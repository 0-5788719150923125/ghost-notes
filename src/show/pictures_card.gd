extends VBoxContainer
class_name PicturesCard

## PicturesCard - THE NOTE'S PICTURES, ONE CARD (2026-11-06, the user: "if we are generating images, we are doing it from a
## unified place: not from a bunch of disparate cards. And the reason is maintainability"). Every picture the note's words
## describe is painted, painted again, stepped between, deleted or replaced with a file of the author's here, whatever the
## note is shown in: a novel's, a notebook's, a tablet's, a letter's, a dispatch desk's (the Medium card's formats). Its list and
## its look are [IllustrationPanel]'s, its pictures [Illustrations]'; the same pictures are rows of the Pipeline card.
## Before it, the Picture, Letter and Dispatch desk cards each carried a list of their own, each fed its own way - and the
## third came without what the others had.
##
## IT COMES WITH THE MEDIUM (the `illustrations` row's `comes_with`), standing while its format shows pictures: never attached by itself, no
## ×; its block, `illustrations:` (the painter, the style, the references), goes with the note. WHICH OF THE NOTE'S MARKS
## ARE PICTURES IS THE FORMAT'S TO SAY ([method Medium.pictures_of]: a letter's sketches are drawn by its pen, a
## tablet's pages are captured from the web, a dispatch desk shows each on a screen), so no card names another and a
## format added later says it in one function. THE CARD STANDS ONLY WHILE THE FORMAT SHOWS PICTURES: under a
## Medium whose format shows none (Auto, the comic) it is not on the panel - a control that does nothing teaches nothing
## - and it is back the moment one that does is picked. AND WHAT A SHOW'S AGENTS PAINTED (2026-11-09): every picture its episode's
## maker says it made ([method EpisodeFeed.made_pictures], [MadePictures]) shown under the list, whatever the medium - the card
## comes with such a show too (the `illustrations` row's `comes_with`), and stands while there is any.

const KEY := "illustrations"
## How often it looks at which medium the note is shown in (seconds): a pin and a pick raise no one signal.
const LOOK_EVERY := 0.25

## A line for the panel's status (a reference image the note names is not on this machine).
signal noted(msg: String)

var _list: IllustrationPanel
var _body := ""
var _medium := ""
var _look_t := 0.0
var _card: Control = null      # the card it stands on, hidden while the medium shows no pictures
var _made: MadePictures        # what the episode's agents painted
var _made_t := 0.0
## How often it looks at what the episode's agents have painted (seconds)
const MADE_EVERY := 1.0


static func for_note(_ctx: Dictionary) -> PicturesCard:
	return PicturesCard.new()


func _init() -> void:
	_list = preload("res://src/media/illustration_panel.gd").new()
	_list.noted.connect(func(msg: String) -> void: noted.emit(msg))
	add_child(_list)
	_made = MadePictures.new()
	# (...the episode as the panel hands it to the card's Pipeline section - the cards meet through the feed, never by name)
	_made.follow(func() -> Variant:
		var cb: Callable = _list.pipeline().episode
		return cb.call() if cb.is_valid() else null)
	add_child(_made)


func _ready() -> void:
	_follow(true)


func _process(delta: float) -> void:
	_made_t -= delta
	if _made_t <= 0.0:
		_made_t = MADE_EVERY
		_stand()
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = LOOK_EVERY
	_follow(false)


# --- the block ---------------------------------------------------------------------------------------------------------

## The block for a document: the pictures' look ([method Illustrations.look]).
func capture() -> Dictionary:
	return _list.capture()


## ...and back.
func apply(block: Dictionary) -> void:
	_list.apply(block)


## The list and look it holds.
func list() -> IllustrationPanel:
	return _list


## What the episode's agents painted, as it shows them.
func made() -> MadePictures:
	return _made


## What it hands the note's Pipeline card: its pictures, a row each.
func pipeline() -> PipelineSection:
	return _list.pipeline()


# --- what it follows ---------------------------------------------------------------------------------------------------

## THE NOTE'S WORDS, whenever the reading reads them (on every pause in typing): the list follows them.
func set_script_text(body: String) -> void:
	_body = body
	_follow(true)


## The pictures [member _body] calls for as the medium shown now shows them, and the card stood or put away by whether it
## shows any: at once with [param again], else only where the medium changed.
func _follow(again: bool) -> void:
	var med := Director.resolved_medium()
	if med == _medium and not again:
		return
	_medium = med
	var listed := Medium.uses(med, "illustrations")
	_list.visible = listed
	_list.set_pictures(Medium.pictures_of(med, _body) if listed else [])
	_stand()


## THE CARD STOOD OR PUT AWAY: standing while the medium shows pictures or the episode's agents have painted any.
func _stand() -> void:
	var shows := _made.refresh() or Medium.uses(_medium, "illustrations")
	var card := _own_card()
	if card != null and card.visible != shows:
		card.visible = shows
		# ...and its chip, at once: the chips only look once a frame
		var at := card.get_parent()
		while at != null and not (at is SidePanel):
			at = at.get_parent()
		if at != null and (at as SidePanel).card_row != null:
			(at as SidePanel).card_row.follow()


## The card it stands on (a [Card] holds it in its body), found once it has one.
func _own_card() -> Control:
	if _card != null and is_instance_valid(_card):
		return _card
	var at := get_parent()
	while at != null and not (at is Card):
		at = at.get_parent()
	_card = at as Control
	return _card

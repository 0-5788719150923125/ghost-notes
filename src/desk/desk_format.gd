extends VBoxContainer
class_name DeskFormat

## DeskFormat - the Desk's own rows on the Medium card: a table show's episodes at the desk ([EpisodeDesk]; next/desk.md). They
## are the Letter's desk rows ([DeskRows]): which desk by number, its light, what is on it and the index cards' words, kept in the
## note's `medium:` block, which the reading's document carries to the desk ([method EpisodeCard.book]). Every episode shown at
## the desk is dressed so; a number of 0 is each episode's own, the desk up now placed from the episode's number ([method
## EpisodeFeed.seed]). Changed while an episode plays, the desk is dressed again at once.

## How often the rows look at which episode is up (seconds): the desk they show is its own while the number is 0.
const LOOK_EVERY := 0.5

var _desk: DeskRows
var _panel: ReadingPanel = null
var _shown_seed := -1
var _look_t := 0.0


static func for_note(ctx: Dictionary) -> DeskFormat:
	var card := DeskFormat.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	card._desk = DeskRows.new(card._episode_seed, "each episode's own desk: what is chosen below, placed from the episode's number")
	card._desk.changed.connect(card._touch)
	card._desk.redress.connect(card._redress_live)
	card.add_child(card._desk)
	return card


func _process(delta: float) -> void:
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = LOOK_EVERY
	var s := _episode_seed()
	if s != _shown_seed:
		_shown_seed = s
		_desk.show_desk()


func capture() -> Dictionary:
	return _desk.capture()


func apply(cfg: Dictionary) -> void:
	_desk.apply(cfg)


## The episode up now's number, 1 while there is none.
func _episode_seed() -> int:
	var feed: EpisodeFeed = _panel.episode_feed() if _panel != null and is_instance_valid(_panel) else null
	var s := feed.seed() if feed != null else 0
	return s if s > 0 else 1


func _touch() -> void:
	if _panel != null:
		_panel.touch()


## The desk dressed again while an episode plays: the rows as they stand, in the reading's live document's `medium`.
func _redress_live() -> void:
	var subs: Node = _panel.subtitles if _panel != null and is_instance_valid(_panel) else null
	if subs == null or not is_instance_valid(subs):
		return
	var doc: Dictionary = subs.get("document")
	var block: Dictionary = doc.get("medium", {}) if doc.get("medium") is Dictionary else {}
	block.merge(_desk.capture(), true)
	doc["medium"] = block

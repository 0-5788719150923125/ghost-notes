extends VBoxContainer
class_name LikenessCard

## LikenessCard - the Likeness component's card: an actor reads the note (next/likeness.md, "The
## Likeness card"). The actor is the note's Actor card's, read through its feed ([ActorFeed], asked of
## the panel by name: [method ReadingPanel.feed]) - the two cards never name each other.
##
## IT PINS ITS MEDIUM while it is up ([LikenessMedium], as Proof pins the desk: [member
## Director.medium_override]) and HANDS THE READING how it goes out ([LikenessCard.Publish]): the
## document a render draws from carries the actor's folder, the set, its still and the seed, and an upload
## of a likeness refuses an actor with no consent on file.
##
## IT BUILDS NOTHING: the actor is built on the Actor card, and this card says what the set in use still
## needs (2026-10-21: a Generate on each card, the user asking why there were two). Nothing is made per
## note: Play reads the note's words with the actor as they are said, and the seed - the Performance -
## says which pieces of their motion play and when they blink.

const KEY := "likeness"
const KNOBS := {"seed": 1}

signal noted(text: String)

var reading: ReadingPanel
var _knobs := KNOBS.duplicate(true)
var _syncing := false
var _row_t := 0.0

var _status: Label
var _seed: SpinBox


static func for_note(ctx: Dictionary) -> LikenessCard:
	var card := LikenessCard.new()
	card.serve(ctx.get("workspace") as ReadingPanel)
	return card


func serve(panel: ReadingPanel) -> void:
	add_theme_constant_override("separation", 8)
	reading = panel
	if reading != null:
		reading.publish = Publish.new(self)
	_build()


func _enter_tree() -> void:
	if reading != null:
		Director.medium_override = "likeness"


func _exit_tree() -> void:
	if reading != null and Director.medium_override == "likeness":
		Director.medium_override = ""


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	_refresh()


# --- the block ----------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	_knobs = KNOBS.duplicate(true)
	if cfg.has("seed"):
		_knobs["seed"] = maxi(1, int(cfg["seed"]))
	_syncing = true
	_seed.set_value_no_signal(float(_knobs["seed"]))
	_syncing = false


# --- what it hands the reading ---------------------------------------------------------------------

## HOW A LIKENESS GOES OUT: the render's document names the actor, the set and its still, and an upload
## asks for consent on file.
class Publish extends ReadingPublish:
	var card: LikenessCard

	func _init(c: LikenessCard) -> void:
		card = c

	func before_take() -> bool:
		var f := card.feed()
		if f == null or not bool(f.status().get("ready", false)):
			card._say("The actor is not ready to play: Generate on the Actor card builds the set in use.")
			return false
		return true

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["likeness"] = card.document()
		return d

	func upload_base(_take: String) -> Dictionary:
		var f := card.feed()
		var a := f.actor() if f != null else null
		if a == null or a.consent().is_empty():
			card._say("Not uploaded: the actor has no consent on file. Add the signed license on the Actor card (License…).")
			return {}
		return {"tags": [], "description": "A likeness of %s, animated from %s's own footage with consent on file. Every pixel of them is a real one from their footage, bent; the voice is synthetic." % [a.name(), a.name()]}


## The actor, as the note's Actor card hands it; null when the note has none.
func feed() -> ActorFeed:
	return reading.feed("actor") as ActorFeed if reading != null else null


## THE DOCUMENT'S `likeness`: the actor's folder, the set and its still, the seed of their performance.
func document() -> Dictionary:
	var f := feed()
	var a := f.actor() if f != null else null
	if a == null:
		return {}
	var sid := a.chosen_set()
	return {"dir": a.dir, "set": sid, "still": a.still_of(sid), "seed": int(_knobs["seed"]), "name": a.name()}


## The note's words without their frontmatter (which is the panel's, and no reading of it).
static func _body_of(text: String) -> String:
	return Manuscript.strip_frontmatter(text)


func _text() -> String:
	var box := reading.source_box() if reading != null else null
	return box.text if box != null else ""


func _say(text: String) -> void:
	noted.emit(text)
	if reading != null:
		reading.status(text)


## The card brought up to date (asked once a tick: it reads the actor's stamps).
func _refresh() -> void:
	var f := feed()
	var st := f.status() if f != null else {"ready": false, "busy": false, "said": "Attach an Actor to this note: it is who reads it."}
	var who := f.actor().name() if f != null and f.actor() != null else "the actor"
	# ▶ ON A NOTE WITH NO WORDS reads nothing, so the card says to write them (2026-10-21: "nothing happened")
	var words := not Manuscript.unspoken(_body_of(_text())).strip_edges().is_empty()
	if not bool(st.get("ready", false)):
		_status.text = String(st.get("said", ""))
	elif not words:
		_status.text = "Ready. Write what %s reads on the Script card, then press ▶." % who
	else:
		_status.text = "Ready: press ▶ to see %s read the note." % who


# --- the card itself -----------------------------------------------------------------------------

func _build() -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	add_child(_status)
	var srow := HBoxContainer.new()
	add_child(srow)
	var sl := Label.new()
	sl.text = "Performance"
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_theme_font_size_override("font_size", 12)
	sl.tooltip_text = ("Which pieces of their own motion play, and when they blink: another number is another "
		+ "performance of the same words, the same number the same one.")
	sl.mouse_filter = Control.MOUSE_FILTER_STOP
	srow.add_child(sl)
	_seed = SpinBox.new()
	_seed.min_value = 1
	_seed.max_value = 99999
	_seed.value = 1
	_seed.tooltip_text = sl.tooltip_text
	_seed.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		_knobs["seed"] = int(v)
		if reading != null:
			reading.mark_stale())
	srow.add_child(_seed)

extends VBoxContainer
class_name ActorCard

## ActorCard - the Actor component's card: makes and manages an actor of the [Actors] library
## (next/likeness.md, "The Actor card"), and PUTS THEM ON THE STAGE: a note with an Actor is read by them,
## in their own room. One component since 2026-10-22 (it had been two, an Actor that built and a Likeness
## that played; the user: "If we're doing all that pipeline work with Actor... then the implication is we
## want to use that actor in the scene").
##
## TOP TO BOTTOM: the actor (picked from the library, or a new one) and their name; their SOURCES - a
## folder read where it is, a link (a video, a playlist, a channel) listed and fetched one video at a
## time, or a link for captions only, matched to the folder's videos by title - with a tick per video;
## the STEPS, a row each ([ActorSteps]): ✓ made, ⚠ stale, its share while it runs, ▶ to make it and
## what it needs, ⟳ to make it again; the steps the note's other cards add, under them; Generate and Stop;
## the SETS the footage fell into, each with its
## sheet, its minutes and its look in words, whether it is built, and the one in use ("Use this set");
## the STILL they are drawn on, picked from the set's stills; what the library and their motion hold;
## who labels; and the steps' settings, folded.
##
## WHILE IT IS UP IT PINS ITS MEDIUM ([LikenessMedium], as Proof pins the desk: [member
## Director.medium_override]) and HANDS THE READING how it goes out ([ActorCard.Publish]): an export waits
## for the set in use to be built, and the document a render draws from carries the actor's folder, the
## set, its still and the seed of their performance, which is the note's own ([method performance]). And
## WHAT IS READ ([ActorCard.Walk]): the note's words, with no title announced before them.
##
## THE NOTE'S OTHER CARDS ADD STEPS OF THEIR OWN ([EpisodeStep]), as on Cards' and Proof's cards (the user,
## 2026-10-23: "push the generate/regenerate step into the Actor card. Right now, it's buried at the bottom
## of the YouTube card"): the ones wanted now - the YouTube card's tags - are rows under the actor's steps,
## handed the note as their episode (it is its own, [NoteUpload]), made by Generate once the actor's own
## steps are done and again on their ⟳; an export that goes up makes them too, when the note's words have
## changed since. This card never asks what one is.
##
## NOTHING HERE WAITS ON THE DISK (the user, 2026-10-23: "every single one of them comes with ~10 seconds of
## reloading-freeze ... We shouldn't be blocking the main thread for ANY operation"): the steps' states are worked
## out on a worker, on a folder of its own ([method ActorBuilder.states_of]), and the runs laid over them by their
## rows ([ActorStepRows], with the sources and videos' [ActorSourceList] shared with the Voice training card); the
## sets' and stills' pictures are read on a worker; a video ticked rebuilds no row. Tick all and Untick all take the
## whole list at once.
##
## GENERATION IS EXPLICIT: nothing runs on open. The survey costs hours of CPU and the audit quota, so a
## button is the only caller ([ActorBuilder]).

const KEY := "actor"

## The block: the actor this note builds, who labels their footage, and the renderer that plays them
## ([constant ActorSteps.RENDERERS]).
const KNOBS := {"id": "", "writer": "claude", "writer_model": "", "writer_effort": "", "renderer": "2d"}
## What makes the note's episode, as the rows of the steps the note's other cards add say it.
const MAKES := "Generate, or an export that goes up"

signal noted(text: String)

var _knobs := KNOBS.duplicate(true)
var _actor: ActorFolder = null
var _builder: ActorBuilder = null
var _syncing := false
var _row_t := 0.0

var _pick: OptionButton
var _picked: Array = []
var _name: LineEdit
## Their sources and videos, and their steps' rows: parts shared with the Voice training card.
var _sources: ActorSourceList
var _steps: ActorStepRows
var _gen_btn: Button
var _stop_btn: Button
var _line: Label
var _sets_box: VBoxContainer
var _sets_seen := ""
var _stills_box: HFlowContainer
var _stills_seen := ""
var _library: Label
var _library_seen := ""
## Pictures read on a worker ([method _want_picture]): `[picture, path, size]` wanted, those being read, and what
## was read, by path.
var _pics_wanted: Array = []
var _pics_task := -1
var _pics_loading: Array = []
var _pics_found := {}
var _writer: AgentPick
var _advanced: VBoxContainer
var _setting_boxes := {}
var _setting_rows := {}
var _renderer: OptionButton
var _library_head: Label
var _body: VBoxContainer       # everything below the picker: hidden with no actor
## Generate was asked for: the steps the note's other cards add are made once the actor's own are done.
var _steps_asked := false
var _step_box: VBoxContainer   # their rows, under the actor's steps
var _step_rows := {}           # a step's key -> {step, state: Label, redo: Button}
var _rows_steps := ""          # the steps the rows were built for
## The reading this card is on (an Actor brings a Voice, so there is one): its status line says what the
## card says, and it plays them. Without one (a gate) the card only builds, and `noted` says.
var _panel: ReadingPanel = null


static func for_note(ctx: Dictionary) -> ActorCard:
	var card := ActorCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.publish = Publish.new(card)
		card._panel.walk = Walk.new()
	card._build()
	return card


func _enter_tree() -> void:
	if _panel != null:
		Director.medium_override = "likeness"


func _exit_tree() -> void:
	if _panel != null and Director.medium_override == "likeness":
		Director.medium_override = ""
	if _builder != null:
		_builder.stop()
	_stop_steps()
	_wait_workers()


## A worker still reading is waited for, before this card goes: it writes into it (a card freed out of the tree -
## a gate's - never leaves it).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_wait_workers()


func _wait_workers() -> void:
	if _pics_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_pics_task)
	_pics_task = -1
	if _steps != null:
		_steps.wait()


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	if _builder != null:
		_builder.tick()
	_tick_steps()
	_refresh()


# --- the block ---------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	var was := String(_knobs["id"])
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if cfg.has(k):
			_knobs[k] = String(cfg[k])
	if not TextGen.has(String(_knobs["writer"])):
		_knobs["writer"] = "claude"
	if not ActorSteps.RENDERERS.has(String(_knobs["renderer"])):
		_knobs["renderer"] = "2d"
	_show_writer()
	if String(_knobs["id"]) != was or _actor == null:
		_open(String(_knobs["id"]))
	_show_renderer()


## The renderer that plays them on this note.
func renderer() -> String:
	return String(_knobs["renderer"])


## THE CARD FOR ITS RENDERER: the steps and settings it is made with, and those every renderer shares;
## the others' are hidden, and their settings kept as they were for a turn back.
func _show_renderer() -> void:
	var r := renderer()
	if _builder != null:
		_builder.renderer = r
	if _renderer != null:
		_syncing = true
		_renderer.select(ActorSteps.RENDERERS.keys().find(r))
		_syncing = false
	_steps.show_only(func(step: String) -> bool: return ActorSteps.serves(step, r) and ActorSteps.of_kind(step, "actor"))
	for k in _setting_rows:
		(_setting_rows[k] as Control).visible = ActorSteps.setting_serves(String(k), r)
	if _library_head != null:
		_library_head.visible = r == "2d"
		_library.visible = r == "2d"


# --- what it hands the reading -------------------------------------------------------------------

## HOW THEY GO OUT: an export waits for the set in use to be built, the render's document names the
## actor, the set and its still, and an upload says whose likeness it is and how it was made
## ([method disclosure]) - under the description written on the YouTube card, the note being its own
## episode ([NoteUpload]), whose steps this card lists.
class Publish extends ReadingPublish:
	var card: ActorCard

	func _init(c: ActorCard) -> void:
		card = c

	func before_take() -> bool:
		var st := card.likeness_status()
		if not bool(st["ready"]):
			card._say(String(st["said"]))
			return false
		return true

	func book(d: Dictionary, _body: String) -> Dictionary:
		d["likeness"] = card.document()
		return d

	func upload_base(_take: String) -> Dictionary:
		var a := card._actor
		if a == null:
			return {"tags": []}
		return {"tags": [], "description": ActorCard.disclosure(a.name(), card.renderer())}

	# the note's tags are written by whoever labels their footage
	func writer() -> Dictionary:
		return {"agent": String(card._knobs["writer"]), "model": String(card._knobs["writer_model"]),
			"effort": String(card._knobs["writer_effort"])}

	# the steps made from the note's words are rows under the actor's, beside Generate
	func lists_steps() -> bool:
		return true


## WHAT THEY READ: the note's own words, AND NO TITLE ANNOUNCED FIRST (the user, 2026-10-23: "In this mode,
## the actor should NOT speak the title. It's very strange that the video starts with the actor saying, 'Bad
## Yestermorrow'"). A reader announces a chapter; a person talking to the camera does not. A heading written
## in the words is said, as everything written is.
class Walk extends TextWalk:
	func spoken(text: String, title: String) -> Dictionary:
		var d := super.spoken(text, title)
		d["title"] = ""
		return d


## WHOSE LIKENESS AN UPLOAD IS, AND HOW IT WAS MADE, said by the code under the description written for it:
## [param name], played by [param renderer] - the 2D one bends their own pixels; Gaussian draws splats
## learned from their footage, which are no pixel of it.
static func disclosure(name: String, renderer: String) -> String:
	if renderer == "gaussian":
		return "A likeness of %s, learned from %s's own footage and drawn as Gaussian splats; the voice is synthetic." % [name, name]
	return "A likeness of %s, animated from %s's own footage. Every pixel of them is a real one from their footage, bent; the voice is synthetic." % [name, name]


## THE PERFORMANCE: the seed their motion's pieces, blinks, glances and posture are drawn from - the
## note's own file's, so the same note plays the same way (a draft with no file, always the first).
func performance() -> int:
	var doc := _panel.doc_source() if _panel != null else null
	var path := doc.doc_path() if doc != null else ""
	return 1 if path.is_empty() else 1 + absi(hash(path)) % 99999


## THE DOCUMENT'S `likeness`: the actor's folder, the set and its still, the seed of their performance.
func document() -> Dictionary:
	if _actor == null:
		return {}
	var sid := _actor.chosen_set()
	return {"dir": _actor.dir, "set": sid, "still": _actor.still_of(sid), "seed": performance(), "name": _actor.name(),
		"renderer": renderer()}


# --- the actor ---------------------------------------------------------------------------------

func _open(id: String) -> void:
	if _builder != null:
		_builder.stop()
	_actor = Actors.open(id) if not id.is_empty() else null
	_builder = ActorBuilder.new(_actor) if _actor != null else null
	if _builder != null:
		_builder.writer = _writer_choice()
		_builder.renderer = renderer()
		_builder.voice_published.connect(_voice_made)
		ActorSources.rescan(_actor)
		_actor.save()
	_sources.show_actor(_actor, _builder)
	_steps.show_actor(_actor, _builder)
	_sets_seen = ""
	_stills_seen = ""
	_library_seen = ""
	_fill_pick()
	_show_actor()
	_refresh()


func _fill_pick() -> void:
	_syncing = true
	_pick.clear()
	_picked = []
	for a in Actors.list():
		_pick.add_item(String(a["name"]))
		_picked.append(String(a["id"]))
		if String(a["id"]) == String(_knobs["id"]):
			_pick.select(_pick.item_count - 1)
	_pick.add_separator()
	_picked.append("")
	_pick.add_item("New actor…")
	_picked.append("+new")
	if _actor == null:
		_pick.select(-1)
		_pick.text = "Pick an actor"
	_syncing = false


func _on_pick(i: int) -> void:
	if _syncing or i < 0 or i >= _picked.size():
		return
	var id := String(_picked[i])
	if id == "+new":
		_ask_name()
		return
	if id.is_empty():
		return
	_knobs["id"] = id
	_open(id)


func _ask_name() -> void:
	var ask := ConfirmationDialog.new()
	ask.title = "New actor"
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "The actor's name - the person in the videos:"
	box.add_child(l)
	var field := LineEdit.new()
	field.custom_minimum_size.x = 320
	box.add_child(field)
	ask.add_child(box)
	ask.ok_button_text = "Make"
	ask.confirmed.connect(func() -> void:
		var a := Actors.create(field.text)
		ask.queue_free()
		_knobs["id"] = a.id
		_open(a.id)
		_say("A new actor, %s: add a folder of their videos, or a link, then Generate." % a.name()))
	ask.canceled.connect(func() -> void:
		ask.queue_free()
		_fill_pick())
	add_child(ask)
	ask.popup_centered(Vector2i(380, 0))
	field.grab_focus()


func _show_actor() -> void:
	_body.visible = _actor != null
	if _actor == null:
		return
	_syncing = true
	_name.text = _actor.name()
	var s := _actor.settings()
	for k in _setting_boxes:
		(_setting_boxes[k] as SpinBox).set_value_no_signal(float(s[k]))
	_syncing = false


## THEIR OWN VOICE HAS LANDED: the reading this card is on asks for its voices again and reads in it
## ([method ReadingPanel.voice_made]) - the list was asked for when the note opened, hours before.
func _voice_made(voice: String) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.voice_made(voice)


func _say(text: String) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.status(text)
	else:
		noted.emit(text)


# --- the steps ----------------------------------------------------------------------------------

func _generate() -> void:
	if _builder == null:
		return
	if _actor.ticked().is_empty():
		_say("Add a folder of their videos or a link first, and tick the ones that are them.")
		return
	_builder.writer = _writer_choice()
	_builder.start()
	_steps_asked = true          # the steps under them: the other cards' too
	var also := PackedStringArray(_listed().map(func(st: EpisodeStep) -> String: return st.label.to_lower()))
	_say("Generating: every step that is missing or stale, in order. The survey of each video takes about a quarter of its length; the rest a few minutes."
		+ ((" Then the note's %s, from its words." % ", ".join(also)) if not also.is_empty() else ""))


## WHETHER THEY CAN PLAY: `{ready, busy, said}` - ready once the set in use is built, whether anything is
## being made, and a line saying what is missing or under way.
func likeness_status() -> Dictionary:
	if _actor == null:
		return {"ready": false, "busy": false, "said": "The Actor card has no actor yet: pick one or make one."}
	var busy := _builder != null and (_builder.running or _builder.busy())
	if _actor.playable("", renderer()):
		return {"ready": true, "busy": busy, "said": ""}
	var missing := PackedStringArray()
	var sid := _actor.chosen_set()
	for step in ActorSteps.plays(renderer()):
		var scope := ("s:" + sid) if ActorSteps.per(String(step)) == "set" else ""
		if sid.is_empty() or _actor.state_of(String(step), scope) == "missing":
			missing.append(String(Registry.field(ActorSteps.REGISTRY, step, "label", step)).to_lower())
	# THE ACTOR CARD BUILDS, and an export held back says so (2026-10-21: a Generate on each card confused)
	var said := ("Building %s on the Actor card: the set in use still needs %s." if busy
		else "%s is not built yet (the set in use needs %s): Generate on the Actor card builds them.") % [_actor.name(), ", ".join(missing)]
	return {"ready": false, "busy": busy, "said": said}


func _refresh() -> void:
	if _actor == null or _builder == null:
		return
	_actor.forget()
	_sources.refresh()
	var busy := _builder.running or _builder.busy()
	var steps := _steps_asked or _steps_busy()
	_gen_btn.disabled = busy or steps
	_stop_btn.disabled = not (busy or steps)
	_steps.refresh(busy)
	var line := ""
	if not _builder.waiting.is_empty():
		line = "Waiting: %s - Ghost Notes fetches these itself, once (see ⚙ for progress)." % _builder.waiting
	elif _actor.playable("", renderer()):
		line = "Ready to play: the set in use has everything they need to read."
	_line.text = line
	_refresh_step_rows()
	_fill_sets()
	_fill_stills()
	_fill_library()
	_take_pictures()


## A PICTURE READ ON A WORKER: [param path] into [param pic] once read, made [param most] pixels at most (a sheet
## is shown far smaller than it is).
func _want_picture(pic: TextureRect, path: String, most: Vector2i) -> void:
	_pics_wanted.append([pic, path, most])
	_read_pictures()


func _read_pictures() -> void:
	if _pics_task >= 0 or _pics_wanted.is_empty():
		return
	_pics_loading = _pics_wanted
	_pics_wanted = []
	var asked: Array = _pics_loading.map(func(w: Array) -> Array: return [String(w[1]), w[2]])
	_pics_task = WorkerThreadPool.add_task(func() -> void:
		var got := {}
		for a in asked:
			var path := String(a[0])
			if got.has(path) or not FileAccess.file_exists(path):
				continue
			var img := Image.load_from_file(path)
			var most: Vector2i = a[1]
			if img != null and (img.get_width() > most.x or img.get_height() > most.y):
				var k := minf(float(most.x) / img.get_width(), float(most.y) / img.get_height())
				img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
			got[path] = img
		_pics_found = got)


## The pictures read, put up - each where it still stands - and the next asked for.
func _take_pictures() -> void:
	if _pics_task < 0 or not WorkerThreadPool.is_task_completed(_pics_task):
		return
	WorkerThreadPool.wait_for_task_completion(_pics_task)
	_pics_task = -1
	for w in _pics_loading:
		var img: Variant = _pics_found.get(String(w[1]))
		if is_instance_valid(w[0]) and img is Image:
			(w[0] as TextureRect).texture = ImageTexture.create_from_image(img)
	_pics_loading = []
	_pics_found = {}
	_read_pictures()


# --- the steps the note's other cards add -------------------------------------------------------

## The steps the note's other cards add, all of them, as the panel holds them
## ([method ReadingPanel.episode_steps]).
func _offered() -> Array:
	return _panel.episode_steps() if _panel != null and is_instance_valid(_panel) else []


## THE NOTE AS THEIR EPISODE: read as it is written, it is its own ([method ReadingPanel.note_upload]) - null
## while it has no YouTube card.
func _note_feed() -> EpisodeFeed:
	var up := _panel.note_upload() if _panel != null and is_instance_valid(_panel) else null
	return up.feed() if up != null else null


## ...and the ones listed now, under the actor's steps: none while the note has no file to keep them by.
func _listed() -> Array:
	var feed := _note_feed()
	return EpisodeStep.listed_of(_offered()) if feed != null and not feed.folder().is_empty() else []


## What the rows were built for: the listed steps' keys.
func _steps_key() -> String:
	return ",".join(PackedStringArray(_listed().map(func(st: EpisodeStep) -> String: return st.key)))


## This card as the steps' rows say where they are: "the Actor card".
static func host_name() -> String:
	return "the %s card" % String(Registry.field(Components.REGISTRY, KEY, "label", "Actor"))


## EACH REFRESH: what the steps' jobs ended with, landed; the note said to the steps listed; and once the
## actor's own steps are done, each listed step Generate asked for, made - from the note's words, so only
## once they are written.
func _tick_steps() -> void:
	for st in _offered():
		(st as EpisodeStep).tick()
	var feed := _note_feed()
	var listed := _listed()
	for st in listed:
		(st as EpisodeStep).listed(host_name(), feed, MAKES)
	if _steps_asked and not (_builder != null and (_builder.running or _builder.busy())):
		_steps_asked = false
		for st in listed:
			(st as EpisodeStep).generate(feed)


## STOP what the steps are making of the note, and what Generate asked of them.
func _stop_steps() -> void:
	_steps_asked = false
	var feed := _note_feed()
	if feed == null:
		return
	for st in _offered():
		(st as EpisodeStep).stop(feed)


## Is a listed step being made for the note?
func _steps_busy() -> bool:
	var feed := _note_feed()
	for st in _listed():
		if (st as EpisodeStep).busy(feed):
			return true
	return false


## ⟳ on a step's row: made again now, from the note's words - which must be written first.
func _redo_step(step: EpisodeStep) -> void:
	if not step.redo(_note_feed()):
		_say("%s waits for the note's words: write them on the Script card." % step.label)


## The steps' rows, under the actor's, one per step listed, as Proof's card draws them: built again when the
## steps listed change. A step's ⟳ is offered once the note has words and while that step is not being made -
## nothing the actor's steps make is read by it.
func _refresh_step_rows() -> void:
	if _steps_key() != _rows_steps:
		_rows_steps = _steps_key()
		for c in _step_box.get_children():
			_step_box.remove_child(c)
			c.queue_free()
		_step_rows = {}
		for st in _listed():
			var step: EpisodeStep = st
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 4)
			_step_box.add_child(r)
			var name_l := Label.new()
			name_l.text = step.label
			name_l.custom_minimum_size.x = 64.0
			name_l.add_theme_font_size_override("font_size", 12)
			r.add_child(name_l)
			var state := Label.new()
			state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			state.clip_text = true
			state.add_theme_font_size_override("font_size", 11)
			state.mouse_filter = Control.MOUSE_FILTER_STOP
			r.add_child(state)
			var redo := Button.new()
			redo.text = "⟳"
			redo.flat = true
			redo.pressed.connect(_redo_step.bind(step))
			r.add_child(redo)
			_step_rows[step.key] = {"step": step, "state": state, "redo": redo}
	var feed := _note_feed()
	var words := feed != null and not feed.words().is_empty()
	for k in _step_rows:
		var r: Dictionary = _step_rows[k]
		var step: EpisodeStep = r["step"]
		var st := step.state(feed)
		var lead := String({"ready": "✓", "running": "…", "queued": "…", "failed": "✗"}.get(st, "–"))
		var said := step.said(feed)
		(r["state"] as Label).text = lead + (" " + said if not said.is_empty() else "")
		(r["state"] as Label).tooltip_text = (r["state"] as Label).text
		var made := not step.made(feed).is_empty()
		(r["redo"] as Button).disabled = step.busy(feed) or not words
		(r["redo"] as Button).tooltip_text = (step.again if made else step.first) + (
			"" if words else " - once the note has words")


# --- the sets and the library --------------------------------------------------------------------

func _fill_sets() -> void:
	var chosen := _actor.chosen_set()
	# the sets worth a row: a quarter minute usable (or the one in use), at most a dozen
	var shown: Array = []
	for s in _actor.sets():
		if float((s as Dictionary).get("usable", 0.0)) >= 0.25 or String((s as Dictionary).get("id", "")) == chosen:
			shown.append(s)
	shown = shown.slice(0, 12)
	# a set's being built changes only with its stamps: their file's time and size, not every step's state
	var key := chosen + "|"
	for s in shown:
		var stamps := _actor.set_dir(String(s.get("id", ""))).path_join(ActorFolder.STAMPS)
		key += "%s:%s:%s:%s;" % [s.get("id", ""), s.get("usable", 0), s.get("look", ""),
			"%d|%d" % [FileAccess.get_modified_time(stamps), FileAccess.get_size(stamps)] if FileAccess.file_exists(stamps) else "-"]
	if key == _sets_seen:
		return
	_sets_seen = key
	for c in _sets_box.get_children():
		c.queue_free()
	for s in shown:
		var d: Dictionary = s
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sets_box.add_child(row)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(120, 68)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if FileAccess.file_exists(String(d.get("sheet", ""))):
			# read on a worker, at twice the size it is shown (a sheet is 1568 px wide)
			_want_picture(tex, String(d.get("sheet", "")), Vector2i(240, 136))
			tex.tooltip_text = "Click for the set's sheet"
			tex.mouse_filter = Control.MOUSE_FILTER_PASS
			tex.gui_input.connect(func(e: InputEvent) -> void:
				if clicked(e):
					OS.shell_open(String(d.get("sheet", ""))))
		row.add_child(tex)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 11)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var look := String(d.get("look", ""))
		l.text = "%.1f min usable of %.1f · %d shots%s%s%s" % [float(d.get("usable", 0.0)), float(d.get("minutes", 0.0)),
			(d.get("shots", []) as Array).size(), (" · %d out" % int(d["excluded"])) if int(d.get("excluded", 0)) > 0 else "",
			" · handheld" if bool(d.get("handheld", false)) else "", ("\n" + look) if not look.is_empty() else ""]
		col.add_child(l)
		# WHICH SET THE LIKENESS USES: each set is built on its own (its still, its rig, its library - a
		# few minutes), so the row says whether this one is, and using another keeps this one's work
		# (2026-10-21: "Play this set" read as a preview, and switching looked like losing a build)
		var sid := String(d.get("id", ""))
		var built := _actor.playable(sid, renderer())
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 8)
		col.add_child(foot)
		var use := Button.new()
		var is_chosen := sid == chosen
		use.text = "In use" if is_chosen else "Use this set"
		use.disabled = is_chosen
		use.add_theme_font_size_override("font_size", 11)
		use.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		use.tooltip_text = ("The set the likeness is played in: its room and its camera. Each set is built on its own - "
			+ "its stills, its rig, its library of their mouths and eyes, a few minutes. A set already built is kept when "
			+ "another is used, and is ready again at once.")
		use.pressed.connect(func() -> void:
			_actor.data["set"] = sid
			_actor.save()
			_sets_seen = ""
			_say("This set is used now. " + ("It is built: they can play in it." if built
				else "It is not built yet: Generate builds it (%s of CPU). Any set built before is kept." % _build_time(d))))
		foot.add_child(use)
		var said := Label.new()
		said.add_theme_font_size_override("font_size", 11)
		said.text = "✓ built" if built else "not built (%s)" % _build_time(d)
		said.modulate = Color(1, 1, 1, 0.9 if built else 0.6)
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		said.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		foot.add_child(said)


## ROUGHLY HOW LONG SET [param _d] TAKES TO BUILD once the survey is done: its stills, its rig and its
## library seek a few hundred frames, whatever its length.
func _build_time(_d: Dictionary) -> String:
	return "a few minutes"


## THE STILL THE LIKENESS IS DRAWN ON: the set in use's stills - those At rest found them at ease in
## first, most at ease first, and marked - the one in use marked, a click picking another; nothing is made
## again (the library is the set's, matched to each still's light).
func _fill_stills() -> void:
	var sid := _actor.chosen_set()
	var p := _actor.set_dir(sid).path_join("stills.json") if not sid.is_empty() else ""
	var r := _actor.set_dir(sid).path_join("rest.json") if not sid.is_empty() else ""
	var key := "%s|%d|%d|%d" % [sid, FileAccess.get_modified_time(p) if not p.is_empty() and FileAccess.file_exists(p) else 0,
		FileAccess.get_modified_time(r) if not r.is_empty() and FileAccess.file_exists(r) else 0,
		_actor.still_of(sid) if not sid.is_empty() else -1]
	if key == _stills_seen:
		return
	_stills_seen = key
	for c in _stills_box.get_children():
		c.queue_free()
	if sid.is_empty():
		return
	var stills := _actor.stills_of(sid)
	var chosen := _actor.still_of(sid)
	var rest := _actor.rest_of(sid)
	var order := rest.duplicate()
	for k in stills.size():
		if not order.has(k):
			order.append(k)
	for k in order:
		var d: Dictionary = stills[k]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		_stills_box.add_child(col)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(112, 63)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := _actor.set_dir(sid).path_join("stills").path_join(String(d.get("thumb", "")))
		_want_picture(tex, path, Vector2i(224, 126))
		tex.modulate = Color(1, 1, 1, 1.0 if k == chosen else 0.55)
		tex.mouse_filter = Control.MOUSE_FILTER_PASS
		tex.tooltip_text = ("The still in use: every frame of the likeness is drawn on it." if k == chosen \
			else "Draw the likeness on this still instead (nothing is made again).") \
			+ ("\nAt rest found them at ease in it." if rest.has(k) else "")
		tex.gui_input.connect(func(e: InputEvent) -> void:
			if clicked(e):
				_actor.set_still(sid, k)
				_actor.save()
				_say("The likeness is drawn on this still now."))
		col.add_child(tex)
		var l := Label.new()
		l.text = "in use" if k == chosen else ("at rest" if rest.has(k) else " ")
		l.add_theme_font_size_override("font_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)


func _fill_library() -> void:
	var sid := _actor.chosen_set()
	# READ ONLY WHEN MADE AGAIN: this runs four times a second
	var files := [_actor.dir.path_join("visemes.json"), _actor.dir.path_join("motion.json"),
		_actor.dir.path_join("mouth_model.json")]
	if not sid.is_empty():
		files.append(_actor.set_dir(sid).path_join("library.json"))
	var key := sid
	for f in files:
		key += "|%d" % (FileAccess.get_modified_time(f) if FileAccess.file_exists(f) else 0)
	if key == _library_seen:
		return
	_library_seen = key
	var parts := PackedStringArray()
	var l: Variant = ActorFolder.read_json(files[3]) if files.size() > 3 else null
	if l is Dictionary:
		var sounds := {}
		for m in (l as Dictionary).get("mouths", []):
			sounds[String((m as Dictionary)["class"])] = true
		parts.append("%d mouths for %d sounds, %d eyes closing - each a real frame of theirs" % [
			((l as Dictionary).get("mouths", []) as Array).size(), sounds.size(), ((l as Dictionary).get("eyes", []) as Array).size()])
	var v: Variant = ActorFolder.read_json(files[0])
	if v is Dictionary:
		var from_caps := 0
		var cl: Dictionary = (v as Dictionary).get("classes", {})
		for k in cl:
			if String((cl[k] as Dictionary).get("from", "")) == "words":
				from_caps += 1
		var shows := float((v as Dictionary).get("words_show", -1.0))
		if from_caps > 0:
			parts.append("Their mouth for %d sounds, %d learned from their words" % [cl.size(), from_caps])
		elif shows >= 0.0:
			parts.append("Their mouth for %d sounds, each placed in their own range: their words scarcely show in their mouth in this footage (the sounds' mouths span %d%% of their jaw's range)" % [cl.size(), int(round(100.0 * shows))])
		else:
			parts.append("Their mouth for %d sounds, each placed in their own range of movement (no words to learn from)" % cl.size())
	# THE LEARNED MOUTH'S OWN MEASURE: how much of their mouth it explains on a video it never saw
	var mm: Variant = ActorFolder.read_kept(files[2])
	if mm is Dictionary and (mm as Dictionary).get("scores") is Dictionary and not ((mm as Dictionary)["scores"] as Dictionary).is_empty():
		var sc: Dictionary = (mm as Dictionary)["scores"]
		var used := float(sc.get("ensemble", 0.0)) >= LikenessPlan.LEARNED_LEAST \
			and float(sc.get("ensemble", 0.0)) >= float(sc.get("each_sound_mean", 0.0)) + LikenessPlan.LEARNED_BEYOND
		parts.append("Their mouth learned from %d looks by %d networks: on a video it never saw, it explains %d%% of their mouth (each sound's average mouth: %d%%) - %s" % [
			int((mm as Dictionary).get("looks", 0)), ((mm as Dictionary).get("members", []) as Array).size(),
			int(round(100.0 * float(sc.get("ensemble", 0.0)))), int(round(100.0 * float(sc.get("each_sound_mean", 0.0)))),
			"the mouth is drawn from it" if used else "too little to draw from, so the mouth is placed by its sounds"])
	var mo: Variant = ActorFolder.read_kept(files[1])
	if mo is Dictionary:
		var rows := 0
		for r in (mo as Dictionary).get("runs", []):
			rows += ((r as Dictionary).get("rows", []) as Array).size()
		parts.append("%d minutes of their head's own motion; they blink about %d times a minute" % [
			int(round(rows / maxf(1.0, float((mo as Dictionary).get("rate", 5.0))) / 60.0)), int(round(float((mo as Dictionary).get("blinks_per_min", 0.0))))])
	_library.text = "\n".join(parts)


# --- who labels -----------------------------------------------------------------------------------

func _writer_choice() -> Dictionary:
	return {"agent": String(_knobs["writer"]), "model": String(_knobs["writer_model"]),
		"effort": String(_knobs["writer_effort"])}


func _show_writer() -> void:
	if _writer == null:
		return
	_syncing = true
	_writer.set_choice(String(_knobs["writer"]), String(_knobs["writer_model"]), String(_knobs["writer_effort"]))
	_syncing = false


# --- the card itself -----------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	_pick = OptionButton.new()
	_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick.fit_to_longest_item = false
	_pick.clip_text = true
	_pick.focus_mode = Control.FOCUS_NONE
	_pick.tooltip_text = "The actor this note builds - shared by every note that uses them - or a new one."
	_pick.item_selected.connect(_on_pick)
	top.add_child(_pick)
	var folder := Button.new()
	folder.text = "Folder"
	folder.tooltip_text = "Open the actor's folder: their footage, every step's files, the contact sheets and every agent's prompt and answer."
	folder.pressed.connect(func() -> void:
		if _actor != null:
			OS.shell_open(_actor.dir))
	top.add_child(folder)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	var nrow := HBoxContainer.new()
	_body.add_child(nrow)
	var nl := Label.new()
	nl.text = "Name"
	nl.custom_minimum_size.x = 64
	nl.add_theme_font_size_override("font_size", 12)
	nrow.add_child(nl)
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.tooltip_text = "Their name, as the agents are told it and the disclosure names them."
	_name.text_changed.connect(func(t: String) -> void:
		if _syncing or _actor == null:
			return
		_actor.data["name"] = t.strip_edges()
		_actor.save())
	nrow.add_child(_name)
	var rrow := HBoxContainer.new()
	_body.add_child(rrow)
	var rl := Label.new()
	rl.text = "Renderer"
	rl.custom_minimum_size.x = 64
	rl.add_theme_font_size_override("font_size", 12)
	rrow.add_child(rl)
	_renderer = OptionButton.new()
	_renderer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_renderer.fit_to_longest_item = false
	var tips := PackedStringArray()
	for key in ActorSteps.RENDERERS:
		_renderer.add_item(String(Registry.label(ActorSteps.RENDERERS, key)))
		tips.append("%s: %s" % [Registry.label(ActorSteps.RENDERERS, key), Registry.blurb(ActorSteps.RENDERERS, key)])
	_renderer.tooltip_text = ("How they are drawn on this note. Each has steps of its own; the steps they share are "
		+ "made once, and a renderer's settings are kept while another is used.\n\n" + "\n".join(tips))
	_renderer.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_knobs["renderer"] = String(ActorSteps.RENDERERS.keys()[i])
		_show_renderer())
	rrow.add_child(_renderer)

	_body.add_child(heading("Sources"))
	_sources = ActorSourceList.new()
	_sources.said.connect(_say)
	_body.add_child(_sources)

	_body.add_child(heading("Steps"))
	_steps = ActorStepRows.new(ActorSteps.ORDER)
	_steps.said.connect(_say)
	_steps.before_start = func() -> void:
		if _builder != null:
			_builder.writer = _writer_choice()
	_body.add_child(_steps)
	# THE STEPS THE NOTE'S OTHER CARDS ADD, under the actor's ([method _refresh_step_rows])
	_step_box = VBoxContainer.new()
	_step_box.add_theme_constant_override("separation", 0)
	_body.add_child(_step_box)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	_body.add_child(grow)
	_gen_btn = Button.new()
	_gen_btn.text = "Generate"
	_gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gen_btn.tooltip_text = "Make every step that is missing or stale, in order: the survey takes about a quarter of the footage's length in CPU, the rest a few minutes, and the audit the labeler's quota. Then the steps listed under them (the note's tags), from the note's words."
	_gen_btn.pressed.connect(_generate)
	grow.add_child(_gen_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.tooltip_text = "Stop now. What is finished is kept; a survey loses at most the video in hand."
	_stop_btn.pressed.connect(func() -> void:
		if _builder != null:
			_builder.stop()
		_stop_steps())
	grow.add_child(_stop_btn)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.7)
	_body.add_child(_line)

	_body.add_child(heading("Sets"))
	_sets_box = VBoxContainer.new()
	_sets_box.add_theme_constant_override("separation", 6)
	_body.add_child(_sets_box)
	var sh := heading("Still")
	sh.tooltip_text = ("The one frame of the set in use the likeness is drawn on - its head, eyes and mouth moved by what "
		+ "is learned of them. Their most typical calm moments, facing the camera; click another to use it.")
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(sh)
	_stills_box = HFlowContainer.new()
	_stills_box.add_theme_constant_override("h_separation", 4)
	_body.add_child(_stills_box)
	_library_head = heading("Library")
	_body.add_child(_library_head)
	_library = Label.new()
	_library.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_library.add_theme_font_size_override("font_size", 11)
	_body.add_child(_library)

	_writer = AgentPick.writer(("Who labels their footage: the audit of each set's look, and what in it cannot be used. "
		+ "It is shown pictures, so it must be one that sees them. Takes effect at the next step it makes."),
		"The model that labels. Default is the CLI's own choice per job.",
		"How hard the labeler thinks - the CLI's own reasoning effort. Higher is slower and spends more quota.")
	_writer.changed.connect(func() -> void:
		if _syncing:
			return
		var c := _writer.choice()
		_knobs["writer"] = String(c["agent"])
		_knobs["writer_model"] = String(c["model"])
		_knobs["writer_effort"] = String(c["effort"])
		if _builder != null:
			_builder.writer = _writer_choice())
	_body.add_child(_writer)

	var fold := Button.new()
	fold.text = "Advanced ▸"
	fold.flat = true
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.add_child(fold)
	_advanced = VBoxContainer.new()
	_advanced.visible = false
	_body.add_child(_advanced)
	fold.pressed.connect(func() -> void:
		_advanced.visible = not _advanced.visible
		fold.text = "Advanced ▾" if _advanced.visible else "Advanced ▸")
	for k in ActorSteps.SETTINGS:
		var row: Dictionary = ActorSteps.SETTINGS[k]
		var r := HBoxContainer.new()
		_advanced.add_child(r)
		var l := Label.new()
		l.text = String(row["label"])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		l.tooltip_text = String(row["blurb"])
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(l)
		var sb := SpinBox.new()
		sb.min_value = float(row["min"])
		sb.max_value = float(row["max"])
		sb.step = float(row["step"])
		sb.value = float(row["default"])
		sb.tooltip_text = String(row["blurb"])
		var key := String(k)
		sb.value_changed.connect(func(v: float) -> void:
			if _syncing or _actor == null:
				return
			(_actor.data["settings"] as Dictionary)[key] = v
			_actor.save())
		r.add_child(sb)
		_setting_boxes[k] = sb
		_setting_rows[k] = r
	_body.visible = false
	_fill_pick()
	_show_renderer()


## A PICTURE CLICKED: the left button's press, nothing else - the wheel's notches are button presses too (2026-10-23:
## scrolling over the sets opened dozens of their sheets). The pictures pass what they do not take on (MOUSE_FILTER_PASS),
## so the wheel scrolls the card under them.
static func clicked(e: InputEvent) -> bool:
	var mb := e as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


## A HEADING over a part of the card (the Voice training card's too).
static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(1, 1, 1, 0.85)
	return l

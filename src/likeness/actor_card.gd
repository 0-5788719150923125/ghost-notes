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
## what it needs, ⟳ to make it again; Generate and Stop; the SETS the footage fell into, each with its
## sheet, its minutes and its look in words, whether it is built, and the one in use ("Use this set");
## the STILL they are drawn on, picked from the set's stills; what the library and their motion hold;
## who labels; and the steps' settings, folded.
##
## WHILE IT IS UP IT PINS ITS MEDIUM ([LikenessMedium], as Proof pins the desk: [member
## Director.medium_override]) and HANDS THE READING how it goes out ([ActorCard.Publish]): an export waits
## for the set in use to be built, and the document a render draws from carries the actor's folder, the
## set, its still and the seed of their performance, which is the note's own ([method performance]).
##
## GENERATION IS EXPLICIT: nothing runs on open. The survey costs hours of CPU and the audit quota, so a
## button is the only caller ([ActorBuilder]).

const KEY := "actor"

## The block: the actor this note builds, who labels their footage, and the renderer that plays them
## ([constant ActorSteps.RENDERERS]).
const KNOBS := {"id": "", "writer": "claude", "writer_model": "", "writer_effort": "", "renderer": "2d"}

signal noted(text: String)

var _knobs := KNOBS.duplicate(true)
var _actor: ActorFolder = null
var _builder: ActorBuilder = null
var _syncing := false
var _row_t := 0.0

var _pick: OptionButton
var _picked: Array = []
var _name: LineEdit
var _sources_box: VBoxContainer
var _videos_box: VBoxContainer
var _videos_seen := ""
var _rows := {}               # step -> {state: Label, make: Button, redo: Button}
var _gen_btn: Button
var _stop_btn: Button
var _line: Label
var _sets_box: VBoxContainer
var _sets_seen := ""
var _stills_box: HFlowContainer
var _stills_seen := ""
var _library: Label
var _library_seen := ""
var _rows_seen := ""
var _writer: AgentPick
var _advanced: VBoxContainer
var _setting_boxes := {}
var _setting_rows := {}
var _renderer: OptionButton
var _library_head: Label
var _body: VBoxContainer       # everything below the picker: hidden with no actor
## The reading this card is on (an Actor brings a Voice, so there is one): its status line says what the
## card says, and it plays them. Without one (a gate) the card only builds, and `noted` says.
var _panel: ReadingPanel = null


static func for_note(ctx: Dictionary) -> ActorCard:
	var card := ActorCard.new()
	card._panel = ctx.get("workspace") as ReadingPanel
	if card._panel != null:
		card._panel.publish = Publish.new(card)
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


func _process(delta: float) -> void:
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	if _builder != null:
		_builder.tick()
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
	for step in _rows:
		((_rows[step] as Dictionary)["row"] as Control).visible = ActorSteps.serves(String(step), r)
	for k in _setting_rows:
		(_setting_rows[k] as Control).visible = ActorSteps.setting_serves(String(k), r)
	if _library_head != null:
		_library_head.visible = r == "2d"
		_library.visible = r == "2d"
	_rows_seen = ""


# --- what it hands the reading -------------------------------------------------------------------

## HOW THEY GO OUT: an export waits for the set in use to be built, the render's document names the
## actor, the set and its still, and an upload says whose likeness it is.
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
		return {"tags": [], "description": "A likeness of %s, animated from %s's own footage. Every pixel of them is a real one from their footage, bent; the voice is synthetic." % [a.name(), a.name()]}


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
	_videos_seen = ""
	_sets_seen = ""
	_stills_seen = ""
	_rows_seen = ""
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
	_fill_sources()


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


# --- the sources --------------------------------------------------------------------------------

func _fill_sources() -> void:
	for c in _sources_box.get_children():
		c.queue_free()
	if _actor == null:
		return
	var sources: Array = _actor.data["sources"]
	for i in sources.size():
		var s: Dictionary = sources[i]
		var row := HBoxContainer.new()
		_sources_box.add_child(row)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 11)
		var what := ""
		if String(s.get("kind", "")) == "folder":
			what = "📁 " + String(s.get("path", "")).get_file()
			l.tooltip_text = String(s.get("path", ""))
		else:
			var t := String(s.get("title", ""))
			what = ("💬 " if bool(s.get("captions_only", false)) else "🔗 ") + (t if not t.is_empty() else String(s.get("url", "")))
			var landed: Dictionary = s.get("landed", {}) if s.get("landed") is Dictionary else {}
			if bool(s.get("captions_only", false)) and not landed.is_empty():
				what += "  (captions for %d, %d unmatched)" % [int(landed.get("matched", 0)), int(landed.get("unmatched", 0))]
			elif not landed.is_empty():
				what += "  (%d videos)" % int(s.get("count", 0))
			if not String(s.get("error", "")).is_empty():
				what += "  ⚠ " + String(s["error"])
			elif not bool(s.get("listed", false)):
				what += "  - listing…" if _builder != null and _builder.listing(i) else "  - not listed"
			l.tooltip_text = String(s.get("url", "")) + ("\nCaptions only: fetches no video; each caption is matched to a folder video by title." if bool(s.get("captions_only", false)) else "")
		l.text = what
		row.add_child(l)
		if String(s.get("kind", "")) == "link":
			var again := Button.new()
			again.text = "⟳"
			again.flat = true
			again.tooltip_text = "List this link again: new videos in a playlist or channel get rows (fetched videos are not fetched twice)."
			again.pressed.connect(_list.bind(i))
			row.add_child(again)


func _add_folder() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = "A folder of their videos (read where it is, never copied)"
	dlg.dir_selected.connect(func(path: String) -> void:
		dlg.queue_free()
		var n := ActorSources.add_folder(_actor, path)
		_actor.save()
		_fill_sources()
		_videos_seen = ""
		_say("%d video%s found in %s. Untick any that are not them." % [n, "" if n == 1 else "s", path.get_file()]))
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered_ratio(0.6)


func _add_link() -> void:
	var ask := ConfirmationDialog.new()
	ask.title = "Add a link"
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "A video, a playlist or a channel:"
	box.add_child(l)
	var field := LineEdit.new()
	field.custom_minimum_size.x = 420
	field.placeholder_text = "https://www.youtube.com/…"
	box.add_child(field)
	var cap := CheckBox.new()
	cap.text = "Captions only - match them to the folder's videos by title"
	cap.tooltip_text = "Fetches no video: each video's automatic captions are matched to a video already in a folder source, by title, so its words get their times without the video being downloaded again."
	box.add_child(cap)
	ask.add_child(box)
	ask.ok_button_text = "Add"
	ask.confirmed.connect(func() -> void:
		var url := field.text.strip_edges()
		ask.queue_free()
		if not url.begins_with("http"):
			_say("That is not a link.")
			return
		var i := ActorSources.add_link(_actor, url, cap.button_pressed)
		_actor.save()
		_list(i))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(460, 0))
	field.grab_focus()


func _list(i: int) -> void:
	if _builder == null:
		return
	var err := _builder.list_link(i)
	_say(err if not err.is_empty() else "Listing the link… its videos appear below as they are found.")
	_fill_sources()


## The videos' rows, built again when the videos change: a tick, the title, its length.
func _fill_videos() -> void:
	var key := ""
	if _actor != null:
		for vid in _actor.videos():
			var v: Dictionary = _actor.video(String(vid))
			key += "%s|%s|%s|%s;" % [vid, v.get("ticked", true), v.get("path", ""), v.get("captions", "")]
	if key == _videos_seen:
		return
	_videos_seen = key
	for c in _videos_box.get_children():
		c.queue_free()
	if _actor == null:
		return
	for vid in _actor.videos():
		var v: Dictionary = _actor.video(String(vid))
		var row := HBoxContainer.new()
		_videos_box.add_child(row)
		var tick := CheckBox.new()
		tick.button_pressed = bool(v.get("ticked", true))
		tick.tooltip_text = "Use this video. Untick one that is not them, or not in their usual setting."
		tick.toggled.connect(func(on: bool) -> void:
			(_actor.video(String(vid)))["ticked"] = on
			_actor.save())
		row.add_child(tick)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 11)
		var dur := float(v.get("duration", 0.0))
		var marks := ""
		if _actor.is_link(String(vid)) and _actor.video_path(String(vid)).is_empty():
			marks += "↓ "
		elif _actor.video_path(String(vid)).is_empty():
			marks += "⚠ missing "
		if FileAccess.file_exists(String(v.get("captions", ""))):
			marks += "💬 "
		l.text = marks + String(v.get("title", vid)) + ("  %s" % Clock.text(dur) if dur > 0.0 else "")
		l.tooltip_text = String(v.get("path", v.get("url", ""))) + "\n↓ not fetched yet · 💬 has captions"
		row.add_child(l)


# --- the steps ----------------------------------------------------------------------------------

func _make(step: String) -> void:
	if _builder == null:
		return
	_builder.writer = _writer_choice()
	_builder.start(ActorSteps.with_needs(step))
	_say("Making %s, and whatever it needs first." % String(Registry.field(ActorSteps.REGISTRY, step, "label", step)))


func _redo(step: String) -> void:
	if _builder == null:
		return
	var label := String(Registry.field(ActorSteps.REGISTRY, step, "label", step))
	var ask := ConfirmationDialog.new()
	ask.title = "Make %s again" % label
	ask.dialog_text = ("Throw away what %s made and make it again?\n\nEverything made from it is marked stale (⚠): "
		+ "it is still used until it is made again too - Generate does that.") % label
	ask.dialog_autowrap = true
	ask.ok_button_text = "Make again"
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		_builder.writer = _writer_choice()
		_builder.redo(step))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(460, 0))


func _generate() -> void:
	if _builder == null:
		return
	if _actor.ticked().is_empty():
		_say("Add a folder of their videos or a link first, and tick the ones that are them.")
		return
	_builder.writer = _writer_choice()
	_builder.start()
	_say("Generating: every step that is missing or stale, in order. The survey of each video takes about a quarter of its length; the rest a few minutes.")


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
	_fill_videos()
	var busy := _builder.running or _builder.busy()
	_gen_btn.disabled = busy
	_stop_btn.disabled = not busy
	# THE ROWS ARE WORKED OUT AGAIN ONLY WHEN WHAT THEY ARE MADE FROM CHANGED, or while something runs:
	# every scope's state of every step took 10-20 ms, four times a second, under a playing show
	var key := _rows_key(busy)
	if key != _rows_seen:
		_rows_seen = key
		_fill_rows(busy)
	var line := ""
	if not _builder.waiting.is_empty():
		line = "Waiting: %s - Ghost Notes fetches these itself, once (see ⚙ for progress)." % _builder.waiting
	elif _actor.playable("", renderer()):
		line = "Ready to play: the set in use has everything they need to read."
	_line.text = line
	_fill_sets()
	_fill_stills()
	_fill_library()


## What the step rows are made from: the actor's data (videos ticked, settings, the set in use), every
## stamp file a row reads, what failed - and while anything runs, the time, so a running row moves.
func _rows_key(busy: bool) -> String:
	if busy:
		return "busy %d" % Time.get_ticks_msec()
	var parts := PackedStringArray([str(JSON.stringify(_actor.data).hash()), str(JSON.stringify(_builder.errors()).hash())])
	var scopes: Array = [""]
	for v in _actor.ticked():
		scopes.append("v:" + String(v))
	if not _actor.chosen_set().is_empty():
		scopes.append("s:" + _actor.chosen_set())
	for sc in scopes:
		var p := _actor.scope_dir(String(sc)).path_join(ActorFolder.STAMPS)
		parts.append("%d|%d" % [FileAccess.get_modified_time(p), FileAccess.get_size(p)] if FileAccess.file_exists(p) else "-")
	return ",".join(parts)


func _fill_rows(busy: bool) -> void:
	for step in _rows:
		var r: Dictionary = _rows[step]
		var row := _builder.row_of(String(step))
		var st := String(row["state"])
		var count := ""
		if ActorSteps.per(String(step)) == "video" and int(row["total"]) > 1:
			count = "%d/%d " % [int(row["made"]), int(row["total"])]
		var said := ""
		match st:
			"made":
				said = "✓ " + count + String(row["said"])
			"stale":
				said = "⚠ " + count + "stale - made from inputs that changed; still used until made again"
			"running":
				var p := float(row["progress"])
				said = "… " + count + ("%d%% " % int(p * 100.0) if p >= 0.0 else "") + String(row["said"])
			"failed":
				said = "✗ " + String(row["error"])
			"waiting":
				said = "waits for the sets"
			"moot":
				said = "– read in place" if step == "fetch" else "– no captions link"
			"unavailable":
				said = "– " + String(row["said"])
			_:
				said = "– " + count
		(r["state"] as Label).text = said
		(r["state"] as Label).tooltip_text = said + "\n\n" + String(Registry.field(ActorSteps.REGISTRY, step, "blurb", ""))
		(r["make"] as Button).disabled = busy or st == "running" or st == "unavailable"
		(r["redo"] as Button).disabled = busy or not (st == "made" or st == "stale" or st == "failed")


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
		var img := Image.load_from_file(String(d.get("sheet", ""))) if FileAccess.file_exists(String(d.get("sheet", ""))) else null
		if img != null:
			tex.texture = ImageTexture.create_from_image(img)
			tex.tooltip_text = "Click for the set's sheet"
			tex.mouse_filter = Control.MOUSE_FILTER_STOP
			tex.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and e.pressed:
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
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if img != null:
			tex.texture = ImageTexture.create_from_image(img)
		tex.modulate = Color(1, 1, 1, 1.0 if k == chosen else 0.55)
		tex.mouse_filter = Control.MOUSE_FILTER_STOP
		tex.tooltip_text = ("The still in use: every frame of the likeness is drawn on it." if k == chosen \
			else "Draw the likeness on this still instead (nothing is made again).") \
			+ ("\nAt rest found them at ease in it." if rest.has(k) else "")
		tex.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
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

	_body.add_child(_heading("Sources"))
	_sources_box = VBoxContainer.new()
	_body.add_child(_sources_box)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	_body.add_child(srow)
	var af := Button.new()
	af.text = "Add folder…"
	af.tooltip_text = "A folder of their videos: read where it is, never copied or written. Its videos are listed below, ticked."
	af.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	af.pressed.connect(_add_folder)
	srow.add_child(af)
	var al := Button.new()
	al.text = "Add link…"
	al.tooltip_text = "A video, a playlist or a whole channel: listed at once, then each video fetched (up to 1080p, with its automatic captions) by Generate, one at a time. A playlist added again fetches only what is new."
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.pressed.connect(_add_link)
	srow.add_child(al)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_videos_box = VBoxContainer.new()
	_videos_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_videos_box)

	_body.add_child(_heading("Steps"))
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 0)
	_body.add_child(steps)
	for step in ActorSteps.ORDER:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		steps.add_child(r)
		var name_l := Label.new()
		name_l.text = String(Registry.field(ActorSteps.REGISTRY, step, "label", step))
		name_l.custom_minimum_size.x = 64.0
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.tooltip_text = String(Registry.field(ActorSteps.REGISTRY, step, "blurb", ""))
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var make := Button.new()
		make.text = "▶"
		make.flat = true
		make.tooltip_text = "Make this step - and whatever it needs first - where it is missing or stale."
		make.pressed.connect(_make.bind(step))
		r.add_child(make)
		var redo := Button.new()
		redo.text = "⟳"
		redo.flat = true
		redo.tooltip_text = "Make this step again from scratch: what is made from it is marked stale."
		redo.pressed.connect(_redo.bind(step))
		r.add_child(redo)
		_rows[step] = {"state": state, "make": make, "redo": redo, "row": r}
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	_body.add_child(grow)
	_gen_btn = Button.new()
	_gen_btn.text = "Generate"
	_gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gen_btn.tooltip_text = "Make every step that is missing or stale, in order: the survey takes about a quarter of the footage's length in CPU, the rest a few minutes, and the audit the labeler's quota."
	_gen_btn.pressed.connect(_generate)
	grow.add_child(_gen_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.tooltip_text = "Stop now. What is finished is kept; a survey loses at most the video in hand."
	_stop_btn.pressed.connect(func() -> void:
		if _builder != null:
			_builder.stop())
	grow.add_child(_stop_btn)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 11)
	_line.modulate = Color(1, 1, 1, 0.7)
	_body.add_child(_line)

	_body.add_child(_heading("Sets"))
	_sets_box = VBoxContainer.new()
	_sets_box.add_theme_constant_override("separation", 6)
	_body.add_child(_sets_box)
	var sh := _heading("Still")
	sh.tooltip_text = ("The one frame of the set in use the likeness is drawn on - its head, eyes and mouth moved by what "
		+ "is learned of them. Their most typical calm moments, facing the camera; click another to use it.")
	sh.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(sh)
	_stills_box = HFlowContainer.new()
	_stills_box.add_theme_constant_override("h_separation", 4)
	_body.add_child(_stills_box)
	_library_head = _heading("Library")
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


static func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(1, 1, 1, 0.85)
	return l

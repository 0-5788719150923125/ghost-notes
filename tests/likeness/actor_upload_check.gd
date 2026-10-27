extends SceneTree

## actor_upload_check - an Actor's note as it goes up (next/likeness.md): the Actor card reads NO TITLE, and
## LISTS THE STEPS MADE FROM THE NOTE'S WORDS UNDER ITS OWN, beside its Generate (the user, 2026-10-23: "push
## the generate/regenerate step into the Actor card. Right now, it's buried at the bottom of the YouTube card").
##
##   godot --headless --path . --script tests/likeness/actor_upload_check.gd
##
## NO TITLE: the walk the card hands the reading announces none, and the plan's first passage is the note's
## own words (THE CONTROL: the same panel before the Actor card announces it, as a reader announces a chapter).
## THE TAGS STEP ON THE ACTOR CARD: with "Write each episode's tags" ticked its row is under the actor's steps,
## above Generate, the YouTube card's line names the Actor card, and the YouTube card draws no row of its own
## (THE CONTROL: the box clear, no row anywhere). GENERATE MAKES IT ONCE THE ACTOR'S OWN STEPS ARE DONE - not
## while they run - here refused, read-only, and said on its row; a job landed gives its ✓ and replaces the
## note's tags; Stop stops one. The actor's steps are made by the gate ([member ActorBuilder.make_with]): no
## program runs, and no agent - and a step made so is made at once, so a run still under way (as one waiting
## for an install is) is held by hand.
## A PICTURE ON THE CARD IS CLICKED by the left button's press alone (`ActorCard.clicked`): a wheel's notch, a release
## or the right button opens nothing (2026-10-23: scrolling over the sets opened dozens of their sheets).
## A VIDEO TICKED REBUILDS NO ROW (2026-10-23: every tick held the app for seconds while all of them were made again);
## TICK ALL AND UNTICK ALL set every box and the actor's file (THE CONTROL: a video added does make the rows again) -
## the card's sources and videos, a part it shares with the Voice training card ([ActorSourceList]).
## NOTHING OUTSIDE THE TEST ROOT: the actors in a library moved aside ([method Actors.use_for_test]), the note's
## folder under it, and no actor added to the author's library (its folders are only listed: the author's
## build may be writing inside one).

const ROOT := "user://actor_upload_check"
const WORDS := "The quick brown fox jumps over the lazy dog."

var _fails := 0
var _actor: ActorFolder
var _made := 0


func _init() -> void:
	# deferred: the panel and the card need the autoloads, which are only up once the tree is
	_run.call_deferred()


func _run() -> void:
	# A GATE NEVER WRITES THE SETTINGS OF WHOEVER RUNS IT, and starts no agent
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var real := _folders(ProjectSettings.globalize_path(Actors.ROOT))
	var note_upload = load("res://src/reading/note_upload.gd")
	var youtube = load("res://src/export/youtube.gd")
	var keep_readings: String = note_upload.root
	var keep_youtube: String = youtube.root
	Actors.use_for_test(ROOT)
	note_upload.root = ROOT + "/readings"
	youtube.root = ROOT + "/youtube"
	_check()
	note_upload.root = keep_readings
	youtube.root = keep_youtube
	_ok(_folders(ProjectSettings.globalize_path(Actors.ROOT)) == real, "no actor was added to the author's library")
	Actors._remove_tree(ProjectSettings.globalize_path(ROOT))
	print("actor_upload_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _check() -> void:
	# A PICTURE CLICKED: the left button's press; THE CONTROLS: the wheel's notches, a release, the right button
	var card_script = load("res://src/likeness/actor_card.gd")
	var press := func(button: MouseButton, down: bool) -> InputEventMouseButton:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = down
		return ev
	_ok(card_script.clicked(press.call(MOUSE_BUTTON_LEFT, true)) and not card_script.clicked(press.call(MOUSE_BUTTON_WHEEL_DOWN, true))
		and not card_script.clicked(press.call(MOUSE_BUTTON_WHEEL_UP, true)) and not card_script.clicked(press.call(MOUSE_BUTTON_LEFT, false))
		and not card_script.clicked(press.call(MOUSE_BUTTON_RIGHT, true)) and not card_script.clicked(InputEventMouseMotion.new()),
		"a picture is clicked by the left button's press alone, never by the wheel")
	# AN ACTOR WITH TWO VIDEOS (a few bytes is a video to the library, which reads only their names)
	var footage := ProjectSettings.globalize_path(ROOT).path_join("footage_in")
	DirAccess.make_dir_recursive_absolute(footage)
	for n in ["First talk.mp4", "Second talk.mkv"]:
		var f := FileAccess.open(footage.path_join(n), FileAccess.WRITE)
		f.store_string("not really a video " + n)
		f.close()
	var made := Actors.create("Someone")
	ActorSources.add_folder(made, footage)
	made.save()

	# THE NOTE, read by a panel built by hand (its _ready would start the voice host)
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "reading"
	ed._build_panel()
	ed._doc._sync = false
	ed._doc._fields = {"title": "A Reading", "tags": "readings, voice"}
	ed.note_path = ROOT + "/notes/A Reading.md"
	ed._text.text = WORDS
	var plan = load("res://src/reading/reading_plan.gd")
	var before: Dictionary = ed._reading_of(WORDS)
	var opens := String(plan.passages(String(before["body"]), String(before["title"]), {"hesitate": false})[0]["text"])
	_ok(String(before["title"]) == "A Reading" and opens.contains("A Reading"),
		"control: a reading with no Actor announces the note's title first (%s)" % opens.strip_edges().get_slice("\n", 0))

	var card = load("res://src/likeness/actor_card.gd").for_note({"workspace": ed})
	card.apply({"id": made.id})
	# A VIDEO TICKED REBUILDS NO ROW; TICK ALL AND UNTICK ALL TAKE EVERY ONE
	card._refresh()
	var rows_before: Array = card._sources._videos_box.get_children()
	var first_vid := String(card._sources._ticks.keys()[0])
	(card._sources._ticks[first_vid] as CheckBox).button_pressed = false
	card._refresh()
	_ok(card._sources._videos_box.get_children() == rows_before and not bool(card._actor.video(first_vid)["ticked"]),
		"a video unticked made the rows again, or was not unticked")
	card._sources.tick_all(false)
	var none_on: bool = card._sources._ticks.values().all(func(c: CheckBox) -> bool: return not c.button_pressed) \
		and Actors.open(made.id).ticked().is_empty()
	card._sources.tick_all(true)
	var all_on: bool = card._sources._ticks.values().all(func(c: CheckBox) -> bool: return c.button_pressed) \
		and Actors.open(made.id).ticked().size() == card._sources._ticks.size()
	_ok(none_on and all_on, "Untick all or Tick all left a box or the actor's file as it was")
	var more := ProjectSettings.globalize_path(ROOT).path_join("footage_in").path_join("Third talk.mp4")
	var fa := FileAccess.open(more, FileAccess.WRITE)
	fa.store_string("not really a video")
	fa.close()
	ActorSources.rescan(card._actor)
	card._refresh()
	_ok(card._sources._videos_box.get_children() != rows_before, "CONTROL: a video added did not make the rows again")
	_actor = card._actor
	card._builder.make_with = _make
	var said: Dictionary = ed._reading_of(WORDS)
	opens = String(plan.passages(String(said["body"]), String(said["title"]), {"hesitate": false})[0]["text"])
	_ok(String(said["title"]).is_empty() and not opens.contains("A Reading") and opens.contains("quick brown fox"),
		"the actor announces no title: their first words are the note's (%s)" % opens.strip_edges())

	ed._attach("youtube")
	var up = ed._note_upload
	_ok(up != null and ed._youtube._desc.visible and not up.hosting(),
		"the note is its own episode on the YouTube card (its description box), and the Actor card lists its steps")
	var step = ed._youtube.episode_steps()[0]
	_tick(card, up)
	_ok(card._step_rows.is_empty() and up._step_rows.is_empty() and step.host.is_empty(),
		"control: with \"Write each episode's tags\" clear, no row anywhere")

	ed._youtube._write_tags.button_pressed = true
	_tick(card, up)
	var feed = up.feed()
	_ok(step.host == "the Actor card" and step.shown == feed and card._step_rows.has(step.key) and up._step_rows.is_empty(),
		"ticked: its row is on the Actor card, the note its episode, and the YouTube card draws none")
	_ok(card._step_box.get_parent() == card._body and card._step_box.get_index() < card._gen_btn.get_parent().get_index(),
		"the row stands under the actor's steps, above Generate")
	ed._youtube._refresh_tags()
	var line: String = ed._youtube._tags_note.text
	_ok(line.contains("Tags row on the Actor card") and line.ends_with("and so does Generate, or an export that goes up."),
		"the YouTube card says where the row is and what makes it (%s)" % line)

	# GENERATE: the actor's own steps first, then the note's tags
	card._generate()
	_ok(_made > 0 and not card._builder.running, "Generate makes the actor's steps (%d, by the gate)" % _made)
	card._builder.running = true
	_tick(card, up)
	_ok(step.state(feed) == "missing" and card._gen_btn.disabled and not card._stop_btn.disabled,
		"while the actor's steps run, the tags wait for them (%s)" % step.state(feed))
	card._builder.running = false
	_tick(card, up)
	var r: Dictionary = card._step_rows[step.key]
	_ok(step.state(feed) == "failed" and (r["state"] as Label).text.contains("read-only"),
		"then Generate starts the tags - here refused, read-only, and said on the Actor card's row (%s)" % (r["state"] as Label).text)

	# A JOB LANDED: its ✓, and the note's tags replaced
	step._errors.clear()
	AgentJobs._ended["text-actor-upload-check"] = {"ok": true, "text": "{\"tags\": [\"quick brown fox\", \"lazy dog\", \"reading\"]}"}
	step._jobs[feed.folder()] = {"id": "text-actor-upload-check", "feed": feed, "stamp": feed.stamp()}
	card._refresh()
	_ok(card._steps_busy() and card._gen_btn.disabled and not card._stop_btn.disabled and (r["redo"] as Button).disabled,
		"while its job runs: Generate and its ⟳ wait, Stop is offered")
	_tick(card, up)
	_ok((r["state"] as Label).text == "✓ 3 tags: quick brown fox, lazy dog, reading" and not (r["redo"] as Button).disabled
		and ed._doc.field("tags") == "quick brown fox, lazy dog, reading" and not card._gen_btn.disabled,
		"landed: its ✓ on the Actor card, and the note's tags replaced (%s)" % (r["state"] as Label).text)

	# STOP stops a job writing them
	step._jobs[feed.folder()] = {"id": "text-actor-upload-check-2", "feed": feed, "stamp": feed.stamp()}
	card._stop_btn.pressed.emit()
	_ok(not step.busy(feed) and not card._steps_busy(), "Stop stops the tags being written")

	# WORDS WRITTEN AGAIN: stale, and the row says what makes them again
	ed._text.text = "Words written again."
	_tick(card, up)
	_ok(step.state(feed) == "missing" and (r["state"] as Label).text.contains("so does Generate, or an export that goes up"),
		"words written again make them stale, and the row says Generate makes them again (%s)" % (r["state"] as Label).text)
	card.free()
	ed.free()


## A refresh of the note and the card, as their _process makes one.
func _tick(card: Object, up: Object) -> void:
	up.refresh()
	card._tick_steps()
	card._refresh()


## A step "made": its outputs written as made-up files - and the sets and the audit with one set.
func _make(step: String, scope: String) -> String:
	_made += 1
	var dir := _actor.scope_dir(scope)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ActorSteps.outputs(step):
		var p := dir.path_join(String(f))
		if String(f).get_extension().is_empty():
			DirAccess.make_dir_recursive_absolute(p)
			continue
		var text := "{}"
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		if String(f) == "sets.json" or String(f) == "audit.json":
			text = JSON.stringify({"sets": [{"id": "set-made", "usable": 5.0, "minutes": 6.0, "shots": [], "size": [64, 36]}]})
		var fa := FileAccess.open(p, FileAccess.WRITE)
		fa.store_string(text)
		fa.close()
	return ""


## The folders directly under [param dir]: the actors a library holds.
static func _folders(dir: String) -> Array:
	var out := Array(DirAccess.get_directories_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	out.sort()
	return out

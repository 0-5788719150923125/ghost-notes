extends SceneTree

## voice_training_check - the Voice training card (next/likeness.md, "A voice alone"): a person whose voice is all
## that is learned of them, from their own recordings, and the note reading in it (the user, 2026-10-26: "a new
## component/card ... to fine-tune a new voice for that component ... importing a video from file, or by pointing to
## a YouTube URL or playlist URL").
##
##   godot --headless --path . --script tests/likeness/voice_training_check.gd
##
## A VOICE ALONE IS LISTED APART: the card offers the voices alone and the Actor card the actors (THE CONTROL: each
## is the other's - the actor on the Actor card, the voice on this one).
## ITS FOLDERS' SOUND FILES ARE ITS RECORDINGS: a folder of a video, a sound file and a text file gives a voice alone
## two rows (THE CONTROL: the same folder gives an actor one, the video). A FILE PICKED BY ITSELF is a row; picked
## again, or already in a folder of theirs, it is none.
## A LINK IS FETCHED AS ITS SOUND: no picture and no captions, kept in the archive (THE CONTROL: an actor's fetch
## takes the picture and the captions), and the sound file it leaves is what was fetched (a `.part` is not).
## GENERATE MAKES THEIR VOICE AND NOTHING ELSE: each recording's probe and Hear, Kokoro's Utterances and Voice, in that
## order - and a run that asks for every step makes no more of a voice alone (THE CONTROL: on an actor it makes
## the survey, and its voice is Piper's, never Kokoro's). The steps are made by the gate ([member
## ActorBuilder.make_with]): no program runs. Their voice's id is Kokoro's ("kokoro-<id>", an actor's "actor-<id>").
## THE NOTE READS IN IT: Read in it waits for the voice, then hands the reading its id; a voice landing does the
## same (THE CONTROL: before either, the reading has no voice made to read in).
## NOTHING OUTSIDE THE TEST ROOT: the actors in a library moved aside ([method Actors.use_for_test]), and no actor
## added to the author's library (its folders are only listed: the author's build may be writing inside one).

const ROOT := "user://voice_training_check"

var _fails := 0
var _made: Array = []
var _folder: ActorFolder


func _init() -> void:
	# deferred: the panel and the cards need the autoloads, which are only up once the tree is
	_run.call_deferred()


func _run() -> void:
	# A GATE NEVER WRITES THE SETTINGS OF WHOEVER RUNS IT, and starts no agent
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var real := _folders(ProjectSettings.globalize_path(Actors.ROOT))
	Actors.use_for_test(ROOT)
	_check()
	_ok(_folders(ProjectSettings.globalize_path(Actors.ROOT)) == real, "no actor was added to the author's library")
	Actors._remove_tree(ProjectSettings.globalize_path(ROOT))
	print("voice_training_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1


func _check() -> void:
	var base := ProjectSettings.globalize_path(ROOT)
	var rec := base.path_join("recordings")
	DirAccess.make_dir_recursive_absolute(rec)
	for n in ["A talk.mp4", "A podcast.m4a", "notes.txt"]:
		_write(rec.path_join(n), "not really a recording " + n)
	var single := base.path_join("Interview.mp3")
	_write(single, "not really a recording")

	# LISTED APART
	var voice := Actors.create("Someone", "voice")
	var actor := Actors.create("Someone Else")
	var ids := func(kind: String) -> Array: return Actors.list(kind).map(func(a: Dictionary) -> String: return String(a["id"]))
	_ok(voice.sound_only() and not actor.sound_only() and ids.call("voice") == [voice.id] and ids.call("actor") == [actor.id],
		"a voice alone is listed apart from the actors (voices %s, actors %s)" % [ids.call("voice"), ids.call("actor")])

	# ITS RECORDINGS: a folder's sound files, and a file by itself
	ActorSources.add_folder(voice, rec)
	ActorSources.add_folder(actor, rec)
	actor.save()
	var titles := func(a: ActorFolder) -> Array:
		var out := a.videos().values().map(func(v: Dictionary) -> String: return String(v["title"]))
		out.sort()
		return out
	_ok(titles.call(voice) == ["A podcast", "A talk"], "a voice alone's folder lists its videos and sound files (%s)" % [titles.call(voice)])
	_ok(titles.call(actor) == ["A talk"], "CONTROL: an actor's folder lists its videos alone (%s)" % [titles.call(actor)])
	var first := ActorSources.add_file(voice, single)
	var again := ActorSources.add_file(voice, single)
	var inside := ActorSources.add_file(voice, rec.path_join("A podcast.m4a"))
	_ok(first == 1 and again == 0 and inside == 0 and voice.videos().size() == 3,
		"a file picked by itself is a row; picked again, or in a folder of theirs, none (%d, %d, %d)" % [first, again, inside])
	voice.save()

	# A LINK FETCHED AS ITS SOUND
	var sound := Array(ActorSources.fetch_args("https://example.com/v", "/footage", false, "", true))
	var picture := Array(ActorSources.fetch_args("https://example.com/v", "/footage", false, "", false))
	_ok(sound.has(ActorSources.SOUND_FORMAT) and not sound.has(ActorSources.FORMAT) and not sound.has("--write-auto-subs")
		and sound.has("--download-archive") and sound.has("--write-info-json"),
		"a voice alone's link is fetched as its sound: no picture, no captions, kept in the archive")
	_ok(picture.has(ActorSources.FORMAT) and picture.has("--write-auto-subs") and not picture.has(ActorSources.SOUND_FORMAT),
		"CONTROL: an actor's link is fetched with its picture and captions")
	var footage := base.path_join("footage")
	DirAccess.make_dir_recursive_absolute(footage)
	_write(footage.path_join("abc123.m4a.part"), "half")
	var half := ActorSources.fetched(footage, "abc123")
	_write(footage.path_join("abc123.m4a"), "whole")
	_write(footage.path_join("abc123.info.json"), "{}")
	var got := ActorSources.fetched(footage, "abc123")
	_ok(String(half["video"]).is_empty() and String(got["video"]).ends_with("abc123.m4a"),
		"the sound file a fetch leaves is what was fetched, its .part never (%s)" % String(got["video"]).get_file())

	# THE CARD, on a reading built by hand (its _ready would start the voice host)
	var ed = load("res://src/reading/reading_panel.gd").new()
	ed.workspace = "reading"
	ed._build_panel()
	ed._doc._sync = false
	var card = load("res://src/likeness/voice_training_card.gd").for_note({"workspace": ed})
	card.apply({"id": voice.id})
	var actor_card = load("res://src/likeness/actor_card.gd").for_note({})
	actor_card.apply({"id": actor.id})
	_ok(card._picked.has(voice.id) and not card._picked.has(actor.id) and card._voice != null and card._voice.id == voice.id,
		"the card offers the voices alone, and opens the note's")
	_ok(actor_card._picked.has(actor.id) and not actor_card._picked.has(voice.id),
		"CONTROL: the Actor card offers the actors, not the voice")
	card._refresh()
	_ok(card._read_btn.disabled and String(ed._cast._made_voice).is_empty(),
		"CONTROL: before their voice is made, Read in it waits and the reading has no voice made")

	# GENERATE: their voice and nothing else
	_folder = card._voice
	card._builder.make_with = _make
	card._generate()
	var steps := _steps_made()
	var chain := ["probe", "hear", "kokoro_utterances", "kokoro_voice"]
	_ok(steps == chain and _made.filter(func(m: String) -> bool: return m.begins_with("probe|")).size() == 3
		and not card._builder.running,
		"Generate makes each recording's probe and Hear, Kokoro's Utterances, then its Voice - nothing else (%s)" % [steps])
	var order := _made.map(func(m: String) -> String: return m.get_slice("|", 0))
	_ok(order.rfind("probe") < order.find("hear") and order.rfind("hear") < order.find("kokoro_utterances")
		and order.find("kokoro_utterances") < order.find("kokoro_voice"), "in the order each needs the last")
	_made.clear()
	card._builder.redo("hear")
	card._builder.start()
	var everything := _steps_made()
	_ok(not everything.is_empty() and everything.all(func(st: String) -> bool: return ActorSteps.voice_chain().has(st)),
		"a run that asks for every step makes no more of a voice alone (%s)" % [everything])
	_made.clear()
	_folder = actor_card._actor
	actor_card._builder.make_with = _make
	actor_card._builder.start()
	var acted := _steps_made()
	_ok(acted.has("survey") and acted.has("voice") and not acted.has("kokoro_voice") and not acted.has("kokoro_utterances"),
		"CONTROL: on an actor, every step is every step - the survey made, its voice Piper's and never Kokoro's")
	_ok(ActorBuilder.voice_id(voice) == "kokoro-" + voice.id and ActorBuilder.voice_id(actor) == "actor-" + actor.id,
		"a voice alone's id is Kokoro's, an actor's Piper's")

	# THE NOTE READS IN IT
	card._refresh()
	_ok(not card._read_btn.disabled, "once their voice is made, Read in it is offered")
	card._read_btn.pressed.emit()
	var id := ActorBuilder.voice_id(voice)
	_ok(String(ed._cast._made_voice) == id, "Read in it hands the reading their voice (%s)" % ed._cast._made_voice)
	ed._cast._made_voice = ""
	card._builder.voice_published.emit(id)
	_ok(String(ed._cast._made_voice) == id, "a voice landing is read in as it lands")
	card.free()
	actor_card.free()
	ed.free()


## The steps made since the last clear, once each, in the order first made.
func _steps_made() -> Array:
	var out: Array = []
	for m in _made:
		var st := String(m).get_slice("|", 0)
		if not out.has(st):
			out.append(st)
	return out


## A step "made": its outputs written as made-up files.
func _make(step: String, scope: String) -> String:
	_made.append("%s|%s" % [step, scope])
	var dir := _folder.scope_dir(scope)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ActorSteps.outputs(step):
		var p := dir.path_join(String(f))
		if String(f).get_extension().is_empty():
			DirAccess.make_dir_recursive_absolute(p)
			continue
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		var text := "{}"
		if String(f) == "sets.json" or String(f) == "audit.json":
			text = JSON.stringify({"sets": [{"id": "set-made", "usable": 5.0, "minutes": 6.0, "shots": [], "size": [64, 36]}]})
		_write(p, text)
	return ""


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## The folders directly under [param dir]: the actors a library holds.
static func _folders(dir: String) -> Array:
	var out := Array(DirAccess.get_directories_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	out.sort()
	return out

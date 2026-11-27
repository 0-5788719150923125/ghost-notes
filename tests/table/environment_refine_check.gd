extends SceneTree

## A sound round a scene refined, and its versions ([EnvironmentSoundDesign], [EnvironmentSoundTools], [ElementVersions],
## [SoundMeasure], the Tone of [Soundscape]; next/environment.md, "Refining a sound"), with no agent and no renderer.
##
##   godot --headless --path . --script res://tests/table/environment_refine_check.gd
##
## - What a sound measures: a sine's brightness its pitch, a louder one louder, noise low-passed darker than noise as it is (the
##   control), clicks counted as sudden rises and steady noise none (the control), a sound on the right leaning right.
## - Tone: a sound told 0 is the sound told nothing, sample for sample; told dark it measures darker than told bright (the control).
## - A wind round a note's own scene is heard (the control: made with no wind planned, as the card once made it, it is silent).
## - Versions: kept in order, the one used found, one already kept chosen again and not kept twice, made the element again; a session
##   that may not write the author's folders keeps none outside a gate's own (the control).
## - The designer's text and what lands from it: a property changed lands, one left alone stays drawn by the element's number (the
##   control: one changed is set), a hand's change meanwhile is kept, a word of its own added and taken out, a key it does not know and
##   a value past its bounds told, text that is no JSON object refused.
## - On the card: a heard element has Refine… and a light none (the control); Refine… docks its conversation beside the cards in
##   their panel ([RefineDock]), never a window, its verb pressed while open and not once folded (the control); a turn
##   that changes the sound keeps how it was and what it became, puts it in place and offers both on its Version picker; picking the
##   first makes it that again; a turn that changes nothing keeps nothing (the control). Hear tells the draft's numbers, and refuses a
##   draft that is no JSON object (the control).
## - What the designer is told renders whole, for a sound with words of its own and a creature's calls.

const ROOT := "user://environment_refine_check"
## The panel and the card, by path: each names autoloads, which resolve only once the tree is up.
const PANEL := "res://src/reading/reading_panel.gd"
const CARD := "res://src/table/environment_card.gd"
const SIDE := "res://src/ui/side_panel.gd"
const RATE := 22050

var _fails := 0


class Words extends Node:
	var document := {}


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + what)


func _run() -> void:
	await process_frame
	var was_library := Library.root
	Library.root = ROOT.path_join("library")
	ElementVersions.root_aside = ROOT
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_measure()
	_tone()
	await _wind()
	_versions()
	_landing()
	await _card()
	_told()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = was_library
	ElementVersions.root_aside = ""
	print("environment_refine_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


# --- what a sound measures -----------------------------------------------------------------------------------------------

func _measure() -> void:
	var sine := func(f: float, a: float, secs: float) -> PackedVector2Array:
		var x := PackedVector2Array()
		x.resize(int(secs * RATE))
		for i in x.size():
			var v := a * sin(TAU * f * float(i) / RATE)
			x[i] = Vector2(v, v)
		return x
	var m := SoundMeasure.measure(sine.call(1000.0, 0.3, 2.0), RATE)
	_ok(absf(float(m["bright"]) - 1000.0) < 20.0, "a sine's brightness is its pitch (%s)" % str(m["bright"]))
	var louder := SoundMeasure.measure(sine.call(1000.0, 0.6, 2.0), RATE)
	_ok(absf(float(louder["db"]) - float(m["db"]) - 6.02) < 0.2, "twice as loud is 6 dB louder (%s, %s)" % [str(m["db"]), str(louder["db"])])
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var noise := PackedVector2Array()
	var dull := PackedVector2Array()
	noise.resize(RATE * 2)
	dull.resize(RATE * 2)
	var lp := 0.0
	for i in noise.size():
		var v := r.randf_range(-0.3, 0.3)
		lp += 0.05 * (v - lp)
		noise[i] = Vector2(v, v)
		dull[i] = Vector2(lp, lp)
	var bright := SoundMeasure.measure(noise, RATE)
	var dark := SoundMeasure.measure(dull, RATE)
	_ok(float(dark["bright"]) < float(bright["bright"]) * 0.5 and float(dark["high"]) < float(bright["high"]),
		"noise low-passed measures darker, less of it high (%s / %s Hz)" % [str(dark["bright"]), str(bright["bright"])])
	_ok(float(bright["events"]) < 0.5, "the control: steady noise has no sudden rises (%s a second)" % str(bright["events"]))
	var clicks := PackedVector2Array()
	clicks.resize(RATE * 4)
	for i in clicks.size():
		var v := r.randf_range(-0.002, 0.002)
		if i % (RATE / 4) < 40:
			v = 0.5 * (1.0 if i % 2 == 0 else -1.0)
		clicks[i] = Vector2(v, v)
	var ev := SoundMeasure.measure(clicks, RATE)
	_ok(absf(float(ev["events"]) - 4.0) < 0.6, "clicks four times a second are four sudden rises a second (%s)" % str(ev["events"]))
	var right := PackedVector2Array()
	for v in sine.call(500.0, 0.3, 1.0):
		right.append(Vector2(v.x * 0.25, v.y))
	_ok(float(SoundMeasure.measure(right, RATE)["balance"]) > 10.0, "a sound on the right leans right")
	_ok(SoundMeasure.text(m).contains("loudness") and SoundMeasure.text(SoundMeasure.measure(PackedVector2Array(), RATE)).contains("silent"),
		"told in lines, silence said as silence")


# --- Tone ------------------------------------------------------------------------------------------------------------------

func _tone() -> void:
	var made := func(extra: Dictionary) -> PackedVector2Array:
		var sound := Soundscape.sanitize({"rain": {"on": "roof", "strength": 0.6}.merged(extra)})
		var sc := Soundscape.new(sound, {}, 11, RATE, 0.0)
		sc.set_level(Surroundings.BED_LEVEL)
		return sc.render(RATE * 4)
	var plain: PackedVector2Array = made.call({})
	_ok(plain == made.call({"tone": 0.0}), "a sound told Tone 0 is the sound told nothing, sample for sample")
	var dark := SoundMeasure.measure(made.call({"tone": -0.8}), RATE, 2.0)
	var bright := SoundMeasure.measure(made.call({"tone": 0.8}), RATE, 2.0)
	_ok(float(dark["bright"]) < float(bright["bright"]) * 0.7, "told dark it measures darker than told bright (%s / %s Hz)"
		% [str(dark["bright"]), str(bright["bright"])])
	var el := Surroundings.element({"kind": "rain", "seed": 3, "tone": 2.0})
	_ok(is_equal_approx(float(el["tone"]), 1.0) and Surroundings.fields_of("creature").has("tone") and Surroundings.line_of(el).contains("brighter"),
		"every sound has a Tone, held to its bounds and said on its line")
	var cr := Soundscape.sanitize({"creatures": [{"calls": ["coo"], "tone": -0.5}]})
	_ok(is_equal_approx(float((cr["creatures"] as Array)[0].get("tone", 0.0)), -0.5), "a creature keeps its own Tone")


# --- a wind round a note's own scene ---------------------------------------------------------------------------------------

func _wind() -> void:
	await process_frame
	var card_script: GDScript = load(CARD)
	var spec := {"elements": [Surroundings.element({"kind": "wind", "seed": 5})]}
	var made: Dictionary = card_script.call("heard", spec)
	_ok(not (made["wind"] as Dictionary).is_empty(), "a note's wind is planned a wind to blow")
	var heard := SoundMeasure.measure((card_script.call("made_bed", made, RATE, 0.0) as Soundscape).render(RATE * 4), RATE, 2.0)
	_ok(float(heard["db"]) > -80.0, "a wind round a note's own scene is heard (%s dB)" % str(heard["db"]))
	var none := Soundscape.new(made["sound"], {}, int(made["seed"]), RATE, 0.0)
	_ok(float(SoundMeasure.measure(none.render(RATE * 4), RATE, 2.0)["db"]) <= -100.0, "the control: made with no wind planned, it is silent")


# --- versions --------------------------------------------------------------------------------------------------------------

func _versions() -> void:
	var dir := ROOT.path_join("versions")
	var a := Surroundings.element({"kind": "fire", "seed": 1, "size": 0.3})
	var b := Surroundings.element({"kind": "fire", "seed": 1, "size": 0.8, "name": "Hearth", "off": true})
	_ok(ElementVersions.versions(dir).is_empty() and ElementVersions.used(dir) == -1 and ElementVersions.of(dir, a) == -1, "none kept: none")
	_ok(ElementVersions.add(dir, a, "", "") == 0 and ElementVersions.add(dir, b, "a bigger fire", "claude opus") == 1, "kept in order")
	var kept: Dictionary = (ElementVersions.versions(dir)[1] as Dictionary)["element"]
	_ok(not kept.has("name") and not kept.has("off") and ElementVersions.used(dir) == 1, "a version is what it is, never its name or whether it is aside")
	_ok(ElementVersions.of(dir, b) == 1 and ElementVersions.of(dir, a) == 0, "which version an element is, whatever its name")
	_ok(ElementVersions.add(dir, a, "again", "") == 0 and ElementVersions.versions(dir).size() == 2 and ElementVersions.used(dir) == 0,
		"one kept already is chosen again, not kept twice")
	_ok(float(ElementVersions.use(dir, 1).get("size", 0.0)) == 0.8 and ElementVersions.used(dir) == 1, "a version made the one used, its element given")
	_ok(ElementVersions.use(dir, 5).is_empty(), "no such version: nothing")
	_ok(ElementVersions.label_of(dir, 0).begins_with("1  ·  as it was") and ElementVersions.label_of(dir, 1).contains("a bigger fire")
		and ElementVersions.label_of(dir, 1).contains("claude opus"), "labeled by what asked for it and who made it")
	ElementVersions._held.clear()
	_ok(ElementVersions.versions(dir).size() == 2 and ElementVersions.used(dir) == 1, "read again from its file, the same")
	_ok(ElementVersions.add("user://environment_refine_elsewhere", a, "", "") == -1
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://environment_refine_elsewhere")),
		"the control: outside a gate's own folder a read-only session keeps none")


# --- the designer's text and what lands from it ---------------------------------------------------------------------------

func _landing() -> void:
	var el := Surroundings.element({"kind": "wind", "seed": 21, "through": "trees"})
	var text := EnvironmentSoundDesign.text_of(el)
	var d: Variant = JSON.parse_string(text)
	_ok(d is Dictionary and String(d["through"]) == "trees" and (d as Dictionary).has("level") and (d as Dictionary).has("tone")
		and (d as Dictionary).has("volume"), "the text is every property as it is now (%s)" % text)
	(d as Dictionary)["tone"] = -0.4
	var got := EnvironmentSoundDesign.landed(el, el, JSON.stringify(d))
	var made: Dictionary = got.get("element", {})
	_ok(is_equal_approx(float(made.get("tone", 0.0)), -0.4) and not made.has("level") and String(made.get("through", "")) == "trees",
		"a property changed lands; one left alone stays drawn by its number (%s)" % str(made))
	(d as Dictionary)["level"] = float(d["level"]) + 0.2
	_ok(EnvironmentSoundDesign.landed(el, el, JSON.stringify(d))["element"].has("level"), "the control: one changed is set")
	var hand := el.duplicate(true)
	hand["volume"] = -6.0
	var meanwhile: Dictionary = EnvironmentSoundDesign.landed(el, hand, JSON.stringify(d))["element"]
	_ok(float(meanwhile["volume"]) == -6.0 and is_equal_approx(float(meanwhile["tone"]), -0.4), "a hand's change meanwhile is kept beside the designer's")
	(d as Dictionary)["from"] = "left"
	(d as Dictionary)["thunder"] = 1
	(d as Dictionary)["tone"] = 3.0
	got = EnvironmentSoundDesign.landed(el, el, JSON.stringify(d))
	made = got["element"]
	_ok(String((made.get("own", {}) as Dictionary).get("from", "")) == "left", "a word of its own added (%s)" % str(made.get("own")))
	_ok((got["unknown"] as Array) == ["thunder"] and (got["held"] as Array).size() == 1 and String(got["held"][0]).begins_with("tone"),
		"a key it does not know and a value past its bounds are told (%s %s)" % [str(got["unknown"]), str(got["held"])])
	var with_from := made
	(d as Dictionary).erase("from")
	_ok(not (EnvironmentSoundDesign.landed(with_from, with_from, JSON.stringify(d))["element"].get("own", {}) as Dictionary).has("from"),
		"a word of its own taken out is gone")
	_ok(EnvironmentSoundDesign.landed(el, el, "the wind, but softer").has("error") and EnvironmentSoundDesign.landed(el, el, "[1, 2]").has("error"),
		"text that is no JSON object is refused")


# --- on the card -----------------------------------------------------------------------------------------------------------

func _card() -> void:
	var panel: Node = (load(PANEL) as GDScript).new()
	panel.subtitles = Words.new()
	var note := ROOT.path_join("note")
	var card: Control = (load(CARD) as GDScript).call("for_note", {"workspace": panel, "folder": note})
	# (the card stands in a side panel, as in the app: a Refine docks there)
	var side: Control = (load(SIDE) as GDScript).new(380.0)
	root.add_child(side)
	(side.get("body") as Node).add_child(card)
	await process_frame
	card.apply({"elements": [{"kind": "light", "preset": "dusk", "seed": 2}, {"kind": "stream", "seed": 8, "size": 0.4}]})
	var sec: PropSection = card.get("section")
	var verbs := func(i: int) -> Array:
		return ((sec.rows()[i] as Dictionary)["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"]))
	_ok((verbs.call(1) as Array).has("refine") and not (verbs.call(0) as Array).has("refine"), "a heard element has Refine…; the control: a light none")
	_ok(not (verbs.call(1) as Array).has("version"), "with no versions yet, no Version picker")
	var pressed := func() -> bool:
		for v in ((sec.rows()[1] as Dictionary)["verbs"] as Array):
			if String((v as Dictionary)["key"]) == "refine":
				return (v as Dictionary).get("pressed") == true
		return false
	_ok(sec.act("el:1", "refine").is_empty(), "Refine… opens")
	var refines := side.find_children("*", "", true, false).filter(func(c: Node) -> bool: return c is TextRefine)
	var folder: String = sec.call("sound_folder", sec.call("elements"), 1)
	_ok(refines.size() == 1 and (refines[0] as Node).get_window() == root and bool(side.call("docked", refines[0])) and pressed.call()
		and folder == note.path_join("refine").path_join("environment-stream-1"),
		"its conversation docked beside the cards in their panel, never a window, kept in the note's folder")
	_ok(sec.act("el:1", "refine").is_empty() and refines.size() == 1 and not RefineDock.is_open(refines[0]) and not pressed.call(),
		"the control: pressed again it folds away, its verb no longer pressed")
	var d := EnvironmentSoundDesign.live(folder)
	_ok(d != null and d.element_of.is_valid() and String(d.element_of.call().get("kind", "")) == "stream", "its designer stands for the stream")
	var before: Dictionary = card.capture()["elements"][1]
	# a turn: the designer shown the stream, asked, changing its tone, and done
	var draft := JSON.parse_string(d.call("_read")) as Dictionary
	draft["tone"] = -0.5
	d.draft = JSON.stringify(draft, "\t", false)
	var heard: Dictionary = await d.hear(5.0)
	_ok(String(heard.get("text", "")).contains("It is:") and String(heard.get("text", "")).contains("loudness"), "hear tells the draft's numbers")
	_ok(not (d.heard as Dictionary).is_empty(), "what it heard is kept to show")
	_turn(d, "darker, please")
	var now: Dictionary = card.capture()["elements"][1]
	_ok(is_equal_approx(float(now.get("tone", 0.0)), -0.5) and float(now.get("size", 0.0)) == 0.4, "a turn that changed it puts it in place (%s)" % str(now))
	var vs := ElementVersions.versions(folder)
	_ok(vs.size() == 2 and String((vs[1] as Dictionary)["note"]) == "darker, please" and String((vs[1] as Dictionary)["by"]) == "claude opus",
		"how it was and what it became are kept (%d)" % vs.size())
	var picker: Dictionary = {}
	for v in ((sec.rows()[1] as Dictionary)["verbs"] as Array):
		if String((v as Dictionary)["key"]) == "version":
			picker = v
	_ok((picker.get("choices", []) as Array).size() == 2 and String(picker.get("chosen", "")) == "1", "its Version picker offers both, the new one chosen")
	_ok(sec.act("el:1", "version:0").is_empty() and EnvironmentLibrary.what(card.capture()["elements"][1]) == EnvironmentLibrary.what(before),
		"picking the first makes it that again")
	sec.set_field("el:1", "volume", -3.0)
	picker = {}
	for v in ((sec.rows()[1] as Dictionary)["verbs"] as Array):
		if String((v as Dictionary)["key"]) == "version":
			picker = v
	_ok(String(picker.get("chosen", "x")).is_empty() and (picker["choices"] as Array).size() == 3, "changed by hand since: offered as it is now, none chosen")
	# the control: a turn that changes nothing keeps nothing
	d.call("_read")
	_turn(d, "is it fine?")
	_ok(ElementVersions.versions(folder).size() == 2, "the control: a turn that changes nothing keeps nothing")
	d.call("_read")
	d.draft = "not a sound"
	_ok((await d.hear(5.0)).has("error"), "the control: hear refuses a draft that is no JSON object")
	side.queue_free()
	panel.free()
	await process_frame


## A turn of [param d] ended, asked as [param you]: what the conversation does when its writer is done.
func _turn(d: EnvironmentSoundDesign, you: String) -> void:
	d.chat.turns.append({"you": you, "agent": "claude", "model": "opus", "effort": "", "at": 0, "events": [], "reply": "done", "usage": {},
		"error": "", "running": false})
	d.set("_working", true)
	d.call("_on_chat")


# --- what the designer is told ---------------------------------------------------------------------------------------------

func _told() -> void:
	Rules.missing = PackedStringArray()
	var texts: Array = []
	for el in [Surroundings.element({"kind": "wind", "seed": 1}), Surroundings.element({"kind": "creature", "seed": 2})]:
		var d := EnvironmentSoundDesign.at(ROOT.path_join("told").path_join(String(el["kind"])))
		var e: Dictionary = el
		d.element_of = func() -> Dictionary: return e
		d.title = "A night"
		var info := d.about()
		texts.append(WriterChat.system_of(info, true, "sound/environment"))
		texts.append(WriterChat.system_of(info, false, "sound/environment"))
		texts.append(WriterChat.first_message(info, EnvironmentSoundDesign.text_of(el), "softer", "THE AUTHOR: before", "", "sound/environment"))
		texts.append(WriterChat.turn_message("{\"a\": 1}", "{\"a\": 2}", "softer", "sound/environment"))
	_ok(Rules.missing.is_empty(), "what the designer is told leaves nothing unfilled: %s" % str(Rules.missing))
	var all := "\n".join(PackedStringArray(texts))
	_ok(not all.contains("{{") and all.contains("Words of its own") and all.contains("coo") and all.contains("hear")
		and all.contains("Takes 0 to 1."), "it names its properties and their bounds, its words, a creature's calls and hear")


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)

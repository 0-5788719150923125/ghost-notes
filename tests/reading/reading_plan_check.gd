extends SceneTree

## reading_plan_check - a reading's plan is a function of the words and what is asked, and nothing else:
##
##   godot --headless --path . --script tests/reading/reading_plan_check.gd
##
## WHAT IT HOLDS (next/structure.md, step 17). [ReadingPlan] is planned here with no panel, no voice
## and no host - only text in and a plan out:
##
## - THE SAME WORDS, THE SAME PLAN: planned twice, the two are equal, and the `ask` handed in comes
##   back unchanged; told something else (Hesitate off), the plan differs - so "equal" can fail;
## - THE READER'S CUE IS THE READER'S: a cue naming the narrator goes to the `reader` asked, whoever
##   that is, and so does the text before the first cue;
## - A PASSAGE'S RESTS ARE ITS OWN: each passage carries the lengths of its own hesitations, and its
##   chunks rest exactly those - none are left over to shift onto the next voice's;
## - THE VOICE IS TOLD OF A REST: the word a hesitation follows carries its length to the host
##   (`rest_after`), which reads that word as the end of a phrase and rests after it itself (piper.py
##   `REST_AFTER_FLOOR`; 2026-10-25, "moved on to <!-- hesitation --> Someone" came back a "t" and a
##   frame of schwa before the rest);
## - THE FADE IS THE PLAN'S: an outro mark fades for the Outro asked (at least half a second), and
##   text with no mark has none;
## - A READING CAN GROW: a second piece planned on from the first's `sentences` numbers its sentences
##   after the first's, says the same words it would have said as one script, and starts where the
##   scrub's estimate of the first ends.
##
## THE CONTROLS: Hesitate off rests nowhere and tells the voice of nothing (and is a different plan), a reader asked by another
## name gets the cue, and a second piece planned from sentence 0 collides with the first.
##
## Loaded by path after the tree is up: named here, the plan would be compiled with this gate before
## the autoloads its libraries read exist.

var _fails: Array = []
var _plan: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_plan = load("res://src/reading/reading_plan.gd") as GDScript
	var ask := {"reader": "Ryan", "hesitate": true, "bare": 1.5, "outro": 3.0}
	var text := "First line here. <!-- hesitation: 2 --> Then a pause.\n\n<!-- speaker: Judge -->\n" \
		+ "Order in the court. <!-- hesitation --> Sit.\n\n<!-- speaker: Narrator -->\nBack to Ryan."
	_check_pure(text, ask)
	_check_reader(text, ask)
	_check_rests(text, ask)
	_check_told(ask)
	_check_fade(ask)
	_check_grows(ask)
	for f in _fails:
		printerr("FAIL: ", f)
	print("reading_plan_check: %s" % ("ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)


func _check_pure(text: String, ask: Dictionary) -> void:
	var asked := ask.duplicate(true)
	var a: Dictionary = _plan.make(text, "", ask)
	var b: Dictionary = _plan.make(text, "", ask)
	_ok(var_to_str(a) == var_to_str(b), "the same words and the same ask planned two different readings")
	_ok(ask == asked, "planning changed what it was asked: %s" % str(ask))
	_ok((a["chunks"] as Array).size() == 5, "five sentences, five chunks (got %d)" % (a["chunks"] as Array).size())
	var off := ask.duplicate()
	off["hesitate"] = false
	_ok(var_to_str(_plan.make(text, "", off)) != var_to_str(a), "control: Hesitate off planned the same reading")


func _check_reader(text: String, ask: Dictionary) -> void:
	var who: Array = []
	for p in _plan.passages(text, "", ask):
		who.append(String((p as Dictionary)["speaker"]))
	_ok(who == ["Ryan", "Judge", "Ryan"], "the passages went to %s - the reader's cue is not the reader's" % str(who))
	var other := ask.duplicate()
	other["reader"] = "Ada"
	var first := String((_plan.passages(text, "", other)[0] as Dictionary)["speaker"])
	_ok(first == "Ada", "control: a reader asked as Ada read the opening as %s" % first)
	var titled: Array = _plan.passages("The words.", "A Title", ask)
	_ok(not titled.is_empty() and String((titled[0] as Dictionary)["text"]).begins_with("# A Title"),
		"the title is not announced first")


func _check_rests(text: String, ask: Dictionary) -> void:
	var segs: Array = _plan.passages(text, "", ask)
	var holds: Array = []
	for p in segs:
		holds.append((p as Dictionary)["holds"])
	_ok(holds == [[2.0], [1.5], []], "each passage's rests are not its own: %s" % str(holds))
	var rested: Array = []
	for c in _plan.make(text, "", ask)["chunks"]:
		for h in (c as Dictionary)["holds"]:
			if float((h as Dictionary)["sec"]) > 0.0:
				rested.append([String((c as Dictionary)["speaker"]), float((h as Dictionary)["sec"])])
	_ok(rested == [["Ryan", 2.0], ["Judge", 1.5]], "the chunks rest %s" % str(rested))
	var off := ask.duplicate()
	off["hesitate"] = false
	var none: Array = []
	for p in _plan.passages(text, "", off):
		none.append_array((p as Dictionary)["holds"])
	_ok(none.is_empty(), "control: Hesitate off still rests %s" % str(none))


func _check_told(ask: Dictionary) -> void:
	var text := "It had moved on to <!-- hesitation --> someone new. It stopped. <!-- hesitation: 2 --> It waited."
	var told := _told(text, ask)
	_ok(told == [["to", 1.5], ["stopped", 2.0]], "the voice is told of the rests after %s" % str(told))
	var off := ask.duplicate()
	off["hesitate"] = false
	_ok(_told(text, off).is_empty(), "control: Hesitate off still tells the voice of %s" % str(_told(text, off)))


## Every token of [param text]'s plan the voice is told a rest follows, as [text, seconds].
func _told(text: String, ask: Dictionary) -> Array:
	var out: Array = []
	for c in _plan.make(text, "", ask)["chunks"]:
		for t in (c as Dictionary)["tokens"]:
			if (t as Dictionary).has("rest_after"):
				out.append([String((t as Dictionary)["text"]), float((t as Dictionary)["rest_after"])])
	return out


func _check_fade(ask: Dictionary) -> void:
	var marked: Dictionary = _plan.make("One. Two. <!-- outro --> Three. Four.", "", ask)
	_ok(is_equal_approx(float(marked["fade"]), 3.0), "an outro mark fades for %s s, not the Outro's 3" % marked["fade"])
	var brief := ask.duplicate()
	brief["outro"] = 0.1
	_ok(is_equal_approx(float(_plan.make("One. <!-- outro --> Two.", "", brief)["fade"]), _plan.OUTRO_MIN_FADE),
		"a short Outro's fade is not held to the least a fade can be")
	_ok(float(_plan.make("One. Two.", "", ask)["fade"]) == 0.0, "text with no outro mark fades")


func _check_grows(ask: Dictionary) -> void:
	var one := "The first piece goes here. It has two sentences."
	var two := "The second piece arrives later. It has two as well."
	var a: Dictionary = _plan.make(one, "", ask)
	var b: Dictionary = _plan.make(two, "", ask, int(a["sentences"]))
	var whole: Dictionary = _plan.make(one + " " + two, "", ask)
	_ok(int(a["sentences"]) == 2 and int(b["sentences"]) == 4, "the pieces end at sentences %s and %s" % [a["sentences"], b["sentences"]])
	var grown: Array = (a["chunks"] as Array) + (b["chunks"] as Array)
	_ok(_said(grown) == _said(whole["chunks"]), "the pieces said %s, the whole %s" % [str(_said(grown)), str(_said(whole["chunks"]))])
	var at: PackedFloat32Array = _plan.timeline(a["chunks"])
	var all: PackedFloat32Array = _plan.timeline(grown)
	_ok(at.size() == 3 and is_equal_approx(all[2], at[2]), "the second piece does not start where the first's estimate ends")
	var clash: Dictionary = _plan.make(two, "", ask)
	_ok(_said(clash["chunks"])[0][0] == 0, "control: a piece planned from sentence 0 numbered its first sentence %s" % _said(clash["chunks"])[0][0])


## Every word of [param chunks] as [sentence, text].
func _said(chunks: Array) -> Array:
	var out: Array = []
	for c in chunks:
		for w in (c as Dictionary)["words"]:
			out.append([int((w as Dictionary)["sentence"]), String((w as Dictionary)["text"])])
	return out


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

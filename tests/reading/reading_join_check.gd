extends SceneTree

## reading_join_check - a reading's take joined a chunk at a time, the live window's and the export's
## alike ([ReadingJoin]):
##
##   godot --headless --path . --script tests/reading/reading_join_check.gd
##
## WHAT IT HOLDS (next/structure.md, step 18), on takes made here - a tone per chunk, the host's spans
## written by hand - with no voice and no panel:
##
## - THE SEAMS: nothing rests before the first chunk joined, whichever chunk it is (a reading started
##   part way through); each later one rests the seam [method Delivery.gap_before] gives it, a
##   handover the Turn rest on top;
## - THE ROOM'S MARKS: the opening voice at frame 0 (a lead is heard in its room), a later voice at
##   its own first frame, AFTER its seam, and a move nearer BEFORE the seam - and a handover written
##   after the player consumed every mark so far still lands on its own frame, never at 0;
## - THE WORDS, in the take's seconds: a chunk's word at its chunk's frame plus its span, a lead
##   included, and a word after a hesitation moved by exactly the rest spliced in before it - less
##   what the voice already rested there for it (the host's `rested`: told of the rest, the model
##   ends the word and pauses itself), so a hesitation is its own length, never that and the voice's;
## - THE FADE: it starts at the first fading chunk, and ending the take where it runs out drops what
##   was joined past it and every word that starts there - or, when the text ran out first, says how
##   much silence fills it out.
##
## THE CONTROLS, each the claim's other side: a chunk read with a different Turn rests differently, a
## word before the hesitation does not move, a voice that rested the whole hesitation is cut nowhere,
## and a word inside the take survives its end.
##
## Loaded by path after the tree is up: named here, the join would be compiled with this gate before
## the autoloads its libraries read exist.

const SR := 1000

var _fails: Array = []
var _join_script: GDScript
var _slot: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_join_script = load("res://src/reading/reading_join.gd") as GDScript
	_slot = ((load("res://src/reading/reading_panel.gd") as GDScript).get("SLOT_DEFAULTS") as Dictionary).duplicate()
	_check_seams_and_marks()
	_check_started_part_way()
	_check_words()
	_check_rested()
	_check_fade()
	for f in _fails:
		printerr("FAIL: ", f)
	print("reading_join_check: %s" % ("ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)


## Chunk [param i] of a script: one word, said by [param who], rested [param rest] seconds after it.
func _chunk(i: int, who: String, rest := 0.0, near := {}, fade := false) -> Dictionary:
	var c := {"speaker": who, "near": near, "fade": fade,
		"words": [{"text": "w%d" % i, "index": 0, "end": 0, "sentence": i},
			{"text": "x%d" % i, "index": 1, "end": 1, "sentence": i}], "holds": []}
	if rest > 0.0:
		(c["holds"] as Array).append({"tok": 0, "sec": rest, "before": false})
	return c


## A take of [param n] frames, and the spans that time its two words.
func _take(n := 400) -> PackedFloat32Array:
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	pcm.fill(0.2)
	return pcm


func _spans() -> Array:
	return [{"index": 0, "t0": 0.05, "t1": 0.15}, {"index": 1, "t0": 0.25, "t1": 0.35}]


func _check_seams_and_marks() -> void:
	var near := {"c": 0.6, "hush": 0.2}
	var chunks := [_chunk(0, "A"), _chunk(1, "A", 0.0, near), _chunk(2, "B")]
	var j: RefCounted = _join_script.new(SR, [], 100)
	var first: PackedFloat32Array = j.add(chunks, 0, _take(), _spans(), _slot, 1.0)
	_ok(first.size() == 400, "the first chunk joined rested a seam before it (%d frames for a 400-frame take)" % first.size())
	_ok(j.marks.size() >= 1 and int(j.marks[0]["at"]) == 0 and String(j.marks[0]["speaker"]) == "A",
		"the opening voice's room is not dialed at frame 0: %s" % str(j.marks))
	var seam := int(Delivery.gap_before(chunks, 1, _slot, 1.0) * SR)
	var at1: int = j.frames
	var second: PackedFloat32Array = j.add(chunks, 1, _take(), _spans(), _slot, 1.0)
	_ok(second.size() == seam + 400 and int(j.chunk_at[1]) == at1 + seam,
		"the second chunk rests %d frames, not the seam's %d" % [second.size() - 400, seam])
	var moved: Array = j.marks.filter(func(m: Dictionary) -> bool: return m.has("near"))
	_ok(moved.size() == 1 and int(moved[0]["at"]) == at1, "the reader moves at %s, not before the seam at %d" % [str(moved), at1])
	# THE PLAYER CONSUMES THE MARKS as the push reaches them (ReadingStream._fx_admit)...
	j.marks.clear()
	var at2: int = j.frames
	j.add(chunks, 2, _take(), _spans(), _slot, 1.0)
	var turn := int(Delivery.gap_before(chunks, 2, _slot, 1.0) * SR)
	var handover: Array = j.marks.filter(func(m: Dictionary) -> bool: return m.has("speaker"))
	# ...and the next voice's room still waits for the next voice's first frame
	_ok(handover.size() == 1 and int(handover[0]["at"]) == at2 + turn and String(handover[0]["speaker"]) == "B",
		"the handover to B is dialed at %s, not at its first frame %d" % [str(handover), at2 + turn])
	_ok(turn > seam, "a handover rests %d frames, no longer than a seam's %d" % [turn, seam])
	var calm: RefCounted = _join_script.new(SR)
	for i in 3:
		calm.add(chunks, i, _take(), _spans(), _slot, 0.0)
	_ok(int(calm.chunk_at[2]) - int(calm.chunk_at[1]) != int(j.chunk_at[2]) - int(j.chunk_at[1]),
		"control: Turn 0 rested a handover as long as Turn 1")


func _check_started_part_way() -> void:
	var chunks := [_chunk(0, "A"), _chunk(1, "A"), _chunk(2, "A")]
	var j: RefCounted = _join_script.new(SR)
	var out: PackedFloat32Array = j.add(chunks, 2, _take(), _spans(), _slot, 1.0)
	_ok(out.size() == 400 and int(j.chunk_at[2]) == 0, "a reading started at chunk 2 rested a seam before its first sentence")


func _check_words() -> void:
	var chunks := [_chunk(0, "A"), _chunk(1, "A", 0.5)]
	var words: Array = []
	var j: RefCounted = _join_script.new(SR, words, 100)
	j.add(chunks, 0, _take(), _spans(), _slot, 1.0)
	j.add(chunks, 1, _take(), _spans(), _slot, 1.0)
	_ok(words.size() == 4, "%d words joined, not 4" % words.size())
	if words.size() != 4:
		return
	_ok(is_equal_approx(float(words[0]["t0"]), 0.1 + 0.05), "the first word is at %s s, not after the lead" % words[0]["t0"])
	var c1 := float(j.chunk_at[1]) / SR
	_ok(is_equal_approx(float(words[2]["t0"]), c1 + 0.05), "control: the word before the rest moved to %s s" % words[2]["t0"])
	_ok(absf(float(words[3]["t0"]) - (c1 + 0.25 + 0.5)) < 0.002,
		"the word after the rest is at %s s, not moved by the 0.5 s spliced in" % words[3]["t0"])
	_ok(String(words[3].get("speaker", "")) == "A", "a joined word lost who says it")


func _check_rested() -> void:
	var chunks := [_chunk(0, "A", 0.5)]
	var spans := _spans()
	(spans[0] as Dictionary)["rested"] = 0.2
	var words: Array = []
	var j: RefCounted = _join_script.new(SR, words)
	var out: PackedFloat32Array = j.add(chunks, 0, _take(), spans, _slot, 1.0)
	_ok(out.size() == 400 + 300, "a 0.5 s rest the voice began 0.2 s of spliced %d frames, not 300" % (out.size() - 400))
	_ok(words.size() == 2 and absf(float(words[1]["t0"]) - (0.25 + 0.3)) < 0.002,
		"the word after it is at %s s, not moved by what is left of the rest" % (words[1]["t0"] if words.size() == 2 else "-"))
	var all := _spans()
	(all[0] as Dictionary)["rested"] = 0.8
	var whole: PackedFloat32Array = (_join_script.new(SR) as RefCounted).add(chunks, 0, _take(), all, _slot, 1.0)
	_ok(whole.size() == 400 and whole == _take(), "control: a rest the voice rested whole was cut %d frames into" % (whole.size() - 400))


func _check_fade() -> void:
	var chunks := [_chunk(0, "A"), _chunk(1, "A", 0.0, {}, true), _chunk(2, "A", 0.0, {}, true)]
	var words: Array = []
	var j: RefCounted = _join_script.new(SR, words)
	j.add(chunks, 0, _take(), _spans(), _slot, 1.0)
	_ok(j.fade_end(0.3) == -1, "a fade ends before a fading chunk is in")
	j.add(chunks, 1, _take(), _spans(), _slot, 1.0)
	_ok(j.fade_at == int(j.chunk_at[1]), "the fade starts at %d, not at the first fading chunk %s" % [j.fade_at, j.chunk_at[1]])
	j.add(chunks, 2, _take(), _spans(), _slot, 1.0)
	var end: int = j.fade_end(0.3)
	var had: int = j.frames
	var dropped: int = j.end_at(end)
	_ok(dropped == had - end and j.frames == end, "ending the take at %d dropped %d of %d frames" % [end, dropped, had])
	var last := float(end) / SR
	var late: Array = words.filter(func(w: Dictionary) -> bool: return float(w["t0"]) >= last)
	_ok(late.is_empty(), "words past the fade's end are still on the subtitles: %s" % str(late))
	_ok(words.size() >= 3, "control: words inside the take went with the fade's end (%d left)" % words.size())
	var short: RefCounted = _join_script.new(SR)
	short.add([_chunk(0, "A", 0.0, {}, true)], 0, _take(), _spans(), _slot, 1.0)
	_ok(short.end_at(short.fade_end(2.0)) == 400 - 2000, "a fade longer than the text says nothing of the silence it needs")


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

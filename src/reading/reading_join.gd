extends RefCounted
class_name ReadingJoin

## ReadingJoin - a reading's take, joined a chunk at a time: the rest at each seam, the hesitations
## spliced in, where the room changes voice and distance, every word timed in the take's own
## seconds, where each chunk starts and where the outro mark's fade begins.
##
## ONE JOIN FOR THE LIVE READING AND THE EXPORT (next/structure.md, step 18). The live window joined
## each chunk as it arrived and the export joined the whole reading after it, in two copies of the
## same steps kept alike by comments ("as in _drain_ready"); they had already parted - a reading
## started part way through rested a seam before its first sentence and the export never did, and
## the two placed an unaligned word on either side of a hesitation's cut. Both hold one of these now,
## so the take that renders is the performance that was heard.
##
## THE COORDINATE IS FRAMES OF THE TAKE, from its first: the lead (the intro's silence, when the take
## opens on one) and every chunk and seam since. A word's seconds are its frame over the rate, so
## a long reading's subtitles cannot drift from its audio a seam at a time, as a running total of
## seconds did. What is appended is the caller's to hold - the live window's queue for the ring, the
## export's buffer - and the room's [member marks] are the caller's to consume.

## The take's sample rate.
var sr := 22050
## Frames joined so far: the lead and every seam and chunk.
var frames := 0
## WHEN THE ROOM CHANGES, ascending, in frames of the take: `{at, speaker}` dials a voice's room in,
## `{at, near}` moves the reader (see [method Delivery.near_mark]). The first voice's is at 0, so a
## lead is heard in the opening voice's room rather than in nobody's.
var marks: Array = []
## Every word joined, timed in the take's seconds - handed in, and appended to in place (the live
## window's is the subtitle overlay's own list, held by reference).
var words: Array = []
## EVERY SOUND JOINED, timed as the words are (`{p, t0, t1}` in the take's seconds) - what a mouth
## that says them follows ([LikenessMedium]). Handed in when wanted, appended to in place like
## [member words]; a host that hands back no phones leaves it as it was.
var phones: Array = []
## Chunk index -> the frame its audio starts at.
var chunk_at := {}
## The frame the outro mark's fade starts at: the first fading chunk's (-1 until one is joined).
var fade_at := -1
## What the log calls these takes when a word comes back with no timing.
var label := "chunk"

# A chunk is in: the next rests a seam before it, and the opening voice's mark is written. NOT
# `marks.is_empty()`: whoever plays the take consumes the list as it goes, so mid-reading it is empty
# again, and a handover written then at 0 was dialed at once - the next voice's room seconds before
# the next voice.
var _opened := false
var _voice := ""           # the voice the last room mark dialed
var _near := {}            # the distance the last near mark set


## A take at [param sample_rate] whose words go into [param into], opening on [param lead] frames of
## silence the caller already holds. [member sr] may be set again before the first chunk: the rate
## is the host's, known when its first take arrives.
func _init(sample_rate := 22050, into: Array = [], lead := 0) -> void:
	sr = sample_rate
	words = into
	frames = lead


## Join chunk [param idx] of [param chunks], whose take is [param pcm] with the spans the host timed
## it by ([param spans]), in a voice of settings [param s] at the Turn dial [param turn]: the audio to
## append - the seam's rest before it (none before the first chunk joined) and the take with its
## hesitations and hums spliced in ([method Splice.chunk]).
func add(chunks: Array, idx: int, pcm: PackedFloat32Array, spans: Array, s: Dictionary, turn: float,
		said: Array = []) -> PackedFloat32Array:
	var ch: Dictionary = chunks[idx]
	var who := String(ch.get("speaker", ""))
	# THE TONE IS ALREADY IN IT: the host played the take back at the preset's ratio, and every
	# time it returned is in the take's own seconds (`play_ratio`), so there is no ratio to apply.
	var spliced := Splice.chunk(pcm, ch.get("holds", []), spans, 1.0, sr)
	var take: PackedFloat32Array = spliced["pcm"]
	var near: Dictionary = ch.get("near", {})
	var opening := not _opened
	var out := PackedFloat32Array()
	if not opening:
		# THE READER MOVES IN THE PAUSE before the sentence they come in for - so this mark goes
		# BEFORE the seam (the first one follows the voice's, which opens the chain)
		Delivery.near_mark(marks, near, frames, _near)
		# a breath between sentences, at the seam the host cannot see. Scaled by Pause like every
		# other rest, or the control would do nothing at all at CHUNK_SENTENCES = 1 - every sentence
		# boundary in the reading IS a seam. A handover takes the Turn rest on top.
		out.resize(int(Delivery.gap_before(chunks, idx, s, turn) * float(sr)))
		frames += out.size()
	# THE ROOM CHANGES AFTER THE SEAM, deliberately: the handover silence belongs to the voice
	# leaving it, whose reverb is still decaying through it. Dialing the new room at the start of
	# the rest would cut that tail over to a different space halfway down, which is the one thing
	# a room never does. The mark carries the frame; whoever plays the take dials it there.
	if opening or who != _voice:
		_voice = who
		marks.append({"at": 0 if opening else frames, "speaker": who})
	if opening:
		Delivery.near_mark(marks, near, frames, _near)
	_opened = true
	# the host timed the chunk from zero; its words move by the rests spliced in before them, then
	# into the take's time
	var t0 := float(frames) / float(sr)
	for w in ReadingPlan.words_for(ch, spans, "%s %d" % [label, idx]):
		var d: Dictionary = w
		d["t0"] = Splice.shifted(float(d["t0"]), spliced["cuts"], 1.0, true) + t0
		d["t1"] = Splice.shifted(float(d["t1"]), spliced["cuts"], 1.0, false) + t0
		words.append(d)
	# THE PHONES MOVE AS THE WORDS DO: by the rests spliced in before them, then into the take's time
	for ph in said:
		var p: Dictionary = ph
		phones.append({"p": String(p.get("p", "")),
			"t0": Splice.shifted(float(p.get("t0", 0.0)), spliced["cuts"], 1.0, true) + t0,
			"t1": Splice.shifted(float(p.get("t1", 0.0)), spliced["cuts"], 1.0, false) + t0})
	chunk_at[idx] = frames
	# THE OUTRO MARK: the fade starts where the first chunk after it does
	if fade_at < 0 and bool(ch.get("fade", false)):
		fade_at = frames
	out.append_array(take)
	frames += take.size()
	return out


## The frame where an outro mark's fade of [param fade] seconds ends - -1 until a fading chunk is in.
func fade_end(fade: float) -> int:
	return -1 if fade_at < 0 else fade_at + int(fade * float(sr))


## THE TAKE ENDS AT FRAME [param end] (where the outro mark's fade runs out): what was joined past it
## is never heard, so neither is a word that starts there. Returns how many frames the caller drops
## from the end of what it holds - negative when the text ran out first, and that many frames of
## silence fill the take out to its end.
func end_at(end: int) -> int:
	var over := frames - end
	frames = end
	var cut := float(end) / float(sr)
	for i in range(words.size() - 1, -1, -1):
		if float((words[i] as Dictionary).get("t0", 0.0)) >= cut:
			words.remove_at(i)
	for i in range(phones.size() - 1, -1, -1):
		if float((phones[i] as Dictionary).get("t0", 0.0)) >= cut:
			phones.remove_at(i)
	return over


## [param n] frames of silence after the last chunk (the outro), counted into the take.
func pad(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(0, n))
	frames += out.size()
	return out

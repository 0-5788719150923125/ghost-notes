extends RefCounted
class_name ReadingStream

## ReadingStream - the reading on the stream: the sliding window. A chapter is too long to synthesize up front
## (at roughly 4x real time, twenty minutes of narration is five minutes of silence), so the text is planned into
## chunks at sentence boundaries ([ReadingPlan]) and only [constant LOOKAHEAD] of them are ever in flight. The
## first chunk plays while the second is made and each finished one pulls the next in, so first audio arrives in
## seconds and memory stays bounded.
##
## A part of its panel (next/structure.md, step 20). It holds the reading on the stream - its plan, the requests in
## flight and the takes come back, the one continuous stream and its ring, the take being joined ([ReadingJoin]),
## the live effects chain and the place under the voice - and asks the [ReadingPanel] it is part of for the words,
## a voice's settings, the host and the requests. The panel asks it to play, stop, re-pace and seek, and, for the
## transport, where it is.

## The [ReadingPanel] this is a part of: everything read through it is something this part is handed.
var panel: ReadingPanel

const LOOKAHEAD := 2           # chunks in flight; 1 would stall at every seam
# ...and a bound on how much finished audio may sit ahead of the playhead. LOOKAHEAD throttles concurrency, not
# depth: without this the whole chapter is decoded and queued within a minute, and a tone or pace change has
# nothing left to affect. It must comfortably exceed the generator's own ring (131071 frames, 5.94 s at 22050),
# or the ring drains while the next chunk is synthesized and playback stalls. The cost is switch latency, which is
# why chunks are single sentences: shallow in time, deep enough in seconds to never starve.
const LOOKAHEAD_SECONDS := 9.0
## Seconds of audio that must be queued before the first sample is heard, when there is no intro to serve as the
## lead. A short opening sentence (1.13 s measured) cannot cover the synthesis of a long second one (14.49 s). It
## is a lower bound on latency-to-first-word, so it is not larger.
const LIVE_PREROLL := 2.5
## The window follows the host. LOOKAHEAD_SECONDS is sized for Piper, which makes a take four to eleven times
## faster than it is heard; Kokoro makes one two to three times faster, so a long sentence could take longer to
## make than the audio ahead of it lasted. So the host's pace is measured from what comes back ([method _measure]:
## seconds taken per estimated second of each chunk) and the window keeps DEPTH_SAFETY times what the next
## LOOKAHEAD chunks will take to make ([method depth]), never less than LOOKAHEAD_SECONDS and never more than
## DEPTH_MOST (the latency a pace or tone change may cost). The lead before the first sample is as long as the
## next chunk will take to make ([method lead_for]). See tests/reading/stream_depth_check.gd.
const DEPTH_SAFETY := 1.5
const DEPTH_MOST := 45.0
## How much voice a paused reading makes ahead of the playhead (seconds, [method _depth_now]): the whole of any reading a show makes.
const BUFFER_PAUSED := 900.0

# The plan on the stream ([ReadingPlan])
var chunks: Array = []        # [{tokens, words, ...}] planned up front, cheap
## The take kept, playing whole as the session's audio ([method _play_take]): its wav, "" while the reading is said live.
var take_path := ""
## ...and it has played to its end: the reading is over ([method ReadingPanel.take_ended]).
var take_done := false
## The reading on the stream no longer matches the panel: the next Play reads it again.
var stale := false
## The outro mark, live: how long the fade is (0 = no mark; where it starts is the join's, [member ReadingJoin.fade_at]).
var _fade_len := 0.0
# The predicted timeline: a scrub bar scaled by how much audio has been decoded would change length under the
# pointer as the reading is synthesized, so the bar is scaled by an estimate.
var _chunk_t := PackedFloat32Array()     # chunk -> its estimated start along the reading, s (n + 1)
## Live scrubbing, by sentence. A live reading is synthesized a sentence or two ahead, so there is no audio to
## seek within. The transport's rail (through the panel's conductor hooks, [method ReadingPanel.transport_hooks])
## seeks by sentence: its positions are estimated sentence starts, and a seek is Stop + Play from that sentence, a
## fresh reading synthesized from there on. The media start in the state they would be in at that point
## (book_document()["start_words"]). This never seeks a stream; it ends one and starts another.
var _start_chunk := 0
var _seek_k := -1                        # a seek waiting for the bar to settle

# The window: what is asked of the host and what has come back
var _ready_takes: Array = []   # [{wav, index, spans}] synthesized, awaiting the push
var _next_to_request := 0
var _next_to_play := 0
var _in_flight := 0
var _req_chunk := {}           # request id -> {idx, epoch, sent}
var _epoch := 0                # bumped on a pace change; stale replies are dropped
var _cost := 0.0               # the host's seconds per estimated second of a chunk, 0 unmeasured
var _done_ms := 0              # when the host last handed something back (it makes one at a time)

# The one continuous stream
var playback: AudioStreamGeneratorPlayback
var _stream_open := false      # explicit: a null playback must not retry forever
var _pending := PackedFloat32Array()   # decoded samples not yet handed to the ring
var _read := 0                 # cursor into _pending (slicing it per frame would copy the whole queue)
var _pushed := 0               # frames handed to the ring, for the played-time clock
var _ring_capacity := 0        # measured, never computed - see _drain_ready
var _lead_in := 0.0            # the intro seeded into _pending by plan, in seconds
var _outro_queued := false     # the outro's silence is on the stream (see the drain)
var _fade_done := false        # the outro mark's fade has run out: the reading is cut
var _sub_words: Array = []     # shared BY REFERENCE with the Subtitles overlay
var _sub_phones: Array = []    # ...and the phones, the same way (Subtitles.phones)
## The take being joined ([ReadingJoin]): the frames queued on the stream from its first (the intro's silence
## included), the room's marks - when the room changes, in those frames: the effects chain is stateful across chunk
## boundaries, so a second speaker gets the same chain re-dialed at the frame their first sample is heard
## ([method _fx_admit] consumes them) - where each chunk starts and where the outro mark's fade does. A fresh one
## for every reading.
var _join := ReadingJoin.new()

# The live chain: the voice's room, run here rather than in the host
var fx := VoiceFX.new()
var _fx_live_name := ""        # which voice the live chain is currently dialed to

## The place under the voice (a [SoundBed]): the wind, the sea, the rain of where the reading is, mixed in after
## the voice's own effects - live here, and into the exported take by [method ReadingPanel.export_take]. A
## component that knows where its reading is says so through the panel's [member ReadingPanel.bed]; null when none does.
var _env: SoundBed = null
var _env_key := ""             # the place it was made from, to notice the place changing mid-reading
var _env_poll := 0.0


func _init(owner: ReadingPanel) -> void:
	panel = owner


# --- playing, stopping, and reading from part way ---------------------------------------------

## Play: read the script from the top, or, while a reading plays, pause it and carry on. Speak is a toggle while
## a reading plays: Pause, then Resume, from where it was. Reading again from the top is Stop, then Play.
func play() -> void:
	if live():
		Spectrum.set_paused(not Spectrum.paused)
		panel._set_status("Paused. Space or ▶ carries on; ■ ends the reading."
			if Spectrum.paused else "Resumed.")
		return
		# A take kept for these words in these voices plays as it is, the host asked for nothing
	var said := panel._reading_body().strip_edges()
	if not said.is_empty():
		panel._cast.refresh(said)
		if _play_take(panel.kept_take(said)):
			return
	if panel._host == null or not panel._host.is_up() or panel._cast.voice_pick.selected < 0:
		return
		# The real-time read: in sync mode this is the file as it is on disk right now, so the author can keep writing
		# in their own editor with ghost open beside it.
	var body := panel._reading_body().strip_edges()
	if body.is_empty():
		panel._set_status("Nothing to read yet: write the words on the Script card, then press ▶.")
		return
		# The cast now, not at the next pause in typing: a name written a moment ago must read in its own voice.
	panel._cast.refresh(body)
	if panel._test_busy():
		panel._stop_test()
		# plan is a full teardown: stream closed, queues emptied, pending request ids dropped so replies for the old
		# text are discarded on arrival rather than spliced into the new reading.
	plan(body)
	if chunks.is_empty():
		panel._set_status("Nothing speakable in that text.")
		return
	stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	panel._set_status("Planned %d chunk(s). Synthesizing the first…%s" % [chunks.size(), panel._plan_note])
	_pump()


## The take kept at [param path], played whole (next/editing.md step 3): the file a render plays, through the
## session a render opens (its bookend and words its sidecar's), so what is heard and seen is the export's, a seek
## lands at once, paused or not, and the voice host makes nothing. False for no take, or one the owner could not
## play: then the reading is said live.
func _play_take(path: String) -> bool:
	if path.is_empty() or not panel.begin_take.is_valid():
		return false
	if has_reading() or playback != null:
		_reset_playback()
	if not bool(panel.begin_take.call(path)):
		return false
	take_path = path
	take_done = false
	stale = false
	panel._set_status("Playing the kept take (%s): what the export will be, and a seek lands where it is asked."
		% Clock.text(Spectrum.song_length()))
	return true


## Whether there is a reading on the transport: one planned to be said, or a take kept playing.
func has_reading() -> bool:
	return not chunks.is_empty() or not take_path.is_empty()


## Tear the stream down and read again from the top. plan clears the pending request map, so replies still in
## flight for the old voice are dropped on arrival.
func restart() -> void:
	var body := panel._reading_body().strip_edges()
	if body.is_empty():
		return
	panel._cast.refresh(body)
	plan(body)
	if chunks.is_empty():
		return
	stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	panel._set_status("Voice changed - reading again from the start…%s" % panel._plan_note)
	_pump()


## Stop: end the reading and hand the stage back. Tearing down the stream is the half the editor cannot do
## alone: the playback, the Director's attachment to the stage and the subtitle overlay belong to the owner, so
## `end_stream` is wired beside `begin_stream` (see main._end_generative_stream).
func stop() -> void:
	if not has_reading() and playback == null:
		return
	Spectrum.set_stream_paused(false)
	_reset_playback()
	if panel.end_stream.is_valid():
		panel.end_stream.call()
	_sync_speak_buttons()
	panel._set_status("Stopped. Space or ▶ reads again from the top.")


## Plan a reading: tear the old one down, then cut the text into chunks.
func plan(body: String) -> void:
	_reset_playback()
		# The intro, seeded here rather than when the stream opens - see the note in _reset_playback's lead-in block.
	_lead_in = maxf(0.0, Director.intro_hold)
	if _lead_in > 0.0:
		_pending.resize(int(_lead_in * float(panel._sr)))
		_join.frames = _pending.size()
	var made := panel._plan_of(body)
	chunks = made["chunks"]
	_fade_len = float(made["fade"])
	_start_chunk = 0
	_seek_k = -1
	_chunk_t = ReadingPlan.timeline(chunks)


## Every piece of state a reading owns, put back. Split out of [method plan] so that stopping and re-planning
## cannot drift apart. The pending request map matters most: replies for chunks already asked for are still in
## flight on the host, and dropping their ids here makes them discarded on arrival.
func _reset_playback() -> void:
	chunks = []
	take_path = ""
	take_done = false
	_ready_takes = []
	_req_chunk = {}
	_next_to_request = 0
	_next_to_play = 0
	_in_flight = 0
	_cost = 0.0
	_done_ms = 0
	_stream_open = false
	playback = null
	_pushed = 0
	_ring_capacity = 0
	_pending = PackedFloat32Array()
	_read = 0
	_fx_live_name = ""
		# The intro silence belongs to a reading that is starting, so it is seeded in plan and only cleared here. The
		# join's frames are the clock every word span and seam is measured against, so starting them at the end of that
		# silence offsets the whole reading, subtitles included. Inserting it later would put it after the first sentence.
	_lead_in = 0.0
	_close_environment()
	_outro_queued = false
	_fade_done = false
	Director.live_fade = 1.0
	_sub_words.clear()          # cleared in place: Subtitles holds this by reference
	_sub_phones.clear()
	_join = ReadingJoin.new(panel._sr, _sub_words)
	_join.phones = _sub_phones


## Play and Stop, from one place: two buttons whose enabled state is set at several points would disagree.
func _sync_speak_buttons() -> void:
	if not has_reading():
		stale = false


## Read from sentence [param k]: Stop, then Play from there. The old stream is ended (the voice stops at once and
## the stage is handed back), then a fresh reading is planned and requested from [param k] on, with no intro. The
## media start where it starts ([method start_words]).
func speak_from(k: int) -> void:
	_seek_k = -1
	if panel._host == null or not panel._host.is_up() or panel._cast.voice_pick.selected < 0:
		panel._set_status("The voice is not ready yet - wait for it, then scrub.")
		return
	var body := panel._reading_body().strip_edges()
	if body.is_empty():
		return
	if not chunks.is_empty() or playback != null:
		Spectrum.set_stream_paused(false)
		_reset_playback()
		if panel.end_stream.is_valid():
			panel.end_stream.call()
	panel._cast.refresh(body)
	if panel._test_busy():
		panel._stop_test()
	plan(body)
	if chunks.is_empty():
		panel._set_status("Nothing speakable in that text.")
		return
	k = _start_at(k)
	stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	panel._set_status("Reading from sentence %d of %d…%s" % [k + 1, chunks.size(), panel._plan_note])
	_pump()


## A planned reading made to start at chunk [param k]: requested and played from there, with no
## intro. Returns the chunk it will start at.
func _start_at(k: int) -> int:
	k = clampi(k, 0, maxi(0, chunks.size() - 1))
	_start_chunk = k
	if k > 0:
		_pending = PackedFloat32Array()
		_read = 0
		_lead_in = 0.0
		_join.frames = 0
		_next_to_request = k
		_next_to_play = k
	return k


## About where those words are ([method ReadingPlan.start_index]) - -1 for a reading from the top.
func start_index() -> int:
	return ReadingPlan.start_index(chunks, _start_chunk)


## How far into the reading it starts (seconds, the scrub bar's estimated scale) - 0 from the top: what a medium
## keeping the reading's own time (a clock on the table) is set to.
func start_time() -> float:
	return _chunk_t[_start_chunk] if _start_chunk > 0 and _start_chunk < _chunk_t.size() else 0.0


## The first words of the chunk a reading starts at, normalized ([method ReadingPlan.start_words]) -
## how a medium finds its place. Empty for a reading from the top.
func start_words() -> PackedStringArray:
	return ReadingPlan.start_words(chunks, _start_chunk)


## A reading that is still going: planned, and not yet played out to the end. A generated stream never announces
## its end, so "every chunk played and the buffer drained" is the end, and then Play reads again from the top.
func live() -> bool:
	if not take_path.is_empty():
		return not take_done and Spectrum.has_audio()
	if chunks.is_empty():
		return false
	if _next_to_play < chunks.size() or not _pending.is_empty() or playback == null:
		return true
	return _ring_capacity - int(playback.get_frames_available()) > 256


## What Play does now, in a word - for the status line and the gates. The transport draws its
## own button from the conductor's `playing`.
func play_label() -> String:
	var label := "Play"
	if live():
		label = "Resume" if Spectrum.paused else "Pause"
	return label + (" ●" if stale and has_reading() else "")


## The reading on the stream no longer matches the panel: the same dot the text box raises, since the cast changed
## under what is playing.
func mark_stale() -> void:
	if has_reading():
		stale = true


## Re-generate everything not yet committed to the stream, at the new pace. Audio already pushed, and audio decoded
## and waiting in _pending, is finished: its subtitles are placed and the join has moved past it. Everything from
## the next un-drained chunk onward is thrown away and re-requested, so the new pace lands within a chunk or two.
func repace() -> void:
	if not take_path.is_empty():
		stale = true                # a take kept is as it was said: Stop, then Play, says it live
		return
	if chunks.is_empty() or _next_to_play >= chunks.size():
		return
	_epoch += 1                     # in-flight replies from the old pace are now stale
	_ready_takes.clear()
		# The host keeps computing what it was given (there is no cancel - see [method arrived]), so the accounting for
		# it has to survive or the pump will pile more on top.
	_next_to_request = _next_to_play
	panel._set_status("%s at pace %.2fx, pause %.2fx - regenerating from chunk %d…"
		% [panel._cast.tab_name(), panel._cast._rate.value, clampf(panel._cast._pause.value, 0.0, Delivery.MAX_PAUSE_SCALE), _next_to_play + 1])
	_pump()


# --- the scrub --------------------------------------------------------------------------------
# Seeking a live generator is not offered. A generator's ring cannot be cleared while playback is active, so every
# seek had to stop and restart the stream, and repeated restarts left the voice doubling; and the Director is a
# simulation, not a function of time (its scene choice and hold schedule evolve from the events it has seen), so a
# seek would show the scene that happens to be up rather than the one the export will have. To inspect a moment
# of the export, render the take and open the file: a file boot is seekable for real (see Spectrum.seek) and
# replays the same deterministic show from the same seed. `--scene <name>` inspects one scene.

## The scrub bar's length: the whole reading, estimated.
func length() -> float:
	if not take_path.is_empty():
		return Spectrum.song_length()
	return _chunk_t[_chunk_t.size() - 1] if not _chunk_t.is_empty() else 0.0


## The scrub bar's position: where a waiting seek is going, else the sentence being heard and how far through it,
## on the estimated scale.
func position() -> float:
	if not take_path.is_empty():
		return Spectrum.current.time
	var n := _chunk_t.size() - 1
	if n <= 0:
		return 0.0
	if _seek_k >= 0:
		return _chunk_t[clampi(_seek_k, 0, n)]
	var i := _start_chunk
	var f := 0.0
	if playback != null and _ring_capacity > 0 and not _join.chunk_at.is_empty():
		var heard := _pushed - maxi(0, _ring_capacity - int(playback.get_frames_available()))
		var best := -1
		for c in _join.chunk_at:
			if int(_join.chunk_at[c]) <= heard and int(c) > best:
				best = int(c)
		if best >= 0:
			i = best
			var est := maxf(0.2, _chunk_t[mini(i + 1, n)] - _chunk_t[mini(i, n)])
			f = clampf(float(heard - int(_join.chunk_at[best])) / float(panel._sr) / est, 0.0, 0.99)
	i = clampi(i, 0, n - 1)
	return lerpf(_chunk_t[i], _chunk_t[i + 1], f)


## The scrub bar asks to go to [param t] (estimated seconds): remember the sentence there and
## restart from it once the bar settles.
func seek(t: float) -> void:
	if not take_path.is_empty():
		take_done = false
		Spectrum.seek_file(t)
		return
	var k := 0
	for i in _chunk_t.size() - 1:
		if _chunk_t[i] <= t:
			k = i
	_seek_k = k
	if panel._seek_timer != null and panel._seek_timer.is_inside_tree():
		panel._seek_timer.start()


## The bar has settled: read from the sentence a seek waits on. A seek while paused stays paused (next/editing.md
## step 3): the voice is made from there while nobody listens, and plays on Play.
func seek_now() -> void:
	var k := _seek_k
	if k >= 0:
		var hold := Spectrum.paused
		speak_from(k)
		if hold:
			Spectrum.set_stream_paused(true)


# --- the window: what is asked of the host ----------------------------------------------------

## How far ahead of the playhead the voice is made (seconds): what is decoded and waiting, the ring's too - and,
## once the last sentence is made, to the end ([method ReadingPanel.transport_hooks]'s `ahead`).
func ahead() -> float:
	if not take_path.is_empty():
		return INF
	if _next_to_play >= chunks.size() and _outro_queued:
		return INF
	return _buffered_seconds()


## How much finished audio is waiting to be heard: decoded but not yet pushed, plus whatever is in the ring.
func _buffered_seconds() -> float:
	var queued := 0
	if playback != null and _ring_capacity > 0:
		queued = maxi(0, _ring_capacity - int(playback.get_frames_available()))
	return float(maxi(_pending.size() - _read, 0) + queued) / float(maxi(panel._sr, 1))


## Keep LOOKAHEAD chunks in flight and start playback as soon as the chunk we are waiting for exists.
func _pump() -> void:
	if panel._cast.voice_meta.is_empty():
		return
		# The intro is not lookahead: it is seeded as silence before anything is requested, so counting it would let an
		# Intro of LOOKAHEAD_SECONDS or more look like a full buffer and nothing would be requested. Only the speech
		# queued counts; the intro still to be pushed is taken off.
	var intro_left := maxf(0.0, _lead_in - float(_pushed) / float(maxi(panel._sr, 1)))
	var planned := false
	var hits := 0             # sentences taken from the cache this pump: a window's worth at most, then drained
	while _in_flight < LOOKAHEAD and hits < LOOKAHEAD and _next_to_request < chunks.size() \
			and _buffered_seconds() - intro_left < _depth_now():
		var idx := _next_to_request
		if not planned:
			planned = true
			panel._plan_near(chunks, idx)
		_next_to_request += 1
		_in_flight += 1
		var s := panel._cast.cfg_of(String((chunks[idx] as Dictionary).get("speaker", "")))
		var args: Dictionary = panel._request_args(s, chunks[idx])
		var key: String = panel.take_key(s, args)
				# A sentence said before ([TakeCache]) is in the queue at once, as the host's reply would be - no host asked
		var kept := TakeCache.find(key)
		if not kept.is_empty():
			var copy := TakeCache.copy_out(key, ReadingPanel.TAKE_DIR + "/chunk_%d_%d.wav" % [idx, _epoch])
			if not copy.is_empty():
				_in_flight -= 1
				var out: Dictionary = kept["out"]
				panel._sr = int(out.get("sample_rate", panel._sr))
				_ready_takes.append({"wav": copy, "index": idx, "spans": out.get("tokens", []), "phones": out.get("phones", [])})
				hits += 1
				continue
		var id := panel._host.request("", panel._cast.voice_id_of(s),
			ReadingPanel.TAKE_DIR + "/chunk_%d_%d.wav" % [idx, _epoch], args, null)
		_req_chunk[id] = {"idx": idx, "epoch": _epoch, "sent": Time.get_ticks_msec(), "key": key}
	if hits > 0:
		_drain_ready()


## How deep the window is now: [method depth] over the chunks the pump would ask for next - and, while the reading
## is paused, [constant BUFFER_PAUSED]: the voice goes on being made while nobody listens, so what follows plays with
## the host idle and the transport shows it buffered. What is made stays made: playing on, the window is as deep as
## it was, and the host is asked again only as the made voice runs down to it.
func _depth_now() -> float:
	if Spectrum.paused:
		return BUFFER_PAUSED
	var up := PackedFloat32Array()
	for k in range(_next_to_request, mini(_next_to_request + LOOKAHEAD, _chunk_t.size() - 1)):
		up.append(_chunk_t[k + 1] - _chunk_t[k])
	return depth(_cost, up)


## Seconds of audio the window keeps ahead of the playhead: DEPTH_SAFETY times what the chunks [param upcoming]
## (their estimated seconds) will take to make at [param cost], held between LOOKAHEAD_SECONDS and DEPTH_MOST.
## Unmeasured ([param cost] 0), LOOKAHEAD_SECONDS.
static func depth(cost: float, upcoming: PackedFloat32Array) -> float:
	var make := 0.0
	for s in upcoming:
		make += s
	return clampf(DEPTH_SAFETY * cost * make, LOOKAHEAD_SECONDS, DEPTH_MOST)


## The host's cost after one more chunk was seen to cost [param seen]: believed at once when it rises (a busy
## machine starves the stream the first time), let go of slowly when it falls.
static func cost_after(cost: float, seen: float) -> float:
	if cost <= 0.0:
		return seen
	return lerpf(cost, seen, 0.5 if seen > cost else 0.2)


## A reply came back: what it cost the host, from when the host could start on it (when it was asked, or when the
## reply before it came back, whichever is later - the host makes one at a time) to now, per estimated second of
## its chunk. A reply from before a re-pace frees the host all the same, but says nothing about the cost.
func _measure(meta: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var began := maxi(int(meta.get("sent", now)), _done_ms)
	_done_ms = now
	var k := int(meta["idx"])
	if int(meta["epoch"]) != _epoch or k < 0 or k + 1 >= _chunk_t.size():
		return
	var est := _chunk_t[k + 1] - _chunk_t[k]
	if est >= 0.5:
		_cost = cost_after(_cost, float(now - began) / 1000.0 / est)


## The lead the stream waits for before its first sample, beyond its own floor: as long as the next
## chunk to be heard will take to make. 0 until the host's cost is known.
func _make_next() -> float:
	if _next_to_play + 1 >= _chunk_t.size():
		return 0.0
	return lead_for(_cost, _chunk_t[_next_to_play + 1] - _chunk_t[_next_to_play])


## How long a chunk of [param next_len] estimated seconds will take a host of [param cost] to make
## (at most DEPTH_MOST): what the audio ahead of the first sample must cover. 0 at an unknown cost.
static func lead_for(cost: float, next_len: float) -> float:
	return minf(DEPTH_MOST, maxf(0.0, cost) * next_len)


## Whether the host's reply [param id] is a chunk of the reading on the stream - or one it asked for
## before a re-pace or a jump, which is dropped on arrival.
func owns(id: int) -> bool:
	return _req_chunk.has(id)


## A chunk the reading asked for came back: into the queue, in order ([method _drain_ready]).
func arrived(id: int, result: Dictionary) -> void:
	var meta: Dictionary = _req_chunk[id]
	_req_chunk.erase(id)
	_measure(meta)
		# The slot is freed whether or not the result is wanted, and this must happen before the epoch check: an
		# abandoned request still occupies the host (the stream does not cancel it; VoiceHost.cancel is for Test), so
		# a jump that zeroed the counter would let _pump send a full lookahead on top of queued work, and the chunk
		# waited for would be third or fourth in line.
	_in_flight = maxi(0, _in_flight - 1)
	if int(meta["epoch"]) != _epoch:
				# Superseded by a pace change or a jump. Nothing to keep, but the pump may now have room.
		_pump()
		return
	var idx: int = int(meta["idx"])

	var wav := String(result.get("wav", ""))
	if wav.is_empty():
		panel._set_status("The host returned no audio.")
		return
	panel._sr = int(result.get("sample_rate", panel._sr))
	# ...kept, so it is never asked for again ([TakeCache])
	if not Settings.is_read_only():
		TakeCache.put(String(meta.get("key", "")), wav, result)
	_ready_takes.append({"wav": wav, "index": idx,
		"spans": result.get("tokens", []), "phones": result.get("phones", [])})
	_drain_ready()
	_pump()


## A request the host could not make: its slot in the window is free again.
func failed() -> void:
	_in_flight = maxi(0, _in_flight - 1)


# --- the take: joined in order ----------------------------------------------------------------

## Append every chunk that is ready and next in order to the one stream. Out-of-order arrivals wait: audio goes
## out in the order it was written.
func _drain_ready() -> void:
	while true:
		if _fade_done:
			return                   # the outro mark's fade has run out: the reading is over
		var found := -1
		for i in _ready_takes.size():
			if int(_ready_takes[i]["index"]) == _next_to_play:
				found = i
				break
		if found < 0:
			return
				# ...and whatever comes in over it is in hand (next/tabletop.md): once a chunk is on the stream its frames are gone, and a voice arriving late for them has nowhere to go
		if not ReadingJoin.overlaps_ready(chunks, _next_to_play, _ready_takes):
			return
		var take: Dictionary = _ready_takes[found]
		_ready_takes.remove_at(found)
		var idx := int(take["index"])
		_next_to_play += 1

		var pcm := Splice.read_wav(String(take["wav"]))
		if pcm.is_empty() or idx < 0 or idx >= chunks.size():
			continue
		var who := String((chunks[idx] as Dictionary).get("speaker", ""))
				# One join, the export's too ([ReadingJoin]): the seam, the hesitations spliced in, the words in stream time
				# and where the fade starts. The room's marks are scheduled, never dialed here: this runs when a chunk is
				# decoded, seconds ahead of when it is heard, so the marks carry their frames and [method tick] dials each
				# as the push reaches it.
		_join.sr = panel._sr
		_pending.append_array(_join.add(chunks, idx, pcm, take.get("spans", []), panel._cast.cfg_of(who), panel._cast.turn_scale(),
			take.get("phones", [])))
				# ...and the reading ends where the fade does: the rest of this chunk, and every chunk after it, is never heard
		var end := _join.fade_end(_fade_len)
		if end >= 0 and _join.frames >= end:
			_pending.resize(_pending.size() - _join.end_at(end))
			_fade_done = true
			_outro_queued = true
			chunks = chunks.slice(0, _next_to_play)
				# The outro, after the last chunk: silence on the stream, as the intro is silence before the first. A stream
				# that simply runs dry stops the session clock, so the show would freeze on the last word.
		if _next_to_play >= chunks.size() and not _outro_queued:
			var outro := int(maxf(0.0, Director.outro_hold) * float(panel._sr))
			if end >= 0:
				# the text ran out inside the fade: silence to the fade's end, no more
				outro = maxi(0, end - _join.frames)
				_fade_done = true
			_pending.append_array(_join.pad(outro))
			_outro_queued = true
		panel._set_status("Chunk %d of %d - %.0fs of audio ready."
			% [_next_to_play, chunks.size(), float(_join.frames) / float(panel._sr)])
				# Hold the first sample until there is a lead. Chunks are one sentence each and sentence lengths are uneven
				# (1.13 s then 14.49 s on one chapter), so a stream opened on the first chunk drains it and starves while the
				# next is synthesized. The intro doubles as the lead (one condition, not two) and the floor covers an intro
				# turned off. Once open it stays open: a mid-reading stall is the pump's business.
		if not _stream_open:
			var have := float(_pending.size() - _read) / float(panel._sr)
			var lead := maxf(maxf(_lead_in, LIVE_PREROLL), _make_next())
			if have < lead and _next_to_play < chunks.size():
				continue          # keep accumulating; nothing is lost, it is all queued
						# same text, same music: the pad's note choices are seeded
			fx.pad_seed = hash(panel._fingerprint_text())
			fx.setup(panel._sr)
						# every dial onto the fresh chain, in one call, the preset's own nudge to the bed included. The opening
						# voice's, not the tab on screen's.
			_fx_live_name = String((_join.marks[0] as Dictionary).get("speaker", who)) \
				if not _join.marks.is_empty() else who
			Delivery.apply_fx(fx, panel._cast.cfg_of(_fx_live_name))
						# the session opens on the first chunk and never again: one unbroken take, so the Director does not
						# re-cut and the harmonic seed does not re-derive every few sentences
			_stream_open = true
			if panel.begin_stream.is_valid():
				playback = panel.begin_stream.call(hash(panel._fingerprint_text()), panel._sr, _sub_words)
				# the phones ride beside the words, by reference too
				if panel.subtitles != null and is_instance_valid(panel.subtitles):
					panel.subtitles.set("phones", _sub_phones)
						# the place opens with the stream: its first sample is the stream's first, at the show time the stream's
						# frame 0 is heard at
			_open_environment(Spectrum.stream_origin())
						# No scrub hooks here: seeking a live generator is not offered (see the note over the scrub, below).
						# Measure the ring, do not compute it: Godot sizes a generator's buffer to a power of two (131071 frames),
						# not STREAM_BUFFER * sample_rate, so a computed figure made `queued` negative. An empty ring reports its
						# whole capacity as available, and it is empty exactly here, before the first push.
			if playback != null:
				_ring_capacity = int(playback.get_frames_available())


## Chunk [param idx]'s words timed from the spans the host returned ([method ReadingPlan.words_for]), in the take's
## own seconds: the karaoke overlay (main._attach_subtitles picks up any take that has a sidecar).
func words_for(idx: int, spans: Array) -> Array:
	if idx < 0 or idx >= chunks.size():
		return []
	return ReadingPlan.words_for(chunks[idx], spans, "chunk %d" % idx)


# --- the ring: pushed a frame at a time, through the room -------------------------------------

## Feed the ring, every frame of a reading. The generator is the only thing keeping the session alive, so this
## must never fall behind; it is a few array copies a frame.
func tick(delta: float) -> void:
	if playback == null:
		return
	_tick_environment(delta)
		# The picture fades with the voice: the gain of the sample being heard right now, so the outro mark's fade is one
		# fade, in sound and picture, whatever the buffer holds ahead
	if _join.fade_at >= 0 and _ring_capacity > 0:
		var heard := _pushed - maxi(0, _ring_capacity - int(playback.get_frames_available()))
		Director.live_fade = _fade_gain(heard)

		# Re-base the subtitle clock first, and unconditionally: it describes playback, which continues whether or not
		# there is new audio to hand over. Behind an early return on an empty queue, time_base would freeze once
		# synthesis got ahead and the overlay would draw nothing from then on.
	if panel.subtitles != null and is_instance_valid(panel.subtitles) and _ring_capacity > 0:
		var queued := _ring_capacity - int(playback.get_frames_available())
		var played := float(maxi(0, _pushed - maxi(queued, 0))) / float(panel._sr)
		panel.subtitles.time_base = Spectrum.current.time - played

		# The window has to be topped up as it drains, not only on chunk arrival (which stops at the buffer bound).
	if not chunks.is_empty() and _next_to_request < chunks.size():
		_pump()

	if _pending.size() - _read <= 0:
		return
	var room := int(playback.get_frames_available())
	if room <= 0:
		return
	var avail := _fx_admit(_pending.size() - _read)
	var n := mini(room, avail)
		# the place is rendered ahead on a worker ([method Soundscape.prefetch]); a frame takes at most half a second of
		# it, so filling the ring at the start is spread over frames
	if _env != null:
		n = mini(n, panel._sr / 2)
	if n <= 0:
		return
		# the ambience runs here rather than in the host: it is stateful across chunk boundaries, so a seam must not
		# reset the echo tail or the ring
		# ...the voices over this line, each where it sits ([ReadingJoin])
	fx.side = _join.side_between(_pushed, _pushed + n, panel._cast.pan_of)
	var buf: PackedVector2Array = fx.process_stereo(_pending.slice(_read, _read + n))
		# ...and the place after it, so the room and the bed are the voice's and the wind is not
	if _env != null:
		buf = _env.mix(buf)
	if _join.fade_at >= 0:
		for i in n:
			buf[i] *= _fade_gain(_pushed + i)
	playback.push_buffer(buf)
	_pushed += n
	_read += n
		# compact only when the consumed head is worth reclaiming, not every frame
	if _read > 0 and (_read == _pending.size() or _read > 4 * panel._sr):
		_pending = _pending.slice(_read)
		_read = 0


## The room changes at a frame, not at a chunk. Dial in every scheduled change the push has reached, and report
## how many frames may go out before the next one. The coordinate is absolute frames pushed, the only clock these
## marks can use: the ring runs seconds ahead of what is heard, but the chain transforms the samples at exactly
## these positions on their way out. Cut short at the next mark rather than crossing it, or a buffer of one
## speaker is read in the other's room. Split out of [method tick] because this arithmetic can be wrong by a buffer.
func _fx_admit(avail: int) -> int:
	var marks := _join.marks
	while not marks.is_empty() and int((marks[0] as Dictionary)["at"]) <= _pushed:
		var m: Dictionary = marks.pop_front()
		if m.has("speaker"):
			_fx_live_name = String(m["speaker"])
			Delivery.apply_fx(fx, panel._cast.cfg_of(_fx_live_name))
			fx.heard = String(m.get("heard", ""))
		if m.has("near"):
			Delivery.near_to(fx, m["near"])
	if marks.is_empty():
		return avail
	return mini(avail, maxi(0, int((marks[0] as Dictionary)["at"]) - _pushed))


## The outro mark's fade at stream sample [param sample]: 1 before it starts, easing to 0 over
## [member _fade_len], 0 after.
func _fade_gain(sample: int) -> float:
	var at := _join.fade_at
	if at < 0 or sample < at:
		return 1.0
	var u := float(sample - at) / maxf(1.0, _fade_len * float(panel._sr))
	return 0.0 if u >= 1.0 else 0.5 + 0.5 * cos(PI * u)


## A dial moved on the panel, applied to the live chain, but only if the tab being edited is the voice currently
## sounding (reverb turned up on a character who has not spoken yet must not put the narrator in a cathedral). The
## setting is stored either way and arrives at that character's first word through the join's marks
## ([member ReadingJoin.marks]).
func live_fx() -> void:
	if not _fx_live_name.is_empty() and _fx_live_name != panel._cast.tab_name():
		return
	_fx_live_name = panel._cast.tab_name()
	Delivery.apply_fx(fx, panel._cast.slot_cfg(panel._cast.slot))


# --- the place under the voice ----------------------------------------------------------------

func _open_environment(t0: float) -> void:
	_close_environment()
	var place := panel.bed.of()
	_env_key = String(place.get("key", ""))
	_env_poll = 0.0
	if not place.has("make"):
		return
	var env: SoundBed = (place["make"] as Callable).call(panel._sr, t0)
	if env == null or not env.active():
		return
	env.set_level(panel.bed.level())
	env.prefetch()
	_env = env


func _close_environment() -> void:
	if _env != null:
		_env.finish()
	_env = null


## Every frame of a reading: keep the place rendered ahead, follow the dial, and every couple of seconds see
## whether the place itself changed (live, the set dresser can hand a table in mid-reading) and, if so, carry on
## from here with the new one.
func _tick_environment(delta: float) -> void:
	if _env != null:
		_env.set_level(panel.bed.level())
		_env.prefetch()
	if not _stream_open:
		return
	_env_poll += delta
	if _env_poll < 2.0:
		return
	_env_poll = 0.0
	var place := panel.bed.of()
	if String(place.get("key", "")) != _env_key:
		_open_environment(Spectrum.stream_origin() + float(_pushed) / float(panel._sr))

extends RefCounted
class_name ReadingStream

## ReadingStream - the reading on the stream: THE SLIDING WINDOW. A chapter is far too long to
## synthesize up front: at roughly 4x real time, twenty minutes of narration is five minutes of
## silence before anything plays. So the text is planned into chunks at sentence boundaries
## ([ReadingPlan]) and only [constant LOOKAHEAD] of them are ever in flight. The first chunk plays
## while the second is still being made, and each finished one pulls the next one in. First audio
## arrives in seconds however long the chapter is, and memory stays bounded.
##
## A PART OF ITS PANEL (next/structure.md, step 20). It holds the reading on the stream - its plan,
## the requests in flight and the takes come back, the one continuous stream and its ring, the take
## being joined ([ReadingJoin]: the seams, the room's marks, the words, the outro mark's fade), the
## live effects chain and the place under the voice - and asks the [ReadingPanel] it is part of for
## the words, a voice's settings, the host and the requests. The panel asks it to play, stop,
## re-pace and seek, and, for the transport, where it is.

## The [ReadingPanel] this is a part of: everything read through it is something this part
## is handed, and the list of them is what it depends on.
var panel: ReadingPanel

const LOOKAHEAD := 2           # chunks in flight; 1 would stall at every seam
# ...and a bound on how much finished audio may sit AHEAD of the playhead.
#
# LOOKAHEAD alone throttles concurrency, not depth: chunks were requested as
# fast as they arrived, so at ~4x real time the whole chapter ended up decoded
# and queued within a minute. Nothing was wrong with the audio, but a tone or
# pace change then had nothing left to affect - every remaining chunk was
# already made - so the switch appeared to take "ages". Keeping only a few
# seconds buffered is what makes the window actually slide.
# Must comfortably EXCEED the generator's own ring (measured 131071 frames,
# 5.94 s at 22050) - otherwise the ring drains while the next chunk is still
# being synthesized and playback stalls, which is heard as a pause every few
# chunks and seen as the visualizer freezing with it. 3.0 was below the ring and
# did exactly that. The cost is switch latency, which is why chunks are single
# sentences: small chunks keep the window shallow in TIME while still deep
# enough in SECONDS to never starve.
const LOOKAHEAD_SECONDS := 9.0
## Seconds of audio that must be queued before the first sample is heard, when there is
## no intro to serve as the lead. Chunks are one sentence, and a short opening sentence
## (1.13 s, measured) cannot cover the synthesis of a long second one (14.49 s), so
## playback starves without a floor here. It is a LOWER bound on latency-to-first-word,
## which is why it is not larger.
const LIVE_PREROLL := 2.5

# THE PLAN on the stream ([ReadingPlan])
var chunks: Array = []        # [{tokens, words, ...}] planned up front, cheap
## The reading on the stream no longer matches the panel: the next Play reads it again.
var stale := false
## THE OUTRO MARK, live: how long the fade is (0 = no mark; where it starts is the join's,
## [member ReadingJoin.fade_at]).
var _fade_len := 0.0
# THE PREDICTED TIMELINE. The scrub bar used to be scaled by how much audio had been
# DECODED, which grows as the reading is synthesized - so the bar's own length changed
# under the pointer and dragging to "near the end" meant near the end of the first thirty
# seconds. A timeline has to know how long the thing is before it plays it.
var _chunk_t := PackedFloat32Array()     # chunk -> its estimated start along the reading, s (n + 1)
## LIVE SCRUBBING, BY SENTENCE. A live reading is synthesized a sentence or two ahead, so there
## is no audio behind or ahead of the playhead to seek within. The transport's rail (through the
## panel's conductor hooks, [method ReadingPanel.transport_hooks]) therefore seeks by SENTENCE: its
## positions are estimated sentence starts, and a seek is Stop + Play from that sentence - a fresh
## reading that is only synthesized from there on. The media start in the state they would be in
## at that point (book_document()["start_words"]). The in-place generator seek stays withdrawn
## (see the note over the scrub); this never seeks a stream, it ends one and starts another, as
## Stop then Play does.
var _start_chunk := 0
var _seek_k := -1                        # a seek waiting for the bar to settle

# THE WINDOW: what is asked of the host and what has come back
var _ready_takes: Array = []   # [{wav, index, spans}] synthesized, awaiting the push
var _next_to_request := 0
var _next_to_play := 0
var _in_flight := 0
var _req_chunk := {}           # request id -> {idx, epoch}
var _epoch := 0                # bumped on a pace change; stale replies are dropped

# THE ONE CONTINUOUS STREAM
var playback: AudioStreamGeneratorPlayback
var _stream_open := false      # explicit: a null playback must not retry forever
var _pending := PackedFloat32Array()   # decoded samples not yet handed to the ring
var _read := 0                 # cursor into _pending; slicing it per frame was
                               # an O(n) copy of the whole queue 60 times a
                               # second, which is its own source of hitching
var _pushed := 0               # frames handed to the ring, for the played-time clock
var _ring_capacity := 0        # measured, never computed - see _drain_ready
var _lead_in := 0.0            # the intro seeded into _pending by plan, in seconds
var _outro_queued := false     # the outro's silence is on the stream (see the drain)
var _fade_done := false        # the outro mark's fade has run out: the reading is cut
var _sub_words: Array = []     # shared BY REFERENCE with the Subtitles overlay
var _sub_phones: Array = []    # ...and the phones, the same way (Subtitles.phones)
## THE TAKE BEING JOINED ([ReadingJoin]): the frames queued on the stream from its first (the intro's
## silence included), the room's marks - WHEN THE ROOM CHANGES, in those frames: the effects chain is
## stateful across chunk boundaries, which is the whole reason it runs here rather than in the host,
## so a second speaker gets the same chain re-dialed at the exact frame their first sample is heard,
## which is what a live slider move already does, just scheduled ([method _fx_admit] consumes them) -
## where each chunk starts and where the outro mark's fade does. A fresh one for every reading.
var _join := ReadingJoin.new()

# THE LIVE CHAIN: the voice's room, run here rather than in the host
var fx := VoiceFX.new()
var _fx_live_name := ""        # which voice the live chain is currently dialed to

## THE PLACE UNDER THE VOICE (a [SoundBed]): the wind, the sea, the rain of where the reading is, mixed
## in after the voice's own effects - live here, and into the exported take by
## [method ReadingPanel.export_take]. A component that knows where its reading is says so through the
## panel's [member ReadingPanel.bed]; null when none does.
var _env: SoundBed = null
var _env_key := ""             # the place it was made from, to notice the place changing mid-reading
var _env_poll := 0.0


func _init(owner: ReadingPanel) -> void:
	panel = owner


# --- playing, stopping, and reading from part way ---------------------------------------------

## Play: read the script from the top - or, while a reading plays, pause it and carry on.
## SPEAK IS A TOGGLE while a reading plays: Pause, then Resume, from where it was. It restarted
## the reading from the top every time, and "there are times when I need to pause the
## visualization and come back to it later". Reading again from the top is Stop, then Play.
func play() -> void:
	if live():
		Spectrum.set_paused(not Spectrum.paused)
		panel._set_status("Paused. Space or ▶ carries on; ■ ends the reading."
			if Spectrum.paused else "Resumed.")
		return
	if panel._host == null or not panel._host.is_up() or panel._cast.voice_pick.selected < 0:
		return
	# THE REAL-TIME READ. In sync mode this is the file as it is on disk RIGHT NOW, not as
	# it was when the document was opened - which is what lets the author keep writing in
	# their own editor with ghost open beside it.
	var body := panel._reading_body().strip_edges()
	if body.is_empty():
		panel._set_status("Nothing to read yet: write the words on the Script card, then press ▶.")
		return
	# The cast NOW, not at the next pause in typing: a name written a moment ago must read in
	# its own voice from the first Play.
	panel._cast.refresh(body)
	if panel._test_busy():
		panel._stop_test()
	# plan is a full teardown - stream closed, queues emptied, pending request
	# ids dropped so replies for the OLD text are discarded on arrival rather
	# than spliced into the new reading.
	plan(body)
	if chunks.is_empty():
		panel._set_status("Nothing speakable in that text.")
		return
	stale = false
	Spectrum.set_stream_paused(false)
	_sync_speak_buttons()
	panel._set_status("Planned %d chunk(s). Synthesizing the first…%s" % [chunks.size(), panel._plan_note])
	_pump()


## Tear the stream down and read again from the top. plan clears the pending
## request map, so replies still in flight for the old voice are dropped on
## arrival rather than spliced in.
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


## STOP: end the reading and hand the stage back.
##
## There was no way to do this. The Speak button's tooltip claimed "press again while it is
## running to stop" and that was simply untrue - play re-plans and reads again from the
## top, whatever is playing. Reported as: "it would be preferable to stop the real-time scene
## before I do an export, and today I've just been restarting the program."
##
## Tearing down the STREAM is the half the editor cannot do alone: the playback, the Director's
## attachment to the stage and the subtitle overlay all belong to the owner, which is why
## `end_stream` exists and is wired beside `begin_stream` (see main._end_generative_stream).
## The synth editor has had both since it was written; this path was given only the opening
## half, so nothing was ever able to close it.
func stop() -> void:
	if chunks.is_empty() and playback == null:
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
	# THE INTRO, seeded HERE rather than at the moment the stream opens - see the note in
	# _reset_playback's lead-in block, which this replaces for a reading that is starting.
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


## EVERY PIECE OF STATE A READING OWNS, put back. Split out of [method plan] so that
## stopping and re-planning cannot drift apart: they were one block, and a Stop button that
## reset "most of" it is the kind that leaves a stream half open.
##
## The pending request map is the important one. Replies for chunks already asked for are still
## in flight on the host, and dropping their ids here is what makes them discarded on arrival
## instead of spliced into a reading that no longer exists.
func _reset_playback() -> void:
	chunks = []
	_ready_takes = []
	_req_chunk = {}
	_next_to_request = 0
	_next_to_play = 0
	_in_flight = 0
	_stream_open = false
	playback = null
	_pushed = 0
	_ring_capacity = 0
	_pending = PackedFloat32Array()
	_read = 0
	_fx_live_name = ""
	# The intro silence belongs to a reading that is STARTING, so it is seeded in plan and
	# only cleared here. The join's frames are the clock every word span and every seam is
	# measured against, so starting them at the end of that silence offsets the whole reading,
	# subtitles included, with nothing else needing to know. Inserting it later would put it AFTER
	# the first sentence - the audition spoke its opening line, went quiet for five seconds, then
	# carried on.
	_lead_in = 0.0
	_close_environment()
	_outro_queued = false
	_fade_done = false
	Director.live_fade = 1.0
	_sub_words.clear()          # cleared in place: Subtitles holds this by reference
	_sub_phones.clear()
	_join = ReadingJoin.new(panel._sr, _sub_words)
	_join.phones = _sub_phones


## Play and Stop, from one place. Two buttons whose enabled state is set at each of the
## several points a reading starts or ends is two buttons that will eventually disagree.
func _sync_speak_buttons() -> void:
	if chunks.is_empty():
		stale = false


## Read from sentence [param k]: Stop, then Play from there. The old stream is ENDED (the voice
## stops at once and the stage is handed back), then a fresh reading is planned and requested
## from [param k] on, with no intro. The media start where it starts ([method start_words]).
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


## The first words of the chunk a reading starts at, normalized ([method ReadingPlan.start_words]) -
## how a medium finds its place. Empty for a reading from the top.
func start_words() -> PackedStringArray:
	return ReadingPlan.start_words(chunks, _start_chunk)


## A reading that is still going: planned, and not yet played out to the end. A generated
## stream never announces its end, so "every chunk played and the buffer drained" is the end -
## and then Play reads again from the top rather than pausing silence.
func live() -> bool:
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
	return label + (" ●" if stale and not chunks.is_empty() else "")


## The reading on the stream no longer matches the panel. The same dot the text
## box raises, and for the same reason: the cast changed under what is playing.
func mark_stale() -> void:
	if not chunks.is_empty():
		stale = true


## Re-generate everything not yet committed to the stream, at the new pace.
##
## Audio already pushed - and audio decoded and waiting in _pending - is
## finished business: its subtitles are placed and the join has moved past
## it, so rewriting it would desync the overlay. Everything from the next
## un-drained chunk onward is thrown away and re-requested, so the new pace
## lands within a chunk or two rather than at the end of the chapter.
func repace() -> void:
	if chunks.is_empty() or _next_to_play >= chunks.size():
		return
	_epoch += 1                     # in-flight replies from the old pace are now stale
	_ready_takes.clear()
	# The host keeps computing what it was given (there is no cancel - see [method arrived]), so
	# the accounting for it has to survive or the pump will pile more on top.
	_next_to_request = _next_to_play
	panel._set_status("%s at pace %.2fx, pause %.2fx - regenerating from chunk %d…"
		% [panel._cast.tab_name(), panel._cast._rate.value, clampf(panel._cast._pause.value, 0.0, Delivery.MAX_PAUSE_SCALE), _next_to_play + 1])
	_pump()


# --- the scrub --------------------------------------------------------------------------------
# SEEKING A LIVE GENERATOR IS WITHDRAWN, and this note is the record of why.
#
# It was built, it worked in the sense that the playhead moved, and it was wrong in two
# ways that only showed up in use. A generator's ring cannot be cleared while playback is
# active, so every seek had to stop and restart the stream - and repeated restarts left
# the session audibly wrong, the voice doubling and then trebling as more seeks were made,
# with the Director's transitions stalling alongside it. Neither reproduced in a headless
# measurement (a freshly synthesized take autocorrelates clean, with no delayed copy), and
# guessing further at engine-side playback state without being able to run the UI is how
# the first two attempts at this shipped.
#
# The deeper problem is that it could not have served its purpose anyway. The reason to
# scrub is to check what a given moment WILL LOOK LIKE when exported - and a seek cannot
# answer that here, because the Director is a simulation rather than a function of time:
# its scene choice and hold schedule evolve from the events it has actually seen, so
# seeking forward shows the scene that happens to be up rather than the one the export
# will have. A control that answers a different question from the one being asked is worse
# than no control.
#
# What DOES answer it: render the take, then open the rendered file. A file boot is
# seekable for real (one operation, no restart - see Spectrum.seek) and replays the same
# deterministic show from the same seed, so scrubbing it shows exactly what the export
# will contain. `--scene <name>` remains the fastest way to inspect one scene.

## The scrub bar's length: the whole reading, estimated.
func length() -> float:
	return _chunk_t[_chunk_t.size() - 1] if not _chunk_t.is_empty() else 0.0


## The scrub bar's position: where a waiting seek is going, else the sentence being heard and
## how far through it, on the estimated scale.
func position() -> float:
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
	var k := 0
	for i in _chunk_t.size() - 1:
		if _chunk_t[i] <= t:
			k = i
	_seek_k = k
	if panel._seek_timer != null and panel._seek_timer.is_inside_tree():
		panel._seek_timer.start()


## The bar has settled: read from the sentence a seek waits on.
func seek_now() -> void:
	var k := _seek_k
	if k >= 0:
		speak_from(k)


# --- the window: what is asked of the host ----------------------------------------------------

## How much finished audio is waiting to be heard: decoded but not yet pushed,
## plus whatever is still sitting in the ring.
func _buffered_seconds() -> float:
	var queued := 0
	if playback != null and _ring_capacity > 0:
		queued = maxi(0, _ring_capacity - int(playback.get_frames_available()))
	return float(maxi(_pending.size() - _read, 0) + queued) / float(maxi(panel._sr, 1))


## Keep LOOKAHEAD chunks in flight and start playback as soon as the chunk we
## are waiting for exists.
func _pump() -> void:
	if panel._cast.voice_meta.is_empty():
		return
	# THE INTRO IS NOT LOOKAHEAD. It is seeded into the queue as silence before anything is
	# requested, so counting it made an Intro of LOOKAHEAD_SECONDS or more look like a full
	# buffer: nothing was ever requested, the stream never opened, and Play did nothing at
	# all ("at 9 the video breaks, at 7 it works"). Only the SPEECH queued counts; the intro
	# still to be pushed is taken off (an underestimate once it plays, so it stays safe).
	var intro_left := maxf(0.0, _lead_in - float(_pushed) / float(maxi(panel._sr, 1)))
	var planned := false
	while _in_flight < LOOKAHEAD and _next_to_request < chunks.size() \
			and _buffered_seconds() - intro_left < LOOKAHEAD_SECONDS:
		var idx := _next_to_request
		if not planned:
			planned = true
			panel._plan_near(chunks, idx)
		_next_to_request += 1
		_in_flight += 1
		var s := panel._cast.cfg_of(String((chunks[idx] as Dictionary).get("speaker", "")))
		var id := panel._host.request("", panel._cast.voice_id_of(s),
			ReadingPanel.TAKE_DIR + "/chunk_%d_%d.wav" % [idx, _epoch], panel._request_args(s, chunks[idx]), null)
		_req_chunk[id] = {"idx": idx, "epoch": _epoch}


## Whether the host's reply [param id] is a chunk of the reading on the stream - or one it asked for
## before a re-pace or a jump, which is dropped on arrival.
func owns(id: int) -> bool:
	return _req_chunk.has(id)


## A chunk the reading asked for came back: into the queue, in order ([method _drain_ready]).
func arrived(id: int, result: Dictionary) -> void:
	var meta: Dictionary = _req_chunk[id]
	_req_chunk.erase(id)
	# THE SLOT IS FREED WHETHER OR NOT THE RESULT IS WANTED, and this has to happen BEFORE
	# the epoch check. It did not, and that is what made seeking slower than a cold start:
	# an abandoned request still occupies the host - the protocol has no cancel - so a jump
	# that zeroed the counter let _pump send a full lookahead on top of work already
	# queued, and the chunk actually being waited for ended up third or fourth in line.
	# Counting abandoned work as in-flight means the new request enters the queue exactly
	# when a slot frees, which without a cancel is the best available.
	_in_flight = maxi(0, _in_flight - 1)
	if int(meta["epoch"]) != _epoch:
		# Superseded by a pace change or a jump. Nothing to keep, but the pump may now
		# have room it did not have a moment ago.
		_pump()
		return
	var idx: int = int(meta["idx"])

	var wav := String(result.get("wav", ""))
	if wav.is_empty():
		panel._set_status("The host returned no audio.")
		return
	panel._sr = int(result.get("sample_rate", panel._sr))
	_ready_takes.append({"wav": wav, "index": idx,
		"spans": result.get("tokens", []), "phones": result.get("phones", [])})
	_drain_ready()
	_pump()


## A request the host could not make: its slot in the window is free again.
func failed() -> void:
	_in_flight = maxi(0, _in_flight - 1)


# --- the take: joined in order ----------------------------------------------------------------

## Append every chunk that is ready AND next in order to the one stream. Out of
## order arrivals wait: audio has to go out in the order it was written.
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
		var take: Dictionary = _ready_takes[found]
		_ready_takes.remove_at(found)
		var idx := int(take["index"])
		_next_to_play += 1

		var pcm := Splice.read_wav(String(take["wav"]))
		if pcm.is_empty() or idx < 0 or idx >= chunks.size():
			continue
		var who := String((chunks[idx] as Dictionary).get("speaker", ""))
		# ONE JOIN, THE EXPORT'S TOO ([ReadingJoin]): the seam, the hesitations spliced in, the words
		# in stream time and where the fade starts. The room's marks are SCHEDULED, never dialed
		# here: this runs when a chunk is DECODED, seconds ahead of when it is heard, so dialing the
		# chain now would put the next speaker's room over the end of this one's last sentence - the
		# marks carry their frames and [method tick] dials each as the push reaches it.
		_join.sr = panel._sr
		_pending.append_array(_join.add(chunks, idx, pcm, take.get("spans", []), panel._cast.cfg_of(who), panel._cast.turn_scale(),
			take.get("phones", [])))
		# ...and the reading ENDS where the fade does: the rest of this chunk, and every
		# chunk after it, is never heard
		var end := _join.fade_end(_fade_len)
		if end >= 0 and _join.frames >= end:
			_pending.resize(_pending.size() - _join.end_at(end))
			_fade_done = true
			_outro_queued = true
			chunks = chunks.slice(0, _next_to_play)
		# THE OUTRO, after the last chunk: silence on the stream, the way the intro is silence
		# before the first and the export pads both ends. A stream that simply runs dry stops the
		# session clock with it, so the show froze on the last word instead of playing out the
		# outro ("it doesn't respect the 7.0 second outro I specified").
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
		# HOLD THE FIRST SAMPLE UNTIL THERE IS A LEAD. Chunks are one sentence each
		# (CHUNK_SENTENCES = 1), and sentence lengths are wildly uneven: measured on
		# chapter 3, the opening sentence renders to 1.13 s and the next to 14.49 s. The
		# stream used to open on whatever the first chunk happened to be, so playback
		# drained that 1.13 s and then starved for as long as the 14.49 s sentence took
		# to synthesize. Nothing was wrong with the audio - no chunk carries more than
		# 0.27 s of internal silence - it simply ran out.
		#
		# So wait for a real lead before starting. The intro doubles as that lead, which
		# is why this is one condition and not two, and the floor covers the case where
		# the intro is turned off entirely. Once open it stays open: the drain is
		# continuous from here and a mid-reading stall is the pump's business, not this.
		if not _stream_open:
			var have := float(_pending.size() - _read) / float(panel._sr)
			var lead := maxf(_lead_in, LIVE_PREROLL)
			if have < lead and _next_to_play < chunks.size():
				continue          # keep accumulating; nothing is lost, it is all queued
			# same text, same music: the pad's note choices are seeded
			fx.pad_seed = hash(panel._fingerprint_text())
			fx.setup(panel._sr)
			# every dial onto the fresh chain, in one call - the preset's own nudge
			# to the bed included: a mood is carried by the room as much as by the
			# reading. The opening voice's, not the tab on screen's.
			_fx_live_name = String((_join.marks[0] as Dictionary).get("speaker", who)) \
				if not _join.marks.is_empty() else who
			Delivery.apply_fx(fx, panel._cast.cfg_of(_fx_live_name))
			# the session opens on the FIRST chunk and never again - that is the
			# whole point: one unbroken take, so the Director does not re-cut
			# and the harmonic seed does not re-derive every few sentences
			_stream_open = true
			if panel.begin_stream.is_valid():
				playback = panel.begin_stream.call(hash(panel._fingerprint_text()), panel._sr, _sub_words)
				# the phones ride beside the words, by reference too
				if panel.subtitles != null and is_instance_valid(panel.subtitles):
					panel.subtitles.set("phones", _sub_phones)
			# the place opens with the stream: its first sample is the stream's first, at the show
			# time the stream's frame 0 is heard at
			_open_environment(Spectrum.stream_origin())
			# NO SCRUB HOOKS HERE. Seeking a live generator was implemented and is
			# WITHDRAWN - see the note over the scrub, below.
			# MEASURE the ring, do not compute it. Godot sizes a generator's
			# buffer to a power of two (131071 frames measured), not to
			# STREAM_BUFFER * sample_rate (88200) - so the computed figure made
			# `queued` NEGATIVE, `played` start ~1.9 s ahead, and the subtitles
			# open in the middle of the text. An empty ring reports its whole
			# capacity as available, and it is empty exactly here, before the
			# first push.
			if playback != null:
				_ring_capacity = int(playback.get_frames_available())


## Chunk [param idx]'s words timed from the spans the host returned ([method ReadingPlan.words_for]),
## in the take's own seconds. This is what restores the karaoke overlay: main._attach_subtitles picks
## up any take that has a sidecar, so the neural path gets subtitles with no special casing anywhere.
func words_for(idx: int, spans: Array) -> Array:
	if idx < 0 or idx >= chunks.size():
		return []
	return ReadingPlan.words_for(chunks[idx], spans, "chunk %d" % idx)


# --- the ring: pushed a frame at a time, through the room -------------------------------------

## FEED THE RING, every frame of a reading. The generator is the only thing keeping the session
## alive, so this must never fall behind; it is a few array copies a frame.
func tick(delta: float) -> void:
	if playback == null:
		return
	_tick_environment(delta)
	# THE PICTURE FADES WITH THE VOICE: the gain of the sample being heard right now, so the
	# outro mark's fade is one fade, in sound and picture, whatever the buffer holds ahead
	if _join.fade_at >= 0 and _ring_capacity > 0:
		var heard := _pushed - maxi(0, _ring_capacity - int(playback.get_frames_available()))
		Director.live_fade = _fade_gain(heard)

	# RE-BASE THE SUBTITLE CLOCK FIRST, and unconditionally.
	#
	# This used to sit at the BOTTOM of the push block, after an early return on
	# an empty queue - so the moment synthesis got ahead of playback and there
	# was nothing left to push, the re-base stopped running and time_base froze.
	# Spectrum's clock kept advancing against a stale base, _now() ran past the
	# last word, and the overlay drew nothing from then on. Reported as: the
	# subtitles worked briefly, then disappeared and never came back.
	#
	# It belongs here because it describes PLAYBACK, which continues whether or
	# not there is new audio to hand over.
	if panel.subtitles != null and is_instance_valid(panel.subtitles) and _ring_capacity > 0:
		var queued := _ring_capacity - int(playback.get_frames_available())
		var played := float(maxi(0, _pushed - maxi(queued, 0))) / float(panel._sr)
		panel.subtitles.time_base = Spectrum.current.time - played

	# The window has to be topped up as it drains. Requests used to be driven
	# only by chunk ARRIVAL, which stops the moment the buffer bound is hit.
	if not chunks.is_empty() and _next_to_request < chunks.size():
		_pump()

	if _pending.size() - _read <= 0:
		return
	var room := int(playback.get_frames_available())
	if room <= 0:
		return
	var avail := _fx_admit(_pending.size() - _read)
	var n := mini(room, avail)
	# the place is rendered ahead on a worker ([method Soundscape.prefetch]); a frame takes at most half
	# a second of it, so filling the ring at the start is spread over frames rather than one long one
	if _env != null:
		n = mini(n, panel._sr / 2)
	if n <= 0:
		return
	# the ambience runs HERE rather than in the host: it is stateful across
	# chunk boundaries, so a seam must not reset the echo tail or the ring
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


## THE ROOM CHANGES AT A FRAME, not at a chunk. Dial in every scheduled change the
## push has reached, and report how many frames may go out before the next one.
##
## The coordinate is ABSOLUTE FRAMES PUSHED, which is the only clock these marks
## can use. It is not what is being heard - the ring runs seconds ahead - and it
## does not need to be: the chain transforms the samples at exactly these
## positions on their way out, so aligning to the push aligns to the audio. Cut
## short at the next mark rather than crossing it, or a whole buffer of one
## speaker is read in the other's room.
##
## Split out of [method tick] because it is the arithmetic here that can be
## wrong by a buffer, and a room that arrives a moment early is audible without
## being attributable.
func _fx_admit(avail: int) -> int:
	var marks := _join.marks
	while not marks.is_empty() and int((marks[0] as Dictionary)["at"]) <= _pushed:
		var m: Dictionary = marks.pop_front()
		if m.has("speaker"):
			_fx_live_name = String(m["speaker"])
			Delivery.apply_fx(fx, panel._cast.cfg_of(_fx_live_name))
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


## A dial moved on the panel, applied to the LIVE chain - but only if the tab
## being edited is the voice currently sounding. Turning up the reverb on a
## character who has not spoken yet must not put the narrator in a cathedral;
## the setting is stored either way, and arrives at that character's first word
## through the join's marks ([member ReadingJoin.marks]).
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


## Every frame of a reading: keep the place rendered ahead, follow the dial, and every couple of
## seconds see whether the place itself changed (live, the set dresser can hand a table in mid-reading),
## and if so carry on from here with the new one.
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

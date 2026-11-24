extends Node

## stream_chain_check - a live reading's loops over every sample run on workers, never on the app's thread
## ([ReadingStream]):
##
##   tests/run_boot_probe.sh tests/reading/stream_chain_check.gd 90
##
## A boot probe: the stream names the Spectrum autoload. The panel is built by hand and never added to the tree (its
## `_ready` starts the voice host); the ring is a real generator's, held paused so nothing here depends on how fast
## it drains. The chain is a [VoiceFX] that notes the thread each piece runs on and keeps what it made.
##
## Holds:
##
## - the room is a worker's: three seconds of voice on an empty ring, and the frame that finds them hands the ring
##   nothing and the chain a piece of at most [constant ReadingStream.FX_PIECE]; no piece runs on this thread;
## - every frame comes out once, in order, in its own voice's room: what the pieces made is what one chain makes of
##   the same audio cut at the same frames, a piece ends at the handover and the second voice's room is dialed there;
##   all of it reaches the ring, and the window counts it while it is in the room;
## - a dial moved while a piece is on the worker waits for it: the chain is untouched until the piece is back;
## - Stop with a piece on the worker leaves no worker in the chain and nothing of the reading behind;
## - a take lands on a worker: asked to land, nothing is decoded in the call; landed, it is the file's samples in the
##   queue, and kept under its key ([TakeCache], moved aside);
## - a long script's plan is a worker's ([method ReadingPanel.plan_ahead]): Play plans nothing in the call and asks
##   the host for nothing, Play again changes nothing, and when the plan lands Play carries on - the plan is the one
##   [method ReadingPlan.make] makes here, and the host is asked for the window's first sentences;
## - the plan is kept: a seek plans nothing (the plan kept is the same one, its words the reading's own), and each
##   asker's chunks are its own (a mark written on one is on no other);
## - Stop while the plan is made ends it: the plan lands and nothing plays;
## - a seek after the words were written on is a worker's plan too: nothing is planned in the call, the reading on the
##   stream stays as it is with the bar on the sentence sought, and when the plan lands the reading starts there.
##
## Controls: the same audio put through the same chain from this thread, as a frame's push once did, is seen on it;
## a script under [constant ReadingPanel.PLAN_AWAY] is planned in the call; other words are planned anew.

const RATE := 22050
const SECONDS := 3.0
const HANDOVER := 30000            # the frame the second voice comes in at
const SCRATCH := "user://stream_chain_check"

var _fails: Array = []
var _ed: ReadingPanel
var _player: AudioStreamPlayer
var _host: Host


## A voice host that notes what it is asked and makes nothing.
class Host extends VoiceHost:
	var asked: Array = []

	func request(_text: String, voice: String, out_path: String,
			params: Dictionary = {}, _phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 5000 + asked.size()

	func is_up() -> bool:
		return true


## A walk that reads the words it holds, whatever the panel pulled.
class Fixed extends TextWalk:
	var words := ""

	func body(_pulled: String) -> String:
		return words


## A chain that says where it ran: the thread of each piece, each piece's length, and everything it made.
class Tap extends VoiceFX:
	var threads: Array = []
	var sizes: PackedInt32Array = PackedInt32Array()
	var made := PackedVector2Array()
	var inside := 0

	func process_stereo(buf: PackedFloat32Array) -> PackedVector2Array:
		inside += 1
		threads.append(OS.get_thread_caller_id())
		sizes.append(buf.size())
		var out := super(buf)
		made.append_array(out)
		inside -= 1
		return out


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _ready() -> void:
	_ed = ReadingPanel.new()
	_ed._build_panel()
	_ed.walk = TextWalk.new()
	if _ed._doc != null:
		_ed._doc._sync = false
	_run.call_deferred()


func _run() -> void:
	await _check_the_room_is_a_workers()
	await _check_a_take_lands_on_a_worker()
	await _check_a_long_plan_is_a_workers()
	print("")
	if _fails.is_empty():
		print("stream_chain_check: ALL OK - the room and the takes are workers' work.")
	else:
		print("stream_chain_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	_ed._stream._reset_playback()
	_ed._plans_finish()
	if _player != null:
		_player.queue_free()
	if _host != null:
		_host.free()
	for _i in 4:
		await get_tree().process_frame
	_ed.free()
	get_tree().quit(1 if not _fails.is_empty() else 0)


## A voice to put through the room: a tone that swells, so every frame differs from the one a piece away.
func _voice() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(SECONDS * RATE))
	for i in out.size():
		out[i] = 0.3 * sin(TAU * 180.0 * float(i) / RATE) * (0.4 + 0.6 * float(i) / float(out.size()))
	return out


func _two_voices() -> void:
	var names := [Manuscript.NARRATOR, "Voice 2"]
	_ed._cast._names = PackedStringArray(names)
	_ed._cast._slots = []
	for i in names.size():
		_ed._cast._slots.append(ReadingPanel.SLOT_DEFAULTS.duplicate(true))
	_ed._cast._stash = {}
	_ed._cast._order = PackedStringArray(names)
	_ed._cast.slot = 0
	_ed._cast._slots[0]["room"] = 0.3
	_ed._cast._slots[1]["echo"] = 0.9


## A stream with [param dry] on its queue and an empty ring, the chain [param tap]: the state a sentence landing on a
## queue run dry leaves.
func _open(dry: PackedFloat32Array, tap: VoiceFX) -> void:
	var s := _ed._stream
	s._reset_playback()
	_ed._sr = RATE
	if _player == null:
		_player = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = Spectrum.STREAM_BUFFER
		_player.stream = gen
		add_child(_player)
	_player.play()
	_player.stream_paused = true
	s.playback = _player.get_stream_playback()
	s._ring_capacity = int(s.playback.get_frames_available())
	tap.pad_seed = 7
	tap.setup(RATE)
	s.fx = tap
	s._pending = dry
	s._join.frames = dry.size()
	s._join.marks = [{"at": 0, "speaker": Manuscript.NARRATOR}, {"at": HANDOVER, "speaker": "Voice 2"}]


func _check_the_room_is_a_workers() -> void:
	print("")
	print("the_room_is_a_workers")
	_two_voices()
	var dry := _voice()
	var tap := Tap.new()
	_open(dry, tap)
	var s := _ed._stream
	_ok(s._ring_capacity > dry.size(), "the ring holds all of it: %d frames of room for %d" % [s._ring_capacity, dry.size()])
	var piece_most := int(ReadingStream.FX_PIECE * RATE)
	s.tick(0.016)
	_ok(s._pushed == 0 and s._wet.is_empty(), "the frame that finds the voice hands the ring nothing (%d pushed)" % s._pushed)
	_ok(not s._fx_task.is_empty() and int(s._fx_task.get("n", 0)) > 0 and int(s._fx_task.get("n", 0)) <= piece_most,
		"...and a worker a piece of at most %d frames (%d)" % [piece_most, int(s._fx_task.get("n", 0))])
	_ok(is_equal_approx(s._buffered_seconds(), SECONDS), "the window counts what is in the room: %.2f s of %.2f" % [s._buffered_seconds(), SECONDS])
	# a dial moved now is the worker's chain's to wait for
	var echo_was := tap.echo_wet
	var turned := (_ed._cast.slot_cfg(0) as Dictionary).duplicate(true)
	turned["echo"] = 0.6
	s.dial(turned)
	_ok(is_equal_approx(tap.echo_wet, echo_was) and not s._dial.is_empty(), "a dial moved while a piece is on the worker waits for it")
	var frames := 0
	var dialed := -1.0
	while (s._pushed < dry.size() or not s._fx_task.is_empty()) and frames < 3000:
		await get_tree().process_frame
		s.tick(0.016)
		frames += 1
		if dialed < 0.0 and s._dial.is_empty():
			dialed = tap.echo_wet
	_ok(is_equal_approx(dialed, 0.6), "...and is dialed in when it is back (echo %.2f)" % dialed)
	_ok(s._pushed == dry.size() and s._through == dry.size(), "every frame went through the room and into the ring (%d and %d of %d)"
		% [s._through, s._pushed, dry.size()])
	var main := OS.get_main_thread_id()
	_ok(not tap.threads.is_empty() and not tap.threads.has(main), "no piece ran on this thread (%d pieces)" % tap.threads.size())
	var most := 0
	var at := 0
	var cut_at_handover := false
	for n in tap.sizes:
		most = maxi(most, n)
		at += n
		cut_at_handover = cut_at_handover or at == HANDOVER
	_ok(most <= piece_most, "no piece is longer than %d frames (the longest %d)" % [piece_most, most])
	_ok(cut_at_handover, "a piece ends at the handover")
	_ok(s._fx_live_name == "Voice 2" and tap.echo_wet > 0.8, "the second voice's room is dialed in (echo %.2f)" % tap.echo_wet)
	# one chain over the same audio, cut at the same frames, each voice's room dialed at its own
	var ref := VoiceFX.new()
	ref.pad_seed = 7
	ref.setup(RATE)
	var want := PackedVector2Array()
	at = 0
	for n in tap.sizes:
		if at == 0:
			Delivery.apply_fx(ref, _ed._cast.cfg_of(Manuscript.NARRATOR))
		elif at == int(tap.sizes[0]):
			Delivery.apply_fx(ref, turned)
		if at == HANDOVER:
			Delivery.apply_fx(ref, _ed._cast.cfg_of("Voice 2"))
		want.append_array(ref.process_stereo(dry.slice(at, at + n)))
		at += n
	_ok(tap.made.size() == dry.size() and tap.made == want, "what the pieces made is what one chain makes of it, in order")

	# the control: the same chain run from here is seen here
	var here := Tap.new()
	here.setup(RATE)
	here.process_stereo(dry.slice(0, piece_most))
	_ok(here.threads.has(main), "control: a piece put through the chain from this thread is seen on it")

	# Stop with a piece on the worker
	_open(dry, tap)
	s.tick(0.016)
	_ok(not s._fx_task.is_empty(), "a piece is on the worker again")
	s._reset_playback()
	_ok(s._fx_task.is_empty() and tap.inside == 0, "Stop leaves no worker in the chain")
	_ok(s._wet.is_empty() and s._through == 0 and s._pending.is_empty() and s._dial.is_empty(), "...and nothing of the reading behind")


func _check_a_take_lands_on_a_worker() -> void:
	print("")
	print("a_take_lands_on_a_worker")
	var dir := ProjectSettings.globalize_path(SCRATCH)
	DirAccess.make_dir_recursive_absolute(dir)
	var said := _voice().slice(0, RATE)
	var frames := PackedVector2Array()
	frames.resize(said.size())
	for i in said.size():
		frames[i] = Vector2(said[i], said[i])
	var wav := Splice.write_wav(SCRATCH + "/take.wav", frames, 1, RATE)
	_ok(FileAccess.file_exists(wav), "a take's file to land")
	var cache_was := TakeCache.root
	TakeCache.root = SCRATCH + "/cache"
	var s := _ed._stream
	_ed._text.text = "The machines are running."
	s.plan(_ed._text.text)
	_ok(s.chunks.size() == 1, "one sentence planned (%d)" % s.chunks.size())
	var lead := s._pending.size()
	_ed._sr = RATE
	s._land(wav, 0, [], [], "stream-chain-check", {"sample_rate": RATE, "wav": wav})
	_ok(s._landing.size() == 1 and s._ready_takes.is_empty() and s._pending.size() == lead, "asked to land, nothing is decoded in the call")
	var waited := 0
	while not s._landing.is_empty() and waited < 3000:
		await get_tree().process_frame
		s.tick(0.016)
		waited += 1
	_ok(s._landing.is_empty() and s._join.chunk_at.has(0), "landed, it is joined to the reading")
	var decoded := Splice.read_wav(wav)
	var at := int(s._join.chunk_at.get(0, 0))
	_ok(decoded.size() == said.size() and s._pending.size() >= at + decoded.size() and s._pending.slice(at, at + decoded.size()) == decoded,
		"...and the queue holds the file's samples (%d)" % decoded.size())
	_ok(not TakeCache.find("stream-chain-check").is_empty(), "...kept under its key by the worker")
	TakeCache.root = cache_was
	s._reset_playback()
	for f in DirAccess.get_files_at(dir.path_join("cache")):
		DirAccess.remove_absolute(dir.path_join("cache").path_join(f))
	DirAccess.remove_absolute(dir.path_join("cache"))
	DirAccess.remove_absolute(dir.path_join("take.wav"))
	DirAccess.remove_absolute(dir)


## A script of [param n] sentences, each its own.
func _script(n: int) -> String:
	var out := PackedStringArray()
	for i in n:
		out.append("The machine at desk %d is running, and nobody at it minds." % (i + 1))
	return " ".join(out)


func _check_a_long_plan_is_a_workers() -> void:
	print("")
	print("a_long_plan_is_a_workers")
	var cache_was := TakeCache.root
	TakeCache.root = SCRATCH + "/none"
	_host = Host.new()
	_ed._host = _host
	_ed._cast._names = PackedStringArray([Manuscript.NARRATOR])
	var first := ReadingPanel.SLOT_DEFAULTS.duplicate(true)
	first["voice"] = "kokoro"
	_ed._cast._slots = [first]
	_ed._cast._stash = {}
	_ed._cast._order = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast.slot = 0
	_ed._cast.fill_voices([{"id": "kokoro", "name": "kokoro", "backend": "kokoro", "speakers": 3, "installed": true}])
	_ed._cast._apply_slot(0)
	var walk := Fixed.new()
	_ed.walk = walk
	var s := _ed._stream
	s._reset_playback()

	# the control first: a short script is planned where Play is pressed
	walk.words = _script(3)
	_ok(walk.words.length() < ReadingPanel.PLAN_AWAY, "a short script (%d characters)" % walk.words.length())
	s.play()
	_ok(not s.planning() and s.chunks.size() == 3 and _host.asked.size() == ReadingStream.LOOKAHEAD,
		"control: a short script is planned in the call, and the host asked (%d chunks, %d asked)" % [s.chunks.size(), _host.asked.size()])
	s.stop()

	# a long one
	walk.words = _script(60)
	_host.asked.clear()
	_ok(walk.words.length() >= ReadingPanel.PLAN_AWAY, "a long script (%d characters)" % walk.words.length())
	s.play()
	_ok(s.planning() and s.chunks.is_empty() and _host.asked.is_empty() and not _ed._plan_task.is_empty(),
		"Play plans nothing in the call and asks the host for nothing: a worker has the plan")
	var of: Array = _ed._plan_asked(walk.words)
	_ok(_ed._plan_for != of, "...and no plan of these words is kept yet")
	var task := int(_ed._plan_task["task"])
	s.play()
	_ok(s.planning() and int(_ed._plan_task["task"]) == task and s.chunks.is_empty(), "Play again changes nothing")
	var frames := 0
	while s.planning() and frames < 3000:
		await get_tree().process_frame
		_ed._plan_landed()
		frames += 1
	_ok(not s.planning() and s.chunks.size() == 60 and s.has_reading(), "the plan lands and Play carries on (%d chunks)" % s.chunks.size())
	_ok(_host.asked.size() == ReadingStream.LOOKAHEAD, "...asking the host for the window's first sentences (%d)" % _host.asked.size())
	var here: Dictionary = ReadingPlan.make(of[0], of[1], of[2])
	_ok(_ed._plan_for == of and _ed._plan_kept["chunks"] == here["chunks"] and _ed._plan_kept["fade"] == here["fade"],
		"the worker's plan is the one made here")

	# kept: a seek plans nothing
	var kept: Dictionary = _ed._plan_kept
	s.speak_from(20)
	_ok(is_same(_ed._plan_kept, kept), "a seek plans nothing: the plan kept is the same one")
	_ok(s.chunks.size() == 60 and is_same((s.chunks[20] as Dictionary)["words"], ((kept["chunks"] as Array)[20] as Dictionary)["words"]),
		"...and the reading's words are the kept plan's own")
	var mine: Array = _ed._build_chunks(walk.words)
	(mine[20] as Dictionary)["near"] = {"c": 9.0}
	_ok(not is_same(mine[20], s.chunks[20]) and (s.chunks[20] as Dictionary).get("near", {}) != {"c": 9.0}
		and not ((kept["chunks"] as Array)[20] as Dictionary).has("near"),
		"each asker's chunks are its own: a mark written on one is on no other")
	_ed._build_chunks(walk.words + " One more thing is said.")
	_ok(not is_same(_ed._plan_kept, kept) and (_ed._plan_kept["chunks"] as Array).size() == 61, "control: other words are planned anew")
	s.stop()

	# Stop while the plan is made
	walk.words = _script(70)
	_host.asked.clear()
	s.play()
	_ok(s.planning(), "another long script is being planned")
	s.stop()
	_ok(not s.planning(), "Stop ends the wait")
	frames = 0
	while not _ed._plan_task.is_empty() and frames < 3000:
		await get_tree().process_frame
		_ed._plan_landed()
		frames += 1
	_ok(_ed._plan_task.is_empty() and s.chunks.is_empty() and _host.asked.is_empty() and not s.has_reading(),
		"...the plan lands and nothing plays")
	_ok(_ed._plan_for == _ed._plan_asked(walk.words), "...and is kept for the next Play")

	# a seek after the words were written on: a worker plans them, the reading on the stream left as it is meanwhile
	s.play()
	_ok(not s.planning() and s.chunks.size() == 70, "control: the kept plan is taken where Play is pressed (%d chunks)" % s.chunks.size())
	walk.words = _script(71)
	_host.asked.clear()
	var on_stream: Array = s.chunks
	s.speak_from(30)
	_ok(s.planning() and is_same(s.chunks, on_stream) and _host.asked.is_empty() and not _ed._plan_task.is_empty(),
		"a seek after the words changed plans nothing in the call: the reading stays as it is, a worker has the plan")
	_ok(is_equal_approx(s.position(), s._bar_t[30]), "...the bar waiting on the sentence sought")
	frames = 0
	while s.planning() and frames < 3000:
		await get_tree().process_frame
		_ed._plan_landed()
		frames += 1
	_ok(not s.planning() and s.chunks.size() == 71 and s._start_chunk == 30 and s._next_to_request == 30 + ReadingStream.LOOKAHEAD
			and _host.asked.size() == ReadingStream.LOOKAHEAD,
		"the plan lands and the reading starts at the sentence sought (%d chunks, from %d, %d asked)" % [s.chunks.size(), s._start_chunk, _host.asked.size()])
	s.stop()
	TakeCache.root = cache_was

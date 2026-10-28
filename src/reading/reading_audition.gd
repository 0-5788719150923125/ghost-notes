extends RefCounted
class_name ReadingAudition

## ReadingAudition - one voice heard on its own (the Voice card's Test): a fixed passage read in the
## voice on the selected tab - its tone, pace, pauses, delivery and room - and played straight out:
## no stage, no subtitles, no Director. In a script with seven speakers the last one first speaks
## forty minutes in, so tuning that voice by reading the whole script is not a loop anyone can
## iterate in.
##
## STREAMED, like a reading: every sentence is requested at once (the host answers them in order),
## each is joined onto the stream the moment it and everything before it has arrived, and playback
## starts with the first sentence. The first cut waited for the whole passage and was reported as
## "a solid 15 seconds of silence" - longer than a chapter takes to start. So a Stop cancels what
## is still asked ([method stop]).
##
## A PART OF ITS PANEL (next/structure.md, step 19): its state is its own, and it asks the
## [ReadingPanel] it was made by for the host, a voice's settings and the request for a chunk. The
## sentences are joined by a [ReadingJoin], as a reading's and an export's are, so a voice is
## auditioned with the seams, the rests and the moves nearer it reads with.

## The words every voice is auditioned with. The SAME passage for every speaker, so two
## voices are compared on identical material; chosen to exercise what a chapter will ask of
## them - a long sentence with commas, a colon, a semicolon, a question, an exclamation, a
## number, a list, a dash, lines of dialogue in quotes and a short sentence landing after a long
## one. It OPENS on a short sentence on purpose: the first sound waits for the first sentence to
## be made. About a minute long (2026-10-25, the user: "make the test audio a bit longer. There's
## no reason for it to be so short" - it had been twenty-five seconds).
const PASSAGE := """The rain had not stopped. Since morning it had kept on, and the lamps along the river were already lit by four o'clock. I counted them from the window: twelve on this side, eleven on the other, one of them out.

"Are you coming, or not?" she asked from the doorway. I told her I would be a minute. It was closer to twenty.

Some evenings are like that. You mean to leave, and the room keeps you, and by the time you notice it is dark. Still, I went. I am glad I did!

The street was empty but for a man and his dog, and the dog was plainly in charge. They crossed at the bakery, where the windows had fogged over and someone had written a name in the steam - not mine, though for a moment I hoped it was.

"You took your time," she said when I arrived. I said that time had taken me; she did not find this as clever as I did. We ordered two coffees, a slice of lemon cake and, after a long look at the menu, a second slice. By nine the rain had eased to a hush, and we walked home the long way."""
## THE ROOM RUNS ON A WORKER. VoiceFX is GDScript DSP at about 15 microseconds a sample -
## measured, a third of the main thread for every second of audio, and 0.36 s in ONE frame
## when a sentence was processed whole: the reported "the entire UI keeps freezing, then
## releasing". So the dry audio goes through the chain on a worker, half a second at a time
## and ONE piece at a time (the chain is stateful, so pieces must run in order), and the main
## thread only moves finished samples into the ring. A dial moved mid-test reaches the next
## piece - the settings are taken when a piece starts, never changed under a running one.
const FX_PIECE := 0.5

## The panel this is a part of: the host, the voices' settings and the requests are its.
var panel: ReadingPanel
## The voice being auditioned, by name - fixed when Test was pressed.
var voice := ""
## The passage's chunks, a sentence each ([method ReadingPlan.cut]).
var chunks: Array = []

var _player: AudioStreamPlayer
var _sr := 22050
var _req := {}                 # host request id -> chunk index
var _parts := {}               # chunk index -> {wav, spans}, as they arrive
var _tasks := {}               # chunk index -> {box, task}: decoding on a worker
var _next := 0                 # the next sentence to join onto the stream
var _join: ReadingJoin = null  # the dry take: seams, rests, where the reader moves
var _dry := PackedFloat32Array()   # joined audio waiting for the room (see _pump_fx)
var _dry_at := 0               # the frame _dry[0] is
var _fx: VoiceFX = null
var _fx_task := {}             # the one piece going through the room right now: {box, task}
var _hold := PackedVector2Array()   # wet frames not yet pushed
var _read := 0                 # cursor into _hold: what has been pushed
var _pushed := 0
var _cap := 0                  # the generator's ring, measured empty


func _init(owner: ReadingPanel) -> void:
	panel = owner


## Read [param passage] in the voice named [param name]: every sentence asked of the host at once.
func start(passage: String, name: String) -> void:
	stop()
	voice = name
	chunks = ReadingPlan.cut(passage, 0)["chunks"]
	ReadingPlan.place(chunks, passage)
	for c in chunks:
		(c as Dictionary)["speaker"] = name
	panel._plan_near(chunks, 0, name)
	_sr = panel._sr
	_join = ReadingJoin.new(_sr)
	_next = 0
	_dry_at = 0
	_fx = null
	var s := panel._cast.cfg_of(name)
	for i in chunks.size():
		var id := panel._host.request("", panel._cast.voice_id_of(s), ReadingPanel.TAKE_DIR + "/test_%d.wav" % i,
			panel._request_args(s, chunks[i]), null)
		_req[id] = i


## Whether an audition is being made or heard.
func busy() -> bool:
	return not _req.is_empty() or (_player != null and _player.playing)


## Whether the host's reply [param id] is one of this audition's.
func owns(id: int) -> bool:
	return _req.has(id)


## Stop: the sentences not yet made are CANCELLED on the host ([method VoiceHost.cancel]) and the one
## being made is dropped on arrival; a worker still decoding is waited for rather than abandoned - it
## is a fraction of a second. Only forgotten, every sentence was still made, and each Test after a
## Stop waited for the whole passage before it (2026-10-27: pressed a few times, "it will not work
## again until we restart the app").
func stop() -> void:
	if not _req.is_empty() and panel._host != null:
		panel._host.cancel(_req.keys())
	for k in _tasks:
		WorkerThreadPool.wait_for_task_completion(int((_tasks[k] as Dictionary)["task"]))
	_tasks = {}
	if not _fx_task.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_fx_task["task"]))
	_fx_task = {}
	_dry = PackedFloat32Array()
	_req = {}
	for k in _parts:
		_forget(String((_parts[k] as Dictionary)["wav"]))
	_parts = {}
	_hold = PackedVector2Array()
	_read = 0
	_pushed = 0
	if _player != null:
		_player.stop()


## One sentence of the audition arrived. Join everything that is now contiguous from the front -
## the seam, the voice's room, through ONE effects chain so the room carries across the joins -
## and hand it to the stream.
func take(id: int, result: Dictionary) -> void:
	var i := int(_req[id])
	_req.erase(id)
	var wav := String(result.get("wav", ""))
	_parts[i] = {"wav": wav, "spans": result.get("tokens", [])}
	# the host's rate is the panel's to know: every take after this one is at it
	_sr = int(result.get("sample_rate", _sr))
	panel._sr = _sr
	_join.sr = _sr
	if _fx == null:
		_fx = VoiceFX.new()
		_fx.pad_seed = hash(panel._test_passage())
		_fx.setup(_sr)
		Delivery.apply_fx(_fx, panel._cast.cfg_of(voice))
	# DECODE OFF THE MAIN THREAD. It is a per-sample GDScript loop, and a long sentence is
	# several hundred thousand samples - measured at a 0.3 s frame on arrival. A pure function
	# of the file, so a worker can do it; the join below waits for it.
	var box := [PackedFloat32Array()]
	_tasks[i] = {"box": box, "task": WorkerThreadPool.add_task(func() -> void:
		box[0] = Splice.decode_wav(wav))}
	_join_parts()


## Every frame: join what the workers finished, keep the room going, feed the ring a frame's worth
## of finished (wet) samples - and end the audition once everything has been pushed and has played
## out (a generator never finishes by itself).
func tick() -> void:
	if not _tasks.is_empty():
		_join_parts()
	if not _fx_task.is_empty() or not _dry.is_empty():
		_pump_fx()
	if _player == null or not _player.playing:
		return
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := mini(_hold.size() - _read, pb.get_frames_available())
	if n > 0:
		pb.push_buffer(_hold.slice(_read, _read + n))
		_pushed += n
		_read += n
		# reclaim the consumed head only when it is worth it, not every frame
		if _read > 4 * _sr:
			_hold = _hold.slice(_read)
			_read = 0
		return
	if _req.is_empty() and _next >= chunks.size() and _dry.is_empty() and _fx_task.is_empty() \
			and pb.get_frames_available() >= _cap - 64:
		_player.stop()
		panel._show_testing(false)
		panel._set_status("Tested %s - %.1fs." % [voice, float(_pushed) / float(_sr)])


## Join every decoded sentence that is now contiguous from the front onto the audition - the seams,
## the rests and the moves nearer by the same join a reading takes - and a second of silence after
## the last, so the room rings out rather than being cut.
func _join_parts() -> void:
	var s := panel._cast.cfg_of(voice)
	while _tasks.has(_next):
		var t: Dictionary = _tasks[_next]
		if not WorkerThreadPool.is_task_completed(int(t["task"])):
			return
		WorkerThreadPool.wait_for_task_completion(int(t["task"]))
		_tasks.erase(_next)
		var part: PackedFloat32Array = (t["box"] as Array)[0]
		var got: Dictionary = _parts.get(_next, {})
		_parts.erase(_next)
		_forget(String(got.get("wav", "")))
		if not part.is_empty():
			_dry.append_array(_join.add(chunks, _next, part, got.get("spans", []), s, panel._cast.turn_scale()))
		_next += 1
		if _next >= chunks.size():
			_dry.append_array(_join.pad(_sr))
	_pump_fx()


## The next half second of dry audio through the room, on a worker, one piece at a time.
func _pump_fx() -> void:
	if not _fx_task.is_empty():
		if not WorkerThreadPool.is_task_completed(int(_fx_task["task"])):
			return
		WorkerThreadPool.wait_for_task_completion(int(_fx_task["task"]))
		_hold.append_array((_fx_task["box"] as Array)[0])
		_fx_task = {}
	if _dry.is_empty() or _fx == null:
		_start_playback()
		return
	var n := mini(_dry.size(), int(FX_PIECE * float(_sr)))
	# a distance the piece has reached goes in before it; a piece stops at the next one (the voice
	# never changes - its own room is dialed onto every piece)
	var near := {}
	var marks := _join.marks
	while not marks.is_empty() and int((marks[0] as Dictionary)["at"]) <= _dry_at:
		var m: Dictionary = marks.pop_front()
		if m.has("near"):
			near = m["near"]
	if not marks.is_empty():
		n = mini(n, int((marks[0] as Dictionary)["at"]) - _dry_at)
	var piece := _dry.slice(0, n)
	_dry = _dry.slice(n)
	_dry_at += n
	var fx := _fx
	var cfg := panel._cast.cfg_of(voice)
	var box := [PackedVector2Array()]
	_fx_task = {"box": box, "task": WorkerThreadPool.add_task(func() -> void:
		Delivery.apply_fx(fx, cfg)
		if not near.is_empty():
			Delivery.near_to(fx, near)
		box[0] = fx.process_stereo(piece))}
	_start_playback()


func _start_playback() -> void:
	var done := _next >= chunks.size() and _dry.is_empty() and _fx_task.is_empty()
	panel._set_status("Testing %s… %d of %d" % [voice, _next, chunks.size()])
	# Unlike a reading, the audition starts on its FIRST sentence (a short one, see PASSAGE): a
	# test is pressed to hear a voice now, and a brief gap at one seam costs less here than
	# seconds of silence up front.
	var playing := _player != null and _player.playing
	if playing or (_hold.size() - _read <= 0 and not done):
		return
	if _player == null:
		_player = AudioStreamPlayer.new()
		panel.add_child(_player)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sr
	# A short ring: the room is already applied (on a worker), so a frame only copies samples.
	gen.buffer_length = 1.0
	_player.stream = gen
	_player.play()
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	# MEASURED, not computed: Godot rounds a generator's ring to a power of two, so "empty"
	# is whatever it reports before the first push (see ReadingStream._drain_ready).
	_cap = pb.get_frames_available() if pb != null else 0


## A take this audition is done with, off the disk.
func _forget(wav: String) -> void:
	if not wav.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(wav))

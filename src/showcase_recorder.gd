extends Node
class_name ShowcaseRecorder

## ShowcaseRecorder - the README's recording, inside the second ghost that [Showcase] starts under
## Movie Maker with `--showcase <work>`. It makes what a person would - a Manual note with a song,
## on the showcase storyboard - opens it the way the notes list does, presses Play, and quits once
## [method Showcase.frames] frames have been drawn since. Movie Maker has been writing every frame
## from the first; [Showcase] keeps the last of them, so the boot and the note opening never show.
##
## Everything it writes is under the work folder: the song, the note (`NoteStore.root`) and, from
## its process environment, user:// itself. As it plays it collects the files the show has loaded
## ([method Showcase.loaded_files]) - more than once, because a resource freed before the end is
## gone from the cache - and leaves them in `capture.json` for the stamp.

## The song: 120 bpm, so the prisms have a beat to move on.
const BPM := 120.0
const RATE := 22050

var main: Node
var work := ""
var _left := -1
var _files := {}


func _ready() -> void:
	set_process(false)
	_run.call_deferred()


func _run() -> void:
	var notes := work.path_join("notes")
	DirAccess.make_dir_recursive_absolute(notes)
	for f in DirAccess.get_files_at(notes):
		DirAccess.remove_absolute(notes.path_join(f))
	NoteStore.root = notes
	var song := work.path_join("showcase.wav")
	if not write_song(song):
		_fail("could not write the song (%s)" % song)
		return
	var note := NoteStore.create("manual", Showcase.TITLE, Showcase.BODY, {
		"song": {"path": song},
		"scenes": {"storyboard": Showcase.STORYBOARD},
		"bookends": {"intro": Showcase.INTRO, "outro": Showcase.OUTRO}})
	if note.is_empty():
		_fail("could not make the note")
		return
	main.open_note(note)
	# A FIRST RUN OPENS THE ENVIRONMENT PANEL (`[deps] open` defaults to true, and this user:// is
	# new), and so does any problem its probe finds later: closed now, and after each, so the
	# picture is the note and its show
	var ch: Chrome = main._chrome
	ch.set_environment_open(false, false)
	ch.environment.problem_found.connect(func() -> void: ch.set_environment_open(false, false))
	# the panel loads the song once its cards have applied the note's blocks
	for i in 120:
		if Spectrum.has_audio() and Director.is_attached():
			break
		await get_tree().process_frame
	if not Spectrum.has_audio() or not Director.is_attached():
		_fail("the note's song or picture did not come up")
		return
	# the first frames of a show build its scene: settled, then played
	for i in 10:
		await get_tree().process_frame
	Spectrum.transport_play()
	_left = Showcase.frames()
	set_process(true)


func _process(_dt: float) -> void:
	_left -= 1
	if _left % Showcase.FPS == 0:
		_collect()
	if _left > 0:
		return
	set_process(false)
	_collect()
	var f := FileAccess.open(work.path_join("capture.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": Showcase.frames(), "files": _files.keys()}, "\t"))
	f.close()
	print("ghost showcase: recorded %d frames, %d files loaded" % [Showcase.frames(), _files.size()])
	get_tree().quit(0)


func _collect() -> void:
	for p in Showcase.loaded_files():
		_files[p] = true


func _fail(why: String) -> void:
	printerr("ghost showcase: " + why)
	get_tree().quit(1)


## A small song to [param path], [constant Showcase.SONG] seconds: a soft kick on every beat, a
## tick between, and a low chord that swells and falls back each bar - made, not found, and the
## same every time. False when it could not be written.
static func write_song(path: String) -> bool:
	var n := int(Showcase.SONG * RATE)
	var beat := 60.0 / BPM
	var chord := [110.0, 130.81, 164.81, 220.0]          # A minor, low
	var noise := RandomNumberGenerator.new()
	noise.seed = 5
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var tb := fmod(t, beat)
		# the kick: a sine falling from 150 to 50 Hz, gone in a quarter of a beat
		var kick := sin(TAU * (50.0 * tb + 100.0 * (1.0 - exp(-tb * 30.0)) / 30.0)) * exp(-tb * 9.0)
		# the tick on the off-beat
		var to := fmod(t + beat * 0.5, beat)
		var tick := (noise.randf() * 2.0 - 1.0) * exp(-to * 60.0) * 0.18
		# the chord swells over each bar
		var bar := fmod(t, beat * 4.0) / (beat * 4.0)
		var pad := 0.0
		for hz in chord:
			pad += sin(TAU * float(hz) * t)
		pad *= 0.05 * sin(PI * bar)
		# the song fades in and out over a quarter second, so its loop has no click
		var edge := clampf(minf(t, Showcase.SONG - t) / 0.25, 0.0, 1.0)
		var v := clampf((kick * 0.7 + tick + pad) * edge, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	# save_to_wav appends ".wav" to a name without it, so the part name keeps the extension
	var part := path.get_basename() + ".part.wav"
	return wav.save_to_wav(part) == OK and DirAccess.rename_absolute(part, path) == OK

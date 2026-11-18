extends Node
class_name SoundTest

## SoundTest - a sound heard alone while a person tunes it, as a voice's Test is: a card hands it what it plays (a key and a maker,
## [method play]), and it plays that [SoundBed] at the level it is heard at under the voice until stopped, made again from where it
## is whenever the key changes - so a property changed is heard at once. Rendered ahead on the bed's own worker ([method
## SoundBed.prefetch]); one sound at a time per test.

## Its sample rate, and how much is queued ahead (s).
const RATE := 22050
const BUFFER := 0.4

var _player: AudioStreamPlayer = null
var _pb: AudioStreamGeneratorPlayback = null
var _bed: SoundBed = null
var _key := ""
var _t := 0.0                    # how long it has played: where a remade sound picks up


## Whether it is playing.
func playing() -> bool:
	return _bed != null


## What it plays ("" nothing).
func key() -> String:
	return _key if _bed != null else ""


## Play the sound [param make] makes (`(rate, t0) -> SoundBed`), kept as [param key], at [param level]: begun where the last left off
## when the key is another, left as it is when it is the same.
func play(key: String, make: Callable, level: float) -> void:
	if _bed != null and key == _key:
		return
	if _bed != null:
		_bed.finish()
	_bed = make.call(RATE, _t) as SoundBed
	_key = key
	if _bed == null:
		return
	_bed.set_level(level)
	if _player == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = BUFFER
		_player = AudioStreamPlayer.new()
		_player.stream = gen
		add_child(_player)
	# (heard once it is in the tree: a card built out of it plays when it is put in)
	if not _player.playing and _player.is_inside_tree():
		_player.play()
		_pb = _player.get_stream_playback()


## Stop: nothing heard, the next play from its start.
func stop() -> void:
	if _bed != null:
		_bed.finish()
	_bed = null
	_key = ""
	_t = 0.0
	_pb = null
	if _player != null and _player.is_inside_tree():
		_player.stop()


func _process(_delta: float) -> void:
	if _bed != null and _pb == null and _player != null and _player.is_inside_tree():
		_player.play()
		_pb = _player.get_stream_playback()
	if _bed == null or _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	_bed.prefetch(BUFFER * 2.0)
	var quiet := PackedVector2Array()
	quiet.resize(n)
	_pb.push_buffer(_bed.mix(quiet))
	_t += float(n) / float(RATE)


func _exit_tree() -> void:
	stop()

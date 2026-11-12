extends Node

## take_play_check - the kept take plays as the session's audio ([method ReadingStream.play],
## [method ReadingPanel.kept_take]; next/editing.md step 3), so a seek is a seek inside one file.
##
##   tests/run_boot_probe.sh tests/reading/take_play_check.gd 90
##
## On a take of its own under user:// (never the author's), a panel built by hand, its episode keeping that take:
##   - what a take is said from ([method ReadingPanel.take_sig]) is the same for the same words and voices; controls: another
##     word and another pace each another;
##   - the take is the reading's only where it was said from these words in these voices; controls: other words, a voice
##     changed, an episode with no take;
##   - Play plays it as a file with no voice host at all: the transport's length is the file's and all of it is ready, a seek
##     while paused lands inside the file and stays paused, its end is the reading's end and Play plays it again, Stop ends it;
##     control: a voice changed, Play plays no take;
##   - an export is handed a copy of it, nothing said again, the copy's book written as it stands.

const ROOT := "user://take_play_check"
const BODY := "One two three. Four five six."
const SR := 22050
const SECONDS := 3.0

var _fails := 0
var _ed: ReadingPanel
var _begun := 0
var _ended := 0


class KeptFeed extends EpisodeFeed:
	var path := ""

	func take() -> String:
		return path


class KeptPublish extends ReadingPublish:
	var kept: KeptFeed

	func feed() -> EpisodeFeed:
		return kept


class FixedWalk extends TextWalk:
	var text := ""

	func body(_pulled: String) -> String:
		return text


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_rmrf(root)
	DirAccess.make_dir_recursive_absolute(root)
	# built by hand, out of the tree: its _ready would start the voice host, and nothing here may need one
	_ed = ReadingPanel.new()
	_ed._build_panel()
	if _ed._doc != null:
		_ed._doc._sync = false
	_ed.take_dir = ROOT
	var walk := FixedWalk.new()
	walk.text = BODY
	_ed.walk = walk
	var feed := KeptFeed.new()
	var pub := KeptPublish.new()
	pub.kept = feed
	_ed.publish = pub
	_ed._cast._names = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast._slots = [ReadingPanel.SLOT_DEFAULTS.duplicate()]
	_ed._cast._stash = {}
	_ed._cast._order = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast.slot = 0
	# what main does ([method main._begin_generative_take]), but the show: the file opened as a render opens it
	_ed.begin_take = func(p: String) -> bool:
		_begun += 1
		Spectrum.stop()
		Spectrum.lead_in = 0.0
		Spectrum.tail = 0.0
		Spectrum.begin(p)
		return Spectrum.has_audio() and Spectrum.audio_path() == p
	_ed.end_stream = func() -> void:
		_ended += 1
		Spectrum.stop()
	Spectrum.conduct(_ed, _ed.transport_hooks())

	# what a take is said from
	var sig := _ed.take_sig(BODY)
	_ok(sig.length() == 64 and sig == _ed.take_sig(BODY), "the same words in the same voices: the same take")
	var pace := _ed._cast._rate.value
	_ed._cast._rate.value = pace + 0.2
	var paced := _ed.take_sig(BODY)
	_ed._cast._rate.value = pace
	_ok(_ed.take_sig(BODY + " Seven.") != sig and paced != sig and _ed.take_sig(BODY) == sig,
		"the controls: another word, another pace - each another take")

	# the take kept
	var wav := root.path_join("take.wav")
	var frames := PackedVector2Array()
	frames.resize(int(SECONDS * SR))
	for i in frames.size():
		var v := 0.3 * sin(TAU * 220.0 * float(i) / SR)
		frames[i] = Vector2(v, v)
	_ok(not Splice.write_wav(wav, frames, 1, SR).is_empty(), "a take of %.0f s is written" % SECONDS)
	var words := [{"text": "One", "t0": 0.2, "t1": 0.5}, {"text": "two", "t0": 0.6, "t1": 0.9}]
	var side := FileAccess.open(wav.get_basename() + ".json", FileAccess.WRITE)
	side.store_string(JSON.stringify({"words": words, "phones": [], "bookend": {"in": 0.0, "out": 0.0}, "sig": sig}))
	side.close()
	feed.path = wav
	_ok(_ed.kept_take(BODY) == wav, "said from these words in these voices, the episode's take is the reading's")
	_ed._cast._rate.value = pace + 0.2
	var changed := _ed.kept_take(BODY)
	_ed._cast._rate.value = pace
	feed.path = ""
	var none := _ed.kept_take(BODY)
	feed.path = wav
	_ok(_ed.kept_take(BODY + " Seven.").is_empty() and changed.is_empty() and none.is_empty(),
		"the controls: other words, a voice changed, an episode with no take - no take")

	# play: the file, no host
	_ed._stream.play()
	_ok(_begun == 1 and _ed.take_playing() and _ed._stream.live() and Spectrum.audio_path() == wav,
		"Play plays the take as a file, with no voice host at all (begun %d)" % _begun)
	_ok(Spectrum.seekable() and absf(Spectrum.scrub_length() - SECONDS) < 0.05,
		"the transport can seek it, and its length is the file's (%.2f s)" % Spectrum.scrub_length())
	_ok(is_inf(float((_ed.transport_hooks()["ahead"] as Callable).call())), "all of it is ready ahead of the playhead")
	Spectrum.transport_pause()
	var held := Spectrum.paused and Spectrum._player.stream_paused
	Spectrum.seek(1.5)
	_ok(held and Spectrum.paused and Spectrum._player.stream_paused, "a seek while paused stays paused (paused %s, held %s)"
		% [Spectrum.paused, Spectrum._player.stream_paused])
	_ok(absf(Spectrum._player.get_playback_position() - 1.5) < 0.1,
		"...and lands inside the file where it was asked (%.2f s)" % Spectrum._player.get_playback_position())
	_ed.take_ended()
	_ok(not _ed._stream.live(), "played to its end, the reading is over")
	Spectrum.set_paused(false)
	_ed._stream.play()
	_ok(_begun == 2 and _ed._stream.live(), "and Play plays it again from the top")
	_ed._stream.stop()
	_ok(_ended == 1 and not _ed.take_playing() and not _ed._stream.has_reading(), "Stop ends it")
	_ed._cast._rate.value = pace + 0.2
	_ed._stream.play()
	_ok(_begun == 2 and not _ed.take_playing(), "the control: a voice changed, Play plays no take")
	_ed._cast._rate.value = pace

	# an export: a copy, nothing said again
	var out: String = await _ed.export_take()
	var copied: Variant = JSON.parse_string(FileAccess.get_file_as_string(out.get_basename() + ".json")) if not out.is_empty() else null
	_ok(not out.is_empty() and out != wav and out.begins_with(root) and FileAccess.get_file_as_bytes(out) == FileAccess.get_file_as_bytes(wav)
		and copied is Dictionary and ((copied as Dictionary).get("words", []) as Array).size() == words.size()
		and (copied as Dictionary).get("book") is Dictionary, "an export is handed a copy of the take, its book written as it stands (%s)" % out)

	Spectrum.stop()
	Spectrum.release_conductor(_ed)
	_ed.free()
	_rmrf(root)
	if _fails == 0:
		print("take_play_check: ALL OK")
		get_tree().quit(0)
		return
	print("take_play_check: %d FAILED" % _fails)
	get_tree().quit(1)


func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1

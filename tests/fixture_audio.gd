extends RefCounted

## Audio a gate can count on, made on demand - never a file someone has to have lying around.
##
## [method silence] is exactly that many seconds of digital silence (16-bit mono, 22050 Hz),
## written once under user://fixtures/ and reused. It replaced `res://01_silence.wav`, which two
## gates (bookend_check, seek_check) required at the project root, which was gitignored with the
## voice listening probes, and which nothing made - so both failed on every machine without it.
##
##   const FixtureAudio := preload("res://tests/fixture_audio.gd")
##   var wav: String = FixtureAudio.silence(10.0)    # an absolute path

const DIR := "user://fixtures"
const RATE := 22050


## The absolute path of a [param seconds]-long silent WAV, written if it is not there yet. ""
## if it could not be written.
static func silence(seconds: float) -> String:
	var dir := ProjectSettings.globalize_path(DIR)
	var out := dir.path_join("silence_%dms.wav" % int(round(seconds * 1000.0)))
	if FileAccess.file_exists(out):
		return out
	DirAccess.make_dir_recursive_absolute(dir)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(int(round(seconds * RATE)) * 2)
	data.fill(0)
	wav.data = data
	# Written beside its final name and renamed into place, so a run killed mid-write leaves
	# nothing a later run would take for a whole fixture. The temporary name ends in .wav too:
	# save_to_wav APPENDS ".wav" to a path that does not, and the rename then finds nothing.
	var part := out.get_basename() + ".part.wav"
	if wav.save_to_wav(part) != OK or DirAccess.rename_absolute(part, out) != OK:
		return ""
	return out

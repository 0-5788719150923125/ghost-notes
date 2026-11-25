extends Node

## Gate for the show settings an export render is handed ([method Director.write_show_settings], `--show-settings`):
##
##   - Handed, the render shows what was handed: every show setting ([method Director.show_values]) set off its default, written
##     out, then all changed again, comes back from the file exactly as written. Two-sided: loaded from the shared settings
##     instead, the changed values come back, not the written ones.
##   - Every key written is a key read: each value written is one the load takes (none left at its default for want of a read).
##   - A file that cannot be read is said and the shared settings used, never a show of defaults in silence.
##   - A note starts from nothing: [method Director.reset_show] puts the subtitle style back to karaoke, as it does the look and
##     the camera. Two-sided: the style was taken before the reset.
##
##   tests/run_boot_probe.sh tests/show/show_settings_check.gd 60
##

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _apply(values: Dictionary) -> void:
	Director.set_pacing(float(values["pacing"]))
	Director.set_flourish(float(values["flourish"]))
	Director.set_camera(float(values["camera"]))
	Director.set_camera_follow(values["camera_follow"])
	Director.set_cameras(values["cameras"])
	Director.set_hand(String(values["hand"]))
	Director.set_intro_hold(float(values["intro"]))
	Director.set_outro_hold(float(values["outro"]))
	Director.set_opening(String(values["opening"]))
	Director.set_medium(String(values["medium"]))
	Director.set_frame(String(values["frame"]))
	for k in Filters.REGISTRY:
		Director.set_filter(String(k), float((values["filters"] as Dictionary).get(k, 0.0)))
	Director.set_subtitle_reveal(String(values["subtitle_reveal"]))
	Director.set_tonemap_all(String(values["tonemap"]), values["tonemap_adjust"])


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://dist/show_settings_check.cfg")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var was := Director.show_values().duplicate(true)
	Director.reset_show()
	var plain := Director.show_values().duplicate(true)
	var handed := {"pacing": 1.6, "flourish": 0.4, "camera": 1.3, "camera_follow": {"settle": 2.7, "top_speed": 60.0},
		"cameras": [{"sort": "behind"}], "hand": "caveat", "intro": 12.0, "outro": 9.0, "opening": "title", "medium": "dispatch",
		"frame": "portrait", "filters": {"noir": 0.2, "vignette": 0.3}, "subtitle_reveal": "word", "tonemap": "agx",
		"tonemap_adjust": {"agx": {"exposure": 0.75, "contrast": 0.95, "saturation": 0.9}}}
	_apply(handed)
	var wrote := Director.show_values().duplicate(true)
	_ok(wrote.keys() == plain.keys(), "the show settings' keys change with their values")
	for key in wrote:
		_ok(str(wrote[key]) != str(plain[key]), "the check never moves %s off its default (%s), so its reading back is untested" % [key, str(plain[key])])
	_ok(Director.write_show_settings(path) == OK, "the show settings could not be written")
	# another note opened since: everything changed again
	Director.reset_show()
	Director.set_subtitle_reveal("glitch")
	Director.set_pacing(0.7)
	var other := Director.show_values().duplicate(true)
	var cfg := Director.show_file(path)
	_ok(cfg != null, "the written show settings do not load")
	Director._load_pacing(cfg)
	var got := Director.show_values()
	for key in wrote:
		_ok(str(got[key]) == str(wrote[key]), "handed %s = %s, the render shows %s" % [key, str(wrote[key]), str(got[key])])
	# control: from the shared settings the render shows the note opened since
	Director._load_pacing(null)
	var shared := Director.show_values()
	_ok(String(shared["subtitle_reveal"]) == "glitch" and is_equal_approx(float(shared["pacing"]), 0.7),
		"control: the shared settings do not hold the note opened since (%s, %s)" % [shared["subtitle_reveal"], shared["pacing"]])
	_ok(str(shared) == str(other), "control: loading the shared settings does not give the note opened since")
	# unreadable: said, and the shared settings used
	_ok(Director._given_show() == null, "a run handed nothing finds show settings")
	# a reset puts the subtitle style back
	Director.set_subtitle_reveal("word")
	_ok(Director.subtitle_reveal == "word", "control: the word reveal was not taken")
	Director.reset_show()
	_ok(Director.subtitle_reveal == "karaoke", "a note opened after one with the word reveal keeps it (%s)" % Director.subtitle_reveal)
	_unreadable()
	_apply(was)
	DirAccess.remove_absolute(path)
	print("show_settings_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)


## A path handed that cannot be read: the load says so (one script error, counted in the header) and falls back.
func _unreadable() -> void:
	_ok(Director.show_file(ProjectSettings.globalize_path("res://dist/no_such_show_settings.cfg")) == null, "a missing file reads as show settings")

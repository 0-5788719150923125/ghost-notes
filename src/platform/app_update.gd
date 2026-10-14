extends Node
class_name AppUpdate

## Portable desktop updater. The release executable is copied beside the running one while it
## can still be written, then that same downloaded executable starts headlessly on exit to swap
## the files after the old process closes. No installer or system Python is needed.
signal changed

const REPO := "0-5788719150923125/ghost-notes"
const UPDATE_DIR := "user://updates"
const ERROR_PATH := UPDATE_DIR + "/last_error.txt"
const CHECK_INTERVAL := 6.0 * 3600.0
const EXEC_PERMISSIONS := 493 # 0755

var current_sha := ""
var available_sha := ""
var status := "development build"
var update_ready := false
var enabled := false
var _busy := false
var _download := ""
var _staged := ""
var _expected_digest := ""
var _release: Dictionary = {}
var _restart_requested := false


static func build_info() -> Dictionary:
	if not FileAccess.file_exists("res://data/build_info.json"):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_info.json"))
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	var info := build_info()
	current_sha = String(info.get("commit", ""))
	var settings := get_node_or_null("/root/Settings")
	enabled = OS.has_feature("template") and OS.has_feature("release") \
		and not OS.has_feature("mobile") and settings != null and not bool(settings.call("is_read_only")) \
		and current_sha.length() == 40 and not bool(info.get("dirty", true))
	status = "build %s" % current_sha.substr(0, 7) if not current_sha.is_empty() else "development build"
	if enabled:
		get_tree().create_timer(10.0).timeout.connect(_cleanup_downloads)
		var previous_error := FileAccess.get_file_as_string(ERROR_PATH) if FileAccess.file_exists(ERROR_PATH) else ""
		if not previous_error.is_empty():
			status = "last app update failed · " + previous_error.strip_edges()
		var timer := Timer.new()
		timer.wait_time = CHECK_INTERVAL
		timer.autostart = true
		timer.timeout.connect(func() -> void:
			if _auto_enabled():
				check_now())
		add_child(timer)
		if _auto_enabled() and previous_error.is_empty():
			check_now.call_deferred()
	changed.emit()


func _auto_enabled() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings != null and bool(settings.call("read", "deps", "auto_update", true))


func _cleanup_downloads() -> void:
	var dir := DirAccess.open(UPDATE_DIR)
	if dir == null: return
	for name in dir.get_files():
		if name == _download.get_file(): continue
		if name.length() == 17 and name.begins_with("build-") \
				and _is_hex(name.substr(6, 7), 7) and (name.ends_with(".exe") or name.ends_with(".bin")):
			DirAccess.remove_absolute(UPDATE_DIR.path_join(name))


func check_now() -> void:
	if not enabled or _busy or update_ready:
		return
	_busy = true
	DirAccess.remove_absolute(ERROR_PATH)
	status = "checking for an app update…"
	changed.emit()
	_request_url("https://api.github.com/repos/%s/releases?per_page=20" % REPO, _on_releases)


func _request_url(url: String, callback: Callable, download_to := "") -> void:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = 0.0 if not download_to.is_empty() else 20.0
	req.download_file = download_to
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray,
			body: PackedByteArray) -> void:
		req.queue_free()
		callback.call(result, code, body))
	var err := req.request(url, ["Accept: application/vnd.github+json", "User-Agent: GhostNotes"])
	if err != OK:
		req.queue_free()
		_fail("Could not start the update check.")


func _valid(result: int, code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Update check failed (HTTP %d)." % code)
		return false
	return true


func _on_releases(result: int, code: int, body: PackedByteArray) -> void:
	if not _valid(result, code): return
	var rows = JSON.parse_string(body.get_string_from_utf8())
	if not rows is Array:
		_fail("The releases response was invalid.")
		return
	var newest := ""
	_release = {}
	for item in rows:
		if not item is Dictionary or bool(item.get("draft", false)) or bool(item.get("prerelease", false)):
			continue
		var tag := String(item.get("tag_name", ""))
		if tag.length() != 13 or not tag.begins_with("build-"):
			continue
		var hex_ok := true
		for c in tag.substr(6):
			if not "0123456789abcdef".contains(c): hex_ok = false
		if not hex_ok: continue
		var date := String(item.get("published_at", ""))
		if date > newest:
			newest = date
			_release = item
	if _release.is_empty():
		_fail("No published build release was found.")
		return
	if String(_release["tag_name"]) == "build-" + current_sha.substr(0, 7):
		_done("build %s · up to date" % current_sha.substr(0, 7))
		return
	var url := _asset_url(_release, "manifest.json")
	if url.is_empty():
		_fail("The latest release has no manifest.")
		return
	_request_url(url, _on_manifest)


func _asset_url(release: Dictionary, name: String) -> String:
	for asset in release.get("assets", []):
		if asset is Dictionary and String(asset.get("name", "")) == name:
			return String(asset.get("browser_download_url", ""))
	return ""


func _asset_name() -> String:
	return "ghost-notes-windows-x86_64.exe" if OS.has_feature("windows") \
		else "ghost-notes-linux-x86_64.bin"


func _on_manifest(result: int, code: int, body: PackedByteArray) -> void:
	if not _valid(result, code): return
	var manifest = JSON.parse_string(body.get_string_from_utf8())
	if not manifest is Dictionary:
		_fail("The release manifest was invalid.")
		return
	available_sha = String(manifest.get("commit", ""))
	if not _is_hex(available_sha, 40) or String(manifest.get("tag", "")) != String(_release["tag_name"]) \
			or not available_sha.begins_with(String(_release["tag_name"]).substr(6)):
		_fail("The release identity did not match its manifest.")
		return
	_expected_digest = ""
	for asset in manifest.get("assets", []):
		if asset is Dictionary and String(asset.get("name", "")) == _asset_name():
			_expected_digest = String(asset.get("sha256", ""))
	if not _is_hex(_expected_digest, 64) or _asset_url(_release, _asset_name()).is_empty():
		_fail("The release has no verified desktop executable.")
		return
	_request_url("https://api.github.com/repos/%s/compare/%s...%s" % [REPO, current_sha, available_sha],
		_on_compare)


func _on_compare(result: int, code: int, body: PackedByteArray) -> void:
	if not _valid(result, code): return
	var comparison = JSON.parse_string(body.get_string_from_utf8())
	if not comparison is Dictionary or String(comparison.get("status", "")) != "ahead":
		_done("build %s · up to date" % current_sha.substr(0, 7))
		return
	status = "downloading build %s…" % available_sha.substr(0, 7)
	changed.emit()
	if DirAccess.make_dir_recursive_absolute(UPDATE_DIR) != OK:
		_fail("Could not prepare the update folder.")
		return
	_download = UPDATE_DIR.path_join("build-%s%s" % [available_sha.substr(0, 7),
		".exe" if OS.has_feature("windows") else ".bin"])
	DirAccess.remove_absolute(_download)
	_request_url(_asset_url(_release, _asset_name()), _on_download, _download)


func _on_download(result: int, code: int, _body: PackedByteArray) -> void:
	if not _valid(result, code): return
	if FileAccess.get_sha256(_download) != _expected_digest:
		_fail("The downloaded app failed its checksum.")
		return
	var target := OS.get_executable_path()
	_staged = target.get_basename() + ".ghost-update-%s.exe" % available_sha.substr(0, 7) \
		if OS.has_feature("windows") else target + ".ghost-update-" + available_sha.substr(0, 7)
	DirAccess.remove_absolute(_staged)
	if DirAccess.copy_absolute(_download, _staged, EXEC_PERMISSIONS) != OK \
			or FileAccess.get_sha256(_staged) != _expected_digest:
		_fail("Could not stage the update beside the app. Check folder permissions.")
		return
	if not OS.has_feature("windows") and FileAccess.set_unix_permissions(_download, EXEC_PERMISSIONS) != OK:
		_fail("Could not make the update executable.")
		return
	_busy = false
	update_ready = true
	status = "build %s ready · restart to update" % available_sha.substr(0, 7)
	changed.emit()


func restart_now() -> void:
	if not update_ready: return
	_restart_requested = true
	var main := get_tree().current_scene
	if main != null and main.has_method("_shutdown"):
		main.call_deferred("_shutdown")


func _exit_tree() -> void:
	if not update_ready: return
	var target := OS.get_executable_path()
	var args := PackedStringArray(["--headless", "--", "--apply-update", target,
		str(OS.get_process_id()), _staged, _expected_digest, "1" if _restart_requested else "0"])
	var pid := OS.create_process(ProjectSettings.globalize_path(_download), args)
	if pid <= 0:
		printerr("ghost/update: could not launch the update helper")


## The downloaded *new* executable runs this after the old process exits.
static func run_helper(args: PackedStringArray) -> int:
	var i := args.find("--apply-update")
	if i < 0 or i + 5 >= args.size(): return 2
	var target := args[i + 1]
	var parent_pid := int(args[i + 2])
	var staged := args[i + 3]
	var digest := args[i + 4]
	var restart := args[i + 5] == "1"
	if parent_pid <= 0 or not _is_hex(digest, 64) or FileAccess.get_sha256(staged) != digest:
		return _helper_error("staged executable failed verification")
	# OS.is_process_running only tracks child processes, and the old app is this
	# helper's parent. On Linux /proc tracks it; on Windows the rename retries
	# below wait until the running executable is released.
	if OS.has_feature("linux"):
		for n in 240:
			if not DirAccess.dir_exists_absolute("/proc/%d" % parent_pid): break
			OS.delay_msec(250)
		if DirAccess.dir_exists_absolute("/proc/%d" % parent_pid):
			return _helper_error("old app did not exit")
	else:
		OS.delay_msec(1000)
	var backup := target + ".ghost-previous"
	DirAccess.remove_absolute(backup)
	var moved := false
	for n in 120:
		if DirAccess.rename_absolute(target, backup) == OK:
			moved = true
			break
		OS.delay_msec(250)
	if not moved: return _helper_error("old executable could not be moved")
	if DirAccess.rename_absolute(staged, target) != OK:
		DirAccess.rename_absolute(backup, target)
		return _helper_error("new executable could not be installed")
	if FileAccess.get_sha256(target) != digest:
		DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(backup, target)
		return _helper_error("installed executable failed verification")
	DirAccess.remove_absolute(ERROR_PATH)
	if restart:
		OS.create_process(target, PackedStringArray())
	return 0


static func _helper_error(message: String) -> int:
	printerr("ghost/update: " + message)
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	var file := FileAccess.open(ERROR_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(message)
	return 1


func _done(message: String) -> void:
	_busy = false
	status = message
	changed.emit()


func _fail(message: String) -> void:
	_busy = false
	status = message
	changed.emit()


static func _is_hex(value: String, count: int) -> bool:
	if value.length() != count: return false
	for c in value:
		if not "0123456789abcdef".contains(c): return false
	return true

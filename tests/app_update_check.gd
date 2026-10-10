extends SceneTree

## The helper replaces a portable executable only after verifying the staged bytes, and keeps
## the old executable as a rollback copy. No network or real installed app is touched.
##   godot --headless --path . --script tests/app_update_check.gd

func _initialize() -> void:
	var had_error := FileAccess.file_exists(AppUpdate.ERROR_PATH)
	var old_error := FileAccess.get_file_as_string(AppUpdate.ERROR_PATH) if had_error else ""
	var temp := DirAccess.create_temp("ghost-app-update-check")
	if temp == null:
		printerr("app_update_check: FAIL: no temporary directory")
		quit(1)
		return
	var root := temp.get_current_dir()
	var target := root.path_join("ghost-notes.exe")
	var staged := root.path_join("ghost-notes.new.exe")
	_write(target, "old build")
	_write(staged, "new build")
	var digest := FileAccess.get_sha256(staged)
	var args := PackedStringArray(["--apply-update", target, "2147483647", staged, digest, "0"])
	if AppUpdate.run_helper(args) != 0 or FileAccess.get_file_as_string(target) != "new build" \
			or FileAccess.get_file_as_string(target + ".ghost-previous") != "old build":
		printerr("app_update_check: FAIL: verified update or rollback copy")
		quit(1)
		return
	_write(staged, "unverified build")
	var rejected := AppUpdate.run_helper(args) != 0 and FileAccess.get_file_as_string(target) == "new build"
	if had_error:
		_write(AppUpdate.ERROR_PATH, old_error)
	else:
		DirAccess.remove_absolute(AppUpdate.ERROR_PATH)
	if not rejected:
		printerr("app_update_check: FAIL: wrong checksum replaced the app")
		quit(1)
		return
	print("app_update_check: ALL OK")
	quit(0)


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)

extends RefCounted
class_name BundledHosts

## External Python processes cannot read the exported res:// pack. The build includes one
## archive of hosts/ in that pack; on first use, copy it to a versioned user:// directory.
## The editor keeps using the source tree directly.

const ARCHIVE := "res://data/hosts_bundle.zip"
static var _root := ""


static func path(resource_path: String) -> String:
	if not resource_path.begins_with("res://hosts/"):
		printerr("bundled hosts: expected a res://hosts/ path: ", resource_path)
		return ""
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(resource_path)
	if _root.is_empty() and not _prepare():
		return ""
	var absolute := _root.path_join(resource_path.trim_prefix("res://hosts/"))
	return absolute if FileAccess.file_exists(absolute) else ""


static func _prepare() -> bool:
	var digest := FileAccess.get_sha256(ARCHIVE)
	if digest.is_empty():
		printerr("bundled hosts: missing ", ARCHIVE)
		return false
	var folder := "user://bundled_hosts/" + digest.substr(0, 16)
	var marker := folder.path_join("ready.txt")
	if FileAccess.file_exists(marker) and FileAccess.get_file_as_string(marker) == digest:
		_root = ProjectSettings.globalize_path(folder)
		return true
	var reader := ZIPReader.new()
	if reader.open(ARCHIVE) != OK:
		printerr("bundled hosts: could not open ", ARCHIVE)
		return false
	for file in reader.get_files():
		if file.is_empty() or file.begins_with("/") or ".." in file.split("/"):
			printerr("bundled hosts: unsafe archive path: ", file)
			reader.close()
			return false
		var dest := folder.path_join(file)
		if DirAccess.make_dir_recursive_absolute(dest.get_base_dir()) != OK:
			reader.close()
			return false
		var part := dest + ".%d.part" % OS.get_process_id()
		var output := FileAccess.open(part, FileAccess.WRITE)
		if output == null:
			reader.close()
			return false
		output.store_buffer(reader.read_file(file))
		output.close()
		if DirAccess.rename_absolute(part, dest) != OK:
			reader.close()
			return false
	reader.close()
	var done := FileAccess.open(marker, FileAccess.WRITE)
	if done == null:
		return false
	done.store_string(digest)
	done.close()
	_root = ProjectSettings.globalize_path(folder)
	return true

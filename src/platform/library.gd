extends RefCounted
class_name Library

## Library - what a person keeps to use on every note (next/library.md): one root, `user://library/`, a folder per shelf -
## `things/` (props, [ThingLibrary]) and `pictures/` (a prop's picture, named by the hash of what it is, [PropStudio]).
## `voices/`: voices kept for every note, each beside its sample ([VoiceLibrary]).
## Moved aside under test ([member root]), so a gate never writes the author's library; what is removed goes to the system
## trash, as a note does ([method trash]).

const ROOT := "user://library"

## Where the library lives.
static var root := ROOT
## (path: String) -> int, an error: where a removed entry goes. The system trash when unset; a gate hands its own.
static var discard: Callable = Callable()


## Whether this process may write the library: one moved aside ([member root], a gate's own) always; the author's only from a
## session that may write the author's things - the Settings autoload where it runs, and never from a process without it.
static func writable() -> bool:
	if root != ROOT:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null
	return s != null and not bool(s.call("is_read_only"))


## The folder of shelf [param name], absolute.
static func shelf(name: String) -> String:
	return ProjectSettings.globalize_path(root.path_join(name))


## The file at [param path] (absolute) taken off its shelf: to the system trash, or the gate's [member discard]. An error, OK
## for done.
static func trash(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return int(discard.call(path)) if discard.is_valid() else OS.move_to_trash(path)

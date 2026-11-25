extends Node

## TitleScreen - what a Title screen thumbnail will be, seen before it goes up: the live stage caught as a Play from the top
## passes the moment the thumbnail is taken at ([method Openings.title_moment]), the Look laid over it as the window lays it
## ([method Filters.apply]), cut about its middle to YouTube's shape and size, and kept in the episode's folder as [constant
## FILE] - the Upload card's preview ([YouTubeCard]). A show plays live as it exports, a pure function of show time, so it is
## that frame of the export drawn at the stage's size; what goes up is still the frame taken from the export itself ([method
## Exporter.thumbnail_args]).
##
## A Play from the top is one whose clock starts within [constant TOP] of zero, with no seek away since: a reading started part
## way opens without its title. The picture is drawn once into a viewport of the thumbnail's size, read back off the graphics
## card without waiting on it ([method RenderingDevice.texture_get_data_async]) and written on a worker. A read-only run keeps
## nothing, and a renderer with no device of its own (the phone's) catches nothing.

const YouTube := preload("res://src/export/youtube.gd")
## The preview's file in the episode's folder.
const FILE := "title_screen.jpg"
## A clock this near zero as Play starts is the top.
const TOP := 0.5
## How long past the moment a catch still shows the title whole: [method Openings.title_moment] keeps the moment at least this
## far before the focus pull.
const LATE := 0.2

## Bumped each time a catch is kept, so the card draws it again.
var kept := 0

var _folder: Callable            # () -> String: the episode's folder, "" for none
var _moment: Callable            # () -> float: when the title screen stands whole, seconds into the take; < 0 for none
var _top := false                # this Play started from the top, no seek away since
var _was := false                # playing at the last frame
var _last := 0.0                 # the clock at the last frame
var _done := false               # caught, or missed, this Play
var _view: SubViewport = null    # the picture drawn at the thumbnail's size, until what was read back is written
var _box := {}                   # the catch in hand: {task, path} once its pixels came back, {failed} if they cannot
var _found := {}                 # folder -> {path, at}: its preview ("" for none), looked for once


## [param folder_by] () -> String, the episode's folder (absolute); [param moment_by] () -> float, the moment the title
## screen stands whole, below zero while the note has none.
func _init(folder_by := Callable(), moment_by := Callable()) -> void:
	_folder = folder_by
	_moment = moment_by


func _ready() -> void:
	Spectrum.sought.connect(_sought)


## A seek: the top again only when it goes back there.
func _sought(t: float) -> void:
	_top = t < TOP
	_done = false


## The preview kept for the episode in [param folder]: `{path, at}` (`at` the time it was caught, as the file says), path ""
## for none. Looked for once a folder, and again as a catch lands.
func shown_in(folder: String) -> Dictionary:
	if folder.is_empty():
		return {"path": "", "at": 0}
	if not _found.has(folder):
		var path := folder.path_join(FILE)
		_found[folder] = {"path": path, "at": FileAccess.get_modified_time(path)} if FileAccess.file_exists(path) \
			else {"path": "", "at": 0}
	return _found[folder]


## Looked for again at the next [method shown_in]: the card asks as its Thumbnail is picked, so a file put there since shows.
func forget() -> void:
	_found.clear()


func _process(_dt: float) -> void:
	_landed()
	if not due(Spectrum.current.time, Spectrum.transport_playing()) or _view != null:
		return
	var folder := String(_folder.call()) if _folder.is_valid() else ""
	if not folder.is_empty() and not Settings.is_read_only():
		_catch(folder)


## A frame of the show at [param t] on its clock, [param on] while it plays: whether the title screen is to be caught now -
## once a Play from the top, within [constant LATE] of its moment (a frame that lands later misses it until the next Play).
func due(t: float, on: bool) -> bool:
	if on and (not _was or t < _last - TOP):
		_top = t < TOP
		_done = false
	_was = on
	_last = t
	if not on or not _top or _done:
		return false
	var at := float(_moment.call()) if _moment.is_valid() else -1.0
	if at < 0.0 or t < at:
		return false
	_done = true
	return t <= at + LATE


## The stage as the window shows it now, Look and all, drawn once at the thumbnail's size; read back once drawn.
func _catch(folder: String) -> void:
	var stage := Graphics.stage()
	if stage == null or RenderingServer.get_rendering_device() == null:
		return
	var size := YouTube.THUMBNAIL_SIZE
	if Director.resolved_frame() == "portrait":
		size = Vector2i(size.y, size.x)
	_view = SubViewport.new()
	_view.size = size
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var pic := TextureRect.new()
	pic.texture = stage.get_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size = Vector2(size)
	Filters.apply(pic, Director.resolved_filters(), Vector2(size))
	_view.add_child(pic)
	add_child(_view)
	_box = {}
	RenderingServer.frame_post_draw.connect(_drawn.bind(folder, size), CONNECT_ONE_SHOT)


## Drawn: its pixels asked of the graphics card, and written on a worker once they come.
func _drawn(folder: String, size: Vector2i) -> void:
	var rd := RenderingServer.get_rendering_device()
	var tex := RenderingServer.texture_get_rd_texture(_view.get_texture().get_rid()) if _view != null else RID()
	if rd == null or not tex.is_valid():
		_box["failed"] = true
		return
	_ask(rd, tex, size, folder.path_join(FILE), _box)


## Static, so what comes back is written whether or not this node is still there to see it: the worker's task goes in
## [param box] as the pixels come, and its answer, the file written, under `path` once it is done.
static func _ask(rd: RenderingDevice, tex: RID, size: Vector2i, to: String, box: Dictionary) -> void:
	var err := rd.texture_get_data_async(tex, 0, func(data: PackedByteArray) -> void:
		box["task"] = WorkerThreadPool.add_task(func() -> void: box["path"] = write(data, size, to), false, "a title screen"))
	if err != OK:
		box["failed"] = true


## [param data], RGBA8 pixels [param size] big, written as a JPEG at [param to] by rename, so it is there whole or not at
## all: [param to] once written, else "".
static func write(data: PackedByteArray, size: Vector2i, to: String) -> String:
	if data.size() != size.x * size.y * 4:
		return ""
	var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	img.convert(Image.FORMAT_RGB8)
	var tmp := to + ".part.jpg"
	if img.save_jpg(tmp, 0.9) != OK or DirAccess.rename_absolute(tmp, to) != OK:
		return ""
	return to


## A catch written: kept as the episode's preview, said to the card, and its viewport let go.
func _landed() -> void:
	if _box.has("task") and not WorkerThreadPool.is_task_completed(int(_box["task"])):
		return
	if not _box.has("task") and not _box.has("failed"):
		return
	if _box.has("task"):
		WorkerThreadPool.wait_for_task_completion(int(_box["task"]))
	var path := String(_box.get("path", ""))
	_box = {}
	if _view != null:
		_view.queue_free()
		_view = null
	if path.is_empty():
		push_warning("ghost: the title screen could not be caught for the Upload card's preview")
		return
	_found[path.get_base_dir()] = {"path": path, "at": FileAccess.get_modified_time(path)}
	kept += 1
	print("ghost: title screen caught for the thumbnail's preview -> " + path)


## A catch still being written is waited for: a worker running as the app quits brings it down.
func _exit_tree() -> void:
	if _box.has("task"):
		WorkerThreadPool.wait_for_task_completion(int(_box["task"]))
		_box = {}

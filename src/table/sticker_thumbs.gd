extends RefCounted
class_name StickerThumbs

## StickerThumbs - small pictures of a sticker book's drawings and sets for a card's rows and the Dex's tiles ([StickerShelf],
## [EpisodeProps]): each file read and made small on a worker, once for each time it is written, and held. Null until it is read.

## The longest side of a picture made small (pixels).
const SIDE := 256

var _held := {}          # "path|modified" -> Image, or null while it is read
var _lock := Mutex.new()
var _tasks: Array = []   # the readings under way, each waited for once done ([method settle])


## The small picture of the file at [param path], or null while it is read (its reading begun on a worker, once).
func of(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var key := "%s|%d" % [path, FileAccess.get_modified_time(path)]
	_lock.lock()
	var known := _held.has(key)
	var img: Variant = _held.get(key)
	if not known:
		_held[key] = null
	_lock.unlock()
	_reap()
	if not known:
		_tasks.append(WorkerThreadPool.add_task(_read.bind(path, key)))
	return img


## The readings that are done, waited for (at once: they are done) and let go.
func _reap() -> void:
	for id in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(int(id)):
			WorkerThreadPool.wait_for_task_completion(int(id))
			_tasks.erase(id)


## Every reading under way waited for: before what it reads goes, or the process ends.
func settle() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(int(id))
	_tasks.clear()


func _read(path: String, key: String) -> void:
	var img := Image.load_from_file(path)
	if img != null and not img.is_empty():
		var k := float(SIDE) / float(maxi(img.get_width(), img.get_height()))
		if k < 1.0:
			img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	_lock.lock()
	_held[key] = img
	_lock.unlock()

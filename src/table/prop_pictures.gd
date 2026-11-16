extends RefCounted
class_name PropPictures

## PropPictures - the pictures a card shows of props, by the hash of what each is ([method ThingLibrary.hash_of]): taken by
## [PropStudio] one at a time, kept on the library's `pictures` shelf where the library may be written ([method Library.writable]),
## and held here once taken or read. A picture kept on the shelf is read on a worker, a few at a time; one never taken is taken in
## the order asked, the props wanted now ([method want], [method of]) before those only made ready ([method prepare]), which wait no
## longer once the shelf asking for them closes. A process that takes no pictures answers null for each.

## How many kept pictures one worker reads before the next are asked for.
const READ_AT_ONCE := 24

## What takes a picture, awaited: `(thing, materials, hash, store) -> {image, size}`, {} where none can be taken ([method
## PropStudio.picture]). A gate hands its own.
var take: Callable = PropStudio.picture

var _images := {}         # hash -> Image, or null where none can be taken
var _sizes := {}          # hash -> its size, as written
var _queue: Array = []    # [hash, thing, materials] wanted, waiting to be taken, the most wanted first
var _ready: Array = []    # [hash, thing, materials] made ready, taken once nothing is wanted
var _pumping := false
var _reads: Array = []    # hashes whose kept picture waits to be read
var _reading := {}        # hash -> true from asked until read
var _unread := {}         # hash -> true where the kept file would not read: taken again
var _read_busy := false


## The picture of prop [param h] (a [param thing] built of [param mats]) once taken or read, null until then - asked for now if it
## is not: read where it is kept, else taken after the props already waiting.
func of(h: String, thing: Dictionary, mats: Dictionary) -> Variant:
	if h.is_empty():
		return null
	if _images.has(h):
		return _images[h]
	if _kept(h):
		_read(h)
	elif not _queue.any(func(q: Array) -> bool: return String(q[0]) == h):
		_ready = _ready.filter(func(q: Array) -> bool: return String(q[0]) != h)
		_queue.append([h, thing, mats])
		_pump()
	return null


## The props [param asked] (each `[hash, thing, materials]`) wanted now, ahead of every other: read where kept, taken where not,
## in the order given. What waited before waits behind them.
func want(asked: Array) -> void:
	var first: Array = []
	var have := {}
	for a in asked:
		var h := String(a[0])
		if h.is_empty() or _images.has(h) or have.has(h):
			continue
		have[h] = true
		if _kept(h):
			_read(h)
		else:
			first.append(a)
	if first.is_empty():
		return
	_queue = first + _queue.filter(func(q: Array) -> bool: return not have.has(String(q[0])))
	_ready = _ready.filter(func(q: Array) -> bool: return not have.has(String(q[0])))
	_pump()


## The props [param asked] (each `[hash, thing, materials]`) made ready in place of those before: each never taken is taken once
## nothing is wanted, so it is kept by the time it is. One already kept is left on the shelf until it is wanted; [] stops the rest.
func prepare(asked: Array) -> void:
	var wanted := {}
	for q in _queue:
		wanted[String(q[0])] = true
	_ready = []
	for a in asked:
		var h := String(a[0])
		if h.is_empty() or _images.has(h) or wanted.has(h) or _kept(h):
			continue
		wanted[h] = true
		_ready.append(a)
	if not _ready.is_empty():
		_pump()


## The picture of prop [param h] if it has been taken or read, null otherwise; never asks for one.
func image(h: String) -> Variant:
	return _images.get(h)


## Prop [param h]'s size as its picture measured it, "" until it is taken.
func size_of(h: String) -> String:
	return String(_sizes.get(h, ""))


## How many props wait for a picture to be taken, wanted or made ready.
func waiting() -> int:
	return _queue.size() + _ready.size()


func _kept(h: String) -> bool:
	return _reading.has(h) or (not _unread.has(h) and FileAccess.file_exists(PropStudio.kept_path(h)))


## Prop [param h]'s kept picture read on a worker, with the others asked meanwhile.
func _read(h: String) -> void:
	if _reading.has(h):
		return
	_reading[h] = true
	_reads.append(h)
	if not _read_busy:
		_read_on()


func _read_on() -> void:
	_read_busy = true
	var tree := PropStudio.tree()
	while not _reads.is_empty():
		var hs: Array = _reads.slice(0, READ_AT_ONCE)
		_reads = _reads.slice(READ_AT_ONCE)
		var got: Array = []
		var task := WorkerThreadPool.add_task(func() -> void:
			for h in hs:
				var path := PropStudio.kept_path(String(h))
				var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
				got.append([String(h), img, FileAccess.get_file_as_string(path.get_basename() + ".txt").strip_edges()]))
		while not WorkerThreadPool.is_task_completed(task):
			await tree.process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		for g in got:
			var h := String(g[0])
			_reading.erase(h)
			if g[1] is Image and not (g[1] as Image).is_empty():
				_images[h] = g[1]
				_sizes[h] = String(g[2])
			else:
				_unread[h] = true
	_read_busy = false


func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while not _queue.is_empty() or not _ready.is_empty():
		var q: Array = _queue.pop_front() if not _queue.is_empty() else _ready.pop_front()
		if _images.has(String(q[0])):
			continue
		var got: Dictionary = await take.call(q[1], q[2], String(q[0]), Library.writable())
		if got.is_empty():
			_images[String(q[0])] = null
			if not PropStudio.can_see():
				_queue.clear()
				_ready.clear()
		else:
			_images[String(q[0])] = got["image"]
			_sizes[String(q[0])] = String(got["size"])
	_pumping = false

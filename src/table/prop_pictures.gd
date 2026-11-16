extends RefCounted
class_name PropPictures

## PropPictures - the pictures a card shows of props, by the hash of what each is ([method ThingLibrary.hash_of]): taken by
## [PropStudio] one at a time as they are first asked for, kept on the library's `pictures` shelf where the library may be
## written ([method Library.writable]), and held here once taken. A process that takes no pictures answers null for each.

var _images := {}         # hash -> Image, or null where none can be taken
var _sizes := {}          # hash -> its size, as written
var _queue: Array = []    # [hash, thing, materials] waiting, in order
var _pumping := false


## The picture of prop [param h] (a [param thing] built of [param mats]) once taken, null until then - asked for now if it is not.
func of(h: String, thing: Dictionary, mats: Dictionary) -> Variant:
	if h.is_empty():
		return null
	if _images.has(h):
		return _images[h]
	var have := PropStudio.cached(h)
	if not have.is_empty():
		_images[h] = have["image"]
		_sizes[h] = String(have["size"])
		return have["image"]
	if not _queue.any(func(q: Array) -> bool: return String(q[0]) == h):
		_queue.append([h, thing, mats])
	if not _pumping:
		_pump()
	return null


## The picture of prop [param h] if it has been taken, null otherwise; never asks for one.
func image(h: String) -> Variant:
	return _images.get(h)


## Prop [param h]'s size as its picture measured it, "" until it is taken.
func size_of(h: String) -> String:
	return String(_sizes.get(h, ""))


func _pump() -> void:
	_pumping = true
	while not _queue.is_empty():
		var q: Array = _queue.pop_front()
		var got: Dictionary = await PropStudio.picture(q[1], q[2], String(q[0]), Library.writable())
		if got.is_empty():
			_images[String(q[0])] = null
			if not PropStudio.can_see():
				_queue.clear()
		else:
			_images[String(q[0])] = got["image"]
			_sizes[String(q[0])] = String(got["size"])
	_pumping = false

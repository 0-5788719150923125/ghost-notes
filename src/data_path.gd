extends RefCounted
class_name DataPath

## DataPath - edits of nested data (Dictionaries and Arrays) as PURE FUNCTIONS, addressed by a
## path: the keys and indexes from the root down, `["sequence", 2, "track", "spans", 0, "from"]`.
##
## EVERY EDIT RETURNS A NEW ROOT AND LEAVES ITS ARGUMENT AS IT WAS. Godot's containers are
## references, so an edit made in place reaches everything that holds the same Dictionary - a card,
## the Director, the document's last snapshot - and "what changed" can no longer be asked ([Settings]
## learned it from ConfigFile, which keeps the reference it is handed). With a new root per edit an
## editor's history is a list of roots, an undo is taking the one before, and whoever was handed
## the old one still has exactly what they were given.
##
## The whole root is copied per edit, not only the path walked. A storyboard is a few thousand
## values and an edit is a person's click; sharing the untouched branches would save nothing a
## person could feel, and would bring the aliasing back.
##
## A path that leads nowhere is a no-op, never an error and never a repair: [method put] makes the
## maps a path names on its way down, and nothing else invents structure.


## The value at [param path], or [param fallback] where the path leads nowhere.
static func at(root: Variant, path: Array, fallback: Variant = null) -> Variant:
	var node: Variant = root
	for key in path:
		if not _has(node, key):
			return fallback
		node = node[key]
	return node


## Whether [param path] leads to a value.
static func has(root: Variant, path: Array) -> bool:
	var node: Variant = root
	for key in path:
		if not _has(node, key):
			return false
		node = node[key]
	return true


## [param root] with [param value] at [param path]. A map the path names and the data lacks is
## made on the way down; an index must be one the list has, or one past its end (an append).
static func put(root: Variant, path: Array, value: Variant) -> Variant:
	if path.is_empty():
		return _copy(value)
	var out: Variant = _copy(root)
	if not (out is Dictionary or out is Array):
		out = {}
	var node: Variant = out
	for i in path.size() - 1:
		var key: Variant = path[i]
		if not _has(node, key):
			if not (node is Dictionary):
				return _copy(root)             # a list cannot grow a map in its middle
			node[key] = {}
		node = node[key]
	var last: Variant = path[path.size() - 1]
	if node is Array:
		var arr: Array = node
		var i := int(last)
		if typeof(last) != TYPE_INT or i < 0 or i > arr.size():
			return _copy(root)
		if i == arr.size():
			arr.append(_copy(value))
		else:
			arr[i] = _copy(value)
	elif node is Dictionary:
		node[last] = _copy(value)
	else:
		return _copy(root)
	return out


## [param root] without what is at [param path]: a key erased, a list's item removed.
static func cut(root: Variant, path: Array) -> Variant:
	var out: Variant = _copy(root)
	if path.is_empty() or not has(out, path):
		return out
	var node: Variant = at(out, path.slice(0, path.size() - 1))
	var last: Variant = path[path.size() - 1]
	if node is Array:
		(node as Array).remove_at(int(last))
	elif node is Dictionary:
		(node as Dictionary).erase(last)
	return out


## [param root] with [param item] put into the list at [param path], before [param index]
## (clamped to the list; the list is made when the path's last key has none).
static func insert(root: Variant, path: Array, index: int, item: Variant) -> Variant:
	var list: Variant = at(root, path)
	var arr: Array = (list as Array).duplicate(true) if list is Array else []
	arr.insert(clampi(index, 0, arr.size()), _copy(item))
	return put(root, path, arr)


## [param root] with the list at [param path]'s item [param from] moved to stand at [param to].
static func move(root: Variant, path: Array, from: int, to: int) -> Variant:
	var list: Variant = at(root, path)
	if not (list is Array) or from < 0 or from >= (list as Array).size():
		return _copy(root)
	var arr: Array = (list as Array).duplicate(true)
	var item: Variant = arr[from]
	arr.remove_at(from)
	arr.insert(clampi(to, 0, arr.size()), item)
	return put(root, path, arr)


## Equal as data: maps by key whatever their order, lists in order, numbers by value whatever
## their type (YAML reads `4`, JSON gives `4.0`).
static func same(a: Variant, b: Variant) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not same(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


static func _has(node: Variant, key: Variant) -> bool:
	if node is Dictionary:
		return (node as Dictionary).has(key)
	if node is Array:
		return typeof(key) == TYPE_INT and int(key) >= 0 and int(key) < (node as Array).size()
	return false


static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v

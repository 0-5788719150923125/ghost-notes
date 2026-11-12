extends RefCounted
class_name AssemblyTrack

## AssemblyTrack - what happened to the bricks, read back ([AssemblyBake] wrote it, stretch by stretch, on a clock of its own - the record's
## tau - that stops whenever nothing is moving). A piece's pose at any moment of the record is a lookup, so a scrub lands exactly where the
## same moment was and an hour costs a frame what a minute does: nothing here is worked out again. It knows nothing of the show's time,
## which [method Assembly.lay] maps onto it.

## A record's tau is looked up by twentieths of a second, for what moved near it: a coarser step has a frame posing the whole heap in a dig.
const BUCKET := 0.05

var stock_ready := false
var start := PackedFloat32Array()     # every piece's place in the stock: 7 floats a piece
var keys: Array = []                  # a piece -> PackedFloat32Array [tau, x, y, z, qx, qy, qz, qw]...
var seats: Array = []                 # a piece -> [[tau on, tau off, local Transform3D]...]
var turns: Array = []                 # [tau from, tau to, yaw from, yaw to] in order
var steps := {}                       # a step's index -> {t0, t1, stops: [[offset, natural, least, weight, held]...]}
var baked_to := -1                    # how many of the steps are here
var ev_t := PackedFloat32Array()      # each sound's moment
var ev := PackedFloat32Array()        # ...its x, y, z, strength, reach, weight
var ev_kind := PackedStringArray()    # ...its kind and what it hit, "hit/metal"
var _buckets := {}                    # a bucket of tau -> {piece: true}


func _init(piece_count: int) -> void:
	keys.resize(piece_count)
	seats.resize(piece_count)
	for i in piece_count:
		keys[i] = PackedFloat32Array()
		seats[i] = []


## The stock as it lay poured ([method AssemblyBake._pour]).
func add_stock(rest: Dictionary) -> void:
	start = rest["poses"]
	stock_ready = true


## A stretch of the record landed ([method AssemblyBake._write_stretch]), in the order they were written.
func add_stretch(seg: Dictionary) -> void:
	var ks: Dictionary = seg["keys"]
	for id in ks:
		var more: PackedFloat32Array = ks[id]
		var mine: PackedFloat32Array = keys[int(id)]
		mine.append_array(more)
		keys[int(id)] = mine
		var i := 0
		while i < more.size():
			var b := int(more[i] / BUCKET)
			if not _buckets.has(b):
				_buckets[b] = {}
			(_buckets[b] as Dictionary)[int(id)] = true
			i += 8
	for s in seg["seat_log"]:
		var a: Array = s
		var id := int(a[0])
		var list: Array = seats[id]
		if bool(a[2]):
			list.append([float(a[1]), INF, a[3] as Transform3D])
		elif not list.is_empty():
			(list[list.size() - 1] as Array)[1] = float(a[1])
		var b := int(float(a[1]) / BUCKET)
		if not _buckets.has(b):
			_buckets[b] = {}
		(_buckets[b] as Dictionary)[id] = true
	turns.append_array(seg["turns"])
	for st in seg["steps"]:
		steps[int((st as Dictionary)["k"])] = st
	baked_to = int(seg["to"])
	ev_t.append_array(seg["ev_t"])
	ev.append_array(seg["ev"])
	ev_kind.append_array(seg["ev_k"])


func piece_count() -> int:
	return keys.size()


## The plate's turn at [param tau]: as written where the record has none yet.
func yaw_at(tau: float, at_first: float) -> float:
	var y := at_first
	for t in turns:
		var a: Array = t
		if tau >= float(a[1]):
			y = float(a[3])
		elif tau > float(a[0]):
			return lerpf(float(a[2]), float(a[3]), Hands.smooth((tau - float(a[0])) / maxf(float(a[1]) - float(a[0]), 1e-4)))
		else:
			break
	return y


## Whether the plate is turning at [param tau].
func turning(tau: float) -> bool:
	for t in turns:
		if tau >= float((t as Array)[0]) - 0.02 and tau <= float((t as Array)[1]) + 0.02:
			return true
	return false


## Piece [param id] at [param tau]: on the plate at [param plate], or where its keys have it: held at its first key before that.
func pose_of(id: int, tau: float, plate: Transform3D) -> Transform3D:
	var list: Array = seats[id]
	var i := list.size() - 1
	while i >= 0:
		var s: Array = list[i]
		if tau >= float(s[0]):
			if tau < float(s[1]):
				return plate * (s[2] as Transform3D)
			break
		i -= 1
	var k: PackedFloat32Array = keys[id]
	var n := k.size() / 8
	if n == 0 or tau <= k[0]:
		return _start_of(id)
	if tau >= k[(n - 1) * 8]:
		return _key(k, n - 1)
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var m := (lo + hi) / 2
		if k[m * 8] <= tau:
			lo = m
		else:
			hi = m
	var a := lo * 8
	var b := hi * 8
	var u := (tau - k[a]) / maxf(k[b] - k[a], 1e-6)
	var p := Vector3(k[a + 1], k[a + 2], k[a + 3]).lerp(Vector3(k[b + 1], k[b + 2], k[b + 3]), u)
	var q := Quaternion(k[a + 4], k[a + 5], k[a + 6], k[a + 7]).slerp(Quaternion(k[b + 4], k[b + 5], k[b + 6], k[b + 7]), u)
	return Transform3D(Basis(q), p)


func _start_of(id: int) -> Transform3D:
	if start.size() < (id + 1) * 7:
		return Transform3D.IDENTITY
	var i := id * 7
	return Transform3D(Basis(Quaternion(start[i + 3], start[i + 4], start[i + 5], start[i + 6])), Vector3(start[i], start[i + 1], start[i + 2]))


static func _key(k: PackedFloat32Array, i: int) -> Transform3D:
	var a := i * 8
	return Transform3D(Basis(Quaternion(k[a + 4], k[a + 5], k[a + 6], k[a + 7])), Vector3(k[a + 1], k[a + 2], k[a + 3]))


## What moved between [param a] and [param b] of the record: a frame's work is that and only that.
func moved_between(a: float, b: float) -> Dictionary:
	var out := {}
	var b0 := int(minf(a, b) / BUCKET) - 1
	var b1 := int(maxf(a, b) / BUCKET) + 1
	for i in range(b0, b1 + 1):
		if _buckets.has(i):
			out.merge(_buckets[i])
	return out


## The sounds between [param a] and [param b] of the record, as indexes.
func events_between(a: float, b: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if ev_t.is_empty() or b <= a:
		return out
	var i := ev_t.bsearch(a)
	# ...the record's order is the order they happened, but a piece of a stretch may share a moment with the next
	while i < ev_t.size() and ev_t[i] < b:
		out.append(i)
		i += 1
	return out

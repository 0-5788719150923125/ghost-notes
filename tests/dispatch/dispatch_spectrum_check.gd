extends SceneTree

## Gate for the receiver's SDR screen ([DispatchSpectrum], next/dispatch.md). It holds:
##
## - the receiver's filter shows: idle, the band inside its passband is brighter than past its edges;
## - a storm lifts the band: Io-B's crackle over the bare hiss, its rows with a pop [DispatchSounds] plays brighter than those
##   with none; Io-A's surf brighter at a swell's crest than in its trough;
## - a voice on the receiver is a station: through a word the heard bands show either side of the carrier, alike on both sides,
##   the carrier the brightest column; between its words the carrier stands and the bands do not show; before its turn no carrier;
## - the room's voice never reaches it: the same bands handed with no voice on the receiver change nothing (the control: handed
##   through the receiver's word, they do);
## - with the grid down the screen is dark;
## - a row is a pure function of its moment and what it is handed (the same twice);
## - the waterfall: each row laid one image row above the one before, round the ring, in the palette's colors; run on, the rows
##   made stay; a jump back starts it empty (the control: the row that was there before the jump was not empty);
## - the SDR's own make has the screen the medium draws on, at the screen's proportions.
##
## Run: godot --headless --path . --script tests/dispatch/dispatch_spectrum_check.gd

const S := preload("res://src/dispatch/dispatch_spectrum.gd")

var _fails: Array = []


func _init() -> void:
	var none := PackedFloat32Array()
	var crackle := {"t": 10.0, "t1": 20.0, "kind": "static", "storm": "popcorn", "seed": 7, "under": [], "words": []}
	var surf := {"t": 30.0, "t1": 50.0, "kind": "static", "storm": "surf", "seed": 9, "under": [], "words": []}
	var station := {"t": 60.0, "t1": 70.0, "kind": "static", "storm": "popcorn", "seed": 5, "under": [[1.0, 4.0]],
		"words": [[1.25, 1.75], [2.5, 3.2]]}
	var open := [crackle, surf, station]
	# the filter
	var idle := S.row_at(5.0, open, none, true)
	_ok(_inside(idle) > _outside(idle) + 0.08, "idle, the filter's passband is brighter than past its edges (%.3f against %.3f)" % [_inside(idle), _outside(idle)])
	# Io-B's crackle over the bare hiss, and a pop that is heard is seen
	var storm := S.row_at(15.0, open, none, true)
	var bare := S.row_at(15.0, [], none, true)
	_ok(_inside(storm) > _inside(bare) + 0.1, "a storm lifts the band over the bare hiss (%.3f against %.3f)" % [_inside(storm), _inside(bare)])
	var with_pop := 0.0
	var n_pop := 0
	var without := 0.0
	var n_without := 0
	for r in range(int(11.0 * S.ROW_RATE), int(19.0 * S.ROW_RATE)):
		var t := float(r) / S.ROW_RATE
		var u := t - 10.0
		var lv := DispatchSounds.receiver_level(crackle, u)
		var row := S.row_at(t, open, none, true)
		if S.pop_in(crackle, u, 1.0 / S.ROW_RATE, lv) > 0.0:
			with_pop += _inside(row)
			n_pop += 1
		else:
			without += _inside(row)
			n_without += 1
	_ok(n_pop > 5 and n_without > 5 and with_pop / float(n_pop) > without / float(n_without) + 0.02,
		"rows with a pop the receiver plays are brighter than rows without (%d and %d rows)" % [n_pop, n_without])
	# Io-A's swells
	var crest := 0.0
	var trough := 0.0
	var hi := -1.0
	var lo := 2.0
	for r in range(int(31.0 * S.ROW_RATE), int(49.0 * S.ROW_RATE)):
		var t := float(r) / S.ROW_RATE
		var lv := DispatchSounds.storm_level("surf", t - 30.0, 9, 20.0)
		if lv > hi:
			hi = lv
			crest = t
		if lv < lo:
			lo = lv
			trough = t
	var up := S.row_at(crest, open, none, true)
	var down := S.row_at(trough, open, none, true)
	_ok(_inside(up) > _inside(down) + 0.05, "the surf is brighter at a swell's crest than in its trough (%.3f against %.3f)" % [_inside(up), _inside(down)])
	# a voice on the receiver: the bands either side of the carrier through a word
	var bands := PackedFloat32Array()
	bands.resize(AudioFeatures.BAND_COUNT)
	var ratio := AudioFeatures.FREQ_MAX / AudioFeatures.FREQ_MIN
	for b in bands.size():
		var hz := AudioFeatures.FREQ_MIN * pow(ratio, (float(b) + 0.5) / float(bands.size()))
		bands[b] = 0.65 if hz > 600.0 and hz < 1000.0 else 0.0
	var mid := S.COLS / 2
	var at := mid + int(round(800.0 / (S.SPAN / float(S.COLS - 1))))
	var heard := S.row_at(61.5, open, bands, true)
	var unheard := S.row_at(61.5, open, none, true)
	_ok(heard[at] > unheard[at] + 0.15 and heard[2 * mid - at] > unheard[2 * mid - at] + 0.15,
		"through a word the voice's bands show either side of the carrier (%.3f, %.3f against %.3f)" % [heard[at], heard[2 * mid - at], unheard[at]])
	_ok(absf(heard[at] - heard[2 * mid - at]) < 0.05, "the two sidebands are alike (%.3f, %.3f)" % [heard[at], heard[2 * mid - at]])
	var most := 0.0
	for v in heard:
		most = maxf(most, v)
	_ok(is_equal_approx(heard[mid], most), "the carrier is the brightest column (%.3f, the most %.3f)" % [heard[mid], most])
	var between := S.row_at(62.1, open, bands, true)
	_ok(between == S.row_at(62.1, open, none, true) and between[mid] > 0.8,
		"between the voice's words the carrier stands (%.3f) and the bands do not show" % between[mid])
	_ok(S.row_at(60.5, open, none, true)[mid] < 0.5, "before the voice's turn there is no carrier")
	# the room's voice: the same bands with no voice on the receiver
	_ok(S.row_at(5.0, open, bands, true) == idle and S.row_at(15.0, open, bands, true) == storm,
		"the room's voice never reaches the screen: bands handed with no voice on the receiver change nothing")
	# the grid down, and a pure function
	var dark := S.row_at(15.0, open, bands, false)
	var lit := 0.0
	for v in dark:
		lit = maxf(lit, v)
	_ok(lit == 0.0 and dark.size() == S.COLS, "with the grid down the screen is dark")
	_ok(S.row_at(61.5, open, bands, true) == heard, "a row is the same twice")
	# the waterfall's ring
	_ok(S.row_y(6) == posmod(S.row_y(5) - 1, S.ROWS) and S.row_y(S.ROWS) == S.row_y(0), "each row is laid one image row above the one before, round the ring")
	var sp := S.new()
	var lut := S.palette()
	sp.tick(0.0, open, none, 1.0)
	sp.tick(5.0 / S.ROW_RATE, open, none, 1.0)
	var c := mid + 10
	var want := S.row_at(5.0 / S.ROW_RATE, open, none, true)
	var k := int(want[c] * 255.0) * 4
	_ok(sp.head == 5 and sp.top() == S.row_y(5) and sp.image.get_pixel(c, S.row_y(5)) == Color8(lut[k], lut[k + 1], lut[k + 2]),
		"a row made is laid in the palette's colors where its ring says (head %d)" % sp.head)
	var four := sp.image.get_pixel(c, S.row_y(4))
	sp.tick(7.0 / S.ROW_RATE, open, none, 1.0)
	_ok(sp.head == 7 and sp.image.get_pixel(c, S.row_y(4)) == four, "run on, the rows already made stay")
	var blank := Color8(lut[0], lut[1], lut[2])
	_ok(four != blank, "the control: the row there before a jump is not empty")
	sp.tick(2.0 / S.ROW_RATE, open, none, 1.0)
	_ok(sp.head == 2 and sp.image.get_pixel(c, S.row_y(4)) == blank and sp.image.get_pixel(c, S.row_y(2)) != blank,
		"a jump back starts the waterfall empty, but for the row it lands on")
	# the SDR's make
	var b := PropMakes.made("sdr", {}, 1)
	var rig := PropRig.new(b) if b.get("node") is Node3D else null
	var face: Dictionary = rig.face_part("screen") if rig != null else {}
	var size: Vector2 = face.get("size", Vector2.ZERO)
	var shape := float(DispatchScreens.SPECTRUM_SIZE.x) / float(DispatchScreens.SPECTRUM_SIZE.y)
	_ok(rig != null and rig.face("screen") != null and size.y > 0.0 and absf(size.x / size.y - shape) < 0.02,
		"the SDR's make has its screen at the picture's proportions (%s)" % str(size))
	if rig != null:
		rig.node.free()
	if _fails.is_empty():
		print("dispatch_spectrum_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("dispatch_spectrum_check: FAIL  " + f)
		quit(1)


## A row's mean inside the receiver's passband (within 2 kHz of the carrier, the carrier's own columns left out).
func _inside(row: PackedFloat32Array) -> float:
	var s := 0.0
	var n := 0
	for c in row.size():
		var f := absf(S.freq_of(c))
		if f < 2000.0 and f > 200.0:
			s += row[c]
			n += 1
	return s / float(maxi(n, 1))


## ...and past its edges.
func _outside(row: PackedFloat32Array) -> float:
	var s := 0.0
	var n := 0
	for c in row.size():
		if absf(S.freq_of(c)) > S.IF_EDGE + 300.0:
			s += row[c]
			n += 1
	return s / float(maxi(n, 1))


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)

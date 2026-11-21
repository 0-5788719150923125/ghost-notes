extends RefCounted
class_name DispatchSpectrum

## DispatchSpectrum - what the little modern screen on the receiver shows (next/dispatch.md): a hobbyist's SDR tapping the
## old set's band, its spectrum on top and its waterfall under it, a row a moment, the newest at the top, scrolling down.
## Drawn on the SDR's `screen` face ([PropMakes] `sdr`, standing on the receiver's oscilloscope, [method DispatchSet._sdr]);
## with the SDR taken off the desk nothing is made.
##
## Drawn from what the receiver sounds, across [constant SPAN] round the dial's [constant FREQ]: the band's hiss inside the
## receiver's filter (bright in its passband, dark past its edges), a storm laid over it - Io-B's pops as short streaks
## across the band, the very pops [DispatchSounds] plays; Io-A's surf as swells - and a voice that comes in on the receiver
## as a station: its carrier a line down the middle, keyed up a beat before the first word and down after the last, and the
## voice's own spectrum mirrored either side of it, read off the heard audio's bands ([AudioFeatures], handed to the
## medium's `advance`) only while that voice is speaking. So the room's own voice, the keys and a phone never reach it.
##
## A row is a pure function of its moment and what it is handed ([method row_at]). The waterfall keeps the rows it has made
## ([method tick]), and the bands each row heard a voice through; where the show jumps (a scrub, a reading begun mid-way, its
## first frame) the rows before are made again on a worker ([method _refill]), a voice heard there before with them, so the
## screen is always full. With the grid down its rows are dark. Levels are display decibels, [constant DB_LOW] the screen's
## black and [constant DB_HIGH] its top.

## The band across the screen (Hz) round the dial's frequency (Hz), its columns (the middle one the carrier's), its rows
## (the waterfall's height) and how many it makes a second; the most one frame makes itself, past which the waterfall is made
## again on a worker; how many rows' heard bands are kept, the nearest the show's place.
const SPAN := 12000.0
const FREQ := 20.1e6
const COLS := 201
const ROWS := 120
const ROW_RATE := 24.0
const MOST_A_FRAME := 8
const HEARD_MOST := 30000
## The screen's scale (display dB): its black and its top; the SDR's own floor, off the receiver's filter.
const DB_LOW := -110.0
const DB_HIGH := -30.0
const FLOOR_DB := -108.0
## A receiver amplitude (full scale, as [DispatchSounds] makes it) on the screen's scale: 20 log10 of it, plus this.
const CAL := -41.0
## The receiver's filter: flat to here (Hz off the carrier), sagging this much at its edge (dB), rolled off to this much
## down by there.
const IF_FLAT := 3000.0
const IF_EDGE := 4200.0
const IF_SAG := -1.5
const IF_OUT := -20.0
## Io-A's surf at its crest, as the receiver's amplitude (it rides the storm's level); a pop held in a row as a frame of
## this length would hold it (s), so a pop shows as an SDR's short frames show it.
const SURF_RMS := 0.03
const POP_FRAME := 0.004
## A voice: a heard band's decibels on the screen's scale (plus this); the audio it is read over (Hz either side of the
## carrier), eased in from the low end over an octave and out from the top over the last of it; and how far round each of
## its words it is taken (s, before and after).
const VOICE_DB := -18.0
const VOICE_LOW := 150.0
const VOICE_TOP := 2600.0
const VOICE_HIGH := 3400.0
const VOICE_IN := 0.04
const VOICE_OUT := 0.12
## The station's carrier on the screen's scale, eased up and down over this long (s), and how far down the columns
## either side of it read (dB).
const CARRIER_DB := -36.0
const CARRIER_EASE := 0.25
const CARRIER_SIDE := [-18.0, -32.0]
## How far the spectrum's line goes toward each newest row (an SDR program's averaging).
const TRACE_EASE := 0.5
## How many noise draws a cell picks among ([method _columns]); decibels to power and back by [method exp] and [method log].
const SPECKLE := 4096
const SPECKLE_MASK := SPECKLE - 1
const DB_E := 0.2302585093
const E_DB := 4.3429448190
## The waterfall's colors, low to high on the screen's scale: navy through blue, pale, yellow and orange to red.
const PALETTE := [[0.0, Color(0.0, 0.0, 0.03)], [0.12, Color(0.0, 0.024, 0.23)], [0.28, Color(0.04, 0.165, 0.6)],
	[0.42, Color(0.12, 0.37, 0.88)], [0.52, Color(0.35, 0.66, 1.0)], [0.6, Color(0.85, 0.93, 1.0)],
	[0.68, Color(1.0, 0.91, 0.35)], [0.78, Color(1.0, 0.69, 0.13)], [0.88, Color(1.0, 0.42, 0.06)], [1.0, Color(0.91, 0.13, 0.04)]]

var image: Image                  # the waterfall, a ring of rows: row r at image row [method row_y]
var texture: ImageTexture
var head := -1                    # the newest row made: its moment times [constant ROW_RATE]
var trace := PackedFloat32Array() # the spectrum's line: the newest rows eased into, each column on the screen's scale (0-1)
var _lut := PackedByteArray()     # the palette, 256 colors RGBA8
var _line: Image                  # one row's colors, laid into the ring
var _heard := {}                  # a row made while the receiver's voice spoke -> the bands it was read off
var _task := -1                   # the waterfall being made again on a worker ([method _refill]), and what it hands back
var _box := {}
var _next := {}                   # a refill asked for while one runs: started once that one is in, which is then stale
static var _cols := {}            # what each column keeps from row to row ([method _columns])


func _init() -> void:
	_lut = palette()
	_columns()
	image = Image.create_empty(COLS, ROWS, false, Image.FORMAT_RGBA8)
	_line = Image.create_empty(COLS, 1, false, Image.FORMAT_RGBA8)
	_blank()
	texture = ImageTexture.create_from_image(image)
	trace.resize(COLS)


## The rows due by show time [param t] made and laid in, from what the receiver is open on ([param open], the medium's
## stretches, [method DispatchMedium._build_receiver]), the heard audio's [param bands] and the grid's [param power]: true
## when anything changed. A jump back, or on by more than the waterfall holds, starts it empty.
func tick(t: float, open: Array, bands: PackedFloat32Array, power: float) -> bool:
	var changed := _land()
	var now := int(floor(t * ROW_RATE))
	if now == head:
		return changed
	var jumped := head < 0 or now < head or now - head > MOST_A_FRAME
	if jumped:
		_refill(now - 1, open, power > 0.5)
		head = now - 1
	for r in range(head + 1, now + 1):
		var at := float(r) / ROW_RATE
		if not bands.is_empty() and heard_at(at, open) > 0.0:
			_keep(r, bands)
		var row := row_at(at, open, bands, power > 0.5)
		_lay(r, row)
		for c in COLS:
			trace[c] = row[c] if jumped else lerpf(trace[c], row[c], TRACE_EASE)
		jumped = false
	head = now
	texture.update(image)
	return true


## A waterfall being made again on a worker waited for and laid in (a gate's).
func settle() -> void:
	while _task >= 0:
		_land(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


## The image row the newest row is in: the waterfall is drawn from there down, then from the image's top.
func top() -> int:
	return row_y(head)


## The image row row [param r] is laid in: each newer row one up, round the ring.
static func row_y(r: int) -> int:
	return posmod(-1 - r, ROWS)


## One row at show time [param t]: each column's level on the screen's scale (0-1), its frequency
## [method freq_of]. [param open]: the receiver's stretches (`{t, t1, storm, seed, under, words}`); [param bands]: the heard
## audio's (empty for none); dark where not [param powered].
static func row_at(t: float, open: Array, bands: PackedFloat32Array, powered: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(COLS)
	if not powered:
		return out
	var o := {}
	for s in open:
		if float(s["t"]) <= t and t < float(s["t1"]):
			o = s
			break
	var u := t - float(o.get("t", 0.0))
	var lv := DispatchSounds.receiver_level(o, u) if not o.is_empty() else 0.0
	var storm := String(o.get("storm", ""))
	var hiss := DispatchSounds.HISS_OPEN * lv * 0.6 + DispatchSounds.HISS if not o.is_empty() else DispatchSounds.HISS
	var p_rx := hiss * hiss
	if storm == "surf":
		p_rx += pow(SURF_RMS * lv, 2.0)
	elif not o.is_empty():
		var pop := pop_in(o, u, 1.0 / ROW_RATE, lv)
		p_rx += pop * pop * DispatchSounds.POP_LEN / (2.0 * POP_FRAME)
	var rx_db := log(maxf(p_rx, 1e-20)) * E_DB + CAL
	var gate := voice_gate(o, u) if not bands.is_empty() else 0.0
	var key := carrier_key(o, u)
	var row := int(round(t * ROW_RATE))
	var cols := _columns()
	var ifg: PackedFloat32Array = cols["if"]
	var heard: PackedFloat32Array = cols["voice"]
	var at_band: PackedFloat32Array = cols["band"]
	var spk: PackedFloat32Array = cols["speckle"]
	var whole := bands.size() == AudioFeatures.BAND_COUNT
	var mid := COLS / 2
	for c in COLS:
		# one mix a cell: the floor's speckle, the band's, and the voice's give from its parts
		var h := (row * 73856093) ^ (c * 19349663)
		h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
		h = h ^ (h >> 16)
		var p := exp((FLOOR_DB + spk[h & SPECKLE_MASK]) * DB_E) + exp((rx_db + ifg[c] + spk[(h >> 12) & SPECKLE_MASK]) * DB_E)
		var w := heard[c] * gate
		if w > 0.0:
			var b := 0.0
			if whole:
				var x := at_band[c]
				var i := int(x)
				b = lerpf(bands[i], bands[mini(i + 1, AudioFeatures.BAND_COUNT - 1)], x - float(i))
			else:
				b = band_at(bands, absf(freq_of(c)))
			p += exp((b * AudioFeatures.DB_FLOOR - AudioFeatures.DB_FLOOR + VOICE_DB) * DB_E) * w \
				* (0.75 + 0.5 * float((h >> 24) & 255) / 255.0)
		var off := absi(c - mid)
		if key > 0.0 and off <= 2:
			p += exp((CARRIER_DB + (0.0 if off == 0 else float(CARRIER_SIDE[off - 1]))) * DB_E) * key
		out[c] = clampf((log(p) * E_DB - DB_LOW) / (DB_HIGH - DB_LOW), 0.0, 1.0)
	return out


## How much of the heard audio is the receiver's voice at show time [param t] ([method voice_gate]; 0 with none on it).
static func heard_at(t: float, open: Array) -> float:
	for s in open:
		if float(s["t"]) <= t and t < float(s["t1"]):
			return voice_gate(s, t - float(s["t"]))
	return 0.0


## Column [param c]'s frequency, off the carrier (Hz): the middle column 0, the edges half of [constant SPAN] either side.
static func freq_of(c: int) -> float:
	return (float(c) - float(COLS / 2)) * SPAN / float(COLS - 1)


## The receiver's filter at [param f] Hz off the carrier (dB): flat, sagging a little toward its edge, rolled off past it.
static func if_gain(f: float) -> float:
	var a := absf(f)
	if a <= IF_FLAT:
		return IF_SAG * pow(a / IF_FLAT, 4.0)
	var w := clampf((a - IF_FLAT) / (IF_EDGE - IF_FLAT), 0.0, 1.0)
	return lerpf(IF_SAG, IF_OUT, 0.5 - 0.5 * cos(PI * w))


## The loudest pop [DispatchSounds] plays in the [param span] seconds from [param u] into stretch [param o] at its
## level [param lv] (full scale; 0 for none) - its own slots and draws, so what is seen is what is heard.
static func pop_in(o: Dictionary, u: float, span: float, lv: float) -> float:
	var seed := int(o.get("seed", 0))
	var p := DispatchSounds.POP_RATE * DispatchSounds.POP_SLOT * lv
	var most := 0.0
	for slot in range(int(floor(u / DispatchSounds.POP_SLOT)), int(floor((u + span) / DispatchSounds.POP_SLOT))):
		if DispatchSounds.hash01(seed, slot) < p:
			most = maxf(most, DispatchSounds.POP * lerpf(0.3, 1.0, DispatchSounds.hash01(seed + 7, slot)))
	return most


## How much of the heard audio is the receiver's voice [param u] seconds into stretch [param o] (0-1): 1 round each of its
## words ([constant VOICE_IN] before, [constant VOICE_OUT] after), eased, nothing between them or with no voice on it.
static func voice_gate(o: Dictionary, u: float) -> float:
	var g := 0.0
	for w in o.get("words", []):
		var a := float((w as Array)[0]) - VOICE_IN
		var b := float((w as Array)[1]) + VOICE_OUT
		if u > a - VOICE_IN and u < b + VOICE_OUT:
			g = maxf(g, clampf((u - a) / VOICE_IN + 1.0, 0.0, 1.0) * clampf((b - u) / VOICE_OUT + 1.0, 0.0, 1.0))
	return smoothstep(0.0, 1.0, g)


## How far up the station's carrier is [param u] seconds into stretch [param o] (0-1): through each of its voice's turns
## (`under`), eased over [constant CARRIER_EASE] at each end.
static func carrier_key(o: Dictionary, u: float) -> float:
	var k := 0.0
	for s in o.get("under", []):
		var a := float((s as Array)[0])
		var b := float((s as Array)[1])
		k = maxf(k, clampf((u - a) / CARRIER_EASE, 0.0, 1.0) * clampf((b - u) / CARRIER_EASE, 0.0, 1.0))
	return smoothstep(0.0, 1.0, k)


## [param bands] ([constant AudioFeatures.BAND_COUNT] log-spaced, [constant AudioFeatures.FREQ_MIN] to [constant AudioFeatures.FREQ_MAX])
## read at [param hz], between the two bands round it.
static func band_at(bands: PackedFloat32Array, hz: float) -> float:
	var n := bands.size()
	if n == 0:
		return 0.0
	var x := float(n) * log(hz / AudioFeatures.FREQ_MIN) / log(AudioFeatures.FREQ_MAX / AudioFeatures.FREQ_MIN) - 0.5
	var i := clampi(int(floor(x)), 0, n - 1)
	var j := mini(i + 1, n - 1)
	return lerpf(bands[i], bands[j], clampf(x - float(i), 0.0, 1.0))


## The waterfall's palette ([constant PALETTE]) as 256 colors, RGBA8.
static func palette() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256 * 4)
	for i in 256:
		var x := float(i) / 255.0
		var col: Color = (PALETTE[0] as Array)[1]
		for k in range(1, PALETTE.size()):
			var lo: Array = PALETTE[k - 1]
			var hi: Array = PALETTE[k]
			if x <= float(hi[0]):
				col = (lo[1] as Color).lerp(hi[1], (x - float(lo[0])) / (float(hi[0]) - float(lo[0])))
				break
		out[i * 4] = col.r8
		out[i * 4 + 1] = col.g8
		out[i * 4 + 2] = col.b8
		out[i * 4 + 3] = 255
	return out


## What each column keeps from row to row, made once: the receiver's filter there (dB), how much of a voice's bands it
## shows (eased in from [constant VOICE_LOW], out to [constant VOICE_HIGH]), where it reads them (a band's index and its
## share of the next); and a noise's power in a cell as an FFT reads it, in dB about its mean (an exponential draw), for a
## cell's number of [constant SPECKLE].
static func _columns() -> Dictionary:
	if not _cols.is_empty():
		return _cols
	var ifg := PackedFloat32Array()
	var heard := PackedFloat32Array()
	var at_band := PackedFloat32Array()
	var n := float(AudioFeatures.BAND_COUNT)
	for c in COLS:
		var a := absf(freq_of(c))
		ifg.append(if_gain(a))
		heard.append(smoothstep(VOICE_LOW, VOICE_LOW * 2.0, a) * (1.0 - smoothstep(VOICE_TOP, VOICE_HIGH, a)))
		var x := n * log(maxf(a, 1.0) / AudioFeatures.FREQ_MIN) / log(AudioFeatures.FREQ_MAX / AudioFeatures.FREQ_MIN) - 0.5
		at_band.append(clampf(x, 0.0, n - 1.0))
	var spk := PackedFloat32Array()
	for k in SPECKLE:
		spk.append(log(-log((float(k) + 0.5) / float(SPECKLE))) * E_DB)
	_cols = {"if": ifg, "voice": heard, "band": at_band, "speckle": spk}
	return _cols


## The whole waterfall up to row [param to] made again on a worker ([method _made]), from what the receiver is open on
## ([param open]) and the bands kept for its rows; asked while one runs, it waits for that one, which is then stale.
func _refill(to: int, open: Array, powered: bool) -> void:
	var heard := {}
	for r in range(to - ROWS + 1, to + 1):
		if _heard.has(r):
			heard[r] = _heard[r]
	var job := {"to": to, "open": open.duplicate(true), "heard": heard, "powered": powered}
	if _task >= 0:
		_next = job
		return
	_start(job)


func _start(job: Dictionary) -> void:
	var box := {"to": int(job["to"])}
	var lut := _lut
	_box = box
	_task = WorkerThreadPool.add_task(func() -> void:
		box["image"] = _made(int(job["to"]), job["open"], job["heard"], bool(job["powered"]), lut), false, "the SDR's waterfall")


## The refill in, where it is done (or waited for, [param wait]): laid under the rows made here since it was asked for,
## unless a newer one waits, which is started. True where the waterfall changed.
func _land(wait := false) -> bool:
	if _task < 0 or not (wait or WorkerThreadPool.is_task_completed(_task)):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var made: Image = _box.get("image")
	var landed := false
	if made != null and _next.is_empty():
		for r in range(maxi(int(_box["to"]) + 1, head - ROWS + 1), head + 1):
			made.blit_rect(image, Rect2i(0, row_y(r), COLS, 1), Vector2i(0, row_y(r)))
		image = made
		texture.update(image)
		landed = true
	if not _next.is_empty():
		var job := _next
		_next = {}
		_start(job)
	return landed


## The waterfall's [constant ROWS] rows up to row [param to], each in its place round the ring, in [param lut]'s colors: a
## worker's, touching nothing but what it is handed.
static func _made(to: int, open: Array, heard: Dictionary, powered: bool, lut: PackedByteArray) -> Image:
	var px := PackedByteArray()
	px.resize(COLS * ROWS * 4)
	var none := PackedFloat32Array()
	for r in range(to - ROWS + 1, to + 1):
		var levels := row_at(float(r) / ROW_RATE, open, heard.get(r, none), powered)
		var base := row_y(r) * COLS * 4
		for c in COLS:
			var k := int(levels[c] * 255.0) * 4
			px[base + c * 4] = lut[k]
			px[base + c * 4 + 1] = lut[k + 1]
			px[base + c * 4 + 2] = lut[k + 2]
			px[base + c * 4 + 3] = 255
	return Image.create_from_data(COLS, ROWS, false, Image.FORMAT_RGBA8, px)


## Row [param r]'s heard [param bands] kept, so it is made again with its voice; the farthest from it let go past
## [constant HEARD_MOST].
func _keep(r: int, bands: PackedFloat32Array) -> void:
	_heard[r] = bands
	if _heard.size() > HEARD_MOST:
		for k in _heard.keys():
			if absi(int(k) - r) > HEARD_MOST / 2:
				_heard.erase(k)


## Row [param r]'s [param levels] in the palette's colors, laid into the ring.
func _lay(r: int, levels: PackedFloat32Array) -> void:
	var px := PackedByteArray()
	px.resize(COLS * 4)
	for c in COLS:
		var k := int(levels[c] * 255.0) * 4
		px[c * 4] = _lut[k]
		px[c * 4 + 1] = _lut[k + 1]
		px[c * 4 + 2] = _lut[k + 2]
		px[c * 4 + 3] = 255
	_line.set_data(COLS, 1, false, Image.FORMAT_RGBA8, px)
	image.blit_rect(_line, Rect2i(0, 0, COLS, 1), Vector2i(0, row_y(r)))


## The waterfall empty: the screen's black, as the program shows before its first row.
func _blank() -> void:
	image.fill(Color8(_lut[0], _lut[1], _lut[2]))

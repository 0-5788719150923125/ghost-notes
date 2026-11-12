extends RefCounted
class_name Boids

## Boids - a flock that decides together, over packed arrays and a uniform grid hash.
##
## Local rules between moving neighbors, where a shape decided by consensus comes from ([Primitives]' forces are
## field-like, and [Swarm] is a scalar field on a fixed lattice).
##
## The hash: birds are bucketed into a uniform grid whose cell edge is exactly 2 x [member radius], so every neighbor
## within the perception radius lies in the 2x2x2 block of cells starting at floor((p - radius - origin) / cell). The
## bucketing is a counting sort into two packed int arrays ([member _start], one offset per cell, and [member _items],
## the bird indices in cell order), rebuilt every tick: O(n + cells), no allocation.
##
## Three bounds keep a dense flock from going quadratic:
##   [member scan_cap]     - how many candidates a bird may examine before it stops.
##   [member k_cap]        - how many neighbors a bird may be influenced by (the k-nearest cap real starlings appear
##                           to use, about seven).
##   [member query_stride] - re-query neighbors for only every s-th bird each tick, reusing the stored steering
##                           directions in between (heading is low-frequency, so 12 Hz instead of 25 Hz is invisible).
## The stored steering vectors are unit directions, so the caller can re-weight cohesion against alignment every frame.
##
## Alarm is a scalar per bird that spreads by contact only. A bird the hawk passes gets 1.0; every tick a bird takes
## the maximum alarm among the neighbors it queried times [member alarm_transfer], or its own decayed value,
## whichever is larger: a front advancing one perception radius per tick, two to four times faster than the birds fly,
## so a strike reads as a wave. It is double-buffered so the front is symmetric.
##
## Bank is computed here because only the solver knows the acceleration: the bank angle is atan of the lateral
## acceleration, with a traveling plane wave in roll on top ([member wave_amp]). The renderer turns roll into how much
## wing area faces the lens.
##
## Nothing in here is audio-aware and nothing draws. The caller sets the weights and reads the arrays.

# ---------------------------------------------------------------------------------
# World and perception. Set these BEFORE calling build().
# ---------------------------------------------------------------------------------

## Half-extents of the box the flock lives in, in unit-fraction space. May be widened after [method build] (see
## [member ext_max]).
var ext := Vector3(0.78, 0.44, 0.62)

## The largest box [method build] must lay a neighbor grid for. Set it before build when the walls will move outward
## later: the grid's dimensions are fixed there, and a bird outside it has every cell index clamped to the rim, so its
## neighbor queries stop working. Zero means the same as `ext`.
var ext_max := Vector3.ZERO
## Perception radius. The grid cell edge is twice this, which reduces the neighbor search to eight cells.
var radius := 0.032
## Below this, birds actively push apart. Kept well under [member radius] so separation is a personal-space rule, not
## a cohesion term with the sign flipped.
var sep_radius := 0.013
## Candidates a bird may examine per query (bounds work in a dense knot).
var scan_cap := 22
## Neighbors a bird may be influenced by (the k-nearest cap).
var k_cap := 9
## Re-query one bird in this many per tick; 1 = every bird, every tick.
var query_stride := 1

# ---------------------------------------------------------------------------------
# Steering. The caller rewrites these every tick - they ARE the audio mapping.
# ---------------------------------------------------------------------------------
var w_sep := 1.5
var w_coh := 0.8
var w_ali := 1.0
var w_roost := 0.45
## Where the flock wants to be. Drifting this is how the flock is kept in frame.
var roost := Vector3.ZERO
## A constant vertical bias on the air itself (negative = rising): weather, not a per-bird force.
var thermal := 0.0
var speed_min := 0.15
var speed_max := 0.33
## Maximum acceleration, which caps the turn rate: a bird at speed s turning with acceleration a sweeps a/s radians a
## second.
var accel_max := 1.5

## The predator. When on, birds inside [member hawk_radius] are pushed hard and alarmed.
var hawk_on := false
var hawk := Vector3.ZERO
var hawk_radius := 0.11
var hawk_push := 7.0

## Alarm decay time constant, neighbor transfer coefficient, and how much alarm lifts a bird's speed.
var alarm_tau := 1.1
var alarm_transfer := 0.87
var alarm_speed := 0.4

## Roll: gain from lateral acceleration, and how fast the roll itself eases toward target.
var bank_gain := 2.6
var bank_rate := 7.0
## The traveling roll wave: unit direction, spatial frequency (radians per unit),
## temporal frequency (radians per second), amplitude (radians), and a phase offset.
var wave_dir := Vector3(1, 0, 0)
var wave_k := 9.0
var wave_w := 6.0
var wave_amp := 0.45
var wave_phase := 0.0

## Wingbeat rate range, sampled per bird at build time so the flock's flicker is asynchronous.
var flap_lo := 7.0
var flap_hi := 12.0

# ---------------------------------------------------------------------------------
# State. Public, because the renderer reads it directly - there is no per-bird object.
# ---------------------------------------------------------------------------------
var n := 0
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var pz := PackedFloat32Array()
## Positions at the start of the last tick, so a renderer running faster than the sim can interpolate.
var qx := PackedFloat32Array()
var qy := PackedFloat32Array()
var qz := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var vz := PackedFloat32Array()
var alarm := PackedFloat32Array()
var bank := PackedFloat32Array()
var flap := PackedFloat32Array()
## Simulated seconds, for the roll wave. Independent of frame rate by construction.
var t := 0.0

var _flap_rate := PackedFloat32Array()
var _alarm_next := PackedFloat32Array()

# Stored steering directions (unit), refreshed on a bird's query tick.
var _sx := PackedFloat32Array()
var _sy := PackedFloat32Array()
var _sz := PackedFloat32Array()
var _cx := PackedFloat32Array()
var _cy := PackedFloat32Array()
var _cz := PackedFloat32Array()
var _ax := PackedFloat32Array()
var _ay := PackedFloat32Array()
var _az := PackedFloat32Array()
var _na := PackedFloat32Array()          # max neighbor alarm seen at the last query

# The hash.
var _cell := 0.064
var _inv := 15.625
var _org := Vector3.ZERO
var _gx := 1
var _gy := 1
var _gz := 1
var _start := PackedInt32Array()         # size cells+1
var _counts := PackedInt32Array()        # size cells (count pass, then scatter cursor)
var _items := PackedInt32Array()         # size n
var _cellof := PackedInt32Array()        # size n
var _gen := 0


## Seed the flock. Set the world fields first - the grid is sized from them here.
func build(count: int, rng: RandomNumberGenerator) -> void:
	n = maxi(1, count)
	px.resize(n); py.resize(n); pz.resize(n)
	qx.resize(n); qy.resize(n); qz.resize(n)
	vx.resize(n); vy.resize(n); vz.resize(n)
	alarm.resize(n); bank.resize(n); flap.resize(n)
	_flap_rate.resize(n); _alarm_next.resize(n)
	_sx.resize(n); _sy.resize(n); _sz.resize(n)
	_cx.resize(n); _cy.resize(n); _cz.resize(n)
	_ax.resize(n); _ay.resize(n); _az.resize(n)
	_na.resize(n)
	_items.resize(n)
	_cellof.resize(n)

	_cell = maxf(0.004, radius * 2.0)
	_inv = 1.0 / _cell
	# Two cells of margin below the box, so the block base index of a bird on the low face is non-negative and the hot
	# path needs no clamp.
	var gext := Vector3(maxf(ext.x, ext_max.x), maxf(ext.y, ext_max.y), maxf(ext.z, ext_max.z))
	_org = Vector3(-gext.x, -gext.y, -gext.z) - Vector3(_cell, _cell, _cell) * 2.0
	_gx = maxi(1, int(2.0 * gext.x * _inv) + 5)
	_gy = maxi(1, int(2.0 * gext.y * _inv) + 5)
	_gz = maxi(1, int(2.0 * gext.z * _inv) + 5)
	var cells := _gx * _gy * _gz
	_start.resize(cells + 1)
	_counts.resize(cells)

	# The flock starts as a loose blob already in motion, not a cube of stationary dots (the first drawn frame is
	# after the Director's pre-warm).
	var lead := Vector3(cos(rng.randf() * TAU), rng.randf_range(-0.2, 0.2),
		sin(rng.randf() * TAU)).normalized()
	for i in n:
		var u := rng.randf()
		var r := pow(u, 0.34)                     # denser toward the middle
		var th := rng.randf() * TAU
		var ph := acos(clampf(rng.randf_range(-1.0, 1.0), -1.0, 1.0))
		px[i] = clampf(r * sin(ph) * cos(th) * ext.x * 0.42, -ext.x, ext.x)
		py[i] = clampf(r * cos(ph) * ext.y * 0.38, -ext.y, ext.y)
		pz[i] = clampf(r * sin(ph) * sin(th) * ext.z * 0.42, -ext.z, ext.z)
		qx[i] = px[i]
		qy[i] = py[i]
		qz[i] = pz[i]
		var sp := rng.randf_range(speed_min, speed_max)
		var d := (lead + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.30, 0.30),
			rng.randf_range(-0.45, 0.45))).normalized()
		vx[i] = d.x * sp
		vy[i] = d.y * sp
		vz[i] = d.z * sp
		alarm[i] = 0.0
		bank[i] = 0.0
		flap[i] = rng.randf() * TAU
		_flap_rate[i] = rng.randf_range(flap_lo, flap_hi)
		_sx[i] = 0.0; _sy[i] = 0.0; _sz[i] = 0.0
		_cx[i] = 0.0; _cy[i] = 0.0; _cz[i] = 0.0
		_ax[i] = d.x; _ay[i] = d.y; _az[i] = d.z
		_na[i] = 0.0


## One generation, at a fixed timestep. Everything above is read; everything under
## "State" is written.
func step(dt: float) -> void:
	if n <= 0:
		return
	t += dt
	qx = px.duplicate()
	qy = py.duplicate()
	qz = pz.duplicate()
	_hash()

	var r2 := radius * radius
	var s2 := sep_radius * sep_radius
	var keep := exp(-dt / maxf(0.05, alarm_tau))
	var stride := maxi(1, query_stride)
	var gen := _gen
	var wdx := wave_dir.x
	var wdy := wave_dir.y
	var wdz := wave_dir.z
	var wph := wave_phase - wave_w * t
	var hr2 := hawk_radius * hawk_radius
	var row := _gx
	var slab := _gx * _gy

	for i in n:
		var pix := px[i]
		var piy := py[i]
		var piz := pz[i]

		# ---- neighbors (only on this bird's query tick) --------------------------
		if stride == 1 or ((i + gen) % stride) == 0:
			var bx := int((pix - radius - _org.x) * _inv)
			var by := int((piy - radius - _org.y) * _inv)
			var bz := int((piz - radius - _org.z) * _inv)
			bx = clampi(bx, 0, _gx - 2)
			by = clampi(by, 0, _gy - 2)
			bz = clampi(bz, 0, _gz - 2)
			var sepx := 0.0
			var sepy := 0.0
			var sepz := 0.0
			var cohx := 0.0
			var cohy := 0.0
			var cohz := 0.0
			var alix := 0.0
			var aliy := 0.0
			var aliz := 0.0
			var amax := 0.0
			var cnt := 0
			var scanned := 0
			var full := false
			for dz in 2:
				if full:
					break
				var zb := (bz + dz) * slab
				for dy in 2:
					if full:
						break
					var yb := zb + (by + dy) * row
					for dx in 2:
						if full:
							break
						var c := yb + bx + dx
						var e := _start[c + 1]
						for k in range(_start[c], e):
							if scanned >= scan_cap or cnt >= k_cap:
								full = true
								break
							var j := _items[k]
							if j == i:
								continue
							scanned += 1
							var ox := px[j] - pix
							var oy := py[j] - piy
							var oz := pz[j] - piz
							var d2 := ox * ox + oy * oy + oz * oz
							if d2 > r2 or d2 < 1e-12:
								continue
							cnt += 1
							cohx += ox
							cohy += oy
							cohz += oz
							alix += vx[j]
							aliy += vy[j]
							aliz += vz[j]
							if d2 < s2:
								# 1/d falloff, not 1/d^2: the squared form makes a near-contact pair explode out of the flock.
								var w := (sep_radius / sqrt(d2)) - 1.0
								sepx -= ox * w
								sepy -= oy * w
								sepz -= oz * w
							var aj := alarm[j]
							if aj > amax:
								amax = aj
			_na[i] = amax
			var m := sqrt(sepx * sepx + sepy * sepy + sepz * sepz)
			if m > 1e-9:
				_sx[i] = sepx / m
				_sy[i] = sepy / m
				_sz[i] = sepz / m
			else:
				_sx[i] = 0.0
				_sy[i] = 0.0
				_sz[i] = 0.0
			if cnt > 0:
				m = sqrt(cohx * cohx + cohy * cohy + cohz * cohz)
				if m > 1e-9:
					_cx[i] = cohx / m
					_cy[i] = cohy / m
					_cz[i] = cohz / m
				else:
					_cx[i] = 0.0
					_cy[i] = 0.0
					_cz[i] = 0.0
				m = sqrt(alix * alix + aliy * aliy + aliz * aliz)
				if m > 1e-9:
					_ax[i] = alix / m
					_ay[i] = aliy / m
					_az[i] = aliz / m
			else:
				_cx[i] = 0.0
				_cy[i] = 0.0
				_cz[i] = 0.0

		# ---- alarm ---------------------------------------------------------------
		var al := maxf(alarm[i] * keep, _na[i] * alarm_transfer)

		# ---- desired direction ----------------------------------------------------
		var dsx := _sx[i] * w_sep + _cx[i] * w_coh + _ax[i] * w_ali
		var dsy := _sy[i] * w_sep + _cy[i] * w_coh + _ay[i] * w_ali
		var dsz := _sz[i] * w_sep + _cz[i] * w_coh + _az[i] * w_ali
		var rx := roost.x - pix
		var ry := roost.y - piy
		var rz := roost.z - piz
		var rm := sqrt(rx * rx + ry * ry + rz * rz)
		if rm > 1e-6:
			dsx += rx / rm * w_roost
			dsy += ry / rm * w_roost
			dsz += rz / rm * w_roost
		dsy += thermal
		if hawk_on:
			var hx := pix - hawk.x
			var hy := piy - hawk.y
			var hz := piz - hawk.z
			var hd2 := hx * hx + hy * hy + hz * hz
			if hd2 < hr2 and hd2 > 1e-9:
				var hm := sqrt(hd2)
				var g := hawk_push * (1.0 - hm / hawk_radius)
				dsx += hx / hm * g
				dsy += hy / hm * g
				dsz += hz / hm * g
				al = 1.0
		_alarm_next[i] = al

		# ---- integrate -------------------------------------------------------------
		var dm := sqrt(dsx * dsx + dsy * dsy + dsz * dsz)
		var target := clampf(speed_max * (1.0 + alarm_speed * al), speed_min, speed_max * 2.0)
		var vix := vx[i]
		var viy := vy[i]
		var viz := vz[i]
		var acx := 0.0
		var acy := 0.0
		var acz := 0.0
		if dm > 1e-9:
			acx = dsx / dm * target - vix
			acy = dsy / dm * target - viy
			acz = dsz / dm * target - viz
			var am := sqrt(acx * acx + acy * acy + acz * acz)
			var cap := accel_max * (1.0 + 1.2 * al)
			if am > cap:
				var f := cap / am
				acx *= f
				acy *= f
				acz *= f
		vix += acx * dt
		viy += acy * dt
		viz += acz * dt
		var sp := sqrt(vix * vix + viy * viy + viz * viz)
		if sp < 1e-9:
			vix = 0.001
			sp = 0.001
		var lo := speed_min
		var hi := maxf(lo + 0.001, target)
		if sp < lo:
			var f2 := lo / sp
			vix *= f2; viy *= f2; viz *= f2
			sp = lo
		elif sp > hi:
			var f3 := hi / sp
			vix *= f3; viy *= f3; viz *= f3
			sp = hi
		vx[i] = vix
		vy[i] = viy
		vz[i] = viz
		var nx := pix + vix * dt
		var ny := piy + viy * dt
		var nz := piz + viz * dt
		# Hard box, softly: a hawk pass can throw a bird past the wall, and outside the grid it would have no neighbors.
		if nx < -ext.x:
			nx = -ext.x
			vx[i] = absf(vix) * 0.4
		elif nx > ext.x:
			nx = ext.x
			vx[i] = -absf(vix) * 0.4
		if ny < -ext.y:
			ny = -ext.y
			vy[i] = absf(viy) * 0.4
		elif ny > ext.y:
			ny = ext.y
			vy[i] = -absf(viy) * 0.4
		if nz < -ext.z:
			nz = -ext.z
			vz[i] = absf(viz) * 0.4
		elif nz > ext.z:
			nz = ext.z
			vz[i] = -absf(viz) * 0.4
		px[i] = nx
		py[i] = ny
		pz[i] = nz

		# ---- roll ------------------------------------------------------------------
		# Lateral acceleration relative to the heading, signed by which side of the
		# heading it falls on, is exactly the quantity an aircraft banks into.
		var ix := vix / sp
		var iy := viy / sp
		var iz := viz / sp
		var adotf := acx * ix + acy * iy + acz * iz
		var lx := acx - ix * adotf
		var ly := acy - iy * adotf
		var lz := acz - iz * adotf
		# right = forward x world-up, world-up = (0,-1,0) in this y-down space
		var rgx := iz
		var rgz := -ix
		var rgm := sqrt(rgx * rgx + rgz * rgz)
		var signed := 0.0
		if rgm > 1e-6:
			signed = (lx * rgx + lz * rgz) / rgm
		var tgt := atan(signed * bank_gain)
		tgt += wave_amp * sin(wave_k * (nx * wdx + ny * wdy + nz * wdz) + wph)
		bank[i] = lerpf(bank[i], tgt, 1.0 - exp(-bank_rate * dt))

		# ---- wingbeat ---------------------------------------------------------------
		flap[i] = fposmod(flap[i] + _flap_rate[i] * (1.0 + 0.55 * al) * dt, TAU)

	var swap := alarm
	alarm = _alarm_next
	_alarm_next = swap
	_gen += 1


## Rebuild the uniform grid: a counting sort of every bird into its cell, in two passes
## over the birds and one over the cells. No allocation, no Dictionary.
func _hash() -> void:
	_counts.fill(0)
	var row := _gx
	var slab := _gx * _gy
	for i in n:
		var cx := clampi(int((px[i] - _org.x) * _inv), 0, _gx - 1)
		var cy := clampi(int((py[i] - _org.y) * _inv), 0, _gy - 1)
		var cz := clampi(int((pz[i] - _org.z) * _inv), 0, _gz - 1)
		var c := cz * slab + cy * row + cx
		_cellof[i] = c
		_counts[c] += 1
	var cells := _counts.size()
	var run := 0
	_start[0] = 0
	for c in cells:
		run += _counts[c]
		_start[c + 1] = run
	_counts.fill(0)
	for i in n:
		var c2 := _cellof[i]
		_items[_start[c2] + _counts[c2]] = i
		_counts[c2] += 1

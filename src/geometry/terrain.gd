extends RefCounted
class_name Terrain

## Terrain - a heightfield assembled from [Field]s and drawn through a [Lens3D].
##
## A type (rolling hills, mountains, valleys, fissured canyon, islands, banded mesa) selects a recipe of [Field]s that becomes a
## height grid, sampled once at build into world vertices and per-vertex colors from a [Palette] plus a fine surface-texture
## field and slope shading. Each frame the grid is projected and depth-sorted. It exposes height(wx, wz) and a surface normal so
## other scenes can stand things on it.

const RES := 112                 # grid resolution (RES x RES vertices)
const KNEE := 0.72               # height above which the ceiling turns soft
# Water. Both are fractions of this map's deepest point (see `_wdepth`), not of the datum, so a shallow pond still reads as a full body of water.
const WATER_OPAQUE := 0.45       # depth at which the bed stops showing through
const WATER_SURF := 0.16         # width of the bright surf band just off the waterline

var res := RES
var half := 3.0                  # world half-extent in x and z
var relief := 1.4                # vertical world scale
var water := 0.0                 # water plane world height (0 = none)
var type := "hills"
var palette: Palette
var hgrid := PackedFloat32Array()   # heights 0..1
var _world := PackedVector3Array()  # world-space vertices
var _vcol: PackedColorArray         # base per-vertex color (palette + texture + slope)
var _vnorm := PackedVector3Array()  # per-vertex surface normal (for the moving directional light)

# Cinematic area light + cast shadows: a low directional key light whose azimuth drifts, so the mountains cast long sweeping
# shadows. The shadow map is per-vertex and refreshed a few rows per frame (never a full-grid recompute).
var _light_dir := Vector3(0.55, 0.5, 0.35).normalized()   # world direction TOWARD the key light
var _cast := PackedFloat32Array()   # per-vertex cast-shadow factor SHOWN (eased toward _cast_target)
var _cast_target := PackedFloat32Array()   # the FEATHERED march result, refreshed a few rows per frame
var _cast_raw := PackedFloat32Array()      # the raw per-vertex march, before the spatial feather
var _cast_blur := PackedFloat32Array()     # the raw march, blurred horizontally (the separable pass)
# Slow per-vertex shading, cached and refreshed a slice at a time - see _refresh_slow.
var _cloud_c := PackedFloat32Array()       # drifting cloud-shadow factor
var _occ_c := PackedFloat32Array()         # prop shadow-map factor (1 where there is no field)
var _slow_cursor := 0
var _shadow_row := 0                 # incremental shadow-refresh cursor (row being recomputed)
const SHADOW_MIN := 0.42            # ground brightness where fully in a mountain's cast shadow
var _fog_level := -1.0               # world height below which valley fog pools (< min = no fog)
var _fog_col := Color(0.62, 0.66, 0.72)
var _wdepth := 0.0                   # deepest point of the SMOOTHED water column (0 = the map is dry)
var _wsub := PackedFloat32Array()    # per-vertex water column, smoothed (see _measure_water)

# Biome color sets [h, s, v] for grass / dirt / low rock / high rock / snow / sand / water, chosen by height + slope + moisture.
const CLIMATES := {
	"temperate": {"grass": [0.28, 0.55, 0.50], "dirt": [0.09, 0.50, 0.42],
		"rock_lo": [0.07, 0.22, 0.42], "rock_hi": [0.0, 0.05, 0.55], "snow": [0.58, 0.05, 0.86],
		"sand": [0.11, 0.35, 0.66], "water": [0.58, 0.62, 0.46]},
	"arid": {"grass": [0.18, 0.45, 0.46], "dirt": [0.08, 0.55, 0.50],
		"rock_lo": [0.06, 0.52, 0.50], "rock_hi": [0.05, 0.22, 0.60], "snow": [0.10, 0.10, 0.80],
		"sand": [0.11, 0.45, 0.74], "water": [0.50, 0.45, 0.50]},
	"tundra": {"grass": [0.26, 0.24, 0.42], "dirt": [0.08, 0.30, 0.38],
		"rock_lo": [0.60, 0.08, 0.42], "rock_hi": [0.0, 0.03, 0.60], "snow": [0.60, 0.03, 0.92],
		"sand": [0.10, 0.16, 0.60], "water": [0.55, 0.40, 0.55]},
	"verdant": {"grass": [0.32, 0.62, 0.46], "dirt": [0.10, 0.48, 0.36],
		"rock_lo": [0.10, 0.28, 0.40], "rock_hi": [0.0, 0.05, 0.52], "snow": [0.55, 0.06, 0.84],
		"sand": [0.13, 0.40, 0.64], "water": [0.50, 0.60, 0.44]},
}

var _biome_on := false
var _c_grass := Color.WHITE
var _c_dirt := Color.WHITE
var _c_rock_lo := Color.WHITE
var _c_rock_hi := Color.WHITE
var _c_snow := Color.WHITE
var _c_sand := Color.WHITE
var _water_col := Color(0.1, 0.3, 0.5)


func build(rng: RandomNumberGenerator, type_: String, world_half := 3.0,
		relief_ := 1.4, pal: Palette = null, climate := "") -> void:
	type = type_
	half = world_half
	relief = relief_
	_biome_on = climate != ""
	if _biome_on:
		_setup_climate(climate, rng)
	else:
		palette = pal if pal != null else Palette.named("earth", rng)
		_water_col = palette.at(0.0)
	var height := _recipe(rng)
	# Regional relief: a very low-frequency field (well under 1, so a map spans two or three regions) that scales the heightfield's
	# deviation from its own mid-line: whole districts sit low and rolling while others rise into massifs.
	var regions := Field.make("fbm", rng.randi(), rng.randf_range(0.35, 0.65), 2)
	var region_depth := rng.randf_range(0.45, 0.85)
	# Surface texture: a coarse mottle plus a fine grain and a rocky ridged striation, combined.
	var mottle := Field.make("fbm", rng.randi(), 14.0, 4)
	var grain := Field.make("fbm", rng.randi(), 34.0, 3)
	var striate := Field.make("ridged", rng.randi(), 22.0, 3)
	var detail := Field.combine(Field.combine(mottle, "add", grain, 0.5), "add", striate, 0.4)
	var moist := Field.make("fbm", rng.randi(), 3.2, 4)        # wet (grass) vs dry (rock) regions
	hgrid.resize(res * res)
	_world.resize(res * res)
	_vnorm.resize(res * res)
	_cast.resize(res * res)
	_cast.fill(1.0)
	_vcol = PackedColorArray()
	_vcol.resize(res * res)
	# Sample the field into the grid (the only expensive pass; done once).
	for gy in res:
		for gx in res:
			var p := Vector2(float(gx) / float(res - 1) - 0.5, float(gy) / float(res - 1) - 0.5) * 2.0
			var h := height.at(p)
			# lerp toward the mid-line where the region is low, away where high
			var amp := 1.0 - region_depth * (1.0 - regions.at(p))
			hgrid[gy * res + gx] = 0.5 + (h - 0.5) * amp
	_smooth(1)        # a single pass: knock down grid-scale aliasing but KEEP the recipe's detail
	# Micro-relief: fine geometric detail over the whole surface (a coarse roll, a ridged grain, a fine crinkle), tiled across the
	# terrain and added after the smoothing pass so it survives. It becomes real height, so the slope shading and normals keep crisp
	# bumps under a close camera.
	var micro := Field.combine(
		Field.combine(Field.make("fbm", rng.randi(), 9.0, 5), "add",
			Field.make("ridged", rng.randi(), 19.0, 4), 0.7),
		"add", Field.make("fbm", rng.randi(), 42.0, 3), 0.4)
	var micro_amp := 0.09
	for gy in res:
		for gx in res:
			var i := gy * res + gx
			var p := Vector2(float(gx) / float(res - 1) - 0.5, float(gy) / float(res - 1) - 0.5) * 2.0
			hgrid[i] = _soft_ceiling(hgrid[i] + (micro.at(p) - 0.5) * micro_amp)
	for gy in res:
		for gx in res:
			var i := gy * res + gx
			var p := Vector2(float(gx) / float(res - 1) - 0.5, float(gy) / float(res - 1) - 0.5) * 2.0
			_world[i] = Vector3(p.x * half, (hgrid[i] - water) * relief, p.y * half)
	# Per-vertex color: palette by height, mottled by the detail field, shaded by slope.
	for gy in res:
		for gx in res:
			var i := gy * res + gx
			var p := Vector2(float(gx) / float(res - 1) - 0.5, float(gy) / float(res - 1) - 0.5) * 2.0
			var n := _normal(gx, gy)
			_vnorm[i] = n
			var slope := clampf(n.dot(Vector3(0, 1, 0)), 0.0, 1.0)     # 1 flat .. 0 cliff
			var tex := detail.at(p)
			if _biome_on:
				_vcol[i] = _biome(hgrid[i], slope, moist.at(p), tex)
				continue
			# Palette path (surreal climates): take the palette's interpolated color (smooth in RGB) and shade it by slope and surface
			# detail. Rebuilding it via from_hsv(c.h, ...) flips the hue wherever the RGB lerp crosses gray. The detail field still
			# shifts the band a little and grains the brightness.
			var c := palette.at(clampf(hgrid[i] + 0.18 * (tex - 0.5), 0.0, 1.0))
			var contour := 0.94 + 0.06 * sin(hgrid[i] * PI * 9.0)
			var shade := clampf((0.50 + 0.42 * slope + 0.40 * (tex - 0.5)) * contour, 0.14, 1.25)
			_vcol[i] = Color(c.r * shade, c.g * shade, c.b * shade, 1.0)
	# Valley fog pools a little above the lowest ground (or the water line); a tundra/arid palette gets a cooler, thinner fog.
	var lo := 1.0
	var hi := 0.0
	for hv in hgrid:
		lo = minf(lo, hv)
		hi = maxf(hi, hv)
	_fog_level = maxf(water, lo) + 0.11 * (hi - lo)
	_fog_col = Color(0.66, 0.70, 0.76) if _biome_on else Color(0.60, 0.62, 0.70)
	_measure_water()


## Work out whether this map has water at all, and how thick the column is at each vertex. Several recipes set a water level no
## ground on the map reaches (mountains, canyon and mesa are dry every time): a dry map renders no water at all, since the
## heightfield has no side skirt and the sheet would show as a flat apron.
##
## The column is smoothed, and the shading reads that rather than the raw depth: the micro-relief amplitude (0.09) is the same
## order as a shallow lake's depth, so raw depth made the water read as mottled noise. Blurring a field that is zero on land also
## tapers it to nothing at the shoreline (the shore feather). `_wdepth` is the max of the smoothed field, so the deepest point
## reaches full opacity and every ramp scales to this map.
func _measure_water() -> void:
	_wdepth = 0.0
	_wsub = PackedFloat32Array()
	if water <= 0.0:
		return
	var n := res * res
	var col := PackedFloat32Array()
	col.resize(n)
	var any := false
	for i in n:
		var s := water - hgrid[i]
		col[i] = s if s > 0.0 else 0.0
		any = any or s > 0.0
	if not any:
		return
	var tmp := PackedFloat32Array()
	tmp.resize(n)
	for _p in 4:
		for gy in res:
			for gx in res:
				var acc := 0.0
				var c := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = gx + dx
						var ny: int = gy + dy
						if nx >= 0 and nx < res and ny >= 0 and ny < res:
							acc += col[ny * res + nx]
							c += 1
				tmp[gy * res + gx] = acc / float(c)
		for i in n:
			col[i] = tmp[i]
	for i in n:
		_wdepth = maxf(_wdepth, col[i])
	if _wdepth <= 0.0:
		return
	_wsub = col


# Resolve a climate's material colors (jittered per seed).
func _setup_climate(name: String, rng: RandomNumberGenerator) -> void:
	var cl: Dictionary = CLIMATES.get(name, CLIMATES["temperate"])
	var jh := rng.randf_range(-0.025, 0.025)
	_c_grass = _hsv(cl.grass, jh, rng)
	_c_dirt = _hsv(cl.dirt, jh, rng)
	_c_rock_lo = _hsv(cl.rock_lo, jh, rng)
	_c_rock_hi = _hsv(cl.rock_hi, jh, rng)
	_c_snow = _hsv(cl.snow, jh, rng)
	_c_sand = _hsv(cl.sand, jh, rng)
	_water_col = _hsv(cl.water, jh, rng)


func _hsv(a: Array, jh: float, rng: RandomNumberGenerator) -> Color:
	return Color.from_hsv(fposmod(float(a[0]) + jh, 1.0),
		clampf(float(a[1]) * rng.randf_range(0.9, 1.1), 0.0, 1.0),
		clampf(float(a[2]) * rng.randf_range(0.92, 1.08), 0.0, 1.0))


# Pick a vertex color from elevation, slope, moisture and surface detail: green lowland grading to brown/gray rock on steeps and
# heights, snow on high flats, sand at the shore.
func _biome(h: float, slope: float, moist: float, det: float) -> Color:
	var t := clampf((h - water) / maxf(0.25, 1.0 - water), 0.0, 1.0)    # 0 shore .. 1 peak
	var ground := _c_grass.lerp(_c_dirt, clampf(0.45 - 0.7 * (moist - 0.5) + 0.5 * (det - 0.5), 0.0, 1.0))
	var rock := _c_rock_lo.lerp(_c_rock_hi, smoothstep(0.15, 0.9, t))
	var rocky := clampf((1.0 - slope) * 1.7 + smoothstep(0.5, 0.88, t) * 0.6, 0.0, 1.0)
	var c := ground.lerp(rock, rocky)
	c = c.lerp(_c_snow, smoothstep(0.80, 0.97, t) * clampf(slope * 1.3, 0.0, 1.0))
	c = c.lerp(_c_sand, (1.0 - smoothstep(0.0, 0.07, t)) * 0.7)
	# A whisper of height striation (a strong contour band reads as artificial topographic lines).
	var contour := 0.95 + 0.05 * sin(h * PI * 9.0)
	var sh := clampf((0.55 + 0.42 * slope + 0.32 * (det - 0.5)) * contour, 0.15, 1.25)
	return Color(c.r * sh, c.g * sh, c.b * sh, 1.0)


# A few box-blur passes over the height grid: removes high-frequency aliasing while peaks and valleys keep their large-scale shape.
func _smooth(passes: int) -> void:
	var tmp := PackedFloat32Array()
	tmp.resize(res * res)
	for _p in passes:
		for gy in res:
			for gx in res:
				var s := 0.0
				var c := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = gx + dx
						var ny: int = gy + dy
						if nx >= 0 and nx < res and ny >= 0 and ny < res:
							s += hgrid[ny * res + nx]
							c += 1
				tmp[gy * res + gx] = s / float(c)
		for i in res * res:
			hgrid[i] = tmp[i]


# Recipe: compose the height [Field] for each terrain type.
func _recipe(rng: RandomNumberGenerator) -> Field:
	var f := rng.randf_range(0.7, 1.05)
	match type:
		"mountains":
			water = 0.18
			relief = maxf(relief, 2.0)
			var base := Field.make("fbm", rng.randi(), f * 0.7).scale(0.45)
			var peaks := Field.make("ridged", rng.randi(), f * 1.5, 5).curve("smoothstep")
			var where := Field.make("fbm", rng.randi(), f * 0.5).curve("sigmoid", 5.0)
			return Field.combine(base.offset(0.18), "add", Field.combine(peaks, "mask", where, 1.0), 0.85)
		"valleys":
			water = 0.20
			var rolling := Field.make("fbm", rng.randi(), f).offset(0.30).scale(0.6)
			var rivers := Field.make("ridged", rng.randi(), f * 0.9, 4).inverted().curve("spike", 2.0)
			return Field.combine(rolling, "sub", rivers, 0.5)
		"canyon":
			water = 0.10
			relief = maxf(relief, 1.8)
			var plateau := Field.make("fbm", rng.randi(), f * 0.6).curve("smoothstep").scale(0.4).offset(0.5)
			var cracks := Field.make("cells", rng.randi(), f * 0.9).curve("spike", 3.0)
			return Field.combine(plateau, "sub", cracks, 0.7)
		"islands":
			water = 0.42
			var land := Field.make("fbm", rng.randi(), f * 1.1, 5)
			var bowl := Field.make("gradient", 0).scale(1.4).curve("smoothstep")   # center high
			return Field.combine(land, "mask", bowl, 1.0)
		"mesa":
			water = 0.12
			var bands := Field.make("fbm", rng.randi(), f * 0.8).strata(rng.randf_range(4.0, 7.0))
			var base := Field.make("fbm", rng.randi(), f * 0.5).scale(0.5).offset(0.25)
			return Field.combine(base, "add", bands, 0.4)
		_:  # rolling hills
			water = 0.0
			var warpf := Field.make("fbm", rng.randi(), f * 0.5)
			return Field.make("fbm", rng.randi(), f, 4).warp(warpf, 0.4).offset(0.05)


## A soft ceiling instead of a hard clamp: clampf(h, 0, 1) makes every peak that reaches the top a plateau at exactly the same
## altitude. This compresses the last stretch, so heights approach 1.0 asymptotically and each summit keeps its own height.
static func _soft_ceiling(h: float) -> float:
	if h <= KNEE:
		return maxf(h, 0.0)
	var over := (h - KNEE) / (1.0 - KNEE)
	return KNEE + (1.0 - KNEE) * (1.0 - exp(-over))


# World height (relief units, water-relative) at continuous world (wx, wz), bilinear.
func height_at(wx: float, wz: float) -> float:
	var gx := (wx / half * 0.5 + 0.5) * float(res - 1)
	var gy := (wz / half * 0.5 + 0.5) * float(res - 1)
	var x0 := clampi(int(floor(gx)), 0, res - 1)
	var y0 := clampi(int(floor(gy)), 0, res - 1)
	var x1 := mini(x0 + 1, res - 1)
	var y1 := mini(y0 + 1, res - 1)
	var fx := clampf(gx - float(x0), 0.0, 1.0)
	var fy := clampf(gy - float(y0), 0.0, 1.0)
	var h00 := hgrid[y0 * res + x0]
	var h10 := hgrid[y0 * res + x1]
	var h01 := hgrid[y1 * res + x0]
	var h11 := hgrid[y1 * res + x1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fy) - water


# Surface normal at grid cell (gx, gy), from central differences on the height grid.
func _normal(gx: int, gy: int) -> Vector3:
	var l := hgrid[gy * res + maxi(gx - 1, 0)]
	var r := hgrid[gy * res + mini(gx + 1, res - 1)]
	var d := hgrid[maxi(gy - 1, 0) * res + gx]
	var u := hgrid[mini(gy + 1, res - 1) * res + gx]
	var sx := (r - l) * relief * float(res) / (4.0 * half)
	var sz := (u - d) * relief * float(res) / (4.0 * half)
	return Vector3(-sx, 1.0, -sz).normalized()


func normal_world(wx: float, wz: float) -> Vector3:
	var gx := clampi(int((wx / half * 0.5 + 0.5) * float(res - 1)), 0, res - 1)
	var gy := clampi(int((wz / half * 0.5 + 0.5) * float(res - 1)), 0, res - 1)
	return _normal(gx, gy)


## The cast-shadow factor at a world XZ (1 = full sun, down to SHADOW_MIN inside a mountain's shadow), bilinearly sampled from
## the terrain's own shadow map, so a scene can darken props that stand where the terrain is already in shadow.
func shadow_at(wx: float, wz: float) -> float:
	if _cast.size() != res * res:
		return 1.0
	var gx := (wx / half * 0.5 + 0.5) * float(res - 1)
	var gy := (wz / half * 0.5 + 0.5) * float(res - 1)
	var x0 := clampi(int(floor(gx)), 0, res - 1)
	var y0 := clampi(int(floor(gy)), 0, res - 1)
	var x1 := mini(x0 + 1, res - 1)
	var y1 := mini(y0 + 1, res - 1)
	var fx := clampf(gx - float(x0), 0.0, 1.0)
	var fy := clampf(gy - float(y0), 0.0, 1.0)
	return lerpf(lerpf(_cast[y0 * res + x0], _cast[y0 * res + x1], fx),
		lerpf(_cast[y1 * res + x0], _cast[y1 * res + x1], fx), fy)


## Aim the key light. `az` is the azimuth (radians, drifts over time); `el` the elevation (kept low for long shadows). Call each
## frame from the scene with a slowly moving az.
func set_light(az: float, el := 0.5) -> void:
	_light_dir = Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az)).normalized()


## The world direction toward the key light (so a scene can shade its own props with the same light as the terrain).
func light_dir() -> Vector3:
	return _light_dir


## Refresh a few rows of the cast-shadow target each frame, then ease the shown shadow toward it. The easing keeps a cell from
## hard-flipping lit<->shadowed as the light drifts.
##
## The target is feathered across the lattice on the way in: the march itself (see [method _cast_at]) is a coarse 17-step walk
## over a bumpy heightfield, so neighboring vertices disagree by more than the surface does, and a shadow edge between two
## vertices is a staircase one quad wide. A separable 5-tap binomial over the refreshed band spreads an edge across about five
## vertices, which interpolation can resolve. It touches only the rows that changed.
func step_light(delta: float) -> void:
	var n := res * res
	if _cast.size() != n:
		_cast.resize(n)
		_cast.fill(1.0)
	if _cast_target.size() != n:
		_cast_target.resize(n)
		_cast_target.fill(1.0)
	if _cast_raw.size() != n:
		_cast_raw.resize(n)
		_cast_raw.fill(1.0)
		_cast_blur.resize(n)
		_cast_blur.fill(1.0)
	var rows := maxi(1, int(res / 16))            # a few rows per frame; whole target refreshed ~every 16
	var first := _shadow_row
	for _r in rows:
		var gy := _shadow_row
		for gx in res:
			_cast_raw[gy * res + gx] = _cast_at(gx, gy)
		_shadow_row = (_shadow_row + 1) % res
	# Feather the band that just changed, plus the two rows either side (their kernels reach in): a 5-tap binomial (1 4 6 4 1),
	# applied separably through `_cast_blur`. The worst neighbor-to-neighbor step falls from 84% of the lit-to-shadowed range to a
	# third. See tests/geometry/shadow_feather_check.gd.
	for k in range(-4, rows + 4):
		var gy := posmod(first + k, res)
		var y0 := gy * res
		for gx in res:
			_cast_blur[y0 + gx] = 0.0625 * _cast_raw[y0 + maxi(gx - 2, 0)] \
				+ 0.25 * _cast_raw[y0 + maxi(gx - 1, 0)] \
				+ 0.375 * _cast_raw[y0 + gx] \
				+ 0.25 * _cast_raw[y0 + mini(gx + 1, res - 1)] \
				+ 0.0625 * _cast_raw[y0 + mini(gx + 2, res - 1)]
	for k in range(-2, rows + 2):
		var gy := posmod(first + k, res)
		var y0 := gy * res
		var ym2 := maxi(gy - 2, 0) * res
		var ym1 := maxi(gy - 1, 0) * res
		var yp1 := mini(gy + 1, res - 1) * res
		var yp2 := mini(gy + 2, res - 1) * res
		for gx in res:
			_cast_target[y0 + gx] = 0.0625 * _cast_blur[ym2 + gx] + 0.25 * _cast_blur[ym1 + gx] \
				+ 0.375 * _cast_blur[y0 + gx] \
				+ 0.25 * _cast_blur[yp1 + gx] + 0.0625 * _cast_blur[yp2 + gx]
	var ease := 1.0 - exp(-3.0 * delta)           # smooth glide toward the target - no pop, no seam
	for i in n:
		_cast[i] = lerpf(_cast[i], _cast_target[i], ease)


# March from a vertex toward the light through the heightfield and return a soft shadow factor (SHADOW_MIN fully shadowed .. 1
# lit): it tracks how far the terrain rises above the light ray and maps that penetration through a smoothstep, so shadow edges
# get a penumbra and do not flip on/off as the light sweeps.
func _cast_at(gx: int, gy: int) -> float:
	if _light_dir.y <= 0.02:
		return 1.0
	var p: Vector3 = _world[gy * res + gx]
	var ds := (2.0 * half / float(res)) * 2.1
	var bias := 0.03 * relief
	var occ := 0.0
	for s in range(1, 18):
		var d := ds * float(s)
		var wx := p.x + _light_dir.x * d
		var wz := p.z + _light_dir.z * d
		if absf(wx) > half or absf(wz) > half:
			break                                 # ray left the terrain - nothing more can occlude
		var margin := height_at(wx, wz) * relief - (p.y + _light_dir.y * d + bias)
		if margin > occ:
			occ = margin
	var shade := smoothstep(0.0, 0.14 * relief, occ)   # 0 lit .. 1 fully shadowed, with a penumbra
	return lerpf(1.0, SHADOW_MIN, shade)


# Recompute `count` vertices' worth of the slow shading terms, starting at `from` and wrapping. Called from collect_surface (see
# the note there). The vertex position used for the shadow tap is the clipped one (a submerged vertex is the water surface, at y = 0),
# as the shading loop uses it, so a lake bed is not tested for shadow at its real depth.
func _refresh_slow(from: int, count: int, sxd: float, szd: float, shadow: ShadowField) -> void:
	var n := res * res
	var wet := _wsub.size() == n
	for k in count:
		var i := from + k
		if i >= n:
			i -= n
		var p: Vector3 = _world[i]
		if wet and hgrid[i] < water:
			p.y = 0.0
		# Two gentle orthogonal bands only (a diagonal term reads as a diagonal shimmer).
		var cv := sin(p.x * 0.5 + sxd) + sin(p.z * 0.42 - szd)
		_cloud_c[i] = clampf(0.74 + 0.26 * smoothstep(-0.8, 0.9, cv * 0.5), 0.68, 1.0)
		_occ_c[i] = shadow.factor(p) if shadow != null else 1.0


## Build the terrain's projected quads for this frame, unsorted, so a caller can merge them with its own geometry (buildings,
## spires) and depth-sort everything together, letting the terrain occlude props embedded in it. Each quad is {d, poly, cols, uvs}.
##
## Water is part of this surface, not a sheet over it: a shoreline is an interpenetration that a painter's sort over whole quads
## cannot resolve. The visible surface is the heightfield clipped at the datum: a submerged vertex is lifted to y = 0 (the water
## surface) and colored as water in proportion to its depth. The lift equals the depth, so it vanishes at the waterline and the mesh
## never tears; the waterline is the land's own contour at full grid resolution; the color interpolates between vertices. No extra
## quads, no separate untextured run (which cost ~894 extra batch cuts), and no alpha.
func collect_surface(lens: Lens3D, u: float, lit: float, shimmer: float, shadow: ShadowField = null) -> Array:
	var n := res * res
	var sv := PackedVector2Array()
	sv.resize(n)
	var dep := PackedFloat32Array()
	dep.resize(n)
	# Drifting cloud shadows: soft bands moving across the land (per-vertex, so they follow the 3D surface), layered under the key light and cast shadows.
	var sxd := shimmer * 0.035
	var szd := shimmer * 0.028
	# The final lit color per vertex: base color x audio brightness x cloud shadow x key light (n.l) x mountain cast shadow, then
	# valley fog over the low ground. Computed once here so both triangles of every quad reuse it.
	var vc := PackedColorArray()
	vc.resize(n)
	# World-space UVs for the tiling detail texture (grain follows the surface, not the screen).
	var uvg := PackedVector2Array()
	uvg.resize(n)
	var tile := 5.0 / maxf(0.5, half)                        # fine grain (many small repeats, not a few stretched)
	var wet := _wsub.size() == n
	# Water constants, hoisted. The shading below is inline rather than a per-vertex call because an archipelago submerges ~10k
	# vertices and a helper measured 22.3 ms/frame on the one scene that runs collect_surface on the main thread.
	var lx := _light_dir.x
	var ly := _light_dir.y
	var lz := _light_dir.z
	# The sun's glitter path, placed rather than searched for: for a flat surface at y = 0, a directional light and a fixed eye, the
	# sun's mirror image sits at exactly one point on the plane, so the highlight's center is a frame constant and its falloff a
	# cheap function of distance from it (a single frame-constant half-vector would make n.h near-constant and h^32 vanish or white
	# out the sea).
	var g_on := _light_dir.y > 0.05 and lens.eye.y > 0.0
	var g_t := (lens.eye.y / _light_dir.y) if g_on else 0.0
	var g_x := lens.eye.x + g_t * _light_dir.x
	var g_z := lens.eye.z + g_t * _light_dir.z
	var g_k := 9.0 / maxf(0.25, half * half)                 # highlight tightness, in world units
	var w_op := 1.0 / maxf(0.01, WATER_OPAQUE * _wdepth)      # 1 / the depth at which the bed vanishes
	var w_surf := 1.0 / maxf(0.004, WATER_SURF * _wdepth)     # 1 / the surf band's width
	var w_deep := 1.0 / maxf(0.01, _wdepth)                   # 1 / the deepest column
	var wcr := _water_col.r
	var wcg := _water_col.g
	var wcb := _water_col.b
	# The slow terms, cached. The cloud shadow and the prop shadow-map tap are the most expensive per-vertex work (the tap alone is
	# 23.6 ms of an 82 ms build at RES 112), and both depend on quantities that move a fraction of a world unit a second. Refreshing
	# a quarter of the grid per frame is enough. The audio-driven part, `lit`, is not cached and applies per frame.
	if _cloud_c.size() != n:
		_cloud_c.resize(n)
		_occ_c.resize(n)
		_slow_cursor = 0
		_refresh_slow(0, n, sxd, szd, shadow)      # a fresh scene must be complete on frame one
	else:
		var take := (n >> 2) + 1
		_refresh_slow(_slow_cursor, take, sxd, szd, shadow)
		_slow_cursor = (_slow_cursor + take) % n
	for i in n:
		var p: Vector3 = _world[i]
		# Clip the surface at the water datum (see the note above): a submerged vertex is the water surface, at y = 0. The lift tests
		# the true height, so the waterline is the land's own contour; the shading below reads the smoothed column.
		var sub := 0.0
		if wet and hgrid[i] < water:
			p.y = 0.0
			sub = _wsub[i]
		var pr := lens.project(p)
		sv[i] = Vector2(pr.x, pr.y) * u
		dep[i] = pr.z
		uvg[i] = Vector2(p.x, p.z) * tile
		# Soft drifting cloud shadow, and the cast shadows the scene's occluders drop on the ground, from the slice cache above.
		var cloud := _cloud_c[i]
		var occ := _occ_c[i]
		# Directional key light: sunny slopes brighten, slopes facing away fall into shade.
		var ndotl := clampf(_vnorm[i].dot(_light_dir), 0.0, 1.0)
		var key := 0.55 + 0.6 * ndotl                 # ambient floor + directional term
		var col := _lit(_vcol[i], lit * cloud * key * _cast[i] * occ)
		# Water, composited over the bed: shallow water shows the ground through it, deep water hides it. `sub` is 0 at the waterline,
		# so the transition is the land's own contour and feathers instead of stepping. Two crossing swells give the surface a
		# perturbed normal, which earns a diffuse term against the key light and a tight specular glint. The swells are functions of
		# world position, never of the grid indices (a per-quad value flat-shades the sheet and pins the pattern to the lattice).
		if sub > 0.0:
			var wa := p.x * 2.7 + p.z * 1.1 + shimmer * 0.85
			var wb := p.z * 3.3 - p.x * 0.9 - shimmer * 0.62
			var ca := cos(wa)
			var cb := cos(wb)
			var nx := -(2.7 * ca - 0.9 * cb) * 0.055        # surface slope, i.e. the wave normal
			var nz := -(1.1 * ca + 3.3 * cb) * 0.055        # (unnormalized; the y term is 1)
			# 1/|n| to first order: the slopes are under 0.2, where this is good to ~0.5% and saves a sqrt per submerged vertex.
			var ninv := 1.0 - 0.5 * (nx * nx + nz * nz)
			var wkey := 0.55 + 0.55 * clampf((nx * lx + ly + nz * lz) * ninv, 0.0, 1.0)
			# Glint: the glitter path's falloff (a rational, not an exp: this is per vertex), broken up by whether the wave face is
			# tilted toward the light, so crests flash and troughs stay dark.
			var gdx := p.x - g_x
			var gdz := p.z - g_z
			var sp := 0.0
			if g_on:
				sp = clampf(0.5 + 3.2 * (nx * lx + nz * lz), 0.0, 1.0) \
					/ (1.0 + (gdx * gdx + gdz * gdz) * g_k)
			# Depth: 0 at the shore, 1 at this map's deepest point. The body absorbs red first as it thickens, so a basin darkens
			# toward its middle.
			var dr := clampf(sub * w_deep, 0.0, 1.0)
			var pale := 0.16 * (1.0 - dr)                   # thin water is paler
			# Surf: a band peaking just off the waterline (at the line itself the water is transparent).
			var bnd := clampf(sub * w_surf, 0.0, 2.0)
			var shd := _cast[i] * occ
			var gl := sp * 0.85 * lit * shd + clampf(bnd * (2.0 - bnd), 0.0, 1.0) * 0.16 * lit
			var wk := lit * cloud * shd * wkey
			var wcol_r := minf((wcr + (1.0 - wcr) * pale) * (1.0 - 0.62 * dr) * wk + gl, 1.35)
			var wcol_g := minf((wcg + (1.0 - wcg) * pale) * (1.0 - 0.40 * dr) * wk + gl, 1.35)
			var wcol_b := minf((wcb + (1.0 - wcb) * pale) * (1.0 - 0.12 * dr) * wk + gl, 1.35)
			var o := clampf(sub * w_op, 0.0, 1.0)
			o = o * o * (3.0 - 2.0 * o)                     # smoothstep, so the shore feathers
			col = Color(col.r + (wcol_r - col.r) * o, col.g + (wcol_g - col.g) * o,
				col.b + (wcol_b - col.b) * o, 1.0)
		# Valley fog: a thin drifting haze pooling in the deepest land hollows (never over water or on the ridges), thickest at the bottom.
		if hgrid[i] > water and hgrid[i] < _fog_level:
			var hw := (hgrid[i] - water) / maxf(0.02, _fog_level - water)   # 0 valley floor .. 1 fog line
			var drift := 0.7 + 0.3 * sin(shimmer * 0.15 + p.x * 0.5 + p.z * 0.4)
			var fog := clampf((1.0 - hw) * (1.0 - hw), 0.0, 1.0) * 0.42 * drift
			col = col.lerp(Color(_fog_col.r * lit, _fog_col.g * lit, _fog_col.b * lit), fog)
		vc[i] = col
	var quads: Array = []
	for gy in res - 1:
		for gx in res - 1:
			var i0 := gy * res + gx
			var i1 := i0 + 1
			var i2 := i0 + res
			var i3 := i2 + 1
			if dep[i0] <= lens.near or dep[i1] <= lens.near or dep[i2] <= lens.near or dep[i3] <= lens.near:
				continue
			var poly := PackedVector2Array([sv[i0], sv[i1], sv[i3], sv[i2]])
			if _quad_area(poly) < 0.25:       # only truly collapsed quads (lowered: the old 2.0 left black holes)
				continue
			quads.append({"d": (dep[i0] + dep[i1] + dep[i2] + dep[i3]) * 0.25, "poly": poly,
				"cols": PackedColorArray([vc[i0], vc[i1], vc[i3], vc[i2]]),
				"uvs": PackedVector2Array([uvg[i0], uvg[i1], uvg[i3], uvg[i2]])})
	return quads


## Tint a prop's vertex color for the water it stands in (buildings, spire shafts, anything a scene embeds in the land). Returns
## `c` unchanged above the waterline and on dry maps. The surface hides what is under it, but a wall face spanning the waterline is
## one quad with one depth key, so this puts the water back on the submerged part of the prop.
func submerged(c: Color, world_y: float) -> Color:
	if _wdepth <= 0.0 or world_y >= 0.0:
		return c
	var dr := clampf(-world_y / maxf(0.01, _wdepth * relief), 0.0, 1.0)
	return c.lerp(Color(_water_col.r * 0.45, _water_col.g * 0.62, _water_col.b * 0.85),
		0.35 + 0.5 * dr)


## Project + depth-sort + draw the terrain surface: the standalone path for scenes that draw only terrain. Scenes with props
## embedded in the land use collect_surface() and merge instead.
func draw_surface(ci: CanvasItem, lens: Lens3D, u: float, lit: float, shimmer: float) -> void:
	ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # so the UVs > 1 tile
	var quads := collect_surface(lens, u, lit, shimmer)
	quads = TriBatch.painter_sort(quads)   # native-key far-first sort (see TriBatch)
	var tex := detail_texture()
	# Batched: every surface quad is textured, so a frame is a single run. The run switch is set_run, the canvas-mode one that
	# flushes to `ci`; mark_run is the worker-side switch whose chunks only take_chunks() drains, and using it here would drop every
	# run but the last.
	var tb := TriBatch.new()
	tb.set_run(ci, true, tex.get_rid() if tex != null else RID())
	for q in quads:
		var want: bool = q.has("uvs")
		tb.set_run(ci, want, tex.get_rid() if (want and tex != null) else RID())
		if want:
			tb.quad_textured(q.poly, q.cols, q.uvs)
		else:
			tb.quad_colored(q.poly, q.cols)
	tb.flush(ci)


# Screen-space area of a quad (shoelace), computed relative to the first vertex. Near-zero means edge-on / collapsed / folded,
# which makes draw_colored_polygon's triangulation fail, so those are skipped. Subtracting p[0] first matters: a quad projected
# just past the near plane lands at coordinates in the millions, and the raw shoelace loses every significant digit to cancellation.
static func _quad_area(p: PackedVector2Array) -> float:
	if p.size() < 3:
		return 0.0
	var o := p[0]
	var a := 0.0
	for i in range(1, p.size()):
		var j := (i + 1) % p.size()
		if j == 0:
			break
		var u1 := p[i] - o
		var v1 := p[j] - o
		a += u1.x * v1.y - v1.x * u1.y
	return absf(a) * 0.5


# The screen extent (longest edge from the first vertex): the scale a degeneracy test is judged against.
static func _poly_extent(p: PackedVector2Array) -> float:
	var e := 0.0
	for i in range(1, p.size()):
		e = maxf(e, (p[i] - p[0]).length())
	return e


# Godot stores these points as float32 and its triangulator recomputes the polygon's area in float32 to choose a winding order.
# At the coordinate magnitudes of a quad just past the near plane that loses every significant digit (a triangle of area +3500 px²
# at ~1e6 evaluates to -32768), the winding flips and the polygon is rejected ("triangulation failed"). GDScript's own arithmetic
# is double precision, so a plain area check passes it. Hence a precision-aware floor: the area must survive a float32
# evaluation at this triangle's own coordinate scale (24-bit mantissa: the shoelace error is on the order of c² · 1e-6).
const _F32_AREA_EPS := 1.0e-6


## Is this triangle/quad safe to hand to the rasterizer? Finite, big enough to survive float32 at its own coordinate scale (see
## above), and not a sliver that is collinear at its own length.
static func _poly_ok(p: PackedVector2Array) -> bool:
	var c := 0.0
	for v in p:
		if not (is_finite(v.x) and is_finite(v.y)):
			return false
		c = maxf(c, maxf(absf(v.x), absf(v.y)))
	var area := _quad_area(p)
	if not is_finite(area) or area <= maxf(0.04, c * c * _F32_AREA_EPS):
		return false
	var ext := _poly_extent(p)
	return ext > 0.001 and area > ext * 0.0005


static func _lit(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## Draw a 4-point quad as its two Gouraud (per-vertex-colored) triangles, split on the 0-2 diagonal (a projected quad can fold into
## a bowtie a single polygon cannot triangulate); degenerate ones are skipped. If `uvs` + `tex` are given, the vertex colors are
## modulated by a tiling detail texture (world-space UVs): sub-vertex surface grain.
static func draw_quad(ci: CanvasItem, poly: PackedVector2Array, cols: PackedColorArray,
		uvs := PackedVector2Array(), tex: Texture2D = null) -> void:
	if poly.size() < 4:
		return
	var textured := tex != null and uvs.size() >= 4 and cols.size() >= 4
	var t1 := PackedVector2Array([poly[0], poly[1], poly[2]])
	if _poly_ok(t1):
		if textured:
			ci.draw_polygon(t1, PackedColorArray([cols[0], cols[1], cols[2]]),
				PackedVector2Array([uvs[0], uvs[1], uvs[2]]), tex)
		else:
			ci.draw_polygon(t1, PackedColorArray([cols[0], cols[1], cols[2]]))
	var t2 := PackedVector2Array([poly[0], poly[2], poly[3]])
	if _poly_ok(t2):
		if textured:
			ci.draw_polygon(t2, PackedColorArray([cols[0], cols[2], cols[3]]),
				PackedVector2Array([uvs[0], uvs[2], uvs[3]]), tex)
		else:
			ci.draw_polygon(t2, PackedColorArray([cols[0], cols[2], cols[3]]))


# A tiling grayscale detail texture (built once): fbm value-noise crossed with a ridged streak. Tiled finely via world-space UVs,
# so its (not perfectly seamless) seams fall well below a pixel.
static var _dtex: Texture2D = null
static func detail_texture() -> Texture2D:
	if _dtex == null:
		# A fine, isotropic gray grain (two plain fbm octaves, no ridged noise, which baked in directional streaks). FastNoiseLite
		# is seamless enough at these frequencies to tile.
		var s := 256
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var nf := FastNoiseLite.new()
		nf.seed = 1337
		nf.frequency = 0.10
		nf.fractal_octaves = 5
		var nr := FastNoiseLite.new()
		nr.seed = 4242
		nr.noise_type = FastNoiseLite.TYPE_SIMPLEX
		nr.frequency = 0.26
		nr.fractal_octaves = 3
		for y in s:
			for x in s:
				var a := nf.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var b := nr.get_noise_2d(float(x) + 33.0, float(y) - 12.0) * 0.5 + 0.5
				var v := clampf(0.80 + 0.30 * (a - 0.5) + 0.18 * (b - 0.5), 0.6, 1.12)
				img.set_pixel(x, y, Color(v, v, v, 1.0))
		img.generate_mipmaps()
		_dtex = ImageTexture.create_from_image(img)
	return _dtex

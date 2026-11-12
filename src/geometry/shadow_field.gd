extends RefCounted
class_name ShadowField

## A cheap CPU shadow map in light space for the canvas 3D scenes. Occluders (buildings, spires) are rasterized into a grid on
## the plane perpendicular to the light; each cell keeps the occluder surface closest to the light. A surface point is in shadow
## if something is nearer the light at its cell, so a whole building casts a volumetric shadow onto the ground and other
## buildings.
##
## Self-shadowing is avoided by biasing each building's own query by its own light-depth extent: moving a point along the light
## changes only its depth, not its cell, so a large-enough bias lifts it clear of its own body while a taller neighbor still
## occludes it.

const SHADOW_MIN := 0.5          # brightness of a fully cast-shadowed surface (0 = black, 1 = lit)

var _l := Vector3(0, 1, 0)       # unit direction TOWARD the light
var _lr := Vector3(1, 0, 0)      # light-space right / up (perpendicular to _l)
var _lu := Vector3(0, 0, 1)
var _res := 220
var _grid := PackedFloat32Array()
var _cov := PackedFloat32Array()      # per-cell silhouette COVERAGE, 0..1 (see add_box)
var _minx := 0.0
var _miny := 0.0
var _sx := 1.0
var _sy := 1.0
var _ready := false


## Set up the light frame + grid bounds from the scene's world AABB, and clear the map.
func build(light_dir: Vector3, wmin: Vector3, wmax: Vector3, res := 220) -> void:
	_l = light_dir.normalized()
	_lr = _l.cross(Vector3.UP)
	if _lr.length() < 1e-4:
		_lr = _l.cross(Vector3(1, 0, 0))
	_lr = _lr.normalized()
	_lu = _lr.cross(_l).normalized()
	# Stable texels: the extent comes from the box's bounding sphere, which is the same number whatever direction the light comes
	# from, and the origin is snapped down to a whole texel. The texel has a fixed size and phase in world space, so a turning
	# light (Terrain.set_light turns the azimuth continuously) rotates the map instead of re-quantizing it, and a stationary
	# tree's shadow does not swim.
	var pad := 0.5
	var ctr := (wmin + wmax) * 0.5
	var radius := (wmax - wmin).length() * 0.5 + pad
	_res = res
	_sx = float(res) / maxf(0.001, 2.0 * radius)
	_sy = _sx
	var texel := 1.0 / _sx
	_minx = floor((ctr.dot(_lr) - radius) / texel) * texel
	_miny = floor((ctr.dot(_lu) - radius) / texel) * texel
	_grid = PackedFloat32Array()
	_grid.resize(res * res)
	_grid.fill(-1e20)
	_cov = PackedFloat32Array()
	_cov.resize(res * res)
	_cov.fill(0.0)
	_ready = true


## Rasterize an oriented box occluder (its light-space silhouette bounding rect, storing the box's surface nearest the light)
## and its per-cell coverage. Returns the box's light-depth extent, which the caller passes back as the self-shadow bias when
## shading that box's own faces.
##
## Coverage is the antialiasing: it stores the fraction of each border cell the silhouette covers, so the edge sits at its true
## sub-texel position and moves continuously as the light drifts.
##
## [param round_] treats the silhouette as the inscribed ellipse rather than the rect, feathering to nothing at its rim (a tree
## crown and a spire shaft are round). Buildings stay square.
func add_box(base: Vector3, up: Vector3, bx: Vector3, bz: Vector3, w: float, h: float,
		round_ := false) -> float:
	if not _ready:
		return 0.0
	var top := base + up * h
	var corners := [
		base - bx * w - bz * w, base + bx * w - bz * w, base + bx * w + bz * w, base - bx * w + bz * w,
		top - bx * w - bz * w, top + bx * w - bz * w, top + bx * w + bz * w, top - bx * w + bz * w]
	var minlx := 1e20
	var maxlx := -1e20
	var minly := 1e20
	var maxly := -1e20
	var maxld := -1e20
	var minld := 1e20
	for c in corners:
		var lx: float = c.dot(_lr)
		var ly: float = c.dot(_lu)
		var ld: float = c.dot(_l)
		minlx = minf(minlx, lx); maxlx = maxf(maxlx, lx)
		minly = minf(minly, ly); maxly = maxf(maxly, ly)
		maxld = maxf(maxld, ld); minld = minf(minld, ld)
	# The silhouette in cell units, kept fractional.
	var fx0 := (minlx - _minx) * _sx
	var fx1 := (maxlx - _minx) * _sx
	var fy0 := (minly - _miny) * _sy
	var fy1 := (maxly - _miny) * _sy
	var cx0 := clampi(int(floor(fx0)), 0, _res - 1)
	var cx1 := clampi(int(floor(fx1)), 0, _res - 1)
	var cy0 := clampi(int(floor(fy0)), 0, _res - 1)
	var cy1 := clampi(int(floor(fy1)), 0, _res - 1)
	var mx := (fx0 + fx1) * 0.5
	var my := (fy0 + fy1) * 0.5
	var rx := maxf(0.5 * (fx1 - fx0), 1e-4)
	var ry := maxf(0.5 * (fy1 - fy0), 1e-4)
	for cy in range(cy0, cy1 + 1):
		var row := cy * _res
		# Fraction of this cell's height the silhouette spans (1 in the interior, a fraction at the rim).
		var covy := clampf(minf(fy1, float(cy) + 1.0) - maxf(fy0, float(cy)), 0.0, 1.0)
		var dy := (float(cy) + 0.5 - my) / ry
		for cx in range(cx0, cx1 + 1):
			var cov := covy * clampf(minf(fx1, float(cx) + 1.0) - maxf(fx0, float(cx)), 0.0, 1.0)
			if round_:
				# Inscribed ellipse, feathered over its outer third so the rim is a gradient.
				var dx := (float(cx) + 0.5 - mx) / rx
				cov *= clampf((1.0 - sqrt(dx * dx + dy * dy)) * 3.0, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var idx := row + cx
			if maxld > _grid[idx]:
				_grid[idx] = maxld
			# Coverage accumulates as a max over occluders rather than traveling with the depth that won: a cell grazed by one tree
			# and filled by another is filled.
			if cov > _cov[idx]:
				_cov[idx] = cov
	return maxld - minld


## The light-space depth of a world point (higher = nearer the light), for measuring an occluder's own depth extent.
func light_depth(p: Vector3) -> float:
	return p.dot(_l)


## Light factor at a world point: 1 = full sun, down to SHADOW_MIN if an occluder is nearer the light at this point's cell.
## `bias` lifts the point clear of its own occluder (the box's depth extent for its own faces; a small value for the ground).
##
## Bilinear: a nearest tap gives a staircase edge on the cell grid. The four factors are blended, not the four depths:
## neighboring cells hold the depth of different occluders, and the average of two is not a surface. Each cell's own
## lit/shadowed verdict is computed first and only those are mixed. [method add_box]'s coverage supplies the partial cells the
## filter needs for more than a one-cell ramp.
func factor(p: Vector3, bias := 0.06) -> float:
	if not _ready:
		return 1.0
	# Cell centers sit at +0.5, so subtracting it puts the integer part at the lower-left neighbor and the fraction at the blend weight.
	var fx := (p.dot(_lr) - _minx) * _sx - 0.5
	var fy := (p.dot(_lu) - _miny) * _sy - 0.5
	var x0 := floori(fx)
	var y0 := floori(fy)
	if x0 < -1 or x0 >= _res or y0 < -1 or y0 >= _res:
		return 1.0
	var ax := fx - float(x0)
	var ay := fy - float(y0)
	var x1 := mini(x0 + 1, _res - 1)
	var y1 := mini(y0 + 1, _res - 1)
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	var d := p.dot(_l) + bias
	var r0 := y0 * _res
	var r1 := y1 * _res
	# Each cell's verdict is its depth test scaled by how much of it the silhouette covered, so a grazed cell casts a partial shadow.
	var t00 := _cov[r0 + x0] * clampf((_grid[r0 + x0] - d) / 0.35, 0.0, 1.0)     # soft ramp into shadow
	var t10 := _cov[r0 + x1] * clampf((_grid[r0 + x1] - d) / 0.35, 0.0, 1.0)
	var t01 := _cov[r1 + x0] * clampf((_grid[r1 + x0] - d) / 0.35, 0.0, 1.0)
	var t11 := _cov[r1 + x1] * clampf((_grid[r1 + x1] - d) / 0.35, 0.0, 1.0)
	var t := lerpf(lerpf(t00, t10, ax), lerpf(t01, t11, ax), ay)
	return lerpf(1.0, SHADOW_MIN, t)

extends Node2D
class_name GhostScene

## GhostScene - one visualizer.
##
## The base of every scene: a seeded definition plus transforms modulated by audio. Two things come for free here:
##
##   mod  : a [ModBank] of organic oscillator channels (mod.value("sway")...)
##   view : a [SceneView] - zoom / tilt / rotate / off-center, drawn through
##
## Subclasses override:
##   build_params(rng) -> Dictionary   # the seeded definition
##   update(features, delta)           # set state + view, then queue_redraw()
##   _draw()                           # begin_draw(); draw shapes around (0,0)
##
## Coordinates in _draw are centered: (0,0) is the screen middle. Call
## [method begin_draw] first and the view's zoom/tilt/pan/roll apply to
## everything you draw.

## Motion behaviors - how a scene moves, separate from what it draws: frozen (pure audio reaction), gently drifting
## as a whole, or with each element moving on its own. The Director pairs a scene with one of these.
##   view    - how much whole-scene camera drift to apply (0 = frozen camera)
##   element - how much independent per-element motion (0 = rigid)
##   speed   - time scale for all organic motion (0 = modulators frozen)
const BEHAVIORS := {
	"static": {"view": 0.0, "element": 0.0, "speed": 0.0},
	"drift": {"view": 1.0, "element": 0.0, "speed": 1.0},
	"fluid": {"view": 0.3, "element": 1.0, "speed": 1.0},
}

## Render kind - how a scene is drawn, separate from what it draws and how it moves. A scene declares one in build_params:
##   "canvas"    - flat 2D canvas drawing (draw_* in centered screen space). Legacy.
##   "mesh3d"    - software 3D bodies ([Mesh3D]) projected onto the 2D canvas.
##   "particles" - a [ParticleSystem] substrate, drawn on the canvas.
##   "swarm"     - a [Swarm] field of many items, drawn on the canvas.
##   "scene3d"   - the unified path: a [Camera3D] + depth-sorted 3D drawables
##                 (meshes and [Plane3D] quads) under forced perspective. The target
##                 everything else migrates toward.
var render_kind := "canvas"

## What this scene reads of the show ([ShowFeed]): handed by whoever mounts it (the [Director]); the show that is up
## for a scene nobody handed one (a gate, a medium's placeholder). A scene reads the show here, never by the Director's name.
var feed: ShowFeed = ShowFeed.playing()

## The typed definition for this instance.
var params: Dictionary = {}

## The raw storyboard entry that created this scene (empty in auto mode), set by the [Director] before
## [method init_with_seed]. A data-driven scene (see scenes/stage.gd) builds its content from this in build_params;
## an ordinary scene reads only its `set`, the settings an entry tells it ([method choice]).
var spec: Dictionary = {}
## What each setting an entry may tell came out as, told or drawn ([method choice]): the scene's own
## account of its choices, for the feedback console and a gate.
var chosen := {}

## Identity stamped by the [Director] at creation, for telemetry / feedback capture
## (the feedback console writes these so a critique can be tied back to its scene).
var scene_name := ""
var behavior_name := "drift"
var shot_name := ""
var seed_value := 0

## Optional per-scene exit override set by the [Director] in manual (storyboard) mode:
## `{"hold": seconds}` for fixed timing, or `{"trigger": Trigger, "min":, "max":}`
## to land the cut on a chosen musical cue. Empty = the Director's default
## lifecycle + randomly-armed trigger (auto mode).
var exit_spec: Dictionary = {}

## Narrative-tempo scalar from the storyboard's `sensitivity` (see the Director), 1.0 = nominal. Higher = faster: the
## Director shrinks this scene's hold by it, and a scene with no fixed hold divides its nominal keyframe span by it.
## It only compresses the keyframe/phase clock: the ambient life of the bodies always runs on the raw delta.
var event_scale: float = 1.0

## The window (seconds) a keyframe-driven scene paces its phases over: its fixed hold if it has one (already
## sensitivity-scaled by the Director), else its own [param nominal] design length divided by [member event_scale].
## Scenes express keyframes as fractions of this (e.g. `_t / phase_span(8.0)`), so every event lands whatever the hold.
func phase_span(nominal: float) -> float:
	if exit_spec.has("hold"):
		return maxf(0.05, float(exit_spec["hold"]))
	return maxf(0.05, nominal / maxf(0.05, event_scale))

## Content-aware transition typing. A scene declares the geometry it leaves on screen (`morph_out`) and the geometry
## it can grow in from (`morph_in`). When the Director changes from A to B and `B.morph_in == A.morph_out` (both
## non-empty) it plays a morph: an instant swap where B animates itself out of A's shape (e.g. one eye splitting into
## two), instead of a cut or dip. Only compatible geometries morph.
var morph_out := ""
var morph_in := ""

## Transition style the [Director] uses when leaving this scene, set from the
## storyboard ("cut" / "dip" / "fade"; "" = the Director chooses). A morph, when
## compatible, always wins over this.
var transition_style := ""
## Viewport size in pixels, kept current across resizes.
var size: Vector2 = Vector2.ZERO
## Organic modulation channels (seeded). See [ModBank].
var mod: ModBank
## The camera this scene draws through. See [SceneView].
var view: SceneView
## This instance's motion behavior (one of [constant BEHAVIORS]).
var behavior: Dictionary = BEHAVIORS["drift"]

## Lifecycle - does this scene loop until the Director cuts it (`"loop"`), or play
## one self-contained sequence and end (`"oneshot"`)? A oneshot reports when its
## sequence is done via [method finished]; the Director then exits it on the next
## musical cue. A scene sets this in [method build_params] if it wants to be a
## oneshot (or to choose between the two on its seed).
var lifecycle := "loop"

## Framing class for shot selection: `"subject"` (a discrete object - gets the
## expressive cinematic shots) or `"field"` (fills the frame - gets gentle shots
## only, so panning never exposes its edges). Field scenes set this in build_params.
var framing := "subject"

## The camera framing assigned by the [Director] (see [Shots]); applied in tick().
var shot = null

## Seconds this scene has been alive - drives slow shot moves (push-in, pan).
var _life := 0.0

## Composed visual components (see [Layer]), the appearance sibling of the physics [Primitives] force list. A scene
## adds layers in build_params; update_layers advances them and draw_layers paints them, in order.
var layers: Array = []
## The most recent audio frame, kept so draw-time code (and layers) can read it.
var last_f: AudioFeatures = AudioFeatures.new()


## Called once by [Director] before the scene enters the tree. Seeds everything
## deterministically and fixes the motion behavior. Do not override - override
## [method build_params] / [method seed_view].
func init_with_seed(seed_value: int, behavior_name := "drift") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	self.seed_value = seed_value
	self.behavior_name = behavior_name
	behavior = BEHAVIORS.get(behavior_name, BEHAVIORS["drift"])
	mod = ModBank.new(seed_value ^ 0x5bd1e995)
	view = SceneView.new()
	params = build_params(rng)
	seed_view(rng)


## Override: roll the typed definition. Same seed -> same scene.
func build_params(_rng: RandomNumberGenerator) -> Dictionary:
	return {}


# --- what a scene can be told ---------------------------------------------------------------------

## A setting a storyboard entry may tell this scene: one of the options its row in the scene's own `FIELDS` names
## ([method fields_of]), the one the entry's `set` gives, else the seed's pick. The die is thrown either way, so
## telling one setting moves no draw made before or beside it; only a told setting that changes how much is drawn
## after it (a kind with rolls of its own, a count that sizes a loop) moves what follows.
func choice(key: String, rng: RandomNumberGenerator) -> Variant:
	var options := options_of(get_script(), key)
	assert(not options.is_empty(), "%s: no options for the setting '%s'" % [get_script().resource_path, key])
	var drawn: Variant = options[rng.randi() % options.size()]
	var said: Variant = told(key)
	# an option that is an index is told by the name its row's `names` gives it, or by itself
	var names := table_of(get_script(), String((fields_of(get_script()).get(key, {}) as Dictionary).get("names", "")))
	if said != null and names.has(said):
		said = names.find(said)
	if said != null:
		for o in options:
			if str(o) == str(said):
				chosen[key] = o
				return o
	chosen[key] = drawn
	return drawn


## A number a storyboard entry may tell this scene: drawn from the `range` its `FIELDS` row gives ([method fields_of]),
## `rng.randi_range` when both ends are whole numbers, `randf_range` otherwise; when the entry's `set` gives a number
## or a narrower `[lo, hi]`, that number, or the same draw carried into that range. What is told is held to the
## scene's own range. The die is thrown either way, as in [method choice].
func number(key: String, rng: RandomNumberGenerator) -> Variant:
	var r: Array = (fields_of(get_script()).get(key, {}) as Dictionary).get("range", [])
	assert(r.size() == 2, "%s: no range for the setting '%s'" % [get_script().resource_path, key])
	var whole := typeof(r[0]) == TYPE_INT and typeof(r[1]) == TYPE_INT
	var drawn: Variant = rng.randi_range(r[0], r[1]) if whole else rng.randf_range(r[0], r[1])
	var said: Variant = told(key)
	var span: Variant = null
	if said is Array and (said as Array).size() == 2 and _is_number(said[0]) and _is_number(said[1]):
		span = [minf(said[0], said[1]), maxf(said[0], said[1])]
	elif _is_number(said):
		span = [float(said), float(said)]
	if span == null:
		chosen[key] = drawn
		return drawn
	var lo := clampf(span[0], r[0], r[1])
	var hi := clampf(span[1], r[0], r[1])
	var out: Variant = drawn
	if lo == float(r[0]) and hi == float(r[1]):
		pass
	elif whole:
		var n := int(r[1]) - int(r[0]) + 1
		var a := ceili(lo)
		var b := maxi(floori(hi), a)
		out = a + (int(drawn) - int(r[0])) * (b - a + 1) / n
	else:
		var at := (float(drawn) - float(r[0])) / (float(r[1]) - float(r[0]))
		out = lo + at * (hi - lo)
	chosen[key] = out
	return out


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## What the entry's `set` tells this scene of [param key], or null (nothing, or nothing named).
func told(key: String) -> Variant:
	var set: Variant = spec.get("set")
	if not (set is Dictionary):
		return null
	var v: Variant = (set as Dictionary).get(key)
	return null if v == null or str(v).is_empty() else v


## What a scene can be told: the rows of its own `FIELDS` (and an ancestor's), one per setting - `label`, `type`
## ("choice", or "num" for a rolled number), `options` (a choice's: the name of the scene's own table its choices are;
## repeats weight the seed's pick), `names` (for options that are indices, the table of their names, which an entry may
## tell instead), `range` (a number's `[lo, hi]`, what the seed draws from - [method number]), `default` (null: drawn
## from the seed), `blurb`. What the storyboard's inspector builds its rows from ([method SceneRoster.fields_of]) and
## docs/scenes.md shows; docs.py holds each row to the code that reads it.
static func fields_of(script: Script) -> Dictionary:
	var chain: Array = []
	var s := script
	while s != null:
		chain.push_front(s)
		s = s.get_base_script()
	var out := {}
	for c in chain:
		var f: Variant = (c as Script).get_script_constant_map().get("FIELDS")
		if f is Dictionary:
			out.merge(f as Dictionary, true)
	return out


## The options of [param script]'s setting [param key], in the order the seed draws from them.
static func options_of(script: Script, key: String) -> Array:
	return table_of(script, String((fields_of(script).get(key, {}) as Dictionary).get("options", "")))


## [param script]'s own table [param name] (or an ancestor's) as a list: a Dictionary's keys, an
## Array itself; empty when there is none.
static func table_of(script: Script, name: String) -> Array:
	var s := script
	while s != null and not name.is_empty():
		var t: Variant = s.get_script_constant_map().get(name)
		if t is Dictionary:
			return (t as Dictionary).keys()
		if t is Array:
			return t
		s = s.get_base_script()
	return []


## Override (optional): seed per-scene view ranges or initial state.
func seed_view(_rng: RandomNumberGenerator) -> void:
	pass


## Override: read [param f], update state and [member view], then queue_redraw().
func update(_f: AudioFeatures, _delta: float) -> void:
	pass


## Override (oneshot scenes only): true once the scene's sequence has finished
## and it is ready to be exited. Loop scenes leave this false forever.
func finished() -> bool:
	return false


## Override (morph sources): a small typed bag of state the outgoing scene hands to the incoming one during a morph,
## so the transition is continuous (e.g. the eye passes its color / gaze / size). Keys are by convention; the
## receiver reads what it understands.
func morph_payload() -> Dictionary:
	return {}


## Override (morph targets): called by the [Director] when this scene is morphing in
## from a compatible scene (see [member morph_in]). [param from] is the outgoing
## scene - read its [method morph_payload] to continue from its state, then play the
## morph-in animation (e.g. two_eyes starts as one eye and splits apart).
func begin_morph(_from: GhostScene) -> void:
	pass


func _ready() -> void:
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_resize)
	# Disable canvas-item culling: scenes draw through a view transform (pan / zoom), so content near the frame edge (big
	# soft glows whose halo still bleeds in) would pop out when the item's auto-computed bounds crossed the viewport. A
	# large custom rect keeps the item always visible.
	RenderingServer.canvas_item_set_custom_rect(
		get_canvas_item(), true, Rect2(-100000, -100000, 200000, 200000))


func _on_resize() -> void:
	size = get_viewport_rect().size
	queue_redraw()


## Push the view transform. Call at the top of _draw; then draw around (0,0).
func begin_draw() -> void:
	draw_set_transform_matrix(view.matrix(size))


## A filled polygon with an antialiased silhouette: use this instead of draw_colored_polygon wherever the shape's
## outline is part of the picture.
##
## Godot offers no antialiasing for draw_colored_polygon. Stroking the same outline with an antialiased polyline lays a
## smoothed fringe over the hard silhouette (edge pixels with no partial coverage drop from 97.7% to 40.8% on the
## harmonic lattice) for one extra draw call per shape.
##
## Alpha: the stroke composites on top of the fill it traces, so a translucent shape gets a rim of roughly 2a - a²
## instead of a: invisible near a = 1, a bright hairline near a = 0.1. Full-frame washes, fog banks and beds keep plain
## draw_colored_polygon. Cost: one extra draw call per shape, for scenes that draw tens to a few hundred shapes;
## anything drawing thousands should go through [TriBatch] and get its antialiasing from supersampling.
func fill_aa(pts: PackedVector2Array, col: Color, width := 1.0) -> void:
	fill_aa_on(self, pts, col, width)


## The same, for the shared drawers ([Layer], [EyeBody], [Cast]) that paint onto a scene's
## CanvasItem rather than being one.
static func fill_aa_on(ci: CanvasItem, pts: PackedVector2Array, col: Color, width := 1.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, col, width, true)


## Flood the whole frame with one bright, flat ground: the high-key counterpart to [Layer]'s `bed`.
##
## `bed` paints top / middle / bottom at val*0.5, val*1.0 and val*0.35 around a default val of 0.32, so its brightest
## pixel is a mid tone and its edges are darker than its center. That suits a luminous subject in a dark frame, not
## paper, daylight, or water seen from above, where the ground is the subject and must read flat and bright.
##
## Three differences from `bed`:
##   Flat, not vignetted: a gradient toward the corners reads as a spotlight on paper.
##   Plain fill, never fill_aa: the antialiased variant strokes the outline on top of the fill, and on a full-frame
##   quad that rim lands on the frame edge as a bright hairline.
##   Oversized: the same 1.15 overdraw the layers get, so camera drift never exposes a corner. Call it first in
##   _draw, right after begin_draw.
##
## [param tint] is a gentle audio-driven wash toward the accent at low strength: a bright scene reacts by shifting
## temperature, not by dimming.
func paint_ground(hue: float, sat := 0.06, val := 0.94, tint := 0.0, tint_hue := 0.0) -> void:
	# Blended on the wheel, not along the shortest arc (see blend_hue): this full-bleed quad is the largest surface in the frame.
	var h := blend_hue(hue, tint_hue, clampf(tint, 0.0, 1.0) * 0.5)
	var col := Color.from_hsv(fposmod(h, 1.0), clampf(sat, 0.0, 1.0), clampf(val, 0.0, 1.0))
	# Sized to what the camera can see (see [method SceneView.visible_half]) rather than to the viewport scaled by a
	# constant, so a panned or rolled camera cannot walk this quad's corner into frame.
	var hv := view_half_px()
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hv.x, -hv.y), Vector2(hv.x, -hv.y),
		Vector2(hv.x, hv.y), Vector2(-hv.x, hv.y)]), col)


## The shorter screen axis - use it to size geometry independent of aspect.
func unit() -> float:
	return minf(size.x, size.y)


## The half-extent this scene must fill to cover the frame, in unit fractions (the space layers, spawn bounds and
## flock walls are expressed in). Ask this instead of assuming the viewport: it follows the camera exactly. See
## [method SceneView.visible_half].
func view_half() -> Vector2:
	return view.visible_half(size) / maxf(1.0, unit())


## The same, in PIXELS - for scenes that build in screen units rather than unit fractions.
func view_half_px() -> Vector2:
	return view.visible_half(size)


## Pull [param base] a fraction [param k] of the way toward [param toward], both hues in turns.
##
## Use this instead of the shortest-arc form `base + (fposmod(toward - base + 0.5, 1.0) - 0.5) * k`, which is
## discontinuous at the antipode (it flips between +0.5 and -0.5): a tonal center near the point opposite a scene's
## hue makes the color jump or dither between two colors, however slowly the input moves.
##
## Blending the two hues as vectors on the color wheel has no such boundary: as `toward` sweeps through the antipode
## the resultant swings smoothly through `base` and its length shrinks. For k < 0.5 its length is at least 1 - 2k, so
## the angle is always well defined.
static func blend_hue(base: float, toward: float, k: float) -> float:
	var w := clampf(k, 0.0, 0.49)
	if w <= 0.0005:
		return fposmod(base, 1.0)
	var a := base * TAU
	var b := toward * TAU
	var v := Vector2(cos(a), sin(a)) * (1.0 - w) + Vector2(cos(b), sin(b)) * w
	return fposmod(v.angle() / TAU, 1.0)


## Set the camera framing for this scene (called once by the Director).
func set_shot(s) -> void:
	shot = s


## Advance the organic clock once per frame, scaled by the behavior's speed
## (so a "static" scene's modulators stay frozen and it reacts to audio alone),
## and apply the assigned shot's base framing. Call this at the top of update().
func tick(f: AudioFeatures, delta: float) -> void:
	_life += delta
	mod.advance(delta * float(behavior.speed), f.energy)
	if shot != null:
		shot.apply(view, f, _life)


## Organic camera drift, added on top of the shot's base framing, scaled by the behavior's view gain. A "static"
## scene (view = 0) adds nothing. Only zoom + pan: rolling or shearing flat 2D content reads as fake 3D, so rotation
## comes only from shots and real depth only from Mesh3D. (`roll` and `tilt` are unused, kept for call-site
## compatibility; a scene that wants skew sets view.skew itself, e.g. strata.)
func drift_view(f: AudioFeatures, move := 0.05, zoom := 0.08, _roll := 0.0, _tilt := 0.0) -> void:
	var g: float = behavior.view
	if g <= 0.0:
		return
	view.zoom += g * zoom * mod.value("zoom") + 0.04 * f.energy
	view.offset += Vector2(g * move * mod.value("panx"), g * move * mod.value("pany"))


## Compose a visual component by [Layer] registry key, seeded from [param rng] (use the
## one handed to build_params so the look is deterministic per session). Returns the
## layer so a scene can keep a handle on it. Layers paint back-to-front in add order.
func add_layer(key: String, rng: RandomNumberGenerator, cfg := {}) -> Layer.Base:
	var l := Layer.make(key, rng, cfg)
	layers.append(l)
	return l


## Advance every composed layer. Call from update(). Hands each layer the visible
## half-extent (in unit fractions) so it fills the frame at any aspect / resolution.
func update_layers(f: AudioFeatures, delta: float) -> void:
	last_f = f
	if layers.is_empty():
		return
	# What the camera can actually see, not a fixed guess: a constant margin cannot know whether the shot has pulled back
	# or panned sideways, and the layer's drawn region would end inside the frame. See [method SceneView.visible_half].
	for l in layers:
		l.update(f, delta, view_half())


## Paint composed layers onto this scene's canvas, in add order. Call from _draw() after
## begin_draw() (so the layers share the scene's view transform). [param z_filter] picks
## a depth band ("back" / "front") so a geometry scene can draw its background layers
## (stars) before its geometry and its foreground layers (snow) after; "" draws all.
func draw_layers(z_filter := "") -> void:
	if layers.is_empty():
		return
	var u := unit()
	for l in layers:
		if z_filter == "" or l.z() == z_filter:
			l.draw(self, u)


## Per-element motion primitive: an independent organic offset in -1..1 for
## element [param i], decorrelated per index and scaled by the behavior's element
## gain (0 for rigid scenes). This is how lines/shapes move on their own instead
## of the whole scene shifting as a block - the seed of the motion-primitive
## library the visualizer will grow.
func wobble(key: String, i: int) -> float:
	var g: float = behavior.element
	if g <= 0.0:
		return 0.0
	return mod.value("%s_%d" % [key, i]) * g


## The music's harmonic signature now, as the show that plays this scene hears it
## ([method ShowFeed.signature]); empty with no show.
func signature() -> PackedFloat32Array:
	return feed.signature() if feed != null else PackedFloat32Array()


## Tonal color from the live harmonic signature: the continuous, expressive half of harmonic seeding (the discrete
## half is the seed_bias mixed into seeds; see next/harmonic_seeding.md).
## The 12 chroma bins are placed on the color wheel and summed: the result's angle is the
## music's tonality (its "key" as a hue) and its length is how tonal the moment is. Returns
## Vector2(hue 0..1, strength 0..1); a scene can pull its palette toward the hue by the strength.
func chroma_hue() -> Vector2:
	var sig := signature()
	if sig.size() < 12:
		return Vector2.ZERO
	var acc := Vector2.ZERO
	for k in 12:
		acc += Vector2(cos(TAU * float(k) / 12.0), sin(TAU * float(k) / 12.0)) * sig[k]
	return Vector2(fposmod(acc.angle() / TAU, 1.0), clampf(acc.length() * 1.6, 0.0, 1.0))

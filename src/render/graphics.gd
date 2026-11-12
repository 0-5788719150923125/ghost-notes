extends RefCounted
class_name Graphics

## Graphics - how finely the stage is drawn, live and in an export: the same picture, each at a quality of its own.
##
## What is drawn never changes with it: a row is how finely the renderer draws what the show already is (samples a
## pixel takes, texture filtering across a slant, taps softening a shadow's edge or the ambient occlusion), never a
## light, a color or a place. The one row that changes the look, bounce light, is one choice for both columns
## (`shared`: an export must look as the viewer did) and is off until chosen.
##
## Two columns, live and export. The live defaults are the plain picture; an export's are the finest each row offers
## (a slow frame costs a render only time), except supersampling at 1.5x: at a 1080p export's 2880 x 1620 the stage's
## GPU time is 21.0 ms without it, 38.5 at 1.5x and 63.5 at 2x, and 1.5x does most of what 2x does. Choices are made
## on the panel ([GraphicsPanel]) and kept in `[graphics]` as `live_<key>` and `export_<key>`; an export render reads
## ghost.cfg as every render does, and writes nothing.
##
## Resolution is the live viewer's alone (`only`). The window stretches its canvas (`canvas_items`, 1080 units high)
## and the stage is the frame in those units, scaled to the window as shown. The row is how many lines that is
## ([method stage_size], asked by whoever sizes the stage and again when the row changes, [method bind_stage]'s
## `refit`); an export is drawn at its own size. GPU time grows about 2.4 ms a million pixels over a 1.4 ms base.
##
## It reaches the stage's own viewport ([method bind_stage]: supersampling, texture filtering) and the renderer's
## globals (ambient occlusion and bounce light quality, subsurface scattering, shadow filtering, the fog's grid); one
## process has one stage. A medium hands its environment to [method dress], which sets bounce light on it and keeps it
## to set again when the row changes.
##
## An export already supersamples the whole frame (exporter.gd's QUALITIES `ss`, held to 1.5x by the scratch file's
## size). The 3D's own supersampling is resolved on the graphics card before the frame is written, so it costs only
## time and memory, held under [constant SUPERSAMPLE_MOST].
##
## Shadow filtering keeps every shadow's width: Godot spreads a light's `shadow_blur` over a radius its quality sets,
## and [ShadowFilter] divides a light's blur by that radius as it is made, so the quality is written where
## ShadowFilter reads it before any light is made, and a light already made has its blur rescaled
## ([method _set_shadows]). Only positional lights': the sun's blur is set by hand.

## Where the choices are kept, in ghost.cfg.
const SECTION := "graphics"
const TIERS := ["live", "export"]

## The rows. `options`: [value, what a person reads], in order; `live` and `export`: each column's default - or
## `shared` and `default` for a row that is one choice for both, or `only` the one column that has it and `other`,
## what the other column's cell says.
const SETTINGS := {
	"resolution": {"label": "Resolution",
		"blurb": "How many lines the show is drawn at in the viewer, then scaled to the window whatever its size: 1080p is what it always drew. 4K is sharper on a 4K screen and four times the pixels - about three times the graphics card's work on a table; 720p is a little over half of it. An export is drawn at the size it is exported at, whatever is chosen here.",
		"options": [[720, "720p"], [1080, "1080p"], [1440, "1440p"], [2160, "4K"]], "only": "live", "live": 1080,
		"other": "its own size"},
	"supersample": {"label": "Supersampling",
		"blurb": "Draws the 3D larger and scales it down, so every pixel is the mean of several: glints on metal and glass, brush hairs, chains and thin lines stop shimmering, which multisampling (only the edges of shapes) cannot do. The cost grows with the square - 2x is four times the shading.",
		"options": [[1.0, "Off"], [1.5, "1.5x"], [2.0, "2x"]], "live": 1.0, "export": 1.5},
	"anisotropy": {"label": "Texture filtering",
		"blurb": "How sharp a texture stays across a slant: a table's painting toward its far side, words on a sheet lying flat, a desk's grain. Nearly free on a recent graphics card.",
		"options": [[1, "2x"], [2, "4x"], [3, "8x"], [4, "16x"]], "live": 2, "export": 4},
	"occlusion": {"label": "Ambient occlusion",
		"blurb": "The soft shade where things meet the cloth and each other (and bounce light, when it is on). Higher takes more samples at full size: smoother, and held to small things.",
		"options": [[2, "Medium (half size)"], [3, "High"], [4, "Ultra"]], "live": 2, "export": 4},
	"subsurface": {"label": "Subsurface scattering",
		"blurb": "Light carried under the surface of wax, skin, paper and stone. Higher takes more samples, so it spreads smoothly rather than in steps.",
		"options": [[1, "Low"], [2, "Medium"], [3, "High"]], "live": 1, "export": 3},
	"shadows": {"label": "Shadow filtering",
		"blurb": "How many taps soften a candle's or a lamp's shadow edge. The edge is as wide at either; more taps make it smoother.",
		"options": [[4, "High"], [5, "Ultra"]], "live": 4, "export": 5},
	"fog": {"label": "Fog detail",
		"blurb": "The grid the volumetric fog and its light shafts are worked out on. Finer is smoother, and costs as a cube.",
		"options": [[64, "Normal"], [96, "Fine"], [128, "Finest"]], "live": 64, "export": 128},
	"bounce": {"label": "Bounce light",
		"blurb": "CHANGES THE LOOK, so it is one choice for the viewer and the export: light falling on the cloth and the things bounces onto what is near them (screen-space indirect light) - a candle's pool on a red cloth tints the brass bowl over it. Only what is on screen bounces. Its quality is Ambient occlusion's.",
		"options": [[false, "Off"], [true, "On"]], "shared": true, "default": false},
}

## The most pixels the 3D is drawn at, supersampled: a 1080p export's 2880 x 1620 at 2x. A 4K export (drawn at its own
## size) takes 1.5x under it, and a large live window less: the buffers, multisampled four times, grow with the pixels.
const SUPERSAMPLE_MOST := 5760 * 3240

## The lines the live stage is drawn at by default: a pixel to a unit of the window's canvas, which is 1080 units high
## at any window (`display/window/stretch` in project.godot).
const LINES_AS_DRAWN := 1080

## Bounce light at a table's scale: Godot's own reach is 5 m, a room's; things on a table are a few centimeters to a few
## tens apart, and light from across the cloth reaches them.
const BOUNCE_REACH := 0.35
const BOUNCE_STRENGTH := 1.0

## Set by a probe, never by the app: a tier to draw at whatever the process is (`--graphics export`), and rows told
## outright (`--graphics supersample=2`), laid over the settings.
static var tier_override := ""
static var overrides := {}

static var _stage: WeakRef = null
static var _refit := Callable()      # what sizes the stage again when its resolution changes ([method bind_stage])
static var _measuring := {}          # who has asked for the stage's drawing time ([method measure]): a name -> true
static var _envs: Array = []         # WeakRefs of the environments the mediums handed in
## What this process's main thread last read of each row (its key in [constant SECTION]), for what is built on a worker:
## the settings' owner is a node of the tree, which a worker may not ask for (a table built away, `TablePreview._stand`,
## hands its environment to [method dress]). Read on the main thread, every row, as the stage is bound ([method apply]);
## it and [member _envs] are held by [member _lock].
static var _read := {}
static var _lock := Mutex.new()


## The column this process draws at: an export render's, else the live viewer's.
static func tier() -> String:
	if not tier_override.is_empty():
		return tier_override
	return "export" if exporting() else "live"


## Whether this process is an export's render ([Boot]'s own test).
static func exporting() -> bool:
	return OS.get_cmdline_user_args().has("--export")


## Where [param key]'s choice for [param t] is kept in [constant SECTION].
static func key_of(key: String, t: String) -> String:
	return key if bool(Registry.field(SETTINGS, key, "shared", false)) else "%s_%s" % [t, key]


## Whether [param key] is a choice at tier [param t]: a row `only` one column has is none in the other.
static func has_tier(key: String, t: String) -> bool:
	var only := String(Registry.field(SETTINGS, key, "only", ""))
	return only.is_empty() or only == t


## [param key]'s default for [param t] (null where the tier has no such choice).
static func default_of(key: String, t: String) -> Variant:
	var row := Registry.row(SETTINGS, key)
	return row.get("default") if bool(row.get("shared", false)) else row.get(t)


## [param key]'s values, in order.
static func values_of(key: String) -> Array:
	var out: Array = []
	for o in Registry.field(SETTINGS, key, "options", []):
		out.append((o as Array)[0])
	return out


## [param key]'s choice for [param t] (this process's tier when empty): a probe's override, else what is kept, else
## the default - and a kept value no option has any more is the default too. Null where the tier has no such choice.
static func value(key: String, t := "") -> Variant:
	if overrides.has(key):
		return overrides[key]
	if t.is_empty():
		t = tier()
	if not has_tier(key, t):
		return null
	var dflt: Variant = default_of(key, t)
	var k := key_of(key, t)
	var v: Variant = dflt
	_lock.lock()
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		# ...on a worker, what the main thread last read ([member _read])
		v = _read.get(k, dflt)
	else:
		var st := _settings()
		v = st.read(SECTION, k, dflt) if st != null else dflt
		_read[k] = v
	_lock.unlock()
	return v if values_of(key).has(v) else dflt


## The settings' owner (an autoload), or null where there is none (a `--script` run's first compile). The main thread's alone ([member _read]).
static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null


## The stage, handed by whoever builds it (`main._stage_host`, a probe): dressed now and whenever it is resized (the
## supersampling's cap is by its size), and everything else applied with it. [param refit] is what sizes it
## ([method stage_size]): called whenever a row is applied after, never from here - its owner sizes it once it has
## built what shows it.
static func bind_stage(stage: SubViewport, refit := Callable()) -> void:
	_stage = weakref(stage)
	if not stage.size_changed.is_connected(_dress_stage):
		stage.size_changed.connect(_dress_stage)
	_refit = Callable()
	apply()
	_refit = refit
	RenderingServer.viewport_set_measure_render_time(stage.get_viewport_rid(), not _measuring.is_empty())


static func stage() -> SubViewport:
	return _stage.get_ref() as SubViewport if _stage != null else null


## Everything as this process's tier has it: the renderer's globals, the stage, and every environment handed in.
## Called as the stage is bound, and by the panel whenever a row of this tier changes.
static func apply() -> void:
	# (every row read here, on the main thread, for what is built on a worker after - [member _read])
	for key in SETTINGS:
		value(String(key))
	var ao := int(value("occlusion"))
	var half := ao <= 2
	RenderingServer.environment_set_ssao_quality(ao as RenderingServer.EnvironmentSSAOQuality, half,
		_ps("ssao/adaptive_target", 0.5), int(_ps("ssao/blur_passes", 2)), _ps("ssao/fadeout_from", 50.0),
		_ps("ssao/fadeout_to", 300.0))
	RenderingServer.environment_set_ssil_quality(ao as RenderingServer.EnvironmentSSILQuality, half,
		_ps("ssil/adaptive_target", 0.5), int(_ps("ssil/blur_passes", 4)), _ps("ssil/fadeout_from", 50.0),
		_ps("ssil/fadeout_to", 300.0))
	RenderingServer.sub_surface_scattering_set_quality(int(value("subsurface")) as RenderingServer.SubSurfaceScatteringQuality)
	var fog := int(value("fog"))
	RenderingServer.environment_set_volumetric_fog_volume_size(fog, fog)
	_set_shadows(int(value("shadows")))
	_dress_stage()
	if _refit.is_valid():
		_refit.call()
	_lock.lock()
	var envs := _envs.duplicate()
	_lock.unlock()
	var gone: Array = []
	for w in envs:
		var env := (w as WeakRef).get_ref() as Environment
		if env != null:
			_bounce(env)
		else:
			gone.append(w)
	_lock.lock()
	for w in gone:
		_envs.erase(w)
	_lock.unlock()


static func _ps(name: String, dflt: float) -> float:
	return float(ProjectSettings.get_setting("rendering/environment/" + name, dflt))


## A medium's environment, handed as it is made (on a worker too, as a table is built away): bounce light set on it as
## the row has it, and again whenever the row changes. [param reach] and [param strength] are the medium's own, at its scale.
static func dress(env: Environment, reach := BOUNCE_REACH, strength := BOUNCE_STRENGTH) -> void:
	env.ssil_radius = reach
	env.ssil_intensity = strength
	_bounce(env)
	_lock.lock()
	var known := false
	for w in _envs:
		if (w as WeakRef).get_ref() == env:
			known = true
			break
	if not known:
		_envs.append(weakref(env))
	_lock.unlock()


static func _bounce(env: Environment) -> void:
	env.ssil_enabled = bool(value("bounce"))


## The stage's own settings: the supersampling (under [constant SUPERSAMPLE_MOST]) and the texture filtering.
static func _dress_stage() -> void:
	var st := stage()
	if st == null:
		return
	st.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	st.scaling_3d_scale = supersample_for(st.size, float(value("supersample")))
	st.anisotropic_filtering_level = int(value("anisotropy")) as Viewport.AnisotropicFiltering


## How many pixels the stage is drawn at where its frame is [param shown] units of the window's canvas large: that many
## in the live viewer unless its Resolution says otherwise, its shape kept; in an export the frame's own, always.
static func stage_size(shown: Vector2) -> Vector2i:
	var k := 1.0
	if has_tier("resolution", tier()):
		k = float(int(value("resolution"))) / float(LINES_AS_DRAWN)
	return Vector2i(maxi(1, roundi(shown.x * k)), maxi(1, roundi(shown.y * k)))


## The supersampling a stage of [param size] takes when [param want] is chosen: never past [constant SUPERSAMPLE_MOST]
## pixels, never under 1.
static func supersample_for(size: Vector2i, want: float) -> float:
	var px := float(maxi(size.x, 1) * maxi(size.y, 1))
	return clampf(minf(want, sqrt(SUPERSAMPLE_MOST / px)), 1.0, maxf(want, 1.0))


## The positional shadows' filter at quality [param q], every shadow as wide as it was (see the header).
static func _set_shadows(q: int) -> void:
	var was := clampi(int(ProjectSettings.get_setting(ShadowFilter.QUALITY_SETTING, 2)), 0, ShadowFilter.QUALITY_RADIUS.size() - 1)
	q = clampi(q, 0, ShadowFilter.QUALITY_RADIUS.size() - 1)
	ProjectSettings.set_setting(ShadowFilter.QUALITY_SETTING, q)
	RenderingServer.positional_soft_shadow_filter_set_quality(q as RenderingServer.ShadowQuality)
	if was == q or stage() == null:
		return
	var k := float(ShadowFilter.QUALITY_RADIUS[was]) / float(ShadowFilter.QUALITY_RADIUS[q])
	for n in stage().find_children("*", "Light3D", true, false):
		if (n is OmniLight3D or n is SpotLight3D) and (n as Light3D).shadow_enabled:
			(n as Light3D).shadow_blur *= k


## The stage's drawing time, for the panel while it is shown and for the governor while frames are slow ([param who]
## asks, [param on] or off; measured while anyone does), read as the last frame's GPU milliseconds, or -1 with no stage.
static func measure(on: bool, who := "panel") -> void:
	if on:
		_measuring[who] = true
	else:
		_measuring.erase(who)
	var st := stage()
	if st != null:
		RenderingServer.viewport_set_measure_render_time(st.get_viewport_rid(), not _measuring.is_empty())


static func stage_ms() -> float:
	var st := stage()
	return RenderingServer.viewport_get_measured_render_time_gpu(st.get_viewport_rid()) if st != null else -1.0

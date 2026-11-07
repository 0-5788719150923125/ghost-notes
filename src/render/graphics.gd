extends RefCounted
class_name Graphics

## Graphics - how finely the stage is drawn, live and in an export: the same picture, each at a quality of its own.
##
## WHAT IS DRAWN NEVER CHANGES WITH IT. A row is how finely the renderer draws what the show already is - how many
## samples a pixel takes, how far a texture is filtered across a slant, how many taps soften a shadow's edge or the
## ambient occlusion - never a light, a color or a place. The one row that changes the look, BOUNCE LIGHT, says so,
## is one choice for both (`shared`: an export must look as the viewer did), and is off until it is chosen.
##
## TWO COLUMNS, LIVE AND EXPORT (the user, 2026-11-06: "increase stuff like anisotropic filtering and supersampling at
## export-time, so that we don't harm realtime performance ... a proper graphics menu at the bottom-right"). The live
## viewer's defaults are the picture as it was drawn before this menu, so nothing is slower than it was; an export's
## are the finest each row offers, since a slow frame costs a render only time (Movie Maker writes one frame per step
## of show time however long it took) - BUT SUPERSAMPLING, 1.5x. Measured on a candlelit table (true-tarot 279427, its
## frame at 60 s, at a 1080p export's 2880 x 1620, the stage's GPU time): the live column 19.0 ms, the export's rows
## without supersampling 21.0, at 1.5x 38.5, at 2x 63.5. At 1080p, 1.5x took most of what 2x changed (0.21% of pixels
## off the unsupersampled frame by more than 16 levels, 2x 0.37%) for well under half the added time; the frame's
## brightness and its highlights were unchanged by either (a mean of 90.2 against 90.4). Both are chosen on the row's panel ([GraphicsPanel]) and kept in `[graphics]`
## as `live_<key>` and `export_<key>`; an export render reads ghost.cfg as every render does, and writes nothing.
##
## WHERE IT REACHES: the stage's own viewport ([method bind_stage]: supersampling, texture filtering) and the
## renderer's globals (ambient occlusion and bounce light's quality, subsurface scattering, shadow filtering, the fog's
## grid) - one process has one stage, so its globals are the stage's. A medium hands its environment to [method dress],
## which sets bounce light on it and keeps it, to set again when the row changes.
##
## AN EXPORT ALREADY SUPERSAMPLES THE WHOLE FRAME (exporter.gd's QUALITIES `ss`: 1080p is drawn at 2880 x 1620 and
## ffmpeg resolves it), held to 1.5x by the scratch file's size. The 3D's own supersampling here is resolved on the
## graphics card before the frame is written, so it costs the file nothing - only time and memory, the memory held
## under [constant SUPERSAMPLE_MOST].
##
## SHADOW FILTERING KEEPS EVERY SHADOW'S WIDTH: Godot spreads a light's `shadow_blur` over a radius its quality sets,
## and [ShadowFilter] divides a light's blur by that radius as it is made - so the quality is written where
## ShadowFilter reads it, before any light is made, and a light already made has its blur rescaled
## ([method _set_shadows]). Only the positional lights': the sun's blur is set by hand at the directional quality, which
## is left as it was.

## Where the choices are kept, in ghost.cfg.
const SECTION := "graphics"
const TIERS := ["live", "export"]

## THE ROWS. `options`: [value, what a person reads], in order; `live` and `export`: each column's default - or
## `shared` and `default` for a row that is one choice for both.
const SETTINGS := {
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

## THE MOST PIXELS THE 3D IS DRAWN AT, supersampled: a 1080p export's 2880 x 1620 at 2x, if 2x is chosen. A 4K export
## (drawn at its own size) takes 1.5x under it, and a large live window less: the buffers, multisampled four times,
## grow with the pixels, on a card a voice's training may share.
const SUPERSAMPLE_MOST := 5760 * 3240

## BOUNCE LIGHT AT A TABLE'S SCALE: Godot's own reach is 5 m, a room's; things on a table are a few centimeters to a
## few tens apart, and light from across the cloth reaches them.
const BOUNCE_REACH := 0.35
const BOUNCE_STRENGTH := 1.0

## Set by a probe, never by the app: a tier to draw at whatever the process is (`--graphics export`), and rows told
## outright (`--graphics supersample=2`), laid over the settings.
static var tier_override := ""
static var overrides := {}

static var _stage: WeakRef = null
static var _envs: Array = []         # WeakRefs of the environments the mediums handed in


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


## [param key]'s default for [param t].
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
## the default - and a kept value no option has any more is the default too.
static func value(key: String, t := "") -> Variant:
	if overrides.has(key):
		return overrides[key]
	if t.is_empty():
		t = tier()
	var dflt: Variant = default_of(key, t)
	var v: Variant = _settings().read(SECTION, key_of(key, t), dflt) if _settings() != null else dflt
	return v if values_of(key).has(v) else dflt


## The settings' owner (an autoload), or null where there is none (a `--script` run's first compile).
static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null


## THE STAGE, handed by whoever builds it ([code]main._stage_host[/code], a probe): dressed now and whenever it is
## resized (the supersampling's cap is by its size), and everything else applied with it.
static func bind_stage(stage: SubViewport) -> void:
	_stage = weakref(stage)
	if not stage.size_changed.is_connected(_dress_stage):
		stage.size_changed.connect(_dress_stage)
	apply()


static func stage() -> SubViewport:
	return _stage.get_ref() as SubViewport if _stage != null else null


## EVERYTHING AS THIS PROCESS'S TIER HAS IT: the renderer's globals, the stage, and every environment handed in.
## Called as the stage is bound, and by the panel whenever a row of this tier changes.
static func apply() -> void:
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
	var kept: Array = []
	for w in _envs:
		var env := (w as WeakRef).get_ref() as Environment
		if env != null:
			_bounce(env)
			kept.append(w)
	_envs = kept


static func _ps(name: String, dflt: float) -> float:
	return float(ProjectSettings.get_setting("rendering/environment/" + name, dflt))


## A MEDIUM'S ENVIRONMENT, handed as it is made: bounce light set on it as the row has it, and again whenever the
## row changes. [param reach] and [param strength] are the medium's own, at its scale.
static func dress(env: Environment, reach := BOUNCE_REACH, strength := BOUNCE_STRENGTH) -> void:
	env.ssil_radius = reach
	env.ssil_intensity = strength
	_bounce(env)
	for w in _envs:
		if (w as WeakRef).get_ref() == env:
			return
	_envs.append(weakref(env))


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


## The supersampling a stage of [param size] takes when [param want] is chosen: never past [constant SUPERSAMPLE_MOST]
## pixels, never under 1.
static func supersample_for(size: Vector2i, want: float) -> float:
	var px := float(maxi(size.x, 1) * maxi(size.y, 1))
	return clampf(minf(want, sqrt(SUPERSAMPLE_MOST / px)), 1.0, maxf(want, 1.0))


## THE POSITIONAL SHADOWS' FILTER at quality [param q], every shadow as wide as it was (see the header).
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


## THE STAGE'S DRAWING TIME, for the panel: turned on while it is shown ([param on]), read as the last frame's GPU
## milliseconds - what these rows cost - or -1 with no stage.
static func measure(on: bool) -> void:
	var st := stage()
	if st != null:
		RenderingServer.viewport_set_measure_render_time(st.get_viewport_rid(), on)


static func stage_ms() -> float:
	var st := stage()
	return RenderingServer.viewport_get_measured_render_time_gpu(st.get_viewport_rid()) if st != null else -1.0

extends RefCounted
class_name Filters

## Filters - the look the whole picture is put through, after the scenes have drawn.
##
## Scenes draw into one [SubViewport] that main presents through a single [TextureRect] at child index 0,
## with every panel and the karaoke overlay above it on their own CanvasLayers. A material on that rect
## is a post-process over the whole show and nothing else: no extra render target or pass, no change to a
## scene, and the UI stays legible. Subtitles are not filtered (grain over a karaoke line is hard to
## read, and a caption is not part of the photograph).
##
## Filters combine, so this is a registry of amounts, not a picker: every entry has its own 0..1 dial and
## all are applied in one fragment shader in one pass. A filter at 0 is arithmetically a no-op, and when
## every filter is at 0 the material is removed from the rect, so the default show runs the code it
## always ran.
##
## The registry order is the pipeline order, top to bottom, and cannot be read off the shader: dots first
## (they re-sample the picture, so anything after grades the dots), then the optics a lens adds, the
## grade, the emulsion, the frame. Monochrome before Noir makes the pair read as black-and-white noir,
## since Noir's split-tone is applied to whatever it is handed.
##
## Adding a filter is a row of [constant REGISTRY], a `u_<key>` uniform and a block in
## [code]shaders/stage_filter.gdshader[/code]; the controls are built off the registry. A key with no
## matching uniform is a silent no-op in `set_shader_parameter`; the gate reads the shader source and
## fails on it.

const SHADER := "res://shaders/stage_filter.gdshader"

## The registry, in pipeline order: one row a filter (next/structure.md).
##
##   label    its name, on the Look card and in docs/filters.md
##   uniform  the shader uniform its amount drives
##   default  where its dial lands the first time it is switched on. Not 1.0: the top of every range is
##            deliberately too much, so an unfamiliar filter at full strength would read as broken.
##   blurb    one line, for the checkbox's tooltip and docs/filters.md; one string literal, not a `+`
##            continuation, so docs.py reads it whole
##
## Keys are what `[director] filters` in `user://ghost.cfg` stores and what `--filter KEY=AMOUNT` takes.
const REGISTRY := {
	"slip": {"label": "Gate slip", "uniform": "u_slip", "default": 0.45,
		"blurb": "Tearing: now and then a band of the picture jumps sideways for one frame and snaps back, the way a frame that does not seat squarely in a projector's gate is printed offset. The dial is how often and how far."},
	"pointillism": {"label": "Pointillism", "uniform": "u_pointillism", "default": 0.35,
		"blurb": "The picture re-laid as overlapping dots of paint on a jittered lattice, each dot taking its color from where it sits and its size from how bright that is. The dial is the size of the dots, so a little is a canvas texture and a lot is a painting you have to stand back from."},
	"bloom": {"label": "Bloom", "uniform": "u_bloom", "default": 0.45,
		"blurb": "Light bleeding out of the bright parts, the way it does through a lens. Only what is already brighter than the picture's own highlights blooms, so it lifts lamps, sparks and speculars without fogging the whole frame."},
	"monochrome": {"label": "Monochrome", "uniform": "u_monochrome", "default": 1.0,
		"blurb": "Color taken out, weighted the way the eye weighs it rather than by averaging the channels - so a red and a green of the same brightness do not come out as the same gray."},
	"noir": {"label": "Film noir", "uniform": "u_noir", "default": 0.55,
		"blurb": "The hard grade: contrast pushed until the blacks close up and the highlights burn, with cold shadows against warm highlights. It grades whatever it is handed, so put Monochrome above it for black-and-white and leave it off for something closer to Technicolor."},
	"static": {"label": "Static", "uniform": "u_static", "default": 0.4,
		"blurb": "Fine noise over the picture, strongest in the midtones and nearly absent in the blacks and the blown highlights, where the emulsion's own noise lives, and it moves at a film's frame rate."},
	"dust": {"label": "Dust & scratches", "uniform": "u_dust", "default": 0.45,
		"blurb": "Dirt on the print: specks of dust (mostly dark, some light), the odd curled hair, and now and then a scratch down the frame that holds for a moment and wanders. It changes every film frame, the way dirt on a moving print does."},
	"vignette": {"label": "Vignette", "uniform": "u_vignette", "default": 0.45,
		"blurb": "The corners fallen off, as a fast lens does wide open. Measured on the frame's own diagonal, so it is the same shape of falloff on a phone clip as on a widescreen render."},
}


## Every registry key, in pipeline order.
static func keys() -> Array:
	return REGISTRY.keys()


## A stored dictionary cleaned up: known keys only, every amount a float in 0..1, anything at zero
## dropped so "is anything on" is `is_empty`. Everything that reads a filter set goes through here, so a
## key removed from the registry degrades to "that filter is off" rather than a null uniform write.
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	# "grain" is this filter's old name; a setting or chapter that has it keeps its amount
	if (raw as Dictionary).has("grain") and not (raw as Dictionary).has("static"):
		raw = (raw as Dictionary).duplicate()
		raw["static"] = raw["grain"]
	for k in REGISTRY:
		if not (raw as Dictionary).has(k):
			continue
		var v := clampf(float((raw as Dictionary)[k]), 0.0, 1.0)
		if v > 0.0:
			out[k] = v
	return out


## Put the look on the picture. [param rect] is main's stage view, [param amounts] a sanitized set,
## [param size] the rect's pixel size.
##
## Nothing on means no material, not a material with every dial at zero: the picture is the same, but
## the default show runs the code it always ran, and that is checkable. The material is reused across
## calls, as rebuilding it re-compiles the shader on every step of a dial drag.
static func apply(rect: CanvasItem, amounts: Dictionary, size: Vector2) -> void:
	if rect == null or not is_instance_valid(rect):
		return
	var live := sanitize(amounts)
	if live.is_empty():
		rect.material = null
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load(SHADER)
		rect.material = mat
	# Every uniform, every time, including those at zero: writing only the live ones leaves a filter
	# just switched off burning at its old amount.
	for k in REGISTRY:
		mat.set_shader_parameter(String(REGISTRY[k]["uniform"]), float(live.get(k, 0.0)))
	# The dot lattice and the grain are sized in pixels, so they need the frame's real size; in UV a dot
	# would get coarser as the window grows.
	mat.set_shader_parameter("u_size", size)


## The one-run override: `--filter monochrome=1,static=0.3` (or `--filter none`). Like `--medium`, for a
## gate that must pin a look without touching the author's settings and for a render of a session that
## was not the remembered one. Returns null when the flag is absent, so a caller can tell "no override"
## from "override to nothing".
static func from_args(args: PackedStringArray) -> Variant:
	var i := args.find("--filter")
	if i < 0 or i + 1 >= args.size():
		return null
	var spec := String(args[i + 1])
	if spec == "none":
		return {}
	var out := {}
	for part in spec.split(",", false):
		var bits := String(part).split("=")
		var key := String(bits[0]).strip_edges()
		if not REGISTRY.has(key):
			push_warning("ghost: --filter %s is not a known filter - ignored" % key)
			continue
		out[key] = clampf(float(bits[1]) if bits.size() > 1 else 1.0, 0.0, 1.0)
	return sanitize(out)


## "Monochrome 100%, Grain 40%", or "none" - for a status line and a tooltip.
static func describe(amounts: Dictionary) -> String:
	var live := sanitize(amounts)
	if live.is_empty():
		return "none"
	var parts: Array = []
	for k in REGISTRY:
		if live.has(k):
			parts.append("%s %d%%" % [Registry.label(REGISTRY, k), int(round(float(live[k]) * 100.0))])
	return ", ".join(parts)

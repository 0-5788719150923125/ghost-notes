extends RefCounted
class_name Ornaments

## Ornaments - a surface written by an agent (next/surfaces.md): the body of one shader function in
## `shaders/prop_common.gdshaderinc`, one of [constant HOOKS] - an ORNAMENT ([Props] `ornament` of its own: a surface's relief and
## where its paint or inlay goes at each point of a cell laid out round a part) or a TEXTURE (a material's `texture` of its own: its
## relief, roughness and second color all over it, in the thing's own space). Checked before it is compiled ([method check]), then
## compiled into a variant of the shader the material uses ([method shader_for]), kept once a process by what it is. What it may call
## is [constant HELPERS] and GLSL's own math.
##
## Never `TIME` (a render and a scrub agree), never the screen or a texture, no loop past [constant LOOP_MOST] turns, at most
## [constant LOOPS] loops, nothing longer than [constant LONGEST]: a surface is drawn on every pixel of every frame. What compiles
## and what does not is the renderer's to say ([method compile_errors], told back to the agent line by line in its own code).

## What an agent writes the body of: each the function (its `label`), what it is (`blurb`), what its body takes the place of in the
## shader (`mark`), the names it reads (`reads`), how it ends (`ends`) and what it is called where it is told of (`noun`).
const ORNAMENT := "ornament"
const TEXTURE := "texture"
const HOOKS := {
	"ornament": {"label": "vec2 own_ornament(vec2 p, vec2 cell, vec2 uv, float s)",
		"blurb": "an ornament: relief, and where its color is laid, cell by cell round a part",
		"mark": "return vec2(0.0); // OWN ORNAMENT", "reads": "p, cell, uv and s", "ends": "return vec2(relief, paint);", "noun": "an ornament"},
	"texture": {"label": "vec3 own_texture(vec3 p, vec3 n, float s)",
		"blurb": "a texture: relief, roughness and a second color all over a material, in the thing's own space",
		"mark": "return vec3(0.5, 0.0, 0.0); // OWN TEXTURE", "reads": "p, n and s", "ends": "return vec3(relief, rough, tint);", "noun": "a texture"},
}
## An ornament's function and its mark: [constant HOOKS] `ornament`'s.
const SIGNATURE := "vec2 own_ornament(vec2 p, vec2 cell, vec2 uv, float s)"
const MARK := "return vec2(0.0); // OWN ORNAMENT"
const COMMON := "res://shaders/prop_common.gdshaderinc"
const INCLUDE := "#include \"res://shaders/prop_common.gdshaderinc\""
## The most characters a body has, loops it holds and turns a loop makes.
const LONGEST := 4000
const LOOPS := 2
const LOOP_MOST := 16
## Words a body may not hold: what loops without end, reads the screen, a texture or the clock, declares what a shader declares,
## or reaches past its own value.
const BANNED := ["while", "do", "discard", "uniform", "varying", "texture", "textureLod", "texelFetch", "textureSize", "shader_type",
	"render_mode", "void", "TIME", "out", "inout"]
## The capitals a body may name: the constants GLSL has.
const CAPS := ["PI", "TAU", "E"]
## What a body may call beside GLSL's own math (`sin`, `mix`, `smoothstep`, `abs`, `fract`, `atan`, `length`...): each its call and
## what it gives.
const HELPERS := {
	"sd_circle": {"label": "sd_circle(p, r)", "blurb": "the distance from p to a circle of radius r round the middle, negative inside"},
	"sd_box": {"label": "sd_box(p, half_size)", "blurb": "the distance from p to a box round the middle, half_size its half width and half height, negative inside"},
	"sd_segment": {"label": "sd_segment(p, a, b)", "blurb": "the distance from p to the straight line from a to b"},
	"sd_spiral": {"label": "sd_spiral(p, gap, turns)", "blurb": "the distance from p to a spiral winding out from the middle, its arms gap apart, turns round at most"},
	"star5": {"label": "star5(p, r, inner)", "blurb": "the distance from p to a five-pointed star, r its points' reach and inner its waist's (a share of r), negative inside"},
	"rot": {"label": "rot(p, a)", "blurb": "p turned a radians about the middle"},
	"stroke": {"label": "stroke(d, w)", "blurb": "a line w wide along distance d, 1 on it and fading to 0 at its edge"},
	"fill": {"label": "fill(d)", "blurb": "1 inside a shape whose distance is d, 0 outside, soft at the edge"},
	"vnoise": {"label": "vnoise(vec3 q)", "blurb": "smooth noise 0..1"},
	"fbm": {"label": "fbm(vec3 q)", "blurb": "noise 0..1 with finer noise over it"},
	"hash3": {"label": "hash3(vec3 q)", "blurb": "a number 0..1 that never repeats, the same for the same q"},
	"cellsid": {"label": "cellsid(vec3 q)", "blurb": "cells scattered through space about 1 across: a vec3 of the distance to the nearest cell's middle, to the next nearest's (the two close together on the line between cells) and the nearest cell's own number 0..1 - pits, plates and their cracks, grains, scales, pebbles"},
	"near_cell": {"label": "near_cell(vec3 q, to)", "blurb": "what cellsid gives, and `to` (a vec3 declared before the call) set to the way from q to the nearest cell's middle - a facet tipped its own way, a scallop hollowed round its middle"},
}
## How many shaders are kept at once, by what they are.
const KEPT := 64

static var _shaders := {}
static var _lock := Mutex.new()


## Why [param code] cannot be the body of [param of] (one of [constant HOOKS]), "" when it can be compiled: empty, too long, a word it
## may not hold, a loop it may not run, its braces unbalanced, or no `return`.
static func check(code: String, of := ORNAMENT) -> String:
	var noun := String(Registry.field(HOOKS, of, "noun", "an ornament"))
	var body := _bare(code)
	if body.strip_edges().is_empty():
		return "it is empty"
	if code.length() > LONGEST:
		return "it is %d characters long; %s is at most %d" % [code.length(), noun, LONGEST]
	if body.contains("#"):
		return "it has a `#`: %s includes and defines nothing" % noun
	for w in BANNED:
		if RegEx.create_from_string("\\b%s\\b" % w).search(body) != null:
			return "it uses `%s`, which %s may not" % [w, noun]
	for m in RegEx.create_from_string("\\b[A-Z][A-Z0-9_]{1,}\\b").search_all(body):
		if not m.get_string() in CAPS:
			return "it names `%s`: %s reads only its own %s" % [m.get_string(), noun, String(Registry.field(HOOKS, of, "reads", ""))]
	var loops := RegEx.create_from_string("\\bfor\\b").search_all(body).size()
	if loops > LOOPS:
		return "it has %d loops; %s has at most %d" % [loops, noun, LOOPS]
	var bounded := RegEx.create_from_string("\\bfor\\s*\\(\\s*int\\s+(\\w+)\\s*=\\s*\\d+\\s*;\\s*\\1\\s*<=?\\s*(\\d+)\\s*;\\s*(\\+\\+\\1|\\1\\+\\+|\\1\\s*\\+=\\s*1)\\s*\\)")
	var found := bounded.search_all(body)
	if found.size() != loops:
		return "a loop must count an int from a number up to a number, one at a time: for (int i = 0; i < 8; i++)"
	for m in found:
		if int(m.get_string(2)) > LOOP_MOST:
			return "a loop runs to %s; its loops run at most %d times" % [m.get_string(2), LOOP_MOST]
	if body.count("{") != body.count("}") or body.count("(") != body.count(")"):
		return "its braces or brackets do not balance"
	if RegEx.create_from_string("\\breturn\\b").search(body) == null:
		return "it never returns: it ends with " + String(Registry.field(HOOKS, of, "ends", ""))
	return ""


## [param code] without its comments: what [method check] reads.
static func _bare(code: String) -> String:
	var out := RegEx.create_from_string("(?s)/\\*.*?\\*/").sub(code, " ", true)
	return RegEx.create_from_string("//[^\\n]*").sub(out, "", true)


## The source of [param base] (a prop shader that includes prop_common) with [param code] written as its ornament's body and
## [param texture] as its texture's (either "" for the plain one).
static func source_for(base: Shader, code: String, texture := "") -> String:
	var common := (load(COMMON) as ShaderInclude).code
	if not code.strip_edges().is_empty():
		common = common.replace(MARK, "\n" + code.strip_edges() + "\n")
	if not texture.strip_edges().is_empty():
		common = common.replace(String(Registry.field(HOOKS, TEXTURE, "mark", "")), "\n" + texture.strip_edges() + "\n")
	return base.code.replace(INCLUDE, common)


## The variant of [param base] whose ornament is [param code] and whose texture is [param texture] (either "" for the plain one),
## compiled once a process (each built from any thread, under a lock): each body that does not pass [method check] left plain, and
## [param base] itself where both are.
static func shader_for(base: Shader, code: String, texture := "") -> Shader:
	if not code.is_empty() and not check(code).is_empty():
		code = ""
	if not texture.is_empty() and not check(texture, TEXTURE).is_empty():
		texture = ""
	if code.is_empty() and texture.is_empty():
		return base
	var key := "%s|%s|%s" % [base.resource_path, code.sha256_text(), texture.sha256_text()]
	_lock.lock()
	var sh: Shader = _shaders.get(key)
	if sh == null:
		if _shaders.size() >= KEPT:
			_shaders.clear()
		sh = Shader.new()
		sh.code = source_for(base, code, texture)
		_shaders[key] = sh
	_lock.unlock()
	return sh


## What the renderer says is wrong with [param code] compiled into the opaque prop shader as the body of [param of] (one of [constant
## HOOKS]), each error at its line in the code: "" for nothing wrong - or for nothing the renderer can say, where there is none (a
## headless process). [method check]'s answer first.
static func compile_errors(code: String, of := ORNAMENT) -> String:
	var why := check(code, of)
	if not why.is_empty():
		return why
	if DisplayServer.get_name() == "headless":
		return ""
	var base: Shader = load("res://shaders/prop.gdshader")
	var src := source_for(base, code if of == ORNAMENT else "", code if of == TEXTURE else "")
	var first := src.substr(0, src.find(code.strip_edges())).count("\n") + 1
	var listen := Listen.new()
	OS.add_logger(listen)
	var sh := Shader.new()
	sh.code = src
	var uniforms := sh.get_shader_uniform_list().size()
	OS.remove_logger(listen)
	if uniforms > 0 and listen.errors.is_empty():
		return ""
	var lines := code.strip_edges().split("\n")
	var out := PackedStringArray()
	for e in listen.errors:
		out.append(String(e))
	for at in listen.lines:
		var n := int(at) - first + 1
		if n >= 1 and n <= lines.size():
			out.append("line %d of your code: %s" % [n, lines[n - 1].strip_edges()])
	return "; ".join(out) if not out.is_empty() else "it does not compile"


## What the renderer says while a shader compiles: its errors, and the lines it marks as where they are.
class Listen extends Logger:
	var errors := PackedStringArray()
	var lines := PackedInt32Array()
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array) -> void:
		var said := code if not code.is_empty() else rationale
		if said.is_empty() or said.begins_with("Method/function failed") or said.contains("Shader compilation failed"):
			return
		_lock.lock()
		errors.append(said.strip_edges())
		_lock.unlock()

	func _log_message(message: String, _error: bool) -> void:
		# the renderer marks the line an error is at: "E  12->  ..."
		var m := RegEx.create_from_string("^E\\s+(\\d+)->").search(message)
		if m != null:
			_lock.lock()
			lines.append(int(m.get_string(1)))
			_lock.unlock()


## The language of [param of] (one of [constant HOOKS]) as an agent reads it: the function, what it is handed and gives, what it may
## call and what it may not.
static func describe(of := ORNAMENT) -> String:
	var lines := PackedStringArray()
	if of == TEXTURE:
		lines.append("A TEXTURE OF ITS OWN is the body of one shader function, %s, in the shading language of Godot 4 (GLSL)." % Registry.label(HOOKS, TEXTURE))
		lines.append("It covers a material all over, as stone, wood, plaster or leather is textured: `p` is where the point is in the thing's own space, in units of the texture's size (the material's `texture_size`, centimeters; one unit is one feature - a grain, a pit, a brick), y up; `n` the way the surface faces there, in the same space, unit length (for laying a pattern on the face it lies nearest, as bricks are); `s` the part's own number, 0 to 1. Nothing tiles or seams: noise read at `p` is the same where faces meet.")
		lines.append("It returns vec3(relief, rough, tint): relief 0 to 1 how high the surface stands there (0 its deepest hollow; how deep the whole is, the material's `bumps` says), rough -1 to 1 how much rougher (above 0) or glossier (below 0) than its material it is there - a polished peak, a dull hollow, a patch of grime - and tint 0 to 1 how much of the material's second color (`color2`) shows there: mortar, dirt in pits, moss in cracks, a darker grain. Its hollows come out a little darker of themselves. A feature much finer than its size fades into roughness where the camera is far.")
	else:
		lines.append("AN ORNAMENT OF ITS OWN is the body of one shader function, %s, in the shading language of Godot 4 (GLSL)." % SIGNATURE)
		lines.append("It is laid out in cells round the part, as wide round it as they are tall: `p` is where the point is in its cell, x and y from -0.5 to 0.5, (0, 0) the middle, y up the part; `cell` which cell (its column round the part, its row up it, whole numbers); `uv` where it is round the part and up the ornament's band, 0 to 1 each; `s` the part's own number, 0 to 1.")
		lines.append("It returns vec2(relief, paint): relief 0 to 1 how far the surface stands out there (0 the plain surface), paint 0 to 1 where an ornament's color is laid (paint or inlay; with no color the relief alone shows). Keep shapes inside the cell where they should join their neighbors, so the pattern runs on unbroken.")
	lines.append("Beside GLSL's math (sin, cos, atan, length, abs, fract, floor, mod, mix, clamp, smoothstep, step, min, max, pow, sqrt, dot) it may call:")
	for k in HELPERS:
		lines.append("- %s: %s" % [Registry.label(HELPERS, k), Registry.blurb(HELPERS, k)])
	lines.append("It may not use %s, any other name in capitals, or a texture image; at most %d loops, each counting an int up to at most %d (for (int i = 0; i < 8; i++)); at most %d characters." % [
		", ".join(PackedStringArray(BANNED)), LOOPS, LOOP_MOST, LONGEST])
	return "\n".join(lines)

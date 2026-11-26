extends RefCounted
class_name Ornaments

## Ornaments - an ornament written by an agent ([Props] `ornament` of its own, next/surfaces.md): the body of one shader function,
## `own_ornament` in `shaders/prop_common.gdshaderinc` ([constant SIGNATURE]), which gives a surface's relief and where its paint or
## inlay goes at each point of a cell laid out round a part. Checked before it is compiled ([method check]), then compiled into a
## variant of the shader the material uses ([method shader_for]), kept once a process by what it is. What it may call is [constant
## HELPERS] and GLSL's own math.
##
## Never `TIME` (a render and a scrub agree), never the screen or a texture, no loop past [constant LOOP_MOST] turns, at most
## [constant LOOPS] loops, nothing longer than [constant LONGEST]: a surface is drawn on every pixel of every frame. What compiles
## and what does not is the renderer's to say ([method compile_errors], told back to the agent line by line in its own code).

## The function an agent writes the body of, and what its body takes the place of in the shader.
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
}
## How many shaders are kept at once, by what they are.
const KEPT := 64

static var _shaders := {}
static var _lock := Mutex.new()


## Why [param code] cannot be an ornament's body, "" when it can be compiled: empty, too long, a word it may not hold, a loop it may
## not run, its braces unbalanced, or no `return`.
static func check(code: String) -> String:
	var body := _bare(code)
	if body.strip_edges().is_empty():
		return "it is empty"
	if code.length() > LONGEST:
		return "it is %d characters long; an ornament is at most %d" % [code.length(), LONGEST]
	if body.contains("#"):
		return "it has a `#`: an ornament includes and defines nothing"
	for w in BANNED:
		if RegEx.create_from_string("\\b%s\\b" % w).search(body) != null:
			return "it uses `%s`, which an ornament may not" % w
	for m in RegEx.create_from_string("\\b[A-Z][A-Z0-9_]{1,}\\b").search_all(body):
		if not m.get_string() in CAPS:
			return "it names `%s`: an ornament reads only its own p, cell, uv and s" % m.get_string()
	var loops := RegEx.create_from_string("\\bfor\\b").search_all(body).size()
	if loops > LOOPS:
		return "it has %d loops; an ornament has at most %d" % [loops, LOOPS]
	var bounded := RegEx.create_from_string("\\bfor\\s*\\(\\s*int\\s+(\\w+)\\s*=\\s*\\d+\\s*;\\s*\\1\\s*<=?\\s*(\\d+)\\s*;\\s*(\\+\\+\\1|\\1\\+\\+|\\1\\s*\\+=\\s*1)\\s*\\)")
	var found := bounded.search_all(body)
	if found.size() != loops:
		return "a loop must count an int from a number up to a number, one at a time: for (int i = 0; i < 8; i++)"
	for m in found:
		if int(m.get_string(2)) > LOOP_MOST:
			return "a loop runs to %s; an ornament's loops run at most %d times" % [m.get_string(2), LOOP_MOST]
	if body.count("{") != body.count("}") or body.count("(") != body.count(")"):
		return "its braces or brackets do not balance"
	if RegEx.create_from_string("\\breturn\\b").search(body) == null:
		return "it never returns: it ends with return vec2(relief, paint);"
	return ""


## [param code] without its comments: what [method check] reads.
static func _bare(code: String) -> String:
	var out := RegEx.create_from_string("(?s)/\\*.*?\\*/").sub(code, " ", true)
	return RegEx.create_from_string("//[^\\n]*").sub(out, "", true)


## The source of [param base] (a prop shader that includes prop_common) with [param code] written as its ornament's body.
static func source_for(base: Shader, code: String) -> String:
	var common := (load(COMMON) as ShaderInclude).code
	return base.code.replace(INCLUDE, common.replace(MARK, "\n" + code.strip_edges() + "\n"))


## The variant of [param base] whose ornament is [param code], compiled once a process (each built from any thread, under a lock):
## [param base] itself for a body that does not pass [method check].
static func shader_for(base: Shader, code: String) -> Shader:
	if not check(code).is_empty():
		return base
	var key := "%s|%s" % [base.resource_path, code.sha256_text()]
	_lock.lock()
	var sh: Shader = _shaders.get(key)
	if sh == null:
		if _shaders.size() >= KEPT:
			_shaders.clear()
		sh = Shader.new()
		sh.code = source_for(base, code)
		_shaders[key] = sh
	_lock.unlock()
	return sh


## What the renderer says is wrong with [param code] compiled into the opaque prop shader, each error at its line in the code: "" for
## nothing wrong - or for nothing the renderer can say, where there is none (a headless process). [method check]'s answer first.
static func compile_errors(code: String) -> String:
	var why := check(code)
	if not why.is_empty():
		return why
	if DisplayServer.get_name() == "headless":
		return ""
	var base: Shader = load("res://shaders/prop.gdshader")
	var src := source_for(base, code)
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


## The ornament language as an agent reads it: the function, what it is handed and gives, what it may call and what it may not.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("AN ORNAMENT OF ITS OWN is the body of one shader function, %s, in the shading language of Godot 4 (GLSL)." % SIGNATURE)
	lines.append("It is laid out in cells round the part, as wide round it as they are tall: `p` is where the point is in its cell, x and y from -0.5 to 0.5, (0, 0) the middle, y up the part; `cell` which cell (its column round the part, its row up it, whole numbers); `uv` where it is round the part and up the ornament's band, 0 to 1 each; `s` the part's own number, 0 to 1.")
	lines.append("It returns vec2(relief, paint): relief 0 to 1 how far the surface stands out there (0 the plain surface), paint 0 to 1 where an ornament's color is laid (paint or inlay; with no color the relief alone shows). Keep shapes inside the cell where they should join their neighbors, so the pattern runs on unbroken.")
	lines.append("Beside GLSL's math (sin, cos, atan, length, abs, fract, floor, mod, mix, clamp, smoothstep, step, min, max, pow, sqrt, dot) it may call:")
	for k in HELPERS:
		lines.append("- %s: %s" % [Registry.label(HELPERS, k), Registry.blurb(HELPERS, k)])
	lines.append("It may not use %s, any other name in capitals, or a texture; at most %d loops, each counting an int up to at most %d (for (int i = 0; i < 8; i++)); at most %d characters." % [
		", ".join(PackedStringArray(BANNED)), LOOPS, LOOP_MOST, LONGEST])
	return "\n".join(lines)

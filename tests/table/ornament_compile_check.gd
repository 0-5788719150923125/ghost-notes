extends SceneTree

## ornament_compile_check - an ornament written by an agent compiled and drawn by the real renderer ([Ornaments], [OrnamentTools];
## next/surfaces.md). Needs a GPU.
##
##   tests/run_quiet.sh -- res://tests/table/ornament_compile_check.gd
##
## shader errors: 1
##
## - Every prop shader compiles with the ornament's hook in it (the opaque, the glass and the lens).
## - A body that draws compiles into a variant with every uniform its shader has, and the renderer finds nothing wrong with it.
## - A body that does not compile is told back at its own line (control: the same body called right compiles).
## - Its swatch is built and photographed as any prop is: the picture is no flat field.

const GOOD := "vec2 q = rot(p, 0.3);\nfloat d = sd_spiral(q, 0.09, 2.5);\nfloat h = stroke(d, 0.035);\nreturn vec2(h, h);"
const BROKEN := "float d = sd_spiral(p, 0.09);\nreturn vec2(d, d);"
const MENDED := "float d = sd_spiral(p, 0.09, 2.0);\nreturn vec2(d, d);"
const DIR := "user://ornament_compile_check"

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	for p in ["res://shaders/prop.gdshader", "res://shaders/prop_glass.gdshader", "res://shaders/prop_lens.gdshader"]:
		var sh := Shader.new()
		sh.code = (load(p) as Shader).code
		_ok(sh.get_shader_uniform_list().size() > 0, "%s compiles with the ornament's hook" % p)
	var base: Shader = load("res://shaders/prop.gdshader")
	var plain := Shader.new()
	plain.code = base.code
	var variant := Ornaments.shader_for(base, GOOD)
	_ok(variant != base and variant.get_shader_uniform_list().size() == plain.get_shader_uniform_list().size(),
		"a body that draws compiles into a variant with every uniform (%d of %d)" % [variant.get_shader_uniform_list().size(), plain.get_shader_uniform_list().size()])
	_ok(Ornaments.compile_errors(GOOD).is_empty(), "the renderer finds nothing wrong with it: %s" % Ornaments.compile_errors(GOOD))
	var why := Ornaments.compile_errors(BROKEN)
	_ok(why.contains("line 1 of your code") and why.contains("sd_spiral"), "a body that does not compile is told at its own line: %s" % why)
	_ok(Ornaments.compile_errors(MENDED).is_empty(), "the control: the same body called right compiles")
	var sw := OrnamentLibrary.swatch(GOOD)
	var paths: Array = await PropStudio.views(sw["thing"], sw["materials"], GOOD.sha256_text().left(16), ProjectSettings.globalize_path(DIR))
	var img: Image = Image.load_from_file(String(paths[0])) if not paths.is_empty() else null
	var spread := 0.0
	if img != null:
		var lo := 1.0
		var hi := 0.0
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				var v := img.get_pixel(x, y).get_luminance()
				lo = minf(lo, v)
				hi = maxf(hi, v)
		spread = hi - lo
	_ok(img != null and spread > 0.2, "its swatch is photographed, no flat field (spread %.2f)" % spread)
	for p in paths:
		DirAccess.remove_absolute(String(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("ornament_compile_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)

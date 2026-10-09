extends Node

## Gate for THE FRAME'S FOIL: it lies on the frame's lines, never along their edges.
##
## The foil shader ([constant TableMedium.FOIL_SHADER]) keys the frame's accent by its distance from
## the face's texel, and the face is sampled LINEAR (`source_color`). The accent went over in sRGB, so
## for the 1327 export's deck (accent #a8602a on #e6d9b4) a line's own color stood 0.40 from it - no
## foil at all - while a texel blended ~60% toward the stock, the line's anti-aliased edge, stood 0.06
## from it: full foil. Every bracket drew as a dark line with a bright, metallic, emissive fringe one
## texel wide down each side, stair-stepped and crawling as the held card breathed - reported as bad
## aliasing at the corners in the export (2026-10-09). The stock had the same fault and the same fix
## (feedback 0005, [method TableMedium._foil_stock]).
##
## Held, for several decks' colors, with the shader's own thresholds read off its source:
##
##   - THE LINE IS FOIL: the accent the material is handed is the line's color as the face samples
##     it, and the stock it is handed is the stock's.
##   - NO FRINGE: from the line's color out to the stock, through every blend its edge holds, the
##     distance from the accent only grows - so the foil fades off the line and never peaks beside it.
##   - ONE WAY IN: the table writes the accent through [method TableMedium._foil_accent] alone.
##
## Two-sided: the sRGB accent, run through the same checks, misses the line and peaks on its edge.
##
##   tests/run_boot_probe.sh tests/card_foil_check.gd 60

## Decks' frames: [accent, stock] - the 1327 export's, the default, and a dark and a pale accent.
const DECKS := [["#a8602a", "#e6d9b4"], ["#c9a227", "#efe6d2"], ["#5a1a1a", "#f4efe2"], ["#e0c070", "#2a2420"]]

var _fails: Array = []


func _ready() -> void:
	var rx := RegEx.create_from_string("smoothstep\\(([0-9.]+), ([0-9.]+), distance\\(c\\.rgb, accent\\)\\)")
	var m := rx.search(TableMedium.FOIL_SHADER)
	_ok(m != null, "the foil shader no longer keys the accent by distance - this gate reads its thresholds")
	if m != null:
		var inner := float(m.get_string(1))
		var outer := float(m.get_string(2))
		for d in DECKS:
			var look := {"frame": {"accent": d[0], "stock": d[1]}}
			var mat := ShaderMaterial.new()
			TableMedium._foil_accent(mat, look)
			TableMedium._foil_stock(mat, look)
			var accent: Vector3 = mat.get_shader_parameter("accent")
			var stock: Vector3 = mat.get_shader_parameter("stock")
			var why := _keys_the_line(accent, d[0], d[1], inner)
			_ok(why.is_empty(), "%s on %s: %s" % [d[0], d[1], why])
			var s := _sampled(Color.html(d[1]))
			_ok(s.distance_to(stock) < 0.01, "%s: the stock the foil leaves alone is %s, the face samples %s" % [d[1], stock, s])
		# the control: the accent as it went over before, in sRGB
		var a := Color.html(DECKS[0][0])
		var raw := _keys_the_line(Vector3(a.r, a.g, a.b), DECKS[0][0], DECKS[0][1], inner)
		_ok(not raw.is_empty(), "control: the sRGB accent passed - the checks cannot see the fringe")
		print("card_foil_check: the sRGB accent fails as it must (%s); key edges %.2f-%.2f" % [raw, inner, outer])
	var src := FileAccess.get_file_as_string("res://src/media/table.gd")
	var writes := RegEx.create_from_string("set_shader_parameter\\(\"accent\"").search_all(src).size()
	_ok(writes == 1, "table.gd writes the accent uniform in %d places - only _foil_accent may" % writes)
	await get_tree().process_frame
	if _fails.is_empty():
		print("card_foil_check: ALL OK")
		get_tree().quit()
		return
	print("card_foil_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   FAIL: ", f)
	get_tree().quit(1)


## "" when [param uniform] keys a line of [param accent] printed on [param stock]: the line's own color
## within the key's [param inner] edge, and every blend of its edge farther out than the last.
func _keys_the_line(uniform: Vector3, accent: String, stock: String, inner: float) -> String:
	var a := Color.html(accent)
	var s := Color.html(stock)
	var core := _sampled(a).distance_to(uniform)
	if core >= inner:
		return "the line's own color is %.3f from the accent, past the key's %.2f" % [core, inner]
	var last := core
	for i in range(1, 21):
		var t := float(i) / 20.0
		# an edge texel: the canvas blends in sRGB, the face is sampled linear
		var dd := _sampled(a.lerp(s, t)).distance_to(uniform)
		if dd < last - 0.0001:
			return "a blend %d%% toward the stock is nearer the accent (%.3f) than the line is (%.3f)" % [
				int(t * 100.0), dd, core]
		last = dd
	return ""


## A face's texel as the shader sees it.
static func _sampled(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

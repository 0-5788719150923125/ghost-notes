extends SceneTree

## back_frame_check - that an arch round a card's BACK stands round the back's design (feedback 0006: "that
## border should be shifted upward on the card, so that it's around the rectangular part"). The painting keeps
## its marks inside the middle four sixths of the card, so the arch's springing line is above the first sixth and
## its foot under the last, and its dome rises to the window's top. Pure geometry
## ([method CardFaces.back_arch], [method CardFaces.outline]).
##
##   godot --headless --path . --script tests/table/back_frame_check.gd
##
## Control: the arch as the face's front has it (a half circle dome over the whole window) springs from below the
## first sixth - it cuts across the design's top corners - and its foot runs past the last.

var _fails := 0
var _checks := 0


func _init() -> void:
	var look := CardTable.sanitize_look({"frame": {"window": "arch", "style": "corners", "ornament": "rope"}})
	var sz := Vector2(CardFaces.face_px(look))
	var win := CardFaces.window(true, look)
	var fit := CardFaces.back_arch(look, win)
	var box: Rect2 = fit["win"]
	var dome: float = fit["dome"]
	_ok(box.position == win.position and is_equal_approx(box.size.x, win.size.x), "the arch keeps the window's top and width")
	_ok(box.end.y <= win.end.y and box.end.y >= sz.y * 5.0 / 6.0, "its foot is under the design's last sixth, no lower than the window")
	var pts := CardFaces.outline("arch", box, 0.0, dome)
	var top := INF
	var spring := INF
	for p in pts:
		top = minf(top, p.y)
		if is_equal_approx(p.x, box.position.x):
			spring = minf(spring, p.y)
	_ok(is_equal_approx(top, box.position.y), "the dome rises to the window's top (%.1f of %.1f)" % [top, box.position.y])
	_ok(spring <= sz.y / 6.0, "the straight sides begin above the design's first sixth (%.1f)" % spring)
	var grown := CardFaces.outline("arch", box, 10.0, dome)
	var gtop := INF
	for p in grown:
		gtop = minf(gtop, p.y)
	_ok(is_equal_approx(gtop, box.position.y - 10.0), "a rule grown 10 px stands 10 px out round the dome (%.1f)" % gtop)
	var whole := CardFaces.outline("arch", win)
	var whole_spring := INF
	for p in whole:
		if is_equal_approx(p.x, win.position.x):
			whole_spring = minf(whole_spring, p.y)
	_ok(whole_spring > sz.y / 6.0, "control: the half circle springs from below the first sixth (%.1f) and cuts the design" % whole_spring)
	print("back_frame_check: %s (%d checks, %d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _checks, _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: " + what)

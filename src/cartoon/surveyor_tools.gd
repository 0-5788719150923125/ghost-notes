extends RefCounted
class_name SurveyorTools

## SurveyorTools - the surveyor's tools (next/cartoon.md, rules/cartoon/surveyor.yaml): a painted set's GROUND LINE, where its characters'
## feet go across it (a hill's ridge), traced by an agent that looks. Served over ghost's MCP server ([AgentTools]) to a writer that
## takes tools.
##
## `trace` takes the agent's points (shares of the picture in percent, left to right) and answers with the picture on a numbered grid,
## the line drawn over it in red: the points are joined along the edge the painting has there (the darkest, sharpest row in a narrow
## band round the agent's line, a path kept smooth), so a rough line lands on the ink; `snap: false` keeps the points as written.
## `submit` keeps the last line traced beside the set's picture ([method PuppetRig.ground_file]), where the stage reads it. The picture
## is read and drawn on a worker; a tool waits for it frame by frame.

## The band round the agent's line the edge is looked for in (a share of the picture's height), and how much a path pays to step a
## row from one column to the next (against an edge's strength, 0-1).
const BAND := 0.03
const BEND_COST := 0.04
## How many points a traced line is kept as.
const KEPT := 96

## The set's picture, and where its ground line goes.
var picture := ""
var target := ""
var submitted := false
## How many pictures it may look at.
var looks := 10

var _looked := 0
var _line := PackedVector2Array()    # the last line traced, shares of the picture
var _image: Image = null
var _busy := false
var _released := false


func _init(set_picture: String, ground_target: String, most_looks := 10) -> void:
	picture = set_picture
	target = ground_target
	looks = most_looks


## Its tools let go (the job ended): a call still waiting answers that they are closed.
func release() -> void:
	_released = true


func instructions() -> String:
	return "Tools for tracing where a painted set's characters walk: trace a line over the picture, see it, and hand it in."


func list_tools() -> Array:
	return [
		{"name": "trace", "description": "Trace the ground line: `line` [[x, y], ...] in percent of the picture's width and height (0, 0 its top left), from its left edge to its right. Answers with the picture on a grid numbered every 10 percent, the line drawn over it in red where it was joined along the painted edge (`snap`, on unless false). With no line, the picture on its grid alone.",
			"inputSchema": {"type": "object", "properties": {
				"line": {"type": "array", "items": {"type": "array", "items": {"type": "number"}}},
				"snap": {"type": "boolean"}}}},
		{"name": "submit", "description": "Hand in the line as it was last traced. Answers with what keeps it from being handed in, if anything; otherwise your work is done.",
			"inputSchema": {"type": "object", "properties": {}}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	while _busy and not _released:
		await tree.process_frame
	if _released:
		return {"text": "The line has been handed in and the tools are closed.", "error": true}
	_busy = true
	var out: Dictionary = {}
	match name:
		"trace":
			out = await _trace(args.get("line", []) if args.get("line") is Array else [], bool(args.get("snap", true)))
		"submit":
			if _line.size() < 2:
				out = {"text": "Nothing is traced yet: `trace` the line, look, and hand it in when it lies where they walk.", "error": true}
			else:
				out = {"text": SurveyorTools.keep(target, _line)}
				submitted = not String(out["text"]).begins_with("Could not")
				if not submitted:
					out["error"] = true
		_:
			out = {"text": "There is no tool called %s." % name, "error": true}
	_busy = false
	return out


## [param line] kept as the ground line at [param file]: what was done, a sentence.
static func keep(file: String, line: PackedVector2Array) -> String:
	var pts: Array = []
	for p in line:
		pts.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001)])
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return "Could not write %s." % file
	f.store_string(JSON.stringify({"line": pts}, "\t"))
	f.close()
	return "Handed in. The line is kept with the set, and your work is done."


func _trace(raw: Array, snap: bool) -> Dictionary:
	var pts := PackedVector2Array()
	for p in raw:
		if p is Array and (p as Array).size() >= 2:
			pts.append(Vector2(clampf(float(p[0]) / 100.0, 0.0, 1.0), clampf(float(p[1]) / 100.0, 0.0, 1.0)))
	var sorted := Array(pts)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	pts = PackedVector2Array(sorted)
	if not raw.is_empty() and pts.size() < 2:
		return {"text": "A line needs at least two points [x, y].", "error": true}
	var job := {"picture": picture, "image": _image, "points": pts, "snap": snap}
	var task := WorkerThreadPool.add_task(func() -> void: SurveyorTools.work(job))
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if job.get("image") == null:
		return {"text": "The set's picture would not read (%s)." % picture, "error": true}
	_image = job["image"]
	var said := "The picture on its grid."
	if pts.size() >= 2:
		_line = job["line"]
		said = "The line traced, in red%s: %d points from x %.0f%% to %.0f%%, y %.0f%% to %.0f%%. Check that it lies along where they walk the whole way across." % [
			" (joined along the painted edge; the yellow dots are your points)" if snap else "", _line.size(), _line[0].x * 100.0,
			_line[_line.size() - 1].x * 100.0, _min_y(_line) * 100.0, _max_y(_line) * 100.0]
	var images: Array = []
	if _looked < looks:
		_looked += 1
		images.append(job["look"])
		said += "\n(%d of %d looks used)" % [_looked, looks]
	else:
		said += "\n(no looks left: hand the line in)"
	return {"text": said, "images": images}


static func _min_y(line: PackedVector2Array) -> float:
	var m := 1.0
	for p in line:
		m = minf(m, p.y)
	return m


static func _max_y(line: PackedVector2Array) -> float:
	var m := 0.0
	for p in line:
		m = maxf(m, p.y)
	return m


# --- the worker's -----------------------------------------------------------------------------------------------------------

## A trace worked out (on a worker): [param job] {picture, image, points, snap} given `image` (read where it was not), `line` (the
## points joined along the painted edge, or as written) and `look` (the picture on its grid with the line over it).
static func work(job: Dictionary) -> void:
	var img: Image = job.get("image")
	if img == null:
		img = Image.load_from_file(String(job["picture"]))
		if img == null:
			return
		img.convert(Image.FORMAT_RGB8)
		job["image"] = img
	var pts: PackedVector2Array = job["points"]
	var line := pts
	if pts.size() >= 2 and bool(job.get("snap", true)):
		line = along_edge(img, pts)
	job["line"] = thin(line, KEPT)
	job["look"] = look(img, job["line"] if pts.size() >= 2 else PackedVector2Array(), pts)


## The line through [param pts] (shares of [param img], left to right) laid along the painted edge near it: column by column across
## the picture, the row in a band of [constant BAND] round the agent's line where the painting is darkest and changes most, a path
## that pays [constant BEND_COST] a row it steps. Shares of the picture, a point every few columns.
static func along_edge(img: Image, pts: PackedVector2Array) -> PackedVector2Array:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, w / 480)
	var band := maxi(3, int(BAND * h))
	var cols: Array = []
	var x := 0
	while x < w:
		cols.append(x)
		x += step
	var n := cols.size()
	var rows := 2 * band + 1
	var cost := PackedFloat32Array()
	cost.resize(n * rows)
	var mid := PackedInt32Array()
	mid.resize(n)
	for i in n:
		var cx: int = cols[i]
		var cy := int(PuppetRig.ground_at(pts, float(cx) / float(w)) * h)
		mid[i] = cy
		for r in rows:
			var y := cy - band + r
			cost[i * rows + r] = 1.0 - _edge(img, cx, y)
	# the cheapest path across: each column's row from the last column's, stepping costs
	var acc := cost.duplicate()
	var back := PackedInt32Array()
	back.resize(n * rows)
	for i in range(1, n):
		for r in rows:
			var y := mid[i] - band + r
			var best := INF
			var from := 0
			for q in range(maxi(0, r - 3), mini(rows, r + 4)):
				var py := mid[i - 1] - band + q
				var c := acc[(i - 1) * rows + q] + BEND_COST * absf(float(y - py))
				if c < best:
					best = c
					from = q
			acc[i * rows + r] = cost[i * rows + r] + best
			back[i * rows + r] = from
	var end := 0
	for r in rows:
		if acc[(n - 1) * rows + r] < acc[(n - 1) * rows + end]:
			end = r
	var out := PackedVector2Array()
	out.resize(n)
	var at := end
	for i in range(n - 1, -1, -1):
		out[i] = Vector2(float(cols[i]) / float(w), float(mid[i] - band + at) / float(h))
		at = back[i * rows + at] if i > 0 else at
	return out


## How much row [param y] of column [param x] is an edge (0-1): dark there and changing sharply above and below it.
static func _edge(img: Image, x: int, y: int) -> float:
	var h := img.get_height()
	if y < 2 or y >= h - 2:
		return 0.0
	var here := img.get_pixel(x, y).get_luminance()
	var up := img.get_pixel(x, y - 2).get_luminance()
	var down := img.get_pixel(x, y + 2).get_luminance()
	return clampf(0.6 * (1.0 - here) * (1.0 - here) + 0.8 * absf(up - down) + 0.4 * maxf(0.0, minf(up, down) - here), 0.0, 1.0)


## [param line] kept as at most [param most] points, evenly across it.
static func thin(line: PackedVector2Array, most: int) -> PackedVector2Array:
	if line.size() <= most:
		return line
	var out := PackedVector2Array()
	for i in most:
		out.append(line[int(round(float(i) * float(line.size() - 1) / float(most - 1)))])
	return out


## [param img] at most 1200 wide with a grid every 10 percent numbered along its top and left, [param line] over it in red and the
## agent's own [param pts] as yellow dots.
static func look(img: Image, line: PackedVector2Array, pts: PackedVector2Array) -> Image:
	var out := img.duplicate() as Image
	if out.get_width() > 1200:
		out.resize(1200, int(round(1200.0 * out.get_height() / out.get_width())), Image.INTERPOLATE_BILINEAR)
	out.convert(Image.FORMAT_RGB8)
	var w := out.get_width()
	var h := out.get_height()
	for k in range(1, 10):
		var gx := int(w * k / 10.0)
		var gy := int(h * k / 10.0)
		var c := Color(1, 1, 1, 1) if k == 5 else Color(0.85, 0.85, 0.85)
		_blend_rect(out, Rect2i(gx, 0, 2 if k == 5 else 1, h), c, 0.7)
		_blend_rect(out, Rect2i(0, gy, w, 2 if k == 5 else 1), c, 0.7)
		_number(out, k * 10, Vector2i(gx + 4, 4))
		_number(out, k * 10, Vector2i(4, gy + 4))
	for i in range(1, line.size()):
		var a := Vector2(line[i - 1].x * w, line[i - 1].y * h)
		var b := Vector2(line[i].x * w, line[i].y * h)
		var steps := maxi(1, int(a.distance_to(b)))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(steps))
			out.fill_rect(Rect2i(int(p.x) - 1, int(p.y) - 1, 3, 3).intersection(Rect2i(0, 0, w, h)), Color(1, 0.1, 0.1))
	for p in pts:
		out.fill_rect(Rect2i(int(p.x * w) - 4, int(p.y * h) - 4, 9, 9).intersection(Rect2i(0, 0, w, h)), Color(1, 0.9, 0.1))
	return out


static func _blend_rect(img: Image, r: Rect2i, c: Color, a: float) -> void:
	var rr := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))


## Digits five pixels tall, three wide, a row a string of three bits.
const DIGITS := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111"]


## [param value] written at [param at] in block digits, white on a dark box.
static func _number(img: Image, value: int, at: Vector2i) -> void:
	var text := str(value)
	var px := 3
	var box := Rect2i(at, Vector2i(text.length() * 4 * px + px, 7 * px)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.fill_rect(box, Color(0.05, 0.05, 0.05))
	for i in text.length():
		var bits: String = DIGITS[int(text[i])]
		for b in 15:
			if bits[b] == "1":
				var r := Rect2i(at.x + px + (i * 4 + b % 3) * px, at.y + px + (b / 3) * px, px, px)
				img.fill_rect(r.intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color.WHITE)

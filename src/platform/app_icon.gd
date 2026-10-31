class_name AppIcon
extends RefCounted

## AppIcon - Ghost Notes' icon, drawn where it is needed and never shipped as a file (2026-10-31,
## the user: "I don't like how we've pre-created it, and shipped as a static thing"). A ghost whose
## color, body, pose, face, backdrop and what floats beside it are each read off a hash:
##
## - OF THE MACHINE for the window's icon, set at launch by Boot ([method apply]):
##   `OS.get_unique_id()` - /etc/machine-id, Windows' hardware profile, Android's ANDROID_ID, the
##   Mac's platform UUID - salted and hashed, so every machine keeps its own ghost and the id itself
##   is kept nowhere.
## - OF THE BUILD for the icons a phone shows ([method packaged], written by app_icon_tool.gd from
##   scripts/build.sh): Android and iOS read a launcher icon out of the package, and an app cannot
##   draw a new one there, so each build is seeded by its commit and every update comes with a new
##   ghost.
##
## THE GHOST IS DATA. Every part is a row: a body's outline an SVG path in the ghost's own frame
## (its middle at 0,0, about 64 across), a face's or a prop's an SVG fragment with its colors left
## as `{names}`. [method svg_of] composes one SVG and the engine's own ThorVG draws it at any size
## (`Image.load_svg_from_string`), so a new body, face or prop is a row. A pick is one byte of the
## hash modulo its table's size: a row added re-draws the ghosts that land on it. A ROW THORVG
## CANNOT READ MAY CRASH THE ENGINE (a stray `<` in one did, in tvg::Paint), and Boot draws at every
## launch: tests/platform/app_icon_check.gd draws every row, so it crashes there first.
##
## LAYERS, for the platforms that put an icon together themselves ([const LAYERS]): the window's
## whole icon, a full-bleed opaque backdrop (Android's adaptive background, iOS under its own mask),
## the figure alone within Android's safe circle, and the figure in white with its face cut out
## (Android 13's themed icon, iOS's tinted one).

## Mixed into every hash, so this icon's draw is its own: another use of the machine's id hashes to
## something unrelated. Renaming it re-draws every ghost.
const SALT := "ghost-icon"
## The SVG's own frame; every coordinate below is in it.
const FRAME := 128.0
## EVERY GHOST STANDS IN THE MIDDLE (2026-10-31, the user: "quite a few of the ghosts are
## off-center"), the same size with a prop or without: its body's drawn box is centered on the
## frame's middle, and a prop perches on the head, over its outline but never its face.
const SIZE := 0.86
## How far it may lean either way, about its middle (degrees).
const TILT_MOST := 9.0
## A prop leans out, away from the ghost (degrees, about where it perches).
const PROP_LEAN := 8.0
## The outline's width, drawn under every shape: twice what shows outside it.
const OUTLINE := 7.0

## What a ghost's outline can be. `path` in the ghost's frame; `eyes` and `mouth` the heights of
## its face; `shoulder` where an arm is pinned (x on each side, y); `middle` the middle of the box it
## draws, outline and all - the point set on the frame's middle (app_icon_check measures it);
## `perch` where a prop's box meets the head, its inner bottom corner on the right side (mirrored on
## the left): above the eyes and outside the cheeks, so a prop overlaps the head and not the face.
const BODIES := {
	"classic": {
		"label": "Classic",
		"blurb": "A dome on straight sides, the hem in four round lobes.",
		"path": "M -30,36 L -30,-14 A 30,30 0 0 1 30,-14 L 30,36 Q 22.5,48 15,36 Q 7.5,48 0,36 Q -7.5,48 -15,36 Q -22.5,48 -30,36 Z",
		"eyes": -12.0,
		"mouth": 4.0,
		"shoulder": [28.0, 6.0],
		"middle": [0.0, -1.0],
		"perch": [22.0, -26.0],
	},
	"drift": {
		"label": "Drift",
		"blurb": "A dome trailing off to one side in a curled tail, as if blown along.",
		"path": "M -30,-14 A 30,30 0 0 1 30,-14 C 30,8 32,26 46,40 C 34,44 25,36 16,40 C 8,44 -2,37 -10,41 C -19,45 -28,38 -30,26 Z",
		"eyes": -12.0,
		"mouth": 4.0,
		"shoulder": [28.0, 6.0],
		"middle": [8.0, -1.0],
		"perch": [22.0, -26.0],
	},
	"sheet": {
		"label": "Sheet",
		"blurb": "A sheet thrown over someone: the sides falling wide, the hem in small folds.",
		"path": "M -37,40 C -34,22 -30,6 -30,-14 A 30,30 0 0 1 30,-14 C 30,6 34,22 37,40 Q 30.8,47 24.7,40 Q 18.5,47 12.3,40 Q 6.2,47 0,40 Q -6.2,47 -12.3,40 Q -18.5,47 -24.7,40 Q -30.8,47 -37,40 Z",
		"eyes": -12.0,
		"mouth": 4.0,
		"shoulder": [29.0, 4.0],
		"middle": [0.0, -0.3],
		"perch": [22.0, -26.0],
	},
	"plump": {
		"label": "Plump",
		"blurb": "Short and round, three lobes at its hem.",
		"path": "M -34,22 C -36,-4 -28,-40 0,-40 C 28,-40 36,-4 34,22 Q 25.5,34 17,22 Q 8.5,34 0,22 Q -8.5,34 -17,22 Q -25.5,34 -34,22 Z",
		"eyes": -10.0,
		"mouth": 5.0,
		"shoulder": [31.0, 4.0],
		"middle": [0.0, -6.0],
		"perch": [22.0, -24.0],
	},
}

## How it holds its arms: each arm a side (-1 left, 1 right) and a turn from straight up (degrees,
## clockwise). `free` is the side a prop goes on (0: either).
const POSES := {
	"float": {"label": "Float", "blurb": "No arms out, just drifting.", "arms": [], "free": 0},
	"boo": {"label": "Boo", "blurb": "Both arms up and out.", "arms": [[-1, -58.0], [1, 58.0]], "free": 0},
	"wave": {"label": "Wave", "blurb": "One arm up in a wave, the other hanging.", "arms": [[1, 28.0], [-1, -128.0]], "free": -1},
	"reach": {"label": "Reach", "blurb": "Both arms out to the sides.", "arms": [[-1, -96.0], [1, 96.0]], "free": 0},
}

## Eyes, about the face's middle; `{ink}` and `{glint}` are filled in.
const EYES := {
	"ovals": {
		"label": "Ovals",
		"blurb": "Two tall dark ovals.",
		"svg": "<ellipse cx=\"-11\" cy=\"0\" rx=\"4.6\" ry=\"6.6\" fill=\"{ink}\"/><ellipse cx=\"11\" cy=\"0\" rx=\"4.6\" ry=\"6.6\" fill=\"{ink}\"/>",
	},
	"glints": {
		"label": "Glints",
		"blurb": "Round eyes, each with a spot of light.",
		"svg": "<circle cx=\"-11\" cy=\"0\" r=\"5.8\" fill=\"{ink}\"/><circle cx=\"11\" cy=\"0\" r=\"5.8\" fill=\"{ink}\"/><circle cx=\"-9\" cy=\"-2.2\" r=\"2\" fill=\"{glint}\"/><circle cx=\"13\" cy=\"-2.2\" r=\"2\" fill=\"{glint}\"/>",
	},
	"happy": {
		"label": "Happy",
		"blurb": "Two arcs, smiling with the eyes.",
		"svg": "<path d=\"M -16,2 Q -11,-6 -6,2 M 6,2 Q 11,-6 16,2\" fill=\"none\" stroke=\"{ink}\" stroke-width=\"3.4\" stroke-linecap=\"round\"/>",
	},
	"wink": {
		"label": "Wink",
		"blurb": "One oval, one arc.",
		"svg": "<ellipse cx=\"-11\" cy=\"0\" rx=\"4.6\" ry=\"6.6\" fill=\"{ink}\"/><path d=\"M 6,1 Q 11,-5 16,1\" fill=\"none\" stroke=\"{ink}\" stroke-width=\"3.4\" stroke-linecap=\"round\"/>",
	},
	"sleepy": {
		"label": "Sleepy",
		"blurb": "Closed, curved down.",
		"svg": "<path d=\"M -16,-1 Q -11,5 -6,-1 M 6,-1 Q 11,5 16,-1\" fill=\"none\" stroke=\"{ink}\" stroke-width=\"3.4\" stroke-linecap=\"round\"/>",
	},
}

## Mouths, about where the body puts one.
const MOUTHS := {
	"none": {"label": "None", "blurb": "No mouth.", "svg": ""},
	"o": {"label": "O", "blurb": "A small round mouth, mid-boo.", "svg": "<ellipse cx=\"0\" cy=\"1\" rx=\"3.6\" ry=\"4.6\" fill=\"{ink}\"/>"},
	"smile": {"label": "Smile", "blurb": "A curved line.", "svg": "<path d=\"M -6,0 Q 0,6.5 6,0\" fill=\"none\" stroke=\"{ink}\" stroke-width=\"3\" stroke-linecap=\"round\"/>"},
	"grin": {"label": "Grin", "blurb": "Open wide.", "svg": "<path d=\"M -7,-1 Q 0,-2.5 7,-1 Q 5.5,9 0,9 Q -5.5,9 -7,-1 Z\" fill=\"{ink}\"/>"},
}

## What floats beside it, in its own frame. `{paint}` is the outline in one pass and the fill in
## the next, so overlapping parts share one clean outline. `box` is what it draws, outline and all
## ([x0, y0, x1, y1]; app_icon_check measures it): its inner bottom corner goes on the body's perch.
const PROPS := {
	"none": {"label": "None", "blurb": "Nothing beside it.", "svg": ""},
	"note": {
		"label": "Note",
		"blurb": "An eighth note.",
		"box": [-8.6, -29.2, 17.5, 7.4],
		"svg": "<g {paint}><ellipse cx=\"0\" cy=\"0\" rx=\"6.6\" ry=\"4.9\" transform=\"rotate(-22)\"/><rect x=\"3.4\" y=\"-27\" width=\"3.4\" height=\"26\"/><path d=\"M 6.8,-27 C 8.5,-20 17,-18 15,-7 C 13.8,-12.5 11,-15.5 6.8,-16.5 Z\"/></g>",
	},
	"notes": {
		"label": "Notes",
		"blurb": "Two eighth notes beamed together.",
		"box": [-16.8, -30.2, 17.2, 10.7],
		"svg": "<g {paint}><ellipse cx=\"-9\" cy=\"4\" rx=\"5.8\" ry=\"4.3\" transform=\"rotate(-22 -9 4)\"/><ellipse cx=\"9\" cy=\"0\" rx=\"5.8\" ry=\"4.3\" transform=\"rotate(-22 9 0)\"/><rect x=\"-6\" y=\"-24\" width=\"3\" height=\"27\"/><rect x=\"12\" y=\"-28\" width=\"3\" height=\"27\"/><path d=\"M -6,-24 L 15,-28 L 15,-21.5 L -6,-17.5 Z\"/></g>",
	},
	"sparkles": {
		"label": "Sparkles",
		"blurb": "Three four-pointed stars.",
		"box": [-18.7, -13.2, 21.2, 22.2],
		"svg": "<g {paint}><path d=\"M 0,-11 Q 0,0 11,0 Q 0,0 0,11 Q 0,0 -11,0 Q 0,0 0,-11 Z\"/><path d=\"M 13,8 Q 13,14 19,14 Q 13,14 13,20 Q 13,14 7,14 Q 13,14 13,8 Z\"/><path d=\"M -12,9 Q -12,13.5 -7.5,13.5 Q -12,13.5 -12,18 Q -12,13.5 -16.5,13.5 Q -12,13.5 -12,9 Z\"/></g>",
	},
}

## What the window's icon stands on. `{back}` and `{aura}` are gradients.
const STYLES := {
	"tile": {"label": "Tile", "blurb": "A rounded square, lit from the middle.", "svg": "<rect x=\"6\" y=\"6\" width=\"116\" height=\"116\" rx=\"28\" fill=\"{back}\"/>"},
	"disc": {"label": "Disc", "blurb": "A circle, lit from the middle.", "svg": "<circle cx=\"64\" cy=\"64\" r=\"58\" fill=\"{back}\"/>"},
	"aura": {"label": "Aura", "blurb": "No backdrop, only a glow round the ghost.", "svg": "<circle cx=\"64\" cy=\"64\" r=\"62\" fill=\"{aura}\"/>"},
}

## Ways to draw one design. `back`: the style's backdrop, `bleed` (the whole square, opaque) or
## none; `figure`: the ghost's scale about the frame's middle, 0 for none; `mono` draws it white
## with the face cut out.
const LAYERS := {
	"whole": {"label": "Whole", "blurb": "The window's icon: its style's backdrop and the ghost.", "back": "style", "figure": 1.0, "mono": false},
	"square": {"label": "Square", "blurb": "Full bleed and opaque, for a platform that rounds the corners itself (iOS).", "back": "bleed", "figure": 0.8, "mono": false},
	"backdrop": {"label": "Backdrop", "blurb": "The backdrop alone, full bleed (Android's adaptive background).", "back": "bleed", "figure": 0.0, "mono": false},
	"figure": {"label": "Figure", "blurb": "The ghost and its prop alone, inside Android's safe circle (its adaptive foreground).", "back": "none", "figure": 0.49, "mono": false},
	"mono": {"label": "Mono", "blurb": "The figure in white with its face cut out (Android 13's themed icon).", "back": "none", "figure": 0.49, "mono": true},
	"figure_square": {"label": "Figure, square", "blurb": "The figure alone at the square's size (iOS's dark icon).", "back": "none", "figure": 0.8, "mono": false},
	"mono_square": {"label": "Mono, square", "blurb": "The white figure at the square's size (iOS's tinted icon).", "back": "none", "figure": 0.8, "mono": true},
}

## The icons a package carries, each a layer at a size; the export presets name these files.
const PACKAGED := {
	"android_main": {"label": "Android", "blurb": "The launcher icon of a phone older than Android 8.", "file": "android_main_192.png", "layer": "whole", "size": 192},
	"android_foreground": {"label": "Android foreground", "blurb": "The adaptive icon's foreground.", "file": "android_foreground_432.png", "layer": "figure", "size": 432},
	"android_background": {"label": "Android background", "blurb": "The adaptive icon's background.", "file": "android_background_432.png", "layer": "backdrop", "size": 432},
	"android_monochrome": {"label": "Android monochrome", "blurb": "The themed icon Android 13 tints.", "file": "android_monochrome_432.png", "layer": "mono", "size": 432},
	"ios": {"label": "iOS", "blurb": "The base icon iOS makes every other size from.", "file": "ios_1024.png", "layer": "square", "size": 1024},
	"ios_dark": {"label": "iOS dark", "blurb": "The figure on nothing; iOS puts its dark backdrop behind.", "file": "ios_1024_dark.png", "layer": "figure_square", "size": 1024},
	"ios_tinted": {"label": "iOS tinted", "blurb": "The white figure iOS tints.", "file": "ios_1024_tinted.png", "layer": "mono_square", "size": 1024},
}


## The window's icon, for this machine: set at launch where the platform has one (not a phone, not
## headless). Returns whether it was set.
static func apply() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_ICON):
		return false
	var img := image_of(design_of(machine_seed()), 256)
	if img.is_empty():
		return false
	DisplayServer.set_icon(img)
	return true


## This machine's seed: its id salted and hashed. Where a platform has no id, the user data folder
## (it names the account) stands in.
static func machine_seed() -> PackedByteArray:
	var id := OS.get_unique_id()
	if id.is_empty():
		id = OS.get_user_data_dir()
	return seed_of(id)


static func seed_of(text: String) -> PackedByteArray:
	return ("%s:%s" % [SALT, text]).sha256_buffer()


## Every choice one seed makes, as plain data: the row keys, the hues, the tilt - and the body's
## `middle` and `perch`, copied from its row, so all [method svg_of] draws from is here (a gate moves
## them to see its measures fail).
static func design_of(seed: PackedByteArray) -> Dictionary:
	var b := seed
	if b.size() < 16:
		b = seed_of(b.hex_encode())
	var hue := float(b.decode_u16(0)) / 65536.0
	var body := _pick(BODIES, b[4])
	return {
		"hue": hue,
		"back_hue": fposmod(hue + 0.42 + float(b[2]) / 255.0 * 0.16, 1.0),
		"prop_hue": fposmod(hue + 0.33 + float(b[3]) / 255.0 * 0.34, 1.0),
		"body": body,
		"middle": BODIES[body]["middle"],
		"perch": BODIES[body]["perch"],
		"pose": _pick(POSES, b[5]),
		"eyes": _pick(EYES, b[6]),
		"mouth": _pick(MOUTHS, b[7]),
		"prop": _pick(PROPS, b[8]),
		"style": _pick(STYLES, b[9]),
		"mirror": (b[10] & 1) == 1,
		"tilt": (float(b[11]) / 255.0 * 2.0 - 1.0) * TILT_MOST,
		"blush": b[12] % 3 == 0,
		"saturation": 0.26 + float(b[13]) / 255.0 * 0.26,
	}


static func _pick(table: Dictionary, byte: int) -> String:
	var keys := table.keys()
	return str(keys[byte % keys.size()])


## The design drawn at [param size] pixels square, as [param layer] (a [const LAYERS] key).
static func image_of(design: Dictionary, size: int, layer := "whole") -> Image:
	var img := Image.new()
	var err := img.load_svg_from_string(svg_of(design, layer), float(size) / FRAME)
	if err != OK:
		push_error("AppIcon: the SVG did not draw (%s)" % error_string(err))
		return Image.new()
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return img


## Every [const PACKAGED] icon for one seed, by key.
static func packaged(seed: PackedByteArray) -> Dictionary:
	var design := design_of(seed)
	var out := {}
	for key: String in PACKAGED:
		var row: Dictionary = PACKAGED[key]
		out[key] = image_of(design, int(row["size"]), str(row["layer"]))
	return out


## The design as one SVG document.
static func svg_of(design: Dictionary, layer := "whole") -> String:
	var how: Dictionary = LAYERS[layer]
	var mono: bool = how["mono"]
	var colors := _colors(design, mono)
	var body: Dictionary = BODIES[design["body"]]
	var pose: Dictionary = POSES[design["pose"]]
	var prop: Dictionary = PROPS[design["prop"]]
	var flip := -1.0 if design["mirror"] else 1.0
	var middle := Vector2(float(design["middle"][0]), float(design["middle"][1]))
	var tilt := float(design["tilt"])
	var c := FRAME * 0.5

	var shapes := "<path d=\"%s\"/>" % body["path"]
	for arm: Array in pose["arms"]:
		shapes += "<path d=\"%s\"/>" % _arm(body["shoulder"], float(arm[0]), float(arm[1]))

	var ghost := "<g transform=\"translate(%s,%s) rotate(%s) scale(%s,%s) translate(%s,%s)\">" % [
		_n(c), _n(c), _n(tilt), _n(SIZE * flip), _n(SIZE), _n(-middle.x), _n(-middle.y)]
	ghost += "<g fill=\"{line}\" stroke=\"{line}\" stroke-width=\"%s\" stroke-linejoin=\"round\">%s</g>" % [_n(OUTLINE), shapes]
	ghost += "<g fill=\"{body}\">%s</g>" % shapes
	ghost += "<g transform=\"translate(0,%s)\">%s%s</g>" % [_n(body["eyes"]), EYES[design["eyes"]]["svg"], _cheeks(design)]
	ghost += "<g transform=\"translate(0,%s)\">%s</g>" % [_n(body["mouth"]), MOUTHS[design["mouth"]]["svg"]]
	ghost += "</g>"
	if prop.has("box"):
		# Perched on the head through the ghost's own turn, lean and size, so it keeps clear of the
		# face however the ghost stands; drawn unmirrored (a note's flag points right).
		var side := float(pose["free"])
		if side == 0.0:
			side = 1.0
		var perch := Vector2(float(design["perch"][0]) * side, float(design["perch"][1]))
		var at := Vector2(c, c) + (Vector2(flip, 1.0) * SIZE * (perch - middle)).rotated(deg_to_rad(tilt))
		var shown := side * flip
		var box: Array = prop["box"]
		var corner := Vector2(float(box[0]) if shown > 0.0 else float(box[2]), float(box[3]))
		ghost += "<g transform=\"translate(%s,%s) rotate(%s) scale(%s) translate(%s,%s)\">" % [
			_n(at.x), _n(at.y), _n(shown * PROP_LEAN), _n(SIZE), _n(-corner.x), _n(-corner.y)]
		var art := str(prop["svg"])
		ghost += art.replace("{paint}", "fill=\"{line}\" stroke=\"{line}\" stroke-width=\"4.4\" stroke-linejoin=\"round\"")
		ghost += art.replace("{paint}", "fill=\"{prop}\"")
		ghost += "</g>"

	var scale := float(how["figure"])
	if scale == 0.0:
		ghost = ""
	elif scale != 1.0:
		ghost = "<g transform=\"translate(%s,%s) scale(%s) translate(%s,%s)\">%s</g>" % [_n(c), _n(c), _n(scale), _n(-c), _n(-c), ghost]

	var back := ""
	match str(how["back"]):
		"style":
			back = str(STYLES[design["style"]]["svg"])
		"bleed":
			back = "<rect x=\"0\" y=\"0\" width=\"128\" height=\"128\" fill=\"{back}\"/>"

	var inner := back + ghost
	if mono:
		# White where the figure is, nothing where its face is: a luminance mask over a white sheet.
		inner = "<mask id=\"cut\" maskUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"128\" height=\"128\">%s</mask>" % ghost \
			+ "<rect x=\"0\" y=\"0\" width=\"128\" height=\"128\" fill=\"#ffffff\" mask=\"url(#cut)\"/>"
	var doc := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\">"
	doc += _defs(design) + inner + "</svg>"
	return doc.format(colors)


static func _colors(design: Dictionary, mono: bool) -> Dictionary:
	if mono:
		return {"line": "#ffffff", "body": "#ffffff", "ink": "#000000", "glint": "#ffffff",
			"blush": "#ffffff", "prop": "#ffffff", "back": "#000000", "aura": "none"}
	var h: float = design["hue"]
	return {
		"line": _hex(Color.from_hsv(h, 0.72, 0.24)),
		"body": "url(#body)",
		"ink": _hex(Color.from_hsv(h, 0.8, 0.13)),
		"glint": "#ffffff",
		"blush": _hex(Color.from_hsv(0.97, 0.42, 1.0)),
		"prop": _hex(Color.from_hsv(design["prop_hue"], 0.5, 1.0)),
		"back": "url(#back)",
		"aura": "url(#aura)",
	}


static func _defs(design: Dictionary) -> String:
	var h: float = design["hue"]
	var bh: float = design["back_hue"]
	var s: float = design["saturation"]
	var d := "<defs>"
	d += "<linearGradient id=\"body\" gradientUnits=\"userSpaceOnUse\" x1=\"0\" y1=\"-44\" x2=\"0\" y2=\"46\">"
	d += "<stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [
		_hex(Color.from_hsv(h, s * 0.35, 1.0)), _hex(Color.from_hsv(h, s, 0.97))]
	d += "<radialGradient id=\"back\" cx=\"64\" cy=\"58\" r=\"80\" gradientUnits=\"userSpaceOnUse\">"
	d += "<stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></radialGradient>" % [
		_hex(Color.from_hsv(bh, 0.5, 0.46)), _hex(Color.from_hsv(bh, 0.62, 0.13))]
	d += "<radialGradient id=\"aura\" cx=\"64\" cy=\"64\" r=\"62\" gradientUnits=\"userSpaceOnUse\">"
	d += "<stop offset=\"0.35\" stop-color=\"%s\" stop-opacity=\"0.6\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient>" % [
		_hex(Color.from_hsv(h, 0.55, 1.0)), _hex(Color.from_hsv(h, 0.55, 1.0))]
	return d + "</defs>"


static func _cheeks(design: Dictionary) -> String:
	if not design["blush"]:
		return ""
	return "<ellipse cx=\"-19\" cy=\"8\" rx=\"5\" ry=\"3\" fill=\"{blush}\" opacity=\"0.6\"/><ellipse cx=\"19\" cy=\"8\" rx=\"5\" ry=\"3\" fill=\"{blush}\" opacity=\"0.6\"/>"


## One arm: an ellipse pinned at the shoulder on [param side], turned [param turn] degrees from
## straight up - written as two arcs in the ghost's frame, so it shares the body's gradient.
static func _arm(shoulder: Array, side: float, turn: float) -> String:
	const LONG := 12.5
	const WIDE := 7.5
	var pin := Vector2(float(shoulder[0]) * side, float(shoulder[1]))
	var along := Vector2(sin(deg_to_rad(turn)), -cos(deg_to_rad(turn)))
	var mid := pin + along * (LONG - 1.5)
	var a := mid - along * LONG
	var z := mid + along * LONG
	var rot := _n(turn - 90.0)
	return "M %s,%s A %s,%s %s 1 0 %s,%s A %s,%s %s 1 0 %s,%s Z" % [
		_n(a.x), _n(a.y), _n(LONG), _n(WIDE), rot, _n(z.x), _n(z.y),
		_n(LONG), _n(WIDE), rot, _n(a.x), _n(a.y)]


static func _n(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

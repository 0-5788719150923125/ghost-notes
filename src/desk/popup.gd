extends BookMedium
class_name PopupMedium

## PopupMedium - the reading as a pop-up book open on the Letter's desk, one scene a spread ([PopupLayout]).
##
## Everything that makes the book work is the book's (the 3D spread, the turn, the voice followed word by word, the
## camera); here is what a pop-up book does differently.
##
## THE DESK IS THE LETTER'S ([DeskLook], [DeskLight]): its top, the things lying on it (none under the open book), its lamp,
## its candles and the room's light as its mood says, chosen on the Medium card's desk rows ([PopupFormat], the document's
## `medium`) and lit as the Environment card says (`environment`). The book is set on it at its real size ([constant
## BOOK_M] a page's width), the camera worked out in the book's own units.
##
## Its pages are boards, so a leaf turns flat ([method _leaf_bend]). What stands on a spread is pieces of card, each a
## picture creased into panels ([method footprint]): its creases at fractions across the picture (`folds`), each panel
## turned from facing the reader (`turns`, degrees, + its right end back), one crease on the spine (`at`) at a depth (`z`).
## A cut-out (`<!-- popup: -->`, painted on magenta and cut out, [Illustrations]) is one; the scene's picture
## (`<!-- image: -->`) stands behind them whole as its scenery. How each stands is the design the note keeps
## ([PopupDesign], the document's `popup`), else a V for each cut-out, its ridge toward the reader.
##
## A piece folds flat as its spread closes - with the cover as the book opens, and as a leaf turns, the old scene folding
## onto the rising leaf as the new one rises from under it: every crease leans as a V-fold's does ([method crease]: square
## to both feet, each at [constant FOLD] to the spine), while each foot of the piece rides its own page. Exact for a V;
## for any other shape nothing ever passes through a page, and every crease of a spread leans together, so the pieces
## fold as a stack.
##
## THE VOICE WAITS FOR THE BOOK ([PopupWalk] rests it): after the title, while the cover opens and the first scene stands
## up, and at each scene, while the leaf turns ([method _turn_lead]) and the next scene stands. It opens on the closed book
## seen from above, its painted cover (`<!-- image (cover): -->`) held while the title is read; after the sources (what
## follows the unread line) the cover shuts again, the camera rises back over it, and only then does the picture fade.

## A page's width on the desk, in meters: the open book is about as wide as the Letter's legal pad is tall.
const BOOK_M := 0.19
## The angle each crease's feet make with the spine, degrees ([method crease]).
const FOLD := 72.0
## The most panels one piece may have, and the most pieces two spreads in shot stand (each spread its scenery and three).
const MOST_PANELS := 11
const POOL := 12
## Where a spread's cut-outs stand when the note's design says nothing, by how many it has: `[z of the ridge, most
## height, most width of a panel]` each, farthest back first, each a V with its ridge toward the reader ([constant V]).
const SLOTS := {
	1: [[0.08, 0.55, 0.60]],
	2: [[-0.10, 0.48, 0.60], [0.12, 0.36, 0.45]],
	3: [[-0.16, 0.42, 0.62], [0.0, 0.34, 0.50], [0.14, 0.26, 0.38]],
}
## A V, its ridge toward the reader: one crease down the middle, on the spine, each half turned back.
const V := {"folds": [0.5], "turns": [-18.0, 18.0], "at": 1}
## The scenery when the design says nothing: a shallow V at the back, its picture cropped to this shape (width / height).
const SCENERY := {"z": -0.4, "height": 0.5, "folds": [0.5], "turns": [-6.0, 6.0], "at": 1, "aspect": 2.4}
## Where a piece may stand, page units from the spine: its feet within [constant REACH_X] across and between
## [constant BACK_Z] and the words' top; folded, inside the page ([constant SHUT_X], [constant SHUT_Z]).
const REACH_X := 0.94
const BACK_Z := -0.72
const SHUT_X := 0.98
const SHUT_Z := 0.74
## The back of a cut-out: plain card.
const CARD := Color(0.92, 0.9, 0.85)
## How long after the last word the leaf turns to the sources, seconds.
const BACK_AFTER := 1.4
## The cover opens over this long, done this long before the story's first word ([PopupWalk] rests the voice for it);
## before the words are known, this long after the intro.
const OPENING := 4.2
const OPEN_DONE := 0.8
const OPEN_UNTIMED := 1.4
## The leaf starts to turn this long before the next scene's first word: early in the voice's rest for it
## ([constant PopupWalk.TURN_REST]).
const TURN_EARLY := 2.8
## The cover closes over this long, never before the last word has been said, and is then held shut this long before
## the show ends, the last of it fading out.
const CLOSING := 4.5
const SHUT_HOLD := 3.8
const END_FADE := 2.4
## A turn to the sources is not begun with less than this long left to see them before the cover closes.
const SOURCES_LEAST := 2.5

const PIECE_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// each crease's foot: (its distance from the spine along its page, its depth z, which page: -1 left, 1 right)
uniform vec3 foot[12];
uniform vec3 page_l;
uniform vec3 page_r;
uniform vec3 org_l;
uniform vec3 org_r;
uniform vec3 crease;
uniform float height = 0.4;
uniform float whole = 0.0;
uniform vec3 card : source_color = vec3(0.92, 0.9, 0.85);

vec3 base_of(int i) {
	vec3 f = foot[i];
	return f.z < 0.0 ? org_l + page_l * f.x + vec3(0.0, 0.0, f.y) : org_r + page_r * f.x + vec3(0.0, 0.0, f.y);
}

// UV across the whole picture; UV2 = (this vertex's crease, the other crease of its panel), so a panel is lit by its own
// normal and the creases stay sharp.
void vertex() {
	int i = int(UV2.x + 0.5);
	int j = int(UV2.y + 0.5);
	VERTEX = base_of(i) + (1.0 - UV.y) * height * crease;
	NORMAL = normalize(cross(base_of(max(i, j)) - base_of(min(i, j)), crease));
}

void fragment() {
	vec4 c = texture(tex, mix(uv_rect.xy, uv_rect.zw, UV));
	bool front = dot(NORMAL, VIEW) > 0.0;
	if (!front) {
		NORMAL = -NORMAL;
	}
	ALBEDO = front ? c.rgb : card;
	ALPHA = whole > 0.5 ? 1.0 : c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.88;
	SPECULAR = 0.1;
}
"""

## The desk's look ([method DeskLook.of]) and the environment it is lit by.
var look: Dictionary = {}
var environment: Dictionary = Surroundings.sanitize({})
var _light := DeskLight.new()
var _desk_node: Node3D
var _desk_key := ""
var _rays: Node3D
var _air = null
## The note's design ([PopupDesign]): `{spreads: [{back, pieces}]}`, by scene.
var _design: Dictionary = {}

var _pool: Array = []            # MeshInstance3D
var _meshes := {}                # panel u's -> ArrayMesh
var _shader: Shader
var _blank: Texture2D            # a piece not yet painted: a plain card
var _shown := ""


# --- mount ---------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	# Boards, not paper: a page lies flat to the spine.
	for leaf in [_leaf_l, _leaf_r, _leaf_t]:
		((leaf as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("lift", 0.0)
	_shader = Shader.new()
	_shader.code = PIECE_SHADER
	for i in POOL:
		var m := MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("card", CARD)
		m.material_override = mat
		m.custom_aabb = AABB(Vector3(-1.6, -0.5, -1.3), Vector3(3.2, 2.2, 2.6))
		m.visible = false
		_book.add_child(m)
		_pool.append(m)
	_blank = _blank_card()
	_light.medium = self


func _build_world() -> void:
	super._build_world()
	# the book at its real size on the desk, its floor on the desk's top
	_book.scale = Vector3.ONE * BOOK_M
	_book.position = Vector3(0.0, LegalPad.DESK_Y + 0.075 * BOOK_M, 0.0)
	_desk_plane.visible = false
	_cam.near = 0.01
	_cam.far = 30.0
	_env.ambient_light_color = DeskMedium.AMBIENT
	_env.ambient_light_energy = DeskMedium.AMBIENT_ENERGY
	Graphics.dress(_env)
	_lamp.spot_range = 4.0
	_lamp.spot_angle = 42.0
	_lamp.spot_angle_attenuation = 1.4
	_lamp.shadow_bias = 0.005
	_lamp.shadow_normal_bias = 0.15
	_lamp.shadow_blur = ShadowFilter.blur(1.4)
	_lamp.position = Vector3(-0.3, 0.55, 0.25)
	_lamp.look_at_from_position(_lamp.position, Vector3(0.0, LegalPad.DESK_Y, 0.0), Vector3.UP)


## A pop-up not yet painted stands as a plain card with a pencil edge, so the spread shows where it goes.
static func _blank_card() -> Texture2D:
	var img := Image.create(240, 300, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.93, 0.88))
	var edge := Color(0.55, 0.5, 0.45)
	for x in 240:
		for y in [0, 1, 298, 299]:
			img.set_pixel(x, y, edge)
	for y in 300:
		for x in [0, 1, 238, 239]:
			img.set_pixel(x, y, edge)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## What this medium shows as pictures, for the Pictures card ([method Medium.pictures_of]): every picture of the read
## part - the scenery asked for as a backdrop ([constant Illustrations.SPREAD]), a floor and the cover as themselves, a
## pop-up as a pop-up.
static func pictures_in(body: String) -> Array:
	var out: Array = []
	for im in Manuscript.images(Manuscript.read_part(body)):
		var d: Dictionary = (im as Dictionary).duplicate()
		var placed := String(d.get("placement", ""))
		if placed == "brief":
			continue                 # a spread's brief is its engineer's to make, in layers painted of their own
		if not bool(d.get("popup", false)) and not bool(d.get("sketch", false)) \
				and placed != Illustrations.COVER and placed != Illustrations.FLOOR:
			d["placement"] = Illustrations.SPREAD
		out.append(d)
	return out


# --- the pieces ------------------------------------------------------------------------

## The crease every piece of a spread leans along, its pages lying [param left] and [param right] (directions from the
## spine across each, perpendicular to it): a V-fold's, whose feet run back from the spine at [param fold_deg] to it -
## square to both feet, on the side the pages face. ZERO where the spread is closed and everything lies flat in it.
static func crease(left: Vector3, right: Vector3, fold_deg := FOLD) -> Vector3:
	var l := left.normalized()
	var r := right.normalized()
	if l.dot(r) > 0.995:
		return Vector3.ZERO
	var s := sin(deg_to_rad(fold_deg))
	var k := cos(deg_to_rad(fold_deg))
	var c := (l * s - Vector3(0.0, 0.0, k)).cross(r * s - Vector3(0.0, 0.0, k))
	if c.length() < 1e-4:
		return Vector3.ZERO
	var up := l.cross(Vector3(0.0, 0.0, 1.0)) + Vector3(0.0, 0.0, 1.0).cross(r)
	return (c if c.dot(up) >= 0.0 else -c).normalized()


## A piece standing on an open spread, as [param piece] says (`z`, `x`, `height`, `folds`, `turns`, `at`) for a picture
## [param aspect] wide for each of its tall: `{feet, u, height}` - each crease's foot (x across, z toward the reader; page
## units), each crease's place across the picture, and the height it stands at: the one asked, or less where it would
## not otherwise stand inside the page, off the words below [param words_z], and fold flat inside the page.
static func footprint(piece: Dictionary, aspect: float, words_z: float) -> Dictionary:
	var folds: Array = (piece.get("folds", []) as Array).slice(0, MOST_PANELS - 1)
	var u := PackedFloat32Array([0.0])
	for f in folds:
		u.append(clampf(float(f), u[u.size() - 1], 1.0))
	u.append(1.0)
	var n := u.size() - 1
	var turns: Array = piece.get("turns", [])
	var at := clampi(int(piece.get("at", n / 2)), 0, n)
	# its shape at a height of 1, from the crease on the spine
	var shape := PackedVector2Array()
	shape.resize(n + 1)
	shape[at] = Vector2.ZERO
	for i in range(at, n):
		var th := deg_to_rad(float(turns[i]) if i < turns.size() else 0.0)
		shape[i + 1] = shape[i] + Vector2(cos(th), -sin(th)) * (u[i + 1] - u[i]) * aspect
	for i in range(at - 1, -1, -1):
		var th := deg_to_rad(float(turns[i]) if i < turns.size() else 0.0)
		shape[i] = shape[i + 1] - Vector2(cos(th), -sin(th)) * (u[i + 1] - u[i]) * aspect
	var origin := Vector2(float(piece.get("x", 0.0)), float(piece.get("z", 0.0)))
	var h := maxf(float(piece.get("height", 0.4)), 0.02)
	var s := sin(deg_to_rad(FOLD))
	var k := cos(deg_to_rad(FOLD))
	for p in shape:
		# standing: within reach, back of the words; folded (the crease lies in the page, falling forward and out): inside
		if absf(p.x) > 1e-5:
			h = minf(h, (REACH_X - absf(origin.x)) / absf(p.x)) if absf(origin.x) < REACH_X else h
		if p.y < -1e-5:
			h = minf(h, (origin.y - BACK_Z) / -p.y)
		elif p.y > 1e-5:
			h = minf(h, (words_z - origin.y) / p.y)
		h = minf(h, (SHUT_X - absf(origin.x)) / (absf(p.x) + k))
		h = minf(h, (SHUT_Z - origin.y) / (p.y + s) if p.y + s > 1e-5 else h)
	h = maxf(h, 0.02)
	var feet := PackedVector2Array()
	for p in shape:
		feet.append(origin + p * h)
	return {"feet": feet, "u": u, "height": h}


## The pieces of the scene on spread [param s] as they stand, before any page moves: `[{key, tex, feet, u, height, uv,
## whole}]`, the scenery first. The design's layers where it makes the scene ([method PopupDesign.layered]: each a picture of
## its own words), else the script's own marks (its scenery and its pop-ups, each a V where the design says nothing).
func _pieces_of(s: int) -> Array:
	var lay := _layout as PopupLayout
	var out: Array = []
	if lay == null or s < 0 or s >= lay.pieces.size():
		return out
	var scene: int = int(lay.scene_of[s]) if s < lay.scene_of.size() else -1
	var asked := PopupDesign.scene_of(_design, scene)
	var words_z := (PopupLayout.TEXT_TOP - 0.5) * PAGE_H - 0.02
	var layered := PopupDesign.layered(asked)
	# the scenery: the design's own picture, else the script's
	var back_piece: Dictionary = asked.get("back") if asked.get("back") is Dictionary else {}
	var back_key := ""
	if layered:
		if not String(back_piece.get("picture", "")).is_empty():
			back_key = PopupDesign.key_of("back", String(back_piece["picture"]))
	elif not (lay.backs[s] as Dictionary).is_empty():
		back_key = String((lay.backs[s] as Dictionary)["key"])
	if not back_key.is_empty() and not bool(back_piece.get("hidden", false)):
		var piece: Dictionary = SCENERY.merged(back_piece, true)
		var tex := _texture_for(back_key)
		var want := maxf(float(piece.get("aspect", SCENERY["aspect"])), 0.3)
		var uv := Rect2(0.0, 0.0, 1.0, 1.0)
		if tex != null:
			var ta := float(tex.get_width()) / float(maxi(tex.get_height(), 1))
			if ta > want:
				uv = Rect2((1.0 - want / ta) * 0.5, 0.0, want / ta, 1.0)
			else:
				var f := ta / want
				uv = Rect2(0.0, (1.0 - f) * 0.65, 1.0, f)
		out.append(footprint(piece, want, words_z).merged({"key": back_key, "tex": tex if tex != null else _blank, "uv": uv,
			"whole": true}))
	# the cut-outs, farthest back first
	var designed: Array = asked.get("pieces", []) if asked.get("pieces") is Array else []
	var list: Array = []
	if layered:
		for p in designed.slice(0, PopupDesign.MOST):
			if p is Dictionary and not String((p as Dictionary).get("picture", "")).is_empty():
				list.append({"key": PopupDesign.key_of("piece", String(p["picture"])), "piece": p})
	else:
		for i in (lay.pieces[s] as Array).size():
			list.append({"key": String(((lay.pieces[s] as Array)[i] as Dictionary)["key"]),
				"piece": designed[i] if i < designed.size() and designed[i] is Dictionary else {}})
	for i in list.size():
		var key := String((list[i] as Dictionary)["key"])
		var tex := _texture_for(key)
		var aspect := float(tex.get_width()) / float(maxi(tex.get_height(), 1)) if tex != null else 0.8
		var piece: Dictionary = (list[i] as Dictionary)["piece"]
		if bool(piece.get("hidden", false)):
			continue
		if not piece.has("z") or not piece.has("height"):
			piece = V.merged(slot(i, list.size(), aspect)).merged(piece, true)
		out.append(footprint(piece, aspect, words_z).merged({"key": key, "tex": tex if tex != null else _blank,
			"uv": Rect2(0.0, 0.0, 1.0, 1.0), "whole": false}))
	return out


## Where cut-out [param i] of [param n] stands when nothing says: `{z, height}`, the farthest back tallest and the nearest
## smallest, spread evenly between the scenery and the words, a V's halves narrower toward the front, for a picture
## [param aspect] wide for each of its tall.
static func slot(i: int, n: int, aspect: float) -> Dictionary:
	if SLOTS.has(n):
		var sl: Array = SLOTS[n][i]
		return {"z": sl[0], "height": minf(float(sl[1]), 2.0 * float(sl[2]) / maxf(aspect, 0.1))}
	var k := float(i) / float(maxi(n - 1, 1))
	var w := lerpf(0.62, 0.34, k)
	return {"z": lerpf(-0.24, 0.15, k), "height": minf(lerpf(0.44, 0.24, k), 2.0 * w / maxf(aspect, 0.1))}


## A designed floor under the scene on page [param pg]'s spread, printed across its band before its words; else the book's
## paper.
func _draw_paper(ci: CanvasItem, pg: Dictionary) -> void:
	super._draw_paper(ci, pg)
	var page := _page_of(pg)
	var band := Rect2(0.0, 0.0, PopupLayout.PAGE.x, PopupLayout.PAGE.y * PopupLayout.TEXT_TOP - PopupLayout.ART_GAP)
	var key := _floor_key(page)
	if not key.is_empty():
		_draw_image(ci, {"rect": band, "key": key, "prompt": "", "span": int(pg["side"])})
		return
	# a spread its engineer has not made yet: its brief, faint, across the band of its left page
	var brief := _unmade_brief(page)
	if not brief.is_empty() and int(pg["side"]) == 0:
		ci.draw_multiline_string(_layout.face(1), band.position + Vector2(140.0, band.size.y * 0.38), brief,
			HORIZONTAL_ALIGNMENT_CENTER, band.size.x - 180.0, 26, 7, Color(_ink, 0.32))


## The page [param pg] is, by its place in the layout.
func _page_of(pg: Dictionary) -> int:
	return _layout.pages.find(pg) if _layout != null else -1


## The designed floor's picture under page [param page]'s spread, "" for none.
func _floor_key(page: int) -> String:
	var lay := _layout as PopupLayout
	if lay == null or page < 0:
		return ""
	var s := page / 2
	var scene: int = int(lay.scene_of[s]) if s < lay.scene_of.size() else -1
	var floor: Variant = PopupDesign.scene_of(_design, scene).get("floor")
	if not (floor is Dictionary) or String((floor as Dictionary).get("picture", "")).is_empty():
		return ""
	return PopupDesign.key_of("floor", String(floor["picture"]))


## The script's brief for page [param page]'s spread while the design makes nothing of it, "" otherwise.
func _unmade_brief(page: int) -> String:
	var lay := _layout as PopupLayout
	if lay == null or page < 0 or page / 2 >= lay.briefs.size():
		return ""
	var s := page / 2
	var scene: int = int(lay.scene_of[s]) if s < lay.scene_of.size() else -1
	return "" if PopupDesign.layered(PopupDesign.scene_of(_design, scene)) else String(lay.briefs[s])


## A page redraws when its designed floor's picture changes or lands, or its spread is made.
func _page_state(page: int) -> String:
	var key := _floor_key(page)
	return "%s|%d|%s" % [key, 0 if key.is_empty() or _texture_for(key) == null else 1, _unmade_brief(page).left(12)]


func _place_leaves() -> void:
	super._place_leaves()
	_sink_blocks()
	_place_pieces()


## Where a board starts to lie flat past the gutter's dip, and how far under it the page blocks sit: a flat board
## lies exactly on its block's top (the book's swell keeps its pages off it), so the block stops short of the dip and
## sits a hair lower, or the two fight for the same surface.
const BLOCK_FROM := 0.32
const BLOCK_SINK := 0.004

func _sink_blocks() -> void:
	var inner := BLOCK_FROM
	var outer := 0.9925
	var full := 0.985 - STACK_GAP
	for st in [[_stack_l, -1.0], [_stack_r, 1.0]]:
		var m: MeshInstance3D = st[0]
		m.scale.x = (outer - inner) / full
		m.position.x = float(st[1]) * (inner + outer) * 0.5
		m.position.y -= BLOCK_SINK


## Stand every piece of the spreads in shot on its pages as they lie this frame: the open spread (its right page the
## turning leaf while one turns), and the spread a turn is going to (its left page the leaf's back).
func _place_pieces() -> void:
	for m in _pool:
		(m as MeshInstance3D).visible = false
	if _layout == null:
		return
	var turning := _turn_t >= 0.0
	var k := _turn_k()
	var a := PI * k
	var yl := _stack_depth.x
	var yr := _stack_depth.z
	var piv := _pivot.transform
	var left := piv.basis * Vector3(-1.0, 0.0, 0.0)
	var left_at := piv * Vector3(0.0, yl, 0.0)
	var leaf := Vector3(cos(a), sin(a), 0.0)
	var leaf_at := Vector3(0.0, lerpf(yr, yl, k) + 0.003, 0.0)
	var flat := Vector3(1.0, 0.0, 0.0)
	var flat_at := Vector3(0.0, yr, 0.0)
	var views := [[_spread, left, left_at, leaf if turning else flat, leaf_at if turning else flat_at]]
	if turning:
		views.append([_turn_to, leaf, leaf_at, flat, flat_at])
	var shown: Array = []
	var used := 0
	for view in views:
		var c := crease(view[1], view[3])
		if c == Vector3.ZERO:
			continue
		for pc in _pieces_of(int(view[0])):
			if used >= _pool.size():
				break
			var m: MeshInstance3D = _pool[used]
			used += 1
			_stand(m, pc, c, view)
			shown.append("%d:%s" % [int(view[0]), String(pc["key"]).substr(0, 6)])
	_shown = ",".join(shown)


## Piece [param pc] stood by mesh [param m] along crease [param c], on the pages of [param view].
func _stand(m: MeshInstance3D, pc: Dictionary, c: Vector3, view: Array) -> void:
	var u: PackedFloat32Array = pc["u"]
	var key := str(u)
	if not _meshes.has(key):
		_meshes[key] = _panel_mesh(u)
	m.mesh = _meshes[key]
	var feet := PackedVector3Array()
	for p in (pc["feet"] as PackedVector2Array):
		feet.append(Vector3(absf(p.x), p.y, -1.0 if p.x < -1e-5 else 1.0))
	while feet.size() < 12:
		feet.append(Vector3.ZERO)
	var mat := m.material_override as ShaderMaterial
	var uv: Rect2 = pc["uv"]
	mat.set_shader_parameter("tex", pc["tex"])
	mat.set_shader_parameter("uv_rect", Vector4(uv.position.x, uv.position.y, uv.end.x, uv.end.y))
	mat.set_shader_parameter("foot", feet)
	mat.set_shader_parameter("page_l", (view[1] as Vector3).normalized())
	mat.set_shader_parameter("org_l", view[2])
	mat.set_shader_parameter("page_r", (view[3] as Vector3).normalized())
	mat.set_shader_parameter("org_r", view[4])
	mat.set_shader_parameter("crease", c)
	mat.set_shader_parameter("height", pc["height"])
	mat.set_shader_parameter("whole", 1.0 if bool(pc["whole"]) else 0.0)
	m.visible = true


## A piece of [param u]'s creases as quads, one a panel, each vertex told its crease and its panel's other (UV2).
static func _panel_mesh(u: PackedFloat32Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in u.size() - 1:
		var b := v.size()
		for c in [[i, i + 1, 0.0], [i + 1, i, 0.0], [i, i + 1, 1.0], [i + 1, i, 1.0]]:
			var at := int(c[0])
			v.append(Vector3(u[at], 1.0 - float(c[2]), 0.0))
			uv.append(Vector2(u[at], float(c[2])))
			uv2.append(Vector2(float(c[0]), float(c[1])))
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


# --- the desk ---------------------------------------------------------------------------

func advance(features, delta: float, bookend: float) -> void:
	if _subs != null and is_instance_valid(_subs):
		var d: Dictionary = _subs.document
		_design = d.get("popup", {}) if d.get("popup") is Dictionary else {}
		var rows: Dictionary = d.get("medium", {}) if d.get("medium") is Dictionary else {}
		_dress_desk(rows, Surroundings.sanitize(d.get("environment")), String(d.get("title", "")))
	elif look.is_empty():
		_dress_desk({}, Surroundings.sanitize({}), "")
	super.advance(features, delta, bookend)
	_light.tick(maxf(feed.show_time(), 0.0))


## The desk's number: the rows' (`seed`), else the note's own, from its title.
static func desk_seed(rows: Dictionary, title: String) -> int:
	var n := int(rows.get("seed", 0)) if rows.get("seed") is float or rows.get("seed") is int else 0
	return n if n > 0 else (absi(hash(["popup desk", title])) % 9973) + 1


## The desk dressed as [param rows] (the Medium card's desk rows) and [param env] (the Environment card) say, once for
## each change: its top and what lies on it - nothing under the open book - its lamp, candles and room light.
func _dress_desk(rows: Dictionary, env: Dictionary, title: String) -> void:
	var seed := desk_seed(rows, title)
	var picks := DeskLook.picks_of(rows, env)
	var key := str([seed, picks, env])
	if key == _desk_key or _root3 == null:
		return
	_desk_key = key
	environment = env
	look = DeskLook.of(seed, picks)
	if _desk_node != null:
		_desk_node.queue_free()
	var dressed := DeskLook.dress(look, seed, LegalPad.DESK_Y)
	_desk_node = dressed["node"]
	var lit := _clear_of_book(_desk_node, dressed["lit"])
	_root3.add_child(_desk_node)
	var lamp: Dictionary = look["lamp"]
	_lamp.light_color = lamp["color"]
	_lamp.position = lamp["at"]
	_lamp.look_at_from_position(_lamp.position, Vector3(0.0, LegalPad.DESK_Y, 0.0), Vector3.UP)
	var share := Surroundings.lamp_of(environment, float(lamp.get("share", 1.0))) * Surroundings.share_of(environment, "lamp")
	_lamp.light_energy = float(lamp["energy"]) * share
	_lamp.visible = share > 0.0
	_fill.light_color = look["fill"]
	_light.build(look, lit, seed)
	_light.shares = environment["lights"]
	_fill.visible = not _light.lights_room()
	_dress_environment()
	ShadowCasters.cut_under(_root3)


## The things [param node] holds that would lie under the open book, gone; [param lit] less what burned among them.
func _clear_of_book(node: Node3D, lit: Array) -> Array:
	var half := Vector2(1.08 * BOOK_M + 0.04, 0.82 * BOOK_M + 0.04)
	var gone: Array = []
	for child in node.get_children():
		if not (child is Node3D) or not child.has_meta("kind"):
			continue
		var p := (child as Node3D).position
		if absf(p.x) < half.x and absf(p.z) < half.y:
			gone.append(child)
	for g in gone:
		node.remove_child(g)
		(g as Node).free()
	return lit.filter(func(l: Dictionary) -> bool: return is_instance_valid(l.get("node")))


## How bright the desk is and what is in its air, as [member environment] says: the desk medium's own ([method
## DeskMedium._dress_environment]), round the book.
func _dress_environment() -> void:
	if _env == null or look.is_empty():
		return
	Tonemaps.dress(_env, Surroundings.brightness(environment))
	var row := Surroundings.light_of(environment, String(look.get("mood", "lamplight")))
	var fog := Color.html(String(row["fog"]))
	if _rays != null:
		_rays.queue_free()
		_rays = null
	if Surroundings.has_shafts(environment):
		var sun: Dictionary = (look.get("light", {}) as Dictionary).get("sun", {}) if (look.get("light", {}) as Dictionary).get("sun") is Dictionary else {}
		var from := float(sun.get("from", DeskMedium.RAYS_FROM.x)) if sun.get("from") is float or sun.get("from") is int else DeskMedium.RAYS_FROM.x
		var toward := Surroundings.toward(from, float(sun.get("height", DeskMedium.RAYS_FROM.y)))
		_rays = Surroundings.rays(environment, Color.html(String(row["key_color"])), toward,
			[AABB(Vector3(-0.18, LegalPad.DESK_Y, -0.14), Vector3(0.36, 0.0, 0.28))], DeskMedium.RAYS_REACH)
		_root3.add_child(_rays)
	Surroundings.fog_for(_env, environment, 0.0)
	_env.volumetric_fog_length = DeskMedium.FOG_LENGTH
	if _air != null:
		_air.release()
		_air = null
	var fx := Surroundings.effects_of(environment, fog)
	if not fx.is_empty():
		var y := Vector3(0.0, LegalPad.DESK_Y, 0.0)
		_air = Effects.build(fx, {"regions": {"near": AABB(DeskMedium.AIR_NEAR.position + y, DeskMedium.AIR_NEAR.size),
			"far": AABB(DeskMedium.AIR_FAR.position + y, DeskMedium.AIR_FAR.size),
			"room": AABB(DeskMedium.AIR_ROOM.position + y, DeskMedium.AIR_ROOM.size)},
			"camera": _wide_camera(), "fov": _cam.fov, "aspect": 16.0 / 9.0}, hash([_seed, "popup air"]))
		_root3.add_child(_air.root)


## Where the wide view's camera stands, in the world.
func _wide_camera() -> Transform3D:
	var w: Dictionary = _wide_view()
	var p := deg_to_rad(float(w["pitch"]))
	var aim: Vector3 = _book.position + (w["aim"] as Vector3) * BOOK_M
	var at := aim + Vector3(0.0, sin(p), cos(p)) * float(w["dist"]) * BOOK_M
	return Transform3D(Basis.IDENTITY, at).looking_at(aim, Vector3.UP)


func release() -> void:
	super.release()
	_light.release()


# --- the opening and the close ---------------------------------------------------------------

## Open (1) or shut (0): the cover opening while the voice rests after the title, and shutting again at the end.
func _open_now() -> float:
	return _opening() * (1.0 - _closing())


## How far the cover has opened: over [constant OPENING], done [constant OPEN_DONE] before the first word after the title
## (as the take times it).
func _opening() -> float:
	var start := feed.lead() + OPEN_UNTIMED
	var lay := _layout as PopupLayout
	if lay != null and _subs != null and is_instance_valid(_subs) and _lay_t0.has(lay.title_words):
		start = float(_lay_t0[lay.title_words]) + _sub_offset() - OPEN_DONE - OPENING
	return opened_at(feed.show_time(), start, OPENING)


## How far the cover has closed again (0 until the end): over [constant CLOSING] from [method _close_start].
func _closing() -> float:
	if feed.show_length() <= 0.0:
		return 0.0
	return opened_at(feed.show_time(), _close_start(), CLOSING)


## When the cover starts to close: [constant SHUT_HOLD] and [constant CLOSING] before the end, never before the
## last word has been said. Show time.
func _close_start() -> float:
	var done := -INF
	if _subs != null and is_instance_valid(_subs) and not (_subs.words as Array).is_empty():
		done = float((_subs.words.back() as Dictionary).get("t1", 0.0)) + _sub_offset()
	return close_start(feed.show_length(), done)


## The words' clock against the show's: what to add to a word's time to have it in show time.
func _sub_offset() -> float:
	return feed.show_time() - float(_subs.now())


## Smoothly from 0 to 1 over [param over] seconds from [param start], at [param t]. Pure, for a gate.
static func opened_at(t: float, start: float, over: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - start) / maxf(over, 0.01), 0.0, 1.0))


## When the cover of a show [param length] long starts to close, the last word ending at [param done]. Pure.
static func close_start(length: float, done: float) -> float:
	return maxf(length - SHUT_HOLD - CLOSING, done + 0.6)


## Lit until the cover is shut and held, then out over the last [constant END_FADE] seconds (the Director's fade
## would dim the whole outro, the close with it).
func _fade_out(bookend: float) -> float:
	var slen := feed.show_length()
	if slen <= 0.0:
		return bookend
	return clampf((slen - feed.show_time()) / END_FADE, 0.0, 1.0)


## The closed book from above, its cover filling the frame's height.
func _cover_view() -> Dictionary:
	return {"dist": 5.0, "pitch": 77.0, "aim": Vector3(0.53, 0.07, 0.02)}


## The leaf turns early in the voice's rest for it, so the next scene has stood up before its first word.
func _turn_lead() -> float:
	return TURN_EARLY


# --- the book's hooks ------------------------------------------------------------------

func _make_layout() -> BookLayout:
	return PopupLayout.new()


## A board turns flat: no curl over the spine, no swell off it.
func _leaf_bend(_a: float) -> Vector2:
	return Vector2.ZERO


## From low in front, aimed into the pop-up, the whole spread in frame; a spread with nothing standing (the sources)
## from above, as the novel sees its pages.
func _wide_view() -> Dictionary:
	var lay := _layout as PopupLayout
	if lay != null and _spread < lay.pieces.size() and (lay.pieces[_spread] as Array).is_empty() \
			and (lay.backs[_spread] as Dictionary).is_empty() and _turn_t < 0.0:
		return {"dist": 5.0, "pitch": 62.0, "aim": Vector3(0.0, 0.0, 0.06)}
	return {"dist": 4.9, "pitch": 34.0, "aim": Vector3(0.0, 0.2, -0.12)}


## While the words are read: a little nearer and higher than the wide view, never so near that the pop-up leaves the frame -
## the scene and its words are one picture, the camera leaning only a little toward the page being read and the line on it.
func _local_view() -> Dictionary:
	return {"pitch": 50.0}


func _local_dist() -> float:
	return 4.3


func _local_aim(page_x: float, line_z: float) -> Vector3:
	return Vector3(page_x * 0.12, 0.1, 0.12 + 0.15 * (clampf(line_z, 0.24, 0.6) - 0.4))


## A spread is seen at a fraction of the novel's angle: the words are read across both pages at once.
func _spread_tilt() -> float:
	return 0.45


## A spread opens on its pop-up a while before the camera goes to the words.
func _arc_shares() -> Vector2:
	return Vector2(0.24, 0.14)


## Once the last word read has been said, the leaf turns to the sources at the back, and stays there - unless the
## cover would close before they could be seen.
func _spread_wanted(want: int) -> int:
	var lay := _layout as PopupLayout
	if lay == null or lay.back_from < 0:
		return want
	if _spread >= lay.back_from:
		return _spread
	if want < lay.back_from - 1 or _subs == null or not is_instance_valid(_subs):
		return want
	if feed.show_length() > 0.0 and _close_start() - feed.show_time() < TURN_TIME + SOURCES_LEAST:
		return want
	var last := -1
	for li in _lay_t:
		last = maxi(last, int(li))
	var first_back := lay.words.size()
	var bp: Array = (lay.pages[lay.back_from * 2] as Dictionary)["words"]
	if not bp.is_empty():
		first_back = int(bp[0])
	if last < 0 or last < first_back - 4 or _subs.now() < float(_lay_t[last]) + BACK_AFTER:
		return want
	return lay.back_from


## A floor printed across the spread under its pieces: the picture covers both pages' band, cropped evenly, each page
## drawing its half; it fades into the paper above the words. Any other picture is the book's.
func _draw_image(ci: CanvasItem, im: Dictionary) -> void:
	if not im.has("span"):
		super._draw_image(ci, im)
		return
	var rect: Rect2 = im["rect"]
	var span := int(im["span"])
	var tex := _texture_for(String(im["key"]))
	if tex == null:
		ci.draw_rect(rect, Color(_ink, 0.03))
		return
	var ts := Vector2(tex.get_size())
	var want := rect.size.x * 2.0 / rect.size.y
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > want:
		var w := ts.y * want
		src = Rect2((ts.x - w) * 0.5, 0.0, w, ts.y)
	else:
		var h := ts.x / want
		src = Rect2(0.0, (ts.y - h) * 0.5, ts.x, h)
	var half := Rect2(src.position.x + src.size.x * 0.5 * float(span), src.position.y, src.size.x * 0.5, src.size.y)
	ci.draw_texture_rect_region(tex, rect, half)
	var fade := 90.0
	for i in 18:
		var y := rect.end.y - fade + fade * float(i) / 18.0
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, fade / 18.0 + 1.0), Color(_paper, float(i + 1) / 18.0))


func debug_line() -> String:
	return super.debug_line() + " pieces [%s]" % _shown

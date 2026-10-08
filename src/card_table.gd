extends RefCounted
class_name CardTable

## CardTable - what an episode's look may name, and how a look is made safe to draw.
##
## The producer invents a whole deck for every episode (see [CardPrompts.producer]), but some
## of a look is drawn by ghost rather than painted: the card's frame and lettering, the booklet's
## type, the things standing on the table. Those are REGISTRIES - the producer picks keys from
## them, the table draws them - so a look can be anything an agent imagines and still always be
## something the table knows how to draw. Adding one is an entry here and a branch where it is
## drawn ([CardFaces] for faces and frames, [TableMedium] for props).

## THE TYPE ON A CARD: the face its name and numeral are set in. One string literal per entry,
## and the description is what the producer reads when it chooses (OFL fonts, `fonts/cards/`).
const FACES := {
	"roman": {"file": "res://fonts/cards/Cinzel-Variable.ttf", "weight": 600,
		"about": "inscriptional Roman capitals - classical, carved, the traditional tarot title"},
	"fell": {"file": "res://fonts/cards/IMFellEnglish-Regular.ttf",
		"about": "seventeenth-century English printing type, a little rough - old almanacs and broadsides"},
	"black": {"file": "res://fonts/cards/UnifrakturMaguntia-Book.ttf",
		"about": "blackletter - Gothic manuscripts, German woodcuts"},
	"uncial": {"file": "res://fonts/cards/UncialAntiqua-Regular.ttf",
		"about": "insular uncial - illuminated Celtic manuscripts"},
	"deco": {"file": "res://fonts/cards/Limelight-Regular.ttf",
		"about": "high-contrast Art Deco display - 1920s cinema, cocktail menus"},
	"sign": {"file": "res://fonts/cards/Bungee-Regular.ttf",
		"about": "chunky signage capitals - storefronts, arcades, roadside neon"},
	"typed": {"file": "res://fonts/cards/CourierPrime-Bold.ttf",
		"about": "a typewriter - carbon copies, case files, office memos"},
}

## The booklet's text face, whatever the deck: little white booklets are set in a book face.
const BOOK_FACE := "res://fonts/cards/EBGaramond-Variable.ttf"
const BOOK_ITALIC := "res://fonts/cards/EBGaramond-Italic-Variable.ttf"

## THE FRAME around a card's picture - the border the deck prints on every face and back. Every
## style keeps a border of stock round the picture, its numeral above it and its name below: a
## frameless `bleed` style (removed 2026-10-06, feedback 0010) ran the painting to the card's edge,
## cropped it to the card's shape, and set the name and numeral on plates over it - "It looks nothing
## like other cards, from other episodes." A look naming it is drawn as `line`.
const FRAMES := {
	"line": "a plain border with one thin rule inside it",
	"double": "a border with a double rule, thick and thin",
	"corners": "a border with ornamental brackets in the four corners",
	"deco": "a border with stepped Art Deco corners",
}

## THE CARD ITSELF, beyond its frame's rules (2026-10-07, the user: "Every single card we generate right
## now has a plain, rectangular border ... sometimes that border has rounded corners. Sometimes the cards
## themselves have rounded borders ... the border around the image was... window-shaped"): the shape of
## the picture's WINDOW, the card's CORNERS (the slab is cut to them - [method corner_radius]) and an
## ORNAMENT printed round the card's edge. Each drawn by [CardFaces], chosen by the producer.
const WINDOWS := {
	"rect": "a plain rectangle",
	"rounded": "a rectangle with softly rounded corners",
	"arch": "an arched window: straight sides and bottom, the top corners stepped in and a round arch over them",
	"gothic": "a pointed Gothic arch over straight sides, as a church window",
	"oval": "an oval, as a cameo or a portrait medallion",
	"notched": "a rectangle with its corners cut in, in quarter circles, as an old label",
	"octagon": "a rectangle with its corners cut off straight",
}
## The card's corners, each its radius (meters - a card is 70 mm wide).
const CORNERS := {
	"square": {"r": 0.0012, "about": "all but square, as an old playing card or a trade card"},
	"rounded": {"r": 0.0045, "about": "rounded, as most decks are"},
	"round": {"r": 0.009, "about": "well rounded, as a modern oracle deck or a game card"},
}
const ORNAMENTS := {
	"none": "nothing round the edge",
	"vine": "a vine winding round the card's edge, leaves along it and a curl of tendril now and then",
	"serpent": "a serpent round the card's edge, its scales drawn, its tail in its mouth",
	"laurel": "a laurel of paired leaves running round the card's edge",
	"beads": "a string of beads, large and small, round the card's edge",
	"rope": "a twisted cord round the card's edge",
	"stars": "small four-pointed stars set round the card's edge",
	"scallops": "a scalloped lace edge, a dot in every scallop",
}
## THE BOOKLET'S PAGE, laid out as its printer set it: the same entry, set four ways.
const PAGES := {
	"classic": "centered: the numeral, the name, the keywords in one line, a small ornament, the text justified",
	"drop": "a heading set to the left over a rule, the text opening on a large drop capital, the keywords listed at the foot",
	"banner": "the name printed out of a band of the accent color across the top, the keywords under it, the text centered",
	"ledger": "the name and numeral on one line over a heavy rule, the keywords listed down the page, then the text, ragged",
}

## THE CANDLES: the most LIT THINGS on a table - a candle in its stick, a candelabra, a dish of tea
## lights - each burning as ONE light however many flames it has (a light each is a shadow each, six
## passes a frame), the brightest the key (see [method TableMedium._light_the_table]); and the most
## flames any one of them has.
const MAX_CANDLES := 4
const MAX_FLAMES := 12

## THE THINGS ON THE TABLE are modeled, not painted (see [Props]): the set dresser describes each
## in parts and materials and names where it stands; the table builds and places it. A painted
## cut-out could neither take the candlelight nor cast a shadow. At most this many.
const MAX_THINGS := 12

## WHERE A THING CAN STAND, as the set dresser names it: stretches of the cloth the cards leave
## free. `aim` is a zone's middle on the table (x across, z toward the reader, meters); the table
## finds the spot itself ([method TableMedium._place_things]). "by the deck" is aimed per episode.
const ZONES := {
	"back left": {"aim": Vector2(-0.3, -0.27), "about": "the far left of the cloth, behind where the cards are laid"},
	"back": {"aim": Vector2(0.0, -0.3), "about": "the far middle of the cloth, behind where the cards are laid"},
	"back right": {"aim": Vector2(0.3, -0.27), "about": "the far right of the cloth, behind where the cards are laid"},
	"left": {"aim": Vector2(-0.31, -0.1), "about": "the left side, beside where the cards are laid"},
	"right": {"aim": Vector2(0.31, -0.1), "about": "the right side, beside where the cards are laid"},
	"by the deck": {"aim": Vector2.ZERO, "about": "beside the deck, near the front of the cloth on the side the reader keeps it"},
}

## WHERE THE AIR IS: the stretches of the scene an effect ([Effects]) may fill - boxes in the table's
## space (meters: x to the reader's right, y up from the cloth, z toward the reader) - each with the
## height fog lies on (`floor`: the cloth's), how much of it a line of sight crosses (`sight`, meters:
## what a fog's density is judged over), where motes there fly when that is not the whole box (`motes`:
## a bank's front thins out over the middle of the cloth, but its lights stay at the back) and what it
## is, as the set dresser reads it. The camera looks
## down across the cloth, so past the table's far edge it sees only the floor and the room's lower part.
const AIR := {
	"beyond the table": {"box": AABB(Vector3(-1.7, -0.75, -2.8), Vector3(3.4, 1.25, 2.8)), "floor": 0.0, "sight": 0.9,
		"motes": AABB(Vector3(-1.7, -0.75, -2.8), Vector3(3.4, 1.2, 2.5)),
		"about": "the back of the table and past its far edge: the floor and the room beyond, out of focus - where a bank of fog rolls in and lights hang in the distance; the near table stays clear"},
	"over the cloth": {"box": AABB(Vector3(-0.6, 0.0, -0.4), Vector3(1.2, 0.26, 0.74)), "floor": 0.0, "sight": 0.35,
		"about": "the air just over the cloth, among the things on it and the cards"},
	"low on the cloth": {"box": AABB(Vector3(-0.62, 0.0, -0.42), Vector3(1.24, 0.1, 0.78)), "floor": 0.0, "sight": 0.08,
		"about": "a thin layer lying on the cloth itself, round the feet of the cards and the things"},
	"the whole room": {"box": AABB(Vector3(-2.6, -0.8, -3.0), Vector3(5.2, 2.2, 4.0)), "floor": 0.0, "sight": 3.0,
		"about": "everywhere, the air near the camera too - for a faint haze only, or the reading cannot be seen"},
}
## THE MOMENTS a burst can mark, each where it happens on the table.
const MOMENTS := {
	"shuffle": "as the shuffling begins, at the deck in the middle of the cloth",
	"jumper": "a card leaping out of the deck on its own during a shuffle - thrown along its flight",
	"reveal": "each card as it comes up to the camera and faces the viewer - from its edges; every card's, unless `which` picks one",
	"pirouette": "a held card twirled round in the reader's fingers, a showman's flourish - from its edges as it spins. Cards are seldom twirled; a burst on it makes the reader twirl one",
	"lay": "each card as it lands in the spread - from its edges; every card's, unless `which` picks one",
	"close": "when the last card is down and the reading closes - from every card in the spread",
}

## THE STAGING: how an episode's cards come and are shown, the producer's choice ([method staging_of]).
## `source` - where they come from ([constant TableActions.SOURCES]); `text` - where a card's text is
## printed ([constant TEXTS]).
const STAGING := {"source": "deck", "text": "booklet"}
## WHERE A CARD'S TEXT IS, and so how a drawn card is shown: beside its page in the deck's little
## booklet (held up on the left, the page open on the right), or printed on its own back - held up
## alone in the middle, and turned over to show it.
const TEXTS := {
	"booklet": "a page of the deck's little booklet, shown beside the card while it is held up (a reading deck's, an oracle's)",
	"back": "printed on the card's own back - stats, a bio, rules, an answer - and the card is held up alone in the middle and turned over to show it (a baseball card's, a trading card's)",
}
## THE BOX THE CARDS ARE KEPT IN, at its largest (x across, z front to back, meters) and tallest: a box
## the set dresser made bigger is stood smaller, so the spread is laid clear of where it can stand.
const BOX_MAX := Vector3(0.15, 0.12, 0.22)
## How many printings a deck may mix ([method look_of]).
const MAX_SERIES := 6

## A look's colors when the producer's are missing or not colors at all.
const FALLBACK_PALETTE := ["#1d1a2b", "#c9a227", "#e8dcc0", "#7a2e3a", "#2f5d62"]

## The least contrast (WCAG ratio) a card's ink may have against its stock: the name is printed
## in it. 3 is WCAG's floor for large text.
const INK_CONTRAST := 3.0
## ...and the booklet's running text, which is small: WCAG's floor for body text.
const TEXT_CONTRAST := 4.5

## THE TITLE SCREEN: the show's name over the table thrown out of focus, which is also the video's
## thumbnail (the user, 2026-10-06: "too small in some layouts on mobile"). The name is as large as
## a line of it fits across TITLE_WIDTH of the frame, and no larger than TITLE_SIZE of its height;
## a name that would come out under TITLE_TWO_LINES of that on one line is set on two. The byline
## is TITLE_BYLINE of the name's size, and the whole block is centered TITLE_MIDDLE down the frame.
## Then (2026-10-07) "a little too large. It basically touches the left and the right side of the screen":
## the width it may fill came in from 0.86 to 0.74, a margin of an eighth of the frame each side.
const TITLE_SIZE := 0.15
const TITLE_WIDTH := 0.74
const TITLE_TWO_LINES := 0.7
const TITLE_BYLINE := 0.4
const TITLE_MIDDLE := 0.45
## How tall the title face's capitals stand, as a share of its size (Cinzel's), and how far apart
## two lines of the name are.
const TITLE_CAP := 0.7
const TITLE_PITCH := 1.05
## The name's color when the set dresser chose none (a table set before it was asked, or none
## set yet), and how far the shade round it goes toward black or white ([method title_shade]).
const TITLE_INK := "#fff7e6"
const TITLE_SHADE := 0.85
## THE TABLE BEHIND THE NAME, THROWN FAR OUT OF FOCUS (the user, 2026-10-06: "an extremely strong
## blur, such that nothing is really visible in the scene except for the colors"): a Gaussian whose
## sigma is this share of the frame's height ([TableMedium], `shaders/table_intro.gdshader`). The
## lens's softest bokeh (a sigma of 6.2 px, 0.0086 of a 720 frame, measured) showed "too much table
## detail"; 0.11 came first and was "just a smidge too blurry" (the user: "reduce the blur by about
## 25%"), and 0.0825 was cut "another 50%". tests/intro_blur_check.gd holds it between the verdicts.
const TITLE_BLUR := 0.04125


## THE LENS: the camera's vertical field of view, degrees, before an episode's own small turn of it.
const VFOV := 42.0
## The stretch of the table the camera can see (x z, meters), and the grid it is sampled on: where the
## table's lightness is read ([constant TableMedium.LUM_RECT]) and its light is counted.
const SEEN_RECT := Rect2(-0.7, -0.8, 1.4, 1.24)
const SEEN_GRID := Vector2i(35, 31)
## THE ROOM'S PICTURE is asked for as a LEVEL photograph from a seated reader's eye, its horizon
## across its middle, through a lens this wide (millimeters, on a 36 x 24 frame) - the photograph an
## image model makes most reliably - and projected from the camera's own eye, so the room past the
## table is seen as the tilted camera would see it ([method TableMedium._place_backdrop]).
const BACKDROP_LENS := 20.0
## THE CLOTH'S PICTURE is asked for as this much of the surface, centimeters - as wide as the
## cloth and a little deeper, landscape as the painters make it - so its grain comes out at its
## true size ([method cloth_crop]).
const CLOTH_PICTURE := Vector2(120.0, 80.0)


## THE PART OF A CLOTH'S PICTURE THE CLOTH SHOWS, as a UV rectangle: as much of it as fits on a
## cloth [param cloth] (meters) with its pixels square, cut evenly off the long side. Stretched to
## the cloth, a square picture came out 1.67 times as wide as it was painted, every bead and weave
## with it.
static func cloth_crop(picture: Vector2, cloth: Vector2) -> Rect2:
	# the share of the picture's height the cloth takes when the picture spans its width
	var k := (cloth.y / cloth.x) * (picture.x / maxf(picture.y, 1.0))
	var size := Vector2(1.0, k) if k <= 1.0 else Vector2(1.0 / k, 1.0)
	return Rect2((Vector2.ONE - size) * 0.5, size)


## THE EPISODE'S LAYOUT, drawn from [param rng] in a fixed order: the camera (`camera`, `fov`,
## `pitch`), the lamp (`lamp`, `lamp_energy`), where the deck is kept (`deck`) and shuffled
## (`mid`). The table draws it as it is built; [method layout_of] lets a prompt know it first.
static func sample_layout(rng: RandomNumberGenerator) -> Dictionary:
	# shallow enough that the room always shows past the table's far edge (at 48 it was a sliver)
	var pitch := rng.randf_range(34.0, 42.0)
	var dist := rng.randf_range(0.5, 0.56)
	var yaw := deg_to_rad(rng.randf_range(-3.5, 3.5))
	var target := Vector3(rng.randf_range(-0.01, 0.01), 0.0, -0.05)
	var p := deg_to_rad(pitch)
	var eye := target + Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
	var out := {"pitch": pitch, "camera": Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye),
		"fov": VFOV + rng.randf_range(-1.5, 1.5)}
	# a draw kept where the far blur's distance was sampled, so every draw after it - the lamp,
	# the deck, the spread - lands where it did for episodes already made
	rng.randf_range(0.45, 0.75)
	var side := -1.0 if rng.randf() < 0.6 else 1.0
	# low enough, and far enough to one side, that what stands on the table throws a shadow you see
	out["lamp"] = Vector3(side * rng.randf_range(0.4, 0.6), rng.randf_range(0.75, 0.95), rng.randf_range(-0.35, -0.1))
	out["lamp_energy"] = rng.randf_range(1.3, 1.9)
	out["deck"] = Vector3(rng.randf_range(0.17, 0.23) * (1.0 if rng.randf() < 0.7 else -1.0), 0.0, rng.randf_range(0.04, 0.07))
	out["mid"] = Vector3(rng.randf_range(-0.015, 0.015), 0.0, rng.randf_range(-0.05, -0.02))
	return out


## THE TABLE THE CAMERA SEES, sampled: the middle of every cell of [constant SEEN_GRID] over [constant
## SEEN_RECT] that lies on [param top] (a top made safe, [Tables]) and in the picture of a camera at
## [param cam] with [param fov] - where a light's report counts the sun ([Lights]), and the table's own
## light is fitted ([TableMedium]).
static func seen_points(cam: Transform3D, fov: float, top: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cell := SEEN_RECT.size / Vector2(SEEN_GRID)
	for gy in SEEN_GRID.y:
		for gx in SEEN_GRID.x:
			var p := Vector3(SEEN_RECT.position.x + (gx + 0.5) * cell.x, 0.0, SEEN_RECT.position.y + (gy + 0.5) * cell.y)
			if not Tables.inside(top, Vector2(p.x, p.z), 0.0):
				continue
			var sp: Variant = project(cam, fov, p)
			if sp != null and (sp as Vector2).x > 0.0 and (sp as Vector2).x < 1.0 and (sp as Vector2).y > 0.0 and (sp as Vector2).y < 1.0:
				out.append(p)
	return out


## Where the cards go - the deck, the shuffle, the spread ([constant Tables.HOLDS]) - sampled every few
## centimeters, on the table.
static func card_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var r := Tables.HOLDS
	for gy in 12:
		for gx in 18:
			out.append(Vector3(r.position.x + (gx + 0.5) * r.size.x / 18.0, 0.0, r.position.y + (gy + 0.5) * r.size.y / 12.0))
	return out


## Episode [param seed]'s layout (see [method sample_layout]).
static func layout_of(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-table"])
	return sample_layout(rng)


## WHERE [param at] LANDS IN THE PICTURE of a camera at [param cam] with [param fov] (16:9),
## 0..1 across and down; null behind the camera.
static func project(cam: Transform3D, fov: float, at: Vector3) -> Variant:
	var l: Vector3 = cam.affine_inverse() * at
	if l.z > -0.001:
		return null
	var k := tan(deg_to_rad(fov * 0.5))
	return Vector2(0.5 + l.x / (-l.z * k * (16.0 / 9.0)) * 0.5, 0.5 - l.y / (-l.z * k) * 0.5)


## Whether [param at] is in the picture of a camera at [param cam] with [param fov] (16:9), with a margin
## of a tenth all round - a light there would light the table from where nothing is seen burning.
static func in_shot(cam: Transform3D, fov: float, at: Vector3) -> bool:
	var sp: Variant = project(cam, fov, at)
	if sp == null:
		return false
	var v: Vector2 = sp
	return v.x > -0.1 and v.x < 1.1 and v.y > -0.1 and v.y < 1.1


## HOW TALL A THING CAN STAND AND BE SEEN WHOLE, centimeters, in each of [constant ZONES] for
## episode [param seed]: the frame's top edge passes lower over the far cloth than the near, so
## the back holds only short things. For the set dresser's prompt.
static func headroom(seed: int) -> Dictionary:
	var lay := layout_of(seed)
	var out := {}
	for z in ZONES:
		var aim := zone_aim(String(z), lay["deck"])
		var h := 0.0
		while h < 0.6:
			var top: Variant = project(lay["camera"], float(lay["fov"]), Vector3(aim.x, h + 0.01, aim.y))
			if top == null or (top as Vector2).y < 0.03:
				break
			h += 0.005
		out[z] = roundi(h * 100.0)
	return out


## The middle of zone [param zone] on the table (x, z), the deck kept at [param deck].
static func zone_aim(zone: String, deck: Vector3) -> Vector2:
	if zone == "by the deck":
		return Vector2(deck.x + signf(deck.x) * 0.11, deck.z - 0.07)
	return (ZONES.get(zone, ZONES["back"]) as Dictionary)["aim"]


## THE LOOK MADE SAFE: every key the table reads present, every color a color, every registry
## key one the table knows. Whatever an agent wrote, the table can draw what this returns.
static func sanitize_look(look: Dictionary) -> Dictionary:
	var out := look.duplicate(true)
	var pal: Array = []
	for c in (look.get("palette", []) if look.get("palette") is Array else []):
		if _is_color(String(c)):
			pal.append(String(c))
	if pal.size() < 3:
		pal = FALLBACK_PALETTE.duplicate()
	out["palette"] = pal
	var frame: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	var f := {"style": String(frame.get("style", "")).strip_edges().to_lower()}
	if not FRAMES.has(f["style"]):
		f["style"] = "line"
	f["stock"] = String(frame.get("stock", "")) if _is_color(String(frame.get("stock", ""))) else "#efe6d2"
	f["ink"] = String(frame.get("ink", "")) if _is_color(String(frame.get("ink", ""))) else String(pal[0])
	f["accent"] = String(frame.get("accent", "")) if _is_color(String(frame.get("accent", ""))) else String(pal[1])
	for k in [["window", WINDOWS, "rect"], ["corners", CORNERS, "rounded"], ["ornament", ORNAMENTS, "none"]]:
		var v := String(frame.get(k[0], "") if frame.get(k[0]) is String else "").strip_edges().to_lower()
		f[k[0]] = v if (k[1] as Dictionary).has(v) else String(k[2])
	# the producer may print on any stock, black to white: the name must read on it
	var ink := color(f["ink"])
	var readable := legible_ink(ink, color(f["stock"]))
	if readable != ink:
		f["ink"] = "#" + readable.to_html(false)
	out["frame"] = f
	var face := String(look.get("title_face", "")).strip_edges().to_lower()
	out["title_face"] = face if FACES.has(face) else "roman"
	var page := String(look.get("page", "") if look.get("page") is String else "").strip_edges().to_lower()
	out["page"] = page if PAGES.has(page) else "classic"
	# the candles: a count - an older look named props, and its candles carry over
	var candles := 1
	var nc: Variant = look.get("candles")
	if nc is int or nc is float:
		candles = clampi(int(nc), 0, MAX_CANDLES)
	elif look.get("props") is Array:
		var old: Array = look["props"]
		candles = 3 if old.has("candles") else (1 if old.has("candle") else 0)
	out["candles"] = candles
	out.erase("props")
	out.erase("objects")
	var light: Dictionary = look.get("light", {}) if look.get("light") is Dictionary else {}
	out["light"] = {"kind": String(light.get("kind", "candlelight")),
		"color": String(light.get("color", "")) if _is_color(String(light.get("color", ""))) else "#ffb36b",
		"warmth": "cool" if String(light.get("warmth", "")).to_lower().begins_with("cool") else "warm"}
	for k in ["deck_name", "deck_style", "card_back", "surface", "setting"]:
		out[k] = String(look.get(k, ""))
	out["foil"] = clampf(float(look.get("foil", 0.6)) if (look.get("foil") is float or look.get("foil") is int) else 0.6, 0.0, 1.0)
	# THE PRINTINGS a deck mixes, each a name and what it prints otherwise ([method look_of])
	var series: Array = []
	for sv in look.get("series", []) if look.get("series") is Array else []:
		if sv is Dictionary and not str((sv as Dictionary).get("name", "")).strip_edges().is_empty() and series.size() < MAX_SERIES \
				and not series.any(func(o: Variant) -> bool: return str((o as Dictionary)["name"]).to_lower() == str((sv as Dictionary)["name"]).strip_edges().to_lower()):
			var e := {"name": str((sv as Dictionary)["name"]).strip_edges()}
			for k in ["deck_style", "card_back", "title_face"]:
				if (sv as Dictionary).get(k) is String:
					e[k] = String((sv as Dictionary)[k])
			if (sv as Dictionary).get("palette") is Array:
				e["palette"] = (sv as Dictionary)["palette"]
			if (sv as Dictionary).get("frame") is Dictionary:
				e["frame"] = (sv as Dictionary)["frame"]
			if (sv as Dictionary).get("foil") is float or (sv as Dictionary).get("foil") is int:
				e["foil"] = (sv as Dictionary)["foil"]
			series.append(e)
	if series.is_empty():
		out.erase("series")
	else:
		out["series"] = series
	return out


## HOW ROUND [param look]'s CARDS ARE CUT at the corners, meters ([constant CORNERS]).
static func corner_radius(look: Dictionary) -> float:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	return float((CORNERS.get(String(f.get("corners", "rounded")), CORNERS["rounded"]) as Dictionary)["r"])


## THE STAGING OF [param plan], made safe: [constant STAGING]'s keys, each one of its own registry's.
static func staging_of(plan: Dictionary) -> Dictionary:
	var st: Dictionary = plan.get("staging", {}) if plan.get("staging") is Dictionary else {}
	var source := str(st.get("source", "")).strip_edges().to_lower()
	var text := str(st.get("text", "")).strip_edges().to_lower()
	return {"source": source if TableActions.SOURCES.has(source) else String(STAGING["source"]),
		"text": text if TEXTS.has(text) else String(STAGING["text"])}


## THE PRINTING [param card] belongs to, by name, in [param look]'s `series` - its own `series`, or its
## group's name when a printing is called that - or "" for the deck's own.
static func series_of(look: Dictionary, card: Dictionary) -> String:
	var names: Array = []
	for s in look.get("series", []) if look.get("series") is Array else []:
		if s is Dictionary and not str((s as Dictionary).get("name", "")).strip_edges().is_empty():
			names.append(str((s as Dictionary)["name"]).strip_edges())
	for want in [str(card.get("series", "")), str(card.get("group", ""))]:
		for n in names:
			if String(n).to_lower() == want.strip_edges().to_lower() and not want.strip_edges().is_empty():
				return String(n)
	return ""


## A printing's name as a file's key: `back_<key>.png`.
static func series_key(name: String) -> String:
	return CardEpisode.slug(name)


## THE LOOK [param card] IS PRINTED IN: [param look], with its printing's own written over it (its
## style, its back, its palette, its frame - a frame's colors one by one - its title face, its foil), made
## safe. A deck of one printing is every card's look.
static func look_of(look: Dictionary, card: Dictionary) -> Dictionary:
	var name := series_of(look, card)
	if name.is_empty():
		return look
	var out := look.duplicate(true)
	for s in look["series"]:
		if not (s is Dictionary) or str((s as Dictionary).get("name", "")).strip_edges() != name:
			continue
		for k in (s as Dictionary):
			var v: Variant = (s as Dictionary)[k]
			if k == "name":
				continue
			if k == "frame" and v is Dictionary:
				var f: Dictionary = (out.get("frame", {}) as Dictionary).duplicate() if out.get("frame") is Dictionary else {}
				f.merge(v as Dictionary, true)
				out["frame"] = f
			elif k in ["deck_style", "card_back", "palette", "title_face", "foil"]:
				out[k] = v
		break
	out.erase("series")
	return sanitize_look(out)


## THE TABLE MADE SAFE: the set dresser's reply as [Props] can build it, its `top` and `layers` as
## [Tables] can (the old table when it wrote neither), every thing standing in a
## zone the table knows ("back" when it named none), things sharing a `group` kept together, no
## more lit things than [constant MAX_CANDLES] and no more than [constant MAX_FLAMES] flames on one
## - the first written keep their flames, the rest stand unlit - its `effects` as [Effects] can
## build them, in the table's [constant AIR] and at its [constant MOMENTS], its `light` as [Lights]
## can build it (`{}` when it wrote none: the lamp and the room's candles, as every table had), and its
## `title` (the color the show's name is printed in over it) when that is a color.
static func sanitize_table(spec: Dictionary, look: Dictionary) -> Dictionary:
	var out := Props.sanitize(spec, look.get("palette", FALLBACK_PALETTE) if look.get("palette") is Array else FALLBACK_PALETTE)
	var things: Array = []
	var lit := 0
	for t in (out["things"] as Array).slice(0, MAX_THINGS):
		var thing: Dictionary = t
		var place := String(thing.get("place", "")).strip_edges().to_lower()
		thing["place"] = place if ZONES.has(place) else "back"
		var g: Variant = thing.get("group", "")
		thing["group"] = str(int(g)) if (g is float or g is int) else String(g if g is String else "").strip_edges()
		thing["turn"] = Props._num(thing.get("turn"), 0.0, -180.0, 180.0)
		# THE BOX THE CARDS ARE KEPT IN: one thing at most, stood where the deck would be
		var holds: bool = thing.get("holds_cards") == true and not things.any(func(o: Variant) -> bool: return bool((o as Dictionary).get("holds_cards", false)))
		thing["holds_cards"] = holds
		var flames := 0
		for p in thing["parts"]:
			var n := Props.flames_of(p as Dictionary)
			if n == 0:
				continue
			if lit >= MAX_CANDLES or flames + n > MAX_FLAMES:
				Props.unlit(p as Dictionary)
			else:
				flames += n
		if flames > 0:
			lit += 1
		things.append(thing)
	out["things"] = things
	# THE TABLE ITSELF - its top and the layers laid on it ([Tables]): the table every episode had
	# before when the set dresser wrote neither
	var furniture := Tables.sanitize(spec.get("top"), spec.get("layers"), out["materials"],
		look.get("palette", FALLBACK_PALETTE) if look.get("palette") is Array else FALLBACK_PALETTE)
	out["top"] = furniture["top"]
	out["layers"] = furniture["layers"]
	# THE AIR: fog, motes and bursts the set dresser wrote beside its things
	out["effects"] = Effects.sanitize(spec.get("effects", []), look.get("palette", FALLBACK_PALETTE) if look.get("palette") is Array else FALLBACK_PALETTE,
		AIR.keys(), MOMENTS.keys())
	# THE LIGHT: the sky, the sun and what it falls through, the weather, lamps out of the shot
	out["light"] = Lights.sanitize(spec.get("light"))
	# THE TITLE'S COLOR, chosen to stand out from this table: kept when it is a color at all
	var title: Dictionary = spec.get("title", {}) if spec.get("title") is Dictionary else {}
	out["title"] = {}
	if _is_color(String(title.get("color", "")) if title.get("color") is String else ""):
		out["title"] = {"color": String(title["color"]).strip_edges(), "why": Props._text(title.get("why", ""), 200)}
	return out


## THE TABLE BEFORE THE SET DRESSER HAS SET ONE: the look's candles alone, plain pillars of wax a
## shade of its palette each, flanking the cloth.
static func default_table(look: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-default-candles"])
	var pal: Array = look.get("palette", FALLBACK_PALETTE) if look.get("palette") is Array else FALLBACK_PALETTE
	var things: Array = []
	var mats := {}
	for i in clampi(int(look.get("candles", 1)), 0, MAX_CANDLES):
		var r := rng.randf_range(1.7, 2.6)
		var h := rng.randf_range(7.0, 12.0)
		var wax := Color(0.8, 0.76, 0.68).lerp(color(String(pal[rng.randi_range(0, pal.size() - 1)])), rng.randf_range(0.1, 0.5))
		mats["wax %d" % i] = {"kind": "wax", "color": "#" + wax.to_html(false)}
		things.append({"name": "a candle", "place": "back left" if i % 2 == 0 else "back right",
			"parts": [{"shape": "lathe", "profile": [[0, 0], [r, 0], [r * 0.98, h], [0, h]], "material": "wax %d" % i,
				"wick": true, "drips": rng.randf_range(0.0, 0.4)}]})
	return sanitize_table({"things": things, "materials": mats}, look)


## A card's footprint on the table at [param pos], turned by [param yaw]: a rectangle in x by z.
static func footprint(pos: Vector3, yaw: float, card: Vector2) -> Rect2:
	var hx := absf(cos(yaw)) * card.x * 0.5 + absf(sin(yaw)) * card.y * 0.5
	var hz := absf(sin(yaw)) * card.x * 0.5 + absf(cos(yaw)) * card.y * 0.5
	return Rect2(pos.x - hx, pos.z - hz, hx * 2.0, hz * 2.0)


## HOW FAR A SPREAD MUST MOVE to lie clear of [param keep_out] (a rectangle on the table, x by z -
## the deck): the smaller of stepping back (-z, away from the reader) and stepping aside, away
## from it. An offset (x, z), zero when nothing touches. [param slots] are `{pos, yaw}`.
static func clear_of(slots: Array, card: Vector2, keep_out: Rect2) -> Vector2:
	var back := 0.0
	var aside := 0.0
	var right := keep_out.get_center().x > 0.0         # step aside AWAY from it
	# a card that a step would carry THROUGH it rules that step out: one nearer the reader than it
	# (stepping back), one past its far side (stepping aside)
	var front := false
	var beyond := false
	for sl in slots:
		var r := footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), card)
		var x_over := r.position.x < keep_out.end.x and r.end.x > keep_out.position.x
		var z_over := r.position.y < keep_out.end.y and r.end.y > keep_out.position.y
		if x_over and z_over:
			back = maxf(back, r.end.y - keep_out.position.y)
			aside = maxf(aside, r.end.x - keep_out.position.x if right else keep_out.end.x - r.position.x)
		elif x_over and r.position.y >= keep_out.end.y:
			front = true
		elif z_over and (r.position.x >= keep_out.end.x if right else r.end.x <= keep_out.position.x):
			beyond = true
	if back <= 0.0:
		return Vector2.ZERO
	var go_aside := (aside < back or front) and not (beyond and not front)
	return Vector2(-aside if right else aside, 0.0) if go_aside else Vector2(0.0, -back)


## What the reader is told stands on the table besides the cloth, the deck and the cards: the
## look's candles and the reader's own things (the set dresser's, which no passage depends on).
static func on_the_table(look: Dictionary) -> String:
	var n := int(look.get("candles", 0))
	if n <= 0:
		return "the reader's own things"
	return "%s lit candle%s and the reader's own things" % [["", "one", "two", "three", "four"][mini(n, 4)], "" if n == 1 else "s"]


static func _is_color(s: String) -> bool:
	return Manuscript._rx("^#[0-9a-fA-F]{6}$").search(s.strip_edges()) != null


static func color(s: String, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	return Color.html(s.strip_edges()) if _is_color(s) else fallback


## WCAG's contrast ratio between two colors: 1 is the same, 21 is black on white.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## THE TITLE'S INK: the color the set dresser chose for the show's name over its table ([param spec]
## made safe by [method sanitize_table]), else [constant TITLE_INK].
static func title_ink(spec: Dictionary) -> Color:
	var title: Dictionary = spec.get("title", {}) if spec.get("title") is Dictionary else {}
	return color(String(title.get("color", "")) if title.get("color") is String else "", color(TITLE_INK))


## THE SHADE ROUND THE TITLE: the ink's own hue taken nearly to black or white, whichever stands
## further from it - dark round a light name, light round a dark one - so the letters always have an
## edge to read against, whatever the table behind them is.
static func title_shade(ink: Color) -> Color:
	var to := Color.WHITE if contrast(Color.WHITE, ink) > contrast(Color.BLACK, ink) else Color.BLACK
	return ink.lerp(to, TITLE_SHADE)


## THE TITLE SCREEN'S TYPE for a [param frame] (pixels): the show's [param name] in [param face] -
## on one line as large as fits ([constant TITLE_SIZE], [constant TITLE_WIDTH]), or on two where one
## would set it under [constant TITLE_TWO_LINES] of that and two set it larger - and [param under]
## (the byline) beneath it in [param italic]. `{lines: [{text, italic, size, y}], box: Rect2}`: `y` is
## a line's baseline, every line centered across the frame; `box` runs from the top of the name's
## capitals to the foot of the last line.
static func title_layout(face: Font, italic: Font, name: String, under: String, frame: Vector2) -> Dictionary:
	var cap := maxi(int(frame.y * TITLE_SIZE), 8)
	var room := frame.x * TITLE_WIDTH
	var rows := PackedStringArray([name.strip_edges()])
	var size := fit_rows(face, rows, cap, room)
	var words := name.strip_edges().split(" ", false)
	if size < cap * TITLE_TWO_LINES and words.size() >= 2:
		# the break whose longer half is the shortest
		var best := PackedStringArray()
		var widest := INF
		for i in range(1, words.size()):
			var pair := PackedStringArray([" ".join(words.slice(0, i)), " ".join(words.slice(i))])
			var w := maxf(face.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x,
				face.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x)
			if w < widest:
				widest = w
				best = pair
		var two := fit_rows(face, best, cap, room)
		if two > size:
			rows = best
			size = two
	var lines: Array = []
	var pitch := size * TITLE_PITCH
	for i in rows.size():
		lines.append({"text": rows[i], "italic": false, "size": size, "y": pitch * i})
	var top := -size * TITLE_CAP
	var bottom := pitch * (rows.size() - 1) + size * 0.05
	var u := under.strip_edges()
	if not u.is_empty() and italic != null:
		var us := fit_rows(italic, PackedStringArray([u]), maxi(int(size * TITLE_BYLINE), 8), frame.x * 0.8)
		var uy := pitch * (rows.size() - 1) + size * 0.32 + us * 0.8
		lines.append({"text": u, "italic": true, "size": us, "y": uy})
		bottom = uy + us * 0.25
	var shift := frame.y * TITLE_MIDDLE - (top + bottom) * 0.5
	for l in lines:
		(l as Dictionary)["y"] = float((l as Dictionary)["y"]) + shift
	return {"lines": lines, "box": Rect2(0.0, top + shift, frame.x, bottom - top)}


## The largest size up to [param cap] at which every one of [param rows] fits [param room] pixels
## across in [param font].
static func fit_rows(font: Font, rows: PackedStringArray, cap: int, room: float) -> int:
	var w := 0.0
	for r in rows:
		w = maxf(w, font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x)
	var s := mini(cap, int(100.0 * room / maxf(w, 1.0)))
	# a face's widths are not quite proportional to its size: step down to where it truly fits
	while s > 8:
		var widest := 0.0
		for r in rows:
			widest = maxf(widest, font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		if widest <= room:
			break
		s -= 1
	return maxi(s, 8)


## [param ink] as it is when it reads on [param stock] (contrast at least [param least]);
## otherwise moved toward white or black, whichever stands further from the stock, until it does.
static func legible_ink(ink: Color, stock: Color, least := INK_CONTRAST) -> Color:
	if contrast(ink, stock) >= least:
		return ink
	var to := Color.WHITE if contrast(Color.WHITE, stock) > contrast(Color.BLACK, stock) else Color.BLACK
	for i in range(1, 11):
		var c := ink.lerp(to, float(i) / 10.0)
		if contrast(c, stock) >= least:
			return c
	return to


static var _fonts := {}
## ...guarded: the set dresser's table is built on a worker thread while the show may build its own
static var _fonts_lock := Mutex.new()

## The [Font] for a face key (or a font path), loaded once. A variable face is set at the
## weight the registry names.
static func font(key: String) -> Font:
	_fonts_lock.lock()
	var known: Font = _fonts.get(key)
	_fonts_lock.unlock()
	if known != null:
		return known
	var entry: Dictionary = FACES.get(key, {})
	var path := String(entry.get("file", key))
	var f: Font = null
	# Imported fonts live in the PCK as resources. load_dynamic_font() reads the raw
	# .ttf from FileAccess, which is absent from a normal Godot export.
	if ResourceLoader.exists(path):
		var imported := ResourceLoader.load(path)
		if imported is Font:
			f = imported
	if f == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			f = ff
	if f != null and entry.has("weight"):
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {"wght": int(entry["weight"])}
		f = fv
	if f == null:
		f = ThemeDB.fallback_font
	_fonts_lock.lock()
	_fonts[key] = f
	_fonts_lock.unlock()
	return f

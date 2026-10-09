extends RefCounted
class_name Props

## Props - things BUILT FROM A DESCRIPTION. A thing is a few PARTS, each one SHAPE with real sizes
## and one MATERIAL whose surface is procedural, with an ORNAMENT worked into it if it has one - or a
## GROUP of parts, placed and repeated as one (a candelabra's arm, cup and taper, copied round). An
## agent writes the description - centimeters, the thing's base on y = 0, its front toward +z - and
## [method sanitize] makes whatever it wrote buildable; [method build] makes the meshes, in meters.
##
## SHAPES, MATERIALS, PLAYS and ORNAMENTS are registries, and their words are what an agent reads
## when it chooses ([method describe]), so the prompt and the builder cannot disagree about what
## exists.
## Geometry is built here rather than from CSG nodes because a part's lobes, twist and wax drips
## displace it as it is built, which a spun polygon cannot do.
##
## FREE FORM, NOT FREE TRIANGLES. An agent draws its own curves - a lathe's profile, a tube's or a
## loft's path, an extrude's or a section's outline, any point of them rounded or kept crisp - and
## any part can be WARPED whole (bent, twisted, tapered, leaned, scaled, wobbled). It never writes
## vertices: typed out by hand they come back inside out, holed and unshaded, and skip the foot and
## the heaps that every built shape feeds. A smooth curve keeps a flat base and top flat ([method
## _lathe]); a set dresser's teapot drawn through every point came out a ball.

## The most parts a thing has (every part in every group counted), points a profile or path has,
## copies a part makes, groups deep a part may sit, parts a thing makes in all (every copy of every
## part), and wicks one wax part has.
const MAX_PARTS := 16
const MAX_POINTS := 40
const MAX_COPIES := 24
const MAX_DEPTH := 3
const MAX_INSTANCES := 96
const MAX_WICKS := 6
## The most cross-sections a loft has.
const MAX_SECTIONS := 12
## How far apart a warped part's points may be, meters: a warp moves the points a shape has, and a
## candle's wall drawn top and bottom only stayed straight however far it was bent.
const WARP_STEP := 0.005
## The largest anything may be, centimeters: a thing past it is scaled down whole.
const MAX_SIZE := 60.0
## How high above the cloth a thing's FOOT is measured (meters): what a card sliding across the
## cloth would run into. A chalice's bowl is above it; its foot and stem are not.
const FOOT_H := 0.02
## A crystal this clear or clearer is drawn as glass.
const CLEAR := 0.8

## THE SHAPES a part can be, and what they are for.
const SHAPES := {
	"lathe": "a solid turned about the vertical axis, as on a lathe: vessels, candles, candlesticks, cups, bowls, bottles, vases, stems, bells, finials, coins. `profile`: [radius, height] points from the middle of the bottom outward and up the outside; a HOLLOW thing goes on over its rim and back down the inside to the middle of its inner floor - a bowl is [[0,0],[3,0],[6,4],[6.4,4.2],[5.8,4],[2.8,0.6],[0,0.6]]. Optional: `smooth` true curves through the points instead of joining them straight (a flat base and a flat top stay flat); a point written [radius, height, r] has its corner rounded r centimeters, and [radius, height, 0] keeps a crisp corner in a smooth profile - a foot, a rim, the edge where a lid sits; `sides` 3-12 cuts it flat-sided (6 is hexagonal); `lobes` bulges round it (a scalloped bowl, a melon, a fluted column) with `lobe_depth` 0.05-0.4; `twist` in degrees from bottom to top (a twisted taper). A candle's wax has `wick` true - its flame is lit at the middle of its top, which is melted into a shallow pool - or `wicks` 2-6, set round the top (three make a triangle), or `wicks` [[x, z], ...] placing each, centimeters from the middle; and `drips` 0-1.",
	"box": "a block with rounded edges: books, boxes, tins, slabs, trays, a plinth. `size` [width, height, depth]; `round` the edges' radius; `taper` 0-0.9 narrows it toward the top.",
	"ball": "a sphere, stretched to `size` [width, height, depth]: crystal balls, beads, fruit, eggs, orbs, pebbles, tumbled stones. `lumpy` 0-1 makes it irregular like a tumbled stone or a fruit; `facets` true cuts it into flat faces like a rough, raw stone.",
	"point": "one crystal: a prism with a pointed end, standing up from its base - a tower, a single point. `radius`, `length` (the prism), `tip` (the point), `sides` (6 for quartz).",
	"cluster": "a crystal cluster: points growing out of one rough rock. `count` 3-24, `radius` (the rock), `length` [shortest, longest], `spread` (degrees the outer points lean out), `thickness` (a point's width over its length, 0.1-0.3), `base` (the rock's material, if not the crystal's).",
	"geode": "a geode broken open: a rough round rock, hollow, the hollow lined with crystal points growing in toward its middle. It lies open side up; `turn` [30, 0, 0] tips the opening toward the reader. `radius` (the rock's), `rind` (the thickness of its shell), `length` (the crystals'), `base` (the rock's material; plain gray rock if not given). The part's own material is the crystals'.",
	"ring": "a ring lying flat round the vertical axis, resting on whatever is under it: rims, rings, bangles, a coiled rope. `radius` (to the middle of the band), `thickness` (the band's), `arc` (degrees, less than 360 for an open ring).",
	"tube": "a round rod along a path: handles, stems, incense sticks, wands, branches, wire, a feather's quill, a pipe. `path` [[x,y,z], ...] in the thing's own space, `radius` (or `radii`, one per point, to taper or swell it). It curves through its points (`smooth` false: joined straight, every bend a crisp elbow, like a bent wire); a point written [x, y, z, r] bends round r centimeters there (a pipe's elbow), and [x, y, z, 0] is a crisp kink in a smooth path. `wall` (centimeters) makes it hollow and open at both ends: a pipe, a straw, a spout.",
	"loft": "a form swept along a path through CROSS-SECTIONS that change as it goes - what a lathe, a tube or an extrude cannot make: a spout wide at the body and narrow at its lip, a blade of a snake plant or an aloe, a cactus pad, a horn, a spoon's handle, a shell's whorl, a curling leaf with real thickness. `path` [[x,y,z], ...] as a tube's (with its corners), or none: it rises straight up `height`. `sections` [{`at` 0-1 along the path, `outline` (as an extrude's, or `points` [[x, z], ...]), `size` [width, thickness] or one number, `sides`, `scale`, `turn` (degrees about the path), `shift` [x, z]}, ...]: the form blends smoothly from each section to the next (`smooth` false: straight); a section of `size` 0 closes to a point. Width runs across the path and thickness the other way - the thing's x and z while the path runs up. An outline, size or sides written on the part itself is every section's unless it says otherwise. `wall` makes it hollow and open at both ends.",
	"coil": "a band wound round the vertical axis: an incense coil, a spring, a coiled cord, a curling tendril, a spiral of wire. `turns`, `radius` (where it starts) and `radius2` (where it ends: larger for a flat spiral), `height` (how far it climbs over all its turns; 0 lies flat), `thickness` (the band's, as a ring's).",
	"sheet": "a thin flat piece lying on the cloth unless turned, placed by its middle: a leaf, a petal, a feather, a page, a scrap of cloth. `outline` (leaf, petal, feather, oval or rect - or `points` [[x,z], ...] for any outline), `size` [width, length] (its length runs front to back), `bend` -1..1 (the tip curls up), `fold` 0-1 (the sides lift).",
	"bloom": "a flower head, petals in rings round a small middle: `petals`, `layers` 1-4, `radius`, `cup` 0 (open flat) to 1 (a closed bud), `width` (a petal's width over its length).",
	"strand": "something long and limp laid down: a rope, a cord, a wire, a vine, a string of beads, a chain. `kind` (rope, cord, wire, vine, beads or chain), `length` (centimeters along it), `thickness` (how wide it is), and how it lies, `lay`: \"coil\" (coiled down, loop piled on loop, as a rope is - `radius` the loops'), \"flemish\" (wound flat in a spiral from the middle out), \"heap\" (dropped in a loose tangle, crossing over itself - within `radius`), \"path\" (laid along `path` [[x, z], ...], centimeters from the thing's middle, its length the path's) or \"drape\" (laid across the table itself and over its edge - DRAPED, below). `loose` 0-1: how unkempt it lies, 0 laid neatly, 1 thrown down. A vine carries leaves - `leaf` their length (centimeters) and `leaves` their material, if not the stem's. It rests on the cloth, and on itself wherever it crosses itself.",
	"bone": "a bone, lying on its side along x: `kind` \"femur\" (a thigh bone: a ball on a neck at one end, two knuckles at the other), \"long\" (an arm or leg bone, knobbed at both ends), \"rib\" (a curved, flattened bar), \"small\" (a chicken's or a small animal's - thin, knobbed, a little bent: copy it in a `heap` for a pile of them) or \"wishbone\"; `length` and `thickness` (the shaft's, centimeters). Its material is most often `bone`.",
	"skull": "a skull, resting on its jaw and facing the thing's front: `kind` \"human\", \"horned\" (a cow's, a goat's or a ram's, long-snouted, with `horns` \"straight\", \"curved\" or \"curled\", or \"none\") or \"bird\" (a long beak); `length` (centimeters, front to back - a person's is about 19). Its sockets are deep and its openings go through. It is bone, not a head: no eyes, no skin, nothing living.",
	"sculpt": "a form modeled freely, as clay is, from STROKES - for what no other shape makes: the skull or the jaw of a creature not listed, a shell, an antler, a gnarled root, a seed pod, a mushroom, a stone worn into a shape, a carved charm. `strokes` [{`points` [[x, y, z, r], ...]}, ...] in order: each stroke a rod through its points (curving through them; `smooth` false joins them straight), r its thickness there (a radius, centimeters), so it swells and narrows as it goes; one point is a ball, stretched to `size` [width, height, depth] if given. Each stroke melts into what came before it, `blend` centimeters soft (0 a crisp seam); `carve` true cuts it out of what came before instead - a socket, a groove, a hollow, a hole right through, the gap under an arch. `mirror` true makes it the same on both sides of x = 0: draw only its middle and its right side. It is one surface, its hollows shut in from the light; a rod much thinner than a hundredth of the whole comes out broken. Draw it blind and you will not get it right first: look at it from every side, and put it again.",
	"extrude": "an outline raised straight up: trays, tiles, plaques, tablets, boxes, dishes and candles of any plan - a star, a hexagon, a heart. `outline` (polygon with `sides` 3-12, star with `sides` points, circle, rect, heart, lens (pointed at both ends, as a leaf or an eye is) or drop (round behind, pointed in front) - or `points` [[x, z], ...] for any outline, which may go in and out), `size` [width, depth], `height`; optional `taper` 0-0.9 (narrower at the top), `bevel` (centimeters cut off the top edge), `wall` (centimeters: hollow, as a tray or a dish is, its floor as thick as its wall). A wax extrude takes `wick` or `wicks` as a turned candle does.",
}

## THE STRANDS: what a strand can be, and the width it is when none is given (centimeters).
const STRANDS := {"rope": {"thickness": 1.2}, "cord": {"thickness": 0.5}, "wire": {"thickness": 0.15},
	"vine": {"thickness": 0.45}, "beads": {"thickness": 0.8}, "chain": {"thickness": 0.7}}
## How a strand lies ([method _strand_line]).
const LAYS := ["coil", "flemish", "heap", "path", "drape"]
## The longest a strand is (centimeters), how far from the middle of the reading a draped one's path may
## run (centimeters - past the edge of the largest top), and the most points it is cut into.
const MAX_STRAND := 600.0
const DRAPE_REACH := 220.0
const STRAND_SAMPLES := 1400
## THE BONES: each kind's length and shaft thickness when none is given (centimeters).
const BONES := {"femur": Vector2(44.0, 2.6), "long": Vector2(30.0, 2.0), "rib": Vector2(24.0, 1.2),
	"small": Vector2(9.0, 0.6), "wishbone": Vector2(6.0, 0.35)}
## THE SKULLS: each kind's length front to back when none is given (centimeters).
const SKULLS := {"human": 19.0, "horned": 40.0, "bird": 8.0}
## THE SKULLS AS SCULPTS ([method _skull]), their right halves (mirrored), centimeters, facing +z - each
## sized to its length when built. Drawn by hand from the bone: a crow's (a braincase, orbits open to the side
## and through a thin wall between them, a beak with its nostrils through, the bars under the eyes, a jaw of
## two thin branches), a person's (a vault, brow, cheekbones and the arches behind them standing free, sockets,
## the nose's opening, the teeth, and the jaw) and a cow's or a goat's as it is found - no jaw - long-faced,
## its sockets at the sides in raised rims.
const SKULL_FORMS := {
	"bird": [
		{"points": [[0, 2.0, -1.9]], "size": [3.0, 2.6, 3.1]},
		{"points": [[0, 2.2, -0.3]], "size": [2.7, 2.0, 2.9], "blend": 1.0},
		{"points": [[0, 2.05, 1.0, 0.72], [0, 1.8, 2.4, 0.52], [0, 1.45, 4.0, 0.32], [0, 1.12, 5.6, 0.12], [0, 0.98, 6.35, 0.03]], "blend": 0.5},
		{"points": [[1.1, 1.95, 0.1]], "size": [2.0, 1.9, 2.1], "carve": true, "blend": 0.15},
		{"points": [[0, 1.9, 0.3]], "size": [0.6, 0.9, 1.1], "carve": true, "blend": 0.05},
		{"points": [[0, 1.95, 2.0]], "size": [2.0, 0.32, 0.75], "carve": true, "blend": 0.05},
		{"points": [[0, 1.05, -3.0]], "size": [0.6, 0.6, 0.8], "carve": true, "blend": 0.1},
		{"points": [[1.35, 1.6, -1.25]], "size": [0.4, 0.5, 0.4], "carve": true, "blend": 0.05},
		{"points": [[0.55, 1.25, 1.6, 0.09], [0.95, 1.05, 0.2, 0.08], [1.12, 1.05, -1.25, 0.11]], "blend": 0.12},
		{"points": [[0.25, 1.35, 1.4, 0.08], [0.35, 1.25, -0.3, 0.09], [0.3, 1.35, -1.2, 0.12]], "blend": 0.12},
		{"points": [[1.1, 1.0, -1.35]], "size": [0.4, 0.5, 0.4], "blend": 0.12},
		{"points": [[0.04, 0.9, 6.0, 0.06], [0.28, 0.92, 4.2, 0.13], [0.62, 0.95, 2.2, 0.15], [0.98, 0.95, 0.2, 0.14], [1.15, 1.0, -1.35, 0.15]], "blend": 0.1},
	],
	"human": [
		{"points": [[0, 12.4, -1.8]], "size": [14.0, 13.2, 18.0]},
		{"points": [[0, 11.5, 4.5]], "size": [11.5, 8.5, 8.0], "blend": 2.0},
		{"points": [[0, 10.6, 8.1, 0.9], [2.6, 10.9, 7.9, 0.85], [4.6, 10.4, 7.0, 0.8]], "blend": 0.8},
		{"points": [[0, 6.6, 6.0]], "size": [9.6, 6.6, 6.2], "blend": 1.5},
		{"points": [[4.6, 7.3, 6.0]], "size": [2.6, 2.8, 3.0], "blend": 1.0},
		{"points": [[5.6, 7.2, -2.2, 0.9], [5.4, 5.6, -2.0, 0.6]], "blend": 0.8},
		{"points": [[6.4, 9.0, 3.2]], "size": [3.0, 4.0, 3.5], "carve": true, "blend": 1.0},
		{"points": [[4.9, 7.4, 5.5, 0.6], [6.2, 7.6, 2.8, 0.45], [6.5, 7.9, 0.2, 0.45]], "blend": 0.4},
		{"points": [[3.3, 8.7, 9.6, 1.95], [3.1, 8.6, 7.6, 1.75], [2.6, 8.4, 4.6, 0.9]], "carve": true, "blend": 0.4},
		{"points": [[0, 6.9, 9.8, 0.8], [0, 6.7, 7.0, 0.8], [0, 6.6, 3.5, 0.6]], "carve": true, "blend": 0.3},
		{"points": [[0, 5.9, 9.8, 1.25], [0, 5.9, 7.0, 1.15], [0, 6.0, 3.5, 0.8]], "carve": true, "blend": 0.3},
		{"points": [[6.6, 8.3, -0.9]], "size": [1.6, 0.9, 0.9], "carve": true, "blend": 0.2},
		{"points": [[0, 4.0, 7.6, 0.9], [2.2, 4.1, 6.6, 0.9], [2.8, 4.3, 4.0, 0.9]], "blend": 0.8},
		{"points": [[0.45, 3.2, 8.1]], "size": [0.8, 1.1, 0.55], "blend": 0.1},
		{"points": [[1.25, 3.25, 7.8]], "size": [0.75, 1.0, 0.55], "blend": 0.1},
		{"points": [[1.9, 3.2, 7.3]], "size": [0.75, 1.15, 0.7], "blend": 0.1},
		{"points": [[2.3, 3.3, 6.6]], "size": [0.75, 0.9, 0.75], "blend": 0.1},
		{"points": [[2.55, 3.35, 5.9]], "size": [0.75, 0.9, 0.75], "blend": 0.1},
		{"points": [[2.75, 3.4, 5.1]], "size": [0.95, 0.85, 0.95], "blend": 0.1},
		{"points": [[2.9, 3.45, 4.2]], "size": [0.95, 0.85, 0.95], "blend": 0.1},
		{"points": [[0, 1.0, 7.6, 1.0], [2.4, 1.0, 6.6, 0.9], [4.4, 1.4, 3.8, 0.8], [5.0, 1.6, 1.2, 0.85]], "blend": 0.6},
		{"points": [[0, 0.9, 7.7]], "size": [3.0, 1.8, 1.6], "blend": 0.6},
		{"points": [[5.0, 1.6, 1.2, 0.75], [5.3, 4.5, 0.6, 0.6], [5.6, 7.0, -0.3, 0.5]], "blend": 0.5},
		{"points": [[5.6, 7.4, -0.4]], "size": [1.8, 0.9, 1.0], "blend": 0.3},
		{"points": [[5.1, 4.4, 1.3, 0.45], [5.0, 6.4, 2.4, 0.3]], "blend": 0.4},
		{"points": [[0, 2.0, 7.5, 0.75], [2.3, 2.1, 6.4, 0.75], [2.8, 2.2, 4.0, 0.75]], "blend": 0.5},
		{"points": [[0.4, 2.65, 7.85]], "size": [0.7, 0.95, 0.5], "blend": 0.1},
		{"points": [[1.15, 2.65, 7.6]], "size": [0.7, 0.95, 0.5], "blend": 0.1},
		{"points": [[1.8, 2.7, 7.1]], "size": [0.7, 1.0, 0.65], "blend": 0.1},
		{"points": [[2.2, 2.75, 6.4]], "size": [0.7, 0.85, 0.7], "blend": 0.1},
		{"points": [[2.45, 2.75, 5.7]], "size": [0.7, 0.85, 0.7], "blend": 0.1},
		{"points": [[2.65, 2.8, 4.9]], "size": [0.9, 0.8, 0.95], "blend": 0.1},
		{"points": [[2.8, 2.85, 4.0]], "size": [0.9, 0.8, 0.95], "blend": 0.1},
	],
	"horned": [
		{"points": [[0, 9.5, -6.0]], "size": [12.0, 10.0, 9.0]},
		{"points": [[0, 12.0, -2.0]], "size": [17.0, 6.0, 16.0], "blend": 2.0},
		{"points": [[0, 14.3, -8.6, 2.2], [7.6, 14.0, -8.6, 2.7]], "blend": 2.0},
		{"points": [[2.8, 10.5, 2.0, 3.6], [2.6, 9.2, 12.0, 2.8], [2.0, 7.6, 20.0, 2.2], [1.3, 6.2, 27.0, 1.4]], "blend": 2.5},
		{"points": [[0, 9.0, 2.0, 3.6], [0, 7.8, 12.0, 2.8], [0, 6.4, 20.0, 2.1], [0, 5.4, 27.5, 1.3]], "blend": 2.0},
		{"points": [[5.0, 8.0, 4.0, 1.0], [4.2, 6.6, 12.0, 0.8]], "blend": 1.5},
		{"points": [[7.5, 9.5, -3.0]], "size": [3.0, 4.0, 4.0], "carve": true, "blend": 1.0},
		{"points": [[6.8, 10.8, 1.5]], "size": [3.2, 4.6, 4.6], "blend": 1.2},
		{"points": [[7.6, 10.8, 1.7]], "size": [2.6, 3.6, 3.6], "carve": true, "blend": 0.3},
		{"points": [[3.4, 4.6, 4.0, 1.0], [3.2, 4.8, 14.0, 0.9]], "blend": 1.0},
		{"points": [[0, 7.0, 30.0, 1.8], [0, 7.2, 22.0, 1.3]], "carve": true, "blend": 0.4},
		{"points": [[2.0, 6.5, -10.5]], "size": [2.2, 2.8, 2.2], "blend": 0.5},
		{"points": [[0, 7.5, -11.5]], "size": [2.6, 2.6, 3.0], "carve": true, "blend": 0.3},
	],
}
## A SCULPT's limits: its strokes, the points in all of them, the cells across its longest side (at least, and
## at most - [method _cut_of]), the short pieces a smooth rod is cut into between two of its points, a grid
## block's cells a side ([method _grid]), and how many built sculpts a process keeps ([method _sculpt]).
const MAX_STROKES := 48
const MAX_SCULPT_POINTS := 320
const SCULPT_CELLS := Vector2(72.0, 144.0)
const SCULPT_STEPS := 4
const SCULPT_BLOCK := 6
const SCULPT_PIECE := 2
## How much further than a block's (or a piece's) reach its middle may be from the surface before it is
## skipped: a tapered rod's field overstates its distance a little.
const SCULPT_SLACK := 1.15
const SCULPT_KEPT := 24
const _CORNERS := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1),
	Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
const _CUBE_EDGES := [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7]
static var _sculpted := {}
## ...guarded: the set dresser's table is built on a worker thread while the show may build its own
static var _sculpted_lock := Mutex.new()

## AN EXTRUDE's (and a loft section's) named outlines.
const EXTRUDE_OUTLINES := ["polygon", "star", "circle", "rect", "heart", "lens", "drop"]

## A WARP's numbers and their ranges (`scale` and `lean` are vectors, made safe on their own).
const WARPS := {"taper": Vector2(-1.0, 0.95), "twist": Vector2(-1080.0, 1080.0), "bend": Vector2(-270.0, 270.0),
	"bend_to": Vector2(-360.0, 360.0), "wobble": Vector2(0.0, 1.0)}

## THE MATERIALS, each with its shader `code` and its defaults. `polish` is how smooth it is,
## `wear` how used, `pattern` how strong its natural pattern, `clarity` how far light goes into
## it, `grain` the pattern's size in centimeters.
const MATERIALS := {
	"metal": {"code": 1, "polish": 0.62, "wear": 0.2, "pattern": 0.0, "clarity": 0.5, "grain": 1.5,
		"about": "brass, copper, bronze, silver, iron, pewter, gold; `wear` is tarnish or patina in `color2`, `pattern` a hammered surface"},
	"wax": {"code": 2, "polish": 0.2, "wear": 0.0, "pattern": 0.0, "clarity": 0.5, "grain": 2.0,
		"about": "candle wax - beeswax, paraffin, tallow; `clarity` how much the light glows through it"},
	"glass": {"code": 3, "polish": 0.92, "wear": 0.0, "pattern": 0.0, "clarity": 0.85, "grain": 2.0,
		"about": "see-through; `color` tints it, a low `clarity` frosts it, an ornament on glass is etched"},
	"crystal": {"code": 4, "polish": 0.85, "wear": 0.0, "pattern": 0.2, "clarity": 0.5, "grain": 1.2,
		"about": "quartz, amethyst, citrine, obsidian, selenite, any mineral; `clarity` from milky 0 to water-clear 1, `pattern` banding in `color2` - curving round in rings with `rings` true (agate, malachite, onyx)"},
	"ceramic": {"code": 5, "polish": 0.6, "wear": 0.0, "pattern": 0.15, "clarity": 0.5, "grain": 1.0,
		"about": "glazed or bare clay - porcelain, stoneware, terracotta, faience; `polish` is the glaze, `pattern` speckle, `wear` crazing, `color2` where the glaze pools"},
	"stone": {"code": 6, "polish": 0.3, "wear": 0.1, "pattern": 0.4, "clarity": 0.5, "grain": 2.5,
		"about": "marble, slate, granite, soapstone, alabaster, jasper; `pattern` veins in `color2` - curving round in rings with `rings` true (banded jasper) - and `wear` flecks"},
	"wood": {"code": 7, "polish": 0.4, "wear": 0.0, "pattern": 0.55, "clarity": 0.5, "grain": 1.2,
		"about": "any timber, carved or turned; `pattern` its grain in `color2`, `polish` oil or varnish"},
	"paper": {"code": 8, "polish": 0.05, "wear": 0.2, "pattern": 0.0, "clarity": 0.5, "grain": 3.0,
		"about": "paper, card, parchment; `wear` stains in `color2`"},
	"leather": {"code": 9, "polish": 0.35, "wear": 0.3, "pattern": 0.0, "clarity": 0.5, "grain": 0.8,
		"about": "hide and leather bindings; `wear` scuffs in `color2`"},
	"fabric": {"code": 10, "polish": 0.3, "wear": 0.0, "pattern": 0.0, "clarity": 0.5, "grain": 2.0,
		"about": "cloth, velvet, silk, cord; `polish` is a velvet's sheen"},
	"bone": {"code": 11, "polish": 0.4, "wear": 0.4, "pattern": 0.0, "clarity": 0.5, "grain": 2.0,
		"about": "bone, ivory, horn, shell; `wear` yellows it toward `color2`"},
	"plant": {"code": 12, "polish": 0.2, "wear": 0.0, "pattern": 0.5, "clarity": 0.5, "grain": 1.0,
		"about": "leaves, petals, stems, herbs; `wear` dries them toward `color2`"},
	"painted": {"code": 0, "polish": 0.5, "wear": 0.0, "pattern": 0.0, "clarity": 0.5, "grain": 1.0,
		"about": "lacquer, enamel or paint over anything"},
}

## THE ORNAMENTS a part's surface can carry, with their shader codes.
const ORNAMENTS := {
	"bands": {"code": 1, "about": "raised rings round it, `count` of them"},
	"flutes": {"code": 2, "about": "grooves running up it, `count` round"},
	"dots": {"code": 3, "about": "a field of dots, `count` round"},
	"stars": {"code": 4, "about": "five-pointed stars, `count` round"},
	"moons": {"code": 5, "about": "crescent moons, `count` round"},
	"zigzag": {"code": 6, "about": "one zigzag band, `count` peaks round"},
	"scales": {"code": 7, "about": "overlapping scales, `count` round"},
	"spiral": {"code": 8, "about": "lines winding up it, `count` of them"},
	"lattice": {"code": 9, "about": "a diamond lattice, `count` diamonds round"},
	"hammered": {"code": 10, "about": "the dimpled face of hand-hammered metal, all over"},
}

## THE PLAY OF LIGHT a material can have - what moves in a stone, a shell or a metal as it turns,
## or as the flames catch it - with its shader code. Clear glass and crystal show only a rainbow.
const PLAYS := {
	"silk": {"code": 1, "about": "a silky band of light lying across its fibers, sliding over it as it turns; `pattern` stripes it in `color2` - tiger's eye, hawk's eye, satin spar selenite"},
	"flash": {"code": 2, "about": "broad patches that flash `color2` and the colors beside it where they catch the light, dark elsewhere - labradorite, spectrolite"},
	"fire": {"code": 3, "about": "small patches of every color, changing as it turns - opal"},
	"glitter": {"code": 4, "about": "tiny flakes of `color2` that sparkle in the flames - goldstone, sunstone, aventurine, the pyrite in lapis"},
	"rainbow": {"code": 5, "about": "an oily rainbow film over the surface - aura quartz, rainbow obsidian, bismuth, paua, abalone, mother of pearl"},
	"glow": {"code": 6, "about": "a soft light of `color2` floating under the surface - moonstone"},
}

## A sheet's outlines: its half-width along its length, 0 at the base to 1 at the tip.
const OUTLINES := ["leaf", "petal", "feather", "oval", "rect"]

const _SHADER := preload("res://shaders/prop.gdshader")
const _GLASS := preload("res://shaders/prop_glass.gdshader")
const _LENS := preload("res://shaders/prop_lens.gdshader")


## A THING DRAPED ACROSS THE TABLE: one whose strand is laid `drape` - built in the table's own space and
## standing nowhere else.
static func draped(thing: Dictionary) -> bool:
	for p in thing.get("parts", []):
		if p is Dictionary and String((p as Dictionary).get("shape", "")) == "strand" and String((p as Dictionary).get("lay", "")) == "drape":
			return true
	return false


## THE VOCABULARY, as an agent reads it: every shape, material and ornament with its words.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("SHAPES (a part's `shape`):")
	for k in SHAPES:
		lines.append("- %s: %s" % [k, SHAPES[k]])
	lines.append("")
	lines.append("MATERIALS: name each one used under `materials`, then give a part its name. A material is {\"kind\", \"color\", \"color2\", \"polish\", \"wear\", \"pattern\", \"clarity\", \"grain\", \"play\", \"rings\"} - all but kind and color optional, numbers 0-1 except grain (centimeters). Kinds:")
	for k in MATERIALS:
		lines.append("- %s: %s" % [k, String((MATERIALS[k] as Dictionary)["about"])])
	lines.append("")
	lines.append("PLAY OF LIGHT: a material's `play` is the light that moves in it, most often a stone's, a shell's or a metal's (clear glass and crystal show only rainbow):")
	for k in PLAYS:
		lines.append("- %s: %s" % [k, String((PLAYS[k] as Dictionary)["about"])])
	lines.append("")
	lines.append("ORNAMENT: a part's surface can carry one: {\"kind\", \"count\", \"depth\" 0-1 (relief), \"color\" (paint or inlay; leave it out for relief alone), \"from\" and \"to\" (the band of the part's height it covers, 0 the bottom, 1 the top)}. Kinds:")
	for k in ORNAMENTS:
		lines.append("- %s: %s" % [k, String((ORNAMENTS[k] as Dictionary)["about"])])
	lines.append("")
	lines.append("COPIES: a part's `copies` repeats it - \"copies\": {\"ring\": {\"count\": 5, \"radius\": 4}} round the vertical axis (`arc` less than 360 makes it an arc, from `start` degrees: 0 the thing's right, 90 its front, 270 its back), {\"line\": {\"count\": 3, \"step\": [x, y, z]}}, {\"scatter\": {\"count\": 9, \"radius\": 6}} strewn about, never touching (stones set out on the cloth), or {\"heap\": {\"count\": 12, \"radius\": 3}} piled up, each resting on the ones under it (stones heaped in a dish or a shell, a pile of coins) - with `jitter` 0-1 so the copies differ a little. A copied part's `material` can be a LIST of names, which its copies take in turn: a handful of stones of five kinds, books in three bindings. A copied candle's wax lights a flame on every copy.")
	lines.append("")
	lines.append("GROUPS: a part can be a GROUP instead of a shape - {\"parts\": [...], \"at\", \"turn\", \"copies\"} - whose own parts are placed in its space as a thing's are in the thing's; repeat the group and all of it repeats. A candelabra's arm, its cup and its taper are one group copied round in a ring; a group can hold groups, %d deep. A list of materials on a part inside a copied group goes to the group's copies in turn. Every part in every group counts toward the %d a thing may have." % [MAX_DEPTH, MAX_PARTS])
	lines.append("")
	lines.append("WARP: any part, whatever its shape, can be reshaped whole by its `warp` - {\"scale\" [x, y, z] (stretched or squashed: an oval dish is a turned bowl with scale [1, 1, 0.7]), \"taper\" -1 to 0.95 (narrower toward its top; below 0, wider), \"twist\" (degrees it turns about its upright middle from bottom to top), \"lean\" [x, z] (its top moved that many centimeters, its base kept), \"bend\" (degrees: it bows along its height until its top has turned that far, toward \"bend_to\" - 0 its right, 90 its front, 180 its left, 270 its back), \"wobble\" 0-1 (the unevenness of a thing made by hand - a hand-thrown pot, a gnarled root, a misshapen fruit; 0.1-0.3 is plenty)}, applied in that order. A bend is a banana's curve, a candle slumped in the heat, a horn's sweep; a whole bent rod with kinks in it is a tube's path.")
	lines.append("")
	lines.append("WHERE PARTS MEET: a spout, a handle, an arm, a stem or a branch grows OUT of what it joins - start it a little inside that part, so no gap or seam of light shows. A thing is a few parts that join well, not many small ones floating side by side. A vessel's profile carries its character - foot, belly, shoulder, neck, lip - and most stand on a flat base. A spout leaves the body wide and low and narrows as it rises to a lip about level with the rim; a handle is a rod bent round, both ends sunk into the body; a lid is its own part, sitting in or on the rim, with a knob.")
	lines.append("")
	lines.append("DRAPED: a strand laid `drape` is laid across the TABLE ITSELF, not in a thing's own space: its `path` is in the table's centimeters, from the middle of the reading (as a layer's `at`), x to the reader's right and z toward the reader. Where the path runs past the top's edge the strand rolls over the edge and hangs straight down as far as it ran past - a path ending 30 cm past the right edge hangs 30 cm down the side, to the floor at most. It is its thing's only part, its thing's `place` is not used, and it keeps clear of the middle of the cloth, where the deck and the cards go: along the back, round a corner, across one side and over an edge. The camera sees the far edge and a little of the sides; what hangs over the near edge is under the lens.")
	lines.append("")
	lines.append("FLAMES: a thing's flames burn as ONE light, however many it has - a candelabra's tapers, a pillar's three wicks, a dish of tea lights - up to %d on one thing." % CardTable.MAX_FLAMES)
	return "\n".join(lines)


# --- sanitizing -----------------------------------------------------------------------------

## WHATEVER AN AGENT WROTE, as something [method build] can make: every part a known shape with its
## numbers in range, every material named and known, colors colors. A part with no shape the
## builder knows is dropped, and a thing with no part left is dropped. Keys this file does not own
## (where a thing stands, say) are passed through for the caller to judge. [param palette] gives
## the colors an agent left out.
static func sanitize(spec: Dictionary, palette: Array) -> Dictionary:
	var pal: Array = palette if not palette.is_empty() else ["#8a6a3a", "#c9b38a", "#3a3030"]
	var mats := {}
	var raw: Dictionary = spec.get("materials", {}) if spec.get("materials") is Dictionary else {}
	var i := 0
	for k in raw:
		mats[String(k).strip_edges()] = sanitize_material(raw[k], String(pal[i % pal.size()]))
		i += 1
	var things: Array = []
	for t in (spec.get("things", []) if spec.get("things") is Array else []):
		if not (t is Dictionary):
			continue
		var thing := _sanitize_thing(t as Dictionary, mats, pal)
		if not (thing["parts"] as Array).is_empty():
			things.append(thing)
	return {"idea": _text(spec.get("idea", ""), 600), "things": things, "materials": mats}


static func sanitize_material(m: Variant, fallback: String) -> Dictionary:
	var d: Dictionary = m if m is Dictionary else {}
	var kind := String(d.get("kind", "")).strip_edges().to_lower()
	if not MATERIALS.has(kind):
		kind = "painted"
	var base: Dictionary = MATERIALS[kind]
	var c := _color(d.get("color", ""), fallback)
	var out := {"kind": kind, "color": c,
		"color2": _color(d.get("color2", ""), "#" + Color.html(c).darkened(0.45).to_html(false)),
		"grain": _num(d.get("grain"), float(base["grain"]), 0.2, 20.0), "rings": _flag(d.get("rings"))}
	for k in ["polish", "wear", "pattern", "clarity"]:
		out[k] = _num(d.get(k), float(base[k]), 0.0, 1.0)
	var play := String(d["play"]).strip_edges().to_lower() if d.get("play") is String else ""
	if PLAYS.has(play):
		out["play"] = play
	return out


static func _sanitize_thing(t: Dictionary, mats: Dictionary, pal: Array) -> Dictionary:
	var out := t.duplicate(true)
	out["name"] = _text(t.get("name", "a thing"), 100)
	out["why"] = _text(t.get("why", ""), 200)
	out["parts"] = _sanitize_parts(t.get("parts"), mats, pal, 0, [MAX_PARTS])
	if draped(out):
		# a draped strand is its thing's only part ([method draped])
		out["parts"] = (out["parts"] as Array).filter(func(q: Variant) -> bool:
			return q is Dictionary and String((q as Dictionary).get("lay", "")) == "drape").slice(0, 1)
	return out


## A list of parts made safe, a GROUP's own parts with it ({"parts": [...]} placed, turned and
## repeated as one), [constant MAX_DEPTH] groups deep at most - a group past that is dropped, with
## everything in it. [param budget] is how many shaped parts the thing has left ([constant
## MAX_PARTS] in all), spent as they are kept. A group left with no part is dropped.
static func _sanitize_parts(raw: Variant, mats: Dictionary, pal: Array, depth: int, budget: Array) -> Array:
	var out: Array = []
	for p in (raw if raw is Array else []):
		if int(budget[0]) <= 0:
			break
		if not (p is Dictionary):
			continue
		var d: Dictionary = p
		if d.get("parts") is Array:
			if depth >= MAX_DEPTH:
				continue
			var kids := _sanitize_parts(d["parts"], mats, pal, depth + 1, budget)
			if not kids.is_empty():
				out.append({"parts": kids, "at": _vec3(d.get("at"), Vector3.ZERO, MAX_SIZE), "turn": _turn(d.get("turn")),
					"wick": false, "copies": _copies_of(d)})
			continue
		var part := _sanitize_part(d, mats, pal)
		if not part.is_empty():
			out.append(part)
			budget[0] = int(budget[0]) - 1
	return out


static func _sanitize_part(p: Dictionary, mats: Dictionary, pal: Array) -> Dictionary:
	var shape := String(p.get("shape", "")).strip_edges().to_lower()
	if not SHAPES.has(shape):
		return {}
	var out := {"shape": shape, "at": _vec3(p.get("at"), Vector3.ZERO, MAX_SIZE),
		"turn": _turn(p.get("turn")), "wick": _flag(p.get("wick"))}
	# WICKS: `wick` true is one, at the middle of the top; `wicks` a number set round the top, or
	# each placed [[x, z], ...]
	var wicks := 1 if bool(out["wick"]) else 0
	var spots: Array = []
	if p.get("wicks") is Array:
		spots = _points2(p["wicks"], Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE)).slice(0, MAX_WICKS)
		wicks = spots.size()
	elif p.get("wicks") is float or p.get("wicks") is int:
		wicks = int(_num(p["wicks"], 1.0, 0.0, float(MAX_WICKS)))
	out["wick"] = wicks > 0
	out["wicks"] = wicks
	out["wick_spots"] = spots
	# THE MATERIAL: a name under `materials` or one written inline - or a LIST of them, which the
	# part's copies take in turn
	var names: Array = []
	for m in ((p["material"] as Array).slice(0, MAX_COPIES) if p.get("material") is Array else [p.get("material", "")]):
		names.append(_material_key(m, mats, pal))
	if names.is_empty():
		names.append(_material_key("", mats, pal))
	out["material"] = names[0]
	if names.size() > 1:
		out["materials"] = names
	match shape:
		"lathe":
			var prof := _points2(p.get("profile"), Vector2(0.0, -1.0), Vector2(MAX_SIZE * 0.5, MAX_SIZE))
			if prof.size() < 2:
				return {}
			out["profile"] = prof
			out["rounds"] = _rounds(p.get("profile"), 2)
			out["smooth"] = _flag(p.get("smooth"))
			var sides := int(_num(p.get("sides"), 0.0, 0.0, 16.0))
			out["sides"] = sides if sides >= 3 else 0
			out["lobes"] = int(_num(p.get("lobes"), 0.0, 0.0, 32.0))
			out["lobe_depth"] = _num(p.get("lobe_depth"), 0.15, 0.0, 0.45)
			out["twist"] = _num(p.get("twist"), 0.0, -1080.0, 1080.0)
			out["drips"] = _num(p.get("drips"), 0.0, 0.0, 1.0)
		"box":
			out["size"] = _vec3(p.get("size"), Vector3(6, 3, 4), MAX_SIZE, 0.1)
			var s: Vector3 = out["size"]
			out["round"] = _num(p.get("round"), minf(0.3, minf(s.x, minf(s.y, s.z)) * 0.1), 0.0, minf(s.x, minf(s.y, s.z)) * 0.5)
			out["taper"] = _num(p.get("taper"), 0.0, 0.0, 0.9)
		"ball":
			var r := _num(p.get("radius"), -1.0, 0.1, MAX_SIZE * 0.5)
			out["size"] = _vec3(p.get("size"), Vector3(r, r, r) * 2.0 if r > 0.0 else Vector3(4, 4, 4), MAX_SIZE, 0.1)
			out["lumpy"] = _num(p.get("lumpy"), 0.0, 0.0, 1.0)
			out["facets"] = _flag(p.get("facets"))
		"point":
			out["radius"] = _num(p.get("radius"), 1.0, 0.1, 12.0)
			out["length"] = _num(p.get("length"), 5.0, 0.2, 40.0)
			out["tip"] = _num(p.get("tip"), float(out["radius"]) * 1.4, 0.0, 20.0)
			out["sides"] = int(_num(p.get("sides"), 6.0, 3.0, 12.0))
		"cluster":
			out["count"] = int(_num(p.get("count"), 7.0, 2.0, 24.0))
			out["radius"] = _num(p.get("radius"), 4.0, 0.5, 20.0)
			var ln := _points2([p.get("length")], Vector2(0.3, 0.3), Vector2(30.0, 30.0))
			var lv: Vector2 = ln[0] if not ln.is_empty() else Vector2(2.0, 6.0)
			if p.get("length") is float or p.get("length") is int:
				lv = Vector2(float(p["length"]) * 0.45, float(p["length"]))
			out["length"] = Vector2(minf(lv.x, lv.y), maxf(lv.x, lv.y)).clamp(Vector2(0.3, 0.3), Vector2(30.0, 30.0))
			out["spread"] = _num(p.get("spread"), 35.0, 0.0, 80.0)
			out["thickness"] = _num(p.get("thickness"), 0.17, 0.06, 0.4)
			var b := String(p.get("base", "")).strip_edges()
			out["base"] = b if mats.has(b) else ""
		"geode":
			var r := _num(p.get("radius"), 6.0, 1.0, 25.0)
			out["radius"] = r
			out["rind"] = _num(p.get("rind"), r * 0.18, r * 0.06, r * 0.45)
			var hollow := r - float(out["rind"])
			out["length"] = _num(p.get("length"), hollow * 0.35, 0.2, hollow * 0.55)
			# enough points to line the hollow, each standing in about its own width
			var each := pow(float(out["length"]) * 0.45, 2.0)
			out["count"] = int(_num(p.get("count"), clampf(TAU * hollow * hollow * 0.6 / each, 12.0, 90.0), 6.0, 160.0))
			var b := String(p.get("base", "")).strip_edges()
			if not mats.has(b):
				b = "geode rock"
				if not mats.has(b):
					mats[b] = sanitize_material({"kind": "stone", "color": "#7a7168", "color2": "#b3aa9c", "polish": 0.1,
						"wear": 0.5, "pattern": 0.15}, "#7a7168")
			out["base"] = b
		"extrude":
			var outline := String(p.get("outline", "polygon")).strip_edges().to_lower()
			out["outline"] = outline if EXTRUDE_OUTLINES.has(outline) else "polygon"
			out["points"] = _points2(p.get("points"), Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE))
			var sz := _points2([p.get("size")], Vector2(0.2, 0.2), Vector2(MAX_SIZE, MAX_SIZE))
			out["size"] = sz[0] if not sz.is_empty() else Vector2(6.0, 6.0)
			out["height"] = _num(p.get("height"), 2.0, 0.05, MAX_SIZE)
			out["sides"] = int(_num(p.get("sides"), 6.0, 3.0, 12.0))
			out["taper"] = _num(p.get("taper"), 0.0, 0.0, 0.9)
			out["bevel"] = _num(p.get("bevel"), 0.0, 0.0, 5.0)
			out["wall"] = _num(p.get("wall"), 0.0, 0.0, 10.0)
		"ring":
			out["radius"] = _num(p.get("radius"), 3.0, 0.2, MAX_SIZE * 0.5)
			out["thickness"] = _num(p.get("thickness"), 0.4, 0.05, 10.0)
			out["arc"] = _num(p.get("arc"), 360.0, 10.0, 360.0)
		"tube":
			var path := _points3(p.get("path"), MAX_SIZE)
			if path.size() < 2:
				return {}
			out["path"] = path
			out["rounds"] = _rounds(p.get("path"), 3)
			out["radius"] = _num(p.get("radius"), 0.3, 0.03, 10.0)
			var radii := PackedFloat32Array()
			if p.get("radii") is Array:
				for x in (p["radii"] as Array):
					radii.append(_num(x, float(out["radius"]), 0.0, 10.0))
			out["radii"] = radii
			out["smooth"] = _flag(p.get("smooth"), true)
			out["wall"] = _num(p.get("wall"), 0.0, 0.0, 10.0)
		"loft":
			var path := _points3(p.get("path"), MAX_SIZE)
			out["path"] = path if path.size() >= 2 else []
			out["rounds"] = _rounds(p.get("path"), 3) if path.size() >= 2 else PackedFloat32Array()
			out["height"] = _num(p.get("height"), 10.0, 0.1, MAX_SIZE)
			out["smooth"] = _flag(p.get("smooth"), true)
			out["wall"] = _num(p.get("wall"), 0.0, 0.0, 10.0)
			out["sections"] = _sections(p)
		"coil":
			out["radius"] = _num(p.get("radius"), 2.0, 0.1, MAX_SIZE * 0.5)
			out["radius2"] = _num(p.get("radius2"), float(out["radius"]), 0.0, MAX_SIZE * 0.5)
			out["turns"] = _num(p.get("turns"), 3.0, 0.25, 20.0)
			out["height"] = _num(p.get("height"), 0.0, 0.0, MAX_SIZE)
			out["thickness"] = _num(p.get("thickness"), 0.3, 0.03, 5.0)
		"sheet":
			var outline := String(p.get("outline", "leaf")).strip_edges().to_lower()
			out["outline"] = outline if OUTLINES.has(outline) else "leaf"
			out["points"] = _points2(p.get("points"), Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE))
			var sz := _points2([p.get("size")], Vector2(0.2, 0.2), Vector2(40.0, 40.0))
			out["size"] = sz[0] if not sz.is_empty() else Vector2(3.0, 6.0)
			out["bend"] = _num(p.get("bend"), 0.0, -1.0, 1.0)
			out["fold"] = _num(p.get("fold"), 0.0, 0.0, 1.0)
			out["thickness"] = _num(p.get("thickness"), 0.08, 0.02, 1.0)
		"strand":
			var kind := String(p.get("kind", "")).strip_edges().to_lower()
			out["kind"] = kind if STRANDS.has(kind) else "cord"
			var lay := String(p.get("lay", "")).strip_edges().to_lower()
			out["lay"] = lay if LAYS.has(lay) else "coil"
			out["thickness"] = _num(p.get("thickness"), float((STRANDS[out["kind"]] as Dictionary)["thickness"]), 0.05, 5.0)
			out["length"] = _num(p.get("length"), 120.0, 5.0, MAX_STRAND)
			out["loose"] = _num(p.get("loose"), 0.3, 0.0, 1.0)
			# none given: the lay chooses one from the length ([method _strand_flat])
			out["radius"] = _num(p["radius"], 6.0, 0.5, MAX_SIZE * 0.5) if (p.get("radius") is float or p.get("radius") is int) else -1.0
			var far := DRAPE_REACH if out["lay"] == "drape" else MAX_SIZE
			out["path"] = _points2(p.get("path"), Vector2(-far, -far), Vector2(far, far)).slice(0, MAX_POINTS)
			if out["lay"] in ["path", "drape"] and (out["path"] as Array).size() < 2:
				out["lay"] = "heap"
			out["leaf"] = _num(p.get("leaf"), 3.0, 0.5, 15.0)
			var lm := String(p.get("leaves", "")).strip_edges() if p.get("leaves") is String else ""
			out["leaves"] = lm if mats.has(lm) else ""
		"bone":
			var kind := String(p.get("kind", "")).strip_edges().to_lower()
			out["kind"] = kind if BONES.has(kind) else "long"
			var dl: Vector2 = BONES[out["kind"]]
			out["length"] = _num(p.get("length"), dl.x, 1.0, MAX_SIZE)
			out["thickness"] = _num(p.get("thickness"), dl.y * float(out["length"]) / dl.x, 0.1, 8.0)
		"skull":
			var kind := String(p.get("kind", "")).strip_edges().to_lower()
			out["kind"] = kind if SKULLS.has(kind) else "human"
			out["length"] = _num(p.get("length"), float(SKULLS[out["kind"]]), 2.0, 40.0)
			var horns := String(p.get("horns", "curved")).strip_edges().to_lower() if p.get("horns") is String else "curved"
			out["horns"] = horns if horns in ["straight", "curved", "curled", "none"] else "curved"
		"sculpt":
			out["strokes"] = _strokes(p.get("strokes"))
			if (out["strokes"] as Array).is_empty():
				return {}
			out["mirror"] = _flag(p.get("mirror"))
		"bloom":
			out["petals"] = int(_num(p.get("petals"), 8.0, 3.0, 24.0))
			out["layers"] = int(_num(p.get("layers"), 2.0, 1.0, 4.0))
			out["radius"] = _num(p.get("radius"), 3.0, 0.5, 15.0)
			out["cup"] = _num(p.get("cup"), 0.4, 0.0, 1.0)
			out["width"] = _num(p.get("width"), 0.55, 0.2, 1.2)
	out["ornament"] = _sanitize_ornament(p.get("ornament"))
	out["copies"] = _copies_of(p)
	out["warp"] = _sanitize_warp(p.get("warp"))
	return out


## A LOFT'S SECTIONS made safe, sorted along its path: each `{outline, points, size, sides, scale,
## turn, shift, at}`. A section names its own outline or takes the part's; a section written as a
## bare number is a size. One with no `at` is set between its neighbors, the first at 0 and the last
## at 1 when they have none.
static func _sections(p: Dictionary) -> Array:
	var base := _section(p, {"outline": "circle", "points": [], "size": Vector2(2.0, 2.0), "sides": 6})
	var out: Array = []
	for s in ((p["sections"] as Array).slice(0, MAX_SECTIONS) if p.get("sections") is Array else []):
		if s is Dictionary:
			out.append(_section(s as Dictionary, base))
		elif s is float or s is int:
			out.append(_section({"size": s}, base))
	if out.is_empty():
		base["at"] = 0.0
		return [base]
	var n := out.size()
	if float((out[0] as Dictionary)["at"]) < 0.0:
		out[0]["at"] = 0.0
	if n > 1 and float((out[n - 1] as Dictionary)["at"]) < 0.0:
		out[n - 1]["at"] = 1.0
	var i := 1
	while i < n:
		if float((out[i] as Dictionary)["at"]) >= 0.0:
			i += 1
			continue
		var j := i
		while float((out[j] as Dictionary)["at"]) < 0.0:
			j += 1
		var a := float((out[i - 1] as Dictionary)["at"])
		var b := float((out[j] as Dictionary)["at"])
		for k in range(i, j):
			out[k]["at"] = lerpf(a, b, float(k - i + 1) / float(j - i + 1))
		i = j
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["at"]) < float(y["at"]))
	return out


static func _section(d: Dictionary, base: Dictionary) -> Dictionary:
	var outline := String(d.get("outline", base.get("outline", "circle"))).strip_edges().to_lower()
	var pts := _points2(d.get("points"), Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE))
	if pts.size() < 3:
		pts = [] if d.has("outline") else base.get("points", [])
	var size: Vector2 = base.get("size", Vector2(2.0, 2.0))
	if d.get("size") is float or d.get("size") is int:
		var s := _num(d["size"], 2.0, 0.0, MAX_SIZE)
		size = Vector2(s, s)
	else:
		var sz := _points2([d.get("size")], Vector2.ZERO, Vector2(MAX_SIZE, MAX_SIZE))
		if not sz.is_empty():
			size = sz[0]
	var shift := _points2([d.get("shift")], Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE))
	var at: Variant = d.get("at")
	return {"outline": outline if EXTRUDE_OUTLINES.has(outline) else "circle", "points": pts, "size": size,
		"sides": int(_num(d.get("sides"), float(base.get("sides", 6)), 3.0, 12.0)),
		"scale": _num(d.get("scale"), 1.0, 0.0, 10.0), "turn": _num(d.get("turn"), 0.0, -1080.0, 1080.0),
		"shift": shift[0] if not shift.is_empty() else Vector2.ZERO,
		"at": clampf(float(at), 0.0, 1.0) if (at is float or at is int) else -1.0}


## A part's WARP made safe: only what it changes, each in range.
static func _sanitize_warp(w: Variant) -> Dictionary:
	if not (w is Dictionary):
		return {}
	var d: Dictionary = w
	var out := {}
	if d.get("scale") is float or d.get("scale") is int:
		var s := _num(d["scale"], 1.0, 0.1, 4.0)
		out["scale"] = Vector3(s, s, s)
	elif d.get("scale") is Array:
		out["scale"] = _vec3(d["scale"], Vector3.ONE, 4.0, 0.1)
	if out.get("scale", Vector3.ONE) == Vector3.ONE:
		out.erase("scale")
	for k in WARPS:
		var r: Vector2 = WARPS[k]
		var x := _num(d.get(k), 0.0, r.x, r.y)
		if x != 0.0:
			out[k] = x
	var lean := _points2([d.get("lean")], Vector2(-MAX_SIZE, -MAX_SIZE), Vector2(MAX_SIZE, MAX_SIZE))
	if not lean.is_empty() and lean[0] != Vector2.ZERO:
		out["lean"] = lean[0]
	if not out.has("bend"):
		out.erase("bend_to")
	return out


## A part's (or a group's) repeat: its `copies` - or a REPEAT WRITTEN BESIDE IT ({"line": {...}} on
## the part itself), which is the same repeat: a set dresser wrote a skein's turns that way, and one
## turn of each color was built, the top one floating where the turns under it should have been.
static func _copies_of(p: Dictionary) -> Dictionary:
	var c := _sanitize_copies(p.get("copies"))
	if not c.is_empty():
		return c
	var loose := {}
	for kind in ["ring", "line", "scatter", "heap"]:
		if p.get(kind) is Dictionary:
			loose[kind] = p[kind]
	if loose.is_empty():
		return {}
	if p.has("jitter"):
		loose["jitter"] = p["jitter"]
	return _sanitize_copies(loose)


## How many flames [param part] lights: its wicks on every copy of it - a group's parts' on every
## copy of the group.
static func flames_of(part: Dictionary) -> int:
	var n := 0
	if part.get("parts") is Array:
		for q in part["parts"]:
			n += flames_of(q as Dictionary)
	elif part.get("wick") == true:
		n = maxi(int(part.get("wicks", 1)), 1)
	var c: Dictionary = part.get("copies", {})
	return n * (int(c.get("count", 1)) if not c.is_empty() else 1)


## [param part] standing unlit - a group with every part in it.
static func unlit(part: Dictionary) -> void:
	part["wick"] = false
	for q in (part.get("parts", []) if part.get("parts") is Array else []):
		unlit(q as Dictionary)


## The key of the material a part names: one under `materials`, one written inline (kept under a
## key of its own), or a bare kind; anything else is painted in the look's own colors.
static func _material_key(m: Variant, mats: Dictionary, pal: Array) -> String:
	if m is Dictionary:
		var key := "inline %d" % mats.size()
		mats[key] = sanitize_material(m, String(pal[mats.size() % pal.size()]))
		return key
	var name := String(m).strip_edges() if m is String else ""
	if mats.has(name) and not name.is_empty():
		return name
	if MATERIALS.has(name.to_lower()):
		var key := name.to_lower()
		if not mats.has(key):
			mats[key] = sanitize_material({"kind": key}, String(pal[mats.size() % pal.size()]))
		return key
	if not mats.has("painted"):
		mats["painted"] = sanitize_material({"kind": "painted"}, String(pal[0]))
	return "painted"


static func _sanitize_ornament(o: Variant) -> Dictionary:
	if not (o is Dictionary):
		return {}
	var d: Dictionary = o
	var kind := String(d.get("kind", "")).strip_edges().to_lower()
	if not ORNAMENTS.has(kind):
		return {}
	var out := {"kind": kind, "count": _num(d.get("count"), 8.0, 1.0, 64.0),
		"depth": _num(d.get("depth"), 0.5, 0.0, 1.0), "from": _num(d.get("from"), 0.0, 0.0, 1.0),
		"to": _num(d.get("to"), 1.0, 0.0, 1.0)}
	if _is_color(d.get("color", "")):
		out["color"] = String(d["color"]).strip_edges()
	return out


static func _sanitize_copies(c: Variant) -> Dictionary:
	if not (c is Dictionary):
		return {}
	var d: Dictionary = c
	var jitter := _num(d.get("jitter"), 0.0, 0.0, 1.0)
	for kind in ["ring", "line", "scatter", "heap"]:
		if not (d.get(kind) is Dictionary):
			continue
		var k: Dictionary = d[kind]
		var out := {"kind": kind, "count": int(_num(k.get("count"), 3.0, 1.0, float(MAX_COPIES))),
			"jitter": _num(k.get("jitter"), jitter, 0.0, 1.0)}
		match kind:
			"ring":
				out["radius"] = _num(k.get("radius"), 3.0, 0.0, MAX_SIZE * 0.5)
				out["start"] = _num(k.get("start"), 0.0, -360.0, 360.0)
				out["arc"] = _num(k.get("arc"), 360.0, 10.0, 360.0)
				out["face"] = _flag(k.get("face"), true)
			"line":
				out["step"] = _vec3(k.get("step"), Vector3(2, 0, 0), MAX_SIZE)
			"scatter", "heap":
				out["radius"] = _num(k.get("radius"), 4.0, 0.0, MAX_SIZE * 0.5)
		return out
	return {}


static func _num(v: Variant, fallback: float, lo: float, hi: float) -> float:
	var x := fallback
	if v is float or v is int:
		x = float(v)
	elif v is String and (v as String).is_valid_float():
		x = (v as String).to_float()
	if is_nan(x) or is_inf(x):
		x = fallback
	return clampf(x, lo, hi)


## A yes or no an agent wrote: itself when it is one, [param fallback] when it is anything else (a
## "yes" compared with true is an error, not false).
static func _flag(v: Variant, fallback := false) -> bool:
	return bool(v) if v is bool else fallback


static func _text(v: Variant, most: int) -> String:
	var s := (v as String) if v is String else ("" if v == null else str(v))
	return s.strip_edges().substr(0, most)


static func _is_color(v: Variant) -> bool:
	return v is String and Manuscript._rx("^#[0-9a-fA-F]{6}$").search((v as String).strip_edges()) != null


static func _color(v: Variant, fallback: String) -> String:
	if _is_color(v):
		return String(v).strip_edges()
	return fallback if _is_color(fallback) else "#808080"


static func _vec3(v: Variant, fallback: Vector3, lim: float, lo := -INF) -> Vector3:
	if not (v is Array) or (v as Array).size() < 3:
		return fallback
	var a: Array = v
	var out := Vector3(_num(a[0], fallback.x, -lim, lim), _num(a[1], fallback.y, -lim, lim), _num(a[2], fallback.z, -lim, lim))
	if lo > -INF:
		out = out.clamp(Vector3(lo, lo, lo), Vector3(lim, lim, lim))
	return out


static func _turn(v: Variant) -> Vector3:
	if v is float or v is int:
		return Vector3(0.0, clampf(float(v), -720.0, 720.0), 0.0)
	return _vec3(v, Vector3.ZERO, 720.0)


static func _points2(v: Variant, lo: Vector2, hi: Vector2) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for q in (v as Array):
		if out.size() >= MAX_POINTS:
			break
		if q is Array and (q as Array).size() >= 2 and (q[0] is float or q[0] is int) and (q[1] is float or q[1] is int):
			out.append(Vector2(float(q[0]), float(q[1])).clamp(lo, hi))
	return out


## Each kept point's ROUNDING, one for one with [method _points2] ([param dims] 2) or [method
## _points3] (3): the number an agent wrote after the point's coordinates - the radius its corner
## is rounded to, in centimeters, 0 a crisp corner - or -1 where it wrote none.
static func _rounds(v: Variant, dims: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not (v is Array):
		return out
	for q in (v as Array):
		if out.size() >= MAX_POINTS:
			break
		if not (q is Array) or (q as Array).size() < dims:
			continue
		var a: Array = q
		if dims == 2 and not ((a[0] is float or a[0] is int) and (a[1] is float or a[1] is int)):
			continue
		out.append(clampf(float(a[dims]), 0.0, 20.0) if a.size() > dims and (a[dims] is float or a[dims] is int) else -1.0)
	return out


static func _points3(v: Variant, lim: float) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for q in (v as Array):
		if out.size() >= MAX_POINTS:
			break
		if q is Array and (q as Array).size() >= 3:
			out.append(_vec3(q, Vector3.ZERO, lim))
	return out


# --- building -----------------------------------------------------------------------------

## HOW MUCH OF A DRAFT REACHES A FLAME lit at [param at] (a wick's top, world) on thing [param node]: all of
## it in the open; little in a chimney, a lantern or a hurricane glass - any of the thing's [param meshes]
## standing round the flame (its middle over the flame, seen from above, and wider than a wick) and
## rising past it, the less the higher it rises over the wick ([constant SHELTER]). A candelabra's stem
## stands beside its arms' flames, not round them, and a candle's own wax ends at its wick.
static func open_to_air(at: Vector3, node: Node3D, meshes: Array) -> float:
	var open := 1.0
	for m in meshes:
		if not (m is MeshInstance3D) or (m as MeshInstance3D).mesh == null:
			continue
		var xf := (m as MeshInstance3D).transform
		var up := (m as Node3D).get_parent()
		while up != null and up != node and up is Node3D:
			xf = (up as Node3D).transform * xf
			up = up.get_parent()
		var box: AABB = node.transform * xf * (m as MeshInstance3D).mesh.get_aabb()
		var half := minf(box.size.x, box.size.z) * 0.5
		var mid := box.get_center()
		if half < 0.008 or Vector2(mid.x - at.x, mid.z - at.z).length() > 0.35 * half or box.position.y > at.y:
			continue
		open = minf(open, clampf(1.0 - (box.end.y - at.y) / SHELTER.x, SHELTER.y, 1.0))
	return open


## A FLAME SHELTERED: walls round it this far over its wick (meters) keep off all of a draft they can, and
## that is all but this share of it - a chimney draws air of its own.
const SHELTER := Vector2(0.05, 0.1)


## A THING, BUILT: `node` (its meshes, in meters: base on y = 0, centered over what it stands on,
## front toward +z), `size` (its bounds), `foot` (the convex outline of where it meets the cloth,
## up to [constant FOOT_H], x by z), `outline` (its whole outline seen from above), `wicks`
## (where its flames are lit), `glows` (each wick's wax material, whose `flame` the table sets as
## the flame flickers) and `meshes` (every MeshInstance3D in it). [param materials] are the
## sanitized materials; [param seed] varies drips, scatter, lumps and the patterns' noise.
## [param keep]: built where it was written, neither moved to stand on the origin nor made smaller - a strand
## draped across the table is laid in the table's own space ([method TableMedium._drape]).
static func build(thing: Dictionary, materials: Dictionary, seed: int, keep := false) -> Dictionary:
	var inner := Node3D.new()
	var all := PackedVector3Array()
	var wicks: Array = []
	var glows: Array = []
	var meshes: Array = []
	# EVERY PART, its groups opened: its geometry and every place it stands - its groups' repeats and
	# its own together - and no more of them in all than a thing may make
	var leaves := _assemble(thing.get("parts", []), seed, [])
	var budget := MAX_INSTANCES
	for leaf in leaves:
		var xs: Array = leaf["xforms"]
		leaf["xforms"] = xs.slice(0, maxi(budget, 0))
		budget -= xs.size()
	for leaf in leaves:
		var part: Dictionary = leaf["part"]
		var geos: Array = leaf["geos"]
		var xforms: Array = leaf["xforms"]
		var salt: Variant = leaf["salt"]
		if xforms.is_empty():
			continue
		# A FLAME FOR EVERY WICK on the top of a candle that is not turned (a turned one's are set
		# where its pool is, in [method _lathe])
		var g0: Tris = (geos[0] as Dictionary)["geo"]
		if part.get("wick") == true and g0.wicks.is_empty():
			for sp in _wick_spots(part, _top_radius(g0)):
				g0.wicks.append(Vector3(g0.top.x + (sp as Vector2).x, g0.top.y, g0.top.z + (sp as Vector2).y))
		# A LIST OF MATERIALS is taken by the copies in turn: a mesh for each material's copies
		var names: Array = part.get("materials", [])
		if names.is_empty():
			names = [String(part.get("material", "painted"))]
		for gi in geos.size():
			var g: Tris = (geos[gi] as Dictionary)["geo"]
			if g.v.is_empty():
				continue
			var fixed := String((geos[gi] as Dictionary).get("material", ""))
			var takers := {}
			for ci in xforms.size():
				var nm := fixed if not fixed.is_empty() else String(names[ci % names.size()])
				if not takers.has(nm):
					takers[nm] = []
				(takers[nm] as Array).append(ci)
			for nm in takers:
				var ids: Array = takers[nm]
				var mine: Array = []
				for ci in ids:
					mine.append(xforms[ci])
				var merged := g.placed(mine, ids)
				var m: Dictionary = materials.get(nm, sanitize_material({}, "#808080"))
				var mi := MeshInstance3D.new()
				mi.mesh = merged.mesh()
				var mat := material(m, part.get("ornament", {}), g.girth, g.height, hash([seed, salt, gi, nm]), _solid(part), not String(part.get("shape", "")) in ["lathe", "extrude"])
				mi.material_override = mat
				if see_through(m):
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				inner.add_child(mi)
				meshes.append(mi)
				all.append_array(merged.v)
				if gi == 0 and part.get("wick") == true:
					for xf in mine:
						for w in g.wicks:
							wicks.append((xf as Transform3D) * w)
							glows.append(mat)
	var root := Node3D.new()
	root.add_child(inner)
	if all.is_empty():
		return {"node": root, "size": AABB(), "foot": PackedVector2Array(), "outline": PackedVector2Array(),
			"wicks": [], "glows": [], "meshes": []}
	var box := AABB(all[0], Vector3.ZERO)
	for p in all:
		box = box.expand(p)
	# TOO BIG IS SCALED DOWN WHOLE: an agent's 2-meter vase is a mistake in units, not a vase
	var k := minf(1.0, MAX_SIZE * 0.01 / maxf(box.size.x, maxf(box.size.y, box.size.z))) if not keep else 1.0
	var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) if not keep else Vector3.ZERO
	inner.scale = Vector3(k, k, k)
	inner.position = shift * k
	var placed := PackedVector3Array()
	for p in all:
		placed.append((p + shift) * k)
	for i in wicks.size():
		wicks[i] = ((wicks[i] as Vector3) + shift) * k
	var size := AABB((box.position + shift) * k, box.size * k)
	return {"node": root, "size": size, "foot": _foot(placed, FOOT_H), "outline": _hull(placed, INF),
		"wicks": wicks, "glows": glows, "meshes": meshes}


## A thing's parts, groups opened: `[{part, geos, xforms, salt}]` - each shaped part with its
## geometry and every place it stands in the thing (its own repeats inside its groups', a group's
## copies sized - for a scatter or a heap - and jittered about their middles by everything in it).
## A heap is laid last, into whatever the other parts make of a vessel round it. [param path] is
## where these parts sit among the groups; `salt` is a part's place, the same as it always was for a
## part in no group.
static func _assemble(parts: Array, seed: int, path: Array) -> Array:
	var out: Array = []
	var heaps: Array = []    # [place in out, rng]: laid last, into whatever they lie in ([method _walls])
	for pi in parts.size():
		var part: Dictionary = parts[pi]
		var here: Variant = pi if path.is_empty() else path + [pi]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, here, "part"])
		if part.get("parts") is Array:
			var inner := _assemble(part["parts"], seed, path + [pi])
			if inner.is_empty():
				continue
			var sized: Array = []
			var copies: Dictionary = part.get("copies", {})
			if String(copies.get("kind", "")) in ["scatter", "heap"] or float(copies.get("jitter", 0.0)) > 0.0:
				for leaf in inner:
					for e in leaf["geos"]:
						sized.append({"geo": ((e as Dictionary)["geo"] as Tris).placed(leaf["xforms"])})
			var outer := _placements(part, rng, sized)
			for leaf in inner:
				var xs: Array = []
				for o in outer:
					for x in leaf["xforms"]:
						xs.append((o as Transform3D) * (x as Transform3D))
				leaf["xforms"] = xs
				out.append(leaf)
			continue
		var geos := _geometry(part, rng)
		if geos.is_empty():
			continue
		if String((part.get("copies", {}) as Dictionary).get("kind", "")) in ["heap", "scatter"]:
			heaps.append([out.size(), rng])
			out.append({"part": part, "geos": geos, "xforms": [], "salt": here})
			continue
		out.append({"part": part, "geos": geos, "xforms": _placements(part, rng, geos), "salt": here})
	for h in heaps:
		var leaf: Dictionary = out[h[0]]
		var at: Vector3 = (leaf["part"] as Dictionary).get("at", Vector3.ZERO)
		if String(((leaf["part"] as Dictionary)["copies"] as Dictionary)["kind"]) == "scatter":
			leaf["xforms"] = _placements(leaf["part"], h[1], leaf["geos"], {}, _blocks(out, at.y * 0.01))
		else:
			leaf["xforms"] = _placements(leaf["part"], h[1], leaf["geos"], _walls(out, h[0], at * 0.01))
	return out


## WHAT A STREWN PART MUST NOT LIE ON: the outline, seen from above, of every standing part among
## [param leaves] (everything but the strewn ones) that rises above the floor at [param floor_y],
## one convex hull per copy - a tablet's slab, a pedestal. Stones scattered beside a slab used to be
## drawn through it (feedback 0009).
static func _blocks(leaves: Array, floor_y: float) -> Array:
	var out: Array = []
	for leaf in leaves:
		if String(((leaf["part"] as Dictionary).get("copies", {}) as Dictionary).get("kind", "")) in ["scatter", "heap"]:
			continue
		for x in leaf["xforms"]:
			var pts := PackedVector2Array()
			for e in leaf["geos"]:
				for q in ((e as Dictionary)["geo"] as Tris).v:
					var w: Vector3 = (x as Transform3D) * q
					if w.y > floor_y + 0.002:
						pts.append(Vector2(w.x, w.z))
			if pts.size() >= 3:
				var hull := Geometry2D.convex_hull(pts)
				if hull.size() >= 4:
					out.append(hull)
	return out


## Whether a disc of [param r] at [param p] meets any of [param blocks] ([method _blocks]).
static func _blocked(p: Vector2, r: float, blocks: Array) -> bool:
	for hull in blocks:
		var poly: PackedVector2Array = hull
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
		for i in poly.size():
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])) < r + 0.001:
				return true
	return false


## Where a candle's wicks stand on a top of radius [param R] (meters), from its middle: each where
## it was placed (kept on the top), or so many set round it - one in the middle, two to six on a
## ring half way out (more a little further).
static func _wick_spots(p: Dictionary, R: float) -> Array:
	var out: Array = []
	var spots: Array = p.get("wick_spots", [])
	if not spots.is_empty():
		for sp in spots:
			var v := (sp as Vector2) * 0.01
			if v.length() > R * 0.85:
				v = v.normalized() * R * 0.85
			out.append(v)
		return out
	var n := maxi(int(p.get("wicks", 1)), 1)
	if n == 1:
		return [Vector2.ZERO]
	var r := R * (0.5 if n <= 3 else 0.62)
	for i in n:
		var a := -PI * 0.5 + TAU * float(i) / float(n)
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


## How far a part's top reaches from its middle (meters): what of it lies within a millimeter of its
## highest point.
static func _top_radius(g: Tris) -> float:
	var r := 0.0
	for q in g.v:
		if q.y >= g.top.y - 0.001:
			r = maxf(r, Vector2(q.x - g.top.x, q.z - g.top.z).length())
	return maxf(r, 0.004)


## Whether a material is drawn see-through: glass, and crystal clear enough to see through.
static func see_through(m: Dictionary) -> bool:
	var kind := String(m.get("kind", ""))
	return kind == "glass" or (kind == "crystal" and float(m.get("clarity", 0.5)) >= CLEAR)


## Whether a part is SOLID rather than a vessel: a ball, a crystal, a rod - or a turned part whose
## profile never goes back down (a hollow one climbs its outside and comes down its inside).
static func _solid(part: Dictionary) -> bool:
	if String(part.get("shape", "")) in ["extrude", "tube", "loft"]:
		return float(part.get("wall", 0.0)) <= 0.0
	if String(part.get("shape", "")) != "lathe":
		return String(part.get("shape", "")) in ["ball", "point", "cluster", "geode", "ring", "coil"]
	var prof: Array = part.get("profile", [])
	var top := -INF
	for q in prof:
		top = maxf(top, (q as Vector2).y)
		if (q as Vector2).y < top - 0.5:
			return false
	return true


## The material for one part: the named material's look with this part's ornament, laid out for
## its own girth and height (so a motif keeps its shape on a tall vase and a squat bowl alike).
## SEEN-THROUGH material is glass for a vessel - a flame inside it shows - and a lens for a solid
## thing, which bends what is behind it.
static func material(m: Dictionary, orn: Variant, girth: float, height: float, salt: int, solid := false, round_solid := true) -> ShaderMaterial:
	var kind := String(m.get("kind", "painted"))
	var mat := ShaderMaterial.new()
	# CLEAR CRYSTAL IS SEEN THROUGH: an opaque shader made a crystal ball a pearl
	var clear := see_through(m)
	mat.shader = (_LENS if solid else _GLASS) if clear else _SHADER
	if not clear:
		mat.set_shader_parameter("kind", int((MATERIALS.get(kind, MATERIALS["painted"]) as Dictionary)["code"]))
	mat.set_shader_parameter("color", Color.html(String(m.get("color", "#808080"))))
	mat.set_shader_parameter("color2", Color.html(String(m.get("color2", "#404040"))))
	for k in ["polish", "wear", "pattern", "clarity", "grain"]:
		mat.set_shader_parameter(k, float(m.get(k, 0.5)))
	if clear and solid:
		mat.set_shader_parameter("bend_y", 1.0 if round_solid else 0.0)
	mat.set_shader_parameter("seed", float(salt & 0xFFF) / 64.0)
	mat.set_shader_parameter("dims", Vector2(maxf(girth, 0.5), maxf(height, 0.5)))
	var play := String(m.get("play", ""))
	mat.set_shader_parameter("play", int((PLAYS[play] as Dictionary)["code"]) if PLAYS.has(play) else 0)
	mat.set_shader_parameter("rings", 1.0 if m.get("rings") == true else 0.0)
	var o: Dictionary = orn if orn is Dictionary else {}
	if not o.is_empty():
		mat.set_shader_parameter("orn", int((ORNAMENTS[String(o["kind"])] as Dictionary)["code"]))
		mat.set_shader_parameter("orn_count", float(o.get("count", 8.0)))
		mat.set_shader_parameter("orn_depth", float(o.get("depth", 0.5)))
		mat.set_shader_parameter("orn_zone", Vector2(float(o.get("from", 0.0)), float(o.get("to", 1.0))))
		if o.has("color"):
			mat.set_shader_parameter("orn_color", Color.html(String(o["color"])))
			mat.set_shader_parameter("orn_paint", 1.0)
	return mat


## Where each copy of a part goes, in the thing's space: the part turned about its own origin,
## then laid out as its copies ask, then moved to its `at`. [param geos] are the part's geometry
## ([method _geometry]), which strewn copies need the size of.
static func _placements(part: Dictionary, rng: RandomNumberGenerator, geos: Array, walls := {}, blocks := []) -> Array:
	var turn: Vector3 = part.get("turn", Vector3.ZERO)
	var own := Transform3D(Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))), Vector3.ZERO)
	var at: Vector3 = (part.get("at", Vector3.ZERO) as Vector3) * 0.01
	var c: Dictionary = part.get("copies", {})
	var out: Array = []
	if c.is_empty():
		return [Transform3D(Basis(), at) * own]
	var n := int(c["count"])
	var jit := float(c.get("jitter", 0.0))
	if String(c["kind"]) in ["scatter", "heap"]:
		return _strewn(String(c["kind"]) == "heap", n, jit, float(c["radius"]) * 0.01, own, at, _bounds(geos, own), rng, walls, blocks)
	# A COPY'S JITTER TURNS IT ABOUT ITS OWN MIDDLE: about the part's origin, a rod drawn away from
	# it (a squid's arm, a jig lying on its side) swung across the thing, and a row of them splayed
	# like legs (feedback 0006)
	var pivot := _pivot(geos, own)
	for i in n:
		var xf := Transform3D.IDENTITY
		match String(c["kind"]):
			"ring":
				# round the whole circle evenly, or along an arc from one end to the other
				var arc := float(c.get("arc", 360.0))
				var a := deg_to_rad(float(c.get("start", 0.0)) + (arc * float(i) / float(n) if arc >= 359.9 else arc * float(i) / float(maxi(n - 1, 1))))
				var r := float(c["radius"]) * 0.01
				xf = Transform3D(Basis(Vector3.UP, -a) if bool(c.get("face", true)) else Basis(), Vector3(cos(a), 0.0, sin(a)) * r)
			"line":
				xf = Transform3D(Basis(), (c["step"] as Vector3) * 0.01 * float(i))
		if jit > 0.0:
			var s := 1.0 + rng.randf_range(-0.15, 0.15) * jit
			var turn_by := Basis(Vector3.UP, rng.randf_range(-0.45, 0.45) * jit).scaled(Vector3(s, s, s))
			xf = xf * Transform3D(Basis(), pivot) * Transform3D(turn_by, Vector3.ZERO) * Transform3D(Basis(), -pivot)
		out.append(Transform3D(Basis(), at) * xf * own)
	return out


## The middle of a part's base, turned by [param own] as each copy is: halfway across what it
## covers seen from above, at its lowest. The origin when there is no geometry to measure.
static func _pivot(geos: Array, own: Transform3D) -> Vector3:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for e in geos:
		for q in ((e as Dictionary)["geo"] as Tris).v:
			var w := own.basis * q
			lo = Vector3(minf(lo.x, w.x), minf(lo.y, w.y), minf(lo.z, w.z))
			hi = Vector3(maxf(hi.x, w.x), maxf(hi.y, w.y), maxf(hi.z, w.z))
	if lo.x > hi.x:
		return Vector3.ZERO
	return Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)


## STREWN COPIES. Scattered ones never touch: each takes a spot in the circle clear of the rest,
## and a handful too crowded for it spreads wider rather than pass through itself. HEAPED ones
## settle as a dropped handful does ([method _heaped]): on the floor while there is room, then in
## the pockets of the heap, a little tipped where they lie on others - so the floor fills before
## the heap rises.
static func _strewn(heap: bool, n: int, jit: float, radius: float, own: Transform3D, at: Vector3, bounds: Dictionary,
		rng: RandomNumberGenerator, walls := {}, blocks := []) -> Array:
	var reach := float(bounds["reach"])
	var girth := float(bounds["girth"])
	var low := float(bounds["low"])
	var tall := float(bounds["high"]) - low
	var laid: Array = []     # [where (x, z), reach]
	var mids := PackedVector3Array()   # a heap's lumps: middles, half-widths, half heights
	var wide_of := PackedFloat32Array()
	var high_of := PackedFloat32Array()
	var out: Array = []
	var flat := heap and girth >= tall * 0.5 * FLAT
	for i in n:
		var s := 1.0 + rng.randf_range(-0.15, 0.15) * jit
		var r := reach * s
		var hh := tall * s * 0.5
		var spot := Vector2.ZERO
		var mid := hh
		if heap:
			var rest: Variant = (_stacked(girth * s, hh, radius, mids, wide_of, high_of, walls, rng) if flat
			else _heaped(girth * s, hh, radius, mids, wide_of, high_of, walls, rng))
			if rest == null:
				continue
			var p: Vector3 = rest
			mids.append(p)
			wide_of.append(girth * s)
			high_of.append(hh)
			spot = Vector2(p.x, p.z)
			mid = p.y
		else:
			var wide := radius
			for k in 240:
				if k > 0 and k % 24 == 0:
					wide = wide * 1.15 + r * 0.3
				var q := Vector2.from_angle(rng.randf() * TAU) * wide * sqrt(rng.randf())
				var clear := true
				for e in laid:
					if q.distance_to(e[0]) < r + float(e[1]) + 0.001:
						clear = false
						break
				# NEVER THROUGH A STANDING PART of the same thing
				if clear and not blocks.is_empty() and _blocked(Vector2(at.x, at.z) + q, r, blocks):
					clear = false
				spot = q
				if clear:
					break
			if not blocks.is_empty() and _blocked(Vector2(at.x, at.z) + spot, r, blocks):
				continue
		laid.append([spot, r])
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		# a flat lump (a coin) lies flat: a tipped disc's rim swings through its neighbors
		if mid > hh * 1.2 and not flat:
			b = Basis(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.1, 0.35)) * b
		# turned and tipped about its own middle, so a tipped lump stays in the pocket it was laid in
		out.append(Transform3D(Basis(), at) * Transform3D(b, Vector3(spot.x, mid, spot.y))
			* Transform3D(Basis(), Vector3(0.0, -(low + tall * 0.5), 0.0)) * own)
	return out


## WHERE A HEAPED LUMP COMES TO REST - its middle - [param a] wide and [param b] high (half sizes,
## meters) among the lumps already down ([param mids], [param wide_of], [param high_of]): on the
## floor where it is dropped while there is room there; then in a POCKET of the heap
## ([method _pockets]) - or against the wall of the vessel it lies in ([param walls], see
## [method _walls]); then on the floor further out, as a handful spills wider, but never through a
## vessel's wall. Null when a vessel has no room left for it. NEVER ON TOP OF ONE ROUND LUMP: a
## pebble balanced on another rolls off it, in the world and in the eye (feedback 0006 - a rule that
## let a lump rest over another's middle stacked them into columns).
static func _heaped(a: float, b: float, radius: float, mids: PackedVector3Array, wide_of: PackedFloat32Array,
		high_of: PackedFloat32Array, walls: Dictionary, rng: RandomNumberGenerator) -> Variant:
	# how far out its middle may lie, below the rim of what holds it
	var inside := INF if walls.is_empty() else float(walls["radius"]) - a
	var rim := INF if walls.is_empty() else float(walls["top"])
	if inside <= 0.0:
		return null
	var drop := minf(radius, inside)
	for k in 48:
		var q := Vector2.from_angle(rng.randf() * TAU) * drop * sqrt(rng.randf())
		if _free(Vector3(q.x, b, q.y), a, b, mids, wide_of, high_of):
			return Vector3(q.x, b, q.y)
	var rests: Array = []
	for p in _pockets(a, b, mids, wide_of, high_of, rng):
		var rest: Vector3 = p
		# below the rim, inside the wall; above it, it may lean out over the rim
		if rest.y - b >= rim or Vector2(rest.x, rest.z).length() <= inside:
			rests.append(rest)
	if not walls.is_empty():
		rests.append_array(_wall_pockets(a, b, inside, rim, mids, wide_of, high_of))
	if not rests.is_empty():
		# it drops into one of the LOW places, not always the lowest of them
		var lowest := INF
		for p in rests:
			lowest = minf(lowest, (p as Vector3).y)
		var near: Array = rests.filter(func(p: Vector3) -> bool: return p.y <= lowest + b * 0.5)
		return near[rng.randi() % near.size()]
	var wide := drop
	var q := Vector2.ZERO
	for k in 240:
		if k > 0 and k % 24 == 0:
			wide = minf(wide * 1.15 + a * 0.3, inside)
		q = Vector2.from_angle(rng.randf() * TAU) * wide * sqrt(rng.randf())
		if _free(Vector3(q.x, b, q.y), a, b, mids, wide_of, high_of):
			return Vector3(q.x, b, q.y)
	# no room anywhere: a vessel leaves it out, the open cloth takes it where it fell
	return null if not walls.is_empty() else Vector3(q.x, b, q.y)


## WHERE A HEAPED FLAT LUMP (a coin) COMES TO REST, sizes as in [method _heaped]. Coins are discs,
## not the rounded lumps [method _free] and [method _pockets] treat as ellipsoids, whose rims pass
## through each other where they overlap and which settle into pockets no disc fits: a coin is
## dropped at several places in the circle, falls to the top of the highest coin whose disc it
## overlaps (lying flat, one thickness above it), and takes the lowest of them - so the dish floor
## fills before the heap rises, and no two coins ever share space (feedback 0008). Null when the
## vessel has no room left for it.
static func _stacked(a: float, b: float, radius: float, mids: PackedVector3Array, wide_of: PackedFloat32Array,
		high_of: PackedFloat32Array, walls: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var inside := INF if walls.is_empty() else float(walls["radius"]) - a
	var rim := INF if walls.is_empty() else float(walls["top"])
	if inside <= 0.0:
		return null
	var drop := minf(radius, inside)
	var best: Variant = null
	for k in 24:
		var q := Vector2.from_angle(rng.randf() * TAU) * drop * sqrt(rng.randf())
		var y := b
		for i in mids.size():
			var d := Vector2(q.x - mids[i].x, q.y - mids[i].z).length()
			# 1.03: a disc cut in flat sides reaches a little past its mean half-width
			if d < (a + wide_of[i]) * 1.03:
				y = maxf(y, mids[i].y + high_of[i] + b + 0.00005)
		if best == null or y < (best as Vector3).y - 1e-6:
			best = Vector3(q.x, y, q.y)
	if (best as Vector3).y - b >= rim:
		return null
	return best


## THE WALL ROUND A HEAP, when it lies in a vessel - a dish, a bowl, a tray among the thing's other
## [param leaves] (the heap's own, [param skip], and every other strewn part left out): the nearest
## surface rising from the heap's floor, measured from its middle [param at] - `{radius, top}`,
## meters out and how high it stands above that floor. Empty when a line out from the middle in any
## direction meets no such surface - an open heap, on the cloth or beside a candle.
static func _walls(leaves: Array, skip: int, at: Vector3) -> Dictionary:
	const RAYS := 8
	var mid := Vector2(at.x, at.z)
	var hit := PackedFloat32Array()
	hit.resize(RAYS)
	hit.fill(INF)
	var tops := PackedFloat32Array()
	tops.resize(RAYS)
	var nearest := INF
	for li in leaves.size():
		var leaf: Dictionary = leaves[li]
		if li == skip or String(((leaf["part"] as Dictionary).get("copies", {}) as Dictionary).get("kind", "")) in ["scatter", "heap"]:
			continue
		for e in leaf["geos"]:
			var g: Tris = (e as Dictionary)["geo"]
			for x in leaf["xforms"]:
				var xf: Transform3D = x
				for t in range(0, g.v.size() - 2, 3):
					var p0 := xf * g.v[t]
					var p1 := xf * g.v[t + 1]
					var p2 := xf * g.v[t + 2]
					# a wall rises from the heap's floor: its foot down at the floor, its top above it
					if minf(p0.y, minf(p1.y, p2.y)) > at.y + 0.002 or maxf(p0.y, maxf(p1.y, p2.y)) < at.y + 0.004:
						continue
					var top := maxf(p0.y, maxf(p1.y, p2.y)) - at.y
					var flat := [Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p2.x, p2.z)]
					for k in 3:
						var u: Vector2 = flat[k]
						var w: Vector2 = flat[(k + 1) % 3]
						nearest = minf(nearest, mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, u, w)))
						for r in RAYS:
							var cross: Variant = Geometry2D.segment_intersects_segment(mid, mid + Vector2.from_angle(TAU * r / RAYS), u, w)
							if cross != null:
								var d := mid.distance_to(cross as Vector2)
								if d < hit[r] - 0.0005:
									hit[r] = d
									tops[r] = top
								elif d < hit[r] + 0.0005:
									tops[r] = maxf(tops[r], top)
	var rim := INF
	for r in RAYS:
		if hit[r] == INF:
			return {}
		rim = minf(rim, tops[r])
	return {"radius": nearest, "top": rim}


## How far rounded lumps nestle into each other: two touch where their half sizes, summed and taken
## this much of, meet - a lump's bumps sit in another's hollows.
const NESTLE := 0.9
## A lump this many times wider than it is high (a coin, a tile, a skimming stone) is FLAT: it can
## lie still across the middle of a single lump under it. A rounder one rolls off unless a pocket
## holds it.
const FLAT := 2.5


## Whether a lump [param a] wide and [param b] high with its middle at [param p] passes through none
## already down: each pair taken as touching ellipsoids, their half sizes summed ([constant NESTLE]).
static func _free(p: Vector3, a: float, b: float, mids: PackedVector3Array, wide_of: PackedFloat32Array,
		high_of: PackedFloat32Array) -> bool:
	for i in mids.size():
		var A := (a + wide_of[i]) * NESTLE
		var B := (b + high_of[i]) * NESTLE
		var d := p - mids[i]
		if (d.x * d.x + d.z * d.z) / (A * A) + d.y * d.y / (B * B) < 0.999:
			return false
	return true


## THE POCKETS A LUMP CAN REST IN: where three lumps hold it from below and its weight falls
## between them - the contact forces, each pushing it straight off the lump it touches, add up to
## something that holds it against gravity with every one of the three pushing ([method _pocket]).
## A FLAT lump may also lie across the middle of any one. Where three lumps stand too far apart to
## hold it, it falls between them to the floor - a place on the floor too. Places it would pass
## through another lump to reach are not places.
static func _pockets(a: float, b: float, mids: PackedVector3Array, wide_of: PackedFloat32Array,
		high_of: PackedFloat32Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := mids.size()
	var reach := PackedFloat32Array()
	var tall := PackedFloat32Array()
	for i in n:
		reach.append((a + wide_of[i]) * NESTLE)
		tall.append((b + high_of[i]) * NESTLE)
	for i in n:
		if a >= b * FLAT:
			var off := Vector2.from_angle(rng.randf() * TAU) * reach[i] * 0.35 * sqrt(rng.randf())
			var top := mids[i] + Vector3(off.x, tall[i] * sqrt(1.0 - off.length_squared() / (reach[i] * reach[i])), off.y)
			if top.y >= b and _free(top, a, b, mids, wide_of, high_of):
				out.append(top)
		for j in range(i + 1, n):
			if not _both(i, j, mids, reach, tall):
				continue
			for k in range(j + 1, n):
				if not (_both(i, k, mids, reach, tall) and _both(j, k, mids, reach, tall)):
					continue
				var p: Variant = _pocket([mids[i], mids[j], mids[k]], [reach[i], reach[j], reach[k]], [tall[i], tall[j], tall[k]], b)
				if p != null and _free(p, a, b, mids, wide_of, high_of):
					out.append(p)
	return out


## THE PLACES AGAINST A VESSEL'S WALL: two lumps holding a lump from below and the wall
## ([param inside] meters out from the middle, for its middle) holding it from the side - where it
## stands no higher than the wall's [param rim].
static func _wall_pockets(a: float, b: float, inside: float, rim: float, mids: PackedVector3Array,
		wide_of: PackedFloat32Array, high_of: PackedFloat32Array) -> Array:
	var out: Array = []
	var n := mids.size()
	for i in n:
		var ri := (a + wide_of[i]) * NESTLE
		var ti := (b + high_of[i]) * NESTLE
		if Vector2(mids[i].x, mids[i].z).length() + ri < inside:
			continue
		for j in range(i + 1, n):
			var rj := (a + wide_of[j]) * NESTLE
			var tj := (b + high_of[j]) * NESTLE
			var d := mids[i] - mids[j]
			if Vector2(mids[j].x, mids[j].z).length() + rj < inside or Vector2(d.x, d.z).length() >= ri + rj or absf(d.y) >= ti + tj:
				continue
			var p: Variant = _pocket([mids[i], mids[j]], [ri, rj], [ti, tj], b, inside)
			if p != null and (p as Vector3).y - b < rim and _free(p, a, b, mids, wide_of, high_of):
				out.append(p)
	return out


## Whether one lump can touch lumps [param i] and [param j] at once.
static func _both(i: int, j: int, mids: PackedVector3Array, reach: PackedFloat32Array, tall: PackedFloat32Array) -> bool:
	var d := mids[i] - mids[j]
	return Vector2(d.x, d.z).length() < reach[i] + reach[j] and absf(d.y) < tall[i] + tall[j]


## WHERE A LUMP TOUCHING LUMPS [param c] COMES TO REST (half sizes summed: [param A] across,
## [param B] up) - three of them, or two and a vessel's wall [param wall] meters out from the
## heap's middle - above them: Newton's method from above, then the contact forces solved for (a
## lump's pushing straight off its surface, the wall's straight back in) and every one required to
## carry a share. A rest under [param b] is where it falls through to the floor, and the floor
## there is returned for the caller to judge. Null when nothing holds it there.
static func _pocket(c: Array, A: Array, B: Array, b: float, wall := 0.0) -> Variant:
	var lumps := c.size()
	var p: Vector3 = Vector3.ZERO
	for m in lumps:
		p += c[m] / float(lumps)
	if wall > 0.0:
		var out := Vector2(p.x, p.z)
		out = (out if out.length() > 1e-6 else Vector2(c[0].x, c[0].z)).normalized() * wall
		p = Vector3(out.x, p.y, out.y)
	for m in lumps:
		p.y = maxf(p.y, c[m].y + B[m])
	var g := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var f := Vector3.ZERO
	for it in 24:
		for m in lumps:
			var d: Vector3 = p - c[m]
			var a2: float = A[m] * A[m]
			var b2: float = B[m] * B[m]
			f[m] = (d.x * d.x + d.z * d.z) / a2 + d.y * d.y / b2 - 1.0
			g[m] = Vector3(2.0 * d.x / a2, 2.0 * d.y / b2, 2.0 * d.z / a2)
		if wall > 0.0:
			f[2] = (p.x * p.x + p.z * p.z) / (wall * wall) - 1.0
			g[2] = Vector3(2.0 * p.x, 0.0, 2.0 * p.z) / (wall * wall)
		if absf(f.x) + absf(f.y) + absf(f.z) < 1e-5:
			break
		# the gradients as COLUMNS: transposed, they are the rows of the Jacobian
		var jt := Basis(g[0], g[1], g[2])
		if absf(jt.determinant()) < 1e-9:
			return null
		var step := jt.transposed().inverse() * -f
		if step.length() > A[0] + A[1]:
			return null
		p += step
	if absf(f.x) + absf(f.y) + absf(f.z) >= 1e-5:
		return null
	if p.y < b:
		return Vector3(p.x, b, p.z)
	# HELD FROM BELOW: a pocket under the side of a higher lump is a wedge, and a lump dropped on
	# the heap from above does not get in under another
	for m in lumps:
		if p.y <= c[m].y:
			return null
	# the forces: off each lump along its normal, and the wall's back toward the middle
	var held := Basis(g[0], g[1], -g[2] if wall > 0.0 else g[2])
	if absf(held.determinant()) < 1e-9:
		return null
	var w := held.inverse() * Vector3.UP
	if minf(w.x, minf(w.y, w.z)) <= 0.05 * (w.x + w.y + w.z):
		return null
	return p


## How far a part reaches from its own origin seen from above (`reach`, its farthest; `girth`, the
## mean of its half-width and half-depth), and how low and high it goes - turned by [param own] as
## each copy is before it is laid out.
static func _bounds(geos: Array, own: Transform3D) -> Dictionary:
	var reach := 0.0
	var hx := 0.0
	var hz := 0.0
	var low := INF
	var high := -INF
	for e in geos:
		for q in ((e as Dictionary)["geo"] as Tris).v:
			var w := own.basis * q
			reach = maxf(reach, Vector2(w.x, w.z).length())
			hx = maxf(hx, absf(w.x))
			hz = maxf(hz, absf(w.z))
			low = minf(low, w.y)
			high = maxf(high, w.y)
	if low > high:
		return {"reach": 0.01, "girth": 0.01, "low": 0.0, "high": 0.01}
	return {"reach": maxf(reach, 0.0005), "girth": maxf((hx + hz) * 0.5, 0.0005), "low": low, "high": maxf(high, low + 0.0005)}


## The part's geometry, in its own space (meters): `[{geo, material?}]` - a cluster's rock is a
## second entry when it has a material of its own - reshaped by its WARP, all of it as one.
static func _geometry(p: Dictionary, rng: RandomNumberGenerator) -> Array:
	var geos := _shaped(p, rng)
	var w: Dictionary = p.get("warp", {})
	if not w.is_empty() and not geos.is_empty():
		_warp(geos, w, rng.randi())
	return geos


static func _shaped(p: Dictionary, rng: RandomNumberGenerator) -> Array:
	match String(p["shape"]):
		"lathe":
			return [{"geo": _lathe(p, rng)}]
		"box":
			return [{"geo": _box(p)}]
		"ball":
			return [{"geo": _ball(p["size"] as Vector3, float(p["lumpy"]), bool(p["facets"]), rng)}]
		"point":
			var g := Tris.new()
			_crystal(g, float(p["radius"]) * 0.01, float(p["length"]) * 0.01, float(p["tip"]) * 0.01,
				int(p["sides"]), Transform3D.IDENTITY, rng)
			g.measure()
			return [{"geo": g}]
		"cluster":
			return _cluster(p, rng)
		"geode":
			return _geode(p, rng)
		"ring":
			return [{"geo": _ring(float(p["radius"]) * 0.01, float(p["thickness"]) * 0.01, float(p["arc"]))}]
		"tube":
			return [{"geo": _tube(p)}]
		"sheet":
			# placed by its middle, as a leaf laid down is
			var g := Tris.new()
			var mid := Vector3.ZERO if not (p.get("points", []) as Array).is_empty() else Vector3(0.0, 0.0, -float((p["size"] as Vector2).y) * 0.005)
			_sheet(g, p, Transform3D(Basis(), mid))
			g.measure()
			return [{"geo": g}]
		"bloom":
			return [{"geo": _bloom(p, rng)}]
		"extrude":
			return [{"geo": _extrude(p)}]
		"loft":
			return [{"geo": _loft(p)}]
		"coil":
			return [{"geo": _coil(p)}]
		"strand":
			return _strand(p, rng)
		"bone":
			return [{"geo": _bone(p, rng)}]
		"skull":
			return _skull(p, rng)
		"sculpt":
			return [{"geo": _sculpt(p)}]
	return []


## A WARP on a part's geometry [param geos], all of it as one: every point moved ([method
## _warped]), its normal turned as the surface round it was (by the inverse transpose of the
## warp's own slope there, measured), and the part's top and wicks moved with it. Heights are
## measured from the part's own bottom, and the middle it narrows, twists and leans about is the
## middle of what it covers seen from above. [param salt] seeds the wobble.
static func _warp(geos: Array, w: Dictionary, salt: int) -> void:
	var box := AABB()
	var first := true
	for e in geos:
		for q in ((e as Dictionary)["geo"] as Tris).v:
			box = AABB(q, Vector3.ZERO) if first else box.expand(q)
			first = false
	if first:
		return
	var noise: FastNoiseLite = null
	var ext := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if float(w.get("wobble", 0.0)) > 0.0:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = salt
		noise.frequency = 1.6 / maxf(ext, 0.005)
	var frame := {"mid": Vector3(box.get_center().x, box.position.y, box.get_center().z), "h": maxf(box.size.y, 0.0005),
		"ext": ext, "noise": noise}
	var done := {}
	var e := 0.0001
	for g in geos:
		var t: Tris = (g as Dictionary)["geo"]
		for i in t.v.size():
			var q := t.v[i]
			if not done.has(q):
				# the slope of the warp here, from a step either way along each axis
				var jx := (_warped(q + Vector3(e, 0, 0), w, frame) - _warped(q - Vector3(e, 0, 0), w, frame)) / (2.0 * e)
				var jy := (_warped(q + Vector3(0, e, 0), w, frame) - _warped(q - Vector3(0, e, 0), w, frame)) / (2.0 * e)
				var jz := (_warped(q + Vector3(0, 0, e), w, frame) - _warped(q - Vector3(0, 0, e), w, frame)) / (2.0 * e)
				var jac := Basis(jx, jy, jz)
				done[q] = [_warped(q, w, frame), jac.inverse().transposed() if absf(jac.determinant()) > 1e-9 else Basis()]
			var hit: Array = done[q]
			t.v[i] = hit[0]
			var nn: Vector3 = (hit[1] as Basis) * t.n[i]
			if nn.length() > 1e-9:
				t.n[i] = nn.normalized()
		t.top = _warped(t.top, w, frame)
		for k in t.wicks.size():
			t.wicks[k] = _warped(t.wicks[k], w, frame)


## Where point [param q] goes under warp [param w], in this order: scaled about the middle of the
## part's base, narrowed (or widened) toward its top, twisted about its middle, its top leaned over,
## bent along its height toward `bend_to` as a rod is bent round a drum (each slice turned square to
## the curve, so its thickness is kept), and wobbled by a smooth field that depends only on where the
## point was (so seams and crisp corners move together and never open).
static func _warped(q: Vector3, w: Dictionary, frame: Dictionary) -> Vector3:
	var mid: Vector3 = frame["mid"]
	var h: float = frame["h"]
	var sc: Vector3 = w.get("scale", Vector3.ONE)
	var p := mid + (q - mid) * sc
	var f := (q.y - mid.y) / h
	var taper := float(w.get("taper", 0.0))
	if taper != 0.0:
		var k := 1.0 - taper * f
		p = Vector3(mid.x + (p.x - mid.x) * k, p.y, mid.z + (p.z - mid.z) * k)
	var twist := deg_to_rad(float(w.get("twist", 0.0))) * f
	if twist != 0.0:
		var r := Vector2(p.x - mid.x, p.z - mid.z).rotated(twist)
		p = Vector3(mid.x + r.x, p.y, mid.z + r.y)
	var lean: Vector2 = w.get("lean", Vector2.ZERO)
	p += Vector3(lean.x, 0.0, lean.y) * 0.01 * f
	var bend := deg_to_rad(float(w.get("bend", 0.0)))
	if absf(bend) > 1e-4:
		# toward bend_to: its own x there, bent round a center that far out, back again
		var to := deg_to_rad(float(w.get("bend_to", 0.0)))
		var d := Vector2(p.x - mid.x, p.z - mid.z)
		var lx := d.x * cos(to) + d.y * sin(to)
		var lz := -d.x * sin(to) + d.y * cos(to)
		var R := h * sc.y / bend
		var phi := (p.y - mid.y) / R
		var bx := R - (R - lx) * cos(phi)
		var by := (R - lx) * sin(phi)
		p = Vector3(mid.x + bx * cos(to) - lz * sin(to), mid.y + by, mid.z + bx * sin(to) + lz * cos(to))
	var noise: FastNoiseLite = frame["noise"]
	if noise != null:
		var amp := float(w.get("wobble", 0.0)) * 0.05 * float(frame["ext"])
		p += Vector3(noise.get_noise_3dv(q), noise.get_noise_3dv(q + Vector3(31.4, 0.0, 0.0)),
			noise.get_noise_3dv(q + Vector3(0.0, 0.0, 47.3))) * amp
	return p


# --- the shapes -------------------------------------------------------------------------------

## A TURNED SOLID. The profile is joined straight (or curved through, `smooth`), closed at the axis
## top and bottom, and split into runs where it turns a corner, so a rim or a foot stays crisp and a
## belly stays smooth. Each ring of it can then be displaced as it goes round: LOBES bulge it,
## TWIST turns it with height, and wax DRIPS run down from the top - which is melted into a pool
## when the part carries a wick.
static func _lathe(p: Dictionary, rng: RandomNumberGenerator) -> Tris:
	var pts: Array = []
	for q in (p["profile"] as Array):
		pts.append((q as Vector2) * 0.01)
	var rounds := _rounds_m(p, pts.size())
	var smooth := bool(p.get("smooth", false))
	# A FLAT BASE AND A FLAT TOP STAY FLAT in a smooth profile: curved through, a teapot's base sagged
	# below the cloth and its top domed up, and the pot came out a ball
	if smooth and pts.size() >= 3:
		var m := pts.size()
		if rounds[1] < 0.0 and (pts[0] as Vector2).x <= 0.0002 and absf((pts[1] as Vector2).y - (pts[0] as Vector2).y) < 0.0001:
			rounds[1] = 0.0
		if rounds[m - 2] < 0.0 and (pts[m - 1] as Vector2).x <= 0.0002 and absf((pts[m - 2] as Vector2).y - (pts[m - 1] as Vector2).y) < 0.0001:
			rounds[m - 2] = 0.0
	if pts.size() >= 3:
		pts = _curve(pts, rounds, smooth, 6)["pts"]
		for i in pts.size():
			pts[i] = Vector2(maxf((pts[i] as Vector2).x, 0.0), (pts[i] as Vector2).y)
	if (pts[0] as Vector2).x > 0.0002:
		pts.insert(0, Vector2(0.0, (pts[0] as Vector2).y))
	if (pts[-1] as Vector2).x > 0.0002:
		pts.append(Vector2(0.0, (pts[-1] as Vector2).y))
	# THE POOL a burning candle melts round its wicks, and where its rim is
	var rim := Vector2.ZERO
	if bool(p.get("wick", false)):
		if pts.size() >= 3 and (pts[-2] as Vector2).x >= 0.002 and absf((pts[-2] as Vector2).y - (pts[-1] as Vector2).y) <= 0.002:
			rim = pts[-2]
		pts = _pool(pts)
	var twist := deg_to_rad(float(p.get("twist", 0.0)))
	var drips := float(p.get("drips", 0.0))
	if absf(twist) > 0.01 or drips > 0.0 or _fine(p):
		pts = _subdivide(pts, 0.004)
	var y0 := INF
	var y1 := -INF
	var rmax := 0.0
	for q in pts:
		y0 = minf(y0, (q as Vector2).y)
		y1 = maxf(y1, (q as Vector2).y)
		rmax = maxf(rmax, (q as Vector2).x)
	var height := maxf(y1 - y0, 0.0005)
	var sides := int(p.get("sides", 0))
	var lobes := int(p.get("lobes", 0))
	var depth := float(p.get("lobe_depth", 0.15))
	var around := sides if sides >= 3 else clampi(roundi(rmax * 100.0 * 6.0 + 16.0), 24, 72)
	if lobes > 0:
		around = maxi(around, mini(lobes * 8, 160))
	# the drips: where round the top each runs, how wide, how far down, how proud
	var rtop := 0.0
	for q in pts:
		if (q as Vector2).y > y1 - height * 0.15:
			rtop = maxf(rtop, (q as Vector2).x)
	var drops: Array = []
	if drips > 0.0:
		for i in roundi(lerpf(2.0, 10.0, drips)):
			drops.append([rng.randf() * TAU, rng.randf_range(0.07, 0.17), rng.randf_range(0.12, 0.55) * (0.4 + 0.6 * drips),
				rtop * rng.randf_range(0.08, 0.15)])
	# arclength along the profile, for V
	var arc := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		arc.append(arc[i - 1] + (pts[i] as Vector2).distance_to(pts[i - 1]))
	var total := maxf(arc[arc.size() - 1], 0.0001)
	# RUNS: split where the profile turns a corner
	var runs: Array = []
	var start := 0
	for i in range(1, pts.size() - 1):
		var a: Vector2 = (pts[i] as Vector2) - (pts[i - 1] as Vector2)
		var b: Vector2 = (pts[i + 1] as Vector2) - (pts[i] as Vector2)
		if a.length() < 1e-6 or b.length() < 1e-6:
			continue
		if absf(a.angle_to(b)) > deg_to_rad(35.0):
			runs.append([start, i])
			start = i
	runs.append([start, pts.size() - 1])
	var g := Tris.new()
	var surf := func(th: float, q: Vector2, n2: Vector2) -> Vector3:
		var r := q.x
		if lobes > 0:
			r *= 1.0 - depth * 0.5 * (1.0 - cos(float(lobes) * th))
		if not drops.is_empty() and absf(n2.x) > 0.5 and r > 0.0001:
			r += _drip(drops, th, (q.y - y0) / height)
		var tt := th + twist * (q.y - y0) / height
		return Vector3(cos(tt) * r, q.y, sin(tt) * r)
	for run in runs:
		var a := int(run[0])
		var b := int(run[1])
		if b <= a:
			continue
		# each point's outward normal in the profile's plane, within its run
		var n2s: Array = []
		for j in range(a, b + 1):
			var sum := Vector2.ZERO
			if j > a:
				var d: Vector2 = (pts[j] as Vector2) - (pts[j - 1] as Vector2)
				sum += Vector2(d.y, -d.x).normalized()
			if j < b:
				var d2: Vector2 = (pts[j + 1] as Vector2) - (pts[j] as Vector2)
				sum += Vector2(d2.y, -d2.x).normalized()
			n2s.append(sum.normalized() if sum.length() > 1e-6 else Vector2(1, 0))
		var rows: Array = []      # per profile point: [positions, normals] round the circle
		for j in range(a, b + 1):
			var q: Vector2 = pts[j]
			var n2: Vector2 = n2s[j - a]
			var ps := PackedVector3Array()
			var ns := PackedVector3Array()
			for i in around + 1:
				var th := TAU * float(i % around) / float(around)
				var pos: Vector3 = surf.call(th, q, n2)
				ps.append(pos)
				var tt := th + twist * (q.y - y0) / height
				var n0 := Vector3(cos(tt) * n2.x, n2.y, sin(tt) * n2.x)
				var nrm := n0
				if (lobes > 0 or not drops.is_empty() or absf(twist) > 0.01) and q.x > 0.0005 and sides < 3:
					var e := 0.002
					var dth: Vector3 = (surf.call(th + e, q, n2) as Vector3) - (surf.call(th - e, q, n2) as Vector3)
					var qa: Vector2 = pts[maxi(j - 1, a)]
					var qb: Vector2 = pts[mini(j + 1, b)]
					var ds: Vector3 = (surf.call(th, qb, n2) as Vector3) - (surf.call(th, qa, n2) as Vector3)
					var c := ds.cross(dth)
					if c.length() > 1e-12:
						nrm = c.normalized()
						if nrm.dot(n0) < 0.0:
							nrm = -nrm
				ns.append(nrm)
			rows.append([ps, ns])
		for j in range(a, b):
			var r0: Array = rows[j - a]
			var r1: Array = rows[j - a + 1]
			var v0 := arc[j] / total
			var v1 := arc[j + 1] / total
			var h0 := ((pts[j] as Vector2).y - y0) / height
			var h1 := ((pts[j + 1] as Vector2).y - y0) / height
			for i in around:
				var p00: Vector3 = (r0[0] as PackedVector3Array)[i]
				var p10: Vector3 = (r0[0] as PackedVector3Array)[i + 1]
				var p01: Vector3 = (r1[0] as PackedVector3Array)[i]
				var p11: Vector3 = (r1[0] as PackedVector3Array)[i + 1]
				var n00: Vector3 = (r0[1] as PackedVector3Array)[i]
				var n10: Vector3 = (r0[1] as PackedVector3Array)[i + 1]
				var n01: Vector3 = (r1[1] as PackedVector3Array)[i]
				var n11: Vector3 = (r1[1] as PackedVector3Array)[i + 1]
				if sides >= 3:
					# FLAT FACES: the face's own normal, kept facing out
					var mid := (n00 + n10 + n01 + n11)
					var fn := (p10 - p00).cross(p01 - p00)
					if fn.length() < 1e-12:
						fn = (p11 - p01).cross(p10 - p11)
					fn = fn.normalized() if fn.length() > 1e-12 else mid.normalized()
					if fn.dot(mid) < 0.0:
						fn = -fn
					n00 = fn
					n10 = fn
					n01 = fn
					n11 = fn
				var u0 := float(i) / float(around)
				var u1 := float(i + 1) / float(around)
				g.quad(p00, p10, p11, p01, n00, n10, n11, n01, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1),
					h0, h0, h1, h1)
	g.girth = TAU * rmax * 100.0
	g.height = height * 100.0
	g.top = Vector3(0.0, (pts[-1] as Vector2).y, 0.0)
	# THE WICKS stand on the pool, as deep in it as it is where each stands (one in the middle is at
	# its bottom); a top with no pool has them on its top
	if bool(p.get("wick", false)):
		var R := rim.x if rim.x > 0.0 else maxf(rtop, 0.004)
		var sink := minf(0.005, rim.x * 0.3) if rim.x > 0.0 else 0.0
		var top_y := rim.y if rim.x > 0.0 else (pts[-1] as Vector2).y
		for sp in _wick_spots(p, R):
			var f := minf((sp as Vector2).length() / maxf(R, 1e-6), 1.0)
			g.wicks.append(Vector3((sp as Vector2).x, top_y - sink * (1.0 - f * f), (sp as Vector2).y))
	return g


## How far drip [param drops] push the wall out at angle [param th], [param yf] up the part (0..1):
## each a narrow ridge from the top down to its own length, ending in a bead.
static func _drip(drops: Array, th: float, yf: float) -> float:
	var out := 0.0
	for d in drops:
		var dd: Array = d
		var end := 1.0 - float(dd[2])
		if yf < end - 0.04:
			continue
		var dt := wrapf(th - float(dd[0]), -PI, PI)
		var across := exp(-pow(dt / float(dd[1]), 2.0))
		if across < 0.01:
			continue
		var s := (yf - end) / maxf(float(dd[2]), 0.01)
		var along := smoothstep(-0.08, 0.06, s) * (1.0 + 0.9 * exp(-pow(s / 0.07, 2.0)))
		out += float(dd[3]) * across * along
	return out


## A burned candle's top: the flat top of the wax melted into a shallow pool round the wick.
static func _pool(pts: Array) -> Array:
	if pts.size() < 3:
		return pts
	var last: Vector2 = pts[-1]
	var rim: Vector2 = pts[-2]
	if rim.x < 0.002 or absf(rim.y - last.y) > 0.002:
		return pts
	var depth := minf(0.005, rim.x * 0.3)
	var out := pts.slice(0, pts.size() - 1)
	for k in range(1, 7):
		var f := float(k) / 6.0
		var r := rim.x * (1.0 - f)
		out.append(Vector2(r, rim.y - depth * (1.0 - pow(r / rim.x, 2.0))))
	return out


## Points along a profile no further apart than [param step].
static func _subdivide(pts: Array, step: float) -> Array:
	var out: Array = [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## A part's corner roundings in meters, one per point of its profile or path (-1 where none was
## written).
static func _rounds_m(p: Dictionary, n: int) -> PackedFloat32Array:
	var src: PackedFloat32Array = p.get("rounds", PackedFloat32Array())
	var out := PackedFloat32Array()
	for i in n:
		var r := src[i] if i < src.size() else -1.0
		out.append(r * 0.01 if r >= 0.0 else -1.0)
	return out


## A LINE THROUGH POINTS (Vector2 or Vector3), as a profile or a path is drawn: `pts`, each one's
## place among the points it was drawn from (`src`, fractional between them, for anything given per
## point - a tube's radii) and whether it is a `corner`. A point with a rounding ([param rounds],
## the same units, -1 for none) has its corner cut by an arc that far round; one rounded 0 is a crisp
## corner. The rest are curved through when [param smooth] - a centripetal Catmull-Rom, which never
## loops or overshoots between points far apart and close together as the uniform one did - and
## are crisp corners when not. [param steps] is how many pieces the longest span is cut into.
static func _curve(pts: Array, rounds: PackedFloat32Array, smooth: bool, steps := 8) -> Dictionary:
	var P: Array = []
	var R := PackedFloat32Array()
	var I := PackedFloat32Array()
	for i in pts.size():
		if not P.is_empty() and (pts[i] - P[-1]).length() < 1e-6:
			continue
		P.append(pts[i])
		R.append(rounds[i] if i < rounds.size() else -1.0)
		I.append(float(i))
	var n := P.size()
	var ctl: Array = []
	var src := PackedFloat32Array()
	var mark := PackedByteArray()
	for i in n:
		var r := R[i]
		if i > 0 and i < n - 1 and r > 0.0:
			var la: float = (P[i - 1] - P[i]).length()
			var lb: float = (P[i + 1] - P[i]).length()
			var u: Variant = (P[i - 1] - P[i]) / la
			var v: Variant = (P[i + 1] - P[i]) / lb
			var half := acos(clampf(u.dot(v), -1.0, 1.0)) * 0.5
			if half > 0.02 and half < PI * 0.5 - 0.02:
				# THE ROUNDING: from where an arc of radius r would leave one side to where it meets the
				# other, never more than half of either side
				var d := minf(r / tan(half), 0.5 * minf(la, lb))
				var a1: Variant = P[i] + u * d
				var b1: Variant = P[i] + v * d
				var sa := I[i] - d / la * (I[i] - I[i - 1])
				var sb := I[i] + d / lb * (I[i + 1] - I[i])
				for k in 7:
					var t := float(k) / 6.0
					ctl.append(a1 * (1.0 - t) * (1.0 - t) + P[i] * 2.0 * t * (1.0 - t) + b1 * t * t)
					src.append(lerpf(sa, sb, t))
					mark.append(0)
				continue
		ctl.append(P[i])
		src.append(I[i])
		mark.append(1 if i > 0 and i < n - 1 and (r == 0.0 or (r < 0.0 and not smooth)) else 0)
	var m := ctl.size()
	if not smooth or m < 3:
		return {"pts": ctl, "src": src, "corner": mark}
	var mean := 0.0
	for i in m - 1:
		mean += (ctl[i + 1] - ctl[i]).length()
	mean = maxf(mean / float(m - 1), 1e-6)
	var out: Array = []
	var os := PackedFloat32Array()
	var oc := PackedByteArray()
	var a := 0
	while a < m - 1:
		# a RUN, from corner to corner, curved through; its ends continue straight on past themselves
		var b := a + 1
		while b < m - 1 and mark[b] == 0:
			b += 1
		for i in range(a, b):
			var p0: Variant = ctl[i - 1] if i > a else ctl[a] * 2.0 - ctl[a + 1]
			var p3: Variant = ctl[i + 2] if i + 1 < b else ctl[b] * 2.0 - ctl[b - 1]
			var k_n := clampi(ceili(float(steps) * (ctl[i + 1] - ctl[i]).length() / mean), 1, steps)
			for k in k_n:
				var t := float(k) / float(k_n)
				out.append(_ccr(p0, ctl[i], ctl[i + 1], p3, t))
				os.append(lerpf(src[i], src[i + 1], t))
				oc.append(mark[i] if k == 0 else 0)
		a = b
	out.append(ctl[m - 1])
	os.append(src[m - 1])
	oc.append(0)
	return {"pts": out, "src": os, "corner": oc}


## A point [param t] (0..1) of the way from [param p1] to [param p2] on a centripetal Catmull-Rom
## curve (Barry and Goldman's form).
static func _ccr(p0: Variant, p1: Variant, p2: Variant, p3: Variant, t: float) -> Variant:
	var t1: float = sqrt(maxf((p1 - p0).length(), 1e-6))
	var t2: float = t1 + sqrt(maxf((p2 - p1).length(), 1e-6))
	var t3: float = t2 + sqrt(maxf((p3 - p2).length(), 1e-6))
	var tt := lerpf(t1, t2, t)
	var a1: Variant = p0 * ((t1 - tt) / t1) + p1 * (tt / t1)
	var a2: Variant = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3: Variant = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1: Variant = a1 * ((t2 - tt) / t2) + a2 * (tt / t2)
	var b2: Variant = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


## A BLOCK WITH ROUNDED EDGES, its base at y = 0: a cube's six faces, each a grid that crowds toward
## its edges, pushed onto the rounded shape (a point's nearest point on the inner box, plus the
## radius toward it), then narrowed toward the top by the taper.
static func _box(p: Dictionary) -> Tris:
	var s: Vector3 = (p["size"] as Vector3) * 0.01
	var h := s * 0.5
	var r := minf(float(p["round"]) * 0.01, minf(h.x, minf(h.y, h.z)))
	var taper := float(p["taper"])
	var g := Tris.new()
	var fine := _fine(p)
	var axis_samples := func(half: float) -> PackedFloat32Array:
		var out := PackedFloat32Array([-half])
		if r > 0.0001:
			for k in [0.15, 0.4, 0.7]:
				out.append(-half + r * (1.0 - cos(float(k) * PI * 0.5)) / (1.0 - cos(PI * 0.5)) * 1.0)
			out.append(-half + r)
		# a warped block is cut across its flat faces too, so it can bend
		var flat := 2.0 * (half - r)
		var cuts := ceili(flat / WARP_STEP) if fine and flat > WARP_STEP else 1
		for k in range(1, cuts):
			out.append(-half + r + flat * float(k) / float(cuts))
		if r > 0.0001:
			out.append(half - r)
			for k in [0.7, 0.4, 0.15]:
				out.append(half - r * (1.0 - cos(float(k) * PI * 0.5)))
		out.append(half)
		return out
	var inner := h - Vector3(r, r, r)
	var place := func(q: Vector3) -> Array:
		var c := q.clamp(-inner, inner)
		var d := q - c
		var nrm := d.normalized() if d.length() > 1e-9 else Vector3.ZERO
		var pos := c + nrm * r if d.length() > 1e-9 else q
		var yf := (pos.y + h.y) / maxf(s.y, 1e-6)
		var k := 1.0 - taper * yf
		pos = Vector3(pos.x * k, pos.y + h.y, pos.z * k)
		return [pos, nrm]
	# each face: its normal, and the two axes it spans
	var faces := [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	for f in faces:
		var fn: Vector3 = f[0]
		var ua: Vector3 = f[1]
		var va: Vector3 = f[2]
		var us: PackedFloat32Array = axis_samples.call(absf(ua.dot(h)))
		var vs: PackedFloat32Array = axis_samples.call(absf(va.dot(h)))
		var grid: Array = []
		for j in vs.size():
			var row: Array = []
			for i in us.size():
				var q := fn * absf(fn.dot(h)) + ua * us[i] + va * vs[j]
				row.append(place.call(q))
			grid.append(row)
		for j in vs.size() - 1:
			for i in us.size() - 1:
				var c00: Array = grid[j][i]
				var c10: Array = grid[j][i + 1]
				var c11: Array = grid[j + 1][i + 1]
				var c01: Array = grid[j + 1][i]
				var n00: Vector3 = c00[1] if (c00[1] as Vector3) != Vector3.ZERO else fn
				var n10: Vector3 = c10[1] if (c10[1] as Vector3) != Vector3.ZERO else fn
				var n11: Vector3 = c11[1] if (c11[1] as Vector3) != Vector3.ZERO else fn
				var n01: Vector3 = c01[1] if (c01[1] as Vector3) != Vector3.ZERO else fn
				var uv := func(ii: int, jj: int) -> Vector2:
					return Vector2((us[ii] + absf(ua.dot(h))) / maxf(2.0 * absf(ua.dot(h)), 1e-6),
						(vs[jj] + absf(va.dot(h))) / maxf(2.0 * absf(va.dot(h)), 1e-6))
				var p00: Vector3 = c00[0]
				var p10: Vector3 = c10[0]
				var p11: Vector3 = c11[0]
				var p01: Vector3 = c01[0]
				g.quad(p00, p10, p11, p01, n00, n10, n11, n01, uv.call(i, j), uv.call(i + 1, j), uv.call(i + 1, j + 1),
					uv.call(i, j + 1), p00.y / s.y, p10.y / s.y, p11.y / s.y, p01.y / s.y)
	g.girth = (s.x + s.z) * 100.0
	g.height = s.y * 100.0
	g.top = Vector3(0.0, s.y, 0.0)
	return g


## A SPHERE stretched to [param size] (centimeters), resting on y = 0: smooth, LUMPY (pushed in and
## out by noise, as a stone or a fruit is) or FACETED (a coarse, jittered, flat-faced one, as a
## rough stone is).
static func _ball(size: Vector3, lumpy: float, facets: bool, rng: RandomNumberGenerator) -> Tris:
	var s := size * 0.01
	var rings := 6 if facets else 18
	var segs := 8 if facets else 32
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = rng.randi()
	noise.frequency = 1.6
	var jit: Array = []
	for j in rings + 1:
		var row: Array = []
		for i in segs + 1:
			row.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (0.12 if facets else 0.0))
		jit.append(row)
	var grid: Array = []
	for j in rings + 1:
		var row: Array = []
		var phi := PI * float(j) / float(rings)
		for i in segs + 1:
			var th := TAU * float(i % segs) / float(segs)
			var d := Vector3(sin(phi) * cos(th), -cos(phi), sin(phi) * sin(th))
			if facets and j > 0 and j < rings:
				d = (d + (jit[j][i % segs] as Vector3)).normalized()
			# a few broad lumps, as a tumbled stone or a fruit has, and a little unevenness over them: lumps
			# as fine as the second alone crimped the edge of a small stone like a dumpling's
			var k := 1.0 + lumpy * (0.42 * noise.get_noise_3dv(d * 0.45) + 0.05 * noise.get_noise_3dv(d * 1.6 + Vector3(5.0, 0.0, 0.0)))
			row.append(Vector3(d.x * s.x * 0.5, d.y * s.y * 0.5, d.z * s.z * 0.5) * k)
		grid.append(row)
	# resting on its lowest point
	var low := INF
	for row in grid:
		for q in row:
			low = minf(low, (q as Vector3).y)
	for row in grid:
		for i in (row as Array).size():
			row[i] = (row[i] as Vector3) - Vector3(0.0, low, 0.0)
	var g := Tris.new()
	var mid := Vector3(0.0, -low, 0.0)
	var hgt := maxf(s.y * 1.3, 0.0001)
	for j in rings:
		for i in segs:
			var p00: Vector3 = grid[j][i]
			var p10: Vector3 = grid[j][i + 1]
			var p11: Vector3 = grid[j + 1][i + 1]
			var p01: Vector3 = grid[j + 1][i]
			var ns: Array = []
			for q in [[j, i], [j, i + 1], [j + 1, i + 1], [j + 1, i]]:
				ns.append(_grid_normal(grid, int(q[0]), int(q[1]), segs, mid))
			if facets:
				var fn := ((p10 - p00).cross(p01 - p00) + (p11 - p01).cross(p10 - p11)).normalized()
				if fn.dot((p00 + p11) * 0.5 - mid) < 0.0:
					fn = -fn
				ns = [fn, fn, fn, fn]
			var u0 := float(i) / float(segs)
			var u1 := float(i + 1) / float(segs)
			var v0 := float(j) / float(rings)
			var v1 := float(j + 1) / float(rings)
			g.quad(p00, p10, p11, p01, ns[0], ns[1], ns[2], ns[3], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1),
				p00.y / hgt, p10.y / hgt, p11.y / hgt, p01.y / hgt)
	g.girth = PI * (s.x + s.z) * 50.0
	g.height = s.y * 100.0
	g.top = Vector3(0.0, s.y, 0.0)
	return g


## A grid surface's normal at row [param j], column [param i] (columns wrap), facing away from
## [param mid].
static func _grid_normal(grid: Array, j: int, i: int, segs: int, mid: Vector3) -> Vector3:
	var rows := grid.size()
	var p: Vector3 = grid[j][i]
	var a: Vector3 = grid[j][(i + 1) % segs] - grid[j][(i - 1 + segs) % segs]
	var b: Vector3 = grid[mini(j + 1, rows - 1)][i] - grid[maxi(j - 1, 0)][i]
	var n := a.cross(b)
	if n.length() < 1e-12:
		n = p - mid
	n = n.normalized()
	if n.dot(p - mid) < 0.0:
		n = -n
	return n


## ONE CRYSTAL POINT into [param g]: a prism of [param sides], each face a little off the last,
## with a pyramidal termination whose apex is a little off center, placed by [param xf].
static func _crystal(g: Tris, radius: float, length: float, tip: float, sides: int, xf: Transform3D,
		rng: RandomNumberGenerator) -> void:
	var ring: Array = []
	var off := rng.randf() * TAU
	for i in sides:
		var a := off + TAU * float(i) / float(sides)
		var r := radius * rng.randf_range(0.88, 1.12)
		ring.append(Vector2(cos(a), sin(a)) * r)
	var apex := Vector3(rng.randf_range(-0.15, 0.15) * radius, length + tip, rng.randf_range(-0.15, 0.15) * radius)
	var top_y := length
	var total := maxf(length + tip, 0.0001)
	var axis_mid := xf * Vector3(0.0, total * 0.5, 0.0)
	for i in sides:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % sides]
		var a0 := xf * Vector3(a.x, 0.0, a.y)
		var b0 := xf * Vector3(b.x, 0.0, b.y)
		var a1 := xf * Vector3(a.x, top_y, a.y)
		var b1 := xf * Vector3(b.x, top_y, b.y)
		var ap := xf * apex
		var fn := _face_n(a0, b0, a1, axis_mid)
		var u0 := float(i) / float(sides)
		var u1 := float(i + 1) / float(sides)
		g.quad(a0, b0, b1, a1, fn, fn, fn, fn, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.7), Vector2(u0, 0.7),
			0.0, 0.0, top_y / total, top_y / total)
		var tn := _face_n(a1, b1, ap, axis_mid)
		g.tri(a1, b1, ap, tn, tn, tn, Vector2(u0, 0.7), Vector2(u1, 0.7), Vector2((u0 + u1) * 0.5, 1.0),
			Vector2(top_y / total, 0.0), Vector2(top_y / total, 0.0), Vector2(1.0, 0.0))
		var bn := (xf.basis * Vector3.DOWN).normalized()
		g.tri(xf * Vector3.ZERO, b0, a0, bn, bn, bn, Vector2(0.5, 0.0), Vector2(u1, 0.0), Vector2(u0, 0.0),
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


static func _face_n(a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	n = n.normalized() if n.length() > 1e-12 else Vector3.UP
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	return n


## A CLUSTER: points growing out of a rough rock, the middle ones longest and most upright, the
## outer ones shorter and leaning out.
static func _cluster(p: Dictionary, rng: RandomNumberGenerator) -> Array:
	var R := float(p["radius"]) * 0.01
	var rock := _ball(Vector3(R * 200.0, R * 55.0, R * 170.0), 0.45, false, rng)
	var pts := Tris.new()
	var n := int(p["count"])
	var lens: Vector2 = p["length"]
	var spread := deg_to_rad(float(p["spread"]))
	for i in n:
		var rad := R * 0.62 * sqrt(rng.randf()) * (0.2 if i == 0 else 1.0)
		var ang := rng.randf() * TAU
		var out01 := rad / maxf(R * 0.62, 0.0001)
		var length := lerpf(lens.y, lens.x, clampf(out01 * 0.75 + rng.randf() * 0.35, 0.0, 1.0)) * 0.01
		var lean := spread * out01 + rng.randf_range(-0.12, 0.12)
		# out of the rock's own surface (an ellipsoid R x 0.55 R x 0.85 R resting on the cloth), a little sunk
		var e := sqrt(maxf(0.0, 1.0 - pow(cos(ang) * rad / R, 2.0) - pow(sin(ang) * rad / (R * 0.85), 2.0)))
		var base := Vector3(cos(ang) * rad, R * 0.275 * (1.0 + e) - R * 0.06, sin(ang) * rad)
		var axis := Vector3(-sin(ang), 0.0, cos(ang))
		var xf := Transform3D(Basis(axis, -lean) if axis.length() > 0.0 else Basis(), base)
		var thick := length * float(p["thickness"]) * rng.randf_range(0.8, 1.2)
		_crystal(pts, thick, length * 0.72, length * 0.28, 6, xf, rng)
	pts.measure()
	var base_mat := String(p.get("base", ""))
	if base_mat.is_empty():
		pts.append(rock)
		pts.measure()
		return [{"geo": pts}]
	return [{"geo": pts}, {"geo": rock, "material": base_mat}]


## A GEODE broken open, lying open side up: the lower half of a rough round rock, its cut face a band
## of rind round a hollow lined with crystal points growing in toward the middle - `[{geo}]` the
## lining, then the rock in its own material. The hollow follows the rock's lumps, so the rind is
## as thick all round as it was asked to be.
static func _geode(p: Dictionary, rng: RandomNumberGenerator) -> Array:
	var R := float(p["radius"]) * 0.01
	var hollow := R - float(p["rind"]) * 0.01
	var L := float(p["length"]) * 0.01
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = rng.randi()
	noise.frequency = 1.6
	var lump := func(d: Vector3) -> float:
		return 1.0 + 0.3 * noise.get_noise_3dv(d * 1.3)
	var rings := 10
	var segs := 32
	# half a lumpy ball, from the bottom up to the cut (at y = 0 until the whole is stood up); the
	# cut stays flat, since a lump there only moves the edge in or out
	var half := func(radius: float, wobble: float) -> Array:
		var grid: Array = []
		for j in rings + 1:
			var phi := PI * 0.5 * float(j) / float(rings)
			var row: Array = []
			for i in segs + 1:
				var th := TAU * float(i % segs) / float(segs)
				var d := Vector3(sin(phi) * cos(th), -cos(phi), sin(phi) * sin(th))
				row.append(d * radius * (float(lump.call(d)) + wobble * noise.get_noise_3dv(d * 3.1 + Vector3(9.0, 0.0, 0.0))))
			grid.append(row)
		return grid
	var outside: Array = half.call(R, 0.0)
	var inside: Array = half.call(hollow, 0.03)
	var rock := Tris.new()
	var lining := Tris.new()
	for j in rings:
		for i in segs:
			for side in [[outside, rock, 1.0], [inside, lining, -1.0]]:
				var grid: Array = side[0]
				var ps: Array = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
				var ns: Array = []
				for q in [[j, i], [j, i + 1], [j + 1, i + 1], [j + 1, i]]:
					ns.append(_grid_normal(grid, int(q[0]), int(q[1]), segs, Vector3.ZERO) * float(side[2]))
				var hs: Array = []
				for q in ps:
					hs.append(clampf(1.0 + (q as Vector3).y / R, 0.0, 1.0))
				(side[1] as Tris).quad(ps[0], ps[1], ps[2], ps[3], ns[0], ns[1], ns[2], ns[3],
					Vector2(float(i) / segs, float(j) / rings), Vector2(float(i + 1) / segs, float(j) / rings),
					Vector2(float(i + 1) / segs, float(j + 1) / rings), Vector2(float(i) / segs, float(j + 1) / rings), hs[0], hs[1], hs[2], hs[3])
	# THE CUT FACE: the rind, from the rock's edge in to the hollow's
	for i in segs:
		rock.quad(outside[rings][i], outside[rings][i + 1], inside[rings][i + 1], inside[rings][i], Vector3.UP, Vector3.UP,
			Vector3.UP, Vector3.UP, Vector2(float(i) / segs, 0.0), Vector2(float(i + 1) / segs, 0.0), Vector2(float(i + 1) / segs, 1.0),
			Vector2(float(i) / segs, 1.0), 1.0, 1.0, 1.0, 1.0)
	# THE CRYSTALS, spread evenly over the hollow (a spiral) from its bottom to a little under the
	# cut, each rooted in the wall and pointing in, toward a point under the middle of the cut
	var n := int(p["count"])
	var golden := PI * (3.0 - sqrt(5.0))
	for k in n:
		var yk := -1.0 + (float(k) + 0.5) / float(n) * 0.75
		var across := sqrt(maxf(0.0, 1.0 - yk * yk))
		var th := golden * float(k) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(th) * across, yk, sin(th) * across)
		var wall := d * hollow * float(lump.call(d))
		var aim := (Vector3(0.0, -hollow * 0.35, 0.0) - wall).normalized()
		aim = (aim + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.22).normalized()
		var length := L * rng.randf_range(0.55, 1.1)
		var basis := Basis(Quaternion(Vector3.UP, aim)) * Basis(Vector3.UP, rng.randf() * TAU)
		_crystal(lining, length * rng.randf_range(0.2, 0.3), length * 0.62, length * 0.38, 6,
			Transform3D(basis, wall - aim * length * 0.12), rng)
	var low := 0.0
	for row in outside:
		for q in row:
			low = minf(low, (q as Vector3).y)
	rock.lift(-low)
	lining.lift(-low)
	rock.measure()
	lining.measure()
	return [{"geo": lining}, {"geo": rock, "material": String(p["base"])}]


## A RING lying flat round the vertical axis, resting on y = 0: a torus, or part of one.
static func _ring(radius: float, thick: float, arc_deg: float) -> Tris:
	var g := Tris.new()
	var segs := clampi(roundi(arc_deg / 360.0 * 64.0), 8, 64)
	var tsegs := 12
	var arc := deg_to_rad(arc_deg)
	for i in segs:
		for j in tsegs:
			var corners: Array = []
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a := arc * float(q[0]) / float(segs)
				var b := TAU * float(q[1]) / float(tsegs)
				var c := Vector3(cos(a), 0.0, sin(a))
				var n := c * cos(b) + Vector3.UP * sin(b)
				var pos := c * radius + n * thick + Vector3(0.0, thick, 0.0)
				corners.append([pos, n, Vector2(float(q[0]) / float(segs), float(q[1]) / float(tsegs)), pos.y / maxf(thick * 2.0, 1e-6)])
			g.quad(corners[0][0], corners[1][0], corners[2][0], corners[3][0], corners[0][1], corners[1][1], corners[2][1],
				corners[3][1], corners[0][2], corners[1][2], corners[2][2], corners[3][2], corners[0][3], corners[1][3],
				corners[2][3], corners[3][3])
	g.girth = arc * radius * 100.0
	g.height = thick * 200.0
	g.top = Vector3(0.0, thick * 2.0, 0.0)
	return g


## A ROD along a path: a circle swept along it ([method _sweep]), its radius following `radii` if
## given, closed at both ends - or, with a `wall`, hollow and open, a pipe.
static func _tube(p: Dictionary) -> Tris:
	var raw: Array = []
	for q in (p["path"] as Array):
		raw.append((q as Vector3) * 0.01)
	var c := _curve(raw, _rounds_m(p, raw.size()), bool(p.get("smooth", true)), 8)
	if _fine(p):
		c = _densify_by(c, WARP_STEP)
	var radii: PackedFloat32Array = p.get("radii", PackedFloat32Array())
	var base_r := float(p["radius"]) * 0.01
	var src: PackedFloat32Array = c["src"]
	var rings: Array = []
	var hollow := PackedFloat32Array()
	var wall := float(p.get("wall", 0.0)) * 0.01
	for i in src.size():
		var f := src[i]
		var k := floori(f)
		var r := lerpf(_radius_at(radii, k, base_r), _radius_at(radii, k + 1, base_r), f - float(k))
		var ring: Array = []
		for j in 12:
			var a := TAU * float(j) / 12.0
			ring.append(Vector2(cos(a), sin(a)) * r)
		rings.append(ring)
		hollow.append(clampf(1.0 - wall / maxf(r, 1e-5), 0.1, 0.95) if wall > 0.0 else 0.0)
	var sharp := PackedByteArray()
	sharp.resize(12)
	return _sweep(c["pts"], c["corner"], rings, sharp, hollow)


static func _radius_at(radii: PackedFloat32Array, i: int, fallback: float) -> float:
	if radii.is_empty():
		return fallback
	return maxf(radii[clampi(i, 0, radii.size() - 1)] * 0.01, 0.0002)


## A LOFT: its sections ([method _sections]) blended along its path - or straight up its height -
## and swept ([method _sweep]). Sections drawn from the same outline keep its points one for one (a
## square stays crisp); different outlines are each walked round from the same side and cut into as
## many points, so a circle becomes a star without twisting.
static func _loft(p: Dictionary) -> Tris:
	var path: Array = []
	for q in (p.get("path", []) as Array):
		path.append((q as Vector3) * 0.01)
	var smooth := bool(p.get("smooth", true))
	var spine: Array
	var corner: PackedByteArray
	if path.size() >= 2:
		var c := _curve(path, _rounds_m(p, path.size()), smooth, 8)
		spine = c["pts"]
		corner = c["corner"]
	else:
		spine = [Vector3.ZERO, Vector3(0.0, float(p.get("height", 10.0)) * 0.01, 0.0)]
		corner = PackedByteArray([0, 0])
	var secs: Array = p.get("sections", [])
	if secs.is_empty():
		secs = [{"outline": "circle", "points": [], "size": Vector2(2, 2), "sides": 6, "scale": 1.0, "turn": 0.0, "shift": Vector2.ZERO, "at": 0.0}]
	# enough rings for the sections to blend smoothly (and for a warp to bend)
	var want := maxi(24, secs.size() * 10)
	if _fine(p):
		want = maxi(want, ceili(_lengths(spine)[spine.size() - 1] / WARP_STEP) + 1)
	var d := _densify(spine, corner, want)
	spine = d["pts"]
	corner = d["corner"]
	var along := _lengths(spine)
	var total := maxf(along[along.size() - 1], 1e-6)
	# THE OUTLINES: one for one when every section is drawn from the same one
	var outs: Array = []
	var sig := {}
	for sd in secs:
		var o := _section_outline(sd as Dictionary)
		outs.append(o)
		var own := (sd["points"] as Array).size()
		sig["points:%d" % own if own >= 3 else "%s:%d" % [String(sd["outline"]), int(sd["sides"])]] = true
	if sig.size() > 1:
		for i in outs.size():
			outs[i] = _resample(outs[i], 48)
	var m := (outs[0] as Array).size()
	for o in outs:
		m = mini(m, (o as Array).size())
	var sharp := PackedByteArray()
	var first: Array = outs[0]
	for k in m:
		var a: Vector2 = first[(k - 1 + m) % m]
		var b: Vector2 = first[k]
		var c2: Vector2 = first[(k + 1) % m]
		var turn := 0.0
		if (b - a).length() > 1e-7 and (c2 - b).length() > 1e-7:
			turn = absf((b - a).angle_to(c2 - b))
		sharp.append(1 if turn > deg_to_rad(35.0) else 0)
	var ats := PackedFloat32Array()
	for sd in secs:
		ats.append(float(sd["at"]))
	var wall := float(p.get("wall", 0.0)) * 0.01
	var rings: Array = []
	var hollow := PackedFloat32Array()
	for i in spine.size():
		var s := along[i] / total
		var turn := deg_to_rad(float(_blend(ats, secs.map(func(x: Dictionary) -> float: return float(x["turn"])), s, smooth)))
		var shift: Vector2 = _blend(ats, secs.map(func(x: Dictionary) -> Vector2: return (x["shift"] as Vector2) * 0.01), s, smooth)
		var ring: Array = []
		var reach := 0.0
		for k in m:
			var q: Vector2 = _blend(ats, outs.map(func(o: Array) -> Vector2: return o[k]), s, smooth)
			ring.append(q.rotated(turn) + shift)
			reach += q.length()
		rings.append(ring)
		reach /= float(m)
		hollow.append(clampf(1.0 - wall / maxf(reach, 1e-5), 0.1, 0.95) if wall > 0.0 else 0.0)
	return _sweep(spine, corner, rings, sharp, hollow)


## A loft section's outline in meters about the path, its scale applied: drawn at a unit size of
## its own proportions and then scaled, so a section of size 0 keeps its points (all at the path).
static func _section_outline(sd: Dictionary) -> Array:
	var size: Vector2 = sd["size"]
	var big := maxf(size.x, size.y)
	var k := float(sd.get("scale", 1.0))
	var own: Array = sd.get("points", [])
	var out: Array
	if own.size() >= 3:
		out = _outline2({"points": own})
	else:
		var unit := (size / big).max(Vector2(0.02, 0.02)) if big > 1e-4 else Vector2(1.0, 1.0)
		out = _outline2({"outline": sd["outline"], "size": unit, "sides": sd["sides"]})
		k *= big
	for i in out.size():
		out[i] = (out[i] as Vector2) * k
	return out


## An outline walked round from where a line from its middle toward the back (-z) leaves it, cut
## into [param m] points evenly along its length.
static func _resample(poly: Array, m: int) -> Array:
	var n := poly.size()
	if n < 3:
		return poly
	var mid := Vector2.ZERO
	for q in poly:
		mid += q
	mid /= float(n)
	var start_i := 0
	var start_p: Vector2 = poly[0]
	var best := -1.0
	for i in n:
		var hit: Variant = Geometry2D.segment_intersects_segment(mid, mid + Vector2(0.0, -10.0), poly[i], poly[(i + 1) % n])
		if hit != null and (hit as Vector2).distance_to(mid) > best:
			best = (hit as Vector2).distance_to(mid)
			start_i = i
			start_p = hit
	var walk: Array = [start_p]
	for j in range(1, n + 1):
		walk.append(poly[(start_i + j) % n])
	walk.append(start_p)
	var lens := _lengths(walk)
	var total := lens[lens.size() - 1]
	if total < 1e-9:
		var same: Array = []
		for k in m:
			same.append(start_p)
		return same
	var out: Array = []
	var seg := 0
	for k in m:
		var want := total * float(k) / float(m)
		while seg < walk.size() - 2 and lens[seg + 1] < want:
			seg += 1
		var span := maxf(lens[seg + 1] - lens[seg], 1e-12)
		out.append((walk[seg] as Vector2).lerp(walk[seg + 1], (want - lens[seg]) / span))
	return out


## Whether part [param p]'s warp bends its shape rather than only scaling it: then its shape is
## built with points no further apart than [constant WARP_STEP].
static func _fine(p: Dictionary) -> bool:
	var w: Dictionary = p.get("warp", {})
	for k in ["taper", "twist", "lean", "bend", "wobble"]:
		if w.has(k):
			return true
	return false


## A curve's points ([method _curve]) no further apart than [param step], each new point's place among
## the points it was drawn from between its neighbors'.
static func _densify_by(c: Dictionary, step: float) -> Dictionary:
	var pts: Array = c["pts"]
	var src: PackedFloat32Array = c["src"]
	var corner: PackedByteArray = c["corner"]
	var out: Array = []
	var os := PackedFloat32Array()
	var oc := PackedByteArray()
	for i in pts.size() - 1:
		var n := maxi(1, ceili((pts[i + 1] - pts[i]).length() / step))
		for k in n:
			var t := float(k) / float(n)
			out.append(pts[i] + (pts[i + 1] - pts[i]) * t)
			os.append(lerpf(src[i], src[i + 1], t))
			oc.append(corner[i] if k == 0 else 0)
	out.append(pts[-1])
	os.append(src[src.size() - 1])
	oc.append(0)
	return {"pts": out, "src": os, "corner": oc}


## The distance along [param pts] to each of them.
static func _lengths(pts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		out.append(out[i - 1] + (pts[i] - pts[i - 1]).length())
	return out


## A path with at least [param want] points: its longest spans cut evenly, its corners kept.
static func _densify(pts: Array, corner: PackedByteArray, want: int) -> Dictionary:
	if pts.size() >= want or pts.size() < 2:
		return {"pts": pts, "corner": corner}
	var lens := _lengths(pts)
	var step := maxf(lens[lens.size() - 1] / float(want - 1), 1e-6)
	var out: Array = []
	var oc := PackedByteArray()
	for i in pts.size() - 1:
		var n := maxi(1, ceili((lens[i + 1] - lens[i]) / step - 0.001))
		for k in n:
			out.append((pts[i] as Vector3).lerp(pts[i + 1], float(k) / float(n)))
			oc.append(corner[i] if k == 0 and i < corner.size() else 0)
	out.append(pts[-1])
	oc.append(0)
	return {"pts": out, "corner": oc}


## The value at [param s] (0..1 along a loft) of [param vals] (floats or Vector2s) given at
## [param ats]: held before the first and after the last, and between them a cubic through each
## (its slope from the neighbors on either side - a straight taper stays straight), or a straight
## line when not [param smooth].
static func _blend(ats: PackedFloat32Array, vals: Array, s: float, smooth: bool) -> Variant:
	var n := ats.size()
	if n == 1 or s <= ats[0]:
		return vals[0]
	if s >= ats[n - 1]:
		return vals[n - 1]
	var j := 0
	while j < n - 2 and s > ats[j + 1]:
		j += 1
	var h := ats[j + 1] - ats[j]
	if h < 1e-6:
		return vals[j + 1]
	var t := (s - ats[j]) / h
	if not smooth:
		return vals[j] + (vals[j + 1] - vals[j]) * t
	var slope := func(i: int) -> Variant:
		var a := maxi(i - 1, 0)
		var b := mini(i + 1, n - 1)
		return (vals[b] - vals[a]) / maxf(ats[b] - ats[a], 1e-6)
	var t2 := t * t
	var t3 := t2 * t
	return vals[j] * (2.0 * t3 - 3.0 * t2 + 1.0) + slope.call(j) * h * (t3 - 2.0 * t2 + t) \
		+ vals[j + 1] * (-2.0 * t3 + 3.0 * t2) + slope.call(j + 1) * h * (t3 - t2)


## A COIL: a band wound round the vertical axis from `radius` to `radius2`, climbing `height` over
## its turns, its underside on y = 0.
static func _coil(p: Dictionary) -> Tris:
	var turns := float(p["turns"])
	var r0 := float(p["radius"]) * 0.01
	var r1 := float(p["radius2"]) * 0.01
	var h := float(p["height"]) * 0.01
	var th := float(p["thickness"]) * 0.01
	var n := clampi(ceili(turns * 32.0), 12, 640)
	var spine: Array = []
	var rings: Array = []
	var ring: Array = []
	for j in 12:
		var a := TAU * float(j) / 12.0
		ring.append(Vector2(cos(a), sin(a)) * th)
	for i in n + 1:
		var f := float(i) / float(n)
		var a := TAU * turns * f
		var r := lerpf(r0, r1, f)
		spine.append(Vector3(cos(a) * r, th + h * f, sin(a) * r))
		rings.append(ring)
	var none := PackedByteArray()
	none.resize(n + 1)
	var sharp := PackedByteArray()
	sharp.resize(12)
	var hollow := PackedFloat32Array()
	hollow.resize(n + 1)
	return _sweep(spine, none, rings, sharp, hollow)


# --- bones --------------------------------------------------------------------------------------

## A BONE lying on its side along x, resting on its knobs (asked 2026-10-07: "Chicken bones in a pile, a skull
## upon the table, or even a large femur just sitting there"): a shaft swept along a slight bow, flaring at its
## ends, and the knobs of its joints - built of the rods and balls every other thing is, in its own
## proportions, so a set dresser writes a kind and a length and never draws one.
static func _bone(p: Dictionary, rng: RandomNumberGenerator) -> Tris:
	var L := float(p["length"])
	var r := float(p["thickness"]) * 0.5
	var g := Tris.new()
	var shaft := func(from: Vector3, to: Vector3, bow: Vector3, flare: float, r0 := -1.0, r1 := -1.0) -> void:
		var path: Array = []
		var radii := PackedFloat32Array()
		for i in 9:
			var u := float(i) / 8.0
			path.append(from.lerp(to, u) + bow * sin(u * PI))
			var end := pow(absf(u - 0.5) * 2.0, 4.0)
			var base := lerpf(r0 if r0 > 0.0 else r, r1 if r1 > 0.0 else r, u)
			radii.append(base * (1.0 + flare * end))
		g.append(_tube({"path": path, "rounds": PackedFloat32Array(), "radius": r, "radii": radii, "smooth": true, "wall": 0.0}))
	match String(p["kind"]):
		"femur":
			shaft.call(Vector3(-0.40 * L, r, 0.0), Vector3(0.40 * L, r, 0.0), Vector3(0.0, 0.0, 0.035 * L), 0.9)
			# the knee's two knuckles, the hip's ball on its neck and the knob beside it
			_knob(g, Vector3(0.43 * L, r * 1.1, 0.85 * r), Vector3(2.3, 2.1, 2.1) * r, rng)
			_knob(g, Vector3(0.43 * L, r * 1.1, -0.85 * r), Vector3(2.3, 2.1, 2.1) * r, rng)
			shaft.call(Vector3(-0.38 * L, r, 0.0), Vector3(-0.44 * L, r * 1.2, -2.0 * r), Vector3.ZERO, 0.2, r * 1.0, r * 0.9)
			_knob(g, Vector3(-0.45 * L, r * 1.3, -2.3 * r), Vector3.ONE * 2.5 * r, rng, 0.05)
			_knob(g, Vector3(-0.42 * L, r * 1.1, 0.7 * r), Vector3(2.0, 1.7, 1.7) * r, rng)
		"long":
			shaft.call(Vector3(-0.42 * L, r, 0.0), Vector3(0.42 * L, r, 0.0), Vector3(0.0, 0.0, 0.02 * L), 0.8)
			_knob(g, Vector3(-0.45 * L, r * 1.2, 0.2 * r), Vector3.ONE * 2.3 * r, rng, 0.08)
			_knob(g, Vector3(0.45 * L, r * 1.0, 0.6 * r), Vector3(1.7, 1.6, 1.6) * r, rng)
			_knob(g, Vector3(0.45 * L, r * 1.0, -0.6 * r), Vector3(1.7, 1.6, 1.6) * r, rng)
		"rib":
			# a flattened bar bowed round in an arc, lying flat, thinning toward its end
			var path: Array = []
			var radii := PackedFloat32Array()
			var R := L * 0.62
			for i in 13:
				var u := float(i) / 12.0
				var a := lerpf(-0.95, 0.95, u)
				path.append(Vector3(sin(a) * R, r * 0.5, R - cos(a) * R * 0.9))
				radii.append(r * lerpf(1.1, 0.55, u))
			var bar := _tube({"path": path, "rounds": PackedFloat32Array(), "radius": r, "radii": radii, "smooth": true, "wall": 0.0})
			_xf_append(g, bar, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)), Vector3.ZERO))
			_knob(g, path[0] as Vector3, Vector3(1.6, 1.0, 1.6) * r, rng)
		"wishbone":
			for side in [-1.0, 1.0]:
				shaft.call(Vector3(-0.45 * L, r, 0.0), Vector3(0.45 * L, r, side * 0.42 * L), Vector3(0.0, 0.0, side * 0.04 * L), 0.4)
				_knob(g, Vector3(0.46 * L, r * 0.9, side * 0.43 * L), Vector3.ONE * 2.0 * r, rng, 0.2)
			_knob(g, Vector3(-0.47 * L, r * 0.9, 0.0), Vector3(2.6, 1.4, 2.2) * r, rng, 0.2)
		_:
			# a small bone - a chicken's: thin, a little bent, its knobs uneven
			var bend := rng.randf_range(-0.05, 0.05) * L
			shaft.call(Vector3(-0.42 * L, r, 0.0), Vector3(0.42 * L, r, 0.0), Vector3(0.0, 0.0, bend), 0.7)
			_knob(g, Vector3(-0.45 * L, r * 1.1, 0.0), Vector3(2.4, 2.0, 2.2) * r, rng, 0.35)
			_knob(g, Vector3(0.45 * L, r * 1.1, 0.0), Vector3(2.6, 1.9, 2.6) * r, rng, 0.3)
	_rest(g)
	return g


## A knob of bone at [param c] (centimeters), of [param size], [param lumpy] as a joint's end is.
static func _knob(g: Tris, c: Vector3, size: Vector3, rng: RandomNumberGenerator, lumpy := 0.15) -> void:
	var b := _ball(size, lumpy, false, rng)
	_xf_append(g, b, Transform3D(Basis(), c * 0.01 - Vector3(0.0, size.y * 0.005, 0.0)))


## [param g] moved to rest: its lowest point on y = 0, its middle over the origin.
static func _rest(g: Tris) -> void:
	if g.v.is_empty():
		return
	var box := AABB(g.v[0], Vector3.ZERO)
	for q in g.v:
		box = box.expand(q)
	var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for i in g.v.size():
		g.v[i] = g.v[i] + shift
	g.measure()


## A SKULL ([constant SKULLS]), facing +z and resting on its jaw: a SCULPT ([constant SKULL_FORMS]) built as an
## agent's is ([method _sculpt]) - its openings holes right through, its sockets shut in and so darkened - and
## scaled to its length; a horned one's horns swept on. Asked 2026-10-07, of the first skulls (one surface
## found along rays from inside, which can make no hole, with dark lumps for sockets): "The bird-like skull
## I'm seeing does look rather cartoonish".
static func _skull(p: Dictionary, _rng: RandomNumberGenerator) -> Array:
	var kind := String(p["kind"])
	var bone := _sculpt({"strokes": _strokes(SKULL_FORMS[kind]), "mirror": true})
	var k := float(p["length"]) / maxf(_bounds_of(bone).size.z * 100.0, 1e-3)
	if kind == "horned" and String(p.get("horns", "curved")) != "none":
		for side in [-1.0, 1.0]:
			bone.append(_horn(String(p["horns"]), side))
	var out := Tris.new()
	_xf_append(out, bone, Transform3D(Basis().scaled(Vector3.ONE * k), Vector3.ZERO))
	# resting where the bone rests
	var box := _bounds_of(out)
	var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for i in out.v.size():
		out.v[i] = out.v[i] + shift
		out.uv2[i] = Vector2(clampf(out.v[i].y / maxf(box.size.y, 1e-4), 0.0, 1.0), out.uv2[i].y)
	out.measure()
	return [{"geo": out}]


## A horn on side [param side] of a horned skull's poll (written in centimeters, built in meters, before the
## skull is scaled): straight, curved up and forward, or curled round as a ram's.
static func _horn(how: String, side: float) -> Tris:
	var path: Array = []
	var radii := PackedFloat32Array()
	# started inside the poll, so no end of it shows
	var root := Vector3(side * 6.4, 14.1, -8.6)
	match how:
		"straight":
			for i in 7:
				var u := float(i) / 6.0
				path.append(root + Vector3(side * 16.0 * u, 5.0 * u, -2.0 * u))
		"curled":
			# up off the poll, back, down beside the head and round forward under the ear, as a ram's
			for i in 17:
				var u := float(i) / 16.0
				var a := u * TAU * 0.95
				var rr := lerpf(6.0, 3.2, u)
				path.append(root + Vector3(side * (1.0 + 5.0 * u), sin(a) * rr, -(1.0 - cos(a)) * rr))
		_:
			for i in 9:
				var u := float(i) / 8.0
				path.append(root + Vector3(side * 15.0 * u, 2.0 * u + 9.0 * u * u, -2.5 * u + 7.0 * u * u))
	for i in path.size():
		var u := float(i) / float(path.size() - 1)
		radii.append(lerpf(2.6, 0.25, pow(u, 0.9)))
	return _tube({"path": path, "rounds": PackedFloat32Array(), "radius": 2.0, "radii": radii, "smooth": true, "wall": 0.0})


static func _bounds_of(g: Tris) -> AABB:
	if g.v.is_empty():
		return AABB()
	var box := AABB(g.v[0], Vector3.ZERO)
	for q in g.v:
		box = box.expand(q)
	return box


# --- sculpt ---------------------------------------------------------------------------------------

## A SCULPT's strokes made safe ([constant SHAPES]): each {points (centimeters), radii, size (a ball's, or
## zero), carve, blend (-1: chosen from its thickness), smooth} - [constant MAX_STROKES] strokes and
## [constant MAX_SCULPT_POINTS] points in all at most. A stroke with no point is dropped.
static func _strokes(v: Variant) -> Array:
	var out: Array = []
	var left := MAX_SCULPT_POINTS
	for s in (v if v is Array else []):
		if out.size() >= MAX_STROKES or left <= 0:
			break
		if not (s is Dictionary):
			continue
		var d: Dictionary = s
		var r0 := _num(d.get("radius"), 0.5, 0.02, MAX_SIZE * 0.5)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for q in (d["points"] as Array if d.get("points") is Array else []):
			if pts.size() >= mini(MAX_POINTS, left):
				break
			if not (q is Array) or (q as Array).size() < 3:
				continue
			var a: Array = q
			if not ((a[0] is float or a[0] is int) and (a[1] is float or a[1] is int) and (a[2] is float or a[2] is int)):
				continue
			pts.append(_vec3(a, Vector3.ZERO, MAX_SIZE))
			radii.append(_num(a[3], r0, 0.02, MAX_SIZE * 0.5) if a.size() > 3 else r0)
		if pts.is_empty():
			continue
		left -= pts.size()
		var size := Vector3.ZERO
		if pts.size() == 1 and d.get("size") is Array:
			size = _vec3(d["size"], Vector3.ONE * r0 * 2.0, MAX_SIZE, 0.04)
		elif pts.size() == 1 and (d.get("size") is float or d.get("size") is int):
			size = Vector3.ONE * _num(d["size"], r0 * 2.0, 0.04, MAX_SIZE)
		out.append({"points": pts, "radii": radii, "size": size, "carve": _flag(d.get("carve")),
			"blend": _num(d["blend"], 0.0, 0.0, 10.0) if (d.get("blend") is float or d.get("blend") is int) else -1.0,
			"smooth": _flag(d.get("smooth"), true)})
	return out


## A SCULPT, built ([constant SHAPES] `sculpt`): its strokes as one surface ([method _carved]), in meters,
## each point carrying how shut in it is (uv2.y, [method _cavity]). The same sculpt is built once in a
## process ([constant SCULPT_KEPT]): a skull is a second or two of arithmetic, and a table builds its things
## more than once.
static func _sculpt(p: Dictionary) -> Tris:
	var mirror := bool(p.get("mirror", false))
	var key := hash([p["strokes"], mirror])
	_sculpted_lock.lock()
	var made: Variant = _sculpted.get(key)
	_sculpted_lock.unlock()
	if made == null:
		made = _carved(_field_of(p["strokes"], mirror))
		_sculpted_lock.lock()
		if _sculpted.size() >= SCULPT_KEPT:
			_sculpted.erase(_sculpted.keys()[0])
		_sculpted[key] = made
		_sculpted_lock.unlock()
	var g := Tris.new()
	g.append(made)
	g.measure()
	return g


## A SCULPT'S FIELD (centimeters; below 0 inside): its strokes in order, each melted into what came before it
## (`k`, centimeters: soft as clay smoothed over, 0 a crisp seam) or, carved, cut out of it - a carve cuts only
## what came before it. A rod is a run of tapered segments (a smooth one cut short along a curve through its
## points), a ball an ellipsoid. Mirrored, it is sampled at |x|, so what is drawn on the right is drawn on the
## left too (a stroke drawn wholly on the left is moved to the right). Each stroke's bounds (`box`, its right
## side when mirrored), each segment's (`lo`, `hi`) and its thinnest (`thin`) are kept for what samples it.
static func _field_of(strokes: Array, mirror: bool) -> Dictionary:
	var A := PackedVector3Array()
	var B := PackedVector3Array()
	var RA := PackedFloat32Array()
	var RB := PackedFloat32Array()
	var LO := PackedVector3Array()
	var HI := PackedVector3Array()
	var carve := PackedByteArray()
	var ell := PackedByteArray()
	var K := PackedFloat32Array()
	var EC := PackedVector3Array()
	var ER := PackedVector3Array()
	var list: Array = []
	for s in strokes:
		var pts: PackedVector3Array = (s["points"] as PackedVector3Array).duplicate()
		var radii: PackedFloat32Array = s["radii"]
		if mirror:
			var right := false
			for q in pts:
				right = right or q.x >= 0.0
			if not right:
				for i in pts.size():
					pts[i] = Vector3(-pts[i].x, pts[i].y, pts[i].z)
		var e := {"carve": bool(s["carve"]), "from": A.size(), "to": A.size()}
		var box := AABB()
		var thin := INF
		var size: Vector3 = s["size"]
		if pts.size() == 1:
			var r: Vector3 = size * 0.5 if size != Vector3.ZERO else Vector3.ONE * radii[0]
			box = AABB(pts[0] - r, r * 2.0)
			thin = minf(r.x, minf(r.y, r.z))
			ell.append(1)
			EC.append(pts[0])
			ER.append(r)
		else:
			var line: Array = []
			for i in pts.size():
				line.append(Vector4(pts[i].x, pts[i].y, pts[i].z, radii[i]))
			if bool(s["smooth"]) and line.size() >= 3:
				var fine: Array = [line[0]]
				for i in line.size() - 1:
					for st in range(1, SCULPT_STEPS + 1):
						fine.append(_ccr(line[maxi(i - 1, 0)], line[i], line[i + 1], line[mini(i + 2, line.size() - 1)], float(st) / float(SCULPT_STEPS)))
				line = fine
			for i in line.size() - 1:
				var a: Vector4 = line[i]
				var b: Vector4 = line[i + 1]
				var pa := Vector3(a.x, a.y, a.z)
				var pb := Vector3(b.x, b.y, b.z)
				var ra := maxf(a.w, 0.02)
				var rb := maxf(b.w, 0.02)
				A.append(pa)
				B.append(pb)
				RA.append(ra)
				RB.append(rb)
				var sb := AABB(pa, Vector3.ZERO).expand(pb).grow(maxf(ra, rb))
				LO.append(sb.position)
				HI.append(sb.end)
				box = sb if i == 0 else box.merge(sb)
				thin = minf(thin, minf(ra, rb))
			e["to"] = A.size()
			ell.append(0)
			EC.append(Vector3.ZERO)
			ER.append(Vector3.ONE)
		var k := float(s["blend"])
		if k < 0.0:
			k = thin * (0.1 if bool(e["carve"]) else 0.3)
		K.append(k)
		carve.append(1 if bool(e["carve"]) else 0)
		e["box"] = box.grow(k)
		e["thin"] = thin
		list.append(e)
	return {"a": A, "b": B, "ra": RA, "rb": RB, "lo": LO, "hi": HI, "carve": carve, "ell": ell, "k": K, "ec": EC,
		"er": ER, "strokes": list, "mirror": mirror}


## Where a sculpt is, and how finely it is cut: [box (centimeters, both sides when mirrored), cell], the cell
## from its thinnest added stroke - fine enough for it, within [constant SCULPT_CELLS] across its longest
## side. A rod much thinner than a cell comes out broken ([method SetDresserTools._part_troubles] says so).
static func _cut_of(f: Dictionary) -> Array:
	var box := AABB()
	var any := false
	var thin := INF
	for e in f["strokes"]:
		if bool(e["carve"]):
			continue
		var b: AABB = e["box"]
		if bool(f["mirror"]):
			b = b.merge(AABB(Vector3(-b.end.x, b.position.y, b.position.z), b.size))
		box = b if not any else box.merge(b)
		any = true
		thin = minf(thin, float(e["thin"]))
	if not any:
		return [AABB(), 0.0]
	var longest := box.get_longest_axis_size()
	return [box, clampf(thin * 0.8, longest / SCULPT_CELLS.y, longest / SCULPT_CELLS.x)]


## The finest a sculpt part ([method _sanitize_part]) is cut, centimeters (0 for none), and each of its
## strokes' thinnest - what [SetDresserTools] warns of before it is built.
static func sculpt_cut(p: Dictionary) -> Dictionary:
	var f := _field_of(p.get("strokes", []), bool(p.get("mirror", false)))
	var thin: Array = []
	for e in f["strokes"]:
		thin.append(INF if bool(e["carve"]) else float(e["thin"]))
	return {"cell": float(_cut_of(f)[1]), "thin": thin}


## THE STROKES NEAR [param box] (centimeters): [ids, segments] - each stroke's place in the list whose bounds
## reach it, and for a rod the segments of it that do. Mirrored, the box is folded onto the right side.
static func _near(f: Dictionary, box: AABB) -> Array:
	var lo := box.position
	var hi := box.end
	if bool(f["mirror"]):
		var x0 := 0.0 if lo.x <= 0.0 and hi.x >= 0.0 else minf(absf(lo.x), absf(hi.x))
		var x1 := maxf(absf(lo.x), absf(hi.x))
		lo.x = x0
		hi.x = x1
	var folded := AABB(lo, hi - lo)
	var ids := PackedInt32Array()
	var segs: Array = []
	var LO: PackedVector3Array = f["lo"]
	var HI: PackedVector3Array = f["hi"]
	var K: PackedFloat32Array = f["k"]
	var list: Array = f["strokes"]
	for si in list.size():
		var e: Dictionary = list[si]
		if not (e["box"] as AABB).intersects(folded):
			continue
		var mine := PackedInt32Array()
		var g := K[si]
		for j in range(int(e["from"]), int(e["to"])):
			if LO[j].x - g <= hi.x and HI[j].x + g >= lo.x and LO[j].y - g <= hi.y and HI[j].y + g >= lo.y \
					and LO[j].z - g <= hi.z and HI[j].z + g >= lo.z:
				mine.append(j)
		if int(e["to"]) > int(e["from"]) and mine.is_empty():
			continue
		ids.append(si)
		segs.append(mine)
	return [ids, segs]


## The field at each of [param pts] (centimeters), from the strokes [param near] ([method _near]).
static func _sample(f: Dictionary, near: Array, pts: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts.size())
	var ids: PackedInt32Array = near[0]
	var segs: Array = near[1]
	var A: PackedVector3Array = f["a"]
	var B: PackedVector3Array = f["b"]
	var RA: PackedFloat32Array = f["ra"]
	var RB: PackedFloat32Array = f["rb"]
	var carve: PackedByteArray = f["carve"]
	var ell: PackedByteArray = f["ell"]
	var K: PackedFloat32Array = f["k"]
	var EC: PackedVector3Array = f["ec"]
	var ER: PackedVector3Array = f["er"]
	var mirror := bool(f["mirror"])
	for pi in pts.size():
		var q := pts[pi]
		if mirror:
			q.x = absf(q.x)
		var d := 1e9
		for ni in ids.size():
			var si := ids[ni]
			var s := 1e9
			if ell[si] == 1:
				s = _ell(q - EC[si], ER[si])
			else:
				for j in (segs[ni] as PackedInt32Array):
					s = minf(s, _cone(q, A[j], B[j], RA[j], RB[j]))
			d = -_smin(-d, s, K[si]) if carve[si] == 1 else _smin(d, s, K[si])
		out[pi] = d
	return out


## THE FIELD ON A GRID: [param dims] points from [param origin], [param cell] apart (centimeters), sampled a
## block of [constant SCULPT_BLOCK] cells at a time from the strokes near the block alone. With [param band],
## only near the surface: a block whose middle is further from it than the block is wide is skipped, and in
## the rest only the pieces of [constant SCULPT_PIECE] cells the surface can reach are sampled - the points
## left NAN (a person's skull sampled whole block by block was 850,000 points and seven seconds). {vals,
## blocks: each sampled piece's first and last cells, six numbers a piece}.
static func _grid(f: Dictionary, origin: Vector3, cell: float, dims: Vector3i, band: bool) -> Dictionary:
	var vals := PackedFloat32Array()
	vals.resize(dims.x * dims.y * dims.z)
	vals.fill(NAN)
	var queued := PackedByteArray()
	queued.resize(vals.size())
	var blocks := PackedInt32Array()
	var cells := dims - Vector3i.ONE
	var reach := float(SCULPT_BLOCK) * cell * 0.5 * sqrt(3.0)
	var piece_reach := float(SCULPT_PIECE) * cell * 0.5 * sqrt(3.0)
	var sx := dims.x
	var sxy := dims.x * dims.y
	var per := SCULPT_BLOCK / SCULPT_PIECE
	for bz in ceili(float(cells.z) / float(SCULPT_BLOCK)):
		for by in ceili(float(cells.y) / float(SCULPT_BLOCK)):
			for bx in ceili(float(cells.x) / float(SCULPT_BLOCK)):
				var c0 := Vector3i(bx, by, bz) * SCULPT_BLOCK
				var c1 := (c0 + Vector3i.ONE * SCULPT_BLOCK).min(cells)
				var lo := origin + Vector3(c0) * cell
				var hi := origin + Vector3(c1) * cell
				var near := _near(f, AABB(lo, hi - lo).grow(cell))
				var pieces: Array = [[c0, c1]]
				if band:
					if (near[0] as PackedInt32Array).is_empty():
						continue
					if absf(_sample(f, near, PackedVector3Array([(lo + hi) * 0.5]))[0]) > reach * SCULPT_SLACK + cell:
						continue
					# the pieces of it the surface can reach
					var mids := PackedVector3Array()
					var spans: Array = []
					for pz in per:
						for py in per:
							for px in per:
								var p0 := c0 + Vector3i(px, py, pz) * SCULPT_PIECE
								if p0.x >= c1.x or p0.y >= c1.y or p0.z >= c1.z:
									continue
								var p1 := (p0 + Vector3i.ONE * SCULPT_PIECE).min(c1)
								mids.append(origin + (Vector3(p0) + Vector3(p1)) * 0.5 * cell)
								spans.append([p0, p1])
					var got := _sample(f, near, mids)
					pieces = []
					for i in spans.size():
						if absf(got[i]) <= piece_reach * SCULPT_SLACK + cell * 0.5:
							pieces.append(spans[i])
				var pts := PackedVector3Array()
				var idx := PackedInt32Array()
				for pc in pieces:
					var q0: Vector3i = pc[0]
					var q1: Vector3i = pc[1]
					for k in range(q0.z, q1.z + 1):
						for j in range(q0.y, q1.y + 1):
							for i in range(q0.x, q1.x + 1):
								var id := i + sx * j + sxy * k
								if queued[id] == 0:
									queued[id] = 1
									pts.append(origin + Vector3(i, j, k) * cell)
									idx.append(id)
					blocks.append_array([q0.x, q0.y, q0.z, q1.x, q1.y, q1.z])
				var got := _sample(f, near, pts)
				for t in idx.size():
					vals[idx[t]] = got[t]
	return {"vals": vals, "blocks": blocks}


## A SCULPT'S SURFACE ([method _field_of]), meters: the field sampled on a grid ([method _cut_of], [method
## _grid]), a point in every cell the surface passes through - the middle of where it crosses the cell's edges
## - and a face across every edge it crosses, joining the four cells round that edge (surface nets: what
## marching cubes makes, without its table, and as smooth). Each point's normal is its faces' together; its
## uv2.y how shut in it is ([method _cavity]).
static func _carved(f: Dictionary) -> Tris:
	var g := Tris.new()
	var cut := _cut_of(f)
	var cell := float(cut[1])
	if cell <= 0.0:
		return g
	var box: AABB = cut[0]
	var origin := box.position - Vector3.ONE * cell * 2.0
	var dims := Vector3i((box.size / cell).ceil()) + Vector3i(5, 5, 5)
	var grid := _grid(f, origin, cell, dims, true)
	var vals: PackedFloat32Array = grid["vals"]
	var bl: PackedInt32Array = grid["blocks"]
	var cells := dims - Vector3i.ONE
	var sx := dims.x
	var sxy := dims.x * dims.y
	var csx := cells.x
	var csxy := cells.x * cells.y
	var at := PackedInt32Array()
	at.resize(cells.x * cells.y * cells.z)
	at.fill(-1)
	var verts := PackedVector3Array()
	var surf := PackedInt32Array()          # each point's cell: i, j, k
	var cv := PackedFloat32Array()
	cv.resize(8)
	for b in range(0, bl.size(), 6):
		for k in range(bl[b + 2], bl[b + 5]):
			for j in range(bl[b + 1], bl[b + 4]):
				for i in range(bl[b], bl[b + 3]):
					var p0 := i + sx * j + sxy * k
					cv[0] = vals[p0]
					cv[1] = vals[p0 + 1]
					cv[2] = vals[p0 + sx]
					cv[3] = vals[p0 + sx + 1]
					cv[4] = vals[p0 + sxy]
					cv[5] = vals[p0 + sxy + 1]
					cv[6] = vals[p0 + sxy + sx]
					cv[7] = vals[p0 + sxy + sx + 1]
					var inside := 0
					for c in 8:
						if cv[c] < 0.0:
							inside += 1
					if inside == 0 or inside == 8:
						continue
					var ci := i + csx * j + csxy * k
					if at[ci] >= 0:
						continue
					var sum := Vector3.ZERO
					var crossings := 0
					for e in range(0, 24, 2):
						var ca: int = _CUBE_EDGES[e]
						var cb: int = _CUBE_EDGES[e + 1]
						if (cv[ca] < 0.0) == (cv[cb] < 0.0):
							continue
						var t := cv[ca] / (cv[ca] - cv[cb])
						sum += (_CORNERS[ca] as Vector3).lerp(_CORNERS[cb], t)
						crossings += 1
					at[ci] = verts.size()
					verts.append(origin + (Vector3(i, j, k) + sum / float(crossings)) * cell)
					surf.append_array([i, j, k])
	# THE FACES: across each edge from a cell's first corner that the surface crosses, wound so they face out
	var quads := PackedInt32Array()
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	for vi in verts.size():
		var i := surf[vi * 3]
		var j := surf[vi * 3 + 1]
		var k := surf[vi * 3 + 2]
		if i == 0 or j == 0 or k == 0:
			continue
		var p0 := i + sx * j + sxy * k
		var inner := vals[p0] < 0.0
		var ci := i + csx * j + csxy * k
		for axis in 3:
			var p1 := p0 + (1 if axis == 0 else (sx if axis == 1 else sxy))
			if is_nan(vals[p1]) or (vals[p1] < 0.0) == inner:
				continue
			# the four cells round the edge, in order about it: a, a + u, a + u + w, a + w (u, w the other axes)
			var du := csx if axis == 0 else (csxy if axis == 1 else 1)
			var dw := csxy if axis == 0 else (1 if axis == 1 else csx)
			var q := [at[ci - du - dw], at[ci - dw], at[ci], at[ci - du]]
			if q.has(-1):
				continue
			if not inner:
				q.reverse()
			quads.append_array(q)
			var n := (verts[q[1]] - verts[q[0]]).cross(verts[q[3]] - verts[q[0]]) + (verts[q[2]] - verts[q[1]]).cross(verts[q[3]] - verts[q[1]])
			for c in 4:
				acc[q[c]] += n
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for vi in verts.size():
		normals[vi] = acc[vi].normalized() if acc[vi].length() > 1e-9 else Vector3.UP
	var cave := _cavity(f, verts, normals, cell)
	var lo_y := box.position.y
	var span := maxf(box.size.y, 1e-3)
	var pm := PackedVector3Array()
	var tv := PackedVector2Array()
	var sv := PackedVector2Array()
	for vi in verts.size():
		var p := verts[vi]
		pm.append(p * 0.01)
		tv.append(Vector2(atan2(p.x, p.z) / TAU + 0.5, (p.y - lo_y) / span))
		sv.append(Vector2(clampf((p.y - lo_y) / span, 0.0, 1.0), cave[vi]))
	# each quad as two triangles across its shorter diagonal, written straight in - wound as [method Tris.tri]
	# winds them: the quads face out, and Godot's fronts are clockwise
	var tri := PackedInt32Array()
	for qi in range(0, quads.size(), 4):
		var o := 0 if (verts[quads[qi]] - verts[quads[qi + 2]]).length_squared() <= (verts[quads[qi + 1]] - verts[quads[qi + 3]]).length_squared() else 1
		var a := quads[qi + o]
		var b := quads[qi + o + 1]
		var c := quads[qi + (o + 2) % 4]
		var d := quads[qi + (o + 3) % 4]
		tri.append_array([a, c, b, a, d, c])
	for i in tri:
		g.v.append(pm[i])
		g.n.append(normals[i])
		g.uv.append(tv[i])
		g.uv2.append(sv[i])
	g.measure()
	return g


## HOW SHUT IN each of [param pts] is (0 open, 1 deep in a hollow), with [param normals]: the field looked up
## a few steps out from it along its normal, on a grid three cells to one of the surface's - a point the
## surface stays close to as it steps out (a socket's floor, a groove, the hollow under an arch) sees less of
## the room. What the material darkens and takes the room's light from ([code]prop.gdshader[/code]).
static func _cavity(f: Dictionary, pts: PackedVector3Array, normals: PackedVector3Array, cell: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(pts.size())
	var cut := _cut_of(f)
	var box: AABB = cut[0]
	var c3 := cell * 3.0
	var origin := box.position - Vector3.ONE * c3 * 3.0
	var dims := Vector3i((box.size / c3).ceil()) + Vector3i(7, 7, 7)
	var vals: PackedFloat32Array = _grid(f, origin, c3, dims, false)["vals"]
	# out along the normal, then leaning 50 degrees off it four ways: a well's wall faces across the well, and
	# only a look up and down it finds the walls round it
	var steps := [[3.0, 0.2], [6.0, 0.2]]
	var leaned := [[10.0, 0.08], [20.0, 0.07]]
	for i in pts.size():
		var n := normals[i]
		var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := n.cross(t1)
		var occ := 0.0
		for st in steps:
			var h := float(st[0]) * cell
			var d := _trilinear(vals, dims, (pts[i] + n * h - origin) / c3)
			occ += float(st[1]) * clampf(1.0 - d / h, 0.0, 1.0)
		for st in leaned:
			var h := float(st[0]) * cell
			for dir in [t1, -t1, t2, -t2]:
				# against how far it would stand off a flat surface: a dome's leaning look is open
				var d := _trilinear(vals, dims, (pts[i] + (n * 0.64 + (dir as Vector3) * 0.77) * h - origin) / c3)
				occ += float(st[1]) * clampf(1.0 - d / (0.64 * h), 0.0, 1.0)
		out[i] = clampf(occ * 1.3, 0.0, 1.0)
	return out


static func _trilinear(vals: PackedFloat32Array, dims: Vector3i, g: Vector3) -> float:
	var b := Vector3i(g.floor()).clamp(Vector3i.ZERO, dims - Vector3i(2, 2, 2))
	var t := (g - Vector3(b)).clamp(Vector3.ZERO, Vector3.ONE)
	var sx := dims.x
	var sxy := dims.x * dims.y
	var p := b.x + sx * b.y + sxy * b.z
	var x00 := lerpf(minf(vals[p], 1e3), minf(vals[p + 1], 1e3), t.x)
	var x10 := lerpf(minf(vals[p + sx], 1e3), minf(vals[p + sx + 1], 1e3), t.x)
	var x01 := lerpf(minf(vals[p + sxy], 1e3), minf(vals[p + sxy + 1], 1e3), t.x)
	var x11 := lerpf(minf(vals[p + sxy + sx], 1e3), minf(vals[p + sxy + sx + 1], 1e3), t.x)
	return lerpf(lerpf(x00, x10, t.y), lerpf(x01, x11, t.y), t.z)


static func _ell(q: Vector3, r: Vector3) -> float:
	return ((q / r).length() - 1.0) * minf(r.x, minf(r.y, r.z))


## The distance from [param q] to a ROUND CONE: two balls (radius [param ra] at [param a], [param rb] at [param b])
## and the cone touching both - exact (Inigo Quilez's), so a rod of them is smooth through its joints, where a
## radius blended along the segment left a ring at every one.
static func _cone(q: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var ba := b - a
	var l2 := ba.dot(ba)
	var rr := ra - rb
	var a2 := l2 - rr * rr
	var pa := q - a
	if l2 < 1e-12 or a2 <= 1e-9:
		# one ball inside the other
		return minf(pa.length() - ra, (q - b).length() - rb)
	var il2 := 1.0 / l2
	var y := pa.dot(ba)
	var z := y - l2
	var x2 := (pa * l2 - ba * y).length_squared()
	var y2 := y * y * l2
	var z2 := z * z * l2
	var k := signf(rr) * rr * rr * x2
	if signf(z) * a2 * z2 > k:
		return sqrt(x2 + z2) * il2 - rb
	if signf(y) * a2 * y2 < k:
		return sqrt(x2 + y2) * il2 - ra
	return (sqrt(x2 * a2 * il2) + y * rr) * il2 - ra


static func _smin(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return minf(a, b)
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


# --- strands --------------------------------------------------------------------------------------

## A STRAND: its centerline as it lies ([method strand_line]), and what is built along it - a rope's
## twisted strands, a cord, a wire, a vine and its leaves, beads on a thread, a chain's links.
## Asked 2026-10-07: "a coil of rope ... a vine with leaves ... a wire ... layed into a nice, coiled pile -
## or they might be layed chaotically, unkempt ... or "draped" across the table, such that the item spills
## over one or both sides of the table".
static func _strand(p: Dictionary, rng: RandomNumberGenerator) -> Array:
	var line := strand_line(p, rng)
	var t := float(p["thickness"]) * 0.01
	var n := line.size()
	if n < 2:
		return []
	var kind := String(p["kind"])
	var none := PackedByteArray()
	none.resize(n)
	var hollow := PackedFloat32Array()
	hollow.resize(n)
	var spine: Array = Array(line)
	match kind:
		"beads", "chain":
			var g := Tris.new()
			var along := _lengths(spine)
			if kind == "beads":
				# the thread, then a bead every bead's width along it
				g.append(_sweep(spine, none, _rings_of(n, t * 0.1, 8), _sharp(8), hollow))
				var bead := _ball(Vector3.ONE * t * 100.0, 0.08, false, rng)
				var each := t * 1.08
				var s := each * 0.5
				while s < along[along.size() - 1] and g.v.size() < 400000:
					var at := _at_length(spine, along, s)
					_xf_append(g, bead, Transform3D(Basis(), (at[0] as Vector3) - Vector3(0.0, t * 0.5, 0.0)))
					s += each
			else:
				var R := t * 0.36
				var wire := t * 0.13
				var link := _ring(R, wire, 360.0)
				link.lift(-wire)
				var pitch := (2.0 * R - wire) * 1.45
				var s := pitch * 0.5
				var k := 0
				while s < along[along.size() - 1] and k < 360:
					var at := _at_length(spine, along, s)
					var tan: Vector3 = at[1]
					var side := tan.cross(Vector3.UP)
					side = side.normalized() if side.length() > 1e-4 else Vector3.RIGHT
					var up := side.cross(tan).normalized()
					# every other link stands on edge, turned a quarter round its way
					var b := Basis(tan * 1.45, up, side) if k % 2 == 0 else Basis(tan * 1.45, side, -up)
					# a flat one lies on what is under it; one on edge stands on it
					var lift := Vector3.ZERO if k % 2 == 1 else -up * (t * 0.5 - wire)
					_xf_append(g, link, Transform3D(b, (at[0] as Vector3) + lift))
					s += pitch
					k += 1
			g.measure()
			return [{"geo": g}]
		"rope":
			# THREE STRANDS LAID ROUND EACH OTHER: a three-lobed section turning along it, a full turn every
			# few widths
			var rings: Array = []
			var along := _lengths(spine)
			for i in n:
				var ph := TAU * along[i] / maxf(t * 3.4, 1e-4)
				var ring: Array = []
				for j in 18:
					var a := TAU * float(j) / 18.0
					ring.append(Vector2(cos(a), sin(a)) * t * 0.5 * (0.84 + 0.16 * cos(3.0 * (a - ph))))
				rings.append(ring)
			var g := _sweep(spine, none, rings, _sharp(18), hollow)
			g.measure()
			return [{"geo": g}]
		"vine":
			var radii: Array = []
			for i in n:
				radii.append(t * 0.5 * lerpf(1.0, 0.45, pow(float(i) / float(n - 1), 2.0)))
			var rings: Array = []
			for i in n:
				rings.append(_circle(float(radii[i]), 10))
			var stem := _sweep(spine, none, rings, _sharp(10), hollow)
			stem.measure()
			var leaves := Tris.new()
			var along := _lengths(spine)
			var lf := float(p["leaf"]) * 0.01
			var each := lf * 0.85
			var s := each * 0.6
			var k := 0
			while s < along[along.size() - 1] - lf * 0.2 and k < 200:
				var at := _at_length(spine, along, s)
				var tan: Vector3 = at[1]
				var flat := Vector3(tan.x, 0.0, tan.z)
				var side := flat.cross(Vector3.UP).normalized() if flat.length() > 1e-3 else Vector3.RIGHT
				var sgn := 1.0 if k % 2 == 0 else -1.0
				var dir := (flat.normalized() * 0.6 + side * sgn * 0.8).normalized() if flat.length() > 1e-3 else side * sgn
				dir = (dir + Vector3.UP * rng.randf_range(-0.05, 0.12)).normalized()
				var xb := dir.cross(Vector3.UP).normalized()
				var yb := dir.cross(xb).normalized() * -1.0
				var size := Vector2(lf * 55.0, lf * 100.0) * rng.randf_range(0.8, 1.15)
				var leaf := Tris.new()
				_sheet(leaf, {"outline": "leaf", "points": [], "size": size, "bend": rng.randf_range(0.05, 0.3),
					"fold": rng.randf_range(0.1, 0.4), "thickness": 0.06}, Transform3D.IDENTITY)
				_xf_append(leaves, leaf, Transform3D(Basis(xb, yb, dir), (at[0] as Vector3) + side * sgn * float(radii[0]) * 0.6
					- Vector3(0.0, float(radii[0]) * 0.6, 0.0)))
				s += each * rng.randf_range(0.75, 1.25)
				k += 1
			leaves.measure()
			var own := String(p.get("leaves", ""))
			if own.is_empty():
				stem.append(leaves)
				stem.measure()
				return [{"geo": stem}]
			return [{"geo": stem}, {"geo": leaves, "material": own}]
	var g := _sweep(spine, none, _rings_of(n, t * 0.5, 12 if kind != "wire" else 8), _sharp(12 if kind != "wire" else 8), hollow)
	g.measure()
	return [{"geo": g}]


## A STRAND'S CENTERLINE (meters): laid out flat as `lay` says ([method _strand_flat]), raised to rest on the
## cloth and on itself wherever it crosses ([method _strand_rest]) - and, draped over the table's edge, falling
## down past it ([method _draped]), when the table has given it its `ground`.
static func strand_line(p: Dictionary, rng: RandomNumberGenerator) -> PackedVector3Array:
	var t := float(p["thickness"]) * 0.01
	var flat := _strand_flat(p, rng)
	var ys := _strand_rest(flat, t)
	var out := PackedVector3Array()
	for i in flat.size():
		out.append(Vector3(flat[i].x, ys[i], flat[i].y))
	if String(p["lay"]) == "drape" and p.get("ground") is Dictionary:
		out = _draped(out, p["ground"], t)
	return out


## THE STRAND LAID FLAT, as `lay` says - points evenly spaced along it (meters, x z).
static func _strand_flat(p: Dictionary, rng: RandomNumberGenerator) -> PackedVector2Array:
	var t := float(p["thickness"]) * 0.01
	var L := float(p["length"]) * 0.01
	var loose := float(p["loose"])
	var lay := String(p["lay"])
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = rng.randi()
	var pts := PackedVector2Array()
	var ds := maxf(t * 0.5, 0.002)
	if lay in ["path", "drape"]:
		var raw: Array = []
		var origin: Vector2 = ((p.get("ground", {}) as Dictionary).get("origin", Vector2.ZERO)) if lay == "drape" else Vector2.ZERO
		for q in p["path"]:
			raw.append(origin + (q as Vector2) * 0.01)
		var c := _curve(raw, PackedFloat32Array(), true, 12)
		var line := PackedVector2Array()
		for q in c["pts"]:
			line.append(q as Vector2)
		pts = _even(line, ds)
		# unkempt: it wanders off the line a little, as a dropped cord does
		if loose > 0.0 and pts.size() > 2:
			var along := 0.0
			var bent := PackedVector2Array()
			for i in pts.size():
				var tan := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var off := noise.get_noise_1d(along * 40.0) * loose * maxf(t * 3.0, 0.01)
				bent.append(pts[i] + tan.orthogonal() * off)
				along += ds
			pts = bent
		return pts
	var n := clampi(ceili(L / ds), 8, STRAND_SAMPLES)
	ds = L / float(n)
	var R := float(p["radius"]) * 0.01
	match lay:
		"coil":
			if R <= 0.0:
				R = clampf(0.1 * sqrt(L), t * 5.0, 0.26)
			var tail := int(float(n) * lerpf(0.06, 0.16, loose))
			var a := rng.randf() * TAU
			var mid := Vector2.ZERO
			var r := R
			var loop_left := TAU
			for i in n - tail:
				pts.append(mid + Vector2(cos(a), sin(a)) * r)
				var da := ds / maxf(r, 1e-3)
				a += da
				loop_left -= da
				if loop_left <= 0.0:
					# each loop lands a little off the last, the more so the looser it was coiled
					loop_left = TAU
					mid += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * R * 0.06 * (0.3 + loose)
					r = R * (1.0 + rng.randf_range(-0.1, 0.1) * (0.3 + loose))
			_trail(pts, a + PI * 0.5, n - pts.size(), ds, noise, loose)
		"flemish":
			var a := rng.randf() * TAU
			var r0 := t * 1.5
			var grow := t * (1.02 + loose * 0.4) / TAU
			var r := r0
			var tail := int(float(n) * 0.06)
			for i in n - tail:
				pts.append(Vector2(cos(a), sin(a)) * (r + noise.get_noise_1d(a * 3.0) * loose * t * 0.6))
				var da := ds / maxf(r, 1e-3)
				a += da
				r += grow * da
			_trail(pts, a + PI * 0.5, n - pts.size(), ds, noise, loose)
		_:
			# A TANGLE: a wandering line that turns about and back on itself inside its radius
			if R <= 0.0:
				R = clampf(0.08 * sqrt(L), t * 4.0, 0.22)
			var at := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * R
			var h := rng.randf() * TAU
			var bendy := lerpf(2.0, 7.0, loose) / R
			for i in n:
				pts.append(at)
				var k := noise.get_noise_1d(float(i) * ds / R * 18.0) * bendy
				var out := at.length() / R
				if out > 0.75:
					# turned back toward the middle, the harder the further out
					var back := wrapf(atan2(-at.y, -at.x) - h, -PI, PI)
					k += signf(back) * (out - 0.75) * 14.0 / R
				h += k * ds
				at += Vector2(cos(h), sin(h)) * ds
	return pts


## A LOOSE END running on from where the coiling stopped: [param n] more points heading [param heading].
static func _trail(pts: PackedVector2Array, heading: float, n: int, ds: float, noise: FastNoiseLite, loose: float) -> void:
	var at := pts[pts.size() - 1] if not pts.is_empty() else Vector2.ZERO
	var h := heading
	for i in n:
		h += noise.get_noise_1d(float(i) * 2.0 + 77.0) * ds * lerpf(8.0, 25.0, loose)
		at += Vector2(cos(h), sin(h)) * ds
		pts.append(at)


## [param line] cut into points [param ds] apart along it.
static func _even(line: PackedVector2Array, ds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line.is_empty():
		return out
	out.append(line[0])
	var carry := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var seg := a.distance_to(b)
		var s := ds - carry
		while s <= seg and out.size() < STRAND_SAMPLES:
			out.append(a.lerp(b, s / maxf(seg, 1e-9)))
			s += ds
		carry = seg - (s - ds)
	if out[out.size() - 1].distance_to(line[line.size() - 1]) > ds * 0.3:
		out.append(line[line.size() - 1])
	return out


## THE HEIGHT EACH POINT OF A STRAND RESTS AT (its middle, meters): on the cloth, or over whatever of
## itself it crosses - a round section of width [param t] riding on another - and easing up and down to it
## over a few widths, never a step.
static func _strand_rest(flat: PackedVector2Array, t: float) -> PackedFloat32Array:
	var n := flat.size()
	var ys := PackedFloat32Array()
	ys.resize(n)
	if n == 0:
		return ys
	var ds := flat[0].distance_to(flat[mini(1, n - 1)]) if n > 1 else t
	var skip := ceili(1.6 * t / maxf(ds, 1e-5)) + 1
	var slope := 0.45 * ds
	var cell := maxf(t, 1e-4)
	var grid := {}
	for i in n:
		var p := flat[i]
		var y := t * 0.5
		var c := Vector2i(floori(p.x / cell), floori(p.y / cell))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for j in grid.get(c + Vector2i(dx, dz), []):
					if int(j) >= i - skip:
						continue
					var d := p.distance_to(flat[int(j)])
					if d < t:
						y = maxf(y, ys[int(j)] + sqrt(t * t - d * d))
		if i > 0:
			y = maxf(y, ys[i - 1] - slope)
		ys[i] = y
		var need := y - slope
		var k := i - 1
		while k >= 0 and ys[k] < need:
			ys[k] = need
			need -= slope
			k -= 1
		if not grid.has(c):
			grid[c] = []
		(grid[c] as Array).append(i)
	return ys


## A STRAND DRAPED OVER THE TABLE'S EDGE: where [param line] runs past the top ([param ground]'s `sdf`, its
## outward `normal`), it rolls over the edge and hangs straight down as far as it ran past - to the floor
## (`drop` below the top) at most, and on along the floor beyond that.
static func _draped(line: PackedVector3Array, ground: Dictionary, t: float) -> PackedVector3Array:
	var sdf: Callable = ground["sdf"]
	var normal: Callable = ground["normal"]
	var drop := float(ground.get("drop", 0.7))
	var rho := 0.012 + t * 0.5
	var clear := t * 0.5 + 0.012
	var out := PackedVector3Array()
	for q in line:
		var xz := Vector2(q.x, q.z)
		var d := float(sdf.call(xz))
		if d <= -rho:
			out.append(q)
			continue
		var nn: Vector2 = normal.call(xz)
		var e := xz - nn * d
		var u := d + rho
		if u <= rho * PI * 0.5:
			var th := u / rho
			var h := e - nn * rho + nn * (rho + clear) * sin(th)
			out.append(Vector3(h.x, q.y - rho + rho * cos(th), h.y))
			continue
		var rest := u - rho * PI * 0.5
		var y := q.y - rho - rest
		var h := e + nn * clear
		if y < -drop + t * 0.5:
			# on the floor, running on out from under the table
			h += nn * (-drop + t * 0.5 - y)
			y = -drop + t * 0.5
		out.append(Vector3(h.x, y, h.y))
	return out


## [param n] circles of radius [param r], [param m] points each.
static func _rings_of(n: int, r: float, m: int) -> Array:
	var ring := _circle(r, m)
	var out: Array = []
	for i in n:
		out.append(ring)
	return out


static func _circle(r: float, m: int) -> Array:
	var ring: Array = []
	for j in m:
		var a := TAU * float(j) / float(m)
		ring.append(Vector2(cos(a), sin(a)) * r)
	return ring


static func _sharp(m: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(m)
	return b


## Where [param s] (meters along [param spine], its lengths [param along]) is: `[point, tangent]`.
static func _at_length(spine: Array, along: PackedFloat32Array, s: float) -> Array:
	var i := clampi(along.bsearch(s), 1, along.size() - 1)
	var a: Vector3 = spine[i - 1]
	var b: Vector3 = spine[i]
	var f := clampf((s - along[i - 1]) / maxf(along[i] - along[i - 1], 1e-9), 0.0, 1.0)
	var tan := (b - a).normalized() if (b - a).length() > 1e-9 else Vector3.RIGHT
	return [a.lerp(b, f), tan]


## [param src] moved by [param xf] onto the end of [param dst] (its copies' marks left off: the part's own
## placing gives them).
static func _xf_append(dst: Tris, src: Tris, xf: Transform3D) -> void:
	var nb := xf.basis.inverse().transposed()
	for i in src.v.size():
		dst.v.append(xf * src.v[i])
		dst.n.append((nb * src.n[i]).normalized())
	dst.uv.append_array(src.uv)
	dst.uv2.append_array(src.uv2)


## A SWEEP: an outline carried along [param spine] (meters). [param rings] holds each spine point's
## outline (Vector2s in meters, as many in each, all wound the same way), drawn across the path -
## its x across, its y the other way: the thing's x and z where the path runs up; the outline's
## frame is carried along the path without twisting. [param corner] marks the path's crisp corners,
## whose rings are mitered (laid in the plane halfway between the two directions and stretched
## across it, so the rod keeps its width round the bend instead of pinching); [param sharp] marks
## the outline's own corners, kept crisp along their length. A [param hollow] above 0 is the inner
## outline's size (as a part of the outer one) there: hollow and open, a pipe - otherwise solid,
## closed at both ends. Faces' normals come from the surface itself, so a twist or a flare shades
## as it is shaped.
static func _sweep(spine: Array, corner: PackedByteArray, rings: Array, sharp: PackedByteArray, hollow: PackedFloat32Array) -> Tris:
	var g := Tris.new()
	var n := spine.size()
	if n < 2:
		return g
	var m := (rings[0] as Array).size()
	var dirs: Array = []
	for i in n - 1:
		var dv: Vector3 = (spine[i + 1] as Vector3) - (spine[i] as Vector3)
		dirs.append(dv.normalized() if dv.length() > 1e-9 else (dirs[-1] if not dirs.is_empty() else Vector3.UP))
	var tans: Array = []
	for i in n:
		if i == 0:
			tans.append(dirs[0])
		elif i == n - 1:
			tans.append(dirs[n - 2])
		elif i < corner.size() and corner[i] == 1 and ((dirs[i - 1] as Vector3) + (dirs[i] as Vector3)).length() > 1e-3:
			tans.append(((dirs[i - 1] as Vector3) + (dirs[i] as Vector3)).normalized())
		else:
			var dv: Vector3 = (spine[i + 1] as Vector3) - (spine[i - 1] as Vector3)
			tans.append(dv.normalized() if dv.length() > 1e-9 else dirs[i])
	# THE FRAME: across starts as the thing's x (its z for a path that starts along x) and is carried
	var t0: Vector3 = tans[0]
	var side := Vector3.RIGHT if absf(t0.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	side = (side - t0 * side.dot(t0)).normalized()
	var frames: Array = []
	for i in n:
		var t: Vector3 = tans[i]
		if i > 0:
			var prev: Vector3 = tans[i - 1]
			var ax := prev.cross(t)
			if ax.length() > 1e-6:
				side = side.rotated(ax.normalized(), prev.angle_to(t))
		side = (side - t * side.dot(t)).normalized()
		frames.append([side, side.cross(t).normalized()])
	var place := func(i: int, q: Vector2) -> Vector3:
		var f: Array = frames[i]
		var off: Vector3 = (f[0] as Vector3) * q.x + (f[1] as Vector3) * q.y
		if i > 0 and i < n - 1 and i < corner.size() and corner[i] == 1:
			var w: Vector3 = (dirs[i] as Vector3) - (dirs[i - 1] as Vector3)
			if w.length() > 1e-6:
				w = w.normalized()
				var c := maxf((tans[i] as Vector3).dot(dirs[i - 1]), 0.25)
				off += w * off.dot(w) * (1.0 / c - 1.0)
		return (spine[i] as Vector3) + off
	var outer: Array = []
	var inner: Array = []
	var is_hollow := false
	for i in n:
		var ring: Array = rings[i]
		var row := PackedVector3Array()
		var row_in := PackedVector3Array()
		var mid := Vector2.ZERO
		for q in ring:
			mid += q
		mid /= float(m)
		for k in m:
			row.append(place.call(i, ring[k]))
			if hollow[i] > 0.0:
				is_hollow = true
				row_in.append(place.call(i, mid + ((ring[k] as Vector2) - mid) * hollow[i]))
		outer.append(row)
		inner.append(row_in)
	var along := _lengths(spine)
	var total := maxf(along[n - 1], 1e-6)
	var around := PackedFloat32Array([0.0])
	for k in m:
		around.append(around[k] + ((rings[0] as Array)[(k + 1) % m] as Vector2).distance_to((rings[0] as Array)[k]))
	var perim := maxf(around[m], 1e-9)
	_sweep_skin(g, outer, tans, corner, sharp, along, total, around, perim, 1.0)
	if is_hollow:
		_sweep_skin(g, inner, tans, corner, sharp, along, total, around, perim, -1.0)
	for end in [0, n - 1]:
		var t: Vector3 = (tans[end] as Vector3) * (-1.0 if end == 0 else 1.0)
		var o: PackedVector3Array = outer[end]
		var v := float(end) / float(n - 1)
		if is_hollow:
			var ins: PackedVector3Array = inner[end]
			for k in m:
				var k2 := (k + 1) % m
				g.quad(o[k], o[k2], ins[k2], ins[k], t, t, t, t, Vector2(around[k] / perim, v), Vector2(around[k + 1] / perim, v),
					Vector2(around[k + 1] / perim, v), Vector2(around[k] / perim, v), v, v, v, v)
			continue
		# THE END, closed: the outline cut into triangles - or fanned from the path, one that crosses itself
		var flat := PackedVector2Array()
		for q in rings[end]:
			flat.append(q)
		var tris := Geometry2D.triangulate_polygon(flat)
		if tris.is_empty():
			for k in m:
				tris.append_array([-1, k, (k + 1) % m])
		for j in range(0, tris.size() - 2, 3):
			var pa: Vector3 = spine[end] if tris[j] < 0 else o[tris[j]]
			g.tri(pa, o[tris[j + 1]], o[tris[j + 2]], t, t, t, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5),
				Vector2(v, 0.0), Vector2(v, 0.0), Vector2(v, 0.0))
	var big := 0.0
	for ring in rings:
		var per := 0.0
		for k in m:
			per += ((ring as Array)[(k + 1) % m] as Vector2).distance_to((ring as Array)[k])
		big = maxf(big, per)
	g.girth = maxf(big * 100.0, 0.5)
	g.height = total * 100.0
	g.top = spine[n - 1]
	return g


## One skin of a sweep, its faces turned out ([param side] 1) or in (-1): a quad between each pair of
## rings, each corner's normal from the surface round it - from one side only across a crisp corner
## of the outline or the path. UV is (round the outline, along the path), and the second UV's x is
## how far along the path, which is where an ornament's band lies.
static func _sweep_skin(g: Tris, rows: Array, tans: Array, corner: PackedByteArray, sharp: PackedByteArray,
		along: PackedFloat32Array, total: float, around: PackedFloat32Array, perim: float, side: float) -> void:
	var n := rows.size()
	var m := (rows[0] as PackedVector3Array).size()
	var at := func(i: int, k: int) -> Vector3:
		return (rows[clampi(i, 0, n - 1)] as PackedVector3Array)[(k + m) % m]
	# a corner's normal, for the face beyond it in [param di] (+1 ahead along the path, -1 behind) and
	# [param dk] (+1 the next point round, -1 the one before)
	var normal := func(i: int, k: int, di: int, dk: int) -> Vector3:
		var crisp_i := i == 0 or i == n - 1 or (i < corner.size() and corner[i] == 1)
		var a: Vector3
		if crisp_i:
			a = (at.call(i + 1, k) - at.call(i, k)) if di > 0 else (at.call(i, k) - at.call(i - 1, k))
			if a.length() < 1e-9:
				a = (at.call(i + 1, k) - at.call(i - 1, k))
		else:
			a = at.call(i + 1, k) - at.call(i - 1, k)
		var b: Vector3
		if sharp[(k + m) % m] == 1:
			b = (at.call(i, k + 1) - at.call(i, k)) if dk > 0 else (at.call(i, k) - at.call(i, k - 1))
		else:
			b = at.call(i, k + 1) - at.call(i, k - 1)
		# every outline is wound the same way, so along x round is always out (a point - a tip - faces
		# along the path, out of the end it is nearer)
		var nn := a.cross(b) * side
		if nn.length() < 1e-12:
			return (tans[i] as Vector3) * (1.0 if i * 2 >= n else -1.0)
		return nn.normalized()
	for i in n - 1:
		var v0 := along[i] / total
		var v1 := along[i + 1] / total
		for k in m:
			var u0 := around[k] / perim
			var u1 := around[k + 1] / perim
			g.quad(at.call(i, k), at.call(i, k + 1), at.call(i + 1, k + 1), at.call(i + 1, k),
				normal.call(i, k, 1, 1), normal.call(i, k + 1, 1, -1), normal.call(i + 1, k + 1, -1, -1), normal.call(i + 1, k, -1, 1),
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), v0, v0, v1, v1)


## A SHEET into [param g]: its outline (a named one, or `points`), its base at the origin and its
## length along +z, a little thickness, the tip curled up by `bend` and the sides lifted by
## `fold`; placed by [param xf].
static func _sheet(g: Tris, p: Dictionary, xf: Transform3D) -> void:
	var sz: Vector2 = (p["size"] as Vector2) * 0.01
	var bend := float(p.get("bend", 0.0))
	var fold := float(p.get("fold", 0.0))
	var thick := float(p.get("thickness", 0.08)) * 0.01
	var lift := func(x: float, z: float, w: float, l: float) -> float:
		var t := clampf(z / maxf(l, 1e-6), 0.0, 1.0)
		var s := clampf(x / maxf(w * 0.5, 1e-6), -1.0, 1.0)
		return bend * l * 0.35 * t * t + fold * w * 0.3 * s * s
	var pts: Array = p.get("points", [])
	if pts.size() >= 3:
		var poly := PackedVector2Array()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in pts:
			var v := (q as Vector2) * 0.01
			poly.append(v)
			lo = lo.min(v)
			hi = hi.max(v)
		var tris := Geometry2D.triangulate_polygon(poly)
		var w := hi.x - lo.x
		var l := hi.y - lo.y
		var top := func(v: Vector2) -> Vector3:
			return Vector3(v.x, thick + float(lift.call(v.x - (lo.x + hi.x) * 0.5, v.y - lo.y, w, l)), v.y)
		for t in range(0, tris.size() - 2, 3):
			var a := poly[tris[t]]
			var b := poly[tris[t + 1]]
			var c := poly[tris[t + 2]]
			for side in [1.0, -1.0]:
				var pa: Vector3 = top.call(a) + Vector3(0, 0 if side > 0.0 else -thick, 0)
				var pb: Vector3 = top.call(b) + Vector3(0, 0 if side > 0.0 else -thick, 0)
				var pc: Vector3 = top.call(c) + Vector3(0, 0 if side > 0.0 else -thick, 0)
				var nn := (xf.basis * Vector3(0, side, 0)).normalized()
				var uva := (a - lo) / Vector2(maxf(w, 1e-6), maxf(l, 1e-6))
				var uvb := (b - lo) / Vector2(maxf(w, 1e-6), maxf(l, 1e-6))
				var uvc := (c - lo) / Vector2(maxf(w, 1e-6), maxf(l, 1e-6))
				g.tri(xf * pa, xf * pb, xf * pc, nn, nn, nn, uva, uvb, uvc, Vector2(1, 0) if side > 0.0 else Vector2.ZERO,
					Vector2(1, 0) if side > 0.0 else Vector2.ZERO, Vector2(1, 0) if side > 0.0 else Vector2.ZERO)
		# ITS EDGE, all round: a slab, not a sheet of paper standing off the cloth
		var mid := Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var ta: Vector3 = top.call(a)
			var tb: Vector3 = top.call(b)
			var out := Vector2(b.y - a.y, a.x - b.x).normalized()
			if out.dot((a + b) * 0.5 - mid) < 0.0:
				out = -out
			var nn := (xf.basis * Vector3(out.x, 0.0, out.y)).normalized()
			g.quad(xf * (ta - Vector3(0, thick, 0)), xf * (tb - Vector3(0, thick, 0)), xf * tb, xf * ta, nn, nn, nn, nn,
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), 0.0, 0.0, 1.0, 1.0)
		return
	var outline := String(p.get("outline", "leaf"))
	var nl := 14
	var nw := 6
	var grid: Array = []
	# A FEATHER is not a leaf: one vane narrower than the other, and the whole of it curving a little
	# to the narrow side
	var narrow := 0.5 if outline == "feather" else 1.0
	var sweep := 0.06 if outline == "feather" else 0.0
	for j in nl + 1:
		var t := float(j) / float(nl)
		var hw := sz.x * 0.5 * _outline_w(outline, t)
		var row: Array = []
		for i in nw + 1:
			var s := -1.0 + 2.0 * float(i) / float(nw)
			var x := s * hw * (narrow if s < 0.0 else 1.0) - sweep * sz.y * sin(PI * t)
			var z := t * sz.y
			row.append(Vector3(x, thick + float(lift.call(x, z, sz.x, sz.y)), z))
		grid.append(row)
	# ITS EDGE: down each side and across the base and the tip
	var rim: Array = []
	for j in nl + 1:
		rim.append(grid[j][0])
	for j in range(nl, -1, -1):
		rim.append(grid[j][nw])
	for k in rim.size() - 1:
		var a: Vector3 = rim[k]
		var b: Vector3 = rim[k + 1]
		if a.distance_to(b) < 1e-6:
			continue
		var out := Vector3(b.z - a.z, 0.0, a.x - b.x).normalized()
		if out.dot((a + b) * 0.5 - Vector3(0.0, 0.0, sz.y * 0.5)) < 0.0:
			out = -out
		var nn := (xf.basis * out).normalized()
		g.quad(xf * (a - Vector3(0, thick, 0)), xf * (b - Vector3(0, thick, 0)), xf * b, xf * a, nn, nn, nn, nn,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), 0.0, 0.0, 1.0, 1.0)
	for side in [1.0, -1.0]:
		for j in nl:
			for i in nw:
				var cs: Array = []
				for q in [[j, i], [j, i + 1], [j + 1, i + 1], [j + 1, i]]:
					var jj := int(q[0])
					var ii := int(q[1])
					var pos: Vector3 = grid[jj][ii]
					var a: Vector3 = grid[jj][mini(ii + 1, nw)] - grid[jj][maxi(ii - 1, 0)]
					var b: Vector3 = grid[mini(jj + 1, nl)][ii] - grid[maxi(jj - 1, 0)][ii]
					var nn := b.cross(a)
					nn = nn.normalized() if nn.length() > 1e-12 else Vector3.UP
					if nn.y < 0.0:
						nn = -nn
					if side < 0.0:
						pos -= Vector3(0, thick, 0)
						nn = -nn
					cs.append([xf * pos, (xf.basis * nn).normalized(), Vector2(float(ii) / nw, float(jj) / nl)])
				g.quad(cs[0][0], cs[1][0], cs[2][0], cs[3][0], cs[0][1], cs[1][1], cs[2][1], cs[3][1], cs[0][2], cs[1][2],
					cs[2][2], cs[3][2], 0.0, 0.0, 0.0, 0.0)


## A named outline's half-width at [param t] along its length, 0 at the base and 1 at the tip.
static func _outline_w(kind: String, t: float) -> float:
	match kind:
		"petal":
			return clampf(1.25 * sqrt(t) * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.55), 0.0, 1.0)
		"feather":
			return pow(sin(PI * pow(t, 0.75)), 0.45) * (0.85 + 0.15 * t)
		"oval":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * t - 1.0, 2.0)))
		"rect":
			return 1.0
	return pow(sin(PI * t), 0.9)


## A FLOWER HEAD: rings of petals round a small middle, the inner rings shorter and more upright.
static func _bloom(p: Dictionary, rng: RandomNumberGenerator) -> Tris:
	var g := Tris.new()
	var R := float(p["radius"])
	var cup := float(p["cup"])
	var layers := int(p["layers"])
	var n := int(p["petals"])
	for k in layers:
		var length := R * (1.0 - 0.22 * float(k))
		var tilt := deg_to_rad(lerpf(8.0, 70.0, cup) + float(k) * lerpf(10.0, 22.0, cup))
		for i in n:
			var yaw := TAU * (float(i) + 0.5 * float(k)) / float(n) + rng.randf_range(-0.08, 0.08)
			var petal := {"size": Vector2(length * float(p["width"]), length), "bend": 0.25 - cup * 0.6, "fold": 0.35,
				"thickness": 0.05, "outline": "petal", "points": []}
			var xf := Transform3D(Basis(Vector3.UP, -yaw + PI * 0.5) * Basis(Vector3.RIGHT, -tilt), Vector3(0.0, 0.002 * float(k) + R * 0.04, 0.0))
			_sheet(g, petal, xf)
	var heart := _ball(Vector3(R * 0.36, R * 0.24, R * 0.36), 0.3, false, rng)
	heart.lift(R * 0.01 * 0.06)
	g.append(heart)
	g.measure()
	return g


## AN OUTLINE RAISED STRAIGHT UP, resting on y = 0: its walls - round where the outline is round,
## crisp where it turns a corner - narrowed toward the top by the taper, its top edge cut back by
## the bevel, its top and its bottom. With a WALL it is hollow, as a tray is: a rim round an inner
## floor as thick as the wall, the inside's walls facing in. The inside is the outline drawn smaller
## about its middle, so a star tray's wall is thinner at its points than in its notches.
static func _extrude(p: Dictionary) -> Tris:
	var g := Tris.new()
	var pts := _outline2(p)
	if pts.size() < 3:
		return g
	var h := float(p["height"]) * 0.01
	var taper := float(p.get("taper", 0.0))
	var wall := float(p.get("wall", 0.0)) * 0.01
	var mid := Vector2.ZERO
	for q in pts:
		mid += q
	mid /= float(pts.size())
	var reach := 0.0
	for q in pts:
		reach += (q as Vector2).distance_to(mid)
	reach = maxf(reach / float(pts.size()), 0.001)
	var bevel := 0.0 if wall > 0.0 else minf(float(p.get("bevel", 0.0)) * 0.01, minf(h * 0.5, reach * 0.4))
	# a point of the outline at height y, drawn smaller about the middle by k and by the taper there
	var ring := func(k: float, y: float) -> Array:
		var s := k * (1.0 - taper * y / maxf(h, 1e-6))
		var out: Array = []
		for q in pts:
			var v: Vector2 = mid + ((q as Vector2) - mid) * s
			out.append(Vector3(v.x, y, v.y))
		return out
	var n := pts.size()
	# along the outline, for laying out a surface's pattern round it
	var along := PackedFloat32Array([0.0])
	for i in n:
		along.append(along[i] + (pts[i] as Vector2).distance_to(pts[(i + 1) % n]))
	var perim := maxf(along[n], 1e-6)
	# a warped extrude's walls are cut into bands, so they can bend
	var bands := ceili(h / WARP_STEP) if _fine(p) else 1
	var walls := func(k: float, y0: float, y1: float, side: float) -> void:
		for b in bands:
			_extrude_wall(g, ring.call(k, lerpf(y0, y1, float(b) / bands)), ring.call(k, lerpf(y0, y1, float(b + 1) / bands)),
				along, perim, h, side)
	if wall <= 0.0:
		walls.call(1.0, 0.0, h - bevel, 1.0)
		if bevel > 0.0:
			_extrude_wall(g, ring.call(1.0, h - bevel), ring.call(1.0 - bevel / reach, h), along, perim, h, 1.0)
		_extrude_face(g, ring.call(1.0 - bevel / reach, h), 1.0, h)
		_extrude_face(g, ring.call(1.0, 0.0), -1.0, h)
	else:
		var k_in := clampf(1.0 - wall / reach, 0.15, 0.95)
		var floor_y := minf(wall, h * 0.5)
		walls.call(1.0, 0.0, h, 1.0)
		walls.call(k_in, floor_y, h, -1.0)
		_extrude_rim(g, ring.call(1.0, h), ring.call(k_in, h), h)
		_extrude_face(g, ring.call(k_in, floor_y), 1.0, h)
		_extrude_face(g, ring.call(1.0, 0.0), -1.0, h)
	g.girth = perim * 100.0
	g.height = h * 100.0
	g.top = Vector3(mid.x, h, mid.y)
	return g


## An extrude's outline in meters about its own middle, wound one way (its area positive, so an
## edge's outside is to its right): a named one at its `size`, or its own `points`.
static func _outline2(p: Dictionary) -> Array:
	var out: Array = []
	var own: Array = p.get("points", [])
	var half: Vector2 = (p.get("size", Vector2(6.0, 6.0)) as Vector2) * 0.005
	var n := int(p.get("sides", 6))
	if own.size() >= 3:
		for q in own:
			out.append((q as Vector2) * 0.01)
	else:
		match String(p.get("outline", "polygon")):
			"rect":
				out = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
			"circle":
				for i in 48:
					var a := TAU * float(i) / 48.0
					out.append(Vector2(cos(a) * half.x, sin(a) * half.y))
			"star":
				for i in n * 2:
					var a := -PI * 0.5 + PI * float(i) / float(n)
					var r := 1.0 if i % 2 == 0 else 0.48
					out.append(Vector2(cos(a) * half.x * r, sin(a) * half.y * r))
			"lens":
				# two arcs meeting in a point at each side: a leaf's cross-section, an eye
				for i in 48:
					var a := TAU * float(i) / 48.0
					out.append(Vector2(cos(a) * half.x, sin(a) * absf(sin(a)) * half.y))
			"drop":
				# round behind, drawn to a point toward the reader
				for i in 48:
					var a := TAU * float(i) / 48.0
					out.append(Vector2(sin(a) * pow(absf(sin(a * 0.5)), 1.4) * half.x * 1.3, cos(a) * half.y))
			"heart":
				# the heart curve, its point toward the reader
				for i in 48:
					var t := TAU * float(i) / 48.0
					var x := 16.0 * pow(sin(t), 3.0)
					var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
					out.append(Vector2(x / 16.0 * half.x, -(y + 2.5) / 14.5 * half.y))
			_:
				for i in n:
					var a := -PI * 0.5 + TAU * float(i) / float(n)
					out.append(Vector2(cos(a) * half.x, sin(a) * half.y))
	var clean: Array = []
	for q in out:
		if clean.is_empty() or (q as Vector2).distance_to(clean[-1]) > 1e-5:
			clean.append(q)
	while clean.size() > 1 and (clean[0] as Vector2).distance_to(clean[-1]) <= 1e-5:
		clean.pop_back()
	var area := 0.0
	for i in clean.size():
		var a2: Vector2 = clean[i]
		var b2: Vector2 = clean[(i + 1) % clean.size()]
		area += a2.x * b2.y - b2.x * a2.y
	if area < 0.0:
		clean.reverse()
	return clean


## A band of wall from ring [param lo] up to ring [param hi] (each a point per outline point), its
## faces turned out ([param side] 1) or in (-1): smooth across a gentle turn of the outline, crisp
## at a corner.
static func _extrude_wall(g: Tris, lo: Array, hi: Array, along: PackedFloat32Array, perim: float, h: float, side: float) -> void:
	var n := lo.size()
	var faces: Array = []
	for i in n:
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[(i + 1) % n]
		var c: Vector3 = hi[i]
		var out2 := Vector3(b.z - a.z, 0.0, a.x - b.x) * side
		var fn := (b - a).cross(c - a)
		if fn.length() < 1e-12:
			fn = out2
		fn = fn.normalized()
		if fn.dot(out2) < 0.0:
			fn = -fn
		faces.append(fn)
	for i in n:
		var j := (i + 1) % n
		var na: Vector3 = faces[i]
		var nb: Vector3 = faces[i]
		if (faces[(i - 1 + n) % n] as Vector3).dot(faces[i]) > cos(deg_to_rad(35.0)):
			na = ((faces[(i - 1 + n) % n] as Vector3) + (faces[i] as Vector3)).normalized()
		if (faces[j] as Vector3).dot(faces[i]) > cos(deg_to_rad(35.0)):
			nb = ((faces[j] as Vector3) + (faces[i] as Vector3)).normalized()
		var u0 := along[i] / perim
		var u1 := along[i + 1] / perim
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[j]
		var c: Vector3 = hi[j]
		var d: Vector3 = hi[i]
		g.quad(a, b, c, d, na, nb, nb, na, Vector2(u0, a.y / maxf(h, 1e-6)), Vector2(u1, b.y / maxf(h, 1e-6)),
			Vector2(u1, c.y / maxf(h, 1e-6)), Vector2(u0, d.y / maxf(h, 1e-6)), a.y / maxf(h, 1e-6), b.y / maxf(h, 1e-6),
			c.y / maxf(h, 1e-6), d.y / maxf(h, 1e-6))


## A flat face over ring [param r], facing up ([param up] 1) or down (-1): the outline cut into
## triangles, in and out as it goes - or, an outline that crosses itself, fanned from its middle.
static func _extrude_face(g: Tris, r: Array, up: float, h: float) -> void:
	var flat := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in r:
		var v := Vector2((q as Vector3).x, (q as Vector3).z)
		flat.append(v)
		lo = lo.min(v)
		hi = hi.max(v)
	var span := (hi - lo).max(Vector2(1e-6, 1e-6))
	var nrm := Vector3(0.0, up, 0.0)
	var y := (r[0] as Vector3).y
	var hf := y / maxf(h, 1e-6)
	var tris := Geometry2D.triangulate_polygon(flat)
	if tris.is_empty():
		var c := Vector3.ZERO
		for q in r:
			c += q
		c /= float(r.size())
		for i in r.size():
			tris.append_array([-1, i, (i + 1) % r.size()])
		for t in range(0, tris.size(), 3):
			var pa: Vector3 = c if tris[t] < 0 else r[tris[t]]
			var pb: Vector3 = r[tris[t + 1]]
			var pc: Vector3 = r[tris[t + 2]]
			g.tri(pa, pb, pc, nrm, nrm, nrm, (Vector2(pa.x, pa.z) - lo) / span, (Vector2(pb.x, pb.z) - lo) / span,
				(Vector2(pc.x, pc.z) - lo) / span, Vector2(hf, 0.0), Vector2(hf, 0.0), Vector2(hf, 0.0))
		return
	for t in range(0, tris.size(), 3):
		var pa: Vector3 = r[tris[t]]
		var pb: Vector3 = r[tris[t + 1]]
		var pc: Vector3 = r[tris[t + 2]]
		g.tri(pa, pb, pc, nrm, nrm, nrm, (flat[tris[t]] - lo) / span, (flat[tris[t + 1]] - lo) / span,
			(flat[tris[t + 2]] - lo) / span, Vector2(hf, 0.0), Vector2(hf, 0.0), Vector2(hf, 0.0))


## A hollow extrude's rim: the band across its top from ring [param outer] in to ring [param inner].
static func _extrude_rim(g: Tris, outer: Array, inner: Array, h: float) -> void:
	var n := outer.size()
	for i in n:
		var j := (i + 1) % n
		g.quad(outer[i], outer[j], inner[j], inner[i], Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
			Vector2(float(i) / n, 0.0), Vector2(float(i + 1) / n, 0.0), Vector2(float(i + 1) / n, 1.0), Vector2(float(i) / n, 1.0),
			1.0, 1.0, 1.0, 1.0)


# --- footprints ------------------------------------------------------------------------------

## The convex outline, seen from above, of everything in [param pts] up to [param below] meters
## high - and of where the surface crosses that height, so a straight wall's outline is its own
## and not only its corners'.
static func _foot(pts: PackedVector3Array, below: float) -> PackedVector2Array:
	var flat := PackedVector2Array()
	for t in range(0, pts.size() - 2, 3):
		var tri := [pts[t], pts[t + 1], pts[t + 2]]
		for i in 3:
			var a: Vector3 = tri[i]
			var b: Vector3 = tri[(i + 1) % 3]
			if a.y <= below:
				flat.append(Vector2(a.x, a.z))
			if (a.y - below) * (b.y - below) < 0.0:
				var f := (below - a.y) / (b.y - a.y)
				var c := a.lerp(b, f)
				flat.append(Vector2(c.x, c.z))
	return Geometry2D.convex_hull(flat) if flat.size() >= 3 else PackedVector2Array()


## The convex outline of every point in [param pts] lower than [param below], seen from above.
static func _hull(pts: PackedVector3Array, below: float) -> PackedVector2Array:
	var flat := PackedVector2Array()
	for q in pts:
		if q.y <= below:
			flat.append(Vector2(q.x, q.z))
	return Geometry2D.convex_hull(flat) if flat.size() >= 3 else PackedVector2Array()


## A GROWING TRIANGLE LIST - positions, normals and both UV channels, three per triangle - with
## the part's measure (its girth and height in centimeters, for laying out ornament) and the top
## of it where a wick goes.
class Tris:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	## Once placed, four floats a vertex: the middle of its copy (x, y, z) and the copy's own number
	## (0..1), which a pattern centers on and varies by ([method placed])
	var copy := PackedFloat32Array()
	## Where a candle's flames stand on it, in its own space
	var wicks := PackedVector3Array()
	var girth := 10.0
	var height := 10.0
	var top := Vector3.ZERO

	## One triangle, wound so its front faces the way its normals point (Godot draws clockwise
	## fronts): no builder's index arithmetic has to get the winding right.
	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ta: Vector2, tb: Vector2,
			tc: Vector2, sa: Vector2, sb: Vector2, sc: Vector2) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			v.append_array([a, c, b])
			n.append_array([na, nc, nb])
			uv.append_array([ta, tc, tb])
			uv2.append_array([sa, sc, sb])
		else:
			v.append_array([a, b, c])
			n.append_array([na, nb, nc])
			uv.append_array([ta, tb, tc])
			uv2.append_array([sa, sb, sc])

	## A quad as two triangles; [param ha]..[param hd] are each corner's height up the part (0..1).
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
			ta: Vector2, tb: Vector2, tc: Vector2, td: Vector2, ha: float, hb: float, hc: float, hd: float) -> void:
		tri(a, b, c, na, nb, nc, ta, tb, tc, Vector2(ha, 0), Vector2(hb, 0), Vector2(hc, 0))
		tri(a, c, d, na, nc, nd, ta, tc, td, Vector2(ha, 0), Vector2(hc, 0), Vector2(hd, 0))

	func append(o: Tris) -> void:
		v.append_array(o.v)
		n.append_array(o.n)
		uv.append_array(o.uv)
		uv2.append_array(o.uv2)
		copy.append_array(o.copy)

	func lift(dy: float) -> void:
		for i in v.size():
			v[i] = v[i] + Vector3(0.0, dy, 0.0)

	## Girth, height and top from the triangles themselves, for shapes made of pieces.
	func measure() -> void:
		if v.is_empty():
			return
		var box := AABB(v[0], Vector3.ZERO)
		for q in v:
			box = box.expand(q)
		girth = PI * (box.size.x + box.size.z) * 50.0
		height = box.size.y * 100.0
		top = Vector3(box.get_center().x, box.end.y, box.get_center().z)

	## Every copy of this geometry at [param xforms], as one - each vertex carrying its copy's middle
	## and number ([member copy]; [param ids] are the copies' places among the part's own).
	func placed(xforms: Array, ids: Array = []) -> Tris:
		var out := Tris.new()
		out.girth = girth
		out.height = height
		out.top = top
		var mid := Vector3.ZERO
		if not v.is_empty():
			var box := AABB(v[0], Vector3.ZERO)
			for q in v:
				box = box.expand(q)
			mid = box.get_center()
		for k in xforms.size():
			var t: Transform3D = xforms[k]
			var nb := t.basis.inverse().transposed()
			for i in v.size():
				out.v.append(t * v[i])
				out.n.append((nb * n[i]).normalized())
			out.uv.append_array(uv)
			out.uv2.append_array(uv2)
			var c := t * mid
			var block := PackedFloat32Array([c.x, c.y, c.z, fposmod(float(ids[k] if k < ids.size() else k) * 0.618034 + 0.137, 1.0)])
			while block.size() < v.size() * 4:
				block.append_array(block.duplicate())
			block.resize(v.size() * 4)
			out.copy.append_array(block)
		return out

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		var flags := 0
		if copy.size() == v.size() * 4:
			arrays[Mesh.ARRAY_CUSTOM0] = copy
			flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		return m

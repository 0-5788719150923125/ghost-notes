extends RefCounted
class_name TablePaint

## TablePaint - THE PAINTED SURFACE, played: a part of [TableWork] (next/painted_surface.md). Every part with a `skin` on the
## table, the design painted on it ([Skins], the episode's `skin.json`), and the `paint` law ([Motions]) that lays it on - a
## tool fetched from where it rests, loaded from its paint, pressed onto the surface and moved over each element as its
## program has it ([method Skins.program]), back to the paint when it runs dry, and back where it rests when the act is done.
##
## A PURE FUNCTION OF SHOW TIME, as all the work is: each element is shown where its tool has been by its reveal map and the
## moments the schedule gives its strokes ([method spans]); a tool's place, the bend of its hairs, the paint on its tip and the
## give of a sponge are worked out from the time ([method pose], [method tick]) - nothing is painted frame by frame. THE PAINT
## IS COMPOSED IN 2D, an element a sprite in its order, in two small viewports of the skin's own (its color, and what its
## finish is - rough, metallic, glittering), which the part's own shader lays over it from its front (prop.gdshader).
##
## A HELD TOOL STANDS IN NOTHING (feedback 0016): it is held the way its work asks - a brush by its tip, a pad flat, a sponge flat to
## spread and by its corner to dab and to dip ([method _contact_for]) - and at every place its program keeps, found before the bake
## begins, it points the way nearest a hand's that keeps its own surface out of the surface it works on and what holds it
## ([method _cleared]), and out of the wall of the pot it dips into ([method _pot_clear]); a sponge pressed in gives back to the
## surface it is pressed on ([constant GIVE]).

## The skin's composed pictures, pixels a millimeter.
const CANVAS_PX := Skins.PX_MM
## A ACT'S OWN STEPS (seconds, at a hand's pace): fetched from where the tool rests to its work, a load from its paint, a rinse,
## a move between elements, and back where it was.
const FETCH := 2.0
const LOAD := 3.2
const RINSE := 4.0
const MOVE := 1.4
const RETURN := 2.0
## HOW FAR AN ACT'S STROKES MAY BE SLOWED (a share of a hand's pace) before what is left is rests between its elements, the
## longest one rest is (seconds), and how far they may be hurried. SLOWED RATHER THAN PUT DOWN (2026-11-10, the author: "between 6:30
## and 8:30 - there is no animation at all"): a live voice says its words slower than the plan's guess (732687's intro, 442 s guessed,
## about 510 s said), and the last acts of a beat, sized once the voice's pace is known, take up all of what the first were not given -
## at 1.6 and 4 s they put their tools down and the hand waited out the words.
const SLOW_MOST := 2.5
const REST_MOST := 6.0
const QUICK_MOST := 0.4
## The least an act that paints is hurried to, of its natural length: hardly at all - a face is never rushed (at 0.6, 856886's was
## done in 9:22 under ten minutes of words).
const LEAST := 0.85
## How far over a surface a tool's tip is held as it touches (meters), and how high it lifts on its way from where it rests (meters).
const TOUCH := 0.00025
## A BRUSH'S TIP PRESSED PAST ITS POINT (feedback 0052, 2026-11-07: "Why are we painting with the very tip of it? There is something like
## a needlepoint's worth of brush actually touching the mask here. Yet when we move the brush back and forth, it bends a lot ... We need to
## push a little BEYOND that tip, such that it is FORCED to bend in one direction or another, and such that a larger (or smaller) portion
## of the bristles are touching the mask at any given time we're painting, depending upon how much we want to apply"): at its hardest
## this share of its hairs' length, as deep as its belly is laid ([constant BELLY_PUSH]); a line presses it as far as the share of the
## brush it is wide ([method Skins.program], `LINE_PRESS_LEAST` at the least) - it had been 0.6 mm whatever the line.
const TIP_PUSH := 0.2
## A KEY IS PRESSED at more than this (0-1): a line pressed as far as it is wide, a fill eased off its edge, are pressed however
## lightly - more than half had been, and a fine line went unpulled and lifted along its way.
const PRESSED := 0.05
const FETCH_LIFT := 0.08
## HOW A TOOL IS HELD over the surface: its handle out of the surface, up along it and out to the side its work is on - never
## toward the camera, where it would hide the work, and never across what it has painted (shares, then made a direction); and over
## its paint, upright and leaning toward the camera. A brush drawn along a stroke leans the way it goes instead ([constant HELD_PULL]).
const HELD_OUT := 0.55
const HELD_UP := 0.35
## ...A BRUSH LAYING A FILL OR BLENDING held low, on the side of its hairs (`belly`): this much out of the surface where HELD_OUT is
## held, about 30 degrees off it (feedback 0028: "You don't paint with the tip of the bristles, you paint with the side of them").
const HELD_LOW := 0.2
## ...and pressed in this share of its hairs' length, so they bow and lay their side on it ([method _bend_to_surface]).
const BELLY_PUSH := 0.2
const HELD_SIDE := 0.6
const HELD_SIDE_EDGE := 0.15
## A BRUSH IS PULLED THROUGH ITS STROKE (the user, 2026-11-07: "a real artist would turn the brush, to pull THROUGH the stroke at the
## same angle" - held up and out to one side whichever way it went, it was pushed through half its lines): along a stroke its handle
## leans the way it goes, this far along the surface for [constant HELD_OUT] (or [constant HELD_LOW]) out of it, so its hairs trail
## behind it at one angle to the stroke ([method _pulls_of]). Back and forth along a fill's rows the wrist rocks it over between them,
## as a wall is painted - never turned round. Drawing a line toward the camera it stands up this share more, hiding less of what it
## paints; laid low on its belly it stays as low whichever way it goes (stood up on the rows toward the camera, a flat brush laid half
## as much of its belly on the face, and left streaks between its rows that the next look had to put right).
const HELD_PULL := 0.45
const PULL_TOWARD := 0.5
## A TRIP (to the paint, the water, the towel): how far over its place a tool comes and leaves (meters), how far across a towel it is
## wiped, and the trips there are - a dry is the towel's.
const TRIP_LIFT := 0.012
const WIPE := 0.015
## ...and over a pot's or a cup's rim it comes in and leaves at least this far (meters): from over its paint alone, a brush came in
## to the water cup through its wall and was held back on it (joker-motivation 856886, 2026-11-05).
const RIM_CLEAR := 0.01
## THE WAY BETWEEN PLACES GOES OVER WHAT STANDS IN IT ([method _lift_over]), as a carry's does ([method TableWork._clearance]): what
## stands on the table where the tools go is mapped once as they are prepared, the highest surface over each cell this wide
## (meters), this far past the places they go, and looked at as far round the tip as the tool is wide - half its width and this
## much more (meters): widened by two centimeters for every tool, the face lying back 60 degrees stood 3.5 cm over itself and every
## brush hopped between its strokes. A brush taken from the water cup to the palette went through the setting spray between them,
## 11 cm tall, and was held back on it by twenty to thirty centimeters, act after act (joker-motivation 856886).
const TOPS_CELL := 0.01
const TOPS_MARGIN := 0.08
const TOPS_BESIDE := 0.005
const TRIPS := ["load", "rinse", "dry"]
const DRY := 2.6
## A SPONGE RINSED AS A HAND RINSES ONE (feedback 0050: "we're dipping the entire sponge into the water, but not ringing it out over
## the cup ... holding it in the water for longer, so that it can actually soak up some of the liquid, for us to ring out? Then, when
## we press it against the board ... push harder, and more than just one quick press. Like, press it a few times, in and out"):
## lowered into the water and squeezed there as it soaks, lifted over the cup and wrung out, then blotted on the towel in firm
## presses, each on a fresh place ([method _sponge_trip]). Its rinse and its dry take this long (seconds), the carry there this much
## of it; it is squeezed this many times on the cup's floor under the water (where a rinse goes, [method _source_of]), between this
## little (its own shape between squeezes) and this much of a full squeeze, and wrung this many times; blotted this many times, held pressed this much of each, lifted
## this far between (meters) and stepped this far across the towel.
const SPONGE_RINSE := 8.0
const SPONGE_DRY := 4.6
const SPONGE_GO := 0.2
const SOAKS := 3
const SOAK_EASE := 0.0
const SOAK_PRESS := 0.8
const WRINGS := 2
const BLOTS := 3
const BLOT_HELD := 1.6
const BLOT_LIFT := 0.008
const BLOT_STEP := 0.012
## ...going over to the next place in this much of each blot, lifted
const BLOT_OVER := 0.15
## ...and squeezed in the hand, at its hardest, this much thinner across its broad faces ([method _squeeze_of]) - pinched in its middle by a
## finger and thumb, the press reaching this share of half its narrower broad side ([method _squeeze_reach])
const SQUEEZE_REACH := 0.6
const SQUEEZE_MOST := 0.5
## A DESIGN'S COLORS ARE THE TABLE'S PAINTS (the user's choice, 2026-11-07, of feedback 0057 and 0059 - "Pot paint, thinned": a lighter plum
## had come from the one plum pot, "It's not clear how that would have happened, when the brush only has one color"; a watery band and a
## crisp line from one liner, "The physics aren't making sense to me here"; the first base's tan from the white pot): an element is laid
## in the paint of the pot it is taken from ([method _pot_of]), as thick as brings that paint over a face this light to the design's
## lightness ([method _thickness], [constant THIN_LEAST] at the least); one laid thinner than [constant THIN_WET] is taken up on a brush
## wetted in the water first; one with an edge this soft (millimeters) or softer goes on crisp and is softened as its tool goes back over
## it, nothing more taken up.
const FACE_LIGHT := 0.85
const THIN_LEAST := 0.2
const THIN_WET := 0.75
const SOFT_GONE_OVER := 2.0
## WATER CLOUDS BY WHAT IS RINSED INTO IT ([method cloud_at]), never at once (2026-11-07, the user: "start clear, and inherit colors
## based upon the volume coming off of brushes and sponges ... accumulate color over time, not immediately"; each rinse had taken
## it a tenth of the way to the color, a liner's as much as a sponge's): the paint a rinse carries out - a sponge's face this deep a
## film of it (meters), a brush's belly this share of its hairs' bulk - its share of the water then turning the water's color
## toward it (1 - e^(-TINTS * share)) and clouding it (its clearness times e^(-CLOUDS * share)). A sponge's rinse in a glass of
## water clouds it about a tenth; a liner's, hardly at all.
const RINSED_FILM := 0.0005
const RINSED_BELLY := 0.05
const TINTS := 90.0
const CLOUDS := 60.0
## ...in this much water where its vessel's is not known (milliliters)
const WATER_ML := 250.0
## A SPRAY: how long its tool is held ready before and after, how far off the surface (millimeters), and the mist's puffs.
const SPRAY_STANDOFF := 120.0
## ...and which way from it: out of the surface, to its right, up along it (shares, then made a direction).
const SPRAY_FROM := Vector3(0.6, 0.7, 0.3)
## A SPONGE GIVES this far where it is pressed hardest (meters): pushed in that far, squashed back to the surface - it had been
## squashed off it, its pressed face 3.6 mm over the face it painted.
const GIVE := 0.003
## ...AND A PAD (a powder puff) THIS FAR, drawn squashed onto it as a sponge is: stiff, it stood off a curved face on its flat one, 5-23 mm,
## and painted nothing once what touches is what paints (feedback 0035; 520084's puff left 17,000 mm2 of the face bare).
const PAD_GIVE := 0.008
## PRESSED ONTO A SKIN, A PAD OR A SPONGE TAKES ITS SHAPE (feedback 0041, of 520084's puff: "the pad is clipping through the nose ...
## the pad is always perfectly flat: it never seems to bend or compress ... when pressing into eye sockets for example ... pads like this
## are very soft and should be easy to bend"): squashed back along the way it was pushed, as a share of its depth, its pressed face had
## stood flat and 3.5 mm in a flat forehead and more in a nose. So each bit of it is drawn from the skin's own heights
## ([method press_lands], prop_common.gdshaderinc's `press_lands`, the same arithmetic): what would go in it lies on it, PRESS_LIFT
## over it, softened over PRESS_SOFT; a pad's face sags into a hollow within PRESS_REACH of it, PRESS_SAG of what it gives as it is
## pressed (a sponge's denser foam does not); its back is kept PRESS_THIN of its own depth over the skin, so pushed past that the whole
## of it bends away. What of it is drawn as low as a bit standing [constant TOUCH_BAND] over the skin is, touches.
const PRESS_SOFT := 0.0003
const PRESS_LIFT := 0.0002
const PRESS_THIN := 0.3
const PRESS_REACH := 0.008
const PRESS_SAG := 0.4
## ...ITS SHAPE READ THIS FINELY (meters), this far past the skin's frame all round: read every 2 mm, as the way a tool is held reads it,
## a nose's ridge peaking between them stood 2.7 mm through a sponge laid on it ([method _press_field]).
const PRESS_CELL := 0.001
const PRESS_BEYOND := 0.012
## ...AND IS PUSHED INTO ITS PAINT this far to take it up (meters), a puff into its powder this far, held there for this share of the
## dip (the user, 2026-11-06: "the sponge barely touched the foundation case ... we should have really pushed the sponge into the
## foundation, to pick-up a lot of the dust").
## AND PRESSED, IT IS PRESSED FLAT (the user, 2026-11-06, of the 8 mm it had been pushed: "It touches at the very tip of a corner,
## and doesn't compress the sponge at all ... it didn't pick up enough foundation to equal the amount that is then applied"): the foam
## squashed back from its middle along its length had been drawn a sponge a quarter shorter, its corner on the cream. So what would go
## under its paint's surface is drawn ON it, the [constant FLAT_BAND] over it squeezed and spread out by [constant FLAT_SPREAD] of what
## it gave ([method _flat_lift], prop_common.gdshaderinc's `flat_on`) - pushed in by the end of its length ([method tool_of]'s `end`),
## DABBED into it two or three times as it is held there ([constant LOAD_EASE] between, never out of it).
const LOAD_PRESS := 0.012
const LOAD_PRESS_PAD := 0.004
const LOAD_HELD := 1.8
const LOAD_EASE := 0.35
## A BRUSH DIPS INTO ITS PAINT this far (meters), its hairs in it as it turns (feedback 0019, joker-motivation 209459: "When it dips
## into the container, it didn't touch there either" - it had been taken to a millimeter over the paint's surface and no further).
const BRUSH_DIP := 0.003
## ...and WORKED INTO IT ([method _brush_load]): swirled round this many times, out this far from where it went in (meters).
const LOAD_TURNS := 2.0
const LOAD_SWIRL := 0.004
## A BRUSH IS LAID ON WHAT IT IS PRESSED ONTO OFF THE FACE - ITS PAINT IN ITS POT, THE WATER CUP'S FLOOR, THE TOWEL (feedback 0002,
## 2026-11-09: "These brushes are not actually touching the foundation in the container ... just a tiny little portion of the very tip of
## the brush is touching. The same applies EVERYWHERE that brushes are dipped in containers. It also applies to the grey pad ... we need
## the bottom 30% to 50% of bristles touching, laying on their side"): its handle leaning the first of [constant LAY_LEANS] (degrees off
## upright) that keeps it inside the pot's wall, out toward the side of the table the pot is on and a little toward the camera
## ([constant LAY_OUT]: never over the work), and pushed straight down until [constant LAY_SHARE] of its hairs' length lies along the
## surface, the rest bowed down to it ([method _laid_hold], [method Bristles.laid]) - their middle line this far over it, about a hair's
## thickness ([constant LAY_CLEAR]). A flat brush is leaned across its broadside as it comes rolled, so its flat lies down, never its
## chisel edge (anything left of a turn turned in the hand on the way, [method _roll_toward]). Held 21 degrees off upright and pushed its
## give past the surface, its hairs bent only until the tip met it (feedback 0017), 1 mm of its point had touched.
## ...the last nearly upright, its hairs bent most of a right angle onto the floor of a cup too deep and narrow for any lean (feedback 0002:
## "EVERYWHERE that brushes are dipped in containers" - a water cup 7 cm deep had taken no lean, and a rinse stood 1 mm over its floor).
const LAY_LEANS := [55.0, 45.0, 35.0, 25.0, 15.0, 5.0]
## ...COME TO IT AT A HAND'S PACE THE BRUSH KEEPS UP WITH ([method _brush_laid]): its way there taking at least as long as this many meters a
## second, on average, brings it - the solver carries a held thing near others no faster than [constant RigidParts.STEP_MOST] x
## [constant RigidParts.PIECES_MOST] a frame, about 58 cm a second, and a hand's way peaks near twice its average - and at most this
## share of the trip, the rest its press.
const TRIP_PACE := 0.25
## ...and from one element to the next, on average (m/s), over its whole way - up over what stands between, down, its handle swung -
## eased in and out, near twice as fast at its fastest.
const MOVE_PACE := 0.25
## ...and from one key of an element's program to the next (m/s, over the way its body goes - [method _pace_keys]): a stroke goes far
## slower than this, but between two strokes drawn opposite ways a brush's handle swings from leaning one way to the other.
const KEY_PACE := 0.35
## A BRUSH'S HAIRS LAID BEHIND THE WAY IT GOES along what it is laid on ([method _lay_on_plane]): wholly at this speed (m/s), the way taken
## over this long before the moment (s) - a hand's swirl round a pot, 1.6 to 4 cm a second, trailed round after it.
const TRAIL_SPEED := 0.01
const TRAIL_LAG := 0.1
## ...wholly upright, less as it leans, none this far over (degrees).
const TRAIL_LEAN_MOST := 70.0
## ...its reveal maps carried to its new times through a table of this many steps of its length ([method _warp_maps]).
const WARP_LUT := 4096
const TRIP_GO_MOST := 0.6
const LAY_OUT := Vector2(0.8, 0.6)
const LAY_SHARE := 0.3
const LAY_CLEAR := 0.0003
## ...AND IS NEVER STOOD OFF WHAT IT PAINTS FURTHER THAN THIS (meters, [method _cleared]): its hairs bend against what it meets.
const BRUSH_STAND_MOST := 0.0015
const FLAT_BAND := 0.008
const FLAT_SPREAD := 0.2
## A FACE TOO BROAD FOR ITS POT'S MOUTH IS LAID OVER IT, FLAT (feedback 0005, 2026-11-08: "It's also dabbing into the container at a weird
## angle, for the flat side. You would expected it dabbed flat: resting on both sides of the container, and compressed/pushed from the middle,
## into the container. It would bend in the middle"): a 50 mm sponge over a 45 mm pot had been tilted 60 degrees and lifted, its corner still
## through the wall. It rests this far over the rim ([method _pot_hold]); pressed, its face's middle goes down past the paint's surface this
## far, its back this much further under the finger, the finger as wide as this share of the mouth ([method _drape_on],
## prop_common.gdshaderinc's `drape_at`).
const DRAPE_CLEAR := 0.0005
const DRAPE_INTO := 0.0015
const DRAPE_DENT := 0.004
const DRAPE_FINGER := 0.35
## HOW A SPONGE IS HELD BY ITS CORNER ([constant Skins.FLAT_MANNERS]): its middle out of the surface, up along it and out to the side
## its work is on (shares, as [constant HELD_OUT]) - nearer upright than a brush's handle; by its face, flat on the surface.
const CORNER_HELD := Vector3(0.85, 0.3, 0.3)
## ...AND TIPPED ONTO ITS CORNER ONLY AS FAR AS THE WORK NEEDS (the user, 2026-11-08: "when the sponge turns from flat to its corner dab, it
## always turns at a very severe angle - the same angle every time ... a real human would barely need to turn from flat to an angle, to dab
## with a corner ... with a preference toward not needing to move the sponge quite so much"): its face tipped this many degrees toward its
## corner, the corner down and the face beside it - a little, a small wedge of it touching; more, less - its hand leaning that share of a
## corner's lean. The ways [constant WAYS] names them; the corner itself, held through its middle (about 60 degrees), is left to what is not
## laid from the picture.
const TILTS := {"tilt12": 12.0, "tilt25": 25.0, "tilt40": 40.0}
## A HELD TOOL STANDS IN NOTHING (feedback 0016, joker-motivation 209459: "This sponge is clipping right through the nose" - its flat
## face held at a brush's tilt stood 36 mm in the mask's nose and its board, and a sponge 5 cm across went into a pot 4.6 cm across):
## its own surface ([member tools]' `points`) is held clear of the surface it works on and what holds it, and of the pot it dips into,
## by the way it points nearest how a hand holds it there ([method _cleared], [method _pot_clear]) - tried this far from the surface's
## normal (degrees), each this many ways round it - and stood off only as far as it must.
const CLEAR_TILTS := [15.0, 30.0, 45.0, 60.0]
const CLEAR_ROUND := 12
## ...measured against the surface where it lies, every this far (meters), and this far past it all round (what holds it) - read across
## its slope, never straight down it: at 3 mm and read down it, a sponge's corner on a mask's rim or under its nose stood 9 to 17 mm in
## the cliff its cell straddled;
const CLEAR_CELL := 0.002
const CLEAR_BEYOND := 0.04
## ...the highest of it kept over blocks this many cells across, so what stands well over it is never looked at closer;
const CLEAR_BLOCK := 8
## ...and read across it no more than this much shallower than straight down (deep under a nose's tip, its slope over two millimeters made
## a point 10 mm in it read 2);
const SLOPE_MOST := 1.5
## ...what a way of holding it a radian further from how a hand holds it costs, in how far it stands off the surface (meters), and
## how far a sponge's face may stand off before its corner is tried there ([method _held_keys]);
const CLEAR_TURN := 0.006
const FLAT_MOST := 0.004
## ...and the way between two places looked at, unless they are this close (millimeters) and turned less than this (degrees) - every
## that far along it and that much of its turn, at most so many times (three along a 113 mm way had missed the nose it crossed);
const ARC_STEP := 3.0
const ARC_TURN := 4.0
const ARC_LOOKS := 40
## ...clear of the surface by this much where it is not pressed onto it (meters).
const ARC_CLEAR := 0.003
## ...looked at only this far from either key (shares of the way): nearer, the key's own clearance is what holds it.
const ARC_ENDS := 0.15
## ...AND EVERY POSE IT IS DRAWN AT, whatever its plan ([method _kept_out]): standing in what it paints past what gives by no more than this
## (meters), turned up about its tip at most this far (degrees, found to within its halvings), else lifted out in at most this many steps.
const KEEP_OUT := 0.0005
## ...its handle and ferrule read off the surface itself, not its cells, within this of them (meters, [method _sunk_exact]), found every
## this far over their faces ([method tool_of]'s `stiff_dense`).
const EXACT_BAND := 0.003
const KEEP_EVERY := 0.002
const KEEP_TURN_MOST := 40.0
const KEEP_HALVINGS := 7
const KEEP_LIFTS := 6
## ...a pot's wall kept this far from (meters, past the swirl of a rinse);
const CLEAR_WALL := 0.0055
## ...and the tool's surface found across each face of its box every this far (meters), at least two and at most POINTS_MOST a side: a
## centimeter apart, the nose's underside stood 7 mm in a sponge's flat face between them; at most twelve a side, a round brush 15 cm
## long was looked at every 14 mm along it, and its ferrule's lip, between two, stood 6 mm in a mask's nose (feedback 0003, 2026-11-09,
## 732687's intro: "This brush is clipping straight through the nose here").
const POINTS_EVERY := 0.005
const POINTS_MOST := 40
const POINTS_RIM := 0.0015
## WHAT A PRESSING TOOL TOUCHES IS WHAT IT PAINTS ([method _touched]): its surface found this finely (meters), and a bit of it touches
## the face within this of it, or in it (a sponge pushed in gives, and is drawn squashed onto it) - for the manners a tool presses on.
const TOUCH_EVERY := 0.001
const TOUCH_BAND := 0.0006
## ...a cell of what stands over the skin this much higher at one corner than another is a wall, read as high as it stands ([method _touched]).
const TOUCH_STEEP := 0.002
const TOUCHED := ["stipple", "pat"]
## ...and A BRUSH'S HAIRS, BENT AS THEY ARE DRAWN, paint what of them touches the face (feedback 0031: "the whole brush is touching the eye,
## but paint is only coming out from one side of that brush"): for these manners, each line looked at every BRUSH_SAMPLE millimeters (a
## fill, twice that - what it touches is wide), the hairs from this far up them (what can reach the face).
const BRUSH_TOUCHED := ["line", "sweep", "dab"]
const BRUSH_SAMPLE := 0.5
## ...on a map this many pixels a millimeter, each bit of a hair that touches laid this wide (millimeters): at a sponge's millimeter a
## liner's line was drawn in steps.
const BRUSH_PX := 4.0
const BRUSH_SPOT := 0.45
const HAIR_TOUCH_FROM := 0.35
## How near its aim a brush's hairs touch for it to have met it (millimeters, [method _gaps_in]).
const AIM_MET := 1.0
## A BRUSH'S TIP IS BENT ONTO THE FACE ([method _bend_to_surface]) by the least bend that brings it there: looked for in steps from this
## (meters), each twice the last, and the step it is found in halved this many times (a quarter of a millimeter left at the widest), no
## further than this many times what would bring it there over a flat face.
const TIP_STEP := 0.00025
const TIP_HALVES := 5
const TIP_REACH := 2.0
## A BRUSH KEEPS INSIDE WHAT IT FILLS ([method _keep_inside]): its hairs may touch this far past its shape (millimeters), a moment
## touching past that at this many points or more has run past it (three had let a lip's fill lay 24 mm2 past it, a bit or two at a
## time along its top), and its ways are looked at this many times;
const SPILL_MOST := 0.5
const SPILL_LEAST := 1
const SPILL_ROUNDS := 6
## ...eased off where it runs past, at the least this hard (a share of how hard it lays the rest).
const SPILL_LIGHTEST := 0.25
## A HAND GOES BACK OVER WHAT IT MISSED ([method _cover_gaps]): this many looks at what its presses touched, a gap as large as this
## worth a press (square millimeters), and a press put in after the first look this much harder (a soft sponge pushed into a crease).
const GAP_ROUNDS := 5
const GAP_LEAST := 1.0
const PRESS_HARD := 1.8
## The manners an element laid from the picture is laid in ([method _from_picture]): a sponge's dabs, a brush's dots, pulls and lines.
const PICTURE_MANNERS := ["stipple", "dab", "sweep", "line", "blend"]
## ...each in no more than this share of the time its shape's program took: the length the readers' words were written to (laid from the
## picture with no end, 257002's work ran an hour past its words, and the show closed on a face half painted; at 1.1, the work stopped with
## most of the picture's detail never begun).
const PICTURE_SLACK := 1.25
## ...and its readers told this share of its shape's time: what the operations laid from the picture took, all together (most finish
## before their time, once nothing worth a mark is left; 257002's took 1,958 s where their shapes took 1,935)
const PICTURE_TOLD := 1.0
## ...and a painter's operation (the painter's tools) as long as it took the painter, and this share more; worked this far round the
## region it drew where it meant it (millimeters)
const PLANNED_SLACK := 1.15
const PAINTER_GROW := 2.0
## ...a line's or dots' traced path as rough as a fill's shape is, and thinner: worked this far round it (millimeters)
const PICTURE_GROW_LINE := 15.0
## ...and a blend's softening of what was laid from the picture held to this many mip levels of its canvas
const PICTURE_BLEND_LOD := 1.0
## ...a FOUNDATION whole whatever its first coat takes, its goings-back over what is still thin held to this share of its shape's time -
## a corner's own dabs, each a thin film (the user, 2026-11-08: "much too quick ... every touch of the sponge creates a paint area that is
## at least 4 times as large as the corner we touched the mask with ... all dabs are applied at full color/transparency, so no re-dos are
## ever necessary"), take four times the dabs and two or three to a point; worked area by area, each print lighter at its edge and fainter
## as the load runs out, its broad prints fading over a share of their width and pressed hardest in their middles - and never mostly a miss,
## its loads lasting, its last thin places evened - 257002's takes 407 s.
const FOUNDATION_SLACK := 2.5
## ...and a sponge's dab laid from the picture this share of its touch's width across (half the width it was: "a paint area that is at
## least 4 times as large as the corner we touched the mask with").
const PICTURE_CORNER := 0.25
## ...each point a press touched stamped on its reveal map this far round it (pixels of [constant Skins.WHEN_PX]): a point of the map is
## touched where its middle lies within it ([method Skins.touch_map]), and the look stamps as the map does ([method _gaps_left]).
const PRESS_SPOT := 0.75
## The ways a key may be held other than its program's own ([method _held_keys]' `ways`): 1 a sponge's or pad's corner, 2 a sponge's
## long end, held along its length, 3 its face, flat, 4 to 6 its face tipped onto its corner a little, more and most ([constant TILTS]).
const WAYS := ["", "corner", "end", "face", "tilt12", "tilt25", "tilt40"]
## ...and a press put in where the first missed, held its own way, touching no nearer where it is aimed than [constant AIM_MET], is held
## another way where that touches this much nearer it (millimeters, [method _press_miss]).
const REACH_BETTER := 0.3
## THE PAINT ON A BRUSH'S TIP: as much as it shows just loaded, what never comes out until it is rinsed, and how long it takes to
## lay most of it (seconds).
const TIP_FULL := 0.9
const TIP_LEFT := 0.5
const TIP_LASTS := 18.0
## How long a tool's hairs take to settle after its act (seconds): it is posed that long after.
const SETTLE := 0.6
## How finely a skin's surface is found (millimeters between rays), and how far its edge may face away from its front (the cosine)
## or lie under the surface beside it (meters) before it counts as past the surface ([method _surface_of]).
const SURFACE_STEP := 2.0
const EDGE_FACING := 0.35
const EDGE_CLIFF := 0.004
## The stones' size against what the design says, and how far they stand out of the surface (shares of their radius).
const STONE_OUT := 0.25

const _CANVAS := preload("res://shaders/skin_paint.gdshader")

var work: TableWork
## Every skin on the table: `{ti, name, part, holder, meshes, xform (its part into its holder's space), box (its own, meters),
## frame (millimeters), outline, shape, design, surface, canvas: [color viewport, finish viewport], items: {id: {...}}, stones,
## clear (what stands over it, [method _obstacles]), held ([method _held_keys])}`
var skins: Array = []
## Each tool a paint track works ("w3:pose"/"t1:pose" -> {tip, grip, kind, mm, tufts, sponges, node, len, x0, center, points,
## contact, contacts: {name: {tip, grip, give, bend, reach}}})
var tools := {}
## A trip's hold over its pot, found as it is first asked ([method _pot_clear]) - each its own, the bake's twin as the app's.
var _pots := {}
## The paint on each tool's tip over time: channel -> [[t, color or null], ...] in order ([method spans]).
var _loads := {}
## The programs made, kept across a puppeteer's acts written again: key -> {program, cover, when, rect}.
var _made := {}
## Which act lays each element, and which go over it again: "skin|id" -> {act, manner, tool}; and the order acts lay them.
var _layers := {}
var _host_doc := {}       # the painter at the table's elements, read once a build (`paint/elements.json` - [method _from_host])
var _dust: Array = []         # [{t, p}] a pat's puff of powder, and a sweep's
var _drawn_t := NAN
var _active: Array = []       # items whose time is now, as last found
var _creams: Array = []       # [{color, at, ti, powder}] the paints on the table, creams and powders, where each is taken up from (the table's space, as it stood)
## What stands where the tools go ([method _map_tops]): the highest surface over each [constant TOPS_CELL] (-INF where none); its first
## cell's corner (the table's x, z) and how many cells across x and z. Made before the bake begins, only read after.
var _tops := PackedFloat32Array()
var _tops_at := Vector2.ZERO
var _tops_n := Vector2i.ZERO
## WHAT HAS BEEN FOUND, by what it was found from, so a hand going back over what it missed finds again only what is new
## ([method _cover_gaps]): a tool held clear at a place ([method _cleared], by skin, place, way and tool), lifted between two keys
## ([method _held_keys]' arcs, by the two), and what it touches held so ([method _touched], by the hold). This thread's alone.
var _clear_memo := {}
var _arc_memo := {}
var _touch_memo := {}
# (how a tool was held clear at a place by a side, when the picture's dabs asked what it touched there - [method _side_touch])
var _side_held := {}
## ...and what a stroke touched, by the stroke itself (its places, its pace, what was on the tool): a dab put in moves when it is laid, not
## what it touches ([method _stroke_touches]).
var _stroke_memo := {}


func _init(w: TableWork) -> void:
	work = w


## A BREATH for the app's thread, in a long loop on a table built on a worker ([method TableMedium._breathe]).
func _breathe() -> void:
	if work != null and work.medium != null:
		work.medium._breathe()


## THE BAKE'S OWN ([TablePhysics]'s twin, [param w]): the same skins, tools, programs and paints, found before the bake began
## and only read on its thread - TWO THREADS SHARE NOTHING EITHER WRITES.
func twin_for(w: TableWork) -> TablePaint:
	var t := TablePaint.new(w)
	t.skins = skins
	t.tools = tools
	t._made = _made
	t._layers = _layers
	t._creams = _creams
	t._tops = _tops
	t._tops_at = _tops_at
	t._tops_n = _tops_n
	return t


func clear() -> void:
	for s in skins:
		for vp in (s as Dictionary).get("canvas", []):
			if is_instance_valid(vp):
				(vp as Node).queue_free()
		for st in (s as Dictionary).get("stone_nodes", []):
			if is_instance_valid(st):
				(st as Node).queue_free()
	skins = []
	tools = {}
	_clear_memo = {}
	_arc_memo = {}
	_touch_memo = {}
	_side_held = {}
	_stroke_memo = {}
	_pots = {}
	_loads = {}
	_layers = {}
	_dust = []
	_active = []
	_drawn_t = NAN


# --- what is on the table ----------------------------------------------------------------------------

## Thing [param ti]'s skins as [method Props.build] made them ([param b]'s `skins`).
func take(ti: int, b: Dictionary) -> void:
	for s in b.get("skins", []):
		var sd: Dictionary = (s as Dictionary).duplicate()
		sd["ti"] = ti
		sd["name"] = String((work.things[ti] as Dictionary)["name"])
		var box: AABB = sd["box"]
		sd["frame"] = Vector2(box.size.x, box.size.y) * 1000.0
		sd["design"] = {}
		sd["items"] = {}
		sd["canvas"] = []
		sd["stone_nodes"] = []
		sd["clear"] = {}
		sd["held"] = {}
		skins.append(sd)


## The skin a thing's name (and its part's, if it gives one) names, or -1.
func skin_named(thing: String, part := "") -> int:
	for k in skins.size():
		var s: Dictionary = skins[k]
		if String(s["name"]).to_lower() == thing.strip_edges().to_lower() and (part.is_empty() or String(s["part"]).to_lower() == part.strip_edges().to_lower()):
			return k
	return -1


## THE DESIGNS ([param doc], `skin.json` as parsed) on the skins they name - before the acts are found on the table, which
## name their elements.
func set_designs(doc: Dictionary) -> void:
	tools = {}
	_pots = {}
	for s in skins:
		var sd: Dictionary = s
		sd["design"] = {}
		for d in doc.get("designs", []):
			if not (d is Dictionary):
				continue
			var dd: Dictionary = d
			if String(dd.get("thing", "")).to_lower() == String(sd["name"]).to_lower() and (String(dd.get("part", "")).is_empty()
					or String(dd.get("part", "")).to_lower() == String(sd["part"]).to_lower()):
				sd["design"] = Skins.sanitize(dd, sd["frame"], String(sd.get("outline", "")))
		if sd.get("surface") == null:
			sd["surface"] = _surface_of(sd)


## THE ACTS THAT PAINT ([member TableWork.acts], found on the table): each element's program for the tool that lays it, its
## pictures and its reveal map, its sprites in its skin's canvas - and each paint act's length at a hand's pace (`_natural`,
## the least it is hurried to `_min_length`), which the schedule and the readers go by.
func prepare() -> void:
	_layers = {}
	# THE PAINTS ON THE TABLE, where each is taken up from - before the elements are given theirs ([method _pot_of]). A POWDER IS ONE TOO
	# (2026-11-07: 257002's setting powder, patted on from its pot, was given the white cream's color as the nearest cream - and as a fill
	# over the whole face in the white's paint, folded into the white base by [method _one_coat]: its two acts patted nothing; its copper
	# glitter, pressed on from a vial of copper flakes, was laid in the rust cream's color)
	_creams = []
	var cream := int((Props.MATERIALS["cream"] as Dictionary)["code"])
	var powder := int((Props.MATERIALS["powder"] as Dictionary)["code"])
	for ti in work.things.size():
		for m in (work.things[ti] as Dictionary)["meshes"]:
			var mi := m as MeshInstance3D
			var mat := mi.material_override as ShaderMaterial
			if mat == null or mat.get_shader_parameter("kind") == null or not int(mat.get_shader_parameter("kind")) in [cream, powder]:
				continue
			var box: AABB = work._world_of(mi) * mi.get_aabb()
			_creams.append({"color": mat.get_shader_parameter("color"), "at": Vector3(box.get_center().x, box.end.y + 0.001, box.get_center().z), "ti": ti,
				"powder": int(mat.get_shader_parameter("kind")) == powder})
	# WHO LAYS EACH ELEMENT: the first act that paints it, in the order the reading comes to them; any later one goes over it
	var pots := {}
	for a in _in_reading_order(work.acts):
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint":
				continue
			var si := int(t.get("_skin", -1))
			if si < 0:
				continue
			var tool := tool_of(String(t["_ch"]), t)
			for id in t["paint"]:
				var key := "%d|%s" % [si, String(id).to_lower()]
				if not _layers.has(key):
					var el := element(si, String(id))
					if el.is_empty():
						continue
					var manner := Skins.manner_of(el, String(tool["kind"]), String(t.get("manner", "")))
					var mm := _width(tool, t, manner)
					# ...a tool that presses laid as wide as what of it touches, pressed as it is pressed ([method _touch_width]) - whatever
					# width its track says (520084's sponge was written 32 mm, its whole face; its corner touches 15)
					if manner in TOUCHED and tool.has("touch"):
						mm = _touch_width(tool, _contact_for(tool, manner))
					# ...IN THE PAINT OF ITS POT, as thick as its color asks ([method _pot_of], [method _thickness]) - a smear the paint it drags
					var pot := _pot_of(t, el) if String(el["kind"]) != "smear" else String(pots.get(String(el["paint"]), el["paint"]))
					pots[String(el["paint"])] = pots.get(String(el["paint"]), pot)
					var thick := _thickness(Color.html(String(el["paint"])), Color.html(pot)) if String(el["kind"]) in ["fill", "line", "dots"] else 1.0
					_layers[key] = {"act": String((a as Dictionary)["name"]), "manner": manner, "mm": mm, "pot": pot, "thick": thick,
						"soft_over": float(el.get("soft", 0.0)) >= SOFT_GONE_OVER and String(el["kind"]) in ["fill", "line"] and String(tool["kind"]) in ["brush", "sponge"]}
	_one_coat()
	_one_after_another()
	for si in skins.size():
		(skins[si] as Dictionary)["_rest"] = work._world_of((skins[si] as Dictionary)["holder"])
		_canvas(si)
	# ...what stands where the tools go, for their ways over it
	_map_tops()
	# ...WHAT THE PAINTER AT THE TABLE LAID, played as it wrote it ([method _from_hosts]) - and what the picture wants, laid by the tools
	# element by element, where the surface was painted first ([method _from_picture])
	_from_hosts()
	_from_picture()
	# ...A HAND GOING BACK OVER WHAT IT MISSED, before any act's length is known ([method _cover_gaps])
	_cover_gaps()
	# ...AND HOW EACH TOOL IS HELD at every place its programs keep, clear of what it works on ([method _cleared]): found here, on
	# this thread, before the bake reads them - and so each way inside an element is given the time its body needs ([method _pace_keys])
	_hold_all()
	_pace_keys()
	# ...and each act's length at a hand's pace (every program it asks made now, before the bake reads them) - and how much of it is
	# its trips and moves, which an act given more time than it takes never slows ([method TableWork.schedule]'s `_fixed`)
	for a in work.acts:
		var natural := 0.0
		var fixed := 0.0
		var paints := false
		for tr in (a as Dictionary)["tracks"]:
			if String((tr as Dictionary)["law"]) == "paint":
				paints = true
				var pl := _unhurried(a as Dictionary, tr as Dictionary)
				if float(pl["natural"]) > natural:
					natural = float(pl["natural"])
					fixed = maxf(natural - float(pl.get("work", 0.0)), 0.0)
		if paints:
			(a as Dictionary)["_natural"] = natural
			(a as Dictionary)["_fixed"] = fixed
			(a as Dictionary)["_min_length"] = natural * LEAST
			if not bool((a as Dictionary).get("under", false)):
				(a as Dictionary)["length"] = maxf(float((a as Dictionary)["length"]), natural * LEAST)
			else:
				(a as Dictionary)["length"] = natural
	# ...and what a pressing tool touches, held so, is what it paints ([method _touch_all])
	_touch_all()
	# ...and where a blending brush goes over what was laid, softened there alone ([method _blend_touches])
	_blend_touches()
	# ...AND WHAT A PAD OR A SPONGE PRESSED ONTO A SKIN TAKES THE SHAPE OF, found here, on this thread, never as it plays ([method _press_field])
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) == "paint" and int(t.get("_skin", -1)) >= 0 and t.has("_ch") and tool_of(String(t["_ch"]), t).has("touch_n"):
				_press_field(skins[int(t["_skin"])])


## How wide tool [param tool] lays paint for track [param tr] in [param manner] (millimeters): the track's `size`, else its own
## ([method Skins.width_for]).
static func _width(tool: Dictionary, tr: Dictionary, manner: String) -> float:
	return float(tr["size"]) if tr.has("size") else Skins.width_for(String(tool["kind"]), float(tool["mm"]), manner)


## EVERY PAINT TRACK'S TOOL HELD CLEAR at each place of each program it goes through ([method _held_keys]), kept by its skin -
## each skin's whole map new, so what the bake reads is never written; what was found before for the same program and tool, kept.
func _hold_all() -> void:
	var fresh: Array = []
	for si in skins.size():
		_obstacles(skins[si] as Dictionary)
		fresh.append({})
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch") or int(t.get("_skin", -1)) < 0:
				continue
			var si := int(t["_skin"])
			var ch := String(t["_ch"])
			var tool := tool_of(ch, t)
			var was: Dictionary = (skins[si] as Dictionary).get("held", {})
			var plan := plan_of(t, float((a as Dictionary).get("_natural", 0.0)))
			for ph in plan["phases"]:
				if not (ph as Dictionary).has("prog"):
					continue
				var prog: Dictionary = (ph as Dictionary)["prog"]
				var contact := _contact_for(tool, String(prog.get("manner", "")))
				var key := _held_key(prog, ch, contact)
				if (fresh[si] as Dictionary).has(key):
					continue
				(fresh[si] as Dictionary)[key] = was[key] if was.has(key) else _held_keys(si, prog, tool, contact)
	for si in skins.size():
		(skins[si] as Dictionary)["held"] = fresh[si]


static func _held_key(prog: Dictionary, ch: String, contact: String) -> String:
	return "%s|%s|%s" % [prog.get("id", ""), ch, contact]


## THE MAP OF WHAT STANDS WHERE THE TOOLS GO ([member _tops]): over the things every paint track names - what it paints, its tool's
## own, its pots, water and towel, every paint on the table - the highest surface over each cell, as the table was built. A thing
## an act carries off is mapped where it stands until then; the tool's own place is low.
func _map_tops() -> void:
	_tops = PackedFloat32Array()
	var tis: Array = []
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch"):
				continue
			for ti in touches(t):
				if not tis.has(ti):
					tis.append(ti)
			var wi := int(t.get("_wi", -1))
			if wi >= 0 and not tis.has(int((work.works[wi] as Dictionary)["thing"])):
				tis.append(int((work.works[wi] as Dictionary)["thing"]))
	if tis.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for ti in tis:
		var box: AABB = work._world_rest_thing(int(ti)) * ((work.things[int(ti)] as Dictionary)["box"] as AABB)
		lo = lo.min(Vector2(box.position.x, box.position.z))
		hi = hi.max(Vector2(box.end.x, box.end.z))
	lo -= Vector2.ONE * TOPS_MARGIN
	hi += Vector2.ONE * TOPS_MARGIN
	var n := Vector2i(ceili((hi.x - lo.x) / TOPS_CELL), ceili((hi.y - lo.y) / TOPS_CELL))
	# ...every solid as it was built: the things' own and their parts'
	var meshes: Array = []
	for tj in work.things.size():
		var tm := work._mesh_of(tj)
		if tm != null:
			meshes.append([tm, Transform3D.IDENTITY, (work.things[tj] as Dictionary)["mesh_box"]])
	for wi in work.works.size():
		var tm: Variant = (work.works[wi] as Dictionary).get("mesh")
		if tm != null:
			meshes.append([tm, Transform3D.IDENTITY, (work.works[wi] as Dictionary)["mesh_box"]])
	var raw := PackedFloat32Array()
	raw.resize(n.x * n.y)
	for k in n.y:
		_breathe()
		for i in n.x:
			var c := Vector3(lo.x + (float(i) + 0.5) * TOPS_CELL, 0.0, lo.y + (float(k) + 0.5) * TOPS_CELL)
			raw[k * n.x + i] = work._top_under([c], -1, 0.0, -1, meshes)
	_tops = raw
	_tops_at = lo
	_tops_n = n


## The highest thing mapped within [param reach] (meters, level) of [param p] ([method _map_tops]), or -INF.
func _top_at(p: Vector3, reach: float) -> float:
	if _tops.is_empty():
		return -INF
	var r := ceili(reach / TOPS_CELL)
	var i0 := floori((p.x - _tops_at.x) / TOPS_CELL)
	var k0 := floori((p.z - _tops_at.y) / TOPS_CELL)
	var top := -INF
	for k in range(maxi(k0 - r, 0), mini(k0 + r, _tops_n.y - 1) + 1):
		for i in range(maxi(i0 - r, 0), mini(i0 + r, _tops_n.x - 1) + 1):
			top = maxf(top, _tops[k * _tops_n.x + i])
	return top


## How far round its tip tool [param tool] ([method tool_of]) is as wide (meters, level).
static func _reach_of(tool: Dictionary) -> float:
	return float(tool.get("mm", 6.0)) * 0.0005 + TOPS_BESIDE


## HOW HIGH A WAY FROM [param pa] TO [param pb] MUST LIFT (meters, at its highest; [param seed] its hand's) for a tool [param reach]
## wide round its tip ([method _reach_of]) to pass [constant TableWork.CLEAR_GAP] over what stands under it, looked at through its
## middle as a carry's is ([method TableWork._clearance]) - none for a way shorter than [constant TableWork.CLEAR_FROM], or nothing in it.
func _lift_over(pa: Vector3, pb: Vector3, seed: int, reach: float) -> float:
	if _tops.is_empty() or pa.distance_to(pb) < TableWork.CLEAR_FROM:
		return 0.0
	var need := 0.0
	for k in TableWork.CLEAR_SAMPLES:
		var u := lerpf(TableWork.CLEAR_SPAN.x, TableWork.CLEAR_SPAN.y, float(k) / float(TableWork.CLEAR_SAMPLES - 1))
		var shape := Hands.lift_at(u)
		if shape < TableWork.CLEAR_SHAPE:
			continue
		var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, 0.0, u, seed)
		var top := _top_at(p, reach)
		if top > -INF:
			need = maxf(need, (top + TableWork.CLEAR_GAP - p.y) / shape)
	return minf(need, TableWork.CLEAR_MOST)


## THE THINGS PAINT TRACK [param tr]'s TOOL GOES INTO, as it is meant to: what it paints, and the pots, the water and the towel it
## goes to (one loaded with no `from` goes to whichever paint is nearest its color: every paint on the table) - pressed onto,
## never passing through ([method TableWork._pressed_by], [method TablePhysics._painted_by]). Its `press` alone had been: the
## brushes dipped into the palette were told they passed through it, and held back on the water cup (joker-motivation 856886).
func touches(tr: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var names := [String(tr.get("press", ""))]
	for k in ["from", "rinse", "dry"]:
		names.append(String(tr.get(k, "")).get_slice("/", 0).get_slice(".", 0))
	for nm in names:
		var ti := work._thing_named(String(nm)) if not String(nm).is_empty() else -1
		if ti >= 0 and not out.has(ti):
			out.append(ti)
	if String(tr.get("from", "")).is_empty():
		for cr in _creams:
			var ti := int((cr as Dictionary).get("ti", -1))
			if ti >= 0 and not out.has(ti):
				out.append(ti)
	return out


static func _in_reading_order(acts: Array) -> Array:
	var rank := func(b: String) -> int: return 0 if b == "intro" else (100000 if b == "close" else int(b))
	var order: Array = []
	for i in acts.size():
		order.append([rank.call(String((acts[i] as Dictionary)["beat"])), i])
	order.sort()
	return order.map(func(o: Array) -> Dictionary: return acts[int(o[1])])


## Element [param id] of skin [param si]'s design, or empty.
func element(si: int, id: String) -> Dictionary:
	for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
		if String((e as Dictionary)["id"]).to_lower() == id.strip_edges().to_lower():
			return e
	return {}


## WHAT A PAINT TRACK [param tr] NEEDS ON THE TABLE ([method TableWork._resolve]): the skin it paints (`_skin`) and the
## elements it names there - "" when found, else why not.
func resolve(tr: Dictionary) -> String:
	var on := String(tr.get("on", ""))
	var thing := on.get_slice("/", 0)
	var part := on.get_slice("/", 1) if on.contains("/") else ""
	var si := skin_named(thing, part)
	if si < 0:
		var have := PackedStringArray()
		for s in skins:
			have.append(String((s as Dictionary)["name"]) + ("/" + String((s as Dictionary)["part"]) if not String((s as Dictionary)["part"]).is_empty() else ""))
		return "nothing called \"%s\" has a surface to paint (%s)" % [on, ", ".join(have) if not have.is_empty() else "no part on this table has a `skin`"]
	tr["_skin"] = si
	var design: Dictionary = (skins[si] as Dictionary)["design"]
	# A SURFACE WITH NO DESIGN HAS NOTHING TO PAINT, and the act is told so - it had been taken, painted nothing and pressed its
	# tool into the bare surface, and the puppeteer reading "it paints:  - 3 s" could only guess why (joker-motivation 856886)
	if (design.get("elements", []) as Array).is_empty():
		tr["paint"] = []
		return "\"%s\" has no design yet, so there is nothing on it to paint (its design is made before the acts, in `skin.json`)" % on
	var kept: Array = []
	var missing := PackedStringArray()
	for id in tr.get("paint", []):
		if element(si, String(id)).is_empty():
			missing.append(String(id))
		else:
			kept.append(String(id))
	tr["paint"] = kept
	if not missing.is_empty():
		work.notes.append("paint on \"%s\": no element called %s in its design" % [on, ", ".join(Array(missing).map(func(m: String) -> String: return "\"%s\"" % m))])
	return "" if not kept.is_empty() else "it names no element of \"%s\"'s design (%s)" % [on, ", ".join(_ids(si))]


func _ids(si: int) -> PackedStringArray:
	var out := PackedStringArray()
	for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
		out.append(String((e as Dictionary)["id"]))
	return out


## WHAT A TOOL IS, found once for channel [param ch]: its tip and grip (its node's space, meters - its own points `tip` and
## `grip`, else found), what kind of tool it is ("brush" for a tuft, "sponge", or "tool"), how wide it works (millimeters),
## its tufts' and sponges' materials - and its own surface (`points`, its node's space) and THE WAYS IT IS HELD (`contacts`: each
## a tip, a grip it points along, how far it is pressed in where it is pressed hardest - `give` - how far its hairs reach, `bend`,
## and how far its tip is from its middle, `reach`): a brush and a pad by their tip, a sponge by its face and by its corner.
func tool_of(ch: String, tr: Dictionary) -> Dictionary:
	if tools.has(ch):
		return tools[ch]
	var node: Node3D = null
	var pts := {}
	var meshes: Array = []
	if ch.begins_with("w"):
		var wi := int(tr.get("_wi", -1))
		node = (work.works[wi] as Dictionary)["node"]
		pts = ((work.works[wi] as Dictionary)["w"] as Dictionary).get("points", {})
		meshes = node.find_children("*", "MeshInstance3D", true, false)
	else:
		var ti := int(tr.get("_ti", -1))
		node = (work.things[ti] as Dictionary)["node"]
		meshes = (work.things[ti] as Dictionary)["meshes"]
	var tufts: Array = []
	var sponges: Array = []
	var box := AABB()
	var first := true
	var inv := work._world_of(node).affine_inverse()
	var faces := PackedVector3Array()
	# (...its hairs' apart from the rest - [method _sunk_node] lets hairs alone bend and give)
	var hair_faces := PackedVector3Array()
	var hair_box := AABB()
	var stiff_faces := PackedVector3Array()
	var stiff_box := AABB()
	for m in meshes:
		var mi := m as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		var to_node := inv * work._world_of(mi)
		var b: AABB = to_node * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		if mi.mesh != null:
			var own := to_node * mi.mesh.get_faces()
			faces.append_array(own)
			if mat != null and mat.has_meta("tuft"):
				hair_box = b if hair_faces.is_empty() else hair_box.merge(b)
				hair_faces.append_array(own)
			else:
				stiff_box = b if stiff_faces.is_empty() else stiff_box.merge(b)
				stiff_faces.append_array(own)
		if mat == null:
			continue
		if mat.has_meta("tuft"):
			tufts.append({"mat": mat, "mesh": mi, "tuft": mat.get_meta("tuft")})
		var kd: Variant = mat.get_shader_parameter("kind")
		if kd != null and int(kd) == int((Props.MATERIALS["sponge"] as Dictionary)["code"]):
			sponges.append({"mat": mat, "mesh": mi})
	var out := {"node": node, "kind": "tool", "mm": 6.0, "tufts": tufts, "sponges": sponges, "box": box, "len": 0.0}
	if not tufts.is_empty():
		var tf: Dictionary = (tufts[0] as Dictionary)["tuft"]
		out["kind"] = "brush"
		out["mm"] = float(tf["mm"])
		out["len"] = float(tf["len"])
		# (...as far as its hairs bend at all: a cotton swab's bud, wound tight on its stick, a little - [constant Bristles.KINDS])
		out["bends"] = Bristles.bends_of(String(tf["kind"]))
		# its tip the tuft's, its grip back along the handle
		var to_node := inv * work._world_of((tufts[0] as Dictionary)["mesh"])
		var root: Vector3 = to_node * (tf["root"] as Vector3)
		var axis: Vector3 = (to_node.basis * (tf["axis"] as Vector3)).normalized()
		out["tip"] = root + axis * float(tf["len"])
		out["grip"] = root - axis * maxf(box.size.length() * 0.6, 0.05)
		# ...AND ITS HAIRS' POINTS, the lower two thirds of each (what can reach the face), with how far up its hair each is - bent as the
		# shader bends them, what of them touches the face is what it paints ([method _touched])
		var hp := PackedVector3Array()
		var hs := PackedFloat32Array()
		var hc := PackedByteArray()
		var seen_h := {}
		for td in tufts:
			var tmi: MeshInstance3D = (td as Dictionary)["mesh"]
			if tmi.mesh == null:
				continue
			var arr := tmi.mesh.surface_get_arrays(0)
			var tv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var tu2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			var tu: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if tu2.size() != tv.size():
				continue
			var tn := inv * work._world_of(tmi)
			for i in tv.size():
				if tu2[i].x < HAIR_TOUCH_FROM:
					continue
				var q := tn * tv[i]
				var key := Vector3i(roundi(q.x * 2500.0), roundi(q.y * 2500.0), roundi(q.z * 2500.0))
				if seen_h.has(key):
					continue
				seen_h[key] = true
				hp.append(q)
				hs.append(tu2[i].x)
				# (...the core's drawn in and down under the hairs as they splay - [method Bristles.core_at])
				hc.append(1 if i < tu.size() and tu[i].x > Bristles.CORE_MARK - 0.5 else 0)
		if not hp.is_empty():
			out["touch"] = hp
			out["touch_s"] = hs
			out["touch_core"] = hc
			out["hair_root"] = root
			out["hair_axis"] = axis
	elif not sponges.is_empty():
		out["kind"] = "sponge"
		var dims := [box.size.x, box.size.y, box.size.z]
		dims.sort()
		out["mm"] = sqrt(float(dims[1]) * float(dims[2])) * 1000.0 * 0.7
		out["tip"] = Vector3(box.get_center().x, box.position.y, box.get_center().z)
		out["grip"] = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	else:
		var dims := [box.size.x, box.size.y, box.size.z]
		var sorted := dims.duplicate()
		sorted.sort()
		var c := box.get_center()
		out["mm"] = clampf(float(dims.min()) * 1000.0, 3.0, 40.0)
		# A PAD (a puff, a pad of cotton, a stamp): pressed with its face, as wide as that face - it is far thinner one way than the others
		if float(sorted[0]) < float(sorted[1]) * 0.5 and float(sorted[1]) > float(sorted[2]) * 0.5:
			var thin := dims.find(sorted[0])
			var axis := Vector3.ZERO
			axis[thin] = box.size[thin] * 0.5
			out["mm"] = clampf(sqrt(float(sorted[1]) * float(sorted[2])) * 1000.0 * 0.7, 3.0, 60.0)
			out["tip"] = c - axis
			out["grip"] = c + axis
			out["flat"] = true
			# ...soft, as a puff is: drawn squashed where it is pressed ([constant PAD_GIVE], [method _tick_tool])
			for m in meshes:
				var pm := (m as MeshInstance3D).material_override as ShaderMaterial
				if pm != null:
					sponges.append({"mat": pm, "mesh": m})
		elif box.size.y >= box.size.x and box.size.y >= box.size.z:
			out["tip"] = Vector3(c.x, box.position.y, c.z)
			out["grip"] = Vector3(c.x, box.end.y, c.z)
		elif box.size.x >= box.size.z:
			out["tip"] = Vector3(box.position.x, c.y, c.z)
			out["grip"] = Vector3(box.end.x, c.y, c.z)
		else:
			out["tip"] = Vector3(c.x, c.y, box.end.z)
			out["grip"] = Vector3(c.x, c.y, box.position.z)
	for k in pts:
		if String(k).to_lower() == "tip":
			out["tip"] = pts[k]
		elif String(k).to_lower() == "grip":
			out["grip"] = pts[k]
	if tr.has("size"):
		out["mm"] = float(tr["size"])
	# ...AND HOW IT IS HELD, its own surface clear of what it works on
	var c := box.get_center()
	var tm: TriangleMesh = TableWork._ray_mesh(faces) if not faces.is_empty() else null
	out["x0"] = work._rest.get(ch, work._world_of(node))
	# ...and a flat brush's broad way, its node's space ([method _node_at] turns it to its stroke)
	if not tufts.is_empty() and String(((tufts[0] as Dictionary)["tuft"] as Dictionary)["kind"]) in ["flat", "fan"] and ((tufts[0] as Dictionary)["tuft"] as Dictionary).has("across"):
		var to_node_t := inv * work._world_of((tufts[0] as Dictionary)["mesh"])
		out["across"] = (to_node_t.basis * (((tufts[0] as Dictionary)["tuft"] as Dictionary)["across"] as Vector3)).normalized()
	out["center"] = c
	# ...A BRUSH'S HANDLE AND FERRULE FOUND APART FROM ITS HAIRS, the first `stiff` of its points: only its hairs bend and give as it is
	# pressed ([method _sunk_node]). Forgiven its hairs' bend and give, and looked at every 14 mm, the ferrule of 732687's round brush laid
	# low on its belly stood 6 mm in the mask's nose where the clearance read it 3-5 mm clear of it (feedback 0003). AND ITS RIMS AS ITS
	# MESH HAS THEM, a point every POINTS_RIM: rays across its box graze a ferrule's lip, its lowest edge laid low, and a flat brush's on a
	# nose's ridge stood 3 mm in it with no point of the clearance's nearer than 4.5 mm
	if String(out["kind"]) == "brush" and not stiff_faces.is_empty() and not hair_faces.is_empty():
		var stiff := _surface_points(TableWork._ray_mesh(stiff_faces), stiff_box)
		var seen := {}
		for v in stiff_faces:
			var cell := Vector3i((v / POINTS_RIM).round())
			if not seen.has(cell):
				seen[cell] = true
				stiff.append(v)
		out["stiff"] = stiff.size()
		# ...and, for a pose as it is drawn ([method _kept_out]), its handle and ferrule found every KEEP_EVERY over each of their faces:
		# between points 5 mm apart a ferrule's lip laid on a nose's ridge stood 1.4 mm in it (feedback 0003)
		out["stiff_dense"] = _dense_points(stiff_faces, KEEP_EVERY)
		stiff.append_array(_surface_points(TableWork._ray_mesh(hair_faces), hair_box))
		out["points"] = stiff
	else:
		out["points"] = _surface_points(tm, box)
	var kind := String(out["kind"])
	var bends := float(out.get("bends", 1.0))
	var held := {"tip": out["tip"], "grip": out["grip"], "give": GIVE if kind == "sponge" else (float(out["len"]) * TIP_PUSH * bends if kind == "brush" else (PAD_GIVE if bool(out.get("flat", false)) else 0.0)),
		"bend": float(out["len"]) * bends if kind == "brush" else 0.001}
	out["ch"] = ch
	out["contact"] = "face" if kind == "sponge" or bool(out.get("flat", false)) else "tip"
	out["contacts"] = {String(out["contact"]): held}
	# A BRUSH LAYING A FILL PRESSED DEEPER, its belly brought down onto the face ([constant BELLY_PUSH]; held low, [constant HELD_LOW])
	if kind == "brush":
		(out["contacts"] as Dictionary)["belly"] = {"tip": out["tip"], "grip": out["grip"], "give": float(out["len"]) * BELLY_PUSH * bends, "bend": float(out["len"]) * bends}
	# A SPONGE'S CORNER: the point of its surface toward a corner of its box, held through its middle
	if kind == "sponge":
		var corner := box.position
		var hit := TableWork._ray(tm, corner + (corner - c).normalized() * 0.01, (c - corner).normalized()) if tm != null else {}
		(out["contacts"] as Dictionary)["corner"] = {"tip": hit["position"] if not hit.is_empty() else corner, "grip": c, "give": GIVE, "bend": 0.001}
		# ...and its face tipped onto that corner a little ([constant TILTS]): the corner down, held along a way between the face's and the
		# corner's, as far from the corner as its middle is
		var c_tip: Vector3 = hit["position"] if not hit.is_empty() else corner
		var flat_up := ((held["grip"] as Vector3) - (held["tip"] as Vector3)).normalized()
		var to_mid := (c - c_tip).normalized()
		var steepest := flat_up.angle_to(to_mid)
		for nm in TILTS:
			var share := clampf(deg_to_rad(float(TILTS[nm])) / maxf(steepest, 1e-3), 0.0, 1.0)
			(out["contacts"] as Dictionary)[nm] = {"tip": c_tip, "grip": c_tip + flat_up.slerp(to_mid, share) * c_tip.distance_to(c), "give": GIVE,
				"bend": 0.001, "lean": share}
		# ...AND THAT CORNER HELD ALONG ITS LENGTH, toward the middle of its far end: how it is dipped into its paint - its long side
		# steep and its end's corner down, as a hand dips a wedge. Through its middle, balanced on the corner, a box is as wide as it can
		# be just over it, and a pot's rim kept all but the corner out of the cream
		var long := 0 if box.size.x >= box.size.y and box.size.x >= box.size.z else (1 if box.size.y >= box.size.z else 2)
		var far := c
		far[long] = box.end[long]
		(out["contacts"] as Dictionary)["end"] = {"tip": hit["position"] if not hit.is_empty() else corner, "grip": far, "give": GIVE, "bend": 0.001}
	for nm in out["contacts"]:
		var hd: Dictionary = out["contacts"][nm]
		hd["reach"] = maxf(((hd["tip"] as Vector3) - c).dot(((hd["tip"] as Vector3) - (hd["grip"] as Vector3)).normalized()), 0.002)
	# ...A PAD TIPPED ONTO ITS EDGE where its face cannot reach (round a nose, a puff's 45 mm face held off the creases beside it - feedback
	# 0035): the point of its edge toward a corner of its box, held through its middle, as a sponge's corner is ([method _held_keys])
	if bool(out.get("flat", false)):
		var corner_p := box.position
		var hit_p := TableWork._ray(tm, corner_p + (corner_p - c).normalized() * 0.01, (c - corner_p).normalized()) if tm != null else {}
		(out["contacts"] as Dictionary)["corner"] = {"tip": hit_p["position"] if not hit_p.is_empty() else corner_p, "grip": c, "give": PAD_GIVE, "bend": 0.001,
			"reach": maxf(((hit_p["position"] if not hit_p.is_empty() else corner_p) as Vector3 - c).length(), 0.002)}
	# ...AND ITS SURFACE FOUND FINELY, for what of it touches the face ([method _touched]): a sponge's, a pad's
	if kind == "sponge" or bool(out.get("flat", false)):
		var tn: Array = []
		out["touch"] = _surface_points(tm, box, TOUCH_EVERY, 90, tn)
		out["touch_n"] = PackedVector3Array(tn)
	tools[ch] = out
	return out


## WHERE A TOOL'S OWN SURFACE IS (its node's space): rays straight in from across each face of its box [param box], every
## [constant POINTS_EVERY], where each meets [param tm] - a box's corners and its faces to their edges alike, which its corners alone are
## not (and rays aimed at its middle met a face's edges from the side). Given an Array [param normals], the way each faces is put in it.
## Points over each of triangles [param faces] (three a face) no further than [param every] apart along each of its two edges, one kept
## each [constant POINTS_RIM] - a long, thin face (a handle's side, end to end) looked at along its length, never only at its corners.
static func _dense_points(faces: PackedVector3Array, every: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var seen := {}
	for k in range(0, faces.size() - 2, 3):
		var a := faces[k]
		var e1 := faces[k + 1] - a
		var e2 := faces[k + 2] - a
		var nu := maxi(ceili(e1.length() / every), 1)
		var nv := maxi(ceili(e2.length() / every), 1)
		for i in nu + 1:
			for j in nv + 1:
				var u := float(i) / float(nu)
				var v := float(j) / float(nv)
				if u + v > 1.0001:
					continue
				var p := a + e1 * u + e2 * v
				var cell := Vector3i((p / POINTS_RIM).round())
				if not seen.has(cell):
					seen[cell] = true
					out.append(p)
	return out


static func _surface_points(tm: TriangleMesh, box: AABB, every := POINTS_EVERY, most := POINTS_MOST, normals: Variant = null) -> PackedVector3Array:
	var out := PackedVector3Array()
	if tm == null:
		return out
	var b := box.grow(0.002)
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var nu := clampi(ceili(box.size[u] / every) + 1, 2, most)
		var nv := clampi(ceili(box.size[v] / every) + 1, 2, most)
		for side in 2:
			var into := Vector3.ZERO
			into[ax] = 1.0 if side == 0 else -1.0
			for i in nu:
				for j in nv:
					var q := b.position
					q[ax] = b.position[ax] if side == 0 else b.end[ax]
					q[u] = lerpf(box.position[u], box.end[u], float(i) / float(nu - 1))
					q[v] = lerpf(box.position[v], box.end[v], float(j) / float(nv - 1))
					var hit := TableWork._ray(tm, q, into)
					if not hit.is_empty():
						out.append(hit["position"])
						# (...and, asked for, which way it faces there - out, against the ray that found it)
						if normals != null:
							var hn: Vector3 = hit["normal"]
							(normals as Array).append(-hn if hn.dot(into) > 0.0 else hn)
	return out


## WHERE TOOL [param tool] TOUCHES SKIN [param si] held [param h] (the table's space, the skin as it rests): every bit of its surface
## ([method tool_of]'s `touch`) within [constant TOUCH_BAND] of what stands over the skin, or in it - a sponge pushed in gives and is
## drawn squashed onto it - as millimeters across and down the skin's front ([method at_mm]'s).
func _touched(si: int, tool: Dictionary, h: Array, bend := Vector3.ZERO, splay := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pts: PackedVector3Array = tool.get("touch", PackedVector3Array())
	if pts.is_empty():
		return out
	# (a press is looked at again round after round, and kept; a brush's every moment is its own)
	var keep := not tool.has("touch_s")
	var tk := ""
	if keep:
		tk = "%d|%s|%s|%s|%s|%s" % [si, tool.get("ch", ""), h[0], h[1], h[2], _contact_of(h)]
		if _touch_memo.has(tk):
			return _touch_memo[tk]
	# ...A BRUSH'S HAIRS BENT [param bend] aside and splayed [param splay] (its node's space, [method Bristles.target]), as prop_common's
	# `bristle_bend` draws them: an arc as long as each hair, spread out from the middle
	if tool.has("touch_s") and (bend.length_squared() > 1e-12 or splay > 0.0):
		var hs: PackedFloat32Array = tool["touch_s"]
		var hc: PackedByteArray = tool.get("touch_core", PackedByteArray())
		var root: Vector3 = tool["hair_root"]
		var ax: Vector3 = tool["hair_axis"]
		var hl := maxf(float(tool["len"]), 1e-4)
		var aside := bend - ax * bend.dot(ax)
		var side := aside.length()
		var th := Bristles.arc_angle(minf(side / hl, Bristles.ASIDE_MOST))
		var along := aside / side if side > 1e-9 else Vector3.ZERO
		var rr := hl / th if th > 1e-4 else 0.0
		var bent := PackedVector3Array()
		bent.resize(pts.size())
		for i in pts.size():
			var sv := hs[i]
			var p := pts[i]
			var off := p - root
			var out_by := splay * sv * 1.2
			if i < hc.size() and hc[i] == 1:
				var core := Bristles.core_at(sv, splay)
				p -= ax * off.dot(ax) * core.y
				sv = core.x
				out_by = core.z
			var q := p + (off - ax * off.dot(ax)) * out_by
			if th > 1e-4:
				q += ax * (rr * sin(th * sv) - hl * sv) + along * rr * (1.0 - cos(th * sv))
			bent[i] = q
		pts = bent
	var sd: Dictionary = skins[si]
	var g := _obstacles(sd)
	var to_front: Transform3D = (g["to_part"] as Transform3D) * _node_at(h, tool, tool["x0"])
	var qs: PackedVector3Array = to_front * pts
	var box: AABB = sd["box"]
	var at: Vector2 = g["at"]
	var n: Vector2i = g["n"]
	var Z: PackedFloat32Array = g["z"]
	var top: PackedFloat32Array = g["top"]
	var bn: Vector2i = g["bn"]
	# ...A PAD PRESSED ONTO IT TAKES ITS SHAPE as it is drawn ([method _press_point]): what of it is drawn within the band of it touches,
	# where it is drawn - its face sagged into a hollow beside what it is pressed onto, what would go into it laid on it. (A sponge, whose
	# foam does not sag, touches by the reading below, its stipple's go-back loop tuned to it: read as a pad's, a stippled base left 911
	# mm2 bare at its first look where it had left 213, and 29 never painted on a nose's steep sides.)
	var nn: PackedVector3Array = tool.get("touch_n", PackedVector3Array())
	if nn.size() == pts.size() and h.size() > 3 and bool(h[3]) and bool(tool.get("flat", false)):
		var ps := _press_of(tool, h, to_front)
		var pf := _press_field(sd)
		# (looked at closer under what stands highest round it read every 2 mm, and as far over it as a ridge between those stands)
		var reach := TOUCH_BAND + float(ps["sag"]) + CLEAR_CELL
		var low := _press_touches()
		for idx in qs.size():
			var q := qs[idx]
			var fx := (q.x - at.x) / CLEAR_CELL
			var fy := (q.y - at.y) / CLEAR_CELL
			if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
				continue
			if q.z - top[(mini(int(fy), n.y - 2) / CLEAR_BLOCK) * bn.x + mini(int(fx), n.x - 2) / CLEAR_BLOCK] > reach:
				continue
			var lands := _press_point(pf, ps, q, nn[idx])
			if not is_nan(lands.w) and lands.w <= low:
				out.append(Vector2((lands.x - box.position.x) * 1000.0, (box.end.y - lands.y) * 1000.0))
		if keep:
			_touch_memo[tk] = out
		return out
	for q in qs:
		var fx := (q.x - at.x) / CLEAR_CELL
		var fy := (q.y - at.y) / CLEAR_CELL
		if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
			continue
		var i := mini(int(fx), n.x - 2)
		var j := mini(int(fy), n.y - 2)
		# (a point over the highest of what is round it touches nothing there: most of a brush's hairs, most of the time)
		if q.z - top[(j / CLEAR_BLOCK) * bn.x + i / CLEAR_BLOCK] > TOUCH_BAND:
			continue
		var k := j * n.x + i
		var z00 := Z[k]
		var z10 := Z[k + 1]
		var z01 := Z[k + n.x]
		var z11 := Z[k + n.x + 1]
		var z := -INF
		if z00 == -INF or z10 == -INF or z01 == -INF or z11 == -INF:
			# (BY THE RIM, part of the cell off the surface: the highest of it there is - skipped, a band along the rim never showed)
			z = maxf(maxf(z00, z10), maxf(z01, z11))
			if z == -INF:
				continue
		else:
			var a := fx - float(i)
			z = lerpf(lerpf(z00, z10, a), lerpf(z01, z11, a), fy - float(j))
			# (...and where it falls steeply across the cell - a rim's wall - as high as it stands there: read between, a point on the wall's
			# top stood over a surface dropped to the board beside it)
			var hi := maxf(maxf(z00, z10), maxf(z01, z11))
			if hi - minf(minf(z00, z10), minf(z01, z11)) > TOUCH_STEEP:
				z = hi
		if q.z - z <= TOUCH_BAND:
			out.append(Vector2((q.x - box.position.x) * 1000.0, (box.end.y - q.y) * 1000.0))
	if keep:
		_touch_memo[tk] = out
	return out


## HOW WIDE TOOL [param tool] TOUCHES held [param contact] and pressed its hardest, on something flat (millimeters): as wide as a disc as
## large as what of it touches ([method _touched]'s test) - a sponge's corner pushed in as far as it gives, a puff's face.
func _touch_width(tool: Dictionary, contact: String) -> float:
	var pts: PackedVector3Array = tool.get("touch", PackedVector3Array())
	if pts.is_empty():
		return float(tool["mm"])
	var axis := (Vector3.UP * CORNER_HELD.x + Vector3.BACK * CORNER_HELD.y).normalized() if contact == "corner" else Vector3.UP
	var give := float(_contact(tool, contact)["give"])
	var hold := [Vector3(0.0, TOUCH, 0.0) - axis * give, axis, 1.0, true, TRIP_LIFT, contact]
	var x := _node_at(hold, tool, tool["x0"])
	# (...drawn as it takes the shape of what it is pressed onto - [method press_lands] - in the flat's own front: across, along, out)
	var nn: PackedVector3Array = tool.get("touch_n", PackedVector3Array())
	var ps := _press_of(tool, hold, Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).inverse(), Vector3.ZERO) * x) \
		if nn.size() == pts.size() and bool(tool.get("flat", false)) else {}
	var cells := {}
	var qs := x * pts
	var low := _press_touches() if not ps.is_empty() else TOUCH_BAND
	for i in qs.size():
		var q := qs[i]
		var hh := q.y
		if not ps.is_empty():
			var qf := Vector3(q.x, -q.z, q.y)
			hh = press_lands(q.y, maxf((qf - (ps["tip"] as Vector3)).dot(ps["up"] as Vector3), 0.0),
				smoothstep(-0.2, 0.2, nn[i].normalized().dot(ps["up_own"] as Vector3)), float(ps["sag"]))
		if hh <= low:
			cells[Vector2i(floori(q.x / TOUCH_EVERY), floori(q.z / TOUCH_EVERY))] = true
	var mm2 := float(cells.size()) * pow(TOUCH_EVERY * 1000.0, 2.0)
	return clampf(sqrt(mm2 * 4.0 / PI), 2.0, float(tool["mm"]))


## THE PAINTING IS THE DESIGN (next/painted_surface.md; [PaintLayers]): where the surface was painted first as a picture
## ([member TableWork.skin_ref]), each element a tool lays by dabs, pulls or lines is an OPERATION - its act's tool, its pot, its manner,
## and its shape grown a little as where it works - laid from the picture on one canvas, element by element in the order the reading
## comes to their acts: its strokes only where the canvas still differs from the picture and the tool's footprint fits, each made by the
## program the show plays (its loads, its trips back to the pot) and drawn as the tool lays it - and that program, that paint (the marks'
## own coverage) and that reveal are the element's, nothing looked for after (no gap loop, no touch map: it is what was laid). An element
## whose fill is the whole surface, first, is a FOUNDATION: its own paint, laid by the corner's own dabs, each a thin film, gone back over
## where it is still thin until it is whole - never spreading past where a dab touched (the old stipple's paint, read from a map a point a
## millimeter with a ragged edge, showed about 3 mm past every touch, and its holes filled as later presses landed: it "would ooze and
## spread outward, in a crawling fashion"). The
## decorator's shape says where, the picture what, the tool how (the user, 2026-11-07: "The tools are just there to give the visualization
## of our self-correction process"; 2026-11-08: "the expression is not only in the layering: it is in how the tools put those layers on").
func _from_picture() -> void:
	var ref: Image = work.skin_ref
	if ref == null:
		return
	var on := String(work.skin_ref_on)
	var si := skin_named(on.get_slice("/", 0), on.get_slice("/", 1) if on.contains("/") else "") if not on.is_empty() else (0 if not skins.is_empty() else -1)
	if si < 0:
		return
	var sd: Dictionary = skins[si]
	var frame: Vector2 = sd["frame"]
	var creams: Array = []
	for cr in _creams:
		if not bool((cr as Dictionary).get("powder", false)):
			creams.append((cr as Dictionary)["color"])
	if creams.is_empty():
		return
	# (...the elements as their acts come in the reading, and the paint of the first that fills the whole surface the picture's ground)
	var ops: Array = []
	var ground := Color(-1, -1, -1)
	for a in _in_reading_order(work.acts):
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or int(t.get("_skin", -1)) != si or not t.has("_ch"):
				continue
			for id in t["paint"]:
				var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
				var ed := element(si, String(id))
				if lay.is_empty() or ed.is_empty() or lay.get("act") != (a as Dictionary)["name"]:
					continue
				# (...a smear too, laid as a line of the paint it drags: the old drag had drawn the tears under an eye a grey no pot holds)
				if String(ed["kind"]) != "smear" and (not String(lay["manner"]) in PICTURE_MANNERS or not String(ed["kind"]) in ["fill", "line", "dots"]):
					continue
				var whole := String(ed["kind"]) == "fill" and String(ed.get("d", "")) == "all"
				if whole and ground.r < 0.0:
					ground = Color.html(String(lay.get("pot", ed["paint"])))
				ops.append({"id": String(id).to_lower(), "ed": ed, "lay": lay, "track": t, "base": whole and ops.is_empty()})
	if ops.is_empty():
		return
	if ground.r < 0.0:
		ground = creams[0]
		for c in creams:
			if (c as Color).get_luminance() > ground.get_luminance():
				ground = c
	# (...the surface where its own outline says, never where the picture's clear edge does)
	var surface := PackedByteArray()
	var whole_cov := Skins.cover({"kind": "fill", "d": "all"}, Rect2(Vector2.ZERO, frame), PaintLayers.PX, String(sd.get("outline", "")), frame)
	if whole_cov != null:
		surface = covered_in(whole_cov)
	# (...its canvas begun only for an element it lays itself: the painter at the table's elements bring their own - a canvas begun for
	# nothing had cost seconds a build)
	var pl: PaintLayers = null
	for o in ops:
		var od: Dictionary = o
		var ed: Dictionary = od["ed"]
		var lay: Dictionary = od["lay"]
		var item: Dictionary = (sd.get("items", {}) as Dictionary).get(String(od["id"]), {})
		if item.is_empty():
			continue
		var made: Dictionary = item["made"]
		# (...laid by the painter at the table: played as it wrote it, never laid again here - [method _from_hosts])
		if not _host_of(ed).is_empty():
			continue
		# (...AS LONG AS ITS ACT WAS PLANNED: the program its shape made, the length the readers' words were written to - kept from the
		# first build, before it is laid)
		if not made.has("shape_natural"):
			made["shape_natural"] = float((made["program"] as Dictionary).get("natural", 0.0))
		# (...its picture as wide as its tool reaches round where it works, its sprites made to fit: a sponge by a small element's edge had
		# been kept out of it)
		var reach := float(lay["mm"]) * 0.5 + PaintLayers.RAGGED + PaintLayers.EDGE_SOFT + PaintLayers.REGION_GROW + 1.0
		var rect := Skins.rect_of(ed, frame, reach)
		made["rect"] = rect
		var blank := Image.create(maxi(int(ceil(rect.size.x * CANVAS_PX)), 1), maxi(int(ceil(rect.size.y * CANVAS_PX)), 1), false, Image.FORMAT_L8)
		blank.fill(Color.WHITE)
		made["cover_tex"] = ImageTexture.create_from_image(blank)
		for sp in item["sprites"]:
			(sp as Sprite2D).texture = made["cover_tex"]
			(sp as Sprite2D).position = rect.position * CANVAS_PX
		if pl == null:
			pl = PaintLayers.begin(ref, frame, _bare_of(sd), creams, ground, surface)
		var region := PackedByteArray()
		var cov := Skins.cover(ed, Rect2(Vector2.ZERO, frame), PaintLayers.PX, String(sd.get("outline", "")), frame)
		if cov != null and cov.get_width() == pl.w and cov.get_height() == pl.h:
			region = covered_in(cov)
		# (...a sponge's dab as wide as its corner touches - its touch's width is the widest it ever presses, half again what a press lays)
		var r_mark := float(lay["mm"]) * (PICTURE_CORNER if String(lay["manner"]) == "stipple" else 0.5)
		var smear := String(ed["kind"]) == "smear"
		if smear:
			r_mark = maxf(float(ed.get("width", 1.2)) * 0.5, 0.6)
		# ...AND A SPONGE DABBED WITH WHICHEVER SIDE THE WORK NEEDS, judged by what that side really touches there, as the show will pose it
		var tool := tool_of(String((od["track"] as Dictionary)["_ch"]), od["track"])
		var sides: Array = []
		var touch := Callable()
		if String(lay["manner"]) == "stipple" and String(tool.get("kind", "")) == "sponge" and not smear:
			# (...the broadest first, then tipped onto its corner more and more - never further than 40 degrees, the corner held through its
			# middle had turned the sponge 60 at every corner's dab)
			for side in ["face", "tilt12", "tilt25", "tilt40"]:
				if (tool.get("contacts", {}) as Dictionary).has(side):
					sides.append(side)
			touch = func(xy: Vector2, side: String, press: float) -> PackedVector2Array: return _side_touch(si, tool, side, xy, press)
		var res := pl.lay({"id": od["id"], "manner": "line" if smear else String(lay["manner"]), "paint": Color.html(String(lay.get("pot", ed["paint"]))),
			"opacity": clampf(float(ed.get("opacity", 1.0)) * float(lay.get("thick", 1.0)), 0.1, 1.0), "r": r_mark,
			"region": PackedByteArray() if bool(od["base"]) else region, "base": bool(od["base"]), "rect": made["rect"], "frame": frame,
			"grow": PAINTER_GROW if ed.get("plan") is Dictionary else (PICTURE_GROW_LINE if String(ed["kind"]) in ["line", "dots", "smear"] else PaintLayers.REGION_GROW),
			"seed": hash([String(od["id"]), String(lay["manner"])]),
			"budget": _picture_budget(ed, made, bool(od["base"])),
			"mix": ((ed.get("plan", {}) as Dictionary).get("mix", []) as Array).map(func(c: Variant) -> Color: return Color.html(String(c))) if ed.get("plan") is Dictionary else [],
			"touch": touch, "sides": sides})
		var prog: Dictionary = res["program"]
		# (...by which its holds are kept - [method _held_keys]: a program laid again on another canvas is another program)
		prog["id"] = "%s|picture|%d" % [String(od["id"]), hash(prog["keys"])]
		prog["pot"] = String(lay.get("pot", ed["paint"]))
		made["program"] = prog
		made["planned"] = prog
		made["laid"] = true
		made["foot"] = res["coverage"]
		made["foot_tex"] = ImageTexture.create_from_image(res["coverage"])
		made["when"] = res["when"]
		made["when_tex"] = ImageTexture.create_from_image(res["when"])
		# (...and BUILT UP AS IT WAS LAID: each point at what the marks so far have laid there - shown at what they all came to from the first
		# that touched it, every dab had looked "extremely heavy with paint", "no opacity at all" - [method PaintLayers.render])
		made["built_tex"] = [ImageTexture.create_from_image((res["built"] as Array)[0]), ImageTexture.create_from_image((res["built"] as Array)[1])]
		made["built_when"] = res["built_when"]
		made["built_when_tex"] = [ImageTexture.create_from_image((res["built_when"] as Array)[0]), ImageTexture.create_from_image((res["built_when"] as Array)[1])]
		# (...IN THE COLORS ITS MARKS CARRY, where they carry their own - mixed on the palette, or taken up from the surface by a clean brush)
		made["tint_tex"] = ImageTexture.create_from_image(res["tint"]) if res.get("tint") is Image else null
		for m in item["mats"]:
			var mat := m as ShaderMaterial
			mat.set_shader_parameter("tinted", made["tint_tex"] != null)
			if made["tint_tex"] != null:
				mat.set_shader_parameter("tint_map", made["tint_tex"])
			mat.set_shader_parameter("foot", made["foot_tex"])
			mat.set_shader_parameter("footed", true)
			mat.set_shader_parameter("when_map", made["when_tex"])
			mat.set_shader_parameter("laid_map", (made["built_tex"] as Array)[0])
			mat.set_shader_parameter("laid_when", (made["built_when_tex"] as Array)[0])
			mat.set_shader_parameter("laid_map2", (made["built_tex"] as Array)[1])
			mat.set_shader_parameter("laid_when2", (made["built_when_tex"] as Array)[1])
			mat.set_shader_parameter("laid_on", true)
			# (...the marks' own coverage is the paint - its film, its load, its thinness laid in it already)
			mat.set_shader_parameter("pressed", 0)
			mat.set_shader_parameter("opacity", 1.0)
			# (...softened by a blend no more than [constant PICTURE_BLEND_LOD]: the planner never sees a blend's blur, and blurred whole a
			# blended element's every detail had gone)
			var lods: Vector2 = mat.get_shader_parameter("lods")
			mat.set_shader_parameter("lods", Vector2(0.0, minf(lods.y, PICTURE_BLEND_LOD)))


## AN ELEMENT THE PAINTER AT THE TABLE LAID (next/face_layers.md; hosts/paint/export.py): its program - the hand's keys and strokes, on
## the show's own pace - and its maps - what each point holds after each of its marks and when, what it comes to, its own colors - read
## from `paint/elements.json` as the host wrote them, and played as they are: what the painter laid is what the show draws.
## LAID BY THE PAINTER AT THE TABLE, a host (next/face_layers.md): every element it laid played from its program and maps as it wrote
## them - whatever act it falls in, its manner, or whether the surface has a picture - never laid again by the show's own painter.
func _from_hosts() -> void:
	for si in skins.size():
		var items: Dictionary = (skins[si] as Dictionary).get("items", {})
		for id in items:
			var item: Dictionary = items[id]
			var host_id := _host_of(item["el"])
			if not host_id.is_empty():
				_from_host(item, host_id, String(id), si)


## The painter host's element design element [param ed] plays; "" when the show lays it itself.
static func _host_of(ed: Dictionary) -> String:
	return String((ed.get("plan", {}) as Dictionary).get("host", "")) if ed.get("plan") is Dictionary else ""


## Element [param id] of skin [param si] ([param item]) played from the painter host's element [param host_id]: its box, its maps on its
## sprites' material, and its program - the tool's way over the surface, on the same clock as the maps.
func _from_host(item: Dictionary, host_id: String, id: String, si: int) -> void:
	var el := _host_element(host_id)
	if el.is_empty():
		push_warning("ghost: table - the painter's element %s is missing" % host_id)
		return
	var made: Dictionary = item["made"]
	var r: Array = el["rect"]
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	made["rect"] = rect
	var blank := Image.create(maxi(int(ceil(rect.size.x * CANVAS_PX)), 1), maxi(int(ceil(rect.size.y * CANVAS_PX)), 1), false, Image.FORMAT_L8)
	blank.fill(Color.WHITE)
	made["cover_tex"] = ImageTexture.create_from_image(blank)
	for sp in item["sprites"]:
		(sp as Sprite2D).texture = made["cover_tex"]
		(sp as Sprite2D).position = rect.position * CANVAS_PX
	var maps: Dictionary = el["maps"]
	var w := int(maps["w"])
	var h := int(maps["h"])
	var cover := _host_map(maps, "cover", w, h, Image.FORMAT_L8)
	var when := _host_map(maps, "when", w, h, Image.FORMAT_RGBH)
	var built := [_host_map(maps, "built0", w, h, Image.FORMAT_RGBA8), _host_map(maps, "built1", w, h, Image.FORMAT_RGBA8)]
	var built_when := [_host_map(maps, "built_when0", w, h, Image.FORMAT_RGBAH), _host_map(maps, "built_when1", w, h, Image.FORMAT_RGBAH)]
	var tint := _host_map(maps, "tint", w, h, Image.FORMAT_RGB8)
	if cover == null or when == null or tint == null or built.has(null) or built_when.has(null):
		push_warning("ghost: table - the painter's maps for %s could not be read" % host_id)
		return
	cover.generate_mipmaps()
	var p: Dictionary = el["program"]
	var strokes: Array = []
	# ...EACH PRESS HELD BY THE SIDE THE PAINTER PRESSED IT WITH (feedback 0012, 2026-11-09: "This sponge has, so far, never once used its
	# flat side ... if we're covering the whole face here"): its `side`, by its place, as a program laid from the picture says it
	# ([method _held_keys]' `way_at`) - every press of 732687's base, patted with the face, had been held by the corner, the manner's
	var way_at := {}
	for st in p.get("strokes", []):
		var sd2: Dictionary = st
		var pts := PackedVector2Array()
		for q in sd2["pts"]:
			pts.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
		strokes.append({"pts": pts, "t": PackedFloat32Array(sd2["t"]), "r": float(sd2["r"]), "load": PackedFloat32Array(sd2["load"]),
			"press": PackedFloat32Array(sd2["press"])})
		var side := WAYS.find(String(sd2.get("side", "")))
		if pts.size() == 1 and side > 0:
			way_at[pts[0]] = side
	var keys: Array = []
	for k in p.get("keys", []):
		var ka: Array = k
		keys.append([float(ka[0]), float(ka[1]), float(ka[2]), float(ka[3]), float(ka[4]), int(ka[5])])
	var prog := {"keys": keys, "strokes": strokes, "stones": [], "pats": [], "mists": [], "natural": maxf(float(p.get("natural", 0.1)), 0.1)}
	var lay: Dictionary = _layers.get("%d|%s" % [si, id], {})
	prog["manner"] = String(lay.get("manner", ""))
	# (...and the paint its trips back to the pot go to - [method _surface_hold])
	prog["pot"] = String(lay.get("pot", el.get("color", "")))
	prog["way_at"] = way_at
	prog["id"] = "%s|host|%d" % [id, hash(keys)]
	made["shape_natural"] = float(prog["natural"])
	made["program"] = prog
	made["planned"] = prog
	made["laid"] = true
	made["foot"] = cover
	made["foot_tex"] = ImageTexture.create_from_image(cover)
	made["when"] = when
	made["when_tex"] = ImageTexture.create_from_image(when)
	made["built_tex"] = [ImageTexture.create_from_image(built[0]), ImageTexture.create_from_image(built[1])]
	made["built_when"] = built_when
	made["built_when_tex"] = [ImageTexture.create_from_image(built_when[0]), ImageTexture.create_from_image(built_when[1])]
	made["tint_tex"] = ImageTexture.create_from_image(tint)
	for m in item["mats"]:
		var mat := m as ShaderMaterial
		mat.set_shader_parameter("foot", made["foot_tex"])
		mat.set_shader_parameter("footed", true)
		mat.set_shader_parameter("when_map", made["when_tex"])
		mat.set_shader_parameter("laid_map", (made["built_tex"] as Array)[0])
		mat.set_shader_parameter("laid_when", (made["built_when_tex"] as Array)[0])
		mat.set_shader_parameter("laid_map2", (made["built_tex"] as Array)[1])
		mat.set_shader_parameter("laid_when2", (made["built_when_tex"] as Array)[1])
		mat.set_shader_parameter("laid_on", true)
		mat.set_shader_parameter("tinted", true)
		mat.set_shader_parameter("tint_map", made["tint_tex"])
		mat.set_shader_parameter("pressed", 0)
		mat.set_shader_parameter("opacity", 1.0)
		mat.set_shader_parameter("lods", Vector2(0.0, 0.0))


## The painter at the table's element [param host_id], as `paint/elements.json` keeps it; {} none. Read once a build.
func _host_element(host_id: String) -> Dictionary:
	if _host_doc.is_empty() or String(_host_doc.get("_dir", "")) != String(work.skin_dir):
		_host_doc = {"_dir": String(work.skin_dir), "by": {}}
		var path := String(work.skin_dir).path_join("paint/elements.json")
		var j := JSON.new()
		if FileAccess.file_exists(path) and j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			for e in (j.data as Dictionary).get("elements", []):
				(_host_doc["by"] as Dictionary)[String((e as Dictionary)["id"])] = e
	return ((_host_doc["by"] as Dictionary).get(host_id, {}) as Dictionary)


## One of an element's maps, as the painter wrote it (raw, [param fmt], [param w] by [param h]); null when it cannot be read.
func _host_map(maps: Dictionary, tag: String, w: int, h: int, fmt: Image.Format) -> Image:
	var path := String(work.skin_dir).path_join("paint").path_join(String(maps.get(tag, "")))
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var want: int = w * h * {Image.FORMAT_L8: 1, Image.FORMAT_RGB8: 3, Image.FORMAT_RGBA8: 4, Image.FORMAT_RGBH: 6, Image.FORMAT_RGBAH: 8}[fmt]
	if bytes.size() != want:
		return null
	return Image.create_from_data(w, h, false, fmt, bytes)


## HOW LONG AN ELEMENT LAID FROM THE PICTURE MAY TAKE (seconds): a painter's operation as long as it took when the painter laid it
## (a painter's - a little more, the table's sponge pressing its real sides), else its shape's program's time and the share more it may run
## to ([constant PICTURE_SLACK]; a foundation's, whole, the most).
static func _picture_budget(ed: Dictionary, made: Dictionary, base: bool) -> float:
	var planned := float((ed.get("plan", {}) as Dictionary).get("seconds", 0.0)) if ed.get("plan") is Dictionary else 0.0
	if planned > 0.0:
		return planned * PLANNED_SLACK
	return float(made["shape_natural"]) * (FOUNDATION_SLACK if base else PICTURE_SLACK) if float(made["shape_natural"]) > 0.0 else INF


## WHAT A SPONGE DABBED AT [param xy] (millimeters of skin [param si]) HELD BY ITS [param side], pressed [param press], TOUCHES - held clear
## ([method _cleared]) and posed as the show poses it ([method _skin_hold]), its touch found as every press's is ([method _touched]); kept by
## where, which side and how hard ([member _touch_memo]).
func _side_touch(si: int, tool: Dictionary, side: String, xy: Vector2, press: float) -> PackedVector2Array:
	var key := "side|%d|%s|%s|%s|%.2f" % [si, tool.get("ch", ""), side, xy.snapped(Vector2(0.1, 0.1)), press]
	if _touch_memo.has(key):
		return _touch_memo[key]
	var held := _cleared(si, xy, tool, side)
	_side_held["%d|%s|%s|%s" % [si, tool.get("ch", ""), side, xy]] = held
	var got := _touched(si, tool, _skin_hold(si, xy, 0.0, press, 0.0, tool, side, held, held, 0.0))
	_touch_memo[key] = got
	return got


## The surface's own color, as its first mesh is drawn (the bare face the paint goes on).
func _bare_of(sd: Dictionary) -> Color:
	for m in sd.get("meshes", []):
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
		if mat != null and mat.get_shader_parameter("color") is Color:
			return mat.get_shader_parameter("color")
	return Color("#c89e80")


## A HAND GOES BACK OVER WHAT IT MISSED (feedback 0035: "There are still huge gaps in the face paint ... Do we need some kind of detection
## mechanism, such that the dabs are not just pre-planned actions, but actually made in response to the gaps in coverage? Like a
## self-correcting mechanism, which slowly fixes errors until there are none left."): each element a tool presses on, its presses planned
## ([method Skins.press_places]), held as they will be drawn ([method _held_keys]), and WHAT THEY TOUCHED LOOKED AT ([method _gaps_left]) -
## every gap of what it covers that no press touched, [constant GAP_LEAST] or more, given a press of its own right after the press nearest
## it (the hand puts it right while it is there, never at the end), and looked at again, up to [constant GAP_ROUNDS] times; a gap a press
## did not reach is pressed [constant PRESS_HARD] as hard. A corner held off the nose so its body clears it, a sponge stood off the
## cradle's board at the rim, had left them bare, and nothing ever looked.
func _cover_gaps() -> void:
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or int(t.get("_skin", -1)) < 0 or not t.has("_ch"):
				continue
			var si := int(t["_skin"])
			var tool := tool_of(String(t["_ch"]), t)
			if not tool.has("touch"):
				continue
			var sd: Dictionary = skins[si]
			for id in t["paint"]:
				var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
				if lay.is_empty() or lay.get("act") != (a as Dictionary)["name"]:
					continue
				# (...laid from the picture, it is what was laid: nothing to go back for - [method _from_picture])
				var laid_it: Dictionary = (sd.get("items", {}) as Dictionary).get(String(id).to_lower(), {})
				if not laid_it.is_empty() and bool((laid_it["made"] as Dictionary).get("laid", false)):
					continue
				if String(tool["kind"]) == "brush" and String(lay["manner"]) in ["line", "sweep"]:
					_brush_gaps(si, t, tool, String(id), lay)
					continue
				if not String(lay["manner"]) in TOUCHED:
					continue
				# (...but a powder: a finish nearly the color it is pressed over - gone back over for every point a puff's pats had missed, it held
				# 257002's show two and a half minutes, told its readers half a minute, for what no one sees)
				if String(element(si, String(id)).get("finish", "")) == "powder":
					continue
				var item: Dictionary = (sd.get("items", {}) as Dictionary).get(String(id).to_lower(), {})
				if item.is_empty():
					continue
				var made: Dictionary = item["made"]
				_as_planned(made)
				var ed := element(si, String(id))
				var manner := String(lay["manner"])
				var mm := float(lay["mm"])
				var rect: Rect2 = made["rect"]
				var contact := _contact_for(tool, manner)
				var cov := Skins.cover(ed, rect, Skins.WHEN_PX, String(sd.get("outline", "")), sd["frame"])
				if cov == null:
					continue
				var inside := covered_in(cov)
				var last_look := {}
				var places: Array = Skins.press_places(manner, mm, cov, rect)
				var named := String((made["program"] as Dictionary)["id"])
				# (what was left bare at each look, square millimeters - for a probe to say)
				var bare_at := PackedFloat32Array()
				for round in GAP_ROUNDS + 1:
					var prog: Dictionary = made["program"]
					var key := _held_key(prog, String(t["_ch"]), contact)
					var held: Dictionary = sd.get("held", {})
					if not held.has(key):
						held[key] = _held_keys(si, prog, tool, contact)
						sd["held"] = held
					var left := _gaps_left(si, prog, t, tool, cov, rect, mm, inside)
					made["touches"] = left["touches"]
					last_look = left
					var gaps: Array = left["at"]
					var aside: Array = left["aside"]
					bare_at.append(float(left["bare"]))
					made["gaps"] = bare_at
					if gaps.is_empty() or round == GAP_ROUNDS:
						break
					# ...each put in after the press nearest it, the latest first so the places before stay where they are
					var at: Array = []
					for g in gaps:
						var gv: Vector2 = (g as Array)[0]
						var best := 0
						for i in places.size():
							if Vector2((places[i] as Vector3).x, (places[i] as Vector3).y).distance_squared_to(gv) \
									< Vector2((places[best] as Vector3).x, (places[best] as Vector3).y).distance_squared_to(gv):
								best = i
						# ...PUT RIGHT AS SOON AS IT IS SEEN (the user: "They would fix the gaps soon after they first see them"): right after the
						# press that last laid paint round it - put in after the press it is nearest, it had waited a minute for the hand to come
						# round to that one
						var seen := int((g as Array)[1])
						# ...AIMED SO WHAT IT TOUCHES LANDS ON IT: a corner touches to one side of where it is aimed, the way it leans, and a press
						# aimed at a gap's middle had touched beside it - aimed off by as much as the press nearest it touched off its own place
						var off: Vector2 = aside[best] if best < aside.size() else Vector2.ZERO
						at.append([seen if seen >= 0 else best, Vector3(gv.x - off.x, gv.y - off.y, 1.0 if round == 0 else PRESS_HARD)])
					at.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
					for ins in at:
						places.insert(int(ins[0]) + 1, ins[1])
					var again := Skins.pressed(ed, manner, mm, places)
					again["id"] = "%s|again %d" % [named, round + 1]
					made["program"] = again
				# ...AND WHAT NO PRESS REACHED, PAINTED ALL THE SAME by the press nearest it ([method _painted_anyway])
				made["touches"] = _painted_anyway(made.get("touches", []), last_look.get("islands", []), last_look.get("firsts", []))


## A BRUSH GOES BACK OVER WHAT IT MISSED ([method _cover_gaps], as a sponge does): element [param id] of skin [param si] laid by track
## [param tr]'s brush [param tool] ([param lay]), its strokes looked at as they will be drawn ([method _stroke_touches]), and every gap of what
## it covers no hair touched given a dab of the brush right after the planned stroke that last laid paint round it ([method Skins.program]'s
## `inserts`), looked at again, up to [constant GAP_ROUNDS] times - a liner pressed lightly drew a band narrower than its line, a fill's rows
## missed its corners, and nothing looked.
func _brush_gaps(si: int, tr: Dictionary, tool: Dictionary, id: String, lay: Dictionary) -> void:
	var sd: Dictionary = skins[si]
	var item: Dictionary = (sd.get("items", {}) as Dictionary).get(id.to_lower(), {})
	if item.is_empty():
		return
	var made: Dictionary = item["made"]
	_as_planned(made)
	var ed := element(si, id)
	var manner := String(lay["manner"])
	# ...A LINE IS NEVER PUT RIGHT AFTER: laid as the band its hairs sweep, it leaves no gaps to go back for ([method Skins.band_map]; feedback
	# 0060: "The brush is fixing jagged edges in this line by tapping at each jagged place, quickly. That's too precise, and to inefficient")
	if manner == "line":
		return
	var mm := float(lay["mm"])
	var rect: Rect2 = made["rect"]
	var contact := _contact_for(tool, manner)
	var cov1 := Skins.cover(ed, rect, Skins.WHEN_PX, String(sd.get("outline", "")), sd["frame"])
	var cov := Skins.cover(ed, rect, BRUSH_PX, String(sd.get("outline", "")), sd["frame"])
	if cov == null or cov1 == null:
		return
	var inside := covered_in(cov)
	var named := String((made["program"] as Dictionary)["id"])
	var inserts := {}
	var bare_at := PackedFloat32Array()
	var last_look := {}
	# ...A FILL'S STROKES KEPT INSIDE IT FIRST, and every dab put in after that would run past a fill or a line left out ([method
	# _keep_inside]): laid where they touch, dabs along a line's bare edge had stood out of it as blobs (feedback 0043: "rough edges")
	var allowed := _allowed(si, ed, rect) if manner in ["sweep", "line"] else PackedByteArray()
	var as_planned: Dictionary = made["program"]
	var ways: Variant = _keep_inside(si, tr, tool, made, ed, manner, mm, cov1, contact, allowed) if manner == "sweep" else null
	# ...BUT A FILL TOO FINE FOR ITS BRUSH, nothing of it left that keeps inside even eased off (520084's five small stars, 7 mm across,
	# under the round brush): laid as it was planned, its paint cut to its shape as it had always been ([method _touch_all]) - a hand
	# would take a finer brush, or pull each point out with the tip, and neither is built
	if ways is Array and (ways as Array).is_empty():
		made["program"] = as_planned
		made["too_fine"] = true
		ways = null
		allowed = PackedByteArray()
	for round in GAP_ROUNDS + 1:
		var prog: Dictionary = made["program"]
		var key := _held_key(prog, String(tr["_ch"]), contact)
		var held: Dictionary = sd.get("held", {})
		if not held.has(key):
			held[key] = _held_keys(si, prog, tool, contact)
			sd["held"] = held
		var touches := _stroke_touches(si, prog, tr, tool, manner)
		made["touches"] = touches
		var left := _gaps_in(touches, cov, rect, BRUSH_PX, mm, float(tool["len"]) * 1000.0, inside)
		last_look = left
		bare_at.append(float(left["bare"]))
		made["gaps"] = bare_at
		var gaps: Array = left["at"]
		# (...and no further once a look at what it pressed hard puts little more right: what is left is out of its reach - the first
		# dabs are laid as lightly as the strokes, and a forehead's star they hardly touched was covered by the hard ones after)
		if gaps.is_empty() or round == GAP_ROUNDS or (round > 1 and bare_at[round] > bare_at[round - 1] * 0.9):
			break
		var origin: PackedInt32Array = prog.get("origin", PackedInt32Array())
		var press := 1.0 if round == 0 else PRESS_HARD
		for g in gaps:
			var seen := int((g as Array)[1])
			var planned_k := origin[seen] if seen >= 0 and seen < origin.size() else (origin[origin.size() - 1] if not origin.is_empty() else 0)
			if not inserts.has(planned_k):
				inserts[planned_k] = []
			var gv: Vector2 = (g as Array)[0]
			# ...AIMED WHERE A DAB TOUCHES IT, looked at before it is laid: at it, or off by as much as the hairs aimed nearest it touched off
			# their aim ([method _gaps_in]) - a fill brush held low under a lip's bulge touched the bulge, and a dab aimed at what it missed
			# touched where it had; aimed off where it touched all round its aim, it missed a forehead's stars
			var off: Vector2 = (g as Array)[2]
			var aim := gv
			if off.length_squared() > 1e-6 and _dab_miss(si, tool, contact, gv, press, gv) > _dab_miss(si, tool, contact, gv - off, press, gv):
				aim = gv - off
			if not allowed.is_empty() and _spills(_dab_touch(si, tool, contact, aim, press), rect, allowed) >= SPILL_LEAST:
				continue
			(inserts[planned_k] as Array).append(Vector3(aim.x, aim.y, press))
		var again := Skins.program(ed, manner, mm, cov1, rect, inserts, ways, (skins[si] as Dictionary)["frame"])
		again["id"] = "%s|again %d" % [named, round + 1]
		made["program"] = again
	# ...AND WHAT NO HAIR REACHED, PAINTED ALL THE SAME by the moment nearest it ([method _painted_anyway])
	made["touches"] = _painted_anyway(made.get("touches", []), last_look.get("islands", []))


## AN ELEMENT'S MAKING [param made] ([method _made_for], kept between builds) BACK AS IT WAS PLANNED, before a hand goes back over what it
## missed ([method _cover_gaps], [method _brush_gaps]): what the last build put in, and what it found, left out. Built again (its acts
## reworked), a stipple had started from the presses the last build put in - 36 - against the 16 places it plans afresh, and put its
## new ones in past the end of them; and each rework would have put in more over the last.
static func _as_planned(made: Dictionary) -> void:
	if made.has("planned"):
		made["program"] = made["planned"]
	for k in ["touches", "gaps", "spill", "too_fine"]:
		made.erase(k)


## WHAT NO TOOL REACHED, PAINTED ALL THE SAME (the user, 2026-11-07, of a chin's underside the sponge could not touch: "One way or another,
## we have to cover that chin area. If more pressure can do it, great. If not - just dab in that area, and paint it anyway"): [param touches]
## ([method _stroke_touches]'s, each with its `aim`) with every point of [param islands] - what the last look found bare - laid as the touch
## aimed nearest IT is laid: when the press or stroke put in for it, or the nearest, comes down there (a gap given the moment of the touch
## nearest its middle would come in all at once). Each such touch says `anyway`.
## AND WHAT ONE PRESS ALONE REACHED, MADE WHOLE ALL THE SAME (feedback 0001, 2026-11-07: "there is a tiny spot just under the nose that is
## slightly more transparent than the rest of the white"; "a small piece to the left of the nose as well"): given [param firsts] (each
## island point's first touch, its `st`; -1 none), a point a touch has reached is laid again by the touch aimed nearest it of those after
## that one - the press put in for it, which touched beside it. Laid by the nearest whatever its moment, it was laid by its own press
## again, and stayed a single press's thin film to the act's end: 257002's spot under the nose and its piece beside the left nostril.
static func _painted_anyway(touches: Array, islands: Array, firsts: Array = []) -> Array:
	if islands.is_empty() or touches.is_empty():
		return touches
	var aims := PackedVector2Array()
	var sts := PackedInt32Array()
	var of: Array = []
	for tc in touches:
		if (tc as Dictionary).has("aim"):
			aims.append((tc as Dictionary)["aim"])
			sts.append(int((tc as Dictionary).get("st", 0)))
			of.append(tc)
	if aims.is_empty():
		return touches
	var given := {}
	for ii in islands.size():
		var isl: PackedVector2Array = islands[ii]
		var by: PackedInt32Array = firsts[ii] if ii < firsts.size() else PackedInt32Array()
		for qi in isl.size():
			var q := isl[qi]
			var after := by[qi] if qi < by.size() else -1
			var best := -1
			var bd := INF
			for i in aims.size():
				if after >= 0 and sts[i] <= after:
					continue
				var dd := aims[i].distance_squared_to(q)
				if dd < bd:
					bd = dd
					best = i
			# (...none after it - its press the last there is - laid by the nearest)
			if best < 0:
				for i in aims.size():
					var dd := aims[i].distance_squared_to(q)
					if dd < bd:
						bd = dd
						best = i
			# (a packed array read out of a dictionary is a copy: added to, it is put back)
			var got: PackedVector2Array = given.get(best, PackedVector2Array())
			got.append(q)
			given[best] = got
	var out := touches.duplicate()
	for i in given:
		var d: Dictionary = of[i]
		out.append({"u": d["u"], "load": d.get("load", 1.0), "pts": given[i], "st": d.get("st", 0), "aim": d["aim"], "anyway": true})
	return out


## Which points of picture [param cov] are covered (one a point, row by row; its alpha over a half), read at once.
static func covered_in(cov: Image) -> PackedByteArray:
	var img := cov
	if img.get_format() != Image.FORMAT_RGBA8:
		img = cov.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var out := PackedByteArray()
	out.resize(img.get_width() * img.get_height())
	for k in out.size():
		out[k] = 1 if data[k * 4 + 3] > 127 else 0
	return out


## How far from (x, y) millimeters [param at] the nearest of what brush [param tool] held [param contact] touches dabbed at [param xy], pressed
## [param press], on skin [param si] (millimeters; INF where it touches nothing) - its hairs bent as [method _stroke_touches] bends them at a
## dab's bottom, standing still.
func _dab_miss(si: int, tool: Dictionary, contact: String, xy: Vector2, press: float, at: Vector2) -> float:
	var near := INF
	for q in _dab_touch(si, tool, contact, xy, press):
		near = minf(near, q.distance_to(at))
	return near


## What a brush dabbed at [param xy] millimeters of skin [param si], pressed [param press], touches there ([method _touched]).
func _dab_touch(si: int, tool: Dictionary, contact: String, xy: Vector2, press: float) -> PackedVector2Array:
	var cl := _cleared(si, xy, tool, contact)
	var h := _skin_hold(si, xy, 0.0, press, 0.0, tool, contact, cl, cl, 0.0)
	var axis: Vector3 = (h[1] as Vector3).normalized()
	var n: Vector3 = h[7]
	var tg := Bristles.target(Vector3.ZERO, press, float(tool["len"]), axis, -(axis - n * axis.dot(n)), float(tool.get("bends", 1.0)))
	var bend: Vector3 = _node_at(h, tool, tool["x0"]).basis.inverse() * _bend_to_surface(si, tool, h, tg[0] as Vector3)
	return _touched(si, tool, h, bend, float(tg[1]))


## A BRUSH KEEPS INSIDE WHAT IT FILLS ([constant Skins.CUT_IN]; feedback 0042, 0043): element [param ed]'s sweep looked at as it will be
## drawn ([method _stroke_touches]) and each of its ways EASED OFF where its hairs touch the face past its shape by more than [constant
## SPILL_MOST] millimeters at [constant SPILL_LEAST] points or more - pressed half as hard there, as a hand lightens near an edge, down to
## [constant SPILL_LIGHTEST] - and cut back where it still does so lightly ([method _ease_off]); looked at again, up to [constant
## SPILL_ROUNDS] times. A star's points narrower than the round brush laying it had been cut away whole, and the rows came back as they
## were (520084: 506 mm2 of copper round five small stars). What is left bare is for the looks after to put right ([method _brush_gaps]).
## The ways kept; `made`'s `spill` says how many moments ran past at each look.
func _keep_inside(si: int, tr: Dictionary, tool: Dictionary, made: Dictionary, ed: Dictionary, manner: String, mm: float, cov1: Image,
		contact: String, allowed: PackedByteArray) -> Variant:
	var sd: Dictionary = skins[si]
	var rect: Rect2 = made["rect"]
	var named := String((made["program"] as Dictionary)["id"])
	var ways: Array = (made["program"] as Dictionary).get("ways", [])
	var spilt := PackedInt32Array()
	if ways.is_empty() or allowed.is_empty():
		return null
	for round in SPILL_ROUNDS + 1:
		var prog: Dictionary = made["program"]
		var key := _held_key(prog, String(tr["_ch"]), contact)
		var held: Dictionary = sd.get("held", {})
		if not held.has(key):
			held[key] = _held_keys(si, prog, tool, contact)
			sd["held"] = held
		var bad := PackedVector2Array()
		for tc in _stroke_touches(si, prog, tr, tool, manner):
			if (tc as Dictionary).has("aim") and _spills(tc["pts"], rect, allowed) >= SPILL_LEAST:
				bad.append(tc["aim"])
		spilt.append(bad.size())
		made["spill"] = spilt
		if bad.is_empty() or round == SPILL_ROUNDS:
			break
		ways = _ease_off(ways, bad, Skins.ROW_KEYS * 0.5)
		var again := Skins.program(ed, manner, mm, cov1, rect, {}, ways, (skins[si] as Dictionary)["frame"])
		again["id"] = "%s|inside %d" % [named, round + 1]
		made["program"] = again
	return ways


## How many of [param pts] (millimeters of skin) lie outside what [param allowed] holds over [param rect] at [constant BRUSH_PX] pixels a
## millimeter (one a point, row by row) - or past its rect.
static func _spills(pts: PackedVector2Array, rect: Rect2, allowed: PackedByteArray) -> int:
	var w := maxi(int(ceil(rect.size.x * BRUSH_PX)), 1)
	var h := maxi(int(ceil(rect.size.y * BRUSH_PX)), 1)
	var n := 0
	for q in pts:
		var px := Vector2i(((q - rect.position) * BRUSH_PX).floor())
		if px.x < 0 or px.y < 0 or px.x >= w or px.y >= h or allowed[px.y * w + px.x] == 0:
			n += 1
	return n


## [param ways] (`{pts, press}`, millimeters) EASED OFF where they ran past: each point within [param reach] of any of [param bad] pressed
## half as hard, and one already as light as [constant SPILL_LIGHTEST] taken out, the way broken there into what is left - none shorter
## than [constant Skins.CUT_LEAST].
static func _ease_off(ways: Array, bad: PackedVector2Array, reach: float) -> Array:
	var out: Array = []
	for w in ways:
		var pts: PackedVector2Array = (w as Dictionary)["pts"]
		var press: PackedFloat32Array = (w as Dictionary)["press"]
		var cur := PackedVector2Array()
		var cur_p := PackedFloat32Array()
		var runs: Array = []
		for k in pts.size():
			var near := false
			for b in bad:
				if pts[k].distance_squared_to(b) <= reach * reach:
					near = true
					break
			var pr := press[k]
			if near and pr <= SPILL_LIGHTEST + 1e-4:
				if cur.size() >= 2:
					runs.append({"pts": cur, "press": cur_p})
				cur = PackedVector2Array()
				cur_p = PackedFloat32Array()
				continue
			cur.append(pts[k])
			cur_p.append(maxf(pr * 0.5, SPILL_LIGHTEST) if near else pr)
		if cur.size() >= 2:
			runs.append({"pts": cur, "press": cur_p})
		for r in runs:
			# (a fine fill's spine keeps its line's pace - [method Skins._spine])
			if (w as Dictionary).has("speed"):
				(r as Dictionary)["speed"] = (w as Dictionary)["speed"]
			var rp: PackedVector2Array = (r as Dictionary)["pts"]
			var length := 0.0
			for k in range(1, rp.size()):
				length += rp[k - 1].distance_to(rp[k])
			if length >= Skins.CUT_LEAST:
				out.append(r)
	return out


## WHAT A BRUSH MAY TOUCH laying element [param ed] over [param rect] ([constant BRUSH_PX] pixels a millimeter, one a point, row by row):
## its shape and [constant SPILL_MOST] millimeters round it.
func _allowed(si: int, ed: Dictionary, rect: Rect2) -> PackedByteArray:
	var sd: Dictionary = skins[si]
	var cov := Skins.cover(ed, rect, BRUSH_PX, String(sd.get("outline", "")), sd["frame"])
	if cov == null:
		return PackedByteArray()
	var inside := covered_in(cov)
	var w := cov.get_width()
	var h := cov.get_height()
	var rp := SPILL_MOST * BRUSH_PX
	var r := ceili(rp)
	var out := inside.duplicate()
	for y in h:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var qx := x + dx
					var qy := y + dy
					if qx >= 0 and qy >= 0 and qx < w and qy < h and dx * dx + dy * dy <= rp * rp:
						out[qy * w + qx] = 1
	return out


## WHAT NONE OF [param touches] TOUCHED of what [param cov] covers over [param rect] ([param px] pixels a millimeter; each touch's `st` the
## stroke it was laid by, `aim` where it was aimed): each gap apart of at least [constant GAP_LEAST] square millimeters as the places a tool
## touching [param mm] across would dab it, with the stroke that last laid paint round it and how far the hairs aimed nearest it touched
## off their aim where they missed it (the middle of what they touched less their aim, as far as [param reach_mm]; none where they touched
## it) - `{at: [[Vector2(x, y), stroke, Vector2 off]], bare: mm2, islands: [every point of each gap, however small]}` ([method _gaps_left]'s).
func _gaps_in(touches: Array, cov: Image, rect: Rect2, px: float, mm: float, reach_mm := INF, inside := PackedByteArray()) -> Dictionary:
	var aims := PackedVector2Array()
	var offs := PackedVector2Array()
	for tc in touches:
		var got: PackedVector2Array = (tc as Dictionary)["pts"]
		if got.is_empty() or not (tc as Dictionary).has("aim"):
			continue
		var aim: Vector2 = (tc as Dictionary)["aim"]
		var mid_t := Vector2.ZERO
		var on_it := false
		for q in got:
			mid_t += q
			on_it = on_it or q.distance_squared_to(aim) < AIM_MET * AIM_MET
		aims.append(aim)
		offs.append(Vector2.ZERO if on_it else (mid_t / float(got.size()) - aim).limit_length(reach_mm))
	var w := cov.get_width()
	var h := cov.get_height()
	# (what it covers, read once: a point at a time, it was most of the time a look took)
	if inside.size() != w * h:
		inside = covered_in(cov)
	var first := PackedFloat32Array()
	first.resize(w * h)
	first.fill(-1.0)
	var reach := maxf(BRUSH_SPOT * px, 0.75)
	for tc in touches:
		var st := float((tc as Dictionary)["st"])
		for p in (tc as Dictionary)["pts"]:
			var pc := ((p as Vector2) - rect.position) * px
			for y in range(maxi(int(pc.y - reach), 0), mini(int(pc.y + reach) + 1, h)):
				for x in range(maxi(int(pc.x - reach), 0), mini(int(pc.x + reach) + 1, w)):
					if first[y * w + x] < 0.0:
						first[y * w + x] = st
	Skins.closed_in(first, PackedFloat32Array(), w, h, inside)
	var out: Array = []
	var islands: Array = []
	var bare := 0.0
	var seen := PackedByteArray()
	seen.resize(w * h)
	for k in w * h:
		if seen[k] == 1 or first[k] >= 0.0 or inside[k] == 0:
			continue
		var island := PackedInt32Array([k])
		seen[k] = 1
		var head := 0
		var mid := Vector2.ZERO
		var closed := -1
		while head < island.size():
			var c := island[head]
			head += 1
			mid += Vector2(float(c % w), float(c / w))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x: int = c % w + d.x
				var y: int = c / w + d.y
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var nk := y * w + x
				if first[nk] >= 0.0:
					closed = maxi(closed, int(first[nk]))
				elif seen[nk] == 0 and inside[nk] != 0:
					seen[nk] = 1
					island.append(nk)
		var mm2 := float(island.size()) / (px * px)
		var where := PackedVector2Array()
		for c in island:
			where.append(Vector2(rect.position.x + (float(c % w) + 0.5) / px, rect.position.y + (float(c / w) + 0.5) / px))
		islands.append(where)
		if mm2 < GAP_LEAST:
			continue
		bare += mm2
		mid /= float(island.size())
		var best := island[0]
		for c in island:
			if Vector2(float(c % w), float(c / w)).distance_squared_to(mid) < Vector2(float(best % w), float(best / w)).distance_squared_to(mid):
				best = c
		var chosen := PackedInt32Array([best])
		var many := clampi(ceili(mm2 / (PI * mm * mm * 0.25 * 0.6)), 1, 12)
		while chosen.size() < many:
			var far := -1.0
			var pick := -1
			for c in island:
				var near := INF
				for q in chosen:
					near = minf(near, Vector2(float(c % w), float(c / w)).distance_squared_to(Vector2(float(q % w), float(q / w))))
				if near > far:
					far = near
					pick = c
			if pick < 0 or far < 1.0:
				break
			chosen.append(pick)
		for c in chosen:
			var gv := Vector2(rect.position.x + (float(c % w) + 0.5) / px, rect.position.y + (float(c / w) + 0.5) / px)
			var near := -1
			for i in aims.size():
				if near < 0 or aims[i].distance_squared_to(gv) < aims[near].distance_squared_to(gv):
					near = i
			out.append([gv, closed, offs[near] if near >= 0 else Vector2.ZERO])
	return {"at": out, "bare": bare, "islands": islands}


## WHAT NO PRESS OF PROGRAM [param prog] TOUCHED, OR ONE ALONE DID, of what [param cov] covers over [param rect] (track [param tr]'s tool
## [param tool] held at each as it will be drawn, [method _touched]; each point it touched stamped as its reveal map stamps it,
## [constant PRESS_SPOT]): each gap apart of at least [constant GAP_LEAST] square millimeters, as the places a tool touching [param mm]
## across would press it - the point of it nearest its middle, then each the point of it furthest from those, as many as it is large, and
## the press after which a hand would see it (the last to lay paint round it or in it, -1 none) - `{at: [[Vector2(x, y), that press]],
## bare: mm2 of every such gap, aside: [how far off its own place each press touched, the middle of what it touched less where it was aimed
## (millimeters)], touches: what each press touched, as [method _stroke_touches] gives it, islands: [every point of each gap, however small
## (millimeters)]}`.
func _gaps_left(si: int, prog: Dictionary, tr: Dictionary, tool: Dictionary, cov: Image, rect: Rect2, mm: float,
		inside := PackedByteArray()) -> Dictionary:
	var w := cov.get_width()
	var h := cov.get_height()
	if inside.size() != w * h:
		inside = covered_in(cov)
	var hit := PackedByteArray()
	hit.resize(w * h)
	var aside: Array = []
	var first := PackedInt32Array()
	first.resize(w * h)
	first.fill(-1)
	# (how many presses reached each point, two at most)
	var times_hit := PackedByteArray()
	times_hit.resize(w * h)
	var last_hit := PackedInt32Array()
	last_hit.resize(w * h)
	last_hit.fill(-1)
	var si_k := -1
	# (a press found before - the same place, as hard, held the same way - is what it touched before: only a press put in is looked at anew)
	var contact := _contact_for(tool, String(prog.get("manner", "")))
	var kept: Dictionary = ((skins[si] as Dictionary).get("held", {}) as Dictionary).get(_held_key(prog, String(tr.get("_ch", "")), contact), {})
	var kh: PackedVector4Array = kept.get("held", PackedVector4Array())
	var kw: PackedByteArray = kept.get("ways", PackedByteArray())
	var keys: Array = prog["keys"]
	var key_at := {}
	for k in keys.size():
		key_at[snappedf(float((keys[k] as Array)[0]), 0.0001)] = k
	var natural := maxf(float(prog["natural"]), 1e-3)
	var touches: Array = []
	for st in prog["strokes"]:
		si_k += 1
		var ts: PackedFloat32Array = (st as Dictionary)["t"]
		var ld: PackedFloat32Array = (st as Dictionary).get("load", PackedFloat32Array())
		var aim: Vector2 = ((st as Dictionary)["pts"] as PackedVector2Array)[0]
		var kk := int(key_at.get(snappedf(ts[0], 0.0001), -1))
		var gk := ""
		if kk >= 0 and kk < kh.size():
			gk = "%d|%s|%s|%s|%d|%s" % [si, aim, (keys[kk] as Array)[4], kh[kk], kw[kk] if kk < kw.size() else 0, tr.get("_ch", "")]
		var got: PackedVector2Array
		if not gk.is_empty() and _touch_memo.has(gk):
			got = _touch_memo[gk]
		else:
			got = _touched(si, tool, _hold_of(_surface_hold(si, prog, ts[0], 0.0, tr), tool))
			if not gk.is_empty():
				_touch_memo[gk] = got
		touches.append({"u": ts[0] / natural, "load": ld[0] if not ld.is_empty() else 1.0, "pts": got, "st": si_k, "aim": aim})
		var mid_t := Vector2.ZERO
		for p in got:
			mid_t += p
		aside.append(mid_t / float(got.size()) - aim if not got.is_empty() else Vector2.ZERO)
		# ...EACH POINT IT TOUCHED STAMPED AS ITS REVEAL MAP STAMPS IT, a point of the map as touched only where its middle lies within
		# [constant PRESS_SPOT] ([method Skins.touch_map]): read as every point from a spot's lowest to its highest, the look had stamped up
		# to nine where the map laid one to four, and counted two presses on a point the map showed one alone had reached
		for p in got:
			var pc := (p - rect.position) * Skins.WHEN_PX
			for y in range(maxi(int(pc.y - PRESS_SPOT), 0), mini(int(pc.y + PRESS_SPOT) + 1, h)):
				for x in range(maxi(int(pc.x - PRESS_SPOT), 0), mini(int(pc.x + PRESS_SPOT) + 1, w)):
					if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(pc) > PRESS_SPOT:
						continue
					hit[y * w + x] = 1
					if first[y * w + x] < 0:
						first[y * w + x] = si_k
					if last_hit[y * w + x] != si_k:
						last_hit[y * w + x] = si_k
						times_hit[y * w + x] = mini(int(times_hit[y * w + x]) + 1, 2)
	# ...as it will show: what presses spread into, closed in where it is all but surrounded ([method Skins.closed_in])
	var times := PackedFloat32Array()
	times.resize(w * h)
	for k in w * h:
		times[k] = float(first[k]) if hit[k] == 1 else -1.0
	Skins.closed_in(times, PackedFloat32Array(), w, h, inside)
	for k in w * h:
		if hit[k] == 0 and times[k] >= 0.0:
			hit[k] = 1
			first[k] = int(times[k])
	# ...AND WHAT IS THIN WANTS FILLING TOO, put right while the hand is there (the user, 2026-11-07: "Why can't the heuristic just correct
	# specks as they appear, localized ... If an area of makeup is thin, they would fill it out before moving on to new areas"; feedback
	# 0001, 2026-11-07: "missing specks of makeup all over this face ... it's completely ignoring the ugly missing specks right at the center
	# of the face"): A POINT ONE PRESS ALONE REACHED IS THIN, however loaded the tool was. One dab leaves a film, uneven and only most of its
	# paint (skin_paint.gdshader's `FIRST`, `UNEVEN`), and only a second press fills it (`again`): at a stipple's end every point short of
	# whole is one a single press reached. Called thin only where the tool had run all but dry, 257002's base kept specks of 1-3 mm in its
	# white, thickest round the nose, to its act's end; called thin as one press alone, none is left under 60% shown and 11 mm2 of it one
	# press alone reached - for 863 presses where it had 568. A point the map closes round is laid whole ([method Skins.touch_map]), and is
	# not thin.
	for k in w * h:
		if hit[k] == 1 and times_hit[k] == 1:
			hit[k] = 0
	var out: Array = []
	var islands: Array = []
	var firsts: Array = []
	var bare := 0.0
	var seen := PackedByteArray()
	seen.resize(w * h)
	for k in w * h:
		if seen[k] == 1 or hit[k] == 1 or inside[k] == 0:
			continue
		var island := PackedInt32Array([k])
		seen[k] = 1
		var head := 0
		var mid := Vector2.ZERO
		var closed := -1
		while head < island.size():
			var c := island[head]
			head += 1
			mid += Vector2(float(c % w), float(c / w))
			# (...a thin point is seen once its own press has laid it, too)
			closed = maxi(closed, first[c])
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x: int = c % w + d.x
				var y: int = c / w + d.y
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var nk := y * w + x
				if hit[nk] == 1:
					# (the press that last laid paint round it: when it was there to be seen)
					closed = maxi(closed, first[nk])
				elif seen[nk] == 0 and inside[nk] != 0:
					seen[nk] = 1
					island.append(nk)
		var mm2 := float(island.size()) / (Skins.WHEN_PX * Skins.WHEN_PX)
		var where := PackedVector2Array()
		var by := PackedInt32Array()
		for c in island:
			where.append(Vector2(rect.position.x + (float(c % w) + 0.5) / Skins.WHEN_PX, rect.position.y + (float(c / w) + 0.5) / Skins.WHEN_PX))
			by.append(first[c])
		islands.append(where)
		firsts.append(by)
		if mm2 < GAP_LEAST:
			continue
		bare += mm2
		mid /= float(island.size())
		var best := island[0]
		for c in island:
			if Vector2(float(c % w), float(c / w)).distance_squared_to(mid) < Vector2(float(best % w), float(best / w)).distance_squared_to(mid):
				best = c
		var chosen := PackedInt32Array([best])
		var many := clampi(ceili(mm2 / (PI * mm * mm * 0.25 * 0.6)), 1, 16)
		while chosen.size() < many:
			var far := -1.0
			var pick := -1
			for c in island:
				var near := INF
				for q in chosen:
					near = minf(near, Vector2(float(c % w), float(c / w)).distance_squared_to(Vector2(float(q % w), float(q / w))))
				if near > far:
					far = near
					pick = c
			if pick < 0 or far < 1.0:
				break
			chosen.append(pick)
		for c in chosen:
			out.append([Vector2(rect.position.x + (float(c % w) + 0.5) / Skins.WHEN_PX, rect.position.y + (float(c / w) + 0.5) / Skins.WHEN_PX), closed])
	return {"at": out, "bare": bare, "aside": aside, "touches": touches, "islands": islands, "firsts": firsts}


## WHAT A PRESSING TOOL TOUCHES IS WHAT IT PAINTS (feedback 0032): each element a sponge stipples or a puff pats shown only where the
## tool, held as it is drawn at each press ([method _surface_hold]), touches the face ([method _touched], [method Skins.touch_map]) -
## its reveal map from its program alone had shown every point the nearest press's, so a corner's touch showed a whole patch round it.
func _touch_all() -> void:
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or int(t.get("_skin", -1)) < 0 or not t.has("_ch"):
				continue
			var si := int(t["_skin"])
			var tool := tool_of(String(t["_ch"]), t)
			if not tool.has("touch"):
				continue
			var brush := String(tool["kind"]) == "brush"
			for id in t["paint"]:
				var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
				if lay.is_empty() or lay.get("act") != (a as Dictionary)["name"]:
					continue
				if not (String(lay["manner"]) in TOUCHED or (brush and String(lay["manner"]) in BRUSH_TOUCHED)):
					continue
				var item: Dictionary = ((skins[si] as Dictionary).get("items", {}) as Dictionary).get(String(id).to_lower(), {})
				if item.is_empty():
					continue
				var made: Dictionary = item["made"]
				if bool(made.get("laid", false)):
					continue
				var prog: Dictionary = made["program"]
				var natural := maxf(float(prog["natural"]), 1e-3)
				# (a brush's last look at what it missed has them already, for this program - [method _brush_gaps])
				var touches: Array = made["touches"] if made.has("touches") else _stroke_touches(si, prog, t, tool, String(lay["manner"]))
				var wm: Image
				var foot: Array = []
				if brush and String(lay["manner"]) == "line":
					# ...A LINE THE BAND ITS HAIRS SWEEP, smooth, its tail thinning ([method Skins.band_map]; "a proper brush stroke is more often
					# than not very smooth, with clean edges")
					wm = Skins.band_map(prog, made["rect"], BRUSH_PX, foot)
				elif brush:
					# ...A BRUSH LAYS ITS PAINT WHERE ITS HAIRS TOUCHED, its element's shape or not (feedback 0042) - the shape is what its
					# strokes keep to ([method _keep_inside]), never what cuts its paint off; a fill too fine for its brush cut to it still
					wm = Skins.touch_map(touches, made["rect"], BRUSH_PX, BRUSH_SPOT, PackedByteArray(), 0.0, null if bool(made.get("too_fine", false)) else foot)
				else:
					# ...a press's, its edge's moment carried past the element's edge as far as its ragged edge reads ([method Skins.touch_map])
					var cov := Skins.cover(element(si, String(id)), made["rect"], Skins.WHEN_PX, String((skins[si] as Dictionary).get("outline", "")), (skins[si] as Dictionary)["frame"])
					wm = Skins.touch_map(touches, made["rect"], Skins.WHEN_PX, PRESS_SPOT / Skins.WHEN_PX, covered_in(cov) if cov != null else PackedByteArray(),
						Skins.PRESS_RAGGED)
				made["when"] = wm
				made["when_tex"] = ImageTexture.create_from_image(wm)
				if not foot.is_empty():
					made["foot"] = foot[0]
					made["foot_tex"] = ImageTexture.create_from_image(foot[0])
				for m in item["mats"]:
					(m as ShaderMaterial).set_shader_parameter("when_map", made["when_tex"])
					if not foot.is_empty():
						(m as ShaderMaterial).set_shader_parameter("foot", made["foot_tex"])
						(m as ShaderMaterial).set_shader_parameter("footed", true)


## WHERE A BLENDING BRUSH GOES OVER WHAT WAS LAID, AND THERE ALONE, IT IS SOFTENED (feedback 0046, of lips gone over with the blending
## brush: "now the lips are fainter at the top, while smearing outside the lines at the bottom" - every edge of an element blended had
## softened at once, wherever the brush went): each element a brush's act goes over and another lays, its blend held as it is drawn
## ([method plan_of]'s blend, [method _stroke_touches]) and what its hairs touched mapped by when ([method Skins.touch_map]) over the
## element's own picture - skin_paint.gdshader's `blend_map`.
func _blend_touches() -> void:
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or int(t.get("_skin", -1)) < 0 or not t.has("_ch"):
				continue
			var si := int(t["_skin"])
			var tool := tool_of(String(t["_ch"]), t)
			if String(tool.get("kind", "")) != "brush":
				continue
			for id in t["paint"]:
				var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
				var item: Dictionary = ((skins[si] as Dictionary).get("items", {}) as Dictionary).get(String(id).to_lower(), {})
				var ed := element(si, String(id))
				if lay.is_empty() or item.is_empty() or String(ed.get("finish", "")) == "powder" \
						or (lay.get("act") == (a as Dictionary)["name"] and not bool(lay.get("soft_over", false))):
					continue
				var manner := Skins.blend_manner(String(tool["kind"]))
				var prog: Dictionary = _made_for(si, ed, manner, _width(tool, t, manner))["program"]
				var made: Dictionary = item["made"]
				var bm := Skins.touch_map(_stroke_touches(si, prog, t, tool, manner), made["rect"], BRUSH_PX, BRUSH_SPOT)
				made["blend_when"] = bm
				made["blend_tex"] = ImageTexture.create_from_image(bm)
				for m in item["mats"]:
					(m as ShaderMaterial).set_shader_parameter("blend_map", made["blend_tex"])
					(m as ShaderMaterial).set_shader_parameter("blend_touched", true)


## A BRUSH'S HAIRS BENT [param bend] (the table's space, [method Bristles.target]) HELD [param h] ON SKIN [param si], made to keep their tip ON
## THE FACE: what of the bend goes toward the face or away from it, across the hairs, is as much as brings the tip back to it from where
## the hold put it - pushed in, they bow just so far (a liner pressed lightly hardly at all, a brush laying a fill well over) - and what
## goes along the face, a drag aside, is kept (feedback 0029-0031: a fold of a fifth of their length, tilted with the brush, had carried a
## liner's tip 2.5 mm up off the face it was meant to be touching, and it painted nothing). NEVER TOWARD THE FACE (feedback 0019, 2026-11-09:
## "why are the bristles curved, when the brush is lifted? ... a lot of the brushes will curve in the WRONG direction when applying paint:
## they will curve downward, into the mask, rather than away, repulsed by the mask's collision"): what touches only pushes hairs away, so
## a tip standing off the face stays straight - 732687's round brush, lifted 4.3 mm, had curled its hairs 4.8 mm down toward the mask in
## every lifted frame, the search's answer jumping 2 to 8 mm between frames. How far
## over the face the tip is, is read off the face's heights as the skin's own part stands - along ITS depth - so the bend that takes it
## there is found with the tip where the arc puts it - the least bend either way that brings it onto the face, looked for in growing
## steps and then halved ([constant TIP_STEP]). Counted along the face's normal, a forehead sloping back from the mask's depth saw a tip
## 4.7 mm deep where it was under 2 mm, and the bend lifted it clear - a fill brush laid its halo and brows and touched nothing; stepped
## to by its slope alone, a liner's tip on the steep underside of a lower lip went over the edge and was bent back 8 mm, onto the lip.
func _bend_to_surface(si: int, tool: Dictionary, h: Array, bend: Vector3) -> Vector3:
	if h.size() < 8 or (h[7] as Vector3).length_squared() < 0.5 or not tool.has("hair_root"):
		return bend
	var axis: Vector3 = (h[1] as Vector3).normalized()
	var n: Vector3 = (h[7] as Vector3).normalized()
	var m := n - axis * axis.dot(n)
	if m.length() < 0.05:
		return bend
	m = m.normalized()
	var g := _obstacles(skins[si])
	var to_part: Transform3D = g["to_part"] * _node_at(h, tool, tool["x0"])
	var to_node := _node_at(h, tool, tool["x0"]).basis.inverse()
	# (...a stiff tip - a cotton swab's bud - as little as its hairs bend: [constant Bristles.KINDS]' `bends`)
	var most := float(tool.get("len", 0.01)) * 0.6 * float(tool.get("bends", 1.0))
	var kept := bend - m * bend.dot(m)
	# how far over the face the tip is, bent toward m this far (meters; NAN off the face)
	var over := func(t: float) -> float:
		var tip := to_part * _bent_tip(tool, to_node * (kept + m * t))
		var face := _front_z(g, tip)
		return NAN if face == -INF else tip.z - face
	var o0: float = over.call(0.0)
	if is_nan(o0):
		return bend
	# ...STANDING OFF IT, NOT BENT TOWARD IT: only the drag aside is kept
	if o0 >= 0.0:
		return kept
	# ...no further than TIP_REACH times what would bring it there over a flat face (the part's depth it goes for each meter of bend): a
	# brush held near upright, pressed into the crease between two lips, slid its tip 4 mm up the lower one to find the face - its hairs
	# spread, and its tip stays
	var mp := (g["to_part"] as Transform3D).basis * m
	most = minf(most, TIP_REACH * absf(o0) / maxf(mp.z, 0.2 * mp.length()))
	# ...away from the face where it is in it: the first step past the face, then halved - and none past it within reach, the bend of
	# those that came nearest (pressed into the crease between two lips, bent away it only climbed a lip's side, and bent as far as it
	# bends it painted a lip and not the crease)
	var way := 1.0
	var lo := 0.0
	var hi := NAN
	var nearest := 0.0
	var near_o := absf(o0)
	var step := TIP_STEP
	while step <= most * 2.0:
		var t := minf(step, most)
		var o: float = over.call(way * t)
		if is_nan(o):
			break
		if (o >= 0.0) == (o0 < 0.0):
			hi = t
			break
		if absf(o) < near_o:
			nearest = t
			near_o = absf(o)
		lo = t
		if t >= most:
			break
		step *= 2.0
	if is_nan(hi):
		return kept + m * way * nearest
	for _halve in TIP_HALVES:
		var mid := (lo + hi) * 0.5
		var o: float = over.call(way * mid)
		if not is_nan(o) and (o >= 0.0) == (o0 < 0.0):
			hi = mid
		else:
			lo = mid
	return kept + m * way * hi


## A BRUSH'S HAIRS HELD [param h] ON A LEVEL SURFACE - its paint in a pot, the water cup's floor, the towel - whose height is the hold's
## `h[6]` and whose normal its `h[7]` ([method _laid_hold], [method _trip]): LAID ON IT as far as their root is pushed down to it
## ([method Bristles.laid]) - reaching it, bent away across the hairs until the tip is on it, never toward it; lower, a share of them
## lying along it on their side (feedback 0002) - bowed away from the handle's lean. Out of its reach, bent [param bend] (the table's
## space) as they were. Returns `[bend (the table's space), lay (prop_common's `bristle_lay`: the share lying along it, the arc's
## angle)]`. Bent no further than brings the tip onto it, as an arc whose tip still pointed into the surface (feedback 0017), 1 mm of
## a brush's point had touched its paint. LAID AS IT IS DRAWN, where [param drawn] says (its node in the table's space, as the solver
## carries it), else as the hold has it: a liner squeezed on a water cup's floor was stopped by the table under the cup's 4 mm floor
## 9.6 mm short of its hand, and its hairs, laid as its hand had it, curled in the water over the floor (2026-11-10, the user: "the
## bristles bend - even though the brush isn't touching the bottom of the glass").
func _lay_on_plane(tool: Dictionary, h: Array, bend: Vector3, drawn: Variant = null, goes := Vector3.ZERO) -> Array:
	if h.size() < 8 or (h[7] as Vector3).length_squared() < 0.5 or not tool.has("hair_root") or is_nan(float(h[6])):
		return [bend, Vector2.ZERO]
	var x: Transform3D = drawn if drawn is Transform3D else _node_at(h, tool, tool["x0"])
	var n: Vector3 = (h[7] as Vector3).normalized()
	var d := (x.basis * (tool["hair_axis"] as Vector3)).normalized()
	var root := x * (tool["hair_root"] as Vector3)
	var hl := float(tool["len"])
	# (away from the handle's lean along the surface, the way its hairs lean - held straight down onto it, the way its node's own x goes)
	var m := d - n * d.dot(n)
	if m.length() < 0.05:
		m = x.basis.x - n * x.basis.x.dot(n)
	m = m.normalized()
	# ...AND BEHIND THE WAY IT GOES along it, [param goes] (m/s; the user, 2026-11-10: "the brush moves in small circles in those
	# containers... yet the bristles only bend in a single direction ... the bristles should be adjusting to point in the opposite direction
	# we're pulling the brush"): swirled round a pot or the cup's floor they trail round after it, leaning against the way they lie half the
	# time ([method Bristles.laid_leaning]); pulled across the towel, behind the pull - away from the lean, as they were. As far as it stands
	# upright: leaning far over, landed on the towel still going sideways, its hairs had folded back 145 degrees under its handle
	var along := goes - n * goes.dot(n)
	var lean_most := cos(deg_to_rad(TRAIL_LEAN_MOST))
	var upright := clampf((-d.dot(n) - lean_most) / (1.0 - lean_most), 0.0, 1.0)
	var w := clampf(along.length() / TRAIL_SPEED, 0.0, 1.0) * upright if along.length_squared() > 1e-10 else 0.0
	if w > 0.0:
		var blend := m * (1.0 - w) - along.normalized() * w
		m = blend.normalized() if blend.length() > 0.05 else -along.normalized()
	# (...each hair an arc in the plane of its root's way and the way it is laid, the surface as low as "down" reaches in that plane - turned
	# aside, a swirl's hairs had stopped 0.8 mm short of the paint)
	var aside := m - d * m.dot(d)
	aside = aside.normalized() if aside.length() > 1e-6 else m
	var into := -d.dot(n)
	var across := -aside.dot(n)
	var reach := maxf(sqrt(into * into + across * across), 0.1)
	var lay := Bristles.laid_leaning(((root - Vector3(root.x, float(h[6]), root.z)).dot(n) - LAY_CLEAR) / reach, atan2(-across, into), hl)
	# (...a cotton tip, wound tight on its stick, only bends, a little - [constant Bristles.KINDS]' `bends`)
	var bends := float(tool.get("bends", 1.0))
	if bends < 1.0:
		lay = Vector2(0.0, minf(lay.y, Bristles.arc_angle(0.6 * bends)))
	if lay.y <= 0.0:
		return [bend, Vector2.ZERO]
	return [m * Bristles.laid_at(1.0, lay, hl).x, lay]


## Where brush [param tool]'s tip is, its hairs bent [param bend] (its node's space) as [method _touched] bends them: an arc as long as
## the hairs, from their root - or, laid on a surface ([param lay], [method _lay_on_plane]), as [method Bristles.laid_at] lays them,
## bowed the way [param bend] goes.
static func _bent_tip(tool: Dictionary, bend: Vector3, lay := Vector2.ZERO) -> Vector3:
	var root: Vector3 = tool["hair_root"]
	var ax: Vector3 = tool["hair_axis"]
	var hl := maxf(float(tool["len"]), 1e-4)
	var aside := bend - ax * bend.dot(ax)
	var side := aside.length()
	if lay.y > 1e-4 and side > 1e-9:
		var at := Bristles.laid_at(1.0, lay, hl)
		return root + ax * at.y + aside / side * at.x
	var th := Bristles.arc_angle(minf(side / hl, Bristles.ASIDE_MOST))
	if th <= 1e-4:
		return root + ax * hl
	var rr := hl / th
	return root + ax * rr * sin(th) + aside / side * rr * (1.0 - cos(th))


## The face's height (along its part's depth) under point [param q] (the part's space) of obstacle grid [param g] ([method _obstacles]):
## between its cells, as high as a cell stands where it meets the rim; -INF off it. Where it falls steeply it is read between too, not
## as high as the wall stands as [method _touched] reads it: a liner's tip put onto the steep underside of a lower lip read as its top
## was lifted 2 mm onto the lip, and never drew the outline's lower half.
static func _front_z(g: Dictionary, q: Vector3) -> float:
	var at: Vector2 = g["at"]
	var n: Vector2i = g["n"]
	var Z: PackedFloat32Array = g["z"]
	var cell := float(g.get("cell", CLEAR_CELL))
	var fx := (q.x - at.x) / cell
	var fy := (q.y - at.y) / cell
	if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
		return -INF
	var i := mini(int(fx), n.x - 2)
	var j := mini(int(fy), n.y - 2)
	var k := j * n.x + i
	var z00 := Z[k]
	var z10 := Z[k + 1]
	var z01 := Z[k + n.x]
	var z11 := Z[k + n.x + 1]
	var hi := maxf(maxf(z00, z10), maxf(z01, z11))
	if z00 == -INF or z10 == -INF or z01 == -INF or z11 == -INF:
		return hi
	var a := fx - float(i)
	return lerpf(lerpf(z00, z10, a), lerpf(z01, z11, a), fy - float(j))


## WHAT TOOL [param tool] TOUCHES THROUGH PROGRAM [param prog] (laid in [param manner]) on skin [param si], held as track [param tr] holds it:
## a press where it is pressed, a stroke every BRUSH_SAMPLE millimeters along it (a fill twice that), a brush's hairs bent as they are at
## that moment - `[{u, load, pts, st}]` (when, 0-1 of the program; what was on it; the skin's millimeters it touched; which stroke).
func _stroke_touches(si: int, prog: Dictionary, tr: Dictionary, tool: Dictionary, manner: String) -> Array:
	var t := tr
	var touches: Array = []
	var brush := String(tool["kind"]) == "brush"
	var natural := maxf(float(prog["natural"]), 1e-3)
	var sk := -1
	for st in prog["strokes"]:
		sk += 1
		var s: Dictionary = st
		var ts: PackedFloat32Array = s["t"]
		var sp: PackedVector2Array = s["pts"]
		var ld: PackedFloat32Array = s.get("load", PackedFloat32Array())
		# (a stroke found before, the same places at the same pace, is what it touched then, moved to when it is laid now)
		var rel := PackedFloat32Array()
		for v in ts:
			rel.append(snappedf(v - ts[0], 0.0001))
		var mk := hash([si, tool.get("ch", ""), manner, sp, rel, ld, s.get("press", PackedFloat32Array())])
		if _stroke_memo.has(mk):
			for e in _stroke_memo[mk]:
				touches.append({"u": (ts[0] + float((e as Dictionary)["dt"])) / natural, "load": (e as Dictionary)["load"], "pts": (e as Dictionary)["pts"], "st": sk, "aim": (e as Dictionary)["aim"]})
			continue
		var found: Array = []
		# ...a press where it is pressed; a stroke every BRUSH_SAMPLE millimeters along it
		var at_t := PackedFloat32Array([ts[0]])
		var at_l := PackedFloat32Array([ld[0] if not ld.is_empty() else 1.0])
		var at_a := PackedVector2Array([sp[0]])
		var every := BRUSH_SAMPLE if manner == "line" else BRUSH_SAMPLE * 2.0
		for k in range(1, sp.size()):
			var many := maxi(ceili(sp[k - 1].distance_to(sp[k]) / every), 1)
			for j in range(1, many + 1):
				var f := float(j) / float(many)
				at_t.append(lerpf(ts[k - 1], ts[k], f))
				at_l.append(lerpf(ld[k - 1], ld[k], f) if ld.size() == sp.size() else 1.0)
				at_a.append(sp[k - 1].lerp(sp[k], f))
		var holds: Array = []
		for i in at_t.size():
			holds.append(_hold_of(_surface_hold(si, prog, at_t[i], 0.0, t), tool))
		for i in at_t.size():
			var h: Array = holds[i]
			var bend := Vector3.ZERO
			var splay := 0.0
			if brush:
				# (the hairs bent as they are at that moment: dragged back across themselves, folded the way the tip goes as pressed -
				# how fast it goes read off the places either side along the stroke, or a moment either side of a press)
				var h0: Array = holds[i - 1] if i > 0 else _hold_of(_surface_hold(si, prog, at_t[i] - 0.03, 0.0, t), tool)
				var h1: Array = holds[i + 1] if i + 1 < at_t.size() else _hold_of(_surface_hold(si, prog, at_t[i] + 0.03, 0.0, t), tool)
				var dt := (at_t[i + 1] if i + 1 < at_t.size() else at_t[i] + 0.03) - (at_t[i - 1] if i > 0 else at_t[i] - 0.03)
				var axis: Vector3 = (h[1] as Vector3).normalized()
				var n_h: Vector3 = h[7] if h.size() > 7 else Vector3.ZERO
				var ahead := -(axis - n_h * axis.dot(n_h)) if n_h.length_squared() > 0.5 else Vector3.ZERO
				var tg := Bristles.target(((h1[0] as Vector3) - (h0[0] as Vector3)) / maxf(dt, 1e-3), float(h[2]), float(tool["len"]), axis, ahead,
					float(tool.get("bends", 1.0)))
				bend = _node_at(h, tool, tool["x0"]).basis.inverse() * _bend_to_surface(si, tool, h, tg[0] as Vector3)
				splay = float(tg[1])
			var got := _touched(si, tool, h, bend, splay)
			touches.append({"u": at_t[i] / natural, "load": at_l[i], "pts": got, "st": sk, "aim": at_a[i]})
			found.append({"dt": at_t[i] - ts[0], "load": at_l[i], "pts": got, "aim": at_a[i]})
		_stroke_memo[mk] = found
	return touches


## The way tool [param tool] is held named [param name] ([method tool_of]'s `contacts`), or its own way.
static func _contact(tool: Dictionary, name: String) -> Dictionary:
	var cs: Dictionary = tool.get("contacts", {})
	if cs.has(name):
		return cs[name]
	if cs.has(String(tool.get("contact", ""))):
		return cs[String(tool["contact"])]
	return {"tip": tool.get("tip", Vector3.ZERO), "grip": tool.get("grip", Vector3.UP), "give": 0.0, "bend": 0.0, "reach": 0.01}


## HOW TOOL [param tool] IS HELD for what [param manner] lays, or for trip [param trip] (load, rinse, dry, pick): a sponge flat for
## the manners that spread and onto a towel, by its corner for every other ([constant Skins.FLAT_MANNERS]), and into its paint by its
## end's corner, along its length ([method tool_of]'s `end`).
static func _contact_for(tool: Dictionary, manner: String, trip := "") -> String:
	if String(tool.get("kind", "")) != "sponge":
		# ...a brush laying a fill or blending by the side of its hairs, held low ([constant HELD_LOW]) - its tip's own contact otherwise
		if String(tool.get("kind", "")) == "brush" and trip.is_empty() and manner in Skins.FLAT_MANNERS:
			return "belly"
		return String(tool.get("contact", "tip"))
	if not trip.is_empty():
		return "face" if trip == "dry" else "end"
	return "face" if manner in Skins.FLAT_MANNERS else "corner"


## The way a hold [param h] holds its tool ("" its own).
static func _contact_of(h: Array) -> String:
	return String(h[5]) if h.size() > 5 else ""


# --- the skin's surface ------------------------------------------------------------------------------

## A SKIN'S SURFACE seen from its front, found once: a grid every [constant SURFACE_STEP] millimeters of where the surface
## is and which way it faces, in its holder's space - from rays straight in along the part's front.
func _surface_of(sd: Dictionary) -> Dictionary:
	var faces := PackedVector3Array()
	for m in sd["meshes"]:
		var mi := m as MeshInstance3D
		if mi.mesh != null:
			faces.append_array(mi.mesh.get_faces())
	var frame: Vector2 = sd["frame"]
	var nx := int(ceil(frame.x / SURFACE_STEP)) + 1
	var ny := int(ceil(frame.y / SURFACE_STEP)) + 1
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var hit := PackedByteArray()
	pos.resize(nx * ny)
	nrm.resize(nx * ny)
	hit.resize(nx * ny)
	var xf: Transform3D = sd["xform"]
	var box: AABB = sd["box"]
	var front := (xf.basis * Vector3.BACK).normalized()
	if faces.is_empty():
		return {"nx": nx, "ny": ny, "pos": pos, "nrm": nrm, "hit": hit, "front": front}
	var tm := TableWork._ray_mesh(faces)
	for j in ny:
		_breathe()
		for i in nx:
			var x := box.position.x + minf(float(i) * SURFACE_STEP * 0.001, box.size.x)
			var y := box.end.y - minf(float(j) * SURFACE_STEP * 0.001, box.size.y)
			var from := xf * Vector3(x, y, box.end.z + 0.02)
			var got := TableWork._ray(tm, from, -front)
			var k := j * nx + i
			if got.is_empty():
				# none here: the plane the front stands in, facing out
				pos[k] = xf * Vector3(x, y, box.position.z + box.size.z * 0.5)
				nrm[k] = front
				continue
			pos[k] = got["position"]
			var n: Vector3 = (got["normal"] as Vector3).normalized()
			nrm[k] = n if n.dot(front) >= 0.0 else -n
			hit[k] = 1
	# ...FACING AS ITS SURFACE SLOPES, never as the one facet a ray happened to land on: the grid's rays fall on the face's own points,
	# a vertex six facets share, and which of them answered was luck - a mask's grid 1.5 microns narrower turned the normals by 30
	# degrees at the nose's tip and a sponge laid flat on it stood 7 mm in it (feedback 0025's mesh). From its neighbors either way, as
	# far as they are on it; a place with none beside it keeps its facet's.
	var sloped := PackedVector3Array(nrm)
	for j in ny:
		for i in nx:
			var k := j * nx + i
			if hit[k] == 0:
				continue
			var e := pos[k + 1] if i + 1 < nx and hit[k + 1] == 1 else pos[k]
			var w := pos[k - 1] if i > 0 and hit[k - 1] == 1 else pos[k]
			var s := pos[k + nx] if j + 1 < ny and hit[k + nx] == 1 else pos[k]
			var u := pos[k - nx] if j > 0 and hit[k - nx] == 1 else pos[k]
			var c := (e - w).cross(u - s)
			if (e - w).length_squared() > 0.0 and (u - s).length_squared() > 0.0 and c.length_squared() > 1e-16:
				c = c.normalized()
				sloped[k] = c if c.dot(front) >= 0.0 else -c
	nrm = sloped
	# ...ITS EDGE, where it falls away sideways beside nothing, is past it too: a tool sent to a mask's rim had gone to the foot of the
	# shell's outer edge, under the face beside it, and a sponge's corner could only stand off it (feedback 0016)
	# ...and so is a lip at the foot of it (a shell's back, beside nothing, far under the face beside it)
	var edge := PackedInt32Array()
	for k in hit.size():
		if hit[k] == 0:
			continue
		var i0 := k % nx
		var j0 := k / nx
		var bare := false
		var over := -INF
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var x := i0 + di
				var y := j0 + dj
				if x < 0 or y < 0 or x >= nx or y >= ny:
					continue
				if hit[y * nx + x] == 0:
					bare = true
				else:
					over = maxf(over, pos[y * nx + x].dot(front))
		if bare and (nrm[k].dot(front) < EDGE_FACING or over - pos[k].dot(front) > EDGE_CLIFF):
			edge.append(k)
	for k in edge:
		hit[k] = 0
	# OFF THE SURFACE (past a mask's rim), the nearest place on it: a tool sent there goes to the edge, never into the air
	var queue := PackedInt32Array()
	var near := PackedByteArray(hit)
	for k in hit.size():
		if hit[k] == 1:
			queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var x: int = k % nx + d[0]
			var y: int = k / nx + d[1]
			if x < 0 or y < 0 or x >= nx or y >= ny:
				continue
			var nk := y * nx + x
			if near[nk] == 0:
				near[nk] = 1
				pos[nk] = pos[k]
				nrm[nk] = nrm[k]
				queue.append(nk)
	return {"nx": nx, "ny": ny, "pos": pos, "nrm": nrm, "hit": hit, "front": front, "mesh": tm}


## WHERE (x, y) millimeters ON SKIN [param si] IS, in its holder's space: `[point, normal]`.
func at_mm(si: int, xy: Vector2) -> Array:
	var sf: Dictionary = (skins[si] as Dictionary)["surface"]
	var nx := int(sf["nx"])
	var ny := int(sf["ny"])
	var fx := clampf(xy.x / SURFACE_STEP, 0.0, float(nx - 1))
	var fy := clampf(xy.y / SURFACE_STEP, 0.0, float(ny - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fy), ny - 2)
	var a := fx - float(i)
	var b := fy - float(j)
	var P: PackedVector3Array = sf["pos"]
	var N: PackedVector3Array = sf["nrm"]
	var k := j * nx + i
	var p := P[k].lerp(P[k + 1], a).lerp(P[k + nx].lerp(P[k + nx + 1], a), b)
	var n := N[k].lerp(N[k + 1], a).lerp(N[k + nx].lerp(N[k + nx + 1], a), b)
	# ...ON THE SURFACE ITSELF wherever there is one under it: the grid's corners only bound it, a face curves between them, and BY ITS
	# EDGE (a corner of the cell off it) their blend hung in front of a surface curving away - where its paint is laid all the same,
	# projected straight in along its front, and every tool painting along a mask's rim hovered over it (feedback 0019, 0021: "you can
	# tell by the shadow it casts, it's floating above the mask" - the liner 11 mm off, the flat brush 22). There it faces as it does.
	var H: PackedByteArray = sf["hit"]
	if sf.get("mesh") != null and (H[k] == 1 or H[k + 1] == 1 or H[k + nx] == 1 or H[k + nx + 1] == 1):
		var sd: Dictionary = skins[si]
		var box: AABB = sd["box"]
		var front: Vector3 = sf["front"]
		var from: Vector3 = (sd["xform"] as Transform3D) * Vector3(box.position.x + xy.x * 0.001, box.end.y - xy.y * 0.001, box.end.z + 0.02)
		var got := TableWork._ray(sf["mesh"], from, -front)
		if not got.is_empty():
			p = got["position"]
			if not (H[k] == 1 and H[k + 1] == 1 and H[k + nx] == 1 and H[k + nx + 1] == 1):
				var hn: Vector3 = got["normal"]
				n = hn if hn.dot(front) > 0.0 else -hn
	return [p, n.normalized() if n.length() > 1e-6 else sf["front"]]


## Which way skin [param si]'s surface faces at (x, y) millimeters, in its holder's space ([method at_mm]'s, with no ray).
func _normal_mm(si: int, xy: Vector2) -> Vector3:
	var sf: Dictionary = (skins[si] as Dictionary)["surface"]
	var nx := int(sf["nx"])
	var ny := int(sf["ny"])
	var fx := clampf(xy.x / SURFACE_STEP, 0.0, float(nx - 1))
	var fy := clampf(xy.y / SURFACE_STEP, 0.0, float(ny - 1))
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fy), ny - 2)
	var N: PackedVector3Array = sf["nrm"]
	var k := j * nx + i
	var n := N[k].lerp(N[k + 1], fx - float(i)).lerp(N[k + nx].lerp(N[k + nx + 1], fx - float(i)), fy - float(j))
	return n.normalized() if n.length() > 1e-6 else (sf["front"] as Vector3)


## SKIN [param si]'s holder where it is at show time [param T], in the table's space.
func holder_world(si: int, T: float) -> Transform3D:
	var sd: Dictionary = skins[si]
	var ti := int(sd["ti"])
	if not sd.has("_rest"):
		sd["_rest"] = work._world_of(sd["holder"])
	return work._thing_world(ti, T) * work._world_rest_thing(ti).affine_inverse() * (sd["_rest"] as Transform3D)


# --- the canvas ---------------------------------------------------------------------------------------

## SKIN [param si]'s CANVAS: two viewports of its own - its color, and its finish - an element a sprite in each, every element
## an act lays; and the part's material told where they are.
func _canvas(si: int) -> void:
	var sd: Dictionary = skins[si]
	for vp in sd.get("canvas", []):
		if is_instance_valid(vp):
			(vp as Node).queue_free()
	for st in sd.get("stone_nodes", []):
		if is_instance_valid(st):
			(st as Node).queue_free()
	sd["canvas"] = []
	sd["items"] = {}
	sd["stone_nodes"] = []
	sd["stones"] = []
	var design: Dictionary = sd["design"]
	if (design.get("elements", []) as Array).is_empty():
		_skin_material(sd, null, null)
		return
	var frame: Vector2 = sd["frame"]
	var size := Vector2i(maxi(int(ceil(frame.x * CANVAS_PX)), 8), maxi(int(ceil(frame.y * CANVAS_PX)), 8))
	var vps: Array = []
	for k in 2:
		var vp := SubViewport.new()
		vp.name = "Skin %d %s" % [si, "color" if k == 0 else "finish"]
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		if work._root != null:
			work._root.add_child(vp)
		vps.append(vp)
	sd["canvas"] = vps
	var outline := String(sd.get("outline", ""))
	for e in design["elements"]:
		var ed: Dictionary = e
		var lay: Dictionary = _layers.get("%d|%s" % [si, String(ed["id"]).to_lower()], {})
		if lay.is_empty():
			continue
		if String(ed["kind"]) == "stones":
			_stones_of(si, ed)
			continue
		var made := _made_for(si, ed, String(lay["manner"]), float(lay["mm"]))
		if made.is_empty() or made.get("cover") == null:
			continue
		var fin: Dictionary = Skins.FINISHES[String(ed["finish"])]
		# (...a fill blended, softened no further than its own middle allows - [constant Skins.BLEND_SHARE]; a line feathered as it was)
		var reach := float(made.get("reach", INF)) if String(ed["kind"]) == "fill" else INF
		var lods := Vector2(_lod(float(ed["soft"])), _lod(maxf(float(ed["soft"]), minf(Skins.BLEND_SOFT, reach * Skins.BLEND_SHARE))))
		# (...a soft edge goes on crisp, and softens as its tool goes back over it - [constant SOFT_GONE_OVER])
		if bool(lay.get("soft_over", false)):
			lods.x = _lod(0.0)
		var item := {"el": ed, "made": made, "sprites": [], "mats": []}
		for k in 2:
			var sp := Sprite2D.new()
			sp.centered = false
			sp.texture = made["cover_tex"]
			sp.position = (made["rect"] as Rect2).position * CANVAS_PX
			var mat := ShaderMaterial.new()
			mat.shader = _CANVAS
			mat.set_shader_parameter("cover", made["cover_tex"])
			mat.set_shader_parameter("when_map", made["when_tex"])
			mat.set_shader_parameter("paint", Color.html(String(lay.get("pot", ed["paint"]))))
			mat.set_shader_parameter("finish", Color(float(fin["rough"]), float(fin["metal"]), float(fin["glitter"]), 1.0))
			mat.set_shader_parameter("finish_pass", k == 1)
			mat.set_shader_parameter("opacity", float(ed["opacity"]) * float(lay.get("thick", 1.0)))
			mat.set_shader_parameter("pressed", {"stipple": 1, "pat": 2}.get(String(lay["manner"]), 0))
			mat.set_shader_parameter("lods", lods)
			mat.set_shader_parameter("swept", Skins.SWEPT if String(ed["finish"]) == "powder" else 1.0)
			mat.set_shader_parameter("mm", (made["rect"] as Rect2).size)
			# A MIST lays no color: only its sheen, which dries down
			if String(ed["kind"]) == "mist":
				mat.set_shader_parameter("color_alpha", 0.0)
				mat.set_shader_parameter("finish", Color(Skins.DEW, 0.0, 0.0, 1.0))
				mat.set_shader_parameter("dries", Skins.DEW_DRIES)
				mat.set_shader_parameter("dried", Skins.DEW_LEFT)
			mat.set_shader_parameter("span", Vector2(1e9, 1e9 + 1.0))
			mat.set_shader_parameter("blend_span", Vector2(1e9, 1e9 + 1.0))
			mat.set_shader_parameter("sweep_span", Vector2(1e9, 1e9 + 1.0))
			sp.material = mat
			(vps[k] as SubViewport).add_child(sp)
			(item["sprites"] as Array).append(sp)
			(item["mats"] as Array).append(mat)
		(sd["items"] as Dictionary)[String(ed["id"]).to_lower()] = item
	_skin_material(sd, (vps[0] as SubViewport).get_texture(), (vps[1] as SubViewport).get_texture())


## The mip level that softens an edge [param mm] millimeters.
static func _lod(mm: float) -> float:
	return log(maxf(mm * CANVAS_PX, 1.0)) / log(2.0)


## WHAT ELEMENT [param ed] OF SKIN [param si] IS, laid in [param manner] by a tool [param mm] across: its program, its pictures
## and its reveal map - made once, kept.
func _made_for(si: int, ed: Dictionary, manner: String, mm: float) -> Dictionary:
	var sd: Dictionary = skins[si]
	var key := "%s|%s|%s|%.2f|%s" % [sd["name"], hash(ed), manner, mm, sd["frame"]]
	if _made.has(key):
		return _made[key]
	var frame: Vector2 = sd["frame"]
	var outline := String(sd.get("outline", ""))
	# (...and a brush's paint as far past it as its hairs reach: laid where they touch - [method _touch_all])
	var margin := maxf(float(ed["soft"]), Skins.BLEND_SOFT) * 1.5 + (mm if manner in BRUSH_TOUCHED else 0.0)
	var rect := Skins.rect_of(ed, frame, margin)
	var cov1 := Skins.cover(ed, rect, Skins.WHEN_PX, outline, frame)
	var prog := Skins.program(ed, manner, mm, cov1, rect, {}, null, frame)
	# (by which its holds are kept, [method _held_keys])
	prog["id"] = key
	var out := {"program": prog, "planned": prog, "rect": rect, "reach": Skins.inner_reach(cov1)}
	if String(ed["kind"]) != "stones":
		var cov := Skins.cover(ed, rect, CANVAS_PX, outline, frame)
		if cov != null:
			cov.generate_mipmaps()
			out["cover"] = cov
			out["cover_tex"] = ImageTexture.create_from_image(cov)
			var wm := Skins.when_map(prog, rect)
			out["when"] = wm
			out["when_tex"] = ImageTexture.create_from_image(wm)
	if _made.size() > 400:
		_made.clear()
	_made[key] = out
	return out


## ITS STONES, things of their own on the skin's holder: each a small faceted crystal, seen once a tool has picked it up.
func _stones_of(si: int, ed: Dictionary) -> void:
	var sd: Dictionary = skins[si]
	var lay: Dictionary = _layers.get("%d|%s" % [si, String(ed["id"]).to_lower()], {})
	var made := _made_for(si, ed, "place", float(lay.get("mm", 4.0)))
	var holder: Node3D = sd["holder"]
	var m := Props.sanitize_material({"kind": "crystal", "color": String(ed["paint"]), "clarity": 0.55, "polish": 0.95, "play": "fire"}, String(ed["paint"]))
	for k in (ed["stones"] as Array).size():
		var c: Array = ed["stones"][k]
		var r := float(c[2]) * 0.001
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd["name"], ed["id"], k])
		var g := Props._ball(Vector3(r, r * 0.7, r) * 200.0, 0.0, true, rng)
		var mi := MeshInstance3D.new()
		mi.mesh = g.placed([Transform3D.IDENTITY]).mesh()
		mi.material_override = Props.material(m, {}, r * 600.0, r * 140.0, hash([ed["id"], k]), true, true)
		mi.visible = false
		holder.add_child(mi)
		(sd["stone_nodes"] as Array).append(mi)
		var on := at_mm(si, Vector2(float(c[0]), float(c[1])))
		var n: Vector3 = on[1]
		var b := Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) > -0.999 else Basis.IDENTITY
		(sd["stones"] as Array).append({"node": mi, "el": String(ed["id"]).to_lower(), "k": k, "seat": Transform3D(b, (on[0] as Vector3) + n * r * STONE_OUT),
			"t": Vector2(INF, INF), "tool": ""})
	sd["stones_made"] = made


## THE PART'S OWN MATERIAL told of its skin: where its front is, and the two pictures composed for it.
func _skin_material(sd: Dictionary, color: Texture2D, finish: Texture2D) -> void:
	var xf: Transform3D = sd["xform"]
	var box: AABB = sd["box"]
	var M := xf.affine_inverse()
	var row := func(r: int) -> Vector4:
		return Vector4(M.basis.x[r], M.basis.y[r], M.basis.z[r], M.origin[r])
	var rx: Vector4 = row.call(0)
	var ry: Vector4 = row.call(1)
	var u := Vector4(rx.x, rx.y, rx.z, rx.w - box.position.x) / maxf(box.size.x, 1e-6)
	var v := Vector4(-ry.x, -ry.y, -ry.z, box.end.y - ry.w) / maxf(box.size.y, 1e-6)
	for m in sd["meshes"]:
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("skinned", color != null)
		mat.set_shader_parameter("skin_u", u)
		mat.set_shader_parameter("skin_v", v)
		mat.set_shader_parameter("skin_side", (xf.basis * Vector3.BACK).normalized())
		if color != null:
			mat.set_shader_parameter("skin_color", color)
			mat.set_shader_parameter("skin_finish", finish)


# --- an act that paints -------------------------------------------------------------------------------

## THE PLAN OF PAINT TRACK [param tr], [param d] seconds long: its phases in seconds from its start - `{phases: [{kind (fetch,
## load, rinse, move, el, rest, back, still), a, b, ...}], natural, work}` - `work` the part of `natural` its elements take, the rest
## its trips and moves. An element's phase carries its program and how much it is slowed (`k`); a load the paint it takes up and from where.
func plan_of(tr: Dictionary, d: float) -> Dictionary:
	var si := int(tr.get("_skin", -1))
	var ch := String(tr.get("_ch", ""))
	var tool := tool_of(ch, tr)
	var parts: Array = []
	# (...still holding the paint its last act ended with, where this one begins in it - [method _one_after_another])
	var loaded := String(tr.get("_loaded", ""))
	# ...and the mix on it, once this act loaded one: a new mix from the same pot is rinsed off and taken up again (feedback 0006,
	# 2026-11-09: a pale amber mix, then a dark one, "applied without ever returning to the container, to pickup a heavier load")
	var loaded_as := ""
	for id in tr.get("paint", []):
		var ed := element(si, String(id))
		if ed.is_empty():
			continue
		var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
		var mine: bool = not lay.is_empty() and lay.get("act") == tr.get("_act")
		var manner := String(lay.get("manner", "")) if mine else Skins.blend_manner(String(tool["kind"]))
		if String(ed["kind"]) == "stones" and not mine:
			continue
		# (the program its paint is shown by, [member _layers]'s - or its blend's)
		var made := _made_for(si, ed, manner, float(lay["mm"])) if mine else _made_for(si, ed, manner, _width(tool, tr, manner))
		var prog: Dictionary = made["program"]
		# (...laid from the picture, and nothing of it wanted there: no part of its act - [method _from_picture])
		if mine and bool(made.get("laid", false)) and (prog.get("strokes", []) as Array).is_empty():
			continue
		var role := "paint" if mine else ("sweep" if String(ed["finish"]) == "powder" else "blend")
		var pre: Array = []
		var pot := String(lay.get("pot", ed["paint"]))
		if role == "paint" and String(lay.get("manner", "")) == "blend":
			# (...A BLEND taken up on nothing: the brush rinsed clean of what it held, and dried - [method PaintLayers._blend_op])
			if tr.has("rinse") and not loaded.is_empty():
				pre.append({"kind": "rinse", "len": _trip_len("rinse", tool), "out": loaded})
				if tr.has("dry"):
					pre.append({"kind": "dry", "len": _trip_len("dry", tool)})
			loaded = ""
			loaded_as = ""
		elif role == "paint" and not String(ed["kind"]) in ["stones", "smear", "mist"] \
				and (pot != loaded or (not loaded_as.is_empty() and String(ed["paint"]) != loaded_as)):
			# (...a thin one taken up on a brush wetted first - rinsed and not dried, or dipped clean - [constant THIN_WET]; never one still
			# damp from the rinse that ended its last act)
			var thin := float(ed["opacity"]) * float(lay.get("thick", 1.0)) < THIN_WET and not (loaded.is_empty() and bool(tr.get("_damp", false)))
			if tr.has("rinse") and (not loaded.is_empty() or thin):
				pre.append({"kind": "rinse", "len": _trip_len("rinse", tool), "out": loaded})
				if tr.has("dry") and not thin:
					pre.append({"kind": "dry", "len": _trip_len("dry", tool)})
			pre.append({"kind": "load", "len": LOAD, "paint": pot, "from": String(tr.get("from", "")), "side": _side_after(prog, -1)})
			loaded = pot
			loaded_as = String(ed["paint"])
			if not prog.has("pot"):
				prog["pot"] = pot
		parts.append({"el": String(ed["id"]).to_lower(), "pre": pre, "prog": prog, "role": role, "finish": String(ed["finish"])})
		# ...AND A SOFT EDGE GONE OVER AGAIN as soon as it is laid, nothing more taken up ([constant SOFT_GONE_OVER])
		if mine and bool(lay.get("soft_over", false)):
			var bm := Skins.blend_manner(String(tool["kind"]))
			parts.append({"el": String(ed["id"]).to_lower(), "pre": [], "prog": _made_for(si, ed, bm, _width(tool, tr, bm))["program"], "role": "blend",
				"finish": String(ed["finish"])})
	# ...AND CLEANED BEFORE IT GOES BACK, where there is water for it - unless its next act begins in the paint it holds
	var clean: Array = []
	if tr.has("rinse") and not loaded.is_empty() and not bool(tr.get("_keep", false)):
		clean.append({"kind": "rinse", "len": _trip_len("rinse", tool), "out": loaded})
		if tr.has("dry"):
			clean.append({"kind": "dry", "len": _trip_len("dry", tool)})
	# ...NOTHING TO LAY OR GO OVER, nothing taken up: the tool stays where it rests ([method _one_coat] - an act whose coat is the one before's)
	if parts.is_empty() and clean.is_empty():
		return {"phases": [], "natural": 0.1, "work": 0.0, "d": d, "si": si}
	# ...EACH WAY AS LONG AS ITS LENGTH NEEDS (2026-11-10, the user: "the brush is leaving paint streaks in places that are far away from where
	# it's actually touching now" - "I have a feeling these marks are being drawn out of view"): a move from one element to the next had
	# taken 1.4 s however far it went, and a trip its own time from wherever the tool was - a brow to a chin, 20 cm, at a metre a second at
	# its fastest, where a held tool's body is carried at about 0.58 m/s; the body fell 12 cm behind its hand and the next element was
	# painted where it was not. Never less than a hand's time ([constant MOVE], a trip's own), at most MOVE_PACE (m/s) between elements and
	# TRIP_PACE out to a trip's place in the share its flight has ([constant TRIP_GO_MOST])
	_paced(si, tr, parts, clean)
	var natural := FETCH + RETURN
	for q in clean:
		natural += float((q as Dictionary)["len"])
	var work_len := 0.0
	for p in parts:
		for q in (p as Dictionary)["pre"]:
			natural += float((q as Dictionary)["len"])
		natural += float((p as Dictionary).get("move", MOVE)) + float(((p as Dictionary)["prog"] as Dictionary)["natural"])
		work_len += float(((p as Dictionary)["prog"] as Dictionary)["natural"])
	var fixed := natural - work_len
	# SLOWED, THEN RESTED, as long as the act is; HURRIED, if it must be
	var k := 1.0
	var rest := 0.0
	var after := 0.0
	if d > natural and work_len > 0.0:
		k = minf((d - fixed) / work_len, SLOW_MOST)
		var left := d - fixed - work_len * k
		rest = minf(left / float(maxi(parts.size(), 1)), REST_MOST)
		after = maxf(left - rest * float(parts.size()), 0.0)
	elif d < natural and work_len > 0.0:
		k = maxf((d - fixed * minf(d / natural, 1.0)) / work_len, QUICK_MOST)
	var squeeze := minf(d / maxf(fixed + work_len * k + rest * float(parts.size()), 1e-3), 1.0)
	var phases: Array = []
	var clock := [0.0]            # (a lambda's own copy of a number would never move on)
	var add := func(kind: String, len: float, extra: Dictionary) -> void:
		var ph := extra.duplicate()
		ph["kind"] = kind
		ph["a"] = float(clock[0])
		ph["b"] = float(clock[0]) + len * squeeze
		phases.append(ph)
		clock[0] = float(ph["b"])
	add.call("fetch", FETCH, {})
	for i in parts.size():
		var p: Dictionary = parts[i]
		for q in p["pre"]:
			add.call(String((q as Dictionary)["kind"]), float((q as Dictionary)["len"]), q as Dictionary)
		add.call("move", float(p.get("move", MOVE)), {"el": p["el"], "prog": p["prog"]})
		add.call("el", float((p["prog"] as Dictionary)["natural"]) * k, {"el": p["el"], "prog": p["prog"], "role": p["role"], "finish": p["finish"]})
		add.call("rest", rest, {"el": p["el"], "prog": p["prog"]})
	for q in clean:
		add.call(String((q as Dictionary)["kind"]), float((q as Dictionary)["len"]), q as Dictionary)
	# (...and never put down where its next act goes straight on with it - [method _one_after_another]: "the sponge went into the dish, then
	# came back to the mask and started dabbing again", feedback 0063)
	if not bool(tr.get("_keep", false)):
		add.call("back", RETURN, {})
	if after > 0.0:
		add.call("still", after, {})
	return {"phases": phases, "natural": natural, "work": work_len, "d": d, "si": si}


## EACH MOVE AND TRIP OF AN ACT AS LONG AS ITS WAY NEEDS ([method plan_of]): [param parts]' `move` (seconds, from where the tool was to its
## element's first key) and each trip's `len` in their `pre` and in [param clean] (from where the tool was to the trip's place), measured on
## the table as it stands - never shorter than they were.
func _paced(si: int, tr: Dictionary, parts: Array, clean: Array) -> void:
	if not paced or si < 0 or si >= skins.size():
		return
	var hw := holder_world(si, 0.0)
	var on := func(xy: Vector2) -> Vector3: return hw * (at_mm(si, xy)[0] as Vector3)
	var place := func(q: Dictionary) -> Vector3:
		var kind := String(q.get("kind", ""))
		return _source_of(kind, String(tr.get(kind, "")) if kind in ["rinse", "dry"] else String(q.get("from", tr.get("from", ""))),
			String(q.get("paint", "")), 0.0)
	var tool := tool_of(String(tr.get("_ch", "")), tr)
	var trip := func(q: Dictionary, here: Vector3, here_lean: Vector3) -> Vector3:
		var to: Vector3 = place.call(q)
		if here != Vector3.INF and to != Vector3.INF:
			# (...its handle stood up into the pot from however it leaned - [method _way_length])
			q["len"] = maxf(float(q["len"]), _way_length(here, to, here_lean, Vector3.UP, tool) / (TRIP_PACE * TRIP_GO_MOST))
		return to
	# (...and how a hand holds it there: its handle swung from one lean to the next sweeps further than its tip goes - [method _held_axis])
	var lean := func(xy: Vector2, prog: Dictionary) -> Vector3:
		if tool.is_empty():
			return Vector3.UP
		return _held_axis(si, xy, (at_mm(si, xy)[1] as Vector3).normalized(), tool, _contact_for(tool, String(prog.get("manner", ""))))
	var here := Vector3.INF
	var here_lean := Vector3.ZERO
	for p in parts:
		var pd: Dictionary = p
		for q in pd["pre"]:
			here = trip.call(q as Dictionary, here, here_lean)
			here_lean = Vector3.UP
		var keys: Array = (pd["prog"] as Dictionary).get("keys", [])
		if keys.is_empty():
			continue
		var xy0 := Vector2(float((keys[0] as Array)[1]), float((keys[0] as Array)[2]))
		var start: Vector3 = on.call(xy0)
		var start_lean: Vector3 = lean.call(xy0, pd["prog"])
		if here != Vector3.INF:
			pd["move"] = maxf(MOVE, _way_length(here, start, here_lean, start_lean, tool) / MOVE_PACE)
		var last: Array = keys[keys.size() - 1]
		var xy1 := Vector2(float(last[1]), float(last[2]))
		here = on.call(xy1)
		here_lean = lean.call(xy1, pd["prog"])
	for q in clean:
		here = trip.call(q as Dictionary, here, here_lean)
		here_lean = Vector3.UP


## EACH WAY INSIDE AN ELEMENT AS LONG AS ITS LENGTH NEEDS (feedback 0010, 2026-11-10: "black mark on the chin ... brush not even
## touching"): a liner's chin, drawn out from its middle, ended one stroke leaning left and began the next leaning right - its handle swung
## 100 degrees in the 0.41 s its program gave the lift between, its body (carried near what it paints no faster than about 0.58 m/s) fell
## 6 cm behind its hand, and its paint was laid where the brush was not. Where a program gives a way less time than [constant KEY_PACE]
## needs over it ([method _key_ways]), its times are stretched there and every reveal map of it with them ([method _warp_program],
## [method _warp_maps]), before any act's length is known. Never twice: a way given its time needs no more.
func _pace_keys() -> void:
	if not paced:
		return
	# (each program once, at the most time any track's tool needs over each of its ways)
	var needs := {}
	for a in work.acts:
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch") or int(t.get("_skin", -1)) < 0:
				continue
			var si := int(t["_skin"])
			var tool := tool_of(String(t["_ch"]), t)
			if tool.is_empty():
				continue
			var held_of: Dictionary = (skins[si] as Dictionary).get("held", {})
			for ph in plan_of(t, 0.0)["phases"]:
				var pd: Dictionary = ph
				if String(pd["kind"]) != "el":
					continue
				var prog: Dictionary = pd["prog"]
				var contact := _contact_for(tool, String(prog.get("manner", "")))
				var least := _key_ways(si, prog, tool, contact, held_of.get(_held_key(prog, String(t["_ch"]), contact), {}))
				var id := String(prog.get("id", ""))
				if needs.has(id):
					var most: PackedFloat32Array = (needs[id] as Array)[1]
					for k in mini(most.size(), least.size()):
						most[k] = maxf(most[k], least[k])
					(needs[id] as Array)[1] = most
				else:
					needs[id] = [prog, least]
	for id in needs:
		var prog: Dictionary = (needs[id] as Array)[0]
		var times := _warp_program(prog, (needs[id] as Array)[1])
		if times.is_empty():
			continue
		# ...AND WHAT SHOWS ITS PAINT, by its new times: every made thing laying it, and the materials of each element shown by one
		var warped: Array = []
		for made in _made.values():
			if made is Dictionary and is_same((made as Dictionary).get("program"), prog):
				_warp_maps(made, times)
				warped.append(made)
		for si in skins.size():
			var items: Dictionary = (skins[si] as Dictionary)["items"]
			for item_id in items:
				var item: Dictionary = items[item_id]
				var made: Dictionary = item.get("made", {})
				if not is_same(made.get("program"), prog):
					continue
				if not warped.any(func(m: Variant) -> bool: return is_same(m, made)):
					_warp_maps(made, times)
					warped.append(made)
				for m in item["mats"]:
					var mat := m as ShaderMaterial
					if made.has("when_tex"):
						mat.set_shader_parameter("when_map", made["when_tex"])
					if made.has("built_when_tex"):
						mat.set_shader_parameter("laid_when", (made["built_when_tex"] as Array)[0])
						mat.set_shader_parameter("laid_when2", (made["built_when_tex"] as Array)[1])


## THE LEAST TIME EACH WAY OF PROGRAM [param prog] NEEDS, from each key to the next (seconds; none where its time is a trip's, a spray's
## or no time at all): its tip's way over skin [param si], up and down and over its arc, and its handle swung from how it is held at the
## one to how at the other ([param kept], [method _held_keys]; none found, as a hand holds it - [method _skin_hold]), at [constant KEY_PACE].
func _key_ways(si: int, prog: Dictionary, tool: Dictionary, contact: String, kept: Dictionary) -> PackedFloat32Array:
	var keys: Array = prog["keys"]
	var out := PackedFloat32Array()
	out.resize(maxi(keys.size() - 1, 0))
	if keys.size() < 2:
		return out
	var held: PackedVector4Array = kept.get("held", PackedVector4Array())
	var arcs: PackedFloat32Array = kept.get("arcs", PackedFloat32Array())
	var arm := _arm_of(tool)
	var hw := holder_world(si, 0.0)
	var places: Array = []
	for k in keys.size():
		var kk: Array = keys[k]
		if int(kk[5]) == 3:
			places.append(null)
			continue
		var xy := Vector2(float(kk[1]), float(kk[2]))
		var on := at_mm(si, xy)
		var n: Vector3 = (on[1] as Vector3).normalized()
		var hk := held[k] if k < held.size() else Vector4.ZERO
		var ax := Vector3(hk.x, hk.y, hk.z)
		if ax.length_squared() < 0.5:
			ax = _held_axis(si, xy, on[1], tool, contact)
		places.append([hw * ((on[0] as Vector3) + n * float(kk[3]) * 0.001 + ax * hk.w), (hw.basis * ax).normalized()])
		if k % 64 == 63:
			_breathe()
	for k in keys.size() - 1:
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		if int(a[5]) != 0 or int(b[5]) != 0 or float(b[0]) - float(a[0]) < 1e-5 or places[k] == null or places[k + 1] == null:
			continue
		var pa: Array = places[k]
		var pb: Array = places[k + 1]
		var arc := arcs[k] if k < arcs.size() else 0.0
		out[k] = ((pa[0] as Vector3).distance_to(pb[0] as Vector3) + 2.0 * arc + (pa[1] as Vector3).angle_to(pb[1] as Vector3) * arm) / KEY_PACE
	return out


## PROGRAM [param prog]'s TIMES STRETCHED wherever a way from one key to the next has less than [param least] (seconds) - its keys, its
## strokes' points, its pats, mists and stones, and its length, each new (a program laid again may share the old) - and
## `[old moments, new moments, old length, new length]` (the start's, each key's and the end's), or none where every way had its time.
static func _warp_program(prog: Dictionary, least: PackedFloat32Array) -> Array:
	var keys: Array = prog["keys"]
	var old_t := PackedFloat32Array([0.0])
	var new_t := PackedFloat32Array([0.0])
	var shift := 0.0
	for k in keys.size():
		var t := float((keys[k] as Array)[0])
		if k > 0:
			var span := t - float((keys[k - 1] as Array)[0])
			var want := least[k - 1] if k - 1 < least.size() else 0.0
			# (...more than a millisecond short: a way given its time is never stretched again)
			if span > 1e-5 and want > span + 0.001:
				shift += want - span
		old_t.append(maxf(t, old_t[old_t.size() - 1]))
		new_t.append(maxf(t + shift, new_t[new_t.size() - 1]))
	if shift <= 0.0:
		return []
	var was := maxf(float(prog["natural"]), old_t[old_t.size() - 1])
	old_t.append(was)
	new_t.append(was + shift)
	var at := func(t: float) -> float: return _warp_t(t, old_t, new_t)
	var new_keys: Array = []
	for k in keys.size():
		var kk: Array = (keys[k] as Array).duplicate()
		kk[0] = new_t[k + 1]
		new_keys.append(kk)
	prog["keys"] = new_keys
	var strokes: Array = []
	for st in prog.get("strokes", []):
		var sd: Dictionary = (st as Dictionary).duplicate()
		var ts := PackedFloat32Array(sd["t"])
		for i in ts.size():
			ts[i] = at.call(ts[i])
		sd["t"] = ts
		strokes.append(sd)
	prog["strokes"] = strokes
	if prog.has("pats"):
		var pats := PackedFloat32Array()
		for pt in prog["pats"]:
			pats.append(at.call(float(pt)))
		prog["pats"] = pats
	for field in ["mists", "stones"]:
		var rows: Array = []
		for row in prog.get(field, []):
			var r: Array = (row as Array).duplicate()
			# (a mist's moment first; a stone's picked and laid)
			for i in ([0] if field == "mists" else [0, 1]):
				r[i] = at.call(float(r[i]))
			rows.append(r)
		if prog.has(field):
			prog[field] = rows
	prog["natural"] = was + shift
	return [old_t, new_t, was, was + shift]


## Moment [param t] of a program, by the times it was stretched from ([param old_t]) to ([param new_t]): straight between two of them,
## and past either end as far past its new one.
static func _warp_t(t: float, old_t: PackedFloat32Array, new_t: PackedFloat32Array) -> float:
	var n := old_t.size()
	if t <= old_t[0]:
		return t - old_t[0] + new_t[0]
	if t >= old_t[n - 1]:
		return t - old_t[n - 1] + new_t[n - 1]
	var i := clampi(old_t.bsearch(t, false) - 1, 0, n - 2)
	var seg := old_t[i + 1] - old_t[i]
	return new_t[i] + ((t - old_t[i]) * (new_t[i + 1] - new_t[i]) / seg if seg > 1e-9 else 0.0)


## WHAT SHOWED A PROGRAM'S PAINT BY ITS OLD TIMES, BY ITS NEW ([method _warp_program]'s [param times]): each moment in made thing
## [param made]'s reveal maps (shares of the program's length - Skins.NEVER, and a touch map's "never again", left as they are) and its
## touches. Each map a new image: a host's or a picture's may be another build's too.
func _warp_maps(made: Dictionary, times: Array) -> void:
	var old_t: PackedFloat32Array = times[0]
	var new_t: PackedFloat32Array = times[1]
	var was := float(times[2])
	var now := float(times[3])
	var share := func(u: float) -> float: return _warp_t(u * was, old_t, new_t) / now
	# (...the shares through a table of them: a picture's map is a few hundred thousand points)
	var lut := PackedFloat32Array()
	lut.resize(WARP_LUT + 1)
	for i in WARP_LUT + 1:
		lut[i] = share.call(float(i) / float(WARP_LUT))
	if made.get("when") is Image:
		made["when"] = _warped_map(made["when"], lut, [0, 2], share)
		made["when_tex"] = ImageTexture.create_from_image(made["when"])
	if made.get("built_when") is Array and (made["built_when"] as Array).size() == 2:
		var bw: Array = []
		for img in made["built_when"]:
			bw.append(_warped_map(img, lut, [0, 1, 2, 3], share))
		made["built_when"] = bw
		made["built_when_tex"] = [ImageTexture.create_from_image(bw[0]), ImageTexture.create_from_image(bw[1])]
	if made.get("touches") is Array:
		var touches: Array = []
		for tc in made["touches"]:
			var d: Dictionary = (tc as Dictionary).duplicate()
			d["u"] = share.call(float(d["u"]))
			touches.append(d)
		made["touches"] = touches


## Map [param img] with each moment in its channels [param chans] mapped through [param lut] (shares 0-1; just past 1, by [param share]
## itself; anything else - never - left), as a new image in floats.
func _warped_map(img: Image, lut: PackedFloat32Array, chans: Array, share: Callable) -> Image:
	var fmt := img.get_format()
	var to: int = {Image.FORMAT_RH: Image.FORMAT_RF, Image.FORMAT_RGH: Image.FORMAT_RGF, Image.FORMAT_RGBH: Image.FORMAT_RGBF,
		Image.FORMAT_RGBAH: Image.FORMAT_RGBAF}.get(fmt, fmt)
	var per: int = {Image.FORMAT_RF: 1, Image.FORMAT_RGF: 2, Image.FORMAT_RGBF: 3, Image.FORMAT_RGBAF: 4}.get(to, 0)
	if per == 0:
		return img
	var im := img.duplicate() as Image
	if to != fmt:
		im.convert(to)
	var v := im.get_data().to_float32_array()
	var last := lut.size() - 1
	for c in chans:
		if int(c) >= per:
			continue
		var i := int(c)
		var row := 0
		while i < v.size():
			var u := v[i]
			if u >= 0.0 and u <= 1.0:
				v[i] = lut[int(u * float(last) + 0.5)]
			elif u > 1.0 and u < 2.0:
				v[i] = share.call(u)
			i += per
			row += 1
			if row % 65536 == 0:
				_breathe()
	return Image.create_from_data(im.get_width(), im.get_height(), im.has_mipmaps(), to, v.to_byte_array())


## THE WATER A TOOL IS RINSED IN, at [param tau] into paint track [param tr]'s act of [param d] seconds, from [param from] (as it was
## as the act began), [param water_ml] of it: toward the color each rinse takes out of the tool and clouded by it, by how much paint
## that is in that much water ([constant TINTS], [constant CLOUDS]), as it is swished there - a pure function of time. Its alpha is
## how clear it is left (1 clean; prop_liquid.gdshaderinc's `murk` is the rest).
func cloud_at(tr: Dictionary, from: Color, tau: float, d: float, water_ml := WATER_ML) -> Color:
	var plan := plan_of(tr, d)
	var share := rinsed_ml(tools.get(String(tr.get("_ch", "")), {})) / maxf(water_ml, 1.0)
	var c := from
	for p in plan["phases"]:
		var pd: Dictionary = p
		if String(pd["kind"]) != "rinse" or String(pd.get("out", "")).is_empty() or tau <= float(pd["a"]):
			continue
		var w := clampf((tau - float(pd["a"])) / maxf(float(pd["b"]) - float(pd["a"]), 1e-4), 0.0, 1.0)
		c = clouded(c, Color.html(String(pd["out"])), share, Hands.smooth(clampf((w - 0.4) / 0.6, 0.0, 1.0)))
	return c


## WATER [param c] (its alpha how clear it is) with [param share] of its volume of [param paint] rinsed into it, [param into] of the
## way through the rinse: toward the paint's color, and clouded ([constant TINTS], [constant CLOUDS]).
static func clouded(c: Color, paint: Color, share: float, into := 1.0) -> Color:
	var rgb := Color(c.r, c.g, c.b).lerp(paint, (1.0 - exp(-TINTS * share)) * into)
	return Color(rgb.r, rgb.g, rgb.b, c.a * exp(-CLOUDS * share * into))


## THE PAINT A RINSE TAKES OUT OF TOOL [param tool] ([method tool_of]), milliliters: a brush's belly ([constant RINSED_BELLY] of its
## hairs' bulk), anything else's face ([constant RINSED_FILM] deep).
static func rinsed_ml(tool: Dictionary) -> float:
	var w := float(tool.get("mm", 6.0)) / 1000.0
	if String(tool.get("kind", "")) == "brush":
		return w * w * maxf(float(tool.get("len", 0.012)), 0.002) * RINSED_BELLY * 1e6
	return w * w * RINSED_FILM * 1e6


## Act [param act]'s track [param tr] at a hand's pace: [method plan_of]'s plan, its `natural` and the `work` of it its elements take.
func _unhurried(act: Dictionary, tr: Dictionary) -> Dictionary:
	tr["_act"] = String(act["name"])
	return plan_of(tr, 0.0)


## WHERE THE TOOL IS at [param tau] seconds into its act (of [param d]): its node in the table's space - fetched from
## [param from], over its work, and back where it rests ([method _home_of]). [param x0]: its node at rest.
func pose(e: Dictionary, tr: Dictionary, tau: float, d: float, T: float, from: Transform3D, x0: Transform3D) -> Transform3D:
	var plan := _plan_entry(e, tr, d)
	var tool := tool_of(String(tr["_ch"]), tr)
	var held: Variant = _held_at(plan, tr, tau, T, from, x0, _home_of(e, from))
	var x: Transform3D = held if held is Transform3D else _node_at(held as Array, tool, x0)
	return _kept_out(int(plan.get("si", -1)), tool, x, held, T)


## A GATE'S SWITCH: off, an act's moves and trips take a hand's fixed times, however far they go ([method _paced]). Never set by the show.
var paced := true


## A GATE'S SWITCH: off, a drawn pose is left as its plan places it ([method _kept_out]) - what a control shows the guard keeps from
## happening. Never set by the show.
var keep_out := true


## THE DRAWN TOOL STANDS IN NOTHING, WHATEVER ITS PLAN (feedback 0003, 2026-11-09, the user: "This brush is clipping straight through the
## nose here. This has happened a half dozen times already ... Why don't we have proper collision on the props and on the mask, so that it
## would not even be possible to clip through the nose like this?"): every pose a painting tool is drawn at - over its work, between two
## elements, on a trip, fetched or put back - is looked at against what stands over the surface it paints ([method _obstacles], the
## measure its clearance is found by), its handle and ferrule never in it, its hairs and a sponge no deeper than they give ([method
## _sunk_node]). One that is, is turned up about its tip, as little as clears it (at most [constant KEEP_TURN_MOST]), else lifted out
## along the surface's front. Each key had been held clear and the way between them looked at every few millimeters, and still the
## round brush's ferrule stood up to 21 mm in 732687's nose between them, on a move from one element to the next. The physics, which
## leaves a tool painting a surface where its law puts it ([method TablePhysics._painted_by]), draws this pose. [param held]: the hold it
## was placed from (an Array), or the node itself (fetched, put back, turned in the hand).
func _kept_out(si: int, tool: Dictionary, x: Transform3D, held: Variant, T: float) -> Transform3D:
	if not keep_out or si < 0 or si >= skins.size() or tool.is_empty() or (tool.get("points", PackedVector3Array()) as PackedVector3Array).is_empty():
		return x
	var sd: Dictionary = skins[si]
	if not sd.has("_rest"):
		return x
	var g := _obstacles(sd)
	var contact := _contact_of(held as Array) if held is Array else ""
	if contact.is_empty():
		contact = String(tool.get("contact", ""))
	var press := float((held as Array)[2]) if held is Array and (held as Array).size() > 2 else 0.0
	# (...in the skin's frame as it rests, where its field was found - carried with its holder as it is now)
	var rest: Transform3D = sd["_rest"]
	var to_rest := rest * holder_world(si, T).affine_inverse()
	var xr := to_rest * x
	if _sunk_exact(sd, g, tool, contact, xr, press, KEEP_OUT) <= KEEP_OUT:
		return x
	var out := ((rest * (sd["xform"] as Transform3D)).basis * Vector3.BACK).normalized()
	var c := _contact(tool, contact)
	var tip := xr * (c["tip"] as Vector3)
	var along := (xr.basis * ((c["grip"] as Vector3) - (c["tip"] as Vector3))).normalized()
	var spin := along.cross(out)
	# ...TURNED UP ABOUT ITS TIP toward the surface's front, as little as clears it
	if spin.length() > 0.05:
		spin = spin.normalized()
		var most := minf(deg_to_rad(KEEP_TURN_MOST), along.angle_to(out))
		var turned := func(a: float) -> Transform3D:
			var r := Basis(spin, a)
			return Transform3D(r * xr.basis, tip + r * (xr.origin - tip))
		if _sunk_exact(sd, g, tool, contact, turned.call(most), press, KEEP_OUT) <= KEEP_OUT:
			var lo := 0.0
			var hi := most
			for it in KEEP_HALVINGS:
				var mid := (lo + hi) * 0.5
				if _sunk_exact(sd, g, tool, contact, turned.call(mid), press, KEEP_OUT) <= KEEP_OUT:
					hi = mid
				else:
					lo = mid
			return to_rest.affine_inverse() * (turned.call(hi) as Transform3D)
		xr = turned.call(most)
	# ...ELSE LIFTED OUT along its front until it is clear (read across a slope, a depth is at most SLOPE_MOST times shallower)
	for it in KEEP_LIFTS:
		var dd := _sunk_exact(sd, g, tool, contact, xr, press, INF)
		if dd <= KEEP_OUT:
			break
		xr = Transform3D(xr.basis, xr.origin + out * (dd * SLOPE_MOST + KEEP_OUT))
	return to_rest.affine_inverse() * xr


## WHERE ENTRY [param e]'s ACT PUTS ITS TOOL BACK: where it was as the act began ([param from]) - or, begun with it still in hand from the
## act straight before (`_loaded`, [method _one_after_another]), where THAT act took it from (feedback 0004, 2026-11-09: "Why is there a
## brush floating near the eye, while we are simultaneously using a second brush, dipping it in the yellow foundation?"). Put back where
## the act found it, 732687's round brush, kept in hand from one act into the next, was set down in the air over the eye where the first
## had left it, and every act of it after went back there while the other brushes worked.
func _home_of(e: Dictionary, from: Transform3D) -> Transform3D:
	var tr: Dictionary = e["track"]
	if not tr.has("_loaded"):
		return from
	# (...the entry before it on its channel, by when it begins - never by which copy of the entry this is: the physics holds a tool by a
	# copy, its `from` where the body was ([method TablePhysics._held_pose]), and a copy matched no entry, so the hand that moves the
	# body still set 732687's round brush down over the eye - the plan's hand back in the tray, the brush itself 39 cm short of it while
	# the liner worked. Laid down in order, the last before it is also the one while this one's own end is still being worked out.)
	var before: Dictionary = {}
	for o in work._chan.get(String(tr.get("_ch", "")), []):
		if float((o as Dictionary)["t0"]) >= float(e["t0"]) - 1e-6:
			break
		before = o
	if before.is_empty() or not bool((before["track"] as Dictionary).get("_keep", false)) or not (before.get("from") is Transform3D):
		return from
	return _home_of(before, before["from"])


## The plan of entry [param e], made once for its length.
func _plan_entry(e: Dictionary, tr: Dictionary, d: float) -> Dictionary:
	var got: Variant = e.get("_paint")
	if got is Dictionary and absf(float((got as Dictionary)["d"]) - d) < 1e-4:
		return got
	var plan := plan_of(tr, d)
	e["_paint"] = plan
	return plan


## WHERE THE TIP IS AND WHICH WAY THE TOOL POINTS at [param tau] into [param plan] - a hold, `[tip, axis, pressed (0-1), on the
## surface, how far over a pot it comes in, the way it is held ([method _contact])]` (the table's space) - or, fetched, put back or
## turned in the hand from one way of holding it to another, the node's own place (a Transform3D). [param home]: where it is put back
## ([method _home_of]).
func _held_at(plan: Dictionary, tr: Dictionary, tau: float, T: float, from: Transform3D, x0: Transform3D, home: Transform3D) -> Variant:
	var phases: Array = plan["phases"]
	if phases.is_empty():
		return from
	var si := int(plan["si"])
	var i := phases.size() - 1
	for k in phases.size():
		if tau <= float((phases[k] as Dictionary)["b"]):
			i = k
			break
	var ph: Dictionary = phases[i]
	var len := maxf(float(ph["b"]) - float(ph["a"]), 1e-4)
	var s := clampf((tau - float(ph["a"])) / len, 0.0, 1.0)
	var tool := tool_of(String(tr["_ch"]), tr)
	var seed := int(tr.get("_hand", 0))
	match String(ph["kind"]):
		"fetch", "back", "still":
			# FROM WHERE IT RESTS to its first place, and back - as a carry goes, the tip arcing, the tool turning on its way
			var a := from
			var b := _node_at(_end_of(plan, tr, T, 0), tool, x0)
			if String(ph["kind"]) != "fetch":
				if String(ph["kind"]) == "still":
					# (held where it is, kept in hand for the act straight after - else back where it rests)
					return _node_at(_end_of(plan, tr, T, i - 1), tool, x0) if bool(tr.get("_keep", false)) and i > 0 else home
				a = _node_at(_end_of(plan, tr, T, i - 1), tool, x0)
				b = home
			var tip_l: Vector3 = tool["tip"]
			var pa := a * tip_l
			var pb := b * tip_l
			var lin := Hands.timing(s)
			var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, maxf(FETCH_LIFT, _lift_over(pa, pb, seed, _reach_of(tool))), s, seed)
			var rb := Basis(Quaternion(a.basis.orthonormalized()).slerp(Quaternion(b.basis.orthonormalized()), lin))
			var basis := rb.scaled(a.basis.get_scale())
			return Transform3D(basis, p - basis * tip_l)
		"load", "rinse", "dry":
			# TO ITS PAINT, THE WATER OR THE TOWEL, from wherever it last was, and there - it leaves in what comes next
			# (...a flat brush leaned across its broadside as it comes rolled from there - [method _laid_hold])
			var came := _end_of(plan, tr, T, i - 1)
			return _trip(came, _trip_hold(ph, T, tr, came), s, seed + i * 7919, String(ph["kind"]), tool, float(ph["b"]) - float(ph["a"]))
		"move":
			return _between(_end_of(plan, tr, T, i - 1), _hold_of(_surface_hold(si, ph["prog"], 0.0, T, tr), tool), s, seed, tool)
		"rest":
			var prog: Dictionary = ph["prog"]
			var h := _hold_of(_surface_hold(si, prog, float(prog["natural"]), T, tr), tool)
			h[0] = (h[0] as Vector3) + (Hands.drift(T, seed, 1.0)[0] as Vector3)
			return h
		"el":
			var prog2: Dictionary = ph["prog"]
			return _surface_hold(si, prog2, s * float(prog2["natural"]), T, tr)
	return from


## Where phase [param i] of [param plan] leaves the tool: an element's end over the surface, over the pot, cup or towel a trip went
## to, or - before anything - where the first phase after the fetch begins.
func _end_of(plan: Dictionary, tr: Dictionary, T: float, i: int) -> Array:
	var phases: Array = plan["phases"]
	var tool := _tool_or_none(tr)
	if i <= 0:
		for k in range(1, phases.size()):
			var pd: Dictionary = phases[k]
			if String(pd["kind"]) in TRIPS:
				return _lifted(_trip_hold(pd, T, tr))
			if pd.has("prog"):
				return _hold_of(_surface_hold(int(plan["si"]), pd["prog"], 0.0, T, tr), tool)
		return [Vector3.ZERO, Vector3.UP, 0.0, false]
	var ph: Dictionary = phases[mini(i, phases.size() - 1)]
	if String(ph["kind"]) in TRIPS:
		# (...rolled as the tool was where it came from, as the trip itself kept it - a flat brush never turned back at its end)
		var came := _end_of(plan, tr, T, i - 1)
		return _lifted(_trip_hold(ph, T, tr, came), came, tool)
	if String(ph["kind"]) == "move":
		return _hold_of(_surface_hold(int(plan["si"]), ph["prog"], 0.0, T, tr), tool)
	if ph.has("prog"):
		return _hold_of(_surface_hold(int(plan["si"]), ph["prog"], float((ph["prog"] as Dictionary)["natural"]), T, tr), tool)
	return _end_of(plan, tr, T, i - 1)


## The node's place for a hold [param h] ([tip, axis], held its way) - turned from where it rests as [method pose] turns it.
func _node_at(h: Array, tool: Dictionary, x0: Transform3D) -> Transform3D:
	var c := _contact(tool, _contact_of(h))
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var v0 := (x0.basis * (grip_l - tip_l)).normalized()
	var A: Vector3 = (h[1] as Vector3).normalized()
	var r := Basis(Quaternion(v0, A)) if v0.dot(A) > -0.999 else Basis(Vector3.RIGHT, PI)
	# A FLAT BRUSH TURNED TO ITS STROKE (feedback 0031: "all of the ways a person can turn a brush, to the fat side for wide strokes, to the
	# corner for fine strokes"): laying a fill, broadside across the way it goes; drawing a line, on its edge along it - WHICHEVER WAY ROUND
	# IT WAS AT THE KEY BEFORE, its way kept in sign along the program ([method _dirs_of]; feedback 0016: "They wouldn't just flip-flop back
	# and forth"). Chosen against how it would be held with no turn - its rest turned onto the handle's lean - the choice had flipped as
	# that lean swung from stroke to stroke, and rolled the flat over half a turn between two keys.
	if tool.has("across") and h.size() > 8 and (h[8] as Vector3).length_squared() > 0.5:
		var goes: Vector3 = h[8]
		var n_s: Vector3 = h[7]
		var want: Vector3 = n_s.cross(goes) if _contact_of(h) == "belly" else goes
		want -= A * want.dot(A)
		if want.length_squared() > 1e-8:
			want = want.normalized()
			var u0 := x0.basis * (tool["across"] as Vector3)
			u0 = (u0 - v0 * u0.dot(v0)).normalized()
			var from := Basis(v0, u0, v0.cross(u0))
			var to := Basis(A, want, A.cross(want))
			r = to * from.inverse()
	return Transform3D(r, (h[0] as Vector3) - r * (x0 * tip_l)) * x0


## [param v] as a hold: a node's place ([method _held_at]) as the tip and axis of tool [param tool]'s own way of holding it.
static func _hold_of(v: Variant, tool: Dictionary) -> Array:
	if v is Array:
		return v
	var x: Transform3D = v
	var c := _contact(tool, "")
	return [x * (c["tip"] as Vector3), (x.basis * ((c["grip"] as Vector3) - (c["tip"] as Vector3))).normalized(), 0.0, false, TRIP_LIFT, ""]


## Paint track [param tr]'s tool, or none (a puff of powder placed with no tool).
func _tool_or_none(tr: Dictionary) -> Dictionary:
	var ch := String(tr.get("_ch", ""))
	return {} if ch.is_empty() else tool_of(ch, tr)


## The way hold [param h] holds tool [param tool], named: its own, or the tool's.
static func _way(tool: Dictionary, h: Array) -> String:
	var n := _contact_of(h)
	return n if not n.is_empty() else String(tool.get("contact", ""))


## The hold over trip [param ph]'s pot, cup or towel - a load on the side its element's first dab is pressed with - coming from [param near].
func _trip_hold(ph: Dictionary, T: float, tr: Dictionary, near: Array = []) -> Array:
	return _pot_hold(String(ph["kind"]), String(ph.get("from", "")), String(ph.get("paint", "")), T, tr, String(ph.get("side", "")), near)


## The side program [param prog]'s next dab after key [param k] is pressed with (`way_at`, by its place - a program laid from the picture,
## [method _from_picture]), or "" - what a trip back to the pot loads.
static func _side_after(prog: Dictionary, k: int) -> String:
	var at: Dictionary = prog.get("way_at", {})
	if at.is_empty():
		return ""
	var keys: Array = prog["keys"]
	for j in range(k + 1, keys.size()):
		var kk: Array = keys[j]
		if int(kk[5]) == 0 and float(kk[4]) > 0.0:
			var w := int(at.get(Vector2(float(kk[1]), float(kk[2])), 0))
			return String(WAYS[w]) if w > 0 else ""
	return ""


## A hold [param h] lifted clear over where it is (a trip's place, left upward - over its rim) - rolled as it was there, else as tool
## [param tool] was at [param near] ([method _way_from]).
func _lifted(h: Array, near: Array = [], tool: Dictionary = {}) -> Array:
	var rise := float(h[4]) if h.size() > 4 else TRIP_LIFT
	# (...a hold that says its own way keeps it, turned end for end to the way it came from - a brush laid broadside, [method _laid_hold])
	if _says_way(h):
		return _way_from([(h[0] as Vector3) + Vector3.UP * rise, h[1], 0.0, false, rise, _contact_of(h), NAN, Vector3.ZERO, h[8]],
			near if near.size() > 8 else h, tool) as Array
	return _way_from([(h[0] as Vector3) + Vector3.UP * rise, h[1], 0.0, false, rise, _contact_of(h)], h if h.size() > 8 else near, tool) as Array


## HOLD [param h] ROLLED AS TOOL [param tool] WAS AT [param near] (`h[8]`, the table's space - [method _node_at]), so a flat brush on a trip
## to its pot, the water or the towel and back stays rolled as it was: with no way there, its untouched roll, it turned up to half a turn
## going and coming back. Its broadside as it lay at [param near], tilted with the handle as the hand turns it there - never twisted:
## the stroke's own way given at the pot, its handle 60-70 degrees steeper than laid on its belly over 732687's mask, still left it 20 to
## 66 degrees off. With no tool, or none with a broadside, [param near]'s own way. Made as long as [method _skin_hold] makes one where it
## is shorter (6 none, 7 no normal); a Transform3D, or a hold [param near] gives no way to, as it was.
func _way_from(h: Variant, near: Array, tool: Dictionary = {}) -> Variant:
	if not (h is Array) or near.size() <= 8 or not (near[8] is Vector3) or (near[8] as Vector3).length_squared() < 0.5:
		return h
	var way: Vector3 = near[8]
	if tool.has("across") and tool.has("x0") and (h as Array).size() > 1:
		var across := (_node_at(near, tool, tool["x0"]).basis * (tool["across"] as Vector3)).normalized()
		var an := (near[1] as Vector3).normalized()
		var ah := ((h as Array)[1] as Vector3).normalized()
		way = Basis(Quaternion(an, ah)) * across if an.dot(ah) > -0.999 else across
	# (...laid on its belly there, broadside across the way it went, it stays broadside held by its tip: across that way - [method _node_at])
	elif _contact_of(near) == "belly" and _contact_of(h as Array) != "belly" and near.size() > 7 and near[7] is Vector3 and (near[7] as Vector3).length_squared() > 0.5:
		way = (near[7] as Vector3).cross(way)
	var out: Array = (h as Array).duplicate()
	while out.size() < 8:
		match out.size():
			4:
				out.append(TRIP_LIFT)
			5:
				out.append("")
			6:
				out.append(NAN)
			_:
				out.append(Vector3.ZERO)
	if out.size() == 8:
		out.append(way)
	elif _says_way(out):
		# (...A HOLD THAT SAYS ITS OWN WAY KEEPS IT - a brush laid broadside on its paint, [method _laid_hold] - turned end for end to the
		# nearer of the two, so a flat brush is never rolled more than a quarter turn to it)
		out[8] = (out[8] as Vector3) * (-1.0 if (out[8] as Vector3).dot(way) < 0.0 else 1.0)
	else:
		out[8] = way
	return out


## WHERE THE TOOL IS at [param tau] (seconds, a hand's own pace) into program [param prog] on skin [param si]: a hold (the table's
## space), or - turned in the hand, on a trip to its paint or from its face to its corner - its node's place. [param making]: the holds
## being found for it ([method _held_keys]), in place of its skin's.
func _surface_hold(si: int, prog: Dictionary, tau: float, T: float, tr: Dictionary, making: Dictionary = {}) -> Variant:
	var keys: Array = prog["keys"]
	if keys.is_empty():
		return [Vector3.ZERO, Vector3.UP, 0.0, true]
	var tool := _tool_or_none(tr)
	var contact := _contact_for(tool, String(prog.get("manner", ""))) if not tool.is_empty() else ""
	# the key it is past (they are in order of time)
	var lo := 0
	var hi := keys.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float((keys[mid] as Array)[0]) <= tau:
			lo = mid
		else:
			hi = mid - 1
	var k := lo
	var kb := mini(k + 1, keys.size() - 1)
	var a: Array = keys[k]
	var b: Array = keys[kb]
	var span := float(b[0]) - float(a[0])
	var s := clampf((tau - float(a[0])) / span, 0.0, 1.0) if span > 1e-5 else 1.0
	var at_a := int(a[5])
	var at_b := int(b[5])
	# HOW IT IS HELD AT EACH KEY, clear of the surface ([method _held_keys]; none found, as a hand holds it)
	var kept: Dictionary = making if not making.is_empty() else ((skins[si] as Dictionary).get("held", {}) as Dictionary).get(_held_key(prog, String(tr.get("_ch", "")), contact), {})
	var held: PackedVector4Array = kept.get("held", PackedVector4Array())
	var ways: PackedByteArray = kept.get("ways", PackedByteArray())
	var ha := held[k] if k < held.size() else Vector4.ZERO
	var hb := held[kb] if kb < held.size() else Vector4.ZERO
	var ca: String = WAYS[ways[k]] if k < ways.size() and ways[k] > 0 else contact
	var cb: String = WAYS[ways[kb]] if kb < ways.size() and ways[kb] > 0 else contact
	var arcs: PackedFloat32Array = kept.get("arcs", PackedFloat32Array())
	var arc := arcs[k] if k < arcs.size() and kb > k else 0.0
	if at_a == 3 or at_b == 3:
		# AIMED FROM A HAND'S LENGTH OFF (a spray): over what it sprays and up from it, pointed at it
		var xy3 := Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), Hands.smooth(s))
		return _spray_hold(si, xy3, float(a[3]) * 0.001, lerpf(float(a[4]), float(b[4]), s), T)
	if at_a in [1, 2] and at_b in [1, 2]:
		# A TRIP inside the element: to its paint (1) or its stones' dish (2), and back to where it goes on
		# (...each end the way its stroke goes, so a flat brush leaves and comes back rolled as it was - [method _node_at])
		var trip_dirs: PackedVector2Array = kept.get("dirs", PackedVector2Array())
		var near := _skin_hold(si, Vector2(float(a[1]), float(a[2])), float(a[3]), 0.0, T, tool, ca, ha, ha, 0.0,
			trip_dirs[k] if k < trip_dirs.size() else Vector2.ZERO)
		var next := _skin_hold(si, Vector2(float(b[1]), float(b[2])), float(b[3]), 0.0, T, tool, cb, hb, hb, 0.0,
			trip_dirs[kb] if kb < trip_dirs.size() else Vector2.ZERO)
		# ...TO THE PAINT IT WAS LOADED FROM (feedback 0010, 2026-11-09: "Why does the sponge keep pressing into the corner of the brush box
		# here, squishing itself?"): a track naming no `from` was sent with no paint, and went to the spot by the work kept for none - 12 cm
		# right of a mask, the corner of 732687's brush tray - every time it ran dry, never to the white pot it began from
		var pot := _pot_hold("load" if at_a == 1 else "pick", String(tr.get("from", "")), String(prog.get("pot", "")) if at_a == 1 else "", T, tr, _side_after(prog, k), near)
		# (...its way back to the work as large a share of the trip as its length needs - its program's trip is the painter's, three and a
		# half seconds wherever the pot stands - and its way out told how long it has, [method _trip])
		var trip_s := maxf(float(b[0]) - float(a[0]), 0.1)
		var back := clampf((pot[0] as Vector3).distance_to(next[0] as Vector3) / (TRIP_PACE * trip_s), 0.3, 0.5)
		var there := 1.0 - back
		if s < there:
			return _trip(near, pot, s / there, int(tr.get("_hand", 0)) + k * 7919, "load", tool, trip_s * there)
		return _between(_lifted(pot, near, tool), next, (s - there) / back, int(tr.get("_hand", 0)), tool)
	# down and up are eased as a hand eases them; along a stroke it goes steadily
	var e := Hands.smooth(s) if float(a[4]) != float(b[4]) or float(a[3]) != float(b[3]) else s
	var xy := Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), e if float(a[4]) != float(b[4]) else s)
	var lift := lerpf(float(a[3]), float(b[3]), e) + arc * 1000.0 * sin(PI * s)
	var press := lerpf(float(a[4]), float(b[4]), e)
	# ...going the way the stroke goes there ([method _held_keys]' `dirs`), for a flat brush turned to it ([method _node_at])
	var dirs: PackedVector2Array = kept.get("dirs", PackedVector2Array())
	var dir := Vector2.ZERO
	if k < dirs.size() and kb < dirs.size():
		# (...never snapped over halfway between two keys: the ways are kept in sign along the program, a quarter turn apart at most)
		dir = dirs[k].lerp(dirs[kb], s)
	if ca == cb:
		return _skin_hold(si, xy, lift, press, T, tool, ca, ha, hb, e, dir)
	# ...TURNED IN THE HAND between two keys held two ways (its face, then its corner): from the one to the other where it is, eased
	# off the surface as it turns
	var x0: Transform3D = tool["x0"]
	var na := _node_at(_skin_hold(si, xy, lift, 0.0, T, tool, ca, ha, ha, 0.0), tool, x0)
	var nb := _node_at(_skin_hold(si, xy, lift, 0.0, T, tool, cb, hb, hb, 0.0), tool, x0)
	var w := Hands.smooth(s)
	var turned := Basis(Quaternion(na.basis.orthonormalized()).slerp(Quaternion(nb.basis.orthonormalized()), w)).scaled(na.basis.get_scale())
	return Transform3D(turned, na.origin.lerp(nb.origin, w))


## THE TOOL OVER (x, y) millimeters of skin [param si], lifted [param lift] millimeters, pressed [param press], held [param contact]:
## pointing as it is held clear at the keys either side ([param ha], [param hb] - each its axis in the holder's space and how far it
## must stand off, `e` of the way between), else as a hand holds it there ([method _held_axis]). A brush's hairs are pressed in
## along the surface; a sponge is pushed in along the way it points, and gives back to the surface ([method _tick_tool]).
func _skin_hold(si: int, xy: Vector2, lift: float, press: float, T: float, tool: Dictionary, contact: String, ha := Vector4.ZERO,
		hb := Vector4.ZERO, e := 0.0, dir := Vector2.ZERO) -> Array:
	var on := at_mm(si, xy)
	var hw := holder_world(si, T)
	var p: Vector3 = hw * (on[0] as Vector3)
	var n: Vector3 = (hw.basis * (on[1] as Vector3)).normalized()
	var ca := Vector3(ha.x, ha.y, ha.z)
	var cb := Vector3(hb.x, hb.y, hb.z)
	var axis_l: Vector3
	var off := 0.0
	if ca.length_squared() > 0.5:
		var both := cb.length_squared() > 0.5
		axis_l = ca.slerp(cb, e) if both and ca.dot(cb) > -0.99 else ca
		off = lerpf(ha.w, hb.w if both else ha.w, e)
	else:
		axis_l = _held_axis(si, xy, on[1], tool, contact)
	var axis := (hw.basis * axis_l).normalized()
	var give := float(_contact(tool, contact).get("give", 0.0)) * press if not tool.is_empty() else 0.0
	var into := n * give if String(tool.get("kind", "")) != "sponge" else axis * give
	# (...and the way the surface faces there, after the floor a trip's hold has - [method _tick_tool] folds a brush's hairs along it - and the
	# way the stroke goes along it, the table's space: [param dir] millimeters across and down the skin's front)
	var goes := Vector3.ZERO
	if dir.length_squared() > 1e-6:
		var xf: Transform3D = (skins[si] as Dictionary)["xform"]
		var g := hw.basis * (xf.basis * Vector3(dir.x, -dir.y, 0.0))
		g -= n * g.dot(n)
		goes = g.normalized() if g.length_squared() > 1e-10 else Vector3.ZERO
	return [p + n * (TOUCH + lift * 0.001) + axis * off - into, axis, press, true, TRIP_LIFT, contact, NAN, n, goes]


## HOW A HAND HOLDS TOOL [param tool] by [param contact] at (x, y) millimeters of skin [param si], whose surface faces [param n] there
## (the holder's space): a brush's handle out of the surface, up along it and out to the side its work is on - drawn along the surface
## [param pull] (millimeters across and down the skin's front, unit), leaning the way it goes ([constant HELD_PULL]); a sponge's corner
## nearer upright ([constant CORNER_HELD]); a face flat on it.
func _held_axis(si: int, xy: Vector2, n: Vector3, tool: Dictionary, contact: String, pull := Vector2.ZERO) -> Vector3:
	if contact == "face":
		# ...FLAT ON WHAT IS UNDER ALL OF IT, never on the one point it is over (under a nose, the surface faces down)
		var r := float(tool.get("mm", 20.0)) * 0.6
		var sum := n.normalized()
		for k in 12:
			var ph := TAU * float(k) / 12.0
			sum += _normal_mm(si, xy + Vector2(cos(ph), sin(ph)) * r * (0.5 if k % 2 == 0 else 1.0))
		return sum.normalized()
	var sd: Dictionary = skins[si]
	var frame: Vector2 = sd["frame"]
	var xf: Transform3D = sd["xform"]
	var right := (xf.basis * Vector3.RIGHT).normalized()
	var up := (xf.basis * Vector3.UP).normalized()
	var side := clampf((xy.x - frame.x * 0.5) / maxf(frame.x * HELD_SIDE_EDGE, 1e-3), -1.0, 1.0)
	if contact == "corner":
		return (n * CORNER_HELD.x + up * CORNER_HELD.y + right * side * CORNER_HELD.z).normalized()
	if TILTS.has(contact):
		# (...tipped a little, its hand leaning as little: that share of a corner's lean)
		var lean := float(_contact(tool, contact).get("lean", 0.0))
		return (n * CORNER_HELD.x + (up * CORNER_HELD.y + right * side * CORNER_HELD.z) * lean).normalized()
	if pull.length_squared() > 0.5 and String(tool.get("kind", "")) == "brush":
		var nn := n.normalized()
		var goes := xf.basis * Vector3(pull.x, -pull.y, 0.0)
		goes -= nn * goes.dot(nn)
		var up_on := up - nn * up.dot(nn)
		if goes.length_squared() > 1e-10:
			goes = goes.normalized()
			var toward := maxf(-goes.dot(up_on.normalized()), 0.0) if up_on.length_squared() > 1e-10 else 0.0
			if contact == "belly":
				return (nn * HELD_LOW + goes * HELD_PULL).normalized()
			return (nn * HELD_OUT + goes * HELD_PULL * (1.0 - PULL_TOWARD * toward)).normalized()
	if contact == "belly":
		return (n * HELD_LOW + up * HELD_UP + right * side * HELD_SIDE).normalized()
	return (n * HELD_OUT + up * HELD_UP + right * side * HELD_SIDE).normalized()


# --- held clear -----------------------------------------------------------------------------------------

## WHAT STANDS OVER SKIN [param sd] SEEN FROM ITS FRONT, found once: the highest surface of its whole thing - the surface itself and what
## holds it (a mask's board) - every [constant CLEAR_CELL], [constant CLEAR_BEYOND] past its frame all round, in its part's own frame
## (meters along its front, -INF where nothing is; between cells, read across, and over an edge the highest beside it - [method _sunk]):
## `{at: its first cell (the part's x, y), n: cells across and up, z, to_part: the table's space as the skin rests into its part's, top: the
## highest over each block of [constant CLEAR_BLOCK] cells and those beside it, bn: blocks across and up}`.
func _obstacles(sd: Dictionary) -> Dictionary:
	var got: Dictionary = sd.get("clear", {})
	if got.has("top"):
		return got
	var to_part := ((sd["_rest"] as Transform3D) * (sd["xform"] as Transform3D)).affine_inverse()
	var faces := PackedVector3Array()
	for m in (work.things[int(sd["ti"])] as Dictionary)["meshes"]:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := to_part * work._world_of(mi)
		for v in mi.mesh.get_faces():
			faces.append(xf * v)
	var box: AABB = sd["box"]
	var at := Vector2(box.position.x, box.position.y) - Vector2.ONE * CLEAR_BEYOND
	var n := Vector2i(ceili((box.size.x + CLEAR_BEYOND * 2.0) / CLEAR_CELL) + 1, ceili((box.size.y + CLEAR_BEYOND * 2.0) / CLEAR_CELL) + 1)
	var z := PackedFloat32Array()
	z.resize(n.x * n.y)
	z.fill(-INF)
	# (...and the surface itself, kept to read under a point where the cells are too coarse - [method _sunk_exact])
	var ray_mesh: TriangleMesh = null
	var ray_from := -INF
	if not faces.is_empty():
		var top := -INF
		for v in faces:
			top = maxf(top, v.z)
		var tm := TableWork._ray_mesh(faces)
		ray_mesh = tm
		ray_from = top + 0.01
		for j in n.y:
			_breathe()
			for i in n.x:
				var hit := TableWork._ray(tm, Vector3(at.x + float(i) * CLEAR_CELL, at.y + float(j) * CLEAR_CELL, top + 0.01), Vector3(0.0, 0.0, -1.0))
				if not hit.is_empty():
					z[j * n.x + i] = (hit["position"] as Vector3).z
	# ...and the highest of it over each block of cells and the cells beside it, for what stands well over it
	var bn := Vector2i(ceili(float(n.x) / CLEAR_BLOCK), ceili(float(n.y) / CLEAR_BLOCK))
	var top := PackedFloat32Array()
	top.resize(bn.x * bn.y)
	top.fill(-INF)
	for j in n.y:
		for i in n.x:
			var zk := z[j * n.x + i]
			if zk == -INF:
				continue
			for bj in range(maxi((j - 1) / CLEAR_BLOCK, 0), mini((j + 1) / CLEAR_BLOCK, bn.y - 1) + 1):
				for bi in range(maxi((i - 1) / CLEAR_BLOCK, 0), mini((i + 1) / CLEAR_BLOCK, bn.x - 1) + 1):
					top[bj * bn.x + bi] = maxf(top[bj * bn.x + bi], zk)
	var out := {"at": at, "n": n, "z": z, "to_part": to_part, "top": top, "bn": bn, "mesh": ray_mesh, "mesh_from": ray_from}
	sd["clear"] = out
	return out


## HOW DEEP TOOL [param tool], held [param contact] with its tip at [param p] pointing along [param a] (the table's space, the skin as
## it rests), stands in what stands over skin [param sd] ([method _obstacles] [param g]) past what that way of holding it lets it
## (meters; clear, none over 0) - its hairs bend, a sponge gives. Past [param stop], looked at no further.
func _sunk(sd: Dictionary, g: Dictionary, tool: Dictionary, contact: String, p: Vector3, a: Vector3, stop := INF) -> float:
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var x0: Transform3D = tool["x0"]
	var v0 := (x0.basis * (grip_l - tip_l)).normalized()
	var r := Basis(Quaternion(v0, a)) if v0.dot(a) > -0.999 else Basis(Vector3.RIGHT, PI)
	return _sunk_node(sd, g, tool, contact, Transform3D(r, p - r * (x0 * tip_l)) * x0, 1.0, stop)


## HOW DEEP TOOL [param tool], its node at [param x] (the table's space, the skin as it rests), stands in what stands over skin
## [param sd] ([method _obstacles] [param g]) past what holding it [param contact], pressed [param press], lets it ([method _sunk]).
func _sunk_node(sd: Dictionary, g: Dictionary, tool: Dictionary, contact: String, x: Transform3D, press: float, stop := INF, margin := 0.0) -> float:
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var M := (g["to_part"] as Transform3D) * x
	# ...AS DEEP AS IT GIVES BACK: each point as far as it is squashed from the tool's middle (the whole of a pressed face, a corner's
	# tip most - [method _tick_tool]), and near its tip as far as its hairs bend and its surface is found no finer than its cells - all
	# but A BRUSH'S HANDLE AND FERRULE, its first `stiff` points ([method tool_of]), which neither bend nor give
	var near := float(c["bend"]) + CLEAR_CELL
	var stiff := int(tool.get("stiff", 0))
	var give := float(c["give"]) * press
	var mid: Vector3 = tool.get("center", tip_l)
	var into := (tip_l - grip_l).normalized()
	var reach := float(c.get("reach", 0.01))
	# (what stands over it, read here inline: a few hundred points a way it is tried, dozens of ways a place)
	var at: Vector2 = g["at"]
	var n: Vector2i = g["n"]
	var Z: PackedFloat32Array = g["z"]
	var top: PackedFloat32Array = g["top"]
	var bn: Vector2i = g["bn"]
	var pts: PackedVector3Array = tool["points"]
	# (all of it placed at once; and a point over the highest of what is round it, never looked at closer)
	var qs: PackedVector3Array = M * pts
	var worst := -INF
	for idx in qs.size():
		var q := qs[idx]
		var fx := (q.x - at.x) / CLEAR_CELL
		var fy := (q.y - at.y) / CLEAR_CELL
		if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
			continue
		var i := mini(int(fx), n.x - 2)
		var j := mini(int(fy), n.y - 2)
		if q.z > top[(j / CLEAR_BLOCK) * bn.x + i / CLEAR_BLOCK] + margin:
			continue
		var s := pts[idx]
		var k := j * n.x + i
		var z00 := Z[k]
		var z10 := Z[k + 1]
		var z01 := Z[k + n.x]
		var z11 := Z[k + n.x + 1]
		var d := 0.0
		if z00 == -INF or z10 == -INF or z01 == -INF or z11 == -INF:
			d = maxf(maxf(z00, z10), maxf(z01, z11)) - q.z
			if is_inf(d):
				continue
		else:
			# ...ACROSS ITS SLOPE: how far under its surface's own plane there
			var u := fx - float(i)
			var v := fy - float(j)
			var gx := lerpf(z10 - z00, z11 - z01, v) / CLEAR_CELL
			var gy := lerpf(z01 - z00, z11 - z10, u) / CLEAR_CELL
			d = (lerpf(lerpf(z00, z10, u), lerpf(z01, z11, u), v) - q.z) / minf(sqrt(1.0 + gx * gx + gy * gy), SLOPE_MOST)
		d += margin
		if idx >= stiff:
			d -= give * clampf((s - mid).dot(into) / reach, 0.0, 1.0) + maxf(near - s.distance_to(tip_l), 0.0)
		if d > worst:
			worst = d
			if worst > stop:
				return worst
	return worst


## HOW DEEP TOOL [param tool]'s node at [param x] stands in what stands over skin [param sd], as [method _sunk_node] measures it - but
## each of its handle's and ferrule's points within [constant EXACT_BAND] of its cell's surface read off the surface itself, straight down
## under it: between two cells a nose's ridge reads low, and across its slope shallower still - a ferrule over 732687's nose, clear by the
## cells, stood 1.5 to 2.7 mm in it (feedback 0003). What a drawn pose is held to ([method _kept_out]).
func _sunk_exact(sd: Dictionary, g: Dictionary, tool: Dictionary, contact: String, x: Transform3D, press: float, stop := INF) -> float:
	var worst := _sunk_node(sd, g, tool, contact, x, press, stop)
	var tm: Variant = g.get("mesh")
	if worst > stop or not (tm is TriangleMesh):
		return worst
	var pts: PackedVector3Array = tool.get("stiff_dense", tool["points"])
	var stiff := pts.size() if tool.has("stiff_dense") else mini(int(tool.get("stiff", 0)), pts.size())
	var M := (g["to_part"] as Transform3D) * x
	var at: Vector2 = g["at"]
	var n: Vector2i = g["n"]
	var Z: PackedFloat32Array = g["z"]
	var from := float(g["mesh_from"])
	for idx in stiff:
		var q := M * pts[idx]
		var fx := (q.x - at.x) / CLEAR_CELL
		var fy := (q.y - at.y) / CLEAR_CELL
		if fx < 0.0 or fy < 0.0 or fx > float(n.x - 1) or fy > float(n.y - 1):
			continue
		var k := mini(int(fy), n.y - 2) * n.x + mini(int(fx), n.x - 2)
		if q.z > maxf(maxf(Z[k], Z[k + 1]), maxf(Z[k + n.x], Z[k + n.x + 1])) + EXACT_BAND:
			continue
		var hit := TableWork._ray(tm, Vector3(q.x, q.y, from), Vector3(0.0, 0.0, -1.0))
		if hit.is_empty():
			continue
		var d := (hit["position"] as Vector3).z - q.z
		if d > worst:
			worst = d
			if worst > stop:
				return worst
	return worst


## THE WAYS A TOOL IS TRIED, held [param contact], nearest [param want] first: round each of [param about] (the surface's normal where it
## touches, and the way the whole surface faces - at a mask's rim the one faces sideways, and a hand comes from the other), itself and
## [constant CLEAR_ROUND] ways round it at each of [constant CLEAR_TILTS].
static func _ways_round(about: Array, want: Vector3, contact: String) -> Array:
	var out: Array = []
	for a in about:
		var n := (a as Vector3).normalized()
		var e1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var e2 := n.cross(e1).normalized()
		out.append([n.angle_to(want), n])
		for tilt in CLEAR_TILTS:
			var tr := deg_to_rad(float(tilt))
			for k in CLEAR_ROUND:
				var ph := TAU * float(k) / float(CLEAR_ROUND)
				var ax := (n * cos(tr) + (e1 * cos(ph) + e2 * sin(ph)) * sin(tr)).normalized()
				out.append([ax.angle_to(want), ax])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return out


## HOW TOOL [param tool] IS HELD AT (x, y) millimeters OF SKIN [param si] by [param contact], its tip on the surface, its own surface
## in nothing: the way it points nearest how a hand holds it there ([method _held_axis]) - each other way it is tried costing its turn
## ([constant CLEAR_TURN]) and how far it must stand off the surface, back along itself, to be clear ([method _sunk]): resting on its
## edge beside a nose beats hovering flat a finger over it - `Vector4(axis (the holder's space), off (meters))`. Pressed in as far as
## it ever is; a brush drawn [param pull] leaning the way it goes.
func _cleared(si: int, xy: Vector2, tool: Dictionary, contact: String, pull := Vector2.ZERO) -> Vector4:
	var sd: Dictionary = skins[si]
	var g := _obstacles(sd)
	var on := at_mm(si, xy)
	var n_l: Vector3 = (on[1] as Vector3).normalized()
	var want := _held_axis(si, xy, n_l, tool, contact, pull)
	if tool.is_empty() or (tool.get("points", PackedVector3Array()) as PackedVector3Array).is_empty():
		return Vector4(want.x, want.y, want.z, 0.0)
	var hw: Transform3D = sd["_rest"]
	var n := (hw.basis * n_l).normalized()
	var base: Vector3 = hw * (on[0] as Vector3) + n * TOUCH
	var give := float(_contact(tool, contact)["give"])
	var sponge := String(tool["kind"]) == "sponge"
	var sunk := func(ax_l: Vector3, off: float, stop: float) -> float:
		var ax := (hw.basis * ax_l).normalized()
		return _sunk(sd, g, tool, contact, base + ax * off - (ax if sponge else n) * give, ax, stop)
	if float(sunk.call(want, 0.0, 0.0)) <= 0.0:
		return Vector4(want.x, want.y, want.z, 0.0)
	var front: Vector3 = (sd["surface"] as Dictionary)["front"]
	var best := want
	var cost := INF
	for w in _ways_round([n_l, front] if n_l.angle_to(front) > deg_to_rad(CLEAR_TILTS[0]) else [n_l], want, contact):
		var turn := float((w as Array)[0]) * CLEAR_TURN
		# (the rest are turned further: none of them can cost less)
		if turn >= cost:
			break
		var ax: Vector3 = (w as Array)[1]
		var rate := maxf(ax.dot(front), 0.3)
		var d := float(sunk.call(ax, 0.0, (cost - turn) * rate))
		if turn + maxf(d, 0.0) / rate < cost:
			cost = turn + maxf(d, 0.0) / rate
			best = ax
	# ...stood off back along itself until it is clear - A BRUSH NO FURTHER THAN ITS HAIRS GIVE: past that it painted in the air, a
	# liner 14 mm off a mask's brow at the top of each diamond (feedback 0019); its hairs bend against what it meets, as a painter's do
	var off := 0.0
	for it in 6:
		var d := float(sunk.call(best, off, INF))
		if d <= 0.0:
			break
		off += d / maxf(best.dot(front), 0.3) + 0.0003
	if String(tool["kind"]) == "brush":
		off = minf(off, BRUSH_STAND_MOST)
	return Vector4(best.x, best.y, best.z, off)


## How far from (x, y) millimeters [param xy] of skin [param si] the nearest of what tool [param tool] touches is, held [param way] clear as
## [param held] says ([method _cleared]) and pressed [param press] there (millimeters; INF where it touches nothing).
func _press_miss(si: int, xy: Vector2, tool: Dictionary, way: String, held: Vector4, press: float) -> float:
	var near := INF
	for q in _touched(si, tool, _skin_hold(si, xy, 0.0, press, 0.0, tool, way, held, held, 0.0)):
		near = minf(near, q.distance_to(xy))
	return near


## EACH KEY OF PROGRAM [param prog] on skin [param si] held clear ([method _cleared]) by tool [param tool] held [param contact], in
## order - a key where the one before it is, as that one; a spray's, none (it is held off the surface) - `{held: [Vector4 ...], ways:
## [1 where it is held by its corner instead], arcs: [how high it is lifted on its way to the next (meters, at the middle)]}`. A SPONGE SPREADING FLAT TURNS TO ITS CORNER where its face would stand off the surface
## more than [constant FLAT_MOST] and its corner costs less (beside a nose its face had hovered a finger off it).
func _held_keys(si: int, prog: Dictionary, tool: Dictionary, contact: String) -> Dictionary:
	var out := PackedVector4Array()
	var ways := PackedByteArray()
	var last_xy := Vector2.INF
	var last := Vector4.ZERO
	var last_way := 0
	var all_keys: Array = prog["keys"]
	# (a brush drawn along the surface leans the way it goes - [constant HELD_PULL])
	var pulls := _pulls_of(all_keys) if String(tool.get("kind", "")) == "brush" else PackedVector2Array()
	var last_pull := Vector2.INF
	for ki in all_keys.size():
		var kk: Array = all_keys[ki]
		_breathe()
		if int(kk[5]) == 3:
			out.append(Vector4.ZERO)
			ways.append(0)
			continue
		var xy := Vector2(float(kk[1]), float(kk[2]))
		var pull := pulls[ki] if ki < pulls.size() else Vector2.ZERO
		if xy != last_xy or pull != last_pull:
			# (how hard it presses here: the keys at this place, its way down and up among them)
			var hard := 0.0
			var kj := ki
			while kj < all_keys.size() and Vector2(float((all_keys[kj] as Array)[1]), float((all_keys[kj] as Array)[2])) == xy:
				hard = maxf(hard, float((all_keys[kj] as Array)[4]))
				kj += 1
			var hard_press := hard > PRESS_HARD - 0.01
			# (...held by the side it was laid with, where a program laid from the picture says - [method _from_picture])
			var chosen := int((prog.get("way_at", {}) as Dictionary).get(xy, 0))
			var mk := "%d|%s|%s|%s|%s|%s|%d" % [si, xy, contact, tool.get("ch", ""), hard_press, pull, chosen]
			if _clear_memo.has(mk):
				last = (_clear_memo[mk] as Array)[0]
				last_way = (_clear_memo[mk] as Array)[1]
			elif chosen > 0 and (tool.get("contacts", {}) as Dictionary).has(String(WAYS[chosen])):
				var sk := "%d|%s|%s|%s" % [si, tool.get("ch", ""), String(WAYS[chosen]), xy]
				last = _side_held[sk] if _side_held.has(sk) else _cleared(si, xy, tool, String(WAYS[chosen]))
				last_way = chosen
				# (...a face that would stand off a ridge - a nose - further than [constant FLAT_MOST] by its corner, where that costs less, as
				# a face held the tool's own way is below)
				if String(WAYS[chosen]) == "face" and last.w > FLAT_MOST and (tool.get("contacts", {}) as Dictionary).has("corner"):
					var by_corner := _cleared(si, xy, tool, "corner")
					if _held_cost(si, xy, tool, "corner", by_corner) < _held_cost(si, xy, tool, "face", last):
						last = by_corner
						last_way = 1
				_clear_memo[mk] = [last, last_way]
			else:
				last = _cleared(si, xy, tool, contact, pull)
				last_way = 0
				if contact == "face" and (String(tool.get("kind", "")) == "sponge" or bool(tool.get("flat", false))) and last.w > FLAT_MOST:
					var by_corner := _cleared(si, xy, tool, "corner")
					if _held_cost(si, xy, tool, "corner", by_corner) < _held_cost(si, xy, tool, contact, last):
						last = by_corner
						last_way = 1
				# ...A PRESS PUT IN WHERE THE FIRST MISSED, HELD THE WAY THAT REACHES IT, looked at before it is laid ([method _press_miss]):
				# by its long end into the crease beside a nose, as a pencil is held (feedback 0039: the corner, held off the nose by its body,
				# left it bare); flat under a chin (520084, 2026-11-07: the corner, come at it from above, met the chin 8 mm up its slope and
				# stood 1.4-6.5 mm off its underside - pressed five times as hard it got there, squashed 15 mm; flat, it reached it as pressed)
				if hard_press and String(tool.get("kind", "")) != "brush":
					var own: String = WAYS[last_way] if last_way > 0 else contact
					var miss := _press_miss(si, xy, tool, own, last, hard)
					# (only where its own way misses it: a puff's face that touches where it is aimed covers more of a gap than its corner)
					for w in (range(1, WAYS.size()) if miss > AIM_MET else []):
						var wn: String = WAYS[w]
						if wn == own or not (tool.get("contacts", {}) as Dictionary).has(wn):
							continue
						var by_way := _cleared(si, xy, tool, wn)
						var m := _press_miss(si, xy, tool, wn, by_way, hard)
						if m < miss - REACH_BETTER:
							miss = m
							last = by_way
							last_way = w
				_clear_memo[mk] = [last, last_way]
			last_xy = xy
			last_pull = pull
		out.append(last)
		ways.append(last_way)
	# ...AND LIFTED ON ITS WAY FROM ONE TO THE NEXT where it would go into the surface between them, as a hand lifts a tool between
	# presses: each stretch over the surface looked along ([constant ARC_STEP]) - a sponge's corner between two dabs either side of a
	# nose, turned from the one way to the other, went 18 mm into it with the 2.5 mm lift its program gives it
	var keys: Array = prog["keys"]
	var arcs := PackedFloat32Array()
	arcs.resize(keys.size())
	if tool.is_empty():
		return {"held": out, "ways": ways, "arcs": arcs, "dirs": _dirs_of(prog["keys"])}
	var sd: Dictionary = skins[si]
	var g := _obstacles(sd)
	var front: Vector3 = (sd["surface"] as Dictionary)["front"]
	var making := {"held": out, "ways": ways, "arcs": PackedFloat32Array()}
	var tr := {"_ch": String(tool.get("ch", "")), "_hand": 0}
	var x0: Transform3D = tool["x0"]
	for k in range(keys.size() - 1):
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		_breathe()
		if int(a[5]) != 0 or int(b[5]) != 0 or float(b[0]) - float(a[0]) < 1e-5:
			continue
		# (ALONG A STROKE, pressed the whole way - a line, a sweep's row - every pose is on the surface: lifted there it painted in the air,
		# a liner 11 mm and a flat brush 17 mm over a mask's rim; feedback 0019, 0021)
		if float(a[4]) > PRESSED and float(b[4]) > PRESSED:
			continue
		var xa := Vector2(float(a[1]), float(a[2]))
		var xb := Vector2(float(b[1]), float(b[2]))
		var turn := Vector3(out[k].x, out[k].y, out[k].z).angle_to(Vector3(out[k + 1].x, out[k + 1].y, out[k + 1].z))
		# (along a stroke, a step of a few millimeters and hardly turned: the keys either side are clear, and so is the way between)
		if xa.distance_to(xb) < ARC_STEP and turn < deg_to_rad(ARC_TURN) and ways[k] == ways[k + 1]:
			continue
		var ak := "%d|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d|%s" % [si, xa, xb, a[3], b[3], a[4], b[4], out[k], out[k + 1], ways[k], ways[k + 1], tool.get("ch", "")]
		if _arc_memo.has(ak):
			arcs[k] = float(_arc_memo[ak])
			continue
		var need := 0.0
		var looks := clampi(maxi(ceili(xa.distance_to(xb) / ARC_STEP), ceili(rad_to_deg(turn) / ARC_TURN)), 3, ARC_LOOKS)
		for fi in looks:
			var f := (float(fi) + 0.5) / float(looks)
			# (beside a key its own clearance holds it: the arc's lift there is next to nothing, and what it found divided by that had
			# lifted a sweep 155 mm)
			if f < ARC_ENDS or f > 1.0 - ARC_ENDS:
				continue
			# ...posed as it will be, but for the lift this finds
			var v: Variant = _surface_hold(si, prog, lerpf(float(a[0]), float(b[0]), f), 0.0, tr, making)
			var x: Transform3D = v if v is Transform3D else _node_at(v as Array, tool, x0)
			var way := _way(tool, v as Array) if v is Array else contact
			var press := float((v as Array)[2]) if v is Array else 0.0
			# ...and clear of it by a little, as a hand gives what it goes past room (read near a nose's steep side, its depth is a guess)
			var d := _sunk_node(sd, g, tool, way, x, press, INF, ARC_CLEAR * (1.0 - press))
			if d > 0.0:
				var n_l := (at_mm(si, xa.lerp(xb, f))[1] as Vector3).normalized()
				need = maxf(need, (d / maxf(n_l.dot(front), 0.3) + 0.0005) / sin(PI * f))
		arcs[k] = need
		_arc_memo[ak] = need
	return {"held": out, "ways": ways, "arcs": arcs, "dirs": _dirs_of(keys)}


## THE WAY PROGRAM [param keys]' TOOL GOES AT EACH KEY across the skin (millimeters, unit; none where it is never drawn along), which
## [method _node_at] turns a flat brush to - only a brush with an edge across reads it: the way its handle leans ([method _pulls_of]: a
## stretch's, held until the stroke needs another), lifted the way it was last pressed and then the way it is next pressed - never the
## way it travels in the air - and KEPT IN SIGN ALONG THE PROGRAM, its two edges alike (feedback 0016, 2026-11-09: "This brush is
## flipping and twirling and twisting and repositioning and it just looks chaotic ... They wouldn't just flip-flop back and forth"): a
## stroke drawn back the way the last came had rolled it over, half a turn between two keys, and its way in the air turned it twice more
## between strokes - 100 to 139 degrees a second, a stroke after a stroke, in 732687's intro, its body left up to 28.6 cm off its hand.
static func _dirs_of(keys: Array) -> PackedVector2Array:
	var out := _pulls_of(keys)
	# ...where it stands still, the way it last went, else the way it goes next
	for k in range(1, out.size()):
		if out[k] == Vector2.ZERO:
			out[k] = out[k - 1]
	for k in range(out.size() - 2, -1, -1):
		if out[k] == Vector2.ZERO:
			out[k] = out[k + 1]
	# ...and kept in sign along it: never more than a quarter turn from the key before
	for k in range(1, out.size()):
		if out[k].dot(out[k - 1]) < 0.0:
			out[k] = -out[k]
	return out


## ...THE WAY OF A STRETCH OF A STROKE, NEVER OF ONE STEP OF IT (feedback 0014, 2026-11-09: "This brush is jittering/jerking back and
## forth, at the top side, while the point remains perfectly still drawing lines ... a gentle hand painting lines would not be jerking
## around constantly like that"): 732687's traced line, keys 0.25 mm apart, wobbled 12 degrees either way every 2.5 mm, and the way of
## each key - its two steps - swung the 16 cm handle with it: its end 130 mm/s (to 930) where the point went 8.5, turning back 63 times
## in 9.5 s. So a key's way is its stroke's chord from [constant PULL_SPAN] millimeters behind it to as far ahead, a corner sharper than
## [constant PULL_CORNER] degrees still turned at; and the hand leans as it did until the way is [constant PULL_HOLD] degrees from it -
## following it no nearer along a stroke, turned to it whole only where a stroke begins past it (feedback 0016: "A real artist would
## prefer keep a neutral position, and only reposition when the stroke requires it").
const PULL_SPAN := 5.0
const PULL_CORNER := 60.0
const PULL_HOLD := 20.0


## THE WAY A BRUSH IS DRAWN AT EACH KEY OF [param keys] across the skin (millimeters, unit), for its handle to lean ([constant HELD_PULL]):
## pressed, the way its stroke goes there ([constant PULL_SPAN]; at a corner, between the two), held until it is [constant PULL_HOLD] off;
## lifted where it was last pressed, the way it went there - else the way it next goes, so it comes down already turned to its stroke.
## None for a dab, which goes nowhere.
static func _pulls_of(keys: Array) -> PackedVector2Array:
	var n := keys.size()
	var xy := PackedVector2Array()
	xy.resize(n)
	var pressed := PackedByteArray()
	pressed.resize(n)
	for k in n:
		var a: Array = keys[k]
		pressed[k] = 1 if float(a[4]) > PRESSED and int(a[5]) == 0 else 0
		xy[k] = Vector2(float(a[1]), float(a[2]))
	# THE LEGS: each pressed run, cut where one step turns from the last sharper than PULL_CORNER - that key the end of the one and the
	# start of the next
	var legs: Array = []
	var corner := PackedByteArray()
	corner.resize(n)
	var cos_c := cos(deg_to_rad(PULL_CORNER))
	var k0 := 0
	while k0 < n:
		if pressed[k0] == 0:
			k0 += 1
			continue
		var leg := PackedInt32Array([k0])
		var came := Vector2.ZERO
		var k := k0 + 1
		while k < n and pressed[k] == 1:
			var d := xy[k] - xy[k - 1]
			if d.length() > 0.05:
				var u := d.normalized()
				if came != Vector2.ZERO and came.dot(u) < cos_c:
					corner[k - 1] = 1
					legs.append(leg)
					leg = PackedInt32Array([k - 1])
				came = u
			leg.append(k)
			k += 1
		legs.append(leg)
		k0 = k
	# ...EACH KEY'S WAY, ITS LEG'S CHORD over PULL_SPAN either side (at a corner, the way in and the way out together)
	var raw := PackedVector2Array()
	raw.resize(n)
	var out_of := {}
	for lg in legs:
		var leg: PackedInt32Array = lg
		var m := leg.size()
		var s := PackedFloat32Array()
		s.resize(m)
		for j in range(1, m):
			s[j] = s[j - 1] + xy[leg[j]].distance_to(xy[leg[j - 1]])
		var jb := 0
		var ja := 0
		for j in m:
			var tb := maxf(s[j] - PULL_SPAN, 0.0)
			var ta := minf(s[j] + PULL_SPAN, s[m - 1])
			while jb < m - 1 and s[jb + 1] < tb:
				jb += 1
			while ja < m - 1 and s[ja + 1] < ta:
				ja += 1
			var pb := xy[leg[jb]].lerp(xy[leg[jb + 1]], (tb - s[jb]) / (s[jb + 1] - s[jb])) if jb < m - 1 and s[jb + 1] > s[jb] else xy[leg[jb]]
			var pa := xy[leg[ja]].lerp(xy[leg[ja + 1]], (ta - s[ja]) / (s[ja + 1] - s[ja])) if ja < m - 1 and s[ja + 1] > s[ja] else xy[leg[ja]]
			var w := (pa - pb).normalized() if pa.distance_to(pb) > 0.05 else Vector2.ZERO
			var kk := leg[j]
			if corner[kk] == 1:
				raw[kk] += w
				if j == 0:
					out_of[kk] = w
			else:
				raw[kk] = w
	for kk in out_of:
		raw[kk] = raw[kk].normalized() if raw[kk].length() > 0.1 else (out_of[kk] as Vector2)
	# ...AND HELD: leaning as it did until the way is PULL_HOLD from it - along a stroke following it no nearer, where one begins (or a
	# corner turns it) turned to it whole
	var out := PackedVector2Array()
	out.resize(n)
	var hold := deg_to_rad(PULL_HOLD)
	var held := Vector2.ZERO
	for k in n:
		if pressed[k] == 0 or raw[k] == Vector2.ZERO:
			continue
		var w := raw[k]
		var ang := held.angle_to(w) if held != Vector2.ZERO else 0.0
		if held == Vector2.ZERO or corner[k] == 1 or (k > 0 and corner[k - 1] == 1):
			held = w
		elif absf(ang) > hold:
			held = w if k == 0 or pressed[k - 1] == 0 else w.rotated(-signf(ang) * hold)
		out[k] = held
	# ...and lifted: where it was last pressed, as it was there; elsewhere as it is when it is next pressed
	var last_k := -1
	for k in n:
		if pressed[k] == 1:
			last_k = k
			continue
		if last_k >= 0 and xy[k].distance_to(xy[last_k]) < 0.05:
			out[k] = out[last_k]
			continue
		var next_k := k + 1
		while next_k < n and pressed[next_k] == 0:
			next_k += 1
		out[k] = out[next_k] if next_k < n else (out[last_k] if last_k >= 0 else Vector2.ZERO)
	return out


## What holding tool [param tool] by [param contact] as [param v] ([method _cleared]) at (x, y) of skin [param si] costs: how far it
## stands off, and how far it is turned from how a hand holds it there ([constant CLEAR_TURN]).
func _held_cost(si: int, xy: Vector2, tool: Dictionary, contact: String, v: Vector4) -> float:
	var want := _held_axis(si, xy, (at_mm(si, xy)[1] as Vector3).normalized(), tool, contact)
	return v.w + Vector3(v.x, v.y, v.z).angle_to(want) * CLEAR_TURN


## A TOOL AIMED AT (x, y) millimeters of skin [param si] from [param off] meters away: out from the surface, to its right and a little up
## along it - in the picture, never between the surface and the lens - pointed at the place, its tip toward it.
func _spray_hold(si: int, xy: Vector2, off: float, press: float, T: float) -> Array:
	var on := at_mm(si, xy)
	var hw := holder_world(si, T)
	var p: Vector3 = hw * (on[0] as Vector3)
	var n: Vector3 = (hw.basis * (on[1] as Vector3)).normalized()
	var xf: Transform3D = (skins[si] as Dictionary)["xform"]
	var up := (hw.basis * (xf.basis * Vector3.UP)).normalized()
	var right := (hw.basis * (xf.basis * Vector3.RIGHT)).normalized()
	var away := (n * SPRAY_FROM.x + right * SPRAY_FROM.y + up * SPRAY_FROM.z).normalized()
	return [p + away * off, away, press, false]


## OVER ITS PAINT (a load: its pot; a rinse: the water; a pick: the stones' dish), pressed in: `[tip, axis, 1, false, how far over
## it the tool comes in and leaves, the way it is held]` - a sponge by its corner (onto a towel, flat), its own surface inside the pot's
## mouth ([method _pot_clear]), lifted where it cannot be - a brush laid on what is under it, coming from [param near] ([method _laid_hold]).
func _pot_hold(kind: String, from: String, paint: String, T: float, tr: Dictionary, side := "", near: Array = []) -> Array:
	var name := String(tr.get(kind, "")) if kind in ["rinse", "dry"] else from
	var p := _source_of(kind, name, paint, T)
	var tool := _tool_or_none(tr)
	var contact := _contact_for(tool, "", kind) if not tool.is_empty() else ""
	# ...LOADED ON THE SIDE IT DABS WITH (the user, 2026-11-08: "The sponge is dabbed in the foundation container, via a single corner. Then we
	# proceed to tap the face with the flat side - which would not have picked-up any foundation at all"): its face pressed onto the paint for
	# the face's prints, a corner tapped for a corner's
	if kind == "load" and not side.is_empty() and (tool.get("contacts", {}) as Dictionary).has(side):
		# (...a face tipped onto its corner presses its face beside the corner: loaded by its face)
		contact = "face" if TILTS.has(side) and (tool.get("contacts", {}) as Dictionary).has("face") else side
	var axis := Vector3.UP if contact == "face" else (Vector3.UP * 0.9 + Vector3.BACK * 0.35).normalized()
	# ...COMING IN OVER ITS RIM: a cup's water lies well under it ([constant RIM_CLEAR])
	if name.is_empty() and kind == "load" and not paint.is_empty():
		var cr := _cream_near(paint)
		if not cr.is_empty() and int(cr.get("ti", -1)) >= 0:
			name = String((work.things[int(cr["ti"])] as Dictionary)["name"])
	var rise := TRIP_LIFT
	var mouth := {}
	if not name.is_empty() and not name.contains("."):
		mouth = work._mouth_of(name, T)
		if not mouth.is_empty():
			rise = maxf(rise, float((mouth["at"] as Vector3).y) + RIM_CLEAR - p.y)
	# ...A BRUSH LAID ON ITS PAINT, THE CUP'S FLOOR OR THE TOWEL, a share of its hairs on their side along it ([method _laid_hold])
	if kind in ["load", "rinse", "dry"]:
		var laid := _laid_hold(kind, name, tool, contact, p, rise, {} if kind == "dry" else mouth, T, near)
		if not laid.is_empty():
			return laid
	# ...AND ITS BODY INSIDE THE MOUTH as it is drawn, never through the wall - pressed flat on its paint, a load ([method _flat_lift])
	var floor_y := p.y - 0.001 if kind == "load" and not tool.is_empty() and _pressed_into(tool, contact) > 0.0 \
		and String(tool.get("kind", "")) != "brush" else NAN
	# ...OR, A FACE TOO BROAD FOR THE MOUTH, LAID OVER IT FLAT: resting on the rim either side, its middle pushed down into the paint as it
	# is pressed ([constant DRAPE_CLEAR], [method _drape_on]) - its hold's last, the mouth (`Vector4(x, rim, z, how wide inside its wall)`)
	if kind == "load" and contact == "face" and not is_nan(floor_y) and not mouth.is_empty() and _wider_than(tool, contact, float(mouth["r"]) - POT_WALL):
		var at: Vector3 = mouth["at"]
		return [Vector3(p.x, at.y + DRAPE_CLEAR, p.z), Vector3.UP, 1.0, false, TRIP_LIFT, contact, floor_y, Vector3.ZERO, Vector3.ZERO,
			Vector4(p.x, at.y, p.z, float(mouth["r"]) - POT_WALL)]
	var lifted := 0.0
	if not tool.is_empty() and not mouth.is_empty() and kind != "dry":
		var cl := _pot_clear(name, tool, contact, p, axis, mouth, floor_y)
		axis = cl["axis"]
		p += (cl["off"] as Vector3) + Vector3.UP * float(cl["lift"])
		rise = maxf(rise - float(cl["lift"]), TRIP_LIFT)
		lifted = float(cl["lift"])
	# ...A BRUSH ON ITS PAINT OR THE TOWEL, PRESSED ONTO IT AND KEPT ON IT (feedback 0017, [method _lay_on_plane]): how high the surface is
	# under it - the paint's own, under where it goes in, not its pot's box - and which way it faces; none where it had to be lifted
	# clear of the pot's wall, which pressing it down would go through
	if String(tool.get("kind", "")) == "brush" and kind in ["load", "dry"] and lifted <= 0.0:
		var level := p.y if kind == "dry" else (work._surface_under(name, p, T) if not name.is_empty() and not name.contains(".") else NAN)
		if not is_nan(level):
			return [p, axis, 1.0, false, rise, contact, level, Vector3.UP]
	return [p, axis, 1.0, false, rise, contact, floor_y]


## BRUSH [param tool] LAID ON ITS PAINT, THE WATER CUP'S FLOOR OR THE TOWEL ([constant LAY_SHARE]): the hold for trip [param kind] to
## [param name], its straight tip over [param p] (where its paint is taken, [method _source_of]), coming in [param rise] over that,
## held [param contact] - pushed down until that share of its hairs would lie along the surface, `[tip, axis, 1, false, how far over it
## the tool comes in and leaves, the way it is held, the surface's height, its normal, the way a flat brush lies broadside]`. Leaned
## the first of [constant LAY_LEANS] that keeps it inside [param mouth] (none: anywhere); none where nothing lies under it, nothing of
## that lean keeps inside, or its hairs hardly bend (a cotton tip's, [constant Bristles.KINDS]' `bends`). A FLAT BRUSH COMING FROM
## [param near] keeps the roll it had there ([method _way_from]: never turned half over on a trip) and is leaned across its broadside as
## that roll carries it, so its flat lies on the surface - leaned the one way, it had bent sideways along its chisel edge.
func _laid_hold(kind: String, name: String, tool: Dictionary, contact: String, p: Vector3, rise: float, mouth: Dictionary, T: float, near: Array = []) -> Array:
	if String(tool.get("kind", "")) != "brush" or not tool.has("hair_root") or float(tool.get("bends", 1.0)) < 0.5:
		return []
	var level := p.y if kind == "dry" else (work._surface_under(name, p, T) if not name.is_empty() and not name.contains(".") else NAN)
	if is_nan(level):
		return []
	var rolled := tool.has("across") and near.size() > 8 and near[8] is Vector3 and (near[8] as Vector3).length_squared() > 0.5
	# (found once for each pot and each way a flat brush comes rolled - it is asked every frame, many times over)
	var key := "laid|%s|%s|%s|%s|%.5f|%.5f|%.5f|%.5f|%s" % [kind, name, tool.get("ch", ""), contact, p.x, p.y, p.z, level,
		(str(near[1]) + str(near[8]) + _contact_of(near)) if rolled else ""]
	if _pots.has(key):
		return (_pots[key] as Array).duplicate()
	# (out toward the side of the table it is on, a little toward the camera - and a flat brush broadside across that)
	var side := 1.0 if p.x >= work.work_spot().x else -1.0
	var out_h := Vector3(LAY_OUT.x * side, 0.0, LAY_OUT.y).normalized()
	var across0 := Vector3.ZERO
	var an := Vector3.UP
	if rolled:
		across0 = (_node_at(near, tool, tool["x0"]).basis * (tool["across"] as Vector3)).normalized()
		an = (near[1] as Vector3).normalized()
	var hl := float(tool["len"])
	var found: Array = []
	for lean in LAY_LEANS:
		var a := deg_to_rad(float(lean))
		var lean_h := out_h
		var goes := Vector3.UP.cross(out_h).normalized()
		if rolled:
			# (...its broadside as the handle carries it there, [method _way_from] - leaned square across that, out of the work's way)
			for _k in 3:
				var ah := (Vector3.UP * cos(a) + lean_h * sin(a)).normalized()
				goes = Basis(Quaternion(an, ah)) * across0 if an.dot(ah) > -0.999 else across0
				var flat := Vector3(goes.x, 0.0, goes.z)
				if flat.length() < 0.05:
					break
				var w := Vector3.UP.cross(flat).normalized()
				lean_h = w if w.dot(out_h) + 1e-3 * w.x * side >= 0.0 else -w
			var ah2 := (Vector3.UP * cos(a) + lean_h * sin(a)).normalized()
			goes = Basis(Quaternion(an, ah2)) * across0 if an.dot(ah2) > -0.999 else across0
		var h := [p, (Vector3.UP * cos(a) + lean_h * sin(a)).normalized(), 1.0, false, rise, contact, level, Vector3.UP, goes]
		var x := _node_at(h, tool, tool["x0"])
		var d := (x.basis * (tool["hair_axis"] as Vector3)).normalized()
		var down_by := (x * (tool["hair_root"] as Vector3)).y - (level + LAY_CLEAR + Bristles.lay_over(-d.y, hl, LAY_SHARE))
		h[0] = p - Vector3.UP * down_by
		h[4] = rise + down_by
		if mouth.is_empty() or _laid_inside(h, tool, mouth):
			found = h
			break
	_pots[key] = found
	return found.duplicate()


## Whether brush [param tool] held laid as [param h] ([method _laid_hold]) keeps inside [param mouth]: its own surface under the rim, and
## its hairs' tip laid out along its paint, inside the wall - with room to be worked round in it ([constant LOAD_SWIRL]) and drawn toward
## its handle as it comes up, half as far again ([method _load_swirl]).
func _laid_inside(h: Array, tool: Dictionary, mouth: Dictionary) -> bool:
	var x := _node_at(h, tool, tool["x0"])
	var at: Vector3 = mouth["at"]
	var r := float(mouth["r"])
	for s in tool.get("points", PackedVector3Array()):
		var q := x * (s as Vector3)
		if q.y < at.y and Vector2(q.x - at.x, q.z - at.z).length() > r - CLEAR_WALL - LOAD_SWIRL * 1.5:
			return false
	var on := _lay_on_plane(tool, h, Vector3.ZERO)
	var tip := x * _bent_tip(tool, x.basis.inverse() * (on[0] as Vector3), on[1] as Vector2)
	return Vector2(tip.x - at.x, tip.z - at.z).length() <= r - POT_WALL - LOAD_SWIRL


## The pots' ways tried across a mouth (shares of its room, [method _pot_clear]): its middle first - as far as a corner going in
## beside the wall, the end it is the corner of lying across the mouth.
const POT_OFFS := [0.0, 0.3, 0.55, 0.75, 0.9]
const POT_OFF_ROUND := 8
## ...and its wall kept off a tool drawn pressed flat on its paint this far: its outline is its own edges, sampled along them
## ([constant CLEAR_WALL] is a rigid tool's, its points [constant POINTS_EVERY] apart).
const POT_WALL := 0.002


## Whether tool [param tool], held upright by [param contact] (its grip straight over its tip), stands further than [param r] (meters) out
## from the line through its tip anywhere - a face too broad for a mouth that wide.
static func _wider_than(tool: Dictionary, contact: String, r: float) -> bool:
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var up := ((c["grip"] as Vector3) - tip_l).normalized()
	for q in tool.get("points", PackedVector3Array()) as PackedVector3Array:
		var rel := (q as Vector3) - tip_l
		if (rel - up * rel.dot(up)).length() > r:
			return true
	return false


## HOW TOOL [param tool] IS HELD IN A POT, held [param contact] with its tip at [param p] and pushed in its [method _pressed_into]: of
## every part of it under the rim of [param mouth] AS IT IS DRAWN - what would go under the paint's surface [param floor_y] (none: NAN)
## pressed flat on it ([method _flat_lift]) - none past its wall ([constant CLEAR_WALL]). The way nearest [param want] with its tip
## nearest the mouth's middle that is ([constant POT_OFFS] across it), else the least past, lifted until what is past is over the rim -
## `{axis (the table's space), off (its tip moved across the mouth), lift (meters)}`, found once ([member _pots]).
func _pot_clear(name: String, tool: Dictionary, contact: String, p: Vector3, want: Vector3, mouth: Dictionary, floor_y := NAN) -> Dictionary:
	var key := "%s|%s|%s|%.4f" % [name, tool.get("ch", ""), contact, p.y]
	if _pots.has(key):
		return _pots[key]
	var c := _contact(tool, contact)
	var tip_l: Vector3 = c["tip"]
	var grip_l: Vector3 = c["grip"]
	var x0b: Basis = (tool["x0"] as Transform3D).basis
	var v0 := (x0b * (grip_l - tip_l)).normalized()
	var at: Vector3 = mouth["at"]
	var flat := not is_nan(floor_y)
	var r := float(mouth["r"]) - (POT_WALL if flat else CLEAR_WALL)
	var pts: PackedVector3Array = tool.get("points", PackedVector3Array())
	# (as far into its paint as it is ever pushed, [method _trip])
	var give := _pressed_into(tool, contact)
	# how far past the wall it stands, and how far under the rim what is past it is
	var past := func(ax: Vector3, off: Vector3, stop: float) -> Vector2:
		var B := (Basis(Quaternion(v0, ax)) if v0.dot(ax) > -0.999 else Basis(Vector3.RIGHT, PI)) * x0b
		var base := p + off - ax * give
		var deep := 0.0
		if flat:
			for s in pts:
				deep = maxf(deep, floor_y - (base + B * ((s as Vector3) - tip_l)).y)
		var worst := -INF
		var under := 0.0
		for s in pts:
			var q: Vector3 = base + B * ((s as Vector3) - tip_l)
			var lift := _flat_lift(q.y - floor_y, deep) if flat else 0.0
			if q.y + lift >= at.y:
				continue
			# (spread out as it is squeezed: at most that much further from the middle)
			var o := Vector2(q.x - at.x, q.z - at.z).length() + lift * FLAT_SPREAD - r
			if o > 0.0:
				under = maxf(under, at.y - q.y - lift)
			if o > worst:
				worst = o
				if worst > stop:
					break
		return Vector2(worst, under)
	var out := {"axis": want, "off": Vector3.ZERO, "lift": 0.0}
	if not pts.is_empty() and (past.call(want, Vector3.ZERO, 0.0) as Vector2).x > 0.0:
		var ways := _ways_round([Vector3.UP], want, contact)
		var best := want
		var best_off := Vector3.ZERO
		var least := INF
		var found := false
		# (held as near upright as it can be, and moved across the mouth for it - a hand moves a sponge aside before it lays it over)
		var offs: Array = []
		for share in POT_OFFS:
			for k in (1 if float(share) == 0.0 else POT_OFF_ROUND):
				var ph := TAU * float(k) / float(POT_OFF_ROUND)
				offs.append(Vector3(cos(ph), 0.0, sin(ph)) * float(share) * r)
		for w in ways:
			var ax: Vector3 = (w as Array)[1]
			for off in offs:
				var o: Vector2 = past.call(ax, off, least)
				if o.x <= 0.0:
					out = {"axis": ax, "off": off, "lift": 0.0}
					found = true
					break
				if o.x < least:
					least = o.x
					best = ax
					best_off = off
			if found:
				break
		if not found:
			out = {"axis": best, "off": best_off, "lift": (past.call(best, best_off, INF) as Vector2).y + RIM_CLEAR * 0.3}
	_pots[key] = out
	return out


## HOW FAR A POINT [param s] over the surface it is pressed onto (meters; under it, less than 0) is drawn lifted, the deepest of what
## it is part of [param deep] past it: what would go under the surface drawn ON it, the [constant FLAT_BAND] over it giving - squeezed
## hardest nearest it, and as the foam was at the band's top. prop_common.gdshaderinc's `flat_on` draws it.
static func _flat_lift(s: float, deep: float) -> float:
	if deep <= 0.0 or s >= FLAT_BAND:
		return 0.0
	var u := clampf((s + deep) / (FLAT_BAND + deep), 0.0, 1.0)
	return FLAT_BAND * pow(u, (FLAT_BAND + deep) / FLAT_BAND) - s


## HOW HIGH A BIT OF A PRESSED PAD OR SPONGE IS DRAWN over the skin (meters; prop_common.gdshaderinc's `press_lands`, the same
## arithmetic), standing [param fs] over it as it is held (along the skin's depth; in it, under 0), [param zf] up from its face toward
## the hand, facing the hand [param back] (0 its face, 1 its back): its face sagged [param sag] into what hollow is near it and laid
## softly on whatever it would go into ([constant PRESS_SOFT]); its back kept its own share of its depth over it ([constant PRESS_THIN]).
## Never lower for standing higher, so nothing of it passes through the rest.
static func press_lands(fs: float, zf: float, back: float, sag: float) -> float:
	var g := fs - sag * (1.0 - back) * (1.0 - smoothstep(0.0, PRESS_REACH, fs))
	var h := PRESS_LIFT + PRESS_SOFT * log(1.0 + exp((g - PRESS_LIFT) / PRESS_SOFT)) if g - PRESS_LIFT < PRESS_SOFT * 20.0 else g
	return maxf(h, PRESS_THIN * zf * back)


## HOW TOOL [param tool] HELD [param h] IS PRESSED ONTO A SKIN, its node's space into the skin's front's [param m]: `{tip, up}` (where
## its way of holding it meets the skin and the way up from it toward the hand, the front's space), `up_own` (that way, its node's)
## and `sag` (how far a pad's face sags into a hollow, pressed as it is - [constant PRESS_SAG] of what it gives). [method press_lands],
## [method _press_on].
static func _press_of(tool: Dictionary, h: Array, m: Transform3D) -> Dictionary:
	var c := _contact(tool, _contact_of(h))
	var tip_l: Vector3 = c["tip"]
	var up_own := ((c["grip"] as Vector3) - tip_l).normalized()
	var sag := float(c.get("give", 0.0)) * float(h[2]) * PRESS_SAG if bool(tool.get("flat", false)) else 0.0
	return {"tip": m * tip_l, "up": (m.basis * up_own).normalized(), "up_own": up_own, "sag": sag}


## How low a pressed bit that touches is drawn ([method press_lands]): as low as a bit standing [constant TOUCH_BAND] over the skin is.
static func _press_touches() -> float:
	return press_lands(TOUCH_BAND, 0.0, 0.0, 0.0)


## WHERE BIT [param q] OF A PRESSED PAD OR SPONGE IS DRAWN (the skin's front's space, as it is held), facing [param n_own] (its node's
## space), pressed as [param ps] says ([method _press_of]) onto what stands over the skin ([method _obstacles] [param g]): `Vector4(x,
## y, z, how high over the skin)` - as high over the skin there as [method press_lands] says, along its depth; its height NAN off the
## skin. prop_common.gdshaderinc, the same arithmetic.
static func _press_point(g: Dictionary, ps: Dictionary, q: Vector3, n_own: Vector3) -> Vector4:
	var zs := _front_z(g, q)
	if zs == -INF:
		return Vector4(q.x, q.y, q.z, NAN)
	var fs := q.z - zs
	var zf := maxf((q - (ps["tip"] as Vector3)).dot(ps["up"] as Vector3), 0.0)
	var back := smoothstep(-0.2, 0.2, n_own.normalized().dot(ps["up_own"] as Vector3))
	var hh := press_lands(fs, zf, back, float(ps["sag"]))
	if absf(hh - fs) <= 1e-6:
		return Vector4(q.x, q.y, q.z, fs)
	return Vector4(q.x, q.y, zs + hh, hh)


## The paint on the table nearest [param paint]'s color ([member _creams]) - of its powders alone, its creams alone ([param powder] 1, 0),
## or of either (-1) - or empty.
func _cream_near(paint: String, powder := -1) -> Dictionary:
	var best := INF
	var got := {}
	var want := Color.html(paint)
	for cr in _creams:
		if powder >= 0 and bool((cr as Dictionary)["powder"]) != (powder == 1):
			continue
		var c: Color = (cr as Dictionary)["color"]
		var dd := Vector3(c.r - want.r, c.g - want.g, c.b - want.b).length()
		if dd < best:
			best = dd
			got = cr
	return got


## WHERE A TOOL TAKES ITS PAINT: [param from] named (a thing, "thing/part", or "thing.point") - its mouth, down to what is in
## it - or the paint on the table nearest [param paint]'s color, or - none - over the middle of the table near the work.
func _source_of(kind: String, from: String, paint: String, T: float) -> Vector3:
	if not from.is_empty():
		if from.contains("."):
			return work.place_of(from, work.work_spot(), T)
		var mouth := work._mouth_of(from, T)
		if not mouth.is_empty():
			var at: Vector3 = mouth["at"]
			var y := work._surface_under(from.get_slice("/", 0), at, T)
			# ...A DRY, OR A THING WITH NO INSIDE (its "mouth" its top), AT ITS SURFACE (feedback 0017: "at the grey block, where we dry the
			# brush, it never touches either" - the millimeter over a vessel's floor had held every dry 1.0 mm over the towel)
			if not is_nan(y) and (kind == "dry" or (float(mouth["r"]) <= 0.0101 and at.y - y < 0.002)):
				return Vector3(at.x, y, at.z)
			return Vector3(at.x, (y + 0.001) if not is_nan(y) and y < at.y else at.y - (0.02 if kind == "rinse" else 0.006), at.z)
		var ti := work._thing_named(from.get_slice("/", 0))
		if ti >= 0:
			return work.place_of(from.get_slice("/", 0) + ".top", work.work_spot(), T)
	if not paint.is_empty():
		var cr := _cream_near(paint)
		if not cr.is_empty():
			return cr["at"]
	var spot := work.work_spot()
	return spot + Vector3(0.12, 0.06, 0.05)


## HOW LONG A TRIP [param kind] TAKES tool [param tool] (seconds): a sponge's rinse and dry as a hand gives them ([method _sponge_trip]).
static func _trip_len(kind: String, tool: Dictionary) -> float:
	var sponge := String(tool.get("kind", "")) == "sponge"
	match kind:
		"rinse":
			return SPONGE_RINSE if sponge else RINSE
		"dry":
			return SPONGE_DRY if sponge else DRY
	return LOAD


## A TRIP: from [param near] to [param pot], over [param s] of the way - there, then down into it and up: a load dips and turns
## once, a rinse swishes round twice, a dry presses onto the cloth and wipes across it - a sponge or a puff PUSHED INTO ITS PAINT and
## held there as it turns ([method _pressed_into]); a sponge rinsed and dried as a hand does it ([method _sponge_trip]). It ends lifted
## over the place. A hold, or - turned in the hand on the way - its node's place.
func _trip(near: Array, pot: Array, s: float, seed: int, kind: String, tool: Dictionary, secs := 0.0) -> Variant:
	if String(tool.get("kind", "")) == "sponge" and kind in ["rinse", "dry"]:
		return _sponge_trip(near, pot, s, seed, kind, tool)
	if String(tool.get("kind", "")) == "brush" and _says_way(pot) and not is_nan(float(pot[6])):
		return _brush_laid(near, pot, s, seed, kind, tool, secs)
	if String(tool.get("kind", "")) == "brush" and kind == "load":
		return _brush_load(near, pot, s, seed, tool)
	var go := 0.4
	var rise := float(pot[4]) if pot.size() > 4 else TRIP_LIFT
	var over: Vector3 = (pot[0] as Vector3) + Vector3.UP * rise
	if s < go:
		# (...going the way its last stroke went, there and back - [method _way_from])
		return _way_from(_between(near, _way_from([over, pot[1], 0.0, false, rise, _contact_of(pot)], near, tool), s / go, seed, tool), near, tool)
	var w := (s - go) / (1.0 - go)
	var deep := _pressed_into(tool, _contact_of(pot)) if kind == "load" else 0.0
	# ...held down as it turns, where it takes up as much as it can
	var dip := clampf(sin(w * PI) * LOAD_HELD, 0.0, 1.0) if deep > 0.0 else sin(w * PI)
	# ...DABBED INTO IT two or three times (the user: "when we're dabbing from the container"), eased between, never out of it
	var pumped := deep > 0.0 and String(tool.get("kind", "")) != "brush"
	var pumps := 2 + absi(hash([seed, "pumps"])) % 2
	var press := dip * lerpf(LOAD_EASE, 1.0, pow(sin(w * PI * float(pumps)), 2.0)) if pumped else dip
	var way := Vector3.ZERO
	match kind:
		"rinse":
			way = Vector3(cos(w * TAU * 2.0), 0.0, sin(w * TAU * 2.0)) * 0.004 * dip
		"dry":
			way = Vector3(lerpf(-WIPE, WIPE, Hands.smooth(w)), 0.0, 0.0)
		_:
			# (a brush turned once in its paint; what is pressed into it pumps, and never swirls into the pot's wall)
			way = Vector3(cos(w * TAU), 0.0, sin(w * TAU)) * 0.0025 * dip if not pumped else Vector3.ZERO
	var into := Vector3.ZERO
	# (...laid over a mouth too narrow for it, it rests on the rim and only bends - [method _pot_hold])
	var draped := pot.size() > 9 and (pot[9] as Vector4).w > 0.0
	if deep > 0.0 and not draped:
		into = (pot[1] as Vector3).normalized() * deep * press
	elif String(tool.get("kind", "")) == "sponge" and not draped:
		into = (pot[1] as Vector3).normalized() * float(_contact(tool, _contact_of(pot))["give"]) * dip
	# ...A BRUSH DRIED PRESSED ONTO THE TOWEL, as far as its hairs give, as a sponge is - wiped across it, they trail and fold along it
	# ([method _lay_on_plane]; feedback 0017: "at the grey block, where we dry the brush, it never touches either" - nothing had pushed it
	# in, and its hairs had wiped 1.1-1.3 mm over the towel)
	var on_towel := String(tool.get("kind", "")) == "brush" and kind == "dry" and pot.size() > 7 and not is_nan(float(pot[6]))
	if on_towel:
		into = (pot[1] as Vector3).normalized() * float(_contact(tool, _contact_of(pot))["give"]) * dip
	# (and where its paint's surface is, which it is drawn pressed flat on - [method _tick_tool])
	var out := [(pot[0] as Vector3) + Vector3.UP * (rise * (1.0 - dip)) + way - into, pot[1], press, false, rise, _contact_of(pot),
		float(pot[6]) if pot.size() > 6 and (pumped or on_towel) else NAN]
	if on_towel:
		out.append(pot[7])
	if draped:
		# (...pressed only once it rests on the rim, never bent in the air on its way down)
		out[2] = press * smoothstep(0.85, 1.0, dip)
		out.append_array([Vector3.ZERO, Vector3.ZERO, pot[9]])
	return _way_from(out, near, tool)


## A BRUSH WORKED INTO ITS PAINT (2026-11-07, the user: "the brush doesn't really move at all when it's dipped into the container, to
## pickup more makeup" - it had been turned once in 2.5 mm): down onto it and pressed past its surface as far as its hairs give (at least
## [constant BRUSH_DIP]), swirled round [constant LOAD_TURNS] times
## out to [constant LOAD_SWIRL] and back to its middle, its hairs dragged through the paint ([method Bristles.target]), then drawn once
## across it as it comes up - from [param near] to [param pot] over [param s] of the way. A hold, or its node's place on the way there.
func _brush_load(near: Array, pot: Array, s: float, seed: int, tool: Dictionary) -> Variant:
	var go := 0.35
	var rise := float(pot[4]) if pot.size() > 4 else TRIP_LIFT
	var at: Vector3 = pot[0]
	if s < go:
		return _way_from(_between(near, _way_from([at + Vector3.UP * rise, pot[1], 0.0, false, rise, _contact_of(pot)], near, tool), s / go, seed, tool), near, tool)
	var w := (s - go) / (1.0 - go)
	var down := Hands.smooth(clampf(w / 0.12, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((w - 0.88) / 0.12, 0.0, 1.0)))
	var way := _load_swirl(w, seed, Vector3(1.0 if hash([seed, "turn"]) % 2 == 0 else -1.0, 0.0, 0.0))
	# ...PRESSED ONTO ITS PAINT, NOT DIPPED THROUGH IT (feedback 0017, 2026-11-09: "That brush is not even touching the foundation it's
	# dipping into. The brush should push so close to the container that the bristles might curve at certain angles"): from the paint's
	# own surface under where it goes in ([method _pot_hold]'s `h[6]`), its tip pushed as far past it as its hairs give - as on a face - and
	# its hairs kept on it, folded along it away from the handle's lean ([method _lay_on_plane]). Dipped [constant BRUSH_DIP] from a
	# millimeter over its pot's box, a 2 mm point had gone into the cream straight and nothing bent.
	var axis_n := (pot[1] as Vector3).normalized()
	if pot.size() > 7 and not is_nan(float(pot[6])):
		var give := maxf(float(_contact(tool, _contact_of(pot))["give"]), BRUSH_DIP)
		# (...as deep as along the handle, but straight down, so it is still swirled round the middle it went in at)
		var low := Vector3(at.x, float(pot[6]) - give * maxf(axis_n.y, 0.5), at.z)
		return _way_from([low.lerp(at + Vector3.UP * rise, 1.0 - down) + way, pot[1], down, false, rise, _contact_of(pot), float(pot[6]), pot[7]], near, tool)
	var into := axis_n * BRUSH_DIP * down
	return _way_from([at + Vector3.UP * rise * (1.0 - down) + way - into, pot[1], down, false, rise, _contact_of(pot), NAN], near, tool)


## THE WAY A BRUSH IS WORKED ROUND IN ITS PAINT [param w] (0-1) of its time there ([method _brush_load]): swirled round [constant LOAD_TURNS]
## times out to [constant LOAD_SWIRL] and back to its middle, the way round [param seed]'s, then drawn once along [param across] as it
## comes up (meters, the table's space).
static func _load_swirl(w: float, seed: int, across: Vector3) -> Vector3:
	var spun := (1.0 if hash([seed, "turn"]) % 2 == 0 else -1.0)
	if w < 0.7:
		var u := clampf((w - 0.1) / 0.6, 0.0, 1.0)
		return Vector3(cos(u * TAU * LOAD_TURNS * spun), 0.0, sin(u * TAU * LOAD_TURNS * spun)) * LOAD_SWIRL * sin(u * PI)
	return across * LOAD_SWIRL * 1.5 * Hands.smooth(clampf((w - 0.7) / 0.25, 0.0, 1.0))


## A BRUSH LAID ON ITS PAINT, THE WATER CUP'S FLOOR OR THE TOWEL ([method _laid_hold], feedback 0002): from [param near] - a flat brush
## leaned across its broadside as it comes, what is left of a turn turned on the way ([method _roll_toward]) - down onto it and pushed straight down until [constant LAY_SHARE] of its
## hairs lie along it on their side ([method _lay_on_plane]); held there, a load worked round in its paint ([method _load_swirl]) and
## drawn once toward its handle as it comes up, a rinse swished round twice on the cup's floor, a dry pulled across the towel toward its
## handle, its hairs trailing - over [param s] of the way. It ends lifted over the place. A hold, or its node's place on the way there.
func _brush_laid(near: Array, pot: Array, s: float, seed: int, kind: String, tool: Dictionary, secs := 0.0) -> Variant:
	var go := 0.35 if kind == "load" else 0.4
	var rise := float(pot[4])
	var at: Vector3 = pot[0]
	var to: Array = _way_from([at + Vector3.UP * rise, pot[1], 0.0, false, rise, _contact_of(pot), NAN, Vector3.ZERO, pot[8]], near, tool)
	# ...ITS WAY THERE AS LONG AS IT TAKES A HAND THAT THE BRUSH KEEPS UP WITH, the trip [param secs] long: going to the towel 40 cm off in a
	# trip's fixed share, 732687's flat brush had been drawn 15 cm behind its hand on the way and 2.6 cm over the towel as its wipe
	# began, its hairs on it only 0.4 s in (feedback 0002: "It also applies to the grey pad. The brushes barely touch at all")
	if secs > 0.0:
		go = clampf(_way_length(near[0], to[0], near[1], to[1], tool) / (TRIP_PACE * secs), go, TRIP_GO_MOST)
	if s < go:
		return _roll_toward(_between(near, to, s / go, seed, tool), near, to, Hands.smooth(s / go), tool)
	var w := (s - go) / (1.0 - go)
	var down := Hands.smooth(clampf(w / 0.12, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((w - 0.88) / 0.12, 0.0, 1.0)))
	# (toward its handle, along the surface)
	var back := Vector3((pot[1] as Vector3).x, 0.0, (pot[1] as Vector3).z).normalized()
	var way := Vector3.ZERO
	match kind:
		"dry":
			way = back * lerpf(-WIPE, WIPE, Hands.smooth(w)) * down
		"rinse":
			way = Vector3(cos(w * TAU * 2.0), 0.0, sin(w * TAU * 2.0)) * 0.004 * down
		_:
			way = _load_swirl(w, seed, back)
	return _way_from([at + Vector3.UP * rise * (1.0 - down) + way, pot[1], down, false, rise, _contact_of(pot), float(pot[6]), pot[7], pot[8]],
		near, tool)


## HOLD [param h] ON ITS WAY FROM [param near] TO [param to], A HOLD THAT SAYS ITS OWN WAY (a brush laid broadside on its paint, [method
## _laid_hold]): a flat brush rolled from as [method _way_from] carries it toward that way, [param k] (0-1) of the turn - turned in the hand
## as it goes, never all at once at the end. Anything else as [method _way_from] has it.
func _roll_toward(h: Variant, near: Array, to: Array, k: float, tool: Dictionary) -> Variant:
	var out: Variant = _way_from(h, near, tool)
	if not (out is Array) or not tool.has("across") or not _says_way(to):
		return out
	var o: Array = (out as Array).duplicate()
	var from_way := (_node_at(o, tool, tool["x0"]).basis * (tool["across"] as Vector3)).normalized()
	var to_way := (to[8] as Vector3).normalized()
	while o.size() < 9:
		o.append([TRIP_LIFT, "", NAN, Vector3.ZERO, Vector3.ZERO][o.size() - 4])
	o[8] = from_way.slerp(to_way, k) if from_way.dot(to_way) > -0.999 else to_way
	return o


## Whether hold [param h] says its own way (`h[8]`, the broadside of a brush laid on its paint - [method _laid_hold]), which [method
## _way_from] keeps.
static func _says_way(h: Array) -> bool:
	return h.size() > 8 and h[8] is Vector3 and (h[8] as Vector3).length_squared() > 0.5


## A SPONGE RINSED AND DRIED AS A HAND DOES IT ([constant SPONGE_RINSE]), from [param near] to [param pot] over [param s] of the way.
## A RINSE: down into the water, onto the cup's floor, and squeezed there [constant SOAKS] times as it soaks, its paint let go; lifted over the cup and
## wrung out hard [constant WRINGS] times, over the water it runs back into. A DRY: [constant BLOTS] firm presses onto the towel, each
## held a while and each on a fresh place, lifted a little between. Squeezed as hard as its hold's press says ([method _tick_tool]'s
## squash); it ends lifted over the place.
func _sponge_trip(near: Array, pot: Array, s: float, seed: int, kind: String, tool: Dictionary) -> Variant:
	var rise := float(pot[4]) if pot.size() > 4 else TRIP_LIFT
	var contact := _contact_of(pot)
	var at: Vector3 = pot[0]
	var into_n := (pot[1] as Vector3).normalized()
	if s < SPONGE_GO:
		return _way_from(_between(near, _way_from([at + Vector3.UP * rise, pot[1], 0.0, false, rise, contact], near, tool), s / SPONGE_GO, seed, tool), near, tool)
	var w := (s - SPONGE_GO) / (1.0 - SPONGE_GO)
	var press := 0.0
	var p := at
	if kind == "rinse":
		# (down into it, squeezed as it soaks, up over the cup, wrung)
		var down := Hands.smooth(clampf(w / 0.1, 0.0, 1.0)) * (1.0 - Hands.smooth(clampf((w - 0.5) / 0.1, 0.0, 1.0)))
		if w < 0.55:
			var soak := clampf((w - 0.1) / 0.4, 0.0, 1.0)
			press = down * lerpf(SOAK_EASE, SOAK_PRESS, pow(sin(soak * PI * float(SOAKS)), 2.0))
		else:
			press = pow(sin(clampf((w - 0.6) / 0.35, 0.0, 1.0) * PI * float(WRINGS)), 2.0)
		var swish := Vector3(cos(w * TAU), 0.0, sin(w * TAU)) * 0.002 * down
		p = at + Vector3.UP * rise * (1.0 - down) + swish
	else:
		# (blotted: down, held pressed, up a little and over to a fresh place - from over the towel and back over it)
		# (over to its place while lifted, then down and pressed - never slid along the towel pressed)
		var b := w * float(BLOTS)
		var k := mini(int(b), BLOTS - 1)
		var u := b - float(k)
		var held := clampf(sin(clampf((u - BLOT_OVER) / (1.0 - BLOT_OVER), 0.0, 1.0) * PI) * BLOT_HELD, 0.0, 1.0)
		press = held
		var lift := BLOT_LIFT
		if (k == 0 and u < 0.5) or (k == BLOTS - 1 and u >= 0.5):
			lift = rise
		var step := float(k) - float(BLOTS - 1) * 0.5
		var x := step - (1.0 - Hands.smooth(clampf(u / BLOT_OVER, 0.0, 1.0))) if k > 0 else step
		p = at + Vector3.RIGHT * x * BLOT_STEP + Vector3.UP * lift * (1.0 - held) \
			- into_n * float(_contact(tool, contact)["give"]) * held
	return _way_from([p, pot[1], press, false, rise, contact, NAN], near, tool)


## HOW FAR TOOL [param tool], held [param contact], is pushed into its paint to take it up (meters): a sponge its [constant LOAD_PRESS],
## squashed against it, a pad (a puff) [constant LOAD_PRESS_PAD], a brush's hairs [constant BRUSH_DIP].
static func _pressed_into(tool: Dictionary, contact: String) -> float:
	if String(tool.get("kind", "")) == "sponge":
		return LOAD_PRESS
	if String(tool.get("kind", "")) == "brush":
		return BRUSH_DIP
	if bool(tool.get("flat", false)) and _contact(tool, contact).get("tip") != null:
		return LOAD_PRESS_PAD
	return 0.0


## HOW FAR TOOL [param tool]'s BODY GOES between a tip at [param pa] leaning [param la] and one at [param pb] leaning [param lb] (meters), as
## [method _between] takes it: the tip's way, up over what stands between and down again, and its handle swung from the one lean to the
## other - a brow's upright to a chin's low lean swept a liner's end 80 cm while its tip went 20 (2026-11-10). What a way is paced by.
func _way_length(pa: Vector3, pb: Vector3, la: Vector3, lb: Vector3, tool: Dictionary) -> float:
	var reach := _reach_of(tool) if not tool.is_empty() else TOPS_BESIDE
	var dist := pa.distance_to(pb)
	var lift := maxf(clampf(dist * 0.25, 0.0, 0.06), _lift_over(pa, pb, 0, reach))
	var arm := _arm_of(tool)
	var swing := la.normalized().angle_to(lb.normalized()) * arm if la.length_squared() > 0.5 and lb.length_squared() > 0.5 else 0.0
	return dist + 2.0 * lift + swing


## HOW FAR TOOL [param tool]'s BODY GOES a radian it is turned about its tip (meters): twice its grip's way from its tip - a liner's 0.26 m,
## where the solver's own measure ([method RigidParts._span]: its middle's way and its turn times its radius) is 0.21. None without a tool.
func _arm_of(tool: Dictionary) -> float:
	if tool.is_empty():
		return 0.0
	var c0 := _contact(tool, "")
	return ((c0["grip"] as Vector3) - (c0["tip"] as Vector3)).length() * 2.0


## From hold [param a] to hold [param b], as a hand goes - lifted on its way between places apart, and over what stands between. From
## one way of holding tool [param tool] to another (a sponge's corner out of its paint, its face onto the surface) it is turned in the
## hand on the way: its node's place.
func _between(a: Array, b: Array, s: float, seed: int, tool: Dictionary) -> Variant:
	if not tool.is_empty() and _way(tool, a) != _way(tool, b):
		var x0: Transform3D = tool["x0"]
		var na := _node_at(a, tool, x0)
		var nb := _node_at(b, tool, x0)
		var c: Vector3 = tool["center"]
		var ca := na * c
		var cb := nb * c
		var lift_c := maxf(clampf(ca.distance_to(cb) * 0.25, 0.0, 0.06), _lift_over(ca, cb, seed, _reach_of(tool)))
		var q := Hands.carried(ca, cb, Vector3.ZERO, Vector3.ZERO, lift_c, s, seed)
		var rb := Basis(Quaternion(na.basis.orthonormalized()).slerp(Quaternion(nb.basis.orthonormalized()), Hands.timing(s)))
		var basis := rb.scaled(na.basis.get_scale())
		return Transform3D(basis, q - basis * c)
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var reach := _reach_of(tool) if not tool.is_empty() else TOPS_BESIDE
	var lift := maxf(clampf(pa.distance_to(pb) * 0.25, 0.0, 0.06), _lift_over(pa, pb, seed, reach))
	var p := Hands.carried(pa, pb, Vector3.ZERO, Vector3.ZERO, lift, s, seed)
	var axis := (a[1] as Vector3).slerp((b[1] as Vector3).normalized(), Hands.timing(s)) if (a[1] as Vector3).dot(b[1] as Vector3) > -0.99 else (b[1] as Vector3)
	return [p, axis, 0.0, false, TRIP_LIFT, _contact_of(b) if not _contact_of(b).is_empty() else _contact_of(a)]


# --- when everything happens --------------------------------------------------------------------------

## AFTER THE SCHEDULE: each element's moments - laid, gone over, swept - its stones', the paint on each tool's tip, and the
## puffs a pat raises - from every paint act where the schedule has put it.
func spans(entries: Array) -> void:
	_dust = []
	_loads = {}
	var spans_of := {}            # "si|id" -> {span, blend, sweep}
	for s in skins:
		for st in (s as Dictionary).get("stones", []):
			(st as Dictionary)["t"] = Vector2(INF, INF)
	for en in entries:
		var e: Dictionary = en
		var tr: Dictionary = e["track"]
		var t0 := float(e["t0"])
		var d := maxf(float(e["t1"]) - t0, 1e-3)
		var plan := _plan_entry(e, tr, d)
		var si := int(plan["si"])
		var ch := String(tr["_ch"])
		if not _loads.has(ch):
			_loads[ch] = []
		for p in plan["phases"]:
			var pd: Dictionary = p
			var a := t0 + float(pd["a"])
			var b := t0 + float(pd["b"])
			match String(pd["kind"]):
				"load":
					(_loads[ch] as Array).append([lerpf(a, b, 0.5), String(pd["paint"])])
				"rinse":
					(_loads[ch] as Array).append([lerpf(a, b, 0.5), ""])
				"el":
					var key := "%d|%s" % [si, String(pd["el"])]
					if not spans_of.has(key):
						spans_of[key] = {}
					var role := String(pd["role"])
					var sp: Dictionary = spans_of[key]
					if not sp.has(role):
						sp[role] = Vector2(a, b)
					var prog: Dictionary = pd["prog"]
					var k := (b - a) / maxf(float(prog["natural"]), 1e-3)
					for pt in prog.get("pats", PackedFloat32Array()):
						if _dust.size() < 400:
							_dust.append({"t": a + float(pt) * k, "si": si, "prog": prog, "tau": float(pt), "look": "dust"})
					for mm in prog.get("mists", []):
						if _dust.size() < 400:
							_dust.append({"t": a + float((mm as Array)[0]) * k, "si": si, "prog": prog, "tau": float((mm as Array)[0]), "look": "mist"})
					# ...and each time it goes back to its paint for more, in the middle of it
					if role == "paint":
						var keys: Array = prog["keys"]
						for q in range(1, keys.size()):
							if int((keys[q] as Array)[5]) == 1 and int((keys[q - 1] as Array)[5]) == 1:
								var paint_of: String = String((_layers.get("%d|%s" % [si, String(pd["el"])], {}) as Dictionary).get("pot", element(si, String(pd["el"])).get("paint", "")))
								if not paint_of.is_empty():
									(_loads[ch] as Array).append([a + float((keys[q] as Array)[0]) * k, paint_of])
					var stones: Array = prog.get("stones", [])
					for j in stones.size():
						_stone_at(si, String(pd["el"]), j, stones[j] as Array, a, k, ch)
	for s_i in skins.size():
		var sd: Dictionary = skins[s_i]
		var order: Array = []
		for id in sd["items"]:
			var it: Dictionary = sd["items"][id]
			var sp: Dictionary = spans_of.get("%d|%s" % [s_i, id], {})
			var span: Vector2 = sp.get("paint", Vector2(1e9, 1e9 + 1.0))
			it["span"] = span
			it["blend"] = sp.get("blend", Vector2(1e9, 1e9 + 1.0))
			it["sweep"] = sp.get("sweep", Vector2(1e9, 1e9 + 1.0))
			for m in it["mats"]:
				var mat := m as ShaderMaterial
				mat.set_shader_parameter("span", span)
				mat.set_shader_parameter("blend_span", it["blend"])
				mat.set_shader_parameter("sweep_span", it["sweep"])
			order.append([span.x, id])
		# WHAT GOES ON LATER LIES OVER WHAT WENT ON BEFORE
		order.sort()
		for k in order.size():
			var it: Dictionary = sd["items"][order[k][1]]
			for sp in it["sprites"]:
				var spr := sp as Sprite2D
				if spr.get_parent() != null:
					spr.get_parent().move_child(spr, k)
	for ch in _loads:
		(_loads[ch] as Array).sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	_drawn_t = NAN


func _stone_at(si: int, el: String, j: int, st: Array, a: float, k: float, ch: String) -> void:
	for s in (skins[si] as Dictionary).get("stones", []):
		var sd: Dictionary = s
		if String(sd["el"]) == el and int(sd["k"]) == j and (sd["t"] as Vector2).x == INF:
			sd["t"] = Vector2(a + float(st[0]) * k, a + float(st[1]) * k)
			sd["tool"] = ch
			return


## THE PUFFS OF POWDER the work raises, as a cue's bursts are placed ([method TableWork.plan_cues]): `[{t, p}]`.
func dust(look := "dust") -> Array:
	var out: Array = []
	for dd in _dust:
		var d: Dictionary = dd
		if String(d.get("look", "dust")) != look:
			continue
		var h := _hold_of(_surface_hold(int(d["si"]), d["prog"], float(d["tau"]), float(d["t"]), {"_ch": "", "_hand": 0}), {})
		# ...thrown the way the tool points, at what it is sprayed on (a burst throws along its moment's up)
		var toward := -(h[1] as Vector3).normalized() if look == "mist" else Vector3.UP
		var side := toward.cross(Vector3.FORWARD if absf(toward.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		out.append({"t": float(d["t"]), "p": h[0], "basis": Basis(side, toward, side.cross(toward).normalized())})
	return out


# --- drawn --------------------------------------------------------------------------------------------

## THE PAINT AT SHOW TIME [param t] (its canvas draws every frame - two small 2D pictures: a frame that asked for one draw could be
## followed by another, in a render or a probe, before the first was ever drawn): what is laid shows where its tool has been, its stones where they are, each tool's hairs
## bent as they are pulled and pressed, its tip the color it was loaded with, a sponge given where it is pressed.
func tick(t: float, entries_of: Callable) -> void:
	var jumped := is_nan(_drawn_t) or absf(t - _drawn_t) > 0.25
	for s in skins:
		var sd: Dictionary = s
		for id in sd["items"]:
			var it: Dictionary = sd["items"][id]
			var live := _live(it, t) or (not is_nan(_drawn_t) and _live(it, _drawn_t))
			if jumped or live:
				for m in it["mats"]:
					(m as ShaderMaterial).set_shader_parameter("now", t)
		for st in sd.get("stones", []):
			_tick_stone(st as Dictionary, t)
	for ch in tools:
		_tick_tool(String(ch), t, entries_of)
	_drawn_t = t


func _live(it: Dictionary, t: float) -> bool:
	for k in ["span", "blend", "sweep"]:
		var sp: Vector2 = it.get(k, Vector2(1e9, 1e9))
		if t >= sp.x - 1.0 and t <= sp.y + 1.0:
			return true
	return false


func _tick_stone(st: Dictionary, t: float) -> void:
	var mi: MeshInstance3D = st["node"]
	var w: Vector2 = st["t"]
	if t < w.x or w.x == INF:
		mi.visible = false
		return
	mi.visible = true
	if t >= w.y:
		mi.transform = st["seat"]
		return
	# ...carried at the tool's tip
	var tool: Dictionary = tools.get(String(st["tool"]), {})
	if tool.is_empty():
		mi.transform = st["seat"]
		return
	var node: Node3D = tool["node"]
	var tip_w := work._world_of(node) * (tool["tip"] as Vector3)
	var holder := mi.get_parent() as Node3D
	mi.transform = Transform3D(Basis.IDENTITY, work._world_of(holder).affine_inverse() * tip_w)


## A TOOL'S HAIRS, TIP AND GIVE at show time [param t]: the entry of its channel that holds it now (or just let it go).
func _tick_tool(ch: String, t: float, entries_of: Callable) -> void:
	var tool: Dictionary = tools[ch]
	var ents: Array = entries_of.call(ch)
	var e: Dictionary = {}
	for en in ents:
		var ed: Dictionary = en
		if String((ed["track"] as Dictionary)["law"]) == "paint" and t >= float(ed["t0"]) and t <= float(ed["t1"]) + SETTLE:
			e = ed
	# THE PAINT ON ITS TIP: the last it took up, unless rinsed since
	var tip := Color(0, 0, 0, 0)
	var since := 0.0
	for ld in _loads.get(ch, []):
		if float(ld[0]) <= t:
			tip = Color.html(String(ld[1])) if not String(ld[1]).is_empty() else Color(0, 0, 0, 0)
			since = t - float(ld[0])
	# ...THINNER AS IT IS USED, down to what never comes out of a brush until it is rinsed
	var load := lerpf(TIP_LEFT, TIP_FULL, exp(-since / TIP_LASTS)) if tip.a > 0.0 else 0.0
	for tf in tool["tufts"]:
		var mat: ShaderMaterial = (tf as Dictionary)["mat"]
		mat.set_shader_parameter("tip_paint", Color(tip.r, tip.g, tip.b, load))
	if e.is_empty():
		for tf in tool["tufts"]:
			((tf as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("bristle_bend", Vector3.ZERO)
			((tf as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("bristle_splay", 0.0)
			((tf as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("bristle_lay", Vector2.ZERO)
		for sp in tool["sponges"]:
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("squash", Vector4.ZERO)
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("squeeze", Vector4.ZERO)
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("flat_by", Vector3.ZERO)
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("press_cells", Vector4.ZERO)
			((sp as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("drape_at", Vector4.ZERO)
		return
	var tr: Dictionary = e["track"]
	var t0 := float(e["t0"])
	var d := maxf(float(e["t1"]) - t0, 1e-3)
	var plan := _plan_entry(e, tr, d)
	var home := _home_of(e, e["from"])
	var hold_at := func(tt: float) -> Array:
		var held: Variant = _held_at(plan, tr, clampf(tt - t0, 0.0, d), tt, e["from"], work._rest.get(ch, Transform3D.IDENTITY), home)
		return _hold_of(held, tool)
	var node_w := work._world_of(tool["node"])
	if not tool["tufts"].is_empty():
		var len := float(tool["len"])
		var target := func(tt: float) -> Array:
			var h0: Array = hold_at.call(tt - 0.03)
			var h1: Array = hold_at.call(tt + 0.03)
			var v := ((h1[0] as Vector3) - (h0[0] as Vector3)) / 0.06
			var press := (float(h0[2]) + float(h1[2])) * 0.5
			var axis: Vector3 = ((h0[1] as Vector3) + (h1[1] as Vector3)).normalized()
			# ...pressed, its tip goes along the surface away from where the handle leans over it ([method _skin_hold]'s normal)
			var n: Vector3 = h1[7] if h1.size() > 7 else Vector3.ZERO
			var ahead := -(axis - n * axis.dot(n)) if n.length_squared() > 0.5 else Vector3.ZERO
			return Bristles.target(v, press, len, axis, ahead, float(tool.get("bends", 1.0)))
		var bent: Array = Bristles.response(target, t)
		# ...BENT NO FURTHER THAN KEEPS ITS TIP ON THE FACE it is pressed on ([method _bend_to_surface]) - AND ONLY WHILE IT IS PRESSED
		# (feedback 0019: a lifted brush's hold still says it is over the face, and its hairs had been bent to reach it from 4.3 mm up); on
		# its paint, the cup's floor or the towel, laid on that as far as the brush AS DRAWN reaches it, and straight where it does not
		# ([method _lay_on_plane]: pick a lane - "either touch the actual bottom, so that the curves make sense, or don't touch it, and don't
		# curve the bristles in the water")
		var h_now := hold_at.call(t) as Array
		var lay := Vector2.ZERO
		if bool(h_now[3]) and float(h_now[2]) > 0.0 and int(tr.get("_skin", -1)) >= 0:
			bent[0] = _bend_to_surface(int(tr["_skin"]), tool, h_now, bent[0] as Vector3)
		elif not bool(h_now[3]) and float(h_now[2]) > 0.0 and h_now.size() > 7 and not is_nan(float(h_now[6])):
			var on := _lay_on_plane(tool, h_now, bent[0] as Vector3, node_w,
				((h_now[0] as Vector3) - ((hold_at.call(t - TRAIL_LAG) as Array)[0] as Vector3)) / TRAIL_LAG)
			lay = on[1]
			bent[0] = on[0] if lay.y > 0.0 else Vector3.ZERO
		var inv := node_w.basis.inverse()
		for tf in tool["tufts"]:
			var mat: ShaderMaterial = (tf as Dictionary)["mat"]
			mat.set_shader_parameter("bristle_bend", inv * (bent[0] as Vector3))
			mat.set_shader_parameter("bristle_splay", float(bent[1]))
			mat.set_shader_parameter("bristle_lay", lay)
	# ...A SPONGE BEING RINSED IS SQUEEZED IN THE HAND, its broad faces together ([method _squeeze_of])
	var rinsing := String(tool.get("kind", "")) == "sponge" and _phase_kind(plan, clampf(t - t0, 0.0, d)) == "rinse"
	for sp in tool["sponges"]:
		var mat2: ShaderMaterial = (sp as Dictionary)["mat"]
		var h: Array = hold_at.call(t)
		mat2.set_shader_parameter("squeeze", _squeeze_of(tool, float(h[2])) if rinsing else Vector4.ZERO)
		mat2.set_shader_parameter("squeeze_reach", _squeeze_reach(tool))
		# ...LAID OVER A POT'S MOUTH TOO NARROW FOR IT, bent down into it as it is pressed ([method _drape_on])
		var drape: Vector4 = h[9] if h.size() > 9 and h[9] is Vector4 else Vector4.ZERO
		mat2.set_shader_parameter("drape_at", Vector4.ZERO)
		if drape.w > 0.0 and not rinsing:
			var dr := _drape_on(node_w, drape, float(h[6]) if h.size() > 6 else NAN, float(h[2]), tool)
			mat2.set_shader_parameter("press_cells", Vector4.ZERO)
			mat2.set_shader_parameter("squash", Vector4.ZERO)
			mat2.set_shader_parameter("squash_at", tool["center"])
			mat2.set_shader_parameter("drape_on", dr["on"])
			mat2.set_shader_parameter("drape_at", dr["at"])
			mat2.set_shader_parameter("drape_by", dr["by"])
			mat2.set_shader_parameter("flat_by", dr["flat_by"])
			mat2.set_shader_parameter("flat_on", dr["flat_on"])
			mat2.set_shader_parameter("flat_at", dr["flat_at"])
			continue
		if rinsing:
			mat2.set_shader_parameter("press_cells", Vector4.ZERO)
			mat2.set_shader_parameter("squash", Vector4.ZERO)
			mat2.set_shader_parameter("squash_at", tool["center"])
			mat2.set_shader_parameter("flat_by", Vector3.ZERO)
			continue
		# ...ON A SKIN, TAKING ITS SHAPE ([method _press_on]) - held over it, or turned in the hand between its face and its corner (it had
		# stood 2.7 mm in a nose); never at its paint, its water or its towel (a trip's hold)
		var si_on := int(tr.get("_skin", -1))
		if si_on >= 0 and (bool(h[3]) or h.size() <= 6):
			_press_on(mat2, si_on, tool, h, (sp as Dictionary)["mesh"])
			mat2.set_shader_parameter("squash", Vector4.ZERO)
			mat2.set_shader_parameter("squash_at", tool["center"])
			mat2.set_shader_parameter("flat_by", Vector3.ZERO)
			continue
		mat2.set_shader_parameter("press_cells", Vector4.ZERO)
		var into := -(h[1] as Vector3).normalized()
		var dir_m := (node_w.basis.inverse() * into).normalized()
		# ...GIVING BACK TO THE SURFACE what it was pushed into it ([method _skin_hold]): squashed from its middle that much at its tip
		var way := _contact(tool, _contact_of(h))
		# ...in its paint (a trip's hold, off the surface) pushed in deeper ([method _trip])
		var pushed := _pressed_into(tool, _contact_of(h)) if not bool(h[3]) else float(way["give"])
		var give := pushed * float(h[2]) / float(way["reach"])
		# ...PRESSED INTO ITS PAINT, drawn flat on its surface ([method _flat_lift]) - in its own space, as far as the deepest of it went
		var floor_y := float(h[6]) if h.size() > 6 else NAN
		var flat := _flat_on(node_w, floor_y, tool) if not is_nan(floor_y) else []
		mat2.set_shader_parameter("squash", Vector4(dir_m.x, dir_m.y, dir_m.z, minf(give, 0.5)) if flat.is_empty() else Vector4.ZERO)
		mat2.set_shader_parameter("squash_at", tool["center"])
		mat2.set_shader_parameter("flat_by", Vector3.ZERO if flat.is_empty() else flat[1])
		if not flat.is_empty():
			mat2.set_shader_parameter("flat_on", flat[0])
			mat2.set_shader_parameter("flat_at", flat[2])


## ONE COAT OF A PAINT, NEVER TWO (the user, 2026-11-07, of feedback 0062-0063: "why are we making two passes of white at all? And if BOTH use
## the exact same color, then why would the first pass be half as light, with the second being even more light? ... There ought to be one
## application of white, no more"): of each design's fills over all of its surface, those in one pot are one application - the first, as
## thick as they all come to together (its own `opacity` made that, so a table prepared again finds the same), the rest taken out of the
## design; an act left nothing to lay takes nothing up ([method plan_of]). A tan wash and a white over it, both its pot's white, had been
## laid as two whites - then as a thin first coat and a made-up second.
func _one_coat() -> void:
	for si in skins.size():
		var sd: Dictionary = skins[si]
		var els: Array = (sd["design"] as Dictionary).get("elements", [])
		var first_of := {}
		var clear := {}
		var gone := {}
		for e in els:
			var ed: Dictionary = e
			var key := "%d|%s" % [si, String(ed["id"]).to_lower()]
			# (...never one the painter host laid: its own coat, as it laid it - folded in, 327484's first shading had gone into the base)
			if String(ed["kind"]) != "fill" or String(ed["d"]) != "all" or not _layers.has(key) or not _host_of(ed).is_empty():
				continue
			var lay: Dictionary = _layers[key]
			var pot := String(lay.get("pot", ed["paint"]))
			var o := clampf(float(ed["opacity"]) * float(lay.get("thick", 1.0)), 0.0, 1.0)
			if not first_of.has(pot):
				first_of[pot] = ed
				clear[pot] = 1.0 - o
			else:
				clear[pot] = float(clear[pot]) * (1.0 - o)
				gone[String(ed["id"]).to_lower()] = true
				_layers.erase(key)
		if gone.is_empty():
			continue
		for pot in first_of:
			var fd: Dictionary = first_of[pot]
			var lay: Dictionary = _layers["%d|%s" % [si, String(fd["id"]).to_lower()]]
			fd["opacity"] = clampf((1.0 - float(clear[pot])) / maxf(float(lay.get("thick", 1.0)), 1e-3), float(fd["opacity"]), 1.0)
		(sd["design"] as Dictionary)["elements"] = els.filter(func(e: Dictionary) -> bool: return not gone.has(String(e["id"]).to_lower()))


## A TOOL'S ACTS ONE AFTER ANOTHER (feedback 0061, 2026-11-07: "we put the sponge in water, squeezed it, dabbed it off, then put it on the
## white dish. Then, we put it BACK into the water again. Why are we doing this a second time"): each paint track told what the same
## tool's acts either side of it leave it - one whose next act comes straight after and begins in the paint it ends with keeps it,
## uncleaned and never put down (`_keep`; 0063: "the sponge went into the dish, then came back to the mask and started dabbing again"),
## and that act begins holding it (`_loaded`); one that ends rinsed leaves the next damp, wetted for nothing thin (`_damp`). Each act had
## cleaned its tool before putting it down, and the next wetted it again.
## AN ACT LEFT NOTHING TO DO IS NO ACT HERE (feedback 0002, 2026-11-07: "we went in the water, then dabbed it dry, then put it on the white
## tray. Then, we picked it up and just dunked it in the water again ... redundant"): 257002's second white, folded into the first by
## [method _one_coat], left its act painting nothing - and it stood as the sponge's next act, so the white's rinse left IT damp, and the rim
## shade after it began dry and wet the clean sponge again.
func _one_after_another() -> void:
	var by_tool := {}
	var order := {}
	for a in _in_reading_order(work.acts):
		var idle := true
		for tr in (a as Dictionary)["tracks"]:
			idle = idle and _paints_nothing(tr)
		if not idle:
			order[String((a as Dictionary)["name"])] = order.size()
		for tr in (a as Dictionary)["tracks"]:
			var t: Dictionary = tr
			if String(t["law"]) != "paint" or not t.has("_ch") or int(t.get("_skin", -1)) < 0:
				continue
			for k in ["_keep", "_loaded", "_damp"]:
				t.erase(k)
			t["_act"] = String((a as Dictionary)["name"])
			if _paints_nothing(t):
				continue
			if not by_tool.has(String(t["_ch"])):
				by_tool[String(t["_ch"])] = []
			(by_tool[String(t["_ch"])] as Array).append(t)
	for ch in by_tool:
		var list: Array = by_tool[ch]
		for i in range(list.size() - 1):
			var t: Dictionary = list[i]
			var nxt: Dictionary = list[i + 1]
			var ends := _pots_laid(t)
			var begins := _pots_laid(nxt)
			# (...kept in hand only for the act that comes straight after - never held up through another tool's work between)
			var next_now := int(order.get(String(nxt["_act"]), -9)) == int(order.get(String(t["_act"]), -9)) + 1
			if next_now and not ends.is_empty() and not begins.is_empty() and ends[ends.size() - 1] == begins[0]:
				t["_keep"] = true
				nxt["_loaded"] = begins[0]
			elif t.has("rinse") and not ends.is_empty():
				nxt["_damp"] = true


## Whether track [param tr] is a paint track with nothing of its design left to lay or go over (each element it names taken out - [method
## _one_coat]): its act takes nothing up and its tool stays where it rests.
func _paints_nothing(tr: Dictionary) -> bool:
	if String(tr.get("law", "")) != "paint" or int(tr.get("_skin", -1)) < 0:
		return false
	for id in tr.get("paint", []):
		if not element(int(tr["_skin"]), String(id)).is_empty():
			return false
	return true


## THE POTS PAINT TRACK [param tr] TAKES UP, in the order its elements are laid ([method _pot_of]) - those it lays, never those it goes over.
func _pots_laid(tr: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var si := int(tr.get("_skin", -1))
	for id in tr.get("paint", []):
		var lay: Dictionary = _layers.get("%d|%s" % [si, String(id).to_lower()], {})
		var ed := element(si, String(id))
		if lay.is_empty() or ed.is_empty() or lay.get("act") != tr.get("_act") or String(ed["kind"]) in ["stones", "smear", "mist"]:
			continue
		var pot := String(lay.get("pot", ed["paint"]))
		if out.is_empty() or out[out.size() - 1] != pot:
			out.append(pot)
	return out


## THE PAINT ELEMENT [param el] IS LAID IN by paint track [param tr]: the paint in the pot its act takes from (`from`), or the pot its
## design names (`plan.pot`), a cream or a powder, else the paint on the table nearest its color of its own kind (a powder's finish a
## powder, any other a cream; either where the table has none of it) - as "#rrggbb" - or its own where it takes none (stones, a mist) or
## the table has none.
func _pot_of(tr: Dictionary, el: Dictionary) -> String:
	var own := String(el.get("paint", ""))
	if String(el.get("kind", "")) in ["stones", "mist", "smear"] or _creams.is_empty() or own.is_empty():
		return own
	var powder := String(el.get("finish", "")) == "powder"
	var from := String(tr.get("from", ""))
	# ...THE POT THE PAINTER NAMED (feedback 0001, 2026-11-09: "how a sponge being dipped into yellow foundation is somehow applying white/
	# light green makeup upon the mask"): 732687's base, laid from the white pot, went back for more to the amber - the cream nearest its
	# color - and 39 of its 103 elements to a pot the painter never named, an amber and black to the clear gloss
	if from.is_empty() and el.get("plan") is Dictionary:
		from = String((el["plan"] as Dictionary).get("pot", ""))
	if not from.is_empty():
		var ti := work._thing_named(from.get_slice("/", 0).get_slice(".", 0))
		var got := {}
		for cr in _creams:
			if int((cr as Dictionary)["ti"]) == ti and (got.is_empty() or bool((cr as Dictionary)["powder"]) == powder):
				got = cr
		if not got.is_empty():
			return "#" + Color(got["color"]).to_html(false)
	var near := _cream_near(own, 1 if powder else 0)
	if near.is_empty():
		near = _cream_near(own)
	return "#" + Color(near["color"]).to_html(false) if not near.is_empty() else own


## HOW THICK a pot's paint [param pot] is laid for an element designed [param paint] (0-1, times its opacity): as thin as brings it over
## a face [constant FACE_LIGHT] light to the design's lightness - a lighter plum a thinner plum - and whole where the design is as dark as
## its pot or darker.
static func _thickness(paint: Color, pot: Color) -> float:
	var lp := pot.get_luminance()
	var ld := paint.get_luminance()
	if ld <= lp + 0.02:
		return 1.0
	return clampf((FACE_LIGHT - ld) / maxf(FACE_LIGHT - lp, 0.05), THIN_LEAST, 1.0)


## THE KIND OF PHASE of [param plan] ([method plan_of]) at [param tau] seconds into its act ("" between phases).
static func _phase_kind(plan: Dictionary, tau: float) -> String:
	for p in plan.get("phases", []):
		if tau >= float((p as Dictionary)["a"]) and tau <= float((p as Dictionary)["b"]):
			return String((p as Dictionary)["kind"])
	return ""


## A SPONGE SQUEEZED IN THE HAND as hard as [param press] (0-1): across its broad faces - its box's thinnest way, in its own space -
## that much of [constant SQUEEZE_MOST] thinner, prop_common.gdshaderinc's `squeeze` (the user, 2026-11-07, of a wring drawn as a press
## along its length: "The sponge stretches and retracts the long way ... The sponge should compress first, then expand back to where it
## started ... most people would squish on the wider edge, the fatter edge - not lengthwise").
static func _squeeze_of(tool: Dictionary, press: float) -> Vector4:
	var box: AABB = tool.get("box", AABB())
	var k := 0 if box.size.x <= box.size.y and box.size.x <= box.size.z else (1 if box.size.y <= box.size.z else 2)
	var across := Vector3.ZERO
	across[k] = 1.0
	return Vector4(across.x, across.y, across.z, clampf(press, 0.0, 1.0) * SQUEEZE_MOST)


## ...AND WHERE A FINGER AND THUMB PINCH IT: how far from its middle the press reaches (its own space), a share of half its narrower broad side
## (prop_common.gdshaderinc's `squeeze_reach`).
static func _squeeze_reach(tool: Dictionary) -> float:
	var box: AABB = tool.get("box", AABB())
	var k := 0 if box.size.x <= box.size.y and box.size.x <= box.size.z else (1 if box.size.y <= box.size.z else 2)
	var broad := INF
	for i in 3:
		if i != k:
			broad = minf(broad, box.size[i])
	return broad * 0.5 * SQUEEZE_REACH if broad < INF else 0.0


## WHAT STANDS OVER SKIN [param sd] AS A PRESSED PAD TAKES ITS SHAPE ([constant PRESS_CELL]), found once as the table is built, as
## [method _obstacles] finds its own - `{at, n, z, cell, tex}` (`tex` its heights as a picture, far under it where nothing is,
## prop_common.gdshaderinc's `press_z`) - or its obstacles', where it was not found.
func _press_field(sd: Dictionary) -> Dictionary:
	var got: Dictionary = sd.get("press_field", {})
	if not got.is_empty():
		return got
	var g := _obstacles(sd)
	var faces := PackedVector3Array()
	var to_part: Transform3D = g["to_part"]
	for m in (work.things[int(sd["ti"])] as Dictionary)["meshes"]:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := to_part * work._world_of(mi)
		for v in mi.mesh.get_faces():
			faces.append(xf * v)
	var box: AABB = sd["box"]
	var at := Vector2(box.position.x, box.position.y) - Vector2.ONE * PRESS_BEYOND
	var n := Vector2i(ceili((box.size.x + PRESS_BEYOND * 2.0) / PRESS_CELL) + 1, ceili((box.size.y + PRESS_BEYOND * 2.0) / PRESS_CELL) + 1)
	var z := PackedFloat32Array()
	z.resize(n.x * n.y)
	z.fill(-INF)
	if not faces.is_empty():
		var top := -INF
		for v in faces:
			top = maxf(top, v.z)
		var tm := TableWork._ray_mesh(faces)
		for j in n.y:
			_breathe()
			for i in n.x:
				var hit := TableWork._ray(tm, Vector3(at.x + float(i) * PRESS_CELL, at.y + float(j) * PRESS_CELL, top + 0.01), Vector3(0.0, 0.0, -1.0))
				if not hit.is_empty():
					z[j * n.x + i] = (hit["position"] as Vector3).z
	var zs := z.duplicate()
	for i in zs.size():
		if zs[i] == -INF:
			zs[i] = -1.0
	var out := {"at": at, "n": n, "z": z, "cell": PRESS_CELL,
		"tex": ImageTexture.create_from_image(Image.create_from_data(n.x, n.y, false, Image.FORMAT_RF, zs.to_byte_array()))}
	sd["press_field"] = out
	return out


## A PAD OR A SPONGE'S MATERIAL [param mat] (on [param mesh]) TOLD IT IS PRESSED ONTO SKIN [param si] held [param h]
## (prop_common.gdshaderinc's `press_`, [method press_lands]): what stands over the skin as a picture of its heights ([method
## _press_field]), this mesh as it is drawn now into the skin's front as it stands now and back, and how it is pressed ([method _press_of]).
func _press_on(mat: ShaderMaterial, si: int, tool: Dictionary, h: Array, mesh: Node3D) -> void:
	var sd: Dictionary = skins[si]
	var g := _press_field(sd)
	var to_front := (work._world_of(sd["holder"]) * (sd["xform"] as Transform3D)).affine_inverse()
	var m_world := work._world_of(mesh)
	var node_to_front := to_front * work._world_of(tool["node"])
	var ps := _press_of(tool, h, node_to_front)
	var to_mesh := m_world.affine_inverse() * work._world_of(tool["node"])
	var at: Vector2 = g["at"]
	mat.set_shader_parameter("press_z", g["tex"])
	mat.set_shader_parameter("press_cells", Vector4(at.x, at.y, PRESS_CELL, float(ps["sag"])))
	mat.set_shader_parameter("press_in", to_front * m_world)
	mat.set_shader_parameter("press_out", (to_front * m_world).affine_inverse())
	mat.set_shader_parameter("press_tip", ps["tip"])
	mat.set_shader_parameter("press_up", ps["up"])
	mat.set_shader_parameter("press_up_own", (to_mesh.basis * (ps["up_own"] as Vector3)).normalized())


## WHERE VERTEX [param v] (facing [param n], its mesh's own space) OF A PAD OR A SPONGE IS DRAWN as its material [param mat] has it
## pressed onto skin [param si] ([method _press_on]; itself where it is not): prop_common.gdshaderinc's own arithmetic, for a gate to judge
## what is drawn.
func pressed_drawn(mat: ShaderMaterial, si: int, v: Vector3, n: Vector3) -> Vector3:
	var cells: Variant = mat.get_shader_parameter("press_cells")
	if not cells is Vector4 or (cells as Vector4).z <= 0.0:
		return v
	var as_xf := func(x: Variant) -> Transform3D: return x if x is Transform3D else Transform3D(x as Projection)
	var p_in: Transform3D = as_xf.call(mat.get_shader_parameter("press_in"))
	var p_out: Transform3D = as_xf.call(mat.get_shader_parameter("press_out"))
	var ps := {"tip": mat.get_shader_parameter("press_tip"), "up": mat.get_shader_parameter("press_up"),
		"up_own": (mat.get_shader_parameter("press_up_own") as Vector3).normalized(), "sag": (cells as Vector4).w}
	var lands := _press_point(_press_field(skins[si]), ps, p_in * v, n)
	return v if is_nan(lands.w) else p_out * Vector3(lands.x, lands.y, lands.z)


## TOOL [param tool], its node at [param node_w], PRESSED ONTO the level surface at [param floor_y] (the table's space): in its node's
## space, `[Vector4(the surface's normal toward it, how far along that the surface is), Vector3(how far the deepest of it went past it,
## the band over it that gives, how far it spreads - [constant FLAT_BAND], [constant FLAT_SPREAD]), the deepest of it]` - empty when
## none of it is past the surface. prop_common.gdshaderinc's `flat_on`, `flat_by` and `flat_at`.
static func _flat_on(node_w: Transform3D, floor_y: float, tool: Dictionary) -> Array:
	# a point's height over it is its node's `row` (the world's up, in the node's space) - scaled as the node is
	var row := Vector3(node_w.basis.x.y, node_w.basis.y.y, node_w.basis.z.y)
	var k := row.length()
	if k < 1e-6:
		return []
	var n := row / k
	var w := (floor_y - node_w.origin.y) / k
	var deep := 0.0
	var at := Vector3.ZERO
	var pts: PackedVector3Array = tool.get("points", PackedVector3Array())
	for q in pts:
		var d := w - n.dot(q)
		if d > deep:
			deep = d
			at = q
	if deep <= 0.0:
		return []
	return [Vector4(n.x, n.y, n.z, w), Vector3(deep, FLAT_BAND / k, FLAT_SPREAD), at]


## TOOL [param tool], its node at [param node_w], LAID OVER A POT'S MOUTH [param drape] (`Vector4(x, rim, z, how wide inside its wall)`, the
## table's space - [method _pot_hold]) and pressed [param press] (0-1) toward its paint's surface [param floor_y]: in its node's space, the
## way up and how high its face is (`on`), the mouth's middle and width (`at`), how far its face's middle goes down, its back further under
## the finger, how thick it is and how wide the finger presses (`by`) - prop_common.gdshaderinc's `drape_*` - and the paint's surface its
## middle is drawn flat on as it goes past it (`flat_on`, `flat_by`, `flat_at`, as [method _flat_on]'s).
static func _drape_on(node_w: Transform3D, drape: Vector4, floor_y: float, press: float, tool: Dictionary) -> Dictionary:
	var row := Vector3(node_w.basis.x.y, node_w.basis.y.y, node_w.basis.z.y)
	var k := maxf(row.length(), 1e-6)
	var n := row / k
	var lo := INF
	var hi := -INF
	for q in tool.get("points", PackedVector3Array()) as PackedVector3Array:
		lo = minf(lo, n.dot(q))
		hi = maxf(hi, n.dot(q))
	if lo == INF:
		lo = 0.0
		hi = 0.0
	var mid := node_w.affine_inverse() * Vector3(drape.x, drape.y, drape.z)
	var surface := floor_y if not is_nan(floor_y) else drape.y - DRAPE_CLEAR
	var down := (drape.y + DRAPE_CLEAR - surface + DRAPE_INTO) * clampf(press, 0.0, 1.0)
	var past := maxf(down - (drape.y + DRAPE_CLEAR - surface), 0.0)
	var face_mid := mid + n * (lo - n.dot(mid))
	var out := {"on": Vector4(n.x, n.y, n.z, lo), "at": Vector4(mid.x, mid.y, mid.z, drape.w / k),
		"by": Vector4(down / k, DRAPE_DENT * clampf(press, 0.0, 1.0) / k, maxf(hi - lo, 1e-4), DRAPE_FINGER),
		"flat_on": Vector4(n.x, n.y, n.z, (surface - node_w.origin.y) / k), "flat_by": Vector3.ZERO, "flat_at": face_mid}
	if past > 0.0 and not is_nan(floor_y):
		out["flat_by"] = Vector3(past / k, FLAT_BAND / k, FLAT_SPREAD)
	return out


# --- telling the agents -------------------------------------------------------------------------------

## WHAT CAN BE PAINTED and what paints, as the puppeteer reads it ([method TableWork.parts_report]).
func report() -> PackedStringArray:
	var out := PackedStringArray()
	for si in skins.size():
		var sd: Dictionary = skins[si]
		var nm := String(sd["name"]) + ("/" + String(sd["part"]) if not String(sd["part"]).is_empty() else "")
		var els: Array = (sd["design"] as Dictionary).get("elements", [])
		if els.is_empty():
			out.append("- \"%s\" has a surface to paint (its front, %d x %d mm), and no design for it yet" % [nm, roundi((sd["frame"] as Vector2).x), roundi((sd["frame"] as Vector2).y)])
			continue
		out.append("- \"%s\" has a surface to paint (`paint` with `on`: \"%s\"), and its design, %d elements in the order they go on:" % [nm, nm, els.size()])
		for e in els:
			var ed: Dictionary = e
			var r := Skins.bounds(ed, sd["frame"])
			var line := "    \"%s\" (%s): a %s in %s, %s, %d x %d mm" % [ed["id"], ed["stage"] if not String(ed["stage"]).is_empty() else "-", ed["kind"],
				ed["paint"], ed["finish"], roundi(r.size.x), roundi(r.size.y)]
			for m in ["brush", "sponge", "tool"]:
				var manner := Skins.manner_of(ed, m)
				var made := _made_for(si, ed, manner, 6.0 if m == "brush" else (Skins.width_for(m, 24.0, manner) if m == "sponge" else 20.0))
				line += "; %s %ds" % [{"brush": "a 6 mm brush", "sponge": "a sponge", "tool": "a puff"}[m] if not manner in ["line", "dab", "place"] else manner, roundi(float((made["program"] as Dictionary)["natural"]))]
				if manner in ["line", "dab", "place"]:
					break
			out.append(line)
	for ti in work.things.size():
		for w in (work.things[ti] as Dictionary)["works"]:
			var wk: Dictionary = work.works[int(w)]
			if String(wk["kind"]) != "free":
				continue
			var tufted := false
			for mi in (wk["node"] as Node).find_children("*", "MeshInstance3D", true, false):
				var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
				if mat != null and mat.has_meta("tuft"):
					var tf: Dictionary = mat.get_meta("tuft")
					out.append("- %s is a %s brush, %.0f mm across: it paints" % [work._part_label(int(w)), String(tf["kind"]), float(tf["mm"])])
					tufted = true
					break
			if tufted:
				continue
	return out


## WHAT AN ACT PAINTS, as `act` answers ([method TableWork.check]): each element, how long it takes at this act's pace, and
## what of each design is left unpainted by every act there is.
func said(act: Dictionary, t0: float, t1: float) -> PackedStringArray:
	var out := PackedStringArray()
	for tr in act["tracks"]:
		var t: Dictionary = tr
		if String(t["law"]) != "paint":
			continue
		var plan := plan_of(t, t1 - t0)
		var bits := PackedStringArray()
		for p in plan["phases"]:
			var pd: Dictionary = p
			if String(pd["kind"]) == "el":
				bits.append("\"%s\" %s in %.0f s" % [pd["el"], {"paint": "laid", "blend": "blended", "sweep": "swept"}.get(String(pd["role"]), ""), float(pd["b"]) - float(pd["a"])])
		var natural := float(plan["natural"])
		out.append("it paints: %s - %.0f s at a hand's own pace%s" % [", ".join(bits), natural,
			(" (hurried into %.0f s)" % (t1 - t0)) if t1 - t0 < natural * 0.95 else ""])
	return out


## WHETHER ANYTHING HERE RAISES [param look]: "dust" - a powder laid or swept, or anything patted on; "mist" - anything sprayed.
func raises(look := "dust") -> bool:
	for k in _layers:
		var si := int(String(k).get_slice("|", 0))
		var ed := element(si, String(k).get_slice("|", 1))
		var manner := String((_layers[k] as Dictionary)["manner"])
		if look == "mist" and manner == "spray":
			return true
		if look == "dust" and (manner == "pat" or String(ed.get("finish", "")) == "powder"):
			return true
	return false


## WHAT NO ACT LAYS, of every design on the table.
func unpainted() -> PackedStringArray:
	var out := PackedStringArray()
	for si in skins.size():
		for e in ((skins[si] as Dictionary)["design"] as Dictionary).get("elements", []):
			if not _layers.has("%d|%s" % [si, String((e as Dictionary)["id"]).to_lower()]):
				out.append(String((e as Dictionary)["id"]))
	return out

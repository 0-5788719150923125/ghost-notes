extends RefCounted
class_name Lights

## Lights - what lights a scene, and how that light moves: the SKY that fills it, a SUN (or the moon)
## that throws its shadows, what the sun falls THROUGH on its way (a window and its panes, blinds, a
## pierced screen, leaves, fronds or bare branches overhead, a pergola's slats, an awning, a
## parasol), the WEATHER between it and the table (clouds passing over it, birds crossing it), LAMPS
## out of the shot (candles, a torch, a fire, a lantern, a lamp, fluorescent tubes, neon, a screen's
## glow, a street lamp, passing headlights, a lighthouse's beam, lightning), and SHADOWS of things out
## of the shot (a roof beam, a pillar, a rope swinging, a chandelier, laundry on a line). An agent
## describes it as data - the registries' words are what it reads ([method describe]) - [method
## sanitize] makes whatever it wrote buildable, and [method build] makes the nodes. Generic: a host
## gives its STAGE ([method build]: its camera, the middle of its set, what stands there, what is in
## the shot, its room's picture), and the card table is the first host ([TableMedium]); the set
## dresser writes it as `light` (the user, 2026-10-07: "giving them a way to control both lighting
## and shadow... I would want to give the agents proper tooling, to create these vibes on its own").
##
## EVERYTHING IS A FUNCTION OF SHOW TIME ([method Rig.tick]): a cloud's passing, a bird's crossing, a
## leaf's stir and a flame's flicker are computed from the time and the seed, never stepped - so a
## render and a scrub see the same light.
##
## HOW IT IS MADE (Godot 4.7, measured 2026-10-07). The sun is a DirectionalLight3D. What it falls
## through is SHADOW-ONLY geometry standing up its ray from the table, on a render layer of its own
## ([constant SCREEN_LAYER], which no other light casts with): a wall with its window cut out, a canopy
## of leaves - holes cut by `discard` in a shader posed from show time (shaders/light_screen.gdshader),
## so the shade falls on the table, on everything on it, and through any fog; a bird is one too
## (shaders/light_bird.gdshader). Three things were tried first and dropped: a light's projector cannot
## be a ViewportTexture (Godot refuses it), a DirectionalLight3D ignores a projector, and a cloud as a
## DITHERED caster - partial shade from a shadow filter averaging holes - read as camouflage mottle at
## every filter quality. So A CLOUD DIMS THE SUN over everything at once, which is what a real one
## does at a table's scale: its edge is tens of meters wide and passes in seconds, the light sinking,
## the shadows softening and fading, not a line sweeping the cloth. The room's picture dims with it.
##
## THE CPU KNOWS WHAT IS DRAWN: every screen's pattern is [method _pattern], line for line the
## shader's, on noise both reckon alike ([method noise], shaders/light_noise.gdshaderinc) - so the
## set dresser is told how much of the table, and of where the cards lie, the sun reaches.
##
## A SHADOW OUT OF THE SHOT (`shadows`, the user, 2026-10-07: "a beam or a pillar might cast a permanent
## shadow over the table... a hanging rope might be gently swaying in the wind... a chandelier might cast
## shadows") is a thing built of silhouettes ([constant CASTER_SHAPES]: blocks, posts, balls, hoops,
## tubes, sheets, grilles, grouped and copied round or along), shadow-only on [constant CASTER_LAYER],
## which every light that casts casts with - the sun, a lamp. It is aimed by where its shadow falls and
## placed up its light's ray to throw it there ([method caster_place]), out of the shot and clear of the
## table. It stands still, SWINGS (a pendulum pushed by gusts - the sine of its angle, not the angle,
## pulls it back, so a big swing is slower than a small one: [method swing_at]), spins, or ripples
## (shaders/light_caster.gdshader). Not [Props]: those are a thing's surfaces at most 60 cm across; these
## are silhouettes that run to meters.

const SCREEN_SHADER := preload("res://shaders/light_screen.gdshader")
const BIRD_SHADER := preload("res://shaders/light_bird.gdshader")
const CASTER_SHADER := preload("res://shaders/light_caster.gdshader")

## The render layer the sun's screens and the birds are on: the sun casts with them, no other light
## does, and nothing draws them.
const SCREEN_LAYER := 1 << 18
## The render layer of the shadows out of the shot: every light that casts casts with them - the sun, a
## lamp of the light's own, the old lamp - and nothing draws them.
const CASTER_LAYER := 1 << 17

## WHERE A LIGHT COMES FROM, by name: degrees round the table seen from above, clockwise from the
## reader's own side - 0 from behind the reader, over their shoulder; 90 from their right; 180 from
## across the table, toward the camera; 270 from their left. A number is taken as degrees.
const FROM := {"front": 0.0, "front right": 45.0, "right": 90.0, "back right": 135.0, "back": 180.0,
	"back left": 225.0, "left": 270.0, "front left": 315.0}

## THE SUN, or the moon: its color and strength when none is given, and how soft its shadows are.
const SUNS := {
	"sun": {"about": "the sun - white at noon, golden and long-shadowed low in the sky", "color": "#fff1dc",
		"strength": 0.8, "softness": 0.2},
	"moon": {"about": "the moon - faint and cool", "color": "#b7c6ee", "strength": 0.3, "softness": 0.5},
}

## WHAT THE SUN FALLS THROUGH: in a WALL on the sun's side (its patch of sun lands where it is aimed,
## the rest of the table in the room's shade) or OVERHEAD (a canopy or a shade over the table). `code`
## is the shader's.
const SCREENS := {
	"window": {"about": "a window in the wall on the sun's side: the sun falls through it in a bright patch with the bars' shadows across it, the rest of the table in the room's shade", "wall": true, "code": 0},
	"blinds": {"about": "slatted blinds over a window: the sun falls through in stripes", "wall": true, "code": 1},
	"lattice": {"about": "a pierced screen over a window - a jali, a mashrabiya, a trellis, a shoji's grid: the sun falls through in its pattern", "wall": true, "code": 2},
	"leaves": {"about": "a tree's leaves overhead: dapples of sun that shift as the leaves stir", "wall": false, "code": 3},
	"fronds": {"about": "palm fronds, reeds or long grasses overhead: long blades of shade that sway", "wall": false, "code": 4},
	"branches": {"about": "bare branches overhead: a thin tangle of shadow", "wall": false, "code": 5},
	"slats": {"about": "a pergola's beams, a reed or palm-thatch shade, a slatted roof overhead: the sun falls through in bars", "wall": false, "code": 6},
	"awning": {"about": "a canvas awning or a roof's edge overhead: part or all of the table in its shade, the line of its edge across it, the bright day beyond", "wall": false, "code": 7},
	"parasol": {"about": "a parasol or a market umbrella over the table: a round shade", "wall": false, "code": 8},
}

## A LATTICE'S PATTERN, in the shader's order.
const LATTICES := {
	"grid": "square openings - a trellis, a shoji's grid",
	"diamonds": "squares turned as diamonds - a lattice window",
	"hexes": "hexagons - a honeycomb screen",
	"circles": "round holes - a pierced metal or stone screen",
	"stars": "eight-pointed stars - a mashrabiya, a jali",
}

## A BIRD: its span (m), its real speed (m/s: an agent's `speed` 1, and 0 a third of it - at a real
## pigeon's speed its shadow is over the table for two frames), how often its wings beat (a second) and
## the share of the time it glides, its silhouette (the bird shader's `shape`), how many fly together,
## and how it flies - straight across, darting, fluttering, or circling high (its shadow wheeling back
## over the table).
const BIRDS := {
	"gull": {"about": "gulls - long narrow wings, gliding, a beat now and then", "span": 1.1, "speed": 9.0, "beat": 2.2,
		"glide": 0.7, "shape": 0, "flock": [1, 3], "path": "straight"},
	"crow": {"about": "crows or ravens - broad fingered wings, steady beats", "span": 0.95, "speed": 10.0, "beat": 3.4,
		"glide": 0.2, "shape": 1, "flock": [1, 2], "path": "straight"},
	"pigeon": {"about": "pigeons or doves - quick beats, low over the roofs", "span": 0.65, "speed": 12.0, "beat": 5.5,
		"glide": 0.15, "shape": 0, "flock": [1, 6], "path": "straight"},
	"swallow": {"about": "swallows or swifts - small, fast, darting", "span": 0.32, "speed": 14.0, "beat": 7.0,
		"glide": 0.4, "shape": 2, "flock": [1, 4], "path": "dart"},
	"hawk": {"about": "a hawk or a kite circling high - its shadow wheeling back across the table again and again", "span": 1.25,
		"speed": 6.0, "beat": 1.5, "glide": 0.9, "shape": 1, "flock": [1, 1], "path": "circle"},
	"heron": {"about": "a heron or an egret - huge, slow wingbeats", "span": 1.7, "speed": 8.0, "beat": 1.6,
		"glide": 0.25, "shape": 1, "flock": [1, 1], "path": "straight"},
	"bat": {"about": "bats at dusk - small, fluttering, erratic", "span": 0.3, "speed": 7.0, "beat": 9.0,
		"glide": 0.0, "shape": 3, "flock": [1, 5], "path": "flutter"},
	"starlings": {"about": "a flock of starlings or sparrows - many small birds passing together", "span": 0.38, "speed": 13.0,
		"beat": 6.0, "glide": 0.3, "shape": 0, "flock": [8, 16], "path": "straight"},
}

## A LAMP OUT OF THE SHOT: a point of light (`omni`) or one aimed at the table (`spot`), its color and
## strength when none is given, how it flickers ([method flicker]), how wide its glow is (cm - its
## shadows' softness), whether it casts by default, where it stands when not told (cm from the
## table's middle, and above it), and how often it comes when it comes and goes (`every`, seconds).
const LAMPS := {
	"candles": {"about": "a few candles burning somewhere in the room - a warm, gently shifting fill", "kind": "omni",
		"color": "#ffb066", "strength": 0.25, "flicker": "candle", "size": 2.0, "shadows": false, "distance": 120.0, "height": 30.0},
	"torch": {"about": "a torch on a wall or a post - bright and ragged, its light and its shadows dancing", "kind": "omni",
		"color": "#ff9440", "strength": 0.6, "flicker": "torch", "size": 6.0, "shadows": true, "distance": 150.0, "height": 90.0},
	"fire": {"about": "an open fire, a hearth or a brazier - low and deep orange, pulsing slowly, crackling", "kind": "omni",
		"color": "#ff7a30", "strength": 0.55, "flicker": "fire", "size": 8.0, "shadows": true, "distance": 170.0, "height": 15.0},
	"lantern": {"about": "an oil lantern - warm and nearly steady", "kind": "omni", "color": "#ffbf73", "strength": 0.45,
		"flicker": "lantern", "size": 3.0, "shadows": false, "distance": 110.0, "height": 60.0},
	"lamp": {"about": "an electric lamp with a shade - steady and warm, its light falling across the table", "kind": "spot",
		"color": "#ffd6a0", "strength": 0.5, "flicker": "steady", "size": 4.0, "shadows": true, "distance": 110.0, "height": 70.0},
	"hanging lamp": {"about": "a shaded lamp hanging over the table, out of the frame - a steady pool of light", "kind": "spot",
		"color": "#ffdcb0", "strength": 0.7, "flicker": "steady", "size": 4.0, "shadows": true, "distance": 45.0, "height": 85.0},
	"fluorescent": {"about": "fluorescent tubes overhead - cool, flat and steady, now and then a stutter", "kind": "omni",
		"color": "#e8f0ff", "strength": 0.5, "flicker": "fluorescent", "size": 8.0, "shadows": false, "distance": 80.0, "height": 160.0},
	"neon": {"about": "a neon sign in the room or outside a window - one saturated color, steady, now and then a stutter",
		"kind": "omni", "color": "#ff3d7f", "strength": 0.4, "flicker": "neon", "size": 6.0, "shadows": false, "distance": 180.0, "height": 70.0},
	"screen": {"about": "a television's or a monitor's glow - cool, its brightness and color changing with each cut", "kind": "spot",
		"color": "#b8d0ff", "strength": 0.35, "flicker": "screen", "size": 8.0, "shadows": false, "distance": 200.0, "height": 40.0},
	"street lamp": {"about": "a street lamp outside - sodium orange or cold white, steady, from high up", "kind": "spot",
		"color": "#ffa040", "strength": 0.5, "flicker": "steady", "size": 6.0, "shadows": true, "distance": 300.0, "height": 250.0},
	"headlights": {"about": "a car's headlights passing outside now and then, their light sweeping across the table", "kind": "spot",
		"color": "#f4f4ff", "strength": 0.6, "flicker": "pass", "size": 5.0, "shadows": true, "distance": 350.0, "height": 40.0, "every": 40.0},
	"lighthouse": {"about": "a lighthouse's beam sweeping round, crossing the table every few seconds", "kind": "spot",
		"color": "#fff6e0", "strength": 0.6, "flicker": "beam", "size": 5.0, "shadows": false, "distance": 600.0, "height": 120.0, "every": 10.0},
	"lightning": {"about": "a storm's lightning - now and then a blue-white flash, two or three flickers at once, the room lit by it",
		"kind": "omni", "color": "#dfe8ff", "strength": 1.0, "flicker": "lightning", "size": 0.0, "shadows": false, "distance": 500.0,
		"height": 400.0, "every": 25.0},
}

## A SHADOW OUT OF THE SHOT is made of these silhouettes, in centimeters, up to [constant CASTER_SIZE]
## (a roof beam runs six meters). A part's `at` is where its middle goes.
const CASTER_SHAPES := {
	"box": "a block {\"size\": [x, y, z]} - a beam, a plank, a sign, a shelf, a fan's blade",
	"cylinder": "an upright post {\"radius\", \"height\", \"radius2\" (its top - a taper, a cone)} - a pillar, a pole, a lampshade, a bell, a bucket",
	"ball": "{\"size\": [x, y, z]} - a globe, a gourd, a hanging ball, a cage's dome",
	"ring": "a hoop lying flat {\"radius\", \"thickness\"} - a chandelier's hoop, a wreath, a dreamcatcher",
	"tube": "a rope, a chain, a cord, an arm or a vine along {\"path\": [[x, y, z], ...], \"radius\"}",
	"sheet": "a thin panel standing upright {\"size\": [width, height]} - laundry on a line, a flag, a banner, a sign (it can ripple)",
	"grille": "a flat grid of bars standing upright {\"size\": [width, height], \"cell\", \"bars\"} - a cage's side, a gate, a rack, a lantern's pierced wall",
}
## HOW A SHADOW OUT OF THE SHOT MOVES.
const CASTER_MOVES := {
	"still": "it does not move - a beam, a pillar, a sign",
	"swing": "it hangs from its top and swings in the wind as a pendulum does - a rope, a lantern or a chandelier on its chain, a hanging basket, a cage; `amount` from barely stirring (0.1) to swinging hard (1)",
	"spin": "it turns about its middle, upright - a ceiling fan's blades, a mobile, a weathervane; `speed` from a slow turn to a fan's blur",
	"flutter": "its sheets ripple - laundry, a flag, a banner, prayer flags; `amount` from a stir to a snapping wind",
}

## The most of each: screens the sun falls through, lamps, lamps that cast (a shadow each - a cube of
## six passes for a point of light), and birds in the air at once.
const MAX_SCREENS := 3
const MAX_LAMPS := 4
const MAX_SHADOWED := 2
const MAX_BIRDS := 16
## ...shadows out of the shot, the parts one is written with (every part in every group), the parts it is
## built with (every copy of every part), the copies a part makes, and how big a silhouette may be (cm).
const MAX_CASTERS := 4
const MAX_CASTER_PARTS := 24
const MAX_CASTER_MESHES := 96
const MAX_CASTER_COPIES := 16
const CASTER_SIZE := 600.0
## A SWING, simulated ([method swing_at]): its step (seconds), how often a step is kept, and how fast a
## swing dies away (the share of critical damping: well under 1 so a gust still swings it, but high enough
## that a push leans it to one side and it settles there, instead of ringing back and forth for a minute).
const SWING_STEP := 1.0 / 120.0
const SWING_KEEP := 4
const SWING_DAMP := 0.55
## A sun through a wall stands no higher than this (degrees): a higher sun hardly reaches into a room,
## and its wall would stand over the table.
const WALL_SUN := 65.0

## THE LIGHT'S STRENGTH, in the engine's terms (calibrated by eye on the card table, 2026-10-07): the
## sun's energy at strength 1; the sky's at strength 1, and the share of it that comes from above (a
## light with no shadow, so things are modeled from the top as an open sky models them) - a clear day's
## sun lights a table four or five times as much as its sky; THE EXPOSURE: the most the palest thing in
## the light may take, its lightness times the sun and the sky on it (as [constant TableMedium.HEAT]
## holds a candle's pool) - both brought down together past it, so the day keeps its contrast; a lamp's
## light at the table's middle at strength 1, and its cap.
const SUN_MAX := 2.6
const SKY_MAX := 0.6
const SKY_TOP := 0.35
const SUN_HEAT := 1.05
const LAMP_IRR := 1.3
const LAMP_HEAT := 1.25
## What leads the light: a sun or a lamp lighting the table at least this much (its energy where the
## cards are) leads it, and the candles burn as fills.
const LEAD_MIN := 0.35
## How far ahead birds, cuts, stutters and flashes are planned (seconds): longer than any reading.
const HORIZON := 7200.0
## A CLOUD OVER THE SUN GLOWS: this share of the sunlight it holds back comes back as the sky's (a sunlit
## cloud is the brightest thing in the sky), so a thick one leaves the table about a stop darker, its
## shadows gone - not a dimmer turned down.
const CLOUD_GLOW := 0.25
## How far over the table a bird's shadow-caster flies, and over everything standing an overhead
## screen hangs (meters): what fixes their place, not how they look - the light is parallel.
const BIRD_UP := 1.3
const OVERHEAD := 0.35
## How far past everything standing a wall stands, on the sun's side (meters).
const WALL_CLEAR := 0.25
## The shutter a bird's shadow is smeared over (seconds).
const SHUTTER := 1.0 / 250.0
## How big a wall and a canopy are (meters): past every ray from the table to the sun.
const WALL := Vector2(30.0, 16.0)
const CANOPY := 40.0


# --- the vocabulary ---------------------------------------------------------------------------------

## THE VOCABULARY, as an agent reads it.
static func describe() -> String:
	var lines := PackedStringArray()
	lines.append("THE LIGHT (`light`): {\"why\", \"sky\", \"sun\", \"through\", \"clouds\", \"birds\", \"lamps\", \"shadows\"} - every part may be left out. Light never shows in the picture as a thing: only what it does to the table.")
	lines.append("- why: a few words - what lights this table, where, and when.")
	lines.append("- sky: {\"color\": \"#rrggbb\", \"strength\" 0-1} - the light that fills everything and throws no shadow. Outdoors the open sky: by day bright (0.5 to 1), its color the sky's - pale blue, white under cloud, apricot at dawn. Within a room the room's own light: dim (0.1 to 0.4), the color of its walls. At night 0 to 0.1.")
	lines.append("- sun: {\"look\", \"from\", \"height\", \"color\", \"strength\" 0-1, \"softness\" 0-1} - the light that throws the shadows. Leave it out for a table no sun reaches: an overcast day (the sky alone), a room lit by its lamps, night. look:")
	for k in SUNS:
		lines.append("  - %s: %s" % [k, String((SUNS[k] as Dictionary)["about"])])
	lines.append("  from: where it is - front (behind the reader, over their shoulder), front right, right, back right, back (across the table, toward the camera: the shadows fall toward the viewer), back left, left, front left; or degrees round the table from front (0) through right (90). height: degrees above the horizon - 5, the first or last light, golden, every shadow long, to 85, noon in the tropics, the shadows short. softness: 0 crisp (clear dry air) to 1 soft (haze).")
	lines.append("- through: [what the sun falls through on its way to the table - at most %d], each {\"name\", \"kind\", ...}:" % MAX_SCREENS)
	for k in SCREENS:
		lines.append("  - %s: %s" % [k, String((SCREENS[k] as Dictionary)["about"])])
	lines.append("  A window, blinds or a lattice: {\"at\": [x, z] (cm from the middle of the reading - where the middle of its patch of sun lands), \"size\": [width, height] (cm, the opening), and for a window \"panes\": [across, up] and \"bars\" (cm); for blinds \"slats\" (cm apart), \"open\" 0-1 and \"turn\" (0 slats across, 90 upright); for a lattice \"pattern\" (%s), \"cell\" (cm) and \"bars\" (cm)}. Its wall stands on the sun's side: a low sun throws a long patch, a high one a short one; a sun through a wall stands no higher than %d." % [", ".join(PackedStringArray(LATTICES.keys())), int(WALL_SUN)])
	lines.append("  Leaves, fronds or branches: {\"cover\" 0-1 (how much of the sun they hold back), \"size\" (cm - a cluster of leaves, a blade, how far apart the twigs are), \"sway\" 0-1 (how much they stir: 0 still air, 1 a gusty breeze)}. Slats: {\"slats\" (cm apart), \"open\" 0-1, \"turn\" (degrees, their run: 0 side to side)}. An awning: {\"cover\" 0-1 (how much of the table you see lies in its shade - 1 all of it), \"turn\" (degrees: its edge's line), \"edge\" (\"straight\" or \"scalloped\"), \"color\" (its canvas, which tints the light under it), \"sway\" 0-1}. A parasol: {\"at\" (the middle of its shade), \"size\" (cm across), \"ribs\", \"color\", \"sway\"}.")
	lines.append("- clouds: {\"cover\" 0-1 (how much of the sky they fill: 0.1 a few passing, 0.5 broken, 0.9 heavy with breaks the sun comes through, 1 overcast), \"size\" 0-1 (small puffs to great banks: how long each passing lasts), \"speed\" 0-1 (drifting to racing), \"thickness\" 0-1 (a thin veil the shadows soften under, to a thick cloud they vanish under)}. As a cloud passes over the sun the whole table dims over a few seconds, its shadows softening and fading, then the sun comes back - what a real cloud does to a table. Leave clouds out for a clear sky.")
	lines.append("- birds: {\"look\", \"every\" (seconds between them, about), \"flock\" (how many fly together), \"speed\" 0-1, \"from\" (where they mostly fly from; left out, anywhere)} - now and then a bird's shadow flicks across the table and is gone; the bird is never seen. looks:")
	for k in BIRDS:
		lines.append("  - %s: %s" % [k, String((BIRDS[k] as Dictionary)["about"])])
	lines.append("- lamps: [lights round the table, out of the shot - at most %d], each {\"name\", \"look\", \"from\", \"distance\" (cm from the middle of the table), \"height\" (cm above it), \"color\", \"strength\" 0-1, \"shadows\" true or false (at most %d cast), \"every\" (seconds, for what comes and goes)} - never seen, only felt: their light, its color and flicker and, when they cast them, their shadows across the table. A lamp the camera could see is moved up out of the shot. looks:" % [MAX_LAMPS, MAX_SHADOWED])
	for k in LAMPS:
		lines.append("  - %s: %s" % [k, String((LAMPS[k] as Dictionary)["about"])])
	lines.append("- shadows: [things out of the shot that throw a shadow on the table - at most %d], each {\"name\", \"what\", \"parts\", \"shadow\": [x, z] (cm from the middle of the reading - where the middle of its shadow falls), \"height\" (cm over the table - how high its middle is: a roof beam 200, a lantern on its chain 120), \"turn\" (degrees about the upright), \"by\" (\"sun\", or the name of a lamp that casts: whose shadow it is - the sun when left out), \"around\" (the name of a lamp it hangs round - a chandelier round its candles, a pierced lantern round its flame: that lamp's own light throws its shadow, from the origin [0, 0, 0] of its parts, so draw the thing round the flame: what hangs below it - a hoop, arms, a cage's bars - throws its shadow down on the table), \"move\": {\"kind\", \"amount\" 0-1, \"speed\" 0-1}} - never seen, only its shadow: a beam's bar of shade, a pillar's long stripe, a rope swinging across the cloth, a chandelier's arms spread over the table. It is set up its light's ray, out of the shot and clear of the table, so its shadow falls where it is aimed." % MAX_CASTERS)
	lines.append("  Its parts are silhouettes in centimeters, at most %d: each {\"shape\", \"at\": [x, y, z] (where its middle goes), \"turn\" ([x, y, z] degrees, or one number about the upright), \"copies\"} - or a group {\"parts\": [...], \"at\", \"turn\", \"copies\"}, two deep at most. \"copies\": {\"around\": {\"count\", \"radius\"}} repeats it round the upright (a chandelier's arms, a fan's blades), {\"line\": {\"count\", \"step\": [x, y, z]}} in a row (beams across a ceiling, a railing's posts, laundry on a line). Up is +y; a hanging thing hangs from its highest point. shapes:" % MAX_CASTER_PARTS)
	for k in CASTER_SHAPES:
		lines.append("  - %s: %s" % [k, String(CASTER_SHAPES[k])])
	lines.append("  move:")
	for k in CASTER_MOVES:
		lines.append("  - %s: %s" % [k, String(CASTER_MOVES[k])])
	lines.append("The candles on the table burn in this light whatever it is: by day small and warm, at dusk and at night they lead.")
	return "\n".join(lines)


# --- made safe ----------------------------------------------------------------------------------------

## WHATEVER AN AGENT WROTE as `light`, as something [method build] can make: known looks and kinds only,
## every number in range, every color a color, every direction in degrees ([constant FROM]), the caps
## kept (screens, lamps, lamps that cast, birds, shadows and their parts), every shadow given a light to
## throw it. Not written - or not an object - is `{}`: no light of its own (a host lights itself as it
## always did). What had to change is said in [param notes].
static func sanitize(raw: Variant, notes: PackedStringArray = PackedStringArray()) -> Dictionary:
	if raw == null:
		return {}
	if not (raw is Dictionary):
		notes.append("the light was not an object {sky, sun, through, ...} - left out")
		return {}
	var d: Dictionary = raw
	if d.is_empty():
		return {}
	var out := {"why": Props._text(d.get("why", ""), 200)}
	var sky: Dictionary = d.get("sky", {}) if d.get("sky") is Dictionary else {}
	out["sky"] = {"color": Props._color(sky.get("color", ""), "#8f9bb0"), "strength": Props._num(sky.get("strength"), 0.3, 0.0, 1.0)}
	if d.has("sky") and not (d.get("sky") is Dictionary) and d.get("sky") != null:
		notes.append("the sky was not an object {color, strength} - a dim gray one stands in")
	out["sun"] = {}
	if d.get("sun") is Dictionary:
		out["sun"] = _sun(d["sun"], notes)
	elif d.get("sun") != null:
		notes.append("the sun was not an object {look, from, height, ...} - no sun")
	var through: Array = []
	var walls := false
	for e in (d.get("through", []) if d.get("through") is Array else []):
		if not (e is Dictionary):
			notes.append("something the sun falls through was not an object {name, kind, ...} - left out")
			continue
		if through.size() >= MAX_SCREENS:
			notes.append("past %d screens the sun falls through: \"%s\" and the rest left out" % [MAX_SCREENS, str((e as Dictionary).get("name", ""))])
			break
		var sc := _screen(e as Dictionary, notes)
		if sc.is_empty():
			continue
		if (out["sun"] as Dictionary).is_empty():
			notes.append("\"%s\": there is no sun to fall through it - left out" % String(sc["name"]))
			continue
		walls = walls or bool((SCREENS[String(sc["kind"])] as Dictionary)["wall"])
		through.append(sc)
	out["through"] = through
	if walls and float((out["sun"] as Dictionary)["height"]) > WALL_SUN:
		notes.append("a sun through a wall stands no higher than %d degrees: lowered from %d" % [int(WALL_SUN), roundi(float((out["sun"] as Dictionary)["height"]))])
		(out["sun"] as Dictionary)["height"] = WALL_SUN
	out["clouds"] = {}
	if d.get("clouds") is Dictionary:
		var c: Dictionary = d["clouds"]
		var cover := Props._num(c.get("cover"), 0.3, 0.0, 1.0)
		if cover > 0.001:
			out["clouds"] = {"cover": cover, "size": Props._num(c.get("size"), 0.5, 0.0, 1.0),
				"speed": Props._num(c.get("speed"), 0.4, 0.0, 1.0), "thickness": Props._num(c.get("thickness"), 0.7, 0.0, 1.0)}
			if (out["sun"] as Dictionary).is_empty():
				notes.append("clouds pass over the sun, and there is none: they only darken the sky's light")
	out["birds"] = {}
	if d.get("birds") is Dictionary:
		out["birds"] = _birds(d["birds"], notes)
		if not (out["birds"] as Dictionary).is_empty() and (out["sun"] as Dictionary).is_empty():
			notes.append("a bird's shadow is the sun's: with no sun, the birds were left out")
			out["birds"] = {}
	var lamps: Array = []
	var cast := 0
	for e in (d.get("lamps", []) if d.get("lamps") is Array else []):
		if not (e is Dictionary):
			notes.append("a lamp that was not an object {name, look, ...} was left out")
			continue
		if lamps.size() >= MAX_LAMPS:
			notes.append("past %d lamps: \"%s\" and the rest left out" % [MAX_LAMPS, str((e as Dictionary).get("name", ""))])
			break
		var l := _lamp(e as Dictionary, notes)
		if l.is_empty():
			continue
		if bool(l["shadows"]):
			if cast >= MAX_SHADOWED:
				l["shadows"] = false
				notes.append("\"%s\" casts no shadows: at most %d lamps do" % [String(l["name"]), MAX_SHADOWED])
			else:
				cast += 1
		lamps.append(l)
	out["lamps"] = lamps
	var casters: Array = []
	for e in (d.get("shadows", []) if d.get("shadows") is Array else []):
		if not (e is Dictionary):
			notes.append("a shadow that was not an object {name, parts, ...} was left out")
			continue
		if casters.size() >= MAX_CASTERS:
			notes.append("past %d shadows: \"%s\" and the rest left out" % [MAX_CASTERS, str((e as Dictionary).get("name", ""))])
			break
		var c := _caster(e as Dictionary, out, notes)
		if not c.is_empty():
			casters.append(c)
	out["shadows"] = casters
	return out


static func _sun(s: Dictionary, notes: PackedStringArray) -> Dictionary:
	var look := String(s.get("look", "sun")).strip_edges().to_lower() if s.get("look") is String else "sun"
	if not SUNS.has(look):
		notes.append("\"%s\" is not a sun: %s - the sun" % [look, ", ".join(PackedStringArray(SUNS.keys()))])
		look = "sun"
	var base: Dictionary = SUNS[look]
	return {"look": look, "from": _from(s.get("from"), 270.0, "the %s" % look, notes),
		"height": Props._num(s.get("height"), 40.0, 5.0, 85.0), "color": Props._color(s.get("color", ""), String(base["color"])),
		"strength": Props._num(s.get("strength"), float(base["strength"]), 0.0, 1.0),
		"softness": Props._num(s.get("softness"), float(base["softness"]), 0.0, 1.0)}


static func _screen(e: Dictionary, notes: PackedStringArray) -> Dictionary:
	var kind := String(e.get("kind", "")).strip_edges().to_lower() if e.get("kind") is String else ""
	if not SCREENS.has(kind):
		notes.append("\"%s\" is not something the sun falls through: %s" % [kind, ", ".join(PackedStringArray(SCREENS.keys()))])
		return {}
	var s := {"name": Props._text(e.get("name", kind), 80), "kind": kind, "at": _at(e.get("at")),
		"sway": Props._num(e.get("sway"), 0.35 if kind in ["leaves", "fronds"] else 0.15, 0.0, 1.0)}
	if String(s["name"]).is_empty():
		s["name"] = kind
	match kind:
		"window", "blinds", "lattice":
			s["size"] = _pair(e.get("size"), Vector2(110.0, 140.0), Vector2(30.0, 30.0), Vector2(400.0, 400.0))
			s["bars"] = Props._num(e.get("bars"), 4.0 if kind == "window" else (3.0 if kind == "blinds" else 2.0), 0.0, 20.0)
			if kind == "window":
				var p := _pair(e.get("panes"), Vector2(2.0, 3.0), Vector2(1.0, 1.0), Vector2(8.0, 8.0))
				s["panes"] = [roundf(float(p[0])), roundf(float(p[1]))]
			elif kind == "blinds":
				s["slats"] = Props._num(e.get("slats"), 6.0, 1.5, 30.0)
				s["open"] = Props._num(e.get("open"), 0.5, 0.05, 0.95)
				s["turn"] = Props._num(e.get("turn"), 0.0, -90.0, 90.0)
			else:
				var pat := String(e.get("pattern", "grid")).strip_edges().to_lower() if e.get("pattern") is String else "grid"
				if not LATTICES.has(pat):
					notes.append("\"%s\": \"%s\" is not a lattice's pattern: %s - grid" % [String(s["name"]), pat, ", ".join(PackedStringArray(LATTICES.keys()))])
					pat = "grid"
				s["pattern"] = pat
				s["cell"] = Props._num(e.get("cell"), 10.0, 2.0, 60.0)
				s["bars"] = minf(float(s["bars"]), float(s["cell"]) * 0.45)
		"leaves", "fronds", "branches":
			s["cover"] = Props._num(e.get("cover"), 0.5, 0.05, 0.95)
			s["size"] = Props._num(e.get("size"), 14.0 if kind == "leaves" else (10.0 if kind == "fronds" else 25.0), 2.0, 80.0)
		"slats":
			s["slats"] = Props._num(e.get("slats"), 20.0, 3.0, 120.0)
			s["open"] = Props._num(e.get("open"), 0.55, 0.05, 0.95)
			s["turn"] = Props._num(e.get("turn"), 0.0, -180.0, 180.0)
		"awning":
			s["cover"] = Props._num(e.get("cover"), 0.7, 0.0, 1.0)
			s["turn"] = Props._num(e.get("turn"), 0.0, -90.0, 90.0)
			var edge := String(e.get("edge", "straight")).strip_edges().to_lower() if e.get("edge") is String else "straight"
			s["edge"] = edge if edge in ["straight", "scalloped"] else "straight"
			s["color"] = Props._color(e.get("color", ""), "#d8d0c0")
		"parasol":
			s["size"] = Props._num(e.get("size"), 220.0, 80.0, 500.0)
			s["ribs"] = roundf(Props._num(e.get("ribs"), 8.0, 4.0, 16.0))
			s["color"] = Props._color(e.get("color", ""), "#e8e0d0")
	return s


static func _birds(b: Dictionary, notes: PackedStringArray) -> Dictionary:
	var look := String(b.get("look", "")).strip_edges().to_lower() if b.get("look") is String else ""
	if not BIRDS.has(look):
		notes.append("\"%s\" is not a bird: %s - no birds" % [look, ", ".join(PackedStringArray(BIRDS.keys()))])
		return {}
	var base: Dictionary = BIRDS[look]
	var flock := int(Props._num(b.get("flock"), float((base["flock"] as Array)[0]), 1.0, float(MAX_BIRDS)))
	return {"look": look, "every": Props._num(b.get("every"), 45.0, 6.0, 900.0), "flock": flock,
		"speed": Props._num(b.get("speed"), 0.5, 0.0, 1.0),
		"from": _from(b.get("from"), -1.0, "the birds", notes) if b.get("from") != null else -1.0}


static func _lamp(e: Dictionary, notes: PackedStringArray) -> Dictionary:
	var look := String(e.get("look", "")).strip_edges().to_lower() if e.get("look") is String else ""
	var name := Props._text(e.get("name", look), 80)
	if not LAMPS.has(look):
		notes.append("\"%s\": \"%s\" is not a lamp: %s - left out" % [name, look, ", ".join(PackedStringArray(LAMPS.keys()))])
		return {}
	var base: Dictionary = LAMPS[look]
	var l := {"name": name if not name.is_empty() else look, "look": look,
		"from": _from(e.get("from"), 270.0, "\"%s\"" % name, notes),
		"distance": Props._num(e.get("distance"), float(base["distance"]), 40.0, 900.0),
		"height": Props._num(e.get("height"), float(base["height"]), -60.0, 500.0),
		"color": Props._color(e.get("color", ""), String(base["color"])),
		"strength": Props._num(e.get("strength"), float(base["strength"]), 0.0, 1.0),
		"shadows": Props._flag(e.get("shadows"), bool(base["shadows"]))}
	if base.has("every"):
		l["every"] = Props._num(e.get("every"), float(base["every"]), 3.0, 600.0)
	return l


## A SHADOW OUT OF THE SHOT, made safe: its parts as silhouettes ([method _caster_parts]), where its
## shadow is aimed and how high it hangs, how it moves - and the light that throws it: round a lamp, that
## lamp's (`around`); else the one named in `by` when it is a lamp that casts, else the sun, else the first
## lamp that casts. With none, it is left out. [param light] is the light made safe so far (its sun and lamps).
static func _caster(e: Dictionary, light: Dictionary, notes: PackedStringArray) -> Dictionary:
	var name := Props._text(e.get("name", ""), 80)
	if name.is_empty():
		name = "a shadow"
	var parts := _caster_parts(e.get("parts"), 0, [MAX_CASTER_PARTS], name, notes)
	if parts.is_empty():
		notes.append("\"%s\" has nothing that can throw a shadow - left out" % name)
		return {}
	var mv: Variant = e.get("move", {})
	var move: Dictionary = mv if mv is Dictionary else ({"kind": mv} if mv is String else {})
	var kind := String(move.get("kind", "still")).strip_edges().to_lower() if move.get("kind") is String else "still"
	if not CASTER_MOVES.has(kind):
		notes.append("\"%s\": \"%s\" is not a way to move (%s) - still" % [name, kind, ", ".join(PackedStringArray(CASTER_MOVES.keys()))])
		kind = "still"
	var c := {"name": name, "what": Props._text(e.get("what", ""), 160), "parts": parts, "shadow": _at(e.get("shadow")),
		"height": Props._num(e.get("height"), 160.0, 10.0, CASTER_SIZE), "turn": Props._num(e.get("turn"), 0.0, -180.0, 180.0),
		"move": {"kind": kind, "amount": Props._num(move.get("amount"), 0.3, 0.0, 1.0), "speed": Props._num(move.get("speed"), 0.3, 0.0, 1.0)},
		"by": "", "around": ""}
	var around := _lamp_named(light, e.get("around"))
	if not around.is_empty():
		c["around"] = String(around["name"])
		if not bool(around["shadows"]):
			notes.append("\"%s\" hangs round \"%s\", which casts no shadows: its shade throws none until that lamp's `shadows` is true" % [name, String(around["name"])])
		return c
	if e.get("around") is String and not String(e["around"]).strip_edges().is_empty():
		notes.append("\"%s\": there is no lamp called \"%s\" to hang round" % [name, String(e["around"])])
	var sun: Dictionary = light.get("sun", {})
	var by := String(e.get("by", "")).strip_edges() if e.get("by") is String else ""
	if not by.is_empty() and by.to_lower() != "sun":
		var l := _lamp_named(light, by)
		if not l.is_empty() and bool(l["shadows"]):
			c["by"] = String(l["name"])
			return c
		notes.append("\"%s\": \"%s\" is not a lamp that casts - %s throws its shadow" % [name, by, "the sun" if not sun.is_empty() else "another light"])
	if not sun.is_empty():
		c["by"] = "sun"
		return c
	for l in light.get("lamps", []):
		if bool((l as Dictionary)["shadows"]):
			c["by"] = String((l as Dictionary)["name"])
			return c
	notes.append("\"%s\": no light throws its shadow - give the table a sun, or a lamp with `shadows`; left out" % name)
	return {}


## The lamp of [param light] named [param v] (any case), or {}.
static func _lamp_named(light: Dictionary, v: Variant) -> Dictionary:
	var want := String(v).strip_edges().to_lower() if v is String else ""
	if want.is_empty():
		return {}
	for l in light.get("lamps", []):
		if String((l as Dictionary)["name"]).to_lower() == want:
			return l
	return {}


## A SHADOW'S PARTS made safe: known shapes only, every size in range ([constant CASTER_SIZE]), groups two
## deep at most, and no more parts than [param budget] (one number in an array, spent as parts are kept).
static func _caster_parts(raw: Variant, depth: int, budget: Array, name: String, notes: PackedStringArray) -> Array:
	var out: Array = []
	for p in (raw if raw is Array else []):
		if int(budget[0]) <= 0:
			notes.append("\"%s\": past %d parts - the rest left out" % [name, MAX_CASTER_PARTS])
			break
		if not (p is Dictionary):
			notes.append("\"%s\": a part that was not an object {shape, ...} was left out" % name)
			continue
		var d: Dictionary = p
		var part := {"at": Props._vec3(d.get("at"), Vector3.ZERO, CASTER_SIZE), "turn": Props._turn(d.get("turn")),
			"copies": _caster_copies(d.get("copies"))}
		if d.get("parts") is Array:
			if depth >= 2:
				notes.append("\"%s\": a group more than two deep was left out" % name)
				continue
			part["parts"] = _caster_parts(d["parts"], depth + 1, budget, name, notes)
			if not (part["parts"] as Array).is_empty():
				out.append(part)
			continue
		var shape := String(d.get("shape", "")).strip_edges().to_lower() if d.get("shape") is String else ""
		if not CASTER_SHAPES.has(shape):
			notes.append("\"%s\": \"%s\" is not a shape a shadow is made of (%s) - left out" % [name, shape, ", ".join(PackedStringArray(CASTER_SHAPES.keys()))])
			continue
		part["shape"] = shape
		match shape:
			"box":
				part["size"] = Props._vec3(d.get("size"), Vector3(100.0, 10.0, 10.0), CASTER_SIZE, 0.2)
			"cylinder":
				part["radius"] = Props._num(d.get("radius"), 5.0, 0.1, CASTER_SIZE * 0.5)
				part["height"] = Props._num(d.get("height"), 100.0, 0.2, CASTER_SIZE)
				part["radius2"] = Props._num(d.get("radius2"), float(part["radius"]), 0.0, CASTER_SIZE * 0.5)
			"ball":
				part["size"] = Props._vec3(d.get("size"), Vector3(12.0, 12.0, 12.0), CASTER_SIZE, 0.2)
			"ring":
				part["radius"] = Props._num(d.get("radius"), 30.0, 0.5, CASTER_SIZE * 0.5)
				part["thickness"] = Props._num(d.get("thickness"), 2.0, 0.2, 60.0)
			"tube":
				var path := Props._points3(d.get("path"), CASTER_SIZE)
				if path.size() < 2:
					notes.append("\"%s\": a tube's path needs two [x, y, z] points or more - left out" % name)
					continue
				part["path"] = path
				part["radius"] = Props._num(d.get("radius"), 1.0, 0.1, 40.0)
			"sheet":
				var sz := _pair(d.get("size"), Vector2(80.0, 60.0), Vector2(1.0, 1.0), Vector2(CASTER_SIZE, CASTER_SIZE))
				part["size"] = Vector2(float(sz[0]), float(sz[1]))
			"grille":
				var gz := _pair(d.get("size"), Vector2(60.0, 60.0), Vector2(2.0, 2.0), Vector2(CASTER_SIZE, CASTER_SIZE))
				part["size"] = Vector2(float(gz[0]), float(gz[1]))
				part["cell"] = Props._num(d.get("cell"), 10.0, 1.0, CASTER_SIZE)
				part["bars"] = minf(Props._num(d.get("bars"), 1.0, 0.2, 30.0), float(part["cell"]) * 0.8)
		budget[0] = int(budget[0]) - 1
		out.append(part)
	return out


## A part's copies made safe: {kind: "around" (round the upright, `radius` out) or "line" (each `step`
## on), count}; {} for one.
static func _caster_copies(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	if d.get("around") is Dictionary:
		var a: Dictionary = d["around"]
		return {"kind": "around", "count": int(Props._num(a.get("count"), 6.0, 1.0, float(MAX_CASTER_COPIES))),
			"radius": Props._num(a.get("radius"), 0.0, 0.0, CASTER_SIZE)}
	if d.get("line") is Dictionary:
		var l: Dictionary = d["line"]
		return {"kind": "line", "count": int(Props._num(l.get("count"), 3.0, 1.0, float(MAX_CASTER_COPIES))),
			"step": Props._vec3(l.get("step"), Vector3(50.0, 0.0, 0.0), CASTER_SIZE)}
	return {}


## A direction as degrees round the table ([constant FROM]): a name, or a number; [param fallback]
## (said in [param notes], about [param what]) when it is neither.
static func _from(v: Variant, fallback: float, what: String, notes: PackedStringArray) -> float:
	if v is float or v is int:
		return fposmod(float(v), 360.0)
	if v is String:
		var s := (v as String).strip_edges().to_lower()
		if FROM.has(s):
			return float(FROM[s])
		if s.is_valid_float():
			return fposmod(s.to_float(), 360.0)
		notes.append("%s: \"%s\" is not a direction (%s, or degrees)" % [what, s, ", ".join(PackedStringArray(FROM.keys()))])
	elif v != null:
		notes.append("%s: its direction is not a name or degrees" % what)
	return fallback


## [x, z] centimeters on the table, within reach of the reading.
static func _at(v: Variant) -> Array:
	var a: Array = v if v is Array else []
	return [Props._num(a[0] if a.size() > 0 else 0.0, 0.0, -90.0, 90.0), Props._num(a[1] if a.size() > 1 else 0.0, 0.0, -60.0, 60.0)]


static func _pair(v: Variant, fallback: Vector2, lo: Vector2, hi: Vector2) -> Array:
	var a: Array = v if v is Array else []
	return [Props._num(a[0] if a.size() > 0 else null, fallback.x, lo.x, hi.x), Props._num(a[1] if a.size() > 1 else null, fallback.y, lo.y, hi.y)]


## A direction's name for [param deg] - the nearest of [constant FROM].
static func from_name(deg: float) -> String:
	var best := "front"
	var gap := INF
	for k in FROM:
		var g := absf(angle_difference(deg_to_rad(deg), deg_to_rad(float(FROM[k]))))
		if g < gap:
			gap = g
			best = String(k)
	return best


## THE LIGHT IN A LINE, as a report and an earlier episode's record say it.
static func summary(light: Dictionary) -> String:
	if light.is_empty():
		return ""
	var parts := PackedStringArray()
	var sun: Dictionary = light.get("sun", {})
	if not sun.is_empty():
		var through := PackedStringArray()
		for s in light.get("through", []):
			through.append("%s (%s)" % [String((s as Dictionary)["name"]), String((s as Dictionary)["kind"])])
		parts.append("the %s from the %s, %d degrees up%s%s" % [String(sun["look"]), from_name(float(sun["from"])), roundi(float(sun["height"])),
			", soft" if float(sun["softness"]) > 0.55 else "", (" through " + ", ".join(through)) if not through.is_empty() else ""])
	else:
		parts.append("no sun")
	var sky: Dictionary = light.get("sky", {})
	var k := float(sky.get("strength", 0.3))
	parts.append("a %s sky, %s" % ["bright" if k >= 0.6 else ("dim" if k < 0.25 else "soft"), String(sky.get("color", ""))])
	var clouds: Dictionary = light.get("clouds", {})
	if not clouds.is_empty():
		parts.append("clouds over %d%% of the sky" % roundi(float(clouds["cover"]) * 100.0))
	var birds: Dictionary = light.get("birds", {})
	if not birds.is_empty():
		parts.append("%s every %d s or so" % [String(birds["look"]), roundi(float(birds["every"]))])
	for l in light.get("lamps", []):
		var d: Dictionary = l
		parts.append("%s (%s, %s%s)" % [String(d["name"]), String(d["look"]), from_name(float(d["from"])), ", casting" if bool(d["shadows"]) else ""])
	for c in light.get("shadows", []):
		var d: Dictionary = c
		var kind := String((d["move"] as Dictionary)["kind"])
		parts.append("the shadow of %s (%s%s)" % [String(d["name"]), {"still": "still", "swing": "swinging", "spin": "turning", "flutter": "rippling"}[kind],
			(", round " + String(d["around"])) if not String(d["around"]).is_empty() else ((", by " + String(d["by"])) if String(d["by"]) != "sun" else "")])
	return "; ".join(parts)


# --- where it is ---------------------------------------------------------------------------------------

## THE SUN'S DIRECTION for [param sun] (made safe): a unit vector from the table toward it, in the
## table's space (x to the reader's right, y up, z toward the reader).
static func sun_dir(sun: Dictionary) -> Vector3:
	var a := deg_to_rad(float(sun.get("from", 270.0)))
	var e := deg_to_rad(float(sun.get("height", 40.0)))
	return Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))


## WHERE EACH SCREEN STANDS for a set whose top is at y = 0 and whose reading's middle is [param middle],
## everything on it within [param bounds], the table the camera sees sampled at [param seen] (for an
## awning's edge): `[{screen, origin, bx, by, normal, u}]` - its plane, its own x and y axes, and `u`,
## what its shader is set to ([method _uniforms]). Every point of a screen lies up the sun's ray from the
## table; a wall stands past everything on the sun's side, a canopy over everything.
static func screens_of(light: Dictionary, middle: Vector3, bounds: AABB, seen: PackedVector3Array, seed: int) -> Array:
	var sun: Dictionary = light.get("sun", {})
	var out: Array = []
	if sun.is_empty():
		return out
	var s := sun_dir(sun)
	var sh := Vector3(s.x, 0.0, s.z).normalized()
	var flat := maxf(Vector2(s.x, s.z).length(), 0.02)
	var through: Array = light.get("through", [])
	for i in through.size():
		var sc: Dictionary = through[i]
		var at := middle + Vector3(float((sc["at"] as Array)[0]) * 0.01, 0.0, float((sc["at"] as Array)[1]) * 0.01)
		var g := {"screen": sc}
		if bool((SCREENS[String(sc["kind"])] as Dictionary)["wall"]):
			var reach := 0.0
			for k in 8:
				reach = maxf(reach, (bounds.get_endpoint(k) - at).dot(sh))
			g["origin"] = at + s * ((reach + WALL_CLEAR) / flat)
			g["by"] = Vector3.UP
			g["normal"] = sh
			g["bx"] = Vector3(sh.z, 0.0, -sh.x)
		else:
			var up := maxf(bounds.end.y, 0.0) + OVERHEAD
			g["origin"] = at + s * (up / maxf(s.y, 0.05))
			g["normal"] = Vector3.UP
			if String(sc["kind"]) == "awning":
				# its y runs from the sunlit side into the shade: the sun comes in under its free edge
				var into := (-sh).rotated(Vector3.UP, -deg_to_rad(float(sc["turn"])))
				g["by"] = into
				g["bx"] = into.cross(Vector3.UP)
			else:
				g["bx"] = Vector3.RIGHT
				g["by"] = Vector3.FORWARD
		g["u"] = _uniforms(sc, hash([seed, i, String(sc["name"])]) & 0x7FFFFFFF)
		if String(sc["kind"]) == "awning":
			(g["u"] as Dictionary)["edge"] = _awning_edge(g, s, seen, float(sc["cover"]))
		out.append(g)
	return out


## WHAT A SCREEN'S SHADER IS SET TO, from its description - and what [method _pattern] reads, so the two
## reckon alike. Meters and radians.
static func _uniforms(sc: Dictionary, salt: int) -> Dictionary:
	var kind := String(sc["kind"])
	var u := {"kind": int((SCREENS[kind] as Dictionary)["code"]), "salt": salt, "sway": float(sc.get("sway", 0.0)),
		"opening": Vector2(1.1, 1.4), "panes": Vector2(2.0, 3.0), "bars": 0.04, "spacing": 0.06, "open": 0.5, "turn": 0.0,
		"lattice": 0, "cell": 0.1, "thr": 2.0, "size": 0.12, "edge": 0.0, "scallop": 0.0, "radius": 1.1, "ribs": 8.0}
	match kind:
		"window", "blinds", "lattice":
			u["opening"] = Vector2(float((sc["size"] as Array)[0]), float((sc["size"] as Array)[1])) * 0.01
			u["bars"] = float(sc["bars"]) * 0.01
			if kind == "window":
				u["panes"] = Vector2(float((sc["panes"] as Array)[0]), float((sc["panes"] as Array)[1]))
			elif kind == "blinds":
				u["spacing"] = float(sc["slats"]) * 0.01
				u["open"] = float(sc["open"])
				u["turn"] = deg_to_rad(float(sc["turn"]))
			else:
				u["lattice"] = LATTICES.keys().find(String(sc["pattern"]))
				u["cell"] = float(sc["cell"]) * 0.01
		"leaves", "fronds", "branches":
			u["size"] = float(sc["size"]) * 0.01
			u["thr"] = threshold(kind, float(sc["cover"]))
		"slats":
			u["spacing"] = float(sc["slats"]) * 0.01
			u["open"] = float(sc["open"])
			u["turn"] = deg_to_rad(float(sc["turn"]))
		"awning":
			u["scallop"] = 0.28 if String(sc["edge"]) == "scalloped" else 0.0
		"parasol":
			u["radius"] = float(sc["size"]) * 0.005
			u["ribs"] = float(sc["ribs"])
	return u


## AN AWNING'S EDGE, along its own y: where it lies so that [param cover] of the table the camera sees
## ([param seen]) is in its shade.
static func _awning_edge(g: Dictionary, s: Vector3, seen: PackedVector3Array, cover: float) -> float:
	if seen.is_empty():
		return 0.0
	var ys := PackedFloat32Array()
	for p in seen:
		ys.append(_plane_q(g, s, p).y)
	ys.sort()
	if cover >= 0.999:
		return ys[0] - 10.0
	if cover <= 0.001:
		return ys[ys.size() - 1] + 10.0
	return ys[clampi(int((1.0 - cover) * ys.size()), 0, ys.size() - 1)]


## Where the sun's ray from [param p] crosses screen [param g]'s plane, in its own coordinates.
static func _plane_q(g: Dictionary, s: Vector3, p: Vector3) -> Vector2:
	var n: Vector3 = g["normal"]
	var o: Vector3 = g["origin"]
	var mu := (o - p).dot(n) / (s.dot(n) if absf(s.dot(n)) > 1e-5 else 1e-5)
	var x := p + s * mu - o
	return Vector2(x.dot(g["bx"]), x.dot(g["by"]))


## WHETHER THE SUN REACHES [param p] (on or over the table) at show time [param t] through every screen in
## [param geom] ([method screens_of]) - the clouds and the birds aside.
static func sunlit(geom: Array, s: Vector3, p: Vector3, t: float) -> bool:
	for g in geom:
		if _pattern(g["u"], _plane_q(g, s, p), t):
			return false
	return true


## THE SHARE OF [param points] the sun reaches at [param t] ([method sunlit]).
static func coverage(geom: Array, s: Vector3, points: PackedVector3Array, t: float) -> float:
	if points.is_empty():
		return 1.0
	var n := 0
	for p in points:
		n += 1 if sunlit(geom, s, p, t) else 0
	return float(n) / float(points.size())


## A SCREEN'S PATTERN at [param q] (its own coordinates, meters) and show time [param t]: true where it
## holds the sun back. shaders/light_screen.gdshader's `shaded()`, line for line.
static func _pattern(u: Dictionary, q: Vector2, t: float) -> bool:
	var kind := int(u["kind"])
	var opening: Vector2 = u["opening"]
	var bars := float(u["bars"])
	var salt := int(u["salt"])
	if kind <= 2:
		if absf(q.x) > opening.x * 0.5 or absf(q.y) > opening.y * 0.5:
			return true
		if minf(opening.x * 0.5 - absf(q.x), opening.y * 0.5 - absf(q.y)) < bars * 0.5:
			return true
		if kind == 0:
			var r := q + opening * 0.5
			var c := opening / (u["panes"] as Vector2).max(Vector2.ONE)
			var m := r - c * (r / c).floor()
			var dd := m.min(c - m)
			return minf(dd.x, dd.y) < bars * 0.5
		if kind == 1:
			var r := _turned(q, float(u["turn"]))
			var spacing := float(u["spacing"])
			var y := r.y + float(u["sway"]) * spacing * 0.15 * sin(0.9 * t + r.x * 2.0)
			return _fract(y / spacing) >= float(u["open"])
		return _lattice_bar(u, q)
	var size := float(u["size"])
	if kind == 3:
		return fbm((q + _stir(u, q, t)) / size, salt) > float(u["thr"])
	if kind == 4:
		var p := q + _stir(u, q, t)
		var best := 0.0
		for k in 3:
			var r := _turned(p, float(k) * 1.0471976 + 0.4)
			best = maxf(best, fbm(Vector2(r.x / (size * 3.0), r.y / (size * 0.6)), (salt + k * 77) & 0xFFFFFFFF))
		return best > float(u["thr"])
	if kind == 5:
		return 1.0 - absf(2.0 * fbm((q + _stir(u, q, t) * 0.4) / size, salt) - 1.0) > float(u["thr"])
	if kind == 6:
		return _fract(_turned(q, float(u["turn"])).y / float(u["spacing"])) >= float(u["open"])
	if kind == 7:
		var e := float(u["edge"]) + float(u["sway"]) * 0.012 * sin(2.3 * t + q.x * 4.0)
		var sc := float(u["scallop"])
		if sc > 0.0:
			var w := (q.x - sc * floorf(q.x / sc)) / sc * 2.0 - 1.0
			e -= sc * 0.35 * sqrt(maxf(1.0 - w * w, 0.0))
		return q.y > e
	var a := atan2(q.y, q.x)
	var sector := TAU / float(u["ribs"])
	var local := a - sector * (floorf(a / sector) + 0.5)
	var radius := float(u["radius"])
	var rr := radius * cos(sector * 0.5) / cos(local)
	rr -= radius * 0.04 * cos(local / (sector * 0.5) * 1.5707963)
	rr += float(u["sway"]) * 0.01 * sin(1.7 * t + a * 3.0)
	return q.length() < rr


static func _lattice_bar(u: Dictionary, q: Vector2) -> bool:
	var lattice := int(u["lattice"])
	var cell := float(u["cell"])
	var bars := float(u["bars"])
	if lattice == 1:
		q = _turned(q, 0.78539816)
	if lattice <= 1:
		var m := q - Vector2(cell, cell) * (q / cell).floor()
		var dd := m.min(Vector2(cell, cell) - m)
		return minf(dd.x, dd.y) < bars * 0.5
	if lattice == 2:
		var s := Vector2(1.0, 1.7320508) * cell
		var a := q - s * (q / s + Vector2(0.5, 0.5)).floor()
		var b := (q - s * 0.5) - s * ((q - s * 0.5) / s + Vector2(0.5, 0.5)).floor()
		var g := (a if a.dot(a) < b.dot(b) else b).abs()
		return maxf(g.x, g.dot(Vector2(0.5, 0.8660254))) > cell * 0.5 - bars * 0.5
	var mm := q - Vector2(cell, cell) * ((q / cell).floor() + Vector2(0.5, 0.5))
	if lattice == 3:
		return mm.length() > cell * 0.5 - bars * 0.5
	var sq := maxf(absf(mm.x), absf(mm.y))
	var di := (absf(mm.x) + absf(mm.y)) * 0.70710678
	return minf(sq, di) > (cell * 0.5 - bars) * 0.82


static func _stir(u: Dictionary, q: Vector2, t: float) -> Vector2:
	var size := float(u["size"])
	var salt := int(u["salt"])
	var swing := Vector2(sin(0.53 * t + 1.3) + 0.5 * sin(1.37 * t + 0.4), sin(0.41 * t + 0.2) + 0.5 * sin(1.13 * t + 2.1))
	var flutter := Vector2(noise(q / size * 1.7 + Vector2(t * 0.9, 0.0), (salt + 7) & 0xFFFFFFFF),
		noise(q / size * 1.7 + Vector2(0.0, t * 0.8), (salt + 11) & 0xFFFFFFFF)) - Vector2(0.5, 0.5)
	return (swing * 0.22 + flutter * 0.45) * float(u["sway"]) * size


static func _turned(p: Vector2, a: float) -> Vector2:
	return Vector2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y)


static func _fract(x: float) -> float:
	return x - floorf(x)


# --- noise both reckon alike --------------------------------------------------------------------------

static func _hash(x: int) -> int:
	x &= 0xFFFFFFFF
	x ^= x >> 15
	x = (x * 739982445) & 0xFFFFFFFF
	x ^= x >> 12
	x = (x * 695872825) & 0xFFFFFFFF
	x ^= x >> 15
	return x


static func _cell(x: int, y: int, salt: int) -> float:
	return float(_hash(_hash((x & 0xFFFFFFFF) ^ salt) ^ (y & 0xFFFFFFFF)) & 65535) / 65535.0


## Value noise at [param p] (0..1), on [param salt] - shaders/light_noise.gdshaderinc's `lnoise`.
static func noise(p: Vector2, salt: int) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - f * 2.0)
	var x := int(i.x)
	var y := int(i.y)
	return lerpf(lerpf(_cell(x, y, salt), _cell(x + 1, y, salt), u.x), lerpf(_cell(x, y + 1, salt), _cell(x + 1, y + 1, salt), u.x), u.y)


## Four octaves of it - `lfbm` - or fewer, for a smoother field.
static func fbm(p: Vector2, salt: int, octaves := 4) -> float:
	var s := 0.0
	var a := 0.5
	var total := 0.0
	for k in octaves:
		s += a * noise(p, (salt + k * 1013) & 0xFFFFFFFF)
		total += a
		p = Vector2(p.x * 1.6 - p.y * 1.2, p.x * 1.2 + p.y * 1.6) + Vector2(5.3, 1.7)
		a *= 0.5
	return s / total


static var _quantiles := {}

## THE NOISE LEVEL ABOVE WHICH [param cover] OF A CANOPY IS SHADE, for [param kind]'s pattern (leaves,
## fronds, branches, or "clouds"): read off the pattern's own spread of values, sampled once.
static func threshold(kind: String, cover: float) -> float:
	if cover <= 0.001:
		return 2.0
	if cover >= 0.999:
		return -1.0
	if not _quantiles.has(kind):
		var r := RandomNumberGenerator.new()
		r.seed = 7331
		var vals := PackedFloat32Array()
		for i in 4096:
			var p := Vector2(r.randf_range(-400.0, 400.0), r.randf_range(-400.0, 400.0))
			var salt := r.randi() & 0x7FFFFFFF
			match kind:
				"fronds":
					var best := 0.0
					for k in 3:
						var q := _turned(p, float(k) * 1.0471976 + 0.4)
						best = maxf(best, fbm(Vector2(q.x / 3.0, q.y / 0.6), (salt + k * 77) & 0xFFFFFFFF))
					vals.append(best)
				"branches":
					vals.append(1.0 - absf(2.0 * fbm(p, salt) - 1.0))
				"clouds":
					vals.append(fbm(p, salt, 2))
				_:
					vals.append(fbm(p, salt))
		vals.sort()
		_quantiles[kind] = vals
	var v: PackedFloat32Array = _quantiles[kind]
	return v[clampi(int((1.0 - cover) * v.size()), 0, v.size() - 1)]


# --- shadows out of the shot ----------------------------------------------------------------------------

## A SHADOW'S MESHES: every part of [param parts] placed, its groups opened and copied - `[{mesh, xform,
## sheet}]`, in meters, in the thing's own space (`sheet`: a sheet's height, for its ripple; 0 otherwise),
## at most [constant MAX_CASTER_MESHES].
static func caster_meshes(parts: Array, base := Transform3D.IDENTITY, out: Array = []) -> Array:
	for p in parts:
		var d: Dictionary = p
		var own := base * Transform3D(Basis.from_euler((d["turn"] as Vector3) * (PI / 180.0)), (d["at"] as Vector3) * 0.01)
		for cx in _copy_xforms(d.get("copies", {})):
			var here: Transform3D = own * (cx as Transform3D)
			if d.has("parts"):
				caster_meshes(d["parts"], here, out)
				continue
			for m in _shape_meshes(d):
				if out.size() >= MAX_CASTER_MESHES:
					return out
				out.append({"mesh": (m as Dictionary)["mesh"], "xform": here * ((m as Dictionary)["xform"] as Transform3D),
					"sheet": float((m as Dictionary).get("sheet", 0.0))})
	return out


## Each copy's place in its part's own frame: round the upright (`radius` out first), or along `step`.
static func _copy_xforms(c: Dictionary) -> Array:
	var out: Array = []
	match String(c.get("kind", "")):
		"around":
			var n := int(c["count"])
			for k in n:
				out.append(Transform3D(Basis(Vector3.UP, TAU * float(k) / float(n)), Vector3.ZERO)
					* Transform3D(Basis.IDENTITY, Vector3(float(c["radius"]) * 0.01, 0.0, 0.0)))
		"line":
			for k in int(c["count"]):
				out.append(Transform3D(Basis.IDENTITY, (c["step"] as Vector3) * 0.01 * float(k)))
		_:
			out.append(Transform3D.IDENTITY)
	return out


## One silhouette part as meshes, each with its place in the part's frame (meters).
static func _shape_meshes(d: Dictionary) -> Array:
	match String(d["shape"]):
		"box":
			var b := BoxMesh.new()
			b.size = (d["size"] as Vector3) * 0.01
			return [{"mesh": b, "xform": Transform3D.IDENTITY}]
		"cylinder":
			var c := CylinderMesh.new()
			c.bottom_radius = float(d["radius"]) * 0.01
			c.top_radius = float(d["radius2"]) * 0.01
			c.height = float(d["height"]) * 0.01
			c.radial_segments = 16
			c.rings = 1
			return [{"mesh": c, "xform": Transform3D.IDENTITY}]
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			return [{"mesh": s, "xform": Transform3D(Basis.from_scale((d["size"] as Vector3) * 0.01), Vector3.ZERO)}]
		"ring":
			var t := TorusMesh.new()
			var r := float(d["radius"]) * 0.01
			var th := float(d["thickness"]) * 0.01
			t.inner_radius = maxf(r - th * 0.5, 0.0005)
			t.outer_radius = r + th * 0.5
			t.rings = 32
			t.ring_segments = 8
			return [{"mesh": t, "xform": Transform3D.IDENTITY}]
		"tube":
			# a post along each stretch of the path, and a ball at every bend, so a rope has no gaps
			var out: Array = []
			var path: Array = d["path"]
			var rad := float(d["radius"]) * 0.01
			for i in path.size() - 1:
				var a: Vector3 = (path[i] as Vector3) * 0.01
				var b: Vector3 = (path[i + 1] as Vector3) * 0.01
				var along := b - a
				if along.length() < 1e-4:
					continue
				var seg := CylinderMesh.new()
				seg.top_radius = rad
				seg.bottom_radius = rad
				seg.height = along.length()
				seg.radial_segments = 8
				seg.rings = 1
				out.append({"mesh": seg, "xform": Transform3D(Basis(Quaternion(Vector3.UP, along.normalized())), (a + b) * 0.5)})
				if i > 0:
					var joint := SphereMesh.new()
					joint.radius = rad
					joint.height = rad * 2.0
					joint.radial_segments = 8
					joint.rings = 4
					out.append({"mesh": joint, "xform": Transform3D(Basis.IDENTITY, a)})
			return out
		"sheet":
			var sh := BoxMesh.new()
			var sz: Vector2 = d["size"]
			sh.size = Vector3(sz.x, sz.y, 0.4) * 0.01
			sh.subdivide_width = 24
			sh.subdivide_height = 12
			return [{"mesh": sh, "xform": Transform3D.IDENTITY, "sheet": sz.y * 0.01}]
		"grille":
			# its bars, upright and across, no more than a couple of dozen each way
			var out: Array = []
			var sz: Vector2 = (d["size"] as Vector2) * 0.01
			var cell := maxf(float(d["cell"]) * 0.01, maxf(sz.x, sz.y) / 24.0)
			var bar := float(d["bars"]) * 0.01
			var nx := maxi(1, roundi(sz.x / cell))
			var ny := maxi(1, roundi(sz.y / cell))
			for i in nx + 1:
				var up := BoxMesh.new()
				up.size = Vector3(bar, sz.y, bar)
				out.append({"mesh": up, "xform": Transform3D(Basis.IDENTITY, Vector3(-sz.x * 0.5 + sz.x * float(i) / float(nx), 0.0, 0.0))})
			for j in ny + 1:
				var across := BoxMesh.new()
				across.size = Vector3(sz.x, bar, bar)
				out.append({"mesh": across, "xform": Transform3D(Basis.IDENTITY, Vector3(0.0, -sz.y * 0.5 + sz.y * float(j) / float(ny), 0.0))})
			return out
	return []


## The bounds of [param meshes] ([method caster_meshes]) in the thing's own space.
static func meshes_box(meshes: Array) -> AABB:
	var box := AABB()
	var first := true
	for m in meshes:
		var b: AABB = ((m as Dictionary)["xform"] as Transform3D) * ((m as Dictionary)["mesh"] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## WHERE A SHADOW OUT OF THE SHOT HANGS: [param c] (made safe; built as [param meshes]) set so the light
## that throws it ([param light]: the sun's direction is [method sun_dir]; a lamp's place is in [param
## lamps_at], by name) throws its middle's shadow where it is aimed - up the sun's ray, or on the line from
## the aim to the lamp - at its height. Then, along that same ray (so its shadow stays where it was
## aimed), it is raised clear of everything on the table ([param stage] `bounds`) and out of the shot
## (`in_shot`). ROUND ITS LAMP, its own origin - [0, 0, 0] of its parts - is the lamp's flame: a
## chandelier's hoop drawn round the origin has its candles' light at its heart, and its arms' shadows
## spread from there. `{xform (its own space to the world), middle, top, box, moved}` - `top` its highest
## point, what it hangs from.
static func caster_place(c: Dictionary, meshes: Array, light: Dictionary, stage: Dictionary, lamps_at: Dictionary) -> Dictionary:
	var box := meshes_box(meshes)
	var mid_local := box.get_center()
	var turn := Basis(Vector3.UP, deg_to_rad(float(c["turn"])))
	var middle: Vector3 = stage.get("middle", Vector3.ZERO)
	var aim := middle + Vector3(float((c["shadow"] as Array)[0]) * 0.01, 0.0, float((c["shadow"] as Array)[1]) * 0.01)
	var h := float(c["height"]) * 0.01
	var mid := aim + Vector3(0.0, h, 0.0)
	var moved := false
	if not String(c["around"]).is_empty():
		var flame: Vector3 = lamps_at.get(String(c["around"]), mid)
		var round_xf := Transform3D(turn, flame)
		return {"xform": round_xf, "middle": round_xf * mid_local, "top": round_xf * Vector3(mid_local.x, box.end.y, mid_local.z),
			"box": round_xf * box, "moved": false}
	else:
		var by := String(c["by"])
		var lamp: Variant = lamps_at.get(by) if by != "sun" else null
		var s := sun_dir(light.get("sun", {})) if by == "sun" else Vector3.UP
		var bounds: AABB = stage.get("bounds", AABB(middle - Vector3(1.0, 0.1, 0.6), Vector3(2.0, 0.6, 1.2)))
		var in_shot: Callable = stage.get("in_shot", Callable())
		for i in 80:
			if lamp is Vector3:
				# on the line from the aim to the lamp, a little short of the lamp
				var ly := maxf((lamp as Vector3).y - middle.y, 0.05)
				mid = aim + ((lamp as Vector3) - aim) * clampf(h / ly, 0.0, 0.92)
			else:
				mid = aim + s * (h / maxf(s.y, 0.05))
			var placed := Transform3D(turn, mid - turn * mid_local) * box
			if not placed.intersects(bounds.grow(0.04)) and not _box_seen(placed, in_shot):
				break
			h += 0.1
			moved = true
	var xf := Transform3D(turn, mid - turn * mid_local)
	return {"xform": xf, "middle": mid, "top": xf * Vector3(mid_local.x, box.end.y, mid_local.z), "box": xf * box, "moved": moved}


## Whether any of [param box] is in the shot: its corners, its edges' middles and its middle tried.
static func _box_seen(box: AABB, in_shot: Callable) -> bool:
	if not in_shot.is_valid():
		return false
	for ix in 3:
		for iy in 3:
			for iz in 3:
				if bool(in_shot.call(box.position + box.size * Vector3(ix, iy, iz) * 0.5)):
					return true
	return false


## THE OUTLINES OF A SHADOW on the table (x by z, meters): each placed part's box ([param meshes] under
## [param xf]) thrown along its light - the sun's direction [param s], or from the lamp at [param from] -
## onto the table's top (y = [param floor_y]), the convex hull of where it lands; one outline a part, so
## two beams are two bars of shade with the sun between them. A part that falls nowhere on the table's
## plane has none.
static func caster_outlines(meshes: Array, xf: Transform3D, s: Vector3, from: Variant = null, floor_y := 0.0) -> Array:
	var out: Array = []
	for m in meshes:
		var mesh: Mesh = (m as Dictionary)["mesh"]
		var to_world: Transform3D = xf * ((m as Dictionary)["xform"] as Transform3D)
		var boxes: Array = []
		if mesh is TorusMesh:
			# A HOOP IS HOLLOW: its outline is the segments round its circle, not the disc they enclose
			var tm := mesh as TorusMesh
			var mid_r := (tm.inner_radius + tm.outer_radius) * 0.5
			var half := (tm.outer_radius - tm.inner_radius) * 0.5
			for k in 24:
				var a0 := TAU * float(k) / 24.0
				var a1 := TAU * float(k + 1) / 24.0
				var p0 := Vector3(cos(a0), 0.0, sin(a0)) * mid_r
				var p1 := Vector3(cos(a1), 0.0, sin(a1)) * mid_r
				boxes.append(to_world * AABB(p0.min(p1) - Vector3(half, half, half), (p1 - p0).abs() + Vector3(half, half, half) * 2.0))
		else:
			boxes.append(to_world * mesh.get_aabb())
		for b in boxes:
			out.append_array(_box_outline(b, s, from, floor_y))
	return out


## One box's shadow on the table's plane, as an outline in an array - empty when it falls nowhere.
static func _box_outline(b: AABB, s: Vector3, from: Variant, floor_y: float) -> Array:
	var pts := PackedVector2Array()
	for k in 8:
		var p := b.get_endpoint(k)
		if from is Vector3:
			var l: Vector3 = from
			if p.y >= l.y - 1e-3:
				continue
			var q := l + (p - l) * ((l.y - floor_y) / (l.y - p.y))
			pts.append(Vector2(q.x, q.z))
		elif s.y > 1e-3:
			var q := p - s * ((p.y - floor_y) / s.y)
			pts.append(Vector2(q.x, q.z))
	return [Geometry2D.convex_hull(pts)] if pts.size() >= 3 else []


## Whether [param p] (x, z) lies in any of [param outlines] ([method caster_outlines]).
static func in_outlines(outlines: Array, p: Vector2) -> bool:
	for o in outlines:
		if (o as PackedVector2Array).size() >= 3 and Geometry2D.is_point_in_polygon(p, o):
			return true
	return false


## A SWING, made ready: a pendulum [param length] meters from what it hangs from to its middle, pushed by a
## wind of [param amount] (0-1) whose gusts come from [param salt]. [method swing_at] steps it on.
static func swing_of(length: float, amount: float, salt: int) -> Dictionary:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.seed = salt & 0x7FFF
	var r := RandomNumberGenerator.new()
	r.seed = salt
	return {"g_l": 9.81 / maxf(length, 0.05), "amount": amount, "noise": n, "dir": r.randf() * TAU,
		"theta": Vector2.ZERO, "omega": Vector2.ZERO, "t": 0.0, "steps": 0, "kept": PackedVector2Array([Vector2.ZERO])}


## THE SWING'S ANGLES at show time [param t] (radians: toward +x, toward +z). A pendulum: the SINE of its
## angle pulls it back, so a wide swing is slower than a narrow one - nonlinear, as a rope or a chandelier
## really swings - lightly damped, and pushed by the wind's lean, its slow turns and its gusts, which
## build the swing up and let it die back. STEPPED from show time 0 at a fixed step and kept every
## [constant SWING_KEEP] steps, extended only as far as it has been asked: any time is the same swing,
## whatever order the times are asked in - a render, a scrub and a picture see the same rope.
static func swing_at(sw: Dictionary, t: float) -> Vector2:
	var kept: PackedVector2Array = sw["kept"]
	var dt_keep := SWING_STEP * float(SWING_KEEP)
	var want := clampf(t, 0.0, HORIZON)
	var need := floori(want / dt_keep) + 2
	if need > kept.size():
		var theta: Vector2 = sw["theta"]
		var omega: Vector2 = sw["omega"]
		var tt := float(sw["t"])
		var steps := int(sw["steps"])
		var g_l := float(sw["g_l"])
		while kept.size() < need:
			for k in SWING_KEEP:
				var r := theta.length()
				var pull := theta * (sin(r) / r) if r > 1e-6 else theta
				var acc := -g_l * pull - 2.0 * SWING_DAMP * sqrt(g_l) * omega + g_l * _wind(sw, tt)
				omega += acc * SWING_STEP
				theta = (theta + omega * SWING_STEP).limit_length(1.2)
				tt += SWING_STEP
				steps += 1
			kept.append(theta)
		sw["theta"] = theta
		sw["omega"] = omega
		sw["t"] = tt
		sw["steps"] = steps
		sw["kept"] = kept
	var u := want / dt_keep
	var i := mini(floori(u), kept.size() - 2)
	return kept[i].lerp(kept[i + 1], u - float(i))


## The wind's push on a swing at [param t] (radians it would lean the thing in a steady wind): a breeze
## whose lean and direction drift slowly, gusts now and then, and a little slow turbulence (kept well off the pendulum's
## own pace, which it would drive to ringing) - the push that sets a hanging thing swinging.
static func _wind(sw: Dictionary, t: float) -> Vector2:
	var n: FastNoiseLite = sw["noise"]
	var a := float(sw["amount"])
	var dir := float(sw["dir"]) + 0.9 * n.get_noise_1d(t * 0.013)
	var lean := 0.12 * (0.55 + 0.45 * n.get_noise_1d(t * 0.05 + 100.0))
	var gust := pow(maxf(n.get_noise_1d(t * 0.21 + 300.0), 0.0), 2.0) * 0.35
	var turb := Vector2(n.get_noise_1d(t * 0.3 + 500.0), n.get_noise_1d(t * 0.37 + 700.0)) * 0.02
	return (Vector2(cos(dir), sin(dir)) * (lean + gust) + turb) * a


# --- the weather ---------------------------------------------------------------------------------------

## THE CLOUDS made into numbers for [param clouds] (made safe) on [param seed]: the field's scale and
## wind (noise units a second), the level above which it is cloud, how soft a cloud's edge is, and how
## much of the sun a cloud holds back. Empty for a clear sky. The field is two octaves of the noise, not
## four: the finer ones crossed the sun as flickers a second long, which no cloud is.
static func cloud_field(clouds: Dictionary, seed: int) -> Dictionary:
	if clouds.is_empty():
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "clouds"])
	# small puffs a hundred and fifty meters across to banks of a few kilometers, crossing at a breeze's
	# two meters a second to a gale's twenty
	var size_m := 150.0 * pow(18.0, float(clouds["size"]))
	var speed := 2.0 * pow(10.0, float(clouds["speed"]))
	var ang := r.randf() * TAU
	return {"wind": Vector2(cos(ang), sin(ang)) * speed / size_m, "start": Vector2(r.randf_range(-300.0, 300.0), r.randf_range(-300.0, 300.0)),
		"thr": threshold("clouds", float(clouds["cover"])), "edge": 0.05, "opacity": 0.3 + 0.55 * float(clouds["thickness"]),
		"thin": 1.0 - float(clouds["thickness"]), "salt": r.randi() & 0x7FFFFFFF}


## HOW MUCH CLOUD IS OVER THE SUN at show time [param t] (0 clear, 1 in cloud) for [param field]
## ([method cloud_field]). Pure.
static func cloud_at(field: Dictionary, t: float) -> float:
	if field.is_empty():
		return 0.0
	var p: Vector2 = (field["start"] as Vector2) - (field["wind"] as Vector2) * t
	var d := fbm(p, int(field["salt"]), 2)
	var thr := float(field["thr"])
	var e := float(field["edge"])
	return clampf((d - (thr - e)) / (2.0 * e), 0.0, 1.0) if thr > -0.5 else 1.0


## The share of the sun let through at [param t]: 1 clear, less in cloud.
static func transmission(field: Dictionary, t: float) -> float:
	if field.is_empty():
		return 1.0
	var m := cloud_at(field, t)
	m = m * m * (3.0 - 2.0 * m)
	return 1.0 - float(field["opacity"]) * m


## THE BIRDS' CROSSINGS for [param birds] (made safe) on [param seed], over the whole [constant HORIZON]:
## `[{t, dur, path, dir, at, speed, members: [{off: Vector2, phase, flap, glide}], radius, center}]` - each
## crossing's middle time and how long it is over the reach of the table, how it flies, the way it
## flies (2D: x across, y away from the reader), where its line crosses the table, and each bird's place
## in the flock. Pure: the same seed gives the same skies.
static func crossings(birds: Dictionary, seed: int) -> Array:
	var out: Array = []
	if birds.is_empty():
		return out
	var look: Dictionary = BIRDS[String(birds["look"])]
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "birds"])
	var every := float(birds["every"])
	var t := r.randf_range(0.25, 1.0) * every
	var from := float(birds["from"])
	var speed := float(look["speed"]) * lerpf(0.3, 1.0, float(birds["speed"]))
	var path := String(look["path"])
	while t < HORIZON:
		var ang := deg_to_rad(from) + r.randf_range(-0.45, 0.45) if from >= 0.0 else r.randf() * TAU
		# the way it FLIES is away from where it comes from
		var dir := -Vector2(sin(ang), -cos(ang)) if from >= 0.0 else Vector2(cos(ang), sin(ang))
		var v := speed * r.randf_range(0.85, 1.15)
		var c := {"t": t, "path": path, "dir": dir, "speed": v,
			"at": Vector2(r.randf_range(-0.35, 0.35), r.randf_range(-0.25, 0.2)), "members": []}
		var n := int(birds["flock"])
		if n > 1 and r.randf() < 0.25:
			n = maxi(1, n + r.randi_range(-1, 1))
		var spread := float(look["span"]) * (6.0 if n > 6 else 2.5)
		for k in n:
			var off := Vector2.ZERO if k == 0 else Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-1.5, 0.3)) * spread
			(c["members"] as Array).append({"off": off, "phase": r.randf() * TAU, "flap": float(look["beat"]) * r.randf_range(0.85, 1.15),
				"glide": r.randf()})
		if path == "circle":
			# a hawk's visit: wheeling round a center some way off, its circle passing over the table
			var radius := r.randf_range(3.0, 6.0)
			var heading := r.randf() * TAU
			c["radius"] = radius
			c["center"] = (c["at"] as Vector2) + Vector2(cos(heading), sin(heading)) * radius * r.randf_range(0.92, 1.0)
			c["dur"] = r.randf_range(25.0, 50.0)
			c["phase0"] = r.randf() * TAU
		else:
			c["dur"] = 5.0 / v
		out.append(c)
		t += (float(c["dur"]) if path == "circle" else 0.0) + every * exp(r.randfn(0.0, 0.4))
	return out


## WHERE EVERY BIRD IS at show time [param t], over [param crossings]: `[{at: Vector2 (its shadow's
## middle on the table, x across, z toward the reader), heading: Vector2, beat, span, shape, smear}]` -
## only those near enough the table that their shadow may fall on it. [param look] is the birds' look.
static func birds_at(crossings_: Array, look: String, t: float) -> Array:
	var out: Array = []
	if crossings_.is_empty():
		return out
	var info: Dictionary = BIRDS[look]
	# the crossings in reach: their middles within a span of their own of now
	var lo := 0
	var hi := crossings_.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float((crossings_[mid] as Dictionary)["t"]) + 60.0 < t:
			lo = mid + 1
		else:
			hi = mid
	for i in range(lo, crossings_.size()):
		var c: Dictionary = crossings_[i]
		var tc := float(c["t"])
		if tc - 60.0 > t:
			break
		var circle := String(c["path"]) == "circle"
		var dur := float(c["dur"])
		if circle and (t < tc or t > tc + dur):
			continue
		if not circle and absf(t - tc) > dur * 0.5 + 1.0:
			continue
		var v := float(c["speed"])
		var dir: Vector2 = c["dir"]
		var side := Vector2(-dir.y, dir.x)
		for m in c["members"]:
			var mb: Dictionary = m
			var off: Vector2 = mb["off"]
			var at := Vector2.ZERO
			var heading := dir
			if circle:
				var radius := float(c["radius"])
				var a := float(c["phase0"]) + v / radius * (t - tc)
				var ctr: Vector2 = c["center"]
				at = ctr + Vector2(cos(a), sin(a)) * radius
				heading = Vector2(-sin(a), cos(a))
			else:
				var s := (t - tc) * v
				at = (c["at"] as Vector2) + dir * (s + off.y) + side * off.x
				if String(c["path"]) == "dart":
					var w := sin(t * 3.1 + float(mb["phase"])) * 0.6 + sin(t * 7.3 + float(mb["phase"]) * 2.0) * 0.25
					at += side * w * 0.6
					heading = (dir + side * cos(t * 3.1 + float(mb["phase"])) * 0.6).normalized()
				elif String(c["path"]) == "flutter":
					at += side * sin(t * 5.0 + float(mb["phase"])) * 0.35 + dir * sin(t * 3.7 + float(mb["phase"])) * 0.2
					heading = (dir + side * cos(t * 5.0 + float(mb["phase"])) * 0.9).normalized()
			if at.length() > 3.5:
				continue
			# the wings: gliding a while, then a few beats, on dice of its own
			var flap := float(mb["flap"])
			var glide := float(info["glide"])
			var cycle := fposmod(t * 0.4 + float(mb["glide"]), 1.0)
			var beat := 0.08
			if cycle >= glide:
				beat = 0.5 - 0.5 * cos(TAU * flap * t + float(mb["phase"]))
			out.append({"at": Vector2(at.x, -at.y), "heading": Vector2(heading.x, -heading.y), "beat": beat,
				"span": float(info["span"]), "shape": float(info["shape"]), "smear": v * SHUTTER})
	return out


## THE WEATHER IN NUMBERS over the first [param span] seconds, for a report: `{cloud: the share of the
## time the sun is in cloud, passings: how many times a cloud comes over it, lasting: [shortest,
## longest] seconds in cloud, birds: crossings, over: about how long a bird's shadow is over the table}`.
static func weather(light: Dictionary, seed: int, span := 600.0) -> Dictionary:
	var out := {"cloud": 0.0, "passings": 0, "lasting": [0.0, 0.0], "birds": 0, "over": 0.0}
	var field := cloud_field(light.get("clouds", {}), seed)
	if not field.is_empty():
		var n := 0
		var under := 0
		var was := false
		var since := 0.0
		var lo := INF
		var hi := 0.0
		var t := 0.0
		while t <= span:
			var c := cloud_at(field, t) > 0.5
			under += 1 if c else 0
			if c and not was:
				out["passings"] = int(out["passings"]) + 1
				since = t
			if was and (not c or t + 0.5 > span):
				lo = minf(lo, t - since)
				hi = maxf(hi, t - since)
			was = c
			n += 1
			t += 0.5
		out["cloud"] = float(under) / float(maxi(n, 1))
		out["lasting"] = [lo if lo < INF else 0.0, hi]
	var birds: Dictionary = light.get("birds", {})
	if not birds.is_empty():
		for c in crossings(birds, seed):
			if float((c as Dictionary)["t"]) < span:
				out["birds"] = int(out["birds"]) + 1
		var look: Dictionary = BIRDS[String(birds["look"])]
		out["over"] = (0.9 + float(look["span"])) / (float(look["speed"]) * lerpf(0.3, 1.0, float(birds["speed"])))
	return out


# --- lamps ------------------------------------------------------------------------------------------

## WHERE LAMP [param l] (made safe) STANDS for a set whose reading's middle is [param middle]: up and out
## of the shot if [param in_shot] says it would be seen there. Its place, and whether it was moved.
static func lamp_place(l: Dictionary, middle: Vector3, in_shot: Callable) -> Dictionary:
	var a := deg_to_rad(float(l["from"]))
	var dist := float(l["distance"]) * 0.01
	var h := float(l["height"]) * 0.01
	var at := middle + Vector3(sin(a) * dist, h, cos(a) * dist)
	var moved := false
	if in_shot.is_valid():
		var tries := 0
		while bool(in_shot.call(at)) and tries < 80:
			at.y += 0.05
			moved = true
			tries += 1
	return {"at": at, "moved": moved}


## HOW LAMP [param look] BURNS at show time [param t]: `{bright, jitter: Vector3 (meters), tint: Color
## (multiplied in), sweep: float (-1..1, how far a passing light has gone; 0 at the table)}` - a function of
## the time and [param fk] ([method flicker_of]) alone.
static func flicker(look: String, fk: Dictionary, t: float) -> Dictionary:
	var n: FastNoiseLite = fk["noise"]
	var s := float(fk["seed"])
	var out := {"bright": 1.0, "jitter": Vector3.ZERO, "tint": Color(1, 1, 1), "sweep": 0.0}
	match String((LAMPS[look] as Dictionary)["flicker"]):
		"candle":
			out["bright"] = 1.0 + 0.08 * n.get_noise_2d(t * 0.8, s) + 0.04 * n.get_noise_2d(t * 7.0, s + 31.0)
		"torch":
			out["bright"] = 1.0 + 0.22 * n.get_noise_2d(t * 1.6, s) + 0.12 * n.get_noise_2d(t * 6.0, s + 13.0) + 0.06 * n.get_noise_2d(t * 13.0, s + 29.0)
			out["jitter"] = Vector3(n.get_noise_2d(t * 2.0, s + 3.0), n.get_noise_2d(t * 2.5, s + 9.0) * 0.7, n.get_noise_2d(t * 2.2, s + 17.0)) * 0.02
		"fire":
			var crackle := pow(maxf(n.get_noise_2d(t * 9.0, s + 41.0), 0.0), 3.0) * 0.6
			out["bright"] = 0.92 + 0.2 * n.get_noise_2d(t * 0.7, s) + 0.1 * n.get_noise_2d(t * 3.0, s + 5.0) + crackle
			out["jitter"] = Vector3(n.get_noise_2d(t * 1.1, s + 3.0), n.get_noise_2d(t * 1.4, s + 9.0) * 0.5, n.get_noise_2d(t * 1.2, s + 17.0)) * 0.035
		"lantern":
			out["bright"] = 1.0 + 0.03 * n.get_noise_2d(t * 1.5, s) + 0.015 * n.get_noise_2d(t * 9.0, s + 7.0)
		"fluorescent", "neon":
			out["bright"] = _stutter(fk, t, 60.0 if String((LAMPS[look] as Dictionary)["flicker"]) == "fluorescent" else 25.0)
		"screen":
			var cut := _segment(fk["cuts"] as PackedFloat32Array, t)
			var h := _hash(int(fk["salt"]) ^ cut)
			out["bright"] = (0.45 + 0.55 * float(h & 0xFF) / 255.0) * (1.0 + 0.03 * n.get_noise_2d(t * 4.0, s))
			out["tint"] = Color.from_hsv(float((h >> 8) & 0xFF) / 255.0, 0.25 * float((h >> 16) & 0xFF) / 255.0, 1.0)
		"pass":
			var ev := _event(fk["events"] as PackedFloat32Array, t, 3.2)
			if ev >= 0.0:
				out["bright"] = pow(sin(PI * ev), 2.0)
				out["sweep"] = ev * 2.0 - 1.0
			else:
				out["bright"] = 0.0
		"beam":
			var ph := fposmod(t / float(fk["every"]) + s, 1.0)
			out["bright"] = exp(-pow((ph - 0.5) / 0.05, 2.0))
			out["sweep"] = clampf((ph - 0.5) / 0.1, -1.0, 1.0)
		"lightning":
			out["bright"] = _flash(fk, t)
	return out


## The dice a lamp's flicker reads ([method flicker]): its noise and seed, the cuts of a screen's
## pictures, the times headlights pass and lightning strikes, and its stutters - all over [constant
## HORIZON], from [param salt].
static func flicker_of(l: Dictionary, salt: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = salt
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.seed = salt & 0x7FFF
	var every := float(l.get("every", 30.0))
	var cuts := PackedFloat32Array()
	var events := PackedFloat32Array()
	var t := 0.0
	match String((LAMPS[String(l["look"])] as Dictionary)["flicker"]):
		"screen":
			while t < HORIZON:
				cuts.append(t)
				t += exp(r.randf_range(log(1.5), log(7.0)))
		"pass", "lightning":
			t = r.randf_range(0.3, 1.0) * every
			while t < HORIZON:
				events.append(t)
				t += every * exp(r.randfn(0.0, 0.5))
	return {"noise": n, "seed": r.randf() * 1000.0, "salt": salt & 0x7FFFFFFF, "every": every, "cuts": cuts, "events": events}


## The index of the segment [param t] falls in, segments starting at [param starts].
static func _segment(starts: PackedFloat32Array, t: float) -> int:
	if starts.is_empty():
		return 0
	return maxi(starts.bsearch(t, false) - 1, 0)


## How far through the event of length [param dur] that holds [param t] it is (0..1), or -1 for none.
static func _event(starts: PackedFloat32Array, t: float, dur: float) -> float:
	var i := _segment(starts, t)
	if starts.is_empty() or t < starts[i] or t > starts[i] + dur:
		return -1.0
	return (t - starts[i]) / dur


## A tube's or a sign's STUTTER: steady, and now and then (about every [param slot] seconds) a fraction
## of a second blinking off and on.
static func _stutter(fk: Dictionary, t: float, slot: float) -> float:
	var k := floori(t / slot)
	var h := _hash(int(fk["salt"]) ^ (k * 2654435) & 0xFFFFFFFF)
	if float(h & 0xFF) / 255.0 > 0.55:
		return 1.0
	var dur := 0.15 + 0.6 * float((h >> 8) & 0xFF) / 255.0
	var start := float(k) * slot + (slot - dur) * float((h >> 16) & 0xFF) / 255.0
	if t < start or t > start + dur:
		return 1.0
	return 1.0 if sin((t - start) * 115.0 + float(h & 0x3F)) > -0.2 else 0.08


## LIGHTNING at [param t]: dark, and at each strike two to four flickers inside a second, each dying fast.
static func _flash(fk: Dictionary, t: float) -> float:
	var starts: PackedFloat32Array = fk["events"]
	var i := _segment(starts, t)
	if starts.is_empty() or t < starts[i] or t > starts[i] + 1.2:
		return 0.0
	var h := _hash(int(fk["salt"]) ^ (i * 7919))
	var pulses := 2 + (h & 0x3) % 3
	var out := 0.0
	for p in pulses:
		var at := starts[i] + float(p) * (0.12 + 0.18 * float((h >> (4 + p * 4)) & 0xF) / 15.0)
		if t >= at:
			out = maxf(out, exp(-(t - at) / 0.06) * (1.0 if p == 0 else 0.7))
	return out


# --- built --------------------------------------------------------------------------------------------

## BUILD [param light] (made safe) for a host whose [param stage] is `{camera: Transform3D, fov: float,
## aspect: float, middle: Vector3 (the middle of the reading, on the top), bounds: AABB (the table and
## all that stands on it), seen: PackedVector3Array (the table the camera sees, sampled), env:
## Environment, room: ShaderMaterial or null (the room's picture: clouds dim it), in_shot: Callable(at)
## -> bool}`. [param seed] varies everything sampled. A [Rig] to add to the scene, [method Rig.fit] to the
## table's lightness, and tick.
static func build(light: Dictionary, stage: Dictionary, seed: int) -> Rig:
	var rig := Rig.new()
	rig.light = light
	rig.stage = stage
	rig.root = Node3D.new()
	rig.root.name = "Light"
	var middle: Vector3 = stage.get("middle", Vector3.ZERO)
	# THE SKY: an ambient light, and the share of it that falls from above
	var sky: Dictionary = light.get("sky", {"color": "#8f9bb0", "strength": 0.3})
	rig.sky_color = Props._color(sky.get("color", ""), "#8f9bb0")
	rig.sky_energy = SKY_MAX * float(sky.get("strength", 0.3))
	rig.top = DirectionalLight3D.new()
	rig.top.name = "Sky"
	rig.top.shadow_enabled = false
	rig.top.light_color = Color.html(rig.sky_color)
	rig.top.rotation_degrees = Vector3(-80.0, 20.0, 0.0)
	rig.top.light_specular = 0.2
	rig.root.add_child(rig.top)
	# THE SUN
	var sun: Dictionary = light.get("sun", {})
	if not sun.is_empty():
		var s := sun_dir(sun)
		rig.sun_vec = s
		rig.sun = DirectionalLight3D.new()
		rig.sun.name = "Sun"
		rig.sun.light_color = Color.html(String(sun["color"]))
		rig.sun.shadow_enabled = true
		rig.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		rig.sun.directional_shadow_max_distance = 2.0
		rig.sun.directional_shadow_fade_start = 0.95
		# A TABLETOP'S BIASES (cards are 0.7 mm thick), and SOFTNESS BY THE FILTER, not by PCSS: a sun's
		# PCSS searches as far as its farthest caster (a wall a meter and more off), and the blocker search
		# then misses a stone's small shadow
		rig.sun.shadow_bias = 0.015
		rig.sun.shadow_normal_bias = 0.35
		rig.sun.light_angular_distance = 0.0
		rig.sun_blur = lerpf(0.9, 4.0, float(sun["softness"]))
		rig.sun.shadow_blur = rig.sun_blur
		rig.sun.light_specular = 0.7
		rig.root.add_child(rig.sun)
		rig.sun.basis = Basis.looking_at(-s, Vector3.UP if absf(s.y) < 0.999 else Vector3.FORWARD)
		rig.sun_asked = SUN_MAX * float(sun["strength"])
		rig.sun_energy = rig.sun_asked
		rig.sun_height = float(sun["height"])
		# WHAT IT FALLS THROUGH
		var seen: PackedVector3Array = stage.get("seen", PackedVector3Array())
		rig.geom = screens_of(light, middle, stage.get("bounds", AABB(middle - Vector3(1, 0, 1), Vector3(2, 0.4, 2))), seen, seed)
		for g in rig.geom:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			var wall := bool((SCREENS[String((g["screen"] as Dictionary)["kind"])] as Dictionary)["wall"])
			q.size = WALL if wall else Vector2(CANOPY, CANOPY)
			mi.mesh = q
			mi.layers = SCREEN_LAYER
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var mat := ShaderMaterial.new()
			mat.shader = SCREEN_SHADER
			for k in g["u"]:
				mat.set_shader_parameter(String(k), (g["u"] as Dictionary)[k])
			mi.material_override = mat
			mi.transform = Transform3D(Basis(g["bx"], g["by"], (g["bx"] as Vector3).cross(g["by"])), g["origin"])
			rig.root.add_child(mi)
			var moves := float((g["u"] as Dictionary)["sway"]) > 0.0 and int((g["u"] as Dictionary)["kind"]) != 0 \
				and int((g["u"] as Dictionary)["kind"]) != 2 and int((g["u"] as Dictionary)["kind"]) != 6
			rig.screens.append({"node": mi, "mat": mat, "moves": moves, "g": g})
			# A CANVAS'S COLOR tints the light under it
			var sc: Dictionary = g["screen"]
			if sc.has("color") and String(sc["kind"]) in ["awning", "parasol"]:
				rig.tint = Color.html(String(sc["color"]))
				rig.tint_share = float(sc.get("cover", 0.6)) if String(sc["kind"]) == "awning" else 0.4
		# THE WEATHER
		rig.field = cloud_field(light.get("clouds", {}), seed)
		var birds: Dictionary = light.get("birds", {})
		if not birds.is_empty():
			rig.bird_look = String(birds["look"])
			rig.flights = crossings(birds, seed)
			for i in MAX_BIRDS:
				var b := MeshInstance3D.new()
				var bq := QuadMesh.new()
				var span := float((BIRDS[rig.bird_look] as Dictionary)["span"])
				bq.size = Vector2(span * 1.15, span * 1.0 + 0.2)
				b.mesh = bq
				b.layers = SCREEN_LAYER
				b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				var bm := ShaderMaterial.new()
				bm.shader = BIRD_SHADER
				b.material_override = bm
				b.visible = false
				rig.root.add_child(b)
				rig.bird_nodes.append(b)
	elif not (light.get("clouds", {}) as Dictionary).is_empty():
		rig.field = cloud_field(light["clouds"], seed)
	# THE LAMPS
	var lamps: Array = light.get("lamps", [])
	for i in lamps.size():
		var l: Dictionary = lamps[i]
		var info: Dictionary = LAMPS[String(l["look"])]
		var place := lamp_place(l, middle, stage.get("in_shot", Callable()))
		var at: Vector3 = place["at"]
		var node: Light3D
		var to := at - middle
		var dist := maxf(to.length(), 0.1)
		var slant := maxf(to.normalized().y, 0.25)
		if String(info["kind"]) == "spot":
			var sp := SpotLight3D.new()
			sp.spot_range = dist * 2.5 + 1.0
			sp.spot_angle = clampf(rad_to_deg(atan(0.9 / dist)), 12.0, 60.0)
			sp.spot_angle_attenuation = 1.2
			sp.shadow_bias = 0.005
			sp.shadow_normal_bias = 0.15
			node = sp
		else:
			var om := OmniLight3D.new()
			om.omni_range = dist * 2.5 + 1.0
			om.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
			om.shadow_bias = 0.006
			om.shadow_normal_bias = 0.12
			node = om
		node.name = "Lamp%d" % i
		node.light_color = Color.html(String(l["color"]))
		node.light_size = minf(float(info["size"]) * 0.01, 0.06)
		node.shadow_enabled = bool(l["shadows"])
		node.shadow_caster_mask = 0xFFFFFFFF & ~SCREEN_LAYER
		node.light_specular = 0.5
		rig.root.add_child(node)
		node.transform = Transform3D(Basis.looking_at(-to, Vector3.UP if absf(to.normalized().y) < 0.999 else Vector3.FORWARD)
			if node is SpotLight3D else Basis.IDENTITY, at)
		# AS BRIGHT AT THE TABLE'S MIDDLE AS ITS STRENGTH ASKS: an omni light falls off as 1/d (Godot's
		# own attenuation), and the cloth takes it at a slant
		var energy := LAMP_IRR * float(l["strength"]) * dist / slant
		if String(info["flicker"]) == "lightning":
			# a flash lights the whole room: as bright as it is far
			energy = LAMP_IRR * 2.5 * float(l["strength"]) * dist
		rig.lamps.append({"spec": l, "light": node, "base": at, "energy": energy, "asked": energy, "moved": place["moved"],
			"fk": flicker_of(l, hash([seed, i, String(l["name"]), "lamp"])), "dist": dist, "slant": slant})
	# THE SHADOWS OUT OF THE SHOT, set up their lights' rays
	var lamps_at := {}
	for l in rig.lamps:
		lamps_at[String(((l as Dictionary)["spec"] as Dictionary)["name"])] = (l as Dictionary)["base"]
	var casters: Array = light.get("shadows", [])
	for i in casters.size():
		var c: Dictionary = casters[i]
		var meshes := caster_meshes(c["parts"])
		if meshes.is_empty():
			continue
		var place := caster_place(c, meshes, light, stage, lamps_at)
		var kind := String((c["move"] as Dictionary)["kind"])
		var xf: Transform3D = place["xform"]
		# what it moves about: its top for a swing (what it hangs from), its middle for a spin
		var pivot_at: Vector3 = place["middle"] if kind == "spin" else place["top"]
		var pivot := Node3D.new()
		pivot.name = "Shadow%d" % i
		pivot.position = pivot_at
		var body := Node3D.new()
		body.transform = Transform3D(xf.basis, xf.origin - pivot_at)
		pivot.add_child(body)
		var wave := float((c["move"] as Dictionary)["amount"]) * 0.06 if kind == "flutter" else 0.0
		var mats: Array = []
		for m in meshes:
			var mi := MeshInstance3D.new()
			mi.mesh = (m as Dictionary)["mesh"]
			mi.transform = (m as Dictionary)["xform"]
			mi.layers = CASTER_LAYER
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var mat := ShaderMaterial.new()
			mat.shader = CASTER_SHADER
			var span := float((m as Dictionary)["sheet"])
			if span > 0.0 and wave > 0.0:
				mat.set_shader_parameter("wave", wave)
				mat.set_shader_parameter("top", span * 0.5)
				mat.set_shader_parameter("span", span)
				mat.set_shader_parameter("phase", float(mats.size()) * 1.7)
				mats.append(mat)
			mi.material_override = mat
			body.add_child(mi)
		rig.root.add_child(pivot)
		var mid_local := meshes_box(meshes).get_center()
		var top_y := meshes_box(meshes).end.y
		rig.casters.append({"spec": c, "pivot": pivot, "kind": kind, "mats": mats, "moved": place["moved"],
			"swing": swing_of(maxf(top_y - mid_local.y, 0.05) * 2.0 * 0.667, float((c["move"] as Dictionary)["amount"]),
				hash([seed, i, String(c["name"]), "swing"]) & 0x7FFFFFFF) if kind == "swing" else {},
			"spin": 0.3 * pow(40.0, float((c["move"] as Dictionary)["speed"])), "turn": deg_to_rad(float(c["turn"])),
			"meshes": meshes, "xform": xf})
	rig.apply_sky()
	return rig


## A LIGHT AS BUILT: its sky, sun, screens, birds and lamps, posed from show time ([method tick]).
class Rig:
	extends RefCounted

	var root: Node3D
	var light := {}
	var stage := {}
	var sky_color := "#8f9bb0"
	var sky_energy := 0.3
	var top: DirectionalLight3D
	var sun: DirectionalLight3D = null
	var sun_vec := Vector3.UP
	var sun_asked := 0.0                # the sun's energy as its strength asked
	var sun_energy := 0.0               # ...and as the palest thing it falls on allows ([method fit])
	var sun_height := 40.0
	var sun_blur := 1.0
	var geom: Array = []                # the screens' places ([method Lights.screens_of])
	var screens: Array = []             # [{node, mat, moves, g}]
	var tint := Color(1, 1, 1)          # a canvas over the table: its color, and how much of the light under it it tints
	var tint_share := 0.0
	var field := {}                     # the clouds ([method Lights.cloud_field])
	var bird_look := ""
	var flights: Array = []             # the birds' crossings ([method Lights.crossings])
	var bird_nodes: Array = []
	var lamps: Array = []               # [{spec, light, base, energy, asked, moved, fk, dist, slant}]
	var casters: Array = []             # the shadows out of the shot: [{spec, pivot, kind, mats, moved, swing, spin, turn, meshes, xform}]
	var flash := 0.0                    # lightning, this frame

	## THE SKY in the environment: its ambient, and the light from above - and, now, a flash of lightning
	## ([param flash_now]) and a cloud's glow over the sun ([param glow]).
	func apply_sky(flash_now := 0.0, glow := 0.0) -> void:
		var env: Environment = stage.get("env")
		var c := Color.html(sky_color).lerp(tint, tint_share * 0.5)
		var e := sky_energy + glow
		if env != null:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = c
			env.ambient_light_energy = e * (1.0 - Lights.SKY_TOP) + flash_now * 0.6
		top.light_color = c
		top.light_energy = e * Lights.SKY_TOP + flash_now * 0.4

	## FITTED TO THE TABLE: [param hot] is the lightness (linear) of the palest thing the light falls on
	## where the camera looks - the cloth's hottest stretch, the card stock. The sun and the sky are
	## brought down together until that takes no more than [constant Lights.SUN_HEAT] of them; a lamp is
	## held to [constant Lights.LAMP_HEAT] where its light is strongest on the table.
	func fit(hot: float) -> void:
		var h := maxf(hot, 0.05)
		var sky_asked := Lights.SKY_MAX * float((light.get("sky", {}) as Dictionary).get("strength", 0.3))
		var direct := sun_asked * maxf(sin(deg_to_rad(sun_height)), 0.08) if sun != null else 0.0
		# THE EXPOSURE: stopped down until the palest thing in the light takes no more than SUN_HEAT -
		# the sun and the sky together, so the shade keeps its depth against the sun
		var k := minf(1.0, Lights.SUN_HEAT / maxf((direct + sky_asked) * h, 1e-4))
		sun_energy = sun_asked * k
		sky_energy = sky_asked * k
		for l in lamps:
			var d: Dictionary = l
			if String((Lights.LAMPS[String((d["spec"] as Dictionary)["look"])] as Dictionary)["flicker"]) == "lightning":
				continue
			# where it is strongest on the table: under it, at the height it stands over the cloth
			var middle: Vector3 = stage.get("middle", Vector3.ZERO)
			var near := maxf(absf((d["base"] as Vector3).y - middle.y), 0.15)
			d["energy"] = minf(float(d["asked"]), Lights.LAMP_HEAT * near / h)
		apply_sky()

	## Whether the sun or a lamp LEADS the light here - lighting the cards at least [constant
	## Lights.LEAD_MIN] - so the candles on the table burn as fills.
	func leads() -> bool:
		return lead_level() >= Lights.LEAD_MIN

	func lead_level() -> float:
		var best := 0.0
		if sun != null:
			best = sun_energy * sin(deg_to_rad(sun_height))
		for l in lamps:
			var d: Dictionary = l
			if String((Lights.LAMPS[String((d["spec"] as Dictionary)["look"])] as Dictionary)["flicker"]) in ["pass", "beam", "lightning"]:
				continue
			best = maxf(best, float(d["energy"]) * float(d["slant"]) / float(d["dist"]))
		return best

	## What leads, in words - the strongest light on the table, whether or not it leads.
	func key_name() -> String:
		var best := -1.0
		var name := ""
		if sun != null:
			best = sun_energy * sin(deg_to_rad(sun_height))
			name = "the %s" % String((light["sun"] as Dictionary)["look"])
		for l in lamps:
			var d: Dictionary = l
			var v := float(d["energy"]) * float(d["slant"]) / float(d["dist"])
			if v > best and not String((Lights.LAMPS[String((d["spec"] as Dictionary)["look"])] as Dictionary)["flicker"]) in ["pass", "beam", "lightning"]:
				best = v
				name = String((d["spec"] as Dictionary)["name"])
		return name

	## In fog, the sun is seen: shafts through what it falls through.
	func set_fog(foggy: bool) -> void:
		if sun != null:
			sun.light_volumetric_fog_energy = 1.4 if foggy else 1.0
		for l in lamps:
			((l as Dictionary)["light"] as Light3D).light_volumetric_fog_energy = 1.6 if foggy else 1.0

	## The share of the sun the clouds let through at [param t].
	func transmission(t: float) -> float:
		return Lights.transmission(field, t)

	## A time at or after [param t] with the sun out and no bird over the table - for a still picture of
	## the table as it mostly is. [param t] itself when nothing comes and goes.
	func quiet_near(t: float) -> float:
		var tt := t
		for i in 600:
			var clear := field.is_empty() or Lights.cloud_at(field, tt) < 0.02 or float(field["thr"]) < -0.5
			if clear and Lights.birds_at(flights, bird_look, tt).is_empty():
				return tt
			tt += 0.5
		return t

	## EVERYTHING AS IT IS at show time [param t].
	func tick(t: float) -> void:
		var tau := transmission(t)
		var glow := 0.0
		if sun != null:
			sun.light_energy = sun_energy * tau
			glow = Lights.CLOUD_GLOW * (1.0 - tau) * sun_energy * sin(deg_to_rad(sun_height))
			# under a thin cloud the shadows soften before they fade
			var cloud := 1.0 - tau
			sun.shadow_blur = sun_blur * (1.0 + 3.0 * cloud * float(field.get("thin", 0.0)))
			for s in screens:
				if bool((s as Dictionary)["moves"]):
					((s as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("show_time", t)
			_tick_birds(t)
		flash = 0.0
		for l in lamps:
			var d: Dictionary = l
			var spec: Dictionary = d["spec"]
			var f := Lights.flicker(String(spec["look"]), d["fk"], t)
			var node: Light3D = d["light"]
			var base: Vector3 = d["base"]
			node.light_energy = float(d["energy"]) * float(f["bright"])
			node.position = base + (f["jitter"] as Vector3)
			node.light_color = Color.html(String(spec["color"])) * (f["tint"] as Color)
			var kind := String((Lights.LAMPS[String(spec["look"])] as Dictionary)["flicker"])
			if kind == "pass" or kind == "beam":
				# its beam sweeps across the table, from one side of it to the other
				var middle: Vector3 = stage.get("middle", Vector3.ZERO)
				var across := (middle - base).cross(Vector3.UP).normalized()
				node.basis = Basis.looking_at(middle + across * float(f["sweep"]) * 1.2 - node.position, Vector3.UP)
			elif kind == "lightning":
				flash = maxf(flash, float(f["bright"]) * float(spec["strength"]))
		apply_sky(flash, glow)
		_tick_casters(t)
		var room: ShaderMaterial = stage.get("room")
		if room != null:
			# the room's picture holds the sun's light as well as the sky's: under a cloud it is lit as the
			# table is - the sun's share dimmed, the cloud's glow added
			room.set_shader_parameter("shade", lit_share(tau) * (1.0 + flash * 1.5))

	## HOW LIT THE TABLE IS with [param tau] of the sun let through, against the sun out: the sun's share
	## dimmed, the cloud's glow added to the sky's. 1 with no sun to dim.
	func lit_share(tau: float) -> float:
		if sun == null:
			return 1.0 if field.is_empty() else lerpf(1.0, 0.7, 1.0 - tau)
		var direct := sun_energy * sin(deg_to_rad(sun_height))
		var full := maxf(direct + sky_energy, 0.01)
		return (direct * tau + sky_energy + Lights.CLOUD_GLOW * (1.0 - tau) * direct) / full

	## The shadows out of the shot at [param t]: a swing's pendulum, a spin's turn, a sheet's ripple.
	func _tick_casters(t: float) -> void:
		for c in casters:
			var d: Dictionary = c
			var pivot: Node3D = d["pivot"]
			match String(d["kind"]):
				"swing":
					var th := Lights.swing_at(d["swing"], t)
					pivot.basis = Basis(Vector3(0.0, 0.0, 1.0), -th.x) * Basis(Vector3(1.0, 0.0, 0.0), th.y)
				"spin":
					var w := float(d["spin"])
					pivot.basis = Basis(Vector3.UP, w * t + 0.08 * sin(t * 0.7))
				"flutter":
					for m in d["mats"]:
						(m as ShaderMaterial).set_shader_parameter("show_time", t)

	func _tick_birds(t: float) -> void:
		if bird_nodes.is_empty():
			return
		var now := Lights.birds_at(flights, bird_look, t)
		var middle: Vector3 = stage.get("middle", Vector3.ZERO)
		var s := sun_vec
		var up := Lights.BIRD_UP / maxf(s.y, 0.08)
		for i in bird_nodes.size():
			var node: MeshInstance3D = bird_nodes[i]
			if i >= now.size():
				node.visible = false
				continue
			var b: Dictionary = now[i]
			var at: Vector2 = b["at"]
			var h: Vector2 = (b["heading"] as Vector2).normalized()
			var heading := Vector3(h.x, 0.0, h.y)
			var right := Vector3(-heading.z, 0.0, heading.x)
			node.transform = Transform3D(Basis(right, heading, Vector3.UP), middle + Vector3(at.x, 0.0, at.y) + s * up)
			var mat := node.material_override as ShaderMaterial
			mat.set_shader_parameter("span", float(b["span"]))
			mat.set_shader_parameter("beat", float(b["beat"]))
			mat.set_shader_parameter("shape", float(b["shape"]))
			mat.set_shader_parameter("smear", float(b["smear"]))
			node.visible = true

	func release() -> void:
		var room: ShaderMaterial = stage.get("room")
		if room != null:
			room.set_shader_parameter("shade", 1.0)
		if root != null and is_instance_valid(root):
			root.queue_free()
		root = null

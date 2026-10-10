extends Medium
class_name TableMedium

## TableMedium - a card reading at a table, seen from the reader's chair.
##
## The Cards mode's own medium (see [constant Medium.OWNED]): the episode's cloth on a table,
## its room out of focus beyond the far edge, its candles, and the deck. The reader is a voice, never a pair of hands - the cards move on their own:
##
##   the intro      the deck shuffles in the middle of the table under the voice, in RUNS -
##                  riffles, overhand passes, strings of cuts, now and then a wash across the
##                  cloth - with long stretches of nothing between them ([constant RUNS])
##   the push       before the first card, the deck is squared and pushed to its side
##   a draw         the deck squares, the top card slides off, turns over, and comes up to the
##                  camera on the LEFT; its booklet page opens on the RIGHT - shown, never read
##   the reading    the card and the page float there while the voice talks about it, turning
##                  a little on their axes; now and then the card is turned to look at its back
##   the lay        the page closes and the card goes down into its place in the spread
##   a jumper       the first card flies out of the shuffle on its own, lands face up, and is
##                  picked up and shown like a drawn one
##   the close      the whole spread lies on the table
##
## EVERYTHING IS A FUNCTION OF SHOW TIME, as the tablet's screen is: the actions are the
## reading's own marks ([CardReading]), placed in the rests the voice left for them by a
## [ReadingFollower], and every card, page and packet of the deck is posed from that schedule
## each frame - so a render draws exactly what the live reading drew, and a scrub lands the
## table where the reading is.
##
## THE LOOK IS THE EPISODE'S. The cloth, the room, the card back and every face are its
## pictures; THE TABLE ITSELF - its top's shape, edge and wood, and the cloths laid on it - is the set
## dresser's, built by [Tables] (the old board table and its painted cloth when it wrote none); the frame, the type, the props and the light come from its look through
## [CardTable]'s registries, and the rest - where the deck sits, how the spread is laid, which
## shuffles, the camera's height - is sampled from the episode's seed, so no two episodes share a
## table. A picture still being painted is a placeholder until it lands, live.
##
## FOIL. The brightest, most colorful parts of each painting - found per picture from its own
## luminance, never a fixed threshold - are printed as foil: they catch the light as a card
## tilts, breathe slowly, and now and then a glint sweeps across them, and the scene's bloom
## lets them bleed. The deck's look says how much foil it was printed with.

## A card is 70 x 120 mm. World units are meters: the table is a table.
const CARD := TablePositions.CARD
const CARD_R := 0.0045
const CARD_T := 0.0007
## The deck: this many meshes, each standing for three cards - 78 cards stand about 3 cm.
const DECK_N := 26
## How much table a laid card leaves between itself and the deck.
const DECK_CLEAR := TablePositions.DECK_CLEAR
const DECK_T := 0.0012
## The table every episode had before (width, thickness, depth), centered at TABLE_Z, its top at y = 0
## ([constant Tables.DEFAULT_TOP]; the room's old placement still measures from its far edge); the
## cloth on it.
const TABLE := Vector3(1.9, 0.05, 0.85)
const TABLE_Z := 0.02
const CLOTH := TablePositions.CLOTH
## THE ROOM, out of focus ([method _place_backdrop]): the picture drawn through a lens blur, each
## point a disc this wide - its radius, as a share of the frame's width. A lens focused on the table
## half a meter off sees a room some meters away about so soft at f/4.
const ROOM_SHADER := preload("res://shaders/table_room.gdshader")
const ROOM_BLUR := 0.005
## How far out the room's picture stands from the camera (meters, level).
const ROOM_REACH := 3.2
## Where a shown card and its booklet page float, in the camera's frame (meters right, up, and
## away). The page sits a hair farther back so the card always reads as in front.
const PRESENT_DIST := 0.23
const PRESENT := Vector2(-0.087, 0.012)
## A card with its text on either face ([constant CardTable.TEXTS]) is held up alone, in the middle
## and a little nearer: there is no page beside it.
const PRESENT_ALONE := Vector2(0.0, 0.006)
const PRESENT_ALONE_DIST := 0.205
## ...and it is turned over to show that text: first this long after it is up, held there this long.
const BACK_LOOK := Vector2(3.5, 5.5)
const BACK_HOLD := Vector2(5.0, 8.0)
const PAGE := Vector2(0.088, 0.012)
const PAGE_H := 0.126
const VFOV := CardTable.VFOV

## THE PHASES of each action, in its own seconds. They sum to [CardReading]'s rests, which is
## what the voice waits: DRAW = 3.4, LAY = 1.7, JUMP = 5.0.
const SQUARE := 0.45          # the deck squares before a card leaves it
const SLIDE_END := 1.0        # the top card slides off toward the reader
const FLIP_END := 1.9         # ...lifts and turns over
const RISE_END := 2.8         # ...and comes up to be shown
const PAGE_IN := Vector2(2.6, 3.4)
const LAY_PAGE_OUT := 0.5
const LAY_MOVE := Vector2(0.15, 1.45)
const LAY_END := 1.7
## A JUMPER FLIES OUT OF A SHUFFLE (2026-10-05: "that jump should probably happen during a shuffle -
## not when the cards are just sitting there on the table, doing nothing"): its action opens with
## one more riffle, and the card springs off the top of a half while the halves are falling. The
## riffle, the flight, the card lying there, its rise, its page.
const JUMP_RIFFLE := 2.4
const JUMP_FLY := Vector2(1.15, 2.25)
const JUMP_REST := 3.3
const JUMP_RISE := 4.3
const JUMP_PAGE := Vector2(4.2, 5.0)
## A CARD DEALT (TableActions.DEAL): off its source and turned over, then down into its place.
const DEAL_TURN := 0.9
const DEAL_END := 1.9
## A WATERFALL (TableActions.FAN): each card leaves a beat behind the one before (TableActions.FAN_EACH)
## and slides out to its place, turning face up as it goes.
const FAN_MOVE := 1.45
## A CARD SHOWN from where it lies (TableActions.SHOW): it lifts and comes up; its page opens.
const SHOW_RISE := 1.1
const SHOW_PAGE := Vector2(0.9, 1.6)
## A card TURNED where it lies (TableActions.TURN, FLIP): the turn's own seconds.
const TURN_END := 0.8
const FLIP_END_LAY := 1.1
## THE BOX THE CARDS ARE KEPT IN: how thick its walls are taken to be (meters), and the cards filed in
## it - their pitch (a card and the air beside it), and how far the last of them lean into the gap.
const BOX_WALL := 0.006
const FILE_PITCH := 0.0011
const FILE_LEAN := 0.35
## A card pulled from the box rises this far above the rim before it turns to the camera.
const PULL_CLEAR := 0.02
## A card laid down arcs this high over the cloth on its way (meters) - and is lifted higher while the
## box stands in its way ([method _lay_lift]): sampled in LAY_SAMPLES steps, the lift eased away over
## LAY_EASE of the way after the box and over the last LAY_LAND of it.
const LAY_ARC := 0.05
const LAY_LIFT_MAX := 0.3
const LAY_SAMPLES := 32
const LAY_EASE := 0.08
const LAY_LAND := 0.04
## A card's edge may lie this far over the box's rim (meters) before the arc lifts it: the last of its
## descent, tilted still, reaches a few millimeters past where it lies, and the spread leaves the box
## more than this (TablePositions.DECK_CLEAR).
const BOX_GRAZE := 0.008
## Lead and tail around each action group, as the tablet's: a beat after the last word before
## the cards move, and they are still a beat before the next word.
## HOW A READER SHUFFLES: in RUNS - several riffles, a string of cuts, a few overhand passes,
## one at a tempo - and then nothing for a while, the deck squared under their hands while they
## talk. A run per kind: how likely it is chosen, how many moves, each move's length and the gap
## inside the run. The wash (the deck spread and swirled across the cloth) is its own event: rare,
## long, and once at most.
const RUNS := {
	"riffle": {"weight": 3.0, "n": [2, 4], "dur": [2.2, 2.7], "gap": [0.2, 0.55]},
	"overhand": {"weight": 2.0, "n": [2, 5], "dur": [2.1, 2.6], "gap": [0.05, 0.3]},
	"cut": {"weight": 2.0, "n": [2, 5], "dur": [1.15, 1.5], "gap": [0.05, 0.25]},
	"wash": {"weight": 0.9, "n": [1, 1], "dur": [26.0, 32.0], "gap": [0.0, 0.0]},
}
## The pause after a run: mostly a few seconds, now and then a long linger - median ~3 s.
const IDLE_LOG := Vector2(1.1, 0.55)
const IDLE_RANGE := Vector2(1.6, 18.0)
## The chance a run is followed by a long linger instead.
const LINGER_CHANCE := 0.15
## A wash is sampled at this rate once, when it is planned, and posed by lookup.
const WASH_HZ := 20.0
## THE FAN-OUT CALMED (the user, 2026-10-08: as the cards fan out they "wobble and vibrate, which
## is a thing cards shouldn't do"): under the palm, each card's tilt is the mean of its resting tilt
## over CALM_REACH steps of CALM_HZ either side - a card sliding off another's edge tipped in a frame
## (576 deg/s, measured) and back - and it is set down on its highest support at that tilt, so it
## never floats nor dips. Calm until the cards are out, easing to the bare rest over CALM_SETTLE.
const CALM_HZ := 20.0
const CALM_REACH := 2
const CALM_SETTLE := 0.5
## The least time a wash needs to spread, mix a little and gather (seconds): with less before the
## first card, the deck is not washed at all.
const WASH_ROOM := 9.0
## A SPREAD CARD IS A REAL CARD'S THICKNESS (the user: cards should rest "with a gentle tilt"): the
## plan's chains of cards lying on cards run many deep, and every millimeter a card stands on tips
## the card lying across it. The cloth's top, how far over it a spread card lies, a spread card's
## thickness, and the hair between a card and the one under it (so two faces never fight for one
## depth).
const CLOTH_TOP := Tables.LAYERS_UNDER
const FLOOR_GAP := 0.0001
const WASH_T := 0.0003
const STACK_GAP := 0.0001
## A spread card lying on the cloth: its middle this high. And one card's place in a pile.
const WASH_FLOOR := CLOTH_TOP + FLOOR_GAP + WASH_T * 0.5
const WASH_LAYER := WASH_T + STACK_GAP
## How long the deck takes to flatten under the palm (seconds) - to its cards' own thickness, so
## the first cards slide off a low stack, not a deck's height.
const WASH_FLATTEN := 0.35
## THE HANDS IN A WASH (2026-10-05, the user: "cards barely move... the movements are very small,
## very localized... It would be much more common for cards to sweep back, and forth, back, and
## forth in various directions, crossing large regions of the table, creating chaos along their
## path"): each palm had worked a 6 cm circle, and the cards under it went round that circle and
## back - 4 cm the longest straight run, 11 cm the farthest a card got. How often a palm scrubs,
## swirls or fetches ([method _wash_gesture]), how long a scrub's pass is (meters), and how often a
## palm rests a moment between gestures.
const WASH_GESTURES := {"scrub": 0.65, "swirl": 0.15, "fetch": 0.2}
const WASH_SCRUB := Vector2(0.2, 0.4)
const WASH_REST := 0.12
## A palm flat on the cards: half its width and half its length (meters), its length along the
## forearm from the reader's shoulder (to the side and toward the reader, about the deck's place).
## It comes down and lifts over WASH_TOUCH seconds, keeps its middle WASH_APART from the other
## palm's when it can, and fetches a card lying out past WASH_STRAY of the spread's reach.
const PALM := Vector2(0.045, 0.08)
const WASH_SHOULDER := Vector2(0.19, 0.46)
const WASH_TOUCH := 0.12
const WASH_APART := 0.14
const WASH_STRAY := 0.85
## Where on a card a palm takes hold (meters across and along it, from its middle), and a card's
## turning inertia over its mass (meters squared: a 70 x 120 mm sheet).
const GRIP_AT := [Vector2.ZERO, Vector2(-0.022, -0.04), Vector2(0.022, -0.04), Vector2(-0.022, 0.04),
	Vector2(0.022, 0.04)]
const CARD_I := (0.07 * 0.07 + 0.12 * 0.12) / 12.0
## HOW CARDS SLIDE in a wash (centers: each wash samples its own feel round them). How hard a palm
## can pull a card it presses whole (m/s each second - far past what the cloth holds back, so the
## card goes with it) - where another card lies over it, WASH_COVERED of that; the drag between two
## cards lying one on the other (per second: loose, and added when a palm presses the top one); how
## much of the difference in their speeds a card sliding into another gives it as they meet; how fast
## a loose card slows (m/s each second, WASH_ON_CARD of that on another card) and stops turning
## (radians/s each second); and the fastest a hand drags a card (m/s) or turns one (radians/s).
## A MEETING IS A NUDGE, NOT A BOUNCE (the user: cards must not "repel each other in a way that makes
## them almost bouncy"): the card run into takes a sixth of the difference in their speeds, where
## they touch - well short of evening them, so nothing ever comes back the way it went - and a hand
## turns a card a few radians a second at most. The chaos along a sweep is the drag's.
const WASH_GRIP := 40.0
const WASH_COVERED := 0.25
const WASH_DRAG := Vector2(5.0, 40.0)
const WASH_KNOCK := 0.16
const WASH_SLIDE := 3.0
const WASH_ON_CARD := 0.55
const WASH_SPIN := 40.0
const HAND_SPEED := 1.2
const WASH_TURN_MAX := 3.5
## A heap slumps ([method _wash_slump]): a loose card this many cards up creeps off it, this fast
## (m/s) for each card higher.
const SLUMP_FROM := 3
const SLUMP := 0.012
## A CARD STRUCK HARD IS THROWN OUT OF THE SPREAD (2026-10-06, the user: "when a lot of repulsion is
## applied, a card can get ejected... I would expect some ejections to land face-down, and thus NOT
## be drawn"): a meeting faster than EJECT_SPEED (m/s, their speeds apart) may throw the card run
## into - surer the harder, up to EJECT_CHANCE - a hop of EJECT_REACH (meters) along the blow, onto
## the cloth and in the picture, clear of everything that stands. It lands face down: a deck card's
## face is never painted, so only a drawn card - a jumper - may come down face up. A card is thrown
## only with nothing lying on it and no palm on it, at most EJECT_MOST a wash, and none in the last
## EJECT_ROOM seconds of the mixing (it is down before the gather). Its hop's height (meters) and
## how long it takes (seconds).
const EJECT_SPEED := 0.5
const EJECT_CHANCE := 0.35
const EJECT_REACH := Vector2(0.1, 0.28)
const EJECT_MOST := 2
const EJECT_ROOM := 1.5
const EJECT_HOP := Vector2(0.012, 0.035)
const EJECT_TIME := Vector2(0.35, 0.55)
## A JUMPER OUT OF A WASH: when the first card is a jumper and the deck is being washed as its moment
## comes, the jumper is the card a hard blow throws out - over, face up, clear of the rest - this far
## into its action (its own seconds), and lies there until it is picked up as from a riffle; the hands
## stop as it flies and gather the rest once it is up. Its hop (meters) and flight (seconds), how long
## the gather takes, and the least mixing before it (a wash only just spread has nothing to throw).
const JUMP_EJECT := 0.35
const JUMP_HOP := Vector2(0.075, 0.095)
const JUMP_FLIGHT := Vector2(0.45, 0.6)
const JUMP_GATHER := 4.2
const JUMP_MIX := 3.0
## An episode whose first card is a jumper washes the deck into it this often: its wash is held back
## to begin this long before the jumper is reckoned to come (from the script's words at a steady
## pace) and to run this long past it - a voice is never quite the pace reckoned.
const JUMPER_WASH := 0.5
const JUMPER_WASH_LEAD := 24.0
const JUMPER_WASH_SLACK := 16.0
## The first card's PUSH (TableActions.PUSH): the deck squares, then slides to its side this long.
const PUSH_SLIDE := 0.85
## A held card is turned over now and then, to look at its back ([method _look_of]): the chance a
## card is at all, the chance of each look after that, the seconds between looks, how long a turn
## takes (each its own), and how long its back is looked at - drawn evenly in its logarithm, so most
## looks are short and now and then one is long (a fixed-feeling 1.1-1.8 s was reported as "the
## exact same length, always"). Most cards are never turned: 4-5 looks in one draw was too many.
const TURN_CHANCE := 0.25
const LOOK_AGAIN := 0.25
const LOOK_GAP := Vector2(25.0, 45.0)
const TURN := Vector2(0.6, 0.95)
const TURN_HOLD := Vector2(0.6, 5.0)
## THE PIROUETTE (the user's, 2026-10-05: "the kind of trick a person might do in their own hands
## to show off"): the chance a look ends in one - over to the back and held there a few seconds,
## then on round the SAME way, five half turns more, to face on again three whole turns from where
## it started - the hold, and how long the twirl takes. Rare, and once a card at most: the plain
## half turn is the common look.
const PIROUETTE_CHANCE := 0.1
const PIROUETTE_HOLD := Vector2(1.6, 4.0)
const TWIRL := Vector2(1.5, 2.1)
## A BURST ON THE PIROUETTE makes one happen: about one card in forty twirled by chance, so a set
## dresser's sparks on it (seen in its own preview, which stages one) went unseen in nearly every
## reading (2026-10-07, "I have yet to see that occur even one time"). The card twirled is a held
## one with at least this long in the hand (seconds), seeded - the longest-held when none has.
const SPIN_ROOM := 12.0
## How far apart things stand on the table (meters): any two, and two of one group.
const THING_GAP := 0.014
const GROUP_GAP := 0.004
## HOW A READER SETS OUT THEIR THINGS, a habit drawn per episode (the user, 2026-10-08: "props are
## most often placed in a kind of arc along the top, with more or less equal spacing"; a real reader
## "will often have an entire table of stuff", much of it cut by the frame's edge, and "push the props
## to the left and right edges, such that the middle of the table remains more free"). Patterns
## guided toward, never enforced ([method _habit_of]): how far each group's spot wanders off its
## zone's middle (meters, x and z), how far the things are pushed out to the sides at the most, and
## the least share of a thing's picture the frame may keep when it cuts it - an unlit thing only; a
## lit one is the light and stands wholly in the shot.
const AIM_WANDER := Vector2(0.08, 0.05)
const EDGE_PUSH := 0.2
const SEEN_LEAST := 0.55
## A THING ACROSS A CLOTH'S EDGE - half on the cloth, half on the bare top - reads as set down
## carelessly (the user, 2026-10-08), unless it is large: a book, a tray may lie across a hem. So a
## spot whose foot crosses a layer's edge scores this much worse (as many meters from its aim, over 4),
## and a thing wider than STRADDLE_BIG only a third of it.
const STRADDLE := 0.5
const STRADDLE_BIG := 0.18
## THE DECK PUT ASIDE (the user, 2026-10-08: a long row comes "oddly close to the deck ... TOO close"):
## when a card of the spread would lie within DECK_CROWD of the deck (meters, edge to edge), the reader
## slides the deck further out before drawing it - in an episode that draws DECK_ASIDE or under - over
## ASIDE_S seconds, ending as that card is taken.
const DECK_CROWD := 0.07
const DECK_ASIDE := 0.75
const ASIDE_S := 0.45
## How far a card sliding across the cloth keeps from a thing's foot (meters).
const FOOT_MARGIN := 0.004
## HOW HOT A CANDLE'S POOL MAY BURN: its light times the hottest spot of cloth round it - the
## cloth's linear luminance there over the flame's falloff (its height over the distance squared).
## The key's light on a felt of luminance 0.18 is the measure - it reads as a candle. On pale pine
## (0.64) the same light flooded half the frame through the bloom, and a cream stripe just behind a
## candle on a near-black blanket blew out though the cloth round it was dark on average.
const HEAT := 2.0
## ...looked for this far round the candle, meters, on the table's lightness at this grid over the
## stretch of table the camera can see (x z, meters; 4 cm cells); and the flame height a candle's
## place is judged at.
const HEAT_R := 0.25
const LUM_RECT := CardTable.SEEN_RECT
const LUM_GRID := CardTable.SEEN_GRID
const HEAT_H := 0.13
## The key candle's light, the least a candle must be allowed to be the key, and every other
## candle's.
const KEY_ENERGY := 1.5
const KEY_MIN := 1.0
const FILL_ENERGY := 0.35
## A table with a light of its own ([Lights]) whose sun and lamps light the cards less than this, and
## which no candle can lead, has the lamp hung over it after all.
const LAMP_FALLBACK := 0.12
## The render layer of the first candle's body (the next is the next bit), so each flame can leave
## its own candle out of its shadows - and only its own: a candle stands in the key's light.
const CANDLE_LAYER := 1 << 12
## The render layer of a thing with no flame: off the cloth's layer, so the shade a thing presses
## into the cloth falls on the cloth alone.
const THING_LAYER := 1 << 1
## The intro's focus pull: it starts this long before the reading opens and takes this long after it
## (seconds), from a lens this soft (CameraAttributesPractical.dof_blur_amount).
const FOCUS_PULL := Vector2(1.4, 1.6)
const FOCUS_BLUR := 0.16
## THE INTRO, THROWN FAR OUT OF FOCUS: while the name is up, the whole frame is drawn through a
## Gaussian [constant CardTable.TITLE_BLUR] of its height wide ([constant INTRO_SHADER]). It lifts
## over the first INTRO_LIFT of the focus pull, eased through its log down to INTRO_SHARP (half a
## pixel at 1080), then is taken off; the lens's own near-to-far pull carries on from there.
const INTRO_SHADER := preload("res://shaders/table_intro.gdshader")
const INTRO_LIFT := 0.5
const INTRO_SHARP := 0.0005
const LEAD := 0.25
const TAIL := 0.2

const FOIL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 window = vec4(0.0, 0.0, 1.0, 1.0);   // the picture's part of the face, in UV
uniform float lo = 0.8;                            // the picture's own foil key (luminance)
uniform float hi = 0.95;
uniform vec3 accent = vec3(0.58, 0.36, 0.02);      // the frame's foil color, linear as tex is sampled
uniform vec3 stock = vec3(-1.0);                   // the card's stock: a shaped window's corners are stock, never foil
uniform float foil = 0.6;                          // how much foil the deck was printed with
uniform float pulse = 0.5;                         // the slow breath, 0..1
uniform float glint = -1.0;                        // the sweep's place along the diagonal
uniform float lift = 0.14;                         // a little self-light, so the art reads
uniform float dim = 1.0;                           // the bookend
void fragment() {
	// A face is a viewport's texture and has no mip chain, so a card seen smaller than its 560 x 960
	// (always, and more so at a grazing angle) was sampled with plain bilinear taps that skip texels:
	// a thin line came out as two offset, half-strength copies (feedback 0012, the back's ring and
	// keys). The pixel's footprint is averaged by hand instead: a 4 x 4 box across it.
	vec2 ddx = dFdx(UV);
	vec2 ddy = dFdy(UV);
	vec4 c = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		for (int j = 0; j < 4; j++) {
			vec2 o = vec2(float(i), float(j)) * 0.25 - 0.375;
			c += texture(tex, UV + ddx * o.x + ddy * o.y);
		}
	}
	c *= 0.0625;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	float inside = step(window.x, UV.x) * step(UV.x, window.z) * step(window.y, UV.y) * step(UV.y, window.w);
	float key = inside * smoothstep(lo, hi, lum) * mix(0.45, 1.0, sat) * smoothstep(0.03, 0.09, distance(c.rgb, stock));
	// the frame's own accent prints as foil too - on the FRAME only: inside the painting the same
	// color may be the whole ground of the picture
	key = max(key, (1.0 - inside) * (1.0 - smoothstep(0.06, 0.16, distance(c.rgb, accent))));
	key *= foil;
	float band = 0.0;
	if (glint > -0.5) {
		float d = (UV.x + UV.y) * 0.5 - glint;
		band = exp(-d * d / 0.004);
	}
	ALBEDO = c.rgb * dim;
	ROUGHNESS = mix(0.66, 0.2, key);
	METALLIC = key * 0.6;
	SPECULAR = mix(0.4, 0.8, key);
	// bright enough to cross the bloom's threshold, breathing between a glow and a blaze; a
	// foil that only ever reached the threshold was measured to change the picture by a level or two
	EMISSION = c.rgb * dim * (lift + key * (1.3 + 2.2 * pulse) + key * band * 5.0);
}
"""

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
uniform vec3 color = vec3(1.0, 0.65, 0.3);
uniform float energy = 4.0;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.62);
	p.x *= 2.2;
	float body = 1.0 - smoothstep(0.0, 0.42, length(vec2(p.x, p.y * (p.y < 0.0 ? 0.55 : 1.0))));
	float core = 1.0 - smoothstep(0.0, 0.16, length(vec2(p.x * 1.4, p.y + 0.12)));
	vec3 col = mix(color, vec3(1.0, 0.97, 0.88), core);
	ALBEDO = col * energy * body;
	ALPHA = body;
}
"""

var _subs = null
var _pay: Dictionary = {}           # the episode, as the panel handed it over (CardEpisode.document)
var _source := ""                   # the reading's script
var _parse: Dictionary = {}
var _follow := ReadingFollower.new()
var _sched: Array = []
var _built_n := -1
var _key := ""
var _now := 0.0
var _seed := 0
var _look: Dictionary = {}
var _staging: Dictionary = CardTable.STAGING.duplicate()   # how the cards come and are shown (CardTable.staging_of)
var _cards_from := "deck"                 # where they come from: the reading's opening verb's, else the staging's
var _alone := false                   # a drawn card with text on either face is held up alone
var _backs := {}                      # printing name ("" the deck's own) -> {vp, canvas, mat}: each printing's back
var _printed: Array = []              # per drawn card, when its text is on its back: {vp, canvas, mat}
var _box := {}                        # the box the cards are kept in, stood: {node, at, inner (AABB, world), upright, lie}
var _file: Array = []                 # the cards filed in it: MultiMeshInstance3D, one per printing
var _box_objects: Array = []          # optional small keepsakes inside the box

var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _cam_base := Transform3D.IDENTITY
var _env: Environment
var _attrs: CameraAttributesPractical
var _lamp: SpotLight3D
var _fill: DirectionalLight3D
var _furniture := {}                 # the table itself, built (Tables.build): its top and its layers
var _top := {}                       # ...its top, made safe: where cards and things may lie
var _top_o := Tables.top_outline({})  # ...its outline, read once (Tables.sdf), for the thousands of spots a thing is tried at
var _painting_tex: Texture2D = null  # the episode's surface painting, as laid on the table
var _height_tex: Texture2D = null    # ...the painter's height map of it, when one lined up with it
var _backdrop: MeshInstance3D
var _backdrop_mat: ShaderMaterial
var _rest_plan: Dictionary = {}     # the wash plan [member _rest_steps] are of
var _rest_steps := {}               # plan step -> every card at rest there ([method _wash_rest])
var _props: Node3D
var _probe: ReflectionProbe
var _probe_nudge := 1.0
var _lights: Array = []             # a light per lit thing: {light, base, light_base, energy, flames: [{mesh, base, flicker, glow}]}
var _flame_n := 0                     # flames lit so far on this table, each with its own flicker
## A candle's flame: how tall it burns (meters - what a draft must blow against, [method Winds.flame]) and
## the quad it is drawn on, standing on its wick.
const FLAME_H := 0.03
const FLAME_QUAD := 0.03
var _glows: Array = []              # [{light, base, energy, flicker}] - candles in the room, out of shot
var _lamp_base := 1.6                 # the lamp's light before a candle takes the key from it
var _key_flame := -1                  # the key: the flame that leads the light, or -1 for the lamp
var _lum := PackedFloat32Array()      # the table's linear luminance where candles may stand (LUM_RECT); empty: not yet built
var _heat_cells := {}                 # grid cell -> its heat at HEAT_H, for this build
var _contact_tex: Texture2D = null
var _lit_cloth: Texture2D = null      # the painting the table was last lit for
var _shuffle_room := INF             # how long the shuffle has, from its start to the first card
var _jump_room := -1.0                # ...when that first card is a jumper (-1: it is not, or not placed yet)
var _jump_scale := 1.0                # ...and the speed its action is performed at
var _wash_held := false               # the shuffle holds its wash back for a jumper ([method _jumper_wash])
var _wash_from := 0.0                 # ...when (into the shuffle) it begins - before the first run ends, at once
var _wash_until := 0.0                # ...and when it would end, past the jumper reckoned
var _deck_gone := 0                   # deck meshes gone from the deck (a jumper thrown out of a wash)
var _standing: Array = []             # what stands on the table: convex feet (x by z), for a wash to go round
var _standing_c := PackedVector2Array()   # ...their middles
var _standing_r := PackedFloat32Array()   # ...and how far they reach from them
var _habit := {}                     # how this episode's reader sets out their things (_habit_of)
var _layer_os: Array = []             # the layers' outlines (Tables.layer_outline), for a foot across a hem
var wash_calm := true                # the fan-out calmed (CALM_HZ); a gate's control turns it off
var _deck_far := Vector3.ZERO         # where the deck is slid aside to, when the spread crowds it
var _aside_card := -1                 # the card it is slid aside for (-1: it stays)
var _things: Array = []               # what stood: [{name, group, place, node, outline, bb, rect, foot, lit, flames, meshes}]
var _collide := true                  # cards go round what stands (off only for a gate's control)
var _table_mt := -2                   # the table file's time when it was last built (-1: none)
var _stage_was := {}                  # the stage's own settings, given back on leaving it
var _deck: Array = []               # DECK_N MeshInstance3D, bottom first
var _cards: Array = []              # one MeshInstance3D per drawn card
var _faces: Array = []              # one SubViewport per drawn card's face
var _face_canvas: Array = []
var _face_mats: Array = []
var _back_vp: SubViewport
var _back_canvas: CardFaces.Face
var _back_mat: ShaderMaterial
var _page: MeshInstance3D
var _page_vp: SubViewport
var _page_canvas: CardFaces.Page
var _page_mat: StandardMaterial3D
var _page_for := -1
var _blur: IntroBlur
var _title: TitleCard
var _card_mesh: ArrayMesh
var _meshes := {}                   # "radius|thickness" -> a card's slab cut to it ([method _mesh_for])
var _edge_mat: StandardMaterial3D

# the episode's table, sampled from its seed
var _deck_base := Vector3.ZERO      # where the deck is drawn from, to one side
var _mid := Vector3.ZERO            # where it is shuffled, in the middle of the table
var _cur_base := Vector3.ZERO       # where it is at the moment being posed (see _deck_at)
var _slots: Array = []              # per card: Transform3D where it lies in the spread
var _jump_land := Vector3.ZERO
var _slot_jit: Array = []           # per deck slot: Vector3(x, z, yaw)
var _lay_jit: Array = []            # per shown card: a small, repeatable placement difference
var _moves: Array = []              # the shuffle: [{kind, t0, dur, seed}]
var _move_rng := RandomNumberGenerator.new()
var _pitch := 45.0
var _foil := 0.6
var _noise := FastNoiseLite.new()
var _mtimes := {}
var _poll_t := 0.0
var _textures := {}
var _air = null                     # the set dresser's effects, built (Effects.Air), or null
var _air_key := ""                  # the schedule its bursts were last planned on
var _spin_wanted := false           # a burst marks a pirouette: one card is twirled ([method _spin_card])
var _spin_key := ""                 # ...the schedule it was chosen on
var _spin_k := -1                   # ...and the card
var _rig = null                     # the set dresser's light, built (Lights.Rig), or null: the lamp and the room's candles
## BUILT ASIDE, on a worker thread ([method TablePreview._stand]): its long loops then [method _breathe]
var aside := false
var _breaths := 0
var _wind := {}                     # the table's wind (Winds.plan): its light's, or still air - shared by the light and the air
var _ambient := {}                  # the room's own ambient, for a table with no light of its own
var _seen := PackedVector3Array()   # the table the camera sees, sampled (for the light), this build


# --- mount -----------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	# EDGES: the deck's stacked card edges and the shadow edges stair-stepped. 4x multisampling on
	# the stage (a light scene - cheap), and a bigger atlas whose first quadrant is one whole slot,
	# for the light whose shadows cover the most; the other lights take the next quadrant's four
	# (every candle and the lamp cast: four candles at most). Given back when the table leaves.
	_stage_was = {"msaa": st.msaa_3d, "atlas": st.positional_shadow_atlas_size,
		"quad": st.positional_shadow_atlas_quad_0}
	st.msaa_3d = Viewport.MSAA_4X
	st.positional_shadow_atlas_size = 4096
	st.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	# the intro's bokeh: round, and fine enough to be a lens rather than a smear
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_build_world()
	# the intro's blur over the table, under the name
	_blur = IntroBlur.new(INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	add_child(_title)


func _build_world() -> void:
	_root3 = Node3D.new()
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.018, 0.02)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.46, 0.44)
	_env.ambient_light_energy = 0.18
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.82
	_env.adjustment_enabled = true
	# THE BLOOM the foil and the flames bleed through: only what is brighter than white glows
	_env.glow_enabled = true
	_env.glow_normalized = false
	_env.glow_intensity = 0.75
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.25
	_env.glow_hdr_scale = 2.0
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.set_glow_level(0, 0.0)
	_env.set_glow_level(1, 0.6)
	_env.set_glow_level(2, 1.0)
	_env.set_glow_level(3, 0.8)
	_env.set_glow_level(4, 0.4)
	_cam = Camera3D.new()
	_cam.fov = VFOV
	_cam.near = 0.02
	_cam.far = 40.0
	_cam.environment = _env
	# THE ROOM IS OUT OF FOCUS: the table is where the eye is, and a painted room far behind it
	# reads as a place rather than as a picture of one
	# NOT BY DEPTH OF FIELD: a far blur behind the table drew a band along its far edge - the sharp
	# table and the blurred room bleeding into each other where their depths meet. The room's own
	# picture is drawn through a lens blur instead ([constant ROOM_SHADER]), which is also cheaper;
	# the lens's blur is kept for the intro, when the whole table is out of focus ([method _tick_focus]).
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)

	_lamp = SpotLight3D.new()
	_lamp.light_energy = 1.6
	_lamp.spot_range = 4.0
	_lamp.spot_angle = 38.0
	_lamp.spot_angle_attenuation = 2.2
	_lamp.shadow_enabled = true
	_lamp.shadow_blur = 1.6
	# A TABLETOP'S BIASES, as the candles' are. At Godot's own (made for rooms) the depth and normal
	# biases came to millimeters at the lamp's distance - more than a bowl's floor stands off the
	# cloth - so anything low cast nothing, a bowl only its rim's ring (a crescent), and taller things
	# a shadow standing off their feet. Softened by the blur alone: a spot's light_size threw a white
	# glare off a geode's rim facing it.
	_lamp.shadow_bias = 0.005
	_lamp.shadow_normal_bias = 0.15
	# the sun's screens and birds ([Lights]) are the sun's alone
	_lamp.shadow_caster_mask = 0xFFFFFFFF & ~Lights.SCREEN_MASK
	_root3.add_child(_lamp)
	_fill = DirectionalLight3D.new()
	_fill.light_energy = 0.12
	_fill.rotation_degrees = Vector3(-60.0, 25.0, 0.0)
	_root3.add_child(_fill)

	# THE TABLE ITSELF is built with its things, from the set dresser's description ([method _build_table])
	_backdrop = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(1.0, 1.0)
	_backdrop.mesh = bq
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = ROOM_SHADER
	_backdrop.material_override = _backdrop_mat
	# A PICTURE CASTS NO SHADOW: a sun low behind the table would throw the room's picture over it
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root3.add_child(_backdrop)

	_props = Node3D.new()
	_root3.add_child(_props)
	# WHAT THE THINGS REFLECT: the table and the room, caught once when the table is set (see
	# _reflect). Metal with nothing to reflect read as flat paint. The things alone take it: the
	# cards and the cloth keep the light they were tuned under.
	_probe = ReflectionProbe.new()
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.size = Vector3(1.9, 1.0, 1.4)
	_probe.position = Vector3(0.0, 0.2, -0.05)
	_probe.box_projection = true
	_probe.max_distance = 5.0
	_probe.enable_shadows = true
	_probe.reflection_mask = THING_LAYER | (CANDLE_LAYER * 0xF)
	_root3.add_child(_probe)

	_card_mesh = _make_card_mesh(CARD, CARD_T, CARD_R)
	_edge_mat = StandardMaterial3D.new()
	_edge_mat.albedo_color = Color(0.9, 0.88, 0.82)
	_edge_mat.roughness = 0.8
	var deck_mesh := _make_card_mesh(CARD, DECK_T, CARD_R)
	_back_canvas = CardFaces.Face.new()
	_back_canvas.back = true
	_back_vp = CardFaces.viewport(self, _back_canvas, CardFaces.FACE_PX)
	_back_mat = _foil_material(_back_vp.get_texture())
	_back_mat.set_shader_parameter("lift", 0.06)
	var unseen := StandardMaterial3D.new()
	unseen.albedo_color = Color(0.92, 0.9, 0.85)
	for i in DECK_N:
		var m := MeshInstance3D.new()
		m.mesh = deck_mesh
		m.set_surface_override_material(0, unseen)
		m.set_surface_override_material(1, _back_mat)
		m.set_surface_override_material(2, _edge_mat)
		_root3.add_child(m)
		_deck.append(m)

	_page = MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(PAGE_H * CardFaces.PAGE_ASPECT, PAGE_H)
	_page.mesh = pq
	_page_canvas = CardFaces.Page.new()
	_page_vp = CardFaces.viewport(self, _page_canvas, CardFaces.PAGE_PX)
	_page_mat = StandardMaterial3D.new()
	_page_mat.albedo_texture = _page_vp.get_texture()
	_page_mat.emission_enabled = true
	_page_mat.emission_texture = _page_vp.get_texture()
	_page_mat.emission_energy_multiplier = 0.32
	_page_mat.roughness = 0.85
	_page_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_page.material_override = _page_mat
	_page.visible = false
	_root3.add_child(_page)


## A card: a thin slab with rounded corners - surface 0 the face (on -Y), 1 the back (on +Y), 2
## the edge. Width along X, height along Z with the card's TOP at -Z, so a card lying face down
## with its top away from the reader turns face up the right way round when flipped about its
## long side (see [method _face_up]).
static func _make_card_mesh(size: Vector2, t: float, r: float) -> ArrayMesh:
	var outline := PackedVector2Array()
	var seg := 6
	var hw := size.x * 0.5 - r
	var hd := size.y * 0.5 - r
	var centers := [Vector2(hw, hd), Vector2(-hw, hd), Vector2(-hw, -hd), Vector2(hw, -hd)]
	for c in 4:
		for i in seg + 1:
			var a := (float(c) + float(i) / float(seg)) * PI * 0.5
			outline.append(centers[c] + Vector2(cos(a), sin(a)) * r)
	var mesh := ArrayMesh.new()
	var n := outline.size()
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y: float = side * t * 0.5
		for i in n:
			var a := outline[i]
			var b := outline[(i + 1) % n]
			var tri := [Vector2.ZERO, a, b] if side > 0.0 else [Vector2.ZERO, b, a]
			for p in tri:
				var v := p as Vector2
				st.set_normal(Vector3(0.0, side, 0.0))
				# the face is seen from below until the card is turned: its U runs the other way
				var u := (0.5 + v.x / size.x) if side > 0.0 else (0.5 - v.x / size.x)
				st.set_uv(Vector2(u, 0.5 + v.y / size.y))
				st.add_vertex(Vector3(v.x, y, v.y))
		st.commit(mesh)
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var na := Vector3(a.x, 0.0, a.y).normalized()
		var nb := Vector3(b.x, 0.0, b.y).normalized()
		for v in [[a, t * 0.5, na], [b, -t * 0.5, nb], [b, t * 0.5, nb],
				[a, t * 0.5, na], [a, -t * 0.5, na], [b, -t * 0.5, nb]]:
			rim.set_normal(v[2])
			rim.add_vertex(Vector3((v[0] as Vector2).x, v[1], (v[0] as Vector2).y))
	rim.commit(mesh)
	return mesh


func _foil_material(tex: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = FOIL_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex)
	return m


# --- the Medium contract -----------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The words are spoken, not printed: the karaoke line stays (return false). Its clock is the
## table's.
func bind_captions(subs) -> bool:
	_subs = subs
	_key = ""
	return false


func begin_session() -> void:
	_key = ""


func release() -> void:
	_subs = null
	_key = ""


func _exit_tree() -> void:
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		stage.msaa_3d = _stage_was["msaa"]
		stage.positional_shadow_atlas_size = _stage_was["atlas"]
		stage.positional_shadow_atlas_quad_0 = _stage_was["quad"]


func on_stage_resized(_size: Vector2) -> void:
	if _blur != null:
		_blur.queue_redraw()
	if _title != null:
		_title.queue_redraw()


func advance(_features, delta: float, _bookend: float) -> void:
	var t := maxf(Spectrum.current.time, 0.0)
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	_ensure_doc()
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0
		_poll_pictures()
	if not _parse.is_empty() and _subs != null and is_instance_valid(_subs):
		_follow.extend(_subs.words)
		var n := _follow.map.size()
		if n != _built_n:
			_built_n = n
			_sched = _follow.place(_parse["actions"], maxf(Director.intro_hold, 0.6), LEAD, TAIL)
	# up from black as the session starts, down to it after the last word - the table owns its
	# bookend, so the Director's whole-take fade is not used; an outro mark's fade still is
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0) * _end_fade(_now) * Director.live_fade, 0.0, 1.0)
	_pose(_now)
	_tick_focus(_now)
	_tick_camera(_now)
	_tick_props(_now)
	_tick_light(_now)
	_tick_air(_now)
	_title.alpha = _title_alpha(_now)
	_title.queue_redraw()


# --- the episode ----------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	var pay: Dictionary = d.get("table", {}) if d.get("table") is Dictionary else {}
	var src := String(d.get("source", ""))
	var key := "%s|%d|%d" % [String(pay.get("dir", "")), int(pay.get("seed", 0)), hash(src)]
	if key == _key:
		return
	_key = key
	_pay = pay
	_source = src
	_parse = CardReading.parse(src) if not src.is_empty() else {}
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	_look = CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})
	_seed = int(pay.get("seed", 0))
	_foil = float(_look.get("foil", 0.6))
	_staging = CardTable.staging_of(plan)
	_cards_from = String(_parse.get("source", _staging["source"])) if not _parse.is_empty() else String(_staging["source"])
	_alone = String(_staging["text"]) != "booklet"
	# A READING STARTED MID-WAY (a scrub) begins where its first words are: everything before them
	# happened long ago, spaced as a voice would have said it, so the cards drawn by then are
	# already down (or up) on the first frame
	var spoken: PackedStringArray = _parse.get("spoken", PackedStringArray()) if not _parse.is_empty() \
		else PackedStringArray()
	var start_si := -1
	var sw: Variant = d.get("start_words", PackedStringArray())
	if sw is PackedStringArray and not (sw as PackedStringArray).is_empty() and not spoken.is_empty():
		start_si = TabletScript.find_run(spoken, sw, int(d.get("start_index", -1)))
	_follow.reset(spoken, start_si, _estimated_times(spoken.size()))
	_built_n = -1
	_sched = []
	var t0 := Time.get_ticks_msec()
	_build_episode()
	print("ghost: card table - %s #%d, %d cards, %d actions, %d things (built in %d ms)" % [String(pay.get("show", "?")), _seed,
		(pay.get("cards", []) as Array).size(), (_parse.get("actions", []) as Array).size(), _things.size(),
		Time.get_ticks_msec() - t0])


## Each spoken word's time along the reading as a voice would say it - the past a mid-way start
## is replayed in: the intro, then a word every 0.4 s, and each action's own rest.
func _estimated_times(n: int) -> PackedFloat32Array:
	var rests := {}
	for a in _parse.get("actions", []):
		var k := int((a as Dictionary)["after"])
		rests[k] = float(rests.get(k, 0.0)) + float((a as Dictionary)["dur"]) + LEAD + TAIL
	var out := PackedFloat32Array()
	out.resize(n)
	var t := maxf(Director.intro_hold, 0.0)
	for j in n:
		t += float(rests.get(j, 0.0))
		out[j] = t
		t += 0.4
	return out


## Everything sampled from the episode's seed, and the episode's own cards.
func _build_episode() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "tarot-table"])
	# THE CHANNEL'S NAME ONLY: the episode's title is the video's, on the platform, not on the table
	_title.channel = String(_subs.document.get("title", "")) if _subs != null else ""
	# ...and the show's byline under it, when it has one ("with Pen & Ink")
	_title.byline = String(_subs.document.get("byline", "")) if _subs != null else ""
	# THE CHANNEL'S NAME IS THE CHANNEL'S, set the same way every episode - a brand, not a
	# deck's lettering (an uncial deck turned "Truthful" into "Truchful")
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	var lay := CardTable.sample_layout(rng)
	# THE CAMERA: the reader's eye, a little different every episode
	_pitch = float(lay["pitch"])
	_cam_base = lay["camera"]
	_cam.transform = _cam_base
	_cam.fov = float(lay["fov"])
	# THE LIGHT: the look's own, from above and to one side
	var lc := CardTable.color(String((_look.get("light", {}) as Dictionary).get("color", "#ffb36b")))
	_lamp.light_color = Color(1, 1, 1).lerp(lc, 0.55)
	_lamp.position = lay["lamp"]
	# AIMED BY ITS OWN TRANSFORM, what look_at does under _root3 (never moved): look_at needs the tree, and
	# the set dresser's table is built out of it, on a worker thread ([method TablePreview._stand])
	var lamp_scale := _lamp.scale
	_lamp.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -0.1) - _lamp.position, Vector3.UP), _lamp.position)
	_lamp.scale = lamp_scale
	_lamp.light_energy = float(lay["lamp_energy"])
	_lamp_base = _lamp.light_energy
	var pal: Array = _look.get("palette", CardTable.FALLBACK_PALETTE)
	var dark := CardTable.color(String(pal[0]))
	_env.background_color = dark.darkened(0.6)
	_env.ambient_light_color = Color(0.5, 0.5, 0.5).lerp(dark.lightened(0.4), 0.35)
	_ambient = {"color": _env.ambient_light_color, "energy": 0.18}
	_fill.light_color = Color(0.75, 0.8, 1.0) if String((_look.get("light", {}) as Dictionary).get("warmth", "warm")) == "warm" else lc
	# THE DECK, squared where the reader keeps it
	_deck_base = lay["deck"]
	# SHUFFLED IN THE MIDDLE, in front of the reader, and pushed to its side before the first card
	_mid = lay["mid"]
	_cur_base = _mid
	_slot_jit = []
	for i in DECK_N + 1:
		_slot_jit.append(Vector3(rng.randf_range(-0.0007, 0.0007), rng.randf_range(-0.0007, 0.0007),
			deg_to_rad(rng.randf_range(-1.3, 1.3))))
	# THE CARDS
	for c in _cards:
		(c as Node).queue_free()
	for v in _faces:
		(v as Node).queue_free()
	for pb in _printed:
		((pb as Dictionary)["vp"] as Node).queue_free()
	_printed = []
	_cards = []
	_faces = []
	_face_canvas = []
	_face_mats = []
	# THIS EPISODE'S PICTURES ARE KEPT across its sessions (each Play, each scrub): decoding a
	# dozen full-size paintings on the main thread is a visible hitch. Another episode's go.
	var keep_dir := String(_pay.get("dir", "")) + "/"
	for k in _textures.keys():
		if not String(k).begins_with(keep_dir):
			_textures.erase(k)
			_mtimes.erase(String(k))
	var cards: Array = _pay.get("cards", [])
	_build_backs(cards)
	for i in cards.size():
		var canvas := CardFaces.Face.new()
		# EACH CARD IN ITS OWN PRINTING: a box may mix sets, each with its own front and back
		canvas.look = CardTable.look_of(_look, cards[i])
		canvas.card = cards[i]
		canvas.details = String(_staging["text"]) == "front"
		canvas.seed = _seed
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("window", _face_window(canvas.look, canvas.details))
		_foil_stock(mat, canvas.look)
		var m := MeshInstance3D.new()
		m.mesh = _mesh_for(canvas.look)
		m.set_surface_override_material(0, mat)
		m.set_surface_override_material(1, _back_of(i, cards[i]))
		m.set_surface_override_material(2, _edge_mat)
		m.visible = false
		_root3.add_child(m)
		_cards.append(m)
		_faces.append(vp)
		_face_canvas.append(canvas)
		_face_mats.append(mat)
	_back_canvas.look = _look
	_back_vp.size = CardFaces.face_px(_look)
	_back_canvas.seed = _seed
	_foil_stock(_back_mat, _look)
	var deck_mesh := _mesh_for(_look, DECK_T)
	for d in _deck:
		(d as MeshInstance3D).mesh = deck_mesh
	_back_mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
	_edge_mat.albedo_color = CardTable.color(String((_look.get("frame", {}) as Dictionary).get("stock", "#efe6d2"))).darkened(0.08)
	_page_canvas.look = _look
	_page_canvas.seed = _seed
	_page_for = -1
	# THE SPREAD: where the cards were given to lie (a plan's coordinates, a dealer's layout - checked
	# on the cloth, in the frame and clear of the deck), else the seeded preset. The preset is drawn
	# either way, so every draw after it lands where it always has.
	var seeded := TablePositions.staged(cards, rng, CardTable.layout_of(_seed), _box_keep(), _box_center())
	var spec := _table_spec()
	var given := TablePositions.given(cards, _seed, spec["top"], _box_keep(), _box_center())
	_slots = given if not given.is_empty() else seeded
	_lay_jit = []
	var placement := RandomNumberGenerator.new()
	placement.seed = hash([_seed, "lay by hand"])
	for i in cards.size():
		_lay_jit.append(Vector3(placement.randf_range(-0.0015, 0.0015),
			placement.randf_range(-0.0015, 0.0015), deg_to_rad(placement.randf_range(-1.2, 1.2))))
	_plan_aside(spec["top"])
	# a jumper flies out of the deck in the middle and lands on the far side from where the deck
	# is about to go
	_jump_land = _mid + Vector3(-signf(_deck_base.x) * 0.16, 0.0, 0.035)
	_build_table(spec)
	_plan_moves()
	_place_backdrop()
	_poll_pictures()
	for vp in _faces:
		CardFaces.redraw(vp)
	CardFaces.redraw(_back_vp)
	for pb in _printed:
		CardFaces.redraw((pb as Dictionary)["vp"])


## THE BACKS: the deck's own ([member _back_vp]), and one more per printing the drawn cards (and the box,
## when the producer chose it) are printed in ([method CardTable.look_of]).
func _build_backs(cards: Array) -> void:
	for key in _backs:
		if String(key) != "":
			((_backs[key] as Dictionary)["vp"] as Node).queue_free()
	_backs = {"": {"vp": _back_vp, "canvas": _back_canvas, "mat": _back_mat}}
	for name in _printings(cards):
		if String(name).is_empty() or _backs.has(name):
			continue
		var canvas := CardFaces.Face.new()
		canvas.back = true
		canvas.look = CardTable.look_of(_look, {"series": name})
		canvas.seed = _seed
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("lift", 0.06)
		mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
		_foil_stock(mat, canvas.look)
		_backs[name] = {"vp": vp, "canvas": canvas, "mat": mat}


## Every printing the episode's cards are in, the deck's own ("") among them when any card is in it: the
## drawn cards', and the whole box's when the producer chose one.
func _printings(cards: Array) -> Array:
	var out: Array = []
	var plan: Dictionary = _pay.get("plan", {}) if _pay.get("plan") is Dictionary else {}
	var all: Array = cards.duplicate()
	all.append_array(plan.get("deck", []) if plan.get("deck") is Array else [])
	for c in all:
		var name := CardTable.series_of(_look, c as Dictionary) if c is Dictionary else ""
		if not out.has(name):
			out.append(name)
	var inventory: Dictionary = plan.get("inventory", {}) if plan.get("inventory") is Dictionary else {}
	var counts: Dictionary = inventory.get("printings", {}) if inventory.get("printings") is Dictionary else {}
	for name in counts:
		if int(counts[name]) > 0 and not out.has(String(name)):
			out.append(String(name))
	if out.is_empty():
		out.append("")
	return out


## Card [param i]'s back: its printing's - or, when its text is printed on its back, its very own.
func _back_of(i: int, card: Dictionary) -> Material:
	var name := CardTable.series_of(_look, card)
	if String(_staging["text"]) != "back":
		return (_backs.get(name, _backs[""]) as Dictionary)["mat"]
	var canvas := CardFaces.Face.new()
	canvas.back = true
	canvas.printed = true
	canvas.look = CardTable.look_of(_look, card)
	canvas.card = card
	canvas.seed = _seed
	var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
	var mat := _foil_material(vp.get_texture())
	mat.set_shader_parameter("lift", 0.06)
	mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
	while _printed.size() <= i:
		_printed.append({})
	_printed[i] = {"vp": vp, "canvas": canvas, "mat": mat, "series": name}
	return mat


## Where the box the cards are kept in may stand, across and deep - kept clear by the spread - or zero
## when they come from a deck.
func _box_keep() -> Vector2:
	var most := CardTable.SHOEBOX_MAX if String(_staging.get("box_style", "open")) == "shoebox" else CardTable.BOX_MAX
	return Vector2(most.x, most.z) if _cards_from == "box" else Vector2.ZERO


func _box_center() -> Vector3:
	return TablePositions.SHOEBOX_AT if _cards_from == "box" and String(_staging.get("box_style", "open")) == "shoebox" else Vector3.ZERO


## The part of a face that is the painting, in UV - foil is keyed inside it (the frame's foil is
## keyed by its color instead).
func _face_window(look: Dictionary = {}, details := false) -> Vector4:
	var sz := Vector2(CardFaces.face_px(look))
	var w := CardFaces.front_window(look, details)
	return Vector4(w.position.x / sz.x, w.position.y / sz.y, w.end.x / sz.x, w.end.y / sz.y)


## The card's stock, for the foil to leave alone where a shaped window's corners show it. LINEAR, as
## the face's texture is sampled: in sRGB a pale stock missed by ~0.2 and an oval's corners blazed
## white as foil (feedback 0005).
static func _foil_stock(mat: ShaderMaterial, look: Dictionary) -> void:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	var c := CardTable.color(String(f.get("stock", "#efe6d2"))).srgb_to_linear()
	mat.set_shader_parameter("stock", Vector3(c.r, c.g, c.b))


## The frame's accent, for the foil to find on the frame's lines. LINEAR too: in sRGB a line's own
## color missed it by ~0.4 and the texels of its edge, half blended toward the stock, hit it - a dark
## line with a bright, stair-stepped foil fringe down each side (the corners' aliasing in the 1327
## export, tests/card_foil_check.gd).
static func _foil_accent(mat: ShaderMaterial, look: Dictionary) -> void:
	var f: Dictionary = look.get("frame", {}) if look.get("frame") is Dictionary else {}
	var c := CardTable.color(String(f.get("accent", "#c9a227"))).srgb_to_linear()
	mat.set_shader_parameter("accent", Vector3(c.r, c.g, c.b))


## THE CARD'S SLAB for [param look], cut to its corners ([method CardTable.corner_radius]) - one mesh per
## radius and thickness, shared.
func _mesh_for(look: Dictionary, t := CARD_T) -> ArrayMesh:
	var size := CardTable.card_size(look)
	var r := minf(CardTable.corner_radius(look), size.x * 0.12)
	var key := "%.5f|%.5f|%.5f|%.5f" % [size.x, size.y, r, t]
	if not _meshes.has(key):
		_meshes[key] = _make_card_mesh(size, t, r)
	return _meshes[key]


## Pictures that have landed since last looked - live, a reading can start while the deck is
## still being painted.
func _poll_pictures(force := false) -> void:
	var dir := String(_pay.get("dir", ""))
	if dir.is_empty():
		return
	for i in _cards.size():
		var tex := _picture(dir.path_join("card_%d.png" % (i + 1)), force)
		if tex != null and (_face_canvas[i] as CardFaces.Face).art != tex:
			(_face_canvas[i] as CardFaces.Face).art = tex
			var key: Vector2 = _textures.get(dir.path_join("card_%d.png" % (i + 1)) + "|key", Vector2(0.8, 0.95))
			var mat: ShaderMaterial = _face_mats[i]
			mat.set_shader_parameter("lo", key.x)
			mat.set_shader_parameter("hi", key.y)
			CardFaces.redraw(_faces[i])
		_foil_accent(_face_mats[i], _look)
		(_face_mats[i] as ShaderMaterial).set_shader_parameter("foil", _foil)
	# EACH PRINTING'S BACK (`back.png` the deck's own, `back_<printing>.png` the others'), and every back
	# printed with a card's text over its printing's
	for name in _backs:
		var file := "back.png" if String(name).is_empty() else "back_%s.png" % CardTable.series_key(String(name))
		var back := _picture(dir.path_join(file), force)
		if back == null and not String(name).is_empty():
			back = _picture(dir.path_join("back.png"), force)
		var bk: Dictionary = _backs[name]
		var pkey: Vector2 = _textures.get(dir.path_join(file) + "|key", Vector2(0.8, 0.95))
		if back != null and (bk["canvas"] as CardFaces.Face).art != back:
			(bk["canvas"] as CardFaces.Face).art = back
			(bk["mat"] as ShaderMaterial).set_shader_parameter("lo", pkey.x)
			(bk["mat"] as ShaderMaterial).set_shader_parameter("hi", pkey.y)
			CardFaces.redraw(bk["vp"])
		_foil_accent(bk["mat"], _look)
		(bk["mat"] as ShaderMaterial).set_shader_parameter("foil", _foil * 0.8)
		for pb in _printed:
			if String((pb as Dictionary).get("series", "")) != String(name):
				continue
			if back != null and ((pb as Dictionary)["canvas"] as CardFaces.Face).art != back:
				((pb as Dictionary)["canvas"] as CardFaces.Face).art = back
				CardFaces.redraw((pb as Dictionary)["vp"])
			# a printed back is read, not shone: its foil kept low
			((pb as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("foil", _foil * 0.25)
	# THE PAINTING of the episode's surface, laid wherever the table takes it ([Tables]: its cloth, its
	# top, a runner...) - or each such surface's own color until it is painted
	var cloth := _picture(dir.path_join("surface.png"), force)
	# ...and its DEPTH, where the painter drew a height map that lies under it (`height.json` beside it
	# is its fit: CardProducer._land_height)
	var depth := _picture(dir.path_join("height.png"), force) if FileAccess.file_exists(dir.path_join("height.json")) else null
	if cloth != _painting_tex or depth != _height_tex:
		var relit := cloth != _painting_tex
		_painting_tex = cloth
		_height_tex = depth
		_apply_painting()
		if relit:
			_lum = _surface_lum()
			_heat_cells = {}
	# a cloth that landed after the candles stood (live, it is painted while a reading can already
	# be playing) lights the table again
	if _painting_tex != _lit_cloth:
		_light_the_table()
		_reflect()
	# THE TABLE, set while a reading can already be playing (live, the set dresser works beside the
	# painter): built again when it lands, and the shuffle's chain with it - a wash goes round
	# whatever stands
	var tpath := dir.path_join("table.json")
	if (FileAccess.get_modified_time(tpath) if FileAccess.file_exists(tpath) else -1) != _table_mt:
		_build_table()
		_plan_moves()
	var room := _picture(dir.path_join("backdrop.png"), force)
	if room != null:
		if _backdrop_mat.get_shader_parameter("picture") != room:
			_backdrop_mat.set_shader_parameter("picture", room)
			_backdrop_mat.set_shader_parameter("has_picture", 1.0)
			# a picture landing live may be one asked for level: placed again for its view
			_place_backdrop()
			_reflect()
	elif _backdrop_mat.get_shader_parameter("picture") == null:
		var pal2: Array = _look.get("palette", CardTable.FALLBACK_PALETTE)
		_backdrop_mat.set_shader_parameter("tint", CardTable.color(String(pal2[0])).darkened(0.25))


## The painting and its height map laid on whatever surfaces of the table take them, the map shifted
## onto the painting as its fit found (`height.json`).
func _apply_painting() -> void:
	var shift := Vector2.ZERO
	var fit_path := String(_pay.get("dir", "")).path_join("height.json")
	if _height_tex != null and FileAccess.file_exists(fit_path):
		var fit: Variant = JSON.parse_string(FileAccess.get_file_as_string(fit_path))
		if fit is Dictionary and (fit as Dictionary).get("shift") is Array and ((fit as Dictionary)["shift"] as Array).size() == 2:
			shift = Vector2(float(fit["shift"][0]), float(fit["shift"][1]))
	Tables.apply_painting(_furniture, _painting_tex, _height_tex, shift)


## THE PAINTING SMALL, in linear light - what [method Tables.surface_lum] reads the table's lightness
## from. Made once per picture, from the file rather than read back from the GPU (which a probe's
## dummy renderer cannot do). Null when there is no picture.
func _painting_small(path: String) -> Image:
	var key := path + "|small"
	if _textures.has(key) and int(_mtimes.get(key, -1)) == int(_mtimes.get(path, -2)):
		return _textures[key]
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	img.srgb_to_linear()
	img.resize(96, 64, Image.INTERPOLATE_LANCZOS)
	_textures[key] = img
	_mtimes[key] = _mtimes.get(path, -2)
	return img


## THE TABLE'S LIGHTNESS where candles may stand ([constant LUM_RECT], row by row, linear): whatever
## lies uppermost there - a layer, the top - for [method _heat].
func _surface_lum() -> PackedFloat32Array:
	if _furniture.is_empty():
		return PackedFloat32Array()
	var path := String(_pay.get("dir", "")).path_join("surface.png")
	return Tables.surface_lum(_furniture["spec"], _painting_small(path) if _painting_tex != null else null, LUM_RECT, LUM_GRID,
		_cloth_fallback())


## The cloth an episode gets while its own is not painted: a dark shade of its palette.
func _cloth_fallback() -> Color:
	var pal: Array = _look.get("palette", CardTable.FALLBACK_PALETTE)
	return CardTable.color(String(pal[min(4, pal.size() - 1)])).darkened(0.35)


## The picture at [param path] as a texture, reloaded when the file changes; null when absent.
## Each picture's foil key is measured as it loads: the 90th and 98th percentile of its own
## luminance, so a dark painting's stars glow and a pale one's highlights do, never a fixed line.
func _picture(path: String, force := false) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var mt := FileAccess.get_modified_time(path)
	if not force and int(_mtimes.get(path, -1)) == mt and _textures.has(path):
		return _textures[path]
	_mtimes[path] = mt
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var small := img.duplicate() as Image
	small.resize(48, 72, Image.INTERPOLATE_BILINEAR)
	var lums := PackedFloat32Array()
	for y in small.get_height():
		for x in small.get_width():
			lums.append(small.get_pixel(x, y).get_luminance())
	lums.sort()
	# IN LINEAR LIGHT: the shader samples the face as `source_color`, so it compares LINEAR values -
	# thresholds measured on these sRGB pixels sat above the very regions they were taken from, and
	# the foil keyed nothing at all
	var lo := Color(lums[int(lums.size() * 0.9)], 0, 0).srgb_to_linear().r
	var hi := Color(lums[int(lums.size() * 0.985)], 0, 0).srgb_to_linear().r
	_textures[path + "|key"] = Vector2(lo, maxf(hi, lo + 0.03))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


## THE ROOM. A picture asked for as a LEVEL photograph from a seated eye (`backdrop.json` beside it
## names its lens, [constant CardTable.BACKDROP_LENS]) is PROJECTED FROM THE CAMERA'S EYE: an
## upright plane far behind the table, its middle at the eye's height straight ahead, as wide as its
## lens saw - so every point of the picture lies in the direction it was seen from, and the camera,
## tilted down at the table, sees the room as it would really look past the table's edge (its
## uprights running together below, the floor where a floor would be). Laid square to the tilted
## camera with its horizon on the table's edge, a room was seen from the height of the cloth: a wall
## or a window just past the table looked wrong, a far landscape got away with it (the user,
## 2026-10-05: "the backgrounds are 2D... the angles feel wrong"). A picture made before (no view
## beside it) holds nothing below its horizon for the camera to see, so it keeps that placement.
func _place_backdrop() -> void:
	var view := _backdrop_view()
	if not view.is_empty():
		var lens := clampf(float(view.get("lens_mm", CardTable.BACKDROP_LENS)), 8.0, 200.0)
		var ahead := Vector3(-_cam_base.basis.z.x, 0.0, -_cam_base.basis.z.z).normalized()
		_backdrop.transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), _cam_base.origin + ahead * ROOM_REACH)
		# a 36 x 24 frame behind a lens of this length, seen at this reach
		(_backdrop.mesh as QuadMesh).size = Vector2(36.0, 24.0) * ROOM_REACH / lens
	else:
		var dist := ROOM_REACH
		var fwd := -_cam_base.basis.z
		var center := _cam_base.origin + fwd * dist
		var h := 2.0 * dist * tan(deg_to_rad(_cam.fov * 0.5))
		var w := h * 16.0 / 9.0
		var far_edge := Vector3(0.0, 0.0, TABLE_Z - TABLE.z * 0.5)
		var up := _cam_base.basis.y
		# where the far edge's line of sight crosses the backdrop's plane, along the camera's up axis
		var to_edge := (far_edge - _cam_base.origin).normalized()
		var along := to_edge.dot(fwd)
		var hit := _cam_base.origin + to_edge * (dist / maxf(along, 0.05))
		var edge_up := (hit - center).dot(up)
		var size := Vector2(w * 1.45, w * 1.45 / 1.5)
		# the picture's horizon (a third up from its bottom) on that line
		var offset := edge_up - (-size.y * 0.5 + size.y * (1.0 / 3.0))
		_backdrop.transform = Transform3D(_cam_base.basis, center + up * offset)
		(_backdrop.mesh as QuadMesh).size = size
	_backdrop_mat.set_shader_parameter("radius", room_blur(_cam_base, _cam.fov, _backdrop.transform,
		(_backdrop.mesh as QuadMesh).size))


## HOW SOFT THE ROOM IS, as the disc's radius in its picture's UV (per axis): [constant ROOM_BLUR]
## of the frame's width, measured where the camera sees the picture - just past the table's far
## edge, under the top of the frame - since the room may be placed any way and seen at a slant.
static func room_blur(cam: Transform3D, fov: float, room: Transform3D, size: Vector2) -> Vector2:
	# the line of sight just under the top of the frame, to the picture's plane
	var sight := (cam.basis * Vector3(0.0, tan(deg_to_rad(fov * 0.5)) * 0.8, -1.0)).normalized()
	var normal := room.basis.z.normalized()
	var facing := sight.dot(normal)
	if absf(facing) < 1e-4:
		return Vector2.ZERO
	var hit := cam.origin + sight * ((room.origin - cam.origin).dot(normal) / facing)
	# how much of the frame's width a meter of the picture there takes
	var across := room.basis.x.normalized() * 0.5
	var a: Variant = CardTable.project(cam, fov, hit - across)
	var b: Variant = CardTable.project(cam, fov, hit + across)
	if a == null or b == null:
		return Vector2.ZERO
	var meters := ROOM_BLUR / maxf(absf((b as Vector2).x - (a as Vector2).x), 1e-4)
	return Vector2(meters / maxf(size.x, 1e-4), meters / maxf(size.y, 1e-4))


## The view the room's picture was asked for (`backdrop.json` beside it): `{view, lens_mm}`, or empty
## for a picture made before there was one.
func _backdrop_view() -> Dictionary:
	var path := String(_pay.get("dir", "")).path_join("backdrop.json")
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data if String((j.data as Dictionary).get("view", "")) == "level" else {}


# --- the spread ------------------------------------------------------------------------------------

## WHERE EACH CARD GOES DOWN is data now ([TablePositions], step 9): a position given by the plan or
## a dealer, or the seeded preset - a row, an arc, two rows, a pyramid - laid within reach of the
## camera, in its frame and clear of the deck.


## Card [param i]'s pose lying in the spread, the way it came out of the deck - face up, unless the
## position it was given lies it face down - turned [param quarter] quarter turns sideways since (tapped,
## [constant TablePositions.SIDEWAYS] each) and turned over when [param over].
func _slot_xf(i: int, quarter := 0, over := false) -> Transform3D:
	var cards: Array = _pay.get("cards", [])
	if _filed() and i < cards.size() and cards[i] is Dictionary:
		var p: Dictionary = (cards[i] as Dictionary).get("position", {}) if (cards[i] as Dictionary).get("position") is Dictionary else {}
		if String(p.get("destination", "")) == "box" and i < (_box["at_k"] as Array).size():
			var placed: Transform3D = (_box["at_k"] as Array)[i]
			if _box.has("return_at"):
				placed.origin = (_box["return_at"] as Vector3) + Vector3(0.0, float(i) * CARD_T * 1.1, 0.0)
				placed.basis = Basis(Vector3.UP, PI if i % 2 == 0 else 0.0)
			elif String(_staging.get("contents", "file")) != "file":
				var inner: AABB = _box["inner"]
				placed.origin.y = minf(inner.end.y - CARD_T, placed.origin.y + CARD_T * 2.0)
			return placed
	var s: Dictionary = _slots[i] if i < _slots.size() else {"pos": Vector3.ZERO, "yaw": 0.0}
	var hand: Vector3 = _lay_jit[i] if i < _lay_jit.size() else Vector3.ZERO
	var yaw := float(s["yaw"]) + hand.z + (PI if _reversed(i) else 0.0) + TablePositions.SIDEWAYS * float(quarter)
	var down := String(s.get("face", "up")) == "down"
	var face := _face_up() if down == over else Basis.IDENTITY
	return Transform3D(Basis(Vector3.UP, yaw) * face,
		s["pos"] as Vector3 + Vector3(hand.x, CARD_T * 0.5, hand.y))


func _reversed(i: int) -> bool:
	var cards: Array = _pay.get("cards", [])
	return i < cards.size() and bool((cards[i] as Dictionary).get("reversed", false))


## A card turned face up about its long side.
static func _face_up() -> Basis:
	return Basis(Vector3(0, 0, 1), PI)


# --- the things on the table --------------------------------------------------------------------------

## THE TABLE'S THINGS: what the set dresser described for this episode (`table.json` in its folder,
## made safe by [method CardTable.sanitize_table]), or the look's candles alone until it has -
## each built ([Props]), stood where [method _place_things] finds it room, its wicks lit - on THE
## TABLE ITSELF, built first ([Tables]): its top and the layers laid on it, the painting on whatever
## takes it. [param spec]: the table made safe, when it was just read.
func _build_table(spec: Dictionary = {}) -> void:
	for c in _props.get_children():
		c.queue_free()
	if spec.is_empty():
		spec = _table_spec()
	if not _furniture.is_empty():
		(_furniture["node"] as Node).queue_free()
	_furniture = Tables.build({"top": spec["top"], "layers": spec["layers"]}, _seed)
	_furniture["spec"] = {"top": spec["top"], "layers": spec["layers"]}
	_top = spec["top"]
	_top_o = Tables.top_outline(_top)
	_layer_os = []
	for l in (spec["layers"] if spec["layers"] is Array else []):
		if l is Dictionary and String((l as Dictionary).get("outline", "rect")) != "top":
			_layer_os.append(Tables.layer_outline(l, _top))
	_root3.add_child(_furniture["node"])
	_apply_painting()
	# its lightness before anything stands on it: a candle looks for dark cloth
	_lum = _surface_lum()
	_lights = []
	_flame_n = 0
	_standing = []
	_standing_c = PackedVector2Array()
	_standing_r = PackedFloat32Array()
	_things = []
	_heat_cells = {}
	# the name over this table is printed in the color the set dresser chose to stand out from it
	_title.ink = CardTable.title_ink(spec)
	_title.queue_redraw()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "tarot-things"])
	var things: Array = (spec["things"] as Array).duplicate()
	var built: Array = []
	for i in things.size():
		if Props.draped(things[i]):
			# LAID ACROSS THE TABLE ITSELF: built in its space, over the edge of this top
			things[i] = _grounded(things[i])
			built.append(Props.build(things[i], spec["materials"], hash([_seed, i, "thing"]), true))
		else:
			built.append(Props.build(things[i], spec["materials"], hash([_seed, i, "thing"])))
	# THE BOX THE CARDS ARE KEPT IN stands first, where the deck would be: the rest go round it
	_stand_box(things, built)
	_place_things(things, built, rng)
	_build_light(spec)
	_light_the_table()
	_reflect()
	_build_air(spec)


## THE BOX THE CARDS ARE KEPT IN, for a show whose cards come from one ([member _cards_from] `box`): the set
## dresser's thing that `holds_cards` - taken out of [param things] and [param built] - or, when it made
## none, a plain box of the deck's own stock. An open box stands by the deck; a shoebox settles across
## the center. Both are scaled to their allotted space, with their contents built inside ([method
## _build_file]). A box on a table whose cards come from a deck is a thing like any other.
func _stand_box(things: Array, built: Array) -> void:
	for f in _file:
		(f as Node).queue_free()
	_file = []
	for o in _box_objects:
		(o as Node).queue_free()
	_box_objects = []
	_box = {}
	if _cards_from != "box":
		return
	var t := {}
	var b := {}
	for i in things.size():
		if bool((things[i] as Dictionary).get("holds_cards", false)):
			t = things[i]
			b = built[i]
			things.remove_at(i)
			built.remove_at(i)
			break
	var shoebox := String(_staging.get("box_style", "open")) == "shoebox"
	if t.is_empty():
		var stock := CardTable.color(String((_look.get("frame", {}) as Dictionary).get("stock", "#c9b38a")))
		t = {"name": "the box the cards are kept in", "place": "by the deck", "holds_cards": true, "parts": [
			{"shape": "extrude", "outline": "rect", "size": [22.0, 33.0] if shoebox else [9.6, 17.0],
				"height": 11.0 if shoebox else 9.0, "wall": 0.5, "material": "card box"}]}
		var mats := {"card box": Props.sanitize_material({"kind": "paper", "color": "#" + stock.darkened(0.25).to_html(false)}, "#a08060")}
		b = Props.build(Props.sanitize({"things": [t], "materials": mats}, [])["things"][0], mats, hash([_seed, "card box"]))
	var size: AABB = b["size"]
	if size.size.x <= 0.0 or size.size.z <= 0.0:
		return
	var across := size.size.z > size.size.x
	var turn := (PI * 0.5 if across else 0.0) if shoebox else (0.0 if across or is_equal_approx(size.size.x, size.size.z) else PI * 0.5)
	var w := size.size.z if turn != 0.0 else size.size.x
	var d := size.size.x if turn != 0.0 else size.size.z
	var most := CardTable.SHOEBOX_MAX if shoebox else CardTable.BOX_MAX
	var k := minf(1.0, minf(most.x / w, minf(most.z / d, most.y / maxf(size.size.y, 0.001))))
	var basis := Basis(Vector3.UP, turn).scaled(Vector3(k, k, k))
	var want := _box_center() if shoebox else TablePositions.box_at(_deck_base)
	var mid := basis * size.get_center()
	var at := Vector2(want.x - mid.x, want.z - mid.z)
	var shape := _translated(_turned(b["outline"], basis), at)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in shape:
		lo = lo.min(q)
		hi = hi.max(q)
	var corners := PackedVector3Array()
	for cx in [size.position.x, size.end.x]:
		for cy in [size.position.y, size.end.y]:
			for cz in [size.position.z, size.end.z]:
				corners.append(basis * Vector3(cx, cy, cz))
	var lens := Vector2(tan(deg_to_rad(_cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(_cam.fov * 0.5)))
	var rect := _screen_rect_fast(corners, Vector3(at.x, 0.0, at.y), _cam_base.affine_inverse(), lens)
	_put(t, b, {"at": at, "outline": shape, "bb": Rect2(lo, hi - lo), "rect": rect}, basis, "#the box")
	var world := Transform3D(basis, Vector3(at.x, 0.0, at.y)) * size
	var inner := AABB(world.position + Vector3(BOX_WALL, BOX_WALL, BOX_WALL),
		world.size - Vector3(BOX_WALL * 2.0, BOX_WALL, BOX_WALL * 2.0))
	_box = {"node": b["node"], "inner": inner, "world": world, "local_bounds": size,
		"rest": (b["node"] as Node3D).transform}
	if shoebox:
		for m in b["meshes"]:
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lid := Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CardTable.color(String((_look.get("frame", {}) as Dictionary).get("stock", "#c9b38a"))).darkened(0.3)
		mat.roughness = 0.9
		var lx := size.size.x + 0.016
		var lz := size.size.z + 0.016
		_lid_piece(lid, mat, Vector3(lx, 0.003, lz), Vector3.ZERO)
		for sx in [-1.0, 1.0]:
			_lid_piece(lid, mat, Vector3(0.003, 0.028, lz), Vector3(sx * (lx - 0.003) * 0.5, -0.0155, 0.0))
		for sz in [-1.0, 1.0]:
			_lid_piece(lid, mat, Vector3(lx - 0.006, 0.028, 0.003), Vector3(0.0, -0.0155, sz * (lz - 0.003) * 0.5))
		(b["node"] as Node3D).add_child(lid)
		_box["lid"] = lid
		_box["lid_rest"] = Vector3(size.get_center().x, size.end.y + 0.009, size.get_center().z)
		_box["shadow"] = _contact(shape)
		_box["lid_shadow"] = _contact(shape)
	_build_file()
	_build_box_objects()
	if shoebox:
		# A card passing close to these walls throws a large, stair-stepped shadow
		# across them in the positional atlas. The box keeps its soft tabletop shade.
		for card in _cards:
			(card as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _lid_piece(parent: Node3D, mat: Material, dimensions: Vector3, at: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	part.layers = THING_LAYER
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


## THE CARDS IN THE BOX: an open box keeps the planned collection; a shoebox fills out its
## printings with physical copies so it reads as a collection accumulated over time. The drawn
## cards have their own places near the accessible top. Undrawn cards share one MultiMesh per printing.
func _build_file() -> void:
	var inner: AABB = _box["inner"]
	var content := String(_staging.get("contents", "file"))
	var size := CardTable.card_size(_look)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "card file"])
	var under_lid := _box.has("lid")
	var upright := content == "file" and inner.size.x >= size.x * 1.03 and inner.size.y >= size.y * (1.03 if under_lid else 0.6)
	var lie := content == "file" and not upright and inner.size.x >= size.y * 1.03 and inner.size.y >= size.x * (1.03 if under_lid else 0.6)
	_box["upright"] = upright
	_box["lie"] = lie
	_box["at_k"] = []
	if content == "file" and not upright and not lie:
		# a shallow tin: the deck lies flat on its floor
		_box["flat"] = true
		return
	var v := size.y if upright else size.x
	var stand := Basis(Vector3.UP, PI) * Basis(Vector3(1, 0, 0), PI * 0.5)
	if lie:
		stand = stand * Basis(Vector3.UP, PI * 0.5)
	var undrawn := _file_inventory()
	var count := _cards.size() + undrawn.size()
	var shoebox := _box.has("lid")
	_box["count"] = count
	if shoebox and content == "loose":
		_box["return_at"] = Vector3(inner.end.x - size.x * 0.5 - 0.008,
			inner.end.y + 0.004, inner.get_center().z)
	var fill := minf(1.0, float(count) * FILE_PITCH / maxf(inner.size.z, FILE_PITCH))
	var tail := mini(6, count / 4)
	var xfs: Array = []
	for i in count:
		if shoebox:
			if content == "file":
				var rows := maxi(1, int(floor(inner.size.x / (size.x + 0.006))))
				var row := i % rows
				var layer := i / rows
				var pitch := minf(CARD_T * 1.02, (inner.size.z - size.x * 0.1) / float(maxi(int(ceil(float(count) / rows)), 1)))
				var x := inner.position.x + inner.size.x * (float(row) + 0.5) / float(rows)
				var z := inner.end.z - pitch * (float(layer) + 0.5) - 0.004
				xfs.append(Transform3D(stand, Vector3(x, inner.position.y + v * 0.5, z)))
				continue
			if content == "loose" and i >= count - 8:
				var radius := size.length() * 0.5 + 0.002
				var x_min := inner.position.x + radius
				var x_max := minf(inner.end.x - radius,
					(_box["return_at"] as Vector3).x - radius * 2.0 - 0.008)
				var dz := maxf(inner.size.z * 0.5 - radius, 0.0)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)),
					Vector3(rng.randf_range(x_min, maxf(x_min, x_max)),
						inner.end.y - 0.003 + float(i - (count - 8)) * 0.0008,
						inner.get_center().z + rng.randf_range(-dz, dz))))
				continue
			var cols := maxi(1, int(floor(inner.size.x / (size.x + 0.006))))
			var rows := maxi(1, int(floor(inner.size.z / (size.y + 0.006))))
			var cells := cols * rows
			var cell := i % cells
			var layer := i / cells
			var layers := maxi(1, int(ceil(float(count) / float(cells))))
			var pitch := minf(CARD_T * 1.02, (inner.size.y - 0.004) / float(layers))
			var x := inner.position.x + inner.size.x * (float(cell % cols) + 0.5) / float(cols)
			var z := inner.position.z + inner.size.z * (float(cell / cols) + 0.5) / float(rows)
			var loose := content == "loose"
			var angle := rng.randf_range(-0.08, 0.08) if loose else 0.0
			if loose and layer >= layers - 3:
				angle = rng.randf_range(-0.13, 0.13)
			if hash([_seed, cell, "pile direction"]) & 1:
				angle += PI
			xfs.append(Transform3D(Basis(Vector3.UP, angle), Vector3(x, inner.position.y + 0.001 + (float(layer) + 0.5) * pitch, z)))
			continue
		if content == "loose":
			var radius := size.length() * 0.5
			var dx := maxf(inner.size.x * 0.5 - radius - 0.003, 0.0)
			var dz := maxf(inner.size.z * 0.5 - radius - 0.003, 0.0)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)),
				Vector3(inner.get_center().x + rng.randf_range(-dx, dx),
					inner.position.y + 0.001 + 0.004 * float(i) / float(maxi(count, 1)),
					inner.get_center().z + rng.randf_range(-dz, dz))))
			continue
		if content == "piles":
			var groups := 2 if inner.size.z >= size.y * 2.05 else 1
			var group := i % groups
			var layer := i / groups
			var z_flat := inner.position.z + inner.size.z * (0.5 if groups == 1 else (0.25 if group == 0 else 0.75))
			var x_flat := inner.get_center().x
			var y_flat := inner.position.y + 0.001 + float(layer) * (CARD_T + 0.00025)
			xfs.append(Transform3D(Basis.IDENTITY, Vector3(x_flat, y_flat, z_flat)))
			continue
		# from the front wall back; the last few lean back into the gap
		var z := inner.end.z - FILE_PITCH * (float(i) + 0.5)
		var lean := 0.0
		if fill < 0.96 and i >= count - tail:
			lean = FILE_LEAN * float(i - (count - tail) + 1) / float(tail)
		var bottom := Vector3(inner.get_center().x + rng.randf_range(-0.002, 0.002), inner.position.y, z)
		var b := Basis(Vector3(1, 0, 0), -lean) * Basis(Vector3.UP, deg_to_rad(rng.randf_range(-1.2, 1.2))) * stand
		xfs.append(Transform3D(b, bottom + Basis(Vector3(1, 0, 0), -lean) * Vector3(0.0, v * 0.5, 0.0)))
	# THE DRAWN CARDS' PLACES in the file, away from the leaning tail
	var free: Array = range(0, count - tail)
	if shoebox:
		free = range(maxi(0, count - maxi(_cards.size() * 4, 24)), count)
		if content == "loose":
			free = range(maxi(0, count - maxi(_cards.size(), 8)), count)
	for k in _cards.size():
		var j := int(free.pop_back()) if shoebox and content == "loose" else int(free.pop_at(rng.randi_range(0, free.size() - 1)))
		(_box["at_k"] as Array).append(xfs[j])
		xfs[j] = null
	# one MultiMesh per printing, its cards shared out among them
	var per := {}
	for n in _backs:
		per[n] = []
	for xf in xfs:
		if xf != null and not undrawn.is_empty():
			var name: String = undrawn.pop_at(rng.randi_range(0, undrawn.size() - 1))
			(per[name] as Array).append(xf)
	for n in per:
		var list: Array = per[n]
		if list.is_empty():
			continue
		var mesh := _mesh_for((_backs[n] as Dictionary)["canvas"].look).duplicate() as ArrayMesh
		# a filed card faces either way: the front one shows its printing's back, whichever way it stands
		mesh.surface_set_material(0, (_backs[n] as Dictionary)["mat"])
		mesh.surface_set_material(1, (_backs[n] as Dictionary)["mat"])
		mesh.surface_set_material(2, _edge_mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		if shoebox:
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root3.add_child(inst)
		_file.append(inst)


## A few ordinary small keepsakes rest in the open space at the back of the container.
## They are not cards, so they never enter the draw or the file's inventory.
func _build_box_objects() -> void:
	var inner: AABB = _box["inner"]
	_box["objects_rest"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "box keepsakes"])
	for item in _staging.get("keepsakes", []) if _staging.get("keepsakes") is Array else []:
		var kind := String(item)
		var mesh: PrimitiveMesh
		var color := Color(0.72, 0.65, 0.49)
		match kind:
			"coin", "button":
				var round_mesh := CylinderMesh.new()
				round_mesh.top_radius = 0.008 if kind == "coin" else 0.006
				round_mesh.bottom_radius = round_mesh.top_radius
				round_mesh.height = 0.0015 if kind == "coin" else 0.0025
				mesh = round_mesh
				color = Color(0.68, 0.54, 0.29) if kind == "coin" else Color(0.47, 0.35, 0.3)
			"marble":
				var round_mesh := SphereMesh.new()
				round_mesh.radius = 0.006
				round_mesh.height = 0.012
				mesh = round_mesh
				color = Color(0.21, 0.47, 0.56)
			"ticket":
				var paper := BoxMesh.new()
				paper.size = Vector3(0.024, 0.0007, 0.014)
				mesh = paper
				color = Color(0.78, 0.72, 0.58)
			_:
				continue
		var obj := MeshInstance3D.new()
		obj.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.55 if kind == "marble" else 0.85
		obj.material_override = mat
		var x := inner.get_center().x + rng.randf_range(-0.28, 0.28) * inner.size.x
		var z := inner.position.z + inner.size.z * rng.randf_range(0.07, 0.13)
		obj.position = Vector3(x, inner.position.y + (0.006 if kind == "marble" else 0.002), z)
		obj.rotation.y = rng.randf_range(-0.25, 0.25)
		_root3.add_child(obj)
		_box_objects.append(obj)
		(_box["objects_rest"] as Array).append(obj.transform)


## The planned cards still in the box, by printing. A shoebox repeats those printings to fill
## the physical container without asking the producer to enumerate every unseen card.
func _file_inventory() -> Array:
	var plan: Dictionary = _pay.get("plan", {}) if _pay.get("plan") is Dictionary else {}
	var names: Array = []
	var deck: Array = plan.get("deck", []) if plan.get("deck") is Array else []
	if not deck.is_empty():
		for card in deck:
			if card is Dictionary:
				names.append(CardTable.series_of(_look, card as Dictionary))
	else:
		var inventory: Dictionary = plan.get("inventory", {}) if plan.get("inventory") is Dictionary else {}
		var counts: Dictionary = inventory.get("printings", {}) if inventory.get("printings") is Dictionary else {}
		for name in counts:
			for i in maxi(0, int(counts[name])):
				names.append(String(name))
	if names.is_empty():
		for card in _pay.get("cards", []) if _pay.get("cards") is Array else []:
			if card is Dictionary:
				names.append(CardTable.series_of(_look, card as Dictionary))
	if _box.has("lid") and not names.is_empty():
		var printings := names.duplicate()
		while names.size() < CardTable.SHOEBOX_FILL:
			names.append(printings[names.size() % printings.size()])
	for card in _pay.get("cards", []) if _pay.get("cards") is Array else []:
		if not (card is Dictionary) or names.is_empty():
			continue
		var name := CardTable.series_of(_look, card as Dictionary)
		var at := names.find(name)
		names.remove_at(at if at >= 0 else 0)
	return names


## The cards come out of a box they are filed in (on edge, not lying flat in a tin).
func _filed() -> bool:
	return not _box.is_empty() and not bool(_box.get("flat", false)) and (_box.get("at_k", []) as Array).size() > 0


## Catch the table again for the things to reflect: a probe that updates once does so again when
## it moves, so it is moved by a hair.
func _reflect() -> void:
	if _probe == null:
		return
	_probe_nudge = -_probe_nudge
	_probe.position = Vector3(0.0, 0.2 + 0.0001 * _probe_nudge, -0.05)


## The set dresser's table, made safe - or, before there is one, the look's candles. Read from the
## FILE, as the pictures are, so a render (a second process) stands what the live table stood.
func _table_spec() -> Dictionary:
	var path := String(_pay.get("dir", "")).path_join("table.json")
	_table_mt = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	if _table_mt >= 0:
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			return CardTable.sanitize_table(j.data as Dictionary, _look)
	return CardTable.default_table(_look, _seed)


## WHERE EACH THING STANDS. A thing goes in the zone the set dresser named, and things that share
## a group stand together: the group's tallest first, as near its zone's middle as there is room,
## the rest round it - the shorter ones toward the reader - so a group reads as arranged, not
## lined up. The biggest groups choose first. A thing with no room is tried smaller, then left
## off the table.
func _place_things(things: Array, built: Array, rng: RandomNumberGenerator) -> void:
	var keep_out := _keep_out()
	_habit = _habit_of(_seed)
	# THE DRAPED FIRST: where they lie is written, and the rest stand clear of them
	for i in things.size():
		if Props.draped(things[i]):
			_drape(things[i], built[i], keep_out)
	var groups := {}
	for i in things.size():
		if Props.draped(things[i]):
			continue
		var g := String((things[i] as Dictionary).get("group", ""))
		var key := g if not g.is_empty() else "#%d" % i
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(i)
	var area := func(members: Array) -> float:
		var s := 0.0
		for i in members:
			var box: AABB = (built[i] as Dictionary)["size"]
			s += box.size.x * box.size.z
		return s
	var order: Array = groups.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return float(area.call(groups[a])) > float(area.call(groups[b])))
	for key in order:
		var members: Array = groups[key]
		members.sort_custom(func(a: int, b: int) -> bool:
			return ((built[a] as Dictionary)["size"] as AABB).size.y > ((built[b] as Dictionary)["size"] as AABB).size.y)
		var anchor := {}
		for i in members:
			var stood := _stand(things[i], built[i], String(key), anchor, keep_out, rng)
			if stood.is_empty():
				print("ghost: card table - no room for %s" % String((things[i] as Dictionary).get("name", "a thing")))
				((built[i] as Dictionary)["node"] as Node).free()
			elif anchor.is_empty():
				anchor = stood


## THIS EPISODE'S HABIT ([constant AIM_WANDER]), from its own die so no other draw moves: `push` - how
## far out to the sides its things lean (0 keeps the zones' own middles, as before; often well out, so
## the middle stays free), and `wander`, `side` - each group's own step off its zone's middle and the side
## a "back" group leans to, by the group's name.
static func _habit_of(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-things-habit"])
	return {"push": pow(rng.randf(), 0.7), "salt": rng.randi()}


## Where group [param group] of zone [param zone] aims, the deck kept at [param deck]: the zone's middle,
## pushed out to its side by the habit and wandered off by the group's own step.
func _habit_aim(zone: String, group: String, deck: Vector3) -> Vector2:
	var aim := CardTable.zone_aim(zone, deck)
	if _habit.is_empty():
		return aim
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(_habit["salt"]), group])
	var step := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * AIM_WANDER
	var side := signf(aim.x) if absf(aim.x) > 0.01 else (-1.0 if rng.randf() < 0.5 else 1.0)
	# a "back" thing leans out less (it stands where the frame is narrowest), by the deck not at all
	var push := float(_habit["push"]) * EDGE_PUSH * (0.0 if zone == "by the deck" else (0.8 if absf(aim.x) < 0.01 else 1.0))
	return aim + step + Vector2(side * push, 0.0)


## How much worse a spot is for a foot [param bb] (x by z) that crosses a layer's edge ([constant STRADDLE]).
func _straddle(bb: Rect2) -> float:
	var pts := [bb.position, bb.end, Vector2(bb.position.x, bb.end.y), Vector2(bb.end.x, bb.position.y), bb.get_center()]
	for o in _layer_os:
		var inside := 0
		for q in pts:
			inside += 1 if Tables.sdf(o, q) < 0.0 else 0
		if inside > 0 and inside < pts.size():
			return STRADDLE * (1.0 / 3.0 if maxf(bb.size.x, bb.size.y) > STRADDLE_BIG else 1.0)
	return 0.0


## THING [param t] (its strand laid `drape`) with the ground it falls over: this top's edge ([method
## Tables.sdf]), the middle of the reading its path is written from, and the floor.
func _grounded(t: Dictionary) -> Dictionary:
	var out := t.duplicate(true)
	var o := _top_o
	var ground := {"sdf": func(p: Vector2) -> float: return Tables.sdf(o, p),
		"normal": func(p: Vector2) -> Vector2: return Tables.normal(o, p),
		"origin": Tables.ORIGIN, "drop": Tables.DROP_MOST}
	for p in out["parts"]:
		(p as Dictionary)["ground"] = ground
	return out


## A STRAND DRAPED ACROSS THE TABLE ([param t], built as [param b] in the table's own space): laid where it was
## written - unless it runs where the cards go ([param keep_out]), when it is left off - and the stretches of
## the table it covers kept out for the things that stand after it.
func _drape(t: Dictionary, b: Dictionary, keep_out: Array) -> void:
	var node: Node3D = b["node"]
	var line := PackedVector2Array()
	for m in b["meshes"]:
		var arr := ((m as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, vs.size(), 7):
			if vs[i].y > -0.01:
				line.append(Vector2(vs[i].x, vs[i].z))
	var pieces: Array = []
	var cell := 0.06
	var cells := {}
	for q in line:
		var c := Vector2i(floori(q.x / cell), floori(q.y / cell))
		if not cells.has(c):
			cells[c] = Rect2(q, Vector2.ZERO)
		cells[c] = (cells[c] as Rect2).expand(q)
	for c in cells:
		pieces.append((cells[c] as Rect2).grow(0.004))
	for r in pieces:
		for k in keep_out:
			if (r as Rect2).intersects(k as Rect2):
				print("ghost: card table - %s runs where the cards go; left off" % String(t.get("name", "a strand")))
				node.free()
				return
	var bb := Rect2()
	for r in pieces:
		bb = (r as Rect2) if bb.size == Vector2.ZERO else bb.merge(r as Rect2)
	var flat := b.duplicate()
	flat["foot"] = PackedVector2Array()
	_put(t, flat, {"at": Vector2.ZERO, "rect": Rect2(), "bb": bb, "outline": PackedVector2Array()}, Basis(), "")
	keep_out.append_array(pieces)


## Where nothing may stand: everywhere the cards go - the spread, the deck, the middle where the
## deck is shuffled, where a jumper lands - as rectangles on the table (x by z).
func _keep_out() -> Array:
	var out: Array = []
	for sl in _slots:
		out.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), CARD).grow(0.03))
	out.append(Rect2(_deck_base.x - 0.08, _deck_base.z - 0.1, 0.16, 0.2))
	if _aside_card >= 0:
		out.append(Rect2(_deck_far.x - 0.08, _deck_far.z - 0.1, 0.16, 0.2))
	# the middle, where the deck is shuffled - and, whatever the source, where the spread lies
	out.append(Rect2(_mid.x - 0.22, _mid.z - 0.14, 0.44, 0.28))
	if _cards_from == "box":
		# nothing stands where the box would, nor where a pulled card rises past it
		out.append(TablePositions.deck_keep(_deck_base, _box_keep(), _box_center()))
		if _box.has("lid"):
			var world: AABB = _box["world"]
			var side := signf(_deck_base.x)
			var x := world.get_center().x + side * (world.size.x + 0.025)
			out.append(Rect2(x - world.size.x * 0.5 - 0.025, world.position.z + 0.08 - 0.025,
				world.size.x + 0.05, world.size.z + 0.05))
		return out
	out.append(Rect2(_jump_land.x - 0.07, _jump_land.z - 0.09, 0.14, 0.18))
	return out


## ONE THING STOOD: the best free spot for [param t] (built as [param b]) on a grid over the table,
## at full size or, failing that, a little smaller. Every spot is ON THE TABLE, off everywhere the
## cards go, clear of what already stands (by [constant THING_GAP], or [constant GROUP_GAP] within
## its own group), IN THE SHOT (its whole box, projected: never cut by the frame's top, and a lit thing
## not at all - any other may run off a side, [constant SEEN_LEAST]), and - between groups - not in
## front of another in the picture. Aimed where the episode's habit puts its zone ([method _habit_aim]),
## and kept off a cloth's edge where it can be ([method _straddle]). A lit thing stands only behind the middle (in front of the
## cards its flame blew out the card held up to the lens) and looks for dark cloth. The spot
## chosen ({at, k, group, height}), or empty when there is none.
func _stand(t: Dictionary, b: Dictionary, group: String, anchor: Dictionary, keep_out: Array,
		rng: RandomNumberGenerator) -> Dictionary:
	var box: AABB = b["size"]
	var lit := not (b["wicks"] as Array).is_empty()
	var yaw := deg_to_rad(float(t.get("turn", 0.0)) + rng.randf_range(-8.0, 8.0))
	var zone := String(t.get("place", "back"))
	var aim := _habit_aim(zone, group, _deck_base)
	var front := (_deck_base.z + 0.03) if zone in ["by the deck", "left", "right"] else _mid.z + 0.03
	# a LOW thing may lie nearer the reader, where it hides no card and nothing behind it
	if box.size.y < 0.04:
		front = 0.2
	if lit:
		front = minf(front, _mid.z)
	var outline: PackedVector2Array = b["outline"]
	for k in [1.0, 0.88, 0.76]:
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(k, k, k))
		var shape := PackedVector2Array()
		for q in outline:
			var w := basis * Vector3(q.x, 0.0, q.y)
			shape.append(Vector2(w.x, w.z))
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in shape:
			lo = lo.min(q)
			hi = hi.max(q)
		var corners := PackedVector3Array()
		for cx in [box.position.x, box.end.x]:
			for cy in [box.position.y, box.end.y]:
				for cz in [box.position.z, box.end.z]:
					corners.append(basis * Vector3(cx, cy, cz))
		var best := {}
		var best_score := -INF
		var cam_inv := _cam_base.affine_inverse()
		var lens := Vector2(tan(deg_to_rad(_cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(_cam.fov * 0.5)))
		# from the back of the top - a deep one reaches further back than the old table did
		var top_back := Tables.ORIGIN.y + Tables.TOP_AT.y - float((_top.get("size", [0.0, 85.0]) as Array)[1]) * 0.005 + Tables.THING_EDGE
		var z := minf(-0.4, top_back)
		# the old cloth's back edge, unless the top goes well past it
		var back := -0.02 - CLOTH.y * 0.48
		if top_back < back - 0.02:
			back = top_back
		while z <= front:
			var x := -0.62
			while x <= 0.62:
				_breathe()
				var at := Vector2(x + rng.randf_range(-0.004, 0.004), z + rng.randf_range(-0.004, 0.004))
				x += 0.02
				var bb := Rect2(lo + at, hi - lo)
				# WITHIN THE READER'S REACH - the old cloth's stretch, the width the camera sees, further
				# back only where a deep top goes further back (a thing let out to the old table's whole
				# width stood where a wash's card then clipped its foot) - and ON THE TOP, well in from its
				# edge: a thing by the rim read as about to fall off
				if bb.position.x < -CLOTH.x * 0.49 or bb.end.x > CLOTH.x * 0.49 or bb.position.y < back \
						or bb.end.y > -0.02 + CLOTH.y * 0.48:
					continue
				if Tables.sdf(_top_o, bb.position) > -Tables.THING_EDGE or Tables.sdf(_top_o, bb.end) > -Tables.THING_EDGE \
						or Tables.sdf(_top_o, Vector2(bb.position.x, bb.end.y)) > -Tables.THING_EDGE \
						or Tables.sdf(_top_o, Vector2(bb.end.x, bb.position.y)) > -Tables.THING_EDGE:
					continue
				# the outline itself only where the boxes meet: most spots are judged by box alone
				var placed := PackedVector2Array()
				var clear := true
				for r in keep_out:
					if (r as Rect2).intersects(bb):
						if placed.is_empty():
							placed = _translated(shape, at)
						if _convex_overlap(placed, _rect_poly(r as Rect2), 0.0):
							clear = false
							break
				if not clear:
					continue
				for th in _things:
					var gap := GROUP_GAP if String((th as Dictionary)["group"]) == group else THING_GAP
					if ((th as Dictionary)["bb"] as Rect2).grow(gap).intersects(bb):
						if placed.is_empty():
							placed = _translated(shape, at)
						if _convex_overlap(placed, (th as Dictionary)["outline"], gap):
							clear = false
							break
				if not clear:
					continue
				var rect := _screen_rect_fast(corners, Vector3(at.x, 0.0, at.y), cam_inv, lens)
				# never cut by the frame's TOP: a thing cut there reads as one standing in the room, not on
				# the table. A lit thing is the light, and stands wholly in the shot; any other may run off
				# a side or the foot of the frame, as a crowded table's do, so long as SEEN_LEAST of it shows
				if rect.position.y < 0.02:
					continue
				if lit:
					if rect.position.x < 0.02 or rect.end.x > 0.98 or rect.end.y > 0.97:
						continue
				elif rect.intersection(Rect2(0.0, 0.0, 1.0, 1.0)).get_area() < rect.get_area() * SEEN_LEAST:
					continue
				# not in front of another in the picture: apart between groups, and within one only a
				# little in front - a group seen one thing through another read as a stack
				var hidden := 0.0
				for th in _things:
					var other: Rect2 = (th as Dictionary)["rect"]
					if String((th as Dictionary)["group"]) != group:
						if other.grow(0.008).intersects(rect):
							clear = false
							break
					elif other.intersects(rect):
						hidden = maxf(hidden, other.intersection(rect).get_area() / maxf(minf(other.get_area(), rect.get_area()), 1e-6))
				if not clear or hidden > 0.3:
					continue
				var score := -hidden * 2.0
				if anchor.is_empty():
					score -= at.distance_to(aim) * 4.0
				else:
					var ap: Vector2 = anchor["at"]
					score -= at.distance_to(ap) * 6.0
					# a shorter thing in a group stands toward the reader, a taller one behind
					if box.size.y * k < float(anchor["height"]):
						score += clampf((at.y - ap.y) * 4.0, -0.2, 0.2)
				if lit:
					# by dark cloth, where it can burn as the key: by pale, its light is held down
					score -= 0.8 * maxf(0.0, _heat_cell(Vector3(at.x, 0.0, at.y)) * KEY_ENERGY / HEAT - 1.0)
				score -= _straddle(bb)
				score += rng.randf() * 0.05
				if score > best_score:
					best_score = score
					best = {"at": at, "rect": rect, "bb": bb, "outline": placed if not placed.is_empty() else _translated(shape, at)}
			z += 0.02
		if not best.is_empty():
			_put(t, b, best, basis, group)
			return {"at": best["at"], "height": box.size.y * k, "k": k}
	return {}


## A BREATH for the app, in a table built [member aside]: a worker in a long loop of GDScript calls holds
## the engine's object locks so tightly that the main thread drew at four frames a second (measured
## 2026-10-08); a moment given up now and then gave it back its frames, and the build got no slower. It
## changes nothing built.
func _breathe() -> void:
	if not aside:
		return
	_breaths += 1
	if _breaths % 64 == 0:
		OS.delay_usec(0)


## Thing [param t] stood at the chosen spot: in the scene, its wicks lit, a soft shade where it meets
## the cloth, its foot kept for the cards to go round (see [method _card_clear]).
func _put(t: Dictionary, b: Dictionary, spot: Dictionary, basis: Basis, group: String) -> void:
	var at: Vector2 = spot["at"]
	var node: Node3D = b["node"]
	node.transform = Transform3D(basis, Vector3(at.x, 0.0, at.y))
	_props.add_child(node)
	var wicks: Array = b["wicks"]
	# A CANDLE CASTS IN EVERY FLAME'S LIGHT BUT ITS OWN: its own, just above it, printed a hard dark
	# disc round its base. So it has a render layer of its own, which only its flames leave out. A
	# thing with no flame is on its own layer too, so the cloth's shades fall on the cloth alone.
	var own := (CANDLE_LAYER << _lights.size()) if not wicks.is_empty() else THING_LAYER
	for m in b["meshes"]:
		(m as MeshInstance3D).layers = own
	var glows: Array = b.get("glows", [])
	var first := _lights.size()
	if not wicks.is_empty():
		var flames: Array = []
		for i in wicks.size():
			var wick: Vector3 = node.transform * (wicks[i] as Vector3)
			var f := _flame(wick, own, glows[i] if i < glows.size() else null)
			f["open"] = Props.open_to_air(wick, node, b["meshes"])
			flames.append(f)
		_light_flames(flames, own)
	var foot := _translated(_turned(b["foot"], basis), at)
	if foot.size() >= 3:
		# A moving shoebox gets its own moving soft shade. A fixed decal projects onto
		# its walls as it passes, and a fixed shadow slab leaves a ghost at its destination.
		if not (group == "#the box" and String(_staging.get("box_style", "open")) == "shoebox"):
			_contact(foot)
			_foot_shadow(foot, own)
		var grown := _grown(foot, FOOT_MARGIN)
		_standing.append(grown)
		var c := Vector2.ZERO
		for q in grown:
			c += q
		c /= float(grown.size())
		var r := 0.0
		for q in grown:
			r = maxf(r, q.distance_to(c))
		_standing_c.append(c)
		_standing_r.append(r)
	_things.append({"name": String(t.get("name", "")), "group": group, "place": String(t.get("place", "back")),
		"node": node, "outline": spot["outline"], "bb": spot["bb"], "rect": spot["rect"], "foot": foot,
		"box": node.transform * (b["size"] as AABB), "lit": wicks.size(), "lights": range(first, _lights.size()),
		"meshes": b["meshes"]})


## A FLAME at [param at], the top of a wick: a wick under it (on its candle's layer, [param own])
## and the flame, flickering in its own time. Its light is its thing's ([method _light_flames]); its
## own wax glows with it, through [param glow] (its material's `flame`). The flame, as
## `{mesh, base, flicker, glow}`.
func _flame(at: Vector3, own: int, glow: Variant = null) -> Dictionary:
	var wick := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.0006
	wm.bottom_radius = 0.0008
	wm.height = 0.009
	wm.radial_segments = 6
	wm.rings = 1
	wick.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.07, 0.05, 0.04)
	wmat.roughness = 0.9
	wick.material_override = wmat
	wick.position = at + Vector3(0.0, 0.0035, 0.0)
	wick.layers = own
	_props.add_child(wick)
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.03)
	flame.mesh = q
	var fm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLAME_SHADER
	fm.shader = sh
	flame.material_override = fm
	flame.position = at + Vector3(0, 0.016, 0)
	_props.add_child(flame)
	_flame_n += 1
	return {"mesh": flame, "base": flame.position, "flicker": _flicker_of(_flame_n - 1), "glow": glow, "open": 1.0}


## A LIT THING'S ONE LIGHT, for every flame on it: a candelabra's tapers or a pillar's three wicks
## light the room as one light from among them, as near together as they are - so a candle costs
## one shadow however many flames it has. It lights everything but its own thing (render layer
## [param own]) and throws shadows from all of it: a flame lighting its own holder blew it out (an
## oil lamp's flame sits a few centimeters above its body). Its brightness follows its flames' -
## each still flickers in its own time.
func _light_flames(flames: Array, own: int) -> void:
	var at := Vector3.ZERO
	for f in flames:
		at += (f as Dictionary)["base"]
	at /= float(flames.size())
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.omni_range = 1.4
	light.light_energy = 0.35
	light.shadow_caster_mask = 0xFFFFFFFF & ~own & ~Lights.SCREEN_MASK
	light.light_cull_mask = 0xFFFFFFFF & ~own
	# a flame is a couple of centimeters across: the shadows it throws are soft at their ends. The
	# biases are for a TABLETOP: at their defaults a deck's shadow began centimeters in front of it
	light.light_size = 0.015
	light.shadow_bias = 0.004
	light.shadow_normal_bias = 0.08
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_enabled = true
	light.position = at + Vector3(0, 0.016, 0)
	_props.add_child(light)
	_lights.append({"light": light, "base": at, "light_base": light.position, "energy": 0.28, "flames": flames})


## A SHADOW-ONLY SLAB under [param foot]: the tabletop's shadow biases are larger than the gap
## under a bowl's sloping wall, so a ring of the lamp leaked in beside its base (feedback 0009). The
## slab stands a few millimeters over the cloth, draws nothing and shades what the thing already
## covers. It is on [param layer], so a candle's own flames still leave it out.
func _foot_shadow(foot: PackedVector2Array, layer: int) -> void:
	var tris := Geometry2D.triangulate_polygon(foot)
	if tris.is_empty():
		return
	const H := 0.006
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tris.size() - 2, 3):
		var a := foot[tris[i]]
		var b := foot[tris[i + 1]]
		var c := foot[tris[i + 2]]
		# top and bottom, each both ways round: no winding to get wrong in the shadow pass
		for y in [H, 0.0]:
			for q in [a, b, c, a, c, b]:
				st.add_vertex(Vector3(q.x, y, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.layers = layer
	_props.add_child(mi)


## A soft shade on the cloth under [param foot] (a thing's outline where it meets it): what
## anything standing presses into the cloth.
func _contact(foot: PackedVector2Array) -> Decal:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in foot:
		lo = lo.min(q)
		hi = hi.max(q)
	var size := (hi - lo).max(Vector2(0.01, 0.01))
	var contact := Decal.new()
	contact.texture_albedo = _contact_texture()
	contact.modulate = Color(0, 0, 0, 1)
	contact.albedo_mix = 0.6
	contact.size = Vector3(size.x * 1.7, 0.03, size.y * 1.7)
	contact.position = Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	contact.cull_mask = 1
	_props.add_child(contact)
	return contact


## The rectangle in the picture that [param corners] (a thing's box, turned and sized) cover
## standing at [param at], for a camera whose inverse is [param cam_inv] and whose lens spreads
## [param lens] (tangents across and up); one wider than the frame when any lies behind the lens.
static func _screen_rect_fast(corners: PackedVector3Array, at: Vector3, cam_inv: Transform3D, lens: Vector2) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in corners:
		var l: Vector3 = cam_inv * (c + at)
		if l.z > -0.001:
			return Rect2(-1.0, -1.0, 3.0, 3.0)
		var sp := Vector2(0.5 + l.x / (-l.z * lens.x) * 0.5, 0.5 - l.y / (-l.z * lens.y) * 0.5)
		lo = lo.min(sp)
		hi = hi.max(sp)
	return Rect2(lo, hi - lo)


static func _translated(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + by)
	return out


static func _turned(poly: PackedVector2Array, basis: Basis) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var w := basis * Vector3(q.x, 0.0, q.y)
		out.append(Vector2(w.x, w.z))
	return out


## [param poly] (convex) pushed out by [param by] all round.
static func _grown(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= float(maxi(poly.size(), 1))
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + (q - c).normalized() * by)
	return out


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Whether convex [param a] and [param b] come within [param gap] of each other: no separating
## axis among their edges' normals with that much room on it.
static func _convex_overlap(a: PackedVector2Array, b: PackedVector2Array, gap: float) -> bool:
	if a.size() < 2 or b.size() < 2:
		return false
	for poly in [a, b]:
		var p: PackedVector2Array = poly
		for i in p.size():
			var e := p[(i + 1) % p.size()] - p[i]
			if e.length_squared() < 1e-12:
				continue
			var ax := Vector2(-e.y, e.x).normalized()
			var ra := _span(a, ax)
			var rb := _span(b, ax)
			if ra.x > rb.y + gap or rb.x > ra.y + gap:
				return false
	return true


## [param poly]'s extent along [param ax]: (least, most).
static func _span(poly: PackedVector2Array, ax: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for q in poly:
		var d := q.dot(ax)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


## LIGHT FROM OUTSIDE THE SHOT: two or three more candles in the room - behind the camera and off
## to the sides - never seen, only felt: a warm, shifting fill on the cloth, and on a card held up
## to the lens. Without shadows - faint fills, whose shadows would be fainter still, at six shadow
## passes each - each flickering in its own time.
## Their own dice, so the rest of the table lands where it did.
func _build_glows() -> void:
	_glows = []
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "tarot-glows"])
	var n := r.randi_range(2, 3)
	var tries := 0
	while _glows.size() < n and tries < 60:
		tries += 1
		var at := Vector3(r.randf_range(-0.7, 0.7), r.randf_range(0.12, 0.5), _cam_base.origin.z + r.randf_range(0.2, 0.7))
		if not _glows.is_empty() and r.randf() < 0.5:
			at = Vector3(r.randf_range(0.85, 1.4) * (1.0 if r.randf() < 0.5 else -1.0), r.randf_range(0.08, 0.45),
				r.randf_range(-0.45, 0.35))
		if _in_shot(at):
			continue
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, r.randf_range(0.6, 0.74), r.randf_range(0.3, 0.44))
		light.omni_range = 3.0
		light.shadow_enabled = false
		light.position = at
		_props.add_child(light)
		_glows.append({"light": light, "base": at, "energy": r.randf_range(0.12, 0.3),
			"flicker": _flicker_of("glow%d" % _glows.size())})


## Whether [param at] is inside the camera's picture (with a margin) - a light there would light
## the table from a place where nothing is burning.
func _in_shot(at: Vector3) -> bool:
	return CardTable.in_shot(_cam_base, _cam.fov, at)


## THE LIGHT: the set dresser's (its table's `light`, [Lights]) - a sky, a sun and what it falls through,
## clouds, birds, lamps out of the shot - in place of the lamp and the room's out-of-shot candles; or,
## for a table that wrote none (every table set before 2026-10-07), those, as every table had them.
func _build_light(spec: Dictionary) -> void:
	if _rig != null:
		_rig.release()
		_rig = null
	var light: Dictionary = spec.get("light", {}) if spec.get("light") is Dictionary else {}
	# ONE WIND for the light and the air: what stirs the leaves overhead blows the petals off the cloth
	_wind = Winds.plan(light.get("wind", {}) if light.get("wind") is Dictionary else {}, hash([_seed, "wind"]))
	_lamp.visible = light.is_empty()
	_fill.visible = light.is_empty()
	if light.is_empty():
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = _ambient.get("color", Color(0.5, 0.46, 0.44))
		_env.ambient_light_energy = float(_ambient.get("energy", 0.18))
		_build_glows()
		return
	_glows = []
	_seen = _seen_points()
	_rig = Lights.build(light, _light_stage(), hash([_seed, "light"]))
	_root3.add_child(_rig.root)


## Where the light stands ([method Lights.build]): the camera, the middle of the reading, the table and
## everything standing on it (a wall stands past them, a canopy over them), the table the camera sees,
## the environment, the room's picture, and what is in the shot.
func _light_stage() -> Dictionary:
	var bounds: AABB = _furniture.get("bounds", AABB(Vector3(-TABLE.x * 0.5, -TABLE.y, TABLE_Z - TABLE.z * 0.5), TABLE))
	for th in _things:
		bounds = bounds.merge((th as Dictionary)["box"] as AABB)
	return {"camera": _cam_base, "fov": _cam.fov, "aspect": 16.0 / 9.0, "middle": Vector3(Tables.ORIGIN.x, 0.0, Tables.ORIGIN.y),
		"bounds": bounds, "seen": _seen, "env": _env, "room": _backdrop_mat, "in_shot": _in_shot, "wind": _wind}


## THE TABLE THE CAMERA SEES, sampled ([method CardTable.seen_points]).
func _seen_points() -> PackedVector3Array:
	return CardTable.seen_points(_cam_base, _cam.fov, _top)


## HOW PALE THE PALEST THING THE LIGHT FALLS ON IS (linear luminance): the cloth where it is lightest
## that the camera sees (its 97th percentile - one pale thread is not the cloth) and the card stock, which
## lies in the spread under the same light.
func _hot_lum() -> float:
	var lums := PackedFloat32Array()
	if not _lum.is_empty():
		var cell := LUM_RECT.size / Vector2(LUM_GRID)
		for p in _seen:
			var gx := clampi(floori((p.x - LUM_RECT.position.x) / cell.x), 0, LUM_GRID.x - 1)
			var gy := clampi(floori((p.z - LUM_RECT.position.y) / cell.y), 0, LUM_GRID.y - 1)
			lums.append(_lum[gy * LUM_GRID.x + gx])
	var hot := 0.0
	if lums.is_empty():
		var c := _cloth_fallback().srgb_to_linear()
		hot = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	else:
		lums.sort()
		hot = lums[clampi(int(lums.size() * 0.97), 0, lums.size() - 1)]
	var stock := CardTable.color(String((_look.get("frame", {}) as Dictionary).get("stock", "#efe6d2"))).srgb_to_linear()
	return maxf(hot, (stock.r * 0.2126 + stock.g * 0.7152 + stock.b * 0.0722) * 0.85)


## The light at show time [param t].
func _tick_light(t: float) -> void:
	if _rig != null:
		_rig.tick(t)


## WHAT LEADS THE LIGHT, in words: a candle (by its thing's name), the sun or a lamp of the table's own
## light, or the lamp.
func lead_name(by_light: Dictionary = {}) -> String:
	if _key_flame >= 0:
		return String(by_light.get(_key_flame, "a candle"))
	if _rig != null:
		if _rig.leads():
			return _rig.key_name()
		if not _lamp.visible:
			var name: String = _rig.key_name()
			return ("%s, faintly - nothing in the light leads it" % name) if not name.is_empty() else "nothing but the sky - the table is dim"
	return "the lamp"


## EVERY LIGHT THROWS ITS OWN SHADOW (the user, 2026-10-05: "most scenes have multiple light
## sources, and thus should probably cast multiple shadows"): every candle and the lamp, so a thing
## has a shadow for each light near it, each turned away from its own. One light had thrown them all
## (every light casting its own then gave the deck no shadow worth the name and each half of a split
## deck two - "it's all very strange"); now the KEY leads instead of casting alone: the candle
## nearest the middle of the table, bright enough to reach the cards, so the deck's long shadow
## toward the reader reads and the others are fainter. The other candles are fills, and the lamp is
## dimmed to one; with no candle at all, the lamp is the key ([member _key_flame] -1). NO CLOTH IS LIT HOTTER THAN IT CAN TAKE ([constant HEAT]): a candle
## by pale cloth is dimmer - and so are candles standing TOGETHER, whose pools add up on the cloth
## between them (two tapers side by side, each at its own limit, burned a pale cloth white through
## the bloom). A candle the cloth cannot let burn at [constant KEY_MIN] is never the key - with
## none that can, the lamp is.
func _light_the_table() -> void:
	# A LIGHT OF THE TABLE'S OWN ([Lights]) is fitted to how pale the table is; where its sun or a lamp
	# leads, every candle burns as a fill
	var leads := false
	if _rig != null:
		_rig.fit(_hot_lum())
		leads = _rig.leads()
	var fields: Array = []
	var key := -1
	var best := INF
	for i in _lights.size():
		var base: Vector3 = (_lights[i] as Dictionary)["base"]
		var lb: Vector3 = (_lights[i] as Dictionary)["light_base"]
		var field := _heat_field(Vector3(base.x, 0.0, base.z), lb.y)
		fields.append(field)
		var d := (base * Vector3(1, 0, 1)).length()
		if not leads and HEAT / maxf(_field_max(field), 0.05) >= KEY_MIN and d < best:
			best = d
			key = i
	# A LIGHT IS AS BRIGHT AS ITS FLAMES: a pillar's three wicks give three flames' light, a
	# candelabra's five tapers five - capped like any other by the cloth they light
	var flames := PackedFloat32Array()
	for i in _lights.size():
		flames.append(float(((_lights[i] as Dictionary)["flames"] as Array).size()))
	var energy := PackedFloat32Array()
	for i in _lights.size():
		energy.append(minf((KEY_ENERGY if i == key else FILL_ENERGY) * flames[i], HEAT / maxf(_field_max(fields[i]), 0.05)))
	# the cloth's hottest spot under all of them at once, brought down to what it can take by
	# dimming every flame that reaches it - a few times, as the hottest spot moves
	for pass_ in 6:
		var total := {}
		for i in _lights.size():
			for c in fields[i]:
				total[c] = float(total.get(c, 0.0)) + energy[i] * float((fields[i] as Dictionary)[c])
		var hot := -1
		var most := HEAT
		for c in total:
			if float(total[c]) > most:
				most = float(total[c])
				hot = int(c)
		if hot < 0:
			break
		for i in _lights.size():
			if (fields[i] as Dictionary).has(hot):
				energy[i] *= HEAT / most * 0.999
	if key >= 0 and energy[key] < KEY_MIN:
		key = -1
	_key_flame = key
	for i in _lights.size():
		var f: Dictionary = _lights[i]
		f["energy"] = energy[i] if i == key else minf(energy[i], FILL_ENERGY * flames[i])
	if _rig == null:
		# the candle has to carry much of the light at the cards, or its shadow is lost under the lamp's
		_lamp.light_energy = _lamp_base * (1.0 if key < 0 else 0.4)
	else:
		# A TABLE WITH A LIGHT OF ITS OWN has no lamp - unless nothing in that light reaches the cards and no
		# candle can lead: then the lamp hangs over it, so a reading is never read in the dark
		_lamp.visible = not leads and key < 0 and _rig.lead_level() < LAMP_FALLBACK
		_lamp.light_energy = _lamp_base * 0.7
	_lit_cloth = _painting_tex


## The cloth's HOTTEST SPOT under a flame [param hf] above [param at] (see [method _heat_field]).
func _heat(at: Vector3, hf: float) -> float:
	return _field_max(_heat_field(at, hf))


static func _field_max(field: Dictionary) -> float:
	var m := 0.0
	for c in field:
		m = maxf(m, float(field[c]))
	return m


## HOW HOT A FLAME [param hf] above [param at] LIGHTS THE TABLE, cell by cell within [constant
## HEAT_R] ([constant LUM_GRID] over [constant LUM_RECT], keyed by cell): each cell's lightness over
## the flame's falloff - height over distance squared, which is the slant of the light times an omni
## light's 1/d at Godot's default attenuation. A table not yet built is its cloth's color.
func _heat_field(at: Vector3, hf: float) -> Dictionary:
	var out := {}
	var cell := LUM_RECT.size / Vector2(LUM_GRID)
	var g := Vector2((at.x - LUM_RECT.position.x) / cell.x, (at.z - LUM_RECT.position.y) / cell.y)
	var reach := Vector2i(ceili(HEAT_R / cell.x), ceili(HEAT_R / cell.y))
	var flat := 0.0
	if _lum.is_empty():
		var c := _cloth_fallback().srgb_to_linear()
		flat = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	for gy in range(maxi(0, floori(g.y) - reach.y), mini(LUM_GRID.y, floori(g.y) + reach.y + 1)):
		for gx in range(maxi(0, floori(g.x) - reach.x), mini(LUM_GRID.x, floori(g.x) + reach.x + 1)):
			var r2 := Vector2((gx + 0.5 - g.x) * cell.x, (gy + 0.5 - g.y) * cell.y).length_squared()
			if r2 <= HEAT_R * HEAT_R:
				var lum := flat if _lum.is_empty() else _lum[gy * LUM_GRID.x + gx]
				out[gy * LUM_GRID.x + gx] = lum * hf / (r2 + hf * hf)
	return out


## [method _heat] at a grid cell's middle for a flame of [constant HEAT_H], kept for the build -
## a candle's place is judged at hundreds of spots.
func _heat_cell(at: Vector3) -> float:
	var cell := LUM_RECT.size / Vector2(LUM_GRID)
	var gx := clampi(floori((at.x - LUM_RECT.position.x) / cell.x), 0, LUM_GRID.x - 1)
	var gy := clampi(floori((at.z - LUM_RECT.position.y) / cell.y), 0, LUM_GRID.y - 1)
	var k := gy * LUM_GRID.x + gx
	if not _heat_cells.has(k):
		_heat_cells[k] = _heat(Vector3(LUM_RECT.position.x + (gx + 0.5) * cell.x, 0.0, LUM_RECT.position.y + (gy + 0.5) * cell.y), HEAT_H)
	return float(_heat_cells[k])


## HOW A FLAME FLICKERS - its own way, so no two keep time: a tempo, how steadily it burns, and
## how often a draft finds it. They all shared one tempo and one swing, and pulsed together.
func _flicker_of(salt: Variant) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_seed, "flicker", salt])
	return {"seed": r.randf() * 1000.0, "rate": exp(r.randf_range(log(0.5), log(2.0))),
		"calm": r.randf_range(0.04, 0.12), "slot": r.randf_range(4.0, 12.0), "drafts": r.randf_range(0.3, 0.65),
		"salt": hash([_seed, "draft", salt])}


## A flame at show time [param t]: (brightness about 1, height about 1, lean). Mostly a steady burn
## - a slow sway and a fine shiver at the flame's own tempo - and now and then a DRAFT: for a second
## or two it gutters, dims and leans. A draft is drawn per slot of the flame's own length from a
## hash, so this is a pure function of time and a render and a scrub see the same flame. The room's
## drafts are still air's ([param drafts]): in the light's wind the wind is the draft ([method _tick_props]).
func _flame_at(fk: Dictionary, t: float, drafts := true) -> Vector3:
	var s := float(fk["seed"])
	var r := float(fk["rate"])
	var calm := float(fk["calm"])
	var slow := _noise.get_noise_2d(t * 0.8 * r, s)
	var fast := _noise.get_noise_2d(t * 7.0 * r, s + 31.0)
	var slot := float(fk["slot"])
	var k := floori(t / slot)
	var h := hash([int(fk["salt"]), k])
	var env := 0.0
	var strength := 0.0
	if drafts and float(h & 0xFFFF) / 65535.0 < float(fk["drafts"]):
		var dur := 0.7 + 1.8 * float((h >> 16) & 0xFF) / 255.0
		var start := float(k) * slot + (slot - dur) * float((h >> 24) & 0xFF) / 255.0
		var u := (t - start) / dur
		if u > 0.0 and u < 1.0:
			env = pow(sin(PI * u), 2.0)
			strength = 0.18 + 0.2 * float((h >> 8) & 0xFF) / 255.0
	var gust := _noise.get_noise_2d(t * 13.0 * r, s + 57.0)
	return Vector3(1.0 + calm * (0.65 * slow + 0.35 * fast) + env * strength * (gust - 0.35),
		1.0 + calm * 2.5 * slow + env * strength * 1.4 * gust,
		_noise.get_noise_2d(t * 1.3 * r, s + 7.0) * 0.4 + env * gust * 1.6)


## A soft round shade, dark at its middle, made once: what a candle's base presses into the cloth.
func _contact_texture() -> Texture2D:
	if _contact_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_contact_tex = gt
	return _contact_tex


## THE CANDLES AT SHOW TIME [param t]: each flame flickering in its own time, and IN THE LIGHT'S WIND
## ([method Winds.flame], as much of it as reaches the flame - [method Props.open_to_air]) leaning downwind,
## flickering in its eddies and guttering in a gust; its thing's light leans and dims with its flames,
## so the shadows round it lean and dance with them.
func _tick_props(t: float) -> void:
	var blows := Winds.blows(_wind)
	for l in _lights:
		# EACH FLAME IN ITS OWN TIME, and their light as bright as they are together
		var bright := 0.0
		var leans := Vector3.ZERO
		for f in (l as Dictionary)["flames"]:
			var fl := _flame_at(f["flicker"], t, not blows)
			var fast := _noise.get_noise_2d(t * 9.0 * float((f["flicker"] as Dictionary)["rate"]), float((f["flicker"] as Dictionary)["seed"]) + 91.0)
			var lean := Vector3(fl.z * 0.0015, 0, 0)
			var axis := Vector3.UP
			var tall := 1.0
			if blows:
				var w := Winds.flame(_wind, t, f["base"] as Vector3, FLAME_H, float(f.get("open", 1.0)))
				axis = w["axis"]
				tall = float(w["tall"])
				fl.x *= float(w["bright"])
				lean += w["mid"] as Vector3
			var mesh: MeshInstance3D = f["mesh"]
			# A SPRITE FACING THE READER, standing on its wick: turned about the upright to the camera, then
			# tipped in its own plane as far as its lean shows from there, and foreshortened by what of it
			# leans toward or away from the lens
			var root := (f["base"] as Vector3) - Vector3(0.0, FLAME_QUAD * 0.5, 0.0)
			var face := (_cam.global_position - root) * Vector3(1, 0, 1)
			face = face.normalized() if face.length() > 1e-5 else Vector3.BACK
			var across := Vector3.UP.cross(face)
			var shown := Vector2(axis.dot(across), axis.y)
			var b := Basis(across, Vector3.UP, face) * Basis(Vector3.BACK, -atan2(shown.x, shown.y)) \
				* Basis.from_scale(Vector3(1.0 + 0.06 * fast, fl.y * tall * shown.length(), 1.0))
			mesh.transform = Transform3D(b, root + b * Vector3(0.0, FLAME_QUAD * 0.5, 0.0) + Vector3(lean.x, 0.0, 0.0) * (0.0 if blows else 1.0))
			if f.get("glow") is ShaderMaterial:
				(f["glow"] as ShaderMaterial).set_shader_parameter("flame", fl.x)
			bright += fl.x
			leans += lean
		var n := maxf(float(((l as Dictionary)["flames"] as Array).size()), 1.0)
		var light: OmniLight3D = (l as Dictionary)["light"]
		light.light_energy = float((l as Dictionary)["energy"]) * bright / n
		# the light leans with its flames, so the shadows breathe with them
		light.position = ((l as Dictionary)["light_base"] as Vector3) + leans / n
	for g in _glows:
		(g["light"] as OmniLight3D).light_energy = float(g["energy"]) * _flame_at(g["flicker"], t).x


# --- the camera ----------------------------------------------------------------------------------------

## The reader's eye: still.
func _tick_camera(_t: float) -> void:
	# A LOCKED-OFF CAMERA: the table is filmed from a tripod. The Camera dial's breath was a
	# millimeter - nothing anyone could see - so the dial is gone from the panel
	_cam.transform = _cam_base


## THE INTRO IS OUT OF FOCUS: the whole frame thrown far out of focus while the channel's name is
## up - nothing on the table to be made out, only its colors - then the focus PULLS as the reading
## opens (the deck's shuffle, the box's opening): the wide blur lifts, and the lens carries on near
## to far, the cloth in front of the reader first, and is off for the reading. The end card leaves it alone.
func _tick_focus(t: float) -> void:
	var ts := float(_times()["opening"])
	var pull := 1.0                      # a reading with no opening placed: nothing to wait for
	if ts < INF:
		pull = clampf((t - (ts - FOCUS_PULL.x)) / (FOCUS_PULL.x + FOCUS_PULL.y), 0.0, 1.0)
	elif _sched.is_empty():
		pull = 0.0                       # the intro: nothing placed yet
	_lens(pull)


## The lens at [param pull] of the intro's focus pull: 0 the intro (the frame through
## [constant CardTable.TITLE_BLUR], the lens at its softest), 1 sharp (both off).
func _lens(pull: float) -> void:
	var k := _ease(clampf(pull / INTRO_LIFT, 0.0, 1.0))
	var wide := CardTable.TITLE_BLUR
	_blur.set_sigma(wide * pow(INTRO_SHARP / wide, k) if k < 1.0 else 0.0)
	if pull >= 1.0:
		_attrs.dof_blur_far_enabled = false
		return
	var e := _ease(pull)
	_attrs.dof_blur_far_enabled = true
	_attrs.dof_blur_far_distance = lerpf(0.04, 1.6, e * e)
	_attrs.dof_blur_far_transition = lerpf(0.05, 0.6, e)
	_attrs.dof_blur_amount = lerpf(FOCUS_BLUR, FOCUS_BLUR * 0.4, e)


# --- the air ---------------------------------------------------------------------------------------------

## THE AIR: the set dresser's effects (its table's `effects`, [Effects]) - fog, motes and bursts -
## built for this camera, with the stage's volumetric fog on only while there is fog to draw.
func _build_air(spec: Dictionary) -> void:
	if _air != null:
		_air.release()
		_air = null
	var fx: Array = spec.get("effects", []) if spec.get("effects") is Array else []
	_spin_wanted = fx.any(func(e: Variant) -> bool:
		return e is Dictionary and String((e as Dictionary).get("kind", "")) == "burst" and String((e as Dictionary).get("on", "")) == "pirouette")
	_spin_key = ""
	if not fx.is_empty():
		_air = Effects.build(fx, _air_stage(), hash([_seed, "air"]))
		_root3.add_child(_air.root)
	var foggy: bool = _air != null and _air.has_fog()
	Effects.fog_environment(_env, foggy)
	# IN FOG, A LIGHT IS SEEN: the lamp's beam and every candle's glow scatter in it, shafts and halos
	_lamp.light_volumetric_fog_energy = 1.6 if foggy else 1.0
	for l in _lights:
		((l as Dictionary)["light"] as OmniLight3D).light_volumetric_fog_energy = 2.0 if foggy else 1.0
	if _rig != null:
		_rig.set_fog(foggy)
	_air_key = ""


## Where the air may be, the camera it is seen through, and what stands in it - the table and the
## things on it (the cards' box too), which motes are homed in front of and fly over; the wind, the
## table's top, where what drifts can lie, and what covers it at a time ([method _cover_at]). And THE LENS: sharp over the table
## (its nearest corner to its farthest, along the camera's axis), blurring past it as the room is -
## [constant ROOM_BLUR] of the frame's width, [constant ROOM_REACH] out - and the air ending just short
## of the room's picture.
func _air_stage() -> Dictionary:
	var table: AABB = _furniture.get("bounds", AABB(Vector3(-TABLE.x * 0.5, -TABLE.y, TABLE_Z - TABLE.z * 0.5), TABLE))
	var under: Array = [table]
	for th in _things:
		under.append((th as Dictionary)["box"])
	if not _box.is_empty():
		under.append(_box["world"])
	var fwd := -_cam_base.basis.z
	var near := INF
	var far := 0.0
	for i in 8:
		var d := (table.get_endpoint(i) - _cam_base.origin).dot(fwd)
		near = minf(near, d)
		far = maxf(far, d)
	var top: Dictionary = (_furniture.get("spec", {}) as Dictionary).get("top", Tables.DEFAULT_TOP)
	return {"regions": CardTable.AIR, "camera": _cam_base, "fov": _cam.fov, "aspect": 16.0 / 9.0, "occluders": under,
		"wind": _wind, "on_top": func(p: Vector2) -> bool: return Tables.inside(top, p, 0.01), "cover": _cover_at,
		"sharp": Vector2(near, far), "defocus": 2.0 * ROOM_BLUR / maxf(1.0 / far - 1.0 / ROOM_REACH, 1e-3),
		"deep": ROOM_REACH * 0.9}


## WHAT LIES ON THE CLOTH at [param p] (xz, [param r] round it) at show time [param t]: the top of the deck
## or of a card lying there, or -INF - where what drifts may not come down, skid or lie uncovered (a
## flower once fell through the deck and lay under it, 2026-10-08). A card held up, or still in the
## deck, covers nothing; a deck being shuffled or washed spreads wider than it lies.
func _cover_at(p: Vector2, t: float, r: float) -> float:
	var tm := _times()
	var wj := _wash_jump(maxf(float(tm["shuffle"]), minf(0.0, _now)))
	var keep := _cur_base
	var keep_gone := _deck_gone
	_cur_base = _deck_at(t, tm, wj)
	_deck_gone = 1 if not wj.is_empty() and t >= float(wj["end"]) else 0
	var top := -INF
	if _cards_from != "box":
		var loose := 0.0
		if t >= float(tm["shuffle"]) and t < float(tm["end"]) + SQUARE:
			loose = 0.1
		if not wj.is_empty() and t >= float(wj["base"]) and t < float(wj["end"]):
			loose = 0.12
		if _under_card(_rest_xf(DECK_N - 1), p, r + loose):
			top = _cur_base.y + float(DECK_N - _deck_gone) * DECK_T
	var events: Array = tm["events"]
	for k in _cards.size():
		var pose := _card_pose(k, t, events[k], wj)
		var xf: Transform3D = pose["xf"]
		if bool(pose["visible"]) and not bool(pose["up"]) and xf.origin.y < _cur_base.y + DECK_UP_AIR and _under_card(xf, p, r):
			top = maxf(top, xf.origin.y + CARD_T)
	_cur_base = keep
	_deck_gone = keep_gone
	return top


## How high over the deck's place a card can be and still lie on the cloth, to the air (meters).
const DECK_UP_AIR := 0.05


## Whether [param p] (xz) is within [param r] of a card posed [param xf].
static func _under_card(xf: Transform3D, p: Vector2, r: float) -> bool:
	var l := xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
	return absf(l.x) <= CARD.x * 0.5 + r and absf(l.z) <= CARD.y * 0.5 + r


## The air at show time [param t] - its bursts planned again whenever the schedule moved (and only
## then: a word heard that moves no action plans nothing, as tracing every card's path is not free).
func _tick_air(t: float) -> void:
	if _air == null:
		return
	var key := str(hash(_sched.map(func(e: Dictionary) -> Vector2: return Vector2(float(e["t0"]), float(e["s"])))))
	if key != _air_key:
		_air_key = key
		_air.plan(_air_moments())
	_air.tick(t)


## THE MOMENTS THE AIR CAN MARK, from the schedule: `{name: [{t, dur, path, from, card}]}` (see
## [constant CardTable.MOMENTS]) - each with the time it starts, how long it lasts, the card it is on
## (-1 for none), and where its emitter is through it (`path`, `[[t, Transform3D], ...]`). A card's
## moment is timed by when the card really gets there - faces the viewer, lands, is down for the close
## - and its path is the card as the table draws it over the whole window its particles are born in
## ([method _card_path]), never a pose it has yet to reach: the close was once marked at the spread's
## mark from where each card would lie, and burst on the empty cloth beside the last card while it was
## still held up on the left, about to be laid there (2026-10-08). A moment the voice has not reached
## yet is not here.
func _air_moments() -> Dictionary:
	var out := {}
	for m in CardTable.MOMENTS:
		out[m] = []
	var tm := _times()
	if float(tm["shuffle"]) < INF:
		var ts := float(tm["shuffle"])
		(out["shuffle"] as Array).append({"t": ts, "dur": 0.5, "from": "point", "card": -1,
			"path": [[ts, Transform3D(Basis.IDENTITY, _mid + Vector3(0.0, DECK_T * DECK_N, 0.0))]]})
	var all_events: Array = tm["events"]
	var wj0 := _wash_jump(maxf(float(tm["shuffle"]), minf(0.0, _now)))
	# THE CLOSE waits for the last card down: the spread's mark lays a card still held up, and a turn
	# under way finishes
	var tc := float(tm["spread"])
	var down := tc
	for k in _cards.size():
		var ev: Array = all_events[k]
		for i in ev.size():
			var e: Dictionary = ev[i]
			var td := float(e["t0"])
			if td == INF:
				continue
			var s := maxf(float(e["s"]), 0.05)
			var off := float(e["off"])
			var kind := String(e["k"])
			var how := String(e.get("how", ""))
			var tl := float((ev[i + 1] as Dictionary)["t0"]) if i + 1 < ev.size() and String((ev[i + 1] as Dictionary)["k"]) == "lay" else INF
			var up_at := INF
			if kind == "arrive" and how in ["draw", "jumper"]:
				up_at = td + (off + (JUMP_RISE if how == "jumper" else RISE_END)) * s
			elif kind == "show":
				up_at = td + (off + SHOW_RISE) * s
			if how == "jumper":
				# ALONG ITS FLIGHT, from springing off the riffle - or being thrown out of the wash - to
				# landing
				var t0 := td + (off + JUMP_FLY.x) * s
				var t1 := td + (off + JUMP_FLY.y) * s
				if k == 0 and not wj0.is_empty():
					t0 = float(wj0["eject"])
					t1 = float(wj0["land"])
				(out["jumper"] as Array).append({"t": t0, "dur": t1 - t0, "from": "card", "card": k,
					"path": _card_path(k, t0, t1 - t0, tm, wj0)})
			if up_at < INF:
				(out["reveal"] as Array).append({"t": up_at, "dur": 0.3, "from": "card", "card": k,
					"path": _card_path(k, up_at, 0.3, tm, wj0)})
				for l in _looks(k, up_at, tl):
					var look: Dictionary = (l as Dictionary)["look"]
					if float(look["twirl"]) <= 0.0:
						continue
					# THROUGH THE TWIRL, the card's edges spinning with it
					var a0 := float((l as Dictionary)["at"]) + float(look["turn"]) + float(look["hold"])
					var dur := float(look["twirl"])
					(out["pirouette"] as Array).append({"t": a0, "dur": dur, "from": "card", "card": k,
						"path": _card_path(k, a0, dur, tm, wj0)})
			# WHERE IT LANDS: laid from the hand, dealt, or swept out
			var land := INF
			match kind:
				"lay":
					land = td + LAY_END * s
				"arrive":
					if how == "deal":
						land = td + (off + DEAL_END) * s
					elif how == "fan":
						land = td + (off + TableActions.FAN_EACH * float(e.get("i", 0)) + FAN_MOVE) * s
			if land < INF:
				(out["lay"] as Array).append({"t": land, "dur": 0.2, "from": "card", "card": k,
					"path": _card_path(k, land, 0.2, tm, wj0)})
			var still := land
			if kind == "turn":
				still = td + (off + (FLIP_END_LAY if how == "flip" else TURN_END)) * s
			if td <= tc and still < INF:
				down = maxf(down, still)
	if tc < INF:
		for k in _cards.size():
			(out["close"] as Array).append({"t": down, "dur": 0.8, "from": "card", "card": k,
				"path": _card_path(k, down, 0.8, tm, wj0)})
	return out


## How often a burst's emitter is sampled along its card's path (seconds): a frame's time at 30 - a
## twirl turns well under half a turn between two, so a card's edges eased between them are where
## they are drawn.
const AIR_STEP := 1.0 / 30.0

## CARD [param k] AS THE TABLE DRAWS IT from [param t0] through [param dur] seconds - or through the
## window a moment's particles are born in ([constant Effects.BIRTH]) when that is longer: its pose
## ([method _card_pose]) with the deck where [method _pose] has it, every [constant AIR_STEP]. What a
## burst on it rides: `[[t, Transform3D], ...]`.
func _card_path(k: int, t0: float, dur: float, tm: Dictionary, wj: Dictionary) -> Array:
	var keep := _cur_base
	var keep_gone := _deck_gone
	var span := maxf(dur, Effects.BIRTH)
	var n := maxi(ceili(span / AIR_STEP), 1)
	var ev: Array = (tm["events"] as Array)[k]
	var path: Array = []
	for j in n + 1:
		var t := t0 + span * float(j) / float(n)
		_cur_base = _deck_at(t, tm, wj)
		_deck_gone = 1 if not wj.is_empty() and t >= float(wj["end"]) else 0
		path.append([t, _card_pose(k, t, ev, wj)["xf"]])
	_cur_base = keep
	_deck_gone = keep_gone
	return path


# --- the schedule ----------------------------------------------------------------------------------------

## THE SHUFFLE'S CHAIN, made now, wash plans and all, rather than a frame at a time while it
## plays - and after the things on the table stand, so a wash's cards go round them, never
## through them. Again whenever the table changes.
func _plan_moves() -> void:
	_move_rng.seed = hash([_seed, "tarot-moves"])
	_moves = []
	_jumper_wash()
	_move_at(120.0)


## A JUMPER'S WASH, held back for it: an episode whose first card is a jumper washes the deck into
## it now and then ([constant JUMPER_WASH], its own die) - its one wash begins
## [constant JUMPER_WASH_LEAD] before the jumper is reckoned to come (the script's words at the
## follower's steady pace) and runs [constant JUMPER_WASH_SLACK] past it, so the jumper comes while
## it mixes whatever the voice's real pace ([method _jumper_plan]).
func _jumper_wash() -> void:
	_wash_held = false
	var first := {}
	for a in _parse.get("actions", []):
		var kind := String((a as Dictionary)["kind"])
		if TableActions.shows(kind):
			first = a
			break
	if first.is_empty() or String(first["kind"]) != "jumper":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "jumper-wash"])
	var spoken: PackedStringArray = _parse.get("spoken", PackedStringArray())
	var k := mini(int(first["after"]), spoken.size())
	if rng.randf() >= JUMPER_WASH or k <= 0:
		return
	# the shuffle starts its lead before the first word; the jumper a beat after the intro's last
	var est := _estimated_times(spoken.size())
	var at := est[k - 1] + 0.4 + LEAD - (est[0] - TableActions.SHUFFLE_LEAD - TAIL)
	_wash_held = true
	_wash_from = at - JUMPER_WASH_LEAD
	_wash_until = at + JUMPER_WASH_SLACK


## When each card is drawn and laid, and when the shuffle starts and stops, from the placed
## schedule: `{shuffle, opening, end, draw: [t0, s, kind, lead], lay: [t0, s], spread, first, events}` -
## a time of INF is one the voice has not reached yet. `opening` is when the reading opens, whatever
## its source - the deck's shuffle or the box's opening: the intro's end, where the name goes and the
## focus pulls (a box has no shuffle, and its episodes lost both). `events` is EACH CARD'S TIMELINE, in order: `{k: arrive
## (how: draw, jumper, deal, fan - `i` its place in the waterfall), show, lay, turn (how: tap, untap,
## flip), t0, s, off}` - `off` the seconds (at speed 1) its own phases wait for what goes first: the
## card up before it laid, or the deck pushed aside.
func _times() -> Dictionary:
	var n := _cards.size()
	var draw: Array = []
	var lay: Array = []
	var events: Array = []
	for i in n:
		draw.append([INF, 1.0, "draw", 0.0])
		lay.append([INF, 1.0])
		events.append([])
	var shuffle := INF
	var opening := INF
	var first := INF
	var spread := INF
	var up := -1
	var moved := false
	var pushes := bool((TableActions.SOURCES.get(_cards_from, TableActions.SOURCES["deck"]) as Dictionary)["pushes"])
	var first_act: Array = []
	for e in _sched:
		var a: Dictionary = e["a"]
		var t0 := float(e["t0"])
		var s := float(e["s"])
		var kind := String(a["kind"])
		if not TableActions.source_of(kind).is_empty():
			opening = minf(opening, t0)
			if kind == "shuffle":
				shuffle = t0
			continue
		var showing := up >= 0
		if showing and bool((TableActions.REGISTRY.get(kind, {}) as Dictionary).get("lays", false)):
			lay[up] = [t0, s]
			(events[up] as Array).append({"k": "lay", "t0": t0, "s": s, "off": 0.0})
			up = -1
		var takes := TableActions.takes_from_source(kind)
		var off := TableActions.lead_of(kind, takes and not moved, showing, pushes)
		if takes and first_act.is_empty():
			first_act = [t0, s, kind]
			first = t0
		var k := int(a.get("card", 0)) - 1
		var last := maxi(int(a.get("last", k + 1)) - 1, k)
		match kind:
			"draw", "jumper", "deal":
				if k >= 0 and k < n:
					draw[k] = [t0, s, kind, off]
					(events[k] as Array).append({"k": "arrive", "how": kind, "t0": t0, "s": s, "off": off})
					if TableActions.shows(kind):
						up = k
			"fan":
				for j in range(maxi(k, 0), mini(last + 1, n)):
					draw[j] = [t0, s, kind, off]
					(events[j] as Array).append({"k": "arrive", "how": "fan", "i": j - k, "t0": t0, "s": s, "off": off})
			"show":
				if k >= 0 and k < n:
					(events[k] as Array).append({"k": "show", "t0": t0, "s": s, "off": off})
					up = k
			"tap", "untap", "flip":
				if k >= 0 and k < n:
					(events[k] as Array).append({"k": "turn", "how": kind, "t0": t0, "s": s, "off": off})
			_:
				if TableActions.ends(kind):
					spread = t0
		moved = moved or takes
	return {"shuffle": shuffle, "opening": opening, "end": first, "draw": draw, "lay": lay, "spread": spread,
		"first": first_act, "events": events}


## Where the deck is at [param t]: in the middle while it is shuffled, then pushed to its side
## as the first card comes - squared first (SQUARE), then slid (PUSH_SLIDE), a hair off the cloth.
## A jumper flies out of a riffle in the middle, and the deck goes once that riffle is done - or,
## out of a wash ([param wj], [method _wash_jump]), once the wash is gathered.
func _deck_at(t: float, tm: Dictionary, wj := {}) -> Vector3:
	if _cards_from == "box":
		# IN THE BOX: a tin's deck lies flat on its floor (a box's cards are filed, the deck unseen)
		var inner: AABB = _box.get("inner", AABB(_deck_base, Vector3.ZERO))
		return Vector3(inner.get_center().x, inner.position.y, inner.get_center().z) if not _box.is_empty() else _deck_base
	var ts := float(tm["shuffle"])
	var te := float(tm["end"])
	var wander := _shuffle_wander(minf(maxf(t - ts, 0.0), maxf(te - ts, 0.0))) if ts < INF else Vector3.ZERO
	var first: Array = tm["first"]
	if first.is_empty():
		return _mid + wander
	var s := maxf(float(first[1]), 0.05)
	var go := SQUARE if String(first[2]) != "jumper" else JUMP_RIFFLE
	if not wj.is_empty():
		go = (float(wj["end"]) - float(first[0])) / s
	var u := clampf(((t - float(first[0])) / s - go) / PUSH_SLIDE, 0.0, 1.0)
	if u >= 1.0 and _aside_card >= 0:
		# PUT ASIDE before the card that would crowd it is taken ([method _plan_aside])
		var d: Array = (tm["draw"] as Array)[_aside_card]
		var taken := float(d[0]) + float(d[3]) * float(d[1])
		var v := clampf((t - (taken - ASIDE_S)) / ASIDE_S, 0.0, 1.0)
		return _deck_base.lerp(_deck_far, _ease(v)) + Vector3(0.0, sin(PI * v) * 0.003, 0.0) + wander
	return _mid.lerp(_deck_base, _ease(u)) + Vector3(0.0, sin(PI * u) * 0.004, 0.0) + wander


## THE DECK PUT ASIDE ([constant DECK_CROWD]): the first card of the spread that would lie that near
## the deck, and the spot further out - in the frame, on the top, as far from the spread as it can be,
## by the least slide - it is moved to before that card is drawn. None when nothing crowds it, the die
## says it stays, the cards come from a box, or there is nowhere better; the first card itself crowding
## it puts the deck there from the start.
func _plan_aside(top: Dictionary) -> void:
	_aside_card = -1
	_deck_far = _deck_base
	if _cards_from == "box" or _slots.is_empty():
		return
	var gap := func(a: Rect2, b: Rect2) -> float:
		return Vector2(maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
			maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))).length()
	var feet: Array = []
	for sl in _slots:
		feet.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), CARD))
	var keep := TablePositions.deck_keep(_deck_base)
	var crowd := -1
	for i in feet.size():
		if float(gap.call(keep, feet[i])) < DECK_CROWD:
			crowd = i
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "tarot-deck-aside"])
	if crowd < 0 or rng.randf() >= DECK_ASIDE:
		return
	var lay := CardTable.layout_of(_seed)
	var side := signf(_deck_base.x)
	var best := -INF
	for dx in range(4, 17):
		for dz in range(-3, 3):
			var at := _deck_base + Vector3(side * float(dx) * 0.01, 0.0, float(dz) * 0.02)
			var r := TablePositions.deck_keep(at)
			if not TablePositions._frame_trouble(r, lay).is_empty():
				continue
			if not (Tables.inside(top, r.position, Tables.EDGE) and Tables.inside(top, r.end, Tables.EDGE)
					and Tables.inside(top, Vector2(r.position.x, r.end.y), Tables.EDGE) and Tables.inside(top, Vector2(r.end.x, r.position.y), Tables.EDGE)):
				continue
			var near := INF
			for f in feet:
				near = minf(near, float(gap.call(r, f)))
			# room enough wins; past it, the shorter slide
			var score := minf(near, DECK_CROWD + 0.03) - at.distance_to(_deck_base) * 0.1
			if near > float(gap.call(keep, feet[crowd])) + 0.02 and score > best:
				best = score
				_deck_far = at
	if best == -INF:
		return
	if crowd == 0:
		_deck_base = _deck_far
	else:
		_aside_card = crowd


# --- posing everything --------------------------------------------------------------------------------------

## A lidded shoebox arrives from the side and settles at the center, broad side across the
## table. It stays there while the lid is lifted and set beside it. The contents are built at
## that settled position and travel with it. Scrubbing uses the same poses.
func _pose_box(t: float, tm: Dictionary) -> void:
	if not _box.has("lid"):
		return
	var open_at := float(tm["opening"])
	var u := maxf(t - open_at, 0.0) if open_at < INF else 0.0
	var rest: Transform3D = _box["rest"]
	var side := signf(_deck_base.x)
	var arrival := _ease(clampf(u / 2.7, 0.0, 1.0))
	var turn := _ease(clampf((u - 0.7) / 2.0, 0.0, 1.0))
	var node: Node3D = _box["node"]
	node.transform = Transform3D(rest.basis * Basis(Vector3.UP, -side * (1.0 - turn) * PI * 0.5),
		rest.origin + Vector3(side * 0.30 * (1.0 - arrival), 0.0, 0.015 * (1.0 - arrival)))
	var lift := _ease(clampf((u - 3.0) / 0.8, 0.0, 1.0))
	var away := _ease(clampf((u - 3.8) / 1.2, 0.0, 1.0))
	var lid: Node3D = _box["lid"]
	var lid_rest: Vector3 = _box["lid_rest"]
	var box_bounds: AABB = _box["world"]
	var lower := _ease(clampf((u - 5.0) / 0.9, 0.0, 1.0))
	lid.position = Vector3(lid_rest.x, lerpf(lid_rest.y + 0.065 * lift, 0.003, lower), lid_rest.z) \
		+ rest.basis.inverse() * Vector3(side * (box_bounds.size.x + 0.025) * away, 0.0, 0.08 * away)
	lid.rotation.x = PI * _ease(clampf((u - 4.4) / 1.4, 0.0, 1.0))
	var contents_move := node.transform * rest.affine_inverse()
	for f in _file:
		(f as Node3D).transform = contents_move
	for i in _box_objects.size():
		(_box_objects[i] as Node3D).transform = contents_move * ((_box["objects_rest"] as Array)[i] as Transform3D)
	var shade: Decal = _box["shadow"]
	var moved: AABB = node.transform * (_box["local_bounds"] as AABB)
	shade.position = Vector3(moved.get_center().x, 0.0, moved.get_center().z)
	shade.size = Vector3(moved.size.x * 1.7, 0.03, moved.size.z * 1.7)
	var lid_shade: Decal = _box["lid_shadow"]
	var lid_at: Vector3 = node.transform * lid.position
	lid_shade.position = Vector3(lid_at.x, 0.0, lid_at.z)
	lid_shade.size = Vector3(box_bounds.size.x * 1.7, 0.03, box_bounds.size.z * 1.7)
	lid_shade.modulate.a = 0.6 * away

func _pose(t: float) -> void:
	var tm := _times()
	_pose_box(t, tm)
	# a shuffle that began in the replayed past of a mid-way start is under way NOW, not a hundred
	# thousand seconds in (the chain of moves is only made so far)
	var ts := maxf(float(tm["shuffle"]), minf(0.0, _now))
	var te := float(tm["end"])
	_shuffle_room = te - ts if te < INF else INF
	# a jumper's own riffle, on the jumper's clock (its action's scale) - or the wash it comes out of
	var first: Array = tm["first"]
	var jump_s := maxf(float(first[1]), 0.05) if not first.is_empty() and String(first[2]) == "jumper" else 0.0
	_jump_room = te - ts if jump_s > 0.0 and te < INF else -1.0
	_jump_scale = jump_s if jump_s > 0.0 else 1.0
	var wj := _wash_jump(ts)
	_cur_base = _deck_at(t, tm, wj)
	# THE JUMPER'S CARD IS NOT IN THE DECK once a wash throws it: its mesh is hidden while the wash
	# runs on, and the deck is one mesh short after (identical meshes: the top one goes)
	var gone := -1
	if not wj.is_empty() and t >= float(wj["eject"]):
		gone = int(wj["card"]) if t < float(wj["end"]) else DECK_N - 1
	_deck_gone = 1 if not wj.is_empty() and t >= float(wj["end"]) else 0
	# THE DECK: shuffling from the shuffle mark until the first card leaves it, squared after - or,
	# when the first card is a jumper, riffled once more first: the card flies out of that riffle;
	# or the wash under way runs on and throws it
	for i in DECK_N:
		var xf := _rest_xf(i)
		if t >= ts:
			if t < te:
				xf = _shuffle_xf(i, t - ts)
			elif not wj.is_empty() and t < float(wj["end"]):
				xf = _wash(i, t - float(wj["base"]), wj["m"])
			elif jump_s > 0.0 and wj.is_empty() and te < INF and t < te + JUMP_RIFFLE * jump_s:
				xf = _jump_riffle(i, (t - te) / jump_s, _shuffle_xf(i, te - ts))
			elif t < te + SQUARE and te < INF and jump_s == 0.0:
				xf = _shuffle_xf(i, te - ts).interpolate_with(_rest_xf(i), _ease((t - te) / SQUARE))
		var dm: MeshInstance3D = _deck[i]
		dm.transform = xf
		# a box's cards are filed in it: the deck is seen only lying flat in a tin
		dm.visible = i != gone and (_cards_from != "box" or bool(_box.get("flat", false)))
	# THE CARDS, each from its own timeline
	var showing := -1
	var page_in := 0.0
	var all_events: Array = tm["events"]
	var glint_t := t
	for k in _cards.size():
		var m: MeshInstance3D = _cards[k]
		var pose := _card_pose(k, t, all_events[k], wj)
		m.visible = bool(pose["visible"])
		if not m.visible:
			continue
		m.transform = pose["xf"]
		if _box.has("lid") and float(tm["opening"]) < INF and t < float(tm["opening"]) + 2.7:
			m.transform = (_box["node"] as Node3D).transform * (_box["rest"] as Transform3D).affine_inverse() * m.transform
		if float(pose["page"]) > 0.0:
			showing = k
			page_in = float(pose["page"])
		if not bool(pose["up"]):
			continue
		# THE FOIL breathes while a card is held up, and now and then a glint crosses it
		var mat: ShaderMaterial = _face_mats[k]
		mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(glint_t * TAU / 5.5 + float(k)))
		var cyc := fmod(maxf(glint_t - float(pose["since"]), 0.0), 7.0)
		mat.set_shader_parameter("glint", -1.0 if cyc > 1.4 else lerpf(-0.25, 1.25, cyc / 1.4))
	# a card held alone shows its text on its back: no page beside it
	if _alone:
		showing = -1
	_pose_page(showing, page_in, t)
	# the laid cards keep a slow breath of foil; the back's own glint rides the shuffle
	_back_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(t * TAU / 7.0))


## CARD [param k] AT [param t], from its timeline [param ev] ([method _times]): `{xf, visible, up (held
## up), page (how far its booklet page is open), since (when its last event began)}`. The state the
## events before the one under way left it in - lying (its quarter turns, turned over or not) or held
## up - and the event under way posed from it. A card no event has reached waits in its source: unseen
## in a deck, standing in its place in a box's file.
func _card_pose(k: int, t: float, ev: Array, wj: Dictionary) -> Dictionary:
	var out := {"xf": Transform3D.IDENTITY, "visible": false, "up": false, "page": 0.0, "since": 0.0}
	var cur := -1
	for i in ev.size():
		if t >= float((ev[i] as Dictionary)["t0"]) and float((ev[i] as Dictionary)["t0"]) < INF:
			cur = i
	if cur < 0:
		if _filed() and k < (_box["at_k"] as Array).size():
			out["visible"] = true
			out["xf"] = (_box["at_k"] as Array)[k]
		return out
	out["visible"] = true
	# the state the events before the current one left - a card laid sideways can be untapped upright
	var cards: Array = _pay.get("cards", [])
	var least := -1 if k < cards.size() and TablePositions.lies_sideways(cards[k]) else 0
	var quarter := 0
	var over := false
	var up_at := INF
	var up_ev := -1
	for i in cur:
		var e: Dictionary = ev[i]
		var s := maxf(float(e["s"]), 0.05)
		match String(e["k"]):
			"arrive":
				if String(e["how"]) in ["draw", "jumper"]:
					up_at = float(e["t0"]) + (float(e["off"]) + (JUMP_RISE if String(e["how"]) == "jumper" else RISE_END)) * s
					up_ev = i
			"show":
				up_at = float(e["t0"]) + (float(e["off"]) + SHOW_RISE) * s
				up_ev = i
			"turn":
				match String(e["how"]):
					"tap":
						quarter += 1
					"untap":
						quarter = maxi(quarter - 1, least)
					"flip":
						over = not over
	var e: Dictionary = ev[cur]
	var s := maxf(float(e["s"]), 0.05)
	var t0 := float(e["t0"])
	var u := (t - t0) / s - float(e["off"])
	out["since"] = t0
	var lying := _slot_xf(k, quarter, over)
	# when the card held up now goes down: the next event's start, if it is a lay
	var until := INF
	if cur + 1 < ev.size() and String((ev[cur + 1] as Dictionary)["k"]) == "lay":
		until = float((ev[cur + 1] as Dictionary)["t0"])
	match String(e["k"]):
		"arrive":
			var how := String(e["how"])
			if u < 0.0 and how != "fan":
				# the card before is still going down: this one waits in its source
				out["xf"] = _source_xf(k)
				return out
			match how:
				"draw":
					var at := t0 + (float(e["off"]) + RISE_END) * s
					out["xf"] = _take_xf(k, u, _present_xf(k, t, at, until), RISE_END)
					out["up"] = true
					if u >= PAGE_IN.x:
						out["page"] = _ease(clampf((u - PAGE_IN.x) / (PAGE_IN.y - PAGE_IN.x), 0.0, 1.0))
				"jumper":
					var at := t0 + (float(e["off"]) + JUMP_RISE) * s
					var pres := _present_xf(k, t, at, until)
					if not wj.is_empty():
						# out of a wash: in it, as one of its cards, until it is thrown
						if t < float(wj["eject"]):
							out["visible"] = false
							return out
						out["xf"] = _wash_jump_xf(u, t, t0 + JUMP_REST * s, pres, wj)
					else:
						out["xf"] = _jump_xf(k, u, pres)
					out["up"] = true
					if u >= JUMP_PAGE.x:
						out["page"] = _ease(clampf((u - JUMP_PAGE.x) / (JUMP_PAGE.y - JUMP_PAGE.x), 0.0, 1.0))
				"deal":
					out["xf"] = _take_xf(k, u, lying, DEAL_END)
				"fan":
					var v := u - TableActions.FAN_EACH * float(e.get("i", 0))
					if v < 0.0:
						# still in its source: one of the deck's own until it leaves (a box's stands in its file)
						out["xf"] = _source_xf(k)
						out["visible"] = _filed()
					else:
						out["xf"] = _sweep_xf(k, v, lying)
		"show":
			var at := t0 + (float(e["off"]) + SHOW_RISE) * s
			var pres := _present_xf(k, t, at, until)
			if u < 0.0:
				out["xf"] = lying
			elif u < SHOW_RISE:
				var f := _ease(u / SHOW_RISE)
				var xf := lying.interpolate_with(pres, f)
				xf.origin.y += sin(PI * f) * 0.025
				out["xf"] = xf
			else:
				out["xf"] = pres
			out["up"] = u >= 0.0
			if u >= SHOW_PAGE.x:
				out["page"] = _ease(clampf((u - SHOW_PAGE.x) / (SHOW_PAGE.y - SHOW_PAGE.x), 0.0, 1.0))
		"lay":
			# the card held up goes down into its place
			var from := _present_xf(k, t0, up_at, t0)
			var lay_u := (t - t0) / s
			if lay_u < LAY_END:
				var f := _ease(clampf((lay_u - LAY_MOVE.x) / (LAY_MOVE.y - LAY_MOVE.x), 0.0, 1.0))
				var xf := from.interpolate_with(lying, f)
				xf.origin.y += _lay_lift(from, lying, f)
				if lay_u > LAY_MOVE.y:
					xf.origin.y += (1.0 - clampf((lay_u - LAY_MOVE.y) / (LAY_END - LAY_MOVE.y), 0.0, 1.0)) * 0.002
				out["xf"] = xf
				if lay_u < LAY_PAGE_OUT:
					out["page"] = 1.0 - _ease(lay_u / LAY_PAGE_OUT)
			else:
				out["xf"] = lying
		"turn":
			var how := String(e["how"])
			var to := _slot_xf(k, quarter + (1 if how == "tap" else (-1 if how == "untap" and quarter > least else 0)),
				not over if how == "flip" else over)
			var span := FLIP_END_LAY if how == "flip" else TURN_END
			var f := _ease(clampf(u / span, 0.0, 1.0))
			var xf := lying.interpolate_with(to, f)
			xf.origin.y += sin(PI * f) * (0.03 if how == "flip" else 0.003)
			out["xf"] = xf if u > 0.0 else lying
	if up_ev >= 0 and String(e["k"]) == "lay":
		out["since"] = float((ev[up_ev] as Dictionary)["t0"])
	return out


## HOW HIGH A CARD LAID DOWN IS LIFTED at [param f] of its way (0..1, eased) from [param from] (held up)
## to [param to] (lying): the usual [constant LAY_ARC]'s arc, or - when the straight way there carries
## the card across the box the cards are kept in - enough to hold its lowest edge [constant PULL_CLEAR]
## over the box's top for every step it is over it, kept there until it has passed the rim and eased
## down after (the card's footprint, turned as it is at each step; [constant LAY_SAMPLES] steps), and
## gone by the time it lies. Feedback 0010: a card laid behind the box went down through it.
func _lay_lift(from: Transform3D, to: Transform3D, f: float) -> float:
	var lift := sin(PI * f) * LAY_ARC
	if _box.is_empty():
		return lift
	var world: AABB = _box["world"]
	var rim := Rect2(world.position.x, world.position.z, world.size.x, world.size.z).grow(-BOX_GRAZE)
	var step := 1.0 / float(LAY_SAMPLES)
	for s in range(1, LAY_SAMPLES):
		var fs := float(s) * step
		var xf := from.interpolate_with(to, fs)
		var b := xf.basis
		# half the card's extent along each world axis, turned as it is
		var half := Vector3(
			CARD.x * absf(b.x.x) + CARD.y * absf(b.z.x) + CARD_T * absf(b.y.x),
			CARD.x * absf(b.x.y) + CARD.y * absf(b.z.y) + CARD_T * absf(b.y.y),
			CARD.x * absf(b.x.z) + CARD.y * absf(b.z.z) + CARD_T * absf(b.y.z)) * 0.5
		if not Rect2(xf.origin.x - half.x, xf.origin.z - half.z, half.x * 2.0, half.z * 2.0).intersects(rim):
			continue
		var need := world.end.y + PULL_CLEAR + half.y - xf.origin.y
		# held for the step either side, eased away over LAY_EASE after
		var held := 1.0 - smoothstep(0.0, LAY_EASE, absf(f - fs) - step)
		lift = maxf(lift, need * held)
	# set down: nothing is left of it where the card lies
	return minf(lift, LAY_LIFT_MAX) * smoothstep(1.0, 1.0 - LAY_LAND, f)


## WHERE CARD [param k] WAITS before it is taken: on top of the deck, or standing in the box's file (on
## top of a tin's flat deck).
func _source_xf(k: int) -> Transform3D:
	if _filed() and k < (_box["at_k"] as Array).size():
		return (_box["at_k"] as Array)[k]
	return _deck_top_xf(k)


## CARD [param k] TAKEN FROM ITS SOURCE to [param to], [param u] seconds into a taking of [param span]
## seconds - a draw's own phases ([method _draw_xf]) at its pace: off the top of the deck and turned
## over, or pulled straight up out of the box's file ([method _pull_xf]); then on to [param to].
func _take_xf(k: int, u: float, to: Transform3D, span: float) -> Transform3D:
	var r := u * RISE_END / maxf(span, 0.05)
	if _filed():
		return _pull_xf(k, r, to)
	return _draw_xf(k, r, to)


## A card PULLED FROM THE BOX at [param r] (a draw's phases): still in the file while the hand finds it,
## then up along its own plane until it clears the rim, then on to [param to].
func _pull_xf(k: int, r: float, to: Transform3D) -> Transform3D:
	var at: Transform3D = (_box["at_k"] as Array)[k]
	if r < SQUARE:
		return at
	var inner: AABB = _box["inner"]
	var v := CardTable.card_size(_look).y if bool(_box.get("upright", true)) else CardTable.card_size(_look).x
	if String(_staging.get("contents", "file")) != "file":
		v = 0.0
	var raised := Transform3D(at.basis, Vector3(at.origin.x, maxf(inner.end.y, (_box["world"] as AABB).end.y) + v * 0.5 + PULL_CLEAR, at.origin.z))
	if r < FLIP_END:
		return at.interpolate_with(raised, _ease((r - SQUARE) / (FLIP_END - SQUARE)))
	if r < RISE_END:
		return raised.interpolate_with(to, _ease((r - FLIP_END) / (RISE_END - FLIP_END)))
	return to


## A card IN A WATERFALL at [param v] seconds of its own slide ([constant FAN_MOVE]): off the deck and
## along the cloth to [param to], low, turning face up as it goes - or pulled up out of the box first.
func _sweep_xf(k: int, v: float, to: Transform3D) -> Transform3D:
	if _filed():
		return _pull_xf(k, v * RISE_END / FAN_MOVE, to)
	var from := _deck_top_xf(k)
	if v >= FAN_MOVE:
		return to
	var f := _ease(clampf(v / FAN_MOVE, 0.0, 1.0))
	var xf := from.interpolate_with(to, f)
	xf.origin.y += sin(PI * f) * 0.018
	return xf


## Deck slot [param i] at rest - the squared deck, a hair off true per slot.
func _rest_xf(i: int) -> Transform3D:
	var j: Vector3 = _slot_jit[i] if i < _slot_jit.size() else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, j.z), _cur_base + Vector3(j.x, (float(i) + 0.5) * DECK_T, j.y))


## Drawn card [param k] lying on top of the deck, face down (the way it will come up).
func _deck_top_xf(k: int) -> Transform3D:
	var j: Vector3 = _slot_jit[DECK_N] if _slot_jit.size() > DECK_N else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, j.z + (PI if _reversed(k) else 0.0)),
		_cur_base + Vector3(j.x, float(DECK_N - _deck_gone) * DECK_T + CARD_T * 0.5, j.y))


## Card [param k] held up to the camera on the left: floating, turning a little on its axes as a
## card in a hand does, and now and then turned over to look at its back ([method _turn_of]) -
## between [param up_at], when it is fully up, and [param until], when it goes down.
func _present_xf(k: int, t: float, up_at := INF, until := INF) -> Transform3D:
	var c := _cam_base.basis
	var b := Basis(-c.x, -c.z, -c.y)
	var rng_k := float(hash([_seed, k]) & 0xFF) / 255.0
	var yaw := deg_to_rad(lerpf(4.0, 10.0, rng_k)) + sin(t * 0.5 + rng_k * 6.0) * deg_to_rad(3.2) \
		+ sin(t * 0.21 + rng_k * 2.0) * deg_to_rad(1.8)
	var roll := deg_to_rad(lerpf(-2.5, 2.5, fmod(rng_k * 7.3, 1.0))) + sin(t * 0.37 + 1.0) * deg_to_rad(1.3)
	var tilt := sin(t * 0.29 + rng_k * 4.0) * deg_to_rad(2.6)
	if _alone:
		# held alone in the middle: square to the lens, the hand's sway smaller
		yaw *= 0.45
	b = Basis(c.y, yaw + _turn_of(k, t, up_at, until)) * Basis(c.x, tilt) * Basis(c.z, roll) * b
	if _reversed(k):
		b = Basis(c.z, PI) * b
	var at := PRESENT_ALONE if _alone else PRESENT
	var off := Vector3(at.x + sin(t * 0.7 + rng_k) * 0.0012, at.y + sin(t * 0.9 + 1.3) * 0.0015,
		-(PRESENT_ALONE_DIST if _alone else PRESENT_DIST))
	return Transform3D(b, _cam_base * off)


## How far card [param k] is turned over at [param t] (0 face on, PI showing its back - a whole
## turn more is the same pose): a look at its back ([method _look_of]), first some seconds after it
## is up and now and then another ([constant LOOK_AGAIN]) - never while it is coming up or about to
## go down, and for most cards never.
func _turn_of(k: int, t: float, up_at: float, until: float) -> float:
	if up_at == INF or t < up_at:
		return 0.0
	for l in _looks(k, up_at, until):
		var at := float((l as Dictionary)["at"])
		var look: Dictionary = (l as Dictionary)["look"]
		if t < at:
			return 0.0
		if t - at < float(look["total"]):
			return _look_angle(look, t - at)
	return 0.0


## EVERY LOOK AT CARD [param k]'s BACK while it is held - up at [param up_at], going down at
## [param until] - in order: `[{at, look}]` ([method _look_of]). What [method _turn_of] poses, and
## what the air's pirouettes are timed by, from one place.
func _looks(k: int, up_at: float, until: float) -> Array:
	var out: Array = []
	if up_at == INF:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, k, "turn"])
	var at := 0.0
	var forced := k == _spin_card()
	if String(_staging["text"]) == "back":
		# ITS TEXT IS ON ITS BACK: turned over to show it every time, a few seconds after it is up, and
		# held there long enough to read
		var back := RandomNumberGenerator.new()
		back.seed = hash([_seed, k, "back"])
		var turn := back.randf_range(TURN.x, TURN.y)
		var look := {"way": 1.0 if back.randf() < 0.5 else -1.0, "turn": turn,
			"hold": back.randf_range(BACK_HOLD.x, BACK_HOLD.y), "twirl": 0.0, "back": back.randf_range(TURN.x, TURN.y)}
		look["total"] = float(look["turn"]) + float(look["hold"]) + float(look["back"])
		at = up_at + back.randf_range(BACK_LOOK.x, BACK_LOOK.y)
		if at + float(look["total"]) > until - 1.0:
			# a short passage: turned over at once, and back as it ends
			at = up_at + 0.4
			look["hold"] = maxf(until - 1.0 - at - turn - float(look["back"]), 0.0)
			look["total"] = float(look["turn"]) + float(look["hold"]) + float(look["back"])
			if look["hold"] <= 0.5:
				return out
		out.append({"at": at, "look": look})
		if rng.randf() > LOOK_AGAIN and not forced:
			return out
		at += float(look["total"]) + rng.randf_range(LOOK_GAP.x, LOOK_GAP.y)
	else:
		if rng.randf() > TURN_CHANCE and not forced:
			return out
		at = up_at + rng.randf_range(5.0, 9.0)
	var spun := false
	for i in 64:
		var look := _look_of(rng, not spun, forced)
		spun = spun or float(look["twirl"]) > 0.0
		if forced and float(look["twirl"]) > 0.0 and at + float(look["total"]) > until - 1.0:
			# THE TWIRL A BURST MARKS fits in somewhere while the card is held, or it is not done
			at = maxf(up_at + 1.5, until - 1.0 - float(look["total"]))
		if at + float(look["total"]) > until - 1.0:
			return out
		out.append({"at": at, "look": look})
		if rng.randf() > LOOK_AGAIN:
			return out
		at += float(look["total"]) + rng.randf_range(LOOK_GAP.x, LOOK_GAP.y)
	return out


## THE CARD TWIRLED for a burst on the pirouette ([constant SPIN_ROOM]), or -1 when no burst marks one -
## chosen again whenever the schedule moves.
func _spin_card() -> int:
	if not _spin_wanted:
		return -1
	var key := "%d|%d" % [_built_n, _sched.size()]
	if key == _spin_key:
		return _spin_k
	_spin_key = key
	_spin_k = -1
	var tm := _times()
	var order: Array = range(_cards.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "spin"])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	var longest := 0.0
	for k in order:
		var span := _held_span(int(k), tm)
		var room := span.y - span.x
		if room >= SPIN_ROOM:
			_spin_k = int(k)
			return _spin_k
		if room > longest and room > 1.0 + PIROUETTE_HOLD.x + TURN.x + TWIRL.y + 2.5:
			longest = room
			_spin_k = int(k)
	return _spin_k


## WHEN CARD [param k] IS HELD UP: from the moment it faces the camera to the moment it goes down (INF
## when it is never laid) - `Vector2(INF, INF)` for a card never held up - as [method _air_moments]
## reads them off [param tm] ([method _times]).
func _held_span(k: int, tm: Dictionary) -> Vector2:
	var ev: Array = (tm["events"] as Array)[k] if k < (tm["events"] as Array).size() else []
	for i in ev.size():
		var e: Dictionary = ev[i]
		var td := float(e["t0"])
		if td == INF:
			continue
		var s := maxf(float(e["s"]), 0.05)
		var off := float(e["off"])
		var kind := String(e["k"])
		var how := String(e.get("how", ""))
		var up_at := INF
		if kind == "arrive" and how in ["draw", "jumper"]:
			up_at = td + (off + (JUMP_RISE if how == "jumper" else RISE_END)) * s
		elif kind == "show":
			up_at = td + (off + SHOW_RISE) * s
		if up_at < INF:
			var tl := float((ev[i + 1] as Dictionary)["t0"]) if i + 1 < ev.size() and String((ev[i + 1] as Dictionary)["k"]) == "lay" else INF
			return Vector2(up_at, tl)
	return Vector2(INF, INF)


## ONE LOOK AT A HELD CARD'S BACK, drawn: which way it turns (`way`, 1 or -1 - a hand turns a card
## either way), how long the turn over takes (`turn`), how long the back is held (`hold`), then
## either how long the turn back takes (`back`) or, for a PIROUETTE, the twirl on round (`twirl`) -
## the other 0; `total` its seconds. A card that has already pirouetted does not again
## ([param may_spin] false).
static func _look_of(rng: RandomNumberGenerator, may_spin := true, force := false) -> Dictionary:
	var way := 1.0 if rng.randf() < 0.5 else -1.0
	var turn := rng.randf_range(TURN.x, TURN.y)
	var spin := (rng.randf() < PIROUETTE_CHANCE or force) and may_spin
	var hold := rng.randf_range(PIROUETTE_HOLD.x, PIROUETTE_HOLD.y) if spin \
		else exp(rng.randf_range(log(TURN_HOLD.x), log(TURN_HOLD.y)))
	var twirl := rng.randf_range(TWIRL.x, TWIRL.y) if spin else 0.0
	var back := 0.0 if spin else rng.randf_range(TURN.x, TURN.y)
	return {"way": way, "turn": turn, "hold": hold, "twirl": twirl, "back": back,
		"total": turn + hold + twirl + back}


## How far a held card is turned (radians) [param v] seconds into [param look] ([method _look_of]):
## over to its back and held there; then back the way it came - or, in a pirouette, on round the
## same way: a flick that winds down onto its face, three whole turns from where it started.
static func _look_angle(look: Dictionary, v: float) -> float:
	var way := float(look["way"])
	var turn := float(look["turn"])
	var hold := float(look["hold"])
	if v < turn:
		return way * PI * _ease(v / turn)
	if v < turn + hold:
		return way * PI
	var twirl := float(look["twirl"])
	if twirl > 0.0:
		# quick out of the hold, long to wind down (still at both ends)
		return way * (PI + 5.0 * PI * _ease(pow(clampf((v - turn - hold) / twirl, 0.0, 1.0), 0.7)))
	return way * PI * (1.0 - _ease((v - turn - hold) / float(look["back"])))


## A drawn card at [param u] seconds into its draw.
func _draw_xf(k: int, u: float, pres: Transform3D) -> Transform3D:
	var top := _deck_top_xf(k)
	if u < SQUARE:
		return top
	if u < SLIDE_END:
		var e := _ease((u - SQUARE) / (SLIDE_END - SQUARE))
		var xf := top
		xf.origin += Vector3(0, 0.004 * e, 0.05 * e)
		return xf
	var slid := top
	slid.origin += Vector3(0, 0.004, 0.05)
	var lifted := slid.origin + Vector3(0, 0.085, 0.035)
	if u < FLIP_END:
		var e := _ease((u - SLIDE_END) / (FLIP_END - SLIDE_END))
		var b := slid.basis * Basis(Vector3(0, 0, 1), PI * e)
		return Transform3D(b, slid.origin.lerp(lifted, e))
	var flipped := Transform3D(slid.basis * Basis(Vector3(0, 0, 1), PI), lifted)
	if u < RISE_END:
		return flipped.interpolate_with(pres, _ease((u - FLIP_END) / (RISE_END - FLIP_END)))
	return pres


## Deck slot [param i] in a jumper's riffle at [param v] (its action's seconds) - eased in over the
## first moments from [param was], wherever the shuffle left that slot.
func _jump_riffle(i: int, v: float, was: Transform3D) -> Transform3D:
	var xf := _riffle(i, v, JUMP_RIFFLE, hash([_seed, "jumper-riffle"]))
	return was.interpolate_with(xf, _ease(v / 0.35)) if v < 0.35 else xf


## Where a jumper rides before it springs: on top of the riffle's right half, one card above its
## top card (so it moves with the half), from the top of the deck as the riffle begins.
func _jump_ride(k: int, v: float) -> Transform3D:
	var top := _riffle(DECK_N - 1, v, JUMP_RIFFLE, hash([_seed, "jumper-riffle"]))
	top.origin += top.basis.y.normalized() * DECK_T
	top.basis = top.basis * Basis(Vector3.UP, PI if _reversed(k) else 0.0)
	return _deck_top_xf(k).interpolate_with(top, _ease(v / 0.35)) if v < 0.35 else top


## THE JUMPER OUT OF A WASH at [param u] seconds into its action ([param t] show time): thrown as
## the wash's card it was ([method _flight_xf]) - the drawn card's own mesh, a spread card's
## thickness - lying face up where it fell until [param rest_at], then picked up and shown.
func _wash_jump_xf(u: float, t: float, rest_at: float, pres: Transform3D, wj: Dictionary) -> Transform3D:
	var c := int(wj["card"])
	var base := float(wj["base"])
	if u < JUMP_REST:
		return _as_drawn(_wash(c, t - base, wj["m"]))
	var lying := _as_drawn(_wash(c, rest_at - base, wj["m"]))
	if u < JUMP_RISE:
		var e := _ease((u - JUMP_REST) / (JUMP_RISE - JUMP_REST))
		var xf := lying.interpolate_with(pres, e)
		xf.origin.y += sin(PI * e) * 0.03
		return xf
	return pres


## A deck mesh's pose [param xf] for a drawn card's mesh: the same card, the same thickness (a drawn
## card's mesh is [constant CARD_T] thick, a deck slot's [constant DECK_T]).
static func _as_drawn(xf: Transform3D) -> Transform3D:
	xf.basis.y = xf.basis.y * (DECK_T / CARD_T)
	return xf


## A jumper at [param u] seconds into its action: riding a riffle's half, springing off it as the
## halves fall, flying to land face up, lying there a moment, then picked up and shown.
func _jump_xf(k: int, u: float, pres: Transform3D) -> Transform3D:
	var land := Transform3D(Basis(Vector3.UP, 0.6 + (PI if _reversed(k) else 0.0)) * _face_up(),
		_jump_land + Vector3(0, CARD_T * 0.5, 0))
	if u < JUMP_FLY.x:
		return _jump_ride(k, u)
	if u < JUMP_FLY.y:
		var top := _jump_ride(k, JUMP_FLY.x)
		var e := clampf((u - JUMP_FLY.x) / (JUMP_FLY.y - JUMP_FLY.x), 0.0, 1.0)
		var pos := top.origin.lerp(land.origin, e) + Vector3(0, sin(PI * e) * 0.13, 0)
		var b := Basis(Vector3.UP, 0.6 * e + 1.3 * PI * e) * top.basis * Basis(Vector3(0, 0, 1), 3.0 * PI * e)
		# ...COMING DOWN AS IT LIES: the tumble alone ends a third of a turn off the card's landing (it
		# snapped round as it touched the cloth), so what is left over is taken up along the flight
		var end := Basis(Vector3.UP, 0.6 + 1.3 * PI) * top.basis.orthonormalized() * Basis(Vector3(0, 0, 1), 3.0 * PI)
		var left := Quaternion(land.basis * end.orthonormalized().inverse())
		return Transform3D(Basis(Quaternion.IDENTITY.slerp(left, e)) * b, pos)
	var settle := land
	settle.origin += Vector3(0.006, 0, 0.004) * clampf((u - JUMP_FLY.y) / 0.4, 0.0, 1.0)
	if u < JUMP_REST:
		return settle
	if u < JUMP_RISE:
		var e := _ease((u - JUMP_REST) / (JUMP_RISE - JUMP_REST))
		var xf := settle.interpolate_with(pres, e)
		xf.origin.y += sin(PI * e) * 0.03
		return xf
	return pres


func _pose_page(k: int, amount: float, t: float) -> void:
	_page.visible = k >= 0 and amount > 0.001
	if not _page.visible:
		return
	if k != _page_for:
		_page_for = k
		var cards: Array = _pay.get("cards", [])
		_page_canvas.card = cards[k] if k < cards.size() else {}
		CardFaces.redraw(_page_vp)
	var c := _cam_base.basis
	var yaw := -deg_to_rad(6.0) + sin(t * 0.45 + 2.0) * deg_to_rad(2.8) + sin(t * 0.19 + 0.7) * deg_to_rad(1.4)
	var tilt := sin(t * 0.33 + 1.1) * deg_to_rad(2.0)
	var b := Basis(c.y, yaw) * Basis(c.x, tilt) * Basis(c.z, sin(t * 0.27) * deg_to_rad(0.8)) * c
	var off := Vector3(PAGE.x + (1.0 - amount) * 0.22, PAGE.y + sin(t * 0.8 + 0.4) * 0.0012,
		-PRESENT_DIST - 0.004)
	_page.transform = Transform3D(b, _cam_base * off)


# --- the shuffle ------------------------------------------------------------------------------------------

## The resting spot after each shuffle move drifts a few millimeters. It is computed from the
## move's seed and eased over that move, so repeated cuts do not snap to an identical spot.
func _shuffle_wander(u: float) -> Vector3:
	_move_at(u)
	var from := Vector3.ZERO
	for m in _moves:
		var d: Dictionary = m
		var start := float(d["t0"])
		if u < start:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(d["seed"]), "resting place"])
		var to := Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004))
		if u < start + float(d["dur"]):
			return from.lerp(to, _ease(clampf((u - start) / maxf(float(d["dur"]), 0.01), 0.0, 1.0)))
		from = to
	return from

## Deck slot [param i] at [param u] seconds into the shuffle, posed about where the deck is
## ([member _cur_base]). The shuffle is a chain of RUNS (see [constant RUNS], [method _move_at]).
##
## THE DECK'S MESHES ARE INTERCHANGEABLE: every move ends with slot i's mesh in some other slot
## j, and the next move starts it in slot i again. They are identical cards, and a slot's small
## offset belongs to the slot, so the hand-over is invisible.
func _shuffle_xf(i: int, u: float) -> Transform3D:
	var m := _move_at(u)
	if m.is_empty():
		return _rest_xf(i)
	var v := u - float(m["t0"])
	var dur := float(m["dur"])
	match String(m["kind"]):
		"riffle":
			return _riffle(i, v, dur, int(m["seed"]))
		"overhand":
			return _overhand(i, v, dur, int(m["seed"]))
		"cut":
			return _cut(i, v, dur, int(m["seed"]))
		"wash":
			return _wash(i, v, m)
	return _rest_xf(i)


## The move under way at [param u], or empty in a pause. RUNS, NOT A LOTTERY: a reader does not
## pick a new shuffle for every move - they riffle three times running, cut four times, and then
## leave the deck alone for a few seconds (now and then for a long while) while they talk. So a
## run is one kind at one tempo, and the pause after it is drawn from a long-tailed spread. A wash
## comes at most once, and never first. Moves are made as far as they are needed, in order, from
## their own seeded stream - so the chain is the same however a reading gets to a moment.
func _move_at(u: float) -> Dictionary:
	while _moves.is_empty() or float((_moves[-1] as Dictionary)["t0"]) + float((_moves[-1] as Dictionary)["dur"]) \
			+ float((_moves[-1] as Dictionary)["pause"]) < u:
		var t0 := 0.15
		var last := ""
		var washed := false
		for m in _moves:
			washed = washed or String((m as Dictionary)["kind"]) == "wash"
		if not _moves.is_empty():
			var p: Dictionary = _moves[-1]
			t0 = float(p["t0"]) + float(p["dur"]) + float(p["pause"])
			last = String(p["kind"])
		# the run's kind: weighted, never the same as the last run, no second wash, no wash first -
		# and a jumper's wash held back until its time ([method _jumper_wash])
		var held_back := _wash_held and not washed
		var total := 0.0
		var pool: Array = []
		for k in RUNS:
			if k == last or (k == "wash" and (washed or _moves.is_empty() or held_back)):
				continue
			pool.append(k)
			total += float((RUNS[k] as Dictionary)["weight"])
		var pick := _move_rng.randf() * total
		var kind := String(pool[0])
		for k in pool:
			pick -= float((RUNS[k] as Dictionary)["weight"])
			if pick <= 0.0:
				kind = String(k)
				break
		# its time: the run after this one would begin past it
		if held_back and not _moves.is_empty() and t0 >= _wash_from - 6.0:
			kind = "wash"
		var run: Dictionary = RUNS[kind]
		var n := _move_rng.randi_range(int(run["n"][0]), int(run["n"][1]))
		var tempo := _move_rng.randf_range(float(run["dur"][0]), float(run["dur"][1]))
		for i in n:
			var gap := _move_rng.randf_range(float(run["gap"][0]), float(run["gap"][1]))
			if i == n - 1:
				# the pause after a run: a few seconds, or now and then a long linger
				gap = clampf(exp(_move_rng.randfn(IDLE_LOG.x, IDLE_LOG.y)), IDLE_RANGE.x, IDLE_RANGE.y)
				if _move_rng.randf() < LINGER_CHANCE:
					gap = _move_rng.randf_range(9.0, IDLE_RANGE.y)
			var move := {"kind": kind, "t0": t0, "dur": tempo * _move_rng.randf_range(0.95, 1.05),
				"pause": gap, "seed": _move_rng.randi()}
			if kind == "wash" and _wash_held:
				move["dur"] = clampf(_wash_until - t0, float(run["dur"][0]), 44.0)
			if kind == "wash":
				move["plan"] = _wash_plan(int(move["seed"]), float(move["dur"]))
			_moves.append(move)
			t0 += float(move["dur"]) + gap
		if _moves.size() > 400:
			break
	for m in _moves:
		var d: Dictionary = m
		if u >= float(d["t0"]) and u < float(d["t0"]) + float(d["dur"]):
			return d
	return {}


func _riffle(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var half := int(DECK_N * 0.5)
	var left := i < half
	var k := i if left else i - half
	var side := -1.0 if left else 1.0
	var j := mini(2 * k + (0 if left else 1), DECK_N - 1)
	var split_end := 0.5
	var drop0 := 0.55
	var drop1 := dur - 0.6
	var fall := 0.11
	var held_rot := Basis(Vector3(0, 0, 1), side * deg_to_rad(9.0)) * Basis(Vector3.UP, side * deg_to_rad(6.0))
	var held := Transform3D(held_rot, _cur_base + Vector3(side * 0.052, 0.016 + (float(k) + 0.5) * DECK_T, 0.004))
	if v < split_end:
		return _rest_xf(i).interpolate_with(held, _ease(v / split_end))
	var tj := drop0 + (drop1 - drop0) * float(j) / float(DECK_N - 1)
	if v < tj:
		return held
	var messy := _messy(j, seed)
	if v < tj + fall:
		return held.interpolate_with(messy, (v - tj) / fall)
	var sq := clampf((v - drop1 - fall) / maxf(dur - drop1 - fall, 0.05), 0.0, 1.0)
	return messy.interpolate_with(_rest_xf(j), _ease(sq))


func _overhand(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var k0 := int(DECK_N * 0.42)
	if i < k0:
		return _rest_xf(i)
	var held_n := DECK_N - k0
	var packets := 5
	var lift_end := 0.45
	var casc0 := 0.5
	var casc1 := dur - 0.45
	var held := Transform3D(Basis(Vector3.UP, deg_to_rad(-7.0)),
		_cur_base + Vector3(0.07, 0.032 + (float(i - k0) + 0.5) * DECK_T, 0.012))
	if v < lift_end:
		return _rest_xf(i).interpolate_with(held, _ease(v / lift_end))
	# packets peel off the TOP of the held cards and land in turn on the deck: the top packet
	# lands first, so the held cards' order is reversed packet by packet
	var from_top := DECK_N - 1 - i
	var p := mini(packets - 1, int(float(from_top) * float(packets) / float(held_n)))
	var lo := int(ceil(float(p) * float(held_n) / float(packets)))
	var hi := int(ceil(float(p + 1) * float(held_n) / float(packets)))
	var below := lo
	var in_packet := (DECK_N - 1 - lo) - i          # 0 = the packet's top card
	var size := hi - lo
	var j := k0 + below + (size - 1 - in_packet)
	var tp := casc0 + (casc1 - casc0) * float(p) / float(packets)
	var pd := (casc1 - casc0) / float(packets) * 0.85
	if v < tp:
		return held
	var messy := _messy(j, seed)
	if v < tp + pd:
		var e := _ease((v - tp) / pd)
		var xf := held.interpolate_with(messy, e)
		xf.origin.y += sin(PI * e) * 0.012
		return xf
	var sq := clampf((v - casc1) / maxf(dur - casc1, 0.05), 0.0, 1.0)
	return messy.interpolate_with(_rest_xf(j), _ease(sq))


## A CUT, quick enough to be done several times running: the top packet (from a point of the
## move's own) is lifted off and set down beside the deck, the rest is put on top of it, and the
## deck is drawn back to its place. Each cut in a run goes to its own side.
func _cut(i: int, v: float, dur: float, seed: int) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := rng.randi_range(int(DECK_N * 0.3), int(DECK_N * 0.7))
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var aside := Vector3(side * rng.randf_range(0.08, 0.095), 0.0, rng.randf_range(-0.012, 0.018))
	var top := i >= a
	# where each card ends: the old top packet underneath, the old bottom on it
	var j := (i - a) if top else (DECK_N - a + i)
	var out := Vector2(0.0, 0.36) * dur          # the top packet goes aside
	var over := Vector2(0.4, 0.74) * dur         # the rest goes on top of it
	var back := Vector2(0.8, 1.0) * dur          # the whole deck back to its place
	var spot := func(slot: int, off: Vector3) -> Transform3D:
		var r := _rest_xf(slot)
		r.origin += off
		return r
	if v >= back.x:
		var e := _ease((v - back.x) / (back.y - back.x))
		return (spot.call(j, aside) as Transform3D).interpolate_with(_rest_xf(j), e)
	if top:
		if v < out.x:
			return _rest_xf(i)
		var e := _ease(clampf((v - out.x) / (out.y - out.x), 0.0, 1.0))
		var xf := _rest_xf(i).interpolate_with(spot.call(j, aside), e)
		xf.origin.y += sin(PI * e) * 0.022
		return xf
	if v < over.x:
		return _rest_xf(i)
	var e2 := _ease(clampf((v - over.x) / (over.y - over.x), 0.0, 1.0))
	var xf2 := _rest_xf(i).interpolate_with(spot.call(j, aside), e2)
	xf2.origin.y += sin(PI * e2) * 0.028
	return xf2


## A WASH, posed from its plan (see [method _wash_plan]): card [param i] at [param v] seconds in -
## where the plan has it, resting on what is under it ([method _wash_rest]), a card's own thickness
## once spread ([constant WASH_T]: a deck mesh stands for three); in the air if it is thrown
## ([method _flight_xf]).
func _wash(i: int, v: float, m: Dictionary) -> Transform3D:
	var plan := _wash_fit(m)
	if plan.is_empty():
		return _rest_xf(i)
	var fl := _flight_of(plan, i, v)
	if not fl.is_empty():
		return _flight_xf(plan, fl, v)
	var q := _wash_at(plan, i, v)
	var th := lerpf(DECK_T, WASH_T, _wash_spread_at(plan, i, v))
	var r: Vector3 = (_wash_rest_at(plan, v) as Array)[i]
	var b := _tipped(q.w, Vector2(r.y, r.z))
	# the jumper, down: over about its long side, face up on what it lies on
	if int(plan.get("jumper", -1)) == i and v >= float((plan["jumper_flight"] as Dictionary)["t1"]):
		b = b * Basis(Vector3(0.0, 0.0, 1.0), PI)
	return Transform3D(b * Basis.from_scale(Vector3(1.0, th / DECK_T, 1.0)), _cur_base + Vector3(q.x, r.x, q.z))


## Card [param i]'s track at [param v] seconds into the wash, between the plan's steps: x, z and its
## turn. (Its y is its place in the order the cards lie, [method _wash_rest_at] reads it at a step.)
static func _wash_at(plan: Dictionary, i: int, v: float) -> Vector4:
	var track: PackedVector4Array = (plan["tracks"] as Array)[i]
	var f := clampf(v * WASH_HZ, 0.0, float(track.size() - 1))
	var a := int(floor(f))
	return track[a].lerp(track[mini(a + 1, track.size() - 1)], f - float(a))


## The throw card [param i] is in at [param v] - from the moment it leaves its place until it is
## down - or empty.
static func _flight_of(plan: Dictionary, i: int, v: float) -> Dictionary:
	for f in (plan.get("airborne", {}) as Dictionary).get(i, []):
		var fd: Dictionary = f
		if v > float(fd["t0"]) and v < float(fd["t1"]):
			return fd
	return {}


## Whether card [param i] is off the cloth at [param v]: in the air, or the jumper once picked up.
static func _off_cloth(plan: Dictionary, i: int, v: float) -> bool:
	return not _flight_of(plan, i, v).is_empty() or (int(plan.get("jumper", -1)) == i and v > float(plan["gather"]))


## A THROWN CARD at [param v] seconds into the wash: off its place with a pop, along its way and
## turning, and down onto whatever is where it comes down; a jumper turns over on the way.
func _flight_xf(plan: Dictionary, f: Dictionary, v: float) -> Transform3D:
	var i := int(f["card"])
	var up := bool(f["up"])
	var u := clampf((v - float(f["t0"])) / maxf(float(f["t1"]) - float(f["t0"]), 0.01), 0.0, 1.0)
	if not f.has("r0"):
		f["r0"] = (_wash_rest_at(plan, float(f["t0"])) as Array)[i]
		f["r1"] = (_wash_rest_at(plan, float(f["t1"])) as Array)[i]
	var r0: Vector3 = f["r0"]
	var r1: Vector3 = f["r1"]
	var g := _flight_ground(f, v)
	var y := lerpf(r0.x, r1.x, _ease(u)) + float(f["hop"]) * sqrt(maxf(sin(PI * u), 0.0))
	var h: Vector2 = f["axis"]
	var axis := Vector3(h.x, 0.0, h.y)
	var turned: Basis
	if up:
		# over about h, from lying as it lay to lying face up as it comes down ([method _wash]): the
		# flat turn, eased off the slope it left and onto the one it lands on
		var flat := Basis(axis, -PI * _ease((u - 0.08) / 0.8)) * Basis(Vector3.UP, g.z)
		var off := Quaternion(_tipped(float(f["yaw0"]), Vector2(r0.y, r0.z)) * Basis(Vector3.UP, float(f["yaw0"])).inverse())
		var land := _tipped(float(f["lie"]), Vector2(r1.y, r1.z)) * Basis(Vector3(0.0, 0.0, 1.0), PI)
		var onto := Quaternion(land * (Basis(axis, -PI) * Basis(Vector3.UP, float(f["yaw1"]))).inverse())
		turned = Basis(Quaternion.IDENTITY.slerp(onto, _ease((u - 0.8) / 0.2)) * Quaternion.IDENTITY.slerp(off, 1.0 - _ease(u / 0.2))) * flat
	else:
		var slope := Vector2(r0.y, r0.z) * (1.0 - _ease(u / 0.2)) + Vector2(r1.y, r1.z) * _ease((u - 0.8) / 0.2)
		turned = Basis(axis, float(f["wobble"]) * sin(PI * u)) * _tipped(g.z, slope)
	var xf := Transform3D(turned * Basis.from_scale(Vector3(1.0, WASH_T / DECK_T, 1.0)), Vector3(g.x, y, g.y))
	# CLEAR OF WHAT IT PASSES OVER: turning about its middle, an edge would dip into the cloth or a
	# card - so it rides up over that edge, as a card does
	xf.origin.y += _flight_clear(plan, i, v, xf)
	xf.origin += _cur_base
	return xf


## How far a thrown card posed at [param xf] (about the deck's place) must rise to be clear of the
## cloth and of every card resting under it at [param v] ([method _wash_rest_at]): its lower face
## against their faces wherever they cross, while it lies within 60 degrees of flat; its lowest
## corner against the highest of them near it, while it is turned further over.
func _flight_clear(plan: Dictionary, i: int, v: float, xf: Transform3D) -> float:
	var b := xf.basis
	var half := Vector3(CARD.x * 0.5, DECK_T * 0.5, CARD.y * 0.5)
	var drop := absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z
	var need := CLOTH_TOP + FLOOR_GAP - (xf.origin.y - drop)
	var rests: Array = _wash_rest_at(plan, v)
	var n := b.y.normalized()
	var flat := absf(n.y) > 0.5
	# the lower face: its middle, its normal, and its outline on the cloth
	var face := xf.origin - b.y * (DECK_T * 0.5) * signf(n.y)
	var foot := PackedVector2Array()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = face + b.x * (half.x * (s as Vector2).x) + b.z * (half.z * (s as Vector2).y)
		foot.append(Vector2(p.x, p.z))
	var mid := Vector2(xf.origin.x, xf.origin.z)
	var reach := Vector2(CARD.x, CARD.y).length()
	for j in rests.size():
		if j == i or _off_cloth(plan, j, v):
			continue
		var q := _wash_at(plan, j, v)
		var mj := Vector2(q.x, q.z)
		if mj.distance_to(mid) > reach:
			continue
		var r: Vector3 = rests[j]
		var g := Vector2(r.y, r.z)
		var top := lerpf(DECK_T, WASH_T, _wash_spread_at(plan, j, v)) * 0.5 + STACK_GAP
		if not flat:
			need = maxf(need, r.x + g.length() * reach * 0.5 + top - (xf.origin.y - drop))
			continue
		for piece in Geometry2D.intersect_polygons(foot, _card_corners(mj, q.w)):
			for p: Vector2 in piece:
				var low := face.y - (n.x * (p.x - face.x) + n.z * (p.y - face.z)) / n.y
				need = maxf(need, r.x + g.dot(p - mj) + top - low)
	return maxf(need, 0.0)


## A card turned [param yaw] about the vertical and tipped to lie on a plane rising [param slope]
## (meters per meter across x and z): its long and short sides follow the plane, its face is square to it.
static func _tipped(yaw: float, slope: Vector2) -> Basis:
	var flat := Basis(Vector3.UP, yaw)
	if slope == Vector2.ZERO:
		return flat
	var x := flat.x + Vector3.UP * slope.dot(Vector2(flat.x.x, flat.x.z))
	var z := flat.z + Vector3.UP * slope.dot(Vector2(flat.z.x, flat.z.z))
	var up := z.cross(x).normalized()
	# THE LONG SIDE KEPT TRUE to the plane's own line under it, the short side squared to it: the
	# card's corners on a steep slope (a card slid up onto the gathered deck tips 20 degrees) stray
	# least from where its rest was reckoned, its long side's arm being the longer
	z = z.normalized()
	return Basis(up.cross(z).normalized(), up, z)


## CARDS IN A WASH REST ON ONE ANOTHER (the user: they rest "upon each other with a gentle tilt").
## Every card - in the deck, spread, or gathered in the pile - from the bottom of the order the plan
## has them lying in, up, is a rigid card resting on whatever is under it: the cloth beneath its
## corners and the faces of the cards under it, wherever they cross it ([method _rest_on]). So it
## tips: on a card at one end, on the cloth at the other, and over the deck's edge as it slides off
## it; and a card swept onto the pile rides up onto it rather than through it. A card is its own
## thickness (a deck slot's in the deck and the pile, [constant WASH_T] spread); deck slots lie
## flush, the bottom one sunk into the cloth as the squared deck is, spread cards a hair apart and a
## hair over it.
##
## AT THE MOMENT ITSELF, [param v] seconds into the wash, the cards where their tracks have them
## between the plan's steps - two steps' rests blended pass a card sliding onto another through its
## edge for a frame - in the order of the step that ends the moment (a pair parting keeps its order
## a step after it parts, so a pair touching at the moment is in the order it touches in). Kept for
## the frames that ask again. Each card `Vector3(height of its middle, slope
## across x, slope across z)`; a card in the air rests on nothing and nothing on it. Under the palm,
## as the cards fan out, each tilt is calmed ([constant CALM_HZ]); [param bare] is the rest without.
func _wash_rest_at(plan: Dictionary, v: float, bare := false) -> Array:
	if not is_same(plan, _rest_plan):
		_rest_plan = plan
		_rest_steps = {}
	var key := int(round(v * 4000.0))
	key = -key - 1 if bare else key
	if _rest_steps.has(key):
		return _rest_steps[key]
	if _rest_steps.size() > 40:
		_rest_steps = {}
	# THE FAN-OUT'S TILTS, calmed: each card's bare tilt averaged over a window on a fixed grid (so
	# the frames after reuse it), between the two grid points round the moment
	var calm := 0.0 if bare or not wash_calm else \
		1.0 - clampf((v - float((plan["mix"] as Vector2).x)) / CALM_SETTLE, 0.0, 1.0)
	var calmed: Array = []
	if calm > 0.0:
		var g := v * CALM_HZ
		var g0 := int(floor(g))
		var bares: Array = []
		for k in range(g0 - CALM_REACH, g0 + CALM_REACH + 2):
			bares.append(_wash_rest_at(plan, float(k) / CALM_HZ, true))
		for i in (plan["tracks"] as Array).size():
			var a := Vector2.ZERO
			var b := Vector2.ZERO
			for k in CALM_REACH * 2 + 1:
				var r0: Vector3 = (bares[k] as Array)[i]
				var r1: Vector3 = (bares[k + 1] as Array)[i]
				a += Vector2(r0.y, r0.z)
				b += Vector2(r1.y, r1.z)
			calmed.append(a.lerp(b, g - float(g0)) / float(CALM_REACH * 2 + 1))
	var tracks: Array = plan["tracks"]
	var n := tracks.size()
	var last := (tracks[0] as PackedVector4Array).size() - 1
	var f := clampf(v * WASH_HZ, 0.0, float(last))
	var b := mini(int(ceil(f - 0.0001)), last)
	var q: Array = []
	var at: Array = []
	var order: Array = []
	for i in n:
		at.append(_wash_at(plan, i, v))
		q.append((tracks[i] as PackedVector4Array)[b].y)
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool:
		return float(q[x]) < float(q[y]) or (float(q[x]) == float(q[y]) and x < y))
	var out: Array = []
	out.resize(n)
	var under: Array = []      # [corners, middle, rest, thickness, spread, turn] of every card resting so far
	var reach := Vector2(CARD.x, CARD.y).length()
	for i in order:
		var qi: Vector4 = at[i]
		if _off_cloth(plan, i, v):
			out[i] = Vector3(WASH_FLOOR, 0.0, 0.0)
			continue
		var s := _wash_spread_at(plan, i, v)
		var th := lerpf(DECK_T, WASH_T, s)
		var low := lerpf(0.0, CLOTH_TOP + FLOOR_GAP, s) + th * 0.5
		var mid := Vector2(qi.x, qi.z)
		var corners := _card_corners(mid, qi.w)
		var pts := PackedVector2Array()
		var hs := PackedFloat32Array()
		for c in corners:
			pts.append(c - mid)
			hs.append(low)
		for u in under:
			var umid: Vector2 = u[1]
			if umid.distance_squared_to(mid) > reach * reach:
				continue
			var ur: Vector3 = u[2]
			var ug := Vector2(ur.y, ur.z)
			var lift := float(u[3]) * 0.5 + STACK_GAP * maxf(s, float(u[4])) + th * 0.5
			# SQUARED ONE ON THE OTHER (the deck, the pile): held up at its own corners - above the face
			# under it over the whole card, so above it wherever they cross
			if umid.distance_squared_to(mid) < 0.006 * 0.006 and absf(wrapf(qi.w - float(u[5]), -PI, PI)) < 0.12:
				for c in 4:
					hs[c] = maxf(hs[c], ur.x + ug.dot(corners[c] - umid) + lift)
				continue
			for piece in Geometry2D.intersect_polygons(corners, u[0]):
				for p in piece:
					pts.append(p - mid)
					hs.append(ur.x + ug.dot(p - umid) + lift)
		var rest := Vector3(hs[0], 0.0, 0.0) if pts.size() == 4 and hs[0] == hs[1] and hs[1] == hs[2] and hs[2] == hs[3] \
			else _rest_on(pts, hs)
		if calm > 0.0:
			# its calmed tilt, set down on the highest of its supports at that tilt
			var gc := Vector2(rest.y, rest.z).lerp(calmed[i], calm)
			var h := -INF
			for k in pts.size():
				h = maxf(h, hs[k] - gc.dot(pts[k]))
			rest = Vector3(h, gc.x, gc.y)
		out[i] = rest
		under.append([corners, mid, rest, th, s, qi.w])
	_rest_steps[key] = out
	return out


## [method _wash_rest_at] at the plan's step [param k].
func _wash_rest(plan: Dictionary, k: int) -> Array:
	return _wash_rest_at(plan, float(k) / WASH_HZ)


## A card's four corners on the cloth, its middle at [param mid], turned [param yaw].
static func _card_corners(mid: Vector2, yaw: float) -> PackedVector2Array:
	var ax := Vector2(cos(yaw), -sin(yaw)) * CARD.x * 0.5
	var az := Vector2(sin(yaw), cos(yaw)) * CARD.y * 0.5
	return PackedVector2Array([mid - ax - az, mid + ax - az, mid + ax + az, mid - ax + az])


## THE LOWEST A RIGID CARD CAN LIE on supports [param hs] high at [param pts] (about its middle):
## the plane above every one of them that is lowest at the middle - which is where a card settles,
## its weight being at its middle. It is the face, above the middle, of the hull over the
## supports, walked to from the highest of them: tip from that point toward the middle until a
## second holds it, swing about those two until a third does, and over the edge the middle lies
## beyond while it lies outside the three. Every step moves the plane only as far as the first
## support it meets, so no support ever ends up above it. `Vector3(height at the middle, slope
## across x, slope across z)`.
static func _rest_on(pts: PackedVector2Array, hs: PackedFloat32Array) -> Vector3:
	var n := pts.size()
	var top := 0
	for k in n:
		if hs[k] > hs[top]:
			top = k
	var h := hs[top]
	var g := Vector2.ZERO
	if pts[top].length() < 1e-7:
		return Vector3(h, 0.0, 0.0)
	# tip about the highest support, lowering the middle, until a second meets the plane
	var e := pts[top].normalized()
	var t := INF
	var second := -1
	for k in n:
		var de := e.dot(pts[top] - pts[k])
		if de > 1e-7 and (hs[top] - hs[k]) / de < t:
			t = (hs[top] - hs[k]) / de
			second = k
	if second < 0:
		return Vector3(h, 0.0, 0.0)
	g = e * t
	h = hs[top] - g.dot(pts[top])
	var held: Array = [top, second]
	for it in 12:
		if held.size() == 2:
			var pa: Vector2 = pts[held[0]]
			var dir: Vector2 = pts[held[1]] - pa
			if dir.length() < 1e-7:
				break
			var across := Vector2(-dir.y, dir.x).normalized()
			var side := across.dot(-pa)
			if absf(side) < 1e-7:
				break
			if side < 0.0:
				across = -across
			# swing about the two, lowering the middle's side, until a third meets the plane
			var s := INF
			var third := -1
			for k in n:
				var dn := across.dot(pts[k] - pa)
				if dn > 1e-7 and k != held[0] and k != held[1]:
					var sk := maxf(h + g.dot(pts[k]) - hs[k], 0.0) / dn
					if sk < s:
						s = sk
						third = k
			if third < 0:
				break
			g -= across * s
			h += s * across.dot(pa)
			held.append(third)
		# three hold it: settled if the middle lies among them, else over the edge it lies beyond
		var p0: Vector2 = pts[held[0]]
		var p1: Vector2 = pts[held[1]]
		var p2: Vector2 = pts[held[2]]
		var area := (p1 - p0).cross(p2 - p0)
		if absf(area) < 1e-10:
			held.remove_at(2)
			break
		var l0 := p1.cross(p2) / area
		var l1 := p2.cross(p0) / area
		var l2 := p0.cross(p1) / area
		var least := minf(l0, minf(l1, l2))
		if least >= -1e-6:
			break
		held.remove_at(0 if l0 == least else (1 if l1 == least else 2))
	return Vector3(h, g.x, g.y)


## A wash's plan for the time it has: the whole of it, or - when the first card comes before it
## would finish - one that mixes for less and gathers in time. The spreading and the hands are the
## same up to there (their own dice), so it is the same wash, cut short; without it the spread
## went back into the deck in [constant SQUARE]. With too little room to spread, mix and gather at
## all, there is no wash: the deck waits, squared, for the first card (empty). When the first card
## is a jumper that comes while this wash is mixing, the wash runs on into it ([method _jumper_plan]).
func _wash_fit(m: Dictionary) -> Dictionary:
	var jp := _jumper_plan(m)
	if not jp.is_empty():
		return jp
	var room := _shuffle_room - float(m["t0"])
	if room >= float(m["dur"]) - 0.05:
		return m["plan"]
	if room < WASH_ROOM:
		return {}
	var d := snappedf(room, 0.25)
	if float(m.get("cut_dur", -1.0)) != d:
		m["cut_dur"] = d
		m["cut"] = _wash_plan(int(m["seed"]), d, m["plan"])
	return m["cut"]


## A JUMPER OUT OF A WASH: when the first card is a jumper ([member _jump_room] into the shuffle, its
## action at [member _jump_scale]) and wash [param m] is mixing as it comes, the wash planned on
## through it - mixing until the jumper is thrown [constant JUMP_EJECT] into its action, still while
## it lies there, gathered once it is up ([constant JUMP_RISE]). Empty for any other wash, one only
## just spread ([constant JUMP_MIX]) or already gathering, or one with no card it could throw.
func _jumper_plan(m: Dictionary) -> Dictionary:
	if _jump_room < 0.0 or String(m.get("kind", "")) != "wash" or not m.has("plan"):
		return {}
	var into := _jump_room - float(m["t0"])
	var mix: Vector2 = (m["plan"] as Dictionary)["mix"]
	var s := maxf(_jump_scale, 0.05)
	var at := into + JUMP_EJECT * s
	if into < mix.x + JUMP_MIX or at > mix.y:
		return {}
	var key := "%.3f|%.3f" % [into, s]
	if String(m.get("jump_key", "")) != key:
		m["jump_key"] = key
		var pick := into + JUMP_RISE * s
		var plan := _wash_plan(int(m["seed"]), pick + JUMP_GATHER + 0.6, m["plan"],
			{"at": at, "pick": pick, "reversed": _reversed(0)})
		m["jump"] = plan if int(plan["jumper"]) >= 0 else {}
	return m["jump"]


## THE JUMPER'S WASH as the table poses it, from the shuffle's start [param ts]: the wash move, its
## plan, the card thrown, and when (show time) the wash began, the card leaves it and lands, and the
## wash ends - or empty when the jumper does not come out of a wash.
func _wash_jump(ts: float) -> Dictionary:
	if _jump_room < 0.0:
		return {}
	var m := _move_at(_jump_room - 0.001)
	if m.is_empty():
		return {}
	var plan := _jumper_plan(m)
	if plan.is_empty():
		return {}
	var f: Dictionary = plan["jumper_flight"]
	var at := ts + float(m["t0"])
	return {"m": m, "plan": plan, "card": int(plan["jumper"]), "base": at, "eject": at + float(f["t0"]),
		"land": at + float(f["t1"]), "end": at + float(plan["dur"])}


## How spread out card [param i] is at [param v]: 0 a deck slot's thickness, flush in the deck, 1 a
## card's own on the cloth - thinned as the deck is flattened ([constant WASH_FLATTEN]), thickened
## as it lands in the pile.
func _wash_spread_at(plan: Dictionary, i: int, v: float) -> float:
	var t_out := float((plan["out"] as PackedFloat32Array)[i])
	var t_in := float((plan["in"] as PackedFloat32Array)[i])
	return clampf((v - t_out) / WASH_FLATTEN, 0.0, 1.0) * (1.0 - clampf((v - t_in) / 0.6, 0.0, 1.0))


## [param at] (a card's middle, about the deck's place) moved out from anything standing on the
## table, by the least that keeps a card's whole reach clear of it; unchanged when clear.
func _clear_of_standing(at: Vector2) -> Vector2:
	var reach := Vector2(CARD.x, CARD.y).length() * 0.5 + 0.01
	var off := Vector2(_mid.x, _mid.z)
	var p := at
	for i in _standing.size():
		var c: Vector2 = _standing_c[i]
		var d := (p + off).distance_to(c)
		var need := _standing_r[i] + reach
		if d < need:
			var away := ((p + off) - c).normalized() if d > 1e-6 else Vector2(0.0, 1.0)
			p += away * (need - d)
	return p


## Whether a card's reach swept from [param a] to [param b] (about the deck's place) keeps clear of
## everything standing on the table.
func _path_clear(a: Vector2, b: Vector2) -> bool:
	var reach := Vector2(CARD.x, CARD.y).length() * 0.5
	var off := Vector2(_mid.x, _mid.z)
	for i in _standing.size():
		var c: Vector2 = _standing_c[i]
		var q := Geometry2D.get_closest_point_to_segment(c, a + off, b + off)
		if q.distance_to(c) < _standing_r[i] + reach:
			return false
	return true


## NOTHING PASSES THROUGH WHAT STANDS ON THE TABLE. A card going from [param from] to
## [param want] (about the deck's place), turned [param yaw], is moved there a few millimeters at a
## time, and each time it has run into something it is pushed back out - away from that thing's
## middle, the way it came - so it slides along it, and never jumps through to its far side. Wedged
## between two things, where a push out of one is a push into the other, it stays where it was.
func _card_clear(from: Vector2, want: Vector2, yaw: float) -> Vector2:
	if _standing.is_empty() or not _collide:
		return want
	var off := Vector2(_mid.x, _mid.z)
	var reach := Vector2(CARD.x, CARD.y).length() * 0.5
	var travel := from.distance_to(want)
	var near := false
	for i in _standing.size():
		if (want + off).distance_to(_standing_c[i]) < _standing_r[i] + reach + travel + 0.01:
			near = true
			break
	if not near:
		return want
	var steps := maxi(1, ceili(travel / 0.006))
	var p := from
	for s in steps:
		p += (want - from) / float(steps)
		for i in _standing.size():
			var c: Vector2 = _standing_c[i]
			if (p + off).distance_to(c) > _standing_r[i] + reach:
				continue
			p += _push_out(_card_poly(p + off, yaw), _standing[i], (p + off) - c)
	# clear of every one at once
	for round in 4:
		var clear := true
		for i in _standing.size():
			var c: Vector2 = _standing_c[i]
			if (p + off).distance_to(c) > _standing_r[i] + reach:
				continue
			var push := _push_out(_card_poly(p + off, yaw), _standing[i], (p + off) - c)
			if push != Vector2.ZERO:
				p += push
				clear = false
		if clear:
			return p
	return from


## A card lying at [param at] turned [param yaw]: its four corners (x by z).
static func _card_poly(at: Vector2, yaw: float) -> PackedVector2Array:
	var ax := Vector2(cos(yaw), -sin(yaw)) * CARD.x * 0.5
	var az := Vector2(sin(yaw), cos(yaw)) * CARD.y * 0.5
	return PackedVector2Array([at - ax - az, at + ax - az, at + ax + az, at - ax + az])


## How far to move convex [param a] along [param dir] so it no longer overlaps convex [param b] -
## the least such move, by separating axes; along the shortest way out when [param dir] is
## nothing. Zero when they do not overlap.
static func _push_out(a: PackedVector2Array, b: PackedVector2Array, dir: Vector2) -> Vector2:
	var d := dir.normalized() if dir.length() > 1e-6 else Vector2.ZERO
	var need := INF
	var least := INF
	var least_ax := Vector2.ZERO
	for poly in [a, b]:
		var p: PackedVector2Array = poly
		for i in p.size():
			var e := p[(i + 1) % p.size()] - p[i]
			if e.length_squared() < 1e-12:
				continue
			var ax := Vector2(-e.y, e.x).normalized()
			var ra := _span(a, ax)
			var rb := _span(b, ax)
			var o := minf(ra.y, rb.y) - maxf(ra.x, rb.x)
			if o <= 0.0:
				return Vector2.ZERO
			if o < least:
				least = o
				least_ax = ax * (1.0 if ra.x + ra.y > rb.x + rb.y else -1.0)
			var k := d.dot(ax)
			if absf(k) > 1e-4:
				# moving a along d by s shifts it by s * k on this axis: past b's far side, or its near one
				var sep := (rb.y - ra.x) / k if k > 0.0 else (rb.x - ra.y) / k
				if sep >= 0.0:
					need = minf(need, sep)
	if need < INF:
		return d * (need + 0.0004)
	return least_ax * (least + 0.0004)


## Whether two cards lying on the table overlap: their turned rectangles, by separating axes.
static func _cards_overlap(a: Vector2, ya: float, b: Vector2, yb: float) -> bool:
	var d := b - a
	var far := 2.0 * Vector2(CARD.x, CARD.y).length() * 0.5
	if d.length_squared() > far * far:
		return false
	if d.length_squared() < CARD.x * CARD.x:
		return true
	# each card's two axes in turn (written out: a wash asks this some hundred thousand times)
	var a0 := Vector2(cos(ya), -sin(ya))
	var a1 := Vector2(sin(ya), cos(ya))
	var b0 := Vector2(cos(yb), -sin(yb))
	var b1 := Vector2(sin(yb), cos(yb))
	return not (_parted(d, a0, a0, a1, b0, b1) or _parted(d, a1, a0, a1, b0, b1)
		or _parted(d, b0, a0, a1, b0, b1) or _parted(d, b1, a0, a1, b0, b1))


## Whether two cards [param d] apart, turned to axes [param a0] [param a1] and [param b0]
## [param b1], are parted along [param v]: their reaches along it fall short of the gap.
static func _parted(d: Vector2, v: Vector2, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> bool:
	var h := CARD * 0.5
	var ra := h.x * absf(a0.dot(v)) + h.y * absf(a1.dot(v))
	var rb := h.x * absf(b0.dot(v)) + h.y * absf(b1.dot(v))
	return absf(d.dot(v)) > ra + rb


## THE WASH, planned once and sampled at [constant WASH_HZ] - because it is a SIMULATION, not a
## pose: two flat palms work the cloth and drag the cards under them along, and a pose that is a
## function of time alone cannot remember where a palm left a card. Planned from the move's seed,
## so it is the same every time it is posed.
##
##   out      the deck is pushed out across the cloth, top cards first (~2 s)
##   mix      most of the wash: the palms scrub back and forth across the spread, swirl wide and
##            fetch strays back through the middle ([method _wash_gesture]); a card a palm holds
##            goes its way ([method _wash_palm]), slides on when it lets go, and drags and turns
##            every card it passes over ([method _wash_drag]); a card struck hard is thrown out of
##            the spread, face down ([method _eject])
##   gather   six to eight sweeps, each taking the next share of the cards by direction, onto the
##            pile - some missed and fetched by a later one
##   square   the pile is squared into the deck, in the order it lies
##
## A JUMPER'S WASH ([param jump]: `{at, pick, reversed}`, seconds into the wash): the mixing stops at
## `at` and the jumper is thrown - over, face up, clear of every card - and lies there, the others
## sliding on round it, until it is picked up at `pick`; then the hands gather the rest. It leaves
## the deck: `jumper` names its card, -1 when no card could be thrown anywhere it may land.
##
## THE ORDER CHANGES, NEVER THROUGH A CARD: two cards that come to overlap lie the way they met -
## the one sliding in goes on top (never over a card already above it: no stacking loops) - and
## keep that order while they touch; once apart, their next meeting decides again. Each track is
## per card, x / z about the deck's place, y its place in the order the cards lie (what
## [method _wash_rest] rests them in, bottom up), w the card's turn; `flights` are the throws
## ([method _flight_xf]).
func _wash_plan(seed: int, dur: float, base: Dictionary = {}, jump: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "wash"])
	var n := DECK_N
	var steps := int(ceil(dur * WASH_HZ)) + 1
	var dt := 1.0 / WASH_HZ
	var out_end := minf(2.4, dur * 0.2)
	var square := 0.6
	# MANY SMALL SWEEPS: the pile is a few cards at a time, gathered one after another - never the
	# whole spread arriving at once
	var swipes := rng.randi_range(6, 8)
	var gather := clampf(dur * 0.24, 4.0, 7.0)
	var mix_end := maxf(out_end, dur - square - gather)
	var gather_t0 := mix_end
	var jumping := not jump.is_empty()
	if jumping:
		mix_end = float(jump["at"])
		gather_t0 = maxf(float(jump["pick"]), mix_end)
		gather = maxf(dur - square - gather_t0, 1.0)
	# WIDE: the cards go well out across the cloth, a few of them a long way
	var rx := rng.randf_range(0.24, 0.29)
	var rz := rng.randf_range(0.12, 0.15)
	var pos := PackedVector2Array()
	var yaw := PackedFloat32Array()
	var start := PackedVector2Array()
	var aim := PackedVector2Array()
	var t_out := PackedFloat32Array()
	for i in n:
		var jit: Vector3 = _slot_jit[i] if i < _slot_jit.size() else Vector3.ZERO
		start.append(Vector2(jit.x, jit.y))
		# out to somewhere a card can get to: by a way clear of everything standing on the table (a
		# few tries, then the nearest spot clear of them)
		var target := Vector2.ZERO
		for attempt in 6:
			var r := sqrt(rng.randf()) * 0.85
			if rng.randf() < 0.18:
				r = rng.randf_range(0.95, 1.3)    # flung out further than the rest
			var ang := rng.randf() * TAU
			target = Vector2(cos(ang) * rx * r, sin(ang) * rz * r - 0.01)
			if _path_clear(Vector2(jit.x, jit.y), target):
				break
		aim.append(_clear_of_standing(target))
		pos.append(Vector2(jit.x, jit.y))
		yaw.append(jit.z)
		t_out.append(float(n - 1 - i) / float(n) * 0.9)
	var spin0 := PackedFloat32Array()
	for i in n:
		spin0.append(rng.randf_range(-1.1, 1.1))
	var was := pos.duplicate()             # where each card was at the step before, and its turn
	var was_yaw := yaw.duplicate()
	# HOW EACH CARD IS MOVING while it slides (x / z a second, and its turn a second), how hard a palm
	# held it at the last step, and whether a sweep of the gather moves it instead (or it lies in the
	# pile)
	var vel := PackedVector2Array()
	var spin := PackedFloat32Array()
	var held := PackedFloat32Array()
	var kin := PackedByteArray()
	vel.resize(n)
	spin.resize(n)
	held.resize(n)
	kin.resize(n)
	var hands := _wash_hands(seed, out_end, rx, rz)
	# the sweeps, one after another across the gather
	var sweep_len := gather / float(swipes)
	var caught := PackedInt32Array()       # the sweep that brings each card in
	caught.resize(n)
	# plain Arrays while they grow: appending to `tracks[i] as PackedVector4Array` appends to a COPY
	var tracks: Array = []
	for i in n:
		tracks.append([])
	var t_in := PackedFloat32Array()       # when a card is in the pile for good
	t_in.resize(n)
	var from_p := PackedVector2Array()     # a sweep under way: where the card was, where it goes
	var to_p := PackedVector2Array()
	from_p.resize(n)
	to_p.resize(n)
	var from_yaw := PackedFloat32Array()
	var to_yaw := PackedFloat32Array()
	from_yaw.resize(n)
	to_yaw.resize(n)
	var begun := {}
	var land_order: Array = []
	var planned_sweeps := false
	# who lies on whom: pair (i * 64 + j, i < j) -> +1 i on top, -1 j on top, for pairs that overlap
	var rel := {}
	var under: Array = []                  # card -> the cards it lies directly on
	for i in n:
		under.append([])
	var over: Array = []                   # card -> the cards lying on it, at the step before
	for i in n:
		over.append([])
	var layer := PackedInt32Array()
	layer.resize(n)
	var moved := PackedFloat32Array()
	moved.resize(n)
	var stirred := PackedByteArray()       # moved or turned this step: only then can it meet or part
	stirred.resize(n)
	var restacked := true                  # who lies on whom changed this step
	var parted := {}                       # pairs a step apart, keeping their order that step
	# THE THROWS: every flight, the one each card is in at this step (-1 on the cloth), the jumper's
	# card once it is picked up (out of the wash for good), and the hard blows of late (one of them
	# throws the jumper)
	var flights: Array = []
	var flying := PackedInt32Array()
	flying.resize(n)
	var landed := PackedByteArray()
	landed.resize(n)
	var taken := PackedByteArray()
	taken.resize(n)
	var jumper := -1
	var jumper_flight := {}
	var tried := false
	var blown: Array = []                  # [t, card, impact, the blow's way]
	# THE SAME WASH, CUT SHORT ([param base], the whole of it): up to where this one stops mixing, the
	# spreading and the palms are the same, so its tracks and throws are copied rather than made
	# again, and the cards - where they lay, how they were sliding, and who on whom - are taken up
	# from there
	var s_from := 0
	if not base.is_empty() and is_equal_approx(float((base["mix"] as Vector2).x), out_end) \
			and mix_end <= float((base["mix"] as Vector2).y):
		s_from = clampi(int(ceil(mix_end * WASH_HZ)), 2, ((base["tracks"] as Array)[0] as PackedVector4Array).size() - 1)
		for f in base.get("flights", []):
			if float((f as Dictionary)["t0"]) < float(s_from) * dt:
				flights.append(_flight_copy(f as Dictionary))
		var t_prev := float(s_from - 1) * dt
		for i in n:
			var tr: PackedVector4Array = (base["tracks"] as Array)[i]
			var copied: Array = []
			for st in s_from:
				copied.append(tr[st])
			tracks[i] = copied
			var q: Vector4 = tr[s_from - 1]
			var q0: Vector4 = tr[s_from - 2]
			pos[i] = Vector2(q.x, q.z)
			was[i] = pos[i]
			yaw[i] = q.w
			was_yaw[i] = q.w
			vel[i] = Vector2(q.x - q0.x, q.z - q0.z) * WASH_HZ
			spin[i] = (q.w - q0.w) * WASH_HZ
		for i in n:
			if _in_flight(flights, i, t_prev):
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
				continue
			for j in range(i + 1, n):
				if not _in_flight(flights, j, t_prev) and _cards_overlap(pos[i], yaw[i], pos[j], yaw[j]):
					var yi := ((base["tracks"] as Array)[i] as PackedVector4Array)[s_from - 1].y
					var yj := ((base["tracks"] as Array)[j] as PackedVector4Array)[s_from - 1].y
					rel[i * 64 + j] = 1 if yi > yj else -1
					(under[i if yi > yj else j] as Array).append(j if yi > yj else i)
		for i in n:
			for j in under[i]:
				(over[int(j)] as Array).append(i)
	var thrown := flights.size()
	var last_pos := pos.duplicate()        # where each card was at the step before (for meetings between steps)
	var last_yaw := yaw.duplicate()
	for step in range(s_from, steps):
		_breathe()
		var t := float(step) * dt
		last_pos = pos.duplicate()
		last_yaw = yaw.duplicate()
		# WHO IS IN THE AIR: a card from the moment it is thrown until it is down - and, the step it
		# comes down, where its flight ends, on top of whatever it comes down on
		flying.fill(-1)
		landed.fill(0)
		for fi in flights.size():
			var f: Dictionary = flights[fi]
			if t > float(f["t0"]) and t < float(f["t1"]):
				flying[int(f["card"])] = fi
			elif t >= float(f["t1"]) and t - dt < float(f["t1"]):
				var c := int(f["card"])
				landed[c] = 1
				pos[c] = f["to"]
				yaw[c] = float(f["lie"])
				vel[c] = Vector2.ZERO
				spin[c] = 0.0
		# THE JUMPER, DOWN, lies still where it fell - on top of anything - until it is picked up
		var lying := jumper if jumper >= 0 and t >= float(jumper_flight["t1"]) and t < gather_t0 else -1
		if jumper >= 0 and t >= gather_t0:
			taken[jumper] = 1
		if t < out_end:
			# OUT: the palm comes down on the deck and it flattens ([constant WASH_FLATTEN]); then each
			# card slides from it to its place on the cloth, turning as it goes
			kin.fill(1)
			for i in n:
				var e := _ease(clampf((t - WASH_FLATTEN * 0.5 - t_out[i]) / minf(1.1, out_end * 0.4), 0.0, 1.0))
				pos[i] = start[i].lerp(aim[i], e)
				yaw[i] = (_slot_jit[i] as Vector3).z + spin0[i] * e if i < _slot_jit.size() else spin0[i] * e
		elif t < gather_t0:
			# MIX: the cloth slows what slides, cards drag what they lie on, the palms bring what they
			# press to their speed (last, so what a palm holds goes its way), and every card moves.
			# Once the jumper is thrown the palms are still, and what slides runs on and stops.
			kin.fill(0)
			for i in n:
				if flying[i] >= 0 or taken[i] == 1 or i == lying:
					kin[i] = 1
			_wash_rub(hands, vel, spin, under, kin, dt)
			_wash_drag(hands, pos, vel, spin, held, kin, rel, dt)
			held.fill(0.0)
			if t < mix_end:
				for h in 2:
					_wash_palm(hands, h, t, dt, mix_end, pos, yaw, vel, spin, over, held, kin)
			_wash_move(hands, pos, yaw, vel, spin, kin, dt)
			_wash_slump(pos, under, layer, held, kin, dt)
		else:
			if not planned_sweeps:
				planned_sweeps = true
				# who each sweep takes: the sweeps go round the pile, each taking the next SHARE of
				# the cards by direction - so every sweep has cards to bring in, wherever the hands
				# left them (fixed directions sent whole sweeps past empty cloth). A card is
				# missed now and then and a later sweep fetches it. Each lands squared on the pile:
				# a stiff card left with its middle at the pile's edge pivots there, and every card
				# on it leans with it.
				var by_angle: Array = []
				for i in n:
					if taken[i] == 0:
						by_angle.append([atan2(pos[i].y, pos[i].x), i])
				by_angle.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
				var ng := by_angle.size()
				var first_card := rng.randi_range(0, n - 1)
				var share := PackedInt32Array()
				share.resize(n)
				for r in ng:
					share[int((by_angle[(first_card + r) % ng] as Array)[1])] = mini(swipes - 1, int(float(r) * float(swipes) / float(ng)))
				for i in n:
					if taken[i] == 1:
						caught[i] = -1
						t_in[i] = INF
						continue
					var k2 := share[i]
					while k2 < swipes - 1 and rng.randf() < 0.15:
						k2 += 1          # missed: a later sweep fetches it
					caught[i] = k2
				# the pile's order is the order they arrive in
				var order: Array = []
				for i in n:
					if taken[i] == 0:
						order.append([caught[i], pos[i].length(), i])
				order.sort_custom(func(x: Array, y: Array) -> bool:
					if int(x[0]) != int(y[0]):
						return int(x[0]) < int(y[0])
					return float(x[1]) > float(y[1]))
				for o in order:
					land_order.append(int(o[2]))
			var g := t - gather_t0
			kin.fill(0)
			for i in n:
				if taken[i] == 1 or flying[i] >= 0:
					kin[i] = 1
					continue
				# in the pile for good: nothing slides it again
				if t_in[i] > 0.0 and t >= t_in[i]:
					kin[i] = 1
				# the sweep reaches the outermost cards first and pushes them in ahead of it
				var k := caught[i]
				var s0 := float(k) * sweep_len
				var u1 := s0 + sweep_len * 0.82
				if not begun.has(i):
					var r := clampf(pos[i].length() / maxf(rx, rz), 0.0, 1.0)
					var u0 := s0 + (1.0 - r) * 0.28
					if g < u0:
						continue
					begun[i] = u0
					from_p[i] = pos[i]
					from_yaw[i] = yaw[i]
					# into the pile, squared as it lands, near enough: the pile is built, not tidied
					var slot := land_order.find(i)
					var jit2: Vector3 = _slot_jit[slot] if slot >= 0 and slot < _slot_jit.size() else Vector3.ZERO
					to_p[i] = Vector2(jit2.x, jit2.y) + Vector2(rng.randf_range(-0.0025, 0.0025), rng.randf_range(-0.0025, 0.0025))
					to_yaw[i] = jit2.z + rng.randf_range(-0.05, 0.05)
					t_in[i] = gather_t0 + u1
				var b0 := float(begun[i])
				if g > u1 + dt:
					continue
				var e2 := _ease(clampf((g - b0) / maxf(u1 - b0, 0.05), 0.0, 1.0))
				pos[i] = from_p[i].lerp(to_p[i], e2)
				yaw[i] = lerp_angle(from_yaw[i], to_yaw[i], e2)
				kin[i] = 1
			# WHAT NO SWEEP HAS REACHED YET SLIDES ON: the palms lift, and a card they let go of
			# mid-pass runs on and stops, rather than freezing where the gather began
			for i in n:
				if kin[i] == 1:
					vel[i] = Vector2.ZERO
					spin[i] = 0.0
			held.fill(0.0)
			_wash_rub(hands, vel, spin, under, kin, dt)
			_wash_drag(hands, pos, vel, spin, held, kin, rel, dt)
			_wash_move(hands, pos, yaw, vel, spin, kin, dt)
		# A CARD IN THE AIR is where its flight has it; the jumper, down, stays where it fell
		for i in n:
			if i == lying:
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
			if flying[i] >= 0:
				var fg := _flight_ground(flights[flying[i]], t)
				pos[i] = Vector2(fg.x, fg.y)
				yaw[i] = fg.z
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
		# THE JUMPER IS THROWN as the mixing stops: the card a hard blow struck last, or the one sliding
		# fastest - over onto its face, clear of every card ([method _eject])
		if jumping and not tried and t >= mix_end:
			tried = true
			var picks: Array = []
			for i in n:
				if flying[i] >= 0 or not (over[i] as Array).is_empty():
					continue
				var hit := 0.0
				var way := vel[i]
				for b in blown:
					if int((b as Array)[1]) == i and t - float((b as Array)[0]) < 0.8 and float((b as Array)[2]) > hit:
						hit = float((b as Array)[2])
						way = (b as Array)[3]
				if way.length() < 0.02:
					way = pos[i] + Vector2(0.0, 0.01)
				picks.append([hit * 4.0 + vel[i].length() + pos[i].length(), i, way.normalized(), hit])
			picks.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
			for p in picks:
				var i := int((p as Array)[1])
				var fl := _eject(i, pos[i], yaw[i], (p as Array)[2], Vector2(0.15, 0.28), t, hash([seed, "jumper", i]), true,
					pos, yaw, flights, bool(jump.get("reversed", false)))
				if fl.is_empty():
					continue
				fl["blow"] = (p as Array)[3]
				flights.append(fl)
				jumper = i
				jumper_flight = fl
				vel[i] = Vector2.ZERO
				spin[i] = 0.0
				break
		# NOTHING PASSES THROUGH WHAT STANDS ON THE TABLE: every card goes from where it was to where
		# this step put it, and whatever it runs into stops it - it slides along it instead, at the
		# speed it really went. A thrown card's way was chosen clear.
		for i in n:
			if flying[i] >= 0 or taken[i] == 1 or (i == lying and landed[i] == 0):
				moved[i] = pos[i].distance_to(was[i])
				stirred[i] = 1 if flying[i] >= 0 or taken[i] == 1 else 0
				was[i] = pos[i]
				was_yaw[i] = yaw[i]
				continue
			# a card lying still has nowhere new to be (one just come down meets what it lies on)
			if kin[i] == 0 and vel[i] == Vector2.ZERO and spin[i] == 0.0 and landed[i] == 0 and pos[i] == was[i]:
				moved[i] = 0.0
				stirred[i] = 0
				continue
			pos[i] = _card_clear(was[i], pos[i], yaw[i])
			moved[i] = pos[i].distance_to(was[i])
			stirred[i] = 1 if moved[i] > 0.0 or yaw[i] != was_yaw[i] or landed[i] == 1 else 0
			if kin[i] == 0:
				vel[i] = (pos[i] - was[i]) * WASH_HZ
			was[i] = pos[i]
			was_yaw[i] = yaw[i]
		# WHO LIES ON WHOM: pairs that came apart forget their order; a pair that has just met lies
		# the way it met, the card sliding in on top (in the deck, the higher slot on top). A card in
		# the air, or the jumper, lies on nothing and nothing on it.
		var far2 := Vector2(CARD.x, CARD.y).length_squared()
		var blows: Array = []
		for i in n:
			var pi_: Vector2 = pos[i]
			var off_i := flying[i] >= 0 or taken[i] == 1
			for j in range(i + 1, n):
				var key := i * 64 + j
				if off_i or flying[j] >= 0 or taken[j] == 1:
					parted.erase(key)
					if rel.has(key):
						var top0 := i if int(rel[key]) > 0 else j
						(under[top0] as Array).erase(j if top0 == i else i)
						rel.erase(key)
						restacked = true
					continue
				# two cards that both lay still lie as they did - once the first step has said how
				if step > s_from and stirred[i] == 0 and stirred[j] == 0 and not parted.has(key):
					continue
				var d2 := pi_.distance_squared_to(pos[j])
				var apart := d2 > far2 or (d2 > CARD.x * CARD.x and not _cards_overlap(pi_, yaw[i], pos[j], yaw[j]))
				# ...or touching only between the steps ([method _wash_rest_at] poses between them)
				var between := apart and d2 < far2 * 1.6 and moved[i] + moved[j] > 0.004 and _cards_overlap((last_pos[i] + pi_) * 0.5,
					lerp_angle(last_yaw[i], yaw[i], 0.5), (last_pos[j] + pos[j]) * 0.5, lerp_angle(last_yaw[j], yaw[j], 0.5))
				if apart and not between:
					# a pair keeps its order the step it parts
					if rel.has(key):
						if not parted.has(key):
							parted[key] = true
							continue
						var top := i if int(rel[key]) > 0 else j
						(under[top] as Array).erase(j if top == i else i)
						rel.erase(key)
						restacked = true
					parted.erase(key)
					continue
				if between:
					parted[key] = true
				else:
					parted.erase(key)
				if rel.has(key):
					continue
				var i_top := moved[i] > moved[j] + 1e-6 if absf(moved[i] - moved[j]) > 1e-6 else false
				# A CARD CLIMBS ONE CARD, NOT A HEAP: one lying two or more above it it runs in under
				if i_top and layer[j] >= layer[i] + 2:
					i_top = false
				elif not i_top and layer[i] >= layer[j] + 2:
					i_top = true
				# a card coming down lies on what it comes down on; nothing covers the jumper
				if landed[i] != landed[j]:
					i_top = landed[i] == 1
				if i == lying or j == lying:
					i_top = i == lying
				# never over a card already above it, however far down the stack: no loops
				if i_top and _lies_on(under, j, i):
					i_top = false
				elif not i_top and _lies_on(under, i, j):
					i_top = true
				rel[key] = 1 if i_top else -1
				(under[i if i_top else j] as Array).append(j if i_top else i)
				restacked = true
				# A CARD RUN INTO IS NUDGED where the other first touches it - on its way, turned if
				# struck off its middle ([constant WASH_KNOCK]); a hard blow may throw it
				if kin[i] == 0 and kin[j] == 0:
					var top := i if i_top else j
					var bot := j if i_top else i
					var impact := (vel[top] - vel[bot]).length()
					var way := vel[top].normalized() if vel[top].length() > 1e-4 else (pos[bot] - pos[top]).normalized()
					var c := _touch(pos[bot], yaw[bot], pos[top])
					var dv := (vel[top] - vel[bot]) * float(hands["knock"])
					_wash_push(vel, spin, bot, c - pos[bot], dv)
					_wash_push(vel, spin, top, c - pos[top], -dv)
					if impact >= EJECT_SPEED * 0.6:
						blows.append([impact, top, bot, way])
						blown.append([t, bot, impact, way])
		while not blown.is_empty() and t - float((blown[0] as Array)[0]) > 1.0:
			blown.pop_front()
		# A HARD BLOW THROWS THE CARD IT STRIKES out of the spread, face down - the harder, the surer
		if not blows.is_empty() and t >= out_end and t < mix_end - EJECT_ROOM and thrown < EJECT_MOST:
			blows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
			for bl in blows:
				var impact := float((bl as Array)[0])
				if impact < EJECT_SPEED or thrown >= EJECT_MOST:
					break
				var top := int((bl as Array)[1])
				var bot := int((bl as Array)[2])
				if held[bot] > 0.2 or not (over[bot] as Array).is_empty() or _lain_on(under, bot, top) \
						or _thrown_lately(flights, bot, t):
					continue
				var die := float(hash([seed, "throw", step, bot]) & 0xFFFF) / 65535.0
				if die >= EJECT_CHANCE * clampf((impact - EJECT_SPEED) / 0.3, 0.0, 1.0):
					continue
				var fl := _eject(bot, pos[bot], yaw[bot], (bl as Array)[3], EJECT_REACH, t, hash([seed, "throw-way", step, bot]),
					false, pos, yaw, flights)
				if fl.is_empty():
					continue
				fl["blow"] = impact
				flights.append(fl)
				thrown += 1
				# it pops up onto the edge that struck it, and is off
				var key := mini(top, bot) * 64 + maxi(top, bot)
				if rel.has(key):
					(under[top] as Array).erase(bot)
					(under[bot] as Array).append(top)
					rel[key] = 1 if bot < top else -1
					restacked = true
				vel[bot] = Vector2.ZERO
				spin[bot] = 0.0
		# THE ORDER THE CARDS LIE IN: each one above the highest card it lies on
		if restacked:
			restacked = false
			layer.fill(-1)
			for i in n:
				_layer_of(i, under, layer)
			for i in n:
				(over[i] as Array).clear()
			for i in n:
				for j in under[i]:
					(over[int(j)] as Array).append(i)
		for i in n:
			var y := WASH_FLOOR + float(layer[i]) * WASH_LAYER
			if flying[i] >= 0 or taken[i] == 1:
				y = WASH_FLOOR + float(n + 1) * WASH_LAYER
			(tracks[i] as Array).append(Vector4(pos[i].x, y, pos[i].y, yaw[i]))
	# SQUARE: from wherever the pile left each card to its place in the deck - its place being where
	# it lies in the pile, so none passes through another as the deck is squared - turned the short
	# way round, whatever turns the wash gave it
	var order: Array = []
	for i in n:
		if taken[i] == 0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return layer[a] < layer[b] or (layer[a] == layer[b] and a < b))
	var last := steps - 1
	var sq0 := int(floor((dur - square) * WASH_HZ))
	for i in n:
		tracks[i] = PackedVector4Array(tracks[i] as Array)
	for slot in order.size():
		var i := int(order[slot])
		var jit3: Vector3 = _slot_jit[slot] if slot < _slot_jit.size() else Vector3.ZERO
		var tr: PackedVector4Array = tracks[i]
		var from: Vector4 = tr[mini(sq0, tr.size() - 1)]
		var to := Vector4(jit3.x, WASH_FLOOR + float(slot) * WASH_LAYER, jit3.y, from.w + wrapf(jit3.z - from.w, -PI, PI))
		for st in range(sq0, tr.size()):
			var e3 := _ease(float(st - sq0) / maxf(float(last - sq0), 1.0))
			tr[st] = from.lerp(to, e3)
		tracks[i] = tr
	var airborne := {}
	for f in flights:
		var c := int((f as Dictionary)["card"])
		if not airborne.has(c):
			airborne[c] = []
		(airborne[c] as Array).append(f)
	# EVERY CARD IS ITS OWN THICKNESS from the moment the palm comes down on the deck until it is in
	# the pile for good ([method _wash_spread_at]): the deck flattens as it is spread, and the pile
	# BUILDS TO THE DECK'S HEIGHT as it is gathered - each card thickened as it lands - or as it is
	# squared at the latest. Thickened all at once as the pile was squared, the gathered pile stood a
	# quarter of the deck's height and then "suddenly just grows by 2x or 3x" (the user, 2026-10-08).
	var thin_at := PackedFloat32Array()
	var thick_at := PackedFloat32Array()
	for i in n:
		thin_at.append(0.0)
		var piled := t_in[i] if t_in[i] > 0.0 and t_in[i] < INF else dur - square
		thick_at.append(INF if taken[i] == 1 else minf(piled, dur - square))
	return {"tracks": tracks, "out": thin_at, "in": thick_at, "order": order, "mix": Vector2(out_end, mix_end),
		"gather": gather_t0, "dur": dur, "hands": hands["log"], "flights": flights, "airborne": airborne,
		"jumper": jumper, "jumper_flight": jumper_flight}


## Whether card [param i] is in the air at [param t] in [param flights].
static func _in_flight(flights: Array, i: int, t: float) -> bool:
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) == i and t > float(fd["t0"]) and t < float(fd["t1"]):
			return true
	return false


## Whether card [param i] was thrown in the last few seconds before [param t] - a card lands and lies
## a moment before anything throws it again.
static func _thrown_lately(flights: Array, i: int, t: float) -> bool:
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) == i and t - float(fd["t1"]) < 2.0:
			return true
	return false


## Whether any card but [param but] lies on card [param i].
static func _lain_on(under: Array, i: int, but: int) -> bool:
	for c in under.size():
		if c != but and (under[c] as Array).has(i):
			return true
	return false


## A flight to carry into a plan of its own: its pose's cached rests are that plan's.
static func _flight_copy(f: Dictionary) -> Dictionary:
	var out := f.duplicate()
	out.erase("r0")
	out.erase("r1")
	return out


## The point of a card lying at [param at] turned [param yaw] nearest [param p] - where a card sliding
## in from there first touches it.
static func _touch(at: Vector2, yaw: float, p: Vector2) -> Vector2:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var d := p - at
	return at + ax * clampf(d.dot(ax), -CARD.x * 0.5, CARD.x * 0.5) + az * clampf(d.dot(az), -CARD.y * 0.5, CARD.y * 0.5)


## A CARD THROWN OUT OF THE SPREAD: card [param i], lying at [param at] turned [param yaw] (about the
## deck's place), struck along [param way] at [param t] - a hop out along the blow, [param reach]
## meters (least, most), onto the cloth and wholly in the picture, its way and where it lands clear
## of what stands and of where a card in [param flights] comes down. Face down,
## wobbling as it goes; or, the jumper ([param up]), higher and over onto its face - its top away
## from the reader, or toward them [param reversed] - and down on as few of the cards where they lie
## ([param pos], [param yaws]) as it can. A few tries round the blow: the flight
## (`{card, t0, t1, from, to, yaw0, yaw1, lie, hop, axis, up, wobble}` - `lie` the turn of the card
## as it lies when down - see [method _flight_xf]), or empty when none lands anywhere it may.
func _eject(i: int, at: Vector2, yaw: float, way: Vector2, reach: Vector2, t: float, salt: int, up: bool,
		pos: PackedVector2Array, yaws: PackedFloat32Array, flights: Array, reversed := false) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = salt
	var hop := r.randf_range(JUMP_HOP.x, JUMP_HOP.y) if up else r.randf_range(EJECT_HOP.x, EJECT_HOP.y)
	var time := r.randf_range(JUMP_FLIGHT.x, JUMP_FLIGHT.y) if up else r.randf_range(EJECT_TIME.x, EJECT_TIME.y)
	var wobble := r.randf_range(0.12, 0.35) * (1.0 if r.randf() < 0.5 else -1.0)
	var best := {}
	var best_on := 0
	for attempt in 12:
		var d := way.rotated(r.randf_range(-0.45, 0.45) * (1.0 + float(attempt) * 0.45)).normalized()
		var to := at + d * r.randf_range(reach.x, reach.y) * (1.0 - 0.04 * float(attempt))
		var h := Vector2(-d.y, d.x)
		var yaw1 := yaw + r.randf_range(-1.3, 1.3)
		var lie := yaw1
		if up:
			# turned over about h, its top lands pointing `top`: so before the turn it points top
			# mirrored in h - and it lies along `top`
			var top := Vector2(0.0, 1.0 if reversed else -1.0).rotated(r.randf_range(-0.5, 0.5))
			var m := h * (2.0 * top.dot(h)) - top
			yaw1 = yaw + wrapf(atan2(-m.x, -m.y) - yaw, -PI, PI)
			lie = atan2(-top.x, -top.y)
		if not _may_land(i, at, to, lie, up, flights):
			continue
		var fl := {"card": i, "t0": t, "t1": ceilf((t + time) * WASH_HZ - 0.001) / WASH_HZ, "from": at, "to": to,
			"yaw0": yaw, "yaw1": yaw1, "lie": lie, "hop": hop, "axis": h, "up": up, "wobble": wobble}
		if not up:
			return fl
		# the jumper comes down on the fewest cards it can - on none, where there is room
		var on := 0
		for j in pos.size():
			if j != i and pos[j].distance_to(to) < Vector2(CARD.x, CARD.y).length() \
					and _cards_overlap(pos[j], yaws[j], to, lie):
				on += 1
		if on == 0:
			return fl
		if best.is_empty() or on < best_on:
			best = fl
			best_on = on
	return best


## Whether card [param i] thrown from [param from] may come down at [param to] turned [param yaw]
## (about the deck's place): its way clear of what stands, the card wholly on the cloth and in the
## picture - the jumper ([param up]) well inside it - off everything standing, and off where any
## card in [param flights] comes down.
func _may_land(i: int, from: Vector2, to: Vector2, yaw: float, up: bool, flights: Array) -> bool:
	if not _path_clear(from, to):
		return false
	var off := Vector2(_mid.x, _mid.z)
	var card := _card_poly(to + off, yaw)
	var cloth := Rect2(-CLOTH.x * 0.5 + 0.01, -0.02 - CLOTH.y * 0.5 + 0.01, CLOTH.x - 0.02, CLOTH.y - 0.02)
	var frame := Rect2(0.1, 0.1, 0.8, 0.8) if up else Rect2(0.03, 0.03, 0.94, 0.94)
	for c: Vector2 in card:
		if not cloth.has_point(c) or Tables.sdf(_top_o, c) > -Tables.EDGE:
			return false
		var sc: Variant = CardTable.project(_cam_base, _cam.fov, Vector3(c.x, WASH_FLOOR, c.y))
		if sc == null or not frame.has_point(sc as Vector2):
			return false
	for foot in _standing:
		if _convex_overlap(card, foot, FOOT_MARGIN):
			return false
	for f in flights:
		var fd: Dictionary = f
		if int(fd["card"]) != i and _convex_overlap(card, _card_poly((fd["to"] as Vector2) + off, float(fd["lie"])), 0.01):
			return false
	return true


## Where a thrown card is over the cloth at [param t] (about the deck's place), `Vector3(x, z, its
## turn)`: fast off the blow, slowing as it comes down.
static func _flight_ground(f: Dictionary, t: float) -> Vector3:
	var u := clampf((t - float(f["t0"])) / maxf(float(f["t1"]) - float(f["t0"]), 0.01), 0.0, 1.0)
	var p := 1.0 - (1.0 - u) * (1.0 - u)
	var at := (f["from"] as Vector2).lerp(f["to"] as Vector2, p)
	return Vector3(at.x, at.y, lerpf(float(f["yaw0"]), float(f["yaw1"]), _ease(u)))


## How many cards card [param i] lies on, one on another at the deepest: its layer in the pile, kept in
## [param layer] (-1 for one not walked yet). Who lies on whom never loops, so the walk ends.
static func _layer_of(i: int, under: Array, layer: PackedInt32Array) -> int:
	if layer[i] >= 0:
		return layer[i]
	var l := 0
	for j in under[i]:
		l = maxi(l, _layer_of(int(j), under, layer) + 1)
	layer[i] = l
	return l


## Whether card [param a] lies, however far down, on card [param b] - walking down what each lies on.
static func _lies_on(under: Array, a: int, b: int) -> bool:
	var seen := {}
	var todo: Array = [a]
	while not todo.is_empty():
		var c := int(todo.pop_back())
		for d in under[c]:
			if int(d) == b:
				return true
			if not seen.has(d):
				seen[d] = true
				todo.append(d)
	return false


## THE HANDS OF A WASH: their own dice - so a wash cut short ([method _wash_fit]) has the same hands
## up to where it was cut - and their own FEEL, each wash sampled round the centers ([constant
## WASH_GRIP] and on): how firmly a palm holds, how cards drag and slide, how briskly these hands
## move. Each palm: its gesture under way, when it next comes down, its size, and how it holds
## each card this pass; and every gesture the palms made, in order ([palm, gesture]).
func _wash_hands(seed: int, t0: float, rx: float, rz: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, "wash-palms"])
	var palms: Array = []
	for h in 2:
		var grip := PackedFloat32Array()
		grip.resize(DECK_N)
		palms.append({"g": {}, "next": t0 + r.randf_range(0.0, 0.4), "pass": -1, "grip": grip,
			"size": PALM * r.randf_range(0.9, 1.12)})
	var touched := PackedFloat32Array()
	touched.resize(DECK_N)
	return {"r": r, "palms": palms, "rx": rx, "rz": rz, "touched": touched, "log": [],
		"grip": WASH_GRIP * r.randf_range(0.85, 1.15), "drag": WASH_DRAG * r.randf_range(0.8, 1.25),
		"slide": WASH_SLIDE * r.randf_range(0.85, 1.2), "spin": WASH_SPIN * r.randf_range(0.8, 1.25),
		"knock": WASH_KNOCK * r.randf_range(0.75, 1.25),
		"pace": r.randf_range(0.85, 1.15)}


## PALM [param h] for the step from [param t]. Lifted between gestures, it comes down on its next
## ([method _wash_gesture]) where the cards are. At each of [constant GRIP_AT]'s points it presses, a
## card is brought to the palm's speed - as far as the palm's friction there allows ([constant
## WASH_GRIP]): a card pressed whole goes with it, one caught at an end swings round behind it, one
## only brushed slips. Where another card lies over it the palm hardly touches it ([constant
## WASH_COVERED]), so a card half under another is pulled out by its free half. Each pass the palm
## takes hold afresh - the heel of a hand bears on some cards and skims others - so a scrub carries
## a different few each way, and what it carried out it often leaves there. A card in the air
## ([param kin]) it does not touch.
func _wash_palm(hands: Dictionary, h: int, t: float, dt: float, t_end: float, pos: PackedVector2Array,
		yaw: PackedFloat32Array, vel: PackedVector2Array, spin: PackedFloat32Array, over: Array,
		held: PackedFloat32Array, kin: PackedByteArray) -> void:
	var p: Dictionary = (hands["palms"] as Array)[h]
	var r: RandomNumberGenerator = hands["r"]
	var g: Dictionary = p["g"]
	if not g.is_empty() and t >= float(g["t1"]):
		# lifted: a moment's reach to the next place, now and then a rest
		p["next"] = float(g["t1"]) + (r.randf_range(0.5, 1.2) if r.randf() < WASH_REST else r.randf_range(0.08, 0.3))
		g = {}
		p["g"] = g
	if g.is_empty():
		if t < float(p["next"]) or t > t_end - 0.5:
			return
		g = _wash_gesture(hands, h, t, pos, t_end)
		p["g"] = g
		p["pass"] = -1
		if g.is_empty():
			p["next"] = t + 0.25
			return
		(hands["log"] as Array).append([h, g])
	var a := _gesture_at(g, t)
	var b := _gesture_at(g, t + dt)
	var press := minf(a.z, b.z)
	if press <= 0.0:
		return
	var grip: PackedFloat32Array = p["grip"]
	var k := _gesture_pass(g, t)
	if k != int(p["pass"]):
		p["pass"] = k
		for i in grip.size():
			var u := r.randf()
			# held (it goes with the palm), dragged (it slides along slower, and falls behind), or
			# brushed (it stays): how the palm's friction there compares with the cloth's
			grip[i] = 1.0 if u < 0.45 else (r.randf_range(0.1, 0.2) if u < 0.75 else r.randf_range(0.02, 0.07))
	var at := Vector2(a.x, a.y)
	var v := (Vector2(b.x, b.y) - at) / dt
	var size: Vector2 = p["size"]
	# the hand lies along the forearm, from the reader's shoulder on its side
	var along := (at - Vector2(WASH_SHOULDER.x * (-1.0 if h == 0 else 1.0), WASH_SHOULDER.y)).normalized()
	var across := Vector2(-along.y, along.x)
	var reach := size.y * 1.05 + Vector2(CARD.x, CARD.y).length() * 0.5
	var most := float(hands["grip"]) * dt / float(GRIP_AT.size())
	var touched: PackedFloat32Array = hands["touched"]
	for i in pos.size():
		if kin[i] == 1 or pos[i].distance_squared_to(at) > reach * reach:
			continue
		var ax := Vector2(cos(yaw[i]), -sin(yaw[i]))
		var az := Vector2(sin(yaw[i]), cos(yaw[i]))
		var hold := press * grip[i]
		for q in GRIP_AT:
			var o: Vector2 = q
			var rr := ax * o.x + az * o.y
			var d := pos[i] + rr - at
			var e := Vector2(d.dot(across) / size.x, d.dot(along) / size.y).length()
			if e >= 1.05:
				continue
			var w := hold * (1.0 - smoothstep(0.75, 1.05, e))
			# where another card lies over it, the palm presses that one instead
			for k2 in over[i]:
				if _card_has(pos[int(k2)], yaw[int(k2)], pos[i] + rr):
					w *= WASH_COVERED
					break
			held[i] = maxf(held[i], w)
			_wash_push(vel, spin, i, rr, v - vel[i] - Vector2(rr.y, -rr.x) * spin[i], most * w)
		if held[i] > 0.2:
			touched[i] = t


## Whether a card lying at [param at] turned [param yaw] covers the point [param pt] (x by z).
static func _card_has(at: Vector2, yaw: float, pt: Vector2) -> bool:
	var d := pt - at
	return absf(d.dot(Vector2(cos(yaw), -sin(yaw)))) <= CARD.x * 0.5 and absf(d.dot(Vector2(sin(yaw), cos(yaw)))) <= CARD.y * 0.5


## Card [param i]'s point [param rr] (from its middle) brought [param dv] nearer the speed it is
## pushed toward - no more than [param most] m/s of the card's own speed changed (a friction's
## limit; the card slips past it): it moves and turns as a flat card would, pushed there, so a push
## through its middle only moves it and one at an end turns it too.
static func _wash_push(vel: PackedVector2Array, spin: PackedFloat32Array, i: int, rr: Vector2, dv: Vector2,
		most: float = INF) -> void:
	var rp := Vector2(rr.y, -rr.x)
	var j := dv - rp * (rp.dot(dv) / (CARD_I + rr.length_squared()))
	if j.length() > most:
		j *= most / j.length()
	vel[i] += j
	spin[i] += rp.dot(j) / CARD_I


## THE CLOTH SLOWS EVERY LOOSE CARD by the same each second, as cloth does - a card let go mid-pass
## runs on a little and stops, sooner on cloth than on another card - and its turning stops too.
static func _wash_rub(hands: Dictionary, vel: PackedVector2Array, spin: PackedFloat32Array, under: Array,
		kin: PackedByteArray, dt: float) -> void:
	var slide := float(hands["slide"]) * dt
	var turn := float(hands["spin"]) * dt
	for i in vel.size():
		if kin[i] == 1 or (vel[i] == Vector2.ZERO and spin[i] == 0.0):
			continue
		var sp := vel[i].length()
		if sp > 0.0:
			var mu := slide * (1.0 if (under[i] as Array).is_empty() else WASH_ON_CARD)
			vel[i] *= maxf(0.0, sp - mu) / sp
		spin[i] = signf(spin[i]) * maxf(0.0, absf(spin[i]) - turn)


## CARDS DRAG CARDS: two lying one on the other pull each toward the other's speed where they touch
## - hard when a palm pressed the top one at the last step ([constant WASH_DRAG], [param held]), so a
## card scrubbed across the spread drags and turns what it passes over and leaves a wake of cards
## knocked askew. Before the palms, so what a palm holds goes its way whatever lies under it.
func _wash_drag(hands: Dictionary, pos: PackedVector2Array, vel: PackedVector2Array, spin: PackedFloat32Array,
		held: PackedFloat32Array, kin: PackedByteArray, rel: Dictionary, dt: float) -> void:
	var far := Vector2(CARD.x, CARD.y).length()
	var drag: Vector2 = hands["drag"]
	for key in rel:
		var i := int(key) >> 6
		var j := int(key) & 63
		if kin[i] == 1 or kin[j] == 1:
			continue
		if vel[i] == Vector2.ZERO and vel[j] == Vector2.ZERO and spin[i] == 0.0 and spin[j] == 0.0:
			continue
		var top := i if int(rel[key]) > 0 else j
		var bot := j if top == i else i
		var k := (drag.x + drag.y * held[top]) * (1.0 - clampf(pos[top].distance_to(pos[bot]) / far, 0.0, 1.0))
		if k <= 0.0:
			continue
		var c := (pos[top] + pos[bot]) * 0.5
		var rt := c - pos[top]
		var rb := c - pos[bot]
		var dv := ((vel[top] + Vector2(rt.y, -rt.x) * spin[top]) - (vel[bot] + Vector2(rb.y, -rb.x) * spin[bot])) \
			* (0.5 * (1.0 - exp(-k * dt)))
		_wash_push(vel, spin, bot, rb, dv)
		_wash_push(vel, spin, top, rt, -dv)


## A HEAP SLUMPS: a loose card lying [constant SLUMP_FROM] or more cards up creeps off the cards
## under it, away from their middle, the higher the faster ([constant SLUMP]) - a heap of real cards
## spreads under the hands, and a stiff card balanced on one tips steeply.
static func _wash_slump(pos: PackedVector2Array, under: Array, layer: PackedInt32Array, held: PackedFloat32Array,
		kin: PackedByteArray, dt: float) -> void:
	for i in pos.size():
		if kin[i] == 1 or held[i] > 0.2 or layer[i] < SLUMP_FROM or (under[i] as Array).is_empty():
			continue
		var c := Vector2.ZERO
		for j in under[i]:
			c += pos[int(j)]
		c /= float((under[i] as Array).size())
		var away := pos[i] - c
		if away.length() < 1e-4:
			continue
		pos[i] += away.normalized() * SLUMP * float(layer[i] - SLUMP_FROM + 1) * dt


## THE CARDS MOVE, one step: none faster than a hand ([constant HAND_SPEED]), and one going out past
## the spread's edge is turned back, the harder the farther out, as a hand would.
func _wash_move(hands: Dictionary, pos: PackedVector2Array, yaw: PackedFloat32Array, vel: PackedVector2Array,
		spin: PackedFloat32Array, kin: PackedByteArray, dt: float) -> void:
	var rx := float(hands["rx"])
	var rz := float(hands["rz"])
	for i in pos.size():
		if kin[i] == 1 or (vel[i] == Vector2.ZERO and spin[i] == 0.0):
			continue
		var sp := vel[i].length()
		if sp > HAND_SPEED:
			vel[i] *= HAND_SPEED / sp
		spin[i] = clampf(spin[i], -WASH_TURN_MAX, WASH_TURN_MAX)
		var q := Vector2(pos[i].x / rx, (pos[i].y + 0.01) / rz)
		var l := q.length()
		if l > 1.0:
			var nrm := Vector2(q.x / rx, q.y / rz).normalized()
			var vn := vel[i].dot(nrm)
			if vn > 0.0:
				vel[i] -= nrm * vn * clampf((l - 1.0) / 0.15, 0.0, 1.0)
		pos[i] += vel[i] * dt
		yaw[i] += spin[i] * dt


## A PALM'S NEXT GESTURE, from [param t]. It comes down on a card - mostly one on its own side of the
## spread, and one the hands have left alone a while - and the best of a few tries keeps clear of
## the other palm ([constant WASH_APART]). How often each ([constant WASH_GESTURES]):
##
##   scrub   passes back and forth, each across a good part of the spread ([constant WASH_SCRUB]),
##           its line turning and drifting a little between them
##   swirl   wide rounds, often the other way round from the other palm's
##   fetch   out to the card lying farthest out, and back through the middle with it
##
## A scrub or a fetch is its turning points `pts` at times `ts`, pressed `press` on each pass; a
## swirl its middle `c` (drifting `v`), radii `a` and `b` turned `rot`, where round it `ph`, how
## fast `om` and how hard `press`. Empty when there is no time left for one.
func _wash_gesture(hands: Dictionary, h: int, t: float, pos: PackedVector2Array, t_end: float) -> Dictionary:
	var r: RandomNumberGenerator = hands["r"]
	var rx := float(hands["rx"])
	var rz := float(hands["rz"])
	var pace := float(hands["pace"])
	var side := -1.0 if h == 0 else 1.0
	var touched: PackedFloat32Array = hands["touched"]
	var other: Dictionary = ((hands["palms"] as Array)[1 - h] as Dictionary)["g"]
	var best := {}
	var best_apart := -1.0
	for attempt in 6:
		# where it comes down
		var ws := PackedFloat32Array()
		var total := 0.0
		for i in pos.size():
			var w := (1.0 / (1.0 + exp(-side * pos[i].x / 0.07)) + 0.08) * (0.3 + clampf((t - touched[i]) / 2.5, 0.0, 1.0))
			ws.append(w)
			total += w
		var pick := r.randf() * total
		var land := pos[pos.size() - 1]
		for i in pos.size():
			pick -= ws[i]
			if pick <= 0.0:
				land = pos[i]
				break
		# the card lying farthest out, for a fetch
		var stray := -1
		var out_most := WASH_STRAY
		for i in pos.size():
			var k := Vector2(pos[i].x / rx, (pos[i].y + 0.01) / rz).length() * (1.15 if pos[i].x * side > 0.0 else 1.0)
			if k > out_most:
				out_most = k
				stray = i
		var u := r.randf() * (float(WASH_GESTURES["scrub"]) + float(WASH_GESTURES["swirl"]) + float(WASH_GESTURES["fetch"]))
		var g := {}
		if u < float(WASH_GESTURES["swirl"]):
			var a := rx * r.randf_range(0.28, 0.5)
			var b := rz * r.randf_range(0.5, 0.85)
			var rot := r.randf_range(-0.4, 0.4)
			var om := r.randf_range(3.2, 5.5) * pace
			if String(other.get("kind", "")) == "swirl" and r.randf() < 0.65:
				om *= -signf(float(other["om"]))
			elif r.randf() < 0.5:
				om = -om
			var ph := r.randf() * TAU
			var c := land - Vector2(cos(ph) * a, sin(ph) * b).rotated(rot)
			c = Vector2(clampf(c.x, -rx * 0.92 + a, rx * 0.92 - a), clampf(c.y, -rz * 0.92 + b - 0.01, rz * 0.92 - b - 0.01))
			var t1 := minf(t + r.randf_range(0.75, 1.5) * TAU / absf(om), t_end - 0.1)
			if t1 - t < 0.5:
				continue
			g = {"kind": "swirl", "t0": t, "t1": t1, "c": c, "v": Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.0, 0.02),
				"a": a, "b": b, "rot": rot, "ph": ph, "om": om, "press": r.randf_range(0.6, 1.0)}
		else:
			var pts := PackedVector2Array()
			var ts := PackedFloat32Array([t])
			var press := PackedFloat32Array()
			if u < float(WASH_GESTURES["swirl"]) + float(WASH_GESTURES["fetch"]) and stray >= 0:
				# FETCH: onto the stray's outer edge, in through the middle and on a little past it, and
				# now and then a lighter half-pass back
				var p0 := pos[stray] + (pos[stray] + Vector2(0.0, 0.01)).normalized() * 0.02
				var p1 := _wash_into(Vector2(r.randf_range(-0.35, 0.35) * rx, r.randf_range(-0.35, 0.35) * rz - 0.01), rx, rz, 0.9)
				p1 = _wash_into(p1 + (p1 - p0).normalized() * r.randf_range(0.0, 0.08), rx, rz, 0.92)
				pts.append(p0)
				pts.append(p1)
				press.append(r.randf_range(0.8, 1.0))
				if r.randf() < 0.4:
					pts.append(p1.lerp(p0, r.randf_range(0.35, 0.6)))
					press.append(r.randf_range(0.4, 0.7))
			else:
				# SCRUB: from the card, toward somewhere a good way across the spread, then back and
				# forth along that line - turning and drifting a little each pass
				var p := _wash_into(land + Vector2(r.randf_range(-0.025, 0.025), r.randf_range(-0.02, 0.02)), rx, rz, 0.92)
				var to := _wash_into(Vector2(r.randf_range(-1.0, 1.0) * rx, r.randf_range(-1.0, 1.0) * rz - 0.01), rx, rz, 0.9)
				var dir := (to - p).normalized() if p.distance_to(to) > 0.08 else Vector2.from_angle(r.randf() * TAU)
				var span := r.randf_range(WASH_SCRUB.x, WASH_SCRUB.y)
				pts.append(p)
				for pass_ in r.randi_range(2, 6):
					var d := dir.rotated(r.randf_range(-0.3, 0.3)) * (1.0 if pass_ % 2 == 0 else -1.0)
					var q := _wash_into(p + d * span * r.randf_range(0.75, 1.1) + Vector2(-d.y, d.x) * r.randf_range(-0.035, 0.035), rx, rz, 0.92)
					if p.distance_to(q) < 0.06:
						break
					pts.append(q)
					press.append(r.randf_range(0.6, 1.0))
					p = q
			# each pass in its own time, at a hand's pace for its length
			for k in range(1, pts.size()):
				var tt := ts[k - 1] + pts[k - 1].distance_to(pts[k]) / (r.randf_range(0.32, 0.58) * pace)
				if tt > t_end - 0.1:
					break
				ts.append(tt)
			if ts.size() < 2:
				continue
			pts.resize(ts.size())
			press.resize(ts.size() - 1)
			g = {"kind": "scrub", "t0": t, "t1": ts[ts.size() - 1], "pts": pts, "ts": ts, "press": press}
		var apart := _palms_apart(g, other)
		if apart > best_apart:
			best = g
			best_apart = apart
		if apart >= WASH_APART:
			break
	return best


## Gesture [param g] at [param t]: (x, z, how hard it presses - nothing outside it, coming down and
## lifting over [constant WASH_TOUCH]). A scrub's pass eases out to a stop at each end.
static func _gesture_at(g: Dictionary, t: float) -> Vector3:
	var t0 := float(g["t0"])
	var t1 := float(g["t1"])
	if t < t0 or t > t1:
		return Vector3.ZERO
	var touch := clampf((t - t0) / WASH_TOUCH, 0.0, 1.0) * clampf((t1 - t) / WASH_TOUCH, 0.0, 1.0)
	if String(g["kind"]) == "swirl":
		var u := t - t0
		var ph := float(g["ph"]) + float(g["om"]) * u
		var p := (g["c"] as Vector2) + (g["v"] as Vector2) * u + Vector2(cos(ph) * float(g["a"]), sin(ph) * float(g["b"])).rotated(float(g["rot"]))
		return Vector3(p.x, p.y, touch * float(g["press"]))
	var ts: PackedFloat32Array = g["ts"]
	var pts: PackedVector2Array = g["pts"]
	var k := _gesture_pass(g, t)
	var p2 := pts[k].lerp(pts[k + 1], _ease((t - ts[k]) / maxf(ts[k + 1] - ts[k], 0.001)))
	return Vector3(p2.x, p2.y, touch * (g["press"] as PackedFloat32Array)[k])


## Which pass of gesture [param g] is under way at [param t]: a scrub's leg, a swirl's half-round.
static func _gesture_pass(g: Dictionary, t: float) -> int:
	if String(g["kind"]) == "swirl":
		return int(absf(float(g["om"])) * (t - float(g["t0"])) / PI)
	var ts: PackedFloat32Array = g["ts"]
	var k := 0
	while k < ts.size() - 2 and t > ts[k + 1]:
		k += 1
	return k


## How near gesture [param g] comes to the other palm's [param other] while both press (INF when
## they never do at once).
static func _palms_apart(g: Dictionary, other: Dictionary) -> float:
	if g.is_empty() or other.is_empty():
		return INF
	var least := INF
	var t := maxf(float(g["t0"]), float(other["t0"]))
	var t1 := minf(float(g["t1"]), float(other["t1"]))
	while t <= t1:
		var a := _gesture_at(g, t)
		var b := _gesture_at(other, t)
		if a.z > 0.0 and b.z > 0.0:
			least = minf(least, Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)))
		t += 0.1
	return least


## [param p] brought in to the spread's edge, scaled by [param k], when it lies out past it.
static func _wash_into(p: Vector2, rx: float, rz: float, k: float) -> Vector2:
	var q := Vector2(p.x / rx, (p.y + 0.01) / rz)
	var l := q.length()
	if l <= k:
		return p
	q *= k / l
	return Vector2(q.x * rx, q.y * rz - 0.01)


## A card just landed on the deck, not yet squared.
func _messy(j: int, seed: int) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, j, "messy"])
	var xf := _rest_xf(j)
	xf.origin += Vector3(rng.randf_range(-0.003, 0.003), 0.0, rng.randf_range(-0.003, 0.003))
	xf.basis = Basis(Vector3.UP, rng.randf_range(-0.07, 0.07)) * xf.basis
	return xf


static func _ease(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# --- the title -------------------------------------------------------------------------------------------

## The channel's name over the table while the intro holds, gone as the reading opens (the deck's
## shuffle, the box's opening) - and only then: the reading ends on the table fading to black, not
## on the name again.
func _title_alpha(t: float) -> float:
	var ts := float(_times()["opening"])
	var a := clampf((t - 0.3) / 1.1, 0.0, 1.0)
	if ts < INF:
		a *= 1.0 - clampf((t - (ts - 0.6)) / 0.9, 0.0, 1.0)
	elif not _sched.is_empty():
		a = 0.0
	return a


## THE OUTRO: once the voice has said its last word, the table fades to black - a beat after it,
## and black exactly as the outro's silence runs out (the take's own tail in a render, the
## Director's outro live). A function of show time like everything else, so a live reading, a
## scrub and the export fade alike. 1 until then.
func _end_fade(t: float) -> float:
	var total := (_parse.get("spoken", PackedStringArray()) as PackedStringArray).size()
	var last := _follow.known_last()
	if total == 0 or last < total - 1:
		return 1.0
	var outro := maxf(Spectrum.tail if Spectrum.bookend_baked else Director.outro_hold, 0.0)
	var beat := minf(0.8, outro * 0.15)
	return 1.0 - _ease((t - (_follow.st1[last] + beat)) / maxf(outro - beat, 0.05))


## THE INTRO'S BLUR: the whole stage read back through [constant INTRO_SHADER], drawn over the table
## and under the name - and not drawn at all while it is off.
class IntroBlur:
	extends Node2D

	var _mat := ShaderMaterial.new()

	func _init(shader: Shader) -> void:
		_mat.shader = shader
		material = _mat
		visible = false

	## The blur's sigma, as a share of the frame's height; 0 takes it off.
	func set_sigma(sigma: float) -> void:
		_mat.set_shader_parameter("sigma", sigma)
		visible = sigma > 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)


class TitleCard:
	extends Node2D

	## A shade behind the type, at its middle (it fades to nothing above and below), and THE HALO
	## round every letter: rings of the shade, each `x` of the type's size wide at `y` alpha, soft
	## from the outside in.
	const BAND := 0.32
	const HALO := [Vector2(0.24, 0.06), Vector2(0.16, 0.08), Vector2(0.1, 0.12), Vector2(0.06, 0.18), Vector2(0.03, 0.3)]

	var channel := ""
	## A line under the name in the italic face.
	var byline := ""
	var face: Font = null
	var italic: Font = null
	var alpha := 0.0
	## The name's color: the set dresser's, chosen to stand out from this table ([method CardTable.title_ink]).
	var ink := CardTable.color(CardTable.TITLE_INK)
	var _lay := {}
	var _lay_key := ""

	func _draw() -> void:
		if alpha <= 0.001 or face == null or channel.is_empty():
			return
		var vp := get_viewport_rect().size
		var key := "%s|%s|%s" % [channel, byline, str(vp)]
		if key != _lay_key:
			_lay_key = key
			_lay = CardTable.title_layout(face, italic, channel, byline, vp)
		var shade := CardTable.title_shade(ink)
		# A SHADE BEHIND THE TYPE, soft above and below: the cloth is whatever the episode painted
		var box: Rect2 = _lay["box"]
		var reach := box.size.y * 0.5 + vp.y * 0.12
		_band(Rect2(0.0, box.get_center().y - reach, vp.x, reach * 2.0), shade)
		for l in _lay["lines"]:
			var d: Dictionary = l
			var f: Font = italic if bool(d["italic"]) else face
			var size := int(d["size"])
			var at := Vector2(0.0, float(d["y"]))
			for h in HALO:
				draw_string_outline(f, at, String(d["text"]), HORIZONTAL_ALIGNMENT_CENTER, vp.x, size,
					maxi(int(size * (h as Vector2).x), 1), Color(shade, (h as Vector2).y * alpha))
			draw_string(f, at, String(d["text"]), HORIZONTAL_ALIGNMENT_CENTER, vp.x, size, Color(ink, alpha))

	## A band of [param shade] across [param r], clear at its top and bottom edges and [constant BAND]
	## at its middle - a raised cosine, drawn as strips whose corners carry it, so it has no steps.
	func _band(r: Rect2, shade: Color) -> void:
		var n := 12
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var a0 := Color(shade, BAND * alpha * (0.5 - 0.5 * cos(TAU * u0)))
			var a1 := Color(shade, BAND * alpha * (0.5 - 0.5 * cos(TAU * u1)))
			var y0 := r.position.y + r.size.y * u0
			var y1 := r.position.y + r.size.y * u1
			draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)]),
				PackedColorArray([a0, a0, a1, a1]))

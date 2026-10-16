extends Medium
class_name TableMedium

## TableMedium - a card reading at a table, seen from the reader's chair.
##
## The Cards mode's own medium (its row of [constant Medium.REGISTRY] names the mode): the episode's cloth on a table,
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
## THE DECK: a mesh for each of its cards, this thick - as many as the episode's deck holds
## ([method _deck_count]: the agents decide it; 78 stand about 3 cm). A WASH SPREADS EVERY ONE OF
## THEM, so the pile it gathers builds to the deck's height card by card (the user, 2026-10-14: the
## gathered deck kept "slowly growing in a strange way... as if the number of cards on the table/in
## the wash does not match the number of cards needed in the deck when stacked" - it had been 26
## meshes standing for three cards each, spread as 26 single cards that swelled fourfold on the
## pile). A deck card is a spread card and the gap above it ([constant TableShuffle.WASH_LAYER]).
const DECK_T := 0.0004
## The deck of an episode that says nothing of its size (one made up, as a gate's is): a tarot's.
const DECK_FALLBACK := 78
## How much table a laid card leaves between itself and the deck.
const DECK_CLEAR := TablePositions.DECK_CLEAR
## The table every episode had before (width, thickness, depth), centered at TABLE_Z, its top at y = 0
## ([constant Tables.DEFAULT_TOP]; the room's old placement still measures from its far edge); the
## cloth on it.
const TABLE := Vector3(1.9, 0.05, 0.85)
const TABLE_Z := 0.02
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
const PAGE := Vector2(0.088, 0.012)
const PAGE_H := 0.126
const VFOV := CardTable.VFOV

## THE PHASES of each action, in its own seconds. They sum to [CardReading]'s rests, which is
## what the voice waits: DRAW = 3.4, LAY = 1.7, JUMP = 5.0.
const SQUARE := 0.45          # the deck squares before a card leaves it
const RISE_END := 2.8         # ...and comes up to be shown
const LAY_END := 1.7
## A JUMPER FLIES OUT OF A SHUFFLE (2026-10-05: "that jump should probably happen during a shuffle -
## not when the cards are just sitting there on the table, doing nothing"): its action opens with
## one more riffle, and the card springs off the top of a half while the halves are falling. The
## riffle, the flight, the card lying there, its rise, its page.
const JUMP_RIFFLE := 2.4
const JUMP_FLY := Vector2(1.15, 2.25)
const JUMP_RISE := 4.3
## A CARD DEALT (TableActions.DEAL): off its source and turned over, then down into its place.
const DEAL_TURN := 0.9
const DEAL_END := 1.9
## A WATERFALL (TableActions.FAN): each card leaves a beat behind the one before (TableActions.FAN_EACH)
## and slides out to its place, turning face up as it goes.
const FAN_MOVE := 1.45
## A CARD SHOWN from where it lies (TableActions.SHOW): it lifts and comes up; its page opens.
const SHOW_RISE := 1.1
## A card TURNED where it lies (TableActions.TURN, FLIP): the turn's own seconds.
const TURN_END := 0.8
const FLIP_END_LAY := 1.1
## How many different cards the unseen cards of one printing are printed as ([method _unseen_fronts],
## [method _blank_backs]) when nobody wrote them, and the most of the deck's own cards they are printed
## as when the episode lists them.
const BLANKS := 3
const WRITTEN := 6
const SEARCH_LOOKS := 3
## A SPREAD CARD IS A REAL CARD'S THICKNESS (the user: cards should rest "with a gentle tilt"): the
## plan's chains of cards lying on cards run many deep, and every millimeter a card stands on tips
## the card lying across it. The cloth's top, how far over it a spread card lies, a spread card's
## thickness, and the hair between a card and the one under it (so two faces never fight for one
## depth).
const CLOTH_TOP := Tables.LAYERS_UNDER
## An episode whose first card is a jumper washes the deck into it this often: its wash is held back
## to begin this long before the jumper is reckoned to come (from the script's words at a steady
## pace) and to run this long past it - a voice is never quite the pace reckoned.
const JUMPER_WASH := 0.5
const JUMPER_WASH_LEAD := 24.0
const JUMPER_WASH_SLACK := 16.0
## The first card's PUSH (TableActions.PUSH): the deck squares, then slides to its side this long.
const PUSH_SLIDE := 0.85
const TURN := Vector2(0.6, 0.95)
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
## the least share of a thing's picture the frame may keep when it cuts it. Lit things first seek a
## whole view; when that fails, their body may cross a side edge while every flame stays visible.
const AIM_WANDER := Vector2(0.08, 0.05)
const EDGE_PUSH := 0.2
const SEEN_LEAST := 0.55
## A THING ACROSS A CLOTH'S EDGE - half on the cloth, half on the bare top - reads as set down
## carelessly (the user, 2026-10-08), unless it is large: a book, a tray may lie across a hem. So a
## spot whose foot crosses a layer's edge scores this much worse (as many meters from its aim, over 4),
## and a thing wider than STRADDLE_BIG only a third of it.
const STRADDLE := 0.5
const STRADDLE_BIG := 0.18
## THE READER'S WORKSPACE (the user, 2026-10-10: a low thing stood "at the bottom and in the middle -
## just in front of the speaker ... when there are open areas elsewhere"): the strip of the cloth
## nearest the reader, in front of where the cards are shuffled and laid, is where their hands work.
## A spot there scores this much worse (as many meters from its aim, over 4), a low thing's too - the
## near ground a low thing may lie on ([method _stand]) is for a crowded table, not the first choice.
## Soft: a table with no other room still stands its thing there. WORKSPACE_HALF is the strip's
## half-width from the middle of the reading; it begins where [method _keep_out]'s middle ends.
const WORKSPACE := 2.0
const WORKSPACE_HALF := 0.25
const WORKSPACE_FROM := 0.14
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
const LUM_RECT := CardTable.SEEN_RECT
const LUM_GRID := CardTable.SEEN_GRID
## The key candle's light, the least a candle must be allowed to be the key, and every other
## candle's.
const KEY_ENERGY := 1.5
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
## Lead and tail around each action group, as the tablet's: a beat after the last word before
## the cards move, and they are still a beat before the next word.
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
// A FLAME BENDS, it does not tip: its foot stays on the wick and its tip leans furthest, licking from
// side to side as the draft finds it. `bend` is how far the tip has leaned (meters, across the quad), `lick`
// how far a ripple swings it and `phase` where the ripple is - all planned on the CPU from show time.
uniform float bend = 0.0;
uniform float lick = 0.0;
uniform float phase = 0.0;
void vertex() {
	float h = clamp(VERTEX.y / 0.03 + 0.5, 0.0, 1.0);
	VERTEX.x += (bend + lick * sin(phase - h * 4.5)) * h * h;
}
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
## WHAT THE EPISODE DECIDED ([TablePlan]): written when it loads, read by everything after.
var _plan := TablePlan.new()
var _source := ""                   # the reading's script
var _follow := ReadingFollower.new()
var _sched: Array = []
var _built_n := -1
var _key := ""
var _now := 0.0
var _backs := {}                      # printing name ("" the deck's own) -> {vp, canvas, mat}: each printing's back
var _printed: Array = []              # per drawn card, when its text is on its back: {vp, canvas, mat}

var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
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
var _props: Node3D
var _probe: ReflectionProbe
var _probe_nudge := 1.0
var _lights: Array = []             # a light per lit thing: {light, base, light_base, energy, flames: [{mesh, base, flicker, glow}]}
var _lum := PackedFloat32Array()      # the table's linear luminance where candles may stand (LUM_RECT); empty: not yet built
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
var _table_mt := -2                   # the table file's time when it was last built (-1: none)
var _stage_was := {}                  # the stage's own settings, given back on leaving it
var _deck: Array = []               # a MeshInstance3D per deck card (TablePlan.deck_n), bottom first
var _rummage_card: MeshInstance3D    # a search's card where the box keeps none for it (a tin's flat deck, one pile)
var _cards: Array = []              # one MeshInstance3D per drawn card
var _faces: Array = []              # one SubViewport per drawn card's face
var _face_canvas: Array = []
var _face_mats: Array = []
var _back_vp: SubViewport
var _back_canvas: CardFaces.Face
var _back_mat: ShaderMaterial
var _unseen_mat: StandardMaterial3D   # a deck card's face, never shown
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
var _cur_base := Vector3.ZERO       # where it is at the moment being posed (see _deck_at)
var _all_events: Array = []         # every card's timeline, as [method _times] last made it ([method _rest_lift])
var _laps: Array = []               # per card: the cards its place overlaps ([method _laps_of]), for [member _laps_for]
var _laps_for: Array = []
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
## BUILT ASIDE, on a worker thread ([method TablePreview._stand]): its long loops then [method _breathe]
var aside := false
var _breaths := 0
var _wind := {}                     # the table's wind (Winds.plan): its light's, or still air - shared by the light and the air


## THE SHUFFLE is a part of its own ([TableShuffle]): every move the deck makes between readings
## and where each card is during one. This file asks it seven things (`shuffle_xf`, `move_at`,
## `deck_turns`, `riffle`, `wash`, `wash_jump`, `sweeps`) and hands it itself to read from.
var _shuffles := TableShuffle.new()


func _init() -> void:
	_box_part.medium = self
	_light_part.medium = self
	_card_poses.medium = self
	_shuffles.medium = self


## WHERE EACH CARD IS at a moment of the show is a part of its own ([TableCardPose]): no state,
## read off the plan, the schedule and the box; [method _pose] applies what it answers.
var _card_poses := TableCardPose.new()


## THE LIGHT ON THE TABLE is a part of its own ([TableLight]): the flames, their glow and heat, the
## rig and its key, the contact shadows.
var _light_part := TableLight.new()


## THE BOX THE DECK IS KEPT IN is a part of its own ([TableBox]): built once per episode, holding
## the box, its files and what a search looks at.
var _box_part := TableBox.new()


# --- mount -----------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	# EDGES: 4x multisampling on the stage, and a bigger atlas. The first two
	# quadrants hold a high-resolution shadow each; the others hold four each so
	# four candles and the lamp can all cast. Given back when the table leaves.
	_stage_was = {"msaa": st.msaa_3d, "atlas": st.positional_shadow_atlas_size,
		"quad": st.positional_shadow_atlas_quad_0, "quad1": st.positional_shadow_atlas_quad_1,
		"quad2": st.positional_shadow_atlas_quad_2, "quad3": st.positional_shadow_atlas_quad_3}
	st.msaa_3d = Viewport.MSAA_4X
	st.positional_shadow_atlas_size = 4096
	st.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	st.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	st.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	st.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
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
	_back_canvas = CardFaces.Face.new()
	_back_canvas.back = true
	_back_vp = CardFaces.viewport(self, _back_canvas, CardFaces.FACE_PX)
	_back_mat = _foil_material(_back_vp.get_texture())
	_back_mat.set_shader_parameter("lift", 0.06)
	_unseen_mat = StandardMaterial3D.new()
	_unseen_mat.albedo_color = Color(0.92, 0.9, 0.85)
	_rummage_card = MeshInstance3D.new()
	_rummage_card.visible = false
	_root3.add_child(_rummage_card)

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
		stage.positional_shadow_atlas_quad_1 = _stage_was["quad1"]
		stage.positional_shadow_atlas_quad_2 = _stage_was["quad2"]
		stage.positional_shadow_atlas_quad_3 = _stage_was["quad3"]


func on_stage_resized(_size: Vector2) -> void:
	if _blur != null:
		_blur.queue_redraw()
	if _title != null:
		_title.queue_redraw()


func advance(_features, delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	_ensure_doc()
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0
		_poll_pictures()
	if not _plan.parse.is_empty() and _subs != null and is_instance_valid(_subs):
		_follow.extend(_subs.words)
		var n := _follow.map.size()
		if n != _built_n:
			_built_n = n
			_sched = _follow.place(_plan.parse["actions"], maxf(feed.intro_hold, 0.6), LEAD, TAIL)
	# up from black as the session starts, down to it after the last word - the table owns its
	# bookend, so the Director's whole-take fade is not used; an outro mark's fade still is
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0) * _end_fade(_now) * feed.live_fade, 0.0, 1.0)
	_pose(_now)
	_tick_focus(_now)
	_tick_camera(_now)
	_light_part.tick_props(_now)
	_light_part.tick(_now)
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
	# A NEW EPISODE IS A NEW PLAN, decided below and in _build_episode in one fixed order, and read
	# by everything after (TablePlan); nothing of the last one's survives into it.
	_plan = TablePlan.new()
	_plan.pay = pay
	_source = src
	_plan.parse = CardReading.parse(src) if not src.is_empty() else {}
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	_plan.look = CardTable.sanitize_look(plan.get("look", {}) if plan.get("look") is Dictionary else {})
	_plan.seed_value = int(pay.get("seed", 0))
	_foil = float(_plan.look.get("foil", 0.6))
	_plan.staging = CardTable.staging_of(plan)
	_plan.cards_from = String(_plan.parse.get("source", _plan.staging["source"])) if not _plan.parse.is_empty() else String(_plan.staging["source"])
	_plan.alone = String(_plan.staging["text"]) != "booklet"
	_plan.deck_n = _deck_count(pay)
	# A READING STARTED MID-WAY (a scrub) begins where its first words are: everything before them
	# happened long ago, spaced as a voice would have said it, so the cards drawn by then are
	# already down (or up) on the first frame
	var spoken: PackedStringArray = _plan.parse.get("spoken", PackedStringArray()) if not _plan.parse.is_empty() \
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
	print("ghost: card table - %s #%d, %d cards, %d actions, %d things (built in %d ms)" % [String(pay.get("show", "?")), _plan.seed_value,
		(pay.get("cards", []) as Array).size(), (_plan.parse.get("actions", []) as Array).size(), _things.size(),
		Time.get_ticks_msec() - t0])


## HOW MANY CARDS THE DECK HOLDS, as the episode says - the table never picks a number of its own
## (the user, 2026-10-14: "The agents define how many cards a deck will use"): what the draw was
## shuffled from (`deck_n`, [method CardProducer._make_draw]; for an episode drawn before the draw
## counted it, the deck its brief lists, [method EpisodeCard._table_doc]), else the deck the producer
## chose, else a box's drawn and left-in cards - and never fewer than the cards drawn. An episode that
## says none of these (a made-up one) holds [constant DECK_FALLBACK].
static func _deck_count(pay: Dictionary) -> int:
	var drawn: int = (pay.get("cards", []) as Array).size() if pay.get("cards") is Array else 0
	var n := int(pay.get("deck_n", 0))
	var plan: Dictionary = pay.get("plan", {}) if pay.get("plan") is Dictionary else {}
	if n <= 0 and plan.get("deck") is Array:
		n = (plan["deck"] as Array).size()
	if n <= 0 and pay.get("left") is Array and not (pay["left"] as Array).is_empty():
		n = drawn + (pay["left"] as Array).size()
	return maxi(n if n > 0 else DECK_FALLBACK, maxi(drawn, 1))


## Each spoken word's time along the reading as a voice would say it - the past a mid-way start
## is replayed in: the intro, then a word every 0.4 s, and each action's own rest.
func _estimated_times(n: int) -> PackedFloat32Array:
	var rests := {}
	for a in _plan.parse.get("actions", []):
		var k := int((a as Dictionary)["after"])
		rests[k] = float(rests.get(k, 0.0)) + float((a as Dictionary)["dur"]) + LEAD + TAIL
	var out := PackedFloat32Array()
	out.resize(n)
	var t := maxf(feed.intro_hold, 0.0)
	for j in n:
		t += float(rests.get(j, 0.0))
		out[j] = t
		t += 0.4
	return out


## Everything sampled from the episode's seed, and the episode's own cards.
func _build_episode() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_plan.seed_value, "tarot-table"])
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
	_plan.cam_base = lay["camera"]
	_cam.transform = _plan.cam_base
	_cam.fov = float(lay["fov"])
	# THE LIGHT: the look's own, from above and to one side
	var lc := CardTable.color(String((_plan.look.get("light", {}) as Dictionary).get("color", "#ffb36b")))
	_lamp.light_color = Color(1, 1, 1).lerp(lc, 0.55)
	_lamp.position = lay["lamp"]
	# AIMED BY ITS OWN TRANSFORM, what look_at does under _root3 (never moved): look_at needs the tree, and
	# the set dresser's table is built out of it, on a worker thread ([method TablePreview._stand])
	var lamp_scale := _lamp.scale
	_lamp.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -0.1) - _lamp.position, Vector3.UP), _lamp.position)
	_lamp.scale = lamp_scale
	_lamp.light_energy = float(lay["lamp_energy"])
	_plan.lamp_base = _lamp.light_energy
	var pal: Array = _plan.look.get("palette", CardTable.FALLBACK_PALETTE)
	var dark := CardTable.color(String(pal[0]))
	_env.background_color = dark.darkened(0.6)
	_env.ambient_light_color = Color(0.5, 0.5, 0.5).lerp(dark.lightened(0.4), 0.35)
	_plan.ambient = {"color": _env.ambient_light_color, "energy": 0.18}
	_fill.light_color = Color(0.75, 0.8, 1.0) if String((_plan.look.get("light", {}) as Dictionary).get("warmth", "warm")) == "warm" else lc
	# THE DECK, squared where the reader keeps it
	_deck_base = lay["deck"]
	# SHUFFLED IN THE MIDDLE, in front of the reader, and pushed to its side before the first card
	_plan.mid = lay["mid"]
	_cur_base = _plan.mid
	_plan.slot_jit = []
	for i in _plan.deck_n + 1:
		_plan.slot_jit.append(Vector3(rng.randf_range(-0.0007, 0.0007), rng.randf_range(-0.0007, 0.0007),
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
	var keep_dir := String(_plan.pay.get("dir", "")) + "/"
	for k in _textures.keys():
		if not String(k).begins_with(keep_dir):
			_textures.erase(k)
			_mtimes.erase(String(k))
	var cards: Array = _plan.pay.get("cards", [])
	_build_backs(cards)
	for i in cards.size():
		var canvas := CardFaces.Face.new()
		# EACH CARD IN ITS OWN PRINTING: a box may mix sets, each with its own front and back
		canvas.look = CardTable.look_of(_plan.look, cards[i])
		canvas.card = cards[i]
		canvas.details = String(_plan.staging["text"]) == "front"
		canvas.seed = _plan.seed_value
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("window", _face_window(canvas))
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
	_back_canvas.look = _plan.look
	_back_vp.size = CardFaces.face_px(_plan.look)
	_back_canvas.seed = _plan.seed_value
	_foil_stock(_back_mat, _plan.look)
	# THE DECK'S CARDS, as many as it holds
	var deck_mesh := _mesh_for(_plan.look, DECK_T)
	while _deck.size() > _plan.deck_n:
		(_deck.pop_back() as Node).queue_free()
	while _deck.size() < _plan.deck_n:
		var dm := MeshInstance3D.new()
		dm.mesh = deck_mesh
		dm.set_surface_override_material(0, _unseen_mat)
		dm.set_surface_override_material(1, _back_mat)
		dm.set_surface_override_material(2, _edge_mat)
		_root3.add_child(dm)
		_deck.append(dm)
	for d in _deck:
		(d as MeshInstance3D).mesh = deck_mesh
	_rummage_card.mesh = _mesh_for(_plan.look)
	_show_searched(0)
	_rummage_card.set_surface_override_material(2, _edge_mat)
	_back_mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
	_edge_mat.albedo_color = CardTable.color(String((_plan.look.get("frame", {}) as Dictionary).get("stock", "#efe6d2"))).darkened(0.08)
	_page_canvas.look = _plan.look
	_page_canvas.seed = _plan.seed_value
	_page_for = -1
	# THE SPREAD: where the cards were given to lie (a plan's coordinates, a dealer's layout - checked
	# on the cloth, in the frame and clear of the deck), else the seeded preset. The preset is drawn
	# either way, so every draw after it lands where it always has.
	var seeded := TablePositions.staged(cards, rng, CardTable.layout_of(_plan.seed_value), _box_keep(), _box_center())
	var spec := _table_spec()
	var given := TablePositions.given(cards, _plan.seed_value, spec["top"], _box_keep(), _box_center())
	_plan.slots = given if not given.is_empty() else seeded
	_plan.lay_jit = []
	var placement := RandomNumberGenerator.new()
	placement.seed = hash([_plan.seed_value, "lay by hand"])
	for i in cards.size():
		_plan.lay_jit.append(Vector3(placement.randf_range(-0.0015, 0.0015),
			placement.randf_range(-0.0015, 0.0015), deg_to_rad(placement.randf_range(-1.2, 1.2))))
	_plan_aside(spec["top"])
	# a jumper flies out of the deck in the middle and lands on the far side from where the deck
	# is about to go
	_plan.jump_land = _plan.mid + Vector3(-signf(_deck_base.x) * 0.16, 0.0, 0.035)
	_build_table(spec)
	_plan_moves()
	_place_backdrop()
	_poll_pictures()
	for vp in _faces:
		CardFaces.redraw(vp)
	CardFaces.redraw(_back_vp)
	for pb in _printed:
		CardFaces.redraw((pb as Dictionary)["vp"])
	for key in _backs:
		for side in ["blank", "fronts"]:
			for unseen in (_backs[key] as Dictionary).get(side, []) as Array:
				CardFaces.redraw((unseen as Dictionary)["vp"])


## THE BACKS: the deck's own ([member _back_vp]), and one more per printing the drawn cards (and the box,
## when the producer chose it) are printed in ([method CardTable.look_of]) - and with each, what the
## cards nobody drew are printed as: their fronts (`fronts`, [method _unseen_fronts]) and, when the text
## is on the back, their backs (`blank`, [method _blank_backs]).
func _build_backs(cards: Array) -> void:
	for key in _backs:
		for side in ["blank", "fronts"]:
			for unseen in (_backs[key] as Dictionary).get(side, []) as Array:
				((unseen as Dictionary)["vp"] as Node).queue_free()
		if String(key) != "":
			((_backs[key] as Dictionary)["vp"] as Node).queue_free()
	_backs = {"": {"vp": _back_vp, "canvas": _back_canvas, "mat": _back_mat, "blank": _blank_backs(""),
		"fronts": _unseen_fronts("", cards)}}
	for name in _printings(cards):
		if String(name).is_empty() or _backs.has(name):
			continue
		var canvas := CardFaces.Face.new()
		canvas.back = true
		canvas.look = CardTable.look_of(_plan.look, {"series": name})
		canvas.seed = _plan.seed_value
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("lift", 0.06)
		mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
		_foil_stock(mat, canvas.look)
		_backs[name] = {"vp": vp, "canvas": canvas, "mat": mat, "blank": _blank_backs(String(name)),
			"fronts": _unseen_fronts(String(name), cards)}


## THE BACKS OF THE CARDS NOBODY DREW, for printing [param name], when the cards come from a box and
## their text is printed on their backs: printed as a drawn card's own back is ([method _back_of]). THEY
## ARE THE DECK'S OWN CARDS where the plan lists them - the ones the draw left in the box, their name,
## group and meaning set as a drawn card's are ([method _left_in]; up to [constant WRITTEN] of them) - and
## otherwise [constant BLANKS] backs of type nobody wrote ([member CardFaces.Face.anonymous]). The box's
## unseen cards showed the printing's shared artwork while every card pulled out of it had a printed
## back - two kinds of card in one box (the user, 2026-10-11) - and then ruled dashes, which a card
## held up in a search showed for what they were (2026-10-12). None otherwise: the shared back is the
## right one.
func _blank_backs(name: String) -> Array:
	var out: Array = []
	if _plan.cards_from != "box" or String(_plan.staging["text"]) != "back":
		return out
	var left := _left_in(name)
	for v in left.size() if not left.is_empty() else BLANKS:
		var canvas := CardFaces.Face.new()
		canvas.back = true
		canvas.printed = true
		canvas.anonymous = left.is_empty()
		canvas.look = CardTable.look_of(_plan.look, {"series": name}) if not name.is_empty() else _plan.look
		canvas.card = left[v] if not left.is_empty() else {"key": "unseen %d" % v}
		canvas.seed = _plan.seed_value
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("lift", 0.5)
		mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
		out.append({"vp": vp, "canvas": canvas, "mat": mat})
	return out


## THE FRONTS OF THE CARDS NOBODY DREW, for printing [param name], when the cards come from a box - what
## a card looked at in a search shows, and every card standing in the file. EACH IS ONE OF THE DECK'S OWN
## CARDS the draw left in ([method _left_in]; up to [constant WRITTEN]), printed as a drawn card's front
## is - its frame, its ornament, its name, its details under the picture when the text is on the front -
## with A PAINTING NOBODY PAINTED in its window: a part of a drawn card's ([method CardFaces.stand_in];
## `from`, one of this printing's among [param cards] when it has any), put in as that painting lands
## ([method _poll_pictures]). A painting is a painter's run, and no card is painted to be glanced at in
## its box. Where the episode lists no card left in, [constant BLANKS] fronts with no name. A search
## used to show the BACK of every card it looked at, and nobody looks for a card by its back (the user,
## 2026-10-13: "they rifle through it looking at the front, to find the specific card").
func _unseen_fronts(name: String, cards: Array) -> Array:
	var out: Array = []
	if _plan.cards_from != "box":
		return out
	var left := _left_in(name)
	var own: Array = []
	for i in cards.size():
		if cards[i] is Dictionary and CardTable.series_of(_plan.look, cards[i] as Dictionary) == name:
			own.append(i)
	if own.is_empty():
		own = range(cards.size())
	for v in left.size() if not left.is_empty() else BLANKS:
		var canvas := CardFaces.Face.new()
		canvas.look = CardTable.look_of(_plan.look, {"series": name}) if not name.is_empty() else _plan.look
		canvas.anonymous = left.is_empty()
		canvas.card = left[v] if not left.is_empty() else {"key": "unseen %d" % v}
		canvas.details = String(_plan.staging["text"]) == "front"
		canvas.seed = _plan.seed_value
		var pick := hash([_plan.seed_value, name, String(canvas.card.get("key", "")), "stand-in"])
		canvas.part = CardFaces.stand_in(canvas.look.get("palette", []) if canvas.look.get("palette") is Array else [], pick)
		var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
		var mat := _foil_material(vp.get_texture())
		mat.set_shader_parameter("window", _face_window(canvas))
		_foil_stock(mat, canvas.look)
		out.append({"vp": vp, "canvas": canvas, "mat": mat, "from": int(own[absi(pick) % own.size()]) if not own.is_empty() else -1})
	return out


## The deck's cards of printing [param name] that the draw LEFT IN THE BOX, as a card's faces set one
## ([class CardFaces.Face]: its name and numeral, its group as its one fact, its meaning as its text) - at
## most [constant WRITTEN], picked on the seed. They are the plan's deck less the drawn cards when the
## producer chose it, and otherwise what the draw says it left of the show's own (`left`,
## [method CardProducer._make_draw]). Empty when the episode lists neither.
func _left_in(name: String) -> Array:
	var plan: Dictionary = _plan.pay.get("plan", {}) if _plan.pay.get("plan") is Dictionary else {}
	var drawn := {}
	for c in _plan.pay.get("cards", []) if _plan.pay.get("cards") is Array else []:
		if c is Dictionary:
			drawn[String((c as Dictionary).get("key", ""))] = true
	var listed: Array = plan.get("deck", []) if plan.get("deck") is Array else []
	if listed.is_empty():
		listed = _plan.pay.get("left", []) if _plan.pay.get("left") is Array else []
	var out: Array = []
	for c in listed:
		if not (c is Dictionary) or drawn.has(String((c as Dictionary).get("key", ""))):
			continue
		var card: Dictionary = c
		if CardTable.series_of(_plan.look, card) != name or String(card.get("name", "")).strip_edges().is_empty():
			continue
		var group := String(card.get("group", "")).strip_edges()
		out.append({"key": String(card.get("key", "")), "name": String(card.get("name", "")),
			"numeral": String(card.get("numeral", "")),
			"booklet": {"keywords": [group] if not group.is_empty() else [], "upright": String(card.get("meaning", ""))}})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_plan.seed_value, name, "left in the box"])
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = out[i]
		out[i] = out[j]
		out[j] = swap
	return out.slice(0, WRITTEN)


## What a card nobody drew shows on its back, in printing [param name]: its shared back, or one of its
## printed backs ([method _blank_backs]).
func _unseen_mats(name: String) -> Array:
	var bk: Dictionary = _backs.get(name, _backs[""])
	var blank: Array = bk.get("blank", [])
	if blank.is_empty():
		return [bk["mat"]]
	return blank.map(func(b: Dictionary) -> Material: return b["mat"])


## THE CARDS NOBODY DREW, in printing [param name], as `[front, back]` materials: each its own front
## ([method _unseen_fronts]) and, where the backs are printed, that same card's back ([method _blank_backs]
## sets the same cards in the same order) - the shared back otherwise, on both sides where there is no
## front to show (a show whose cards do not come from a box).
func _unseen_kinds(name: String) -> Array:
	var backs := _unseen_mats(name)
	var fronts: Array = (_backs.get(name, _backs[""]) as Dictionary).get("fronts", [])
	var out: Array = []
	for v in maxi(fronts.size(), backs.size()):
		var back: Material = backs[v % backs.size()]
		out.append([(fronts[v % fronts.size()] as Dictionary)["mat"] if not fronts.is_empty() else back, back])
	return out


## Every printing's cards nobody drew, one after another ([method _unseen_kinds]): what a search turns up.
func _unseen_all() -> Array:
	var out: Array = []
	for name in _backs:
		out.append_array(_unseen_kinds(String(name)))
	return out


## Every printing the episode's cards are in, the deck's own ("") among them when any card is in it: the
## drawn cards', and the whole box's when the producer chose one.
func _printings(cards: Array) -> Array:
	var out: Array = []
	var plan: Dictionary = _plan.pay.get("plan", {}) if _plan.pay.get("plan") is Dictionary else {}
	var all: Array = cards.duplicate()
	all.append_array(plan.get("deck", []) if plan.get("deck") is Array else [])
	for c in all:
		var name := CardTable.series_of(_plan.look, c as Dictionary) if c is Dictionary else ""
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
	var name := CardTable.series_of(_plan.look, card)
	if String(_plan.staging["text"]) != "back":
		return (_backs.get(name, _backs[""]) as Dictionary)["mat"]
	var canvas := CardFaces.Face.new()
	canvas.back = true
	canvas.printed = true
	canvas.look = CardTable.look_of(_plan.look, card)
	canvas.card = card
	canvas.seed = _plan.seed_value
	var vp := CardFaces.viewport(self, canvas, CardFaces.face_px(canvas.look))
	var mat := _foil_material(vp.get_texture())
	# Printed details need to read even when the box shades a card held over it.
	mat.set_shader_parameter("lift", 0.5)
	mat.set_shader_parameter("window", Vector4(0.0, 0.0, 1.0, 1.0))
	while _printed.size() <= i:
		_printed.append({})
	_printed[i] = {"vp": vp, "canvas": canvas, "mat": mat, "series": name}
	return mat


## Where the box the cards are kept in may stand, across and deep - kept clear by the spread - or zero
## when they come from a deck.
func _box_keep() -> Vector2:
	var most := CardTable.SHOEBOX_MAX if String(_plan.staging.get("box_style", "open")) == "shoebox" else CardTable.BOX_MAX
	return Vector2(most.x, most.z) if _plan.cards_from == "box" else Vector2.ZERO


func _box_center() -> Vector3:
	return TablePositions.SHOEBOX_AT if _plan.cards_from == "box" and String(_plan.staging.get("box_style", "open")) == "shoebox" else Vector3.ZERO


## The part of a face that is the painting with no type over it, in UV - foil is keyed inside it (the
## frame's foil is keyed by its color instead; [method CardFaces.Face.bare]).
func _face_window(face: CardFaces.Face) -> Vector4:
	var sz := Vector2(CardFaces.face_px(face.look))
	var w := face.bare()
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
## export, tests/table/card_foil_check.gd).
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
	var dir := String(_plan.pay.get("dir", ""))
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
		_foil_accent(_face_mats[i], _plan.look)
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
		_foil_accent(bk["mat"], _plan.look)
		(bk["mat"] as ShaderMaterial).set_shader_parameter("foil", _foil * 0.8)
		for blank in bk.get("blank", []) as Array:
			if back != null and ((blank as Dictionary)["canvas"] as CardFaces.Face).art != back:
				((blank as Dictionary)["canvas"] as CardFaces.Face).art = back
				CardFaces.redraw((blank as Dictionary)["vp"])
			((blank as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("foil", _foil * 0.25)
		# THE FRONTS OF THE CARDS NOBODY DREW: a part of a drawn card's painting, once that one has landed
		for front in bk.get("fronts", []) as Array:
			var from := int((front as Dictionary).get("from", -1))
			var fc: CardFaces.Face = (front as Dictionary)["canvas"]
			var fmat: ShaderMaterial = (front as Dictionary)["mat"]
			var art: Texture2D = (_face_canvas[from] as CardFaces.Face).art if from >= 0 and from < _face_canvas.size() else null
			if art != null and fc.art != art:
				fc.art = art
				var fkey: Vector2 = _textures.get(dir.path_join("card_%d.png" % (from + 1)) + "|key", Vector2(0.8, 0.95))
				fmat.set_shader_parameter("lo", fkey.x)
				fmat.set_shader_parameter("hi", fkey.y)
				CardFaces.redraw((front as Dictionary)["vp"])
			_foil_accent(fmat, fc.look)
			fmat.set_shader_parameter("foil", _foil)
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
			_light_part._heat_cells = {}
	# a cloth that landed after the candles stood (live, it is painted while a reading can already
	# be playing) lights the table again
	if _painting_tex != _light_part._lit_cloth:
		_light_part.light_the_table()
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
		var pal2: Array = _plan.look.get("palette", CardTable.FALLBACK_PALETTE)
		_backdrop_mat.set_shader_parameter("tint", CardTable.color(String(pal2[0])).darkened(0.25))


## The painting and its height map laid on whatever surfaces of the table take them, the map shifted
## onto the painting as its fit found (`height.json`).
func _apply_painting() -> void:
	var shift := Vector2.ZERO
	var fit_path := String(_plan.pay.get("dir", "")).path_join("height.json")
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
	var path := String(_plan.pay.get("dir", "")).path_join("surface.png")
	return Tables.surface_lum(_furniture["spec"], _painting_small(path) if _painting_tex != null else null, LUM_RECT, LUM_GRID,
		_cloth_fallback())


## The cloth an episode gets while its own is not painted: a dark shade of its palette.
func _cloth_fallback() -> Color:
	var pal: Array = _plan.look.get("palette", CardTable.FALLBACK_PALETTE)
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
		var ahead := Vector3(-_plan.cam_base.basis.z.x, 0.0, -_plan.cam_base.basis.z.z).normalized()
		_backdrop.transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), _plan.cam_base.origin + ahead * ROOM_REACH)
		# a 36 x 24 frame behind a lens of this length, seen at this reach
		(_backdrop.mesh as QuadMesh).size = Vector2(36.0, 24.0) * ROOM_REACH / lens
	else:
		var dist := ROOM_REACH
		var fwd := -_plan.cam_base.basis.z
		var center := _plan.cam_base.origin + fwd * dist
		var h := 2.0 * dist * tan(deg_to_rad(_cam.fov * 0.5))
		var w := h * 16.0 / 9.0
		var far_edge := Vector3(0.0, 0.0, TABLE_Z - TABLE.z * 0.5)
		var up := _plan.cam_base.basis.y
		# where the far edge's line of sight crosses the backdrop's plane, along the camera's up axis
		var to_edge := (far_edge - _plan.cam_base.origin).normalized()
		var along := to_edge.dot(fwd)
		var hit := _plan.cam_base.origin + to_edge * (dist / maxf(along, 0.05))
		var edge_up := (hit - center).dot(up)
		var size := Vector2(w * 1.45, w * 1.45 / 1.5)
		# the picture's horizon (a third up from its bottom) on that line
		var offset := edge_up - (-size.y * 0.5 + size.y * (1.0 / 3.0))
		_backdrop.transform = Transform3D(_plan.cam_base.basis, center + up * offset)
		(_backdrop.mesh as QuadMesh).size = size
	_backdrop_mat.set_shader_parameter("radius", room_blur(_plan.cam_base, _cam.fov, _backdrop.transform,
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
	var path := String(_plan.pay.get("dir", "")).path_join("backdrop.json")
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
	var cards: Array = _plan.pay.get("cards", [])
	if _box_part.filed_on_edge() and i < cards.size() and cards[i] is Dictionary:
		var p: Dictionary = (cards[i] as Dictionary).get("position", {}) if (cards[i] as Dictionary).get("position") is Dictionary else {}
		if String(p.get("destination", "")) == "box" and i < (_box_part.stood["at_k"] as Array).size():
			var placed: Transform3D = (_box_part.stood["at_k"] as Array)[i]
			if _box_part.stood.has("return_at"):
				# on the pile the returns go to, each on the last, set down a little off true
				var before := 0
				for j in i:
					if cards[j] is Dictionary and (cards[j] as Dictionary).get("position") is Dictionary \
							and String(((cards[j] as Dictionary)["position"] as Dictionary).get("destination", "")) == "box":
						before += 1
				placed.origin = (_box_part.stood["return_at"] as Vector3) + Vector3(0.0, float(before) * CARD_T * 1.1, 0.0)
				placed.basis = Basis(Vector3.UP, float(_box_part.stood.get("return_turn", 0.0))
					+ (float(hash([_plan.seed_value, i, "put back"]) % 1000) / 1000.0 - 0.5) * 0.14)
			elif String(_plan.staging.get("contents", "file")) != "file":
				var inner: AABB = _box_part.stood["inner"]
				placed.origin.y = minf(inner.end.y - CARD_T, placed.origin.y + CARD_T * 2.0)
			return placed
	var s: Dictionary = _plan.slots[i] if i < _plan.slots.size() else {"pos": Vector3.ZERO, "yaw": 0.0}
	var hand: Vector3 = _plan.lay_jit[i] if i < _plan.lay_jit.size() else Vector3.ZERO
	var yaw := float(s["yaw"]) + hand.z + (PI if _reversed(i) else 0.0) + TablePositions.SIDEWAYS * float(quarter)
	var down := String(s.get("face", "up")) == "down"
	var face := _face_up() if down == over else Basis.IDENTITY
	return Transform3D(Basis(Vector3.UP, yaw) * face,
		s["pos"] as Vector3 + Vector3(hand.x, CARD_T * 0.5, hand.y))


func _reversed(i: int) -> bool:
	var cards: Array = _plan.pay.get("cards", [])
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
	_furniture = Tables.build({"top": spec["top"], "layers": spec["layers"]}, _plan.seed_value)
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
	_light_part._flame_n = 0
	_standing = []
	_standing_c = PackedVector2Array()
	_standing_r = PackedFloat32Array()
	_things = []
	_light_part._heat_cells = {}
	# the name over this table is printed in the color the set dresser chose to stand out from it
	_title.ink = CardTable.title_ink(spec)
	_title.queue_redraw()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_plan.seed_value, "tarot-things"])
	var things: Array = (spec["things"] as Array).duplicate()
	var built: Array = []
	for i in things.size():
		if Props.draped(things[i]):
			# LAID ACROSS THE TABLE ITSELF: built in its space, over the edge of this top
			things[i] = _grounded(things[i])
			built.append(Props.build(things[i], spec["materials"], hash([_plan.seed_value, i, "thing"]), true))
		else:
			built.append(Props.build(things[i], spec["materials"], hash([_plan.seed_value, i, "thing"])))
	# THE BOX THE CARDS ARE KEPT IN stands first, where the deck would be: the rest go round it
	_box_part.build(things, built)
	_place_things(things, built, rng)
	_light_part.build(spec)
	_light_part.light_the_table()
	_reflect()
	_build_air(spec)


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
	var path := String(_plan.pay.get("dir", "")).path_join("table.json")
	_table_mt = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	if _table_mt >= 0:
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			return CardTable.sanitize_table(j.data as Dictionary, _plan.look)
	return CardTable.default_table(_plan.look, _plan.seed_value)


## WHERE EACH THING STANDS. A thing goes in the zone the set dresser named, and things that share
## a group stand together: the group's tallest first, as near its zone's middle as there is room,
## the rest round it - the shorter ones toward the reader - so a group reads as arranged, not
## lined up. The biggest groups choose first. A thing with no room is tried smaller, then left
## off the table.
func _place_things(things: Array, built: Array, rng: RandomNumberGenerator) -> void:
	var keep_out := _keep_out()
	_habit = _habit_of(_plan.seed_value)
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
	for sl in _plan.slots:
		out.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), CARD).grow(0.03))
	out.append(Rect2(_deck_base.x - 0.08, _deck_base.z - 0.1, 0.16, 0.2))
	if _aside_card >= 0:
		out.append(Rect2(_deck_far.x - 0.08, _deck_far.z - 0.1, 0.16, 0.2))
	# the middle, where the deck is shuffled - and, whatever the source, where the spread lies
	out.append(Rect2(_plan.mid.x - 0.22, _plan.mid.z - 0.14, 0.44, 0.28))
	if _plan.cards_from == "box":
		# nothing stands where the box would, nor where a pulled card rises past it
		out.append(TablePositions.deck_keep(_deck_base, _box_keep(), _box_center()))
		if _box_part.stood.has("lid"):
			var world: AABB = _box_part.stood["world"]
			var side := signf(_deck_base.x)
			var x := world.get_center().x + side * (world.size.x + 0.025)
			out.append(Rect2(x - world.size.x * 0.5 - 0.025, world.position.z + 0.08 - 0.025,
				world.size.x + 0.05, world.size.z + 0.05))
		return out
	out.append(Rect2(_plan.jump_land.x - 0.07, _plan.jump_land.z - 0.09, 0.14, 0.18))
	return out


## ONE THING STOOD: the best free spot for [param t] (built as [param b]) on a grid over the table,
## at full size or, failing that, a little smaller. Every spot is ON THE TABLE, off everywhere the
## cards go, clear of what already stands (by [constant THING_GAP], or [constant GROUP_GAP] within
## its own group), IN THE SHOT (its projected box never cut by the frame's top, with at least
## [constant SEEN_LEAST] visible). A lit thing first seeks a whole view; if none fits, its sides
## may be cut while every flame stays in view. Between groups, things do not overlap in the picture.
## Aimed where the episode's habit puts its zone ([method _habit_aim]),
## and kept off a cloth's edge where it can be ([method _straddle]). A lit thing stands only behind the middle (in front of the
## cards its flame blew out the card held up to the lens) and looks for dark cloth. The spot
## chosen ({at, k, group, height}), or empty when there is none.
func _stand(t: Dictionary, b: Dictionary, group: String, anchor: Dictionary, keep_out: Array,
		rng: RandomNumberGenerator, edge_light := false) -> Dictionary:
	var box: AABB = b["size"]
	var lit := not (b["wicks"] as Array).is_empty()
	var yaw := deg_to_rad(float(t.get("turn", 0.0)) + rng.randf_range(-8.0, 8.0))
	var zone := String(t.get("place", "back"))
	var aim := _habit_aim(zone, group, _deck_base)
	var front := (_deck_base.z + 0.03) if zone in ["by the deck", "left", "right"] else _plan.mid.z + 0.03
	# a LOW thing may lie nearer the reader, where it hides no card and nothing behind it
	if box.size.y < 0.04:
		front = 0.2
	if lit:
		front = minf(front, _plan.mid.z)
	var outline: PackedVector2Array = b["outline"]
	var top_center: Vector2 = _top_o["center"]
	var top_half: Vector2 = _top_o["half"]
	var shot := Rect2(0.0, 0.0, 1.0, 1.0)
	var workspace := Rect2(_plan.mid.x - WORKSPACE_HALF, _plan.mid.z + WORKSPACE_FROM, WORKSPACE_HALF * 2.0, 1.0)
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
		var cam_inv := _plan.cam_base.affine_inverse()
		var lens := Vector2(tan(deg_to_rad(_cam.fov * 0.5)) * (16.0 / 9.0), tan(deg_to_rad(_cam.fov * 0.5)))
		var z := top_center.y - top_half.y
		while z <= front:
			var x := top_center.x - top_half.x
			while x <= top_center.x + top_half.x:
				_breathe()
				var at := Vector2(x + rng.randf_range(-0.004, 0.004), z + rng.randf_range(-0.004, 0.004))
				x += 0.02
				var bb := Rect2(lo + at, hi - lo)
				# The actual top, including its side margins, is available. Its outline below keeps
				# every foot safely in from the rim; the picture test decides what the viewer sees.
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
				var seen := rect.intersection(shot)
				# Never cut by the frame's TOP: that reads as a thing standing in the room. Lit things
				# seek a whole view first; everything may run off a side if enough of it remains visible.
				if rect.position.y < 0.02:
					continue
				if seen.get_area() < rect.get_area() * SEEN_LEAST:
					continue
				if lit:
					if rect.end.y > 0.97:
						continue
					if not edge_light and (rect.position.x < 0.02 or rect.end.x > 0.98):
						continue
					if edge_light:
						var wick_seen := true
						for wick in b["wicks"]:
							var flame: Variant = CardTable.project(_plan.cam_base, _cam.fov,
								basis * (wick as Vector3) + Vector3(at.x, 0.0, at.y))
							if flame == null or (flame as Vector2).x < 0.02 or (flame as Vector2).x > 0.98:
								wick_seen = false
								break
						if not wick_seen:
							continue
				# not in front of another in the picture: apart between groups, and within one only a
				# little in front - a group seen one thing through another read as a stack
				var hidden := 0.0
				for th in _things:
					var other: Rect2 = ((th as Dictionary)["rect"] as Rect2).intersection(shot)
					if String((th as Dictionary)["group"]) != group:
						if other.grow(0.008).intersects(seen):
							clear = false
							break
					elif other.intersects(seen):
						hidden = maxf(hidden, other.intersection(seen).get_area() / maxf(minf(other.get_area(), seen.get_area()), 1e-6))
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
					score -= 0.8 * maxf(0.0, _light_part.heat_cell(Vector3(at.x, 0.0, at.y)) * KEY_ENERGY / HEAT - 1.0)
				score -= _straddle(bb)
				if bb.intersects(workspace):
					score -= WORKSPACE
				score += rng.randf() * 0.05
				if score > best_score:
					best_score = score
					best = {"at": at, "rect": rect, "bb": bb, "outline": placed if not placed.is_empty() else _translated(shape, at)}
			z += 0.02
		if not best.is_empty():
			_put(t, b, best, basis, group)
			return {"at": best["at"], "height": box.size.y * k, "k": k}
	if lit and not edge_light:
		return _stand(t, b, group, anchor, keep_out, rng, true)
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
	# The wax and holder immediately under a flame cannot shadow themselves: they printed a
	# hard disc at the base. Separate accessories several centimeters away (a dish of dye beside
	# the candle, for example) must still catch and cast that candle's light.
	var own := (CANDLE_LAYER << _lights.size()) if not wicks.is_empty() else THING_LAYER
	for m in b["meshes"]:
		var mesh := m as MeshInstance3D
		mesh.layers = own if wicks.is_empty() or TableLight.near_wick(mesh, wicks) else THING_LAYER
	var glows: Array = b.get("glows", [])
	var first := _lights.size()
	if not wicks.is_empty():
		var flames: Array = []
		for i in wicks.size():
			var wick: Vector3 = node.transform * (wicks[i] as Vector3)
			var f := _light_part.add_flame(wick, own, glows[i] if i < glows.size() else null)
			f["open"] = Props.open_to_air(wick, node, b["meshes"])
			flames.append(f)
		_light_part.light_flames(flames, own)
	var foot := _translated(_turned(b["foot"], basis), at)
	if foot.size() >= 3:
		# A moving shoebox gets its own moving soft shade. A fixed decal projects onto
		# its walls as it passes, and a fixed shadow slab leaves a ghost at its destination.
		if not (group == "#the box" and String(_plan.staging.get("box_style", "open")) == "shoebox"):
			_light_part.contact_shadow(foot)
			_light_part.foot_shadow(foot, own)
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


# --- the camera ----------------------------------------------------------------------------------------

## The reader's eye: still.
func _tick_camera(_t: float) -> void:
	# A LOCKED-OFF CAMERA: the table is filmed from a tripod. The Camera dial's breath was a
	# millimeter - nothing anyone could see - so the dial is gone from the panel
	_cam.transform = _plan.cam_base


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
		_air = Effects.build(fx, _air_stage(), hash([_plan.seed_value, "air"]))
		_root3.add_child(_air.root)
	var foggy: bool = _air != null and _air.has_fog()
	Effects.fog_environment(_env, foggy)
	# IN FOG, A LIGHT IS SEEN: the lamp's beam and every candle's glow scatter in it, shafts and halos
	_lamp.light_volumetric_fog_energy = 1.6 if foggy else 1.0
	for l in _lights:
		((l as Dictionary)["light"] as OmniLight3D).light_volumetric_fog_energy = 2.0 if foggy else 1.0
	if _light_part._rig != null:
		_light_part._rig.set_fog(foggy)
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
	if not _box_part.stood.is_empty():
		under.append(_box_part.stood["world"])
	var fwd := -_plan.cam_base.basis.z
	var near := INF
	var far := 0.0
	for i in 8:
		var d := (table.get_endpoint(i) - _plan.cam_base.origin).dot(fwd)
		near = minf(near, d)
		far = maxf(far, d)
	var top: Dictionary = (_furniture.get("spec", {}) as Dictionary).get("top", Tables.DEFAULT_TOP)
	return {"regions": CardTable.AIR, "camera": _plan.cam_base, "fov": _cam.fov, "aspect": 16.0 / 9.0, "occluders": under,
		"wind": _wind, "on_top": func(p: Vector2) -> bool: return Tables.inside(top, p, 0.01), "cover": _cover_at,
		"sharp": Vector2(near, far), "defocus": 2.0 * ROOM_BLUR / maxf(1.0 / far - 1.0 / ROOM_REACH, 1e-3),
		"deep": ROOM_REACH * 0.9}


## WHAT LIES ON THE CLOTH at [param p] (xz, [param r] round it) at show time [param t]: the top of the deck
## or of a card lying there, or -INF - where what drifts may not come down, skid or lie uncovered (a
## flower once fell through the deck and lay under it, 2026-10-08). A card held up, or still in the
## deck, covers nothing; a deck being shuffled or washed spreads wider than it lies.
func _cover_at(p: Vector2, t: float, r: float) -> float:
	var tm := _times()
	var wj := _shuffles.wash_jump(maxf(float(tm["shuffle"]), minf(0.0, _now)))
	var keep := _cur_base
	var keep_gone := _deck_gone
	_cur_base = _deck_at(t, tm, wj)
	_deck_gone = 1 if not wj.is_empty() and t >= float(wj["end"]) else 0
	var top := -INF
	if _plan.cards_from != "box":
		var loose := 0.0
		if t >= float(tm["shuffle"]) and t < float(tm["end"]) + SQUARE:
			loose = 0.1
		if not wj.is_empty() and t >= float(wj["base"]) and t < float(wj["end"]):
			loose = 0.12
		if _under_card(_rest_xf(_plan.deck_n - 1), p, r + loose):
			top = _cur_base.y + float(_plan.deck_n - _deck_gone) * DECK_T
	var events: Array = tm["events"]
	for k in _cards.size():
		var pose := _card_poses.card_pose(k, t, events[k], wj)
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
			"path": [[ts, Transform3D(Basis.IDENTITY, _plan.mid + Vector3(0.0, DECK_T * _plan.deck_n, 0.0))]]})
	var all_events: Array = tm["events"]
	var wj0 := _shuffles.wash_jump(maxf(float(tm["shuffle"]), minf(0.0, _now)))
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
				for l in _card_poses.looks(k, up_at, tl):
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
	# THE WASH'S CARDS ON THE CLOTH, for what lies there to be shoved by ([method Drifts.laid]); not a
	# moment a burst can be on, so not one of [constant CardTable.MOMENTS]
	var ts_wash := maxf(float(tm["shuffle"]), minf(0.0, _now))
	out["sweep"] = _shuffles.sweeps(ts_wash, float(tm["end"]), func(t: float) -> Vector3: return _deck_at(t, tm, wj0),
		str(tm["first"]))
	return out


## How often a burst's emitter is sampled along its card's path (seconds): a frame's time at 30 - a
## twirl turns well under half a turn between two, so a card's edges eased between them are where
## they are drawn.
const AIR_STEP := 1.0 / 30.0

## CARD [param k] AS THE TABLE DRAWS IT from [param t0] through [param dur] seconds - or through the
## window a moment's particles are born in ([constant Effects.BIRTH]) when that is longer: its pose
## ([method TableCardPose.card_pose]) with the deck where [method _pose] has it, every [constant AIR_STEP]. What a
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
		path.append([t, _card_poses.card_pose(k, t, ev, wj)["xf"]])
	_cur_base = keep
	_deck_gone = keep_gone
	return path


# --- the schedule ----------------------------------------------------------------------------------------

## THE SHUFFLE'S CHAIN, made now rather than a frame at a time while it plays - and after the things
## on the table stand, so a wash's cards go round them, never through them. Again whenever the table
## changes. A wash's plan is made when it is first asked for ([method TableShuffle._whole]): the
## first frame of a reading that shuffles, and never for a table only looked at.
func _plan_moves() -> void:
	_move_rng.seed = hash([_plan.seed_value, "tarot-moves"])
	_moves = []
	_jumper_wash()
	_shuffles.move_at(120.0)


## A JUMPER'S WASH, held back for it: an episode whose first card is a jumper washes the deck into
## it now and then ([constant JUMPER_WASH], its own die) - its one wash begins
## [constant JUMPER_WASH_LEAD] before the jumper is reckoned to come (the script's words at the
## follower's steady pace) and runs [constant JUMPER_WASH_SLACK] past it, so the jumper comes while
## it mixes whatever the voice's real pace ([method _jumper_plan]).
func _jumper_wash() -> void:
	_wash_held = false
	var first := {}
	for a in _plan.parse.get("actions", []):
		var kind := String((a as Dictionary)["kind"])
		if TableActions.shows(kind):
			first = a
			break
	if first.is_empty() or String(first["kind"]) != "jumper":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_plan.seed_value, "jumper-wash"])
	var spoken: PackedStringArray = _plan.parse.get("spoken", PackedStringArray())
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
	var rummages: Array = []
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
	var pushes := bool((TableActions.SOURCES.get(_plan.cards_from, TableActions.SOURCES["deck"]) as Dictionary)["pushes"])
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
			"rummage":
				rummages.append({"t0": t0, "s": s, "off": off})
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
	_all_events = events
	return {"shuffle": shuffle, "opening": opening, "end": first, "draw": draw, "lay": lay, "spread": spread,
		"first": first_act, "events": events, "rummages": rummages}


## Where the deck is at [param t]: in the middle while it is shuffled, then pushed to its side
## as the first card comes - squared first (SQUARE), then slid (PUSH_SLIDE), a hair off the cloth.
## A jumper flies out of a riffle in the middle, and the deck goes once that riffle is done - or,
## out of a wash ([param wj], [method TableShuffle.wash_jump]), once the wash is gathered.
func _deck_at(t: float, tm: Dictionary, wj := {}) -> Vector3:
	if _plan.cards_from == "box":
		# IN THE BOX: a tin's deck lies flat on its floor (a box's cards are filed, the deck unseen)
		var inner: AABB = _box_part.stood.get("inner", AABB(_deck_base, Vector3.ZERO))
		return Vector3(inner.get_center().x, inner.position.y, inner.get_center().z) if not _box_part.stood.is_empty() else _deck_base
	var first: Array = tm["first"]
	if first.is_empty():
		return _plan.mid
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
		return _deck_base.lerp(_deck_far, _ease(v)) + Vector3(0.0, sin(PI * v) * 0.003, 0.0)
	return _plan.mid.lerp(_deck_base, _ease(u)) + Vector3(0.0, sin(PI * u) * 0.004, 0.0)


## THE DECK PUT ASIDE ([constant DECK_CROWD]): the first card of the spread that would lie that near
## the deck, and the spot further out - in the frame, on the top, as far from the spread as it can be,
## by the least slide - it is moved to before that card is drawn. None when nothing crowds it, the die
## says it stays, the cards come from a box, or there is nowhere better; the first card itself crowding
## it puts the deck there from the start.
func _plan_aside(top: Dictionary) -> void:
	_aside_card = -1
	_deck_far = _deck_base
	if _plan.cards_from == "box" or _plan.slots.is_empty():
		return
	var gap := func(a: Rect2, b: Rect2) -> float:
		return Vector2(maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
			maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))).length()
	var feet: Array = []
	for sl in _plan.slots:
		feet.append(CardTable.footprint((sl as Dictionary)["pos"], float((sl as Dictionary)["yaw"]), CARD))
	var keep := TablePositions.deck_keep(_deck_base)
	var crowd := -1
	for i in feet.size():
		if float(gap.call(keep, feet[i])) < DECK_CROWD:
			crowd = i
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_plan.seed_value, "tarot-deck-aside"])
	if crowd < 0 or rng.randf() >= DECK_ASIDE:
		return
	var lay := CardTable.layout_of(_plan.seed_value)
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
	if not _box_part.stood.has("lid"):
		return
	var open_at := float(tm["opening"])
	var u := maxf(t - open_at, 0.0) if open_at < INF else 0.0
	var rest: Transform3D = _box_part.stood["rest"]
	var side := signf(_deck_base.x)
	var arrival := _ease(clampf(u / 2.7, 0.0, 1.0))
	var turn := _ease(clampf((u - 0.7) / 2.0, 0.0, 1.0))
	var node: Node3D = _box_part.stood["node"]
	node.transform = Transform3D(rest.basis * Basis(Vector3.UP, -side * (1.0 - turn) * PI * 0.5),
		rest.origin + Vector3(side * 0.30 * (1.0 - arrival), 0.0, 0.015 * (1.0 - arrival)))
	var lift := _ease(clampf((u - 3.0) / 0.8, 0.0, 1.0))
	var away := _ease(clampf((u - 3.8) / 1.2, 0.0, 1.0))
	var lid: Node3D = _box_part.stood["lid"]
	var lid_rest: Vector3 = _box_part.stood["lid_rest"]
	var box_bounds: AABB = _box_part.stood["world"]
	var lower := _ease(clampf((u - 5.0) / 0.9, 0.0, 1.0))
	lid.position = Vector3(lid_rest.x, lerpf(lid_rest.y + 0.065 * lift, 0.003, lower), lid_rest.z) \
		+ rest.basis.inverse() * Vector3(side * (box_bounds.size.x + 0.025) * away, 0.0, 0.08 * away)
	lid.rotation.x = PI * _ease(clampf((u - 4.4) / 1.4, 0.0, 1.0))
	var contents_move := node.transform * rest.affine_inverse()
	for f in _box_part.files:
		(f as Node3D).transform = contents_move
	_box_part.stood["move"] = contents_move
	for i in _box_part.objects.size():
		(_box_part.objects[i] as Node3D).transform = contents_move * ((_box_part.stood["objects_rest"] as Array)[i] as Transform3D)
	var shade: Decal = _box_part.stood["shadow"]
	var moved: AABB = node.transform * (_box_part.stood["local_bounds"] as AABB)
	shade.position = Vector3(moved.get_center().x, 0.0, moved.get_center().z)
	shade.size = Vector3(moved.size.x * 1.7, 0.03, moved.size.z * 1.7)
	var lid_shade: Decal = _box_part.stood["lid_shadow"]
	var lid_at: Vector3 = node.transform * lid.position
	lid_shade.position = Vector3(lid_at.x, 0.0, lid_at.z)
	lid_shade.size = Vector3(box_bounds.size.x * 1.7, 0.03, box_bounds.size.z * 1.7)
	lid_shade.modulate.a = 0.6 * away


## A SEARCH LOOKS AT A FEW OF THE BOX'S OWN CARDS, one after another, each in its place
## (`_box["search"]`, [method _build_file] and [method _pile_places]), AND AT THEIR FRONTS (the user,
## 2026-10-13: nobody looks for a card by its back): a card ON EDGE, standing face to the reader, is
## drawn up out of the file along its own plane, [constant SEARCH_RISE] of its height, its face leaned
## back to the eye about the file's top, and let back down ([constant SEARCH_LOOKS] of them); a card
## LYING face down on a pile is lifted clear of the rim, turned over to be seen, turned back and laid
## down ([constant SEARCH_LOOKS_LYING], a turn over taking the longer). THE CARD IS THE BOX'S OWN, kept
## in that place ([method _keep_searched]), so nothing appears or changes as a look begins; only a box
## with no place to spare (a tin's flat deck, one pile) is given a card for the length of the look
## ([method _show_searched]). None becomes an episode draw, and none shows a painting of its own
## ([method _unseen_fronts]). It used to be one flat card that appeared in the air over the rim, rose
## and sank three times, over a box of cards standing on edge (the user, 2026-10-12: "lifted from the
## deck FLAT, and THREE times in a row. That is totally wrong").
func _pose_rummage(t: float, tm: Dictionary) -> void:
	_rummage_card.visible = false
	_box_part.looking = null
	if _plan.cards_from != "box" or _box_part.stood.is_empty():
		return
	# the box's own cards rest in their places, where the box is
	var move: Transform3D = _box_part.stood.get("move", Transform3D.IDENTITY)
	var seats: Array = _box_part.stood.get("search", [])
	for i in _box_part.searched.size():
		(_box_part.searched[i] as MeshInstance3D).transform = move * (seats[i] as Transform3D)
	var searches: Array = tm["rummages"]
	for n in searches.size():
		var e: Dictionary = searches[n]
		var start := float(e["t0"]) + float(e["off"]) * float(e["s"])
		var span := TableActions.RUMMAGE * float(e["s"])
		if t < start or t >= start + span:
			continue
		var looks := _card_poses.search_looks()
		var beat := fmod((t - start) / span * float(looks), 1.0)
		var which := n * looks + int(floor((t - start) / span * float(looks)))
		if not _box_part.searched.is_empty():
			_box_part.looking = _box_part.searched[which % _box_part.searched.size()]
		elif beat >= 0.05 and beat <= 0.95:
			# no card of its own to look at: one for the length of the look
			_box_part.looking = _rummage_card
			_show_searched(which)
			_rummage_card.visible = true
		if _box_part.looking != null:
			_box_part.looking.transform = move * _card_poses.searched_xf(which, beat)
		return


## The searched card is the [param which]-th card nobody drew, front and back ([method _unseen_all],
## through every printing in turn): a different card at every look.
func _show_searched(which: int) -> void:
	var kinds := _unseen_all()
	var kind: Array = kinds[which % kinds.size()]
	if _rummage_card.get_surface_override_material(0) != kind[0]:
		_rummage_card.set_surface_override_material(0, kind[0])
		_rummage_card.set_surface_override_material(1, kind[1])


func _pose(t: float) -> void:
	var tm := _times()
	_pose_box(t, tm)
	_pose_rummage(t, tm)
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
	var wj := _shuffles.wash_jump(ts)
	_cur_base = _deck_at(t, tm, wj)
	# THE JUMPER'S CARD IS NOT IN THE DECK once a wash throws it: its mesh is hidden while the wash
	# runs on, and the deck is one mesh short after (identical meshes: the top one goes)
	var gone := -1
	if not wj.is_empty() and t >= float(wj["eject"]):
		gone = int(wj["card"]) if t < float(wj["end"]) else _plan.deck_n - 1
	_deck_gone = 1 if not wj.is_empty() and t >= float(wj["end"]) else 0
	# THE DECK: shuffling from the shuffle mark until the first card leaves it, squared after - or,
	# when the first card is a jumper, riffled once more first: the card flies out of that riffle;
	# or the wash under way runs on and throws it
	# THE DECK'S CARDS LIE THE WAY THEY LIE ([method TableShuffle.deck_turns]): each carries its own way through
	# the shuffle, and the one that ends on top is the way the next card drawn comes up
	var chained := _plan.cards_from == "deck" and ts < INF
	var turns := _shuffles.deck_turns(t, ts, te, tm, wj, jump_s) if chained else PackedFloat32Array()
	var settled := float(wj["end"]) if not wj.is_empty() else te
	var top_slot := _plan.deck_n - 1 - _deck_gone
	for i in _plan.deck_n:
		var xf := _rest_xf(i)
		if t >= ts:
			if t < te:
				xf = _shuffles.shuffle_xf(i, t - ts)
			elif not wj.is_empty() and t < float(wj["end"]):
				xf = _shuffles.wash(i, t - float(wj["base"]), wj["m"])
			elif jump_s > 0.0 and wj.is_empty() and te < INF and t < te + JUMP_RIFFLE * jump_s:
				xf = _card_poses.jump_riffle(i, (t - te) / jump_s, _shuffles.shuffle_xf(i, te - ts))
			elif t < te + SQUARE and te < INF and jump_s == 0.0:
				xf = _shuffles.shuffle_xf(i, te - ts).interpolate_with(_rest_xf(i), _ease((t - te) / SQUARE))
		# The top of the stack is the next card the viewer will see. Once the shuffle is over, give its
		# back that card's orientation before it is uncovered; the draw mesh takes its place at t0.
		var spin := turns[i] if chained else 0.0
		if _plan.cards_from == "deck" and i == top_slot and (not chained or t >= settled):
			spin = PI if _top_deck_reversed(t, tm) else 0.0
		if spin != 0.0:
			xf.basis = xf.basis * Basis(Vector3.UP, spin)
		var dm: MeshInstance3D = _deck[i]
		dm.transform = xf
		# a box's cards are filed in it: the deck is seen only lying flat in a tin
		dm.visible = i != gone and (_plan.cards_from != "box" or bool(_box_part.stood.get("flat", false)))
	# THE CARDS, each from its own timeline
	var showing := -1
	var page_in := 0.0
	var all_events: Array = tm["events"]
	var glint_t := t
	for k in _cards.size():
		var m: MeshInstance3D = _cards[k]
		var pose := _card_poses.card_pose(k, t, all_events[k], wj)
		m.visible = bool(pose["visible"])
		if not m.visible:
			continue
		m.transform = pose["xf"]
		if _box_part.stood.has("lid") and float(tm["opening"]) < INF and t < float(tm["opening"]) + 2.7:
			m.transform = (_box_part.stood["node"] as Node3D).transform * (_box_part.stood["rest"] as Transform3D).affine_inverse() * m.transform
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
	if _plan.alone:
		showing = -1
	_pose_page(showing, page_in, t)
	# the laid cards keep a slow breath of foil; the back's own glint rides the shuffle
	_back_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(t * TAU / 7.0))


## The card waiting on top of the deck. Advance while the current card covers the stack at the
## start of its draw, so the newly exposed back never changes orientation between draws.
func _top_deck_reversed(t: float, tm: Dictionary) -> bool:
	var draws: Array = tm["draw"]
	for k in mini(draws.size(), _cards.size()):
		if t < float((draws[k] as Array)[0]):
			return _reversed(k)
	return not _cards.is_empty() and _reversed(_cards.size() - 1)


## The cards whose places on the cloth card [param k]'s overlaps ([method TablePositions.overlaps]) -
## none in a spread laid side by side, and nothing more is asked of it then. Made once per spread.
func _laps_of(k: int) -> Array:
	if not is_same(_laps_for, _plan.slots) or _laps.size() != _plan.slots.size():
		_laps_for = _plan.slots
		_laps = []
		var cards: Array = _plan.pay.get("cards", [])
		var lies: Array = []
		for i in _plan.slots.size():
			var p: Dictionary = (cards[i] as Dictionary).get("position", {}) \
				if i < cards.size() and cards[i] is Dictionary and (cards[i] as Dictionary).get("position") is Dictionary else {}
			# a card put back in its box is not on the cloth
			var boxed := _box_part.filed_on_edge() and String(p.get("destination", "")) == "box"
			var hand: Vector3 = _plan.lay_jit[i] if i < _plan.lay_jit.size() else Vector3.ZERO
			lies.append({} if boxed else {"pos": (_plan.slots[i]["pos"] as Vector3) + Vector3(hand.x, 0.0, hand.y),
				"yaw": float(_plan.slots[i]["yaw"]) + hand.z})
			_laps.append([])
		for i in lies.size():
			for j in range(i + 1, lies.size()):
				if not (lies[i] as Dictionary).is_empty() and not (lies[j] as Dictionary).is_empty() \
						and TablePositions.overlaps(lies[i], lies[j]):
					(_laps[i] as Array).append(j)
					(_laps[j] as Array).append(i)
	return _laps[k] if k < _laps.size() else []


## Deck slot [param i] at rest - the squared deck, a hair off true per slot.
func _rest_xf(i: int) -> Transform3D:
	var j: Vector3 = _plan.slot_jit[i] if i < _plan.slot_jit.size() else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, j.z), _cur_base + Vector3(j.x, (float(i) + 0.5) * DECK_T, j.y))


## Drawn card [param k] lying on top of the deck, face down (the way it will come up).
func _deck_top_xf(k: int) -> Transform3D:
	var j: Vector3 = _plan.slot_jit[_plan.deck_n] if _plan.slot_jit.size() > _plan.deck_n else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, j.z + (PI if _reversed(k) else 0.0)),
		_cur_base + Vector3(j.x, float(_plan.deck_n - _deck_gone) * DECK_T + CARD_T * 0.5, j.y))


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
	rng.seed = hash([_plan.seed_value, "spin"])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	var longest := 0.0
	for k in order:
		var span := _card_poses.held_span(int(k), tm)
		var room := span.y - span.x
		if room >= SPIN_ROOM:
			_spin_k = int(k)
			return _spin_k
		if room > longest and room > 1.0 + PIROUETTE_HOLD.x + TURN.x + TWIRL.y + 2.5:
			longest = room
			_spin_k = int(k)
	return _spin_k


func _pose_page(k: int, amount: float, t: float) -> void:
	_page.visible = k >= 0 and amount > 0.001
	if not _page.visible:
		return
	if k != _page_for:
		_page_for = k
		var cards: Array = _plan.pay.get("cards", [])
		_page_canvas.card = cards[k] if k < cards.size() else {}
		CardFaces.redraw(_page_vp)
	var c := _plan.cam_base.basis
	var yaw := -deg_to_rad(6.0) + sin(t * 0.45 + 2.0) * deg_to_rad(2.8) + sin(t * 0.19 + 0.7) * deg_to_rad(1.4)
	var tilt := sin(t * 0.33 + 1.1) * deg_to_rad(2.0)
	var b := Basis(c.y, yaw) * Basis(c.x, tilt) * Basis(c.z, sin(t * 0.27) * deg_to_rad(0.8)) * c
	var off := Vector3(PAGE.x + (1.0 - amount) * 0.22, PAGE.y + sin(t * 0.8 + 0.4) * 0.0012,
		-PRESENT_DIST - 0.004)
	_page.transform = Transform3D(b, _plan.cam_base * off)


# --- the shuffle ------------------------------------------------------------------------------------------


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
	var total := (_plan.parse.get("spoken", PackedStringArray()) as PackedStringArray).size()
	var last := _follow.known_last()
	if total == 0 or last < total - 1:
		return 1.0
	var outro := maxf(feed.tail(), 0.0)
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



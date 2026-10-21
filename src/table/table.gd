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
## ([method TablePlan.deck_count]: the agents decide it; 78 stand about 3 cm). A WASH SPREADS EVERY ONE OF
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
## THE DECK PUT ASIDE (the user, 2026-10-08: a long row comes "oddly close to the deck ... TOO close"):
## when a card of the spread would lie within DECK_CROWD of the deck (meters, edge to edge), the reader
## slides the deck further out before drawing it - in an episode that draws DECK_ASIDE or under - over
## ASIDE_S seconds, ending as that card is taken.
const DECK_CROWD := 0.07
const DECK_ASIDE := 0.75
const ASIDE_S := 0.45
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
## (seconds) - the opening every show at a table or a desk shares ([ShowOpening]).
const FOCUS_PULL := ShowOpening.FOCUS_PULL
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
var _deck_gone := 0                   # deck meshes gone from the deck (a jumper thrown out of a wash)
var wash_calm := true                # the fan-out calmed (CALM_HZ); a gate's control turns it off
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

var _cur_base := Vector3.ZERO       # where the deck is at the moment being posed (see _deck_at)
var _all_events: Array = []         # every card's timeline, as [method _times] last made it ([method _rest_lift])
var _laps: Array = []               # per card: the cards its place overlaps ([method _laps_of]), for [member _laps_for]
var _laps_for: Array = []
var _moves: Array = []              # the shuffle: [{kind, t0, dur, seed}]
var _move_rng := RandomNumberGenerator.new()
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
var _ride := {}                     # what the table is aboard (Rides.plan), or {} for a table standing still
var _movers: Array = []             # what moves with the ride and the wind: [{node, r, pivot, into, kind, at, contact}] (_tick_ride)


## THE SHUFFLE is a part of its own ([TableShuffle]): every move the deck makes between readings
## and where each card is during one. This file asks it seven things (`shuffle_xf`, `move_at`,
## `deck_turns`, `riffle`, `wash`, `wash_jump`, `sweeps`) and hands it itself to read from.
var _shuffles := TableShuffle.new()


func _init() -> void:
	_things_part.medium = self
	_box_part.medium = self
	_light_part.medium = self
	_card_poses.medium = self
	_shuffles.medium = self


## THE THINGS ON THE TABLE are a part of their own ([TableThings]): where each stands, and what
## stands where - the light, the wash and the blueprint read what stood.
var _things_part := TableThings.new()


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
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
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
	_tick_ride(_now)
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
	# A NEW EPISODE IS A NEW PLAN ([method TablePlan.make]): a function of the document, the set
	# dresser's table as its file says now and the show's intro hold, and nothing of the last one's
	# survives into it. The medium builds from it and decides nothing of its own.
	_source = src
	_plan = TablePlan.make(d, _table_json(pay), feed.intro_hold)
	var spoken: PackedStringArray = _plan.parse.get("spoken", PackedStringArray()) if not _plan.parse.is_empty() \
		else PackedStringArray()
	_follow.reset(spoken, _plan.start_si, _plan.estimated_times(spoken.size()))
	_built_n = -1
	_sched = []
	var t0 := Time.get_ticks_msec()
	_build_episode()
	print("ghost: card table - %s #%d, %d cards, %d actions, %d things (built in %d ms)" % [String(pay.get("show", "?")), _plan.seed_value,
		(pay.get("cards", []) as Array).size(), (_plan.parse.get("actions", []) as Array).size(), _things_part.on_table.size(),
		Time.get_ticks_msec() - t0])


## THE EPISODE BUILT from what its plan decided ([member _plan]): the camera, the light, the cards and
## their faces, the deck, the table and its things, the room.
func _build_episode() -> void:
	# THE CHANNEL'S NAME ONLY: the episode's title is the video's, on the platform, not on the table
	_title.channel = String(_subs.document.get("title", "")) if _subs != null else ""
	# ...and the show's byline under it, when it has one ("with Pen & Ink")
	_title.byline = String(_subs.document.get("byline", "")) if _subs != null else ""
	# THE CHANNEL'S NAME IS THE CHANNEL'S, set the same way every episode - a brand, not a
	# deck's lettering (an uncial deck turned "Truthful" into "Truchful")
	_title.face = CardTable.font("roman")
	_title.italic = CardTable.font(CardTable.BOOK_ITALIC)
	# THE CAMERA, THE LIGHT AND THE ROOM'S DARK, as the plan decided them
	_cam.transform = _plan.cam_base
	_cam.fov = _plan.fov
	_lamp.light_color = _plan.lamp_color
	_lamp.position = _plan.lamp_at
	# AIMED BY ITS OWN TRANSFORM, what look_at does under _root3 (never moved): look_at needs the tree, and
	# the set dresser's table is built out of it, on a worker thread ([method TablePreview._stand])
	var lamp_scale := _lamp.scale
	_lamp.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -0.1) - _lamp.position, Vector3.UP), _lamp.position)
	_lamp.scale = lamp_scale
	_lamp.light_energy = _plan.lamp_base
	_env.background_color = _plan.background
	_env.ambient_light_color = _plan.ambient["color"]
	_fill.light_color = _plan.fill
	_cur_base = _plan.mid
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
	_build_table(_plan.table)
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
		(_face_mats[i] as ShaderMaterial).set_shader_parameter("foil", _plan.foil)
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
		(bk["mat"] as ShaderMaterial).set_shader_parameter("foil", _plan.foil * 0.8)
		for blank in bk.get("blank", []) as Array:
			if back != null and ((blank as Dictionary)["canvas"] as CardFaces.Face).art != back:
				((blank as Dictionary)["canvas"] as CardFaces.Face).art = back
				CardFaces.redraw((blank as Dictionary)["vp"])
			((blank as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("foil", _plan.foil * 0.25)
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
			fmat.set_shader_parameter("foil", _plan.foil)
		for pb in _printed:
			if String((pb as Dictionary).get("series", "")) != String(name):
				continue
			if back != null and ((pb as Dictionary)["canvas"] as CardFaces.Face).art != back:
				((pb as Dictionary)["canvas"] as CardFaces.Face).art = back
				CardFaces.redraw((pb as Dictionary)["vp"])
			# a printed back is read, not shone: its foil kept low
			((pb as Dictionary)["mat"] as ShaderMaterial).set_shader_parameter("foil", _plan.foil * 0.25)
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
			elif _box_part.contents() != "file":
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


## THE TABLE'S THINGS: what the set dresser described for this episode (`table.json` in its folder,
## made safe by [method CardTable.sanitize_table]), or the look's candles alone until it has -
## each built ([Props]), stood where [method TableThings.place] finds it room, its wicks lit - on THE
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
	_root3.add_child(_furniture["node"])
	_apply_painting()
	# its lightness before anything stands on it: a candle looks for dark cloth
	_lum = _surface_lum()
	_lights = []
	_light_part._flame_n = 0
	_things_part.clear(spec["layers"])
	_light_part._heat_cells = {}
	# WHAT THE TABLE IS ABOARD, planned before anything stands on it: each thing's moving parts are made
	# ready to answer it as they are put ([method TableThings.put])
	_ride = Rides.plan(spec.get("ride", {}) if spec.get("ride") is Dictionary else {}, hash([_plan.seed_value, "ride"]))
	_movers = []
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
			things[i] = _things_part.grounded(things[i])
			built.append(Props.build(things[i], spec["materials"], hash([_plan.seed_value, i, "thing"]), true))
		else:
			built.append(Props.build(things[i], spec["materials"], hash([_plan.seed_value, i, "thing"])))
	# THE BOX THE CARDS ARE KEPT IN stands first, where the deck would be: the rest go round it
	_box_part.build(things, built)
	_things_part.place(things, built, rng)
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
	return TablePlan.table_of(_table_json(_plan.pay), _plan.look, _plan.seed_value)


## The set dresser's `table.json` in episode [param pay]'s folder, as parsed - null when there is none
## (or it does not parse) - and its time noted, so a table that lands live is built again.
func _table_json(pay: Dictionary) -> Variant:
	var path := String(pay.get("dir", "")).path_join("table.json")
	_table_mt = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	if _table_mt >= 0:
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			return j.data
	return null


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


# --- the camera ----------------------------------------------------------------------------------------

## The reader's eye: still - or, on a table that rides ([Rides]), given what its mount gives.
func _tick_camera(t: float) -> void:
	# A LOCKED-OFF CAMERA: the table is filmed from a tripod. The Camera dial's breath was a
	# millimeter - nothing anyone could see - so the dial is gone from the panel. ABOARD SOMETHING
	# THAT MOVES the tripod rides with the table, and only its give shows: a faint buzz, a quick nod
	# at a jolt (Rides.camera) - turned about the lens, so what is posed from the camera's place
	# (a card held up, its page) is where it was
	var give := Rides.camera(_ride, t)
	_cam.transform = _plan.cam_base if give == Vector3.ZERO else _plan.cam_base * Transform3D(Basis.from_euler(give), Vector3.ZERO)


# --- what moves ----------------------------------------------------------------------------------------

## A THING'S MOVING PARTS ([Props.build]'s `movers`), made ready to answer the ride and the wind: each one's
## oscillator ([method Rides.responder], from how far it reaches as it stands - the thing's size and scale
## counted), where it is held, the turn from the table's space into its thing's, and where it stands on
## the table (for the eddies of the wind there). Past [constant Rides.MAX_MOVERS] on a table, a thing's stand as built.
func _take_movers(b: Dictionary, node: Node3D) -> void:
	var into := node.transform.basis.orthonormalized().inverse()
	var sized := float(b.get("sized", 1.0)) * node.transform.basis.get_scale().x
	var inner: Node3D = node.get_child(0) if node.get_child_count() > 0 else node
	for m in b.get("movers", []):
		if _movers.size() >= Rides.MAX_MOVERS:
			return
		var md: Dictionary = m
		var move: Dictionary = md["move"]
		var pivot: Vector3 = md["pivot"]
		_movers.append({"node": md["node"], "pivot": pivot, "into": into, "kind": String(move["kind"]),
			"r": Rides.responder(_ride, move, float(md["reach"]) * sized, int(md["salt"])),
			"at": node.transform * (inner.transform * pivot), "contact": md.get("contact", PackedVector3Array())})


## EVERY MOVING PART at show time [param t] ([method Rides.pose]): turned about where it is held - a lean
## about the level axis square to it (a hanging thing's weight swung that way, a rock tipped on the edge of
## what it rests on furthest the way it leans - [method Props._contact]), a turn about the up - inside its
## thing, so the light and its shadows follow.
func _tick_ride(t: float) -> void:
	for m in _movers:
		var md: Dictionary = m
		var node: Node3D = md["node"]
		if not is_instance_valid(node):
			continue
		var pose := Rides.pose(_ride, _wind, md["r"], t, md["at"])
		var lean: Vector2 = pose["lean"]
		var into: Basis = md["into"]
		var kind := String(md["kind"])
		var pivot: Vector3 = md["pivot"]
		var rot := Basis.IDENTITY
		var turn := float(pose["turn"])
		if absf(turn) > 1e-7:
			rot = Basis(Vector3.UP, turn)
		# a lean toward d turns its top (or, hanging, its weight) toward d: about up x d
		var axis := Vector3(lean.y, 0.0, -lean.x) * (-1.0 if kind == "swing" else 1.0)
		var a := axis.length()
		if a > 1e-7:
			rot = Basis((into * (axis / a)).normalized(), a) * rot
			var contact: PackedVector3Array = md["contact"]
			if kind == "rock" and not contact.is_empty():
				var d := into * Vector3(lean.x, 0.0, lean.y)
				var far := -INF
				for c in contact:
					if c.dot(d) > far:
						far = c.dot(d)
						pivot = c
		node.transform = Transform3D(rot, pivot - rot * pivot)


## THE INTRO IS OUT OF FOCUS: the whole frame thrown far out of focus while the channel's name is
## up - nothing on the table to be made out, only its colors - then the focus PULLS as the reading
## opens (the deck's shuffle, the box's opening): the wide blur lifts, and the lens carries on near
## to far, the cloth in front of the reader first, and is off for the reading. The end card leaves it alone.
func _tick_focus(t: float) -> void:
	_lens(ShowOpening.pull(t, float(_times()["opening"]), not _sched.is_empty()))


## The lens at [param pull] of the intro's focus pull ([method ShowOpening.lens]).
func _lens(pull: float) -> void:
	ShowOpening.lens(pull, _blur, _attrs)


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
	for th in _things_part.on_table:
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
			top = _cur_base.y + float(_plan.deck_n - _deck_gone - _taken_by(t)) * DECK_T
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
	_shuffles.move_at(120.0)


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
		var inner: AABB = _box_part.stood.get("inner", AABB(_plan.deck_base, Vector3.ZERO))
		return Vector3(inner.get_center().x, inner.position.y, inner.get_center().z) if not _box_part.stood.is_empty() else _plan.deck_base
	var first: Array = tm["first"]
	if first.is_empty():
		return _plan.mid
	var s := maxf(float(first[1]), 0.05)
	var go := SQUARE if String(first[2]) != "jumper" else JUMP_RIFFLE
	if not wj.is_empty():
		go = (float(wj["end"]) - float(first[0])) / s
	var u := clampf(((t - float(first[0])) / s - go) / PUSH_SLIDE, 0.0, 1.0)
	if u >= 1.0 and _plan.aside_card >= 0:
		# PUT ASIDE before the card that would crowd it is taken ([method TablePlan.put_aside])
		var d: Array = (tm["draw"] as Array)[_plan.aside_card]
		var taken := float(d[0]) + float(d[3]) * float(d[1])
		var v := clampf((t - (taken - ASIDE_S)) / ASIDE_S, 0.0, 1.0)
		return _plan.deck_base.lerp(_plan.deck_far, _ease(v)) + Vector3(0.0, sin(PI * v) * 0.003, 0.0)
	return _plan.mid.lerp(_plan.deck_base, _ease(u)) + Vector3(0.0, sin(PI * u) * 0.004, 0.0)


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
	var side := signf(_plan.deck_base.x)
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
	# a move the first card cuts off is finished, not undone ([method TableShuffle.finish_xf])
	var cut := _shuffles.cut_off(ts, te) if chained and wj.is_empty() and jump_s == 0.0 else {}
	if not cut.is_empty():
		settled += SQUARE
	var top_slot := _plan.deck_n - 1 - _deck_gone - _taken_by(t)
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
				xf = _shuffles.finish_xf(i, t, ts, te, cut) if not cut.is_empty() \
					else _shuffles.shuffle_xf(i, te - ts).interpolate_with(_rest_xf(i), _ease((t - te) / SQUARE))
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
		dm.visible = i != gone and i <= top_slot and (_plan.cards_from != "box" or bool(_box_part.stood.get("flat", false)))
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


## The card waiting on top of the deck: the next to be taken off it ([method _leaves]) - a jumper until
## its action begins - so the deck's top card is turned the way the card it is comes up, and the back
## exposed when it is taken already lies the way of the card after it.
func _top_deck_reversed(t: float, tm: Dictionary) -> bool:
	var draws: Array = tm["draw"]
	for k in mini(draws.size(), _cards.size()):
		if t < (_leaves(k) if _from_top(k) else float((draws[k] as Array)[0])):
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


## Drawn card [param k] lying on top of the deck, face down (the way it will come up): the deck's own top
## card as the hand takes it ([method _taken_by]) - in its slot, turned as it lies, a card's thickness
## from the slot under it. A jumper, which flies out of the deck rather than off its top, rides on it.
func _deck_top_xf(k: int) -> Transform3D:
	var slot := _plan.deck_n - 1 - _deck_gone - _taken_before(k) + (0 if _from_top(k) else 1)
	var j: Vector3 = _plan.slot_jit[slot] if slot >= 0 and slot < _plan.slot_jit.size() else Vector3.ZERO
	return Transform3D(Basis(Vector3.UP, j.z + (PI if _reversed(k) else 0.0)),
		_cur_base + Vector3(j.x, float(slot) * DECK_T + CARD_T * 0.5, j.y))


## THE CARDS TAKEN OFF THE DECK'S TOP: a drawn, dealt or swept card is the deck's own top card until the
## hand takes it, and the deck is a card shorter from then. It was a card of its own laid over the whole
## deck, there from the moment its move was scheduled: at the end of a shuffle it appeared on the top
## while the last packet of the shuffle was still coming down through where it lay (true-tarot 288024,
## the user, 2026-10-18: a card "pops" to the top "or appearing out of nowhere").
## Whether card [param k] comes off the deck's top (a jumper flies out of it).
func _from_top(k: int) -> bool:
	if k >= _all_events.size():
		return false
	for e in _all_events[k]:
		if String((e as Dictionary)["k"]) == "arrive":
			return String((e as Dictionary)["how"]) in ["draw", "deal", "fan"]
	return false


## When card [param k] leaves the deck: the start of its draw or deal, or its turn in a waterfall - the
## moment it first moves ([method TableCardPose.card_pose]) - or INF before it is scheduled.
func _leaves(k: int) -> float:
	if k >= _all_events.size():
		return INF
	for e in _all_events[k]:
		var d: Dictionary = e
		if String(d["k"]) == "arrive":
			var each := TableActions.FAN_EACH * float(d.get("i", 0)) if String(d["how"]) == "fan" else 0.0
			return float(d["t0"]) + (float(d["off"]) + each) * maxf(float(d["s"]), 0.05)
	return INF


## How many cards have been taken off the deck's top by [param t].
func _taken_by(t: float) -> int:
	var n := 0
	for k in mini(_cards.size(), _all_events.size()):
		if _from_top(k) and _leaves(k) <= t:
			n += 1
	return n


## How many cards are taken off the deck's top before card [param k].
func _taken_before(k: int) -> int:
	var n := 0
	for j in mini(k, _all_events.size()):
		if _from_top(j) and _leaves(j) < INF:
			n += 1
	return n


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
	return ShowOpening.title_alpha(t, float(_times()["opening"]), not _sched.is_empty())


## THE OUTRO: once the voice has said its last word, the table fades to black - a beat after it,
## and black exactly as the outro's silence runs out (the take's own tail in a render, the
## Director's outro live). A function of show time like everything else, so a live reading, a
## scrub and the export fade alike. 1 until then.
func _end_fade(t: float) -> float:
	return ShowOpening.end_fade(t, _follow,
		(_plan.parse.get("spoken", PackedStringArray()) as PackedStringArray).size(), feed.tail())



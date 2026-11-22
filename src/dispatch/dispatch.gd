extends Medium
class_name DispatchMedium

## DispatchMedium - one desk, late at night, in a hollow under the ground, seen from the chair (next/dispatch.md). The man
## who works it is never seen: the viewer sits where he sits, and everything on the desk moves on its own.
##
## It draws from the reading's document: its `source`, the note with its marks ([DispatchScript]); its `dispatch`, what
## the Dispatch desk's rows on the Medium card hand ([method DispatchFormat.document]): the desk's `seed` and each
## picture's file (`pictures`). The desk ([DispatchSet]) is built from the note's `desk:` block (the phones' labels) and
## the seed; the roots ([DispatchRoots]) from the seed. A seed changed while the note plays draws the desk again at once and
## keeps the reading's place ([method reseed]).
##
## The desk acts in the rests the voice leaves for it ([method _place]): each action of the script before its spoken
## word, placed back from that word by what the script wrote after it in the same silence (or on from the word before
## when the next is not heard yet) and, once begun, kept where it began ([member _held]; a live reading's words arrive a
## sentence at a time). Everything on the desk is then a pure function of show time ([method _pose]), so a render draws
## what the live reading drew and a scrub lands where the reading is.
##
## The camera sits in the chair and turns to what is active ([method _attention], [constant SPOTS]): a phone ringing, the
## terminal while it types or shows something, the radar on a ping, the receiver while it plays static, a picture landing
## on a screen, the printer, the bell, the lamp switched (the whole desk, to see it go dark). `look:` turns it on purpose
## and it stays, as the gain knob holds it on the radar. It leans toward what it looks at and its lens closes in on the
## small things, on critically damped springs ([constant SPRING_TAU]); with nothing new for a while it eases back to the
## whole desk, with a slow breath of wander under it. Every look holds long enough to settle ([constant LOOK_LEAST]), a
## ping to the end of the sentence said over it ([constant PING_HOLD]), and it never leaves a thing only to come straight
## back ([constant AWAY_LEAST]).
##
## A phone in hand is held to the ear: it rises out of its row, flips open and floats up beside the camera, in the frame's
## lower right, its screen saying who is on it and for how long, and goes back the same way. A call is speed-dialed: the
## phone comes up before the eye, 1 is held and Send pressed, then it goes to the ear for the rings. One on hold lies open
## on the desk in front of the rows. A phone ringing buzzes and rattles in its row. A text chimes and the phone comes up
## open before the eye with the message on its screen, never captioned; a reply is typed into it as it is said, under the
## message, and sent; then it goes home.
##
## The receiver is open in its storms and under a voice that comes in on it ([method _build_receiver]): the storm brought
## down while the voice is said over it, the needle swinging with the storm and each word, the scope tracing the receiver's own
## output as a scope across its speaker would ([DispatchScope]: its static, and the voice's real waveform). The SDR
## screen standing on the scope draws the band's spectrum and waterfall from the same stretches, and the voice's own spectrum
## from the heard audio's bands while that voice speaks ([DispatchSpectrum]).
##
## The subtitles caption what cannot be read on the desk, as the letter's do: speech, never the words typed on the
## terminal as they are said or lit on the tablet's page as they are read off it ([method _captioned]); a text is read on
## its phone and nowhere else.
##
## Redacted words on the terminal are hidden over the frame ([DispatchCensor], [method _censor_at]): drawn after the 3D
## and before a picture over the whole screen, so a picture covers it.

## The spots the camera turns to, and `look:` names ([method DispatchSet._spots] says where each is).
const SPOTS := {
	"home": {"label": "The desk", "blurb": "The whole desk, seen from the chair."},
	"terminal": {"label": "The terminal", "blurb": "Close on the terminal's screen, near enough to read it."},
	"keyboard": {"label": "The keyboard", "blurb": "Down at the keyboard."},
	"phones": {"label": "The phones", "blurb": "The two rows of phones, their names on the tape."},
	"radar": {"label": "The radar", "blurb": "The round green scope, its sweep and the blip."},
	"receiver": {"label": "The receiver", "blurb": "The shortwave receiver, its dial, needle and the scope on it."},
	"printer": {"label": "The printer", "blurb": "The printer at the desk's end and its paper falling to the heap."},
	"chart": {"label": "The chart", "blurb": "The chart of the council's hours, taped down."},
	"handbook": {"label": "The handbook", "blurb": "The fat binder labeled HANDBOOK."},
	"switch": {"label": "The switch", "blurb": "The switch box, GOOD above and BAD below."},
	"mug": {"label": "The mug", "blurb": "The mug in its ring of old coffee."},
	"feed": {"label": "The security monitor", "blurb": "The little black-and-white monitor."},
	"satellite": {"label": "The satellite's monitor", "blurb": "The flat monitor that looks down from orbit."},
	"tv": {"label": "The television", "blurb": "The small old television with its rabbit ears."},
	"clock": {"label": "The clock", "blurb": "Close on the little flip clock's cards."},
	"tablet": {"label": "The tablet", "blurb": "The tablet held up before the eye."},
}
## The camera's springs (seconds): how long it takes to settle on what it turns to (critically damped), after a lead that
## eases every move in so none starts with a jolt - slow and gentle, as the night is; and how long after the last thing it
## looked at it waits before easing back to the whole desk.
const SPRING_TAU := 1.7
const LEAD_TAU := 1.1
## How long after it turns to a thing the camera is on it, by those springs (seconds).
const CAMERA_ARRIVES := 8.0
const HOME_AFTER := 9.0
## The tablet laid down leaves nothing where it was held: the camera stays there this long after the hand begins to lay it
## down (seconds), then goes to the whole desk - or straight on to what is turned to next, where that begins within as long
## again.
const TABLET_LEAVE := 1.0
## Two looks at the same thing this close (seconds; words said at WORD_EST each, for one whose words are not heard yet) are
## one: the camera holds between them rather than ease away and straight back.
const SAME_BRIDGE := 45.0
const WORD_EST := 0.4
## Its wander (m at the aim, a slow breath) and how fast.
const WANDER := Vector3(0.010, 0.006, 0.006)
const WANDER_RATE := 0.11
## The radar: its sweep's round (seconds), how many of its paints of the target it keeps fading behind the newest,
## an aircraft drifting across it now and then (a pass's seconds; one starts in the first half of every stretch this long, so
## the scope is empty of them most of the night).
const SWEEP := 2.5
const TRAIL := 6
const PLANE_PASS := 70.0
const PLANE_EVERY := 900.0
## The target's track ([method track_of]): how far he goes on the scope a second of a ping's seconds (its radius 1), a
## step's least and most, the step of a ping that says no seconds, how far a place's comma puts it off its head, how
## sharply the track turns (radians), how far out the whole track may reach; a bare ping's leg at most (seconds), and a
## paint's give-or-take.
const TRACK_PACE := 0.018
const WALK_WORD := 0.42
const STEP_LEAST := 0.05
const STEP_MOST := 0.4
const STEP_BARE := 0.13
const STEP_OFF := 0.04
const TURN_MOST := 0.7
const TRACK_EDGE := 0.82
const LEG_MOST := 14.0
## The radar's clutter ([method clutter_at]): the most blips the scope ever paints (at gain 10), how sharply their number
## grows with the knob, the building they stand in round him (on the scope, its edge 1), how near him the nearest may be,
## how far the few who move drift (one in [constant CLUTTER_MOVING]), and how long a blip the gain no longer reaches takes
## to fade (seconds). Each blip is painted by the sweep as the target is, dimmer and with no name, and a little off where
## it was each round.
const CLUTTER_MOST := 40
const CLUTTER_CURVE := 1.25
const CLUTTER_BUILDING := Vector2(0.40, 0.18)
const CLUTTER_NEAR := 0.022
const CLUTTER_MOVING := 4
const CLUTTER_DRIFT := 0.012
const CLUTTER_FADE := 4.0
const CLUTTER_JITTER := 0.004
## The chair's own blip: from this gain the scope paints whoever sits at this desk too, as faint as the clutter and
## with no name, just off the desk's mark at its middle on the chair's side; it fades with the clutter as the knob goes down.
const CHAIR_GAIN := 9
const CHAIR_AT := Vector2(0.0, 0.04)
## The lamp going out: the filament's glow dies over this long (seconds), and comes up over the first part of it.
const LAMP_FADE := 0.18
## The grid going down ([method power_at]): this far into its rest the breaker goes (its thunk), every glow gone over POWER_FADE,
## flickering as it goes (a tube's picture collapsing to its dot inside it); back up as quickly.
const POWER_AT := 0.25
const POWER_FADE := 0.45
## A film on a screen ([method film_at]): its glass waking from a dot over FILM_WAKE before its first frame moves; its last frame held
## FILM_HOLD after it ends, then the glass going down as it came up.
const FILM_WAKE := 0.6
const FILM_HOLD := 0.8
## What on the desk runs on its own batteries, and so stays lit when the grid goes down.
const BATTERY := ["tablet"]
## A note played inside the desk ([NestedShow]), by path: it compiles a Director, which a desk that plays no note never needs.
const NESTED := "res://src/show/nested_show.gd"
## The camera on the radar as the target sets off (seconds, at least): it stays while he walks, to the ping where he
## arrives, [constant MOVING_HOLD_MOST] at most, so a drive is a glance, never a stare.
const MOVING_LOOK := 3.0
const MOVING_HOLD_MOST := 12.0
## A ping holds the radar (seconds from its ring): at least this long, on to the end of the sentence being said then if it
## ends by the most; then it lingers this long before it goes home - time for the camera to get there and the blip to be
## seen, at the camera's slow pace.
const PING_HOLD := 12.0
const PING_HOLD_MOST := 16.0
const PING_LINGER := 4.0
## What the camera turns to is seen (seconds; the camera takes about eight of them to arrive): every look holds at least
## [constant LOOK_LEAST] from its start, unless something else begins first; and the camera never leaves a thing for less
## than [constant AWAY_LEAST] - it stays on what it was on rather than pull back to the whole desk for less than that before
## it turns again.
const LOOK_LEAST := 10.0
const AWAY_LEAST := 12.0
## A look cut by the next sooner than this (seconds) is not taken: the camera would only swerve toward it.
const GLANCE_LEAST := 3.0
## What the camera turns to to read (the terminal's words, a phone's message, a picture): always looked at.
const TO_READ := ["session", "type", "strike", "text", "reply", "picture", "live", "tablet", "fade"]
const PAINT_JITTER := 0.006
## A phone at the ear, in the camera's frame (m): where it floats, and how it is turned (degrees: tipped, turned, rolled).
const EAR := Vector3(0.165, -0.105, -0.36)
const EAR_TURN := Vector3(58.0, -28.0, -18.0)
## A phone held up to be read or dialed, in the camera's frame (m): low in the middle of the picture, open, its screen to
## the eye and leaning back a little (degrees about its width: 90 holds it straight up at the eye).
const READ := Vector3(0.0, -0.118, -0.27)
const READ_LEAN := 74.0
## A phone ringing rattles this far (m) and turns this much (degrees).
const RATTLE := 0.0025
const RATTLE_TURN := 3.0
## The mug, drunk from: where its foot comes to in the camera's own frame (m: well under the eye and barely in front of it,
## the mouth, so the whole mug is out of the picture whichever way the camera looks); how far it is lifted out of its ring before
## it goes toward the mouth, at the least and at the most (m: higher only to clear what stands under its way); how much lower than
## the mouth it comes up to it from, and from how far nearer the desk; and how far it keeps over what it passes over (m).
const MUG_MOUTH := Vector3(0.03, -0.17, -0.01)
const MUG_LIFT := Vector2(0.06, 0.32)
const MUG_UNDER := 0.06
const MUG_NEARER := 0.12
const MUG_GAP := 0.02
## A thing carried off the desk ([method _carry]): the share of its way it spends going straight up out of where it stood (and
## straight down into where it goes), and how far over what lies under its way it is carried (m).
const CARRY_RISE := 0.3
## How high over the desk's top the tablet is carried between its place and the hand (m): at the least, and at the most (above
## the hand only where no way round clears what stands under it, [method tablet_route]).
const TABLET_OVER := Vector2(0.05, 0.45)
## ...and, where the straight way is not clear, how far it is drawn out toward the chair past the hand before it is brought
## across (m, [method _tablet_vias]).
const TABLET_DRAW := 0.25
## The tablet's screen once it is laid down: left lit this long (seconds), dimmed to this share for the last of them, then dark
## in a moment - a screen locking itself.
const TABLET_LOCK := 30.0
const TABLET_DIM := 5.0
const TABLET_DIMMED := 0.35
const TABLET_OFF := 0.4
## How far past the last word heard the clock's turns are planned (seconds), while the reading's end is not heard yet.
const CLOCK_AHEAD := 180.0
## How far ahead of the playhead the plan knows the reading before more of it heard makes it again (seconds, [method
## take_words]): past the longest thing it looks ahead for (a look bridged to the same thing again, [constant SAME_BRIDGE]).
const PLAN_AHEAD := 60.0
const CARRY_GAP := 0.025
## The terminal's cursor blinks this often (seconds).
const BLINK := 0.53
## The camera on the terminal after a block or a said line: the glass read at GLASS_WORD a word on it, held GLASS_LEAST to
## GLASS_MOST, on to the end of the sentence the voice is in if that ends within GLASS_SENTENCE; then it stays on the panel
## left up however long the voice goes on about it (GLASS_LINGER: never pulled back to the whole desk for nothing) - until
## something else is looked at, or the script says `<!-- look: home -->`.
const GLASS_WORD := 0.3
const GLASS_LEAST := 6.0
const GLASS_MOST := 16.0
const GLASS_SENTENCE := 6.0
const GLASS_LINGER := INF
## A note that opens in the black goes down to it as its title goes: from this long before the opening to this long after,
## as [method ShowOpening.title_alpha] fades the name out.
const BLACK_LEAD := 0.6
const BLACK_TAIL := 0.3
## The tablet's page: eased to what is said over EASE seconds, what is said kept this far down the view; with nothing said
## on it, eased down the page over the time it is up (GLIDE_LEAST seconds or more: a page left sooner stays where it is),
## never faster than GLIDE pixels a second (a reader's skim, never past where its writing ends: the desk's pages have no
## padding), or DRIFT pixels a second while how long it is up is not known. A word said is followed where it is this long
## and the word said after it is the next one there (a phrase, never one stray word), or where it reads on from the last word
## followed; a run of READ_RUN words read on lights them as the tablet medium lights what its voice reads; a word is looked
## for this many words on from the last. What the finger goes to is brought this far down the view (a link, a search box;
## a message box, which the keyboard rises under), unless it is in view already, this far from the view's edges. The
## keyboard rises and goes down over KEYBOARD seconds, a key under the finger shows for KEY_SHOWN seconds.
const PAGE_EASE := 0.9
const PAGE_GLIDE := 36.0
const PAGE_GLIDE_LEAST := 2.0
const TAP_KEEP := 0.4
const BOX_KEEP := 0.3
const TAP_MARGIN := 0.06
const KEYBOARD := 0.45
## How far above the keyboard a live page's message box stands while a reply is typed (px on the tablet's screen).
const KEYBOARD_CLEAR := 18.0
## A live page's sound is tapped on this long before a voice heard through the tablet begins, and off this long after it
## ends (s).
const SOUND_LEAD := 0.45
const SOUND_TAIL := 0.5
const KEY_SHOWN := 0.18
## How bright the tablet's screen glows lit (the tablet medium's own is 1.15, in a lighter room): a page read in the dark of
## the desk keeps its words' color, its white just under full at the hollow's exposure ([constant EXPOSURE]), never blown out.
const TABLET_GLOW := 0.6
const PAGE_KEEP := 0.32
const PAGE_DRIFT := 18.0
const FOLLOW_LETTERS := 5
const READ_RUN := 3
const FOLLOW_WINDOW := 400
## The live picture: its camera behind the chair, and its viewport's size.
const LIVE_EYE := Vector3(0.32, 1.48, 1.95)
const LIVE_AIM := Vector3(-0.05, 0.86, -0.15)
const LIVE_SIZE := Vector2i(480, 360)
## What the show is told it waits for while the desk is built ([method ShowFeed.wait_for]).
const WAIT_FOR := "the desk"
## A gate's: build on a worker as the app does, though a gate's frames otherwise wait for nothing.
static var away_in_tests := false
## A picture over the whole screen: its fade.
const IMAGE_FADE := DispatchScript.IMAGE_FADE
## The least lead an action has after the word before it (seconds).
const LEAD := 0.12
## The receiver under a voice heard through it ([method _build_receiver]): open this long past its last word, carried on
## from a stretch that ended at most this long before it began, and its voice said over from a little before its first
## word to a little past its last.
const RECEIVER_TAIL := 1.2
const RECEIVER_JOIN := 1.0
const UNDER_LEAD := 0.25
const UNDER_TAIL := 0.35
## The title typed over the opening: a paler phosphor than the terminal's own, taking the hue picked for its text.
const TITLE_INK := Color(0.62, 1.0, 0.68)
## The environment: the hollow's fog and its ambient light.
const FOG := Color(0.11, 0.12, 0.135)
const AMBIENT := Color(0.18, 0.2, 0.24)
const AMBIENT_ENERGY := 0.22
## The hollow's own light, where the Environment chooses none: the exposure it is seen at, the faint fill from above and the cold
## shaft down through a crack behind the desk (where it falls from and what it falls on) - and how strongly candles out of the shot
## burn where a light chooses candles and no lamp.
const EXPOSURE := 1.25
const FILL_COLOR := Color(0.55, 0.62, 0.75)
const FILL_ENERGY := 0.1
const CRACK_COLOR := Color(0.62, 0.7, 0.82)
const CRACK_ENERGY := 6.0
const CRACK_AT := Vector3(0.5, 3.35, -1.6)
const CRACK_AIM := Vector3(-0.1, 0.4, -1.1)
const CANDLES_ENERGY := 0.45
## Where shafts chosen on the Environment fall - all round the chair, behind the desk among the roots and out to either side of
## it, so light comes down wherever the camera turns - and what drifts keeps to, anywhere in each (the camera turns): round the
## desk and past both its ends, the hollow behind it, the whole hollow.
const RAYS_ROUND := [AABB(Vector3(-3.0, 0.35, -1.0), Vector3(1.4, 0.0, 2.6)), AABB(Vector3(-2.4, 0.35, -2.5), Vector3(4.8, 0.0, 1.5)),
	AABB(Vector3(1.6, 0.35, -1.0), Vector3(1.4, 0.0, 2.6))]
const AIR_NEAR := AABB(Vector3(-2.6, 0.6, -1.2), Vector3(5.2, 0.9, 2.2))
## How many more motes round the desk than the Environment's own count, for the air there reaching past both its ends.
const AIR_NEAR_MORE := 2.2
const AIR_FAR := AABB(Vector3(-3.0, 0.0, -3.2), Vector3(6.0, 2.6, 2.4))
const AIR_ROOM := AABB(Vector3(-3.0, 0.0, -3.0), Vector3(6.0, 3.3, 4.0))

var _subs = null
var _doc_key := ""                      # the document as last loaded, but for its seed ([member _doc_seed])
var _doc_seed := 0
var _seed := 1
var _parsed := {}
var _known_to := -INF                   # the end of the last word heard when the plan was last made ([method take_words])
var _fades := PackedInt32Array()        # which actions are fades ([method fade_at]), for the list [member _fades_of]
var _fades_of: Array = []
var _parsed_of := ""                    # the source it was read from: handed again (a reading started part way), it is kept
var _est := PackedFloat32Array()        # each word's moment by the steady voice's estimate, made once a source ([method _estimate])
## Which spoken words end a sentence ([method DispatchScript.sentence_ends]).
var _ends := PackedByteArray()
var _actions: Array = []
var _spans: Array = []
var _moves: Array = []
var _spoken_n := 0
var _typed_words := PackedByteArray()   # a spoken word -> 1 when it is typed on the terminal as it is said
var _follower := ReadingFollower.new()
var _midway := false                    # the reading started part way (its document names start words): no intro
var _since := 0.0                       # a mid-way start: how far into the reading it starts (s, the scrub bar's scale)
var _est_from := 0.0                    # ...and where its first word falls on the steady voice's estimate (s)
var _built_n := -1
var _t0 := PackedFloat32Array()        # each action's start (INF until placed)
var _sp := PackedFloat32Array()        # ...and its speed (1, or quicker where its silence was short)
var _held := {}                         # an action begun -> [t0, speed]
var _chars := {}                        # a typed block's action -> each of its characters' moments
var _phone_moves: Array = []            # {label, from, to, t0, dur, slot, how}
var _attn: Array = []                   # {t0, t1, spot: Dictionary, sticky}
var _legs: Array = []                   # the target's track: {i, place, from, to, t0 (he leaves), t1 (he arrives)}
var _clutter: Array = []                # where the radar's clutter stands round him, nearest first ([method clutter_of])
var _leg_known := {}                    # a bare ping's action -> the show time a plan first placed it
var _term := {}                         # the note's terminal: its title, width and keys ([method DispatchTerminal.config_of])
var _rings := 4.0                       # the radar's range rings: a ping's range in them, the scope's edge the last
var _term_key := Vector2(NAN, NAN)      # the moment [method terminal_at] last drew, and whether whole...
var _term_at := {}                      # ...and what it drew
var _wants := {}                        # the things the script uses that only some desks have: clock, tablet
var _makes := {}                        # the makes chosen for the desk's parts, and the desk and its roots ([method makes_of])
var _feed_static := 0.12                # how much snow shows over the security monitor's picture ([method DispatchSet.feed_static])
var _dark0 := false                     # the note opens in the black, until its first fade up
var _tablet_doc := {}                   # the tablet's pages as the tablet medium reads them ([TabletScript])
var _tablet_pages := {}                 # ...a page's index -> its [TabletPage], set when first shown
var _clips := {}                        # a clip's key -> its frames ([method Illustrations.clip_of])
var _clip_tex := {}                     # ...and the frame it shows: {i, tex}
var _black: ImageTexture                # a player with nothing playing
var _follow := {}                       # a page's action -> where it scrolls to as words on it are said ([method _page_follow])
var _tablet_char0 := PackedInt32Array() # a page word -> its first letter's place in the pages' text (for the hues it is lit in)
var _tablet_hue0 := 0.0
var _sound_plan: Array = []
var _sound_rev := 0
var _open: Array = []                   # where the receiver is open ([method _build_receiver])
var _now := 0.0
var _last_now := -1.0
var _last_tick := 0                     # when the desk last advanced (the machine's clock, usec): a stall told from a seek
var _snap := true
var _labels := PackedStringArray()
var _built_for := ""
var _pictures := {}                     # a picture's key -> its texture
var _build_task := -1                   # the set's build on a worker, -1 for none
var _pic_task := -1                     # ...the pictures' decoding
var _pic_of := ""                       # the files the pictures up (or on their way) are of ([method _pictures_of])
var _decoded := {}                      # ...what it decoded, waiting to be made textures
var _made := {}                         # ...what it made, waiting to be put in
var _tablet_route := Vector3.ZERO       # how the tablet is carried on this desk: what its way bends by, how high ([method tablet_route])
var _feeds := {}                        # what each thing on the desk is fed now ([method _pose]), by thing
## What is round the desk, as the document's Environment chooses it ([Surroundings], made safe; [method _dress_environment]): its
## light (none chosen: the hollow's own), how bright, the shafts that fall through the ceiling, what drifts in the air, and how
## strongly each lit thing on the desk shines.
var _surround := Surroundings.sanitize({})
var _surround_key := "-"
var _crack: SpotLight3D = null          # the hollow's own shaft, down through a crack behind the desk
var _rays: Node3D = null                # the shafts the Environment chooses in its place
var _candles: OmniLight3D = null        # candles out of the shot, where the light chosen burns them and no lamp
var _air = null                         # what drifts in the air ([Effects]' Air), or null
var _lamp_share := 1.0
var _crack_energy := 0.0                # the hollow's own shaft as dressed, before an `environment:` mark dims it
var _films := {}                        # what each `play` plays -> what it is ([method ScreenPlays.record_of])
var _players := {}                      # ...a video file's [ScreenFilm], made when first shown
var _shows := {}                        # ...a note's [NestedShow], made when it comes up and let go when it goes
var _loads := {}                        # ...a note's song and bake being read on a worker: {task, box}
var _dt := 0.0                          # this frame's step, for a note played inside the desk
var _power_now := 1.0                   # how much power the desk has this frame ([method power_at])
var _glass_power := 1.0                 # the same without its flicker, for the screens' glass
var _of_kind := {}                      # `play`, `power`, `environment` -> the actions of that kind, in order
var _cut_by := {}                       # a `play` -> the next action that puts something else on its screen (-1 none)
var _film_now := {}                     # each screen -> the film on it this frame ([method film_at])
var _waiting := false                   # the show held for it

var _placeholder: GhostScene
var _root3: Node3D
var _cam: Camera3D
var _attrs: CameraAttributesPractical
var _env: Environment
var _set: DispatchSet
var _set_node: Node3D
var _roots: DispatchRoots
var _roots_node: Node3D
var _screens: DispatchScreens
var _night := "?"                # the document's night the chart was last handed ([method DispatchScreens.set_night]); none yet
var _spectrum: DispatchSpectrum         # the receiver's SDR screen: its waterfall's rows as they are made
var _bands := PackedFloat32Array()      # the heard audio's bands this frame ([AudioFeatures], handed to [method advance])
var _heard: AudioFeatures               # ...and the whole frame, its waveform the scope's ([member _scope])
var _scope: DispatchScope               # the receiver's oscilloscope: its trace worked out on a worker
var _sounds: DispatchSounds
var _blur: IntroBlur
var _censor: DispatchCensor
var _after_censor: BackBufferCopy       # what reads the frame after the censor (the intro's blur) reads it censored
var _title: TitleCard
var _plate: LetterMedium.Plate
var _live_vp: SubViewport
var _live_cam: Camera3D
var _stage_was := {}
var _fill: DirectionalLight3D
var _mats := {}                         # a screen's or phone face's ShaderMaterial, by name

var _f_aim := Vector3.ZERO                # where the camera is led toward, eased in ([constant LEAD_TAU])...
var _f_eye := Vector3.ZERO
var _f_fov := 50.0
var _c_aim := Vector3.ZERO
var _v_aim := Vector3.ZERO
var _c_eye := Vector3.ZERO
var _v_eye := Vector3.ZERO
var _c_fov := 50.0
var _v_fov := 0.0


# --- mount -------------------------------------------------------------------------------------------------------------

func mount(st: SubViewport) -> void:
	super.mount(st)
	_stage_was = {}
	for key in TableMedium.STAGE:
		_stage_was[key] = st.get(key)
		st.set(key, TableMedium.STAGE[key])
	_placeholder = GhostScene.new()
	_placeholder.init_with_seed(1, "drift")
	_placeholder.visible = false
	add_child(_placeholder)
	_screens = DispatchScreens.new()
	add_child(_screens)
	_spectrum = DispatchSpectrum.new()
	_scope = DispatchScope.new()
	_build_world()
	_censor = DispatchCensor.new()
	add_child(_censor)
	_plate = LetterMedium.Plate.new()
	_plate.material = ShaderMaterial.new()
	(_plate.material as ShaderMaterial).shader = LetterMedium._plate_shader()
	add_child(_plate)
	_after_censor = BackBufferCopy.new()
	_after_censor.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_after_censor.visible = false
	add_child(_after_censor)
	_blur = IntroBlur.new(ShowOpening.INTRO_SHADER)
	add_child(_blur)
	_title = TitleCard.new()
	_title.face = CardTable.font("typed")
	_title.italic = CardTable.font("typed")
	_title.ink = TITLE_INK
	add_child(_title)
	_sounds = DispatchSounds.new(self)


func _build_world() -> void:
	_root3 = Node3D.new()
	add_child(_root3)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.006, 0.007, 0.008)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = AMBIENT_ENERGY
	# the tonemapper, as the Look has it ([Tonemaps]): Filmic unless a note picks another, at the exposure tuned under Filmic - the
	# Environment's brightness over it ([method _dress_environment])
	Tonemaps.dress(_env, EXPOSURE)
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.0
	_env.fog_enabled = true
	_env.fog_light_color = FOG
	_env.fog_density = 0.2
	_env.fog_aerial_perspective = 0.0
	_env.fog_sky_affect = 0.0
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = Color(0.7, 0.72, 0.75)
	_env.volumetric_fog_length = 8.0
	_env.adjustment_enabled = true
	# bounce light, as the Graphics panel has it (off unless chosen: it changes the look)
	Graphics.dress(_env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.near = 0.03
	_cam.far = 30.0
	_cam.environment = _env
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_cam.attributes = _attrs
	_root3.add_child(_cam)
	# a faint cold light from somewhere above, so the roots stand out of the dark
	_fill = DirectionalLight3D.new()
	_fill.light_color = FILL_COLOR
	_fill.light_energy = FILL_ENERGY
	_fill.rotation_degrees = Vector3(-62.0, 25.0, 0.0)
	_root3.add_child(_fill)
	# ...and down through a crack in the ceiling behind the desk: cold light falling through the fog onto the roots there
	var crack := SpotLight3D.new()
	crack.light_color = CRACK_COLOR
	crack.light_energy = CRACK_ENERGY
	crack.spot_range = 7.0
	crack.spot_angle = 26.0
	crack.spot_angle_attenuation = 0.8
	crack.shadow_enabled = true
	crack.light_volumetric_fog_energy = 2.5
	_root3.add_child(crack)
	crack.look_at_from_position(CRACK_AT, CRACK_AIM, Vector3.UP)
	_crack = crack
	# candles somewhere in the hollow, out of the shot: lit only where the Environment's light burns candles and no lamp
	_candles = OmniLight3D.new()
	_candles.light_color = Color(1.0, 0.69, 0.4)
	_candles.omni_range = 2.6
	_candles.omni_attenuation = 1.4
	_candles.position = Vector3(-0.7, DispatchSet.DESK_Y + 0.35, 0.55)
	_candles.visible = false
	_root3.add_child(_candles)


## The desk built for [param labels] and [param seed] (again only when either changed): the screens' labels here, then the
## set and its roots, on a worker while the show waits (a half second, most of it the roots), out of the tree, put in as
## they land ([method _land_set]). A render and a gate build where they stand: their frames wait for nothing ([method
## TablePhysics.render_waits]).
func _build_set(labels: PackedStringArray, seed: int) -> void:
	var key := "%s|%d|%s|%s" % [",".join(labels), seed, ",".join(PackedStringArray(_wants.keys())), JSON.stringify(_makes)]
	if key == _built_for:
		return
	_built_for = key
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
	_screens.build(labels)
	_dress_inks()
	var tex := _screens.textures()
	if is_inside_tree() and (away_in_tests or not TablePhysics.render_waits()):
		_waiting = true
		feed.wait_for(WAIT_FOR, true)
		_build_task = WorkerThreadPool.add_task(_make_set.bind(labels, seed, tex, _wants.duplicate(), _makes.duplicate(true)), false,
			"the dispatch desk")
		return
	_make_set(labels, seed, tex, _wants.duplicate(), _makes.duplicate(true))
	_land_set()


## The set and its roots, made out of the tree (a worker's, or the caller's), its parts played by the makes [param makes] chooses,
## the desk and the roots as it keeps them ([method makes_of]).
func _make_set(labels: PackedStringArray, seed: int, tex: Dictionary, wants: Dictionary, makes: Dictionary) -> void:
	var s := DispatchSet.new()
	s.makes = makes
	s.desk = makes.get("desk", {})
	var node := s.build(labels, seed, tex, wants)
	var r := DispatchRoots.new()
	var rn := r.build(seed, s.footprints, s.held_rect(), s.clear, makes.get("roots", {}))
	# the patch panel's cables laid again over the roots lying on the desk, now they are known
	s.lay_cables(r.lying, r.hanging)
	_made = {"set": s, "node": node, "roots": r, "roots_node": rn, "tablet_route": tablet_route(s)}


## The set that was made, put in: the last one freed, the new one in the world, every glass's material, the live picture's
## camera; the plan's camera and sounds, which read the set, made again; the show let go on.
func _land_set() -> void:
	if _made.is_empty():
		return
	if _set_node != null:
		_set_node.queue_free()
	if _roots_node != null:
		_roots_node.queue_free()
	_set = _made["set"]
	_set_node = _made["node"]
	_roots = _made["roots"]
	_roots_node = _made["roots_node"]
	_tablet_route = _made["tablet_route"]
	_made = {}
	_root3.add_child(_set_node)
	_root3.add_child(_roots_node)
	_mats = {}
	# each glass shows its picture as its make's face says ([method _glass])
	# (the terminal, the radar and the oscilloscope shown as drawn, so the color picked for each is the one seen, [method _dress_inks])
	if _set.terminal_screen != null:
		_set.terminal_screen.material_override = _screen_mat("terminal", _screens.terminal.get_texture(), Color.WHITE, _glass("terminal", "screen"))
	if _set.radar_screen != null:
		_set.radar_screen.material_override = _screen_mat("radar", _screens.radar.get_texture(), Color.WHITE, _glass("radar", "scope"))
	if _set.scope_screen != null:
		_set.scope_screen.material_override = _screen_mat("scope", _screens.scope.get_texture(), Color.WHITE, _glass("receiver", "scope"))
	if _set.spectrum_screen != null:
		# a flat panel: no tube's roll of brightness
		var flat := _glass("sdr", "screen")
		flat["flicker"] = 0.0
		_set.spectrum_screen.material_override = _screen_mat("spectrum", _screens.spectrum.get_texture(), Color.WHITE, flat)
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _screens.paper.get_texture()
	pm.roughness = 0.9
	_set.paper_print = pm
	if _set.paper != null and _set.paper.mesh != null and _set.paper.mesh.get_surface_count() > 0:
		_set.paper.mesh.surface_set_material(0, pm)
	for k in _set.screens:
		var sc: Dictionary = _set.screens[k]
		if sc["mesh"] != null:
			(sc["mesh"] as MeshInstance3D).material_override = _screen_mat(k, null, Color(1, 1, 1), _glass(k, "screen"))
	if _set.clock_face != null:
		_set.clock_face.material_override = _screen_mat("clock", _screens.clock.get_texture(), Color(1, 1, 1), _glass("clock", "cards"))
	if _set.tablet_screen != null:
		# the tablet medium's own glass: its rounded corners, its glow - its size and corners the make's face's
		var face := (_set.rigs["tablet"] as PropRig).face_part("screen")
		var glass := ShaderMaterial.new()
		glass.shader = _tablet_glass()
		glass.set_shader_parameter("screen_tex", _screens.tablet.get_texture())
		glass.set_shader_parameter("size", (face.get("size", Vector2(15.0, 20.0)) as Vector2) * 0.01)
		glass.set_shader_parameter("radius", float(face.get("round", 0.6)) * 0.01 if String(face.get("outline", "")) == "rounded" else 0.0)
		glass.set_shader_parameter("glow", 0.0)
		_set.tablet_screen.material_override = glass
		_mats["tablet"] = glass
	for i in _set.phones.size():
		var ph: Dictionary = _set.phones[i]
		for which in ["inner", "outer"]:
			if ph[which] != null:
				(ph[which] as MeshInstance3D).material_override = _screen_mat("%s %d" % [which, i], null, Color(1, 1, 1),
					_glass_of((ph["rig"] as PropRig).face_part(which)))
	_live_vp = SubViewport.new()
	_live_vp.size = LIVE_SIZE
	_live_vp.own_world_3d = false
	_live_vp.world_3d = _root3.get_world_3d()
	_live_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_live_cam = Camera3D.new()
	_live_cam.fov = 46.0
	_live_cam.environment = _env
	_live_vp.add_child(_live_cam)
	_set_node.add_child(_live_vp)
	_live_cam.look_at_from_position(LIVE_EYE, LIVE_AIM, Vector3.UP)
	_shine_things()
	_snap = true
	if _built_n > 0:
		_build_attention()
		_build_sound()
	if _waiting:
		_waiting = false
		feed.wait_for(WAIT_FOR, false)


## The terminal's text, the radar's glow and the receiver's oscilloscope as the note keeps them ([method DispatchSet.terminal_ink],
## [method DispatchSet.radar_ink], [method DispatchSet.receiver_inks]): the screens drawn in them, the title typed in the terminal's hue;
## how the scope draws ([method DispatchSet.scope_trace]); and the security monitor's static ([method DispatchSet.feed_static]).
func _dress_inks() -> void:
	_feed_static = DispatchSet.feed_static(_makes.get("feed_screen", {}))
	var term := DispatchSet.terminal_ink(_makes.get("terminal_screen", {}))
	_screens.set_inks(term, DispatchSet.radar_ink(_makes.get("radar_screen", {})),
		DispatchSet.receiver_inks(_makes.get("receiver_glow", {}))["scope"])
	if _scope != null:
		_scope.mode = DispatchSet.scope_trace(_makes.get("receiver_glow", {}))
	if _title != null:
		_title.ink = DispatchScreens.tinted(TITLE_INK, DispatchScreens.PHOSPHOR, term)


## The tablet medium's screen shader ([constant TabletMedium.SCREEN_SHADER]), made once.
static var _glass_shader: Shader = null

static func _tablet_glass() -> Shader:
	if _glass_shader == null:
		_glass_shader = Shader.new()
		_glass_shader.code = TabletMedium.SCREEN_SHADER
	return _glass_shader


# --- what is round the desk -------------------------------------------------------------------------------------------

## The hollow lit, its shafts and its air as [member _surround] says: with no light chosen, the hollow's own (its ambient, the fill,
## the shaft through the crack, the lamp); a light chosen, its preset's colors and shares of them ([constant Surroundings.LIGHTS]) -
## candles out of the shot where it burns candles and no lamp. Brightness over the exposure; shafts chosen in the crack's place;
## what drifts, built over the desk and the hollow; each lit thing on the desk at its share.
func _dress_environment() -> void:
	if _env == null:
		return
	var own := Surroundings.preset_of(_surround).is_empty()
	var row := Surroundings.light_of(_surround)
	var key := Color.html(String(row["key_color"]))
	_env.ambient_light_color = AMBIENT if own else Color.html(String(row["ambient"]))
	_env.ambient_light_energy = AMBIENT_ENERGY * (1.0 if own else float(row["ambient_energy"]))
	_fill.light_color = FILL_COLOR if own else FILL_COLOR.lerp(key, 0.5)
	_fill.light_energy = FILL_ENERGY * (1.0 if own else float(row["ambient_energy"]))
	_lamp_share = Surroundings.lamp_of(_surround, 1.0 if own else float(row["lamp"]))
	var candles := not own and int((row["candles"] as Array)[1]) > 0 and _lamp_share <= 0.0
	_candles.visible = candles
	_candles.light_energy = CANDLES_ENERGY if candles else 0.0
	Tonemaps.dress(_env, EXPOSURE * Surroundings.brightness(_surround))
	var shafts := Surroundings.has_shafts(_surround)
	_crack.visible = not shafts
	_crack.light_color = CRACK_COLOR if own else key
	_crack.light_energy = CRACK_ENERGY * (1.0 if own else float(row["key_strength"]))
	_crack_energy = _crack.light_energy
	if _rays != null:
		_rays.queue_free()
		_rays = null
	if shafts:
		_rays = Surroundings.rays(_surround, CRACK_COLOR if own else key, CRACK_AT - CRACK_AIM, RAYS_ROUND,
			CRACK_AT.y - (RAYS_ROUND[0] as AABB).end.y)
		_root3.add_child(_rays)
	if not own:
		_env.volumetric_fog_albedo = Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)
	if _air != null:
		_air.release()
		_air = null
	var fx := Surroundings.effects_of(_surround, Color.html(String(row["fog"])) if not own else FOG, AIR_NEAR_MORE)
	if not fx.is_empty():
		# its motes spread over the whole desk as the chair sees it, never over wherever the camera happens to be (on first
		# dressing it is placed nowhere yet, and every mote would be put in the middle of its region)
		var home := DispatchSet.home_spot()
		var eye: Vector3 = home["eye"]
		_air = Effects.build(fx, {"regions": {"near": AIR_NEAR, "far": AIR_FAR, "room": AIR_ROOM},
			"camera": Transform3D(Basis.looking_at((home["aim"] as Vector3) - eye, Vector3.UP), eye), "fov": float(home["fov"]),
			"aspect": 16.0 / 9.0, "around": true}, hash([_seed, "dispatch air"]))
		_root3.add_child(_air.root)
	_shine_things()


## Each lit thing on the desk at its share of its light ([method Surroundings.share_of], by its role), and the receiver as loud as
## the Environment says ([method Surroundings.heard_of]).
func _shine_things() -> void:
	if _sounds != null:
		_sounds.receiver_share = Surroundings.heard_of(_surround, "receiver")
	if _set == null:
		return
	for k in _set.rigs:
		(_set.rigs[k] as PropRig).set_light_scale(Surroundings.share_of(_surround, String(k)))


## How thing [param k]'s make shows a picture on its face [param face] ([constant Props.SHAPES] `face`: its `glass`, a round one
## masked round) - the screen shader's settings ([method _screen_mat]).
func _glass(k: String, face: String) -> Dictionary:
	var rig: PropRig = _set.rigs.get(k)
	return _glass_of(rig.face_part(face) if rig != null else {})


static func _glass_of(part: Dictionary) -> Dictionary:
	var out: Dictionary = (part.get("glass", {}) as Dictionary).duplicate() if part.get("glass") is Dictionary else {}
	out["round_mask"] = 1.0 if String(part.get("outline", "")) == "round" else 0.0
	return out


func _screen_mat(name: String, tex: Texture2D, tint: Color, opts: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/dispatch_screen.gdshader")
	m.set_shader_parameter("has_face", tex != null)
	if tex != null:
		m.set_shader_parameter("face", tex)
	m.set_shader_parameter("tint", tint)
	for k in opts:
		m.set_shader_parameter(String(k), opts[k])
	_mats[name] = m
	return m


func begin_session() -> void:
	_seed = feed.session_seed()
	_snap = true


func release() -> void:
	_subs = null
	_doc_key = ""
	_hush_films()


## Every note played inside the desk let go and every film's sound stopped: the session ended under them (Stop), or the desk left.
func _hush_films() -> void:
	for f in _players.values():
		(f as ScreenFilm).stop()
	_players = {}
	for what in _shows.keys():
		_let_go(String(what))


func _exit_tree() -> void:
	if _air != null:
		_air.release()
		_air = null
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_made = {}
	if _pic_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
	if _waiting:
		_waiting = false
		feed.wait_for(WAIT_FOR, false)
	if _sounds != null:
		_sounds.stop()
	_hush_films()
	for l in _loads.values():
		if int((l as Dictionary)["task"]) >= 0:
			WorkerThreadPool.wait_for_task_completion(int((l as Dictionary)["task"]))
	_loads = {}
	if stage != null and is_instance_valid(stage) and not _stage_was.is_empty():
		for key in _stage_was:
			stage.set(key, _stage_was[key])


# --- the Medium contract ------------------------------------------------------------------------------------------------

func owns_cast() -> bool:
	return true


func take_over(_outgoing: GhostScene) -> GhostScene:
	return _placeholder


func owns_bookend() -> bool:
	return true


## The subtitles are the desk's to caption ([method _captioned]).
func bind_captions(subs) -> bool:
	_subs = subs
	_doc_key = ""
	if subs != null and "captions" in subs:
		subs.captions = _captioned
	return false


func on_stage_resized(_size: Vector2) -> void:
	for n in [_blur, _title, _plate]:
		if n != null:
			(n as CanvasItem).queue_redraw()


## Is the line from subtitle word [param w0] to [param w1] captioned? Yes, unless every word of it is read where it is
## shown as it is said: typed on the terminal, or lit on the tablet's page as the room reads it off ([method _page_follow]);
## two places saying the same words leave the eye nowhere to go. Always while a picture covers the screen.
func _captioned(w0: int, w1: int, _t: float) -> bool:
	if LetterMedium.cover_of(_plate.layers) >= 0.5:
		return true
	var map: Array = _follower.map
	var lit := {}
	var looked := false
	for w in range(w0, w1 + 1):
		var si := int(map[w]) if w >= 0 and w < map.size() else -1
		if si < 0:
			continue
		if si < _typed_words.size() and _typed_words[si] != 0:
			continue
		if not looked:
			lit = _tablet_read()
			looked = true
		if not lit.has(si):
			return true
	return false


## The spoken words read off the tablet's pages, each lit there as it is said: `{spoken word: true}`.
func _tablet_read() -> Dictionary:
	var out := {}
	var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
	for i in _actions.size():
		if String((_actions[i] as Dictionary)["kind"]) != "page" or int((_actions[i] as Dictionary)["page"]) < 0:
			continue
		for pair in _page_follow(i, view, 1.0e9)["lit"]:
			out[int((pair as Array)[1])] = true
	return out


func advance(features, delta: float, _bookend: float) -> void:
	var t := maxf(feed.show_time(), 0.0)
	_dt = delta
	_heard = features as AudioFeatures if features is AudioFeatures else null
	_bands = _heard.bands if _heard != null else PackedFloat32Array()
	_ensure_doc()
	if _build_task >= 0 and WorkerThreadPool.is_task_completed(_build_task):
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		_land_set()
	if _pic_task >= 0 and WorkerThreadPool.is_task_completed(_pic_task):
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
		_land_pictures()
	_now = _subs.now() if _subs != null and is_instance_valid(_subs) else t
	var waited := float(Time.get_ticks_usec() - _last_tick) / 1e6 if _last_tick > 0 else 0.0
	_last_tick = Time.get_ticks_usec()
	if jumped(_now - _last_now, waited):
		_snap = true
	if _now < _last_now - 1.0:
		_held = {}
		_built_n = -1
	_last_now = _now
	if _subs != null and is_instance_valid(_subs) and not _parsed.is_empty():
		take_words(_subs.words)
	var black := fade_at(_now)
	_env.adjustment_brightness = clampf(clampf(t / 1.2, 0.0, 1.0) * _end_fade() * feed.live_fade * (1.0 - black), 0.0, 1.0)
	_plate.modulate = Color(1.0 - black, 1.0 - black, 1.0 - black)
	if black >= 0.999:
		_snap = true
	var opening := _opening()
	ShowOpening.lens(_pull(_now, opening), _blur, _attrs)
	_title.alpha = ShowOpening.title_alpha(ShowOpening.style_of(feed.opening, _midway), _now, opening, _built_n > 0)
	_title.fisheye = feed.fisheye()
	_title.queue_redraw()
	if _set != null:
		# the camera first: a phone at the ear and the mug lifted are held where it is this frame, never the last
		_tick_camera(delta)
		_pose(_now)
		_censor_at(_now)
	_show_pictures()
	_sounds.tick(_now, self)


## The outro, after the desk is done: once the voice has said its last word and the desk has done what follows it (the
## lamp switched off, a last line on the terminal, its sleep: rests the voice holds after its last word), the desk fades
## to black a beat later, black as the outro runs out.
func _end_fade() -> float:
	return ShowOpening.end_fade(_now - _after_last(), _follower, _spoken_n, feed.tail())


## How long the desk goes on after the voice's last word: the end of the rests it holds there (0 for none, or before the last
## word is heard).
func _after_last() -> float:
	var last := _word_t1(_spoken_n - 1)
	if last == INF:
		return 0.0
	var out := 0.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if int(a["after"]) >= _spoken_n and _t0[i] < INF:
			out = maxf(out, _t0[i] + float(a["rest"]) / _sp[i] + float(a["back"]) - last)
	return out


## The show opens on the desk at rest: the title and the blur clear a settle ([method Openings.settle]) before the first
## word or the first thing the desk does, so the desk is seen whole first, never under the title; INF until either is
## placed.
func _opening() -> float:
	var first := _word_t0(0)
	for i in _t0.size():
		if int((_actions[i] as Dictionary)["after"]) == 0 and _t0[i] < first:
			first = _t0[i]
	return first - Openings.settle(first) if first < INF else INF


# --- the document --------------------------------------------------------------------------------------------------------

func _ensure_doc() -> void:
	if _subs == null or not is_instance_valid(_subs):
		return
	var d: Dictionary = _subs.document
	# the night its words were filled for: the chart is printed round it
	var night := String(d.get("night", ""))
	if night != _night:
		_night = night
		_screens.set_night(night)
	var env := Surroundings.sanitize(d.get("environment"))
	var ek := JSON.stringify(env)
	if ek != _surround_key:
		_surround_key = ek
		_surround = env
		_dress_environment()
	_title.channel = String(d.get("title", ""))
	_title.byline = String(d.get("byline", d.get("author", "")))
	var src := String(d.get("source", ""))
	var dispatch: Dictionary = d.get("dispatch", {}) if d.get("dispatch") is Dictionary else {}
	var start: PackedStringArray = d.get("start_words", PackedStringArray()) \
		if d.get("start_words") is PackedStringArray else PackedStringArray()
	var seed := int(dispatch.get("seed", 0))
	var key := "%d|%d|%d|%d|%d|%s" % [src.hash(), String(dispatch.get("head", "")).hash(),
		hash(dispatch.get("pictures", {})), hash(dispatch.get("clips", {})), hash(DispatchScript.lengths_of(dispatch.get("films", {})
		if dispatch.get("films") is Dictionary else {})), " ".join(start)]
	if key == _doc_key:
		if seed != _doc_seed:
			_doc_seed = seed
			reseed(_seed_of(seed, src))
		# another make chosen for one of the desk's parts, or the desk or its roots changed: built again, the reading kept where it is
		var makes := makes_of(dispatch)
		if makes != _makes:
			_makes = makes
			_build_set(_labels, _seed)
		return
	_doc_key = key
	_doc_seed = seed
	load_note(src, dispatch, start, int(d.get("start_index", -1)), float(d.get("start_time", 0.0)))


## The spare things on the desk ([constant DispatchSet.SPARE]) the script [param parsed] works, which cannot be taken off: `switch`
## where it throws the switch.
static func works_of(parsed: Dictionary) -> Dictionary:
	var out := {}
	for a in parsed.get("actions", []):
		if String((a as Dictionary)["kind"]) == "switch":
			out["switch"] = true
	return out


## What the desk builds only where the script uses it, for the script [param parsed] read from [param source]: `clock` (its
## `desk:` names one, or a fade tells the hour), `tablet` (named, or read from).
static func wants_of(parsed: Dictionary, source: String) -> Dictionary:
	var out := {}
	var desk := DispatchScript.desk_of(source)
	for k in ["clock", "tablet"]:
		if desk.has(k):
			out[k] = true
	for a in parsed.get("actions", []):
		match String((a as Dictionary)["kind"]):
			"fade":
				if int(a.get("clock", -1)) >= 0:
					out["clock"] = true
			"tablet", "page":
				out["tablet"] = true
	return out


## The makes a document's [param dispatch] chooses for the desk's parts: `{role: choice}` ([DispatchProps], [PropMakes]) - and, where
## it keeps them otherwise than its own, the desk itself (`desk`, [DispatchDesk]), the roots (`roots`, [DispatchRoots]), the
## phones' colors (`phones`, [constant DispatchSet.PHONE_FIELDS]), the terminal's and the radar's glass colors (`terminal_screen`,
## `radar_screen`, [constant DispatchSet.TERMINAL_FIELDS], [constant DispatchSet.RADAR_FIELDS]), the receiver's glows
## (`receiver_glow`, [constant DispatchSet.RECEIVER_FIELDS]) and the security monitor's static (`feed_screen`, [constant
## DispatchSet.FEED_FIELDS]), each `{seed, <its fields set>}`.
static func makes_of(dispatch: Dictionary) -> Dictionary:
	var out := {}
	var things: Dictionary = dispatch.get("things", {}) if dispatch.get("things") is Dictionary else {}
	for role in things:
		if PropMakes.valid_for(String(role), things[role]) and not (things[role] as Dictionary).is_empty():
			out[String(role)] = (things[role] as Dictionary).duplicate(true)
	var parts := {"desk": DispatchDesk.FIELDS, "roots": DispatchRoots.FIELDS, "phones": DispatchSet.PHONE_FIELDS,
		"terminal_screen": DispatchSet.TERMINAL_FIELDS, "radar_screen": DispatchSet.RADAR_FIELDS, "receiver_glow": DispatchSet.RECEIVER_FIELDS,
		"feed_screen": DispatchSet.FEED_FIELDS}
	for part in parts:
		var spec := Roll.clean_spec(parts[part], dispatch.get(part))
		if not spec.is_empty():
			out[part] = spec
	return out


## The desk's number a document's [param seed] names, or the words' own where it names none.
static func _seed_of(seed: int, text: String) -> int:
	return seed if seed > 0 else 1 + absi(text.hash()) % 99999


## The desk drawn again as desk number [param seed] while the note plays: the set and its roots, the radar's clutter, how each
## picture drifts and the receiver's storms - never when anything happens, so the reading keeps its place. Public for a gate.
func reseed(seed: int) -> void:
	_seed = seed
	_clutter = clutter_of(seed)
	_moves = LetterMedium.moves_of(_spans, _seed)
	for i in _spans.size():
		(_spans[i] as Dictionary).erase("move")
		if not (_moves[i] as Dictionary).is_empty():
			(_spans[i] as Dictionary)["move"] = _moves[i]
	_build_receiver()
	_build_set(_labels, _seed)


## Load a note: [param source] (its text, its marks in it) and [param dispatch] (`{seed, pictures, clips, films, head}`, any missing:
## `head` the note's frontmatter, put on words that come without it); for a reading started mid-way its first words
## [param start] (normalized), [param near] the index they are about, [param since] how far into the reading it starts
## (seconds; 0 when not known). Public for a gate, which hands it one by hand.
func load_note(text: String, dispatch: Dictionary, start := PackedStringArray(), near := -1, since := 0.0) -> void:
	var source := whole(text, String(dispatch.get("head", "")))
	var seed := _seed_of(int(dispatch.get("seed", 0)), text)
	_seed = seed
	_clutter = clutter_of(seed)
	# The note read once: a seek starts the reading again part way and hands the same words over, and reading them (every
	# mark, every sentence's end, each glass's words) is a quarter of a second of this thread for a long note.
	var films: Dictionary = dispatch.get("films", {}) if dispatch.get("films") is Dictionary else {}
	var heard := source + "\n" + JSON.stringify(DispatchScript.lengths_of(films))
	var read := _parsed.is_empty() or heard != _parsed_of
	_take_films(films)
	if read:
		_parsed_of = heard
		_parsed = DispatchScript.parse(source, films)
		_ends = DispatchScript.sentence_ends(_parsed)
		_est = PackedFloat32Array()
	_actions = _parsed["actions"]
	_index_kinds()
	_spans = _parsed["spans"]
	_moves = LetterMedium.moves_of(_spans, _seed)
	for i in _spans.size():
		(_spans[i] as Dictionary).erase("move")
		if not (_moves[i] as Dictionary).is_empty():
			(_spans[i] as Dictionary)["move"] = _moves[i]
	var spoken: PackedStringArray = _parsed["spoken"]
	_spoken_n = spoken.size()
	_typed_words = PackedByteArray()
	_typed_words.resize(_spoken_n)
	for a in _actions:
		if String((a as Dictionary)["kind"]) == "type":
			for k in (a["spans"] as Array).size():
				var si := _span_word(a, k)
				if si < _spoken_n:
					_typed_words[si] = 1
	_term = _parsed.get("terminal", DispatchTerminal.config_of(""))
	_dark0 = bool(_parsed.get("dark", false))
	_wants = wants_of(_parsed, source)
	_makes = makes_of(dispatch)
	_tablet_doc = _parsed.get("tablet", {})
	_tablet_pages = {}
	_tablet_char0 = PackedInt32Array()
	var letters := 0
	for w in _tablet_doc.get("words", []):
		_tablet_char0.append(letters)
		letters += String((w as Dictionary)["text"]).length() + 1
	_tablet_hue0 = float(hash([_seed, "hue"]) & 0xFFFF) / 65535.0
	_clips = dispatch.get("clips", {}) if dispatch.get("clips") is Dictionary else {}
	_clip_tex = {}
	_rings = float(_parsed.get("rings", DispatchScript.SCOPE_RINGS))
	_term_key = Vector2(NAN, NAN)
	for a in _actions if read else []:
		var act: Dictionary = a
		match String(act["kind"]):
			"session":
				act["words"] = DispatchTerminal.words_on(DispatchTerminal.up(DispatchTerminal.at(act["glass"], act["ops"], INF)), _term)
			"type":
				var after := DispatchTerminal.typed(act["glass"], String(act["text"]), String(act["text"]).length())
				act["words"] = DispatchTerminal.words_on(DispatchTerminal.up(after), _term)
	# nothing placed yet, before the set is built: a set landing rebuilds what is placed, and the last note's times are
	# not this one's (a note with more actions than the last would read past them)
	_built_n = -1
	_held = {}
	_leg_known = {}
	_t0 = PackedFloat32Array()
	_t0.resize(_actions.size())
	_t0.fill(INF)
	_sp = PackedFloat32Array()
	_sp.resize(_actions.size())
	_sp.fill(1.0)
	_chars = {}
	_labels = _parsed["phones"]
	_build_set(_labels, _seed)
	_load_pictures(dispatch.get("pictures", {}) if dispatch.get("pictures") is Dictionary else {})
	var from := TabletScript.find_run(spoken, start, near) if not start.is_empty() else -1
	_midway = not start.is_empty()
	var est := _estimate() if from > 0 else PackedFloat32Array()
	_follower.reset(spoken, from, est)
	_since = maxf(since, 0.0) if from > 0 else 0.0
	_est_from = est[from] if from > 0 and from < est.size() else 0.0
	_snap = true


## Each spoken word's moment as a steady voice would say the note ([method DispatchScript.rehearsal]): where a reading
## started part way puts what came before it. A pass over every word, made once for the note loaded.
func _estimate() -> PackedFloat32Array:
	if _est.is_empty():
		for w in DispatchScript.rehearsal(_parsed):
			_est.append(float((w as Dictionary)["t0"]))
	return _est


## The pictures' files, decoded on a worker in the app and put up as they land (a picture not landed yet leaves its screen
## as it was); in a render and a gate, here. The same files as are up, or on their way, are left as they are: a reading
## started again part way hands the same note over, and decoding thirty pictures is a second of a worker each time.
func _load_pictures(paths: Dictionary) -> void:
	var of := _pictures_of(paths)
	if of == _pic_of:
		return
	_pic_of = of
	if _pic_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_pic_task)
		_pic_task = -1
	_pictures = {}
	_decoded = {}
	if paths.is_empty():
		return
	if is_inside_tree() and (away_in_tests or not TablePhysics.render_waits()):
		_pic_task = WorkerThreadPool.add_task(_decode.bind(paths.duplicate()), false, "the dispatch desk's pictures")
		return
	_decode(paths)
	_land_pictures()


## What a set of picture files is: each one's key, its path and when it was last written (a picture painted again is another).
static func _pictures_of(paths: Dictionary) -> String:
	var out := PackedStringArray()
	for key in paths:
		out.append("%s=%s@%d" % [key, paths[key], FileAccess.get_modified_time(String(paths[key]))])
	return "\n".join(out)


func _decode(paths: Dictionary) -> void:
	var out := {}
	for key in paths:
		var img := Image.load_from_file(String(paths[key]))
		if img == null or img.is_empty():
			continue
		img.generate_mipmaps()
		out[String(key)] = img
	_decoded = out


func _land_pictures() -> void:
	for key in _decoded:
		_pictures[key] = ImageTexture.create_from_image(_decoded[key])
	_decoded = {}


## The voice's words so far, matched, and the plan made again when more came. Public for a gate, which hands it words as a
## live reading would.
func take_words(words: Array) -> void:
	var grown := words.size() != _built_n
	var more := _built_n > 0 and words.size() > _built_n
	if grown and not more:
		_held = {}
	_follower.extend(words)
	if not grown:
		return
	# More heard far ahead of the playhead changes nothing seen or heard yet: in the app the plan is made again as the
	# reading comes within PLAN_AHEAD of what it knows, never for every sentence a paused reading makes (minutes of them,
	# a frame each). A render and a gate make it at once, as they build the set ([method _build_set]).
	if more and is_inside_tree() and (away_in_tests or not TablePhysics.render_waits()) and _known_to - _now > PLAN_AHEAD:
		return
	_built_n = words.size()
	_build_plan()


# --- the plan ----------------------------------------------------------------------------------------------------------

func _word_t0(si: int) -> float:
	if si < 0 or si >= _follower.said0.size() or _follower.said0[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said0[si]


func _word_t1(si: int) -> float:
	if si < 0 or si >= _follower.said1.size() or _follower.said1[si] == ReadingFollower.NO_TIME:
		return INF
	return _follower.said1[si]


## When each action happens, and then everything that follows from it: each placed in its silence ([method _place]), what
## has begun kept; then the typed characters' moments, the phones' moves, where the camera looks, and what is heard.
func _build_plan() -> void:
	var known := _follower.known_last()
	var heard := _word_t1(known) if known >= 0 else INF
	_known_to = heard if heard < INF else -INF
	for i in _actions.size():
		if _held.has(i):
			_t0[i] = float(_held[i][0])
			_sp[i] = float(_held[i][1])
			continue
		var got := _place(i)
		_t0[i] = got.x
		_sp[i] = got.y
		if got.x <= _now and got.x < INF:
			_held[i] = [got.x, got.y]
	var was := _chars
	_chars = {}
	_term_key = Vector2(NAN, NAN)
	_follow = {}
	for i in _actions.size():
		if String((_actions[i] as Dictionary)["kind"]) in ["type", "reply", "post"]:
			_chars[i] = _char_times(i, was.get(i, PackedFloat32Array()))
	_build_receiver()
	_build_phones()
	_build_track()
	if _set != null:
		_build_attention()
		_build_sound()


## Where action [param i] falls: `(t0, speed)`. Back from the word after it by what the script wrote after it in the same
## silence and its own rest; never before the word before it ended (squeezed quicker where the silence came out short).
## With the word after it not heard yet, on from the word before by what was written before it. INF until either is.
func _place(i: int) -> Vector2:
	var a: Dictionary = _actions[i]
	var n := int(a["after"])
	var rest := float(a["rest"])
	var next0 := _word_t0(n) if n < _spoken_n else INF
	var prev1 := _word_t1(n - 1) if n > 0 else -INF
	if next0 < INF:
		var t := next0 - float(a["back"]) - rest
		if prev1 > -INF and t < prev1 + LEAD:
			var room := next0 - float(a["back"]) - (prev1 + LEAD)
			var s := clampf(room / maxf(rest, 0.01), 0.3, 1.0)
			return Vector2(prev1 + LEAD, 1.0 / s)
		return Vector2(t, 1.0)
	if prev1 > -INF and prev1 < INF:
		return Vector2(prev1 + LEAD + float(a["fwd"]), 1.0)
	return Vector2(INF, 1.0)


## When action [param i] ends: its start and its length, at its speed.
func _end_of(i: int) -> float:
	return _t0[i] + float((_actions[i] as Dictionary)["len"]) / _sp[i]


## A typed block's characters, each's moment: a said line's ahead of its voice ([method _typed_ahead]); a reply's keys on a
## phone's keypad, at [constant DispatchScript.T9_RATE] a second on the whole, unevenly ([method DispatchScript.key_times]),
## in the rest before it is said; one typed into the tablet's page, each word as it is said, a word's keys struck unevenly
## as a hand does ([method DispatchScript.hand_times]). INF for a word not heard yet. [param was]: the keys as they last
## stood.
func _char_times(i: int, was := PackedFloat32Array()) -> PackedFloat32Array:
	var a: Dictionary = _actions[i]
	var text := String(a["text"])
	var out := PackedFloat32Array()
	out.resize(text.length())
	out.fill(INF)
	if _t0[i] == INF:
		return out
	if String(a["kind"]) == "type":
		return _typed_ahead(i, text, out, was)
	if String(a["kind"]) == "reply":
		# a reply: typed on the phone's keypad, every key in the rest before it is said, each as long as its presses and a hand's
		# unevenness make it ([method DispatchScript.key_times])
		var at := DispatchScript.key_times(text)
		var t9 := _t0[i] + DispatchScript.REPLY_LEAD / _sp[i]
		var typing := DispatchScript.reply_typing(text) / _sp[i]
		for c in text.length():
			out[c] = t9 + at[c] * typing
		return out
	var spans: Array = a["spans"]
	var from := int(a["from"])
	var last := _t0[i] + DispatchScript.TYPE_LEAD * 0.6
	for k in spans.size():
		var span: Dictionary = spans[k]
		var c0 := int(span["c0"])
		var c1 := int(span["c1"])
		var w0 := _word_t0(from + k)
		var w1 := _word_t1(from + k)
		if w0 == INF or w1 == INF:
			break
		var s := maxf(w0, last)
		var e := maxf(w1, s + 0.04 * float(c1 - c0))
		var hand := DispatchScript.hand_times(text, c0, c1)
		for c in range(c0, c1):
			out[c] = s + hand[c - c0] * (e - s)
		last = e
	return out


## A said line's keys: its first [constant DispatchScript.AHEAD_WORDS] words at a typist's pace in the rest before the voice,
## done as it begins; then a way through the band - the keys at least [constant DispatchScript.AHEAD_LEAST] and at most
## [constant DispatchScript.AHEAD_MOST] words ahead of the word being said - at its evenest pace ([method PenPace.taut]),
## so a short word is not rushed nor a pause crawled through; each word's keys struck unevenly on it, as a hand does
## ([method DispatchScript.hand_times]). The keys of a line under way already struck in [param was] stay as they were, the
## way going on from the last of them. INF past the words heard yet.
func _typed_ahead(i: int, text: String, out: PackedFloat32Array, was: PackedFloat32Array) -> PackedFloat32Array:
	var a: Dictionary = _actions[i]
	var spans: Array = a["spans"]
	if spans.is_empty():
		return out
	var heard := 0
	while heard < spans.size() and _word_t0(_span_word(a, heard)) < INF:
		heard += 1
	var start := _t0[i] + DispatchScript.TYPE_LEAD * 0.6
	var lead := mini(DispatchScript.AHEAD_WORDS, spans.size())
	var lead_c := float(int((spans[lead - 1] as Dictionary)["c1"]))
	var lead_end := start + lead_c * DispatchTerminal.KEY_EACH
	if heard > 0:
		lead_end = minf(lead_end, _word_t0(_span_word(a, 0)) - 0.05)
	var done := 0
	var go := Vector2(start, 0.0)
	if _held.has(i) and was.size() == text.length():
		while done < text.length() and was[done] <= _now:
			out[done] = was[done]
			done += 1
		if done > 0:
			go = Vector2(was[done - 1], float(done))
	var knots := PackedVector2Array([go])
	if go.y < lead_c:
		knots.append(Vector2(maxf(lead_end, go.x + 0.01), lead_c))
	if heard > lead:
		var lows := PackedVector2Array()
		var highs := PackedVector2Array()
		for k in heard:
			var said := _word_t0(_span_word(a, k))
			lows.append(Vector2(said - 0.05, float(int((spans[mini(k + DispatchScript.AHEAD_LEAST, heard - 1)] as Dictionary)["c1"]))))
			if k + DispatchScript.AHEAD_MOST < spans.size():
				highs.append(Vector2(said, float(int((spans[k + DispatchScript.AHEAD_MOST] as Dictionary)["c1"]))))
		var end := Vector2(_word_t0(_span_word(a, heard - 1)) - 0.05, float(int((spans[heard - 1] as Dictionary)["c1"])))
		var here := knots[knots.size() - 1]
		if end.y > here.y:
			end.x = maxf(end.x, here.x + 0.01)
			var way := PenPace.taut(here, lows, highs, end)
			for p in way.slice(1):
				knots.append(p)
	# what is typed past the last word said (a line said only in part): on at the pace it was typed at, once all are heard
	var tail_from := knots[knots.size() - 1]
	if heard == spans.size() and tail_from.y >= float(int((spans.back() as Dictionary)["c1"])) and tail_from.y < float(text.length()):
		var pace := (tail_from.x - knots[0].x) / maxf(tail_from.y - knots[0].y, 1.0)
		pace = clampf(pace, DispatchScript.KEY_LEAST, DispatchTerminal.KEY_EACH)
		knots.append(Vector2(tail_from.x + pace * (float(text.length()) - tail_from.y), float(text.length())))
	var reach := knots[knots.size() - 1].y
	if reach >= float(text.length()) and float(int((spans.back() as Dictionary)["c1"])) < float(text.length()):
		spans = spans.duplicate()
		spans.append({"c0": int((spans.back() as Dictionary)["c1"]), "c1": text.length()})
	for k in spans.size():
		var c0 := int((spans[k] as Dictionary)["c0"])
		var c1 := int((spans[k] as Dictionary)["c1"])
		if float(c1) > reach + 0.001:
			break
		if c1 <= done:
			continue
		var s := _on_way(knots, float(c0))
		var e := _on_way(knots, float(c1))
		var hand := DispatchScript.hand_times(text, c0, c1)
		for c in range(maxi(c0, done), c1):
			out[c] = maxf(s + hand[c - c0] * (e - s), go.x)
	return out


## The spoken word span [param k] of typed action [param a] is typed ahead of: its `word` where the words said are not the
## typed ones ([method DispatchScript.said_keys]), else the k-th from the action's first.
static func _span_word(a: Dictionary, k: int) -> int:
	return int(((a["spans"] as Array)[k] as Dictionary).get("word", int(a["from"]) + k))


## When a way of keys ([method _typed_ahead]'s knots, `Vector2(time, keys struck)`) has struck [param keys]; INF past it.
static func _on_way(knots: PackedVector2Array, keys: float) -> float:
	if keys <= knots[0].y:
		return knots[0].x
	for k in range(1, knots.size()):
		if keys <= knots[k].y:
			var dy := knots[k].y - knots[k - 1].y
			return knots[k].x if dy <= 1e-6 else lerpf(knots[k - 1].x, knots[k].x, (keys - knots[k - 1].y) / dy)
	return INF


## The phones' moves from the calls, hang-ups, rings and texts: `{label, from, to, t0, dur, slot, how}` - from and to
## "row", "ear" or "desk".
func _build_phones() -> void:
	_phone_moves = []
	var on_desk: Array = []                  # what lies open on the desk, by slot
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		if t == INF:
			continue
		var s := _sp[i]
		match String(a["kind"]):
			"call":
				for p in a["parts"]:
					var part: Dictionary = p
					var label := String(part["label"])
					var at := t + float(part["at"]) / s
					match String(part["move"]):
						"lay_down":
							var slot := on_desk.find("")
							if slot < 0:
								slot = on_desk.size()
								on_desk.append(label)
							else:
								on_desk[slot] = label
							_phone_moves.append({"label": label, "from": "ear", "to": "desk", "t0": at, "dur": DispatchScript.LAY_DOWN / s, "slot": slot})
						"pick_up":
							var slot := on_desk.find(label)
							if slot >= 0:
								on_desk[slot] = ""
							_phone_moves.append({"label": label, "from": "desk", "to": "ear", "t0": at, "dur": DispatchScript.PICK_UP / s, "slot": slot})
						"dial":
							var until := t + float(a["rest"]) / s
							_phone_moves.append({"label": label, "from": "row", "to": "read", "t0": at, "dur": DispatchScript.LIFT / s,
								"how": "dial", "dialed": at + DispatchScript.LIFT / s, "until": until, "slot": -1, "began": _on_reading(i, t),
								"answered": _word_t0(int(a["after"]))})
							_phone_moves.append({"label": label, "from": "read", "to": "ear", "t0": at + (DispatchScript.LIFT + DispatchScript.DIAL
								- DispatchScript.TO_EAR) / s, "dur": DispatchScript.TO_EAR / s, "how": "dial", "until": until, "slot": -1, "began": _on_reading(i, t)})
							continue
						_:
							_phone_moves.append({"label": label, "from": "row", "to": "ear", "t0": at, "dur": DispatchScript.LIFT / s,
								"how": String(part["move"]), "until": t + float(a["rest"]) / s, "slot": -1, "began": _on_reading(i, t)})
			"hang_up":
				var label := String(a["label"])
				var slot := on_desk.find(label)
				var from := "ear"
				if slot >= 0:
					on_desk[slot] = ""
					from = "desk"
				_phone_moves.append({"label": label, "from": from, "to": "row", "t0": t, "dur": DispatchScript.HANG_UP / s, "slot": slot})
	# The texts, once the calls are laid out: each phone up out of its row to be read (when the calls leave it there), and
	# home again once read and answered - unless it texts again in a moment, when it stays up
	var up := {}                             # a phone held up -> the move that brought it, its `down` when it goes home
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "text" or _t0[i] == INF:
			continue
		var label := String(a["label"])
		var arrives := _t0[i] + DispatchScript.TEXT_CHIME / _sp[i]
		if up.has(label):
			var open_mv: Dictionary = up[label]
			if arrives < float(open_mv["down"]) + DispatchScript.TEXT_AGAIN:
				open_mv["down"] = maxf(float(open_mv["down"]), _read_until(i))
				continue
			_put_down(open_mv)
			up.erase(label)
		if _call_place(label, arrives) != "row":
			continue
		var mv := {"label": label, "from": "row", "to": "read", "t0": arrives, "dur": DispatchScript.READ_LIFT / _sp[i], "slot": -1,
			"down": _read_until(i)}
		_phone_moves.append(mv)
		up[label] = mv
	for label in up:
		_put_down(up[label])
	_phone_moves.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))


## A phone held up to be read [param mv] goes home at its `down` (not while what it waits for is unheard).
func _put_down(mv: Dictionary) -> void:
	if float(mv["down"]) < INF:
		_phone_moves.append({"label": mv["label"], "from": "read", "to": "row", "t0": float(mv["down"]), "dur": DispatchScript.READ_DOWN,
			"slot": -1})


## Where the calls have phone [param label] at [param t]: "row", "ear", "desk" (or on its way).
func _call_place(label: String, t: float) -> String:
	var at := "row"
	for m in _phone_moves:
		var d: Dictionary = m
		if String(d["label"]) == label and float(d["t0"]) <= t:
			at = String(d["to"])
	return at


## When a text is done with: read - and, where the room answers it, the answer typed and sent ([constant
## DispatchScript.REPLY_SEND] after its last key); INF while the answer is not heard yet.
func _read_until(i: int) -> float:
	var a: Dictionary = _actions[i]
	var done := _t0[i] + float(a["rest"]) / _sp[i]
	var label := String(a["label"])
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b.get("label", "")) != label:
			continue
		if String(b["kind"]) == "reply":
			return maxf(done, _sent_at(k))
		if String(b["kind"]) == "text":
			break
	return done


## When reply [param k] is sent: typed and said, and a beat; INF until it is heard.
func _sent_at(k: int) -> float:
	var times: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
	var said := _word_t1(int((_actions[k] as Dictionary)["to"]) - 1)
	if times.is_empty() or times[times.size() - 1] == INF or said == INF:
		return INF
	return maxf(times[times.size() - 1], said) + DispatchScript.REPLY_SEND / _sp[k]


## The next text from [param label] after action [param i], -1 for none.
func _next_text(label: String, i: int) -> int:
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "text" and String(b["label"]) == label:
			return k
	return -1


## The camera's attention: what it turns to and from when to when ([method _attention]); what happens in the black is
## unseen and turns it to nothing.
func _build_attention() -> void:
	_attn = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		# what happens in the black is unseen (the clock it comes up on aside): it turns the camera to nothing
		if t == INF or bool(a.get("dark", false)) or (String(a["kind"]) != "fade" and fade_at(t) >= 0.999):
			continue
		var e := _end_of(i)
		var n0 := _attn.size()
		match String(a["kind"]):
			"call":
				var label := String(a["label"])
				var lift_at := t + float((a["parts"] as Array).back()["at"]) / _sp[i]
				_attn.append({"t0": t, "t1": lift_at + DispatchScript.LIFT * 0.7, "spot": _phone_spot(label, 34.0)})
			"hang_up":
				_attn.append({"t0": t, "t1": t + DispatchScript.HANG_UP, "spot": _spot("phones")})
			"ring":
				_attn.append({"t0": t, "t1": e, "spot": _phone_spot(String(a["label"]), 26.0)})
			"text", "reply":
				var until := _read_until(i) if String(a["kind"]) == "text" else _sent_at(i)
				_attn.append({"t0": t, "t1": (until if until < INF else e) + 0.3, "spot": _spot("home")})
			"ping":
				# held a while as it pings, to the end of a sentence, then let go of quickly: a still blip is not watched
				_attn.append({"t0": t, "t1": e + 0.5, "hold": _ping_hold(i), "spot": _spot("radar"), "linger": PING_LINGER})
			"moving":
				# as he sets off, and while he walks - until the ping where he arrives, or a drive's first moments (a long way
				# is no long stare); passing through a place on the way, nothing
				if bool(a.get("passing", false)):
					continue
				var arrive := t + MOVING_LOOK
				for k in range(i + 1, _actions.size()):
					if String((_actions[k] as Dictionary)["kind"]) == "ping":
						if _t0[k] < INF:
							arrive = maxf(arrive, _t0[k])
						break
				_attn.append({"t0": t, "t1": minf(arrive, t + MOVING_HOLD_MOST), "spot": _spot("radar")})
			"sound":
				_attn.append({"t0": t, "t1": e + 1.5, "spot": _spot("radar")})
			"session":
				_attn.append({"t0": t, "t1": e + 1.5, "hold": _glass_hold(i, t + float(a["rest"]) / _sp[i]), "linger": GLASS_LINGER,
					"spot": _spot("terminal")})
			"static":
				if bool(a.get(DispatchScript.UNWATCHED, false)):
					continue
				_attn.append({"t0": t, "t1": e + 0.8, "spot": _spot("receiver")})
			"print":
				_attn.append({"t0": t, "t1": e + 0.8, "spot": _spot("printer")})
			"type":
				var last := int(a["to"]) - 1
				var done := _word_t1(last) if last >= int(a["from"]) else t + 2.0
				done = done if done < INF else t + 30.0
				_attn.append({"t0": t, "t1": done + 2.5, "hold": _glass_hold(i, done), "linger": GLASS_LINGER, "spot": _spot("terminal")})
			"receiver":
				var heard := _word_t1(int(a["to"]) - 1)
				_attn.append({"t0": t, "t1": (heard if heard < INF else t + 3.0) + 1.0, "spot": _spot("receiver")})
			"strike", "sleep":
				_attn.append({"t0": t, "t1": e + 1.0, "spot": _spot("terminal")})
			"off", "picture", "live":
				if String(a["screen"]) == "tablet" or bool(a.get(DispatchScript.UNWATCHED, false)):
					continue
				_attn.append({"t0": t, "t1": e + (1.0 if String(a["kind"]) == "off" else 3.5), "spot": _spot(String(a["screen"]))})
			"look":
				var at := String(a["at"])
				_attn.append({"t0": t, "t1": INF, "spot": _spot(at if SPOTS.has(at) else "home"), "sticky": true})
			"lift":
				# the whole desk: the mug is seen to rise toward the chair and leave the picture past its lower edge
				_attn.append({"t0": t, "t1": e, "spot": _spot("home")})
			"switch":
				_attn.append({"t0": t, "t1": e + 1.6, "spot": _spot("switch")})
			"gain":
				# the knob turned and the scope watched, as a look holds it, until something else is active
				_attn.append({"t0": t, "t1": INF, "spot": _spot("radar"), "sticky": true})
			"bell":
				_attn.append({"t0": t, "t1": _bell_at(i) + 1.5, "spot": _spot("terminal")})
			"lamp", "power":
				_attn.append({"t0": t, "t1": e + 2.5, "spot": _spot("home")})
			"play":
				if bool(a.get(DispatchScript.UNWATCHED, false)) or not SPOTS.has(String(a["screen"])):
					continue
				# a film round and round has no end to let the camera go at: it holds it as a `look:` does, until something else turns it
				if bool(a.get(DispatchScript.LOOP, false)):
					_attn.append({"t0": t, "t1": INF, "spot": _spot(String(a["screen"])), "sticky": true})
				else:
					_attn.append({"t0": t, "t1": e + FILM_WAKE + FILM_HOLD, "spot": _spot(String(a["screen"]))})
			"fade":
				# up from the black on the clock: the camera is there in the dark, holds while its cards turn and a beat,
				# then eases to the desk
				if bool(a["to"]) or int(a.get("clock", -1)) < 0 or not _set.spots.has("clock"):
					continue
				var from := _black_from(i)
				var held := t + float(a["rest"]) / _sp[i]
				_attn.append({"t0": from, "t1": held, "spot": _spot("clock"), "linger": 0.0, "kind": "fade", "seen": t})
				_attn.append({"t0": held, "t1": held + 2.0, "spot": _spot("home")})
			"tablet":
				if not bool(a["up"]) or not _set.spots.has("tablet"):
					continue
				var down := INF
				for k in range(i + 1, _actions.size()):
					var b: Dictionary = _actions[k]
					if String(b["kind"]) == "tablet" and not bool(b["up"]):
						down = _t0[k] + TABLET_LEAVE / _sp[k] if _t0[k] < INF else INF
						break
				_attn.append({"t0": t, "t1": down, "spot": _spot("tablet"), "kind": "tablet", "linger": 0.0, "leaves": true})
		if _attn.size() > n0:
			(_attn.back() as Dictionary)["kind"] = String(a["kind"])
			(_attn.back() as Dictionary)["i"] = i
	_attn = _settled(_attn)
	# the next look the script holds, its words not heard yet (a live reading knows a sentence or so ahead): when it comes as
	# soon as a placed one would be held for (the same thing within SAME_BRIDGE, anything but the whole desk within the
	# linger and AWAY_LEAST), the camera holds on until it is placed, rather than pull back to the whole desk for nothing
	if not _attn.is_empty():
		var last: Dictionary = _attn.back()
		var li := int(last.get("i", -1))
		var nk := _next_look(li) if li >= 0 else -1
		if nk >= 0 and _t0[nk] == INF and float(last["t1"]) < INF:
			var key := _look_key(_actions[nk])
			var comes := _said_by(int((_actions[nk] as Dictionary)["after"]))
			var same := key == _look_key(_actions[li]) and not key.is_empty()
			var soon := comes - float(last["t1"]) <= (SAME_BRIDGE if same else float(last.get("linger", HOME_AFTER)) + AWAY_LEAST)
			if soon and key != "home" and not bool(last.get("leaves", false)):
				last["t1"] = INF


## What is turned to is seen: [param attn]'s looks in order, those the camera would only swerve through or turn away and
## straight back for dropped ([method _looks_taken]); each held at least [constant LOOK_LEAST] (a ping to its sentence's
## end) but never past what begins next, so nothing is gone back to; a `look:` until the next; and the camera kept on what
## it was on rather than eased home for less than [constant AWAY_LEAST] before it turns again - unless what comes next is
## the whole desk, where it goes as it would have.
func _settled(attn: Array) -> Array:
	attn.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t0"]) < float(y["t0"]))
	var out := _looks_taken(attn)
	for k in out.size():
		var w: Dictionary = out[k]
		var next0 := float((out[k + 1] as Dictionary)["t0"]) if k + 1 < out.size() else INF
		if bool(w.get("sticky", false)):
			w["t1"] = next0
		if not bool(w.get("leaves", false)):
			w["t1"] = maxf(float(w["t1"]), minf(maxf(float(w["t0"]) + LOOK_LEAST, float(w.get("hold", 0.0))), next0))
	var home: Dictionary = _spot("home")
	for k in range(out.size() - 1):
		var w: Dictionary = out[k]
		var nxt: Dictionary = out[k + 1]
		# a look that leaves nothing behind (the tablet laid down) goes straight on only to what begins at once
		if bool(w.get("leaves", false)):
			if float(nxt["t0"]) - float(w["t1"]) <= TABLET_LEAVE:
				w["t1"] = maxf(float(w["t1"]), float(nxt["t0"]))
			continue
		var near := float(nxt["t0"]) < float(w["t1"]) + float(w.get("linger", HOME_AFTER)) + AWAY_LEAST
		# the same thing again before long is one look: held between them
		var again: bool = nxt["spot"] == w["spot"] and float(nxt["t0"]) - float(w["t1"]) <= SAME_BRIDGE
		if (nxt["spot"] != home and near) or again:
			w["t1"] = maxf(float(w["t1"]), float(nxt["t0"]))
	return out


## When spoken word [param si] is about to be said, as near as the words heard so far tell: the last heard word's end, and
## [constant WORD_EST] a word after it.
func _said_by(si: int) -> float:
	var k := mini(si, _spoken_n) - 1
	while k >= 0 and _word_t1(k) == INF:
		k -= 1
	var from := _word_t1(k) if k >= 0 else _now
	return from + float(si - maxi(k, 0)) * WORD_EST


## The next action after [param i] that turns the camera ([method _look_key]), in the script's order: -1 for none.
func _next_look(i: int) -> int:
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if not bool(b.get("dark", false)) and not _look_key(b).is_empty():
			return k
	return -1


## What action [param a] turns the camera to (a key of [member DispatchSet.spots], "phone" for a phone's own), "" for
## nothing - as [method _build_attention] has it.
static func _look_key(a: Dictionary) -> String:
	match String(a["kind"]):
		"session", "type", "strike", "sleep", "bell":
			return "terminal"
		"ping", "sound", "gain":
			return "radar"
		"moving":
			return "" if bool(a.get("passing", false)) else "radar"
		"static", "receiver":
			return "" if bool(a.get(DispatchScript.UNWATCHED, false)) else "receiver"
		"print":
			return "printer"
		"switch":
			return "switch"
		"look":
			return String(a["at"])
		"picture", "live", "off":
			return "" if bool(a.get(DispatchScript.UNWATCHED, false)) else String(a.get("screen", ""))
		"call", "ring":
			return "phone"
		"hang_up":
			return "phones"
		"text", "reply", "lift", "lamp", "power":
			return "home"
		"play":
			return "" if bool(a.get(DispatchScript.UNWATCHED, false)) else String(a["screen"])
		"fade":
			return "clock" if not bool(a["to"]) and int(a.get("clock", -1)) >= 0 else ""
		"tablet":
			return "tablet" if bool(a["up"]) else ""
	return ""


## The looks the camera takes of [param attn] (sorted by start): none cut by the next before it could be got to
## ([constant GLANCE_LEAST]), and none away from a thing for less than [constant LOOK_LEAST] between two looks at it, so
## it never swerves toward one thing on its way to another, nor turns away and straight back. Kept whatever comes: a look
## that outlasts what begins over it (the camera comes back to it), a `look:`, and words to be read ([constant TO_READ]).
func _looks_taken(attn: Array) -> Array:
	var out: Array = []
	for k in attn.size():
		var w: Dictionary = attn[k]
		if bool(w.get("sticky", false)) or String(w.get("kind", "")) in TO_READ or k + 1 >= attn.size():
			out.append(w)
			continue
		var nxt: Dictionary = attn[k + 1]
		var cover := float(nxt["t1"])
		for j in range(k + 2, attn.size()):
			if float((attn[j] as Dictionary)["t0"]) > cover or cover >= float(w["t1"]):
				break
			cover = maxf(cover, float((attn[j] as Dictionary)["t1"]))
		var outlasts := float(w["t1"]) > cover + 0.5
		# (a look that begins in the black is seen from when the picture comes up: the camera's way there is unseen)
		var cut := float(nxt.get("seen", nxt["t0"])) - float(w["t0"]) < GLANCE_LEAST
		var was: Dictionary = out.back() if not out.is_empty() else {}
		var between: bool = not was.is_empty() and nxt["spot"] == was["spot"] and w["spot"] != was["spot"] \
			and float(nxt["t0"]) - float(w["t0"]) < LOOK_LEAST \
			and float(was["t1"]) + float(was.get("linger", HOME_AFTER)) >= float(w["t0"])
		if (cut or between) and not outlasts:
			continue
		out.append(w)
	return out


## How long ping [param i] holds the radar: [constant PING_HOLD] from its ring, on to the end of the sentence being said
## then if it ends by [constant PING_HOLD_MOST], and never before its ring is over.
func _ping_hold(i: int) -> float:
	var t := _t0[i]
	var least := maxf(t + PING_HOLD, _end_of(i) + 0.5)
	var most := maxf(t + PING_HOLD_MOST, least)
	for si in range(int((_actions[i] as Dictionary)["after"]), _ends.size()):
		var e := _word_t1(si)
		if e == INF or e > most:
			break
		if e >= least and _ends[si] == 1:
			return e + 0.3
	return least


## Until when the camera stays on the terminal for action [param i], its steps or its typing done at [param done]: the
## glass read ([constant GLASS_WORD] a word on the panel it leaves up, [constant GLASS_LEAST] to [constant GLASS_MOST]),
## then on to the end of the sentence being said if that ends within [constant GLASS_SENTENCE].
func _glass_hold(i: int, done: float) -> float:
	if done == INF:
		return INF
	var read := done + clampf(GLASS_WORD * float((_actions[i] as Dictionary).get("words", 0)), GLASS_LEAST, GLASS_MOST)
	for si in range(int((_actions[i] as Dictionary)["after"]), _ends.size()):
		var e := _word_t1(si)
		if e == INF or e > read + GLASS_SENTENCE:
			break
		if e >= read and _ends[si] == 1:
			return e + 0.3
	return read


func _spot(key: String) -> Dictionary:
	return _set.spots.get(key, _set.spots["home"])


## A spot close on phone [param label] in its row, the lens [param fov] wide; on its lid's little screen for a text.
func _phone_spot(label: String, fov: float, lid := false) -> Dictionary:
	var i := _labels.find(label)
	if i < 0:
		return _spot("phones")
	var home := _set.phone_home(i)
	var aim := home.origin + Vector3(0, DispatchSet.PHONE.y, 0.02 if lid else 0.0)
	var eye := DispatchSet.EYE + (aim - DispatchSet.EYE).normalized() * (0.30 if lid else 0.18)
	return {"aim": aim, "eye": eye, "fov": fov}


## What is heard and when ([DispatchSounds]): each `{t, t1?, what | kind, at, ...}`, by time.
func _build_sound() -> void:
	var out: Array = []
	var radar_at := _set.desk_at("radar")
	var recv_at := _set.desk_at("receiver")
	var printer_at := _set.desk_at("printer")
	var term_at := _set.desk_at("keyboard")
	for mv in _phone_moves:
		var m: Dictionary = mv
		var i := _labels.find(String(m["label"]))
		var at := _set.phone_home(i).origin if i >= 0 else Vector3.ZERO
		var t := float(m["t0"])
		var dur := float(m["dur"])
		match [String(m["from"]), String(m["to"])]:
			["row", "ear"]:
				out.append({"t": t + dur * 0.25, "what": "flip", "at": at})
			["row", "read"]:
				out.append({"t": t + dur * 0.25, "what": "flip", "at": at})
				if String(m.get("how", "")) == "dial":
					var k := _sp_of(m)
					var dialed := float(m["dialed"])
					out.append({"t": dialed + DispatchScript.SPEED_PRESS / k, "what": "dtmf", "digit": 1, "secs": DispatchScript.SPEED_HOLD / k, "at": at})
					out.append({"t": dialed + DispatchScript.SEND_AT / k, "what": "pad", "at": at})
					var ring_from := dialed + DispatchScript.DIAL / k
					# the far end rings until it answers: its rings, cut off the moment its first word is said
					var rung := ring_from + DispatchScript.RING_CYCLE * float(DispatchScript.SCOPE_RINGS - 1) + DispatchScript.RING_ON
					out.append({"t": ring_from, "t1": minf(rung, float(m.get("answered", INF))), "kind": "ringback"})
			["ear", "desk"]:
				out.append({"t": t + dur * 0.9, "what": "lay", "at": at})
			["desk", "ear"]:
				out.append({"t": t + dur * 0.1, "what": "click", "at": at})
			[_, "row"]:
				out.append({"t": t + dur * 0.15, "what": "snap", "at": at})
				out.append({"t": t + dur * 0.92, "what": "lay", "at": at})
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		var t := _t0[i]
		if t == INF:
			continue
		var e := _end_of(i)
		match String(a["kind"]):
			"ring":
				var label := String(a["label"])
				var stop := e
				for mv in _phone_moves:
					if String((mv as Dictionary)["label"]) == label and float(mv["t0"]) >= t and float(mv["t0"]) < stop:
						stop = float(mv["t0"])
				var li := _labels.find(label)
				out.append({"t": t, "t1": stop, "kind": "buzz", "pattern": "ring", "ears": DispatchSounds.ears_of(_set.phone_home(li).origin if li >= 0 else Vector3.ZERO)})
			"text":
				var li := _labels.find(String(a["label"]))
				var home := _set.phone_home(li).origin if li >= 0 else Vector3.ZERO
				out.append({"t": t, "what": "chime", "at": home})
				out.append({"t": t, "t1": t + DispatchScript.TEXT_BUZZ, "kind": "buzz", "pattern": "text", "ears": DispatchSounds.ears_of(home)})
			"reply":
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				var near := _cam.global_position + Vector3(0.0, -0.12, -0.25)
				for c in times.size():
					if times[c] == INF:
						break
					if text[c] != " ":
						out.append({"t": times[c], "what": "pad", "at": near})
				var sent := _sent_at(i)
				if sent < INF:
					out.append({"t": sent - 0.15, "what": "sent", "at": near})
			"ping":
				out.append({"t": t + 0.25, "what": "ping", "at": radar_at})
				out.append({"t": t + 0.25 + DispatchSounds.PING_ECHO, "what": "echo", "at": radar_at})
				# ...the sweeps of this reading alone: a leg set off on before a mid-way start begins far in the past
				# ([constant ReadingFollower.START_PAST]), forty thousand sweeps ago, and none of those is heard
				for leg in _legs:
					if int((leg as Dictionary)["i"]) == i and float(leg["t0"]) < t:
						for swept in passes(maxf(float(leg["t0"]), 0.0), t):
							out.append({"t": swept, "what": "tick", "at": radar_at})
			"moving":
				# the radar's alarm as he sets off: a low beep, then two higher (passing through a place on the way, none)
				if bool(a.get("passing", false)):
					continue
				out.append({"t": t, "what": "alarm", "at": radar_at})
				out.append({"t": t + 0.16, "what": "alarm_hi", "at": radar_at})
				out.append({"t": t + 0.34, "what": "alarm_hi", "at": radar_at})
			"session":
				for o in a["ops"]:
					var op: Dictionary = o
					var at := t + float(op["t"]) / _sp[i]
					match String(op["op"]):
						"wake":
							out.append({"t": at, "what": "crt", "at": term_at})
						"command":
							var typed := String(op["text"])
							var keys: PackedFloat32Array = op["keys"]
							for c in keys.size():
								out.append({"t": t + keys[c] / _sp[i], "what": "space" if typed[c] == " " else "key", "at": term_at})
							out.append({"t": t + float(op["enter"]) / _sp[i], "what": "enter", "at": term_at})
						"key":
							var text := String(op["text"])
							var times: PackedFloat32Array = op["times"]
							for c in times.size():
								out.append({"t": t + times[c] / _sp[i], "what": "key" if text[c] != " " else "space", "at": term_at})
						"set":
							for k in op["back"]:
								out.append({"t": t + float(k) / _sp[i], "what": "key", "at": term_at})
							for k in op["keys"]:
								out.append({"t": t + float(k) / _sp[i], "what": "key", "at": term_at})
						"select":
							for k in op["presses"]:
								out.append({"t": t + float(k) / _sp[i], "what": "key", "at": term_at})
							if float(op["enter"]) >= 0.0:
								out.append({"t": t + float(op["enter"]) / _sp[i], "what": "enter", "at": term_at})
						"alert":
							out.append({"t": at, "t1": at + DispatchSounds.BELL_LEN, "kind": "bell", "ears": DispatchSounds.ears_of(term_at)})
			"sound":
				if String(a["sound"]) == "jet":
					out.append({"t": t, "t1": e, "kind": "jet"})
			"print":
				out.append({"t": t, "t1": e, "kind": "print", "lines": (a["lines"] as PackedStringArray).size(), "ears": DispatchSounds.ears_of(printer_at)})
			"switch":
				out.append({"t": t + DispatchScript.SWITCH_AT / _sp[i], "what": "toggle", "at": _set.desk_at("switch")})
			"lift":
				out.append({"t": t + 0.1, "what": "lift", "at": _set.desk_at("mug")})
				out.append({"t": e - 0.05, "what": "thud", "at": _set.desk_at("mug")})
			"gain":
				var from := int(a["from"])
				var to := int(a["to"])
				var step := signi(to - from)
				var d := from
				while d != to:
					d += step
					out.append({"t": _step_at(i, d), "what": "detent", "at": radar_at})
			"bell":
				var rung := _bell_at(i)
				out.append({"t": rung, "t1": rung + DispatchSounds.BELL_LEN, "kind": "bell", "ears": DispatchSounds.ears_of(term_at)})
			"lamp":
				out.append({"t": t + DispatchScript.LAMP_AT / _sp[i], "what": "lamp", "at": _set.desk_at("lamp")})
			"power":
				var at := t + POWER_AT / _sp[i]
				out.append({"t": at, "what": "power_on" if bool(a["on"]) else "breaker", "at": term_at})
				if not bool(a["on"]):
					# the receiver dead until the power comes back: no hiss, no storm
					var back := INF
					for k in range(i + 1, _actions.size()):
						var b: Dictionary = _actions[k]
						if String(b["kind"]) == "power" and bool(b["on"]):
							back = _t0[k] + POWER_AT / _sp[k] if _t0[k] < INF else INF
							break
					out.append({"t": at, "t1": back if back < INF else at + 1e6, "kind": "unpowered"})
			"play":
				out.append({"t": t + 0.05, "what": "crt", "at": term_at if String(a["screen"]) == "terminal" else _set.desk_at(String(a["screen"]))})

			"tablet":
				# lifted as the hand takes it; heard on the desk as it is laid there
				out.append({"t": t + (0.15 if bool(a["up"]) else (DispatchScript.TABLET_DOWN - 0.1) / _sp[i]), "what": "lift" if bool(a["up"]) else "thud",
					"at": _set.desk_at("tablet")})
			"page":
				var near := _cam.global_position + Vector3(0.0, -0.05, -0.24)
				var st := _page_times(i)
				for k in st["keys"]:
					out.append({"t": float(k), "what": "pad", "at": near})
				if float(st["tap"]) < INF:
					out.append({"t": float(st["tap"]), "what": "pad", "at": near})
			"post":
				var near := _cam.global_position + Vector3(0.0, -0.05, -0.24)
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				out.append({"t": t + (DispatchScript.TABLET_POST - 0.6) / _sp[i], "what": "pad", "at": near})
				for c in times.size():
					if times[c] == INF:
						break
					if text[c] != " ":
						out.append({"t": times[c], "what": "pad", "at": near})
				var sent := _sent_at(i)
				if sent < INF:
					out.append({"t": sent - 0.15, "what": "sent", "at": near})
			"type":
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				for c in times.size():
					if times[c] == INF:
						break
					var ch := text[c]
					out.append({"t": times[c], "what": "space" if ch == " " else ("enter" if ch == "\n" else "key"), "at": term_at})
			"strike":
				var decide := float(a["decide"]) / _sp[i]
				var block: Dictionary = _actions[int(a["block"])]
				var n := String(block["text"]).length()
				var back := e - (t + decide)
				for c in mini(n, 160):
					out.append({"t": t + decide + back * float(c) / float(maxi(n, 1)), "what": "key", "at": term_at})
			"sleep":
				out.append({"t": t + 0.1, "what": "crt", "at": term_at})
	# the receiver, open: its storms and the voices said over them
	out.append_array(_open)
	# the flip clock: a click as each card slaps down, at every turn of it - the time a fade sets and each minute after
	for turn in _clock_turns():
		var starts := DispatchScript.flap_starts(String(turn[1]), String(turn[2]))
		for k in 4:
			if starts[k] >= 0.0:
				out.append({"t": float(turn[0]) + starts[k] + DispatchScript.CLOCK_LAND * DispatchScript.CLOCK_FLAP, "what": "detent",
					"at": _set.desk_at("clock")})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	_sound_plan = out
	_sound_rev += 1


## The desk's sound plan, and its revision ([DispatchSounds]).
func sound_plan() -> Array:
	return _sound_plan


func sound_rev() -> int:
	return _sound_rev


# --- the power, the environment, the films ----------------------------------------------------------------------------

## How much of its power the desk has at [param t] (0 to 1): whole until a `power: off`, every glow dying over [constant
## POWER_FADE] from its thunk ([constant POWER_AT] into its rest), flickering as it goes ([param flicker]: a tube's glass takes it
## steady, or its collapse strobes); a `power: on` brings it back as quickly.
func power_at(t: float, flicker := true) -> float:
	var lit := 1.0
	for i in _of_kind.get("power", PackedInt32Array()):
		var a: Dictionary = _actions[i]
		if _t0[i] == INF:
			continue
		var at := _t0[i] + POWER_AT / _sp[i]
		if at > t:
			continue
		var u := clampf((t - at) / POWER_FADE, 0.0, 1.0)
		lit = lerpf(lit, 1.0 if bool(a["on"]) else 0.0, u)
		if flicker and u < 1.0 and not bool(a["on"]):
			lit *= 0.5 + 0.5 * float(fposmod((t - at) * 23.0, 1.0) < 0.65)
	return lit


## Each Environment element's share of itself at [param t]: its place in the block's `elements` -> 0 to 1 (-1 the hollow's own
## shaft, where the block chooses no shafts and a mark names them), as each `environment:` mark switched it, eased over its seconds;
## before the first mark that names it, the other way. An element no mark names is not in it (whole).
func env_levels(t: float) -> Dictionary:
	var out := {}
	for i in _of_kind.get("environment", PackedInt32Array()):
		var a: Dictionary = _actions[i]
		var begun := _t0[i] < INF and _t0[i] <= t
		var u := clampf((t - _t0[i]) / maxf(float(a["secs"]), 1e-3), 0.0, 1.0) if begun else 0.0
		for name in (a["set"] as Dictionary):
			var to := 1.0 if bool((a["set"] as Dictionary)[name]) else 0.0
			for e in _env_named(String(name)):
				if not out.has(e):
					out[e] = 1.0 - to
				if begun:
					out[e] = lerpf(float(out[e]), to, u)
	return out


## The elements [param name] names in what is round the desk ([method Surroundings.named]); `shafts` with none chosen, the hollow's
## own (-1).
func _env_named(name: String) -> Array:
	var out := Array(Surroundings.named(_surround, name))
	if out.is_empty() and name.strip_edges().to_lower() == "shafts" and not Surroundings.has_shafts(_surround):
		out.append(-1)
	return out


## The films handed in ([param films]: what each `play` plays -> its film): a player kept for each that is the same film, the rest let go.
func _take_films(films: Dictionary) -> void:
	for what in _players.keys():
		var was: Dictionary = _films.get(what, {})
		var now: Dictionary = films.get(what, {})
		if String(was.get("video", "")) != String(now.get("video", "")) or float(was.get("secs", 0.0)) != float(now.get("secs", 0.0)):
			(_players[what] as ScreenFilm).stop()
			_players.erase(what)
	for what in _shows.keys():
		var was: Dictionary = _films.get(what, {})
		var now: Dictionary = films.get(what, {})
		if String(was.get("song", "")) != String(now.get("song", "")) or String(was.get("medium", "")) != String(now.get("medium", "")) \
				or String(was.get("reveal", "")) != String(now.get("reveal", "")) \
				or JSON.stringify(was.get("storyboard", {})) != JSON.stringify(now.get("storyboard", {})):
			_let_go(String(what))
	_films = films.duplicate(true)
	for what in _films:
		var f: Dictionary = _films[what]
		if String(f.get("kind", "")) == "note" and bool(f.get("ready", false)) and not _loads.has(what) and not f.has("stream"):
			_load_note(String(what))


## A note's song and its bake read ([method NestedShow.prepared]) on a worker live, here in a render; kept on its record once read.
func _load_note(what: String) -> void:
	var note: Dictionary = (_films[what] as Dictionary).duplicate()
	var box := {}
	if TablePhysics.render_waits():
		box["note"] = (load(NESTED) as GDScript).call("prepared", note)
		_loads[what] = {"task": -1, "box": box}
	else:
		var nested: GDScript = load(NESTED)
		_loads[what] = {"task": WorkerThreadPool.add_task(func() -> void: box["note"] = nested.call("prepared", note)), "box": box}


## The notes whose song and bake are read by now, landed on their records.
func _land_notes() -> void:
	for what in _loads.keys():
		var l: Dictionary = _loads[what]
		var task := int(l["task"])
		if task >= 0:
			if not WorkerThreadPool.is_task_completed(task):
				continue
			WorkerThreadPool.wait_for_task_completion(task)
		_loads.erase(what)
		var got: Dictionary = (l["box"] as Dictionary).get("note", {})
		if _films.has(what) and not got.is_empty() and (got.get("stream") != null or String(got.get("song", "")).is_empty()):
			_films[what] = got


## A note's show let go.
func _let_go(what: String) -> void:
	if _shows.has(what):
		var show: Node = _shows[what]
		show.call("stop")
		show.queue_free()
		_shows.erase(what)


## The film up on screen [param key] at [param t]: `{i, what, at (seconds into it), power (its glass: waking, then going down), mono,
## playing, note}`, {} for none - from a `play` on it to its last frame and a beat, unless something else is put on that screen first.
## What is not ready is the screen's static (`snow`) from its `play` on.
func film_at(key: String, t: float) -> Dictionary:
	var out := {}
	for i in _of_kind.get("play", PackedInt32Array()):
		var a: Dictionary = _actions[i]
		if _t0[i] == INF or _t0[i] > t or String(a["screen"]) != key:
			continue
		var cut := int(_cut_by.get(i, -1))
		var film: Dictionary = _films.get(String(a["what"]), {})
		var secs := float(film.get("secs", 0.0))
		var since := t - _t0[i]
		var at := since - FILM_WAKE
		var gone := secs + FILM_HOLD
		# a film told `loop` goes round and round until something else is put on its screen
		var looping := bool(a.get(DispatchScript.LOOP, false)) and secs > 0.0
		if looping:
			gone = INF
			if at >= 0.0:
				at = fposmod(at, secs)
		if cut >= 0 and _t0[cut] <= t:
			out = {}
			continue
		# a note's show waits for what plays it to be read ([method NestedShow.prepared]): its song, or none for a silent note
		var unread := String(film.get("kind", "")) == "note" and (not film.has("stream") \
			or (film.get("stream") == null and not String(film.get("song", "")).is_empty()))
		if not bool(film.get("ready", false)) or unread:
			# not ready (a note's song not heard yet, a file not read, nothing by that name): the glass wakes on its static, as a
			# clip not imported does, until something else is put on it
			out = {"i": i, "what": String(a["what"]), "at": 0.0, "mono": false, "snow": true, "playing": false,
				"power": clampf(since / FILM_WAKE, 0.0, 1.0)}
			continue
		if at > gone + FILM_WAKE:
			out = {}
			continue
		out = {"i": i, "what": String(a["what"]), "note": String(film.get("kind", "")) == "note",
			"at": clampf(at, 0.0, maxf(secs - 0.001, 0.0)), "mono": bool(a.get(DispatchScript.MONO, false)),
			"power": clampf(since / FILM_WAKE, 0.0, 1.0) * clampf((gone + FILM_WAKE - at) / FILM_WAKE, 0.0, 1.0),
			"playing": at >= 0.0 and at < secs}
	return out


## The actions of the kinds the power, the Environment and the films are read from, each list in order, and what cuts each film
## short: the next action that puts anything else on its screen (a picture, a live picture, `off`; on the terminal, its program).
func _index_kinds() -> void:
	var by := {"play": PackedInt32Array(), "power": PackedInt32Array(), "environment": PackedInt32Array()}
	_cut_by = {}
	for i in _actions.size():
		var kind := String((_actions[i] as Dictionary)["kind"])
		if by.has(kind):
			var list: PackedInt32Array = by[kind]
			list.append(i)
			by[kind] = list
	_of_kind = by
	for i in _of_kind["play"]:
		var key := String((_actions[i] as Dictionary)["screen"])
		_cut_by[i] = -1
		for k in range(i + 1, _actions.size()):
			var b: Dictionary = _actions[k]
			var kind := String(b["kind"])
			if (kind in ["picture", "live", "off", "play"] and String(b.get("screen", "")) == key) \
					or (key == "terminal" and kind in ["session", "type", "strike", "sleep"]):
				_cut_by[i] = k
				break


## The player of film [param what], made the first time it is shown.
func _player_of(what: String) -> ScreenFilm:
	if not _players.has(what):
		_players[what] = ScreenFilm.new(_films.get(what, {}))
	return _players[what]


## Glass [param m] showing [param film] ([method film_at]): the frame due (waited for in a render), its glass waking and going down;
## in the screen's own phosphor where it is told `mono`.
func _show_film(m: ShaderMaterial, film: Dictionary) -> void:
	if bool(film.get("snow", false)):
		m.set_shader_parameter("has_face", false)
		m.set_shader_parameter("snow", 0.85)
		m.set_shader_parameter("mono", 0.0)
		m.set_shader_parameter("frame", floor(_now * 24.0))
		m.set_shader_parameter("power", float(film["power"]))
		return
	var tex: Texture2D = null
	if bool(film.get("note", false)):
		var show: Node = _shows.get(String(film["what"]))
		tex = show.call("texture") if show != null else null
	else:
		tex = _player_of(String(film["what"])).frame_at(float(film["at"]), TablePhysics.render_waits())
	m.set_shader_parameter("has_face", tex != null)
	if tex != null:
		m.set_shader_parameter("face", tex)
	m.set_shader_parameter("snow", 0.0)
	m.set_shader_parameter("mono", 1.0 if bool(film["mono"]) else 0.0)
	m.set_shader_parameter("power", float(film["power"]))


## The terminal's glass: a film on it ([param film]) shows in place of its program; else its program's face, as lit as the desk has
## power.
func _pose_terminal(film: Dictionary) -> void:
	var m: ShaderMaterial = _mats.get("terminal")
	if m == null:
		return
	if not film.is_empty():
		_show_film(m, film)
		return
	m.set_shader_parameter("has_face", true)
	m.set_shader_parameter("face", _screens.terminal.get_texture())
	m.set_shader_parameter("mono", 0.0)
	m.set_shader_parameter("snow", 0.0)
	m.set_shader_parameter("power", _glass_power)


## Everything on the desk that runs on the grid at the power it has ([method PropRig.set_power]): its lights and its glowing parts,
## the radar's and the oscilloscope's glass, the receiver's dial lamp. What runs on its batteries ([constant BATTERY]) and a screen a
## film plays on ([param on_glass] the terminal's) stay lit.
func _pose_power(on_glass: Dictionary) -> void:
	for k in _set.rigs:
		if String(k) in BATTERY:
			continue
		var p := _power_now
		if String(k) == "terminal":
			p = maxf(p, float(on_glass.get("power", 0.0)))
		elif _film_now.has(String(k)):
			p = maxf(p, float((_film_now[String(k)] as Dictionary)["power"]))
		(_set.rigs[k] as PropRig).set_power(p)
	for key in ["radar", "scope"]:
		if _mats.has(key):
			(_mats[key] as ShaderMaterial).set_shader_parameter("power", _glass_power)
	for card in [_set.dial, _set.meter]:
		if card != null and (card as MeshInstance3D).material_override is StandardMaterial3D:
			((card as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = DispatchSet.DIAL_GLOW * _power_now


## Each note up on a screen played inside the desk at its moment ([NestedShow]: its scenes stepped, its song heard while it plays,
## held while the show is); a note gone from every screen let go.
func _play_notes() -> void:
	var up := {}
	for key in _film_now:
		var f: Dictionary = _film_now[key]
		if not bool(f.get("note", false)) or bool(f.get("snow", false)):
			continue
		var what := String(f["what"])
		up[what] = true
		if not _shows.has(what):
			var show: Node = (load(NESTED) as GDScript).new(_films[what])
			add_child(show)
			_shows[what] = show
		(_shows[what] as Node).call("play_at", float(f["at"]), _dt, true, bool(f["playing"]), feed.paused())
	for what in _shows.keys():
		if not up.has(what):
			_let_go(String(what))


## Each video file's sound in the room while its picture plays ([method ScreenFilm.hear]), held while the show is.
func _hear_films(_t: float) -> void:
	var playing := {}
	for key in _film_now:
		var f: Dictionary = _film_now[key]
		if bool(f["playing"]) and not bool(f.get("note", false)):
			playing[String(f["what"])] = float(f["at"])
	for what in _films:
		if String((_films[what] as Dictionary).get("kind", "")) != "file" or (not _players.has(what) and not playing.has(what)):
			continue
		_player_of(String(what)).hear(float(playing.get(what, -1.0)), self, playing.has(what), feed.paused(), TablePhysics.render_waits())


# --- the desk at a moment ---------------------------------------------------------------------------------------------

## Everything on the desk at [param t]: the phones, the terminal, the radar, the receiver, the printer, the screens, the
## switch, the mug, the roots. What a thing's parts do is its make's: each is fed what the script has it at now ([member _feeds],
## by thing: the receiver's signal, the radar's gain, the switch's side, the lamp's light...) and its rig poses it
## ([method DispatchSet.pose]).
func _pose(t: float) -> void:
	_feeds = {}
	_power_now = power_at(t)
	_glass_power = power_at(t, false)
	_land_notes()
	_film_now = {}
	if not (_of_kind.get("play", PackedInt32Array()) as PackedInt32Array).is_empty():
		for key in DispatchScript.FILM_SCREENS:
			var f := film_at(String(key), t)
			if not f.is_empty():
				_film_now[String(key)] = f
	_pose_phones(t)
	_screens.show_terminal(terminal_at(t))
	_play_notes()
	var on_glass: Dictionary = _film_now.get("terminal", {})
	_pose_terminal(on_glass)
	_screens.show_radar(radar_at(t))
	var st := storm_at(t)
	var voice := float(st.get("voice", 0.0))
	# the scope: the receiver's own output, swept as a scope sweeps it
	_scope.seed = _seed
	if _scope.tick(t, _open, _heard, _power_now, _sounds.receiver_share if _sounds != null else 1.0, TablePhysics.render_waits()):
		_screens.show_scope(_scope.shown())
	# the SDR screen, its rows made as show time passes them
	if _set.spectrum_screen != null and _spectrum.tick(t, _open, _bands, _power_now):
		_screens.show_spectrum({"tex": _spectrum.texture, "top": _spectrum.top(), "trace": _spectrum.trace, "power": _power_now})
	# what the receiver hears: the storm, swelling in a word said over it, never quite still
	_feeds["receiver"] = {"signal": clampf(0.08 + float(st.get("level", 0.0)) * 0.85 + voice * 0.45 + 0.03 * sin(t * 1.3), 0.0, 1.0) * _power_now}
	# what the screen throws on the desk: as much as its glass is lit, never a whole screen's worth for a cursor alone; a film's
	# picture, a screenful
	_feeds["terminal"] = {"lit": maxf(DispatchTerminal.lit_share(terminal_at(t)) * _power_now, 0.6 * float(on_glass.get("power", 0.0)))}
	_pose_printer(t)
	_pose_screens(t)
	_pose_clock(t)
	_pose_tablet(t)
	_pose_switch(t)
	_pose_mug(t)
	_feeds["radar"] = {"gain": gain_at(t)}
	_feeds["lamp"] = {"lit": lamp_at(t) * _lamp_share * _power_now}
	_pose_power(on_glass)
	_set.pose(t, _feeds)
	_roots.grow(t)
	if _air != null:
		_air.tick(t)
	var levels := env_levels(t)
	Surroundings.tick_rays(_rays, t, levels)
	if _crack != null:
		_crack.light_energy = _crack_energy * float(levels.get(-1, 1.0))
	_hear_films(t)


## Where each phone is at [param t], its lid, and what its screens show: in its row, rising to the ear, at the ear, laid open
## on the desk, back to the row; rattling while it rings; its little screen lit by a text. The pool of lit faces goes first
## to the phone in hand, then those on the desk, then one ringing or texting.
func _pose_phones(t: float) -> void:
	var cam_xf := _cam.global_transform
	var ear := cam_xf * Transform3D(Basis.from_euler(EAR_TURN * (PI / 180.0)), EAR)
	var held := cam_xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(READ_LEAN)), READ)
	var lit: Array = []                   # [phone index, which screen, state]
	for i in _set.phones.size():
		var ph: Dictionary = _set.phones[i]
		var label := String(ph["label"])
		var home: Transform3D = ph["home"]
		var place := "row"
		var mv := {}
		for m in _phone_moves:
			if String((m as Dictionary)["label"]) == label and float(m["t0"]) <= t:
				mv = m
		var xf := home
		var open := 0.0
		if not mv.is_empty():
			var u := clampf((t - float(mv["t0"])) / maxf(float(mv["dur"]), 0.01), 0.0, 1.0)
			var e := _jerkless(u)
			var a := _where(String(mv["from"]), home, ear, held, int(mv.get("slot", 0)))
			var b := _where(String(mv["to"]), home, ear, held, int(mv.get("slot", 0)))
			xf = _arc(a, b, e, 0.08 if String(mv["from"]) == "row" or String(mv["to"]) == "row" else 0.04)
			place = String(mv["to"]) if u >= 1.0 else "moving"
			var to_open := 0.0 if String(mv["to"]) == "row" else 1.0
			var from_open := 0.0 if String(mv["from"]) == "row" else 1.0
			var ou := clampf(u * 2.2, 0.0, 1.0) if to_open > from_open else clampf(u * 2.5, 0.0, 1.0)
			open = lerpf(from_open, to_open, _jerkless(ou))
			var dialing := String(mv.get("how", "")) == "dial" and t < float(mv.get("until", -INF))
			if dialing and t < float(mv.get("dialed", -INF)) + DispatchScript.SEND_AT / _sp_of(mv):
				var pressed := t >= float(mv.get("dialed", INF)) + DispatchScript.SPEED_PRESS / _sp_of(mv)
				lit.append([i, "inner", {"mode": "dial", "label": label, "digits": "1" if pressed else ""}])
			elif place == "ear" or (place == "moving" and String(mv["to"]) == "ear") or dialing:
				var secs := _call_secs(label, t)
				lit.append([i, "inner", {"mode": "calling" if dialing else "call", "label": label, "secs": secs}])
			elif place == "read" or (place == "moving" and (String(mv["to"]) == "read" or String(mv["from"]) == "read")):
				lit.append([i, "inner", _reading(label, t)])
			elif place == "desk" or (place == "moving" and String(mv["to"]) == "desk"):
				lit.append([i, "inner", {"mode": "hold", "label": label, "secs": _call_secs(label, t)}])
		# Ringing: rattling in the row, its little screen saying who; a text: its little screen with the words
		for k in _actions.size():
			var a: Dictionary = _actions[k]
			if String(a.get("label", "")) != label or _t0[k] > t or _t0[k] == INF:
				continue
			var kind := String(a["kind"])
			var e := _end_of(k)
			if kind == "ring" and t < e and place == "row":
				var cyc := fposmod(t - _t0[k], DispatchScript.BUZZ_ON + DispatchScript.BUZZ_OFF)
				if cyc < DispatchScript.BUZZ_ON:
					var j := t * 37.0
					xf = xf.translated(Vector3(sin(j * 1.7) * RATTLE, 0.0, cos(j * 2.3) * RATTLE))
					xf.basis = xf.basis * Basis(Vector3.UP, deg_to_rad(sin(j * 3.1) * RATTLE_TURN))
				lit.append([i, "outer", {"mode": "ring", "label": label}])
			elif kind == "text" and t < _t0[k] + DispatchScript.TEXT_CHIME + DispatchScript.READ_LIFT and place == "row":
				if t - _t0[k] < DispatchScript.TEXT_BUZZ:
					var j := t * 41.0
					xf = xf.translated(Vector3(sin(j * 1.9) * RATTLE * 0.6, 0.0, cos(j * 2.1) * RATTLE * 0.6))
				lit.append([i, "outer", {"mode": "text", "label": label, "words": String(a["words"])}])
		(ph["node"] as Node3D).global_transform = xf
		(ph["rig"] as PropRig).pose(t, {"open": open})
	var used := {}
	var k := 0
	lit.sort_custom(func(x: Array, y: Array) -> bool: return _rank(String(x[2]["mode"])) < _rank(String(y[2]["mode"])))
	for l in lit:
		if k >= DispatchScreens.PHONE_FACES:
			break
		_screens.show_phone(k, l[2])
		var m: ShaderMaterial = _mats["%s %d" % [String(l[1]), int(l[0])]]
		m.set_shader_parameter("has_face", true)
		m.set_shader_parameter("face", (_screens.faces[k] as SubViewport).get_texture())
		m.set_shader_parameter("power", 1.0)
		used["%s %d" % [String(l[1]), int(l[0])]] = true
		k += 1
	for i in _set.phones.size():
		for which in ["inner", "outer"]:
			var name := "%s %d" % [which, i]
			if not used.has(name):
				var m: ShaderMaterial = _mats[name]
				m.set_shader_parameter("has_face", false)
				m.set_shader_parameter("power", 0.0)


static func _rank(mode: String) -> int:
	return {"call": 0, "calling": 0, "dial": 0, "read": 0, "hold": 1, "ring": 2, "text": 2}.get(mode, 3)


## How long the call phone [param label] is on at [param t] has been on, in the night's own time ([method _night_at]): a call
## held across a black has been on the hours the clock jumped.
func _call_secs(label: String, t: float) -> float:
	return snappedf(maxf(_night_at(t) - _night_at(_call_began(label, t)), 0.0), 1.0)


## The night's own time at [param t] (seconds since its midnight before): the time the last fade up set the clock to and how
## long since, as the clock shows it ([method clock_at]) - so a black jumps it the hours the story does. A set earlier in the
## day than the one before it is the next day. Before the first set, counted back from it; with none, the show's own time.
## [param t] is on the reading's scale, so a fade is judged where it falls on it ([method _on_reading]): after a mid-way start
## the fades before it lie in the far past, and a call begun before one of them would count it.
func _night_at(t: float) -> float:
	var first := Vector2(INF, 0.0)
	var at := -INF
	var night := 0.0
	var prev := -1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "fade" or int(a.get("clock", -1)) < 0 or _t0[i] == INF:
			continue
		var mins := float(int(a["clock"]))
		while prev >= 0.0 and mins < prev:
			mins += 24.0 * 60.0
		prev = mins
		var turn := _on_reading(i, _t0[i] + float(a["secs"]) / _sp[i])
		if first.x == INF:
			first = Vector2(turn, mins * 60.0)
		if _on_reading(i, _t0[i]) > t:
			break
		at = turn
		night = mins * 60.0
	if at > -INF:
		return night + (t - at)
	return first.y - (first.x - t) if first.x < INF else t


## When the call phone [param label] is on at [param t] began: its call's first move up out of its row, whether it has been laid
## on the desk and picked up since - a call's timer runs from there until it is hung up, wherever the handset lies. A call begun
## before a mid-way start began where it falls on the reading ([method _on_reading]), never in the far past it is placed in.
func _call_began(label: String, t: float) -> float:
	var began := t
	var latest := -INF
	for m in _phone_moves:
		var mv: Dictionary = m
		var at := float(mv["t0"])
		if String(mv["label"]) != label or at > t or at < latest:
			continue
		if String(mv["from"]) == "row" and String(mv["to"]) in ["ear", "read"]:
			began = float(mv.get("began", at))
			latest = at
		elif String(mv["to"]) == "row":
			began = t
			latest = at
	return began


## The speed a move [param mv] was made at (its action's), for the moments inside it.
func _sp_of(mv: Dictionary) -> float:
	return clampf(DispatchScript.LIFT / maxf(float(mv["dur"]), 0.001), 1.0, 4.0) if String(mv.get("how", "")) == "dial" else 1.0


## What a phone held up to be read shows at [param t]: `{mode: read, label, thread: [[in | out, words, sent]]}` - the texts
## from it since it last came up, and the room's answers under each, as far as they are typed and whether sent: the latest
## few, as a phone's screen keeps them.
func _reading(label: String, t: float) -> Dictionary:
	var since := -INF
	for m in _phone_moves:
		var d: Dictionary = m
		if String(d["label"]) == label and String(d["to"]) == "read" and float(d["t0"]) <= t + 0.001:
			since = float(d["t0"])
	var thread: Array = []
	for k in _actions.size():
		var a: Dictionary = _actions[k]
		if String(a.get("label", "")) != label or _t0[k] == INF or _t0[k] > t:
			continue
		match String(a["kind"]):
			"text":
				if _t0[k] + DispatchScript.TEXT_CHIME >= since - 0.01:
					thread.append(["in", String(a["words"]), true])
			"reply":
				if not thread.is_empty():
					var times: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
					var n := 0
					while n < times.size() and times[n] <= t:
						n += 1
					thread.append(["out", String(a["text"]).substr(0, n), t >= _sent_at(k) - 0.15])
	if thread.size() > 4:
		thread = thread.slice(thread.size() - 4)
	return {"mode": "read", "label": label, "thread": thread}


## Where a phone is in [param place] ("row", "ear" - [param ear], in the world - "read", held up before the eye
## ([param held]), or "desk", its [param slot]).
func _where(place: String, home: Transform3D, ear: Transform3D, held: Transform3D, slot: int) -> Transform3D:
	match place:
		"read":
			return held
		"ear":
			return ear
		"desk":
			return _set.held_xf(maxi(slot, 0))
	return home


## Between [param a] and [param b] at [param u], lifted [param lift] at the middle of the way.
static func _arc(a: Transform3D, b: Transform3D, u: float, lift: float) -> Transform3D:
	var o := a.origin.lerp(b.origin, u) + Vector3(0, lift * sin(u * PI), 0)
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u)
	return Transform3D(Basis(q), o)


## A thing carried from [param a] to [param b], [param u] of the way (0-1), as a hand carries it past what stands in its way:
## straight up out of where it stood until it is as high as [param by] (over what stands under its way), across no lower, and
## straight down into where it goes - each end that is below that height; the rest of the way smoothly, a hand's. Across, it
## bends toward [param by] (x, z): half way between the two, it goes straight.
static func _carry(a: Transform3D, b: Transform3D, u: float, by: Vector3) -> Transform3D:
	var over := by.y
	var up := CARRY_RISE if a.origin.y < over else 0.0
	var down := CARRY_RISE if b.origin.y < over else 0.0
	var h := _jerkless(clampf((u - up) / maxf(1.0 - up - down, 1e-3), 0.0, 1.0))
	var o := a.origin * ((1.0 - h) * (1.0 - h)) + by * (2.0 * h * (1.0 - h)) + b.origin * (h * h)
	var floor_y := over
	if u < up:
		floor_y = lerpf(a.origin.y, over, _jerkless(u / up))
	elif u > 1.0 - down:
		floor_y = lerpf(over, b.origin.y, _jerkless((u - (1.0 - down)) / down))
	o.y = maxf(lerpf(a.origin.y, b.origin.y, _jerkless(u)), floor_y)
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), h)
	return Transform3D(Basis(q), o)


## Minimum jerk: a hand's way from 0 to 1.
static func _jerkless(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * x * (10.0 - 15.0 * x + 6.0 * x * x)


## The terminal at [param t]: `{lines, asleep, cursor, cursor_at, bar, alert}` - dark until a block wakes it; then the glass
## the last action at it began from, played to this moment ([DispatchTerminal]): a run of steps, a said line as far as it
## is typed, a strike backspacing it, sleep darkening the glass. The cursor blinks while it is awake.
##
## [param whole]: a redacted run being typed is there whole from its first key ([method _censor_at]).
func terminal_at(t: float, whole := false) -> Dictionary:
	var key := Vector2(t, 1.0 if whole else 0.0)
	if key == _term_key:
		return _term_at
	var g := {}
	var asleep := true
	for i in range(_actions.size() - 1, -1, -1):
		var a: Dictionary = _actions[i]
		var t0 := _t0[i]
		if t0 > t or t0 == INF:
			continue
		match String(a["kind"]):
			"session":
				g = DispatchTerminal.at(a["glass"], a["ops"], (t - t0) * _sp[i], whole)
			"type":
				var times: PackedFloat32Array = _chars.get(i, PackedFloat32Array())
				var text := String(a["text"])
				var n := 0
				while n < times.size() and times[n] <= t:
					n += 1
				while whole and n > 0 and n < text.length() and DispatchScript.is_redacted(text.unicode_at(n - 1)) \
						and DispatchScript.is_redacted(text.unicode_at(n)):
					n += 1
				g = DispatchTerminal.typed(a["glass"], text, n)
				g["awake"] = true
			"strike":
				var from := t0 + float(a["decide"]) / _sp[i]
				g = DispatchTerminal.struck(a["glass"], clampf((t - from) / maxf(_end_of(i) - from, 0.01), 0.0, 1.0))
			"sleep":
				g = a["glass"]
				if t >= t0 + 0.6:
					g = g.duplicate()
					g["awake"] = false
			_:
				continue
		asleep = not bool(g.get("awake", false))
		break
	var out := {"lines": PackedStringArray(), "asleep": asleep, "cursor": false}
	if not asleep:
		var rows := DispatchTerminal.rows_of(g, _term)
		out = {"lines": rows["lines"], "asleep": false, "cursor": fposmod(t, BLINK * 2.0) < BLINK, "cursor_at": rows["cursor"],
			"bar": rows["bar"], "chosen": rows["chosen"], "alert": rows["alert"], "crash": rows["crash"]}
	_term_key = key
	_term_at = out
	return out


## The target's track on the radar: each ping's place a spot laid out from the script alone ([method track_of]), and a
## leg to it under the voice - from the `moving` mark since the last ping, else over the moments before it ([constant
## LEG_MOST] at most), arriving as it pings; the first found where he is. A live plan's leg without a `moving` never
## begins before the plan knew of its ping.
func _build_track() -> void:
	var stops: Array = []
	var idx: Array = []
	var set_off := -1
	var offs: Array = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		match String(a["kind"]):
			"moving":
				if set_off < 0:
					set_off = i
			"ping":
				var words := int(a["after"]) - int((_actions[set_off] as Dictionary)["after"]) if set_off >= 0 else 0
				stops.append({"place": String(a["place"]), "words": words, "bearing": float(a.get("bearing", INF)),
					"range": float(a.get("range", INF))})
				idx.append(i)
				offs.append(set_off)
				set_off = -1
	var spots := track_of(stops, _rings)
	_legs = []
	var arrived := -INF
	for k in idx.size():
		var i: int = idx[k]
		var t0 := _t0[i]
		var leave := t0
		if t0 < INF and k > 0 and not bool((_actions[i] as Dictionary).get("jump", false)):
			var off: int = offs[k]
			if off >= 0 and _t0[off] < t0:
				leave = maxf(_t0[off] + DispatchScript.MOVING * 0.5 / _sp[off], arrived)
			else:
				var known := float(_leg_known.get_or_add(i, _now))
				leave = maxf(maxf(arrived, t0 - LEG_MOST), minf(known, t0))
		_legs.append({"i": i, "place": String((stops[k] as Dictionary)["place"]), "from": spots[maxi(k - 1, 0)],
			"to": spots[k], "t0": leave, "t1": t0})
		if t0 < INF:
			arrived = t0


## Where the target is on the scope at [param t] - between two places on a leg, eased - or Vector2(INF, INF) before the
## radar has found him.
func target_at(t: float) -> Vector2:
	var at := Vector2(INF, INF)
	for leg in _legs:
		var l: Dictionary = leg
		var t0 := float(l["t0"])
		var t1 := float(l["t1"])
		if t0 > t:
			break
		if t >= t1:
			at = l["to"]
			continue
		var u := clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
		return (l["from"] as Vector2).lerp(l["to"], u * u * (3.0 - 2.0 * u))
	return at


## When the sweep passes the target between [param t0] and [param t1]: once a round, where he is as it comes round.
func passes(t0: float, t1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if t1 == INF or t0 == INF:
		return out
	for n in range(int(floor(t0 / SWEEP)), int(ceil(t1 / SWEEP)) + 1):
		var p := target_at(float(n) * SWEEP)
		if p.x == INF:
			p = target_at(float(n + 1) * SWEEP)
		if p.x == INF:
			continue
		var swept := (float(n) + fposmod(p.angle() + PI * 0.5, TAU) / TAU) * SWEEP
		if swept >= t0 and swept <= t1 and target_at(swept).x < INF:
			out.append(swept)
	return out


## The radar at [param t]: the sweep's clock; the target as the sweep paints him (where he was as it last passed, the
## paints before it fading behind, a step apart where he is moving), with the place he last came to (its readout and his
## coordinates, [method DispatchScreens.radar_redactions]) and its ping's ring; the aircraft drifting across it; the jet, over the middle, while it is heard; with the gain past three,
## the clutter round him ([method clutter_at]).
func radar_at(t: float) -> Dictionary:
	var jet := -1.0
	var jet_len := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if _t0[i] > t or _t0[i] == INF:
			continue
		if String(a["kind"]) == "sound" and String(a["sound"]) == "jet" and t < _end_of(i):
			jet = t - _t0[i]
			jet_len = _end_of(i) - _t0[i]
	var st := {"t": t}
	var sweep := fposmod(t / SWEEP, 1.0) * TAU - PI * 0.5
	var now := target_at(t)
	if now.x < INF:
		var swept := t - fposmod(sweep - now.angle(), TAU) / TAU * SWEEP
		var then := target_at(swept)
		if then.x < INF:
			swept = t - fposmod(sweep - then.angle(), TAU) / TAU * SWEEP
		var paints: Array = []
		for k in TRAIL + 1:
			var tk := swept - float(k) * SWEEP
			var pk := target_at(tk)
			if pk.x == INF:
				break
			var n := int(floor(tk / SWEEP))
			pk += Vector2(DispatchSounds.hash01(_seed + 43, n) - 0.5, DispatchSounds.hash01(_seed + 47, n) - 0.5) * 2.0 * PAINT_JITTER
			paints.append(pk)
		var came: Dictionary = {}
		for leg in _legs:
			if float((leg as Dictionary)["t1"]) <= t:
				came = leg
		if not paints.is_empty() and not came.is_empty():
			st["blip"] = {"at": paints[0], "label": String(came["place"]).to_upper(), "since": t - float(came["t1"])}
			st["ping"] = t - float(came["t1"])
			var trail: Array = []
			for k in range(1, paints.size()):
				trail.append({"at": paints[k], "age": float(k), "fade": 1.0 - float(k) / float(TRAIL + 1)})
			st["trail"] = trail
	var planes: Array = []
	var k0 := int(floor((t - PLANE_PASS) / PLANE_EVERY))
	for k in range(maxi(k0, 0), int(floor(t / PLANE_EVERY)) + 1):
		var start := float(k) * PLANE_EVERY + DispatchSounds.hash01(_seed + 31, k) * PLANE_EVERY * 0.5
		var u := (t - start) / PLANE_PASS
		if u < 0.0 or u > 1.0:
			continue
		var ang := DispatchSounds.hash01(_seed + 37, k) * TAU
		var off := (DispatchSounds.hash01(_seed + 41, k) - 0.5) * 1.2
		var d := Vector2.from_angle(ang)
		planes.append({"at": d * lerpf(-1.05, 1.05, u) + d.orthogonal() * off, "heading": ang})
	if jet >= 0.0:
		var u := jet / jet_len
		planes.append({"at": Vector2(lerpf(-1.0, 1.0, u), 0.06), "heading": 0.0})
	st["planes"] = planes
	st["rings"] = roundi(_rings)
	var clutter := clutter_at(t)
	if not clutter.is_empty():
		st["clutter"] = clutter
	st["t"] = snappedf(t, 1.0 / 30.0)
	return st


## The radar's gain knob at [param t]: where it stands (1 to 10, [constant DispatchScript.GAIN_REST] when the night
## begins), turned steadily from step to step while a `gain:` turns it.
func gain_at(t: float) -> float:
	var level := float(DispatchScript.GAIN_REST)
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "gain" or _t0[i] > t or _t0[i] == INF:
			continue
		var start := _t0[i] + DispatchScript.GAIN_REACH / _sp[i]
		var turn := DispatchScript.gain_turn(int(a["from"]), int(a["to"])) / _sp[i]
		level = lerpf(float(a["from"]), float(a["to"]), clampf((t - start) / maxf(turn, 0.001), 0.0, 1.0))
	return level


## When gain action [param i] turns the knob onto step [param d]: its click.
func _step_at(i: int, d: int) -> float:
	var a: Dictionary = _actions[i]
	var from := int(a["from"])
	var to := int(a["to"])
	var start := _t0[i] + DispatchScript.GAIN_REACH / _sp[i]
	if to == from:
		return start
	return start + DispatchScript.gain_turn(from, to) / _sp[i] * float(d - from) / float(to - from)


## How many clutter blips the scope paints with its gain at [param level]: none at the handbook's three or under, all
## [constant CLUTTER_MOST] at ten.
static func clutter_n(level: int) -> int:
	var u := clampf(float(level - DispatchScript.GAIN_REST) / float(DispatchScript.GAIN_MOST - DispatchScript.GAIN_REST), 0.0, 1.0)
	return roundi(float(CLUTTER_MOST) * pow(u, CLUTTER_CURVE))


## Where the clutter stands round him on desk number [param seed]: offsets on the scope, nearest him first (the rooms of
## one building turned its own way, with him in it off its middle), so each step the knob is turned up paints the next
## nearest. The same every time.
static func clutter_of(seed: int) -> Array:
	var turn := DispatchSounds.hash01(seed + 51, 0) * PI
	var off := (Vector2(DispatchSounds.hash01(seed + 53, 0), DispatchSounds.hash01(seed + 53, 1)) - Vector2(0.5, 0.5)) * CLUTTER_BUILDING * 0.6
	var out: Array = []
	for k in CLUTTER_MOST:
		var p := (Vector2(DispatchSounds.hash01(seed + 55, k), DispatchSounds.hash01(seed + 57, k)) - Vector2(0.5, 0.5)) * CLUTTER_BUILDING
		var at := (p + off).rotated(turn)
		if at.length() < CLUTTER_NEAR:
			at = (at if at.length() > 1e-4 else Vector2.RIGHT).normalized() * CLUTTER_NEAR
		out.append(at)
	out.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.length() < y.length())
	return out


## The clutter on the scope at [param t]: `[{at, fade, chair?}]` - each blip the gain reaches, round where the target was
## when the knob was turned up past three, and from [constant CHAIR_GAIN] the chair's own at the desk ([constant CHAIR_AT],
## `chair: true`); each painted once the sweep has passed it since the knob reached it and a little off where it was each
## round (the few who move drift); a blip the knob no longer reaches fades over a sweep or two and is never painted again.
func clutter_at(t: float) -> Array:
	const CHAIR := -1                    # the chair's key among the blips
	var on := {}                         # a blip -> when the knob reached it
	var off := {}                        # ...and when it no longer did
	var mid := Vector2.ZERO
	var n := 0
	var seated := false                  # the chair painted at the knob's last step
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "gain" or _t0[i] > t or _t0[i] == INF:
			continue
		var from := int(a["from"])
		var to := int(a["to"])
		if n == 0 and clutter_n(to) > 0:
			var here := target_at(_t0[i])
			mid = here if here.x < INF else Vector2.ZERO
		var d := from
		while d != to:
			d += signi(to - from)
			var at := _step_at(i, d)
			if at > t:
				break
			var m := clutter_n(d)
			for k in range(n, m):
				on[k] = at
				off.erase(k)
			for k in range(m, n):
				off[k] = at
			n = m
			if (d >= CHAIR_GAIN) != seated:
				seated = d >= CHAIR_GAIN
				if seated:
					on[CHAIR] = at
					off.erase(CHAIR)
				else:
					off[CHAIR] = at
	var out: Array = []
	var sweep := fposmod(t / SWEEP, 1.0) * TAU - PI * 0.5
	for key in on:
		var k := int(key)
		var fade := 1.0 - clampf((t - float(off[k])) / CLUTTER_FADE, 0.0, 1.0) if off.has(k) else 1.0
		if fade <= 0.0:
			continue
		var at: Vector2 = CHAIR_AT if k == CHAIR else mid + (_clutter[k] as Vector2)
		if k % CLUTTER_MOVING == 1:
			var w := TAU / lerpf(50.0, 110.0, DispatchSounds.hash01(_seed + 63, k))
			at += Vector2(sin(t * w + DispatchSounds.hash01(_seed + 65, k) * TAU), sin(t * w * 0.7 + DispatchSounds.hash01(_seed + 67, k) * TAU)) * CLUTTER_DRIFT
		var swept := t - fposmod(sweep - at.angle(), TAU) / TAU * SWEEP
		if swept < float(on[k]):
			continue
		var rnd := int(floor(swept / SWEEP)) * CLUTTER_MOST + maxi(k, 0)
		var s := _seed + (73 if k == CHAIR else 69)
		at += (Vector2(DispatchSounds.hash01(s, rnd), DispatchSounds.hash01(s + 2, rnd)) - Vector2(0.5, 0.5)) * 2.0 * CLUTTER_JITTER
		var blip := {"at": at, "fade": fade}
		if k == CHAIR:
			blip["chair"] = true
		out.append(blip)
	return out


## When bell [param i] sounds: as the block after it goes up, when one follows in the same silence - a block at its first
## step, a said line at its first key; else in its own half beat.
func _bell_at(i: int) -> float:
	var own := _t0[i] + DispatchScript.BELL * 0.5 / _sp[i]
	var k := i + 1
	if k >= _actions.size() or _t0[k] == INF or int((_actions[k] as Dictionary)["after"]) != int((_actions[i] as Dictionary)["after"]):
		return own
	var b: Dictionary = _actions[k]
	match String(b["kind"]):
		"session":
			for o in b["ops"]:
				if String((o as Dictionary)["op"]) != "wake":
					return _t0[k] + float(o["t"]) / _sp[k]
			return _t0[k]
		"type":
			var keys: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
			return keys[0] if not keys.is_empty() and keys[0] < INF else _t0[k]
	return own


## The lamp at [param t]: how lit (0 to 1) - on until a `lamp: off`, its filament's glow dying fast from the click and gone
## in [constant LAMP_FADE]; a `lamp: on` brings it up as quickly.
func lamp_at(t: float) -> float:
	var lit := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "lamp" or _t0[i] == INF:
			continue
		var at := _t0[i] + DispatchScript.LAMP_AT / _sp[i]
		if at > t:
			continue
		var u := clampf((t - at) / LAMP_FADE, 0.0, 1.0)
		lit = lerpf(lit, 1.0 if bool(a["on"]) else 0.0, 1.0 - (1.0 - u) * (1.0 - u))
	return lit


## The note as written: [param body], with frontmatter [param head] on it where it has none of its own (a synced note's
## words are read without it, and the desk reads its `desk:` and `terminal:` blocks from it).
static func whole(body: String, head: String) -> String:
	if head.strip_edges().is_empty() or FrontMatter.split(body).has:
		return body
	return "---\n%s\n---\n%s" % [head, body]


## What this medium shows as pictures ([method Medium.pictures_of], the note's Pictures card): every picture the script
## puts on a screen, over the frame or on a tablet's page, each painted as a whole screen's - a `live:` screen is this desk,
## never painted - and each clip a screen plays (`clip`, its file's name: imported, never painted).
static func pictures_in(body: String) -> Array:
	var out := Manuscript.images(DispatchScript.pictures_only(body))
	var seen := {}
	for m in DispatchScript._rx("(?m)" + DispatchScript.VIDEO.trim_prefix("^").trim_suffix("$")).search_all(Manuscript.strip_frontmatter(body)):
		var prompt := m.get_string(3).strip_edges()
		var key := Manuscript.image_key(prompt)
		if not seen.has(key):
			seen[key] = true
			out.append({"kind": "image", "key": key, "prompt": prompt, "placement": "screen", "clip": m.get_string(2).strip_edges()})
	return out


## Where each ping's place is on the scope (its middle the desk, its edge 1), from the script alone - [param stops]
## `[{place, words, bearing?, range?}]` in order. A place given a bearing and a range is where a radar reports it: the
## bearing clockwise from the scope's top, the range in [param rings] range rings out from the desk ([method scope_at]); named
## again bare, it is that same spot, and one whose head (before a comma) was placed is a little off it. A place given no
## numbers is laid out from the words: the first its own spot ([method place_on_scope]); each after it a step on from the
## last, as long as the walk the script gives it ([constant TRACK_PACE] a second, [constant WALK_WORD] seconds a word said
## between its `moving` and its ping; [constant STEP_BARE] for a ping with none), turning at most [constant TURN_MOST] from
## the way he was going (a compass word sets the way: north is up). A track with no numbers at all is then centered on the
## scope, made smaller only if it would run off it. Nothing is to scale.
static func track_of(stops: Array, rings := float(DispatchScript.SCOPE_RINGS)) -> Array:
	var out: Array = []
	var seen := {}
	var way := 0.0
	var fixed := false
	for k in stops.size():
		var stop: Dictionary = stops[k]
		var place := String(stop["place"]).strip_edges()
		var key := place.to_lower()
		var head := key.get_slice(",", 0).strip_edges()
		var rng := float(stop.get("range", INF))
		var at: Vector2
		if rng < INF:
			at = scope_at(float(stop.get("bearing", 0.0)), rng, rings)
			fixed = true
			seen[key] = at
		elif seen.has(key):
			at = seen[key]
		elif key != head and seen.has(head):
			at = (seen[head] as Vector2) + Vector2.from_angle(DispatchSounds.hash01(key.hash(), 3) * TAU) * STEP_OFF
		elif out.is_empty():
			at = place_on_scope(place)
			way = DispatchSounds.hash01(key.hash(), 4) * TAU
		else:
			var prev: Vector2 = out.back()
			var words := int(stop.get("words", 0))
			var step := clampf(float(words) * WALK_WORD * TRACK_PACE, STEP_LEAST, STEP_MOST) if words > 0 else STEP_BARE
			var compass := compass_of(key)
			way = compass if not is_nan(compass) else way + (DispatchSounds.hash01(key.hash(), 5) - 0.5) * 2.0 * TURN_MOST
			at = prev + Vector2.from_angle(way) * step
		if not out.is_empty() and ((out.back() as Vector2) - at).length() > 1e-4:
			way = (at - (out.back() as Vector2)).angle()
		if not seen.has(key):
			seen[key] = at
		if not seen.has(head):
			seen[head] = at
		out.append(at)
	# a track laid out from words alone: its middle at the scope's, made smaller only where it would run off, keeping its
	# shape and its compass
	if out.is_empty() or fixed:
		return out
	var box := Rect2(out[0], Vector2.ZERO)
	for p in out:
		box = box.expand(p)
	var mid := box.get_center()
	var reach := 0.0
	for p in out:
		reach = maxf(reach, ((p as Vector2) - mid).length())
	var fit := minf(1.0, TRACK_EDGE / reach) if reach > 0.0 else 1.0
	for k in out.size():
		out[k] = ((out[k] as Vector2) - mid) * fit
	return out


## Where a contact at [param bearing] (degrees clockwise from the scope's top) and [param range] (range rings out from the
## desk, of [param rings]) is on the scope: its middle the desk, its edge 1.
static func scope_at(bearing: float, range: float, rings: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(bearing) - PI * 0.5) * clampf(range / maxf(rings, 1.0), 0.0, 1.0)


## The way a compass word in [param words] points on the scope (radians, north up), NAN for none.
static func compass_of(words: String) -> float:
	for w in words.to_lower().split(" ", false):
		match w.strip_edges().trim_suffix(","):
			"north", "northward", "northbound":
				return -PI * 0.5
			"south", "southward", "southbound":
				return PI * 0.5
			"east", "eastward", "eastbound":
				return 0.0
			"west", "westward", "westbound":
				return PI
	return NAN


## Where a place is on the scope (its middle the desk, its edge 1): from the place's words, the same every time - its first
## clause the spot, what follows a little off it. Nothing is to scale.
static func place_on_scope(place: String) -> Vector2:
	var head := place.get_slice(",", 0).strip_edges().to_lower()
	var a := DispatchSounds.hash01(head.hash(), 1) * TAU
	var r := lerpf(0.22, 0.82, DispatchSounds.hash01(head.hash(), 2))
	var at := Vector2.from_angle(a) * r
	if place.contains(","):
		var tail := place.get_slice(",", 1).strip_edges().to_lower()
		at += Vector2.from_angle(DispatchSounds.hash01(tail.hash(), 3) * TAU) * 0.06
	return at


## Where the receiver is open, by time: each static for its seconds, and each typed turn heard through it
## ([constant DispatchScript.RECEIVER]) from its first key to [constant RECEIVER_TAIL] past its last word, on the storm
## it last opened on (open until its last word is heard). A stretch that begins within [constant RECEIVER_JOIN] of the
## last one's end carries it on, so a static runs straight into the voice and the voice out into the next static. Each
## is a sound of the desk's plan, `{t, t1, kind: "static", storm, seed, under, words}`: `under` where a voice is said
## over it and `words` each word, `[from, to]` in seconds into it ([method DispatchSounds.receiver_level]).
func _build_receiver() -> void:
	var parts: Array = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if _t0[i] == INF:
			continue
		if String(a["kind"]) == "static":
			parts.append({"t": _t0[i], "t1": _end_of(i), "storm": String(a["storm"]), "seed": hash([_seed, i]), "words": []})
		elif String(a["kind"]) in ["type", "receiver", "session"] and String(a.get("heard", "")) == DispatchScript.RECEIVER:
			var words: Array = []
			for n in range(int(a["from"]), int(a["to"])):
				var w0 := _word_t0(n) if n < _spoken_n else INF
				var w1 := _word_t1(n) if n < _spoken_n else INF
				if w0 == INF or w1 == INF:
					words = []
					break
				words.append([w0, w1])
			var t1 := float((words.back() as Array)[1]) + RECEIVER_TAIL if not words.is_empty() else INF
			parts.append({"t": _t0[i], "t1": t1, "storm": String(a.get("storm", "popcorn")), "seed": hash([_seed, i]), "words": words})
	parts.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	_open = []
	for p in parts:
		var o: Dictionary = _open.back() if not _open.is_empty() else {}
		if o.is_empty() or float(p["t"]) > float(o["t1"]) + RECEIVER_JOIN:
			o = {"t": float(p["t"]), "t1": float(p["t1"]), "kind": "static", "storm": String(p["storm"]), "seed": int(p["seed"]),
				"under": [], "words": []}
			_open.append(o)
		o["t1"] = maxf(float(o["t1"]), float(p["t1"]))
		var words: Array = p["words"]
		if words.is_empty():
			continue
		var t := float(o["t"])
		(o["under"] as Array).append([float((words[0] as Array)[0]) - UNDER_LEAD - t, float((words.back() as Array)[1]) + UNDER_TAIL - t])
		for w in words:
			(o["words"] as Array).append([float((w as Array)[0]) - t, float((w as Array)[1]) - t])


## The receiver at [param t]: the storm it is open on, `{storm, level, voice}` - how hard the storm is, and how hard a voice
## said over it moves the needle and the trace ([method DispatchSounds.voice_level]) - {} for none.
func storm_at(t: float) -> Dictionary:
	for o in _open:
		if float(o["t"]) <= t and t < float(o["t1"]):
			var u := t - float(o["t"])
			return {"storm": String(o["storm"]), "level": DispatchSounds.receiver_level(o, u), "voice": DispatchSounds.voice_level(o, u)}
	return {}


## The printer at [param t]: its head going across while it prints, the paper's lines - every print's lines so far, the one
## printing a character at a time - and the paper fed a line at a time, and once more when a print is done ([method
## DispatchSet.feed_paper]: its creases and its fold onto the heap go with it).
func _pose_printer(t: float) -> void:
	var lines := PackedStringArray()
	var partial := ""
	var feed := 0.0
	var head := 0.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "print" or _t0[i] > t or _t0[i] == INF:
			continue
		var pl: PackedStringArray = a["lines"]
		var u := (t - _t0[i]) * _sp[i] - DispatchScript.PRINT_LEAD
		var past := u - float(pl.size()) * DispatchScript.PRINT_LINE
		if past >= 0.0:
			lines.append_array(pl)
			if past >= DispatchScript.PRINT_FEED:
				lines.append("")
			else:
				feed = past / DispatchScript.PRINT_FEED
			continue
		var k := int(floor(maxf(u, 0.0) / DispatchScript.PRINT_LINE))
		var w := fposmod(maxf(u, 0.0), DispatchScript.PRINT_LINE) / DispatchScript.PRINT_LINE
		for j in mini(k, pl.size()):
			lines.append(pl[j])
		if u >= 0.0 and k < pl.size():
			var across := clampf(w / 0.82, 0.0, 1.0)
			var line := String(pl[k])
			partial = line.substr(0, int(across * float(line.length()))) if k % 2 == 0 else line.substr(line.length() - int(across * float(line.length())))
			if k % 2 == 1:
				partial = " ".repeat(line.length() - partial.length()) + partial
			head = (across if k % 2 == 0 else 1.0 - across) - 0.5
			feed = clampf((w - 0.82) / 0.18, 0.0, 1.0)
	feed = snappedf(feed, 0.05)
	var line := DispatchSet.SHEET.y / float(DispatchScreens.PAPER_FOLD)
	var fed := _set.feed_paper((float(lines.size()) + feed) * line)
	_screens.show_paper({"lines": lines, "partial": partial, "feed": feed, "fed": fed / line})
	_feeds["printer"] = {"head": head}


## The three screens at [param t]: each the last picture pinned to it (or this desk, live), or dark after an `off`; the feed
## snowy with nothing on it; each fed how brightly its picture lights the desk (`glow`).
func _pose_screens(t: float) -> void:
	var live := false
	for k in _set.screens:
		var key := String(k)
		var film: Dictionary = _film_now.get(key, {})
		if not film.is_empty() and _mats.has(key):
			_show_film(_mats[key] as ShaderMaterial, film)
			_feeds[key] = {"glow": 0.35 * float(film["power"])}
			continue
		var shown := ""
		var since := INF
		for i in _actions.size():
			var a: Dictionary = _actions[i]
			if _t0[i] > t or _t0[i] == INF or String(a.get("screen", "")) != key:
				continue
			match String(a["kind"]):
				"picture":
					shown = ("clip:" if a.has("clip") else "") + String(a["key"])
					since = t - _t0[i]
				"live":
					shown = "live"
					since = t - _t0[i]
				"off":
					shown = ""
					since = -(t - _t0[i])
		if not _mats.has(key):
			continue
		var m: ShaderMaterial = _mats[key]
		var power := 1.0
		var tex: Texture2D = null
		var snowing := false
		if shown == "live":
			tex = _live_vp.get_texture()
			live = true
		elif shown.begins_with("clip:"):
			tex = _clip_frame(shown.substr(5), since)
			snowing = tex == null
		elif not shown.is_empty():
			tex = _pictures.get(shown)
		if since < 0.0:
			power = clampf(1.0 + since / 0.5, 0.0, 1.0)
		elif since < INF:
			power = clampf(since / 0.35, 0.0, 1.0)
		if snowing:
			# a clip not imported yet: the screen's static, never a still where a moving picture belongs
			m.set_shader_parameter("snow", 0.85)
			m.set_shader_parameter("has_face", false)
			m.set_shader_parameter("power", power * _glass_power)
			m.set_shader_parameter("frame", floor(t * 24.0))
			_feeds[key] = {"glow": (0.3 + 0.025 * sin(t * 17.0) * sin(t * 5.3)) * power}
			continue
		if key != "feed":
			m.set_shader_parameter("snow", 0.06 if tex != null and shown.begins_with("clip:") else 0.0)
			m.set_shader_parameter("frame", floor(t * 24.0))
		if key == "feed" and tex == null:
			m.set_shader_parameter("snow", 0.85)
			m.set_shader_parameter("has_face", false)
			m.set_shader_parameter("power", _glass_power)
			m.set_shader_parameter("brightness", 0.5)
			m.set_shader_parameter("frame", floor(t * 24.0))
			_feeds[key] = {"glow": 0.32 + 0.03 * sin(t * 17.0) * sin(t * 5.3)}
			continue
		if key == "feed":
			m.set_shader_parameter("snow", _feed_static)
			m.set_shader_parameter("brightness", 1.4)
			m.set_shader_parameter("frame", floor(t * 24.0))
		m.set_shader_parameter("has_face", tex != null)
		if tex != null:
			m.set_shader_parameter("face", tex)
		m.set_shader_parameter("power", (power if (tex != null or since < 0.0) else 0.0) * _glass_power)
		_feeds[key] = {"glow": 0.35 * power if tex != null else 0.0}
	_live_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if live and _live_cam != null:
		_live_cam.look_at_from_position(LIVE_EYE, LIVE_AIM, Vector3.UP)


## The switch at [param t]: up (GOOD) until it is thrown, each throw at its moment.
func _pose_switch(t: float) -> void:
	var side := "GOOD"
	var u := 1.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "switch" or _t0[i] > t or _t0[i] == INF:
			continue
		var at := _t0[i] + DispatchScript.SWITCH_AT / _sp[i]
		var was := side
		side = String(a["side"])
		u = clampf((t - at) / 0.08, 0.0, 1.0) if t < at + 0.08 else 1.0
		if t < at:
			side = was
			u = 1.0
	var up := 28.0
	var want := -up if side == "GOOD" else up
	var angle := want if u >= 1.0 else lerpf(-want, want, u)
	_feeds["switch"] = {"side": angle / up}


## The mug at [param t]: in its ring, or drunk from: lifted gently upright out of its ring and carried on an arc to the mouth
## ([method mug_way]: only as high as clears what stands under it), coming up to it from a little below, just under the eye and out
## of the picture past its lower edge; held there for the sip, and set back down in its ring the same way. It never tips.
func _pose_mug(t: float) -> void:
	var xf := _set.mug_home
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "lift" or _t0[i] > t or _t0[i] == INF or t > _end_of(i):
			continue
		var u := (t - _t0[i]) * _sp[i]
		# the mouth, under the eye wherever it is now (it leans and breathes), the mug upright and turned as it stood
		var held := Transform3D(_set.mug_home.basis, _cam.global_transform * MUG_MOUTH)
		var k := 0.0
		if u < DispatchScript.LIFT_UP:
			k = _jerkless(u / DispatchScript.LIFT_UP)
		elif u < DispatchScript.LIFT_UP + DispatchScript.LIFT_HOLD:
			k = 1.0
		else:
			k = 1.0 - _jerkless((u - DispatchScript.LIFT_UP - DispatchScript.LIFT_HOLD) / DispatchScript.LIFT_DOWN)
		xf = Transform3D(_set.mug_home.basis, mug_way(_set, _set.mug_home.origin, held.origin, k))
	_set.mug.global_transform = xf


## Where the mug is [param s] of its way (0 in its ring at [param home], 1 at the mouth at [param mouth]) on the desk of [param set]:
## a smooth arc - lifted straight up out of its ring first, then on toward the face, coming up to the mouth from a little below and
## nearer the desk - lifted no higher than clears what stands under its way ([constant MUG_LIFT]; the tallest it may be where
## nothing lower clears).
static func mug_way(set: DispatchSet, home: Vector3, mouth: Vector3, s: float) -> Vector3:
	var lift := MUG_LIFT.x
	while lift < MUG_LIFT.y and not set.way_clear(_mug_samples(home, mouth, lift), set.mug_radius, set.mug_tall(), MUG_GAP, ["mug"]):
		lift += 0.02
	return _mug_at(home, mouth, minf(lift, MUG_LIFT.y), s)


## The mug's arc ([method mug_way]) lifted [param lift] out of its ring, at [param s] of the way: a cubic curve from its ring up and
## over to the mouth.
static func _mug_at(home: Vector3, mouth: Vector3, lift: float, s: float) -> Vector3:
	var flat := Vector3(home.x - mouth.x, 0.0, home.z - mouth.z)
	var back := flat.normalized() * MUG_NEARER if flat.length() > 1e-4 else Vector3.ZERO
	var p1 := home + Vector3(0.0, lift, 0.0)
	var p2 := mouth + back + Vector3(0.0, -MUG_UNDER, 0.0)
	var u := clampf(s, 0.0, 1.0)
	var v := 1.0 - u
	return home * (v * v * v) + p1 * (3.0 * v * v * u) + p2 * (3.0 * v * u * u) + mouth * (u * u * u)


static func _mug_samples(home: Vector3, mouth: Vector3, lift: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(1, 25):
		out.append(_mug_at(home, mouth, lift, float(i) / 24.0))
	return out


## The redacted words on the terminal at [param t], and the coordinates beside the radar's blip while its glass is lit, hidden
## over this frame where the camera sees them ([DispatchCensor]): a run being typed is covered to its end from its first key,
## as an editor's box goes up when a name begins to appear (unless finishing it would wrap or scroll the screen: then as it
## stands).
func _censor_at(t: float) -> void:
	var shown := terminal_at(t)
	var runs: Array = []
	if not bool(shown["asleep"]):
		var lines: PackedStringArray = shown["lines"]
		runs = _screens.redactions(lines)
		if not runs.is_empty():
			var whole: PackedStringArray = terminal_at(t, true)["lines"]
			if whole.size() == lines.size() and whole[0] == lines[0]:
				runs = _screens.redactions(whole)
	if _set.radar_screen != null and _power_now > 0.0:
		var curve := float(_glass("radar", "scope").get("curve", 0.0))
		for r in _screens.radar_redactions():
			r["glass"] = _set.radar_screen
			r["curve"] = curve
			runs.append(r)
	_censor.cover(runs, _set.terminal_screen, float(_glass("terminal", "screen").get("curve", 0.0)), _cam, t)
	_after_censor.visible = _censor.visible and _blur.visible


# --- the black, the clock, the tablet, the clips ---------------------------------------------------------------------

## How black the picture is at [param t] (0 up, 1 black): down over a fade's seconds, up over another's. A note that opens
## in the black is black until its first fade up - from the start where it opens with no title, else from the title's
## going ([method _opened_black]), the title standing over the blurred desk as any show's does.
func fade_at(t: float) -> float:
	var black := _opened_black(t) if _dark0 else 0.0
	# the fades alone, found once for the actions in hand: this is asked every frame and of every action as the plan is made
	if not is_same(_fades_of, _actions):
		_fades_of = _actions
		_fades = PackedInt32Array()
		for i in _actions.size():
			if String((_actions[i] as Dictionary)["kind"]) == "fade":
				_fades.append(i)
	for i in _fades:
		var a: Dictionary = _actions[i]
		if _t0[i] > t or _t0[i] == INF:
			continue
		var u := clampf((t - _t0[i]) * _sp[i] / maxf(float(a["secs"]), 0.01), 0.0, 1.0)
		black = u if bool(a["to"]) else 1.0 - u
	return black


## How black a note that opens in the black is at [param t], before its first fade up: with a title or a blur to open on,
## up under them and down to black as the title goes ([method ShowOpening.title_alpha]: from 0.6 s before the opening to
## 0.3 s after it), and up while the opening is not known; with neither, black from the start. A reading started part way is past
## it: its fades decide.
func _opened_black(t: float) -> float:
	if _midway:
		return 0.0
	if not Openings.titled(feed.opening) and not Openings.blurred(feed.opening):
		return 1.0
	var opening := _opening()
	if opening == INF:
		return 0.0
	return _ease((t - (opening - BLACK_LEAD)) / (BLACK_LEAD + BLACK_TAIL))


## How far the opening's focus pull is at [param t] ([method ShowOpening.pull]), its opening at [param opening]. Where the
## note opens in the black the title's blur never lifts on the desk: it holds as the picture goes down to black, and is
## gone once it is black, so the night comes up sharp.
func _pull(t: float, opening: float) -> float:
	var p := ShowOpening.pull(ShowOpening.style_of(feed.opening, _midway), t, opening, _built_n > 0)
	if _midway or not _dark0 or opening == INF:
		return p
	return 1.0 if _opened_black(t) >= 1.0 else 0.0


## When the black before fade up [param i] is whole: the fade down's end; where the note opens in the black, when the
## title has gone ([method _opened_black]) - the show's start with no title.
func _black_from(i: int) -> float:
	for k in range(i - 1, -1, -1):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "fade" and bool(b["to"]):
			return _end_of(k) if _t0[k] < INF else _t0[i]
	if not _dark0:
		return _t0[i]
	if not Openings.titled(feed.opening) and not Openings.blurred(feed.opening):
		return 0.0
	var opening := _opening()
	return minf(opening + BLACK_TAIL, _t0[i]) if opening < INF else _t0[i]


## The clock at [param t]: `{from, to, u}` - what its cards show and, while they turn, what they turn from - {} with no
## time given yet. A fade up with a time turns them to it from a minute before it as the picture comes up (the black is a jump in
## the story's time); from there it runs a minute a minute, each minute turning over. A mid-way start's fades before it count from where they fall on the reading ([method
## _on_reading]), never from the far past its earlier actions are placed in.
func clock_at(t: float) -> Dictionary:
	var set_t := -INF
	var set_to := -1
	var was := -1
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "fade" or int(a.get("clock", -1)) < 0 or _t0[i] == INF:
			continue
		var turn := _on_reading(i, _t0[i] + float(a["secs"]) / _sp[i])
		if _on_reading(i, _t0[i]) > t:
			break
		# the black is a jump in the story's time: the cards come up a minute short of the time given and turn that minute,
		# never from wherever the clock had run to before it
		was = int(a["clock"]) - 1
		set_t = turn
		set_to = int(a["clock"])
	if set_to < 0:
		return {}
	if t < set_t + DispatchScript.CLOCK_TURN:
		var u := clampf((t - set_t) / DispatchScript.CLOCK_TURN, 0.0, 1.0)
		return {"from": DispatchScript.clock_text(was), "to": DispatchScript.clock_text(set_to if t >= set_t else was),
			"u": u if t >= set_t else 1.0}
	var gone := int(floor((t - set_t) / 60.0))
	var into := t - set_t - float(gone) * 60.0
	if gone > 0 and into < DispatchScript.CLOCK_TURN:
		return {"from": DispatchScript.clock_text(set_to + gone - 1), "to": DispatchScript.clock_text(set_to + gone),
			"u": into / DispatchScript.CLOCK_TURN}
	return {"from": DispatchScript.clock_text(set_to + gone), "to": DispatchScript.clock_text(set_to + gone), "u": 1.0}


## Every turn of the clock's cards: `[t, from, to]` - each time a fade up sets (from a minute before it, as it comes up) and each
## minute after, to the next time set or the voice's last word and what the desk does after it ([method _after_last]); while the
## last word is not heard yet, only [constant CLOCK_AHEAD] past the last word that is (the plan is made again as words come).
## Counted, never asked of [method clock_at] a minute at a time: it is made again with every sentence a live reading hears.
func _clock_turns() -> Array:
	var out: Array = []
	var last := _word_t1(_spoken_n - 1)
	var until := last + _after_last() + feed.tail()
	if last == INF:
		var k := _follower.known_last()
		var heard := _word_t1(k) if k >= 0 else 0.0
		until = (heard if heard < INF else 0.0) + CLOCK_AHEAD
	var sets: Array = []
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) == "fade" and int(a.get("clock", -1)) >= 0 and _t0[i] < INF:
			sets.append([_on_reading(i, _t0[i] + float(a["secs"]) / _sp[i]), int(a["clock"])])
	for k in sets.size():
		var t := float(sets[k][0])
		var c := int(sets[k][1])
		out.append([t, DispatchScript.clock_text(c - 1), DispatchScript.clock_text(c)])
		var stop: float = sets[k + 1][0] if k + 1 < sets.size() else until
		var g := 1
		while t + 60.0 * float(g) < stop and g < 600:
			out.append([t + 60.0 * float(g), DispatchScript.clock_text(c + g - 1), DispatchScript.clock_text(c + g)])
			g += 1
	return out


## Moment [param x] of action [param i] on the show's clock as the reading runs: a mid-way start places its earlier actions
## far in the past ([constant ReadingFollower.START_PAST], spaced by the steady voice's estimate), so one of those is put
## back before the start by its distance on the estimate, stretched to the reading's own time to the start ([member _since]).
func _on_reading(i: int, x: float) -> float:
	if _follower.start_si <= 0 or int((_actions[i] as Dictionary)["after"]) >= _follower.start_si:
		return x
	var on_est := x - ReadingFollower.START_PAST
	if _since > 0.0 and _est_from > 0.0:
		return (on_est - _est_from) * _since / _est_from
	return on_est - _est_from


func _pose_clock(t: float) -> void:
	if _set.clock_face == null:
		return
	var c := clock_at(t)
	_screens.show_clock(c if not c.is_empty() else {"from": "--:--", "to": "--:--", "u": 1.0})


## Page [param pi] set for the tablet's screen, and its words in reading order with how far down each is: `{page, words:
## [[norm, y]], links: {url key: Rect2}, own: every word written on it, drawn or not, in order}` ({} for no such page).
func _tablet_page(pi: int) -> Dictionary:
	if _tablet_pages.has(pi):
		return _tablet_pages[pi]
	var out := {}
	if pi >= 0 and pi < (_tablet_doc.get("pages", []) as Array).size():
		var tp := TabletPage.new()
		tp.placeholders = false
		var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
		tp.build(_tablet_doc, pi, float(DispatchScreens.TABLET_SIZE.x), view * 2.4, view)
		var words: Array = []
		var links := {}
		var all: Array = _tablet_doc["words"]
		var keys := tp.word_rect.keys()
		keys.sort()
		for wi in keys:
			var w: Dictionary = all[int(wi)]
			var r: Rect2 = tp.word_rect[wi]
			words.append([String(w["norm"]), r.position.y, int(wi)])
			var link := String(w.get("link", ""))
			if not link.is_empty() and not links.has(TabletScript.url_key(link)):
				links[TabletScript.url_key(link)] = r
		var own := PackedInt32Array()
		for wi in all.size():
			if int((all[wi] as Dictionary)["page"]) == pi:
				own.append(wi)
		out = {"page": tp, "words": words, "links": links, "own": own}
	_tablet_pages[pi] = out
	return out


## When page action [param i] does each thing, in show time: `{keys (each key typed, in the bar or the page's own box), tap
## (the finger down: on a link, a search box, the back arrow, the new tab's plus; INF for none), edit (the bar or box taken
## and the keyboard rising; INF where nothing is typed), load (what was typed entered, the page loading from), go (how long
## it loads), shown (up from)}`.
func _page_times(i: int) -> Dictionary:
	var a: Dictionary = _actions[i]
	var t := _t0[i]
	var sp := _sp[i]
	var keys := PackedFloat32Array()
	var tap := INF
	var edit := INF
	var load := t
	var go := DispatchScript.TABLET_GO / sp
	match String(a["how"]):
		"tap":
			tap = t + (DispatchScript.TABLET_TAP - 0.25) / sp
			load = t + DispatchScript.TABLET_TAP / sp
		"again":
			go = DispatchScript.TABLET_AGAIN * 0.7 / sp
		"back":
			tap = t + 0.3 / sp
			load = t + 0.45 / sp
			go = 0.1 / sp
		"tab":
			tap = t + 0.35 / sp
			load = t + 0.6 / sp
			go = 0.0
		_:
			var typed := String(a["text"])
			if bool(a["bar"]):
				edit = t
				for k in typed.length():
					keys.append(t + (0.3 + DispatchScript.TABLET_KEY * float(k)) / sp)
				load = t + (0.4 + DispatchScript.TABLET_KEY * float(typed.length())) / sp
			else:
				# into the page's own box: found and tapped, then typed as the tablet medium types
				tap = t + (DispatchScript.TABLET_BOX - 0.3) / sp
				edit = t + DispatchScript.TABLET_BOX / sp
				var at := TabletScript.char_times(typed)
				for k in typed.length():
					keys.append(edit + (DispatchScript.TABLET_HAND + at[k]) / sp)
				load = edit + (DispatchScript.box_typing(typed) + DispatchScript.TABLET_ENTER) / sp
	return {"keys": keys, "tap": tap, "edit": edit, "load": load, "go": go, "shown": load + go}


## The page action before [param i] (-1 for none): what is up on the tablet as it begins.
func _page_before(i: int) -> int:
	for k in range(i - 1, -1, -1):
		if String((_actions[k] as Dictionary)["kind"]) == "page":
			return k
	return -1


## The page of page action [param i] scrolled at [param t] (px down it): still while it is first looked at, where it came up
## ([method _page_base]), and never looked at before the camera is on the tablet ([method _tablet_seen]); then to each word said on it as it is said, and to its message box for a reply typed into it
## ([method _page_follow]); with none, eased down the page over the time it is up ([constant PAGE_GLIDE]).
func _page_scroll(i: int, t: float) -> float:
	var a: Dictionary = _actions[i]
	var pg := _tablet_page(int(a["page"]))
	if pg.is_empty() or _t0[i] == INF:
		return 0.0
	var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
	var most := maxf((pg["page"] as TabletPage).height - view, 0.0)
	var base := minf(_page_base(i), most)
	var look := DispatchScript.TABLET_LOOK if String(a["how"]) in ["type", "tap", "search"] else DispatchScript.TABLET_AGAIN * 0.5
	var start := maxf(float(_page_times(i)["shown"]), _tablet_seen(i)) + look / _sp[i]
	if t <= start:
		return base
	var marks: Array = _page_follow(i, view, most)["marks"]
	if not marks.is_empty() or not (a.get("said", []) as Array).is_empty():
		var from := base
		var goal := base
		var since := start
		for m in marks:
			var at := maxf(float((m as Array)[0]), start)
			if at > t:
				break
			from = lerpf(from, goal, _ease((at - since) / PAGE_EASE))
			since = at
			# held to the page here: the marks are kept as first worked out, which may be for the words lit, unbounded
			goal = minf(float((m as Array)[1]), most)
		return lerpf(from, goal, _ease((t - since) / PAGE_EASE))
	var end := _page_end(i)
	if end < INF:
		if end - start < PAGE_GLIDE_LEAST:
			return base
		return lerpf(base, minf(most, base + PAGE_GLIDE * (end - start)), _ease((t - start) / (end - start)))
	return minf(base + (t - start) * PAGE_DRIFT, most)


## When the camera is on the tablet page action [param i] is on: [constant CAMERA_ARRIVES] after it was picked up (-INF
## where it was not). A page is looked at from then, so the first page of a tablet just picked up stays where it came up
## until the camera has got to it.
func _tablet_seen(i: int) -> float:
	for k in range(i - 1, -1, -1):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "tablet":
			return _t0[k] + CAMERA_ARRIVES if bool(b["up"]) and _t0[k] < INF else -INF
	return -INF


## Where the page of page action [param i] stands as it comes up: its top - or, come back to by the back arrow or loaded
## again, where it was left ([method _page_left]).
func _page_base(i: int) -> float:
	var a: Dictionary = _actions[i]
	match String(a["how"]):
		"back":
			var j := int(a.get("resume", -1))
			return _page_left(j) if j >= 0 else 0.0
		"again":
			var j := _page_before(i)
			return _page_left(j) if j >= 0 else 0.0
	return 0.0


## Where the page of page action [param j] is scrolled as it is left: as it stood, or brought to what the finger went to on
## it ([method _reach_scroll]).
func _page_left(j: int) -> float:
	var k := -1
	for n in range(j + 1, _actions.size()):
		if String((_actions[n] as Dictionary)["kind"]) == "page":
			k = n
			break
	if k < 0 or _t0[k] == INF or _t0[j] == INF:
		return 0.0
	var reached := _reach_scroll(j, k)
	return reached if reached >= 0.0 else _page_scroll(j, _t0[k])


## What page action [param k] puts the finger to on the page of [param j], the one up before it: the link it taps, or the
## search box it types into - where that is on the page (a zero rect for neither).
func _reach_rect(j: int, k: int) -> Rect2:
	var a: Dictionary = _actions[k]
	var bp := _tablet_page(int((_actions[j] as Dictionary)["page"])) if j >= 0 else {}
	if bp.is_empty():
		return Rect2()
	match String(a["how"]):
		"tap":
			return (bp["links"] as Dictionary).get(TabletScript.url_key(String(a["url"])), Rect2())
		"search":
			return Rect2() if bool(a["bar"]) else (bp["page"] as TabletPage).search_rect
	return Rect2()


## Where the page of page action [param j] is brought to for what page action [param k] reaches on it ([method
## _reach_rect]; -1 for nothing): where it stands if that is in view, else that [constant TAP_KEEP] down the view.
func _reach_scroll(j: int, k: int) -> float:
	var r := _reach_rect(j, k)
	if r.size == Vector2.ZERO:
		return -1.0
	var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
	var most := maxf((_tablet_page(int((_actions[j] as Dictionary)["page"]))["page"] as TabletPage).height - view, 0.0)
	var at := _page_scroll(j, _t0[k])
	# a box is typed into over the keyboard: it is kept in the part of the view the keyboard leaves
	var foot := 1.0 - TAP_MARGIN if String((_actions[k] as Dictionary)["how"]) == "tap" else 1.0 - TabletChrome.KEYBOARD - TAP_MARGIN
	if r.position.y >= at + view * TAP_MARGIN and r.end.y <= at + view * foot:
		return at
	return clampf(r.position.y - view * TAP_KEEP, 0.0, most)


static func _ease(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## When page action [param i] is no longer up: the next page, or the tablet put down (INF until placed).
func _page_end(i: int) -> float:
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "page" or (String(b["kind"]) == "tablet" and not bool(b["up"])):
			return _t0[k]
	return INF


## How page action [param i] follows what is said while it is up: `{marks: [[when, to]], lit: [[page word, spoken word]]}`.
## A word said is found on the page reading on from the last one found (the next word there), or - one of
## [constant FOLLOW_LETTERS] letters or more, the word said after it the next word there - further on within
## [constant FOLLOW_WINDOW] words, its run starting back at the words said just before it that stand just before it there
## (the short words a phrase is never found by); each found is a mark the
## page scrolls to, kept [constant PAGE_KEEP] down the view ([param view] high, [param most] the furthest down), and a run of
## [constant READ_RUN] or more read on in a row is read off the page, its words lit as they are said. A reply typed into the
## page is a mark too, its message box brought [constant BOX_KEEP] down the view, and its words are typed, never followed.
## A page with places marked for what is said ([method DispatchScript.said_in]) goes to those alone, each as its words
## begin ([method _said_place]): no word is looked for on it, and none lit.
func _page_follow(i: int, view: float, most: float) -> Dictionary:
	if _follow.has(i):
		return _follow[i]
	var a: Dictionary = _actions[i]
	var pg := _tablet_page(int(a["page"]))
	var marks: Array = []
	var lit: Array = []
	var words: Array = pg.get("words", [])
	var spoken: PackedStringArray = _parsed["spoken"]
	var end := _spoken_n
	var posts: Array = []                 # the replies typed into it
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "page" or (String(b["kind"]) == "tablet" and not bool(b["up"])):
			end = int(b["after"])
			break
		if String(b["kind"]) == "post":
			posts.append(k)
	var cursor := 0
	var used := int(a["after"]) - 1       # the last spoken word followed or typed: a run reaches back no further
	var run: Array = []                   # [page word, spoken word] read on in a row
	var complete := true
	var places: Array = a.get("said", []) if not pg.is_empty() else []
	for si in range(int(a["after"]), mini(end, spoken.size())):
		var typed := false
		for k in posts:
			var post: Dictionary = _actions[k]
			if si == int(post["from"]) and not pg.is_empty():
				if _t0[k] == INF:
					complete = false
				else:
					marks.append([_t0[k] + 0.1, clampf((pg["page"] as TabletPage).reply_rect.position.y - view * BOX_KEEP, 0.0, most)])
			typed = typed or (si >= int(post["from"]) and si < int(post["to"]))
		if not complete:
			break
		if typed:
			if run.size() >= READ_RUN:
				lit.append_array(run)
			run = []
			used = si
			continue
		var w := String(spoken[si])
		var t := _word_t0(si)
		if t == INF:
			complete = false
			break
		if not places.is_empty():
			continue
		var j := -1
		# a mark with no letters on the page (a dash, an arrow) is read past, never said
		while not run.is_empty() and cursor < words.size() and String((words[cursor] as Array)[0]).is_empty():
			cursor += 1
		if cursor < words.size() and String((words[cursor] as Array)[0]) == w and not run.is_empty() \
				and (not _ends_sentence(words[cursor - 1]) or si + 1 >= spoken.size() or cursor + 1 >= words.size()
				or String((words[cursor + 1] as Array)[0]) == String(spoken[si + 1])):
			# reading on past a sentence's end there takes a phrase, as finding one does ("me. I moved" is not "I have")
			j = cursor
		elif w.length() >= FOLLOW_LETTERS and si + 1 < spoken.size():
			# a phrase found further on: this word and the next said, one after the other there
			for k in range(cursor, mini(cursor + FOLLOW_WINDOW, words.size() - 1)):
				if String((words[k] as Array)[0]) == w and String((words[k + 1] as Array)[0]) == String(spoken[si + 1]):
					j = k
					break
		if j < 0:
			if run.size() >= READ_RUN:
				lit.append_array(run)
			run = []
			continue
		if not run.is_empty() and j != cursor:
			if run.size() >= READ_RUN:
				lit.append_array(run)
			run = []
		if run.is_empty():
			# a phrase found starts its run back at the words said just before it that stand just before it there (the
			# short ones a phrase is never found by: "A woman in", "Same here. This one sat across"), so it is read whole
			var back := 1
			var pj := j - 1
			while si - back > used and pj >= cursor:
				if String((words[pj] as Array)[0]).is_empty():
					pj -= 1
					continue
				if String((words[pj] as Array)[0]) != String(spoken[si - back]) or _word_t0(si - back) == INF:
					break
				run.push_front([int((words[pj] as Array)[2]), si - back])
				back += 1
				pj -= 1
			if not run.is_empty():
				t = _word_t0(int((run[0] as Array)[1]))
		run.append([int((words[j] as Array)[2]), si])
		marks.append([t, clampf(float((words[j] as Array)[1]) - view * PAGE_KEEP, 0.0, most)])
		cursor = j + 1
		used = si
	if run.size() >= READ_RUN:
		lit.append_array(run)
	if not places.is_empty():
		var from := int(a["after"])
		var said := spoken.slice(from, maxi(mini(end, spoken.size()), from))
		for p in places:
			var at := TabletScript.find_run(said, (p as Dictionary)["words"])
			if at >= 0 and _word_t0(from + at) < INF:
				marks.append([_word_t0(from + at), _said_place(pg, int(p["before"]), view, most)])
		marks.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out := {"marks": marks, "lit": lit}
	if complete:
		_follow[i] = out
	return out


## Whether page word [param w] (`[norm, y, word]`, [method _tablet_page]) ends a sentence as written.
func _ends_sentence(w: Array) -> bool:
	var text := String((_tablet_doc["words"][int(w[2])] as Dictionary)["text"])
	return TabletScript._rx("[.!?][\"')\\]”’*_]*$").search(text) != null


## Where the page [param pg] ([method _tablet_page]) is brought to for a `said` mark with [param before] of its words
## written above it: what stands under the mark kept [constant PAGE_KEEP] down the view, as a word followed is.
func _said_place(pg: Dictionary, before: int, view: float, most: float) -> float:
	var tp: TabletPage = pg["page"]
	var own: PackedInt32Array = pg["own"]
	var top := 0.0
	for k in range(mini(before, own.size()) - 1, -1, -1):
		if tp.word_rect.has(own[k]):
			top = (tp.word_rect[own[k]] as Rect2).end.y
			break
	return clampf(top - view * PAGE_KEEP, 0.0, most)


## The words of page action [param i] read off it by [param t], lit as the tablet medium lights what its voice reads
## ([method TabletPage.draw]): `{times: {page word: Vector2(said from, to)}, cur, frac, now, char0, hue0}`.
func _page_lit(i: int, t: float) -> Dictionary:
	var view := float(DispatchScreens.TABLET_SIZE.y) - TabletChrome.TOP
	var times := {}
	var cur := -1
	var frac := 0.0
	for pair in _page_follow(i, view, 1.0e9)["lit"]:
		var wi := int((pair as Array)[0])
		var si := int((pair as Array)[1])
		var t0 := _word_t0(si)
		var t1 := _word_t1(si)
		if t0 == INF or t0 > t or t - t1 > BookMedium.TRAIL_TAU * 4.0:
			continue
		times[wi] = Vector2(t0, t1)
		if t < t1:
			cur = wi
			frac = clampf((t - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
	if times.is_empty():
		return {}
	return {"times": times, "cur": cur, "frac": frac, "now": t, "char0": _tablet_char0, "hue0": _tablet_hue0}


## What a tab says of the page in it: the page's title; a blank tab's.
func _tab_title(p: int) -> String:
	var pg := _tablet_page(p)
	return (pg["page"] as TabletPage).title if not pg.is_empty() else "New Tab"


## What the address bar says of page [param p]: its host - or, a search's results, what was searched for, as a browser's
## bar does ("" for a blank tab).
func _bar_text(p: int) -> String:
	var pages: Array = _tablet_doc.get("pages", [])
	if p < 0 or p >= pages.size():
		return ""
	var pg: Dictionary = pages[p]
	if bool(pg.get("results", false)) and not String(pg.get("query", "")).is_empty():
		return String(pg["query"])
	return TabletScript.host_of(String(pg["url"]))


## The browser as page action [param i] leaves it, into [param face]: its page (none in a blank tab), what the bar says,
## its tabs by their titles, and whether a page is behind this one.
func _browser_after(face: Dictionary, i: int) -> void:
	var a: Dictionary = _actions[i]
	var titles: Array = []
	for p in a.get("tabs", [int(a["page"])]):
		titles.append(_tab_title(int(p)))
	face["tabs"] = titles
	face["tab"] = clampi(int(a.get("tab", 0)), 0, titles.size() - 1)
	face["can_back"] = int(a.get("behind", 0)) > 0
	face["page"] = _tablet_page(int(a["page"])).get("page")
	face["url"] = _bar_text(int(a["page"]))


## A finger's tap on the tablet at [param at], come down at [param when], into [param face].
static func _tap(face: Dictionary, at: Vector2, when: float, t: float) -> void:
	if when == INF or at == Vector2.ZERO:
		return
	face["tap"] = at
	face["tap_u"] = snappedf((t - when) / 0.5, 0.02) if t >= when else -1.0


## The tablet at [param t]: `{lift (0 on the desk, 1 held up), face}` - the face as [method DispatchScreens.show_tablet]
## takes it: dark until it is woken, and laid down, lit as it was left until it locks itself ([method _locking]; picked up
## again before that, it is still lit); on the blank tab it wakes to; the page up, or the one before it while the hand reaches
## the next - a link or a search box brought into view and tapped, an address typed into the bar, a search into the page's
## own box, the back arrow or the new tab's plus tapped; the page loading; scrolled; the keyboard up while anything is
## typed; a reply typed into the page's message box as it is said, and sent.
func tablet_at(t: float) -> Dictionary:
	var lift := 0.0
	var power := 0.0
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if String(a["kind"]) != "tablet" or _t0[i] > t or _t0[i] == INF:
			continue
		var r := (t - _t0[i]) * _sp[i]
		if bool(a["up"]):
			lift = clampf(r / DispatchScript.TABLET_UP, 0.0, 1.0)
			power = maxf(power, clampf((r - 0.5) / 0.4, 0.0, 1.0))
		else:
			lift = 1.0 - clampf(r / DispatchScript.TABLET_DOWN, 0.0, 1.0)
			power = _locking(t - _laid_at(i))
	if power <= 0.0:
		return {"lift": lift, "face": {"power": 0.0}}
	var face := {"power": snappedf(power, 0.02), "textures": _page_tex, "url": "", "tabs": [_tab_title(-1)], "tab": 0, "seed": _seed,
		"minutes": _minutes_at(t), "battery": 64.0 - t / 600.0, "now": snappedf(t, 0.05)}
	var cur := -1
	for i in _actions.size():
		if String((_actions[i] as Dictionary)["kind"]) == "page" and _t0[i] <= t and _t0[i] < INF:
			cur = i
	if cur < 0:
		return {"lift": lift, "face": face}
	var before := _page_before(cur)
	var a: Dictionary = _actions[cur]
	var pt := _page_times(cur)
	var how := String(a["how"])
	var sp := _sp[cur]
	var load := float(pt["load"])
	if t >= float(pt["shown"]):
		_browser_after(face, cur)
		face["scroll"] = snappedf(_page_scroll(cur, t), 0.5)
		face["lit"] = _page_lit(cur, t)
		if how == "tab":
			# a blank tab takes an address: its bar ready, the keyboard up
			face["typing"] = true
			face["typed"] = ""
			face["kb"] = snappedf(_ease((t - float(pt["shown"])) * sp / KEYBOARD), 0.02)
		elif float(pt["edit"]) < INF:
			face["kb"] = snappedf(1.0 - _ease((t - load) * sp / KEYBOARD), 0.02)
		_post_at(face, cur, t)
		_sound_at(face, cur, t)
		_clear_keyboard(face)
		return {"lift": lift, "face": face}
	# what was up before it, while the hand reaches this one
	var blank := before >= 0 and String((_actions[before] as Dictionary)["how"]) == "tab"
	if before >= 0:
		_browser_after(face, before)
		face["scroll"] = snappedf(_page_scroll(before, _t0[cur]), 0.5)
	match how:
		"tap", "search":
			var want := _reach_scroll(before, cur)
			if want >= 0.0:
				var u := _ease((t - _t0[cur]) / maxf(float(pt["tap"]) - _t0[cur] - 0.2, 0.1))
				face["scroll"] = snappedf(lerpf(float(face["scroll"]), want, u), 0.5)
				_tap(face, _reach_rect(before, cur).get_center() + Vector2(0.0, TabletChrome.TOP - float(face["scroll"])), float(pt["tap"]), t)
		"back":
			_tap(face, TabletChrome.back_at(), float(pt["tap"]), t)
		"tab":
			_tap(face, TabletChrome.plus_rect(Vector2(DispatchScreens.TABLET_SIZE)).get_center(), float(pt["tap"]), t)
	if blank:
		# a blank tab's bar is ready, its keyboard up
		face["typing"] = true
		face["typed"] = ""
		face["kb"] = 1.0
	var keys: PackedFloat32Array = pt["keys"]
	var edit := float(pt["edit"])
	if edit < INF and t >= edit:
		var typed := String(a["text"])
		var n := 0
		while n < keys.size() and keys[n] <= t:
			n += 1
		var in_box := not bool(a["bar"])
		if t < load:
			if in_box:
				face["box"] = typed.substr(0, n)
			else:
				face["typing"] = true
				face["typed"] = typed.substr(0, n)
			if not blank:
				face["kb"] = snappedf(_ease((t - edit) * sp / KEYBOARD), 0.02)
			if n > 0 and (t - keys[n - 1]) * sp < KEY_SHOWN:
				face["key"] = typed[n - 1]
				face["key_k"] = snappedf(1.0 - (t - keys[n - 1]) * sp / KEY_SHOWN, 0.05)
			elif (load - t) * sp < 0.25:
				face["key"] = "\n"
				face["key_k"] = 1.0
		else:
			if in_box:
				face["box"] = typed
			face["typing"] = false
			face["kb"] = snappedf(1.0 - _ease((t - load) * sp / KEYBOARD), 0.02)
	if t >= load and not how in ["back", "tab"]:
		face["url"] = _bar_text(int(a["page"]))
		face["load"] = snappedf(clampf((t - load) / maxf(float(pt["go"]), 0.01), 0.0, 1.0), 0.02)
	return {"lift": lift, "face": face}


## When the tablet put down by action [param i] lies on the desk again - where that falls on the reading, for one put down
## before a mid-way start ([method _on_reading]).
func _laid_at(i: int) -> float:
	return _on_reading(i, _end_of(i))


## How lit the tablet's screen is [param lain] seconds after it is laid down (0-1): left on for [constant TABLET_LOCK], dimmed
## to [constant TABLET_DIMMED] for the last [constant TABLET_DIM] of them, then dark over [constant TABLET_OFF].
static func _locking(lain: float) -> float:
	if lain >= TABLET_LOCK:
		return TABLET_DIMMED * (1.0 - clampf((lain - TABLET_LOCK) / TABLET_OFF, 0.0, 1.0))
	return lerpf(1.0, TABLET_DIMMED, _ease((lain - (TABLET_LOCK - TABLET_DIM)) / 0.6))


## A reply typed into the message box of the page of page action [param i], at [param t], into [param face]: the box
## tapped, the keyboard up, its words so far (`post`), and its Send pressed - then the box empty again, and what was sent
## (`sent`: `{text, at}`) for a live page to show with its paid messages ([TabletPage]).
func _post_at(face: Dictionary, i: int, t: float) -> void:
	var page: TabletPage = face.get("page")
	if page == null or page.reply_rect.size == Vector2.ZERO:
		return
	for k in range(i + 1, _actions.size()):
		var b: Dictionary = _actions[k]
		if String(b["kind"]) == "page" or (String(b["kind"]) == "tablet" and not bool(b["up"])):
			return
		if String(b["kind"]) != "post" or _t0[k] == INF or _t0[k] > t:
			continue
		var sp := _sp[k]
		var tapped := _t0[k] + (DispatchScript.TABLET_POST - 0.6) / sp
		var sent := _sent_at(k)
		var down := Vector2(0.0, TabletChrome.TOP - float(face.get("scroll", 0.0)))
		if t >= tapped:
			face["posting"] = true
		if t >= sent:
			# sent: the box empty again, the keyboard going down; on a live page it stands with the paid messages
			face["kb"] = snappedf(1.0 - _ease((t - sent) * sp / KEYBOARD), 0.02)
			var was: Array = face.get("sent", [])
			face["sent"] = was + [{"text": String(b["text"]), "at": sent}]
			_tap(face, page.send_rect().get_center() + down, sent - 0.15, t)
			continue
		_tap(face, page.reply_rect.get_center() + down, tapped, t)
		if sent < INF and t >= sent - 0.15:
			_tap(face, page.send_rect().get_center() + down, sent - 0.15, t)
		if t < tapped:
			continue
		face["kb"] = snappedf(_ease((t - tapped) * sp / KEYBOARD), 0.02)
		var times: PackedFloat32Array = _chars.get(k, PackedFloat32Array())
		var n := 0
		while n < times.size() and times[n] <= t:
			n += 1
		var text := String(b["text"])
		face["post"] = text.substr(0, n)
		if n > 0 and (t - times[n - 1]) * sp < KEY_SHOWN:
			face["key"] = text[n - 1]
			face["key_k"] = snappedf(1.0 - (t - times[n - 1]) * sp / KEY_SHOWN, 0.05)


## A live page's sound button at [param t], into [param face] (page action [param i]'s page): muted, and tapped on
## [constant SOUND_LEAD] before each run of words heard through the tablet while the page is up, and off again
## [constant SOUND_TAIL] after it (`sound`, and the finger's `tap`).
func _sound_at(face: Dictionary, i: int, t: float) -> void:
	var page: TabletPage = face.get("page")
	if page == null or page.sound_rect.size == Vector2.ZERO:
		return
	var from := _t0[i]
	var to := _page_end(i)
	var at := page.sound_rect.get_center() + Vector2(0.0, TabletChrome.TOP - float(face.get("scroll", 0.0)))
	for run in (_parsed.get("heard", []) as Array):
		var r: Dictionary = run
		if String(r["band"]) != "tablet":
			continue
		var on := _word_t0(int(r["from"])) - SOUND_LEAD
		var off := _word_t1(int(r["to"]) - 1) + SOUND_TAIL
		if on == INF or on < from or on >= to:
			continue
		if t >= on and t < off:
			face["sound"] = true
		if t >= on and t < on + 0.5:
			_tap(face, at, on, t)
		elif off < INF and t >= off and t < off + 0.5:
			_tap(face, at, off, t)


## A live page ([TabletPage], built to the screen) with a reply being typed into it pushed up by as much as the keyboard
## covers of its message box, and down again as the keyboard goes: the words typed stay in sight. The finger's tap goes with it.
func _clear_keyboard(face: Dictionary) -> void:
	var page: TabletPage = face.get("page")
	if page == null or not page.live or not bool(face.get("posting", false)):
		return
	var size := Vector2(DispatchScreens.TABLET_SIZE)
	var keys_top := size.y - size.y * TabletChrome.KEYBOARD * float(face.get("kb", 0.0))
	var scroll := float(face.get("scroll", 0.0))
	var push := maxf(page.reply_rect.end.y + TabletChrome.TOP - scroll + KEYBOARD_CLEAR - keys_top, 0.0)
	if push <= 0.0:
		return
	face["scroll"] = snappedf(scroll + push, 0.5)
	if face.has("tap"):
		face["tap"] = (face["tap"] as Vector2) - Vector2(0.0, push)


## The desk's time at [param t] in minutes into the day (the clock's, [method clock_at]; late evening before it is set):
## what the tablet's status bar says.
func _minutes_at(t: float) -> int:
	var c := clock_at(t)
	var hm := String(c.get("to", "")).split(":")
	return int(hm[0]) * 60 + int(hm[1]) if hm.size() == 2 else 22 * 60


## A picture on a tablet's page by its key: the player the live desk once `live: tablet` has begun (dark before), else
## the painted picture.
func _page_tex(key: String) -> Texture2D:
	if key == Manuscript.image_key(DispatchScript.PLAYER):
		if _live_tablet(_now) and _live_vp != null:
			return _live_vp.get_texture()
		if _black == null:
			var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
			img.fill(Color(0.01, 0.01, 0.012))
			_black = ImageTexture.create_from_image(img)
		return _black
	return _pictures.get(key)


## Is the desk playing live into the tablet's player at [param t]: a `live: tablet` begun, and the tablet's screen not gone dark
## since (laid down, it plays on until it locks, [method _locking]; picked up again before that, it never stopped)?
func _live_tablet(t: float) -> bool:
	var live := false
	var locks := INF                      # when the screen of the tablet laid down goes dark, unless it is picked up first
	for i in _actions.size():
		var a: Dictionary = _actions[i]
		if _t0[i] > t or _t0[i] == INF:
			continue
		if String(a["kind"]) == "live" and String(a["screen"]) == "tablet":
			live = true
		elif String(a["kind"]) == "tablet":
			if bool(a["up"]):
				if locks <= _on_reading(i, _t0[i]):
					live = false
				locks = INF
			else:
				locks = _laid_at(i) + TABLET_LOCK + TABLET_OFF
	return live and t < locks


## The tablet at [param t]: lifted off the desk and held low over its near edge to be read, the camera looking down into it,
## and laid back, carried by this desk's way ([method tablet_route]); its screen as [method tablet_at] has it.
func _pose_tablet(t: float) -> void:
	if _set.tablet == null:
		return
	var st := tablet_at(t)
	var lift := float(st["lift"])
	var xf := _set.tablet_home
	if lift > 0.0:
		xf = _carry(_set.tablet_home, _set.tablet_held_xf(), _jerkless(lift), _tablet_route)
	_set.tablet.global_transform = xf
	var face: Dictionary = st["face"]
	_screens.show_tablet(face)
	var m: ShaderMaterial = _mats.get("tablet")
	if m != null:
		m.set_shader_parameter("glow", TABLET_GLOW * float(face.get("power", 0.0)))
	if float(face.get("power", 0.0)) > 0.0 and _live_tablet(t) and _live_vp != null:
		_live_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _live_cam != null:
			_live_cam.look_at_from_position(LIVE_EYE, LIVE_AIM, Vector3.UP)


## How the tablet is carried between its place on [param set]'s desk and the hand: what its way bends by, as high as it is
## carried ([method _carry]'s `by`). It keeps [constant CARRY_GAP] over what stands under it, by each thing's own outline, so it
## is never lifted over what it only passes beside ([method DispatchSet.slab_clear]): the straightest of [method _tablet_vias]
## that clears no higher than the hand holds it, as low as it does; else the lowest that clears, by any of them; at
## [constant TABLET_OVER]'s most and straight where nothing does.
static func tablet_route(set: DispatchSet) -> Vector3:
	if set.tablet == null:
		return Vector3.ZERO
	var home := set.tablet_home
	var held := set.tablet_held_xf()
	var vias := _tablet_vias(home.origin, held.origin)
	var hand := held.origin.y - home.origin.y
	var clears := func(via: Vector3, over: float) -> bool:
		return set.slab_clear(set.tablet_box, home, tablet_way(home, held, Vector3(via.x, home.origin.y + over, via.z)), CARRY_GAP, ["tablet"])
	for via in vias:
		var over := TABLET_OVER.x
		while over < hand + 0.001:
			if clears.call(via, over):
				return Vector3(via.x, home.origin.y + over, via.z)
			over += 0.01
	var over := maxf(hand, TABLET_OVER.x) + 0.01
	while over < TABLET_OVER.y + 0.001:
		for via in vias:
			if clears.call(via, over):
				return Vector3(via.x, home.origin.y + over, via.z)
		over += 0.01
	return Vector3(vias[0].x, home.origin.y + TABLET_OVER.y, vias[0].z)


## What the tablet's way from [param home] to [param held] may bend by (x, z), the straightest first: straight; half round;
## out toward the chair as far as the hand, then along the desk's near side; and drawn out [constant TABLET_DRAW] past the hand
## first, as a thing is taken from beside what stands close in front of it.
static func _tablet_vias(home: Vector3, held: Vector3) -> Array[Vector3]:
	var mid := home.lerp(held, 0.5)
	var corner := Vector3(home.x, mid.y, held.z)
	return [mid, mid.lerp(corner, 0.5), corner, corner + Vector3(0.0, 0.0, TABLET_DRAW)]


## Where the tablet is at each step of its way from [param home] to [param held] by [param route] ([method tablet_route]), as
## it is posed ([method _pose_tablet]) - past its first moment, where it still lies in its place.
static func tablet_way(home: Transform3D, held: Transform3D, route: Vector3) -> Array:
	var out: Array = []
	for i in range(1, 41):
		out.append(_carry(home, held, _jerkless(float(i) / 40.0), route))
	return out


## Clip [param key]'s frame [param secs] into it, looping ([method Illustrations.clip_frame]); null until it is imported.
func _clip_frame(key: String, secs: float) -> Texture2D:
	var clip: Dictionary = _clips.get(key, {})
	if clip.is_empty() or int(clip.get("frames", 0)) <= 0:
		return null
	var i := posmod(int(floor(maxf(secs, 0.0) * float(clip.get("fps", 12)))), int(clip["frames"]))
	var cur: Dictionary = _clip_tex.get(key, {})
	if int(cur.get("i", -1)) == i:
		return cur["tex"]
	var img := Image.load_from_file(Illustrations.clip_frame(clip, i))
	if img == null or img.is_empty():
		return cur.get("tex")
	var tex: ImageTexture = cur.get("tex")
	if tex != null and Vector2i(tex.get_size()) == img.get_size():
		tex.update(img)
	else:
		tex = ImageTexture.create_from_image(img)
	_clip_tex[key] = {"i": i, "tex": tex}
	return tex


# --- the camera --------------------------------------------------------------------------------------------------------

## Whether the clock moving [param moved] seconds while [param waited] went by on the machine's clock is a jump the camera is put
## across (a seek, a reading begun elsewhere) - not a stall of the app's thread (a heavy frame, a note coming up on a screen), which
## moves the clock as far as the time it took and is eased out of.
static func jumped(moved: float, waited: float) -> bool:
	return moved > waited + 1.0 or moved < -1.0


## What the camera looks at, at [param t]: the latest thing begun that still holds it; with none, what it looked at last,
## until [constant HOME_AFTER] has gone by, then the whole desk.
func _attention(t: float) -> Dictionary:
	var best := {}
	var last_end := -INF
	var last := {}
	var linger := HOME_AFTER
	for e in _attn:
		var d: Dictionary = e
		if float(d["t0"]) > t:
			break
		if t < float(d["t1"]):
			best = d["spot"]
		elif float(d["t1"]) > last_end:
			last_end = float(d["t1"])
			last = d["spot"]
			linger = float(d.get("linger", HOME_AFTER))
	if not best.is_empty():
		return best
	if not last.is_empty() and t - last_end < linger:
		return last
	return _spot("home")


func _tick_camera(delta: float) -> void:
	var want := _attention(_now)
	var aim: Vector3 = want["aim"]
	var eye: Vector3 = want["eye"]
	var fov := float(want["fov"])
	var w := Vector3(sin(_now * WANDER_RATE * TAU + 1.3) * WANDER.x, sin(_now * WANDER_RATE * 0.77 * TAU) * WANDER.y,
		sin(_now * WANDER_RATE * 0.53 * TAU + 2.1) * WANDER.z)
	aim += w
	if _snap:
		_f_aim = aim
		_f_eye = eye
		_f_fov = fov
		_c_aim = aim
		_c_eye = eye
		_c_fov = fov
		_v_aim = Vector3.ZERO
		_v_eye = Vector3.ZERO
		_v_fov = 0.0
		_snap = false
	else:
		var dt := clampf(delta, 0.0, 0.1)
		var steps := maxi(1, ceili(dt / 0.02))
		var h := dt / float(steps)
		var lead := 1.0 - exp(-h / LEAD_TAU)
		for _s in steps:
			# the lead first, so the spring is pulled toward a target that moves off gently, never one that jumps
			_f_aim = _f_aim.lerp(aim, lead)
			_f_eye = _f_eye.lerp(eye, lead)
			_f_fov = lerpf(_f_fov, fov, lead)
			var k := h / (SPRING_TAU * SPRING_TAU)
			var c := 2.0 * h / SPRING_TAU
			_v_aim += (_f_aim - _c_aim) * k - _v_aim * c
			_c_aim += _v_aim * h
			_v_eye += (_f_eye - _c_eye) * k - _v_eye * c
			_c_eye += _v_eye * h
			_v_fov += (_f_fov - _c_fov) * k - _v_fov * c
			_c_fov += _v_fov * h
	_cam.fov = _c_fov
	_cam.look_at_from_position(_c_eye, _c_aim, Vector3.UP)


# --- the pictures over the whole screen ---------------------------------------------------------------------------------

## When a picture over the whole screen comes in: just after the word before its passage, and never before what the desk
## does ahead of it in that silence is done (the actions written before it, a block's typing among them): the picture
## comes where it is written. INF while one of those is not placed yet.
func _picture_in(sp: Dictionary) -> float:
	var from := int(sp["from"])
	var t := (_word_t1(from - 1) + 0.1) if from > 0 else _word_t0(from) - IMAGE_FADE
	for i in range(mini(int(sp.get("acts", 0)), _actions.size()) - 1, -1, -1):
		var a: Dictionary = _actions[i]
		if int(a["after"]) != from:
			break
		t = maxf(t, _t0[i] + float(a["rest"]) / _sp[i] + 0.1)
	return t


## The pictures up now over the desk: each faded in when it comes in ([method _picture_in]), dissolving into the next or out
## after its passage's last word, moving its own way ([constant LetterMedium.MOVES]).
func _show_pictures() -> void:
	var layers: Array = []
	var shown: Array = []
	for s in _spans:
		var sp: Dictionary = s
		if _pictures.has(String(sp["key"])) and int(sp["to"]) > int(sp["from"]):
			shown.append(sp)
	for i in shown.size():
		var sp: Dictionary = shown[i]
		var from := int(sp["from"])
		var to := int(sp["to"])
		var nxt: Dictionary = shown[i + 1] if i + 1 < shown.size() else {}
		var under := not nxt.is_empty() and bool(nxt.get("blend", false)) and int(nxt["from"]) == to
		var t0 := _picture_in(sp)
		var t1 := _picture_in(nxt) if under else _word_t1(to - 1) + 0.1
		if t0 == INF or _now < t0 or (t1 < INF and _now > t1 + IMAGE_FADE):
			continue
		var a := clampf((_now - t0) / IMAGE_FADE, 0.0, 1.0)
		if not under and t1 < INF:
			a = minf(a, 1.0 - clampf((_now - t1) / IMAGE_FADE, 0.0, 1.0))
		var u := clampf((_now - t0) / maxf(float(to - from) * DeskScript.SAID_WORD + IMAGE_FADE * 2.0, 1.0), 0.0, 1.0)
		var mv: Dictionary = sp.get("move", {"grow": Vector2(1.04, 1.16), "way": Vector2.RIGHT, "drift": 0.5})
		var grow: Vector2 = mv["grow"]
		var tex: Texture2D = _pictures[String(sp["key"])]
		layers.append({"tex": tex, "alpha": a * a * (3.0 - 2.0 * a), "grow": lerpf(grow.x, grow.y, u),
			"drift": (mv["way"] as Vector2) * lerpf(-float(mv["drift"]), float(mv["drift"]), u)})
	if layers != _plate.layers:
		_plate.layers = layers
		_plate.queue_redraw()


# --- for a gate --------------------------------------------------------------------------------------------------------

## Where phone [param label] IS at [param t] in its moves: "row", "ear", "desk" or "moving".
func phone_at(label: String, t: float) -> String:
	var mv := {}
	for m in _phone_moves:
		if String((m as Dictionary)["label"]) == label and float(m["t0"]) <= t:
			mv = m
	if mv.is_empty():
		return "row"
	return String(mv["to"]) if t >= float(mv["t0"]) + float(mv["dur"]) else "moving"


## What the camera turns to at [param t]: the key of [member DispatchSet.spots] its aim is, or "phone" for a phone's own.
func looking_at(t: float) -> String:
	var want := _attention(t)
	for k in _set.spots:
		if (_set.spots[k] as Dictionary)["aim"] == want["aim"]:
			return String(k)
	return "phone"


## Each action's placed start (INF until it is).
func starts() -> PackedFloat32Array:
	return _t0

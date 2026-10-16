extends Node2D
class_name Medium

## Medium - what the show is carried ON. The presentation axis.
##
## ghost has always had exactly one presentation and never had to name it: the
## [Director] paints ONE scene, full-bleed, edge to edge, and cuts to the next. A
## medium is that choice made addressable. [FullMedium] is that behavior,
## unchanged and default; [ComicMedium] renders the same scenes into the panels of
## an open comic book - two facing pages across a spine - and flies a real perspective
## camera over it.
##
## NOT A MODE, and the distinction is the whole point. A mode decides what DRIVES the
## show - a song (Auto), a storyboard (Manual), a written script (Synthesis /
## Generative). A medium decides what the show is PRESENTED AS. They are independent
## axes, so every mode gets every medium for free, exactly as every scene gets every
## behavior and every render kind. Putting the comic in as a fifth mode would have
## meant a comic that only works over a song, and a second copy of the Director's
## scheduling to drive it.
##
## THE CONTRACT is deliberately four small vetoes rather than a rendering interface,
## because the Director must not learn what a comic is:
##
##   host_for(incoming)   - the node an arriving scene is added to. `full` returns the
##                          stage; `comic` returns the next panel's SubViewport, having
##                          first FROZEN the one behind it.
##   style_for(style)     - veto on the transition style the Director chose.
##   hold_outgoing()      - true when the leaving scene must NOT fade out (its panel is
##                          already drawn and must stay drawn).
##   owns_bookend()       - true when the medium applies the whole-show fade itself,
##                          so the Director stops applying it to the scene.
##
## A medium is a Node2D mounted INSIDE the stage SubViewport, so the stage governor
## still owns it: when the governor stops the stage, it stops the medium and every
## panel viewport nested under it, together.

## THE REGISTRY: one row a medium, the one shape every registry here has (a `label` a person reads, a
## `blurb`, and the fields of its own kind - next/structure.md, step 6). Adding a presentation is a
## row here, never new control flow in the Director (see the four vetoes above) - the same rule
## [Layer] and [Primitives] follow. Keys are what `--medium NAME` and `[director] medium` in
## `user://ghost.cfg` take; the order is the picker's.
##
##   label   its name in the Picture card's picker
##   script  the medium's script, by path - a medium a feature brings lives with that feature (the
##           card table, in `table/`)
##   uses    WHICH OPTIONAL SETTINGS IT USES, as the panel's own group names. A medium decides what
##           the show is presented AS, so some of the Director's picture settings mean nothing to
##           some of them - the full-frame show has no camera to be severe with and no panels to
##           cut footage into. Reported as "there are a number of settings currently being
##           displayed that ONLY work with the comic book medium". Declared here rather than
##           branched on in the panel: a medium added later says what it uses and the panel
##           follows. A setting EVERY medium uses (scene hold, flourishes, the Look, the holds)
##           needs no tag.
##   frames  THE FRAMES IT CAN BE SHOWN IN (next/notes.md, "Two frames"): landscape 16:9 for every
##           one, portrait 9:16 only where it was measured to work. The full-frame show does -
##           scenes size everything off the frame's short side. The tablet needs its camera
##           distances fitted on both axes first; the comic, the book, the notebook and the card
##           table frame a spread or a table a 9:16 view cannot hold: design work of their own.
##   needs   optional: WHAT IT NEEDS FROM THE NOTE beyond a sound to cut on. The novel, the
##           notebook and the tablet print a READING - its words, timed by the voice - so a note
##           with only a song has nothing to put on their pages, and its Picture card does not
##           offer them.
##   mode    optional: THE MODE IT BELONGS TO, which shows its readings in it (the desk is Proof's). The card table is
##           drawn from an episode Cards produced - its deck, its pictures, its spread - so a
##           chapter read anywhere else has nothing to put on it. Such a medium is never offered
##           by a picker ([method pickable]) and never becomes the remembered setting; its mode
##           pins it for the session instead (see [member Director.medium_override]).
##   bare    optional: it TAKES NO SETTINGS - the Picture card shows nothing under the picker,
##           and picking it puts the Director's dials back to their defaults (see [AutoMedium]).
##   blurb   one line, for the picker's tooltip and docs/media.md - ONE string literal, not a `+`
##           continuation, so docs.py reads it whole
const REGISTRY := {
	"auto": {"label": "Auto", "script": "res://src/media/auto.gd",
		"uses": [], "frames": ["landscape"], "bare": true,
		"blurb": "The original show with nothing to set: scenes chosen by the song's own fingerprint and cut on its beat, at the default pacing - the same song is the same show in every note."},
	"full": {"label": "Full frame", "script": "res://src/media/full.gd",
		"uses": [], "frames": ["landscape", "portrait"],
		"blurb": "One scene at a time, filling the frame. The original show."},
	"comic": {"label": "Comic book", "script": "res://src/media/comic.gd",
		"uses": ["camera", "films"], "frames": ["landscape"],
		"blurb": "The same scenes drawn into the panels of an open comic book - two facing pages, flown over by a real perspective camera. Each cut fills the next panel; a full spread turns the leaf on its spine."},
	"book": {"label": "Novel", "script": "res://src/media/book.gd",
		"uses": ["camera", "illustrations"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "The chapter itself, typeset into the pages of an open novel on a desk, with each word lit as it is spoken and the leaf turning as the reading reaches the next spread. Pictures come from the chapter's image markers."},
	"notebook": {"label": "Notebook", "script": "res://src/media/notebook.gd",
		"uses": ["camera", "illustrations", "handwriting"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "The chapter handwritten into a ruled research notebook - margin times, underlined emphasis, photos paper-clipped over the writing at an angle, and sketches (`<!-- sketch: ... -->`) drawn onto the page in the same ink. For a chapter drafted as a journal or a lab report."},
	"tablet": {"label": "Tablet", "script": "res://src/media/tablet.gd",
		"uses": ["camera", "illustrations"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "Somebody browsing on a tablet lying on a desk: the chapter is web pages (`<!-- url: -->`), read aloud as they are scrolled, with searches, new tabs, a turn to landscape and links followed between them - every tap and keystroke timed into the rests the voice leaves for it."},
	"table": {"label": "Card table", "script": "res://src/table/table.gd",
		"uses": [], "frames": ["landscape"], "mode": "cards",
		"blurb": "A card reading at a table, seen from the reader's chair: the deck shuffles while the reader talks, each card is drawn, held up beside its booklet entry, read and laid into the spread. The Cards mode's own medium - its deck, pictures and spread come from the episode the agents produced."},
	"desk": {"label": "Desk", "script": "res://src/desk/desk.gd",
		"uses": [], "frames": ["landscape"], "mode": "proof",
		"blurb": "A ghost doing math at a desk: a legal pad under a lamp, and a pen that writes each formula on it by itself while the teacher talks, in a hand drawn from TeX's own layout. The Proof component's own medium - what it writes comes from the lesson its agents made."},
}


## Does [param key]'s medium take any settings? (A row's `bare`.)
static func takes_settings(key: String) -> bool:
	return not bool(Registry.field(REGISTRY, key, "bare", false))


## The media a picker offers a note that provides [param have] (a note with a song provides
## "audio"; a reading, "reading" too), in registry order - [method pickable] less what needs more.
static func offered(have: Array) -> Array:
	var out: Array = []
	for k in pickable():
		var ok := true
		for n in Registry.field(REGISTRY, k, "needs", []) as Array:
			if not have.has(n):
				ok = false
		if ok:
			out.append(k)
	return out


## The mode [param key]'s medium belongs to (a row's `mode`), or "" for one every note may pick.
static func mode_of(key: String) -> String:
	return String(Registry.field(REGISTRY, key, "mode", ""))


## The keys a picker offers, in registry order: every medium no mode owns.
static func pickable() -> Array:
	var out: Array = []
	for k in REGISTRY:
		if mode_of(k).is_empty():
			out.append(k)
	return out

## Does [param key]'s medium use the [param feature] group? Unknown media and unknown
## features answer TRUE, deliberately: the failure of a wrong answer here is a control the
## author cannot find, and showing a setting that does nothing is the lesser of the two.
static func uses(key: String, feature: String) -> bool:
	if not REGISTRY.has(key):
		return true
	return feature in (Registry.field(REGISTRY, key, "uses", []) as Array)


## Each frame's size at 1080p, in pixels.
const FRAME_SIZES := {"landscape": Vector2i(1920, 1080), "portrait": Vector2i(1080, 1920)}


## The frames [param key]'s presentation can be shown in.
static func frames(key: String) -> Array:
	return Registry.field(REGISTRY, key, "frames", ["landscape"])


## Can [param key]'s presentation be shown in [param frame]?
static func supports(key: String, frame: String) -> bool:
	return frames(key).has(frame)


## SHOW EACH ROW ONLY WHERE [param key]'s medium has its feature: [param rows] maps a `uses`
## tag to the controls that answer to it. Every card with such rows shows them by this one rule;
## the key is the caller's (`Director.resolved_medium()`), so this file names no autoload.
static func show_rows(rows: Dictionary, key: String) -> void:
	for tag in rows:
		var on := uses(key, String(tag))
		for row in rows[tag] as Array:
			if is_instance_valid(row):
				(row as Control).visible = on




## Build the medium for [param key], falling back to `full` for an unknown one (a
## stale config or a typo must never be able to stop a session starting).
static func make(key: String) -> Medium:
	var path := String(Registry.field(REGISTRY, key, "script", REGISTRY["full"]["script"]))
	if not REGISTRY.has(key):
		push_warning("ghost: unknown medium '%s' - falling back to full frame" % key)
	var v: Medium = load(path).new()
	v.key = key if REGISTRY.has(key) else "full"
	return v


## The registry key this instance was built from.
var key := "full"

## WHAT THIS MEDIUM READS OF THE SHOW ([ShowFeed]): the session's seed, the camera and the
## handwriting a person chose, the holds at each end, the fade, the hold left on the scene that is
## up, and one more scene when it asks. Handed by [method Director.attach]; the show that is up,
## for a medium nobody handed one (a gate that builds it by hand). A medium reads the show here
## and never by the Director's name - it is below the player (docs/structure.md).
var feed: ShowFeed = ShowFeed.playing()

## The stage this medium is mounted in - the SubViewport [main] composites. Set by
## [method mount] before the Director attaches.
var stage: SubViewport = null


## Mount on the stage. The base parents itself; a medium with its own furniture
## (panel viewports, a page) builds it here.
##
## SEED-INDEPENDENT WORK ONLY. Mounting happens while the stage is being created, which
## is BEFORE the Director has resolved the session seed - so anything sampled belongs in
## [method begin_session], not here. (It is the same ordering trap as reading the song
## fingerprint before the audio is loaded, and it fails silently: every session would
## roll the identical "random" page.)
func mount(st: SubViewport) -> void:
	stage = st
	st.add_child(self)


## A session is starting and [method Director.session_seed] is now valid. Roll everything
## sampled here. Called by [method Director.attach], and again for every take in the
## synthesis modes, which re-attach per take.
func begin_session() -> void:
	pass


## The node an ARRIVING scene should be added to. Called by the [Director] at every
## point it would have written `_host.add_child(...)`, and it is the hook a medium
## with more than one surface hangs everything off: `comic` uses the call itself as
## the signal to freeze the panel behind and open the next one.
func host_for(_incoming: GhostScene) -> Node:
	return stage


## Veto on the transition style (a [enum Director.Style] value). Return it unchanged
## to accept the Director's choice.
func style_for(style: int) -> int:
	return style


## True when the OUTGOING scene must be held at full opacity through a transition
## instead of fading out. A comic panel that is already on the paper cannot un-draw
## itself; the full frame has no such constraint.
func hold_outgoing() -> bool:
	return false


## True when this medium applies the whole-show bookend fade itself. The [Director]
## then stops folding it into the scene's alpha, because on a comic page that would
## fade one panel and leave the paper lit.
func owns_bookend() -> bool:
	return false


## True when this medium makes and owns the scenes itself, rather than showing the one
## the [Director] makes per cut.
##
## The full frame shows ONE scene, so "the scene" and "the show" are the same object and
## the Director can own it. A comic page has several on it AT ONCE - that is what makes it
## a page rather than a slideshow - so the page owns its cast and the Director's cut means
## "move the reading to the next panel" instead of "build a new scene". A medium that
## says true here must answer [method take_over], and the Director then never creates,
## parents or frees a scene on its own.
func owns_cast() -> bool:
	return false


## The scene the show is now ON, for a medium that owns its cast. Returning non-null
## means: this scene is ALREADY BUILT AND PARENTED, adopt it as current, and leave
## [param outgoing] alone - it is still on the page and must not be freed. [param outgoing]
## is null on the first call of a session.
##
## Returning null keeps the Director's own behavior, so a medium can decline a
## particular change without giving up ownership.
func take_over(_outgoing: GhostScene) -> GhostScene:
	return null


## The session's words and their clock, handed over when the karaoke overlay is made.
## Return TRUE when this medium shows the words itself, and main hides the overlay - a page
## that prints the text under a subtitle of the same text would say every sentence twice.
func bind_captions(_subs) -> bool:
	return false


## Per-frame, after the Director has advanced the schedule. [param features] is the
## live [AudioFeatures]; [param bookend] is the whole-show fade, 1 except at the ends.
func advance(_features, _delta: float, _bookend: float) -> void:
	pass


## The stage changed size (a window resize, or the export's fixed render size being
## applied). A medium that sizes its own render targets off the stage re-sizes them here.
func on_stage_resized(_size: Vector2) -> void:
	pass


## Session teardown (the Director detached). Release anything held.
func release() -> void:
	pass

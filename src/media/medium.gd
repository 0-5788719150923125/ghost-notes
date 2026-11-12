extends Node2D
class_name Medium

## Medium - what the show is carried on: the presentation axis.
##
## The [Director] paints one scene full-bleed and cuts to the next; a medium makes that choice
## addressable. [FullMedium] is that behavior and the default; [ComicMedium] renders the same scenes
## into the panels of an open comic book and flies a real perspective camera over it.
##
## A medium is not a mode: a mode decides what drives the show (a song, a storyboard, a written
## script), a medium decides what it is presented as. They are independent axes, so every mode gets
## every medium.
##
## The contract is four small vetoes rather than a rendering interface, so the Director never learns
## what a comic is:
##
##   host_for(incoming)   - the node an arriving scene is added to. `full` returns the stage;
##                          `comic` returns the next panel's SubViewport, having frozen the one behind.
##   style_for(style)     - veto on the transition style the Director chose.
##   hold_outgoing()      - true when the leaving scene must not fade out (its panel stays drawn).
##   owns_bookend()       - true when the medium applies the whole-show fade itself.
##
## A medium is a Node2D mounted inside the stage SubViewport, so the stage governor stops the medium
## and every panel viewport under it together.

## The registry: one row a medium (a `label`, a `blurb`, and the fields of its own kind -
## next/structure.md). Adding a presentation is a row here, never new control flow in the Director.
## Keys are what `--medium NAME`, `[director] medium` in `user://ghost.cfg` and a note's
## `medium: format:` take; the order is the Format picker's.
##
## Every row without a `mode` is a format of the Medium card ([MediumCard]): its shared rows are
## shown by `uses` and its own by `card`.
##
##   label   its name in the Format picker
##   script  the medium's script, by path (a medium a feature brings lives with that feature)
##   uses    which optional settings it uses, as the Medium card's group names; a setting a medium
##           has no use for is hidden (declared here, not branched on in the panel). `scenes`: it cuts
##           the Director's scenes, so Scene hold and Flourishes mean something. `camera`, `films`,
##           `illustrations` (the note's Pictures card stands), `handwriting` (the shared hand row),
##           `ink` (a voice's pen color, on the Voice card). `opening`: it draws an opening of its own
##           through the intro hold ([Openings], [ShowOpening]) and the Intro & outro card offers one.
##   frames  the frames it can be shown in (next/notes.md, "Two frames"): landscape 16:9 for every
##           one, portrait 9:16 only where it was measured to work.
##   needs   optional: what it needs from the note beyond a sound to cut on. Formats that show a
##           reading (its words, timed by the voice) are not offered for a note with only a song.
##   card    optional: the format's own rows, by path - a script answering `for_note(ctx)`,
##           `capture()` and `apply(block)`, built into the Medium card under the shared rows. What it
##           keeps is part of the Medium's one block; what it hands the reading (its `walk`,
##           `publish`) is why a change to or from such a format opens the note again.
##   capabilities  optional: what the format asks of the platform ([Capabilities]); a format
##           impossible here is grayed in the picker, saying why.
##   intro_tip, outro_tip  optional: what the Intro & outro card's holds say under this format.
##   mode    optional: the component it belongs to, which shows its readings in it (the card table is
##           Table's, drawn from an episode Table produced). Never offered by a picker
##           ([method pickable]) nor remembered as the setting; its component pins it for the session
##           (see [member Director.medium_override]).
##   bare    optional: it takes no settings - the Medium card shows nothing under the picker and picking
##           it resets the Director's dials to their defaults (see [AutoMedium]).
##   blurb   one line, for the picker's tooltip and docs/media.md - one string literal, not a `+`
##           continuation, so docs.py reads it whole
const REGISTRY := {
	"auto": {"label": "Auto", "script": "res://src/media/auto.gd",
		"uses": [], "frames": ["landscape"], "bare": true,
		"blurb": "The original show with nothing to set: scenes chosen by the song's own fingerprint and cut on its beat, at the default pacing - the same song is the same show in every note."},
	"full": {"label": "Full frame", "script": "res://src/media/full.gd",
		"uses": ["scenes"], "frames": ["landscape", "portrait"],
		"blurb": "One scene at a time, filling the frame. The original show."},
	"comic": {"label": "Comic book", "script": "res://src/media/comic.gd",
		"uses": ["scenes", "camera", "films"], "frames": ["landscape"],
		"blurb": "The same scenes drawn into the panels of an open comic book - two facing pages, flown over by a real perspective camera. Each cut fills the next panel; a full spread turns the leaf on its spine."},
	"book": {"label": "Novel", "script": "res://src/media/book.gd",
		"uses": ["camera", "illustrations"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "The chapter itself, typeset into the pages of an open novel on a desk, with each word lit as it is spoken and the leaf turning as the reading reaches the next spread. Pictures come from the chapter's image markers."},
	"notebook": {"label": "Notebook", "script": "res://src/media/notebook.gd",
		"uses": ["camera", "illustrations", "handwriting", "ink"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "The chapter handwritten into a ruled research notebook - margin times, underlined emphasis, photos paper-clipped over the writing at an angle, and sketches (`<!-- sketch: ... -->`) drawn onto the page in the same ink. For a chapter drafted as a journal or a lab report."},
	"tablet": {"label": "Tablet", "script": "res://src/media/tablet.gd",
		"uses": ["camera", "illustrations"], "frames": ["landscape"], "needs": ["reading"],
		"blurb": "Somebody browsing on a tablet lying on a desk: the chapter is web pages (`<!-- url: -->`), read aloud as they are scrolled, with searches, new tabs, a turn to landscape and links followed between them - every tap and keystroke timed into the rests the voice leaves for it."},
	"letter": {"label": "Letter", "script": "res://src/desk/letter.gd",
		"uses": ["opening", "illustrations", "handwriting"], "frames": ["landscape"], "needs": ["reading"],
		"card": "res://src/letter/letter_format.gd",
		"capabilities": ["subprocess", "agent:writer", "tex", "python:math"],
		"intro_tip": "Seconds the desk holds before the letter is begun, its title over it.",
		"outro_tip": "Seconds held after the pen's last stroke, the page on the desk, fading picture and sound out together.",
		"blurb": "Somebody writing a letter at a desk, reading it aloud as the pen puts it down in a cursive hand: a thought said and not written, a line crossed out, a sketch drawn as it is described, the pen tapped while the writer thinks or pointed at whoever watches, and a picture over the whole screen for a passage read over it."},
	"dispatch": {"label": "Dispatch desk", "script": "res://src/dispatch/dispatch.gd",
		"uses": ["opening", "illustrations"], "frames": ["landscape"], "needs": ["reading"],
		"card": "res://src/dispatch/dispatch_format.gd",
		"intro_tip": "Seconds the desk holds, its title over it; then the desk at rest, a few seconds more, before the first word.",
		"outro_tip": "Seconds held after the last word, the desk in the dark, fading picture and sound out together.",
		"blurb": "One desk late at night in a hollow under the ground, seen from the chair: an old terminal that types what is said, a dozen labeled flip phones that ring and are held to the ear (every voice but the room's heard through one), a radar, a shortwave receiver, a printer, small screens - the camera turning to whatever is active, roots growing across the desk."},
	"table": {"label": "Card table", "script": "res://src/table/table.gd",
		"uses": ["opening"], "frames": ["landscape"], "mode": "table",
		"blurb": "A card reading at a table, seen from the reader's chair: the deck shuffles while the reader talks, each card is drawn, held up beside its booklet entry, read and laid into the spread. The Table mode's own medium - its deck, pictures and spread come from the episode the agents produced."},
	"likeness": {"label": "Likeness", "script": "res://src/likeness/likeness.gd",
		"uses": [], "frames": ["landscape"], "needs": ["reading"], "mode": "likeness",
		"blurb": "An actor reading the note in their own room, from their own footage: their real takes, joined where two frames nearly match, the mouth drawn from their own mouths to the voice's sounds through one mesh over the frame, their gestures on the words a director placed them. The Likeness component's own medium."},
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

## Does [param key]'s medium use the [param feature] group? Unknown media and features answer true:
## a setting that does nothing is the lesser failure than a control the author cannot find.
static func uses(key: String, feature: String) -> bool:
	if not REGISTRY.has(key):
		return true
	return feature in (Registry.field(REGISTRY, key, "uses", []) as Array)


## What a medium shows as pictures, for the one Pictures card every presentation shares: [param body]'s
## pictures as [param key]'s medium shows them ([Manuscript.images] rows, a captured page's with its
## `url`) - asked of its script's static `pictures_in(body)` where it has one (a letter's sketches are
## drawn by its pen, a tablet's pages are captured, a dispatch desk shows each on a screen), else every
## image mark. [] for a medium that shows none (no "illustrations" in its `uses`).
static func pictures_of(key: String, body: String) -> Array:
	if not uses(key, "illustrations"):
		return []
	var own := _pictures_script(key)
	if own != null:
		return own.call("pictures_in", body) as Array
	return Manuscript.images(body)


## Each medium's script, where it says for itself what it shows as pictures (null where it does not), found once.
static var _pictures_scripts := {}

static func _pictures_script(key: String) -> GDScript:
	if _pictures_scripts.has(key):
		return _pictures_scripts[key]
	var own: GDScript = null
	var path := String(Registry.field(REGISTRY, key, "script", ""))
	var script: GDScript = load(path) as GDScript if not path.is_empty() else null
	if script != null:
		for m in script.get_script_method_list():
			if String((m as Dictionary)["name"]) == "pictures_in":
				own = script
	_pictures_scripts[key] = own
	return own


## Each frame's size at 1080p, in pixels.
const FRAME_SIZES := {"landscape": Vector2i(1920, 1080), "portrait": Vector2i(1080, 1920)}


## The frames [param key]'s presentation can be shown in.
static func frames(key: String) -> Array:
	return Registry.field(REGISTRY, key, "frames", ["landscape"])


## Can [param key]'s presentation be shown in [param frame]?
static func supports(key: String, frame: String) -> bool:
	return frames(key).has(frame)


## Show each row only where [param key]'s medium has its feature: [param rows] maps a `uses` tag to
## the controls that answer to it. The key is the caller's (`Director.resolved_medium()`), so this
## file names no autoload.
static func show_rows(rows: Dictionary, key: String) -> void:
	for tag in rows:
		var on := uses(key, String(tag))
		for row in rows[tag] as Array:
			if is_instance_valid(row):
				(row as Control).visible = on




## Build the medium for [param key], falling back to `full` for an unknown one.
static func make(key: String) -> Medium:
	var path := String(Registry.field(REGISTRY, key, "script", REGISTRY["full"]["script"]))
	if not REGISTRY.has(key):
		push_warning("ghost: unknown medium '%s' - falling back to full frame" % key)
	var v: Medium = load(path).new()
	v.key = key if REGISTRY.has(key) else "full"
	return v


## The registry key this instance was built from.
var key := "full"

## What this medium reads of the show ([ShowFeed]): the session's seed, the camera and handwriting a
## person chose, the holds at each end, the fade, and the hold left on the scene that is up. Handed by
## [method Director.attach]; the live show for a medium nobody handed one (a gate). A medium reads the
## show here, never by the Director's name (it is below the player: docs/structure.md).
var feed: ShowFeed = ShowFeed.playing()

## The stage this medium is mounted in - the SubViewport [main] composites. Set by
## [method mount] before the Director attaches.
var stage: SubViewport = null


## Mount on the stage. The base parents itself; a medium with its own furniture (panel viewports, a
## page) builds it here.
##
## Seed-independent work only: mounting happens before the Director has resolved the session seed, so
## anything sampled belongs in [method begin_session].
func mount(st: SubViewport) -> void:
	stage = st
	st.add_child(self)


## A session is starting and [method Director.session_seed] is valid: roll everything sampled here.
## Called by [method Director.attach], and again for every take in the synthesis modes.
func begin_session() -> void:
	pass


## The node an arriving scene should be added to. Called by the [Director] wherever it would add a
## scene to the host; `comic` uses the call itself as the signal to freeze the panel behind and open
## the next one.
func host_for(_incoming: GhostScene) -> Node:
	return stage


## Veto on the transition style (a [enum Director.Style] value). Return it unchanged to accept.
func style_for(style: int) -> int:
	return style


## True when the outgoing scene must be held at full opacity through a transition instead of fading
## out (a comic panel already on the paper cannot un-draw itself).
func hold_outgoing() -> bool:
	return false


## True when this medium applies the whole-show bookend fade itself, so the [Director] stops folding
## it into the scene's alpha (on a comic page that would fade one panel and leave the paper lit).
func owns_bookend() -> bool:
	return false


## True when this medium makes and owns the scenes itself rather than showing the one the [Director]
## makes per cut: a comic page has several scenes on it at once, so a cut means "move the reading to
## the next panel". A medium that says true must answer [method take_over]; the Director then never
## creates, parents or frees a scene on its own.
func owns_cast() -> bool:
	return false


## The scene the show is now on, for a medium that owns its cast. Non-null means the scene is already
## built and parented: adopt it as current and leave [param outgoing] alone (it is still on the page
## and must not be freed; null on the first call of a session). Null keeps the Director's own
## behavior, so a medium can decline a particular change.
func take_over(_outgoing: GhostScene) -> GhostScene:
	return null


## The session's words and their clock, handed over when the karaoke overlay is made. Return true when
## this medium shows the words itself, and main hides the overlay.
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

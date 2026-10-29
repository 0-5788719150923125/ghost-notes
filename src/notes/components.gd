extends RefCounted
class_name Components

## Components - the parts a note is made of (next/notes.md, "A component"). One registry shaped
## like [Medium]'s: each entry says what the component is, what it needs and what it gives, the
## components it brings with it, the room it takes in a note, what it asks of the platform
## ([Capabilities]), which groups of the script's marks it brings, the frontmatter block it keeps,
## and the card it is set on.
##
## A NOTE IS WHAT ITS COMPONENTS MAKE IT. There is one kind of new note - its words and nothing
## else - and "+" attaches the rest ([method attach_menu]); what a note can do, which panel runs it
## ([method workspace_of]) and what it may take next are read off what is attached, never off a
## list of kinds of note. A song and a Picture is a seeded show; add a Storyboard and it is a show
## written by hand; a Voice reads the words, and Cards has agents write them.
##
## NEEDS AND PROVIDES ARE TYPED NAMES that ghost matches, the way a scene's `morph_out` and
## `morph_in` already are: "text", "audio", "reading", "picture", "moments". A component never
## names another to work - only what it needs - so a need nobody provides is a sentence on a card,
## never a branch somewhere else.
##
## SLOTS SAY HOW MANY ([constant SLOTS]): components that name the same slot are alternatives, and
## a note has one of them. A show has one clock and one presentation, so a song and a voice are
## not attached together - "+" grays the second, and says which to detach.
##
## THE STAGE IS A CAPABILITY: anything shown on it asks for `forward_plus`, the desktop renderer, so
## on a phone - where a note is its text and nothing more - every component but the text is
## impossible and "+" offers nothing ([method attach_menu]).
##
## A PART THAT COMES WITH ANOTHER IS A ROW'S `comes_with` (optional): it is never attached by itself
## and brings nothing, its block is kept by whichever of those components the note has ([method
## blocks_of]) - a book's pictures' look, with a Picture or a Letter - and a note carrying its block
## with none of them has the first ([method attached_of]). As `requires`, the Picture had come with
## it, and a letter's look would have brought a Picture into the letter.
##
## A CARD ANY PANEL CAN SHOW IS A ROW'S `script`: the path of the script that builds the
## component's card, loaded when a panel builds it ([method NoteCards.make]). By path because this
## registry is under every card (docs/structure.md): a row is how it names one. The script answers
## `KEY` (its block), `for_note(ctx)`, `capture()` and `apply(block)`; `tests/notes/components_check.gd`
## loads each and holds it to that.
##
## Static and free of autoload names, like [Capabilities], so a gate can read it under `--script`.

## THE FAMILIES: a label and a hue in degrees - the color a component's card, chip and marks are
## drawn in ([Card]); "paper", the note's own text, has none. Color is per family, not per component
## (Scratch's categories, Blender's sockets, TouchDesigner's operator families), because hues run out
## near eight. The order is the order cards stand in on a panel - read top to bottom, it says what
## happens to the note: the text, what produces a reading, the voice, sound, pictures, the
## presentation, the Look, and where the finished video goes.
const FAMILIES := {
	&"paper": {"label": "Text", "hue": -1.0},
	&"producer": {"label": "Producer", "hue": 275.0},
	&"voice": {"label": "Voice", "hue": 172.0},
	&"sound": {"label": "Sound", "hue": 212.0},
	&"picture": {"label": "Picture", "hue": 32.0},
	&"medium": {"label": "Presentation", "hue": 128.0},
	&"look": {"label": "Look", "hue": 322.0},
	&"publish": {"label": "Publish", "hue": 2.0},
}

## THE SLOTS: where a note has room for exactly one. `label` reads in a sentence ("this note's
## clock is its Song").
const SLOTS := {
	"clock": {"label": "clock",
		"blurb": "What the show is timed by, and how long it is: a song, a voice reading the text, or a clip."},
	"presentation": {"label": "presentation",
		"blurb": "What the show is seen in: the Picture and the medium it names, a card table, a voice lab's own show, or a clip's own frame."},
}

## THE WORKSPACES: the panels that run a note. Most components are a card on whichever panel is
## up; a few are an editor of their own, and name the workspace that is ([method workspace_of]).
## `section` is the panel's [Settings] section, and `mode` the name its Script card works in - the rows
## it shows, what its words are called and the marks it offers ([ScriptWriter], [ScriptMarks] `modes`) -
## the section's where the row names none ([method script_mode]). The two were one name until Cards
## became Table (2026-10-26): the table's settings kept their section, and its Script card, built in the
## section, showed no Byline, no brief's marks and no "Brief" (2026-10-29: "It's not displayed in the UI
## anywhere").
## The two a [ReadingPanel] runs say the rest of that panel too, so nothing extends it: `title` and
## `hint` (its heading and the line under it), `hosts` (which of a note's component cards it can
## show - a card table is its own presentation, so it shows no Picture) and `classic` (what a panel
## started without a note - the command line, a gate - is made of).
const WORKSPACES := {
	"note": {"label": "Note", "section": "note",
		"blurb": "The note's own panel: its words, and a card for each thing attached."},
	"reading": {"label": "Reading", "section": "generative",
		"blurb": "A voice reads the note: the cast, each speaker's delivery and room, the stream.",
		"title": "Generative",
		"hint": "Write or open a chapter. It is spoken in chunks, so the show starts while the rest is still being made. Edit lists every mark the reading understands - speakers, hesitations, pictures, pronunciations.",
		"hosts": ["voice", "voice_training", "picture", "letter", "actor", "storyboard", "look", "bookends"],
		"classic": ["text", "voice", "picture", "illustrations", "look", "bookends"]},
	# (its settings keep the section they had as Cards: renamed, the workspace would forget them)
	"table": {"label": "Table", "section": "cards", "mode": "table",
		"blurb": "A show at a table: the episodes agents make from the note's brief - cards drawn, things made, or both - and the voice that reads them.",
		"title": "Table",
		"hint": "Open a show: its body is the brief every agent works from. Each seed is one episode - planned, shuffled, painted and written one card (or one beat of work) at a time by the agents, then read here in the voice below, at the table.",
		"hosts": ["table", "voice", "voice_training", "look", "bookends"],
		"classic": ["text", "table", "voice", "look", "bookends"]},
	"proof": {"label": "Proof", "section": "proof",
		"blurb": "A ghost doing math at a desk: the episodes agents make from the note's problem, and the voice that teaches them.",
		"title": "Proof",
		"hint": "The note's words are the problem: write one, or press Invent a problem. Make episode has the agents fix it, solve it at the desk and check the proof in Lean, then write the lesson the voice below reads while the pen writes it on the pad.",
		"hosts": ["proof", "voice", "voice_training", "look", "bookends"],
		"classic": ["text", "proof", "voice", "look", "bookends"]},
	"lab": {"label": "Voice lab", "section": "synth", "mode": "synthesis",
		"blurb": "Ghost Notes' own synthesizer and the fishing game that breeds its voices."},
	"clip": {"label": "Masking", "section": "",
		"blurb": "A clip's editor: its markers, tracks, effects and timeline."},
}

const REGISTRY := {
	"text": {"label": "Text", "family": &"paper",
		"blurb": "The note's own words: what a voice reads, the brief an agent works from, or just a note.",
		"needs": [], "provides": ["text"], "requires": [], "slots": [], "workspace": "", "capabilities": [],
		"marks": [], "block": "", "card": "script"},
	"song": {"label": "Song", "family": &"sound",
		"blurb": "A song the show is cut on: its beat and its spectrum drive the scenes.",
		"needs": [], "provides": ["audio"], "requires": [], "slots": ["clock"], "workspace": "", "capabilities": ["stage"],
		"marks": [], "block": "song", "card": "song"},
	"scenes": {"label": "Scenes", "family": &"picture",
		"blurb": "The visualizer scenes, chosen by the seed and cut on the sound.",
		"needs": ["audio"], "provides": ["picture", "moments"], "requires": [], "slots": [], "workspace": "",
		"capabilities": ["forward_plus"], "marks": [], "block": "", "card": ""},
	"storyboard": {"label": "Storyboard", "family": &"picture",
		"blurb": "The show written down: which scenes play, in what order, how long each stays and how it leaves - and, on a stage, who is there and what they do. Nothing written, and the seed chooses.",
		"needs": ["audio", "places"], "provides": ["picture"], "requires": ["scenes"], "slots": [], "workspace": "",
		"capabilities": ["forward_plus"], "marks": [], "block": "scenes", "card": "scenes",
		"script": "res://src/timeline/storyboard_card.gd"},
	"voice": {"label": "Voice", "family": &"voice",
		"blurb": "A small local neural voice reads the text: a cast of speakers, their delivery and their room.",
		"needs": ["text"], "provides": ["audio", "reading", "moments"], "requires": [], "slots": ["clock"], "workspace": "reading",
		"capabilities": ["stage", "subprocess", "python:voice"], "marks": ["voices", "timing", "pronunciation"],
		"block": "voice", "card": "voice", "script": "res://src/reading/voice_card.gd"},
	# SOMEONE'S OWN VOICE (2026-10-26, next/likeness.md "A voice alone"): its card teaches a voice to speak as a
	# person does, from their recordings - a folder, files, or links fetched as their sound - and the note reads in
	# it. The Actor card's voice steps, without their picture; it brings a Voice.
	"voice_training": {"label": "Voice training", "family": &"voice",
		"blurb": "Teaches a voice to speak as someone does, from their own recordings - a folder, files, or links to videos, playlists or a channel: their speech heard, cut into clean sentences, and a voice fine-tuned on them on the graphics card. The note reads in it, and every Voice card can pick it.",
		"needs": ["reading"], "provides": [], "requires": ["voice"], "slots": [], "workspace": "",
		"capabilities": ["subprocess", "ffmpeg", "python:voice", "python:speech", "python:download", "python:voice_train"],
		"marks": [], "block": "voice_training", "card": "voice_training",
		"script": "res://src/likeness/voice_training_card.gd"},
	"voice_lab": {"label": "Voice lab", "family": &"voice",
		"blurb": "Ghost Notes' own synthesizer reads the text, and the fishing game breeds its voices.",
		"needs": ["text"], "provides": ["audio", "reading", "moments"], "requires": ["scenes"],
		"slots": ["clock", "presentation"], "workspace": "lab",
		"capabilities": ["stage"], "marks": ["voices", "timing"], "block": "synthesis", "card": "water"},
	"picture": {"label": "Picture", "family": &"picture",
		"blurb": "A show for the note, and what it is carried on: Auto (the seeded show, nothing to set), full frame, a comic, a book, a notebook, a tablet.",
		"needs": ["picture"], "provides": ["places"], "requires": ["scenes"], "slots": ["presentation"], "workspace": "",
		"capabilities": ["forward_plus"], "marks": ["typography", "tablet"], "block": "picture", "card": "picture",
		"script": "res://src/show/picture_card.gd"},
	"illustrations": {"label": "Illustrations", "family": &"picture",
		"blurb": "The book's pictures, painted by an agent from the marks in the text, or imported.",
		"needs": ["text", "places"], "provides": ["picture"], "requires": [], "comes_with": ["picture", "letter"],
		"slots": [], "workspace": "",
		"capabilities": ["forward_plus"], "marks": ["pictures"], "block": "illustrations", "card": "picture"},
	"look": {"label": "Look", "family": &"look",
		"blurb": "A post-process over the whole picture: grain, noir, a vignette, and the rest.",
		"needs": ["picture"], "provides": [], "requires": [], "slots": [], "workspace": "",
		"capabilities": ["forward_plus"], "marks": [], "block": "look", "card": "look",
		"script": "res://src/show/look_card.gd"},
	"bookends": {"label": "Intro & outro", "family": &"paper",
		"blurb": "Seconds held before the first word and after the last.",
		"needs": ["audio"], "provides": [], "requires": [], "slots": [], "workspace": "",
		"capabilities": ["forward_plus"], "marks": [], "block": "bookends", "card": "bookends",
		"script": "res://src/show/bookends_card.gd"},
	# ITS CARD IS THE EPISODE: the show's knobs, its agents and every step they make. It hands the
	# reading what is read (the episode's script), where it is heard (the table's sound) and how it
	# goes out (the episode's title and upload notes). `heading` is the card's title where it is
	# not the label; the tips are what the bookends hold at a card table.
	"table": {"label": "Table", "family": &"producer",
		"blurb": "Agents plan, paint and write a show at a table, a beat at a time: cards drawn and read, things made - or both. The note's words are the show's brief: they say what is done there.",
		"needs": ["text"], "provides": ["text", "picture", "moments"], "requires": ["voice"],
		"slots": ["presentation"], "workspace": "table", "starter": "res://rules/table/starter.md",
		"capabilities": ["forward_plus", "subprocess", "agent:writer", "agent:painter"], "marks": [],
		"block": "table", "card": "episode", "heading": "Episode",
		"script": "res://src/table_show/episode_card.gd",
		"intro_tip": "Seconds the table holds before the reader speaks, with the channel's name and the episode's title over it. The deck starts shuffling a beat before the first word.",
		"outro_tip": "Seconds held after the last word, the spread on the table and the channel's name over it, fading picture and sound out together."},
	# A GHOST DOING MATH AT A DESK (next/proof.md, 2026-10-15): its card is the episode - the problem
	# fixed, solved at the desk with Lean, taught - and it hands the reading the lesson to read and the
	# desk's document. It brings a Voice, as Cards does, and its own medium (the desk).
	"proof": {"label": "Proof", "family": &"producer",
		"blurb": "Agents work a math problem at a desk - the note's words are the problem - check the proof in Lean, and teach it: a pen writes each formula on a pad while the voice explains.",
		"needs": ["text"], "provides": ["text", "picture", "moments"], "requires": ["voice"],
		"slots": ["presentation"], "workspace": "proof",
		"capabilities": ["forward_plus", "subprocess", "agent:writer", "tex", "lean", "python:math"], "marks": [],
		"block": "proof", "card": "proof", "heading": "Proof",
		"script": "res://src/proof/proof_card.gd",
		"intro_tip": "Seconds the desk holds before the teacher speaks.",
		"outro_tip": "Seconds held after the last word, the page on the desk, fading picture and sound out together."},
	# A LETTER WRITTEN AT A DESK (next/letter.md, 2026-10-26): the note's words are the letter, written by
	# hand while the voice reads them; its card draws the sketches and paints the pictures its marks
	# describe, and pins its medium. It brings a Voice.
	"letter": {"label": "Letter", "family": &"picture",
		"blurb": "The note read as a letter written by hand at a desk: the pen writes each paragraph as the voice reads it, crosses lines out, draws the sketches the letter describes, taps while the writer thinks, and a picture takes the screen for a passage read over it.",
		"needs": ["reading"], "provides": ["picture"], "requires": ["voice"],
		"slots": ["presentation"], "workspace": "",
		"capabilities": ["forward_plus", "subprocess", "agent:writer", "tex", "python:math"], "marks": ["letter"],
		"block": "letter", "card": "letter", "script": "res://src/letter/letter_card.gd",
		"intro_tip": "Seconds the desk holds before the letter is begun, its title over it.",
		"outro_tip": "Seconds held after the pen's last stroke, the page on the desk, fading picture and sound out together."},
	# AN ACTOR READS THE NOTE (next/likeness.md): its card builds them from their own videos - the footage
	# surveyed and cut into sets, a still of the set in use, a model of them and their voice from every
	# video - and puts them on the stage, the still moved by their own motion, the mouth and eyes drawn
	# from their own as the voice's phones say. It brings a Voice. One component since 2026-10-22 (an
	# Actor that built and a Likeness that played, until the user: "If we're doing all that pipeline work
	# with Actor... then the implication is we want to use that actor in the scene").
	"actor": {"label": "Actor", "family": &"picture",
		"blurb": "An actor reads the note in their own room, built from their own videos - a folder, or links to videos, playlists or a channel: the footage surveyed and grouped by camera and look, a still of them chosen, and their motion, blinks, mouths and voice learned from every video. Every pixel of them is their own.",
		"needs": ["reading"], "provides": ["picture"], "requires": ["voice"],
		"slots": ["presentation"], "workspace": "",
		"capabilities": ["forward_plus", "subprocess", "ffmpeg", "python:face", "python:speech", "python:download", "agent:writer"], "marks": [],
		"block": "actor", "card": "actor", "script": "res://src/likeness/actor_card.gd",
		"intro_tip": "Seconds the actor fades up from black, sitting, before starting to read.",
		"outro_tip": "Seconds held after the last word, fading picture and sound out together."},
	"clip": {"label": "Clip", "family": &"picture",
		"blurb": "A video, cut and prepared from a file or a link, with chroma-key effects over it: markers, tracks and renders.",
		"needs": [], "provides": ["picture", "audio"], "requires": [], "slots": ["clock", "presentation"], "workspace": "clip",
		"capabilities": ["forward_plus", "subprocess", "ffmpeg"], "marks": [], "block": "clip", "card": "clip"},
	"masks": {"label": "Masks", "family": &"look",
		"blurb": "Chroma-key effects over a clip: markers, tracks and renders.",
		"needs": ["picture"], "provides": [], "requires": ["clip"], "slots": [], "workspace": "",
		"capabilities": ["forward_plus", "subprocess", "ffmpeg"], "marks": [], "block": "", "card": ""},
	# AN EXPORT'S DESTINATION (2026-10-07): it needs what a video is made of, and the exporter that
	# makes one - Masking's own export is a relaunch of its editor, so its panel offers no "+".
	"youtube": {"label": "YouTube", "family": &"publish",
		"blurb": "Uploads the exported video to your YouTube channel: its title, who may see it and the playlist it joins.",
		"needs": ["picture", "audio"], "provides": [], "requires": [], "slots": [], "workspace": "",
		"capabilities": ["movie_export", "subprocess", "ffmpeg"], "marks": [], "block": "youtube", "card": "youtube",
		"script": "res://src/export/youtube_card.gd"},
}


## THE MODE THE SCRIPT CARD OF WORKSPACE [param key] WORKS IN: its row's `mode`, else its section.
static func script_mode(key: String) -> String:
	return String(Registry.field(WORKSPACES, key, "mode", Registry.field(WORKSPACES, key, "section", "generative")))


## WHICH WORKSPACE RUNS A NOTE with [param attached]: the one its components name - a voice's, a
## voice lab's, a clip's, a show of cards' - or the note's own panel when none does. Where two name
## one, a component another BRINGS gives way to the one that brings it: Cards brings a Voice, so a
## show of cards is run by Cards' workspace, not the reading's.
static func workspace_of(attached: Array) -> String:
	var named: Array = []
	for k in with_required(attached):
		if not String((REGISTRY[k] as Dictionary)["workspace"]).is_empty():
			named.append(k)
	for k in named:
		var brought := false
		for other in named:
			if other != k and with_required([other]).has(k):
				brought = true
		if not brought:
			return String((REGISTRY[k] as Dictionary)["workspace"])
	return "note"


## The blocks attaching the component [param key] to a note adds: its own marker (`voice:` for a
## Voice), or {} for one that is not attached by itself - it comes with another (the scenes with a
## Picture, a clip's masks) or is the note (its text). A block is only what says the component is
## there: every setting is written by its card the first time it changes, because an empty block is
## not "the defaults" to every card (an empty `illustrations:` wipes the pictures' look).
static func attach_blocks(key: String) -> Dictionary:
	match key:
		"voice":
			return {"voice": {}}
		"voice_lab":
			return {"synthesis": {}}
		"table":
			return {"table": {}}
		"proof":
			return {"proof": {}}
		"actor":
			return {"actor": {}}
		"letter":
			return {"letter": {}}
		"voice_training":
			return {"voice_training": {}}
		"song":
			return {"song": {"path": ""}}
		"clip":
			return {"clip": {"path": ""}}
		# NOTHING WRITTEN IN IT YET: the seed still chooses, until the first entry is added
		"storyboard":
			return {"scenes": Storyboard.own_block({})}
		# A PICTURE starts as the seeded show (the user's flow: "attach a picture component... an
		# auto type"); the card picks another medium.
		"picture":
			return {"picture": {"medium": "auto"}}
		"look":
			return {"look": {}}
		"bookends":
			return {"bookends": {}}
		# its card fills its defaults (nothing goes up until "Upload after export" is ticked)
		"youtube":
			return {"youtube": {}}
	return {}


## THE BLOCKS THAT ARE [param key]'s in a note: its own, and those of what only comes with it (a
## Picture's or a Letter's illustrations). What a panel showing the component keeps, and what the
## note loses when it is detached.
static func blocks_of(key: String) -> Array:
	var out: Array = attach_blocks(key).keys()
	for k in REGISTRY:
		var row: Dictionary = REGISTRY[k]
		var b := String(row["block"])
		var with := (row["requires"] as Array).has(key) or (row.get("comes_with", []) as Array).has(key)
		if with and attach_blocks(k).is_empty() and not b.is_empty() and not out.has(b):
			out.append(b)
	return out


## Why [param key] cannot be detached from a note with [param attached], "" when it can: the text
## is the note itself, and a component another one brings stays while that one does.
static func detach_blocker(key: String, attached: Array) -> String:
	if attach_blocks(key).is_empty():
		return "%s is not attached by itself." % String((REGISTRY.get(key, {"label": key}) as Dictionary)["label"])
	for other in attached:
		if other != key and REGISTRY.has(other) and not attach_blocks(other).is_empty() \
				and ((REGISTRY[other] as Dictionary)["requires"] as Array).has(key):
			var label := String((REGISTRY[other] as Dictionary)["label"])
			return "%s brings it - detach %s first." % [label, label]
	return ""


## WHICH COMPONENTS A NOTE HAS, read off its blocks: the text always, each component whose block it
## carries, and a storyboard where the `scenes:` block holds or names one (the scenes themselves
## come with the picture that shows them). A part that comes with another, carried with none of
## them, has the first: a voice's chapter keeping `illustrations:` and no `picture:` (written before
## attaching a Picture wrote its block) is still shown with its pictures.
static func attached_of(blocks: Dictionary) -> Array:
	var out: Array = ["text"]
	for k in REGISTRY:
		var b := String((REGISTRY[k] as Dictionary)["block"])
		if k == "storyboard":
			if String(Storyboard.of_block(blocks.get("scenes"))["kind"]) != "none":
				out.append(k)
		elif not b.is_empty() and blocks.get(b) is Dictionary:
			out.append(k)
	for k in out.duplicate():
		var hosts: Array = (REGISTRY.get(k, {}) as Dictionary).get("comes_with", [])
		var have := with_required(out)
		if not hosts.is_empty() and not hosts.any(func(h: String) -> bool: return have.has(h)):
			out.append(hosts[0])
	return out


## Every capability [param keys] ask for between them, in order, once each - the components' own
## and those of the components they bring.
static func capabilities_of(keys: Array) -> Array:
	var out: Array = []
	for k in with_required(keys):
		for c in (REGISTRY[k] as Dictionary)["capabilities"]:
			if not out.has(c):
				out.append(c)
	return out


## [param keys] and every component they bring with them ([member REGISTRY]'s `requires`), in order.
static func with_required(keys: Array) -> Array:
	var out: Array = []
	var todo := keys.duplicate()
	while not todo.is_empty():
		var k: String = todo.pop_front()
		if out.has(k) or not REGISTRY.has(k):
			continue
		out.append(k)
		todo.append_array((REGISTRY[k] as Dictionary)["requires"])
	return out


## Why the component [param key] cannot be attached here at all, "" when it can.
static func impossible(key: String) -> String:
	return Capabilities.impossible_any(capabilities_of([key]))


## Why [param key] cannot be attached right now, "" when it can.
static func not_ready(key: String) -> String:
	return Capabilities.not_ready_any(capabilities_of([key]))


## The needs of [param keys] that none of them provides: what a card says is missing ("the
## Notebook follows a reading - attach a voice").
static func unmet(keys: Array) -> Array:
	var have: Array = []
	for k in with_required(keys):
		have.append_array((REGISTRY[k] as Dictionary)["provides"])
	var out: Array = []
	for k in with_required(keys):
		for n in (REGISTRY[k] as Dictionary)["needs"]:
			if not have.has(n) and not out.has(n):
				out.append(n)
	return out


## Which of [param attached] holds the slot [param slot], "" when it is free.
static func holder(slot: String, attached: Array) -> String:
	for k in with_required(attached):
		if ((REGISTRY[k] as Dictionary)["slots"] as Array).has(slot):
			return k
	return ""


## Why a slot [param key] takes is not free in a note with [param attached], as a sentence for the
## "+" menu ("This note's clock is its Song - detach that first."), or "" when it has room.
static func slot_note(key: String, attached: Array) -> String:
	for c in with_required([key]):
		if with_required(attached).has(c):
			continue
		for slot in (REGISTRY[c] as Dictionary)["slots"]:
			var held := holder(String(slot), attached)
			if not held.is_empty():
				return "This note's %s is its %s - detach that first." % [
					String((SLOTS[slot] as Dictionary)["label"]), String((REGISTRY[held] as Dictionary)["label"])]
	return ""


## WHAT "+" OFFERS a note with [param attached], in the families' order: every component that is
## attached by itself, is not there already and is possible on this platform.
static func offered(attached: Array) -> Array:
	var have := with_required(attached)
	var order: Array = FAMILIES.keys()
	var keys: Array = REGISTRY.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return order.find(REGISTRY[a]["family"]) < order.find(REGISTRY[b]["family"]))
	return keys.filter(func(k: String) -> bool:
		return not have.has(k) and not attach_blocks(k).is_empty() and impossible(k).is_empty())


## Why [param key] cannot be attached to a note with [param attached] this moment, "" when it can:
## the room it takes is taken, something it runs on is not installed yet, or it needs what nothing
## attached gives.
static func cannot_attach(key: String, attached: Array) -> String:
	var why := slot_note(key, attached)
	if why.is_empty():
		why = not_ready(key)
	if why.is_empty():
		why = needs_note(key, attached)
	if why.is_empty():
		why = host_note(key, attached)
	return why


## Why the panel a note with [param attached] would run on, once [param key] is attached, shows no
## card for it (its workspace's `hosts`), "" when it does: an Actor on a show of cards would be a block
## nothing shows. A panel with no `hosts` (the note's own) shows every card, and where the video goes
## is every panel's own to build.
static func host_note(key: String, attached: Array) -> String:
	var row: Dictionary = REGISTRY.get(key, {})
	if StringName(row.get("family", &"")) == &"publish":
		return ""
	var ws := workspace_of(attached + [key])
	var hosts: Variant = (WORKSPACES.get(ws, {}) as Dictionary).get("hosts")
	if not (hosts is Array) or (hosts as Array).has(key):
		return ""
	return "The %s panel shows no %s - it goes on a note of its own, or with what brings it." % [
		String((WORKSPACES[ws] as Dictionary)["label"]), String(row.get("label", key))]


## THE "+" MENU: every component [method offered] a note with [param attached] - what can be
## attached now first, then, under a line, what cannot be had yet, each GRAYED with its reason as
## the tooltip ([method cannot_attach]). What is impossible on this platform is left out, and so is
## what is attached already. A component that agents run says which are installed, or lists every
## one its roles support ([method Capabilities.agents_tooltip]). Each item's metadata is its key
## ("" on the line between).
static func attach_menu(menu: PopupMenu, attached: Array) -> void:
	menu.clear()
	var keys := offered(attached)
	var lit: Array = keys.filter(func(k: String) -> bool: return cannot_attach(k, attached).is_empty())
	var waiting: Array = keys.filter(func(k: String) -> bool: return not lit.has(k))
	for k in lit:
		_menu_item(menu, k, attached)
	if not lit.is_empty() and not waiting.is_empty():
		menu.add_separator()
		menu.set_item_metadata(menu.item_count - 1, "")
	for k in waiting:
		_menu_item(menu, k, attached)


static func _menu_item(menu: PopupMenu, k: String, attached: Array) -> void:
	var row: Dictionary = REGISTRY[k]
	menu.add_item(String(row["label"]))
	var i := menu.item_count - 1
	menu.set_item_metadata(i, k)
	var why := cannot_attach(k, attached)
	menu.set_item_disabled(i, not why.is_empty())
	var tip := String(row["blurb"])
	var roles := Capabilities.roles_of(capabilities_of([k]))
	var missing := Capabilities.missing_roles(roles)
	if not roles.is_empty():
		tip += "\n\n" + Capabilities.agents_tooltip(roles, missing)
	# a missing agent is said above, in full; any other reason is said here
	if not why.is_empty() and not (not missing.is_empty() and why == not_ready(k)):
		tip += "\n\n" + why
	menu.set_item_tooltip(i, tip)


## What attaching each need's provider looks like, for [method needs_note].
const NEED_HINTS := {"text": "text", "audio": "a song or a voice", "reading": "a voice",
	"picture": "a Picture", "places": "a Picture", "moments": "a song or a voice"}


## The needs [param key] brings that nothing in [param attached] provides, as a sentence for the "+"
## menu ("Needs a Picture - attach it first."), or "" when everything it needs is there.
static func needs_note(key: String, attached: Array) -> String:
	var have: Array = []
	for c in with_required(attached + [key]):
		have.append_array((REGISTRY[c] as Dictionary)["provides"])
	var hints := PackedStringArray()
	for c in with_required([key]):
		for n in (REGISTRY[c] as Dictionary)["needs"]:
			var h := String(NEED_HINTS.get(n, n))
			if not have.has(n) and not hints.has(h):
				hints.append(h)
	if hints.is_empty():
		return ""
	return "Needs %s - attach %s first." % [" and ".join(hints), "it" if hints.size() == 1 else "them"]

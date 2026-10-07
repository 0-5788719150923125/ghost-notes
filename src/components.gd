extends RefCounted
class_name Components

## Components - the parts a note is made of (next/notes.md, "A component" and step 7). One registry
## shaped like [Medium]'s: each entry says what the component is, what it needs and what it gives,
## the components it brings with it, what it asks of the platform ([Capabilities]), which groups of
## the script's marks it brings, the frontmatter block it keeps, and the card it is set on. Today's
## six modes are TEMPLATES over it ([constant TEMPLATES]): the notes list's New offers them, and main
## starts every one through one path (`main.start_template`).
##
## NEEDS AND PROVIDES ARE TYPED NAMES that ghost matches, the way a scene's `morph_out` and
## `morph_in` already are: "text", "audio", "reading", "picture", "moments". A component never
## names another to work - only what it needs - so a need nobody provides is a sentence on a card,
## never a branch somewhere else.
##
## THE STAGE IS A CAPABILITY: anything shown on it asks for `forward_plus`, the desktop renderer, so
## on a phone - where a note is its text and nothing more - every component but the text is
## impossible and "+" offers nothing else ([method attach_menu]).
##
## Static and free of autoload names, like [Capabilities], so a gate can read it under `--script`.

## THE FAMILIES: a label and a hue in degrees - the color a component's card, chip and marks are
## drawn in ([Card]); "paper", the note's own text, has none. Color is per family, not per component
## (Scratch's categories, Blender's sockets, TouchDesigner's operator families), because hues run out
## near eight. The order is the order cards stand in on a panel - read top to bottom, it says what
## happens to the note: the text, what produces a reading, the voice, sound, pictures, the
## presentation, the Look last.
const FAMILIES := {
	&"paper": {"label": "Text", "hue": -1.0},
	&"producer": {"label": "Producer", "hue": 275.0},
	&"voice": {"label": "Voice", "hue": 172.0},
	&"sound": {"label": "Sound", "hue": 212.0},
	&"picture": {"label": "Picture", "hue": 32.0},
	&"medium": {"label": "Presentation", "hue": 128.0},
	&"look": {"label": "Look", "hue": 322.0},
}

const REGISTRY := {
	"text": {"label": "Text", "family": &"paper",
		"blurb": "The note's own words: what a voice reads, the brief an agent works from, or just a note.",
		"needs": [], "provides": ["text"], "requires": [], "capabilities": [],
		"marks": [], "block": "", "card": "script"},
	"song": {"label": "Song", "family": &"sound",
		"blurb": "A song the show is cut on: its beat and its spectrum drive the scenes.",
		"needs": [], "provides": ["audio"], "requires": [], "capabilities": ["stage"],
		"marks": [], "block": "song", "card": ""},
	"scenes": {"label": "Scenes", "family": &"picture",
		"blurb": "The visualizer scenes, chosen by the seed and cut on the sound.",
		"needs": ["audio"], "provides": ["picture", "moments"], "requires": [],
		"capabilities": ["forward_plus"], "marks": [], "block": "scenes", "card": ""},
	"storyboard": {"label": "Storyboards", "family": &"picture",
		"blurb": "The scenes by hand: a storyboard picks them and the dial plays them.",
		"needs": ["audio", "places"], "provides": ["picture"], "requires": ["scenes"],
		"capabilities": ["forward_plus"], "marks": [], "block": "", "card": "storyboards"},
	"voice": {"label": "Voice", "family": &"voice",
		"blurb": "A small local neural voice reads the text: a cast of speakers, their delivery and their room.",
		"needs": ["text"], "provides": ["audio", "reading", "moments"], "requires": [],
		"capabilities": ["stage", "subprocess", "python:voice"], "marks": ["voices", "timing", "pronunciation"],
		"block": "voice", "card": "voice"},
	"voice_lab": {"label": "Voice lab", "family": &"voice",
		"blurb": "Ghost Notes' own synthesizer reads the text, and the fishing game breeds its voices.",
		"needs": ["text"], "provides": ["audio", "reading", "moments"], "requires": [],
		"capabilities": ["stage"], "marks": ["voices", "timing"], "block": "synthesis", "card": "water"},
	"picture": {"label": "Picture", "family": &"picture",
		"blurb": "A show for the note, and what it is carried on: Auto (the seeded show, nothing to set), full frame, a comic, a book, a notebook, a tablet.",
		"needs": ["picture"], "provides": ["places"], "requires": ["scenes"],
		"capabilities": ["forward_plus"], "marks": ["typography", "tablet"], "block": "picture", "card": "picture"},
	"illustrations": {"label": "Illustrations", "family": &"picture",
		"blurb": "The book's pictures, painted by an agent from the marks in the text, or imported.",
		"needs": ["text", "places"], "provides": ["picture"], "requires": ["picture"],
		"capabilities": ["forward_plus"], "marks": ["pictures"], "block": "illustrations", "card": "picture"},
	"look": {"label": "Look", "family": &"look",
		"blurb": "A post-process over the whole picture: grain, noir, a vignette, and the rest.",
		"needs": ["picture"], "provides": [], "requires": [],
		"capabilities": ["forward_plus"], "marks": [], "block": "look", "card": "look"},
	"bookends": {"label": "Intro & outro", "family": &"paper",
		"blurb": "Seconds held before the first word and after the last.",
		"needs": ["audio"], "provides": [], "requires": [],
		"capabilities": ["forward_plus"], "marks": [], "block": "bookends", "card": "bookends"},
	"cards": {"label": "Cards", "family": &"producer",
		"blurb": "Agents plan, deal, paint and write a reading, one card at a time, at a table.",
		"needs": ["text"], "provides": ["text", "picture", "moments"], "requires": ["voice"],
		"capabilities": ["forward_plus", "subprocess", "agent:writer", "agent:painter"], "marks": [],
		"block": "cards", "card": "episode"},
	"clip": {"label": "Clip", "family": &"picture",
		"blurb": "A video, cut and prepared from a file or a link.",
		"needs": [], "provides": ["picture", "audio"], "requires": [],
		"capabilities": ["forward_plus", "subprocess", "ffmpeg"], "marks": [], "block": "clip", "card": ""},
	"masks": {"label": "Masks", "family": &"look",
		"blurb": "Chroma-key effects over a clip: markers, tracks and renders.",
		"needs": ["picture"], "provides": [], "requires": ["clip"],
		"capabilities": ["forward_plus", "subprocess", "ffmpeg"], "marks": [], "block": "", "card": ""},
}

## TODAY'S MODES, AS TEMPLATES: each a set of components and the session that runs them (`song`, a
## song playing under the scenes; `reading`, a panel that reads a text; `clip`, Masking's editor).
## The notes list's New offers them in this order; `main.start_template` starts each through one path.
## `uses` is the small caption under a row; `mode` is the key the session path and the script's
## marks still go by ([ScriptMarks] filters by it), until a note composes its components (step 8).
const TEMPLATES := {
	# JUST THE TEXT: a note with nothing attached is a text editor, and "+" makes it something
	"note": {"label": "Note", "session": "text", "mode": "note", "components": ["text"],
		"blurb": "Just the words. Attach what it should become - a voice, a picture, a song - with +.",
		"uses": ""},
	# A SONG AND ITS SHOW: the song plays from the note's panel, and its Picture is the Auto medium -
	# the seeded show with nothing to set (2026-10-06). A Look, the bookends or a storyboard are "+".
	"auto": {"label": "Auto", "session": "song", "mode": "auto",
		"components": ["text", "song", "picture"],
		"blurb": "A song and the seeded show - every scene chosen from the song itself, nothing to set.", "uses": ""},
	"manual": {"label": "Manual", "session": "song", "mode": "manual", "storyboard": "default",
		"components": ["text", "song", "picture", "storyboard"],
		"blurb": "A song and a show by hand - storyboards and the dial.", "uses": ""},
	# Two templates rather than one with a sub-choice: the paths are not variants of each other.
	# Synthesis has a genome, a belt and a fishing loop; Generative has a speaker id and three
	# scalars (VOICE_PLAN.md section 6).
	"synthesis": {"label": "Synthesis", "session": "reading", "mode": "fishing", "section": "synth",
		"components": ["text", "voice_lab", "scenes"],
		"blurb": "Write a script; Ghost Notes speaks it and the show reacts to the voice.",
		"uses": "no import needed"},
	"generative": {"label": "Generative", "session": "reading", "mode": "neural", "section": "generative",
		"components": ["text", "voice", "scenes", "picture", "illustrations", "look", "bookends"],
		"blurb": "The same, in a small local neural voice - clearer, at the cost of a downloaded model.",
		"uses": "downloads a voice once"},
	# A reading nobody writes: agents plan, paint and write each episode, and the neural voice reads
	# it at a card table - its own template rather than a medium of Generative, because what drives
	# it is not a script but a show's brief.
	"cards": {"label": "Cards", "session": "reading", "mode": "cards", "section": "cards",
		"components": ["text", "cards", "voice", "look", "bookends"],
		"blurb": "A card reading nobody writes - agents plan, deal, paint and write each episode one card at a time, and a voice reads it at the table. Tarot is its first deck.",
		"uses": ""},
	"masking": {"label": "Masking", "session": "clip", "mode": "masking",
		"components": ["clip", "masks"],
		"blurb": "Chroma-key effects over a video - markers, tracks, renders.", "uses": ""},
}


## WHICH TEMPLATE RUNS A NOTE, read off its blocks (step 8): a show (`cards:`) is Cards; a voice
## lab's (`synthesis:`) Synthesis; a voice (`voice:`) Generative; a clip (`clip:`) Masking; a song
## (`song:`) Manual when its scenes name a storyboard, else Auto; nothing attached, a plain note.
## In that order, because a show carries a voice and a reading carries a picture: the component that
## decides what the note IS comes first.
static func template_for(blocks: Dictionary) -> String:
	if blocks.get("cards") is Dictionary:
		return "cards"
	if blocks.get("synthesis") is Dictionary:
		return "synthesis"
	if blocks.get("voice") is Dictionary:
		return "generative"
	if blocks.get("clip") is Dictionary:
		return "masking"
	if blocks.get("song") is Dictionary:
		var scenes: Variant = blocks.get("scenes", {})
		var board := String((scenes as Dictionary).get("storyboard", "")) if scenes is Dictionary else ""
		return "manual" if not board.is_empty() else "auto"
	return "note"


## THE BLOCKS A NEW NOTE FROM [param key] IS MADE WITH: only the one that says what it is, so
## [method template_for] reads it back - every other block is written by its card the first time it
## changes. An empty block is not "the defaults" to every card (an empty `illustrations:` wipes the
## pictures' look), and a block nobody set is no block.
static func marker_blocks(key: String) -> Dictionary:
	match key:
		"cards":
			return {"cards": {}}
		"synthesis":
			return {"synthesis": {}}
		"generative":
			return {"voice": {}}
		"masking":
			return {"clip": {"path": ""}}
		"auto":
			return {"song": {"path": ""}, "picture": {"medium": "auto"}}
		"manual":
			return {"song": {"path": ""}, "picture": {"medium": "full"},
				"scenes": {"storyboard": String(TEMPLATES["manual"].get("storyboard", "default"))}}
	return {}


## The blocks attaching the component [param key] to a note adds: its own marker, as a new note's
## would have it (`voice:` for a Voice), or {} for one that keeps nothing in the note.
static func attach_blocks(key: String) -> Dictionary:
	match key:
		"voice":
			return {"voice": {}}
		"voice_lab":
			return {"synthesis": {}}
		"cards":
			return {"cards": {}}
		"song":
			return {"song": {"path": ""}}
		"clip":
			return {"clip": {"path": ""}}
		"storyboard":
			return {"scenes": {"storyboard": "default"}}
		# A PICTURE FOR A SONG starts as the seeded show (the user's flow: "attach a picture
		# component... an auto type"); the card picks another medium.
		"picture":
			return {"picture": {"medium": "auto"}}
		"look":
			return {"look": {}}
		"bookends":
			return {"bookends": {}}
	return {}


## WHICH COMPONENTS A NOTE HAS, read off its blocks: the text always, each component whose block it
## carries, and a storyboard where the `scenes:` block names one (the scenes themselves come with the
## picture that shows them).
static func attached_of(blocks: Dictionary) -> Array:
	var out: Array = ["text"]
	for k in REGISTRY:
		var b := String((REGISTRY[k] as Dictionary)["block"])
		if k != "scenes" and not b.is_empty() and blocks.get(b) is Dictionary:
			out.append(k)
	var scenes: Variant = blocks.get("scenes", {})
	if scenes is Dictionary and not String((scenes as Dictionary).get("storyboard", "")).is_empty():
		out.append("storyboard")
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


## Why the template [param key] cannot be started right now, "" when it can.
static func template_not_ready(key: String) -> String:
	return Capabilities.not_ready_any(capabilities_of(TEMPLATES[key]["components"]))


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


## THE "+" MENU: every component a note with [param attached] could add, in the families' order -
## or only those in [param only] (a plain note offers what decides what it becomes).
## What is impossible on this platform is LEFT OUT; what is not ready yet is listed GRAYED, its reason
## as the tooltip; what is attached already is left out. Each item's metadata is its key.
static func attach_menu(menu: PopupMenu, attached: Array, only: Array = []) -> void:
	menu.clear()
	var order: Array = FAMILIES.keys()
	var keys: Array = REGISTRY.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return order.find(REGISTRY[a]["family"]) < order.find(REGISTRY[b]["family"]))
	for k in keys:
		if attached.has(k) or not impossible(k).is_empty() or (not only.is_empty() and not only.has(k)):
			continue
		var row: Dictionary = REGISTRY[k]
		menu.add_item(String(row["label"]))
		var i := menu.item_count - 1
		menu.set_item_metadata(i, k)
		var why := not_ready(k)
		if why.is_empty():
			why = needs_note(k, attached)
		menu.set_item_disabled(i, not why.is_empty())
		menu.set_item_tooltip(i, String(row["blurb"]) + ("" if why.is_empty() else "\n\n" + why))


## What attaching each need's provider looks like, for [method needs_note].
const NEED_HINTS := {"text": "text", "audio": "a song or a voice", "reading": "a voice",
	"picture": "a Picture", "places": "a Picture", "moments": "a song or a voice"}


## The needs [param key] brings that nothing in [param attached] provides, as a sentence for the "+"
## menu ("Needs a Picture - attach one first."), or "" when everything it needs is there.
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

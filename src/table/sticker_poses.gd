extends RefCounted
class_name StickerPoses

## StickerPoses - what a page of a sticker book ([StickerBook], next/sticker_book.md) can ask of the drawings laid on it: each
## character's POSES, every one painted from the character's model on a flat green ground and cut off it, and the EFFECTS a page
## marks its beat with. Generic as a body is: no pose or effect names a story, a game or a kind of show.
##
## A pose row: `label`, `blurb` (what the game master is told), `ask` (what the painter is told: the pose, never the hand, which is
## the show's), `close` (head and shoulders filling the page, for a close shot, rather than the whole body), `tall` (how much of the
## character's standing height its drawing spans: a crouch is lower, arms thrown up higher - so a pose is drawn at the size its
## body is, whatever size the painter drew it), and `faces` ("side": turned to the right of the page, mirrored to face left;
## "front": never mirrored). A pose the game master says in its own words is painted from those words, standing height, turned.
##
## An effect row: `label`, `blurb`, and `lasts` (seconds from the page's first moment; 0 for the whole page).
##
## An ANGLE row: one view of a set, `label`, `blurb` (what the game master is told) and `ask` (what the painter is told of it, beside
## the set's first painting, which is its `wide`). A scene is covered from its set's angles as a film covers one.

const POSES := {
	"stand": {"label": "Standing", "close": false, "tall": 1.0, "faces": "side",
		"ask": "standing at ease, whole, head to foot, turned a little toward the RIGHT side of the page, arms relaxed, whatever it always carries held as it carries it",
		"blurb": "at ease: the pose for just being there"},
	"talk": {"label": "Talking", "close": false, "tall": 1.0, "faces": "side",
		"ask": "talking, mouth open mid-word, one hand out in a gesture, whole, head to foot, turned a little toward the RIGHT side of the page",
		"blurb": "saying something, a hand out"},
	"point": {"label": "Pointing", "close": false, "tall": 1.0, "faces": "side",
		"ask": "pointing hard at something off the RIGHT edge of the page, arm straight out, looking where it points, whole, head to foot",
		"blurb": "pointing at something or someone"},
	"shock": {"label": "Shocked", "close": false, "tall": 0.97, "faces": "side",
		"ask": "recoiling in shock, leaning back, eyes huge, mouth wide open, both hands flung up, whole, head to foot, turned a little toward the RIGHT side of the page",
		"blurb": "recoiling in surprise"},
	"laugh": {"label": "Laughing", "close": false, "tall": 0.97, "faces": "side",
		"ask": "laughing hard, eyes squeezed shut, mouth wide, leaning back with a hand on its belly, whole, head to foot",
		"blurb": "doubled over laughing"},
	"angry": {"label": "Furious", "close": false, "tall": 0.97, "faces": "side",
		"ask": "furious, brows down, teeth bared, fists clenched, leaning forward toward the RIGHT side of the page, whole, head to foot",
		"blurb": "furious, leaning in"},
	"sad": {"label": "Dejected", "close": false, "tall": 0.92, "faces": "side",
		"ask": "dejected, shoulders slumped, head hung, arms hanging, whole, head to foot, turned a little toward the RIGHT side of the page",
		"blurb": "slumped, defeated"},
	"scared": {"label": "Cowering", "close": false, "tall": 0.72, "faces": "side",
		"ask": "cowering, crouched low with both arms up to shield its face, trembling, whole, turned a little toward the RIGHT side of the page",
		"blurb": "cowering in fear"},
	"think": {"label": "Thinking", "close": false, "tall": 1.0, "faces": "side",
		"ask": "thinking hard, a hand on its chin, eyes turned up and aside, whole, head to foot, turned a little toward the RIGHT side of the page",
		"blurb": "pondering, hand on chin"},
	"proud": {"label": "Proud", "close": false, "tall": 1.0, "faces": "front",
		"ask": "standing tall and proud facing us, chest out, fists on hips, chin up, whole, head to foot",
		"blurb": "chest out, triumphant"},
	"cheer": {"label": "Cheering", "close": false, "tall": 1.15, "faces": "front",
		"ask": "cheering, both arms thrown straight up, mouth wide open, facing us, whole, head to foot",
		"blurb": "arms up in a cheer"},
	"run": {"label": "Running", "close": false, "tall": 0.95, "faces": "side",
		"ask": "running flat out toward the RIGHT side of the page, seen from the side, mid-stride, leaning into it, arms pumping, whole, head to foot",
		"blurb": "running, seen from the side"},
	"sneak": {"label": "Sneaking", "close": false, "tall": 0.85, "faces": "side",
		"ask": "creeping toward the RIGHT side of the page on tiptoe, hunched, arms held up, seen from the side, whole, head to foot",
		"blurb": "creeping on tiptoe"},
	"strike": {"label": "Striking", "close": false, "tall": 0.98, "faces": "side",
		"ask": "mid-blow, swinging whatever it holds (or a fist) hard toward the RIGHT side of the page, body twisted into it, whole, head to foot",
		"blurb": "swinging a blow"},
	"thrust": {"label": "Hands out", "close": false, "tall": 1.0, "faces": "side",
		"ask": "both hands thrust out toward the RIGHT side of the page, fingers spread, straining, as if pushing something unseen away, whole, head to foot",
		"blurb": "both hands thrust out, straining at something unseen"},
	"hold": {"label": "Holding up", "close": false, "tall": 1.0, "faces": "front",
		"ask": "holding something up in both hands in front of it to look at it, facing us, whole, head to foot",
		"blurb": "holding something up to look at"},
	"wave": {"label": "Waving", "close": false, "tall": 1.0, "faces": "side",
		"ask": "waving one hand high in greeting, smiling, whole, head to foot, turned a little toward the RIGHT side of the page",
		"blurb": "waving hello"},
	"shrug": {"label": "Shrugging", "close": false, "tall": 0.98, "faces": "front",
		"ask": "shrugging, shoulders up, palms turned up, eyebrows raised, facing us, whole, head to foot",
		"blurb": "shrugging, palms up"},
	"crouch": {"label": "Crouching", "close": false, "tall": 0.66, "faces": "side",
		"ask": "crouched low and ready, one hand on the ground, looking toward the RIGHT side of the page, whole",
		"blurb": "crouched, ready to spring"},
	"sit": {"label": "Sitting", "close": false, "tall": 0.62, "faces": "side",
		"ask": "sitting on the ground, legs crossed, turned a little toward the RIGHT side of the page, whole",
		"blurb": "sitting on the ground"},
	"fall": {"label": "Knocked flat", "close": false, "tall": 0.36, "faces": "side",
		"ask": "knocked flat on its back on the ground, arms and legs flung out, dazed, seen from the side, its head toward the RIGHT side of the page, whole",
		"blurb": "flat on its back"},
	"back": {"label": "From behind", "close": false, "tall": 1.0, "faces": "front",
		"ask": "seen from behind, its back to us, walking away, whole, head to foot",
		"blurb": "its back to us, walking away"},
	"face": {"label": "Close: calm", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, calm, mouth closed",
		"blurb": "a close shot, calm"},
	"face_talk": {"label": "Close: talking", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, mouth open mid-word",
		"blurb": "a close shot, saying something"},
	"face_shock": {"label": "Close: shocked", "close": true, "tall": 1.0, "faces": "front",
		"ask": "close up: its head and shoulders filling the page, facing us, eyes huge, mouth wide open in shock",
		"blurb": "a close shot, shocked"},
	"face_smile": {"label": "Close: smiling", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, a broad warm smile",
		"blurb": "a close shot, smiling"},
	"face_smug": {"label": "Close: smug", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, a sly, smug half-smile, eyes narrowed",
		"blurb": "a close shot, smug"},
	"face_angry": {"label": "Close: furious", "close": true, "tall": 1.0, "faces": "front",
		"ask": "close up: its head and shoulders filling the page, facing us, brows down hard, teeth bared",
		"blurb": "a close shot, furious"},
	"face_worried": {"label": "Close: worried", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, brows up, a bead of sweat, biting its lip",
		"blurb": "a close shot, worried"},
	"face_sad": {"label": "Close: crushed", "close": true, "tall": 1.0, "faces": "side",
		"ask": "close up: its head and shoulders filling the page, turned a little toward the RIGHT side of the page, eyes welling, mouth trembling",
		"blurb": "a close shot, close to tears"},
	"face_blank": {"label": "Close: deadpan", "close": true, "tall": 1.0, "faces": "front",
		"ask": "close up: its head and shoulders filling the page, facing us dead on, a completely flat, expressionless stare",
		"blurb": "a close shot, a flat deadpan stare at us"},
}

const EFFECTS := {
	"flash": {"label": "Flash", "lasts": 0.32, "blurb": "the page comes up out of a white flash: a sudden thing"},
	"shake": {"label": "Shake", "lasts": 0.5, "blurb": "the frame shakes as the page comes up: an impact, a crash"},
	"lines": {"label": "Focus lines", "lasts": 0.0, "blurb": "lines rush in from the edges toward who or what the page is about: a big realization, a dramatic beat"},
	"burst": {"label": "Burst", "lasts": 0.0, "blurb": "a jagged burst behind who or what the page is about: shock, impact, a roll's extreme"},
	"dark": {"label": "Dark", "lasts": 0.0, "blurb": "the set goes dark behind the cast: a dread moment, someone alone with a thought"},
	"red": {"label": "Red", "lasts": 0.0, "blurb": "the whole page goes red: rage, danger, fire"},
	"blue": {"label": "Blue", "lasts": 0.0, "blurb": "the whole page goes cold blue: gloom, a chill, embarrassment"},
	"gold": {"label": "Gold", "lasts": 0.0, "blurb": "the whole page glows gold: glory, a triumph, something precious"},
	"boom": {"label": "Explosion", "lasts": 0.9, "blurb": "an explosion where who or what the page is about is: a flash, a shake and a burst of smoke"},
	"glide": {"label": "Glide", "lasts": 0.0, "blurb": "the camera moves to this picture across the same view instead of cutting: following someone across the place, rarely"},
	"still": {"label": "Still", "lasts": 0.0, "blurb": "the page is held dead still, never pushed in: a long awkward silence"},
}

const ANGLES := {
	"wide": {"label": "Wide", "ask": "",
		"blurb": "the whole place from the front, as the set was first painted: to open a scene, and to come back to when someone arrives or leaves"},
	"reverse": {"label": "Reverse",
		"ask": "seen from the opposite side, looking back toward where the first view was painted from: what was behind that view is in front of this one",
		"blurb": "the same place from the other side, looking back: the other half of a conversation, or what someone sees when they turn round"},
	"side": {"label": "From the side",
		"ask": "seen from its left-hand side, at a right angle to the first view",
		"blurb": "the same place from one side, at a right angle to the wide: someone coming in, two facing off"},
	"close": {"label": "Close",
		"ask": "seen close, from where someone stands in it: one part of it - a wall, a corner, a workbench - filling the view, its floor at the bottom",
		"blurb": "one part of the place seen close, a wall or a corner or a bench filling the view: behind a close shot, or a few people in a tight spot"},
}

## A pose said in a game master's own words is at most this many words (a pose and what it does, whole); past it, only its first ones are kept.
const OWN_WORDS := 20
## The share of a standing figure an own-words pose spans, and how it faces.
const OWN_TALL := 1.0


## The key of the pose [param said]: a row's key as said (any case, spaces for underscores), or "own:" and the words themselves
## for a pose said in words; "stand" for nothing said.
static func key_of(said: String) -> String:
	var s := said.strip_edges().to_lower()
	if s.is_empty():
		return "stand"
	var k := s.replace(" ", "_").replace("-", "_")
	if POSES.has(k):
		return k
	if k.begins_with("close_") and POSES.has("face_" + k.trim_prefix("close_")):
		return "face_" + k.trim_prefix("close_")
	var words := s.split(" ", false)
	return "own:" + " ".join(words.slice(0, OWN_WORDS))


## Whether [param key] (a [method key_of]) is a close shot of the head and shoulders.
static func close(key: String) -> bool:
	return bool(Registry.field(POSES, key, "close", false)) if POSES.has(key) else false


## How much of a standing figure's height pose [param key]'s drawing spans.
static func tall(key: String) -> float:
	return float(Registry.field(POSES, key, "tall", OWN_TALL)) if POSES.has(key) else OWN_TALL


## Whether pose [param key] is drawn turned (so mirrored to face left); a front pose never is.
static func turned(key: String) -> bool:
	return String(Registry.field(POSES, key, "faces", "side")) == "side" if POSES.has(key) else true


## What the painter is told of pose [param key]: its row's words, or the game master's own.
static func ask(key: String) -> String:
	if POSES.has(key):
		return String(Registry.field(POSES, key, "ask", ""))
	return "%s, whole, head to foot, turned a little toward the RIGHT side of the page" % key.trim_prefix("own:")


## What a row of the Pipeline card or the Dex calls pose [param key].
static func label(key: String) -> String:
	return Registry.label(POSES, key) if POSES.has(key) else key.trim_prefix("own:")


## Every pose as the game master is told it: "key: what it is", one a line.
static func told() -> String:
	var out := PackedStringArray()
	for k in POSES:
		out.append("%s: %s" % [k, Registry.blurb(POSES, k)])
	return "\n".join(out)


## Every angle as the game master is told it.
static func angles_told() -> String:
	var out := PackedStringArray()
	for k in ANGLES:
		out.append("%s: %s" % [k, Registry.blurb(ANGLES, k)])
	return "\n".join(out)


## The angle [param said] names (any case), "wide" for nothing said or a name that is none.
static func angle_of(said: Variant) -> String:
	var k := String(said).strip_edges().to_lower() if said is String else ""
	return k if ANGLES.has(k) else "wide"


## Every effect as the game master is told it.
static func effects_told() -> String:
	var out := PackedStringArray()
	for k in EFFECTS:
		out.append("%s: %s" % [k, Registry.blurb(EFFECTS, k)])
	return "\n".join(out)


## The effects of [param said] that are rows, in order, each once.
static func effects_of(said: Variant) -> Array:
	var out: Array = []
	var list: Array = said if said is Array else ([said] if said is String else [])
	for v in list:
		var k := String(v).strip_edges().to_lower()
		if EFFECTS.has(k) and not out.has(k):
			out.append(k)
	return out

extends RefCounted
class_name PuppetSheet

## PuppetSheet - the drawings a puppet is made of (next/cartoon.md, "The model sheet"), as a cartoon's model sheet is: the character
## facing us with its mouth closed, open and wide, in profile, from behind, and in a few moods - each painted by an image model from
## the maker's drawing (or from another drawing of the sheet), cut off its paper, set to the others' size and feet, and rigged. The
## puppet SWAPS between them as a hand-drawn cartoon does (its view as it turns or runs, its mouth as it talks, its mood), and bends
## each only for the small life between ([PuppetBody]).
##
## A row: `view` (front, side, back), `mouth` (closed, open, wide; "" for a drawing that is only itself), `mood` ("" for none), `action`
## ("" for none: a stride swapped with the profile as it goes, a wind-up and a reeling a verb swaps in for its moment), `from`
## (the drawing it is painted from, "" the maker's own), `ask` (what the painter is asked for - the drawing, never its style, which is
## the maker's), and `blurb`. A side drawing faces right; facing left is it mirrored.
##
## A puppet's folder holds `sheet.json` ({drawings: [keys]}) and a folder per drawing with its rig; a folder with only a `rig.json` is
## a puppet of one drawing, its front.

const FILE := "sheet.json"
const VIEWS := ["front", "side", "back"]
const MOUTHS := ["closed", "open", "wide"]
const MOODS := ["", "scared", "angry", "laughing", "dead"]
const ACTIONS := ["", "stride", "windup", "reeling"]

const REGISTRY := {
	"front": {"label": "Front", "view": "front", "mouth": "closed", "mood": "", "from": "",
		"ask": "The same character standing on the ground facing us, its whole body from the top of its head to its feet, its mouth CLOSED, its arms held a little away from its body, whatever it holds still in its hands.",
		"blurb": "Facing us, mouth closed: the drawing the rest of the sheet is painted from."},
	"front_open": {"label": "Front, talking", "view": "front", "mouth": "open", "mood": "", "from": "front",
		"ask": "Exactly the same drawing, changed in one thing only: its mouth is OPEN, partway, as if in the middle of a word. Same pose, same size, same place on the page.",
		"blurb": "Facing us, its mouth open mid-word."},
	"front_wide": {"label": "Front, shouting", "view": "front", "mouth": "wide", "mood": "", "from": "front",
		"ask": "Exactly the same drawing, changed in one thing only: its mouth is WIDE open, as if shouting. Same pose, same size, same place on the page.",
		"blurb": "Facing us, its mouth wide open."},
	"side": {"label": "Profile", "view": "side", "mouth": "closed", "mood": "", "from": "front",
		"ask": "The same character turned to face the RIGHT side of the page, seen exactly in profile, standing, its whole body from the top of its head to its feet, its mouth closed, whatever it holds still in its hands.",
		"blurb": "In profile, facing right (left is it mirrored): what it is drawn as while it walks or runs across."},
	"side_open": {"label": "Profile, talking", "view": "side", "mouth": "open", "mood": "", "from": "side",
		"ask": "Exactly the same drawing, changed in one thing only: its mouth is OPEN, as if in the middle of a word. Same pose, same size, same place on the page.",
		"blurb": "In profile, its mouth open."},
	"back": {"label": "From behind", "view": "back", "mouth": "", "mood": "", "from": "front",
		"ask": "The same character seen from BEHIND, its back to us, standing, its whole body from the top of its head to its feet.",
		"blurb": "Its back to us."},
	"scared": {"label": "Scared", "view": "front", "mouth": "", "mood": "scared", "from": "front",
		"ask": "The same character facing us, terrified: eyes bulging, cowering, hands up by its face, mouth open in a yelp. Whole body, head to feet.",
		"blurb": "Frightened."},
	"angry": {"label": "Angry", "view": "front", "mouth": "", "mood": "angry", "from": "front",
		"ask": "The same character facing us, furious: brows down, teeth bared, fists or claws clenched, leaning forward. Whole body, head to feet.",
		"blurb": "Furious."},
	"laughing": {"label": "Laughing", "view": "front", "mouth": "", "mood": "laughing", "from": "front",
		"ask": "The same character facing us, laughing hard: eyes squeezed shut, mouth wide open, leaning back, a hand on its belly. Whole body, head to feet.",
		"blurb": "Laughing."},
	"dead": {"label": "Cartoon-dead", "view": "front", "mouth": "", "mood": "dead", "from": "front",
		"ask": "The same character knocked out cold, cartoon-dead: flung flat, arms and legs splayed out wildly, X's for eyes, tongue hanging out. Whole body.",
		"blurb": "Knocked out cold, X's for eyes."},
	"stride": {"label": "Stride", "view": "side", "mouth": "", "mood": "", "action": "stride", "from": "side",
		"ask": "Exactly the same character in the same profile, facing the RIGHT side of the page, caught mid-stride as it walks: its front leg reaching forward, its back leg pushing off behind, its arms swinging the other way. Same size, whatever it holds still in its hands.",
		"blurb": "Mid-stride in profile: swapped with the profile at every step, as a drawn walk is."},
	"windup": {"label": "Wind-up", "view": "front", "mouth": "", "mood": "", "action": "windup", "from": "front",
		"ask": "The same character facing us, winding up to strike: whatever it holds raised high behind its head (or a fist pulled back if it holds nothing), its body leaning back, teeth gritted. Whole body, head to feet.",
		"blurb": "Winding up a blow."},
	"reeling": {"label": "Reeling", "view": "front", "mouth": "", "mood": "", "action": "reeling", "from": "front",
		"ask": "The same character facing us, just hit hard on the head: reeling, knees buckling, eyes crossed and spinning, tongue lolling, a bump rising on its head. Whole body, head to feet.",
		"blurb": "Just struck, reeling."},
}


## The drawing of those a puppet [param have] (key -> anything) best for its [param view], [param mouth], [param mood] and [param action]:
## the action's own where it has one, the mood's next, else the view's with that mouth (wide falling back to open, open to closed), else its front; "" for none.
static func pick(have: Dictionary, view: String, mouth: String, mood: String, action := "") -> String:
	if not action.is_empty() and have.has(action):
		return action
	if not mood.is_empty() and have.has(mood):
		return mood
	var v := view if have.has(view) else "front"
	if not have.has(v):
		return String(have.keys()[0]) if not have.is_empty() else ""
	if mouth == "wide" and have.has(v + "_wide"):
		return v + "_wide"
	if mouth in ["wide", "open"] and have.has(v + "_open"):
		return v + "_open"
	return v


## The drawing [param key]'s view (front where it is none of the sheet's).
static func view_of(key: String) -> String:
	return String((REGISTRY.get(key, {}) as Dictionary).get("view", "front"))


## The drawings to make, in an order where each comes after the one it is painted from.
static func order() -> PackedStringArray:
	var out := PackedStringArray()
	while out.size() < REGISTRY.size():
		for k in REGISTRY:
			var from := String((REGISTRY[k] as Dictionary)["from"])
			if not out.has(k) and (from.is_empty() or out.has(from)):
				out.append(k)
	return out

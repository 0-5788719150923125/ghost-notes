extends RefCounted
class_name ActorSteps

## ActorSteps - what an actor is made of, step by step (next/likeness.md, "The steps"): one row a
## step, in the order an actor is built. The Actor card lists them, [ActorBuilder] runs them, and
## [ActorFolder] keeps what each made.
##
##   label     the step's row on the card
##   per       what one run of it covers: "video" (each ticked video), "actor" (all of them at once)
##             or "set" (the chosen set: where the pixels come from - its still, its rig, its library)
##   needs     the steps whose outputs it reads - of the same video, or of every ticked video when it
##             covers more than one
##   runs      how: "download" (yt-dlp), "probe" (ffprobe), "python" (hosts/face/actor.py), "local"
##             (ghost itself) or "agent" (a writer shown pictures)
##   env       what it runs on that ghost installs, as [Deps] keys
##   outputs   the files it makes, in its folder: the video's, the actor's or the set's
##   settings  the [constant SETTINGS] it is made under: one changed makes it stale
##   version   bumped when what the step makes changes, which makes every one made before stale
##   blurb     what it does, for the row's tooltip
##
## A video that came from a folder has nothing to fetch: its `fetch` is MOOT ([method ActorFolder.moot]),
## and a step that needs it reads the file where it is; one with no captions link has no `captions`
## to fetch either (a linked video's come with it).
const REGISTRY := {
	"fetch": {"label": "Fetch", "per": "video", "needs": [], "runs": "download", "env": ["ytdlp_venv"],
		"outputs": [], "settings": [], "version": 1,
		"blurb": "Downloads a linked video (up to 1080p) with its automatic captions and its details, one at a time. A video from a folder is read where it is."},
	"captions": {"label": "Captions", "per": "video", "needs": [], "runs": "download", "env": ["ytdlp_venv"],
		"outputs": [], "settings": [], "version": 1,
		"blurb": "Fetches the automatic captions of a folder video from the link added for its captions, matched by title. A linked video's come with it."},
	"probe": {"label": "Probe", "per": "video", "needs": ["fetch"], "runs": "probe", "env": ["ffmpeg"],
		"outputs": ["probe.json"], "settings": [], "version": 1,
		"blurb": "Reads each video's length, frame rate and size, and finds its captions."},
	"survey": {"label": "Survey", "per": "video", "needs": ["probe"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["survey.bin"], "settings": ["survey_interval"], "version": 1,
		"blurb": "Looks at every video a few times a second: their face, its turn and its 52 expressions, their body and hands, and a small picture of the room. About a quarter of the video's own length. Everything after it is made from what it saw."},
	"shots": {"label": "Shots", "per": "video", "needs": ["survey"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["shots.json"], "settings": ["shortest_shot"], "version": 1,
		"blurb": "Finds each video's cuts, each placed on its exact frame; shots shorter than the shortest shot are dropped."},
	"words": {"label": "Words", "per": "video", "needs": ["probe", "captions"], "runs": "local", "env": [],
		"outputs": ["words.json"], "settings": [], "version": 1,
		"blurb": "Reads each video's automatic captions into words with their times - what they said, and when."},
	"sets": {"label": "Sets", "per": "actor", "needs": ["shots"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["sets.json"], "settings": ["set_threshold"], "version": 1,
		"blurb": "Groups the shots of every ticked video into sets: one camera placement each, judged by the room's edges so the sun moving on a wall keeps a set whole. Makes the contact sheets the audit looks at."},
	"audit": {"label": "Audit", "per": "actor", "needs": ["sets"], "runs": "agent", "env": [],
		"outputs": ["audit.json"], "settings": [], "version": 1,
		"blurb": "A writer looks at each set's contact sheets: their look in words, a shot in another look split off, and the shots that cannot be used (an insert, another person, a phone or a hand over their face)."},
	"visemes": {"label": "Visemes", "per": "actor", "needs": ["audit", "words"], "runs": "python", "env": ["face_venv"],
		"outputs": ["visemes.json"], "settings": [], "version": 2,
		"blurb": "Their mouth for each sound, from every video: from the captions' words turned into sounds, where they give enough of a sound, else from their own range."},
	"motion": {"label": "Motion", "per": "actor", "needs": ["audit"], "runs": "python", "env": ["face_venv"],
		"outputs": ["motion.json"], "settings": [], "version": 1,
		"blurb": "Their head's own motion wherever they face the camera, from every video - its slow drift taken out - and how often they blink: what moves the still, played back in pieces."},
	"stills": {"label": "Stills", "per": "set", "needs": ["audit"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["stills.json", "stills"], "settings": [], "version": 1,
		"blurb": "The set's most typical calm moments: facing the camera, eyes open, mouth closed, hands at rest, nothing in front of them, sharp. The Likeness is drawn on one of them; the card shows the others to pick from."},
	"rig": {"label": "Rig", "per": "set", "needs": ["stills"], "runs": "python", "env": ["face_venv"],
		"outputs": ["rig.json", "mask_mouth.png", "mask_eyes.png"], "settings": [], "version": 2,
		"blurb": "The mesh on the still: their face, the rings round it out to the frame's edge, and the masks where their mouth and eyes are drawn."},
	"library": {"label": "Library", "per": "set", "needs": ["rig", "visemes"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["library.json", "library"], "settings": ["articulation"], "version": 1,
		"blurb": "A few clean real mouths for each sound and their eyes half and fully closed, from any video, turned as the still is - each a real frame, never an average. A few minutes."},
}

## THE SETTINGS an actor is built under, on the card's Advanced fold: each a row, as a layer's FIELDS
## are (`label`, `type`, `default`, `min`, `max`, `step`, `blurb`).
const SETTINGS := {
	"survey_interval": {"label": "Survey every", "type": "float", "default": 0.2, "min": 0.1, "max": 1.0, "step": 0.05,
		"blurb": "Seconds between the survey's looks: enough to find cuts and sets, their range of mouth shapes and their head's motion."},
	"shortest_shot": {"label": "Shortest shot", "type": "float", "default": 3.0, "min": 1.0, "max": 20.0, "step": 0.5,
		"blurb": "Seconds: a jump cut shorter than this is dropped."},
	"set_threshold": {"label": "Set likeness", "type": "float", "default": 0.55, "min": 0.1, "max": 2.0, "step": 0.05,
		"blurb": "How different two shots' rooms may be and still be one set. Lower splits more."},
	"articulation": {"label": "Articulation", "type": "float", "default": 2.0, "min": 1.0, "max": 3.0, "step": 0.1,
		"blurb": "How much clearer than their own each sound's mouth is: their mouth is mostly near closed while they talk, so their own shapes read as nothing on a still. 1 is as they are."},
}

## The order steps are made in.
const ORDER := ["fetch", "captions", "probe", "survey", "shots", "words", "sets", "audit", "visemes", "motion",
	"stills", "rig", "library"]

## WHAT THE LIKENESS NEEDS OF AN ACTOR TO PLAY THEM: the chosen set's steps and the actor's own.
const PLAYS := ["motion", "stills", "rig", "library"]


static func per(step: String) -> String:
	return String(Registry.field(REGISTRY, step, "per", "actor"))


static func needs(step: String) -> Array:
	return Registry.field(REGISTRY, step, "needs", []) as Array


static func outputs(step: String) -> Array:
	return Registry.field(REGISTRY, step, "outputs", []) as Array


## The steps made from [param step], directly or not, in order.
static func dependents(step: String) -> Array:
	var out: Array = []
	for s in ORDER:
		if s == step:
			continue
		var todo: Array = needs(s).duplicate()
		var seen := {}
		while not todo.is_empty():
			var n := String(todo.pop_back())
			if seen.has(n):
				continue
			seen[n] = true
			if n == step:
				out.append(s)
				break
			todo.append_array(needs(n))
	return out


## [param step] and every step it is made from, in order: what ▶ on its row makes.
static func with_needs(step: String) -> Array:
	var want := {step: true}
	var todo: Array = [step]
	while not todo.is_empty():
		for n in needs(String(todo.pop_back())):
			if not want.has(n):
				want[n] = true
				todo.append(n)
	return ORDER.filter(func(s: String) -> bool: return want.has(s))


## The settings a [param stored] block holds, every one there: its own values where it has them and
## they are sound, the defaults elsewhere.
static func settings_of(stored: Variant) -> Dictionary:
	var out := {}
	var d: Dictionary = stored if stored is Dictionary else {}
	for k in SETTINGS:
		var row: Dictionary = SETTINGS[k]
		var v: Variant = d.get(k, row["default"])
		if not (v is float or v is int):
			v = row["default"]
		var f := clampf(float(v), float(row["min"]), float(row["max"]))
		out[k] = int(round(f)) if String(row["type"]) == "int" else f
	return out

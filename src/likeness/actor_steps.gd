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
##             (ghost itself), "agent" (a writer shown pictures) or "train" (on the graphics card,
##             hosts/voice_train/train.py - a lane of its own, beside the processor's)
##   env       what it runs on that ghost installs, as [Deps] keys
##   voice     a step of their own voice (next/likeness.md, "Their own voice"): on a machine that cannot
##             train one ([method ActorBuilder.cannot_train]) it is left alone and its row says why
##   renderer  the one renderer it is made for ([constant RENDERERS]), absent when both play from it: the
##             Actor card shows and makes the note's renderer's steps alone
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

	"sets": {"label": "Sets", "per": "actor", "needs": ["shots"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["sets.json"], "settings": ["set_threshold"], "version": 1,
		"blurb": "Groups the shots of every ticked video into sets: one camera placement each, judged by the room's edges so the sun moving on a wall keeps a set whole. Makes the contact sheets the audit looks at."},
	"audit": {"label": "Audit", "per": "actor", "needs": ["sets"], "runs": "agent", "env": [],
		"outputs": ["audit.json"], "settings": [], "version": 1,
		"blurb": "A writer looks at each set's contact sheets: their look in words, a shot in another look split off, and the shots that cannot be used (an insert, another person, a phone or a hand over their face)."},
	"transcribe": {"label": "Transcribe", "per": "video", "needs": ["probe", "audit"], "runs": "python",
		"env": ["ffmpeg", "speech_venv"], "outputs": ["transcript.json"], "settings": ["listen_minutes"], "version": 1,
		"blurb": "Listens to a video with no captions - its usable stretches, at most the Listen setting's minutes - and writes what they say and when, word by word (Whisper, on this computer). About a seventh of the time it hears."},
	"words": {"label": "Words", "per": "video", "needs": ["probe", "captions", "transcribe"], "runs": "local", "env": [],
		"outputs": ["words.json"], "settings": [], "version": 2,
		"blurb": "Each video's words with their times - what they said, and when: from its captions, or from what Transcribe heard."},
	"visemes": {"label": "Visemes", "per": "actor", "needs": ["audit", "words"], "runs": "python", "env": ["face_venv"],
		"outputs": ["visemes.json"], "settings": [], "version": 2,
		"blurb": "Their mouth for each sound, from every video: from the captions' words turned into sounds, where they give enough of a sound, else from their own range."},
	"learn": {"label": "Learn", "per": "actor", "needs": ["audit", "words"], "runs": "python", "env": ["face_venv"],
		"outputs": ["mouth_model.json"], "settings": [], "version": 1, "renderer": "2d",
		"blurb": "Learns their mouth for the voice's sounds from every video: an ensemble of small networks, from the sounds heard round a moment to their mouth then, trained on every look near their words - and says how much of their mouth it explains on a video it never saw. A minute or two."},
	"motion": {"label": "Motion", "per": "actor", "needs": ["audit"], "runs": "python", "env": ["face_venv"],
		"outputs": ["motion.json"], "settings": [], "version": 3,
		"blurb": "Their own motion wherever they face the camera, from every video - the head's quick turns on the shoulders, played back in pieces; their posture, how far and which ways their body settles and how long it holds; and how often they blink."},
	"stills": {"label": "Stills", "per": "set", "needs": ["audit"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["stills.json", "stills"], "settings": [], "version": 3,
		"blurb": "The set's most typical calm moments: facing the camera, eyes open, mouth closed, nothing in front of them, sharp - each with its matte and the room behind them, made from the set's frames, and all of them on one sheet for At rest. The Likeness is drawn on one of them; the card shows the others to pick from."},
	"rest": {"label": "At rest", "per": "set", "needs": ["stills"], "runs": "agent", "env": [],
		"outputs": ["rest.json"], "settings": [], "version": 1,
		"blurb": "A writer looks at the set's stills and says which show them at ease - hands folded, resting or out of sight, nothing held, facing the camera - most at ease first. The Likeness is drawn on the first unless another is picked: their hands and how they sit are held for the whole reading."},
	"rig": {"label": "Rig", "per": "set", "needs": ["stills"], "runs": "python", "env": ["face_venv"],
		"outputs": ["rig.json", "mask_mouth.png", "mask_eyes.png"], "settings": [], "version": 4,
		"blurb": "The mesh on each still and its skeleton: their face, the rings round it, their body from their pose and silhouette - the torso, the shoulders, each arm's upper arm, forearm and hand - the frame's edge, each vertex weighed to the bones it moves with; and the masks where their mouth and eyes are drawn."},
	"library": {"label": "Library", "per": "set", "needs": ["rig", "visemes"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["library.json", "library"], "settings": ["articulation"], "version": 2, "renderer": "2d",
		"blurb": "A few clean real mouths for each sound and their eyes half and fully closed and glancing aside, from any video, turned as the still is, matched to the still's colors - each a real frame, never an average. A few minutes."},

	"hear": {"label": "Hear", "per": "video", "needs": ["probe"], "runs": "python", "env": ["ffmpeg", "speech_venv"],
		"outputs": ["speech.json"], "settings": [], "version": 1, "voice": true,
		"blurb": "Listens to the whole of each video for their voice: every word they say and when, their ums and uhs too (Whisper, on this computer). About a seventh of the video's own length."},
	"utterances": {"label": "Utterances", "per": "actor", "needs": ["hear"], "runs": "python",
		"env": ["ffmpeg", "voice_venv", "voice_train_venv"], "outputs": ["utterances.json", "utterances"], "settings": [],
		"version": 1, "voice": true,
		"blurb": "Cuts their speech into the sentences their voice is taught on: each between pauses, cut in the quiet, every word heard surely and nothing heard that the words lack, spoken rather than whispered, all at one level - and holds a few back to measure it by."},
	"voice": {"label": "Voice", "per": "actor", "needs": ["utterances"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["voice.json", "voice"], "settings": ["voice_epochs"], "version": 1, "voice": true,
		"blurb": "Teaches a voice to speak as they do: a public-domain voice fine-tuned on their sentences on the graphics card - an hour or more, beside the other steps - then offered on the Voice card under their name. Stop keeps what it has learned, and ▶ goes on from there."},

	# A HEAD OF SPLATS (next/likeness.md, "A head of splats"): the set's frames, the face they show, and the
	# head learned from them
	"frames": {"label": "Frames", "per": "set", "needs": ["stills"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["avatar/frames.npz", "avatar/img", "avatar/mask"], "settings": [], "version": 1, "renderer": "gaussian",
		"blurb": "Reads the set's longest shot twice a second at full resolution, cropped round their head: their face's points and expressions in every frame, and where they are. About a third of the shot's length."},
	"face": {"label": "Face rig", "per": "set", "needs": ["frames"], "runs": "python", "env": ["face_venv"],
		"outputs": ["avatar/rig.npz", "avatar/poses.json"], "settings": [], "version": 1, "renderer": "gaussian",
		"blurb": "Learns their face from the frames: their neutral face, each frame's head pose, and how each of MediaPipe's 52 expressions moves every point of it - what the head is played from. Seconds."},
	"avatar": {"label": "Avatar", "per": "set", "needs": ["face"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["avatar/avatar.json", "avatar/avatar.bin"], "settings": ["avatar_steps"], "version": 1,
		"renderer": "gaussian",
		"blurb": "Learns their head as Gaussian splats bound to their face, from the frames, on the graphics card: hair, beard and skin as they look, moved by their face's expressions. Twenty minutes or so."},
}

## THE RENDERERS an actor is played with (the note's `renderer`): what each needs of an actor to play them.
const RENDERERS := {
	"2d": {"label": "2D", "plays": ["motion", "stills", "rig", "library"],
		"blurb": "Their still, warped: the head turned through its points, the mouth and eyes drawn from real frames of theirs for each sound."},
	"gaussian": {"label": "Gaussian", "plays": ["motion", "visemes", "stills", "rig", "avatar"],
		"blurb": "Their head as 3D Gaussian splats learned from the set's frames, moved by their face's expressions - their body and room the still's."},
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
	"listen_minutes": {"label": "Listen", "type": "float", "default": 20.0, "min": 2.0, "max": 120.0, "step": 1.0,
		"blurb": "The most minutes of each video Transcribe listens to (where it has no captions): enough of their speech to learn their mouth for every sound."},
	"articulation": {"label": "Articulation", "type": "float", "default": 2.0, "min": 1.0, "max": 3.0, "step": 0.1,
		"blurb": "How much clearer than their own each sound's mouth is: their mouth is mostly near closed while they talk, so their own shapes read as nothing on a still. 1 is as they are. Both renderers play it: the 2D library's mouths, the head of splats' sounds."},
	"voice_epochs": {"label": "Voice lessons", "type": "int", "default": 150, "min": 20, "max": 1000, "step": 10,
		"blurb": "How many times their voice hears every sentence of theirs while it learns. More is closer to them and longer on the graphics card (about 25 seconds each, an hour of their speech); raised after it is made, ▶ goes on from where it stopped."},
	"avatar_steps": {"label": "Avatar steps", "type": "int", "default": 30000, "min": 3000, "max": 100000, "step": 1000,
		"renderer": "gaussian",
		"blurb": "How many frames the head of splats is shown while it learns, one at a time: more is sharper and longer on the graphics card (about 40 ms each)."},
}

## The order steps are made in.
const ORDER := ["fetch", "captions", "probe", "survey", "shots", "sets", "audit", "transcribe", "words", "visemes",
	"learn", "motion", "stills", "rest", "rig", "library", "frames", "face", "avatar", "hear", "utterances", "voice"]


## WHAT [param renderer] NEEDS OF AN ACTOR TO PLAY THEM: the chosen set's steps and the actor's own.
static func plays(renderer: String) -> Array:
	return Registry.field(RENDERERS, renderer if RENDERERS.has(renderer) else "2d", "plays", []) as Array


## The renderer [param step] is made for, "" when every renderer plays from it.
static func renderer_of(step: String) -> String:
	return String(Registry.field(REGISTRY, step, "renderer", ""))


## Is [param step] one [param renderer] is played from, or made from?
static func serves(step: String, renderer: String) -> bool:
	var r := renderer_of(step)
	return r.is_empty() or r == renderer


## Is [param setting] one of [param renderer]'s (or every renderer's)?
static func setting_serves(setting: String, renderer: String) -> bool:
	var r := String(Registry.field(SETTINGS, setting, "renderer", ""))
	return r.is_empty() or r == renderer


## Is [param step] taught on the graphics card, or made only for one that is - their voice, a head of splats?
static func trains(step: String) -> bool:
	return is_voice(step) or renderer_of(step) == "gaussian"


static func per(step: String) -> String:
	return String(Registry.field(REGISTRY, step, "per", "actor"))


## Is [param step] one of their own voice's?
static func is_voice(step: String) -> bool:
	return bool(Registry.field(REGISTRY, step, "voice", false))


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

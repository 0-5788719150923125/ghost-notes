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
		"outputs": ["motion.json"], "settings": [], "version": 4,
		"blurb": "Their own motion wherever they face the camera, from every video - the head's quick turns on the shoulders and their face's slow changes with it (brows, lids, cheeks, the mouth's corners), played back in pieces; their posture, how far and which ways their body settles and how long it holds; and how often they blink."},
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
		"version": 2, "voice": true,
		"blurb": "Cuts their speech into the sentences their voice is taught on: each between pauses, cut in the quiet, every word heard surely and nothing heard that the words lack, spoken rather than whispered, all at one level - and keeps ONE VOICE of them, measured: clean, paced as speech, in their usual register, not breathy, from one recording setup, each sentence once. Holds a few back to measure it by."},
	"voice": {"label": "Voice", "per": "actor", "needs": ["utterances"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["voice.json", "voice"], "settings": ["voice_steps"], "version": 1, "voice": true,
		"blurb": "Teaches a voice to speak as they do: a public-domain voice fine-tuned on their sentences on the graphics card - an hour or more, beside the other steps - then offered on the Voice card under their name. Stop keeps what it has learned, and ▶ goes on from there."},

	# ONE HEAD FOR EVERY SET (next/likeness.md, "One head"): each video's moments, their face from all of them,
	# and their head learned from every video at once
	"head_frames": {"label": "Head frames", "per": "video", "needs": ["survey", "audit"], "runs": "python",
		"env": ["ffmpeg", "face_venv"], "outputs": ["head/frames.npz", "head/img", "head/mask"], "settings": [],
		"version": 1, "renderer": "gaussian",
		"blurb": "Reads moments of the video picked from its survey: half for what they show - an open mouth, a pucker, a turned head, their whole range - and half spread through it; their face, body and where they are in each. Two or three minutes a video."},
	"head_rig": {"label": "Head rig", "per": "actor", "needs": ["head_frames"], "runs": "python", "env": ["face_venv"],
		"outputs": ["head/rig.npz", "head/poses.json"], "settings": [], "version": 2, "renderer": "gaussian",
		"blurb": "Learns their face from every video's moments: one neutral face, how MediaPipe's 52 expressions move it - each only its own part of the face, the eyes, the brows or the mouth - each moment's head pose and their body's bones. Seconds."},
	"head": {"label": "Head", "per": "actor", "needs": ["head_rig"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["head/head.npz"], "settings": ["head_videos", "head_steps"], "version": 3, "renderer": "gaussian",
		"blurb": "Learns their head as Gaussian splats from their videos at once - the Head videos with the most of them facing the camera, each its Head steps - on the graphics card: hair, beard and skin as they look, moved by their face's expressions, and each video's look - its light, the little that differs - learned beside it. Under two hours."},

	# A SET'S AVATAR (next/likeness.md, "A head of splats", "One head"): its moments, posed against their face,
	# their head baked as the set looks, and their body fitted to its still
	"frames": {"label": "Frames", "per": "set", "needs": ["stills"], "runs": "python", "env": ["ffmpeg", "face_venv"],
		"outputs": ["avatar/frames.npz", "avatar/img", "avatar/mask"], "settings": [], "version": 2, "renderer": "gaussian",
		"blurb": "Reads moments of the set's shots and its stills, whole, at full resolution: their face's points and expressions and their body's pose in each, and where they are - the set's room, and how its stills stand. A minute or two."},
	"face": {"label": "Face rig", "per": "set", "needs": ["frames", "head_rig", "visemes"], "runs": "python",
		"env": ["face_venv"], "outputs": ["avatar/rig.npz", "avatar/poses.json"], "settings": [], "version": 3,
		"renderer": "gaussian",
		"blurb": "Poses the set's moments and its stills against their face (the Head rig's): each one's head pose and their body's bones - what they are played from - and their own mouth for each sound, from every video's moments. Seconds."},
	"avatar": {"label": "Avatar", "per": "set", "needs": ["face", "head"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["avatar/avatar.json", "avatar/avatar.bin"], "settings": [], "version": 6,
		"renderer": "gaussian",
		"blurb": "Makes the set's avatar from their head, on the graphics card: the head as learned from every video, in the set's own look and with its own mouth, with the set's room behind them as its moments show it and their body laid on its bones. A few minutes."},
	"fit": {"label": "Fit", "per": "set", "needs": ["avatar", "stills"], "runs": "train", "env": ["voice_train_venv"],
		"outputs": ["avatar/fit.json", "avatar/fit.bin"], "settings": [], "version": 4, "renderer": "gaussian",
		"blurb": "Fits them to the still they are played from, on the graphics card: the weave of their clothes, their hands, hair, ears, beard and neck as the still has them, where every frame together gave a blur - all but their lips and eyes, which move as every video taught them - held to the set's own moments, so nothing breaks as they move. Picking another still fits it again. A few minutes."},
}

## THE RENDERERS an actor is played with (the note's `renderer`): what each needs of an actor to play them.
const RENDERERS := {
	"2d": {"label": "2D", "plays": ["motion", "stills", "rig", "library"],
		"blurb": "Their still, warped: the head turned through its points, the mouth and eyes drawn from real frames of theirs for each sound."},
	"gaussian": {"label": "Gaussian", "plays": ["motion", "visemes", "stills", "rig", "avatar", "fit"],
		"blurb": "Them as 3D Gaussian splats: their head learned from every video at once, in the set's look, and their body fitted to the set's still - moved by their face's expressions and their body's bones - over the set's room."},
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
		"blurb": "How much clearer than their own each sound's mouth is: their mouth is mostly near closed while they talk, so their own shapes read as nothing on a still. 1 is as they are. Both renderers play it: the 2D library's mouths, the head of splats' sounds (never past their own 99th percentile of each score)."},
	"voice_steps": {"label": "Voice lessons", "type": "int", "default": 6000, "min": 1000, "max": 60000, "step": 500,
		"blurb": "How many lessons their voice is taught, each a batch of 16 of their sentences - however many sentences they gave. More is closer to them and longer on the graphics card (about half a second each: 6,000 is under an hour); raised after it is made, ▶ goes on from where it stopped."},
	"head_videos": {"label": "Head videos", "type": "int", "default": 10, "min": 1, "max": 200, "step": 1,
		"renderer": "gaussian",
		"blurb": "How many of their videos their head of splats learns from: those with the most of them facing the camera. More is their face in more lights and moods, and longer on the graphics card (Head steps each); a video it does not learn from takes their usual look."},
	"head_steps": {"label": "Head steps", "type": "int", "default": 6000, "min": 1000, "max": 30000, "step": 500,
		"renderer": "gaussian",
		"blurb": "How many moments of each Head video their head of splats is shown while it learns, one at a time: more is sharper and longer on the graphics card (about a tenth of a second each - 6,000 for each of 10 videos is under two hours)."},
}

## The order steps are made in.
const ORDER := ["fetch", "captions", "probe", "survey", "shots", "sets", "audit", "transcribe", "words", "visemes",
	"learn", "motion", "stills", "rest", "rig", "library", "head_frames", "head_rig", "head", "frames", "face", "avatar",
	"fit", "hear", "utterances", "voice"]


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

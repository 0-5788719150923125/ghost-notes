extends RefCounted
class_name ProofEpisode

## ProofEpisode - one episode of a Proof note, as it lies on disk (next/proof.md, "How an episode is
## made"). EVERY STEP IS A FILE under `user://proofs/<show>/<n>/`, written the moment it is made, as a
## card show's episodes are ([CardEpisode]): re-opening an episode re-uses what it made, a ghost that
## quit half way picks up where it stopped, and REDOING A STEP IS DELETING IT ([method invalidate]
## removes the step and everything made from it; the producer makes what is missing).
##
##   problem   problem.json  the framer's: the problem fixed before anyone works on it - its words,
##                           its TeX, its exact Lean statement, the facts it may not cite, its history
##   solve     solve.json    the solver's session, ended: verified or not, and how many checks; beside
##                           it notebook.md (its lab notebook) and proof.lean (its Lean file)
##   draft     draft.md      the teacher's first draft of the lesson
##   review    review.json   the student's notes on the draft: where it loses a newcomer, and what was
##                           needed there (`{notes: [{quote, need}]}`)
##   lesson    lesson.md     the teacher's, written again from the draft and the notes: what the voice
##                           says, with the pen's marks ([DeskScript])
##   ink       ink.json      ghost's own: every formula the pen writes, laid out by TeX
##   script    script.md     ghost's own: what the voice reads
##
## The job folders under `jobs/` keep every prompt as sent, beside the reply and every tool call
## ([AgentTools] writes `tools.jsonl`) - the record that the work shown is the work done.

const ROOT := "user://proofs"
## The steps, in the order an episode is made.
const STEPS := ["problem", "solve", "draft", "review", "lesson", "ink", "script"]
## What each step is made from.
const NEEDS := {"problem": [], "solve": ["problem"], "draft": ["solve"], "review": ["draft"],
	"lesson": ["review"], "ink": ["lesson"], "script": ["ink"]}
## THE STEPS ON THE WAY TO A LESSON: made only for one. An episode whose lesson was written before
## there were drafts is not given one now (the producer passes them by while the lesson stands).
const DRAFTING := ["draft", "review"]

## Where episodes live. Moved aside under test, so a gate never touches the author's episodes.
static var root := ROOT
## How a deleted episode's folder is thrown away, when set: the gate's seam (see [CardEpisode]).
static var discard: Callable = Callable()

var show := ""
var number := 1
## Absolute.
var dir := ""


static func open(show_key: String, n: int) -> ProofEpisode:
	var e := ProofEpisode.new()
	e.show = show_key
	e.number = maxi(1, n)
	e.dir = ProjectSettings.globalize_path(root.path_join(show_key).path_join(str(e.number)))
	return e


## A note's key among the shows: its file's name, made safe ("Untitled" for none).
static func show_key_of(note_path: String) -> String:
	var base := note_path.get_file().get_basename().strip_edges()
	if base.is_empty():
		return "untitled"
	return base.to_lower().replace(" ", "-").validate_filename()


## Every episode of [param show_key], oldest first: `[{n, title}]` - its number, and its problem's
## title once it has one.
static func history(show_key: String) -> Array:
	var base := ProjectSettings.globalize_path(root.path_join(show_key))
	var out: Array = []
	if not DirAccess.dir_exists_absolute(base):
		return out
	for d in DirAccess.get_directories_at(base):
		if not String(d).is_valid_int():
			continue
		var ep := open(show_key, int(d))
		var p: Variant = ep.read_json("problem")
		out.append({"n": int(d), "title": str((p as Dictionary).get("episode_title", "")) if p is Dictionary else ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) < int(b["n"]))
	return out


## The hand's seed: one per episode, so its formulas are written the same every time it is played.
var seed: int:
	get:
		return absi(hash(["proof-episode", show, number])) % 2147483647


# --- files ----------------------------------------------------------------------------------

func file_of(step: String) -> String:
	match step:
		"problem":
			return dir.path_join("problem.json")
		"solve":
			return dir.path_join("solve.json")
		"notebook":
			return dir.path_join("notebook.md")
		"proof":
			return dir.path_join("proof.lean")
		"draft":
			return dir.path_join("draft.md")
		"review":
			return dir.path_join("review.json")
		"lesson":
			return dir.path_join("lesson.md")
		"ink":
			return dir.path_join("ink.json")
		"script":
			return dir.path_join("script.md")
	return ""


## A step exists when its file does: every write lands by rename, so a file that is there is whole.
func has(step: String) -> bool:
	var p := file_of(step)
	return not p.is_empty() and FileAccess.file_exists(p)


func needs(step: String) -> Array:
	return NEEDS.get(step, [])


## A step there is no need to make: one on the way to a lesson ([constant DRAFTING]) while the lesson
## stands - an episode written before there were drafts is not drafted again behind its lesson.
func moot(step: String) -> bool:
	return DRAFTING.has(step) and has("lesson")


## The steps made from [param step], directly or through others, in order.
func dependents(step: String) -> Array:
	var out: Array = []
	for s in STEPS:
		var reach := false
		for need in _closure(String(s)):
			if need == step:
				reach = true
		if reach:
			out.append(s)
	return out


func _closure(step: String) -> Array:
	var out: Array = []
	var todo: Array = (NEEDS.get(step, []) as Array).duplicate()
	while not todo.is_empty():
		var s := String(todo.pop_front())
		if out.has(s):
			continue
		out.append(s)
		todo.append_array(NEEDS.get(s, []))
	return out


## REDO IS DELETE: [param step] and everything made from it are removed (the solver's notebook and
## Lean file go with its step), and the producer makes them again.
func invalidate(step: String) -> void:
	for s in [step] + dependents(step):
		DirAccess.remove_absolute(file_of(String(s)))
		if s == "solve":
			DirAccess.remove_absolute(file_of("notebook"))
			DirAccess.remove_absolute(file_of("proof"))


## The folder a step's agent job runs in - kept, with its prompt.
func job_dir(step: String) -> String:
	return dir.path_join("jobs").path_join(step)


func read_json(step: String) -> Variant:
	var raw := FileAccess.get_file_as_string(file_of(step))
	if raw.is_empty():
		return null
	var j := JSON.new()
	return j.data if j.parse(raw) == OK else null


func read_text(step: String) -> String:
	var p := file_of(step)
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


## Written ATOMICALLY: a file that exists is a step that is done, so a half-written one is never seen.
func write_text(step: String, text: String) -> String:
	var p := file_of(step)
	if p.is_empty():
		return "no file for the step %s" % step
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var tmp := p + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not write " + p
	f.store_string(text)
	f.close()
	if DirAccess.rename_absolute(tmp, p) != OK:
		return "could not move %s into place" % p
	return ""


func write_json(step: String, value: Variant) -> String:
	return write_text(step, JSON.stringify(value, "\t"))


## What the voice reads: the script, "" before it is made.
func script() -> String:
	return read_text("script")


## WHAT THE DESK DRAWS FROM ([DeskMedium]): the folder, the hand's seed, and every formula as TeX
## laid it out. Plain data, so the reading's document can carry it.
func document() -> Dictionary:
	var ink: Variant = read_json("ink")
	return {"dir": dir, "seed": seed, "ink": ink if ink is Dictionary else {}}


## How long each formula takes the pen to write (id -> seconds), from the ink - what the voice's rests
## are sized from ([method DeskScript.parse]), measured exactly as the desk will write them.
func lengths() -> Dictionary:
	var out := {}
	var ink: Variant = read_json("ink")
	if not (ink is Dictionary):
		return out
	var outlines: Dictionary = (ink as Dictionary).get("fonts", {}) if (ink as Dictionary).get("fonts") is Dictionary else {}
	for r in (ink as Dictionary).get("items", []):
		if r is Dictionary and bool((r as Dictionary).get("ok", false)):
			var got := Ink.strokes_of(r, seed, outlines)
			out[String((r as Dictionary)["id"])] = float(Ink.schedule(got["strokes"], seed)["length"])
	return out


## Every formula as TeX laid it out, by item id: what the pad's layout - and so where a page turns,
## a rest the voice takes - is made from ([method DeskScript.lay_out]).
func sizes() -> Dictionary:
	var out := {}
	var ink: Variant = read_json("ink")
	if ink is Dictionary:
		for r in (ink as Dictionary).get("items", []):
			if r is Dictionary and bool((r as Dictionary).get("ok", false)):
				out[String((r as Dictionary)["id"])] = r
	return out


## Throw the episode away: the system trash, or the gate's [member discard].
func trash() -> String:
	if discard.is_valid():
		discard.call(dir)
		return ""
	if not DirAccess.dir_exists_absolute(dir):
		return ""
	return "" if OS.move_to_trash(dir) == OK else "could not move %s to the trash" % dir

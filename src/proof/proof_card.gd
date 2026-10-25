extends VBoxContainer
class_name ProofCard

## ProofCard - the Proof component's card: a ghost doing math at a desk (next/proof.md).
##
## THE NOTE IS THE PROBLEM. Its words are what the agents work from - written by hand, or proposed by
## "Invent a problem" (the user, 2026-10-15: "a second button: to generate a random problem to solve
## ... I can just ask the agents to write one, then test it"), which writes them into the note where
## they can be edited - or worked over by "Refine" (the user, 2026-10-16: "I want the agents to look at
## what I've written in the script, and give in a more fully fleshed-out structure there"), which
## writes the note back whole, the problem defined. An EPISODE is one go at the note, made by agents
## step by step and kept on disk ([ProofEpisode], [ProofProducer]): the problem fixed, solved at the
## desk with Lean, taught. What they make is then read by the note's voice at the desk
## ([DeskMedium]), which this card pins.
##
## A CARD ON THE READING, as Cards' is ([EpisodeCard]): built by [NoteCards] from the `proof` row, it
## HANDS the reading what is read ([ProofWalk]: the episode's lesson, never the note) and how it goes
## out ([ProofCard.Publish]: the episode's title, and the desk's document).
##
## GENERATION IS EXPLICIT: Make episode makes the episode, and once anything of it is made it is
## REMAKE EPISODE - everything made again from the note, after asking (the user, 2026-10-16: "There is
## also no way to entirely remake one ... 'Make Episode' should probably just regenerate the entire
## thing"). A step's ⟳ deletes it (and what was made from it) and makes it again - on a step that failed
## or was never made, it goes on from there. New episode starts another; DELETE… throws the picked
## one away, after asking, to the system trash ("There is currently no way to delete an episode").
## Nothing runs on open. While a take of an episode renders, it is pinned ([member _taking]): neither
## deleted nor remade under it.
##
## THE NOTE'S OTHER CARDS ADD STEPS OF THEIR OWN ([EpisodeStep]), as on Cards' card: the ones wanted
## now are rows under the Script - the YouTube card's tags - each handed the episode as a [Feed], made
## once the episode's own steps are done, and made again on its ⟳. This card never asks what one is.
##
## THE NOTE'S TAGS ARE ONE LIST (the user, 2026-10-19: "I never know which tags are truly going to be
## applied"): its `tags:` line, shown on the YouTube card ([method youtube_built]) and taken whole by
## every upload. A note with none takes the framer's, once ([method _seed_tags]), as a card show takes
## its producer's; a step that writes an episode's tags writes over it ([method Feed.replace_tags]).

const YouTube := preload("res://src/export/youtube.gd")
const TagField := preload("res://src/ui/tag_field.gd")

const KEY := "proof"
## NO MINUTES (the user, 2026-10-16: "I would prefer to just make videos as long as they need to be"):
## a lesson runs as long as its proof takes to teach ([ProofPrompts]).
const KNOBS := {"episode": 1, "writer": "claude", "writer_model": "", "writer_effort": ""}
## THE AGENTS THAT WRITE THE NOTE'S WORDS, one at a time: its button's job, who it is in the status,
## what the card says while it works and once its words are in.
const NOTE_WRITERS := {
	"invent": {"label": "proof invent", "dir": "invented", "who": "The inventor",
		"busy": "Inventing a problem…", "done": "A new problem is in the note"},
	"refine": {"label": "proof refine", "dir": "refined", "who": "The refiner",
		"busy": "Refining the note…", "done": "The note is refined"},
}
## The rows of the episode list: a label, the step, who makes it, and what its ⟳ says.
const ROWS := [
	["Problem", "problem", "framer", "Fix the problem again from the note (clears everything after it)"],
	["Solve", "solve", "solver", "Work the problem again at the desk (clears the lesson)"],
	["Draft", "draft", "teacher", "Write the first draft again (clears the student's notes and the lesson)"],
	["Student", "review", "student", "Read the draft again as the viewer (clears the lesson)"],
	["Lesson", "lesson", "teacher", "Write the lesson again from the draft and the student's notes"],
	["Ink", "ink", "TeX", "Lay the formulas out again"],
	["Script", "script", "", ""],
]

var reading: ReadingPanel
var _doc: DocSource
var _text: TextEdit
var _knobs := KNOBS.duplicate(true)
var _episode: ProofEpisode = null
var _producer: ProofProducer = null
var _syncing := false
var _row_t := 0.0
var _script_seen := -1
var _taking := ""           # the folder of the episode a take is being rendered of, while it is
var _note_job := ""         # the job writing the note's words, if one is
var _note_job_by := ""      # its NOTE_WRITERS key

var _pick: OptionButton
var _picked: Array = []
var _invent_btn: Button
var _refine_btn: Button
var _make_btn: Button
var _stop_btn: Button
var _del_btn: Button
var _writer: AgentPick
var _youtube: YouTubeCard    # the note's YouTube card, once the reading has built it
var _tags_field: TagField     # the note's tags on it
var _rows := {}               # step -> {state: Label, redo: Button}
## The picked episode, as the steps other cards add to it read it ([method _tick_steps]).
var _feed: Feed = null
## Making was asked for: the steps other cards add are made once the episode's own are done.
var _steps_asked := false
var _step_box: VBoxContainer  # their rows, under the Script
var _step_rows := {}          # a step's key -> {step, state: Label, redo: Button}
var _rows_steps := ""         # the steps the rows were built for
var _note: Label


static func for_note(ctx: Dictionary) -> ProofCard:
	var card := ProofCard.new()
	card.serve(ctx.get("workspace") as ReadingPanel)
	return card


## SERVE [param panel]: hand it the episode's walk and publish, and build the card.
func serve(panel: ReadingPanel) -> void:
	add_theme_constant_override("separation", 8)
	reading = panel
	if reading == null:
		return
	_doc = reading.doc_source()
	_text = reading.source_box()
	reading.walk = ProofWalk.new(func() -> ProofEpisode: return _episode)
	reading.publish = Publish.new(self)
	reading.ready.connect(_open_episode, CONNECT_ONE_SHOT)
	_build()


## THE DESK IS THE MEDIUM, pinned while the card is up - before anything attaches (as the card table
## is for Cards; see Director.medium_override).
func _enter_tree() -> void:
	if reading != null:
		Director.medium_override = "desk"


func _exit_tree() -> void:
	if _producer != null:
		_producer.stop()
	_stop_steps(_feed)
	if _note_job != "":
		AgentJobs.cancel(_note_job)
		AgentJobs.forget(_note_job)
	if reading != null and Director.medium_override == "desk":
		Director.medium_override = ""


func _process(delta: float) -> void:
	if reading == null:
		return
	_row_t -= delta
	if _row_t > 0.0:
		return
	_row_t = 0.25
	if _producer != null:
		_producer.tick()
	_tick_steps()
	_poll_note_job()
	_seed_tags()
	_refresh_tags()
	_refresh()


# --- the block ----------------------------------------------------------------------------------

func capture() -> Dictionary:
	return _knobs.duplicate(true)


func apply(cfg: Dictionary) -> void:
	var was := int(_knobs["episode"])
	_knobs = KNOBS.duplicate(true)
	for k in KNOBS:
		if not cfg.has(k):
			continue
		match k:
			"episode":
				_knobs[k] = maxi(1, int(cfg[k]))
			"writer":
				_knobs[k] = String(cfg[k]) if TextGen.has(String(cfg[k])) else "claude"
			_:
				_knobs[k] = String(cfg[k])
	_show_knobs()
	if _episode == null or int(_knobs["episode"]) != was:
		_open_episode()


# --- what it hands the reading ---------------------------------------------------------------------

## HOW AN EPISODE GOES OUT, as a card show's does ([EpisodeCard.Publish]): named after the episode, the
## channel's name and byline over the desk while the intro holds, and its upload titled
## `%title%: %episode%` - the note's Title, then the name the framer gave the episode (the Script card's
## Episode, where it can be edited).
class Publish extends ReadingPublish:
	var card: ProofCard

	func _init(c: ProofCard) -> void:
		card = c

	func name() -> String:
		return card.export_name()

	# THE EPISODE IS PINNED while its take renders: Delete and Remake wait for it
	func before_take() -> bool:
		card._taking = card.current().dir if card.current() != null else ""
		return true

	func after_take(_path: String) -> String:
		card._taking = ""
		return ""

	func book(d: Dictionary, _body: String) -> Dictionary:
		var ep := card.current()
		d["desk"] = ep.document() if ep != null else {}
		d["title"] = card.show_title()
		d["byline"] = card.show_byline()
		return d

	func upload_base(take: String) -> Dictionary:
		return card.upload_base(take)

	func upload_values() -> Dictionary:
		return card.upload_values()

	func episode_title() -> Variant:
		var ep := card.current()
		return card.episode_title() if ep != null and ep.has("problem") else null

	func name_episode(title: String) -> String:
		return card.name_episode(title)

	func youtube_built(yt: YouTubeCard) -> void:
		card.youtube_built(yt)

	# its episodes say what they go up with, and list the other cards' steps themselves
	func note_is_episode() -> bool:
		return false


## THE EPISODE AS THE STEPS OTHER CARDS ADD TO IT READ IT ([EpisodeFeed]): its folder, the channel's
## name, the framer's title and description, the note's tags with the framer's (and a step's to write
## over the note's), the lesson as the voice reads it, and the note's writer.
class Feed extends EpisodeFeed:
	var card: ProofCard
	var episode: ProofEpisode

	func _init(c: ProofCard, ep: ProofEpisode) -> void:
		card = c
		episode = ep

	func _problem() -> Dictionary:
		var p: Variant = episode.read_json("problem")
		return p if p is Dictionary else {}

	func folder() -> String:
		return episode.dir

	func show_title() -> String:
		return card.show_title()

	func episode_title() -> String:
		return str(_problem().get("episode_title", "")).strip_edges()

	func description() -> String:
		return str(_problem().get("description", "")).strip_edges()

	func tags() -> PackedStringArray:
		var all := card._show_tags()
		for t in DataPath.strings(_problem().get("tags", [])):
			if not all.has(t):
				all.append(t)
		return all

	func replace_tags(tags: PackedStringArray) -> String:
		if card._doc == null or not card._doc.set_field("tags", ", ".join(tags)):
			return "the tags could not be written into the note"
		card._refresh_tags()
		return ""

	func words() -> String:
		return Manuscript.unspoken(episode.script()).strip_edges()

	func writer() -> Dictionary:
		return {"agent": String(card._knobs["writer"]), "model": String(card._knobs["writer_model"]),
			"effort": String(card._knobs["writer_effort"])}


func current() -> ProofEpisode:
	return _episode


## The episode's name, as the framer gave it - "" before the problem is fixed.
func episode_title() -> String:
	if _episode == null:
		return ""
	var p: Variant = _episode.read_json("problem")
	return str((p as Dictionary).get("episode_title", "")) if p is Dictionary else ""


## [param title] NAMES THE EPISODE from now on - the Script card's Episode, edited: written into its problem
## (the framer's), the rest kept, so its export, its entry in the list and %episode% follow. "" once
## written, else why not - an emptied title is not written (a video needs one).
func name_episode(title: String) -> String:
	var t := title.strip_edges()
	var p: Variant = _episode.read_json("problem") if _episode != null else null
	if not (p is Dictionary):
		return "The problem is not fixed yet - Make episode names the episode."
	if t.is_empty():
		return "An episode needs a title: it names the export and the video."
	if t == str((p as Dictionary).get("episode_title", "")).strip_edges():
		return ""
	(p as Dictionary)["episode_title"] = t
	var err := _episode.write_json("problem", p)
	if not err.is_empty():
		return "The title could not be saved into the episode's problem: " + err
	_refill()
	return ""


## THE CHANNEL'S NAME: the note's Title (its `title:` line), as a card show's is - on the title screen
## while the intro holds, and the YouTube title's %title%.
func show_title() -> String:
	return _doc.field("title").strip_edges() if _doc != null else ""


## A line under the channel's name on the title screen (the note's `byline:`).
func show_byline() -> String:
	return _doc.field("byline").strip_edges() if _doc != null else ""


## The note's own `tags:` line, as a card show's: every episode goes up with them.
func _show_tags() -> PackedStringArray:
	var out := PackedStringArray()
	for t in (_doc.field("tags") if _doc != null else "").split(",", false):
		if not String(t).strip_edges().is_empty():
			out.append(String(t).strip_edges())
	return out


## THE NOTE'S TAGS ON THE YOUTUBE CARD ([member YouTubeCard.extra]): its `tags:` line, as chips - the
## one list its uploads take.
func youtube_built(yt: YouTubeCard) -> void:
	_youtube = yt
	_tags_field = TagField.new()
	_tags_field.tooltip_text = ("The note's tags - its `tags:` line - the one list every episode goes up with. With "
		+ "\"Write each episode's tags\" ticked above, the writer replaces it with tags written for each episode. "
		+ "× removes one; type in the box and a comma (or Enter) makes it a tag. YouTube takes 500 characters "
		+ "of tags in all; a dimmed tag is past that.")
	_tags_field.changed.connect(_save_tags)
	yt.extra.add_child(_tags_field)
	_refresh_tags()


## The chips follow the note's line, unless they are being typed in.
func _refresh_tags() -> void:
	if _tags_field == null or _tags_field.typing():
		return
	var tags := _show_tags()
	if _tags_field.get_tags() != tags:
		_tags_field.set_tags(tags)
	_tags_field.mark(YouTube.left_out(tags))


## A chip added or removed: the note's `tags:` line, written at once.
func _save_tags() -> void:
	if _doc != null and not _doc.set_field("tags", ", ".join(_tags_field.get_tags())):
		_set_status("The tags could not be saved into the note.")
	_tags_field.mark(YouTube.left_out(_tags_field.get_tags()))


## A NOTE WITH NO TAGS YET TAKES THE FRAMER'S, once, as a card show takes its producer's: after that the
## list is the note's, edited on the YouTube card. Only with a YouTube card to show them, and never in a
## process that may not write (a probe).
func _seed_tags() -> void:
	if not Settings.is_read_only():
		_seed_from_problem()


func _seed_from_problem() -> void:
	if _tags_field == null or _tags_field.typing() or _episode == null or not _show_tags().is_empty() \
			or not _episode.has("problem"):
		return
	var p: Variant = _episode.read_json("problem")
	var tags := DataPath.strings((p as Dictionary).get("tags", [])) if p is Dictionary else PackedStringArray()
	if not tags.is_empty() and _doc.set_field("tags", ", ".join(tags)):
		_refresh_tags()


## AN EXPORT IS NAMED AFTER ITS EPISODE: the framer's name for it, or the note and the number while it
## has none.
func export_name() -> String:
	if _episode == null:
		return ""
	var t := episode_title()
	if not t.is_empty():
		return t
	var show := show_title()
	return "%s %d" % [show if not show.is_empty() else "Proof", _episode.number]


## THE LINE THE EPISODE'S TITLE GOES UP IN, which the framer is shown before it names one: the YouTube
## card's template (the default one with no card) with the channel's name in it and the episode's place
## marked ([method YouTube.title_shape]) - what Cards' producer is shown too.
func _uploads_as() -> String:
	return YouTube.title_shape(_youtube.template() if _youtube != null else YouTube.TITLE_TEMPLATE,
		{"title": show_title(), "seed": str(_episode.number) if _episode != null else ""})


## The YouTube title's macros as the card stands: the channel's name and this episode's.
func upload_values() -> Dictionary:
	return {"title": show_title(), "episode": episode_title(),
		"seed": str(_episode.number) if _episode != null else ""}


## THE UPLOAD: the episode's name in the title, the framer's description - and, said by the code from
## what Lean answered, whether the proof was checked and by what (never the agents' to claim) - the
## note's tags (the one list, as the YouTube card shows it), and THE THUMBNAIL's moment: the channel's
## name over the desk out of focus, as a card show's is ([method ShowOpening.thumbnail_moment], at the
## intro [param take] was rendered with). Without one the exporter takes none and YouTube picks a frame
## of its own (2026-10-16, the user: "did not use the proper thumbnail ... the same thumbnail that
## cards-based modes use"). {} before the episode has a name.
func upload_base(take: String) -> Dictionary:
	if _episode == null or episode_title().is_empty():
		return {}
	return upload_of(_episode, upload_values(), _show_tags(), ShowOpening.take_intro(take, Director.intro_hold))


## [method upload_base] for episode [param ep], with the title's macros [param values], the note's
## [param tags] and the [param intro] its take was rendered with. Static and pure for the gate.
static func upload_of(ep: ProofEpisode, values: Dictionary, tags: PackedStringArray, intro: float) -> Dictionary:
	var p: Dictionary = ep.read_json("problem") if ep.read_json("problem") is Dictionary else {}
	var s: Variant = ep.read_json("solve")
	var solve: Dictionary = s if s is Dictionary else {}
	var check := ""
	if bool(solve.get("verified", false)):
		check = ("The proof in this video was checked by the Lean theorem prover%s: every step, with no "
			+ "gaps and nothing assumed beyond Lean's standard axioms.") % (
			" (Lean %s, Mathlib %s)" % [solve["lean"], solve["mathlib"]] if not String(solve.get("lean", "")).is_empty() else "")
	elif bool(solve.get("computed", false)):
		check = ("The numbers and graphs in this video come from code that was run for it (Python, with NumPy, "
			+ "SciPy and SymPy). A computation shows what happens in the cases it ran; it is not a proof for "
			+ "every case.")
	elif not solve.is_empty():
		check = ("The computation for this episode did not settle the question, and the video says so."
			if ProofTools.kind_of(p) == "computation"
			else "The formal check in Lean did not finish for this episode, and the video says so.")
	var desc := String(p.get("description", "")).strip_edges()
	return {"values": values, "description": (desc + ("\n\n" + check if not check.is_empty() else "")).strip_edges(),
		"tags": Array(tags), "record": ep.dir.path_join("youtube.json"),
		"thumbnail_at": ShowOpening.thumbnail_moment(intro)}


# --- the episode ---------------------------------------------------------------------------------

func _show_key() -> String:
	return ProofEpisode.show_key_of(reading.note_path if reading != null else "")


func _open_episode() -> void:
	if reading == null:
		return
	if _producer != null:
		_producer.stop()
	_stop_steps(_feed)
	_episode = ProofEpisode.open(_show_key(), int(_knobs["episode"]))
	_feed = Feed.new(self, _episode)
	_producer = ProofProducer.new(_episode, {})
	_script_seen = -1
	_refill()
	_refresh()


func _refill() -> void:
	_syncing = true
	_pick.clear()
	_picked = []
	var have := ProofEpisode.history(_show_key())
	var nums: Array = []
	for h in have:
		nums.append(int((h as Dictionary)["n"]))
	if not nums.has(int(_knobs["episode"])):
		have.append({"n": int(_knobs["episode"]), "title": ""})
		have.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) < int(b["n"]))
	for h in have:
		var t := String((h as Dictionary)["title"])
		_pick.add_item("Episode %d%s" % [int(h["n"]), (" - " + t) if not t.is_empty() else ""])
		_picked.append(int(h["n"]))
		if int(h["n"]) == int(_knobs["episode"]):
			_pick.select(_pick.item_count - 1)
	_syncing = false


func _spec() -> Dictionary:
	# the channel's name, as the agents are told it: the note's Title, else the note's own name
	var title := show_title()
	if title.is_empty() and not reading.note_path.is_empty():
		title = NoteStore.title_of(reading.note_path)
	var before: Array = []
	for h in ProofEpisode.history(_show_key()):
		if int((h as Dictionary)["n"]) != int(_knobs["episode"]) and not String((h as Dictionary)["title"]).is_empty():
			before.append(String((h as Dictionary)["title"]))
	return {"title": title if not title.is_empty() else "Ghost Notes", "byline": show_byline(),
		"uploads_as": _uploads_as(), "before": before.slice(-20), "brief": _problem_text(),
		"writer": _knobs["writer"], "writer_model": _knobs["writer_model"],
		"writer_effort": _knobs["writer_effort"]}


## The note's words: the problem, as the author, the inventor or the refiner wrote it.
func _problem_text() -> String:
	return Manuscript.strip_frontmatter(_text.text if _text != null else "").strip_edges()


func _make() -> void:
	if _episode == null:
		return
	if _problem_text().is_empty():
		_set_status("Write a problem in the note first, or press Invent a problem.")
		return
	if not made_any(_episode):
		_start_making("Making")
		return
	if _taking == _episode.dir:
		_set_status("Episode %d is being exported - remake it once the export is done." % _episode.number)
		return
	_confirm("Remake episode", ("Remake episode %d%s from the note?\n\nEverything made for it - the problem, "
		+ "the work at the desk and its Lean check, the drafts, the lesson and its ink - is thrown away and "
		+ "made again. To redo only part of it, use the ⟳ on a step instead.") % [_episode.number,
		("  \"%s\"" % episode_title()) if not episode_title().is_empty() else ""], "Remake",
		_remake.bind(_episode))


## REMAKE [param ep] whole: whatever is making it stops, every step it made goes, and it is made again.
func _remake(ep: ProofEpisode) -> void:
	if ep == null or _episode == null or ep.dir != _episode.dir or _taking == ep.dir:
		return
	_producer.stop()
	_episode.invalidate("problem")
	reading.mark_stale()
	_start_making("Remaking")


func _start_making(verb: String) -> void:
	_producer.spec = _spec()
	_steps_asked = true
	_producer.start()
	_set_status("%s episode %d: the problem is fixed first, then solved at the desk with Lean, then taught."
		% [verb, _episode.number])


## Has anything of [param ep] been made - any step's file on disk?
static func made_any(ep: ProofEpisode) -> bool:
	for s in ProofEpisode.STEPS:
		if ep.has(String(s)):
			return true
	return FileAccess.file_exists(ep.file_of("notebook"))


## DELETE…: ask, then throw the picked episode away ([method _delete_episode]).
func _ask_delete() -> void:
	if _episode == null or not DirAccess.dir_exists_absolute(_episode.dir):
		return
	if _taking == _episode.dir:
		_set_status("Episode %d is being exported - delete it once the export is done." % _episode.number)
		return
	_confirm("Delete episode", ("Delete episode %d%s?\n\nIts problem, the work at the desk, the lesson, the "
		+ "ink and its upload notes go to the system trash (restore it from there). Exported videos and "
		+ "the note's other episodes are not touched.") % [_episode.number,
		("  \"%s\"" % episode_title()) if not episode_title().is_empty() else ""], "Delete",
		_delete_episode.bind(_episode))


## DELETE [param ep]: whatever is making it stops, a reading of it stops, its folder goes to the trash,
## and the card moves to the newest episode left ([method after_delete]).
func _delete_episode(ep: ProofEpisode) -> void:
	if ep == null or _taking == ep.dir:
		return
	var open := _episode != null and _episode.dir == ep.dir
	if open and _producer != null:
		_producer.stop()
	_stop_steps(Feed.new(self, ep))
	if open and reading.reading_live():
		reading.stop_speaking()
	var err := ep.trash()
	if not err.is_empty():
		_set_status("Could not delete episode %d: %s" % [ep.number, err])
		return
	print("ghost: proof - episode %s %d moved to the trash" % [ep.show, ep.number])
	if open:
		reading.mark_stale()
		_knobs["episode"] = after_delete(ProofEpisode.history(_show_key()))
		_touch()
		_open_episode()
	else:
		_refill()
	_set_status("Episode %d is in the system trash." % ep.number)


## The episode to open once one is deleted, given the [param left] ([method ProofEpisode.history]):
## the newest, else a first one, empty.
static func after_delete(left: Array) -> int:
	var n := 0
	for h in left:
		n = maxi(n, int((h as Dictionary)["n"]))
	return maxi(n, 1)


## A question before something is thrown away: [param ok] runs on yes.
func _confirm(title: String, text: String, yes: String, ok: Callable) -> void:
	var ask := ConfirmationDialog.new()
	ask.title = title
	ask.dialog_text = text
	ask.dialog_autowrap = true
	ask.ok_button_text = yes
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		ok.call())
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(520, 0))


func _new_episode() -> void:
	var top := 0
	for h in ProofEpisode.history(_show_key()):
		top = maxi(top, int((h as Dictionary)["n"]))
	if _episode != null and not _episode.has("problem"):
		_set_status("This episode has nothing made yet: Make episode fills it in.")
		return
	_knobs["episode"] = maxi(top, int(_knobs["episode"])) + 1
	_touch()
	_open_episode()


func _redo(step: String) -> void:
	if _episode == null:
		return
	if _taking == _episode.dir:
		_set_status("Episode %d is being exported - redo a step once the export is done." % _episode.number)
		return
	_producer.stop()
	_episode.invalidate(step)
	reading.mark_stale()
	_producer.spec = _spec()
	_steps_asked = true          # the steps after it: the other cards' too
	_producer.start()


# --- the steps the note's other cards add -------------------------------------------------------

## The steps the note's other cards add, all of them, as the panel holds them
## ([method ReadingPanel.episode_steps]).
func _offered() -> Array:
	return reading.episode_steps() if reading != null else []


## ...and the ones listed now, under the Script.
func _listed() -> Array:
	return EpisodeStep.listed_of(_offered())


## What the rows were built for: the listed steps' keys.
func _steps_key() -> String:
	return ",".join(PackedStringArray(_listed().map(func(s: EpisodeStep) -> String: return s.key)))


## This card as the steps' rows say where they are: "the Proof card".
static func host_name() -> String:
	return "the %s card" % String(Registry.field(Components.REGISTRY, KEY, "heading", "Proof"))


## EACH REFRESH: what the steps' jobs ended with, landed; the picked episode said to the steps listed;
## and once the episode's own steps are done, each listed step made - from its words, so only when they
## were written.
func _tick_steps() -> void:
	for s in _offered():
		(s as EpisodeStep).tick()
	var listed := _listed()
	for s in listed:
		(s as EpisodeStep).listed(host_name(), _feed)
	if _steps_asked and _producer != null and not (_producer.running or _producer.busy()):
		_steps_asked = false
		for s in listed:
			(s as EpisodeStep).generate(_feed)


## STOP what the steps are making of [param feed]'s episode - and, for the picked one, what making it asked
## of them.
func _stop_steps(feed: Feed) -> void:
	if feed == null or _feed == null or feed.folder() == _feed.folder():
		_steps_asked = false
	if feed == null:
		return
	for s in _offered():
		(s as EpisodeStep).stop(feed)


## Is a listed step being made for the picked episode?
func _steps_busy() -> bool:
	for s in _listed():
		if (s as EpisodeStep).busy(_feed):
			return true
	return false


## ⟳ on a step's row: made again now, from the episode's words - which must be written first.
func _redo_step(step: EpisodeStep) -> void:
	if not step.redo(_feed):
		_set_status("%s waits for the episode's words - Make episode writes them." % step.label)


## The steps' rows, under the Script, one per step listed: built again when the steps listed change.
func _build_step_rows() -> void:
	for c in _step_box.get_children():
		_step_box.remove_child(c)
		c.queue_free()
	_step_rows = {}
	for s in _listed():
		var step: EpisodeStep = s
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		_step_box.add_child(r)
		var name_l := Label.new()
		name_l.text = step.label
		name_l.custom_minimum_size.x = 64.0
		name_l.add_theme_font_size_override("font_size", 12)
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var redo := Button.new()
		redo.text = "⟳"
		redo.flat = true
		redo.pressed.connect(_redo_step.bind(step))
		r.add_child(redo)
		_step_rows[step.key] = {"step": step, "state": state, "redo": redo}
	_rows_steps = _steps_key()


## What each step's row says, as the episode's own rows do, and its ⟳ - offered once the episode's
## words are written and nothing is being made.
func _refresh_step_rows(busy: bool) -> void:
	if _steps_key() != _rows_steps:
		_build_step_rows()
	var words := _feed != null and not _feed.words().is_empty()
	for k in _step_rows:
		var r: Dictionary = _step_rows[k]
		var step: EpisodeStep = r["step"]
		var st := step.state(_feed)
		var lead := String({"ready": "✓", "running": "…", "queued": "…", "failed": "✗"}.get(st, "–"))
		var said := step.said(_feed)
		(r["state"] as Label).text = lead + (" " + said if not said.is_empty() else "")
		(r["state"] as Label).tooltip_text = (r["state"] as Label).text
		var made := not step.made(_feed).is_empty()
		(r["redo"] as Button).disabled = busy or not words
		(r["redo"] as Button).tooltip_text = (step.again if made else step.first) + (
			"" if words else " - once the episode's words are written")


# --- the note's words: "Invent a problem" and "Refine" ---------------------------------------

func _invent() -> void:
	var before: Array = []
	for h in ProofEpisode.history(_show_key()):
		var t := String((h as Dictionary)["title"])
		if not t.is_empty():
			before.append(t)
	_write_note("invent", ProofPrompts.inventor(int(Time.get_unix_time_from_system()) ^ randi(), before.slice(-12),
		ProofTools.can_run()))


## "Refine": the refiner reads the note as it stands and writes it back whole, the problem defined.
func _refine() -> void:
	if _problem_text().is_empty():
		_set_status("Write an idea in the note first - a line is enough - then press Refine.")
		return
	var s := _spec()
	_write_note("refine", ProofPrompts.refiner(String(s["title"]), String(s["brief"]), ProofTools.can_run()))


## Hands [param p] (`{system, prompt}`) to the writer as [param by]'s job ([constant NOTE_WRITERS]);
## its answer becomes the note's words ([method _poll_note_job]).
func _write_note(by: String, p: Dictionary) -> void:
	if _note_job != "":
		return
	var w: Dictionary = NOTE_WRITERS[by]
	var dir := ProjectSettings.globalize_path(ProofEpisode.root.path_join(_show_key())
		.path_join(String(w["dir"])).path_join(str(Time.get_unix_time_from_system()).replace(".", "_")))
	_note_job = AgentJobs.submit({"kind": "text", "backend": String(_knobs["writer"]), "tier": "best",
		"dir": dir, "system": String(p["system"]), "prompt": String(p["prompt"]),
		"label": String(w["label"]), "model": String(_knobs["writer_model"]),
		"effort": String(_knobs["writer_effort"])})
	if _note_job.is_empty():
		_set_status("⚠  This session cannot start agents.")
		return
	_note_job_by = by
	_set_status(String(w["busy"]))


func _poll_note_job() -> void:
	if _note_job.is_empty():
		return
	var st := AgentJobs.state(_note_job)
	if st != "done" and st != "failed":
		return
	var res := AgentJobs.result(_note_job)
	var w: Dictionary = NOTE_WRITERS[_note_job_by]
	AgentJobs.forget(_note_job)
	_note_job = ""
	if not bool(res.get("ok", false)):
		_set_status("⚠  %s stopped: %s" % [String(w["who"]), String(res.get("error", "its run failed"))])
		return
	var text := ProofProducer.clean_lesson(String(res.get("text", "")))
	if text.is_empty():
		_set_status("⚠  %s wrote nothing." % String(w["who"]))
		return
	# AN EDIT, NOT A REPLACEMENT: the note's own undo takes it back, and the autosave keeps it
	_text.select_all()
	_text.insert_text_at_caret(text + "\n")
	# an episode already framed was framed from the note as it was: the new words need a new one
	var then := ("New episode, then Make episode" if _episode != null and _episode.has("problem")
		else "Make episode")
	_set_status("%s - edit it if you like, then %s. Undo in the note brings back what was there."
		% [String(w["done"]), then])


# --- the card itself -----------------------------------------------------------------------------

func _build() -> void:
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 6)
	add_child(erow)
	_pick = OptionButton.new()
	_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick.fit_to_longest_item = false
	_pick.clip_text = true
	_pick.focus_mode = Control.FOCUS_NONE
	_pick.tooltip_text = "Every episode this note has made. Picking one loads it exactly as it was made."
	_pick.item_selected.connect(func(i: int) -> void:
		if _syncing or i < 0 or i >= _picked.size():
			return
		_knobs["episode"] = int(_picked[i])
		_touch()
		_open_episode())
	erow.add_child(_pick)
	var new_btn := Button.new()
	new_btn.text = "New episode"
	new_btn.tooltip_text = "Another go at the note: a fresh episode, made when you press Make episode."
	new_btn.pressed.connect(_new_episode)
	erow.add_child(new_btn)
	# THE PANEL IS 380 PX, DECLARED (SidePanel): Folder stands here, beside the episode it opens,
	# so the row of what to do fits - all four in one row asked for 374 px of a 380 px panel's room
	var folder := Button.new()
	folder.text = "Folder"
	folder.tooltip_text = "Open this episode's folder: every prompt as sent, every reply, every Lean check, the notebook and the proof."
	folder.pressed.connect(func() -> void:
		if _episode != null:
			DirAccess.make_dir_recursive_absolute(_episode.dir)
			OS.shell_open(_episode.dir))
	erow.add_child(folder)

	# THE NOTE'S WORDS, then the episode made from them: two rows, since the four buttons side by side
	# ask for 375 px of a 380 px panel (Invent clipped to "Invent a pr…")
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 6)
	add_child(wrow)
	_invent_btn = Button.new()
	_invent_btn.text = "Invent a problem"
	_invent_btn.tooltip_text = ("The writer proposes a classic problem from a field picked at random - one it "
		+ "can settle with a proof Lean checks, or (where code can run) a computation - and writes it into "
		+ "the note, replacing what is there (Undo in the note brings it back). Edit it as you like before "
		+ "making an episode.")
	_invent_btn.pressed.connect(_invent)
	_invent_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invent_btn.clip_text = true
	wrow.add_child(_invent_btn)
	_refine_btn = Button.new()
	_refine_btn.text = "Refine"
	_refine_btn.tooltip_text = ("The writer reads what you have written - a line of an idea is enough - and "
		+ "writes the note back whole: the problem defined, what the viewer learns, who it is for and what "
		+ "to show on the pad. Everything you asked for is kept. It replaces "
		+ "what is there (Undo in the note brings it back); press it again to refine further.")
	_refine_btn.pressed.connect(_refine)
	_refine_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refine_btn.clip_text = true
	wrow.add_child(_refine_btn)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 6)
	add_child(grow)
	_make_btn = Button.new()
	_make_btn.text = "Make episode"
	_make_btn.pressed.connect(_make)
	_make_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_btn.clip_text = true
	grow.add_child(_make_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.tooltip_text = "Stop making this episode. Whatever is finished is kept."
	_stop_btn.pressed.connect(func() -> void:
		if _producer != null:
			_producer.stop()
		_stop_steps(_feed))
	grow.add_child(_stop_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete…"
	_del_btn.tooltip_text = ("Delete the episode picked above: its problem, work, lesson, ink and upload notes "
		+ "go to the system trash (restore it from there). Exported videos and the note's other episodes "
		+ "are not touched.")
	_del_btn.pressed.connect(_ask_delete)
	grow.add_child(_del_btn)

	# WHO WRITES: the agent, its model and how hard it reasons - one row, built the way every card
	# that runs agents builds it ([AgentPick], Cards' own)
	_writer = AgentPick.writer(("Who frames the problem, solves it at the desk and teaches it, and who invents "
		+ "or refines a problem. The solver checks its work with tools, so the writer must be one that takes them "
		+ "(Claude, Codex or Grok). Takes effect at the next Make episode. There is no painter: the desk, "
		+ "what lies on it, the paper and the pen are built from shapes, picked anew for each episode."),
		"The model that writes. Default is the CLI's own choice per job; a model chosen here writes all of it.",
		("How hard the writer thinks before it writes - the CLI's own reasoning effort. Default is what "
		+ "each CLI does unasked. A level chosen here is used for every job. Higher is slower and spends "
		+ "more quota."))
	_writer.changed.connect(func() -> void:
		if _syncing:
			return
		var c := _writer.choice()
		_knobs["writer"] = String(c["agent"])
		_knobs["writer_model"] = String(c["model"])
		_knobs["writer_effort"] = String(c["effort"])
		_touch())
	add_child(_writer)

	for row in ROWS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		add_child(r)
		var name_l := Label.new()
		name_l.text = String(row[0])
		name_l.custom_minimum_size.x = 64.0
		name_l.add_theme_font_size_override("font_size", 12)
		r.add_child(name_l)
		var state := Label.new()
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.clip_text = true
		state.add_theme_font_size_override("font_size", 11)
		state.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(state)
		var redo := Button.new()
		redo.text = "⟳"
		redo.flat = true
		redo.tooltip_text = String(row[3])
		redo.visible = not String(row[3]).is_empty()
		var step := String(row[1])
		redo.pressed.connect(func() -> void: _redo(step))
		r.add_child(redo)
		_rows[step] = {"state": state, "redo": redo, "maker": String(row[2]), "again": String(row[3])}
	# THE STEPS THE NOTE'S OTHER CARDS ADD, under the Script ([method _build_step_rows])
	_step_box = VBoxContainer.new()
	add_child(_step_box)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 11)
	_note.modulate = Color(1, 1, 1, 0.7)
	add_child(_note)
	_show_knobs()


func _show_knobs() -> void:
	if _writer == null:
		return
	_syncing = true
	_writer.set_choice(String(_knobs["writer"]), String(_knobs["writer_model"]), String(_knobs["writer_effort"]))
	_syncing = false


func _refresh() -> void:
	if _episode == null or _producer == null:
		return
	var busy := _producer.running or _producer.busy() or _steps_asked or _steps_busy()
	var made := made_any(_episode)
	_make_btn.disabled = busy
	_make_btn.text = "Remake episode" if made else "Make episode"
	_make_btn.tooltip_text = (("Make this episode again from the note, whole: everything made for it is thrown "
		+ "away first (it asks). To redo only part of it, use the ⟳ on a step.") if made else
		("Make the episode, in order: the problem fixed from the note, the work at the desk - a proof checked "
		+ "in Lean, or a computation run in a sandbox - the lesson, and its formulas laid out by TeX. Spends "
		+ "the writer's quota. Lean, Mathlib and TeX are fetched the first time (about 11 GB), and the "
		+ "compute environment (about 220 MB) where code can run."))
	_stop_btn.disabled = not busy
	_del_btn.disabled = busy or not DirAccess.dir_exists_absolute(_episode.dir)
	_invent_btn.disabled = _note_job != ""
	_refine_btn.disabled = _note_job != ""
	var first_missing := ""
	for step in _rows:
		if _producer.state_of(String(step)) == "missing" and not _episode.moot(String(step)):
			first_missing = String(step)
			break
	for step in _rows:
		var r: Dictionary = _rows[step]
		var st := _producer.state_of(String(step))
		var said := ""
		match st:
			"ready":
				said = "✓ " + _ready_note(String(step))
			"running":
				said = "… " + _producer.activity_of(String(step))
			"queued":
				said = "… waiting its turn"
			"failed":
				said = "✗ " + _producer.error_of(String(step))
			_:
				said = "–"
		(r["state"] as Label).text = said
		(r["state"] as Label).tooltip_text = said
		# A STEP THAT FAILED, or the first one never made in an episode begun, goes on from there
		var go_on: bool = made and (st == "failed" or (st == "missing" and String(step) == first_missing))
		(r["redo"] as Button).disabled = busy or not (st == "ready" or go_on)
		(r["redo"] as Button).tooltip_text = String(r["again"]) if st == "ready" \
			else "Make this step and the ones after it - what is made before it is kept"
	_refresh_step_rows(busy)
	var line := ""
	if not _producer.waiting.is_empty():
		line = "Waiting: %s - Ghost Notes fetches these itself, once (see ⚙ for progress)." % _producer.waiting
	elif _episode.has("script"):
		line = "Ready: press Play to hear the lesson at the desk."
	_note.text = line
	# A NEW SCRIPT IS A NEW READING: what is on the stream was made from the old one
	var mt := FileAccess.get_modified_time(_episode.file_of("script")) if _episode.has("script") else 0
	if mt != _script_seen:
		if _script_seen >= 0:
			reading.mark_stale()
		_script_seen = mt


## What a ready step says of itself.
func _ready_note(step: String) -> String:
	match step:
		"problem":
			return episode_title()
		"solve":
			var s: Variant = _episode.read_json("solve")
			if s is Dictionary:
				var d := s as Dictionary
				var runs := int(d.get("runs", 0))
				if bool(d.get("computed", false)):
					return "computed (%d run%s)" % [runs, "" if runs == 1 else "s"]
				var p: Variant = _episode.read_json("problem")
				if ProofTools.kind_of(p if p is Dictionary else {}) == "computation":
					return "NOT computed (%d run%s)" % [runs, "" if runs == 1 else "s"]
				return ("verified in Lean (%d check%s)" if bool(d.get("verified", false))
					else "NOT verified (%d check%s)") % [int(d.get("checks", 0)),
					"" if int(d.get("checks", 0)) == 1 else "s"]
		"draft", "lesson":
			return _pad_note(_episode.read_text(step))
		"review":
			var r: Variant = _episode.read_json("review")
			var n := ((r as Dictionary).get("notes", []) as Array).size() if r is Dictionary else 0
			return "%d note%s" % [n, "" if n == 1 else "s"]
		"ink":
			var ink: Variant = _episode.read_json("ink")
			if ink is Dictionary:
				var ok := 0
				var all := 0
				for r in (ink as Dictionary).get("items", []):
					all += 1
					if bool((r as Dictionary).get("ok", false)):
						ok += 1
				return "%d of %d set" % [ok, all]
	return "made"


## What a lesson puts on the pad: its formulas and its drawings.
static func _pad_note(lesson: String) -> String:
	var drawn := 0
	var items := DeskScript.items(lesson)
	for it in items:
		if String((it as Dictionary)["mode"]) == "figure":
			drawn += 1
	return "%d formula%s and %d drawing%s on the pad" % [items.size() - drawn,
		"" if items.size() - drawn == 1 else "s", drawn, "" if drawn == 1 else "s"]


func _set_status(text: String) -> void:
	if reading != null:
		reading.status(text)


func _touch() -> void:
	if reading != null:
		reading.touch()

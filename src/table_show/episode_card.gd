extends VBoxContainer
class_name EpisodeCard

## EpisodeCard - the Table component's card (Cards until 2026-10-26): a show at a table nobody writes by
## hand - cards read, things made, or both. What it does there, and what the show is, are the brief's to say.
##
## A SHOW is a document: its title is the channel, its body is the BRIEF - what the show is,
## its voice, its rules - and its `ghost: table:` block holds the knobs and the reader's voice.
## An EPISODE is one seed of the show, produced by agents ([TableProducer]) step by step and
## kept on disk ([TableEpisode]): planned, shuffled, designed, painted, and read aloud one card
## at a time, in drawing order. What they write is then read by the note's voice, at the card
## table ([TableMedium]), which this card pins as the medium.
##
## A CARD ON THE READING, NOT A MODE OF IT (next/structure.md, step 12). This was `CardsEditor`, a
## [ReadingPanel] that overrode 25 of the panel's methods. It is a component card now, built by
## [NoteCards] from the `table` row as the Look's is, and it HANDS the reading what a show of cards
## changes: what is read ([EpisodeWalk]: the episode's script, never the brief), where it is heard
## ([EpisodeCard.Bed]: the episode's table, its sound and wind) and how it goes out
## ([EpisodeCard.Publish]: the episode's title, the episode held through a render, upload notes and its
## chapters). The panel is the one a chapter is read in, and knows nothing of cards.
##
## GENERATION IS EXPLICIT, as with every picture in ghost, and ON THE NOTE'S PIPELINE CARD ([Section]; next/pipeline.md):
## Generate makes what the episode is missing, New episode (here) makes a new seed, and a row's ⟳ deletes that step (and
## what was made from it, asking first when that is anything) and makes it again. Nothing runs on open - it spends the
## author's quota. EACH THING THAT CAN BE MADE AGAIN IS A ROW OF ITS OWN (the user, 2026-11-02: "I don't think we should
## bury options under that button"; a menu of four under every card's ⟳ until then).

const YouTube := preload("res://src/export/youtube.gd")
const TagField := preload("res://src/ui/tag_field.gd")

## The block it keeps under the document's `ghost:` key.
const KEY := "table"
## The knobs a show keeps beside its voice. Also the schema: a stored value of the wrong shape
## falls back to these. NO DRAW (the user, 2026-10-26: "The 'draw' option is confusing ... leave it up to
## the agents to calculate the number of cards to draw (if they are even using cards at all)"): the brief
## says what its episodes draw and the producer plans that many, or none ([method TableProducer._land_plan]).
const KNOBS := {"show": "", "seed": 1, "environment": 0.5,
	"writer": "claude", "writer_model": "", "writer_effort": "", "painter": "codex", "painter_model": "",
	"painter_effort": "", "players": "", "players_model": "", "players_effort": ""}
## Who makes each kind of step (a step's name up to its first ":"), as a row's status names them.
const MAKERS := TableProducer.MAKERS
## EVERY STEP AS ITS ROW SAYS IT, "K" each card or beat: what it is called, and what its ⟳ does ("" for a step with no ⟳ of
## its own - the draw is a function of the seed, so dealing again deals the same cards, and a different deal is a different
## episode; a check and the depth come with their painting; the script with its readings). A ROW IS WHAT THE EPISODE HAS
## (2026-10-26, the user of an alchemy show: "Shuffle" and "Card" "no longer appropriate names"): the draw only where cards
## are drawn, the work only where the plan has work, and each beat called what the producer calls one ([method
## TableEpisode.beat_word] - an ingredient, a card, a coat of paint), with its own name beside it.
const STEPS := {
	"plan": {"label": "Plan", "again": "Make a new plan"},
	"draw": {"label": "Draw", "again": ""},
	"image:back": {"label": "Back", "again": "Paint a new card back"},
	"image:back:": {"label": "Back", "again": "Paint a new back for this printing"},
	"image:surface": {"label": "Cloth", "again": "Paint a new cloth"},
	"image:backdrop": {"label": "Room", "again": "Paint a new room"},
	"model": {"label": "Model", "again": "Design the model again"},
	"image:face": {"label": "Picture to copy", "again": "Paint a new picture to copy"},
	"check:face": {"label": "Art check", "again": ""},
	"layers": {"label": "Layers", "again": "Write the order it is painted in again"},
	"image:layer:K": {"label": "Layer", "again": "Paint this layer, and the ones after it, again"},
	"skin": {"label": "What is painted", "again": "Design what is painted again"},
	"prep": {"label": "Preparation", "again": "Prepare the game again"},
	"table": {"label": "Set", "again": "Set the table again"},
	"image:map:K": {"label": "Map", "again": "Paint this map again"},
	"image:figure:K": {"label": "Figure", "again": "Paint this figure again"},
	"image:reveal:K": {"label": "Picture", "again": "Paint this picture again"},
	"image:height": {"label": "Depth", "again": ""},
	"acts": {"label": "Work", "again": "Block the work again"},
	"say:intro": {"label": "Intro", "again": "Rewrite the intro"},
	"design:K": {"label": "Design", "again": "Redesign this card"},
	"image:card:K": {"label": "Painting", "again": "Paint this card again"},
	"check:K": {"label": "Art check", "again": ""},
	"say:K": {"label": "Reading", "again": "Rewrite this card's reading"},
	"say:work:K": {"label": "Over its work", "again": "Rewrite what is said while its work is done"},
	"beat:K": {"label": "Beat", "again": "Rewrite this beat"},
	"say:close": {"label": "Close", "again": "Rewrite the close"},
	"script": {"label": "Script", "again": ""},
}
## How much of what a ⟳ would throw away it names, before "and 12 more".
const NAMED_MOST := 6
## WHAT A REDO MAKES ALONG WITH ITS STEP: what is made from it and nothing else, so no choice is left
## (the user, 2026-10-17: "if you're changing the first, then by definition you'll need the other
## automatically"). The cloth's depth is painted from the cloth: a new cloth is a new depth, where
## the table wants one (TableEpisode.wants_height), and never a cloth with no depth until Generate.
const TOGETHER := {"image:surface": ["image:height"]}

var _knobs := KNOBS.duplicate(true)
var _episode: TableEpisode = null
var _dock: TimelineDock = null      # the episode's timeline, while it is docked under the show
var _tl_btn: Button = null
var _undo: Array = []                 # what the dock's Undo takes back, last last: {episode, step, digest} - the version before each edit
var _source_window: SourceWindow = null    # ✎'s window, made the first time a row's is pressed
var _tune := {}                     # the show's `tune:` ([TableTune]), as its block tells it - {} for none
var _taking := false                # the voice's take being made ([method _make_take])
var _design_window: DesignWindow = null    # a painted design's elements as rows, made the first time its ✎ is pressed
var _producer: TableProducer = null
var _episode_pick: OptionButton
var _episode_seeds: Array = []
var _new_btn: Button
var _del_btn: Button
var _writer: AgentPick
var _painter: AgentPick
var _players: AgentPick
var _environment_dial: HSlider
var _row_t := 0.0
## WHAT IT HANDS THE NOTE'S PIPELINE CARD ([method pipeline]).
var _section: Section = null
## WHAT THE ROWS ARE DRAWN FROM, read again only when the episode's files change ([method _facts]): they refresh four
## times a second, and an episode's steps are a JSON parse each.
var _facts_of := []
var _facts_kept := {}
var _brief_changed := false
var _deck_note: Label
var _deck_seen := -1
var _table_seen := {}
var _tools_log := {}            # step -> {mt, path, said}: its agent's last tool call
## THE EPISODE AN EXPORT IS OF, held from the moment it is asked for: synthesis takes minutes,
## and an episode picked meanwhile must not lend the take its cards or its upload notes.
## {episode, body, doc, title}, or empty.
var _export_pin := {}
## The take the last export rendered and the episode it is of: the upload describes them (see
## [method upload_base]) after the pin is let go. {take, episode}, or empty.
var _taken := {}
## THE YOUTUBE FIELDS: the show's description and tags (on the YouTube card - null without one). The
## picked episode's title is the Script card's Episode ([method episode_title], edited in its plan).
## The picked episode, as what other cards make from it reads it ([method ReadingPanel.episode_feed]).
var _feed: Feed = null
var _yt_desc: TextField
var _yt_tags: TagField
var _yt_note: Label
var _yt_dirty := 0.0       # seconds until the description's edit is kept; 0 = nothing waiting
var _yt_seen := {}         # {path, mt, ups}: the plan the fields were last filled for, and its uploads
## THE SHOW'S YOUTUBE DESCRIPTION, kept in its document's block - global, the same for every episode,
## never a record per episode (see [method capture]).
var _cur_desc := ""



## THE READING THIS CARD SERVES ([method serve]): it asks the panel a few things by name - its
## document, its script box, the cast's names, the status line - and hands it a walk, a bed and a
## publish. Null for a card nobody handed a reading (it is then inert).
var reading: ReadingPanel
var _doc: DocSource          # the reading's document: the show's brief, and its blocks
var _text: TextEdit          # the brief as its box holds it
var _syncing := false        # writing the controls from the knobs must not write them back
var _youtube: YouTubeCard    # the note's YouTube card, once the reading has built it


## A card for the panel in [param ctx] (`workspace`, the [ReadingPanel] it is built on).
static func for_note(ctx: Dictionary) -> EpisodeCard:
	var card := EpisodeCard.new()
	card.serve(ctx.get("workspace") as ReadingPanel)
	return card


## SERVE [param panel]: hand it the episode's walk, bed and publish, and build the card. The episode
## opens once the panel has read its document ([method _on_reading_ready]) - opening it before would
## open the last show's.
func serve(panel: ReadingPanel) -> void:
	add_theme_constant_override("separation", 8)
	reading = panel
	if reading == null:
		return
	_doc = reading.doc_source()
	_text = reading.source_box()
	reading.walk = EpisodeWalk.new(func() -> TableEpisode: return _episode)
	reading.bed = Bed.new(self)
	reading.publish = Publish.new(self)
	reading.tune_sections.append(Pacing.new(self))
	_doc.opened.connect(_on_show_opened)
	_doc.mode_changed.connect(_on_doc_mode)
	reading.source_edited.connect(func() -> void: _brief_changed = true)
	reading.persisted.connect(_persist)
	reading.ready.connect(_on_reading_ready, CONNECT_ONE_SHOT)
	_build()
	_load_persisted()


## The panel has read its document (its block applied, its cast loaded): a synced show with no block
## of its own starts from the defaults, and the episode its knobs name opens.
func _on_reading_ready() -> void:
	if _doc.is_sync() and not _doc_has_block():
		_knobs = KNOBS.duplicate(true)
		_show_knobs()
	_open_episode()


## THE TABLE IS THE MEDIUM, pinned while the card is up - and BEFORE ANYTHING ATTACHES: the stage
## is built on the first reading, with whatever medium resolves then (see Director.medium_override).
## Pinned on entering the tree, not on being built, so a panel built by hand and freed (a gate)
## leaves no pin behind.
func _enter_tree() -> void:
	if reading != null:
		Director.pin_medium("table", self)


func _exit_tree() -> void:
	if _producer != null:
		_producer.stop()
	if reading != null:
		Director.unpin_medium(self)


func _process(delta: float) -> void:
	if reading == null:
		return
	if _yt_dirty > 0.0:
		_yt_dirty -= delta
		if _yt_dirty <= 0.0:
			_flush_upload_fields(true)
	# four times a second is plenty for runs that take tens of seconds, and every tick asks the
	# disk which steps exist
	_row_t -= delta
	if _row_t <= 0.0:
		_row_t = 0.25
		if _producer != null:
			_producer.tick()
		_refresh_card()
		_seed_globals()


# --- what the reading is asked ------------------------------------------------------------------

func _set_status(text: String) -> void:
	if reading != null:
		reading.status(text)


func _mark_stale() -> void:
	if reading != null:
		reading.mark_stale()


func _touch() -> void:
	if reading != null:
		reading.touch()


## The episode the reading on the stage is of, "" when none is playing.
func _live_episode_dir() -> String:
	if reading == null or not reading.reading_live():
		return ""
	var subs: Node = reading.subtitles
	if subs == null or not is_instance_valid(subs):
		return ""
	var d: Variant = subs.get("document")
	var t: Variant = (d as Dictionary).get("table", {}) if d is Dictionary else {}
	return String((t as Dictionary).get("dir", "")) if t is Dictionary else ""


# --- what it hands the reading -------------------------------------------------------------------

## WHERE THE READING IS: the episode's table (`table.json`), heard - its `sound` and its light's wind,
## on the episode's seed as the table plans it ([method Soundscape.of_table]). An export's is the
## episode pinned for it.
class Bed extends ReadingBed:
	var card: EpisodeCard

	func _init(c: EpisodeCard) -> void:
		card = c

	func of(export := false) -> Dictionary:
		return card.bed_of(export)

	## The Environment dial on the card.
	func level() -> float:
		return float(card._knobs["environment"])


## WHAT THE EPISODE IS PACED BY ([TuneSection], on the panel's Pacing card): the numbers that pace the laws its acts use
## ([method TableTune.fields]: a show that paints nothing is offered no brush's), told in the show's block (`tune:`). Read again only
## when the acts change.
class Pacing extends TuneSection:
	var card: EpisodeCard
	var _seen := "-"
	var _laws: Array = []

	func _init(c: EpisodeCard) -> void:
		card = c

	func rows() -> Dictionary:
		if card._episode == null or not card._episode.has("acts"):
			return {}
		var key := card._episode.dir + "|" + card._episode.digest("acts")
		if key != _seen:
			_seen = key
			_laws = card.laws_used()
		return TableTune.fields(_laws)

	func values() -> Dictionary:
		return card._tune.duplicate()

	func set_value(key: String, value: Variant) -> String:
		card.set_tune(key, value)
		return ""


## The laws the episode's acts use, each once.
func laws_used() -> Array:
	var out: Array = []
	for a in _acts_list():
		for t in ((a as Dictionary).get("tracks", []) if a is Dictionary and (a as Dictionary).get("tracks") is Array else []):
			var law := String((t as Dictionary).get("law", "")) if t is Dictionary else ""
			if not law.is_empty() and not out.has(law):
				out.append(law)
	return out


## HOW AN EPISODE GOES OUT: named after itself, pinned through the minutes of its render, and
## followed by upload notes (see [method EpisodeCard.before_take]).
class Publish extends ReadingPublish:
	var card: EpisodeCard

	func _init(c: EpisodeCard) -> void:
		card = c

	func name() -> String:
		return card.export_name()

	func before_take() -> bool:
		return card.before_take()

	func after_take(path: String) -> String:
		return card.after_take(path)

	func upload_base(take: String) -> Dictionary:
		return card.upload_base(take)

	func upload_values() -> Dictionary:
		return card.upload_values()

	func episode_title() -> Variant:
		return card.episode_title()

	func name_episode(title: String) -> String:
		return card.name_episode(title)

	func book(d: Dictionary, body: String) -> Dictionary:
		return card.book(d, body)

	func youtube_built(yt: YouTubeCard) -> void:
		card.youtube_built(yt)

	# its episodes say what they go up with
	func note_is_episode() -> bool:
		return false

	func feed() -> EpisodeFeed:
		return card._feed


## THE EPISODE AS THE STEPS OTHER CARDS ADD TO IT READ IT ([EpisodeFeed]): its folder, the show's name,
## the episode's title and description, the show's tags (and a step's to write over them), its reading
## with the marks taken out, and the show's writer.
class Feed extends EpisodeFeed:
	var card: EpisodeCard
	var episode: TableEpisode

	func _init(c: EpisodeCard, ep: TableEpisode) -> void:
		card = c
		episode = ep

	func folder() -> String:
		return episode.dir

	func versions() -> Array:
		return episode.step_versions(func(s: String) -> String: return card._step_name(s, card._facts()))

	func put_back(key: Variant) -> String:
		var k: Array = key if key is Array else []
		if k.size() != 2:
			return "no such version"
		var err := episode.restore(String(k[0]), int(k[1]))
		card._after_hand(String(k[0]), err)
		return err

	func show_title() -> String:
		return card._doc.field("title").strip_edges() if card._doc != null else ""

	func episode_title() -> String:
		return String(episode.upload_notes()["title"])

	func description() -> String:
		return card._cur_desc if not card._cur_desc.is_empty() else String(episode.upload_notes()["description"])

	func tags() -> PackedStringArray:
		return card._show_tags()

	func replace_tags(tags: PackedStringArray) -> String:
		if card._doc == null or not card._doc.set_field("tags", ", ".join(tags)):
			return "the tags could not be written into the show's document"
		card._refresh_show_fields()
		return ""

	func words() -> String:
		return Manuscript.unspoken(episode.script()).strip_edges()

	func take() -> String:
		return ProjectSettings.globalize_path(episode.take_file()) if episode.take_matches() else ""

	# the drawn cards' paintings, in drawing order (cards are counted from 1: counted from 0, the last card's painting was missed)
	func pictures() -> PackedStringArray:
		var out := PackedStringArray()
		for k in range(1, episode.card_count() + 1):
			if episode.has("image:card:%d" % k):
				out.append(ProjectSettings.globalize_path(episode.file_of("image:card:%d" % k)))
		return out

	# EVERY PICTURE ITS PAINTER MADE, in the order the episode makes them, each by its row's own name: the picture painted first that
	# a surface copies, its layers, the cloth, the room, the depth, the backs, the cards' paintings, a game's pictures
	func made_pictures() -> Array:
		var out: Array = []
		for st in episode.steps():
			var step := String(st)
			if not step.begins_with("image:") or not episode.has(step):
				continue
			var path := episode.file_of(step)
			if not path.ends_with(".png"):
				continue
			var kind := EpisodeCard.kind_of(step)
			var label := String((EpisodeCard.STEPS.get(kind, {}) as Dictionary).get("label", step))
			var parts := step.split(":")
			var group := ""
			if step.begins_with("image:layer:"):
				var layers := episode.layers()
				var k := int(parts[2])
				label = "Layer %d: %s" % [k, String((layers[k - 1] as Dictionary).get("name", "")) if k <= layers.size() else ""]
				group = "Layers"
			elif parts.size() > 2:
				label += " " + String(parts[2])
				group = "Cards" if step.begins_with("image:card:") else ""
			out.append({"path": ProjectSettings.globalize_path(path), "label": label, "row": step, "group": group})
		return out

	func writer() -> Dictionary:
		return {"agent": String(card._knobs["writer"]), "model": String(card._knobs["writer_model"]),
			"effort": String(card._knobs["writer_effort"])}


func bed_of(export := false) -> Dictionary:
	var dir := ""
	var seed := 0
	if export and not _export_pin.is_empty():
		dir = String((_export_pin["doc"] as Dictionary).get("dir", ""))
		seed = int((_export_pin["doc"] as Dictionary).get("seed", 0))
	elif _episode != null:
		dir = _episode.dir
		seed = _episode.seed
	var path := dir.path_join("table.json")
	if dir.is_empty() or not FileAccess.file_exists(path):
		return {}
	var key := "%s|%d" % [path, FileAccess.get_modified_time(path)]
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (table is Dictionary):
		return {"key": key}
	var made := Soundscape.of_table(table as Dictionary, seed)
	if (made["sound"] as Dictionary).is_empty():
		return {"key": key}
	return {"key": key, "make": func(sample_rate: int, t0: float) -> SoundBed:
		return Soundscape.new(made["sound"], made["wind"], seed, sample_rate, t0, made["ride"])}


## The reading's document [param d], at a table: the show's title and byline, and the episode as the
## table draws it - for an export's own reading, the episode pinned when it was asked for.
func book(d: Dictionary, body: String) -> Dictionary:
	var pinned := not _export_pin.is_empty() and body.strip_edges() == String(_export_pin["body"])
	d["title"] = String(_export_pin["title"]) if pinned else _show_title()
	d["byline"] = String(_export_pin.get("byline", "")) if pinned else _show_byline()
	d["table"] = _export_pin["doc"] if pinned else (_table_doc(_episode) if _episode != null else {})
	return d


## Episode [param ep] as the table draws it ([method TableEpisode.document]). One drawn before the
## draw counted its deck is counted from the deck the brief lists (a deck the producer chose is in
## its plan) - the table stands and washes as many cards as the deck held, never a number of its own.
func _table_doc(ep: TableEpisode) -> Dictionary:
	var doc := ep.document()
	# ...THE TAKE KEPT, where it was said from the script as it stands: the table plans on its words' times (TablePlan.take_times)
	if ep.take_matches(_voice_sig()):
		doc["take"] = ep.take_file()
	# ...AND HOW THE SHOW TUNES ITS HANDS ([TableTune]): the block's `tune:`, for the table live and in a render alike
	if not _tune.is_empty():
		doc["tune"] = _tune.duplicate(true)
	if int(doc.get("deck_n", 0)) <= 0 and _text != null:
		doc["deck_n"] = CardDeck.parse(_text.text).size()
	return doc


## AN EXPORT IS NAMED AFTER ITS EPISODE: the title the producer gave it (made safe for a file name
## by the exporter), or the show and seed while it has none - a folder of `ghost_1080p.mp4`s
## says nothing about which reading is which.
func export_name() -> String:
	if _episode == null:
		return ""
	var plan: Variant = _episode.read_json("plan")
	var t := String((plan as Dictionary).get("episode_title", "")).strip_edges() if plan is Dictionary else ""
	return t if not t.is_empty() else "%s %d" % [_show_title(), _episode.seed]


## THE EXPORT: the take is rendered as any reading's is, then the episode's folder gets `upload.md`
## - the title, the description and tags the producer wrote, and the chapters its readers named timed
## from the take itself ([method TableEpisode.upload_notes]). One show makes many videos; each should arrive ready to post.
##
## THE EPISODE IS PINNED BEFORE THE FIRST AWAIT: the take is minutes of synthesis, and the panel
## stays live through it. False with no episode: nothing renders.
func before_take() -> bool:
	_doc.pull()          # a change in the show's file lands now, not part way through
	_flush_upload_fields()
	var ep := _episode
	if ep == null:
		return false
	_export_pin = {"episode": ep, "body": ep.script().strip_edges(), "doc": _table_doc(ep),
		"title": _show_title(), "byline": _show_byline()}
	return true


## ...and once the take at [param path] is rendered ("" when it was not): the pin let go, the
## upload notes written. Returns what the status line says of them.
func after_take(path: String) -> String:
	var ep: TableEpisode = _export_pin.get("episode")
	_export_pin = {}
	if path.is_empty() or ep == null:
		return ""
	_taken = {"take": path, "episode": ep}
	var show := _doc.field("title")
	var ep_title := String(ep.upload_notes()["title"])
	var err := ep.write_upload_notes(path, _show_tags(), _cur_desc, _youtube.title_now(
		{"title": show.strip_edges(), "episode": ep_title, "seed": str(ep.seed)}) if _youtube != null else upload_title(show, ep_title))
	return ("Rendered the take; upload notes are in the episode's folder (upload.md)." if err.is_empty()
		else "Rendered the take; the upload notes failed: " + err)


## WHAT AN UPLOAD SAYS, under the YouTube card's title, visibility, playlist and thumbnail (see
## [member Exporter.upload_provider]): the episode's description and its chapters timed from
## [param take] (apart, so the playlist goes between them - [method YouTube.description_of]), the
## SHOW'S tags (its document's `tags:` line, the one list - a step that writes an episode's writes over
## it), the episode's folder (where the steps other cards add keep what they made of it), the file its
## uploads are recorded in, and the show's and the episode's titles for the card's `%title%` and
## `%episode%`. For the take an export just rendered it describes THAT episode, whichever is picked now;
## with no take, the picked one. {} while the episode has no plan.
func upload_base(take: String) -> Dictionary:
	var ep: TableEpisode = _episode
	if not take.is_empty() and String(_taken.get("take", "")) == take:
		ep = _taken["episode"]
	if ep == null:
		return {}
	var n := ep.upload_notes(take)
	if String(n["title"]).is_empty():
		return {}
	var desc := _cur_desc if not _cur_desc.is_empty() else String(n["description"])
	return {"values": {"title": _doc.field("title").strip_edges(), "episode": String(n["title"]), "seed": str(ep.seed)},
		"description": desc, "chapters": Array(n["chapters"] as PackedStringArray), "tags": Array(_show_tags()),
		"folder": ep.dir, "record": ep.file_of("youtube")}


## The macros of the YouTube card's title as the card stands: the show's title (no file's name for it), the
## picked episode's and its seed.
func upload_values() -> Dictionary:
	var t: Variant = episode_title()
	return {"title": _doc.field("title").strip_edges() if _doc != null else "", "episode": str(t) if t != null else "",
		"seed": str(_episode.seed) if _episode != null else ""}


## THE PICKED EPISODE'S TITLE, as its plan has it: the Script card's Episode (handed it by the panel -
## [method ReadingPublish.episode_title]), the export's name, the picker's entry and `upload.md`. Null
## before it has a plan: Generate names it.
func episode_title() -> Variant:
	if _episode == null or not _episode.has("plan"):
		return null
	return String(_episode.upload_notes()["title"])


## [param title] NAMES THE PICKED EPISODE from now on: written into its plan, the rest of it kept, so the
## export's file name, the episode picker and `upload.md` follow. "" once written, else why not - an
## emptied title is not written (a video needs one).
func name_episode(title: String) -> String:
	var t := title.strip_edges()
	var plan: Variant = _episode.read_json("plan") if _episode != null else null
	if not (plan is Dictionary):
		return "The episode has no plan yet - Generate names it."
	if t.is_empty():
		return "An episode needs a title: it names the export and the video."
	if t == String((plan as Dictionary).get("episode_title", "")).strip_edges():
		return ""
	(plan as Dictionary)["episode_title"] = t
	var err := _episode.write_json("plan", plan)
	if not err.is_empty():
		return "The title could not be saved into the episode's plan: " + err
	_refresh_upload_note()
	return ""


## THE UPLOAD'S TITLE as the YouTube card's default template makes it: the show's name, then the
## episode's - "Truthful Tarot: My Episode Name" (the user, 2026-10-06) - unless the episode's
## already begins with the name, or the show has none. YouTube's 100 characters are cut from the end
## ([method YouTube.fit_title]), so the name stands.
static func upload_title(show: String, episode: String) -> String:
	var name := show.strip_edges()
	var t := episode.strip_edges()
	if name.is_empty() or t.to_lower().begins_with(name.to_lower()):
		return t
	return "%s: %s" % [name, t] if not t.is_empty() else name


## THE LINE THE NEXT EPISODE'S TITLE GOES UP IN, which its producer is shown before it writes one
## ([method YouTube.title_shape], the `episode_title` rule in rules/table/producer.yaml): the YouTube
## card's template - with no card, the default one, which is what [method upload_title] makes - with
## the show's name in it and [constant TablePrompts.TITLE_MARK] where the episode's title will stand.
func _uploads_as() -> String:
	return YouTube.title_shape(_youtube.template() if _youtube != null else YouTube.TITLE_TEMPLATE,
		{"title": _doc.field("title").strip_edges() if _doc != null else "",
		"seed": str(_episode.seed) if _episode != null else ""}, TablePrompts.TITLE_MARK)


## THE SHOW'S TAGS: its document's own `tags:` line, as North Star's chapters keep theirs
## (`tags: a, b, c`) - every episode goes up with them.
func _show_tags() -> PackedStringArray:
	return YouTube.split_tags(_doc.field("tags")) if _doc != null else PackedStringArray()


## The show's byline: its document's `byline:` line.
func _show_byline() -> String:
	return _doc.field("byline").strip_edges() if _doc != null else ""


# --- the show's document ---------------------------------------------------------------------

func _show_title() -> String:
	var t := _doc.field("title").strip_edges() if _doc != null else ""
	return t if not t.is_empty() else "Untitled show"


## What the producer works from, read fresh: the title and byline, the line an episode's title goes
## up in ([method _uploads_as]), the brief (as the agents get it: its card LIST taken out, its
## macros read, its notes to self gone - see [method TablePrompts.brief]), the deck the brief lists (or none, when the producer chooses each
## episode's - `chooses`), the show's voices
## (every one its document names - the reader's and any other, a familiar's - for the reader to
## hand lines to), how long a word takes its reader to say (what its passages are written to), and the knobs.
func _spec() -> Dictionary:
	var body := Manuscript.strip_frontmatter(_doc.pull())
	return {"title": _show_title(), "byline": _show_byline(), "uploads_as": _uploads_as(),
		"brief": TablePrompts.brief(body), "deck": CardDeck.of(body), "fixed": FixedTable.parse(body),
		"chooses": CardDeck.chooses(body), "voices": reading.cast_names(), "seats": reading.cast_seats(), "said_word": reading.reader_said_word(),
		"writer": _knobs["writer"], "writer_model": _knobs["writer_model"], "writer_effort": _knobs["writer_effort"],
		"painter": _knobs["painter"], "painter_model": _knobs["painter_model"], "painter_effort": _knobs["painter_effort"],
		"players": _knobs["players"] if not String(_knobs["players"]).is_empty() else _knobs["writer"], "players_model": _knobs["players_model"], "players_effort": _knobs["players_effort"]}


## The show's own block: the knobs, and its YouTube title and description.
func capture() -> Dictionary:
	var t := {}
	for k in KNOBS:
		# (who plays the players is written only where someone chose: every other show's block stays as it was)
		if String(k).begins_with("players") and String(_knobs[k]).is_empty():
			continue
		t[k] = _knobs[k]
	# THE SHOW'S YOUTUBE DESCRIPTION: a global value (each episode's title is its plan's)
	if not _cur_desc.is_empty():
		t["description"] = _cur_desc
	# ...and its tuning, only where it tells some: every other show's block stays as it was
	if not _tune.is_empty():
		t["tune"] = _tune.duplicate(true)
	return t


## The document's block arrives at every read of it - on open, and at every Play and export
## (see [method DocSource.pull]) - so the episode is reopened only when the block names a
## DIFFERENT one. Reopening on every read stopped a generation in progress, and reopening reads the
## document again, which used to recurse.
##
## THE KNOBS ARE THE DOCUMENT'S, EXACTLY: the block is laid over the defaults, never over the
## knobs the panel held - those belong to whatever show was open before, and a show whose block
## does not name its `show` key would otherwise make its episodes in the last show's folder,
## with the last show's history handed to its producer as its own. A document with no `table:`
## block at all (a chapter, opened here for its voice) is never applied: it opens as a new show,
## from the defaults ([method _on_show_opened]).
func apply(cfg: Dictionary) -> void:
	var was := "%s#%d" % [String(_knobs["show"]), int(_knobs["seed"])]
	_knobs = KNOBS.duplicate(true)
	_take_knobs(cfg)
	_cur_desc = str(cfg.get("description", ""))
	_tune = (cfg["tune"] as Dictionary).duplicate(true) if cfg.get("tune") is Dictionary else {}
	if _episode == null or "%s#%d" % [String(_knobs["show"]), int(_knobs["seed"])] != was:
		_open_episode()
	_refresh_show_fields()


## A document arrived (opened, or synced to). One that carries a `table:` block has had it
## applied already; one with none is a new show, and starts from the defaults rather than from
## the show before it. Nothing is written into it until something is changed.
func _on_show_opened(_path: String) -> void:
	if not _doc_has_block():
		_fresh_show()


## Detached from the document: the show it was is not this one any more.
func _on_doc_mode(sync: bool) -> void:
	if not sync:
		_fresh_show()


func _fresh_show() -> void:
	_knobs = KNOBS.duplicate(true)
	_cur_desc = ""
	_show_knobs()
	_open_episode()
	_refresh_show_fields()


## Whether the synced document carries a show's own block (`table:`).
func _doc_has_block() -> bool:
	if _doc == null or not _doc.is_sync():
		return false
	var raw := FileAccess.get_file_as_string(_doc.doc_path())
	var res: Dictionary = FrontMatter.read_block(raw)
	return res.get("data") is Dictionary and (res["data"] as Dictionary).get(KEY) is Dictionary


func _persist() -> void:
	Settings.write(reading.section(), "knobs", _knobs.duplicate(true))


## The knobs from the last session, for an unsynced brief; a synced show's own block replaces
## them as the reading reads its document, and a synced show with no block starts from the
## defaults ([method _on_reading_ready]).
func _load_persisted() -> void:
	var k: Variant = Settings.read(reading.section(), "knobs", {})
	if k is Dictionary:
		_take_knobs(k as Dictionary)


## Knobs from a stored block or a document, each checked against [constant KNOBS].
func _take_knobs(src: Dictionary) -> void:
	for k in KNOBS:
		if not src.has(k):
			continue
		var v: Variant = src[k]
		match k:
			"seed":
				_knobs[k] = maxi(1, int(v))
			"environment":
				_knobs[k] = clampf(float(v), 0.0, 1.0) if (v is float or v is int) else float(KNOBS[k])
			"writer":
				_knobs[k] = String(v) if TextGen.has(String(v)) else "claude"
			"painter":
				_knobs[k] = String(v) if ImageGen.REGISTRY.has(String(v)) else "codex"
			_:
				_knobs[k] = String(v)
	_show_knobs()

# --- the episode section -----------------------------------------------------------------------

## The card: the episode picker, the agents, Generate, the rows and the title.
func _build() -> void:
	var box: VBoxContainer = self

	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 6)
	box.add_child(erow)
	_episode_pick = OptionButton.new()
	_episode_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SIZED BY THE ROW, NOT BY ITS ITEMS: an OptionButton is as wide as its longest item unless
	# told otherwise (clip_text alone does not do it), and an episode's title is a writer's - one
	# long title pushed the whole panel out to 1080 px
	_episode_pick.fit_to_longest_item = false
	_episode_pick.clip_text = true
	_episode_pick.focus_mode = Control.FOCUS_NONE
	_episode_pick.tooltip_text = ("Every episode this show has made, by seed. Picking one loads it "
		+ "exactly as it was made - same cards, same pictures, same words.")
	_episode_pick.item_selected.connect(func(i: int) -> void:
		if _syncing or i < 0 or i >= _episode_seeds.size():
			return
		_knobs["seed"] = int(_episode_seeds[i])
		_touch()
		_open_episode())
	erow.add_child(_episode_pick)
	# ...ITS NAME GIVEN THE WHOLE ROW, what is done to an episode beneath it (the user, 2026-11-11: "so that the buttons are near
	# each other, and so that the episode names get the full row")
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	box.add_child(arow)
	_new_btn = Button.new()
	_new_btn.text = "New episode"
	_new_btn.tooltip_text = ("A fresh seed: a new plan, a new deck, a new reading - made when you press "
		+ "Generate, or a part at a time with ⟳, on the Pipeline card.")
	_new_btn.pressed.connect(_new_episode)
	arow.add_child(_new_btn)
	# ...OR ONE BEGUN BY HAND (next/editing.md step 8): no agent asked, every row waiting for its ✎
	var hand := Button.new()
	hand.text = "By hand"
	hand.tooltip_text = ("A fresh episode no agent makes: a plan of one beat, the table with the brief's fixed things, empty words - "
		+ "each part waiting on the Pipeline card for its ✎. Generate passes them by; a ⟳ hands one to its agent.")
	hand.pressed.connect(new_by_hand)
	arow.add_child(hand)
	_del_btn = Button.new()
	_del_btn.text = "Delete…"
	_del_btn.tooltip_text = ("Delete the episode picked above: its plan, cards, pictures, reading and "
		+ "upload notes go to the system trash (restore it from there). Exported videos and the "
		+ "show's other episodes are not touched.")
	_del_btn.pressed.connect(_ask_delete)
	arow.add_child(_del_btn)

	# NO DRAW, REVERSALS OR JUMPERS (the user, 2026-10-25: "options that should be set by the agents during
	# preparation for an episode"; and 2026-10-26, of the draw): the producer chooses them from the brief - how
	# many cards in the plan's spread, the rest in its staging ([constant CardTable.REVERSALS], `jumpers`)
	# THE PLACE, HEARD: what the set dresser wrote as the table's `sound`, and its wind ([Soundscape])
	_environment_dial = Card.slider_row(box, "Environment", 0.0, 1.0, 0.05, float(_knobs["environment"]),
		("The place the reading is in, heard under the voice: the wind, the sea, rain, a fire - whatever "
		+ "the set dresser gave the episode's table, and its wind whenever the table has one, every gust "
		+ "heard as it moves the leaves, the shadows and the petals. 0 is off. Low is far and steady, a "
		+ "bed behind the reader; higher is closer and more vivid - louder, brighter, the gusts and the "
		+ "breakers and the crackles hitting harder. It steps back a little whenever the reader speaks. "
		+ "In the exported take too; while a reading plays, a change is heard after the few seconds "
		+ "already queued."),
		func(v: float) -> void:
			if _syncing:
				return
			_knobs["environment"] = v
			_touch())


	# WHO WRITES AND WHO PAINTS: an agent CLI each, from the registries - the plan, the booklet and
	# the reading are words, the deck and the table are pictures. One row each, built the way every
	# card that runs agents builds them ([AgentPick])
	_writer = AgentPick.writer("Who writes the plan, the booklet and the reading. Takes effect at the next Generate.",
		"The model that writes. Default is the CLI's own choice per job (for Claude: Opus for the plan and the reading, Sonnet for the card designs); a model chosen here writes all of it.",
		("How hard the writer thinks before it writes - the CLI's own reasoning effort. Default is what "
		+ "each CLI does unasked (Claude: your Claude Code setting for the model; Codex: medium, low for "
		+ "the card designs; Amazon Nova: off - only Nova 2 Lite thinks, billed as output). A level "
		+ "chosen here is used for every job. Higher is slower and spends more quota."))
	_writer.changed.connect(_agents_chosen.bind(_writer, "writer"))
	box.add_child(_writer)
	_painter = AgentPick.painter("Who paints the card back, the cloth, the room and every card. Takes effect at the next Generate.",
		"The model of the agent that asks for each picture. The picture itself is made by the CLI's own image tool whichever model asks.",
		("How hard the agent that asks for each picture thinks - not the picture itself. Default is "
		+ "low for Codex (its job is to call one tool); Bedrock's painter takes no setting."))
	_painter.changed.connect(_agents_chosen.bind(_painter, "painter"))
	box.add_child(_painter)
	# ...AND WHO PLAYS THE PLAYERS, in a game (next/tabletop.md): seen only where the episode is one
	_players = AgentPick.players("Who plays the players at the table: each is asked what they do as the game is played, knowing only what they know. Takes effect at the next Generate.",
		"The model that plays them. Default is the writer's own, on its quicker tier: they are asked a hundred questions a night.",
		"How hard a player thinks before they answer. Default is what the CLI does unasked: a player is not meant to think long.")
	_players.changed.connect(_agents_chosen.bind(_players, "players"))
	_players.visible = false
	box.add_child(_players)

	# ...AND ITS TIMELINE (next/editing.md, "The Timeline"): its beats, acts and cues docked under the show, read from its files
	var tl := Button.new()
	tl.text = "Timeline…"
	tl.toggle_mode = true
	tl.tooltip_text = ("This episode's timeline, under the show: its beats along the top, and the one picked below - each act a "
		+ "block in the lane of the thing it works, each cue a flag where it is said. Read from the episode's files as they stand.")
	tl.toggled.connect(func(on: bool) -> void:
		if on:
			if open_dock() == null:
				tl.set_pressed_no_signal(false)
		else:
			close_dock())
	_tl_btn = tl
	# ...OPENED FROM BESIDE PLAY, as every note's timeline is ([method Transport.offer_timeline]): no button of its own here
	tl.visible = false
	tree_entered.connect(func() -> void:
		Transport.offer_timeline(self, 3, func() -> void:
			if _dock != null and is_instance_valid(_dock):
				close_dock()
			else:
				open_dock(), func() -> bool: return _dock != null and is_instance_valid(_dock),
			"The episode's timeline: its beats, each act in the lane of the thing it works, each cue where it is said - and one inspector for what is picked."))
	tree_exiting.connect(func() -> void: Transport.withdraw_timeline(self))
	arow.add_child(tl)

	_deck_note = Label.new()
	_deck_note.add_theme_font_size_override("font_size", 11)
	_deck_note.modulate = Color(1, 1, 1, 0.7)
	_deck_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_note.tooltip_text = ("THE DECK IS THE SHOW'S: a `## Cards` section in the brief, one card per "
		+ "list item - `- XVI. The Tower: what it means` - with `###` headings for its suits. A brief "
		+ "that lists none leaves each episode's deck to its producer. Each episode's cards are a "
		+ "shuffle of the deck, from a seed drawn from the system's own randomness; no agent ever picks a card.")
	_deck_note.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_deck_note)
	_section = Section.new(self)
	_show_knobs()


## A person chose another agent, model or level on [param pick]: its choice is the show's [param knob]
## and its `_model` and `_effort`.
func _agents_chosen(pick: AgentPick, knob: String) -> void:
	if _syncing:
		return
	var c := pick.choice()
	_knobs[knob] = String(c["agent"])
	_knobs[knob + "_model"] = String(c["model"])
	_knobs[knob + "_effort"] = String(c["effort"])
	_touch()


func _show_knobs() -> void:
	if _environment_dial == null:
		return
	_syncing = true
	_environment_dial.value = float(_knobs["environment"])
	_writer.set_choice(String(_knobs["writer"]), String(_knobs["writer_model"]), String(_knobs["writer_effort"]))
	_painter.set_choice(String(_knobs["painter"]), String(_knobs["painter_model"]), String(_knobs["painter_effort"]))
	var who_plays := String(_knobs["players"]) if not String(_knobs["players"]).is_empty() else String(_knobs["writer"])
	_players.set_choice(who_plays, String(_knobs["players_model"]), String(_knobs["players_effort"]))
	_syncing = false


## The show's key: the title's, until the first episode is made - then FIXED in the document
## (see [method _generate]), because an episode's files are found by it and renaming the channel
## must not lose them. Not fixed earlier, or a new show would be keyed by the title it had at boot.
func _show_key() -> String:
	var k := String(_knobs["show"])
	return k if not k.is_empty() else Manuscript.slug(_show_title())


## Point the panel at the current seed's episode (made, partly made, or not at all).
func _open_episode() -> void:
	if _episode_pick == null:
		return
	if _producer != null and _producer.running:
		_producer.stop()
	if reading != null:
		reading.episode_left(_feed)   # ...and what the other cards were making of it
	_flush_upload_fields()      # an edit still waiting belongs to the episode being left
	var seed := int(_knobs["seed"])
	_episode = TableEpisode.open(_show_key(), seed)
	# AN EPISODE MADE BEFORE RECORDS gains them as it is opened here (TableEpisode.adopt), so its rows show at once what is kept -
	# never in a process that may not write the author's things
	if not Settings.is_read_only():
		_episode.adopt()
	_feed = Feed.new(self, _episode)
	# the spec is taken when Generate is pressed (see _generate) - never here, where reading the
	# document would land back in apply
	_producer = TableProducer.new(_episode, {})
	_brief_changed = false
	_refill_episodes()
	_fill_upload_fields(true)
	_mark_stale()


func _refill_episodes() -> void:
	_syncing = true
	_episode_pick.clear()
	_episode_seeds = []
	# NEWEST FIRST: seeds are random now, so their order says nothing; when an episode was made does
	var seen := {}
	var seeds: Array = []
	var cur := int(_knobs["seed"])
	for h in TableEpisode.history(_show_key()):
		var s := int((h as Dictionary)["seed"])
		seen[s] = String(((h as Dictionary)["plan"] as Dictionary).get("episode_title", ""))
		seeds.append(s)
	if not seen.has(cur):
		seen[cur] = ""
		seeds.push_front(cur)
	for s in seeds:
		_episode_pick.add_item(_episode_label(int(s), String(seen[s])))
		_episode_seeds.append(int(s))
	_episode_pick.select(_episode_seeds.find(cur))
	_syncing = false


## An episode's entry in the picker: its seed, and its title once its plan has one.
static func _episode_label(seed: int, title: String) -> String:
	return "#%d  %s" % [seed, title if not title.is_empty() else "(not made yet)"]


## A NEW EPISODE IS A NEW SEED, drawn from the operating system's cryptographic randomness (see
## [method CardDeck.true_seed]): the cards it deals are nobody's choice, and the seed is kept, so
## the episode can be made again exactly.
func _new_episode() -> void:
	var used := {}
	for h in TableEpisode.history(_show_key()):
		used[int((h as Dictionary)["seed"])] = true
	var seed := CardDeck.true_seed()
	while used.has(seed):
		seed = CardDeck.true_seed()
	_knobs["seed"] = seed
	_touch()
	_open_episode()


## A NEW EPISODE BEGUN BY HAND ([method TableEpisode.begin_by_hand]): a fresh seed, written at once, nothing asked of an agent.
func new_by_hand() -> void:
	if Settings.is_read_only():
		_set_status("This session is read-only (a render or a probe) - nothing is written here.")
		return
	_new_episode()
	if _episode == null:
		return
	var err := _episode.begin_by_hand(1, FixedTable.parse(_text.text) if _text != null else {})
	_set_status(("Could not begin it: " + err) if not err.is_empty() else "Episode #%d is yours: write each part with its ✎ on the Pipeline card." % _episode.seed)
	_mark_stale()


func _generate() -> void:
	_run([])


## Make what is missing - all of it, or only [param steps] (see [member TableProducer.only]).
func _run(steps: Array, remake := false, note := "") -> void:
	if _episode == null:
		return
	if Settings.is_read_only():
		_section.tell("This session is read-only (a render or a probe) - nothing is generated here.")
		return
	if String(_knobs["show"]).is_empty():
		_knobs["show"] = _show_key()
		_touch()
		_open_episode()
	# the spec as it is NOW: the brief may have been edited since the episode was opened
	_producer.spec = _spec()
	_brief_changed = false
	_producer.start(steps, remake, note)


## Asked first: an episode is minutes of the writer's and the painter's quota.
func _ask_delete() -> void:
	if _episode == null or not DirAccess.dir_exists_absolute(_episode.dir):
		return
	if _exporting(_episode):
		_set_status("Episode #%d is being exported - delete it once the export is done." % _episode.seed)
		return
	var plan: Variant = _episode.read_json("plan")
	var named := String((plan as Dictionary).get("episode_title", "")) if plan is Dictionary else ""
	var ask := ConfirmationDialog.new()
	ask.title = "Delete episode"
	ask.dialog_text = ("Delete episode #%d%s?\n\nIts plan, cards, pictures, reading and upload notes go to "
		+ "the system trash. Exported videos are not touched.") % [_episode.seed,
		("  \"%s\"" % named) if not named.is_empty() else ""]
	ask.dialog_autowrap = true
	ask.ok_button_text = "Delete"
	var which := _episode
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		_delete_episode(which))
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered(Vector2i(520, 0))


## DELETE [param ep]: whatever is making it stops, a reading of it stops (the table is showing its
## pictures), its folder goes to the trash, and the panel moves to the newest episode left - or to
## a fresh seed, not made yet, when none is.
func _delete_episode(ep: TableEpisode) -> void:
	if ep == null or _exporting(ep):
		return
	var open := _episode != null and _episode.dir == ep.dir
	if open and _producer != null:
		_producer.stop()
	if reading != null:
		reading.episode_left(Feed.new(self, ep))
	if _live_episode_dir() == ep.dir:
		reading.stop_speaking()
	var err := ep.trash()
	if not err.is_empty():
		_set_status("Could not delete episode #%d: %s" % [ep.seed, err])
		return
	print("ghost: table - episode %s #%d moved to the trash" % [ep.show, ep.seed])
	if open:
		var left := TableEpisode.history(_show_key())
		_knobs["seed"] = int((left[0] as Dictionary)["seed"]) if not left.is_empty() else CardDeck.true_seed()
		_touch()
		_open_episode()
	else:
		_refill_episodes()
	_set_status("Episode #%d is in the system trash." % ep.seed)


## Whether an export of [param ep] is under way (see [member _export_pin]).
func _exporting(ep: TableEpisode) -> bool:
	return not _export_pin.is_empty() and (_export_pin["episode"] as TableEpisode).dir == ep.dir


func _redo(step: String) -> void:
	if _episode == null:
		return
	if _producer.running:
		_producer.stop()
	# MADE AGAIN, NOTHING THROWN AWAY (next/editing.md step 1): what stands plays until the new one lands over it, a version back,
	# and what was made from it goes stale ([member TableProducer.again])
	print("ghost: table make %s again - what stands goes a version back" % step)
	_mark_stale()
	_run([step] + (TOGETHER.get(step, []) as Array), true)


# --- on the Pipeline card ------------------------------------------------------------------------

## WHAT THIS CARD MAKES, on the note's one list ([PipelineCard]).
class Section extends PipelineSection:
	var card: EpisodeCard

	func _init(c: EpisodeCard) -> void:
		card = c
		owner = c
		title = String(Registry.field(Components.REGISTRY, EpisodeCard.KEY, "heading", "Episode"))

	func shown() -> bool:
		return card._episode != null

	func rows() -> Array:
		return card._step_rows()

	func group_said(group: String) -> String:
		return card._group_said(group)

	func line() -> String:
		return card._pipeline_line()

	func make() -> void:
		card._generate()

	func make_tip() -> String:
		return ("Make whatever this episode is missing, in order: the plan, the shuffle, the deck, the pictures, and the "
			+ "reading - one card at a time, each written knowing only the cards already drawn. Spends the writer's and "
			+ "the painter's quota.")

	func stop() -> void:
		if card._producer != null:
			card._producer.stop()

	func busy() -> bool:
		return card._making()

	# (...a row made again runs alone, what was made from it waiting for Generate: pressed meanwhile, the rest is made after it)
	func widens() -> bool:
		return card._producer != null and card._producer.running and not card._producer.only.is_empty() and missing()

	func missing() -> bool:
		return card._episode != null and not bool(card._facts()["complete"])


## What it hands the note's Pipeline card.
func pipeline() -> PipelineSection:
	return _section


func _making() -> bool:
	return _producer != null and (_producer.running or _producer.busy())


## WHAT THE ROWS READ, ONCE PER CHANGE OF THE EPISODE'S FILES: a step made or thrown away changes the listing, and the
## plan's own edits (the Episode's title) its time. What is worked out row by row is kept here too (`asks`, `ready`, `said`).
func _facts() -> Dictionary:
	var dir := _episode.dir
	var files := DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	# ...and its size: a file's clock is in seconds, and a plan written again inside one must be read again
	var plan_at := _episode.file_of("plan")
	var now := [dir, files, _mtime(plan_at), FileAccess.get_size(plan_at) if FileAccess.file_exists(plan_at) else 0]
	if now == _facts_of:
		return _facts_kept
	_facts_of = now
	var needs := {}
	var all := _episode.steps()
	for st in all:
		needs[String(st)] = _episode.needs(String(st))
	_facts_kept = {"plan": _episode.read_json("plan"), "steps": all, "needs": needs, "lost": _episode.all_dependents(),
		"doc": _episode.document(), "complete": _episode.complete(), "cardless": _episode.cardless(),
		"cards": _episode.card_count(), "beats": _episode.beat_count() if _episode.cardless() else 0,
		"word": _episode.beat_word(), "printings": _episode.printings(), "depth": _episode.wants_height(),
		"asks": {}, "ready": {}, "said": {}}
	return _facts_kept


## THE EPISODE'S ROWS, each thing that can be made again a row of its own.
func _step_rows() -> Array:
	if _episode == null or _producer == null:
		return []
	var f := _facts()
	var has: Array = f["steps"]
	var busy := _making()
	var out: Array = [_row_of("plan", "plan", "", busy, f)]
	if not bool(f["cardless"]):
		out.append(_row_of("draw", "draw", "", busy, f))
	if _players != null:
		_players.visible = has.has("prep")
	if has.has("prep"):
		out.append(_row_of("prep", "prep", "", busy, f))
	# THE TABLE: a back only where cards are drawn, and a back per printing the drawn cards are in (TableEpisode.printings)
	if has.has("image:back"):
		out.append(_row_of("image:back", "image:back", "Table", busy, f))
	for key in f["printings"]:
		if has.has("image:back:%s" % key):
			out.append(_row_of("image:back:%s" % key, "image:back:", "Table", busy, f, "Back: %s" % key))
	if has.has("model"):
		out.append(_row_of("model", "model", "", busy, f))
	for st in ["image:surface", "image:backdrop", "table"]:
		out.append(_row_of(st, st, "Table", busy, f))
	if bool(f["depth"]):
		out.append(_row_of("image:height", "image:height", "Table", busy, f))
	# ...WHAT IS PAINTED, painted first as a picture and looked at, then copied (TableEpisode.wants_face)
	for st in ["image:face", "check:face"]:
		if has.has(st):
			out.append(_row_of(st, st, "", busy, f))
	# ...AND AGAIN IN LAYERS, the order written then each layer painted over the one before (TableEpisode._layer_steps)
	if has.has("layers"):
		out.append(_row_of("layers", "layers", "Layers", busy, f))
		var layers := _episode.layers()
		for k in range(1, layers.size() + 1):
			var st := "image:layer:%d" % k
			if has.has(st):
				var lr := _row_of(st, "image:layer:K", "Layers", busy, f, "%d. %s" % [k, String((layers[k - 1] as Dictionary).get("name", "Layer"))])
				# ...ITS ▶: THIS LAYER LAID AGAIN ON THE TABLE, ALONE (TableProducer.lay_layer) - where the painting is laid already
				if has.has("skin") and FileAccess.file_exists(_episode.dir.path_join("paint").path_join("elements.json")):
					lr.go = "Lay this layer again on the table: the painter paints it alone, over the layers before it, and the rest stay as they are."
					lr.go_open = not busy
					lr.make = _lay_layer.bind(k)
				out.append(lr)
	if has.has("skin"):
		out.append(_row_of("skin", "skin", "", busy, f))
	if has.has("acts"):
		out.append(_row_of("acts", "acts", "", busy, f))
	out.append(_row_of("say:intro", "say:intro", "", busy, f))
	var word := String(f["word"])
	for k in range(1, int(f["cards"]) + 1):
		var group := "%s %d" % [word, k]
		for kind in ["design:K", "image:card:K", "check:K", "say:K", "say:work:K"]:
			var st := String(kind).replace("K", str(k))
			# ...a card read before checks has none (TableEpisode.checks), a written card no picture, and a card its work
			# words only where it has work: what the episode has
			if has.has(st):
				out.append(_row_of(st, String(kind), group, busy, f))
	for k in range(1, int(f["beats"]) + 1):
		out.append(_row_of("say:%d" % k, "beat:K", "", busy, f, "%s %d" % [word, k]))
	out.append(_row_of("say:close", "say:close", "", busy, f))
	out.append(_row_of("script", "script", "", busy, f))
	out.append(_take_row(busy))
	# ...WHAT THE SESSION TURNED OUT TO NEED, each named, painted after it was played (next/tabletop.md)
	var played: Dictionary = _episode.game()
	for key in TableEpisode.GAME_PICTURES:
		var word2 := String(TableEpisode.GAME_PICTURES[key])
		var list: Array = played.get(key, [])
		for k in list.size():
			var st := "image:%s:%d" % [word2, k + 1]
			if has.has(st):
				out.append(_row_of(st, "image:%s:K" % word2, "Pictures", busy, f, String((list[k] as Dictionary).get("name", "%s %d" % [word2, k + 1]))))
	return out


## THE SHOW'S [param key] TUNED to [param value] ([TableTune]; null unsets it, back to its row's default): made safe, kept in the
## show's block, and the rows shown again as they now stand.
func set_tune(key: String, value: Variant) -> void:
	if value == null:
		_tune.erase(key)
	else:
		var safe: Dictionary = TableTune.sanitize({key: value})["values"]
		if not safe.has(key):
			return
		_tune[key] = safe[key]
	_touch()
	_set_status("Paced for this show: the table is set with it the next time it stands.")


## THE VOICE'S TAKE AS A ROW (next/editing.md step 3): made, stale (the script changed since it was said) or not made, with its
## length; its ⟳ says the whole script once, every sentence said before coming from the cache, and keeps it with the episode.
func _take_row(busy: bool) -> PipelineRow:
	var r := PipelineRow.new("take", "Voice")
	var has_take := FileAccess.file_exists(_episode.take_file())
	r.state = "running" if _taking else ("made" if _episode.take_matches(_voice_sig()) else ("stale" if has_take else "missing"))
	r.said = ("being said, a sentence at a time" if _taking else (Clock.text(_episode.take_length()) if has_take else ""))
	r.wraps = _taking
	r.tip = ("The whole reading said once and kept: Play plays it as the export will, the table plans on when each word is really "
		+ "said rather than a guess, and a seek lands where it is asked. Stale once the words or a voice change.")
	r.again = "Say the whole script and keep it: sentences said before are not said again"
	r.open = not busy and not _taking and reading != null and _episode.has("script")
	r.redo = _make_take
	return r


## What a take of the reading as it stands is said from ([method ReadingPanel.take_sig]): "" without a reading, and then only the
## script decides whether the take kept is the episode's.
func _voice_sig() -> String:
	return reading.take_sig() if reading != null else ""


## THE TAKE MADE AND KEPT: the reading's whole take, rendered as an export renders it, kept with the episode.
func _make_take() -> void:
	if reading == null or _episode == null or _taking:
		return
	if Settings.is_read_only():
		_set_status("This session is read-only (a render or a probe) - nothing is said here.")
		return
	_taking = true
	var ep := _episode
	var path: String = await reading.render_take()
	_taking = false
	var err := "the voice made no take" if path.is_empty() else ep.keep_take(path)
	_set_status(("Could not keep the take: " + err) if not err.is_empty() else "The take is kept (%s): Play plays it, and the table plans on its times." % Clock.text(ep.take_length()))
	_mark_stale()


## THE ROW KIND OF STEP [param step], as [constant STEPS] names it: a card's or a beat's number, a game picture's, a printing's key
## made the kind's own ("image:card:3" -> "image:card:K", "image:back:gilt" -> "image:back:").
static func kind_of(step: String) -> String:
	if STEPS.has(step):
		return step
	var parts := step.split(":")
	if parts.size() >= 3:
		var k := "%s:%s:K" % [parts[0], parts[1]]
		if STEPS.has(k):
			return k
		if STEPS.has("%s:%s:" % [parts[0], parts[1]]):
			return "%s:%s:" % [parts[0], parts[1]]
	if parts.size() == 2 and STEPS.has("%s:K" % parts[0]):
		return "%s:K" % parts[0]
	return step


func _row_of(step: String, kind: String, group: String, busy: bool, f: Dictionary, named := "") -> PipelineRow:
	var info: Dictionary = STEPS[kind]
	var r := PipelineRow.new(step, named if not named.is_empty() else String(info["label"]), group)
	var st := _producer.state_of(step)
	r.state = String({"ready": "made", "running": "running", "queued": "queued", "failed": "failed"}.get(st, "missing"))
	# STALE: made from something that has changed since - it still plays (TableEpisode.stale)
	if st == "ready" and _episode.stale(step):
		r.state = "stale"
	r.said = _said_of(step, f)
	# WHAT ITS AGENT IS DOING, while it is made: who, doing what, for how long (TableProducer.activity_of) - a step of many
	# minutes showed only its glyph, and could not be told from one stuck. WHAT IS BEING DONE COMES FIRST, AND WHOLE
	# (2026-10-26: an 18-minute run's status sat past the end of a clipped row, behind what was already made)
	var doing := _doing_of(step)
	if not doing.is_empty():
		r.said = doing + (" - " + r.said if not r.said.is_empty() else "")
		r.wraps = true
	if st == "failed":
		r.said = _producer.error_of(step)
	# A DEPTH NOT MADE YET HOLDS NOTHING BACK ([method TableEpisode.complete]): it comes with the cloth, where the table wants one
	if step == "image:height" and st == "missing":
		r.state = "none"
		r.said = "comes with the cloth"
	# BY HAND, NOT MADE YET (TableEpisode.by_hand): Generate passes it by, and it waits for its ✎
	if st == "missing" and _episode.by_hand(step):
		r.said = "by hand - waits for you"
	if step == "table" and st == "ready" and not _table_things().is_empty():
		r.tip = "On the table:\n" + "\n".join(_table_things())
	r.again = String(info["again"])
	if r.again.is_empty():
		_edit_of(r, step)
		return r
	# ⟳ ONLY WHAT CAN START: a step whose inputs are not made was passed by without a word (TableProducer.tick)
	var ready := _ready_to_make(step, f)
	r.open = ready and not busy
	if not ready:
		r.again += " - once what it is made from is made"
	r.asks = _asks_of(step, f)
	# A LOCK BESIDE ITS ⟳ ON WHAT IS MADE (TableEpisode.kept): locked, it is KEPT - Generate passes it by, stale or not; a step changed
	# by hand is kept until it is unlocked
	r.lockable = _episode.has(step)
	r.locked = _episode.kept(step)
	r.lock = func(on: bool) -> void:
		var err := _episode.set_kept(step, on)
		if not err.is_empty():
			_set_status("Could not keep the lock: " + err)
		_mark_stale()
	r.redo = _redo.bind(step)
	_edit_of(r, step)
	return r


## THE EPISODE'S TIMELINE, DOCKED UNDER THE SHOW (its "Timeline…"; next/editing.md, "The Timeline" and step 6): its beats along the
## top, the one picked below, and ONE INSPECTOR at the right for what is picked there or on the stage ([method _inspect]). Worked
## there - an act's block stretched, a cue's flag moved, a field of an act or a thing set, a thing dragged on the plan - each a
## hand's version of its step, kept, and taken back by its Undo ([method _take_back]). The dock, null without an episode.
func open_dock() -> TimelineDock:
	if _dock != null and is_instance_valid(_dock):
		return _dock
	if _episode == null:
		return null
	_dock = TimelineDock.new()
	var plan: Variant = _episode.read_json("plan")
	_dock.open(_episode.timeline(), String((plan as Dictionary).get("episode_title", "Episode")) if plan is Dictionary else "Episode")
	_dock.closed.connect(close_dock)
	_dock.edit = func(it: Dictionary, from: float, to: float) -> String:
		var src: Array = it.get("source", [])
		var err := "this is not something the timeline can change yet"
		if src.size() == 2 and String(src[0]) == "acts":
			err = _hand_write("acts", func() -> String: return _episode.set_act_length(int(src[1]), to - from))
		elif src.size() == 3 and String(src[1]) == "cue":
			err = _hand_write(String(src[0]), func() -> String:
				return _episode.move_cue(String(src[0]), int(src[2]), from - float(it.get("passage_at", 0.0))))
		_after_hand(String(src[0]) if not src.is_empty() else "", err)
		return err
	_dock.inspector = _inspect
	_dock.undo = _take_back
	# THE SHOW'S TIME ON THE EPISODE'S CLOCK: a kept take carries its intro as held silence, the timeline begins at the first word
	_dock.clock = func() -> float:
		if not Spectrum.timed():
			return -1.0
		return Spectrum.scrub_position() - (Spectrum.lead_in if reading != null and reading.take_playing() else 0.0)
	_dock.seek = func(t: float) -> void:
		Spectrum.seek(t + (Spectrum.lead_in if reading != null and reading.take_playing() else 0.0))
	add_child(_dock)
	if _tl_btn != null:
		_tl_btn.set_pressed_no_signal(true)
	return _dock


func close_dock() -> void:
	# (the show's own eye back, whatever was looked at freely)
	var med := Director.shown_medium() as TableMedium
	if med != null and med.looking_freely():
		med.free_look(false)
	if _dock != null and is_instance_valid(_dock):
		_dock.queue_free()
	_dock = null
	if _tl_btn != null:
		_tl_btn.set_pressed_no_signal(false)


## A HAND'S EDIT OF [param step]: [param write] (`() -> String`, "" written) run, and the step as it stood remembered for Undo and
## the step kept. "" done, else why not.
func _hand_write(step: String, write: Callable) -> String:
	if _episode == null:
		return "no episode is open"
	var before := _episode.digest(step)
	var err := String(write.call())
	if not err.is_empty() or _episode.digest(step) == before:
		return err
	if not before.is_empty():
		_undo.append({"episode": _episode.dir, "step": step, "digest": before})
		while _undo.size() > 50:
			_undo.pop_front()
	# ...RECORDED AS THE HAND'S, so Restore says "yours" of it once it stands a version back
	var noted := _episode.note_made(step, "hand")
	return noted if not noted.is_empty() else _episode.set_kept(step, true)


## After a hand's edit of [param step] ([param err] "" when it was written): what is made from it for free made again (the script
## from a passage), the timeline read again, the reading told - or what went wrong said.
func _after_hand(step: String, err: String) -> void:
	if not err.is_empty():
		_set_status("Could not change it: " + err)
		if _dock != null and is_instance_valid(_dock):
			_dock.say("Could not change it: " + err)
		return
	if step.begins_with("say:") and not _making():
		_run(["script"], true)
	if _dock != null and is_instance_valid(_dock):
		_dock.say("")
		_dock.reload(_episode.timeline())
	_mark_stale()


## UNDO: the last hand's edit made here taken back - the version it replaced put back (what it was is kept a version back). ""
## done, else why not.
func _take_back() -> String:
	if _undo.is_empty():
		return "nothing has been changed here yet"
	var u: Dictionary = _undo.pop_back()
	if _episode == null or String(u["episode"]) != _episode.dir:
		return "that change was made to another episode"
	var step := String(u["step"])
	var vs := _episode.versions(step)
	for i in range(vs.size() - 1, -1, -1):
		if String((vs[i] as Dictionary).get("digest", "")) == String(u["digest"]):
			var err := _episode.restore(step, i)
			_after_hand(step, err)
			if err.is_empty():
				_set_status("Taken back: %s as it was." % _step_name(step, _facts()))
			return err
	return "what %s was is no longer kept" % step


# --- the inspector ------------------------------------------------------------------------------------

## WHAT IS PICKED, SHOWN TO BE CHANGED ([member TimelineDock.inspector]): an act as its rows ([constant TableRows.ACT]), a cue and
## the words it stands in, a thing on the table ([method _inspect_thing]).
func _inspect(what: Dictionary, box: VBoxContainer) -> void:
	if _episode == null:
		return
	if what.has("thing"):
		_inspect_thing(String(what["thing"]), what, box)
		return
	var it: Dictionary = what.get("item", {}) if what.get("item") is Dictionary else {}
	var src: Array = it.get("source", []) if it.get("source") is Array else []
	if src.size() == 2 and String(src[0]) == "acts" and what.has("track"):
		_inspect_track(int(src[1]), int(what["track"]), it, box)
	elif src.size() == 2 and String(src[0]) == "acts":
		_inspect_act(int(src[1]), box)
	elif src.size() == 3 and String(src[1]) == "cue":
		_heading_to(box, "Cue: %s" % String(it.get("label", "")))
		_line_to(box, "Said in %s. Drag its flag to move it among the words; a cue that names an act or a painted layer starts it there."
			% _step_name(String(src[0]), _facts()))
		_button_to(box, "✎ The words it is in", func() -> void: _edit_step(String(src[0])))
	else:
		_heading_to(box, String(it.get("label", "?")))
		_line_to(box, "%s, at %s" % [String(it.get("kind", "")), Clock.text(float(it.get("at", 0.0)))])


func _acts_list() -> Array:
	var raw: Variant = _episode.read_json("acts")
	var list: Variant = (raw as Dictionary).get("acts", []) if raw is Dictionary else raw
	return list if list is Array else []


func _inspect_act(i: int, box: VBoxContainer) -> void:
	var acts := _acts_list()
	if i < 0 or i >= acts.size() or not (acts[i] is Dictionary):
		_line_to(box, "This act is no longer in the acts.")
		return
	var act: Dictionary = acts[i]
	_heading_to(box, "Act: %s" % String(act.get("name", "")))
	var form := SchemaForm.new()
	form.show_fields(TableRows.ACT, act, {"extra": true})
	form.edited.connect(func(key: String, value: Variant) -> void:
		_after_hand("acts", _hand_write("acts", func() -> String: return set_act_field(i, key, value))))
	box.add_child(form)
	# ...ITS TRACKS, each a press: its law's rows
	var tracks: Array = act.get("tracks", []) if act.get("tracks") is Array else []
	if not tracks.is_empty():
		_line_to(box, "Its tracks:")
		var flow := HFlowContainer.new()
		box.add_child(flow)
		for j in tracks.size():
			var td: Dictionary = tracks[j] if tracks[j] is Dictionary else {}
			var item := {"source": ["acts", i], "label": String(act.get("name", "")), "kind": "span"}
			_button_to(flow, "%s · %s" % [String(td.get("law", "?")), String(td.get("thing", ""))],
				func() -> void: _dock.inspect({"item": item, "track": j}))
	# ...and the things it works, each a press from its own inspector
	var seen := {}
	for t in (act.get("tracks", []) if act.get("tracks") is Array else []):
		var thing := String((t as Dictionary).get("thing", "")) if t is Dictionary else ""
		if not thing.is_empty() and not seen.has(thing):
			seen[thing] = true
			_button_to(box, "→ %s" % thing, func() -> void: _dock.inspect({"thing": thing}))
	_ask_row(box, "acts", "the act \"%s\"" % String(act.get("name", "")))


## TRACK [param j] OF ACT [param i] AS ITS LAW'S ROWS ([method TableRows.law_fields]); a field set is the act's tracks written again,
## refused as any act's field is ([method set_act_field]).
func _inspect_track(i: int, j: int, item: Dictionary, box: VBoxContainer) -> void:
	var acts := _acts_list()
	var tracks: Array = (acts[i] as Dictionary).get("tracks", []) if i >= 0 and i < acts.size() and acts[i] is Dictionary else []
	if j < 0 or j >= tracks.size() or not (tracks[j] is Dictionary):
		_line_to(box, "This track is no longer in the act.")
		return
	var track: Dictionary = tracks[j]
	_heading_to(box, "%s · track %d: %s" % [String((acts[i] as Dictionary).get("name", "")), j + 1, String(track.get("law", "?"))])
	var law := String(track.get("law", ""))
	if Motions.LAWS.has(law):
		_line_to(box, String(Registry.blurb(Motions.LAWS, law)))
	var form := SchemaForm.new()
	form.show_fields(TableRows.law_fields(law), track, {"extra": true})
	form.edited.connect(func(key: String, value: Variant) -> void:
		var err := _hand_write("acts", func() -> String: return set_track_field(i, j, key, value))
		_after_hand("acts", err))
	box.add_child(form)
	_button_to(box, "← The act", func() -> void: _dock.inspect({"item": item}))


## TRACK [param j] OF ACT [param i]: its [param key] set to [param value] (null unsets it), written as the act's tracks. "" written.
func set_track_field(i: int, j: int, key: String, value: Variant) -> String:
	var acts := _acts_list()
	if i < 0 or i >= acts.size() or not (acts[i] is Dictionary):
		return "there is no act %d" % (i + 1)
	var tracks: Array = ((acts[i] as Dictionary).get("tracks", []) as Array).duplicate(true)
	if j < 0 or j >= tracks.size() or not (tracks[j] is Dictionary):
		return "there is no track %d" % (j + 1)
	if value == null:
		(tracks[j] as Dictionary).erase(key)
	else:
		(tracks[j] as Dictionary)[key] = value
	return set_act_field(i, "tracks", tracks)


## ACT [param i]'S [param key] SET TO [param value] (null unsets it) in `acts.json`: refused when the acts would be read otherwise
## than written - a note of their sanitizer's the edit brings ([method Motions.sanitize_acts]). "" written, else why not.
func set_act_field(i: int, key: String, value: Variant) -> String:
	var raw: Variant = _episode.read_json("acts")
	var wrapped := raw is Dictionary
	var acts: Array = _acts_list().duplicate(true)
	if i < 0 or i >= acts.size() or not (acts[i] is Dictionary):
		return "there is no act %d" % (i + 1)
	if value == null:
		(acts[i] as Dictionary).erase(key)
	else:
		(acts[i] as Dictionary)[key] = value
	# ...REFUSED WHERE IT WOULD BE READ OTHERWISE THAN WRITTEN: a note the acts' sanitizer did not have before it, said
	var was := PackedStringArray(Motions.sanitize_acts({"acts": _acts_list()}, _episode.beat_count())["notes"])
	var safe := Motions.sanitize_acts({"acts": acts}, _episode.beat_count())
	var fresh := PackedStringArray()
	for n in safe["notes"]:
		if not was.has(String(n)):
			fresh.append(String(n))
	if (safe["acts"] as Array).size() != acts.size() or not fresh.is_empty():
		return "; ".join(fresh) if not fresh.is_empty() else "the acts would lose one"
	if wrapped:
		var out: Dictionary = (raw as Dictionary).duplicate(true)
		out["acts"] = acts
		return _episode.write_json("acts", out)
	return _episode.write_json("acts", {"acts": acts})


## A THING ON THE TABLE, SHOWN TO BE CHANGED (next/editing.md step 7: "one thing picked, one inspector"): the table from above to move
## it on ([TablePlanView], where the episode stands on the table now), its rows ([constant TableRows.THING]), each of its parts a press
## and the part picked as its rows ([method TableRows.part_fields]); kept in the library, put on from it, taken off the table.
func _inspect_thing(name: String, what: Dictionary, box: VBoxContainer) -> void:
	var med := Director.shown_medium() as TableMedium
	var bp: Dictionary = med.blueprint() if med != null and med.standing_dir() == _episode.dir else {}
	var table: Variant = _episode.read_json("table")
	var td: Dictionary = table if table is Dictionary else {}
	var ti := TableRows.thing_index(td, name)
	var part_path: Array = what.get("path", []) if what.get("path") is Array else []
	if part_path.is_empty() and ti >= 0:
		part_path = TableRows.part_path((td["things"] as Array)[ti], String(what.get("part", "")))
	_heading_to(box, name if not name.is_empty() else "The table")
	if not bp.is_empty():
		var plan := TablePlanView.new()
		plan.show_plan(bp)
		plan.selected = name
		plan.picked.connect(func(n: String) -> void: _dock.inspect({"thing": n}))
		plan.moved.connect(func(n: String, at_cm: Vector2) -> void:
			var err := _hand_write("table", func() -> String: return set_thing_field(n, [], "at", [snappedf(at_cm.x, 0.5), snappedf(at_cm.y, 0.5)]))
			_after_hand("table", err)
			if err.is_empty():
				_set_status("%s moved: it stands there at the next Play, when the table is set again." % n))
		box.add_child(plan)
	else:
		_line_to(box, "Play the episode to see its table from above and move things on it.")
	if ti < 0:
		if not name.is_empty():
			_line_to(box, "%s is not written in the table's data: it comes with the brief or the work." % name)
		_library_row(box, td)
		return
	var thing: Dictionary = (td["things"] as Array)[ti]
	var shown := thing.duplicate()
	shown.erase("parts")
	var fields := TableRows.THING.duplicate()
	fields.erase("parts")
	var form := SchemaForm.new()
	form.show_fields(fields, shown, {"extra": true})
	form.edited.connect(func(key: String, value: Variant) -> void:
		_after_hand("table", _hand_write("table", func() -> String: return set_thing_field(name, [], key, value))))
	box.add_child(form)
	# EACH PART A PRESS, the one picked as its rows
	var parts := _part_list(thing, [], 0)
	if not parts.is_empty():
		_line_to(box, "Its parts:")
		var flow := HFlowContainer.new()
		box.add_child(flow)
		for p in parts:
			var pp: Array = (p as Dictionary)["path"]
			var b := Button.new()
			b.text = String((p as Dictionary)["label"])
			b.toggle_mode = true
			b.button_pressed = pp == part_path
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void: _dock.inspect({"thing": name, "path": pp}))
			flow.add_child(b)
	# ...AND ONE MORE, from the shapes there are ([constant Props.SHAPES]): a part of its own size, of the table's first material
	var add := MenuButton.new()
	add.text = "+ Part ▾"
	add.flat = false
	add.tooltip_text = "Give the thing another part: a shape from those there are, 6 cm, at its middle - set its size and place in its rows."
	for shape in Props.SHAPES:
		add.get_popup().add_item(String(shape))
	add.get_popup().index_pressed.connect(func(k: int) -> void:
		var shape := add.get_popup().get_item_text(k)
		var mats := TableRows.materials_of(td)
		var fresh := {"shape": shape, "size": [6.0, 6.0, 6.0], "at": [0.0, 0.0, 0.0]}
		if not mats.is_empty():
			fresh["material"] = mats[0]
		var n := ((thing.get("parts", []) as Array) if thing.get("parts") is Array else []).size()
		var err := _hand_write("table", func() -> String:
			var t: Variant = _episode.read_json("table")
			var have: Array = ((t as Dictionary)["things"][ti] as Dictionary).get("parts", []) if t is Dictionary else []
			return set_thing_field(name, [], "parts", have + [fresh]))
		_after_hand("table", err)
		if err.is_empty():
			_dock.inspect({"thing": name, "path": ["parts", n]}))
	box.add_child(add)
	var part: Variant = DataPath.at(thing, part_path) if not part_path.is_empty() else null
	if part is Dictionary:
		var pshown := (part as Dictionary).duplicate()
		pshown.erase("parts")
		var pform := SchemaForm.new()
		pform.show_fields(TableRows.part_fields(), pshown, {"extra": true, "materials": TableRows.materials_of(td)})
		pform.edited.connect(func(key: String, value: Variant) -> void:
			_after_hand("table", _hand_write("table", func() -> String: return set_thing_field(name, part_path, key, value))))
		box.add_child(pform)
	var row := HFlowContainer.new()
	box.add_child(row)
	_button_to(row, "✎ In the table's data", func() -> void:
		_edit_step("table")
		if _source_window != null and is_instance_valid(_source_window):
			_source_window.find_text("\"%s\"" % name))
	_button_to(row, "Keep in the library", func() -> void:
		var err := ThingLibrary.keep(thing, td) if not Settings.is_read_only() else "this session is read-only"
		_set_status(("Not kept: " + err) if not err.is_empty() else "%s is kept in the library, to put on another table." % name))
	_button_to(row, "Take off the table", func() -> void:
		var err := _hand_write("table", func() -> String: return take_thing_off(name))
		_after_hand("table", err)
		if err.is_empty():
			_dock.inspect({}))
	_ask_row(box, "table", "the %s" % name)
	_library_row(box, td)


## AN AGENT ASKED ABOUT WHAT IS PICKED (next/editing.md step 9: "'Ask…' opens the step's role ... on the document as it stands,
## only what is picked open to change, the person's note as its brief"): [param step]'s maker made it again with the note, which
## names [param about] and asks for nothing else changed - what stands plays until the new one lands, and Undo can put it back.
func _ask_row(box: Container, step: String, about: String) -> void:
	var maker := String(TableProducer.MAKERS.get(step.get_slice(":", 0), ""))
	if maker.is_empty():
		return
	var row := HBoxContainer.new()
	box.add_child(row)
	var note := LineEdit.new()
	note.placeholder_text = "What the %s should change about %s" % [maker, about]
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	var go := Button.new()
	go.text = "Ask the %s" % maker
	go.focus_mode = Control.FOCUS_NONE
	go.tooltip_text = ("The %s makes this step again from what stands, told your note about %s alone and to change nothing else. "
		+ "Spends the agent's quota; what stands plays until the new one lands.") % [maker, about]
	go.pressed.connect(func() -> void:
		var err := ask_about(step, about, note.text)
		if err.is_empty():
			note.text = ""
		_dock.say(err if not err.is_empty() else "Asked the %s about %s: what stands plays until the new one lands." % [maker, about]))
	row.add_child(go)


## [param step]'S MAKER ASKED AGAIN about [param about] with [param note] ([method _ask_row]). "" asked, else why not.
func ask_about(step: String, about: String, note: String) -> String:
	if note.strip_edges().is_empty():
		return "write what should change first"
	if _episode == null or not _episode.has(step):
		return "%s is not made yet" % step
	if Settings.is_read_only():
		return "this session is read-only"
	var before := _episode.digest(step)
	if not before.is_empty():
		_undo.append({"episode": _episode.dir, "step": step, "digest": before})
	if _producer.running:
		_producer.stop()
	_run([step], true, "About %s alone - change nothing else in it: %s" % [about, note.strip_edges()])
	_mark_stale()
	return ""


## "+ New thing", "+ From the library" and the free look: a thing put on this table at the middle of the reading, to be dragged where
## it goes - a box of its own, or one kept in the library - and the eye let go of to look the set over ([method TableMedium.free_look]).
func _library_row(box: Container, table: Dictionary) -> void:
	var row := HFlowContainer.new()
	box.add_child(row)
	_button_to(row, "+ New thing", func() -> void:
		var named := "new thing"
		var n := 2
		while TableRows.thing_index(table, named) >= 0:
			named = "new thing %d" % n
			n += 1
		var mats := TableRows.materials_of(table)
		var part := {"shape": "box", "size": [6.0, 6.0, 6.0]}
		if not mats.is_empty():
			part["material"] = mats[0]
		var err := _hand_write("table", func() -> String:
			var t: Variant = _episode.read_json("table")
			var out: Dictionary = (t as Dictionary).duplicate(true) if t is Dictionary else {}
			var things: Array = out.get("things", []) if out.get("things") is Array else []
			things.append({"name": named, "at": [0.0, 0.0], "parts": [part]})
			out["things"] = things
			return _episode.write_json("table", out))
		_after_hand("table", err)
		if err.is_empty():
			_dock.inspect({"thing": named}))
	var med := Director.shown_medium() as TableMedium
	if med != null and med.standing_dir() == _episode.dir:
		var look := CheckButton.new()
		look.text = "Free look"
		look.focus_mode = Control.FOCUS_NONE
		look.button_pressed = med.looking_freely()
		look.tooltip_text = "Look the set over: drag with the right button on the show to turn about the table, the wheel to draw in or out. Off, the show's own eye is back."
		look.toggled.connect(func(on: bool) -> void: med.free_look(on))
		row.add_child(look)
	var names := ThingLibrary.names()
	if names.is_empty():
		return
	var add := MenuButton.new()
	add.text = "+ From the library ▾"
	add.flat = false
	add.tooltip_text = "Put a thing kept in the library on this table: it stands near the middle, to be moved where it goes."
	for n in names:
		add.get_popup().add_item(String(n))
	add.get_popup().index_pressed.connect(func(i: int) -> void:
		var entry := ThingLibrary.read(add.get_popup().get_item_text(i))
		var err := _hand_write("table", func() -> String:
			var t: Variant = _episode.read_json("table")
			return _episode.write_json("table", ThingLibrary.put_on(t if t is Dictionary else {}, entry)) if not entry.is_empty() else "it is not in the library")
		_after_hand("table", err)
		if err.is_empty():
			_set_status("%s is on the table: it stands the next time the table is set." % add.get_popup().get_item_text(i)))
	box.add_child(add)


## Thing [param thing]'s parts, depth first, each `{label, path}` - named by its name, else its shape.
func _part_list(node: Dictionary, path: Array, depth: int) -> Array:
	var out: Array = []
	var parts: Array = node.get("parts", []) if node.get("parts") is Array else []
	for i in parts.size():
		if not (parts[i] is Dictionary) or depth > 4:
			continue
		var p: Dictionary = parts[i]
		var pp := path + ["parts", i]
		var label := String(p.get("name", "")) if not String(p.get("name", "")).is_empty() else String(p.get("shape", "part"))
		out.append({"label": label, "path": pp})
		out.append_array(_part_list(p, pp, depth + 1))
	return out


## THING [param name]'S [param key] (at [param path] inside it: [] for the thing, a part's path for a part) SET TO [param value] in
## `table.json` - null unsets it. "" written, else why not.
func set_thing_field(name: String, path: Array, key: String, value: Variant) -> String:
	var raw: Variant = _episode.read_json("table")
	if not (raw is Dictionary):
		return "the table is not made yet"
	var table: Dictionary = (raw as Dictionary).duplicate(true)
	var ti := TableRows.thing_index(table, name)
	if ti < 0:
		return "%s is not on the table" % name
	var node: Variant = DataPath.at((table["things"] as Array)[ti], path) if not path.is_empty() else (table["things"] as Array)[ti]
	if not (node is Dictionary):
		return "that part is no longer there"
	if value == null:
		(node as Dictionary).erase(key)
	else:
		(node as Dictionary)[key] = value
	return _episode.write_json("table", table)


## THING [param name] TAKEN OFF THE TABLE (the table's data without it; the version with it kept a version back). "" written.
func take_thing_off(name: String) -> String:
	var raw: Variant = _episode.read_json("table")
	if not (raw is Dictionary):
		return "the table is not made yet"
	var table: Dictionary = (raw as Dictionary).duplicate(true)
	var ti := TableRows.thing_index(table, name)
	if ti < 0:
		return "%s is not on the table" % name
	(table["things"] as Array).remove_at(ti)
	return _episode.write_json("table", table)


func _heading_to(box: Container, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.clip_text = true
	box.add_child(l)


func _line_to(box: Container, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.7)
	box.add_child(l)


func _button_to(box: Container, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	box.add_child(b)


## A CLICK ON THE TABLE NAMES WHAT IS THERE (next/editing.md step 7: "a click on the stage names a thing and its part"): said, and
## shown in the timeline's inspector to be changed ([method pick_thing]). A click that names nothing goes on to what else wants it.
func _unhandled_input(event: InputEvent) -> void:
	# A FREE LOOK, while one is on: a right-drag turns about the table, the wheel draws in or out
	var med := Director.shown_medium() as TableMedium
	if med != null and med.looking_freely():
		var drag := event as InputEventMouseMotion
		if drag != null and (drag.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			med.look_by(-drag.relative.x * 0.006, -drag.relative.y * 0.006)
			get_viewport().set_input_as_handled()
			return
		var wheel := event as InputEventMouseButton
		if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
				and Director.frame_rect.has_point(wheel.position):
			med.look_by(0.0, 0.0, 0.9 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
			return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _episode == null or not is_visible_in_tree():
		return
	var hit := Director.pick(mb.position)
	if not hit.has("thing") or String(hit["thing"]).is_empty():
		return
	get_viewport().set_input_as_handled()
	pick_thing(String(hit["thing"]), String(hit.get("part", "")))


## [param thing] (and its [param part]) PICKED ON THE TABLE: named on the status line, and shown in the timeline's inspector - the
## table from above, its rows and its parts ([method _inspect_thing]). "" shown, else why not.
func pick_thing(thing: String, part := "") -> String:
	_set_status("On the table: %s%s." % [thing, " - its %s" % part if not part.is_empty() and part != thing else ""])
	var dock := open_dock()
	if dock == null:
		return "no episode is open"
	dock.inspect({"thing": thing, "part": part})
	return ""


## THE DATA A HAND MAY EDIT AS JSON (next/editing.md step 4), each step taken back only as a map.
const EDITABLE_DATA := ["plan", "table", "acts", "skin", "layers", "model"]


## ✎ ON [param r], where what [param step] made can be changed by hand: the script whole, a passage alone, the data as JSON, a
## picture by one's own - each written as a hand's version, kept (TableEpisode.set_kept), what stood a version back.
func _edit_of(r: PipelineRow, step: String) -> void:
	if not _episode.has(step) and not _episode.by_hand(step):
		return
	if step == "script":
		r.edit_tip = "Edit the whole script: the words between its marks go back to their passages, each kept as yours."
	elif step.begins_with("say:"):
		r.edit_tip = "Edit these words by hand: kept as yours, the script put together again from them."
	elif step in EDITABLE_DATA:
		r.edit_tip = "Edit what was made, as JSON: taken back if it is still a map, kept as yours, what stood a version back."
	elif step.begins_with("image:"):
		r.edit_tip = "Use a picture of your own instead: imported over this one, kept as yours, what stood a version back."
	else:
		return
	r.edit = _edit_step.bind(step)


func _edit_step(step: String) -> void:
	if _episode == null:
		return
	if step.begins_with("image:"):
		_import_picture(step)
		return
	# A PAINTED DESIGN, ELEMENT BY ELEMENT ([DesignWindow]): where its elements carry their plans (a painter laid them)
	if step == "skin" and _design_planned():
		_edit_design()
		return
	if _source_window == null or not is_instance_valid(_source_window):
		_source_window = SourceWindow.new()
	var w := _source_window
	w.notes = Callable()
	# ...WITH ITS VERSIONS, any of them put back (TableEpisode.versions, restore): nothing a ⟳ or a hand replaced is out of reach
	w.versions = func() -> PackedStringArray:
		var out := PackedStringArray()
		for v in _episode.versions(step):
			var vd: Dictionary = v
			var by := String(vd.get("by", ""))
			out.append("%s%s" % ["made by the %s" % by if not by.is_empty() and by != "hand" else ("yours" if by == "hand" else "as it was"),
				", " + Time.get_datetime_string_from_unix_time(int(vd.get("at", 0)), true).substr(5, 11) if int(vd.get("at", 0)) > 0 else ""])
		return out
	w.restore = func(i: int) -> String:
		var err := _episode.restore(step, i)
		if err.is_empty() and step.begins_with("say:") and not _making():
			_run(["script"], true)
		_mark_stale()
		return err
	# ...AND ITS MAKER ASKED AGAIN WITH A NOTE (next/editing.md step 9), where an agent made it: what stands plays until the new one lands
	var maker := String(MAKERS.get(step.get_slice(":", 0), ""))
	w.ask = Callable() if maker.is_empty() or step == "script" else func(note: String) -> String:
		if _producer.running:
			_producer.stop()
		_run([step] + (TOGETHER.get(step, []) as Array), true, note)
		_mark_stale()
		return ""
	w.ask_who = "the " + maker if not maker.is_empty() else ""
	w.reread = func() -> String:
		return _episode.read_text(step) if not step in EDITABLE_DATA else JSON.stringify(_episode.read_json(step), "\t")
	if step == "script":
		w.take = func(text: String) -> String:
			var err := _producer.write_script(text)
			_mark_stale()
			return err
		w.open_on("The script - %s" % _step_name(step, _facts()), _episode.read_text(step), self)
	elif step.begins_with("say:"):
		w.take = func(text: String) -> String:
			var err := _episode.write_text(step, text.strip_edges())
			if err.is_empty():
				err = _episode.set_kept(step, true)
			if err.is_empty() and not _making():
				_run(["script"], true)
			_mark_stale()
			return err
		w.open_on(_step_name(step, _facts()), _episode.read_text(step), self)
	else:
		w.take = func(text: String) -> String:
			var j := JSON.new()
			if j.parse(text) != OK:
				return "it is not JSON: %s (line %d)" % [j.get_error_message(), j.get_error_line()]
			if not (j.data is Dictionary):
				return "it must be a map, as it was"
			var err := _episode.write_json(step, j.data)
			if err.is_empty():
				err = _episode.set_kept(step, true)
			_mark_stale()
			return err
		if step == "acts":
			w.notes = func() -> PackedStringArray:
				return PackedStringArray(Motions.sanitize_acts(_episode.read_json("acts"), _episode.beat_count())["notes"])
		w.open_on(_step_name(step, _facts()), JSON.stringify(_episode.read_json(step), "\t"), self)


## LAYER [param k] LAID AGAIN ON THE TABLE, ALONE ([method TableProducer.lay_layer]).
func _lay_layer(k: int) -> void:
	if _episode == null or Settings.is_read_only():
		return
	if _producer.running:
		_producer.stop()
	_producer.spec = _spec()
	var err := _producer.lay_layer(k)
	_set_status(("Could not lay it again: " + err) if not err.is_empty() else "Layer %d is being laid again, alone; the rest stay as they are." % k)
	_mark_stale()


## Whether the design's elements carry the plans a painter laid them by (beat, seconds, tool): then they are rows.
func _design_planned() -> bool:
	var doc: Variant = _episode.read_json("skin")
	for g in ((doc as Dictionary).get("designs", []) if doc is Dictionary else []):
		for e in ((g as Dictionary).get("elements", []) if g is Dictionary else []):
			if e is Dictionary and (e as Dictionary).get("plan") is Dictionary:
				return true
	return false


## THE DESIGN'S ELEMENTS AS ROWS ([DesignWindow]): written back as a hand's version, kept, and the work made again from it at once -
## computed from the painting, it costs no agent (unless the work is kept, when it stays as it is).
func _edit_design() -> void:
	if _design_window == null or not is_instance_valid(_design_window):
		_design_window = DesignWindow.new()
	var beats: Array = ["intro"]
	for k in range(1, _episode.beat_count() + 1):
		beats.append(str(k))
	beats.append("close")
	_design_window.take = func(doc: Dictionary) -> String:
		var err := _episode.write_json("skin", doc)
		if err.is_empty():
			err = _episode.set_kept("skin", true)
		if err.is_empty() and _episode.has("acts") and not _episode.kept("acts") and not _making():
			_run(["acts"], true)
		_mark_stale()
		return err
	_design_window.open_on(_episode.read_json("skin"), beats, self)


## A PICTURE OF ONE'S OWN for [param step]: picked from disk, written over its picture as a PNG (what stood a version back), kept.
func _import_picture(step: String) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
	fd.title = "A picture for %s" % _step_name(step, _facts())
	fd.file_selected.connect(func(path: String) -> void:
		var err := import_picture(step, path)
		_set_status(("Could not use it: " + err) if not err.is_empty() else "%s is your picture now." % _step_name(step, _facts()))
		_mark_stale()
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


## [param path]'s picture over [param step]'s, as a PNG, kept as a hand's version. "" done, else why not.
func import_picture(step: String, path: String) -> String:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return "%s is not a picture this can read" % path.get_file()
	var err := _episode.keep_version(step)
	if not err.is_empty():
		return err
	var target := _episode.file_of(step)
	if img.save_png(target + ".part.png") != OK or DirAccess.rename_absolute(target + ".part.png", target) != OK:
		return "could not write %s" % target.get_file()
	return _episode.set_kept(step, true)


## What [param step] says of what it made - kept with the facts: it is the file's, and the file's being there is theirs.
func _said_of(step: String, f: Dictionary) -> String:
	var kept: Dictionary = f["said"]
	if kept.has(step):
		return String(kept[step])
	var said := ""
	var plan: Variant = f["plan"]
	if step == "plan":
		said = String((plan as Dictionary).get("episode_title", "")) if plan is Dictionary else ""
	elif step == "draw":
		var n := int(f["cards"])
		said = ("%d card%s" % [n, "" if n == 1 else "s"]) if _episode.has("draw") else ""
	elif step == "model":
		var made := _episode.model()
		said = "%s, %d parts" % [String(made.get("name", "")), (made.get("parts", []) as Array).size()] if not made.is_empty() else ""
	elif step == "skin":
		var doc: Variant = _episode.read_json("skin") if _episode.has("skin") else null
		var names := PackedStringArray()
		for g in ((doc as Dictionary).get("designs", []) if doc is Dictionary else []):
			if g is Dictionary:
				names.append("%s, %d elements" % [String((g as Dictionary).get("name", "")), ((g as Dictionary).get("elements", []) as Array).size()])
		said = "; ".join(names)
	elif step == "table":
		var things := _table_things()
		said = "%d thing%s" % [things.size(), "" if things.size() == 1 else "s"] if not things.is_empty() else ""
	elif step == "acts":
		var acts: Variant = _episode.read_json("acts") if _episode.has("acts") else null
		var n := ((acts as Dictionary).get("acts", []) as Array).size() if acts is Dictionary and (acts as Dictionary).get("acts") is Array else 0
		said = ("%d act%s" % [n, "" if n == 1 else "s"]) if _episode.has("acts") else ""
	elif step.begins_with("say:"):
		var words := _episode.read_text(step) if _episode.has(step) else ""
		said = "%d words" % words.split(" ", false).size() if not words.is_empty() else ""
		# ...and a beat's name, as the plan gives it
		if bool(f["cardless"]) and step.get_slice(":", 1).is_valid_int():
			var name := _beat_name(plan, int(step.get_slice(":", 1)))
			said = (name + (" - " + said if not said.is_empty() else "")) if not name.is_empty() else said
	kept[step] = said
	return said


## What the agents making [param step] are doing, "" while none is: who, what, and for one with tools its last call.
func _doing_of(step: String) -> String:
	var a := _producer.activity_of(step)
	if a.is_empty():
		return ""
	var piece := "%s %s" % [String(MAKERS.get(step.get_slice(":", 0), "agent")), a]
	var calls := _tools_progress(step) if step in ["model", "skin", "table", "acts", "prep"] or (step.begins_with("say:") and _episode.wants_game()) else ""
	if not calls.is_empty():
		# THE BUDGET IN VIEW: a run with no clock ends at its last picture, and the row says how near that is
		var looked: Array = _producer.looks_of(step)
		piece += " - %s%s" % ["%d of %d looks - " % looked if looked.size() == 2 else "", calls]
	return piece


## Whether everything [param step] is made from is made.
func _ready_to_make(step: String, f: Dictionary) -> bool:
	var kept: Dictionary = f["ready"]
	if not kept.has(step):
		var ready := true
		for need in (f["needs"] as Dictionary).get(step, []):
			ready = ready and _episode.has(String(need))
		kept[step] = ready
	return bool(kept[step])


## WHAT [param step]'S ⟳ THROWS AWAY besides what it remakes: "" for nothing, and it starts at once; otherwise the row goes
## amber and asks (the menu had been all that stood between a stray click on Plan and every painting and reading).
func _asks_of(step: String, f: Dictionary) -> String:
	var kept: Dictionary = f["asks"]
	if kept.has(step):
		return String(kept[step])
	var lost := PackedStringArray()
	var with_it: Array = TOGETHER.get(step, [])
	for s in (f["lost"] as Dictionary).get(step, []):
		# the script is only the readings put together, and what is made along with it is remade now
		if String(s) != "script" and not with_it.has(s) and _episode.has(String(s)):
			lost.append(_step_name(String(s), f))
	var said := ""
	if not lost.is_empty():
		var named := ", ".join(lost.slice(0, NAMED_MOST))
		if lost.size() > NAMED_MOST:
			named += " and %d more" % (lost.size() - NAMED_MOST)
		said = ("Nothing is thrown away - what stands goes a version back - but what was made from it goes stale, and Generate "
			+ "makes it again unless it is locked: %s." % named)
	kept[step] = said
	return said


## [param step] as a person would name it among others: "Card 3 Reading".
func _step_name(step: String, f: Dictionary) -> String:
	var word := String(f["word"])
	var k := step.get_slice(":", step.get_slice_count(":") - 1)
	if not k.is_valid_int():
		return String(Registry.field(STEPS, step, "label", step))
	if bool(f["cardless"]):
		return "%s %s" % [word, k]
	var kind := step.substr(0, step.length() - k.length()) + "K"
	return "%s %s %s" % [word, k, String(Registry.field(STEPS, kind, "label", step))]


## WHAT A CARD'S GROUP SAYS: the card, under its beat's name, as the plan gives it.
func _group_said(group: String) -> String:
	var at := group.rsplit(" ", true, 1)
	if at.size() != 2 or not String(at[1]).is_valid_int() or _episode == null:
		return ""
	var k := int(at[1])
	var f := _facts()
	var cards: Array = (f["doc"] as Dictionary).get("cards", [])
	var text := ""
	if k - 1 < cards.size():
		var c: Dictionary = cards[k - 1]
		text = "%s%s%s" % [String(c.get("name", "")), " (reversed)" if bool(c.get("reversed", false)) else "",
			" - jumper" if bool(c.get("jumper", false)) else ""]
	var place := _beat_name(f["plan"], k)
	return (place + (": " + text if not text.is_empty() else "")) if not place.is_empty() else text


## What the episode as a whole says, over the rows.
func _pipeline_line() -> String:
	if _episode == null:
		return ""
	var note := ""
	if bool(_facts()["complete"]):
		note = "Ready - press Play to watch it, or export it."
	elif _making():
		note = "Making episode #%d…" % _episode.seed
	elif _episode.has("plan"):
		note = "Partly made - Generate finishes it."
	else:
		note = "Not made yet - Generate makes it."
	if _brief_changed and _episode.has("plan"):
		note += " The brief has changed since this episode was made; New episode uses it."
	return note


## What the set dresser put on the picked episode's table, by name - read again only when the file
## changes (the rows refresh four times a second).
func _table_things() -> PackedStringArray:
	var path := _episode.file_of("table") if _episode != null else ""
	var mt := FileAccess.get_modified_time(path) if not path.is_empty() and FileAccess.file_exists(path) else -1
	if mt != int(_table_seen.get("mt", -2)) or path != String(_table_seen.get("path", "")):
		var names := PackedStringArray()
		var t: Variant = _episode.read_json("table") if mt >= 0 else null
		if t is Dictionary and (t as Dictionary).get("things") is Array:
			for th in (t as Dictionary)["things"]:
				if th is Dictionary:
					names.append(String((th as Dictionary).get("name", "a thing")))
		_table_seen = {"mt": mt, "path": path, "names": names}
	return _table_seen["names"]


## WHAT AN AGENT WITH TOOLS IS DOING while it makes [param step] - the set dresser setting the table, the
## puppeteer blocking the work: its last call, from the job's `tools.jsonl` (read again only when that file
## changes) - a run of many minutes otherwise shows nothing but its glyph. "" before its first call, or for
## an agent with no tools.
func _tools_progress(step: String) -> String:
	var path := _episode.job_dir(step).path_join("tools.jsonl") if _episode != null else ""
	var seen: Dictionary = _tools_log.get(step, {})
	var mt := FileAccess.get_modified_time(path) if not path.is_empty() and FileAccess.file_exists(path) else -1
	if mt != int(seen.get("mt", -2)) or path != String(seen.get("path", "")):
		var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false) if mt >= 0 else PackedStringArray()
		var last: Variant = JSON.parse_string(String(lines[lines.size() - 1])) if not lines.is_empty() else null
		var said := ""
		if last is Dictionary:
			said = "%s (call %d): %s" % [String((last as Dictionary).get("tool", "")), lines.size(),
				String((last as Dictionary).get("text", "")).get_slice("\n", 0).left(90)]
		seen = {"mt": mt, "path": path, "said": said}
		_tools_log[step] = seen
	return String(seen.get("said", ""))


## Beat [param k]'s own name in [param plan] (a position of its spread, a beat of a show with no cards), or "".
static func _beat_name(plan: Variant, k: int) -> String:
	var spread: Variant = (plan as Dictionary).get("spread") if plan is Dictionary else null
	var pos: Array = ((spread as Dictionary)["positions"] as Array) if spread is Dictionary and (spread as Dictionary).get("positions") is Array else []
	var b: Variant = pos[k - 1] if k >= 1 and k - 1 < pos.size() else {}
	return String((b as Dictionary).get("name", "")) if b is Dictionary else ""


## EACH REFRESH, WHAT THE CARD ITSELF SHOWS: the picked episode's entry, the deck, Delete, and the upload's fields.
func _refresh_card() -> void:
	if _episode == null or _episode_pick == null:
		return
	var plan: Variant = _facts()["plan"]
	# THE PICKER FOLLOWS THE EPISODE: its entries are written when the list is filled, so an episode
	# made while it was open went on saying "(not made yet)" until another was picked and back
	var at := _episode_seeds.find(int(_knobs["seed"]))
	if at >= 0:
		var label := _episode_label(int(_knobs["seed"]),
			String((plan as Dictionary).get("episode_title", "")) if plan is Dictionary else "")
		if _episode_pick.get_item_text(at) != label:
			_episode_pick.set_item_text(at, label)
	# the deck, recounted whenever the brief changes
	if _text != null and _text.get_version() != _deck_seen and _deck_note != null:
		_deck_seen = _text.get_version()
		var own := CardDeck.parse(_text.text)
		_deck_note.text = ("Deck: %d cards, from the brief's Cards." % own.size()) if not own.is_empty() \
			else "Deck: the producer's choice, each episode (the brief lists no cards)."
	_del_btn.disabled = not DirAccess.dir_exists_absolute(_episode.dir) or _exporting(_episode)
	_fill_upload_fields()


# --- the YouTube fields ------------------------------------------------------------------------

## WHAT THE EPISODE GOES UP TO YOUTUBE AS. The title is the episode's - its plan's, the Script card's
## Episode (2026-10-25: it had been a box on this card, and %episode% no other note's), written straight
## back into the plan ([method name_episode]), so the export's file name, the episode picker,
## `upload.md` and the YouTube card's `%episode%` all say what the panel says. The description and THE
## TAGS ARE THE SHOW'S, on the YouTube card when the note has one (2026-10-07): the description in the
## show's block, the tags its document's own `tags:` line, the way North Star's chapters keep theirs,
## edited as chips and going up with every episode. Nothing of any one episode is kept in the document
## (the user, 2026-10-06: "I just don't want to store a bunch of episode-specific logic in the
## frontmatter of a markdown file").
##
## The show's description and tags, on the YouTube card ([member YouTubeCard.extra]).
func youtube_built(card: YouTubeCard) -> void:
	_youtube = card
	_build_upload_fields(card.extra)
	_fill_upload_fields(true)


func _build_upload_fields(box: VBoxContainer) -> void:
	_yt_desc = TextField.new("Description", "No description yet - click to write one",
		"The video's description. The chapters its readers named, timed from the export "
		+ "itself, are added under it as the video goes up.")
	_yt_desc.text_changed.connect(_upload_edited)
	box.add_child(_yt_desc)
	_yt_tags = TagField.new()
	_yt_tags.tooltip_text = ("The show's tags - its document's `tags:` line - the one list every episode goes up "
		+ "with. With \"Write each episode's tags\" ticked above, the writer replaces it with tags written for "
		+ "each episode. × removes one; type in the box and a comma (or Enter) makes it a tag. YouTube takes "
		+ "500 characters of tags in all; a dimmed tag is past that.")
	_yt_tags.changed.connect(_save_tags)
	box.add_child(_yt_tags)
	_yt_note = Label.new()
	_yt_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_yt_note.add_theme_font_size_override("font_size", 11)
	_yt_note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_yt_note)


func _upload_edited() -> void:
	if _syncing:
		return
	_yt_dirty = 0.8
	_refresh_upload_note()


func _upload_focused() -> bool:
	return _yt_desc != null and _yt_desc.editing()


static func _mtime(path: String) -> int:
	return FileAccess.get_modified_time(path) if not path.is_empty() and FileAccess.file_exists(path) else -1


## THE FIELDS SHOW THE SHOW'S GLOBAL VALUES from its document at once - on open, on New episode, on
## any pick (the user: "it should have been grabbed immediately, since that stuff is global"): the
## description and the tags as the show keeps them. Refilled when another episode is picked or its plan
## changes on disk, unless the description is being typed in, or at once with [param force]. A new
## upload refreshes the note.
func _fill_upload_fields(force := false) -> void:
	if _yt_desc == null:
		return
	var path := _episode.file_of("plan") if _episode != null else ""
	var mt := _mtime(path)
	var ups := _mtime(_episode.file_of("youtube") if _episode != null else "")
	if ups != int(_yt_seen.get("ups", -2)):
		_yt_seen["ups"] = ups
		_refresh_upload_note()
	var same := mt == int(_yt_seen.get("mt", -2)) and path == String(_yt_seen.get("path", ""))
	if not force and (same or _yt_dirty > 0.0 or _upload_focused()):
		return
	_yt_seen["path"] = path
	_yt_seen["mt"] = mt
	var was := _syncing
	_syncing = true
	if _yt_desc.text != _cur_desc:
		_yt_desc.text = _cur_desc
	_syncing = was
	_refresh_show_fields()


## The show's tags from its document, unless they are being typed in.
func _refresh_show_fields() -> void:
	if _yt_tags != null and not _yt_tags.typing():
		_yt_tags.set_tags(_show_tags())
	_refresh_upload_note()


## A SHOW THAT HAS NO DESCRIPTION OR TAGS YET TAKES THE PICKED EPISODE'S, once, so the section is
## never empty for want of a first one: the producer writes both with every plan. After that they
## are the show's, edited here. Run from the frame loop, not on open, so the document's autosave
## sees the change (the snapshot a just-opened document is compared with is taken after it opens);
## never in a process that may not write (a probe).
func _seed_globals() -> void:
	if not Settings.is_read_only():
		_seed_from_plan()


func _seed_from_plan() -> void:
	# the description and tags are the YouTube card's: a note without one is not given them
	if _episode == null or not _episode.has("plan") or _doc == null or _yt_desc == null:
		return
	if _cur_desc.is_empty() and _yt_dirty <= 0.0 and not _yt_desc.editing():
		var d := String(_episode.upload_notes()["description"]).strip_edges()
		if not d.is_empty():
			_cur_desc = d
			_fill_upload_fields(true)
	if _show_tags().is_empty() and not _yt_tags.typing():
		var tags: PackedStringArray = _episode.upload_notes()["tags"]
		if not tags.is_empty():
			_doc.set_field("tags", ", ".join(tags))
			_refresh_show_fields()


## The edited description - only when it was edited (with [param force], when the edit's wait is over):
## the show's, kept in its block.
func _flush_upload_fields(force := false) -> void:
	if not force and _yt_dirty <= 0.0:
		return
	_yt_dirty = 0.0
	if _yt_desc != null:
		_cur_desc = _yt_desc.text.strip_edges()
	_refresh_upload_note()


## A tag added or removed: the show's `tags:` line, written at once.
func _save_tags() -> void:
	if _syncing or _doc == null:
		return
	if not _doc.set_field("tags", ", ".join(_yt_tags.get_tags())):
		_set_status("The tags could not be saved into the show's document.")
	_refresh_upload_note()


## Under the fields: what goes up as tags against YouTube's limit, and where the episode already is
## on YouTube. A tag past the limit is dimmed in the field, saying so. The card's own line - the
## title as it goes up - follows the episode's title.
func _refresh_upload_note() -> void:
	if _youtube != null:
		_youtube.refresh()
	if _yt_note == null:
		return
	var own := _yt_tags.get_tags() if _yt_tags != null else PackedStringArray()
	var fitted := YouTube.fit_tags(Array(own))
	if _yt_tags != null:
		_yt_tags.mark(YouTube.left_out(own))
	if _episode == null or not _episode.has("plan"):
		_yt_note.text = "Generate the plan first: the producer writes the episode's title."
		return
	var t := ("These %d tag%s go up, %d of YouTube's %d characters." % [fitted.size(),
		"" if fitted.size() == 1 else "s", YouTube.tags_length(fitted), YouTube.TAGS_MAX]) if not fitted.is_empty() \
		else "No tags yet: the ones added here are the show's, and go up with every episode."
	var ups := _episode.uploads()
	if not ups.is_empty():
		var last: Dictionary = ups[ups.size() - 1]
		t += " On YouTube: %s (%s)." % [String(last.get("url", "")), String(last.get("privacy", ""))]
	_yt_note.text = t

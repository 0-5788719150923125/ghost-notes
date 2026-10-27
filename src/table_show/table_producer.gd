extends RefCounted
class_name TableProducer

## TableProducer - makes whatever an episode is missing, in the order a reading happens.
##
## THE LOOP. Every [method tick] looks at the episode's steps (see [TableEpisode]) and starts
## each one whose inputs exist and whose own file does not; when a job ends, its output is
## checked and written into the episode, which is what lets the steps after it start. So the
## order is not a script anywhere - it falls out of what each step is made from:
##
##   plan       the producer plans the episode: title, angle, how many cards (the spread), the deck's whole look
##   draw       the deck is shuffled and cut (here, from the seed - no agent touches it)
##   design:K   the deck's creator draws up card K: its illustration and its booklet entry
##   image:*    the painter makes the back, the cloth, the room, then each card in turn
##   check:K    the art director looks at card K's painting beside what it was asked to show and what
##              is printed with it, and keeps it or sends it back to be painted again
##   table      the set dresser sets the reader's table, looking at the cloth - and, given a writer
##              that takes tools, looking at what it builds as it builds it ([SetDresserTools])
##   say:intro  the reader opens the video, shuffling, knowing no card
##   say:K      the reader turns over card K - knowing cards 1..K and what it said before, and
##              LOOKING AT card K's painting, so the words are about the picture on screen
##   say:close  the reader closes, with the whole spread on the table
##   acts       the puppeteer blocks the WORK the plan has done at the table (next/table_work.md), on the
##              set table with the cards as drawn - through [PuppeteerTools] when its writer takes tools
##   say:work:K the reader talks card K's work through as it is done, told its acts and no later beat's
##   script     the passages and the marks between them, ready for the voice
##
## HOW MANY CARDS, AND WHETHER ANY, ARE THE PRODUCER'S (the user, 2026-10-26: "The 'draw' option is confusing
## ... leave it up to the agents to calculate the number of cards to draw (if they are even using cards at all).
## Then, in the markdown, we can specify a range"): the brief says in its own words what its episodes draw, and
## the plan's spread is the draw - as many cards as it has positions, at most [constant SPREAD_MOST]. It had been
## the seed's pick in a range on the Episode card, the producer told to plan exactly that many.
##
## A SHOW THAT DRAWS NO CARDS (its producer plans beats, [method TableEpisode.cardless]; the user, 2026-10-26: "we
## should start with a mask every time - and just paint it while talking") is planned in BEATS: no deck, no design,
## no card painted or checked - the plan, the cloth and the room, the table, the work, and a passage per beat
## said while its work is done.
##
## NO CHEATING. The reader's passages are made strictly in drawing order, each from the passages
## before it and the cards drawn so far ([method _drawn] stops at K), so an early passage was
## written, and is kept, before any later card was ever put in front of a writer. The painter and
## the designer see the cards they make and nothing of the reading; the reader never sees their
## prompts, only the booklet entry printed for a card that has been turned over.
##
## Nothing runs on its own: [method start] is a person pressing Generate, because every step
## spends the author's quota - and a person asking for ONE part ([param only]) gets that part:
## what follows from it waits for Generate. Only the two steps that cost nothing and are a pure
## function of what they follow - the shuffle and assembling the script - come along on their own.

signal changed

## A step whose job fails is tried this many more times before the episode stops on it.
const RETRIES := 1
## The most beats a show that draws no cards is planned in, between its intro and its close.
const BEATS_MOST := 8
## The most cards an episode draws: a spread planned longer is cut to it ([method _land_plan]).
const SPREAD_MOST := 10
## How many times the art director may send one card's painting back ([method _land_check]): past
## that the last painting stands, and the reader is told what it gets wrong.
const REPAINTS := 2
## The most lines a written card's designer may write on it ([method _land_design]).
const WRITING_MOST := 16
## How much of the deck goes into a card's references: the back, the first card (which set the
## hand) and the most recent - the [Illustrations] chain, for the same reason: more attachments
## make a painter worse at matching, not better.
const CHAIN_MAX := 2
## The chance the first card is a jumper, when the plan lets one fly (`staging.jumpers`).
const JUMPER_CHANCE := 0.3
## The steps made here, with no agent and no quota - see the class note.
const LOCAL := ["draw", "script"]

var episode: TableEpisode
## {title, brief, deck, chooses, writer, painter} - how many cards are drawn, whether they come up reversed
## and whether one jumps are the plan's ([method _land_plan], [method CardTable.staging_of]), never the author's
var spec: Dictionary = {}
var running := false
## The steps this run was asked for; empty for the whole episode.
var only: Array = []

var _jobs := {}        # step -> AgentJobs id
var _tools := {}       # step -> {url, set}: the tools a step's agent is working with, until it lands
var _errors := {}      # step -> why it failed, once it is out of tries
var _tries := {}       # step -> runs started


func _init(ep: TableEpisode, sp: Dictionary) -> void:
	episode = ep
	spec = sp


## Make what is missing: every step, or only [param steps] (and the free steps that follow them).
func start(steps: Array = []) -> void:
	_errors.clear()
	_tries.clear()
	only = steps.duplicate()
	running = true
	tick()
	changed.emit()


func stop() -> void:
	running = false
	for step in _jobs:
		AgentJobs.cancel(String(_jobs[step]))
		AgentJobs.forget(String(_jobs[step]))
	_jobs.clear()
	for step in _tools.keys():
		_close_tools(String(step))
	changed.emit()


func busy() -> bool:
	return not _jobs.is_empty()


## "ready", "running", "queued", "failed" or "missing".
func state_of(step: String) -> String:
	if episode.has(step):
		return "ready"
	if _jobs.has(step):
		var st := AgentJobs.state(String(_jobs[step]))
		return "running" if st == "running" else "queued"
	if _errors.has(step):
		return "failed"
	return "missing"


func error_of(step: String) -> String:
	return String(_errors.get(step, ""))


## What [param step]'s agent is doing now ([method AgentJobs.activity]); "" when it is not being made.
func activity_of(step: String) -> String:
	return AgentJobs.activity(String(_jobs[step])) if _jobs.has(step) else ""


## Land what ended; start what can start.
func tick() -> void:
	var moved := false
	for step in _jobs.keys():
		var id := String(_jobs[step])
		var st := AgentJobs.state(id)
		if st != "done" and st != "failed":
			continue
		var res := AgentJobs.result(id)
		AgentJobs.forget(id)
		_jobs.erase(step)
		_land(String(step), res)
		moved = true
	if running:
		for step in episode.steps():
			var s := String(step)
			if episode.has(s) or _jobs.has(s) or _errors.has(s):
				continue
			var ready := true
			for need in episode.needs(s):
				if not episode.has(String(need)):
					ready = false
					break
			if not ready or not (only.is_empty() or only.has(s) or LOCAL.has(s)):
				continue
			_make(s)
			moved = true
		if _jobs.is_empty():
			running = false          # done, or stopped on a failure nothing else can get past
			moved = true
	if moved:
		changed.emit()


# --- making one step ---------------------------------------------------------------------

func _make(step: String) -> void:
	var parts := step.split(":")
	match String(parts[0]):
		"plan":
			_make_plan()
		"draw":
			_finish(step, _make_draw())
		"design":
			_make_design(int(parts[1]))
		"check":
			_make_check(int(parts[1]))
		"image":
			_make_image(step)
		"say":
			# "intro", "close", a card's place - or "work:K", card K's work passage
			_make_say(step.trim_prefix("say:"))
		"script":
			_finish(step, _make_script())
		"table":
			_make_table()
		"acts":
			_make_acts()


## [param extra]: more of the job's spec - its tools and their timeout (see [method _make_table]).
func _submit_text(step: String, p: Dictionary, tier: String, extra: Dictionary = {}) -> void:
	_tries[step] = int(_tries.get(step, 0)) + 1
	if not p.has("system") or not p.has("prompt"):
		_errors[step] = "its prompt could not be built (see the log)"
		_close_tools(step)
		return
	var job := {"kind": "text", "backend": String(spec.get("writer", "claude")),
		"tier": tier, "dir": episode.job_dir(step), "system": String(p["system"]),
		"prompt": String(p["prompt"]), "images": p.get("images", []), "label": "table %s" % step,
		"model": String(spec.get("writer_model", "")), "effort": String(spec.get("writer_effort", ""))}
	job.merge(extra, true)
	var id := AgentJobs.submit(job)
	if id.is_empty():
		_errors[step] = "this session cannot start agents (read-only)"
		_close_tools(step)
		return
	_jobs[step] = id


func _submit_image(step: String, prompt: String, refs: Array) -> void:
	_tries[step] = int(_tries.get(step, 0)) + 1
	var id := AgentJobs.submit({"kind": "image", "backend": String(spec.get("painter", "codex")),
		"dir": episode.job_dir(step), "prompt": prompt, "refs": refs,
		"target": episode.file_of(step), "label": "table %s" % step,
		"model": String(spec.get("painter_model", "")), "effort": String(spec.get("painter_effort", ""))})
	if id.is_empty():
		_errors[step] = "this session cannot start agents (read-only)"
		return
	_jobs[step] = id


## A local step's outcome: "" written, else why not. A step that says it succeeded and left no
## file failed all the same - a script error returns "" - and must say so, or the producer goes
## idle with the step still missing and nothing on screen saying why.
func _finish(step: String, err: String) -> void:
	if err.is_empty() and not episode.has(step):
		err = "it wrote nothing (see the log)"
	if not err.is_empty():
		_errors[step] = err


func _plan() -> Dictionary:
	var p: Variant = episode.read_json("plan")
	return p if p is Dictionary else {}


func _look() -> Dictionary:
	var l: Variant = _plan().get("look", {})
	return l if l is Dictionary else {}


## The deck the show reads with (see [CardDeck]): the one its brief lists, handed over in the spec -
## or, when the producer chooses it (`chooses`, [method CardDeck.chooses]), the one in this episode's
## plan, and none before the plan is made. No deck is built in.
func _deck() -> Array:
	var d: Variant = _plan().get("deck", []) if bool(spec.get("chooses", false)) else spec.get("deck", [])
	return d if d is Array else []


## The most cards this episode may draw: [constant SPREAD_MOST], and never more than the show's own deck
## holds - a deck the producer chooses is made for the spread, at least twice its size ([method _land_box]).
func _spread_most() -> int:
	return SPREAD_MOST if bool(spec.get("chooses", false)) else mini(SPREAD_MOST, _deck().size())


func _make_plan() -> void:
	var p := TablePrompts.producer(String(spec.get("title", "")), String(spec.get("brief", "")),
		episode.seed, CardTable.FACES, CardTable.FRAMES, TableEpisode.archive(episode.show, episode.seed), _deck(), bool(spec.get("chooses", false)),
		String(spec.get("uploads_as", "")), _spread_most())
	_submit_text("plan", p, "best")


## The shuffle and the cut, from the seed alone - and, in a show that draws no cards, a draw of none.
func _make_draw() -> String:
	var plan := _plan()
	if CardTable.cardless(plan):
		return episode.write_json("draw", {"seed": episode.seed, "cards": [], "left": [], "deck_n": 0})
	var n := ((plan.get("spread", {}) as Dictionary).get("positions", []) as Array).size()
	if n <= 0:
		return "the plan has no spread"
	# the show's own deck, shuffled from the seed - and each card WRITTEN INTO the draw, so the
	# episode keeps the cards it drew whatever the show's deck becomes later
	var deck := CardDeck.shuffled(_deck(), episode.seed, CardTable.reverses(plan))
	if deck.size() < n:
		return "the deck has %d cards and this spread needs %d (the plan was made for a bigger deck: New episode)" \
			% [deck.size(), n]
	var jumper := jumps(episode.seed, plan)
	var read := CardTable.reads_reversed(plan)
	var cards: Array = []
	for i in n:
		var c: Dictionary = (deck[i] as Dictionary).duplicate()
		c["jumper"] = jumper and i == 0
		# A CARD THAT CAME OUT UPSIDE DOWN AND IS RIGHTED in the hand is read the right way up
		if bool(c.get("reversed", false)) and not read:
			c["reversed"] = false
			c["righted"] = true
		cards.append(c)
	# ...and, of a box, THE CARDS IT LEFT IN: what the table prints the cards nobody drew as
	# (TableMedium._left_in). The table's alone - no writer is handed a card that was not drawn.
	var left: Array = []
	if String(CardTable.staging_of(plan)["source"]) == "box":
		for c in deck.slice(n):
			var card: Dictionary = c
			left.append({"key": card.get("key", ""), "name": card.get("name", ""), "numeral": card.get("numeral", ""),
				"group": card.get("group", ""), "series": card.get("series", ""), "meaning": card.get("meaning", "")})
	# ...and HOW MANY CARDS THE DECK HELD: the table stands, shuffles and washes that many
	# (TablePlan.deck_count)
	return episode.write_json("draw", {"seed": episode.seed, "cards": cards, "left": left, "deck_n": deck.size()})


## WHETHER A CARD JUMPS in episode [param seed], staged by [param plan]: the plan lets one fly
## (`staging.jumpers`, the producer's choice), and the seed says whether one does - how the reading
## goes, never which card. A JUMPER flies out of a shuffle: never out of a box, and never into a card
## not drawn by hand.
static func jumps(seed: int, plan: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-jumper"])
	var jumper := bool(CardTable.staging_of(plan)["jumpers"]) and rng.randf() < JUMPER_CHANCE
	var listed: Array = ((plan.get("spread", {}) as Dictionary).get("positions", []) as Array) if plan.get("spread") is Dictionary else []
	var first_pos: Variant = listed[0] if not listed.is_empty() else {}
	if first_pos is Dictionary and String((first_pos as Dictionary).get("comes", "drawn")) != "drawn":
		jumper = false
	return jumper


## Card [param k] (1-based) as drawn: the deck's card, the way up it came, its place in the
## spread and - once designed - its booklet entry.
func _card(k: int) -> Dictionary:
	var draw: Variant = episode.read_json("draw")
	if not (draw is Dictionary):
		return {}
	var list: Array = (draw as Dictionary).get("cards", [])
	if k < 1 or k > list.size():
		return {}
	var card := (list[k - 1] as Dictionary).duplicate()
	card["reversed"] = bool(card.get("reversed", false))
	card["righted"] = bool(card.get("righted", false))
	card["jumper"] = bool(card.get("jumper", false))
	var design: Variant = episode.read_json("design:%d" % k)
	if design is Dictionary:
		card["booklet"] = (design as Dictionary).get("booklet", {})
		card["art"] = String((design as Dictionary).get("art", ""))
		if (design as Dictionary).get("writing") is Dictionary:
			card["writing"] = (design as Dictionary)["writing"]
	return card


## THE CARDS THE READER MAY KNOW at a step: those turned over so far - 1..k for card k, none for
## the intro, all of them for the close. The only way a card reaches a reader prompt. (None at all in
## a show that draws none.)
func _drawn(upto: int) -> Array:
	var out: Array = []
	for k in range(1, mini(upto, episode.card_count()) + 1):
		out.append(_card(k))
	return out


## CARD [param k]'s DESIGN, shown the pictures of the cards designed before it in this draw (the user,
## 2026-10-17, of penalty-box: "players will be in very similar poses/positions" - seven of ten designs of
## 901482 were two men nose to nose in the middle, each designer blind to the others).
func _make_design(k: int) -> void:
	var card := _card(k)
	var siblings: Array = []
	for j in range(1, k):
		var c := _card(j)
		if not String(c.get("art", "")).is_empty():
			siblings.append({"k": j, "name": String(c.get("name", "")), "art": String(c["art"])})
	var p := TablePrompts.designer(String(spec.get("title", "")), String(spec.get("brief", "")),
		CardTable.look_of(_look(), card), card, CardTable.reads_reversed(_plan()) or bool(card.get("reversed", false)),
		TableEpisode.archive(episode.show, episode.seed),
		String(CardTable.staging_of(_plan())["text"]), siblings)
	_submit_text("design:%d" % k, p, "fast")


func _make_image(step: String) -> void:
	var look := _look()
	# the painter saves into its own job directory; the queue moves the picture into the episode
	# whole (see AgentJobs.paint_target)
	var target := AgentJobs.paint_target(episode.job_dir(step))
	var parts := step.split(":")
	var printed := String(CardTable.staging_of(_plan())["text"]) == "back"
	if parts.size() == 3 and String(parts[1]) == "card":
		var k := int(parts[2])
		var design: Variant = episode.read_json("design:%d" % k)
		var art := String((design as Dictionary).get("art", "")) if design is Dictionary else ""
		var refs: Array = []
		# IN ITS OWN PRINTING'S HAND: that printing's back, and the cards drawn before it in that printing
		var key := episode.printing_of(k)
		var back := "image:back" if key.is_empty() else "image:back:%s" % key
		var has_back := episode.has(back)
		if has_back:
			refs.append(episode.file_of(back))
		var chain: Array = []
		for j in range(1, k):
			if episode.has("image:card:%d" % j) and episode.printing_of(j) == key:
				chain.append(episode.file_of("image:card:%d" % j))
		if chain.size() > CHAIN_MAX:
			chain = [chain[0]] + chain.slice(chain.size() - (CHAIN_MAX - 1))
		refs.append_array(chain)
		# WHAT THE ART DIRECTOR SENT BACK of this card's earlier paintings, every fault once
		var faults := PackedStringArray()
		for round in episode.sent_back(k):
			for f in DataPath.strings(round):
				if not faults.has(f):
					faults.append(f)
		_submit_image(step, TablePrompts.card_image(CardTable.look_of(look, _card(k)), _card(k), art, target, has_back,
			chain.size(), String(CardTable.staging_of(_plan())["text"]) == "front", faults), refs)
		return
	if parts.size() == 3 and String(parts[1]) == "back":
		# A printing's own back, even when none of its cards happened to be drawn.
		var name := ""
		for s in look.get("series", []) if look.get("series") is Array else []:
			if s is Dictionary and CardTable.series_key(String((s as Dictionary).get("name", ""))) == String(parts[2]):
				name = String((s as Dictionary)["name"])
				break
		_submit_image(step, TablePrompts.back_image(CardTable.look_of(look, {"series": name}), target,
			CardTable.reads_reversed(_plan()), printed), [])
		return
	match String(parts[1]):
		"back":
			_submit_image(step, TablePrompts.back_image(look, target, CardTable.reads_reversed(_plan()), printed), [])
		"surface":
			_submit_image(step, TablePrompts.surface_image(look, target), [])
		"height":
			# the painting's depth, redrawn FROM the painting - an edit of it, checked as it lands
			_submit_image(step, TablePrompts.height_image(look, target), [episode.file_of("image:surface")])
		"backdrop":
			# THE VIEW IT IS ASKED FOR, kept beside it: the table projects a level picture from the
			# camera's eye, and keeps a picture made before (none beside it) as it always stood
			var view := episode.dir.path_join("backdrop.json")
			var f := FileAccess.open(view + ".part", FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"view": "level", "lens_mm": CardTable.BACKDROP_LENS}))
				f.close()
				DirAccess.rename_absolute(view + ".part", view)
			_submit_image(step, TablePrompts.backdrop_image(look, target), [])


## THE ART DIRECTOR looks at card [param k]'s painting before the reader does: shown the painting, the
## description it was painted from, what is printed with it and the cards of this draw painted before
## it, it keeps the painting or sends it back with what is wrong ([method _land_check]) - the user,
## 2026-10-17: a reading said a player shook with his left hand, and the picture showed a right-handed
## shake (penalty-box 290660); a rink bent into a triangle so a crowd would fit. A reversed card is shown
## as it was painted, the right way up.
func _make_check(k: int) -> void:
	var card := _card(k)
	var images: Array = [{"path": episode.file_of("image:card:%d" % k),
		"label": "THE PAINTING to check - card %d, %s:" % [k, String(card.get("name", ""))], "flip": false}]
	for j in range(1, k):
		if episode.has("image:card:%d" % j):
			images.append({"path": episode.file_of("image:card:%d" % j),
				"label": "An earlier card of this draw - card %d, %s:" % [j, String(_card(j).get("name", ""))], "flip": false})
	var p := TablePrompts.art_director(String(spec.get("title", "")), String(spec.get("brief", "")),
		CardTable.look_of(_look(), card), card, images.size() - 1, String(CardTable.staging_of(_plan())["text"]))
	p["images"] = images
	_submit_text("check:%d" % k, p, "best")


## THE SET DRESSER sets the table from the plan, looking at the cloth, told the things earlier
## episodes' tables held so this one holds others. A writer that takes tools works with
## [SetDresserTools]: it builds the table a few things at a time, LOOKS at what it built and at the
## table as the camera will film it, fixes what it sees, and hands the table in - see [method _land].
## One that cannot is asked for the table in one reply, as before.
func _make_table() -> void:
	var seen: Array = []
	var airs: Array = []
	var tables: Array = []
	var lights: Array = []
	for e in TableEpisode.archive(episode.show, episode.seed):
		seen.append_array((e as Dictionary)["things"])
		airs.append_array((e as Dictionary).get("air", []))
		if not String((e as Dictionary).get("furniture", "")).is_empty():
			tables.append((e as Dictionary)["furniture"])
		if not String((e as Dictionary).get("light", "")).is_empty():
			lights.append((e as Dictionary)["light"])
	var cloth := episode.has("image:surface")
	var room := episode.has("image:backdrop")
	_close_tools("table")
	# a table an earlier run handed in is not this run's answer, whoever writes this one
	DirAccess.remove_absolute(episode.job_dir("table").path_join(SetDresserTools.SUBMITTED))
	var extra := {}
	if TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		var toolset := SetDresserTools.new(episode, _plan(), episode.job_dir("table"), String(spec.get("title", "")),
			String(spec.get("byline", "")))
		var url := AgentTools.open(episode.job_dir("table"), toolset)
		if not url.is_empty():
			_tools["table"] = {"url": url, "set": toolset}
			extra = {"tools_url": url}
		else:
			toolset.release()
	var p := TablePrompts.set_dresser(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(),
		episode.seed, CardTable.headroom(episode.seed), seen.slice(0, 40), cloth,
		SetDresserTools.LOOKS if not extra.is_empty() else 0, airs.slice(0, 24), String(spec.get("byline", "")),
		tables.slice(0, 10), lights.slice(0, 10), room, jumps(episode.seed, _plan()))
	var images: Array = []
	if cloth:
		images.append({"path": episode.file_of("image:surface"), "label": "The painting of this episode's surface, seen from above:", "flip": false})
	# THE ROOM, so the light agrees with it: where its windows are, which side its sun comes from
	if room:
		images.append({"path": episode.file_of("image:backdrop"), "label": "The painting of the room past the table, as the reader sees it (only its lower part shows, out of focus):", "flip": false})
	if not images.is_empty():
		p["images"] = images
	_submit_text("table", p, "best", extra)


## How many pictures the set dresser has taken so far, -1 while none is working with tools.
## How many pictures the agent making [param step] with its tools has taken, and may in all: `[used, most]` -
## the set dresser's or the puppeteer's - or `[]` while it has no tools open.
func looks_of(step: String) -> Array:
	var t: Dictionary = _tools.get(step, {})
	if t.is_empty():
		return []
	if t["set"] is SetDresserTools:
		return [(t["set"] as SetDresserTools).looks_used(), SetDresserTools.LOOKS]
	if t["set"] is PuppeteerTools:
		return [(t["set"] as PuppeteerTools).looks_used(), PuppeteerTools.LOOKS]
	return []


## THE PUPPETEER blocks the episode's work ([PuppeteerTools], next/table_work.md): told the plan's work beat
## by beat, the cards as they were drawn (the work is made of them) and what on the set table can be worked -
## and, given a writer that takes tools, writing acts, told what each does, watching them and handing them in.
## One that cannot is asked for the acts in one reply.
func _make_acts() -> void:
	_close_tools("acts")
	DirAccess.remove_absolute(episode.job_dir("acts").path_join(PuppeteerTools.SUBMITTED))
	var table: Variant = episode.read_json("table")
	var tbl: Dictionary = table if table is Dictionary else {}
	var extra := {}
	var looks := 0
	if TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		var toolset := PuppeteerTools.new(episode, _plan(), episode.job_dir("acts"), tbl)
		var url := AgentTools.open(episode.job_dir("acts"), toolset)
		if not url.is_empty():
			_tools["acts"] = {"url": url, "set": toolset}
			extra = {"tools_url": url}
			looks = PuppeteerTools.LOOKS
		else:
			toolset.release()
	var things: Array = CardTable.sanitize_table(tbl, _look())["things"] if not tbl.is_empty() else []
	var p := TablePrompts.puppeteer(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(), episode.seed,
		_drawn(episode.card_count()), Motions.table_text(things), looks)
	_submit_text("acts", p, "best", extra)


## A step's tools stop answering, and what they built is given back.
func _close_tools(step: String) -> void:
	var t: Dictionary = _tools.get(step, {})
	if t.is_empty():
		return
	AgentTools.close(String(t["url"]))
	(t["set"] as Object).call("release")
	_tools.erase(step)


## WHAT AN AGENT HANDED IN WITH A TOOL for [param step] (its job's `submitted.json`), or "" - an
## answer that does not depend on its last words, or on its run ending cleanly.
func _handed_in(step: String) -> String:
	var path := episode.job_dir(step).path_join(SetDresserTools.SUBMITTED)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _make_say(who: String) -> void:
	if who.is_valid_int():
		var positions: Array = ((_plan().get("spread", {}) as Dictionary).get("positions", []) as Array)
		var k := int(who) - 1
		if k >= 0 and k < positions.size() and positions[k] is Dictionary \
				and String((positions[k] as Dictionary).get("comment", "")) == "none":
			_finish("say:" + who, episode.write_text("say:" + who, ""))
			return
	_submit_text("say:" + who, say_prompt(who), "best")


## THE READER'S PROMPT for passage [param who] ("intro", "1".."N", "close"): the passages before it
## and [method _drawn] up to its card - nothing else reaches it - and `images`, the PAINTINGS it
## talks about: card K's own for card K when K is one it may stop on ([method TablePrompts.remarks]),
## every card's for the close, none for the intro; and whether card K is one read with the cards
## already down ([method TablePrompts.links]). A
## reversed card is sent upside down, as the viewer sees it. Public so the gate can hold the
## producer itself, not only the prompt builder, to all of that.
func say_prompt(who: String) -> Dictionary:
	var n := episode.card_count()
	# the passages between the intro and the close: a card's each, or a beat's of a show that draws none
	var beats := episode.beat_count()
	var said: Array = []
	var drawn: Array = []
	# CARD K'S WORK PASSAGE (next/table_work.md): everything said through card K's own, the cards up to K
	var work_k := int(who.trim_prefix("work:")) if who.begins_with("work:") else 0
	if who == "intro":
		pass
	elif who == "close":
		said = _said(beats)
		drawn = _drawn(n)
	elif work_k > 0:
		said = _said(work_k, false)
		drawn = _drawn(episode.reveal_of(work_k))
	elif episode.cardless():
		# A BEAT OF A SHOW WITH NO CARDS: everything said before it, and no card
		said = _said(int(who) - 1)
	else:
		var k := int(who)
		said = _said(k - 1)
		# THE CARDS ON THE TABLE by now: up to this one - or, swept out in a waterfall, up to its last
		drawn = _drawn(episode.reveal_of(k))
	# THE PAINTINGS go with a passage only where the reader may stop on one ([method TablePrompts.remarks]):
	# a card left out reaches it by name and meaning alone
	var remark := true
	# ...and a share of the cards is read with the cards already down ([method TablePrompts.links])
	var link := false
	if who != "intro" and who != "close" and work_k == 0:
		var shares := TablePrompts.remarks(episode.seed, n)
		remark = int(who) - 1 < shares.size() and bool(shares[int(who) - 1])
		var links := TablePrompts.links(episode.seed, n)
		link = int(who) - 1 < links.size() and bool(links[int(who) - 1])
	var images: Array = []
	if who != "intro" and remark and work_k == 0:
		var plan_pos: Array = ((_plan().get("spread", {}) as Dictionary).get("positions", [])) as Array
		var first := 1 if who == "close" else int(who)
		for k in range(first, (drawn.size() if who == "close" else first) + 1):
			var c: Dictionary = drawn[k - 1]
			var pos: Variant = plan_pos[k - 1] if k - 1 < plan_pos.size() else {}
			var where := String((pos as Dictionary).get("name", "")) if pos is Dictionary else ""
			var label := ("Card %d, just turned over - its painting, as the viewer sees it:" % k) if who != "close" \
				else ("Card %d%s - %s%s:" % [k, (" (" + where + ")") if not where.is_empty() else "",
					String(c.get("name", "")), ", reversed" if bool(c.get("reversed", false)) else ""])
			images.append({"path": episode.file_of("image:card:%d" % k), "label": label,
				"flip": bool(c.get("reversed", false))})
	var names: Array = []
	for c in _deck():
		names.append(String((c as Dictionary).get("name", "")))
	# ...and WHAT ITS PAINTING GETS WRONG, when the art director could not have it put right
	var misses: Array = []
	if who.is_valid_int():
		var check: Variant = episode.read_json("check:%s" % who)
		if check is Dictionary and not bool((check as Dictionary).get("kept", true)):
			misses = Array(DataPath.strings((check as Dictionary).get("faults", [])))
	var p := TablePrompts.reader(String(spec.get("title", "")), String(spec.get("brief", "")),
		_plan(), who, said, drawn, beats, not images.is_empty(), TableEpisode.archive(episode.show, episode.seed), names,
		_voices(), remark, link, misses, _acts_of(_beat_of("say:" + who, episode.cardless())))
	p["images"] = images
	return p


## The intro and the passages for cards 1..upto, in order - each card's work passage after its own, but the
## last card's when [param last_work] is false (the work passage being written now).
func _said(upto: int, last_work := true) -> Array:
	var out := [episode.read_text("say:intro")]
	var works := episode.work_plan()
	for k in range(1, upto + 1):
		out.append(episode.read_text("say:%d" % k))
		if works.has(str(k)) and (k < upto or last_work) and episode.has("say:work:%d" % k):
			out.append(episode.read_text("say:work:%d" % k))
	return out


## THE BEAT a passage's work belongs to ("intro", "close", a card's place for its work passage), or "" - and,
## in a show that draws no cards ([param bare]), a beat's own passage: it is said while its work is done.
static func _beat_of(step: String, bare := false) -> String:
	if step == "say:intro":
		return "intro"
	if step == "say:close":
		return "close"
	if step.begins_with("say:work:"):
		return step.trim_prefix("say:work:")
	if bare and step.trim_prefix("say:").is_valid_int():
		return step.trim_prefix("say:")
	return ""


## THE ACTS OF [param beat], as the puppeteer blocked them (`acts.json`, made safe) - none for a beat with no
## work, or before they are blocked. A reader is handed its own beat's alone: NO CHEATING holds for the work.
func _acts_of(beat: String) -> Array:
	if beat.is_empty() or not episode.has("acts"):
		return []
	return Motions.of_beat(Motions.sanitize_acts(episode.read_json("acts"), episode.beat_count())["acts"], beat)


func _make_script() -> String:
	var n := episode.card_count()
	var passages: Array = []
	for m in choreography(_plan(), _drawn(n)):
		var mv: Dictionary = m
		var text := episode.read_text(String(mv["say"])) if not String(mv.get("say", "")).is_empty() else ""
		passages.append({"kind": mv["kind"], "card": mv.get("card", 0), "last": mv.get("last", mv.get("card", 0)), "text": text})
	return episode.write_text("script", CardReading.compose(passages))


## THE MOVES OF AN EPISODE, in order, from its [param plan]'s staging and positions and its [param cards]
## as drawn: `[{kind, card, last, say}]` - each a written verb ([TableActions]) and the passage read after
## it (`say`, a step's name, or "" for a move with no words of its own). The opening (the shuffle, or the
## box opened) and the intro; then each card as its position says it comes - drawn (a jumper when it flew
## out), dealt, or swept out with the swept positions after it, each then shown - and the moves its
## position makes after its passage (`then`: tap, untap); the spread and the close. A SHOW THAT DRAWS NO
## CARDS begins, and each of its beats opens with its work (`work K`, K the beat), said in its own passage.
static func choreography(plan: Dictionary, cards: Array) -> Array:
	var staging := CardTable.staging_of(plan)
	var pos: Array = ((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array if plan.get("spread") is Dictionary else []
	var out: Array = [{"kind": String((TableActions.SOURCES[staging["source"]] as Dictionary)["opens"]), "card": 0, "say": "say:intro"}]
	if String(staging["source"]) == "none":
		for b in range(1, pos.size() + 1):
			out.append({"kind": "work", "card": b, "say": "say:%d" % b})
		out.append({"kind": "spread", "card": 0, "say": "say:close"})
		return out
	var n := cards.size()
	var k := 1
	var at := func(i: int) -> Dictionary: return pos[i - 1] if i >= 1 and i <= pos.size() and pos[i - 1] is Dictionary else {}
	while k <= n:
		var p: Dictionary = at.call(k)
		var comes := String(p.get("comes", "drawn"))
		if comes == "searched" and String(staging["source"]) == "box":
			out.append({"kind": "rummage", "card": 0, "say": ""})
		if comes == "swept":
			var last := k
			while last < n and String((at.call(last + 1) as Dictionary).get("comes", "")) == "swept":
				last += 1
			out.append({"kind": "fan", "card": k, "last": last, "say": ""})
			for j in range(k, last + 1):
				out.append({"kind": "show", "card": j, "say": "say:%d" % j})
				out.append_array(_then_moves(at.call(j), j))
				out.append_array(_work_move(plan, j))
			k = last + 1
			continue
		var kind := "deal" if comes == "dealt" else ("jumper" if bool((cards[k - 1] as Dictionary).get("jumper", false)) else "draw")
		out.append({"kind": kind, "card": k, "say": "say:%d" % k})
		if bool(p.get("linger", false)) and String(p.get("comment", "")) == "none" and kind == "draw":
			out.append({"kind": "linger", "card": 0, "say": ""})
		out.append_array(_then_moves(p, k))
		out.append_array(_work_move(plan, k))
		k += 1
	out.append({"kind": "spread", "card": 0, "say": "say:close"})
	return out


## THE WORK after card [param k]'s passage (next/table_work.md), where the plan has any: the card goes down and
## its work begins, talked through in its own passage.
static func _work_move(plan: Dictionary, k: int) -> Array:
	return [{"kind": "work", "card": k, "say": "say:work:%d" % k}] if TableEpisode.work_of(plan).has(str(k)) else []


## The moves position [param p] makes after its passage: `then`'s `tap N`, `untap N`, each naming a card
## already on the table - one of 1..[param n].
static func _then_moves(p: Dictionary, n: int) -> Array:
	var out: Array = []
	for m in p.get("then", []) if p.get("then") is Array else []:
		var parts := String(m).strip_edges().to_lower().split(" ", false)
		if parts.size() == 2 and parts[0] in ["tap", "untap"] and parts[1].is_valid_int() \
				and int(parts[1]) >= 1 and int(parts[1]) <= n:
			out.append({"kind": String(parts[0]), "card": int(parts[1]), "say": ""})
	return out


# --- landing a job -------------------------------------------------------------------------

func _land(step: String, res: Dictionary) -> void:
	var err := ""
	var had_tools := _tools.has(step)
	var handed := _handed_in(step) if had_tools else ""
	_close_tools(step)
	if not handed.is_empty():
		err = _land_acts(handed) if step == "acts" else _land_table(handed)
	elif not bool(res.get("ok", false)):
		err = String(res.get("error", "the job failed"))
	else:
		match String(step.split(":")[0]):
			"plan":
				err = _land_plan(String(res.get("text", "")))
			"design":
				err = _land_design(step, String(res.get("text", "")))
			"check":
				err = _land_check(step, String(res.get("text", "")))
			"say":
				# ...keeping the act cues its own beat's acts may be started by ([CardReading], `<!-- act: name -->`)
				var cues: Array = _acts_of(_beat_of(step, episode.cardless())).map(func(a: Dictionary) -> String: return String(a["name"]))
				var t := own_voices(clean_spoken(String(res.get("text", "")), cues), _voices(), _reader_name())
				err = "the reader wrote nothing speakable" if t.split(" ", false).size() < (1 if step.split(":")[1].is_valid_int() else 20) \
					else episode.write_text(step, t)
			"image":
				err = "" if episode.has(step) else "the picture did not arrive"
				if err.is_empty() and step == "image:height":
					err = _land_height()
			"table":
				err = _land_table(String(res.get("text", "")))
				if not err.is_empty() and had_tools:
					err = "the set dresser stopped without handing its table in"
			"acts":
				err = _land_acts(String(res.get("text", "")))
				if not err.is_empty() and had_tools:
					err = "the puppeteer stopped without handing its work in"
	if err.is_empty():
		_errors.erase(step)
		return
	push_warning("ghost: table %s - %s" % [step, err])
	if int(_tries.get(step, 0)) > RETRIES:
		_errors[step] = err


## THE HEIGHT MAP, KEPT ONLY IF IT LIES UNDER THE PAINTING ([method Tables.height_fit]) - or is flat
## ([constant Tables.FLAT_SPAN]) or alike everywhere ([constant Tables.EVEN_SPREAD]), which lie under
## anything: its score and shift written beside it (`height.json`, which the table reads), or the map
## removed and why.
func _land_height() -> String:
	var paint := Image.load_from_file(episode.file_of("image:surface")) if episode.has("image:surface") else null
	var h := Image.load_from_file(episode.file_of("image:height"))
	if paint == null or h == null or paint.is_empty() or h.is_empty():
		DirAccess.remove_absolute(episode.file_of("image:height"))
		return "the height map or the painting could not be read"
	var span := Tables.height_span(h)
	if span < Tables.FLAT_SPAN:
		# a surface with no relief, drawn flat as asked: it lies under anything, as it is
		print("ghost: table image:height - flat (spans %.3f): the surface lies smooth" % span)
		return TextGen.put(episode.dir.path_join("height.json"), JSON.stringify({"score": 1.0, "shift": [0.0, 0.0], "flat": true}, "\t"))
	var fit := Tables.height_fit(paint, h)
	var score := float(fit["score"])
	print("ghost: table image:height - lies under the painting at %.2f, shifted %s" % [score, str(fit["shift"])])
	if score < Tables.FIT_LEAST:
		var spread := Tables.relief_spread(h)
		if spread < Tables.EVEN_SPREAD:
			# relief with no place of its own (a nap, a grain - the painting's pattern a print, not drawn)
			print("ghost: table image:height - alike everywhere (spread %.2f): it lies under the painting unmoved" % spread)
			return TextGen.put(episode.dir.path_join("height.json"), JSON.stringify({"score": score, "shift": [0.0, 0.0], "even": true}, "\t"))
		DirAccess.remove_absolute(episode.file_of("image:height"))
		return "the height map did not line up with the painting (%.2f, %.2f needed): the painting's own detail stands in" % [score, Tables.FIT_LEAST]
	var shift: Vector2 = fit["shift"]
	return TextGen.put(episode.dir.path_join("height.json"), JSON.stringify({"score": score, "shift": [shift.x, shift.y]}, "\t"))


func _land_plan(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the plan was not JSON"
	var plan: Dictionary = d
	# A PLAN OF BEATS DRAWS NO CARDS: the producer's own choice, read off the brief
	if plan.get("beats") is Array and not (plan.get("beats") as Array).is_empty():
		return _land_beats(plan)
	var spread: Dictionary = plan.get("spread", {}) if plan.get("spread") is Dictionary else {}
	# EVERY FIELD IN THE SHAPE ITS READERS EXPECT: a position given as a bare name, tags as one
	# string - a reply of the wrong shape is reshaped here, once, or it stalls the episode later
	# inside a prompt builder, where it fails with nothing on screen
	var pos: Array = []
	# AS MANY CARDS AS THE SPREAD HAS POSITIONS, the producer's count - cut to the most it may draw
	var raw: Array = spread.get("positions", []) if spread.get("positions") is Array else []
	raw = raw.filter(func(q: Variant) -> bool: return q is Dictionary or not _str(q).is_empty()).slice(0, _spread_most())
	if raw.is_empty():
		return "the plan has no spread and no beats"
	var n := raw.size()
	for q in raw:
		if q is Dictionary:
			pos.append(_land_position(q as Dictionary, pos.size() + 1, n))
		else:
			pos.append({"name": _str(q), "asks": ""})
	spread["name"] = _str(spread.get("name", ""))
	for k in ["episode_title", "description", "audience", "topic", "premise", "reader_mood", "running_bit", "work_intro", "work_close"]:
		plan[k] = _str(plan.get(k, ""))
	plan["beat_word"] = beat_word_of(plan.get("beat_word", ""))
	for k in ["tags", "habits"]:
		plan[k] = Array(DataPath.strings(plan.get(k, [])))
	spread["positions"] = pos
	plan["spread"] = spread
	if not (plan.get("look") is Dictionary):
		return "the plan has no look"
	plan["look"] = CardTable.sanitize_look(plan["look"] as Dictionary)
	# a show that draws cards never draws them from nowhere ([constant TableActions.SOURCES] `none`)
	if plan.get("staging") is Dictionary and str((plan["staging"] as Dictionary).get("source", "")).strip_edges().to_lower() == "none":
		(plan["staging"] as Dictionary)["source"] = "deck"
	plan["staging"] = CardTable.staging_of(plan)
	for i in pos.size():
		var p: Dictionary = pos[i]
		if String((plan["staging"] as Dictionary)["source"]) != "box" and String(p.get("comes", "")) == "searched":
			p.erase("comes")
		if String(p.get("comment", "")) == "aside":
			if String((plan["staging"] as Dictionary)["source"]) == "box" and i > 0:
				p["destination"] = "box"
				if String(p.get("comes", "")) in ["dealt", "swept"]:
					p.erase("comes")
			else:
				p.erase("comment")
	runs_of_three(pos)
	back_only_passed(pos, plan["staging"])
	for i in pos.size():
		var p: Dictionary = pos[i]
		# A side pile grows only from the card immediately beneath this one. A returned card
		# cannot become the base of a pile just because an earlier card was kept.
		if String(p.get("destination", "")) == "stack":
			if i > 0 and String((pos[i - 1] as Dictionary).get("destination", "")) == "stack":
				p["on"] = true
			else:
				p.erase("on")
	if (plan["look"] as Dictionary).has("kind"):
		plan["look"]["kind"] = _str(plan["look"]["kind"])
	if bool(spec.get("chooses", false)):
		var box := _land_box(plan.get("deck"), n)
		if box.is_empty():
			return "the plan's deck has fewer than the %d cards the box needs" % int(TablePrompts.box_range(n)[0])
		plan["deck"] = box
	else:
		plan.erase("deck")
	# The table needs the full collection's size and printing mix, including cards never drawn.
	var inventory: Array = plan.get("deck", []) if bool(spec.get("chooses", false)) else _deck()
	var printings := {}
	for card in inventory:
		var name := CardTable.series_of(plan["look"], card as Dictionary)
		printings[name] = int(printings.get(name, 0)) + 1
	plan["inventory"] = {"count": inventory.size(), "printings": printings}
	plan["seed"] = episode.seed
	plan["dice"] = TablePrompts.dice(episode.seed)
	return episode.write_json("plan", plan)


## THE PLAN OF A SHOW THAT DRAWS NO CARDS, as it lands: its BEATS (`beats`) kept as the spread's positions -
## each a name, what it does and its work - at least one and at most [constant BEATS_MOST]; its staging the
## one that draws none; no deck.
func _land_beats(plan: Dictionary) -> String:
	var raw: Variant = plan.get("beats")
	var pos: Array = []
	for q in raw if raw is Array else []:
		if pos.size() >= BEATS_MOST:
			break
		if q is Dictionary:
			var beat := {"name": _str((q as Dictionary).get("name", "")), "asks": _str((q as Dictionary).get("asks", ""))}
			var work := _str((q as Dictionary).get("work", ""))
			if not work.is_empty():
				beat["work"] = work.substr(0, 500)
			pos.append(beat)
		elif not _str(q).is_empty():
			pos.append({"name": _str(q), "asks": ""})
	if pos.is_empty():
		return "the plan has no beats"
	plan.erase("beats")
	plan["spread"] = {"name": "", "positions": pos}
	for k in ["episode_title", "description", "audience", "topic", "premise", "reader_mood", "running_bit", "work_intro", "work_close"]:
		plan[k] = _str(plan.get(k, ""))
	plan["beat_word"] = beat_word_of(plan.get("beat_word", ""))
	for k in ["tags", "habits"]:
		plan[k] = Array(DataPath.strings(plan.get(k, [])))
	plan["look"] = CardTable.sanitize_look(plan["look"] as Dictionary if plan.get("look") is Dictionary else {})
	plan["staging"] = CardTable.staging_of({"staging": {"source": "none"}})
	plan.erase("deck")
	plan["inventory"] = {"count": 0, "printings": {}}
	plan["seed"] = episode.seed
	plan["dice"] = TablePrompts.dice(episode.seed)
	return episode.write_json("plan", plan)


## A CARD GOES BACK IN THE BOX ONLY WHEN IT WAS PASSED OVER - or when every card does. The user,
## 2026-10-13, of an episode whose fourth card was given a story and then put back while two others
## stayed out on a pile: "It makes no sense, why one card would go back in the box while others go on
## the table ... Don't spend a full minute talking about the card, just to put it back." So in a spread
## where some cards stay out, [param positions] are held to it, in place, for [param staging]:
##
##   - a card with a `story` stays out, the way the others do (on the keep pile when the spread has
##     one, else laid in its place) - the story is the reason to keep it;
##   - a card put back with no length asked for is looked at briefly (`comment: "brief"`), which is
##     what makes putting it back read as a choice - [method passed] tells its reader so;
##   - a quick look, a silent one and an aside go back as planned.
##
## A spread that puts EVERY card back is a pattern of its own and is left alone. No card goes back
## into a box when the cards come from a deck, and none that was put straight down on the table (dealt,
## swept) is in a hand to be put back.
static func back_only_passed(positions: Array, staging: Dictionary) -> void:
	var boxed := String(staging.get("source", "deck")) == "box"
	var kept := 0
	var stacks := false
	for q in positions:
		var p: Dictionary = q
		if String(p.get("destination", "")) == "box" and (not boxed or String(p.get("comes", "")) in ["dealt", "swept"]):
			p.erase("destination")
		if String(p.get("destination", "")) != "box":
			kept += 1
		stacks = stacks or String(p.get("destination", "")) == "stack"
	if not boxed or kept == 0:
		return
	for q in positions:
		var p: Dictionary = q
		if String(p.get("destination", "")) != "box":
			continue
		match String(p.get("comment", "")):
			"story":
				if stacks:
					p["destination"] = "stack"
				else:
					p.erase("destination")
			"":
				if String(staging.get("pace", "")) != "quick":
					p["comment"] = "brief"


## A WATERFALL IS A RUN, OF THREE OR MORE: [param positions] swept out with fewer next to them come out one
## at a time, in place. The-shoebox 32533 swept out a pair from its box (the user, 2026-10-18: "two cards
## are drawn simultaneously. One is put on the table, the other is read ... The two cards are eventually
## stacked on top of each other"): two cards a waterfall's step apart lie half on each other, a pile of
## two rather than a run the viewer sees at once.
const RUN_LEAST := 3


static func runs_of_three(positions: Array) -> void:
	var i := 0
	while i < positions.size():
		var j := i
		while j < positions.size() and String((positions[j] as Dictionary).get("comes", "")) == "swept":
			j += 1
		if j - i < RUN_LEAST:
			for k in range(i, j):
				(positions[k] as Dictionary).erase("comes")
		i = maxi(j, i + 1)


## IS POSITION [param p] PASSED OVER in a plan of [param positions]: looked at, said a few words of and
## put back in its box, while other cards of the spread stay out ([method back_only_passed])? Its
## reader is told so, to say what makes it one to put back.
static func passed(p: Dictionary, positions: Array) -> bool:
	if String(p.get("destination", "")) != "box" or String(p.get("comment", "")) == "aside":
		return false
	return positions.any(func(q: Variant) -> bool:
		return q is Dictionary and String((q as Dictionary).get("destination", "")) != "box")


## A SPREAD POSITION AS IT LANDS: its name and question, and how its card comes and lies
## ([constant TablePositions.COMES]) - only what the table knows, and only where it can be: the first card
## stacks on nothing, and `then` turns only a card already on the table by then (one of 1..[param k], or
## of its waterfall's) among the reading's [param n].
func _land_position(q: Dictionary, k: int, n: int) -> Dictionary:
	var out := {"name": _str(q.get("name", "")), "asks": _str(q.get("asks", ""))}
	var comes := _str(q.get("comes", "")).to_lower()
	if comes in TablePositions.COMES and comes != "drawn":
		out["comes"] = comes
	if _str(q.get("lies", "")).to_lower() == "sideways":
		out["lies"] = "sideways"
	if q.get("on") == true and k > 1:
		out["on"] = true
	var destination := _str(q.get("destination", "")).to_lower()
	if destination in ["stack", "box"]:
		out["destination"] = destination
	var comment := _str(q.get("comment", "")).to_lower()
	if comment in ["none", "brief", "story", "aside"]:
		out["comment"] = comment
	if q.get("linger") == true and comment == "none" and comes not in ["dealt", "swept"]:
		out["linger"] = true
	var then: Array = []
	for m in q.get("then", []) if q.get("then") is Array else ([q.get("then")] if q.get("then") is String else []):
		var parts := _str(m).to_lower().split(" ", false)
		if parts.size() == 2 and parts[0] in ["tap", "untap"] and parts[1].is_valid_int() and int(parts[1]) >= 1 \
				and int(parts[1]) <= mini(n, k):
			then.append("%s %d" % [parts[0], int(parts[1])])
	if not then.is_empty():
		out["then"] = then
	# THE WORK done at the table after this card is shown (next/table_work.md), in the producer's words
	var work := _str(q.get("work", ""))
	if not work.is_empty():
		out["work"] = work.substr(0, 500)
	return out


## THE BOX A PRODUCER CHOSE, in the shape [method CardDeck.parse] gives a listed deck - `{key, name,
## numeral, group, meaning}`, keys unique - or empty when it holds fewer than the box's least
## ([method TablePrompts.box_range]): a box the size of the spread would be the producer's pick of the
## cards, not the seed's. More than the most are cut.
func _land_box(v: Variant, n: int) -> Array:
	var r := TablePrompts.box_range(n)
	var out: Array = []
	var keys := {}
	for c in v if v is Array else []:
		var d: Dictionary = c if c is Dictionary else {"name": c}
		var name := _str(d.get("name", ""))
		if name.is_empty() or out.size() >= int(r[1]):
			continue
		var key := Manuscript.slug(name)
		var k := key
		var i := 2
		while keys.has(k):
			k = "%s-%d" % [key, i]
			i += 1
		keys[k] = true
		var card := {"key": k, "name": name, "numeral": "", "group": _str(d.get("group", "")),
			"meaning": _str(d.get("meaning", ""))}
		if not _str(d.get("series", "")).is_empty():
			card["series"] = _str(d["series"])
		out.append(card)
	return out if out.size() >= int(r[0]) else []


## THE ART DIRECTOR'S WORD on a card's painting ([param step] `check:K`): kept, or SENT BACK - its
## faults added to [method TableEpisode.send_back] for the painter of the next, and the painting deleted
## with what was made from it, so the producer paints it again and looks again - while it has been sent
## back fewer than [constant REPAINTS] times. Past that the last painting stands, and its faults are
## written into the check for the reader ([method say_prompt]).
func _land_check(step: String, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary) or not (String((d as Dictionary).get("verdict", "")) in ["keep", "repaint"]):
		return "the art director's reply was not a verdict"
	var k := int(step.split(":")[1])
	var faults := Array(DataPath.strings((d as Dictionary).get("faults", [])))
	var rounds := episode.sent_back(k).size()
	if String((d as Dictionary)["verdict"]) == "keep" or faults.is_empty():
		return episode.write_json(step, {"kept": true, "sent_back": rounds})
	if rounds >= REPAINTS:
		print("ghost: table %s - painted %d times; it stands with: %s" % [step, rounds + 1, "; ".join(faults)])
		return episode.write_json(step, {"kept": false, "sent_back": rounds, "faults": faults})
	var err := episode.send_back(k, faults)
	if not err.is_empty():
		return err
	print("ghost: table %s - sent back: %s" % [step, "; ".join(faults)])
	episode.invalidate("image:card:%d" % k, true)
	# a new painting, and a new look at it: neither is a retry of a failed job
	_tries.erase(step)
	_tries.erase("image:card:%d" % k)
	return ""


func _land_design(step: String, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary) or _str((d as Dictionary).get("art", "")).is_empty():
		return "the design was not JSON with an illustration"
	# A WRITTEN CARD'S WRITING ([constant CardTable.FRAMES] `written`): its title and its lines, kept as written -
	# and as its entry's text, a line to each, for every reader and the work that read a card's entry
	if CardTable.written(CardTable.sanitize_look(_look())):
		var w: Variant = (d as Dictionary).get("writing", {})
		var lines := DataPath.strings((w as Dictionary).get("lines", [])) if w is Dictionary else PackedStringArray()
		if lines.is_empty():
			return "the design has no writing: a written card needs its `writing`, a title and its lines"
		var writing := {"title": _str((w as Dictionary).get("title", "")), "lines": Array(lines.slice(0, WRITING_MOST))}
		if String(writing["title"]).is_empty():
			writing["title"] = String(_card(int(step.get_slice(":", 1))).get("name", ""))
		return episode.write_json(step, {"art": _str((d as Dictionary)["art"]), "writing": writing,
			"booklet": {"keywords": [], "upright": "\n".join(PackedStringArray(writing["lines"]))}})
	var b: Variant = (d as Dictionary).get("booklet", {})
	if not (b is Dictionary) or _str((b as Dictionary).get("upright", "")).is_empty():
		return "the design has no booklet entry"
	var booklet := {"keywords": Array(DataPath.strings((b as Dictionary).get("keywords", []))),
		"upright": _str((b as Dictionary).get("upright", ""))}
	if not _str((b as Dictionary).get("reversed", "")).is_empty():
		booklet["reversed"] = _str((b as Dictionary)["reversed"])
	return episode.write_json(step, {"art": _str((d as Dictionary)["art"]), "booklet": booklet})


## THE WORK, kept as the puppeteer wrote it - made safe each time it is played ([method Motions.sanitize_acts]),
## so an edit by hand is read the same way - if any act in it can be kept.
func _land_acts(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if d is Array:
		d = {"acts": d}
	if not (d is Dictionary):
		return "the acts were not JSON"
	var made := Motions.sanitize_acts(d, episode.beat_count())
	if (made["acts"] as Array).is_empty():
		return "no act could be kept: %s" % "; ".join(made["notes"])
	for n in made["notes"]:
		print("ghost: table acts - %s" % String(n))
	return episode.write_json("acts", d)


## THE TABLE, kept as the set dresser wrote it - it is made safe each time it is built
## ([method CardTable.sanitize_table]), so an edit by hand is read the same way - if anything in
## it can be built.
func _land_table(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the table was not JSON"
	if (CardTable.sanitize_table(d as Dictionary, _look())["things"] as Array).is_empty():
		return "nothing on the table could be built"
	return episode.write_json("table", d)


## A reply's field as text, whatever the writer made it (JSON numbers arrive as floats).
## WHAT ONE BEAT IS CALLED (`beat_word`, the producer's from the brief - an Ingredient, a Card, a Coat; the
## episode's rows are named by it, [method TableEpisode.beat_word]): its first word, letters only, at most 16 of
## them, capitalized - "" for none.
static func beat_word_of(v: Variant) -> String:
	var w := _str(v).get_slice(" ", 0)
	var out := ""
	for i in w.length():
		var c := w.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45 or c == 39:
			out += w[i]
	out = out.left(16)
	return out.left(1).to_upper() + out.substr(1)


static func _str(v: Variant) -> String:
	if v is String:
		return (v as String).strip_edges()
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return "" if v == null else str(v).strip_edges()


## THE READER'S WORDS AS THE VOICE GETS THEM. The prompt asks for spoken words only; this is
## what is left to do when a writer adds a little anyway - wrapping quotes, a heading, a
## bracketed stage direction, a line that is nothing but an action in asterisks - and the em
## dash, which the voice reads as a pause either way and the subtitles show as a plain dash.
## The show's voices besides the reader's: the names its document gives them, in its order. The
## reader is its FIRST voice, whatever the document calls it - a script cues it as
## [constant Manuscript.NARRATOR] ([method ReadingCast.reader]).
func _voices() -> Array:
	var out: Array = []
	var all: Array = spec.get("voices", [])
	for k in all.size():
		if k > 0 and String(all[k]) != Manuscript.NARRATOR and not out.has(String(all[k])):
			out.append(String(all[k]))
	return out


## The reader's own name in the show's document (its first voice), or empty when it has none.
func _reader_name() -> String:
	var all: Array = spec.get("voices", [])
	return String(all[0]) if not all.is_empty() else ""


## [param text] with every change of speaker naming one of the show's own [param voices] (or the
## reader), spelled as the show spells it; a cue naming anyone else is taken out, and its words
## stay with whoever was speaking. A writer's "familiar" would otherwise be a new voice of its own,
## a copy of the reader's, kept in the show's document from then on. A cue naming the reader by
## the show's own name for it ([param reader]) hands the line back to the reader.
## A READER WRITES WORDS AND THE VOICE'S MARKS - a delivery, a hesitation, a change of speaker - AND
## NOTHING ELSE (next/notes.md step 9: "an unknown one is dropped"): every other comment in a reply
## goes, a table mark above all. `<!-- table: draw 2 -->` in a reading's words would be parsed as an
## action when the script is composed - [method CardReading.parse] reads every own-line mark - and
## deal a card nobody drew; the table's actions are the producer's to write ([method CardReading.compose]).
##
## [param acts]: the names of the acts this passage may start at a word (`<!-- act: name -->`, [CardReading]) -
## a cue naming any other is dropped as any mark is.
static func voice_marks_only(text: String, acts: Array = []) -> String:
	var keep := [Manuscript._rx(Manuscript.DELIVERY), Manuscript._rx(Manuscript.HESITATION),
		Manuscript._rx(Manuscript.SPEAKER)]
	var cue := Manuscript._rx(CardReading.ACT_MARK)
	var out := ""
	var at := 0
	for m in Manuscript._rx(Manuscript.COMMENT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var c := m.get_string()
		var named := cue.search(c)
		if named != null:
			if acts.has(named.get_string(1).strip_edges().to_lower()):
				out += "<!-- act: %s -->" % named.get_string(1).strip_edges().to_lower()
			continue
		if keep.any(func(r: RegEx) -> bool: return r.search(c) != null):
			out += c
	return out + text.substr(at)


static func own_voices(text: String, voices: Array, reader := "") -> String:
	var known := {Manuscript.NARRATOR.to_lower(): Manuscript.NARRATOR}
	if not reader.is_empty():
		known[reader.to_lower()] = Manuscript.NARRATOR
	for v in voices:
		known[String(v).to_lower()] = String(v)
	var cue := Manuscript._rx(Manuscript.SPEAKER)
	var out := ""
	var at := 0
	for m in Manuscript._rx(Manuscript.COMMENT).search_all(text):
		var c := cue.search(m.get_string())
		if c == null:
			continue
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var who := (c.get_string(1) if not c.get_string(1).is_empty() else c.get_string(2)).strip_edges()
		if known.has(who.to_lower()):
			out += "<!-- speaker: %s -->" % String(known[who.to_lower()])
	return out + text.substr(at)


static func clean_spoken(text: String, acts: Array = []) -> String:
	var t := voice_marks_only(text.strip_edges(), acts)
	if t.length() >= 2 and t.begins_with("\"") and t.ends_with("\""):
		t = t.substr(1, t.length() - 2)
	var keep := PackedStringArray()
	var action := Manuscript._rx("^\\s*(\\*[^*]+\\*|\\([^)]*\\)|\\[[^\\]]*\\])\\s*$")
	for line in t.split("\n"):
		var l := String(line)
		if l.strip_edges().begins_with("#") or action.search(l) != null:
			continue
		keep.append(l)
	t = "\n".join(keep)
	t = Manuscript._rx("\\[[^\\]]*\\]").sub(t, "", true)
	# (`**word**` stays as written: it is the harder of the two stresses, and shown in bold)
	t = t.replace("\u2014", " - ").replace("\u2013", " - ")
	t = Manuscript._rx("[ \\t]{2,}").sub(t, " ", true)
	t = Manuscript._rx("\\n{3,}").sub(t, "\n\n", true)
	return t.strip_edges()

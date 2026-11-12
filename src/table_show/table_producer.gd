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
##   prep       A GAME (next/tabletop.md): the game master prepares, in secret: the world, and every player's sheet and want
##   say:K      ...and in a game each is a stretch of the session, played live through [GameTools], the players asked as it goes, the words and the dice written as they happen
##   image:map:K, image:figure:K, image:reveal:K     ...painted after it is played: whatever it turned out to need
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
const BEATS_MOST := 12
## The most cards an episode draws: a spread planned longer is cut to it ([method _land_plan]).
const SPREAD_MOST := 10
## How many times the art director may send one card's painting back ([method _land_check]): past
## that the last painting stands, and the reader is told what it gets wrong.
const REPAINTS := 2
## THE PICTURE PAINTED FIRST IS PAINTED AGAIN IN THIS MANY LAYERS at the least and the most ([method _land_layers]).
const LAYERS_LEAST := 3
const LAYERS_MOST := 16
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
## WHO MAKES EACH KIND OF STEP, as its record and its row name them (a step's first word -> its maker).
const MAKERS := {"plan": "producer", "design": "designer", "image": "painter", "check": "art director",
	"table": "set dresser", "say": "reader", "acts": "puppeteer", "model": "modeler", "skin": "decorator", "prep": "game master",
	"layers": "art director"}

var episode: TableEpisode
## {title, brief, deck, chooses, writer, painter} - how many cards are drawn, whether they come up reversed
## and whether one jumps are the plan's ([method _land_plan], [method CardTable.staging_of]), never the author's
var spec: Dictionary = {}
var running := false
## The steps this run was asked for; empty for the whole episode.
var only: Array = []
## THE STEPS MADE AGAIN THOUGH THEY ARE MADE (a row's ⟳, [method start]'s [param remake]): what stands plays until the new one lands
## over it, a version back ([method TableEpisode.keep_version]), and what was made from it goes stale - nothing is thrown away.
var again: Array = []

var _jobs := {}        # step -> AgentJobs id
var _tools := {}       # step -> {url, set}: the tools a step's agent is working with, until it lands
var _errors := {}      # step -> why it failed, once it is out of tries
var _tries := {}       # step -> runs started
var _hosts := {}       # step -> the painter host making it: {pid, out, log} ([method _make_skin_host])
var _waiting := {}     # step -> what it waits on being installed
var _from := {}        # step -> what it was made from as its making began ([method TableEpisode.made_from])
## ONE LAYER LAID AGAIN ([method lay_layer]; next/editing.md step 4): its index from 0, -1 for the whole painting.
var skin_layer := -1
## STEPS ASKED AGAIN WITH A NOTE (next/editing.md step 9): step -> the author's note, appended to that step's prompt alone
## ([method _asked]) until it lands.
var asked := {}


func _init(ep: TableEpisode, sp: Dictionary) -> void:
	episode = ep
	spec = sp


## Make what is missing: every step, or only [param steps] (and the free steps that follow them) - and, with [param remake], those
## steps again though they are made (a row's ⟳). GENERATE ([param steps] empty) MAKES WHAT IS MISSING AND WHAT IS STALE, unless it
## is kept ([method owed]). A person pressing is what starts it, so here an episode made before records gains them ([method
## TableEpisode.adopt]).
func start(steps: Array = [], remake := false, note := "", layer := -1) -> void:
	_errors.clear()
	_tries.clear()
	skin_layer = layer
	only = steps.duplicate()
	again = steps.duplicate() if remake else []
	asked = {}
	if not note.strip_edges().is_empty():
		for s in steps:
			asked[String(s)] = note.strip_edges()
	episode.adopt()
	running = true
	tick()
	changed.emit()


func stop() -> void:
	running = false
	for step in _jobs:
		AgentJobs.cancel(String(_jobs[step]))
		AgentJobs.forget(String(_jobs[step]))
	_jobs.clear()
	for step in _hosts:
		Subprocess.stop(int((_hosts[step] as Dictionary)["pid"]))
	_hosts.clear()
	_waiting.clear()
	for step in _tools.keys():
		_close_tools(String(step))
	changed.emit()


func busy() -> bool:
	return not _jobs.is_empty() or not _hosts.is_empty()


## "ready", "running", "queued", "failed" or "missing". A step being made again is being made, and one that failed to be made
## again failed - what stands of it still plays.
func state_of(step: String) -> String:
	if _jobs.has(step):
		var st := AgentJobs.state(String(_jobs[step]))
		return "running" if st == "running" else "queued"
	if _hosts.has(step):
		return "running"
	if _waiting.has(step):
		return "queued"
	if _errors.has(step):
		return "failed"
	if episode.has(step):
		return "ready"
	return "missing"


func error_of(step: String) -> String:
	return String(_errors.get(step, ""))


## What [param step]'s agent is doing now ([method AgentJobs.activity]); "" when it is not being made.
func activity_of(step: String) -> String:
	if _hosts.has(step):
		# (...the painter host's last line: which layer, how far)
		var lines := FileAccess.get_file_as_string(String((_hosts[step] as Dictionary)["log"])).strip_edges().split("\n")
		return "the painter: " + String(lines[lines.size() - 1]).strip_edges() if not lines.is_empty() else "the painter is starting"
	if _waiting.has(step):
		return String(_waiting[step])
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
		if episode.has(String(step)) and not _errors.has(step):
			_made(String(step), String(MAKERS.get(String(step).get_slice(":", 0), "agent")))
		moved = true
	for step in _hosts.keys():
		if Subprocess.alive(int((_hosts[step] as Dictionary)["pid"])):
			continue
		var h: Dictionary = _hosts[step]
		_hosts.erase(step)
		var err := _land_skin_host(h)
		if not err.is_empty():
			_errors[step] = err
			# ...said in the log as an agent's failure is, with the host's own last lines (its traceback), or it shows only on the card
			push_warning("ghost: table %s - %s" % [step, err])
			var tail := FileAccess.get_file_as_string(String(h["log"])).strip_edges().split("\n")
			print("ghost: table %s - the painter's log (%s) ends:\n%s" % [step, String(h["log"]), "\n".join(tail.slice(maxi(tail.size() - 12, 0)))])
		else:
			_made(String(step), "painter host")
		moved = true
	if running:
		for step in episode.steps():
			var s := String(step)
			if (episode.has(s) and not owed(s)) or _jobs.has(s) or _hosts.has(s) or _errors.has(s) or passes_by(s):
				continue
			# ...ONCE WHAT IT IS MADE FROM IS MADE, AND NOT ABOUT TO BE MADE AGAIN: made now from what goes a version back, it
			# would only go stale
			var ready := true
			for need in episode.needs(s):
				if not episode.has(String(need)) or owed(String(need)) or _jobs.has(String(need)) or _hosts.has(String(need)):
					ready = false
					break
			if not ready or not (only.is_empty() or only.has(s) or LOCAL.has(s)):
				continue
			_make(s)
			moved = true
		if _jobs.is_empty() and _hosts.is_empty() and _waiting.is_empty():
			running = false          # done, or stopped on a failure nothing else can get past
			moved = true
	if moved:
		changed.emit()


# --- making one step ---------------------------------------------------------------------

## WHETHER [param step], MADE, IS TO BE MADE AGAIN in this run: asked for again ([member again]), or stale and not kept ([method
## TableEpisode.stale], [method TableEpisode.kept]) where Generate runs - or where it is a free step that follows what was asked.
func owed(step: String) -> bool:
	if again.has(step):
		return true
	return (only.is_empty() or LOCAL.has(step)) and episode.stale(step) and not episode.kept(step)


## [param prompt] for [param step], with the author's note where it was asked again with one ([member asked]).
func _asked(step: String, prompt: String) -> String:
	return prompt if not asked.has(step) else prompt + "\n\n" + Rules.say("table/show.asked", {"note": String(asked[step])})


## WHETHER GENERATE PASSES [param step] BY, made or not: it is made by hand ([method TableEpisode.by_hand]) and nobody asked for
## it by name (a row's ⟳ hands it to its agent).
func passes_by(step: String) -> bool:
	return episode.by_hand(step) and not again.has(step) and not only.has(step)


## [param step] LANDED, made by [param by]: recorded from what it was made from as its making began, and no longer owed.
func _made(step: String, by: String) -> void:
	var err := episode.note_made(step, by, _from.get(step, {}))
	if not err.is_empty():
		push_warning("ghost: table %s - its record was not kept: %s" % [step, err])
	_from.erase(step)
	again.erase(step)
	asked.erase(step)


func _make(step: String) -> void:
	_from[step] = episode.made_from(step)
	var parts := step.split(":")
	match String(parts[0]):
		"plan":
			_make_plan()
		"draw":
			_finish(step, _make_draw())
		"design":
			_make_design(int(parts[1]))
		"check":
			if String(parts[1]) == "face":
				_make_face_check()
			else:
				_make_check(int(parts[1]))
		"image":
			_make_image(step)
		"say":
			# "intro", "close", a card's place - or "work:K", card K's work passage
			_make_say(step.trim_prefix("say:"))
		"script":
			_finish(step, _make_script())
		"model":
			_make_model()
		"skin":
			_make_skin()
		"table":
			_make_table()
		"acts":
			_make_acts()
		"prep":
			_make_prep()
		"layers":
			_make_layers()


## [param extra]: more of the job's spec - its tools and their timeout (see [method _make_table]).
func _submit_text(step: String, p: Dictionary, tier: String, extra: Dictionary = {}) -> void:
	_tries[step] = int(_tries.get(step, 0)) + 1
	if not p.has("system") or not p.has("prompt"):
		_errors[step] = "its prompt could not be built (see the log)"
		_close_tools(step)
		return
	var job := {"kind": "text", "backend": String(spec.get("writer", "claude")),
		"tier": tier, "dir": episode.job_dir(step), "system": String(p["system"]),
		"prompt": _asked(step, String(p["prompt"])), "images": p.get("images", []), "label": "table %s" % step,
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
	# (the painter writes its picture straight over the one there: that one a version back first)
	episode.keep_version(step)
	var id := AgentJobs.submit({"kind": "image", "backend": String(spec.get("painter", "codex")),
		"dir": episode.job_dir(step), "prompt": _asked(step, prompt), "refs": refs,
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
	else:
		_made(step, "code")


func _plan() -> Dictionary:
	var p: Variant = episode.read_json("plan")
	if not (p is Dictionary):
		return {}
	# ...WHAT IS BEING BUILT, for everyone after whoever designed it ([method TableEpisode.model_words])
	var words := episode.model_words()
	if not words.is_empty():
		(p as Dictionary)["model_words"] = words
	# ...THE SHOW'S FIXED THINGS, standing on every table as its brief writes them ([FixedTable])
	var fixed: Dictionary = spec.get("fixed", {}) if spec.get("fixed") is Dictionary else {}
	if not (fixed.get("things", []) as Array).is_empty():
		var said := PackedStringArray()
		for t in fixed["things"]:
			if t is Dictionary:
				var at: Variant = (t as Dictionary).get("at", [0, 0])
				said.append("\"%s\" at %s" % [String((t as Dictionary).get("name", "")), JSON.stringify(at)])
		(p as Dictionary)["fixed_things"] = ", ".join(said)
	# ...AND WHAT IS PAINTED, element by element, for whoever lays it on ([Skins])
	var doc: Variant = episode.read_json("skin") if episode.has("skin") else null
	if doc is Dictionary:
		var lines := PackedStringArray()
		for g in (doc as Dictionary).get("designs", []):
			if not (g is Dictionary):
				continue
			var gd: Dictionary = g
			var fr: Array = gd.get("frame", [150.0, 210.0])
			var made := Skins.sanitize(gd, Vector2(float(fr[0]), float(fr[1])))
			lines.append("\"%s\", painted on \"%s\"%s - its elements in the order they go on:" % [made["name"], gd.get("thing", ""),
				("/" + String(gd["part"])) if not String(gd.get("part", "")).is_empty() else ""])
			lines.append_array(Skins.summary(made, Vector2(float(fr[0]), float(fr[1]))))
		if not lines.is_empty():
			(p as Dictionary)["painted_design"] = "\n".join(lines)
	return p


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
	# WHAT THE SESSION ASKED TO HAVE PAINTED ([method TableEpisode.game]), the map's own in its look, a figure's on the card it stands on
	if parts.size() == 3 and TableEpisode.GAME_PICTURES.values().has(String(parts[1])):
		var key := String(TableEpisode.GAME_PICTURES.find_key(String(parts[1])))
		var list: Array = episode.game().get(key, [])
		var k := int(parts[2]) - 1
		var thing: Dictionary = list[k] if k >= 0 and k < list.size() and list[k] is Dictionary else {}
		_submit_image(step, TablePrompts.game_image(look, String(parts[1]), thing, target), [])
		return
	# A LAYER OF THE PICTURE PAINTED FIRST: painted over the one before (the bare surface, for the first), the picture itself its guide
	if parts.size() == 3 and String(parts[1]) == "layer":
		_make_layer(step, int(parts[2]), look, target)
		return
	match String(parts[1]):
		"face":
			_make_face(step, look, target)
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


# --- a game played at the table (next/tabletop.md) ---------------------------------------------------------------------------------------------------

## Everyone at the table, the game master first: the show's voices, as its document spells them.
func _people() -> PackedStringArray:
	return PackedStringArray((spec.get("voices", []) as Array).map(func(v: Variant) -> String: return String(v)))


func _make_prep() -> void:
	_close_tools("prep")
	var people := _people()
	if people.size() < 2:
		_errors["prep"] = "a game needs a game master and a player: give the show at least two voices"
		return
	if not TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		_errors["prep"] = "its writer cannot use tools, and a game is played with them: pick another"
		return
	var toolset := GamePrepTools.new(episode.job_dir("prep"), episode.seed, people.slice(1))
	var url := AgentTools.open(episode.job_dir("prep"), toolset)
	if url.is_empty():
		_errors["prep"] = "no tools can be served here"
		return
	_tools["prep"] = {"url": url, "set": toolset}
	_submit_text("prep", TablePrompts.game_prep(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(), people, TableEpisode.archive(episode.show, episode.seed)), "best", {"tools_url": url})


func _land_prep(text: String) -> String:
	var got: Variant = JSON.parse_string(text)
	var wrong := GamePrepTools.problems(got, _people().slice(1))
	if not wrong.is_empty():
		return "; ".join(wrong)
	return episode.write_json("prep", got)


## THE SHEETS AS THE PREPARATION WROTE THEM, by each person as the table spells them.
static func sheets_of(prep: Dictionary, people: PackedStringArray) -> Dictionary:
	var out := {}
	var all: Dictionary = prep.get("people", {}) if prep.get("people") is Dictionary else {}
	for who in people:
		var got: Variant = GamePrepTools._named(all, who)
		if got is Dictionary and (got as Dictionary).get("sheet") is Dictionary:
			out[who] = ((got as Dictionary)["sheet"] as Dictionary).duplicate(true)
	return out


## ONE STRETCH OF THE SESSION: its tools hold the table as the last one left it, and the stretch is what they write. Once the game is over, a stretch is nothing: it was never played.
func _make_scene(who: String) -> void:
	var step := "say:" + who
	_close_tools(step)
	var prep: Variant = episode.read_json("prep")
	var prep_d: Dictionary = prep if prep is Dictionary else {}
	var people := _people()
	var past := episode.events_before(step)
	var ledger := GameLedger.from(sheets_of(prep_d, people), past)
	if ledger.over and who != "close":
		_finish(step, episode.write_text(step, ""))
		return
	var title := String(spec.get("title", ""))
	var plan := _plan().duplicate()
	plan["_show_title"] = title
	plan["_brief"] = String(spec.get("brief", ""))
	var before := _heard_so_far(step)
	var toolset := GameTools.new(episode, who, plan, prep_d, people, ledger, episode.job_dir(step), before)
	toolset.players = {"backend": String(spec.get("players", spec.get("writer", "claude"))), "model": String(spec.get("players_model", "")), "effort": String(spec.get("players_effort", ""))}
	toolset.words_aim = TablePrompts.game_words(who, episode.beat_count())
	var url := AgentTools.open(episode.job_dir(step), toolset)
	if url.is_empty():
		_errors[step] = "no tools can be served here"
		return
	_tools[step] = {"url": url, "set": toolset}
	_submit_text(step, TablePrompts.game_master(title, String(spec.get("brief", "")), _plan(), people, who, episode.beat_count(), prep_d, ledger, before, toolset.words_aim), "best", {"tools_url": url})


## WHAT WAS SAID TONIGHT, before [param step]: with names and rolls, as anyone at the table heard it.
func _heard_so_far(step: String) -> String:
	var out := PackedStringArray()
	var order := ["say:intro"]
	for k in range(1, episode.beat_count() + 1):
		order.append("say:%d" % k)
	order.append("say:close")
	for s in order:
		if String(s) == step:
			break
		var heard := FileAccess.get_file_as_string(_heard_file(String(s)))
		if not heard.is_empty():
			out.append(heard)
	return "\n".join(out)


func _heard_file(say: String) -> String:
	return episode.dir.path_join("heard_%s.txt" % say.trim_prefix("say:"))


## A STRETCH HANDED IN: its events first, so words that are there have their events; what was heard, for those at the table next time; then its words.
func _land_scene(step: String, handed: String) -> String:
	var got: Variant = JSON.parse_string(handed)
	if not (got is Dictionary) or String((got as Dictionary).get("text", "")).strip_edges().is_empty():
		return "the scene handed in has nothing in it"
	var d: Dictionary = got
	var events: Array = d.get("events", []) if d.get("events") is Array else []
	var f := FileAccess.open(episode.events_file(step), FileAccess.WRITE)
	if f == null:
		return "could not write its events"
	f.store_string(JSON.stringify(events))
	f.close()
	var h := FileAccess.open(_heard_file(step), FileAccess.WRITE)
	if h != null:
		h.store_string(GameTools.transcript(d.get("items", []) if d.get("items") is Array else [], events))
		h.close()
	return episode.write_text(step, own_voices(String(d["text"]), _voices(), _reader_name()))


## THE SESSION, gathered for the table and the painter (`game.json`): everything that happened, who sits where with which dice, and each thing it asked to be painted, once.
func _write_game() -> String:
	var people := _people()
	var prep: Variant = episode.read_json("prep")
	var prep_d: Dictionary = prep if prep is Dictionary else {}
	var game := GameBoard.gather(episode.events_before(""), people, prep_d, spec.get("seats", {}) if spec.get("seats") is Dictionary else {})
	return episode.write_json("game", game)


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


## THE FACE PAINTED FIRST (feedback 0023; next/painted_surface.md - the user, of a face the decorator drew from nothing: "a rather
## terrible and unimpressive mask ... It might even be worth generating reference artwork from the painter, which we could copy from"):
## the table's first surface shown bare from its front ([method Skins.face_canvas], kept beside the episode with where it lies in it), and
## the painter asked to paint the plan's `painted` onto that picture - so its features are the surface's own and every mark lands on them -
## told what the art director sent back of its earlier paintings.
func _make_face(step: String, look: Dictionary, target: String) -> void:
	var surfaces := Skins.skins_of(episode.read_json("table"))
	if surfaces.is_empty():
		_errors[step] = "the table has no surface to paint (no part with `skin`)"
		return
	var skin: Dictionary = surfaces[0]
	var canvas := Skins.face_canvas(skin)
	var bare := episode.dir.path_join("face_bare.png")
	DirAccess.make_dir_recursive_absolute(episode.dir)
	if (canvas["image"] as Image).save_png(bare) != OK:
		_errors[step] = "could not write " + bare
		return
	var at: Vector2i = canvas["at"]
	var size: Vector2i = canvas["size"]
	var err := TextGen.put(episode.dir.path_join("face.json"), JSON.stringify({"on": "%s/%s" % [skin["thing"], skin["part"]],
		"at": [at.x, at.y], "size": [size.x, size.y], "px": float(canvas["px"])}, "\t"))
	if not err.is_empty():
		_errors[step] = err
		return
	var faults := PackedStringArray()
	for round in episode.sent_back("face"):
		for f in DataPath.strings(round):
			if not faults.has(f):
				faults.append(f)
	_submit_image(step, TablePrompts.face_image(look, _plan(), skin, target, faults, Skins.table_paints(episode.read_json("table"))), [bare])


## THE FACE PAINTED FIRST, KEPT ONLY IF IT LIES ON THE SURFACE ([method Skins.face_fit]) - then cut back to the surface's millimeters as it
## wears it (`face_ref.png`, [method Skins.face_reference]), which the decorator copies; or removed, and why said - to the painter of the next too
## ([method TableEpisode.send_back]).
func _land_face() -> String:
	var painted := Image.load_from_file(episode.file_of("image:face"))
	var bare := Image.load_from_file(episode.dir.path_join("face_bare.png"))
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(episode.dir.path_join("face.json")))
	var surfaces := Skins.skins_of(episode.read_json("table"))
	if painted == null or bare == null or painted.is_empty() or bare.is_empty() or not (meta is Dictionary) or surfaces.is_empty():
		DirAccess.remove_absolute(episode.file_of("image:face"))
		return "the face, its canvas or the surface could not be read"
	var wrong := Skins.face_fit(bare, painted)
	if not wrong.is_empty():
		# ...and the painter of the next told why, as the art director's faults are told it
		print("ghost: table image:face - %s" % wrong)
		DirAccess.remove_absolute(episode.file_of("image:face"))
		episode.send_back("face", [wrong])
		return "the face did not lie on the surface: " + wrong
	var m: Dictionary = meta
	var canvas := {"at": Vector2i(int((m["at"] as Array)[0]), int((m["at"] as Array)[1])),
		"size": Vector2i(int((m["size"] as Array)[0]), int((m["size"] as Array)[1]))}
	var ref := Skins.face_reference(painted, bare, canvas, surfaces[0])
	return "" if ref.save_png(episode.dir.path_join("face_ref.png")) == OK else "could not write face_ref.png"


## THE PAINTER AT THE TABLE, AS A HOST (next/face_layers.md; the user, 2026-11-09: "the old painter code is pointless, because it makes
## a mess. I want to use the optimizer"): the episode's layers laid with real marks by hosts/paint/run.py - each layer's thin parts traced
## on its own picture, its broad parts by strokes found by gradient descent - written as the show plays it (`paint/`): each element's
## program and maps. Waits while its environment is installed; landed by [method _land_skin_host].
func _make_skin_host() -> void:
	_waiting.erase("skin")
	if not Provision.ensure("paint_venv"):
		_waiting["skin"] = "waiting for the painter's environment to be installed (%s)" % String(Deps.entry("paint_venv").get("size", ""))
		return
	var py := Deps.venv_bin("user://paint_venv", "python")
	var host := BundledHosts.path("res://hosts/paint/run.py")
	if not FileAccess.file_exists(py) or host.is_empty():
		_errors["skin"] = "the painter's environment is not installed"
		return
	var tbl: Variant = episode.read_json("table")
	var surfaces := Skins.skins_of(tbl)
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(episode.dir.path_join("face.json")))
	if surfaces.is_empty() or not (meta is Dictionary):
		_errors["skin"] = "the table has no surface, or the picture's place on it is lost"
		return
	var paints := {}
	for pd in (PainterTools.scan(tbl as Dictionary)["paints"] as Array):
		if not bool((pd as Dictionary)["powder"]) and not bool((pd as Dictionary)["finish"]):
			paints[String(pd["name"])] = "#" + (pd["color"] as Color).to_html(false)
	var images := PackedStringArray()
	var layers: Array = []
	for k in range(1, episode.layer_count() + 1):
		images.append(ProjectSettings.globalize_path(episode.file_of("image:layer:%d" % k)))
		var l: Dictionary = episode.layers()[k - 1]
		layers.append({"name": String(l.get("name", "")), "soft": bool(l.get("soft", false))})
	# ...INTO A FOLDER OF ITS OWN, so what stands plays on while it paints and is kept one back once it lands ([method swap_paint])
	var out := ProjectSettings.globalize_path(episode.dir.path_join(PAINT_NEXT))
	DirAccess.make_dir_recursive_absolute(out)
	var m: Dictionary = meta
	var spec := out.path_join("spec.json")
	# (...pixels as whole numbers: JSON keeps no ints, and `face.json`'s `[0, 22]` comes back `[0.0, 22.0]`, which Python cannot slice by)
	var at := [int((m["at"] as Array)[0]), int((m["at"] as Array)[1])]
	var size := [int((m["size"] as Array)[0]), int((m["size"] as Array)[1])]
	var fields := {"out": out, "bare_image": ProjectSettings.globalize_path(episode.dir.path_join("face_bare.png")),
		"at": at, "size": size, "px": float(m.get("px", 3.0)), "bare": String((surfaces[0] as Dictionary).get("color", "#c89e80")),
		"paints": paints, "layers": layers, "images": images}
	# ...ONE LAYER ALONE ([method lay_layer]): over the canvas the layers before it leave, the rest kept as they stand
	if skin_layer >= 0:
		fields["only"] = skin_layer
		fields["keep"] = ProjectSettings.globalize_path(episode.dir.path_join("paint"))
	var err := TextGen.put(spec, JSON.stringify(fields, "\t"))
	if not err.is_empty():
		_errors["skin"] = err
		return
	var log := out.path_join("painter.log")
	var pid := Subprocess.start_logged(py, PackedStringArray(["-I", host, spec]), log, "painter")
	if pid <= 0:
		_errors["skin"] = "the painter could not start"
		return
	_hosts["skin"] = {"pid": pid, "out": out, "log": log}


## THE PAINTER'S WORK, KEPT AS THE DESIGN (`skin.json`): an element each run of one layer's marks with one tool in one paint, in order - its
## tool the table's nearest ([method _table_tool]), its pot its paint's, its beat where it begins in the painting's time ([method
## _element_beats]), and `plan.host` naming its program and maps in `paint/elements.json` (TablePaint._from_host). "" kept, else why not.
func _land_skin_host(h: Dictionary) -> String:
	var out := String(h["out"])
	var done: Variant = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("done.json"))) if FileAccess.file_exists(out.path_join("done.json")) else null
	if not (done is Dictionary) or not bool((done as Dictionary).get("ok", false)):
		var said := String((done as Dictionary).get("error", "")) if done is Dictionary else FileAccess.get_file_as_string(String(h["log"])).strip_edges().right(400)
		return "the painter failed: " + said
	if not FileAccess.file_exists(out.path_join("elements.json")):
		return "the painter laid nothing"
	var swapped := swap_paint(out)
	if not swapped.is_empty():
		return swapped
	out = ProjectSettings.globalize_path(episode.dir.path_join("paint"))
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("elements.json")))
	var els: Array = (doc as Dictionary).get("elements", []) if doc is Dictionary else []
	if els.is_empty():
		return "the painter laid nothing"
	var tbl: Variant = episode.read_json("table")
	var scanned := PainterTools.scan(tbl as Dictionary)
	var skin: Dictionary = Skins.skins_of(tbl)[0]
	var beats := _element_beats(els)
	var elements: Array = []
	for e in els:
		var ed: Dictionary = e
		var tool := _table_tool(String(ed["tool"]), scanned["tools"])
		var r: Array = ed["rect"]
		var x0 := float(r[0])
		var y0 := float(r[1])
		var x1 := x0 + float(r[2])
		var y1 := y0 + float(r[3])
		elements.append({"id": String(ed["id"]), "stage": String(ed.get("layer_name", "")), "paint": String(ed["color"]), "opacity": 1.0,
			"finish": "matte", "fill": "M %.1f %.1f L %.1f %.1f L %.1f %.1f L %.1f %.1f Z" % [x0, y0, x1, y0, x1, y1, x0, y1],
			"plan": {"thing": String(tool.get("thing", "")), "part": String(tool.get("part", "")), "how": String(ed["how"]),
				"beat": String(beats[String(ed["id"])]), "seconds": float(ed["seconds"]), "pot": _pot_of_paint(String(ed["paint"]), scanned["paints"]),
				"host": String(ed["id"])}})
	# ...ONE LAYER LAID AGAIN ([method lay_layer]): the design as it stood for every other layer - a hand's edits to them kept -
	# and this layer's new elements in its place among them
	if skin_layer >= 0 and episode.has("skin"):
		elements = merged_layer(episode.read_json("skin"), elements, episode.layers(), skin_layer)
	var design := {"thing": String(skin["thing"]), "part": String(skin["part"]), "frame": [(skin["frame"] as Vector2).x, (skin["frame"] as Vector2).y],
		"outline": String(skin.get("outline", "")), "name": String(_plan().get("painted", "")).left(60), "elements": elements}
	var wrote := episode.write_json("skin", {"designs": [design]})
	# ...AND THE WORK THAT IS MADE FROM IT, where it stands and is not kept: it is the painting's own, made from it here in a moment,
	# and left it would block elements there are no longer. The words are left as they are: a cue names a layer, which a repaint
	# keeps ([method TableWork.resolve_cues]), and one that names nothing now is a problem shown (next/editing.md step 2)
	if wrote.is_empty() and episode.has("acts") and not episode.kept("acts"):
		var remade := _acts_from_painting()
		if remade.is_empty():
			_made("acts", "code")
		elif remade != NOT_PAINTED:
			push_warning("ghost: table acts - made again from the painting: " + remade)
	return wrote


## LAYER [param k] (from 1) LAID AGAIN ON THE TABLE, ALONE (next/editing.md step 4: "The painter host solves one layer and replaces
## only that layer's elements"): the host paints it over the canvas the layers before it leave and puts its new elements among the
## rest, and the design is made again from them - minutes, where the whole painting is forty. "" started, else why not.
func lay_layer(k: int) -> String:
	if k < 1 or k > episode.layer_count():
		return "there is no layer %d" % k
	if not FileAccess.file_exists(episode.dir.path_join("paint").path_join("elements.json")):
		return "the painting has not been laid on the table yet: make the design first"
	start(["skin"], true, "", k - 1)
	return ""


## THE DESIGN'S ELEMENTS WITH ONE LAYER LAID AGAIN: [param old] (`skin.json` as it stands, a hand's edits and all) for every layer
## but [param layer] (from 0, of [param layers] - an element's `stage` its layer's name), and [param fresh]'s elements of that layer
## in their place, the layers in their order. Pure: a gate holds it.
static func merged_layer(old: Variant, fresh: Array, layers: Array, layer: int) -> Array:
	var names: Array = layers.map(func(l: Variant) -> String: return String((l as Dictionary).get("name", "")) if l is Dictionary else "")
	var redone := String(names[layer]) if layer >= 0 and layer < names.size() else ""
	var stood: Array = []
	for g in ((old as Dictionary).get("designs", []) if old is Dictionary else []):
		if g is Dictionary:
			stood = (g as Dictionary).get("elements", [])
			break
	var order := func(e: Variant) -> int: return names.find(String((e as Dictionary).get("stage", ""))) if e is Dictionary else -1
	var out: Array = []
	for e in stood:
		if order.call(e) >= 0 and order.call(e) < layer:
			out.append(e)
	for e in fresh:
		if e is Dictionary and String((e as Dictionary).get("stage", "")) == redone:
			out.append(e)
	for e in stood:
		if order.call(e) > layer:
			out.append(e)
	return out


## Where the painter host paints, beside what stands ([method swap_paint]).
const PAINT_NEXT := "paint_next"


## THE HOST'S NEW MAPS PUT IN PLACE, THE OLD ONES KEPT ONE BACK (next/editing.md step 1: "one back for a host's maps" - half a
## gigabyte each, so moved, never copied): `paint/` to `versions/_paint_prev/` (the one before that gone), [param fresh] to
## `paint/`. "" done, else why not (and what stood stands).
func swap_paint(fresh: String) -> String:
	var live := ProjectSettings.globalize_path(episode.dir.path_join("paint"))
	if fresh == live:
		return ""
	var prev := ProjectSettings.globalize_path(episode.dir.path_join(TableEpisode.VERSIONS_DIR).path_join("_paint_prev"))
	if DirAccess.dir_exists_absolute(live):
		TableEpisode._remove_tree(prev)
		DirAccess.make_dir_recursive_absolute(prev.get_base_dir())
		if DirAccess.rename_absolute(live, prev) != OK:
			return "the painter's last maps could not be kept one back"
	if DirAccess.rename_absolute(fresh, live) != OK:
		if DirAccess.dir_exists_absolute(prev) and not DirAccess.dir_exists_absolute(live):
			DirAccess.rename_absolute(prev, live)
		return "the painter's new maps could not be put in place"
	return ""


## EACH ELEMENT'S BEAT, by id: where its middle falls in the painting's time, each counted with the trips its run takes ([constant
## RUN_TRIPS]), spread over the intro and the beats - the ground in the intro, the close left to its words. A layer to a beat, 327484's
## crackle (a third of the time) had taken one beat and left three empty, and the close was given three layers. EACH BEAT ITS SHARE BY
## HOW LONG ITS WORDS TAKE, where they are written ([method _beat_seconds]), else evenly - the reader then writes them to the work
## (2026-11-10, the user: "Starting around 5:30, and continuing for at least 90 seconds... there is no animation at all"): 732687's
## painting, made again under its kept words and shorter, had a ground more than an even sixth of it, so the intro was given the ground
## alone - one sponge over seven minutes of words, put down long before the intro's last.
func _element_beats(els: Array) -> Dictionary:
	var keys: Array = ["intro"]
	for k in range(1, episode.beat_count() + 1):
		keys.append(str(k))
	var said := _beat_seconds()
	var ends: Array = []
	var sum := 0.0
	for key in keys:
		# (...every beat's words, or none: a beat not written yet would be given nothing)
		if float(said.get(key, 0.0)) <= 0.0:
			sum = 0.0
			break
		sum += float(said.get(key, 0.0))
	var at_end := 0.0
	for key in keys:
		at_end += float(said.get(key, 0.0)) / sum if sum > 0.0 else 1.0 / float(keys.size())
		ends.append(at_end)
	var total := 0.0
	for e in els:
		total += float((e as Dictionary)["seconds"]) + RUN_TRIPS
	var out := {}
	var at := 0.0
	for e in els:
		var ed: Dictionary = e
		var took := float(ed["seconds"]) + RUN_TRIPS
		var mid := (at + took * 0.5) / maxf(total, 1e-3)
		var k := keys.size() - 1
		for b in keys.size():
			if mid < float(ends[b]):
				k = b
				break
		out[String(ed["id"])] = "intro" if int(ed["layer"]) == 0 else String(keys[k])
		at += took
	return out


## What a run of one tool in one paint takes in the show beyond its strokes (seconds): fetched, loaded, rinsed, dried, moved and put back -
## 732687's 37 runs, 678 s of it.
const RUN_TRIPS := 18.0


## HOW LONG EACH BEAT'S WORDS TAKE, by beat ("intro", "1"...): its passage's words at the reader's pace ([method _said_word]) and its
## silences - empty where no passage is written yet.
func _beat_seconds() -> Dictionary:
	var bare := episode.cardless()
	var out := {}
	for st in episode.steps():
		var step := String(st)
		if not step.begins_with("say:") or not episode.has(step):
			continue
		var beat := _beat_of(step, bare)
		if beat.is_empty() or beat == "close":
			continue
		var text := episode.read_text(step)
		var words := Manuscript._rx(Manuscript.COMMENT).sub(text, "", true).replace("\n", " ").split(" ", false).size()
		var quiet := 0.0
		for m in Manuscript._rx(CardReading.QUIET_MARK).search_all(text):
			quiet += float(m.get_string(1))
		out[beat] = float(out.get(beat, 0.0)) + float(words) * _said_word() + quiet
	return out


## The table's tool nearest the painter's: a sponge for a sponge, else the brush nearest its width - A COTTON SWAB FOR THE PAINTER'S SWAB
## AND FOR NOTHING ELSE (feedback 0020, 2026-11-09: "we might be able to wipe it away with a cotton swab (if the mistake was small, or the
## color was faint)"): its lifts go to a brush whose tip is a bud ([constant PainterTools.SWAB_TIP]) where the table has one, else to the
## brush nearest its width, a clean brush lifting as well; and a swab, 5 mm across, is never the brush nearest a 6 mm round's.
static func _table_tool(name: String, tools: Array) -> Dictionary:
	var want := {"sponge": 30.0, "round": 6.0, "flat": 10.0, "liner": 2.0, "blender": 16.0, "fan": 12.0, "handle": 1.6, "pencil": 0.8,
		"lipstick": 4.0, "bud": 5.0, "finger": 12.0}
	var kind := "sponge" if name == "sponge" else "brush"
	var swab := name == "bud"
	var best := {}
	var bd := INF
	for pass_ in ([true, false] if swab else [false]):
		for t in tools:
			var td: Dictionary = t
			if String(td["kind"]) != kind or (String(td.get("tip", "")) == PainterTools.SWAB_TIP) != bool(pass_):
				continue
			var d := absf(log(maxf(float(td["mm"]), 0.1) / float(want.get(name, 6.0))))
			if d < bd:
				bd = d
				best = td
		if not best.is_empty():
			break
	if best.is_empty():
		for t in tools:
			if String((t as Dictionary)["kind"]) in ["brush", "sponge"] and (swab or String((t as Dictionary).get("tip", "")) != PainterTools.SWAB_TIP):
				return t
	return best


## The pot a paint is taken from: its own; a mix's, the paint there is most of; none for a clean brush. A MIX OF A MIX TOO (feedback
## 0006, 2026-11-09): "amber cream+olive cream+white paint 0.75 0.75" - each paint after the first mixed in at its share, so the white
## here is three quarters of it - had been read as one mix of "amber cream" and "olive cream+white paint 0.75", no paint at all, and its
## element named no pot.
static func _pot_of_paint(paint: String, paints: Array) -> String:
	if paint.is_empty():
		return ""
	var names := PackedStringArray()
	var shares: Array = []
	var num := RegEx.create_from_string("\\s+([0-9]*\\.?[0-9]+)$")
	for piece in paint.split("+"):
		var p := String(piece).strip_edges()
		var found: Array = []
		var m := num.search(p)
		while m != null:
			found.push_front(float(m.get_string(1)))
			p = p.substr(0, m.get_start()).strip_edges()
			m = num.search(p)
		shares.append_array(found)
		names.append(p)
	# (...the shares as they were written, in order: the second paint's first; a share over each paint after the first)
	var most := [1.0]
	for k in range(1, names.size()):
		var s: float = clampf(float(shares[k - 1]) if k - 1 < shares.size() else 0.5, 0.0, 1.0)
		for w in most.size():
			most[w] = float(most[w]) * (1.0 - s)
		most.append(s)
	var name := names[0]
	var best := -1.0
	for k in names.size():
		if float(most[k]) > best:
			best = float(most[k])
			name = names[k]
	for p in paints:
		if String((p as Dictionary)["name"]) == name:
			return String((p as Dictionary)["pot"])
	return ""


## THE ORDER THE PICTURE IS PAINTED IN (the user, 2026-11-09: "deconstructed the entire mask right from the start ... Split it into
## layers/stages"; lab/paint/layers_gen.py): the art director, shown the picture passed and the bare surface it was painted on, writes
## the layers a hand would lay it in, broad to fine, each in words a painter is told ([method _land_layers]).
func _make_layers() -> void:
	var images: Array = [{"path": episode.file_of("image:face"), "label": "THE PICTURE, finished:", "flip": false},
		{"path": episode.dir.path_join("face_bare.png"), "label": "The bare surface it was painted on:", "flip": false}]
	var surfaces := Skins.skins_of(episode.read_json("table"))
	var p := TablePrompts.face_layers(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(),
		surfaces[0] if not surfaces.is_empty() else {}, Skins.table_paints(episode.read_json("table")))
	p["images"] = images
	_submit_text("layers", p, "best")


## THE LAYERS, KEPT: `{"layers": [{name, add, soft}]}` - between [constant LAYERS_LEAST] and [constant LAYERS_MOST] of them, each named and
## said; "" written, else why not.
func _land_layers(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	var list: Variant = (d as Dictionary).get("layers", []) if d is Dictionary else []
	var out: Array = []
	for l in (list as Array) if list is Array else []:
		if l is Dictionary and not String((l as Dictionary).get("add", "")).strip_edges().is_empty():
			out.append({"name": String((l as Dictionary).get("name", "layer %d" % (out.size() + 1))).strip_edges(),
				"add": String((l as Dictionary)["add"]).strip_edges(), "soft": bool((l as Dictionary).get("soft", false))})
	if out.size() < LAYERS_LEAST or out.size() > LAYERS_MOST:
		return "the art director wrote %d layers (between %d and %d are wanted)" % [out.size(), LAYERS_LEAST, LAYERS_MOST]
	return episode.write_json("layers", {"layers": out})


## ONE LAYER PAINTED: the picture as painted so far (the bare surface, for the first layer) with layer [param k] laid on it, as it is in
## the finished picture - and nothing else.
func _make_layer(step: String, k: int, look: Dictionary, target: String) -> void:
	var list := episode.layers()
	if k < 1 or k > list.size():
		_errors[step] = "there is no layer %d in the order written" % k
		return
	var before := episode.dir.path_join("face_bare.png") if k == 1 else episode.file_of("image:layer:%d" % (k - 1))
	var l: Dictionary = list[k - 1]
	_submit_image(step, TablePrompts.layer_image(look, String(l["add"]), target, k, list.size()), [before, episode.file_of("image:face")])


## A LAYER, KEPT ONLY IF IT LIES ON THE SURFACE as the picture does ([method Skins.face_fit]); else removed, and why said.
func _land_layer(step: String) -> String:
	var painted := Image.load_from_file(episode.file_of(step))
	var bare := Image.load_from_file(episode.dir.path_join("face_bare.png"))
	if painted == null or bare == null or painted.is_empty() or bare.is_empty():
		DirAccess.remove_absolute(episode.file_of(step))
		return "the layer or the bare surface could not be read"
	var wrong := Skins.face_fit(bare, painted)
	if not wrong.is_empty():
		DirAccess.remove_absolute(episode.file_of(step))
		return "the layer did not lie on the surface: " + wrong
	return ""


## THE ART DIRECTOR looks at the face painted first before anything is copied from it ([method _land_check]): shown it and the bare surface it
## was painted on, it keeps it or sends it back with what is wrong.
func _make_face_check() -> void:
	var images: Array = [{"path": episode.file_of("image:face"), "label": "THE PAINTING to check:", "flip": false},
		{"path": episode.dir.path_join("face_bare.png"), "label": "The bare surface it was painted on:", "flip": false}]
	var surfaces := Skins.skins_of(episode.read_json("table"))
	var p := TablePrompts.face_check(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(),
		surfaces[0] if not surfaces.is_empty() else {})
	p["images"] = images
	_submit_text("check:face", p, "best")


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
			String(spec.get("byline", "")), spec.get("fixed", {}) if spec.get("fixed") is Dictionary else {})
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
	if t["set"] is ModelTools:
		return [(t["set"] as ModelTools).looks_used(), ModelTools.LOOKS]
	if t["set"] is DecoratorTools:
		return [(t["set"] as DecoratorTools).looks_used(), DecoratorTools.LOOKS]
	if t["set"] is PainterTools:
		return [(t["set"] as PainterTools).looks_used(), PainterTools.LOOKS]
	return []


## THE MODELER DESIGNS WHAT IS BUILT ([ModelTools], [AssemblyModel]; the user, 2026-11-03: "building to some kind of grand, planned vision"), told what the plan says it is and what earlier episodes built. Given a writer that takes tools, it writes shapes, is told what parts they come to, looks at them and fixes what it sees, and hands in only what holds together. One that cannot is asked for the model in one reply.
func _make_model() -> void:
	_close_tools("model")
	DirAccess.remove_absolute(episode.job_dir("model").path_join(ModelTools.SUBMITTED))
	var earlier: Array = []
	for e in TableEpisode.archive(episode.show, episode.seed):
		if not String((e as Dictionary).get("model", "")).is_empty():
			earlier.append((e as Dictionary)["model"])
	var extra := {}
	var looks := 0
	if TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		var toolset := ModelTools.new(episode.job_dir("model"))
		var url := AgentTools.open(episode.job_dir("model"), toolset)
		if not url.is_empty():
			_tools["model"] = {"url": url, "set": toolset}
			extra = {"tools_url": url}
			looks = ModelTools.LOOKS
		else:
			toolset.release()
	_submit_text("model", TablePrompts.modeler(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(), episode.seed, earlier.slice(0, 16), looks), "best", extra)


## THE DECORATOR DESIGNS WHAT IS PAINTED ([DecoratorTools], [Skins]; next/painted_surface.md), told what the plan says is painted, every
## surface the set table has to paint and what earlier episodes painted. Given a writer that takes tools, it writes elements, looks at them
## painted on the surface and fixes what it sees; one that cannot is asked for the design in one reply.
func _make_skin() -> void:
	# ...WHERE THE PICTURE WAS PAINTED AGAIN IN LAYERS, the painter at the table is the host that lays them (next/face_layers.md)
	if episode.layer_count() > 0:
		_make_skin_host()
		return
	_close_tools("skin")
	DirAccess.remove_absolute(episode.job_dir("skin").path_join(DecoratorTools.SUBMITTED))
	var surfaces := Skins.skins_of(episode.read_json("table"))
	var earlier: Array = []
	for h in TableEpisode.history(episode.show):
		var s := int((h as Dictionary)["seed"])
		if s == episode.seed or earlier.size() >= 16:
			continue
		var d: Variant = TableEpisode.open(episode.show, s).read_json("skin")
		if d is Dictionary:
			for g in (d as Dictionary).get("designs", []):
				if g is Dictionary and not String((g as Dictionary).get("name", "")).is_empty():
					earlier.append(String((g as Dictionary)["name"]))
	# ...COPYING THE FACE PAINTED FIRST, where there is one: shown it as the surface wears it, told its colors
	var face := episode.dir.path_join("face_ref.png")
	var ref := Image.load_from_file(face) if FileAccess.file_exists(face) else null
	var palette: Array = Skins.face_palette(ref) if ref != null and not ref.is_empty() else []
	# ...PAINTED AGAIN AT THE TABLE, an operation at a time, by a painter that sees each land (PainterTools; the user, 2026-11-08: "an agent in
	# the loop ... we can peak at each step, and make informed decisions about what to do next") - where there is a picture and a writer
	# that takes tools; else traced as a design, as before
	if not palette.is_empty() and TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		var tbl: Variant = episode.read_json("table")
		var painter := PainterTools.new(episode.job_dir("skin"), tbl if tbl is Dictionary else {}, _plan(), face)
		if painter.ready():
			var purl := AgentTools.open(episode.job_dir("skin"), painter)
			if not purl.is_empty():
				_tools["skin"] = {"url": purl, "set": painter}
				var pp := TablePrompts.painting(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(), painter.beats(),
					PainterTools.BUDGET, PainterTools.LOOKS)
				pp["images"] = [{"path": face, "label": "THE PICTURE TO PAINT AGAIN, the surface straight from its front (%d pixels a millimeter, its top-left corner at x 0, y 0):" % int(Skins.FACE_PX), "flip": false}]
				_submit_text("skin", pp, "best", {"tools_url": purl})
				return
		painter.release()
	var extra := {}
	var looks := 0
	if TextGen.make(String(spec.get("writer", "claude"))).takes_tools():
		var toolset := DecoratorTools.new(episode.job_dir("skin"), surfaces)
		toolset.reference = face if not palette.is_empty() else ""
		var url := AgentTools.open(episode.job_dir("skin"), toolset)
		if not url.is_empty():
			_tools["skin"] = {"url": url, "set": toolset}
			extra = {"tools_url": url}
			looks = DecoratorTools.LOOKS
		else:
			toolset.release()
	var p := TablePrompts.decorator(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(), episode.seed, surfaces, earlier, looks, palette)
	if not palette.is_empty():
		p["images"] = [{"path": face, "label": "THE PAINTING TO COPY, the surface straight from its front (%d pixels a millimeter, its top-left corner at x 0, y 0):" % int(Skins.FACE_PX), "flip": false}]
	_submit_text("skin", p, "best", extra)


## WHAT THE DECORATOR HANDED IN ([param text]: `{"designs": [...]}`, or one design for the table's first surface) made safe on the
## surfaces the table has, and kept as `skin.json` - each design with where it goes, its frame and its outline.
func _land_skin(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the design was not JSON"
	var surfaces := Skins.skins_of(episode.read_json("table"))
	if surfaces.is_empty():
		return "the table has no surface to paint (no part with `skin`)"
	var list: Array = (d as Dictionary)["designs"] if (d as Dictionary).get("designs") is Array else [d]
	var out: Array = []
	for g in list:
		if not (g is Dictionary):
			continue
		var gd: Dictionary = g
		var on := "%s/%s" % [gd.get("thing", ""), gd.get("part", "")]
		var skin: Dictionary = surfaces[0]
		for sf in surfaces:
			if on.to_lower() == ("%s/%s" % [(sf as Dictionary)["thing"], (sf as Dictionary)["part"]]).to_lower() or String(gd.get("thing", "")).to_lower() == String((sf as Dictionary)["thing"]).to_lower():
				skin = sf
		var made := Skins.sanitize(gd, skin["frame"], String(skin.get("outline", "")))
		if (made["elements"] as Array).is_empty():
			continue
		out.append({"thing": skin["thing"], "part": skin["part"], "frame": [(skin["frame"] as Vector2).x, (skin["frame"] as Vector2).y],
			"outline": skin["outline"], "name": made["name"], "elements": gd.get("elements", [])})
	if out.is_empty():
		return "the design has no element that can be painted"
	return episode.write_json("skin", {"designs": out})


## THE PUPPETEER blocks the episode's work ([PuppeteerTools], next/table_work.md): told the plan's work beat
## by beat, the cards as they were drawn (the work is made of them) and what on the set table can be worked -
## and, given a writer that takes tools, writing acts, told what each does, watching them and handing them in.
## One that cannot is asked for the acts in one reply.
func _make_acts() -> void:
	_close_tools("acts")
	DirAccess.remove_absolute(episode.job_dir("acts").path_join(PuppeteerTools.SUBMITTED))
	var painted := _acts_from_painting()
	if painted != NOT_PAINTED:
		_finish("acts", painted)
		return
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


## What [method _acts_from_painting] says of a design no painter laid.
const NOT_PAINTED := "-"


## THE ACTS A PAINTER'S PAINTING MAKES (PainterTools; the user, 2026-11-08: "I would expect acts to be more fluid ... you still wouldn't
## really restrict those acts to a single tool: you would restrict tools to the necessary job"): its operations beat by beat in the order
## they were laid, each run of them with one tool and one way of laying an act - the hand putting one tool down and taking up the next as the
## work asks, the beat's passage spoken over all of them - each told what its operations took ([method Skins.act_natural]). Written as
## `acts.json`: "" done, else what was wrong; [constant NOT_PAINTED] for a design no painter laid (the puppeteer blocks it).
func _acts_from_painting() -> String:
	var got := acts_from_painting(episode.read_json("skin"), episode.read_json("table"), episode.beat_count())
	if got.is_empty():
		return NOT_PAINTED
	if (got["acts"] as Array).is_empty():
		return "the painting has no operation in any beat"
	return episode.write_json("acts", got)


## [method _acts_from_painting]'s acts, from the design [param doc] (`skin.json`) and table [param tbl] of an episode of [param beats]
## beats: `{acts: [...]}`, or empty for a design no painter laid.
static func acts_from_painting(doc: Variant, tbl: Variant, beats: int) -> Dictionary:
	if not (doc is Dictionary) or not (tbl is Dictionary):
		return {}
	var design: Dictionary = {}
	for g in (doc as Dictionary).get("designs", []):
		if g is Dictionary:
			design = g
			break
	var els: Array = design.get("elements", [])
	if els.is_empty() or not els.all(func(e: Variant) -> bool: return e is Dictionary and (e as Dictionary).get("plan") is Dictionary):
		return {}
	var on := String(design.get("thing", ""))
	var safe := Props.sanitize(tbl as Dictionary, [])
	var water := _clearest_liquid(safe)
	var towel := _towel(safe)
	var keys: Array = ["intro"]
	for k in range(1, beats + 1):
		keys.append(str(k))
	keys.append("close")
	var acts: Array = []
	for key in keys:
		var run: Array = []
		var run_of := ""
		var k := [0]           # (a lambda keeps a number as it was: counted in a list)
		var flush := func() -> void:
			if run.is_empty():
				return
			k[0] += 1
			var pl: Dictionary = (run[0] as Dictionary)["plan"]
			var how := String(pl["how"])
			var paints: PackedStringArray = []
			var layers: Array = []        # ...and the layers it lays, by the names they keep through a repaint (layers.json)
			for e in run:
				var pot := String(((e as Dictionary)["plan"] as Dictionary).get("pot", ""))
				if not pot.is_empty() and not paints.has(pot):
					paints.append(pot)
				var layer := Manuscript.slug(String((e as Dictionary).get("stage", "")))
				if not layer.is_empty() and not layers.has(layer):
					layers.append(layer)
			var track := {"thing": String(pl["thing"]), "part": String(pl["part"]), "law": "paint", "on": on,
				"paint": run.map(func(e: Dictionary) -> String: return String(e["id"])), "manner": String(Skins.PAINTER_HOWS.get(how, "pat"))}
			if not water.is_empty():
				track["rinse"] = water
			if not towel.is_empty():
				track["dry"] = towel
			acts.append({"name": "%s %d %s" % ["intro" if key == "intro" else ("close" if key == "close" else "stage " + String(key)), k[0], String(pl["part"])],
				"beat": key if key in ["intro", "close"] else int(key), "about": "%s with the %s: %s" % [how, String(pl["part"]), ", ".join(paints)],
				"length": "under", "cues": [], "tracks": [track], "layers": layers})
			run.clear()
		for e in els:
			var pl: Dictionary = (e as Dictionary)["plan"]
			if String(pl.get("beat", "")) != String(key):
				continue
			var of := "%s/%s/%s" % [pl["thing"], pl["part"], pl["how"]]
			if of != run_of:
				flush.call()
				run_of = of
			run.append(e)
		flush.call()
	return {"acts": acts.slice(0, Motions.MAX_ACTS)}


## The clearest liquid on table [param safe] (made safe): where a brush is rinsed; "" none.
static func _clearest_liquid(safe: Dictionary) -> String:
	var mats: Dictionary = safe.get("materials", {})
	var best := ""
	var clear := -1.0
	for t in safe.get("things", []):
		for pd in PainterTools._leaf_parts((t as Dictionary)["parts"]):
			var m: Dictionary = mats.get(String((pd as Dictionary).get("material", "")), {})
			if String(m.get("kind", "")) == "liquid" and float(m.get("clarity", 0.0)) > clear:
				clear = float(m.get("clarity", 0.0))
				best = String((t as Dictionary)["name"])
	return best


## A thing on table [param safe] all of cloth that nothing is taken from: where a tool is dried; "" none.
static func _towel(safe: Dictionary) -> String:
	var mats: Dictionary = safe.get("materials", {})
	for t in safe.get("things", []):
		var leaves := PainterTools._leaf_parts((t as Dictionary)["parts"])
		var cloth := not leaves.is_empty()
		for pd in leaves:
			if String((mats.get(String((pd as Dictionary).get("material", "")), {}) as Dictionary).get("kind", "")) != "fabric" or (pd as Dictionary).has("work"):
				cloth = false
		if cloth:
			return String((t as Dictionary)["name"])
	return ""


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
	if episode.wants_game():
		_make_scene(who)
		return
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
			# ...a written card has none: its writing is its face
			if episode.written_card(k):
				continue
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
		_voices(), remark, link, misses, _acts_of(_beat_of("say:" + who, episode.cardless())), _said_word())
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
	var acts: Array = Motions.of_beat(Motions.sanitize_acts(episode.read_json("acts"), episode.beat_count())["acts"], beat)
	# ...WHAT IS PAINTED TAKES WHAT ITS STROKES TAKE ([Skins]): a reader is told it, and its words leave room for it
	if episode.has("skin"):
		var doc: Variant = episode.read_json("skin")
		var all_acts: Variant = episode.read_json("acts")
		var folded := Skins.folded_coats((all_acts as Dictionary).get("acts", []) if all_acts is Dictionary else [], doc if doc is Dictionary else {})
		for a in acts:
			var natural := Skins.act_natural(a as Dictionary, doc if doc is Dictionary else {}, episode.read_json("table"),
				FileAccess.file_exists(episode.dir.path_join("face_ref.png")), folded)
			if natural > 0.0:
				(a as Dictionary)["_natural"] = natural
				(a as Dictionary)["length"] = natural
	return acts


## THE SCRIPT EDITED WHOLE, WRITTEN BACK TO ITS PASSAGES (next/editing.md, design point 3): [param text] split where its marks
## are ([method CardReading.split]) and each passage's words written to its step - a hand's version, kept ([method
## TableEpisode.set_kept]) - then the script put together from them again, so neither is ever made over the other. ITS MARKS
## ARE THE SHOW'S: the same moves in the same order ([method choreography]); only the words between them are the hand's. A
## game's script is its play, as it was played. "" written, else why not (and nothing written).
func write_script(text: String) -> String:
	if episode.wants_game():
		return "a game's script is its play, written as it was played"
	var moves := choreography(_plan(), _drawn(episode.card_count()))
	var parts := CardReading.split(text)
	if not String((parts[0] as Dictionary)["text"]).is_empty():
		return "the script has words before its first mark, where no passage is"
	var marked: Array = parts.slice(1)
	if marked.size() != moves.size():
		return "the script has %d marks where the show has %d moves: edit the words between them, and leave the marks as they are" % [marked.size(), moves.size()]
	var writes := {}
	for i in moves.size():
		var mv: Dictionary = moves[i]
		var p: Dictionary = marked[i]
		if String(p["kind"]) != String(mv["kind"]) or int(p["card"]) != int(mv.get("card", 0)):
			return "mark %d is \"%s %d\" where the show has \"%s %d\": the marks are the show's moves" % [i + 1, String(p["kind"]), int(p["card"]), String(mv["kind"]), int(mv.get("card", 0))]
		var say := String(mv.get("say", ""))
		if say.is_empty():
			if not String(p["text"]).is_empty():
				return "the words after mark %d (%s) have no passage to go in: that move has none" % [i + 1, String(mv["kind"])]
			continue
		if episode.read_text(say).strip_edges() != String(p["text"]):
			writes[say] = String(p["text"])
	for say in writes:
		var err := episode.write_text(String(say), String(writes[say]))
		if err.is_empty():
			err = episode.set_kept(String(say), true)
		if not err.is_empty():
			return err
	return _make_script() if not writes.is_empty() else ""


func _make_script() -> String:
	if episode.wants_game():
		var wrong := _write_game()
		if not wrong.is_empty():
			return wrong
	var n := episode.card_count()
	var passages: Array = []
	for m in choreography(_plan(), _drawn(n)):
		var mv: Dictionary = m
		var text := episode.read_text(String(mv["say"])) if not String(mv.get("say", "")).is_empty() else ""
		# (A STRETCH THE GAME ENDED BEFORE was never played: no mark, no chapter)
		if episode.wants_game() and text.is_empty() and String(mv["kind"]) == "work":
			continue
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
		match String(step.split(":")[0]):
			"acts":
				err = _land_acts(handed)
			"model":
				err = _land_model(handed)
			"skin":
				err = _land_skin(handed)
			"prep":
				err = _land_prep(handed)
			"say":
				err = _land_scene(step, handed)
			_:
				err = _land_table(handed)
	elif episode.wants_game() and (step == "prep" or step.begins_with("say:")):
		err = String(res.get("error", "")) if not bool(res.get("ok", false)) else "it stopped without handing its work in"
	elif not bool(res.get("ok", false)):
		err = String(res.get("error", "the job failed"))
	else:
		match String(step.split(":")[0]):
			"plan":
				err = _land_plan(String(res.get("text", "")))
			"design":
				err = _land_design(step, String(res.get("text", "")))
			"layers":
				err = _land_layers(String(res.get("text", "")))
			"check":
				err = _land_check(step, String(res.get("text", "")))
			"say":
				# ...keeping the act cues its own beat's acts may be started by ([CardReading], `<!-- act: name -->`)
				var beat_acts := _acts_of(_beat_of(step, episode.cardless()))
				var cues: Array = beat_acts.map(func(a: Dictionary) -> String: return String(a["name"]))
				var t := own_voices(clean_spoken(String(res.get("text", "")), cues), _voices(), _reader_name())
				t = fit_silence(t, beat_acts, _said_word())
				err = "the reader wrote nothing speakable" if t.split(" ", false).size() < (1 if step.split(":")[1].is_valid_int() else 20) \
					else episode.write_text(step, t)
			"image":
				err = "" if episode.has(step) else "the picture did not arrive"
				if err.is_empty() and step == "image:height":
					err = _land_height()
				if err.is_empty() and step == "image:face":
					err = _land_face()
				if err.is_empty() and step.begins_with("image:layer:"):
					err = _land_layer(step)
			"model":
				err = _land_model(String(res.get("text", "")))
				if not err.is_empty() and had_tools:
					err = "the modeler stopped without handing its model in"
			"skin":
				err = _land_skin(String(res.get("text", "")))
				if not err.is_empty() and had_tools:
					err = "the decorator stopped without handing its design in"
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
	# A PLAN OF BEATS DRAWS NO CARDS: the producer's own choice, read off the brief. A GAME IS ONE THAT HAS NONE: it plans no beats, for nobody knows what they will be (next/tabletop.md)
	if plan.get("game") == true or (plan.get("beats") is Array and not (plan.get("beats") as Array).is_empty()):
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
	for k in ["episode_title", "description", "audience", "topic", "premise", "reader_mood", "running_bit", "work_intro", "work_close", "build", "painted"]:
		plan[k] = _str(plan.get(k, ""))
	plan["episode_title"] = not_shouted(String(plan["episode_title"]))
	plan["game"] = plan.get("game") == true
	plan["table_note"] = _str(plan.get("table_note", ""))
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
	# A GAME'S SCENES ARE A CEILING, AND NOTHING MORE (next/tabletop.md): nobody knows what they will turn out to be, and a chapter is named as it is played
	if plan.get("game") == true:
		raw = []
		for k in clampi(int(plan.get("scenes", 6)), 1, BEATS_MOST):
			raw.append({"name": "Part %d" % (k + 1), "asks": ""})
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
	for k in ["episode_title", "description", "audience", "topic", "premise", "reader_mood", "running_bit", "work_intro", "work_close", "build", "painted"]:
		plan[k] = _str(plan.get(k, ""))
	plan["episode_title"] = not_shouted(String(plan["episode_title"]))
	plan["game"] = plan.get("game") == true
	plan["table_note"] = _str(plan.get("table_note", ""))
	plan["beat_word"] = "Part" if plan["game"] else beat_word_of(plan.get("beat_word", ""))
	# WHAT THE EPISODE IS MADE OF: built from many small parts ([Assembly]) or not, and how much of it nobody talks through
	plan["assembly"] = plan.get("assembly") == true
	plan["quiet"] = TablePrompts.quiet_of(plan)
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


## THE ART DIRECTOR'S WORD on a card's painting ([param step] `check:K`; or `check:face`, the face painted first's): kept, or SENT BACK - its
## faults added to [method TableEpisode.send_back] for the painter of the next, and the painting deleted
## with what was made from it, so the producer paints it again and looks again - while it has been sent
## back fewer than [constant REPAINTS] times. Past that the last painting stands, and its faults are
## written into the check for the reader ([method say_prompt]).
func _land_check(step: String, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary) or not (String((d as Dictionary).get("verdict", "")) in ["keep", "repaint"]):
		return "the art director's reply was not a verdict"
	var who := step.split(":")[1]
	var k: Variant = int(who) if who.is_valid_int() else who
	var painting := "image:card:%d" % k if who.is_valid_int() else "image:%s" % who
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
	episode.invalidate(painting, true)
	# a new painting, and a new look at it: neither is a retry of a failed job
	_tries.erase(step)
	_tries.erase(painting)
	return ""


func _land_design(step: String, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	var k := int(step.get_slice(":", 1))
	# A WRITTEN CARD'S WRITING ([constant CardTable.FRAMES] `written`): its title and its lines, kept as written -
	# and as its entry's text, a line to each, for every reader and the work that read a card's entry. It has no picture.
	if d is Dictionary and CardTable.written(CardTable.look_of(_look(), _card(k))):
		var w: Variant = (d as Dictionary).get("writing", {})
		var lines := DataPath.strings((w as Dictionary).get("lines", [])) if w is Dictionary else PackedStringArray()
		if lines.is_empty():
			return "the design has no writing: a written card needs its `writing`, a title and its lines"
		var writing := {"title": _str((w as Dictionary).get("title", "")), "lines": Array(lines.slice(0, WRITING_MOST))}
		if String(writing["title"]).is_empty():
			writing["title"] = String(_card(k).get("name", ""))
		return episode.write_json(step, {"writing": writing, "booklet": {"keywords": [], "upright": "\n".join(PackedStringArray(writing["lines"]))}})
	if not (d is Dictionary) or _str((d as Dictionary).get("art", "")).is_empty():
		return "the design was not JSON with an illustration"
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
	# ...AND THE MODEL STANDS BY THE END, whatever was written ([method Assembly.with_finish])
	if episode.wants_model():
		d = Assembly.with_finish(d as Dictionary, episode.model())
	return episode.write_json("acts", d)


## THE MODEL, as handed in by [ModelTools] (already made: `{raw, made}`), or as written in one reply and made here. Kept with its parts, so nothing need work them out again - if it comes to something.
func _land_model(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the model was not JSON"
	var raw: Variant = (d as Dictionary).get("raw", d)
	var made: Dictionary = (d as Dictionary)["made"] if (d as Dictionary).get("made") is Dictionary else ModelTools.safe(AssemblyModel.make(raw))
	if (made.get("parts", []) as Array).is_empty():
		return "the model came to no parts: %s" % "; ".join(PackedStringArray(made.get("notes", [])))
	return episode.write_json("model", {"raw": raw, "made": made})


## THE TABLE, kept as the set dresser wrote it - it is made safe each time it is built
## ([method CardTable.sanitize_table]), so an edit by hand is read the same way - if anything in
## it can be built.
func _land_table(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the table was not JSON"
	# ...THE SHOW'S FIXED THINGS STAND IN IT AS THE BRIEF WRITES THEM, whatever was handed in ([FixedTable])
	d = FixedTable.merge(d as Dictionary, spec.get("fixed", {}) if spec.get("fixed") is Dictionary else {})
	if (CardTable.sanitize_table(d as Dictionary, _look())["things"] as Array).is_empty():
		return "nothing on the table could be built"
	# ...WHAT IS BUILT ON IT GOES WITH IT: every table anywhere is stood from this one file
	var designed := episode.model()
	if not designed.is_empty():
		if not ((d as Dictionary).get("assembly") is Dictionary):
			(d as Dictionary)["assembly"] = {}
		((d as Dictionary)["assembly"] as Dictionary)["model"] = designed
	return episode.write_json("table", d)


## A TITLE IS NEVER SHOUTED (the user, 2026-11-09: "the title of this episode is in ALL CAPS. We probably shouldn't allow for that, as a
## rule"): one written with no small letter at all is set in sentence case - its first letter a capital, the rest small, "I" itself (a
## brief had asked for "capitals", 732687's "THEY CALLED IT DRIFTING BECAUSE THEY COULDN'T SEE WHERE YOU WERE GOING"). Never a capital on
## every word (2026-10-11, of one that had them): title case's small words want a list of words, and the writer is asked for title case
## itself. One with any small letter is the writer's own casing, kept: an acronym in a title as written stays.
static func not_shouted(title: String) -> String:
	var letters := 0
	for i in title.length():
		var c := title.substr(i, 1)
		if c.to_lower() != c.to_upper():
			letters += 1
			if c == c.to_lower():
				return title
	if letters < 4:
		return title
	var words := title.to_lower().split(" ")
	for i in words.size():
		var w := String(words[i])
		if w == "i" or w.begins_with("i'"):
			words[i] = "I" + w.substr(1)
	var out := " ".join(words)
	for i in out.length():
		var c := out.substr(i, 1)
		if c.to_lower() != c.to_upper():
			return out.substr(0, i) + c.to_upper() + out.substr(i + 1)
	return out


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


## How long a word takes the show's reader to say ([method ReadingCast.said_word], handed in the spec): what passages are written to.
func _said_word() -> float:
	return float(spec.get("said_word", TablePrompts.SAID_WORD))


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
## a cue naming any other is dropped as any mark is. A CHAPTER the reader names (`<!-- chapter: name -->`)
## stays, its name one line: the export times it from the take ([method CardReading.chapters]).
static func voice_marks_only(text: String, acts: Array = []) -> String:
	var keep := [Manuscript._rx(Manuscript.DELIVERY), Manuscript._rx(Manuscript.HESITATION),
		Manuscript._rx(Manuscript.SPEAKER), Manuscript._rx(CardReading.QUIET_MARK)]
	var cue := Manuscript._rx(CardReading.ACT_MARK)
	var chapter := Manuscript._rx(CardReading.CHAPTER_MARK)
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
		var part := chapter.search(c)
		if part != null:
			var title := " ".join(part.get_string(1).split("\n", false)).strip_edges()
			if not title.is_empty():
				out += "<!-- chapter: %s -->" % title
			continue
		if keep.any(func(r: RegEx) -> bool: return r.search(c) != null):
			out += c
	return out + text.substr(at)


## WHAT THE WORK TAKES, THE VOICE LEAVES ROOM FOR ([Assembly]; a reader is told how long its acts take, and words are only ever about
## that long): a passage whose words and silences come to less than the least its acts can be hurried to has the difference added as
## a silence before its last sentence - so the work never runs on past the talk, and the talk is never quickened. It adds nothing to
## a passage whose acts have no such floor, or that gives them room.
static func fit_silence(text: String, acts: Array, said_word := TablePrompts.SAID_WORD) -> String:
	var least := 0.0
	for a in acts:
		least += float((a as Dictionary).get("_natural", 0.0)) * SILENCE_FITS
	if least <= 0.0:
		return text
	var words := Manuscript._rx(Manuscript.COMMENT).sub(text, "", true).split(" ", false).size()
	var quiet := 0.0
	for m in Manuscript._rx(CardReading.QUIET_MARK).search_all(text):
		quiet += float(m.get_string(1))
	var short := least - float(words) * said_word - quiet
	if short < SILENCE_LEAST:
		return text
	short = minf(short, CardReading.QUIET_MOST)
	var mark := "<!-- quiet: %d --> " % roundi(short)
	# ...before its last sentence, its last words left for after it
	var at := -1
	for rx in [". ", "? ", "! "]:
		at = maxi(at, text.rstrip(" \n").rfind(rx))
	if at < 0:
		return mark + text
	return text.substr(0, at + 2) + mark + text.substr(at + 2)


## How much of what its acts take at an easy pace a passage must cover, and the least it is worth saying a silence for (seconds).
const SILENCE_FITS := 0.9
const SILENCE_LEAST := 6.0


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

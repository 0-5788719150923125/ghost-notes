extends RefCounted
class_name CardProducer

## CardProducer - makes whatever an episode is missing, in the order a reading happens.
##
## THE LOOP. Every [method tick] looks at the episode's steps (see [CardEpisode]) and starts
## each one whose inputs exist and whose own file does not; when a job ends, its output is
## checked and written into the episode, which is what lets the steps after it start. So the
## order is not a script anywhere - it falls out of what each step is made from:
##
##   plan       the producer plans the episode: title, angle, spread, the deck's whole look
##   draw       the deck is shuffled and cut (here, from the seed - no agent touches it)
##   design:K   the deck's creator draws up card K: its illustration and its booklet entry
##   image:*    the painter makes the back, the cloth, the room, then each card in turn
##   table      the set dresser sets the reader's table, looking at the cloth - and, given a writer
##              that takes tools, looking at what it builds as it builds it ([SetDresserTools])
##   say:intro  the reader opens the video, shuffling, knowing no card
##   say:K      the reader turns over card K - knowing cards 1..K and what it said before, and
##              LOOKING AT card K's painting, so the words are about the picture on screen
##   say:close  the reader closes, with the whole spread on the table
##   script     the passages and the marks between them, ready for the voice
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
## How much of the deck goes into a card's references: the back, the first card (which set the
## hand) and the most recent - the [Illustrations] chain, for the same reason: more attachments
## make a painter worse at matching, not better.
const CHAIN_MAX := 2
## The chance the first card is a jumper, when the show allows them.
const JUMPER_CHANCE := 0.3
## The steps made here, with no agent and no quota - see the class note.
const LOCAL := ["draw", "script"]

var episode: CardEpisode
## {title, brief, cards: [lo, hi], reversals, jumpers, writer, painter}
var spec: Dictionary = {}
var running := false
## The steps this run was asked for; empty for the whole episode.
var only: Array = []

var _jobs := {}        # step -> AgentJobs id
var _tools := {}       # step -> {url, set}: the tools a step's agent is working with, until it lands
var _errors := {}      # step -> why it failed, once it is out of tries
var _tries := {}       # step -> runs started


func _init(ep: CardEpisode, sp: Dictionary) -> void:
	episode = ep
	spec = sp


## How many cards this episode draws: from its seed, within the show's range. Decided before
## anything is planned, so the producer plans a spread of exactly that many.
static func spread_size(seed: int, lo: int, hi: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-spread"])
	return rng.randi_range(mini(lo, hi), maxi(lo, hi))


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
		"image":
			_make_image(step)
		"say":
			_make_say(String(parts[1]))
		"script":
			_finish(step, _make_script())
		"table":
			_make_table()


## [param extra]: more of the job's spec - its tools and their timeout (see [method _make_table]).
func _submit_text(step: String, p: Dictionary, tier: String, extra: Dictionary = {}) -> void:
	_tries[step] = int(_tries.get(step, 0)) + 1
	if not p.has("system") or not p.has("prompt"):
		_errors[step] = "its prompt could not be built (see the log)"
		_close_tools(step)
		return
	var job := {"kind": "text", "backend": String(spec.get("writer", "claude")),
		"tier": tier, "dir": episode.job_dir(step), "system": String(p["system"]),
		"prompt": String(p["prompt"]), "images": p.get("images", []), "label": "cards %s" % step,
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
		"target": episode.file_of(step), "label": "cards %s" % step,
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


func _cards_range() -> Array:
	var c: Variant = spec.get("draw", [3, 6])
	if c is Array and (c as Array).size() == 2:
		return [clampi(int(c[0]), 1, 10), clampi(int(c[1]), 1, 10)]
	return [3, 6]


## The deck the show reads with (see [CardDeck]): the one its brief lists, handed over in the spec -
## or, when the producer chooses it (`chooses`, [method CardDeck.chooses]), the one in this episode's
## plan, and none before the plan is made. No deck is built in.
func _deck() -> Array:
	var d: Variant = _plan().get("deck", []) if bool(spec.get("chooses", false)) else spec.get("deck", [])
	return d if d is Array else []


## How many cards this episode draws: the seed's pick in the show's range, never more than the
## deck holds.
func _spread_n() -> int:
	var r := _cards_range()
	var n := spread_size(episode.seed, int(r[0]), int(r[1]))
	# a deck the producer chooses is made for the spread, at least twice its size (CardPrompts.box_range)
	return n if bool(spec.get("chooses", false)) else mini(n, _deck().size())


func _make_plan() -> void:
	var n := _spread_n()
	var p := CardPrompts.producer(String(spec.get("title", "")), String(spec.get("brief", "")),
		episode.seed, n, bool(spec.get("reversals", true)), CardTable.FACES,
		CardTable.FRAMES, CardEpisode.archive(episode.show, episode.seed), _deck(), bool(spec.get("chooses", false)))
	_submit_text("plan", p, "best")


## The shuffle and the cut, from the seed alone.
func _make_draw() -> String:
	var plan := _plan()
	var n := ((plan.get("spread", {}) as Dictionary).get("positions", []) as Array).size()
	if n <= 0:
		return "the plan has no spread"
	# the show's own deck, shuffled from the seed - and each card WRITTEN INTO the draw, so the
	# episode keeps the cards it drew whatever the show's deck becomes later
	var deck := CardDeck.shuffled(_deck(), episode.seed, bool(spec.get("reversals", true)))
	if deck.size() < n:
		return "the deck has %d cards and this spread needs %d (the plan was made for a bigger deck: New episode)" \
			% [deck.size(), n]
	var jumper := jumps(episode.seed, bool(spec.get("jumpers", true)), plan)
	var cards: Array = []
	for i in n:
		var c: Dictionary = (deck[i] as Dictionary).duplicate()
		c["jumper"] = jumper and i == 0
		cards.append(c)
	return episode.write_json("draw", {"seed": episode.seed, "cards": cards})


## WHETHER A CARD JUMPS in episode [param seed] - a show that [param allowed] them, staged by [param plan] -
## from the seed alone: how the reading goes, never which card. A JUMPER flies out of a shuffle: never
## out of a box, and never into a card not drawn by hand.
static func jumps(seed: int, allowed: bool, plan: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "tarot-jumper"])
	var jumper := allowed and rng.randf() < JUMPER_CHANCE
	var staging := CardTable.staging_of(plan)
	var listed: Array = ((plan.get("spread", {}) as Dictionary).get("positions", []) as Array) if plan.get("spread") is Dictionary else []
	var first_pos: Variant = listed[0] if not listed.is_empty() else {}
	if not bool((TableActions.SOURCES[staging["source"]] as Dictionary)["jumpers"]) \
			or (first_pos is Dictionary and String((first_pos as Dictionary).get("comes", "drawn")) != "drawn"):
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
	card["jumper"] = bool(card.get("jumper", false))
	var design: Variant = episode.read_json("design:%d" % k)
	if design is Dictionary:
		card["booklet"] = (design as Dictionary).get("booklet", {})
		card["art"] = String((design as Dictionary).get("art", ""))
	return card


## THE CARDS THE READER MAY KNOW at a step: those turned over so far - 1..k for card k, none for
## the intro, all of them for the close. The only way a card reaches a reader prompt.
func _drawn(upto: int) -> Array:
	var out: Array = []
	for k in range(1, upto + 1):
		out.append(_card(k))
	return out


func _make_design(k: int) -> void:
	var card := _card(k)
	var p := CardPrompts.designer(String(spec.get("title", "")), String(spec.get("brief", "")),
		CardTable.look_of(_look(), card), card, bool(spec.get("reversals", true)), CardEpisode.archive(episode.show, episode.seed),
		String(CardTable.staging_of(_plan())["text"]))
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
		_submit_image(step, CardPrompts.card_image(CardTable.look_of(look, _card(k)), _card(k), art, target, has_back,
			chain.size()), refs)
		return
	if parts.size() == 3 and String(parts[1]) == "back":
		# a printing's own back: the card of that printing stands for it in the look
		var name := ""
		for k in range(1, episode.card_count() + 1):
			if episode.printing_of(k) == String(parts[2]):
				name = CardTable.series_of(look, _card(k))
				break
		_submit_image(step, CardPrompts.back_image(CardTable.look_of(look, {"series": name}), target,
			bool(spec.get("reversals", true)), printed), [])
		return
	match String(parts[1]):
		"back":
			_submit_image(step, CardPrompts.back_image(look, target, bool(spec.get("reversals", true)), printed), [])
		"surface":
			_submit_image(step, CardPrompts.surface_image(look, target), [])
		"height":
			# the painting's depth, redrawn FROM the painting - an edit of it, checked as it lands
			_submit_image(step, CardPrompts.height_image(look, target), [episode.file_of("image:surface")])
		"backdrop":
			# THE VIEW IT IS ASKED FOR, kept beside it: the table projects a level picture from the
			# camera's eye, and keeps a picture made before (none beside it) as it always stood
			var view := episode.dir.path_join("backdrop.json")
			var f := FileAccess.open(view + ".part", FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"view": "level", "lens_mm": CardTable.BACKDROP_LENS}))
				f.close()
				DirAccess.rename_absolute(view + ".part", view)
			_submit_image(step, CardPrompts.backdrop_image(look, target), [])


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
	for e in CardEpisode.archive(episode.show, episode.seed):
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
	var p := CardPrompts.set_dresser(String(spec.get("title", "")), String(spec.get("brief", "")), _plan(),
		episode.seed, CardTable.headroom(episode.seed), seen.slice(0, 40), cloth,
		SetDresserTools.LOOKS if not extra.is_empty() else 0, airs.slice(0, 24), String(spec.get("byline", "")),
		tables.slice(0, 10), lights.slice(0, 10), room, jumps(episode.seed, bool(spec.get("jumpers", true)), _plan()))
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
func table_looks() -> int:
	var t: Dictionary = _tools.get("table", {})
	return (t["set"] as SetDresserTools).looks_used() if not t.is_empty() else -1


## A step's tools stop answering, and what they built is given back.
func _close_tools(step: String) -> void:
	var t: Dictionary = _tools.get(step, {})
	if t.is_empty():
		return
	AgentTools.close(String(t["url"]))
	(t["set"] as SetDresserTools).release()
	_tools.erase(step)


## WHAT AN AGENT HANDED IN WITH A TOOL for [param step] (its job's `submitted.json`), or "" - an
## answer that does not depend on its last words, or on its run ending cleanly.
func _handed_in(step: String) -> String:
	var path := episode.job_dir(step).path_join(SetDresserTools.SUBMITTED)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _make_say(who: String) -> void:
	_submit_text("say:" + who, say_prompt(who), "best")


## THE READER'S PROMPT for passage [param who] ("intro", "1".."N", "close"): the passages before it
## and [method _drawn] up to its card - nothing else reaches it - and `images`, the PAINTINGS it
## talks about: card K's own for card K when K is one it may stop on ([method CardPrompts.remarks]),
## every card's for the close, none for the intro. A
## reversed card is sent upside down, as the viewer sees it. Public so the gate can hold the
## producer itself, not only the prompt builder, to all of that.
func say_prompt(who: String) -> Dictionary:
	var n := episode.card_count()
	var said: Array = []
	var drawn: Array = []
	if who == "intro":
		pass
	elif who == "close":
		said = _said(n)
		drawn = _drawn(n)
	else:
		var k := int(who)
		said = _said(k - 1)
		# THE CARDS ON THE TABLE by now: up to this one - or, swept out in a waterfall, up to its last
		drawn = _drawn(episode.reveal_of(k))
	# THE PAINTINGS go with a passage only where the reader may stop on one ([method CardPrompts.remarks]):
	# a card left out reaches it by name and meaning alone
	var remark := true
	if who != "intro" and who != "close":
		var shares := CardPrompts.remarks(episode.seed, n)
		remark = int(who) - 1 < shares.size() and bool(shares[int(who) - 1])
	var images: Array = []
	if who != "intro" and remark:
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
	var p := CardPrompts.reader(String(spec.get("title", "")), String(spec.get("brief", "")),
		_plan(), who, said, drawn, n, not images.is_empty(), CardEpisode.archive(episode.show, episode.seed), names,
		_voices(), remark)
	p["images"] = images
	return p


## The intro and the passages for cards 1..upto, in order.
func _said(upto: int) -> Array:
	var out := [episode.read_text("say:intro")]
	for k in range(1, upto + 1):
		out.append(episode.read_text("say:%d" % k))
	return out


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
## position makes after its passage (`then`: tap, untap); the spread and the close.
static func choreography(plan: Dictionary, cards: Array) -> Array:
	var staging := CardTable.staging_of(plan)
	var pos: Array = ((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array if plan.get("spread") is Dictionary else []
	var out: Array = [{"kind": String((TableActions.SOURCES[staging["source"]] as Dictionary)["opens"]), "card": 0, "say": "say:intro"}]
	var n := cards.size()
	var k := 1
	var at := func(i: int) -> Dictionary: return pos[i - 1] if i >= 1 and i <= pos.size() and pos[i - 1] is Dictionary else {}
	while k <= n:
		var p: Dictionary = at.call(k)
		var comes := String(p.get("comes", "drawn"))
		if comes == "swept":
			var last := k
			while last < n and String((at.call(last + 1) as Dictionary).get("comes", "")) == "swept":
				last += 1
			out.append({"kind": "fan", "card": k, "last": last, "say": ""})
			for j in range(k, last + 1):
				out.append({"kind": "show", "card": j, "say": "say:%d" % j})
				out.append_array(_then_moves(at.call(j), j))
			k = last + 1
			continue
		var kind := "deal" if comes == "dealt" else ("jumper" if bool((cards[k - 1] as Dictionary).get("jumper", false)) else "draw")
		out.append({"kind": kind, "card": k, "say": "say:%d" % k})
		out.append_array(_then_moves(p, k))
		k += 1
	out.append({"kind": "spread", "card": 0, "say": "say:close"})
	return out


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
		err = _land_table(handed)
	elif not bool(res.get("ok", false)):
		err = String(res.get("error", "the job failed"))
	else:
		match String(step.split(":")[0]):
			"plan":
				err = _land_plan(String(res.get("text", "")))
			"design":
				err = _land_design(step, String(res.get("text", "")))
			"say":
				var t := own_voices(clean_spoken(String(res.get("text", ""))), _voices())
				err = "the reader wrote nothing speakable" if t.split(" ", false).size() < 20 \
					else episode.write_text(step, t)
			"image":
				err = "" if episode.has(step) else "the picture did not arrive"
				if err.is_empty() and step == "image:height":
					err = _land_height()
			"table":
				err = _land_table(String(res.get("text", "")))
				if not err.is_empty() and had_tools:
					err = "the set dresser stopped without handing its table in"
	if err.is_empty():
		_errors.erase(step)
		return
	push_warning("ghost: cards %s - %s" % [step, err])
	if int(_tries.get(step, 0)) > RETRIES:
		_errors[step] = err


## THE HEIGHT MAP, KEPT ONLY IF IT LIES UNDER THE PAINTING ([method Tables.height_fit]) - or is flat,
## which lies under anything ([constant Tables.FLAT_SPAN]): its score and shift written beside it
## (`height.json`, which the table reads), or the map removed and why.
func _land_height() -> String:
	var paint := Image.load_from_file(episode.file_of("image:surface")) if episode.has("image:surface") else null
	var h := Image.load_from_file(episode.file_of("image:height"))
	if paint == null or h == null or paint.is_empty() or h.is_empty():
		DirAccess.remove_absolute(episode.file_of("image:height"))
		return "the height map or the painting could not be read"
	var span := Tables.height_span(h)
	if span < Tables.FLAT_SPAN:
		# a surface with no relief, drawn flat as asked: it lies under anything, as it is
		print("ghost: cards image:height - flat (spans %.3f): the surface lies smooth" % span)
		return TextGen.put(episode.dir.path_join("height.json"), JSON.stringify({"score": 1.0, "shift": [0.0, 0.0], "flat": true}, "\t"))
	var fit := Tables.height_fit(paint, h)
	var score := float(fit["score"])
	print("ghost: cards image:height - lies under the painting at %.2f, shifted %s" % [score, str(fit["shift"])])
	if score < Tables.FIT_LEAST:
		DirAccess.remove_absolute(episode.file_of("image:height"))
		return "the height map did not line up with the painting (%.2f, %.2f needed): the painting's own detail stands in" % [score, Tables.FIT_LEAST]
	var shift: Vector2 = fit["shift"]
	return TextGen.put(episode.dir.path_join("height.json"), JSON.stringify({"score": score, "shift": [shift.x, shift.y]}, "\t"))


func _land_plan(text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary):
		return "the plan was not JSON"
	var plan: Dictionary = d
	var n := _spread_n()
	var spread: Dictionary = plan.get("spread", {}) if plan.get("spread") is Dictionary else {}
	# EVERY FIELD IN THE SHAPE ITS READERS EXPECT: a position given as a bare name, tags as one
	# string - a reply of the wrong shape is reshaped here, once, or it stalls the episode later
	# inside a prompt builder, where it fails with nothing on screen
	var pos: Array = []
	for q in (spread.get("positions", []) if spread.get("positions") is Array else []):
		if q is Dictionary:
			pos.append(_land_position(q as Dictionary, pos.size() + 1, n))
		elif not _str(q).is_empty():
			pos.append({"name": _str(q), "asks": ""})
	spread["name"] = _str(spread.get("name", ""))
	for k in ["episode_title", "description", "audience", "topic", "premise", "reader_mood", "running_bit"]:
		plan[k] = _str(plan.get(k, ""))
	for k in ["tags", "habits"]:
		plan[k] = Array(CardPrompts.strings(plan.get(k, [])))
	# EXACTLY the size drawn for this seed: a plan that miscounts is trimmed, or filled out
	# with the position readers reach for when they want one more card
	pos = pos.slice(0, n)
	while pos.size() < n:
		pos.append({"name": "Clarifier", "asks": "what the cards before it are really saying"})
	spread["positions"] = pos
	plan["spread"] = spread
	if not (plan.get("look") is Dictionary):
		return "the plan has no look"
	plan["look"] = CardTable.sanitize_look(plan["look"] as Dictionary)
	plan["staging"] = CardTable.staging_of(plan)
	if (plan["look"] as Dictionary).has("kind"):
		plan["look"]["kind"] = _str(plan["look"]["kind"])
	if bool(spec.get("chooses", false)):
		var box := _land_box(plan.get("deck"), n)
		if box.is_empty():
			return "the plan's deck has fewer than the %d cards the box needs" % int(CardPrompts.box_range(n)[0])
		plan["deck"] = box
	else:
		plan.erase("deck")
	plan["seed"] = episode.seed
	plan["dice"] = CardPrompts.dice(episode.seed)
	return episode.write_json("plan", plan)


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
	var then: Array = []
	for m in q.get("then", []) if q.get("then") is Array else ([q.get("then")] if q.get("then") is String else []):
		var parts := _str(m).to_lower().split(" ", false)
		if parts.size() == 2 and parts[0] in ["tap", "untap"] and parts[1].is_valid_int() and int(parts[1]) >= 1 \
				and int(parts[1]) <= mini(n, k):
			then.append("%s %d" % [parts[0], int(parts[1])])
	if not then.is_empty():
		out["then"] = then
	return out


## THE BOX A PRODUCER CHOSE, in the shape [method CardDeck.parse] gives a listed deck - `{key, name,
## numeral, group, meaning}`, keys unique - or empty when it holds fewer than the box's least
## ([method CardPrompts.box_range]): a box the size of the spread would be the producer's pick of the
## cards, not the seed's. More than the most are cut.
func _land_box(v: Variant, n: int) -> Array:
	var r := CardPrompts.box_range(n)
	var out: Array = []
	var keys := {}
	for c in v if v is Array else []:
		var d: Dictionary = c if c is Dictionary else {"name": c}
		var name := _str(d.get("name", ""))
		if name.is_empty() or out.size() >= int(r[1]):
			continue
		var key := CardEpisode.slug(name)
		var k := key
		var i := 2
		while keys.has(k):
			k = "%s-%d" % [key, i]
			i += 1
		keys[k] = true
		out.append({"key": k, "name": name, "numeral": "", "group": _str(d.get("group", "")),
			"meaning": _str(d.get("meaning", ""))})
	return out if out.size() >= int(r[0]) else []


func _land_design(step: String, text: String) -> String:
	var d: Variant = TextGen.extract_json(text)
	if not (d is Dictionary) or _str((d as Dictionary).get("art", "")).is_empty():
		return "the design was not JSON with an illustration"
	var b: Variant = (d as Dictionary).get("booklet", {})
	if not (b is Dictionary) or _str((b as Dictionary).get("upright", "")).is_empty():
		return "the design has no booklet entry"
	var booklet := {"keywords": Array(CardPrompts.strings((b as Dictionary).get("keywords", []))),
		"upright": _str((b as Dictionary).get("upright", ""))}
	if not _str((b as Dictionary).get("reversed", "")).is_empty():
		booklet["reversed"] = _str((b as Dictionary)["reversed"])
	return episode.write_json(step, {"art": _str((d as Dictionary)["art"]), "booklet": booklet})


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
## The show's voices besides the reader's ([constant Manuscript.NARRATOR]): the names its
## document gives them, in its order.
func _voices() -> Array:
	var out: Array = []
	for v in spec.get("voices", []):
		if String(v) != Manuscript.NARRATOR and not out.has(String(v)):
			out.append(String(v))
	return out


## [param text] with every change of speaker naming one of the show's own [param voices] (or the
## reader), spelled as the show spells it; a cue naming anyone else is taken out, and its words
## stay with whoever was speaking. A writer's "familiar" would otherwise be a new voice of its own,
## a copy of the reader's, kept in the show's document from then on.
## A READER WRITES WORDS AND THE VOICE'S MARKS - a delivery, a hesitation, a change of speaker - AND
## NOTHING ELSE (next/notes.md step 9: "an unknown one is dropped"): every other comment in a reply
## goes, a table mark above all. `<!-- table: draw 2 -->` in a reading's words would be parsed as an
## action when the script is composed - [method CardReading.parse] reads every own-line mark - and
## deal a card nobody drew; the table's actions are the producer's to write ([method CardReading.compose]).
static func voice_marks_only(text: String) -> String:
	var keep := [Manuscript._rx(Manuscript.DELIVERY), Manuscript._rx(Manuscript.HESITATION),
		Manuscript._rx(Manuscript.SPEAKER)]
	var out := ""
	var at := 0
	for m in Manuscript._rx(Manuscript.COMMENT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var c := m.get_string()
		if keep.any(func(r: RegEx) -> bool: return r.search(c) != null):
			out += c
	return out + text.substr(at)


static func own_voices(text: String, voices: Array) -> String:
	var known := {Manuscript.NARRATOR.to_lower(): Manuscript.NARRATOR}
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


static func clean_spoken(text: String) -> String:
	var t := voice_marks_only(text.strip_edges())
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
	t = t.replace("\u2014", " - ").replace("\u2013", " - ").replace("**", "*")
	t = Manuscript._rx("[ \\t]{2,}").sub(t, " ", true)
	t = Manuscript._rx("\\n{3,}").sub(t, "\n\n", true)
	return t.strip_edges()

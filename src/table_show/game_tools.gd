extends RefCounted
class_name GameTools

## GameTools - THE TABLE, LIVE (next/tabletop.md "Play is live"): what the game master has while it runs one scene of a game really being played. Served as tools
## ([AgentTools]), as the set dresser's are. The user, 2026-11-04: "game states that could end in both success or failure... or maybe even in complete deviation into something
## that never resolves (i.e. the last remaining player bought a boat and became a fisherman at the end)".
##
## THE SCENE IS WRITTEN BY THE CALLS, IN ORDER, and the tools write the script ([method compose]):
##
##   say       lines, in batches: who, their words, whether they come in over the last line or together with it. Said is said.
##   roll      dice thrown from where a person sits: the number comes back then, from the seed ([GameLedger], [DiceNotation]), and its mark is in the script at this point.
##   change    a field of a sheet                  move, place, fall, rise, remove   a figure on the map
##   map       another map goes down               reveal                            a picture held up
##   state     everything as it stands
##   ask       a player, asked: see below           ask_table                         all of them at once
##   end_scene this scene is done                   game_over                         the game is done, and the scenes left will not be played
##
## SO NOTHING WRITTEN CAN CONTRADICT THE DICE, which came first; no mark can be malformed; a roll cannot be hidden or thrown again until it suits, for everything rolled is on the table
## by the time the agent knows it; and everyone speaking is someone at the table. No tool takes anything back: what is said at a table is said.
##
## THE PLAYERS ARE OTHER AGENTS: [method _ask] starts a job for that person, knowing only their sheet, their own want and what has been said aloud, and hands its answer back to this
## one's call. The game master is told it may not decide what they do, only what comes of it. An author writing one story will not abandon it; a person at a table with a want of their
## own will bid on a boat at the worst moment, and a game master who must honor that has to run the boat. A gate replaces the job ([member asker]).
##
## NO GAME IS NAMED HERE: dice, fields, a board, a table of people. The rules are the brief's and the game master's.

const SUBMITTED := "submitted.json"
## A line that overlaps the one before, when it does not say by how much ([constant Manuscript.OVER]'s bare mark).
const OVER_LEAST := 0.1
const OVER_MOST := 3.0
## The most lines in one call: a scene is said in stretches, each answered with how long it has run.
const LINES_MOST := 40
## How much of what has been said a player is told, in words (the rest is long ago, and the cost of a question grows with it).
const HEARD_MOST := 1500
## How long a player has to answer, in ms: past it, they said nothing.
const ANSWER_MS := 180000

## The episode this is a scene of, the scene ("intro", "close", or a number).
var episode: TableEpisode
var step := ""
var plan := {}
var prep := {}
## Everyone at the table, the game master first. The names are the show's voices.
var people: PackedStringArray = PackedStringArray()
var ledger: GameLedger
var dir := ""
## What was said in the scenes before this one, with names ([method heard]).
var said_before := ""
## Who plays the players, and at what: `{backend, model, effort}`.
var players := {}
var seed_value := 0
## The items of the script, in order: `{who, says, over, together}`, `{mark, id}`, `{chapter}`.
var items: Array = []
var submitted := false
var game_over := false
## A GATE'S SEAM: answers a question in place of an agent, `(who, question) -> String`.
var asker: Callable = Callable()
## How long this scene is meant to run, in words said (the rules tell it).
var words_aim := Vector2i(400, 1000)

var _released := false
var _asked := {}          # a person -> [{q, a}] in this scene
var _jobs := 0


func _init(ep: TableEpisode, scene: String, plan_data: Dictionary, prep_data: Dictionary, cast: PackedStringArray, start: GameLedger, job_dir: String, before: String) -> void:
	episode = ep
	step = scene
	plan = plan_data
	prep = prep_data
	people = cast
	ledger = start
	dir = job_dir
	said_before = before
	seed_value = ep.seed if ep != null else 0
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if String(f) == SUBMITTED or String(f) == "tools.jsonl":
			DirAccess.remove_absolute(dir.path_join(String(f)))


func release() -> void:
	_released = true


func instructions() -> String:
	return "The table, live: what you call happens, in the order you call it, and what is said cannot be taken back. Say lines, throw dice, ask the players, and end the scene."


func list_tools() -> Array:
	var who := {"type": "string", "description": "the person at the table: %s" % ", ".join(people)}
	return [
		{"name": "say", "description": "Lines said at the table, in order, each by one person. A line is only ever words a person says aloud. `over`: it comes in before the last line has ended (true, or the seconds of overlap). `together`: it comes in with the last line, as a table reacts as one. Answered with how long the scene has run.",
			"inputSchema": {"type": "object", "properties": {"lines": {"type": "array", "items": {"type": "object", "properties": {
				"who": who, "says": {"type": "string"}, "over": {"description": "true, or seconds"}, "together": {"type": "boolean"}, "chapter": {"type": "string", "description": "this line begins a chapter of the video, named so"}},
				"required": ["who", "says"]}}}, "required": ["lines"]}},
		{"name": "roll", "description": "Dice thrown onto the table, now, by the person named, from where they sit. Answered with what came up, which then stands: nothing rolls it again. Say what the roll is for and who throws it BEFORE you know the result. Written as players write it: 1d20+5, 2d20kh1+5, 8d6, 20d6>=3, 1d100, 4dF.",
			"inputSchema": {"type": "object", "properties": {"who": who, "dice": {"type": "string"}, "why": {"type": "string"},
				"hidden": {"type": "boolean", "description": "thrown behind a screen: the table sees and hears it land, and only the thrower knows"}}, "required": ["who", "dice", "why"]}},
		{"name": "change", "description": "Write on a sheet: a field `by` a number, `to` a value, or `add` / `remove` from a list. Fields are named by you: the game's own. Answered with what it was and what it is.",
			"inputSchema": {"type": "object", "properties": {"who": {"type": "string"}, "field": {"type": "string"}, "by": {"type": "number"}, "to": {}, "add": {}, "remove": {}, "why": {"type": "string"}}, "required": ["who", "field"]}},
		{"name": "map", "description": "Lay another map on the table. Whatever stood on the last comes off. `looks`: what it shows, from directly above, for the painter - any place at all, prepared or not. `size`: [across, down] in squares. `grid` false for a game measured with a tape, and `unit` what it measures in.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}, "looks": {"type": "string"}, "size": {"type": "array", "items": {"type": "number"}}, "grid": {"type": "boolean"}, "unit": {"type": "string"}}, "required": ["name", "looks"]}},
		{"name": "place", "description": "Set a figure on the map. `looks`: what it shows, for the painter. `owner`: the person who plays it, if anyone. `at`: [x, y], (0, 0) the map's far left.",
			"inputSchema": {"type": "object", "properties": {"figure": {"type": "string"}, "at": {"type": "array", "items": {"type": "number"}}, "looks": {"type": "string"}, "owner": {"type": "string"}}, "required": ["figure", "at", "looks"]}},
		{"name": "move", "description": "Take a figure to another place on the map. Answered with how far, for you to judge.",
			"inputSchema": {"type": "object", "properties": {"figure": {"type": "string"}, "to": {"type": "array", "items": {"type": "number"}}}, "required": ["figure", "to"]}},
		{"name": "fall", "description": "Lay a figure flat where it stands: down, not gone.", "inputSchema": {"type": "object", "properties": {"figure": {"type": "string"}}, "required": ["figure"]}},
		{"name": "rise", "description": "Stand a fallen figure up.", "inputSchema": {"type": "object", "properties": {"figure": {"type": "string"}}, "required": ["figure"]}},
		{"name": "remove", "description": "Take a figure off the map.", "inputSchema": {"type": "object", "properties": {"figure": {"type": "string"}}, "required": ["figure"]}},
		{"name": "reveal", "description": "Hold a picture up for the table: what you hand across to show them. Painted later from `looks`. Few, and only what is worth a viewer's looking at.",
			"inputSchema": {"type": "object", "properties": {"name": {"type": "string"}, "looks": {"type": "string"}}, "required": ["name", "looks"]}},
		{"name": "state", "description": "Everything as it stands: every sheet, the map, where each figure is.", "inputSchema": {"type": "object", "properties": {}}},
		{"name": "ask", "description": "Ask a player something, or what they do: they answer as themselves, knowing only what they know. You may not decide it for them. What they say and do, they say and do.",
			"inputSchema": {"type": "object", "properties": {"who": who, "what": {"type": "string", "description": "what you, the game master, say to them, in your own words"}}, "required": ["who", "what"]}},
		{"name": "ask_table", "description": "Ask every player at once: each answers on their own, not hearing the others.",
			"inputSchema": {"type": "object", "properties": {"what": {"type": "string"}}, "required": ["what"]}},
		{"name": "end_scene", "description": "This stretch of the session is done, and is handed in as it stands.", "inputSchema": {"type": "object", "properties": {}}},
		{"name": "game_over", "description": "The game has ended, however it did: a triumph, everyone dead, or it simply stopped being that game. The scenes not yet played will not be. `how`: what became of them, in a line. The close is still played.",
			"inputSchema": {"type": "object", "properties": {"how": {"type": "string"}}, "required": ["how"]}},
	]


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if _released or submitted:
		return {"text": "This scene is over and its tools are closed.", "error": true}
	match name:
		"say":
			return _say(args)
		"roll":
			return _did(ledger.roll(_person(args.get("who", "")), String(args.get("dice", "")), String(args.get("why", "")), seed_value, bool(args.get("hidden", false))), "roll")
		"change":
			return _did(ledger.change(String(args.get("who", "")), String(args.get("field", "")), _how_changed(args), String(args.get("why", ""))))
		"map":
			var size: Array = args.get("size", [20, 14]) if args.get("size") is Array else [20, 14]
			return _did(ledger.map_down(String(args.get("name", "")), String(args.get("looks", "")), size, bool(args.get("grid", true)), String(args.get("unit", GameLedger.UNIT))), "map")
		"place":
			return _did(ledger.place(String(args.get("figure", "")), _at(args.get("at")), String(args.get("looks", "")), _owner(args.get("owner", ""))), "place")
		"move":
			return _did(ledger.move(String(args.get("figure", "")), _at(args.get("to"))), "move")
		"fall", "rise", "remove":
			return _did(ledger.figure_state(name, String(args.get("figure", ""))), name)
		"reveal":
			return _did(ledger.reveal(String(args.get("name", "")), String(args.get("looks", ""))), "reveal")
		"state":
			return {"text": ledger.describe() + "\n\n" + _running()}
		"ask":
			return await _ask(args)
		"ask_table":
			return await _ask_table(args)
		"end_scene":
			return _submit()
		"game_over":
			ledger.end_game(String(args.get("how", "")))
			game_over = true
			return _submit()
	return {"text": "No tool called %s." % name, "error": true}


## An answer that happened, its mark put in the script at this point when a viewer sees it ([constant GameLedger.KINDS] `table`).
func _did(got: Dictionary, mark := "") -> Dictionary:
	if not bool(got.get("ok", false)):
		return {"text": String(got.get("words", "no")), "error": true}
	var e: Dictionary = got["event"]
	if not mark.is_empty():
		items.append({"mark": mark, "id": int(e["id"])})
	var text := String(got["words"])
	if String(e.get("kind", "")) == "roll":
		text = "Roll %d, thrown by %s: %s." % [int(e["id"]), String(e["who"]), text]
		if bool(e.get("hidden", false)):
			text += " Behind the screen: only you know it."
	return {"text": text}


func _how_changed(args: Dictionary) -> Dictionary:
	var out := {}
	for k in ["by", "to", "add", "remove"]:
		if args.has(k):
			out[k] = args[k]
	return out


func _at(v: Variant) -> Array:
	return v if v is Array else []


## The name of someone at the table as this table spells it, whoever asked; or as it was given, for the ledger to answer.
func _person(v: Variant) -> String:
	var s := String(v).strip_edges()
	for p in people:
		if p.to_lower() == s.to_lower():
			return p
	return s


func _owner(v: Variant) -> String:
	return _person(v) if not String(v).is_empty() else ""


func _say(args: Dictionary) -> Dictionary:
	var lines: Array = args.get("lines", []) if args.get("lines") is Array else []
	if lines.is_empty():
		return {"text": "`lines` is a list of {who, says}: nothing was said.", "error": true}
	if lines.size() > LINES_MOST:
		return {"text": "%d lines at once is more than a call takes (%d): say them in stretches." % [lines.size(), LINES_MOST], "error": true}
	var taken: Array = []
	for l in lines:
		if not (l is Dictionary):
			return {"text": "each line is {who, says}: nothing was said.", "error": true}
		var who := _person((l as Dictionary).get("who", ""))
		if not people.has(who):
			return {"text": "nobody called \"%s\" is at the table: %s. Nothing was said." % [String((l as Dictionary).get("who", "")), ", ".join(people)], "error": true}
		var said := _spoken(String((l as Dictionary).get("says", "")))
		if said.is_empty():
			return {"text": "%s's line has no words to say. Nothing was said." % who, "error": true}
		var item := {"who": who, "says": said}
		var over: Variant = (l as Dictionary).get("over")
		if over is bool and over:
			item["over"] = 0.0
		elif (over is float or over is int) and float(over) > 0.0:
			item["over"] = clampf(float(over), OVER_LEAST, OVER_MOST)
		if (l as Dictionary).get("together") == true:
			item["together"] = true
		var named := String((l as Dictionary).get("chapter", "")).strip_edges()
		if not named.is_empty():
			taken.append({"chapter": " ".join(named.split("\n", false))})
		taken.append(item)
	items.append_array(taken)
	return {"text": _running()}


## WHAT A PERSON CAN SAY: words, and the voice's own marks. A stage direction or a bracket is nothing a voice can read ([method TableProducer.clean_spoken]), and a change of speaker is the line's own.
static func _spoken(text: String) -> String:
	var t := TableProducer.clean_spoken(text)
	t = Manuscript._rx(Manuscript.SPEAKER).sub(t, "", true)
	for bad in ["<!-- speaker", "<!-- table"]:
		if t.contains(bad):
			t = Manuscript._rx("<!--\\s*(?:speaker|table)\\s*:[^>]*-->").sub(t, "", true)
	return t.strip_edges()


## How long the scene has run, in words and in what they come to.
func _running() -> String:
	var n := words_said(items)
	var rolled := 0
	for it in items:
		if String((it as Dictionary).get("mark", "")) == "roll":
			rolled += 1
	return "This scene so far: %d words, about %d minutes, %d rolls (aim: %d to %d words)." % [n, roundi(float(n) * TablePrompts.SAID_WORD / 60.0), rolled, words_aim.x, words_aim.y]


static func words_said(list: Array) -> int:
	var n := 0
	for it in list:
		if (it as Dictionary).has("says"):
			n += String((it as Dictionary)["says"]).split(" ", false).size()
	return n


# --- the players ------------------------------------------------------------------------------------------------------------------------------------

func _ask(args: Dictionary) -> Dictionary:
	var who := _person(args.get("who", ""))
	if not _is_player(who):
		return {"text": "%s is no player here: %s." % [String(args.get("who", "")), ", ".join(people.slice(1))], "error": true}
	var q := String(args.get("what", "")).strip_edges()
	if q.is_empty():
		return {"text": "`what` is what you say to them.", "error": true}
	var a: String = await _answer_of(who, q)
	return {"text": "%s: %s" % [who, a]}


func _ask_table(args: Dictionary) -> Dictionary:
	var q := String(args.get("what", "")).strip_edges()
	if q.is_empty():
		return {"text": "`what` is what you say to them.", "error": true}
	# ALL AT ONCE, each on their own: started together, and waited for in turn
	var jobs := {}
	for who in people.slice(1):
		if not asker.is_valid():
			jobs[who] = _start_answer(who, q)
	var out := PackedStringArray()
	for who in people.slice(1):
		var a: String = String(asker.call(who, q)) if asker.is_valid() else await _wait_answer(String(jobs[who]), who, q)
		out.append("%s: %s" % [who, a])
	return {"text": "\n".join(out)}


func _is_player(who: String) -> bool:
	return people.has(who) and who != people[0]


func _answer_of(who: String, q: String) -> String:
	if asker.is_valid():
		var a := String(asker.call(who, q))
		_remember(who, q, a)
		return a
	return await _wait_answer(_start_answer(who, q), who, q)


func _start_answer(who: String, q: String) -> String:
	_jobs += 1
	var sheet: Dictionary = (ledger.sheets.get(who, {}) as Dictionary)
	var p := TablePrompts.game_player(String(plan.get("_show_title", "")), String(plan.get("_brief", "")), plan, who, people, sheet, _want_of(who), heard(who), _asked.get(who, []), q)
	var ask_dir := dir.path_join("ask_%03d" % _jobs)
	DirAccess.make_dir_recursive_absolute(ask_dir)
	return AgentJobs.submit({"kind": "text", "slot": "aside", "backend": String(players.get("backend", "claude")), "tier": "fast", "dir": ask_dir,
		"system": String(p["system"]), "prompt": String(p["prompt"]), "label": "table ask %s" % who,
		"model": String(players.get("model", "")), "effort": String(players.get("effort", ""))})


func _wait_answer(id: String, who: String, q: String) -> String:
	if id.is_empty():
		return "(no answer: this session cannot start agents)"
	var began := Time.get_ticks_msec()
	while AgentJobs.state(id) in ["queued", "running"]:
		if _released or Time.get_ticks_msec() - began > ANSWER_MS:
			AgentJobs.cancel(id)
			return "(says nothing)"
		await TablePreview._tree().process_frame
	var res := AgentJobs.result(id)
	AgentJobs.forget(id)
	var a := String(res.get("text", "")).strip_edges()
	if a.is_empty():
		a = "(says nothing)"
	_remember(who, q, a)
	return a


func _remember(who: String, q: String, a: String) -> void:
	if not _asked.has(who):
		_asked[who] = []
	(_asked[who] as Array).append({"q": q, "a": a})


func _want_of(who: String) -> String:
	var sheet: Variant = (prep.get("people", {}) as Dictionary).get(who, {}) if prep.get("people") is Dictionary else {}
	return String((sheet as Dictionary).get("wants", "")) if sheet is Dictionary else ""


## WHAT HAS BEEN SAID ALOUD, as [param who] heard it: names on the lines, a hidden roll no number, the last [constant HEARD_MOST] words. Nothing a player is not at the table for reaches them.
func heard(_who := "") -> String:
	var text := said_before
	var here := transcript(items, ledger.events)
	if not here.is_empty():
		text = (text + "\n" + here).strip_edges()
	var words := text.split(" ", false)
	if words.size() > HEARD_MOST:
		text = "... " + " ".join(words.slice(words.size() - HEARD_MOST))
	return text


## A SCRIPT AS IT WAS HEARD: each line with its speaker, each roll as what the table saw land ([param events]: the rolls by their ids).
static func transcript(list: Array, events: Array) -> String:
	var by_id := {}
	for e in events:
		by_id[int((e as Dictionary).get("id", 0))] = e
	var out := PackedStringArray()
	for it in list:
		var d: Dictionary = it
		if d.has("says"):
			out.append("%s: %s" % [String(d["who"]), String(d["says"])])
		elif String(d.get("mark", "")) == "roll":
			var e: Dictionary = by_id.get(int(d["id"]), {})
			out.append("(%s rolls%s)" % [String(e.get("who", "")), " behind the screen" if bool(e.get("hidden", false)) else ": %s" % String(e.get("words", ""))])
	return "\n".join(out)


# --- handing it in ----------------------------------------------------------------------------------------------------------------------------------

func _submit() -> Dictionary:
	if words_said(items) < 1:
		return {"text": "Nothing has been said in this scene.", "error": true}
	submitted = true
	var path := dir.path_join(SUBMITTED)
	var f := FileAccess.open(path + ".part", FileAccess.WRITE)
	if f == null:
		return {"text": "could not write the scene", "error": true}
	f.store_string(JSON.stringify({"text": compose(items, people), "items": items, "events": ledger.events, "over": game_over}))
	f.close()
	DirAccess.rename_absolute(path + ".part", path)
	return {"text": "Handed in. Your work is done."}


## THE SCENE AS A SCRIPT ([CardReading]): each line under its speaker's cue, an overlap's mark after the cue, each thing a viewer sees as its own-line mark, in the order it happened.
## The game master speaks as the reader ([constant Manuscript.NARRATOR]), since the show's first voice is its voice.
static func compose(list: Array, cast: PackedStringArray) -> String:
	var out := PackedStringArray()
	var last := ""
	var gm := cast[0] if not cast.is_empty() else ""
	for it in list:
		var d: Dictionary = it
		if d.has("chapter"):
			out.append("<!-- chapter: %s -->" % String(d["chapter"]))
		elif d.has("mark"):
			out.append("<!-- table: %s %d -->" % [String(d["mark"]), int(d["id"])])
		else:
			var who := String(d["who"])
			var cue := Manuscript.NARRATOR if who == gm else who
			var lines := PackedStringArray()
			if cue != last or d.has("over") or d.has("together"):
				lines.append("<!-- speaker: %s -->" % cue)
			last = cue
			if d.has("together"):
				lines.append("<!-- together -->")
			elif d.has("over"):
				var by := float(d["over"])
				lines.append("<!-- over -->" if by <= 0.0 else "<!-- over: %s -->" % String.num(by, 2))
			lines.append(String(d["says"]))
			out.append("\n".join(lines))
	return "\n\n".join(out)

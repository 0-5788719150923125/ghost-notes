extends SceneTree

## The set dresser's tools ([SetDresserTools]) and how the producer works them - with no agent, no
## model and no renderer.
##
##   godot --headless --path . --script res://tests/cards/set_dresser_tools_check.gd
##
## - A RUN STARTS CLEAN: what a last run handed in, logged or photographed is gone; its prompt stays.
## - PUT says what the builder makes of a thing: its real size and flames, parts it cannot build and
##   why, materials it does not know, more parts or deeper groups than a thing may have, and a thing
##   taller than its place can show. A thing put again under its name REPLACES it. The tally counts
##   lit things against the look's ask.
## - REMOVE, LOOK and SET answer by name and say what is on the table when a name is wrong; with no
##   renderer, LOOK and SET say there is no picture and take none.
## - SUBMIT refuses an empty table, writes the draft exactly as written, and - where a table can be
##   stood - sends the set dresser to look first, once; and to choose the name's color, once.
## - TITLE keeps the name's color (a color only) in the draft, says so with no renderer and takes no
##   picture; the toolset knows the show's name and byline, and both prompts tell the set dresser of
##   the opening and the color it chooses.
## - THE PRODUCER gives a writer that takes tools the toolset (a URL, a long timeout, the working
##   prompt) and one that does not the one-reply prompt; it lands a handed-in table whatever the run's
##   last words, says so when a run with tools handed nothing in, and closes the tools when it stops.
## - CLAUDE WITH TOOLS loads no settings instead of `--safe-mode` (which drops every MCP server) and is
##   pointed at the toolset by a config file, which gives a call ten minutes (the CLI's own limit is
##   one); without tools its argv is as it was. CODEX WITH TOOLS is
##   pointed at ghost's endpoint by config overrides, its token in its environment (never in argv), its
##   calls approved, and told its tools are neither commands nor files; without tools, no server.
## - THE TABLE ITSELF: a top and layers put are said back as the table will be built (a top grown to
##   hold the cards says so), kept in the draft only once put (no `layers` is the old cloth, `[]` a bare
##   top), a layer put again under its name replaced, taken off by name; OVERHEAD with no renderer says
##   there is no picture and takes none.
## - THE AIR: effects put beside things are reported - what was built, and every kind, place, look or
##   moment the builder does not know, a size kept within its look's range - replaced and removed by
##   name, handed in with the table, and watched by name (with no renderer, said so).
## - THE LIGHT ([Lights]): put part by part - a part put again replaces that part alone, a screen or a
##   lamp replaces the one of its name, null takes a part away, an empty list all of its kind - and
##   reported: what it is, what the builder does not know, where the sun falls (on the table, and where
##   the cards lie), how the weather runs, a lamp moved up out of the shot; parts taken off by name (or
##   "clouds", "birds", "light"), watched by name (with no renderer, said so), handed in with the table;
##   both prompts tell the set dresser of it, its vocabulary, its format and earlier episodes' light.

## - ONE CALL AT A TIME (reported 2026-10-07: the table's job ended while a call was photographing, and
##   every picture after it was "a previously freed instance"): two calls made together run one after the
##   other, a release during a call gives the stages back only when it is done, and a call after it is
##   turned away - the control, the same two calls straight into the toolset's own work, overlap.
## - THE TABLE IS SET, AND IS TOLD SO (reported 2026-10-08: a set dresser set its table 14 times chasing
##   things made 88% of their size): a thing made smaller to fit is said at its size, not as a fault, and
##   with nothing left off the frame's question says the table is set and what is left (the title's color,
##   then submit) - the control, a thing left off, is still sent to fix it; the producer says how many
##   pictures its set dresser has taken while its tools are open, and the prompt says a shrink is fine.
## - THE BLUEPRINT (the user, 2026-10-18: "draw a literal blueprint ... then simply ask the model to place
##   props onto the blueprint at certain points, and with certain orientations"): things placed by name -
##   `at`, `turn`, `scale`, only what is given - and refused with a reason when not put, the cards' box,
##   or not a number; a thing put again keeps its place unless given one; a thing never placed waits off
##   the table in every picture (control: the draft keeps it) and is asked about once at submit; with no
##   renderer the plan is said in words and no picture taken. A thing written where it stands is said at
##   its spot - moved from it, or taller than its spot shows, a fault; cut by the frame's side, not - and
##   never "made smaller to fit".
## - THE DRAWING ([TableBlueprint]), without a renderer: the closed-form headroom agrees with the frame
##   walked up step by step ([method CardTable.headroom]) - control: a lens 10 degrees wider does not; each
##   height's line holds that height at its ends, a thing that tall seen whole nearer the reader and cut
##   behind; an outline drawn round a top is the top's size; the frame on the table meets the frame's
##   edge; the plan fits every card and thing in the drawing.
## - HOW FULL A TABLE IS (CardPrompts.FILLS): drawn per episode from a few things to a crowded table, some
##   seeds asking for more than the old most (6) and some for under it.
const ROOT := "user://set_dresser_check"

const FixtureDeck := preload("res://tests/fixture_deck.gd")

var _fails := 0


## A toolset whose table can be stood (to reach the submit rule) but which takes no pictures.
class Standing:
	extends SetDresserTools

	func _can_stand() -> bool:
		return true

	func _can_see() -> bool:
		return false


## A toolset whose every call takes a few frames, as a picture does, and logs when it starts and ends.
class Slow:
	extends SetDresserTools
	var log: Array = []
	func _call(name: String, _args: Dictionary) -> Dictionary:
		log.append("start " + name)
		for i in 3:
			await TablePreview._tree().process_frame
		log.append("end " + name)
		return {"text": name}


## A producer that records the job it would have submitted instead of starting it.
class Spy:
	extends CardProducer

	var sent := {}

	func _submit_text(step: String, p: Dictionary, tier: String, extra: Dictionary = {}) -> void:
		sent = {"step": step, "prompt": p, "tier": tier, "extra": extra}


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	AgentJobs.allow_for_tool()
	for check in [_fresh_start, _tools_listed, _put_reports, _remove_look_set, _submit, _title, _producer, _prompts, _claude_argv, _air, _table_itself, _light, _one_at_a_time, _verdict, _blueprint, _drawing, _fills]:
		var done: Variant = await (check as Callable).call()
		_ok(done == true, "%s stopped part way (a script error - see above)" % (check as Callable).get_method())
	print("set_dresser_tools_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _episode() -> CardEpisode:
	CardEpisode.root = ROOT
	var ep := CardEpisode.open("check-show", 5150)
	if DirAccess.dir_exists_absolute(ep.dir):
		for f in DirAccess.get_files_at(ep.dir):
			DirAccess.remove_absolute(ep.dir.path_join(f))
	ep.write_json("plan", {"episode_title": "A Table Set On Purpose", "audience": "everyone", "topic": "tables",
		"premise": "the premise", "reader_mood": "calm", "spread": {"name": "Three", "positions": [{"name": "One"},
		{"name": "Two"}, {"name": "Three"}]}, "look": CardTable.sanitize_look({"deck_name": "The Test Deck", "candles": 2})})
	var cards: Array = []
	for c in CardDeck.shuffled(FixtureDeck.cards(), ep.seed, true).slice(0, 3):
		cards.append(c)
	ep.write_json("draw", {"seed": ep.seed, "cards": cards})
	return ep


func _tools(ep: CardEpisode) -> SetDresserTools:
	return SetDresserTools.new(ep, ep.read_json("plan"), ep.job_dir("table"))


func _candle(name: String, h: float, place := "back left", at: Variant = [-30.0, -26.0]) -> Dictionary:
	var out := {"name": name, "why": "light", "place": place, "group": "c", "parts": [{"shape": "lathe",
		"profile": [[0, 0], [2, 0], [2, h], [0, h]], "material": "beeswax", "wick": true}]}
	if at != null:
		out["at"] = at
	return out


func _fresh_start() -> bool:
	var ep := _episode()
	var jd := ep.job_dir("table")
	DirAccess.make_dir_recursive_absolute(jd)
	for f in [SetDresserTools.SUBMITTED, "tools.jsonl", "look_01.jpg", "prompt.txt"]:
		TextGen.put(jd.path_join(String(f)), "old")
	var t := _tools(ep)
	_ok(not FileAccess.file_exists(jd.path_join(SetDresserTools.SUBMITTED)) and not FileAccess.file_exists(jd.path_join("tools.jsonl"))
		and not FileAccess.file_exists(jd.path_join("look_01.jpg")), "a new run kept the last run's table, log or pictures")
	_ok(FileAccess.file_exists(jd.path_join("prompt.txt")), "a new run took more than the last run's own output")
	t.release()
	return true


func _tools_listed() -> bool:
	var t := _tools(_episode())
	var names: Array = []
	var shaped := true
	for d in t.list_tools():
		names.append(String((d as Dictionary)["name"]))
		shaped = shaped and String(((d as Dictionary)["inputSchema"] as Dictionary).get("type", "")) == "object" \
			and not String((d as Dictionary).get("description", "")).is_empty()
	_ok(names == ["put", "remove", "blueprint", "look", "set", "overhead", "watch", "title", "submit"], "the set dresser's tools are %s" % str(names))
	_ok(shaped, "a tool has no description or no object schema")
	var r: Dictionary = await t.call_tool("paint", {})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("put, remove, blueprint, look, overhead, set, watch, title and submit"),
		"an unknown tool did not name the real ones: %s" % r)
	t.release()
	return true


func _put_reports() -> bool:
	var ep := _episode()
	var t := _tools(ep)
	var r: Dictionary = await t.call_tool("put", {"things": [{"name": "a hat", "place": "left", "parts": [{"shape": "hat"}]}]})
	var text := String(r["text"])
	_ok(text.contains("a hat") and text.contains("NOTHING BUILT") and text.contains("\"hat\" is not a shape"),
		"a thing with no buildable part was not reported as such:\n%s" % text)
	r = await t.call_tool("put", {"things": [_candle("a pillar", 9.0)]})
	text = String(r["text"])
	_ok(text.contains("\"beeswax\" is not one of the table's materials"), "an unknown material was not reported:\n%s" % text)
	_ok(text.contains("4 x 9 x 4 cm") and text.contains("1 flame"), "a candle's size and flame were not reported:\n%s" % text)
	_ok(text.contains("No pictures in this run"), "a run with no renderer did not say it took no picture:\n%s" % text)
	_ok((r.get("images", []) as Array).is_empty(), "a run with no renderer returned a picture")
	r = await t.call_tool("put", {"materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}, "odd": {"kind": "cheese", "color": "pale", "play": "sparkle"}}})
	text = String(r["text"])
	_ok(text.contains("\"cheese\" is not a kind") and text.contains("its color is not #rrggbb") and text.contains("\"sparkle\" is not a play"),
		"a material's faults were not reported:\n%s" % text)
	r = await t.call_tool("put", {"things": [_candle("a pillar", 12.0), _candle("a taper", 7.0, "back right")]})
	text = String(r["text"])
	_ok(not text.contains("not one of the table's materials"), "a material put after its thing was still unknown:\n%s" % text)
	_ok((t.draft()["things"] as Array).size() == 3 and text.contains("the table now holds 3") and text.contains("4 x 12 x 4 cm"),
		"a thing put again under its name was not replaced (%d things):\n%s" % [(t.draft()["things"] as Array).size(), text])
	_ok(text.contains("2 lit things (2 asked for)"), "the tally does not count lit things against the ask:\n%s" % text)
	# A THING TALLER THAN ITS SPOT SHOWS is said where it is written - and a thing not yet placed is not judged
	var lay := CardTable.layout_of(ep.seed)
	var room := CardTable.headroom_at(lay["camera"], float(lay["fov"]), Tables.ORIGIN + Vector2(0.0, -0.3)) * 100.0
	r = await t.call_tool("put", {"things": [{"name": "a tall jar", "at": [0, -30], "parts": [{"shape": "box",
		"size": [6, roundi(room) + 10, 6], "material": "beeswax"}]}, {"name": "a tall jug", "parts": [{"shape": "box",
		"size": [6, roundi(room) + 10, 6], "material": "beeswax"}]}]})
	text = String(r["text"])
	_ok(text.contains("a tall jar (at [0, -30])") and text.contains("where it stands the frame shows only %s cm" % TablePreview._cm(room * 0.01)),
		"a thing taller than its spot shows was not reported:\n%s" % text)
	_ok(text.contains("a tall jug (not yet placed)") and text.count("the frame shows only") == 1,
		"control: a thing not yet placed was judged by a spot it has none of:\n%s" % text)
	var many: Array = []
	for i in 20:
		many.append({"shape": "ball", "radius": 1, "at": [i * 2, 0, 0], "material": "beeswax"})
	var deep := {"parts": [{"parts": [{"parts": [{"parts": [{"shape": "ball", "radius": 1}]}]}]}]}
	r = await t.call_tool("put", {"things": [{"name": "beads", "parts": many}, {"name": "nest", "parts": [deep, {"shape": "ball", "radius": 2}]}]})
	text = String(r["text"])
	_ok(text.contains("past the %d parts" % Props.MAX_PARTS), "more parts than a thing may have were not reported:\n%s" % text)
	r = await t.call_tool("put", {"things": [{"name": "a stub", "parts": [{"shape": "lathe", "profile": [[1, 1]]},
		{"shape": "tube", "path": [[0, 0, 0]]}]}]})
	_ok(String(r["text"]).contains("a lathe's profile needs two") and String(r["text"]).contains("a tube's path needs two"),
		"a lathe or a tube too short to build was not reported:\n%s" % r["text"])
	_ok(text.contains("more than %d groups deep" % Props.MAX_DEPTH), "a group nested too deep was not reported:\n%s" % text)
	var copies := {"name": "tea lights", "parts": [{"shape": "lathe", "profile": [[0, 0], [2, 0], [2, 1.5], [0, 1.5]], "material": "beeswax",
		"wick": true, "copies": {"ring": {"count": 3, "radius": 4}}}]}
	r = await t.call_tool("put", {"things": [copies]})
	_ok(String(r["text"]).contains("3 flames") and String(r["text"]).contains("3 lit things"), "copied candles were not counted:\n%s" % r["text"])
	r = await t.call_tool("put", {"things": "a lamp"})
	_ok(bool(r.get("error", false)), "a put of nothing usable was not refused")
	t.release()
	return true


func _remove_look_set() -> bool:
	var t := _tools(_episode())
	await t.call_tool("put", {"things": [_candle("a pillar", 9.0), _candle("a taper", 14.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	var r: Dictionary = await t.call_tool("remove", {"names": ["a lamp"]})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("On it: a pillar, a taper"), "removing a thing not there was not refused with what is: %s" % r)
	r = await t.call_tool("remove", {"names": ["a taper"]})
	_ok(not bool(r.get("error", false)) and (t.draft()["things"] as Array).size() == 1, "removing a thing did not take it off: %s" % r)
	r = await t.call_tool("look", {"name": "a lamp"})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("On it: a pillar"), "looking at a thing not there was not refused with what is: %s" % r)
	r = await t.call_tool("look", {"name": "a pillar"})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("a pillar") and (r.get("images", []) as Array).is_empty(),
		"looking with no renderer did not describe the thing without a picture: %s" % r)
	r = await t.call_tool("set", {})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("cannot be stood in this run") and (r.get("images", []) as Array).is_empty(),
		"setting with no renderer did not say so: %s" % r)
	t.release()
	return true


func _submit() -> bool:
	var ep := _episode()
	var t := _tools(ep)
	var r: Dictionary = await t.call_tool("submit", {})
	_ok(bool(r.get("error", false)) and not t.submitted, "an empty table was handed in")
	await t.call_tool("put", {"idea": "a calm table", "things": [_candle("a pillar", 9.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	await t.call_tool("title", {"color": "#1d2f5c", "why": "deep ink on a pale cloth"})
	r = await t.call_tool("submit", {})
	var path := ep.job_dir("table").path_join(SetDresserTools.SUBMITTED)
	var j := JSON.new()
	var same := FileAccess.file_exists(path) and j.parse(FileAccess.get_file_as_string(path)) == OK \
		and JSON.stringify(j.data) == JSON.stringify(JSON.parse_string(JSON.stringify(t.draft())))
	_ok(not bool(r.get("error", false)) and t.submitted and same and String(r["text"]).begins_with("Handed in: 1 thing"),
		"a table was not handed in exactly as drafted: %s" % r)
	_ok(same and String((j.data as Dictionary).get("title", {}).get("color", "")) == "#1d2f5c", "the name's color was not handed in with the table")
	t.release()
	# THE NAME'S COLOR, asked for once - a table handed in without one gets the default
	var plain := _tools(ep)
	await plain.call_tool("put", {"things": [_candle("a pillar", 9.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	r = await plain.call_tool("submit", {})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("call title") and not plain.submitted, "a table with no name's color was handed in without a word")
	r = await plain.call_tool("submit", {})
	_ok(not bool(r.get("error", false)) and plain.submitted and not plain.draft().has("title"), "a second submit with no color was refused: %s" % r)
	plain.release()
	# WHERE A TABLE CAN BE STOOD, the set dresser looks before it hands in - asked once, then trusted
	var s := Standing.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	await s.call_tool("put", {"things": [_candle("a pillar", 9.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	r = await s.call_tool("submit", {})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("call set") and not s.submitted, "a table never seen was handed in without a word")
	await s.call_tool("title", {"color": "#e9dcc0"})
	r = await s.call_tool("submit", {})
	_ok(not bool(r.get("error", false)) and s.submitted, "a second submit, unchanged, was refused: %s" % r)
	s.release()
	# A THING NEVER PLACED ON THE BLUEPRINT is asked about once, then handed in for the table to stand
	var loose := _tools(ep)
	await loose.call_tool("put", {"things": [_candle("a pillar", 9.0), _candle("a stub", 4.0, "back right", null)],
		"materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	await loose.call_tool("title", {"color": "#e9dcc0"})
	r = await loose.call_tool("submit", {})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("Not placed on the blueprint: a stub.") and not loose.submitted,
		"a table with a thing never placed was handed in without a word: %s" % r)
	r = await loose.call_tool("submit", {})
	_ok(not bool(r.get("error", false)) and loose.submitted, "a second submit with a thing unplaced was refused: %s" % r)
	loose.release()
	return true


## THE NAME'S COLOR: kept in the draft as given (a color only, the reason with it), said back with no
## renderer and no picture taken; anything not a color refused, the color before it kept.
func _title() -> bool:
	var t := _tools(_episode())
	var r: Dictionary = await t.call_tool("title", {"color": "#1d2f5c", "why": "deep ink on a pale cloth"})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("#1d2f5c") and String(r["text"]).contains("cannot be shown in this run")
		and (r.get("images", []) as Array).is_empty(), "choosing the name's color with no renderer did not say so: %s" % r)
	_ok(t.draft().get("title") == {"color": "#1d2f5c", "why": "deep ink on a pale cloth"}, "the draft does not carry the name's color: %s" % str(t.draft()))
	_ok(CardTable.title_ink(CardTable.sanitize_table(t.draft(), {})).to_html(false) == "1d2f5c", "the table does not print the name in the color chosen")
	for junk in ["navy", "#1d2f5", 12, ""]:
		r = await t.call_tool("title", {"color": junk})
		_ok(bool(r.get("error", false)) and String((t.draft()["title"] as Dictionary)["color"]) == "#1d2f5c",
			"a color of %s was taken, or lost the one before: %s" % [str(junk), r])
	r = await t.call_tool("title", {})
	_ok(bool(r.get("error", false)), "a title with no color was taken")
	t.release()
	return true


func _producer() -> bool:
	var ep := _episode()
	TextGen.put(ep.file_of("image:surface"), "png")
	# WITH TOOLS: the job gets the toolset's URL and a long timeout, and the working prompt
	var spy := Spy.new(ep, {"title": "Test Tarot", "byline": "with Pen & Ink", "brief": "A brief.", "writer": "claude"})
	spy._make_table()
	var extra: Dictionary = spy.sent.get("extra", {})
	var prompt := String((spy.sent.get("prompt", {}) as Dictionary).get("prompt", ""))
	var preview: TablePreview = (spy._tools.get("table", {}) as Dictionary).get("set")._preview if spy._tools.has("table") else null
	_ok(preview != null and preview.show_name == "Test Tarot" and preview.byline == "with Pen & Ink",
		"the toolset does not know the show's name and byline for the opening")
	_ok(prompt.contains("\"Test Tarot\", set large across the middle of the frame, and under it \"with Pen & Ink\""),
		"the set dresser is not told the name and byline over its table")
	var url := String(extra.get("tools_url", ""))
	_ok(url.begins_with("http://127.0.0.1:") and not extra.has("timeout"),
		"a writer that takes tools was not given them: %s" % extra)
	_ok(prompt.contains("HOW YOU WORK") and prompt.contains("submit") and not prompt.contains("Reply with ONLY a JSON object"),
		"a writer given tools was not told how to work with them")
	_ok(AgentTools.calls(url) == 0 and spy._tools.has("table"), "the toolset was not opened for the step")
	_ok(spy.table_looks() == 0, "the producer does not say how many pictures its set dresser has taken: %d" % spy.table_looks())
	spy.stop()
	_ok(spy.table_looks() == -1, "the producer says its set dresser is looking after its tools closed")
	_ok(AgentTools.calls(url) == -1 and spy._tools.is_empty(), "stopping the producer left the tools answering")
	# WITHOUT: the one-reply prompt, no tools
	var plain := Spy.new(ep, {"title": "Test Tarot", "brief": "A brief.", "writer": "bedrock"})
	plain._make_table()
	_ok((plain.sent.get("extra", {}) as Dictionary).is_empty() and plain._tools.is_empty()
		and String((plain.sent["prompt"] as Dictionary)["prompt"]).contains("Reply with ONLY a JSON object"),
		"a writer that takes no tools was not asked for the table in one reply")
	# A HANDED-IN TABLE LANDS whatever the run's last words, even a run that ended badly
	var prod := CardProducer.new(ep, {"title": "Test Tarot", "brief": "A brief.", "deck": FixtureDeck.cards()})
	var given := SetDresserTools.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	prod._tools["table"] = {"url": AgentTools.open(ep.job_dir("table"), given), "set": given}
	TextGen.put(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED), CardPrompts.set_example())
	prod._land("table", {"ok": false, "error": "timed out after 1500 s"})
	_ok(ep.has("table") and String(((ep.read_json("table") as Dictionary)["things"][0] as Dictionary)["name"]) == "a boxwood chess pawn",
		"a table handed in with a tool did not land")
	# ...but a run WITHOUT tools is answered by its own reply, never by a table some earlier run left
	ep.invalidate("table")
	TextGen.put(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED), CardPrompts.set_example())
	var plain_land := CardProducer.new(ep, {"title": "Test Tarot", "brief": "A brief.", "deck": FixtureDeck.cards()})
	plain_land._tries["table"] = CardProducer.RETRIES + 1
	plain_land._land("table", {"ok": true, "text": "no table here"})
	_ok(not ep.has("table") and plain_land.error_of("table") == "the table was not JSON",
		"a run without tools landed a table an earlier run had handed in")
	plain._make_table()
	_ok(not FileAccess.file_exists(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED)),
		"a new run of the table step kept an earlier run's handed-in table")
	# ...and a run with tools that handed nothing in says so
	DirAccess.remove_absolute(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED))
	ep.invalidate("table")
	var tools := SetDresserTools.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	prod._tools["table"] = {"url": AgentTools.open(ep.job_dir("table"), tools), "set": tools}
	prod._tries["table"] = CardProducer.RETRIES + 1
	prod._land("table", {"ok": true, "text": "Done."})
	_ok(prod.error_of("table") == "the set dresser stopped without handing its table in" and prod._tools.is_empty(),
		"a run with tools that handed nothing in failed as '%s'" % prod.error_of("table"))
	return true


func _prompts() -> bool:
	var ep := _episode()
	var head := CardTable.headroom(ep.seed)
	var size := CardPrompts.table_size(ep.seed)
	_ok(CardPrompts.set_dresser("T", "B", ep.read_json("plan"), ep.seed, head, [], true, 0, ["sea mist (fog)"])["prompt"].contains("EARLIER EPISODES' AIR was this. Give this table its own, or none: sea mist (fog)"),
		"the set dresser is not told what air earlier tables had")
	for looks in [0, SetDresserTools.LOOKS]:
		var p := CardPrompts.set_dresser("Test Tarot", "A brief.", ep.read_json("plan"), ep.seed, head, [], true, looks)
		var text := String(p["prompt"])
		var tag := "with tools" if looks > 0 else "in one reply"
		_ok(text.contains("cannot make a BODY") and text.contains("it has no body"), "the set dresser %s is not told it builds no bodies" % tag)
		_ok(text.contains("Exactly 2 lit things -") and text.contains("and %d to %d other things" % [size.x, size.y]),
			"the set dresser %s is not told what the table holds" % tag)
		for k in Props.SHAPES:
			_ok(text.contains("- %s:" % k), "the set dresser %s is not told the shape %s" % [tag, k])
		# ZONES for the reply written blind; the BLUEPRINT for the one that sees
		for z in CardTable.ZONES:
			_ok(text.contains("\"%s\": %s; up to %d cm" % [z, String((CardTable.ZONES[z] as Dictionary)["about"]), int(head[z])]) == (looks == 0),
				"the set dresser %s is %s the zone %s" % [tag, "told" if looks > 0 else "not told", z])
		_ok(text.contains("WHERE THINGS STAND is yours to write, on the table's BLUEPRINT") == (looks > 0),
			"the set dresser %s is %s the blueprint" % [tag, "not told of" if looks > 0 else "told of"])
		_ok(text.contains(CardPrompts.set_example(looks > 0)), "the set dresser %s is not shown the format" % tag)
		_ok(text.contains("\"at\": [-31, -24]") == (looks > 0) and text.contains("\"place\": \"back left\"") == (looks == 0),
			"the set dresser %s is shown a thing placed the other way" % tag)
		_ok(text.contains("can hold more, up to %d" % (CardTable.MAX_THINGS - 2)), "the set dresser %s is not told how full a table may be" % tag)
		_ok(text.contains("THE AIR:"), "the set dresser %s is not told about the air" % tag)
		_ok(text.contains("THE LIGHT:") and text.contains(Rules.say("cards/set_dresser.light_example")), "the set dresser %s is not told about the light, or shown its format" % tag)
		for k in Lights.SCREENS.keys() + Lights.BIRDS.keys() + Lights.LAMPS.keys() + Lights.SUNS.keys() + Lights.CASTER_SHAPES.keys() + Lights.CASTER_MOVES.keys():
			_ok(text.contains("- %s:" % k), "the set dresser %s is not told the light's word %s" % [tag, k])
		_ok(text.contains("- shadows:") and text.contains("a rope or a lantern swinging"), "the set dresser %s is not told of shadows out of the shot" % tag)
		for k in Effects.KINDS.keys() + Effects.MOTES.keys() + Effects.BURSTS.keys():
			_ok(text.contains("- %s:" % k), "the set dresser %s is not told the effect word %s" % [tag, k])
		for k in CardTable.AIR.keys() + CardTable.MOMENTS.keys():
			_ok(text.contains("- \"%s\":" % k), "the set dresser %s is not told the place or moment %s" % [tag, k])
		_ok(text.contains("HOW YOU WORK") == (looks > 0) and text.contains("Reply with ONLY a JSON object") == (looks == 0),
			"the set dresser %s is told the other way of working" % tag)
		if looks > 0:
			_ok(text.contains("against the %d you have" % looks), "the set dresser is not told how many pictures it has")
			_ok(text.contains("PLAN THE TABLE ON THE BLUEPRINT") and text.contains("`blueprint` places things by name")
				and text.contains("When set says the table is set, it is"),
				"the set dresser is not told to plan on the blueprint, or that a set table is set")
		_ok(text.contains("THE TITLE:") and text.contains("\"Test Tarot\"") and text.contains("thumbnail"),
			"the set dresser %s is not told of the opening and its thumbnail" % tag)
		_ok(text.contains("`title` chooses the color") == (looks > 0) and text.contains("\"title\": {\"color\": \"#rrggbb\"") == (looks == 0),
			"the set dresser %s is not told how to give the name's color" % tag)
	_ok(not String(CardPrompts.set_dresser("Test Tarot", "A brief.", ep.read_json("plan"), ep.seed, head, [], true)["prompt"]).contains("and under it"),
		"a show with no byline is told of one")
	var lit := String(CardPrompts.set_dresser("T", "B", ep.read_json("plan"), ep.seed, head, [], true, 0, [], "", [],
		["the sun from the left, 20 degrees up through a blind"], true)["prompt"])
	_ok(lit.contains("EARLIER EPISODES WERE LIT LIKE THIS") and lit.contains("through a blind"), "the set dresser is not told how earlier tables were lit")
	_ok(lit.contains("ITS PAINTING attached") and lit.contains("agree with the room (its painting attached)"), "the set dresser is not told the room's painting comes with it")
	_ok(not String(CardPrompts.set_dresser("T", "B", ep.read_json("plan"), ep.seed, head, [], true)["prompt"]).contains("ITS PAINTING attached"),
		"a set dresser with no room's painting is told it has one")
	return true


func _claude_argv() -> bool:
	var dir := ProjectSettings.globalize_path(ROOT).path_join("claude")
	DirAccess.make_dir_recursive_absolute(dir)
	var job := {"dir": dir, "tier": "best", "tools_url": "http://127.0.0.1:4242/mcp/" + "ab".repeat(16)}
	var tools := TextGen.Claude.tool_args(job)
	var args := TextGen.Claude.argv(job, dir.path_join("system.txt"), tools)
	var j := JSON.new()
	var cfg_ok := j.parse(FileAccess.get_file_as_string(dir.path_join("mcp.json"))) == OK \
		and String(j.data["mcpServers"]["ghost"]["url"]) == String(job["tools_url"]) and String(j.data["mcpServers"]["ghost"]["type"]) == "http"
	_ok(cfg_ok, "the tools' config does not name the job's URL")
	_ok(cfg_ok and int(j.data["mcpServers"]["ghost"].get("timeout", 0)) == TextGen.Claude.TOOL_TIMEOUT_MS
		and TextGen.Claude.TOOL_TIMEOUT_MS == TextGen.Codex.TOOL_TIMEOUT * 1000,
		"a call of ghost's tools is not given Codex's ten minutes: %s" % str(j.data))
	var at := args.find("--setting-sources")
	_ok(at >= 0 and args[at + 1] == "" and not args.has("--safe-mode"), "a writer with tools still runs in safe mode (which drops ghost's tools): %s" % str(args))
	_ok(args.has("--strict-mcp-config") and args[args.find("--mcp-config") + 1] == dir.path_join("mcp.json")
		and args[args.find("--allowedTools") + 1] == "mcp__ghost" and args[args.find("--tools") + 1] == "",
		"a writer with tools is not pointed at ghost's alone: %s" % str(args))
	for a in args:
		_ok(not String(a).contains("/mcp/"), "the tools' URL is in argv")
	var none := TextGen.Claude.argv({"dir": dir, "tier": "best"}, dir.path_join("system.txt"), TextGen.Claude.tool_args({"dir": dir}))
	_ok(none.has("--safe-mode") and not none.has("--setting-sources") and not none.has("--mcp-config") and none[none.find("--tools") + 1] == "",
		"a writer without tools is not run as before: %s" % str(none))
	_ok(TextGen.make("claude").takes_tools() and TextGen.make("grok").takes_tools() and TextGen.make("codex").takes_tools()
		and not TextGen.make("bedrock").takes_tools(),
		"the writers that take tools are not Claude, Grok and Codex (Grok's own argv: tests/agents/grok_agent_check.gd)")
	# CODEX: ghost's server named in its config overrides, the token in its environment and never in argv
	var cx_url := "http://127.0.0.1:4242/mcp/" + "ab".repeat(16)
	var cx: PackedStringArray = TextGen.Codex.argv({"dir": dir, "tier": "best", "tools_url": cx_url}, [])
	var joined := " ".join(cx)
	_ok(joined.contains("mcp_servers.ghost.url=\"http://127.0.0.1:4242/mcp/\"")
		and joined.contains("mcp_servers.ghost.bearer_token_env_var=\"%s\"" % TextGen.Codex.TOKEN_ENV)
		and joined.contains("mcp_servers.ghost.default_tools_approval_mode=\"approve\"")
		and joined.contains("mcp_servers.ghost.tool_timeout_sec=%d" % TextGen.Codex.TOOL_TIMEOUT)
		and not joined.contains("ab".repeat(16)) and cx[cx.size() - 1] == "-",
		"Codex with tools is not pointed at ghost's alone, its calls approved, its token out of argv: %s" % joined)
	_ok(TextGen.Codex.compose({"dir": dir, "prompt": "Set it.", "tools_url": cx_url})["prompt"].contains("MCP server \"ghost\"")
		and not TextGen.Codex.compose({"dir": dir, "prompt": "Set it."})["prompt"].contains("MCP server"),
		"Codex with tools is not told its tools are no commands or files (or one without is)")
	_ok(not " ".join(TextGen.Codex.argv({"dir": dir, "tier": "best"}, [])).contains("mcp_servers"),
		"the control: Codex without tools was given a server")
	return true


func _air() -> bool:
	var ep := _episode()
	var t := _tools(ep)
	var r: Dictionary = await t.call_tool("put", {"effects": [
		{"name": "sea mist", "kind": "fog", "where": "beyond the table", "density": 0.5},
		{"name": "wisps", "kind": "motes", "look": "pixie", "where": "beyond the table", "count": 5, "size": 40},
		{"name": "sparks", "kind": "burst", "look": "sparks", "on": "jumper"},
		{"name": "rain", "kind": "weather"},
		{"name": "lost", "kind": "fog", "where": "the ceiling"},
		{"name": "odd", "kind": "burst", "look": "confetti", "on": "the end"},
		{"name": "flies", "kind": "motes", "look": "fly", "where": "over the cloth", "count": 3, "light": true}]})
	var text := String(r["text"])
	_ok(text.contains("sea mist: fog beyond the table") and text.contains("wisps: 5 pixies beyond the table") and text.contains("sparks: sparks on jumper"),
		"effects put were not reported as built:\n%s" % text)
	_ok(text.contains("a pixie is 1.5 to 8 mm"), "a mote's size outside its look's range was not reported:\n%s" % text)
	_ok(text.contains("rain: NOT BUILT") and text.contains("\"weather\" is not a kind of effect"), "an unknown kind was not reported:\n%s" % text)
	_ok(text.contains("lost: NOT BUILT") and text.contains("\"the ceiling\" is not a place in the air"), "an unknown place was not reported:\n%s" % text)
	_ok(text.contains("\"confetti\" is not a look of burst") and text.contains("\"the end\" is not a moment"), "an unknown look or moment was not reported:\n%s" % text)
	_ok(text.contains("flies: 3 flies over the cloth") and not text.contains("flies over the cloth, 5 mm, lit") and text.contains("a fly is a dark speck and carries no light"),
		"a fly was not reported unlit, or not counted as flies:\n%s" % text)
	r = await t.call_tool("put", {"effects": [{"name": "sea mist", "kind": "fog", "where": "low on the cloth", "density": 0.2}]})
	var fogs := 0
	for e in t.draft()["effects"]:
		fogs += 1 if String((e as Dictionary)["name"]) == "sea mist" else 0
	_ok(fogs == 1 and String(r["text"]).contains("sea mist: fog low on the cloth"), "an effect put again under its name was not replaced")
	r = await t.call_tool("remove", {"names": ["rain", "lost", "odd", "flies"]})
	_ok((t.draft()["effects"] as Array).size() == 3, "effects were not removed by name: %s" % str(t.draft()["effects"]))
	r = await t.call_tool("watch", {"name": "snow"})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("In its air: sea mist, wisps, sparks"), "watching an effect not there was not refused with what is: %s" % r)
	r = await t.call_tool("watch", {"name": "sparks"})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("cannot be watched") and (r.get("images", []) as Array).is_empty(),
		"watching with no renderer did not say so: %s" % r)
	await t.call_tool("put", {"things": [_candle("a pillar", 9.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	await t.call_tool("title", {"color": "#e9dcc0"})
	r = await t.call_tool("submit", {})
	var handed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED)))
	_ok(handed is Dictionary and ((handed as Dictionary).get("effects", []) as Array).size() == 3, "the air was not handed in with the table")
	_ok((CardTable.sanitize_table(handed, CardTable.sanitize_look({}))["effects"] as Array).size() == 3, "the air handed in does not build")
	t.release()
	return true


func _table_itself() -> bool:
	var ep := _episode()
	var t := _tools(ep)
	_ok(not t.draft().has("top") and not t.draft().has("layers"), "a draft with no table put carries none (the old table)")
	var r: Dictionary = await t.call_tool("put", {"top": {"shape": "round", "size": [60], "material": "oak", "edge": "ogee"},
		"materials": {"oak": {"kind": "wood", "color": "#8a6a3a"}},
		"layers": [{"name": "the cloth", "outline": "top", "drop": 20, "fabric": "linen", "pattern": {"kind": "checks"}},
			{"name": "a square", "outline": "rect", "size": [50, 50], "turn": 45, "pattern": {"kind": "painting"}}]})
	var text := String(r["text"])
	_ok(not bool(r.get("error", false)) and text.contains("a round top of oak") and text.contains("made") and text.contains("larger"),
		"a top put is said back, and that it was grown to hold the cards: %s" % text)
	_ok((t.draft()["layers"] as Array).size() == 2 and String((t.draft()["top"] as Dictionary)["shape"]) == "round", "the top and layers are in the draft")
	await t.call_tool("put", {"layers": [{"name": "a square", "outline": "rect", "size": [40, 40], "fabric": "velvet"}]})
	var layers: Array = t.draft()["layers"]
	_ok(layers.size() == 2 and String((layers[1] as Dictionary)["fabric"]) == "velvet", "a layer put again under its name replaces it")
	var gone: Dictionary = await t.call_tool("remove", {"names": ["the cloth"]})
	_ok(not bool(gone.get("error", false)) and (t.draft()["layers"] as Array).size() == 1, "a layer is taken off by name")
	await t.call_tool("put", {"layers": []})
	_ok(t.draft().has("layers") and (t.draft()["layers"] as Array).is_empty()
		and (CardTable.sanitize_table(t.draft(), {})["layers"] as Array).is_empty(), "`layers: []` is a bare top")
	var o: Dictionary = await t.call_tool("overhead", {})
	_ok(String(o["text"]).contains("cannot be stood") and (o.get("images", []) as Array).is_empty(), "overhead with no renderer says so and takes no picture")
	t.release()
	return true


func _light() -> bool:
	var ep := _episode()
	var t := _tools(ep)
	_ok(not t.draft().has("light"), "a draft with no light put carries one (no light is the lamp, as every table had)")
	var r: Dictionary = await t.call_tool("put", {"light": {"sky": {"color": "#b0c4d8", "strength": 0.6},
		"sun": {"look": "sun", "from": "back left", "height": 30},
		"through": [{"name": "the west window", "kind": "window", "panes": [3, 2]}, {"name": "a chandelier", "kind": "chandelier"}],
		"clouds": {"cover": 0.4, "size": 0.3, "speed": 0.7},
		"birds": {"look": "gull", "every": 30},
		"lamps": [{"name": "a torch", "look": "torch", "from": "left"}, {"name": "the lantern", "look": "lantern", "from": "back", "distance": 60, "height": 5}]}})
	var text := String(r["text"])
	_ok(not bool(r.get("error", false)) and text.contains("The light: the sun from the back left, 30 degrees up through the west window"),
		"a light put was not said back:\n%s" % text)
	_ok(text.contains("\"chandelier\" is not something the sun falls through"), "a screen the builder does not know was not reported:\n%s" % text)
	_ok(text.contains("The sun reaches") and text.contains("of where the cards lie"), "where the sun falls was not reported:\n%s" % text)
	_ok(text.contains("Clouds: the sun is behind cloud") and text.contains("Birds: "), "the weather was not reported:\n%s" % text)
	_ok(text.contains("\"the lantern\" would be seen where it was put: moved up out of the shot"), "a lamp in the shot was not reported moved:\n%s" % text)
	# PART BY PART
	await t.call_tool("put", {"light": {"sun": {"look": "sun", "from": "right", "height": 50}}})
	var l: Dictionary = t.draft()["light"]
	_ok(float((Lights.sanitize(l)["sun"] as Dictionary)["from"]) == 90.0 and (l["through"] as Array).size() == 2 and l.has("clouds"),
		"a part put again does not replace that part alone: %s" % str(l))
	await t.call_tool("put", {"light": {"lamps": [{"name": "a torch", "look": "fire", "from": "left"}, {"name": "a sign", "look": "neon", "from": "back right"}]}})
	var lamps: Array = (t.draft()["light"] as Dictionary)["lamps"]
	_ok(lamps.size() == 3 and String((lamps[0] as Dictionary)["look"]) == "fire", "lamps are not put by name: %s" % str(lamps))
	await t.call_tool("put", {"light": {"clouds": null}})
	_ok(not (t.draft()["light"] as Dictionary).has("clouds"), "null does not take a part away")
	var gone: Dictionary = await t.call_tool("remove", {"names": ["birds", "the lantern"]})
	var after: Dictionary = t.draft()["light"]
	_ok(not bool(gone.get("error", false)) and not after.has("birds") and (after["lamps"] as Array).size() == 2, "parts of the light are not taken off by name: %s" % str(after))
	r = await t.call_tool("watch", {"name": "clouds"})
	_ok(bool(r.get("error", false)) and String(r["text"]).contains("In its light: a torch, a sign"), "watching clouds that are gone was not refused with what moves: %s" % r)
	r = await t.call_tool("watch", {"name": "a torch"})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("cannot be watched") and (r.get("images", []) as Array).is_empty(),
		"watching the light with no renderer did not say so: %s" % r)
	await t.call_tool("put", {"light": {"lamps": []}})
	_ok(((t.draft()["light"] as Dictionary)["lamps"] as Array).is_empty(), "`lamps: []` does not take them all away")
	# SHADOWS OUT OF THE SHOT: reported, put by name, taken off by name, watched by name
	r = await t.call_tool("put", {"light": {"shadows": [
		{"name": "the beam", "parts": [{"shape": "box", "size": [300, 15, 20]}], "shadow": [0, -10], "height": 200},
		{"name": "the rope", "parts": [{"shape": "tube", "path": [[0, 0, 0], [0, -100, 0]]}, {"shape": "kettle"}], "shadow": [-20, 0], "height": 140, "move": {"kind": "swing"}},
		{"name": "far off", "parts": [{"shape": "box", "size": [20, 20, 20]}], "shadow": [90, -60], "height": 30}]}})
	text = String(r["text"])
	_ok(text.contains("Shadows out of the shot:") and text.contains("\"the beam\" (still, the sun's): its shadow covers"), "a shadow out of the shot was not reported:\n%s" % text)
	_ok(text.contains("\"kettle\" is not a shape a shadow is made of"), "a shadow's unknown shape was not reported:\n%s" % text)
	await t.call_tool("put", {"light": {"shadows": [{"name": "the rope", "parts": [{"shape": "tube", "path": [[0, 0, 0], [0, -60, 0]]}], "move": {"kind": "flutter"}}]}})
	var shadows: Array = (t.draft()["light"] as Dictionary)["shadows"]
	_ok(shadows.size() == 3 and String(((shadows[1] as Dictionary)["move"] as Dictionary)["kind"]) == "flutter", "shadows are not put by name: %s" % str(shadows))
	r = await t.call_tool("watch", {"name": "the rope"})
	_ok(not bool(r.get("error", false)) and String(r["text"]).contains("cannot be watched"), "watching a shadow with no renderer did not say so: %s" % r)
	gone = await t.call_tool("remove", {"names": ["far off"]})
	_ok(not bool(gone.get("error", false)) and ((t.draft()["light"] as Dictionary)["shadows"] as Array).size() == 2, "a shadow is not taken off by name")
	# HANDED IN with the table, and built from it
	await t.call_tool("put", {"things": [_candle("a pillar", 9.0)], "materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	await t.call_tool("title", {"color": "#e9dcc0"})
	await t.call_tool("submit", {})
	var handed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ep.job_dir("table").path_join(SetDresserTools.SUBMITTED)))
	var built: Dictionary = CardTable.sanitize_table(handed if handed is Dictionary else {}, CardTable.sanitize_look({}))["light"]
	_ok(not built.is_empty() and float((built["sun"] as Dictionary)["from"]) == 90.0 and (built["through"] as Array).size() == 1,
		"the light was not handed in with the table, or does not build: %s" % str(built))
	# ALL OF IT taken off: the table is lit as every table was
	await t.call_tool("remove", {"names": ["light"]})
	_ok((CardTable.sanitize_table(t.draft(), CardTable.sanitize_look({}))["light"] as Dictionary).is_empty(), "removing \"light\" leaves a light")
	t.release()
	return true


func _one_at_a_time() -> bool:
	var ep := _episode()
	var tools := Slow.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	var a := {}
	var b := {}
	var run := func(n: String, into: Dictionary) -> void:
		into.merge(await tools.call_tool(n, {}))
	run.call("look", a)
	run.call("title", b)
	for i in 20:
		await process_frame
	_ok(tools.log == ["start look", "end look", "start title", "end title"], "two calls made together overlapped: %s" % [tools.log])
	# released mid-call: the call finishes, and the stages are given back after it
	tools.log.clear()
	var c := {}
	run.call("set", c)
	await process_frame
	tools.release()
	_ok(tools._busy, "the call was over before the release - the test proves nothing")
	_ok(tools._preview._studio == null and tools._preview._table == null, "the stages were built in a run with no renderer")
	for i in 10:
		await process_frame
	_ok(tools.log == ["start set", "end set"] and String(c.get("text", "")) == "set", "a call released part way did not finish: %s" % [tools.log])
	var after: Dictionary = await tools.call_tool("look", {})
	_ok(bool(after.get("error", false)) and tools.log.size() == 2, "a call after the release was not turned away")
	# control: straight into the work, the same two calls overlap
	var raw := Slow.new(ep, ep.read_json("plan"), ep.job_dir("table"))
	var noop := func(n: String) -> void:
		await raw._call(n, {})
	noop.call("look")
	noop.call("title")
	for i in 10:
		await process_frame
	_ok(raw.log[1] == "start title", "control: two calls straight into the work did not overlap: %s" % [raw.log])
	raw.release()
	return true


## The frame's verdict on what [method TablePreview.table] stood ([method SetDresserTools.stood_lines],
## [method SetDresserTools.judge_of]).
func _verdict() -> bool:
	var thing := func(name: String, k: float) -> Dictionary:
		return {"name": name, "place": "back left", "at": Vector2(-16.0, -23.0), "k": k, "tall": 0.25}
	# all in the shot, two shown smaller (as far as the table shrinks a thing): SET
	var st := SetDresserTools.stood_lines({"stood": [thing.call("a candle", 1.0), thing.call("an aloe", 0.88),
		thing.call("a mug", 0.76)], "left_off": []})
	var text := "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 0, "a thing made smaller to fit counts as a fault: %s" % text)
	_ok(text.contains("an aloe (back left): 16 cm left of the middle, 23 cm back; 25% of the picture's height - shown at 88% of its size, to fit (as it may be)")
		and text.contains("shown at 76%") and not text.contains("a candle (back left): 16 cm left of the middle, 23 cm back; 25% of the picture's height -"),
		"a thing made smaller is not said at its size, or one at full size is: %s" % text)
	var judge := SetDresserTools.judge_of(int(st["faults"]), false)
	_ok(judge.contains("the table is set") and judge.contains("choose the title's color") and judge.contains("submit"),
		"a table with everything in the shot is not told it is set: %s" % judge)
	judge = SetDresserTools.judge_of(int(st["faults"]), true)
	_ok(judge.contains("the table is set") and judge.contains("submit it") and not judge.contains("choose the title's color"),
		"a set table whose title is chosen is not told only to submit: %s" % judge)
	# THE CONTROL: a thing left off is a fault, and the table is sent to be fixed
	st = SetDresserTools.stood_lines({"stood": [thing.call("a candle", 1.0)], "left_off": ["an aloe"]})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 1 and text.contains("an aloe: LEFT OFF"), "a thing left off is not a fault: %s" % text)
	_ok(SetDresserTools.judge_of(int(st["faults"]), true) == SetDresserTools.JUDGE_TABLE, "a table with a thing left off is told it is set")
	return true


## A THING WRITTEN WHERE IT STANDS, as the frame's verdict says it ([method SetDresserTools.stood_lines]).
func _verdict_written() -> bool:
	var w := {"name": "a bell", "place": "back", "at": Vector2(-30.0, -26.0), "k": 1.0, "tall": 0.2, "written": Vector2(-30.0, -26.0),
		"moved": 0.0, "why": "", "foot": Vector2(6.0, 6.0), "height": 9.0, "room": 14.0, "shown": 1.0}
	var st := SetDresserTools.stood_lines({"stood": [w], "left_off": []}, {"a bell": 3})
	var text := "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 0 and text == "- 3. a bell: at [-30, -26]; 20% of the picture's height", "a thing standing where it was written is not said plainly: %s" % text)
	var moved := w.duplicate()
	moved["written"] = Vector2(-30.0, -20.0)
	moved["moved"] = 6.0
	moved["why"] = "it stood where the cards go"
	st = SetDresserTools.stood_lines({"stood": [moved], "left_off": []}, {"a bell": 3})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 1 and text.contains("MOVED 6 cm from where it was written, [-30, -20]: it stood where the cards go"),
		"a thing moved from where it was written is not a fault, or not said why: %s" % text)
	var tall := w.duplicate()
	tall["height"] = 20.0
	st = SetDresserTools.stood_lines({"stood": [tall], "left_off": []})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 1 and text.contains("20 cm tall where the frame shows 14 cm: its top is cut off"), "a thing taller than its spot is not a fault: %s" % text)
	var cut := w.duplicate()
	cut["shown"] = 0.6
	cut["k"] = 0.5
	st = SetDresserTools.stood_lines({"stood": [cut], "left_off": []})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 0 and text.contains("only 60% of it is in the shot") and not text.contains("to fit"),
		"a thing the frame's side cuts is a fault, or a thing written smaller is said shrunk to fit: %s" % text)
	var gone := w.duplicate()
	gone["shown"] = 0.0
	st = SetDresserTools.stood_lines({"stood": [gone], "left_off": []})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 1 and text.contains("NOT IN THE SHOT"), "a thing out of the shot altogether is not a fault: %s" % text)
	st = SetDresserTools.stood_lines({"stood": [], "left_off": ["a jar"], "left_why": {"a jar": "it stood where the cards go"}}, {"a jar": 2})
	text = "\n".join(st["lines"] as PackedStringArray)
	_ok(int(st["faults"]) == 1 and text.contains("2. a jar: LEFT OFF - nowhere within %d cm of where it was written" % roundi(CardTable.NUDGE_MOST * 100.0))
		and text.contains("(it stood where the cards go)"), "a written thing left off is not said with its reason: %s" % text)
	return true


## THE BLUEPRINT TOOL, with no renderer: placing by name, what it refuses, a place kept through a put, the
## pictures' draft, and the plan in words.
func _blueprint() -> bool:
	if not await _verdict_written():
		return false
	var ep := _episode()
	var t := _tools(ep)
	await t.call_tool("put", {"things": [_candle("a pillar", 9.0),
		{"name": "a bowl", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [6, 3], [5.6, 3], [2.6, 0.4], [0, 0.4]], "material": "beeswax"}]},
		{"name": "a rope", "parts": [{"shape": "strand", "lay": "drape", "path": [[-40, 0, -30], [-60, 0, -20]], "radius": 0.6, "material": "beeswax"}]}],
		"materials": {"beeswax": {"kind": "wax", "color": "#e8d9a8"}}})
	_ok(t._unplaced() == PackedStringArray(["a bowl"]), "the things waiting to be placed are %s" % str(t._unplaced()))
	_ok((t.draft()["things"] as Array).size() == 3 and (t._on_table()["things"] as Array).size() == 2,
		"a thing not yet placed is on the pictures' table, or the draft lost it (control): %d, %d" % [(t.draft()["things"] as Array).size(),
		(t._on_table()["things"] as Array).size()])
	var looks := t.looks_used()
	var r: Dictionary = await t.call_tool("blueprint", {"things": [{"name": "a bowl", "at": [25, -20], "turn": 30},
		{"name": "a ghost", "at": [0, 0]}, {"name": "a rope", "at": [5, 5]}, {"name": "a pillar", "at": "left", "scale": "big"}]})
	var text := String(r["text"])
	_ok(text.contains("Placed: a bowl, a pillar.") and text.contains("nothing called \"a ghost\" has been put")
		and text.contains("\"a rope\" lies where its path is written - not placed") and text.contains("\"a pillar\": `at` is two numbers")
		and text.contains("\"a pillar\": `scale` is a number"), "the blueprint did not say what it placed and refused:\n%s" % text)
	var bowl: Dictionary = t.draft()["things"][1]
	var pillar: Dictionary = t.draft()["things"][0]
	_ok(bowl.get("at") == [25.0, -20.0] and float(bowl.get("turn", 0)) == 30.0 and pillar.get("at") == [-30.0, -26.0] and not pillar.has("scale"),
		"the blueprint placed the wrong things: %s, %s" % [str(bowl), str(pillar)])
	_ok(text.contains("2. a bowl: at [25, -20], turned 30; its spot shows") and text.contains("1. a pillar: at [-30, -26]")
		and text.contains("3. a rope: lies where its path is written") and text.contains("(No drawing: no renderer.)") and (r.get("images", []) as Array).is_empty()
		and t.looks_used() == looks, "the plan was not said in words without a picture:\n%s" % text)
	# A THING MADE AGAIN KEEPS ITS PLACE - unless it is given one (control)
	await t.call_tool("put", {"things": [{"name": "a bowl", "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [7, 3], [0, 3]], "material": "beeswax"}]}]})
	bowl = t.draft()["things"][1]
	_ok(bowl.get("at") == [25.0, -20.0] and float(bowl.get("turn", 0)) == 30.0, "a thing put again lost its place: %s" % str(bowl))
	await t.call_tool("put", {"things": [{"name": "a bowl", "at": [5, -10], "parts": [{"shape": "lathe", "profile": [[0, 0], [4, 0], [7, 3], [0, 3]], "material": "beeswax"}]}]})
	_ok((t.draft()["things"][1] as Dictionary).get("at") == [5, -10], "control: a thing put again with a place did not move: %s" % str(t.draft()["things"][1]))
	_ok(t._unplaced().is_empty() and (t._on_table()["things"] as Array).size() == 3, "a placed thing is still waiting: %s" % str(t._unplaced()))
	# THE TABLE MADE SAFE keeps a written place, and drops one that is not two numbers
	var safe := CardTable.sanitize_table({"things": [{"name": "a", "at": [12, -400], "scale": 9, "parts": [{"shape": "ball", "size": [2, 2, 2]}]},
		{"name": "b", "at": [1], "parts": [{"shape": "ball", "size": [2, 2, 2]}]},
		{"name": "c", "at": [1, 2, 3], "parts": [{"shape": "ball", "size": [2, 2, 2]}]}]}, {})
	_ok((safe["things"][0] as Dictionary).get("at") == [12.0, -CardTable.AT_MOST] and float((safe["things"][0] as Dictionary)["scale"]) == CardTable.SCALE_RANGE.y
		and not (safe["things"][1] as Dictionary).has("at") and not (safe["things"][2] as Dictionary).has("at"),
		"a written place was not made safe, or a part's three numbers were taken for one: %s" % str(safe["things"]))
	t.release()
	return true


## WHERE EVERYTHING FALLS ON THE BLUEPRINT ([TableBlueprint]), worked out with no renderer.
func _drawing() -> bool:
	for seed in [7, 5150, 15853]:
		var lay := CardTable.layout_of(seed)
		var cam: Transform3D = lay["camera"]
		var fov := float(lay["fov"])
		# THE HEADROOM, closed form, against the frame walked up 5 mm at a time - and a wider lens, which must disagree
		var head := CardTable.headroom(seed)
		var worst := 0.0
		var wide := 0.0
		for z in CardTable.ZONES:
			# the walk stops at 60 cm
			if float(head[z]) >= 59.0:
				continue
			var aim := CardTable.zone_aim(String(z), lay["deck"])
			worst = maxf(worst, absf(CardTable.headroom_at(cam, fov, aim) * 100.0 - float(head[z])))
			wide = maxf(wide, absf(CardTable.headroom_at(cam, fov + 10.0, aim) * 100.0 - float(head[z])))
		_ok(worst <= 1.01, "#%d: the blueprint's headroom is %.1f cm off the frame's" % [seed, worst])
		_ok(wide > 2.0, "#%d: control: a lens 10 degrees wider agrees with the frame (%.1f cm) - the comparison proves nothing" % [seed, wide])
		# EACH HEIGHT'S LINE: that height at its ends; a thing that tall seen whole nearer the reader, cut behind
		var area := Rect2(-0.6, -0.55, 1.2, 0.8)
		for h in TableBlueprint.HEIGHTS:
			var seg := TableBlueprint.height_line(cam, fov, float(h) * 0.01, area)
			if seg.size() < 2:
				continue
			var ends := absf(CardTable.headroom_at(cam, fov, seg[0]) - float(h) * 0.01) + absf(CardTable.headroom_at(cam, fov, seg[1]) - float(h) * 0.01)
			var mid := (seg[0] + seg[1]) * 0.5
			var near := CardTable.headroom_at(cam, fov, mid + Vector2(0.0, 0.03))
			var far := CardTable.headroom_at(cam, fov, mid - Vector2(0.0, 0.03))
			_ok(ends < 0.001 and near > float(h) * 0.01 and far < float(h) * 0.01,
				"#%d: the %d cm line does not hold %d cm (ends off by %.4f m; %.3f nearer, %.3f behind)" % [seed, h, h, ends, near, far])
			# what the frame itself shows there: a thing that tall stands whole just nearer, cut just behind
			var top_near: Variant = CardTable.project(cam, fov, Vector3(mid.x, float(h) * 0.01 + 0.01, mid.y + 0.03))
			var top_far: Variant = CardTable.project(cam, fov, Vector3(mid.x, float(h) * 0.01 + 0.01, mid.y - 0.03))
			_ok(top_near != null and (top_near as Vector2).y > 0.03 and top_far != null and (top_far as Vector2).y < 0.03,
				"#%d: the frame does not cut a %d cm thing where its line says" % [seed, h])
		# THE FRAME ON THE TABLE: its near edge is where the frame's bottom meets the cloth
		var seen := TableBlueprint.seen(cam, fov)
		var bottom: Vector2 = seen[80 + 20]
		var sp: Variant = CardTable.project(cam, fov, Vector3(bottom.x, 0.0, bottom.y))
		_ok(seen.size() == 160 and sp != null and absf((sp as Vector2).y - 1.0) < 0.002, "#%d: the frame on the table is not the frame's edge: %s" % [seed, str(sp)])
	# AN OUTLINE drawn round a top is the top's size
	var rect := TableBlueprint._bounds(TableBlueprint.outline(Tables.top_outline({"shape": "rect", "size": [120, 80]})))
	var round := TableBlueprint._bounds(TableBlueprint.outline(Tables.top_outline({"shape": "round", "size": [146, 146]})))
	_ok(absf(rect.size.x - 1.2) < 0.005 and absf(rect.size.y - 0.8) < 0.005 and absf(round.size.x - 1.46) < 0.01,
		"an outline drawn round a top is not its size: %s, %s" % [rect, round])
	# THE PLAN FITS every card and thing in the drawing
	var lay := CardTable.layout_of(5150)
	var d := {"camera": lay["camera"], "fov": lay["fov"], "top": Tables.top_outline({"shape": "rect", "size": [190, 85]}),
		"cards": [{"pos": Vector2(-0.1, -0.05), "yaw": 0.3}, {"pos": Vector2(0.1, -0.05), "yaw": 0.0}],
		"things": [{"bb": Rect2(-0.62, -0.4, 0.08, 0.06)}, {"bb": Rect2(0.5, -0.1, 0.1, 0.1)}]}
	var v := TableBlueprint.view(d)
	var room: Rect2 = v["room"]
	var fits := true
	for p in [Vector2(-0.62, -0.4), Vector2(0.6, 0.0), Vector2(-0.1, -0.05), Tables.ORIGIN]:
		fits = fits and room.grow(0.5).has_point(TableBlueprint._to_px(v, p))
	_ok(fits and float(v["scale"]) > 300.0, "the plan does not fit the table in the drawing: %s" % str(v))
	_ok(absf(_area(TableBlueprint.card_outline(Vector2.ZERO, 0.7, Vector2(0.07, 0.12))) - 0.0084) < 1e-6, "a card on the blueprint is not a card's size")
	return true


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(a) * 0.5


## HOW FULL A TABLE IS: a few things to a crowded table, drawn per episode.
func _fills() -> bool:
	var most := 0
	var least := 99
	var over := 0
	var n := 400
	for seed in n:
		var size := CardPrompts.table_size(seed)
		most = maxi(most, size.y)
		least = mini(least, size.x)
		over += 1 if size.y > 6 else 0
		_ok(size.x >= 3 and size.y > size.x and size.y + CardTable.MAX_CANDLES <= CardTable.MAX_THINGS, "#%d asks for %s things" % [seed, str(size)])
	_ok(least == 3 and most >= 20 and over > n * 0.5 and over < n * 0.95,
		"the tables run from %d to %d things, %d of %d past the old most (6)" % [least, most, over, n])
	return true

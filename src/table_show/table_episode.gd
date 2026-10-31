extends RefCounted
class_name TableEpisode

## TableEpisode - one episode of a card show, as it lies on disk.
##
## An episode is everything one seed of a show produced: the plan (title, spread, look), the
## shuffle, each drawn card's design and booklet entry, the pictures, the reader's words and the
## script they make. EVERY STEP IS A FILE under `user://table/<show>/<seed>/`, written the
## moment it is made, so:
##
##   - re-running a seed re-uses what it produced - the same reading, the same pictures, every
##     time - and nothing is made twice by accident (it costs the author's quota);
##   - a step that failed, or a ghost that quit half way, picks up where it stopped;
##   - REDOING A STEP IS DELETING IT: [method invalidate] removes the step and everything made
##     from it, and the producer makes whatever is missing. There is no other kind of reroll.
##
## The job directories under `jobs/` keep every prompt exactly as sent, beside the reply - the
## record that the reader was never shown a card before it was drawn.

const ROOT := "user://table"
const YouTube := preload("res://src/export/youtube.gd")

## Where shows live. Moved aside under test, so a gate never touches the author's episodes.
static var root := ROOT
## How a deleted episode's folder is thrown away, when set: the gate's seam, so a check never
## fills the author's trash. Unset, it goes to the system's trash ([method trash]).
static var discard: Callable = Callable()

var show := ""
var seed := 0
## Absolute.
var dir := ""
var _script_cache := {}
var _cards_stamp := "-"           # the plan and draw files the printings and waterfalls were last read from
var _printing_keys: Array = []      # per drawn card: its printing's file key, "" the deck's own
var _swept: Array = []              # per spread position: swept out in a waterfall
var _written: Array = []            # per drawn card: a written card, nothing painted for it ([method written_card])
var _height_stamp := "-"          # the table file the height map's wanting was last read from
var _height_wanted := false


static func open(show_key: String, seed_value: int) -> TableEpisode:
	var e := TableEpisode.new()
	e.show = show_key
	e.seed = seed_value
	e.dir = ProjectSettings.globalize_path(root.path_join(show_key).path_join(str(seed_value)))
	return e


## Every seed of [param show_key] with at least a plan, newest first: `[{seed, plan, at}]`.
static func history(show_key: String) -> Array:
	var base := ProjectSettings.globalize_path(root.path_join(show_key))
	var out: Array = []
	if not DirAccess.dir_exists_absolute(base):
		return out
	for d in DirAccess.get_directories_at(base):
		if not String(d).is_valid_int():
			continue
		var p := base.path_join(d).path_join("plan.json")
		if not FileAccess.file_exists(p):
			continue
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
			continue
		out.append({"seed": int(d), "plan": j.data, "at": FileAccess.get_modified_time(p)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out


## WHAT THE SHOW HAS ALREADY MADE, for a later episode's agents to go somewhere else (see
## [TablePrompts]): every other episode of [param show_key] with a plan, newest first, at most
## [param most] - `{seed, plan, cards: [{name, reversed, jumper, art, said}], beats: [{name, said}], things,
## air, furniture, light, intro, close}`: the cards it drew, what each pictured and what the reader said as
## it turned over (or, in a show that draws none, each beat's name and its words), the things on its table, its air, the table itself ([method Tables.summary], "" for the old board
## table) and its light ([method Lights.summary], "" for the lamp every table had), and its first and
## last passages. What an episode has not made is empty.
static func archive(show_key: String, except: int, most := 40) -> Array:
	var out: Array = []
	for h in history(show_key):
		var s := int((h as Dictionary)["seed"])
		if s == except:
			continue
		if out.size() >= most:
			break
		var ep := open(show_key, s)
		var cards: Array = []
		var draw: Variant = ep.read_json("draw")
		var drawn: Array = []
		if draw is Dictionary and (draw as Dictionary).get("cards") is Array:
			drawn = (draw as Dictionary)["cards"]
		for i in drawn.size():
			var c: Dictionary = drawn[i] if drawn[i] is Dictionary else {}
			var design: Variant = ep.read_json("design:%d" % (i + 1))
			cards.append({"name": str(c.get("name", "")), "reversed": bool(c.get("reversed", false)),
				"jumper": bool(c.get("jumper", false)),
				"art": str((design as Dictionary).get("art", "")) if design is Dictionary else "",
				"said": ep.read_text("say:%d" % (i + 1))})
		# A SHOW WITH NO CARDS: each beat, and what was said in it
		var beats: Array = []
		if ep.cardless():
			var plan_d: Dictionary = (h as Dictionary)["plan"]
			var pos: Array = ((plan_d.get("spread", {}) as Dictionary).get("positions", []) as Array) if plan_d.get("spread") is Dictionary else []
			for i in pos.size():
				beats.append({"name": str((pos[i] as Dictionary).get("name", "")) if pos[i] is Dictionary else "", "said": ep.read_text("say:%d" % (i + 1))})
		var things: Array = []
		var table: Variant = ep.read_json("table")
		if table is Dictionary and (table as Dictionary).get("things") is Array:
			for th in (table as Dictionary)["things"]:
				var name := str((th as Dictionary).get("name", "")).strip_edges() if th is Dictionary else ""
				if not name.is_empty():
					things.append(name)
		# ITS AIR, each effect as what it was: a name and its look (or its kind, for fog)
		var air: Array = []
		if table is Dictionary and (table as Dictionary).get("effects") is Array:
			for fx in (table as Dictionary)["effects"]:
				if fx is Dictionary:
					var d: Dictionary = fx
					air.append("%s (%s)" % [str(d.get("name", "")).strip_edges(), str(d.get("look", d.get("kind", ""))).strip_edges()])
		# THE TABLE ITSELF, in a line - only one the set dresser built: the old board table is no habit
		var furniture := ""
		if table is Dictionary and ((table as Dictionary).has("top") or (table as Dictionary).has("layers")):
			var td: Dictionary = table
			furniture = Tables.summary(Tables.sanitize(td.get("top"), td.get("layers"),
				Props.sanitize(td, [])["materials"], []))
		# ITS LIGHT, in a line - only one the set dresser wrote
		var light := ""
		if table is Dictionary and (table as Dictionary).get("light") is Dictionary:
			light = Lights.summary(Lights.sanitize((table as Dictionary)["light"]))
		out.append({"seed": s, "plan": (h as Dictionary)["plan"], "cards": cards, "beats": beats, "things": things, "air": air, "furniture": furniture,
			"light": light, "intro": ep.read_text("say:intro"), "close": ep.read_text("say:close")})
	return out


# --- files -----------------------------------------------------------------------------

## The file a step is kept in (see [method steps] for the keys).
func file_of(step: String) -> String:
	var parts := step.split(":")
	match String(parts[0]):
		"plan":
			return dir.path_join("plan.json")
		"draw":
			return dir.path_join("draw.json")
		"design":
			return dir.path_join("design_%s.json" % parts[1])
		"check":
			return dir.path_join("check_%s.json" % parts[1])
		"image":
			if parts.size() == 3:
				return dir.path_join("%s_%s.png" % [parts[1], parts[2]])     # card_K
			return dir.path_join("%s.png" % parts[1])
		"say":
			# a card's work passage is `say:work:K` (next/table_work.md)
			return dir.path_join("say_%s.txt" % ("_".join(parts.slice(1)) if parts.size() > 2 else parts[1]))
		"acts":
			return dir.path_join("acts.json")
		"script":
			return dir.path_join("script.md")
		"table":
			return dir.path_join("table.json")
		"meta":
			return dir.path_join("meta.json")
		"upload":
			return dir.path_join("upload.md")
		"youtube":
			return dir.path_join("youtube.json")
		"layout":
			return dir.path_join(DealerTools.LAYOUT)
	return ""


## A step exists when its file does: every write lands by rename (here, and the painter's
## pictures in [AgentJobs]), so a file that is there is whole - and asking costs no read.
func has(step: String) -> bool:
	var p := file_of(step)
	return not p.is_empty() and FileAccess.file_exists(p)


## The directory a step's agent job runs in - kept, with its prompt.
func job_dir(step: String) -> String:
	return dir.path_join("jobs").path_join(step.replace(":", "_"))


func read_json(step: String) -> Variant:
	var raw := FileAccess.get_file_as_string(file_of(step))
	if raw.is_empty():
		return null
	var j := JSON.new()
	return j.data if j.parse(raw) == OK else null


func read_text(step: String) -> String:
	return FileAccess.get_file_as_string(file_of(step))


## Written ATOMICALLY - a file that exists is a step that is done, so a half-written one must
## never be seen: temp beside it, then renamed over.
func write_text(step: String, text: String) -> String:
	var p := file_of(step)
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


# --- the steps -------------------------------------------------------------------------

## How many cards the episode draws: the shuffle's, once made; else the plan's spread - none in a show that
## draws no cards ([method cardless]).
func card_count() -> int:
	var d: Variant = read_json("draw")
	if d is Dictionary:
		return ((d as Dictionary).get("cards", []) as Array).size()
	var p: Variant = read_json("plan")
	if p is Dictionary:
		return 0 if CardTable.cardless(p as Dictionary) else CardTable.beats(p as Dictionary)
	return 0


## WHETHER THE EPISODE DRAWS NO CARDS (the user, 2026-10-26: "that card dependency shouldn't exist"): its plan
## says so ([method CardTable.cardless]) - the episode is beats of words and work at the table, each beat
## a passage of its own (`say:K`) said while its work is done.
func cardless() -> bool:
	var p: Variant = read_json("plan")
	return p is Dictionary and CardTable.cardless(p as Dictionary)


## WHAT ONE BEAT OF THE EPISODE IS CALLED on its rows (2026-10-26: "Card" rows on an alchemy show): the
## producer's word for one in its plan (`beat_word`: an Ingredient, a Coat), else a Card where cards are drawn
## and a Beat where none are.
func beat_word() -> String:
	var p: Variant = read_json("plan")
	var w := String((p as Dictionary).get("beat_word", "")) if p is Dictionary else ""
	return w if not w.is_empty() else ("Beat" if p is Dictionary and CardTable.cardless(p as Dictionary) else "Card")


## How many beats the reading has between its intro and its close: a card's each - or, in a show that draws
## none, its plan's ([method CardTable.beats]).
func beat_count() -> int:
	var p: Variant = read_json("plan")
	return CardTable.beats(p as Dictionary) if p is Dictionary and CardTable.cardless(p as Dictionary) else card_count()


## EVERY STEP, in the order it is made: `plan`, `draw`, `design:K`, `image:back`,
## `image:surface`, `image:backdrop`, `table`, `image:height`, `image:card:K` and `check:K`,
## `say:intro`, `say:K`, `say:close`, `script`. Card steps exist only once the plan says how many
## cards there are; the painting's height map only once the table lays the painting where it would be
## read ([method wants_height]). A CARD ALREADY READ NEEDS NO CHECK: an episode read before paintings
## were checked (2026-10-17) keeps its pictures and its words, so `check:K` is a step only where its
## file is, or card K has not been read yet.
##
## A WRITTEN CARD ([method written_card]) is its writing: no painting and no check.
##
## A SHOW THAT DRAWS NO CARDS ([method cardless]) has none of a card's steps - no design, no back, no
## painting, no check - and no work passage of a card's: each beat's passage `say:K` is said while its work
## is done.
func steps() -> Array:
	var out := ["plan", "draw"]
	if cardless():
		out.append_array(["image:surface", "image:backdrop", "table"])
		if wants_height():
			out.append("image:height")
		if not work_plan().is_empty():
			out.append("acts")
		out.append("say:intro")
		for k in range(1, beat_count() + 1):
			out.append("say:%d" % k)
		out.append_array(["say:close", "script"])
		return out
	var n := card_count()
	for k in range(1, n + 1):
		out.append("design:%d" % k)
	out.append("image:back")
	# A BACK PER PRINTING the drawn cards are in, beside the deck's own (CardTable.look_of)
	for key in printings():
		out.append("image:back:%s" % key)
	out.append_array(["image:surface", "image:backdrop", "table"])
	if wants_height():
		out.append("image:height")
	# THE WORK AT THE TABLE, where the plan has any (next/table_work.md): the puppeteer blocks it once the
	# table is set and the cards are drawn
	var works := work_plan()
	if not works.is_empty():
		out.append("acts")
	for k in range(1, n + 1):
		if written_card(k):
			continue
		out.append("image:card:%d" % k)
		if checks(k):
			out.append("check:%d" % k)
	out.append("say:intro")
	for k in range(1, n + 1):
		out.append("say:%d" % k)
		# ...and the words said while a card's work is done, after its own
		if works.has(str(k)):
			out.append("say:work:%d" % k)
	out.append_array(["say:close", "script"])
	return out


## WHAT THE PLAN HAS DONE AT THE TABLE (next/table_work.md): beat ("intro", "close", or a card's place) ->
## the work, in the producer's words - empty for a plan with none, as every plan before the work was.
func work_plan() -> Dictionary:
	var p: Variant = read_json("plan")
	if not (p is Dictionary):
		return {}
	return work_of(p as Dictionary)


## [param plan]'s work, as [method work_plan] gives it ([method CardTable.work_of]: the table reads it too).
static func work_of(plan: Dictionary) -> Dictionary:
	return CardTable.work_of(plan)


## The passage read just before card [param k]'s (the intro, or the last of the card before it: its work's,
## when it had work - a beat of a show with no cards has no passage but its own).
func _before(k: int, works: Dictionary) -> String:
	if k <= 1:
		return "say:intro"
	return "say:work:%d" % (k - 1) if works.has(str(k - 1)) and not cardless() else "say:%d" % (k - 1)


## Whether card [param k]'s painting is checked: a step where its check is, or the card is not read yet
## (see [method steps]).
func checks(k: int) -> bool:
	return has("check:%d" % k) or not has("say:%d" % k)


## What [param step] is made FROM - the steps that must exist before it can be.
func needs(step: String) -> Array:
	var parts := step.split(":")
	var n := card_count()
	match String(parts[0]):
		"plan":
			return []
		"draw":
			return ["plan"]
		"design":
			# ONE AFTER ANOTHER: a card's designer is shown the cards designed before it in this draw,
			# so it pictures its own otherwise (see TableProducer._make_design)
			var k := int(parts[1])
			return ["draw"] if k <= 1 else ["draw", "design:%d" % (k - 1)]
		"check":
			# the art director looks at a card's painting as it is described and printed
			var k := int(parts[1])
			return ["design:%d" % k, "image:card:%d" % k]
		"image":
			if parts.size() == 3 and String(parts[1]) == "card":
				# a card's picture is painted in the deck's hand: after its printing's back, and after the
				# card before it (they are sent to it as references - see TableProducer)
				var k := int(parts[2])
				var key := printing_of(k)
				var out := ["design:%d" % k, "image:back" if key.is_empty() else "image:back:%s" % key]
				# ...the last card before it painted at all: a written one is not
				var j := k - 1
				while j >= 1 and written_card(j):
					j -= 1
				if j >= 1:
					out.append("image:card:%d" % j)
				return out
			if parts.size() == 3 and String(parts[1]) == "back":
				# a printing's back waits for the shuffle, which says which printings are drawn
				return ["draw"]
			if String(parts[1]) == "height":
				# the painting's depth is painted FROM the painting, once the table says it is wanted
				return ["image:surface", "table"]
			return ["plan"]
		"say":
			var who := String(parts[1])
			var works := work_plan()
			if who == "intro":
				return ["draw", "acts"] if works.has("intro") else ["draw"]
			# A BEAT OF A SHOW WITH NO CARDS is said while its work is done: after the passage before it, knowing
			# its acts
			var bare := cardless()
			if bare:
				n = beat_count()
			if who == "close":
				var last := ["say:%d" % n] if n > 0 else ["say:intro"]
				if n > 0 and works.has(str(n)) and not bare:
					last = ["say:work:%d" % n]
				return last + (["acts"] if works.has("close") else [])
			if bare:
				var k := int(who)
				return [_before(k, works)] + (["acts"] if works.has(str(k)) else [])
			# THE WORDS SAID WHILE A CARD'S WORK IS DONE are written knowing the work: after the card's own
			if who == "work":
				return ["say:%s" % String(parts[2]), "acts"]
			# a card's passage is written LOOKING AT the card: it waits for its picture, checked, and a
			# card painted again is a passage written again (see TableProducer.say_prompt)
			var k := int(who)
			var out := ["design:%d" % k, _before(k, works)] if written_card(k) else ["design:%d" % k, "image:card:%d" % k, "check:%d" % k, _before(k, works)]
			# a card swept out in a waterfall is read with the cards that came out with it: their entries too
			for j in range(k + 1, reveal_of(k) + 1):
				out.append("design:%d" % j)
			return out
		"script":
			return ["say:close"]
		"table":
			# the table is set from the plan, LOOKING AT the cloth it stands on - and at the room, which
			# its light must agree with (where the windows are, which side the sun comes from)
			return ["plan", "image:surface", "image:backdrop"]
		"acts":
			# the work is blocked on the table as it is set, with the cards as they were drawn (the work is
			# made of them: an ingredient fetched and ground) - no reader sees past its own beat's - and, where
			# a card is WRITTEN, what is written on it (a recipe's steps are the work)
			var out := ["plan", "draw", "table"]
			var p: Variant = read_json("plan")
			if p is Dictionary and (p as Dictionary).get("look") is Dictionary and CardTable.written((p as Dictionary)["look"]):
				for k in range(1, n + 1):
					out.append("design:%d" % k)
			return out
	return []


## Everything made from [param step], directly or through another step. A card's picture is NOT
## made from the card before it in this sense - it is only shown it - so redoing one picture
## leaves the rest of the deck alone (the [Illustrations] rule: the chain is not the signature).
func dependents(step: String) -> Array:
	var out: Array = []
	var frontier := [step]
	while not frontier.is_empty():
		var s := String(frontier.pop_front())
		for t in steps():
			var ts := String(t)
			if out.has(ts) or ts == step:
				continue
			if _soft(s, ts):
				continue
			if needs(ts).has(s):
				out.append(ts)
				frontier.append(ts)
	return out


## The edges [method needs] lists only for ORDER: a card's picture waits for the back and for
## the card before it, because it is sent them as references, but it is not made from them; a card's
## design waits for the one before it, which it is shown, and is not made from it either; and
## the table waits for the cloth and the room to look at, but a new cloth or room keeps the table.
static func _soft(from: String, to: String) -> bool:
	return (to.begins_with("image:card:") and (from.begins_with("image:card:") or from.begins_with("image:back"))) \
		or (to.begins_with("design:") and from.begins_with("design:")) \
		or (to == "table" and (from == "image:surface" or from == "image:backdrop")) \
		or (to == "image:height" and from == "table")


## REDO [param step]: delete it and everything made from it. Returns what went. A card painted or
## designed again starts with nothing sent back ([method sent_back]) - but [param keep_sent] keeps it,
## for the art director's own send-back, which the painter is told of.
func invalidate(step: String, keep_sent := false) -> Array:
	var gone := [step] + dependents(step)
	# the plan decides how many cards there are: going back to it takes every card step with it,
	# including ones a smaller spread no longer lists
	if (step == "plan" or step == "draw") and DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			var fs := String(f)
			if fs.begins_with("design_") or fs.begins_with("card_") or fs.begins_with("say_") \
					or fs.begins_with("check_") or fs.begins_with("sent_back_") \
					or fs == "script.md" or fs == "acts.json" or (step == "plan" and (fs in ["draw.json", "back.png", "surface.png",
					"backdrop.png", "height.png", "height.json"] or fs.begins_with("back_"))):
				DirAccess.remove_absolute(dir.path_join(fs))
	for s in gone:
		var p := file_of(String(s))
		if not p.is_empty() and FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		# the height map's fit goes with it
		if String(s) == "image:height" and FileAccess.file_exists(dir.path_join("height.json")):
			DirAccess.remove_absolute(dir.path_join("height.json"))
		var card := String(s).trim_prefix("image:card:").trim_prefix("design:")
		if not keep_sent and card != String(s) and card.is_valid_int():
			DirAccess.remove_absolute(_sent_back_file(int(card)))
	return gone


## WHAT THE ART DIRECTOR SENT BACK of card [param k]'s paintings so far, a list of faults per
## painting sent back, oldest first - kept beside the episode, not a step: the painting it was said of
## is gone, and the painter of the next is told it ([method TableProducer._make_image]).
func sent_back(k: int) -> Array:
	var raw := FileAccess.get_file_as_string(_sent_back_file(k))
	var j := JSON.new()
	return j.data if not raw.is_empty() and j.parse(raw) == OK and j.data is Array else []


## Card [param k]'s painting sent back for [param faults]: added to [method sent_back]. "" written.
func send_back(k: int, faults: Array) -> String:
	var rounds := sent_back(k)
	rounds.append(faults)
	var p := _sent_back_file(k)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(p + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + p
	f.store_string(JSON.stringify(rounds, "\t"))
	f.close()
	return "" if DirAccess.rename_absolute(p + ".part", p) == OK else "could not move %s into place" % p


func _sent_back_file(k: int) -> String:
	return dir.path_join("sent_back_%d.json" % k)


## THE PRINTINGS in the full collection, including ones none of tonight's cards came from,
## besides the deck's own, as file keys (`back_<key>.png`).
func printings() -> Array:
	var out: Array = []
	for k in range(1, card_count() + 1):
		var key := printing_of(k)
		if not key.is_empty() and not out.has(key):
			out.append(key)
	var plan: Variant = read_json("plan")
	if plan is Dictionary:
		var look: Dictionary = (plan as Dictionary).get("look", {}) if (plan as Dictionary).get("look") is Dictionary else {}
		for card in (plan as Dictionary).get("deck", []) if (plan as Dictionary).get("deck") is Array else []:
			if card is Dictionary:
				var name := CardTable.series_of(look, card as Dictionary)
				var key := CardTable.series_key(name) if not name.is_empty() else ""
				if not key.is_empty() and not out.has(key):
					out.append(key)
		var inventory: Dictionary = (plan as Dictionary).get("inventory", {}) if (plan as Dictionary).get("inventory") is Dictionary else {}
		var counts: Dictionary = inventory.get("printings", {}) if inventory.get("printings") is Dictionary else {}
		for name in counts:
			if int(counts[name]) > 0 and not String(name).is_empty():
				var key := CardTable.series_key(String(name))
				if not out.has(key):
					out.append(key)
	return out


## Card [param k]'s printing as a file key, or "" for the deck's own.
func printing_of(k: int) -> String:
	_read_cards()
	return String(_printing_keys[k - 1]) if k >= 1 and k <= _printing_keys.size() else ""


## THE LAST CARD THE READER OF CARD [param k]'s PASSAGE HAS SEEN: [param k] itself - or, when it was swept
## out in a waterfall ([constant TablePositions.COMES] `swept`), the last card of that waterfall, which
## all lie face up on the table together.
func reveal_of(k: int) -> int:
	_read_cards()
	var swept := func(i: int) -> bool: return i >= 1 and i <= _swept.size() and bool(_swept[i - 1])
	if not swept.call(k):
		return k
	var last := k
	while swept.call(last + 1):
		last += 1
	return last


## The printings and the waterfalls, read again only when the plan or the draw changes.
func _read_cards() -> void:
	var stamp := ""
	for f in [file_of("plan"), file_of("draw")]:
		stamp += "%d|%d;" % [FileAccess.get_modified_time(f), FileAccess.get_size(f)] if FileAccess.file_exists(f) else "-;"
	if stamp == _cards_stamp:
		return
	_cards_stamp = stamp
	_printing_keys = []
	_swept = []
	_written = []
	var p: Variant = read_json("plan")
	var d: Variant = read_json("draw")
	var plan: Dictionary = p if p is Dictionary else {}
	var look: Dictionary = plan.get("look", {}) if plan.get("look") is Dictionary else {}
	for pos in (((plan.get("spread", {}) as Dictionary).get("positions", [])) as Array) if plan.get("spread") is Dictionary else []:
		_swept.append(pos is Dictionary and String((pos as Dictionary).get("comes", "")) == "swept")
	for c in (d as Dictionary).get("cards", []) if d is Dictionary else []:
		var name := CardTable.series_of(look, c as Dictionary) if c is Dictionary else ""
		_printing_keys.append(CardTable.series_key(name) if not name.is_empty() else "")
		_written.append(c is Dictionary and CardTable.written(CardTable.look_of(CardTable.sanitize_look(look), c as Dictionary)))


## WHETHER CARD [param k] IS A WRITTEN CARD ([constant CardTable.FRAMES] `written`): its writing is its face, and nothing
## is painted for it - no picture, so no art director's look at one.
func written_card(k: int) -> bool:
	_read_cards()
	return k >= 1 and k <= _written.size() and bool(_written[k - 1])


## WHETHER THE PAINTING'S HEIGHT MAP IS WANTED: the table is set and lays the painting where its depth
## is read ([method Tables.wants_height]). Read again only when the table's file changes.
func wants_height() -> bool:
	var p := file_of("table")
	var stamp := "%d|%d" % [FileAccess.get_modified_time(p), FileAccess.get_size(p)] if FileAccess.file_exists(p) else ""
	if stamp != _height_stamp:
		_height_stamp = stamp
		_height_wanted = false
		var t: Variant = read_json("table")
		if t is Dictionary:
			var td: Dictionary = t
			_height_wanted = Tables.wants_height(Tables.sanitize(td.get("top"), td.get("layers"),
				Props.sanitize(td, [])["materials"], []))
	return _height_wanted


## DELETE THE EPISODE: its whole folder - plan, draw, designs, pictures, passages, script, upload
## notes, and every job's prompt beside its reply - goes to the SYSTEM'S TRASH, not to nothing: an
## episode is minutes of an author's quota, and a mistaken delete should be undoable from there.
## Exported videos live elsewhere and are not touched. "" on success, else why not.
func trash() -> String:
	if not DirAccess.dir_exists_absolute(dir):
		return "there is nothing on disk for episode #%d" % seed
	var err: int = discard.call(dir) if discard.is_valid() else OS.move_to_trash(dir)
	if err != OK or DirAccess.dir_exists_absolute(dir):
		return "could not move %s to the trash (error %d)" % [dir, err]
	_script_cache = {}
	return ""


## The whole reading, ready to speak - "" until every passage is written. Asked every frame
## (the exporter's button asks whether there is a reading), so it is read again only when the
## file changes; a redo deletes it, which drops the copy.
func script() -> String:
	var p := file_of("script")
	if not FileAccess.file_exists(p):
		_script_cache = {}
		return ""
	var mt := FileAccess.get_modified_time(p)
	if int(_script_cache.get("at", -1)) != mt:
		_script_cache = {"at": mt, "text": FileAccess.get_file_as_string(p)}
	return String(_script_cache["text"])


## Every step made - but the painting's height map, which only deepens the table: one refused (it did not
## line up with the painting) leaves the episode whole, its painting's own detail standing in.
func complete() -> bool:
	for s in steps():
		if String(s) != "image:height" and not has(String(s)):
			return false
	return true


## WHAT AN UPLOAD OF THE EPISODE SAYS: the title, the description (else the premise) and the tags
## of the plan - as the panel left them - and, given the take at [param take], a chapter per card
## timed from its sidecar's word timings. `{title, description, chapters, tags}`; no chapters
## without a readable take.
func upload_notes(take := "") -> Dictionary:
	var plan: Variant = read_json("plan")
	var p: Dictionary = plan if plan is Dictionary else {}
	var desc := String(p.get("description", "")).strip_edges()
	var out := {"title": String(p.get("episode_title", "")).strip_edges(),
		"description": desc if not desc.is_empty() else String(p.get("premise", "")).strip_edges(),
		"chapters": PackedStringArray(),
		"tags": PackedStringArray(p.get("tags", []) if p.get("tags") is Array else [])}
	var side := FileAccess.get_file_as_string(take.get_basename() + ".json") \
		if not take.is_empty() and FileAccess.file_exists(take.get_basename() + ".json") else ""
	var j := JSON.new()
	if side.is_empty() or j.parse(side) != OK or not (j.data is Dictionary):
		return out
	var words: Array = (j.data as Dictionary).get("words", [])
	var cards: Array = document().get("cards", [])
	# A SHOW WITH NO CARDS: a chapter a beat, by its name
	var bare := cardless()
	var beat_pos: Array = (((p.get("spread", {}) as Dictionary).get("positions", [])) as Array) if bare and p.get("spread") is Dictionary else []
	var chapters := PackedStringArray()
	for c in CardReading.chapters(script(), words):
		var d: Dictionary = c
		var label := "Intro"
		match String(d["kind"]):
			"work":
				var b := int(d["card"])
				var bp: Variant = beat_pos[b - 1] if b >= 1 and b <= beat_pos.size() else {}
				label = String((bp as Dictionary).get("name", "")) if bp is Dictionary else ""
				if label.is_empty():
					label = "Part %d" % b
			"draw", "jumper", "deal", "show":
				var k := int(d["card"])
				var card: Dictionary = cards[k - 1] if k >= 1 and k <= cards.size() else {}
				var pos := String((card.get("position", {}) as Dictionary).get("name", ""))
				label = "%s%s%s%s" % [(pos + " - ") if not pos.is_empty() else "", String(card.get("name", "Card %d" % k)),
					" (reversed)" if bool(card.get("reversed", false)) else "",
					" - a jumper" if String(d["kind"]) == "jumper" else ""]
			"spread":
				label = "The close" if bare else "The spread"
		chapters.append("%s %s" % [chapter_clock(int(d["t"])), label])
	out["chapters"] = chapters
	return out


## [param t] seconds as a chapter's timestamp, as YouTube reads one: `m:ss`, `h:mm:ss` from an hour.
static func chapter_clock(t: int) -> String:
	return Clock.text(float(t))


## UPLOAD NOTES: `upload.md` - what an upload of the episode says (see [method upload_notes]), its
## chapters timed from the take at [param take], the [param title] and the show's [param description]
## it goes up with in place of the plan's when given, and the tags that go up with it - [param tags],
## the show's - fitted to YouTube's limit. "" on success, else why not.
func write_upload_notes(take: String, tags := PackedStringArray(), description := "", title := "") -> String:
	var side := FileAccess.get_file_as_string(take.get_basename() + ".json")
	var j := JSON.new()
	if j.parse(side) != OK or not (j.data is Dictionary):
		return "the take's sidecar is unreadable"
	var n := upload_notes(take)
	var desc := description.strip_edges() if not description.strip_edges().is_empty() else String(n["description"])
	var head := title.strip_edges() if not title.strip_edges().is_empty() else String(n["title"])
	var lines := PackedStringArray(["# " + head, "", desc, "", "Chapters"])
	lines.append_array(n["chapters"] as PackedStringArray)
	var going: PackedStringArray = YouTube.fit_tags(Array(tags))
	if not going.is_empty():
		lines.append("")
		lines.append("Tags: " + ", ".join(going))
	return write_text("upload", "\n".join(lines) + "\n")


## The YouTube uploads made of this episode, oldest first (`youtube.json`, kept by youtube.gd).
func uploads() -> Array:
	return YouTube.uploads_in(file_of("youtube"))


# --- what the table is given ------------------------------------------------------------

## THE EPISODE AS THE TABLE DRAWS IT, handed to the medium beside the script (live, through the
## Generative panel's book document; in a render, through the take's sidecar). Plain data and
## ABSOLUTE paths, because a render is a second process with no producer in it.
func document() -> Dictionary:
	var plan: Variant = read_json("plan")
	var draw: Variant = read_json("draw")
	var out := {"show": show, "seed": seed, "dir": dir, "plan": plan if plan is Dictionary else {},
		"images": {}, "cards": [],
		# the cards a box's draw left in it (TableProducer._make_draw): the table prints the unseen cards as them
		"left": (draw as Dictionary).get("left", []) if draw is Dictionary and (draw as Dictionary).get("left") is Array else [],
		# how many cards the deck the draw was shuffled from held (0: drawn before the draw counted them)
		"deck_n": int((draw as Dictionary).get("deck_n", 0)) if draw is Dictionary else 0}
	for k in ["back", "surface", "backdrop"]:
		if has("image:" + k):
			out["images"][k] = file_of("image:" + k)
	if draw is Dictionary:
		var spread: Array = (((out["plan"] as Dictionary).get("spread", {}) as Dictionary)
			.get("positions", [])) as Array
		# A DEALER'S LAYOUT, laid over the plan's positions: where each card lies (TablePositions)
		var laid := {}
		var layout: Variant = read_json("layout")
		for p in ((layout as Dictionary).get("positions", []) if layout is Dictionary else []):
			if p is Dictionary:
				laid[int((p as Dictionary).get("card", 0))] = p
		var i := 0
		for c in (draw as Dictionary).get("cards", []):
			i += 1
			# the draw keeps the cards themselves (see TableProducer._make_draw)
			var card := (c as Dictionary).duplicate()
			card["reversed"] = bool(card.get("reversed", false))
			card["righted"] = bool(card.get("righted", false))
			card["jumper"] = bool(card.get("jumper", false))
			card["position"] = (spread[i - 1] as Dictionary).duplicate() if i - 1 < spread.size() and spread[i - 1] is Dictionary else {}
			if laid.has(i):
				for k in ["x", "z", "yaw", "face"]:
					if (laid[i] as Dictionary).has(k):
						(card["position"] as Dictionary)[k] = laid[i][k]
			var design: Variant = read_json("design:%d" % i)
			card["booklet"] = (design as Dictionary).get("booklet", {}) if design is Dictionary else {}
			# a written card's writing, which its face is ([constant CardTable.FRAMES] `written`)
			if design is Dictionary and (design as Dictionary).get("writing") is Dictionary:
				card["writing"] = (design as Dictionary)["writing"]
			card["art"] = file_of("image:card:%d" % i) if has("image:card:%d" % i) else ""
			(out["cards"] as Array).append(card)
	return out

extends KeptSteps
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
## The chapters the video opens and closes on when their readers name none ([method upload_notes]): no
## card word in the close's, for a show that brews draws a card too.
const INTRO_CHAPTER := "Intro"
const CLOSE_CHAPTER := "The close"
## What a game's session asks to have painted: a list of [method game] -> the pictures' step word.
const GAME_PICTURES := {"maps": "map", "figures": "figure", "reveals": "reveal"}
## WHAT COMES WITH THE FACE PAINTED FIRST (`image:face`, `face.png`): the bare surface it was painted on, where the surface lies in it
## and which one it is, and the painting as the surface wears it ([method TableProducer._make_image], [method TableProducer._land_face]).
const FACE_FILES := ["face_bare.png", "face.json", "face_ref.png"]

## Where shows live. Moved aside under test, so a gate never touches the author's episodes.
static var root := ROOT
## How a deleted episode's folder is thrown away, when set: the gate's seam, so a check never
## fills the author's trash. Unset, it goes to the system's trash ([method trash]).
static var discard: Callable = Callable()

var show := ""
var seed := 0
var _script_cache := {}
var _cards_stamp := "-"           # the plan and draw files the printings and waterfalls were last read from
var _printing_keys: Array = []      # per drawn card: its printing's file key, "" the deck's own
var _swept: Array = []              # per spread position: swept out in a waterfall
var _written: Array = []            # per drawn card: a written card, nothing painted for it ([method written_card])
var _height_stamp := "-"          # the table file the height map's wanting was last read from
var _height_wanted := false
var _game_cache := {}


static func open(show_key: String, seed_value: int) -> TableEpisode:
	var e := TableEpisode.new()
	e.show = show_key
	e.seed = seed_value
	e.dir = ProjectSettings.globalize_path(root.path_join(show_key).path_join(str(seed_value)))
	return e


## The episode kept in folder [param path] (absolute, or under user://): `<show>/<seed>`, named by the folder's own names.
static func at_dir(path: String) -> TableEpisode:
	var e := TableEpisode.new()
	e.dir = ProjectSettings.globalize_path(path).trim_suffix("/")
	e.seed = int(e.dir.get_file())
	e.show = e.dir.get_base_dir().get_file()
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
			"light": light, "intro": ep.read_text("say:intro"), "close": ep.read_text("say:close"), "model": String(ep.model().get("name", ""))})
	return out


# --- files -----------------------------------------------------------------------------

## The file a step is kept in (see [method steps] for the keys).
func file_of(step: String) -> String:
	var parts := step.split(":")
	match String(parts[0]):
		"plan":
			return dir.path_join("plan.json")
		# WHERE THE AUTHOR TOOK THIS EPISODE ([Direction]): the Direction card's words as the plan was first made
		"direction":
			return dir.path_join("direction.md")
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
		"model":
			return dir.path_join("model.json")
		"skin":
			return dir.path_join("skin.json")
		"meta":
			return dir.path_join("meta.json")
		"prep":
			return dir.path_join("prep.json")
		"game":
			return dir.path_join("game.json")
		"upload":
			return dir.path_join("upload.md")
		"youtube":
			return dir.path_join("youtube.json")
		"layout":
			return dir.path_join(DealerTools.LAYOUT)
		"layers":
			return dir.path_join("layers.json")
		# WORK A COMPUTER CHECKS ([SolverTools]): the verdict, and what the solver left as it worked - its lab notebook, its Lean
		# file, its runs and the series they kept
		"solve":
			return dir.path_join("solve.json")
		"notebook":
			return dir.path_join("notebook.md")
		"proof":
			return dir.path_join("proof.lean")
		"runs":
			return dir.path_join("runs.json")
		"data":
			return dir.path_join("data.json")
		# WHAT IS WRITTEN ON A PAGE, laid out by TeX ([TableInk])
		"ink":
			return dir.path_join(TableInk.FILE)
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
##
## WHAT IT REPLACES GOES A VERSION BACK ([method keep_version]) when it says something else: nothing written over is lost.
func write_text(step: String, text: String) -> String:
	var p := file_of(step)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	if FileAccess.file_exists(p) and FileAccess.get_file_as_string(p) != text:
		keep_version(step)
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
	# (...the direction first, where the episode was given one: the plan is made from it)
	var out: Array = (["direction"] if has("direction") else []) + ["plan", "draw"]
	if wants_game():
		return _game_steps(out)
	if wants_model():
		out.append("model")
	# WORK A COMPUTER CHECKS, where the plan fixes a problem ([method wants_solve]): worked before the table is set, so the
	# work written at it and the words said over it are the work done
	if wants_solve():
		out.append("solve")
	if cardless():
		out.append_array(["image:surface", "image:backdrop", "table"])
		if wants_height():
			out.append("image:height")
		if wants_face():
			out.append_array(["image:face", "check:face"])
			out.append_array(_layer_steps())
		if wants_skin():
			out.append("skin")
		if not work_plan().is_empty():
			out.append("acts")
			if wants_ink():
				out.append("ink")
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
	if wants_face():
		out.append_array(["image:face", "check:face"])
		out.append_array(_layer_steps())
	if wants_skin():
		out.append("skin")
	if not works.is_empty():
		out.append("acts")
		if wants_ink():
			out.append("ink")
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


## THE PICTURE PAINTED FIRST, AGAIN IN LAYERS (the user, 2026-11-09: "generate MULTIPLE images, each one including changes from the
## last ... image 1 would be the white base, image 2 would include the rust regions, image 3 would include the black lines"; the lab,
## lab/paint/layers_gen.py): the order it is painted in, written by the art director looking at it (`layers`, `layers.json`), then each
## layer painted over the one before, as it is in the picture (`image:layer:K`, `layer_K.png`) - so what each layer lays is exactly what
## changed, never guessed from colors. Its layers are listed once the order is written.
func _layer_steps() -> Array:
	var out := ["layers"]
	for k in range(1, layer_count() + 1):
		out.append("image:layer:%d" % k)
	return out


## How many layers the picture painted first is painted in (`layers.json`): 0 before the order is written.
func layer_count() -> int:
	return layers().size()


## The layers, in order: `[{name, add, soft}]` (`layers.json`), [] before they are written.
func layers() -> Array:
	var d: Variant = read_json("layers") if has("layers") else null
	var list: Variant = (d as Dictionary).get("layers", []) if d is Dictionary else []
	return (list as Array).filter(func(l: Variant) -> bool: return l is Dictionary) if list is Array else []


## WHERE THE AUTHOR TOOK THIS EPISODE ([Direction], `direction.md`): the Direction card's words as its plan was first made - "" for
## an episode given none. Every agent behind the episode reads this, never the card ([method TableProducer.with_direction]).
func direction() -> String:
	return read_text("direction").strip_edges() if has("direction") else ""


## WHETHER THE PLAN FIXES A PROBLEM to be worked and checked by a computer ([SolverTools], `problem`): a theorem Lean proves or
## a computation that runs. The brief says whether its episodes have one; nothing else does.
func wants_solve() -> bool:
	return not problem().is_empty()


## THE PROBLEM THE PLAN FIXES, as it landed ([method SolverTools.land_problem]): `{}` for none.
func problem() -> Dictionary:
	var p: Variant = read_json("plan")
	var got: Variant = (p as Dictionary).get("problem") if p is Dictionary else null
	return got if got is Dictionary and not String((got as Dictionary).get("statement", "")).is_empty() else {}


## WHAT THE SOLVE CAME TO (`solve.json`): `{verified, computed, checks, runs, ...}`, `{}` before it is made.
func solved() -> Dictionary:
	var s: Variant = read_json("solve") if has("solve") else null
	return s if s is Dictionary else {}


## WHETHER ANYTHING THE WORK WRITES IS LAID OUT BY TEX ([method TableInk.items_of]): a formula, a drawing, or words with math in
## them - then the ink is a step, made from the acts.
func wants_ink() -> bool:
	return has("acts") and not TableInk.items_of(read_json("acts")).is_empty()


## A GAME PLAYED AT THE TABLE (next/tabletop.md): the secret preparation, the table, the session played a stretch at a time, THEN what it turned out to need painted - a map of a boat, if there came to be a
## boat. Its dice are thrown as the table first stands ([TableGame]).
func _game_steps(out: Array) -> Array:
	out.append_array(["prep", "image:surface", "image:backdrop", "table", "say:intro"])
	for k in range(1, beat_count() + 1):
		out.append("say:%d" % k)
	out.append_array(["say:close", "script"])
	var g := game()
	for key in GAME_PICTURES:
		for k in range(1, (g.get(key, []) as Array).size() + 1):
			out.append("image:%s:%d" % [String(GAME_PICTURES[key]), k])
	return out


## THE PLAN MAKES THIS A GAME ([method CardTable.game_of]).
func wants_game() -> bool:
	var p: Variant = read_json("plan")
	return p is Dictionary and CardTable.game_of(p as Dictionary)


## WHAT THE SESSION CAME TO, once played (`game.json`, [method TableProducer._make_script]): `{events, people, seats, dice, maps, figures, reveals}`, `{}` before. Read once for each time it is written.
func game() -> Dictionary:
	var p := file_of("game")
	if not FileAccess.file_exists(p):
		_game_cache = {}
		return {}
	var mt := FileAccess.get_modified_time(p)
	if int(_game_cache.get("at", -1)) != mt:
		var got: Variant = read_json("game")
		_game_cache = {"at": mt, "data": got if got is Dictionary else {}}
	return _game_cache["data"]


## The file a scene's events are kept in, beside its words ([param say] `say:K`): written first, so words that are there have their events.
func events_file(say: String) -> String:
	return dir.path_join("events_%s.json" % say.trim_prefix("say:"))


## EVERY EVENT OF THE SCENES BEFORE [param say], in order: what a [GameLedger] stands from.
func events_before(say: String) -> Array:
	var out: Array = []
	var order := ["say:intro"]
	for k in range(1, beat_count() + 1):
		order.append("say:%d" % k)
	order.append("say:close")
	for s in order:
		if String(s) == say:
			break
		if not has(String(s)) or not FileAccess.file_exists(events_file(String(s))):
			continue
		var got: Variant = JSON.parse_string(FileAccess.get_file_as_string(events_file(String(s))))
		if got is Array:
			out = got
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
	if wants_game():
		var made := _game_needs(parts)
		if not made.is_empty():
			return made
	match String(parts[0]):
		"direction":
			return []
		"plan":
			# ...made from the direction it was given, where it was given one: a direction taken up again makes the plan stale
			return ["direction"] if has("direction") else []
		"draw":
			return ["plan"]
		"design":
			# ONE AFTER ANOTHER: a card's designer is shown the cards designed before it in this draw,
			# so it pictures its own otherwise (see TableProducer._make_design)
			var k := int(parts[1])
			return ["draw"] if k <= 1 else ["draw", "design:%d" % (k - 1)]
		"check":
			# ...and at the face painted first, as it was asked for
			if String(parts[1]) == "face":
				return ["image:face"]
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
			if String(parts[1]) == "face":
				# what is painted, painted first ON the surface the table stands it on (feedback 0023)
				return ["plan", "table"]
			if parts.size() == 3 and String(parts[1]) == "layer":
				# ...a layer painted over the one before it, toward the picture, in the order written
				var k := int(parts[2])
				return ["layers", "image:face"] + (["image:layer:%d" % (k - 1)] if k > 1 else [])
			return ["plan"]
		"say":
			var who := String(parts[1])
			var works := work_plan()
			if who == "intro":
				# ...and, where the plan fixed a problem, after the work was done: the reader teaches what was really found
				return (["draw", "acts"] if works.has("intro") else ["draw"]) + (["solve"] if wants_solve() else [])
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
		"layers":
			# the order is written looking at the picture, once it is passed
			return ["image:face", "check:face"]
		"model":
			return ["plan"]
		"solve":
			return ["plan"]
		"ink":
			# what the work writes, laid out once it is blocked - and the series a drawing plots, which the solve kept
			return ["acts"]
		"skin":
			# what is painted is designed on the surface the table stands it on - copied from the face painted on it first, looked at
			# ...and, where it was painted again in layers, every layer: the painter at the table lays them (next/face_layers.md)
			var out := ["plan", "table"] + (["image:face", "check:face", "layers"] if wants_face() else [])
			if wants_face():
				for k in range(1, layer_count() + 1):
					out.append("image:layer:%d" % k)
			return out
		"table":
			# the table is set from the plan, LOOKING AT the cloth it stands on - and at the room, which
			# its light must agree with (where the windows are, which side the sun comes from)
			return ["plan", "image:surface", "image:backdrop"] + (["model"] if wants_model() else [])
		"acts":
			# the work is blocked on the table as it is set, with the cards as they were drawn (the work is
			# made of them: an ingredient fetched and ground) - no reader sees past its own beat's - and, where
			# a card is WRITTEN, what is written on it (a recipe's steps are the work)
			var out := ["plan", "draw", "table"] + (["model"] if wants_model() else []) + (["skin"] if wants_skin() else []) \
				+ (["solve"] if wants_solve() else [])
			var p: Variant = read_json("plan")
			if p is Dictionary and (p as Dictionary).get("look") is Dictionary and CardTable.written((p as Dictionary)["look"]):
				for k in range(1, n + 1):
					out.append("design:%d" % k)
			return out
	return []


## WHAT A GAME'S OWN STEPS ARE MADE FROM: the session is played in order on the table as set, and what it needed is painted after. [] for a step no different from any other's.
func _game_needs(parts: PackedStringArray) -> Array:
	match String(parts[0]):
		"prep":
			return ["plan"]
		"image":
			if parts.size() == 3 and GAME_PICTURES.values().has(String(parts[1])):
				return ["script"]
		"say":
			var who := String(parts[1])
			if who == "intro":
				return ["prep", "table"]
			var n := beat_count()
			if who == "close":
				return ["say:%d" % n] if n > 0 else ["say:intro"]
			return ["say:intro"] if int(who) <= 1 else ["say:%d" % (int(who) - 1)]
	return []


## WHAT [param step] IS MADE FROM, AS IT STANDS: each made step it needs (never one it waits on only for order, [method _soft]) ->
## its digest. The script is put together from every passage, so it is made from all of them.
func made_from(step: String) -> Dictionary:
	var out := {}
	var from: Array = needs(step)
	if step == "script":
		from = steps().filter(func(s: Variant) -> bool: return String(s).begins_with("say:"))
	for n in from:
		if not _soft(String(n), step) and has(String(n)):
			out[String(n)] = digest(String(n))
	return out


## AN EPISODE BEGUN BY HAND, no agent asked (next/editing.md step 8: "a human should be able to create nonlinear scenes from scratch"):
## a plan of [param beats] beats that draws no cards, the table - [param fixed], the brief's fixed things ([FixedTable]), where it
## has any - its passages empty and its script put together from them; every step BY HAND ([method by_hand]) and kept, the
## pictures it has not got too, so Generate makes nothing and each row waits for its ✎. "" done, else why not.
func begin_by_hand(beats := 1, fixed := {}) -> String:
	if has("plan"):
		return "this episode is begun already"
	var positions: Array = []
	for k in range(1, maxi(beats, 1) + 1):
		positions.append({"name": "Beat %d" % k})
	var plan := {"episode_title": "By hand", "spread": {"name": "", "positions": positions}, "staging": {"source": "none"},
		"look": CardTable.sanitize_look({}), "beat_word": "Beat"}
	var err := write_json("plan", plan)
	if err.is_empty():
		err = write_json("draw", {"cards": [], "deck_n": 0})
	if err.is_empty():
		err = write_json("table", FixedTable.merge({"things": []}, fixed) if not fixed.is_empty() else {"things": []})
	for st in ["say:intro"] + range(1, positions.size() + 1).map(func(k: int) -> String: return "say:%d" % k) + ["say:close"]:
		if err.is_empty():
			err = write_text(String(st), "")
	if err.is_empty():
		var passages: Array = []
		for m in TableProducer.choreography(plan, []):
			passages.append({"kind": (m as Dictionary)["kind"], "card": (m as Dictionary).get("card", 0), "last": (m as Dictionary).get("last", (m as Dictionary).get("card", 0)), "text": ""})
		err = write_text("script", CardReading.compose(passages))
	if not err.is_empty():
		return err
	for st in steps():
		var s := String(st)
		if has(s):
			note_made(s, "hand")
			set_kept(s, true)
		if s != "script":
			set_by_hand(s, true)
	return ""


## THE VOICE'S TAKE, KEPT (next/editing.md step 3: "the voice is the clock, so the take is kept"): `take.wav` and its sidecar
## `take.json` (every word's time), with the digest of the script it was said from - not a step: a function of the words and
## the voices, made again cheaply ([TakeCache]) and never by Generate.
func take_file() -> String:
	return dir.path_join("take.wav")


## Whether the take kept was said from the script as it stands - and, given [param sig] ([method ReadingPanel.take_sig]), in the
## voices as they stand: where it was, the table plans on its words' times and the reading plays it.
func take_matches(sig := "") -> bool:
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(take_file().get_basename() + ".json")) \
		if FileAccess.file_exists(take_file().get_basename() + ".json") and FileAccess.file_exists(take_file()) else null
	return side is Dictionary and has("script") and String((side as Dictionary).get("script_sha", "")) == digest("script") \
		and (sig.is_empty() or String((side as Dictionary).get("sig", "")) == sig)


## The take kept: its length in seconds (its last word's end and its outro), 0 for none.
func take_length() -> float:
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(take_file().get_basename() + ".json")) \
		if FileAccess.file_exists(take_file().get_basename() + ".json") else null
	var words: Array = (side as Dictionary).get("words", []) if side is Dictionary and (side as Dictionary).get("words") is Array else []
	if words.is_empty() or not (words.back() is Dictionary):
		return 0.0
	var out: Variant = ((side as Dictionary).get("bookend", {}) as Dictionary).get("out", 0.0) if (side as Dictionary).get("bookend") is Dictionary else 0.0
	return float((words.back() as Dictionary).get("t1", 0.0)) + float(out)


## [param wav] (a take just rendered) and its sidecar kept as the episode's take, said from the script as it stands now. "" done.
func keep_take(wav: String) -> String:
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(wav.get_basename() + ".json"))
	if not (side is Dictionary):
		return "the take's sidecar is unreadable"
	(side as Dictionary)["script_sha"] = digest("script")
	DirAccess.make_dir_recursive_absolute(dir)
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(wav), take_file() + ".part") != OK \
			or DirAccess.rename_absolute(take_file() + ".part", take_file()) != OK:
		return "could not keep the take"
	return _put(take_file().get_basename() + ".json", JSON.stringify(side))


## What is cached of the steps' files, forgotten ([method KeptSteps._changed]): a version put back changes them.
func _changed() -> void:
	_script_cache = {}


## The files [param step] is: its own, and what comes with it.
func files_of(step: String) -> Array:
	var p := file_of(step)
	if p.is_empty():
		return []
	var out := [p]
	if step == "image:face":
		for f in FACE_FILES:
			out.append(dir.path_join(String(f)))
	elif step == "image:height":
		out.append(dir.path_join("height.json"))
	elif step == "solve":
		for k in ["notebook", "proof", "runs", "data"]:
			if FileAccess.file_exists(file_of(String(k))):
				out.append(file_of(String(k)))
	return out


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


## WHAT EACH STEP WOULD TAKE WITH IT, for every step at once (step -> [method dependents]): [method needs] parses the episode's
## files on every call, and the Pipeline card's rows each say what their ⟳ throws away, so walking them row by row would
## be thousands of parses - a frame of a playing show lost whenever a step lands.
func all_dependents() -> Dictionary:
	var made_from := {}
	var all := steps()
	for t in all:
		for s in needs(String(t)):
			if _soft(String(s), String(t)):
				continue
			if not made_from.has(String(s)):
				made_from[String(s)] = []
			(made_from[String(s)] as Array).append(String(t))
	var out := {}
	for step in all:
		var from := String(step)
		var reached: Array = []
		var frontier: Array = [from]
		while not frontier.is_empty():
			for t in made_from.get(String(frontier.pop_front()), []):
				if t != from and not reached.has(t):
					reached.append(t)
					frontier.append(t)
		out[from] = reached
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


## WHETHER THIS EPISODE DESIGNS WHAT IS PAINTED ([Skins]; next/painted_surface.md): a plan that says what is painted, unless its work was
## blocked before there were designs - a finished episode goes on as it was made.
func wants_skin() -> bool:
	if has("skin"):
		return true
	if has("acts"):
		return false
	var p: Variant = read_json("plan")
	return p is Dictionary and not String((p as Dictionary).get("painted", "")).strip_edges().is_empty()


## WHETHER WHAT IS PAINTED IS PAINTED FIRST AS A PICTURE, AND COPIED (feedback 0023; next/painted_surface.md): an episode that designs what is
## painted, with no design yet - one designed before there were paintings goes on as it was made, and designing it again starts from one.
func wants_face() -> bool:
	if has("image:face"):
		return true
	if has("skin"):
		return false
	return wants_skin()


## WHETHER THIS EPISODE DESIGNS WHAT IT BUILDS FIRST ([AssemblyModel]): a plan that builds, unless its work was blocked before there were models to build to - a finished episode goes on as it was made, and blocking its work again starts from a model.
func wants_model() -> bool:
	if has("model"):
		return true
	if has("acts"):
		return false
	var p: Variant = read_json("plan")
	return p is Dictionary and (p as Dictionary).get("assembly") == true


var _model_read_at := -1
var _model_kept := {}


## WHAT WAS DESIGNED, as [method AssemblyModel.make] left it, `{}` where nothing was.
func model() -> Dictionary:
	# ...READ ONCE FOR EACH TIME IT IS WRITTEN: it is a large file, and most of what comes after asks
	var path := file_of("model")
	var mt := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	if mt != _model_read_at:
		var d: Variant = read_json("model") if mt >= 0 else null
		_model_kept = (d as Dictionary)["made"] if d is Dictionary and (d as Dictionary).get("made") is Dictionary else {}
		_model_read_at = mt
	return _model_kept


## The model in words, for whoever works on the episode after it is designed: what it is, how big, and its sections in the order they go on. "" where there is none.
func model_words() -> String:
	var m := model()
	if m.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("THE MODEL: %s. %d parts on a plate of %d x %d studs (%.0f by %.0f cm), standing %.0f cm tall. Its sections, in the order they go on:" % [String(m.get("name", "")), (m["parts"] as Array).size(),
		int((m["size"] as Array)[0]), int((m["size"] as Array)[1]), float((m["size"] as Array)[0]) * Assembly.STUD * 100.0, float((m["size"] as Array)[1]) * Assembly.STUD * 100.0, float(m["top"]) * Assembly.PLATE * 100.0])
	for sec in m["sections"]:
		var sd: Dictionary = sec
		if int(sd["parts"]) > 0:
			lines.append("- \"%s\", %d parts%s" % [String(sd["name"]), int(sd["parts"]), (": " + String(sd["about"])) if not String(sd["about"]).is_empty() else ""])
	return "\n".join(lines)


## THROW [param step] AWAY, AND EVERYTHING MADE FROM IT - each moved a version back ([method keep_version]), never deleted. What a
## gate resets a fixture with, and what the art director's send-back repaints by; a person's ⟳ throws nothing away
## ([method TableProducer.again]). Returns what went. A card painted or designed again starts with nothing sent back
## ([method sent_back]) - but [param keep_sent] keeps it, for the art director's own send-back, which the painter is told of.
func invalidate(step: String, keep_sent := false) -> Array:
	var gone := [step] + dependents(step)
	# the plan decides how many cards there are: going back to it takes every card step with it, including ones a smaller
	# spread no longer lists - moved together into one folder of what that plan had made ([constant SWEPT_KEPT] kept)
	if (step == "plan" or step == "draw") and DirAccess.dir_exists_absolute(dir):
		var swept := ""
		for f in DirAccess.get_files_at(dir):
			var fs := String(f)
			if fs.begins_with("design_") or fs.begins_with("card_") or fs.begins_with("say_") \
					or fs.begins_with("check_") or fs.begins_with("sent_back_") \
					or fs == "script.md" or fs == "acts.json" or fs == "game.json" or fs == "prep.json" or fs.begins_with("events_") \
					or fs.begins_with("map_") or fs.begins_with("figure_") or fs.begins_with("reveal_") or (step == "plan" and (fs in ["draw.json", "back.png", "surface.png",
					"backdrop.png", "height.png", "height.json"] or fs.begins_with("back_") or fs.begins_with("face"))):
				if swept.is_empty():
					swept = _swept_folder()
				DirAccess.rename_absolute(dir.path_join(fs), swept.path_join(fs))
	for s in gone:
		keep_version(String(s), true)
		var card := String(s).trim_prefix("image:card:").trim_prefix("design:")
		if String(s) == "image:face" and not keep_sent:
			DirAccess.remove_absolute(_sent_back_file("face"))
		if not keep_sent and card != String(s) and card.is_valid_int():
			DirAccess.remove_absolute(_sent_back_file(int(card)))
	_script_cache = {}
	return gone


## How many folders of what a thrown-away plan had made are kept ([method invalidate]).
const SWEPT_KEPT := 2


## A new folder under `versions/_swept/` for what a plan thrown away had made; past [constant SWEPT_KEPT], the oldest goes.
func _swept_folder() -> String:
	var base := dir.path_join(VERSIONS_DIR).path_join("_swept")
	DirAccess.make_dir_recursive_absolute(base)
	var olds := Array(DirAccess.get_directories_at(base))
	olds.sort()
	var n := int(String(olds.back()).trim_prefix("v")) + 1 if not olds.is_empty() else 1
	while olds.size() >= SWEPT_KEPT:
		_remove_tree(base.path_join(String(olds.pop_front())))
	var out := base.path_join("v%03d" % n)
	DirAccess.make_dir_recursive_absolute(out)
	return out


## WHAT THE ART DIRECTOR SENT BACK of card [param k]'s paintings so far (or "face", the face painted first's), a list of faults per
## painting sent back, oldest first - kept beside the episode, not a step: the painting it was said of
## is gone, and the painter of the next is told it ([method TableProducer._make_image]).
func sent_back(k: Variant) -> Array:
	var raw := FileAccess.get_file_as_string(_sent_back_file(k))
	var j := JSON.new()
	return j.data if not raw.is_empty() and j.parse(raw) == OK and j.data is Array else []


## Card [param k]'s painting sent back for [param faults]: added to [method sent_back]. "" written.
func send_back(k: Variant, faults: Array) -> String:
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


func _sent_back_file(k: Variant) -> String:
	return dir.path_join("sent_back_%s.json" % str(k))


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
## of the plan - as the panel left them - and, given the take at [param take], its chapters timed from
## its sidecar's word timings ([method CardReading.chapters]): each the name the reader gave it, else
## the intro's ([constant INTRO_CHAPTER]), the card by its place and name ([method card_chapter]), the
## beat by its name, the close's ([constant CLOSE_CHAPTER]) - and as YouTube takes them
## ([method YouTube.fit_chapters], the video ending its outro after the last word). `{title, description, chapters, tags}`; no chapters
## without a readable take.
func upload_notes(take := "") -> Dictionary:
	var plan: Variant = read_json("plan")
	var p: Dictionary = plan if plan is Dictionary else {}
	var desc := String(p.get("description", "")).strip_edges()
	if desc.is_empty():
		desc = String(p.get("premise", "")).strip_edges()
	# ...WITH WHAT THE CHECK CAME TO, where a problem was worked: from the verdict, never the producer's words
	var check := SolverTools.check_line(solved(), problem())
	if not check.is_empty():
		desc = (desc + "\n\n" + check).strip_edges()
	var out := {"title": String(p.get("episode_title", "")).strip_edges(),
		"description": desc,
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
	var beat_pos: Array = (((p.get("spread", {}) as Dictionary).get("positions", [])) as Array) if cardless() and p.get("spread") is Dictionary else []
	var timed: Array = []
	for c in CardReading.chapters(script(), words):
		var d: Dictionary = c
		var label := String(d.get("name", ""))
		if label.is_empty():
			match String(d["kind"]):
				"intro":
					label = INTRO_CHAPTER
				"work":
					var b := int(d["card"])
					var bp: Variant = beat_pos[b - 1] if b >= 1 and b <= beat_pos.size() else {}
					label = String((bp as Dictionary).get("name", "")) if bp is Dictionary else ""
					if label.is_empty():
						label = "Part %d" % b
				"draw", "jumper", "deal", "show":
					var k := int(d["card"])
					var card: Dictionary = cards[k - 1] if k >= 1 and k <= cards.size() else {}
					label = card_chapter(String((card.get("position", {}) as Dictionary).get("name", "")),
						String(card.get("name", "Card %d" % k)), bool(card.get("reversed", false)), String(d["kind"]) == "jumper")
				"spread":
					label = CLOSE_CHAPTER
		timed.append({"t": float(d["t"]), "label": label})
	var end := -1.0
	if not words.is_empty() and words.back() is Dictionary:
		var bookend: Variant = (j.data as Dictionary).get("bookend", {})
		end = float((words.back() as Dictionary).get("t1", -1.0)) + (float((bookend as Dictionary).get("out", 0.0)) if bookend is Dictionary else 0.0)
	var chapters := PackedStringArray()
	for c in YouTube.fit_chapters(timed, end):
		chapters.append("%s %s" % [chapter_clock(int((c as Dictionary)["t"])), String((c as Dictionary)["label"])])
	out["chapters"] = chapters
	return out


## A CARD'S CHAPTER when its reader names none: its place in the spread, its name, how it fell.
static func card_chapter(position: String, name: String, reversed: bool, jumper := false) -> String:
	return "%s%s%s%s" % [(position + " - ") if not position.is_empty() else "", name,
		" (reversed)" if reversed else "", " - a jumper" if jumper else ""]


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


# --- as a timeline -----------------------------------------------------------------------

## THE EPISODE AS A [Timeline] on the voice's clock (next/editing.md, "The Timeline"): the intro, each beat and the close a
## group, as long as its words take at the plan's pace ([constant TablePrompts.SAID_WORD] a word) or its acts one after another,
## whichever is longer; each act a span on the `time` engine - the table is a pure function of show time - in the lane of the
## first thing it works ("work" for none), its `source` its place in `acts.json`; each `<!-- act: -->` cue a flag in lane "words"
## at the word it stands before, its `source` the passage and the cue's number in it. A FIRST READING: the schedule the show
## plays ([method TableWork.schedule]) and a kept take's word times are what step 3 makes it.
func timeline() -> Dictionary:
	var raw: Variant = read_json("acts") if has("acts") else null
	var acts: Array = (raw as Dictionary).get("acts", []) if raw is Dictionary and (raw as Dictionary).get("acts") is Array else []
	var told := _told_lengths(raw)
	var bare := cardless()
	var plan: Variant = read_json("plan")
	var pos: Array = (((plan as Dictionary).get("spread", {}) as Dictionary).get("positions", []) as Array) \
		if plan is Dictionary and (plan as Dictionary).get("spread") is Dictionary else []
	var beats: Array = [["intro", "Intro", ["say:intro"]]]
	for k in range(1, beat_count() + 1):
		var nm := String((pos[k - 1] as Dictionary).get("name", "")) if k - 1 < pos.size() and pos[k - 1] is Dictionary else ""
		var says := ["say:%d" % k] if bare else ["say:%d" % k, "say:work:%d" % k]
		beats.append([str(k), "%d. %s" % [k, nm] if not nm.is_empty() else "%s %d" % [beat_word(), k], says])
	beats.append(["close", "Close", ["say:close"]])
	var cue := RegEx.create_from_string(CardReading.ACT_MARK)
	var mark := RegEx.create_from_string("<!--.*?-->")
	var groups: Array = []
	var start := 0.0
	for b in beats:
		var g := Timeline.group(String(b[0]), String(b[1]), start, 0.0, "time")
		var said := 0.0
		for st in b[2]:
			if not has(String(st)):
				continue
			var text := read_text(String(st))
			var n := 0
			for m in cue.search_all(text):
				var before := mark.sub(text.substr(0, m.get_start()), " ", true).split(" ", false).size()
				n += 1
				var flag := Timeline.item("%s-cue-%d" % [String(st).replace(":", "-"), n], m.get_string(1),
					said + before * TablePrompts.SAID_WORD, 0.0, [String(st), "cue", n - 1])
				flag["passage_at"] = said
				Timeline.add(g, "words", "Words", flag)
			said += mark.sub(text, " ", true).split(" ", false).size() * TablePrompts.SAID_WORD
		var at := 0.0
		for i in acts.size():
			var a: Dictionary = acts[i] if acts[i] is Dictionary else {}
			# (a beat's place is a number in the file, which JSON reads back as 1.0)
			var beat: Variant = a.get("beat", "")
			if (str(int(beat)) if typeof(beat) in [TYPE_INT, TYPE_FLOAT] else str(beat)) != String(b[0]):
				continue
			var tracks: Array = a.get("tracks", []) if a.get("tracks") is Array else []
			var thing := String((tracks[0] as Dictionary).get("thing", "")) if not tracks.is_empty() and tracks[0] is Dictionary else ""
			var lane := thing if not thing.is_empty() else "work"
			# (as long as its reader is told it takes - an act sized by its words, `under`, at what it is guessed or laid at)
			var length := maxf(float(told.get(Manuscript.slug(String(a.get("name", ""))), 6.0)), 0.1)
			Timeline.add(g, lane, lane, Timeline.item(String(a.get("name", "act-%d" % (i + 1))), String(a.get("name", "")), at, length, ["acts", i]))
			at += length
		g["length"] = maxf(said, at)
		groups.append(g)
		start += float(g["length"])
	var tl := Timeline.make("voice", groups)
	# A CUE NAMING NOTHING IS A PROBLEM SHOWN, never a mark dropped (next/editing.md step 2): neither an act's name nor a layer
	# an act lays ([method TableWork.resolve_cues])
	var known := {}
	for a in acts:
		if a is Dictionary:
			known[Manuscript.slug(String((a as Dictionary).get("name", "")))] = true     # as the sanitizer names it
			for l in ((a as Dictionary).get("layers", []) if (a as Dictionary).get("layers") is Array else []):
				known[Manuscript.slug(str(l))] = true
	var problems := PackedStringArray()
	for g in groups:
		for l in (g as Dictionary)["lanes"]:
			if String((l as Dictionary)["id"]) != "words":
				continue
			for it in (l as Dictionary)["items"]:
				var nm := Manuscript.slug(String((it as Dictionary)["label"]))
				if not known.has(nm):
					problems.append("%s: the cue \"%s\" names no act and no layer, so it starts nothing" % [String((g as Dictionary)["label"]), nm])
	tl["problems"] = problems
	return tl


## WHAT EACH ACT OF [param raw] (`acts.json`) TAKES, as its reader is told (as [method TableProducer._acts_of] tells it): its
## length made safe ([method Motions.sanitize_acts]), and a painting act what its strokes take ([method Skins.act_natural]).
## slug -> seconds.
func _told_lengths(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var safe: Array = Motions.sanitize_acts(raw, beat_count())["acts"]
	var doc: Variant = read_json("skin") if has("skin") else null
	var folded := Skins.folded_coats((raw as Dictionary).get("acts", []), doc) if doc is Dictionary else {}
	for a in safe:
		var length := float((a as Dictionary).get("length", 6.0))
		if doc is Dictionary:
			var natural := Skins.act_natural(a as Dictionary, doc, read_json("table"), FileAccess.file_exists(dir.path_join("face_ref.png")), folded)
			if natural > 0.0:
				length = natural
		out[String((a as Dictionary)["name"])] = length
	return out


## AN ACT'S LENGTH SET BY HAND (the Timeline's block stretched; next/editing.md step 4): act [param i] of `acts.json` made
## [param seconds] long, what stood a version back, and the step kept - a hand's edit is never made over by Generate. "" done.
func set_act_length(i: int, seconds: float) -> String:
	var raw: Variant = read_json("acts")
	var acts: Variant = (raw as Dictionary).get("acts") if raw is Dictionary else null
	if not (acts is Array) or i < 0 or i >= (acts as Array).size() or not ((acts as Array)[i] is Dictionary):
		return "there is no act %d to set" % (i + 1)
	((acts as Array)[i] as Dictionary)["length"] = snappedf(clampf(seconds, 0.3, Motions.MAX_LENGTH), 0.01)
	var err := write_json("acts", raw)
	return err if not err.is_empty() else set_kept("acts", true)


## A CUE MOVED BY HAND (the Timeline's flag dragged): cue [param n] of passage [param step] put before the word said
## [param at] seconds into the passage (at [constant TablePrompts.SAID_WORD] a word), what stood a version back, and the
## passage kept. "" done.
func move_cue(step: String, n: int, at: float) -> String:
	var text := read_text(step)
	var cues := RegEx.create_from_string(CardReading.ACT_MARK).search_all(text)
	if n < 0 or n >= cues.size():
		return "%s has no cue %d" % [step, n + 1]
	var cue: RegExMatch = cues[n]
	var rest := text.substr(0, cue.get_start()).rstrip(" ") + (" " if cue.get_start() > 0 else "") + text.substr(cue.get_end()).lstrip(" ")
	var mark := RegEx.create_from_string("<!--.*?-->")
	var want := maxi(0, roundi(at / TablePrompts.SAID_WORD))
	# ...before the word [want] of the words said, counted as the timeline counts them (marks are no words)
	var blank := rest
	for mm in mark.search_all(rest):
		blank = blank.substr(0, mm.get_start()) + " ".repeat(mm.get_end() - mm.get_start()) + blank.substr(mm.get_end())
	var said := 0
	var put := rest.length()
	for w in RegEx.create_from_string("\\S+").search_all(blank):
		if said == want:
			put = (w as RegExMatch).get_start()
			break
		said += 1
	var moved := rest.substr(0, put) + cue.get_string() + " " + rest.substr(put)
	var err := write_text(step, moved.strip_edges() + ("\n" if text.ends_with("\n") else ""))
	return err if not err.is_empty() else set_kept(step, true)


## WHAT IS WRONG WITH THE EPISODE AS IT STANDS, in words - [] for nothing (next/editing.md, design point 9: the checks are a
## list, for a person and the same list for an agent's tool): a step's data that does not parse, what the acts' sanitizer
## says of them, the faults of its Timeline and every cue naming nothing, and each step made from something changed since.
## Reads only: what `--episode-check` prints, in seconds, for an edit made in a terminal.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not has("plan"):
		out.append("there is no plan here (%s)" % dir)
		return out
	for st in ["plan", "draw", "table", "acts", "skin", "layers", "model"]:
		if has(st) and read_json(st) == null:
			out.append("%s does not parse as JSON" % file_of(st).get_file())
	if has("acts") and read_json("acts") != null:
		for n in Motions.sanitize_acts(read_json("acts"), beat_count())["notes"]:
			out.append("acts: " + String(n))
	var tl := timeline()
	out.append_array(Timeline.check(tl))
	out.append_array(PackedStringArray(tl.get("problems", [])))
	for st in steps():
		if stale(String(st)):
			out.append("%s is stale: made from something that has changed since%s" % [String(st), " (kept)" if kept(String(st)) else ""])
	return out


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
	# WHAT THE SESSION CAME TO: the table's to stage ([TableGame])
	if has("game"):
		out["game"] = game()
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

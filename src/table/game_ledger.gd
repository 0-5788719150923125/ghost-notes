extends RefCounted
class_name GameLedger

## GameLedger - WHAT IS SO AT A GAME'S TABLE, kept by no one who could fudge it (next/tabletop.md): every sheet, where each figure stands, which map
## lies on the table, every die rolled. An agent forgets it took seven damage, and a viewer does not.
##
## NO GAME IS NAMED HERE: a sheet's fields are whatever the agents call them, numbers or lists, and what any of them means is the brief's. The board
## is squares or a free measure in any unit, and a move says how far it went and leaves whether that was allowed to the one running the game.
##
## IT IS ITS EVENTS: the state at any moment is the sheets it began with and [method apply] over what happened, one by one, so a scene made again
## drops its own events and whatever came after it stands from what came before it. An event is plain data (`{id, kind, ...}`), written into the
## episode ([TableEpisode] `say`), and the table reads the same list ([TableGame]) to stand each figure where it is when.
##
## A REFUSAL IS WORDS ([method move] on a square off the map): the agent is told what is so, in the call that got it wrong. Gate: tests/table/game_ledger_check.gd.

## WHAT CAN HAPPEN AT THE TABLE, as rows: `table` says a viewer sees it happen, so it has a mark in the script ([constant TableActions.REGISTRY], the same verb), and
## `about` is what the agent is told. `change` and `note` are only so.
const KINDS := {
	"roll": {"table": true, "label": "Roll", "blurb": "dice thrown from where a person sits, and what came up"},
	"move": {"table": true, "label": "Move", "blurb": "a figure taken to another place on the map"},
	"place": {"table": true, "label": "Place", "blurb": "a new figure set on the map"},
	"fall": {"table": true, "label": "Fall", "blurb": "a figure laid flat where it stands: down, not gone"},
	"rise": {"table": true, "label": "Rise", "blurb": "a fallen figure stood up again"},
	"remove": {"table": true, "label": "Remove", "blurb": "a figure taken off the map"},
	"map": {"table": true, "label": "Map", "blurb": "another map laid down: whatever stood on the last comes off"},
	"reveal": {"table": true, "label": "Reveal", "blurb": "a picture held up for the table to see"},
	"change": {"table": false, "label": "Change", "blurb": "something written on a sheet"},
	"over": {"table": false, "label": "Over", "blurb": "the game ends here"},
}
## What a map is measured in when the game does not say otherwise, and how big one may be (squares or units a side).
const UNIT := "square"
const SIDE_MOST := 40
const SIDE_LEAST := 4

## who -> {field: a number, a word or a list}
var sheets := {}
## A figure's name -> {at: [x, y], down, owner, looks, map}
var figures := {}
## Every map laid so far, in order: {name, looks, size: [w, h], grid, unit}. The last is on the table.
var maps: Array = []
## Every picture shown: {name, looks}
var reveals: Array = []
## What has happened, in order.
var events: Array = []
## The game has ended.
var over := false
var over_how := ""


## A ledger beginning from [param start_sheets], then all [param past] applied.
static func from(start_sheets: Dictionary, past: Array = []) -> GameLedger:
	var g := GameLedger.new()
	g.sheets = start_sheets.duplicate(true)
	for e in past:
		if e is Dictionary:
			g.apply(e)
	return g


## The id the next event takes: they run on across every scene of an episode, and a script's mark names one.
func next_id() -> int:
	return (int((events.back() as Dictionary).get("id", 0)) + 1) if not events.is_empty() else 1


## WHAT THE EVENT MAKES SO. Never fails: an event only reaches here having passed what made it, and an old one read again must not change what follows.
func apply(e: Dictionary) -> void:
	var what := String(e.get("kind", ""))
	match what:
		"change":
			_set_field(String(e.get("who", "")), String(e.get("field", "")), e.get("to"))
		"move":
			var f: Dictionary = figures.get(String(e.get("figure", "")), {})
			if not f.is_empty():
				f["at"] = e.get("to", f.get("at", [0, 0]))
		"place":
			figures[String(e.get("figure", ""))] = {"at": e.get("at", [0, 0]), "down": false, "owner": String(e.get("owner", "")),
				"looks": String(e.get("looks", "")), "map": maps.size() - 1}
		"fall", "rise":
			var f: Dictionary = figures.get(String(e.get("figure", "")), {})
			if not f.is_empty():
				f["down"] = what == "fall"
		"remove":
			figures.erase(String(e.get("figure", "")))
		"map":
			maps.append({"name": String(e.get("name", "")), "looks": String(e.get("looks", "")), "size": e.get("size", [20, 14]),
				"grid": bool(e.get("grid", true)), "unit": String(e.get("unit", UNIT))})
			figures.clear()
		"reveal":
			reveals.append({"name": String(e.get("name", "")), "looks": String(e.get("looks", ""))})
		"over":
			over = true
			over_how = String(e.get("how", ""))
	events.append(e)


func _set_field(who: String, field: String, to: Variant) -> void:
	if not sheets.has(who):
		sheets[who] = {}
	(sheets[who] as Dictionary)[field] = to


# --- what an agent asks for: each answers `{ok, event, words}`, and only an answer that is `ok` has happened -----------------------------------------------

## ROLL [param notation] for [param who], the [param n]th thing to happen in an episode of [param seed]. `hidden`: thrown behind a screen, so no number reaches anyone at the table but the one who threw it.
func roll(who: String, notation: String, why: String, seed: int, hidden := false) -> Dictionary:
	var id := next_id()
	var got := DiceNotation.roll(notation, hash([seed, "game", id]))
	if not bool(got["ok"]):
		return {"ok": false, "words": String(got["error"])}
	var e := {"id": id, "kind": "roll", "who": who, "notation": notation, "why": why, "hidden": hidden, "total": got["total"],
		"natural": got["natural"], "successes": got["successes"], "thrown": got["thrown"], "words": got["words"]}
	apply(e)
	return {"ok": true, "event": e, "words": String(got["words"])}


## A FIELD OF A SHEET, by a number (`by`, added), to a value (`to`), or a list's `add` or `remove`. Nothing about a field is checked but that the change makes sense for what is there.
func change(who: String, field: String, ask: Dictionary, why := "") -> Dictionary:
	if who.is_empty() or field.is_empty():
		return {"ok": false, "words": "a change names who and which field"}
	var have: Variant = (sheets.get(who, {}) as Dictionary).get(field)
	var to: Variant = have
	if ask.has("by"):
		if have != null and not (have is float or have is int):
			return {"ok": false, "words": "%s's %s is %s, not a number" % [who, field, str(have)]}
		to = float(have if have != null else 0) + float(ask["by"])
	elif ask.has("to"):
		to = ask["to"]
	elif ask.has("add") or ask.has("remove"):
		var list: Array = (have as Array).duplicate() if have is Array else ([] if have == null else [have])
		if ask.has("add"):
			list.append(ask["add"])
		if ask.has("remove"):
			if not list.has(ask["remove"]):
				return {"ok": false, "words": "%s's %s holds no \"%s\": %s" % [who, field, str(ask["remove"]), str(list)]}
			list.erase(ask["remove"])
		to = list
	else:
		return {"ok": false, "words": "a change says by, to, add or remove"}
	var e := {"id": next_id(), "kind": "change", "who": who, "field": field, "to": to, "was": have, "why": why}
	apply(e)
	return {"ok": true, "event": e, "words": "%s's %s: %s -> %s" % [who, field, _plain(have), _plain(to)]}


## A NEW MAP goes down. `size` in squares (or the free measure's units), `grid` false for a table measured with a tape.
func map_down(name: String, looks: String, size: Array, grid := true, unit := UNIT) -> Dictionary:
	if name.is_empty():
		return {"ok": false, "words": "a map needs a name"}
	var w := clampi(int(size[0]) if size.size() > 0 else 20, SIDE_LEAST, SIDE_MOST)
	var h := clampi(int(size[1]) if size.size() > 1 else 14, SIDE_LEAST, SIDE_MOST)
	var e := {"id": next_id(), "kind": "map", "name": name, "looks": looks, "size": [w, h], "grid": grid, "unit": unit}
	var off := figures.keys()
	apply(e)
	var said := "%s is on the table, %d x %d %ss" % [name, w, h, unit]
	if not off.is_empty():
		said += "; off the table: %s" % ", ".join(PackedStringArray(off))
	return {"ok": true, "event": e, "words": said}


## A NEW FIGURE on the map. `owner`: the person who plays it, if anyone does.
func place(figure: String, at: Array, looks: String, owner := "") -> Dictionary:
	if figure.is_empty():
		return {"ok": false, "words": "a figure needs a name"}
	if maps.is_empty():
		return {"ok": false, "words": "no map is on the table yet: lay one first"}
	if figures.has(figure):
		return {"ok": false, "words": "%s is on the map already, at %s" % [figure, _at(figures[figure]["at"])]}
	var bad := _off_map(at)
	if not bad.is_empty():
		return {"ok": false, "words": bad}
	var e := {"id": next_id(), "kind": "place", "figure": figure, "at": _clean_at(at), "looks": looks, "owner": owner}
	var shared := _standing_at(at)
	apply(e)
	var said := "%s stands at %s" % [figure, _at(at)]
	if not shared.is_empty():
		said += ", on the same spot as %s" % shared
	return {"ok": true, "event": e, "words": said}


## A FIGURE TAKEN SOMEWHERE ELSE: answered with how far, which is the one running the game's to judge.
func move(figure: String, to: Array) -> Dictionary:
	if not figures.has(figure):
		return {"ok": false, "words": "no figure called \"%s\" is on the map: %s" % [figure, ", ".join(PackedStringArray(figures.keys()))]}
	var f: Dictionary = figures[figure]
	var bad := _off_map(to)
	if not bad.is_empty():
		return {"ok": false, "words": bad}
	var from: Array = f["at"]
	var far := distance(from, to)
	var e := {"id": next_id(), "kind": "move", "figure": figure, "from": from.duplicate(), "to": _clean_at(to), "far": far}
	var shared := _standing_at(to, figure)
	apply(e)
	var said := "%s goes %s %ss, %s to %s" % [figure, String.num(far, 1), String((maps.back() as Dictionary)["unit"]), _at(from), _at(to)]
	if not shared.is_empty():
		said += ", onto the same spot as %s" % shared
	return {"ok": true, "event": e, "words": said}


## A figure down, up or off.
func figure_state(kind: String, figure: String) -> Dictionary:
	if not figures.has(figure):
		return {"ok": false, "words": "no figure called \"%s\" is on the map: %s" % [figure, ", ".join(PackedStringArray(figures.keys()))]}
	var down := bool((figures[figure] as Dictionary)["down"])
	if kind == "fall" and down:
		return {"ok": false, "words": "%s is down already" % figure}
	if kind == "rise" and not down:
		return {"ok": false, "words": "%s is standing" % figure}
	var e := {"id": next_id(), "kind": kind, "figure": figure}
	apply(e)
	return {"ok": true, "event": e, "words": "%s: %s" % [figure, String((KINDS[kind] as Dictionary)["label"]).to_lower()]}


## A PICTURE HELD UP.
func reveal(name: String, looks: String) -> Dictionary:
	if name.is_empty() or looks.is_empty():
		return {"ok": false, "words": "a picture needs a name and what it shows"}
	var e := {"id": next_id(), "kind": "reveal", "name": name, "looks": looks}
	apply(e)
	return {"ok": true, "event": e, "words": "%s is held up" % name}


## THE GAME IS OVER: however it came to that.
func end_game(how: String) -> Dictionary:
	var e := {"id": next_id(), "kind": "over", "how": how}
	apply(e)
	return {"ok": true, "event": e, "words": "the game is over"}


# --- reading it -------------------------------------------------------------------------------------------------------------------------------------

## HOW FAR from [param a] to [param b]: on squares, as most games count them, a diagonal one square; with a free measure, a straight line.
func distance(a: Array, b: Array) -> float:
	var grid := maps.is_empty() or bool((maps.back() as Dictionary).get("grid", true))
	var dx := absf(float(a[0]) - float(b[0]))
	var dy := absf(float(a[1]) - float(b[1]))
	return maxf(dx, dy) if grid else sqrt(dx * dx + dy * dy)


## Everything as it stands, as an agent reads it.
func describe() -> String:
	var out := PackedStringArray()
	out.append("SHEETS")
	for who in sheets:
		var fields := PackedStringArray()
		var s: Dictionary = sheets[who]
		for k in s:
			fields.append("%s: %s" % [k, _plain(s[k])])
		out.append("- %s: %s" % [who, "; ".join(fields)])
	if maps.is_empty():
		out.append("NO MAP on the table yet")
	else:
		var m: Dictionary = maps.back()
		out.append("THE MAP: %s, %s x %s %ss, (0, 0) at its far left and x to the right, y toward the viewer" % [String(m["name"]), str((m["size"] as Array)[0]), str((m["size"] as Array)[1]), String(m["unit"])])
		for name in figures:
			var f: Dictionary = figures[name]
			out.append("- %s at %s%s%s" % [name, _at(f["at"]), " (down)" if bool(f["down"]) else "", " (%s's)" % String(f["owner"]) if not String(f["owner"]).is_empty() else ""])
	if over:
		out.append("THE GAME IS OVER: %s" % over_how)
	return "\n".join(out)


func _off_map(at: Array) -> String:
	if at.size() < 2:
		return "a place on the map is [x, y]"
	if maps.is_empty():
		return "no map is on the table yet: lay one first"
	var size: Array = (maps.back() as Dictionary)["size"]
	if float(at[0]) < 0.0 or float(at[1]) < 0.0 or float(at[0]) >= float(size[0]) or float(at[1]) >= float(size[1]):
		return "%s is off the map, which runs 0 to %d across and 0 to %d down" % [_at(at), int(size[0]) - 1, int(size[1]) - 1]
	return ""


func _clean_at(at: Array) -> Array:
	var grid := maps.is_empty() or bool((maps.back() as Dictionary).get("grid", true))
	return [int(at[0]), int(at[1])] if grid else [float(at[0]), float(at[1])]


func _standing_at(at: Array, but := "") -> String:
	var found := PackedStringArray()
	for name in figures:
		if String(name) == but:
			continue
		if distance((figures[name] as Dictionary)["at"], at) < 0.5:
			found.append(String(name))
	return ", ".join(found)


static func _at(at: Variant) -> String:
	var a: Array = at if at is Array else [0, 0]
	return "(%s, %s)" % [_plain(a[0]), _plain(a[1])]


## A value as an agent reads it: 12, not 12.0.
static func _plain(v: Variant) -> String:
	if v == null:
		return "nothing"
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	if v is Array:
		return "[%s]" % ", ".join(PackedStringArray((v as Array).map(func(x: Variant) -> String: return _plain(x))))
	return str(v)

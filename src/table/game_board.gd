extends RefCounted
class_name GameBoard

## GameBoard - where a game stands on the table (next/tabletop.md): who sits where, where a map lies and how big its squares are, and a
## session's events gathered into what the table and the painter need. All of it is pure and names no game: a table reads it
## ([TableGame]), the bake reads it ([DiceBake]) and so does the set dresser's view of what to leave clear.
##
## A seat is degrees round the table (0 the far side, 90 the right, -90 the left, 180 at the viewer's elbow): one number, which says where
## their dice come from and, by its sine, which ear they are heard in (`seat`, a voice's row).
##
## Units: meters, on the table's own axes (x to the right, z toward the viewer), as [Tables] has them.

## The map's middle, and the most of the table it may cover: the middle of what the game's camera sees ([method CardTable.game_camera]), with room round it for dice and things.
const MIDDLE := Vector2(0.0, -0.03)
const MAP_MOST := Vector2(0.68, 0.44)
## A paper figure, as a share of a square's width (`card`), with a floor and a ceiling (meters): a figure a viewer cannot see is no figure, whatever the map's scale.
const FIGURE_SHARE := 0.95
const FIGURE_LEAST := 0.024
const FIGURE_MOST := 0.04
const FIGURE_TALL := 1.5
## Where each person keeps their dice, on an ellipse a little inside the picture, and where their hand starts a throw from, on one past it (half across, half down; a hand above the table by `THROW_UP`).
const HOME := Vector2(0.47, 0.25)
const HAND := Vector2(0.6, 0.38)
const THROW_UP := Vector2(0.09, 0.15)
## Where dice are thrown toward: what the camera sees, in from the frame's edge. A throw's end is looked for inside `LANDS`.
const AIM := Rect2(-0.26, -0.2, 0.52, 0.32)
const LANDS := Rect2(-0.48, -0.31, 0.96, 0.58)
## The table the game wants, in centimeters: anything smaller leaves its dice on the floor.
const TOP_LEAST := Vector2(150.0, 110.0)


## Where everyone sits, in degrees: what the voices say ([param given], by name), and otherwise spread round from the far side: the first is the one running the game, at its middle; the others on either hand.
static func seats_of(people: PackedStringArray, given: Dictionary) -> Dictionary:
	var out := {}
	var left := PackedStringArray()
	var right := PackedStringArray()
	var left_n := 0
	var right_n := 0
	for k in people.size():
		var who := people[k]
		if given.has(who) and absf(float(given[who])) > 0.5:
			out[who] = float(given[who])
			if float(given[who]) < 0.0:
				left_n += 1
			else:
				right_n += 1
	for k in people.size():
		var who := people[k]
		if out.has(who):
			continue
		if k == 0:
			out[who] = 0.0
		elif right_n <= left_n:
			right.append(who)
			right_n += 1
		else:
			left.append(who)
			left_n += 1
	for side in [[right, 1.0], [left, -1.0]]:
		var list: PackedStringArray = side[0]
		for i in list.size():
			var share := (float(i) + 0.5) / float(maxi(list.size(), 1))
			out[list[i]] = float(side[1]) * lerpf(50.0, 125.0, share)
	return out


## A seat's point on an ellipse of half-sizes [param half], about the map's middle.
static func at_seat(degrees: float, half: Vector2) -> Vector2:
	var a := deg_to_rad(degrees)
	return MIDDLE + Vector2(sin(a) * half.x, -cos(a) * half.y)


## Which ear they are heard in: -1 the left, 1 the right.
static func pan_of(degrees: float) -> float:
	return sin(deg_to_rad(degrees))


## How wide one square of [param map] is on the table (meters): as big as lets the whole map lie in the room it has.
static func cell_of(map: Dictionary) -> float:
	var size: Array = map.get("size", [20, 14])
	return minf(MAP_MOST.x / maxf(float(size[0]), 1.0), MAP_MOST.y / maxf(float(size[1]), 1.0))


## Where [param map] lies, on the table.
static func rect_of(map: Dictionary) -> Rect2:
	var size: Array = map.get("size", [20, 14])
	var cell := cell_of(map)
	var whole := Vector2(float(size[0]), float(size[1])) * cell
	return Rect2(MIDDLE - whole * 0.5, whole)


## The middle of the square at [param at] on [param map]: (0, 0) its far left. A free measure's place is a point, so it stands on it.
static func at_map(map: Dictionary, at: Array) -> Vector2:
	var cell := cell_of(map)
	var r := rect_of(map)
	var half := 0.5 if bool(map.get("grid", true)) else 0.0
	return r.position + Vector2((float(at[0]) + half) * cell, (float(at[1]) + half) * cell)


## How wide a figure on [param map] is, its card.
static func figure_width(map: Dictionary) -> float:
	return clampf(cell_of(map) * FIGURE_SHARE, FIGURE_LEAST, FIGURE_MOST)


## What nothing else stands on: as big as any map can lie.
static func keep_out() -> Array:
	return [Rect2(MIDDLE - MAP_MOST * 0.5, MAP_MOST).grow(0.015)]


## What the session came to, for the table and the painter: every event, who sits where with which dice, and each thing it asked to have painted, once by name (`maps`, `figures`, `reveals`, each `{name, looks, ...}`). An event is told which one by `pic`, its place in its list, 1 up.
static func gather(events: Array, people: PackedStringArray, prep: Dictionary, given_seats: Dictionary) -> Dictionary:
	var maps: Array = []
	var figures: Array = []
	var figure_pic := {}
	var reveals: Array = []
	var told: Array = []
	for e in events:
		var d: Dictionary = (e as Dictionary).duplicate()
		match String(d.get("kind", "")):
			"map":
				maps.append({"name": String(d.get("name", "")), "looks": String(d.get("looks", "")), "size": d.get("size", [20, 14]), "grid": bool(d.get("grid", true)), "unit": String(d.get("unit", GameLedger.UNIT))})
				d["pic"] = maps.size()
			"place":
				var name := String(d.get("figure", ""))
				if not figure_pic.has(name):
					figures.append({"name": name, "looks": String(d.get("looks", "")), "owner": String(d.get("owner", ""))})
					figure_pic[name] = figures.size()
				d["pic"] = int(figure_pic[name])
			"reveal":
				reveals.append({"name": String(d.get("name", "")), "looks": String(d.get("looks", ""))})
				d["pic"] = reveals.size()
		told.append(d)
	return {"events": told, "people": people, "seats": seats_of(people, given_seats), "dice": _dice_of(people, prep), "maps": maps, "figures": figures, "reveals": reveals}


## Whose dice are whose: as the preparation wrote them, made safe; everyone's unlike the rest's, by a color from a wheel if nobody said.
static func _dice_of(people: PackedStringArray, prep: Dictionary) -> Dictionary:
	var out := {}
	var all: Dictionary = prep.get("people", {}) if prep.get("people") is Dictionary else {}
	for k in people.size():
		var who := people[k]
		var got: Variant = null
		for name in all:
			if String(name).to_lower() == who.to_lower():
				got = (all[name] as Dictionary).get("dice") if all[name] is Dictionary else null
		var d: Dictionary = got if got is Dictionary else {}
		var material := String(d.get("material", "plastic")).to_lower()
		var hue := fposmod(0.61 + float(k) * 0.618, 1.0)
		var body := Color.from_hsv(hue, 0.62, 0.72)
		out[who] = {"material": material if Dice.MATERIALS.has(material) else "plastic",
			"color": String(d.get("color", "")) if Color.html_is_valid(String(d.get("color", ""))) else "#" + body.to_html(false),
			"ink": String(d.get("ink", "")) if Color.html_is_valid(String(d.get("ink", ""))) else "#f6efe0",
			"size": clampf(float(d.get("size", 1.0)), 0.7, 3.0)}
	return out


## What stands on the map at each throw: the figures, by their squares, as the events have them just before it. `[{id, figures: [{at: Vector2, w, down}]}]`, one a roll.
static func figures_at_rolls(game: Dictionary) -> Dictionary:
	var out := {}
	var map := {}
	var maps: Array = game.get("maps", [])
	var standing := {}
	for e in game.get("events", []):
		var d: Dictionary = e
		match String(d.get("kind", "")):
			"map":
				var pic := int(d.get("pic", 0)) - 1
				map = maps[pic] if pic >= 0 and pic < maps.size() else {}
				standing.clear()
			"place":
				standing[String(d.get("figure", ""))] = {"at": d.get("at", [0, 0]), "down": false}
			"move":
				if standing.has(String(d.get("figure", ""))):
					(standing[String(d.get("figure", ""))] as Dictionary)["at"] = d.get("to", [0, 0])
			"fall", "rise":
				if standing.has(String(d.get("figure", ""))):
					(standing[String(d.get("figure", ""))] as Dictionary)["down"] = String(d.get("kind", "")) == "fall"
			"remove":
				standing.erase(String(d.get("figure", "")))
			"roll":
				var now: Array = []
				if not map.is_empty():
					for name in standing:
						var f: Dictionary = standing[name]
						now.append({"at": at_map(map, f["at"]), "w": figure_width(map), "down": bool(f["down"])})
				out[int(d.get("id", 0))] = now
	return out


## What a bake is handed ([DiceBake]): every throw, in order, each from where its person sits, with their dice, and what stands in its way. `solids`, the things on the table as triangles (the caller's: a table standing has them).
static func bake_request(game: Dictionary, solids: Array, seed: int, out_path: String) -> Dictionary:
	var rolls: Array = []
	var seats: Dictionary = game.get("seats", {})
	var sets: Dictionary = game.get("dice", {})
	var standing := figures_at_rolls(game)
	for e in game.get("events", []):
		var d: Dictionary = e
		if String(d.get("kind", "")) != "roll":
			continue
		var who := String(d.get("who", ""))
		var set: Dictionary = sets.get(who, {"material": "plastic", "size": 1.0})
		var dice: Array = []
		for t in d.get("thrown", []):
			dice.append({"shape": int((t as Dictionary)["shape"]), "size": float(set.get("size", 1.0)), "material": String(set.get("material", "plastic"))})
		rolls.append({"id": int(d.get("id", 0)), "seat": float(seats.get(who, 0.0)), "dice": dice, "figures": standing.get(int(d.get("id", 0)), [])})
	var homes: Array = []
	for who in seats:
		homes.append(at_seat(float(seats[who]), HOME))
	return {"out": out_path, "seed": seed, "rolls": rolls, "solids": solids, "homes": homes}

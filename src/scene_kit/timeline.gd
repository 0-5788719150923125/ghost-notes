extends RefCounted
class_name Timeline

## Timeline - one document for what a show does when, whoever wrote it (next/editing.md, "The Timeline"). A storyboard
## is the Timeline a person wrote ([method Storyboard.timeline]); an episode's beats, acts and cues the one agents wrote
## ([method TableEpisode.timeline]). What reads it (the editor's dock, a problems list, a puppeteer) names neither.
##
## Plain data, so it round-trips through JSON and a gate holds it whole:
##
##   {clock, length, groups: [{id, label, start, length, engine, lanes: [{id, label, items: [item]}]}]}
##   item: {id, label, kind, at, length, engine, source}
##
## - `clock`: what show time is measured against ([constant CLOCKS]): the song, the voice's words, or plain seconds.
## - A group is one stretch of the show (a storyboard's entry, an episode's beat): its `start` and `length` in show seconds.
## - A lane is what its items happen to (an actor; a thing on the table); `id` "" for the group's own.
## - An item is a span (`length` > 0: a verb's window, an act) or a flag (`length` 0: a moment - a verb at a point, a
##   cue), `at` in seconds from its group's start ([constant KINDS]).
## - Its engine ([constant ENGINES]) says how it is reached at a moment: `time`, a pure function of show time, is shown
##   at any moment at once; `verb`, a latched simulation that may answer the music, is reached by playing its group
##   from its start. The group's is every item's that does not say.
## - `source`: where it is written, a [DataPath] into the document it was read from (a storyboard's tree, an episode's
##   `acts.json`), so an edit goes back to the one place it lives - never a second copy.

const CLOCKS := {
	"song": {"label": "Song", "blurb": "Seconds of the note's song: entries hold for seconds or leave on its beats."},
	"voice": {"label": "Voice", "blurb": "Seconds of the reading: beats are as long as their words take to say."},
	"seconds": {"label": "Seconds", "blurb": "Plain seconds, with nothing to follow."},
}
const ENGINES := {
	"time": {"label": "Function of time", "blurb": "Worked out from show time alone: shown at any moment at once, and the same every time."},
	"verb": {"label": "Simulation", "blurb": "Latched as it plays, and free to answer the music: reached at a moment by playing its stretch from the start."},
}
const KINDS := {
	"span": {"label": "Span", "blurb": "A window of time: something under way from its start for its length."},
	"flag": {"label": "Flag", "blurb": "A moment: something that happens at one time."},
}


## A Timeline on [param clock] of [param groups] (as [method group] makes them), its length where the last group ends.
static func make(clock: String, groups: Array) -> Dictionary:
	var end := 0.0
	for g in groups:
		end = maxf(end, float((g as Dictionary).get("start", 0.0)) + float((g as Dictionary).get("length", 0.0)))
	return {"clock": clock, "length": end, "groups": groups}


## A group [param id] called [param label], [param start] seconds into the show for [param length], its items' engine
## [param engine] unless one says otherwise, with no lanes yet ([method item] adds to them).
static func group(id: String, label: String, start: float, length: float, engine: String) -> Dictionary:
	return {"id": id, "label": label, "start": start, "length": length, "engine": engine, "lanes": []}


## [param it] added to [param g]'s lane [param lane] (made, called [param lane_label], the first time it is named).
static func add(g: Dictionary, lane: String, lane_label: String, it: Dictionary) -> void:
	for l in g["lanes"]:
		if String((l as Dictionary)["id"]) == lane:
			((l as Dictionary)["items"] as Array).append(it)
			return
	(g["lanes"] as Array).append({"id": lane, "label": lane_label, "items": [it]})


## An item: a span when [param length] > 0, else a flag; its engine its group's when [param engine] is "".
static func item(id: String, label: String, at: float, length: float, source: Array, engine := "") -> Dictionary:
	var out := {"id": id, "label": label, "kind": "span" if length > 0.0 else "flag", "at": at, "length": maxf(length, 0.0),
		"source": source}
	if not engine.is_empty():
		out["engine"] = engine
	return out


## The engine [param it] runs on, in [param g].
static func engine_of(g: Dictionary, it: Dictionary) -> String:
	return String(it.get("engine", g.get("engine", "time")))


## Whether [param it] in [param g] is shown at any moment at once ([constant ENGINES] `time`).
static func seekable(g: Dictionary, it: Dictionary) -> bool:
	return engine_of(g, it) == "time"


## What is under way at [param t] seconds of the show: `[{group, lane, item}]` - a span over it, or a flag within
## [param near] seconds of it.
static func at_time(tl: Dictionary, t: float, near := 0.05) -> Array:
	var out: Array = []
	for g in tl.get("groups", []):
		var gd: Dictionary = g
		var local := t - float(gd["start"])
		if local < -near or local > float(gd["length"]) + near:
			continue
		for l in gd["lanes"]:
			for it in (l as Dictionary)["items"]:
				var d: Dictionary = it
				var a := float(d["at"])
				var hit := absf(local - a) <= near if String(d["kind"]) == "flag" else (local >= a and local < a + float(d["length"]))
				if hit:
					out.append({"group": gd["id"], "lane": (l as Dictionary)["id"], "item": d})
	return out


## What is wrong with [param tl], in words - [] for nothing: a clock, kind or engine with no row, a group or item with no
## time of its own, an item that starts outside its group. The same list for a person and for an agent's tool.
static func check(tl: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (tl is Dictionary) or not ((tl as Dictionary).get("groups") is Array):
		out.append("a timeline is a map with a list of groups")
		return out
	if not CLOCKS.has(String((tl as Dictionary).get("clock", ""))):
		out.append("its clock \"%s\" is none of %s" % [str((tl as Dictionary).get("clock", "")), ", ".join(CLOCKS.keys())])
	for g in (tl as Dictionary)["groups"]:
		if not (g is Dictionary):
			out.append("a group is a map")
			continue
		var gd: Dictionary = g
		var gname := "group \"%s\"" % str(gd.get("id", ""))
		if float(gd.get("length", -1.0)) < 0.0 or float(gd.get("start", -1.0)) < 0.0:
			out.append("%s has no start or length of its own" % gname)
		if not ENGINES.has(String(gd.get("engine", ""))):
			out.append("%s runs on \"%s\", none of %s" % [gname, str(gd.get("engine", "")), ", ".join(ENGINES.keys())])
		for l in gd.get("lanes", []):
			for it in (l as Dictionary).get("items", []) if l is Dictionary else []:
				var d: Dictionary = it if it is Dictionary else {}
				var iname := "%s's item \"%s\"" % [gname, str(d.get("id", ""))]
				if not KINDS.has(String(d.get("kind", ""))):
					out.append("%s is a \"%s\", none of %s" % [iname, str(d.get("kind", "")), ", ".join(KINDS.keys())])
				if d.has("engine") and not ENGINES.has(String(d["engine"])):
					out.append("%s runs on \"%s\", none of %s" % [iname, str(d["engine"]), ", ".join(ENGINES.keys())])
				var a := float(d.get("at", -1.0))
				if a < 0.0 or a > float(gd.get("length", 0.0)) + 1e-3:
					out.append("%s starts at %.2f s, outside its group (0 to %.2f s)" % [iname, a, float(gd.get("length", 0.0))])
				if String(d.get("kind", "")) == "flag" and float(d.get("length", 0.0)) > 0.0:
					out.append("%s is a flag with a length" % iname)
	return out


## How [param key] of [param table] ([constant CLOCKS], [constant ENGINES], [constant KINDS]) is named, and said.
static func label_of(table: Dictionary, key: String) -> String:
	return Registry.label(table, key)


static func blurb_of(table: Dictionary, key: String) -> String:
	return Registry.blurb(table, key)

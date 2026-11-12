extends RefCounted
class_name DeskTable

## DeskTable - the table an episode shown at the desk is blocked on ([EpisodeDesk], next/desk.md): a legal pad of sheets and a
## pen, and nothing for a set dresser to build or a painter to paint. The desk the episode is seen at is the Letter's
## ([DeskLook]); this is only what the puppeteer writes on and with, so its acts name a pad's sheet and a pen as any table's
## do. Landed as a set dresser's table is ([method TableProducer._land_table]), made safe the same way.

## The pad's sheets: as many as a long lesson writes on, the next taken when one is full.
const SHEETS := 10


## The desk's table, as a set dresser would write it: `{idea, materials, things}`.
static func spec() -> Dictionary:
	var parts: Array = [{"at": [0.0, 0.0, 0.0], "material": "chipboard", "round": 0.05, "shape": "box", "size": [21.6, 0.15, 31.5]}]
	for k in range(SHEETS, 0, -1):
		parts.append({"at": [0.0, 0.16 + 0.01 * float(SHEETS - k), 0.9], "joint": {"kind": "free"}, "loose": true,
			"material": "canary paper", "name": "sheet %d" % k, "outline": "rect", "shape": "sheet", "size": [21.4, 29.0]})
	parts.append({"at": [0.0, 0.0, -14.45], "material": "oxblood binding", "round": 0.12, "shape": "box", "size": [21.9, 0.5, 2.6]})
	var pen := {"at": [0.0, 0.62, 6.65], "joint": {"kind": "free"}, "name": "pen",
		"parts": [{"material": "navy lacquer", "shape": "lathe", "smooth": true, "profile": [[0.0, 0.0], [0.45, 0.0, 0.2], [0.6, 0.6],
			[0.62, 5.0], [0.64, 5.05, 0.0], [0.64, 5.3, 0.0], [0.58, 5.35], [0.56, 9.0], [0.5, 9.6], [0.42, 10.6], [0.36, 11.0], [0.0, 11.05]]},
			{"at": [0.0, 10.8, 0.12], "material": "gold nib", "round": 0.02, "shape": "box", "size": [0.6, 1.9, 0.08], "taper": 0.8}],
		"points": {"grip": [0.0, 0.7, -2.5], "tip": [0.0, 0.7, -6.35]}, "turn": [-90.0, 0.0, 0.0]}
	return {"idea": "A desk with a legal pad and a pen: everything is written on the pad, a sheet at a time, by the pen.",
		"materials": {
			"canary paper": {"color": "#f3e9a6", "color2": "#d9c97a", "kind": "paper", "wear": 0.03},
			"chipboard": {"color": "#8f8676", "color2": "#6e6658", "kind": "paper", "wear": 0.2},
			"oxblood binding": {"color": "#7b3a26", "color2": "#5a2a1b", "kind": "paper", "polish": 0.25, "wear": 0.1},
			"navy lacquer": {"color": "#2b3a55", "kind": "painted", "polish": 0.85},
			"gold nib": {"color": "#b8954a", "kind": "metal", "polish": 0.5},
		},
		"things": [
			{"name": "legal pad", "group": "work", "at": [0.0, -2.0], "turn": 0.0, "parts": parts,
				"why": "where all the work is written, a sheet at a time"},
			{"name": "pen", "group": "work", "at": [15.0, 0.0], "turn": 18.0, "parts": [pen],
				"why": "does all the writing and all the pointing"},
		]}

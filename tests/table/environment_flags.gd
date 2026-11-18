extends RefCounted

## Not a gate. The Environment's block ([Surroundings]) from a look probe's command line: `--light K` (a preset, or `own`),
## `--bright X`, `--shafts k=v,...` (light shafts, each `k` one of their fields - `--shafts count=3,width=0.4,inner=2`; `--shafts -`
## every field drawn by its number; given again, another set of shafts), `--air a,b` and `--heard a,b` (kinds, each as its number
## draws it). A probe hands it each flag it does not read itself.

const FLAGS := ["--light", "--bright", "--shafts", "--air", "--heard"]


## Whether [param flag] is one of the Environment's.
static func reads(flag: String) -> bool:
	return flag in FLAGS


## Flag [param flag] at [param value] put into [param block] (a document's `environment`).
static func take(block: Dictionary, flag: String, value: String) -> void:
	if not block.has("elements"):
		block["elements"] = []
	var els: Array = block["elements"]
	match flag:
		"--light", "--bright":
			var light := {}
			for e in els:
				if String((e as Dictionary)["kind"]) == "light":
					light = e
			if light.is_empty():
				light = {"kind": "light", "preset": "own"}
				els.append(light)
			if flag == "--light":
				light["preset"] = value
			else:
				light["brightness"] = float(value)
		"--shafts":
			var el := {"kind": "shafts"}
			for kv in value.split(",", false):
				var v := kv.get_slice("=", 1)
				if kv.contains("="):
					el[kv.get_slice("=", 0)] = float(v) if v.is_valid_float() else v
			els.append(el)
		"--air", "--heard":
			for k in value.split(",", false):
				els.append({"kind": k})

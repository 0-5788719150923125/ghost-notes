extends RefCounted
class_name ActorPrompts

## ActorPrompts - what the Likeness's agents are told, and what is made of their answers
## (next/likeness.md, "The agents"). The words are in `rules/likeness/` ([Rules]); this fills them in
## and reads the answers - each answer checked before anything is kept, a malformed one sent back
## ([ActorBuilder]). Pure, so a gate reads every prompt whole and lands made-up answers.
##
##   audit     a set's contact sheets -> their look, shots of another look, unusable shots
##   rest      a set's stills on one sheet -> the ones that show them at ease, most at ease first
##
## The gestures, their habits and the director went with the first build's footage (2026-10-21, night):
## a still plays no hand. They may come back as the head's own gestures.


# --- the audit -------------------------------------------------------------------------------------

## The audit of set [param set_d] of [param name]'s footage: `{system, prompt}` (the caller adds the
## sheets). [param more]: the set has more shots than its sheets show.
static func audit(name: String, set_d: Dictionary, more: bool) -> Dictionary:
	var v := {"name": name, "shots": str((set_d.get("shots", []) as Array).size()),
		"minutes": str(snappedf(float(set_d.get("minutes", 0.0)), 0.1)), "more": more}
	return {"system": Rules.say("likeness/audit.system", v), "prompt": Rules.say("likeness/audit.prompt", v)}


## The audit's answer [param d] for a set of [param shots] shots, made sound: `{look, other: {shots,
## look}, unusable: [{shot, why}]}` with every number a shot of the set - or `{error}`.
static func land_audit(d: Dictionary, shots: int) -> Dictionary:
	var look := str(d.get("look", "")).strip_edges()
	if look.is_empty():
		return {"error": "the audit says nothing of their look"}
	var other: Dictionary = d.get("other", {}) if d.get("other") is Dictionary else {}
	var other_shots: Array = []
	for n in (other.get("shots", []) if other.get("shots") is Array else []):
		if (n is float or n is int) and int(n) >= 1 and int(n) <= shots and not other_shots.has(int(n)):
			other_shots.append(int(n))
	var unusable: Array = []
	for u in (d.get("unusable", []) if d.get("unusable") is Array else []):
		if u is Dictionary and ((u as Dictionary).get("shot") is float or (u as Dictionary).get("shot") is int):
			var n := int((u as Dictionary)["shot"])
			if n >= 1 and n <= shots:
				unusable.append({"shot": n, "why": str((u as Dictionary).get("why", "")).strip_edges()})
	return {"look": look, "other": {"shots": other_shots, "look": str(other.get("look", "")).strip_edges()},
		"unusable": unusable}


## SET [param set_d] AS THE AUDIT [param part] SAW IT: its look, its unusable shots marked and out of
## its usable minutes - and, where some shots are of another look, those shots as a set of their own.
## The sets it is, in order.
static func apply_audit(set_d: Dictionary, part: Dictionary) -> Array:
	var shots: Array = set_d.get("shots", [])
	var other: Array = (part.get("other", {}) as Dictionary).get("shots", [])
	var why := {}
	for u in part.get("unusable", []):
		why[int((u as Dictionary)["shot"])] = String((u as Dictionary)["why"])
	var main := set_d.duplicate(true)
	var split := set_d.duplicate(true)
	var mine: Array = []
	var theirs: Array = []
	for i in shots.size():
		var sh: Dictionary = (shots[i] as Dictionary).duplicate(true)
		sh["number"] = i + 1
		if why.has(i + 1):
			sh["unusable"] = true
			sh["why"] = why[i + 1]
		(theirs if other.has(i + 1) else mine).append(sh)
	main["shots"] = mine
	main["look"] = String(part["look"])
	main["audited"] = true
	main["usable"] = _usable(mine)
	main["excluded"] = why.size()
	var out: Array = [main]
	if not theirs.is_empty():
		split["id"] = String(set_d["id"]) + "-b"
		split["shots"] = theirs
		split["look"] = String((part.get("other", {}) as Dictionary).get("look", ""))
		split["audited"] = true
		split["usable"] = _usable(theirs)
		split["split_from"] = String(set_d["id"])
		out.append(split)
	return out


static func _usable(shots: Array) -> float:
	var m := 0.0
	for sh in shots:
		if not bool((sh as Dictionary).get("unusable", false)):
			m += float((sh as Dictionary).get("usable", 0.0))
	return snappedf(m / 60.0, 0.01)


# --- the stills at rest ----------------------------------------------------------------------------

## Which of [param count] stills of [param name] show them at rest: `{system, prompt}` (the caller adds the
## sheet).
static func rest(name: String, count: int) -> Dictionary:
	var v := {"name": name, "count": str(count)}
	return {"system": Rules.say("likeness/rest.system", v), "prompt": Rules.say("likeness/rest.prompt", v)}


## The answer [param d] for [param count] stills, made sound: `{rest: [still index from 0, ...]}`, each a
## still once, in the answer's order - or `{error}`.
static func land_rest(d: Dictionary, count: int) -> Dictionary:
	if not (d.get("rest") is Array):
		return {"error": "the answer names no stills at rest"}
	var out: Array = []
	for n in d["rest"]:
		if (n is float or n is int) and int(n) >= 1 and int(n) <= count and not out.has(int(n) - 1):
			out.append(int(n) - 1)
	return {"rest": out}

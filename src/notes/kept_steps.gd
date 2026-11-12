extends RefCounted
class_name KeptSteps

## KeptSteps - AN EPISODE'S STEPS, KEPT, NEVER DELETED (next/editing.md step 1; the user, 2026-11-10: "there is no easy way to fix
## mistakes without regenerating steps"), for every show that makes episodes a step at a time ([TableEpisode]: step
## 12, "the other shows take step 1"). Each step made is recorded in `steps.json` - who made it (a role, `code`, or a `hand`), when,
## a digest of its file and of each file it was made from ([method made_from]) - and whatever replaces or throws away a step's file
## first moves it a version back (`versions/<step>/vNNN/`, the newest [constant VERSIONS_KEPT]: [method keep_version], [method
## restore]). So a step made from something changed since is STALE ([method stale]): it still plays, and Generate makes it again
## unless it is KEPT ([method kept]) - its row's 🔒, or a file changed since it was made (a hand's edit). ⟳ makes one step again
## and throws nothing away: what was made from it goes stale.
##
## AN EPISODE MADE BEFORE RECORDS has none until it is first worked on ([method adopt]): every made step is recorded as it stands,
## and one whose file changed after its job ended is kept (732687's passages, edited by hand and re-cued on 11-09 and 11-10).
## Nothing is written by reading: a probe or a render never writes here.
##
## WHAT AN EPISODE SAYS OF ITSELF, which a show's episode answers: its folder ([member dir]), its steps in order ([method steps]),
## each one's file ([method file_of]) and the files that go with it ([method files_of]), what each is made from ([method needs],
## [method made_from]) and where its agent's job ran ([method job_dir]).

## The episode's folder, absolute.
var dir := ""


## Every step the episode makes, in the order it makes them.
func steps() -> Array:
	return []


## [param step]'s file, absolute - "" for no such step.
func file_of(_step: String) -> String:
	return ""


## A step exists when its file does: every write lands by rename, so a file that is there is whole.
func has(step: String) -> bool:
	var p := file_of(step)
	return not p.is_empty() and FileAccess.file_exists(p)


## The steps [param step] is made from.
func needs(_step: String) -> Array:
	return []


## The folder a step's agent job runs in - kept, with its prompt.
func job_dir(step: String) -> String:
	return dir.path_join("jobs").path_join(step.replace(":", "_"))


## The files [param step] is: its own, and what comes with it.
func files_of(step: String) -> Array:
	var p := file_of(step)
	return [] if p.is_empty() else [p]


## A version was put back: whatever the episode caches of its steps' files is forgotten.
func _changed() -> void:
	pass


const RECORD_FILE := "steps.json"
const VERSIONS_DIR := "versions"
const VERSIONS_KEPT := 5
## A file this much newer than its job's last file was changed after the job made it ([method adopt]).
const CHANGED_AFTER_S := 60
## A file modified this recently is hashed again, whatever the cache says ([method _digest_of]).
const FRESH_S := 2.0

var _record_stamp := "-"
var _record := {}
var _digests := {}       # path -> [mtime, size, sha256]


## What [param step]'s file is, as a sha256 - "" with none. Read again only when the file changes.
func digest(step: String) -> String:
	return _digest_of(file_of(step))


func _digest_of(p: String) -> String:
	if p.is_empty() or not FileAccess.file_exists(p):
		return ""
	var mt := FileAccess.get_modified_time(p)
	var size := FileAccess.get_size(p)
	var c: Array = _digests.get(p, [])
	# ...A FILE CHANGED IN THE LAST SECONDS IS READ AGAIN: a modified time is whole seconds, so an edit within the same second
	# that keeps the size (a length 5.0 made 9.0) read as the same file - no Undo recorded, the step not kept (thing_inspector_check)
	if c.size() == 3 and int(c[0]) == mt and int(c[1]) == size and Time.get_unix_time_from_system() - float(mt) > FRESH_S:
		return String(c[2])
	var sha := FileAccess.get_sha256(p)
	_digests[p] = [mt, size, sha]
	return sha




## WHAT [param step] IS MADE FROM, AS IT STANDS: each made step it needs -> its digest.
func made_from(step: String) -> Dictionary:
	var out := {}
	for n in needs(step):
		if has(String(n)):
			out[String(n)] = digest(String(n))
	return out


## Every step's record: step -> {by, at, digest, from, kept, versions}. {} before [method adopt].
func records() -> Dictionary:
	var p := dir.path_join(RECORD_FILE)
	var stamp := "%d|%d" % [FileAccess.get_modified_time(p), FileAccess.get_size(p)] if FileAccess.file_exists(p) else ""
	if stamp != _record_stamp:
		_record_stamp = stamp
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if not stamp.is_empty() else null
		_record = (d as Dictionary).get("steps", {}) if d is Dictionary and (d as Dictionary).get("steps") is Dictionary else {}
	return _record


## [param step]'s record, {} for none.
func record(step: String) -> Dictionary:
	var r: Variant = records().get(step, {})
	return r if r is Dictionary else {}


func _write_records(all: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var err := _put(dir.path_join(RECORD_FILE), JSON.stringify({"steps": all}, "\t"))
	_record_stamp = "-"
	return err


## Written atomically: beside it, then renamed over.
static func _put(p: String, text: String) -> String:
	var f := FileAccess.open(p + ".part", FileAccess.WRITE)
	if f == null:
		return "could not write " + p
	f.store_string(text)
	f.close()
	return "" if DirAccess.rename_absolute(p + ".part", p) == OK else "could not move %s into place" % p


## RECORDS FOR AN EPISODE MADE BEFORE THEM: every made step as it stands, made from what stands now - kept where its file changed
## after its job ended. Once: an episode with records keeps them. "" done, else why not.
func adopt() -> String:
	if FileAccess.file_exists(dir.path_join(RECORD_FILE)) or not DirAccess.dir_exists_absolute(dir):
		return ""
	var all := {}
	for st in steps():
		var s := String(st)
		if has(s):
			all[s] = {"by": "", "at": FileAccess.get_modified_time(file_of(s)), "digest": digest(s), "from": made_from(s),
				"kept": _changed_after_job(s)}
	return _write_records(all)


func _changed_after_job(step: String) -> bool:
	var jd := job_dir(step)
	if not DirAccess.dir_exists_absolute(jd):
		return false
	var newest := 0
	for f in DirAccess.get_files_at(jd):
		newest = maxi(newest, FileAccess.get_modified_time(jd.path_join(f)))
	return newest > 0 and FileAccess.get_modified_time(file_of(step)) > newest + CHANGED_AFTER_S


## [param step] MADE, by [param by] (a role, `code`, `hand`), from [param from] (what it was made from when its making began,
## [method made_from]; now, when empty). Its 🔒 stays as it was. "" recorded, else why not.
func note_made(step: String, by: String, from := {}) -> String:
	adopt()
	var all := records().duplicate(true)
	var was: Dictionary = all.get(step, {}) if all.get(step) is Dictionary else {}
	all[step] = {"by": by, "at": int(Time.get_unix_time_from_system()), "digest": digest(step),
		"from": from if not from.is_empty() else made_from(step), "kept": bool(was.get("kept", false)),
		"versions": was.get("versions", [])}
	return _write_records(all)


## WHETHER [param step] IS MADE FROM SOMETHING THAT HAS CHANGED SINCE: a step it was made from stands now with another digest.
## A step with no record, or a need thrown away, is not stale: nothing says what it was made from.
func stale(step: String) -> bool:
	if not has(step):
		return false
	var from: Variant = record(step).get("from")
	if not (from is Dictionary):
		return false
	for n in from:
		if has(String(n)) and digest(String(n)) != String((from as Dictionary)[n]):
			return true
	return false


## WHETHER GENERATE PASSES [param step] BY, stale or not: its 🔒 ([method set_kept]), or its file changed since it was made.
func kept(step: String) -> bool:
	var r := record(step)
	return bool(r.get("kept", false)) or changed_by_hand(step)


## Whether [param step]'s file is not what was made: changed since, by a hand or a tool outside the producer.
func changed_by_hand(step: String) -> bool:
	var was := String(record(step).get("digest", ""))
	return has(step) and not was.is_empty() and digest(step) != was


## [param step] kept ([param on]) or given back to Generate - and then, changed by a hand, taken as it is now. "" written.
func set_kept(step: String, on: bool) -> String:
	adopt()
	var all := records().duplicate(true)
	var r: Dictionary = all.get(step, {}) if all.get(step) is Dictionary else {}
	r["kept"] = on
	if not on and has(step):
		r["digest"] = digest(step)
	all[step] = r
	return _write_records(all)


## WHETHER [param step] IS MADE BY HAND (next/editing.md step 8: "a step marked BY HAND, where Generate stops and says it waits"):
## a person makes it, never an agent unasked - Generate passes it by, made or not, and its row says it waits. A ⟳ still hands it to
## its agent, and what the agent makes is the agent's ([method note_made] drops the mark).
func by_hand(step: String) -> bool:
	return bool(record(step).get("hand", false))


## [param step] marked made by hand ([param on]) or given back to its agent. "" written.
func set_by_hand(step: String, on: bool) -> String:
	adopt()
	var all := records().duplicate(true)
	var r: Dictionary = all.get(step, {}) if all.get(step) is Dictionary else {}
	r["hand"] = on
	all[step] = r
	return _write_records(all)


## [param step]'S FILES A VERSION BACK, as they stand - copied, or moved with [param move] (what throws it away). The same as the
## newest version already kept is not kept twice; past [constant VERSIONS_KEPT] the oldest goes. "" kept or nothing to keep.
func keep_version(step: String, move := false) -> String:
	if not has(step):
		return ""
	adopt()
	var all := records().duplicate(true)
	var r: Dictionary = all.get(step, {}) if all.get(step) is Dictionary else {}
	var list: Array = (r.get("versions", []) as Array).duplicate()
	var now := digest(step)
	var base := dir.path_join(VERSIONS_DIR).path_join(step.replace(":", "_"))
	if not list.is_empty() and String((list.back() as Dictionary).get("digest", "")) == now \
			and DirAccess.dir_exists_absolute(base.path_join(String((list.back() as Dictionary).get("dir", "")))):
		if move:
			for f in files_of(step):
				DirAccess.remove_absolute(String(f))
		return ""
	var n := 1
	for v in list:
		n = maxi(n, int(String((v as Dictionary).get("dir", "v0")).trim_prefix("v")) + 1)
	var name := "v%03d" % n
	DirAccess.make_dir_recursive_absolute(base.path_join(name))
	for f in files_of(step):
		var src := String(f)
		if not FileAccess.file_exists(src):
			continue
		var dst := base.path_join(name).path_join(src.get_file())
		var err := DirAccess.rename_absolute(src, dst) if move else DirAccess.copy_absolute(src, dst)
		if err != OK:
			return "could not keep %s a version back (error %d)" % [src.get_file(), err]
	list.append({"dir": name, "digest": now, "by": String(r.get("by", "")), "at": int(r.get("at", 0)), "from": r.get("from", {})})
	while list.size() > VERSIONS_KEPT:
		_remove_tree(base.path_join(String((list.pop_front() as Dictionary).get("dir", ""))))
	r["versions"] = list
	all[step] = r
	return _write_records(all)


## [param step]'s versions kept, oldest first: [{dir, digest, by, at, from}] whose folder is there.
func versions(step: String) -> Array:
	var base := dir.path_join(VERSIONS_DIR).path_join(step.replace(":", "_"))
	return (record(step).get("versions", []) as Array).filter(func(v: Variant) -> bool:
		return v is Dictionary and DirAccess.dir_exists_absolute(base.path_join(String((v as Dictionary).get("dir", "")))))


## VERSION [param i] OF [param step] PUT BACK ([method versions]): what stands goes a version back first, and the one put back is
## KEPT - a person chose it - made from what it was made from. "" done, else why not.
func restore(step: String, i: int) -> String:
	var list := versions(step)
	if i < 0 or i >= list.size():
		return "there is no version %d of %s" % [i + 1, step]
	var v: Dictionary = list[i]
	var src := dir.path_join(VERSIONS_DIR).path_join(step.replace(":", "_")).path_join(String(v["dir"]))
	var err := keep_version(step)
	if not err.is_empty():
		return err
	for f in DirAccess.get_files_at(src):
		var dst := dir.path_join(String(f))
		if DirAccess.copy_absolute(src.path_join(String(f)), dst + ".part") != OK or DirAccess.rename_absolute(dst + ".part", dst) != OK:
			return "could not put %s back" % String(f)
	var all := records().duplicate(true)
	var r: Dictionary = all.get(step, {}) if all.get(step) is Dictionary else {}
	r.merge({"by": String(v.get("by", "")), "at": int(v.get("at", 0)), "digest": digest(step), "from": v.get("from", {}), "kept": true}, true)
	all[step] = r
	_changed()
	return _write_records(all)


## EVERY STEP'S VERSIONS, NEWEST FIRST, for a list to put one back from: `[{at, said, key: [step, i]}]`, [param name_of]
## (`(step) -> String`) naming a step as its card does.
func step_versions(name_of := Callable()) -> Array:
	var out: Array = []
	# (every step with a record - what keeps its versions - whether or not the plan lists it now)
	for st in records():
		var s := String(st)
		var vs := versions(s)
		for i in vs.size():
			var v: Dictionary = vs[i]
			var by := String(v.get("by", ""))
			var who := "yours" if by == "hand" else ("made by the %s" % by if not by.is_empty() and by != "code" else "as it was")
			out.append({"at": float(v.get("at", 0)), "key": [s, i],
				"said": "%s, %s" % [String(name_of.call(s)) if name_of.is_valid() else s, who]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) > float(b["at"]))
	return out


static func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)

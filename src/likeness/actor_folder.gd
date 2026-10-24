extends RefCounted
class_name ActorFolder

## Actor - one actor of the [Actors] library, as it lies on disk (next/likeness.md, "The actor's
## folder"): `actor.json` (their name, their sources and their videos, which are ticked, the chosen set
## and each set's still) and a folder per thing a step covers - each video's (`videos/<vid>/`), the actor's own
## (the folder itself) and each set's (`sets/<set>/`). EVERY STEP IS FILES ([constant
## ActorSteps.REGISTRY]'s `outputs`), and beside them, in the same folder's `steps.json`, what each
## was made from.
##
## WHAT A STEP WAS MADE FROM is a fingerprint ([method inputs_of]): the step, its version, the
## settings it reads, and the TOKEN of every output it read - a token being new each time a step is
## made. So a step made again makes everything made from it stale, a changed setting makes the steps
## that read it stale, and a video ticked or unticked makes the sets stale. A stale output is still
## used ([method state_of] says "stale", never "missing") until it is made again.

const FILE := "actor.json"
const STAMPS := "steps.json"
const VIDEO_EXTS := ["mp4", "mkv", "webm", "mov", "m4v", "avi"]

var id := ""
## Absolute.
var dir := ""
var data := {}
## What was read of the folders since the last [method forget]: a card asks for every step's state
## a few times a second, and each reads the stamps of what it is made from.
var _cache := {}
## FILES PARSED, kept while they stand unchanged on disk (their time and size): the audit, the stamps,
## the stills, the motion - asked for many times a refresh, four refreshes a second, at a millisecond or more a
## read (2026-10-21: the two cards held the main thread 57 ms every quarter second). A write through
## [method write_file] drops its own. Shared by every [ActorFolder] - and A WORKER READS IT TOO (the Actor card
## works its rows out off the main thread, on a folder of its own: 2026-10-23, "We shouldn't be blocking the main
## thread for ANY operation"), so it is touched under [member _kept_lock] alone, never while a file is read.
static var _kept := {}
static var _kept_lock := Mutex.new()


static func blank(name: String) -> Dictionary:
	return {"name": name, "sources": [], "videos": {}, "set": "", "stills": {}, "settings": {}}


static func open(actor_id: String) -> ActorFolder:
	if actor_id.is_empty():
		return null
	var a := ActorFolder.new()
	a.id = actor_id
	a.dir = ProjectSettings.globalize_path(Actors.root.path_join(actor_id))
	if not FileAccess.file_exists(a.dir.path_join(FILE)):
		return null
	a.reload()
	return a


## Read `actor.json` again.
func reload() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(FILE)))
	data = blank("")
	if d is Dictionary:
		data.merge(d as Dictionary, true)
	for k in ["sources"]:
		if not (data[k] is Array):
			data[k] = []
	for k in ["videos", "settings", "stills"]:
		if not (data[k] is Dictionary):
			data[k] = {}


## Write `actor.json`, whole, through a temporary name. "" once written, else why not. Its videos stay
## in the order they were added: written sorted, they came back in another order after a restart.
func save() -> String:
	return write_file(dir.path_join(FILE), JSON.stringify(data, "\t", false))


## Write [param text] at [param path] through a temporary name, so nothing reads half of it.
static func write_file(path: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var part := path + ".part"
	var f := FileAccess.open(part, FileAccess.WRITE)
	if f == null:
		return "could not write %s" % path.get_file()
	f.store_string(text)
	f.close()
	_kept_lock.lock()
	_kept.erase(path)
	_kept_lock.unlock()
	if DirAccess.rename_absolute(part, path) != OK:
		return "could not put %s in place" % path.get_file()
	return ""


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## [method read_json], kept while the file is unchanged ([member _kept]). What it returns is shared:
## never change it.
static func read_kept(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_kept_lock.lock()
		_kept.erase(path)
		_kept_lock.unlock()
		return null
	var stamp := "%d|%d" % [FileAccess.get_modified_time(path), FileAccess.get_size(path)]
	_kept_lock.lock()
	var had: Array = _kept.get(path, [])
	_kept_lock.unlock()
	if had.size() == 2 and String(had[0]) == stamp:
		return had[1]
	var v: Variant = read_json(path)
	_kept_lock.lock()
	_kept[path] = [stamp, v]
	_kept_lock.unlock()
	return v


func name() -> String:
	return String(data.get("name", id))


func settings() -> Dictionary:
	return ActorSteps.settings_of(data.get("settings", {}))


# --- the videos ----------------------------------------------------------------------------------

## A folder video's id: its path and size, hashed - so the same file is the same video, and a file
## replaced by another of the same name is not.
static func vid_of_file(path: String, size: int) -> String:
	return "f-" + ("%s|%d" % [path, size]).sha1_text().substr(0, 10)


## A linked video's id: its id on the site.
static func vid_of_link(entry: String) -> String:
	var safe := ""
	for c in entry:
		safe += c if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "-" or c == "_" else "_"
	return "yt-" + safe


func videos() -> Dictionary:
	return data["videos"]


func video(vid: String) -> Dictionary:
	return (data["videos"] as Dictionary).get(vid, {})


## The ticked videos, in the order they were added - a linked one whether or not it is fetched yet.
func ticked() -> Array:
	var out: Array = []
	for vid in data["videos"]:
		if bool((data["videos"][vid] as Dictionary).get("ticked", true)):
			out.append(String(vid))
	return out


## Is [param vid] a linked video (fetched into `footage/`), rather than one read in its folder?
func is_link(vid: String) -> bool:
	return not String(video(vid).get("url", "")).is_empty()


## The video's file, "" while a linked one is not fetched.
func video_path(vid: String) -> String:
	var p := String(video(vid).get("path", ""))
	return p if not p.is_empty() and FileAccess.file_exists(p) else ""


func footage_dir() -> String:
	return dir.path_join("footage")


func video_dir(vid: String) -> String:
	return dir.path_join("videos").path_join(vid)


func set_dir(sid: String) -> String:
	return dir.path_join("sets").path_join(sid)


func sheets_dir() -> String:
	return dir.path_join("sheets")


# --- the sets ------------------------------------------------------------------------------------

## THE SETS AS THEY STAND: the audit's, once it has looked (it may split a set, and says each one's
## look), else the clustering's. Shared ([method read_kept]): never change them.
func sets() -> Array:
	var au: Variant = read_kept(dir.path_join("audit.json"))
	if au is Dictionary and (au as Dictionary).get("sets") is Array:
		return (au as Dictionary)["sets"]
	var st: Variant = read_kept(dir.path_join("sets.json"))
	if st is Dictionary and (st as Dictionary).get("sets") is Array:
		return (st as Dictionary)["sets"]
	return []


func set_of(sid: String) -> Dictionary:
	for s in sets():
		if String((s as Dictionary).get("id", "")) == sid:
			return s
	return {}


## THE CHOSEN SET: the one picked on the card while it is still a set, else the steady one with the
## most usable minutes (a handheld one only where there is no other). "" before there are sets.
func chosen_set() -> String:
	var all := sets()
	var picked := String(data.get("set", ""))
	var best := ""
	var most := -INF
	for s in all:
		var d: Dictionary = s
		if String(d.get("id", "")) == picked:
			return picked
		var score := float(d.get("usable", 0.0)) - (1000.0 if bool(d.get("handheld", false)) else 0.0)
		if score > most:
			most = score
			best = String(d.get("id", ""))
	return best


# --- what a step covers, and what it made ----------------------------------------------------------

## Where a step's outputs for [param scope] are: a video's folder ("v:<vid>"), a set's ("s:<set>"),
## or the actor's own ("").
func scope_dir(scope: String) -> String:
	if scope.begins_with("v:"):
		return video_dir(scope.substr(2))
	if scope.begins_with("s:"):
		return set_dir(scope.substr(2))
	return dir


## What one run of [param step] covers, now: each ticked video, the actor, or the chosen set.
func scopes_of(step: String) -> Array:
	match ActorSteps.per(step):
		"video":
			return ticked().map(func(v: String) -> String: return "v:" + v)
		"set":
			var sid := chosen_set()
			return [] if sid.is_empty() else ["s:" + sid]
	return [""]


## The scopes of [param need] that a run of a step over [param scope] reads.
func _need_scopes(need: String, scope: String) -> Array:
	if ActorSteps.per(need) == "video" and scope.begins_with("v:"):
		return [scope]
	return scopes_of(need)


func _stamps(scope: String) -> Dictionary:
	var d: Variant = read_kept(scope_dir(scope).path_join(STAMPS))
	return (d as Dictionary).duplicate(true) if d is Dictionary else {}


## Forget what was read: the next question reads the folders again.
func forget() -> void:
	_cache = {}


func stamp_of(step: String, scope: String) -> Dictionary:
	return _stamps(scope).get(step, {})


## [param step] is made for [param scope]: its stamp written with what it was made from, a new token
## and [param summary] - a few words for the card.
func put_stamp(step: String, scope: String, summary := "") -> String:
	if step == "stills" and scope.begins_with("s:"):
		forget_still(scope.substr(2))
	var all := _stamps(scope)
	all[step] = {"inputs": inputs_of(step, scope), "token": ("%d|%d|%s" % [Time.get_ticks_usec(), randi(), step]).sha1_text().substr(0, 12),
		"at": int(Time.get_unix_time_from_system()), "summary": summary}
	forget()
	return write_file(scope_dir(scope).path_join(STAMPS), JSON.stringify(all, "\t"))


## [param step]'s outputs for [param scope] thrown away, and its stamp: ⟳ makes it again, and
## what was made from it is stale once it is.
func drop(step: String, scope: String) -> void:
	for f in ActorSteps.outputs(step):
		var p := scope_dir(scope).path_join(String(f))
		if DirAccess.dir_exists_absolute(p):
			Actors._remove_tree(p)
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var all := _stamps(scope)
	forget()
	if all.has(step):
		all.erase(step)
		write_file(scope_dir(scope).path_join(STAMPS), JSON.stringify(all, "\t"))


## Is [param step] moot for [param scope]? A folder video has nothing to fetch, one with no captions link
## no captions, and one with captions nothing to transcribe.
func moot(step: String, scope: String) -> bool:
	if not scope.begins_with("v:"):
		return false
	match step:
		"fetch":
			return not is_link(scope.substr(2))
		"captions":
			return String(video(scope.substr(2)).get("captions_url", "")).is_empty()
		"transcribe":
			return FileAccess.file_exists(String(video(scope.substr(2)).get("captions", "")))
		"head_frames":
			# a video with no usable shot of theirs in any set has no moments for their head - known once the
			# sets are audited (before, every video would be, and their head made of none)
			return not stamp_of("audit", "").is_empty() and head_shots(scope.substr(2)).is_empty()
	return false


## THE SHOTS OF VIDEO [param vid] ITS MOMENTS ARE READ FROM, for their head ([ActorBuilder], head_frames): the
## usable ones of the set it fills most - one camera placement, its room learned whole - `[[start, end], ...]`;
## none when no set holds a usable shot of it (the audit not made yet, or nothing of theirs in it).
func head_shots(vid: String) -> Array:
	var best: Array = []
	var most := 0.0
	for s in sets():
		var mine: Array = []
		var usable := 0.0
		for sh in (s as Dictionary).get("shots", []):
			var x: Dictionary = sh
			if String(x.get("vid", "")) != vid or bool(x.get("unusable", false)):
				continue
			mine.append([float(x.get("start", 0.0)), float(x.get("end", 0.0))])
			usable += float(x.get("usable", 0.0))
		if usable > most:
			most = usable
			best = mine
	return best


## The token [param step] made [param scope] with: what a step made from it records. A folder
## video's fetch is the file itself - its path, size and time.
func token_of(step: String, scope: String) -> String:
	if (step == "captions" or step == "transcribe" or step == "head_frames") and moot(step, scope):
		return ""
	if moot(step, scope):
		var key := "file:" + scope
		if not _cache.has(key):
			var p := video_path(scope.substr(2))
			var f := FileAccess.open(p, FileAccess.READ) if not p.is_empty() else null
			# named by where it was first found: a file moved to another of their folders is the same video
			var named := String(video(scope.substr(2)).get("found_at", p))
			_cache[key] = "" if f == null else "file:%s|%d|%d" % [named, f.get_length(), FileAccess.get_modified_time(p)]
		return String(_cache[key])
	var st := stamp_of(step, scope)
	return String(st.get("token", "")) if outputs_made(step, scope) else ""


## Are [param step]'s outputs for [param scope] on disk?
func outputs_made(step: String, scope: String) -> bool:
	if step == "fetch":
		return not video_path(scope.substr(2)).is_empty() and not stamp_of(step, scope).is_empty()
	if step == "captions":
		return FileAccess.file_exists(String(video(scope.substr(2)).get("captions", ""))) \
			and not stamp_of(step, scope).is_empty()
	for f in ActorSteps.outputs(step):
		var p := scope_dir(scope).path_join(String(f))
		if not FileAccess.file_exists(p) and not DirAccess.dir_exists_absolute(p):
			return false
	return true


## WHAT [param step] OVER [param scope] WOULD BE MADE FROM NOW, as a fingerprint: the step, its
## version, its settings, and the tokens of what it reads. A captions file found later is a new
## input to a video's words. WHAT IS READ, NEVER IN WHAT ORDER: the videos a step reads go in by id
## (2026-10-21: listed in the order they were held, a restart that held them in another made the
## user's built set stale - the sets, the audit and every step of the set, its track too).
func inputs_of(step: String, scope: String) -> String:
	var row: Dictionary = ActorSteps.REGISTRY.get(step, {})
	var parts: Array = [step, int(row.get("version", 1))]
	var s := settings()
	for k in row.get("settings", []):
		parts.append("%s=%s" % [k, str(s.get(k))])
	for need in row.get("needs", []):
		var read := _need_scopes(String(need), scope)
		read.sort()
		for sc in read:
			parts.append("%s@%s=%s" % [need, sc, token_of(String(need), String(sc))])
	if step == "words" and scope.begins_with("v:"):
		var cap := String(video(scope.substr(2)).get("captions", ""))
		parts.append("captions=%s|%d" % [cap, FileAccess.get_modified_time(cap) if FileAccess.file_exists(cap) else 0])
	if step == "audit" or ActorSteps.per(step) == "set":
		parts.append("set=" + scope)
	# a body fitted to one still is stale once another is picked
	if step == "fit" and scope.begins_with("s:"):
		parts.append("still=%d" % still_of(scope.substr(2)))
	return JSON.stringify(parts).sha256_text().substr(0, 16)


## "made", "stale" or "missing" - and "made" for a moot step.
func state_of(step: String, scope: String) -> String:
	if moot(step, scope):
		return "made" if step == "captions" or not video_path(scope.substr(2)).is_empty() else "missing"
	if not outputs_made(step, scope):
		return "missing"
	var st := stamp_of(step, scope)
	if st.is_empty():
		return "missing"
	return "made" if String(st.get("inputs", "")) == inputs_of(step, scope) else "stale"


## A few words of what [param step] made for [param scope].
func summary_of(step: String, scope: String) -> String:
	return String(stamp_of(step, scope).get("summary", ""))


## Every scope of [param step] made (stale included): a step over each video reads "5/8".
func made_count(step: String) -> Vector2i:
	var all := scopes_of(step)
	var n := 0
	for sc in all:
		if state_of(step, String(sc)) != "missing":
			n += 1
	return Vector2i(n, all.size())


## Can set [param set_id] (the chosen one by default) be played by [param renderer] - every step it reads,
## made (stale or not)?
func playable(set_id := "", renderer := "2d") -> bool:
	var sid := set_id if not set_id.is_empty() else chosen_set()
	if sid.is_empty():
		return false
	for step in ActorSteps.plays(renderer):
		if state_of(String(step), "s:" + sid if ActorSteps.per(String(step)) == "set" else "") == "missing":
			return false
	return true


## THE STILLS of set [param sid] (`stills.json`, [method read_kept]: never change them): `[{file, thumb,
## points, light, ...}]`, the best first.
func stills_of(sid: String) -> Array:
	var d: Variant = read_kept(set_dir(sid).path_join("stills.json"))
	return (d as Dictionary).get("stills", []) if d is Dictionary else []


## WHICH OF SET [param sid]'S STILLS A LIKENESS IS DRAWN ON: the one picked on the card while there is
## one, else the one most at rest ([method rest_of]), else the best.
func still_of(sid: String) -> int:
	var n := stills_of(sid).size()
	var picked: Variant = (data.get("stills", {}) as Dictionary).get(sid, null) if data.get("stills") is Dictionary else null
	if (picked is int or picked is float) and int(picked) >= 0 and int(picked) < n:
		return int(picked)
	var rest := rest_of(sid)
	return int(rest[0]) if not rest.is_empty() else 0


## THE STILLS OF SET [param sid] THAT SHOW THEM AT REST, most at ease first (`rest.json`, the writer's
## answer: the fourth pass) - every one a still the set has.
func rest_of(sid: String) -> Array:
	var d: Variant = read_kept(set_dir(sid).path_join("rest.json"))
	var n := stills_of(sid).size()
	var out: Array = []
	for k in ((d as Dictionary).get("rest", []) if d is Dictionary and (d as Dictionary).get("rest") is Array else []):
		if (k is int or k is float) and int(k) >= 0 and int(k) < n:
			out.append(int(k))
	return out


## Set [param sid]'s stills were made again ([method put_stamp]): what was picked of the last ones is no
## pick of these.
func forget_still(sid: String) -> void:
	if data.get("stills") is Dictionary and (data["stills"] as Dictionary).has(sid):
		(data["stills"] as Dictionary).erase(sid)
		save()


## Draw set [param sid]'s Likeness on its still [param k] - nothing is made again: the library is the
## set's, matched to each still's light as it is drawn.
func set_still(sid: String, k: int) -> void:
	if not (data.get("stills") is Dictionary):
		data["stills"] = {}
	(data["stills"] as Dictionary)[sid] = k

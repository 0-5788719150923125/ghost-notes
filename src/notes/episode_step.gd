extends RefCounted
class_name EpisodeStep

## EpisodeStep - a step one card adds to the episodes another card makes: a row in that card's list
## of steps, with its ✓ once made and its ⟳ to make it again, made by Generate along with the rest (the
## user, 2026-10-18: "add an interface that would allow other cards (like the YouTube one) to hook-in to
## that list, to add their own step - such that we could add a nice little checkmark ... and a
## regenerate button next to that step"). The YouTube card's tags are the first ([YouTubeTags]).
##
## THE CARDS NEVER MEET ([EpisodeFeed]). A card offers its steps (`episode_steps()`), the panel collects
## them ([method ReadingPanel.episode_steps]), and the card that makes episodes lists the ones
## [method wanted], hands each the episode as a feed, and calls it at its own moments: Generate
## ([method generate]), ⟳ ([method redo]), Stop ([method stop]), and every refresh ([method tick],
## [method listed]). It never asks what a step is, and a step never asks what made the episode.
##
## MADE FROM THE EPISODE'S WORDS, BY ONE AGENT JOB, once they are written: the step's prompt
## ([method _prompt]) goes to the maker's own writer ([method EpisodeFeed.writer]), and the answer,
## landed ([method _land]), is KEPT IN THE EPISODE'S FOLDER - `<key>.json`, its job under `jobs/<key>` -
## so deleting the episode takes it along. It is kept with the fingerprint of the words it was made
## from: WORDS WRITTEN AGAIN MAKE IT STALE ([method fresh]), so a maker that rewrites its reading need
## not know what was made from it - the step shows as not made, and Generate makes it again.
##
## A step of another kind sets its names and overrides [method _prompt], [method _land] and
## [method summary].

## A job that fails is tried this many more times before the step stops on it.
const RETRIES := 1

## Its key: its file in the episode's folder (`<key>.json`) and its job's folder (`jobs/<key>`).
var key := ""
## Its name in the list.
var label := ""
## What its ⟳ says once it is made...
var again := ""
## ...and before.
var first := ""
## What its row says while the episode's words are not written yet...
var waits := "made once the episode's words are written"
## ...and once they are, before it is made.
var unmade := "not made for this episode yet"
## The writer's tier for its job ([constant TextGen.TIERS]).
var tier := "best"
## THE CARD LISTING IT now, as that card names itself ("the Episode card"), and the episode it shows -
## set at every refresh by whoever lists it ([method listed]); "" and null while nothing does. What lets
## the card that offers the step say where it is.
var host := ""
var shown: EpisodeFeed = null

var _jobs := {}      # folder -> {id, feed, stamp}: a job making it for that episode
var _errors := {}    # folder -> why it failed, once out of tries
var _tries := {}     # folder -> runs started
var _kept := {}      # file -> {mt, data}: what was read, read again only when the file changes


## Of [param steps] (what the panel collected), the ones a maker lists now.
static func listed_of(steps: Array) -> Array:
	return steps.filter(func(s: Variant) -> bool: return s is EpisodeStep and (s as EpisodeStep).wanted())


## Whether it is a step at all now - a card's own switch (the YouTube card's box). Off, it is not listed,
## made or used; what it made is kept for when it is on again.
func wanted() -> bool:
	return true


## The card listing it says so, each refresh: its name ([param by]) and the episode it shows.
func listed(by: String, feed: EpisodeFeed) -> void:
	host = by
	shown = feed


## The file it is kept in for [param feed]'s episode; "" with no episode.
func file_in(feed: EpisodeFeed) -> String:
	var dir := feed.folder() if feed != null else ""
	return dir.path_join(key + ".json") if not dir.is_empty() else ""


## What is kept for the episode, as landed and with `from` (the words' fingerprint) - {} for nothing.
func made(feed: EpisodeFeed) -> Dictionary:
	var path := file_in(feed)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var mt := FileAccess.get_modified_time(path)
	var c: Dictionary = _kept.get(path, {})
	if c.is_empty() or int(c["mt"]) != mt:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		c = {"mt": mt, "data": d if d is Dictionary else {}}
		_kept[path] = c
	return c["data"]


## Made from the episode's words as they are now.
func fresh(feed: EpisodeFeed) -> bool:
	var m := made(feed)
	var now := feed.stamp() if feed != null else ""
	return not m.is_empty() and not now.is_empty() and String(m.get("from", "")) == now


## "ready", "running", "queued", "failed" or "missing" - the states a maker's own steps are in.
func state(feed: EpisodeFeed) -> String:
	var dir := feed.folder() if feed != null else ""
	if _jobs.has(dir):
		return "running" if AgentJobs.state(String((_jobs[dir] as Dictionary)["id"])) == "running" else "queued"
	if _errors.has(dir):
		return "failed"
	return "ready" if fresh(feed) else "missing"


## What its row says: what was made, what its agent is doing, why it failed, or what it waits for.
func said(feed: EpisodeFeed) -> String:
	if feed == null:
		return ""
	match state(feed):
		"ready":
			return summary(made(feed))
		"running", "queued":
			return "writer " + AgentJobs.activity(String((_jobs[feed.folder()] as Dictionary)["id"]))
		"failed":
			return String(_errors[feed.folder()])
	if feed.words().is_empty():
		return waits
	if not made(feed).is_empty():
		return "made from the words before they were written again - Generate or ⟳ makes it again"
	return unmade


## Whether a job is making it for [param feed]'s episode.
func busy(feed: EpisodeFeed) -> bool:
	return feed != null and _jobs.has(feed.folder())


## GENERATE: made unless it is made already - from the episode's words, so not before they are written.
## True when it is made, being made or started; false while the words are not written.
func generate(feed: EpisodeFeed) -> bool:
	if feed == null or feed.words().is_empty():
		return false
	if wanted() and not busy(feed) and not fresh(feed):
		_errors.erase(feed.folder())
		_tries.erase(feed.folder())
		_start(feed)
	return true


## ⟳: made again now. What was made stays until the new one lands, and a run that fails leaves it.
## False while the episode's words are not written.
func redo(feed: EpisodeFeed) -> bool:
	if feed == null or feed.words().is_empty():
		return false
	stop(feed)
	_errors.erase(feed.folder())
	_tries.erase(feed.folder())
	_start(feed)
	return true


## STOP: a job making it for the episode is cancelled; what was made is kept.
func stop(feed: EpisodeFeed) -> void:
	var dir := feed.folder() if feed != null else ""
	if not _jobs.has(dir):
		return
	var id := String((_jobs[dir] as Dictionary)["id"])
	AgentJobs.cancel(id)
	AgentJobs.forget(id)
	_jobs.erase(dir)


## Land what ended, each refresh: kept, tried once more, or stopped on with why.
func tick() -> void:
	for dir in _jobs.keys():
		var job: Dictionary = _jobs[dir]
		var id := String(job["id"])
		var st := AgentJobs.state(id)
		if st == "queued" or st == "running":
			continue
		var res := AgentJobs.result(id)
		AgentJobs.forget(id)
		_jobs.erase(dir)
		var err := "the job was lost" if st.is_empty() else ""
		if st == "failed":
			err = String(res.get("error", "the job failed"))
		elif st == "done":
			var got: Variant = _land(String(res.get("text", "")), job["feed"])
			err = _keep(job["feed"], got as Dictionary, String(job["stamp"])) if got is Dictionary else str(got)
		if err.is_empty():
			_errors.erase(dir)
			continue
		push_warning("ghost: %s - %s" % [key, err])
		if int(_tries.get(dir, 0)) > RETRIES:
			_errors[dir] = err
		else:
			_start(job["feed"])


func _start(feed: EpisodeFeed) -> void:
	var dir := feed.folder()
	_tries[dir] = int(_tries.get(dir, 0)) + 1
	var p := _prompt(feed)
	if not p.has("system") or not p.has("prompt"):
		_errors[dir] = "its prompt could not be built (see the log)"
		return
	var w := feed.writer()
	var id := AgentJobs.submit({"kind": "text", "backend": String(w.get("agent", "claude")), "tier": tier,
		"dir": dir.path_join("jobs").path_join(key), "system": String(p["system"]), "prompt": String(p["prompt"]),
		"label": "%s %s" % [label.to_lower(), dir.get_file()], "model": String(w.get("model", "")),
		"effort": String(w.get("effort", ""))})
	if id.is_empty():
		_errors[dir] = "this session cannot start agents (read-only)"
		return
	_jobs[dir] = {"id": id, "feed": feed, "stamp": feed.stamp()}


## What landed, kept with the fingerprint of the words its job was sent ([param stamp]).
func _keep(feed: EpisodeFeed, got: Dictionary, stamp: String) -> String:
	var d := got.duplicate(true)
	d["from"] = stamp
	return _write(feed, d)


## Written ATOMICALLY, as every step of an episode is: a file that exists is a step that is done.
func _write(feed: EpisodeFeed, d: Dictionary) -> String:
	var path := file_in(feed)
	if path.is_empty():
		return "the episode has no folder"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not write " + path
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		return "could not move %s into place" % path
	_kept.erase(path)      # a second write within the file clock's second must be read again
	return ""


# --- what a step of another kind says ------------------------------------------------------------

## The job's `{system, prompt}` for [param feed]'s episode, {} when it cannot be built.
func _prompt(_feed: EpisodeFeed) -> Dictionary:
	return {}


## The writer's answer [param text], as kept (a Dictionary), or why it cannot be (a String).
func _land(_text: String, _feed: EpisodeFeed) -> Variant:
	return "nothing is landed for this step"


## What its row says of what was made ([param m], as kept).
func summary(_m: Dictionary) -> String:
	return "made"

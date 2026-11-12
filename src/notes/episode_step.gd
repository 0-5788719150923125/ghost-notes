extends RefCounted
class_name EpisodeStep

## EpisodeStep - a thing one card makes from the episode another card makes: a row of the note's Pipeline card
## ([EpisodeSteps], [PipelineCard]), with its ✓ once made and its ⟳ to make it again, made by Generate after the words
## it is made from. The YouTube card's tags are the first ([YouTubeTags]).
##
## The cards never meet ([EpisodeFeed]): a card hands its steps as a section ([EpisodeSteps]), and the panel says which
## episode is shown ([method ReadingPanel.episode_feed]). The section lists the ones [method wanted] and calls each at
## its moments: Generate ([method generate]), ⟳ ([method redo]), Stop ([method stop]), and every refresh ([method tick],
## [method listed]). A step never asks what made the episode.
##
## It is made from the episode's words by one agent job, once they are written: the step's prompt ([method _prompt])
## goes to the maker's own writer ([method EpisodeFeed.writer]), and the answer, landed ([method _land]), is kept in
## the episode's folder (`<key>.json`, its job under `jobs/<key>`), so deleting the episode takes it along. It is kept
## with the fingerprint of the words it was made from: words written again make it stale ([method fresh]) and Generate
## makes it again, unless what it made is a choice kept ([method owed]; [YouTubeThumbnail]), in which case it says it
## is older than the words and only its ⟳ makes another.
##
## A step of another kind sets its names and overrides [method _prompt], [method _land] and [method summary] - and,
## where the writer's answer is a brief for another agent (a painter's), [method _after] and [method _land_after]: the
## second job runs before anything is kept, so a step is made only once all of it is ([YouTubeThumbnail]). Its writer
## is the maker's unless it names its own ([method _writer]).

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
## The episode it is listed for now, set at every refresh ([method listed]); null while not listed. Lets the card that
## offers the step say how it stands for the episode shown.
var shown: EpisodeFeed = null

var _jobs := {}      # folder -> {id, feed, stamp}: a job making it for that episode
var _errors := {}    # folder -> why it failed, once out of tries
var _tries := {}     # folder -> runs started
var _kept := {}      # file -> {mt, data}: what was read, read again only when the file changes


## Of [param steps], the ones listed now.
static func listed_of(steps: Array) -> Array:
	return steps.filter(func(s: Variant) -> bool: return s is EpisodeStep and (s as EpisodeStep).wanted())


## Whether it is a step at all now - a card's own switch (the YouTube card's box). Off, it is not listed, made or used;
## what it made is kept for when it is on again.
func wanted() -> bool:
	return true


## Listed for [param feed]'s episode, said each refresh.
func listed(feed: EpisodeFeed) -> void:
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


## Whether Generate, or an export that goes up, makes it for [param feed]'s episode: while it is not made from the
## words as they are ([method fresh]). A step whose making is a choice answers for itself ([YouTubeThumbnail]: only
## while none is painted).
func owed(feed: EpisodeFeed) -> bool:
	return not fresh(feed)


## Is it still to make for [param feed]'s episode - being made, failed, or [method owed]? What Generate waits on
## ([method EpisodeSteps.missing_on]).
func to_make(feed: EpisodeFeed) -> bool:
	var st := state(feed)
	return st != "ready" and (st != "missing" or owed(feed))


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
			var job: Dictionary = _jobs[feed.folder()]
			return "%s %s" % [String(job.get("who", "writer")), AgentJobs.activity(String(job["id"]))]
		"failed":
			return String(_errors[feed.folder()])
	if feed.words().is_empty():
		return waits
	if not made(feed).is_empty():
		return ("made from the words before they were written again - ⟳ makes it again, and so does %s" % feed.made_by()) \
			if owed(feed) else "made from the words before they were written again, and kept - ⟳ makes another"
	return unmade


## Whether a job is making it for [param feed]'s episode.
func busy(feed: EpisodeFeed) -> bool:
	return feed != null and _jobs.has(feed.folder())


## Generate: made unless it is made already, from the episode's words, so not before they are written. True when it is
## made, being made or started; false while the words are not written.
func generate(feed: EpisodeFeed) -> bool:
	if feed == null or feed.words().is_empty():
		return false
	if wanted() and not busy(feed) and owed(feed):
		_errors.erase(feed.folder())
		_tries.erase(feed.folder())
		_start(feed)
	return true


## ⟳: made again now. What was made stays until the new one lands, and a run that fails leaves it. False while the
## episode's words are not written.
func redo(feed: EpisodeFeed) -> bool:
	if feed == null or feed.words().is_empty():
		return false
	stop(feed)
	_errors.erase(feed.folder())
	_tries.erase(feed.folder())
	_start(feed)
	return true


## Stop: a job making it for the episode is cancelled; what was made is kept.
func stop(feed: EpisodeFeed) -> void:
	var dir := feed.folder() if feed != null else ""
	if not _jobs.has(dir):
		return
	var id := String((_jobs[dir] as Dictionary)["id"])
	AgentJobs.cancel(id)
	AgentJobs.forget(id)
	_jobs.erase(dir)


## Land what ended, each refresh: kept, handed on to the job after it ([method _after]), tried once more,
## or stopped on with why.
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
			var feed: EpisodeFeed = job["feed"]
			var got: Variant = _land_after(res, job["got"], feed) if job.has("got") \
				else _land(String(res.get("text", "")), feed)
			var after := _after(got as Dictionary, feed) if got is Dictionary and not job.has("got") else {}
			if not after.is_empty():
				err = _submit(feed, after, String(job["stamp"]), got)
				if err.is_empty():
					continue
			else:
				err = _keep(feed, got as Dictionary, String(job["stamp"])) if got is Dictionary else str(got)
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
	var w := _writer(feed)
	var err := _submit(feed, {"kind": "text", "backend": String(w.get("agent", "claude")), "tier": tier,
		"system": String(p["system"]), "prompt": String(p["prompt"]), "images": p.get("images", []),
		"model": String(w.get("model", "")), "effort": String(w.get("effort", ""))}, feed.stamp())
	if not err.is_empty():
		_errors[dir] = err


## The job [param spec] queued for [param feed]'s episode, in a folder of its own under the episode's `jobs/` - the
## writer's, or the one after it, [param got] what the writer's answer was landed as, [param stamp] the words' it was
## made from. "" once queued, else why not.
func _submit(feed: EpisodeFeed, spec: Dictionary, stamp: String, got: Variant = null) -> String:
	var dir := feed.folder()
	var job := spec.duplicate()
	var kind := String(spec.get("kind", "text"))
	job["dir"] = dir.path_join("jobs").path_join(key if got == null else "%s_%s" % [key, kind])
	job["label"] = "%s %s" % [label.to_lower(), dir.get_file()]
	var id := AgentJobs.submit(job)
	if id.is_empty():
		return "this session cannot start agents (read-only)"
	_jobs[dir] = {"id": id, "feed": feed, "stamp": stamp, "who": "writer" if kind == "text" else "painter"}
	if got != null:
		_jobs[dir]["got"] = got
	return ""


## What landed, kept with the fingerprint of the words its job was sent ([param stamp]).
func _keep(feed: EpisodeFeed, got: Dictionary, stamp: String) -> String:
	var d := got.duplicate(true)
	d["from"] = stamp
	return _write(feed, d)


## Written atomically, as every step of an episode is: a file that exists is a step that is done.
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

## The job's `{system, prompt}` for [param feed]'s episode - and `images`, the pictures the writer is
## shown ([method TextGen.Backend], `images`) - {} when it cannot be built.
func _prompt(_feed: EpisodeFeed) -> Dictionary:
	return {}


## Who writes it, `{agent, model, effort}`: the maker's own writer ([method EpisodeFeed.writer]).
func _writer(feed: EpisodeFeed) -> Dictionary:
	return feed.writer()


## The writer's answer [param text], as kept (a Dictionary), or why it cannot be (a String).
func _land(_text: String, _feed: EpisodeFeed) -> Variant:
	return "nothing is landed for this step"


## The job after the writer's, for the answer landed as [param got]: an [AgentJobs] spec (its `kind`, `backend`,
## `prompt`... - its folder is the step's), or {} when the answer is kept as it is.
func _after(_got: Dictionary, _feed: EpisodeFeed) -> Dictionary:
	return {}


## What that job's result [param res] ([method AgentJobs.result]) makes of [param got]: as kept, or why
## it cannot be.
func _land_after(_res: Dictionary, _got: Dictionary, _feed: EpisodeFeed) -> Variant:
	return "nothing is landed after this step"


## What its row says of what was made ([param m], as kept).
func summary(_m: Dictionary) -> String:
	return "made"

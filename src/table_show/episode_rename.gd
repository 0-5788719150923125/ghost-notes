extends RefCounted
class_name EpisodeRename

## EpisodeRename - a person of a table show called by another name in everything its episodes made: the script and its
## passages, what was played (who threw, whose turn, whose seat and dice), the preparation, the plan, what was heard, and what is
## still to be painted - every word file at an episode's top ([constant KINDS]), the name matched whole and in its own case. The
## voice's settings and the brief are the cast's ([method ReadingCast.rename_voice], [method EpisodeWalk.rename_read]).
##
## A rename is no step's making: every record is carried over ([method KeptSteps.carry_over]), so what was stale stays stale and
## nothing else goes stale; each step whose file changes is kept a version back first. The take is said again from the script as
## it now stands, and only the lines that say the name are new ([TakeCache]). Refused while an episode is being made, and where
## the new name is someone already (the brief or an episode names it), for a rename back would then merge two people.

## The word files a rename reads and rewrites.
const KINDS := ["json", "txt", "md"]
## ...but never these: the records, and the take's own (said again from the script).
const SKIP := ["steps.json", "take.json"]
## What a name may not hold: a mark's, a file's quoting, or a replacement's.
const BAD := ["\"", "\\", "$", "<", ">", "[", "]", "{", "}", "|", "\n", "\r", "\t"]


## [param text] with [param old], whole and in its own case, called [param new].
static func replaced(text: String, old: String, new: String) -> String:
	return text if old.is_empty() else _rx(old).sub(text, new, true)


## Whether [param text] names [param name] (whole, in its own case).
static func names(text: String, name: String) -> bool:
	return not name.is_empty() and _rx(name).search(text) != null


static func _rx(name: String) -> RegEx:
	var esc := ""
	for c in name:
		esc += ("\\" + c) if ".^$*+?()[]{}|\\/".contains(c) else c
	return RegEx.create_from_string("(?<![\\p{L}\\p{N}_])" + esc + "(?![\\p{L}\\p{N}_])")


## Every episode of [param ep]'s show with a plan, [param ep] itself among them (its caches are the card's).
static func episodes_of(ep: TableEpisode) -> Array:
	var out: Array = [ep]
	for h in TableEpisode.history(ep.show):
		var s := int((h as Dictionary)["seed"])
		if s != ep.seed:
			out.append(TableEpisode.open(ep.show, s))
	return out


## Why [param old] may not be called [param new] in [param eps] and the brief [param words], "" where it may.
static func refused(eps: Array, old: String, new: String, words: String) -> String:
	var name := new.strip_edges()
	for b in BAD:
		if name.contains(String(b)):
			return "a person's name cannot hold quotes, brackets, bars or slashes"
	if name == old:
		return ""
	if names(words, name):
		return "the brief names %s already: a rename back would make them one person" % name
	for e in eps:
		var ep := e as TableEpisode
		var p := TableProducer.of(ep)
		if p.running or p.busy():
			return "an episode is being made: rename once it is done"
		for step in ["plan", "prep", "game", "script"]:
			var f := ep.file_of(step)
			if not f.is_empty() and FileAccess.file_exists(f) and names(FileAccess.get_file_as_string(f), name):
				return "episode %d names %s already: a rename back would make them one person" % [ep.seed, name]
	return ""


## [param old] called [param new] in every episode of [param eps]. "" done, else why not (the episodes before it are renamed).
static func rename(eps: Array, old: String, new: String) -> String:
	for e in eps:
		var ep := e as TableEpisode
		if not DirAccess.dir_exists_absolute(ep.dir):
			continue
		# ...a page recorded as made from the whole script is first made from its own picture, as a save of the script does
		var err := ep.pages_own_pictures()
		if err.is_empty():
			err = ep.carry_over(func() -> String: return _rewrite(ep, old, new))
		if not err.is_empty():
			return "episode %d: %s" % [ep.seed, err]
	return ""


static func _rewrite(ep: TableEpisode, old: String, new: String) -> String:
	var owner := {}
	for st in ep.steps():
		for f in ep.files_of(String(st)):
			owner[String(f)] = String(st)
	for f in DirAccess.get_files_at(ep.dir):
		var file := String(f)
		if not KINDS.has(file.get_extension()) or SKIP.has(file):
			continue
		var path := ep.dir.path_join(file)
		var text := FileAccess.get_file_as_string(path)
		var now := replaced(text, old, new)
		if now == text:
			continue
		if owner.has(path):
			var kept := ep.keep_version(String(owner[path]))
			if not kept.is_empty():
				return kept
		var out := FileAccess.open(path + ".part", FileAccess.WRITE)
		if out == null:
			return "could not write " + file
		out.store_string(now)
		out.close()
		if DirAccess.rename_absolute(path + ".part", path) != OK:
			return "could not move %s into place" % file
	return ""

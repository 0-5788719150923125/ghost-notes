extends RefCounted
class_name ActorSources

## ActorSources - where an actor's videos come from (next/likeness.md, "Sources"): a FOLDER, read in
## place and never copied or written, a FILE picked by itself (read in place too), or a LINK - a video, a
## playlist or a channel - listed first and then fetched one video at a time into the actor's `footage/`
## (a voice alone's as its sound: [method ActorFolder.sound_only]). A link added CAPTIONS ONLY fetches no
## video: each of its captions files is matched to a folder video by title, so a folder of their videos
## downloaded long ago gets the word times its captions carry without the gigabytes fetched again.
##
## Pure where it can be (a folder's videos, a title made comparable, captions read into words, the
## arguments yt-dlp is given), so a gate reads it without a process; [ActorBuilder] runs what it says.

## THE FORMAT FETCHED: up to 1080p, H.264 and AAC where the site has them (what Eidolon fetched), else
## the best up to 1080p.
const FORMAT := "bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=1080]"
## A VOICE ALONE'S SOUND: the best AAC the site has (on YouTube, its 128 kbps .m4a), else its best sound.
const SOUND_FORMAT := "ba[acodec^=mp4a]/ba"
## AUTOMATIC CAPTIONS CARRY A TIME FOR EVERY WORD (json3's `tOffsetMs`): the words a viseme is
## learned from.
const SUB_LANGS := "en.*"
## The captions tracks taken, in order of preference: the original automatic ones first.
const SUB_PREFER := ["en-orig", "en", "en-US", "en-GB"]
## A word's end is the next word's start, but never longer than this (seconds).
const WORD_MOST := 0.6


## THE VIDEOS IN [param folder], not below it - the files of [param exts] (a voice alone's are sound files too,
## [method ActorFolder.exts]): `[{path, size, title}]`, by name.
static func scan(folder: String, exts: Array = ActorFolder.VIDEO_EXTS) -> Array:
	var out: Array = []
	var d := DirAccess.open(folder)
	if d == null:
		return out
	for f in d.get_files():
		if not exts.has(f.get_extension().to_lower()) or f.begins_with("."):
			continue
		out.append_array(scan_file(folder.path_join(f)))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["path"]).naturalnocasecmp_to(String(b["path"])) < 0)
	return out


## THE FILE AT [param path] as a scan finds it: `[{path, size, title}]`, empty while it is not there.
static func scan_file(path: String) -> Array:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return []
	return [{"path": path, "size": fa.get_length(), "title": title_of_file(path.get_file())}]


## A file's name as a title: no extension, and no "(1080p, h264)"-like tag a downloader put after it.
static func title_of_file(file: String) -> String:
	var t := file.get_basename().strip_edges()
	var tag := RegEx.create_from_string("\\s*[\\[(][^\\])]*\\b(?:\\d{3,4}p|h264|h265|hevc|av1|vp9|avc1?)\\b[^\\])]*[\\])]\\s*$")
	t = tag.sub(t, "", true).strip_edges()
	return t


## A title made comparable: lowercase letters and digits, one space between runs, with a leading
## "@channel - " taken off.
static func comparable(title: String) -> String:
	var t := title.strip_edges()
	t = RegEx.create_from_string("^@\\S+\\s+-\\s+").sub(t, "", false)
	var out := ""
	var gap := false
	for c in t.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			if gap and not out.is_empty():
				out += " "
			out += c
			gap = false
		else:
			gap = true
	return out


## Do two titles name one video? Equal once comparable - or, unless [param exact], one inside the other
## and nearly as long: a channel's "Day 4" is not its "Day 45" (2026-10-21, a channel of 2040 videos).
static func same_title(a: String, b: String, exact := false) -> bool:
	var x := comparable(a)
	var y := comparable(b)
	if x.is_empty() or y.is_empty():
		return false
	if x == y:
		return true
	if exact:
		return false
	var short := mini(x.length(), y.length())
	return short >= 16 and float(short) >= 0.85 * float(maxi(x.length(), y.length())) and (x.contains(y) or y.contains(x))


## ADD THE FOLDER [param folder] to [param actor]: a source, and a row per video in it - ticked, unless
## [param ticked] says otherwise of a title. Returns how many videos are new.
static func add_folder(actor: ActorFolder, folder: String) -> int:
	for s in actor.data["sources"]:
		if String((s as Dictionary).get("kind", "")) == "folder" and String((s as Dictionary).get("path", "")) == folder:
			return rescan(actor)
	(actor.data["sources"] as Array).append({"kind": "folder", "path": folder})
	return rescan(actor)


## ADD THE FILE [param path] to [param actor]: a source of its own, and its row (ticked). Returns how many videos
## are new - none when it is listed already, or in one of their folders.
static func add_file(actor: ActorFolder, path: String) -> int:
	for s in actor.data["sources"]:
		if String((s as Dictionary).get("kind", "")) == "file" and String((s as Dictionary).get("path", "")) == path:
			return rescan(actor)
	(actor.data["sources"] as Array).append({"kind": "file", "path": path})
	return rescan(actor)


## READ EVERY FOLDER AGAIN: a video added since gets its row; one gone keeps its row, and is missing
## until it is back - or until A FILE OF ITS NAME turns up in another of their folders, when it is that video,
## moved: its row, its id and all made from it go on (2026-10-23: the user merged one download folder into
## another, and an id is its path's - eight videos would have been surveyed again as new, and the sets made of
## them lost theirs). Returns how many are new.
static func rescan(actor: ActorFolder) -> int:
	var added := 0
	var vids: Dictionary = actor.data["videos"]
	# the files a row already names (a moved one's id is no longer its path's)
	var named := {}
	for vid in vids:
		named[String((vids[vid] as Dictionary).get("path", ""))] = true
	for si in (actor.data["sources"] as Array).size():
		var s: Dictionary = actor.data["sources"][si]
		var found: Array = []
		match String(s.get("kind", "")):
			"folder":
				found = scan(String(s.get("path", "")), actor.exts())
			"file":
				found = scan_file(String(s.get("path", "")))
		for v in found:
			var vid := ActorFolder.vid_of_file(String(v["path"]), int(v["size"]))
			if vids.has(vid) or named.has(String(v["path"])):
				continue
			var was := _moved_here(vids, String(v["path"]))
			if not was.is_empty():
				var row: Dictionary = vids[was]
				if not row.has("found_at"):
					row["found_at"] = String(row["path"])
				row["path"] = String(v["path"])
				row["source"] = si
				named[String(v["path"])] = true
				continue
			vids[vid] = {"path": String(v["path"]), "title": String(v["title"]), "source": si, "ticked": true}
			added += 1
	return added


## The folder video whose file is gone and which a file at [param path] is, moved: one of the same name, ""
## for none.
static func _moved_here(vids: Dictionary, path: String) -> String:
	for vid in vids:
		var row: Dictionary = vids[vid]
		var was := String(row.get("path", ""))
		if String(vid).begins_with("f-") and was.get_file() == path.get_file() and not FileAccess.file_exists(was):
			return String(vid)
	return ""


## ADD A LINK: a source, its entries to come from its listing ([method land_listing]).
static func add_link(actor: ActorFolder, url: String, captions_only: bool) -> int:
	var sources: Array = actor.data["sources"]
	for i in sources.size():
		var s: Dictionary = sources[i]
		if String(s.get("url", "")) == url and bool(s.get("captions_only", false)) == captions_only:
			return i
	sources.append({"kind": "link", "url": url, "captions_only": captions_only, "listed": false})
	return sources.size() - 1


## THE ARGUMENTS THAT LIST [param url] - a video, a playlist or a channel - as JSON, nothing fetched.
static func list_args(url: String, deno: String) -> PackedStringArray:
	var a := PackedStringArray(["-u", "-m", "yt_dlp", "--flat-playlist", "-J", "--no-warnings"])
	a.append_array(_runtime(deno))
	a.append(url)
	return a


## THE ARGUMENTS THAT FETCH ONE VIDEO into [param footage] as `<id>.<ext>`, with its automatic
## captions and its details - or, [param captions_only], the captions and details alone. A video the
## archive already lists is not fetched again. [param sound_only] (a voice alone, [method
## ActorFolder.sound_only]) fetches its sound and its details, no picture and no captions: Hear listens to all
## of it, and its words come from what it hears.
static func fetch_args(url: String, footage: String, captions_only: bool, deno: String, sound_only := false) -> PackedStringArray:
	var a := PackedStringArray(["-u", "-m", "yt_dlp", "--no-playlist", "--newline", "--no-overwrites",
		"--socket-timeout", "30"])
	if not sound_only:
		a.append_array(PackedStringArray(["--write-auto-subs", "--sub-langs", SUB_LANGS, "--sub-format", "json3"]))
	a.append_array(PackedStringArray(["--write-info-json", "-o", footage.path_join("%(id)s.%(ext)s")]))
	if captions_only:
		a.append("--skip-download")
	elif sound_only:
		a.append_array(PackedStringArray(["-f", SOUND_FORMAT, "--download-archive", footage.path_join("archive.txt"),
			"--throttled-rate", "100K", "--concurrent-fragments", "4"]))
	else:
		a.append_array(PackedStringArray(["-f", FORMAT, "--merge-output-format", "mp4",
			"--download-archive", footage.path_join("archive.txt"),
			"--throttled-rate", "100K", "--concurrent-fragments", "4"]))
	a.append_array(_runtime(deno))
	a.append(url)
	return a


static func _runtime(deno: String) -> PackedStringArray:
	if not deno.is_empty() and FileAccess.file_exists(deno):
		return PackedStringArray(["--js-runtimes", "deno:" + deno])
	for rt in ["deno", "node"]:
		var b := Deps.resolve(rt)
		if not b.is_empty():
			return PackedStringArray(["--js-runtimes", rt + ":" + b])
	return PackedStringArray()


## THE ENTRIES OF A LISTING (yt-dlp's `-J`): `[{id, title, duration, url}]` - one for a video, every
## entry of a playlist, and every video of a channel's tabs.
static func entries_of(listing: Variant) -> Array:
	var out: Array = []
	if not (listing is Dictionary):
		return out
	var d: Dictionary = listing
	if not (d.get("entries") is Array):
		if not String(d.get("id", "")).is_empty():
			out.append({"id": String(d["id"]), "title": String(d.get("title", "")),
				"duration": float(d.get("duration", 0.0) if d.get("duration") != null else 0.0),
				"url": String(d.get("webpage_url", d.get("url", "")))})
		return out
	for e in d["entries"]:
		if not (e is Dictionary):
			continue
		# A CHANNEL IS TABS OF PLAYLISTS: its videos are inside them
		if (e as Dictionary).get("entries") is Array:
			out.append_array(entries_of(e))
			continue
		var id := String((e as Dictionary).get("id", ""))
		if id.is_empty():
			continue
		var url := String((e as Dictionary).get("url", ""))
		if url.is_empty() or not url.begins_with("http"):
			url = "https://www.youtube.com/watch?v=" + id
		var dur: Variant = (e as Dictionary).get("duration")
		out.append({"id": id, "title": String((e as Dictionary).get("title", "")),
			"duration": float(dur) if dur != null else 0.0, "url": url})
	var seen := {}
	var unique: Array = []
	for e in out:
		if not seen.has(e["id"]):
			seen[e["id"]] = true
			unique.append(e)
	return unique


## A LINK'S LISTING LANDS: a video row per entry (ticked), or - captions only - each entry matched to
## the folder video of its title, whose captions it fetches. Returns `{added, matched, unmatched}`.
static func land_listing(actor: ActorFolder, source: int, entries: Array) -> Dictionary:
	var s: Dictionary = actor.data["sources"][source]
	var vids: Dictionary = actor.data["videos"]
	var added := 0
	var matched := 0
	var unmatched := 0
	s["listed"] = true
	s["count"] = entries.size()
	if bool(s.get("captions_only", false)):
		# EXACT TITLES FIRST, then near ones for the videos still without a match: each video takes one
		var taken := {}
		for exact in [true, false]:
			for e in entries:
				if taken.has(String(e["id"])):
					continue
				for vid in vids:
					var v: Dictionary = vids[vid]
					if not String(v.get("url", "")).is_empty() or taken.has("v:" + String(vid)):
						continue
					if same_title(String(v.get("title", "")), String(e["title"]), exact):
						v["captions_url"] = String(e["url"])
						v["captions_id"] = String(e["id"])
						taken["v:" + String(vid)] = true
						taken[String(e["id"])] = true
						matched += 1
						break
		unmatched = entries.size() - matched
		return {"added": 0, "matched": matched, "unmatched": unmatched}
	for e in entries:
		var vid := ActorFolder.vid_of_link(String(e["id"]))
		if vids.has(vid):
			continue
		vids[vid] = {"url": String(e["url"]), "entry": String(e["id"]), "title": String(e["title"]),
			"duration": float(e["duration"]), "source": source, "ticked": true, "path": ""}
		added += 1
	return {"added": added, "matched": 0, "unmatched": 0}


## THE FILES A FETCH OF ENTRY [param entry] LEFT in [param footage]: `{video, captions, info}`, each ""
## when it is not there - the video by its id and a video extension (or a sound file's, fetched for a voice
## alone), the captions the preferred track.
static func fetched(footage: String, entry: String) -> Dictionary:
	var out := {"video": "", "captions": "", "info": ""}
	var d := DirAccess.open(footage)
	if d == null or entry.is_empty():
		return out
	var subs := {}
	for f in d.get_files():
		if not f.begins_with(entry + "."):
			continue
		var rest := f.substr(entry.length() + 1)
		if rest == "info.json":
			out["info"] = footage.path_join(f)
		elif rest.ends_with(".json3"):
			subs[rest.trim_suffix(".json3")] = footage.path_join(f)
		elif (ActorFolder.VIDEO_EXTS.has(rest.to_lower()) or ActorFolder.SOUND_EXTS.has(rest.to_lower())) and not f.ends_with(".part"):
			out["video"] = footage.path_join(f)
	for lang in SUB_PREFER:
		if subs.has(lang):
			out["captions"] = subs[lang]
			break
	if String(out["captions"]).is_empty() and not subs.is_empty():
		out["captions"] = subs[subs.keys()[0]]
	return out


## CAPTIONS INTO WORDS: json3's events, each word at its event's start plus its own offset, ending
## where the next begins (at most [constant WORD_MOST] later, and never past its event). What the
## captions put in brackets ([Music]) is not a word they said. `[{text, t0, t1}]`.
static func words_of_json3(text: String) -> Array:
	var out: Array = []
	var d: Variant = JSON.parse_string(text)
	if not (d is Dictionary) or not ((d as Dictionary).get("events") is Array):
		return out
	var raw: Array = []
	for ev in d["events"]:
		if not (ev is Dictionary) or not ((ev as Dictionary).get("segs") is Array):
			continue
		var start := float((ev as Dictionary).get("tStartMs", 0.0)) / 1000.0
		var end := start + float((ev as Dictionary).get("dDurationMs", 0.0)) / 1000.0
		for seg in ev["segs"]:
			var w := String((seg as Dictionary).get("utf8", "")).strip_edges()
			if w.is_empty() or w.begins_with("["):
				continue
			for part in w.split(" ", false):
				raw.append({"text": String(part), "t0": start + float((seg as Dictionary).get("tOffsetMs", 0.0)) / 1000.0, "end": end})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t0"]) < float(b["t0"]))
	for i in raw.size():
		var w: Dictionary = raw[i]
		var t0 := float(w["t0"])
		var t1 := t0 + WORD_MOST
		if i + 1 < raw.size():
			t1 = minf(t1, float((raw[i + 1] as Dictionary)["t0"]))
		if float(w["end"]) > t0:
			t1 = minf(t1, float(w["end"]))
		out.append({"text": String(w["text"]), "t0": snappedf(t0, 0.001), "t1": snappedf(maxf(t1, t0 + 0.05), 0.001)})
	return out

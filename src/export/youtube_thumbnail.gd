extends EpisodeStep
class_name YouTubeThumbnail

## YouTubeThumbnail - a thumbnail painted for each episode (the user, 2026-10-28: "an agentic workflow
## (supporting all agents, models, and reasoning modes), which would ask an agent to produce a compelling
## and relevant thumbnail. This flow might benefit from both the writer and the painter").
##
## A STEP OF THE EPISODE ([EpisodeStep]), offered by the YouTube card while its Thumbnail is Painted
## ([constant YouTube.THUMBNAILS]): the card that makes episodes lists it under its own steps, Generate
## makes it with them and its ⟳ paints it again - a note read as it is written, by an export that goes up
## ([NoteUpload]). TWO AGENTS, EACH PICKED ON THE CARD: the writer reads the episode - its words, title
## and description, and its own pictures where it has any ([method EpisodeFeed.pictures], a show's
## paintings) - and writes what the painter paints, the words on it and which of those pictures the
## painter follows (rules/youtube/thumbnail.yaml); the painter paints it ([method _after]); the code cuts
## it to YouTube's shape ([method fit]).
##
## KEPT IN THE EPISODE'S FOLDER, EVERY ONE PAINTED (the user, 2026-10-30: "there is no way to cycle
## backward/forward through generated thumbnails, as the generated in-episode pictures can be cycled
## through"): `youtube_thumbnail.json` holds the versions, oldest first - each the writer's answer, the
## fingerprint of the words it was written from and its thumbnail - and the one CHOSEN ([method choose]),
## what goes up ([method image_in]) and what the step says is made ([method made]), so an earlier one
## chosen from words since rewritten shows as stale - AND STILL GOES UP: NOTHING PAINTS OVER A CHOICE (2026-10-31, the
## user, of an export that painted again: "That definitely shouldn't happen. I already had painted one."). Generate
## and an export that goes up paint one only for an episode with none ([method owed]); another is the ⟳'s. A version's painting whole is `youtube_thumbnail_N.png`
## and the thumbnail cut from it `youtube_thumbnail_N.jpg` (a record kept before there were versions is one,
## its files named in it). The YouTube card steps between them and deletes one ([method delete]). Deleting
## the episode takes them along, and another episode starts without one.
##
## IN THE VIDEO'S OWN LOOK (the user, 2026-10-30: "a feature akin to the full-screen images' 'match earlier'
## option, to allow the thumbnail to mimic the style of the pictures in the video. Right now, the thumbnails
## generated are just random weird pictures, completely different from the video"): with the card's "Match
## the video's pictures" ticked ([method matching]), the writer is shown the episode's own pictures and told
## to design one of their world, and the painter is ALWAYS handed some of them - those the writer named, or,
## naming none, [constant REFS_MOST] spread through them ([method spread]) - and told to paint one more of
## them. Unticked, it is designed and painted free of them. (A note read as it is written had handed the
## step no pictures at all: its own are its painted ones now - [method NoteUpload.pictures].)
##
## ANOTHER IS ANOTHER (the user, 2026-10-30: "twice now, the thumbnail generated has essentially been exactly
## the same thing, right down to the exact same text"): the writer had been sent the same prompt every time
## and came back with the same design - the same subject and the same four words. Now it is shown the
## versions kept for the episode ([constant EARLIER_MOST] of them) and told to make one unlike them.

const YouTube := preload("res://src/export/youtube.gd")
## The most of an episode's own pictures the writer is shown, spread through the video in its order.
const PICTURES_MOST := 8
## The most of them the painter is handed to paint after, as a book's picture is handed the ones before it
## ([constant Illustrations.CHAIN_MAX]).
const REFS_MOST := 4
## Version N's files in the episode's folder: the painting (`.png`) and the thumbnail cut from it (`.jpg`).
const FILES := "youtube_thumbnail_%d"
## The most of the versions already kept the writer is shown, the latest.
const EARLIER_MOST := 6
## The most of the painter's brief a row says.
const SAID_MOST := 120

var _wanted: Callable
var _writer_of: Callable
var _painter_of: Callable
var _match_by: Callable


## [param wanted_by]: () -> bool, the card's Thumbnail being Painted; [param writer_by] and
## [param painter_by]: () -> Dictionary, the card's picks, `{agent, model, effort}`; [param match_by]:
## () -> bool, its "Match the video's pictures" (ticked when not handed).
func _init(wanted_by := Callable(), writer_by := Callable(), painter_by := Callable(), match_by := Callable()) -> void:
	key = "youtube_thumbnail"
	label = "Thumbnail"
	again = "Paint another thumbnail for this episode, unlike the ones before - they are kept, and the YouTube card steps between them"
	first = "Paint this episode's thumbnail now"
	waits = "painted once the episode's words are written"
	unmade = "not painted for this episode yet"
	_wanted = wanted_by
	_writer_of = writer_by
	_painter_of = painter_by
	_match_by = match_by


func wanted() -> bool:
	return _wanted.is_valid() and bool(_wanted.call())


## Whether it is painted in the look of the episode's own pictures.
func matching() -> bool:
	return not _match_by.is_valid() or bool(_match_by.call())


## THE THUMBNAIL CHOSEN FOR THE EPISODE IN [param folder] (absolute), "" for none: what an upload takes.
static func image_in(folder: String) -> String:
	var path := folder.path_join("youtube_thumbnail.json") if not folder.is_empty() else ""
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var vs := versions_of(d if d is Dictionary else {})
	return _image(folder, vs[chosen_of(d)] if not vs.is_empty() else {})


## The thumbnail of [param feed]'s episode chosen, as [method image_in] - read off what is kept, so only
## when it changes.
func image(feed: EpisodeFeed) -> String:
	return _image(feed.folder(), made(feed)) if feed != null else ""


## Version [param v]'s thumbnail in [param folder], "" when it has none there.
static func _image(folder: String, v: Dictionary) -> String:
	var name := String(v.get("image", ""))
	var jpg := folder.path_join(name) if not folder.is_empty() and not name.is_empty() else ""
	return jpg if not jpg.is_empty() and FileAccess.file_exists(jpg) else ""


## The versions a kept record [param d] holds, oldest first: its list - or, kept before there were
## versions, itself.
static func versions_of(d: Dictionary) -> Array:
	var vs: Variant = d.get("versions")
	if vs is Array:
		return (vs as Array).filter(func(v: Variant) -> bool: return v is Dictionary)
	return [d] if d.has("image") else []


## The version [param d] has chosen: its `current`, else the latest; -1 with none.
static func chosen_of(d: Variant) -> int:
	var n := versions_of(d if d is Dictionary else {}).size()
	return -1 if n == 0 else clampi(int((d as Dictionary).get("current", n - 1)), 0, n - 1)


## WHAT IS MADE IS THE VERSION CHOSEN, as kept: what was painted, its words, its thumbnail and the
## fingerprint of the words it was painted from.
func made(feed: EpisodeFeed) -> Dictionary:
	var d := super.made(feed)
	var vs := versions_of(d)
	return vs[chosen_of(d)] if not vs.is_empty() else {}


## OWED ONLY WHILE NONE IS PAINTED: words written since leave the one chosen going up, said older than them.
func owed(feed: EpisodeFeed) -> bool:
	return made(feed).is_empty()


## The versions kept for [param feed]'s episode, oldest first.
func versions(feed: EpisodeFeed) -> Array:
	return versions_of(super.made(feed))


## Which of them goes up, -1 with none.
func chosen(feed: EpisodeFeed) -> int:
	return chosen_of(super.made(feed))


## VERSION [param i] GOES UP with [param feed]'s episode from now on. "" once kept, else why not.
func choose(feed: EpisodeFeed, i: int) -> String:
	var vs := versions(feed)
	if i < 0 or i >= vs.size():
		return "there is no such thumbnail"
	return _write(feed, {"versions": vs.duplicate(true), "current": i})


## VERSION [param i] DELETED, its painting and its thumbnail with it, and the one before it chosen (the
## next, when it was the first); with none left the episode has no thumbnail. "" once done, else why not.
func delete(feed: EpisodeFeed, i: int) -> String:
	var vs := versions(feed).duplicate(true)
	if i < 0 or i >= vs.size():
		return "there is no such thumbnail"
	var at := chosen(feed)
	var name := String((vs[i] as Dictionary).get("image", ""))
	if not name.is_empty():
		var jpg := feed.folder().path_join(name)
		for f in [jpg, jpg.get_basename() + ".png"]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(f)
	vs.remove_at(i)
	if vs.is_empty():
		var path := file_in(feed)
		_kept.erase(path)
		return "" if DirAccess.remove_absolute(path) == OK else "could not remove " + path
	return _write(feed, {"versions": vs, "current": maxi(at - 1, 0) if at >= i else at})


## A PAINTING LANDED IS A NEW VERSION, chosen: the ones before it are kept, to step back to.
func _keep(feed: EpisodeFeed, got: Dictionary, stamp: String) -> String:
	var v := got.duplicate(true)
	v["from"] = stamp
	var vs := versions(feed).duplicate(true)
	vs.append(v)
	return _write(feed, {"versions": vs, "current": vs.size() - 1})


## The base name of the next painting's files in [param folder]: the first number neither names.
static func _next_in(folder: String) -> String:
	var n := 1
	while FileAccess.file_exists(folder.path_join(FILES % n + ".png")) or FileAccess.file_exists(folder.path_join(FILES % n + ".jpg")):
		n += 1
	return FILES % n


func _writer(feed: EpisodeFeed) -> Dictionary:
	var w: Variant = _writer_of.call() if _writer_of.is_valid() else {}
	return w if w is Dictionary and not String((w as Dictionary).get("agent", "")).is_empty() else feed.writer()


func _prompt(feed: EpisodeFeed) -> Dictionary:
	return prompt(feed.show_title(), feed.episode_title(), feed.description(), feed.words(), _shown(feed),
		versions(feed).slice(-EARLIER_MOST))


## The episode's own pictures the writer is shown, numbered as it is shown them - none unless it is matching.
func _shown(feed: EpisodeFeed) -> PackedStringArray:
	return PackedStringArray(spread(feed.pictures(), PICTURES_MOST)) if matching() else PackedStringArray()


## [param n] of [param pictures] spread evenly through them, the first and the last among them, in order.
static func spread(pictures: PackedStringArray, n: int) -> Array:
	if pictures.size() <= n:
		return Array(pictures)
	var out: Array = []
	for i in n:
		var p := pictures[roundi(float(i) * (pictures.size() - 1) / maxf(n - 1, 1))]
		if not out.has(p):
			out.append(p)
	return out


## What the writer is told, from the show's name, the episode's [param title] and [param description], its
## [param words], its own [param pictures] (absolute paths, numbered from 1 as it is shown them) and the
## thumbnails already kept for it ([param earlier], versions as kept: it makes one unlike them). Static and
## pure for the gate.
static func prompt(show: String, title: String, description: String, words: String,
		pictures: PackedStringArray, earlier: Array = []) -> Dictionary:
	var images: Array = []
	for i in pictures.size():
		images.append({"path": pictures[i], "label": "Picture %d:" % (i + 1)})
	var made: Array = []
	for v in earlier:
		made.append({"n": made.size() + 1, "brief": String((v as Dictionary).get("picture", "")).strip_edges(),
			"lettering": String((v as Dictionary).get("words", "")).strip_edges()})
	return {"system": Rules.say("youtube/thumbnail.system", {}),
		"prompt": Rules.say("youtube/thumbnail.prompt", {"show": show.strip_edges(), "title": title.strip_edges(),
			"description": description.strip_edges(), "words": words.strip_edges(), "pictures": pictures.size(),
			"earlier": made}),
		"images": images}


func _land(text: String, feed: EpisodeFeed) -> Variant:
	return land(TextGen.extract_json(text), _shown(feed))


## The writer's answer [param d] as kept: `{picture, words, after}` - what the painter paints, the words on
## it (maybe none) and the [param pictures] it follows, by the numbers the writer gave, each once - or why
## it cannot be kept. Static and pure for the gate.
static func land(d: Variant, pictures: PackedStringArray) -> Variant:
	if not (d is Dictionary):
		return "the answer held no JSON object"
	var pic := String((d as Dictionary).get("picture", "")).strip_edges()
	if pic.is_empty():
		return "the answer said nothing for the painter to paint"
	var words := String((d as Dictionary).get("words", "")).strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	var after: Array = []
	var raw: Variant = (d as Dictionary).get("after", [])
	for n in (raw if raw is Array else []):
		# a number as JSON has it (2.0), or written as one ("2")
		var i := (int(n) if n is float or n is int else String(n).strip_edges().to_int()) - 1
		if i >= 0 and i < pictures.size() and not after.has(pictures[i]):
			after.append(pictures[i])
	return {"picture": pic, "words": words, "after": after}


## THE PAINTER'S JOB: the card's painter, painting what the writer wrote ([method painting]) into the
## episode's folder - after the pictures it named, or, matching and naming none, a few spread through the
## episode's own.
func _after(got: Dictionary, feed: EpisodeFeed) -> Dictionary:
	var p: Variant = _painter_of.call() if _painter_of.is_valid() else {}
	var pick: Dictionary = p if p is Dictionary else {}
	var follow := got.duplicate()
	follow["after"] = (got["after"] as Array).slice(0, REFS_MOST)
	if (follow["after"] as Array).is_empty():
		follow["after"] = spread(_shown(feed), REFS_MOST)
	return {"kind": "image", "backend": String(pick.get("agent", ImageGen.REGISTRY.keys()[0])),
		"model": String(pick.get("model", "")), "effort": String(pick.get("effort", "")),
		"prompt": painting(follow, _portrait()), "refs": follow["after"],
		"target": feed.folder().path_join(_next_in(feed.folder()) + ".png")}


## What the painter is told for the writer's answer [param got], landed - a thumbnail of a
## [param portrait] video turned. Static and pure for the gate.
static func painting(got: Dictionary, portrait: bool) -> String:
	return Rules.say("youtube/thumbnail.painter", {"picture": String(got.get("picture", "")),
		"words": String(got.get("words", "")), "refs": not (got.get("after", []) as Array).is_empty(),
		"portrait": portrait})


## The painting landed, cut to the thumbnail beside it ([method fit]), of its name.
func _land_after(res: Dictionary, got: Dictionary, feed: EpisodeFeed) -> Variant:
	var painted := String(res.get("path", ""))
	if painted.is_empty() or not FileAccess.file_exists(painted):
		return "the painter left no picture"
	var image := painted.get_file().get_basename() + ".jpg"
	var err := fit(painted, feed.folder().path_join(image), _portrait())
	if not err.is_empty():
		return err
	var out := got.duplicate()
	out["image"] = image
	return out


## A portrait video's thumbnail is turned: the frame the show is shown in.
static func _portrait() -> bool:
	return Director.resolved_frame() == "portrait"


## THE PAINTING CUT TO A THUMBNAIL: [param src] cropped about its middle to YouTube's shape and scaled to
## [constant YouTube.THUMBNAIL_SIZE] (turned for [param portrait]), written as a JPEG at [param dst] - by
## rename, so it is there whole or not at all. "" once written, else why not.
static func fit(src: String, dst: String, portrait := false) -> String:
	if not FileAccess.file_exists(src):
		return "the painting is missing"
	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		return "the painting could not be read"
	var size := YouTube.THUMBNAIL_SIZE if not portrait else Vector2i(YouTube.THUMBNAIL_SIZE.y, YouTube.THUMBNAIL_SIZE.x)
	var want := float(size.x) / size.y
	var cut := Rect2i(Vector2i.ZERO, img.get_size())
	if float(cut.size.x) / cut.size.y > want:
		cut.size.x = roundi(cut.size.y * want)
		cut.position.x = (img.get_width() - cut.size.x) / 2
	else:
		cut.size.y = roundi(cut.size.x / want)
		cut.position.y = (img.get_height() - cut.size.y) / 2
	var out := img.get_region(cut)
	out.convert(Image.FORMAT_RGB8)
	out.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var tmp := dst + ".part.jpg"
	if out.save_jpg(tmp, 0.9) != OK or DirAccess.rename_absolute(tmp, dst) != OK:
		return "could not write " + dst
	return ""


func summary(m: Dictionary) -> String:
	var words := String(m.get("words", ""))
	var pic := String(m.get("picture", ""))
	if pic.length() > SAID_MOST:
		pic = pic.substr(0, SAID_MOST).strip_edges() + "…"
	return "painted%s: %s" % [(" with \"%s\"" % words) if not words.is_empty() else "", pic]

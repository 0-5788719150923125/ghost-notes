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
## KEPT IN THE EPISODE'S FOLDER: `youtube_thumbnail.json` (the writer's answer, with the fingerprint of the
## words it was written from), the painting whole (`youtube_thumbnail.png`) and the thumbnail cut from it
## (`youtube_thumbnail.jpg`, what goes up - [method image_in]). Deleting the episode takes them along,
## another episode starts without one, and words written again make it stale.

const YouTube := preload("res://src/export/youtube.gd")
## The most of an episode's own pictures the writer is shown, the first in the order the video shows them.
const PICTURES_MOST := 8
## The thumbnail as it goes up, and the painting it was cut from, in the episode's folder.
const IMAGE := "youtube_thumbnail.jpg"
const PAINTED := "youtube_thumbnail.png"
## The most of the painter's brief a row says.
const SAID_MOST := 120

var _wanted: Callable
var _writer_of: Callable
var _painter_of: Callable


## [param wanted_by]: () -> bool, the card's Thumbnail being Painted; [param writer_by] and
## [param painter_by]: () -> Dictionary, the card's picks, `{agent, model, effort}`.
func _init(wanted_by := Callable(), writer_by := Callable(), painter_by := Callable()) -> void:
	key = "youtube_thumbnail"
	label = "Thumbnail"
	again = "Paint this episode's thumbnail again"
	first = "Paint this episode's thumbnail now"
	waits = "painted once the episode's words are written"
	unmade = "not painted for this episode yet"
	_wanted = wanted_by
	_writer_of = writer_by
	_painter_of = painter_by


func wanted() -> bool:
	return _wanted.is_valid() and bool(_wanted.call())


## THE THUMBNAIL PAINTED FOR THE EPISODE IN [param folder] (absolute), "" for none: what an upload takes.
static func image_in(folder: String) -> String:
	if folder.is_empty():
		return ""
	var jpg := folder.path_join(IMAGE)
	return jpg if FileAccess.file_exists(folder.path_join("youtube_thumbnail.json")) and FileAccess.file_exists(jpg) else ""


func _writer(feed: EpisodeFeed) -> Dictionary:
	var w: Variant = _writer_of.call() if _writer_of.is_valid() else {}
	return w if w is Dictionary and not String((w as Dictionary).get("agent", "")).is_empty() else feed.writer()


func _prompt(feed: EpisodeFeed) -> Dictionary:
	return prompt(feed.show_title(), feed.episode_title(), feed.description(), feed.words(), _shown(feed))


func _shown(feed: EpisodeFeed) -> PackedStringArray:
	return feed.pictures().slice(0, PICTURES_MOST)


## What the writer is told, from the show's name, the episode's [param title] and [param description], its
## [param words] and its own [param pictures] (absolute paths, numbered from 1 as it is shown them). Static
## and pure for the gate.
static func prompt(show: String, title: String, description: String, words: String,
		pictures: PackedStringArray) -> Dictionary:
	var images: Array = []
	for i in pictures.size():
		images.append({"path": pictures[i], "label": "Picture %d:" % (i + 1)})
	return {"system": Rules.say("youtube/thumbnail.system", {}),
		"prompt": Rules.say("youtube/thumbnail.prompt", {"show": show.strip_edges(), "title": title.strip_edges(),
			"description": description.strip_edges(), "words": words.strip_edges(), "pictures": pictures.size()}),
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


## THE PAINTER'S JOB: the card's painter, painting what the writer wrote ([method painting]) after the
## pictures it named, into the episode's folder.
func _after(got: Dictionary, feed: EpisodeFeed) -> Dictionary:
	var p: Variant = _painter_of.call() if _painter_of.is_valid() else {}
	var pick: Dictionary = p if p is Dictionary else {}
	return {"kind": "image", "backend": String(pick.get("agent", ImageGen.REGISTRY.keys()[0])),
		"model": String(pick.get("model", "")), "effort": String(pick.get("effort", "")),
		"prompt": painting(got, _portrait()), "refs": got["after"], "target": feed.folder().path_join(PAINTED)}


## What the painter is told for the writer's answer [param got], landed - a thumbnail of a
## [param portrait] video turned. Static and pure for the gate.
static func painting(got: Dictionary, portrait: bool) -> String:
	return Rules.say("youtube/thumbnail.painter", {"picture": String(got.get("picture", "")),
		"words": String(got.get("words", "")), "refs": not (got.get("after", []) as Array).is_empty(),
		"portrait": portrait})


## The painting landed, cut to the thumbnail beside it ([method fit]).
func _land_after(res: Dictionary, got: Dictionary, feed: EpisodeFeed) -> Variant:
	var painted := String(res.get("path", ""))
	if painted.is_empty() or not FileAccess.file_exists(painted):
		return "the painter left no picture"
	var err := fit(painted, feed.folder().path_join(IMAGE), _portrait())
	if not err.is_empty():
		return err
	var out := got.duplicate()
	out["image"] = IMAGE
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

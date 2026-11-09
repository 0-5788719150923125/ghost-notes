extends VBoxContainer
class_name MadePictures

## MadePictures - WHAT A SHOW'S AGENTS PAINTED FOR ITS EPISODE, seen (the user, 2026-11-09: "the Godot app can generate a mask, but we
## will never see the reference image in the UI, and so our only option is to watch until the end of the video... to see what the
## mask actually is"): each picture the episode's maker says its agents made ([method EpisodeFeed.made_pictures]) a thumbnail and its
## row's name, one click away from full size ([PictureWindow]), stepped through in the order they were made. Making one again is its
## row's, on the Pipeline card (docs.py "one pipeline"): the window says which row. On the Pictures card ([PicturesCard]); it names
## no maker.

## A thumbnail's longest side (pixels).
const THUMB := 96

var _feed_of := Callable()       # () -> EpisodeFeed or null
var _shown: Array = []           # the records shown, `{path, label, row, group}`
var _stamp := ""                 # what was shown, by path and change time: rebuilt only when that changes
var _flow: HFlowContainer
var _heading: Label
var _window: PictureWindow = null


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_heading = Label.new()
	_heading.text = "Made for this episode"
	_heading.add_theme_font_size_override("font_size", 12)
	_heading.modulate = Color(1, 1, 1, 0.7)
	add_child(_heading)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 6)
	_flow.add_theme_constant_override("v_separation", 6)
	add_child(_flow)
	visible = false


## Where its pictures come from: [param feed_of] () -> [EpisodeFeed] (or null, none).
func follow(feed_of: Callable) -> void:
	_feed_of = feed_of


## The pictures made now, read again: whether there are any. Rebuilt only when what is there changed.
func refresh() -> bool:
	var feed: Variant = _feed_of.call() if _feed_of.is_valid() else null
	var list: Array = (feed as EpisodeFeed).made_pictures() if feed is EpisodeFeed else []
	var parts := PackedStringArray()
	for r in list:
		var p := String((r as Dictionary)["path"])
		parts.append("%s@%d" % [p, FileAccess.get_modified_time(p)])
	var stamp := "|".join(parts)
	if stamp != _stamp:
		_stamp = stamp
		_shown = list
		_build()
	visible = not _shown.is_empty()
	return visible


## What it shows: the records, in order.
func shown() -> Array:
	return _shown


func _build() -> void:
	for c in _flow.get_children():
		_flow.remove_child(c)
		c.queue_free()
	for i in _shown.size():
		var r: Dictionary = _shown[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(THUMB, THUMB)
		b.tooltip_text = "%s - click to see it full size" % String(r["label"])
		var img := Image.load_from_file(String(r["path"])) if FileAccess.file_exists(String(r["path"])) else null
		if img != null and not img.is_empty():
			var s := float(THUMB) / float(maxi(img.get_width(), img.get_height()))
			img.resize(maxi(int(img.get_width() * s), 1), maxi(int(img.get_height() * s), 1), Image.INTERPOLATE_BILINEAR)
			b.texture_normal = ImageTexture.create_from_image(img)
		b.pressed.connect(_open.bind(i))
		cell.add_child(b)
		var l := Label.new()
		l.text = String(r["label"])
		l.add_theme_font_size_override("font_size", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(THUMB, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(l)
		_flow.add_child(cell)


## Picture [param i] full size, its neighbours a step away.
func _open(i: int) -> void:
	if _shown.is_empty():
		return
	i = clampi(i, 0, _shown.size() - 1)
	if _window == null:
		_window = PictureWindow.new()
		add_child(_window)
	var r: Dictionary = _shown[i]
	var words := "Painted by the episode's agents. To paint it again, use its row on the Pipeline card: %s." % String(r["label"]) \
		if not String(r.get("row", "")).is_empty() else "Painted by the episode's agents."
	_window.fill(String(r["label"]), String(r["path"]), words, i, _shown.size(), "", func(d: int) -> void: _open(i + d), [], "picture")
	if not _window.visible:
		_window.open_over(self)

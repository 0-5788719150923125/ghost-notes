extends Window
class_name PictureWindow

## PictureWindow - ONE PICTURE AT FULL SIZE, in a window of its own: the picture, the words it was made from under it, and
## a bar - its versions stepped through (‹ previous, "version 2 of 3", next ›), then whatever its owner adds (delete the
## one shown, Regenerate, Import…). What a click on a picture opens on the Pictures card ([IllustrationPanel]) and on the
## YouTube card's painted thumbnail ([YouTubeCard]): one window, where each had grown its own. Escape or the window's close
## hides it.


func _init() -> void:
	visible = false
	close_requested.connect(hide)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			hide())


## WHAT IT HOLDS: the picture at [param path], titled [param heading], [param words] under it; then the bar - "version
## [param at] + 1 of [param count]" (or [param counted]'s word for what is stepped through) and [param note] after it, between a ‹
## and a › that call [param step] with -1 or 1 (left out where [param step] is not valid) - and [param extras], buttons its owner
## made, after them.
func fill(heading: String, path: String, words: String, at: int, count: int, note := "", step := Callable(),
		extras: Array = [], counted := "version") -> void:
	clear()
	title = heading
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)
	var pic := TextureRect.new()
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img := Image.load_from_file(path) if not path.is_empty() and FileAccess.file_exists(path) else null
	if img != null and not img.is_empty():
		pic.texture = ImageTexture.create_from_image(img)
	col.add_child(pic)
	var desc := Label.new()
	desc.text = words
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	col.add_child(desc)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	for dir in [-1, 1]:
		if step.is_valid():
			var b := Button.new()
			b.text = "‹ previous" if dir < 0 else "next ›"
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = at + dir < 0 or at + dir >= count
			b.pressed.connect(step.bind(dir))
			bar.add_child(b)
		if dir < 0:
			var v := Label.new()
			v.text = "%s %d of %d%s" % [counted, at + 1, count, ("  " + note) if not note.is_empty() else ""]
			bar.add_child(v)
	for b in extras:
		bar.add_child(b as Control)


## Holds nothing - at once, so what looks in it next finds only what is there.
func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


## Opens it over [param host]'s view, most of its size.
func open_over(host: Control) -> void:
	var vp := host.get_viewport().get_visible_rect().size
	size = Vector2i(int(vp.x * 0.8), int(vp.y * 0.85))
	popup_centered()

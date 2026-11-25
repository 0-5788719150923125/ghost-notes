extends Window
class_name PictureWindow

## PictureWindow - one picture at full size, in a window of its own: the picture, the words it was made
## from under it, and a bar - its versions stepped through, whatever its owner adds (delete the one
## shown, Regenerate, Import...), then Show in folder, which opens the file manager at the picture's file
## on a desktop. A click on a picture opens it on the Pictures card ([IllustrationPanel]), on an episode's
## made pictures ([MadePictures]) and on the Upload card's thumbnail ([YouTubeCard]). Escape or the
## window's close hides it.


func _init() -> void:
	visible = false
	close_requested.connect(hide)
	window_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
			hide())


## What it holds: the picture at [param path], titled [param heading], [param words] under it; then the bar -
## "version [param at] + 1 of [param count]" (or [param counted]'s word for what is stepped through) and
## [param note] after it, between a "‹" and a "›" that call [param step] with -1 or 1 (all three left out
## where [param step] is not valid) - [param extras], buttons its owner made, after them, and Show in folder
## last ([method show_in_folder]).
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
		if dir < 0 and step.is_valid():
			var v := Label.new()
			v.text = "%s %d of %d%s" % [counted, at + 1, count, ("  " + note) if not note.is_empty() else ""]
			bar.add_child(v)
	for b in extras:
		bar.add_child(b as Control)
	if Capabilities.desktop() and img != null and not img.is_empty():
		var shown := Button.new()
		shown.text = "Show in folder"
		shown.tooltip_text = "Open your file manager at this picture's file:\n" + ProjectSettings.globalize_path(path)
		shown.focus_mode = Control.FOCUS_NONE
		shown.pressed.connect(show_in_folder.bind(path))
		bar.add_child(shown)


## The file manager opened at [param path], the file picked out where the file manager can do that.
static func show_in_folder(path: String) -> void:
	var full := ProjectSettings.globalize_path(path)
	if OS.shell_show_in_file_manager(full) != OK:
		push_warning("ghost: could not open a file manager at " + full)


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

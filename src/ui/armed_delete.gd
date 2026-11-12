extends RefCounted
class_name ArmedDelete

## ArmedDelete - a delete pressed twice, because it cannot be undone: the first press arms it for
## [constant ARMED] seconds ("Delete?", in red), the second calls what it deletes. One button for
## whatever a card deletes of what was made - a picture's version ([IllustrationPanel]), a painted
## thumbnail, a kept client ([YouTubeCard]).

## How long a first press stays armed, in seconds.
const ARMED := 3.0


## A delete button reading [param label], [param tip] on hover, that calls [param act] on its second press.
static func button(label: String, act: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = label
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	# The disarm timer is the button's child, not a SceneTree timer: a delete rebuilds a list and frees the button.
	var disarm := Timer.new()
	disarm.one_shot = true
	disarm.wait_time = ARMED
	var calm := func() -> void:
		b.set_meta("armed", false)
		b.text = label
		b.remove_theme_color_override("font_color")
	disarm.timeout.connect(calm)
	b.add_child(disarm)
	b.pressed.connect(func() -> void:
		if not bool(b.get_meta("armed", false)):
			b.set_meta("armed", true)
			b.text = "Delete?"
			b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			if disarm.is_inside_tree():
				disarm.start()
			return
		disarm.stop()
		calm.call()
		act.call())
	return b

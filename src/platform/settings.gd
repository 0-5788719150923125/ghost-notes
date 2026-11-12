extends Node

## Settings - the one owner of `user://ghost.cfg` (autoload).
##
## One in-memory copy, one writer, and persistence a control gets by construction: [method bind] loads the
## stored value into a control, connects its change signal and writes on every change, so a setting cannot be
## added without being saved. Separate owners doing load -> set -> save on the same file would forget to save a
## new control, clobber each other (an export renders in a second ghost process that reads at boot and writes
## at exit) and lose changes on a kill.
##
## Read-only in a render: an export boots a second ghost against the same file; it reads the session's settings
## and never writes them back. See [member _read_only].

const PATH := "user://ghost.cfg"

## Quiet period after the last change before the disk is touched, in ms. A slider DRAG must
## not write once per frame.
const DEBOUNCE_MS := 400
## The longest a change may go unwritten however busy the control is, in ms. A continuous drag keeps pushing the
## quiet period out, and a killed process never reaches its exit flush, so this bounds what a hard stop costs.
const MAX_DIRTY_MS := 2500

var _cfg := ConfigFile.new()
var _dirty := false
var _edit_ms := 0
var _dirty_since := 0
## True in a process that must never write: an export render and the offline analyzer boot the whole app
## against this same file (see exporter.gd).
var _read_only := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# The two subprocesses an export spawns: the Movie Maker render (--export, which also carries --bake-file) and
	# the offline analyzer (--bake-song / --bake-out, see bake_runner.gd), plus the README recording (--showcase,
	# see showcase.gd). All boot the whole app against the user's own settings file.
	var why := ""
	if args.has("--apply-update") or args.has("--update-smoke-hold") or args.has("--export") \
			or args.has("--bake-file") or args.has("--bake-song") \
			or args.has("--showcase") or args.has("--export-smoke"):
		why = "a render"
	# A test probe must not edit the user's settings: run_boot_probe.sh boots the real app at a scene under tests/,
	# so a gate that pokes a setter, or reads a default and hands it back, would persist it.
	elif is_probe_launch(OS.get_cmdline_args()):
		why = "a test"
	# ...and the bricks' record ([AssemblyBake]), a second ghost with nothing to say to anyone's settings
	elif OS.get_cmdline_args().has("res://src/table/assembly_bake.gd"):
		why = "the bricks' record"
	_read_only = not why.is_empty()
	_cfg.load(PATH)              # missing file is fine - everything falls back to its default
	if _read_only:
		print("ghost: settings are READ-ONLY in this process (%s)" % why)


## Is this process a test: booted at a scene under res://tests/ (a probe; each run_boot_probe.sh run boots its
## own `tests/_probe_<pid>.tscn`), or running a script from tests/ with `--script` (a SceneTree gate, which has
## every autoload and would otherwise flush what it wrote into ghost.cfg)?
static func is_probe_launch(args: PackedStringArray) -> bool:
	for i in args.size():
		var a := args[i]
		if a.begins_with("res://tests/") and a.ends_with(".tscn"):
			return true
		if a == "--script" and i + 1 < args.size() \
				and args[i + 1].trim_prefix("res://").begins_with("tests/"):
			return true
	return false


## True in a process that must not write the user's things: an export render, the offline analyzer, a test
## probe. Public because [DocSource] also asks it before saving the voice into a document.
func is_read_only() -> bool:
	return _read_only


## Let a gate that is testing persistence write after all. Nothing else may call this.
func allow_writes_for_test() -> void:
	_read_only = false


## The config's copy is never shared, in either direction, which is why [method read] and [method write]
## duplicate containers. A Dictionary or Array is a reference type and `ConfigFile.set_value` keeps the reference
## it is handed, so sharing would (1) defeat the no-op guard in [method write] (a dictionary compared with itself
## is always equal, so nothing is marked dirty or flushed) and (2) let a caller that mutates what [method read]
## returned write into the config through a side door. Scalars pass through untouched.
##
## The stored value for [param section]/[param key], or [param dflt] when never set. Reads come from the
## in-memory copy.
func read(section: String, key: String, dflt: Variant) -> Variant:
	return _own(_cfg.get_value(section, key, dflt))


## Whether this key has ever been stored. An empty string is still a user's stored choice.
func has(section: String, key: String) -> bool:
	return _cfg.has_section_key(section, key)


## Remember [param value]. Writing an unchanged value is a no-op, so this is safe to call
## from a signal that fires every frame of a drag.
func write(section: String, key: String, value: Variant) -> void:
	# Compared before the copy is taken, so it is a real content comparison against an independent stored copy.
	if _cfg.has_section_key(section, key) and _cfg.get_value(section, key) == value:
		return
	_cfg.set_value(section, key, _own(value))
	_edit_ms = Time.get_ticks_msec()
	if not _dirty:
		_dirty_since = _edit_ms
	_dirty = true


## A container the caller and the config cannot both hold. Deep, because these nest - a voice
## slot list is an Array of Dictionaries and a shallow copy would share every row.
func _own(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v


## Write now, whatever the debounce thinks. Called at every exit path; safe to call when
## nothing is pending.
func flush() -> void:
	if not _dirty or _read_only:
		_dirty = false
		return
	_dirty = false
	var err := _cfg.save(PATH)
	if err != OK:
		push_warning("ghost: could not save settings to %s (error %d)" % [PATH, err])


func _process(_delta: float) -> void:
	if not _dirty:
		return
	var now := Time.get_ticks_msec()
	if now - _edit_ms >= DEBOUNCE_MS or now - _dirty_since >= MAX_DIRTY_MS:
		flush()


func _exit_tree() -> void:
	flush()


func _notification(what: int) -> void:
	# The window's close button, the app being backgrounded on a platform that can kill it, and a plain quit.
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_PREDELETE:
		flush()


## Bind a control to a setting: loads the stored value into [param control], connects its change signal and
## writes on every change.
##
## [param keys] is for an [OptionButton] whose choice must survive the list being reordered or added to: give it
## the stable keys behind the items (a registry's keys) and the setting stores the key rather than the index
## (right only for a list that can never change). Returns the control, so a builder can bind inline.
func bind(control: Control, section: String, key: String, dflt: Variant,
		keys: Array = []) -> Control:
	var stored: Variant = read(section, key, dflt)
	if control is Range:                       # HSlider, VSlider, SpinBox, ProgressBar
		var r := control as Range
		r.set_value_no_signal(clampf(float(stored), r.min_value, r.max_value))
		r.value_changed.connect(func(v: float) -> void: write(section, key, v))
	elif control is OptionButton:
		var o := control as OptionButton
		if keys.is_empty():
			o.select(clampi(int(stored), 0, maxi(0, o.item_count - 1)))
			o.item_selected.connect(func(i: int) -> void: write(section, key, i))
		else:
			o.select(maxi(0, keys.find(stored)))
			o.item_selected.connect(func(i: int) -> void:
				write(section, key, keys[i] if i < keys.size() else dflt))
	elif control is BaseButton:                 # CheckBox, CheckButton, a toggle Button
		var b := control as BaseButton
		b.set_pressed_no_signal(bool(stored))
		b.toggled.connect(func(on: bool) -> void: write(section, key, on))
	elif control is LineEdit:
		var le := control as LineEdit
		le.text = String(stored)
		le.text_changed.connect(func(t: String) -> void: write(section, key, t))
	elif control is TextEdit:
		var te := control as TextEdit
		te.text = String(stored)
		te.text_changed.connect(func() -> void: write(section, key, te.text))
	else:
		push_warning("ghost: Settings.bind cannot persist a %s" % control.get_class())
	return control

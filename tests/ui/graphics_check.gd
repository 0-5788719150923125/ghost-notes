extends Node

## graphics_check - how finely the stage is drawn ([Graphics]) and the panel that chooses it ([GraphicsPanel]).
##
##   tests/run_boot_probe.sh tests/ui/graphics_check.gd 90
##
## THE LIVE VIEWER IS NEVER SLOWER THAN IT WAS: every row's live default is what Godot drew before the menu (the
## project's own SSAO, SSIL, subsurface, shadow and fog qualities, its filtering level, no supersampling), and an
## export's is the finest each row offers - but supersampling, 1.5x (its cost, measured in graphics.gd's header) -
## and never coarser than the live one. A shared row (bounce light) is one choice, off.
##
## THE TIER REACHES THE STAGE: bound in an export, the stage is supersampled and filtered 16x and the shadow filter is
## ultra; in the live viewer, none of that. SUPERSAMPLING IS HELD UNDER ITS CAP: told 2x, a 1080p export's
## 2880 x 1620 takes the whole of it, a 4K stage 1.5x.
##
## A SHADOW KEEPS ITS WIDTH AS THE FILTER'S QUALITY CHANGES: a light on the stage, softened by [ShadowFilter] at one
## quality, has the same blur times radius at the other. The control: the same light off the stage is not rescaled,
## and its width changes - so the rescale is what holds it.
##
## WHAT IS KEPT IS READ, AND WHAT NO OPTION HAS IS NOT: a choice written to `[graphics]` is the value; a value no
## option offers (a hand-edited file) is the default. BOUNCE LIGHT REACHES A MEDIUM'S ENVIRONMENT handed to
## [method Graphics.dress], at a table's reach, and follows the row.
##
## THE PANEL: a cell per row and tier, a shared row one control in both; a live choice applies at once, an export
## choice leaves the live stage as it is; "defaults" puts every row back. (A probe's Settings never reach the disk;
## what it writes is put back in memory at the end.)

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var keep := _kept()
	_defaults()
	await _tiers()
	_shadows()
	_kept_values()
	_bounce()
	await _panel()
	_restore(keep)
	Graphics.tier_override = ""
	Graphics.overrides = {}
	if _fails.is_empty():
		print("graphics_check: ALL OK")
		get_tree().quit(0)
		return
	print("graphics_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _defaults() -> void:
	print("-- defaults")
	var ps := func(name: String) -> Variant: return ProjectSettings.get_setting("rendering/" + name)
	var was := {
		"occlusion": ps.call("environment/ssao/quality"),
		"subsurface": ps.call("environment/subsurface_scattering/subsurface_scattering_quality"),
		"shadows": ps.call("lights_and_shadows/positional_shadow/soft_shadow_filter_quality"),
		"fog": ps.call("environment/volumetric_fog/volume_size"),
		"anisotropy": ps.call("textures/default_filters/anisotropic_filtering_level"),
		"supersample": 1.0,
	}
	_ok(int(ps.call("environment/ssil/quality")) == int(was["occlusion"]),
		"the project's SSIL quality is its SSAO's, so one row holds both")
	for key in Graphics.SETTINGS:
		var row: Dictionary = Graphics.SETTINGS[key]
		var values := Graphics.values_of(key)
		_ok(not String(row.get("label", "")).is_empty() and not String(row.get("blurb", "")).is_empty() and values.size() >= 2,
			"'%s' has a label, a blurb and choices" % key)
		if bool(row.get("shared", false)):
			_ok(values.has(row["default"]) and row["default"] == false, "'%s' is shared and off" % key)
			continue
		_ok(values.has(row["live"]) and values.has(row["export"]), "'%s' defaults are among its choices" % key)
		_ok(was.has(key) and row["live"] == was[key],
			"'%s' live default %s is what Godot drew before (%s)" % [key, str(row["live"]), str(was.get(key))])
		_ok(values.find(row["export"]) >= values.find(row["live"]), "'%s' export default is never coarser than live" % key)
		if key == "supersample":
			_ok(row["export"] == 1.5, "'supersample' export default is 1.5x, for its cost")
		else:
			_ok(row["export"] == values.back(), "'%s' export default is its finest (%s)" % [key, str(row["export"])])


func _tiers() -> void:
	print("-- the tier reaches the stage")
	var st := SubViewport.new()
	st.size = Vector2i(2880, 1620)
	add_child(st)
	Graphics.tier_override = "export"
	Graphics.bind_stage(st)
	_ok(is_equal_approx(st.scaling_3d_scale, 1.5) and st.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR,
		"an export supersamples a 1080p render's stage 1.5x (%.2f)" % st.scaling_3d_scale)
	_ok(st.anisotropic_filtering_level == Viewport.ANISOTROPY_16X, "an export filters 16x (%d)" % st.anisotropic_filtering_level)
	_ok(int(ProjectSettings.get_setting(ShadowFilter.QUALITY_SETTING)) == 5, "an export's shadow filter is ultra")
	Graphics.overrides = {"supersample": 2.0}
	Graphics.apply()
	_ok(is_equal_approx(st.scaling_3d_scale, 2.0), "told 2x, a 1080p render's stage takes the whole of it")
	st.size = Vector2i(3840, 2160)
	await _frames(1)
	_ok(is_equal_approx(st.scaling_3d_scale, 1.5), "a 4K stage, resized, is held to 1.5x under the cap (%.2f)" % st.scaling_3d_scale)
	Graphics.overrides = {}
	_ok(is_equal_approx(Graphics.supersample_for(Vector2i(640, 360), 1.0), 1.0)
		and is_equal_approx(Graphics.supersample_for(Vector2i(8000, 8000), 2.0), 1.0),
		"supersampling is never under 1 (off stays off; past the cap it is off)")
	Graphics.tier_override = "live"
	Graphics.apply()
	_ok(is_equal_approx(st.scaling_3d_scale, 1.0) and st.anisotropic_filtering_level == Viewport.ANISOTROPY_4X
		and int(ProjectSettings.get_setting(ShadowFilter.QUALITY_SETTING)) == 4,
		"the live viewer draws as it did: no supersampling, 4x filtering, high shadows")
	Graphics.tier_override = ""
	_ok(Graphics.tier() == "live", "a process without --export is the live viewer")


func _shadows() -> void:
	print("-- a shadow keeps its width")
	var st := Graphics.stage()
	var on := OmniLight3D.new()
	on.shadow_enabled = true
	st.add_child(on)
	var off := OmniLight3D.new()
	off.shadow_enabled = true
	add_child(off)
	Graphics.tier_override = "live"
	Graphics.apply()
	ShadowFilter.filter(on, 3.0)
	ShadowFilter.filter(off, 3.0)
	var r4 := ShadowFilter.quality_radius()
	var width_on := on.shadow_blur * r4
	var width_off := off.shadow_blur * r4
	Graphics.tier_override = "export"
	Graphics.apply()
	var r5 := ShadowFilter.quality_radius()
	_ok(r5 > r4, "the export's quality spreads a blur wider (%.1f > %.1f)" % [r5, r4])
	_ok(is_equal_approx(on.shadow_blur * r5, width_on), "a light on the stage keeps its width (%.3f, %.3f)" % [on.shadow_blur * r5, width_on])
	_ok(not is_equal_approx(off.shadow_blur * r5, width_off), "CONTROL: one off the stage, not rescaled, does not")
	Graphics.tier_override = "live"
	Graphics.apply()
	_ok(is_equal_approx(on.shadow_blur * r4, width_on), "and back at the live quality, it is as it was")
	on.queue_free()
	off.queue_free()
	Graphics.tier_override = ""


func _kept_values() -> void:
	print("-- what is kept is read")
	Settings.write(Graphics.SECTION, "live_anisotropy", 3)
	_ok(Graphics.value("anisotropy", "live") == 3, "a kept choice is the value")
	Settings.write(Graphics.SECTION, "live_anisotropy", 7)
	_ok(Graphics.value("anisotropy", "live") == Graphics.default_of("anisotropy", "live"),
		"CONTROL: a value no option offers is the default")
	Settings.write(Graphics.SECTION, "live_anisotropy", Graphics.default_of("anisotropy", "live"))
	Graphics.overrides = {"supersample": 1.5}
	_ok(Graphics.value("supersample", "live") == 1.5, "a probe's override is laid over the setting")
	Graphics.overrides = {}
	_ok(Graphics.key_of("bounce", "export") == "bounce" and Graphics.key_of("fog", "export") == "export_fog",
		"a shared row is kept once, a column's row under its tier")


func _bounce() -> void:
	print("-- bounce light reaches a medium")
	var env := Environment.new()
	Graphics.dress(env)
	_ok(not env.ssil_enabled and is_equal_approx(env.ssil_radius, Graphics.BOUNCE_REACH),
		"handed in, it is off and at a table's reach (%.2f m)" % env.ssil_radius)
	Settings.write(Graphics.SECTION, "bounce", true)
	Graphics.apply()
	_ok(env.ssil_enabled, "chosen, it is on in the environment handed in")
	Settings.write(Graphics.SECTION, "bounce", false)
	Graphics.apply()
	_ok(not env.ssil_enabled, "and off again")


func _panel() -> void:
	print("-- the panel")
	var p := GraphicsPanel.new()
	add_child(p)
	await _frames(2)
	var all := true
	for key in Graphics.SETTINGS:
		for t in Graphics.TIERS:
			var o := p.choice(key, t)
			all = all and o != null and o.item_count == Graphics.values_of(key).size()
	_ok(all, "a cell per row and tier, each with the row's choices")
	_ok(p.choice("bounce", "live") == p.choice("bounce", "export"), "a shared row is one control in both columns")
	var st := Graphics.stage()
	var ex := p.choice("supersample", "export")
	ex.select(0)
	ex.item_selected.emit(0)
	_ok(Settings.read(Graphics.SECTION, "export_supersample", -1.0) == 1.0 and is_equal_approx(st.scaling_3d_scale, 1.0),
		"an export choice is kept and leaves the live stage as it is")
	var lv := p.choice("supersample", "live")
	lv.select(2)
	lv.item_selected.emit(2)
	_ok(Settings.read(Graphics.SECTION, "live_supersample", -1.0) == 2.0
		and is_equal_approx(st.scaling_3d_scale, Graphics.supersample_for(st.size, 2.0)) and st.scaling_3d_scale > 1.0,
		"a live choice is kept and applied at once (%.2f on a %dx%d stage)" % [st.scaling_3d_scale, st.size.x, st.size.y])
	p.reset_all()
	_ok(Settings.read(Graphics.SECTION, "live_supersample", -1.0) == 1.0 and Settings.read(Graphics.SECTION, "export_supersample", -1.0) == 1.5
		and is_equal_approx(st.scaling_3d_scale, 1.0) and p.choice("supersample", "export").selected == 1,
		"defaults puts every row back, kept, shown and applied")
	p.visible = false
	await _frames(1)
	p.visible = true
	await _frames(1)
	_ok(p.is_processing(), "open, it reads what the stage costs")
	p.visible = false
	await _frames(1)
	_ok(not p.is_processing(), "closed, it stops")
	p.queue_free()


func _kept() -> Dictionary:
	var out := {}
	if Settings._cfg.has_section(Graphics.SECTION):
		for k in Settings._cfg.get_section_keys(Graphics.SECTION):
			out[k] = Settings._cfg.get_value(Graphics.SECTION, k)
	return out


## The section as it was, in memory (a probe never writes the file).
func _restore(keep: Dictionary) -> void:
	if Settings._cfg.has_section(Graphics.SECTION):
		Settings._cfg.erase_section(Graphics.SECTION)
	for k in keep:
		Settings._cfg.set_value(Graphics.SECTION, k, keep[k])

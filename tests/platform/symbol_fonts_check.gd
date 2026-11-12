extends Node

## symbol_fonts_check - the symbols' fonts are found once (Boot.lend_symbol_fonts): Godot's default font, which
## has no ○ ✓ ✕ ⚙, is handed the system's sans families as its own fallbacks, so the shaper stops asking
## fontconfig each time a label with one is laid out (5-8 ms, against 0.15).
##
##   tests/run_boot_probe.sh tests/platform/symbol_fonts_check.gd 60
##
## Holds, on whatever fonts this machine has:
##   - what is lent is only SYMBOL_FONTS families that are installed, each a SystemFont of that one family at the
##     default font's weight, in that order;
##   - no label grows: a plain label and a button stand exactly as tall with the fallbacks as without. The control
##     is a taller font lent on purpose (Noto Sans Symbols 2 where installed, else a FontVariation of the default
##     with extra spacing), which makes the same label taller;
##   - where DejaVu Sans is installed, ○ ✓ ✕ ⚙ are in a lent font and the default font has none of them (control).
## Nothing is timed.

var _fails: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var base := ThemeDB.fallback_font
	var lent: Array = base.fallbacks.duplicate()
	var have := OS.get_system_fonts()
	var want: Array = Boot.SYMBOL_FONTS.filter(func(f: String) -> bool: return have.has(f))
	var names: Array = lent.map(func(f: Font) -> String: return ", ".join((f as SystemFont).font_names) if f is SystemFont else "?")
	print("lent: %s (installed of the list: %s)" % [names, want])
	var ok_shape := true
	for f in lent:
		var sf := f as SystemFont
		if sf == null or sf.font_names.size() != 1 or sf.font_weight != base.get_font_weight():
			ok_shape = false
	var in_order: Array = want.filter(func(n: String) -> bool: return names.has(n))
	_ok(ok_shape and names == in_order,
		"only installed families of the list are lent, one SystemFont each, at the default font's weight, in order")
	var with := _heights()
	base.fallbacks = []
	var without := _heights()
	_ok(with == without, "no label grows: plain label and button %s with the fallbacks, %s without" % [with, without])
	# The control: a font taller than the default, lent, makes the same label taller
	var tall: Font
	if have.has("Noto Sans Symbols 2"):
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Noto Sans Symbols 2"])
		tall = sf
	else:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_top = 12
		tall = fv
	var taller := tall.get_height(16) > base.get_height(16)
	if tall is SystemFont:
		base.fallbacks = [tall]
		var grown := _heights()
		_ok(taller and grown[0] > without[0], "the control: a taller font lent (%s) makes the label taller (%s against %s)"
			% [", ".join((tall as SystemFont).font_names), grown, without])
	else:
		_ok(taller, "the control: a font taller than the default is told apart by the height test (no Noto Sans Symbols 2 here)")
	base.fallbacks = lent
	if have.has("DejaVu Sans"):
		var found := true
		var none_in_base := true
		for c in [0x25CB, 0x2713, 0x2715, 0x2699]:
			# (has_char counts a font's fallbacks: asked of the default font with them off)
			base.fallbacks = []
			if base.has_char(c):
				none_in_base = false
			base.fallbacks = lent
			if not lent.any(func(f: Font) -> bool: return f.has_char(c)):
				found = false
		_ok(none_in_base, "the default font has none of ○ ✓ ✕ ⚙ (the control: else lending would buy nothing)")
		_ok(found, "and each is in a lent font, found without the system's search")
	else:
		print("  (DejaVu Sans is not installed here: which symbols are lent is not checked)")
	if _fails.is_empty():
		print("symbol_fonts_check: ALL OK")
		get_tree().quit(0)
		return
	print("symbol_fonts_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	get_tree().quit(1)


## A plain label's and a button's minimum heights, laid out now.
func _heights() -> Array:
	var l := Label.new()
	l.text = "Plain words, Ag"
	var b := Button.new()
	b.text = "Plain button"
	add_child(l)
	add_child(b)
	var out := [l.get_combined_minimum_size().y, b.get_combined_minimum_size().y]
	l.free()
	b.free()
	return out


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)

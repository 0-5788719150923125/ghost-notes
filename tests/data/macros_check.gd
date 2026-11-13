extends SceneTree

## macros_check - the names a line of a note may carry ([code]src/data/macros.gd[/code]), filled. No renderer.
##
##   godot --headless --path . --script res://tests/data/macros_check.gd
##
## - A line of names: the default title filled; a missing value leaves nothing dangling (control: every value filled, the
##   line's own separators stand as written); a gap in the middle closes up; no name twice; an unknown macro is left as
##   written; a line naming none is as written (control: the same line naming one is tidied).
## - Prose: filled and nothing else touched - its lines, a leading dash and a doubled separator kept (control: the same text
##   as a line is tidied).
## - What a line names, which a note does not fill (an empty value is filled, `%date%` always is, an unknown one is no claim),
##   and the sentence saying what each filled one stands for, only those.
## - Every row has a label of its own key and a blurb.

const Macros := preload("res://src/data/macros.gd")

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	print("macros_check")
	_line()
	_fill()
	_claims()
	for k in Macros.ROWS:
		_ok(Registry.label(Macros.ROWS, k) == "%" + String(k) + "%" and not Registry.blurb(Macros.ROWS, k).is_empty(),
			"the row %s is labeled by its key and says what it stands for" % k)
	print("macros_check: %s" % ("FAILED (%d)" % _fails if _fails > 0 else "ok"))
	quit(1 if _fails > 0 else 0)


func _line() -> void:
	var v := {"title": "Truthful Tarot", "episode": "The Tower"}
	_ok(Macros.line("%title%: %episode%", v) == "Truthful Tarot: The Tower", "the default title")
	_ok(Macros.line("%title%: %episode%", {"title": "A Note"}) == "A Note", "no episode leaves nothing dangling")
	_ok(Macros.line("%title%: %episode%", {"episode": "Bare"}) == "Bare", "no title neither")
	_ok(Macros.line("with Pen & Ink - %episode%", {"title": "T"}) == "with Pen & Ink", "a byline with no episode is the words alone")
	_ok(Macros.line("with Pen & Ink - %episode%", {"episode": "The Tower"}) == "with Pen & Ink - The Tower", "...and with one, both")
	_ok(Macros.line("%title%: %episode%", {"title": "Truthful Tarot", "episode": "truthful tarot: Named"})
		== "truthful tarot: Named", "a name is never said twice")
	var gap := Macros.line("%title% - %episode% - %date%", {"title": "T", "date": "D"})
	_ok(gap == "T - D", "a gap in the middle closes up (%s)" % gap)
	_ok(Macros.line("%title% #%seed% %what%", {"title": "T", "seed": "7"}) == "T #7 %what%", "an unknown macro is left as written")
	_ok(Macros.line("Part -- %episode%:", {"episode": "One"}) == "Part -- One:",
		"control: every value filled, the line's own separators stand as written")
	_ok(Macros.line("  - a line: -- ", {"title": "T"}) == "- a line: --", "a line naming none is as written")
	_ok(Macros.line("  - a line: -- %episode%", {"title": "T"}) == "a line", "control: the same line naming an empty one is tidied")
	_ok(Macros.line("%date%", {}) == Time.get_date_string_from_system(), "the date is today's unless told")


func _fill() -> void:
	var text := "- %title%, episode %seed%: %episode%\n\nMore -- below."
	var v := {"title": "T", "seed": "7", "episode": "E"}
	_ok(Macros.fill(text, v) == "- T, episode 7: E\n\nMore -- below.", "prose is filled, its lines and marks kept")
	_ok(Macros.fill("- %title%: %episode% -- end", {"title": "T"}) == "- T:  -- end",
		"an empty value in prose leaves its words as written")
	_ok(Macros.line("- %title%: %episode% -- end", {"title": "T"}) == "T: end", "control: the same text as a line is tidied")
	_ok(Macros.fill("50% of %what%", v) == "50% of %what%", "a percent sign and an unknown macro are words")


func _claims() -> void:
	_ok(Array(Macros.named_in("%episode% | %title% #%seed%")) == ["title", "episode", "seed"], "what a line names, in the rows' order")
	_ok(Macros.unfilled("%title%: %episode% (%date%)", {"title": "", "episode": ""}).is_empty()
		and Array(Macros.unfilled("%title% #%seed% %what%", {"title": "T"})) == ["seed"],
		"a value filled empty is filled, the date always is, and an unknown macro is no claim")
	var said := Macros.said({"title": "T"})
	_ok(said.begins_with("%title% is ") and said.contains("%date% is ") and not said.contains("%seed%") and said.ends_with("."),
		"the sentence says what each filled one stands for, only those (%s)" % said)
	_ok(Macros.said({}).begins_with("%date% is "), "control: with nothing filled, the date alone")

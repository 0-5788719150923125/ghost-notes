extends SceneTree

## written_card_check - A WRITTEN CARD ([constant CardTable.FRAMES] `written`; the user, 2026-10-26: "we need to give
## the agents more control over what they draw onto a card, because the current card design may not fit a box full
## of recipe cards. Also note: many recipe cards would be held sideways, not vertical"), with no renderer: what is
## laid out, measured in the fonts it is set in.
##
##   godot --headless --path . --script res://tests/table/written_card_check.gd
##
## - HELD SIDEWAYS: an index card is wider than it is tall, its face as many pixels across its height as a written
##   card's short side; a tall card's face is as it was.
## - THE LOOK KEEPS WHAT IT IS WRITTEN IN: a written card's hand, ruling and picture's place, each one the table
##   knows, unknown ones the defaults, and no ornament; and its text is its front, whatever the staging said.
## - THE WRITING FITS ITS CARD: every line of a recipe is on the card, in order, each row on a rule, inside the card,
##   short of the corner picture where it runs beside it; a long line wraps onto the next rule, indented. The
##   control: a card given far more than it holds says so with an ellipsis, at the smallest pitch.
## - THE DESIGNER WRITES IT: asked for a written card, the designer is asked for its `writing`, never a booklet entry
##   - the control: a card that is not written is asked for its booklet entry.

const RECIPE := ["2 pinches dried sage, crumbled", "1 black peppercorn per traveler", "a thumb of lodestone, rubbed",
	"1 chip of clear quartz", "Warm the base till it steams.", "Grind the sage and add it first.",
	"Stir thrice, sunwise, after each.", "Let it settle before the quartz.", "Done when it glows faintly green."]

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	await process_frame
	_sideways()
	_look()
	_layout()
	_designer()
	print("written_card_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


static func _written(extra := {}) -> Dictionary:
	var frame := {"style": "written", "stock": "#f4efe2", "ink": "#2a2a6a", "accent": "#c0392b"}
	frame.merge(extra, true)
	return CardTable.sanitize_look({"card_size": "index", "frame": frame})


func _sideways() -> void:
	var look := _written()
	var size := CardTable.card_size(look)
	_ok(size.x > size.y, "an index card is not held sideways: %s" % size)
	var px := CardFaces.face_px(look)
	_ok(px.y == CardFaces.WRITTEN_PX and px.x > px.y, "a written index card's face is %s pixels" % px)
	var tall := CardTable.sanitize_look({"card_size": "large"})
	_ok(CardFaces.face_px(tall) == CardFaces.FACE_PX, "a tall card's face changed: %s" % CardFaces.face_px(tall))


func _look() -> void:
	var look := _written({"hand": "quick", "ruling": "grid", "sketch": "band", "ornament": "vine"})
	var f: Dictionary = look["frame"]
	_ok(String(f["hand"]) == "quick" and String(f["ruling"]) == "grid" and String(f["sketch"]) == "band", "a written card's choices were not kept: %s" % f)
	_ok(String(f["ornament"]) == "none", "a written card kept an ornament")
	var odd: Dictionary = _written({"hand": "copperplate", "ruling": "dotted", "sketch": "everywhere"})["frame"]
	_ok(String(odd["hand"]) == "neat" and String(odd["ruling"]) == "ruled" and String(odd["sketch"]) == "corner", "unknown choices were not the defaults: %s" % odd)
	var st := CardTable.staging_of({"look": {"frame": {"style": "Written"}}, "staging": {"source": "box", "text": "booklet"}})
	_ok(String(st["text"]) == "front", "a written card's text is \"%s\", not its front" % st["text"])
	var plain := CardTable.staging_of({"look": {"frame": {"style": "line"}}, "staging": {"source": "deck", "text": "booklet"}})
	_ok(String(plain["text"]) == "booklet", "the control: a card that is not written lost its booklet")


func _layout() -> void:
	var look := _written()
	var face := CardFaces.Face.new()
	face.look = look
	var hand := face._hand()
	face.free()
	var sz := Vector2(CardFaces.face_px(look))
	var m := minf(sz.x, sz.y) * CardFaces.WRITTEN_MARGIN
	var pic := CardFaces.sketch_rect(look)
	var lay := CardFaces.written_layout(look, "Brew for Finding Your Way Home", PackedStringArray(RECIPE), hand)
	var rows: Array = lay["rows"]
	var fs := int(lay["size"])
	var px := float(lay["pitch"])
	_ok(not String((rows[rows.size() - 1] as Dictionary)["text"]).ends_with("..."), "nine lines of a recipe do not fit an index card")
	var said := PackedStringArray()
	var rules: Array = lay["rules"]
	for r in rows:
		var at: Vector2 = (r as Dictionary)["at"]
		var w := hand.get_string_size(String((r as Dictionary)["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		said.append(String((r as Dictionary)["text"]))
		_ok(at.x + w <= sz.x - m * 0.5 + 0.5 and at.y <= sz.y, "a row runs off the card: %s" % (r as Dictionary)["text"])
		if at.y - px * 0.6 < pic.end.y:
			_ok(at.x + w <= pic.position.x, "a row runs into the corner picture: %s" % (r as Dictionary)["text"])
		_ok(rules.any(func(y: float) -> bool: return absf(y - at.y - px * 0.16) < 0.5), "a row is not on a rule: %s" % (r as Dictionary)["text"])
	_ok(" ".join(said).replace("  ", " ") == " ".join(PackedStringArray(RECIPE)), "the rows are not the recipe's words in order:\n%s" % "\n".join(said))
	# a long line wraps, its run indented
	var long := CardFaces.written_layout(look, "Notes", PackedStringArray(["Keep the fire low and stir the pot slowly, sunwise, until the brew turns from olive to a deep sea green and the steam thins."]), hand)
	var lr: Array = long["rows"]
	_ok(lr.size() >= 2 and ((lr[1] as Dictionary)["at"] as Vector2).x > ((lr[0] as Dictionary)["at"] as Vector2).x, "a long line did not wrap onto an indented row: %s" % str(lr))
	# the control: far more than a card holds is cut short, and says so
	var many := PackedStringArray()
	for i in 40:
		many.append("line %d of a great deal more writing than any card holds" % i)
	var over := CardFaces.written_layout(look, "Too Much", many, hand)
	var or_rows: Array = over["rows"]
	_ok(String((or_rows[or_rows.size() - 1] as Dictionary)["text"]).ends_with("...") and float(over["pitch"]) <= minf(sz.x, sz.y) * CardFaces.PITCH.y + 0.01,
		"the control: forty lines were not cut short at the smallest pitch")


func _designer() -> void:
	var card := {"name": "A Brew for Finding Your Way Home", "meaning": "lodestone, pepper, sage, quartz"}
	var w: Dictionary = TablePrompts.designer("The Quiet Crucible", "", _written(), card, false, [], "front")
	var said := String(w["prompt"])
	_ok(said.contains("\"writing\"") and not said.contains("\"booklet\""), "a written card's designer is not asked for its writing:\n%s" % said.right(600))
	var p: Dictionary = TablePrompts.designer("The Quiet Crucible", "", CardTable.sanitize_look({"frame": {"style": "line"}}), card, false, [], "front")
	_ok(String(p["prompt"]).contains("\"booklet\"") and not String(p["prompt"]).contains("\"writing\""), "the control: a printed card's designer is not asked for its booklet")

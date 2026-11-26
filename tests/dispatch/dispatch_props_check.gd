extends Node

## dispatch_props_check - the parts a scene's prop plays and the make chosen for one ([PropMakes], [MakeShelf]), on the Dispatch
## desk's Props card and the Dex ([DispatchProps], [DispatchFormat], [DeskRecipes]), on a library of the gate's own:
##
##   tests/run_boot_probe.sh tests/dispatch/dispatch_props_check.gd 120
##
## - With nothing chosen a part is the desk's own make, the same as the desk drew it before parts could be chosen; a draw of the
##   recipe at another number is another make (the control).
## - A kept prop chosen is built standing on y = 0, centered, at its own size where it is within the part's height, and made that
##   height where it is not (the control: one too tall is scaled, one that fits is not); a name the library lacks is the desk's own.
## - A choice is none, a draw by number or a kept prop's name; anything else is refused.
## - The Dex's choice for a part offers its recipe drawn from many numbers and every kept and seen prop, first filtered by the
##   part's words; the one chosen now says so; Use hands a draw, a kept prop, or a seen prop kept in the library first.
## - The format keeps a choice in its block and hands it to the desk's document; one for no part, or of no shape, is refused.
## - A spare thing's × takes it off the desk (kept as `{aside: true}`, left off the desk built) and "+ Add a prop" sets it out
##   again; the terminal's × stands grayed and refuses (the control), as the switch's does while the script throws it.
## - The desk and the roots stand first on the card ([DispatchDesk], [DispatchRoots]), never taken off: the hollow's own until rolled
##   (the block says nothing of them); a property set stays when rolled, and a roll draws the rest from a number of its own, kept in
##   the block and read by the medium (four legs drawn - the control, the desk's own, none); the desk's own takes it back; Choose…
##   offers the desk's own and drawn desks, Use keeping one; the roots roll too, and are pictured and turned in 3D, grown round the
##   desk, which stands with them. The phones' entry carries their colors (each its own from a palette, or all the make's): a palette
##   set is kept in the block, read by the medium and paints them (the control: the desk's own palette). The terminal's, the radar's
##   and the receiver's entries carry their glass's colors, kept apart from the make chosen: one picked is taken by the terminal's
##   power light, the lights the two throw and the receiver's dial lamp, and draws each screen while the note plays (the controls:
##   the desk's own lamps, lights and screens).
## - The card's rows: every thing the desk works, the mug and the cup of pencils first, each with Choose… (which opens the Dex
##   on its makes, Use choosing for the desk) and Keep, the clock and the tablet only where the script uses them; the Dex on its
##   own offers the desk's things and a desk's recipes to keep, never a desk's mat.
## - Every thing the desk works is a make (next/working_props.md): each role's own builds whole from its shipped file, every part
##   kept, with the faces the desk shows its pictures on. A kept make with those faces is offered for the terminal and plays it -
##   its glass the one the medium shows the program on, its own look on the desk; one with no screen is not offered, and chosen
##   anyway the desk's own plays it (the control). A draw is refused for a part with no recipe. Every hinge of every own make turns
##   about a point on its own part (a joint's `at` in a nested group is in that group's parent's space). The lamp's light is its
##   bulb's: inside its hollow shade, pointing out of the opening, its cone no wider than the opening (the controls: aimed out of
##   the shade's side, or the 66 degree cone it once had). Fed, a make's parts move as its own formulas say: the radar's knob
##   turned to where its printed scale has the gain, the lamp dark at 0.
## - The medium reads a document's choices, dropping any of no shape, and knows what the script asks the desk to build. A make
##   chosen while the note plays builds the desk again with it and keeps the reading's place; the same choices again build
##   nothing (the control).

const ROOT := "user://dispatch_props_check"
const FIXTURE := "res://tests/fixtures/dispatch_note.md"


class LiveSubs extends RefCounted:
	var document := {}

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	var was_library := Library.root
	var was_root := TableEpisode.root
	_clean(ProjectSettings.globalize_path(ROOT))
	Library.root = ROOT.path_join("library")
	Library.discard = func(path: String) -> int: return DirAccess.remove_absolute(path)
	TableEpisode.root = ROOT.path_join("table")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT.path_join("table")))
	_makes()
	_choices()
	await _shelf()
	await _format_and_card()
	_working()
	_medium()
	_remade_live()
	Library.root = was_library
	Library.discard = Callable()
	TableEpisode.root = was_root
	_clean(ProjectSettings.globalize_path(ROOT))
	print("dispatch_props_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## What a part is built as, chosen or not.
func _makes() -> void:
	var seed := 4242
	var own := _desk_made("mug", {}, seed)
	var before := DeskLook.made("mug", hash([seed, "mug"]))
	_ok((own["size"] as AABB).is_equal_approx(before["size"] as AABB), "with nothing chosen the mug is the one the desk drew before (%s, %s)" % [own["size"], before["size"]])
	var cup := _desk_made("pencil_cup", {}, seed)
	var cup_before := DeskLook.made("pencil_cup", hash([seed, "cup"]))
	_ok((cup["size"] as AABB).is_equal_approx(cup_before["size"] as AABB), "and the cup of pencils too")
	var drawn := _desk_made("mug", {"mug": {"recipe": "mug", "seed": 7}}, seed)
	var seven := DeskLook.made("mug", 7)
	_ok((drawn["size"] as AABB).is_equal_approx(seven["size"] as AABB) and not (drawn["size"] as AABB).is_equal_approx(own["size"] as AABB),
		"the control: a draw at another number is another make")
	for n in [own, cup, drawn, before, cup_before, seven]:
		(n["node"] as Node).free()
	# kept props: one too tall for a mug, one that fits
	ThingLibrary.keep({"name": "tall vase", "parts": [{"shape": "lathe", "material": "glaze", "profile": [[0, 0], [5, 0], [6, 40], [0, 40]]}]},
		{"glaze": {"kind": "ceramic", "color": "#335577"}}, "a tall vase")
	ThingLibrary.keep({"name": "tin cup", "parts": [{"shape": "lathe", "material": "tin", "profile": [[0, 0], [4, 0], [4, 9], [0, 9]]}],
		"at": [30, 10]}, {"tin": {"kind": "metal", "color": "#aaaaaa"}}, "a tin cup")
	var vase := PropMakes.made("mug", {"kept": "tall vase"}, seed)
	var vb: AABB = vase["size"]
	_ok(absf(vb.size.y - 0.13) < 0.002 and absf(vb.position.y) < 0.001, "a kept prop too tall for the part is made its height, standing on the ground (%s)" % vb)
	var tin := PropMakes.made("mug", {"kept": "tin cup"}, seed)
	var tb: AABB = tin["size"]
	_ok(absf(tb.size.y - 0.09) < 0.002 and absf(tb.get_center().x) < 0.002 and absf(tb.get_center().z) < 0.002,
		"the control: one that fits keeps its size, centered over where it stands (%s)" % tb)
	var gone := PropMakes.made("mug", {"kept": "no such prop"}, seed)
	var its_own := DeskLook.made("mug", seed)
	_ok((gone["size"] as AABB).is_equal_approx(its_own["size"] as AABB), "a kept name the library lacks is the scene's own")
	for n in [vase, tin, gone, its_own]:
		(n["node"] as Node).free()


func _choices() -> void:
	_ok(PropMakes.valid({}) and PropMakes.valid({"recipe": "mug", "seed": 3}) and PropMakes.valid({"kept": "tin cup"}),
		"none, a draw by number and a kept prop's name are choices")
	_ok(not PropMakes.valid({"kept": ""}) and not PropMakes.valid({"recipe": "mug"}) and not PropMakes.valid("mug") and not PropMakes.valid({"kept": 5}),
		"the control: an empty name, a draw with no number and what is no choice are refused")
	_ok(PropMakes.name_of("mug", {"recipe": "mug", "seed": 3}) == "mug no. 3" and PropMakes.name_of("mug", {"kept": "tin cup"}) == "tin cup",
		"a choice is named for what it is")


## The Dex's choice for the mug.
func _shelf() -> void:
	var seen_ep := TableEpisode.open("elsewhere", 3)
	seen_ep.write_json("table", {"things": [{"name": "enamel mug", "parts": [{"shape": "lathe", "material": "enamel", "profile": [[0, 0], [4, 0], [4, 8], [0, 8]]}]}],
		"materials": {"enamel": {"kind": "painted", "color": "#eeeeee"}}})
	var lib := LibraryProps.new()
	var choice := [{}]
	var shelf := MakeShelf.new("mug", 99, lib, func(c: Dictionary) -> String:
		choice[0] = c
		return "", func() -> Dictionary: return choice[0])
	for i in 200:
		if not lib.seen_list().is_empty():
			break
		await get_tree().process_frame
	var offers := shelf.offers()
	var drawn := offers.filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "drawn")
	var kept := offers.filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "kept_makes").map(func(o: Dictionary) -> String: return String(o["name"]))
	var seen := offers.filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "seen_makes")
	_ok(drawn.size() == PropMakes.DRAWS + 1 and kept.has("tin cup") and kept.has("tall vase") and seen.size() == 1,
		"the mug's makes: the desk's own and %d draws, every kept prop and every seen one (%d, %s, %d)" % [PropMakes.DRAWS, drawn.size(), str(kept), seen.size()])
	_ok(shelf.title() == "The mug" and shelf.find() == "mug" and String(shelf.adds().get("verb", "")) == "Use", "the Dex opens on them filtered by the part's words, each to Use")
	var chosen_now := offers.filter(func(o: Dictionary) -> bool: return not (o["verbs"] as Array).is_empty()).map(func(o: Dictionary) -> String: return String(o["key"]))
	_ok(chosen_now == ["own"], "the one chosen now says so (%s)" % str(chosen_now))
	_ok(shelf.add("draw:3").is_empty() and choice[0] == {"recipe": "mug", "seed": 3}, "Use on a draw chooses it (%s)" % str(choice[0]))
	_ok(shelf.add("kept:tin cup").is_empty() and choice[0] == {"kept": "tin cup"}, "Use on a kept prop chooses it by name")
	var after := shelf.offers().filter(func(o: Dictionary) -> bool: return not (o["verbs"] as Array).is_empty()).map(func(o: Dictionary) -> String: return String(o["key"]))
	_ok(after == ["kept:tin cup"], "and from then it is the one that says so (%s)" % str(after))
	_ok(shelf.add(String(seen[0]["key"])).is_empty() and choice[0] == {"kept": "enamel mug"} and not ThingLibrary.read("enamel mug").is_empty(),
		"Use on a seen prop keeps it in the library first and chooses it by name (%s)" % str(choice[0]))
	_ok(not shelf.add("draw:x9").is_empty() and choice[0] == {"kept": "enamel mug"}, "the control: what it does not offer chooses nothing")
	lib.settle()


## The format's block, the card's rows and the Dex on its own.
func _format_and_card() -> void:
	var fmt := DispatchFormat.for_note({})
	_ok(fmt.choose("mug", {"recipe": "mug", "seed": 5}).is_empty() and fmt.things() == {"mug": {"recipe": "mug", "seed": 5}}, "the format keeps a choice")
	_ok(not fmt.choose("bookshelf", {}).is_empty() and not fmt.choose("mug", {"kept": ""}).is_empty()
		and not fmt.choose("printer", {"recipe": "mug", "seed": 2}).is_empty() and fmt.things().size() == 1,
		"the control: a choice for no part, of no shape, or a draw for a part with no recipe, is refused")
	var block := fmt.capture()
	var again := DispatchFormat.for_note({})
	again.apply(block)
	_ok(again.things() == fmt.things() and (fmt.document()["things"] as Dictionary) == fmt.things(), "it is kept in the block and handed to the desk's document")
	again.apply({"seed": 3, "things": {"bookshelf": {"recipe": "mug", "seed": 1}, "printer": {"recipe": "mug", "seed": 1}, "mug": "a mug"}})
	_ok(again.things().is_empty(), "the control: a block's choices for no part, a draw for a part with no recipe, or of no shape are dropped")
	var sec := DispatchProps.new(fmt)
	var rows := sec.rows().filter(func(r: Dictionary) -> bool: return String(r["key"]).begins_with("role:"))
	var keys: Array = rows.map(func(r: Dictionary) -> String: return String(r["key"]))
	_ok(keys.slice(0, 2) == ["role:mug", "role:pencil_cup"] and keys.has("role:terminal") and keys.has("role:phone") and not keys.has("role:clock"),
		"the card's rows: the mug and the cup, then every thing the desk works, no clock its script does not use (%s)" % str(keys))
	var mug_row: Dictionary = rows[0]
	var verbs: Array = (mug_row["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"]))
	_ok(String(mug_row["name"]) == "mug no. 5" and verbs.has("choose") and verbs.has("own") and not verbs.has("keep")
		and bool((mug_row["verbs"] as Array)[0].get("opens", false)), "the mug's row names its make and offers Choose… and the desk's own; Keep is its 3D view's (%s)" % str(verbs))
	var choices := sec.choices("role:mug")
	_ok(choices is MakeShelf and sec.choices("role:terminal") is MakeShelf and sec.choices("role:bookshelf") == null,
		"Choose… opens the Dex on a part's makes (the control: no such part has none)")
	_ok(choices.add("draw:9").is_empty() and fmt.things()["mug"] == {"recipe": "mug", "seed": 9}, "Use there chooses for the desk")
	_ok(sec.act("role:mug", "own").is_empty() and fmt.things().is_empty(), "the desk's own takes it back")
	_ok(sec.keep_prop("role:mug").is_empty() and not ThingLibrary.read("a mug").is_empty()
		and String(ThingLibrary.read("a mug")["line"]) == String(PropMakes.ROLES["mug"]["blurb"]), "Keep puts the mug on the desk in the library, said to be what the part is")
	# taken off: a spare thing's × takes it off and "+ Add a prop" sets it out again; what the desk or its script works stays
	var by_key := func(k: String) -> Dictionary:
		for r in sec.rows():
			if String((r as Dictionary)["key"]) == k:
				return r
		return {}
	_ok((by_key.call("role:stamp") as Dictionary).has("remove_tip") and (by_key.call("role:terminal") as Dictionary).has("remove_off")
		and sec.adds().is_empty(), "a spare thing's × takes it off; the terminal's stands grayed; nothing taken off, nothing to add")
	_ok(sec.remove("role:stamp").is_empty() and fmt.things()["stamp"] == {"aside": true} and (by_key.call("role:stamp") as Dictionary).is_empty()
		and not sec.adds().is_empty() and sec.offers().any(func(o: Dictionary) -> bool: return String(o["key"]) == "role:stamp" and String(o["shelf"]) == "taken_off"),
		"taken off, it is gone from the card, kept so in the block, and offered on the Dex to set out again")
	_ok(sec.add("role:stamp").is_empty() and not fmt.things().has("stamp") and not (by_key.call("role:stamp") as Dictionary).is_empty(),
		"Use sets it out again")
	_ok(not sec.remove("role:terminal").is_empty() and not fmt.things().has("terminal"), "the control: the terminal cannot be taken off")
	fmt._works = {"switch": true}
	_ok((by_key.call("role:switch") as Dictionary).has("remove_off") and not sec.remove("role:switch").is_empty() and not fmt.things().has("switch"),
		"the switch stays while the script throws it")
	fmt._works = {}
	# the desk and its roots: props of properties and a number of their own, the hollow's own until rolled
	var keys_now: Array = sec.rows().map(func(r: Dictionary) -> String: return String(r["key"]))
	var desk_row: Dictionary = by_key.call("part:desk")
	_ok(keys_now.slice(0, 2) == ["part:desk", "part:roots"] and (desk_row["fields"] as Dictionary).has("base")
		and desk_row.has("remove_off") and (by_key.call("part:roots") as Dictionary).has("remove_off") and fmt.part("desk").is_empty()
		and not fmt.capture().has("desk") and not fmt.capture().has("roots"),
		"the desk and the roots stand first, their properties shown, never taken off; kept as their own, the block says nothing of them")
	_ok(DispatchDesk.values_of({})["base"] == "pedestals" and DispatchDesk.values_of({})["wood"] == "#2a1810"
		and DispatchRoots.values_of({})["hanging"] == 24, "unrolled, the desk and the roots are the hollow's own")
	_ok(sec.set_field("part:desk", "base", "legs").is_empty() and sec.act("part:desk", "roll").is_empty(), "a property set, and rolled")
	var rolled := fmt.part("desk")
	var legs := DispatchDesk.build(DispatchDesk.values_of(rolled), 3)
	var own_desk := DispatchDesk.build(DispatchDesk.values_of({}), 3)
	_ok(rolled.get("base") == "legs" and rolled.has("seed") and fmt.capture()["desk"] == rolled and fmt.document()["desk"] == rolled
		and legs.find_children("Leg*", "", true, false).size() == 4 and own_desk.find_children("Leg*", "", true, false).is_empty(),
		"Roll keeps what is set and draws the rest from a number of its own, kept in the block and the document: four legs - the control, the desk's own, none")
	legs.free()
	own_desk.free()
	_ok(DispatchMedium.makes_of(fmt.document())["desk"] == rolled, "the medium reads the desk as the block keeps it")
	_ok(sec.act("part:desk", "own").is_empty() and fmt.part("desk").is_empty(), "the desk's own takes it back")
	var draws := sec.choices("part:desk")
	_ok(draws != null and draws.offers().size() == 24 and String(draws.offers()[0]["key"]) == "desk:-1"
		and draws.add(String(draws.offers()[3]["key"])).is_empty() and fmt.part("desk").has("seed"),
		"Choose… opens the Dex on the desk's own and desks drawn from many numbers; Use keeps the one picked")
	sec.act("part:desk", "own")
	_ok(sec.act("part:roots", "roll").is_empty() and fmt.part("roots").has("seed")
		and DispatchRoots.values_of(fmt.part("roots")) != DispatchRoots.values_of({}), "the roots roll too, other than their own")
	sec.act("part:roots", "own")
	# the roots pictured and turned in 3D: grown round the note's desk, the desk with them, their box a hollow's height
	var grown: Dictionary = await sec.model_of("part:roots")
	var root_box: AABB = grown.get("box", AABB())
	_ok(grown.get("node") is Node3D and root_box.size.y > 1.5 and (grown["node"] as Node3D).get_child_count() == 2
		and (by_key.call("part:roots") as Dictionary).has("picture"),
		"the roots are pictured and turned in 3D, grown round the desk, which stands with them (%s)" % root_box)
	if grown.get("node") is Node:
		(grown["node"] as Node).free()
	# the phones' colors: properties on their entry, each its own from a palette until set; a palette chosen paints them in it, all
	# the make's leaves them its own (the control: the desk's own palette, office plastics)
	var phone_row: Dictionary = by_key.call("role:phone")
	var phone_verbs: Array = (phone_row["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"]))
	_ok((phone_row.get("fields", {}) as Dictionary).has("palette") and phone_verbs.has("roll") and fmt.part("phones").is_empty()
		and DispatchSet.phones_of({})["palette"] == "office", "the phones' entry carries their colors, office plastics until set (%s)" % str(phone_verbs))
	_ok(sec.set_field("role:phone", "palette", "pastel").is_empty() and fmt.part("phones") == {"palette": "pastel"}
		and DispatchMedium.makes_of(fmt.document())["phones"] == {"palette": "pastel"}, "a palette set is kept in the block and read by the medium")
	var tints := func(makes: Dictionary) -> Array:
		var ds := DispatchSet.new()
		ds.makes = makes
		var n := ds.build(PackedStringArray(["A", "B", "C", "D"]), 3, {})
		var out: Array = []
		for ph in ds.phones:
			for mi in ((ph as Dictionary)["node"] as Node).find_children("*", "MeshInstance3D", true, false):
				var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
				if mat != null and String((mi as MeshInstance3D).get_meta("material", "")) == DispatchSet.PHONE_TINT:
					out.append(mat.get_shader_parameter("color"))
					break
		n.free()
		return out
	var pastel: Array = tints.call({"phones": {"palette": "pastel"}})
	var office: Array = tints.call({})
	var plain: Array = tints.call({"phones": {"colors": "own"}})
	var in_palette := func(cs: Array, k: String) -> bool:
		return not cs.is_empty() and cs.all(func(c: Variant) -> bool: return c is Color and (DispatchSet.PHONE_PALETTES[k] as Array).has(c))
	_ok(in_palette.call(pastel, "pastel") and in_palette.call(office, "office") and not in_palette.call(pastel, "office")
		and not in_palette.call(plain, "office") and not in_palette.call(plain, "pastel"),
		"the phones are painted in the palette chosen (the control: the desk's own, office plastics); all the make's, in none")
	_ok(sec.act("role:phone", "own").is_empty() and fmt.part("phones").is_empty(), "the desk's own takes their colors back")
	# the terminal's and the radar's glass: a color on each entry, the screens' own until set; one picked is kept in the block apart
	# from the make chosen, read by the medium, and its hue taken by the terminal's power light and every light the two throw (the
	# control: the desk's own, its lamps and lights as the makes have them)
	var term_row: Dictionary = by_key.call("role:terminal")
	var radar_row: Dictionary = by_key.call("role:radar")
	_ok((term_row.get("fields", {}) as Dictionary).has("text") and (radar_row.get("fields", {}) as Dictionary).has("glow")
		and DispatchSet.terminal_ink({}).to_html(false) == DispatchScreens.PHOSPHOR.to_html(false)
		and DispatchSet.radar_ink({}).to_html(false) == DispatchScreens.RADAR_GLOW.to_html(false),
		"the terminal's and the radar's entries carry their glass's color, the screens' own until set")
	var picked := DispatchMedium.makes_of(fmt.document()) if sec.set_field("role:terminal", "text", "#ffb000").is_empty() \
		and sec.set_field("role:radar", "glow", "#ffa31a").is_empty() else {}
	_ok(fmt.part("terminal_screen") == {"text": "#ffb000"} and picked.get("terminal_screen") == {"text": "#ffb000"}
		and picked.get("radar_screen") == {"glow": "#ffa31a"} and not picked.has("terminal") and not picked.has("radar"),
		"a color picked is kept in the block and read by the medium, apart from the make chosen (%s)" % str(picked))
	var lit := func(makes: Dictionary) -> Dictionary:
		var ds := DispatchSet.new()
		ds.makes = makes
		var n := ds.build(PackedStringArray(["A", "B"]), 3, {})
		var out := {"lamps": [], "terminal": [], "radar": []}
		for mi in (ds.rigs["terminal"] as PropRig).node.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as ShaderMaterial
			if mat != null and String((mi as MeshInstance3D).get_meta("material", "")) == DispatchSet.TERMINAL_LAMP:
				(out["lamps"] as Array).append(mat.get_shader_parameter("color"))
		for k in ["terminal", "radar"]:
			for l in (ds.rigs[k] as PropRig).lights():
				(out[k] as Array).append((l as Light3D).light_color)
		n.free()
		return out
	var hue_near := func(cs: Array, h: float) -> bool:
		return not cs.is_empty() and cs.all(func(c: Color) -> bool: return absf(c.h - h) < 0.01 and c.s > 0.2)
	var own_lit: Dictionary = lit.call({})
	var amber_lit: Dictionary = lit.call(picked)
	var own_lamp := Color.html(String(((PropMakes.own_of("terminal")["materials"] as Dictionary)[DispatchSet.TERMINAL_LAMP] as Dictionary)["color"]))
	_ok((own_lit["lamps"] as Array).size() >= 2 and (own_lit["lamps"] as Array).all(func(c: Color) -> bool: return c.is_equal_approx(own_lamp))
		and not hue_near.call(own_lit["terminal"], Color.html("#ffb000").h) and not hue_near.call(own_lit["radar"], Color.html("#ffa31a").h),
		"the control: with nothing picked the terminal's lamps and the lights are the makes' own (%s)" % str(own_lit))
	_ok(hue_near.call(amber_lit["lamps"], Color.html("#ffb000").h) and hue_near.call(amber_lit["terminal"], Color.html("#ffb000").h)
		and hue_near.call(amber_lit["radar"], Color.html("#ffa31a").h),
		"a color picked is taken by the terminal's power light and the lights the two throw (%s)" % str(amber_lit))
	_ok(sec.act("role:terminal", "roll").is_empty() and fmt.part("terminal_screen").get("text") == "#ffb000"
		and fmt.part("terminal_screen").has("seed"), "a roll keeps the color picked")
	_ok(sec.act("role:terminal", "own").is_empty() and fmt.part("terminal_screen").is_empty() and sec.act("role:radar", "own").is_empty()
		and fmt.part("radar_screen").is_empty(), "the desk's own takes the colors back")
	# the receiver's glows: its oscilloscope's color and its dial's lamp on its entry, kept apart from its make, the lamp lighting
	# the dial in the color picked (the control: the desk's own, the warm lamp it has always had)
	var recv_row: Dictionary = by_key.call("role:receiver")
	_ok((recv_row.get("fields", {}) as Dictionary).has("scope") and (recv_row.get("fields", {}) as Dictionary).has("dial")
		and (DispatchSet.receiver_inks({})["scope"] as Color).to_html(false) == DispatchScreens.SCOPE_GLOW.to_html(false),
		"the receiver's entry carries its oscilloscope's color and its dial lamp's, the scope's own until set")
	var glows := DispatchMedium.makes_of(fmt.document()) if sec.set_field("role:receiver", "dial", "#b8ffc8").is_empty() \
		and sec.set_field("role:receiver", "scope", "#7fd4ff").is_empty() else {}
	_ok(glows.get("receiver_glow") == {"dial": "#b8ffc8", "scope": "#7fd4ff"} and not glows.has("receiver"),
		"the receiver's colors are kept in the block and read by the medium, apart from its make (%s)" % str(glows))
	var lamp_of := func(makes: Dictionary) -> String:
		var ds := DispatchSet.new()
		ds.makes = makes
		var n := ds.build(PackedStringArray(["A"]), 3, {"dial": PlaceholderTexture2D.new()})
		var m := ds.dial.material_override as StandardMaterial3D if ds.dial != null else null
		var out := m.emission.to_html(false) if m != null else ""
		n.free()
		return out
	var own_dial: String = lamp_of.call({})
	var green_dial: String = lamp_of.call(glows)
	_ok(own_dial == "ffd98c" and green_dial == "b8ffc8", "the dial's lamp lights it in the color picked (%s; the control, its own: %s)" % [green_dial, own_dial])
	var face_of := func(makes: Dictionary) -> String:
		var ds := DispatchSet.new()
		ds.makes = makes
		var n := ds.build(PackedStringArray(["A"]), 3, {"dial": PlaceholderTexture2D.new()})
		var m := ds.dial.material_override as StandardMaterial3D if ds.dial != null else null
		var out := m.albedo_color.to_html(false) if m != null else ""
		n.free()
		return out
	var own_face: String = face_of.call({})
	var pale_face: String = face_of.call({"receiver_glow": {"paper": "#ffffff"}})
	_ok((recv_row.get("fields", {}) as Dictionary).has("paper") and pale_face != own_face and pale_face == "b3b3b3",
		"the dial's face takes the color picked (%s; the control, its own: %s)" % [pale_face, own_face])
	var meter_of := func(makes: Dictionary) -> Array:
		var ds := DispatchSet.new()
		ds.makes = makes
		var n := ds.build(PackedStringArray(["A"]), 3, {"dial": PlaceholderTexture2D.new()})
		var out := []
		for face in [ds.meter, ds.dial]:
			var m := (face as MeshInstance3D).material_override as StandardMaterial3D if face != null else null
			out.append("%s %s" % [m.albedo_color.to_html(false), m.emission.to_html(false)] if m != null else "")
		n.free()
		return out
	var own_meter: Array = meter_of.call({})
	var pale_meter: Array = meter_of.call({"receiver_glow": {"paper": "#ffffff", "dial": "#b8ffc8"}})
	_ok(not String(own_meter[0]).is_empty() and own_meter[0] != pale_meter[0] and pale_meter[0] == pale_meter[1]
		and String(pale_meter[0]).ends_with(" b8ffc8"),
		"the needle meter's card takes the dial's face and lamp, as the dial does (%s; the control, its own: %s)" % [pale_meter, own_meter])
	_ok(sec.act("role:receiver", "own").is_empty() and fmt.part("receiver_glow").is_empty(), "the desk's own takes the receiver's colors back")
	# the security monitor's static on its entry, kept in the block and read by the medium (the control: its own until set)
	var feed_row: Dictionary = by_key.call("role:feed")
	var calm := DispatchMedium.makes_of(fmt.document()) if sec.set_field("role:feed", "static", 0.03).is_empty() else {}
	_ok((feed_row.get("fields", {}) as Dictionary).has("static") and is_equal_approx(DispatchSet.feed_static({}), 0.12)
		and calm.get("feed_screen") == {"static": 0.03} and is_equal_approx(DispatchSet.feed_static(calm["feed_screen"]), 0.03),
		"the security monitor's entry carries how much static shows over its picture, kept in the block (%s)" % str(calm))
	_ok(sec.act("role:feed", "own").is_empty() and fmt.part("feed_screen").is_empty(), "the desk's own takes the monitor's static back")
	var card := PropsCard.new(func() -> Array: return [sec])
	add_child(card)
	card.refresh(true)
	var choose: Button = null
	for e in card.find_children("*", "EntryCard", true, false):
		if not (e as EntryCard).name_label.text.contains("mug"):
			continue
		for b in (e as Node).find_children("*", "Button", true, false):
			if (b as Button).text == "Choose…":
				choose = b
				break
	if choose != null:
		choose.pressed.emit()
	_ok(choose != null and card._shelf != null and card._shelf.title == "Dex - The mug", "the card's Choose… opens the Dex on the part's makes")
	card.queue_free()
	var alone := DispatchProps.new()
	var offered: Array = alone.offers().map(func(o: Dictionary) -> String: return String(o["key"]))
	_ok(alone.rows().is_empty() and offered.has("role:mug") and offered.has("role:radar") and offered.has("role:clock"),
		"the Dex on its own offers every thing the desk works (%s)" % str(offered))
	var recipes := DeskRecipes.new()
	var desk_keys: Array = recipes.offers().map(func(o: Dictionary) -> String: return String(o["key"]))
	_ok(desk_keys.has("desk:mug") and desk_keys.has("desk:taper") and not desk_keys.has("desk:mat"), "a desk's recipes are offered, never its mat (%s)" % str(desk_keys))
	_ok(recipes.keep_prop("desk:cactus").is_empty() and not ThingLibrary.read("a cactus").is_empty(), "and one is kept in the library from its 3D view")
	sec.settle()
	alone.settle()
	recipes.settle()
	fmt.free()
	again.free()


func _medium() -> void:
	var makes := DispatchMedium.makes_of({"things": {"mug": {"recipe": "mug", "seed": 2}, "pencil_cup": {"kept": ""}}})
	_ok(makes == {"mug": {"recipe": "mug", "seed": 2}}, "the medium reads a document's choices, dropping one of no shape (%s)" % str(makes))
	var off := DispatchMedium.makes_of({"things": {"stamp": {"aside": true}, "terminal": {"aside": true}}})
	var set := DispatchSet.new()
	set.makes = off
	var built := set.build(PackedStringArray(["AISLE"]), 7, {}, {})
	var whole := DispatchSet.new()
	var whole_node := whole.build(PackedStringArray(["AISLE"]), 7, {}, {})
	_ok(off.has("stamp") and set.aside("stamp") and not set.aside("terminal") and not set.aside("tracker")
		and not set.rigs.has("stamp") and set.rigs.has("terminal") and whole.rigs.has("stamp"),
		"a spare thing taken off is left off the desk built; the terminal never is, and a desk with nothing taken off has its stamp (the controls)")
	built.free()
	whole_node.free()
	var src := "---\ndesk:\n  clock: true\n---\nWords."
	_ok(DispatchMedium.wants_of(DispatchScript.parse(src), src).has("clock") and DispatchMedium.wants_of(DispatchScript.parse("Words."), "Words.").is_empty(),
		"it knows what the script asks the desk to build (the control: a script that asks nothing)")


## Every thing the desk works as a make: built whole from its own file, offered and played when kept, fed.
func _working() -> void:
	for role in DispatchSet.MAKE_SALTS:
		var row: Dictionary = PropMakes.ROLES.get(role, {})
		if not row.has("own"):
			_ok(row.has("recipe"), "%s is a role with a make of its own" % role)
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(row["own"])))
		var own := PropMakes.own_of(String(role))
		_ok(raw is Dictionary and not own.is_empty() and _parts_in((raw as Dictionary)["thing"]["parts"]) == _parts_in(own["thing"]["parts"])
			and PropMakes.fits(String(role), own["thing"]), "%s's own make builds whole, every part kept, with its faces" % role)
		var b := PropMakes.made(String(role), {}, 1)
		for w in b.get("works", []):
			var wk: Dictionary = (w as Dictionary)["work"]
			var jt: Dictionary = wk.get("joint", {}) if wk.get("joint") is Dictionary else {}
			if String(jt.get("kind", "")) == "hinge":
				var box: AABB = (wk["box"] as AABB).grow(0.005)
				_ok(box.has_point(jt["pivot"]), "%s's %s turns about a point on itself (%s, %s)" % [role, String(wk.get("name", "")), str(jt["pivot"]), str(wk["box"])])
		if b.get("node") is Node:
			(b["node"] as Node).free()
	# the lamp's light leaves by its shade's opening; the control, the shade turned as it once was
	var lamp := PropMakes.own_of("lamp")
	_ok(_lamp_aimed(lamp["thing"], lamp["materials"]) < 5.0, "the lamp's light points out of its shade's opening (%.1f degrees off)" % _lamp_aimed(lamp["thing"], lamp["materials"]))
	var sideways: Dictionary = (lamp["thing"] as Dictionary).duplicate(true)
	var wide: Dictionary = (lamp["thing"] as Dictionary).duplicate(true)
	for part in sideways["parts"]:
		if String((part as Dictionary).get("name", "")) == "lamp":
			part["light"]["aim"] = [1, 0.3, 0]
	for part in wide["parts"]:
		if String((part as Dictionary).get("name", "")) == "lamp":
			part["light"]["angle"] = 66
	_ok(_lamp_aimed(sideways, lamp["materials"]) > 5.0 and _lamp_aimed(wide, lamp["materials"]) > 5.0,
		"the controls: aimed out of the shade's side, or with the cone it once had, the light is off its opening (%.1f, %.1f)"
		% [_lamp_aimed(sideways, lamp["materials"]), _lamp_aimed(wide, lamp["materials"])])
	# a kept terminal of another color, and a kept thing with no screen
	var own_t := PropMakes.own_of("terminal")
	var green: Dictionary = (own_t["materials"] as Dictionary).duplicate(true)
	(green["beige"] as Dictionary)["color"] = "#2f6b3a"
	var gt: Dictionary = (own_t["thing"] as Dictionary).duplicate(true)
	gt["name"] = "green terminal"
	ThingLibrary.keep(gt, green, "a green terminal")
	var lib := LibraryProps.new()
	var shelf := MakeShelf.new("terminal", 5, lib, func(_c: Dictionary) -> String: return "", func() -> Dictionary: return {})
	var names: Array = shelf.offers().map(func(o: Dictionary) -> String: return String(o["name"]))
	var drawn := shelf.offers().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) == "drawn")
	_ok(names.has("green terminal") and not names.has("tin cup") and drawn.size() == 1,
		"the terminal's makes: its own alone (no recipe to draw), a kept make with a screen, never one without (%s)" % str(names))
	lib.settle()
	var labels := PackedStringArray(["AISLE", "VAN"])
	var s := DispatchSet.new()
	s.makes = {"terminal": {"kept": "green terminal"}}
	var node := s.build(labels, 7, {}, {})
	var case_color := _color_of((s.rigs["terminal"] as PropRig).node, "beige")
	_ok(s.terminal_screen != null and s.terminal_screen == (s.rigs["terminal"] as PropRig).face("screen") and case_color.is_equal_approx(Color("#2f6b3a")),
		"a kept terminal plays the desk's: its glass the one shown, its own color (%s)" % str(case_color))
	var t := DispatchSet.new()
	t.makes = {"terminal": {"kept": "tin cup"}}
	var tn := t.build(labels, 7, {}, {})
	_ok(t.terminal_screen != null and _color_of((t.rigs["terminal"] as PropRig).node, "beige").is_equal_approx(Color("#c7ba9e")),
		"the control: a kept thing with no screen chosen anyway, the desk's own plays it")
	s.pose(0.0, {"radar": {"gain": 9.0}, "lamp": {"lit": 0.0}})
	var knob := (s.rigs["radar"] as PropRig).value("gain", "angle")
	_ok(is_equal_approx(deg_to_rad(knob), DispatchSet.gain_angle(9.0)) and not s.lamp.visible,
		"fed, the radar's knob turns to its printed nine (%f) and the lamp goes dark" % knob)
	s.pose(0.0, {"lamp": {"lit": 1.0}})
	_ok(s.lamp.visible and s.lamp.light_energy > 1.0, "the lamp lit again, at its own strength (%f)" % s.lamp.light_energy)
	_ok(s.phones.size() == 2 and (s.phones[1]["rig"] as PropRig).face("tape").get_child(0) is Label3D
		and ((s.phones[1]["rig"] as PropRig).face("tape").get_child(0) as Label3D).text == "VAN", "each phone's tape says its name")
	node.free()
	tn.free()


## How far (degrees) lamp [param thing]'s light points off its shade's opening - its cone counted, so a cone wider than the
## opening is off by how much wider; and 180 where its light is not inside the shade.
static func _lamp_aimed(thing: Dictionary, materials: Dictionary) -> float:
	var safe := Props.sanitize({"things": [thing], "materials": materials}, [])
	var b := Props.build((safe["things"] as Array)[0], safe["materials"], 1)
	var rig := PropRig.new(b)
	var out := 180.0
	var light := rig.light("lamp") as SpotLight3D
	var shade := rig.part("lamp")
	if light != null and shade != null:
		var sm: MeshInstance3D = shade.find_children("*", "MeshInstance3D", true, false)[0]
		var px: Transform3D = rig._in_node(shade) * (sm.get_meta("xform") as Transform3D)
		var opens := (px.basis * Vector3.UP).normalized()
		var lxf := rig._in_node(light)
		var aim := (lxf.basis * Vector3.FORWARD).normalized()
		var local := px.affine_inverse() * lxf.origin
		var part: Dictionary = {}
		for q in (safe["things"] as Array)[0]["parts"]:
			if String(((q as Dictionary).get("work", {}) as Dictionary).get("name", "")) == "lamp":
				part = q
		var prof: Array = part.get("profile", [])
		var rim := 0.0
		var deep := 0.0
		for pt in prof:
			rim = maxf(rim, (pt as Vector2).x)
			deep = maxf(deep, (pt as Vector2).y)
		var inside := local.y > 0.0 and local.y * 100.0 < deep and Vector2(local.x, local.z).length() * 100.0 < rim
		var opening := rad_to_deg(atan2(rim, deep - local.y * 100.0))
		if inside:
			out = rad_to_deg(acos(clampf(opens.dot(aim), -1.0, 1.0))) + maxf(light.spot_angle - opening, 0.0)
	(b["node"] as Node).free()
	return out


static func _parts_in(parts: Array) -> int:
	var n := 0
	for p in parts:
		n += _parts_in(p["parts"]) if (p as Dictionary).has("parts") else 1
	return n


## The color of the first mesh under [param n] made of material [param mat].
static func _color_of(n: Node, mat: String) -> Color:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if String((mi as MeshInstance3D).get_meta("material", "")) == mat and (mi as MeshInstance3D).material_override is ShaderMaterial:
			return ((mi as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("color")
	return Color.BLACK


## Role [param role]'s make on the desk of [param seed] as [param makes] chooses it, built as the desk builds it.
func _desk_made(role: String, makes: Dictionary, seed: int) -> Dictionary:
	var s := DispatchSet.new()
	s._seed = seed
	s.makes = makes
	return s._rig(role).built


## A make chosen in the live document while the note plays.
func _remade_live() -> void:
	var st := SubViewport.new()
	st.size = Vector2i(160, 90)
	st.own_world_3d = true
	add_child(st)
	var md := DispatchMedium.new()
	md.feed = ShowFeed.new()
	md.mount(st)
	var body := FileAccess.get_file_as_string(FIXTURE)
	var subs := LiveSubs.new()
	subs.document = {"source": body, "dispatch": {"seed": 3}}
	md._subs = subs
	md._doc_key = ""
	md._ensure_doc()
	var words := DispatchScript.rehearsal(DispatchScript.parse(body), 0.32)
	md._now = 4.0
	md.take_words(words.slice(0, 12))
	var built_n := md._built_n
	var set_was: DispatchSet = md._set
	var tall_was := _mug_tall(md._set)
	(subs.document["dispatch"] as Dictionary)["things"] = {"mug": {"recipe": "mug", "seed": 11}}
	md._ensure_doc()
	var want := DeskLook.made("mug", 11)
	var tall := (want["size"] as AABB).size.y
	(want["node"] as Node).free()
	_ok(md._set != set_was and absf(_mug_tall(md._set) - tall) < 0.001 and md._built_n == built_n,
		"a make chosen while the note plays builds the desk with it and keeps the reading's place (%.3f, was %.3f, want %.3f)" % [_mug_tall(md._set), tall_was, tall])
	var set_now: DispatchSet = md._set
	md._ensure_doc()
	_ok(md._set == set_now, "the control: the same choices again build nothing")
	# colors picked while the note plays: each screen drawn in its own, the title in the terminal's hue, the reading kept where it is
	# (the control: the screens' own until then)
	var inks := func() -> PackedStringArray:
		return PackedStringArray([md._screens._term_ink.to_html(false), md._screens._radar_ink.to_html(false), md._screens._scope_ink.to_html(false)])
	var own_inks: PackedStringArray = inks.call()
	(subs.document["dispatch"] as Dictionary)["terminal_screen"] = {"text": "#ffb000"}
	(subs.document["dispatch"] as Dictionary)["radar_screen"] = {"glow": "#ffa31a"}
	(subs.document["dispatch"] as Dictionary)["receiver_glow"] = {"scope": "#7fd4ff"}
	var own_static := md._feed_static
	(subs.document["dispatch"] as Dictionary)["feed_screen"] = {"static": 0.03}
	md._ensure_doc()
	_ok(is_equal_approx(own_static, 0.12) and is_equal_approx(md._feed_static, 0.03),
		"the security monitor's static set while the note plays is the snow over its picture (%.2f, was %.2f)" % [md._feed_static, own_static])
	_ok(own_inks == PackedStringArray([DispatchScreens.PHOSPHOR.to_html(false), DispatchScreens.RADAR_GLOW.to_html(false), DispatchScreens.SCOPE_GLOW.to_html(false)])
		and inks.call() == PackedStringArray(["ffb000", "ffa31a", "7fd4ff"]) and absf(md._title.ink.h - Color.html("#ffb000").h) < 0.01
		and md._built_n == built_n, "colors picked while the note plays draw each screen in its own, the reading kept (%s, was %s)" % [inks.call(), own_inks])
	md.free()
	st.queue_free()


## How tall the mug on desk [param s] stands (m).
func _mug_tall(s: DispatchSet) -> float:
	var box := AABB()
	var first := true
	for mi in s.mug.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = s.mug.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clean(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)

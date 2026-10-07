extends SceneTree

## components_check - the registry, the capability table and the templates (next/notes.md step 7).
##
##   godot --headless --path . --script tests/components_check.gd
##
## THE REGISTRY HOLDS TOGETHER: every component is of a known family, asks only for capabilities
## the table has, brings only components that exist, and keeps a block no other component keeps;
## every template's components exist, and a template that runs a song, a reading or a clip has a
## component that gives what that session needs.
##
## THE TABLE ANSWERS FOR THE PLATFORM, two-sided: on this desktop every capability but the agents'
## is possible; asked as Android (`Deps.platform_override`), only the text is - every other
## component is impossible, with a reason, and Subprocess starts nothing.
##
## "+" GRAYS WHAT IS NOT READY, WITH THE REASON: an agent made missing in `Deps._resolved` (the cache
## a launch reads - never a seam) grays the Tarot component and its tooltip says why; asked as
## Android, the menu offers nothing but what is possible there; a component already attached is
## not offered again.

## The programs every agent resolves - the same list splash_agents_check hides.
const AGENT_PROGRAMS := ["claude", "codex", "aws"]

var _fails: Array = []


func _initialize() -> void:
	_registry()
	_desktop()
	_android()
	_menu()
	if _fails.is_empty():
		print("components_check: ALL OK")
		quit(0)
		return
	print("components_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


func _registry() -> void:
	print("-- the registry")
	var blocks := {}
	for k in Components.REGISTRY:
		var row: Dictionary = Components.REGISTRY[k]
		_ok(Components.FAMILIES.has(row["family"]), "%s: family '%s' is known" % [k, row["family"]])
		for c in row["capabilities"]:
			_ok(Capabilities.TABLE.has(c), "%s: capability '%s' is in the table" % [k, c])
		for r in row["requires"]:
			_ok(Components.REGISTRY.has(r), "%s: brings '%s', which exists" % [k, r])
		var b := String(row["block"])
		if not b.is_empty():
			_ok(not blocks.has(b), "%s: its block '%s' is its own (also %s)" % [k, b, blocks.get(b, "-")])
			blocks[b] = k
	# the blocks the panels keep are the components' blocks
	for b in ["voice", "picture", "illustrations", "look", "bookends", "tarot", "synthesis"]:
		_ok(blocks.has(b), "the document block '%s' belongs to a component" % b)
	var gives := {"song": "audio", "reading": "reading", "clip": "picture"}
	for t in Components.TEMPLATES:
		var tpl: Dictionary = Components.TEMPLATES[t]
		var keys: Array = tpl["components"]
		_ok(keys.all(func(k: String) -> bool: return Components.REGISTRY.has(k)), "%s: every component exists (%s)" % [t, keys])
		var provided: Array = []
		for k in Components.with_required(keys):
			provided.append_array(Components.REGISTRY[k]["provides"])
		var need := String(gives[String(tpl["session"])])
		_ok(provided.has(need), "%s: a %s session has something that gives %s" % [t, tpl["session"], need])
	_ok(Components.unmet(["text", "voice"]).is_empty(), "text + voice needs nothing more")
	_ok(Components.unmet(["voice"]) == ["text"], "a voice alone needs a text (%s)" % str(Components.unmet(["voice"])))
	_ok(Components.with_required(["tarot"]).has("voice"), "Tarot brings a voice with it")


func _desktop() -> void:
	print("-- on this desktop")
	Deps.platform_override = ""
	for c in Capabilities.TABLE:
		if String(c).begins_with("agent:"):
			continue
		var why := Capabilities.impossible(c)
		if c == "checkout":
			_ok(why.is_empty() == OS.has_feature("editor"), "checkout is possible exactly when run from the repository")
			continue
		_ok(why.is_empty(), "'%s' is possible here (%s)" % [c, why])
	_ok(not Capabilities.impossible("nonsense").is_empty(), "an unknown capability is impossible, and says so")
	for k in Components.REGISTRY:
		if not ((Components.REGISTRY[k] as Dictionary)["capabilities"] as Array).any(func(c: String) -> bool: return c.begins_with("agent:")):
			_ok(Components.impossible(k).is_empty(), "%s can be attached here" % k)


func _android() -> void:
	print("-- asked as Android")
	Deps.platform_override = "android"
	_ok(not Capabilities.impossible("subprocess").is_empty(), "no program can start (%s)" % Capabilities.impossible("subprocess"))
	for k in Components.REGISTRY:
		var why := Components.impossible(k)
		if k == "text":
			_ok(why.is_empty(), "the text is possible: a phone keeps notes")
		else:
			_ok(not why.is_empty(), "%s is impossible, with a reason (%s)" % [k, why])
	_ok(Subprocess.start("ffmpeg", PackedStringArray(["-version"])) <= 0, "Subprocess starts nothing")
	_ok(Deps.execute("ffmpeg", ["-version"]) == -1, "and Deps.execute runs nothing")
	Deps.platform_override = ""


func _menu() -> void:
	print("-- the \"+\" menu")
	var menu := PopupMenu.new()
	# AN AGENT MADE MISSING the way a launch would find it, as splash_agents_check does: every
	# agent's program resolved to "" in the cache a launch reads.
	var keep := Deps._resolved.duplicate()
	for prog in AGENT_PROGRAMS:
		Deps._resolved[prog] = ""
	_ok(not Capabilities.not_ready("agent:writer").is_empty(), "the control: with %s gone, no writer is ready" % str(AGENT_PROGRAMS))
	Components.attach_menu(menu, ["text"])
	var tarot := _item(menu, "tarot")
	_ok(tarot >= 0 and menu.is_item_disabled(tarot), "with no writer, Tarot is offered GRAYED")
	_ok(tarot >= 0 and menu.get_item_tooltip(tarot).contains("writer"),
		"...and its tooltip says why ('%s')" % (menu.get_item_tooltip(tarot).get_slice("\n\n", 1) if tarot >= 0 else ""))
	_ok(_item(menu, "text") < 0, "the text, attached already, is not offered again")
	_ok(_item(menu, "look") >= 0 and not menu.is_item_disabled(_item(menu, "look")), "the Look is offered, lit")
	Deps._resolved = keep
	Components.attach_menu(menu, ["text"])
	tarot = _item(menu, "tarot")
	_ok(tarot >= 0 and menu.is_item_disabled(tarot) == not Components.not_ready("tarot").is_empty(),
		"and with the agents back, Tarot is lit exactly when this machine has a writer and a painter")
	# asked as Android: nothing but what a phone can do
	Deps.platform_override = "android"
	Components.attach_menu(menu, [])
	var offered: Array = []
	for i in menu.item_count:
		offered.append(String(menu.get_item_metadata(i)))
	_ok(offered == ["text"], "on Android, \"+\" offers the text and nothing else (%s)" % str(offered))
	Deps.platform_override = ""
	menu.free()


func _item(menu: PopupMenu, key: String) -> int:
	for i in menu.item_count:
		if String(menu.get_item_metadata(i)) == key:
			return i
	return -1

extends SceneTree

## components_check - the registry, the capability table, and what a note is made of
## (next/notes.md step 7; "Composition, not templates").
##
##   godot --headless --path . --script tests/components_check.gd
##
## THE REGISTRY HOLDS TOGETHER: every component is of a known family, asks only for capabilities
## the table has, brings only components that exist, names only slots and workspaces that exist,
## and keeps a block no other component keeps.
##
## A NOTE IS WHAT ITS COMPONENTS MAKE IT, with no list of kinds of note anywhere: there is no
## template table to read. Which WORKSPACE runs a note is read off what is attached - its own
## panel for its words or a song, a reading's for a voice, the lab's, a clip's - and a component
## another BRINGS gives way to the one that brings it (Cards brings a Voice, and Cards' workspace
## runs the show). Two-sided: the same voice without Cards is a reading.
##
## SLOTS: a note has one clock and one presentation. A second clock is refused with a sentence that
## names the one in the way (a Voice on a note with a Song), and a Picture on a show of cards is
## refused the same way - and lit again once what held the slot is gone.
##
## EVERYTHING ATTACHED COMES OFF: what "+" attaches, detach removes - the same blocks, and with a
## Picture the illustrations that only come with it. Two refusals, each with its reason: the text
## is the note, and a Voice stays while the Cards that bring it do.
##
## THE TABLE ANSWERS FOR THE PLATFORM, two-sided: on this desktop every capability but the agents'
## is possible; asked as Android (`Deps.platform_override`), only the text is - every other
## component is impossible, with a reason, "+" offers nothing, and Subprocess starts nothing.
##
## "+" GRAYS WHAT IS NOT READY, WITH THE REASON: an agent made missing in `Deps._resolved` (the cache
## a launch reads - never a seam) grays the Cards component and its tooltip says why; a component
## already attached is not offered again. AND WHAT A NOTE CANNOT USE YET: a Look on a note with no
## picture is grayed and says to attach a Picture first (two-sided: with a song and a Picture it is
## lit); so is YouTube, which needs a picture and a sound to make a video of. What "+" offers is
## derived: every component that is attached by itself, with no list per panel.
##
## A NOTE'S COMPONENTS ARE READ OFF ITS BLOCKS: a storyboard is there when the `scenes:` block
## names a file or holds the note's own, an empty one included. A note with only a song is not
## offered the media that print a reading (the novel, the notebook, the tablet).

## The programs every agent resolves - the same list splash_agents_check hides.
const AGENT_PROGRAMS := ["claude", "codex", "grok", "aws"]

var _fails: Array = []


func _initialize() -> void:
	_registry()
	_composition()
	_slots()
	_detach()
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
	# an agent role names its registry by path (Capabilities is under the agents): each row loads
	for role in Capabilities.ROLES:
		var reg := load(String(Capabilities.ROLES[role])) as GDScript
		_ok(reg != null and reg.get_script_constant_map().get("REGISTRY") is Dictionary,
			"the %s role's registry loads and lists its backends" % role)
	for cap in Capabilities.TABLE:
		var role := String((Capabilities.TABLE[cap] as Dictionary).get("role", ""))
		_ok(role.is_empty() or Capabilities.ROLES.has(role),
			"%s: its role '%s' has a registry" % [cap, role])
	# a card any panel can show is named by path (the registry is under every card): each row loads,
	# answers the card contract, and the rows that name one are exactly the keys panels build
	var scripted: Array = []
	for k in Components.REGISTRY:
		var path := String((Components.REGISTRY[k] as Dictionary).get("script", ""))
		if path.is_empty():
			continue
		scripted.append(k)
		var card := load(path) as GDScript
		_ok(card != null and card.get_script_constant_map().get("KEY") == (Components.REGISTRY[k] as Dictionary)["block"],
			"%s: its card's script loads, and its KEY is the row's block" % k)
		var has := {}
		if card != null:
			for m in card.get_script_method_list():
				has[String(m["name"])] = true
		_ok(has.has("for_note") and has.has("capture") and has.has("apply"),
			"%s: its card answers for_note, capture and apply" % k)
	var keys: Array = NoteCards.KEYS.duplicate()
	keys.sort()
	scripted.sort()
	_ok(keys == scripted, "the cards a panel builds are the rows that name a script (%s / %s)" % [keys, scripted])
	var none := NoteCards.make("no-such-component")
	_ok(none.get_child_count() == 0, "CONTROL: a component with no row gets an empty card, and says so")
	none.free()
	var blocks := {}
	for k in Components.REGISTRY:
		var row: Dictionary = Components.REGISTRY[k]
		_ok(Components.FAMILIES.has(row["family"]), "%s: family '%s' is known" % [k, row["family"]])
		for c in row["capabilities"]:
			_ok(Capabilities.TABLE.has(c), "%s: capability '%s' is in the table" % [k, c])
		for r in row["requires"]:
			_ok(Components.REGISTRY.has(r), "%s: brings '%s', which exists" % [k, r])
		for slot in row["slots"]:
			_ok(Components.SLOTS.has(slot), "%s: its slot '%s' is one there is" % [k, slot])
		var ws := String(row["workspace"])
		_ok(ws.is_empty() or Components.WORKSPACES.has(ws), "%s: its workspace '%s' is one there is" % [k, ws])
		var b := String(row["block"])
		if not b.is_empty():
			_ok(not blocks.has(b), "%s: its block '%s' is its own (also %s)" % [k, b, blocks.get(b, "-")])
			blocks[b] = k
		# what "+" writes for a component is in a block that is its own, or it comes with another
		for written in Components.attach_blocks(k):
			_ok(written == b, "%s: attaching it writes its own block ('%s', not '%s')" % [k, b, written])
	# the blocks the panels keep are the components' blocks
	for b in ["voice", "picture", "illustrations", "look", "bookends", "cards", "synthesis", "song", "clip", "scenes", "youtube"]:
		_ok(blocks.has(b), "the document block '%s' belongs to a component" % b)
	_ok(not (Components as Script).get_script_constant_map().has("TEMPLATES"), "there is no table of kinds of note")
	_ok(Components.unmet(["text", "voice"]).is_empty(), "text + voice needs nothing more")
	_ok(Components.unmet(["voice"]) == ["text"], "a voice alone needs a text (%s)" % str(Components.unmet(["voice"])))
	_ok(Components.with_required(["cards"]).has("voice"), "Cards brings a voice with it")
	var song_media := Medium.offered(["audio"])
	_ok(song_media.has("auto") and song_media.has("full") and song_media.has("comic")
		and not song_media.has("book") and not song_media.has("notebook") and not song_media.has("tablet")
		and not song_media.has("table"), "a song alone is offered the media that need nothing more (%s)" % str(song_media))
	_ok(Medium.offered(["audio", "reading"]).has("tablet") and not Medium.offered(["audio", "reading"]).has("table"),
		"a reading is offered every pickable medium")
	_ok(not Medium.takes_settings("auto") and Medium.takes_settings("full"), "Auto takes no settings; Full frame does")


func _composition() -> void:
	print("-- a note is what its components make it")
	_ok(Components.attached_of({}) == ["text"], "a new note is its text and nothing else")
	_ok(Components.workspace_of(["text"]) == "note", "...and opens in the note's own panel")
	var cases := [
		[{"song": {"path": ""}}, "note", "a song"],
		[{"song": {"path": ""}, "picture": {"medium": "auto"}}, "note", "a song and a Picture"],
		[{"song": {"path": ""}, "picture": {}, "scenes": {"sequence": []}}, "note", "a song, a Picture and a storyboard"],
		[{"voice": {}}, "reading", "a voice"],
		[{"voice": {}, "picture": {}, "scenes": {"storyboard": "default"}, "look": {}}, "reading", "a voice with a picture, a storyboard and a look"],
		[{"synthesis": {}}, "lab", "a voice lab"],
		[{"clip": {"path": ""}}, "clip", "a clip"],
		[{"cards": {}}, "cards", "a show of cards"],
		[{"cards": {}, "voice": {}, "look": {}}, "cards", "a show of cards with its voice written down"],
	]
	for c in cases:
		var ws := Components.workspace_of(Components.attached_of(c[0]))
		_ok(ws == String(c[1]), "%s runs in the '%s' workspace (%s)" % [c[2], c[1], ws])
	# two-sided: it is Cards that takes the voice's note from the reading, not the voice's absence
	_ok(Components.workspace_of(["text", "voice"]) == "reading" and Components.workspace_of(["text", "voice", "cards"]) == "cards",
		"the same voice is a reading alone, and a show's with the Cards that bring it")
	for w in Components.WORKSPACES:
		if w == "note":
			continue
		var named := false
		for k in Components.REGISTRY:
			named = named or String(Components.REGISTRY[k]["workspace"]) == w
		_ok(named, "the '%s' workspace is some component's" % w)
	# a storyboard, read off the scenes: block
	_ok(Components.attached_of({"scenes": {"storyboard": "default"}}).has("storyboard"), "a storyboard file named is a storyboard attached")
	_ok(Components.attached_of({"scenes": {"sequence": []}}).has("storyboard"), "the note's own, with nothing in it yet, is one too")
	_ok(not Components.attached_of({"scenes": {}}).has("storyboard"), "an empty scenes: block is none")
	_ok(Storyboard.of_block(Components.attach_blocks("storyboard")["scenes"])["kind"] == "own",
		"attaching a storyboard starts the note's own, with nothing written in it")
	_ok(String((Components.attach_blocks("picture")["picture"] as Dictionary).get("medium", "")) == "auto",
		"a Picture starts as the seeded show: the Auto medium")
	# every attachable component is seen once its blocks are in the note
	for k in Components.REGISTRY:
		var add := Components.attach_blocks(k)
		if not add.is_empty():
			_ok(Components.attached_of(add).has(k), "%s: what attaching it writes is read back as attached" % k)


func _slots() -> void:
	print("-- one clock, one presentation")
	_ok(Components.holder("clock", ["text", "song"]) == "song" and Components.holder("clock", ["text"]).is_empty(),
		"a song holds the clock; a plain note's is free")
	var why := Components.cannot_attach("voice", ["text", "song"])
	_ok(why.contains("clock") and why.contains("Song") and why.contains("detach"),
		"a Voice on a note with a Song is refused, naming what is in the way (%s)" % why)
	_ok(Components.cannot_attach("voice", ["text"]).is_empty() or not Components.not_ready("voice").is_empty(),
		"...and has room on a note with no clock")
	_ok(Components.slot_note("song", ["text", "voice"]).contains("Voice"), "a Song on a reading is refused the same way")
	_ok(Components.slot_note("clip", ["text", "song"]).contains("Song"), "a clip is a clock too")
	why = Components.slot_note("picture", ["text", "cards"])
	_ok(why.contains("presentation") and why.contains("Cards"), "a Picture on a show of cards: the table is its presentation (%s)" % why)
	_ok(Components.slot_note("cards", ["text", "voice"]).is_empty(), "Cards on a reading with no Picture has room")
	_ok(Components.slot_note("cards", ["text", "voice", "picture"]).contains("Picture"), "...and none once a Picture holds the presentation")
	_ok(Components.slot_note("cards", ["text", "song"]).contains("Song"), "Cards brings a voice, so a song's clock is in its way too")
	_ok(Components.slot_note("look", ["text", "song", "voice"]).is_empty(), "a component with no slot is never refused for one")


func _detach() -> void:
	print("-- everything attached comes off")
	for k in Components.REGISTRY:
		var add: Array = Components.attach_blocks(k).keys()
		if add.is_empty():
			continue
		var mine := Components.blocks_of(k)
		_ok(add.all(func(b: String) -> bool: return mine.has(b)), "%s: detaching removes what attaching wrote (%s)" % [k, str(mine)])
		_ok(Components.detach_blocker(k, ["text", k]).is_empty(), "%s: alone on a note, it can be detached" % k)
	_ok(Components.blocks_of("picture").has("illustrations"), "a Picture takes the illustrations that only come with it")
	_ok(not Components.detach_blocker("text", ["text"]).is_empty(), "the text cannot be detached: it is the note")
	var why := Components.detach_blocker("voice", ["text", "cards", "voice"])
	_ok(why.contains("Cards"), "a Voice stays while the Cards that bring it do (%s)" % why)
	_ok(Components.detach_blocker("cards", ["text", "cards", "voice"]).is_empty(), "...and Cards itself comes off")
	_ok(Components.detach_blocker("picture", ["text", "song", "picture", "look"]).is_empty(),
		"a Picture a Look depends on still comes off: the Look then says what it is waiting for")
	_ok(not Components.needs_note("look", ["text", "song", "look"]).is_empty(), "...which it does")


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
	_ok(Components.offered(["text"]).is_empty(), "\"+\" offers nothing: a note is its text (%s)" % str(Components.offered(["text"])))
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
	var cards := _item(menu, "cards")
	_ok(cards >= 0 and menu.is_item_disabled(cards), "with no writer, Cards is offered GRAYED")
	_ok(cards >= 0 and menu.get_item_tooltip(cards).contains("writer"),
		"...and its tooltip says why ('%s')" % (menu.get_item_tooltip(cards).get_slice("\n\n", 1) if cards >= 0 else ""))
	_ok(_item(menu, "text") < 0, "the text is not offered: it is the note")
	_ok(_item(menu, "scenes") < 0 and _item(menu, "masks") < 0 and _item(menu, "illustrations") < 0,
		"what only comes with another component is not offered by itself")
	# a plain note is offered everything that can be attached, with no list of what "decides" it
	for k in ["song", "voice", "voice_lab", "clip", "cards", "picture", "storyboard", "look", "bookends", "youtube"]:
		_ok(_item(menu, k) >= 0, "a plain note's \"+\" offers %s" % k)
	var look := _item(menu, "look")
	_ok(look >= 0 and menu.is_item_disabled(look) and menu.get_item_tooltip(look).contains("Picture"),
		"a Look on a note with no picture is grayed, and says to attach a Picture (%s)" % (menu.get_item_tooltip(look).get_slice("\n\n", 1) if look >= 0 else ""))
	var song := _item(menu, "song")
	_ok(song >= 0 and not menu.is_item_disabled(song), "a Song is lit on a plain note")
	Components.attach_menu(menu, ["text", "song", "picture"])
	look = _item(menu, "look")
	_ok(look >= 0 and not menu.is_item_disabled(look), "...and the Look lit once the note has a song and a Picture")
	_ok(_item(menu, "picture") < 0, "a Picture already attached is not offered again")
	var yt := _item(menu, "youtube")
	_ok(yt >= 0 and not menu.is_item_disabled(yt), "YouTube is lit on a song with a Picture")
	var voice := _item(menu, "voice")
	_ok(voice >= 0 and menu.is_item_disabled(voice) and menu.get_item_tooltip(voice).contains("clock"),
		"a second clock is grayed in the menu, with the reason")
	Components.attach_menu(menu, ["text", "song"])
	yt = _item(menu, "youtube")
	_ok(yt >= 0 and menu.is_item_disabled(yt) and menu.get_item_tooltip(yt).contains("Picture"),
		"...and YouTube grayed on a song with none, saying to attach a Picture (%s)" % (menu.get_item_tooltip(yt).get_slice("\n\n", 1) if yt >= 0 else ""))
	var board := _item(menu, "storyboard")
	_ok(board >= 0 and menu.is_item_disabled(board), "a storyboard needs a Picture too")
	# a reading takes a Picture and a storyboard, as a song does: the pairing is nobody's feature
	Components.attach_menu(menu, ["text", "voice", "picture"])
	board = _item(menu, "storyboard")
	_ok(board >= 0 and not menu.is_item_disabled(board), "a voice with a Picture is offered a storyboard, lit")
	var with_yt: Array = Components.attached_of({"voice": {}, "youtube": {}})
	Components.attach_menu(menu, with_yt)
	_ok(with_yt.has("youtube") and _item(menu, "youtube") < 0, "a note with a youtube block has it, and is not offered it again")
	_ok(Components.attach_blocks("youtube") == {"youtube": {}}, "attaching YouTube writes its block")
	Deps._resolved = keep
	Components.attach_menu(menu, ["text"])
	cards = _item(menu, "cards")
	_ok(cards >= 0 and menu.is_item_disabled(cards) == not Components.not_ready("cards").is_empty(),
		"and with the agents back, Cards is lit exactly when this machine has a writer and a painter")
	# asked as Android: nothing but what a phone can do
	Deps.platform_override = "android"
	Components.attach_menu(menu, ["text"])
	_ok(menu.item_count == 0, "on Android, \"+\" offers nothing (%d)" % menu.item_count)
	Deps.platform_override = ""
	menu.free()


func _item(menu: PopupMenu, key: String) -> int:
	for i in menu.item_count:
		if String(menu.get_item_metadata(i)) == key:
			return i
	return -1

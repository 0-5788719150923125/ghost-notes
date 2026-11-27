extends Node

## delivery_lab_check - the deliveries on the Voice card and their Lab (next/delivery.md, "Tuning a delivery"; [DeliverySection],
## [DeliveryLab], [DeliveryShelf], [DeliveryLibrary], [DeliveryVersions], [DeliveryDesign]):
##
##   tests/run_boot_probe.sh tests/reading/delivery_lab_check.gd 180
##
## Holds, with a stand-in voice host that only records what it is asked:
##
## - the list holds every delivery and act the script says, under "Said in the script", none the script does not (control), and a
##   name the script defines itself is listed as the script's, with no Lab;
## - unticked, a delivery is set aside: its words read plain, the block says so, and what an agent is told leaves it out; ticked
##   again it moves them (the control); its Strength scales what it moves;
## - its Lab opens in the tree on the script's own line, offering lines made to hear it on after the script's; one the script never
##   says opens on its family's line, said with it (plain, without); a curve drawn there is the note's version at once and reaches the words the script says it on
##   (and no others); a run of hand moves is one version; an act's pitch drawn there rides to its word; As said asks the host with
##   the delivery on the words, Plain without; each a toggle as Test is, pressed again to stop;
## - a designer's version is a version of its own, and picking the first again says it so; Keep puts it in the library (moved
##   aside) and the note follows the library; As it comes says it as kept; removed from the Dex, as the bank says it;
## - a new delivery from the Dex is the note's own, renamed and said what it is in its Lab, and an agent is told it;
## - GPU on the Voice row says where the host makes the voices, and why not on the card where it was asked for;
## - the block keeps it all and gives it back; the designer's text lands as a spec, a broken one is said (control); the shelf
##   offers the bank, the acts and the kept, and adds nothing opened on its own (control).
##
## Read-only: the library, the versions and the conversations are moved to the gate's own folder. The panel is built by hand (its
## `_ready` starts the python voice host) and its column moved into the tree.

class Host extends VoiceHost:
	var asked: Array = []
	var measured: Array = []

	func request(text: String, voice: String, out_path: String,
			params: Dictionary = {}, phonemes: Variant = null) -> int:
		asked.append({"voice": voice, "out": out_path, "params": params})
		return 7000 + asked.size()

	func measure(wavs: Array) -> int:
		measured.append(wavs)
		return 9000 + measured.size()

	func cancel(_ids: Array) -> void:
		pass

	func is_up() -> bool:
		return true


const HOME := "user://delivery_lab_check"
const SCRIPT := """A herald carried a bird, a mouse, a frog, [and]{drawn, held} five arrows.

<!-- delivery: excited -->
The king laughed at the gifts and called for his army at once.

<!-- delivery: giddy2 = faster, higher -->
They rode out.
"""

var _fails: Array = []
var _ed: ReadingPanel
var _host: Host
var _card: VoiceCard


func _ready() -> void:
	_clear(ProjectSettings.globalize_path(HOME))
	TextRefine.root = HOME + "/refine"
	DeliveryVersions.root_aside = HOME
	Library.root = HOME + "/library"
	Library.discard = func(path: String) -> int:
		return DirAccess.remove_absolute(path)
	DeliveryLibrary.version += 1
	_ed = ReadingPanel.new()
	_ed._build_panel()
	_ed.walk = TextWalk.new()
	if _ed._doc != null:
		_ed._doc._sync = false
	_ed.remove_child(_ed._panel)
	add_child(_ed._panel)
	_host = Host.new()
	_ed._host = _host
	_ed._cast._names = PackedStringArray([Manuscript.NARRATOR])
	var first := ReadingPanel.SLOT_DEFAULTS.duplicate()
	first["voice"] = "kokoro"
	_ed._cast._slots = [first]
	_ed._cast._order = PackedStringArray([Manuscript.NARRATOR])
	_ed._cast.slot = 0
	_ed._on_synthesized(0, {"backends": {"kokoro": {"blend": true, "inflect": true}}})
	_ed._cast.fill_voices([{"id": "kokoro", "name": "kokoro", "backend": "kokoro", "speakers": 1, "installed": true}])
	_ed._cast._apply_slot(0)
	_ed._sr = 22050
	var player := AudioStreamPlayer.new()
	add_child(player)
	_ed._audition._player = player
	_ed._text.text = SCRIPT
	_card = VoiceCard.new(_ed._cast)
	add_child(_card)
	_run.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
		print("delivery_lab_check: FAIL  " + msg)


func _rows() -> Dictionary:
	var out := {}
	for r in _card._deliveries.rows():
		out[String((r as Dictionary)["key"])] = r
	return out


## Every word of the script as planned now, with its token: [[text, token]].
func _words(text := SCRIPT) -> Array:
	var out: Array = []
	for c in ReadingPlan.make(text, "", _ed._plan_ask(text))["chunks"]:
		for t in (c as Dictionary)["tokens"]:
			out.append([String((t as Dictionary)["text"]), t])
	return out


func _token(word: String, text := SCRIPT) -> Dictionary:
	for w in _words(text):
		if String(w[0]) == word:
			return w[1]
	return {}


func _run() -> void:
	var sec := _card._deliveries
	var cast := _ed._cast
	# the list
	var rows := _rows()
	_ok(rows.has("drawn") and rows.has("held") and rows.has("excited") and String(rows["excited"]["group"]) == "script",
		"the list does not hold what the script says: %s" % str(rows.keys()))
	_ok(not rows.has("sad") and not rows.has("building"), "the list holds what the script never says (control)")
	_ok(rows.has("giddy2") and String(rows["giddy2"].get("line", "")).begins_with("defined in the script")
			and (rows["giddy2"]["verbs"] as Array).is_empty(), "a name the script defines is not listed as the script's")
	_ok(bool(rows["excited"]["on"]) and not rows["excited"].has("remove_tip"), "a delivery the script says can be taken off")
	# set aside, and back
	var moved := _token("laughed").get("x", {}) as Dictionary
	_ok(not moved.is_empty(), "excited moves nothing before it is set aside (control): %s" % str(moved))
	sec.set_on("excited", false)
	_ok(bool(cast.deliveries["excited"]["off"]) and not _token("laughed").has("x"), "a delivery set aside still moves its words")
	_ok(DeliveryBank.listed(cast.delivery_tuning()).contains("never to be written: excited"), "an agent is not told it is set aside")
	_ok(cast.capture()["deliveries"]["excited"]["off"] == true, "the block does not keep it set aside")
	sec.set_on("excited", true)
	_ok(_token("laughed").get("x", {}) == moved, "ticked again, it does not move its words as before")
	sec.set_field("excited", "strength", 0.5)
	var half := float((_token("laughed").get("x", {}) as Dictionary).get("pitch", 0.0))
	_ok(absf(half - 0.5 * float(moved.get("pitch", 0.0))) < 0.05, "its strength does not scale it: %s against %s" % [half, moved.get("pitch")])
	sec.set_field("excited", "strength", null)

	# its Lab
	_ok(sec.open_lab("drawn").is_empty(), "the Lab does not open")
	var lab: DeliveryLab = sec._labs.get("drawn")
	_ok(lab != null and lab.is_inside_tree() and lab.visible, "the Lab is not in the tree, shown")
	_ok(lab._words.text.contains("[and]{drawn, held}"), "the Lab is not first heard on the script's own line: %s" % lab._words.text)
	_ok(lab._pick_words.item_count > 2 and String(lab._pick_words.get_item_metadata(1)).contains("]{drawn}"),
		"the Lab offers no lines made to hear an act on, after the script's")
	# a delivery the script says on a paragraph of its own: the words after its mark, closed round them
	_ok(sec.lines_for("excited") == ["<!-- delivery: excited -->The king laughed at the gifts and called for his army at once.<!-- /delivery -->"],
		"the script's line under a mark of its own is not offered: %s" % str(sec.lines_for("excited")))
	# one the script never says opens on words made to show it, which it moves (and plain, the control, moves nothing)
	sec._picked("sad")
	var sad: DeliveryLab = sec._labs.get("sad")
	_ok(sad != null and not sad._words.text.is_empty() and sad._words.text == DeliveryHearing.words_for("sad")[0]
			and DeliveryHearing.words_for("sad")[0] == DeliveryHearing.FAMILY_WORDS[String(DeliveryBank.BANK["sad"]["family"])],
		"a delivery the script never says does not open on its family's line: %s" % (sad._words.text if sad != null else "no Lab"))
	var sad_words := _words(sad.passage())
	_ok(sad_words.any(func(w: Array) -> bool: return (w[1] as Dictionary).has("x"))
			and _words(DeliveryHearing.plain_of(sad.passage())).all(func(w: Array) -> bool: return not (w[1] as Dictionary).has("x")),
		"the made words are not said with the delivery, or plain moves them (control)")
	sec.remove("sad")
	var rate: CurveEdit = lab._axes["rate"]
	rate.points = [[0.0, 1.3]]
	lab._edited()
	var dir := cast.delivery_folder("drawn")
	_ok(DeliveryVersions.versions(dir).size() == 1 and bool(cast.deliveries["drawn"]["tuned"]), "a curve drawn is not the note's version")
	var and_ := _token("and")
	_ok(absf(float((and_.get("x", {}) as Dictionary).get("rate", 1.0)) - 1.3) < 0.01, "the curve does not reach the word: %s" % str(and_))
	_ok(not _token("bird").has("x"), "the curve moves a word the script does not say it on (control)")
	rate.points = [[0.0, 1.2]]
	lab._edited()
	_ok(DeliveryVersions.versions(dir).size() == 1, "a run of hand moves is not one version")
	# an act's pitch, drawn in the Lab
	for c in lab._acts_box.get_children():
		if String(c.get_meta("act")) == "drawn":
			for n in c.find_children("*", "CurveEdit", true, false):
				(n as CurveEdit).points = [["stress<", 0.0], [0.4, 2.0], [1.0, -1.0]]
	lab._edited()
	var acts: Array = _token("and").get("acts", [])
	var drew := acts.filter(func(a: Array) -> bool: return String(a[0]) == "drawn")
	_ok(drew.size() == 1 and (drew[0] as Array).size() == 3 and str(drew[0][2]).contains("0.4"), "an act's pitch drawn does not ride to its word: %s" % str(acts))
	# heard as said, and plain
	_host.asked.clear()
	lab._play("said")
	var said_tokens: Array = []
	for a in _host.asked:
		said_tokens.append_array(((a as Dictionary)["params"] as Dictionary).get("tokens", []))
	_ok(said_tokens.any(func(t: Dictionary) -> bool: return t.has("acts")), "As said does not ask the host with the delivery on its words")
	lab._process(0.0)
	_ok(_ed.testing() and lab._said_b.text == "As said ■" and lab._plain_b.text == "Plain", "As said does not say it is playing")
	var asked_said := _host.asked.size()
	lab._play("said")
	lab._process(0.0)
	_ok(not _ed.testing() and lab._said_b.text == "As said" and _host.asked.size() == asked_said,
		"As said pressed again does not stop it")
	_host.asked.clear()
	lab._play("plain")
	var plain_tokens: Array = []
	for a in _host.asked:
		plain_tokens.append_array(((a as Dictionary)["params"] as Dictionary).get("tokens", []))
	_ok(not plain_tokens.is_empty() and plain_tokens.all(func(t: Dictionary) -> bool: return not t.has("acts") and not t.has("x")),
		"Plain asks the host with a delivery on its words")
	_ed.stop_testing()

	# a designer's version, picking, keeping
	var mine := lab.spec_now()
	var theirs := mine.duplicate(true)
	theirs["axes"] = {"rate": [[0.0, 0.8]]}
	_ok(lab.put(theirs, "slower", "claude").is_empty() and DeliveryVersions.versions(dir).size() == 2, "a designer's version is not its own")
	_ok(sec.act("drawn", "version:0").is_empty() and absf(float(lab.spec_now()["axes"]["rate"][0][1]) - 1.2) < 0.01,
		"the first version picked again is not said so")
	_ok(DeliveryDesign.landed(DeliveryDesign.text_of(theirs)).get("spec", {}).get("axes", {}).has("rate")
			and DeliveryDesign.landed("{ not json").has("error")
			and (DeliveryDesign.landed('{"axes": {"wobble": [[0, 1]]}, "colour": 1}')["unknown"] as Array).size() == 2,
		"the designer's text does not land as a spec, or a broken one is not said")
	lab._keep()
	_ok(not DeliveryLibrary.find("drawn").is_empty() and not cast.deliveries["drawn"].has("tuned")
			and String(sec.said_as("drawn")["from"]) == "kept", "Keep does not put it in the library, the note following it")
	var shelf := DeliveryShelf.new()
	_ok(shelf.adds().is_empty() and shelf.offers().any(func(o: Dictionary) -> bool: return String(o["key"]) == "kept:drawn")
			and shelf.offers().any(func(o: Dictionary) -> bool: return String(o["key"]) == "bank:excited")
			and shelf.offers().any(func(o: Dictionary) -> bool: return String(o["shelf"]) == "acts"),
		"the shelf does not offer the kept, the bank and the acts, or adds opened on its own (control)")
	_ok(shelf.act("kept:drawn", "forget").is_empty() and String(sec.said_as("drawn")["from"]) == "bank", "removed from the Dex, it is not the bank's")

	# a new one of the note's own
	sec._picked("")
	_ok(cast.deliveries.has("new delivery") and sec._labs.has("new delivery"), "a new delivery is not put on the list, its Lab open")
	_ok(sec.rename_own("new delivery", "Giddy!").is_empty() and cast.deliveries.has("giddy") and not cast.deliveries.has("new delivery"),
		"a new delivery is not renamed as a script can say it")
	_ok(not sec.rename_own("giddy", "excited").is_empty(), "a new delivery takes a bank name (control)")
	cast.deliveries["giddy"]["about"] = "breathless and quick"
	_ok(DeliveryBank.listed(cast.delivery_tuning()).contains("giddy (breathless and quick)"), "an agent is not told the note's own")
	_ok(_token("rode", "They [rode]{giddy} out.").get("x") == null and _ed._plan_of("They [rode]{giddy} out.").get("note", "") == "",
		"a name of the note's own nothing has shaped moves something, or is reported unknown")

	# the block, given back
	var block := _card.capture()
	cast.deliveries = {}
	cast.apply(block)
	_ok(cast.deliveries.has("giddy") and cast.deliveries.has("excited"), "the block does not give the deliveries back: %s" % str(block.get("deliveries")))
	_ok(DeliveryHearing.passage_of("drawn", "and") == "[and]{drawn}" and DeliveryHearing.plain_of("[and]{drawn} so") == "and so"
			and DeliveryHearing.passage_of("excited", "Go now.").begins_with("<!-- delivery: excited -->"), "the words heard are not marked as they should be")

	# where the voices are made, as the host says it: GPU's words follow, and a card asked for and not used says why
	cast.show_device("cpu", "no CUDA here")
	_ok(cast._gpu != null and cast._gpu.tooltip_text.contains("no CUDA here"), "GPU does not say why the card was not used")
	cast.show_device("gpu", "")
	_ok(cast._gpu.tooltip_text.ends_with("on the graphics card.") and not cast._gpu.tooltip_text.contains("no CUDA here"),
		"GPU does not say the voices are made on the card")

	_clear(ProjectSettings.globalize_path(HOME))
	# the Labs are windows: closed and freed before the tree goes
	for l in sec._labs.values():
		if is_instance_valid(l):
			(l as Window).hide()
			(l as Window).queue_free()
	await get_tree().process_frame
	Library.discard = Callable()
	Library.root = Library.ROOT
	print("delivery_lab_check: ", "ALL OK" if _fails.is_empty() else "%d FAILED" % _fails.size())
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(d))
	DirAccess.remove_absolute(dir)

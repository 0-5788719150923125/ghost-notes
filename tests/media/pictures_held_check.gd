extends SceneTree

## Gate for what listing a note's pictures costs the disk ([Illustrations], [PipelineCard]): the Pipeline card asks every
## section for its rows as long as the note is open, and a row asks the library about its picture's versions a score of
## times. It holds:
##
## - what the library found on disk is held: a version's file taken away behind its back is still listed (the control:
##   looked at again, [method Illustrations.look_again], it is gone); a reference file likewise;
## - anything the library writes looks again: a version chosen, and the file taken away is gone from the list;
## - the list handed out is the caller's own: taking one out of it takes nothing from the next ask;
## - the look's signature is held with them, and made again when the style is written;
## - the Pipeline card asks for its rows four times a second while something is being made, and once a second while
##   nothing is (the control: a section made busy is asked again a quarter second on).
##
## Run: godot --headless --path . --script tests/media/pictures_held_check.gd

const DIR := "user://pictures_held_check"

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.set("_read_only", true)
	var I = load("res://src/media/illustrations.gd")
	I.use_for_test({})
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var files: Array = []
	for n in 3:
		var f := dir.path_join("v%d.png" % n)
		img.fill(Color(float(n) * 0.3, 0, 0))
		img.save_png(f)
		files.append(f)
	var key := "held"
	I._put_entry(key, {"prompt": "a picture", "placement": "full", "current": 1, "versions": [
		{"file": files[0], "sig": "a"}, {"file": files[1], "sig": "b"}]})
	_ok(I.versions(key).size() == 2 and I.path_for(key) == files[1], "two versions on disk, the second chosen")
	# taken away behind the library's back: held as it was found, until it looks again
	DirAccess.remove_absolute(files[1])
	var held: int = I.versions(key).size()
	I.look_again()
	var looked: int = I.versions(key).size()
	_ok(held == 2 and looked == 1 and I.path_for(key) == files[0],
		"a file taken away is still listed until the library looks again (held %d; the control, looked at again, %d)" % [held, looked])
	# the caller's own list
	var mine: Array = I.versions(key)
	mine.clear()
	_ok(I.versions(key).size() == 1, "the list handed out is the caller's: emptied, the next ask has its version")
	# a write looks again
	img.save_png(files[1])
	I._put_entry(key, {"prompt": "a picture", "placement": "full", "current": 0, "versions": [
		{"file": files[0], "sig": "a"}, {"file": files[1], "sig": "b"}, {"file": files[2], "sig": "c"}]})
	var three: int = I.versions(key).size()
	DirAccess.remove_absolute(files[2])
	I.select_version(key, 1)
	_ok(three == 3 and I.versions(key).size() == 2 and I.current_index(key) == 1,
		"what the library writes looks again: a version chosen, and the file gone since is gone from the list (%d, then %d)" % [three, I.versions(key).size()])
	# references and the look's signature
	I.add_references([files[0], files[1]], "image")
	var kept: Array = I.references("image")
	var refs: int = kept.size()
	var sig: String = I.current_signature("image")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(String(kept[1])))
	var refs_held: int = I.references("image").size()
	var sig_held: String = I.current_signature("image")
	I.look_again()
	_ok(refs == 2 and refs_held == 2 and sig_held == sig and I.references("image").size() == 1 and I.current_signature("image") != sig,
		"the reference files and the look's signature are held with them (%d held; looked at again %d, and another look)" % [refs_held, I.references("image").size()])
	var before: String = I.current_signature("image")
	I.set_style("in heavy ink", "image")
	_ok(I.current_signature("image") != before, "a style written is another look at once")
	for f in files + I.references("image"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(String(f)))
	DirAccess.remove_absolute(dir)
	I.use_for_test({})
	_cadence()
	print("pictures_held_check: %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## The card's own beat: a quarter second while a section is busy, a second while none is.
func _cadence() -> void:
	var Card: GDScript = load("res://src/ui/pipeline_card.gd")
	var Stub: GDScript = load("res://tests/ui/pipeline_stub_section.gd")
	var card = Card.new()
	var section = Stub.new("Cadence gate")
	var row := PipelineRow.new("one", "one")
	row.state = "made"
	section.listed = [row]
	section.has_missing = false
	card.add(section)
	card._t = 0.0
	card._process(0.01)
	var idle: float = card._t
	section.is_busy = true
	card._t = 0.0
	card._process(0.01)
	var busy: float = card._t
	_ok(is_equal_approx(idle, Card.EVERY_IDLE) and is_equal_approx(busy, Card.EVERY) and Card.EVERY_IDLE >= 4.0 * Card.EVERY,
		"the card asks for its rows once a second while nothing is being made (next in %.2f s; the control, a busy section, in %.2f s)" % [idle, busy])
	card.free()


func _ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		_fails += 1

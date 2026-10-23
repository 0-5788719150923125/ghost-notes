extends Node

## voice_made_check - a voice made while the note is open reaches the Voice card ([method
## ReadingPanel.voice_made]):
##
##   tests/run_boot_probe.sh tests/reading/voice_made_check.gd 60
##
## WHAT IT HOLDS (2026-10-22, the user: "I just spent a couple hours training the actor's voice ... When I
## click on the play button, it's still using the regular Piper voice"): the Voice card asked the host
## for its voices once, as the note opened, so the voice the Actor card trained in the hours after was
## never on it, and nothing read in it. A stand-in host counts what it is asked, and the gate holds that:
##
## - a list asked again keeps what the person picked (it went back to the voice the tab opened with);
## - a voice made asks the host for the voices again, and until the list holds it nothing changes;
## - once it does, the READER reads in it - picked, kept in the reader's slot, the note touched to be
##   saved - even while another voice's tab is shown, and that voice keeps its own;
## - it is read in once: a list after that keeps what is picked.
##
## THE CONTROL: the list holding the new voice, arriving with no voice made, leaves the reader's voice as
## it was - so "reads in it" above is the voice made's doing.
##
## The panel is built by hand and never added to the tree (its `_ready` starts the python voice host),
## as tests/reading/audition_check.gd builds it.

class Host extends VoiceHost:
	var listed := 0

	func list_voices() -> int:
		listed += 1
		return 2000 + listed

	func is_up() -> bool:
		return true


const MADE := "actor-probe"
const ANN := "Ann"

var _fails: Array = []
var _ed: ReadingPanel
var _host: Host


func _ready() -> void:
	_ed = ReadingPanel.new()
	_ed._build_panel()
	if _ed._doc != null:
		_ed._doc._sync = false
	_ed.remove_child(_ed._panel)
	add_child(_ed._panel)
	_host = Host.new()
	_ed._host = _host
	var c := _ed._cast
	c._names = PackedStringArray([Manuscript.NARRATOR, ANN])
	c._order = PackedStringArray([Manuscript.NARRATOR, ANN])
	c._slots = [ReadingPanel.SLOT_DEFAULTS.duplicate(), ReadingPanel.SLOT_DEFAULTS.duplicate()]
	c.slot = 0
	c._rebuild_tabs()
	c.fill_voices(_list(false))
	_run.call_deferred()


func _run() -> void:
	var c := _ed._cast
	_ok(c._selected_voice_id() == ReadingPanel.DEFAULT_VOICE, "the first list did not pick the tab's voice")
	# the person picks another: a list asked again keeps it
	_pick("en_US-lessac-medium")
	c.fill_voices(_list(false))
	_ok(c._selected_voice_id() == "en_US-lessac-medium" and _voice(0) == "en_US-lessac-medium",
		"a list asked again put back %s over the voice picked" % c._selected_voice_id())
	# THE CONTROL: the new voice listed, none made - the reader keeps its voice
	c.fill_voices(_list(true))
	_ok(c._selected_voice_id() == "en_US-lessac-medium" and _voice(0) == "en_US-lessac-medium",
		"control: a voice listed with none made became the reader's")
	# another voice's tab shown, then the voice made
	c._select_tab(1)
	_ed._dirty = false
	_ed.voice_made(MADE)
	_ok(_host.listed == 1, "a voice made asked the host for the voices %d times, not once" % _host.listed)
	c.fill_voices(_list(false))
	_ok(_voice(0) == "en_US-lessac-medium" and c.slot == 1, "a list without the voice made changed the reader")
	c.fill_voices(_list(true))
	_ok(c.slot == 0, "the reader's tab is not shown when the voice made lands")
	_ok(c._selected_voice_id() == MADE and _voice(0) == MADE, "the reader reads in %s, not the voice made" % _voice(0))
	_ok(_voice(1) == ReadingPanel.DEFAULT_VOICE, "the other voice became %s" % _voice(1))
	_ok(_ed._dirty, "the note was not touched to keep the reader's new voice")
	# once: picked away from it, the next list keeps that
	_pick("en_US-lessac-medium")
	c.fill_voices(_list(true))
	_ok(_voice(0) == "en_US-lessac-medium", "the voice made was read in again on a later list")
	print("")
	if _fails.is_empty():
		print("voice_made_check: ALL OK")
	else:
		for f in _fails:
			print("voice_made_check: FAIL - ", f)
		print("voice_made_check: %d FAILED" % _fails.size())
	_ed._panel.queue_free()
	for _i in 4:
		await get_tree().process_frame
	_ed.free()
	get_tree().quit(0 if _fails.is_empty() else 1)


## The voices the host lists, with the voice made among them or not.
func _list(made: bool) -> Array:
	var out: Array = [{"id": "en_US-lessac-medium", "name": "lessac medium", "speakers": 1, "installed": true},
		{"id": ReadingPanel.DEFAULT_VOICE, "name": "libritts high", "speakers": 904, "installed": true}]
	if made:
		out.push_front({"id": MADE, "name": "Probe (their own voice)", "speakers": 1, "installed": true})
	return out


## The person picks [param id] on the Voice card.
func _pick(id: String) -> void:
	var c := _ed._cast
	for k in c.voice_meta.size():
		if String((c.voice_meta[k] as Dictionary).get("id", "")) == id:
			c.voice_pick.select(k)
			c.voice_pick.item_selected.emit(k)


## The voice slot [param i] keeps.
func _voice(i: int) -> String:
	return String(_ed._cast.slot_cfg(i)["voice"])


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

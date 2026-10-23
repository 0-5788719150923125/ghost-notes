extends Node

## synth_bank_check - that the Synthesis voice sings with the bank of the throw that made it, and
## with no other.
##
##   tests/run_boot_probe.sh tests/reading/synth_bank_check.gd 120
##
## A throw from a seed COMPOSES: its traits are the parent's plus a few members' pulls, and the
## sustain bank - where in a reading the voice holds its notes - carries one cycle per member that
## pulled ([method VoiceParty.sustain_bank]). The editor kept those contributors for the bank and
## nothing cleared them, so a voice no throw composed sang with the last throw's: a wild draw; a
## catch landed (its belt entry and the note keep no contributors, so it sang one way as it was
## caught and another when it came back); the still water after a release; a voice a document
## applies. The stream and an export plan from `_current_spec()` - the plan is made at setup and
## restart, a retune swaps timbre only - so that is what is read here:
##
##   A WILD THROW, A LANDED CATCH, A RELEASE AND AN APPLIED DOCUMENT each sing their own cycle alone.
##
## THE CONTROLS: before each, a throw from a seed is made to compose (its bank carries more than
## its own cycle), or a bank found cleared proves nothing; and a document block with NO lineage
## leaves the water as it was - the bank it had stays.
##
## The editor is built by hand and never added to the tree (its `_ready` reads the author's save),
## with `_autopilot` set: `_apply` and `_persist` return at once, so no voice is synthesized and
## nothing is written.

var _fails: Array = []
var _ed: SynthEditor


func _ready() -> void:
	_ed = SynthEditor.new()
	_ed._autopilot = true
	_ed._build_panel()
	seed(20261022)
	var belt: Array = []
	for i in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4000 + i
		belt.append({"lineage": [4000 + i], "traits": Voice.Spec.sample(rng).traits, "genome": {},
			"scene": "", "m": {"s": 30.0 * i, "acts": 1 + i % 2, "restores": 0, "evolves": 0,
				"catches": 0, "r": 0.4 + 0.3 * i, "d": 0.35, "t": 0}})
	_ed._belt = belt
	_ed._profile = "anchor"
	_ed._rebuild_belt()
	_check_wild()
	_check_landed()
	_check_released()
	_check_applied()
	print("")
	if _fails.is_empty():
		print("synth_bank_check: ALL OK - a voice sings with its own throw's bank.")
	else:
		print("synth_bank_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	_ed.free()
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


## How many cycles the voice the stream would plan sings with: 1 is its own alone.
func _bank() -> int:
	return (_ed._current_spec().sustain_bank as Array).size()


## THE CONTROL before each check: throw from the Collection's seeds until one composes.
func _compose(before: String) -> bool:
	for k in 60:
		_ed._throw_from(k % _ed._belt.size())
		if _bank() > 1:
			return true
	_ok(false, "control: no throw composed before %s, so what follows proves nothing" % before)
	return false


func _check_wild() -> void:
	if not _compose("a wild throw"):
		return
	_ed._profile = "reel"
	_ed._drift_dist = 30.0               # far out every throw is wild
	_ed._throw()
	_ok(_ed._lineage.size() == 1 and _bank() == 1,
		"a wild throw (lineage %s) sings its own cycle alone (bank %d)" % [str(_ed._lineage), _bank()])
	_ed._profile = "anchor"
	_ed._drift_dist = 0.0


func _check_landed() -> void:
	if not _compose("a catch"):
		return
	_ed._begin_hook(0.2)
	var n := 0
	while not _ed._hook.is_empty() and n < 4000:
		_ed._advance_reel(0.5)
		n += 1
	if _ed._pending.is_empty():
		_ok(false, "the reel never froze (%d steps), so no catch was landed" % n)
		return
	_ed._accept_catch()
	_ok(_ed._landed and _bank() == 1, "a landed catch sings as itself (bank %d)" % _bank())


func _check_released() -> void:
	if not _compose("a release"):
		return
	_ed._release_line()
	_ok(not _ed._cast and _bank() == 1, "the still water after a release sings no throw's bank (bank %d)" % _bank())


func _check_applied() -> void:
	if not _compose("a document"):
		return
	var had := _bank()
	_ed._doc_apply({"synthesis": {}})
	_ok(_bank() == had, "control: a block with no lineage leaves the water as it was (bank %d, had %d)" % [_bank(), had])
	_ed._doc_apply({"synthesis": {"lineage": [5, 6], "traits": {"pitch": 0.5, "song": 0.4}}})
	_ok(_ed._lineage == [5, 6] and _bank() == 1, "a document's voice sings as itself (bank %d)" % _bank())

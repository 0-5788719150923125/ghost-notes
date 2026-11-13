extends Node

## fishing_bank_check - that the Lab's fishing game sings each voice with the bank of the throw that made it, and
## hands the tab the voice it last cast or held, and nothing else.
##
##   tests/run_boot_probe.sh tests/reading/fishing_bank_check.gd 120
##
## A throw from a seed composes: its traits are the parent's plus a few seeds' pulls, and the sustain bank carries
## one cycle per seed that pulled ([method VoiceParty.sustain_bank]). The line plans from `_current_spec()`, so that
## is what is read: a wild throw, a landed catch and a let-go line each sing their own cycle alone; a voice taken from
## the tab sings with the bank it came with, so what the Lab plays is what the reading reads.
##
## The tab ([method ReadingCast.pick_formant]) is handed the voice of every cast and every Hold; a Fold and a line let
## go leave it as it was.
##
## Controls: before each bank check a throw from a seed is made to compose (its bank carries more than its own cycle),
## or a cleared bank proves nothing; a voice taken from the tab with no bank sings its own cycle, so a bank kept is the
## tab's and not one left over.
##
## The game is built by hand, never added to the tree, `quiet` (no sound, the author's Collection never read or
## written), with a cast of the gate's own that only records what it is handed.

var _fails: Array = []
var _game: VoiceFishing
var _tab: Tab


## A cast that keeps what the game hands the tab and nothing more.
class Tab:
	extends ReadingCast
	var handed: Array = []

	func pick_formant(voice: Dictionary) -> void:
		handed.append(voice.duplicate(true))


func _ready() -> void:
	_tab = Tab.new(null)
	_game = VoiceFishing.new(_tab)
	_game.quiet = true
	_game._loaded = true
	seed(20261112)
	var belt: Array = []
	for i in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4000 + i
		belt.append({"lineage": [4000 + i], "traits": Voice.Spec.sample(rng).traits, "genome": {},
			"m": {"s": 30.0 * i, "acts": 1 + i % 2, "restores": 0, "evolves": 0,
				"catches": 0, "r": 0.4 + 0.3 * i, "d": 0.35, "t": 0}})
	_game._belt = belt
	_game._profile = "anchor"
	_game._rebuild_belt()
	_check_wild()
	_check_landed()
	_check_released()
	_check_opened()
	_check_handed()
	print("")
	if _fails.is_empty():
		print("fishing_bank_check: ALL OK - a voice sings with its own throw's bank, and the tab gets what was cast or held.")
	else:
		print("fishing_bank_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
	_game.free()
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails.append(msg)


## How many cycles the voice the line would plan sings with: 1 is its own alone.
func _bank() -> int:
	return (_game._current_spec().sustain_bank as Array).size()


## The control before each check: throw from the Collection's seeds until one composes.
func _compose(before: String) -> bool:
	for k in 60:
		_game._throw_from(k % _game._belt.size())
		if _bank() > 1:
			return true
	_ok(false, "control: no throw composed before %s, so what follows proves nothing" % before)
	return false


## Reel the hook in to its freeze.
func _reel() -> bool:
	_game._begin_hook(0.2)
	var n := 0
	while not _game._hook.is_empty() and n < 4000:
		_game._advance_reel(0.5)
		n += 1
	if _game._pending.is_empty():
		_ok(false, "the reel never froze (%d steps), so no catch was landed" % n)
		return false
	return true


func _check_wild() -> void:
	if not _compose("a wild throw"):
		return
	_game._profile = "reel"
	_game._drift_dist = 30.0               # far out every throw is wild
	_game._throw()
	_ok(_game._lineage.size() == 1 and _bank() == 1,
		"a wild throw (lineage %s) sings its own cycle alone (bank %d)" % [str(_game._lineage), _bank()])
	_game._profile = "anchor"
	_game._drift_dist = 0.0


func _check_landed() -> void:
	if not _compose("a catch") or not _reel():
		return
	_game._accept_catch()
	_ok(_game._landed and _bank() == 1, "a landed catch sings as itself (bank %d)" % _bank())


func _check_released() -> void:
	if not _compose("a release"):
		return
	_game.release_line()
	_ok(not _game._cast and _bank() == 1, "the still water after the line is let go sings no throw's bank (bank %d)" % _bank())


func _check_opened() -> void:
	if not _compose("a voice taken from the tab"):
		return
	var had := _bank()
	var kept := FormantVoice.kept(_game._lineage, _game._traits, _game._working_genome, _game._working_loc,
		_game._sustain_bank())
	_game.open({})
	_ok(not _game._cast and _bank() == 1, "the Lab opened on a tab with no voice: still water, its own cycle (bank %d)" % _bank())
	_game.open(kept)
	_ok(_game._lineage == kept["lineage"] and _bank() == had,
		"the Lab opened on the tab's voice sings with the bank it came with (bank %d, kept %d)" % [_bank(), had])
	var bare := kept.duplicate(true)
	bare.erase("bank")
	_game.open(bare)
	_ok(_bank() == 1, "control: a tab's voice kept with no bank sings its own cycle (bank %d)" % _bank())


func _check_handed() -> void:
	_tab.handed.clear()
	_game._throw_from(0)
	var cast_voice := FormantVoice.kept(_game._lineage, _game._traits, _game._working_genome, _game._working_loc,
		_game._sustain_bank())
	_ok(_tab.handed.size() == 1 and _tab.handed[0] == cast_voice, "a cast hands the tab its voice (%d handed)" % _tab.handed.size())
	_game._throw()
	_ok(_tab.handed.size() == 2 and (_tab.handed[1]["lineage"] as Array) == _game._lineage,
		"a throw hands the tab its voice (%d handed)" % _tab.handed.size())
	if not _reel():
		return
	_game._release_catch()
	_ok(_tab.handed.size() == 2, "a Fold hands the tab nothing (%d handed)" % _tab.handed.size())
	if not _reel():
		return
	_game._accept_catch()
	_ok(_tab.handed.size() == 3 and (_tab.handed[2]["lineage"] as Array) == _game._lineage
		and _tab.handed[2]["traits"] == _game._traits,
		"a Hold hands the tab the caught voice (%d handed)" % _tab.handed.size())
	_game.release_line()
	_ok(_tab.handed.size() == 3, "letting the line go hands the tab nothing (%d handed)" % _tab.handed.size())

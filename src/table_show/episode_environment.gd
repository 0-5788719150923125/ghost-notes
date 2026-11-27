extends EnvironmentSection
class_name EpisodeEnvironment

## EpisodeEnvironment - a table show's environment on the Environment card ([EnvironmentCard]): what the open episode's table is heard
## with and what lasts in its air ([TableSurroundings]), each an entry as any note's element is - Test, Keep (into the library,
## [EnvironmentLibrary]), its properties as the table has them, Used and its ×. A change is a hand's version of the episode's table (kept, passed by Generate,
## [method EpisodeCard._hand_write]), heard and seen as soon as it is made; "+ Add to the environment" puts what is heard or drifts in the
## air from the Dex on that table. Its light stays the set dresser's, and a burst or what the wind carries the set dresser's staging.
##
## The episode card hands it to the panel ([member ReadingPanel.environment]) while its episode is shown at its table ([method owns]);
## at the desk, where the table is a pad and a pen, the card lists the note's own environment.
##
## A sound's Refine… and its versions are kept in the episode's folder ([method home]); it is heard as the table hears it, and a
## version made or picked is a hand's version of the table, as any change here is.

const EPISODE_GROUPS := [
	{"key": "here", "label": "This episode's", "tip": "What this episode's table is heard with and what lasts in its air. Change one and the table is yours: kept as your version, passed by Generate."},
	{"key": "aside", "label": "Set aside", "tip": "Taken off this episode's environment and kept here: tick one to use it again."},
]

var episode: EpisodeCard
## What a Test plays, and the element it plays (its number, -1 none).
var tester := SoundTest.new()
var _test_seed := -1
var _key := ""                    # the episode and its table's digest, as last read
var _table := {}
var _els: Array = []
var _palette: Array = []


func _init(c: EpisodeCard) -> void:
	super(null)
	episode = c
	c.add_child(tester)


## Whether the open episode's environment is the card's: it is shown at its table (one not set yet lists nothing - the note's own
## would never be heard there).
func owns() -> bool:
	var ep := episode._episode
	return ep != null and not ep.own_set()


## Whether the open episode's table is set, to be added to.
func _table_is_set() -> bool:
	return owns() and episode._episode.has("table")


func groups() -> Array:
	return EPISODE_GROUPS


## The Dex's shelves for a table: what is heard and what drifts, built in and kept - its light is the set dresser's.
func shelves() -> Array:
	return super().filter(func(s: Dictionary) -> bool: return String(s["key"]) != "light")


func offers() -> Array:
	var lit := {}
	for e in _kept_entries():
		var kind := String(((e as Dictionary)["element"] as Dictionary).get("kind", ""))
		if String((Surroundings.KINDS.get(kind, {}) as Dictionary).get("group", "")) == "light":
			lit["kept:" + String((e as Dictionary)["name"])] = true
	return super().filter(func(o: Dictionary) -> bool: return String(o["shelf"]) != "light" and not lit.has(String(o["key"])))


# --- what stands ---------------------------------------------------------------------------------------------------------

func rows() -> Array:
	_read()
	var out: Array = []
	var kept := _kept_entries()
	var plain := Surroundings.sanitize({})
	for i in _els.size():
		var el: Dictionary = _els[i]
		var kind := String(el["kind"])
		var as_kept := EnvironmentLibrary.kept_as(el, kept)
		var heard := String((Surroundings.KINDS.get(kind, {}) as Dictionary).get("group", "")) == "sound"
		var verbs: Array = []
		if heard:
			verbs.append({"key": "test", "label": "Test ■" if testing(i) else "Test",
				"tip": "Hear it alone, as the table hears it under the voice; it follows what you change. Press again to stop."})
		verbs.append({"key": "keep", "label": "Kept" if not as_kept.is_empty() else "Keep", "off": not as_kept.is_empty(),
			"tip": ("In your library as %s." % as_kept) if not as_kept.is_empty() else "Keep it in your library, to use on any note or table."})
		if heard:
			verbs.append_array(refine_verbs(_els, i))
		out.append({"key": "el:%d" % i, "name": name_of(el), "line": refining_line(_els, i, Surroundings.line_of(el)), "group": "aside" if el.get("off") == true else "here",
			"tip": Registry.blurb(Surroundings.KINDS, kind), "picture": _picture(el, plain), "on": el.get("off") != true,
			"on_tip": "Ticked, this episode's table has it; unticked, it is set aside and kept here.",
			"remove_tip": "Take it off this episode's table for good: the table is then yours.",
			"verbs": verbs, "fields": Surroundings.shown_of(el), "values": Surroundings.set_of(el)})
	return out


func set_on(key: String, on: bool) -> String:
	var i := _at(key)
	if i < 0:
		return "nothing here sets that aside"
	var els := _els.duplicate(true)
	var el: Dictionary = els[i]
	if on:
		el.erase("off")
		# one of a kind a scene has once: the one in use gives way to it
		if bool((Surroundings.KINDS[String(el["kind"])] as Dictionary)["one"]):
			for j in els.size():
				if j != i and String((els[j] as Dictionary)["kind"]) == String(el["kind"]) and (els[j] as Dictionary).get("off") != true:
					(els[j] as Dictionary)["off"] = true
	else:
		el["off"] = true
	return _write(els)


func remove(key: String) -> String:
	var i := _at(key)
	if i < 0:
		return "nothing here takes that away"
	var els := _els.duplicate(true)
	if (els[i] as Dictionary).get("seed") == _test_seed:
		_stop_test()
	els.remove_at(i)
	return _write(els)


func set_field(key: String, field: String, value: Variant) -> String:
	var i := _at(key)
	if i < 0:
		return "nothing here is tuned"
	if field in Surroundings.OWN_KEYS:
		return "%s is no property of it" % field
	var el: Dictionary = (_els[i] as Dictionary).duplicate(true)
	if value == null:
		el.erase(field)
	else:
		el[field] = value
	var made := Surroundings.element(el)
	if made.is_empty():
		return "that would make it nothing"
	var els := _els.duplicate(true)
	els[i] = made
	return _write(els)


func act(key: String, verb: String) -> String:
	if verb == "forget" and key.begins_with("kept:"):
		return super(key, verb)
	var i := _at(key)
	if i < 0:
		return "nothing here does that"
	var el: Dictionary = _els[i]
	if verb == "refine" or verb.begins_with("version:"):
		return refine_act(i, verb)
	match verb:
		"test":
			return test(i)
		"keep":
			_kept_t = -INF
			return EnvironmentLibrary.keep(el, String(el.get("name", "%s %d" % [name_of(el), int(el["seed"])])))
	return "nothing here does that"


func adds() -> Dictionary:
	if not _table_is_set():
		return {}
	return {"label": "+ Add to the environment", "verb": "Use",
		"tip": "Put it on this episode's table - the table is then yours. A sound it already has gives way to it."}


func add(key: String) -> String:
	var el := {}
	if key.begins_with("kept:"):
		el = (EnvironmentLibrary.read(key.substr(5)).get("element", {}) as Dictionary).duplicate(true)
	else:
		el = Surroundings.element((Surroundings.offers().get(key, {}) as Dictionary).get("element"))
		if not el.is_empty():
			el["seed"] = Roll.fresh()
	if el.is_empty():
		return "there is no such thing to add"
	if String((Surroundings.KINDS[String(el["kind"])] as Dictionary)["group"]) == "light":
		return "a table's light is its set dresser's"
	if not _table_is_set():
		return "this episode has no table yet"
	_read()
	var els := _els.duplicate(true)
	if bool((Surroundings.KINDS[String(el["kind"])] as Dictionary)["one"]):
		for j in els.size():
			if String((els[j] as Dictionary)["kind"]) == String(el["kind"]) and (els[j] as Dictionary).get("off") != true:
				(els[j] as Dictionary)["off"] = true
	els.append(el)
	return _write(els)


# --- refining a sound: where its table is ------------------------------------------------------------------------------------

func home() -> String:
	return episode._episode.dir if episode != null and is_instance_valid(episode) and episode._episode != null else ""


func elements() -> Array:
	if episode == null or not is_instance_valid(episode):
		return []
	_read()
	return _els


func heard_of(el: Dictionary) -> Dictionary:
	if episode == null or not is_instance_valid(episode) or episode._episode == null:
		return {"sound": {}}
	_read()
	var made := TableSurroundings.heard_alone(_table, el, episode._episode.seed)
	made["seed"] = episode._episode.seed
	return made


func put_at(i: int, el: Dictionary) -> String:
	if episode == null or not is_instance_valid(episode):
		return "the episode was left"
	_read()
	if i < 0 or i >= _els.size():
		return "it is no longer on this episode's table"
	var made := Surroundings.element(el)
	if made.is_empty() or String(made["kind"]) != String((_els[i] as Dictionary)["kind"]):
		return "that would make it something else"
	var els := _els.duplicate(true)
	els[i] = made
	return _write(els)


func window_host() -> Node:
	return episode if episode != null and is_instance_valid(episode) and episode.is_inside_tree() else null


# --- Test ------------------------------------------------------------------------------------------------------------------

## Whether element [param i] is heard alone now ([method test]).
func testing(i: int) -> bool:
	return tester.playing() and i >= 0 and i < _els.size() and int((_els[i] as Dictionary)["seed"]) == _test_seed


## Element [param i] heard alone, as the table hears it (its wind and ride planned as the table's are), at the level it has under the voice,
## following what is changed on it; pressed again, stopped. "" done, else why not.
func test(i: int) -> String:
	if testing(i):
		_stop_test()
		return ""
	var el: Dictionary = _els[i]
	if String((Surroundings.KINDS.get(String(el["kind"]), {}) as Dictionary).get("group", "")) != "sound":
		return "it makes no sound to hear"
	_test_seed = int(el["seed"])
	if not _keep_testing():
		return "it makes no sound to hear"
	return ""


func _stop_test() -> void:
	_test_seed = -1
	tester.stop()


## The Test made again from its element as it is now; false, and stopped, where it is gone or makes no sound.
func _keep_testing() -> bool:
	if _test_seed < 0 or episode._episode == null:
		return false
	var at := -1
	for i in _els.size():
		if int((_els[i] as Dictionary)["seed"]) == _test_seed:
			at = i
	if at < 0:
		_stop_test()
		return false
	var seed := episode._episode.seed
	var made := TableSurroundings.heard_alone(_table, _els[at], seed)
	if (made["sound"] as Dictionary).is_empty():
		_stop_test()
		return false
	var key := JSON.stringify([made["sound"], seed])
	tester.play(key, func(rate: int, t0: float) -> SoundBed:
		return Soundscape.new(made["sound"], made["wind"], seed, rate, t0, made["ride"]), Surroundings.BED_LEVEL)
	return true


# --- reading and writing the table -----------------------------------------------------------------------------------------

## The open episode's table and its elements, read again only when its file changed.
func _read() -> void:
	var ep := episode._episode
	if ep == null or not ep.has("table"):
		_key = ""
		_table = {}
		_els = []
		return
	var key := "%s|%s" % [ep.dir, ep.digest("table")]
	if key == _key:
		return
	_key = key
	var raw: Variant = ep.read_json("table")
	_table = raw if raw is Dictionary else {}
	var plan: Variant = ep.read_json("plan")
	var look: Variant = (plan as Dictionary).get("look", {}) if plan is Dictionary else {}
	_palette = CardTable.sanitize_look(look if look is Dictionary else {}).get("palette", [])
	_els = TableSurroundings.elements_of(_table, ep.seed, _palette)
	_keep_testing()


## The element row [param key] stands for, by its place in the list; -1 for none.
func _at(key: String) -> int:
	_read()
	if not key.begins_with("el:") or not key.substr(3).is_valid_int():
		return -1
	var i := int(key.substr(3))
	return i if i >= 0 and i < _els.size() else -1


## The episode's table written with [param els] as its environment, as a hand's version, and what is made from it told. "" done,
## else why not.
func _write(els: Array) -> String:
	var ep := episode._episode
	if ep == null or not ep.has("table"):
		return "this episode has no table yet"
	var err := episode._hand_write("table", func() -> String:
		var raw: Variant = ep.read_json("table")
		return ep.write_json("table", TableSurroundings.with_elements(raw if raw is Dictionary else {}, els, ep.seed, _palette)))
	episode._after_hand("table", err)
	_read()
	# ...and the table playing it told at once: what drifts in its air redrawn as the dial moves, never waiting on the file's time
	var medium: Object = Director._medium
	if err.is_empty() and medium != null and medium.has_method("table_changed"):
		medium.call("table_changed")
	return err

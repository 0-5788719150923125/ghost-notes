extends SceneTree

## Gate for the letter-to-sound front end, graded against `data/reference.yml`.
##
## Two halves, because they fail differently:
##   PHONES  - four groups (dictionary hits, suffix/clitic derivations, the
##             out-of-dictionary fallback, and our deliberate overrides). Since
##             CMUdict answers 126k words, the interesting groups are the ones
##             it does NOT answer; a hand list of dictionary words would only
##             prove the file loaded.
##   STRESS  - the index of the primary-stressed vowel. Nothing else in the
##             suite tests this, and it is now what the whole rhythm hangs off:
##             a wrong mark is a word leaned on in the wrong place, which is
##             audible in a way a wrong schwa is not. -1 asserts an unstressed
##             function word.
##   GUESSED - which words of a parsed sentence the voice host is told eSpeak would
##             be guessing at (`Phonemes.guessed` -> `rare`, hosts/voice/lexicon.py):
##             the trig list the user heard slurred, every word with its comma or
##             stop after it (2026-10-17: the marks hid all three); the controls, a
##             word normalization wrote and a word the dictionary has, are not.
##
## Run: godot --headless --path . --script tests/voice/g2p_check.gd

const Phonemes_ := preload("res://src/voice/phonemes.gd")

const REF_PATH := "res://data/reference.yml"
const GROUPS := ["words", "derived", "fallback"]


func _init() -> void:
	var f := FileAccess.open(REF_PATH, FileAccess.READ)
	if f == null:
		print("g2p_check: cannot open ", REF_PATH)
		quit(1)
		return
	var r := MiniYaml.parse(f.get_as_text())
	f.close()
	if not r.ok:
		print("g2p_check: reference parse error - ", r.error)
		quit(1)
		return
	var ref: Dictionary = r.data
	var failures := 0
	for g in GROUPS:
		var group: Dictionary = ref.get(g, {})
		var bad := 0
		for word in group:
			var want: Array = _split(String(group[word]))
			var got: Array = Phonemes_.word_to_phones(String(word))
			if want != got:
				print("  %-9s %-14s want: %-24s got: %s" % [
					g, word, " ".join(PackedStringArray(want)), " ".join(PackedStringArray(got))])
				bad += 1
		print("g2p_check: %-9s %d/%d" % [g, group.size() - bad, group.size()])
		failures += bad
	var st: Dictionary = ref.get("stress", {})
	var sbad := 0
	for word in st:
		var want := int(st[word])
		var got := _primary(String(word))
		if want != got:
			print("  %-9s %-14s want primary-stressed vowel %d, got %d" % ["stress", word, want, got])
			sbad += 1
	print("g2p_check: %-9s %d/%d" % ["stress", st.size() - sbad, st.size()])
	failures += sbad
	failures += _guessed()
	if failures > 0:
		print("g2p_check: %d FAILURE(S)" % failures)
		quit(1)
		return
	print("g2p_check: ALL OK")
	quit()


## The GUESSED half: failures, each printed.
func _guessed() -> int:
	var line := "It uses six functions: sine, cosine, tangent, cotangent, secant and cosecant. " \
		+ "In 2009, the letter [x] was \"cosine\"."
	var got := PackedStringArray()
	var said := PackedStringArray()
	for sentence in Phonemes_.parse(line):
		for w in sentence:
			said.append(String(w.text))
			if Phonemes_.guessed(w):
				got.append(String(w.text))
	var want := PackedStringArray(["cosine", "cotangent", "secant", "cosecant", "cosine"])
	var bad := 0
	if got != want:
		print("  guessed   want: %s  got: %s  (of %s)" % [", ".join(want), ", ".join(got), " ".join(said)])
		bad += 1
	# the controls: the numeral's words and the letter's name are normalization's, "sine" is CMUdict's
	for w in ["two", "thousand", "nine", "ex", "sine"]:
		if got.has(w):
			print("  guessed   %s is not a guess, and was marked one" % w)
			bad += 1
	print("g2p_check: %-9s %s" % ["guessed", "ok" if bad == 0 else "FAILED"])
	return bad


## Index of the primary-stressed vowel, counting vowels only. -1 if none.
func _primary(word: String) -> int:
	var got := Phonemes_.lookup(word)
	var vi := 0
	for i in (got.phones as Array).size():
		if Phonemes_.TABLE.get(got.phones[i], {}).get("type", "") != "vowel":
			continue
		if int(got.stress[i]) == 1:
			return vi
		vi += 1
	return -1


func _split(spec: String) -> Array:
	var out: Array = []
	for p in spec.split(" ", false):
		out.append(String(p).to_upper())
	return out

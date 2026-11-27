extends RefCounted
class_name DeliveryHearing

## DeliveryHearing - words said with a delivery and without it, heard as numbers (next/delivery.md, "Tuning a delivery"): both
## planned as the reading plans them ([method ReadingPlan.make], with the note's deliveries as they stand now), said in one voice
## as its takes are ([method ReadingPanel.hear_take]: a take said before in this voice as it is now comes back at once), and measured
## by the voice host ([method ReadingPanel.hear_measured], hosts/voice/measure.py): how long, how high, how wide, how loud, and
## pitch and level across it in tenths. A delivery's Lab shows the numbers; its designer is told them ([DeliveryTools]). The takes
## are the same ones its Test plays, so a hearing then a Test asks the host once.

## The longest a hearing waits on the host (seconds).
const TIMEOUT := 240.0

## The words a delivery is heard on where the script says it nowhere ([method words_for]): a line suited to each family of the bank's
## ([constant DeliveryBank.FAMILIES]), a line for each act with the word it falls on in brackets (`%s` its name), and lines that suit
## anything.
const FAMILY_WORDS := {
	"axis": "The rain had not stopped. Since morning it had kept on, and the lamps along the river were already lit by four o'clock.",
	"ramp": "First one bell rang, then another, then every bell in the town, and the whole square filled with people running for the harbor.",
	"lively": "We did it! The letter came this morning, and they said yes to everything, the house, the garden, all of it.",
	"heated": "I told you three times not to touch it. Three times. And you went ahead and did it anyway.",
	"afraid": "There's someone downstairs. I heard the door. Please, just stay quiet and don't turn on the light.",
	"low": "She kept his coat by the door for a year. Nobody asked her to move it, and she never did.",
	"calm": "It's all right. You're home now, the fire's lit, and there's nothing left to do tonight.",
	"stance": "Oh, of course. Because that worked so well the last time you tried it.",
	"effort": "Can you hear me? I'm over here, by the gate, and the water is still rising.",
	"style": "And here they come around the final bend, three horses side by side, and it is going to be close!",
	"state": "I ran the whole way here. Give me a moment. I can barely breathe.",
}
const ACT_WORDS := {
	"rise": "And you just left it [there]{%s}.",
	"low rise": "Would you mind if I sat [here]{%s}.",
	"fall": "That is the end of it. We are [done]{%s}.",
	"rise-fall": "You painted all of this [yourself]{%s}.",
	"fall-rise": "The food was good, [mostly]{%s}.",
	"contrast": "I asked for the [red]{%s} one, not the blue one.",
	"scoop": "You finished the whole book in one [night]{%s}.",
	"reminder": "We talked about this, [remember]{%s}.",
	"held": "We packed bread, cheese, [apples]{%s} and a flask of tea.",
	"chant": "[Daniel]{%s}, dinner's ready!",
	"drawn": "A bird, a mouse, a frog, [and]{%s} five arrows.",
	"clipped": "Fine. [Whatever]{%s}. Do what you like.",
	"cut off": "I was just about to tell you about the [letter]{%s} when the door opened.",
	"spaced": "That is [absolutely not]{%s} what I said.",
	"none": "Are you coming [tonight]{%s}?",
	"hit": "I said the [red]{%s} one, not the blue one.",
	"hit hard": "I [never]{%s} said that.",
}
const ANY_WORDS := [
	"We waited by the door for an hour, and nobody came. Then, all at once, the lights went out.",
	"The train was late again, so we walked along the canal and talked about nothing much.",
	"He opened the letter, read it twice, and put it back in its envelope without a word.",
]

var _round := 0
var _draft := {}


## The words delivery [param name] is offered to be heard on, the best first, as its Lab's field shows them: an act's own line
## (its word bracketed, `[word]{name}`), a bank row's family's line, then lines that suit anything (plain words: said with the
## delivery round all of them).
static func words_for(name: String) -> Array:
	var out: Array = []
	if ACT_WORDS.has(name):
		out.append(String(ACT_WORDS[name]) % name)
	elif DeliveryBank.BANK.has(name) and FAMILY_WORDS.has(String(DeliveryBank.BANK[name]["family"])):
		out.append(String(FAMILY_WORDS[String(DeliveryBank.BANK[name]["family"])]))
	for w in ANY_WORDS:
		out.append(String(w))
	if not ACT_WORDS.has(name):
		for f in FAMILY_WORDS:
			if not out.has(FAMILY_WORDS[f]):
				out.append(String(FAMILY_WORDS[f]))
	return out


## The words [param words] said with delivery [param name]: as they are where they carry marks of their own, else a closed stretch
## round all of them ([method words_for]'s first where [param words] is empty).
static func passage_of(name: String, words: String) -> String:
	var w := words.strip_edges()
	if w.is_empty():
		w = String(words_for(name)[0])
	if w.contains("]{") or w.contains("<!--"):
		return w
	if DeliveryBank.ACTS.has(name) and not w.contains(" "):
		return "[%s]{%s}" % [w, name]
	return "<!-- delivery: %s -->%s<!-- /delivery -->" % [name, w]


## [param text] with every delivery taken off: its plain twin.
static func plain_of(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("<!--\\s*/?\\s*(delivery|inflect)\\b[^>]*-->")
	return rx.sub(Manuscript.plain(text), "", true)


## [param panel] is the note's [ReadingPanel], named by what it answers alone so this compiles without it (a designer's prompt is
## rendered where no panel is). [param text] said in voice [param voice] of its cast, and its plain twin, heard and measured: `{plain, said, text,
## wavs, plain_wavs}` (each measure `{seconds, voiced, pitch, ...}`, `text` the two compared in words) or `{error}`. [param draft]
## (`{name: spec}`) is heard in place of what the note keeps of those deliveries: a designer's draft, before it is a version. Awaited.
func hear(panel: Object, voice: String, text: String, draft := {}) -> Dictionary:
	if panel == null or not is_instance_valid(panel):
		return {"error": "the note's reading is closed"}
	_round += 1
	_draft = draft
	var said := await _said(panel, voice, text, "d%d" % _round)
	if said.has("error"):
		return said
	var plain := await _said(panel, voice, plain_of(text), "p%d" % _round)
	if plain.has("error"):
		return plain
	var m_said := await _measured(panel, said["wavs"])
	var m_plain := await _measured(panel, plain["wavs"])
	if m_said.has("error") or m_plain.has("error"):
		return {"error": String(m_said.get("error", m_plain.get("error", "")))}
	return {"said": m_said, "plain": m_plain, "text": text_of(m_plain, m_said), "wavs": said["wavs"], "plain_wavs": plain["wavs"]}


## [param text]'s takes in [param voice]: `{wavs}` in order, or `{error}`. Awaited.
func _said(panel: Object, voice: String, text: String, tag: String) -> Dictionary:
	var ask: Dictionary = panel._plan_ask(text)
	if not _draft.is_empty():
		var tuning: Dictionary = (ask.get("deliveries", {}) as Dictionary).duplicate(true)
		var tuned: Dictionary = tuning.get("tuned", {})
		for name in _draft:
			tuned[name] = _draft[name]
			(tuning.get("off", []) as Array).erase(name)
		tuning["tuned"] = tuned
		ask["deliveries"] = tuning
	var plan := ReadingPlan.make(text, "", ask)
	var chunks: Array = plan["chunks"]
	if chunks.is_empty():
		return {"error": "there are no words to say"}
	for c in chunks:
		(c as Dictionary)["speaker"] = voice
	panel._plan_near(chunks, 0, voice)
	var s: Dictionary = panel._cast.cfg_of(voice)
	var box := {"left": chunks.size(), "wavs": [], "error": ""}
	(box["wavs"] as Array).resize(chunks.size())
	for i in chunks.size():
		var to := String(panel.get("take_dir")) + "/delivery_%s_%d.wav" % [tag, i]
		panel.hear_take(s, chunks[i], to, func(result: Dictionary) -> void:
			if result.has("error"):
				box["error"] = String(result["error"])
			else:
				(box["wavs"] as Array)[i] = String(result.get("wav", ""))
			box["left"] = int(box["left"]) - 1)
	var waited := await _wait(func() -> bool: return int(box["left"]) <= 0)
	if not waited:
		return {"error": "the voice host did not answer in time"}
	if not String(box["error"]).is_empty():
		return {"error": String(box["error"])}
	return {"wavs": box["wavs"]}


## The takes [param wavs] measured, end to end: the host's `all`, or `{error}`. Awaited.
func _measured(panel: Object, wavs: Array) -> Dictionary:
	var box := {"got": null}
	panel.hear_measured(wavs, func(result: Dictionary) -> void: box["got"] = result)
	if not await _wait(func() -> bool: return box["got"] != null):
		return {"error": "the voice host did not measure in time"}
	var got: Dictionary = box["got"]
	if got.has("error"):
		return {"error": String(got["error"])}
	return ((got.get("measured", {}) as Dictionary).get("all", {}) as Dictionary)


## Frames waited until [param done] says so, or [constant TIMEOUT]: whether it did.
static func _wait(done: Callable) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var until := Time.get_ticks_msec() + int(TIMEOUT * 1000.0)
	while not done.call():
		if tree == null or Time.get_ticks_msec() > until:
			return false
		await tree.process_frame
	return true


## Plain [param plain] and said [param said] compared in words: each in seconds, pitch and level, the change between them, and pitch
## and level across each in tenths.
static func text_of(plain: Dictionary, said: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Plain: %s" % _line(plain))
	var change := PackedStringArray()
	var ps := float(plain.get("seconds", 0.0))
	var ss := float(said.get("seconds", 0.0))
	if ps > 0.0:
		change.append("%+d%% as long" % roundi((ss / ps - 1.0) * 100.0))
	if plain.get("pitch") != null and said.get("pitch") != null:
		change.append("pitch %+.1f st" % (float(said["pitch"]) - float(plain["pitch"])))
		change.append("top %+.1f st" % (float(said["pitch_high"]) - float(plain["pitch_high"])))
	if plain.get("spread") != null and said.get("spread") != null and float(plain["spread"]) > 0.0:
		change.append("spread x%.2f" % (float(said["spread"]) / float(plain["spread"])))
	if plain.get("level") != null and said.get("level") != null:
		change.append("level %+.1f dB" % (float(said["level"]) - float(plain["level"])))
	if float(plain.get("voiced", 0.0)) > 0.0:
		change.append("voiced x%.2f" % (float(said.get("voiced", 0.0)) / float(plain["voiced"])))
	lines.append("As said: %s" % _line(said))
	lines.append("Against plain: %s" % ", ".join(change))
	lines.append("Pitch across it (st, tenths), plain: %s" % _tenths(plain.get("pitch_tenths", [])))
	lines.append("Pitch across it (st, tenths), as said: %s" % _tenths(said.get("pitch_tenths", [])))
	lines.append("Level across it (dB, tenths), plain: %s" % _tenths(plain.get("level_tenths", [])))
	lines.append("Level across it (dB, tenths), as said: %s" % _tenths(said.get("level_tenths", [])))
	return "\n".join(lines)


static func _line(m: Dictionary) -> String:
	var parts := PackedStringArray(["%.2f s" % float(m.get("seconds", 0.0)), "voiced %.2f s" % float(m.get("voiced", 0.0))])
	if m.get("pitch") != null:
		parts.append("pitch %.1f st over 100 Hz (%.1f to %.1f, spread %.1f)" % [float(m["pitch"]), float(m["pitch_low"]),
			float(m["pitch_high"]), float(m["spread"])])
	if m.get("level") != null:
		parts.append("level %.1f dB" % float(m["level"]))
	return ", ".join(parts)


static func _tenths(v: Variant) -> String:
	var parts := PackedStringArray()
	for x in (v if v is Array else []):
		parts.append("-" if x == null else ("%.0f" % float(x)))
	return " ".join(parts)

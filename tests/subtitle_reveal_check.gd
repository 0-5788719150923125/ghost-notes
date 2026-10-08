extends Node

## Gate for HOW A LINE REVEALS ITS WORDS ([constant Subtitles.REVEALS]). Asked 2026-10-07: "allow for other
## forms of subtitle text revealing, and make the options available to the user ... the reveal that uses
## glitchy/chaotic characters ... the true-word reveal would happen just as the speaker is speaking it -
## because we don't want to glitch the actual words they are saying".
##
##   - A WORD SETTLES AS IT IS SAID: every letter of it shows itself from no later than GLITCH_SETTLE after
##     the word begins, however long the word is spoken - two-sided, letters spread over the whole spoken
##     word (the obvious timing) are still noise most of the way through a long one.
##   - ONLY A FEW LETTERS AHEAD (asked 2026-10-07: "glitching just a few short characters ahead", and "predict
##     ahead, then retract, then predict again"): the noise reaches no further than GLITCH_AHEAD letters
##     past the front, grows a letter at a time, and falls back - two-sided, a reach that never fell back
##     or covered the line (the first glitch: every unsaid letter scrambled) fails.
##   - THE NOISE IS A FUNCTION OF SHOW TIME: the same letter at the same moment is the same glyph, it
##     changes many times a second, and the letter at the front is drawn from the simple set.
##   - THE CHOICE IS THE SHOW'S: the Director takes a known key and refuses an unknown one, and the Look
##     card writes it into the note's `look:` block and reads it back.
##   - BOTH DRAW: the overlay draws a line in either reveal without an error.
##
##   tests/run_boot_probe.sh tests/subtitle_reveal_check.gd 60

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _run() -> void:
	_settles()
	_reach()
	_noise()
	_choice()
	await _draws()
	print("subtitle_reveal_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	get_tree().quit(1 if _fails > 0 else 0)


func _settles() -> void:
	for span in [0.12, 0.4, 2.0]:
		var t0 := 10.0
		var t1 := t0 + float(span)
		var n := 9
		var last := -INF
		for ch in n:
			var at := Subtitles.settle_at(t0, t1, ch, n)
			_ok(at >= last, "letters settle out of order")
			last = at
			_ok(at <= t0 + Subtitles.GLITCH_SETTLE, "a letter of a word spoken over %.2f s is noise %.2f s into it" % [span, at - t0])
			_ok(at >= t0 - Subtitles.GLITCH_EARLY - 1e-6, "a letter settles %.2f s before its word" % (t0 - at))
	# control: letters spread across the whole of a long word are noise well into its saying
	var spread := 10.0 + 2.0 * 8.0 / 9.0
	_ok(spread - 10.0 > Subtitles.GLITCH_SETTLE * 3.0, "control: spreading the settle over the word is no later")


func _reach() -> void:
	var last := Subtitles.glitch_reach(4, 0.0)
	var grew := 0
	var fell := 0
	var most := 0
	for st in range(1, 400):
		var r := Subtitles.glitch_reach(4, (float(st) + 0.5) / Subtitles.GLITCH_STEPS)
		_ok(r >= 1 and r <= Subtitles.GLITCH_AHEAD, "the noise reaches %d letters ahead" % r)
		_ok(r <= last + 1, "the reach jumped from %d to %d letters in one step" % [last, r])
		grew += 1 if r > last else 0
		fell += 1 if r < last else 0
		most = maxi(most, r)
		last = r
	_ok(grew > 40 and fell > 20, "the reach does not reach on and fall back (%d steps on, %d back)" % [grew, fell])
	_ok(most == Subtitles.GLITCH_AHEAD, "the reach never gets past %d letters" % most)
	# control: a sentence's unsaid letters, all scrambled at once as the first glitch had them, are far more
	_ok("Pull up a chair, my loves.".length() > Subtitles.GLITCH_AHEAD * 3, "control: a line is no longer than the reach")


func _noise() -> void:
	var seen := {}
	for f in 32:
		var t := 5.0 + float(f) / 32.0
		var g := Subtitles.glitch_glyph(3, 1, t, 2, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX)
		_ok(g == Subtitles.glitch_glyph(3, 1, t, 2, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX), "the same moment draws a different glyph")
		seen[g] = true
	_ok(seen.size() >= 8, "a scrambled letter changes only %d times in a second" % seen.size())
	for f in 20:
		var t := 8.8 + float(f) * 0.01
		_ok(Subtitles.GLITCH_SIMPLE.contains(Subtitles.glitch_glyph(2, f, t, 0, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX)),
			"the letter at the front shows a complex glyph")


func _choice() -> void:
	var was := Director.subtitle_reveal
	Director.set_subtitle_reveal("glitch")
	_ok(Director.subtitle_reveal == "glitch", "the Director did not take the glitch reveal")
	Director.set_subtitle_reveal("sparkle")
	_ok(Director.subtitle_reveal == "karaoke", "an unknown reveal was kept")
	var card := LookCard.new()
	Director.set_subtitle_reveal("glitch")
	_ok(String(card.capture().get("subtitles", "")) == "glitch", "the Look card does not write the reveal into its block")
	card.apply({"subtitles": "karaoke"})
	_ok(Director.subtitle_reveal == "karaoke", "the Look card does not read the reveal back")
	card.free()
	Director.set_subtitle_reveal(was)


func _draws() -> void:
	var was := Director.subtitle_reveal
	var subs: Subtitles = preload("res://src/subtitles.gd").new()
	var words: Array = []
	var t := 0.5
	for w in ["Hello,", "my", "loves.", "Pull", "up", "a", "chair."]:
		words.append({"text": w, "t0": t, "t1": t + 0.3, "sentence": 0 if words.size() < 3 else 1})
		t += 0.4
	subs.words = words
	add_child(subs)
	# the clock in the middle of the second sentence, so the line is up and part of it is still to come
	Spectrum.virtual_clock = 2.0
	Spectrum.current.time = 2.0
	for reveal in ["karaoke", "glitch"]:
		Director.set_subtitle_reveal(reveal)
		for f in 12:
			subs._process(1.0 / 30.0)
			await get_tree().process_frame
		_ok(subs.presence > 0.5 and subs.span_at(subs._now()) >= 0, "the %s line is not up to be drawn" % reveal)
	Spectrum.virtual_clock = -1.0
	subs.queue_free()
	Director.set_subtitle_reveal(was)

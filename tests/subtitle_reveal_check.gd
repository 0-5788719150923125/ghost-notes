extends Node

## Gate for HOW A LINE REVEALS ITS WORDS ([constant Subtitles.REVEALS]). Asked 2026-10-07: "allow for other
## forms of subtitle text revealing, and make the options available to the user ... the reveal that uses
## glitchy/chaotic characters ... the true-word reveal would happen just as the speaker is speaking it -
## because we don't want to glitch the actual words they are saying".
##
##   - A WORD SETTLES AS IT IS SAID: every letter of it shows itself from no later than GLITCH_SETTLE after
##     the word begins, however long the word is spoken - two-sided, letters spread over the whole spoken
##     word (the obvious timing) are still noise most of the way through a long one.
##   - ONE STEADY SWEEP (reported 2026-10-07: the glitch "stops/pauses at comma boundaries, waiting for the
##     hesitation"): the front never goes back, never speeds up, has every word written by the time it
##     settles, and keeps moving through a pause - two-sided: the old front, each word written as it starts,
##     stands still through the same pause.
##   - ONLY A FEW LETTERS AHEAD (asked 2026-10-07: "glitching just a few short characters ahead", and "predict
##     ahead, then retract, then predict again"): the noise reaches no further than GLITCH_AHEAD letters
##     past the front, grows and backs off a letter at a time, and backs off part way before reaching again
##     - two-sided, a reach that never backed off or covered the line (the first glitch) fails.
##   - THE NOISE IS A FUNCTION OF SHOW TIME, and each letter keeps its own (2026-10-07: "the glitching is
##     extremely fast ... holding transitions for a minimum number of frames?"): the same letter at the same
##     moment is the same glyph, holds it at least GLITCH_HOLD.x, changes a handful of times a second, and
##     not on the same frames as its neighbor; the letter at the front is drawn from the simple set.
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
	_front()
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


func _front() -> void:
	# "Hello, my loves." - then a second's pause - "Pull up a chair."
	var spans: Array = []
	var c := 0
	var t := 1.0
	for w in ["Hello,", "my", "loves.", "Pull", "up", "a", "chair."]:
		spans.append([c, w.length(), t, t + 0.3])
		c += w.length() + 1
		t += 0.35 if w != "loves." else 1.35
	var last := -1.0
	var rate := INF
	for i in 400:
		var at := 0.5 + float(i) * 0.01
		var f := Subtitles.glitch_front(spans, at)
		_ok(f >= last - 1e-6, "the sweep went back at %.2f s" % at)
		if i > 0:
			_ok(f - last <= rate + 1e-4, "the sweep sped up at %.2f s" % at)
			if at > 1.0:
				rate = f - last
		last = f
	for sp in spans:
		var n := int(sp[1])
		var done := Subtitles.settle_at(float(sp[2]), float(sp[3]), n, n)
		_ok(Subtitles.glitch_front(spans, done + 1e-3) >= float(int(sp[0]) + n) - 1e-3, "a word is not written by the time it is said")
	# in the pause after "loves." (written by 1.92 s; "Pull" begins at 3.05 s)
	var moved := Subtitles.glitch_front(spans, 2.6) - Subtitles.glitch_front(spans, 2.0)
	_ok(moved > 2.0, "the sweep waits in the pause (%.1f letters in 0.6 s)" % moved)
	# control: the old front, each word written as it is said, stands still there
	var old := func(at: float) -> int:
		var n := 0
		for sp in spans:
			if at >= Subtitles.settle_at(float(sp[2]), float(sp[3]), int(sp[1]), int(sp[1])):
				n = int(sp[0]) + int(sp[1])
		return n
	_ok(old.call(2.6) == old.call(2.0), "control: the old front moved in the pause")


func _reach() -> void:
	var last := Subtitles.glitch_reach(4, 0.0)
	var grew := 0
	var fell := 0
	var most := 0
	var backed := 0           # a fall that is followed by a reach on again before it is down to one
	var falling := false
	for st in range(1, 600):
		var r := Subtitles.glitch_reach(4, (float(st) + 0.5) / Subtitles.GLITCH_STEPS)
		_ok(r >= 1 and r <= Subtitles.GLITCH_AHEAD, "the noise reaches %d letters ahead" % r)
		_ok(absi(r - last) <= 1, "the reach jumped from %d to %d letters in one step" % [last, r])
		if r > last and falling and last > 1:
			backed += 1
		falling = r < last if r != last else falling
		grew += 1 if r > last else 0
		fell += 1 if r < last else 0
		most = maxi(most, r)
		last = r
	_ok(grew > 40 and fell > 40, "the reach does not reach on and back off (%d steps on, %d back)" % [grew, fell])
	_ok(backed >= 5, "the reach never backs off part way and reaches again (%d times)" % backed)
	_ok(most == Subtitles.GLITCH_AHEAD, "the reach never gets past %d letters" % most)
	# control: a sentence's unsaid letters, all scrambled at once as the first glitch had them, are far more
	_ok("Pull up a chair, my loves. Sit down with me.".length() > Subtitles.GLITCH_AHEAD * 3, "control: a line is no longer than the reach")


func _noise() -> void:
	# sampled at 120 frames a second for two seconds
	var seen := {}
	var changes := 0
	var together := 0
	var shortest := INF
	var since := 0.0
	var prev := ""
	var prev2 := ""
	for f in 240:
		var t := 5.0 + float(f) / 120.0
		var g := Subtitles.glitch_glyph(3, 1, t, 2, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX)
		var g2 := Subtitles.glitch_glyph(3, 2, t, 2, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX)
		_ok(g == Subtitles.glitch_glyph(3, 1, t, 2, Subtitles.GLITCH_SIMPLE, Subtitles.GLITCH_COMPLEX), "the same moment draws a different glyph")
		seen[g] = true
		if f > 0 and g != prev:
			changes += 1
			if since > 0.0:
				shortest = minf(shortest, t - since)
			since = t
			if g2 != prev2:
				together += 1
		prev = g
		prev2 = g2
	_ok(changes >= 8 and changes <= 40, "a scrambled letter changes %d times in two seconds" % changes)
	_ok(shortest >= Subtitles.GLITCH_HOLD.x - 1.0 / 120.0, "a glyph is held only %.3f s" % shortest)
	_ok(together < changes / 2, "neighboring letters turn over together (%d of %d changes)" % [together, changes])
	# control: the old noise turned every letter over on one clock, sixteen times a second - the same
	# measure finds its neighbors turning together, and more often than the holds allow
	var old := func(c: int, t: float) -> int:
		return hash([3, c, floori(t * 16.0)])
	var o_changes := 0
	var o_together := 0
	for f in range(1, 240):
		var t := 5.0 + float(f) / 120.0
		var tp := t - 1.0 / 120.0
		if old.call(1, t) != old.call(1, tp):
			o_changes += 1
			if old.call(2, t) != old.call(2, tp):
				o_together += 1
	_ok(o_together >= o_changes / 2 and o_changes > 30, "control: the old noise passes as staggered (%d of %d together)" % [o_together, o_changes])
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

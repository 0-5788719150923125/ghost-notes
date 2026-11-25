extends Node

## Gate for how a line reveals its words ([constant Subtitles.REVEALS]): the glitch reveal must never
## glitch the words being said.
##
##   - A word settles as it is said: every letter of it shows from no later than GLITCH_SETTLE after the
##     word begins, however long it is spoken. Two-sided: letters spread over the whole spoken word are
##     still noise most of the way through a long one.
##   - One steady sweep: the front never goes back, never speeds up, has every word written by the time it
##     settles, and keeps moving through a pause. Two-sided: the old front (each word written as it starts)
##     stands still through the same pause.
##   - Only a few letters ahead: the noise reaches no further than GLITCH_AHEAD letters past the front,
##     grows and backs off a letter at a time, and backs off part way before reaching again. Two-sided: a
##     reach that never backed off or covered the line fails.
##   - The noise is a function of show time, and each letter keeps its own: the same letter at the same
##     moment is the same glyph, holds it at least GLITCH_HOLD.x, changes a handful of times a second and
##     not on the same frames as its neighbor; the letter at the front is drawn from the simple set.
##   - The choice is the show's: the Director takes a known key and refuses an unknown one, and the Look
##     card writes it into the note's `look:` block and reads it back.
##   - A row written out is its words: the glitch centers a row, and sizes its plate, on its words and the
##     gaps between them, none after its last. Two-sided: in the middle of a row the gap after a written
##     word counts.
##   - A line being written is centered: the plate round the words and the noise past them sits on the
##     middle, on the mean, as the sweep crosses a row; a row written out is centered on its words.
##     Two-sided: centered on what is written alone, the line sits right of center.
##   - A line stays inside its area: at 1080p, at 4K and in portrait, a long sentence and one with a word wider than the area are
##     drawn no wider than the area allows (the space between words measured as it is drawn, the plate's padding inside), and the
##     plate stays clear of the frame's edges. Two-sided: wrapped with the space unscaled and drawn with it scaled, a 4K row runs
##     past its area; the long word is wider than the area at the usual size.
##   - The word reveal shows the word being said: nothing before the first, each from just before it is said until the next or a
##     short hang past its end, then gone; the marks ending a phrase and the quotes round a word left off, a question kept; the
##     word set as a karaoke line is, a long one shrunk to the line's area. Two-sided: within the hang the word still shows; a word
##     wider than the area is set smaller.
##   - Every reveal draws: the overlay draws a line in each without an error.
##
##   tests/run_boot_probe.sh tests/show/subtitle_reveal_check.gd 60

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
	_rows()
	_centered()
	_fits()
	_word()
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
	# control: the old noise turned every letter over on one clock, sixteen times a second; the same
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
	Director.set_subtitle_reveal("word")
	_ok(Director.subtitle_reveal == "word", "the Director did not take the word reveal")
	Director.set_subtitle_reveal("sparkle")
	_ok(Director.subtitle_reveal == "karaoke", "an unknown reveal was kept")
	var card := LookCard.new()
	Director.set_subtitle_reveal("glitch")
	_ok(String(card.capture().get("subtitles", "")) == "glitch", "the Look card does not write the reveal into its block")
	card.apply({"subtitles": "karaoke"})
	_ok(Director.subtitle_reveal == "karaoke", "the Look card does not read the reveal back")
	card.free()
	Director.set_subtitle_reveal(was)


func _rows() -> void:
	var ov := Subtitles.Overlay.new()
	var font := ThemeDB.fallback_font
	var gap := 14.0
	var row: Array = [{"idx": 0, "word": {"text": "one"}, "w": 30.0, "cstart": 0},
		{"idx": 1, "word": {"text": "two"}, "w": 30.0, "cstart": 4},
		{"idx": 2, "word": {"text": "end."}, "w": 40.0, "cstart": 8}]
	var whole := ov._written(row, 40.0, font, 24, gap)
	_ok(is_equal_approx(whole, 30.0 + 30.0 + 40.0 + 2.0 * gap), "a row written out measures %.0f, not its words and the gaps between them (%.0f)"
		% [whole, 30.0 + 30.0 + 40.0 + 2.0 * gap])
	var mid := ov._written(row, 7.5, font, 24, gap)
	_ok(is_equal_approx(mid, 30.0 + 30.0 + gap + gap * 0.5), "control: half way through the gap after a written word, it counts half of it (%.1f)" % mid)
	ov.free()


func _centered() -> void:
	var ov := Subtitles.Overlay.new()
	var font := ThemeDB.fallback_font
	var fs := 30
	var gap := 14.0
	var row: Array = []
	var c := 0
	for w in ["Full", "dark", "already,", "and", "a", "sea", "fog", "pressed", "right", "up", "against", "the", "glass."]:
		row.append({"idx": row.size(), "word": {"text": w}, "w": font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, "cstart": c})
		c += w.length() + 1
	var end := float(c - 1)
	var cx := 960.0
	var off := 0.0
	var old_off := 0.0
	var n := 0
	# the sweep across the row as it is spoken, the noise's reach on its own clock
	for st in 3000:
		var sweep := end * float(st) / 3000.0
		var reach := Subtitles.glitch_reach(7, float(st) / 30.0)
		var drawn := ov._written(row, float(floori(sweep) + reach), font, fs, gap)
		var x0 := ov._glitch_x(row, sweep, cx, font, fs, gap)
		off += x0 + drawn * 0.5 - cx
		old_off += cx - ov._written(row, sweep, font, fs, gap) * 0.5 + drawn * 0.5 - cx
		n += 1
	print("  centered: %.2f px now, %.2f px the old way" % [off / n, old_off / n])
	_ok(absf(off / n) < 3.0, "a line being written sits %.1f px off center" % (off / n))
	_ok(is_equal_approx(ov._glitch_x(row, end, cx, font, fs, gap), cx - ov._written(row, end, font, fs, gap) * 0.5), "a row written out is not centered on its words")
	# control: centered on what is written alone (the first glitch), the line being written sits right of center
	_ok(old_off / n > 8.0, "control: the old centering sits only %.1f px right" % (old_off / n))
	ov.free()


func _fits() -> void:
	var ov := Subtitles.Overlay.new()
	var font := ThemeDB.fallback_font
	var long_words: Array = []
	for i in 40:
		long_words.append(["Something", "moved", "behind", "the", "factory", "gate", "tonight,", "and", "nobody", "saw"][i % 10])
	var wide_word := "Antidisestablishmentarianism-and-everything-after-it-in-one-breath"
	for size in [Vector2(1920, 1080), Vector2(3840, 2160), Vector2(1080, 1920)]:
		var frame := Rect2(Vector2.ZERO, size)
		var box := Subtitles.text_area(frame)
		var area: Rect2 = box["area"]
		_ok(area.position.x >= size.x * 0.04 and area.end.x <= size.x * 0.96, "the %s area runs to the frame's edge (%.0f..%.0f)"
			% [size, area.position.x, area.end.x])
		for words in [long_words, ["A", wide_word, "came", "in."]]:
			var items: Array = []
			var c := 0
			for w in words:
				items.append({"idx": items.size(), "word": {"text": w}, "w": 0.0, "cstart": c})
				c += String(w).length() + 1
			var fit := ov.fit_line(items, font, float(box["k"]), float(box["max_w"]), float(box["gap"]))
			var lines: Array = fit["lines"]
			for row in lines:
				var drawn := -float(box["gap"])
				for item in row:
					drawn += float(item.w) + float(box["gap"])
				var left := float(box["cx"]) - drawn * 0.5 - float(box["pad"])
				var right := float(box["cx"]) + drawn * 0.5 + float(box["pad"])
				_ok(left >= area.position.x - 0.5 and right <= area.end.x + 0.5, "a %s row's plate runs %.0f..%.0f, past its area %.0f..%.0f (%d words)"
					% [size, left, right, area.position.x, area.end.x, row.size()])
	# control: the space unscaled when wrapping and scaled when drawn, a 4K row runs past its area
	var box4 := Subtitles.text_area(Rect2(0, 0, 3840, 2160))
	var items4: Array = []
	for w in long_words:
		items4.append({"idx": items4.size(), "word": {"text": w}, "w": 0.0, "cstart": 0})
	var rows := ov._wrap(items4, font, int(round(Subtitles.Overlay.BASE_FS * float(box4["k"]))), float(box4["max_w"]), Subtitles.GAP)
	_ok(Subtitles.Overlay._widest(rows, float(box4["gap"])) > float(box4["max_w"]), "control: the unscaled space keeps a 4K row inside its area")
	_ok(font.get_string_size(wide_word, HORIZONTAL_ALIGNMENT_LEFT, -1, Subtitles.Overlay.BASE_FS).x > float(Subtitles.text_area(Rect2(0, 0, 1080, 1920))["max_w"]),
		"control: the long word fits the portrait area at the usual size, so its shrinking is untested")
	ov.free()


func _word() -> void:
	var words: Array = [{"text": "\"Hello,", "t0": 1.0, "t1": 1.3, "sentence": 0}, {"text": "there.\"", "t0": 1.4, "t1": 1.8, "sentence": 0},
		{"text": "Why?", "t0": 4.0, "t1": 4.4, "sentence": 1}]
	_ok(int(Subtitles.word_at(words, 0.9)[0]) == -1, "a word shows before the first is said")
	_ok(int(Subtitles.word_at(words, 1.0 - Subtitles.WORD_EARLY + 0.001)[0]) == 0, "the first word does not show just before it is said")
	_ok(int(Subtitles.word_at(words, 1.35)[0]) == 0, "a word does not hold through the gap before the next")
	_ok(int(Subtitles.word_at(words, 1.4 - Subtitles.WORD_EARLY + 0.001)[0]) == 1, "the next word does not take over as it is begun")
	var hang: Array = Subtitles.word_at(words, 1.8 + Subtitles.WORD_HANG * 0.5)
	_ok(int(hang[0]) == 1 and float(hang[1]) == 1.0, "control: within its hang the word is not shown whole")
	var fading: Array = Subtitles.word_at(words, 1.8 + Subtitles.WORD_HANG + Subtitles.WORD_FADE * 0.5)
	_ok(int(fading[0]) == 1 and float(fading[1]) > 0.0 and float(fading[1]) < 1.0, "the word does not fade after its hang")
	_ok(int(Subtitles.word_at(words, 3.0)[0]) == -1, "a word stays up through a long pause")
	_ok(int(Subtitles.word_at(words, 4.2)[0]) == 2, "the word after a pause does not show")
	for pair in [["\"Hello,", "Hello"], ["there.\"", "there"], ["Why?", "Why?"], ["“stop”", "stop"], ["wait...", "wait"], ["now:", "now"],
			["‘yes’", "yes"], ["don't", "don't"], ["—", "—"], ["Go!", "Go!"]]:
		_ok(Subtitles.word_shown(pair[0]) == pair[1], "%s is shown as %s, not %s" % [pair[0], Subtitles.word_shown(pair[0]), pair[1]])
	var portrait := Subtitles.text_area(Rect2(0, 0, 1080, 1920))
	var face := ThemeDB.fallback_font
	_ok(Subtitles.Overlay.word_size(face, "a", 1.0, float(portrait["max_w"])) == Subtitles.Overlay.BASE_FS, "a word is not set at a karaoke line's size")
	var long := "Unbelievably-long-hyphenated-word-that-goes-on"
	var fs := Subtitles.Overlay.word_size(face, long, 1.0, float(portrait["max_w"]))
	var w := face.get_string_size(long, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_ok(fs < Subtitles.Overlay.BASE_FS and w <= float(portrait["max_w"]), "control: a word wider than the line's area is %.0f wide at %d, past it %.0f" % [w, fs, float(portrait["max_w"])])
	_ok(540.0 + w * 0.5 <= 1080.0 * (1.0 - float(Subtitles.SAFE["right"])) + 0.5, "the portrait word reaches under the buttons down the right edge")


func _draws() -> void:
	var was := Director.subtitle_reveal
	var subs: Subtitles = preload("res://src/show/subtitles.gd").new()
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
	for reveal in ["karaoke", "glitch", "credits", "word"]:
		Director.set_subtitle_reveal(reveal)
		for f in 12:
			subs._process(1.0 / 30.0)
			await get_tree().process_frame
		var up := subs.span_at(subs._now()) >= 0 if reveal != "word" else int(Subtitles.word_at(words, subs._now())[0]) == 3
		_ok(subs.presence > 0.5 and up, "the %s line is not up to be drawn" % reveal)
	Spectrum.virtual_clock = -1.0
	subs.queue_free()
	Director.set_subtitle_reveal(was)

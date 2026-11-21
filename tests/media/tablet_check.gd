extends SceneTree

## The tablet's script: what the hand does is inferred right, and the voice and the screen agree
## about which words are read.
##
##   godot --headless --path . --script tests/media/tablet_check.gd
##
## The sharp check is the AGREEMENT. The medium finds the word being said by walking the
## chapter's spoken words alongside the voice's; a word the voice reads that the screen thinks
## is skipped (or the reverse) desynchronizes every highlight, scroll and tap after it, silently.
## So the voice's text ([method TabletScript.speakable]) is tokenized the way the voice would see
## it and compared, word for word, with the words the parse marks spoken. And a chapter that is
## NOT a tablet chapter must come back byte-identical, because this runs on every reading.
##
## A live chat ([constant TabletScript.CHAT]) is read whole and never aloud (control: the words after it are read); its
## page is built to the screen with the message box at its foot; the stream is a pure function of the time (the same
## twice), comes about as often as asked, and never shows a message before its time.
##
## A forum ([method TabletPage._post_begin]): each post's blocks are its own until a heading (control: the paragraph
## after the heading is no post's), its quote a block, its body set beside the author's column inside its card; a
## board's counts are centered in their column and a cell's detail after `<br>` set smaller; the site's `nav` labels its
## menu row and a later page of the site keeps it; a `pager` mark sets a pager of its number of pages. Without placeholders a page draws no squiggles and ends where its
## writing does (control: the same page with them is padded with squiggled stories).

var _fail := 0

const DOC := """---
title: Test
---

Somebody picks it up.

<!-- url: news.test -->

<!-- skip -->
# The News

<!-- filler: 2 -->

## [A Story](news.test/a-story)

<!-- skip -->
The stub of it.

## Nobody wrote this one

<!-- url: news.test/a-story -->

# A Story

Read this. <!-- skip --> Not this, or the rest of the paragraph.

Read to the end <!-- skip --> of this sentence. But not this one.

<!-- skip -->
None of this paragraph.

Some *emphasis* and a [link here](other.test/page) to follow.

<!-- new tab -->
<!-- url: www.engine.test -->

<!-- skip -->
# Engine

<!-- search: what is it? -->

### [First result](far.test/one)

A snippet.

<!-- url: far.test/one -->
<!-- landscape -->

# Far away

The end.
"""


func _initialize() -> void:
	_check_inference()
	_check_agreement()
	_check_untouched()
	_check_back()
	_check_marks()
	_check_real()
	_check_arrivals()
	_check_omnibox()
	_check_list()
	_check_table()
	_check_notify()
	_check_chat()
	_check_forum()
	print("tablet_check: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", what)
	else:
		print("  ok: ", what)


func _check_inference() -> void:
	var d := TabletScript.parse(DOC)
	var kinds := []
	for a in d["actions"]:
		kinds.append(String(a["kind"]))
	_ok(kinds == ["wake", "open", "type", "skim", "link", "tab", "type", "search", "link", "rotate"],
		"actions inferred: %s" % str(kinds))
	var pages: Array = d["pages"]
	_ok(pages.size() == 5, "five pages (got %d)" % pages.size())
	var acts: Array = d["actions"]
	var link: Dictionary = acts[4]
	_ok(String(d["words"][int(link["word"])]["text"]) == "A", "the link tapped is the headline's first word")
	_ok(String(acts[6]["text"]) == "www.engine.test", "a url with no link to it is typed")
	# below a skipped masthead and two placeholder stories, the reader skims to the headline;
	# on the article, a short skipped tail is no skim
	_ok(int(acts[3]["word"]) == int(link["word"]) and int(acts[3]["from"]) == 0,
		"the hand skims past what is not read to what is")
	_ok(bool(pages[2]["search_box"]) and not bool(pages[2]["results"]), "a page searched from has a box")
	_ok(bool(pages[3]["results"]) and String(pages[3]["query"]) == "what is it?", "the results page knows its query")
	var stubs := []
	for b in pages[0]["blocks"]:
		if b["kind"] == "heading" and bool(b.get("stub", false)):
			stubs.append(b["raw"])
	_ok(stubs == ["Nobody wrote this one"], "a heading with nothing under it is a stub, a skipped body is not: %s" % str(stubs))
	# Nothing is read off the screen: the narration before the first url is not a word at all
	_ok(int(acts[0]["after"]) == 0 and int(acts[1]["after"]) == 0, "nothing is read before the browser opens")
	_ok(String(acts[1]["kind"]) == "open" and int(acts[1]["page"]) == -1 and String(acts[2]["kind"]) == "type"
		and String(acts[2]["text"]) == "news.test", "the browser opens on a blank tab and the first address is typed")
	var first: Dictionary = d["words"][(d["spoken"] as PackedInt32Array)[0]]
	_ok(int(first["page"]) == 0 and String(first["text"]) == "A", "the first word read is on the first page")
	# a skip mark mid-sentence holds off to the sentence's end
	var sp := String(d["speakable"])
	_ok(sp.contains("Read to the end of this sentence.") and not sp.contains("But not"),
		"a skip mid-sentence takes effect at the sentence's end")


func _check_agreement() -> void:
	var d := TabletScript.parse(DOC)
	var said := []
	for wi in (d["spoken"] as PackedInt32Array):
		var n := String(d["words"][wi]["norm"])
		if not n.is_empty():
			said.append(n)
	var voice := []
	var text := String(d["speakable"])
	text = TabletScript._rx("<!--[\\s\\S]*?-->").sub(text, " ", true)
	for tok in text.split("\n"):
		for w in String(tok).lstrip("#").split(" ", false):
			var n := TabletScript.norm(String(w))
			if not n.is_empty():
				voice.append(n)
	_ok(said == voice, "the voice reads exactly the words marked spoken\n    voice %s\n    page  %s" % [str(voice), str(said)])
	for gone in ["Somebody", "Test", "News", "stub", "Not", "None", "Engine", "news.test"]:
		_ok(not String(d["speakable"]).contains(gone), "'%s' is not read" % gone)
	for kept in ["Read this.", "link here", "First result"]:
		_ok(String(d["speakable"]).contains(kept), "'%s' is read" % kept)
	# one rest per run of actions, each as long as the run
	var holds := []
	for m in TabletScript._rx(TabletScript.HOLD).search_all(String(d["speakable"])):
		holds.append(float(m.get_string(1)))
	var want := []
	var run := 0.0
	var after := -1
	for a in d["actions"]:
		if int(a["after"]) != after and after >= 0:
			want.append(snappedf(run, 0.01))
			run = 0.0
		after = int(a["after"])
		run += float(a["dur"])
	want.append(snappedf(run, 0.01))
	var got := []
	for h in holds:
		got.append(snappedf(h, 0.01))
	_ok(got == want, "a rest per run of actions, sized to it: %s vs %s" % [str(got), str(want)])
	_ok(TabletScript.hold_of("<!-- action-hold: 3.5 -->") == 3.5 and TabletScript.hold_of("<!-- hesitation -->") < 0.0,
		"hold_of reads only the action rest")


const BACK := """<!-- url: r.test -->

# Results

[One](one.test)

[Two](two.test)

<!-- url: two.test -->

<!-- skip -->
Nothing read here at all.

<!-- back -->

Dropped words.

<!-- url: one.test -->

# One
"""


## What the dispatch desk's tablet browses by: each action names the mark that made it, its tab and what is behind it.
func _check_marks() -> void:
	var d := TabletScript.parse("<!-- url: a.test -->\n\nOne. [B](a.test/b)\n\n<!-- url: a.test/b -->\n\nTwo.\n\n"
		+ "<!-- url: a.test/b -->\n\nTwo again.\n\n<!-- back -->\n\n<!-- back -->\n\n<!-- new tab -->\n<!-- search: what is it -->\n\n### [R](r.test)\n")
	var made := {}
	for a in d["actions"]:
		if (a as Dictionary).has("mark") and String(a["kind"]) != "open":
			made[int(a["mark"])] = a
	var kinds := []
	for m in 7:
		kinds.append(String((made[m] as Dictionary)["kind"]) if made.has(m) else "")
	_ok(kinds == ["type", "link", "type", "back", "", "tab", "search"],
		"each url, search, new tab and back mark names the action it made, and a back with nothing behind it makes none: %s" % str(kinds))
	_ok(bool(made[2].get("again", false)) and int(made[2]["behind"]) == 1 and not bool(made[1].get("again", false)) and int(made[1]["behind"]) == 1
		and int(made[3]["page"]) == 0 and int(made[3]["behind"]) == 0,
		"the address of the page already up replaces it - nothing more behind it, and back goes to the page before both (the control: a new address adds one)")
	var blank: Dictionary = made[6]
	_ok(int(made[5]["tab"]) == 1 and int(made[5]["behind"]) == 0 and bool(blank["bar"]) and int(blank["from"]) == -1 and int(blank["tab"]) == 1
		and String(d["pages"][int(blank["page"])]["host"]) == TabletScript.ENGINE and bool(d["pages"][int(blank["page"])]["results"]),
		"a search in a blank tab is typed into the address bar, its results a search engine's")
	var first := TabletScript.parse("<!-- search: what is it -->\n\n### [R](r.test)\n")
	var first_kinds := []
	for a in first["actions"]:
		first_kinds.append(String(a["kind"]))
	_ok(first_kinds == ["wake", "open", "search"] and bool(first["actions"][2]["bar"]) and (first["pages"] as Array).size() == 1,
		"a search with no page up opens the browser and is typed into the address bar: %s" % str(first_kinds))


func _check_back() -> void:
	var d := TabletScript.parse(BACK)
	var kinds := []
	for a in d["actions"]:
		kinds.append(String(a["kind"]))
	_ok(kinds == ["wake", "open", "type", "link", "skim", "back", "link"], "back inferred, with a glance first: %s" % str(kinds))
	var acts: Array = d["actions"]
	_ok(int(acts[5]["page"]) == 0 and int(acts[5]["from"]) == 1, "back returns to the page before")
	_ok(int(acts[4]["word"]) == -1, "an unread page is glanced at before leaving it")
	_ok(int(acts[6]["from"]) == 0 and String(d["words"][int(acts[6]["word"])]["text"]) == "One",
		"after back, the next link is found on the page returned to")
	var all := []
	for w in d["words"]:
		all.append(String(w["text"]))
	_ok(not all.has("Dropped") and not String(d["speakable"]).contains("Dropped"),
		"text after a back is neither shown nor read")
	# typing: the screen and the voice's rest come from the same clock
	var text := "www.duckduckduck.mom"
	var ct := TabletScript.char_times(text)
	var ph := TabletScript.phases("type", text)
	var mono := true
	for i in text.length():
		mono = mono and ct[i + 1] > ct[i]
	_ok(mono and is_equal_approx(float(ph["chars1"]) - float(ph["chars0"]), ct[text.length()]),
		"each letter typed after the last, ending when the rest says")
	_ok(ct[text.length()] / text.length() >= 0.18, "typing is unhurried (%.2f s a letter)" % (ct[text.length()] / text.length()))


const REAL := """<!-- url: news.test/a -->

# An article

Read this, then [the listing](https://www.shop.test/item/42).

<!-- url: https://www.shop.test/item/42 -->

<!-- new tab -->
<!-- url: engine.test -->

# Engine
"""


func _check_real() -> void:
	var d := TabletScript.parse(REAL)
	var pages: Array = d["pages"]
	_ok(bool(pages[1].get("real", false)) and not bool(pages[0].get("real", false)) and not bool(pages[2].get("real", false)),
		"a url with nothing written under it is the real page; written ones are not")
	_ok(String(pages[1]["snap"]) == TabletScript.snap_key("shop.test/item/42"), "its capture is keyed by its address")
	var kinds := []
	for a in d["actions"]:
		kinds.append(String(a["kind"]))
	_ok(kinds == ["wake", "open", "type", "link", "skim", "tab", "type"], "the real page is reached by its link and lingered on: %s" % str(kinds))
	var linger: Dictionary = d["actions"][4]
	_ok(int(linger["from"]) == 1 and int(linger["word"]) == -1 and float(linger["dur"]) >= 6.0,
		"the linger is long (%.1f s): nothing on it is read" % float(linger["dur"]))
	_ok(not String(d["speakable"]).contains("An article") and String(d["speakable"]).contains("Read this"),
		"a page's opening title is shown, not read; what follows it is read")
	var snaps := TabletScript.snapshots(REAL)
	_ok(snaps.size() == 1 and String(snaps[0]["url"]) == "https://www.shop.test/item/42" and String(snaps[0]["placement"]) == "page",
		"the panel is offered the real page to capture")


const OMNI := """<!-- url: engine.test -->

# Engine

<!-- search: first -->

### [A result](site.test/article)

<!-- url: site.test/article -->

# An article

One. Two. Three.

Four. Five.

Six. Seven.

Eight.

<!-- search: second -->

### Another result
"""


func _check_omnibox() -> void:
	var d := TabletScript.parse(OMNI)
	var acts: Array = []
	for a in d["actions"]:
		if a["kind"] == "search":
			acts.append(a)
	var pages: Array = d["pages"]
	_ok(acts.size() == 2 and not bool(acts[0].get("bar", false)), "a search on an engine's page goes in its box")
	_ok(bool(acts[1].get("bar", false)) and not bool(pages[2]["search_box"]),
		"a search from an article goes in the address bar - no box grows on the article")
	_ok(String(pages[3]["host"]) == "engine.test", "...and its results come from the engine last used")


func _check_arrivals() -> void:
	# a page that comes up is looked at before anything else happens on it
	for kind in ["open", "link", "type", "search"]:
		var ph := TabletScript.phases(kind, "what is it?")
		_ok(float(ph["end"]) - float(ph["show"]) >= TabletScript.ARRIVE_LOOK - 0.001,
			"%s ends on a look at the new page (%.1f s)" % [kind, float(ph["end"]) - float(ph["show"])])
	var rd := TabletScript.parse("<!-- url: a.test -->\n\n[Book](a.test/book)\n\n<!-- redirect: x.test/r, y.test/pay -->\n<!-- url: a.test/book -->\n\nThanks.\n")
	var hops := []
	var dur := 0.0
	for a in rd["actions"]:
		if a["kind"] == "link":
			hops = a.get("hops", [])
			dur = float(a["dur"])
	_ok(hops == ["x.test/r", "y.test/pay"], "a redirect sends the tap through the hops named: %s" % str(hops))
	var own := false
	for a in rd["actions"]:
		if a["kind"] == "link":
			own = bool(a.get("new_tab", false))
	_ok(own, "a link that redirects opens a tab of its own")
	var rt := TabletScript.parse("<!-- url: a.test -->\n\n[Book](a.test/book)\n\n<!-- redirect -->\n<!-- url: a.test/book -->\n\nThanks. [More](a.test/more)\n\n<!-- url: a.test/more -->\n\nMore.\n\n<!-- back -->\n")
	var kinds := []
	for a in rt["actions"]:
		kinds.append(String(a["kind"]))
	_ok(kinds.has("back") and int(rt["actions"].back()["page"]) == 1,
		"in the new tab, back goes to the page the redirect landed on: %s" % str(kinds))
	var plain := float(TabletScript.phases("link")["end"])
	_ok(is_equal_approx(dur - plain, TabletScript.HOP_S * 2.0),
		"each hop holds the page back HOP_S, and the voice waits for it (%.2f s more)" % (dur - plain))
	var spans := TabletScript.hop_spans(["a.test/1", "b.test/2", "c.test/3"])
	var sum := 0.0
	for x in spans:
		sum += x
	_ok(is_equal_approx(sum, TabletScript.HOP_S * 3.0) and absf(spans[0] - spans[1]) + absf(spans[1] - spans[2]) > 0.05,
		"a chain's hops share its time unevenly, and add up to it: %s" % str(spans))
	var auto: Array = TabletScript.auto_hops("gazebra.ride/book")
	_ok(auto.size() == TabletScript.REDIRECT_HOPS and String(auto[0]).begins_with("gazebra.ride/"),
		"a bare redirect makes its hops up from the page's own site: %s" % str(auto))
	var lk := TabletScript.phases("link")
	_ok(float(lk["tap"]) - float(lk["scroll1"]) >= TabletScript.LINK_LOOK - 0.001,
		"a link is looked at, still, before it is tapped (%.1f s)" % (float(lk["tap"]) - float(lk["scroll1"])))
	var bk := TabletScript.phases("back")
	_ok(float(bk["end"]) - float(bk["show"]) >= TabletScript.RETURN_LOOK - 0.001, "back ends on a shorter look")


func _check_list() -> void:
	var src := "<!-- url: a.test -->\n\n## Reports\n\n- One thing.\n- Two things.\n\n- Three.\n\nAfter.\n\n1. First\n2) Second\n"
	var blocks: Array = (TabletScript.parse(src)["pages"][0] as Dictionary)["blocks"]
	var kinds := []
	for b in blocks:
		kinds.append(String((b as Dictionary)["kind"]))
	_ok(kinds == ["heading", "item", "item", "item", "para", "item", "item"], "a list's lines are items: %s" % str(kinds))
	if kinds.size() == 7:
		_ok(int(blocks[1]["list"]) == int(blocks[3]["list"]) and int(blocks[5]["list"]) != int(blocks[1]["list"]),
			"items in a row are one list, a blank line between them included; a paragraph ends it")
		_ok(String(blocks[1]["mark"]) == "" and String(blocks[5]["mark"]) == "1." and String(blocks[6]["mark"]) == "2)",
			"a bullet list has no marks; a numbered one keeps its numbers")
	var say := TabletScript.speakable(src)
	_ok(not say.contains("- One") and not say.contains("1. First") and say.contains("One thing.\n\nTwo things."),
		"each item is read as its own short paragraph, without its dash")


func _check_chat() -> void:
	var src := ("<!-- url: live.test/a -->\n\n# A stream\n\n<!-- chat: 3 -->\nme: desk\ntip: $5\n$2 ann: say home\n"
		+ "names: ann, bo, cy\nnames: di\n- first message\n- second message\n- third message\n<!-- /chat -->\n\nAfter the chat.\n")
	var doc := TabletScript.parse(src)
	var blocks: Array = (doc["pages"][0] as Dictionary)["blocks"]
	var chat: Dictionary = {}
	for b in blocks:
		if String((b as Dictionary)["kind"]) == "chat":
			chat = b
	_ok(not chat.is_empty() and (chat["names"] as PackedStringArray).size() == 4 and (chat["said"] as PackedStringArray).size() == 3
		and (chat["paid"] as Array).size() == 1 and String(chat["me"]) == "desk" and String(chat["tip"]) == "$5" and float(chat["rate"]) == 3.0,
		"a chat's names, bank, paid message, name and tip are read: %s" % str(chat))
	var say := TabletScript.speakable(src)
	_ok(not say.contains("message") and not say.contains("names") and say.contains("After the chat."),
		"a chat is never read aloud (control: the words after it are)")
	var tp := TabletPage.new()
	tp.build(doc, 0, 1200.0, 1400.0 * 2.4, 1400.0)
	_ok(tp.height == 1400.0 and tp.reply_rect.end.y <= 1400.0 and tp.reply_rect.size.y > 0.0,
		"a live page is the screen's height, its message box at the foot")
	var a: Array = tp.chat_at(chat, 200.0, 400.0)
	_ok(a == tp.chat_at(chat, 200.0, 400.0) and not a.is_empty(), "the stream is the same at the same time")
	_ok(a.all(func(m: Dictionary) -> bool: return float(m["at"]) <= 200.0), "no message shows before its time")
	var over: Array = tp.chat_at(chat, 300.0, 6000.0)
	var span := float(over[0]["at"]) - float(over.back()["at"])
	var rate := float(over.size() - 1) / maxf(span, 0.001)
	_ok(rate > 2.0 and rate < 4.0, "messages come about as often as asked (3 a second): %.2f" % rate)


func _check_forum() -> void:
	var src := "<!-- url: board.test -->\n<!-- nav: Forums | Members -->\n\n# Board\n\n" \
		+ "<!-- pager: 245 -->\n\n| Board | Topics |\n|---|---|\n| [Street](board.test/f/street)<br>Strangers who perform | 4,112 |\n| Cars<br>On the road | 906 |\n\n" \
		+ "<!-- filler: 2 -->\n\n<!-- url: board.test/t/one -->\n\n# One\n\n<!-- post: ann | Member · 12 posts | Tue -->\n\nFirst said.\n\n" \
		+ "<!-- post: bo | Senior | Wed -->\n\n> **ann wrote:** First said.\n\nSecond said.\n\n## After\n\nNobody's post.\n"
	var d := TabletScript.parse(src)
	var p1: Dictionary = d["pages"][1]
	var kinds := []
	for b in p1["blocks"]:
		var bd: Dictionary = b
		kinds.append("%s:%d" % [bd["kind"], int(bd.get("post", 0))])
	_ok(kinds == ["heading:0", "post:0", "para:1", "post:0", "quote:2", "para:2", "heading:0", "para:0"],
		"a post's blocks are its own until a heading, its quote a block (control: the paragraph after the heading): %s" % str(kinds))
	_ok((d["pages"][0]["nav"] as PackedStringArray) == PackedStringArray(["Forums", "Members"]), "a page's nav is read")
	var detail := -1
	for wi in d["words"].size():
		if String(d["words"][wi]["text"]) == "Strangers":
			detail = wi
	_ok(detail >= 0 and bool(d["words"][detail].get("brk", false)), "a word after <br> carries the break")
	_ok(String(d["speakable"]).contains("Street. Strangers who perform"), "a break is read as a sentence's end")
	var tp := TabletPage.new()
	tp.placeholders = false
	tp.build(d, 1, 1200.0, 1400.0 * 2.4, 1400.0)
	var card := Rect2()
	var avatars := 0
	var squiggles := 0
	for it in tp.items:
		var k := String((it as Dictionary)["kind"])
		if k == "card" and card.size == Vector2.ZERO:
			card = (it as Dictionary)["rect"]
		avatars += 1 if k == "avatar" else 0
		squiggles += 1 if k in ["squiggle", "image"] else 0
	var first := -1
	var nobody := -1
	for wi in d["words"].size():
		if int(d["words"][wi]["page"]) == 1 and String(d["words"][wi]["text"]) == "First" and first < 0:
			first = wi
		if String(d["words"][wi]["text"]) == "Nobody's":
			nobody = wi
	var fr: Rect2 = tp.word_rect.get(first, Rect2())
	var nr: Rect2 = tp.word_rect.get(nobody, Rect2())
	_ok(avatars == 2 and card.has_point(fr.get_center()) and fr.position.x > card.position.x + TabletPage.POST_SIDE
		and not card.has_point(nr.get_center()) and nr.position.x < fr.position.x,
		"a post's body is set in its card beside the author's column (control: the words after the heading are on the page's own column)")
	_ok(squiggles == 0 and tp.height < 1400.0 * 2.4, "without placeholders a page draws none and ends where its writing does (%d px)" % int(tp.height))
	var t0 := TabletPage.new()
	t0.placeholders = false
	t0.build(d, 0, 1200.0, 1400.0 * 2.4, 1400.0)
	var pagers := t0.items.filter(func(it: Dictionary) -> bool: return String(it["kind"]) == "pager")
	_ok(pagers.size() == 1 and int(pagers[0]["pages"]) == 245, "a pager mark sets Back, the pages to its number, and Next")
	var navs := t0.items.filter(func(it: Dictionary) -> bool: return String(it["kind"]) == "nav")
	var t1 := TabletPage.new()
	t1.placeholders = false
	t1.build(d, 1, 1200.0, 1400.0 * 2.4, 1400.0)
	var navs1 := t1.items.filter(func(it: Dictionary) -> bool: return String(it["kind"]) == "nav")
	_ok(navs.size() == 1 and (navs[0]["labels"] as PackedStringArray).size() == 2 and navs1.size() == 1 and (navs1[0]["labels"] as PackedStringArray).size() == 2,
		"the site's menu row is labeled by its nav, and a later page of the site keeps it")
	var count_r := Rect2()
	var head_r := Rect2()
	var small := 0
	for it in t0.items:
		var dd: Dictionary = it
		if String(dd["kind"]) != "word":
			continue
		var txt := String(d["words"][int(dd["wi"])]["text"])
		if txt == "906":
			count_r = dd["rect"]
		if txt == "Topics":
			head_r = dd["rect"]
		if txt == "Strangers":
			small = int(dd["fs"])
	_ok(absf(count_r.get_center().x - head_r.get_center().x) < 40.0 and small == TabletPage.DETAIL_FS,
		"a column of counts is centered under its header, and a cell's detail set smaller (%.0f vs %.0f, %d px)" % [count_r.get_center().x, head_r.get_center().x, small])
	var padded := TabletPage.new()
	padded.build(d, 0, 1200.0, 1400.0 * 2.4, 1400.0)
	var pad_squiggles := padded.items.filter(func(it: Dictionary) -> bool: return String(it["kind"]) == "squiggle").size()
	_ok(pad_squiggles > 0 and padded.height >= 1400.0 * 2.4, "the control: with placeholders the same page is padded with squiggled stories")


func _check_table() -> void:
	var src := "<!-- url: a.test -->\n\n## Plans\n\n| Plan | What you get | Rate |\n|---|:---:|---|\n" \
		+ "| Free | Dreams as usual | <!-- skip -->Nothing |\n| Premium | No [falling](a.test/fall). | <!-- skip -->Some |\n" \
		+ "After the table.\n"
	var d := TabletScript.parse(src)
	var blocks: Array = (d["pages"][0] as Dictionary)["blocks"]
	var kinds := []
	for b in blocks:
		kinds.append(String((b as Dictionary)["kind"]))
	_ok(kinds == ["heading", "table", "para"], "a table is one block, and a line without a pipe ends it: %s" % str(kinds))
	if kinds.size() == 3:
		var t: Dictionary = blocks[1]
		_ok((t["head"] as Array).size() == 3 and (t["rows"] as Array).size() == 2 and (t["row_cells"] as Array).size() == 2,
			"the rule makes the first row its header; two rows of three cells")
	var say := String(d["speakable"])
	_ok(say.contains("Free. Dreams as usual. Premium. No falling."),
		"the body is read row by row, each cell a sentence: %s" % say.get_slice("\n\n", 2))
	_ok(not say.contains("What you get") and not say.contains("Rate") and not say.contains("Nothing") and not say.contains("Some"),
		"the header is shown, not read, and a skipped cell is not read")
	_ok((d["pages"][0]["links"] as Dictionary).has("a.test/fall"), "a link in a cell can be tapped")
	var glued := false
	for w in d["words"]:
		if String((w as Dictionary)["text"]) == "." and bool((w as Dictionary).get("glue", false)):
			glued = true
	_ok(glued, "the period written against a link is set against it, with no space")
	var said := []
	for wi in (d["spoken"] as PackedInt32Array):
		var sn := String(d["words"][wi]["norm"])
		if not sn.is_empty():
			said.append(sn)
	var voice := []
	for w in TabletScript._rx("<!--[\\s\\S]*?-->|#|\\s+").sub(say, " ", true).split(" ", false):
		var n := TabletScript.norm(String(w))
		if not n.is_empty():
			voice.append(n)
	_ok(said == voice, "the voice reads exactly the table's words marked spoken\n    voice %s\n    page  %s" % [str(voice), str(said)])


func _check_notify() -> void:
	var src := "<!-- url: a.test -->\n\nOne two. It will be very good company. <!-- notify: Bank | Was this you? | A charge. --> Refunds are not available.\n\n<!-- notify: Own | Line | Mark -->\n\nLast words.\n"
	var d := TabletScript.parse(src)
	var notes: Array = d["notes"]
	_ok(notes.size() == 2, "a notification is found mid-paragraph and on a line of its own (%d)" % notes.size())
	if notes.size() == 2:
		var w0 := String(d["words"][(d["spoken"] as PackedInt32Array)[int(notes[0]["after"])]]["text"])
		var w1 := String(d["words"][(d["spoken"] as PackedInt32Array)[int(notes[1]["after"])]]["text"])
		_ok(w0 == "Refunds" and w1 == "Last", "each banner is timed from the word read after its mark (%s, %s)" % [w0, w1])
		_ok(String(notes[0]["sender"]) == "Bank" and String(notes[0]["title"]) == "Was this you?", "its fields are read")
	var say := String(d["speakable"])
	_ok(not say.contains("Bank") and not say.contains("charge") and say.contains("company. Refunds"),
		"a notification is not read, and the sentence around it is whole")
	for w in d["words"]:
		_ok(not String((w as Dictionary)["text"]).contains("notify"), "the mark leaves no word on the page")
		break


func _check_untouched() -> void:
	var plain := "---\ntitle: X\n---\n\nA [link](x.y) and <!-- skip --> words.\n"
	_ok(TabletScript.speakable(plain) == plain, "a chapter without url/search marks is returned untouched")
	# a picture between two read passages is stopped on
	var pics := TabletScript.parse("<!-- url: a.test -->\n\nOne.\n\n<!-- image: a cat -->\n\nTwo.\n")
	var sk: Array = []
	for a in pics["actions"]:
		if a["kind"] == "skim":
			sk.append(a)
	_ok(sk.size() == 1 and int(sk[0]["m"]) == 1 and float(sk[0]["dur"]) > TabletScript.PICTURE_DWELL,
		"a skim stops on the picture it passes")
	_ok(TabletScript.url_key("https://www.Duck.mom/") == "duck.mom", "addresses compare without scheme, www or slash")
	var run := TabletScript.find_run(PackedStringArray(["a", "b", "it", "was", "2009", "then"]),
		PackedStringArray(["it", "was", "twothousandnine", "then"]))
	_ok(run == 2, "a mid-way start finds its words, one spelled differently (%d)" % run)
	var near := TabletScript.find_run(PackedStringArray(["sentence", "one", "five", "of", "the", "long",
		"sentence", "two", "five", "of", "the", "long"]), PackedStringArray(["sentence", "two", "five", "of", "the", "long"]))
	_ok(near == 6, "a mid-way start lands on the run that matches best, not an earlier near miss (%d)" % near)
	var comma := TabletScript.find_run(PackedStringArray(["x", "our", "host", "is", "dionysus", "", "the", "god"]),
		PackedStringArray(["our", "host", "is", "dionysus", "the", "god"]))
	_ok(comma == 1, "a mid-way start is found across the comma after a link, a word with no letters (%d)" % comma)
	var om := TabletScript.speakable("<!-- url: a.test -->\n\nOne. <!-- outro --> Two.\n\n<!-- outro -->\n\nThree.\n")
	_ok(om.count("<!-- outro -->") == 2, "the outro mark reaches the voice, inline or on its own line")

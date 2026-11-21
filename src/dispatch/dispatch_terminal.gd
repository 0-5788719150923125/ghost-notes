extends RefCounted
class_name DispatchTerminal

## DispatchTerminal - the dispatch desk's terminal: one program on a fixed screen, worked by ```terminal blocks
## (next/dispatch.md). Every line of a block is one thing that happens on the glass, in order.
##
## The glass is [constant COLUMNS] by [constant ROWS], never a scrolling shell: row 1 the program's title (inverse) and the
## panel's name, row 2 the panel's second line, a blank, [constant BODY_ROWS] rows of body (drawn a line at a time; when it
## is full the body alone scrolls), a blank, the panel's keys spaced evenly, and the command line `> `. A panel is `width`
## columns wide, set in the middle of the glass.
##
## The note's top-level `terminal:` block holds what every panel shares: `title`, `width`, and `keys` (a key -> a kept
## panel's id; an id ending in `*` is a series: with `r: record-*`, `> r` opens record-1 and `> r 4` record-4). In a block:
##
##     > words                    typed on the command line a key at a time, entered and cleared. It opens the panel
##                                written on the next line; else what it is bound to - the panel up's keys, then the
##                                frontmatter's (a digit too); `> open ID` a kept panel. Nothing: INVALID OPTION, warned.
##                                `> words {2}`: held two seconds typed, before it is entered
##     panel: id = NAME | L | R   a new panel replacing the glass, rows 1 and 2 at once, then the lines after it down the
##                                body; with an id it is kept, and comes back as it last stood. `NAME`, `NAME | L` too
##     panel: id                  a kept panel opened again, its body drawn down the glass
##     keys: N NEXT > id, X MENU  the panel's keys, on its keys row; `> id` binds the key to a kept panel
##     type: words                typed into the body and said behind the keys ([DispatchScript]), wrapped at the width; lines
##                                of it one straight after another, in one voice, are one passage typed on and read through.
##                                One that names an option on the panel (`type: [D]` under `[D] ALL OF THE ABOVE`) chooses it:
##                                typed on the command line and entered, that row shown in inverse - thought over first, kept
##                                in sight after
##     type (Name): words         ...said in that voice
##     read: words                typed into the body by the other side of the glass (the target on the mirror) and read
##                                aloud by the room behind the keys, as `type:` is said; never the room's typing, so never
##                                printed or struck. `read (Name):` read in that voice
##     key: words                 typed into the body quickly and never said; a block's last ones that the paragraph
##                                straight after it says are typed ahead of those words instead ([method
##                                DispatchScript.said_keys]), the voice reading behind the keys
##     show: words                drawn down the body, wrapped at the width
##     set: LABEL ... VALUE       the body row beginning LABEL becomes this line: what differs backspaced, typed again.
##                                Straight after the panel is come back to (`> 3`, then its `set:` lines) the row is
##                                there as the panel is drawn, never typed again: it comes back as it now stands
##     select: LABEL              the arrow keys move a bar in inverse over the panel's items ([method items_of]) from where
##                                it was left (else the first) to the one beginning LABEL, a press an item; Enter then opens
##                                the panel written on the next line (none: the bar stays where it stopped, no Enter)
##     wait: 2                    two seconds on what is up, in place of the read
##     alert: line | line         a box over the panel, with the terminal's beep; gone at the next command or panel
##     crash: words               the program dies: the whole glass the screen's color, the words in black at its middle,
##                                every panel gone, until a panel is drawn again or the screen wakes from sleep.
##                                `crash (Name): words` - that voice says them over it
##     print, strike, clear       the printer; the last typed line backspaced away; the body emptied
##     <!-- static: 4 -->         any desk mark, at that point of the block
##     # words                    a note
##     anything else              a body line as written; `{2}` in it stops the drawing there for two seconds, and a run
##                                of dots just before it fills over those seconds as a progress bar ([method _filled])
##
## After a panel is drawn the operator reads it before the next step ([method read_of]: a new one by its words, one come back
## to a glance), unless a `wait:` says how long; lines drawn onto a panel already up are read the same way, silently, at a
## reader's pace ([constant READ_DRAWN]) - an answer is taken in before it is answered. The voice waits for a block's steps and comes back at its end, the last
## panel still being read.
##
## The glass is simulated through the whole note as it is parsed ([method compile], [method typed], [method struck]), so each
## action at the terminal carries the glass it starts from, and the medium draws a moment by playing that action's own steps
## ([method at]) and setting the rows ([method rows_of]).

## The glass: columns and rows; the body's first row and how many; the keys row and the command line (0-based rows).
const COLUMNS := 70
const ROWS := 22
## How much of a character's cell its glyph lights, and the share of the screen's cells lit that is as bright as the screen gets
## ([method lit_share]: a panel full of text).
const LIT_GLYPH := 0.25
const LIT_FULL := 0.22
const BODY_TOP := 3
const BODY_ROWS := 16
const KEYS_ROW := 20
const COMMAND_ROW := 21
## A panel's width when the frontmatter gives none.
const WIDTH := 65
const PROMPT := "> "
## A block's steps (seconds): a sleeping screen waking; the cursor waiting on the command line before the first key; a key,
## give or take KEY_JITTER of it, a space SPACE_MORE longer; Enter after the last; the program answering; a body line drawn.
const WAKE := 0.6
const PROMPT_WAIT := 0.6
const KEY_EACH := 0.1
const KEY_JITTER := 0.45
const SPACE_MORE := 1.35
const ENTER_AFTER := 0.25
const ANSWER_AFTER := 0.45
const LINE_EACH := 0.06
## A `key:` line (and a row changed by `set:`): a key this long, give or take, the whole line typed in KEY_LINE_MOST at most.
const KEY_LINE := 0.06
const KEY_LINE_MOST := 7.0
## A panel read before the next step: a new one READ_LEAST and READ_WORD a word, at most READ_MOST; one come back to, a
## glance. An alert, the same way.
## How long the operator thinks over the options of a panel before choosing one, past reading it (s), and how long the choice
## stays in sight before what follows ([method choice_row]).
const CHOICE_THINK := 1.5
const CHOICE_HOLD := 1.8
const READ_LEAST := 1.0
const READ_WORD := 0.1
const READ_MOST := 5.0
const KNOWN_LOOK := 0.8
## Lines drawn onto a panel already up (`show:`, a body line) are read before the next key or command, silently: READ_LEAST
## and READ_DRAWN a word, at most READ_DRAWN_MOST - long enough to take in an answer before it is answered.
const READ_DRAWN := 0.2
const READ_DRAWN_MOST := 9.0
const ALERT_LEAST := 1.2
const ALERT_WORD := 0.15
## A `set:` backspaces this many characters a second.
const BACKSPACE := 28.0
## A `select:` (s): the bar up on the item it starts from this long before the first arrow key; an arrow key a press, give or
## take KEY_JITTER of it (each item glanced at as it passes); the item chosen looked at this long before Enter.
const SELECT_FIRST := 0.5
const SELECT_EACH := 0.32
const SELECT_HOLD := 0.7
## The voice comes back this long after a block's last step.
const AFTER := 0.2
## A crash is seen this long before what comes after it.
const CRASH_HOLD := 1.2
## What an alert says when a command opens nothing.
const INVALID := "INVALID OPTION"

## A block's line kinds: group 1 the kind, group 2 a voice (`type (Name):`, `read (Name):`), group 3 the rest.
const LINE_KIND := "^(panel|keys|type|read|key|show|select|set|wait|alert|crash)\\s*(?:\\(\\s*([^)]*?)\\s*\\))?\\s*:\\s?(.*)$"
const BARE_KIND := "^(print|clear|strike)\\b\\s*(?::\\s*(.*))?$"
## A pause inside a body line: `{2}`, a space before it taken with it.
const PAUSE := " ?\\{\\s*([0-9]+(?:\\.[0-9]+)?)\\s*\\}"
## A run of dots before a pause fills as a progress bar: the last dot down at FILL_END of the pause (give or take
## FILL_END_SPREAD), what follows at its end. Each dot waits its own share; a share is a freeze FREEZE_MORE times as long
## FREEZE_CHANCE of the time, or comes with the dot before it BURST_CHANCE of the time.
const FILL_END := 0.88
const FILL_END_SPREAD := 0.07
const FREEZE_CHANCE := 0.12
const FREEZE_MORE := 7.0
const BURST_CHANCE := 0.22
## A kept panel's id, as `panel:` names one.
const ID := "^[a-z0-9][a-z0-9_*-]*$"
## A cell of a body row, as a `select:` reads one: words parted by one or two spaces (three or more part two cells).
const CELL := "\\S+(?: {1,2}\\S+)*"

static var _re := {}


static func _rx(pattern: String) -> RegEx:
	if not _re.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_re[pattern] = r
	return _re[pattern]


## The note's `terminal:` block: `{title, width, keys: {key: id}}` (keys lowered).
static func config_of(body: String) -> Dictionary:
	var data: Variant = FrontMatter.read_block(body, "terminal").get("data", {})
	var d: Dictionary = data if data is Dictionary else {}
	var keys := {}
	var given: Variant = d.get("keys", {})
	if given is Dictionary:
		for k in given as Dictionary:
			keys[String(k).strip_edges().to_lower()] = String((given as Dictionary)[k]).strip_edges().to_lower()
	var width := int(d.get("width", WIDTH)) if str(d.get("width", "")).is_valid_int() else WIDTH
	return {"title": String(d.get("title", "")), "width": clampi(width, 20, COLUMNS), "keys": keys}


## The glass before anything: asleep, no panel.
static func blank() -> Dictionary:
	return {"awake": false, "up": "", "kept": {}, "oneoff": {}, "drawn": -1, "command": "", "alert": PackedStringArray(),
		"cursor": "command", "last_typed": {}}


static func _panel(name: String, left: String, right: String) -> Dictionary:
	return {"id": "", "name": name, "left": left, "right": right, "keys": [], "body": PackedStringArray()}


## The panel up on [param g] ({} for none).
static func up(g: Dictionary) -> Dictionary:
	var id := String(g.get("up", ""))
	if not id.is_empty():
		return (g["kept"] as Dictionary).get(id, {})
	return g.get("oneoff", {})


## [param g] with the panel up its own (a copy), so changing it leaves the glass it came from as it was.
static func _own_up(g: Dictionary) -> Dictionary:
	var id := String(g["up"])
	if not id.is_empty():
		var kept: Dictionary = (g["kept"] as Dictionary).duplicate()
		kept[id] = (kept.get(id, _panel("", "", "")) as Dictionary).duplicate(true)
		g["kept"] = kept
		return kept[id]
	if (g["oneoff"] as Dictionary).is_empty():
		g["oneoff"] = _panel("", "", "")
	else:
		g["oneoff"] = (g["oneoff"] as Dictionary).duplicate(true)
	return g["oneoff"]


## A block's lines as `[{kind: run, lines} | {kind: type, text, voice, theirs} | {kind: line, text}]`: the steps between
## the said lines and the desk marks gathered into runs; `theirs` a `read:` line; `line` a desk mark (or `print`, `strike`)
## for the script to read as its own. Said lines of one kind one straight after another in one voice are one passage, its
## lines parted by line breaks: typed on across each line's end and read straight through. A line naming an option
## ([method option_label]) stands alone, and a strike takes the passage's last line off alone.
static func split(text: String) -> Array:
	var out: Array = []
	var run := PackedStringArray()
	var joins := false                   # the line before was a said line, nothing after it yet
	for raw in text.split("\n"):
		var s := String(raw).rstrip(" \t")
		var m := _rx(LINE_KIND).search(s)
		if m != null and m.get_string(1) in ["type", "read"]:
			var said := m.get_string(3).strip_edges()
			var voice := m.get_string(2).strip_edges()
			var theirs := m.get_string(1) == "read"
			var prev: Dictionary = out.back() if joins else {}
			if not prev.is_empty() and String(prev["voice"]) == voice and bool(prev["theirs"]) == theirs and option_label(said).is_empty() \
					and option_label((prev["lines"] as PackedStringArray)[0]).is_empty():
				var joined: PackedStringArray = prev["lines"]
				joined.append(said)
				prev["lines"] = joined
				prev["text"] = "\n".join(joined)
				continue
			_end_run(out, run)
			out.append({"kind": "type", "text": said, "voice": voice, "theirs": theirs, "lines": PackedStringArray([said])})
			joins = true
			continue
		joins = false
		if m != null and m.get_string(1) == "crash" and not m.get_string(2).strip_edges().is_empty():
			_end_run(out, run)
			out.append({"kind": "crash", "text": m.get_string(3).strip_edges(), "voice": m.get_string(2).strip_edges()})
			continue
		var bare := _rx(BARE_KIND).search(s)
		if bare != null and bare.get_string(1) != "clear":
			_end_run(out, run)
			var whole: Dictionary = out.back() if not out.is_empty() else {}
			if bare.get_string(1) == "strike" and String(whole.get("kind", "")) == "type" and (whole["lines"] as PackedStringArray).size() > 1:
				var lines: PackedStringArray = whole["lines"]
				var last := lines[lines.size() - 1]
				lines.remove_at(lines.size() - 1)
				whole["lines"] = lines
				whole["text"] = "\n".join(lines)
				out.append({"kind": "type", "text": last, "voice": whole["voice"], "theirs": whole["theirs"], "lines": PackedStringArray([last])})
			var arg := bare.get_string(2).strip_edges()
			out.append({"kind": "line", "text": "<!-- %s%s -->" % [bare.get_string(1), (": " + arg) if not arg.is_empty() else ""]})
			continue
		if _rx("^\\s*<!--[\\s\\S]*-->\\s*$").search(s) != null and _rx(DispatchScript.REDACT).search(s) == null:
			_end_run(out, run)
			out.append({"kind": "line", "text": s.strip_edges()})
			continue
		run.append(s)
	_end_run(out, run)
	return out


static func _end_run(out: Array, run: PackedStringArray) -> void:
	var lines := run.duplicate()
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	if not lines.is_empty():
		out.append({"kind": "run", "lines": lines})
	run.clear()


## The steps of a run of [param lines] from glass [param glass], timed: `{ops, rest, len, glass}` - `ops` each `{op, t, ...}`
## (seconds from the run's start), `rest` what the voice waits (its last step done), `len` with the last panel read, `glass`
## the glass after it. What it gets wrong is added to [param warnings].
static func compile(lines: PackedStringArray, glass: Dictionary, cfg: Dictionary, warnings: PackedStringArray) -> Dictionary:
	var g := glass.duplicate(true)
	var width := int(cfg.get("width", WIDTH))
	var ops: Array = []
	var t := 0.0
	var reading := -1.0                  # a panel just drawn: how long it is read before the next step (-1 none)
	var known := false                   # ...it was come back to
	var came_back := -1                  # the step that brought a kept panel back, nothing done on it since (-1 none)
	var drawn := 0                       # words drawn onto a panel already up, not read yet
	var steps := 0
	if not bool(g["awake"]):
		t = _step(g, ops, {"op": "wake", "t": t}, t) + WAKE
	for k in lines.size():
		var s := String(lines[k])
		var st := s.strip_edges()
		if st == "#" or st.begins_with("# "):
			continue
		var m := _rx(LINE_KIND).search(s)
		var bare := _rx(BARE_KIND).search(s)
		var kind := m.get_string(1) if m != null else ("clear" if bare != null and bare.get_string(1) == "clear" else "")
		if s.begins_with(">"):
			kind = "command"
		var comes_changed := kind == "set" and came_back >= 0
		if kind != "set":
			came_back = -1
		# a panel just drawn is read before the next step (its own lines, keys and shown words are its drawing; a wait
		# says how long instead; a row it comes back changed with is its drawing too)
		if reading >= 0.0 and not kind in ["", "keys", "show", "wait"] and not comes_changed:
			t += KNOWN_LOOK if known else reading
			reading = -1.0
		# ...and lines drawn onto a panel already up are read before the next key or command
		if drawn > 0 and not kind in ["", "keys", "show"]:
			if kind != "wait":
				t += minf(READ_LEAST + READ_DRAWN * float(drawn), READ_DRAWN_MOST)
			drawn = 0
		match kind:
			"command":
				# `{2}` after it: held that long, typed, before it is entered
				var asked := s.substr(1).strip_edges()
				var held := 0.0
				var pm := _rx(PAUSE).search(asked)
				if pm != null:
					held = float(pm.get_string(1))
					asked = _rx(PAUSE).sub(asked, "", true).strip_edges()
				var typed := DispatchScript.redacted(asked)
				var keys := PackedFloat32Array()
				var c0 := t + PROMPT_WAIT
				var tk := c0
				for c in typed.length():
					var j := DispatchSounds.hash01(hash([typed, k, steps]), c) * 2.0 - 1.0
					var space := typed[c] == " " or typed.unicode_at(c) == DispatchScript.REDACT_BASE + 32
					tk += KEY_EACH * (1.0 + KEY_JITTER * j) * (SPACE_MORE if space else 1.0)
					keys.append(tk)
				var enter := tk + ENTER_AFTER + held
				_step(g, ops, {"op": "command", "t": t, "text": typed, "keys": keys, "enter": enter}, t)
				t = enter + ANSWER_AFTER
				steps += 1
				if _next_is_panel(lines, k):
					continue
				var said := String(DispatchScript.unredacted(typed)["text"])
				var to := _resolve(said, g, cfg)
				if to.is_empty() or not (g["kept"] as Dictionary).has(to):
					warnings.append("terminal: > %s opens nothing%s" % [said, (" (%s is no kept panel)" % to) if not to.is_empty() else ""])
					_step(g, ops, {"op": "alert", "t": t, "lines": PackedStringArray([INVALID])}, t)
					t += ALERT_LEAST
					continue
				t = _reopen(g, ops, to, t)
				came_back = ops.size() - 1
				reading = read_of(up(g), cfg)
				known = true
			"panel":
				var spec := m.get_string(3).strip_edges()
				if _rx(ID).search(spec) != null and not spec.contains("|"):
					if not (g["kept"] as Dictionary).has(spec):
						warnings.append("terminal: panel: %s is no kept panel yet" % spec)
						continue
					t = _reopen(g, ops, spec, t)
					came_back = ops.size() - 1
					reading = read_of(up(g), cfg)
					known = true
					continue
				var id := ""
				var head := spec.get_slice("|", 0)
				if head.contains("="):
					id = head.get_slice("=", 0).strip_edges().to_lower()
					spec = spec.substr(spec.find("=") + 1)
					if _rx(ID).search(id) == null:
						warnings.append("terminal: panel id %s - lower case, digits and dashes" % id)
				var parts := spec.split("|")
				var p := _panel(String(parts[0]).strip_edges(), String(parts[1]).strip_edges() if parts.size() > 1 else "",
					String(parts[2]).strip_edges() if parts.size() > 2 else "")
				p["id"] = id
				_fits(cfg["title"], p["name"], width, warnings, spec)
				_fits(p["left"], p["right"], width, warnings, spec)
				t = _step(g, ops, {"op": "open", "t": t, "id": id, "def": p}, t) + LINE_EACH
				reading = read_of(up(g), cfg)
				known = false
			"keys":
				_step(g, ops, {"op": "keys", "t": t, "keys": keys_of(m.get_string(3))}, t)
				var shown := spread(_labels(up(g)["keys"] as Array), width)
				if shown.length() > width:
					warnings.append("terminal: keys wider than the panel: %s" % m.get_string(3))
			"key":
				var said := DispatchScript.redacted(m.get_string(3).strip_edges())
				var text := "\n".join(wrapped(said, width))
				var times := PackedFloat32Array()
				var pace := minf(KEY_LINE, KEY_LINE_MOST / maxf(float(text.length()), 1.0))
				var tk := t
				for c in text.length():
					tk += pace * (1.0 + KEY_JITTER * (DispatchSounds.hash01(hash([text, k]), c) * 2.0 - 1.0))
					times.append(tk)
				_step(g, ops, {"op": "key", "t": t, "text": text, "times": times}, t)
				t = tk + LINE_EACH
			"show":
				for row in wrapped(DispatchScript.redacted(m.get_string(3).strip_edges()), width):
					t = _line(g, ops, String(row), t, width, warnings)
				if reading >= 0.0:
					reading = read_of(up(g), cfg)
				else:
					drawn += _words(m.get_string(3))
			"set":
				var line := DispatchScript.redacted(m.get_string(3).rstrip(" "))
				var p := up(g)
				var row := find_row(p.get("body", PackedStringArray()), label_of(line))
				if row < 0:
					warnings.append("terminal: set: no row begins %s on %s" % [label_of(line), String(p.get("name", "the glass"))])
					continue
				var old := String((p["body"] as PackedStringArray)[row])
				var lead := old.length() - old.lstrip(" ").length()
				if line.lstrip(" ").length() == line.length():
					line = old.substr(0, lead) + line
				if comes_changed:
					# the panel just come back comes back as it now stands: the row drawn with the rest of it, and read as
					# what is new on it
					var back: Dictionary = ops[came_back]
					var rows: Dictionary = back.get("set", {})
					rows[row] = line
					back["set"] = rows
					var own := _own_up(g)
					var body: PackedStringArray = own["body"]
					body[row] = line
					own["body"] = body
					reading = minf(READ_LEAST + READ_WORD * float(_words(" ".join(PackedStringArray(rows.values())))), READ_MOST)
					known = false
				else:
					t = _set_row(g, ops, row, old, line, t, k)
				if line.length() > width:
					warnings.append("terminal: a line wider than the panel (%d > %d): %s" % [line.length(), width, line.strip_edges()])
			"select":
				var label := m.get_string(3).strip_edges()
				var body: PackedStringArray = up(g).get("body", PackedStringArray())
				var items := items_of(body)
				var to := item_of(body, items, label)
				if to < 0:
					warnings.append("terminal: select: no item begins %s on %s" % [label, String(up(g).get("name", "the glass"))])
					continue
				var from := maxi(items.find(up(g).get("chosen")), 0)
				var path := PackedInt32Array([from])
				var presses := PackedFloat32Array()
				var tk := t + SELECT_FIRST
				while path[path.size() - 1] != to:
					path.append(path[path.size() - 1] + signi(to - from))
					presses.append(tk)
					tk += SELECT_EACH * (1.0 + KEY_JITTER * (DispatchSounds.hash01(hash([label, k]), presses.size()) * 2.0 - 1.0))
				var last := presses[presses.size() - 1] if not presses.is_empty() else t + SELECT_FIRST
				var opens := _next_is_panel(lines, k)
				var enter := last + SELECT_HOLD if opens else -1.0
				_step(g, ops, {"op": "select", "t": t, "items": items, "path": path, "presses": presses, "enter": enter}, t)
				t = enter + ANSWER_AFTER if opens else last + LINE_EACH
				steps += 1
			"wait":
				var secs := m.get_string(3).strip_edges()
				if not secs.is_valid_float():
					warnings.append("terminal: wait: %s is no number of seconds" % secs)
					continue
				reading = -1.0
				_step(g, ops, {"op": "wait", "t": t, "d": float(secs)}, t)
				t += clampf(float(secs), 0.0, 60.0)
			"alert":
				var said := PackedStringArray()
				for part in m.get_string(3).split("|"):
					said.append(String(part).strip_edges())
				_step(g, ops, {"op": "alert", "t": t, "lines": said}, t)
				t += ALERT_LEAST + ALERT_WORD * float(_words(" ".join(said)))
			"crash":
				reading = -1.0
				drawn = 0
				t = _step(g, ops, {"op": "crash", "t": t, "text": DispatchScript.redacted(m.get_string(3).strip_edges())}, t) + CRASH_HOLD
			"clear":
				_step(g, ops, {"op": "clear", "t": t}, t)
			_:
				t = _line(g, ops, DispatchScript.redacted(s), t, width, warnings)
				if reading >= 0.0:
					reading = read_of(up(g), cfg)
				else:
					drawn += _words(s)
	var rest := t + AFTER
	var last := read_of(up(g), cfg) if reading >= 0.0 else 0.0
	return {"ops": ops, "rest": rest, "len": rest + last, "glass": g}


## Is the next line of [param lines] after [param k] (notes passed over) a panel's?
static func _next_is_panel(lines: PackedStringArray, k: int) -> bool:
	for j in range(k + 1, lines.size()):
		var s := String(lines[j]).strip_edges()
		if s.is_empty() or s == "#" or s.begins_with("# "):
			continue
		var m := _rx(LINE_KIND).search(String(lines[j]))
		return m != null and m.get_string(1) == "panel"
	return false


## A step added to [param ops] and played onto [param g]: returns its time.
static func _step(g: Dictionary, ops: Array, op: Dictionary, t: float) -> float:
	ops.append(op)
	var after := at(g, [op], INF)
	g.merge(after, true)
	return t


## A kept panel opened again: its header at once, its body drawn down the glass (its step's `set`, the rows it comes back
## changed with). Returns when it is drawn.
static func _reopen(g: Dictionary, ops: Array, id: String, t: float) -> float:
	var rows := ((g["kept"] as Dictionary)[id]["body"] as PackedStringArray).size()
	_step(g, ops, {"op": "open", "t": t, "id": id, "rows": rows}, t)
	return t + LINE_EACH * float(rows)


## A body line drawn: what comes before each `{N}` first, the rest after its pause. Returns when it is drawn.
static func _line(g: Dictionary, ops: Array, raw: String, t: float, width: int, warnings: PackedStringArray) -> float:
	var text := ""
	var segs: Array = []                  # [shown up to this column, from this many seconds into the line]
	var at := 0
	var pause := 0.0
	for m in _rx(PAUSE).search_all(raw):
		var from := text.length()
		text += raw.substr(at, m.get_start() - at)
		var held := float(m.get_string(1))
		segs.append_array(_filled(text, from, pause, held, hash([raw, segs.size()])))
		pause += held
		at = m.get_end()
	text += raw.substr(at)
	segs.append([text.length(), pause])
	if text.length() > width:
		warnings.append("terminal: a line wider than the panel (%d > %d): %s" % [text.length(), width, text.strip_edges()])
	_step(g, ops, {"op": "line", "t": t, "text": text, "segs": segs}, t)
	return t + pause + LINE_EACH


## The steps of a body line drawn up to [param text]'s end from column [param from], [param start] seconds into the line,
## with a pause of [param held] after it: `[column, seconds]` each. A run of dots ending it is drawn a dot at a time across
## the pause, unevenly - spurts, freezes, a dot or two at once - by [param salt]; else the whole of it at once.
static func _filled(text: String, from: int, start: float, held: float, salt: int) -> Array:
	var m := _rx("\\.{2,}$").search(text.substr(from))
	if m == null or held <= 0.0:
		return [[text.length(), start]]
	var first := from + m.get_start()
	var n := text.length() - first
	var waits := PackedFloat32Array()
	var sum := 0.0
	for k in n:
		var w := 0.35 + DispatchSounds.hash01(salt, k)
		var roll := DispatchSounds.hash01(salt, k + 1000)
		if k > 0 and roll < BURST_CHANCE:
			w = 0.0
		elif roll > 1.0 - FREEZE_CHANCE:
			w *= FREEZE_MORE
		waits.append(w)
		sum += w
	var span := held * (FILL_END + FILL_END_SPREAD * (DispatchSounds.hash01(salt, -1) * 2.0 - 1.0))
	var out: Array = [[first, start]]
	var t := 0.0
	for k in n:
		t += waits[k] / maxf(sum, 1e-6) * span
		out.append([first + k + 1, start + t])
	return out


## A row changed in place: from where the two differ to where they agree again, the old backspaced (from its end back) and
## the new typed at a `key:` line's pace. Returns when it is done.
static func _set_row(g: Dictionary, ops: Array, row: int, old: String, new: String, t: float, salt: int) -> float:
	var p := 0
	while p < old.length() and p < new.length() and old[p] == new[p]:
		p += 1
	var s := 0
	while s < old.length() - p and s < new.length() - p and old[old.length() - 1 - s] == new[new.length() - 1 - s]:
		s += 1
	var gone := old.length() - p - s
	var put := new.length() - p - s
	var back := PackedFloat32Array()
	var tk := t + PROMPT_WAIT * 0.5
	for c in gone:
		tk += 1.0 / BACKSPACE
		back.append(tk)
	var keys := PackedFloat32Array()
	for c in put:
		tk += KEY_LINE * (1.0 + KEY_JITTER * (DispatchSounds.hash01(hash([new, salt]), c) * 2.0 - 1.0))
		keys.append(tk)
	_step(g, ops, {"op": "set", "t": t, "row": row, "old": old, "new": new, "p": p, "s": s, "back": back, "keys": keys}, t)
	return tk + LINE_EACH


## The glass [param glass] [param r] seconds into [param ops] (INF: all of them). [param whole]: a redacted run being typed
## is there whole from its first key, where the censor's box goes up.
static func at(glass: Dictionary, ops: Array, r: float, whole := false) -> Dictionary:
	var g := glass.duplicate()
	for o in ops:
		var op: Dictionary = o
		var t := float(op["t"])
		if t > r:
			break
		match String(op["op"]):
			"wake":
				g["awake"] = true
				g.erase("crash")
			"command":
				var text := String(op["text"])
				var n := _typed_n(op["keys"], r, text, whole)
				g["command"] = text.substr(0, n) if r < float(op["enter"]) else ""
				g["alert"] = PackedStringArray()
				g["cursor"] = "command"
			"open":
				g["alert"] = PackedStringArray()
				g["cursor"] = "command"
				g.erase("crash")
				var id := String(op["id"])
				if op.has("def"):
					var p: Dictionary = (op["def"] as Dictionary).duplicate(true)
					if id.is_empty():
						g["oneoff"] = p
					else:
						var kept: Dictionary = (g["kept"] as Dictionary).duplicate()
						kept[id] = p
						g["kept"] = kept
					g["up"] = id
					g["drawn"] = -1
				else:
					g["up"] = id
					# the rows it comes back changed with (`{row: line}`), there as it is drawn
					if op.has("set"):
						var p := _own_up(g)
						var body: PackedStringArray = p["body"]
						for row in op["set"]:
							if int(row) < body.size():
								body[int(row)] = String(op["set"][row])
						p["body"] = body
					var rows := int(op["rows"])
					var n := clampi(int(floor((r - t) / LINE_EACH)) + 1, 0, rows) if r < INF else rows
					g["drawn"] = -1 if n >= rows else n
			"keys":
				_own_up(g)["keys"] = op["keys"]
			"line":
				var text := String(op["text"])
				var shown := text
				for sg in op["segs"]:
					if t + float((sg as Array)[1]) > r:
						break
					shown = text.substr(0, int((sg as Array)[0]))
				if t + float(((op["segs"] as Array)[0] as Array)[1]) <= r:
					var p := _own_up(g)
					var body: PackedStringArray = p["body"]
					body.append(shown)
					p["body"] = body
			"key":
				var text := String(op["text"])
				var n := _typed_n(op["times"], r, text, whole)
				var p := _own_up(g)
				var body: PackedStringArray = p["body"]
				body.append_array(text.substr(0, n).split("\n"))
				p["body"] = body
				g["cursor"] = "body" if n < text.length() else "command"
			"set":
				var p := _own_up(g)
				var body: PackedStringArray = p["body"]
				var row := int(op["row"])
				if row < body.size():
					var old := String(op["old"])
					var new := String(op["new"])
					var pre := int(op["p"])
					var suf := int(op["s"])
					var back: PackedFloat32Array = op["back"]
					var keys: PackedFloat32Array = op["keys"]
					var gone := 0
					while gone < back.size() and back[gone] <= r:
						gone += 1
					var put := _typed_n(keys, r, new.substr(pre, new.length() - pre - suf), whole)
					var mid := old.substr(pre, back.size() - gone) if put == 0 else new.substr(pre, put)
					body[row] = old.substr(0, pre) + mid + old.substr(old.length() - suf)
					if put >= keys.size() and gone >= back.size():
						body[row] = new
					p["body"] = body
					g["cursor"] = "command"
			"select":
				var presses: PackedFloat32Array = op["presses"]
				var n := 0
				while n < presses.size() and presses[n] <= r:
					n += 1
				_own_up(g)["chosen"] = (op["items"] as Array)[(op["path"] as PackedInt32Array)[n]]
				g["alert"] = PackedStringArray()
				g["cursor"] = "command"
			"alert":
				g["alert"] = op["lines"]
			"crash":
				g["crash"] = String(op["text"])
				g["alert"] = PackedStringArray()
				g["command"] = ""
			"clear":
				_own_up(g)["body"] = PackedStringArray()
	return g


## How many of [param text]'s characters are typed [param r] seconds in, each at its moment in [param times]; [param whole]
## runs a redacted run being typed to its end.
static func _typed_n(times: PackedFloat32Array, r: float, text: String, whole: bool) -> int:
	var n := 0
	while n < times.size() and times[n] <= r:
		n += 1
	while whole and n > 0 and n < text.length() and DispatchScript.is_redacted(text.unicode_at(n - 1)) \
			and DispatchScript.is_redacted(text.unicode_at(n)):
		n += 1
	return mini(n, text.length())


## The glass [param glass] with the first [param n] characters of a said line [param text] (wrapped, its rows on lines)
## typed under the panel up; all of it noted as the line last typed, which a strike takes away. A line naming an option on the
## panel ([method choice_row]) is typed on the command line instead and, entered, chooses that row: shown in inverse.
static func typed(glass: Dictionary, text: String, n: int) -> Dictionary:
	var choice := choice_row(glass, text)
	if choice >= 0:
		var gc := glass.duplicate()
		var pc := _own_up(gc)
		gc["cursor"] = "command"
		if n < text.length():
			gc["command"] = text.substr(0, maxi(n, 0))
		else:
			gc["command"] = ""
			var row := String((pc["body"] as PackedStringArray)[choice])
			pc["chosen"] = Vector3i(choice, row.length() - row.lstrip(" ").length(), row.rstrip(" ").length())
		return gc
	var g := glass.duplicate()
	var p := _own_up(g)
	var body: PackedStringArray = p["body"]
	var from := body.size()
	var shown := text.substr(0, clampi(n, 0, text.length()))
	if not shown.is_empty():
		body.append_array(shown.split("\n"))
	p["body"] = body
	g["cursor"] = "body"
	if n >= text.length():
		g["cursor"] = "command"
		g["last_typed"] = {"up": g["up"], "from": from, "rows": text.split("\n").size()}
	return g


## The glass [param glass] with the line last typed [param u] of the way backspaced off it (1: gone, and nothing left to
## strike).
static func struck(glass: Dictionary, u: float) -> Dictionary:
	var g := glass.duplicate()
	var last: Dictionary = g.get("last_typed", {})
	if last.is_empty() or String(last["up"]) != String(g["up"]):
		return g
	var p := _own_up(g)
	var body: PackedStringArray = p["body"]
	var from := int(last["from"])
	var rows := mini(int(last["rows"]), body.size() - from)
	if rows <= 0:
		return g
	var text := "\n".join(body.slice(from, from + rows))
	var keep := text.substr(0, int(round((1.0 - clampf(u, 0.0, 1.0)) * float(text.length()))))
	var out := body.slice(0, from)
	if not keep.is_empty():
		out.append_array(keep.split("\n"))
	out.append_array(body.slice(from + rows))
	p["body"] = out
	g["cursor"] = "body" if u < 1.0 else "command"
	if u >= 1.0:
		g["last_typed"] = {}
	return g


## How much of the glass is lit in screen [param st] ([method DispatchMedium.terminal_at]'s: its lines, its inverse bar, its
## alert's box), 0 dark to 1 a panel full of text: each character's cell a quarter lit by its glyph ([constant LIT_GLYPH]), the
## bar's cells three quarters by their inverse, over [constant LIT_FULL] of the screen - what the screen throws on the desk.
static func lit_share(st: Dictionary) -> float:
	if bool(st.get("asleep", true)):
		return 0.0
	if not String(st.get("crash", "")).is_empty():
		return 1.0
	var lit := 0.0
	for line in (st.get("lines", PackedStringArray()) as PackedStringArray):
		lit += float(String(line).replace(" ", "").length()) * LIT_GLYPH
	var bar: Variant = st.get("bar")
	if bar is Vector2i and (bar as Vector2i).x >= 0:
		lit += float((bar as Vector2i).y - (bar as Vector2i).x) * (0.75 - LIT_GLYPH)
	var pick: Variant = st.get("chosen")
	if pick is Vector3i and (pick as Vector3i).x >= 0:
		lit += float((pick as Vector3i).z - (pick as Vector3i).y) * (0.75 - LIT_GLYPH)
	for line in (st.get("alert", PackedStringArray()) as PackedStringArray):
		lit += float(String(line).length() + 4) * LIT_GLYPH
	return clampf(lit / (float(COLUMNS * ROWS) * LIT_FULL), 0.0, 1.0)


## The option a typed [param text] would name, bracketed (`[D]` for `[D]` or `d`), or "" for a line shaped like none.
static func option_label(text: String) -> String:
	var t := text.strip_edges().to_upper()
	if t.is_empty() or t.contains("\n") or t.length() > 5:
		return ""
	var label := t if t.begins_with("[") else "[%s]" % t
	return label if _rx("^\\[[^\\]\\s]{1,3}\\]$").search(label) != null else ""


## The body row of the panel up on [param glass] that a typed [param text] chooses - an option row beginning with its bracketed
## label (`[D] ALL OF THE ABOVE` for `[D]` or `D`), the last such - or -1 where it names none.
static func choice_row(glass: Dictionary, text: String) -> int:
	var label := option_label(text)
	if label.is_empty():
		return -1
	var p := up(glass)
	if p.is_empty():
		return -1
	var body: PackedStringArray = p.get("body", PackedStringArray())
	for i in range(body.size() - 1, -1, -1):
		var row := String(body[i]).strip_edges().to_upper()
		if row.begins_with(label) and row.length() > label.length():
			return i
	return -1


## The items a `select:` moves its bar over on [param body]: each row cut into cells where three or more spaces part its words,
## as `Vector3i(row, first column, last column)`, down the first cells of the rows, then down the second (a table of two
## columns read as a list).
static func items_of(body: PackedStringArray) -> Array:
	var columns: Array = []
	for row in body.size():
		var c := 0
		for m in _rx(CELL).search_all(String(body[row])):
			if columns.size() <= c:
				columns.append([])
			(columns[c] as Array).append(Vector3i(row, m.get_start(), m.get_end()))
			c += 1
	var out: Array = []
	for col in columns:
		out.append_array(col)
	return out


## The item of [param items] on [param body] that begins with [param label] followed by a space, a dot or its end; -1 for none.
static func item_of(body: PackedStringArray, items: Array, label: String) -> int:
	for i in items.size():
		var it: Vector3i = items[i]
		var cell := String(body[it.x]).substr(it.y, it.z - it.y)
		if not label.is_empty() and cell.begins_with(label) and (cell.length() == label.length() or cell[label.length()] in [" ", "."]):
			return i
	return -1


## The glass [param g] as its rows: `{lines (ROWS of them, the panel set in the middle), crash (the words of a crash, the
## glass nothing else; "" for none), bar: Vector2i (row 1's columns,
## inverse), chosen: Vector3i (a chosen option's row, or the cell a `select:` bar is on, and its first and last columns,
## inverse; row -1 none), cursor: Vector2i
## (column, row), alert: PackedStringArray}`.
static func rows_of(g: Dictionary, cfg: Dictionary) -> Dictionary:
	var width := int(cfg.get("width", WIDTH))
	var pad := maxi(0, (COLUMNS - width) / 2)
	var lines := PackedStringArray()
	lines.resize(ROWS)
	var p := up(g)
	var bar := Vector2i(-1, -1)
	var chosen := Vector3i(-1, 0, 0)
	var body_end := BODY_TOP
	var last_row := ""
	if not p.is_empty():
		lines[0] = _ends(String(cfg.get("title", "")), String(p["name"]), width)
		lines[1] = _ends(String(p["left"]), String(p["right"]), width)
		if not String(p["name"]).is_empty() or not String(cfg.get("title", "")).is_empty():
			bar = Vector2i(pad, pad + width)
		var body: PackedStringArray = p["body"]
		var drawn := int(g.get("drawn", -1))
		var shown := body.slice(0, drawn) if drawn >= 0 else body
		var from := maxi(0, shown.size() - BODY_ROWS)
		for k in range(from, shown.size()):
			lines[BODY_TOP + k - from] = shown[k]
		var pick: Variant = p.get("chosen")
		if pick is Vector3i and (pick as Vector3i).x >= from and (pick as Vector3i).x < shown.size():
			chosen = Vector3i(BODY_TOP + (pick as Vector3i).x - from, pad + (pick as Vector3i).y, pad + (pick as Vector3i).z)
		body_end = BODY_TOP + shown.size() - from
		last_row = String(shown[shown.size() - 1]) if not shown.is_empty() else ""
		lines[KEYS_ROW] = spread(_labels(p["keys"] as Array), width)
	lines[COMMAND_ROW] = PROMPT + String(g.get("command", ""))
	var lead := " ".repeat(pad)
	for k in ROWS:
		lines[k] = (lead + String(lines[k])).substr(0, COLUMNS) if not String(lines[k]).is_empty() else ""
	var cursor := Vector2i(pad + PROMPT.length() + String(g.get("command", "")).length(), COMMAND_ROW)
	if String(g.get("cursor", "command")) == "body":
		cursor = Vector2i(pad + last_row.length(), maxi(body_end - 1, BODY_TOP))
	return {"lines": lines, "bar": bar, "chosen": chosen, "cursor": cursor, "alert": g.get("alert", PackedStringArray()),
		"crash": String(g.get("crash", ""))}


## How long the operator reads panel [param p] before going on: [constant READ_LEAST] and [constant READ_WORD] a word on it,
## at most [constant READ_MOST].
static func read_of(p: Dictionary, cfg: Dictionary) -> float:
	if p.is_empty():
		return READ_LEAST
	return minf(READ_LEAST + READ_WORD * float(words_on(p, cfg)), READ_MOST)


## The words on panel [param p]: its header and body (a run of dots is no word).
static func words_on(p: Dictionary, cfg: Dictionary) -> int:
	var text := " ".join([String(cfg.get("title", "")), String(p.get("name", "")), String(p.get("left", "")), String(p.get("right", ""))])
	return _words(text + " " + " ".join(p.get("body", PackedStringArray())))


static func _words(text: String) -> int:
	var n := 0
	for m in _rx("\\S+").search_all(text):
		if _rx("[A-Za-z0-9]").search(m.get_string()) != null:
			n += 1
	return n


## Where a command [param typed] goes on glass [param g] with no panel written after it: a kept panel's id, "" for nowhere.
## `open ID`; else its first word as a key of the panel up, then of the frontmatter (a series `id-*` takes the second word,
## or 1).
static func _resolve(typed: String, g: Dictionary, cfg: Dictionary) -> String:
	var words := typed.strip_edges().to_lower()
	if words.begins_with("open "):
		return words.substr(5).strip_edges()
	var head := words.get_slice(" ", 0)
	var arg := words.get_slice(" ", 1).strip_edges() if words.contains(" ") else ""
	for k in up(g).get("keys", []):
		var key: Dictionary = k
		if String(key["key"]).to_lower() == head and not String(key["to"]).is_empty():
			return String(key["to"])
	var keys: Dictionary = cfg.get("keys", {})
	if keys.has(head):
		var to := String(keys[head])
		if to.ends_with("*"):
			to = to.trim_suffix("*") + (arg if not arg.is_empty() else "1")
		return to
	return ""


## A `keys:` line's keys: `[{key, label, to}]` - each part's first word the key, the rest its label, `> id` what it opens.
static func keys_of(line: String) -> Array:
	var out: Array = []
	for part in line.split(",", false):
		var s := String(part).strip_edges()
		var to := ""
		if s.contains(">"):
			to = s.get_slice(">", 1).strip_edges().to_lower()
			s = s.get_slice(">", 0).strip_edges()
		if s.is_empty():
			continue
		out.append({"key": s.get_slice(" ", 0), "label": s, "to": to})
	return out


static func _labels(keys: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for k in keys:
		out.append(String((k as Dictionary)["label"]))
	return out


## [param labels] spread evenly across [param width] columns, the first at the left edge and the last at the right.
static func spread(labels: PackedStringArray, width: int) -> String:
	if labels.is_empty():
		return ""
	if labels.size() == 1:
		return labels[0]
	var total := 0
	for l in labels:
		total += String(l).length()
	var room := width - total
	if room < labels.size() - 1:
		return " ".join(labels)
	var out := ""
	var gaps := labels.size() - 1
	for k in labels.size():
		out += labels[k]
		if k < gaps:
			out += " ".repeat(room / gaps + (1 if k < room % gaps else 0))
	return out


## [param left] at the left of [param width] columns and [param right] at the right (the left cut where they would meet).
static func _ends(left: String, right: String, width: int) -> String:
	if right.is_empty():
		return left.substr(0, width)
	var room := width - right.length() - 1
	if room <= 0:
		return right.substr(0, width)
	var l := left.substr(0, room)
	return l + " ".repeat(width - l.length() - right.length()) + right


static func _fits(left: String, right: String, width: int, warnings: PackedStringArray, spec: String) -> void:
	if left.length() + right.length() + (1 if not left.is_empty() and not right.is_empty() else 0) > width:
		warnings.append("terminal: a header wider than the panel: %s" % spec)


## A `set:` line's label: what comes before its first run of dots (or two spaces), trimmed.
static func label_of(line: String) -> String:
	var s := line.strip_edges()
	var m := _rx(" ?\\.{2,}|  ").search(s)
	return s.substr(0, m.get_start()).strip_edges() if m != null else s


## The row of [param body] that begins (past its indent) with [param label] followed by a space or a dot; -1 for none.
static func find_row(body: PackedStringArray, label: String) -> int:
	if label.is_empty():
		return -1
	for k in body.size():
		var row := String(body[k]).lstrip(" ")
		if row.begins_with(label) and (row.length() == label.length() or row[label.length()] in [" ", "."]):
			return k
	return -1


## [param text]'s lines wrapped at words to [param width] columns (a word longer than a line is cut). A redacted space is no
## place to wrap ([constant DispatchScript.REDACT_BASE]), so a redacted run stays on one line.
static func wrapped(text: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var s := String(line)
		if s.length() <= width:
			out.append(s)
			continue
		var cur := ""
		for w in s.split(" ", true):
			var word := String(w)
			while word.length() > width:
				if not cur.is_empty():
					out.append(cur)
					cur = ""
				out.append(word.substr(0, width))
				word = word.substr(width)
			if cur.is_empty():
				cur = word
			elif cur.length() + 1 + word.length() <= width:
				cur += " " + word
			else:
				out.append(cur)
				cur = word
		out.append(cur)
	return out

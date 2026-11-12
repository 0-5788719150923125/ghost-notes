extends RefCounted
class_name FrontMatter

## FrontMatter - YAML frontmatter on a Markdown document, read and (carefully) written.
##
## A reading's script lives in a real file the author edits in their own editor (see [DocSource]). Two things
## pass between the document and the panel:
##
##   The body: everything after the frontmatter. [method split] cuts the frontmatter off before a word reaches
##   the voice.
##
##   The voice: ghost writes every dial (reader, tone, room, the cast of a multi-speaker chapter) back into the
##   frontmatter under one key of its own, so a document sounds the same tomorrow.
##
## The write is the dangerous half, because the file is the author's work and often open in their editor at the
## same time. Four rules, enforced in [method write_block] for the voice and mirrored in [method write_body]
## for the words written in ghost's own editor:
##
##   1. Never from a cache: the file is re-read from disk immediately before the edit.
##   2. One key, textually: line surgery on our own top-level key; nothing else in the frontmatter is
##      re-serialized, so a comment, quoting style, key order or unparseable construct survives.
##   3. Verify before committing: [method _verify] re-splits the proposed text and requires the body to be
##      byte-identical and every foreign frontmatter line unchanged; a mismatch aborts with an error.
##   4. Atomic: the new text goes to a sibling temp file, is read back, then renamed over the original.
##
## Nothing here touches the scene tree, so [code]tests/notes/doc_source_check.gd[/code] holds all of it headless.

const MiniYaml_ := preload("res://src/data/yaml.gd")

## The one top-level frontmatter key ghost owns. Nothing outside it is ever touched.
const KEY := "ghost"
## Suffix for the temp file rule 4 renames from. Beside the original, because a rename is only atomic within
## one filesystem.
const TEMP_SUFFIX := ".ghost-tmp"
## Heads the reason [method write_body] gives when the file moved under the editor, so the caller can tell
## "someone else edited this" from "the write failed".
const CONFLICT := "conflict: "


## Cut [param raw] into its frontmatter and its body.
##
## Strict on purpose: a document has frontmatter only when its very first line is exactly `---` and a later
## line is exactly `---` or `...`; an unterminated opening fence is a document with no frontmatter. A looser
## rule would eat the prose above a horizontal rule.
##
## Returns [code]{has, head, body, open, close, nl, bom}[/code]: [code]head[/code] is the frontmatter without
## its fences, [code]body[/code] everything after the closing one, [code]open[/code]/[code]close[/code] the
## fence line indices (-1 when none), [code]nl[/code] the document's line ending, [code]open_fence[/code]/
## [code]fence[/code] the two fence lines verbatim, and [code]bom[/code] whether it opened with a byte-order mark.
static func split(raw: String) -> Dictionary:
	var nl := "\r\n" if raw.contains("\r\n") else "\n"
	#A literal U+feff in GDScript source is stripped from exported scripts, making begins_with("") true for
	#every note and eating the first '-' of its fence.
	var bom := not raw.is_empty() and raw.unicode_at(0) == 0xFEFF
	var text := raw.substr(1) if bom else raw
	var lines := _lines(text)
	var out := {"has": false, "head": "", "body": text, "open": -1, "close": -1,
		"nl": nl, "bom": bom, "open_fence": "---", "fence": "---"}
	if lines.is_empty() or lines[0].strip_edges() != "---":
		return out
	for i in range(1, lines.size()):
		var t: String = lines[i].strip_edges()
		if t == "---" or t == "...":
			out.has = true
			out.open = 0
			out.close = i
			out.open_fence = String(lines[0])
			out.fence = String(lines[i])
			out.head = nl.join(lines.slice(1, i))
			out.body = nl.join(lines.slice(i + 1))
			return out
	return out


## Everything the document says about the voice: the value of our own key, or an empty dictionary when there
## is none.
##
## One key, textually, the mirror of rule 2: [MiniYaml] reads a documented subset and rejects the rest, which
## is wrong for a document ghost is a guest in (`summary: |` is ordinary frontmatter). Only our own key's lines
## are cut out and parsed, so nothing elsewhere in the frontmatter can reach this. A malformed block of our own
## is reported rather than raised, so the panel can say why no voice was restored.
##
## Returns [code]{ok, data, error}[/code].
static func read_block(raw: String, key := KEY) -> Dictionary:
	var parts := split(raw)
	if not parts.has or String(parts.head).strip_edges().is_empty():
		return {"ok": true, "data": {}, "error": ""}
	var head := _lines(String(parts.head))
	var span := _span_of(head, key)
	if span.is_empty():
		return {"ok": true, "data": {}, "error": ""}
	var res := MiniYaml_.parse("\n".join(head.slice(int(span[0]), int(span[1]))))
	if not res.ok:
		return {"ok": false, "data": {}, "error": String(res.error)}
	var data: Variant = res.data
	if not (data is Dictionary):
		return {"ok": false, "data": {}, "error": "`%s:` is not a mapping" % key}
	var v: Variant = (data as Dictionary).get(key, null)
	if v == null:
		return {"ok": true, "data": {}, "error": ""}
	if not (v is Dictionary):
		return {"ok": false, "data": {}, "error": "`%s:` in the frontmatter is not a mapping" % key}
	return {"ok": true, "data": v as Dictionary, "error": ""}


## The document with [param value] stored under [param key], and nothing else different. Pure (text in, text
## out), so the gate can check the guarantee on documents never on a disk; [method write_block] touches files.
##
## Three cases in order: our key is there and its block is replaced in place; the document has frontmatter
## without our key and the block is appended; the document has no frontmatter and a fresh one is opened above
## the body. A null [param value] removes the key (and changes nothing if it is absent).
static func put_block(raw: String, value: Variant, key := KEY) -> String:
	var parts := split(raw)
	var nl := String(parts.nl)
	if value == null:
		if not parts.has:
			return raw
		var h := _lines(String(parts.head))
		var sp := _span_of(h, key)
		if sp.is_empty():
			return raw
		var kept: Array = [String(parts.open_fence)] + _without(h, sp) + [String(parts.fence)]
		kept.append_array(_lines(String(parts.body)))
		return (String.chr(0xFEFF) if parts.bom else "") + nl.join(kept)
	var block := _block_lines(value, key)
	var prefix := String.chr(0xFEFF) if parts.bom else ""
	if not parts.has:
		#A fresh frontmatter, and a blank line under it so the first line is not welded to the closing fence.
		var body := String(parts.body)
		var lead: Array = ["---"] + block + ["---"]
		if not body.is_empty():
			lead.append("")
		return prefix + nl.join(lead) + (nl + body if not body.is_empty() else nl)
	var head := _lines(String(parts.head))
	var span := _span_of(head, key)
	var ghost := _span_of(head, KEY) if key != KEY else []
	if span.is_empty() and not ghost.is_empty():
		#A new field of the author's kind (tags, a byline) goes just above ghost's block, as a new document's title
		#does (see [method create]): ghost's block stays the machine-written one at the bottom.
		var rest: Array = head.slice(int(ghost[0]))
		head = head.slice(0, int(ghost[0]))
		head.append_array(block)
		head.append_array(rest)
	elif span.is_empty():
		#Appended rather than inserted: the author's own keys stay where they were put.
		head.append_array(block)
	else:
		var tail: Array = head.slice(int(span[1]))
		head = head.slice(0, int(span[0]))
		head.append_array(block)
		head.append_array(tail)
	var lines := _lines(String(parts.body))
	var out: Array = [String(parts.open_fence)] + head + [String(parts.fence)]
	out.append_array(lines)
	return prefix + nl.join(out)


## Store [param value] in the frontmatter of the file at [param path], on disk, by the four rules at the top.
## Returns "" on success and a human-readable reason on failure, in which case the file is untouched.
static func write_block(path: String, value: Variant, key := KEY) -> String:
	if path.is_empty():
		return "no document is open"
	if not FileAccess.file_exists(path):
		return "there is no file at %s" % path
	# Rule 1: from the disk, now. Never a copy the panel has been holding.
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return "could not read %s (error %d)" % [path, FileAccess.get_open_error()]
	var before := fh.get_as_text()
	fh.close()
	# Rules 2 and 3: line surgery on one key, then prove nothing else moved.
	var after := put_block(before, value, key)
	if after == before:
		return ""
	var bad := _verify(before, after, key)
	if not bad.is_empty():
		return bad
	return _commit(path, after)


## The body, written from ghost's own editor ([ScriptWriter]). The mirror of [method write_block]: the same
## four rules with the roles swapped; here the body is ours to replace and the frontmatter must survive byte
## for byte, ghost's own key included.
##
## [param expected] is the body as ghost last read or wrote it. If the file's body is no longer that, the
## author edited the document elsewhere, so the write is refused with [constant CONFLICT] at the head of the
## reason, which the caller turns into a choice rather than a loss. Bodies are compared with line endings
## folded, because the editor holds LF whatever the file uses.
static func write_body(path: String, body: String, expected: String) -> String:
	if path.is_empty():
		return "no document is open"
	if not FileAccess.file_exists(path):
		return "there is no file at %s" % path
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return "could not read %s (error %d)" % [path, FileAccess.get_open_error()]
	var before := fh.get_as_text()
	fh.close()
	if lf(String(split(before).body)) != lf(expected):
		return CONFLICT + "%s was changed outside Ghost Notes" % path.get_file()
	var after := put_body(before, body)
	if after.is_empty():
		return "%s mixes line endings around its frontmatter - refusing to rewrite it" \
			% path.get_file()
	if after == before:
		return ""
	var bad := _verify_body(before, after)
	if not bad.is_empty():
		return bad
	return _commit(path, after)


## A new document: [param body] with [param value] stored at [param key]. What "Sync to…" does. [param
## template] is the document being saved from, if any: its frontmatter (a title, the other panel's voice)
## comes along. [param fields] are top-level keys (`title`, `author`...) written ahead of ghost's block where
## the template does not have them. An existing file at [param path] is replaced (the save dialog has already
## asked); the write is still atomic.
static func create(path: String, value: Variant, body: String, template := "",
		key := KEY, fields := {}) -> String:
	if path.is_empty():
		return "no path given"
	var raw := lf(body)
	if not template.is_empty():
		raw = put_body(template, body)
		if raw.is_empty():
			return "the document being saved from mixes line endings - save it from a draft"
	for f in fields:
		if not String(fields[f]).is_empty() and not _has_key(raw, String(f)):
			raw = put_block(raw, String(fields[f]), String(f))
	return _commit(path, put_block(raw, value, key))


## One top-level `key:` of [param source]'s frontmatter, read textually, or "".
static func field_of(source: String, key: String) -> String:
	var lines := source.split("\n")
	var i := 0
	while i < lines.size() and String(lines[i]).strip_edges().is_empty():
		i += 1
	if i >= lines.size() or String(lines[i]).strip_edges() != "---":
		return ""
	for j in range(i + 1, lines.size()):
		var l := String(lines[j]).strip_edges()
		if l == "---":
			break
		if l.begins_with(key + ":"):
			var v := l.substr(key.length() + 1).strip_edges()
			if v.length() >= 2 and (v[0] == "\"" or v[0] == "'") and v[v.length() - 1] == v[0]:
				v = v.substr(1, v.length() - 2)
			return v
	return ""


static func _has_key(raw: String, key: String) -> bool:
	var parts := split(raw)
	return parts.has and not _span_of(_lines(String(parts.head)), key).is_empty()


## The document with its body replaced by [param body] and every byte before the body unchanged. Pure, like
## [method put_block]. Returns "" when the head cannot be cut off exactly (line endings differ inside it),
## since a rewrite that guessed would change bytes the author did not touch.
static func put_body(raw: String, body: String) -> String:
	var parts := split(raw)
	var nl := String(parts.nl)
	var old := String(parts.body)
	if not raw.ends_with(old):
		return ""
	var head := raw.substr(0, raw.length() - old.length())
	var text := lf(body).replace("\n", nl) if nl != "\n" else lf(body)
	#`---` closing a file with no body yet: the first line of the new one must not weld to it.
	if parts.has and not text.is_empty() and old.is_empty() and not head.ends_with("\n"):
		head += nl
	return head + text


## [param text] with CRLF folded to LF.
static func lf(text: String) -> String:
	return text.replace("\r\n", "\n")


## Rule 3 for a body write: everything ahead of the body - BOM, fences, every frontmatter
## line - must be identical.
static func _verify_body(before: String, after: String) -> String:
	var a := split(before)
	var b := split(after)
	if a.has != b.has or String(a.head) != String(b.head) or a.bom != b.bom \
			or String(a.fence) != String(b.fence) or String(a.open_fence) != String(b.open_fence):
		return "the edit would have changed the frontmatter - refusing to write"
	return ""


## Rule 4: write beside, read back, rename over.
static func _commit(path: String, after: String) -> String:
	var tmp := path + TEMP_SUFFIX
	var out := FileAccess.open(tmp, FileAccess.WRITE)
	if out == null:
		return "could not write beside %s (error %d)" % [path, FileAccess.get_open_error()]
	out.store_string(after)
	out.close()
	var check := FileAccess.open(tmp, FileAccess.READ)
	var wrote := check.get_as_text() if check != null else ""
	if check != null:
		check.close()
	if wrote != after:
		DirAccess.remove_absolute(tmp)
		return "the temporary file did not read back as written - %s is untouched" % path.get_file()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return "could not replace %s (error %d)" % [path.get_file(), err]
	return ""


## Rule 3, on its own so the gate can call it: what [param after] destroys, if anything. The body must be
## identical byte for byte and every frontmatter line outside our key's span must survive in order; otherwise
## the reason is returned, and is what the panel shows instead of writing.
static func _verify(before: String, after: String, key: String) -> String:
	var a := split(before)
	var b := split(after)
	if not b.has:
		return "the edit did not produce frontmatter - refusing to write"
	if String(a.body) != String(b.body):
		return "the edit would have changed the document body - refusing to write"
	if a.has and (String(a.fence) != String(b.fence) \
			or String(a.open_fence) != String(b.open_fence)):
		return "the edit would have changed a frontmatter fence - refusing to write"
	#An empty head has no lines: the only key taken out (a note's title emptied) left "---" over "---", which
	#read as one blank line where there had been none.
	var old_head := _lines(String(a.head)) if a.has and not String(a.head).is_empty() else []
	var new_head := _lines(String(b.head)) if not String(b.head).is_empty() else []
	var kept_old := _without(old_head, _span_of(old_head, key))
	var kept_new := _without(new_head, _span_of(new_head, key))
	if kept_old != kept_new:
		return "the edit would have changed another frontmatter key - refusing to write"
	return ""


## The half-open line range [code][from, to)[/code] that [param key]'s block occupies in [param head], or []
## when the key is not there. A block ends at the next non-blank line at column zero (a sibling key); blank
## lines and comments trailing it belong to what follows, so the span is pulled back to the last line with
## content and a blank line an author left between two keys survives every save.
static func _span_of(head: Array, key: String) -> Array:
	var start := -1
	for i in head.size():
		var line := String(head[i])
		if line.begins_with(" ") or line.begins_with("\t") or line.strip_edges().is_empty():
			continue
		if start >= 0:
			var last := i
			while last > start and String(head[last - 1]).strip_edges().is_empty():
				last -= 1
			return [start, last]
		if _key_of(line) == key:
			start = i
	if start < 0:
		return []
	var end := head.size()
	while end > start + 1 and String(head[end - 1]).strip_edges().is_empty():
		end -= 1
	return [start, end]


## The key a top-level frontmatter line declares, or "" when it declares none. Quoted
## keys are unwrapped, because `"ghost":` and `ghost:` are the same key.
static func _key_of(line: String) -> String:
	var colon := line.find(":")
	if colon < 0:
		return ""
	var k := line.substr(0, colon).strip_edges()
	if k.length() >= 2 and ((k.begins_with("\"") and k.ends_with("\"")) \
			or (k.begins_with("'") and k.ends_with("'"))):
		k = k.substr(1, k.length() - 2)
	return k


static func _without(head: Array, span: Array) -> Array:
	if span.is_empty():
		return head.duplicate()
	var out := head.slice(0, int(span[0]))
	out.append_array(head.slice(int(span[1])))
	return out


## [param value] under [param key], as frontmatter lines. Never a trailing blank.
static func _block_lines(value: Variant, key: String) -> Array:
	var text := MiniYaml_.emit({key: value})
	var lines := _lines(text)
	while not lines.is_empty() and String(lines[-1]).strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	return lines


## Split on newlines with the line ending taken back off, so CRLF and LF documents are
## the same problem. Rejoining uses the [code]nl[/code] [method split] reported.
static func _lines(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		out.append(String(line).trim_suffix("\r"))
	return out

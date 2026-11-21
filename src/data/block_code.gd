extends RefCounted
class_name BlockCode

## BlockCode - a block of settings (maps, lists, text, whole numbers, decimals, switches, null: what a note's block holds)
## as a code of letters and digits, and the code back to the same block. REVERSIBLE, NOT A HASH: the code holds every
## value, so it is as long as what is set. A word in the caller's list is one byte (two past the first 127) and any other
## is written out, so a list that grows never breaks a code made before it: A WORD LIST ONLY GROWS, nothing in it moves
## or goes.
##
##   encode(value, words) -> "1d5x0k..."      decode(code, words) -> {value, why}   (why "" when it read)
##
## The letters are Crockford's base 32: no i, l, o or u; read in either case, i and l as 1, o as 0, dashes and spaces
## skipped. The first letter is the format's version and the last byte a check, so a code mistyped or cut short is
## refused, never read as another. A map's keys go in sorted order and a decimal to six places, so the same block is
## always the same code.

## The format's version: a code's first letter.
const VERSION := "1"
const ALPHABET := "0123456789abcdefghjkmnpqrstvwxyz"
## How deep a code may nest maps and lists: deeper is refused, not read.
const DEEPEST := 32

# one byte says what follows: a small whole number itself, else its kind
const SMALL := 0x40          # 0x00-0x3f: 0-63
const INT := 0x40            # a whole number past 63: varint
const DECIMAL := 0x41        # 0x41-0x47: a decimal of 0-6 places, its digits a varint
const FALSE := 0x48
const TRUE := 0x49
const NULL := 0x4a
const TEXT := 0x4b           # varint length, UTF-8
const LIST := 0x4c           # varint count, values
const MAP := 0x4d            # varint count, keys and values
const FLOAT_TEXT := 0x4e     # a decimal too big or odd for six places: its text
const NEGATIVE := 0x4f       # a whole number under 0: varint of -1 - it
const MAP_SHORT := 0x50      # 0x50-0x5f: a map of 0-15
const LIST_SHORT := 0x60     # 0x60-0x6f: a list of 0-15
const NEGATIVE_DECIMAL := 0x70   # 0x70-0x76: a decimal under 0, as DECIMAL
const WORD := 0x80           # 0x80-0xfe: word 0-126; 0xff then a varint: word 127 on
const WORD_LONG := 0xff
const PLACES := 6


## [param value] as a code, the strings in [param words] written as their place in it.
static func encode(value: Variant, words: Array) -> String:
	var at := {}
	for i in words.size():
		if not at.has(String(words[i])):
			at[String(words[i])] = i
	var out := PackedByteArray()
	_write(out, value, at)
	out.append(_check(out))
	return VERSION + _base32(out)


## [param code] read back: `{value, why}`, `why` empty when it read, else what is wrong with it (and `value` null).
static func decode(code: String, words: Array) -> Dictionary:
	var c := code.strip_edges().to_lower().replace("-", "").replace(" ", "").replace("i", "1").replace("l", "1").replace("o", "0")
	if c.is_empty():
		return {"value": null, "why": "no code"}
	if c.substr(0, 1) != VERSION:
		return {"value": null, "why": "not a code this app makes (it starts with %s)" % c.substr(0, 1)}
	var bytes := _unbase32(c.substr(1))
	if bytes.is_empty():
		return {"value": null, "why": "a letter no code has in it"}
	var body := bytes.slice(0, bytes.size() - 1)
	if _check(body) != bytes[bytes.size() - 1]:
		return {"value": null, "why": "mistyped or cut short (its check does not match)"}
	var r := {"b": body, "i": 0, "why": ""}
	var v: Variant = _read(r, words, 0)
	if String(r["why"]).is_empty() and int(r["i"]) != body.size():
		r["why"] = "more in it than one block"
	if not String(r["why"]).is_empty():
		return {"value": null, "why": r["why"]}
	return {"value": v, "why": ""}


# --- writing ---------------------------------------------------------------------------------------

static func _write(out: PackedByteArray, v: Variant, at: Dictionary) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append(NULL)
		TYPE_BOOL:
			out.append(TRUE if v else FALSE)
		TYPE_INT:
			_put_int(out, int(v))
		TYPE_FLOAT:
			_put_float(out, float(v))
		TYPE_STRING, TYPE_STRING_NAME:
			_put_text(out, String(v), at)
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys().map(func(k: Variant) -> String: return str(k))
			keys.sort()
			_put_count(out, keys.size(), MAP_SHORT, MAP)
			for k in keys:
				_put_key(out, String(k), at)
				_write(out, d[k] if d.has(k) else d.get(_raw_key(d, String(k))), at)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var a: Array = Array(v)
			_put_count(out, a.size(), LIST_SHORT, LIST)
			for e in a:
				_write(out, e, at)
		_:
			_put_text(out, str(v), at)


# a key a map holds as something other than text (an int, read from JSON as a float), found by its text
static func _raw_key(d: Dictionary, k: String) -> Variant:
	for raw in d:
		if str(raw) == k:
			return raw
	return k


static func _put_int(out: PackedByteArray, n: int) -> void:
	if n >= 0 and n < SMALL:
		out.append(n)
	elif n >= 0:
		out.append(INT)
		_varint(out, n)
	else:
		out.append(NEGATIVE)
		_varint(out, -1 - n)


static func _put_float(out: PackedByteArray, f: float) -> void:
	if not is_finite(f) or absf(f) >= 1e12:
		out.append(FLOAT_TEXT)
		var t := str(f).to_utf8_buffer()
		_varint(out, t.size())
		out.append_array(t)
		return
	var s := ("%." + str(PLACES) + "f") % f
	var parts := s.split(".")
	var frac := parts[1].rstrip("0") if parts.size() > 1 else ""
	var m := (parts[0] + frac).to_int()
	out.append((NEGATIVE_DECIMAL if m < 0 else DECIMAL) + frac.length())
	_varint(out, absi(m))


static func _put_text(out: PackedByteArray, s: String, at: Dictionary) -> void:
	if at.has(s):
		var i := int(at[s])
		if i < WORD_LONG - WORD:
			out.append(WORD + i)
		else:
			out.append(WORD_LONG)
			_varint(out, i - (WORD_LONG - WORD))
		return
	var t := s.to_utf8_buffer()
	out.append(TEXT)
	_varint(out, t.size())
	out.append_array(t)


# a key that is a whole number written plainly ("3", "-12") goes as that number: a map's keys are always text
static func _put_key(out: PackedByteArray, k: String, at: Dictionary) -> void:
	if not at.has(k) and k.is_valid_int() and str(k.to_int()) == k:
		_put_int(out, k.to_int())
	else:
		_put_text(out, k, at)


static func _put_count(out: PackedByteArray, n: int, short: int, long: int) -> void:
	if n < 16:
		out.append(short + n)
	else:
		out.append(long)
		_varint(out, n)


static func _varint(out: PackedByteArray, v: int) -> void:
	while true:
		var b := v & 0x7f
		v = (v >> 7) & 0x01ffffffffffffff
		if v == 0:
			out.append(b)
			return
		out.append(b | 0x80)


# --- reading ---------------------------------------------------------------------------------------

static func _read(r: Dictionary, words: Array, depth: int) -> Variant:
	if depth > DEEPEST:
		return _fail(r, "nested deeper than a block is")
	var t := _byte(r)
	if t < 0:
		return null
	if t < SMALL:
		return t
	if t == INT:
		return _unvarint(r)
	if t == NEGATIVE:
		return -1 - _unvarint(r)
	var below := t >= NEGATIVE_DECIMAL and t <= NEGATIVE_DECIMAL + PLACES
	if below or (t >= DECIMAL and t <= DECIMAL + PLACES):
		var places := t - (NEGATIVE_DECIMAL if below else DECIMAL)
		var digits := str(_unvarint(r)).lpad(places + 1, "0")
		if places > 0:
			digits = digits.substr(0, digits.length() - places) + "." + digits.substr(digits.length() - places)
		return (("-" if below else "") + digits).to_float()
	match t:
		FALSE:
			return false
		TRUE:
			return true
		NULL:
			return null
		TEXT:
			return _text(r)
		FLOAT_TEXT:
			return _text(r).to_float()
		LIST:
			return _list(r, words, _count(r), depth)
		MAP:
			return _map(r, words, _count(r), depth)
		WORD_LONG:
			return _word(r, words, (WORD_LONG - WORD) + _unvarint(r))
	if t >= MAP_SHORT and t < MAP_SHORT + 16:
		return _map(r, words, t - MAP_SHORT, depth)
	if t >= LIST_SHORT and t < LIST_SHORT + 16:
		return _list(r, words, t - LIST_SHORT, depth)
	if t >= WORD:
		return _word(r, words, t - WORD)
	return _fail(r, "a byte no code has in it")


static func _list(r: Dictionary, words: Array, n: int, depth: int) -> Variant:
	var out: Array = []
	for i in n:
		if not String(r["why"]).is_empty():
			return null
		out.append(_read(r, words, depth + 1))
	return out


static func _map(r: Dictionary, words: Array, n: int, depth: int) -> Variant:
	var out := {}
	for i in n:
		var k: Variant = _read(r, words, depth + 1)
		if not String(r["why"]).is_empty():
			return null
		if k is int:
			k = str(k)
		if not (k is String):
			return _fail(r, "a key that is not a name")
		out[k] = _read(r, words, depth + 1)
	return out


static func _word(r: Dictionary, words: Array, i: int) -> Variant:
	if i < 0 or i >= words.size():
		return _fail(r, "a word this app does not know (made by a newer one?)")
	return String(words[i])


static func _text(r: Dictionary) -> String:
	var n := _unvarint(r)
	var b: PackedByteArray = r["b"]
	var i := int(r["i"])
	if n < 0 or i + n > b.size():
		_fail(r, "cut short")
		return ""
	r["i"] = i + n
	return b.slice(i, i + n).get_string_from_utf8()


static func _count(r: Dictionary) -> int:
	var n := _unvarint(r)
	var left := (r["b"] as PackedByteArray).size() - int(r["i"])
	if n < 0 or n > left:
		_fail(r, "cut short")
		return 0
	return n


static func _byte(r: Dictionary) -> int:
	var b: PackedByteArray = r["b"]
	var i := int(r["i"])
	if not String(r["why"]).is_empty():
		return -1
	if i >= b.size():
		_fail(r, "cut short")
		return -1
	r["i"] = i + 1
	return b[i]


static func _unvarint(r: Dictionary) -> int:
	var v := 0
	var shift := 0
	while shift < 64:
		var b := _byte(r)
		if b < 0:
			return 0
		v |= (b & 0x7f) << shift
		if b & 0x80 == 0:
			return v
		shift += 7
	_fail(r, "a number too long")
	return 0


static func _fail(r: Dictionary, why: String) -> Variant:
	if String(r["why"]).is_empty():
		r["why"] = why
	return null


# --- letters ---------------------------------------------------------------------------------------

static func _check(bytes: PackedByteArray) -> int:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		h.update(bytes)
	return h.finish()[0]


static func _base32(bytes: PackedByteArray) -> String:
	var out := ""
	var acc := 0
	var bits := 0
	for b in bytes:
		acc = (acc << 8) | b
		bits += 8
		while bits >= 5:
			bits -= 5
			out += ALPHABET[(acc >> bits) & 31]
		acc &= (1 << bits) - 1
	if bits > 0:
		out += ALPHABET[(acc << (5 - bits)) & 31]
	return out


# the bytes of [param s], or none where a letter is not the alphabet's
static func _unbase32(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	var acc := 0
	var bits := 0
	for ch in s:
		var v := ALPHABET.find(ch)
		if v < 0:
			return PackedByteArray()
		acc = (acc << 5) | v
		bits += 5
		if bits >= 8:
			bits -= 8
			out.append((acc >> bits) & 0xff)
		acc &= (1 << bits) - 1
	return out

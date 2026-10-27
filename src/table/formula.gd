extends RefCounted
class_name Formula

## Formula - a number an agent writes as arithmetic: anywhere a motion law takes a number ([Motions]),
## it may take a formula of the act's time instead - `"90 + 30 * sin(tau * t / 1.5)"` - read here.
##
## NOTHING AN AGENT WRITES IS RUN AS CODE (next/table_work.md, "Why not code"): this is a small language of
## its own, the GDScript twin of hosts/math/figure.py's - numbers, the names it is handed, + - * / % and ^
## (or **), parentheses, and calls of the functions in [constant FUNCS] by name, and NOTHING ELSE. Godot's
## own `Expression` is not used: with no object behind it, it still reaches any live object through
## `instance_from_id(...)` and runs its methods (measured 2026-10-25, a `--script` probe: the root's id gave
## back a `Window`).
##
## COMPILED ONCE, RUN EVERY FRAME: [method compile] turns the text into a list of steps (postfix: a number,
## a name, an operator, a call), refusing anything it does not know with why; [method run] works the list
## on a stack. A result that is not a finite number - a division by zero, the root of a negative - is 0.

## The most tokens a formula may have, and the most values deep its stack may go.
const MAX_TOKENS := 160
const MAX_STACK := 48
## The constants every formula knows.
const CONSTANTS := {"pi": PI, "tau": TAU, "e": 2.718281828459045}
## THE FUNCTIONS a formula may call, each with how many arguments it takes.
const FUNCS := {"sin": 1, "cos": 1, "tan": 1, "asin": 1, "acos": 1, "atan": 1, "atan2": 2, "abs": 1,
	"min": 2, "max": 2, "clamp": 3, "lerp": 3, "smoothstep": 3, "ease": 1, "pingpong": 2, "fract": 1,
	"floor": 1, "ceil": 1, "round": 1, "sqrt": 1, "pow": 2, "exp": 1, "log": 1, "sign": 1, "step": 2,
	"mod": 2, "noise": 1, "deg": 1, "rad": 1}
## The operators, by how tightly each binds, and whether it binds right to left.
const OPS := {"+": [1, false], "-": [1, false], "*": [2, false], "/": [2, false], "%": [2, false],
	"^": [4, true], "neg": [3, true]}


## [param text] as steps a run can work, for a formula that may name [param names] (and the constants):
## `{ok, code, error}` - `code` the steps, `error` why not.
static func compile(text: String, names: PackedStringArray) -> Dictionary:
	var toks := _tokens(text)
	if toks.is_empty():
		return {"ok": false, "code": [], "error": "an empty formula"}
	if toks.size() > MAX_TOKENS:
		return {"ok": false, "code": [], "error": "a formula longer than %d pieces" % MAX_TOKENS}
	var out: Array = []
	var ops: Array = []           # the operator stack: ["op", name] | ["(", ""] | ["call", name, argc]
	var expect_value := true
	for tk in toks:
		var kind := String(tk[0])
		var v: Variant = tk[1]
		match kind:
			"bad":
				return {"ok": false, "code": [], "error": "\"%s\" is not part of a formula" % str(v)}
			"num":
				if not expect_value:
					return {"ok": false, "code": [], "error": "two numbers with nothing between them"}
				out.append(["num", float(v)])
				expect_value = false
			"name":
				if not expect_value:
					return {"ok": false, "code": [], "error": "\"%s\" follows a value with nothing between them" % str(v)}
				var nm := String(v)
				if CONSTANTS.has(nm):
					out.append(["num", float(CONSTANTS[nm])])
				elif names.has(nm):
					out.append(["var", nm])
				else:
					return {"ok": false, "code": [], "error": "\"%s\" is not a name a formula knows (it knows %s)" % [nm,
						", ".join(names + PackedStringArray(CONSTANTS.keys()))]}
				expect_value = false
			"call":
				if not expect_value:
					return {"ok": false, "code": [], "error": "\"%s(\" follows a value" % str(v)}
				if not FUNCS.has(String(v)):
					return {"ok": false, "code": [], "error": "\"%s\" is not a function a formula knows (%s)" % [str(v),
						", ".join(PackedStringArray(FUNCS.keys()))]}
				ops.append(["call", String(v), 1])
				ops.append(["(", ""])
				expect_value = true
			"(":
				if not expect_value:
					return {"ok": false, "code": [], "error": "\"(\" follows a value"}
				ops.append(["(", ""])
			",":
				while not ops.is_empty() and String((ops.back() as Array)[0]) != "(":
					out.append(ops.pop_back())
				if ops.size() < 2 or String((ops[ops.size() - 2] as Array)[0]) != "call":
					return {"ok": false, "code": [], "error": "a comma outside a function's call"}
				(ops[ops.size() - 2] as Array)[2] = int((ops[ops.size() - 2] as Array)[2]) + 1
				expect_value = true
			")":
				if expect_value:
					return {"ok": false, "code": [], "error": "\")\" where a value should be"}
				while not ops.is_empty() and String((ops.back() as Array)[0]) != "(":
					out.append(ops.pop_back())
				if ops.is_empty():
					return {"ok": false, "code": [], "error": "a \")\" with no \"(\""}
				ops.pop_back()
				if not ops.is_empty() and String((ops.back() as Array)[0]) == "call":
					var c: Array = ops.pop_back()
					if int(c[2]) != int(FUNCS[String(c[1])]):
						return {"ok": false, "code": [], "error": "%s takes %d (it was given %d)" % [String(c[1]), int(FUNCS[String(c[1])]), int(c[2])]}
					out.append(["call", String(c[1]), int(c[2])])
				expect_value = false
			"op":
				var op := String(v)
				if expect_value:
					if op == "-":
						op = "neg"
					elif op == "+":
						continue
					else:
						return {"ok": false, "code": [], "error": "\"%s\" where a value should be" % op}
				var mine: Array = OPS[op]
				while not ops.is_empty() and String((ops.back() as Array)[0]) == "op":
					var top: Array = OPS[String((ops.back() as Array)[1])]
					if int(top[0]) > int(mine[0]) or (int(top[0]) == int(mine[0]) and not bool(mine[1])):
						out.append(ops.pop_back())
					else:
						break
				ops.append(["op", op])
				expect_value = true
	if expect_value:
		return {"ok": false, "code": [], "error": "the formula ends where a value should be"}
	while not ops.is_empty():
		var o: Array = ops.pop_back()
		if String(o[0]) != "op":
			return {"ok": false, "code": [], "error": "a \"(\" with no \")\""}
		out.append(o)
	# HOW DEEP ITS STACK GOES, worked out now: a formula past the most is refused, not run
	var depth := 0
	var most := 0
	for s in out:
		match String((s as Array)[0]):
			"num", "var":
				depth += 1
			"op":
				depth -= 0 if String((s as Array)[1]) == "neg" else 1
			"call":
				depth -= int((s as Array)[2]) - 1
		most = maxi(most, depth)
	if most > MAX_STACK or depth != 1:
		return {"ok": false, "code": [], "error": "a formula too deep to work"}
	return {"ok": true, "code": out, "error": ""}


## Steps [param code] ([method compile]) worked with [param vars] (each name a number): a finite number,
## 0 where the arithmetic gave none.
static func run(code: Array, vars: Dictionary) -> float:
	var st := PackedFloat64Array()
	for s in code:
		var step: Array = s
		match String(step[0]):
			"num":
				st.append(float(step[1]))
			"var":
				st.append(float(vars.get(String(step[1]), 0.0)))
			"op":
				var op := String(step[1])
				if op == "neg":
					st[st.size() - 1] = -st[st.size() - 1]
					continue
				var b := st[st.size() - 1]
				st.resize(st.size() - 1)
				var a := st[st.size() - 1]
				var r := 0.0
				match op:
					"+":
						r = a + b
					"-":
						r = a - b
					"*":
						r = a * b
					"/":
						r = a / b if b != 0.0 else 0.0
					"%":
						r = fposmod(a, b) if b != 0.0 else 0.0
					"^":
						r = pow(a, b)
				st[st.size() - 1] = r
			"call":
				var n := int(step[2])
				var args := st.slice(st.size() - n)
				st.resize(st.size() - n)
				st.append(_call(String(step[1]), args))
	var out := st[0] if st.size() == 1 else 0.0
	return out if is_finite(out) else 0.0


static func _call(f: String, a: PackedFloat64Array) -> float:
	match f:
		"sin": return sin(a[0])
		"cos": return cos(a[0])
		"tan": return tan(a[0])
		"asin": return asin(clampf(a[0], -1.0, 1.0))
		"acos": return acos(clampf(a[0], -1.0, 1.0))
		"atan": return atan(a[0])
		"atan2": return atan2(a[0], a[1])
		"abs": return absf(a[0])
		"min": return minf(a[0], a[1])
		"max": return maxf(a[0], a[1])
		"clamp": return clampf(a[0], minf(a[1], a[2]), maxf(a[1], a[2]))
		"lerp": return lerpf(a[0], a[1], a[2])
		"smoothstep": return smoothstep(a[0], a[1], a[2])
		"ease": return Motions.eased(clampf(a[0], 0.0, 1.0))
		"pingpong": return pingpong(a[0], a[1]) if a[1] != 0.0 else 0.0
		"fract": return a[0] - floorf(a[0])
		"floor": return floorf(a[0])
		"ceil": return ceilf(a[0])
		"round": return roundf(a[0])
		"sqrt": return sqrt(a[0]) if a[0] >= 0.0 else 0.0
		"pow": return pow(a[0], a[1])
		"exp": return exp(minf(a[0], 80.0))
		"log": return log(a[0]) if a[0] > 0.0 else 0.0
		"sign": return signf(a[0])
		"step": return 1.0 if a[1] >= a[0] else 0.0
		"mod": return fposmod(a[0], a[1]) if a[1] != 0.0 else 0.0
		"noise": return noise1(a[0])
		"deg": return rad_to_deg(a[0])
		"rad": return deg_to_rad(a[0])
	return 0.0


## A SMOOTH NOISE of one number, -1..1: the same everywhere it is asked (no state, no seed beyond the
## number), so a formula that wanders wanders the same in a render and a scrub.
static func noise1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	var a := _hash1(i)
	var b := _hash1(i + 1.0)
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))


static func _hash1(i: float) -> float:
	var h := sin(i * 127.1 + 311.7) * 43758.5453
	return (h - floorf(h)) * 2.0 - 1.0


## THE PIECES of [param text]: `[kind, value]` - "num", "name", "call" (a name right before "("), "op",
## "(", ")", ",", or "bad" for anything else, which [method compile] refuses.
static func _tokens(text: String) -> Array:
	var out: Array = []
	var s := text.strip_edges()
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if (c >= "0" and c <= "9") or c == ".":
			var j := i
			while j < s.length() and ((s[j] >= "0" and s[j] <= "9") or s[j] == "."):
				j += 1
			if j < s.length() and (s[j] == "e" or s[j] == "E") and j + 1 < s.length() \
					and ((s[j + 1] >= "0" and s[j + 1] <= "9") or ((s[j + 1] == "-" or s[j + 1] == "+") and j + 2 < s.length() and s[j + 2] >= "0" and s[j + 2] <= "9")):
				j += 2
				while j < s.length() and s[j] >= "0" and s[j] <= "9":
					j += 1
			var num := s.substr(i, j - i)
			if not num.is_valid_float():
				return [["bad", num]]
			out.append(["num", num.to_float()])
			i = j
			continue
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_":
			var j := i
			while j < s.length() and ((s[j] >= "a" and s[j] <= "z") or (s[j] >= "A" and s[j] <= "Z") or (s[j] >= "0" and s[j] <= "9") or s[j] == "_"):
				j += 1
			var nm := s.substr(i, j - i)
			var k := j
			while k < s.length() and s[k] == " ":
				k += 1
			if k < s.length() and s[k] == "(":
				out.append(["call", nm])
				i = k + 1
			else:
				out.append(["name", nm])
				i = j
			continue
		if c == "*" and i + 1 < s.length() and s[i + 1] == "*":
			out.append(["op", "^"])
			i += 2
			continue
		if c in ["+", "-", "*", "/", "%", "^"]:
			out.append(["op", c])
		elif c == "(" or c == ")" or c == ",":
			out.append([c, c])
		else:
			return [["bad", c]]
		i += 1
	return out

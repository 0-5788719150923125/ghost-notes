extends SceneTree

## ornaments_check - an ornament written by an agent ([Ornaments], [OrnamentLibrary], [OrnamentDesign], [OrnamentShelf], [Props]
## `ornament` of its own; next/surfaces.md), with no renderer and a library of its own.
##
##   godot --headless --path . --script res://tests/table/ornaments_check.gd
##
## - The check: a body that draws passes; empty, too long, a word it may not hold (TIME, while, a texture, discard), a name in
##   capitals (control: PI passes), a loop past its turns or past two loops or not counting up by one, unbalanced braces and no
##   return are each refused, saying why. A comment is no code: a banned word in one passes.
## - The variant: its source holds the body where the mark was (control: the shader's own holds the mark); the same body is the same
##   shader, kept; a body the check refuses is the shader as it was.
## - A prop wears one: written as `own` with its code it keeps the code (control: code the check refuses wears none); worn by the name
##   of one kept, it draws that one's version used, and follows a version chosen; a name nobody kept wears none. Its material is the
##   variant, its ornament 11 (control: a built-in ornament keeps the shader and its own code).
## - The library: a new one is named and numbered; code the check refuses is no version; a version is used as it is kept and another
##   chosen; renamed, its folder moves with it; removed, it goes to the trash; only one made is told to an agent.
## - The designer's prompts render whole, told the language, the ornament's name and its words (control: a name nobody gives is said).
## - The shelf stands under Surfaces: a tile to make one, then each kept one with Refine…, its versions and Remove; ‹ and › choose its
##   version.

const ROOT := "user://ornaments_check"
const GOOD := "vec2 q = rot(p, 0.3);\nfloat d = sd_spiral(q, 0.09, 2.5);\nfloat h = stroke(d, 0.035);\nreturn vec2(h, h);"
const OTHER := "float d = sd_circle(p, 0.3);\nreturn vec2(fill(d), stroke(d, 0.05));"

var _fails := 0


func _init() -> void:
	var was := Library.root
	Library.root = ROOT.path_join("library")
	Library.discard = func(path: String) -> int:
		_rmrf(path)
		return OK
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_check()
	_variant()
	_library()
	_worn()
	_designer()
	_shelf()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	Library.root = was
	Library.discard = Callable()
	print("ornaments_check: %s (%d failure%s)" % ["ALL OK" if _fails == 0 else "FAILED", _fails, "" if _fails == 1 else "s"])
	quit(1 if _fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: " + what)


func _refused(code: String, what: String) -> void:
	var why := Ornaments.check(code)
	_ok(not why.is_empty(), "%s is refused" % what)


func _check() -> void:
	_ok(Ornaments.check(GOOD).is_empty(), "a body that draws passes: %s" % Ornaments.check(GOOD))
	_ok(Ornaments.check("float h = PI * 0.1;\nreturn vec2(h);").is_empty(), "the control: PI passes")
	_ok(Ornaments.check("// no TIME here, nor while\nreturn vec2(0.0);").is_empty(), "a banned word in a comment passes")
	_ok(Ornaments.check("float h = 0.0;\nfor (int i = 0; i < 16; i++) { h += 0.01; }\nreturn vec2(h);").is_empty(), "a loop of sixteen passes")
	_refused("", "an empty body")
	_refused("return vec2(0.0);" + " ".repeat(Ornaments.LONGEST), "a body too long")
	_refused("return vec2(sin(TIME));", "TIME")
	_refused("while (true) {}\nreturn vec2(0.0);", "while")
	_refused("vec4 c = texture(x, p);\nreturn c.xy;", "a texture")
	_refused("discard;\nreturn vec2(0.0);", "discard")
	_refused("return vec2(SCREEN_UV);", "a name in capitals")
	_refused("float h = 0.0;\nfor (int i = 0; i < 17; i++) { h += 0.01; }\nreturn vec2(h);", "a loop past its turns")
	_refused("float h = 0.0;\nfor (int i = 0; i < 2; i++) {}\nfor (int j = 0; j < 2; j++) {}\nfor (int k = 0; k < 2; k++) {}\nreturn vec2(h);", "three loops")
	_refused("float h = 0.0;\nfor (int i = 0; i < 8; i += 2) { h += 0.1; }\nreturn vec2(h);", "a loop not counting up by one")
	_refused("float h = (1.0;\nreturn vec2(h);", "unbalanced brackets")
	_refused("float h = 1.0;", "no return")


func _variant() -> void:
	var base: Shader = load("res://shaders/prop.gdshader")
	var common := (load(Ornaments.COMMON) as ShaderInclude).code
	_ok(common.contains(Ornaments.MARK), "the control: the shader's own ornament holds the mark")
	var src := Ornaments.source_for(base, GOOD)
	_ok(src.contains("sd_spiral(q, 0.09, 2.5)") and not src.contains(Ornaments.MARK) and not src.contains(Ornaments.INCLUDE),
		"the variant's source holds the body where the mark was")
	_ok(Ornaments.shader_for(base, GOOD) == Ornaments.shader_for(base, GOOD), "the same body is the same shader, kept")
	_ok(Ornaments.shader_for(base, "return vec2(sin(TIME));") == base, "a body the check refuses is the shader as it was")
	var described := Ornaments.describe()
	_ok(Ornaments.HELPERS.keys().all(func(k: String) -> bool: return described.contains(k)), "the language names every helper it may call")


func _library() -> void:
	var a := OrnamentLibrary.make("a running border of scrolls")
	var b := OrnamentLibrary.make()
	_ok(a == "Ornament" and b == "Ornament 2", "a new one is named and numbered: %s, %s" % [a, b])
	_ok(OrnamentLibrary.add_version(a, "return vec2(sin(TIME));") == -1, "code the check refuses is no version")
	_ok(OrnamentLibrary.add_version(a, GOOD, "spirals") == 0 and OrnamentLibrary.code_of(a) == GOOD, "a version is used as it is kept")
	_ok(OrnamentLibrary.add_version(a, OTHER) == 1 and OrnamentLibrary.code_of(a) == OTHER, "the next is used as it is kept")
	_ok(OrnamentLibrary.use_version(a, 0).is_empty() and OrnamentLibrary.code_of(a) == GOOD, "another version chosen is used")
	var listed := OrnamentLibrary.listing()
	_ok(listed.size() == 1 and String((listed[0] as Dictionary)["name"]) == a, "only one made is told to an agent: %s" % str(listed))
	_ok(OrnamentLibrary.rename(a, "Fine scrolls").is_empty() and OrnamentLibrary.find("fine scrolls").get("code", "") == GOOD
		and DirAccess.dir_exists_absolute(OrnamentLibrary.folder("Fine scrolls")) and not DirAccess.dir_exists_absolute(OrnamentLibrary.folder(a)),
		"renamed, its folder moves with it")
	_ok(OrnamentLibrary.remove(b).is_empty() and OrnamentLibrary.find(b).is_empty(), "removed, it goes")


func _part_of(orn: Dictionary) -> Dictionary:
	var safe := Props.sanitize({"things": [{"name": "t", "parts": [{"shape": "lathe", "profile": [[0, 0], [3, 0], [3, 6], [0, 6]],
		"material": "brass", "ornament": orn}]}], "materials": {"brass": {"kind": "metal", "color": "#c9a24a"}}}, ["#888888"])
	return ((safe["things"] as Array)[0] as Dictionary)["parts"][0]


func _worn() -> void:
	var own: Dictionary = _part_of({"kind": "own", "code": OTHER, "count": 5})["ornament"]
	_ok(String(own.get("kind", "")) == "own" and String(own.get("code", "")) == OTHER and float(own["count"]) == 5.0, "written as own, it keeps its code")
	_ok((_part_of({"kind": "own", "code": "return vec2(sin(TIME));"})["ornament"] as Dictionary).is_empty(), "the control: code the check refuses wears none")
	var kept: Dictionary = _part_of({"kind": "Fine Scrolls"})["ornament"]
	_ok(String(kept.get("code", "")) == GOOD and String(kept.get("name", "")) == "Fine scrolls", "worn by a kept one's name, it draws its version used")
	OrnamentLibrary.use_version("Fine scrolls", 1)
	_ok(String((_part_of({"kind": "fine scrolls"})["ornament"] as Dictionary).get("code", "")) == OTHER, "and follows a version chosen")
	OrnamentLibrary.use_version("Fine scrolls", 0)
	_ok((_part_of({"kind": "nobody kept this"})["ornament"] as Dictionary).is_empty(), "a name nobody kept wears none")
	var m := Props.material({"kind": "metal", "color": "#c9a24a"}, kept, 10.0, 10.0, 1, true)
	_ok(m.shader != Props._SHADER and int(m.get_shader_parameter("orn")) == Props.ORN_OWN and m.shader.code.contains("sd_spiral(q, 0.09, 2.5)"),
		"its material is the variant, its ornament 11")
	var plain := Props.material({"kind": "metal", "color": "#c9a24a"}, {"kind": "stars", "count": 6}, 10.0, 10.0, 1, true)
	_ok(plain.shader == Props._SHADER and int(plain.get_shader_parameter("orn")) == int(Props.ORNAMENTS["stars"]["code"]),
		"the control: a built-in ornament keeps the shader and its own code")


func _designer() -> void:
	var info := OrnamentDesign.new("Fine scrolls").about()
	var system := Rules.say("table/ornament_designer.system", info.merged({"tools": true}))
	_ok(not system.contains("{{") and system.contains("\"Fine scrolls\"") and system.contains(Ornaments.SIGNATURE),
		"the designer's prompt renders whole, told its name and the language")
	var first := WriterChat.first_message(info, GOOD, "make it finer", "", "", "table/ornament_designer")
	_ok(not first.contains("{{") and first.contains("sd_spiral") and first.contains("make it finer"), "its first turn holds the code and the ask")
	Rules.missing.clear()
	Rules.say("table/ornament_designer.system", {"tools": true})
	_ok(not Rules.missing.is_empty(), "the control: a name nobody gives is said")
	Rules.missing.clear()


func _shelf() -> void:
	var sh := OrnamentShelf.new()
	_ok(sh.category() == "Surfaces" and sh.title() == "Ornaments", "the shelf stands under Surfaces")
	var offers := sh.offers()
	_ok(String((offers[0] as Dictionary)["key"]) == "new" and ((offers[0] as Dictionary)["verbs"] as Array)[0]["key"] == "make",
		"a tile makes a new one")
	var row: Array = offers.filter(func(o: Dictionary) -> bool: return String(o["key"]) == "kept:Fine scrolls")
	var verbs: Array = (row[0]["verbs"] as Array).map(func(v: Dictionary) -> String: return String(v["key"])) if not row.is_empty() else []
	_ok(verbs == ["refine", "older", "newer", "forget"], "a kept one has Refine…, its versions and Remove: %s" % str(verbs))
	_ok(sh.act("kept:Fine scrolls", "newer").is_empty() and OrnamentLibrary.code_of("Fine scrolls") == OTHER, "› chooses the next version")
	_ok(sh.act("kept:Fine scrolls", "older").is_empty() and OrnamentLibrary.code_of("Fine scrolls") == GOOD, "‹ the one before")


func _rmrf(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		for d in DirAccess.get_directories_at(path):
			_rmrf(path.path_join(d))
		for f in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(f))
		DirAccess.remove_absolute(path)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

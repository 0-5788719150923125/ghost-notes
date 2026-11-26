extends RefCounted
class_name OrnamentTools

## OrnamentTools - what a designer can do to one ornament's or texture's code while it works on it with the author ([WriterChat],
## [OrnamentDesign]): read the code, change a part of it, write it whole (the text's own tools, [TextTools]) and RENDER it - the
## code as it stands compiled ([method Ornaments.compile_errors]: where it does not, line by line in its own code) and photographed on
## its swatch ([method OrnamentLibrary.swatch], [method PropStudio.views]: an ornament round a turned vase and on a flat plaque, a
## texture all over a clay bowl and a stone block). The designer sees what it drew before it says it is done. Served as tools
## ([AgentTools]).

## The text's own tools: read, edit, write.
var text: TextTools
## Its name (its renders are kept in its folder) and what it is ([constant OrnamentLibrary.ORNAMENT] or [constant
## OrnamentLibrary.TEXTURE]).
var name := ""
var kind := OrnamentLibrary.ORNAMENT
## A render landed: `func(paths: Array)`, so whoever shows the ornament can show its draft.
var rendered: Callable


## What the render photographs it on, in words.
func _on() -> String:
	if kind == OrnamentLibrary.TEXTURE:
		return "all over a turned clay bowl and a stone block"
	return "worn round a turned brass vase and on a flat stone plaque"


func instructions() -> String:
	return (text.instructions() + " render compiles the code as it stands and photographs it %s; " % _on()
		+ "render after each change and judge the pictures against what the %s should be." % kind)


func list_tools() -> Array:
	var out: Array = text.list_tools()
	out.append({"name": "render", "description": "Compile the %s's code as it stands and photograph it, %s, from the front and from the side. Code that does not compile says where, by its line in your code." % [kind, _on()],
		"inputSchema": {"type": "object", "properties": {}}})
	return out


func call_tool(tool: String, args: Dictionary) -> Dictionary:
	if tool != "render":
		return text.call_tool(tool, args)
	var raw: Variant = text.read_text.call() if text.read_text.is_valid() else null
	if raw == null:
		return {"error": "The %s is closed: the author has left it. Stop here." % kind}
	var code := String(raw)
	var why := Ornaments.compile_errors(code, kind)
	if not why.is_empty():
		return {"error": "It does not compile: %s" % why}
	if not PropStudio.can_see():
		return {"text": "It compiles; this session can take no pictures of it."}
	var sw := OrnamentLibrary.swatch(code, kind)
	var paths: Array = await PropStudio.views(sw["thing"], sw["materials"], code.sha256_text().left(16),
		OrnamentLibrary.folder(name).path_join("draft"))
	var images: Array = []
	for p in paths.slice(0, 2):
		var img := Image.load_from_file(String(p))
		if img != null:
			images.append(img)
	if rendered.is_valid():
		rendered.call(paths)
	var said := "worn round the vase (its band from near the foot to near the lip, six cells round) and on the plaque beside it"
	if kind == OrnamentLibrary.TEXTURE:
		said = "all over the bowl and the block beside it, at its own size (%s cm a unit of p) and bumps 0.75" % str(Props.TEX_OWN_SIZE)
	return {"text": "It compiles. The pictures: %s, from a little above the front, then from the side." % said, "images": images}

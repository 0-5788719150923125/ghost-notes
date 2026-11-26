extends RefCounted
class_name OrnamentTools

## OrnamentTools - what an ornament designer can do to one ornament's code while it works on it with the author ([WriterChat],
## [OrnamentDesign]): read the code, change a part of it, write it whole (the text's own tools, [TextTools]) and RENDER it - the
## code as it stands compiled ([method Ornaments.compile_errors]: where it does not, line by line in its own code) and photographed
## worn round a turned vase and on a flat plaque ([method OrnamentLibrary.swatch], [method PropStudio.views]). The designer sees what
## it drew before it says it is done. Served as tools ([AgentTools]).

## The text's own tools: read, edit, write.
var text: TextTools
## The ornament's name: its renders are kept in its folder.
var name := ""
## A render landed: `func(paths: Array)`, so whoever shows the ornament can show its draft.
var rendered: Callable


func instructions() -> String:
	return (text.instructions() + " render compiles the code as it stands and photographs it on a turned vase and a flat plaque; "
		+ "render after each change and judge the pictures against what the ornament should be.")


func list_tools() -> Array:
	var out: Array = text.list_tools()
	out.append({"name": "render", "description": "Compile the ornament's code as it stands and photograph it, worn round a turned brass vase and on a flat stone plaque, from the front and from the side. Code that does not compile says where, by its line in your code.",
		"inputSchema": {"type": "object", "properties": {}}})
	return out


func call_tool(tool: String, args: Dictionary) -> Dictionary:
	if tool != "render":
		return text.call_tool(tool, args)
	var raw: Variant = text.read_text.call() if text.read_text.is_valid() else null
	if raw == null:
		return {"error": "The ornament is closed: the author has left it. Stop here."}
	var code := String(raw)
	var why := Ornaments.compile_errors(code)
	if not why.is_empty():
		return {"error": "It does not compile: %s" % why}
	if not PropStudio.can_see():
		return {"text": "It compiles; this session can take no pictures of it."}
	var sw := OrnamentLibrary.swatch(code)
	var paths: Array = await PropStudio.views(sw["thing"], sw["materials"], code.sha256_text().left(16),
		OrnamentLibrary.folder(name).path_join("draft"))
	var images: Array = []
	for p in paths.slice(0, 2):
		var img := Image.load_from_file(String(p))
		if img != null:
			images.append(img)
	if rendered.is_valid():
		rendered.call(paths)
	return {"text": "It compiles. The pictures: worn round the vase (its band from near the foot to near the lip, six cells round) and on the plaque beside it, from a little above the front, then from the side.",
		"images": images}

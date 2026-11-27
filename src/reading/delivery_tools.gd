extends RefCounted
class_name DeliveryTools

## DeliveryTools - what a designer tuning a delivery can do while it works on it with the author ([DeliveryDesign], [WriterChat]):
## read the delivery as JSON, change a part of it, write it whole (the text's own tools, [TextTools]) and HEAR it - the words said
## with the delivery as the text stands and without it, in the voice the author tests it in, told back as numbers ([DeliveryHearing]:
## how long, how high, how wide, how loud, pitch and level across it). The designer hears what it made before it says it is done.
## Served as tools ([AgentTools]).

## The text's own tools: read, edit, write.
var text: TextTools
## The words said with the delivery as the text stands, and without: `func(words: String) -> Dictionary` (awaited), `{text}` or
## `{error}`; "" words are the Lab's own.
var hear: Callable


func instructions() -> String:
	return (text.instructions() + " hear says words with the delivery as its text stands and without it, and tells you how the two "
		+ "differ as numbers; hear it before you change it, and again after each change, and compare.")


func list_tools() -> Array:
	var out: Array = text.list_tools()
	out.append({"name": "hear", "description": "Say words with the delivery as its text stands now, and without it, in the voice the author tests it in, and hear both: how long each is, its pitch (semitones over 100 Hz: the middle, the 10th and 90th percentiles, the spread), its level, and pitch and level across it in tenths - and the change between them.",
		"inputSchema": {"type": "object", "properties": {"words": {"type": "string",
			"description": "The words to say, as a script would write them: plain words are said with the delivery round all of them, words with marks of their own (`[word]{name}`, `<!-- delivery: name -->`) as written. Left out, the words the author tests it on."}}}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if name != "hear":
		return text.call_tool(name, args)
	if not hear.is_valid():
		return {"error": "The delivery's Lab is closed: the author has left it. Stop here."}
	return await hear.call(String(args.get("words", "")) if args.get("words") is String else "")

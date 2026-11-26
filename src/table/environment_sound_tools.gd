extends RefCounted
class_name EnvironmentSoundTools

## EnvironmentSoundTools - what a designer refining a sound round a scene can do while it works on it with the author
## ([EnvironmentSoundDesign], [WriterChat]): read the sound's properties, change a part of them, write them whole (the text's own
## tools, [TextTools]) and HEAR them - the sound as the properties stand made as the scene makes it, alone at the level it has under
## the voice, and told back as numbers ([SoundMeasure]: its loudness over time and how much it swings, its brightness, its lows and
## highs, its balance, its sudden rises) with what had to change to make it. The designer hears what it made before it says it is done.
## Served as tools ([AgentTools]).

## How long a sound is heard by default, and the least and most a call may ask for (seconds).
const HEARD := 20.0
const LEAST := 5.0
const MOST := 60.0

## The text's own tools: read, edit, write.
var text: TextTools
## The sound as the properties stand heard for [param seconds]: `func(seconds: float) -> Dictionary` (awaited), `{text}` or `{error}`.
var hear: Callable


func instructions() -> String:
	return (text.instructions() + " hear makes the sound as its properties stand now and tells you what it sounds like as numbers; "
		+ "hear it before you change it, and again after each change, and compare.")


func list_tools() -> Array:
	var out: Array = text.list_tools()
	out.append({"name": "hear", "description": "Make the sound as its properties stand now and hear it alone, as it plays under the voice: its loudness over time and how much it swings, how bright it is, how its power falls in the low, middle and high, which side it leans to, and how many sudden rises it has (drops, crackles, chirps, slaps) - with any property that could not be used as written.",
		"inputSchema": {"type": "object", "properties": {"seconds": {"type": "number",
			"description": "How long to hear it, %d to %d seconds (%d when left out): longer for a sound that swells and fades slowly." % [int(LEAST), int(MOST), int(HEARD)]}}}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if name != "hear":
		return text.call_tool(name, args)
	if not hear.is_valid():
		return {"error": "The sound is closed: the author has left it. Stop here."}
	var secs := clampf(float(args.get("seconds", HEARD)) if typeof(args.get("seconds")) in [TYPE_INT, TYPE_FLOAT] else HEARD, LEAST, MOST)
	return await hear.call(secs)

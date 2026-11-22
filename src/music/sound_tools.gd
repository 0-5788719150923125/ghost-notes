extends RefCounted
class_name SoundTools

## SoundTools - what a sound designer can do to one sound's patch while it works on it with the author ([WriterChat],
## next/sound_effects.md): read the patch, change a part of it, write it whole (the text's own tools, [TextTools]) and RENDER
## it - the patch as it stands made into sound by the music host and told back as numbers ([method SoundEffects.heard_text]:
## its loudness, brightness and pitch over time, its onsets, how it fades). The designer hears what it made before it says it
## is done; a patch is checked against its words, never written once and left. Served as tools ([AgentTools]).

## The text's own tools: read, edit, write.
var text: TextTools
## The sound's key ([method SoundEffects.key_of]): its draft is made in its folder.
var key := ""
## A render landed: `func(heard: Dictionary)`, so whoever shows the sound can show its draft.
var rendered: Callable


func instructions() -> String:
	return (text.instructions() + " render makes the patch as it stands into sound and tells you what it sounds like as "
		+ "numbers; render after each change and compare what you hear with what the sound should be.")


func list_tools() -> Array:
	var out: Array = text.list_tools()
	out.append({"name": "render", "description": "Make the patch as it stands into sound and hear it: its length and peak, where it is loudest, its onsets, how it fades, and its loudness (dB), brightness (Hz) and pitch (Hz, where it is a clear tone) over time. A patch that cannot be made says why.",
		"inputSchema": {"type": "object", "properties": {}}})
	return out


func call_tool(name: String, args: Dictionary) -> Dictionary:
	if name != "render":
		return text.call_tool(name, args)
	var raw: Variant = text.read_text.call() if text.read_text.is_valid() else null
	if raw == null:
		return {"error": "The sound is closed: the author has left it. Stop here."}
	var patch: Variant = JSON.parse_string(String(raw))
	if not (patch is Dictionary):
		return {"error": "The patch is not valid JSON: read it and fix it before rendering."}
	var res: Dictionary = await SoundEffects.render(patch, SoundEffects.seed_of(key), SoundEffects.folder(key).path_join("draft.wav"))
	if not bool(res.get("ok", false)):
		return {"error": String(res.get("error", "the sound could not be made"))}
	var heard: Dictionary = res.get("heard", {})
	if rendered.is_valid():
		rendered.call(heard)
	return {"text": SoundEffects.heard_text(heard)}

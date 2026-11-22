extends LibraryVoices
class_name SingerShelf

## SingerShelf - the voices kept in the library that can sing ([Singers]), on the Dex's shelves for a composed Sound's Voice
## part (the Sound card's Choose… beside its Singer): each heard from its sample as the Voices shelf has it, and "Sings it"
## casts it in the part ([member picked]). A voice that cannot sing (a Piper reader) is not offered.

## (name: String) -> void: the kept voice cast in the part.
var picked: Callable = Callable()


func _init(on_pick: Callable = Callable()) -> void:
	picked = on_pick


func title() -> String:
	return "Singers"


func category() -> String:
	return "Voices"


func offers() -> Array:
	var singers := Singers.kept()
	return super.offers().filter(func(o: Dictionary) -> bool: return singers.has(String(o["key"]).substr(5)))


func adds() -> Dictionary:
	return {"verb": "Sings it", "tip": "This voice sings the part: its size from its Tone, its vibrato and drift from its Lab."}


func add(key: String) -> String:
	if not key.begins_with("kept:"):
		return "only a kept voice sings"
	if not picked.is_valid():
		return "no part to sing"
	picked.call(key.substr(5))
	return ""

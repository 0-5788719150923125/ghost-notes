extends RefCounted
class_name ShelfSection

## ShelfSection - what one kind of thing the library keeps puts on the Dex's shelves ([DexWindow]): props, voices. The window draws,
## the section does; it names no component, and no component names the window. A presentation's Props card hands a [PropSection],
## which is one of these with rows of its own.
##
## An offer is one entry on a shelf: `{key, name, line, shelf, picture, sound, named, tip, verbs}` - `picture` an Image (null until
## it is taken), `sound` a playable file ("" for none), `named` whether its name can be changed in place ([method rename]), `verbs`
## its buttons, each `{key, label, tip}` with `off` (grayed, `tip` saying why) where it applies, done by [method act]. An offer
## that can be built whole is turned in 3D ([method model_of], [PropViewer]). These defaults offer nothing.


## What the section holds, said on the Dex: "Props", "Voices".
func title() -> String:
	return ""


## The kind of thing its shelves hold, the heading they stand under in the Dex's list ("Props", "Voices", "Environment"): sections of
## one category stand together. Its title by default.
func category() -> String:
	return title()


## A number that moves whenever what it offers changes in a way the count of offers does not show (a voice's sample made): the Dex
## fills its shelf again when it moves. 0 for a section that never says.
func version() -> int:
	return 0


## The words the Dex is first filtered by when opened on it ("mug" for a choice of mugs), "" for none.
func find() -> String:
	return ""


## The shelves its offers stand on, in order: each `{key, label, tip}`.
func shelves() -> Array:
	return []


## Every offer, on every shelf ([ShelfSection]'s note).
func offers() -> Array:
	return []


## Verb [param verb] of offer or row [param key] done. "" done, else why not.
func act(_key: String, _verb: String) -> String:
	return "nothing here does that"


## The offers [param keys] are in view or near it, the nearest first: their pictures are wanted ahead of any other.
func want_pictures(_keys: Array) -> void:
	pass


## The offers [param keys] are on the shelf shown, in place of those before: each picture never taken is taken behind those
## wanted, so the shelf scrolls without waiting. [] when the shelf closes: those not yet taken wait no longer.
func prepare_pictures(_keys: Array) -> void:
	pass


## The picture of offer [param key] if it is to hand, null otherwise; never asks for one.
func picture(_key: String) -> Variant:
	return null


## Offer [param key] renamed [param name]. "" done, else why not.
func rename(_key: String, _name: String) -> String:
	return "nothing here can be renamed"


## Offer [param key] built whole, to be turned in the hand ([PropViewer]): `{node, box, size}` - its node out of any tree, its
## bounds and its size in words - or {} where it has none. A section that builds one waits for it (a coroutine).
func model_of(_key: String) -> Dictionary:
	return {}


## Whether its offers can be built whole and turned ([method model_of]).
func turns() -> bool:
	return false


## What adding an offer does where the Dex was opened from, said on the button and its tooltip: `{label, verb, tip}`, {} where
## nothing takes it (the Dex opened on its own).
func adds() -> Dictionary:
	return {}


## Offer [param key] added. "" done, else why not.
func add(_key: String) -> String:
	return "nothing here takes it"


## The file an entry is handed on in: `{ext, label}` (".prop.json", "Props"), {} where none can be.
func file_kind() -> Dictionary:
	return {}


## Whether offer [param key] can be written to a file to hand on.
func exportable(_key: String) -> bool:
	return false


## Offer [param key] written to the file at [param path]. "" done, else why not.
func export_to(_key: String, _path: String) -> String:
	return "nothing here can be exported"


## The entry in the file at [param path] taken into the library. "" done, else why not.
func import_from(_path: String) -> String:
	return "nothing here takes a file"

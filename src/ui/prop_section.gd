extends ShelfSection
class_name PropSection

## PropSection - the props a presentation sets down, handed to the panel's Props card ([PropsCard]) by whatever shows them, as a
## show hands the Pacing card a [TuneSection]: the card draws, the section does, and with no section there is no card. No component
## names the card and the card names no component. What can be added is its shelves on the Dex ([ShelfSection], [DexWindow]).
##
## A row is a prop as it stands now: `{key, name, line, group, picture, on, verbs}` - `picture` an Image (null until it is taken),
## `on` whether the scene uses it (null for a row with no tick; `on_tip` its tick's words on hover), `verbs` the buttons it has, each
## `{key, label, tip}` with `pressed` (a toggle's state) and `off` (grayed, `tip` saying why) where they apply, done by [method
## act]. Rows are shown under their group ([method groups]). A row's prop whole, to be looked at in 3D, is [method prop_of] and
## [method model_of]. These defaults show nothing.


func title() -> String:
	return "Props"


func turns() -> bool:
	return true


func file_kind() -> Dictionary:
	return {"ext": ".prop.json", "label": "Props"}


## The groups rows stand under, in order: each `{key, label, tip}`.
func groups() -> Array:
	return []


## The rows standing now ([PropSection]'s note), in their groups' order.
func rows() -> Array:
	return []


## Row [param key] used ([param on] true) or set aside. "" done, else why not.
func set_on(_key: String, _on: bool) -> String:
	return "nothing here sets props down"


## Row or offer [param key]'s prop whole, to be built and looked at ([PropViewer]): `{name, thing, materials, hash}` - a [Props] spec
## and the materials its parts use - or {} where it has none.
func prop_of(_key: String) -> Dictionary:
	return {}

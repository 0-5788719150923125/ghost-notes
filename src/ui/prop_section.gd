extends ShelfSection
class_name PropSection

## PropSection - the props a presentation sets down, handed to the panel's Props card ([PropsCard]) by whatever shows them, as a
## show hands the Pacing card a [TuneSection]: the card draws, the section does, and with no section there is no card. No component
## names the card and the card names no component. What can be added is its shelves on the Dex ([ShelfSection], [DexWindow]).
##
## A row is a prop as it stands now: `{key, name, line, group, picture, on, verbs}` - `picture` an Image (null until it is taken),
## `on` whether the scene uses it (null for a row with no tick; `on_tip` its tick's words on hover), `verbs` the buttons it has, each
## `{key, label, tip}` with `pressed` (a toggle's state) and `off` (grayed, `tip` saying why) where they apply, done by [method
## act] - or with `opens`, which opens the Dex on what may take the row's place ([method choices]). Rows are shown under their
## group ([method groups]). A row's prop whole, to be looked at in 3D, is [method prop_of] and [method model_of]. These defaults
## show nothing.


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


## Where its props keep their versions and are refined ([PropVersions]), null where they have none.
func versions_of() -> PropVersions:
	return null


## Row or offer [param key] is now played by the prop kept as [param name] - kept so it could be refined, or another of its versions
## made the one used: the scene follows where it should (a desk's part chooses it; a table's thing takes its version). "" done, else
## why not.
func refined(_key: String, _name: String) -> String:
	return ""


## What may take row [param key]'s place, offered on the Dex (a choice of mugs for the mug), whose Use puts the one picked there;
## null where nothing can.
func choices(_key: String) -> PropSection:
	return null

extends ShelfSection
class_name PropSection

## PropSection - the props a presentation sets down, handed to the panel's Props card ([PropsCard]) by whatever shows them: the
## card draws, the section does, and with no section there is no card. No component
## names the card and the card names no component. What can be added is its shelves on the Dex ([ShelfSection], [DexWindow]).
##
## A row is a prop as it stands now: `{key, name, line, group, picture, on, verbs}` - an entry on the card ([EntryCard]) - `picture`
## an Image (null until it is taken), `on` whether the scene uses it (null for a row with no tick; `on_tip` its tick's words on hover),
## `remove_tip` what its × does where it can be taken off ([method remove]) or `remove_off` why it cannot, `verbs` the buttons it has, each
## `{key, label, tip}` with `pressed` (a toggle's state) and `off` (grayed, `tip` saying why) where they apply, done by [method
## act] - or with `opens`, which opens the Dex on what may take the row's place ([method choices]), or with `choices` (`[{key,
## label}]`, `chosen` the key picked now), a picker whose pick is done by [method act] as `<verb>:<choice>`. Rows are shown under their
## group ([method groups]). A row's prop whole, to be looked at in 3D, is [method prop_of] and [method model_of]; a section whose
## props do not turn ([method ShelfSection.turns]) opens nothing, and a row with no `picture` key shows none.
##
## A row may carry the properties a person can tune on it ([Roll]): `fields` (key -> a field row, [SchemaForm]'s shape, each unset
## field's `default` what it is now) and `values` (what is set), shown once its entry is opened - or always, with `open`, which has
## no × - and each change done by [method set_field]. These defaults show nothing.


func title() -> String:
	return "Props"


func category() -> String:
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


## Row [param key] taken off: its × pressed ([EntryCard]). "" done, else why not.
func remove(_key: String) -> String:
	return "nothing here takes it off"


## Property [param field] of row [param key] set to [param value] (null: unset, back to what it would be). "" done, else why not.
func set_field(_key: String, _field: String, _value: Variant) -> String:
	return "nothing here is tuned"


## Row or offer [param key]'s prop whole, to be built and looked at ([PropViewer]): `{name, thing, materials, hash}` - a [Props] spec
## and the materials its parts use - or {} where it has none.
func prop_of(_key: String) -> Dictionary:
	return {}


## Where its props keep their versions and are refined ([PropVersions]), null where they have none.
func versions_of() -> PropVersions:
	return null


## Whether row [param key] is refined by the section itself rather than through versions: its 3D view's Refine… is then the row's
## own (`refine`, [method act]) - a table show's table.
func refines(_key: String) -> bool:
	return false


## Row or offer [param key]'s prop kept in the library, as a person's Keep in the 3D view asks ([PropViewer]) - the only Keep a prop
## has - said by [method keep_line]. One held as a draft is kept with its versions. "" done, else why not.
func keep_prop(key: String) -> String:
	var pv := versions_of()
	if pv == null:
		return "nothing here keeps props"
	return pv.keep_in_library(prop_of(key), keep_line(key))


## What row or offer [param key]'s prop is said to be, kept: "" says nothing.
func keep_line(_key: String) -> String:
	return ""


## Row or offer [param key] is now played by the prop kept as [param name] - kept so it could be refined, or another of its versions
## made the one used: the scene follows where it should (a desk's part chooses it; a table's thing takes its version). "" done, else
## why not.
func refined(_key: String, _name: String) -> String:
	return ""


## The things it sets down that throw light, each tuned on the Environment card: `[{key, name}]` - `key` the name the scene reads its
## share by ([method Surroundings.share_of]). None by default.
func lit() -> Array:
	return []


## The things it sets down that make a sound of their own, each turned up or down on the Environment card: `[{key, name}]` - `key`
## the name the scene reads its share by ([method Surroundings.heard_of]). None by default.
func heard() -> Array:
	return []


## What may take row [param key]'s place, offered on the Dex (a choice of mugs for the mug), whose Use puts the one picked there;
## null where nothing can.
func choices(_key: String) -> PropSection:
	return null

extends RefCounted
class_name PropVersions

## PropVersions - where a section's props keep their versions and are refined ([PropSection.versions_of], [PropViewer]): a prop is
## kept by a name, and refining it adds a version beside the rest, which a person steps through and makes the one used - never
## another prop. The library's ([LibraryVersions]) is the one there is; these defaults keep none.
##
## A prop here is a section's [method PropSection.prop_of]: `{name, thing, materials, hash}`.


## The name prop [param prop] is kept or held as a draft by, by the hash of any of its versions; "" where it is neither.
func name_of(_prop: Dictionary) -> String:
	return ""


## Whether prop [param prop] can be refined: it is written as parts and materials (a thing a scene builds by code is not).
func refinable(_prop: Dictionary) -> bool:
	return false


## Prop [param prop] held as a draft where it is not kept yet - a home for its versions, kept by no one until a person keeps it - to be
## refined: `{name}`, or `{error}` saying why not.
func keep(_prop: Dictionary) -> Dictionary:
	return {"error": "nothing here keeps versions"}


## The versions of the prop kept as [param name], oldest first: each `{note, by, made, hash, name, line}` (the direction that made it,
## who did, when, what it is ([method ThingLibrary.hash_of]), and what it is called and said to be - the prop takes them when it is
## used).
func list(_name: String) -> Array:
	return []


## Version [param i] of [param name] called [param to] - the prop too, where it is the version used. "" done, else why not.
func name_version(_name: String, _i: int, _to: String) -> String:
	return "nothing here keeps versions"


## Prop [param prop] kept in the library a person has, said by [param line] - with every version it has where it is held as a draft
## already; one kept already is left as it is. "" done, else why not.
func keep_in_library(_prop: Dictionary, _line: String) -> String:
	return "nothing here keeps props"


## Whether [param name] is kept: in the library a person has, not a draft.
func kept(_name: String) -> bool:
	return false


## Which of [param name]'s versions is the one used, -1 for none.
func used(_name: String) -> int:
	return -1


## Version [param i] of [param name] built whole, to be turned ([method PropSection.model_of]'s shape); waits for it.
func model(_name: String, _i: int) -> Dictionary:
	return {}


## Version [param i] of [param name] made the one used, the prop taking its name where it has one of its own ([method name_of] its
## hash finds it after). "" done, else why not.
func use(_name: String, _i: int) -> String:
	return "nothing here keeps versions"


## Version [param from] of [param name] refined by an agent as [param direction] says, by who [param pick] chooses, begun and left to
## run whoever is looking: what it says and what comes of it are [PropRefining]'s. "" begun, else why not (one at work on it already).
func start_refine(_name: String, _from: int, _direction: String, _pick: Dictionary) -> String:
	return "nothing here can be refined"


## Version [param from] of [param name] refined by an agent as [param direction] says, by who [param pick] chooses (`{agent, model,
## effort}`, [AgentPick]): a new version added after the rest, not yet used. [param told] hears what the agent is doing as it works
## (`(line: String) -> void`). Waits for it: `{index, name}`, the new version's and what it is called, or `{error}`.
func refine(_name: String, _from: int, _direction: String, _pick: Dictionary, _told: Callable) -> Dictionary:
	return {"error": "nothing here can be refined"}


## The refining of [param name] under way given up.
func stop(_name: String) -> void:
	pass


## Whether an agent is refining [param name] now.
func busy(_name: String) -> bool:
	return false

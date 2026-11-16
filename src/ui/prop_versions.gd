extends RefCounted
class_name PropVersions

## PropVersions - where a section's props keep their versions and are refined ([PropSection.versions_of], [PropViewer]): a prop is
## kept by a name, and refining it adds a version beside the rest, which a person steps through and makes the one used - never
## another prop. The library's ([LibraryVersions]) is the one there is; these defaults keep none.
##
## A prop here is a section's [method PropSection.prop_of]: `{name, thing, materials, hash}`.


## The name prop [param prop] is kept by, by the hash of any of its versions; "" where it is not kept.
func name_of(_prop: Dictionary) -> String:
	return ""


## Whether prop [param prop] can be refined: it is written as parts and materials (a thing a scene builds by code is not).
func refinable(_prop: Dictionary) -> bool:
	return false


## Prop [param prop] kept, where it is not yet, to be refined: `{name}`, or `{error}` saying why not.
func keep(_prop: Dictionary) -> Dictionary:
	return {"error": "nothing here keeps versions"}


## The versions of the prop kept as [param name], oldest first: each `{note, by, made, hash}` (the direction that made it, who did,
## when, and what it is, [method ThingLibrary.hash_of]).
func list(_name: String) -> Array:
	return []


## Which of [param name]'s versions is the one used, -1 for none.
func used(_name: String) -> int:
	return -1


## Version [param i] of [param name] built whole, to be turned ([method PropSection.model_of]'s shape); waits for it.
func model(_name: String, _i: int) -> Dictionary:
	return {}


## Version [param i] of [param name] made the one used. "" done, else why not.
func use(_name: String, _i: int) -> String:
	return "nothing here keeps versions"


## Version [param from] of [param name] refined by an agent as [param direction] says, by who [param pick] chooses (`{agent, model,
## effort}`, [AgentPick]): a new version added after the rest, not yet used. [param told] hears what the agent is doing as it works
## (`(line: String) -> void`). Waits for it: `{index}`, the new version's, or `{error}`.
func refine(_name: String, _from: int, _direction: String, _pick: Dictionary, _told: Callable) -> Dictionary:
	return {"error": "nothing here can be refined"}


## The refining under way given up.
func stop() -> void:
	pass


## Whether a refining is under way.
func busy() -> bool:
	return false

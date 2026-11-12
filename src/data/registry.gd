extends RefCounted
class_name Registry

## Registry - reading any of ghost's registries, which are one shape: a Dictionary of rows, one per key, in
## the order they are offered, each row a Dictionary of fields. Every row has a `label` (what a person reads)
## and a `blurb` (a sentence or two: a tooltip, a line of the docs); the rest is its own kind's (a filter's
## `uniform`, a medium's `frames`, a component's `needs`).
##
## One row a thing, never parallel tables keyed alike: adding a thing is one row, and a key cannot be in one
## table and missing from the next. docs.py reads the same rows (`const`), so a field added to a row is in the
## docs without a regex of its own (next/structure.md).

## The label of [param key] in [param registry] - the key itself when there is none.
static func label(registry: Dictionary, key: String) -> String:
	return String(row(registry, key).get("label", key))


## The blurb of [param key] in [param registry], or "".
static func blurb(registry: Dictionary, key: String) -> String:
	return String(row(registry, key).get("blurb", ""))


## Field [param field] of [param key]'s row, or [param fallback] when the row or the field is missing.
static func field(registry: Dictionary, key: String, field_name: String, fallback: Variant = null) -> Variant:
	return row(registry, key).get(field_name, fallback)


## [param key]'s row, or an empty one.
static func row(registry: Dictionary, key: String) -> Dictionary:
	var r: Variant = registry.get(key, {})
	return r if r is Dictionary else {}

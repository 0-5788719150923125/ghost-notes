extends RefCounted
class_name NoteCards

## NoteCards - a note's component cards, built ONE way on whichever panel shows the note, and the
## two edits that change what a note is made of: attach and detach.
##
## A PANEL DOES NOT LIST ITS CARDS; THE NOTE DOES. Each workspace (the note's own panel, a reading's,
## a show of cards', the voice lab's) builds what only it has - its words, the voice lab's water - and
## hands the rest to [method build], which adds a card for each component the note has attached, in
## the order they stand on every panel; what a card shows of the workspace is handed in `ctx` (a
## reading's cast to its Voice). So a Storyboard attached to a note with a voice gets the
## same card a song's has, with nothing written for the pairing: it is not a feature of either
## panel. A card answers `KEY` (its block under `ghost:`), `capture()` and `apply(block)`, as every
## block card does.
##
## A NEED NOTHING PROVIDES IS A SENTENCE ON THE CARD ([method Components.needs_note]), never a
## control that silently does nothing: a Picture left on a note whose song was detached says what
## it is waiting for.
##
## ATTACH AND DETACH WRITE THE NOTE AND NOTHING ELSE ([method attach], [method detach]): the block
## that says a component is there is added or removed in the file, with what the panel's cards hold
## at that moment, and the panel opens the note again as what it now is. One path for every
## workspace, so a component that can be attached can always be taken off again.

## The components whose settings are a card any workspace can show, in the order they stand:
## the rows of [constant Components.REGISTRY] that name a `script`. Cards' and Proof's episodes
## first, then the voice that reads them: what produces the text stands above what shows it.
const KEYS := ["table", "proof", "voice", "voice_training", "picture", "letter", "actor", "storyboard", "look", "bookends", "youtube"]


## A card for each of [param attached] that is one of [constant KEYS] (and of [param ctx]'s
## `only`, when a panel builds some of them itself), added to [param panel]. Returns them by block
## key, in order. [param ctx]: `reading` (the note has a voice, so every medium is offered),
## `intro_tip` / `outro_tip` (what the bookends hold in this workspace's words), `only`.
static func build(panel: SidePanel, attached: Array, ctx := {}) -> Dictionary:
	var out := {}
	var only: Array = ctx.get("only", KEYS)
	for key in KEYS:
		if not attached.has(key) or not only.has(key):
			continue
		var card := make(key, ctx)
		var row: Dictionary = Components.REGISTRY[key]
		# the card's id is its row's `card` (the panel keeps each card's fold under it), its title
		# the row's `heading` where it has one
		var body := panel.add_card(String(row.get("card", card.KEY)), String(row.get("heading", row["label"])),
			row["family"], key)
		var why := Components.needs_note(key, attached)
		if not why.is_empty():
			body.add_child(_waiting(why))
		body.add_child(card)
		out[String(card.KEY)] = card
	return out


## The card of the component [param key]: the script its row names ([constant
## Components.REGISTRY], `script`), asked for a card for this panel. Loaded by path - nothing here
## names a card's class, which is what lets this file sit under every feature that brings one.
static func make(key: String, ctx := {}) -> Control:
	var path := String((Components.REGISTRY.get(key, {}) as Dictionary).get("script", ""))
	var script: GDScript = load(path) as GDScript if not path.is_empty() else null
	if script == null:
		push_warning("ghost: no card is built for the component '%s'" % key)
		return VBoxContainer.new()
	return script.call("for_note", ctx) as Control


## What a component is waiting for, at the head of its card.
static func _waiting(why: String) -> Label:
	var l := Label.new()
	l.text = "⚠  " + why
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	return l


## ATTACH the component [param key] to the note at [param path]: its marker block
## ([method Components.attach_blocks]) written into the file, over what the panel's cards hold now
## ([param held], so a dial moved a moment ago is not lost to the reopen). A component with a
## starter - a show of cards' brief - fills a note that has no words yet. Returns "" once written,
## or why it could not be; the caller opens the note again.
static func attach(path: String, key: String, held := {}) -> String:
	var add := Components.attach_blocks(key)
	if add.is_empty() or not FileAccess.file_exists(path):
		return "%s cannot be attached to this note." % key
	var ghost := NoteStore.blocks_of(path)
	ghost.merge(held, true)
	ghost.merge(add, true)
	var err := FrontMatter.write_block(path, ghost)
	if not err.is_empty():
		return err
	var starter := String((Components.REGISTRY[key] as Dictionary).get("starter", ""))
	if not starter.is_empty():
		var body := String(FrontMatter.split(FileAccess.get_file_as_string(path)).body)
		if body.strip_edges().is_empty():
			err = FrontMatter.write_body(path, FileAccess.get_file_as_string(starter), body)
	return err


## DETACH the component [param key] from the note at [param path]: its blocks
## ([method Components.blocks_of]) taken out of the file, every other block as the panel's
## cards hold it now ([param held]). A note left with nothing attached has no `ghost:` key at all.
## Returns "" once written, or why it could not be; the caller opens the note again.
static func detach(path: String, key: String, held := {}) -> String:
	if not FileAccess.file_exists(path):
		return "There is no note at %s." % path
	var ghost := NoteStore.blocks_of(path)
	ghost.merge(held, true)
	for b in Components.blocks_of(key):
		ghost.erase(b)
	return FrontMatter.write_block(path, ghost if not ghost.is_empty() else null)

# The panel as a deck

A note's panel is one deck of cards, in one scroll, with every card's title bar always in reach. Of three sketched readings (a deck whose edges pile, a deck that scrolls away, a fan at angles) the first was built, with any number of cards open.

## What it is

**One scroll.** Everything on a note's panel scrolls together. The Pipeline card is a card like any other, last in the deck, and its long list has no scroll of its own.

**Every card one click away.** A card scrolled past leaves its title bar in a pile at the top of the panel; one still to come has its bar in a pile at the bottom. Each bar's top line shows, so the way to any card is always in sight. A panel that fits has no piles.

**A card never folds.** A press on a bar, wherever it lies, brings its card into view whole: from a pile, or from where it stands cut off by the bottom pile. A card taller than the room comes with its bar under the bars above it, its start showing; one already whole in view stays put. A chip does the same. The folds kept in ghost.cfg's `[folds]` are no longer read (the Pipeline card's own groups still fold, and keep theirs there).

**A view at the end stays there.** Whatever grows while the view is at the end of the scroll keeps it at the end, in the last card or above it (a picture landing in a card above pushes the list down just the same), and a turn of the wheel lets go. A card a press brings is not dragged back to the end. A panel that fits is at its end only trivially, so it follows its last card alone: a note's words filling in as it opens leave it at its top.

**Nothing on a card scrolls of its own.** A box with a scroll of its own under a panel that scrolls takes the wheel from the panel the moment the pointer crosses it. So words too long for a line are a `TextField` (`src/ui/text_field.gd`): a heading, their first lines as the Body card shows a note's, and a click from a window to write them in - the Description (a show's and a note's), the Letter's index cards, the Pictures' style. A list grows with its rows, in the panel's one scroll - an actor's videos (with Tick all and Untick all above the list), a storyboard's entries. docs.py's rule "one scroll" fails a new one, and `panel_fit_check` walks the real panels.

**It moves.** A card a press brings glides there. Pointing at a bar in a pile spreads the pile there until the whole bar shows - the fan. A small window closes the piles up rather than taking the room from what is being read.

## How it is built

`Card` (`src/ui/card.gd`) is not a `FoldableContainer`, which draws its own title bar: a bar could not leave its card, lie over the next one, or slide. It has no fold; `reveal()` asks to be brought into view (`reveal_asked`), which the deck holding its bar answers.

`PanelDeck` (`src/ui/panel_deck.gd`) holds every card's own bar on one layer over the scroll, in card order, takes its presses, and puts each where it belongs each frame, on every scroll and on every layout: over its card, held inside the piles. They are the real bars, not copies, so Generate and Stop work from a pile. Off a bar, the pointer reaches what scrolls beneath; everything under a pile is covered by solid bars.

## Status

Built. Gates: `tests/ui/panel_deck_check.gd` (the deck), `tests/ui/panel_cards_check.gd` (the real panels' cards and chips); to look: `tests/ui/pipeline_look_probe.gd`, which opens a note on main as a click does. A press bringing a card whole awaits the author's hand.

Two faults showed only in a real note, after every panel gate had passed: `PipelineCard.put_on` joined the tree before it had its card, so Generate and Stop stood in the list, not on the title bar; and a component's × made its bar 34 px tall, so the next bar in a pile cut through its title. Both looked right on a panel built by hand (out of the tree, with no ×); the first said so only as an engine `ERROR:`, which fails no gate.

Left as they were, for the author to say:

- Masking's Markers stay pinned in the footer (`SidePanel.add_footer_card`), so the whole manage-markers workflow stays visible together. It is the only footer left, and its list is the one thing on a left-side card that still scrolls of its own. Into the deck, it needs no scroll of its own.
- The chips under the panel's heading now say much of what the piles say, and with no fold they have no open or closed to show: each brings its card, as its bar does.

One number to change: `PanelDeck.PEEK`, how much of a bar shows in a pile.

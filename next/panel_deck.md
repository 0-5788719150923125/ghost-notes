# The panel as a deck

Asked and built 2026-11-02, the day the Pipeline card was pinned under the scroll. The user: "It's weird that there are now
two panels on the left: one that scrolls, and one that is just frozen there ... They should all be scrollable ... a kind of
card-fanning approach, where cards stack or unstack, overlap or expand". Of three readings shown as sketches (a deck whose edges
pile, a deck that scrolls away, a real fan at angles) they picked the first, with any number of cards open.

## What it is

**One scroll.** Everything on a note's panel scrolls together. The Pipeline card is a card like any other, last in the deck, and
its long list has no scroll of its own.

**Every card one click away.** A card scrolled past leaves its title bar in a pile at the top of the panel; one still to come has
its bar in a pile at the bottom. Each bar's top line shows. So the way to any card is always in sight, wherever the panel
is scrolled - what pinning the Pipeline card was for, without a second panel. A panel that fits has no piles.

**Folded cards overlap**, a later bar on an earlier one, as in a pile.

**A press.** On a bar where its card is, it folds or opens the card. On a bar in a pile, it brings the card into view, opening it if
it is folded; an open card in a pile is never folded by that press. A card opened any other way (a chip) comes into view too.

**A view at the end stays there.** The user, 2026-11-03: "If I'm scrolled all the way down, looking at the pipeline, and I click on
"Generate" - that process can insert new steps into the pipeline card, which causes it to start overflowing, requiring me to scroll
again". So whatever grows while the view is at the end of the scroll keeps it at the end, in the last card or above it (a picture
landing in a card above pushes the list down just the same), and a turn of the wheel lets go. What the viewer opens is not followed: it comes as a
press brings it, its start in view. A panel that fits is at its end only trivially, so it follows its last card alone: a note's words
filling in as it opens leave it at its top.

**Nothing on a card scrolls of its own.** The user, 2026-11-03: "the inner scrolling of the YouTube card's "description" can be pretty
annoying and unexpected. At the same time, that text is hard to read, and it's annoying that I even have to scroll it, to read it."
A box with a scroll of its own under a panel that scrolls takes the wheel from the panel the moment the pointer crosses it. So words too
long for a line are a `TextField` (`src/ui/text_field.gd`): a heading, their first lines as the Body card shows a note's, and a click from a window to
write them in - the Description (a show's and a note's), the Letter's index cards, the Pictures' style. And a list grows with its rows, in the panel's
one scroll - an actor's videos, Synthesis' Collection, a storyboard's entries. docs.py's rule "one scroll" fails a new one, and
`panel_fit_check` walks the real panels. An actor's videos are as long as they have videos: their Tick all and Untick all stand above the list for that.

**It moves.** A card slides open and shut, what is under it going with it. Pointing at a bar in a pile spreads the pile there until
the whole bar shows - the fan. A small window closes the piles up rather than taking the room from what is being read.

## How it is built

`Card` (`src/ui/card.gd`) stopped being a `FoldableContainer`, which draws its own title bar: a bar could not leave its card, lie over
the next one, or slide. The API stayed (`title`, `folded`, `fold()`, `expand()`, `folding_changed`, `add_title_bar_control`).

`PanelDeck` (`src/ui/panel_deck.gd`) holds every card's own bar on one layer over the scroll, in card order, and puts each where it
belongs each frame, on every scroll and on every layout: over its card, held inside the piles. They are the real bars, not copies, so
Generate and Stop work from a pile. Off a bar, the pointer reaches what scrolls beneath; everything under a pile is covered by solid bars.

## Status

Built 2026-11-02. Gate: `tests/ui/panel_deck_check.gd`; to look: `tests/ui/pipeline_look_probe.gd`, which opens a note on main as a click
does. Looked at under xvfb only, its motion not yet by the user.

Found opening a real note, after every panel gate had passed (the first by the user, on Brick by Brick): `PipelineCard.put_on` joined the
tree before it had its card, so in the app Generate and Stop had stood in the list, not on the title bar, since the card's first build; and a
component's × made its bar 34 px tall, the title lower, the next bar in a pile cutting through it. Both looked right on a panel built by hand:
out of the tree, with no ×. The first said so only as an engine `ERROR:`, which fails no gate.

Left as they were, for the user to say:

- Masking's Markers stay pinned in the footer (`SidePanel.add_footer_card`): asked for by name once ("the whole manage-markers
  workflow stays visible together"), and they are not what was complained of. It is the only footer left, and its list is the one thing on a
  left-side card that still scrolls of its own: pinned, nothing else would scroll it. Into the deck, it needs no scroll of its own.
- The chips under the panel's heading now say much of what the piles say. Ctrl-click on one still opens a card alone, which nothing
  else does.

One number to change: `PanelDeck.PEEK`, how much of a bar shows in a pile.

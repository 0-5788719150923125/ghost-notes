# Surroundings: what is round the table, in every direction

## Status

**Thought through, not decided, nothing built.** A game's table now has cameras on every side of it ([Cameras]), and past
the table's edge they see a brown void: the table show's room is one painted backdrop (`image:backdrop`, [method
TableMedium._place_backdrop]), stood beyond the far edge and seen only from the table's head. The author wants a place round
the whole table - a room in a house first, later anything (a great hall, outdoors) - so no one shape of room is the answer.

What the author has judged:

- **Not a scene built of geometry and props.** A room, hall or landscape built from blocks, props and procedural materials
  would be plain long before it is rich, and building large scenes that way is work the author does not want. Geometry may
  still be used where nobody sees it (a guide below).
- **Not a box of four painted walls** as the answer: one kind of room among many.
- Open: the tiled painting below, and a place captured from a game's window (a panorama first, splats after).

## The tiled painting (the leading idea)

A layout is drawn first, then the sphere round the table is cut into windows, and the image model paints each window in turn,
told what is there and shown what is painted beside it already.

1. **The layout**, written by an agent as data: what the place is, and where its big shapes are - walls and their openings, a
   long table, columns, a fireplace, a window and what is beyond it; outdoors, the ground, tree lines, hills, the sky. Never
   shown: it only says where things are.
2. **The guides.** The layout built as a blockout (flat, untextured volumes, each shape a flat color by what it is) and
   rendered from the table's middle into overlapping windows, each a perspective view - about 8 round and 3 up, 60 degrees
   wide. Each window has a picture of what is where (the flat colors, with their edges drawn), and a depth.
3. **The painting.** Each window is painted from its guide ("repaint this, a great hall at night, every shape where it is"),
   the windows beside it already painted given as references so it continues them. A window painted after its neighbors can
   be handed them pasted into its guide, so the overlap is theirs to match. The backends take references and Grok can edit a
   picture; none takes a mask, so matching is by reference and overlap, never by masked in-filling.
4. **Joined.** The windows are laid back onto the sphere where they were cut from, blended across their overlaps.
5. **Projected onto the blockout, not a sphere at infinity** - matte painters call this camera projection: each painting is
   cast from the table's middle onto the volumes it was painted from, so a wall stands at its real distance and shifts as a
   camera circles the table. What a camera sees that the middle could not (behind a column) is smeared; from a table's
   cameras, a meter or two from its middle, that is little.

Why it may hold up: about 24 windows at 1536 x 1024 give about 25 pixels a degree, near what a frame shows; the background is
dim and soft under the table's lamp and the miniature's blur ([TableGame] `miniature`), where a painting's softness reads as
depth of field. A place is made once and kept: it belongs in the Library and the Dex, as a prop does, and every episode set
there reuses it.

Risks: windows that do not agree (light, wallpaper, a table that changes length between two of them); a guide followed
loosely; a painting's light against the table's own (asked for even light, darkened by the scene's light falloff); the
poles (the ceiling or the sky straight up, the floor under the table - the table hides most of the floor). About 24 painter
calls a place.

## Gaussian splats

Splats are fitted to many views of one place that agree with each other. Real footage gives them; generated views do not
agree well enough without models built to make many views of one scene, which are heavy (next/supply_chain.md,
feedback on heavy models). A splat place fitted from the tiled painting's own windows would be the tiled painting with more
steps. Not pursued unless consistent views can be had another way. The likeness work (next/likeness.md) has our own splat
rasterizer if they ever are.

## Captured from a game's window

The author's idea: a place captured from any game by its pixels alone - a capture tool that drives the game and records its
window, never reading an engine. Every engine is different; a window is a window. The rights are the author's call.

- **A spin first: a panorama, with no camera to solve.** Stood in one spot, the tool turns the view by fixed mouse steps and
  captures each, across and up and down. How far a step turns is measured, not known: turned until the first frame comes round
  again is 360 degrees, and a game stops the view at straight up and straight down. Each frame's middle (no weapon, no HUD; a
  game's own console hides them where it can) is laid onto a sphere at its known angle and blended - a panorama many thousands of
  pixels round from any game, with no camera-solving and no model. No parallax: a sphere round the table, which is what a
  room far off behind a lit miniature most needs.
- **Then splats, for parallax.** Captures from many spots, the views' cameras worked out from the frames themselves
  (structure from motion, as splats of real places are made from video), splats fitted to them, drawn round the table by our
  own rasterizer (next/likeness.md). The camera-solving is the new and heavy part (a tool such as COLMAP: next/
  supply_chain.md); the likeness work fits splats guided by face and body tracking, never a moving camera in a room.
- **Traps:** what moves in the game (people, water, flicker) and its own lighting changes ruin a fit and smear a panorama;
  motion blur and depth of field are turned off in the game's settings; the window is captured on Linux through the display
  (X11 grab or PipeWire) and driven by synthetic input (xdotool or ydotool), on a desktop the author is not using.

## What it replaces

The table show's backdrop picture, for any show whose cameras leave the table's head; and the brown void past a game's table.

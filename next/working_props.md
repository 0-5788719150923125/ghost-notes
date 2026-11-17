# Working props: one kind of prop, its behavior as data

Every thing a scene sets down is a [Props] spec - parts, materials and the working parts a scene plays - so any of them can be
kept, pictured, swapped for another make, refined into versions and put on another scene. A scene keeps its program (what a screen
shows, when a phone rings) and its dressing (cables between things, the paper's fall, the room); the prop keeps its geometry, its
looks and how its parts answer what the scene feeds them.

## Status

Built: faces, lights and the `follow` law in [Props] and [Motions]; [PropRig] (and its `copy`, one make built once for a row
of phones); every thing the Dispatch desk works is a role played by a make (`data/props/*.prop.json` its own, any scene's to
reuse), its behaviors fed through the make's rig; the Dispatch desk's Props card a row per role (Choose…, Keep, the 3D view,
Refine…); the refiner told the working parts and to keep them; a Letter desk's things refined into versions and played by the
version used. Gates: `tests/table/prop_rig_check.gd`, `dispatch_props_check` (every own make whole, its faces, its hinges about
points on themselves; a kept make playing the desk), `prop_refine_check` (the terminal and a Letter desk's thing refined).

The user judges: the desk's things as Props draw them (the prop shader under the desk's lamp, where StandardMaterial3D drew them
before), a first Refine of the terminal, the radar and a phone, and the names (face, feed, follow).

Not built: the face programs (below), words on the Letter's cards and the dog tag as faces, kept props anywhere on a desk (only a
desk thing's own versions), and the chair, the desk, the satellite's arm and the cables as props.

## What holds

- **One geometry kit and one material registry**: a scene's things are [Props] shapes and materials (`plastic` for a computer's
  case, a phone, keys), never meshes and StandardMaterial3D written beside them, so an agent can read and change any of them.
- **One identity and one way to picture**: a make is its spec, hashed by `ThingLibrary.hash_of` and pictured by [PropStudio]
  from it on a worker, never by building a scene to photograph one thing.
- **Behavior is the make's data**: a hinge, a slide, a light or a glow follows what the scene feeds it (`follow`); the scene
  feeds numbers and hands pictures, and never poses a part by name. A make lacking a part simply does not move it.
- **Layout reads the make**: the camera frames a thing's faces where its make has them, and the scene's dressing runs between a
  make's named points (the keyboard's `cable`, the terminal's `wire left`, the receiver's `antenna 1`, the printer's `slot`).
- **Words on things are faces** (`text`, a Label3D in the hand asked for), drawn wherever the prop is pictured.

## The design

- **A face** (shape `face`): a flat panel, upright, facing the thing's front, placed by its middle - a screen's glass, a dial, a
  meter, a label. A scene hands it a picture by the part's `name`; with none it is its material, lit by `lit`. `glass` says how a
  screen shows a picture (a tube's bulge, scanlines, bloom, black and white, snow); `text` is words printed on it, built as a
  Label3D, so a picture of the prop shows them too, and a scene may hand it other words.
- **A light** (a part's `light`): a spot or a point at the part, built dark; a rig lights it. A host with no rig never does (a
  lamp kept and set on a table stands unlit; its picture on the Props card is unlit), and the views an agent refining it is shown
  and the 3D view play it as its scene does at rest, so a light refined is seen changed. A lamp's light is its bulb's: inside its
  shade, pointing out of the shade's opening, its cone no wider than the opening.
- **The `follow` law** (a part's `runs`): the channel is a formula every moment, of the video's time `T` and what the scene
  feeds it (`v`, the feed named by `feed`) - a needle following the signal, a knob the gain, a lid how open the phone is, an LED
  blinking. Channels: a hinge's angle, a slide's offset, `glow`, `shown`, `light`. The puppeteer is never told it; at a table,
  where nothing is fed, `v` is its `rest`.
- **[PropRig]** plays a built prop: its faces, lights and working parts by name, its points where it stands, and `pose(T,
  feeds)`. Any scene can play any prop through it.
- **A role** ([PropMakes]): every thing a scene works. Its row names its own make (`own`: a `.prop.json` shipped in
  `data/props/`, the same file Export writes; or a recipe drawn from a number), the faces the scene fills (`faces`: a make without
  them is not offered), and the feeds it hands (`feeds`). The scene keeps the choice in its note.
- **The scene** builds each thing from its role's make, places it, lays its dressing between makes' named points, frames the
  camera on its faces, and each frame hands feeds and pictures. It never names a part's shape.

## Open

- **Face programs**: the terminal, the radar, the scope, a phone's screens and the clock's cards are 2D programs drawn by
  [DispatchScreens]. As a registry of programs any face can name (`shows: terminal`), a terminal kept and set on a table could
  run, fed by whatever plays it.
- A Letter desk's card words and the dog tag's name as faces, fed by the desk, so a refined card keeps its writing in place.
- A table show feeding its things (a television at the table showing a picture).
- Whether a refined make that drops a face its role fills is offered (now: the scene's own plays the role, and says so).

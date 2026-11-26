# Surfaces

What a thing's surface carries beyond its material's own look, written by an agent and kept in the library: first ornament (relief and
where a color is laid in it), then whole materials, perhaps painted tiles. A prop's shape is its parts; its surface is its material and
what is worked into it.

## Status

Built (phase 1, ornament):

- **An ornament of its own** (`Ornaments` in `src/table/`): the body of one shader function, `own_ornament(p, cell, uv, s)` in
  `shaders/prop_common.gdshaderinc`, returning `vec2(relief, paint)` at each point of a cell laid out round a part (cells as wide round
  it as they are tall, in the band `from`-`to` of its height, `count` round). It may call GLSL's math and the drawing helpers beside it
  (`Ornaments.HELPERS`: circles, boxes, segments, spirals, five-pointed stars, rotation, strokes, fills, noise). Checked before it is
  compiled (`Ornaments.check`: no `TIME`, no screen or texture, no `while` or `discard`, no name in capitals but `PI`/`TAU`/`E`, at most
  two loops of sixteen turns counting up by one, at most 4000 characters, a `return`), then compiled into a variant of the shader its
  material uses (`Ornaments.shader_for`, kept once a process by what it is; the opaque, glass and lens shaders all carry the hook).
  The renderer's own errors come back line by line in the agent's code (`Ornaments.compile_errors`, a `Logger` listening while it
  compiles).
- **Worn by a prop** (`Props._sanitize_ornament`): `{"kind": "own", "code": ...}`, or `{"kind": "<a kept ornament's name>"}` - drawn as
  that one's version used, so every prop wearing it follows a version chosen. Ornament code 11 (`Props.ORN_OWN`).
- **The library** (`OrnamentLibrary`, shelf `ornaments`): a folder each, `ornament.json` (`{name, words, versions: [{code, said}], used}`)
  beside the designer's conversation. Versions kept, never deleted. A swatch shows one: a turned brass vase and a stone plaque wearing it
  (`OrnamentLibrary.swatch`), photographed as any prop is (`PropPictures`).
- **The designer** (`OrnamentDesign`, `OrnamentTools`, `rules/table/ornament_designer.yaml`): a `WriterChat` whose text is the body;
  read, edit, write and RENDER (compiled, its errors told back, and photographed from the front and the side on the swatch). A turn that
  leaves new code that compiles is a new version, used. Made and refined in a Refine… window (`TextRefine`); the first thing the author
  says is the ornament's words. Polled each frame by a node of its own.
- **The Dex** (`OrnamentShelf`, category Surfaces): a tile to make one (Make…), then each kept one with its swatch, its words and which
  version is used, Refine…, ‹ and ›, its name changed in place, Remove.
- **The Props card** (`EpisodeProps`): Ornaments worn - the kept ornaments an episode's things wear, each with Refine… and its versions.
- **The agents**: the set dresser and the prop refiner are told the ornaments kept (`OrnamentLibrary.listing`, the shared thing
  language), each worn by its name; the prop refiner that ornament is made of the language's pieces, a kept one among them.

Gates: `tests/table/ornaments_check.gd` (the check, the variant, a prop wearing one, the library, the designer's prompts, the shelf);
`tests/table/ornament_compile_check.gd` (GPU: every prop shader compiles with the hook, a variant compiles whole, a broken body is told at
its own line, a swatch is photographed).

For the user to judge:

- A first ornament made with a designer from the Dex (Surfaces, Make…), and a prop refined to wear it.
- Whether the swatch (a vase and a plaque) shows an ornament well enough to judge it, for the designer and on the shelf.
- Whether the set dresser should reach for kept ornaments on its own, or only when a brief or a refinement asks.

## Open

- **Whole materials** (phase 2): color, roughness, metal and glow written as functions, a material kept and worn by its name.
- **Painted tiles** (phase 3): the image model paints a seamless tile, which becomes a surface's color and relief - engraving-like
  detail that is hard to write as math.
- **A card of its own** for what a note's props wear, if the Props card's group is too little.
- **First use compiles on the app's thread**: a variant is compiled where its material is made (a table's build, on a worker), and the
  renderer compiles its pipeline the first time it is drawn; a show with many new ornaments may hitch once.
- **Export and Import** of a kept ornament, as props and voices are handed on.

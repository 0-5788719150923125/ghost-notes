# Surfaces

What a thing's surface carries beyond its material's own look, written by an agent and kept in the library: ornament (relief and where
a color is laid in it), texture (what it is like to the touch, all over it), then whole materials, perhaps painted tiles. A prop's shape is its parts; its surface is its material and
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

Built (phase 2, texture - what a material is like to the touch):

- **Every material's surface** (`Props.TEXTURES`, `sanitize_material`): `texture` a relief worked all over it - grit, pitted,
  cracked, chipped (a struck flint's scallops), fibers, brushed, lumpy, granular (facets, some in `color2`), pebbled, rough and
  crumbled (noise at every scale, its octaves fading out below a few pixels - heavy roughness, or sharp broken creases), and bricks,
  tiles and planks (their joints in `color2`, laid on the plane each face is nearest to) - with `bumps` (how deep) and
  `texture_size` (its features, centimeters); and `mottle`, how unevenly it is polished (soft patches `grain` across, some duller,
  some glossier). Drawn in the thing's own space (`texture_at`, `surface` in prop_common), so nothing tiles or seams; its hollows
  rougher, darker and dull - a hollow reflects nothing and takes less of the room's light (specular occlusion, as a game's cavity map
  gives: a pit's steep wall seen at a glancing angle otherwise catches the light white however rough it is); detail finer than a few
  pixels fades into roughness, as a normal map's mipmaps do, and a line is never drawn thinner than a pixel. What is seen through
  (clear glass, crystal and liquid) shows none.
- **A bumped normal faces the eye** (`toward_eye` in prop_common): tipped past edge-on by a steep pit's wall it came back as a white glint
  in the multisampled 3D view, however rough the surface (ornament_compile_check holds it, in a real PropViewer).
- **Dull is dull**: a clear coat fades out below polish 0.45 and is gone at 0.15 (`glazed`), and raw stone at polish 0 is as rough as
  paper and reflects little even at a glancing angle (its specular 0.12).
- **A clear liquid is seen through** (`Props.see_through`): from clarity 0.8, as clear crystal is - water, tea, wine in a jar - tinted
  by its color; below, opaque with light in its depth. What is seen through solid draws before hollow glass whatever the angle
  (`LENS_FIRST`), or a vessel's etched band came and went as it turned; and a liquid bends what is behind it a quarter as hard as
  glass (`LIQUID_BEND`), and anything seen through solid bends only as deep as there is of it to look through (prop_lens
  `THROUGH_FULL`): none where it touches what it rests on, or its floor seen from below opened a gap in the mud under it. Glass etches a motif (stars, dots) but
  never flutes or hammering, which are its shape (`etched` in prop_common).
- **A glass's color is how deep it is** (prop_glass, `Props.deep_glass`): near white clear, a light color a tint, a dark one (an amber
  medicine bottle) hard to see through yet translucent and its color, never black; deep glass writes depth (`_glass_deep`) so its near
  wall hides its far wall.
- **A texture of its own** (`Ornaments.HOOKS` `texture`): the body of `own_texture(p, n, s)` returning `vec3(relief, rough, tint)`,
  `p` in units of its size; checked and compiled as an ornament is, into one variant with an ornament of its own beside it. Kept on
  the same shelf with `kind: texture` (`OrnamentLibrary`), made by the same designer told it writes a texture
  (`rules/table/ornament_designer.yaml`), its swatch a clay bowl and a stone block; the Dex's Textures shelf, Surfaces worn on the
  Props card; a material wears one by its name as its `texture`, and keeps the version it wore last if it is removed.
- **The agents**: the prop language says what each field does and when to use which (`Props.describe`, SURFACE); the set dresser and
  the prop refiner are told the kept textures; the refiner that a surface's shine and roughness are its material's.

Gates: `tests/table/ornaments_check.gd` (the check, the variant, a prop wearing one, the library, the designer's prompts, the shelf;
a texture's check, variant, library, material, designer and shelf);
`tests/table/ornament_compile_check.gd` (GPU: every prop shader compiles with the hooks, a variant compiles whole, a broken body is told
at its own line, a swatch is photographed - an ornament's and a texture's).

For the user to judge:

- A first ornament made with a designer from the Dex (Surfaces, Make…), and a prop refined to wear it.
- Whether the swatch (a vase and a plaque) shows an ornament well enough to judge it, for the designer and on the shelf.
- Whether the set dresser should reach for kept ornaments on its own, or only when a brief or a refinement asks.
- The textures on real props: a flint refined to be duller and rougher, the built-in ones on a table at the show's distance.

## Open

- **Whole materials**: color, metal and glow written as functions too, a material kept and worn by its name (a texture already
  writes relief, roughness and where the second color shows).
- **Painted tiles** (phase 3): the image model paints a seamless tile, which becomes a surface's color and relief - engraving-like
  detail that is hard to write as math.
- **A card of its own** for what a note's props wear, if the Props card's group is too little.
- **First use compiles on the app's thread**: a variant is compiled where its material is made (a table's build, on a worker), and the
  renderer compiles its pipeline the first time it is drawn; a show with many new ornaments may hitch once.
- **Export and Import** of a kept ornament, as props and voices are handed on.

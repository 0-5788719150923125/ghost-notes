# The picture painted first, painted again in layers

Opened 2026-11-09. The user, after weeks of a painter that guessed what to lay from the picture's colors: "what if we deconstructed the
entire mask right from the start? Split it into layers/stages with alpha maps defined for each one, along with instructions about what to
do at each step, which tools to use" - then, of generating the layers instead of cutting them: "generate MULTIPLE images, each one
including changes from the last ... image 1 would be the white base, image 2 would include the rust regions, image 3 would include the
black lines". And: "the Godot app can generate a mask, but we will never see the reference image in the UI".

## The approach (proved in the lab first - `lab/paint/`, gitignored)

1. **The picture painted first** (`image:face`), as before, checked by the art director (`check:face`).
2. **The order it is painted in** (`layers`): the art director, shown the picture, writes the layers a hand lays it in, broad to fine -
   each said so a painter lays only it, marked `soft` where it has no edge of its own (a shading, a haze).
3. **Each layer painted over the one before** (`image:layer:K`): the image painter, shown the picture so far and the finished picture,
   lays only that layer. What a layer lays is then exactly what changed between two steps - its region and its colors, soft where the
   change is soft - never guessed from colors. The design and its layers are one thing.
4. **Each layer laid with real marks** (the lab's `layers_paint.py` + `optimize.py`): its thin parts traced on its own picture (a crackle's
   network, lashes, a brow); its broad parts painted by strokes found by gradient descent through a soft model of the very strokes the
   lab lays (DiffVG, Li et al. 2020; Stylized Neural Painting, Zou et al. 2021) toward the step's own picture over the canvas as it
   stands - each layer paints only its region; where error remains, more strokes (e-David's loop, Deussen et al. 2012); a soft element
   worked over wet. Small round parts made dots.

Lab results, 327484 (crackle mask): the crack network with its junctions and gold threads, a crisp lid with lash line and lashes, the
tear with its gold rim, clean runs, shaped glossy lips with their smear, a teal-to-indigo bruise with a violet haze. 11 Codex calls (about
40 s each, cached by prompt and images), about 46 minutes of painting, about 5 minutes to solve on the RTX 5060 Ti.

## What is built in the app (2026-11-09)

- **Every picture an episode's agents made, seen** (`EpisodeFeed.made_pictures`, `MadePictures` on the Pictures card): the picture to
  copy, its layers, the cloth, the room, the depth, the backs, the cards' paintings, a game's pictures - a thumbnail each, full size a click
  away, stepped through in order. Generic: any maker says its own in `made_pictures`; the Pictures card names none. The card now comes
  with a table show too (`comes_with`), standing while there is any picture to show. Making one again stays its row on the Pipeline card.
- **The layers as episode steps**: `layers` (`layers.json`, the art director - rules `table/art_director.layers`) and `image:layer:K`
  (`layer_K.png`, the painter - rules `table/painter.layer`, the picture so far and the finished picture attached), each kept only if it
  lies on the surface (`Skins.face_fit`). Rows on the Pipeline card's Episode section, group Layers: a layer's ⟳ paints it and the layers
  after it again; the picture's ⟳ throws all of them away. Gates: skin_step_check (order, inputs, what a redo throws away, files,
  prompts), pictures_card_check (shown under the full frame; the control: none made, put away).

## The painter at the table (built 2026-11-09)

**The lab became the painter, Godot the player.** `hosts/paint/` is the lab's Python run as a host, as the voice is (`run.py <spec.json>`,
its own `Deps` environment `paint_venv` - numpy, SciPy, Pillow, PyTorch; the GPU where there is one). When an episode has layers, the
producer's skin step (`TableProducer._make_skin_host`) writes a spec (the bare picture, the surface's place in it, the table's creams, the
layers and their pictures) and runs it; `export.py` writes, per element - a run of one layer's marks with one tool in one paint - its
program on the show's own pace (`Skins._Prog` keys and strokes, `Skins`' constants line for line) and the maps skin_paint.gdshader draws
(`cover`, `when`, the staged `built`/`built_when`, `tint`). `_land_skin_host` keeps them as the design (`skin.json`, each element's
`plan.host` naming its output), its tool the table's nearest, its beat where it begins in the painting's time. `TablePaint._from_hosts`
plays every such element from its maps and program - never laid again by the show's own painter. What the painter saw is what the show
draws, by construction (`hosts/paint/test_export.py`: the maps laid in order come to the painter's canvas; control, the reverse order).

- **A layer's broad parts** are optimized part by part, then laid together, the broadest brush first through its paints (`optimize_layer`):
  part by part, each brush taken up again for each, 327484 had come to 52 acts (`Motions.MAX_ACTS` is 40).
- **A thin part's paint** is read from what each point became over what it was (`laid_paints`): read as a color, the gold threads had
  been traced in grey, and lines redrawn a pixel aside by the image model had outweighed them.

Open questions for the author:

- **The environment.** PyTorch is large (about 3 GB with CUDA); the first painting installs it. The optimizer also runs on the CPU,
  slower. The rule is "nothing from upstream until a week old, every helper sandboxed" (next/supply_chain.md).
- **The sponge.** The lab's sponge is a disc with pores; the table's is a real shape with sides (`TablePaint._side_touch`).
- **The time.** About 47 minutes for 327484, a third of it the crackle's 550 lines. The readers' passages are written to the work's length.
- **The rust mask** (257002): its layers made and painted in the lab; judged by the author.
- **The hand** (feedback 0020; the author: "a hand that generally tries to keep its whole brush inside of the edge; however hands can
  make mistakes, and spill over the edge, dragging/blending color with it ... clean that up with more white (or other colors), or ...
  wipe it away with a cotton swab ... we want naturally-looking behaviors here"). Built 2026-11-09, `hosts/paint/test_hand.py`: a fat
  brush's pulls a whole touch inside their region, a smaller brush where it is narrower (`plan.py` `_feather_area`); a mark that changes
  nothing never made (`solve.py`); a blend drags color along (`marks.soften`'s `drag`); a fat brush's every blending pull drawn as a hand
  draws it - a steady wander, now and then a slip aside or a run past its end, seeded (`marks.slipped`; the optimizer's broad strokes are
  laid as found, not yet slipped); and after each layer its spills cleaned - a small or
  faint one blotted with a cotton swab (`marks.blot`, tool `bud`), a bigger one painted back over in the color under it
  (`layers_paint.tidy`). The swab is a stick with a cotton tuft on the fixed table (the brief), a tuft kind of its own in the show.
  Not yet judged: how often a hand slips (`SLIP_EVERY`, `OVER_EVERY`), how much a blend drags (`FEATHER_DRAG`, `SMUDGE_DRAG`).

## Status

The made-pictures feed, the Pictures card on table notes and the layers steps: built and gated, not yet seen by the author in the app.
The painter host and the show's playback: built; 327484 stood from the host's output in `paint_preview_probe` (the bruise, runs, closed
eye and brow as the lab painted them). Run from the app end to end on 732687 (2026-11-09) and watched: feedback 0010-0020 found and fixed
the sponge's reloads going to no pot, its base patted by the corner, a puff left in the air, dead air after a silence, a pull's first pass
shown half its color, the handle following each wiggle, the flat brush flipping, a brush never touching its paint or towel, hairs bent
toward the face when lifted. The fixes in the host (each press's side, pulls turned and gathered by their way, staging by the canvas)
reach an episode only when its painter runs again.

Feedback 0001 (2026-11-09, the second numbering): the sponge dipped into the amber pot and laid a grey-green. The show took every element's
paint from the cream nearest its color, never the pot the painter named (`plan.pot`) - 39 of 732687's 103 elements went to another pot,
amber and black mixes to the clear gloss; now the named pot (`TablePaint._pot_of`), at once. The base had been a mix (olive and white)
from one pot; now one pot's paint (`plan.py` `_base`, white for 732687), and its presses fall where a hand puts them, not on the sweep's
lattice, whose holes had made a grid of the forehead (`PAT_WANDER`; `test_hand.py` 7-8). Those two reach 732687 when its painter runs again.

Feedback 0009-0010 (2026-11-10): paint showed away from the brush. A move between elements took 1.4 s however far it went (a brow to a
chin, up over the nose, its handle swung), its hand at up to a metre a second where the solver carries a held tool about 0.58; the body
fell behind and the element was laid where it was not. Now each move and trip takes as long as its way needs (`TablePaint._paced`,
`MOVE_PACE`; `paint_check` `_paced_ways`): on a made scene, frames that moved the tool over 2 cm went from 81 to 21. And inside an
element: a liner's chin, drawn out from its middle, swung its handle 100 degrees in the 0.41 s between two strokes, its body 63.5 mm
behind its hand - the black mark of 0010. Each way between keys is now given the time its body needs and the program's reveal maps are
carried to the new times (`TablePaint._pace_keys`, `KEY_PACE`; `paint_check` `_paced_keys`): 0.1 mm, the chin 1.1 s longer. Show-side,
so 732687 has both at the next launch. Open: acts paced longer could run past their words; a liner put back in its jar is held 39 mm
off its place by the jar for a moment (as before). A brush rinsed or dried, stopped short of its hand (the table under a cup's floor),
had its hairs laid as its hand had them, curled in the water; now as it is drawn, straight where it does not reach (`TablePaint._lay_on_plane`,
`paint_check` `_laid_as_drawn`).

Feedback 0011 (2026-11-10): white bands inside the diamond's corners - the soot layer's fade (`el_208`, the clean blender): its band 5 mm
past the soot crossed the diamond's line at its corners, and every pull, laid whatever it does, took up the white past the line and
carried it into the plum. Now a fade lays a little past its layer but takes up only what its layer is laid on (`plan.TAKE_INSIDE`,
`untaken`; `test_hand.py` 12); and a part painted by numbers works only its own borders wet, a feather's reach inside its edge
(`layers_paint.OWN_BORDERS`; 10).

Feedback 0012 (2026-11-10): "weird black smudges being painted along the chin, not even touching the brush" - not the brush's lag (0010)
but the painting itself: the image model draws the mask's silhouette a pixel or two aside in every picture, blended into the black past
it, and layer 6 (the right eye socket) read the shift as a thin dark change round the whole face; its near-black liner (`el_224`, 134 s)
traced the jaw in dashes on the steep rim. Now no layer changes the face's own edge (`layers_paint.RIM_OFF`, 1.5 mm; `test_hand.py` 11).
These three reach 732687 when layers 4-6 are painted again (done 2026-11-10, below).

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

## Status

The made-pictures feed, the Pictures card on table notes and the layers steps: built and gated, not yet seen by the author in the app.
The painter host and the show's playback: built; 327484 stood from the host's output in `paint_preview_probe` (the bruise, runs, closed
eye and brow as the lab painted them). Not yet run from the app end to end, nor watched by the author.

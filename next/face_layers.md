# The picture painted first, painted again in layers

A painter that guessed what to lay from the picture's colors gave way to one that deconstructs the picture: the mask is split into
layers, each with an alpha map and instructions for what to do and which tools to use. The layers are generated as images, each
including the changes from the last (image 1 the white base, image 2 the rust regions, image 3 the black lines), and the
reference image is never shown in the UI.

## The approach (proved in the lab first - `lab/paint/`, gitignored)

1. **The picture painted first** (`image:face`), checked by the art director (`check:face`).
2. **The order it is painted in** (`layers`): the art director, shown the picture, writes the layers a hand lays it in, broad to fine -
   each said so a painter lays only it, marked `soft` where it has no edge of its own (a shading, a haze).
3. **Each layer painted over the one before** (`image:layer:K`): the image painter, shown the picture so far and the finished picture,
   lays only that layer. What a layer lays is exactly what changed between two steps - its region and its colors, soft where the
   change is soft - never guessed from colors. The design and its layers are one thing.
4. **Each layer laid with real marks** (the lab's `layers_paint.py` + `optimize.py`): its thin parts traced on its own picture (a crackle's
   network, lashes, a brow); its broad parts painted by strokes found by gradient descent through a soft model of the very strokes the
   lab lays (DiffVG, Li et al. 2020; Stylized Neural Painting, Zou et al. 2021) toward the step's own picture over the canvas as it
   stands - each layer paints only its region; where error remains, more strokes (e-David's loop, Deussen et al. 2012); a soft element
   worked over wet. Small round parts are made dots.

Lab result on the crackle mask (327484): the crack network with its junctions and gold threads, a crisp lid with lash line and
lashes, the tear with its gold rim, clean runs, shaped glossy lips with their smear, a teal-to-indigo bruise with a violet haze. It
took 11 Codex calls (about 40 s each, cached by prompt and images), about 46 minutes of painting, and about 5 minutes to solve on the
RTX 5060 Ti.

## What is built in the app

- **Every picture an episode's agents made, seen** (`EpisodeFeed.made_pictures`, `MadePictures` on the Pictures card): the picture to
  copy, its layers, the cloth, the room, the depth, the backs, the cards' paintings, a game's pictures - a thumbnail each, full size a
  click away, stepped through in order. Generic: any maker says its own in `made_pictures`; the Pictures card names none. The card
  comes with a table show (`comes_with`), standing while there is any picture to show. Making one again is its row on the Pipeline card.
- **The layers as episode steps**: `layers` (`layers.json`, the art director - rules `table/art_director.layers`) and `image:layer:K`
  (`layer_K.png`, the painter - rules `table/painter.layer`, the picture so far and the finished picture attached), each kept only if
  it lies on the surface (`Skins.face_fit`). Rows on the Pipeline card's Episode section, group Layers: a layer's ⟳ paints it and the
  layers after it again; the picture's ⟳ throws all of them away. Gates: skin_step_check (order, inputs, what a redo throws away,
  files, prompts), pictures_card_check (shown under the full frame; the control: none made, put away).

## The painter at the table (built 2026-11-09)

`hosts/paint/` is the lab's Python run as a host, as the voice is (`run.py <spec.json>`, its own `Deps` environment `paint_venv` -
numpy, SciPy, Pillow, PyTorch; the GPU where there is one). When an episode has layers, the producer's skin step
(`TableProducer._make_skin_host`) writes a spec (the bare picture, the surface's place in it, the table's creams, the layers and
their pictures) and runs it. `export.py` writes, per element (a run of one layer's marks with one tool in one paint), its program on
the show's own pace (`Skins._Prog` keys and strokes, `Skins`' constants line for line) and the maps skin_paint.gdshader draws
(`cover`, `when`, the staged `built`/`built_when`, `tint`). `_land_skin_host` keeps them as the design (`skin.json`, each element's
`plan.host` naming its output), its tool the table's nearest, its beat where it begins in the painting's time. `TablePaint._from_hosts`
plays every such element from its maps and program, never laying it again with the show's own painter. What the painter saw is what
the show draws, by construction (`hosts/paint/test_export.py`: the maps laid in order come to the painter's canvas; control, the
reverse order).

- **A layer's broad parts** are optimized part by part, then laid together, the broadest brush first through its paints
  (`optimize_layer`). Part by part, each brush taken up again for each, one episode came to 52 acts (`Motions.MAX_ACTS` is 40).
- **A thin part's paint** is read from what each point became over what it was (`laid_paints`); read as a color, gold threads were
  traced in grey, and lines redrawn a pixel aside by the image model outweighed them.
- **The hand** (`hosts/paint/test_hand.py`): a hand generally keeps its whole brush inside the edge, but can spill over, dragging
  color with it, and cleans up with more paint or a cotton swab. A fat brush's pulls lie a whole touch inside their region, a smaller
  brush where it is narrower (`plan.py` `_feather_area`); a mark that changes nothing is never made (`solve.py`); a blend drags color
  along (`marks.soften`'s `drag`); a fat brush's every blending pull is drawn as a hand draws it - a steady wander, now and then a slip
  aside or a run past its end, seeded (`marks.slipped`; the optimizer's broad strokes are laid as found, not yet slipped); after each
  layer its spills are cleaned - a small or faint one blotted with a cotton swab (`marks.blot`, tool `bud`), a bigger one painted back
  over in the color under it (`layers_paint.tidy`). The swab is a stick with a cotton tuft on the fixed table (the brief), a tuft kind
  of its own in the show. Not yet judged: how often a hand slips (`SLIP_EVERY`, `OVER_EVERY`), how much a blend drags
  (`FEATHER_DRAG`, `SMUDGE_DRAG`).
- **The paint is the named pot's.** Every element's paint is the pot the painter named (`plan.pot`, `TablePaint._pot_of`), never the
  cream nearest its color. The base is one pot's paint (`plan.py` `_base`, white for 732687), and its presses fall where a hand puts
  them, not on the sweep's lattice (`PAT_WANDER`; `test_hand.py` 7-8).
- **A fade takes up only what its layer is laid on** (`plan.TAKE_INSIDE`, `untaken`; `test_hand.py` 12), so it does not carry white
  past a line into a neighbor; a part painted by numbers works only its own borders wet, a feather's reach inside its edge
  (`layers_paint.OWN_BORDERS`; 10).
- **No layer changes the face's own edge** (`layers_paint.RIM_OFF`, 1.5 mm; `test_hand.py` 11): the image model draws the silhouette
  a pixel or two aside in every picture, and a layer reading that shift as a dark change traced the jaw in dashes.

## A layer worked as a hand works it (built 2026-11-10, overnight, at the author's ask)

A long thin part is one base pull, then what corrects it, with few brush and paint changes. Measured on 732687 before: 97 runs of
one brush in one paint (each a rinse, a blot and a dip, about 14 s in the show), 2,434 s of painting, a fifth of it (527 s) paint
that hardly changed the face; the tears 17 runs, five under 3.5 s; the cracks 43 pulls of 5 mm.

- **A long thin part's base first** (`optimize.BASE_LONG`, `_pulls`): a part far longer than it is wide is pulled down its middle in
  the paint most of it is, in pulls up to 45 mm; in two paints at most, its base and the next most of it, every other color of it the
  nearer of those two's; no dab where error remains in it. Any long thin piece of any paint is pulled the same way, never drawn round
  as a ring.
- **One order, laid and judged** (`LayerOpt.key_of`, `_ordered`): broad brush to fine; in each brush the paint its layer's base is laid
  in first, then the rest lightest first; each run toured, the next pull nearest where the hand is. The optimizer renders its strokes
  in the order the layer lays them.
- **Every run worth its trip** (`optimize.consolidate`, `GROUP_LEAST` 12 s): a smaller run is laid by its paint's own run in another
  brush, else by a run worth its trip in a near shade (`MERGE_COLOR_MOST` 12), else it stays, a color of the design (merged as far as
  25, a diamond lost its olive to its plum). A base is never merged. A crisp part's stroke is laid at least a quarter strong
  (`TH_SHOWS`).
- **Corrections are pulls** (`refine`): along the miss's own length, inside its part only, one round of twelve.
- **Makeup, never the skin redrawn** (`layers_paint.SKIN_CHROMA`, `SKIN_LIGHT`): a broad part leaves out where the picture is still the
  base's skin; a soft layer works one place (`SOFT_NEAR`, `SOFT_PIECE`).
- **A line whole** (`layers_paint.LINES_WHOLE`, `LINE_PAINTS` 2, `LINE_APART` 20; `plan.LINE_LEAST` 1 mm, `LINE_JOIN` 2 mm, `LINE_RUN`
  100 mm; `Hand.top_up`): found over all its layer's lines, each whole line in the paint most of it is; a line inside its layer's
  broad part is that part's texture, never traced.
- **A place at a time** (`export._places`, `PLACE_MM` 12): a run's pulls are gathered into places and the places toured, each swept
  by the way its pulls go before the next.
- **The show draws a hairline whole** (`shaders/prop.gdshader` `SKIN_TAPS`): the painted canvas is read at four places across each
  pixel, since sampling it without mipmaps broke a hairline on the forehead, lying back from the camera, into specks.
- Gates: `hosts/paint/test_optimize.py` (base first, runs worth their trip, one run a brush and paint, a brow whole, a line that
  shows), `test_hand.py` 10-12, `test_export.py`.
- Result on 732687 painted again with it: 37 runs where there were 97, 1,133 s of painting over the base's 244 where there were 2,189,
  28 acts where there were 36. As the show plans it (`episode_bake_probe --script --pace=1 --heard --plan-only`): 33 loads, 33 rinses
  and 32 blots, 466 s of a 40-minute show, its painting slowed to 1,733 s to keep with the words; the hand's way between pulls 5.4 m
  where it had been 19.2 m (the base apart).

### The work shorter than its words, and the hand put down

An act longer than its work slows its strokes at most 2.5 times (`TablePaint.SLOW_MOST`), rests at most 6 s an element
(`REST_MOST`), then puts its tool back and stands `still` to its end. Three causes of dead air are fixed for any episode:

1. The schedule shares a beat's spare time by the work alone, never by each act's whole length (trips and moves are never slowed),
   each act's work slowed alike (`TableWork.schedule`, `_fixed`; `table_work_check` `_spare_to_work`).
2. The landing gives each beat a share of the work by how long its words take where they are written, each run counted with its
   trips (`TableProducer._element_beats`, `_beat_seconds`, `RUN_TRIPS`).
3. Words kept over remade work keep their first cue and the rest of the beat's acts follow on, sharing it by what each takes
   (`TableProducer.recue_map`; `skin_step_check`).

The live voice runs longer than the plan's guess (its hesitations and slower deliveries are not in the guess), and a beat's acts are
sized as each begins, so the last take up what the first were not given. `episode_bake_probe --plan-only` reports a tool put down
inside its act as idle.

## Status

- **Built and gated, not yet seen by the author in the app:** the made-pictures feed, the Pictures card on table notes and the
  layers steps.
- **Built:** the painter host and the show's playback. 327484 stands from the host's output in `paint_preview_probe` (the bruise, runs,
  closed eye and brow as the lab painted them). Run end to end on 732687 and watched; the fixes in the host (each press's side, pulls
  turned and gathered by their way, staging by the canvas) reach an episode only when its painter runs again.
- **Show-side fixes** (reach an episode at the next launch): the sponge's reloads go to the named pot; moves and trips take as long as
  their way needs (`TablePaint._paced`, `MOVE_PACE`; `paint_check` `_paced_ways` - on a made scene, frames that moved the tool over
  2 cm went from 81 to 21), and each way between keys is given the time its body needs, with the program's reveal maps carried to
  the new times (`TablePaint._pace_keys`, `KEY_PACE`; `paint_check` `_paced_keys`); a brush rinsed or dried and stopped short of its
  hand has its hairs drawn straight where it does not reach (`TablePaint._lay_on_plane`, `paint_check` `_laid_as_drawn`).
- **Measured, not fixed:** the maps are not behind faint black cracks (every line's coverage, load and build-up whole; each stroke point
  shown within 0.02 s of the brush). A fifth of the painting's time (527 s of 2,619) lays paint that hardly changes the face, mostly pale
  cream on white - the image model's warm skin, redrawn a little differently in every picture, copied as makeup. The right brow is
  mostly missing in the painter's own painting.
- **Open:**
  - Acts paced longer could run past their words; a liner put back in its jar is held 39 mm off its place by the jar for a moment.
  - The environment: PyTorch is large (about 3 GB with CUDA) and the first painting installs it; the optimizer also runs on the CPU,
    slower. The rule is "nothing from upstream until a week old, every helper sandboxed" (next/supply_chain.md).
  - The sponge: the lab's is a disc with pores, the table's is a real shape with sides (`TablePaint._side_touch`).
  - The time: about 47 minutes for 327484, a third of it the crackle's 550 lines. The readers' passages are written to the work's length.
  - The rust mask (257002): its layers are made and painted in the lab; the author has to judge it.
  - The hand's slip rate and blend drag, listed above.

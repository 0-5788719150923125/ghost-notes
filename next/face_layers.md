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

## A layer worked as a hand works it (built 2026-11-10, overnight, at the author's ask)

The author, after watching 732687 to 33 minutes: "They tend to jump around the entire face ... They spend a stupid amount of time
dipping in water, dabbing off the water, and changing paint colors ... the model will pick yellow, make two marks with yellow, then go
through the whole process of grabbing green" - "the tears dripping from the eye ... took a solid 12+ minutes" - "An intelligent model
should know: it can draw a single line, pull it all the way through, as a base color. And then it can correct itself, painting other
colors on top of that ... There are liberties it can and probably should take, for the sake of speeding-up certain tasks, while
minimizing the color churn". Measured on 732687 before: 97 runs of one brush in one paint (every one a rinse, a blot and a dip, about
14 s in the show), 2,434 s of painting, a fifth of it (527 s) paint that hardly changed the face; the tears 17 runs, five of them under
3.5 s each; the cracks 43 pulls of 5 mm. Each change measured on the tears and the cracks repainted alone (`~/scratch_ghost/v2/`).

- **A long thin part's base first** (`optimize.BASE_LONG`, `_pulls`): a part far longer than it is wide is pulled down its middle in the
  paint most of it is, in pulls up to 45 mm; in two paints at most, its base and the next most of it, every other color of it the nearer
  of those two's; no dab where error remains in it. Any long thin piece of any paint is pulled the same way, never drawn round as a ring.
- **One order, laid and judged** (`LayerOpt.key_of`, `_ordered`): broad brush to fine; in each brush the paint its layer's base is laid
  in first, then the rest lightest first; each run toured, the next pull nearest where the hand is. The optimizer renders its strokes in
  the order the layer lays them.
- **Every run worth its trip** (`optimize.consolidate`, `GROUP_LEAST` 12 s): a smaller run laid by its paint's own run in another brush,
  else by a run worth its trip in a near shade (`MERGE_COLOR_MOST` 12) - else it stays, a color of the design (merged as far as 25, the
  diamond had lost its olive to its plum). A base never merged. A crisp part's stroke laid at least a quarter strong (`TH_SHOWS`).
- **Corrections are pulls** (`refine`): along the miss's own length, inside its part only, one round of twelve.
- **Makeup, never the skin redrawn** (`layers_paint.SKIN_CHROMA`, `SKIN_LIGHT`): a broad part leaves out where the picture is still the
  base's skin; a soft layer works one place (`SOFT_NEAR`, `SOFT_PIECE` - "the shine" had drawn near-black down the forehead).
- **A line whole** (`layers_paint.LINES_WHOLE`, `LINE_PAINTS` 2, `LINE_APART` 20; `plan.LINE_LEAST` 1 mm, `LINE_JOIN` 2 mm, `LINE_RUN`
  100 mm; `Hand.top_up`): found over all its layer's lines, each whole line in the paint most of it is - the right brow had been cut into
  pieces at every change between two blacks, and begun on a third of a load it ran dry after 33 mm; a line inside its layer's broad
  part is that part's texture, never traced (plum squiggles down the tears).
- **A place at a time** (`export._places`, `PLACE_MM` 12): a run's pulls gathered into places and the places toured, each swept by the
  way its pulls go before the next - swept by heading over the whole run, gold seams from the brow to the jaw had crossed the face once
  for each way.
- **The show draws a hairline whole** (`shaders/prop.gdshader` `SKIN_TAPS`): the painted canvas read at four places across each pixel.
- Gates: `hosts/paint/test_optimize.py` (base first, runs worth their trip, one run a brush and paint, a brow whole, a line that shows),
  `test_hand.py` 10-12, `test_export.py`.
- **732687 painted again with it** (layers 2-16 over its base, landed 2026-11-10 04:15; backup `~/scratch_ghost/ep_732687_0415_v2`;
  every passage's words unchanged): 37 runs where there were 97, 1,133 s of painting over the base's 244 where there were 2,189, 28
  acts where there were 36; the diamond's olive and plum and the socket's yellow ring kept, the tears two runs, the cracks bold gold
  seams, both brows whole, no pale cream over the face. As the show plans it (`episode_bake_probe --script --pace=1 --heard
  --plan-only`): 33 loads, 33 rinses and 32 blots, 466 s of a 40-minute show, its painting slowed to 1,733 s to keep with the words;
  the hand's way between pulls 5.4 m, where it had been 19.2 m (the base apart). "No idle stretch over 8 s" was wrong: the probe looked
  only between acts, never at a tool put down inside one (below).
- **The work shorter than its words, and the hand put down** (the author, 2026-11-10: "Starting around 5:30, and continuing for at least
  90 seconds... there is no animation at all. There is only the spoken voice"): an act longer than its work slows its strokes at most
  1.6 times (`TablePaint.SLOW_MOST`), rests at most 4 s an element, then puts its tool back and stands `still` to its end. Three causes,
  each fixed for any episode: (1) the schedule shared a beat's spare time by each act's whole length, trips and moves too, which are
  never slowed - an act of few strokes and many trips was given more than its strokes could fill; now the spare goes to the work alone,
  each act's slowed alike (`TableWork.schedule`, `_fixed`; `table_work_check` `_spare_to_work`). (2) The landing gave each beat an even
  share of the work, and the shorter painting's sponge ground was more than an intro's share, so the intro was the ground alone, one act
  over seven minutes of words; now each beat's share is by how long its words take where they are written, each run counted with its
  trips (`TableProducer._element_beats`, `_beat_seconds`, `RUN_TRIPS`). (3) Words kept over remade work kept each cue at its place,
  naming the act now there - acts cued where ones two and three times as long had been; now a passage keeps its first cue and the rest of
  its beat's acts follow on, sharing it by what each takes (`TableProducer.recue_map`; `skin_step_check`). And `episode_bake_probe
  --plan-only` now says a tool put down inside its act as idle. (4) Watched again in the app: "between 6:30 and 8:30 - there is no
  animation at all". The live voice says the intro in about 510 s where the plan guesses 442 (its hesitations and slower deliveries
  are not in the guess), and a beat's acts are sized as each begins: the last take up what the first were not given. Strokes may now
  be slowed 2.5 times and an element rested 6 s (`SLOW_MOST`, `REST_MOST`; they were 1.6 and 4). Landed on 732687 at 11:12 (backup
  `~/scratch_ghost/ep_732687_1112_idle`, every word the same): 29 acts, the intro the base, the diamond's outline and its fill; planned
  with the voice 15% slower than guessed, the intro's acts run on into stage 1 with no tool put down.

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
All three landed on 732687 (2026-11-10): layers 4-6 painted again and spliced as el_200..el_224, the rim's dashes gone and the diamond's
corners plum; every passage's words unchanged (backup `~/scratch_ghost/ep_732687_0221_fb0011`).

Feedback 0013 (2026-11-10): "These black cracks are barely visible ... The brush is constantly touching places that leave no mark at all."
Measured, not yet fixed: the maps are not it (every line's coverage, load and build-up whole; each stroke point shown within 0.02 s of
the brush, its stretched times too). A fifth of the painting's time (527 s of 2,619) lays paint that hardly changes the face, mostly pale
cream on white - the image model's warm skin, redrawn a little differently in every picture, copied as makeup; the brows and cracks are
hairlines as thin as the picture's, in short strokes visited out of order (the cracks 43, median 5 mm), the right brow mostly missing in
the painter's own painting; and the show samples the painted canvas without mipmaps, so a hairline on the forehead, lying back from the
camera, breaks into specks.

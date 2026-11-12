# The painted surface: a face made up, slowly

The show is Joker Motivation (`rift/cards/joker-motivation.md`): an episode where the actor paints a mask, a
mannequin face or the like, like a "Get Ready With Me" video. The person slowly and meticulously applies a
foundation, details, eye liner and lipstick, and gently smears things with a sponge. It is gentle and slow: a
work of art made without rush. While it is made the voice talks off-handedly about random things,
self-affirming (a "you" directed at the self), with moments of nothing said. It is always a clown's mask.
The tools behave like real ones: brushes with hair dynamics, paint smears, sponge smudges, dust from
foundation, gloss from lipstick.

This note is the audit of what that show needed, the plan that followed from it, and what was built. It
carries out next/table_work.md section 11 ("The painted surface, and the makeup show") and goes further: the
tools themselves behave like real ones.

## The audit

Read against the code as it stood:

| needed | stood | where |
|---|---|---|
| an episode with no cards, in beats, each said while its work is done | **built** | `CardTable.cardless`, `TableProducer._land_beats`, cardless_check |
| moments with nobody talking | **built**, any show: the plan's `quiet`, a reader's `<!-- quiet: N -->` | `TablePrompts.quiet_of`, `CardReading.QUIET_MARK` |
| a mask, the same every episode, on its stand, with the same station round it | **missing**: every set dresser builds its own table, and nothing can be handed to it whole. A mask could only be a `sculpt` | section 11, "A SHOW'S FIXED THINGS" and "A MASK FORM" |
| paint that goes on where a tool passes, and stays | **missing**: the only thing a law puts onto a surface is `write`'s words on a sheet (`SheetWriting`) | section 11, "THE PAINTED SURFACE" |
| a design for the face, made before the camera rolls | **missing**: no agent designs anything painted. The painter's pictures (cards, cloths) are pictures, not paint | |
| a tool pressed onto an upright face | **missing**: `press` casts straight down (`TableWork._surface_under`), and the physics bake pushes a held tool out of whatever it meets, the thing it presses included (`RigidParts._near`; only the puppeteer's `act` check excused it) | |
| a brush whose hairs bend as it is dragged and spring back as it lifts | **missing**: no shape is a bundle of hairs, and nothing on the table bends by how it moves | |
| a sponge that gives as it is pressed, stippling | **missing**: no material is foam, and no tool changes shape | |
| powder that puffs up as it is patted, and is brushed away | **in part**: a cue's burst (`Effects.BURSTS`) can rise from a point; no look is a cloud of fine powder, and nothing lays a powder down | |
| a lipstick's gloss, glitter, gold, rhinestones | **in part**: the table's materials have a gloss, glitter (`PLAYS` `glitter`) and metal, but only for a whole part, never for paint on one | |
| a smear: paint softened at its edge after it is on | **missing** | |
| the voice off-handed and kind, its "you" said to the self | **missing**: the brief was the original genre's (a deep voice, "chosen one", "they" who doubted) and a male Kokoro speaker | the brief |

Nothing about makeup or a mask may be named in the code or the rules (`rules_check` holds the rules to name
no kind of work): what is built is a painted surface and the tools that paint it, which a cake's frosting, a
sign's letters or a miniature's colors are made with too. The brief says it is a face, and a clown's.

## The plan

Each step leaves the episodes already made playing as they did, and has a gate with a control that must fail.

1. **A mask form:** a shape of its own (`mask` in `Props.SHAPES`): a face with closed eyes and closed lips, no
   hair, no ears, built as a relief over its own front so every point of the face is one point seen from the
   front. It names its landmarks (the eyes, the brows, the nose's tip, the mouth's corners, the chin) where
   the face's designer can read them.
2. **A painted surface:** a part's `skin`: paint laid on it from one side (the mask's front), in millimeters
   across and down that side.
3. **The design:** a step after the table, `design`, by a new agent, the decorator
   (`rules/table/decorator.yaml`): the plan's `design` in words made into elements, each a shape in the
   skin's millimeters (a fill, a line, dots, stones) with its paint, its finish and the stage it belongs to,
   drawn as SVG paths. It sees its design laid over the bare surface and changes it before it hands it in
   (`DecoratorTools`: `look`, `submit`).
4. **A law that paints:** `paint`: a tool (a brush, a sponge, a puff, tweezers) loaded from a pot, pressed onto
   the surface and moved over each named element as a hand moves it (a line drawn along its path, a fill
   swept back and forth, a base stippled from the middle out, dots dabbed, a stone carried from its dish and
   pressed on), lifting between strokes, going back to the pot when the paint runs low, and back where it was
   when the act is done. The agent says which elements, with what, from which pot; the hand finds the way.
5. **Paint shows where the tool has been:** every element's reveal map (when along its strokes each point of
   it is first covered) is drawn once for the acts; the schedule hands each element its start and end; the
   surface is composited in a small 2D viewport of its own from those, so a frame paints nothing on the
   processor and a scrub lands exactly where a play does. Finishes: matte greasepaint, satin, gloss, glitter,
   metal, pearl, powder. A `blend` softens an element's edge after it is on (the smear). A powder patted on
   lays a matte veil; patted again, its excess is swept off.
6. **Tools that behave:** a `tuft` shape (a bundle of hairs: round, flat, liner, fan, dome) whose hairs bend
   against the way it is dragged, splay when pressed and spring back with a small overshoot when lifted, and
   carry the color they were loaded with; a `sponge` material that gives where it is pressed; powder that puffs
   (`dust` and `mist` bursts) as it is patted and swept.
7. **Pressed, not pushed off:** the bake lets a tool through the surface it paints while it paints it
   (`seat_skip`), and `act` says what an act paints, how long each element takes and what of the design is
   still unpainted at the close.
8. **A show's fixed things:** a brief may carry a fenced JSON block under `## The fixed table`: things (and a
   light and a sound) that stand on every episode's table exactly as written. The set dresser starts with them
   on the table, builds round them, and cannot move or remove them.
9. **The brief:** Joker Motivation: the mask and station fixed, the face designed as stages, the work a GRWM's
   pace, the voice off-handed and self-affirming, quiet stretches, always a clown.

## Status

Built, gated, and looked at on the GPU with a design and acts written by hand. No real agent has painted a
face end to end, nobody has heard a reading over it, and nothing has been exported. Paint is laid only where a
tool touches, and every tool (sponge, puff and brush) goes back over what it missed right after it misses it
(the sections from "Watched a fifth time" on); a brush is pulled through its strokes, its hairs bent over as it
leans ("Pulled through, bent over"); a pressed pad takes the skin's shape, hairs are stiff, a brush's paint is
where its hairs touched and a fill keeps inside its shape, a blend softens where its brush went ("What touches
is what is laid"); a face is painted first, checked and copied ("The painting is the design"). Step by step:

1. **A mask form** - built. `FaceForm` (`src/table/face_form.gd`): a relief over its own front (heights on a
   regular grid, 0.1 cm apart, normals from their differences; an egg-shaped outline; a flat back and a rim),
   cached by size. `landmarks()` names the closed eyes' lash lines, the lids, brows, nose, mouth, chin,
   cheekbones and temples in the designer's millimeters; `outline_path()` is the face's edge as an SVG path.
   Shape `mask` in `Props.SHAPES`.
2. **A painted surface** - built. A part's `skin` (`Props._sanitize_part`), recorded by `Props.build` (`skins`:
   its holder, meshes, placement and box), found by `TablePaint`; the frame is the part's own box seen from +z.
3. **The design** - built. Plan field `painted` (rules/table/producer.yaml); step `skin` (`skin.json`, after
   `table`, before `acts`: `TableEpisode.wants_skin`); the decorator (`rules/table/decorator.yaml`,
   `TablePrompts.decorator`, `DecoratorTools`: `design`, `look`, `submit`; `TableProducer._make_skin`,
   `_land_skin`); the language from the registries (`Skins.describe`, `Skins.told`). `look` is drawn on the
   processor (`Skins.look`: the bare surface by rays, shaded, the design by ThorVG, a grid every 10 mm, the
   outline and landmarks), so it works in any run. An element mostly off the surface is said, and stops
   `submit` once. The Episode card's Pipeline row "What is painted".
4. **A law that paints** - built. `paint` in `Motions.LAWS` (`on`, `paint`, `from`, `rinse`, `manner`, `size`);
   `TablePaint` (`src/table/table_paint.gd`) plans an act (`plan_of`: fetch, load, rinse, move, each element's
   program, rests, back, still) and poses the tool (`pose`); `Skins.program` makes each element's way at a
   hand's pace (constants at its head). The first act (in reading order) that paints an element lays it; a
   later one blends it, or sweeps a powder's excess. Every paint act carries `_natural` and `_min_length`;
   `Skins.act_natural` works the same out from the files for the readers (`TableProducer._acts_of`).
5. **Paint shows where the tool has been** - built. `Skins.cover` (Godot's own SVG renderer per element,
   clipped to the outline), `Skins.when_map` (the program stamped, a millimeter a pixel, the first touch kept,
   the rest filled from the nearest); two SubViewports a skin (`TablePaint._canvas`), an element a sprite in
   each with `shaders/skin_paint.gdshader`; prop.gdshader lays them over the part where it faces its front
   (`skinned`, `skin_u`, `skin_v`, `skin_side`). The paint's viewports draw every frame (a probe's several
   ticks a frame would undo drawing on request). Stipple fills its pores in by its last stroke; `soft` and a
   blend soften by the cover's mip levels; glitter is flakes in the part's own shader.
6. **Tools that behave** - built. `tuft` (`Bristles`): hairs and a core, bent in the vertex shader
   (`bristle_*` uniforms) by a damped spring over the last 0.45 s of the tool's own way
   (`Bristles.response`), splayed when pressed; its tip carries the paint it last took up (`tip_paint`).
   Material `sponge` (pores; it gives: `squash`), material `cream` (paint in a pot). Bursts `powder` (each
   pat, and every 1.6 s of a sweep) and `mist`.
7. **Pressed, not pushed off** - built. `TablePhysics._painted_by` adds what a paint act lays its tool on to
   the body's `seat_skip`; `act` says what an act paints, element by element, and what no act lays yet; the
   parts report lists each design's elements with how long each takes with a brush, a sponge or a puff.
8. **A show's fixed things** - built. `FixedTable` (`src/table_show/fixed_table.gd`): a fenced JSON block under
   `## The fixed table`; `TablePrompts.brief` shows a line in its place; `SetDresserTools` starts with it and
   refuses to put, move or remove it; `TableProducer._land_table` merges it. Things and materials (and a
   light and a sound, if the block has them).
9. **The brief** - `rift/cards/joker-motivation.md`: GRWM, the voice to herself, quiet a quarter of the work,
   six beats a stage each, a soft palette among the kits, no body talk; the station as its fixed table. The
   note's `voice` block is Secular Hazing's (Kokoro speaker 13, Puck, as "Ink"), and the brief's prose names
   no one's pronouns, so the voice can change freely.

**This show's camera sees only 13 to 22 cm up over the table's middle** (`CardTable.headroom_at`, 8 seeds),
so a life-size mask standing up loses its top to the frame. The mask lies back 60 degrees on a cradle,
facing the lens, its top under the frame, and a tool is held with its handle up and out to the side, never
toward the lens (`TablePaint.HELD_*`); a brush drawn along a stroke leans the way it goes ("Pulled through").

Looked at (`paint_look_probe` on the brief's own fixed table, a pierrot of twelve elements and twelve acts
written by hand, 1280 x 720 on the GPU): the mask reads as a face at this distance, lying back on its cradle
and facing the lens whole; the sponge stipples from the rim, the base going matte and porous; the puff pats
the powder on; the liner draws each brow in clean arcs; the round brush fills a diamond that follows the eye
socket's curve; the flat brush lays a mouth that shines wet; the blush is soft and softens further; gold dots,
a glitter star and three stones go on last, the tweezers carrying each; every tool goes back to its place
on the tray with its last color on its tip. Not looked at: the hairs bending at the table's distance, a
powder's puffs, a frame by frame clip.

Gates: `tests/table/paint_check.gd` (the mask, a design, paths, reveal maps, the hairs, and the law on a real
table: the liner's tip within a millimeter of the face while it draws, lifted between strokes, home after;
the sponge on the face as it stipples; a scrub the same as a play), `tests/table_show/skin_step_check.gd`
(the step, the surfaces, the decorator's tools and landing, fixed things, prompts). Probe:
`tests/table/paint_look_probe.gd` (`--brief` takes a brief's fixed table, `--design` a skin.json).

## The details (2026-11-05, later)

- **A smear:** a design element of its own (`smear`: the id of an element laid before it, `line` the path its
  paint is dragged along, `width`): it takes that element's paint and finish, and is drawn as streaks side by
  side across its width, each thinning piece by piece from the paint's own strength to a fifth of it
  (`Skins.smear_svg`); laid in one pressed stroke at a smear's pace (manner `smear`), revealed from where it
  starts. No paint is loaded for it.
- **A rinse, then the towel:** `paint`'s `dry` names a cloth: after each rinse the tool is pressed onto it and
  wiped across. A brush that rinses is rinsed before each new color and when its act is done, before it is
  put down; trips go cup to towel to pot with no stop at the face between (`TablePaint._end_of`, `_trip`). A
  sponge is rinsed as a hand rinses one: lowered in and squeezed three times as it soaks, lifted over the cup
  and wrung out hard twice, then blotted on the towel in three firm presses, each held and each on a fresh
  place (`TablePaint._sponge_trip`; 8 s and 4.6 s where a brush's are 4 and 2.6). Not built: the drops
  running off it as it is wrung.
- **A brush is laid on its paint, the cup's floor and the towel:** leaned 55 to 5 degrees off upright,
  whichever keeps it inside the vessel's wall, and pushed down until 30% of each hair lies flat along the
  surface, the rest bowed down to it (`TablePaint._laid_hold`, `Bristles.laid`, prop_common's `bristle_lay`;
  41-46% of each hair within a touch of it, paint_check); a flat brush is leaned across its broadside as it
  comes rolled, so its flat lies down. It comes to what it is laid on no faster than the solver carries a
  held thing near others (`TablePaint.TRIP_PACE`). Open: the author's eye on it.
- **The water clouds:** each paint act that rinses gets a track of its own on the cup's water, law `cloud`
  (`TableWork._cloud_of`, `TablePaint.cloud_at`): a real tint entry, so the drawn cup and the physics' liquid
  both follow it, and a scrub lands where a play does. The water needs a `name`. By volume: a rinse carries
  out a sponge's face of paint 0.5 mm deep or a brush's belly (a twentieth of its hairs' bulk;
  `TablePaint.rinsed_ml`), and that share of the cup's water (`TableWork._water_ml`) turns its color toward
  the paint and clouds it (`TablePaint.clouded`): in a glass a sponge's rinse clouds it about a tenth, ten of
  them most of the way, a liner's hardly at all. A liquid as clear as 0.5 is drawn seen through
  (`prop_liquid_clear.gdshader`, under its glass), less as its `murk` builds up.
- **A base reaches the edges:** the decorator is told a base covers all of what it is the base of, and
  anything thinner or darker toward an edge is an element of its own over it (decorator.yaml).
- **A setting spray:** a design element `mist` ("all" or a path) lays no color, only a wet sheen (roughness
  0.08, a clear coat), which dries down to a third of it over 75 s (`skin_paint.gdshader`'s `dries`).
  Sprayed (manner `spray`) a few pumps across, from 12 cm off, out from the surface and to its right
  (`TablePaint.SPRAY_FROM`), never between it and the lens, each pump a `mist` burst thrown at the face (a
  burst's moment says which way it throws: its transform's up). The brief's station has a bottle for it.
- **Paint that runs low:** a brush's tip shows its paint thinning as it lays it (`TIP_FULL` to `TIP_LEFT` over
  `TIP_LASTS`), full again each time it goes back to the pot mid-element, gone when rinsed.
- **The powder's puffs** are placed by the cue planner (`_paint_bursts`), and gated.

## The first real run (2026-11-05, joker-motivation 856886)

A real Generate got through the plan, the room, the table and the design (the decorator's first face, 27
elements: a gold crown, arched brows dotted in gold, a violet and lilac diamond band across the closed eyes
set with stones, a violet tear dragged down the cheek, gold mend lines across the right cheek, a small red
mouth with curled corners) and stopped at the acts: the puppeteer wrote 21 sound acts in the design's own
element names, and refused to hand them in because "the mask on this table has no design attached".

- **The design reaches the puppeteer's table.** A preview stands the table in a folder of its own and copies
  the episode's pictures into it (`TablePreview.PICTURES`), `skin.json` included; skin_step_check holds that
  every file `table.gd` opens from its folder is written by the preview or copied into it (the control a list
  without the designs).
- **A paint act on a surface with no design is refused,** and why said (`TablePaint.resolve`).
- **The mask's solid is the face:** `ShapeField` has a `mask` kind (its relief over its front, its flat back,
  past its outline the rim: `ShapeField._mask_d`; paint_check, the control the box), so a brush on the face
  does not read 4 cm deep.
- **A painting tool is not "passing through" what it paints and its pots.** `TablePaint.touches` names what
  it paints and the pots, water and towel it goes to (every paint on the table, loading by color), and
  neither the check (`TableWork.check`: a painting tool's own `still` leaves them out) nor the bake
  (`TablePhysics._painted_by`) counts it inside them. Anything else it passes through is still said.
- **The ways between places go over what stands in them:** what stands where the tools go is mapped once as
  the paint is prepared (`TablePaint._map_tops`, a centimeter's cells), each way finds the lift that takes the
  tool `CLEAR_GAP` over it, looked round the tip as far as the tool is wide (`_lift_over`, `_reach_of`), and a
  trip comes in over a cup's rim (`RIM_CLEAR`). Read on either thread: made before the bake begins.
- **A watch is one look of six frames,** said so by the tool and the rules ("Looks left: 29" is not six
  watches).
- Replayed (`tests/table/act_calls_probe.gd --full`): every act finds its elements and runs its strokes' time
  (761 s of painting in all; the base alone 86 s by sponge), nothing is held back, and the whole act call
  costs the puppeteer about 2.5 minutes, nearly all of it the bake.

## Watched (2026-11-05, 856886 played live)

Symptoms: stalling and buffering; unclear whether the sponge applied any color; an application far faster
than elaborate clown makeup takes.

- **The bake is not thrown away a sentence at a time.** An under act's end is the word that cues the next
  act, a guess until it is heard, and a paint act lays every stroke out over its whole length, so each
  sentence's new guess moved every stroke and the bake went back to its start. A paint act begun keeps its
  length (`TableWork.schedule`, as an act of fixed length always had). Played live on the plan's own word
  times at 0.6 of their pace (`episode_bake_probe --live --script --pace=0.6`): 75.4 s of 120 waited for the
  bake in 14 stalls, now 4.9 s, all of it the first stretch baking.
- **The base changes the mask's color:** the bare face is a warm practice head's skin tone (#c89e80, material
  `face form`), so the white going on first changes it completely; the decorator's `design` says what is
  hardly seen (an element in nearly the color and the finish of what it is laid over:
  `DecoratorTools._unseen`, `UNSEEN`; skin_step_check), with a rule saying why.
- **A careful hand** (`Skins` pace: a line 7 mm/s, sweeps 24, blends 16, slower dabs, pats, smears, picks,
  pumps; `TablePaint`'s trips longer), a look after every stroke (backed off 9 mm, 0.6 to 1.8 s, drawn by the
  stroke), a paint act never hurried below 0.85 of its natural length (`LEAST`), and one hand paints one
  thing at a time (`PAINT_HAND`). A 27-element design comes to about 22 minutes of painting.

## Watched again (2026-11-05, 209459, feedback 0016)

Symptoms: the sponge clipping through the nose and the powder case; a sponge dabbing with its flat side where
a person would dab with the corner (and spread with the flat); a stipple like a pixel grid where fine dust
was expected.

- **A tool's pose looks at its body.** `episode_bake_probe --audit` looks at a painting tool's own mesh to
  0.8 mm (`_audit_paint`).
- **A sponge is held two ways** (`TablePaint._contact_for`, `Skins.FLAT_MANNERS`): flat for the manners that
  spread (sweep, blend) and onto a towel, by its corner for every other and into its paint (the corner the
  point of its surface toward a corner of its box, held through its middle). A corner lays `Skins.CORNER_WIDE`
  of its face's width, so a base takes more presses. A pad (a puff) is held flat.
- **A held tool stands in nothing** (`TablePaint._cleared`, `_held_keys`, `_pot_clear`): at every key of
  every program, found as the acts are prepared (before the bake), the tool's own surface (`tool_of`'s
  `points`, rays straight in across each face of its box every 5 mm) is measured against what stands over the
  skin seen from its front (the skin and what holds it, every 2 mm: `_obstacles`) read across its slope, as
  deep as the foam is squashed back there (`GIVE`). The way it points is the nearest a hand's that is clear,
  each other way tried (round the surface's normal and round the way the whole surface faces, to 60 degrees)
  costing its turn and how far it must stand back along itself (`CLEAR_TURN`). Where a sponge's face would
  stand off more than 4 mm its corner is tried (`FLAT_MOST`), and between two keys held two ways it is turned
  in the hand. In a pot, nothing of it under the rim is within 5.5 mm of the wall, pressed in as far as it
  gives. A skin's edge is past it (`_surface_of`, `EDGE_FACING`, `EDGE_CLIFF`): a dab past the outline goes
  to the face's last forward part. A pressed sponge is pushed in its give and squashed back to the surface.
  On its way between two places (`_held_keys`' `arcs`) each way between keys is posed as it will be played
  every 3 mm and 4 degrees of it, and lifted in an arc 3 mm clear wherever it is not pressed (`ARC_CLEAR`);
  the slope's reading of depth near a steep nose is held to 1.5 (`SLOPE_MOST`). paint_check `_held`: a sponge
  stippling by its corner and blending flat over a whole face, nose and all, stands no more than 3 mm in it as
  drawn, at its keys and between them (the control, blended with nothing held clear: 8 mm and more); dipped
  into a pot narrower than its face, nothing past the wall (the control, held flat: through it). Cost: the
  holds are found as the table stands (8.5 s on one episode, from 4.9), so a table played is built on a
  worker, the show waiting as for its bake (`TableMedium._build_away`), and a puppeteer's acts are bound on
  one (`TablePreview._stand`).
- **A press leaves a film, never a grain the size of the canvas's pixels** (`skin_paint.gdshader` `pressed`):
  each press, a stipple's or a pat's, leaves a thin uneven film (half covered, a puff's a third) that the
  presses after it fill, whole by the act's end; its edge wanders as a foam's does, and fades in over a
  millimeter.

## Watched a third time (2026-11-06, 209459)

- **A reading from the top again is no scrub:** a Stop and a Play with a changed intro makes the table and
  its bake stand, its clock start over and its plan take the intro the show holds now (`TableMedium._restart`;
  table_work_live_check, the control a scrub to the first word). The voice's stream plans again on every Play.
- **Nothing shows before its tool gets there:** a press's edge wanders and comes as the tool does.
- **It runs dry, as a hand runs it dry:** what is on the tool is taken off a share at a time (each press its
  own hand: `Skins.TAKE_SPREAD`; each load taken up more or less full: `AMOUNT_SPREAD`), so it never runs
  out, and the hand goes back for more where this load happens to stop (`STOP`, about the manner's dry: a
  stipple's a quarter, a pat's 0.3), one load in five pushed on nearly dry (`PUSH_ON`, `PUSH_STOP`). On a
  face's base: 25 loads of 11 to 29 presses. A sweep runs dry gently and evenly (`TAKE_SPREAD_SWEEP`,
  `STOP_SWEEP`, never pushed on, loaded before a long row would run it pale). A line, a dot, a smear and a
  mist lay as much to the end and go back by how much they have laid, each load its own length
  (`LOAD_SPREAD`). What each press laid is the reveal map's second channel, laid by `skin_paint.gdshader`; the
  second stipple pass fills what the first left faint. A tool takes its paint up pushed into it (a puff 4 mm).
- **A sponge dips by its end and is drawn flat on the paint** (`tool_of`'s `end`: the same corner, held along
  its length toward its far end's middle, its long side steep, as a hand dips a wedge), pushed in 12 mm
  (`LOAD_PRESS`) and drawn flat on the paint (prop_common.gdshaderinc `flat_on`, `TablePaint._flat_on` /
  `_flat_lift`: what would go under the surface lies on it, the 8 mm over it squeezed hardest nearest it and
  spread out a fifth of what it gave), dabbed two or three times as it is held there (`LOAD_EASE` between,
  never out of it, and no swirl). The pot's check is of the sponge as drawn, 2 mm off the wall (`POT_WALL`),
  held as near upright as it fits with its corner moved across the mouth for it (`POT_OFFS`). Gate: paint_check
  `_held`; `paint_look_probe --loads N` photographs them.

## Watched a fourth time (2026-11-06, 209459, feedback 0018-0022)

- **Powder is a soft round haze, not sparkles:** `Effects.BURSTS` `powder`'s `torn` 0 and `thick` 0.14
  (effect_smoke.gdshader), the paint's puffs fewer, larger and slower to go (`TableWork`); smoke's torn
  billows lit against the dark read as little bright stars.
- **A painting tool is on what it paints while the law has it pressing.** `episode_bake_probe --audit` says a
  painting tool off what it paints while pressing (straight in along the face's front, against the surface's
  normal) and `--held` says each program's stand-offs and lifts. The lift that clears a tool between dabs is
  never along a pressed stroke and never beside a key (`ARC_ENDS`); a brush stands off its surface no further
  than its hairs give (`BRUSH_STAND_MOST` 1.5 mm); a place by the mask's rim is cast onto the surface itself
  wherever any corner of its cell is on it (`at_mm`); a brush dips into its paint (`BRUSH_DIP` 3 mm).
- **The work is a part at a time** (the brief's "The work"); where a feature lands is the drawing board's
  (below). An element's shapes apart are finished one at a time (`Skins._islands`: rows, or a stipple's
  passes).
- **Lines are short pulls, not one perfect stroke:** a line's runs are cut only at sharp corners and drawn
  in short pulls (`Skins.PULL` 6-16 mm, each its own length and pace, eased; begun `PULL_OVER` back over the
  last; lifted `PULL_LIFT` between; now and then one gone over again, `PULL_AGAIN`), a look back only where a
  run ends (`_pulls`).
- **The script:** the reader's silence falls only where a thought is finished, and what follows turns
  (rules/table/reader.yaml `quiet`); the brief's voice is the genre's monologue of vindication, its beats an
  argument that builds. Open: the liner 14 mm into the face once; the sponge and the puff stand 11-26 mm off
  the mask's very rim, against its cradle's board.

## Watched a fifth time (2026-11-06, 520084, feedback 0024-0031)

- **A candle's shadow is drawn straight into its paraboloids** (`TableLight.candle_shadow`: poles up and
  down, the table about the flame at their rims, where they are finest; its filter counted in the slot's own
  texels, `ShadowFilter._cubed`), and what casts is cut fine enough for a paraboloid (`ShadowCasters`,
  render/: no edge over 1.5 cm) by a shadow-only twin of its points alone, cut once a mesh, the mesh itself
  no longer casting (cutting every attribute of a scene's meshes took 7 s; its points, 0.2); a mesh that only
  casts is cut in place; a sheet given a new shape as it plays (a page turning) says `shadow_own` and casts
  itself. Run over the table as it is built (`TableMedium._build_episode`) and the desk as it is dressed.
  Why: Godot draws an omni light's cube at half its atlas slot, so the filter spanned a texel and a half of
  what it reads (an omni light's filter is counted in its cube's own texels: `ShadowFilter.OMNI_MAP`, its
  normal bias with it), and Godot copies the cube into the slot's paraboloids through a linear sampler
  (copy_effects.cpp `copy_cubemap_to_dp`), averaging a thin caster's depth with the far tray behind it at
  every silhouette, drawn out along a grazing light into jagged smears. Not `SHADOW_DUAL_PARABOLOID` turned to
  face down for the rendering of the cube (a big triangle's depth is drawn wrong in a paraboloid: a 40 cm plate
  cast nothing). A still flame's own flicker leaned its light 1.5 mm and the map's texels with it, so a
  candle's light stays put in still air (`TableLight.tick_props`; it leans in a draft or aboard). Gate:
  table_shadow_check: a 6 mm rod 30 cm from the flame, its edge 3.1 px off a line where the cube's strays 7.0
  (control), the plate's shadow there again, no rings, the cloth whole.
- **The face's rim has no ridges** (`FaceForm._pulled_in`): every grid point is kept and its outer band is
  pulled in along its way from the middle, its edge on the rim, its rows running into it, the grid untouched
  inside `PULL_FROM` (0.72 of the way out, past every feature); cutting the grid where the outline crossed it
  made a sawtooth all round. The surface's grid of where it faces (`TablePaint._surface_of`) takes each
  normal from the surface's slope, from the points either side, not from the one facet a ray landed on (a
  mesh 1.5 microns narrower turned its normals by up to 30 degrees at the nose's tip; paint_check).
- **Powder does not twirl:** powder wanders not at all, sinks, and is one faint cloud of many soft puffs over
  each other (`Effects.BURSTS` `powder`, `TableWork`'s paint dust), and rises only off the puff's first press
  after it took up its powder (`Skins._Prog.dab`: `pats` at a load's first press), none off a sweep.
- **A pat is quick and light:** about two a second, lifted 4 mm (`Skins.PAT`, `PAT_LIFT`), and a puff's second
  pass (a powder's excess taken off) presses again where it lies, never slides (`Skins.blend_manner`, manner
  `press`); a brush and a sponge's flat face still blend by strokes.
- **A hair's bend is across the hairs alone** (`Bristles.target`): dragged, back against the way the tip goes
  across them; pressed, along the surface the way the tip goes (away from where the handle leans over it; a
  skin hold carries the surface's normal, its eighth entry). A bent hair is an arc of a circle as long as it
  was (`Bristles.bent_at`, the shader's same arithmetic). Gate: paint_check `_hairs`.
- **Paint is where the tool touches.** A reveal map used to give every point the moment of the nearest place
  the program reached (`Skins.when_map`). What a pressing tool touches is what it paints now, for the
  sponge's stipple and the puff's pats (`TablePaint.TOUCHED`): its surface found every millimeter
  (`tool_of`'s `touch`), held at each press as it is drawn (`_surface_hold`, its corner pushed in as far as
  it gives), and every bit of it within 0.6 mm of the face or in it stamped (`_touched`, `Skins.touch_map`);
  a point no press touched is never shown (`Skins.NEVER`). It lays as wide as it touches (`_touch_width`: a
  sponge corner 15 mm, a puff 18), a load covers an area of the face (`Skins.LOAD_AREA_DABS`, `_PATS`), and a
  sponge bounces quicker (`Skins.DAB`). Gate: paint_check (the first press shows about what its corner
  touches; control: shown by its program alone, every point shows).
- **A stipple fills within a ring before the next** (`Skins._grown`): its presses are one pass, round and
  round out from the middle. Gate: paint_check (no press comes back more than three inside where it has been;
  control: two passes one after the other, seven).
- **A hand goes back over what it missed** (`TablePaint._cover_gaps`), as the table stands, before any act's
  length is known: the presses planned (`Skins.press_places`), held as they will be drawn, what they touched
  looked at (`_gaps_left`), and every gap of 1 mm2 or more (`GAP_LEAST`) given presses of its own (as many
  as it is large, spread over it), each put in right after the press that last laid paint round it
  (`closed`), aimed so what it touches lands on it (a corner touches to one side of where it is aimed),
  pressed harder after the first look (`PRESS_HARD`); five looks (`GAP_ROUNDS`). The touch test reads a rim's
  wall as the board beside it (`TOUCH_STEEP`). A pad gives (`PAD_GIVE` 8 mm), is drawn squashed as a sponge
  is, and tips onto its edge where its face cannot reach (`tool_of`'s pad `corner`). Results are kept by what
  they were found from (`_clear_memo`, `_arc_memo`, `_touch_memo`). Cream spreads under the foam: a point
  all but closed in by what is laid round it (5 of its 8 neighbours) is laid as its last neighbour is, twice
  (`Skins.closed_in`, in the reveal map and in the loop's look alike). A press put in where the first missed
  is held the way that reaches it, looked at before it is laid: where its own way misses where it is aimed by
  more than a millimeter, each other way the tool has (its corner, its long end, its face: `WAYS`) is tried
  and the one that touches nearest taken (`_press_miss`, `REACH_BETTER`); and what no tool reached is painted
  all the same (`_painted_anyway`: every point the last look found bare is laid when the touch aimed nearest
  it comes down). Gates: paint_check (what the stipple left bare put right, control the first look; the
  holes paint closed round, most pressed within 5 s, control two passes one after the other; every put-in
  press held another way is one its corner missed and the other reaches nearer, control no press held but by
  its corner; what was left bare laid with the touch nearest each point, control nothing added with nothing
  bare). The result on a real mask: what is left is what the tool cannot reach (beside the nose, 49 mm2
  along the rim at one look, none the paint closes round).
- **Brushes paint where their hairs touch.** A brush laying a fill or blending is held low, by the side of
  its hairs (`belly`: `HELD_LOW`, about 30 degrees off the face) and pressed deeper (`BELLY_PUSH`, a fifth of
  its hairs); every key knows the way its stroke goes (`_dirs_of`, the hold's ninth entry), and a flat brush
  is turned to it (broadside across a fill, on its edge along a line, whichever way round is nearer so it
  never turns over: `_node_at`, a tuft's `across`). Its hairs paint what of them touches (`tool_of`'s hair
  points, the lower two thirds, bent in `_touched` by the shader's own arc; each stroke looked at every half
  millimeter; `BRUSH_TOUCHED`), on a map four pixels a millimeter (`BRUSH_PX`). A pressed brush's hairs bend
  no further than keeps their tip on the face (`_bend_to_surface`, the shader's and the touch test's alike).
- **A brush goes back over what it missed too** (`_brush_gaps`, as the sponge does): each line and fill's
  strokes looked at as they will be drawn (`_stroke_touches`), every gap of a square millimeter or more
  given a dab right after the planned stroke that last laid paint round it (`Skins.program`'s `inserts`),
  five looks, the dabs after the first pressed harder. Classes of fault it found: the bend that keeps a tip
  on the face is counted along the mask's own depth, not along the face's normal (a forehead slopes back from
  that depth, and a tip 4.7 mm deep by depth was lifted clear); the face is read between the cells for putting
  a tip on it and the bend is the least either way that brings the tip onto the face, found in growing steps
  then halved (`TIP_STEP`, `TIP_HALVES`), no more than twice what a flat face would ask (`TIP_REACH`); each
  dab is tried before it is laid (`_dab_miss`): at the gap, and off by as much as the hairs aimed nearest it
  touched off their aim where they missed it, whichever lands nearer. Gate: paint_check (a liner pressed all
  over a face, its bent tip on it at 165 of 165 places, the control bent along the normal 75; the brow's gaps
  put right, control the first look). Open: the crease between the lips (16.5 mm2, under the lips' red and
  not seen in a render), and the frost's fan brush on the cheeks.
- **No ragged bare band along the rim:** a press's ragged edge reads the reveal map up to 1.6 mm off each
  point (`RAGGED`), so the edge's moment is carried out past what the element covers as far as that
  (`Skins.touch_map`'s spread, `PRESS_RAGGED`), where nothing ever shows. Gate: paint_check (two points past
  the stipple's edge, 517 of 521 hold a moment; the control, 46 of 523).

## Painted where the tool touches

Paint is laid where a tool touches, with the tool's own contact, not at its tip: you do not paint with the tip
of the bristles but with the side of them, back and forth, in many directions, turned to the fat side for wide
strokes and to the corner for fine ones. A program that says where the tip goes and lays a disc of the tool's
width round that path agrees with the tool only at one point, lays the same disc whichever way a flat brush
is turned, and never lays the hairs' side on the face.

The plan, the tool's contact is the paint:

1. **A tool's contact patch,** from its pose and its hairs' bend (the shader's own arithmetic,
   `Bristles.bent_at`): the part of the bent hairs within a fraction of a millimeter of the surface (the
   belly of a pressed round brush, the chisel of a flat one across its width or along its edge as it is
   turned, the tip of a liner held up; a sponge's corner or face; a puff's disc).
2. **Programs move the patch, not the tip:** a fill swept with the belly, the handle low (25-35 degrees to
   the surface), back and forth in changing directions, a flat brush broadside for cover and on its edge to
   cut a border; a blend buffed in small circles and wiper strokes; a line pulled with the tip, the handle
   higher; a puff pressed and rolled.
3. **The pose is found from the patch:** where the hand must hold the tool so its bent hairs lie where the
   program puts the patch, never floating, never stretched.
4. **Paint is laid where the patch has been,** each moment's patch stamped along its real path (the reveal map
   from the posed tool, not from the program's line).
5. **With the drawing board (below):** the patch reveals the reference painting's own pixels.

## Pulled through, bent over (2026-11-07 - BUILT; looked at on 520084's frames, not yet watched by the user)

- **Pulled through** (`TablePaint.HELD_PULL`, `_pulls_of`): a brush pressed along a stroke leans its handle
  the way it goes, at one angle to the stroke, so its hairs trail; lifted, it is turned as it went, or as it
  will go, so it comes down already turned. Back and forth along a fill's rows the wrist rocks it over
  between them (the keys' axes slerp through upright), never turned round. A dab goes nowhere and is held as
  before. Toward the lens a line stands up half as far (`PULL_TOWARD`); a fill on its belly does not (stood
  up, a flat brush laid half its belly and streaked between its rows).
- **The core stays under the hairs** (`Bristles._core`, `CORE_*`, `core_at`): the tuft's core is a solid body
  that stands for the inner hairs and takes the paint; it is no taller than the outer hairs, takes 45% of
  the paint, and pressed it draws in and down under them (the shader and `_touched` the same arithmetic; it is
  told by its UV's x). Taller, over the outer hairs' ends it is the brush's surface: a solid ring of paint.
- **Leaned, the hairs bend** (`Bristles.SPLAY_LEAN`, `SPLAY_LEANED`): the splay is all of the press straight
  down and a quarter of it leaned 30 degrees or more; the bend that keeps the tip on the face
  (`_bend_to_surface`) takes up the press, so the bristles bend more than they balloon.

Gate: paint_check (the eight ways and the brow's keys, the keys' ways, the core under the outer hairs, the
lean's splay, and the go-back loop on a band wider than the liner). Looked at: the go-back loop has less to
put right almost everywhere; the table stands in about 32 s.

## What touches is what is laid

Watching real episodes: the puff clips through the nose and is always perfectly flat; the liner's hairs curl
into a tight arc; a fill's rows pull through the black line and onto the outside of the diamond, its paint
inside the diamond alone though the brush touches the mask the entire time; diamonds have rough edges a
precise artist would clean up; lips are fainter at the top and smear outside the lines at the bottom once
blended.

- **A pressed pad or sponge takes the skin's shape** (`TablePaint.press_lands`, `_press_of`, `_press_point`,
  `_press_on`, `_press_field`, `pressed_drawn`; prop_common.gdshaderinc's `press_`): each bit of it is drawn
  from the skin's heights read every millimeter (`PRESS_CELL`): what would go in it lies on it, a pad's face
  sags into a hollow beside what it is pressed onto (`PRESS_SAG` of what it gives; a sponge's denser foam
  does not), and its back keeps `PRESS_THIN` of its depth over the skin, so pushed past that the whole of it
  bends away. A pad's `_touched` is the same arithmetic, so what is drawn touching is what paints; a
  sponge's keeps the reading its stipple's go-back loop was tuned to. Gate: a puff patting a whole face is
  drawn 0.1 mm in it at most (held flat, 16 mm), and pressed its hardest six times as much of its face lies on
  the face as held flat; a sponge 0 mm where held flat it stood 2.7.
- **Hairs are stiff** (`Bristles.SPRING_HZ` 9, `SPRING_DAMPING` 0.75, `DRAG_BEND` 0.2): nothing in the air
  bends them, a drag on the face bends them half as far, and let go they are back within a tenth of a second,
  past straight by 2%.
- **A brush's paint is where its hairs touched** (`Skins.touch_map`'s `foot_out`, skin_paint.gdshader's
  `foot`), reaching past the shape as far as the tool is wide, smoothed as paint spreads (`Skins.FOOT_SOFT`,
  `FOOT_HALF`, `_blurred`): the touches are shrunk to a point a millimeter and grown back, and laid where
  that is half whole, so a lone bit fades, a pinhole closes, a millimeter's line stays whole.
- **A fill keeps inside its shape** (`Skins.CUT_IN`, `sweep_paths`, `_cut_in`, `_eroded`;
  `TablePaint._keep_inside`, `_ease_off`, `SPILL_*`): it goes once round inside each outline, half its
  brush's width in, the side of the hairs along the edge, and rows back and forth over what is as far inside;
  then each stroke is looked at as it will be drawn and, wherever a bit of its hairs touches more than half
  a millimeter past the shape, eased off (pressed half as hard there, down to a quarter, as a hand lightens
  near an edge) and cut back only where it still runs past that lightly, up to six looks. A dab put in for a
  gap that would run past a fill or a line is left out. A fill too fine for its brush (nothing of it keeps
  inside even eased off) is laid as planned and cut to its shape: a hand would take a finer brush, or pull
  each point out with the tip, and neither is built.
- **A blend softens where the blending brush went** (`TablePaint._blend_touches`, skin_paint.gdshader's
  `blend_map`; `Skins.BLEND_SHARE`, `inner_reach`): a point softens as the brush's hairs reach it, and a fill
  no further than a third of the way to its middle.

The lips' black outline stays (the curly parts warrant it). The face is painted from a reference picture
("The painting is the design"), not from a blueprint of shapes.

Open: a fill too fine for its brush laid as a hand lays it; a touch-up for what does go wrong (paint past a
shape looked at once laid and taken off with a clean damp brush or the base laid back over it); a design's
hand, precise or loose (clean lines, or smearing and bleeding), the decorator's to say and the spill
allowed by it; a line as wide as the liner's touch, which may be narrower than the line drawn.

## The hand at the cup, and the brush that does the work

- **A sponge squeezed in the hand:** rinsing, it is squeezed across its broad faces (not lengthwise), both in
  about its middle and back out to its own shape (`TablePaint._squeeze_of`, prop_common's `squeeze`, at most
  half as thick); pressed on the towel or into its paint it still gives from the side pressed.
- **A base reaches the edges:** the fills a design opens on that each cover 60% of their surface are laid
  over all of it (`Skins._based`, in `sanitize` wherever the outline is known), and the decorator is told so.
- **A brush pressed past its point:** its tip gives as far as its belly (`TablePaint.TIP_PUSH`, a fifth of its
  hairs), and a line presses it as far as the share of the brush it is wide (`Skins.program`,
  `LINE_PRESS_LEAST` 0.15). Any press counts as pressed (`TablePaint.PRESSED`).
- **A brush worked into its paint, its hairs wet:** swirled round twice out to 4 mm and drawn across as it
  comes up (`TablePaint._brush_load`); the paint on its tip over the end half of its hairs, glossy, and half of
  it left until it is rinsed (prop.gdshader, `TIP_LEFT`).
- **Pulled, never pushed:** every way of a fill, a line's pulls and an outline cut where it turns against
  how the hand leans the brush there, and each piece drawn toward the handle, lifted back between
  (`Skins._pulled_ways`, `pull_toward`). A fill's rows 14 mm/s, its edge 10.
- **A fill too fine for its brush is drawn along its middle:** its spine followed in pulls at a line's pace,
  each point pressed as far as the shape is thick there (`Skins._spine`).
- **A design's colors are the table's paints:** an element is laid in the paint of the pot it is taken from
  (its act's `from`, else the nearest paint on the table: `TablePaint._pot_of`) as thick as brings that
  paint over a light face to the design's lightness (`_thickness`); one thinner than `THIN_WET` is taken up
  on a brush wetted in the water first, rinsed and not dried; one with an edge as soft as `SOFT_GONE_OVER`
  goes on crisp and is softened as its tool goes back over it in the same act. Two elements from one pot are
  one load. The tip shows the pot's paint.
- **One coat of a paint; a tool's acts one after another:** a design's fills over the whole surface in one
  pot are one application, as thick as they come to together, the rest taken out of the design
  (`TablePaint._one_coat`); an act left nothing to lay takes nothing up and is no act
  (`_paints_nothing`). A tool whose next act comes straight after and begins in the paint it ends with is
  neither cleaned nor put down between them; one rinsed at the end of its act begins the next damp
  (`_one_after_another`).
- **A press is built by presses, and what is thin is put right then:** a press's film fills only where and
  when another press touches it (`Skins.touch_map`'s third channel, `AGAIN_AFTER`; skin_paint.gdshader's
  `again`); one dab leaves most of its paint (`FIRST` 0.85, a sponge all but dry `DRY_LEAST` 0.75 of it); a
  point one press alone reached is thin like a bare one (`TablePaint._gaps_left`; the look stamps as the map
  does, `PRESS_SPOT`) and is pressed again right after the later of its own press and the paint round it
  (`GAP_THIN_LOAD`). Gate: paint_check (the stipple's area one press alone reached; control, its presses as
  planned).
- **A powder is a paint:** the table's powders are paints too, a track's `from` gives its own whichever kind,
  and the nearest is of the element's kind (`TablePaint._pot_of`). Gate: paint_check `_coats` (control: taken
  as a cream, its nearest is the base's white).
- **Never short of whole:** what one press alone reached is laid again by the touch aimed nearest it of those
  after it (`TablePaint._painted_anyway`'s `firsts`). The go-back loop looks at its own estimate of what the
  tool touched, not at what the shader draws (a first dab's film, a second's filling, a 1.6 mm ragged read,
  a moment interpolated between pixels), and it stops at five looks, after which only painting it anyway
  finishes what the tool cannot reach. Gate: paint_check (a point the first press reached laid by the second;
  control, not told what reached it, by its own).
- **A line is the band its hairs sweep:** each pull laid as a clean band as wide as the line, narrowing and
  thinning over its last quarter (`Skins.band_map`), and never gone back over for gaps (laid from the hairs'
  tips found at moments apart, a line was beads, and the dabs that filled them stood out).

## The painting is the design (2026-11-07, late - ENGINE BUILT, not yet in the show)

Why a design of SVG shapes fails: the detail is gone before a tool moves (the painter makes a detailed picture
of the finished face, the decorator, a text model, redraws it as a few dozen shapes, every tool lays the
shapes, never the picture: the painting's softly darkened edge became a crisp ring, its rust texture
polygons); and whether paint lands was decided by simulating the tool, with coverage a separate estimate,
while the shader draws with effects neither shares (every mismatch a speck, a spill that left no mark, or
paint the tool never touched). The remedy is a layering problem: with enough error correction and layers,
any mask of any level of detail can be painted, and the tools give the visualization of the self-correction.
What brick mode does right: an agent decides what (a design), code decides how (exact parts), staging
animates it, and it always finishes. The painting's own version is `PaintLayers` (src/table/paint_layers.gd;
Hertzmann 1998, "Painterly Rendering with Curved Brush Strokes of Multiple Sizes"):

1. **The painting is the target,** pixel for pixel, painted with the table's own pots (laid whole or thinned).
2. **Widest tool first:** the sponge, then the flat brush, the round brush, the liner. Each pass aims at the
   picture blurred as far as its tool resolves, and paints only where the canvas still differs from it, each
   point given the paint that brings it nearest; the paints that put most right go first. Orange over purple,
   or over a black line, comes of a finer pass finding it still wants orange.
3. **A tool goes only where its footprint fits:** a dab or a stroke's every step must lie where its paint
   makes nothing worse (`FIT`, `WORSE`): never a spill that leaves no mark, never paint no tool touched. What
   a tool cannot fit is the next, finer tool's; the finest lays what is left, so it always finishes.
4. **What it lays is exactly its strokes' footprints:** the canvas it keeps is the painting. A show draws each
   layer as computed and poses the tool along its strokes; the tools are the visualization.

First run (a real picture with its table's seven creams, the four tools; 16.6 s): a white foundation, the
sponge's rust and plum masses, the brushes' grin and eye shapes, the liner's brows, tears, rivets, diamond and
lip line: off the picture (in the palette's colors) 5.2 on average, 16.5% of the surface over 10. Classes of
fault it found: a base chosen by the least average was a grey between the white and the rust (now by vote);
a picture blurred for a wide tool was painted in colors nobody mixed (now each point the color most of the
tool's window is nearest); the painted picture's own light left its white a tan (matched as a rust thinned
over the white, so its ground is the foundation's paint); a liner judged point by point chased the picture's
grain (now by area, 2 mm cells, and a dot only where well off). Open: the liner's 2,465 strokes (rust flecks
and drips; a show cannot spend a second on each: a stippling sponge's own texture, or merging, should take
most); the faint hairline cracks fall under the threshold. Gate: paint_layers_check (a white foundation
first, tools narrowing, orange laid over purple, nearly all of it finished; the control, the sponge alone,
leaves the line and the streak).

NOT A REVEAL. The picture says only where paint is still wanted; every mark is a tool's:

- A stroke is chosen, never a pixel: its tool, pot, path, way and pressure (a sponge's corner a small dab,
  its face a big splotch; a brush pulled along the form, pressed wider; a liner's line).
- A mark is drawn as its tool lays it, and the canvas the engine corrects is those marks: bristle streaks
  along a pull, a load running dry over its strokes until the tool goes back to its pot, a tail thinning, a
  sponge's pores and ragged edge; a patchy area is gone over again as a painter would.
- The show plays those strokes through the motion it has (programs, held poses, hairs bending, the sponge
  squashing, trips to the pot); its paint is the marks' own coverage, revealed as the strokes are laid.
- First, the agents as they are: each decorator element is the region its act works in, with its pot and its
  tool; the engine fills it from the picture, element by element in the acts' order, on one canvas.

Built (`TablePaint._from_picture`): lays every element a sponge or a brush lays by dabs, dots, pulls or
lines from the picture, element by element in its acts' reading order, on one canvas: its act's tool, its
pot, its shape grown 3 mm as where it works; its program the strokes `PaintLayers.lay` chose, made by
`Skins._Prog` (the show's own loads, trips back to the pot, hand); its paint their coverage (`foot`), its
reveal their moments; nothing looked for after. The first element filling the whole surface is a
foundation: its own paint, whole, gone over at what is still bare until no speck shows. An element the
picture wants nothing of in its place lays nothing, and its act takes nothing up. A hand looks at its work
once every few strokes (`LOOK_EVERY`); an operation draws at most `PULLS_MOST` strokes and `TAPS_MOST` taps.
A tool is not pressed only as hard as it goes: each mark is tried at lighter presses until one fits, narrower
as a brush is lifted (`DAB_PRESSES`, `PULL_PRESSES`, `LINE_PRESSES`). Each operation draws the most wanted
strokes its act's planned time holds (`PICTURE_SLACK` of what its shape's program took, the length the
readers' words were written to), in the hand's order, so the work does not run past its words; the
foundation alone is laid whole whatever it takes, its last looks aimed at patches big enough to see
(`BASE_AREA`). Gate: paint_check `_picture` (the foundation and a brushed element laid from a picture, the
brush's black on the picture's black and not on the white beside it in its own shape; the control, no
picture, the shapes as before). Looked at in the show on the GPU (`episode_bake_probe --shots`): the
foundation whole to the rim, the rim shade a soft warm tint at the face's edge where the decorator's ring was
a hard band, the liner's rust runs beside the seam.

- **A sponge dabs with whichever side the work needs:** the corner for smaller detail work, the flat side for
  larger surface areas. Each dab is judged by what that side really touches there, as the show poses it
  (`TablePaint._side_touch`, handed to the engine as `touch`): its face where it lands most on what still
  wants paint, its corner where only a corner fits; the program says the side by place (`way_at`) and
  `_held_keys` holds it so; its mark is the touch itself, softened and cut a little ragged, a thin film
  (`FILM`, pores), shown as the sponge meets the face (`DAB_MEETS`), never spreading after. Goings-back are
  spaced by the dab already there; what no side reaches is painted anyway with the nearest dab. A sponge is
  loaded on the side it dabs with (`_side_after`, `_pot_hold`'s `side`: its face tilted into the pot,
  narrower than it, a corner tapped); a load is spent by what it lays (`LOAD_AREA_DABS` holds this dab's
  touch, counted in a corner's dabs); and a thin film each dab.
- **The sponge is pinched, not pressed flat:** squeezed in the hand, it is thinnest under the finger and
  thumb and less so away from them, its ends their own thickness and a little more (prop_common's
  `squeeze_reach`, `SQUEEZE_EDGE_SWELL`; `TablePaint._squeeze_reach`, `SQUEEZE_REACH`).
- **Laid over the pot, area by area, built up as laid.** A face wider than a pot's mouth (`_wider_than`)
  rests flat on the rim (`DRAPE_CLEAR`) and only bends: pressed, its middle goes down onto the paint and a
  little past it (`DRAPE_INTO`), its back further under the finger (`DRAPE_DENT`, `DRAPE_FINGER`), nothing
  past the wall, what lies outside the mouth over the rim, its faces turned as it bends (`_drape_on`,
  prop_common's `drape_*`); a part of a material that gives is cut finely across its faces (`Props._fine`'s
  `_gives`), or no press could bend it. The dabs go area by area: a coat is shared out among areas three dabs
  across (`AREA_DABS`), begun where the broadest side lands most of itself nearest the middle, each area
  worked whole (its dabs the nearest next, then gone back over until nothing in it is short: `AREA_LOOKS`)
  before the hand moves to the area beside it nearest where it is (`PaintLayers._coat`, `_area`,
  `_next_area`); an area works its own points, each cell's worst among them. The sponge keeps the side it
  holds while it lands mostly on what wants paint, one side then the other in each pass (`SIDE_KEEP`,
  `_side_for`). Built up as laid: `PaintLayers.render` says what each point holds after its first marks and
  after its last, and when (`built`, `built_when`; skin_paint.gdshader's `laid_*`, `BUILT_SLOTS` 8, `laid_map2`,
  `laid_when2`), so a print shows its own film and the next thickens it; each print is lighter toward its
  edge (`EDGE_FADE`, `EDGE_FADE_SHARE`, `EDGE_LEAST`), its edge wandering (`TOUCH_SOFT`, `TOUCH_RAGGED`,
  `TOUCH_FEATHER`) and pressed hardest in its middle, its farthest corners least (`CORNER_FROM`,
  `CORNER_LEAST`), some lighter than others (`FILM_LEAST`), and fainter as the load runs out
  (`DAB_DRY_LEAST`; a brush's pull keeps `DRY_LEAST`). A dab lays what is on the side it presses, as hard as
  it presses (`PaintLayers.deposit`: `FILM` of a fresh load pressed hard by the side just loaded, its load's
  share of that `LOAD_POWER`, a light press less `PRESS_DEPOSIT`, a side other than the one just loaded half
  `OTHER_SIDE`). Gates: paint_check (the face laid over the mouth: flat, nothing past the wall, its middle on
  its paint; the controls, unbent it never reaches the paint, fitted inside it is turned far over),
  paint_layers_check (the hand comes back to a square it left half as often as rings at most; a point holds a
  thin film after its first mark; the controls).

- **The audit.** A second opinion (read-only, on the code, the reference and the engine's own canvas), its
  central claims checked against the code:
  1. The target throws the detail away before a mark is chosen: `_aim_for` replaces every pixel of the
     reference with the nearest of the pots-over-the-ground at four opacities, then the majority over the
     tool's width, so no gradient, flake, crack or highlight survives, and `NEED`, `GAIN` and the 2 mm cells
     reject small corrections.
  2. The decorator's element is the unit of everything: one tool, one pot, its traced region (crude
     polygons, a sparse crack network), its act's slot and a budget of its old SVG program's time; whatever
     the trace missed can never be painted, and nothing goes back over the whole face at the end.
  3. Marks are judged by a proxy: `_fit` tests a disc at the heaviest press, not the mark the raster draws; a
     stroke with no slope to follow goes horizontal; lines under 2.5 mm become capped taps.
  4. The show does not draw the canvas the engine judged: the engine mixes in linear light, the skin's
     viewports blend sRGB sprites and the prop shader unpremultiplies and decodes after.
  5. Powder, mist, blending and gloss are outside the planning canvas.
- **The engine rebuilt,** measured with `tests/table/paint_preview_probe.gd` (the show's own canvas at any
  moment, read back from the GPU after setting the paint alone to that time: no bake, since a frame at 37:00
  had taken half an hour of playing up to it), beside the picture, with how far it stands from it:
  1. One compositor: the engine's canvas is the skin canvas's own (paint times coverage blended as sprites
     over clear, shown over the bare surface as prop.gdshader shows it: `pre`, `alp`, `_shown`, `_after`).
  2. The picture itself is the aim for every operation but a foundation, point for point; its ground is
     balanced to the foundation's paint and its light taken out where it falls off (a flat field from the
     ground's own points, `_ground_shade`), since the painted picture's soft shadow at the rim and beside the
     nose is copied as a brown ring and a grey line otherwise.
  3. Marks are fitted by what they really lay (`_fit_op`): where laying the pot helps most (`_regain`), the
     next near the last; a stroke traced along the run of what still wants it (`_way_at`: across the slope of
     that want, else the long way of its patch, else as a hand pulls; never a horizontal default), each
     candidate rastered at each press and thinning (`THINNINGS`: a dark pot thinned is its tint) and laid only
     where it puts at least `MARK_GAIN` right overall and `MARK_AVG` on average, a point made worse counting
     `WORSE_WEIGHT` times. Smears are laid this way too, as lines of the paint they drag.
  4. Where and how long: an operation works `REGION_GROW` (8 mm) round its element, `PICTURE_GROW_LINE` (15
     mm) round a line or dots; at most `PICTURE_SLACK` of its shape's time, its readers told `PICTURE_TOLD`; a
     blend softens what was laid from the picture no more than `PICTURE_BLEND_LOD`.
  5. The foundation without misses: going back over, a print lands at least `LOOK_LEAST` (half) on what
     still wants paint, aimed at the middle of what wants it; a load lasts `TOUCH_LOAD_AREA` of printed paint;
     whole to `BASE_NEED` 3 and its last thin places evened by the print beside them (`BASE_FINISH`). On a
     real face: 501 prints in 6.8 minutes, 28 trips to the pot, 0.98 of the face covered, 73% of each print on
     what wanted it.
  6. A powder is no longer gone back over, and the face painter is told the table's paints
     (`Skins.table_paints`, painter.yaml `face`), since a picture can ask for a color no pot holds.
  Measured, the show's own canvas against the picture at the end: 13.5 off on average with 50% of the
  surface over 10 (before: 22.4 and 80%): brows, eyes, drips, the diamond, the seam and rivets, the smile,
  cracks and rust in place. The table stands in about 90-105 s: noise is read from a table made once
  (`_noise`, `NOISE_SIDE`), candidates are weighed by a plain print (`raster`'s `quick`), a sponge's narrower
  sides are asked only where its broadest helped too little, an operation gives up after `FIT_REFUSED_MOST`
  refusals in a row, a foundation never weighs thinnings it does not use, and its evening finds the nearest
  print by cells (`EVEN_CELL`). Skipping ahead is the physics' bake (8 to 10 times as fast as the show, the
  rigid bodies and liquids its cost: `episode_bake_probe --profile-bake`), not the paint. A brush's dot is as
  small as its tip (`TIP_LEAST`), crisp (`TIP_RAGGED`, `TIP_SOFT`), a stroke as narrow as `PRESS_NARROW` of
  its width, and the show's maps are drawn at `FOOT_PX` 4. Open: the rust's color (the pots), the eyes'
  blotchy shadow, the total length (about 44 minutes of painting), and an agent in the loop choosing each
  operation from the canvas as the show will draw it, the engine laying it. Up close it is still far from the
  picture (the eyes broad overlapping strokes, the rivets grey dots, the rust a wash), which is the
  decorator's acts (one tool, one pot, a rough region and an old program's time each) more than the marks.

## The painter (2026-11-08, late - BUILT, gated with a script in an agent's place; no real agent has run it yet)

The act structure forces an entire act to use one tool; a real artist restricts tools to the job, starts with
layers and wide areas, and keeps refining at every step, and an agent can look at each step and decide what
to do next. (The decorator's `look` hands AgentTools the picture itself, not a file's path, which it drops;
skin_step_check holds it.)

- Where a face was painted first and the writer takes tools, the `skin` step is the painter (`PainterTools`,
  rules/table/painting.yaml, `TablePrompts.painting`): it paints the picture again at the table an operation
  at a time (a tool of the table's, a paint of its pots, how: sponge, dab, sweep, line, or a powder patted
  on; where: a closed path in millimeters, or all; how strong and how long; in one of the episode's beats: its
  intro, each stage of the plan with its `work`, its close) and `look`s after each: the picture, the canvas as
  the show will draw it, and where it is still off, on a 10 mm grid. [PaintLayers] lays each on that canvas
  (on a worker; a sponge as a disc there, its real sides at the table); `undo` puts the canvas back; `submit`
  hands in the design, an element an operation, its `plan` (tool, how, beat, seconds) beside it. Elsewhere
  the decorator designs.
- Its acts are made from it (`TableProducer.acts_from_painting`): beat by beat, in the order laid, each run of
  operations with one tool and one way an act (the hand putting one tool down and taking the next as the work
  asks, the beat's passage spoken over them all), each told the seconds its operations took
  (`Skins.act_natural` reads `plan.seconds`), and laid at the show in that time (`PLANNED_SLACK`) and the
  region drawn (`PAINTER_GROW`). A design no painter laid goes to the puppeteer as before.
- Tried with a script in the painter's place (16 operations in about 22 minutes of painting): its canvas 12.7
  off the picture where the decorator's 40 acts came to 13.5 in about 44 minutes; the show standing it 15.7.
- Open: the show should replay the marks the painter saw, not lay its operations again (one plan, one
  canvas); a stroke in a broad region with no run to follow goes one way (eye shadows come out as bars); a
  mist, a glitter and stones are not among the painter's ways yet; a real agent's run, a new episode made from
  the plan up.

Still to build: the decorator naming only each beat's region and the finishes a picture does not carry
(gloss, glitter, stones), the layers painted beat by beat inside them; the paint acts made from the plan by
code, as brick mode lays parts. Probe: `tests/table/paint_layers_probe.gd` (an episode's `face_ref.png`
painted in layers, each pass's canvas beside the picture).

## The painter's first run, and what it could not do (2026-11-08, night - BUILT; looked at on the painter's own 28 operations replayed)

A real painter run (27 operations in about 19 minutes) came out recognizable and flat: crackle missing,
lips and eyes smeared instead of feathered. Any brush can be applied with varied pressure (a thick brush can
paint small lines or dots: the brush size option in any paint program). A fade-in of the picture was left
out: it would show, and it is not paint.

- **A line operation draws the picture's own lines** (`PaintLayers._trace_lines`): found at the picture's own
  resolution (`hi`, 3 px/mm, where a crackle's hairlines are a pixel), where the picture is the paint or
  stands nearer it than what is round it, followed on where a line fades (hysteresis), its dotted gaps
  bridged, thinned, and followed as a hand draws: through where lines meet, joined to what is drawn, on
  without lifting into the next that begins where one ends. Each is pressed to the line's own width point by
  point; one wider than the brush filled with passes beside it. Short lines are flicked (`TRACE_SPEED`), long
  ones drawn with care. Where an operation finds lines it draws only those. The answer tells the painter how
  many it found, drew, and how long the rest would take.
- **Pressed to the width** (`_pressed_to`, `_wide_at`): a fitted stroke is tried pressed point by point to the
  width of what still wants its paint, and traced as wide as that: a fat brush follows a hairline with its tip
  (`PRESS_NARROW` 0.12; a dot as small as `TIP_LEAST` 0.15 of the brush).
- **A brush's belly** (`BELLY`): a pull thins out over the outer half of its width, a blend's more;
  overlapping strokes build a gradient and feather.
- **One stroke one color** (`TRACE_SAME`): a stroke runs on only while the picture (softened over a
  millimeter) stays the color it began in.
- **Mixed on the palette** (`mix`, `PaintLayers._mixes`): an operation may name creams to mix with, and each
  mark takes the mix (a quarter, a half, three quarters: pigments' weighted geometric mean, so they darken as
  paint does) that brings the canvas nearest. A mark carries its colors (`cc`), the show draws an element's
  own colors from `PaintLayers.render`'s `tint` (skin_paint.gdshader `tint_map`).
- **A blend** (`how: blend`, `_blend_op`): no paint; a clean brush, rinsed first at the show, pulled short
  across edges the canvas has and the picture does not, taking up what it passes over (`BLEND_PICK`) and
  laying it on along the way, each pull kept only where it brings the canvas nearer. Its marks carry what they
  picked up.
- The painter keeps every operation's marks (`PainterTools.laid`), the first step toward the show replaying
  what the painter saw, and its looks are at 3 px/mm.
- Replayed: the closed eye has its lashes, the brow is one arc, the tear its gold edge, the lips soft with
  their light; the crackle real lines where the painter gave them time. A bruised eye is still one mass of a
  mix: the painter's to work in layers.
- Open: the show replaying the painter's marks (brushes exactly; a sponge's real sides differ); a mix's tool
  dipped into both pots; a sponge's blend (pressed, never slid); a foundation still about eight minutes; the
  author's eye on a new episode.

## Back to the drawing board

Why a decorator that draws the whole face fails: it draws it from nothing, as SVG paths in millimeters, from a
sentence of the producer's. A text model drawing paths gets crude geometry (diamonds, a stock lip outline, an
arch with two curls), flat fills and one line weight, and it places features by numbers it is told, not by
looking (lips drawn 6 mm above the sculpted ones). Brick by Brick's lesson (next/assembly.md): the agent says
what, in the form it is good at, and code does how.

The plan, a painting first, copied:

1. **The reference (`image:face`).** The mask is rendered bare from its front (orthographic, the surface's own
   millimeters, flat even light), and the painter paints the plan's `painted` onto that picture, image to
   image, so its eyes, nose and lips are the mask's own and every feature lands on them. An image model is
   good at exactly this: style, gradients, fine filigree, highlights. The art director looks at it as it
   looks at a card (`check:face`): a clown, on this face, nothing past the mask's edge, no hair, no costume,
   no lighting painted in; sent back with its faults, as a card is.
2. ~~**Its own colors on the mask.** The paint laid is the reference's own pixels~~: rejected. The tools lay
   their own paint, and the painting says only where and what.
3. **Taken apart into work, by code.** The reference is separated into what a hand would lay
   (`Skins.separate`): its colors clustered (Lab, as many as it has paints); each color's regions traced (a
   fill: rows or a stipple by its size; a thin one: a line along its middle, in pulls; a small one: a dot);
   each region given to the part of the face it is on by the mask's landmarks (an eye, the other, the brow,
   the mouth, a cheek). Code proposes the elements; nothing is drawn by hand.
4. **The decorator stages it.** Its job becomes the order and the manner: which part first, a part's outline,
   color, shading and details in turn (the brief's "a part at a time"), each element's finish (gloss on the
   mouth, glitter, metal), which tool, and what is too small to be worth a stroke. Its `look` shows the
   reference beside the elements laid so far.

Open for the author: whether the painting may carry soft shading and highlights (truer to a makeup artist's
work, harder to copy by hand) or should keep to flat colors and clean lines (truer to cream paint); and
whether a face may be sent back to the painter by the decorator as well as the art director. Taken for now:
flat colors with clean edges, a highlight as a shape of its own, soft only where a sponge softens an edge
(what takes apart cleanly); the art director alone sends it back, as with a card.

**Built, steps 1, 2 and 4 in a first form; step 3 not:**

- **The face painted first (`image:face`, then `check:face`)**, between the table and the design, on a show
  whose plan paints (`TableEpisode.wants_face`: an episode designed before goes on as it was made; designed
  again, it starts from one). The table's first surface is shown bare from its front, lit evenly from the
  front, on black, three pixels a millimeter, in the middle of an upright 2:3 canvas (`Skins.face_canvas`,
  kept as `face_bare.png` with where it lies, `face.json`); the painter paints the plan's `painted` onto it
  (rules/table/painter.yaml `face`: in its own frame, only paint, a hand's paint), and a painting that does
  not lie on the surface (its box off the surface's by more than 5% of the canvas, or past its edge) is
  removed and painted again (`Skins.face_fit`). What is kept is cut back to the surface's millimeters with
  the bare light taken out (`face_ref.png`, `Skins.face_reference`). The art director looks at it beside the
  bare surface (art_director.yaml `face`) and keeps it or sends it back with its faults
  (`sent_back_face.json`). Pipeline rows "Picture to copy" (⟳ paints a new one) and "Art check".
- **The decorator copies it:** shown it on its own millimeter grid, told its colors (`Skins.face_palette`,
  most of the surface first), told its design is a copy taken apart into what a hand lays (decorator.yaml
  `copying`), and each `look` shows the painting beside what it has laid (`DecoratorTools.reference`).
- **The paint does not carry the painting's pixels:** an element lays its own paint (skin_paint.gdshader reads
  its own maps alone), the table never reads `face_ref.png` (`Table._skin_json`, `TablePreview.PICTURES`),
  and the decorator is told its marks are the only ones laid (decorator.yaml `copying`). Each element laying
  the painting's own pixel wherever its color was near the element's paint was taken out: it showed the
  underlying PNG through transparency instead of painting textures.
- Gates: skin_step_check (the steps and their order, the controls of an episode designed before and designed
  again; the canvas, the fit and its controls, the light taken out and its control, the palette; landing,
  sending back and keeping; the prompts whole), paint_check (an element draws from its own maps alone; the
  control, the shader that read the painting).
- Not built: step 3, code taking the painting apart into elements (`Skins.separate`); the decorator traces it
  by eye for now. No real painter has painted a face end to end.

## Open

- A real episode: the producer planning `painted`, a painter or decorator making a face, a puppeteer
  blocking paint acts, readers talking over them, and the author watching it. A real run's passages, and its
  table for the new mask, are for the author to make again.
- A passage is written to the reader's own pace (`ReadingCast.said_word`: each engine's measured pace over
  its `pace`, handed to the producer in its spec: a Kokoro voice at pace 1.2 says 0.39 s a word where Piper's
  count is 0.52, so passages counted at Piper's pace came out a quarter short and the painting ran 15 minutes
  past the last word), and told what its acts take as the table will lay them: an element laid from the
  picture its shape's time times `PICTURE_SLACK` (a foundation's, `FOUNDATION_SLACK`, its goings-back held to
  it), a coat the table folds into one before nothing (`Skins.folded_coats`).
- The voice by ear: the show's voice at its pace and tone over a face being painted.
- A tool held over the face hides some of what it paints. A sponge or a dab is held up and out to the side; a
  brush drawn toward the lens leans toward it (a line half as far; a fill on its belly all the way, or its
  rows streak). If that hides too much, the other way is to draw such strokes away from the lens (a fill's
  rows all one way, lifted back between), which lengthens every fill act.
- Marks left on the towel by what is wiped on it.
- The holds are found as the table stands (3.2 s of 8.5, on a worker now): kept beside the episode by what
  they are found from, a second play would not wait for them.
- Two readings of depth near a steep nose disagree by a few millimeters; a true distance to the surface (not
  a height read across a slope) would settle it.

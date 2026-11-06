# The painted surface: a face made up, slowly

The user, 2026-11-05, of Joker Motivation (`rift/cards/joker-motivation.md`):

> we are going to produce an episode where the actor is painting a mask, or a mannequin face, or whatever. A bit like those "Get
> Ready With Me" (GRWM) videos. The person slowly and meticulously applies a foundation, and details, and eye liner, and lipstick,
> and gently smears things with a sponge... etc. The point is: this is gentle, and slow. We're in no rush. We are creating a work of
> art.
>
> And while we're doing it, we're just talking about random stuff - sort of in an off-handed way ... perhaps we also leave moments
> to breath - where nothing is being said. And what we talk about is essentially self-affirming: we are using the word "you," ...
> but the you is directed at the self.
>
> ... the core of the Joker/Clown aspect still must be here. We're always producing clown masks. At the same time, we might need
> some new primitives for stuff like: brushes, with hair dynamics, paint smears, smudges from sponges, dust from foundation, gloss
> from lipstick, etc. We're building for a female audience now, so the requirements have changed.

This note is the audit of what that show needed on 2026-11-05, the plan that followed from it, and what was built. It carries out
next/table_work.md section 11 ("The painted surface, and the makeup show"), which was designed on 2026-10-26 and never built, and
goes further: the user now wants the tools themselves to behave like real ones.

## The audit (2026-11-05)

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
| a lipstick's gloss, glitter, gold, rhinestones | **in part**: the table's materials have a gloss, glitter (`PLAYS` `glitter`) and metal - but only for a whole part, never for paint on one | |
| a smear: paint softened at its edge after it is on | **missing** | |
| the voice off-handed and kind, its "you" said to the self, for women | **missing**: the brief is the original genre's - a deep voice, "chosen one", "they" who doubted - and a male Kokoro speaker (11, Fenrir) | the brief |

Nothing about makeup or a mask may be named in the code or the rules (`rules_check` holds the rules to name no kind of work): what is
built is a PAINTED SURFACE and the TOOLS THAT PAINT it, which a cake's frosting, a sign's letters or a miniature's colors are made with
too. The brief says it is a face, and a clown's.

## The plan

Each step leaves the episodes already made playing as they did, and has a gate with a control that must fail.

1. **A mask form** - a shape of its own (`mask` in `Props.SHAPES`): a face with closed eyes and closed lips, no hair, no ears, built as a
   relief over its own front so every point of the face is one point seen from the front. It names its landmarks (the eyes, the brows,
   the nose's tip, the mouth's corners, the chin) where the face's designer can read them.
2. **A painted surface** - a part's `skin`: paint laid on it from one side (the mask's front), in millimeters across and down that side.
3. **The design** - a new step after the table, `design`, by a new agent, the DECORATOR (`rules/table/decorator.yaml`): the plan's
   `design` in words made into ELEMENTS, each a shape in the skin's millimeters (a fill, a line, dots, stones) with its paint, its
   finish and the stage it belongs to, drawn as SVG paths. It sees its design laid over the bare surface and changes it before it hands
   it in (`DecoratorTools`: `look`, `submit`).
4. **A law that paints** - `paint`: a tool (a brush, a sponge, a puff, tweezers) loaded from a pot, pressed onto the surface and moved
   over each named element as a hand moves it - a line drawn along its path, a fill swept back and forth, a base stippled from the
   middle out, dots dabbed, a stone carried from its dish and pressed on - lifting between strokes, going back to the pot when the paint
   runs low, and back where it was when the act is done. The agent says which elements, with what, from which pot; the hand finds the
   way.
5. **Paint shows where the tool has been** - every element's REVEAL MAP (when along its strokes each point of it is first covered) is
   drawn once for the acts; the schedule hands each element its start and end; the surface is composited in a small 2D viewport of its
   own from those, so a frame paints nothing on the processor and a scrub lands exactly where a play does. Finishes: matte greasepaint,
   satin, gloss, glitter, metal, pearl, powder. A `blend` softens an element's edge after it is on (the smear). A powder patted on lays a
   matte veil; patted again, its excess is swept off.
6. **Tools that behave** - a `tuft` shape (a bundle of hairs: round, flat, liner, fan, dome) whose hairs bend against the way it is
   dragged, splay when pressed and spring back with a small overshoot when lifted, and carry the color they were loaded with; a `sponge`
   material that gives where it is pressed; powder that puffs (`dust` and `mist` bursts) as it is patted and swept.
7. **Pressed, not pushed off** - the bake lets a tool through the surface it paints while it paints it (`seat_skip`), and `act` says
   what an act paints, how long each element takes and what of the design is still unpainted at the close.
8. **A show's fixed things** - a brief may carry a fenced JSON block under `## The fixed table`: things (and a light and a sound) that
   stand on every episode's table exactly as written. The set dresser starts with them on the table, builds round them, and cannot move
   or remove them; the table they hand in is given them whatever they wrote.
9. **The brief** - Joker Motivation rewritten for the user's vision: the mask and station fixed, the face designed as stages, the work a
   GRWM's pace, the voice off-handed and self-affirming, quiet stretches, always a clown.

## Status

*2026-11-05: built, gated, and looked at on the GPU with a design and acts written by hand. No real agent has designed a face or
painted one, nobody has heard a reading over it, and nothing has been exported.* Step by step:

1. **A mask form** - built. `FaceForm` (`src/table/face_form.gd`): a relief over its own front (heights on a regular grid, 0.1 cm
   apart, normals from their differences; an egg-shaped outline; a flat back and a rim), cached by size (the first build is about a
   second, the rest nothing). `landmarks()` names the closed eyes' lash lines, the lids, brows, nose, mouth, chin, cheekbones and
   temples in the designer's millimeters; `outline_path()` is the face's edge as an SVG path. Shape `mask` in `Props.SHAPES`.
2. **A painted surface** - built. A part's `skin` (`Props._sanitize_part`), recorded by `Props.build` (`skins`: its holder, meshes,
   placement and box), found by `TablePaint`; the frame is the part's own box seen from +z.
3. **The design** - built. Plan field `painted` (rules/table/producer.yaml); step `skin` (`skin.json`, after `table`, before
   `acts` - `TableEpisode.wants_skin`); the decorator (`rules/table/decorator.yaml`, `TablePrompts.decorator`, `DecoratorTools`:
   `design`, `look`, `submit`; `TableProducer._make_skin`, `_land_skin`); the language from the registries (`Skins.describe`,
   `Skins.told`). `look` is drawn on the processor (`Skins.look`: the bare surface by rays, shaded, the design by ThorVG, a grid every
   10 mm, the outline and landmarks), so it works in any run. An element mostly off the surface is said, and stops `submit` once.
   The Episode card's Pipeline row "What is painted". The step was to be called `design`: that name is the cards'.
4. **A law that paints** - built. `paint` in `Motions.LAWS` (`on`, `paint`, `from`, `rinse`, `manner`, `size`); `TablePaint`
   (`src/table/table_paint.gd`) plans an act (`plan_of`: fetch, load, rinse, move, each element's program slowed up to 1.6x, rests
   up to 4 s, back, still) and poses the tool (`pose`); `Skins.program` makes each element's way at a hand's pace (constants at its
   head). The first act (in reading order) that paints an element lays it; a later one blends it, or sweeps a powder's excess.
   Every paint act carries `_natural` and `_min_length` (0.6 of it); `Skins.act_natural` works the same out from the files for the
   readers (`TableProducer._acts_of`).
5. **Paint shows where the tool has been** - built. `Skins.cover` (Godot's own SVG renderer per element, clipped to the outline),
   `Skins.when_map` (the program stamped, a millimeter a pixel, the first touch kept, the rest filled from the nearest); two
   SubViewports a skin (`TablePaint._canvas`), an element a sprite in each with `shaders/skin_paint.gdshader`; prop.gdshader lays
   them over the part where it faces its front (`skinned`, `skin_u`, `skin_v`, `skin_side`). Stipple fills its pores in by its last
   stroke; `soft` and a blend soften by the cover's mip levels; glitter is flakes in the part's own shader.
6. **Tools that behave** - built. `tuft` (`Bristles`): hairs and a core, bent in the vertex shader (`bristle_*` uniforms) by a damped
   spring over the last 0.45 s of the tool's own way (`Bristles.response`), splayed when pressed; its tip carries the paint it last
   took up (`tip_paint`). Material `sponge` (pores; it gives - `squash`), material `cream` (paint in a pot). Bursts `powder` (each pat,
   and every 1.6 s of a sweep) and `mist`.
7. **Pressed, not pushed off** - built. `TablePhysics._painted_by` adds what a paint act lays its tool on to the body's `seat_skip`;
   `act` says what an act paints, element by element, and what no act lays yet; the parts report lists each design's elements with
   how long each takes with a brush, a sponge or a puff.
8. **A show's fixed things** - built. `FixedTable` (`src/table_show/fixed_table.gd`): a fenced JSON block under `## The fixed table`;
   `TablePrompts.brief` shows a line in its place; `SetDresserTools` starts with it and refuses to put, move or remove it;
   `TableProducer._land_table` merges it. Things and materials (and a light and a sound, if the block has them).
9. **The brief** - rewritten (`rift/cards/joker-motivation.md`): GRWM, the voice to herself, quiet a quarter of the work, six beats a
   stage each, a soft palette among the kits, no body talk; the station as its fixed table. Its frontmatter's voice is untouched:
   still Kokoro speaker 11, Fenrir, a man's.

**Found on the way: this show's camera sees only 13 to 22 cm up over the table's middle** (`CardTable.headroom_at`, 8 seeds), so a
life-size mask standing up loses its top to the frame. The mask lies back 60 degrees on a cradle, facing the lens, its top under the
frame - and a tool is held with its handle up and out to the side, never toward the lens (`TablePaint.HELD_*`).

**Seen 2026-11-05** (paint_look_probe on the brief's own fixed table, a pierrot of twelve elements and twelve acts written by hand, 1280 x
720 on the GPU): the mask reads as a face at this distance, lying back on its cradle and facing the lens whole; the sponge stipples from
the rim, the base going matte and porous; the puff pats the powder on; the liner draws each brow in clean arcs, held up and out to the side;
the round brush fills a blue diamond that follows the eye socket's curve; the flat brush lays a mouth that shines wet; the blush is soft and
softens further; gold dots, a glitter star and three stones go on last, the tweezers carrying each; every tool goes back to its place on the
tray with its last color on its tip. Fixed on the way: the paint's viewports drew only when asked, and a probe's several ticks a frame
undid the asking (they draw every frame now - before, the bare mask read as white metal); a flat tool (the puff) was held edge-on; two pots
and the towel stood off the frame's bottom edge (moved in the brief). Not looked at: the hairs bending at the table's distance, a powder's
puffs, a frame by frame clip.

Gates: `tests/table/paint_check.gd` (the mask, a design, paths, reveal maps, the hairs, and the law on a real table - the liner's tip
within a millimeter of the face while it draws, lifted between strokes, home after; the sponge on the face as it stipples; a scrub the
same as a play), `tests/table_show/skin_step_check.gd` (the step, the surfaces, the decorator's tools and landing, fixed things,
prompts). Probe: `tests/table/paint_look_probe.gd` (`--brief` takes a brief's fixed table, `--design` a skin.json).

## The details (2026-11-05, later)

The user, on the first pass: "I feel like the smear and towel and such are important details, and we're going to want them at some point.
As for the voice actor, you can just copy from the 'Secular Hazing' script for now." Built the same day:

- **A smear** - a design element of its own (`smear`: the id of an element laid before it, `line` the path its paint is dragged along,
  `width`): it takes that element's paint and finish, and is drawn as streaks side by side across its width, each thinning piece by
  piece from the paint's own strength to a fifth of it (`Skins.smear_svg`); laid in one pressed stroke at a smear's pace (manner
  `smear`), revealed from where it starts. No paint is loaded for it.
- **A rinse, then the towel** - `paint`'s `dry` names a cloth: after each rinse the tool is pressed onto it and wiped across. A brush that
  rinses is rinsed before each new color *and when its act is done*, before it is put down; trips go cup to towel to pot with no stop at
  the face between (`TablePaint._end_of`, `_trip`).
- **The water clouds** - each paint act that rinses gets a track of its own on the cup's water, law `cloud` (`TableWork._cloud_of`,
  `TablePaint.cloud_at`): a tenth of the way toward each color rinsed out, as it is swished there - a real tint entry, so the drawn cup and
  the physics' liquid both follow it, and a scrub lands where a play does. The water needs a `name`.
- **A setting spray** - a design element `mist` ("all" or a path) lays no color, only a wet sheen (roughness 0.08, a clear coat), which
  dries down to a third of it over 75 s (`skin_paint.gdshader`'s `dries`). Sprayed (manner `spray`) a few pumps across, from 12 cm off,
  out from the surface and to its right (`TablePaint.SPRAY_FROM`) - never between it and the lens - each pump a `mist` burst thrown at the face (a burst's moment now says which way
  it throws: its transform's up). The brief's station has a bottle for it.
- **Paint that runs low** - a brush's tip shows its paint thinning as it lays it (`TIP_FULL` to `TIP_LEFT` over `TIP_LASTS`), full again
  each time it goes back to the pot mid-element, gone when rinsed.
- **The powder's puffs** were never placed: the cue planner knew only its own moments. They are now (`_paint_bursts`), and gated.

The voice: the note's `voice` block is Secular Hazing's (Kokoro speaker 13, Puck, as "Ink"), and the brief's prose names no one's
pronouns, so the voice can change again freely.

## The first real run (2026-11-05, joker-motivation 856886)

The user's Generate got through the plan, the room, the table and the design - the decorator's first real face, "Amethyst
Harlequin, Cried and Mended", 27 elements: a gold crown, arched brows dotted in gold, a violet and lilac diamond band across the
closed eyes set with stones, a violet tear dragged down the cheek, gold mend lines across the right cheek, a small red mouth with
curled corners - and stopped at the acts, twice: "the puppeteer stopped without handing its work in". The puppeteer had written 21
sound acts in the design's own element names, and refused to hand them in: "the mask on this table has no design attached".

- **The design never reached the puppeteer's table.** A preview stands the table in a folder of its own and copies the episode's
  pictures into it; `skin.json` was not among them (`TablePreview.PICTURES`). So every paint act laid nothing, ran 2.8 s, and pressed
  its tool into a bare mask. Now copied - and gated by what the table reads: every file `table.gd` opens from its folder must be
  written by the preview or copied into it (skin_step_check, the control a list without the designs).
- **A paint act on a surface with no design is refused**, and why said (`TablePaint.resolve`); it had been taken, painting nothing,
  and "it paints:  - 3 s" was all the puppeteer was told.
- With the design in place, the acts' calls replayed on a copy (`tests/table/act_calls_probe.gd --full`) said what the puppeteer
  would have met next - none of it anything an act could fix:
  - **The mask's solid was a box.** `ShapeField` had no `mask` kind, so its field was a rounded 15 x 21 x 8 cm box: a brush on the face
    read 4 cm deep. It is the face now - its relief over its front, its flat back, past its outline the rim (`ShapeField._mask_d`;
    paint_check, the control the box).
  - **A painting tool was "passing through" what it paints and its pots.** Only the law's `press` thing was excused, and only 6 mm
    deep; the palette it dipped into, the cup, the towel were not, and a 5 cm sponge stippling the rim gave 7 mm onto the board under
    it. Where a painting tool goes is the law's, which the puppeteer cannot move: `TablePaint.touches` names what it paints and the
    pots, water and towel it goes to (every paint on the table, loading by color), and neither the check (`TableWork.check`: a
    painting tool's own `still` leaves them out) nor the bake (`TablePhysics._painted_by`) counts it inside them. Anything else it
    passes through is still said.
  - **The ways between places went through what stood in them.** A brush from the water cup to the palette went through the setting
    spray between them (11 cm tall) and was held back on it by 20 to 34 cm, act after act; it came to the cup through its wall, its
    water further under the rim than a trip's lift. Now what stands where the tools go is mapped once as the paint is prepared
    (`TablePaint._map_tops`, a centimeter's cells), each way finds the lift that takes the tool `CLEAR_GAP` over it, looked round the
    tip as far as the tool is wide (`_lift_over`, `_reach_of` - a fixed two centimeters stood the face lying back 3.5 cm over
    itself), and a trip comes in over a cup's rim (`RIM_CLEAR`). Read on either thread: made before the bake begins.
  - **"Looks left: 29" was read as six a watch** ("six pictures"), and the puppeteer gave up with 24 left, "only 4 more watches". A
    watch is one look of six frames, said so by the tool and the rules.
- Replayed with all of it: every act finds its elements and runs its strokes' time (761 s of painting in all; the base alone 86 s by
  sponge), nothing is held back, and the whole act call costs the puppeteer about 2.5 minutes, nearly all of it the bake.

## Watched (2026-11-05, 856886 played live)

The user, of the whole episode generated: "it keeps stalling/buffering ... the buffer on the timeline is still quite far ahead"; "it's
not clear if the sponge-application is actually applying any color/tone to the face"; and "A 9:22 estimate is a VERY fast application of
elaborate clown makeup ... closer to the range of 20 or 30 minutes".

- **The stalls were the bake thrown away a sentence at a time.** An under act's end is the word that cues the next act, a guess until it
  is heard, and a paint act lays every stroke out over its whole length - so each sentence's new guess moved every stroke from the act's
  first, and the bake went back to its start: the log said "behind the show (the show at 71.0 s, baked to 6.5 s)" at every sentence. A
  paint act begun now keeps its length (`TableWork.schedule`, as an act of fixed length always had). Played live on the plan's own word
  times said at 0.6 of their pace (`episode_bake_probe --live --script --pace=0.6`, a hand-made sidecar naming the episode): 75.4 s of
  120 waited for the bake in 14 stalls, now 4.9 s, all of it the first stretch baking.
- **The base was the mask's own color.** The brief (mine) made the bare mask "a matte, chalky off-white, like unglazed bisque", #ece6da,
  and the decorator, told so, laid a base of #f3eee5: two minutes of stippling that showed nothing. The bare face is now a warm practice
  head's skin tone (#c89e80, material `face form`), so the white going on first changes it completely; and the decorator's `design`
  says what is HARDLY SEEN - an element in nearly the color and the finish of what it is laid over (`DecoratorTools._unseen`,
  `UNSEEN`; skin_step_check), with a rule saying why. 856886's own table keeps its bisque mask: only a table set again takes the brief's.
- **The hand painted three times too fast, and was hurried to fit the words.** A liner at 16 mm/s outlined ten diamonds in a minute; the
  schedule hurried a paint act to 0.6 of its natural length to fit ten minutes of words. A careful hand now (`Skins` pace: a line 7 mm/s,
  sweeps 24, blends 16, slower dabs, pats, smears, picks, pumps; `TablePaint`'s trips longer), and A LOOK AFTER EVERY STROKE - backed off
  9 mm, 0.6 to 1.8 s, drawn by the stroke; never hurried below 0.85 (`LEAST`); and ONE HAND PAINTS ONE THING AT A TIME (`PAINT_HAND`: a
  paint act run past its beat's words had the next beat's tool start beside it). 856886's design comes to 22.5 minutes of painting
  (12.7 before). Its passages were written for the old lengths: written again, the readers are told the new ones.

## Watched again (2026-11-05, 209459, feedback 0016)

The user, of a new episode on the skin-tone mask: "This sponge is clipping right through the nose" (the screenshot, 26 s in: the sponge's
flat face square into the nose); "it also clipped through the powder case, when it got new powder"; "women generally would dab with the
corner of the sponge, not with the flat side ... the flat side to smear it and spread it, but ... the corner to dip into the container,
and to paint features"; and the stipple "looks like a pixel grid, when you would really expect it to be more like a fine dust, perhaps
simulated through transparency and blurring".

- **A tool's pose never looked at its body.** A hold was a tip on the surface and an axis, the axis a brush's (out of the surface, up
  along it and to the side, 45 degrees off the normal), and a sponge was held by the middle of its flat face at that tilt: its edge went
  into whatever rose beside its tip. `episode_bake_probe --audit` on 209459 (a sidecar made by hand): the sponge 35.7 mm in the mask's
  face at 25 s, 8.9 mm in its board, the puff 16.5 mm in the face and 4.1 mm in the powder pot. The sponge in the white pot was never
  said: its tin wall is 3 mm, a body's look is 4 mm deep - the audit now looks at a painting tool's own mesh to 0.8 mm (`_audit_paint`).
- **A sponge is held two ways** (`TablePaint._contact_for`, `Skins.FLAT_MANNERS`): flat for the manners that spread (sweep, blend) and
  onto a towel, by its corner for every other and into its paint - the corner the point of its surface toward a corner of its box, held
  through its middle. A corner lays `Skins.CORNER_WIDE` of its face's width, so a base stippled by it takes more presses (209459's base:
  131 s to 172 s). A pad (a puff) is held flat.
- **A held tool stands in nothing** (`TablePaint._cleared`, `_held_keys`, `_pot_clear`): at every key of every program, found as the
  acts are prepared, before the bake, the tool's own surface (`tool_of`'s `points`, rays straight in across each face of its box every
  5 mm) is measured against what stands over the skin seen from its front - the skin and what holds it, every 2 mm (`_obstacles`) - read
  ACROSS ITS SLOPE (read straight down it, a corner on a mask's rim or under its nose stood 9 to 17 mm in a cliff its cell straddled), as
  deep as the foam is squashed back there (`GIVE`, the whole of a pressed face, a corner's tip most). The way it points is the nearest a
  hand's that is clear, each other way tried (round the surface's normal and round the way the whole surface faces, to 60 degrees)
  costing its turn and how far it must stand back along itself (`CLEAR_TURN`): resting on its edge beside a nose beats hovering flat a
  finger over it. Where a sponge's face would stand off more than 4 mm its corner is tried (`FLAT_MOST`), and between two keys held two
  ways it is turned in the hand. In a pot, nothing of it under the rim is within 5.5 mm of the wall, pressed in as far as it gives.
  A SKIN'S EDGE IS PAST IT (`_surface_of`, `EDGE_FACING`, `EDGE_CLIFF`): a dab past the outline had gone to the foot of the shell's lip,
  6 mm behind the rim, beside the face's steep edge, and a corner could only stand off it a finger; now to the face's last forward part.
  A pressed sponge is pushed in its give and squashed back to the surface (it had been squashed off it). AND ON ITS WAY BETWEEN TWO
  PLACES (`_held_keys`' `arcs`): every key clear, a dab's 2.5 mm lift from one to the next - a 113 mm way from the chin to the middle,
  turned 70 degrees on the way - still swept the sponge 18 mm through the nose; each way between keys is posed as it will be played
  (`_surface_hold` itself, on the holds being made) every 3 mm and 4 degrees of it, and lifted in an arc 3 mm clear wherever it is not
  pressed (`ARC_CLEAR`). Two readings of depth near a steep nose disagree by a few millimeters (a cell's slope, the normal straight
  above): the slope's is held to 1.5 (`SLOPE_MOST`). paint_check `_held`: a sponge stippling by its corner and blending flat over a whole
  face, nose and all, stands no more than 3 mm in it as drawn, at its keys and between them (the control, blended with nothing held
  clear: 8 mm and more); dipped into a pot narrower than its face, nothing past the wall (the control, held flat: through it). On 209459's
  own mask, sponge and puff, every 0.05 s as drawn: the stipple 18 mm in the face at worst, now 2.6 (and one frame of 4.8, a turn of
  70 degrees between two dabs); the blend 6.6, now 1.1; the puff 15.5, now 0.2; the pots, none. THE COST: the holds are found as the
  table stands - 209459's stands in 8.5 s, from 4.9 (3.2 s of it the holds, two thirds the sponge's; the points are placed at once and
  what stands over the highest of a block is never looked at closer, `CLEAR_BLOCK`) - and the user, of it: "We shouldn't be doing work
  in the main thread, as a rule". So a table played is built on a worker, the show waiting as for its bake (`TableMedium._build_away`),
  and a puppeteer's acts are bound on one (`TablePreview._stand`): 209459's 8.5 s drew 1,237 frames meanwhile, none over 11 ms, and its
  first minute played live waited for nothing.
- **A press leaves a film, never a grain the size of the canvas's pixels** (`skin_paint.gdshader` `pressed`): the stipple had cut value
  noise at 5 px a millimeter with a hard threshold - a pixel grid. Now each press, a stipple's or a pat's, leaves a thin uneven film (half
  covered, a puff's a third) that the presses after it fill, whole by the act's end; its edge wanders as a foam's does, and fades in over
  a millimeter.

## Watched a third time (2026-11-06, 209459)

- **A reading from the top again is no scrub** (the intro set from 6 s to 9 s between a Stop and a Play: "the speaking starting DURING the
  intro sequence"): the table took it as a scrub to its first word, kept the plan made with the 6 s intro and put its clock where that
  word had been heard (6.4 s) - it ran ahead of the voice through the new intro and jumped back as the first word came. Now the table and
  its bake stand, its clock starts over and its plan takes the intro the show holds now (`TableMedium._restart`; table_work_live_check,
  the control a scrub to the first word). The voice was right all along: its stream plans again on every Play.
- **Nothing shows before its tool gets there** (feedback 0017: "a faint outline of EVERY place the sponge will place foundation ... before
  we actually place it"): a press's edge had faded in over the time its tool took to cross a millimeter of it - at the border between two
  presses still to come, tens of seconds early. Its edge wanders now, and comes as the tool does.
- **It runs dry** ("there is no way we could possibly have enough foundation to paint as much ... the application to get lighter and
  lighter ... until we are forced to pick-up more product"), AS A HAND RUNS IT DRY ("every 16 dabs is going to be strange ... because
  it's constant"; "each application might use a different amount ... you can almost always get a little bit more out of the dabs, though
  it becomes less and less"): what is on the tool is taken off a share at a time - each press its own hand (`Skins.TAKE_SPREAD`), each load
  taken up more or less full (`AMOUNT_SPREAD`) - so it never runs out, and the hand goes back for more where this load happens to stop
  (`STOP`, about the manner's dry: a stipple's a quarter, a pat's 0.3), one load in five pushed on nearly dry (`PUSH_ON`, `PUSH_STOP`).
  On a face's base: 25 loads of 11 to 29 presses. A sweep runs dry gently and evenly (`TAKE_SPREAD_SWEEP`, `STOP_SWEEP`, never pushed on,
  loaded before a long row would run it pale): no later pass fills a stripe. A line, a dot, a smear and a mist lay as much to the end and
  go back by how much they have laid, each load its own length (`LOAD_SPREAD`). What each press laid is the reveal map's second channel,
  laid by `skin_paint.gdshader`; the second stipple pass fills what the first left faint. And it takes its paint up PUSHED INTO IT (a puff
  4 mm). A base takes longer.
- AND PRESSED FLAT ON IT (209459 watched again, the user: "It touches at the very tip of a corner, and doesn't compress the sponge at all
  ... it didn't pick up enough foundation to equal the amount that is then applied to the mask"). The 8 mm it had been pushed was undone at
  its corner by the squash, which pulled its lower half back toward its middle - drawn a sponge a quarter shorter, its corner resting on the
  cream; and held balanced on that corner through its middle, a box is as wide as it can be just over it, so a 4.6 cm pot's rim (the cream
  4 mm under it) kept all but the corner out. Now a sponge dips BY ITS END (`tool_of`'s `end`: the same corner, held along its length
  toward its far end's middle - its long side steep, as a hand dips a wedge), PUSHED IN 12 mm (`LOAD_PRESS`) and DRAWN FLAT ON THE PAINT
  (prop_common.gdshaderinc `flat_on`, `TablePaint._flat_on` / `_flat_lift`: what would go under the surface lies on it, the 8 mm over it
  squeezed hardest nearest it and spread out a fifth of what it gave), DABBED two or three times as it is held there (`LOAD_EASE` between,
  never out of it, and no swirl). The pot's check is of the sponge AS DRAWN, 2 mm off the wall (`POT_WALL`), held as near upright as it fits
  with its corner moved across the mouth for it (`POT_OFFS`) before it is ever lifted. 209459's foundation: 15 degrees off upright, the corner
  11 mm off the mouth's middle, pressed 10-11 mm in at each pump. Gate: paint_check `_held`; `paint_look_probe --loads N` photographs them.

## Watched a fourth time (2026-11-06, 209459, feedback 0018-0022)

- **Sparkles off the puff (0018: "They look like stars").** A powder's puffs were smoke's billows - a disc torn at its edge - a few
  millimeters across and lit by the lamp against the dark: little bright stars. Powder is a soft round haze now, faint (`Effects.BURSTS`
  `powder`'s `torn` 0 and `thick` 0.14, effect_smoke.gdshader), the paint's puffs fewer, larger and slower to go (`TableWork`).
- **Brushes painting in the air (0019, 0021: "you can tell by the shadow it casts").** Measured with `episode_bake_probe --audit`, which now
  says a painting tool OFF what it paints while the law has it pressing (straight in along the face's front, against the surface's normal -
  along the tool, a brush meeting a steep rim at a graze read a small gap as a long one), and `--held` (each program's stand-offs and lifts,
  and where): the liner 11 mm and the flat brush 17 mm over the mask. Three causes. The lift that clears a tool on its way BETWEEN dabs had
  been found between two keys of one pressed stroke, and divided by the lift's own shape beside a key (a sweep lifted 155 mm): never along
  a pressed stroke now, and never beside a key (`ARC_ENDS`). A brush stood off its surface where every way of holding it met the brow (14 mm
  at the top of each diamond): never further than its hairs give (`BRUSH_STAND_MOST` 1.5 mm). And a place by the mask's rim is cast onto
  the surface itself wherever any corner of its cell is on it (`at_mm`; the grid's blend there had hung in front of it). The flat brush is
  within 1.9 mm now. And A BRUSH DIPS INTO ITS PAINT (`BRUSH_DIP` 3 mm; it had stopped a millimeter over it).
- **The lips missed (0020)**, and "is this how an actual makeup artist would do it? Or would they finish one eye, before moving to the next":
  the brief's work is a part at a time now (rift's joker-motivation.md, "The work"); where a feature lands is the drawing board's (below).
- **Green between the eyes (0022: "one stroke of green on one eye, and another stroke on the other eye, then back").** One element was both
  diamonds and its rows crossed both. An element's shapes apart are finished one at a time (`Skins._islands`: rows, or a stipple's passes).
- **Lines in one perfect stroke** (the user: "Nobody strokes a line perfectly all in one fell swoop"): a line's runs are cut only at sharp
  corners now and drawn in SHORT PULLS (`Skins.PULL` 6-16 mm, each its own length and pace, eased; begun `PULL_OVER` back over the last;
  lifted `PULL_LIFT` between; now and then one gone over again, `PULL_AGAIN`), a look back only where a run ends (`_pulls`).
- **The script** (the user: a story about "a dinner table and potatoes", "large gaps in the speaking ... a forced pause between two connected
  paragraphs feels wrong", and the genre's tone): the reader's silence falls only where a thought is finished, and what follows turns
  (rules/table/reader.yaml `quiet`); the brief's voice is the genre's monologue of vindication, its premise a real one, its beats an argument
  that builds (rift's joker-motivation.md). Still open: the liner 14 mm into the face once at 748 s; the sponge and the puff stood 11-26 mm off
  the mask's very rim, against its cradle's board.

## Back to the drawing board (feedback 0023, 2026-11-06 - PLANNED, nothing built)

The user, of 209459's finished face: "a rather terrible and unimpressive mask. Bad design, it doesn't look professional at all ... learn
from what we did with the LEGO brick-building mode. We might need to start with a blueprint or a plan, something with true style and
fine details. It might even be worth generating reference artwork from the painter, which we could copy from." And of its mouth (0020):
"these lips are drawn missing the actual lips".

Why it fails: the decorator draws the whole face from nothing, as SVG paths in millimeters, from a sentence of the producer's. A text model
drawing paths gets crude geometry - diamonds, a stock lip outline, an arch with two curls - flat fills and one line weight, and it places
features by numbers it is told, not by looking (the lips 6 mm above the sculpted ones). Brick by Brick's lesson (next/assembly.md): the
agent says WHAT, in the form it is good at, and code does HOW.

The plan - A PAINTING FIRST, COPIED:

1. **The reference (`image:face`).** The mask is rendered bare from its front (orthographic, the surface's own millimeters, flat even
   light), and the PAINTER paints the plan's `painted` onto that picture - image to image, so its eyes, nose and lips are the mask's own and
   every feature lands on them. An image model is good at exactly this: style, gradients, fine filigree, highlights. The art director
   looks at it as it looks at a card (`check:face`): a clown, on this face, nothing past the mask's edge, no hair, no costume, no lighting
   painted in - sent back with its faults, as a card is.
2. **Its own colors on the mask.** The paint laid is THE REFERENCE'S OWN PIXELS: each element reveals the painting where its tool has
   been (`skin_paint.gdshader` reading the reference at the surface's millimeters, the bare mask's shading divided out). Every element
   reveals the same picture, so what lies over what no longer changes the face - only when each part of it appears. The finished mask is
   the painting, detail for detail.
3. **Taken apart into work, by code.** The reference is separated into what a hand would lay (`Skins.separate`): its colors clustered
   (Lab, as many as it has paints); each color's regions traced (a fill: rows or a stipple by its size; a thin one: a line along its
   middle, in pulls; a small one: a dot); each region given to the PART of the face it is on by the mask's landmarks (an eye, the other,
   the brow, the mouth, a cheek). Code proposes the elements; nothing is drawn by hand.
4. **The decorator stages it.** Its job becomes the order and the manner: which part first, a part's outline, color, shading and
   details in turn (the brief's "a part at a time"), each element's finish (gloss on the mouth, glitter, metal), which tool, and what is
   too small to be worth a stroke. Its `look` shows the reference beside the elements laid so far.

Open questions for the user: whether the painting may carry soft shading and highlights (truer to a makeup artist's work, harder to copy
by hand) or should be told to keep to flat colors and clean lines (truer to cream paint); and whether a face may be sent back to the
painter by the decorator as well as the art director.

## Open

- A real episode: the producer planning `painted`, a decorator drawing a face, a puppeteer blocking paint acts, readers talking over
  them - and the user watching it. 856886 has been watched once (above); its passages, and its table for the new mask, are for the user
  to make again.
- The producer counts a word at `TablePrompts.SAID_WORD` (0.52 s, Proof's Piper voices); Secular Hazing's Kokoro at pace 1.2 says them
  quicker, so a passage's words cover less of its work than planned and the work runs on past them. The producer does not know the
  voice's pace.
- The voice by ear: Secular Hazing's Puck at its pace and tone over a face being painted.
- A tool held over the face hides some of what it paints - by design it is held up and out to the side; how much it hides, and how
  the hairs read at the table's distance, is for eyes.
- Marks left on the towel by what is wiped on it.
- The holds are found as the table stands (3.2 s of 209459's 8.5, on a worker now): kept beside the episode by what they are found
  from, a second play would not wait for them.
- Two readings of depth near a steep nose disagree by a few millimeters; a true distance to the surface (not a height read across a
  slope) would settle it.

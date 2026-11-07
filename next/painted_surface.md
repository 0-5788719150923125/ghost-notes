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
painted one, nobody has heard a reading over it, and nothing has been exported.* *2026-11-07: since 520084 was watched, paint is laid
only where a tool touches, and every tool - sponge, puff and brush - goes back over what it missed right after it misses it (the
sections from "Watched a fifth time" on); the user has not seen it since. 0023's redesign is built to its first stage - a face painted
first, checked and copied - and no real painter has painted one yet.* Step by step:

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

## Watched a fifth time (2026-11-06, 520084, feedback 0024-0031)

- **The brushes' shadows on their tray (0024: "heavy aliasing, and it almost feels like they aren't even casting in the right
  direction").** They were the chamberstick's, behind the tray and hidden from that view behind the water glass (switched off, they were
  gone; with the lamp off, still there) - so they fall toward the camera, rightly. The lumps: Godot draws an omni light's cube at HALF its
  atlas slot and the filter's width is counted in the slot's texels, so a candle's filter spanned a texel and a half of what it reads, and
  a low flame stretched each stair four times along the lacquer. An omni light's filter is counted in its cube's own texels now
  (`ShadowFilter.OMNI_MAP`, its normal bias with it): smooth, softer shadows. Turning the light so the paraboloids' poles point away from
  the table did next to nothing once the cube limited it - not done. table_shadow_check's controls: the old candle rings, and the new
  filter without its normal bias darkens its own cloth (wide enough, it no longer rings without it).
  WATCHED AGAIN, still wrong ("all we've done is feather/blur the edges more ... it's flickering, even though no light source is
  apparently moving"). Two causes, both Godot's omni shadow. THE FLICKER: a still flame's own flicker leaned its light 1.5 mm and the
  map's texels with it, 2.5 texels across a brush 30 cm off - a candle's light stays put in still air now (`TableLight.tick_props`; it
  leans in a draft or aboard). THE SHAPES: Godot copies the cube into the slot's paraboloids through a LINEAR sampler (copy_effects.cpp
  `copy_cubemap_to_dp`, cube_to_dp.glsl - read in Godot's source), averaging a thin caster's depth with the far tray behind it at every
  silhouette: depths in between that cast too, drawn out along a grazing light into the jagged smears. A 16384 atlas (the cube at 2048)
  kept them; `SHADOW_DUAL_PARABOLOID` turned to face down (rendered straight into the slot, no copy) drew the brushes' shadows clean - and
  failed table_shadow_check (a 40 cm plate cast nothing: a big triangle's depth is drawn wrong in a paraboloid, as Godot warns), on a
  finely cut floor too. The sponge's shadow is the spot lamp's, rendered straight into its own map. SETTLED (the user's go-ahead): A
  CANDLE'S SHADOW IS DRAWN STRAIGHT INTO ITS PARABOLOIDS, their poles up and down (`TableLight.candle_shadow`: the table about the flame at
  their rims, where they are finest; its filter counted in the slot's own texels, `ShadowFilter._cubed`), and WHAT CASTS IS CUT FINE
  ENOUGH FOR A PARABOLOID (`ShadowCasters`, render/: no edge over 1.5 cm) - by a shadow-only TWIN of its points alone, cut once a mesh, the
  mesh itself no longer casting (cutting every attribute of a scene's meshes took 7 s; its points, 0.2); a mesh that only casts (a foot's
  slab) cut in place (turned to casting nothing it was drawn - grey discs in the dishes); a sheet given a new shape as it plays (a page
  turning, a sheet bending) says `shadow_own` and casts itself. Run over the table as it is built (`TableMedium._build_episode`) and the
  desk as it is dressed. The brushes' shadows straight bands; table_shadow_check: a 6 mm rod 30 cm from the flame, its edge 3.1 px off a
  line where the cube's strays 7.0 (control), the plate's shadow there again, no rings, the cloth whole.
- **Ridges along the chin and the side (0025: "like we stretched a plastic mask over the mannequin").** The face's grid was cut where the
  outline crossed it, its outside points moved in onto the rim; the face falls to the rim ever more steeply, so the last point inside
  stood 1-5 mm high as the rows met the outline - a sawtooth all round, plainest where the outline runs along the grid. Every grid point is
  kept now and its outer band PULLED IN along its way from the middle (`FaceForm._pulled_in`): its edge on the rim, its rows running into
  it, the grid untouched inside `PULL_FROM` (0.72 of the way out, past every feature). A grid pushed out in copies of the outline whole was
  tried first and drew the mouth's line in stairs (it crossed it aslant). It showed a fault under it: the surface's grid of where it faces
  (`TablePaint._surface_of`) took each normal from the one facet its ray landed on - and its rays land on the face's own points, a vertex
  six facets share - so a mesh 1.5 microns narrower turned its normals by up to 30 degrees at the nose's tip and 83 at the rim, and a sponge
  laid flat on the nose stood 6.7 mm in it (paint_check). It faces as its surface SLOPES now, from the points either side.
- **Powder that twirls (0026: "Real life dust wouldn't make much of any effect, at all ... more like a cloud ... billowing and falling").**
  Every burst wanders on a sine and cosine whose size grows with its age - circles opening out, smoke's. Powder wanders not at all, sinks,
  and is one faint cloud of many soft puffs over each other (`Effects.BURSTS` `powder`, `TableWork`'s paint dust) - and rises only off the
  puff's first press after it took up its powder (`Skins._Prog.dab`: `pats` at a load's first press), none off a sweep.
- **The puff slid and tapped (0027: "would they rapidly tap it over and over, gently?").** A pat is quick and light now - about two a second,
  lifted 4 mm (`Skins.PAT`, `PAT_LIFT`) - and a puff's second pass (a powder's excess taken off) PRESSES again where it lies, never slides
  (`Skins.blend_manner`, manner `press`): a brush and a sponge's flat face still blend by strokes (the user, 2026-11-05: the flat side "to
  smear it and spread it").
- **Hairs that stretch and contract (0030), and a liner over its line (0029).** The hairs' bend had a part ALONG them: pressed, they folded
  the way the handle leans out of the surface - drawn up into it, the tip 6 mm off the face it painted - and lifted off, the brush's motion
  away from the face pulled them out after it. A bend is across the hairs alone now (`Bristles.target`): dragged, back against the way the
  tip goes across them; pressed, along the surface the way the tip goes (away from where the handle leans over it - a skin hold carries
  the surface's normal, its eighth entry). And bent, a hair is AN ARC OF A CIRCLE as long as it was (`Bristles.bent_at`, the shader's same
  arithmetic; the old bend grew a hair 2-8%). Gate: paint_check `_hairs`.

- **The sponge painting far past its corner (0032: "barely touching the mask with a corner - yet the entire area around it splatters
  with paint ... It would be even better if we truly only painted what was touched").** A reveal map gave every point the moment of
  the NEAREST place the program reached (`Skins.when_map`: stamps, then the rest filled from the nearest), so each dab showed all of the
  face nearest it, and a dab was a disc three quarters of the sponge across. WHAT A PRESSING TOOL TOUCHES IS WHAT IT PAINTS now - the
  first of the plan below, for the sponge's stipple and the puff's pats (`TablePaint.TOUCHED`): its surface found every millimeter
  (`tool_of`'s `touch`), held at each press as it is drawn (`_surface_hold`, its corner pushed in as far as it gives), and every bit of it
  within 0.6 mm of the face or in it stamped (`_touched`, `Skins.touch_map`); a point no press touched is never shown (`Skins.NEVER`). It
  lays as wide as it touches (`_touch_width`: 520084's sponge corner 15 mm, its puff 18 - whatever width its track says, 32), a load
  covers an area of the face (`Skins.LOAD_AREA_DABS`, `_PATS`), and a sponge bounces quicker (`Skins.DAB`). Left bare: where the corner
  never touched (beside the nose, where it cannot press without meeting it) - still to come, a hand going back over what it missed, and a
  blend spreading paint where it touches. Gate: paint_check (the first press shows about what its corner touches; control: shown by its
  program alone, every point shows).
- **Dabbing the rim with gaps at the nose (0034: "a real artist would probably try to fill-in empty spots, before they move to completely
  new areas").** A stipple was two passes, each out from the middle to the rim, the second filling what the first left - minutes later.
  Its presses are one now, round and round out from the middle, every press within a ring before the next (`Skins._grown`). Gate:
  paint_check (no press comes back more than three inside where it has been; control: two passes one after the other, seven). Still bare
  after it: spots on the nose's own ridge and sides, which the sponge's corner cannot press without its body meeting the nose.
- (0033, the dispatch desk's roots, is the dispatch desk's - another session was in the middle of it, its dispatch.gd not compiling.)
- **Still huge gaps (0035: "Do we need some kind of detection mechanism, such that the dabs are not just pre-planned actions, but
  actually made in response to the gaps in coverage? Like a self-correcting mechanism").** Yes: A HAND GOES BACK OVER WHAT IT MISSED
  (`TablePaint._cover_gaps`), as the table stands, before any act's length is known: the presses planned (`Skins.press_places`), held as
  they will be drawn, WHAT THEY TOUCHED looked at (`_gaps_left`), and every gap of 2 mm2 or more given presses of its own - as many as it is
  large, spread over it - each put in right after the press nearest it (put right while the hand is there), AIMED SO WHAT IT TOUCHES LANDS
  ON IT (a corner touches to one side of where it is aimed), pressed harder after the first look (`PRESS_HARD`); five looks
  (`GAP_ROUNDS`). What it found under the gaps: the touch test read a rim's wall as the board beside it (`TOUCH_STEEP`; a band all round
  the rim) and skipped a cell part off the surface; and the puff was STIFF - a 45 mm flat face held 5-23 mm off a curved face, painting
  almost nothing - so a pad gives now (`PAD_GIVE` 8 mm), is drawn squashed as a sponge is, and tips onto its edge where its face cannot
  reach (`tool_of`'s pad `corner`). 520084, bare at each look (mm2): the stipple 238, 148, 77, 58, 52, 52 (502 presses); the pats 3536,
  2440, 1411, 1245, 598, 175. What is left is what the tool cannot reach (beside the nose). Found once and kept by what it was found from
  (`_clear_memo`, `_arc_memo`, `_touch_memo`): the table stands in about the time it did before. Gate: paint_check (what the stipple left
  bare put right; control, the first look). AND PUT RIGHT AS SOON AS IT IS SEEN (the user: "a second pass is too late ... They would fix
  the gaps soon after they first see them"): a gap's presses go in right after the press that last laid paint round it (`_gaps_left`'s
  `closed`) - after the press it was nearest, some had waited a minute; 520084's holes are pressed half a second after paint closes round
  them (the slowest, single-pixel seams between two rings, which the next ring lays). Gate: paint_check (of the holes paint closed round,
  most pressed within 5 s; control: two passes one after the other).
- **Flecks on the nose (0039: "Look at all the huge gaps in paint on the nose ... wouldn't it be possible to just treat this like a
  transparency map ... where our job is to fill all the gaps in it everywhere?").** It is one: the reveal is the face's own flat map, and
  the loop looks for every gap in it. What was left were holes under 2 mm2 the loop let be, and slivers a millimeter wide beside the nose's
  steep sides (wide where the side is steep) - grown by a press's ragged edge (1.6 mm) into orange flecks and lines. CREAM SPREADS UNDER
  THE FOAM: a point all but closed in by what is laid round it (5 of its 8 neighbours) is laid as its last neighbour is, twice
  (`Skins.closed_in`, in the reveal map and in the loop's look alike); the loop chases gaps down to 1 mm2 (`GAP_LEAST`); a press put in
  where the first missed may be held by the sponge's long end, along its length, where that reaches nearer (`WAYS`). 520084: no hole the
  paint closes round is left bare; what is left is 49 mm2 along the rim.

- **Brushes paint where their hairs touch (0028, 0031; the user: "Continue on the brushes").** A brush laying a fill or blending is held
  LOW, by the side of its hairs (`belly`: `HELD_LOW`, about 30 degrees off the face) and pressed deeper (`BELLY_PUSH`, a fifth of its
  hairs); every key knows the way its stroke goes (`_dirs_of`, the hold's ninth entry), and A FLAT BRUSH IS TURNED TO IT - broadside across
  a fill, on its edge along a line, whichever way round is nearer so it never turns over (`_node_at`, a tuft's `across`). ITS HAIRS PAINT
  WHAT OF THEM TOUCHES (`tool_of`'s hair points, the lower two thirds, bent in `_touched` by the shader's own arc; each stroke looked at
  every half millimeter; `BRUSH_TOUCHED`), on a map four pixels a millimeter (`BRUSH_PX` - at a sponge's one, a liner's line was drawn in
  steps). And a pressed brush's hairs BEND NO FURTHER THAN KEEPS THEIR TIP ON THE FACE (`_bend_to_surface`, the shader's and the touch
  test's alike): a fold of a fifth of their length, tilted with the brush, had carried a liner's tip 2.5 mm up off the face, and it painted
  nothing. 520084, bare of each element: the outline 16% (a liner pressed lightly touches a band narrower than the line drawn), the
  diamond's fill 0%, its foot 1%, the lips 10%, the haze 1%.
- **A brush goes back over what it missed too** (`_brush_gaps`, as the sponge does): each line and fill's strokes looked at as they will
  be drawn (`_stroke_touches`), every gap of a square millimeter or more given a dab right after the planned stroke that last laid paint
  round it (`Skins.program`'s `inserts`), five looks, the dabs after the first pressed harder, and no further once a hard look puts
  little more right. What the looks found under it, each a class of fault, not one place:
  - THE FOREHEAD AND BROWS WERE NEVER PAINTED (the halo, the big star, the facets, both brows: 100% bare). The bend that keeps a tip on the
    face read how far over it the tip stood along the mask's own depth, and moved it that far along the face's normal; where the face
    slopes back from that depth (a forehead), a tip 4.7 mm deep by depth was under 2 mm by the normal, and was lifted clear. It is counted
    along the depth now.
  - A LOWER LIP'S OUTLINE WAS DRAWN UP ON THE LIP (2-8 mm off the line it was aimed at). On the steep underside the face was read as high
    as its cell's highest corner (right for counting a touch at a wall's foot, wrong for putting a tip on it), and the bend stepped to by
    the slope alone went over the edge and came back 8 mm. The face is read between the cells for it, and the bend is the least either
    way that brings the tip onto the face - found in growing steps, then halved (`TIP_STEP`, `TIP_HALVES`) - and no more than twice what a
    flat face would ask (`TIP_REACH`): a brush held near upright in the crease between the lips had slid its tip 4 mm up the lower one to
    find the face, where its hairs would spread.
  - A DAB AIMED AT WHAT A FILL MISSED UNDER A LIP'S BULGE TOUCHED THE BULGE AGAIN. Each dab is tried before it is laid (`_dab_miss`): at
    the gap, and off by as much as the hairs aimed nearest it touched off their aim where they missed it - whichever lands nearer. Aimed off
    always, a wide fill brush (which touches all round its aim) missed the forehead's stars.
  520084, bare after the looks (mm2): the stars, brows, horizon, wave crests, cracks, grin and the lip's shine 0; the outlines 1-3; the lip
  line 2.9 (8.7 at the first look, 24.5 before the tip was put on the face); the lips' fill 4.6; the seam between the lips 16.5 (the
  middle of the crease); the frost 4-10. The table stands in about 33 s (the looks were 48 s until the gap finders read a picture's cover
  once instead of a point at a time, and closed it in only inside it; the stipple keeps what its last look touched for its reveal).
  Gate: paint_check (a liner pressed all over a face, its bent tip on it at 165 of 165 places - the control, bent along the normal, 75;
  the brow's gaps put right - the control, the first look). Open: the crease between the lips (16.5 mm2, under the lips' red and
  not seen in a render), and the frost's fan brush on the cheeks.
- **A ragged bare band along the rim (seen in 520084's render, 2026-11-07; the user asked whether a sponge pressed harder would curve
  round the edge).** Not the sponge: its touch map reached the edge everywhere but a hairline (49 mm2), and the face falls steeply enough
  to fade the skin's paint (prop.gdshader, the normal 0.02-0.25 of the front) only in its last millimeter. A PRESS'S RAGGED EDGE READ
  PAST THE FACE: skin_paint.gdshader reads a pressed element's reveal map up to 1.6 mm off each point (`RAGGED`) while its cover is read
  where it is, and past the outline no tool touched - so paint laid to the rim did not show, in a band as wide as the read wanders. The
  edge's moment is carried out past what the element covers as far as that (`Skins.touch_map`'s spread, `PRESS_RAGGED`), where nothing
  ever shows. Gate: paint_check (two points past the stipple's edge, 517 of 521 hold a moment; the control, the same touches with nothing
  carried out, 46 of 523).

## Painted where the tool touches (feedback 0028, 0031, 0032, 2026-11-06 - BUILT for presses and brushes)

The user: "do makeup artists really paint with the tip of the brush like this? ... You don't paint with the tip of the bristles, you
paint with the side of them, back and forth, and in many directions" (0028); "the whole brush is touching the eye, but paint is only
coming out from one side of that brush. There are also all of the ways a person can turn a brush, to the fat side for wide strokes, to the
corner for fine strokes ... we really want to focus on proper physics, where lines, paint, foundations and otherwise are applied
accurately, relative to the tool that applied them" (0031).

Why: a program says where the TIP goes, and paint is laid as a disc of the tool's width round that path (`Skins.when_map`); the tool is
then posed to put its unbent tip there, held as a hand holds a pen. So paint and tool agree only at one point, a flat brush lays the same
disc whichever way it is turned, and nothing ever lays the hairs' side on the face.

The plan - THE TOOL'S CONTACT IS THE PAINT:

1. **A tool's contact patch**, from its pose and its hairs' bend (the shader's own arithmetic, `Bristles.bent_at`): the part of the bent
   hairs within a fraction of a millimeter of the surface - the belly of a pressed round brush, the chisel of a flat one across its width
   or along its edge as it is turned, the tip of a liner held up; a sponge's corner or face; a puff's disc.
2. **Programs move the patch, not the tip**: a fill swept with the belly, the handle low (25-35 degrees to the surface), back and forth in
   changing directions, a flat brush broadside for cover and on its edge to cut a border; a blend buffed in small circles and wiper strokes;
   a line pulled with the tip, the handle higher; a puff pressed and rolled.
3. **The pose is found from the patch**: where the hand must hold the tool so its bent hairs lie where the program puts the patch - never
   floating, never stretched.
4. **Paint is laid where the patch has been**, each moment's patch stamped along its real path (the reveal map from the posed tool, not
   from the program's line). Accurate by construction: the paint is where the tool was.
5. **With the drawing board (below)**: the patch reveals the reference painting's own pixels.

## Back to the drawing board (feedback 0023, 2026-11-06 - FIRST STAGE BUILT 2026-11-07; no real painting made yet)

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
painter by the decorator as well as the art director. Taken for now, until the user says otherwise: flat colors with clean edges, a
highlight as a shape of its own, soft only where a sponge softens an edge (what takes apart cleanly); the art director alone sends it
back, as with a card.

**Built (2026-11-07), steps 1, 2 and 4 in a first form; step 3 not:**

- **The face painted first (`image:face`, then `check:face`)**, between the table and the design, on a show whose plan paints
  (`TableEpisode.wants_face`: an episode designed before goes on as it was made; designed again, it starts from one). The table's first
  surface is shown bare from its front, lit evenly from the front, on black, three pixels a millimeter, in the middle of an upright 2:3
  canvas (`Skins.face_canvas`, kept as `face_bare.png` with where it lies, `face.json`); the painter paints the plan's `painted` onto it
  (rules/table/painter.yaml `face`: in its own frame, only paint, a hand's paint), and a painting that does not lie on the surface - its
  box off the surface's by more than 5% of the canvas, or past its edge - is removed and painted again (`Skins.face_fit`). What is kept
  is cut back to the surface's millimeters with the bare light taken out (`face_ref.png`, `Skins.face_reference`). The art director
  looks at it beside the bare surface (art_director.yaml `face`) and keeps it or sends it back with its faults (`sent_back_face.json`),
  as with a card. Pipeline rows "Picture to copy" (⟳ paints a new one) and "Art check".
- **The decorator copies it**: shown it on its own millimeter grid, told its colors (`Skins.face_palette`, most of the surface first),
  told its design is a copy taken apart into what a hand lays (decorator.yaml `copying`), and each `look` shows the painting beside
  what it has laid (`DecoratorTools.reference`).
- **The paint carries it**: where the painting's color is near an element's paint, the element lays the painting's own pixel - its
  shading, highlights and fine marks - and its own paint elsewhere (`skin_paint.gdshader` `reference`, `rect_uv`, `REFERENCE_NEAR`), so
  a base over the whole surface is white under what goes on later and the finished surface takes the painting's detail. The table reads
  `face_ref.png` and `face.json` with `skin.json`, and a preview copies them (`TablePreview.PICTURES`).
- Gates: skin_step_check (the steps and their order, the controls of an episode designed before and designed again; the canvas, the fit
  and its controls, the light taken out and its control, the palette; landing, sending back and keeping; the prompts whole), paint_check
  (each element laid with the painting and where its picture lies; the control, a design with none). Rendered once by hand under xvfb:
  over the painting's near-white the paint lays the painting's, over its red its own.
- Not built: step 3, code taking the painting apart into elements (`Skins.separate`) - the decorator traces it by eye for now. And no
  real painter has painted a face: the first one is for the user to see.

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

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
sections from "Watched a fifth time" on), and a brush is pulled through its strokes, its hairs bent over as it leans ("Pulled
through, bent over"); the user has not seen it since. 0023's redesign is built to its first stage - a face painted
first, checked and copied - and no real painter has painted one yet. Later the same day: a pressed pad takes the skin's shape, hairs
are stiff, a brush's paint is where its hairs touched and a fill keeps inside its shape, a blend softens where its brush went ("What
touches is what is laid").* Step by step:

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
frame - and a tool is held with its handle up and out to the side, never toward the lens (`TablePaint.HELD_*`) - but a brush drawn along a
stroke leans the way it goes ("Pulled through", below).

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
  the face between (`TablePaint._end_of`, `_trip`). A SPONGE IS RINSED AS A HAND RINSES ONE (feedback 0050, 2026-11-07: "we're dipping
  the entire sponge into the water, but not ringing it out over the cup ... holding it in the water for longer, so that it can actually
  soak up some of the liquid, for us to ring out? Then, when we press it against the board ... push harder, and more than just one quick
  press"): lowered in and squeezed three times as it soaks, lifted over the cup and wrung out hard twice, then blotted on the towel in
  three firm presses, each held and each on a fresh place (`TablePaint._sponge_trip`; 8 s and 4.6 s where a brush's are 4 and 2.6). Not
  built: the drops running off it as it is wrung (a look of falling drops is not among `Effects`').
- **The water clouds** - each paint act that rinses gets a track of its own on the cup's water, law `cloud` (`TableWork._cloud_of`,
  `TablePaint.cloud_at`) - a real tint entry, so the drawn cup and the physics' liquid both follow it, and a scrub lands where a play does.
  The water needs a `name`. It had gone a tenth of the way toward each color rinsed out, a liner's rinse as much as a sponge's, and was
  drawn as opaque as a brew; the user (2026-11-07): "the water starts opaque white. Perhaps it should start clear, and inherit colors
  based upon the volume coming off of brushes and sponges ... it would accumulate color over time, not immediately." Now BY VOLUME: a
  rinse carries out a sponge's face of paint 0.5 mm deep or a brush's belly (a twentieth of its hairs' bulk; `TablePaint.rinsed_ml`),
  and that share of the cup's water (`TableWork._water_ml`, the vessel's as drawn) turns its color toward the paint and clouds it
  (`TablePaint.clouded`): in a glass a sponge's rinse clouds it about a tenth, ten of them most of the way, a liner's hardly at all. A
  liquid as clear as 0.5 is drawn SEEN THROUGH (`prop_liquid_clear.gdshader`, the opaque liquid's body with `CLEAR`; under its glass),
  less as its `murk` - the rest of the cloud's alpha - builds up.
- **A base reaches the edges** (feedback 0050: "We missed a spot of the white layering at the right side of the chin here, and a little
  at the bottom and left"): no spot was missed - 257002's second base covered its shape whole (19 mm² bare at the first look, none
  after the hand went back), but the decorator had drawn that shape short of the chin on the right ("left thinner at the right temple
  and jaw"), so the first base's tan showed past its soft edge. The decorator is told a base covers all of what it is the base of, and
  anything thinner or darker toward an edge is an element of its own over it (decorator.yaml). 257002's design stays as it was made.
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
- **The chin's underside (the user: "One way or another, we have to cover that chin area. If more pressure can do it, great. If not -
  just dab in that area, and paint it anyway").** What was left was the sponge's own: not the board (past the chin it lies 6 mm behind
  the face, no V), but the chin's last millimeters falling away under it - the corner, come from above, sank 5.5 mm into the chin's slope
  8 mm up from where it was aimed and stood 1.4-6.5 mm off the underside. Pressed harder it reached only at five times its press (15 mm
  squashed); by its long end, never; FLAT, at its own press. So A PRESS PUT IN WHERE THE FIRST MISSED IS HELD THE WAY THAT REACHES IT,
  looked at before it is laid: where its own way misses where it is aimed by more than a millimeter, each other way the tool has (its
  corner, its long end, its face - `WAYS`) is tried, and the one that touches nearest taken (`_press_miss`, `REACH_BETTER`; the long end's
  old test of its cost alone is one of them). Only where the own way misses: a puff's face that touches where it is aimed covers more of a
  gap than its corner, and turned whenever its corner was nearer the pats ended twice as bare. And WHAT NO TOOL REACHED IS PAINTED ALL THE
  SAME (`_painted_anyway`, sponge, puff and brush): every point the last look found bare laid when the touch aimed nearest it comes down.
  520084: the stipple bare at each look 213, 130, 0 mm2 (499 presses; it had stopped at 49 after five looks), the pats 3464 ... 30 (189),
  the table standing in 27 s. Gate: paint_check (every put-in press held another way is one its corner missed and the other reaches
  nearer, 43 of 43; the control, no press of the plan is held but by its corner, of 754; what was left bare laid with the touch nearest
  each point; the control, nothing added with nothing bare). This bends the user's "dab with the corner of the sponge, not with the flat
  side" only where the corner cannot reach.

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

## Pulled through, bent over (2026-11-07 - BUILT; looked at on 520084's frames, not yet watched by the user)

The user: "The paint brushes are weird, because they are always at the same angle, no matter which direction we're stroking in ... I
think a real artist would turn the brush, to pull THROUGH the stroke at the same angle"; the fat brush "has a weird ring of <powder
stuff> around it, when the brush is compressed ... you would expect that ring to fan-out into the moving/compressing/splayed bristles,
not stay there, ABOVE the moving bristles"; and "the fat brush sort of balloons into a mushroom shape ... I think they would usually lean
the brush slightly, such that the bristles bend more than they balloon".

- **Pulled through** (`TablePaint.HELD_PULL`, `_pulls_of`): a brush pressed along a stroke leans its handle the way it goes, at one angle
  to the stroke, so its hairs trail; lifted, it is turned as it went, or as it will go, so it comes down already turned. Back and forth
  along a fill's rows the wrist rocks it over between them (the keys' axes slerp through upright), never turned round. A dab goes
  nowhere and is held as before. Toward the lens a line stands up half as far (`PULL_TOWARD`); a fill on its belly does not - stood up,
  a flat brush laid half its belly (82 hair points against 174) and streaked between its rows. Found on the way: held the old way, the
  flat brush's pressed belly lay 6-11 mm off to one side of where it was aimed; pulled, it is centered.
- **The core stays under the hairs** (`Bristles._core`, `CORE_*`, `core_at`): the ring was the tuft's core - a solid body that stands
  for the inner hairs and takes the paint. On a dome brush it was as tall as the middle hairs, 38% taller than the outer ones, so over
  their ends it WAS the brush's surface: a solid band of paint. It is now no taller than the outer hairs, takes 45% of the paint, and
  pressed it draws in and down under them (the shader and `_touched` the same arithmetic; it is told by its UV's x).
- **Leaned, the hairs bend** (`Bristles.SPLAY_LEAN`, `SPLAY_LEANED`): the splay was a fixed share of the press however the brush was
  held. It is now all of it straight down and a quarter of it leaned 30 degrees or more; the bend that keeps the tip on the face
  (`_bend_to_surface`) takes up the press.

On 520084 (`--script --pace=0.6`, the probe's look at each element): the go-back loop has less to put right almost everywhere - first
looks sea-outline 68 -> 37 mm2, ember-outline 57 -> 16, brow-right 25 -> 0, star-halo 216 -> 9, star-big 56 -> 0, lip-fill 38 -> 1.4;
the slate fill leaves nothing it never paints (85 px -> 0), with a few specks between rows for up to 5-9 s before the next look; the
frost glitter ends at 16 mm2 bare (was 10). The table stands in 32 s (30). Gate: paint_check (the eight ways and the brow's keys, the keys'
ways, the core under the outer hairs, the lean's splay, and the go-back loop on a band wider than the liner - the brow itself is left
with nothing to put right).

## What touches is what is laid (feedback 0041-0048, 2026-11-07 - BUILT; looked at on 520084's frames, not yet watched by the user)

The user, watching 520084 again: the puff "is clipping through the nose ... always perfectly flat: it never seems to bend or compress
... pads like this are very soft and should be easy to bend" (0041); the liner's hairs "curl into a tight arc ... Bristles aren't
floppy" (a comment); a fill's rows "pull through the black line and onto the outside of the diamond", its paint inside the diamond
alone, "when the brush is touching the mask the entire time ... we are going to need really accurate paint-application physics ...
smearing, and streaking, and cracking" (0042); the diamonds' "rough edges" that a precise artist "would go back and clean-up" (0043);
the lips "fainter at the top, while smearing outside the lines at the bottom" once blended (0046).

- **A pressed pad or sponge takes the skin's shape** (`TablePaint.press_lands`, `_press_of`, `_press_point`, `_press_on`,
  `_press_field`, `pressed_drawn`; prop_common.gdshaderinc's `press_`): it had been squashed back along its press as a share of its
  depth, so its face stayed flat and stood 3.5 mm in a flat forehead, more in a nose. Each bit of it is now drawn from the skin's heights
  read every millimeter (`PRESS_CELL`; every 2 mm, a nose's ridge between the reads stood 2.7 mm through a sponge): what would go in it
  lies on it, a pad's face sags into a hollow beside what it is pressed onto (`PRESS_SAG` of what it gives; a sponge's denser foam does
  not), and its back keeps `PRESS_THIN` of its depth over the skin, so pushed past that the whole of it bends away. A pad's `_touched` is
  the same arithmetic, so what is drawn touching is what paints; a sponge's keeps the reading its stipple's go-back loop was tuned to
  (read as a pad's, its base left 911 mm2 bare at the first look where it had left 213, and 29 never painted on the nose's steep
  sides, the bare mask showing there brown). In the gate: a puff patting a whole face is drawn 0.1 mm in it at most (held, 16 mm), and
  pressed its hardest six times as much of its face lies on the face as held flat; a sponge 0 mm where it stood 2.7.
- **Hairs are stiff** (`Bristles.SPRING_HZ` 9, `SPRING_DAMPING` 0.75, `DRAG_BEND` 0.2): they had followed a 3.6 Hz spring damped 0.38,
  swinging past straight by a quarter of their bend at every stroke's end, bent a third as far moved through the air as dragged, and
  dragged curled 0.42 of their length aside. Now nothing in the air bends them, a drag on the face bends them half as far, and let go
  they are back within a tenth of a second, past straight by 2%.
- **A brush's paint is where its hairs touched** (`Skins.touch_map`'s `foot_out`, skin_paint.gdshader's `foot`): the element's own
  shape had cut the paint off, so whatever ran past it never showed. Now what its hairs touched is the paint, reaching past the shape as
  far as the tool is wide - SMOOTHED AS PAINT SPREADS (`Skins.FOOT_SOFT`, `FOOT_HALF`, `_blurred`): each bit of a hair stamped on its
  own, a stray one beside a liner's line stood out of it as a bead, so the touches are shrunk to a point a millimeter and grown back,
  and laid where that is half whole - a lone bit fades, a pinhole closes, a millimeter's line stays whole.
- **So a fill keeps inside its shape** (`Skins.CUT_IN`, `sweep_paths`, `_cut_in`, `_eroded`; `TablePaint._keep_inside`, `_ease_off`,
  `SPILL_*`): it goes once round inside each outline, half its brush's width in, the side of the hairs along the edge, and rows back
  and forth over what is as far inside; then each stroke is looked at as it will be drawn and, wherever a bit of its hairs touches more
  than half a millimeter past the shape (two bits at a moment let by, a lip's fill laid 24 mm2 past it along its top), EASED OFF - pressed half as hard there, down to a quarter, as a hand lightens near an edge - and cut back
  only where it still runs past that lightly, up to six looks. A dab put in for a gap that would run past a fill or a line is left out -
  laid where they touch, dabs along a line's bare edge would stand out of it as blobs (0043). On 520084 (`--script --pace=0.6`, the
  probe's look at each element): the slate fill 0.1 mm2 past its shape and 0.1 of it bare, the ember fill 0.4 and 0.1, the lips 0.4 and
  0.1, the big star 2.0 and 0, its facets (the liner) 1.6 and 0.1; the slate outline 0 and 0.1 (unsmoothed, 16 of it bare in pinholes
  and beads). Cut back without easing first, the facets had run 65 mm2 past. Paint hugging an edge under a millimeter out reads as past
  it here - the slate foot 15.9, the frost over the slate diamond 24.9, both under the black outline. A FILL TOO FINE FOR ITS BRUSH, nothing of it left
  that keeps inside even eased off (five small stars 7 mm across, under the round brush), is laid as planned and cut to its shape as it
  always was: a hand would take a finer brush, or pull each point out with the tip, and neither is built.
- **A blend softens where the blending brush went** (`TablePaint._blend_touches`, skin_paint.gdshader's `blend_map`; `Skins.BLEND_SHARE`,
  `inner_reach`): every edge of an element had softened at once by 4 mm wherever the brush went, an upper lip 8 mm deep through and
  through. Now a point softens as the brush's hairs reach it, and a fill no further than a third of the way to its middle.

Not changed: 0044's orange streak down the right cheek is the design's own (`ember-tail`, "the ember diamond's lower point is dragged
down the right cheek with the sponge's edge into a streaked tail") - that it read as a mistake is a mark against the design, not the
hand. The lips' black outline stays (0047: "warranted, because we're also doing those curly parts"). 0048 - "extremely ugly ... we
didn't go into this mask with a proper blueprint/plan ... generating some kind of reference picture with the AI painters, then
'copying' from that style" - is the redesign below, built to its first stage: 520084 was designed before it, and goes on as it was
made until its design is made again.

Open: a fill too fine for its brush laid as a hand lays it (a finer brush, or each point pulled out with the tip); a TOUCH-UP for what does go wrong (0044: "We probably should be able to touch-up places where we've made a mistake") - paint past
a shape looked at once laid and taken off with a clean damp brush or the base laid back over it; a design's HAND, precise or loose (0043:
"very precise ones, with clean lines, or Joker-style masks, with smearing and bleeding"), the decorator's to say and the spill allowed
by it; a line as wide as the liner's touch, which may be narrower than the line drawn (measured on 520084 below).

## The hand at the cup, and the brush that does the work (feedback 0050-0057, 2026-11-07, on 257002)

- **A sponge squeezed in the hand** (0050, then: "The sponge stretches and retracts the long way ... The sponge should compress first,
  then expand back to where it started ... most people would squish on the wider edge, the fatter edge - not lengthwise"): rinsing, it is
  squeezed across its broad faces, both in about its middle and back out to its own shape (`TablePaint._squeeze_of`, prop_common's
  `squeeze`, at most half as thick); pressed on the towel or into its paint it still gives from the side pressed.
- **A base reaches the edges** (0051: "We missed that white spot in the exact same spots on the chin, again ... Our coverage is
  incomplete"): told to the decorator was not enough for a design already made. The fills a design opens on that each cover 60% of their
  surface are laid over all of it (`Skins._based`, in `sanitize` wherever the outline is known), and the decorator is told so.
- **A brush pressed past its point** (0052: "Why are we painting with the very tip of it? There is something like a needlepoint's worth of
  brush actually touching ... We need to push a little BEYOND that tip, such that it is FORCED to bend"): its tip gives as far as its belly
  (`TablePaint.TIP_PUSH`, a fifth of its hairs), and a line presses it as far as the share of the brush it is wide (`Skins.program`,
  `LINE_PRESS_LEAST` 0.15) - it had been 0.6 mm whatever the line, and bent from being dragged alone. Any press counts as pressed now
  (`TablePaint.PRESSED`): over half had, and a fine line would have gone unpulled and lifted.
- **A brush worked into its paint, and its hairs wet** (2026-11-07: "the brush doesn't really move at all when it's dipped into the
  container ... the bristle do not apparently pick up any color"; 0053: the liner's rust did show): swirled round twice out to 4 mm and drawn
  across as it comes up (`TablePaint._brush_load`); the paint on its tip over the end half of its hairs, glossy, and half of it left
  until it is rinsed (prop.gdshader, `TIP_LEFT`).
- **Pulled, never pushed** (0054, 0056: "It feels like it is pushing against the direction of the stroke ... far more common to pull-through
  the strokes"): every way of a fill, a line's pulls and an outline cut where it turns against how the hand leans the brush there and each
  piece drawn toward the handle, lifted back between (`Skins._pulled_ways`, `pull_toward`) - rows had gone back and forth and the handle
  could not lean toward a nose. Slower too: a fill's rows 14 mm/s (24), its edge 10.
- **A fill too fine for its brush drawn along its middle** (0055: "it touched the area once, and the entire brow just appeared"): its spine
  followed in pulls at a line's pace, each point pressed as far as the shape is thick there (`Skins._spine`).
- **A design's colors are the table's paints** (0057: "It's not clear how that would have happened, when the brush only has one color";
  0059: "this brush went from painting a watery, diffuse black band above the eye, to a tiny, fine, thick black line under the eye. The
  physics aren't making sense"; the user chose "pot paint, thinned"): an element is laid in the paint of the pot it is taken from - its
  act's `from`, else the nearest paint on the table (`TablePaint._pot_of`) - as thick as brings that paint over a light face to the
  design's lightness (`_thickness`: a lighter plum a thinner plum; the first base's tan the white pot's white, whole); one thinner than
  `THIN_WET` is taken up on a brush wetted in the water first, rinsed and not dried; one with an edge as soft as `SOFT_GONE_OVER` goes on
  crisp and is softened as its tool goes back over it in the same act (its own blend, mapped where the brush went). Two elements from one
  pot are one load. The tip shows the pot's paint.
- **One coat of a paint; a tool's acts one after another** (0062: "Why are we now applying a second round of white makeup to a face that already
  is completely white?"; then, of a thin first coat and a made-up second: "why are we making two passes of white at all? ... There ought to
  be one application of white, no more"): a design's fills over the whole surface in one pot are one application, as thick as they come to
  together, the rest taken out of the design (`TablePaint._one_coat`); an act left nothing to lay takes nothing up (257002's second base: its
  act now lasts a tenth of a second and the rim shade follows it). A tool whose next act comes straight after and begins in the paint it
  ends with is neither cleaned nor put down between them; one rinsed at the end of its act begins the next damp (`_one_after_another`; 0061,
  0063: "the sponge went into the dish, then came back to the mask and started dabbing again").
- **A press built by presses, and what is thin put right then** ("the darker regions will sometimes slowly increase their brightness to full
  white, even though nothing is touching those places. It's like there is leaky code"; "Why can't the heuristic just correct specks as they
  appear, localized ... If an area of makeup is thin, they would fill it out before moving on"): a press's film had been thickened on a
  clock to its strokes' end. It fills only where and when another press touches it (`Skins.touch_map`'s third channel, `AGAIN_AFTER`;
  skin_paint.gdshader's `again`); one dab leaves most of its paint (`FIRST` 0.85, a sponge all but dry `DRY_LEAST` 0.75 of it); and a point one
  press reached all but dry is a gap like a bare one, pressed again right after the press last round it (`GAP_THIN_LOAD`). Rendered on
  257002: one white coat from the middle out, even as it goes, its specks put right as the sponge passes.
- **Specks left in the white (feedback 0001, 2026-11-07: "missing specks of makeup all over this face ... it's painting in new areas around
  the scalp, at the chin... and it's completely ignoring the ugly missing specks right at the center of the face")**: not holes - the reveal
  map had none - but points one press alone reached, a dab's thin film, thickest round the nose, kept to the act's end (the face as the
  shader draws it, 264 s and the end, reproduced the screenshot). Only a dry one had counted as thin, and the look stamped up to nine pixels round
  each touched point where the map stamps one to four, so it counted two presses where one had landed. Now A POINT ONE PRESS ALONE REACHED IS THIN
  (`TablePaint._gaps_left`), the look stamps as the map does (`PRESS_SPOT`), and a thin patch is pressed right after the later of its own
  press and the paint round it. 257002's base: nothing under 60% shown at its end, 11 mm2 left to one press - but 863 presses for 568, the
  base 470 s for 312, the show 4.6 minutes longer on the plan's own timing. Gate: paint_check (the stipple's area one press alone reached;
  control, its presses as planned).
- **A powder is a paint** (found on 257002 while looking at 0001): only creams were the table's paints, so its setting powder took the
  nearest cream - the white - and as a fill over the whole face in the white's paint `_one_coat` folded it into the base: both powder acts
  lasted a tenth of a second and patted nothing. Its copper glitter, from a vial of copper flakes, was laid in the rust cream. The table's
  powders are its paints too, a track's `from` gives its own whichever kind, and the nearest is of the element's kind (`TablePaint._pot_of`).
  Gate: paint_check `_coats` (control: taken as a cream, its nearest is the base's white).
- **Never short of whole** (0001 again: "a tiny spot just under the nose that is slightly more transparent"; "a small piece to the left of
  the nose as well"; the user: "if you consider the face to be a flat map, and if coverage is alpha transparency ... why could we not just
  detect and correct regions where there is still transparency, and never stop until we have 100% coverage?"): the spots were the only four
  patches of 257002's base one press alone reached at its end (under the nose, beside the left nostril, two by the right eye) - where the
  corner never lands a second time, and painting them anyway laid them with their own press again. Now what one press alone reached is laid
  again by the touch aimed nearest it OF THOSE AFTER IT (`TablePaint._painted_anyway`'s `firsts`): none left. Why it had been hard: the
  loop looks at its own estimate of what the tool touched, not at what the shader draws (a first dab's film, a second's filling, a 1.6 mm
  ragged read, a moment interpolated between pixels), and each fix closed one gap between the two; and it stops at five looks, after which
  only painting it anyway can finish what the tool cannot reach. Gate: paint_check (a point the first press reached laid by the second;
  control, not told what reached it, by its own).
- **An act left nothing to do is no act** (0002: "we went in the water, then dabbed it dry, then put it on the white tray. Then, we picked it
  up and just dunked it in the water again ... redundant"): 257002's second white, folded into the first, left its act empty, and it stood as
  the sponge's next act - the white's rinse left IT damp, and the rim shade began dry and wet the clean sponge again
  (`TablePaint._one_after_another`, `_paints_nothing`). The rim shade now loads straight away: 8 s sooner, its act 7 s shorter.
- **The hard orange edge** (0003, 0004: "how is the sponge making such hard, perfectly-straight edges of orange there?"; "a huge sponge
  pressed against the face, somehow creating a hard orange edge"): laying a press's paint where it touched was TRIED AND TAKEN OUT the same
  hour - it smeared a warm band 10-20 mm wide round the whole face (the user: "The problem was the sponge, spilling over that hard edge but
  leaving no mark ... dab in the regions below the hard edge, where it is safe and it won't spill over, then use a finer brush to make the
  hard edge clean"). Where it came from: the decorator's `rim shade`, a 6 mm ring copied from the painting's softly darkened edge, laid
  since 8c04fbe crisp first (`SOFT_GONE_OVER`) and in a pot's thinned rust (`_pot_of`) - before, in its own pale paint, 4 mm soft from the
  first dab, it hardly showed. What answers it is below: "The painting is the design".
- **A line is the band its hairs sweep** (2026-11-07: "nearly all straight lines are 'splotchy' ... super jagged when applied, and they
  require correction later. But a proper brush stroke is more often than not very smooth, with clean edges... which might fade near the
  tail"; 0060, of the touch-ups: "tapping at each jagged place"): each pull laid as a clean band as wide as the line, narrowing and thinning
  over its last quarter (`Skins.band_map`), and never gone back over for gaps - laid from the hairs' tips found at moments apart, a line
  had been beads, and the dabs that filled them stood out.

## The painting is the design (2026-11-07, late - ENGINE BUILT, not yet in the show)

The user, after a day of specks, spills and a hard orange edge: "There is a lot of detail in this reference mask, and ... our own painting
on the mask was nowhere close to that ... see that the mask is mostly white, so paint a white foundation. See that there is a lot of
orange, so lay the orange layers on ... See that there is orange ON TOP of the purple, so layer more orange on ... This is a layering
problem. With enough error correction and layers, we should be able to paint any mask really, of any arbitrary level of detail. The tools
are just there to give the visualization of our self-correction process ... Consider the brick-building mode."

Why the day went as it did:

- **The detail was gone before a tool moved.** The painter makes a detailed picture of the finished face (`face_ref.png`: cracks, rust
  flakes, gradients); the decorator, a text model, redraws it as a few dozen SVG shapes; every tool lays the shapes, never the picture.
  The painting's softly darkened edge became a crisp 6 mm ring; its rust texture, polygons.
- **Whether paint lands was decided by simulating the tool**, and coverage by a separate estimate of that simulation, while the shader
  draws with effects neither shares (a first dab's film, a second's filling, a ragged read, interpolated moments). Every mismatch was a
  speck; every shape narrower than its tool, a spill that left no mark or paint the tool never touched.

What brick mode does right: an agent decides WHAT (a design), code decides HOW (exact parts), staging animates it, and it always finishes.
The painting's own version, built as `PaintLayers` (src/table/paint_layers.gd; Hertzmann 1998, "Painterly Rendering with Curved Brush
Strokes of Multiple Sizes"):

1. **The painting is the target**, pixel for pixel, painted with the table's own pots (laid whole or thinned).
2. **Widest tool first**: the sponge, then the flat brush, the round brush, the liner. Each pass aims at the picture blurred as far as its
   tool resolves, and paints only where the canvas still differs from it, each point given the paint that brings it nearest; the paints
   that put most right go first. Orange over purple, or over a black line, comes of a finer pass finding it still wants orange.
3. **A tool goes only where its footprint fits**: a dab or a stroke's every step must lie where its paint makes nothing worse (`FIT`,
   `WORSE`) - never a spill that leaves no mark, never paint no tool touched. What a tool cannot fit is the next, finer tool's; the finest
   lays what is left, so it always finishes.
4. **What it lays is exactly its strokes' footprints**: the canvas it keeps IS the painting. A show draws each layer as computed and poses
   the tool along its strokes - the tools are the visualization.

First run, on 257002's picture with its table's seven creams and the sponge, flat brush, round brush and liner (16.6 s): a white
foundation, the sponge's rust and plum masses, the brushes' grin and eye shapes, the liner's brows, tears, rivets, diamond and lip line -
off the picture (in the palette's colors) 5.2 on average, 16.5% of the surface over 10. What it took to get there, each a class of fault:
a base chosen by the least average had been a grey between the white and the rust (now by vote); a picture blurred for a wide tool was
painted in colors nobody mixed (a white flecked with rust, pink - now each point the color MOST of the tool's window is nearest); the
painted picture's own light left its white a tan (`#dbc3ae`), matched as a rust thinned over the white (now balanced so its ground is the
foundation's paint); a liner judged point by point chased the picture's grain (now by area, 2 mm cells, and a dot only where well off).
Open: the liner's 2,465 strokes (rust flecks and drips; a show cannot spend a second on each - a stippling sponge's own texture, or merging,
should take most); the faint hairline cracks fall under the threshold. Gate: paint_layers_check (a white foundation first, tools
narrowing, orange laid over purple, nearly all of it finished; the control, the sponge alone, leaves the line and the streak).

NOT A REVEAL (the user, 2026-11-08: "If you are suggesting that we essentially just 'reveal' layers through transparency operations, I
feel like that could be very wrong ... the expression is not only in the layering: it is in how the tools put those layers on the face.
The strokes of the brushes, the big splotches from a sponge, or small ones from a sponge's corner, the fine lines drawn in pencil or tiny
brushes ... the motions, the pressure applied, the direction a stroke is carried, the amount of product upon the bristles - and how it
decays over time"). The picture says only WHERE paint is still wanted; every mark is a tool's:

- A STROKE IS CHOSEN, NEVER A PIXEL: its tool, pot, path, way and pressure - a sponge's corner a small dab, its face a big splotch; a brush
  pulled along the form, pressed wider; a liner's line.
- A MARK IS DRAWN AS ITS TOOL LAYS IT, and the canvas the engine corrects is those marks: bristle streaks along a pull, a load running dry
  over its strokes until the tool goes back to its pot, a tail thinning, a sponge's pores and ragged edge - a patchy area is gone over again
  as a painter would.
- THE SHOW PLAYS THOSE STROKES through the motion it has (programs, held poses, hairs bending, the sponge squashing, trips to the pot); its
  paint is the marks' own coverage, revealed as the strokes are laid.
- FIRST, THE AGENTS AS THEY ARE: each decorator element is the region its act works in, with its pot and its tool; the engine fills it from
  the picture, element by element in the acts' order, on one canvas.

BUILT, the same night (not yet watched): `TablePaint._from_picture` lays every element a sponge or a brush lays by dabs, dots, pulls or
lines from the picture, element by element in its acts' reading order, on one canvas - its act's tool, its pot, its shape grown 3 mm as
where it works; its program the strokes `PaintLayers.lay` chose, made by `Skins._Prog` (the show's own loads, trips back to the pot, hand);
its paint their coverage (`foot`), its reveal their moments; nothing looked for after (the gap loop and the touch map pass it by). The
first element filling the whole surface is a FOUNDATION: its own paint, whole, gone over at what is still bare until no speck shows. An
element the picture wants nothing of in its place lays nothing, and its act takes nothing up. 257002 stands in about the time it did
(64 s); on the plan's timing the show runs 67 minutes where it ran 55 (the foundation ten, the rims and mouth longer: the picture asks more
of them than the decorator's shapes did). A hand looks at its work once every few strokes (`LOOK_EVERY`); an operation draws at most
`PULLS_MOST` strokes and `TAPS_MOST` taps. Gate: paint_check `_picture` (the foundation and a brushed element laid from a picture, the brush's
black on the picture's black and not on the white beside it in its own shape; the control, no picture, the shapes as before).
  Then, looked at in the show on the GPU (`episode_bake_probe --shots`): the foundation whole to the rim at 640 s, the rim shade a soft warm
  tint at the face's edge where the decorator's ring had been a hard band, the liner's rust runs beside the seam. Two classes of fault
  found and fixed: A TOOL PRESSED ONLY AS HARD AS IT GOES - a flat brush wider than a bar laid nothing, a round brush never a rivet - now
  each mark is tried at lighter presses until one fits, narrower as a brush is lifted (`DAB_PRESSES`, `PULL_PRESSES`, `LINE_PRESSES`); and
  THE WORK RAN PAST ITS WORDS - laid with no end, the work ran an hour past the reading and the show closed on a face half painted - now each
  operation draws the most wanted strokes its act's planned time holds (`PICTURE_SLACK` of what its shape's program took, the length the
  readers' words were written to), in the hand's order: 257002 ends at 3034 s on the plan's timing, where it had ended at 2837. The
  foundation alone is laid whole whatever it takes (573 s where its shape's took 332), its last looks aimed at patches big enough to see
  (`BASE_AREA`), never at what lies between a sponge's pores.

- **A sponge dabs with whichever side the work needs** (2026-11-08, of the foundation laid from the picture: "much too quick ... the
  splotches of white are appearing BEFORE the sponge actually touches the mask ... every touch of the sponge creates a paint area that is
  at least 4 times as large as the corner we touched the mask with ... all dabs are applied at full color"; of the old stipple: "the
  splotches were too big there as well ... the foundation was extremely wet ... it would ooze and spread outward, in a crawling fashion";
  then: "it should be possible to dab from any side of the sponge really ... the corner for smaller detail work, the flat side for larger
  surface areas"). Each dab is judged by WHAT THAT SIDE REALLY TOUCHES there, as the show poses it (`TablePaint._side_touch`, handed to the
  engine as `touch`): its face where it lands most on what still wants paint, its corner where only a corner fits; the program says the
  side by place (`way_at`) and `_held_keys` holds it so; its mark is the touch itself, softened and cut a little ragged, a thin film
  (`FILM` 0.7, pores), shown as the sponge meets the face (`DAB_MEETS`), never spreading after. Goings-back spaced by the dab already
  there; what no side reaches, painted anyway with the nearest dab. The old stipple's paint had been read from a map a point a millimeter
  with a 1.6 mm ragged edge (about 3 mm past every touch) and its holes filled as later presses landed - the size and the ooze. 257002's
  foundation: 281 dabs in about 4 minutes, its face covered 0.96 on average, 0.07% under 0.6 (it had been 2,258 corner dabs and 23 minutes,
  or a coat that stopped at half); the table stands in 60 s. Seen on the GPU: flat on the forehead at 30 s, its corner at the temple and
  the nose's sides at 150 s, whole at 255 s. THEN (the user, watching: "The sponge is dabbed in the foundation container, via a single
  corner. Then we proceed to tap the face with the flat side - which would not have picked-up any foundation at all ... perfect 100% fill
  rate ... never refilling from the container"): A SPONGE IS LOADED ON THE SIDE IT DABS WITH - each trip to the pot, and the act's first
  load, presses the side its next dab is pressed with onto the paint (`_side_after`, `_pot_hold`'s `side`: its face tilted into the pot,
  narrower than it, a corner tapped); A LOAD IS SPENT BY WHAT IT LAYS (as many dabs a load as `LOAD_AREA_DABS` holds this dab's touch -
  counted in a corner's dabs, the face's prints had laid a whole foundation on two loads); and each dab a thinner film (`FILM` 0.5).
  257002: 337 dabs (232 by the face), 44 trips back to the pot, about 7.6 minutes, its face covered 0.93 on average, 0.28% under 0.6.
  Seen on the GPU: the face pressed into the white pot at 180 s, the white built out from the middle in the sponge's own prints.
- **The sponge pinched, not pressed flat** (2026-11-08: "the entire sponge is compressed uniformly ... like praying. Instead, the sponge
  should compress from the middle - while the edges still try to expand"): squeezed in the hand, it is thinnest under the finger and thumb
  and less so away from them, its ends their own thickness and a little more (prop_common's `squeeze_reach`, `SQUEEZE_EDGE_SWELL`;
  `TablePaint._squeeze_reach`, `SQUEEZE_REACH`).
- **Laid over the pot, area by area, built up as laid** (2026-11-08, feedback 0005-0006 and the user's notes while watching). THE FACE
  LAID OVER A POT TOO NARROW FOR IT (0005: "The sponge is clipping through the container ... You would expected it dabbed flat: resting on
  both sides of the container, and compressed/pushed from the middle, into the container. It would bend in the middle"): the 50 mm sponge
  over the 45 mm white pot had been tilted 60 degrees and lifted by the search for a way to fit inside the mouth, its corner still through
  the wall. Now a face wider than the mouth (`_wider_than`) rests flat on the rim (`DRAPE_CLEAR`) and only bends: pressed, its middle goes
  down onto the paint and a little past it (`DRAPE_INTO`), its back further under the finger (`DRAPE_DENT`, `DRAPE_FINGER`), nothing past
  the wall, what lies outside the mouth over the rim, its faces turned as it bends (`_drape_on`, prop_common's `drape_*`) - and a part of a
  material that gives is cut finely across its faces (`Props._fine`'s `_gives`), or no press could bend it: its broad faces had been one
  flat quad each. THE DABS AREA BY
  AREA ("it moves from cheek to cheek, eye to eye, forehead to chin - it jumps everywhere, then returns"; 0006: "touching up everywhere
  else, but completely ignoring the giant gaps missing in the center of the face"): the dabs had gone in rings round the whole face, and
  every look again began at the middle once more, eight times. Now a coat is shared out among areas three dabs across (`AREA_DABS`), begun
  where the broadest side lands most of itself nearest the middle, each area worked whole - its dabs the nearest next, then gone back over
  until nothing in it is short (`AREA_LOOKS`) - before the hand moves to the area beside it nearest where it is (`PaintLayers._coat`,
  `_area`, `_next_area`); an area works its own points, each cell's worst among them (`_wanting`'s labels: picked among all a cell's and then
  left to the area beside, a border's cells had waited for the end). And the sponge keeps the side it holds while it lands mostly on what
  wants paint, one side then the other in each pass (`SIDE_KEEP`, `_side_for`; it had turned in the hand at nearly every dab - and gone
  back over by a corner wherever it touched, it took 993 dabs and 14 minutes). BUILT UP AS LAID ("the dabs are extremely heavy with
  paint. There is not opacity at all ... more transparency at edges, or sometimes randomly, or near the end of the foundation's load"):
  the engine had laid each print as a thin film, but a show drew each point at what ALL its prints came to from the first that touched it -
  a reveal of the finished coat. Now `PaintLayers.render` says what each point holds after its first, second and third marks and after its
  last, and when (`built`, `built_when`; skin_paint.gdshader's `laid_*`), so a print shows its own film and the next thickens it; and each
  print is lighter toward its edge - a broad one over a share of its width (`EDGE_FADE`, `EDGE_FADE_SHARE`, `EDGE_LEAST`; faded its last
  2 mm only, the face's print on a flat brow was a sharp-cornered rectangle), its edge wandering more (`TOUCH_SOFT`, `TOUCH_RAGGED`) -
  some lighter than others (`FILM_LEAST`), and fainter as the load runs out (`DAB_DRY_LEAST` 0.35; a brush's pull keeps `DRY_LEAST`), its
  film `FILM` 0.65. 257002's foundation: 477 dabs (223 by the face), 58 trips back to the pot, about 8.5 minutes (`FOUNDATION_SLACK` 3.0
  tells its readers 498 s), its face 0.94 on average and 0.01% under 0.6; the table stands in about 86 s (it had been 60). Seen on the GPU:
  the sponge flat across the white pot's rim, dented in its middle as it is pressed and back between presses; the white going on in soft
  translucent prints that thicken where they overlap, the brow first, then the forehead, round the eyes, down the cheek. Not looked at
  live; 104-113 turns in the hand remain, about one every five seconds. THEN (feedback 0007: "that hard-edged white against transparent
  color looks strange ... you would expect edges between the shades of white to be more feathered, blurry. It's also not clear why EVERY
  application of the sponge results in transparent white, the first time it's applied ... Some might be perfectly white, others might be
  very faint ... determined by factors like: how much foundation is on the sponge, which part of the sponge we tapped with, how much
  pressure was applied"): the show had been told each point's first three marks and its last (four slots), so every mark past the third
  came in at once, cut along the last one's edge - the hard white; it is told seven and the last now (`BUILT_SLOTS` 8, `laid_map2`,
  `laid_when2`), each print's edge feathered (`TOUCH_FEATHER`) and pressed hardest in its middle, its farthest corners least (`CORNER_FROM`,
  `CORNER_LEAST`; a flat face's print on a flat brow had been its rectangle). And A DAB LAYS WHAT IS ON THE SIDE IT PRESSES, AS HARD AS IT
  PRESSES (`PaintLayers.deposit`): `FILM` 0.95 of a fresh load pressed hard by the side just loaded - near solid - its load's share of that
  (`LOAD_POWER`), a light press less (`PRESS_DEPOSIT`; a dab's press is now kept on its stroke, and pressed between 0.55 and 1), a side other
  than the one just loaded half (`OTHER_SIDE`), each its own share (`FILM_LEAST` 0.55). 257002: 525 dabs, 58 trips, about 8.8 minutes
  (`FOUNDATION_SLACK` 3.2), its face 0.94 on average. Seen on the GPU: some prints near solid at once, others faint, soft irregular edges,
  no rectangle. Gates: paint_check (the face laid over the mouth: flat, nothing past the wall, its middle on
  its paint; the controls, unbent it never reaches the paint, fitted inside it is turned far over), paint_layers_check (the hand comes back
  to a square it left half as often as rings at most; a point holds a thin film after its first mark; the controls).

- **The audit (2026-11-08, after "it looks HORRIBLE ... like something a child did with finger paints" at 37:00).** A second opinion
  (Codex, read-only, on the code, the reference and the engine's own canvas), its central claims checked against the code:
  1. THE TARGET THROWS THE DETAIL AWAY before a mark is chosen: `_aim_for` replaces every pixel of the reference with the nearest of the
     pots-over-the-ground at four opacities, then the majority over the tool's width - no gradient, flake, crack or highlight survives -
     and `NEED`, `GAIN` and the 2 mm cells reject small corrections; planned at 2 px/mm from a 3 px/mm picture. The "9.1 off" was measured
     against that substitute, not the painting.
  2. THE DECORATOR'S ELEMENT IS THE UNIT OF EVERYTHING: one tool, one pot, its traced region (crude rust polygons, a sparse crack network),
     its act's slot and a budget of its old SVG program's time x1.1 - whatever the trace missed can never be painted, and nothing goes back
     over the whole face at the end.
  3. MARKS ARE JUDGED BY A PROXY: `_fit` tests a disc at the heaviest press, not the mark the raster draws; a stroke with no slope to follow
     goes horizontal (`Vector2.RIGHT` - the capsules); lines under 2.5 mm become capped taps (the flakes, crack branches, highlights).
  4. THE SHOW DOES NOT DRAW THE CANVAS THE ENGINE JUDGED: the engine mixes in linear light, the skin's viewports blend sRGB sprites and the
     prop shader unpremultiplies and decodes after; a blend softens coverage the planner never saw.
  5. Powder, mist, blending and gloss are outside the planning canvas.
  Proposed instead: one compositor for planning and playback; the original reference as the target at its own resolution, marks fitted by
  what the raster really lays, judged on color, edges and detail at several scales; agents name regions, order and finishes, and code
  schedules long tool sessions over the whole face with a reserved fine-tool pass at the end; the program's length fixed before the voices
  are written to it. Not started: the user's call.
- **The engine rebuilt (2026-11-08, night - "Go ahead with all of the required work ... The foundation matters most: we have to START from
  the right place").** Built and measured on 257002 with `tests/table/paint_preview_probe.gd` - THE SHOW'S OWN CANVAS AT ANY MOMENT, read
  back from the GPU after setting the paint alone to that time (no bake: a frame at 37:00 had taken half an hour of playing up to it), beside
  the picture, with how far it stands from it. What changed:
  1. ONE COMPOSITOR: the engine's canvas is the skin canvas's own - paint times coverage blended as sprites over clear, shown over the bare
     surface as prop.gdshader shows it (`pre`, `alp`, `_shown`, `_after`).
  2. THE PICTURE ITSELF IS THE AIM for every operation but a foundation, point for point; its ground balanced to the foundation's paint and
     ITS LIGHT TAKEN OUT where it falls off (a flat field from the ground's own points, `_ground_shade`) - the painted picture's soft shadow at
     the rim and beside the nose had been copied as a brown ring and a grey line.
  3. MARKS FITTED BY WHAT THEY REALLY LAY (`_fit_op`): where laying the pot helps most (`_regain`), the next near the last; a stroke traced
     along the run of what still wants it (`_way_at`: across the slope of that want, else the long way of its patch, else as a hand pulls -
     never a horizontal default), each candidate rastered at each press and thinning (`THINNINGS`: a dark pot thinned is its tint) and laid
     only where it puts at least `MARK_GAIN` right overall and `MARK_AVG` on average, a point made worse counting `WORSE_WEIGHT` times. Smears
     are laid this way too, as lines of the paint they drag.
  4. WHERE AND HOW LONG: an operation works `REGION_GROW` (8 mm) round its element, `PICTURE_GROW_LINE` (15 mm) round a line or dots; at most
     `PICTURE_SLACK` (1.25) of its shape's time, its readers told `PICTURE_TOLD` (1.0) - what the operations took, all together; a blend
     softens what was laid from the picture no more than `PICTURE_BLEND_LOD`.
  5. THE FOUNDATION WITHOUT MISSES ("there are a ton of MISSES: dabs that touch a place that didn't need to be touched"): going back over, a
     print lands at least `LOOK_LEAST` (half) on what still wants paint, aimed at the middle of what wants it; a load lasts `TOUCH_LOAD_AREA`
     of printed paint; whole to `BASE_NEED` 3 and its last thin places evened by the print beside them (`BASE_FINISH`). 257002: 501 prints in
     6.8 minutes, 28 trips to the pot, 0.98 of the face covered, 73% of each print on what wanted it (it had been 13.4 minutes at need 2).
  6. A powder is no longer gone back over (a puff's pats had held the show two and a half minutes for a finish no one sees), and the face
     painter is told the table's paints (`Skins.table_paints`, painter.yaml `face`): 257002's picture asks for a bright orange no pot holds.
  Measured, the show's own canvas against the picture at the end of the painting: 22.4 off on average with 80% of the surface over 10 before;
  13.5 and 50% after - brows, eyes, drips, the diamond, the seam and rivets, the smile, cracks and rust in place. Open: the rust's color (the
  pots), the eyes' blotchy shadow, the total length (about 44 minutes of painting), and the next layer - AN AGENT IN THE LOOP choosing each
  operation from the canvas as the show will draw it (the user, 2026-11-08: "send in-progress images back to agents, and allow the agents to
  determine which steps we'll take next"), the engine laying it.
  THEN (the user: "I can't even use the realtime player anymore ... stuck on 'Catching up'"): the table had taken 200 s to stand, the
  foundation 81 of them, a sponge's rim shade and rust 39 and 38 - every candidate print drawn with its pores and ragged edge computed a
  point at a time, at four sides and three thinnings. Now noise is read from a table made once (`_noise`, `NOISE_SIDE`), candidates are
  weighed by a plain print (`raster`'s `quick`), a sponge's narrower sides are asked only where its broadest helped too little, an operation
  gives up after `FIT_REFUSED_MOST` refusals in a row, a foundation never weighs thinnings it does not use, and its evening finds the nearest
  print by cells (`EVEN_CELL`): about 90-105 s. Skipping ahead is the physics' bake (8 to 10 times as fast as the show, the rigid bodies and
  liquids its cost - `episode_bake_probe --profile-bake`), not the paint: 37:00 is about five minutes of baking. And of feedback 0009 (the grey
  diamond "just a grey smudge"): a brush's dot is now as small as its tip (`TIP_LEAST`), crisp (`TIP_RAGGED`, `TIP_SOFT`), a stroke as narrow
  as `PRESS_NARROW` of its width, a spill costs `WORSE_WEIGHT` 3, and the show's maps are drawn at `FOOT_PX` 4. Up close it is still far from
  the picture - the eyes broad overlapping strokes, the rivets grey dots, the rust a wash - which is the decorator's acts (one tool, one pot,
  a rough region and an old program's time each) more than the marks: the agent in the loop is the next step.

## The painter (2026-11-08, late - BUILT, gated with a script in an agent's place; no real agent has run it yet)

The user: "the act structure is kind of a huge limitation. It forces an entire act to use one tool ... I would expect acts to be more fluid
... you would restrict tools to the necessary job ... a real artist would go into this with a plan. They'd start with layers, with wide
areas, and they would keep refining their work at every step ... with an agent, we can peak at each step, and make informed decisions
about what to do next." And found on the way: THE DECORATOR HAD NEVER SEEN ITS LOOKS - `look` handed AgentTools a file's path, which it
drops (it sends only an Image); every look came back blank. Fixed (the picture itself handed back; skin_step_check holds it).

- WHERE A FACE WAS PAINTED FIRST AND THE WRITER TAKES TOOLS, the `skin` step is THE PAINTER (`PainterTools`, rules/table/painting.yaml,
  `TablePrompts.painting`): it paints the picture again at the table an operation at a time - a tool of the table's, a paint of its pots,
  how (sponge, dab, sweep, line, or a powder patted on), where (a closed path in millimeters, or all), how strong and how long, in one of
  the episode's beats (its intro, each stage of the plan with its `work`, its close) - and `look`s after each: the picture, the canvas as
  the show will draw it, and where it is still off, on a 10 mm grid. [PaintLayers] lays each on that canvas (on a worker; a sponge as a
  disc there, its real sides at the table); `undo` puts the canvas back; `submit` hands in the design, an element an operation, its `plan`
  (tool, how, beat, seconds) beside it. Elsewhere the decorator designs, as before.
- ITS ACTS ARE MADE FROM IT (`TableProducer.acts_from_painting`): beat by beat, in the order laid, each run of operations with one tool and
  one way an act - the hand putting one tool down and taking the next as the work asks, the beat's passage spoken over them all - each
  told the seconds its operations took (`Skins.act_natural` reads `plan.seconds`), and laid at the show in that time (`PLANNED_SLACK`) and
  the region drawn (`PAINTER_GROW`). A design no painter laid goes to the puppeteer as before.
- Tried with a script in the painter's place on 257002 (16 operations - ground, rust, the eyes, brows, seam, rivets, drips, smile, diamond,
  cracks - in about 22 minutes of painting): its canvas 12.7 off the picture where the decorator's 40 acts had come to 13.5 in about 44
  minutes; the show standing it 15.7 (a sponge's real sides, the acts' times on an old script).
- Open: THE SHOW SHOULD REPLAY THE MARKS THE PAINTER SAW, not lay its operations again (one plan, one canvas); a stroke in a broad region
  with no run to follow goes one way (the eye shadows came out as bars); a mist, a glitter and stones are not among the painter's ways yet
  (no spray tool is found without naming one); and a real agent's run - a new episode, made from the plan up.

Still to build: the decorator naming only each beat's REGION and
the finishes a picture does not carry (gloss, glitter, stones), the layers painted beat by beat inside them; the paint acts made from the
plan by code, as brick mode lays parts. Probe: `tests/table/paint_layers_probe.gd` (an episode's `face_ref.png` painted in layers, each
pass's canvas beside the picture).

## The painter's first run, and what it could not do (2026-11-08, night - BUILT; looked at on the painter's own 28 operations replayed)

The painter's first real run (joker-motivation 327484, 27 operations in about 19 minutes; stopped before its readers) came out
recognizable and flat. The user, of its `look_30.jpg`: "the crackle is missing, the lips and eyes are smeared instead of feathered;
overall the presentation is just very flat ... I really wish we could just emulate the images better" - and, mid-work: "ANY brush can be
applied with varied degrees of pressure ... Even with a thicker brush, it should be possible to paint small lines or dots ... this is the
brush size option, in any paint program". A fade-in of the picture was talked over and left: it would show, and it is not paint.

- A LINE OPERATION DRAWS THE PICTURE'S OWN LINES (`PaintLayers._trace_lines`): found at the picture's own resolution (`hi`, 3 px/mm, where
  a crackle's hairlines are a pixel - the canvas's 2 px/mm never held them), where the picture is the paint or stands nearer it than what
  is round it, followed on where a line fades (hysteresis), its dotted gaps bridged, thinned, and followed as a hand draws - through where
  lines meet, joined to what is drawn, on without lifting into the next that begins where one ends. Each is pressed to the line's own width
  point by point; one wider than the brush filled with passes beside it. Short lines are flicked (`TRACE_SPEED`), long ones drawn with care.
  Where an operation finds lines it draws only those: fitted after them, a liner had hatched a bruise in bars. The answer tells the painter
  how many it found, drew, and how long the rest would take - the regions 327484's painter drew round held about 1,400 mm of black crackle
  and 2,100 of gold, minutes each.
- PRESSED TO THE WIDTH (`_pressed_to`, `_wide_at`): a fitted stroke is tried pressed point by point to the width of what still wants its
  paint, beside each even press, and traced as wide as that - a fat brush follows a hairline with its tip (`PRESS_NARROW` 0.12; a dot as
  small as `TIP_LEAST` 0.15 of the brush).
- A BRUSH'S BELLY (`BELLY`): a pull thins out over the outer half of its width, a blend's more - a band laid flat to a crisp edge had made
  every lip and eye a smear; overlapping strokes now build a gradient and feather.
- ONE STROKE ONE COLOR (`TRACE_SAME`): a stroke runs on only while the picture (softened over a millimeter) stays the color it began in.
- MIXED ON THE PALETTE (`mix`, `PaintLayers._mixes`): an operation may name creams to mix with, and each mark takes the mix (a quarter, a
  half, three quarters - pigments' weighted geometric mean, so they darken as paint does) that brings the canvas nearest. A mark carries
  its colors (`cc`), the show draws an element's own colors from `PaintLayers.render`'s `tint` (skin_paint.gdshader `tint_map`).
- A BLEND (`how: blend`, `_blend_op`): no paint - a clean brush, rinsed first at the show, pulled short across edges the canvas has and the
  picture does not, taking up what it passes over (`BLEND_PICK`) and laying it on along the way, each pull kept only where it brings the
  canvas nearer. Its marks carry what they picked up.
- The painter keeps every operation's marks (`PainterTools.laid`) - the first step toward the show replaying what the painter saw - and
  its looks are at 3 px/mm.
- Replayed: the same 28 operations, the closed eye now has its lashes, the brow is one arc, the tear its gold edge, the lips soft with their
  light; the crackle real lines where the painter gave them time. The bruised eye is still one mass of a mix: the painter's to work in
  layers with what it has now.
- Open: the show replaying the painter's marks (brushes exactly; a sponge's real sides differ); a mix's tool dipped into both pots; a
  sponge's blend (pressed, never slid); a foundation still about eight minutes; the user's eye on a new episode.

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
2. ~~**Its own colors on the mask.** The paint laid is THE REFERENCE'S OWN PIXELS~~ - REJECTED (feedback 0049, below): the tools lay
   their own paint, and the painting says only where and what.
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
- ~~**The paint carries it**~~ (each element laying the painting's own pixel wherever its color was near the element's paint) - TAKEN
  OUT 2026-11-07 on the user's first sight of it (feedback 0049, 257002 at 1:57, the first base still being sponged on): "You can already
  see the streaky tears under the eyes, you can already see patterns on the forehead, the eyes themselves are perfectly smooth while
  everywhere else has messy textures. The white itself is barely visible... we are just revealing the underlying PNG through
  transparency manipulation"; and "We still need to be painting textures upon the face... we should just be taking cues about where and
  what to apply from the reference designs." The base's tan (#d5b9a1, 0.85) was near enough to the painting's cream that it laid the
  painting - cracks, rust and the streaks' halos - over the whole face at once, and its own color only where the painting was far from
  it (the eyes). Now an element lays its own paint (skin_paint.gdshader reads its own maps alone), the table never reads `face_ref.png`
  (`Table._skin_json`, `TablePreview.PICTURES`), and the decorator is told its marks are the only ones laid (decorator.yaml `copying`).
  The painting stays the decorator's guide: shown it, told its colors, each `look` beside it.
- Gates: skin_step_check (the steps and their order, the controls of an episode designed before and designed again; the canvas, the fit
  and its controls, the light taken out and its control, the palette; landing, sending back and keeping; the prompts whole), paint_check
  (an element draws from its own maps alone; the control, the shader that read the painting).
- Not built: step 3, code taking the painting apart into elements (`Skins.separate`) - the decorator traces it by eye for now. And no
  real painter has painted a face: the first one is for the user to see.

## Open

- A real episode: the producer planning `painted`, a decorator drawing a face, a puppeteer blocking paint acts, readers talking over
  them - and the user watching it. 856886 has been watched once (above); its passages, and its table for the new mask, are for the user
  to make again.
- ANSWERED 2026-11-08: the producer counted every voice's word at 0.52 s (Proof's Piper); 257002's Kokoro at pace 1.2 said 3,779 words
  and 463 s of silence in 1,920 s - 0.39 s a word - so every passage came out a quarter short and the painting ran 15 minutes past the
  last word (the show closes on it). Now a passage is written to the reader's own pace (`ReadingCast.said_word`: each engine's measured
  pace over its `pace`, handed to the producer in its spec), and told what its acts take as the table will lay them: an element laid from
  the picture its shape's time times `PICTURE_SLACK` (a foundation's, `FOUNDATION_SLACK`, its goings-back held to it), a coat the table
  folds into one before nothing (`Skins.folded_coats`). 257002: the table takes 2,530 s, its readers would be told 2,719 s.
- The voice by ear: Secular Hazing's Puck at its pace and tone over a face being painted.
- A tool held over the face hides some of what it paints. A sponge or a dab is held up and out to the side; a brush drawn toward the
  lens now leans toward it (a line half as far; a fill on its belly all the way, or its rows streak). If that hides too much, the other
  way is to draw such strokes away from the lens - a fill's rows all one way, lifted back between - which lengthens every fill act.
- Marks left on the towel by what is wiped on it.
- The holds are found as the table stands (3.2 s of 209459's 8.5, on a worker now): kept beside the episode by what they are found
  from, a second play would not wait for them.
- Two readings of depth near a steep nose disagree by a few millimeters; a true distance to the surface (not a height read across a
  slope) would settle it.

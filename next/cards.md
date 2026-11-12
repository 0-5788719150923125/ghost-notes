# Ghost Notes: Cards

A card reading nobody writes. A show is a document; each seed of it is an episode that agents plan, deal,
paint and write one card at a time, and ghost reads it aloud in the Generative voice at a table. The first
deck is the tarot (`rift/tarot/truthful-tarot.md`, "Truthful Tarot": the genre's format and voice, told
true); the prompts, the 78 cards and their elements live in that show's guide, not in code. Reversals and
jumpers are each episode's producer's ("The staging", below).

In the code: `CardsEditor` (the panel), `TableEpisode`, `TableProducer`, `TablePrompts`, `CardReading` (the
marks, `<!-- table: draw 2 -->`), `CardDeck`, `CardTable`, `CardFaces` and `TableMedium` (the `table`
medium). A show's block is `ghost: table:`; how many cards an episode draws is the brief's to say and the
producer's to choose (there is no draw range). Episodes live under `user://table/`. The seeds' hash salts
keep their old `tarot-` names, so every episode already made comes out the same.

## Using it

1. New ▾ -> **Cards** makes a show's note; the Truthful Tarot note is in the notes list already
   (`godot --path . -- --table` opens the last show). **Edit** edits its body: the rules and the `## Cards`.
2. **New episode** draws a fresh seed from the OS's randomness and makes nothing. **Generate** makes the
   episode in order: about a minute per picture (back, cloth, room, then each card), the reading written
   card by card as the paintings land. **⟳** on a row makes only that part again; what was made from it is
   cleared and waits for Generate (the shuffle and the script cost nothing and follow on their own).
   **Writer** and **Painter** pick the agents (Claude or Codex for words, Codex for pictures) and, beside
   each, the model: Claude's aliases (Fable, Opus, Sonnet, each the newest of its family; Default is Opus
   for the plan and reading, Sonnet for card designs) or Codex's from the catalog its CLI keeps
   (`~/.codex/models_cache.json`; Default is the author's config), saved as `writer_model` /
   `painter_model`. The painter's model is the agent that asks for a picture; the picture is Codex's image
   tool's either way. Beside each model, the reasoning effort (`writer_effort` / `painter_effort`): Claude's
   `--effort` (low..max), Codex's `model_reasoning_effort` (the model's catalog levels; Default is medium,
   low for designs and the painter), Nova 2 Lite's extended thinking (low..high, billed as output; Default
   off). Bedrock's painter takes none (the picker grays out). **Folder** opens the episode: every prompt
   beside its reply.
3. **Play** reads it at the table (the karaoke line tracks the voice). The voice is the panel's own and is
   saved in the show's frontmatter; **Test** auditions it.
4. **Export** renders the video, named after the episode's title; the episode's folder then holds
   `upload.md`: the title, a description, chapters timed per card from the take, and tags (the show's own
   `tags:` line first). Attach **YouTube** with "+" and tick **Upload after export** and the saved video
   goes up to your channel (see "YouTube"). The Episode card's title and the YouTube card's description and
   tags edit what the producer wrote.
5. Any earlier episode is one pick away in the episode list, exactly as it was made.
6. **Delete…** removes the picked episode after asking: its folder goes to the system trash (restorable);
   exported videos and the other episodes are untouched. The panel moves to the newest episode left.

## The pieces

| file | what it is |
|---|---|
| `src/agents/text_gen.gd` | `TextGen`: who writes words, a registry beside `ImageGen` (`claude`, `codex`). Stateless writers; pictures go with the words. Claude runs with no tools; Codex is told to work from the message alone. |
| `src/agents/agent_jobs.gd` | `AgentJobs`: one queue for every AI run (text and image): limits per kind, lanes (one at a time, in order), timeouts, read-only refusal, a rerun's folder cleared of the last run's output. Polled from `main._process`. |
| `src/media/reading_follower.gd` | `ReadingFollower`: where the voice is in a document (the tablet's sequential word match) and the schedule that puts actions in the voice's rests. |
| `src/table_show/table_episode.gd` | `TableEpisode`: an episode on disk, one file per step, under `user://table/<show>/<seed>/`. A redo keeps what it replaces a version back (`KeptSteps`, next/editing.md). |
| `src/table_show/table_producer.gd` | `TableProducer`: makes whatever is missing, in drawing order. |
| `src/table_show/table_prompts.gd` | `TablePrompts`: which rules each agent is told, and what fills them in. Pure. |
| `rules/table/*.yaml`, `src/data/rules.gd` | The words themselves, one file per role (producer, designer, set_dresser, reader, painter, show), each rule's reason a comment above it; `Rules` reads them (items in order, `when` flags, `insert`, Mustache sections). |
| `src/table/card_reading.gd` | `CardReading`: the reading's marks; one walk gives the voice its text and the table its actions. |
| `src/table_show/card_deck.gd` | `CardDeck`: the show's deck, parsed from its brief's `## Cards` section (none built in: a brief that lists no card leaves each episode's to its producer); the seeded shuffle; true-random seeds. |
| `src/table/card_table.gd` | `CardTable`: what a look may name (title faces in `fonts/cards/`, OFL; frames; the zones things stand in): `sanitize_look`, `sanitize_table`, and the layout a prompt can know ahead (`layout_of`, `headroom`). |
| `src/agents/agent_tools.gd` | `AgentTools`: tools ghost serves an agent while it works: an MCP server (HTTP, JSON) inside the ghost process, a URL per job, every call logged beside the prompt (`tools.jsonl`, `look_NN.jpg`). Claude, Grok and Codex take them (`TextGen.Backend.takes_tools`); Bedrock is one reply. |
| `src/table_show/set_dresser_tools.gd` | `SetDresserTools`: the set dresser's tools (`put`, `remove`, `look`, `set`, `watch`, `title`, `submit`) over a draft table. |
| `src/table_show/table_preview.gd` | `TablePreview`: what those tools show: a thing in a studio on a centimeter grid, the draft on the episode's own table from the show's camera, and the opening (the show's name over that table thrown out of focus). |
| `src/table/effects.gd` | `Effects`: the air (fog, motes, bursts) as data an agent writes (registries, `sanitize`, `build`), posed from show time. Generic; the table names its regions and moments (`CardTable.AIR`, `MOMENTS`). Shaders `effect_fog`, `effect_sprite`, `effect_smoke`. |
| `src/table/lights.gd` | `Lights`: the table's light from a description: sky, sun (or moon) and what the sun falls through (window, blinds, lattice, leaves, fronds, branches, slats, awning, parasol), clouds and birds, lamps out of the shot; `sanitize`, `build`, and the CPU's reckoning of where the sun falls. Shaders `light_screen`, `light_bird`, `light_noise.gdshaderinc`. See "THE LIGHT". |
| `src/table/winds.gd` | `Winds`: the table's one wind (a breeze and planned gusts, its carry in closed form), shared by the light and the air. See "SHADE, WIND AND WHAT IT CARRIES". |
| `src/table/drifts.gd` | `Drifts`: what the wind carries (the air's `drift`): petals, leaves, seeds, each piece's life planned from its own dice (falling, lying, skidding, carried off). Shader `air_drift`. |
| `src/table/tables.gd` | `Tables`: the table itself from a description: its top (shape, edge profile, material, boards, tiles, inlay) and the layers laid on it (fabric, pattern, border, fringe), each surface's relief. Shaders `table_top`, `table_textile`, `table_common.gdshaderinc`, `table_relief.gdshaderinc`, `noise_common.gdshaderinc`. |
| `src/table/props.gd` | `Props`: things from a description: shapes (lathe, loft, tube, coil, extrude...), corners as data, a warp on any part, materials, ornaments. Generic. Shaders `prop`, `prop_glass`, `prop_lens`, `prop_common.gdshaderinc`. |
| `src/table/card_faces.gd` | `CardFaces`: faces, backs and booklet pages, composed in 2D into stopped SubViewports. |
| `src/table/table.gd` | `TableMedium`: the table. Pinned by the mode (`Medium.OWNED`, `Director.medium_override`). |
| `src/table_show/cards_editor.gd` | `CardsEditor extends GenerativeEditor`: the panel. |

## The show document

Frontmatter: `title` is the channel. `ghost: table:` holds the knobs: `show` (the cache key, fixed at the
first episode), `seed`, `writer`, `painter`, and the reader's voice (`voices`, `tab`, `picture`), as a
Generative chapter carries its cast. The knobs are the document's exactly: a show opened with no block
starts from the defaults, never from the show open before it. An export is of the episode open when it was
asked for. The body is the brief: what the show is, its reader, its rules. Every agent gets it verbatim.
The framework (the prompts in code) knows what a card show is; the brief knows what this show is. One show
document makes many episodes.

**The deck is the show's**, and it is data. A `## Cards` section of the brief lists it, one card per list
item: an optional numeral, the name, a colon, what it means (`- XVI. The Tower: ...`), with `###` headings
for suits or groups; an indented line or nested bullet says more about the card above it. The heading is
`Cards` (or `The Cards`), never `Deck`: a section describing the deck's look in bullets would become a deck
of its bullets. `CardDeck.standard_section()` writes the standard 78 out as a template (Truthful Tarot
carries them, editable). Agents are handed the brief with the card list taken out (`CardDeck.strip`); a
card's meaning reaches a writer only when it is drawn. **No agent ever picks a card**: an episode's cards
are a shuffle of the deck from its seed, and a new episode's seed comes from the OS's cryptographic
randomness (`CardDeck.true_seed`) and is kept, so the episode can be made again exactly. The draw writes the
cards themselves into `draw.json`, so an episode keeps what it drew whatever the deck becomes.

**A show that is not a tarot reading**. A `## Cards` section of prose alone, with no card listed, leaves
the deck to each episode's producer (`CardDeck.chooses`): it lists a box in the plan's `deck`, at least
twice the spread and twelve, at most thirty (`TablePrompts.BOX`), and the seed draws from it as from a
listed deck. The producer picks what is in the box, never what comes out; a box the size of the spread is
refused. No cheating holds: a reader is handed cards 1..K, never the rest of the box.

**One set of rules for every show**. Every show gets the same shared context (`rules/table/show.yaml`,
`context`), every producer names the deck's `kind` from the brief ("minor-league baseball card set"), and a
look with no `kind` is a plain "deck". The deck, the suits' elements, the stones and the reader's reasons,
and what a jumper means to the genre are the tarot show's own (`rift/cards/true-tarot.md`), in its Cards and
table sections, which every writer reads. The brief is handed verbatim to every writer; the painter, who
never reads it, learns it through the producer's `kind`, `deck_style` and `card_back`. There is no separate
rule-writing step: it would restate the brief in another agent's words. Gates: `rules_check` (no rules file
names a kind of card, against a control part that does) and `cards_choose_check` (the same context around
any brief; "tarot" only from the brief or the `kind`).

A second such show: `rift/tarot/the-shoebox.md` (a collector opening a different box each episode; every
card invented). The producer selects a physical card size; the face uses the shared frame system, with a
text panel when it is printed on a card.

**The staging**. Every choice is the producer's, in the plan, steered by the brief, and every one is data
the table reads:

- `plan.staging.source` (`TableActions.SOURCES`): `deck` (shuffled in the middle, pushed aside, a jumper
  possible) or `box`: one of the set dresser's things marked `holds_cards` (`TablePrompts.box_rule`; a plain
  box of the deck's stock when it built none), stood where the deck would be (`TablePositions.box_at`, no
  bigger than `CardTable.BOX_MAX`, the spread kept clear of it), the cards filed in it on edge (upright, on
  a long edge, or flat in a shallow tin), as many as the planned collection contains, with each printing's
  actual share and the last few leaning into the gap (`TableMedium._build_file`, a MultiMesh per printing).
  A drawn card waits standing in the file and is pulled straight up past the rim. The reading opens with
  `open` instead of `shuffle`.
- `plan.staging.reversals` (`CardTable.REVERSALS`) and `plan.staging.jumpers`. `none` is the default;
  `read`: a card upside down lies and is read so (its booklet's reversed meaning, the back symmetric under a
  half turn); `righted`: the seed's same cards come out upside down (waiting so on the deck, riding a
  riffle, standing in the box's file or on its piles: `TableBox._waits`) and are turned the right way up in
  the hand a beat after they are up (`TableCardPose.righting`), or on the way down when dealt or swept, then
  read and laid the right way up, the reader told so (`righted`). `jumpers` lets the seed's 30% throw the
  first card out of the shuffle (`TableProducer.jumps`), never out of a box. A plan made before the fields
  reads neither. Gates: cards_check `_ways_up`, `_burst_moments`; table_staging_check `_righted`.
- `plan.staging.text` (`CardTable.TEXTS`): `booklet` (the page beside the card, held up on the left);
  `back` (the card's text printed in a panel over its printing's back, `CardFaces.Face.printed`, the card
  held up alone and turned over long enough to read, `TableMedium._looks`); or `front` (art, name, facts and
  text printed together on the front, `CardFaces.Face.details`, the printing's shared artwork on the back).
  The painter leaves a back's middle plain only for `back` staging.
- `look.series`: the printings a box mixes, each a name and what it prints otherwise (style, back, palette,
  frame); a card's `series` (or its group's name) picks one (`CardTable.look_of`). Each printing in the full
  collection is painted its own back (`image:back:<key>`, `back_<key>.png`), even if none of its cards is
  drawn, and each card is painted in its own printing's hand.
- Each spread position: `comes` - `drawn` (held up), `dealt` (straight to its place, never held up) or
  `swept` (a run of swept positions goes out in one waterfall, overlapping, then each is picked up); `lies`
  `sideways` (a quarter turn); `on` (stacked on the card before, a step behind so its name shows); `then` -
  `tap N`, `untap N` after its passage. `TablePositions.staged` lays the piles (a card alone, a stack, a
  waterfall) in a row or two, checked like every position; a spread asking none of it is the seeded preset.

**The verbs.** `TableActions` holds them all, each with its rest: `open`, `deal`, `fan` (`fan 3-5`, a run),
`show` (a card lying on the table picked up and held as a drawn one is), `tap`, `untap`, `flip`.
`TableProducer.choreography` writes the reading's marks from the plan; `TablePrompts.after` tells each
reader what moves after its words. The table poses each card from its own timeline (`TableMedium._times`
`events`, `_card_pose`): arrive (draw, jumper, deal, fan), show, lay, turn, still a pure function of show
time. No cheating holds for a waterfall: the cards swept out together are revealed together
(`TableEpisode.reveal_of`), so the reader of its first card is handed them all, and no card past them.
Gates: `table_staging_check` (the marks, the layouts over 40 seeds, the choreography, a deck show and a box
show posed, the printings' backs), `table_actions_check` (the rests). `flip` has no producer field yet (a
face-down card's reveal needs its own rule for the reader), and the dealer's tools do not take the new
fields.

**Shoebox branch**: the show guide describes the presentation in ordinary prose; the shared agent context
directs each role to translate it using its own rules and choices. `staging.box_style: shoebox` builds a
larger cardboard box with a lid; the box slides to the center, turns its long side across the table, and
stays there while the lid is lifted off and placed beside it before the first card comes out.
`staging.contents` chooses filed cards, neat piles, or loose flat cards. Up to three simple objects from
`staging.keepsakes` (coin, button, marble, ticket) sit inside and appear with the contents. `look.card_size`
chooses a 70 x 120 mm large card or 63.5 x 88.9 mm trading stock; the mesh and printed face share that
aspect ratio, and all cards in one episode have one size. Positions may set `destination: stack` for a
tight pile on the table or `box` to return a card to the contents, and `comment: none`, `brief`, or
`story`. `staging.pace` sets the default length of spoken comments; `none` writes a silent card step. Each
laid card gets its own small hand offset. The shuffle's resting point wanders a few millimeters between
moves on a seeded path, including cuts, reproducible when scrubbing or exporting. Exercised in
`table_staging_check`; silent and short comments in `cards_choose_check`.
## The episode

| step | who | from |
|---|---|---|
| `plan` | producer (best tier) | brief, title, the seed's dice, earlier episodes (it names their habits first) |
| `draw` | ghost | the show's deck and the seed (shuffle, spread size, jumper) |
| `design:K` | deck designer (fast tier), one card per run | the look, card K, its traditional meaning, how earlier decks pictured card K |
| `image:back/surface/backdrop` | painter | the look |
| `table` | set dresser (best tier), with tools when its writer takes them | the plan, the cloth's painting and the room's (its light must agree with the room), earlier episodes' tables and lights - no card; with tools, also pictures of what it builds, of the table set, of what moves in its light and of the opening with the name in its color |
| `image:card:K` | painter | design K; the back + first + previous card as references |
| `say:intro` | reader (best tier) | the plan - no card; how earlier episodes opened |
| `say:K` | reader | the plan, every passage before, cards 1..K, and card K's painting; how earlier episodes met a card |
| `say:close` | reader | everything, and every card's painting; how earlier episodes closed |
| `script` | ghost | the passages and the marks between them |

**The reader looks at the cards**. A card's passage waits for that card's picture and is sent it (upside
down when the card came up reversed, as the viewer sees it) and is told to talk about what is painted; the
designer's plan for the painting is left out, since the painter may have gone its own way. The close is
sent the whole spread. Painting a card again therefore rewrites its passage and every one after it. The
writer takes pictures as stream-json content blocks (`TextGen.Claude.compose`, at most 768 px on the long
edge), and `prompt.txt` lists which pictures went with the words.

**The cards move between passages, never inside one**. A passage is spoken whole and the table acts in the
silence after it, so a passage that announces the move ("And there. That's the first one.") lands before
the card does. Every reader prompt says when the cards move (`TablePrompts.MOVES`): lead into the next
move, never report it; the acknowledgement belongs to the passage after it. Gate: cards_check
`_moves_after_words`.

The order is not written anywhere: a step starts when its inputs exist (`TableEpisode.needs`). A card's
picture waits for the back and the card before it but is not made from them: redoing one picture leaves
the rest of the deck alone. There is no "shuffle again": the draw is a function of the seed, so a different
deal is a different episode. A reply of the wrong shape (a position as a bare name, keywords as one string)
is reshaped as it lands; a step that fails says why on its row.

**No cheating.** The reader's passages are made in drawing order, each from the passages before it and
`TableProducer._drawn(K)`: cards 1..K, nothing else. Every prompt is kept beside its reply in `jobs/`.
`tests/table_show/cards_check.gd` asserts, two-sided, that no later card's name, booklet or picture reaches
a reader prompt (the builder's and the producer's own, `say_prompt`). A writer with tools could still read
`draw.json` off the disk: Claude runs with none, and Codex (whose `exec` keeps a read-only shell) is told
to work from the message alone and open no file (`TextGen.Codex.ONLY_THIS`). Asking is enough; choosing the
agent matters more than sealing it.

**Variety.** Each seed draws numeric dice (a place on Earth, a year, a hue, an hour, a brainstorm pick),
never word lists, and the table samples its own layout from the seed (camera, deck position, spread layout,
shuffle moves, props, light).

**What the show has already made**. Told only to vary, agents vary the subject and converge on the form
(the same craft-object style, the same running-bit shape, a bracketed twist in every title, the same
opening line). `TableEpisode.archive(show, except)` reads every other episode (plan, the cards drawn with
each design's art and the reader's words, table things, intro, close; newest first, at most 40), and each
role gets the part it decides, cut short (`TablePrompts.clip`/`tail`):
- Producer: the newest `PAST_FULL` (10) in full (title, audience, topic and angle, the reader and running
  bit, spread, deck style, what its cards pictured, stock/ink/accent/frame/face/foil/palette, cloth, room,
  light) and `PAST_LINES` more in a line. It names the show's habits first (`habits` in its reply, kept in
  `plan.json`): the formulas under the subjects, each with how many episodes fell into it, then
  brainstorms and plans outside them. A list alone shows different subjects; naming what they share makes
  the formula visible.
- Designer: how earlier decks pictured the same card (`SAME_CARD`, by name), to picture it another way.
- Set dresser: the things earlier tables held.
- Reader: what the audience has heard at this point of an episode (`HEARD`): the start of earlier intros,
  the first words of earlier card passages (jumpers apart), the end of earlier closes, with the sentences
  the brief gives every episode word for word left out (`TablePrompts.unfixed`) and every card name of the
  deck masked (`mask_cards`, "[card]"), so no card reaches a reader through another episode's words.

`running_bit` is its own plan field (the reader is told "Your running bit"); older plans keep it inside
`reader_mood`, of which the record shows 60 words. The look's and the designer's instructions do not
presume a cast or a period. Gate: cards_check `_archive` (two-sided: an episode alone in its show is told
nothing; no episode is its own history; unmasked, the later card is there). Open, the author's to decide:
the brief's own examples and the year and hour dice still pull toward formulas (producers read them
literally: a period piece of that year, the reader stating that hour).

**The card stock** is the producer's choice: the prompt says what the stock is (the card's own color, round
the picture and behind the name, and the booklet's), that decks are printed on every color, and to choose
the one that sets off the paintings; each earlier episode in its history shows its stock, and "do not
repeat" covers card stocks. `CardTable.sanitize_look` keeps the ink readable on whatever stock lands
(`legible_ink`, WCAG contrast >= `INK_CONTRAST` 3). Not a `bleed` style (the painting to the card's edge,
the name on plates over it): the name, fit to the picture's width, runs off a narrower plate; a plan that
names it is drawn as `line`. The picture's window is one function (`CardFaces.window`). Gate: cards_check
`_card_frame` (every standard name fits the band below the picture in every face).

Borderless: `frame.style` `borderless`, the producer's choice like any frame. The painting is the whole
card, face and back, cut to its corners (no window shape, no ornament: `sanitize_look` drops them). The type
is set on the painting (`CardFaces.type_boxes`): the numeral in a band at the top, the name at the foot, a
front's details in a panel over the lower half, each fit to the width its veil runs. Under each is a veil:
the stock's color across the card, from its nearer edge to just past the type, fading into the painting.
The printer never knows which painting goes under the type, so the veil is planned against the worst
painting there could be (`CardTable.veil_contrast`: a veil over black and over white bound every color it
can come out as), one veil for every card of a deck. The name and numeral read at `TEXT_CONTRAST` 4.5 over
any painting, the details at `PANEL_CONTRAST` 7. `veil_of` moves the veil and the ink apart together (the
veil toward black or white, the ink the other way) only as far as the veil stays at most `VEIL_HEAVIEST` 0.6
(details `PANEL_HEAVIEST` 0.8); a mid-tone deck planned on its stock and ink as they were needs a veil all
but opaque. A light ink stays light (made legible on the stock first), and the veil keeps the stock's hue
(moved one at a time, it goes to black). A keyline of the veil's color rings each letter. The foil keys none
of the type (`CardFaces.bare`). The painter is told the deck is borderless and to keep the subject out of
the bottom sixth (the upper half when details are on the front), never to paint a calm patch. Gates:
cards_check `_borderless` (the bound against random paintings, every random deck planned to the least and
no heavier than allowed; control: stock-only plans need too much veil), tests/table/card_veil_check.gd (GPU:
the drawn ground is the planned sRGB mix, not a linear one, and the letters stand at the contrast over
black, white and a painting of the ink's own color; mutation-tested with a veil 20% light). The booklet is
printed in the card's colors (`CardFaces.page_colors`): the stock as its paper, the ink and accent for its
type, kept readable on it (running text at `TEXT_CONTRAST` 4.5); episodes planned before keep a cream page
until the plan is redone. Gate: cards_check `_card_stock`.

## The table

A static camera from the reader's chair (locked; the panel has no Camera dial), cloth from the episode's
`surface`, its `backdrop` out of focus beyond the far edge. The lamp is low and to one side, so things
throw shadows you can see.

THE SET TABLE. A step of its own, `table` (`table.json`): the set dresser (`TablePrompts.set_dresser`, best
tier) sets the reader's table from the plan, looking at the cloth (it waits for it; a new cloth keeps the
table), knowing no card. It invents the things of the episode's world (a field station's hurricane candle,
rain gauge and calabash of rainwater; a harbor's votive stone anchor, hematite weights and murex shell),
each with its reason, and describes each to be built: parts of shapes (`Props.SHAPES`: lathe profiles,
rounded boxes, balls, crystal points and clusters, rings, tubes along paths, sheets, blooms), in real
centimeters, of named materials (`Props.MATERIALS`, procedural surfaces in `shaders/prop.gdshader`) with
ornament worked in (`Props.ORNAMENTS`: bands, flutes, stars, moons, zigzag, as relief, paint or inlay). It
names each thing's zone (`CardTable.ZONES`), its group (things that stand together) and its turn, and is
told each zone's headroom (`CardTable.headroom`: the frame's top passes low over the far cloth, so the back
holds only short things). The reply is kept as written and made safe at every build (`CardTable.sanitize_table`
over `Props.sanitize`: unknown shapes dropped, numbers clamped, flames capped at `MAX_CANDLES`). Exactly the
look's candle count is asked for; before a table is set (or for an older episode) the look's candles stand
alone (`CardTable.default_table`). The reader is told only that the reader's own things stand there; no
passage depends on them, so setting the table again keeps the reading. Not image-to-3D: too slow,
GPU-bound and too large to ship (TripoSR and SF3D are 1.6+ GB and want a GPU); Claude writes the geometry.

THE SET DRESSER SEES WHAT IT BUILDS. When the writer takes tools (Claude), ghost serves them (`AgentTools`,
MCP over HTTP inside the ghost process) and the set dresser works a draft (`SetDresserTools`):
- `put` things and materials (a name put again replaces it), answered with each thing's real size, parts
  and flames, every part or material the builder could not use and why, a thing taller than its zone can
  show, the lit/other tally against what the look asked, and a picture: each thing on its own tile of a
  centimeter-ruled studio, from the episode camera's angle (`TablePreview.things`);
- `look` at one thing from four sides (front, its right, above, the camera's view);
- `set` the draft on the episode's own table (the show's `TableMedium`, its seed, cloth, room, lights, the
  deck, the cards laid face down in their spread), photographed from the camera's place, with where each
  thing stood, what was made smaller or left off, and which light leads;
- `title`: the color the show's name is printed in at the opening (see "The title screen"), answered with a
  picture of that opening and the contrast it measured behind the name;
- `remove`; `submit`, which writes `jobs/table/submitted.json` for the producer to land whatever the run's
  last words (and sends it to `set` once first, wherever a table can be stood, and asks once for the name's
  color).
30 pictures, 1500 s. Any other writer gets the one-reply prompt (`TablePrompts.set_dresser`'s `looks` = 0).
A picture comes with the question to ask of it (`SetDresserTools.JUDGE_THING`, `JUDGE_TABLE`: say what it
actually shows, then whether a stranger would name it so); without it a model calls a flat disc a lamp
because it named it so. Claude with tools cannot run `--safe-mode`, which drops every MCP server: a tool
job loads no settings instead (`--setting-sources ""`), which sees no CLAUDE.md, memory or skills. Gates
`tests/agents/agent_tools_check.gd`, `tests/table_show/set_dresser_tools_check.gd`.

THE BLUEPRINT. A thing is written where it stands:
- `at` ([x, z] cm from `Tables.ORIGIN`, as a layer's `at`), `turn`, `scale` (`CardTable.sanitize_table`).
  `TableThings.stand_at` stands it exactly there, no jitter, and moves it only for a spot where nothing may
  stand (off the top, `Tables.THING_EDGE` in; where the cards go, `_keep_out`; in another thing,
  `WRITTEN_GAP`; a flame in front of the middle) to the nearest clear spot, out to `CardTable.NUDGE_MOST`
  (15 cm), the move and its reason kept; else left off, in `_unstood`. What the camera makes of it (cut by
  the frame, one thing before another) is the set dresser's to judge. A thing with no `at` (an old table,
  the one-reply writer) is hunted for room by zone, after the written.
- The drawing (`TableBlueprint`, `src/table_show/table_blueprint.gd`, from `TableMedium.blueprint()`):
  black on white, ruled in cm from the middle of the reading; the top, the line a foot stays inside, the
  cloths dashed and named; gray where the camera does not see; the cards' room hatched, the spread's cards,
  the deck; the reader's hands; how tall a thing can be and be seen whole (straight lines at 5-45 cm,
  because the frame's top is a plane through the lens: `CardTable.headroom_at`, closed form, held to the
  step-by-step `headroom`); each thing's foot, numbered as `put` numbers it, a tick to its front, lit ones
  warm, the number red when it is taller than its spot shows, its written spot dashed red when it had to
  move. Names and sizes go in words.
- The tools: `put` makes things (a thing put again keeps its place); `blueprint` places them by name (only
  what changes) and answers with the drawing and, per thing, its spot, foot, height against what the spot
  shows, and every move, refusal or cut; a thing not yet placed waits off the table in every picture and is
  asked about once at submit; `set` says each thing at its spot (`numbers: true` tags them in the picture),
  and moved, taller than its spot, or wholly out of the shot are faults. 60 looks. With tools, the set
  dresser plans the whole table on the blueprint, then verifies through the camera; zones serve the blind
  reply only.
- How full (`TablePrompts.FILLS`): a habit drawn per episode, 3-6, 6-10, 10-16 or 16-24 things besides the
  lit ones; a place crowded by nature may go up to `CardTable.MAX_THINGS` (32). The cost is the agent's
  geometry and looks; building is cheap.
Gates `tests/table/written_place_check.gd` (boot probe), `tests/table_show/set_dresser_tools_check.gd`; look
with `set_dresser_look_probe` (an old table is written where its hunt stood it, then drawn and set,
numbered). Open: things stacked on things (a candle on a book) are still one thing's parts; a real run with
an agent.

THE AIR. The set dresser writes `effects` beside its things; `Effects` builds them:
- Fog is Godot's own volumetric fog, a FogVolume per fog in one of `CardTable.AIR`'s regions ("beyond the
  table", a bank from mid-table back thickening to the far edge; "over the cloth"; "low on the cloth"; "the
  whole room"). Its `density` is how much it hides over the region's `sight` (meters a line of sight
  crosses there), so a layer on the cloth and a bank behind the table read alike; it rolls and drifts as a
  function of show time, billows carved by finer wisps, soft at its sides but never at its floor (fading at
  every face makes a layer on the cloth vanish at the cloth). The lamp and candles scatter in it (their fog
  energy is raised when there is fog): halos and shafts. Unlit fog only dims a bright cloth, which reads as
  nothing: it takes ambient light.
- Motes (pixie, firefly, wisp, ember, dust, snow) are placed on the CPU each frame, a pure function of show
  time: a home on screen along a line of sight, in front of the table (the camera sees only below the
  table's plane a meter past it); a wander measured as a share of the picture at its own depth; darts;
  visits that leave sideways and up out of frame and come back (off-screen is fine, never a bounce at the
  frame's edge); a soft floor, which over the table or a thing on it is that thing's top, falling away round
  it as a gentle dome, so a mote is lifted over what stands, never through it. Lit motes carry a tiny
  OmniLight, so the fog glows in their color round them; the light is nearly all the fog's (a surface sees
  1/15), and a lit mote keeps 4 cm off what it flies over. Flies are dark specks on a planned flight: zips
  with sharp turns, hovers of a fraction of a second, a short drift, out of the picture and back in
  elsewhere; a zip smears as a fast shutter would, a short dark dash. Two in five leavings are off into the
  room past the table (up the picture and shrinking); a fly blurs as the room is blurred, so it fades out of
  sight; glows shrink to a point and the fog takes them. Each look's size and brightness stay in its own
  range (a pixie 3 mm, 1.5-8).
- Bursts (sparks, glitter, embers, flames, smoke, stars) mark a moment (`CardTable.MOMENTS`: shuffle,
  jumper, reveal, pirouette, lay, close), read off the schedule by `TableMedium._air_moments` with the
  emitter's path from the table's own poses (the jumper's flight, the held card twirling; `_looks` is what
  `_turn_of` reads too). Particles are born on the CPU when a moment moves (most at its start, on the
  card's edge or at a point), flown on the GPU in closed form (drag, gravity), so any frame can be drawn
  alone. Tabletop scale: a few centimeters to a couple of hands.
The set dresser sees it: `set` shows the air at a moment some way in; `watch` photographs one effect four
times (a burst just after its staged moment, fog and motes 3 s apart). The show's taste is in the brief's
"The table and its air". Gates `tests/table/effects_check.gd`, `tests/table_show/set_dresser_tools_check.gd`;
look with `tests/table/air_look_probe.gd` on a copy of an episode.

THE TABLE ITSELF. The set dresser writes `top` and `layers` beside its things (`Tables`, `src/table/tables.gd`):
- The top: rect (rounded corners), round, oval or a regular polygon, a scalloped rim if it likes; 1.5-9 cm
  thick; its edge cut to a profile (square, eased, bevel, bullnose, ogee, bead) as real geometry (the far
  edge is all of the table's side the camera sees); made of one of the table's materials (boards with
  staggered ends and cut seams, tiles in grout, a stone slab, metal, lacquer worn at the edge, leather, a
  baize) or of the painting itself, with a pattern inlaid in it (marquetry, parquetry) and a band inlaid
  along its edge.
- The layers, bottom first, at most 4: each a fabric (linen, cotton, wool, felt, velvet, silk, brocade,
  lace, burlap), a pattern (stripes, checks, plaid, diamonds, dots, a generative medallion, dyed clouds,
  ikat, or the painting), a border along its hem, a fringe on its ends; an outline of its own placed by `at`
  and `turn` (45 lays a square as a diamond) or the top's own outline grown by a `drop` (a tablecloth).
  Wherever a layer runs past the top's edge it hangs over it (`Tables._drape`): rolled over where the top's
  face ends, straight down, folds deepening as it falls, outward only. Rows of points follow the top's
  outline through the roll, each a hair off its row (concentric rows are all but co-circular and Godot's
  Delaunay is slow on them).
- The painting goes wherever the set dresser lays it (the top, the cloth, a runner, a diamond), its pixels
  square there (`CardTable.cloth_crop`). No `top` and no `layers` is the old table: a 190 x 85 cm board
  table with the painting as a 120 x 72 cm cloth exactly where the old cloth lay; `layers: []` is a bare top.
- Depth (the relief, `table_common.gdshaderinc`): every surface has a height field below it, its own
  (threads, grain, pebble, seams and grout) and what the agent asks for (`relief`: raised or sunk figures,
  quilted, tufted, the painting's own detail). Godot 4 has no tessellation, and lifting the geometry would
  lift the cards off the cloth or sink them into it, so the field is never above the surface (the cards and
  things rest on its highest points) and is seen three ways: a normal from its own slope at every pixel
  (finite differences of the field, in a tangent frame from how the cloth's flat space crosses the screen),
  parallax occlusion (6-22 steps by the angle, one refinement) and its shade (ambient occlusion, a little
  darker albedo). The painting's depth is its detail (its lightness less its lightness blurred 3.5 mips), so
  threads and grain stand up and broad light and dark do not. The drape and the edge profile are real
  geometry. A quilt's section rises all the way from the stitch.
- The top holds the cards: the deck, every preset spread, the shuffle and the wash lie in `Tables.HOLDS`
  (measured over 300 layouts in `tables_check`); a top that does not hold it 2 cm in from its edge is
  grown, its proportions kept (a round table comes out at least about 1.18 m across). Cards given positions
  are refused off the top (`TablePositions.given(..., top)`, then the preset), a card thrown in a wash lands
  only on it, and things stand on the top 3.5 cm in from its edge, within the old cloth's stretch (the width
  the camera sees) and further back only where a deep top reaches further (`_stand`); on the old table they
  stand exactly where they stood.
- The light reads what lies uppermost: the heat cap's lightness grid (`TableMedium.LUM_RECT`, 4 cm cells
  over the table the camera can see) is whatever is on top at each cell (`Tables.surface_lum`): the
  painting's pixels, a pattern's colors, the top's material, the floor.
- The set dresser is told the vocabulary (`Tables.describe`), that the painting must be given a place, about
  depth, and the earlier episodes' tables (`TableEpisode.archive` -> `furniture`); `put` takes `top` and
  `layers` (answered with the table in words and whatever had to change); `remove` takes layers; `overhead`
  photographs the table from straight above with the camera's view outlined; `set` says the table in a
  line. 36 pictures, 1800 s.
Gate `tests/table/tables_check.gd`; look with `set_dresser_look_probe --spec` (a spec with `top`/`layers` is
put first and seen from above).

THE PAINTING'S DEPTH, PAINTED. A step of its own, `image:height` (`height.png`), listed only once the table
lays the painting where its depth is read (as a layer or as the top, its relief `painting` or its own:
`TableEpisode.wants_height`, `Tables.wants_height`); it waits for the table and is made from the painting (a
new cloth clears it, a new table does not). The painter is handed the painting and asked for the same image
redrawn as gray height, every edge on its edge (`TablePrompts.height_image`). An image model may move, zoom
or invent what it redraws, so the map is measured before it is used (`Tables.height_fit`,
`TableProducer._land_height`): both images' structure (the size of their gradients, blind to which way round
the gray runs) at 96 px across, correlated at every shift up to 4 px; the best is kept in `height.json` with
its shift, and under 0.35 the map is removed and the step fails (retried once), the painting's own detail
standing in. The map only deepens the table: an episode is complete without it (`TableEpisode.complete`),
the Table row counts it only while it is made or when it failed, and an episode made before gets one from ⟳
"Paint the cloth's depth again". The shaders read it in place of that detail (its fine relief whole, its
broad rise and fall at half), and a painted surface whose relief is its own takes it too. Real runs score
0.75 to 0.83 unshifted (about 55 s each); an unrelated picture scores 0.18. Not checked: alignment finer
than 96 px, and other painters (Bedrock's take a reference as a style and will likely be refused). Probes
take `--root <dir>` (`episode_probe`, `set_dresser_look_probe`) to work on a copy of an episode.

THE LIGHT. The set dresser writes `light` beside its things (`Lights`, `src/table/lights.gd`;
`CardTable.sanitize_table` -> `light`, `{}` when it wrote none), so a table can be lit as the plan says
(noon sun through an awning, low afternoon sun through tall windows, open-sky morning with no flame):
- The sky: an ambient light and a share of it from above (a light with no shadow, so things are modeled from
  the top as an open sky models them), its color and strength.
- The sun, or the moon: a DirectionalLight3D from a direction named round the table (front = from behind
  the reader, right, back = from across the table toward the camera, left, the four between, or degrees) at
  a height in degrees. Soft by its shadow filter's blur, not by PCSS: a sun's PCSS searches as far as its
  farthest caster (a wall a meter and more up its ray), and the blocker search then misses a stone's small
  shadow.
- What it falls through, at most 3: a window (panes, bars), blinds, a lattice (grid, diamonds, hexes,
  circles, stars), each in a wall standing past everything on the set, on the sun's side, its patch of sun
  landing where it is aimed (`at`); or leaves, fronds, branches, slats, an awning (the share of the table it
  shades is asked and its edge solved to it; straight or scalloped; its canvas tints the light under it), a
  parasol overhead. Shadow-only geometry up the sun's ray on `Lights.SCREEN_LAYER`, which no other light
  casts with; holes cut by `discard` in `shaders/light_screen.gdshader`, posed from show time (leaves stir,
  blinds sway, an awning's edge ripples). In fog the sun's shafts follow them. A sun through a wall stands
  no higher than 65 degrees (`WALL_SUN`).
- Clouds: two octaves of noise drifting past the sun; a cloud over it dims the sun, softens its shadows (a
  thin one) and gives a quarter of what it holds back to the sky (`CLOUD_GLOW`), so a thick one leaves the
  table about a stop darker, its shadows gone; the room's picture dims alike (`shade` in
  `table_room.gdshader`). Not a shadow cast by a projector or a dithered caster: Godot 4.7 refuses a
  ViewportTexture as a light's projector, a DirectionalLight3D ignores a projector, and a dithered caster
  averaged by the shadow filter reads as mottle. A real cloud's edge is tens of meters wide, so at a table's
  scale it is a dimming over seconds, not a line across the cloth; four octaves would let wisps cross the
  sun in under a second, a flicker (lights_check, two-sided).
- Birds: crossings at about the asked interval, each over the table, a flock flying together, a hawk
  circling so its shadow wheels back over the table; level quads (a level bird throws its true shape on a
  level table), wings beating or gliding by look, a little smeared along the way (`light_bird.gdshader`).
  At a pigeon's real 12 m/s its shadow is over the table for two frames, so `speed` runs from a third of the
  bird's real speed (0) to all of it (1).
- Lamps out of the shot, at most 4, 2 casting: candles, a torch, a fire, a lantern, a lamp, a hanging lamp,
  fluorescent tubes, neon, a screen's glow, a street lamp, headlights passing, a lighthouse's beam,
  lightning, each by direction, distance and height, moved up out of the shot when the camera would see it
  (`Lights.lamp_place`, `CardTable.in_shot`), flickering its own way as a pure function of show time.
- Shadows out of the shot (`shadows`, at most 4): things the camera never sees, built of silhouettes in
  centimeters up to six meters (`Lights.CASTER_SHAPES`: box, cylinder, ball, ring, tube along a path, sheet,
  grille; grouped two deep and copied round the upright or along a step), shadow-only on
  `Lights.CASTER_LAYER`, which every light that casts casts with. Not [Props]: those clamp to 60 cm and are
  surfaces. Aimed by where the middle of the shadow falls (`shadow`, at `height`) and set up the ray of the
  light that throws it (the sun, or a lamp that casts, `by`), then raised along that same ray, the shadow
  staying put, until it is clear of the table and out of the shot (`Lights.caster_place`). Round a lamp
  (`around`) its own origin is the lamp's flame: what hangs below it throws its shadow down. It is still, or
  swings (a pendulum stepped at 120 Hz from show time 0 and kept every 30th of a second, pulled back by the
  sine of its angle and pushed by a wind's lean, `Lights.swing_at`: any time is the same swing whatever
  order it is asked in, and a rope swings at its length's period, 1.43 s at half a meter, 2.13 s at one,
  against 1.42 and 2.01 by theory), or spins (a fan's blades), or ripples (a sheet's vertices waved in
  `shaders/light_caster.gdshader`, more the further they hang from its top). `put` reports what each shadow
  covers, part by part, where on the table, and any raise; `watch` takes a moving one by name.
- The exposure (`Lights.Rig.fit`): the sun and the sky are brought down together until the palest thing in
  the light (the 97th percentile of the cloth the camera sees, or the card stock) takes no more than
  `SUN_HEAT`, so the day keeps its contrast (sun to shade four or five to one on a clear day). A lamp is
  held to `LAMP_HEAT` where its light is strongest.
- Who leads: a sun or a lamp lighting the cards at least `LEAD_MIN` leads, and every candle burns as a
  fill; with nothing reaching the cards and no candle to lead, the old lamp hangs over the table
  (`TableMedium.LAMP_FALLBACK`). A table with no `light` is lit as before: the lamp, the fill, the room's
  out-of-shot candles. The room's picture casts no shadow (a low sun behind the table would throw it over
  the cards).
- The set dresser is told the vocabulary (`Lights.describe`), to build the plan's light and make it agree
  with the room (whose painting comes with its prompt; the table step waits for it, softly: a new room
  keeps the table) and earlier episodes' lights (`TableEpisode.archive` -> `light`). `put` takes `light`
  part by part (a part replaces that part; screens, lamps and shadows by name; null and `[]` take away) and
  answers with where the sun falls (how much of the table the camera sees, and of where the cards lie) by
  the CPU's own reckoning (`Lights._pattern`, line for line the shader's, on integer-hashed noise both
  reckon alike; `light_screen_check` holds them together at 99% and more), how the weather runs in the
  first ten minutes, and any lamp moved; `set` photographs the light as it mostly is (the sun out, no bird
  crossing) and names what leads; `watch` takes `clouds`, `birds`, a stirring screen or a lamp and finds the
  moment (a cloud's passing, a bird over sunlit table, a sign's stutter, a strike). 40 pictures, 2100 s.
  The producer's `light.kind` asks for indoors or out, the hour, the weather and what the sun comes
  through, and the room's painter is told it.
Looked at on real episodes with `set_dresser_look_probe --light` (windows, awnings, moonlight through
blinds, one candle and a street lamp, a gull's shadow, roof beams, a swinging bell rope, a chandelier's
spokes, a fan turning). Gates `tests/table/lights_check.gd`, `tests/table/table_light_check.gd` (boot),
`tests/table/light_screen_check.gd` (GPU), set_dresser_tools_check `_light`, cards_check (archive, the table
step).

SHADE, WIND AND WHAT IT CARRIES:
- A soft screen (`soft` 0-1 on anything the sun falls through; leaves 0.5, fronds 0.4, branches 0.35 when
  not said, the rest crisp): the sun is cast `Lights.SOFT_SUNS` (3) times from the one place, each a third
  of its light, each with a screen layer of its own (`SCREEN_LAYERS`, `SCREEN_MASK`); a soft screen is drawn
  once on each, its shade grown a step on one and shrunk a step on another (`grow` in the shader,
  `Lights.grow_of`), so its edge falls in thirds and the filter blurs them into a gradient. Every near
  thing's shadow stays crisp: the three suns are one direction. Not a sun's PCSS, jittered sun directions
  (triple copies of a window's bars) or a dithered caster (mottle). The CPU's reckoning follows
  (`Lights.sun_share`, `coverage`).
- The sky's shadow (`sky.shadows` 0-1, `from`, `height`): the diffuse shade of a big soft light is ambient
  occlusion: more of the sky fills from everywhere (`SKY_TOP_SHADOWED`) and the stage's SSAO (`SKY_REACH`,
  `SKY_AO`) darkens the fill in folds and where things meet the cloth; off again when the rig is released.
  Not a PCSS shadow from the light above (no pool shows, and it prints a faint moire on the cloth).
- The wind (`light.wind`: from, strength, gusts, every; `src/table/winds.gd`, `Winds`): a breeze of slow
  sines and gusts planned over the horizon from the seed (each a raised cosine, quick to rise, slow to
  fall), so how far the air has carried a thing is closed form (`Winds.carried`), never stepped. One plan
  per table (`TableMedium._wind`), shared: a gust stirs the screens harder, swings what hangs, snaps what
  flutters, and carries what drifts. A table that wrote no wind keeps its old light; what drifts there
  falls through a faint breath (`Winds.STILL`).
- The wind reaches everything in the air, but only a written wind moves it (`Winds.blows`): a room with its
  windows shut has still air, which moves no flame or mote. The air is turbulent (eddies of 50 and 8 cm
  carried past on it, `Winds.eddy`, `air_at`). A flame leans as tan(tilt) = draft / draw, its draw
  sqrt(g x its height), never past 69 degrees, and gutters (dimmer, shorter) past 1.8 to 5 draws
  (`Winds.flame`); a table candle's sprite tips on its wick and its light leans with it. A flame inside
  glass, a chimney or a lantern gets a tenth of the draft (`Props.open_to_air`). Lamps out of the shot
  (`Lights.flame_in_wind`): candles and torches lean, a lantern hardly, a fire is fanned brighter. Motes:
  `airspeed` 0 (dust, snow, embers) rides the air round a stretch of it the picture's size at its depth
  (`Effects._stretch`); a flier (pixie 1.2 m/s, firefly 0.5, wisp 0.25, fly 1.8) holds its place, is
  carried off by what is more and flies home at its `back` (`Winds.pushed`, pure). Bursts: the GPU carries
  each particle by the air's run since its birth less the lag still to make up (`air_carried`, `air_vel`,
  `Effects.particle_xform`). Fog rolls with the wind in place of its own `drift`. Gate:
  `tests/table/wind_reach_check.gd`. Open: a tablecloth's hanging edge in a gust; the cards stay put (a 2 g
  card lifts at about 2 m/s, and the reading must stay readable).
- What drifts (`effects` kind `drift`; `src/table/drifts.gd`, `Drifts`, `shaders/air_drift.gdshader`):
  petals, rose petals, leaves, green leaves, seeds, spinners, feathers, falling from above or blown in from
  the wind's side; no whole flowers. Rare: `every` seconds between one coming loose (60 when left out,
  6-600), `shake` how many a gust at its strongest shakes loose (1, 0-6); `settle`, `grip` (the gust that
  lifts one lying), `lying` at the start. Real geometry (a cupped quad cut to its outline, lit, glowing
  through, casting, blurred by the lens). Each piece lives a planned life on dice of its own: falls with the
  air in one of its look's ways (`ways`: flat, fluttering, tumbling, twirling), a gust turns it over, it
  turns flat as it lands, lies trembling, and each gust past its grip skids it across the cloth or, past
  the edge, carries it off. A fall that would pass through a thing or the table's side is thrown again from
  elsewhere. Lives are filed in ten-second bins and planned only as far as asked. Never on or under the
  cards: the table's `cover` (`TableMedium._cover_at`) says where the deck and every card lying on the cloth
  are at a time; a piece never comes down or skids there, and a card laid over one later pins it. `put`
  reports how many gusts lift what lies; `watch` takes a drift through the strongest gust ahead, and `wind`
  through its strongest gust.
Gates: `tests/table/drifts_check.gd` (closed-form carry against a summed one, purity in any order, never
through a thing, gusts lift and grip 1 holds, never on or under the cards, and more), lights_check `_shade`,
light_screen_check (a grown copy in a gust, GPU).

BUILT IN THE ENGINE (`src/table/props.gd`, `Props.build`): meshes in meters, base on y = 0, each part's
surface laid out for its own girth and height so a motif keeps its shape. A candle's wax part carries a
`wick`: the flame is lit at its top, melted into a pool, and `drips` run down it. Seen-through material is
glass for a vessel (`prop_glass`, a flame inside it shows) and a lens for a solid thing (`prop_lens`,
screen refraction: a crystal ball turns the cloth over); a clear crystal (clarity >= `Props.CLEAR`) is drawn
as glass, as opaque it reads as a pearl. A flame lights everything but its own thing, whose wax glows with
the flicker instead (`flame` uniform). A reflection probe catches the table once it is set, and only the
things reflect it (`reflection_mask`): metal with nothing to reflect reads as paint. Look at a description
alone with `tests/table/props_look_probe.gd`.

STONES. A `geode` shape: a rough half rock, its hollow lined with points growing in (its rock plain stone
unless `base`). Strewn copies: `scatter`ed ones never touch (a crowded handful spreads wider rather than
pass through itself) and a `heap` settles each copy into the lowest of a few spots, on the floor or resting
on the copies under it, so the floor fills before the heap rises; a `ring` can be an `arc`. A part's
`material` can be a list its copies take in turn (a mesh per material). The play of light (`Props.PLAYS`, a
material's `play`), all of it lit by the engine, never emitted: silk (tiger's eye: Godot's own anisotropy,
its frame turned across the fibers and rough enough to be broad), flash (labradorite: streaky patches
tipped as they lie, colored like metal), fire (opal), glitter (goldstone: tiny tipped flakes that only the
flames light), rainbow (aura quartz, paua, bismuth: a thin film in what it reflects, its hues near the
body's own; a pale body keeps its own light), glow (moonstone); and `rings` bend a crystal's banding or a
stone's veins round the middle of each copy (agate, malachite): every vertex carries its copy's middle and
number (`CUSTOM0`, `Tris.placed`). Lumpy balls have broad lumps (a fine second octave alone crimps a small
stone). Shader traps: `bump()` must not normalize a zero vector (a NaN reaches the reflection probe and
blacks out everything that reflects it), and a derivative in a branch some pixels skip is undefined, so it
is called on every pixel. A flag written "yes" is read by `Props._flag`. The set dresser is told that many
readers keep stones, set on the cloth or heaped in a dish. Gate: cards_check `_stones`.

CANDLES OF EVERY FORM, AND GROUPS. The model writes data, never code. Wicks as data: `wicks` 2-6 set round a
candle's top (three make a triangle) or `wicks` [[x, z], ...] placed, each standing on the melted pool as
deep as the pool is there. One light a lit thing (`TableMedium._light_flames`): a candelabra's tapers or a
pillar's three wicks light the room as one light from among them, as bright as all its flames together
(then capped by the cloth like any other), so a candle costs one shadow however many flames it has; every
flame still flickers on its own dice and the light follows their mean. `_lights` holds one entry per lit
thing with its `flames`; the cap is `CardTable.MAX_CANDLES` lit things and `MAX_FLAMES` flames on one, and
the set dresser is told "Exactly N lit things" (the plan's `candles`) plus a nudge toward every form
(tapers, multi-wick pillars, tea lights, votives, a pricket, an oil lamp, a candelabra). Groups
(`{"parts": [...], "at", "turn", "copies"}`): a part that is parts, placed and repeated as one (arm, cup
and taper written once and copied round a ring), nested `Props.MAX_DEPTH` deep, every part in every group
counted toward `MAX_PARTS` (16), and `MAX_INSTANCES` parts made in all. Extrude: an outline (polygon, star,
circle, rect, heart, or its own `points` going in and out) raised straight up with `taper`, `bevel` and a
`wall` that makes it a tray. Gate: cards_check `_candles`; table_place_check counts lights and flames apart
(the pair of pillars is one light, two flames). A tall candelabra fits only where the frame has headroom
(the set dresser is told each zone's).

FREE FORM: LOFTS, COILS, CORNERS AND WARPS. The agents draw their own curves (a lathe's profile, a tube's
path, an extrude's and a sheet's outline), so the vocabulary grows by more of that, never raw vertices
(typed by hand they come back inside out and holed, and skip the foot and the heaps every built shape
feeds). A `smooth` profile keeps a flat base and a flat top flat (a uniform Catmull-Rom through every point
sags the base below the cloth and domes the top), the curve is centripetal (no overshoot between points far
apart and close together) and its ends run on straight. Corners as data: any point of a profile or a path
can carry one more number, its corner's rounding in centimeters (0 a crisp corner in a smooth curve: a foot,
a rim, the seat of a lid; r an arc that far round: a pipe's elbow), `Props._curve` for all of them. A crisp
kink in a rod is mitered (`_sweep`: the ring laid halfway between the two directions and stretched across
it). A tube takes a `wall` (a pipe, a straw, an open spout). The loft: sections (any outline, `size`,
`scale`, `turn`, `shift`, `at`) blended along a path or straight up (a spout wide at the body, a snake
plant's twisting blade with outline `lens`, an aloe, a horn, a spoon's handle); the same outline keeps its
points one for one, different ones are walked round from the same side. The coil: incense coils, springs, a
tendril. Outlines `lens` and `drop` serve extrudes and sections. The warp, on any part: `scale`, `taper`,
`twist`, `lean`, `bend` (toward `bend_to`, as a rod round a drum), `wobble` (a field of where a point was,
so crisp seams move together and never open); normals turned by the warp's measured slope; a part warped
past scaling is built with points 5 mm apart (`WARP_STEP`). The set dresser is told how parts meet (a spout
or handle starts inside the body) and that living plants are things the parts make; the show's guide asks
for them. Gate `tests/table/props_check.gd`; cards_check builds a thing of every shape.

WHERE A THING STANDS IS FOUND (`_place_things`, `_stand`), for a thing with no `at`: groups biggest first, a
group's tallest nearest its zone's middle, the rest round it (the shorter toward the reader); on the cloth
(on the wood by the rim it reads as falling off), clear of everywhere the cards go (`_keep_out`), clear of
what stands (`THING_GAP`, `GROUP_GAP` within a group), wholly in the shot, and no group in front of another
in the picture (within a group a little in front at most: one seen through another reads as a stack). A lit
thing stands only behind the middle (a candle in front of the cards becomes the key and blows out the held
card) and by dark cloth. A low thing may lie nearer the reader. A thing with no room is tried smaller, then
left off (logged).

NOTHING PASSES THROUGH WHAT STANDS: each thing's foot (its outline up to `Props.FOOT_H`) is an obstacle in
the planned wash. Every card moves from where it was to where the step puts it a few millimeters at a time
and is pushed back out of any foot it runs into, away from its middle (`_card_clear`, `_push_out` by
separating axes along that direction), so it slides along it and never jumps through; a card is flung out
only by a way clear of everything (`_path_clear`). The wash is planned once, a pure function of the seed
(collision in the engine's physics would not be). Gate: `table_place_check` (no card crosses a foot over 40
seeds; the same washes let through must).

CANDLES TOGETHER LIGHT THE CLOTH TOGETHER: the heat cap is on the cloth's hottest spot under all the flames
at once (`_heat_field` per flame, summed; every flame reaching the hottest cell dimmed).

Not painted objects: a photograph of one thing cut out of its background brings its own camera, light and
grade, and a flat card can neither take the candlelight nor cast a shadow.

FLAMES FLICKER APART. Each flame has its own tempo, steadiness and drafts: mostly a steady burn, and now and
then a draft gutters it for a second or two, a pure function of show time, so a render and a scrub see the
same flame. The light leans with its flame, so the shadows breathe. Room candles out of shot: two or three
shadowless, flickering lights behind the camera and off to the sides, a warm fill on the cloth and on the
card held up to the lens. Gate: `tests/table/table_place_check.gd`.

EVERY LIGHT THROWS ITS OWN SHADOW. Every candle and the lamp cast, so a thing has a shadow for each light
near it, each turned from its own; where two fall together the shadow is darker. The key (the candle
nearest the middle that its cloth can take, else the lamp) is the brightest, so the deck's long shadow
toward the reader leads. The lamp's `shadow_bias` is 0.005 and `shadow_normal_bias` 0.15 (the candles'
0.02 / 0.4): Godot's defaults are made for rooms and at the lamp's distance come to millimeters, more than
a bowl's floor stands off the cloth. A `light_size` on the lamp throws a white glare off a geode's rim, so
its shadows soften by blur alone. The room's out-of-shot candles stay shadowless (faint fills, six shadow
passes each). Try a lamp setting with `props_look_probe --lamp 1 --key 0 --lamp-shadow B,N,S`. No candle is
brighter than its cloth allows: a candle's light times the cloth's hottest spot near it (lightness over the
flame's falloff, height over distance squared) is capped (`HEAT`), and only a candle whose cloth can take
`KEY_MIN` may be the key; on an all-pale cloth the lamp is. The cloth has relief: its picture's luminance is
its height, turned into a normal map natively (`Image.bump_map_to_normal_map`, `RELIEF`), so the low light
rakes the weave; the table wood too.

THE READER MARKS ITS DELIVERY: `<!-- delivery: quicker, brighter -->` on its own line, for the rest of that
paragraph, and `<!-- hesitation -->` for a real stop. Not the Tone presets (they sound like a different
speaker); the marks are subtle shifts: three axes, pace (4% a step), brightness (a third of a semitone on
the host's formant-locked arc path, a little effort and melody) and pauses (a fifth), each word a step
(`DELIVERY_WORDS`, intents as small combinations; a fourth axis, volume, louder / softer, effort alone, and
a wider pause step, x1.3), two steps at most, and eased: each sentence goes half way from the last one's
delivery (`_ease_leans`), in and back out. The host takes `lean_semis` / `lean_effort` in `_discourse_plan`
(`hosts/voice/test_lean.py`). A script mark like any other (`ScriptMarks` "delivery"), so a Generative
chapter can carry it too.

MORE THAN ONE VOICE. Who a show's other voices are and when they speak is the brief's (Truthful Tarot's
"## The familiar"). The framework only hands lines over: the show's voices are its document's `voices:`
(`CardsEditor._spec` -> `voices`), the reader prompt names the others and teaches the Generative panel's own
cue, `<!-- speaker: Familiar -->` on a line of its own and `<!-- speaker: Narrator -->` to take it back
(`TablePrompts.voices_rule`; a show with one voice is told nothing); a reply's cues are held to the show's
names (`TableProducer.own_voices`: any spelling of one, anyone else's cue dropped with its words kept);
`CardReading` keeps the cues for the voice (an inline one put on its own line) and opens every passage in
the reader's voice, after the table's rest so the rest stays on a word. The Turn row (the pause at a
handover) is in the panel. Earlier episodes' lines keep who said them (`heard`: "(Familiar:)"). Gates:
cards_check `_familiar`, multi_voice_check `_check_cards_familiar` (two-sided). Each voice has its own
colors: subtitle words carry their speaker, and `Subtitles.voice_hue` gives the first voice to speak the
whole rainbow and each after it a band of its own (`VOICE_BANDS`), swept there and back by the same flowing
phase; the book's highlight too.

THE ROOM IS SEEN FROM THE READER'S EYE. The camera looks down 34-42 degrees through a 42-degree lens, so the
frame's top is 13-21 degrees below eye level: all it sees past the table is a thin band below the horizon
(in a real room, the floor and the feet of things). Not a skewed picture and not a painter asked for the
camera's own tilt (image models steer poorly to an angle): the backdrop is asked for as photograph models
make most reliably, level at a seated eye (110 cm), horizon across the exact middle, a 20 mm lens
(`CardTable.BACKDROP_LENS`), its lower third carrying the place; and projected from the camera's eye
(`_place_backdrop`): an upright plane straight ahead, its middle at the eye's height, 36 x 24 times its
reach over the lens, so every pixel lies in the direction it was seen from and Godot's own perspective does
the rest. The view it was asked for is kept beside it (`backdrop.json`, written as the job is submitted); a
picture made before has none, holds nothing below its horizon, and keeps the old placement until its
backdrop step is made again. Gates: table_place_check (two-sided), cards_check `_room_prompt`.

THE INTRO IS OUT OF FOCUS: the channel's name alone (no episode title, which is the video's, on the
platform) over the table thrown far out of focus, and the focus pulls as the shuffle starts (`_tick_focus`,
`_lens`): the wide blur lifts over the first half of the pull, and the lens carries on near to far. See "The
title screen". Otherwise there is no depth of field: a far blur behind the table draws a band along its far
edge where the sharp table and the blurred room meet, so the room's picture is drawn through its own lens
blur (`shaders/table_room.gdshader`, a disc at full resolution; shrunk to an eighth and back, the strip the
camera sees past the table is blocks). The stage runs 4x multisampling and a 4096 shadow atlas with the key
light's quadrant whole, given back when the table leaves it. The camera is locked off.

THE SHUFFLE IS RUNS WITH SPARSE ACTIVITY: several riffles, a string of cuts, a few overhand passes (one kind
at one tempo), then nothing for a while (median about 3 s), in the middle of the table; before the first card
the deck is squared and pushed to its side (`CardReading.PUSH`, which the first draw's rest includes). A
wash is rare, once at most, and a planned simulation: the deck flattened under the palm and spread wide, two
flat palms working it for most of half a minute, then six to eight sweeps round the pile over about 7 s,
each taking a few cards, landing squared on the pile, so the end is a light tidy. The order is decided when
two cards meet (the one sliding in on top) and held while they touch, so it changes through the wash and
never through a card.

Cards rest on one another: every card (deck, spread or pile), from the bottom of the order up, is a rigid
card at the lowest it can lie: the plane over the cloth under its corners and over the faces of the cards
under it wherever they cross it (`Geometry2D.intersect_polygons`), lowest at its middle
(`TableMedium._rest_on`). The rest stays the flat plane; the mesh is lifted by however much its tilted
corners would sink (a shallow tilt is not lifted). A card tips on a card at one end and on the cloth at the
other, over the deck's edge as it slides off, up onto the pile as it is swept in. A wash the first card would
cut short is replanned to fit.

CALM, AND NEVER THROUGH A CARD: a spread card is a real card's thickness (`WASH_T` 0.3 mm, 0.1 mm between
cards; a deck slot stands for three); the deck flattens to it under the palm (`WASH_FLATTEN`) and the pile
stays flat until squared; a card is rested at the frame's own moment (`_wash_rest_at`), in the order of the
step that ends the moment; a card climbs one card, not a heap (one lying two or more above it runs in
under), and a loose card three or more up slumps off (`_wash_slump`); a sweep lays each card squared on the
pile; and a meeting is a nudge (`WASH_KNOCK` 0.16, spin capped at 3.5 rad/s). Held over every frame: no
crossing, no card dipping into another or the cloth, no swap; mixing cards tip under 2 degrees 99% of the
time, 6 at most.

THROWN OUT OF THE SPREAD: a meeting faster than `EJECT_SPEED` may throw the card run into a hop along the
blow onto the cloth and wholly in the picture, its way clear of what stands (`_eject`, `_flight_xf`,
`_flight_clear`). About one a wash, two at most, none late in the mixing, and face down: a deck card's face
is never painted, so only a drawn card may come down face up, the jumper. When the first card is a jumper and
the deck is being washed as its moment comes, the wash runs on into it (`_jumper_plan`): the mixing stops and
a hard blow throws it, face up, onto the fewest cards it can; the drawn card's own mesh takes the wash card's
place as it leaves, and it lies there until it is picked up and shown as from a riffle; then the hands
gather the rest, one card short (`_wash_jump`, `_wash_jump_xf`). Half the episodes whose first card is a
jumper hold their wash back for it (`_jumper_wash`: it begins `JUMPER_WASH_LEAD` before the jumper is
reckoned to come and runs `JUMPER_WASH_SLACK` past it); the rest riffle, and either way a wash under way
when the jumper comes throws it.

The hands sweep: a palm comes down where the cards are and mostly scrubs (passes of 20-40 cm back and forth
across the spread, its line turning and drifting between them), or swirls wide, or fetches the card lying
farthest out back through the middle (`_wash_gesture`). The cards slide as cards do (`_wash_rub`,
`_wash_drag`, `_wash_palm`, `_wash_move`): a palm's grip is friction-limited at five points a card, so a
card pressed whole goes with it, one caught at an end swings round behind it, one brushed stays; each pass
takes hold afresh; where another card lies over a point the palm presses that one instead; two cards lying
one on the other drag each other; a card run into is nudged. Measured: half a card's travel is in straight
runs of 15 cm or more, and 89% of the cards get 15 cm or more from where the mixing found them. Gate:
`tests/table/table_wash_check.gd` (two-sided: a circling wash fails four of its checks, and tiny circles
made up inside the gate fail them too).

A draw: square, slide, flip, up to the camera on the left beside the booklet page on the right (shown,
never read); both turn a little on their axes, and the card is now and then turned to look at its back,
either way round, its back held anywhere from half a second to five (most looks short), and about one look
in three a pirouette: over to the back, held a few seconds, then on round the same way, five half turns more,
to face on again three whole turns from where it began (`TableMedium._look_of`, `_look_angle`; gate:
table_wash_check, two-sided on the holds; `table_look_probe --looks 1` says when they happen). A lay: page
out, card down into the spread. A jumper flies out of a shuffle: its action opens with one more riffle, and
the card rides the top of a half and springs off it while the halves fall (`JUMP_RIFFLE`, `_jump_ride`); the
deck goes aside once that riffle is done. The voice's rest for it is 5.0 s. Out of a wash under way, a blow
throws it instead (see THROWN OUT OF THE SPREAD). The channel's name opens the show, and nothing closes it
but the light: the outro, a beat after the last word the table fades to black, reaching it exactly as the
outro's silence runs out (`_end_fade`: the take's own tail in a render, the Director's outro live), a
function of show time like the rest.

**Foil**: each painting's brightest, most colorful pixels (keyed per picture from its own luminance
percentiles, plus anything near the frame's accent color) print as foil: metallic, a slow breath, a glint
sweeping across now and then; the scene's bloom lets it bleed. The look's `foil` (0-1) says how much.

Everything is a function of show time (`ReadingFollower` + the schedule), so live and export draw the same
frames.

## YouTube

`src/export/youtube.gd` is generic. "+" on any note's panel attaches YouTube, and `YouTubeCard` (block
`youtube:`) holds the choice; every panel's `upload_meta` is the card's title, visibility and playlist over
the mode's own part (`_upload_base`: here the episode's description, chapters, tags, thumbnail moment and
record). The export menu has no YouTube items.

- **The flow**: "+" -> YouTube -> tick "Upload after export" -> (first time only: a file dialog for the
  Google Cloud "Desktop app" OAuth client JSON, kept in `user://youtube/client.json`) -> (while no sign-in
  is kept: the browser opens Google's consent page beside a "Sign in to YouTube" dialog: Open the page
  again / Copy the link / Cancel) -> the box ticks -> ⤓ -> quality -> save path -> render -> transcode ->
  upload, with progress on the status line; the link is copied. A sign-in that lapsed (7 days in Testing)
  opens the same dialog as the export starts, beside the render. The card's "Replace client…" replaces the
  kept one; "Sign out" forgets the sign-in.
- **The card**: the title is a template, `%title%: %episode%` by default (`%seed%`, `%date%` too;
  `YouTube.expand_title` drops what a missing value leaves dangling and never says the show's name twice).
  The names are the script card's: Title and Episode, read by the card itself (`YouTubeCard.name_from`,
  which every panel calls and which shows both rows); a show hands the Episode row its picked episode's
  title (`ScriptWriter.hand_field` -> `EpisodeCard.name_episode`, written into the plan; no episode's title
  is kept in the `cards:` block). The macros are rows (`YouTube.MACROS`): the card's tooltip names only
  those the note fills, and a title naming one it does not (`%seed%` on a reading) is said under it and
  refused at the export's click (`YouTubeCard.why_not`). Visibility is Private, Unlisted or Public (private
  by default); Playlist is None or one of the channel's, loaded with ↻ (listing them and adding a video
  take the `youtube` scope, so the first ↻ signs in again for it; `YouTube.granted` reads the scopes kept
  with the token). A playlist YouTube refuses leaves the video up, and the status line says why.
- **The producer writes for that line**: it is shown the template with the show's name in it and its own
  part marked (`YouTube.title_shape`, `CardsEditor._uploads_as`, the `episode_title` rule in
  `rules/table/producer.yaml`) and asked for title case; no code recases a title. Open: judged on a real
  run (earlier episodes' titles still read back to it with every word capitalized).
- **Google's "Access blocked"**: an account that is not one of a Testing project's test users gets a
  dead-end page that never comes back to Ghost Notes, so the dialog names it; add the account under Google
  Auth Platform > Audience > Test users, then "Open the page again" finishes the same sign-in. A newer
  sign-in replaces one still waiting.
- **The panel's fields** show the show's global values at once, New episode included: the description and
  tags are the show's; the title is one value the picked episode overwrites when it has a plan (as the seed
  is), and an edit goes into its plan too. A show with no description or tags yet takes the picked
  episode's once (the producer writes both with every plan). The tags are the show's: the document's own
  top-level `tags:` line, edited as chips like YouTube Studio's (× removes one, a comma, Enter or a pasted
  "a, b, c" in the box at the end makes chips, Backspace in the empty box removes the last, a chip past 500
  characters is dimmed). The block keeps `episode_title` and `description`, one of each, and nothing per
  episode.
- **The table seen first**: the voice rests a settle (`Openings.SETTLE`, 3 s) after the intro before
  anything is said or done (`CardReading.parse` opens its speakable on it), and the name goes and the focus
  pulls that long before the opening verb (`TableMedium._intro_end`): the table sharp and at rest, then the
  shuffle a beat before the first word. The same settle at the desk (`DeskScript.parse`,
  `DeskMedium._blank`) and the dispatch desk (`DispatchScript.OPENING`); a letter's blank page is longer
  (`LetterScript.BLANK_PAGE`); a show with no opening has its picture up that long before the first sound
  (`Director._bookend_fade`).
- **The title screen**: the show's name, and under it the byline (the document's `byline:`, "with Pen &
  Ink", a field on the document card right under Title), built for the thumbnail:
  - The type (`CardTable.title_layout`): the name as large as a line of it fits across 86% of the frame, at
    most 15% of its height (Cinzel), on two lines when one would set it under 70% of that; the byline 0.4
    of its size; the block centered 45% down.
  - The color is the set dresser's (`title: {color, why}` in `table.json`, `CardTable.title_ink`): it is
    the agent that sees the painted cloth, and with tools the table set; the producer only describes a
    cloth before it is painted. Its prompt says the frame is the thumbnail (`TablePrompts.title_rule`); with
    tools, `title` shows it the opening and the WCAG contrast behind the name. A table set before this, or
    with no color, prints the name in cream (`TITLE_INK`) until the table is set again.
  - A shade round the letters (`CardTable.title_shade`): the ink's own hue taken 85% of the way to black or
    white, whichever is further, a soft halo of stacked outlines and a smooth band behind the block, so any
    color reads (>= 3:1 against its shade, every hue and lightness).
  - The blur is not the lens's (at its softest the bokeh leaves every thing on the table plain). The whole
    frame is read back through `shaders/table_intro.gdshader`: the canvas screen texture's mips (Godot
    builds each level with a Gaussian), a B-spline read of the level that carries the asked-for blur, mixed
    between two levels, at `CardTable.TITLE_BLUR` (0.04125 of the frame's height; the lens's softest
    bokeh measures a sigma of 6.2 px, 0.0086 of a 720 frame). Each level carries 2.07 of its texels of
    blur (measured). It lifts, eased through its log, over the first half of the focus pull and is then
    taken off (not drawn at all during the reading). Gate: `tests/run_quiet.sh intro_blur_check` (width at
    720 and 1080, round, smooth, in place; the title width spreads an outline over 0.3-1.0 times the height
    of a 10 cm thing, and the widths judged against it fall outside that band).
- **What goes up**: the show's name and the episode's title ("Truthful Tarot: My Episode Name"; the
  exported file keeps the episode's alone), the show's description with a chapter per card timed from the
  take, the show's tags fitted to YouTube's 500 characters, and a thumbnail: a 1280x720 frame of the saved
  video at the title screen (the name fully up over the out-of-focus table), set once the video is up (needs
  a verified channel; refused, the video stays up and the status line says why). Constants: not made for
  kids, `containsSyntheticMedia`, no paid promotion (`paidProductPlacementDetails`), category 22 (People &
  Blogs); the privacy is the card's.
- **Resilient**: the upload is queued (`pending.json`) the moment the video is saved, so a quit, a lapsed
  sign-in or a dropped connection leaves "Resume the upload of ..." on every YouTube card; resumable
  sessions live about a week. Each upload is recorded in `<episode>/youtube.json`, and the YouTube card's
  note shows the link.
- **Google's side**: in "Testing" the sign-in lasts 7 days, then the browser opens again. Until the Cloud
  project passes YouTube's API audit, YouTube keeps API uploads private whatever was asked (the status line
  says so). Uploads have their own quota: 100 a day.
- **Not built**: a description and tags for a reading's or a song's upload (they go up with the card's
  title alone), and making a new playlist from the card.

## Probes and gates

- `godot --headless --path . --script res://tests/table_show/cards_check.gd` - the gate.
- `godot --headless --path . --script res://tests/export/youtube_check.gd` and `youtube_flow_check.gd` - the
  upload's pieces, and sign-in + upload end to end against a stand-in for Google.
- `tests/table_show/episode_probe.gd` - make an episode headlessly (real quota); `--only table` sets just
  the table.
- `tests/run_quiet.sh -- res://tests/table/props_look_probe.gd --spec <table.json> --out x.png` - a table
  description's things side by side under candlelight (the camera backs off to show the tallest whole).
- `godot --headless --path . --script res://tests/table/props_check.gd` - the shapes themselves: flat ends,
  corners, elbows, kinks, lofts, coils and warps.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/table_look_probe.gd 400 --show S --seed N --marks 1`
  - the table over an episode with a synthetic voice. `--times 3.6 --name "Show" --byline "with X" --ink
  "#1d2f5c"` photographs the title screen with a set dresser's color.
- `tests/run_quiet.sh intro_blur_check` - the intro's blur, in pixels (see "The title screen").
- `GHOST_PROBE_GPU=1 GHOST_PROBE_MUTE=1 tests/run_boot_probe.sh tests/table_show/cards_voice_probe.gd 900 --spec <md> --seed N --export 1`
  - the panel, the real voice and the table, end to end, and the export take.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_show/set_dresser_look_probe.gd 300 --show S --seed N`
  - what the set dresser's tools show, with no agent: an episode's table put, looked at and set, and the
  opening (`--ink`, `--name`, `--byline`). A `--spec` with `top`/`layers` builds the table itself first and
  shows it from above.
- `godot --headless --path . --script res://tests/table/tables_check.gd` - the table itself (`Tables`).
- `godot --headless --path . --script res://tests/table/lights_check.gd` - the light (`Lights`);
  `tests/run_boot_probe.sh tests/table/table_light_check.gd 300` - the table's own light in the medium;
  `tests/run_quiet.sh light_screen_check` - what the screens draw is what `Lights` reckons.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_show/set_dresser_look_probe.gd 380 --show S --seed N --light <light.json> --quick 1`
  - a light put on an episode's table through the set dresser's own tools, set, and every moving part
  watched (`--watch 0`: none).
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_show/set_dresser_run_probe.gd 1600 --spec <md> --seed N [--model haiku]`
  - the real set dresser at work through its tools (quota), on a copy of an episode.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/air_look_probe.gd 400 --show S --seed N --spec <effects.json> --moments 1`
  - the air over a copy of an episode, photographed at every moment a burst can mark.
- `godot --headless --path . --script res://tests/agents/agent_tools_claude_probe.gd` - that the installed
  Claude CLI reaches ghost's tools and sees their pictures (one short run).

## 2026-10-07: the reading's rhythm, the printed card, strands and bones, bursts

- The reader does not announce: `MOVES` says the viewer watches every card come and go and a reader almost
  never says what their hands are doing; a card's passage may stop on its painting only when
  `TablePrompts.remarks` (seeded, 15-40% of the cards, never most) says so, and the rest are sent no
  painting and no description. Each passage after the first is told not to open or end the way the last one
  did.
- The printed card varies: `frame.window` (rect, rounded, arch, gothic, oval, notched, octagon),
  `frame.corners` (square, rounded, round: the card's slab is cut to them), `frame.ornament` round the
  card's edge (vine, serpent, laurel, beads, rope, stars, scallops) and the booklet's `page` (classic, drop,
  banner, ledger). The producer chooses; the archive shows each episode's choice so habits are named. Foil
  skips the stock showing in a shaped window's corners. A `borderless` frame has no window or ornament: the
  painting fills the card, its type on a veil (above).
- Strands (`Props` shape `strand`): rope (three-strand lay), cord, wire, vine (leaves), beads, chain; laid
  as a coil, a flemish spiral, a heap, a path, or draped across the table in its own coordinates and over
  the top's edge, hanging as far as the path runs past it, to the floor. A strand rests on itself where it
  crosses. Draped strands stand first; the rest stand clear of them, and one that runs where the cards go
  is left off.
- Bones (`bone`: femur, long, rib, small, wishbone) and skulls (`skull`: human, horned with straight,
  curved or curled horns, bird): the one exception to "no body", bone only. The brief's "things on it" names
  both.
- Sculpt (`Props` shape `sculpt`): a sculpt is strokes in order, rods through [x, y, z, r] points (round
  cones, smooth through their joints) or a ball stretched to a `size`, each melted into what came before
  (`blend`) or `carve`d out of it, `mirror`ed across x = 0 if asked. It is a distance field meshed by
  surface nets on a grid cut from its thinnest stroke (72-144 cells across), sampled only near the surface
  (blocks, then pieces) from the strokes near each block; each point carries how shut in it is (`uv2.y`,
  looked up out along its normal and leaning off it), which `prop.gdshader` darkens. Built once a process
  (`SCULPT_KEPT`). The skulls are sculpts (`SKULL_FORMS`): a crow's with orbits open through a thin wall,
  nostrils through the beak, the bars under the eyes and a two-branched jaw; a person's with free cheek
  arches, deep sockets and nose, teeth and jaw; a cow's as found, without its jaw. A sculpt is checked as
  any thing is (`put` answers with a picture, `look` shows four sides) and `put` warns of a stroke finer
  than its sculpt is cut. A person's skull takes about 4 s to build the first time (89k triangles), a
  crow's about 2 s.
- Bursts mark moments the table can show: a burst on the pirouette makes the table twirl one card
  (`SPIN_ROOM`), the set dresser is offered the jumper's moment only when a card jumps, and `which` (every,
  first, last, [n]) picks the times a moment is marked.
- The glitch subtitles write as they are spoken: a letter not yet reached is not drawn, a few letters past
  the front are noise, and the reach grows a letter at a time and falls back (`glitch_reach`). The front is
  one steady sweep through the line, pauses and all (`glitch_front`: the upper hull of each word's
  must-be-written-by moment, never behind the voice, never speeding up), and each row is centered on what is
  written of it, so the words come out of the middle of the screen. Each noise letter holds its glyph
  45-110 ms on its own clock and changes 70% of the time; the reach runs 4-10 letters and backs off a
  letter at a time part way, reaches again, and backs off to one (`glitch_reach`, a run of 48 steps at 12 a
  second).
- Open: the vine's leaves could hang off a draped vine's edge more loosely; a strand could knot; the serpent
  ornament's tail falls a few pixels short of its mouth; a sculpt's build could be faster (a person's skull
  is about 4 s of GDScript) or its grid coarser where nothing is thin; no real set dresser has sculpted yet.

## 2026-10-08: where things stand, the long row, the deck put aside, the wash's pile

Patterns are guided toward, never enforced:

- A habit per episode (`TableMedium._habit_of`, its own die): how far out to the sides its things lean
  (`EDGE_PUSH`, often well out, the middle left freer), and each group's own step off its zone's middle
  (`AIM_WANDER`), so the zones' fixed aims do not make an arc of evenly spaced things.
- The frame may cut an unlit thing at a side or the foot, so long as `SEEN_LEAST` of its picture shows;
  never at the top (it reads as standing in the room), and a lit thing still stands wholly in the shot.
- A foot across a layer's edge scores worse (`STRADDLE`), a third of that for something large
  (`STRADDLE_BIG`: a book, a tray may lie across a hem).
- A row or arc of five or more is laid as two rows now and then (`TablePositions.SPLIT_LONG`, its own die);
  and when a card of the spread would lie within `DECK_CROWD` of the deck, the reader slides the deck further
  out (`_plan_aside`, `DECK_ASIDE` of such episodes) just before that card is taken. About a quarter of 5-8
  card spreads; gated in tests/table/table_positions_check.gd.
- The wash's pile builds to the deck's height as it is gathered (each card thickened as it lands), not all
  at once as it is squared. A card slid up onto the taller pile tips about 20 degrees, so the long side is
  the one kept true (`_tipped`; table_wash_check).
- The fan-out is calm: under the palm each tilt is the mean of the bare rest's over a quarter second
  (`CALM_HZ`, `CALM_REACH`), set down on its highest support so it neither floats nor dips, easing to the
  bare rest over `CALM_SETTLE` after the cards are out (0.09% of frames turn a card faster than 60 deg/s),
  gated against the bare rest (`wash_calm = false`) as the control.
- A height map spanning under `Tables.FLAT_SPAN` of gray is kept as flat (`height.json` `flat: true`): a
  printed grid on smooth vinyl is drawn flat and faint scratches correlate with nothing, so the print lies
  smooth and no image job is spent asking again.
- A map that fits nothing is kept, unmoved, when its relief has no place of its own (`Tables.relief_spread`
  under `EVEN_SPREAD`: the gradient's size over blocks, rows and columns; `height.json` `even: true`): a
  printed check, a dyed stripe or a pebbled top drawn right but left out of the print is otherwise refused.
  The gap is narrow (such maps score 0.11 to 0.17, maps of boards and seams 0.21 up), and planks' seams one
  to a block are caught only by the rows.
- Open: the set dresser's prompt names the zones as before; it could be told the table may run off the
  frame's sides and that the middle may stay free.

## 2026-10-08: the place, heard (the sound)

Places with an environment (a boat at sea, an outdoor scene with petals falling, a dock) have a sound. Wind
is heard from where a window is, stronger on the side it blows from, and wind in a tunnel differs from wind
in the open. The configuration is available to the agents, whose attention is drawn to it.

- `Soundscape` (src/table/soundscape.gd): synthesized, no recordings (filtered noise, struck envelopes and
  rising sines for bubbles). Wind through open air, trees, grass, rigging, eaves, canvas or a tunnel; the
  sea on a shore, against a hull, at a dock; rain on leaves, a roof, canvas, a window, the ground, water; a
  fire; a stream; crickets or cicadas. Each with where it is (`from`) and how far off. Not recorded or
  AI-generated sound: files to license or make.
- The wind is the table's: `Soundscape.of_table` plans the light's `wind` on the episode's seed exactly as
  `TableMedium` does, so a gust is heard as the leaves, shadows and petals move (level vs wind speed r =
  0.97 on trees, gated). Out in the open it is louder on the side it blows from, the balance moving as each
  gust veers; `wind.from` holds it at an opening instead. The agent decides: a light's wind is heard only
  when the sound has a `wind`; a sound's wind with `strength` and no light wind is a wind outside, felt by
  nothing on the table. The fire roars, the rain thickens and the sea slaps harder in a gust.
- Never to nothing: a place ebbs and flows beside its own typical gust or wave (`Soundscape._ebb`: a floor
  6 dB under it at the dial's bottom, 11 at the top, a soft swell above it), the wind's strength sets its
  level only by a square root, and what sounds in a gust waits for this wind's gusts.
- Both ears: no sound is more than `MOST_APART` (7 dB) apart between the ears, as the voice's Lean.
- The gust's shape: the churn is brown noise cornered near 80 Hz and under the rush; the turbulence is a
  slow drift and a little shimmer. The wind heard rises in about 0.5 s and lets go over about 3.5 s
  (`HOLD`), and breathes on three slow unrelated swells (`BREATHS`); the shore's breakers and the hull's
  swell hold and drift likewise. A struck sound's ears ease across the block, a new bubble takes the
  quietest voice, a place fades in over 1.5 s.
- Level in decibels: the log of the speed is smoothed through two stages (an S-curve, as a fade), no rise
  faster than `RISE_MOST`, with gentler powers on the rush and the rumble; since the plan is known ahead,
  the wind is heard `LEAD` (0.8 s) early, so the slow entry still peaks with the leaves. Gated: under 8
  dB/s over a second, where the plan's raw gusts climb far faster.
- Not one filtered noise sweep (the sound an ear knows): the body of the wind is three eddies, each pink
  noise (high-passed at 60 Hz) through a 24 dB low-pass, drifting on its own slow course in cutoff and
  level at its own wandering place; a gust's brightening is given back in level so it does not come in as
  loudness too. A space round every place (a four-line feedback delay network, dark, about 1.1 s, about 9
  dB under the dry sound, wetter as the dial falls). The gust's rise limit is on loudness, at every dial
  setting.
- The set dresser writes `sound` beside `light` (rules/table/set_dresser.yaml, `insert: sounds`,
  `sound_example`); `put` / `remove "sound"` in its tools, and `put` answers with the sound in words.
- Heard under the reading: `ReadingPanel` mixes it after the voice's own effects (`_environment()` is the
  seam; `CardsEditor` reads the episode's `table.json`), live in the push loop and into the export take
  (made stereo), on a worker in both. Its clock is the show's (`Spectrum.stream_origin()` + pushed frames),
  and a table handed in mid-reading is picked up within two seconds.
- One dial, Environment (the Cards card, knob `environment`, 0.5): level (-60 to -10 dB, a straight line,
  2.5 dB a step), how hard gusts and crashes strike, and brightness (distance). It ducks up to 4.7 dB under
  speech and a slow limiter holds a place alone under -5 dBFS. At 0.5 every part sits near -54 dBFS RMS,
  some 30 dB under the voice. A stored dial left at a low value is close to silent until it is turned up.
  Open: judged by ear.
- Listening: `tests/table/soundscape_probe.gd` writes a dozen places to dist/soundscape/*.wav. Gate:
  tests/table/soundscape_check.gd.

## 2026-10-11: what lies on what, the box's cards, a leaf under a card

- **Cards through cards.** What lies on what follows from when each card was set down
  (`TableMedium._down_at`, `_rest_lift`): a card rests a full thickness on whatever lay there first, and one
  put back lies on top. A card under another is slid out along the cloth before it rises (`_slid_out`: the
  shortest way clear of what is on it, never into a card beside it, the deck or the hem). A swept card
  leaves the deck flat and turns over with room for its tilt (`_sweep_xf`).
  `tests/table/table_staging_check.gd` follows a waterfall frame by frame; a straight lift is the control.
- **The box's cards are the box's kind.** With the text on the back, a drawn card has a printed back of its
  own, so the unseen cards get printed backs too (`_blank_backs`: `CardFaces.Face.anonymous`, type ruled as
  lines, three per printing); the search's card as well. Front-text and booklet boxes keep the shared back.
- **Piles** (`TablePositions.box_piles`): uneven heights, plots of the floor shared out by lot so no two
  gaps match, each pile leaning and a little ragged, no card off its own plot. The drawn cards wait on top
  of piles, first drawn uppermost; a card put back goes on a pile none is drawn from. A shoebox of piles is
  filled to `SHOEBOX_SHARE` of what it could hold, so heights have room to differ. The open box's piles are
  laid the same way; cards filed on edge and the open box's `loose` heap are separate.
- **A leaf under a card.** The air's `lay` moments reach the drifts (`Drifts.laid`): a piece where a card
  comes down goes aside first, out past the nearest clear edge (`_make_way`, `_aside`). A life is what it was
  planned to do, amended by the cards known so far.

Open: keepsakes in a box lie on its floor, inside whatever pile stands there; a card sliding along the cloth
(a waterfall, a slide-out) does not move a leaf in its way; none of this has been judged in a finished video.

## 2026-10-12: a card out of the box is the box's kind, and a search of cards on edge

- The file stands back to the camera (`_build_file`'s `stand`): a card comes up showing its back, as every
  card in the box does, and is turned round on its way to being shown. This holds for a shared-art back too.
- The unseen cards' printed backs are the deck's own cards the draw left in (`_left_in`: name, group,
  meaning; up to `WRITTEN`); ruled dashes (`anonymous`) remain only where the plan lists no deck.
- The search draws the file's own cards up out of their places (`_box["search"]`, `_searched_xf`): on edge,
  `SEARCH_RISE` of the way, tipped toward the eye, let back down, a different card and place at every look.
  Off a pile it lifts the top card, turns it up to be read and lays it back.

Gate: `table_staging_check` (`_file_search`, the box show's facing, the cards left in).

- The card a search looks at is the box's own, kept in its place (`_keep_searched`, `_searched`): standing
  in the file, or lying on top of a pile nothing is drawn from or put back on (`_pile_places` spares piles
  for it, the draws keeping two). Nothing appears as a look begins. Only a box with no place to spare (a
  tin's flat deck, one pile) is lent a card for the look.
- A card lifted off a pile is lifted no higher than the picture (`_searched_xf`): a shoebox stands at the
  back of the table, near the frame's top.
- The box stands in its own place in the room kept for one (`TablePositions.box_stand`): seeded, anywhere a
  box smaller than `BOX_MAX` / `SHOEBOX_MAX` fits, an open box in the inner half (14 to 27 mm toward the
  spread for the plain box). The spread's room is untouched.

Open: a card at the top of its rise out of an open box at the side can still be about a third out of the
picture; fixing it means moving `box_at`, the room the spread keeps off, which re-lays every box episode's
spread. The pile search was judged on a copy restaged as a shoebox of piles (`--root`). Nothing here is
judged in a finished video.

## 2026-10-12: the brief's own marks

- **The brief's palette.** The editor's palette is built from `ScriptMarks`, each mark listing the panels
  that honor it. The document in Cards is the brief the agents work from, never read aloud, so a mark is
  offered only if it means something in a brief.
- **What a brief is offered**, each saying what it does in a brief (`blurbs`): a speaker cue (another voice
  of the show), the deck (`## Cards`, a suit, a card, colored only inside the section, `CardDeck.span`), a
  template macro (the agents get its default) and a note to self (taken out before any agent sees the
  brief), both in `TablePrompts.brief`; a heading, italic and bold, and a hesitation, a timed hesitation and
  a delivery, which stand in a line the brief gives the host word for word (the reader's `spoken` rule says
  such a line keeps its marks).
- **What it is not offered**: pictures, sketches, scene lines and breaks, log-entry times, the outro mark
  and everything of the tablet (the table is the only medium, its pictures are the painter's, and the outro
  is the bookends'); the inline pronunciation (a reader's passage keeps no bracket,
  `TableProducer.clean_spoken`, so it would be lost; `script_marks_check` holds that, and says to offer the
  mark if that ever changes).
- **Open**: whether a writer keeps a dictated line's marks (the rule is there and the pipeline keeps them;
  no episode has been made with one yet); a way to give a name's pronunciation in a brief.
- **Italic hits, bold hits harder**. A passage keeps `**`, so a bold word is shown in bold and sent at the
  stronger level; both levels apply in the voice host for every reading (`EMPHASIS` in
  hosts/voice/backends/piper.py, with the measured ceiling that keeps a lifted word from clipping).
  `~/.cache/ghost_look/stress/` has one sentence said the three ways. Episodes already written keep the
  single asterisks they were saved with. Open: judged by ear.

## 2026-10-12: nothing out of doors pulses

- **The rule.** Noise chopped by a sine reads as a fan spinning, whatever its rate. Cloth flaps are events: a
  thump at a time, each its own strength and pitch, the waits between them exponential, now and then
  straight back. The slosh after each slap on a hull is a plain wash (broad, unpulsed, struck to a peak
  about 4 dB under its slap) and the gurgle is the bubbles' (a few more of them, and audible).
  `soundscape_pulse_check` holds the wash (no pulse, under its slap and there) and the flaps against the old
  recipes; it is a gate of its own because `soundscape_check` already runs close to its five minutes on a
  busy machine.
- **Method kept**: render the parts of a place alone, and measure their levels, before deciding which one a
  person is hearing. `Band.strike` scales by the envelope one sample after the strike, floored at 0.05, so
  its `amount` is about a fourteenth of the real peak (every struck sound is tuned on that); `Band.hit` is
  the one whose argument is the peak.
- **For the ear.** `~/.cache/ghost_look/sound/`: the water as it was heard and now, the whole place now, and
  each part alone, all at that show's Environment setting.

## 2026-10-13: a search looks at fronts, and a card goes back only as a pass

**Fronts.** The cards nobody drew have fronts, so the file stands face to the reader and a search shows
fronts:

- `TableMedium._unseen_fronts`: each card the draw left in (`_left_in`, up to `WRITTEN` a printing) is
  printed as a drawn card's front is: frame, ornament, name, its details under the picture when the text is
  on the front. In its window is a part of a drawn card's painting (`CardFaces.stand_in`, `Face.part`): a
  third to a half of it, mirrored or not, tinted toward a palette color, seeded per card, put in as that
  painting lands. No painter runs for a card that is only glanced at. A card with no name known
  (`anonymous`) keeps its band bare and its details ruled.
- The cards left in are the plan's deck less the drawn ones when the producer chose it; for a show with its
  own deck, the draw keeps them (`draw.json` `left`, `TableEpisode.document`). No writer is handed one.
  Episodes drawn before this have none and get the nameless fronts.
- The file stands face to the reader (`_build_file`'s `stand`): the drawn card comes up showing its face, as
  every card left in does.
- The look: on edge, the partial draw (`SEARCH_RISE`) leaned back to the eye, which looks down on it
  (`SEARCH_TIP`), and drawn up less where the picture's top would cut the painting (`_search_rise`, down to
  `SEARCH_RISE_LEAST`). Lying, a card is face down, so it is turned over (`_turned_up`, a slerp from where it
  lay), carried as high as keeps its lowest corner out of its pile, and held inside the box's walls
  (`toward` is held inside the front wall too); two looks share the search's rest instead of three
  (`SEARCH_LOOKS_LYING`). The rest the voice takes (`TableActions.RUMMAGE`) is unchanged.

**Back in the box.** Where a card goes is the producer's per position, and the rule is that a card put back
is one that was passed over:

- `TableProducer.back_only_passed`, as a plan lands: where some cards stay out, a card with a `story` stays
  out as they do (on the keep pile when the spread has one), a card put back with no length asked for
  becomes `brief`, and a quick, silent or aside look goes back as planned. A spread that puts every card
  back is left alone. No card goes back into a box from a deck, or from where it was dealt or swept.
- `TableProducer.passed` -> the reader's `passed` rule: its few words (15 to 40, whatever the plan's
  comment says) are the only place the viewer learns why this one goes back, so they say what makes it one
  to put back. No sample reason is written into the rule: it would be said every episode.
- `producer.yaml`'s staging says it flat: one pattern, or the talked-about stay out and only a card passed
  over goes back.

Gates: `table_staging_check` (fronts, facing, the leaned look, the turn over, `_search_rise`; its checks of
the box's contents read the places the table keeps, `_box["filed"]`, because a headless MultiMesh hands back
identity for every instance), `cards_choose_check` (`_put_back`).

Open: a plan made before this is not re-landed. A card put back keeps its empty place in the row
(`TablePositions.piles_of` counts it), so the cards kept sit off-center. Which card is passed over is the
position's, set before the draw: a reason from the card itself (a common one, a double) would need the
destination decided after it. A turn over off a pile near the frame's top, and a drawn card at the top of
its rise out of a shoebox at the back, can leave the picture for a moment. A tin's flat deck takes no card
back: one "put back" is laid in the row. The stand-in paintings have not been judged in a finished video.

## 2026-10-18: a move is for the story, nothing in the box passes through a card, the shuffle's end

**Moves are for the story.** A move (a search, an aside, a put-back, a waterfall, a sideways lay) belongs to
a position whose own question is about it, in cards really handled that way; the plain pull, show and lay is
how cards are handled.

- The history keeps where the cards came from, never how each was handled (`TablePrompts._past`), and the
  habits rule says handling is never varied for its own sake.
- `producer.yaml`: sideways, `on` and `then` are a game's only. The table shows the cards, the box and the
  moves: no plan rests on a band, a clip, a sleeve.
- `TableProducer.runs_of_three`: a waterfall is three or more swept positions; fewer come out one at a time.
- `reader.yaml`: the viewer sees everything done to the cards, so a passage claims no arrangement the table
  does not show; a card laid sideways, laid on another or turned where it lies tells its reader so
  (`handled`, `TablePrompts._handled`), and the reader says what it means. `after` names the sideways lay
  and the card it is laid on.

**The box** (`TableBox`, `TableCardPose`; gate `tests/table/box_clip_check.gd`, frame by frame):

- An open box's loose cards lie in piles, as a shoebox's do (a card is 0.7 mm thick), the drawn ones
  waiting at planned places, not at random in a heap.
- A card put back goes where no card still to be drawn waits under it: the draws after the first return
  never come from the returns' pile, which gives its top cards only to earlier draws; the returns lie on
  its top as it is then. A box with room for one pile, in a reading that puts a card back before another is
  drawn, files its cards on edge instead (`TableBox.contents`).
- A card put back is carried over its place, turned as it will lie, then let straight down (`_put_back_xf`);
  a card taken out rises over the highest card in the box, not only the rim (`top_y`, `_over_box`); a card
  dealt or swept out of the box keeps its lower edge on its line, and over the box while the next one comes
  up behind it (`_box_lift`).
- A file's cards are turned off true no further than keeps their sides clear of their neighbors.
- A search stops on each card: about a second of its front to the eye (`RUMMAGE` 5.4); a card off a pile
  rises clear of the cards it turns over before it turns (`TableCardPose._ground`), and a search spares the
  tallest piles.
- The deck checks of `table_staging_check` look at the deck's top card until the first card is taken. A
  card leaned back out of a file can rock into the cards in front of it below their tops, hidden; the gate
  counts what shows.

**The shuffle's end** (`TableShuffle.cut_off`, `finish_xf`; gate `deck_turns_check`): the first card cuts
the last move off, and a cut-off riffle, overhand or cut is finished along its own path in the squaring's
0.45 s, the orientation following the deck as the move leaves it (easing every card back to the slot it
began the move in would carry a card through the ones it passed). The card to be drawn is the deck's own top
card until the hand takes it (`TableMedium._taken_by`, `_leaves`), then itself in that card's place, the deck
a card shorter.

Open: the moves' own paths are not clean: an overhand's packets drop through the edges of the cards still
held, a riffle's halves lift through each other. A box that can neither spare a pile nor stand its cards on
edge (a shallow tin of one pile) buries a draw under a card put back. A riffle jumper rides on top of a full
deck.

## 2026-10-19: the table rides, and an electric light holds steady

**One ride, one plan** (`Rides`, the table's `ride`: `on` rails, road, track, water or air; `rough`,
`speed`). A table on a moving thing shows it: camera vibration, bumps, props that move a little. Planned
from the seed as the wind is, every part a function of show time in closed form: the buzz (a band of floor
vibration), the knocks (each axle of the car over each rail joint: pairs a long gap apart, as often as the
speed takes them), the patter (a cart's wheels over stones), the bumps (now and then, harder), the slow
sway, the deck's roll on the swell and the turns of the heading over minutes.

- **The lens** is mounted and steadied (a phone on a small tripod, its stabilizer on): a 4.5 Hz, heavily
  damped give (a 0.45 px rms buzz at 720p and a 2.3 px nod at a jolt that settles in a few frames). It never
  takes the sway, the roll or the turns: slow motion of the whole frame makes a viewer seasick, and a
  mounted camera rides it with the table anyway.
- **What moves** is the set dresser's: a part's or a group's `move`: sway (a flower in its vase), tremble (a
  petal, a feather), swing (a pendulum), needle (a compass's: it swings at a jolt and keeps to its north as
  the ride turns), rock (a loose stone: only the hardest jolts, set down a degree or two turned, never far
  from where it was put), slosh (a liquid's surface: it stays level in the world as the deck rolls). Each
  is an oscillator (its frequency from how far it reaches, its damping its kind's) answering the plan as
  damped rings for the jolts, the steady answer to the slow tones, and for the buzz a narrow band (Rice's
  sum of close tones, its strength from Miles' equation). A sway, tremble or swing stirs in a written wind
  too. Built as a pivot node per moving copy (`Props._holder`), at rest exactly where the still build
  stands it; a rock tips about the furthest point of what it rests on (`Props._contact`).
- **Flames** lean toward the push and stay upright as the deck rolls, and jump at a jolt.
- **The sound** (`sound.ride`, heard only when written, as the wind is): a rumble and the wheels' roll, each
  knock a thump and a steel tick, a bump a thud, its impact and a rattle, struck at the plan's own times, so
  a jolt is heard as it is seen.
- Gate `tests/table/ride_check.gd`; the set dresser's `put` says what moves and how fast, and that a ride
  is felt but not heard until its sound names it.

Not yet: what the sun falls through outside going by (trees and poles sweeping their shadows over the
table); the shadows' casters swinging with the ride (a lantern on its chain in a rolling cabin); a liquid's
ripples (the surface tips whole); cards on the cloth shifting at a hard jolt; the reader's held card
jiggling in their hand.

**An electric light holds steady**. `fluorescent` and `neon` are steady by their look. An electric light (a
lamp, a hanging lamp, a street lamp, tubes, a sign) fails only when written `failing`: a bad spell about
every four minutes (`every`), a few seconds of bunched, mostly shallow sags; a bulb's filament cools over a
tenth of a second and warms its color as it sags (light ~ V^3.4, color ~ V^0.42), a tube's bank or a sign
loses one tube or one stroke, shutter-averaged; once in ten spells a moment all but out (`Lights._failing`,
`lights_check`).

## Not built yet

- The light: no real set dresser has lit a table yet. A cloud's edge across the table (a slow low cloud's
  gradient would need the sun's light shaped in every table shader's own `light()`). A screen for a lamp (a
  street lamp through a window's bars at night: screens are the sun's alone). Rain running down a window,
  and water's caustics on the table. Lightning's own shadows (a second directional light). The camera
  opening up under a cloud over a few seconds, as an automatic exposure would.
- The table itself: the prompt says a dressed table is most often more than one layer, and each set dresser
  sees the tables before it. Legs, an apron or a pedestal (the camera sees none from the reader's chair,
  but a lower camera would). A dark velvet or a bare dark top lets a candle burn as the key beside pale
  cards, which bloom (the heat cap reads the cloth, not the cards); counting the cards would take most
  candles off the key. The dealer is told a round or oval top and its layout is checked against it once the
  table is set.
- Free form: no real set dresser has used lofts, coils, corners or warps yet. A rounding on an extrude's or
  a sheet's own outline (a rounded tray); a loft whose path is a coil (a conch's whorl); a warp on a crystal
  bends its flat faces like any other.
- The sound: no real set dresser has written a `sound` yet, and nobody has listened to one under a real
  reading. A boat's timbers creaking with the swell; birdsong (the light's birds are silent); a crowd or a
  market's murmur; thunder with the light's lightning; the sea's size following the wind's strength more
  than a little. A dial change is heard after the few seconds the ring already holds.
- Pick-a-pile episodes (three piles).
- Moving `Illustrations`' own job pump onto `AgentJobs`.
- Porting the tablet's follower onto `ReadingFollower`.
- Tools for the other agents: the painter checked by a vision pass and repainted with notes (a back's
  half-turn symmetry measurable in pixels); the reader's `check_passage` (word range, the MOVES phrases,
  what earlier episodes said), its loop inside one passage only; the producer reading any earlier episode
  whole. Codex (`mcp_servers.<name>.url`) and Bedrock (Converse tool use, turns as `advance()` steps) as
  tool-taking writers.

# Ghost Notes: Cards

A card reading nobody writes. A SHOW is a document; each seed of it is an EPISODE that agents plan,
deal, paint and write one card at a time, and ghost reads it aloud in the Generative voice at a
table. Built 2026-10-04 as the tarot mode; renamed Cards on 2026-10-06 (the user: "the intent is to
later support any kind of card: tarot, baseball cards, MTG, Pokemon, flashcards... I want to use
'Card' as the name"). Its first deck, and so far its only recipe, is the tarot: the prompts, the 78
and their elements, reversals and jumpers are the tarot's, and moving them into a show's guide is
next/notes.md step 9's open part. First show: `rift/tarot/truthful-tarot.md` ("Truthful Tarot" -
the genre's format and voice, told true).

In the code: `CardsEditor` (the panel), `CardEpisode`, `CardProducer`, `CardPrompts`, `CardReading`
(the marks, `<!-- table: draw 2 -->`), `CardDeck`, `CardTable`, `CardFaces` and `TableMedium` (the
`table` medium); a show's block is `ghost: cards:` (its draw range `draw:`), its episodes live under
`user://cards/` (moved from `user://tarot/` once, at the first launch after the rename), and the
seeds' hash salts keep their old `tarot-` names, so every episode already made comes out the same.

## Using it

1. New ▾ -> **Cards** makes a show's note; the Truthful Tarot note is in the notes list already
   (`godot --path . -- --cards` opens the last show). **Edit** edits its body - the rules, and the
   `## Cards`.
2. **New episode** draws a fresh seed from the OS's randomness - and makes nothing. **Generate**
   makes the episode in order: ~1 minute per picture (back, cloth, room, then each card), the
   reading written card by card as the paintings land. **⟳** on a row makes ONLY that part again;
   what was made from it is cleared and waits for Generate (the shuffle and the script, which cost
   nothing, follow on their own). **Writer** and **Painter** pick the agents (Claude or Codex for
   words, Codex for pictures) and, beside each, the MODEL: Claude's aliases (Fable, Opus, Sonnet -
   each the newest of its family; Default is Opus for the plan and reading, Sonnet for the card
   designs), Codex's from the catalog the CLI keeps (`~/.codex/models_cache.json`, listed entries
   only; Default is the author's config). Saved as `writer_model` / `painter_model`. The painter's
   model is the agent that asks for a picture; the picture is Codex's image tool's either way.
   Beside each model, the REASONING EFFORT (2026-10-06), saved as `writer_effort` /
   `painter_effort`: each CLI's own levels - Claude's `--effort` (low..max; Default = the author's
   Claude Code setting for the model), Codex's `model_reasoning_effort` (the model's catalog levels;
   Default = medium, low for designs; the painter low), Nova 2 Lite's extended thinking (low..high,
   billed as output; Default off). Bedrock's painter takes none (the picker grays out). **Folder** opens the episode: every prompt beside its reply.
3. **Play** reads it at the table (the karaoke line tracks the voice). The voice is the panel's
   own and is saved in the show's frontmatter; **Test** auditions it.
4. **Export** renders the video, named after the episode's title; the episode's folder then holds
   `upload.md` - the title, a description, chapters timed per card from the take, and tags (the
   show's own `tags:` line first). Attach **YouTube** with "+" and tick its **Upload after export**,
   and the saved video goes up to your channel - see "YouTube" below. The Episode card's title and
   the YouTube card's description and tags edit what the producer wrote (the title saved into the plan).
5. Any earlier episode is one pick away in the episode list, exactly as it was made.
6. **Delete…** removes the picked episode, after asking: its whole folder goes to the system
   trash (restorable from there); exported videos and the other episodes are untouched. The
   panel moves to the newest episode left.

## The pieces

| file | what it is |
|---|---|
| `src/text_gen.gd` | `TextGen`: who writes words - a registry beside `ImageGen` (`claude`, `codex`). Stateless writers; pictures go with the words. Claude runs with no tools; Codex is told to work from the message alone. |
| `src/agent_jobs.gd` | `AgentJobs`: one queue for every AI run (text and image) - limits per kind, LANES (one at a time, in order), timeouts, read-only refusal, and a rerun's folder cleared of the last run's output. Polled from `main._process`. |
| `src/reading_follower.gd` | `ReadingFollower`: where the voice is in a document - the tablet's sequential word match, and the schedule that puts actions in the voice's rests. |
| `src/card_episode.gd` | `CardEpisode`: an episode on disk, one file per step, under `user://cards/<show>/<seed>/`. A redo is a delete. |
| `src/card_producer.gd` | `CardProducer`: makes whatever is missing, in drawing order. |
| `src/card_prompts.gd` | `CardPrompts`: which rules each agent is told, and what fills them in. Pure. |
| `rules/cards/*.yaml`, `src/rules.gd` | The words themselves, one file per role (producer, designer, set_dresser, reader, painter, show), each rule's reason a comment above it; `Rules` reads them (items in order, `when` flags, `insert`, Mustache sections). Moved out of the code 2026-10-08 with every prompt byte for byte the same (227 prompts over three real episodes, compared before and after). |
| `src/card_reading.gd` | `CardReading`: the reading's marks; one walk gives the voice its text and the table its actions. |
| `src/card_deck.gd` | `CardDeck`: the show's deck, parsed from its brief's `## Cards` section (none built in: a brief that lists no card leaves each episode's to its producer); the seeded shuffle; true-random seeds. |
| `src/card_table.gd` | `CardTable`: what a look may name - title faces (`fonts/cards/`, OFL), frames, the zones things stand in - `sanitize_look`, `sanitize_table`, and the layout a prompt can know ahead (`layout_of`, `headroom`). |
| `src/agent_tools.gd` | `AgentTools`: tools ghost serves an agent WHILE it works - an MCP server (HTTP, JSON) inside the ghost process, a URL per job, every call logged beside the prompt (`tools.jsonl`, `look_NN.jpg`). Claude takes them (`TextGen.Backend.takes_tools`); Codex and Bedrock are still one reply. |
| `src/set_dresser_tools.gd` | `SetDresserTools`: the set dresser's tools - `put`, `remove`, `look`, `set`, `watch`, `title`, `submit` - over a draft table. |
| `src/table_preview.gd` | `TablePreview`: what those tools show - a thing in a studio on a centimeter grid (four sides, or several in tiles), the draft on the episode's own table from the show's camera, and the opening (the show's name over that table thrown out of focus). |
| `src/effects.gd` | `Effects`: the AIR - fog, motes, bursts - as data an agent writes (registries it reads, `sanitize`, `build`), posed from show time. Generic; the tarot table names its regions and moments (`CardTable.AIR`, `MOMENTS`). Shaders `effect_fog.gdshader`, `effect_sprite.gdshader`, `effect_smoke.gdshader`. |
| `src/lights.gd` | `Lights`: the table's LIGHT built from a description - its sky, its sun (or the moon) and what the sun falls through (a window, blinds, a lattice, leaves, fronds, branches, slats, an awning, a parasol), clouds and birds, lamps out of the shot; registries an agent reads, `sanitize`, `build`, and the CPU's reckoning of where the sun falls. Shaders `light_screen.gdshader`, `light_bird.gdshader`, `light_noise.gdshaderinc` (the noise both reckon alike). See "THE LIGHT" below. |
| `src/winds.gd` | `Winds`: the table's one wind - a breeze and planned gusts, its carry in closed form - shared by the light and the air. See "SHADE, WIND AND WHAT IT CARRIES" below. |
| `src/drifts.gd` | `Drifts`: what the wind carries (the air's `drift`) - petals, leaves, seeds - each piece's life planned from its own dice: falling, lying, skidding, carried off. Shader `air_drift.gdshader`. |
| `src/tables.gd` | `Tables`: the table itself built from a description - its top (shape, edge profile, material, boards, tiles, inlay) and the layers laid on it (fabric, pattern, border, fringe), each surface's relief; registries an agent reads, `sanitize`, `build`. Shaders `table_top.gdshader`, `table_textile.gdshader`, `table_common.gdshaderinc`, `table_relief.gdshaderinc` (and `noise_common.gdshaderinc`, shared with the props). |
| `src/props.gd` | `Props`: things built from a description - shapes (lathe, loft, tube, coil, extrude...), corners as data, a warp on any part, materials, ornaments (registries an agent reads), `sanitize`, `build`. Generic; the tarot table is its first user. Shaders `prop.gdshader`, `prop_glass.gdshader`, `prop_lens.gdshader`, `prop_common.gdshaderinc`. |
| `src/card_faces.gd` | `CardFaces`: faces, backs and booklet pages, composed in 2D into stopped SubViewports. |
| `src/media/table.gd` | `TableMedium`: the table. Pinned by the mode (`Medium.OWNED`, `Director.medium_override`). |
| `src/cards_editor.gd` | `CardsEditor extends GenerativeEditor`: the panel. |

## The show document

Frontmatter: `title` is the channel. `ghost: tarot:` holds the knobs - `show` (the cache key,
fixed at the first episode), `seed`, `cards: [lo, hi]`, `reversals`, `jumpers`, `writer`,
`painter` - and the reader's voice (`voices`, `tab`, `picture`), exactly as a Generative chapter
carries its cast. The knobs are the document's exactly: a show opened with no block starts from
the defaults, never from the show open before it (whose key would put its episodes in that
show's folder). An export is of the episode open when it was asked for, whatever is picked
during its minutes of synthesis. The BODY is the BRIEF: what the show is, its reader, its rules. Every agent gets
it verbatim. The framework (the prompts in code) knows what a tarot video is; the brief knows
what THIS show is. One show document makes many episodes.

**The deck is the show's**, and it is data (the user, 2026-10-04: "the 78 cards are constant... we
should define the deck itself, then use true RNG"; and alternative decks with their own cards must
work too). A `## Cards` section of the brief lists it, one card per list item - an optional
numeral, the name, a colon, what it means (`- XVI. The Tower: ...`) - with `###` headings for
suits or groups; an indented line or nested bullet says more about the card above it. The heading
is `Cards` (or `The Cards`), never `Deck`: a section describing the deck's look in bullets would
become a deck of its bullets. Without one, the show reads the standard 78; `CardDeck.standard_section()` writes
those out as a template (Truthful Tarot carries them, editable). Agents are handed the brief with
the card LIST taken out (`CardDeck.strip`); a card's meaning reaches a writer only when it is
drawn. **No agent ever picks a card**: an episode's cards are a shuffle of the deck from its
seed, and a new episode's seed comes from the OS's cryptographic randomness
(`CardDeck.true_seed`) and is kept, so the episode can be made again exactly. The draw writes the
cards themselves into `draw.json`, so an episode keeps what it drew whatever the deck becomes.

**A show that is not a tarot reading** (2026-10-07; the user: "somebody has a box of baseball
cards, or Pokemon cards, and they just want to show them to people"). Two parts of the guide:

- A `## Format` (or `## The format`) section says what the show is. With one, no agent is told
  "tarot": the shared context says only that it is a show of cards at a table, and maps the
  recipe's working words (reader, reading, spread, positions, booklet) to the show's own, which
  the section defines (`CardPrompts.show_context`). The producer names the deck's `kind`
  ("minor-league baseball card set"), and the designer, the card, the back and the room are
  painted as that (`CardPrompts.deck_noun`); the set dresser's reasons and stones are a reader's
  only without one. A show with no Format section is told exactly what it always was.
- A `## Cards` section of PROSE ALONE, with no card listed, leaves the deck to each episode's
  producer (`CardDeck.chooses`): it lists a box in the plan's `deck`, at least twice the spread
  and twelve, at most thirty (`CardPrompts.BOX`), and the seed draws from it as it draws from a
  listed deck. The producer picks what is in the box, never what comes out; a box the size of the
  spread is refused. NO CHEATING holds: a reader is handed cards 1..K, never the rest of the box.

**One set of rules for every show** (2026-10-08; the user: "there shouldn't be ANY tarot-gated rules
or logic in the 'rules/' files ... for anything else that tarot might need - declare it in the markdown
files"). The Format switch above is gone: every show gets the same shared context
(`rules/cards/show.yaml`, `context`), every producer names the deck's `kind` from the brief, and a look
with no `kind` is a plain "deck". What was the tarot's moved into `rift/cards/true-tarot.md`: its 78
(it always listed them; `CardDeck.standard` and its generated deck are gone, and
`data/decks/tarot/` was removed), the suits' elements (prose in its Cards section,
which every writer reads), the stones and the reader's reasons (its table section), and what a jumper
means to the genre. A brief that lists no card - no Cards section at all included - leaves the deck to
the producer. The JUST-IN-TIME rules are the brief itself, handed verbatim to every writer; the
painter, who never reads it, learns it through the producer's `kind`, `deck_style` and `card_back`.
No separate rule-writing step: it would restate the brief in another agent's words. Gates:
`rules_check` (no rules file names a kind of card, against a control part that does) and
`cards_choose_check` (the same context around any brief; "tarot" only from the brief or the `kind`).

First such show: `rift/tarot/the-shoebox.md` (a collector opening a different box each episode;
every card invented). Gate: `cards_choose_check`. Still the tarot's: the card's size and shape
(a baseball card is 6.3 x 8.8 cm, a tarot card 7 x 12) and the face (a numeral, a name, an art
window - no stat box).

**The staging** (2026-10-07; the user: a collector "might have a box... and just draw cards at
random from it", cards in a box "stand vertical... like files in a filing cabinet", a card "tapped...
turned sideways", "a waterfall... presenting several at once", cards "stacked vertically, like land in
MTG", a baseball card "held in the center of the screen, alone", a box mixing printings whose "front
and backs would be different"). Every choice is the producer's, in the plan, steered by the brief, and
every one is data the table reads:

- `plan.staging.source` (`TableActions.SOURCES`): `deck` - shuffled in the middle, pushed aside, a
  jumper possible - or `box`: one of the set dresser's things marked `holds_cards` (`CardPrompts.box_rule`;
  a plain box of the deck's stock when it built none), stood where the deck would be
  (`TablePositions.box_at`, no bigger than `CardTable.BOX_MAX`, the spread kept clear of it), the cards
  filed in it on edge - upright, on a long edge, or flat in a shallow tin - most of its length full and
  the last few leaning into the gap (`TableMedium._build_file`, a MultiMesh per printing). A drawn card
  waits standing in the file and is pulled straight up past the rim. The reading opens with `open`
  instead of `shuffle`, and no first card waits for a push.
- `plan.staging.text` (`CardTable.TEXTS`): `booklet` - the page beside the card, held up on the left -
  or `back`: the card's text printed in a panel over its printing's back (`CardFaces.Face.printed`), the
  card held up ALONE in the middle and turned over to show it, every time, long enough to read
  (`TableMedium._looks`). The designer writes the back's facts and text; the painter leaves the back's
  middle plain for them.
- `look.series`: the PRINTINGS a deck mixes, each a name and what it prints otherwise (style, back,
  palette, frame); a card's `series` (or its group's name) picks one (`CardTable.look_of`). Each printing
  is painted its own back (`image:back:<key>`, `back_<key>.png`), each card in its own printing's hand
  (the chain of references is that printing's).
- Each spread position: `comes` - `drawn` (held up), `dealt` (straight to its place, never held up) or
  `swept` (a run of swept positions goes out in one waterfall, overlapping, then each is picked up);
  `lies` `sideways` (a quarter turn); `on` (stacked on the card before, a step behind so its name shows);
  `then` - `tap N`, `untap N` after its passage. `TablePositions.staged` lays the piles (a card alone, a
  stack, a waterfall) in a row or two, checked like every position; a spread asking none of it is the
  seeded preset, draw for draw.

**The verbs.** `TableActions` holds them all, each with its rest: `open`, `deal`, `fan` (`fan 3-5`, a
run), `show` (a card lying on the table picked up and held as a drawn one is), `tap`, `untap`, `flip`.
`CardProducer.choreography` writes the reading's marks from the plan; `CardPrompts.after` tells each
reader what moves after its words (the same order). The table poses each card from its own TIMELINE
(`TableMedium._times` `events`, `_card_pose`): arrive (draw, jumper, deal, fan), show, lay, turn - still
a pure function of show time, and tarot's draw, jumper and lay keep their exact phases. NO CHEATING holds
for a waterfall: the cards swept out together are revealed together (`CardEpisode.reveal_of`), so the
reader of its first card is handed them all, and no card past them. Gate: `table_staging_check` (the
marks, the layouts over 40 seeds, the choreography, a deck show and a box show posed, the printings'
backs), `table_actions_check` (the rests). `flip` has no producer field yet (a face-down card's reveal
needs its own rule for the reader), and the dealer's tools do not take the new fields.

## The episode

| step | who | from |
|---|---|---|
| `plan` | producer (best tier) | brief, title, the seed's dice, earlier episodes (it names their habits first) |
| `draw` | ghost | the show's deck and the seed (shuffle, spread size, jumper) |
| `design:K` | deck designer (fast tier), one card per run | the look, card K, its traditional meaning, how earlier decks pictured card K |
| `image:back/surface/backdrop` | painter | the look |
| `table` | set dresser (best tier), with tools when its writer takes them | the plan, the cloth's painting and the room's (its light must agree with the room), earlier episodes' tables and lights - no card; and, with tools, pictures of what it builds, of the table set, of what moves in its light and of the opening with the name in its color |
| `image:card:K` | painter | design K; the back + first + previous card as references |
| `say:intro` | reader (best tier) | the plan - no card; how earlier episodes opened |
| `say:K` | reader | the plan, every passage before, cards 1..K, and card K's PAINTING; how earlier episodes met a card |
| `say:close` | reader | everything, and every card's painting; how earlier episodes closed |
| `script` | ghost | the passages and the marks between them |

**The reader looks at the cards** (the user, 2026-10-04: "otherwise, the text and the images are
sort of just disconnected"). A card's passage waits for that card's picture and is sent it -
upside down when the card came up reversed, as the viewer sees it - and is told to talk about
what is actually painted; the designer's plan for the painting is left out, since the painter
may have gone its own way. The close is sent the whole spread. Painting a card again therefore
rewrites its passage and every one after it. The writer takes pictures as stream-json content
blocks (`TextGen.Claude.compose`, at most 768 px on the long edge), and `prompt.txt` lists which
pictures went with the words.

**The cards move between passages, never inside one** (the user, 2026-10-05: "she's signaling the
draw before it even happened"). A passage is spoken whole and the table acts in the silence after
it, so the intro had been told to "end on the moment you stop shuffling to pull the first card" and
wrote "And there. That's the first one." - with a hesitation, trying to time the draw itself - a
beat before the card came out; a last card's "There. Beside the other two." came before it went
down. Every reader prompt now says when the cards move (`CardPrompts.MOVES`): lead into the next
move, never report it - the acknowledgement belongs to the passage after it. Scripts written before
this keep their words until those passages are rewritten. Gate: cards_check `_moves_after_words`.

The order is not written anywhere: a step starts when its inputs exist (`CardEpisode.needs`).
A card's picture waits for the back and the card before it, but is not MADE from them: redoing
one picture leaves the rest of the deck alone (the Illustrations rule). There is no "shuffle
again": the draw is a function of the seed, so a different deal is a different episode.
A reply of the wrong shape (a position as a bare name, keywords as one string) is reshaped as it
lands; a step that fails says why on its row.

**No cheating.** The reader's passages are made in drawing order, each from the passages before
it and `CardProducer._drawn(K)` - cards 1..K, nothing else. Every prompt is kept beside its
reply in `jobs/`. `tests/cards_check.gd` asserts no later card's name, booklet or picture
reaches a reader prompt - the builder's and the producer's own (`say_prompt`) - two-sided.
A writer with tools could still read `draw.json` off the disk: Claude runs with none, and Codex
(whose `exec` keeps a read-only shell) is told plainly to work from the message alone and open no
file (`TextGen.Codex.ONLY_THIS`). The user's call, 2026-10-04: asking is enough - agents follow
it - and choosing the agent matters more than sealing it.

**Variety.** Each seed draws numeric dice (a place on Earth, a year, a hue, an hour, a
brainstorm pick) - no word lists - and the table samples its own layout from the seed (camera,
deck position, spread layout, shuffle moves, props, light).

**What the show has already made** (2026-10-05; the user: "without any context about what we
have already made, the models don't know what they should avoid, or what new things they should
try"). Told only to vary, the agents varied the SUBJECT and converged on the FORM. Eight episodes
in: seven decks were "painted as if it were [a craft object] from [a century]" with a human figure
centered on nearly every card, seven of seven running bits were a status revised at each card
with the third revision the punchline, every title ended on a bracketed twist, three readers said
"it is three in the afternoon where I am", and closes reused "typing I claim it claims a comment".
The producer's history had shown 140 characters of each deck's style - the medium, never the cast -
and no angle or running bit; nobody else saw any. Now `CardEpisode.archive(show, except)` reads
every other episode (plan, the cards drawn with each design's art and the reader's words, table
things, intro, close; newest first, at most 40), and each role gets the part it decides, cut short
(`CardPrompts.clip`/`tail`):
- PRODUCER: the newest `PAST_FULL` (10) in full - title, audience, topic and angle, the reader and
  running bit, spread, deck style, WHAT ITS CARDS PICTURED (the designs' art, so the cast as
  painted), stock/ink/accent/frame/face/foil/palette, cloth, room, light - and `PAST_LINES` more
  in a line. It is asked to NAME THE SHOW'S HABITS first (`habits` in its reply, kept in
  `plan.json`): the formulas under the subjects, each with how many episodes fell into it, then
  to brainstorm and plan outside them. A list alone shows eight different subjects; naming what
  they share is what makes the formula visible.
- DESIGNER: how earlier decks pictured THE SAME CARD (`SAME_CARD`, by name), to picture it some
  other way.
- SET DRESSER: the things earlier tables held, as before.
- READER: what the audience has heard at this point of an episode (`HEARD`) - the start of
  earlier intros, the first words of earlier card passages (jumpers apart), the end of earlier
  closes - with the sentences the brief gives every episode word for word left out
  (`CardPrompts.unfixed`: "Hello, my loves", the sign-off) and EVERY CARD NAME OF THE DECK MASKED
  (`mask_cards`, "[card]"), so no card reaches a reader through another episode's words.
The plan's `reader_mood` was split: `running_bit` is its own field (the reader is told "Your
running bit"), so the record shows it exactly; older plans keep it inside `reader_mood`, which the
record shows 60 words of. The look's instruction no longer presumes the cast or the period ("what
the cards picture (their cast) and how it is drawn, the medium and its influences"; it said "era
and influences ... how figures are drawn"), nor the designer's ("whatever it pictures is its own";
it said "its own people and creatures"). Gate: cards_check `_archive` (two-sided: an episode alone
in its show is told nothing; no episode is its own history; unmasked, the later card is there).
STILL PULLING TOWARD THE FORMULAS, and the user's to decide: the brief's own examples ("runs it as
a working system - with staff, policies, delays, a waiting list and a pricing page"; a running bit
is "a count that moves, a story told in installments, a claim that keeps being revised") and the
year and hour dice, which producers have read literally (a period piece of that year; the reader
stating that hour).

**The card stock** (2026-10-05, the user: "most if not all generated tarot cards have a light tan
color"): asked only for "card stock", the producer printed all four decks on cream. It stays the
PRODUCER'S CHOICE (the user: "the AI will pick more complementary colors, rather than just a random
roll" - a lightness die was tried and dropped the same day; its one episode got a muddy mauve-gray
from outside its own palette): the prompt says what the stock is (the card's own color, round the
picture and behind the name, and the booklet's), that decks are printed on every color, and to
choose the one that sets off the paintings; each earlier episode in its history shows its stock,
and "do not repeat" covers card stocks. `CardTable.sanitize_look` keeps the ink readable on
whatever stock lands (`legible_ink`, WCAG contrast >= `INK_CONTRAST` 3). EVERY FRAME KEEPS A BORDER
(feedback 0010, 2026-10-06): a `bleed` style ran the painting to the card's edge, cropped it to the
card's shape and set the name and numeral on plates over it - the name, fit to the picture's width,
ran off a plate 0.08 of the card narrower each side ("It looks nothing like other cards, from other
episodes"). It is gone from `CardTable.FRAMES`, so a plan that named it is drawn as `line`; the
picture's window is one function (`CardFaces.window`) the foil keys inside too. Gate: cards_check
`_card_frame` (every standard name fits the band below the picture in every face). THE BOOKLET IS PRINTED IN
THE CARD'S COLORS (`CardFaces.page_colors`): the stock as its paper, the ink and accent for its
type, kept readable on it (running text at `TEXT_CONTRAST` 4.5) - it was a fixed cream page.
Episodes planned before keep their cream until the plan is redone. Gate: cards_check `_card_stock`.

## The table

Static camera from the reader's chair (locked; the Tarot panel has no Camera dial), cloth from
the episode's `surface`, its `backdrop` out of focus beyond the far edge. The lamp is low and to
one side, so things throw shadows you can see.

THE SET TABLE (2026-10-05; the user: "the lack of objects upon the table makes the whole scene
rather boring... most tarot readers are very intentional about how they setup their
workspaces"). A step of its own, `table` (`table.json`): the SET DRESSER (`CardPrompts.set_dresser`,
best tier) sets the reader's table from the plan, LOOKING AT the cloth (it waits for it; a new
cloth keeps the table), knowing no card. It invents the things of the episode's world - a
field station's hurricane candle, rain gauge and calabash of rainwater; a harbor's votive stone
anchor, hematite weights and murex shell - each with its reason (the four elements the suits
stand for, the reading's subject, light, devotion) and DESCRIBES EACH TO BE BUILT: parts of
shapes (`Props.SHAPES`: lathe profiles, rounded boxes, balls, crystal points and clusters,
rings, tubes along paths, sheets, blooms), in real centimeters, of named materials
(`Props.MATERIALS`, procedural surfaces in `shaders/prop.gdshader`: metal with tarnish, wax,
crystal, ceramic glaze, stone veins, wood grain...) with ornament worked in (`Props.ORNAMENTS`:
bands, flutes, stars, moons, zigzag... as relief, paint or inlay). It names each thing's zone
(`CardTable.ZONES`), its group (things that stand together) and its turn, and is told each
zone's HEADROOM (`CardTable.headroom`: the frame's top passes low over the far cloth, so the back
holds only short things). The reply is kept as written and made safe at every build
(`CardTable.sanitize_table` over `Props.sanitize`: unknown shapes dropped, numbers clamped,
flames capped at `MAX_CANDLES`). Exactly the look's candle count is asked for; before a table is
set (or for an older episode) the look's candles stand alone (`CardTable.default_table`). The
reader is told only that the reader's own things stand there - no passage depends on them, so
setting the table again keeps the reading. NO IMAGE-TO-3D: the user ruled it out on 2026-10-05
("way too slow, and my GPU is in constant use... I'm not going to expect users to load giant
models") - no Piper-sized model exists (TripoSR and SF3D are 1.6+ GB and want a GPU). Claude
writing the geometry was the user's idea.

THE SET DRESSER SEES WHAT IT BUILDS (2026-10-05; the user, on giving the agents a loop: "offer
the agents the ability to make something, then view the model, then make revisions"). Every agent
had been one prompt in and one reply out - `num_turns: 1` on every job of the last episode - so the
table was ~5,000 tokens of geometry its author never saw, and a "CHECK each thing before you
answer" list it had nothing to check against: the squid of balls and rods, stones perched on
stones, things left off for want of room with only ghost's log knowing. Now, when the writer takes
tools (Claude), ghost SERVES them (`AgentTools`, MCP over HTTP inside the ghost process) and the
set dresser works a draft (`SetDresserTools`):
- `put` things and materials (a name put again replaces it) - answered with each thing's real size,
  parts and flames, every part or material the builder could not use and why, a thing taller than
  its zone can show, the lit/other tally against what the look asked, and a PICTURE: each thing on
  its own tile of a centimeter-ruled studio, from the episode camera's angle (`TablePreview.things`);
- `look` at one thing from four sides - front, its right, above, the camera's view;
- `set` the draft on the episode's OWN table - the show's `TableMedium`, its seed, cloth, room,
  lights, the deck, the cards laid face down in their spread - photographed from the camera's
  place, with where each thing stood, what was made smaller or LEFT OFF, and which light leads;
- `title` - the color the show's name is printed in at the opening (see "The title screen" below),
  answered with a picture of that opening and the contrast it measured behind the name;
- `remove`; `submit`, which writes `jobs/table/submitted.json` for the producer to land whatever
  the run's last words (and sends it to `set` once first, wherever a table can be stood, and asks
  once for the name's color).
30 pictures, 1500 s. Any other writer gets the one-reply prompt (`CardPrompts.set_dresser`'s
`looks` = 0). A PICTURE COMES WITH THE QUESTION TO ASK OF IT (`SetDresserTools.JUDGE_THING`,
`JUDGE_TABLE`: say what it actually shows, then whether a stranger would name it so): in the first
real run (Haiku, on a copy of #352029, 7 turns, ~22k output tokens) the loop worked end to end - put, three
looks, set, submit - but the model called a 1 cm flat disc it had named a soapstone oil lamp, and a
bare rod it had named a dried grass bundle, "perfect". The pictures showed both plainly. CLAUDE WITH TOOLS CANNOT RUN `--safe-mode`, which drops every MCP server (measured):
a tool job loads no settings instead (`--setting-sources ""`), and was measured to see no
CLAUDE.md, memory or skills. Gates `tests/agent_tools_check.gd`, `tests/set_dresser_tools_check.gd`.

THE AIR (2026-10-05; the user: "some particle and/or volumetric effects could go a long way... gentle
fog/smoke rolling in the background region (with less-severe fog in the foreground, perhaps even upon
the table)... when a card is ejected from the deck - a burst of colorful sparks... when a card twirls...
fireflies or pixies (just simple spots of color) that fly around, leaving the scene, coming back...
generic primitives... pixies flying around behind the fog, with the color effects bleeding-through").
The set dresser writes `effects` beside its things; `Effects` builds them:
- FOG is Godot's own volumetric fog, a FogVolume per fog in one of `CardTable.AIR`'s regions ("beyond
  the table" - a bank from mid-table back, thickening to the far edge; "over the cloth"; "low on the
  cloth"; "the whole room"). Its `density` is how much it HIDES over the region's `sight` (meters a
  line of sight crosses there), so a layer on the cloth and a bank behind the table read alike; it
  rolls and drifts as a function of show time, billows carved by finer wisps, soft at its sides but
  never at its floor (fading at every face of the box had made a layer on the cloth vanish exactly
  at the cloth). The lamp and candles scatter in it (their fog energy is raised when there is fog):
  halos and shafts. Unlit fog only DIMS a bright cloth, which reads as nothing: it takes ambient light.
- MOTES - pixie, firefly, wisp, ember, dust, snow - are placed on the CPU each frame (pure function of
  show time): a home on screen along a line of sight, in front of the table (homes drawn from the
  region's volume were mostly behind the table or above the frame - the camera sees only below the
  table's plane a meter past it); a wander measured as a share of the picture at its own depth; darts;
  VISITS that leave sideways and up out of frame and come back (the user: off-screen is fine, never
  bounce at the frame's edge); a soft floor, which over the table or a thing on it is that thing's top,
  falling away round it as a gentle dome - so a mote is lifted over what stands, never through it. Lit
  motes carry a tiny OmniLight, so the fog glows in their color round them; the light is nearly all the
  fog's (a surface sees 1/15), and a lit mote keeps 4 cm off what it flies over - at full strength a
  pixie skimming the cloth bloomed into a red blot. FLIES (2026-10-06) are dark specks on a planned
  flight: zips with sharp turns, hovers of a fraction of a second, now and then a short drift, out of
  the picture and back in elsewhere (the user: "flies are almost never still... a fly zips into a
  scene, hovers for a fraction of a second, then zips somewhere else"); a zip smears as a bright
  day's fast shutter would, a short dark dash. EVERY MOTE CAN FLY AWAY FROM THE CAMERA (the user:
  "a fly COULD fade, if it moved away from the camera and flew far enough away"; "a pixie could fly
  away from the camera too"): two in five leavings are off into the room past the table - with the
  camera looking down at the cloth, up the picture and shrinking - and a fly, a dark speck, also
  blurs as the room is blurred, so it fades out of sight; glows shrink to a point and the fog takes them. Each look's size and brightness stay in its own range (the user: pixies
  "quite small generally", adjustable "within constraints"): a pixie 3 mm, 1.5-8.
- BURSTS - sparks, glitter, embers, flames, smoke, stars - mark a MOMENT (`CardTable.MOMENTS`:
  shuffle, jumper, reveal, pirouette, lay, close), read off the schedule by `TableMedium._air_moments`
  with the emitter's path from the table's own poses (the jumper's flight, the held card twirling -
  `_looks` is now what `_turn_of` reads too). Particles are born on the CPU when a moment moves (most at
  its start, on the card's edge or at a point), flown on the GPU in closed form (drag, gravity), so
  any frame can be drawn alone. Tabletop scale: a few centimeters to a couple of hands.
The set dresser sees it: `set` shows the air at a moment some way in; `watch` photographs one effect
four times (a burst just after its staged moment, fog and motes 3 s apart). The show's taste is in the
brief's "The table and its air". Gates `tests/effects_check.gd`, `tests/set_dresser_tools_check.gd`;
look with `tests/air_look_probe.gd` on a COPY of an episode.

THE TABLE ITSELF (2026-10-06; the user: "right now, the table is just a flat rectangular surface, with
a texture crudely drawn onto it... give the agents the proper tools and instructions to construct their
own table, with optional tapestries, tablecloths, runners, etc. And of course, item placement changes a
bit as well, depending upon the geometry of the table"; then "the table would really benefit from some
depth mapping... normal mapping, tesselation, whatever - make such things available to the agents'
tooling"). The set dresser now writes `top` and `layers` beside its things (`Tables`, `src/tables.gd`):
- THE TOP: rect (with rounded corners), round, oval or a regular polygon, a scalloped rim if it likes;
  1.5-9 cm thick; its edge cut to a profile (square, eased, bevel, bullnose, ogee, bead) as real
  geometry - the far edge is all of the table's side the camera sees; made of one of the table's
  materials (boards with staggered ends and cut seams, tiles in grout, a stone slab, metal, lacquer
  worn at the edge, leather, a baize) or of THE PAINTING itself, with a pattern inlaid in it
  (marquetry, parquetry) and a band inlaid along its edge.
- THE LAYERS, bottom first, at most 4: each a fabric (linen, cotton, wool, felt, velvet, silk, brocade,
  lace, burlap), a pattern (stripes, checks, plaid, diamonds, dots, a generative medallion, dyed clouds,
  ikat - or the painting), a border along its hem, a fringe on its ends; an outline of its own placed by
  `at` and `turn` (45 lays a square as a diamond) or the top's own outline grown by a `drop` - a
  tablecloth. WHEREVER A LAYER RUNS PAST THE TOP'S EDGE IT HANGS OVER IT (`Tables._drape`): rolled over
  where the top's face ends, straight down, folds deepening as it falls, outward only (a fold swung
  inward put the edge through the cloth). Rows of points follow the top's outline through the roll
  (the grid alone drew it in steps), each a hair off its row: concentric rows are all but co-circular,
  and Godot's Delaunay took a second on them (now 0.25 s for a big round tablecloth).
- THE PAINTING goes wherever the set dresser lays it - the top, the cloth, a runner, a diamond - its
  pixels square there (`CardTable.cloth_crop`). NO `top` AND NO `layers` IS THE OLD TABLE: a 190 x 85 cm
  board table with the painting as a 120 x 72 cm cloth exactly where the old cloth lay; `layers: []` is
  a bare top. Every table set before keeps its look, drawn by the new shaders.
- DEPTH (the RELIEF, `table_common.gdshaderinc`): every surface has a height field below it - its own
  (threads, grain, pebble, seams and grout) and what the agent asks for (`relief`: raised or sunk
  figures, quilted, tufted, the painting's own detail). Godot 4 has no tessellation, and lifting the
  geometry would lift the cards off the cloth or sink them into it, so the field is never above the
  surface (the cards and things rest on its highest points) and is SEEN three ways: a normal from its
  own slope at every pixel (finite differences of the field, in a tangent frame taken from how the
  cloth's flat space crosses the screen - exact per triangle; the old cloth's normal map came from
  its whole luminance, every pale patch a hill), PARALLAX OCCLUSION (6-22 steps by the angle, one
  refinement: the hollows lie below the surface and the ridges in front hide them) and their shade
  (ambient occlusion, a little darker albedo). The painting's depth is its DETAIL - its lightness less
  its lightness blurred 3.5 mips - so threads and grain stand up and broad light and dark do not. The
  drape and the edge profile are the real geometry. A quilt's section rises all the way from the
  stitch (a flat-topped puff showed only seams, lost on a busy painting).
- THE TOP HOLDS THE CARDS: the deck, every preset spread, the shuffle and the wash lie in
  `Tables.HOLDS` (measured over 300 layouts in `tables_check`); a top that does not hold it 2 cm in
  from its edge is grown, its proportions kept - a round table comes out at least ~1.18 m across, its
  far edge curving across the frame. Cards given positions are refused off the top
  (`TablePositions.given(..., top)`, then the preset), a card thrown in a wash lands only on it, and
  things stand on the top 3.5 cm in from its edge, within the old cloth's stretch (the width the camera
  sees) and further back only where a deep top reaches further (`_stand`). Let out to the old table's
  whole width, or with their back edge 0.6 mm forward of the old cloth's (a 4 cm margin), the old
  table's things moved and a wash's card clipped a foot (84 of 292,240 samples in table_place_check,
  against 0 at HEAD): on the old table they stand exactly where they stood.
- THE LIGHT READS WHAT LIES UPPERMOST: the HEAT cap's lightness grid (`TableMedium.LUM_RECT`, 4 cm
  cells over the table the camera can see) is now whatever is on top at each cell
  (`Tables.surface_lum`): the painting's pixels, a pattern's colors, the top's material, the floor.
- THE SET DRESSER: told the vocabulary (`Tables.describe`), that the painting must be given a place,
  about depth, and the earlier episodes' tables (`CardEpisode.archive` -> `furniture`); `put` takes
  `top` and `layers` (answered with the table in words and whatever had to change); `remove` takes
  layers; `overhead` photographs the table from straight above with the camera's view outlined; `set`
  says the table in a line. 36 pictures, 1800 s.
Gate `tests/tables_check.gd`; look with `set_dresser_look_probe --spec` (a spec with `top`/`layers` is
put first and seen from above).

THE PAINTING'S DEPTH, PAINTED (2026-10-07; the user: "the painter-made height map, especially, sounds
like a novel idea - if you think it can truly work"). A step of its own, `image:height` (`height.png`),
listed only once the table lays the painting where its depth is read - as a layer or as the top, its
relief `painting` or its own (`CardEpisode.wants_height`, `Tables.wants_height`); it waits for the
table and is made FROM the painting (a new cloth clears it, a new table does not). The painter is
handed the painting and asked for the same image redrawn as gray height, every edge on its edge
(`CardPrompts.height_image`). AN IMAGE MODEL MAY MOVE, ZOOM OR INVENT WHAT IT REDRAWS, so the map is
MEASURED before it is used (`Tables.height_fit`, `CardProducer._land_height`): both images' structure
(the size of their gradients, blind to which way round the gray runs) at 96 px across, correlated at
every shift up to 4 px; the best is kept in `height.json` with its shift, and under 0.35 the map is
removed and the step fails (retried once) - the painting's own detail stands in. The map only
deepens the table: an episode is complete without it (`CardEpisode.complete`), the Table row counts it
only while it is made or when it failed, and an episode made before gets one from ⟳ "Paint the cloth's
depth again". The shaders read it
in place of that detail (its fine relief whole, its broad rise and fall at half), and a painted
surface whose relief is its own takes it too. First real runs (Codex, on copies of two episodes): a
calligrapher's felt at 0.83 and a red linen at 0.75, both unshifted, ~55 s each; on the linen the
threads went from soft to crisp knubs with hollows between them. A synthetic unrelated picture scores
0.18. NOT CHECKED: alignment finer than 96 px (a thread off by a pixel at 1536 does not show; a carved
line might), and other painters (Bedrock's take a reference as a style, and will likely be refused).
Probes take `--root <dir>` now (`episode_probe`, `set_dresser_look_probe`) to work on a COPY of an
episode.

THE LIGHT (2026-10-07; the user: "we sometimes have indoor scenes, and we sometimes have outdoor
scenes... it would be nice to bring the agents into this loop, giving them a way to control both
lighting and shadow"; a bright day's strong light, dusk with torches round the perimeter out of the
camera's view, a window hidden to one side, clouds - sparse and moving, or heavy with breaks the light
peeks through - and "shadows from birds... a simple, fast shadow that crosses the scene"; "I would want
to give the agents proper tooling, to create these vibes on its own"). The plans had described it all
along - "bright overhead noon sun diffused through a white canvas awning", "warm afternoon sunlight
slanting low through tall windows from one side", "cool early-morning daylight from the open sky, with
no flame on the table" - and every table was drawn alike: a dark room, a spot lamp, candles out of shot.
The set dresser now writes `light` beside its things (`Lights`, `src/lights.gd`; `CardTable.sanitize_table`
-> `light`, `{}` when it wrote none):
- THE SKY: an ambient light, and a share of it from above (a light with no shadow, so things are modeled
  from the top as an open sky models them) - its color and strength.
- THE SUN, or the moon: a DirectionalLight3D from a direction named round the table (front = from behind
  the reader, right, back = from across the table toward the camera, left, the four between, or degrees)
  at a height in degrees. Soft by its shadow filter's blur, NOT by PCSS: a sun's PCSS searches as far as
  its farthest caster (a wall a meter and more up its ray), and the blocker search then misses a
  stone's small shadow.
- WHAT IT FALLS THROUGH, at most 3: a window (panes, bars), blinds, a lattice (grid, diamonds, hexes,
  circles, stars) - each in a wall standing past everything on the set, on the sun's side, its patch of
  sun landing where it is aimed (`at`) - or leaves, fronds, branches, slats, an awning (the share of the
  table it shades is asked and its edge solved to it; straight or scalloped; its canvas tints the light
  under it), a parasol overhead. SHADOW-ONLY geometry up the sun's ray on `Lights.SCREEN_LAYER`, which no
  other light casts with; holes cut by `discard` in `shaders/light_screen.gdshader`, posed from show time
  (leaves stir, blinds sway, an awning's edge ripples). In fog the sun's shafts follow them. A sun
  through a wall stands no higher than 65 degrees (`WALL_SUN`).
- CLOUDS: two octaves of noise drifting past the sun; a cloud over it dims the sun, softens its shadows
  (a thin one) and gives a quarter of what it holds back to the sky (`CLOUD_GLOW`: a sunlit cloud is the
  brightest thing in the sky), so a thick one leaves the table about a stop darker, its shadows gone; the
  room's picture dims alike (`shade` in `table_room.gdshader`). NOT A SHADOW, measured first: Godot 4.7
  refuses a ViewportTexture as a light's projector, a DirectionalLight3D ignores a projector, and a
  DITHERED caster averaged by the shadow filter read as camouflage mottle at every quality. A real
  cloud's edge is tens of meters wide, so at a table's scale it is a dimming over seconds, not a line
  across the cloth. Four octaves let wisps cross the sun in under a second - a flicker (lights_check,
  two-sided).
- BIRDS: crossings at about the asked interval, each over the table, a flock flying together, a hawk
  circling so its shadow wheels back over the table; level quads (a level bird throws its true shape on a
  level table), wings beating or gliding by look, a little smeared along the way (`light_bird.gdshader`).
  At a pigeon's real 12 m/s its shadow is over the table for two frames, so `speed` runs from a third of
  the bird's real speed (0) to all of it (1).
- LAMPS out of the shot, at most 4, 2 casting: candles, a torch, a fire, a lantern, a lamp, a hanging lamp,
  fluorescent tubes, neon, a screen's glow, a street lamp, headlights passing, a lighthouse's beam,
  lightning - each by direction, distance and height, moved up out of the shot when the camera would see
  it (`Lights.lamp_place`, `CardTable.in_shot`), flickering its own way as a pure function of show time
  (a torch's dancing light and shadows, a sign's stutters, a screen's cuts, a strike's two to four
  flickers lighting the room).
- SHADOWS OUT OF THE SHOT (`shadows`, at most 4; the user, the same night: "a beam or a pillar might cast
  a permanent shadow over the table... a hanging rope might be gently swaying in the wind - casting a
  shadow that truly would be in constant motion (or better yet, nonlinear periodic motion)... a
  chandelier might cast shadows"): things the camera never sees, built of SILHOUETTES in centimeters up
  to six meters (`Lights.CASTER_SHAPES`: box, cylinder, ball, ring, tube along a path, sheet, grille;
  grouped two deep and copied round the upright or along a step - a chandelier's six arms, a row of roof
  beams), shadow-only on `Lights.CASTER_LAYER`, which every light that casts casts with. NOT [Props]:
  those clamp to 60 cm and are surfaces. Aimed by where the middle of the shadow falls (`shadow`, at
  `height`) and set up the ray of the light that throws it - the sun, or a lamp that casts (`by`) - then
  raised along that same ray, the shadow staying put, until it is clear of the table and out of the shot
  (`Lights.caster_place`). ROUND A LAMP (`around`) its own origin is the lamp's flame: what hangs below it
  throws its shadow down. Measured: a candles lamp inside a chandelier with a boss and cups just under
  the flame threw a blot over the whole table (each magnified five to eight times); the same iron
  chandelier under a ceiling lamp threw its six arms as spokes across the cards. It is still, or
  SWINGS - a pendulum stepped at 120 Hz from show time 0 and kept every 30th of a second, pulled back by
  the sine of its angle and pushed by a wind's lean, slow turns, gusts and turbulence near its own pace
  (`Lights.swing_at`): any time is the same swing whatever order it is asked in, and a rope swings at its
  length's period (1.43 s at half a meter, 2.13 s at one, against 1.42 and 2.01 by theory) a gentle 8 to
  10 degrees at `amount` 0.6 - or spins (a fan's blades), or ripples (a sheet's vertices waved in
  `shaders/light_caster.gdshader`, more the further they hang from its top). `put` reports what each
  shadow covers, part by part (a convex outline round two beams had claimed the sun between them was
  shade; a hoop's outline is its rim, not its disc), where on the table, and any raise; `watch` takes a
  moving one by name.
- THE EXPOSURE (`Lights.Rig.fit`): the sun and the sky brought down TOGETHER until the palest thing in
  the light (the 97th percentile of the cloth the camera sees, or the card stock) takes no more than
  `SUN_HEAT` - the day keeps its contrast, sun to shade four or five to one on a clear day. The first cut
  capped them apart: the sky held its own and a ferry's awning shade was barely darker than its sun.
  A lamp is held to `LAMP_HEAT` where its light is strongest.
- WHO LEADS: a sun or a lamp lighting the cards at least `LEAD_MIN` leads, and every candle burns as a
  fill; with nothing reaching the cards and no candle to lead, the old lamp hangs over the table after
  all (`TableMedium.LAMP_FALLBACK`). A table with no `light` - every table set before - is lit exactly as
  it was: the lamp, the fill, the room's out-of-shot candles. The room's picture now casts no shadow (a
  low sun behind the table would throw it over the cards).
- THE SET DRESSER: told the vocabulary (`Lights.describe`), to build the plan's light and make it agree
  with the room - whose PAINTING now comes with its prompt, the table step waiting for it (softly: a new
  room keeps the table) - and earlier episodes' lights (`CardEpisode.archive` -> `light`). `put` takes
  `light` part by part (a part replaces that part; screens, lamps and shadows by name; null and `[]` take away)
  and answers with where the sun falls - how much of the table the camera sees, and of where the cards
  lie - by the CPU's own reckoning (`Lights._pattern`, line for line the shader's, on integer-hashed
  noise both reckon alike; `light_screen_check` holds them together at 99% and more), how the weather
  runs in the first ten minutes, and any lamp moved; `set` photographs the light as it mostly is (the sun
  out, no bird crossing) and names what leads; `watch` takes `clouds`, `birds`, a stirring screen or a
  lamp and finds the moment - a cloud's passing (the sun out, coming over, under it, back), a bird over
  sunlit table, a sign's stutter, a strike. 40 pictures, 2100 s. The producer's `light.kind` asks for
  indoors or out, the hour, the weather and what the sun comes through, and the room's painter is told it.
Seen on real episodes before it shipped (`set_dresser_look_probe --light`): the library's window bars
across the leather toward the viewer, as its painted room has them; a ferry's awning shade with the day
spilling past its scalloped edge, a cloud taking the sunlit strip and giving it back; moonlight through
blinds with a neon sign's red glow; a 2 a.m. kitchen by one candle and a street lamp's long shadows; a
gull's shadow sweeping the palm mat; then roof beams' bars and a pillar's stripe across the shoebox's
cloth, a bell rope swinging, a chandelier's spokes, laundry rippling and a fan turning. Gates
`tests/lights_check.gd`, `tests/table_light_check.gd` (boot),
`tests/light_screen_check.gd` (GPU), set_dresser_tools_check `_light`, cards_check (archive, the table step).

SHADE, WIND AND WHAT IT CARRIES (2026-10-08; the user: "a diffuse shadow, which is softer and blurrier.
Today, it sort of feels like most shadows more or less are of the same 'quality'"; "a table under a tree,
where the shadows cast upon the table would look like those cast through foliage, gently moving in the
wind"; "petals could fall from that tree ... either blowing through the scene, or settling on the table,
or getting carried-off from the table again after another gust"):
- A SOFT SCREEN (`soft` 0-1 on anything the sun falls through; leaves 0.5, fronds 0.4, branches 0.35 when
  not said, the rest crisp): the sun is cast `Lights.SOFT_SUNS` (3) times from the one place, each a third
  of its light, each with a screen layer of its own (`SCREEN_LAYERS`, `SCREEN_MASK`); a soft screen is
  drawn once on each, its shade grown a step on one and shrunk a step on another (`grow` in the shader,
  `Lights.grow_of`: meters for an edge, noise levels for a canopy, a gap's share for slats), so its edge
  falls in thirds and the filter blurs them into a gradient. Every near thing's shadow stays crisp: the
  three suns are one direction. Rejected: a sun's PCSS (loses a stone's shadow to a far caster, as
  before), jittered sun directions (triple copies of a window's bars), a dithered caster (mottle). The
  CPU's reckoning follows (`Lights.sun_share`, and `coverage` its mean). Seen side by side on episode
  482104 under a cherry: crisp, hard cow-print blobs; soft, blurred dapples that read as a tree's shade.
- THE SKY'S SHADOW (`sky.shadows` 0-1, `from`, `height`): the diffuse shade of a big soft light is
  AMBIENT OCCLUSION - more of the sky fills from everywhere (`SKY_TOP_SHADOWED` from above at full) and
  the stage's SSAO (`SKY_REACH`, `SKY_AO`) darkens the fill in folds and where things meet the cloth; off
  again when the rig is released. Tried first and dropped: a PCSS shadow from the light above, 28 degrees
  wide - a high light's shade lies under the thing, so no pool showed, and it printed a faint moire on
  the cloth. Seen on 482104 overcast: the rope's coils and the pot gain depth; on a table a candle leads,
  the cloth's own pool stays faint (the fill is a small share of its light).
- THE WIND (`light.wind`: from, strength, gusts, every; `src/winds.gd`, `Winds`): a breeze of slow sines
  and gusts planned over the horizon from the seed - each a raised cosine, quick to rise and slow to fall,
  veering a little - so how far the air has carried a thing is closed form (`Winds.carried`), never
  stepped. One plan per table (`TableMedium._wind`), shared: a gust stirs the screens harder (`gust` in
  the shader and `Lights._pattern`), swings what hangs (the swing's push is the table's wind when it has
  one), snaps what flutters, and carries what drifts. A table that wrote no wind keeps its old light;
  what drifts there falls through a faint breath (`Winds.STILL`).
- THE WIND REACHES EVERYTHING IN THE AIR (2026-10-08; the user: "you might expect wind to effect the
  flame from candles, causing flickering (which would also chain into shadows moving) ... when there are
  little flying pixies/particles, you would expect wind to make those move"). ONLY A WRITTEN WIND moves
  them (`Winds.blows`): a room with its windows shut has still air, and STILL moves no flame or mote. The
  air is turbulent - EDDIES of 50 and 8 cm carried past on it, churning by 0.3 of its speed
  (`Winds.eddy`, `air_at`). A FLAME leans as tan(tilt) = draft / draw, its draw sqrt(g x its height) (a
  candle's 3 cm, half a meter a second), never past 69 degrees; gutters (dimmer, shorter) past 1.8 to 5
  draws (`Winds.flame`). A table candle's sprite tips on its wick and its light leans with it, so the
  shadows lean and dance; in still air the old room drafts stay. A flame inside glass, a chimney or a
  lantern - any part of its thing standing round it and rising past it - gets a tenth of the draft
  (`Props.open_to_air`). Lamps out of the shot (`Lights.flame_in_wind`): candles and torches lean (a
  torch's taller flame less), a lantern hardly, a fire is fanned brighter. MOTES: `airspeed` 0 (dust,
  snow, embers) rides the air, tossed by the big eddies, round a stretch of air the picture's size at its
  depth (`Effects._stretch`), so the shot keeps about as many; a flier (pixie 1.2 m/s, firefly 0.5, wisp
  0.25, fly 1.8) holds its place, slipping only near its limit, is carried off by what is more and flies
  home at its `back` (`Winds.pushed`, a weighted sum over the wind it remembers - pure), trembling as it
  works. BURSTS: the GPU carries each particle by the air's run since its birth less the lag still to
  make up (`air_carried`, `air_vel`; its birth's run in the transform's second column,
  `Effects.particle_xform`) - within a centimeter of a stepped integration. FOG rolls with the wind in
  place of its own `drift`. Gate: `tests/wind_reach_check.gd`. Open: a tablecloth's hanging edge in a
  gust; the cards themselves stay put (a 2 g card lifts at about 2 m/s - the reading must stay readable).
- WHAT DRIFTS (`effects` kind `drift`; `src/drifts.gd`, `Drifts`, `shaders/air_drift.gdshader`): petals,
  rose petals, leaves, green leaves, seeds, spinners, feathers - falling from above or blown in from the
  wind's side. RARE (2026-10-08, the user: a tree "coming down all at once"; "it takes days or even weeks
  for all of the foliage to fall"): `every` seconds between one coming loose in the breeze and the next
  (60 when left out, 6-600), `shake` how many a gust at its strongest shakes loose (1, 0-6); `settle`,
  `grip` (the gust that lifts one lying), `lying` at the start. No whole flowers ("blossoms" is gone:
  "whole flowers rarely, if ever, fall"). Real geometry - a cupped quad cut to its outline, lit, glowing
  through (`BACKLIGHT`), casting, blurred by the lens. Each piece lives a planned life on dice of its
  own: falls with the air in one of its look's WAYS (`ways`: flat, fluttering as a falling leaf does,
  tumbling over and over with a glide, twirling round a small circle tipped in to it), and a gust turns
  any of them over, harder the harder it blows (`Winds.gust_run`; the user saw them "fly like
  frisbies"); turns flat as it lands, lies trembling in the breeze, and each gust past its grip skids it
  across the cloth (short of what stands there) or, past the edge, carries it off - lifted, turning
  over, then sinking once clear of the table (and of a cloth hanging over it). A fall that would pass
  through a thing or the table's side is thrown again from elsewhere. Lives are filed in ten-second bins
  and planned only as far as asked. NEVER ON OR UNDER THE CARDS (a flower fell through the deck and lay
  under it): the table's `cover` (`TableMedium._cover_at`) says where the deck and every card lying on
  the cloth are at a time; a piece never comes down or skids there, and a card laid over one later pins
  it - no gust reaches it. `put` reports how many gusts lift what lies; `watch` takes a drift through the
  strongest gust ahead, and `wind` through its strongest gust.
Gates: `tests/drifts_check.gd` (the wind's closed-form carry against a summed one, gust rate, purity in
any order, never through a thing, gusts lift and grip 1 holds, no jump between frames, how often both
ways, gust shaking, the ways, a gust turning a flat one over, never on or under the cards), lights_check
`_shade`, light_screen_check (a grown copy in a gust, GPU).

BUILT IN THE ENGINE (`src/props.gd`, `Props.build`): meshes in meters, base on y = 0, each
part's surface laid out for its own girth and height so a motif keeps its shape. A candle's wax
part carries a `wick`: the flame is lit at its top, melted into a pool, and `drips` run down it.
SEEN-THROUGH material is glass for a vessel (`prop_glass`, a flame inside it shows) and a LENS
for a solid thing (`prop_lens`, screen refraction - a crystal ball turns the cloth over); a
clear crystal (clarity >= `Props.CLEAR`) is drawn as glass - opaque, a crystal ball was a pearl.
A flame lights everything but its own thing (an oil lamp's flame blew its own body white), whose
wax glows with the flicker instead (`flame` uniform). A reflection probe catches the table once
it is set, and only the things reflect it (`reflection_mask`): metal with nothing to reflect
read as paint. Look at a description alone with `tests/props_look_probe.gd`.

STONES (2026-10-05; the user: "a lot of tarot readers often have stones of all sizes: sometimes
large ones, though often a handful of small ones of various colors and properties", and "stones do
not always need to be in a dish. A lot of people would just arrange them on a table"). A `geode`
shape: a rough half rock, its hollow lined with points growing in (its rock plain stone unless
`base`). STREWN COPIES: `scatter`ed ones never touch (a crowded handful spreads wider rather than
pass through itself - three beach stones in a shell had crossed 94% of the time) and a `heap`
settles each copy into the lowest of a few spots, on the floor or resting on the copies under it,
so the floor fills before the heap rises; a `ring` can be an `arc`. A part's `material` can be a
LIST its copies take in turn (a mesh per material). THE PLAY OF LIGHT (`Props.PLAYS`, a
material's `play`), all of it lit by the engine, never emitted: silk (tiger's eye - Godot's own
ANISOTROPY, its frame turned across the fibers and rough enough to be broad), flash (labradorite -
streaky patches tipped as they lie, colored like metal), fire (opal), glitter (goldstone - tiny
tipped flakes that only the flames light), rainbow (aura quartz, paua, bismuth - a thin film in
what it reflects, its hues near the body's own: the whole rainbow read as tie-dye; a pale body
keeps its own light, or a cream shell read nearly black), glow
(moonstone); and `rings` bend a crystal's banding or a stone's veins round the middle of each copy
(agate, malachite) - every vertex carries its copy's middle and number (`CUSTOM0`, `Tris.placed`).
Lumpy balls have broad lumps (a fine second octave alone crimped a small stone like a dumpling).
FOUND ON THE WAY: `bump()` normalized a zero vector where a pore was seen edge-on, and the NaN
reached the reflection probe and blacked out everything that reflects it (a paua shell in bone);
it is guarded now and called on every pixel - a derivative in a branch some pixels skip is
undefined. A flag written "yes" crashed the sanitizer (`Props._flag`). The set dresser is told
that many readers keep stones, set on the cloth or heaped in a dish. Gate: cards_check `_stones`.

CANDLES OF EVERY FORM, AND GROUPS (2026-10-05; the user: "I would prefer if the model had a lot of
control, so that it could explore novel objects from our well-defined interfaces... short, fat ones
with 3 wicks in a triangle. Or a candelabra. Or even just tiny tea light candles"). The model still
writes DATA, never code - its expression is in how it uses the spec. WICKS as data: `wicks` 2-6 set
round a candle's top (three make a triangle) or `wicks` [[x, z], ...] placed, each standing on the
melted pool as deep as the pool is there (a single wick sits where it always did). ONE LIGHT A LIT
THING (`TableMedium._light_flames`): a candelabra's tapers or a pillar's three wicks light the room as
one light from among them, as bright as all its flames together (then capped by the cloth like any
other), so a candle costs one shadow however many flames it has; every flame still flickers on its
own dice and the light follows their mean. `_lights` (was `_flames`) holds one entry per lit thing
with its `flames`; the cap is `CardTable.MAX_CANDLES` lit things and `MAX_FLAMES` flames on one, and
the set dresser is told "Exactly N lit things" (the plan's `candles`) plus a nudge toward every form
- tapers, multi-wick pillars, tea lights, votives, a pricket, an oil lamp, a candelabra. GROUPS
(`{"parts": [...], "at", "turn", "copies"}`): a part that is parts, placed and repeated as one -
arm, cup and taper written once and copied round a ring - nested `Props.MAX_DEPTH` deep, every part
in every group counted toward `MAX_PARTS` (now 16), and `MAX_INSTANCES` parts made in all. EXTRUDE:
an outline (polygon, star, circle, rect, heart, or its own `points` going in and out) raised straight
up with `taper`, `bevel` and a `wall` that makes it a tray. Gate: cards_check `_candles`;
table_place_check counts lights and flames apart (the pair of pillars is one light, two flames). A
tall candelabra fits only where the frame has headroom - the set dresser is told each zone's.

FREE FORM: LOFTS, COILS, CORNERS AND WARPS (2026-10-07; the user: "do we literally allow them to
draw abstract geometry, in order to produce truly novel things?", "if we have a pipe shape - do agents
have the ability to create bends/kinks in that pipe?", and "I've seen a teapot that looked a bit
bulbous and strange"). The agents already drew their own curves - a lathe's profile, a tube's path, an
extrude's and a sheet's outline - so the answer is more of that, never raw vertices (typed by hand
they come back inside out and holed, and skip the foot and the heaps every built shape feeds).
THE TEAPOT (episode 882) was a `smooth` lathe: a uniform Catmull-Rom through every point sagged its
flat base below the cloth and domed its flat top, and the pot came out a ball. Now a smooth profile
keeps a flat base and a flat top flat, the curve is CENTRIPETAL (no overshoot between points far
apart and close together) and its ends run on straight. CORNERS AS DATA: any point of a profile or a
path can carry one more number, its corner's rounding in centimeters - 0 a crisp corner in a smooth
curve (a foot, a rim, the seat of a lid), r an arc that far round (a pipe's elbow) - `Props._curve`
for all of them. A crisp kink in a rod is MITERED (`_sweep`: the ring laid halfway between the two
directions and stretched across it) - it used to pinch to 0.71 of its width inside the bend. A tube
takes a `wall` (a pipe, a straw, an open spout). THE LOFT: sections (any outline, `size`, `scale`,
`turn`, `shift`, `at`) blended along a path or straight up - a spout wide at the body, a snake plant's
twisting blade (outline `lens`, to a point), an aloe, a horn, a spoon's handle; the same outline
keeps its points one for one, different ones are walked round from the same side. THE COIL: incense
coils, springs, a tendril. New outlines `lens` and `drop`, for extrudes and sections. THE WARP, on any
part: `scale`, `taper`, `twist`, `lean`, `bend` (toward `bend_to`, as a rod round a drum), `wobble` (a
field of where a point was, so crisp seams move together and never open); normals turned by the
warp's measured slope; a part warped past scaling is built with points 5 mm apart (`WARP_STEP`) - a
candle drawn top and bottom only stayed straight however far it was bent. The set dresser is told
how parts meet (a spout or handle starts inside the body) and that living plants are things the
parts make; the show's guide asks for them. Gate `tests/props_check.gd`; cards_check builds a thing
of every new shape.

WHERE A THING STANDS IS FOUND (`_place_things`, `_stand`): groups biggest first, a group's tallest
nearest its zone's middle, the rest round it - the shorter toward the reader; on the CLOTH (on the
wood by the rim it read as falling off), clear of everywhere the cards go (`_keep_out`), clear of
what stands (`THING_GAP`, `GROUP_GAP` within a group), wholly in the shot, and no group in front
of another in the picture - within a group a little in front at most (one seen through another
read as a stack). A lit thing stands only behind the middle (a candle in front of the cards
became the key and blew out the held card) and by dark cloth. A low thing may lie nearer the
reader. A thing with no room is tried smaller, then left off (logged).

NOTHING PASSES THROUGH WHAT STANDS (the user: "objects should probably have collision, and so
should the cards"): each thing's FOOT - its outline up to `Props.FOOT_H` - is an obstacle in the
planned wash. Every card moves from where it was to where the step puts it a few millimeters at a
time and is pushed back out of any foot it runs into, away from its middle (`_card_clear`,
`_push_out` by separating axes along that direction), so it slides along it and never jumps
through; a card is flung out only by a way clear of everything (`_path_clear`). The wash is still
planned once, a pure function of the seed - collision in the engine's physics would not be. Gate:
`table_place_check` (no card crosses a foot over 40 seeds; the same washes let through must).

CANDLES TOGETHER LIGHT THE CLOTH TOGETHER: the HEAT cap is on the cloth's hottest spot under ALL
the flames at once (`_heat_field` per flame, summed; every flame reaching the hottest cell dimmed).
Two tapers side by side, each at its own limit, burned a pale linen white through the bloom.

PAINTED OBJECTS WERE TRIED AND TAKEN OFF (2026-10-04): a photograph of one thing cut out of its
background brings its own camera, light and grade, and a flat card can neither take the
candlelight nor cast a shadow ("these 2D objects look awful").

FLAMES FLICKER APART (the user: "the candles flicker at exactly the same rate, which is wrong").
Every flame had one tempo and one swing, so they pulsed together. Each now has its own tempo,
steadiness and drafts: mostly a steady burn, and now and then a draft gutters it for a second or
two - a pure function of show time, so a render and a scrub see the same flame. The light leans
with its flame, so the shadows breathe. ROOM CANDLES OUT OF SHOT (the user's idea, "backlighting
behind the camera, which also flickers"): two or three shadowless, flickering lights behind the
camera and off to the sides - a warm fill on the cloth and on the card held up to the lens.
Gate: `tests/table_place_check.gd`.

EVERY LIGHT THROWS ITS OWN SHADOW (2026-10-05; the user, on a frame where "the rock casts a
shadow that is crescent-moon shaped": "most scenes have multiple light sources, and thus should
probably cast multiple shadows"). Every candle and the lamp cast, so a thing has a shadow for each
light near it, each turned from its own; where two fall together the shadow is darker. The KEY -
the candle nearest the middle that its cloth can take, else the lamp - is still the brightest, so
the deck's long shadow toward the reader leads. (Before, one key light cast alone - the user had
found every light casting strange: "the stack of cards casts no shadow... two independent shadows
for each side".) THE CRESCENTS WERE THE LAMP'S BIASES: Godot's defaults are made for rooms, and at
the lamp's distance they came to millimeters - more than a bowl's floor stands off the cloth - so
a bowl cast only its rim's ring, stones nothing, a geode a shadow standing off its foot; now
`shadow_bias` 0.005 / `shadow_normal_bias` 0.15 (the candles' were already 0.02 / 0.4). A
`light_size` on the lamp threw a white glare off a geode's rim, so its shadows soften by blur
alone. The room's out-of-shot candles stay shadowless (faint fills, six shadow passes each). Try a
lamp setting in seconds with `props_look_probe --lamp 1 --key 0 --lamp-shadow B,N,S`. NO CANDLE IS BRIGHTER
THAN ITS CLOTH ALLOWS: a key candle on the pale half of a "pine boards half covered by a felt
runner" surface flooded half the frame through the bloom, where the same light on the felt reads
as a candle (linear luminance 0.64 against 0.18); and on a near-black blanket a cream stripe just
behind the candles blew out, though the cloth round them was dark ON AVERAGE. So a candle's light
times the cloth's HOTTEST spot near it - lightness over the flame's falloff, height over distance
squared - is capped (`HEAT`), and only a candle whose cloth can take `KEY_MIN` may be the key -
on an all-pale cloth the lamp is. THE CLOTH HAS RELIEF:
its picture's luminance is its height, turned into a normal map natively
(`Image.bump_map_to_normal_map`, `RELIEF`), so the low light rakes the weave; the table wood too.

THE READER MARKS ITS DELIVERY (the user: "a real tarot reader will often speed up, or slow
down... get excited, or become serious"): `<!-- delivery: quicker, brighter -->` on its own line,
for the rest of that paragraph, and `<!-- hesitation -->` for a real stop. NOT THE TONE PRESETS -
the first cut leaned toward the panel's Tone presets and was rejected before it was heard: "they
all sound wildly different... like a totally different speaker... we need subtle inflection
shifts, pace shifts". So: three axes - pace (4% a step), brightness (a third of a semitone on the
host's formant-locked arc path, a little effort and melody) and pauses (a fifth) - each word a
step (`DELIVERY_WORDS`, intents as small combinations; a fourth axis, VOLUME - louder / softer,
effort alone - and a wider pause step, x1.3), two steps at most, and EASED: each
sentence goes half way from the last one's delivery (`_ease_leans`), in and back out. The host
takes `lean_semis` / `lean_effort` in `_discourse_plan` (`hosts/voice/test_lean.py`). A script mark
like any other (`ScriptMarks` "delivery"), so a Generative chapter can carry it too.

MORE THAN ONE VOICE (2026-10-05; the user added a Familiar to Truthful Tarot's voices: "like that
devil or angel on your shoulder: mostly silent, but sometimes they'll make a quip about something,
which the narrator could respond to"). Who a show's other voices are and when they speak is the
BRIEF's (Truthful Tarot's "## The familiar"; its old name for the reader's sincere mode, "the
familiar", became "the spell"). The framework only hands lines over: the show's voices are its
document's `voices:` (`CardsEditor._spec` -> `voices`), the reader prompt names the others and
teaches the Generative panel's own cue, `<!-- speaker: Familiar -->` on a line of its own and
`<!-- speaker: Narrator -->` to take it back (`CardPrompts.voices_rule`; a show with one voice is
told nothing); a reply's cues are held to the show's names (`CardProducer.own_voices`: any
spelling of one, anyone else's cue dropped with its words kept - a writer's "familiar" would have
become a new voice, a copy of the reader's, kept in the document); `CardReading` keeps the cues for
the voice (an inline one put on its own line) and opens every passage in the reader's voice, after
the table's rest so the rest stays on a word. The Turn row (the pause at a handover) is back in the
Tarot panel. Earlier episodes' lines keep who said them (`heard`: "(Familiar:)"). Gates: cards_check
`_familiar`, multi_voice_check `_check_cards_familiar` (two-sided). EACH VOICE IN ITS OWN COLORS (the
user: "the first can remain the rainbow color, while the next could be a different spectrum like red
through purple to blue, the third could be green to yellow"): subtitle words carry their speaker, and
`Subtitles.voice_hue` gives the first voice to speak the whole rainbow and each after it a band of its
own (`VOICE_BANDS`), swept there and back by the same flowing phase - the book's highlight too.

THE ROOM IS SEEN FROM THE READER'S EYE (2026-10-05; the user: "the backgrounds are 2D, so when
the background is just a wall or a window, it's very close to the table and the angles feel
wrong... if it's a distant landscape, the backgrounds look better"). The camera looks down 34-42
degrees through a 42-degree lens, so the frame's top is already 13-21 degrees below eye level: all it
sees past the table is a thin band BELOW the horizon - in a real room, the floor and the feet of
things. The picture had been a level photograph laid square to the tilted camera with its horizon on
the table's edge: the room seen from the height of the cloth, a wall's uprights left parallel.
Neither skewing it nor asking the painter for the camera's own tilt (image models steer poorly to an
angle) - the backdrop is asked for as the photograph models make most reliably, LEVEL at a seated
eye (110 cm), horizon across the exact middle, a 20 mm lens (`CardTable.BACKDROP_LENS`), its lower
third carrying the place; and PROJECTED FROM THE CAMERA'S EYE (`_place_backdrop`): an upright plane
straight ahead, its middle at the eye's height, 36 x 24 times its reach over the lens - so every
pixel lies in the direction it was seen from, and Godot's own perspective does the rest. The view it
was asked for is kept beside it (`backdrop.json`, written as the job is submitted); a picture made
before has none, holds nothing below its horizon, and keeps the old placement until its backdrop
step is made again. Tried on a synthetic level photograph (a checker floor and a striped wall): as a
card the wall stood upright at the table's edge; projected, the floor and a rug lay past it,
foreshortened with the table. Gates: table_place_check (two-sided), cards_check `_room_prompt`.

THE INTRO IS OUT OF FOCUS: the channel's name alone (no episode title - that is the video's, on
the platform) over the table thrown far out of focus, and the focus PULLS as the shuffle starts
(`_tick_focus`, `_lens`): the wide blur lifts over the first half of the pull, and the lens carries
on near to far. See "The title screen" below. Otherwise there is NO depth of field: a far blur behind the table drew a
band along its far edge where the sharp table and the blurred room met, so the room's picture is
drawn through its own lens blur (`shaders/table_room.gdshader`, a disc at full resolution - shrunk
to an eighth and back, the strip the camera sees past the table was blocks). The stage runs 4x multisampling and a 4096 shadow atlas with the key
light's quadrant whole, given back when the table leaves it. The camera is locked off; its dial is
gone from the panel.

THE SHUFFLE IS RUNS WITH SPARSE ACTIVITY (the user: "nonlinear behaviors with sparse
activations"): several riffles, a string of cuts, a few overhand passes - one kind at one tempo -
then nothing for a while (median ~3 s, now and then a long linger), in the MIDDLE of the table;
before the first card the deck is squared and pushed to its side (`CardReading.PUSH`, which the
first draw's rest includes). A wash is rare, once at most, and a planned simulation: the deck
flattened under the palm and spread WIDE (some cards flung well out), two flat palms working it for
most of half a minute, then six to eight sweeps round the pile over ~7 s, each taking a few cards -
a few missed and fetched by a later sweep - landing squared on the pile, so the end is a light tidy,
never the whole spread arriving at once. THE MIXING IS MOST OF IT (the user, 2026-10-05: "BARELY
shuffled at all. 3 or 4 cards might shift slightly... no changing of z-order... maybe 5 or 10
seconds long"): it had been 5 s of two hands drifting through less than one slow loop. The
ORDER is decided when two cards meet - the one sliding in on top - and held while they touch, so
it changes all through the wash and never through a card. CARDS REST ON ONE ANOTHER (feedback
0007: "many of these cards are lifted off of the table itself... they cannot rest upon each other
with a gentle tilt"): every card - in the deck, spread, or gathered in the pile - from the bottom of
the order the plan has them lying in, up, is a rigid card at the LOWEST it can lie: the plane over
the cloth under its corners and over the faces of the cards under it wherever they cross it
(`Geometry2D.intersect_polygons`), lowest at its middle - the upper hull's face over the middle,
walked to from the highest support (`TableMedium._rest_on`). So a card tips: on a card at one end,
on the cloth at the other, over the deck's edge as it slides off it, up onto the pile as it is swept
in. Exact against a brute-force hull on every card the gate judges; the plan's flat layers sit higher
on two cards in three. A wash the first card would cut short is replanned to fit, the same wash up
to its own gather.

CALM, AND NEVER THROUGH A CARD (2026-10-06, the user: the cards "'repel' each other in a way that
makes them almost bouncy - they are very unstable and they tilt far too much... the cards often
clip through each other... cards moving THROUGH each other, which should be impossible"). Measured
first, posed frame by frame: tilts to 24 degrees on heaps 27 mm tall, and some 1700 card-through-card
frames a wash - most of them as the deck spread and as the pile gathered, where only fully spread
cards were rested and the rest (the deck, the pile) were no support at all, so a card slid off the
deck through it and into the pile under it. What changed: a spread card is a REAL card's thickness
(`WASH_T` 0.3 mm, 0.1 mm between cards, where a deck slot stands for three cards); the deck
flattens to it under the palm before the first card slides (`WASH_FLATTEN`) and the pile stays flat
until it is squared; every card is rested, deck and pile included, each its own thickness; a card is
rested AT THE FRAME'S OWN MOMENT (`_wash_rest_at`), not two steps' rests blended (which pass a card
sliding onto another through its edge for a frame), in the order of the step that ends the moment -
a pair keeps its order a step after it parts, and a pair touching only between two steps is caught
at their midpoint; a card climbs one card, not a heap - one lying two or more above it it runs in
under - and a loose card three or more up slumps off (`_wash_slump`); a sweep lays each card squared
on the pile (a stiff card left with its middle at the pile's edge pivots there and every card on it
leans); and a meeting is a NUDGE (`WASH_KNOCK` 0.16, at the point where they touch, spin capped at
3.5 rad/s) - well short of evening their speeds, so nothing comes back the way it went. Now: no
crossing, no card dipping into another or the cloth, no swap, over every frame; mixing cards tip
under 2 degrees 99% of the time, 6 at most.

THROWN OUT OF THE SPREAD (the user, the same day: "when a lot of repulsion is applied, a card can get
ejected, it can land face-up, and the reader can choose to draw that card... I would expect some
ejections to land face-down, and thus NOT be drawn"): a meeting faster than `EJECT_SPEED` may throw
the card run into - surer the harder - a hop along the blow onto the cloth and wholly in the picture,
its way clear of what stands (`_eject`, `_flight_xf`; in the air it rides up over anything its edge
would dip into, `_flight_clear`). About one a wash, two at most, none late in the mixing, and FACE
DOWN: a deck card's face is never painted, so only a drawn card may come down face up - the jumper.
WHEN THE FIRST CARD IS A JUMPER and the deck is being washed as its moment comes, the wash runs on
into it (`_jumper_plan`): the mixing stops and a hard blow throws it - over about the line across its
flight, face up, its top away from the reader (toward them, reversed) - onto the fewest cards it can,
on top of them; the drawn card's own mesh takes the wash card's place as it leaves, nothing slides
over it, and it lies there until it is picked up and shown as from a riffle; then the hands gather
the rest, one card short (`_wash_jump`, `_wash_jump_xf`). Half the episodes whose first card is a
jumper hold their wash back for it (`_jumper_wash`: it begins `JUMPER_WASH_LEAD` before the jumper is
reckoned to come, the script's words at a steady pace, and runs `JUMPER_WASH_SLACK` past it); the rest
riffle as before - and either way, a wash under way when the jumper comes throws it. THE HANDS SWEEP (the user, 2026-10-05:
"cards barely move... the movements are very small, very localized... It would be much more common
for cards to sweep back, and forth, back, and forth in various directions, crossing large regions of
the table, creating chaos along their path. Today, these sort of just shift in tiny little
circles"): each palm had worked a 6 cm circle and the cards under it went round it and back - 4 cm
the longest straight run, 11 cm the farthest a card got - and the gate, which measured PATH length,
passed it. Now a palm comes down where the cards are and mostly SCRUBS: passes of 20-40 cm back and
forth across the spread, its line turning and drifting between them; or it swirls wide, or fetches
the card lying farthest out back through the middle (`_wash_gesture`). The cards slide as cards do
(`_wash_rub`, `_wash_drag`, `_wash_palm`, `_wash_move`): a palm's grip is friction-limited at five
points a card, so a card pressed whole goes with it, one caught at an end swings round behind it,
one brushed stays; each pass takes hold afresh, so a scrub carries a different few each way and
leaves some at the far end; where another card lies over a point the palm presses that one instead,
so a half-covered card is pulled out by its free half; two cards lying one on the other drag each
other, hard under a pressed card; a card run into is nudged. Now half a card's travel is in
straight runs of 15 cm or more (the circles: 4), 89% of the cards get 15 cm or more from where the
mixing found them (24%), and more than half the still cards a sweep runs over are knocked askew. Gate:
`tests/table_wash_check.gd` (two-sided: the circling wash fails four of its checks, and tiny
circles made up inside the gate fail them too). A draw: square, slide, flip, up to the camera on the LEFT beside the booklet page on the
RIGHT (shown, never read); both turn a little on their axes, and the card is now and then turned
to look at its back - either way round, its back held anywhere from half a second to five (most
looks short; a fixed-feeling 1.1-1.8 s was "the exact same length, always"), and about one look in
three a PIROUETTE (the user's, 2026-10-05: "the kind of trick a person might do in their own hands
to show off"): over to the back, held a few seconds, then on round the same way, five half turns
more, to face on again three whole turns from where it began (`TableMedium._look_of`,
`_look_angle`; gate: table_wash_check, two-sided on the holds; `table_look_probe --looks 1` says
when they happen). A lay: page out, card down into the spread. A JUMPER FLIES OUT OF A SHUFFLE
(the user, 2026-10-05: "that jump should probably happen during a shuffle - not when the cards are
just sitting there on the table, doing nothing"): it had left the deck the moment the shuffle
stopped, often after seconds of the deck lying still. Its action now opens with one more riffle,
and the card rides the top of a half and springs off it while the halves fall (`JUMP_RIFFLE`,
`_jump_ride`); the deck goes aside once that riffle is done. The voice's rest for it grew to 5.0 s.
Out of a wash under way, a blow throws it instead (THROWN OUT OF THE SPREAD, above).
The channel's name opens it, and nothing closes it but the light: THE OUTRO (the user,
2026-10-05: "a simple fade to black, after the voice is done speaking... not display the title
again at the end") - a beat after the last word the table fades to black, reaching it exactly as
the outro's silence runs out (`_end_fade`: the take's own tail in a render, the Director's outro
live), a function of show time like the rest.

**Foil** (the user's idea, 2026-10-04): each painting's brightest, most colorful pixels - keyed
per picture from its own luminance percentiles, plus anything near the frame's accent color -
print as foil: metallic, a slow breath, a glint sweeping across now and then; the scene's bloom
lets it bleed. The look's `foil` (0-1) says how much.

Everything is a function of show time (`ReadingFollower` + the schedule), so live and export
draw the same frames.

## YouTube

Built 2026-10-06 (user: "upload them unlisted... an optional flag, selected when we press the
export button"; "have Ghost Notes prompt for a credentials file... and cache those credentials for
every future login"). `src/youtube.gd` is generic. MOVED TO A COMPONENT 2026-10-07 (the user: "The
placement of the YouTube upload button is not in a good spot"): "+" on any note's panel attaches
YouTube, and `YouTubeCard` (block `youtube:`) holds the choice; every panel's `upload_meta` is the
card's title, visibility and playlist over the mode's own part (`_upload_base`: here the episode's
description, chapters, tags, thumbnail moment and record). The export menu has no YouTube items.

- **The flow**: "+" -> YouTube -> tick "Upload after export" -> (first time only: a file dialog for
  the Google Cloud "Desktop app" OAuth client JSON, kept in `user://youtube/client.json`) -> (while no
  sign-in is kept: the browser opens Google's consent page beside a "Sign in to YouTube" dialog -
  Open the page again / Copy the link / Cancel) -> the box ticks -> ⤓ -> quality -> save path ->
  render -> transcode -> upload, with progress on the status line; the link is copied. A sign-in
  that lapsed (7 days in Testing) opens the same dialog as the export starts, beside the render. The
  card's "Replace client…" replaces the kept one; "Sign out" forgets the sign-in.
- **The card**: the title is a template, `%title%: %episode%` by default (`%seed%`, `%date%` too;
  `YouTube.expand_title` drops what a missing value leaves dangling and never says the show's name
  twice); Visibility is Private, Unlisted or Public (private by default); Playlist is None or one
  of the channel's, loaded with ↻ - listing them and adding a video take the `youtube` scope, so
  the first ↻ signs in again for it (`YouTube.granted` reads the scopes kept with the token). A
  playlist YouTube refuses leaves the video up, and the status line says why.
- **Google's "Access blocked"** (fixed 2026-10-06): an account that is not one of a Testing
  project's test users gets a dead-end page that never comes back to Ghost Notes, so the dialog
  names it; add the account under Google Auth Platform > Audience > Test users, then "Open the page
  again" finishes the same sign-in. A newer sign-in replaces one still waiting.
- **The panel's fields** (2026-10-06) show the SHOW'S GLOBAL VALUES at once, New episode included:
  the description and tags are the show's; the title is one value the picked episode overwrites
  when it has a plan (as the seed is) - an edit goes into its plan too. A show with no description
  or tags yet takes the picked episode's once (the producer writes both with every plan). THE TAGS
  ARE THE SHOW'S (the user: "I want global tags, not per-episode ones"):
  the document's own top-level `tags:` line, the North Star chapters' format, edited as CHIPS like
  YouTube Studio's - × removes one, a comma (or Enter, or a pasted "a, b, c") in the box at the end
  makes chips, Backspace in the empty box removes the last, a chip past 500 characters is dimmed.
  The block keeps `episode_title` and `description` - one of each, NOTHING per episode ("I just
  don't want to store a bunch of episode-specific logic in the frontmatter"); a per-seed record map
  was tried the same day and removed.
- **The title screen**: the show's name, and under it the BYLINE - the document's `byline:` ("with
  Pen & Ink"), a field on the document card right under Title. REBUILT 2026-10-06 for the thumbnail
  (the user: the text "too small in some layouts on mobile", "always the same color... camouflaged",
  and the table showing "too much detail" - "an extremely strong blur, such that nothing is really
  visible in the scene except for the colors"):
  - THE TYPE (`CardTable.title_layout`): the name as large as a line of it fits across 86% of the
    frame, at most 15% of its height (Cinzel; "Trustworthy Tarot" went from 84 to 156 px at 1080, its
    byline from 40 to 62), on two lines when one would set it under 70% of that; the byline 0.4 of its size; the block centered
    45% down.
  - THE COLOR IS THE SET DRESSER'S (`title: {color, why}` in `table.json`, `CardTable.title_ink`):
    it is the agent that sees the painted cloth, and with tools the table set - the producer only
    describes a cloth before it is painted, and one planned "deep oxblood" was painted pale gold
    (cream measured 1.3 against it). Its prompt says the frame is the thumbnail (`CardPrompts.
    title_rule`); with tools, `title` shows it the opening and the WCAG contrast behind the name.
    A table set before this, or with no color, prints the name in cream (`TITLE_INK`) until the
    table is set again.
  - A SHADE ROUND THE LETTERS (`CardTable.title_shade`): the ink's own hue taken 85% of the way to
    black or white, whichever is further - a soft halo of stacked outlines and a smooth band behind
    the block (it was 12 stacked rects, which drew visible stripes) - so any color reads (>= 3:1
    against its shade, every hue and lightness).
  - THE BLUR is not the lens's: at its softest the bokeh left every thing on the table plain. The
    whole frame is read back through `shaders/table_intro.gdshader` - the canvas screen texture's
    mips (Godot builds each level with a Gaussian), a B-spline read of the level that carries the
    asked-for blur, mixed between two levels - at `CardTable.TITLE_BLUR` (0.04125 of the frame's
    height: 0.11 came first and was "just a smidge too blurry", the user asking for about 25% less,
    then 0.0825 was cut "another 50%"; the lens's softest bokeh, the "too much table detail" it
    replaced, measures a sigma of 6.2 px - 0.0086 of a 720 frame). Each level carries 2.07 of its
    texels of blur (measured; the first guess, 1.1, drew every blur 1.9x too wide). It lifts, eased
    through its log, over the first half of the focus pull and is then taken off (not drawn at all
    during the reading). Gate: `tests/run_quiet.sh intro_blur_check` (width at 720 and 1080, round,
    smooth, in place; the title width spreads an outline over 0.3-1.0 times the height of a 10 cm
    thing, and the widths judged against it - the lens's 0.0086, and 0.0825 - fall outside that band).
- **What goes up**: the show's name and the episode's title ("Truthful Tarot: My Episode Name";
  the exported file keeps the episode's alone), the show's description with a chapter per card timed
  from the take, the show's tags fitted to YouTube's 500 characters, and a THUMBNAIL:
  a 1280x720 frame of the saved video at the title screen - the name fully up over the out-of-focus
  table - set once the video is up (needs a verified channel; refused, the video stays up and the
  status line says why). Constants: not made for kids, `containsSyntheticMedia`, no paid
  promotion (`paidProductPlacementDetails`), category 22 (People & Blogs); the privacy is the card's.
- **Resilient**: the upload is queued (`pending.json`) the moment the video is saved, so a quit, a
  lapsed sign-in or a dropped connection leaves "Resume the upload of ..." on every YouTube card;
  resumable sessions live about a week. Each upload is recorded in `<episode>/youtube.json`, and the
  YouTube card's note shows the link.
- **Google's side**: in "Testing" the sign-in lasts 7 days, then the browser opens again. Until the
  Cloud project passes YouTube's API audit, YouTube keeps API uploads private whatever was asked
  (the status line says so when that happens). Uploads have their own quota: 100 a day.
- **Not built**: a description and tags for a reading's or a song's upload (they go up with the
  card's title alone), and making a new playlist from the card.

## Probes and gates

- `godot --headless --path . --script res://tests/cards_check.gd` - the gate.
- `godot --headless --path . --script res://tests/youtube_check.gd` and `youtube_flow_check.gd` -
  the upload's pieces, and sign-in + upload end to end against a stand-in for Google.
- `tests/episode_probe.gd` - make an episode headlessly (real quota); `--only table` sets
  just the table.
- `tests/run_quiet.sh -- res://tests/props_look_probe.gd --spec <table.json> --out x.png` - a
  table description's things side by side under candlelight, no tarot table around them (the camera
  backs off to show the tallest whole).
- `godot --headless --path . --script res://tests/props_check.gd` - the shapes themselves: flat ends,
  corners, elbows, kinks, lofts, coils and warps.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table_look_probe.gd 400 --show S --seed N --marks 1`
  - the table over an episode with a synthetic voice. `--times 3.6 --name "Show" --byline "with X"
  --ink "#1d2f5c"` photographs the title screen with a set dresser's color.
- `tests/run_quiet.sh intro_blur_check` - the intro's blur, in pixels (see "The title screen").
- `GHOST_PROBE_GPU=1 GHOST_PROBE_MUTE=1 tests/run_boot_probe.sh tests/cards_voice_probe.gd 900 --spec <md> --seed N --export 1`
  - the panel, the real voice and the table, end to end, and the export take.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/set_dresser_look_probe.gd 300 --show S --seed N`
  - what the set dresser's tools show, with no agent: an episode's table put, looked at and set, and
  the opening (`--ink`, `--name`, `--byline`). A `--spec` with `top`/`layers` builds the table itself first and shows
  it from above.
- `godot --headless --path . --script res://tests/tables_check.gd` - the table itself (`Tables`).
- `godot --headless --path . --script res://tests/lights_check.gd` - the light (`Lights`);
  `tests/run_boot_probe.sh tests/table_light_check.gd 300` - the table's own light in the medium;
  `tests/run_quiet.sh light_screen_check` - what the screens draw is what `Lights` reckons.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/set_dresser_look_probe.gd 380 --show S --seed N --light <light.json> --quick 1`
  - a light put on an episode's table through the set dresser's own tools, set, and every moving part
  watched (`--watch 0`: none).
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/set_dresser_run_probe.gd 1600 --spec <md> --seed N [--model haiku]`
  - the real set dresser at work through its tools (quota), on a COPY of an episode.
- `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/air_look_probe.gd 400 --show S --seed N --spec <effects.json> --moments 1`
  - the air over a COPY of an episode, photographed at every moment a burst can mark.
- `godot --headless --path . --script res://tests/agent_tools_claude_probe.gd` - that the installed
  Claude CLI reaches ghost's tools and sees their pictures (one short run).

## 2026-10-07: the reading's rhythm, the printed card, strands and bones, bursts

- THE READER STOPS ANNOUNCING. Episode 834225 ended every card on "let me set this one down", opened
  every card on "Oh, the ...", and described four paintings of five - the prompt itself gave "let me set
  this one down" as the example of how to lead into a move, and sent every painting. Now `MOVES` says the
  viewer watches every card come and go and a reader almost never says what their hands are doing; a
  card's passage may stop on its painting only when `CardPrompts.remarks` (seeded, 15-40% of the cards,
  never most) says so - the rest are sent no painting and no description. Each passage after the first
  is told not to open or end the way the last one did. Not yet tried on a real episode.
- THE PRINTED CARD varies: `frame.window` (rect, rounded, arch - the "window-shaped" border - gothic,
  oval, notched, octagon), `frame.corners` (square, rounded, round: the card's slab is cut to them),
  `frame.ornament` round the card's edge (vine, serpent, laurel, beads, rope, stars, scallops) and the
  booklet's `page` (classic, drop, banner, ledger). The producer chooses; the archive shows each episode's
  choice so habits are named. Foil skips the stock showing in a shaped window's corners.
- STRANDS (`Props` shape `strand`): rope (three-strand lay), cord, wire, vine (leaves), beads, chain;
  laid as a coil, a flemish spiral, a heap, a path, or DRAPED across the table in its own coordinates
  and over the top's edge - hanging as far as the path runs past it, to the floor. A strand rests on
  itself where it crosses. Draped strands stand first; the rest stand clear of them, and one that runs
  where the cards go is left off.
- BONES (`bone`: femur, long, rib, small, wishbone) and SKULLS (`skull`: human, horned with straight,
  curved or curled horns, bird) - the one exception to "no body", bone only. The brief's "things on it"
  now names both.
- SCULPT (`Props` shape `sculpt`; asked the same day: "grant the agents the ability to draw their own
  geometry ... pass a list of points ... and provide the agents with a way to check their work"). The
  first bird skull was a ball and a cone with a dot for an eye: one surface found along rays from inside,
  which can make no hole. A sculpt is STROKES in order - rods through [x, y, z, r] points (round cones,
  smooth through their joints), or a ball stretched to a `size` - each melted into what came before
  (`blend`) or `carve`d out of it, `mirror`ed across x = 0 if asked. It is a distance field meshed by
  surface nets on a grid cut from its thinnest stroke (72-144 cells across), sampled only near the
  surface (blocks, then pieces) from the strokes near each block; each point carries how shut in it is
  (`uv2.y`, looked up out along its normal and leaning off it), which `prop.gdshader` darkens. Built once
  a process (`SCULPT_KEPT`). THE SKULLS ARE SCULPTS NOW (`SKULL_FORMS`): a crow's with orbits open
  through a thin wall, nostrils through the beak, the bars under the eyes and a two-branched jaw; a
  person's with free cheek arches, deep sockets and nose, teeth and jaw; a cow's as found, without its
  jaw. The dark linings are gone. Checking their work was already there - `put` answers with a picture,
  `look` shows a thing from four sides - and `put` now also warns of a stroke finer than its sculpt is
  cut. Costs: a person's skull ~4 s to build the first time (89k triangles), a crow's ~2 s.
- BURSTS WERE NEVER SEEN: a pirouette happened to about one card in forty, a jumper in 30% of readings
  (the set dresser was not told which), and reveal/lay burst at every card, which the brief forbids. Now
  a burst on the pirouette makes the table twirl one card (`SPIN_ROOM`), the set dresser is offered the
  jumper's moment only when a card jumps, and `which` (every, first, last, [n]) picks the times a moment
  is marked. Checked on 834225's copy: glitter on the forced twirl, stars on the first card up only.
- THE GLITCH SUBTITLES WRITE AS THEY ARE SPOKEN (reported the same day: "every single new subtitle
  starts with a whole sentence of glitching text"): a letter not yet reached is not drawn, a few letters
  past the front are noise, and the reach grows a letter at a time and falls back (`glitch_reach`), as
  vortex's label pushed and popped its ghosts. Then (the same day: it "stops/pauses at comma boundaries,
  waiting for the hesitation", and "center the text based upon the total amount of it currently
  revealed"): the front is ONE STEADY SWEEP through the line, pauses and all (`glitch_front`: the upper
  hull of each word's must-be-written-by moment - never behind the voice, never speeding up), and each
  row is centered on what is written of it, so the words come out of the middle of the screen. Then
  ("the glitching is extremely fast ... holding transitions for a minimum number of frames?"): each noise
  letter holds its glyph 45-110 ms on its own clock and changes 70% of the time, as the label's letters
  stepped; the reach runs further (4-10 letters) and BACKS OFF a letter at a time part way, reaches again,
  and backs off to one (`glitch_reach`, a run of 48 steps at 12 a second).
- Next: the vine's leaves could hang off a draped vine's edge more loosely; a strand could knot; the
  serpent ornament's tail falls a few pixels short of its mouth; a sculpt's build could be faster (a
  person's skull is ~4 s of GDScript), or its grid could be coarser where nothing is thin; no real set
  dresser has sculpted yet.

## 2026-10-08: where things stand, the long row, the deck put aside, the wash's pile

The user: props stood "in a kind of arc along the top, with more or less equal spacing", 5 to 8 of
them, every one wholly in the shot, often across a cloth's edge; a row of six lay "oddly close to the
deck"; and a wash's gathered pile "suddenly just grows by 2x or 3x". Patterns guided toward, never
enforced:

- A HABIT per episode (`TableMedium._habit_of`, its own die): how far out to the sides its things lean
  (`EDGE_PUSH`, often well out, the middle left freer), and each group's own step off its zone's middle
  (`AIM_WANDER`) - so the zones' fixed aims no longer make an arc of evenly spaced things.
- The frame may CUT an unlit thing at a side or the foot, so long as `SEEN_LEAST` of its picture shows;
  never at the top (it reads as standing in the room), and a lit thing still stands wholly in the shot.
- A foot across a layer's edge scores worse (`STRADDLE`), a third of that for something large
  (`STRADDLE_BIG`: a book, a tray may lie across a hem).
- A row or arc of five or more is laid as two rows now and then (`TablePositions.SPLIT_LONG`, its own
  die); and when a card of the spread would lie within `DECK_CROWD` of the deck, the reader slides the
  deck further out (`_plan_aside`, `DECK_ASIDE` of such episodes) just before that card is taken.
  About a quarter of 5-8 card spreads; gated in tests/table_positions_check.gd.
- The wash's pile builds to the deck's height as it is gathered (each card thickened as it lands),
  not all at once as it is squared. A card slid up onto the taller pile tips ~20 degrees, where
  `_tipped`'s skewed long side dipped 0.1 mm into the card under it (table_wash_check): the long side
  is now the one kept true.
- The fan-out "wobbles and vibrates": a card sliding off another's edge tipped in a frame and back
  (4.6% of fan-out frames turned a card faster than 60 deg/s, at worst 576). Under the palm each tilt
  is now the mean of the bare rest's over a quarter second (`CALM_HZ`, `CALM_REACH`), set down on its
  highest support so it neither floats nor dips, easing to the bare rest over `CALM_SETTLE` after the
  cards are out: 0.09%, gated against the bare rest (`wash_calm = false`) as the control.
- A cutting mat's height map was refused ("did not line up", 0.03) though it was right: a printed grid
  on smooth vinyl is drawn flat, and faint scratches correlate with nothing. A map spanning under
  `Tables.FLAT_SPAN` of gray is now kept as flat (`height.json` `flat: true`) - the print lies smooth
  rather than raised by the painting's-own-detail fallback, and no image job is spent asking again.
- Next: the set dresser's prompt still names the zones as before; it could be told the table may run
  off the frame's sides and that the middle may stay free. A first look at real episodes is pending.

## 2026-10-08: the place, heard (the sound)

The user: "a lot of scenes take place in places where pure environmental silence feels inappropriate.
One scene was on a boat at sea ... others are outside, with petals falling, where the wind is
literally blowing ... another was on a dock" - and "if the wind gusts strongly, the sound increases in
strength accordingly". Then: the wind heard from where a window is, stronger on the side it blows
from, and wind in a tunnel unlike wind in the open - "make the configuration features available to
the agents, then simply draw their attention to it".

- `Soundscape` (src/soundscape.gd): synthesized, no recordings - filtered noise, struck envelopes and
  rising sines (bubbles). Wind through open air, trees, grass, rigging, eaves, canvas or a tunnel; the
  sea on a shore, against a hull, at a dock; rain on leaves, a roof, canvas, a window, the ground,
  water; a fire; a stream; crickets or cicadas. Each with where it is (`from`) and how far off.
- THE WIND IS THE TABLE'S: `Soundscape.of_table` plans the light's `wind` on the episode's seed exactly
  as `TableMedium` does, so a gust is heard as the leaves, shadows and petals move (level vs wind speed
  r = 0.97 on trees, gated). Out in the open it is louder on the side it blows from, the balance moving
  as each gust veers; `wind.from` holds it at an opening instead. THE AGENT DECIDES: a light's wind is
  heard only when the sound has a `wind` (a default open-air wind was dropped the same day - "we
  should defer to the agents"); a sound's wind with `strength` and no light wind is a wind outside,
  felt by nothing on the table.
- NEVER TO NOTHING (episode 709583, a breeze through eaves: "a big gust of sound, which drops to 0"):
  loudness was a power of the wind's speed, and a breeze between gusts is a quarter of a gust - 33 to
  46 dB between gusts and silence. Now a place ebbs and flows beside its OWN typical gust or wave
  (`Soundscape._ebb`: a floor 6 dB under it at the dial's bottom, 11 at the top, a soft swell above
  it), the wind's strength sets its level only by a square root, and what sounds in a gust waits for
  this wind's gusts. That breeze now sits about 10 dB under its loud moments.
- BOTH EARS ("100% of the waves/wind is in the right ear"): a pan law had a sound at one side 18 dB
  down in the far ear; now no sound is more than `MOST_APART` (7 dB) apart, as the voice's Lean.
- THE GUST'S SHAPE ("comes on VERY strong ... a dishwasher or a washing machine ... the ramp up and
  down seems rather fast, while the hold at volume is short"): the churn was the rumble, brown noise
  cornered near 10 Hz (5 dB of wobble against the rush's 1.4) - cornered at ~80 Hz now and under the
  rush; the 4 Hz, 60% "turbulence" became a slow drift and a little shimmer. The wind heard rises in
  ~0.5 s and lets go over ~3.5 s (`HOLD`), and breathes on three slow unrelated swells (`BREATHS`);
  the shore's breakers and the hull's swell hold and drift likewise. Clicks: a struck sound's ears ease
  across the block, a new bubble takes the quietest voice, a place fades in over 1.5 s. On episode
  709583 the 10 ms wobble went 4.3 -> 1.6 dB, and the loudest moment sits 5 dB over its loud tenth
  (was 12).
- IN DECIBELS ("are you increasing the volume in a linear fashion, or a logarithmic one?"): linear -
  one smoothing stage on the speed, steepest at its first instant, so every gust began with a jump
  (27 dB/s). Now the log of the speed is smoothed through two stages (an S-curve, as a fade), no rise
  faster than `RISE_MOST`, with gentler powers on the rush and the rumble; and since the plan is known
  ahead, the wind is heard `LEAD` (0.8 s) early, so the slow entry still peaks with the leaves.
  Gated: under 8 dB/s over a second, where the plan's raw gusts climb far faster.
- THE UNCANNY VALLEY ("it sounds ALMOST natural ... which is almost worse"), against a list of the
  usual wind recipes: the body of the wind was ONE band of white noise with a moving center - the
  "filtered noise sweep" an ear knows. Now three EDDIES, each pink noise (high-passed at 60 Hz: pink
  is heaviest at the bottom, and with nothing under it the darkest eddy churned) through a 24 dB
  low-pass, drifting on its own slow course in cutoff and level at its own wandering place; a gust's
  brightening is given back in level so it does not come in as loudness too. And a SPACE round every
  place (a four-line feedback delay network, dark, ~1.1 s, ~9 dB under the dry sound, wetter as the
  dial falls): nothing arrived dry at the ears before. The gust's rise limit is on loudness now, at
  every dial setting. Recorded or AI-generated wind was the other road - files to license or make. The fire roars, the rain thickens and the sea slaps harder in a gust.
- The set dresser writes `sound` beside `light` (rules/cards/set_dresser.yaml, `insert: sounds`,
  `sound_example`); `put` / `remove "sound"` in its tools, and `put` answers with the sound in words.
- HEARD UNDER THE READING: `ReadingPanel` mixes it after the voice's own effects (`_environment()` is
  the seam; `CardsEditor` reads the episode's `table.json`), live in the push loop and into the export
  take (made stereo), on a worker in both. Its clock is the show's (`Spectrum.stream_origin()` + pushed
  frames), and a table handed in mid-reading is picked up within two seconds.
- ONE DIAL, Environment (the Cards card, knob `environment`, 0.5): level on a curve (-30 to -2 dB),
  how hard gusts and crashes strike, and brightness (distance). It ducks up to 4.7 dB under speech and
  a slow limiter holds a place alone under -5 dBFS. At 0.5 every part sits near -32 dBFS RMS.
- Listening: `tests/soundscape_probe.gd` writes a dozen places to dist/soundscape/*.wav. Gate:
  tests/soundscape_check.gd.

## Not built yet

- The light, next (2026-10-07): no real set dresser has lit a table yet. A cloud's edge ACROSS the table
  (it dims everything at once - right at a table's scale for a real cloud, but a slow low cloud's gradient
  would need the sun's light shaped in every table shader's own `light()`). A screen for a LAMP (a street
  lamp through a window's bars at night: screens are the sun's alone). Rain running down a window, and
  water's caustics on the table (a harbor's light). Lightning's own shadows (a second directional light).
  The camera opening up under a cloud over a few seconds, as an automatic exposure would.

- The table itself, next: the first real table (episode 882, 2026-10-07) was elm boards with the
  painting as one felt mat - nearly the old table; the prompt now says a dressed table is most often
  more than one layer, and each set dresser sees the tables before it. Legs, an apron or a pedestal
  (the camera sees none from the reader's chair, but a lower camera would). A dark velvet or a bare
  dark top lets a candle burn as the key beside pale cards, which bloom (the HEAT cap reads the
  cloth, not the cards) - counting the cards would take most candles off the key: the user's call.
  The dealer is told a round or oval top and its layout is checked against it once the table is set.

- Free form, next (2026-10-07): no real set dresser has used lofts, coils, corners or warps yet. A
  rounding on an extrude's or a sheet's own outline (a rounded tray); a loft whose path is a coil (a
  conch's whorl); a warp on a crystal bends its flat faces like any other.
- The sound, next (2026-10-08): no real set dresser has written a `sound` yet, and nobody has listened
  to one under a real reading. A boat's timbers creaking with the swell; birdsong (the light's birds
  are silent); a crowd or a market's murmur; thunder with the light's lightning; the sea's size
  following the wind's strength more than a little. A dial change is heard after the few seconds the
  ring already holds.
- Pick-a-pile episodes (three piles, "all four piles say the same thing").
- Moving `Illustrations`' own job pump onto `AgentJobs`.
- Porting the tablet's follower onto `ReadingFollower`.
- Tools for the other agents (proposed 2026-10-05): the painter checked by a vision pass and
  repainted with notes (a back's half-turn symmetry measurable in pixels); the reader's
  `check_passage` (word range, the MOVES phrases, what earlier episodes said), its loop inside one
  passage only; the producer reading any earlier episode whole. Codex (`mcp_servers.<name>.url`)
  and Bedrock (Converse tool use, turns as `advance()` steps) as tool-taking writers.

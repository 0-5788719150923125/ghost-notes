# Ghost Notes: every project is a note

Opened 2026-10-06 as a proposal, for two worries of the user's that turn out to have one answer:
the six modes duplicate each other, and the product is called Ghost Notes but takes no notes. The
user decided the same day to build it, so this is now the plan, for the session that carries it
out. The first half says what we are building and why; [The plan, in order](#the-plan-in-order)
says how, step by step, and what "done" means for each. Nothing here is built yet.

**Decided by the user, 2026-10-06:**

- Every project is a note with attachable components, each a colored card in the left panel; the
  six modes become templates.
- The continuous meeting point between components is a **feed**, not a signal: Godot already uses
  that word for something else ([How components meet](#how-components-meet)).
- **No home screen.** Ghost Notes opens on the left panel, with the notes listed and the name and
  tagline at its head. The Environment panel moves behind a fourth button in the bottom-right row,
  open until the user first closes it ([The shell around the note](#the-shell-around-the-note)).
- **One transport** - play, pause, stop and the scrubber - for every note, out of the voice's card
  ([The transport](#the-transport)).
- **Two frames**, landscape 16:9 and portrait 9:16, exported in either where the presentation
  allows ([Two frames](#two-frames-landscape-and-portrait)).
- **An Android build that takes notes and nothing else**, behind a capability gate every component
  declares against ([Platforms](#platforms-desktop-and-android)).
- **A repository of its own**, `../ghost-notes`: flat, with the GDScript folder renamed `src/` and
  build scripts in `scripts/` ([Step 0](#step-0-move-to-ghost-notes),
  [Step 1](#step-1-build-scripts)).

**And from the user's answers to the open questions, the same day** ([Questions, answered](#questions-answered)):

- **One window:** the note's text while you write, its stage while it plays.
- **Notes live in a default folder, and anywhere else the user points** - other folders, other
  repositories, single files - behind one storage interface, so a database can come later.
- **Diff notes:** a note can be a copy that stores only its differences from its base.
- **Ghosted stays**, until it proves unused. **Colors** are a family default a note can override.
- **Tarot generalizes into Cards**: any deck, any table, actions an agent drives through tools, and
  everything tarot-specific in the guide ([Cards](#cards-tarot-generalized)).

## The idea

One thing instead of six modes: a **note**, and Ghost Notes opens on a list of them, the way a notes
app does. A new note is a plain text editor and nothing else. Everything ghost does today becomes a
**component** attached to a note. Write a script and attach a voice, and the note speaks. Attach
the tarot table, and the voice reads at a table. Attach scenes, and the show answers the voice. In
the user's words: every project within this app is, at its core, a note.

The left panel stops being a bespoke layout per mode - hard to read, because it shows everything a
mode can do at once - and becomes a stack of **cards**, one per attached component, each bordered in
its component's color (the generative voice in turquoise, say), so it is always plain which settings
belong to what. Cards collapse, and a row of buttons on the note, one per component, opens and
closes them.

And nothing is wired. Attaching a component is declaring it, which is how the rest of ghost already
works: a scene declares what it can morph from, a medium declares the settings it uses, and the show
is a function of what was declared. That is a selling point, and
[Why nothing is wired](#why-nothing-is-wired) is why it holds.

How components blend was the open question; [How components meet](#how-components-meet) is the
answer the plan builds on. What follows: what the code already has, where the duplication is, the
model, how components meet, the shell around the note, the two frames, the platforms, prior art,
risks, and the plan.

## The note is already half there

**Documents already carry their components, keyed by the wrong thing.** Generative, Synthesis and
Tarot sync to a plain markdown file the user owns and keep their settings under its `ghost:`
frontmatter key (`FrontMatter`), one block per PANEL. So the same components are written in two
shapes:

|             | a Generative chapter                                                                  | a Tarot show                                                                                        |
| ----------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| the block   | `ghost: generative:`                                                                  | `ghost: tarot:`                                                                                     |
| the voices  | `turn, tab, voices{...}, hesitate, hesitate_on`                                       | the same                                                                                            |
| the picture | `medium, filters, scene_hold, flourishes, camera, hand, intro, outro, film_frequency` | `filters, intro, outro`                                                                             |
| its own     | `illustrations`                                                                       | `show, seed, cards, reversals, jumpers`, the writer and painter with their models and efforts, `episode_title, description` |

The voices and the picture are the same components in both, and `CardsEditor._doc_capture` takes the
Generative block and erases six keys from it. Open a chapter in Tarot and its voices are not there.
In a note, `voice:`, `picture:` and `tarot:` are siblings, and a block being present is what
"attached" means.

**Ghost already keeps notes - one per mode.** An unsynced draft is saved in ghost.cfg as
`[generative] text`, `[tarot] text` and `[synth] text`: one unsaved note per mode, and nowhere to
put a second.

**Settings with no home end up in other modes' panels.** Auto has no panel. Its picture settings
(Look, medium, scene hold, flourishes, bookends) drive the Director in every mode but Masking, and
the only places to change them are the Generative panel and, for the Look and the bookends, the
Tarot panel - on purpose: "one place to reach for a setting beats an architecturally tidier second
home nobody finds" (`GenerativeEditor._build_picture`). A card is that second home, and it is found
because it appears wherever a picture is made. The same settings are also stored twice, globally in
`[director]` (the film frequency in `[films]`) and per chapter in `picture:`.

**Presentation was pulled out of the modes once, and it worked.** media.md: "Not a mode. Modes decide
what _drives_ the show (a song, a storyboard, a voice). A medium decides what the show is _presented
as_, and every mode gets both." That was the first mode taken apart into pieces.

**The panel already follows declarations rather than branches.** `Medium.USES` lists the setting
groups each medium shows, written after "a number of settings currently being displayed that ONLY
work with the comic book medium", and its comment states the rule this note generalizes: "adding a
presentation is an entry in these tables, never new control flow somewhere else." `Filters.REGISTRY`
builds its own rows, and every one of the 29 entries in `ScriptMarks.REGISTRY` carries a `modes`
filter, which becomes a component filter. (23 are Generative's alone and 6 are Generative's and
Synthesis's; none is Tarot's, so the tarot brief's editor shows an empty palette.)

**Moments exist twice already.** `CardTable.MOMENTS` (shuffle, jumper, reveal, pirouette, lay,
close) are what the air effects fire on. In Synthesis "the fishing owns the MOMENTS"
(`Director._should_change`): a catch or a seed jump cuts the scene. Both are one part telling another
that something happened - the second through a flag the Director checks for one mode.

**Sound already meets in one place.** `Spectrum` is "the one place that knows audio exists": it
analyzes the Master bus, so a song and a voice take reach the scenes the same way, and it owns the
show clock (live, baked, or counted from frames in a render). The Generative editor says it
outright: "Everything DOWNSTREAM is shared, because a take is just a WAV." A clip is the exception:
Masking plays on its own bus and never reaches Spectrum, and a film panel is muted, so no clip's
soundtrack moves the scenes today. Pictures nearly meet in one place too: the Director owns the
picture settings, and main.gd builds the medium and hands it to `Director.attach`.

**A blackboard already runs.** `CardEpisode` is one: each step posts a file, a step runs when what it
needs exists, and a redo invalidates what was made from it. That is the shape agents should keep
when they work for any component.

**The card is an engine node.** Godot 4.7 ships `FoldableContainer` - a titled, collapsible container;
`add_title_bar_control()` puts buttons in its title bar, and its `panel` / `title_panel` styleboxes
carry the border - and `FoldableGroup`, which keeps one open at a time (`allow_folding_all` lets all
close). Checked against 4.7.2's ClassDB. Ghost uses neither yet.

## Where the duplication is

**The duplication is in the shells, not the engine.** Director, Spectrum, the scenes, the Exporter,
Chrome and the registries are shared. What is copied is everything around them: the panels, the mode
wiring in main.gd, and persistence.

- **Panels are built four ways.** SidePanel (Synthesis, Generative, and Tarot by inheritance),
  Manual's `Workspace` (its own PanelContainer), Masking's own full-height panel, and Auto with none.
- **Synthesis and Generative mirror each other by copy.** The header, the ScriptWriter wiring, F2 to
  hide, the status line, and the autosave with its persist-on-exit are copy-paste. Generative's
  `_write_wav` repeats `Voice.write_wav`. Document capture/apply and the subtitle sidecar were written
  in parallel and have drifted.
- **Tarot inherits Generative and spends its effort removing things.** 24 overrides.
  `_doc_capture` erases six keys the base wrote, `_build_cast` hides the Hesitate row after the base
  builds it, Intro and Outro are declared a second time, and the base null-checks rows Tarot never
  builds. One row nobody removed: Ink, the pen a voice writes in on the Notebook, shows on the tarot
  table, and the tarot show's Familiar carries `ink: red`, which only the Notebook could read.
- **main.gd starts a session three ways.** Three start/stop pairs (each one detaches, calls
  `Spectrum.begin*` and `Director.attach`, and sets up subtitles), three subtitle-attach paths, and
  the Exporter wired by copy with different values. Space is bound in three places and means two
  things (see [The transport](#the-transport)).
- **Masking predates Chrome and rebuilt it.** It has its own feedback console and its own Assistant:
  launched from the home screen, that is a second Assistant beside Chrome's, and Assistant has no
  single-instance guard. It has its own export, which never received the Exporter's virtual-display
  render or its streaming transcode. Its track import dialog was copied into Generative for films.
- **Every control is listed three or four times within its own mode.** Generative's voice:
  `SLOT_DEFAULTS`, `_capture_slot`, `_apply_slot`, the builder and `_apply_fx`. Masking's 54 options are
  built, re-synced and shown or hidden in three separate places (a comment there records the bug that
  caused). `Settings.bind` exists to remove the persistence half of this, and no mode panel uses it.
- **Three agent pickers** (Tarot, IllustrationPanel, the home screen): two check availability, one
  lists models, one binds its setting.

A component is the unit all of these collapse into: one card builder, one capture/apply, one
frontmatter block, one place it is torn down.

## The model

### The note

A markdown file, as now: frontmatter, then a body. Notes live where the user already keeps them -
rift's chapters and shows are notes today - and Ghost Notes remembers the recent ones. With nothing
attached, it is a text editor. The file stays plain markdown that any editor can open: marks are HTML
comments and settings are frontmatter, and nothing a component does may change that.

Every note has one card that cannot be removed: its own. Title, author and book, or a show's byline
(ScriptWriter's fields today), the seed, the frame (landscape or portrait, below), and the bookends
once anything plays. Unity's Transform is the precedent,
the one component every object has. It takes no component color; it is the paper.

### A component

An entry in one registry shaped like `Medium` (key, label, blurb, `make()`, a base class with small
hooks), which is the closest thing ghost already has. An entry declares:

| field       | Voice, for example                                                                        |
| ----------- | ----------------------------------------------------------------------------------------- |
| key         | `voice` - its block under `ghost:`                                                        |
| label, icon | Voice, a waveform                                                                         |
| family      | `voice` (below); the family gives the color                                               |
| needs       | the text                                                                                  |
| provides    | audio, a reading position, moments (sentence, speaker change)                             |
| requires    | components it attaches with it (Book brings Illustrations), as Unity's `RequireComponent` |
| marks       | its groups of the script palette (`voices`, `pronunciation`)                              |
| card        | its panel builder                                                                         |
| tools       | MCP tools an agent may call while it works (optional)                                     |

Needs and provides are typed names that ghost matches, the way a scene's `morph_out` and `morph_in`
already are.

**A family says how many.** Some components are alternatives: one presentation per note (Comic,
Book, Notebook, Tablet, the tarot table; full frame when none is attached). Some stack, like Look
filters. Some are one card with plurality inside: one Voice, with a tab per speaker. The family
declares its count, and nothing checks pairs. `Medium.OWNED` becomes a component that brings its own
presentation: attaching Tarot attaches the table.

**Speakers belong to the note, not to the voice.** The cast is read from the text's speaker cues,
and other components want per-speaker settings. The Notebook's ink is one; it lives in the voice's
slot today only because that is where the speakers were. Make the speakers the note's own and let
each component add its fields to them: Voice adds the voice, Notebook adds the ink. Tana and Logseq
solved the same collision the same way - a field has one identity, whichever tag uses it.

**In Godot terms.** A component is a node under the note's node, and Godot's own advice fits:
"design scenes to have no dependencies". The meeting points below are services the note hands its
children - Spectrum and the Director already are autoloads - and groups answer "which attached
components provide a reading" without an entity-component framework.

### A card

One `FoldableContainer` per attached component. The border is its family's color; the title bar holds
its icon, name, the toggles, and a small menu: defaults, "Same as..." (take this card's settings from
another note - the Narrator from the tarot show, say; Xerox Star's "Same" command), detach, help. A
few essential controls show, and the rest sit behind "More" - two levels, never three. A value that
differs from its default is marked and has a reset, as in Unreal's Details panel, because "what did
I change" is half of why the panels are hard to read now. A need nobody provides is a sentence on the
card ("the Notebook follows a reading - attach a voice"), never a control that silently does nothing.

**The color follows the component everywhere:** the card's border, its chip on the note, its marks
highlighted in the text (speaker cues in turquoise), its moments on a timeline. The note and the
panel then explain each other.

**Color is per family, not per component.** That is how every system that uses color this way does
it: Scratch and Blockly categories, Blender's socket colors, TouchDesigner's operator families. Hues
run out near eight, and since most families allow one member per note, within a note it still reads
as one color per component. The two voice engines share turquoise; the presentations share another.
One saturation and lightness for every hue, as Blockly fixes them, checked in both themes, and never
color alone: always the icon and the name. The family's hue is a default: a note can recolor any of
its cards (the user's rule for open choices: when in doubt, be flexible).

**Order is derived, never dragged.** Text, then producers (Tarot), voices, sound, pictures, the
presentation, and the Look last. Read top to bottom, the panel says what happens to the note. Blender
lets the user reorder modifiers because there order changes the result; Figma fixes its effect order
by kind instead, and Observable runs cells by what each needs. Here order is a fact of the families,
so the panel derives it.

### The component row

On the note, under its title: one chip per attached component in its color, then "+". A click opens
or closes that card; Ctrl-click opens it alone and folds the rest, as on Blender's panel headers.
"+" lists what can be attached, grayed with a reason when something cannot be: no agent installed
(the home screen's gating, moved here), or not on this device
([Platforms](#platforms-desktop-and-android)).

**"+" suggests what the text already asks for.** Speaker cues suggest a Voice, `<!-- url: -->` marks
the Tablet, a `## Cards` section Tarot, image marks Illustrations. Ghost infers this already
(`TabletScript.is_tablet`), and tablet.md's rule is "what is inferred, never written". Suggested,
not attached: attaching can start a model download or an agent.

**Three booleans, kept apart.** Blender saves all three per modifier.

- **Open** - a view state. Folding never changes the output. The viewer's, kept in ghost.cfg, so the
  user's files do not churn with it.
- **On** - evaluated or not. Off keeps every setting, so switching back restores it (Notion and
  Anytype keep a converted block's fields dormant the same way). The note's, in its frontmatter.
- **Ghosted** - evaluated but not heard or seen: Blender's Outliner splits "hide" (still evaluated)
  from "disable" (not evaluated). This one is exactly a **ghost note**, a real musical term: a note
  with rhythm and no pitch. A ghosted voice still sets the show's time and its moments and is not
  heard; a ghosted song still drives the scenes, for a picture-only export cut to its timing - which
  is also how a Short made on a commercial song avoids a Content ID claim: the song is added
  afterward from the platform's own licensed library. Notation writes a ghost note in parentheses,
  and the chip can too. Unity's rule decides where it
  appears: a toggle shows only where it changes something, so the Look has no ghost state.

```
 panel                                note
┌─────────────────────────────────┐   ┌─────────────────────────────────────────┐
│ What is the 7th Realm?          │   │ What is the 7th Realm?                  │
│ Pen · North Star                │   │ [● Voice] [● Tablet] [○ Look] [+]       │
│                                 │   │                                         │
│ ┏ Voice ━━━━━━━━━━━━━━━━━ ● ▾ ┓ │   │ <!-- url: risingsun.society -->         │
│ ┃ Narrator │ +                ┃ │   │ ...                                     │
│ ┃ Model  libritts-high   ▶    ┃ │   │                                         │
│ ┃ Pace   ─────●─────          ┃ │   │                                         │
│ ┃ More ▸                      ┃ │   │                                         │
│ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │   │                                         │
│ ┏ Tablet ━━━━━━━━━━━━━━━━ ● ▸ ┓ │   │                                         │
│ ┏ Look ━━━━━━━━━━━━━━━━━━ ○ ▸ ┓ │   │                                         │
└─────────────────────────────────┘   └─────────────────────────────────────────┘
```

## How components meet

The idea leaves this open, and this is my answer: **components never refer to each other.** If Tarot
has to know that scenes exist, every new component pays for every old one - n squared pairs - and
that is the trap the modes are already in (the Director's `_game_paced` is the fishing game reaching
into the scene cutter). Components meet only through things the note owns. There are five.

1. **One clock.** Every output is a pure function of show time, which films, the tablet and the
   export already obey. One component conducts - its length is the show's - and it is chosen by a
   fixed order, never asked: a voice, else a clip, else a song. That is always audio, which is also
   what ffplay and Godot's own sync guide make the master clock. With none of them, the note is not
   timed and shows no transport.
2. **Feeds.** Continuous and typed: the audio (one mix; a song ducks under a voice), the spectrum
   and harmonic signature (`Spectrum`, unchanged), the reading position (`ReadingFollower`). A
   component reads what it needs and never asks who made it. Values are clamped and NaN-guarded once,
   at the source, as VCV Rack does for its voltages (a NaN has spread through ghost before).
3. **Moments.** Discrete events on one schedule: a sentence, a speaker change, a mark reached, a card
   laid, a catch, an onset, a cut. Computed ahead, the way the tablet already computes its actions
   into the voice's rests, so a moment falls on the same frame live and in an export, and a scrub
   lands in the middle of a schedule. "The scene cuts when a card is laid" is then a Scenes setting
   that names a moment - not code in Tarot, and not a flag in the Director.
4. **Places.** A presentation offers places a picture can go: comic panels, the tablet's screen, the
   notebook's clipped photos, the book's illustrations - and, why not, the faces of the tarot cards
   or a window behind the reader. Picture components fill places. The comic already does exactly
   this with scenes in panels, and it is the most direct route to "scenes + tarot" meaning
   something.
5. **Seeds.** One seed per note. Each component draws from it XORed with its own key, the fold
   `Director._pick_salt` already uses. Attaching or switching off one component then never changes
   another's draws, which is what makes switching one off a fair A/B.

Feeds are the continuous half and moments the discrete half - the same split harmonic_seeding.md
makes for a song's signature, one level up, and the split functional reactive programming began
with: Fran's behaviors are values over time and its events are occurrences (Elliott and Hudak,
1997). TouchDesigner and Max keep streams and events apart for the same reason.

**Why "feeds", not "signals".** Godot already uses that word for something else. A Godot signal is
an event: an object emits it, and every connected function runs, there and then. A feed is a value
over show time, and it is read, never delivered: a card that wants the voice's loudness asks for it
at a time. Moments are not Godot signals either, though they are closer: a scrub and an export must
find a moment again, so a moment is a row in a schedule, asked for by time, not an event fired once
and gone. Godot's signals keep the job they have in ghost now: telling whoever listens that
something happened, as `Director.filters_changed` and `CardProducer.changed` do, and a control
telling its card it was moved.

**Modulation is the creative half.** The five points are plumbing: they make a combination work.
What makes it interesting is modulation as Bitwig does it - any numeric control on any card can be
offset by a feed or a moment, within a range drawn on the control itself. The Look's static rising
with the voice's loudness, the scene hold shortening while the Familiar speaks, the camera easing in
on `reveal`. Ableton's macros are the other half: a few dials on the note's own card, each fanning
out to many controls with ranges. Both are data on the card that consumes them, so neither breaks the
rule above. Few dials, small steps, eased per sentence - never a switch.

**One place where order matters: text walks.** Components that own marks rewrite what the voice
reads. The tablet strips its marks and leaves rests (`TabletScript.speakable`), and Tarot swaps the
body (a brief, never read aloud) for the episode's script. Today the tablet's walk is an `if` in
`GenerativeEditor._reading_of`, and Tarot's is two overrides of the base (`_reading_body`,
`_reading_of`). In the model it is a chain of walks ordered by family, and it is the only chain.

**The text as a feed, optionally.** With no voice, the words could still steer the look. SimHash,
the hash harmonic seeding runs on chroma, is best known on text - Google's near-duplicate detection
(Manku et al., 2007). The same note would give the same show, and a lightly edited note a lightly
different one. As a bias on the seed, not a replacement - and a hash of the saved note, never of a
live value: the Director dropped harmonic seeding's `seed_bias` because it could not be reproduced
frame for frame, and a note's text can.

### Three combinations, walked through

- **Voice + Cards + Scenes**, a tarot reading. Cards, with the tarot guide, needs the text (as its
  brief) and agents, and provides an episode script (a text walk), the table (a presentation) and
  moments. The voice reads the script. Scenes need a place; the table offers the card faces, and
  Scenes cuts on `lay`. Nothing in Cards names Scenes.
- **Clip + Voice**, a narrated video. The clip provides a picture and audio, and it conducts, so a
  reading longer than the clip is a gap the card names ("the reading runs 40 s past the clip").
  Masking's effects ride on the clip, or open its workspace.
- **Song + Notebook.** The notebook follows a reading, and a song provides none. The card says so and
  offers two fixes: attach a voice, or a lyrics-alignment component that would provide a reading
  from a song. The types are what find the missing piece.

## Why nothing is wired

Scratch and Blockly have the user snap blocks together; Max, VCV Rack and TouchDesigner have wires.
In those tools the parts are running processes that must be told where to send their output, so the
wire is the program. Ghost needs no wire for the same reason the rest of ghost needs none: **ghost
is declarative.** A part says what it is and what it reads, and the engine derives the rest.

- A scene declares its render kind, and the geometry it leaves and can grow from (`morph_out`,
  `morph_in`). When the types match the Director morphs, handing over a typed payload; when they do
  not it cuts, "so a bespoke transition can never break". Typed ports, matched by the engine, have
  shipped since June.
- A medium declares the settings it uses: "WHAT A MEDIUM USES IS DECLARED, NOT BRANCHED ON".
- A storyboard is data, every number a sampleable range, and the scene-spec north star is "a
  declarative spec that _samples a configuration_ ... rather than from hand-written code".
- The tarot table is, in its own words, "Planned, not engine physics: the table is a pure function
  of show time", and so are the tablet's screen, a film's frame (`Films.position_at`) and the
  book's opening.
- Agents write data, not code: the set dresser describes things in the vocabularies `Props` and
  `Effects` publish, and ghost sanitizes and builds them.
- The show as a whole "is a pure function: the seed is `hash(fingerprint(audio):SEED_SALT)`", which
  is why a six-hour render's schedule replays in about a minute (its seed and running order exactly;
  its cut times, not yet).

In a declarative system the declarations are the program, and the graph is implicit in what each
part reads. A spreadsheet works this way - it recalculates in the right order, and nobody draws
wires between cells - and so does Observable. Attaching a component is one more declaration, and
there is nothing left to connect. Where a real choice remains (which place a picture fills, which
moment a cut follows), it is a picker on the card of the component that consumes it: still a
declaration, never a cable.

**It explains the duplication, too.** The duplication sits exactly where ghost is NOT declarative.
The engine is registries and functions of show time, and it is shared. The shells are hand-built
panels and imperative session wiring in main.gd, and they are copied. The note model is the
declarative style finishing the job: the component registry does for modes what `Medium.USES` did
for the panel.

**Honestly graded.** Not every part is a pure function. Cloth, boids and murmurations integrate
state frame by frame, and the harmonic signature is an EMA: deterministic from the seed under the
render clock, close but not bit-exact live (harmonic_seeding.md's caveat). Agents are not functions
at all - the same prompt gives a different reply - and ghost already handles that the right way: an
agent's output is written to a file when it lands, and from then on the show is a function of that
file ("a redo is a delete"). The claim that holds everywhere is the one that matters: **the show is
determined by what is declared.**

**That is a selling point**, and it reads as one:

- **Nothing to wire.** Write, attach, play. No patching, no node graph.
- **The same note makes the same video.** Seeds and agents' outputs are kept, so an episode plays
  back as it was made, and an export can be replayed.
- **The note is the project.** One plain markdown file to read, diff, version and share (the
  generated pictures aside - see the open questions).
- **Agents write data, not code.** An agent describes and ghost builds: a bad answer is sanitized,
  never executed, and what an agent made is kept.

## The shell around the note

Three changes the user decided on 2026-10-06, all in the shell, none in the engine.

### No home screen

A notes app opens on its notes, so Ghost Notes does. The left panel is the first thing on screen,
and it lists notes:

```
┌─────────────────────────────────┐
│ Ghost Notes                     │
│ A Spectral Experience           │
│                                 │
│ [New ▾]  [Open…]                │
│                                 │
│ What is the 7th Realm?    today │
│ Trustworthy Tarot     yesterday │
│ Untitled                  Oct 3 │
└─────────────────────────────────┘
```

Opening a note turns the panel into that note's cards, with "‹ Notes" at the top to go back, and
the main area into the note: its text while you write, its stage while it plays - one window, the
user's choice. While no note is open, the main area shows the name and tagline in large type: the
home screen's title, with no controls on it. (The user called the tagline the byline; in the code `byline:` is already a tarot
show's own line, "with Pen & Ink", so this plan says tagline.)

Everything on the home screen (`src/splash.gd`) gets a new home, and nothing is dropped:

| on the home screen                                                       | moves to                                                                                                    |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| the name and tagline (`Boot.NAME`, `Boot.TAGLINE`)                       | the head of the notes list, and the stage while no note is open                                             |
| six mode rows                                                            | templates, in the list's New menu                                                                           |
| agent gating (`Splash.AGENT_ROLES`, `missing_roles`, `agents_tooltip`)   | the component registry: anything needing a writer or a painter is grayed with the same tooltip, in "+" and New |
| Import… and the path or URL field (`[audio] last`, `[video] last`, `[ui] kind`) | the Song and Clip cards; a file or link dropped on the list makes a note with that component attached |
| the Assistant dropdown (`[assistant] backend`)                           | the Assistant's own panel (💬), its only user; its gap message says "chosen on the home screen" today       |
| the key hint (F11, the feedback key, Esc)                                | tooltips                                                                                                    |
| the Environment panel (`DepsPanel`)                                      | its own button in the bottom-right row                                                                      |

**The list.** The notes in the default folder and in every folder or file the user has added - a
rift chapter, a git repository - newest first, all through one storage interface
([Questions, answered](#questions-answered)). The unsaved text ghost
keeps per mode in ghost.cfg (`[generative] text`, `[tarot] text`, `[synth] text`) becomes ordinary
notes the first time the new shell starts, so nothing is lost, and ghost.cfg stops holding text.

**Startup.** `main._ready` shows the list where it called `_show_splash`. Flags that open something
directly keep doing so. `--no-splash` has nothing left to skip and goes; `--note <path>` opens one
note; and once modes are templates, `--template tarot` replaces `--cards` and `--synth`. Today
`--mask-edit` builds its editor before Chrome exists, so a command-line Masking session has none of
the shared furniture; with one session path, it does.

**Leaving.** Today the only way back to the home screen is Auto finishing its song: Manual and
Synthesis loop, Generative and Tarot never finish, Masking never reaches the clock, and Esc quits.
"‹ Notes" is a way out of every note, which is why teardown comes before the list replaces the home
screen (see the plan).

### The Environment button

The bottom-right row is three buttons - from the right, 💬 the Assistant, ⤓ export, >\_ the console -
each pinning its own 40-pixel button at a fixed offset, added one by one in `Chrome._ready`, so a
hidden ⤓ leaves a hole. Chrome builds the row as one container instead: each piece of furniture
adds its button, a hidden one closes up, and a fourth is one more button. The Environment button
goes at the row's left end, so the three keep their places.

**Open until the user closes it.** `[deps] open`, default true, written whenever the user opens or
closes the panel. A first launch shows it; the user learns where it lives by closing it; from then
on it starts closed. It replaces `[deps] collapsed`, the header toggle, which the button makes
redundant. Two things carry over from today's panel: a problem the probe finds opens it without
writing the setting, because a missing dependency must be seen; and its one-line state
(`DepsPanel._refresh_title`) becomes the button's tooltip and a colored dot, so a problem shows while
it is closed.

**One panel above the row at a time.** The console's log, the Assistant's panel, the export's
status line and now this panel all open into the space above the row, and nothing stops them
overlapping. Opening one closes the others.

### The transport

A show starts and stops four ways today, Space means two different things, and there are two
scrubbers:

| mode              | play, pause, stop                                           | Space           | scrubber                                  |
| ----------------- | ----------------------------------------------------------- | --------------- | ----------------------------------------- |
| Auto, Manual      | none: the song starts with the session and cannot pause     | skips a scene   | Chrome's, while the song can seek         |
| Synthesis         | click a seed to start it, again to stop                     | skips a scene   | none                                      |
| Generative, Tarot | buttons in the Voice section, halfway down the panel        | play/pause      | Chrome's, through the editor's scrub hooks |
| Masking           | none                                                        | play/pause      | its own timeline                          |

**The transport belongs to the clock, so to the note.** One bar along the bottom of the stage -
play/pause, stop, the time and the length, and the scrub rail - built as Chrome furniture, so every
note gets the same one, Auto included, which gains a pause for the first time. It shows exactly when
something conducts; an untimed note has none. Chrome's Scrubber, already a rail along the stage's
bottom that starts right of an open panel, grows into it. (The user asked for a generic component.
In this model it is not one you attach - it has no card - because every timed note has exactly one.)

**The conductor implements it.** A component that can conduct (Song, Voice, Clip) registers play,
pause, stop, position, length and seek with the clock. Spectrum holds the seek half of this today as
three bare Callables (`scrub_pos`, `scrub_len`, `scrub_seek`), set only by the Generative editor and
never cleared - not by `Spectrum.stop()`, not when the editor leaves. A register/unregister pair,
cleared on detach, replaces them.

**Space is play/pause everywhere**, except while typing; skipping a scene gets a key of its own (N,
say). ←/→ and Home keep seeking, as the Scrubber's do.

**Pause stops all of show time.** `Spectrum.set_stream_paused` pauses the player, but the intro and
outro counters run on, so a pause inside a bookend still moves the picture. One pause, everywhere.

**What stays on a card.** A voice's Test plays one voice through its own player, outside the show,
so it stays on the Voice card; so does Synthesis's click on a seed, an audition. Masking's timeline
stays its workspace's editing tool, and its play and pause go through the transport when Masking
moves, last. A song that ends no longer returns anywhere: the transport stops at the end, and
Manual's loop becomes a setting on the Song card.

## Two frames: landscape and portrait

Every video is 16:9 today. TikTok, YouTube Shorts and Reels want 9:16. The user asked for two
standards and no more, and for export in either one where possible.

**A frame is a property of the show**, like the medium: `frame: landscape` (1920x1080) or
`frame: portrait` (1080x1920), kept beside `medium` in the note's picture block - its own card's,
once the note has one. The Director keeps it as it keeps `medium`, and `--frame` overrides it for
one run, as `--medium` does.

**Each presentation declares the frames it supports**, in a `Medium.FRAMES` table beside
`Medium.USES`. The pickers offer only what fits, and a note that asks for a frame its presentation
lacks falls back to landscape and says so on its card. Measured against the code:

| presentation        | portrait          | why                                                                                                                                                                                                                                                   |
| ------------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| full frame (scenes) | yes               | scenes size everything off the frame's short side, `SceneView.visible_half` covers any frame, and comic panels already run every scene at shapes from 0.42 to 2.6; four scenes need tuning (tidepool's grid, cloth's sheet, two_eyes' spacing, falling_sand's chamber) |
| tablet              | after a parameter | its `landscape` and `portrait` marks turn the device, not the video; its camera distances assume 16:9 and would cut reading lines at 9:16, so they become a fit on both axes                                                                         |
| comic               | not yet           | the two-page spread exists because one page cannot cover a 16:9 frame; at 9:16 a spread shows less than a page, so portrait wants a single page - design work                                                                                        |
| book, notebook      | not yet           | the same: the camera frames a spread, and portrait means framing the page being read                                                                                                                                                                 |
| tarot table         | not yet           | the deck sits outside a 9:16 view, so the shuffle would happen off screen, and several 16:9 values are hard-coded; a three-card reading also runs 4-6 minutes, past a Short                                                                          |

**The preview is the frame.** The stage takes the window's shape today (main.gd sizes its
SubViewport to the visible rect), so an ultrawide window previews wider than any export. Instead the
stage is the frame, centered in the window - 16:9 as now, or 608x1080 for portrait in a 1920x1080
window, black beside it. The side panel already sits clear of a centered portrait frame, the Look
filters follow the stage's rect, and the vignette is fitted to whatever frame it is given.

**Subtitles lay out in the frame, inside a safe area.** They lay out in the window today, and at
1080x1920 their baseline would sit 93.5% of the way down, under the buttons every platform draws
over the bottom third and the right edge (Google's safe zones for 1080x1920 keep the top 288, the
bottom 672 and the right 192 pixels clear).

**Export: small changes, and one trap.**

- Portrait presets are the landscape ones turned: 720x1280 at 30 fps and 1080x1920 at 60. No 4K
  portrait - Shorts stop at 1080p and Instagram at 1920 pixels wide.
- **The trap.** The exporter records the viewport inside a fixed 480x270 window, on the belief that
  window and viewport are independent (`Exporter._write_override`). They are only while the two
  have one shape: under the project's `expand` aspect, Godot widens the viewport to the window's
  shape, so a 1620x2880 render in a landscape window would come out about 5120x2880 (reasoned from
  Godot's stretch rules, not yet measured). Masking escapes only because it shapes its render
  window like its clip. So the render window takes the frame's shape, and the override also writes
  `window/stretch/aspect="keep"`.
- The thumbnail is cut at the frame's shape (it is `scale=1280:720` today, which would squash a
  portrait frame).
- The MP4 is written with its index at the front (`+faststart`): Instagram's API requires it, and
  nothing minds it.
- A portrait export longer than 3 minutes is not a Short, and the export says so. A Short longer
  than a minute with any Content ID claim is blocked worldwide - a music video on a commercial song
  should be one minute or less.
- The YouTube upload needs no change: a vertical upload of 3 minutes or less becomes a Short by
  itself, and the API has no field for it. Custom Shorts thumbnails exist since July 2026, set in
  Studio; whether `thumbnails.set` takes one is untested.

A 1080x1920 H.264 MP4 of 3:00 or less, with AAC and the index at the front, is inside the current
rules of Shorts, TikTok and Reels.

**Gates.** Nothing tests the stage, the media, the subtitles, the filters, the exporter or the
thumbnail at 9:16 (mask_portrait_check and clown_face_check cover Masking). Four are needed: a
headless exporter check (the override, the window's shape, even sizes, a 9:16 thumbnail, and
landscape byte-for-byte unchanged); a boot probe of the stage rect, the filters' size and the
subtitles' safe area; one small real render under xvfb whose MP4 reads back 1080x1920 - the only
check that catches the trap; and a look probe of every scene at 9:16.

Sources: [Shorts length](https://support.google.com/youtube/answer/15424877),
[Shorts resolution](https://support.google.com/youtube/answer/10059070),
[safe zones](https://services.google.com/fh/files/misc/universalsafezones-youtube.pdf),
[TikTok](https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide),
[Instagram](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media).

## Platforms: desktop and Android

Ghost Notes will have a phone build, and on a phone it is a notes app and nothing more: a list, an
editor, a folder of markdown. Everything else stays on the desktop, behind one gate.

**Why the rest cannot run on a phone.** Nearly every component reaches outside Godot: FFmpeg
(Masking, films, the export's transcode, FLAC, the bake), ghost's Python (the neural voice, the face
and body trackers, page capture, yt-dlp), the agents' command-line tools, and the engine relaunching
itself to render. Godot implements `OS.execute` and `OS.create_process` on Android, but Android 10
and later refuse to execute a file from an app's own writable storage, and Godot 4.7.2 targets SDK
36 - so nothing ghost downloads can run there, and `res://` lives inside the APK, where no
subprocess could read it anyway. (A binary shipped as a native library inside the APK is the known
way round, and it needs Godot's Gradle build. Not now.)

**And today it would try.** `Deps._platform()` calls anything that is not Windows or macOS "linux",
so a phone reports `linux-arm64` - a platform ghost has downloads for - and the Provisioner starts
fetching uv, FFmpeg and Python a second after launch. The first fix is that one function: taught
Android, iOS and the web, it lets Provision answer that it has no builds for them, and `ensure()`
already treats that as a permanent failure.

**One capability table.** `Capabilities` answers two questions for each entry, with a reason: is
it possible on this platform (decided once at boot, from `OS.has_feature` and
`Provision.unsupported`), and is it ready now (asked again whenever the Environment panel rescans).

| capability      | means                                                          | possible on   |
| --------------- | -------------------------------------------------------------- | ------------- |
| `subprocess`    | ghost may start a program                                      | desktop       |
| `ffmpeg`        | FFmpeg and ffprobe                                             | desktop       |
| `python:<env>`  | one per environment: voice, download, capture, face            | desktop       |
| `agent:<role>`  | a writer or a painter (`Splash.AGENT_ROLES` today)             | desktop       |
| `movie_export`  | the engine can relaunch itself to record                       | desktop       |
| `checkout`      | running from the repository: the Assistant, docs.py, the gates | editor builds |
| `forward_plus`  | the desktop renderer (volumetric fog needs it)                 | desktop       |
| `mic`           | the voice sampler                                              | desktop, for now |

A component declares the capabilities it needs, the way the Tarot row declares a writer and a
painter today. "+" leaves out what is impossible here and grays what is not ready yet, with the
reason. The table is also checked where programs start (`Subprocess._program`, `Deps.execute`, the
Provisioner's `_may_run`), so a component that forgets to declare still cannot launch anything on a
phone.

**The phone build.** On Android a note has one component, its text, and there is no stage,
transport, Chrome furniture or agent.

- The notes list and the editor, full screen, in portrait (`display/window/handheld/orientation`).
  `CodeEdit` brings up the keyboard by itself. Boot's window fitting and the Provisioner stay off.
- Notes live in `user://notes/`. A file comes in or goes out through the system's picker, which
  hands back a `content://` address that `FileAccess` reads since Godot 4.6.
- No permissions. The preset leaves out the hosts, `masks/`, `feedback/`, `build/`, `tests/`,
  `next/` and `docs/`; prebuilt template, no Gradle - monotone's arrangement, which builds this
  user's Android app today.
- `--handheld` (and an environment variable, for gates) runs the phone shell on the desktop.
  monotone learned that a desktop window at phone size is not a phone, and keeps
  `MONOTONE_HANDHELD=1` for this.
- Monotone's other lesson: Godot drops a setting at its default value when it rewrites
  project.godot - that is how its first APK came up sideways - so every value the phone build
  depends on gets a gate.

Sources: [feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html),
[OS](https://docs.godotengine.org/en/stable/classes/class_os.html),
[Android 10](https://developer.android.com/about/versions/10/behavior-changes-10),
[DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html),
[content:// in FileAccess](https://github.com/godotengine/godot/pull/112215),
[exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

## Cards: Tarot, generalized

The user's direction, 2026-10-06: as a mode, Tarot is too specific. Generalize it into Cards, "which
implements generic primitives and interfaces, allowing a user to drive the cards via their own needs
and logic" - another tarot deck without the standard 78, a Magic: the Gathering or Pokemon board,
baseball cards, an invented sport, flashcards for studying. "Modern AI is extremely capable when
given proper tooling. If we could give it control over actions - card draws, card positions on the
table, etc. - I just think there's a lot more possibility here." Everything tarot-specific comes
from the guide: the show's markdown brief.

**How close we are.** By lines, close. Of 13,986 lines in fifteen files, about 80% would serve any
card show unchanged, about 12% is tarot that belongs in the guide, and about 8% needs primitives
that do not exist yet. But that 8% is the spine. The reading is a fixed sequence of four verbs -
`shuffle`, `draw K`, `jumper K`, `spread` - and it runs through the mark parser, the voice's rests,
the step graph, the table's scheduler and posing, the moments and every reader prompt. No agent
decides anything on the table today: the seed decides the order, the reversals, the jumper and the
spread's shape, and code decides the sequence.

| already generic                                                                                                                                                                                                            | tarot, but data                                                                                                                                                                                                       | missing                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| the shuffle library (riffle, overhand, cut, and the wash's planned simulation), props and their lighting, the air, the title and the outro, the MCP tool server, ReadingFollower, the step graph's engine, the set dresser's tools, how NO CHEATING is enforced | the standard 78 and their elements, reversals (32%) and jumpers (30%, first card only), the spread shapes, the booklet page, the recipe (an intro, a passage per card, a close), the prompts' wording, the card's size (in four places), the frames and Cinzel, the limit of 1-10 cards | a vocabulary of actions with arguments, positions as data, card state over show time beyond one held card, face templates with fields, agents that choose actions and positions |

**The primitives**, in an order that leaves ghost working after each:

1. **Actions are a registry.** Each verb declares its arguments (which card, which position, face up
   or down, a turn), its rest, its pose and the moments it makes - declared, not branched on, like
   `Medium.USES`. Today's four verbs, and the ones nobody writes (the deck's push, squaring, the
   lay), are its first entries, and CardReading's rests, MOMENTS and MOVES derive from it; today
   they are hand-kept sums duplicated across two files. Deal, place, flip, a quarter turn (tap),
   show, gather and discard are more entries. This one changes no behavior, and the tarot gates hold
   it to that.
2. **Positions are data.** Named positions `{x, z, yaw, face, stack}`, written in the guide or by the
   producer's plan. (Today `_land_plan` rebuilds each position as a name and a question and drops
   any geometry.) Each is checked to be on the cloth, in frame and clear of the deck, and today's
   seeded shapes - row, arc, rows, pyramid - become presets. A hand, a pile and a board's grid are
   positions with a stacking rule.
3. **Card state over show time.** Every card's position, face and turn is a pure function of show
   time, generalizing `_times` and `_pose`, so a scrub and an export agree as they do now. The held
   card and its booklet page become one presenter, and more than one card may be up at once.
4. **Decks and faces from the guide.** The card's size, the deck's thickness from its count (the
   26-mesh deck never shrinks today), the fields a face shows, the booklet on or off, and art the
   user supplies as well as art an agent paints. A face template draws a card's fields onto its
   front and back, as Anki's card templates do; today's one face is a numeral, a name, an art window
   and a frame - no text box, no stats, no cost.
5. **The recipe from the guide.** Which agents run and in what order (CardEpisode's step list is
   code), how the script is composed, and the tarot nouns now in every prompt.
6. **Agents choose.** The producer writes the layout, so the set dresser sees it. A reader may write
   registered marks, and an unknown one is dropped - today nothing guards this: `clean_spoken` keeps
   HTML comments, so a tarot mark in a reader's reply would already be parsed as an action. A
   dealer's toolset on the MCP server (deal, place, flip, look, submit) previews the table, as the
   set dresser's `set` does. Two limits stay: every choice lands in an episode file before the voice
   is made, because a rest is spliced into the reading; and `_drawn` stays the only way a card
   reaches a writer.
7. **The rename comes last**, once the name is settled (below), behind a public staging API for
   TablePreview, which reaches into about 25 private members of TableMedium today. It is 736
   references in 30 files, plus `user://cards`, `fonts/tarot`, `data/tarot` and `Medium.OWNED`.

**Hidden information generalizes.** NO CHEATING - a reader sees only the cards drawn so far - is what
a card game calls hidden information, and boardgame.io builds it in: a game's `playerView` strips
whatever one player may not see before the state reaches them. Ghost's rule is that rule with the
agents as the players: a writer sees what has been revealed to its role, and the audience may see
more, as a poker broadcast shows every hand. One gap to know: Codex keeps a shell and could read
`draw.json`; it is only told not to.

**What stays tarot is a template.** Its guide holds the 78 and their elements, the reversal and
jumper rules, the spread presets, the booklet, the recipe (an intro while shuffling, a passage per
card, a close), shuffle-draw-present-lay as its verbs, its prompts' wording, and the deck's look and
Cinzel. The tarot show keeps playing from its file exactly as it does today - the test that the
generalization is honest.

**The name.** "Cards" collides with our own word: a component's settings live on a card, so these
would live on the Cards card - and ScriptWriter's card, SynthEditor's catch card and the tarot's
TitleCard use the word too. In the code, Deck, Zone and Pile are free; Table, Slot, Hand, Spread and
Board are taken (the tablet's markdown tables, the voice slots, handwriting, the book and comic
spreads, Storyboard). My suggestion: call the component **Deck** - "attach a Deck", and the Tarot
template is a Deck with the tarot guide - and say "positions" for where cards go, because "places"
is already a meeting point. The user's call - and the user chose **Cards** (2026-10-06): "the
intent is to later support any kind of card... I want to use 'Card' as the name". The settings card
keeps its name in the code (`Card`), and the folds moved to `[folds]` so `[cards]` could be the
component's.

**Prior art.** Tabletop Simulator's objects carry the verbs this needs: `deal`, `shuffle`,
`takeObject` (with a position and a flip), `flip`, `spread`, `split`, `cut`. boardgame.io declares a
game as moves and phases, and hides each player's secrets with `playerView`. Anki draws a note's
fields onto a card's front and back with templates - the flashcards case, and the shape of a face
template. [Tabletop Simulator](https://api.tabletopsimulator.com/object/),
[boardgame.io](https://github.com/boardgameio/boardgame.io/blob/main/docs/documentation/secret-state.md),
[Anki](https://docs.ankiweb.net/templates/intro.html)

## Today's modes, decomposed

| mode       | as a note                                                                                                                     |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Auto       | Song + Scenes (seeded) + Look                                                                                                 |
| Manual     | Song + Scenes (storyboards, dials) + Look                                                                                     |
| Synthesis  | Voice (synthesis engine) + Voice lab (genome, belt, fishing) + Scenes + Look                                                  |
| Generative | Voice (neural engine) + one presentation, or Scenes full frame + Illustrations or Films, as the presentation uses them + Look |
| Tarot      | Cards with the tarot guide (brings the table) + Voice + Look                                                                  |
| Masking    | Clip + Masks (markers, tracks, effects, its timeline)                                                                         |

Auto and Manual differ by one setting of one component; Synthesis and Generative by the voice engine
and the lab. Six modes are about a dozen components, and most modes share most of theirs.

**The modes survive as templates.** Tarot, in the notes list's New menu, makes a new note with
Tarot and a Voice attached. The on-ramp stays; the six code paths behind it go, and so does the home
screen they were listed on.

## Prior art

Researched 2026-10-06. Grouped by the decision each one informs.

**The three the user named.**

- **Scratch** is the closest match to the panel. Its block palette is one long column of colored
  categories, with a column of colored circles beside it that jumps to each, and **Add Extension**
  (Text to Speech, Music, Video Sensing, Pen, Translate) adds a new category at the bottom: attach a
  component, get a section. Two details worth copying. Extensions do NOT get their own colors - all
  share one green (#0FBD8C) and are told apart by an icon on the category and on every block. And an
  extension whose blocks are unused is dropped when the project reloads. Sprites couple only through
  named broadcasts that fire "when I receive" hats - moments, in Scratch's words.
  [colors](https://github.com/scratchfoundation/scratch-gui/blob/develop/src/lib/themes/default/index.js),
  [extensions](https://github.com/scratchfoundation/scratch-vm/blob/develop/docs/extensions.md),
  [broadcasts](https://en.scratch-wiki.info/wiki/Broadcast)
- **Blockly**, the engine under Scratch's blocks, answers how to type the connections: each
  connection carries a `check` list of type names, two connect only when their lists share one, and
  an empty list accepts anything. That is needs and provides. Its colors are a hue at one fixed
  saturation and value (0.45, 0.65), so any hue fits the set, and blocks are declared in JSON - a
  registry. [checks](https://docs.blockly.com/guides/create-custom-blocks/inputs/connection-checks/),
  [colors](https://docs.blockly.com/guides/configure/toolboxes/appearance/)
- **Logseq** is the closest match to the text. A plugin's slash command writes
  `{{renderer :name, args}}` into a block and the plugin draws its UI there, and the official
  pomodoro sample writes its state back into the macro's arguments: invocation and state live in the
  text, as ghost's marks do. Its newer database version lets a block carry several tags, each with its
  own properties, with one name per property across the whole graph - Tana's supertags, in substance.
  The price was the plain markdown files (an export drops block properties). Keep the files.
  [macros](https://github.com/logseq/docs/blob/master/pages/Macros.md),
  [plugin sample](https://github.com/logseq/logseq-plugin-samples/blob/master/logseq-pomodoro-timer/index.ts),
  [database version](https://github.com/logseq/docs/blob/master/db-version.md)

**Compound documents, and why OpenDoc died.** The container idea is not what failed: few parts ever
shipped, nobody owned the experience across parts, and OLE already held the market. OLE's own flaw is
worth avoiding too: only one embedded part is active at a time, so its controls appear only when you
click into it - a panel of cards shows every attached component at once instead. Ink & Switch's
Patchwork essay (2025) restates the problem OpenDoc never solved: does the person you share a document
with have every editor it needs? [OpenDoc](https://en.wikipedia.org/wiki/OpenDoc),
[OLE](https://learn.microsoft.com/en-us/cpp/mfc/active-document-containment),
[Malleable software](https://www.inkandswitch.com/essay/malleable-software/)

**Text as the source of truth.** Potluck keeps all state in the text ("no hidden metadata") and found
its limit there: text "rules out applications with non-textual data or rich visualizations", which is
why ghost needs components at all. Embark makes views render any subtree of one outline - views over
the note, not owners of separate data. Org-mode's settings cascade (system, language, file, heading,
block, call; the most local wins) is the shape for component default, note, and a mark in a passage.
[Potluck](https://www.inkandswitch.com/potluck/), [Embark](https://www.inkandswitch.com/embark/),
[Org](https://orgmode.org/manual/Using-Header-Arguments.html)

**Inspectors.** Unity's component header is fold arrow, icon, enable checkbox, name and menu; the
checkbox appears only on components where disabling would do something; `RequireComponent` adds
dependencies; it has no built-in header colors (those come from custom editors). Blender evaluates
modifiers top to bottom, saves expanded, viewport and render as properties of each, and Ctrl-click on
a collapsed panel header opens it and closes the rest. Unreal's Details panel marks every value that
differs from its default, with a reset. Xerox Star gave every object the same property sheet and the
same few commands, "Same" among them. [Unity](https://docs.unity3d.com/Manual/UsingComponents.html),
[Blender](https://docs.blender.org/manual/en/latest/modeling/modifiers/introduction.html),
[Outliner](https://docs.blender.org/manual/en/latest/editors/outliner/interface.html),
[Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/level-editor-details-panel-in-unreal-engine),
[Star](https://digibarn.com/friends/curbow/star/retrospect/)

**Composition.**

- Bitwig's modulators: drag from a modulator onto any parameter, the range relative and drawn on the
  control. Ableton's racks: up to 16 macros, each mapped to any number of parameters with ranges.
  [Bitwig](https://www.bitwig.com/userguide/latest/the_unified_modulation_system/),
  [Ableton](https://www.ableton.com/en/live-manual/12/instrument-drum-and-effect-racks/)
- TouchDesigner's typed families ("only operators of the same family (color) can be wired
  together", with explicit exports between them) and Max's hot/cold inlets keep streams and events
  apart. [TouchDesigner](https://docs.derivative.ca/Operator_Family),
  [Max](https://docs.cycling74.com/legacy/max8/tutorials/basicchapter06)
- VCV Rack has one kind of connection, a voltage; it writes down the range each use keeps to and
  turns NaN into 0. [VCV](https://vcvrack.com/manual/VoltageStandards)
- Functional reactive programming began with the feeds/moments split: Fran's behaviors are
  continuous values over time, its events are discrete occurrences, and an animation is a function
  of time - ghost's declarative claim, as a 1997 paper. [Fran](http://conal.net/papers/icfp97/)
- Observable runs cells in dependency order. Jupyter is the cost of not doing so: of 863,878 attempted
  notebook runs, 24% ran without errors and 4% reproduced their results, hidden state and
  out-of-order cells among the causes. [Pimentel et al.](https://leomurta.github.io/papers/pimentel2019a.pdf)
- Entity-component systems keep behavior in systems keyed on which components are present; Bevy's
  `require` adds dependencies. Godot composes with child nodes "at a higher level than in a traditional
  ECS", so ghost needs no framework for it. [ECS FAQ](https://github.com/SanderMertens/ecs-faq),
  [Godot](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)
- Blackboard systems (Hearsay-II): sources post facts, and a controller picks what runs next.
  [Nii 1986](https://ojs.aaai.org/index.php/aimagazine/article/view/537)
- Render volumes (Unity URP, Unreal) blend two writers of one field by priority and weight, with a
  per-field override - the rule if two components ever must set the same field.
  [URP](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@7.5/manual/Volumes.html)

**Writing on it.** Kay and Goldberg named the risk in 1977: a general medium may "collapse under the
weight of trying to be too many different tools for too many people", a "feature-laden hodgepodge".
Victor's Magic Ink: software should infer the context its data is needed in - which is what "+"
suggestions are. Matuschak and Nielsen: the component system is not the insight; each component still
needs real depth. Nielsen Norman Group: designs past two levels of disclosure "typically have low
usability". [Kay and Goldberg](https://tinlizzie.org/VPRIPapers/m1977001_dynamedia.pdf),
[Magic Ink](http://worrydream.com/MagicInk/), [Tools for thought](https://numinous.productions/ttft/),
[NN/g](https://www.nngroup.com/articles/progressive-disclosure/)

## Risks

- **Leaving a note.** A note app switches documents, and ghost cannot leave any of its modes on
  purpose: there is no exit control (main.gd calls one "future"), only Auto returns to the home
  screen and only when its song ends, Manual and Synthesis loop, and the editors (`_generative`,
  `_synth_editor`, `_mask_editor`) are freed only at quit. Every component needs a real detach, and
  a gate that attaches and detaches each one many times and finds no leaked nodes, Chrome claims or
  bus effects, before notes can switch.
- **Pairs.** Telecom calls it the feature interaction problem: features that each work and misbehave
  together. With n components there are 2^n combinations, and most will never run. Templates are the
  tested paths; one contract check per feed (everything that provides a reading passes the same
  test) covers the rest.
- **The hodgepodge.** Kay and Goldberg's warning. A dozen deep components beat thirty shallow ones,
  and a card that needs a third level of disclosure is two cards.
- **Cost.** AUDIT.md: a frame is tens of thousands of GDScript calls on one core of a 2014 CPU. Live
  scenes on four card faces are four scenes. A component should declare a rough cost, and "+" should
  say when the total is past what runs.
- **Workspaces are not cards.** Masking (8,200 lines, its own timeline) is an editor, not settings,
  and Manual's workspace (a storyboard list and the Dial, labeled scaffolding for an editor to come)
  is the start of one. Their cards hold the essentials and a button that hands them the stage, as
  ScriptWriter's pop-up editor does now. Masking moves last, not first.
- **Sharing and versions.** Today every note is the user's own, so a one-time rewrite is enough. Once
  other people have notes, each block needs a version and a migration (Ink & Switch's Cambria shows
  translating between versions always gives something up), and a note opened without a component it
  uses must keep that block verbatim, behind a gray card that names what is missing.
- **The blank page.** An empty note invites less than the Tarot button did. Templates again.
- **The body changes its role.** With Tarot attached the body is a brief, and the voice reads
  something else. See child notes, below.

## The plan, in order

The order the user and I settled on, for the session that carries it out. Each step stands on its
own and leaves ghost working, and the early ones pay for themselves even if the later ones wait.
Mark a step done here when it lands, with what changed in it, and keep CLAUDE.md current as you go.

**Working rules** - the user's standing ones, repeated because a new session may not have its
memory yet:

- Git writes are the user's. Never stage, commit, `git mv` or `git rm`; where a step needs one, give
  the user the command.
- Never overwrite a file you have not read, and never `git checkout` a file with changes in it.
- Run the gate that covers what you touched. `tests/run_boot_probe.sh` runs one probe at a time.
- `/tmp` is a RAM disk: large scratch files go on a real disk. Kill a process by its exact pid,
  never by pattern.
- Credentials stay with the user - keystores, the Google client, tokens. Build the place they go,
  and let the user put them there.
- Prose in American English, with " - " where an em dash would go.

### Step 0: move to ghost-notes

The layout is the user's choice (2026-10-06): flat, with the GDScript folder renamed.

```
ghost-notes/
├── project.godot     the Godot project, at the root
├── src/              GDScript: today's scripts/, renamed
├── scripts/          build scripts (step 1)
├── scenes/ shaders/ data/ fonts/ tests/ docs/ next/ storyboards/ ...
├── hosts/            the Python hosts: voice/, face/, capture/ (moved out of the root, 2026-10-06)
└── README.md  CLAUDE.md  LICENSE (already there: MIT)
```

Start this step from a session in `praxis/axis/ghost`, which has the memory and CLAUDE.md. Later
steps run from sessions in ghost-notes, once its memory has been copied (6, below).

1. **The user commits** everything pending under `axis/ghost`, this file included, and decides about
   `stash@{0}` ("ghost things", 2026-09-05, touching `scripts/vehicles/comic.gd` and
   `tests/comic_camera_check.gd`), which otherwise stays in praxis.
2. **The user brings the history.** No new tool is needed: `git subtree split` produces exactly the
   flat layout.

   ```
   git -C /home/crow/repos/praxis subtree split --prefix=axis/ghost -b ghost-split
   git -C /home/crow/repos/ghost-notes pull --allow-unrelated-histories /home/crow/repos/praxis ghost-split
   git -C /home/crow/repos/praxis branch -D ghost-split
   ```

   That carries 171 commits, from "rename vortex to ghost" (2026-06-29) to today. The ten before
   it, when ghost lived in `axis/vortex/`, stay in praxis: an unrelated app reused that folder later
   and collides with ghost on five paths, and untangling it takes an untested two-pass
   `git filter-repo`.

3. **Copy what git leaves behind**, with
   `rsync -a --exclude='__pycache__/' /home/crow/repos/praxis/axis/ghost/ /home/crow/repos/ghost-notes/`
   (the tracked files are already identical):

   | ignored today                  | size    |                                                                                                    |
   | ------------------------------ | ------- | -------------------------------------------------------------------------------------------------- |
   | `CLAUDE.md`                    | 284 KB  | ignored by a global rule for every CLAUDE.md; stays ignored here (the user, 2026-10-06)            |
   | `feedback/`                    | 36 MB   | 7 reports with screenshots, 4 Assistant conversations; stays ignored                               |
   | `masks/`                       | 3.4 GB  | the ten `session*.json` are hand-placed markers and cannot be remade; the media can               |
   | `build/`                       | 15 MB   | 41 hand-written bench and probe scripts                                                            |
   | `*.uid` (348), `*.import` (17) |         | ignored by ghost's own `.gitignore`; track them from now on - Godot's advice since 4.4, and what lets a clean clone keep every reference |
   | `.godot/`                      | 303 MB  | a cache; copying it saves a reimport                                                               |

4. **Rename `scripts/` to `src/`** with `mv`; the user stages it. The `.uid` files move with their
   scripts, so references by UID survive, and references by path are rewritten: 254
   `res://scripts/` in 98 files, and 820 mentions of `scripts/` in 132 files in all (96 `.gd`, 20
   `.md`, comments in nine shaders, the `.tscn`, project.godot's autoloads, `.gitignore`, two `.py`,
   two `.txt`), including the `../scripts/` links docs.py writes. Every one of them names ghost's
   own folder (checked). Then `godot --headless --path . --editor --quit` rebuilds the class cache,
   and its log must show no invalid UID, failed load or parse error.
5. **Fix what pointed at praxis:**
   - `src/assistant.gd` finds the checkout as `res://../..`, and tells a dispatched agent to read
     `axis/ghost/CLAUDE.md` and `axis/ghost/feedback/NNNN.{json,png}`. From ghost-notes that is
     `/home/crow`, every path dead, and every dispatched fix would run there. The checkout is
     `res://` now, and the paths lose `axis/ghost/`.
   - CLAUDE.md's "Working directory note" (cwd `praxis/`, `--path axis/ghost/`), and about 80
     `--path axis/ghost` or `python axis/ghost/...` strings in about 60 files: the README, docs.py's
     own strings (then regenerate `docs/`), measure_voice.py, the voice host's tests, most test
     headers, a hint `Deps` shows the user, and `mask_marker_tool.gd`.
   - Three probes reach rift as `../../../rift/` (set_dresser_run_probe, cards_voice_probe,
     episode_probe); it is `../rift/` now. (`storyboards/default.yaml` names `../../tunes/`,
     broken already.)
   - `.gitignore` gains `__pycache__/` (praxis's root rule covered it) and `dist/` (step 1), and
     stops ignoring `*.uid` and `*.import`.
6. **Outside the repository:**
   - **Claude's memory.** A session started in ghost-notes reads
     `~/.claude/projects/-home-crow-repos-ghost-notes/memory/`, which does not exist yet. Copy
     `index_ghost.md` and the 77 files it lists, the five ghost files only praxis's MEMORY.md links
     (`feedback_offscreen_is_fine`, `feedback_subtle_eased_modulation`,
     `feedback_prefer_engine_native`, `project_harmonic_seed_bias`, `feedback_ui_must_read_back`),
     the general feedback files and the user's profile entries; write its MEMORY.md; and rewrite
     `axis/ghost/` and `scripts/` in them (43 name `axis/ghost`). In praxis, the ghost index becomes
     one line saying where it went.
   - **Syncthing.** `axis/` is the Syncthing folder "praxis/axis", sent to the phone. Removing
     `axis/ghost` deletes the phone's copy, and ghost-notes syncs only once it is added as a folder
     of its own (with ghost's lines from `axis/.stignore`).
   - **Permissions.** praxis's `.claude/settings.local.json` has about 60 Godot entries that a
     ghost-notes session will not have; the user carries over the ones they want.
   - **Pointers.** rift's `CLAUDE.md:9` and `ENTRYPOINT.md:60` name `axis/ghost/next/cards.md`. In
     praxis: `.gitignore:55-56`, `axis/README.md:9`, and the README and docs index lines generated
     by `praxis/docs.py:151-156` (edit the generator). Godot's project manager lists the old path.
7. **What does not change: the user's data.** `config/name="ghost"` and no custom user directory,
   so `~/.local/share/godot/app_userdata/ghost/` (8 GB of settings, voices, episodes and tools) is
   found exactly as before, and ghost.cfg names no praxis path.
8. **The user, last,** removes `axis/ghost` from praxis and commits both repositories.

**Done when**, in ghost-notes: `--editor --quit` logs no invalid UID, failed load or parse error;
the headless gates and `tests/run_quiet.sh --all` pass; `python docs.py` reports no drift; the app
opens with the user's settings, voices and episodes; a feedback report dispatches with its working
directory in ghost-notes; and the 171 commits are in `git log`.

**Status, 2026-10-06 (the ghost-notes session): done, except the two git steps that are the
user's (0.2 and 0.8).**

- 0.1: praxis was clean when the session began. `stash@{0}` stays in praxis.
- 0.2, the user's: **the history**. Rehearsed against throwaway clones: the split carries **172**
  commits, from "rename vortex to ghost" (2026-06-29) to "revise the notes", and its tip's tree is
  byte-identical to praxis's `axis/ghost`. The working tree now holds the whole refactor, so a
  `git pull` would refuse (untracked files in the way). These commands merge the history UNDER the
  working tree without touching a file; afterwards `git status` shows exactly this session's work
  (rehearsed: 174 commits in the log, the merge on top):

  ```
  git -C /home/crow/repos/praxis subtree split --prefix=axis/ghost -b ghost-split
  git -C /home/crow/repos/ghost-notes fetch /home/crow/repos/praxis ghost-split
  git -C /home/crow/repos/praxis branch -D ghost-split
  cd /home/crow/repos/ghost-notes
  git read-tree FETCH_HEAD
  git update-index --add --cacheinfo "100644,$(git rev-parse HEAD:LICENSE),LICENSE"
  git update-ref refs/heads/main "$(git commit-tree "$(git write-tree)" -p HEAD -p FETCH_HEAD -m 'Bring the history of praxis/axis/ghost')"
  git status --short | head
  ```

- 0.3: copied with rsync; the tracked files matched praxis HEAD exactly.
- 0.4: `scripts/` is `src/`, by `mv`. 746 lines in 162 files were rewritten by rule (`res://scripts/`,
  `../scripts/`, a `scripts/` that starts a path, `--path axis/ghost` -> `--path .`,
  `python axis/ghost/` -> `python`, other `axis/ghost/` prefixes dropped), and a sweep for every
  remaining word `scripts` in code found three more by hand (`"res://scripts"` in deps_check and
  settings_check - the latter then scanned nothing and still passed, so it now asserts it read the
  source - and `ROOT / "scripts"` in docs.py). NOT every mention named ghost's folder, as this
  plan said: uv's wheel layout (`<name>.data/scripts/`, in provision_check) and
  next/voice_rca.md's `git show 11d3c2a8:axis/ghost/scripts/voice.gd` (praxis history) stay.
  Four orphan `.uid` files (no script beside them) were dropped rather than tracked. THE FIRST
  `--editor --quit` after the move logs autoload failures: the copied `.godot/` UID cache still
  maps every UID to `res://scripts/`, and that scan rebuilds it. The second is clean, and that is
  the check (scripts/check.sh's `parse`).
- 0.5: the Assistant's checkout is `res://` and its prompt names `feedback/NNNN.{json,png}`; its
  source scan is recursive now (an agent's fix to a scene or a medium is a code edit too).
  CLAUDE.md's working-directory note, the README, docs.py (docs regenerated, no drift), the voice
  hosts' and tests' run lines, Deps' hint, mask_marker_tool, the three rift probes,
  fractal_depth_check's dump (it wrote into a dead praxis session's scratchpad). `.gitignore`
  tracks `*.uid` and `*.import`, ignores `__pycache__/`, `dist/` and the probe runner's private
  scenes, and UN-ignored CLAUDE.md: the rule hiding it was the user's global
  `~/.gitignore_global`, not praxis's, so it would have stayed hidden here too. (Reversed the same
  day by the user: CLAUDE.md stays out of the repository, and `.gitignore` now says so itself.)
- 0.6: memory - 110 files (the ghost index's 77, the five, 25 general feedback, 3 user) with
  their paths rewritten, and a MEMORY.md; praxis's index line says where ghost went (its copies
  stay, frozen). Syncthing: `.stignore` with ghost's lines is in the repository; adding the folder
  is the user's. Permissions: the user's. Pointers edited: rift `CLAUDE.md:9` and
  `ENTRYPOINT.md:60`; praxis `README.md` and `docs/index.md` (the generated line removed by hand,
  and its source in `praxis/docs.py`'s SUBSYSTEMS), `.gitignore`, `axis/README.md` (it links the
  GitHub repository now). These belong in the same praxis commit as 0.8. Godot's project list
  has ghost-notes added; the old entry goes when `axis/ghost` does.
- 0.8, the user's: remove `axis/ghost` from praxis and commit both repositories.

**Later the same day, at the user's request:** `measure_voice.py` and `AUDIT.md` were deleted as old
and unused (the source-filter test kept the two numpy helpers it borrowed from the first, and the
comments that cited either keep their facts), and CLAUDE.md is gitignored. And the three Python host folders left the root for
`hosts/` (`hosts/voice/`, `hosts/face/`, `hosts/capture/`). Their requirements files moved byte for byte
- the environment digest is their text, not their path - and the voice environment still reads ready.

### Step 1: build scripts

`scripts/build.sh`, modeled on monotone's, which builds this user's Android app today:

```
scripts/build.sh [linux|windows|android|all] [--release] [--install] [--no-check]
```

1. Check that Godot is the project's version (4.7.2) and that the target's export templates are
   installed: a named target fails without them, and `all` skips it.
2. Import first when `.godot/` is missing, as on a clean clone.
3. Run the headless gates through `scripts/check.sh`, unless `--no-check`. CI will call `check.sh`
   too.
4. `godot --headless --path . --export-{debug|release} "<preset>" dist/ghost-notes-<target>.<ext>`.
   (`dist/`, not `build/`: ghost's `build/` holds hand-written bench scripts.)
5. Check the file exists and is at least 1 MB: Godot's exporter exits 0 even when it fails.
6. `--install` puts an APK on the phone with `adb install -r`; adb lives in
   `~/Android/Sdk/platform-tools`, not on PATH.

A tracked `export_presets.cfg` that names no secret: Linux x86_64 with the pack embedded, Windows
x86_64, and Android arm64-v8a (prebuilt template, no Gradle, no permissions, portrait, the debug
keystore from the editor settings). macOS waits: it needs signing.

**Release signing is the user's.** A release APK needs `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`_USER` and `_PASSWORD`, which the user sets. The script refuses `--release` without them and never
prints them. (monotone's own hint names `_PASS`, which Godot does not read - worth fixing there
too.)

**This machine, 2026-10-06.** Godot 4.7.2, with only its Android templates installed: there are no
Linux, Windows or macOS templates for 4.7.2 (AUDIT.md met this too), so the desktop targets need the
4.7.2 template set first. The Android SDK is `~/Android/Sdk`; `ANDROID_HOME` points at
`/opt/android-sdk`, which holds only cmdline-tools, so read the editor's setting first, as monotone
does. JDK 17 and the debug keystore are in place.

**What an exported desktop build cannot do yet.** It boots, but `binary_export_and_steam.md`
("Binary export: why a build would not run today") lists why much of it would not run, and this
research confirmed each item:

- The Python hosts and their requirements files are found through `globalize_path("res://...")`,
  which in an export is a relative path into a `.pck` that Python cannot read. Ship them in the
  pack and have the Provisioner copy them to `user://`, named by digest like its environments,
  before starting one: one file per build, and a checkout behaves the same.
  (binary_export_and_steam.md proposes loose files beside the executable; either works.)
- The render and the bake relaunch the engine with `--path` and `--script`, which export templates
  refuse. The render relaunches the binary itself, and the bake becomes a ghost flag.
- Ghost writes into `res://`, which is read-only once exported: feedback, Masking's sessions and
  downloads (`MASKS_DIR`), and the render's `override.cfg` (an export reads it from beside the
  executable, where an installed app may not be allowed to write).
- Non-resource files need the preset's include filter: `data/english.yml`, `data/cmudict.dict`,
  `storyboards/*.yaml`, the license texts.
- The tarot's card fonts are opened as raw `.ttf` files (`load_dynamic_font`), which an export does
  not contain, so the table would silently fall back to the default font. `load()` fixes it, as the
  notebook does.
- The Assistant and Masking's reload check need the checkout: the `checkout` capability.

None of this blocks the refactor, which runs from the checkout. All of it comes before a build goes
to anyone else.

**Done when** `scripts/build.sh linux` and `scripts/build.sh android` each produce a build that
starts, the APK opens on the phone without trying to download anything (`Deps._platform()` knows
Android - see [Platforms](#platforms-desktop-and-android)), and `scripts/check.sh` runs the
headless gates. The APK shows the desktop shell until step 11: this step proves the toolchain.

**Status, 2026-10-06: done; the APK on a phone is the user's to see (no device was attached).**

- `scripts/build.sh` as planned, modeled on monotone's (targets are the presets, the exit code is
  not trusted, a 1 MB floor, `--release` refused without the three `GODOT_ANDROID_KEYSTORE_RELEASE_*`
  variables, adb from the SDK's platform-tools). Built here: Linux 78 MB, Windows 107 MB, Android
  32 MB (arm64-v8a, debug-signed). The Linux build starts headless and on the GPU (Forward+, the
  RTX 5060 Ti) against an isolated data folder. Android needed `import_etc2_astc=true` in
  project.godot (monotone has it). The APK packs `src/`, shaders, fonts and all of `data/`, and
  none of `masks/`, `tests/`, `docs/`, `next/` or the Python hosts.
- The 4.7.2 Linux and Windows templates were missing (only Android's were here): the official
  `.tpz` was fetched, its SHA-512 checked against the release's sums, and only the x86_64 Linux
  and Windows templates extracted beside the Android ones (about 360 MB added; the archive
  deleted).
- `scripts/check.sh` runs every gate found on disk (`--gpu` for the 22 that need a renderer),
  starting with `parse` (the editor's scan) and ending with `docs` (`python docs.py --check`, a
  new mode that writes nothing). A gate that printed its own passing verdict and then died in
  the engine's teardown is `ok*`, not a failure. ON THE MOVED TREE: 98 of 98 pass, four of them
  `ok*` (the baseline shows the same teardown crashes).
- `Deps.platform()` knows Android, iOS and the web; Provision refuses everything there and the
  Provisioner does not start (provision_check, two-sided, through `Deps.platform_override`).
- The harness, made safe to run beside anything: `run_boot_probe.sh` boots a private scene per
  run (the shared `tests/boot_probe.gd` is gone - and the committed "stub" had become an old copy
  of a probe); every test is read-only, `--script` gates included (`Settings.is_probe_launch`);
  `tests/compile_check.gd` loads every script, since `--editor --quit` only parses;
  `tests/fixture_audio.gd` makes the silent WAV two gates needed and nothing made.
- THE BASELINE: the same gates on the untouched praxis copy failed four, all environmental and
  all fixed here - youtube_check and agent_effort_check built the Tarot panel synced to the
  author's real show (and DocSource.set_field writes a synced file at once, so they could have
  written into it); bookend_check and seek_check needed `res://01_silence.wav`. One header
  timeout was stale (table_place_check said 180 s and takes 430).

### Step 2: cards

Wrap each mode's existing sections in colored `FoldableContainer`s. No change in behavior: the
panels get readable now, and the colors and the row get tried in real use. A fold is the viewer's,
remembered in ghost.cfg. **Done when** every section folds and keeps its fold, and panel_fit_check
and medium_pick_check pass.

**Status, 2026-10-06: done.** `Card` (a FoldableContainer bordered in its family's color) and
`CardRow` (the chips under the heading: a click folds or opens, Ctrl-click opens one alone), made
through `SidePanel.add_card`. Generative: Script, Voice, Picture, Look, Intro & outro. Tarot: Script,
Episode (the producer's violet), Voice, Look, Intro & outro - the Episode section was a separator and
a heading inside the script's card. Synthesis: Script, The water, Collection. Manual's workspace:
Storyboards. Folds are `[cards] <panel>.<card>`. Two things learned: FoldableContainer signals a
fold made by fold(), expand() or a click but not one ASSIGNED, which is how a stored fold comes back -
so the chips follow their cards by polling, or every folded card had an "open" chip at launch (caught
by looking at the panels, then gated two-sided); and a probe must open the cards before measuring a
panel, because it reads the author's real folds. MASKING IS NOT CARDS: its options are one flat
sortable list because titled groups were rejected once (feedback 0011), and it moves last. Gates:
card_fold_check (new), panel_fit_check (opens the cards; its control counts the rows inside them),
medium_pick_check.

### Step 3: the transport

The bar along the stage's bottom ([The transport](#the-transport)): Chrome's Scrubber grows
play/pause, stop and the time; a conductor registers with a register/unregister pair that replaces
Spectrum's three Callables; Space is play/pause everywhere and skipping a scene gets its own key;
pause stops all of show time. Generative's and Tarot's buttons leave the Voice section, Auto and
Manual gain a pause, and Synthesis's seed click stays an audition. **Done when** a gate drives
play, pause, seek and stop through the bar for a song and for a reading, finds the clock still
during a pause (inside a bookend too), and finds no hook left after a stop or after leaving; and
speak_stop_check passes.

**Status, 2026-10-06: done.** `src/transport.gd` (the Scrubber, grown: ▶/❚❚, ■, the time, the rail)
is Chrome furniture and shows exactly when `Spectrum.timed()`. Spectrum gained a CONDUCTOR -
`conduct(owner, hooks)` / `release_conductor(owner)`, held through a WeakRef so a freed owner drops
out by itself - in place of the three bare scrub Callables, and transport verbs that call its hooks
or drive a plain file (Stop = back to the start, paused). The Generative and Tarot panels conduct
from `_ready` to `_exit_tree` (their Play and Stop buttons are gone; `transport_hooks()`); Synthesis
conducts while a take plays, with no seek, and the seed click stays an audition. PAUSE STOPS ALL OF
SHOW TIME (`Spectrum.paused` holds the intro and tail counters too). Space is the transport's
everywhere but while typing; N skips a scene; Auto and Manual have a pause. Two things learned:
setting `stream_paused` turns the player's `playing` false at once in 4.7, so "playing" is never
`_player.playing` alone; and the Scrubber's reveal snapped to zero below 0.004, which a headless
frame of a fraction of a millisecond never cleared - the snap is on the way out only now. NOT DONE
HERE: "a song that ends no longer returns anywhere" - Auto still goes home at its song's end, because
until step 8 the home screen is the only way out. Gates: transport_check (new: a song and a reading
through the bar; the clock still while paused in the intro, the music and the tail, two-sided;
nothing on the rail after Stop, no conductor once the panel is gone), speak_stop_check (moved to
the hooks and `Transport.space_toggles`), multi_voice_check; the full run passes, 100 of 100.

### Step 4: the bottom-right row

One row container in Chrome; the Environment button at its left end, with `[deps] open`; the
Assistant dropdown moves into the Assistant's panel; one panel above the row at a time. The home
screen is left with its title, its import field and its mode rows. deps_panel_probe and
splash_agents_check reach the panel through the splash today; they reach it through Chrome. **Done
when** a gate checks the row's geometry (no hole for a hidden button, nothing over another), opens
each panel in turn and finds one open at a time, and reads `[deps] open` back after a restart.

**Status, 2026-10-06: done.** `Chrome.row` is one HBoxContainer on its own layer (253, above the home
screen and every panel), and each piece of furniture hands it its button with `row_button(who, b)`;
the row keeps `Chrome.ROW_ORDER` (⚙, >\_, Masking's ⤓, ⤓, 💬) and closes up around a hidden one.
The Environment panel is Chrome's, behind the ⚙ at the left end: open until the user closes it
(`[deps] open`, written only by the button), opened without writing when the probe finds a problem,
and its state line and color are the button's tooltip and dot. `[deps] collapsed` and the header
toggle are gone. One panel above the row at a time: each registers its closer
(`register_panel`) and reports opening (`panel_opened`); the export's status line steps aside while
one is open. The Assistant's picker moved into its own panel, refreshed on every probe, and its
panel now draws just under the row - on 126 it had been under the home screen, unseen. The home
screen is down to its title, its import field and its mode rows; the assistant rules stay statics on
Splash until step 8. Masking reuses Chrome's Assistant instead of building a second one, and its ⤓
takes the row's export slot as `&"mask_export"`. Two things learned: `find_children` cannot filter
on a script's class name (match the native class, then test `is`), and a FileDialog carries an
OptionButton of its own, so "no dropdown on the home screen" has to skip Window subtrees. Gates:
row_check (new: the geometry with a hidden ⤓, a claim lifting the row, one panel at a time,
`[deps] open` read back by fresh Chromes), splash_furniture_check (the panel through Chrome, and the
home screen keeps neither panel nor dropdown), splash_agents_check (the picker in the Assistant's
panel), deps_panel_probe (builds a Chrome). The full run passes, 101 of 101.

### Step 5: shared cards

One card per duplicated section (script, cast, voice, picture, Look, bookends), used by every mode
that has it. Tarot stops inheriting Generative. One frontmatter shape per component, with a
one-time rewrite of rift's documents rather than a reader that accepts both shapes. Settle the
Cards component's name and block first ([Cards](#cards-tarot-generalized)), so the tarot show is
rewritten once. **Done when**
doc_sync_check, multi_voice_check, cards_check and medium_pick_check pass on the shared cards, and
every rift chapter and show comes through the rewrite unchanged outside its block.

**Status, 2026-10-06: done.** One block per component under `ghost:` - `voice`, `picture`,
`illustrations`, `look`, `bookends`, `tarot`, `synthesis` - as siblings: a panel declares the blocks
it has cards for (`_doc_blocks`), and DocSource reads and writes those, merging per block and
carrying every other block through. The five rift documents that had blocks (chapters 39-42 and the
tarot show) were rewritten once by `tests/rewrite_blocks.gd`: a dry run, then `--write`, every old
value checked at its new place, each body byte-identical, and the real files byte-identical to a
rehearsal on copies; rift holds them as unstaged changes for the user. `ReadingPanel` is the reading
(the script, cast and voice cards, the stream, the transport's hooks, the export), and both
`GenerativeEditor` and `CardsEditor` extend it - Tarot no longer inherits Generative. The shared cards
are `LookCard`, `BookendsCard` and `PictureCard` (`KEY`, `capture()`, `apply()`), with
`IllustrationPanel` keeping its own block inside the Picture card. Declared rather than removed:
Hesitate shows where the panel's marks have a hesitation, and Ink only where the medium writes by hand
(it showed on the tarot table). THE NAME IS LEFT TO THE USER: `tarot:` keeps its name until Cards or
Deck is chosen ([Cards](#cards-tarot-generalized)). Step 9 reshapes that block anyway (reversals,
jumpers and the deck move into the guide), and the rename can ride along, so each block is still
rewritten once. Two things learned: `main.gd` typed the panel `var editor: GenerativeEditor`, which
would have refused the tarot panel outright, and no gate opens Tarot through main - a one-off probe
caught it, and step 6's teardown gate will keep it caught; and the rewrite tool's leaf-by-leaf check
caught the illustrations block nested one level too deep before anything was written. Gates:
doc_sync_check (one block per component, a stranger block carried through, the tarot panel reading
a chapter's cast and leaving its picture alone), medium_pick_check (the Picture card's rows and the
panel's Ink together), multi_voice_check, cards_check, panel_fit_check (its control counts a shared
card's rows), card_fold_check, youtube_check. The full run passes, 101 of 101.

### Step 6: teardown

Every mode can be left and entered again. **Done when** a gate attaches and detaches each one many
times and finds no leaked nodes, Chrome claims, bus effects or transport hooks.

**Status, 2026-10-06: done.** Chrome's row has a ⌂ at its left end, hidden on the home screen:
main hands Chrome `set_home(leave_mode, leave_blocker)` as a mode comes up. `main._end_session()` is
the one teardown for every mode - Auto's song end and the ⌂ alike - and frees every mode's nodes
(their `_exit_tree` lets go of the conductor, Chrome's claims, the tarot's pinned medium and the voice
host), ends the streams, detaches the Director (which drops a storyboard), stops Spectrum and clears
what the exporter asked of the mode; an export already rendering carries on. Leaving is refused,
with the reason on the grayed ⌂, while an export is making the mode's take (`Exporter.preparing()` -
the take is a coroutine on the mode's panel, and the export would wait on a freed panel forever) or
while Masking's own export renders (`MaskEditor.leave_blocker()`). One thing learned: nothing
needed fixing once a way out existed - every mode already let go of what it held in `_exit_tree` -
and the gate's numbers say so (797 nodes and no orphans after every return, from every mode). Gates:
teardown_check (new: all six modes through the real main scene, three visits each, the counts
steady from the second visit on, the refusal two-sided, and a control that a forgotten node is
counted), row_check, splash_furniture_check, splash_agents_check.

### Step 7: the registry

Components declare key, family, needs and provides, capabilities, marks and card, and
`Capabilities` answers for the platform ([Platforms](#platforms-desktop-and-android)). Modes become
templates, and main.gd's three session paths become one - so a command-line Masking session gets
Chrome. **Done when** each template makes the show its mode made (scene_mix_check's seed replay,
unchanged), and "+" grays a component whose capability is missing, with the reason.

**Status, 2026-10-06: done.** `src/capabilities.gd` is the table from [Platforms](#platforms-desktop-and-android),
each entry answering `impossible()` and `not_ready()` with a reason, plus one entry the table did not
have: `stage`, the show itself (a clock, a transport, a stage that plays), which a song, a voice and
the voice lab feed - without it the gate found a phone's "+" offering a song and the voice lab, and
the plan says a phone note is its text alone. `src/components.gd` holds the registry (label, blurb,
family - the families moved here from Card - needs, provides, requires, capabilities, mark groups,
block, card) and the six templates; the home screen builds its rows from the templates, and
`main.start_template(key, source)` is the one session path for every row and for `--synth`,
`--cards` and `--mask-edit`, which now runs after Chrome exists. "+" is `Components.attach_menu`:
impossible components left out, not-ready ones grayed with the reason. Where programs start,
`Subprocess` and `Deps.execute` refuse when `subprocess` is impossible. Both new files name no
autoload, so SceneTree gates and Subprocess can ask them; the agent registries are named by class,
since TextGen starts its agents through Subprocess. Two things learned: the mark groups a component
brings are declared but the script palette still filters by mode, until a note composes its
components (step 8 and after); and subprocess_pact_check's rare "2999 of 3000" was a real defect -
the two log pumps could splice one stream's chunk into the middle of the other's line - so each pump
now writes whole lines (`\r` counting as a line end, for yt-dlp's live progress). Gates:
components_check (new: the registry holds together; the table two-sided, on this desktop and asked
as Android; "+" grays Tarot with the reason when the agents are hidden), scene_mix_check (unchanged),
splash_agents_check, teardown_check, subprocess_pact_check.

### Step 8: the note and the notes list

Open any markdown file with no mode; "+" attaches; the note owns the clock, feeds, moments, places
and seed. The home screen goes: the app opens on the notes list, the templates sit in New, the
per-mode drafts in ghost.cfg become notes, `--note <path>` opens one, and "‹ Notes" leaves one.
**Done when** a gate starts the app on the list, makes a note from a template, plays it, leaves it
and opens another with nothing leaked; the drafts arrive as notes; and splash.gd and its two gates
are gone, their checks moved to the list's.

**Status, 2026-10-06: done as the "done when" reads; the deeper half of the step is not built yet.**
Ghost Notes opens on the notes list (`src/notes_list.gd`): New (the templates - a plain Note and the
six modes, gated on their agents as the rows were), Open… and the path or URL field, and the notes
newest first, from `NoteStore` (`src/note_store.gd`: the default folder `user://notes` plus the files
and folders the user adds). A note's template is read off its blocks (`Components.template_for`), and
`main.open_note` starts it through the one session path - a reading's panel pointed at the note
first, a song or a clip the note's own `song:`/`clip:` block. A new note carries only its marker
block, because an empty block is not "the defaults" to every card: an empty `illustrations:` wipes
the pictures' look. A note with nothing attached is `src/note_panel.gd`, its "+" offering what
decides what it becomes; attaching writes the block and reopens the note as that template. "‹ Notes"
tops every panel. The drafts became notes once (the user's Synthesis draft will, the first time the
list opens, and the two rift documents join the list), `--note <path>` opens one, `--no-splash` went,
and a song that ends stays in its note. splash.gd, splash_agents_check and splash_furniture_check are
gone: their checks are in notes_list_check and in assistant_pick_check (the Assistant picker's
gating, which splash_agents_check also held - deleting it would have lost that). NOT BUILT: the note
does not yet own the clock, feeds, moments, places and seed - each template still runs its mode's own
session underneath; there is no one-window editor (the plain note's text opens in ScriptWriter's
editor window); no note's own card (seed, frame); no on/ghosted, no "+" suggestions, no diff notes.
Things learned: DocSource assumed every source had settings to capture (a plain note has none); the
list's export claim had to be keyed apart from a note's. Gates: notes_list_check (new), assistant_pick_check
(new), teardown_check (now through the list, a plain note included), components_check, row_check.
The full run passes, 103 of 103.

### Step 9: Tarot becomes Cards

Tarot becomes the generic Cards component, in the order of [its primitives](#cards-tarot-generalized):
the action registry (no change in behavior), positions as data, card state over show time, decks
and faces from the guide, the recipe from the guide, agents that choose, and the rename last. The
tarot show's guide carries everything tarot-specific. **Done when** cards_check, table_wash_check
and table_place_check pass unchanged through the action registry; the tarot show plays from its file
as it does today; a second guide - flashcards, say - makes a show with no code of its own; a dealer
agent places cards through its tools and a gate finds every position on the cloth, in frame and
clear; and NO CHEATING still holds two-sided.

**Status, 2026-10-06: done in part.** Built: (1) THE ACTIONS ARE A REGISTRY - `TableActions` holds
the four written verbs and the three performed between them (push, square, lay), each with its args,
rest, whether it shows a card, lays the shown one first or ends the showing, and its moments;
CardReading's mark pattern, rests and compose and the table's schedule read it, and cards_check,
table_wash_check and table_place_check pass unchanged. (2) POSITIONS ARE DATA - `TablePositions`:
`{x, z, yaw, face}` on the cloth, from the plan's spread positions or a dealer's `layout.json` laid
over them, used only whole and sound, else the seeded presets (the old spread, same draws in the same
order, kept verbatim in table_positions_check as its oracle). Every position is checked the same way -
on the cloth, in the camera's frame, clear of the deck - against the episode's own camera, a pure
function of its seed. Measuring the presets against that found a real fault: an arc or a row of
seven or eight cards put a card partly outside the frame in 2.6% of such spreads (up to 7% of the
frame); those are laid as two rows now, with the same hand's offsets and no draw of their own, and
every other spread is identical. The card's size is one constant. (6, part) A DEALER'S TOOLSET -
`DealerTools` (place, flip, look, submit), told what the table objects to as it places, refused until
whole and sound, told no card's name; and a READER'S REPLY keeps only the voice's marks
(`voice_marks_only`) - a table mark in it would have been parsed as an action. NOT BUILT: (3) card
state over show time and more than one card up at once; (4) decks and faces from the guide; (5) the
recipe from the guide - the prompts' wording is tarot through and through ("reader" 42 times,
"spread" 18, "booklet" 13), so a flashcards show with no code of its own means moving that wording
into a show's guide, which is the user's brief to write; a dealer run by a real agent (the tools exist,
no episode step calls them); and (7) the rename. Gates: table_actions_check and table_positions_check
(new), cards_check, table_wash_check, table_place_check (unchanged).

**2026-10-07: (5) in part - a second guide makes a show with no code of its own.** A guide's
`## Format` section takes "tarot" out of every prompt (the shared context maps the recipe's words
to the show's; the producer names the deck's `kind`, which the designer and painter use), and a
`## Cards` section of prose alone lets each episode's producer choose its box, drawn from by the
seed (`CardDeck.chooses`). First show: `rift/tarot/the-shoebox.md`. The recipe's verbs and its
words in code are still the tarot's; the guide maps them. Gate: cards_choose_check (next/cards.md).

**2026-10-07: (3) and (6) in part - the staging.** Card state over show time is each card's own
timeline (arrive, show, lay, turn), and the producer chooses how the cards come and are shown: a deck or
a box (cards filed on edge), the text in a booklet or on the card's back (held alone, turned over),
printings with their own backs, and per position dealt, swept (a waterfall), sideways, stacked and
tapped later. New verbs `open`, `deal`, `fan`, `show`, `tap`, `untap`, `flip`. Still not built: the
card's size and face template, `flip` for the producer, more than one card held up at once, and the
dealer run by a real agent. Gate: table_staging_check (next/cards.md, "The staging").

### Step 10: portrait

Independent of steps 2-9: it can start any time after step 1. In order: the `frame` setting and
`--frame`; `Medium.FRAMES` and the pickers; the preview fit; the exporter (the window's shape,
`aspect="keep"`, the portrait presets, the thumbnail, `+faststart`, the 3-minute notice); subtitles
in the frame's safe area; the four full-frame scenes; the tarot's hard-coded 16:9 values; the
tablet's distances. A single-page comic, book and notebook, and a portrait tarot table, come after,
as design work of their own. **Done when** the four gates in
[Two frames](#two-frames-landscape-and-portrait) pass - the small real render that reads back
1080x1920 among them - and a landscape export is unchanged.

**Status, 2026-10-06: done for full frame; the rest of the frames are not built.** `Director.frame`
and `--frame` beside the medium, kept in the note's `picture:` block through the Picture card's Frame
picker; `Medium.FRAMES` (portrait only for full frame, as measured) and `resolved_frame()` falling
back to landscape. The preview is the frame - the stage the frame's shape, centered, black beside it
- and the filters follow it. Subtitles lay out in the frame, a portrait one inside the platforms' safe
area (`Subtitles.text_area`), a landscape one exactly as before. The exporter: a portrait render
window shaped like the frame with `aspect="keep"` (a landscape override byte for byte as it was), the
turned presets and no 4K portrait, `--frame` to the render, a frame-shaped thumbnail, `+faststart`,
and the over-3:00 note. Photographed at 9:16, cloth leaves most of the frame an empty dark green under
a line near the top and two_eyes sits its eyes against the frame's edges; tidepool and falling_sand
fill it. NOT BUILT: those scenes' tuning, the tablet's distances (it stays landscape), the tarot's
16:9 values, and portrait comic, book, notebook and tarot layouts. THE TRAP, MEASURED (it was only
reasoned above): a 1080x1920 render in the old 480x270 window lays the show out in a 3413x1920 view,
and Movie Maker records its middle 1080 - the file is the size asked either way, and the picture's
edges are what is lost, not its shape. So a file's size cannot see it: the render now says the view it
laid the show out in (`ghost export: view WxH` in its log), and the gate compares that with the
picture recorded. Gates: frame_check (the headless exporter checks, the stage and the safe area
through the real main scene, measured against the window as it is - headless Godot's is 64x64, a
square view) and portrait_render_check (GPU: one small real render, 1080x1920 recorded and laid out in
exactly that view, and the old override as its control). The scene look probe at 9:16 is
scene_look_probe with `--size 540x960`. THE FULL RUN, steps 9-11 together: 105 of 108 gates passed
(five `ok*`, the known teardown faults); three failed and were fixed, then passed on a rerun -
frame_check (it assumed a 16:9 window), panel_fit_check (the new Frame picker widened the
Generative panel to 427 px against 380: an OptionButton is as wide as its longest item, so its items
are short now and it does not fit to the longest) and portrait_render_check (its control came out
1080x1920 too, which is how the trap above was found to be a crop and not a size).

### Step 11: the phone

The phone shell ([Platforms](#platforms-desktop-and-android)): the list and the editor,
`user://notes/`, the system picker, portrait, the trimmed preset, `--handheld`. **Done when** the
APK on the phone opens the list, makes, edits and keeps a note across restarts and tries no
download, and a desktop gate runs the shell under `--handheld`.

**Status, 2026-10-06: done on the desktop; the phone itself is the user's to try (no device was
attached).** `src/phone_shell.gd`: on a phone, or `--handheld` / `GHOST_HANDHELD=1`, main builds the
shell and nothing else - the notes in `user://notes/`, a full-screen editor written on a quiet period
(the body through `FrontMatter.write_body`, the title as its line), Import… and Export… through the
system's picker (`DisplayServer.file_dialog_show`, `content://` on Android), Android's back, a save on
pause. No stage, transport, furniture, agent or download (`Provisioner._may_run` refuses). The
settings a phone depends on are gated, because Godot drops a value equal to its default when it
rewrites project.godot: portrait orientation, and a portrait canvas for mobile (the desktop's 1920x1080
canvas would have drawn the shell at half size on a portrait phone). The trimmed Android preset was
step 1's. Gate: handheld_check (passed in the full run with steps 9 and 10). `scripts/build.sh
--install android` builds and installs the APK.

### After the first review (2026-10-06)

The user tried the build and sent a round of revisions. **Status: done; gates below.**

- **The notes list makes notes and nothing else.** The large name and tagline over the main area are
  gone (the panel keeps them), and so are Open… and the path/URL field ("a URL input panel causes
  immediate confusion"). A song or a video is a component of a note now: the Song card's Choose…,
  and Masking's Clip card, which takes a file or a link. New ends on "Existing note…", which brings a
  markdown file from anywhere into the list (markdown only).
- **Every note can be deleted.** The list's × and every panel's "⋯" (`Chrome.note_menu`) ask first
  (`src/delete_dialog.gd`); the note goes to the system's trash (`NoteStore.trash`, with a
  `discard` seam so a gate never fills the author's trash), or, for a file added by hand, can just
  leave the list. A note that is open is left first - its panel writes what it holds - then trashed.
  The phone shell's editor has Delete… too.
- **Every note starts from nothing** ("every time we enter a note, we should wipe the scene and start
  fresh"). The medium a note was shown in is freed with it (`main._clear_stage`; it used to stay
  mounted, so a tablet chapter's desk showed under the next plain note, around Masking's video and as
  the "scene" of a song), the stage is hidden until a show attaches, the Director's picture settings go
  back to their defaults as a note opens (`Director.reset_show`) for the note's blocks to set, and a
  song note opens loaded and stopped at its start. A reading's Stop hides the stage too.
- **A song is a note's component, and Auto is a medium.** Song notes (Auto, Manual, and any note a
  song is attached to) are `NotePanel` now - the panel never hides - with the note's components as
  cards: the Script, the Song (`src/song_card.gd`), the Picture, the Look, the Intro & outro, the
  Storyboards. Without a Picture the song plays to an empty frame; "+" offers a Picture for it (and
  grays the Look and storyboards, "Needs a Picture"). The Picture's media are what a song can carry
  (`Medium.offered`: not the novel, notebook or tablet, which print a reading) with AUTO first
  (`src/media/auto.gd`, `Medium.BARE`): the original show with nothing to set - the card shows only
  the picker, picking it puts the dials back to their defaults, and its block is the medium's name
  alone. A medium picked while a song is loaded is shown at once (`main._restage`). New -> Auto is a
  song note with a Picture in the Auto medium; New -> Manual adds the Storyboards card
  (`src/storyboards_card.gd`, the Workspace's list, which is gone) and the dial. "New -> Auto did
  nothing" was a song session started on an empty path: no audio, no panel, no transport.
- **Tarot is Cards** ("I don't want Tarot in our refactor; I want to use Card as the name") - step
  9's (7). The component and template `cards`, the panel `CardsEditor`, the classes `CardEpisode`,
  `CardProducer`, `CardPrompts`, `CardReading`, `CardDeck`, `CardTable`, `CardFaces`, the medium
  `table` (`TableMedium`, "Card table"), the block `ghost: cards:` with its range `draw:`, the marks
  `<!-- table: draw 2 -->`, `--cards`, `user://cards/` (moved from `user://tarot/` once, at the first
  launch, the episodes' script marks rewritten; `main._adopt_old_episodes`, to delete once it has
  run), `fonts/cards/`, `data/decks/tarot/`, and the gates `cards_check`, `table_wash_check`,
  `table_place_check`. The card folds moved to `[folds]`, since `[cards]` is the panel's section now.
  What stays tarot is the content: the Truthful Tarot show (its one rift document rewritten to
  `cards:`), the standard 78, and the prompts - the recipe is still the tarot's, which is (5). The
  seeds' hash salts keep their `tarot-` names, so episodes already made come out the same.
- **Masking is in the framework.** Its panel is a `SidePanel` like every note's - "‹ Notes", the
  note's title, its "⋯", a chip per card - with three cards: the Clip (its name, ⬆ Track, Help, the
  time), the Effect (the key color, the effect and the options: one flat, sortable list, as feedback
  0011 asked) and the Markers, PINNED under the rest (`SidePanel.add_footer_card`), as the ramp/damp
  list always was. With no clip, the panel asks for one (a file through the in-window dialog - the
  native one shows nothing without a portal - or a link), and what is chosen is written into the
  note's `clip:` block. The stage no longer shows around the video. Masking keeps its own playback
  (its timeline, Space) - one transport for it too is still to do.
- **"Edit Script…" is "Edit"**, everywhere - a note's words, a chapter, a show's brief.
- Removed as finished one-time migrations: `NoteStore.move_drafts` (the drafts became notes on the
  user's machine) and `tests/rewrite_blocks.gd` (the step-5 document rewrite).


## Questions, answered

The user answered the open questions on 2026-10-06. Each answer is recorded here and carried into
the sections above.

- **Editor or stage?** One window: the main area holds the note's text while you write and its stage
  while it plays, and a note with nothing visual attached never shows a stage. ScriptWriter's pop-up
  editor becomes that main area.
- **Where do notes live?** In a default folder - and the user can point Ghost Notes at any other
  folders and files, because "it's not realistic to prevent people from sourcing their own content
  from other projects, git repos, etc." The list shows them all. On the phone, `user://notes/`.
  **A database may come later**, for speed, links between notes and a graph of them. So the storage
  sits behind one small interface from the start (list, read, write, watch), and a database can
  arrive without touching a component. My advice for when it does: keep the files the source of
  truth and make the database an index rebuilt from them. Obsidian keeps notes as plain files in a
  folder the user picks and watches them for outside edits; Logseq's database version gave up the
  files. The first keeps the selling point - one plain markdown file - and the second does not.
- **Diff notes** (the user's name for child notes, "like a git diff; the difference between one note
  and its copy"). A diff note names its base and stores only what it changes: settings key by key,
  and its own body if it has one. Everything else it reads from the base, so a change to the base
  reaches every diff note that did not override it. The prior art is close to home: Godot's
  inherited scenes store only their differences from the base scene and mark an overridden property
  with a reset, and Unity's Prefab Variants work the same way. A tarot episode becomes a diff note of
  its show: the episode's script as its body, its seed and drawn cards as overrides, the voices and
  the look from the show. Open: whether a body may be a line-level patch of its base's body - a true
  diff, which brings merge conflicts with it, as git's do. Start with "inherit or replace";
  DocSource's three-way merge (`merge3`) is there when patches are wanted.
- **Storyboards.** Left to me, "without going overboard": they stay the Scenes card's own files, as
  now, and a note names the one it uses in its Scenes block. Nothing more until someone needs it.
- **Where generated things live.** Not a question - the plan stands: `user://notes/<id>/<component>/`,
  generalizing Tarot's `show` key. The id lives in the note's frontmatter, so a note's generated
  files follow it when the file moves or is opened from another folder. And a note names a
  reference by its content hash (the library already names its copies that way), never by an
  absolute path such as
  `/home/crow/.local/share/godot/app_userdata/ghost/illustrations/refs/49b1c1e7ac9a6fb9.png`, which no
  other machine has.
- **The families, and their colors.** No answer, and a rule for this kind of question: when in
  doubt, be flexible, because a compositional system will be used differently in different notes.
  So each family has a default hue, and a note can recolor any of its cards (`color:` in that
  component's block). One saturation and lightness, checked in both themes, never color alone.
- **Ghosted.** Kept: "go for it - and we'll remove it later if we don't need it." A ghosted
  component still runs - it keeps time, makes moments, drives the scenes - but it is not heard or
  seen. The clearest use came out of the portrait research: ghost the song, and the show still moves
  to it while the export carries no music, so a Short made on a commercial song meets no Content ID
  claim, and the song is added afterward from the platform's own licensed library. A ghosted voice
  likewise times a picture-only cut for narration recorded later.
- **Whose defaults?** No answer; the rule stands. A note opened with no block for a component starts
  from that component's defaults, never from the note open before it, and ghost.cfg holds only the
  viewer's preferences.
- **Tarot, as a mode, is too specific.** The user's own addition: generalize it into Cards. See
  [Cards: Tarot, generalized](#cards-tarot-generalized).

**Still open:** the name of the Cards component (it collides with our own word for a component's
settings; see its section), line-level diffs in diff notes, the database's role and timing, and the
key that skips a scene once Space is play/pause.

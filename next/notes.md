# Ghost Notes: every project is a note

Every project is a note with attachable components, each a colored card in the left panel. The six
old modes are components of a note, not templates. This document is the design and the plan that
built it; [The plan, in order](#the-plan-in-order) says how, step by step, and each step's Status says
what is built and what is left.

**Decisions:**

- Every project is a note with attachable components, each a colored card in the left panel.
- The continuous meeting point between components is a **feed**, not a signal: Godot already uses
  that word for something else ([How components meet](#how-components-meet)).
- **No home screen.** Ghost Notes opens on the left panel, with the notes listed and the name and
  tagline at its head. The Environment panel sits behind a fourth button in the bottom-right row, open
  until first closed ([The shell around the note](#the-shell-around-the-note)).
- **One transport** - play, pause, stop and the scrubber - for every note ([The transport](#the-transport)).
- **Two frames**, landscape 16:9 and portrait 9:16, exported in either where the presentation allows
  ([Two frames](#two-frames-landscape-and-portrait)).
- **An Android build that takes notes and nothing else**, behind a capability gate every component
  declares against ([Platforms](#platforms-desktop-and-android)).
- **A repository of its own**, `../ghost-notes`: flat, the GDScript folder is `src/` and build scripts
  are in `scripts/` ([Step 0](#step-0-move-to-ghost-notes), [Step 1](#step-1-build-scripts)).
- **One window:** the note's text while you write, its stage while it plays.
- **Notes live in a default folder, and anywhere else the author points** - other folders, other
  repositories, single files - behind one storage interface, so a database can come later.
- **Diff notes:** a note can be a copy that stores only its differences from its base.
- **Ghosted stays**, until it proves unused. **Colors** are a family default a note can override.
- **Tarot generalizes into Cards** (later named Table): any deck, any table, actions an agent drives
  through tools, and everything tarot-specific in the guide ([Cards](#cards-tarot-generalized)).

## The idea

One thing instead of six modes: a **note**, and Ghost Notes opens on a list of them, the way a notes
app does. A new note is a plain text editor and nothing else. Everything ghost does becomes a
**component** attached to a note. Write a script and attach a voice, and the note speaks. Attach the
table, and the voice reads at a table. Attach scenes, and the show answers the voice.

The left panel is a stack of **cards**, one per attached component, each bordered in its component's
color (the generative voice in turquoise, say), so it is plain which settings belong to what. A row of
chips on the note, one per component, brings each card into view.

Nothing is wired. Attaching a component is declaring it, which is how the rest of ghost already works:
a scene declares what it can morph from, a medium declares the settings it uses, and the show is a
function of what was declared ([Why nothing is wired](#why-nothing-is-wired)).

## The note is already half there

**Documents carry their components, keyed by the wrong thing.** Generative, Synthesis and Tarot sync
to a plain markdown file the author owns and keep their settings under its `ghost:` frontmatter key
(`FrontMatter`), one block per panel. The voices and the picture are the same components in each, but
the blocks were per mode (`ghost: generative:`, `ghost: tarot:`), so opening a chapter in Tarot lost its
voices. In a note, `voice:`, `picture:` and `tarot:` are siblings, and a block being present is what
"attached" means.

**One unsynced draft per mode.** ghost.cfg held `[generative] text`, `[tarot] text` and `[synth] text`:
one unsaved note per mode and nowhere to put a second.

**Settings with no home ended up in other modes' panels.** Auto had no panel. Its picture settings
(Look, medium, scene hold, flourishes, bookends) drive the Director in every mode but Masking, and were
stored twice, globally in `[director]` (the film frequency in `[films]`) and per chapter in `picture:`.
A card is the second home, found because it appears wherever a picture is made.

**Presentation was pulled out of the modes once, and it worked.** A mode decides what drives the show
(a song, a storyboard, a voice); a medium decides what it is presented as, and every mode gets both
(media.md).

**The panel already follows declarations rather than branches.** `Medium.USES` lists the setting groups
each medium shows ("adding a presentation is an entry in these tables, never new control flow somewhere
else"). `Filters.REGISTRY` builds its own rows, and every entry in `ScriptMarks.REGISTRY` carries a
`modes` filter, which becomes a component filter.

**Moments exist twice.** `CardTable.MOMENTS` (shuffle, jumper, reveal, pirouette, lay, close) are what
the air effects fire on. In Synthesis the fishing owns the moments (`Director._should_change`): a catch
or a seed jump cuts the scene. Both are one part telling another that something happened.

**Sound meets in one place.** `Spectrum` analyzes the Master bus, so a song and a voice take reach the
scenes the same way, and it owns the show clock (live, baked, or counted from frames in a render). A
clip is the exception: Masking plays on its own bus and never reaches Spectrum, and a film panel is
muted, so no clip's soundtrack moves the scenes. The Director owns the picture settings, and main.gd
builds the medium and hands it to `Director.attach`.

**A blackboard already runs.** `TableEpisode`: each step posts a file, a step runs when what it needs
exists, and a redo invalidates what was made from it. That is the shape agents keep for any component.

**The card is an engine node.** Godot 4.7 ships `FoldableContainer` - a titled container;
`add_title_bar_control()` puts buttons in its title bar, and its `panel` / `title_panel` styleboxes carry
the border - and `FoldableGroup`.

## Where the duplication is

The duplication was in the shells, not the engine. Director, Spectrum, the scenes, the Exporter, Chrome
and the registries are shared. What was copied is everything around them: the panels, the mode wiring in
main.gd, and persistence.

- **Panels were built four ways:** SidePanel (Synthesis, Generative, Tarot by inheritance), Manual's
  `Workspace`, Masking's full-height panel, and Auto with none.
- **Synthesis and Generative mirrored each other by copy:** the header, the ScriptWriter wiring, F2 to
  hide, the status line, the autosave, document capture/apply and the subtitle sidecar.
- **Tarot inherited Generative and spent its effort removing things** (24 overrides): `_doc_capture`
  erased six keys the base wrote, `_build_cast` hid a row the base built, Intro and Outro were declared
  twice. Ink, the pen a voice writes in on the Notebook, showed on the tarot table.
- **main.gd started a session three ways:** three start/stop pairs, three subtitle-attach paths, the
  Exporter wired by copy with different values, and Space bound in three places meaning two things.
- **Masking predates Chrome and rebuilt it:** its own feedback console, Assistant and export, which
  never received the Exporter's virtual-display render or streaming transcode.
- **Every control was listed three or four times within its own mode** (slot defaults, capture, apply,
  the builder, the effect applier). `Settings.bind` removes the persistence half of this.
- **Three agent pickers** (Tarot, IllustrationPanel, the home screen).

A component is the unit all of these collapse into: one card builder, one capture/apply, one
frontmatter block, one place it is torn down.

## The model

### The note

A markdown file: frontmatter, then a body. Notes live where the author already keeps them, and Ghost
Notes remembers the recent ones. With nothing attached, it is a text editor. The file stays plain
markdown that any editor can open: marks are HTML comments and settings are frontmatter, and nothing a
component does may change that.

Every note has one card that cannot be removed: its own. Title, author and book, or a show's byline,
the seed, the frame, and the bookends once anything plays. It takes no component color; it is the paper.

### A component

An entry in one registry shaped like `Medium` (key, label, blurb, `make()`, a base class with small
hooks). An entry declares:

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

Needs and provides are typed names that ghost matches, the way a scene's `morph_out` and `morph_in` are.

**A family says how many.** Some components are alternatives: one presentation per note (Comic, Book,
Notebook, Tablet, the table; full frame when none is attached). Some stack, like Look filters. Some are
one card with plurality inside: one Voice, with a tab per speaker. The family declares its count, and
nothing checks pairs. A component that makes something brings its own presentation: attaching Table
attaches the table.

**Speakers belong to the note, not to the voice.** The cast is read from the text's speaker cues, and
other components want per-speaker settings (Voice adds the voice, Notebook adds the ink). A field has
one identity, whichever component uses it.

**In Godot terms.** A component is a node under the note's node. The meeting points below are services
the note hands its children - Spectrum and the Director are autoloads - and groups answer "which
attached components provide a reading".

### A card

One `FoldableContainer` per attached component. The border is its family's color; the title bar holds
its icon, name, the toggles and a small menu: defaults, "Same as..." (take this card's settings from
another note), detach, help. A few essential controls show, and the rest sit behind "More" - two levels,
never three. A value that differs from its default is marked and has a reset. A need nobody provides is
a sentence on the card ("the Notebook follows a reading - attach a voice"), never a control that silently
does nothing.

**The color follows the component everywhere:** the card's border, its chip on the note, its marks
highlighted in the text, its moments on a timeline.

**Color is per family, not per component,** as in Scratch and Blockly categories and TouchDesigner's
operator families. Hues run out near eight, and since most families allow one member per note, within a
note it still reads as one color per component. The two voice engines share turquoise; the presentations
share another. One saturation and lightness for every hue, checked in both themes, and never color
alone: always the icon and the name. The family's hue is a default: a note can recolor any of its cards.

**Order is derived, never dragged:** text, then producers (Table), voices, sound, pictures, the
presentation, and the Look last. Read top to bottom, the panel says what happens to the note.

### The component row

On the note, under its title: one chip per attached component in its color, then "+". A click brings that
card into view (cards never fold; see next/panel_deck.md). "+" lists what can be attached, grayed with a
reason when something cannot be: no agent installed, or not on this device
([Platforms](#platforms-desktop-and-android)).

**"+" suggests what the text already asks for.** Speaker cues suggest a Voice, `<!-- url: -->` marks the
Tablet, image marks Illustrations (`TabletScript.is_tablet`; what is inferred is never written).
Suggested, not attached: attaching can start a model download or an agent.

**Three booleans, kept apart:**

- **Open** - a view state, the viewer's, kept in ghost.cfg. Dropped: in the deck a card never folds.
- **On** - evaluated or not. Off keeps every setting, so switching back restores it. The note's, in its
  frontmatter.
- **Ghosted** - evaluated but not heard or seen. This is a ghost note, a musical term: rhythm with no
  pitch. A ghosted voice still sets the show's time and its moments and is not heard; a ghosted song
  still drives the scenes, for a picture-only export cut to its timing - which is also how a Short on a
  commercial song avoids a Content ID claim: the song is added afterward from the platform's own library.
  A toggle shows only where it changes something, so the Look has no ghost state.

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

Components never refer to each other. If Table has to know that scenes exist, every new component pays
for every old one (n squared pairs), the trap the modes were in (the Director's `_game_paced` was the
fishing game reaching into the scene cutter). Components meet only through things the note owns. There
are five.

1. **One clock.** Every output is a pure function of show time, which films, the tablet and the export
   obey. One component conducts - its length is the show's - chosen by a fixed order, never asked: a
   voice, else a clip, else a song. That is always audio, which is also what ffplay and Godot's sync
   guide make the master clock. With none of them, the note is not timed and shows no transport.
2. **Feeds.** Continuous and typed: the audio (one mix; a song ducks under a voice), the spectrum and
   harmonic signature (`Spectrum`), the reading position (`ReadingFollower`). A component reads what it
   needs and never asks who made it. Values are clamped and NaN-guarded once, at the source.
3. **Moments.** Discrete events on one schedule: a sentence, a speaker change, a mark reached, a card
   laid, a catch, an onset, a cut. Computed ahead, the way the tablet computes its actions into the
   voice's rests, so a moment falls on the same frame live and in an export, and a scrub lands in the
   middle of a schedule. "The scene cuts when a card is laid" is a Scenes setting that names a moment -
   not code in Table, and not a flag in the Director.
4. **Places.** A presentation offers places a picture can go: comic panels, the tablet's screen, the
   notebook's clipped photos, the book's illustrations, the faces of cards. Picture components fill
   places. The comic already does this with scenes in panels.
5. **Seeds.** One seed per note. Each component draws from it XORed with its own key, the fold
   `Director._pick_salt` uses. Attaching or switching off one component never changes another's draws,
   which makes switching one off a fair A/B.

Feeds are the continuous half and moments the discrete half - the split harmonic_seeding.md makes for a
song's signature, and the split functional reactive programming began with: behaviors are values over
time and events are occurrences (Elliott and Hudak, 1997).

**Why "feeds", not "signals".** A Godot signal is an event: an object emits it, and every connected
function runs, there and then. A feed is a value over show time, read, never delivered. A moment is a row
in a schedule, asked for by time, because a scrub and an export must find it again. Godot's signals keep
the job they have: telling whoever listens that something happened (`Director.filters_changed`,
`TableProducer.changed`).

**Modulation is the creative half.** Any numeric control on any card can be offset by a feed or a
moment, within a range drawn on the control (as in Bitwig): the Look's static rising with the voice's
loudness, the scene hold shortening while a character speaks, the camera easing in on `reveal`. A few
macro dials on the note's card can each fan out to many controls with ranges. Both are data on the card
that consumes them. Few dials, small steps, eased per sentence - never a switch.

**One place where order matters: text walks.** Components that own marks rewrite what the voice reads.
The tablet strips its marks and leaves rests (`TabletScript.speakable`), and Table swaps the body (a
brief, never read aloud) for the episode's script. In the model it is a chain of walks ordered by family,
and it is the only chain.

**The text as a feed, optionally.** With no voice, the words could still steer the look: SimHash, the
hash harmonic seeding runs on chroma, is best known on text (Manku et al., 2007). As a bias on the seed,
never a replacement, and a hash of the saved note, never of a live value, so it reproduces frame for frame.

### Three combinations, walked through

- **Voice + Table + Scenes.** Table needs the text (as its brief) and agents, and provides an episode
  script (a text walk), the table (a presentation) and moments. The voice reads the script. Scenes need
  a place; the table offers the card faces, and Scenes cuts on `lay`. Nothing in Table names Scenes.
- **Clip + Voice**, a narrated video. The clip provides a picture and audio, and it conducts, so a
  reading longer than the clip is a gap the card names. Masking's effects ride on the clip.
- **Song + Notebook.** The notebook follows a reading, and a song provides none. The card says so and
  offers two fixes: attach a voice, or a lyrics-alignment component that would provide a reading from a
  song.

## Why nothing is wired

Scratch, Blockly, Max, VCV Rack and TouchDesigner have wires because their parts are running processes
that must be told where to send output. Ghost is declarative: a part says what it is and what it reads,
and the engine derives the rest.

- A scene declares its render kind and the geometry it leaves and can grow from (`morph_out`,
  `morph_in`). When the types match the Director morphs; when they do not it cuts.
- A medium declares the settings it uses.
- A storyboard is data, every number a sampleable range.
- The table, the tablet's screen, a film's frame (`Films.position_at`) and the book's opening are pure
  functions of show time.
- Agents write data, not code: the set dresser describes things in the vocabularies `Props` and
  `Effects` publish, and ghost sanitizes and builds them.
- The show is a pure function: the seed is `hash(fingerprint(audio):SEED_SALT)`, so a six-hour render's
  schedule replays in about a minute (its seed and running order exactly; its cut times not yet).

The declarations are the program, and the graph is implicit in what each part reads, as in a
spreadsheet. Where a real choice remains (which place a picture fills, which moment a cut follows), it is
a picker on the card of the component that consumes it: a declaration, never a cable.

The duplication sat exactly where ghost was not declarative: the shells were hand-built panels and
imperative session wiring. The component registry does for modes what `Medium.USES` did for the panel.

**Honestly graded.** Not every part is a pure function. Cloth, boids and murmurations integrate state
frame by frame, and the harmonic signature is an EMA: deterministic from the seed under the render
clock, close but not bit-exact live. Agents are not functions at all, so an agent's output is written to
a file when it lands, and from then on the show is a function of that file. The claim that holds
everywhere: the show is determined by what is declared.

- **Nothing to wire.** Write, attach, play.
- **The same note makes the same video.** Seeds and agents' outputs are kept.
- **The note is the project.** One plain markdown file to read, diff, version and share.
- **Agents write data, not code.** A bad answer is sanitized, never executed, and what an agent made is kept.

## The shell around the note

Three changes, all in the shell, none in the engine.

### No home screen

A notes app opens on its notes, so Ghost Notes does. The left panel is the first thing on screen, and it
lists notes (the name and tagline at its head, then New and Open…, then the notes newest first).
Opening a note turns the panel into that note's cards, with "‹ Notes" at the top to go back, and the
main area into the note: its text while you write, its stage while it plays. While no note is open, the
main area shows the name and tagline in large type, with no controls. (`byline:` is a table show's own
line, so the plan says tagline.)

Everything on the old home screen (`src/splash.gd`) has a new home:

| on the home screen                                                       | moves to                                                                                                    |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| the name and tagline (`Boot.NAME`, `Boot.TAGLINE`)                       | the head of the notes list, and the stage while no note is open                                             |
| six mode rows                                                            | derived from a note's components                                                                            |
| agent gating (`Splash.AGENT_ROLES`, `missing_roles`, `agents_tooltip`)   | the component registry: anything needing a writer or a painter is grayed with the same tooltip, in "+" and New |
| Import… and the path or URL field (`[audio] last`, `[video] last`, `[ui] kind`) | the Song and Clip cards; a file or link dropped on the list makes a note with that component attached |
| the Assistant dropdown (`[assistant] backend`)                           | the Assistant's own panel, its only user                                                                    |
| the key hint (F11, the feedback key, Esc)                                | tooltips                                                                                                    |
| the Environment panel (`DepsPanel`)                                      | its own button in the bottom-right row                                                                      |

**The list.** The notes in the default folder and in every folder or file the author has added, newest
first, all through one storage interface. The unsaved text ghost kept per mode becomes ordinary notes
the first time the shell starts, and ghost.cfg stops holding text.

**Startup.** `main._ready` shows the list. Flags that open something directly keep doing so; `--note
<path>` opens one note. With one session path, a command-line Masking session gets the shared furniture.

**Leaving.** "‹ Notes" is a way out of every note, so teardown comes before the list replaces the home
screen.

### The Environment button

The bottom-right row is one container: each piece of furniture adds its button, and a hidden one closes
up. The Environment button goes at the row's left end, so the others keep their places.

**Open until the author closes it.** `[deps] open`, default true, written whenever the panel is opened or
closed. A first launch shows it; from then on it starts closed. A problem the probe finds opens it
without writing the setting, because a missing dependency must be seen; its one-line state
(`DepsPanel._refresh_title`) is the button's tooltip and a colored dot.

**One panel above the row at a time.** The console's log, the Assistant's panel, the export's status line
and this panel open into the same space; opening one closes the others.

### The transport

One bar along the bottom of the stage - play/pause, stop, the time and the length, and the scrub rail -
built as Chrome furniture, so every note gets the same one, Auto included. It shows exactly when
something conducts; an untimed note has none. It belongs to the clock, so to the note; it has no card
because every timed note has exactly one.

**The conductor implements it.** A component that can conduct (Song, Voice, Clip) registers play, pause,
stop, position, length and seek with the clock. A register/unregister pair, cleared on detach, replaced
the three bare Callables Spectrum held (`scrub_pos`, `scrub_len`, `scrub_seek`).

**Space is play/pause everywhere**, except while typing; skipping a scene has a key of its own (N).
Left/right and Home keep seeking.

**Pause stops all of show time,** including the intro and outro counters.

**What stays on a card.** A voice's Test plays one voice through its own player, outside the show;
Synthesis's click on a seed is an audition; Masking's timeline stays its workspace's editing tool. A song
that ends returns nowhere: the transport stops at the end, and the loop is a setting on the Song card.

## Two frames: landscape and portrait

TikTok, YouTube Shorts and Reels want 9:16. Two standards, no more, and export in either where possible.

**A frame is a property of the show**, like the medium: `frame: landscape` (1920x1080) or `frame:
portrait` (1080x1920), kept beside `medium` in the note's picture block. The Director keeps it as it
keeps `medium`, and `--frame` overrides it for one run.

**Each presentation declares the frames it supports**, in a `Medium.FRAMES` table beside `Medium.USES`.
The pickers offer only what fits, and a note that asks for a frame its presentation lacks falls back to
landscape and says so on its card.

| presentation        | portrait          | why                                                                                                                                                                                                                                                   |
| ------------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| full frame (scenes) | yes               | scenes size everything off the frame's short side, `SceneView.visible_half` covers any frame, and comic panels already run every scene at shapes from 0.42 to 2.6; four scenes need tuning (tidepool's grid, cloth's sheet, two_eyes' spacing, falling_sand's chamber) |
| tablet              | after a parameter | its `landscape` and `portrait` marks turn the device, not the video; its camera distances assume 16:9 and would cut reading lines at 9:16, so they become a fit on both axes                                                                         |
| comic               | not yet           | the two-page spread exists because one page cannot cover a 16:9 frame; portrait wants a single page - design work                                                                                                                                      |
| book, notebook      | not yet           | the camera frames a spread; portrait means framing the page being read                                                                                                                                                                                |
| table               | not yet           | the deck sits outside a 9:16 view, and several 16:9 values are hard-coded; a three-card reading also runs 4-6 minutes, past a Short                                                                                                                   |

**The preview is the frame.** The stage is the frame, centered in the window - 16:9, or 608x1080 for
portrait in a 1920x1080 window, black beside it. The side panel sits clear of a centered portrait frame,
the Look filters follow the stage's rect, and the vignette is fitted to the frame.

**Subtitles lay out in the frame, inside a safe area.** At 1080x1920 a baseline in the window would sit
under the buttons every platform draws over the bottom third and the right edge (Google's safe zones for
1080x1920 keep the top 288, the bottom 672 and the right 192 pixels clear).

**Export:**

- Portrait presets are the landscape ones turned: 720x1280 at 30 fps and 1080x1920 at 60. No 4K
  portrait - Shorts stop at 1080p and Instagram at 1920 pixels wide.
- **The trap.** The exporter records the viewport inside a fixed 480x270 window (`Exporter._write_override`).
  Window and viewport are independent only while they have one shape: under the project's `expand`
  aspect, Godot widens the viewport to the window's shape, so a 1620x2880 render in a landscape window
  would come out about 5120x2880 (reasoned from Godot's stretch rules, not measured). So the render
  window takes the frame's shape, and the override also writes `window/stretch/aspect="keep"`.
- The thumbnail is cut at the frame's shape.
- The MP4 is written with its index at the front (`+faststart`): Instagram's API requires it.
- A portrait export longer than 3 minutes is not a Short, and the export says so. A Short longer than a
  minute with any Content ID claim is blocked worldwide.
- The YouTube upload needs no change: a vertical upload of 3 minutes or less becomes a Short by itself.
  Custom Shorts thumbnails are set in Studio; whether `thumbnails.set` takes one is untested.

A 1080x1920 H.264 MP4 of 3:00 or less, with AAC and the index at the front, is inside the current rules
of Shorts, TikTok and Reels.

**Gates needed.** Nothing tests the stage, the media, the subtitles, the filters, the exporter or the
thumbnail at 9:16 (mask_portrait_check and clown_face_check cover Masking): a headless exporter check
(the override, the window's shape, even sizes, a 9:16 thumbnail, landscape unchanged); a boot probe of the
stage rect, the filters' size and the subtitles' safe area; one small real render under xvfb whose MP4
reads back 1080x1920 (the only check that catches the trap); and a look probe of every scene at 9:16.

Sources: [Shorts length](https://support.google.com/youtube/answer/15424877),
[Shorts resolution](https://support.google.com/youtube/answer/10059070),
[safe zones](https://services.google.com/fh/files/misc/universalsafezones-youtube.pdf),
[TikTok](https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide),
[Instagram](https://developers.facebook.com/docs/instagram-platform/instagram-graph-api/reference/ig-user/media).

## Platforms: desktop and Android

On a phone, Ghost Notes is a notes app and nothing more: a list, an editor, a folder of markdown.
Everything else stays on the desktop, behind one gate.

**Why the rest cannot run on a phone.** Nearly every component reaches outside Godot: FFmpeg, ghost's
Python (the neural voice, the trackers, page capture, yt-dlp), the agents' command-line tools, and the
engine relaunching itself to render. Android 10 and later refuse to execute a file from an app's own
writable storage, and Godot 4.7.2 targets SDK 36, so nothing ghost downloads can run there, and `res://`
lives inside the APK, where no subprocess could read it. (A binary shipped as a native library inside the
APK is the known way round and needs Godot's Gradle build. Not now.)

**`Deps._platform()`** calls anything that is not Windows or macOS "linux", so a phone reported
`linux-arm64` and the Provisioner started fetching uv, FFmpeg and Python. It is taught Android, iOS and
the web, so Provision answers that it has no builds for them and `ensure()` treats that as a permanent
failure.

**One capability table.** `Capabilities` answers two questions for each entry, with a reason: is it
possible on this platform (decided once at boot, from `OS.has_feature` and `Provision.unsupported`), and
is it ready now (asked again whenever the Environment panel rescans).

| capability      | means                                                          | possible on   |
| --------------- | -------------------------------------------------------------- | ------------- |
| `subprocess`    | ghost may start a program                                      | desktop       |
| `ffmpeg`        | FFmpeg and ffprobe                                             | desktop       |
| `python:<env>`  | one per environment: voice, download, capture, face            | desktop       |
| `agent:<role>`  | a writer or a painter                                          | desktop       |
| `movie_export`  | the engine can relaunch itself to record                       | desktop       |
| `checkout`      | running from the repository: the Assistant, docs.py, the gates | editor builds |
| `forward_plus`  | the desktop renderer (volumetric fog needs it)                 | desktop       |
| `mic`           | the voice sampler                                              | desktop, for now |

A component declares the capabilities it needs. "+" leaves out what is impossible here and grays what is
not ready yet, with the reason. The table is also checked where programs start (`Subprocess._program`,
`Deps.execute`, the Provisioner's `_may_run`), so a component that forgets to declare still cannot launch
anything on a phone.

**The phone build.** On Android a note has one component, its text; there is no stage, transport, Chrome
furniture or agent.

- The notes list and the editor, full screen, in portrait (`display/window/handheld/orientation`).
  `CodeEdit` brings up the keyboard by itself. Boot's window fitting and the Provisioner stay off.
- Notes live in `user://notes/`. A file comes in or goes out through the system's picker, which hands
  back a `content://` address that `FileAccess` reads since Godot 4.6.
- No permissions. The preset leaves out the hosts, `masks/`, `feedback/`, `build/`, `tests/`, `next/` and
  `docs/`; prebuilt template, no Gradle.
- `--handheld` (and an environment variable, for gates) runs the phone shell on the desktop; a desktop
  window at phone size is not a phone.
- Godot drops a setting at its default value when it rewrites project.godot, which can bring an APK up
  sideways, so every value the phone build depends on gets a gate.

Sources: [feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html),
[OS](https://docs.godotengine.org/en/stable/classes/class_os.html),
[Android 10](https://developer.android.com/about/versions/10/behavior-changes-10),
[DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html),
[content:// in FileAccess](https://github.com/godotengine/godot/pull/112215),
[exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

## Cards: Tarot, generalized

As a mode, Tarot was too specific. It generalizes into Cards (now Table), which implements generic
primitives and interfaces so an author can drive the cards by their own needs and logic: another tarot
deck, a trading-card board, baseball cards, an invented sport, flashcards. Given proper tooling, an agent
can control actions - card draws, positions on the table. Everything tarot-specific comes from the guide:
the show's markdown brief.

**How close we were.** Of 13,986 lines in fifteen files, about 80% would serve any card show unchanged,
about 12% is tarot that belongs in the guide, and about 8% needs primitives that did not exist. That 8% is
the spine: the reading was a fixed sequence of four verbs - `shuffle`, `draw K`, `jumper K`, `spread` -
running through the mark parser, the voice's rests, the step graph, the table's scheduler and posing, the
moments and every reader prompt. The seed decided the order, the reversals, the jumper and the spread's
shape, and code decided the sequence.

| already generic                                                                                                                                                                                                            | tarot, but data                                                                                                                                                                                                       | missing                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| the shuffle library (riffle, overhand, cut, and the wash's planned simulation), props and their lighting, the air, the title and the outro, the MCP tool server, ReadingFollower, the step graph's engine, the set dresser's tools, how no cheating is enforced | the standard 78 and their elements, reversals (32%) and jumpers (30%, first card only), the spread shapes, the booklet page, the recipe (an intro, a passage per card, a close), the prompts' wording, the card's size (in four places), the frames and Cinzel, the limit of 1-10 cards | a vocabulary of actions with arguments, positions as data, card state over show time beyond one held card, face templates with fields, agents that choose actions and positions |

**The primitives**, in an order that leaves ghost working after each:

1. **Actions are a registry.** Each verb declares its arguments (which card, which position, face up or
   down, a turn), its rest, its pose and the moments it makes - declared, not branched on. The four
   verbs and the ones nobody writes (the deck's push, squaring, the lay) are its first entries, and
   CardReading's rests, MOMENTS and MOVES derive from it. Deal, place, flip, a quarter turn (tap), show,
   gather and discard are more entries. This changes no behavior, and the tarot gates hold it to that.
2. **Positions are data.** Named positions `{x, z, yaw, face, stack}`, written in the guide or by the
   producer's plan. Each is checked to be on the cloth, in frame and clear of the deck, and the seeded
   shapes - row, arc, rows, pyramid - become presets. A hand, a pile and a board's grid are positions
   with a stacking rule.
3. **Card state over show time.** Every card's position, face and turn is a pure function of show time,
   so a scrub and an export agree. The held card and its booklet page become one presenter, and more than
   one card may be up at once.
4. **Decks and faces from the guide.** The card's size, the deck's thickness from its count, the fields a
   face shows, the booklet on or off, and art the author supplies as well as art an agent paints. A face
   template draws a card's fields onto its front and back, as Anki's card templates do.
5. **The recipe from the guide.** Which agents run and in what order, how the script is composed, and the
   tarot nouns in every prompt.
6. **Agents choose.** The producer writes the layout, so the set dresser sees it. A reader may write
   registered marks, and an unknown one is dropped (`clean_spoken` keeps HTML comments, so an unguarded
   mark in a reader's reply would be parsed as an action). A dealer's toolset on the MCP server (deal,
   place, flip, look, submit) previews the table, as the set dresser's `set` does. Two limits stay: every
   choice lands in an episode file before the voice is made, because a rest is spliced into the reading;
   and `_drawn` stays the only way a card reaches a writer.
7. **The rename comes last,** behind a public staging API for TablePreview, which reached into about 25
   private members of TableMedium. It was 736 references in 30 files, plus `user://cards`, `fonts/tarot`,
   `data/tarot` and `Medium.OWNED`.

**Hidden information generalizes.** No cheating - a reader sees only the cards drawn so far - is what a
card game calls hidden information; boardgame.io's `playerView` strips whatever one player may not see
before the state reaches them. Ghost's rule is that rule with the agents as the players: a writer sees
what has been revealed to its role, and the audience may see more, as a poker broadcast shows every
hand. One gap: Codex keeps a shell and could read `draw.json`; it is only told not to.

**What stays tarot is a template.** Its guide holds the 78 and their elements, the reversal and jumper
rules, the spread presets, the booklet, the recipe, shuffle-draw-present-lay as its verbs, its prompts'
wording, and the deck's look and Cinzel. The tarot show keeps playing from its file as before - the test
that the generalization is honest.

**The name.** "Cards" collides with our own word: a component's settings live on a card (ScriptWriter's
card, SynthEditor's catch card and the tarot's TitleCard use the word too). Deck, Zone and Pile were free
in the code; Table, Slot, Hand, Spread and Board were taken. The component was named **Cards**, and later
**Table**. The settings card keeps its name in the code (`Card`), and the folds moved to `[folds]` so
`[cards]` could be the component's.

**Prior art.** Tabletop Simulator's objects carry the verbs this needs: `deal`, `shuffle`, `takeObject`,
`flip`, `spread`, `split`, `cut`. boardgame.io declares a game as moves and phases and hides each
player's secrets with `playerView`. Anki draws a note's fields onto a card's front and back with
templates. [Tabletop Simulator](https://api.tabletopsimulator.com/object/),
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

**The modes survive as a way in.** A new note starts empty and "+" attaches components; the six code
paths behind the old modes and the home screen they were listed on are gone.

## Prior art

Grouped by the decision each one informs.

**The three named.**

- **Scratch** is the closest match to the panel. Its block palette is one long column of colored
  categories, with colored circles beside it that jump to each, and **Add Extension** adds a new category
  at the bottom: attach a component, get a section. Extensions do not get their own colors - all share
  one green and are told apart by an icon on the category and on every block. An extension whose blocks
  are unused is dropped when the project reloads. Sprites couple only through named broadcasts that fire
  "when I receive" hats - moments, in Scratch's words.
  [colors](https://github.com/scratchfoundation/scratch-gui/blob/develop/src/lib/themes/default/index.js),
  [extensions](https://github.com/scratchfoundation/scratch-vm/blob/develop/docs/extensions.md),
  [broadcasts](https://en.scratch-wiki.info/wiki/Broadcast)
- **Blockly** answers how to type the connections: each connection carries a `check` list of type names,
  two connect only when their lists share one, and an empty list accepts anything. That is needs and
  provides. Its colors are a hue at one fixed saturation and value, and blocks are declared in JSON - a
  registry. [checks](https://docs.blockly.com/guides/create-custom-blocks/inputs/connection-checks/),
  [colors](https://docs.blockly.com/guides/configure/toolboxes/appearance/)
- **Logseq** is the closest match to the text. A plugin's slash command writes `{{renderer :name, args}}`
  into a block and the plugin draws its UI there, and its state is written back into the macro's
  arguments: invocation and state live in the text, as ghost's marks do. Its database version lets a
  block carry several tags with one name per property across the graph (Tana's supertags), at the price
  of the plain markdown files. Keep the files.
  [macros](https://github.com/logseq/docs/blob/master/pages/Macros.md),
  [plugin sample](https://github.com/logseq/logseq-plugin-samples/blob/master/logseq-pomodoro-timer/index.ts),
  [database version](https://github.com/logseq/docs/blob/master/db-version.md)

**Compound documents.** OpenDoc's container idea is not what failed: few parts shipped, nobody owned the
experience across parts, and OLE held the market. OLE's flaw is worth avoiding: only one embedded part is
active at a time, so its controls appear only when you click into it - a panel of cards shows every
attached component at once. Ink & Switch's Patchwork essay (2025) restates the problem: does the person
you share a document with have every editor it needs?
[OpenDoc](https://en.wikipedia.org/wiki/OpenDoc),
[OLE](https://learn.microsoft.com/en-us/cpp/mfc/active-document-containment),
[Malleable software](https://www.inkandswitch.com/essay/malleable-software/)

**Text as the source of truth.** Potluck keeps all state in the text and found its limit there: text
"rules out applications with non-textual data or rich visualizations", which is why ghost needs
components. Embark makes views render any subtree of one outline. Org-mode's settings cascade (system,
language, file, heading, block, call; the most local wins) is the shape for component default, note, and
a mark in a passage. [Potluck](https://www.inkandswitch.com/potluck/),
[Embark](https://www.inkandswitch.com/embark/),
[Org](https://orgmode.org/manual/Using-Header-Arguments.html)

**Inspectors.** Unity's component header is fold arrow, icon, enable checkbox, name and menu; the checkbox
appears only where disabling would do something; `RequireComponent` adds dependencies. Blender evaluates
modifiers top to bottom and saves expanded, viewport and render per modifier. Unreal's Details panel marks
every value that differs from its default, with a reset. Xerox Star gave every object the same property
sheet and the same few commands, "Same" among them.
[Unity](https://docs.unity3d.com/Manual/UsingComponents.html),
[Blender](https://docs.blender.org/manual/en/latest/modeling/modifiers/introduction.html),
[Outliner](https://docs.blender.org/manual/en/latest/editors/outliner/interface.html),
[Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/level-editor-details-panel-in-unreal-engine),
[Star](https://digibarn.com/friends/curbow/star/retrospect/)

**Composition.**

- Bitwig's modulators: drag from a modulator onto any parameter, the range relative and drawn on the
  control. Ableton's racks: up to 16 macros, each mapped to any number of parameters with ranges.
  [Bitwig](https://www.bitwig.com/userguide/latest/the_unified_modulation_system/),
  [Ableton](https://www.ableton.com/en/live-manual/12/instrument-drum-and-effect-racks/)
- TouchDesigner's typed families and Max's hot/cold inlets keep streams and events apart.
  [TouchDesigner](https://docs.derivative.ca/Operator_Family),
  [Max](https://docs.cycling74.com/legacy/max8/tutorials/basicchapter06)
- VCV Rack has one kind of connection, a voltage; it writes down the range each use keeps to and turns
  NaN into 0. [VCV](https://vcvrack.com/manual/VoltageStandards)
- Functional reactive programming: behaviors are continuous values over time, events are discrete
  occurrences. [Fran](http://conal.net/papers/icfp97/)
- Observable runs cells in dependency order. Jupyter is the cost of not doing so: of 863,878 attempted
  notebook runs, 24% ran without errors and 4% reproduced their results.
  [Pimentel et al.](https://leomurta.github.io/papers/pimentel2019a.pdf)
- Entity-component systems keep behavior in systems keyed on which components are present. Godot composes
  with child nodes "at a higher level than in a traditional ECS", so ghost needs no framework.
  [ECS FAQ](https://github.com/SanderMertens/ecs-faq),
  [Godot](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)
- Blackboard systems (Hearsay-II): sources post facts, and a controller picks what runs next.
  [Nii 1986](https://ojs.aaai.org/index.php/aimagazine/article/view/537)
- Render volumes (Unity URP, Unreal) blend two writers of one field by priority and weight, with a
  per-field override - the rule if two components ever must set the same field.
  [URP](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@7.5/manual/Volumes.html)

**Writing on it.** Kay and Goldberg (1977): a general medium may "collapse under the weight of trying to
be too many different tools for too many people". Victor's Magic Ink: software should infer the context
its data is needed in, which is what "+" suggestions are. Matuschak and Nielsen: each component still
needs real depth. Nielsen Norman Group: designs past two levels of disclosure "typically have low
usability". [Kay and Goldberg](https://tinlizzie.org/VPRIPapers/m1977001_dynamedia.pdf),
[Magic Ink](http://worrydream.com/MagicInk/), [Tools for thought](https://numinous.productions/ttft/),
[NN/g](https://www.nngroup.com/articles/progressive-disclosure/)

## Risks

- **Leaving a note.** A notes app switches documents, so every component needs a real detach, and a gate
  that attaches and detaches each one many times and finds no leaked nodes, Chrome claims or bus effects.
- **Pairs.** Features that each work can misbehave together (the feature interaction problem). With n
  components there are 2^n combinations, and most will never run. The tested paths are the examples; one
  contract check per feed (everything that provides a reading passes the same test) covers the rest.
- **The hodgepodge.** A dozen deep components beat thirty shallow ones, and a card that needs a third
  level of disclosure is two cards.
- **Cost.** A frame is tens of thousands of GDScript calls on one core of a 2014 CPU. Live scenes on four
  card faces are four scenes. A component should declare a rough cost, and "+" should say when the total is
  past what runs.
- **Workspaces are not cards.** Masking (8,200 lines, its own timeline) is an editor, not settings, and
  Manual's workspace is the start of one. Their cards hold the essentials and a button that hands them the
  stage, as ScriptWriter's pop-up editor does. Masking moves last.
- **Sharing and versions.** Once other people have notes, each block needs a version and a migration
  (translating between versions always gives something up), and a note opened without a component it uses
  must keep that block verbatim, behind a gray card that names what is missing.
- **The blank page.** An empty note invites less than a button for a kind of show did.
- **The body changes its role.** With Table attached the body is a brief, and the voice reads something
  else.

## The plan, in order

Each step stands on its own and leaves ghost working, and the early ones pay for themselves even if the
later ones wait. A step is marked done with what changed in it.

**Working rules** (the project's standing ones, in CLAUDE.md): git writes are the author's; never
overwrite a file you have not read; run the gate that covers what you touched; `/tmp` is a RAM disk and a
process is killed by exact pid; credentials stay with the author; American English, with " - " where an
em dash would go.

### Step 0: move to ghost-notes

The layout is flat, with the GDScript folder renamed.

```
ghost-notes/
├── project.godot     the Godot project, at the root
├── src/              GDScript: formerly scripts/
├── scripts/          build scripts (step 1)
├── scenes/ shaders/ data/ fonts/ tests/ docs/ next/ storyboards/ ...
├── hosts/            the Python hosts: voice/, face/, capture/
└── README.md  CLAUDE.md  LICENSE (MIT)
```

1. **Commit** everything pending in the source repository.
2. **Bring the history** with `git subtree split --prefix=axis/ghost -b ghost-split` in the old
   repository, then a fetch and a merge of that branch under the working tree (a pull refuses once the
   tree holds the refactor), so the commits from "rename vortex to ghost" onward are in `git log`.
3. **Copy what git leaves behind** with rsync: `CLAUDE.md` (stays out of the repository), `feedback/`,
   `masks/` (the ten `session*.json` are hand-placed markers and cannot be remade), `build/` (hand-written
   bench and probe scripts), `*.uid` and `*.import` (tracked from now on, so a clean clone keeps every
   reference), and `.godot/` (a cache).
4. **Rename `scripts/` to `src/`** with `mv`. The `.uid` files move with their scripts, and references by
   path are rewritten by rule (`res://scripts/`, `../scripts/`, `--path axis/ghost` to `--path .`).
   Not every mention of `scripts/` names ghost's folder: uv's wheel layout (`<name>.data/scripts/`, in
   provision_check) and a historical `git show` in next/voice_rca.md stay. The first `--editor --quit`
   after the move logs autoload failures while the UID cache rebuilds; the second must be clean (that is
   `scripts/check.sh`'s `parse`).
5. **Fix what pointed at the old repository:** the Assistant's checkout is `res://` and its prompt names
   `feedback/NNNN.{json,png}`; its source scan is recursive; the README, docs.py strings, the voice hosts'
   and tests' run lines, Deps' hint, `mask_marker_tool.gd` and three rift probes (`../rift/`).
   `.gitignore` gains `__pycache__/` and `dist/` and stops ignoring `*.uid` and `*.import`.
6. **Outside the repository:** Claude's memory directory for the new path, Syncthing's folder (added as
   its own folder by the author), permissions, and pointers in the sibling repositories.
7. **The author's data does not change:** `config/name="ghost"` and `custom_user_dir_name` in project.godot
   name the user folder outright, so settings, voices, episodes and tools are found as before.
8. **Last, the author** removes `axis/ghost` from the old repository and commits both.

**Done when:** `--editor --quit` logs no invalid UID, failed load or parse error; the headless gates and
`tests/run_quiet.sh --all` pass; `python docs.py` reports no drift; the app opens with the author's
settings, voices and episodes; a feedback report dispatches with its working directory in ghost-notes; and
the history is in `git log`.

**Status: done, except the two git steps that are the author's (0.2 and 0.8).**

- 0.2: the split carries 172 commits and its tip's tree is byte-identical to the old `axis/ghost`. The
  merge is done with `git read-tree` and `git commit-tree` under the working tree, so no file is touched.
- 0.4: `scripts/` is `src/`, by `mv`, with 746 lines in 162 files rewritten by rule. Four orphan `.uid`
  files were dropped.
- 0.5: done as listed. `settings_check` asserts it read the source, since a stale path made it scan
  nothing and still pass.
- 0.6: memory copied with its paths rewritten; `.stignore` with ghost's lines is in the repository.
- `CLAUDE.md` stays out of the repository, and `.gitignore` says so.
- The three Python host folders live under `hosts/` (their requirements files moved byte for byte, since
  the environment digest is their text, not their path).

### Step 1: build scripts

`scripts/build.sh`:

```
scripts/build.sh [linux|windows|android|all] [--release] [--install] [--no-check]
```

1. Check that Godot is the project's version (4.7.2) and that the target's export templates are installed:
   a named target fails without them, and `all` skips it.
2. Import first when `.godot/` is missing, as on a clean clone.
3. Run the headless gates through `scripts/check.sh`, unless `--no-check`.
4. `godot --headless --path . --export-{debug|release} "<preset>" dist/ghost-notes-<target>.<ext>`.
   (`dist/`, not `build/`: ghost's `build/` holds hand-written bench scripts.)
5. Check the file exists and is at least 1 MB: Godot's exporter exits 0 even when it fails.
6. `--install` puts an APK on the phone with `adb install -r`; adb lives in
   `~/Android/Sdk/platform-tools`, not on PATH.

A tracked `export_presets.cfg` that names no secret: Linux x86_64 with the pack embedded, Windows x86_64,
and Android arm64-v8a (prebuilt template, no Gradle, no permissions, portrait, the debug keystore from
the editor settings). macOS waits: it needs signing.

**Release signing is the author's.** A release APK needs `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`
and `_PASSWORD`. The script refuses `--release` without them and never prints them.

**This machine.** Godot 4.7.2 with only its Android templates installed; the desktop targets need the
4.7.2 template set first. The Android SDK is `~/Android/Sdk`; `ANDROID_HOME` points at `/opt/android-sdk`,
which holds only cmdline-tools, so read the editor's setting first. JDK 17 and the debug keystore are in
place.

**What an exported desktop build cannot do yet** (binary_export_and_steam.md, "Binary export: why a build
would not run today", lists these). None of this blocks the refactor, which runs from the checkout; all of
it comes before a build goes to anyone else.

- The Python hosts and their requirements files are found through `globalize_path("res://...")`, which in
  an export is a relative path into a `.pck` that Python cannot read. Ship them in the pack and have the
  Provisioner copy them to `user://`, named by digest like its environments, before starting one.
- The render and the bake relaunch the engine with `--path` and `--script`, which export templates refuse.
  The render relaunches the binary itself, and the bake becomes a ghost flag.
- Ghost writes into `res://`, which is read-only once exported: feedback, Masking's sessions and downloads
  (`MASKS_DIR`), and the render's `override.cfg`.
- Non-resource files need the preset's include filter: `data/english.yml`, `data/cmudict.dict`,
  `storyboards/*.yaml`, the license texts.
- The table's card fonts are opened as raw `.ttf` files (`load_dynamic_font`), which an export does not
  contain; `load()` fixes it, as the notebook does.
- The Assistant and Masking's reload check need the checkout: the `checkout` capability.

**Done when** `scripts/build.sh linux` and `scripts/build.sh android` each produce a build that starts, the
APK opens on the phone without trying to download anything (`Deps._platform()` knows Android), and
`scripts/check.sh` runs the headless gates.

**Status: done; the APK on a phone is the author's to see.**

- `scripts/build.sh` is as planned: targets are the presets, the exit code is not trusted, a 1 MB floor,
  `--release` refused without the three `GODOT_ANDROID_KEYSTORE_RELEASE_*` variables, adb from the SDK's
  platform-tools. Built: Linux 78 MB, Windows 107 MB, Android 32 MB (arm64-v8a, debug-signed). The Linux
  build starts headless and on the GPU against an isolated data folder. Android needs
  `import_etc2_astc=true` in project.godot. The APK packs `src/`, shaders, fonts and all of `data/`, and
  none of `masks/`, `tests/`, `docs/`, `next/` or the Python hosts.
- The 4.7.2 Linux and Windows templates come from the official `.tpz`, its SHA-512 checked against the
  release's sums.
- `scripts/check.sh` runs every gate found on disk (`--gpu` for those that need a renderer), starting with
  `parse` and ending with `docs` (`python docs.py --check`, which writes nothing). A gate that printed its
  passing verdict and then died in the engine's teardown is `ok*`, not a failure.
- `Deps.platform()` knows Android, iOS and the web; Provision refuses everything there and the Provisioner
  does not start (provision_check, two-sided, through `Deps.platform_override`).
- The harness is safe to run beside anything: `run_boot_probe.sh` boots a private scene per run; every
  test is read-only, `--script` gates included (`Settings.is_probe_launch`); `tests/compile_check.gd` loads
  every script, since `--editor --quit` only parses; `tests/fixture_audio.gd` makes the silent WAV two
  gates need.

### Step 2: cards

Wrap each mode's existing sections in colored `FoldableContainer`s with no change in behavior. **Done when**
every section folds and keeps its fold, and panel_fit_check and medium_pick_check pass.

**Status: done.** `Card` (a FoldableContainer bordered in its family's color) and `CardRow` (the chips under
the heading), made through `SidePanel.add_card`. Folds were `[cards] <panel>.<card>` (now `[folds]`).

- FoldableContainer signals a fold made by fold(), expand() or a click but not one assigned, which is how a
  stored fold comes back, so the chips followed their cards by polling.
- A probe must open the cards before measuring a panel, because it reads the author's real folds.
- Masking is not cards: its options are one flat sortable list, and it moved last.
- Gates: card_fold_check, panel_fit_check (opens the cards; its control counts the rows inside them),
  medium_pick_check.

### Step 3: the transport

The bar along the stage's bottom ([The transport](#the-transport)): Chrome's Scrubber grows play/pause,
stop and the time; a conductor registers with a register/unregister pair; Space is play/pause everywhere
and skipping a scene gets its own key; pause stops all of show time. **Done when** a gate drives play,
pause, seek and stop through the bar for a song and for a reading, finds the clock still during a pause
(inside a bookend too), and finds no hook left after a stop or after leaving; and speak_stop_check passes.

**Status: done.** `src/show/transport.gd` is Chrome furniture and shows exactly when `Spectrum.timed()`.

- Spectrum has a conductor: `conduct(owner, hooks)` / `release_conductor(owner)`, held through a WeakRef so a
  freed owner drops out by itself, and transport verbs that call its hooks or drive a plain file (Stop =
  back to the start, paused).
- The reading panels conduct from `_ready` to `_exit_tree` (`transport_hooks()`); Synthesis conducts while a
  take plays, with no seek, and the seed click stays an audition.
- `Spectrum.paused` holds the intro and tail counters too. Space is the transport's except while typing; N
  skips a scene.
- Setting `stream_paused` turns the player's `playing` false at once in 4.7, so "playing" is never
  `_player.playing` alone.
- Gates: transport_check, speak_stop_check, multi_voice_check.

### Step 4: the bottom-right row

One row container in Chrome; the Environment button at its left end, with `[deps] open`; the Assistant
dropdown moves into the Assistant's panel; one panel above the row at a time. **Done when** a gate checks the
row's geometry (no hole for a hidden button, nothing over another), opens each panel in turn and finds one
open at a time, and reads `[deps] open` back after a restart.

**Status: done.** `Chrome.row` is one HBoxContainer on its own layer, and each piece of furniture hands it its
button with `row_button(who, b)`; the row keeps `Chrome.ROW_ORDER` and closes up around a hidden one.

- The Environment panel is Chrome's, behind the button at the left end: open until the author closes it
  (`[deps] open`, written only by the button), opened without writing when the probe finds a problem; its
  state line and color are the button's tooltip and dot.
- One panel above the row at a time: each registers its closer (`register_panel`) and reports opening
  (`panel_opened`); the export's status line steps aside while one is open.
- Masking reuses Chrome's Assistant, and its export takes the row's export slot as `&"mask_export"`.
- `find_children` cannot filter on a script's class name (match the native class, then test `is`), and a
  FileDialog carries an OptionButton of its own.
- Gates: row_check, assistant_pick_check, deps_panel_probe.

### Step 5: shared cards

One card per duplicated section (script, cast, voice, picture, Look, bookends), used by every mode that has
it. Tarot stops inheriting Generative. One frontmatter shape per component, with a one-time rewrite of the
documents rather than a reader that accepts both shapes. **Done when** doc_sync_check, multi_voice_check,
cards_check and medium_pick_check pass on the shared cards, and every chapter and show comes through the
rewrite unchanged outside its block.

**Status: done.** One block per component under `ghost:` - `voice`, `picture`, `illustrations`, `look`,
`bookends`, `tarot`, `synthesis` - as siblings.

- A panel declares the blocks it has cards for (`_doc_blocks`), and DocSource reads and writes those,
  merging per block and carrying every other block through.
- `ReadingPanel` is the reading (the script, cast and voice cards, the stream, the transport's hooks, the
  export); `GenerativeEditor` and the table's editor both extend it.
- The shared cards are `LookCard`, `BookendsCard` and `PictureCard` (`KEY`, `capture()`, `apply()`);
  `IllustrationPanel` keeps its own block inside the Picture card.
- Rows are declared rather than removed: Hesitate shows where the panel's marks have a hesitation, and Ink
  only where the medium writes by hand.
- `main.gd` once typed the panel as `GenerativeEditor`, which would have refused the table panel.
- Gates: doc_sync_check, medium_pick_check, multi_voice_check, cards_check, panel_fit_check, card_fold_check,
  youtube_check.

### Step 6: teardown

Every mode can be left and entered again. **Done when** a gate attaches and detaches each one many times and
finds no leaked nodes, Chrome claims, bus effects or transport hooks.

**Status: done.** Chrome's row has a home button at its left end, hidden on the notes list. `main._end_session()`
is the one teardown: it frees every mode's nodes (their `_exit_tree` lets go of the conductor, Chrome's claims,
the table's pinned medium and the voice host), ends the streams, detaches the Director (which drops a
storyboard), stops Spectrum and clears what the exporter asked of the mode; an export already rendering carries
on. Leaving is refused, with the reason on the grayed button, while an export is making the mode's take
(`Exporter.preparing()`) or while Masking's own export renders (`MaskEditor.leave_blocker()`). Every mode
already let go of what it held in `_exit_tree`; nothing needed fixing once a way out existed. Gates:
teardown_check (all modes through the real main scene, three visits each, counts steady from the second visit,
the refusal two-sided, and a control that a forgotten node is counted), row_check, assistant_pick_check.

### Step 7: the registry

Components declare key, family, needs and provides, capabilities, marks and card, and `Capabilities` answers
for the platform ([Platforms](#platforms-desktop-and-android)). main.gd's three session paths become one, so
a command-line Masking session gets Chrome. **Done when** each template makes the show its mode made
(scene_mix_check's seed replay, unchanged), and "+" grays a component whose capability is missing, with the
reason.

**Status: done.** `src/platform/capabilities.gd` is the table from Platforms, each entry answering
`impossible()` and `not_ready()` with a reason, plus `stage` (the show itself: a clock, a transport, a stage
that plays), which a song, a voice and the voice lab need. `src/notes/components.gd` holds the registry
(label, blurb, family, needs, provides, requires, capabilities, mark groups, block, card).
`main.start_template(key, source)` was the one session path, and `--mask-edit` runs after Chrome exists. "+" is
`Components.attach_menu`: impossible components left out, not-ready ones grayed with the reason. `Subprocess`
and `Deps.execute` refuse when `subprocess` is impossible. Both new files name no autoload, so SceneTree gates
and Subprocess can ask them.

- The two log pumps could splice one stream's chunk into the middle of the other's line (subprocess_pact_check's
  rare "2999 of 3000"), so each pump writes whole lines (`\r` counting as a line end, for yt-dlp's progress).
- Gates: components_check (the table two-sided, on this desktop and asked as Android), scene_mix_check,
  teardown_check, subprocess_pact_check.

### Step 8: the note and the notes list

Open any markdown file with no mode; "+" attaches; the note owns the clock, feeds, moments, places and seed.
The home screen goes: the app opens on the notes list, the per-mode drafts in ghost.cfg become notes,
`--note <path>` opens one, and "‹ Notes" leaves one. **Done when** a gate starts the app on the list, makes a
note, plays it, leaves it and opens another with nothing leaked; the drafts arrive as notes; and splash.gd and
its two gates are gone, their checks moved to the list's.

**Status: done as the "done when" reads; the deeper half of the step is not built.** The app opens on the notes
list (`src/app/notes_list.gd`): New, and the notes newest first, from `NoteStore` (`src/notes/note_store.gd`:
the default folder `user://notes` plus the files and folders the author adds). `main.open_note` starts a note
through the one session path. A new note carries only its marker block, because an empty block is not "the
defaults" to every card (an empty `illustrations:` wipes the pictures' look). A note with nothing attached is
`src/app/note_panel.gd`, its "+" offering what decides what it becomes. "‹ Notes" tops every panel, a song that
ends stays in its note, and the assistant picker's gating checks live in assistant_pick_check.

- Not built: the note owning the clock, feeds, moments, places and seed (each workspace still runs its own
  session underneath); a one-window editor; a note's own card (seed, frame); on/ghosted; "+" suggestions; diff
  notes.
- DocSource assumed every source had settings to capture (a plain note has none); the list's export claim is
  keyed apart from a note's.
- Gates: notes_list_check, assistant_pick_check, teardown_check, components_check, row_check.

### Step 9: Tarot becomes Cards

Tarot becomes the generic Cards component (now Table), in the order of [its primitives](#cards-tarot-generalized):
the action registry (no change in behavior), positions as data, card state over show time, decks and faces from
the guide, the recipe from the guide, agents that choose, and the rename last. The show's guide carries
everything tarot-specific. **Done when** cards_check, table_wash_check and table_place_check pass unchanged
through the action registry; the tarot show plays from its file as before; a second guide - flashcards, say -
makes a show with no code of its own; a dealer agent places cards through its tools and a gate finds every
position on the cloth, in frame and clear; and no cheating still holds two-sided.

**Status: built in part.**

- **(1) The actions are a registry.** `TableActions` holds the written verbs and the three performed between
  them (push, square, lay), each with its args, rest, whether it shows a card, lays the shown one first or ends
  the showing, and its moments. CardReading's mark pattern, rests and compose and the table's schedule read it.
- **(2) Positions are data.** `TablePositions`: `{x, z, yaw, face}` on the cloth, from the plan's spread
  positions or a dealer's `layout.json` laid over them, used only whole and sound, else the seeded presets
  (kept verbatim in table_positions_check as its oracle). Every position is checked on the cloth, in the
  camera's frame and clear of the deck, against the episode's own camera. An arc or a row of seven or eight
  cards put a card partly outside the frame in 2.6% of spreads, so those are laid as two rows.
- **(6, part) A dealer's toolset.** `DealerTools` (place, flip, look, submit), told what the table objects to as
  it places, refused until whole and sound, told no card's name. A reader's reply keeps only the voice's marks
  (`voice_marks_only`).
- **(5, part) One set of rules for every show.** The rules name no kind of card (no `tarot` flag, no built-in
  78, no suit's element in code); a tarot show is a brief that says it is one and lists its deck, and every
  producer names the deck's `kind`. A `## Cards` section of prose alone lets each episode's producer choose its
  box, drawn from by the seed (`CardDeck.chooses`). Gate: cards_choose_check (next/cards.md, "One set of rules
  for every show").
- **(3, 6, part) The staging.** Card state over show time is each card's own timeline (arrive, show, lay, turn),
  and the producer chooses how the cards come and are shown: a deck or a box, the text in a booklet or on the
  card's back, printings with their own backs, and per position dealt, swept, sideways, stacked and tapped
  later. Verbs `open`, `deal`, `fan`, `show`, `tap`, `untap`, `flip`. Reversals (`none`, `read` or `righted`)
  and jumpers are the producer's choice in the plan's staging; the seed says which cards come up upside down
  and whether the first one jumps. Gate: table_staging_check (next/cards.md, "The staging").
- Still the tarot's: the card's size and face, and the hash salts (kept by design).
- **Not built:** the card's size and face template, `flip` for the producer, more than one card held up at
  once, the recipe's wording moved into a show's guide for every kind of show, a dealer run by a real agent
  (the tools exist, no episode step calls them).
- Gates: table_actions_check, table_positions_check, cards_check, table_wash_check, table_place_check.

### Step 10: portrait

Independent of steps 2-9. In order: the `frame` setting and `--frame`; `Medium.FRAMES` and the pickers; the
preview fit; the exporter (the window's shape, `aspect="keep"`, the portrait presets, the thumbnail,
`+faststart`, the 3-minute notice); subtitles in the frame's safe area; the four full-frame scenes; the
table's hard-coded 16:9 values; the tablet's distances. A single-page comic, book and notebook, and a portrait
table, come after, as design work of their own. **Done when** the four gates in
[Two frames](#two-frames-landscape-and-portrait) pass - the small real render that reads back 1080x1920 among
them - and a landscape export is unchanged.

**Status: done for full frame; the rest of the frames are not built.**

- `Director.frame` and `--frame` sit beside the medium, kept in the note's `picture:` block through the Picture
  card's Frame picker; `Medium.FRAMES` (portrait only for full frame, as measured) and `resolved_frame()` fall
  back to landscape.
- The preview is the frame: the stage the frame's shape, centered, black beside it; the filters follow it.
- Subtitles lay out in the frame, a portrait one inside the platforms' safe area (`Subtitles.text_area`).
- The exporter: a portrait render window shaped like the frame with `aspect="keep"` (a landscape override byte
  for byte as before), the turned presets and no 4K portrait, `--frame` to the render, a frame-shaped
  thumbnail, `+faststart`, and the over-3:00 note.
- At 9:16, cloth leaves most of the frame an empty dark green under a line near the top and two_eyes sits its
  eyes against the frame's edges; tidepool and falling_sand fill it.
- **The trap, measured.** A 1080x1920 render in the old 480x270 window lays the show out in a 3413x1920 view,
  and Movie Maker records its middle 1080: the file is the size asked either way, and the picture's edges are
  what is lost, not its shape. A file's size cannot see it, so the render logs the view it laid the show out in
  (`ghost export: view WxH`) and the gate compares that with the picture recorded.
- Not built: those scenes' tuning, the tablet's distances (it stays landscape), the table's 16:9 values, and
  portrait comic, book, notebook and table layouts.
- An OptionButton is as wide as its longest item, so the Frame picker's items are short.
- Gates: frame_check (the headless exporter checks, the stage and the safe area through the real main scene,
  measured against the window as it is - headless Godot's is 64x64) and portrait_render_check (GPU: one small
  real render, 1080x1920 recorded and laid out in exactly that view, and the old override as its control). The
  scene look probe at 9:16 is scene_look_probe with `--size 540x960`.

### Step 11: the phone

The phone shell ([Platforms](#platforms-desktop-and-android)): the list and the editor, `user://notes/`, the
system picker, portrait, the trimmed preset, `--handheld`. **Done when** the APK on the phone opens the list,
makes, edits and keeps a note across restarts and tries no download, and a desktop gate runs the shell under
`--handheld`.

**Status: done on the desktop; the phone itself is the author's to try.** `src/app/phone_shell.gd`: on a phone,
or `--handheld` / `GHOST_HANDHELD=1`, main builds the shell and nothing else - the notes in `user://notes/`, a
full-screen editor written on a quiet period (the body through `FrontMatter.write_body`, the title as its
line), Import… and Export… through the system's picker (`DisplayServer.file_dialog_show`, `content://` on
Android), Android's back, a save on pause. No stage, transport, furniture, agent or download
(`Provisioner._may_run` refuses). The settings a phone depends on are gated, because Godot drops a value equal
to its default when it rewrites project.godot: portrait orientation, and a portrait canvas for mobile. Gate:
handheld_check. `scripts/build.sh --install android` builds and installs the APK.

### After the first review

A round of revisions to the first build. **Status: done.**

- **The notes list makes notes and nothing else.** The large name and tagline over the main area are gone
  (the panel keeps them), and so are Open… and the path/URL field. A song or a video is a component of a note:
  the Song card's Choose…, and Masking's Clip card, which takes a file or a link. New ends on "Existing
  note…", which brings a markdown file from anywhere into the list.
- **Every note can be deleted.** The list's × and every panel's "⋯" (`Chrome.note_menu`) ask first
  (`src/app/delete_dialog.gd`); the note goes to the system's trash (`NoteStore.trash`, with a `discard` seam
  so a gate never fills the author's trash), or, for a file added by hand, leaves the list. A note that is
  open is left first - its panel writes what it holds - then trashed. The phone shell's editor has Delete…
  too.
- **Every note starts from nothing.** The medium a note was shown in is freed with it (`main._clear_stage`),
  the stage is hidden until a show attaches, the Director's picture settings go back to their defaults as a
  note opens (`Director.reset_show`) for the note's blocks to set, and a song note opens loaded and stopped at
  its start. A reading's Stop hides the stage too.
- **A song is a note's component, and Auto is a medium.** Song notes are `NotePanel` - the panel never hides -
  with the note's components as cards: the Script, the Song (`src/show/song_card.gd`), the Picture, the Look,
  the Intro & outro, the Storyboards. Without a Picture the song plays to an empty frame; "+" offers a Picture
  for it (and grays the Look and storyboards, "Needs a Picture"). The Picture's media are what a song can carry
  (`Medium.offered`: not the novel, notebook or tablet, which print a reading) with Auto first
  (`src/media/auto.gd`, `Medium.BARE`): the original show with nothing to set - the card shows only the picker,
  and its block is the medium's name alone. A medium picked while a song is loaded is shown at once
  (`main._restage`). The Storyboards card is the old Workspace's list (`src/storyboards_card.gd`).
- **Tarot is Cards** - step 9's (7). The component `cards`, the panel `CardsEditor`, the classes
  `TableEpisode`, `TableProducer`, `TablePrompts`, `CardReading`, `CardDeck`, `CardTable`, `CardFaces`, the
  medium `table` (`TableMedium`), the block `ghost: cards:` with its range `draw:`, the marks `<!-- table: draw
  2 -->`, `--table`, `user://table/` (moved from `user://tarot/` once at first launch; `main._adopt_old_episodes`,
  to delete once it has run), `fonts/cards/`, `data/decks/tarot/`, and the gates `cards_check`,
  `table_wash_check`, `table_place_check`. The card folds moved to `[folds]`, since `[cards]` is the panel's
  section. What stays tarot is the content: the tarot show, the standard 78, and the prompts. The seeds' hash
  salts keep their `tarot-` names, so episodes already made come out the same. (CLAUDE.md's Names section has
  the later rename to Table.)
- **Masking is in the framework.** Its panel is a `SidePanel` like every note's - "‹ Notes", the note's title,
  its "⋯", a chip per card - with three cards: the Clip (its name, Track, Help, the time), the Effect (the key
  color, the effect and the options: one flat, sortable list) and the Markers, pinned under the rest
  (`SidePanel.add_footer_card`). With no clip, the panel asks for one (a file through the in-window dialog -
  the native one shows nothing without a portal - or a link), and what is chosen is written into the note's
  `clip:` block. Masking keeps its own playback (its timeline, Space); one transport for it is still to do.
- **"Edit Script…" is "Edit"**, everywhere.
- Finished one-time migrations were removed: `NoteStore.move_drafts` and `tests/rewrite_blocks.gd`.

### Save… moves the note

**Status: done; `doc_sync_check`, `notes_list_check`.**

- **The cause.** "Sync to…", in the editor window, moved the script's source (`DocSource`) to the file chosen
  and nothing else: the note was still the file it was opened from (`main._note`), and `open_note` points the
  panel back at that file every time, so edits made after a Sync went into the chosen file and the next open
  read the old one.
- **Save…, on the Script card.** It always asks for a file. In a note the whole note goes there
  (`DocSource.moved` -> the panel -> `main.note_moved`): that file is what "⋯" deletes, what the list shows and
  what opens next time. One note, one file - the note Ghost Notes kept in its own folder goes to the trash once
  the new file is written, a file added by hand leaves the list, and the author's own files are left as they
  were. Nothing is torn down: a reading or a generation under way carries on.
- **The mark.** `SaveMark`, beside the file's name on the card and in the editor window: it turns while a
  change waits for its quiet period, ticks when the write is verified, goes amber when a write is refused, and
  its tooltip is the file's whole path and the time of the last write. It reads `DocSource.save_state()` and
  `written`.
- **Open…, in a note too.** Open… on a note's Script card asks for a file and opens it as the note
  (`ScriptWriter.open_as_note` -> `Chrome.open_file` -> `main.open_file`): through the one session path, so it
  is what its own blocks say it is, and nothing is written into it. The note left behind is written first and
  stays in the list - Open… never deletes.
- **Not built.** A rename from the list; pouring one file's words into another note (copy and paste does it).

### Composition, not templates

New has no options. Every note opens the same way, and the author attaches the components with "+".
**Status: done as far as the list below; the design, and what it does not do yet, are in
[storyboard.md](storyboard.md).**

- **The cause.** Modes were templates over the registry, and a note's blocks picked one
  (`Components.template_for`), so a note was still exactly one mode, chosen by an `if` chain.
- **One kind of note.** New is a button. A note has what is attached to it and nothing else;
  `Components.workspace_of` derives which panel runs it from what its components declare, and `TEMPLATES`,
  `template_for` and `marker_blocks` are gone.
- **Slots** (`clock`, `presentation`) say what a note has one of - the "family says how many" of
  [A component](#a-component), declared per component rather than per family, because a clip takes both and a
  Voice takes one.
- **"+" is derived and detach exists.** One menu on every panel, each refusal with its reason; an × on every
  component's card. The block leaves the file (`NoteCards.detach`) and the note opens again.
- **One composition.** `NoteCards.build` makes a note's component cards on every panel, and
  `main._attach_show` puts a song's show and a reading's up through one path.
- **The storyboard is the note's,** kept in its `scenes:` block and written in an editor (`StoryboardEditor`);
  a note may still name a file.
- **The Voice is a card:** `VoiceCard` (`reading/`), made by `NoteCards` from the `voice` row like every other
  component's card, standing after what produces the text and before the Picture; its insides are the reading's
  `ReadingCast`, handed in `ctx` (`cast`), keeping the `voice` block (structure.md, step 23). The voice is the
  reading's always: a table show requires one before its note carries the block (`ReadingPanel._voiced`).
- **Not built:** two clocks on one note, a show with no sound, on/ghosted, "+" suggestions, diff notes.

Gates: components_check and notes_list_check, teardown_check, storyboard_check and storyboard_editor_check.

### The Medium card

One card for what a note is shown in. **Status: built; the gates below pass. The author still has to see it in
the app.**

- **One card, `medium`** ([MediumCard], block `medium:`, the `medium` family's green; the Pictures card keeps its
  orange). Its picker is **Format** - Auto, Full frame, Comic book, Novel, Notebook, Tablet, Letter, Dispatch
  desk, every `Medium.REGISTRY` row no component owns - and under it the shared rows by each format's `uses`:
  Frame, Scene hold and Flourishes (`scenes`: Full frame and the comic only - the Novel, Notebook and Tablet
  have no scenes to change to), Camera, Handwriting (the Notebook's and the Letter's: one hand row,
  `handwriting`; the voice's Ink is `ink`, the Notebook's alone), Films. Then the format's own rows, a row's
  `card` by path ([LetterFormat], [DispatchFormat]). The block holds only what the format uses, flat.
- **What stays a component makes something** - Table the words, the Actor a person and their voice - and brings
  its own medium, pinned. A way of showing the words is a format. The Letter and the Dispatch desk were
  components with a card that pinned their medium; now their format is the Director's medium, set from the
  block.
- **A format with rows of its own hands the reading its walk and publish,** so picking one or leaving one
  writes the note and opens it again (`ctx.reshape`); every other pick is live. A format the note cannot have
  (a Letter whose Voice was detached) is kept as it was, and says so.
- **The notes moved once** (`main._adopt_old_media`, `Components.adopted_medium`; remove once run): `picture:`
  (its `medium:` the format), `letter:` and `dispatch:` became `medium:` where they stood.
- **Not built:** one desk number shared by the Letter, the Dispatch desk and the desks under the Novel,
  Notebook and Tablet; the Actor as a format; a tile's chip naming the format ("Medium" for now - `ui/` cannot
  read the media).

Gates: components_check, letter_format_check, medium_pick_check, pictures_card_check, doc_sync_check,
notes_list_check, note_grid_check, panel_fit_check, card_fold_check, teardown_check.

## Questions, answered

Each answer is carried into the sections above.

- **Editor or stage?** One window: the main area holds the note's text while you write and its stage while it
  plays, and a note with nothing visual attached never shows a stage. ScriptWriter's pop-up editor becomes that
  main area.
- **Where do notes live?** In a default folder, and Ghost Notes can be pointed at any other folders and files,
  so the author can source content from other projects and git repositories. The list shows them all. On the
  phone, `user://notes/`. A database may come later, for speed, links between notes and a graph of them, so the
  storage sits behind one small interface (list, read, write, watch). When it does, the files stay the source
  of truth and the database is an index rebuilt from them (as Obsidian does; Logseq's database version gave up
  the files, which loses the selling point of one plain markdown file).
- **Diff notes** (child notes: the difference between one note and its copy). A diff note names its base and
  stores only what it changes: settings key by key, and its own body if it has one. Everything else it reads
  from the base, so a change to the base reaches every diff note that did not override it. Godot's inherited
  scenes and Unity's Prefab Variants work the same way. A table episode becomes a diff note of its show: the
  episode's script as its body, its seed and drawn cards as overrides, the voices and the look from the show.
  Open: whether a body may be a line-level patch of its base's body, which brings merge conflicts. Start with
  "inherit or replace"; DocSource's three-way merge (`merge3`) is there when patches are wanted.
- **Storyboards.** A note keeps its own storyboard in its `scenes:` block and may still name a file - see
  [storyboard.md](storyboard.md).
- **Where generated things live.** `user://notes/<id>/<component>/`, generalizing the table's `show` key. The id
  lives in the note's frontmatter, so a note's generated files follow it when the file moves. A note names a
  reference by its content hash (the library names its copies that way), never by an absolute path, which no
  other machine has.
- **The families, and their colors.** Each family has a default hue, and a note can recolor any of its cards
  (`color:` in that component's block). One saturation and lightness, checked in both themes, never color alone.
- **Ghosted.** Kept. A ghosted component still runs - it keeps time, makes moments, drives the scenes - but is
  not heard or seen. Ghost the song, and the show still moves to it while the export carries no music, so a
  Short made on a commercial song meets no Content ID claim and the song is added afterward from the platform's
  own library. A ghosted voice likewise times a picture-only cut for narration recorded later.
- **Whose defaults?** A note opened with no block for a component starts from that component's defaults, never
  from the note open before it, and ghost.cfg holds only the viewer's preferences.
- **Tarot, as a mode, is too specific.** It generalizes into Cards. See
  [Cards: Tarot, generalized](#cards-tarot-generalized).

**Still open:** line-level diffs in diff notes, the database's role and timing, and the key that skips a scene
now that Space is play/pause.

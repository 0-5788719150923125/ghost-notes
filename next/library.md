# The library and the Dex: props and voices kept for every note

Agents make props for every table and throw them away; a voice made for one note is copied by hand into the next. A
person keeps the good ones in one library (`user://library/`), every note that can use them does, and the Dex is where a
person finds them, and everything else the app has.

## Status

Built: step 1, kept voices (step 2), the Dex with its Props and Voices shelves (step 3, not Keys), the desk's ticks (step 4,
half), the set dresser's `library` tool (step 5), Export and Import of props and voices (step 6), roles (step 7: every thing the
Dispatch desk works, working faces included - next/working_props.md; its Props card and the Dex's shelves of what scenes build),
and refining a prop (step 8), a Letter desk's things too.
The user judges: a first real Refine (gates use a stand-in agent; a probe may not start one).
The user judges: the names (Props, Dex, Used), the 3D view, the Dex, kept voices by ear, and where the setting goes (Proposed,
"The setting").

- **The library's root** is `Library` (`platform/`): `user://library/`, a folder per shelf, moved aside by a gate, removed
  entries to the trash. `ThingLibrary` is in `table/`, beside `Props`.
- **A kept prop is the thing alone** (`ThingLibrary.OWN`: name, parts, scale) with the materials its parts use, a line, and a
  hash of what it is (`hash_of`: the same prop on any table hashes the same). Put on a table, a material the table holds
  otherwise is renamed, so it looks the same everywhere. A file from anywhere comes in bounded (`sanitized`).
- **Its picture** is taken by `PropStudio` (`table/`): built on a worker, one at a time, kept on the `pictures` shelf by its
  hash, with its size, lit by `StudioLook` (`render/`). On the Dex (`PropPictures`) those in view and near it come first - a
  kept one read on a worker - and every other on the shelf shown is taken behind them until the Dex closes.
- **The Props card** (`PropsCard`, `PropSection` in `ui/`) stands on the panel while a section has rows; a table episode hands
  `EpisodeProps`. Each row is an entry (`EntryCard`, the look every card's list shares): its picture, name and line, and a ×
  top-right taking it off (pressed twice; grayed saying why where it cannot: `remove_tip`, `remove_off`, `PropSection.remove`). A
  click opens it to its tick, verbs and properties. The ×: a table episode's thing off its table for good (a hand's version); a
  Letter desk's thing off the desk (its card lists only what is on it, "+ Add a prop" the rest); a Dispatch desk's spare thing
  (`DispatchSet.SPARE`, the choice `{aside: true}`, "+ Add a prop" setting it out again; the switch stays while the script throws
  it), every other part of that desk grayed (the desk works it). Each row has a Used tick (unticked moves a thing to the table's `aside` list, which nothing stands and no
  agent reads, and the table becomes a hand's version), Keep, and Select (picks it on the stage); groups Used and Set aside. A
  note pins no props: a prop goes on a table when the set dresser finds it in the library, or by hand from the Dex.
- **A prop in 3D** (`PropViewer`, `ui/`): a click on any prop's picture, on the card or the Dex, builds it whole on a worker
  (`PropStudio.model`, a section's `model_of`) and opens it beside the panel, lit as its picture is. A drag turns it about any
  axis, Shift rolls it, the wheel brings it closer, a right drag moves it, a double click or Set straight puts it back.
- **The Dex** (`DexWindow`, `ui/`): what the library keeps, a tab a shelf, a tile an entry, a filter by words. Each kind of thing
  hands a `ShelfSection` (`ui/`): `LibraryProps` (`table_show/`: Kept props, renamed in place, Remove; Seen props, every thing any
  episode stands, read on a worker, once each by its hash, Keep) and `LibraryVoices` (`voice/`: Kept voices, Hear, Say it,
  Remove). Opened on its own from the bottom-right row's books (`Chrome.open_dex`) it adds nothing; opened from the Props card's
  "+ Add a prop" it shows that section's shelves and each tile's Use puts the prop on the episode's table. Export… and Import…
  hand an entry on as `.prop.json` or `.voice.json`.
- **The set dresser's `library` tool** answers words with the closest kept props (`ThingLibrary.search`: name, line, shapes,
  materials; never the whole list), and `put` takes `{kept: name}`. A kept prop is never in its "earlier tables held these"
  list. A fixed thing a brief writes with no `at` is placed by the set dresser (`FixedTable.placed_by_dresser`).
- **Kept voices** (step 2; `VoiceLibrary` in `voice/`, `VoiceKeep` on the Voice card): who speaks and how (`OWN`: the model and
  reader, a blend or formant voice, tone, pace, pause, the delivery dials, the ink), never the room (`ROOM`, each note's own). The
  Voice card's Keep… names it (Replace where the name is taken); its picker lists kept voices under Kept. A note reads one by name
  (`kept:` on its row) and keeps a copy, read when the library is moved aside or the voice removed; a dial of who speaks moved on
  such a tab writes the kept voice once the hand rests, and every note reading it follows, its kept takes going stale
  (`take_sig` counts what is said, never the name). "Make it this note's own" turns the row back into a copy; a rename keeps the
  old names answering. Its sample, the Test passage's opening said dry, is made when it is kept, on a worker, never over a reading.
- **The desk** (step 4, half): its ticks are rows of the Props card (`DeskProps`, handed by the Letter's and the Desk's formats),
  each pictured as the desk's number draws it (`DeskLook.spec_of`); `DeskRows` keeps the number, the light and the cards' words.
  Pictures on both come through one queue (`PropPictures`).
- **Roles** (step 7; `PropMakes`, `MakeShelf` in `desk/`; next/working_props.md): a part a scene's prop plays, and the make
  chosen for it ("Roles", below). Every thing the Dispatch desk works is a role (the terminal, the keyboard, the phones, the
  radar, the receiver, the printer, the three screens and the television's stand, the lamp, the switch, the handbook, the stamp,
  the tracker, the chart, the mug, the cup of pencils; the clock and tablet where the script uses them), its own make shipped in
  `data/props/` (the mug's and the cup's drawn from the desk's number). Its Props card (`DispatchProps`, handed by
  `DispatchFormat`) shows each with Choose… (the Dex on its makes: its own, the recipe drawn from 24 numbers where it has one,
  every kept and seen prop that has the faces the desk fills, filtered by the part's word; Use chooses, a seen one kept first),
  the desk's own, and Keep; the choice is kept in the Medium block's `things` and the desk is built again with it, the reading
  kept where it is.
- **Refining a prop** (step 8; "Refining a prop", below): Refine… in the 3D view (`PropViewer`, `PropRefine`) asks the writer a person
  picks (`AgentPick`: agent, model, effort) to change the version shown as they say, with three pictures of it as built
  (`PropStudio.views`) and `rules/table/prop_refiner.yaml` (the prop language shared with the set dresser, `thing_language`);
  the bar moves and the agent's activity line ticks until it lands. Its answer is a new version of the same kept prop
  (`ThingLibrary.add_version`, `LibraryVersions.land`), stepped through with ‹ ›, the one shown when the view is
  left (closed, or opened on another prop) made the prop (`PropViewer.keep_shown`, `use_version`). A refinement that made it
  something else names its version (the answer's `name` and `line`), and a person types over the name at the view's top to name
  the version shown; the prop takes a version's name when that version is used, and keeps its former names (`aka`), so a desk or a
  role that chose it by one still finds it (`ThingLibrary.read`, `known_as`); a prop not kept yet is held as a DRAFT (`draft` in its
  file: its versions' home, on no shelf, in no agent's search) - refining keeps nothing, nor does choosing a seen prop for a desk's
  part. WORDS ON A THING: the set dresser and the refiner are told a `face` as a label of words (`Props.FACE_WORDS`: a book's title on its
  cover or spine, a bottle's label), never as a scene's picture. A turned vessel's POURING LIP is its warp's `spout` (the rim and the
  wall under it pulled out at one side, one piece), never a part laid on the rim. A thing's heaps settle together, one pile, at most
  `HEAP_MOST`; a part makes at most `MAX_COPIES`, both told to agents. REFINING RUNS IN THE BACKGROUND, any number of props at once, one at a time each (`LibraryVersions.start_refine`,
  `PropRefining`): Refine closes its words' window, the view says what the agent is doing over the foot of the 3D view (never
  taking room from it) with Stop, and may close or turn to another prop; a Props card row says it too, then that a new version is
  ready until the view has shown it. Each refine is told its own ask alone, never the asks before it. KEEP IS THE 3D VIEW'S, never a card row's or a Dex tile's (`PropSection.keep_prop`, a section saying what the prop is by
  `keep_line`): it keeps the prop with every version it has, and the row then says "in your library". What uses it follows (`PropSection.refined`): a table's thing
  takes the version used as a hand's version, a Dispatch part is played by the kept prop (where the version used keeps the faces
  the desk fills), a Letter desk's thing by the version used (`DeskRows.set_make`, the block's `makes`). An agent refining a prop
  a scene works is told its faces, lights and fed parts, and to keep them (`Props.describe_working`). The Dex shows one prop,
  found by any version's hash, so the one it was kept from says Kept.
- **The Dex opened on its own** shows, beside the library, what scenes build: Desk things (`DeskRecipes`: a desk's 13 recipes
  as the first desk draws them, Keep) and Dispatch desk (`DispatchProps` with no note: every thing it works, Keep).
- Gates: `tests/table/thing_library_check.gd`, `tests/table_show/episode_props_check.gd` (the card, the 3D view, the Dex),
  `tests/dispatch/dispatch_props_check.gd` (roles, the Dispatch card, the Dex's scene shelves), `tests/table_show/prop_refine_check.gd`
  (versions, an answer landing, the view, what follows),
  `tests/voice/voice_library_check.gd` and `tests/reading/kept_voice_check.gd` (kept voices), `letter_format_check` (the desk's
  rows), `tests/table/shot_reach_check.gd` (what a table played hides out of the shot); a look: `props_card_probe.gd`. A voice's
  sample is so far made only against a stand-in host in a gate: the first Keep on the real voice host is its test.

Not built: the `Keys` registry and its shelf (step 3), kept props on a desk other than a desk thing's own versions
(`DeskLook._pack` from a built size), and Choose… on the Letter desk's things (`DeskProps`).

## What is there

- **Every prop is the same kind of data already.** A desk's mug and a set dresser's cauldron are both a `Props` spec:
  parts, each a shape with real sizes and a material, built by `Props.build`. The desk's 14 (`DeskLook.THINGS`) are
  recipes, code that writes a spec varied by the desk's number. A set dresser's are specs as written, about 500 bytes
  of JSON each, in an episode's `table.json`.
- **The library of things** is step 1, above (Status).
- **Agents' props are kept only by a person.** The author's 42 episodes hold 296 things a set dresser made, each built,
  photographed and fixed within a budget of 60 pictures; the Seen shelf shows them all, and Keep takes one. Candles were made from scratch 31 times, mugs and
  cups 20.
- **The desk's props are fixed recipes** (`DeskLook.THINGS`), ticked on the Props card: 14 kinds, no kept prop among them yet.
- **A voice lives in one note.** It is a row of the note's `voice:` block (`ReadingCast.capture_slot`): the model, the
  reader, a Kokoro `blend:` line or a formant voice's `formant:` (lineage, traits, genome), the tone, pace, pause and
  delivery dials, the room's eight dials and the ink. Another note gets it by copying the block: 16 of the author's
  notes carry one, and each chapter of a book carries the same narrator, so a change to the narrator is a change to
  every chapter by hand.
- **Some of a voice is shared already, the voice itself is not.** Trained voices (`kokoro/trained/`, an actor's Piper
  voice in `user://actors/`) are listed for every note, and the fishing game's Collection is the player's, never one
  note's. But the voice a note reads in is copied out of them into its row, and a blend saved under a name of its own
  is listed as not built (voice_engines.md).
- **Keys are spread over a dozen handlers and listed nowhere** but Masking's F1 overlay, written by hand beside its
  handler. Space, ← → (Shift: a minute), Home, N (next scene), F2 (the panel), F11, ` (feedback) and Esc, which quits
  ghost from anywhere and ends what it runs, an export included.

## What the app needs

1. A prop or a voice worth having twice is kept by a person's choice, never automatically.
2. A kept prop goes wherever things stand: a table show's table and the desk (Letter, the Desk format, an episode at
   the desk); later the Dispatch desk and the set dresser's desk (letter.md, phase two).
3. **A kept voice is one voice for every note that reads in it**: a book's narrator changed once, every chapter heard
   in the change.
4. **The set dresser reaches the library.** A kept prop is proven and costs no pictures: better, cheaper shows are where
   a library pays back, more than the clicks.
5. **What is kept is a file anyone can hand on.** A prop is 500 bytes, made safe by `Props.sanitize` (parts, points,
   copies and size bounded; no code, no images); a synthetic voice is a blend line or a genome and its dials. It is the
   community's unit of sharing, and later a Workshop item.
6. One place a person finds what the app has, which never goes stale: built from the rows the code already reads
   (`label`, `blurb`), never written twice. Not docs/: fields, paths and bounds are for agents and developers.

## Proposed

### The library (`user://library/`)

- One root, a folder per shelf: `things/`, `voices/`. A gate moves it aside, as `ThingLibrary.root` is today.
- Remove sends a kept entry to the trash, as a note goes. Export writes `<name>.prop.json` or `<name>.voice.json`;
  Import takes one, dropped on the Dex or the card that uses it, read through the same sanitizing a made one is.

### Props (`table/`, `ui/`)

- `ThingLibrary` moves down beside `Props`, so the desk, the table and the Dispatch desk all read it.
- One list on three shelves: **Built in** (the desk's recipes, each pictured from a fixed number, `DeskLook.made`),
  **Kept** and **Seen** (every thing in every episode, read where it stands, never copied).
- A kept prop is the thing alone: parts, materials, a name and a line saying what it is. Never the episode's `at`,
  `group` or `why`. Its materials go with it under names of its own, so it looks the same on any table (today a table's
  material of the same name wins).
- Its picture is made when it is kept (`TablePreview.thing`, on a worker), cached by the spec's hash; a Seen thing's
  while its shelf is open, the nearest the view first.
- **The Props card** is one card for every presentation that sets things down, as the Pictures card is for pictures.
  Whatever shows things hands it a `PropSection`; the card draws, the section does, and with no section there is no card. No card names another.
- Its rows are what stands: a small picture, a name and ×. "+ Add a prop" opens the Dex's Props shelf to pick from,
  offering only what fits (a 40 cm cauldron is not offered for a desk).
- **The desk**: `DeskRows`' ticks move here. Until a prop is added or taken off, the desk's number draws them, as now;
  the first change keeps them (`DeskRows._hold`). A kept prop is placed as a recipe's is: `DeskLook._pack` already
  works from a built size and `TALL_H`.
- **A table episode**: its rows are the set dresser's things, each with a Used tick, Keep and Select. A note pins no props of
  its own: the set dresser finds kept ones with `library`, and a person adds one from the Dex. The dock keeps its inspector;
  its Keep and "+ From the library" move to the card.
- **The set dresser** gets one tool, `library`: what it needs, in words, answered with the closest kept props (name,
  line, size; a picture when asked); `put` takes a kept one by name. The risk: handed a list, agents put the same
  favorites on every table, as a prompt's example gets copied. So it searches and is never handed the list, and its
  rule says a kept prop goes on a table only when it is what that table needs.

### The setting (for the user to choose)

What a scene stands on and how it is lit: the desk (by its number) and its Light on the Medium card's desk rows today, and a
table's top, cloths and lights, which its set dresser writes. Two homes fit:

- **The Props card**, a Setting group above Used: the surface as a row (pictured, its number or top picked there) and the light
  as a row. It is this note's choice, beside what stands on it, and the Medium card keeps only the format and how it is shown.
- **The Dex**, shelves of desks and lights kept under a name, as props are, each Used on a note.

Recommended: both, split by kind - the choice for this note on the Props card, the ones worth keeping on the Dex - built once the
user has seen the Props card and the Dex as they stand.

### Roles: a part any make can play

A scene works its props by what they are for, never by their shape: the Dispatch desk lifts its mug to the mouth and sets it
down in its ring, a table's television shows a picture, a terminal types. A role is that part, and a make is whatever plays
it - the scene's recipe drawn from a number, another draw, a prop kept in the library. The role owns the behavior; the make
owns the geometry; the role fits the make so the behavior holds (`PropMakes.made`: its foot on y = 0, centered, its front
toward +z, its height inside the role's range).

- A role is a row (`PropMakes.ROLES`: its recipe, its words on the Dex, its height). A scene asks for a role's make and
  stores the choice in its note (`{}`, `{recipe, seed}`, `{kept}`); the Dex offers makes the same way for every role
  (`MakeShelf`), so a new role costs a row and the line that builds it.
- A role whose behavior needs a part of the make (a television's screen, a computer's screen, a phone's lid and hinge)
  names it: the make carries it as a named part, found by name, and a make without one is not offered for that role. Built
  for the Dispatch desk (next/working_props.md): its faces, lights and the parts that follow what the scene feeds them are the
  make's data, so computers, televisions and phones are swappable with the same behaviors wherever they are used.
- Kept props from tables have no named working parts yet: they can play roles that need none (a mug, a cup, a lamp's
  body), and the set dresser could name them when it builds one.

### Refining a prop

A prop is mostly right and a few things are wrong: a part's shape, a size, a color. Refine says which in words, and an agent
changes those and nothing else; the answer is a version of the same prop, never another prop, and none is ever deleted.

- A kept prop's file holds every version (`versions`, oldest first, each with the direction that made it, who, when) and which
  is used (`at`); its `thing`, `materials` and `hash` are the used one's, so every reader of the library is unchanged.
- The agent is shown the version as written and three pictures of it on the ruled ground, and answers the whole prop as JSON;
  what it leaves out of the scale is kept. A reply that is no prop, or builds nothing, adds nothing.
- The version made is shown but not used: a person compares it with ‹ and › (it stays turned as it was) and chooses.
- Open: the writer picked is kept for the run, not saved; a refine runs on while its view is closed and lands its version.

### Voices (`voice/`, `reading/`)

- A kept voice is who speaks and how: a name, a line, the model and reader, the blend or the formant voice, the tone,
  pace, pause and delivery dials, and the ink. And a sample: the Test passage said once when it is kept, so the Dex plays
  it at once.
- **The room stays the note's.** Echo, room, resonance, presence, ambience, lean, near and seat are where a voice is
  heard, not who speaks: one narrator in a car and at a desk.
- **The Voice card**: Keep on the voice on screen, and its voice picker lists kept voices by name beside the models.
- **A note reads a kept voice by name** (`kept:` on its row) and carries a copy of what it last read, so it reads the
  same on a machine without that library, and when the voice is removed. A change to the kept voice is heard in every
  note that reads it; their kept takes no longer match and are said again (`ReadingPanel.take_sig`). "Make it this
  note's own" turns the row back into a copy.
- The fishing game's Collection is a shelf as it stands: a held voice is caught already, and keeping one names it.
- A voice resting on a trained model names it and needs it installed. An export never carries the model: it is heavy,
  and a real person's voice is theirs to give.
- `VoiceLibrary` (the store) goes in `voice/`, below `reading/`, whose card and cast read it.

### The Dex (`app/`, a button on the bottom-right row)

- A window of shelves, each a registry row naming its script by path. An entry is a picture or a sound, a name, its
  blurb and its verbs.
- First shelves: **Props** and **Voices** (Keep, Remove, Export, Import, Hear for a voice, and Use when opened from a
  card), and **Keys**.
- Keys need one source first: a `Keys` registry (key, where, label, blurb) that every handler reads, `docs.py` failing a
  `KEY_` handled outside it and writing docs/keys.md. Masking's overlay reads it too.
- Later shelves, a row each: Actors, what a note can be made of (`Components`), formats (`Medium`), script marks
  (`ScriptMarks`, already on the Body card's palette).

## Order

1. The library's root; `ThingLibrary` down to `table/`, kept props cleaned and pictured; the Props card on a table
   episode with Keep. The 296 already made become keepable here.
2. Kept voices on the Voice card, read by name. It needs no Dex, and every book's chapters gain from it at once.
3. The Dex with Props, Voices and Keys, and the `Keys` registry.
4. The desk on the Props card; kept props on the desk.
5. The set dresser's `library` tool.
6. Export and Import.
7. Roles: the Dispatch desk's mug and cup first, then a working face (screens, keys, lids) as named parts, then the desks'
   things and a table's lights as roles.
8. Refining a prop: versions in the kept prop's file, an agent's revision from the 3D view.

Gates, each two-sided: a kept prop built on another table and on a desk matches its picture (a control with a changed
material must not); a note reading a kept voice says what the voice written out whole says (a control with one dial
moved must not), reads its copy with the library moved aside, and its takes go stale when the kept voice changes; an
imported file with 60,000 parts, a NaN or a path in it builds bounded; a `KEY_` outside `Keys` fails `docs.py --check`.

## Open

- Names: "Props" wherever a person reads; the data keeps `things` (every episode file says it) and the builder stays
  `Props`. "Dex" for the window.
- By name or by copy: by name is one narrator for a book, but a change reaches notes already finished. A note could
  hold its voice back ("Make it this note's own") before an export it means to keep.
- Esc quits from anywhere without asking; a key that ends an export may want a second press.
- A kept prop could take the table's palette instead (a choice on its row) if one looks wrong on another table.
- Materials, lights and whole tables could be kept the same way, once props show the shape works.
- Picturing 296 Seen things: measure before caching more.

# The library and the Dex: props and voices kept for every note

Agents make props for every table and throw them away; a voice made for one note is copied by hand into the next. A
person keeps the good ones in one library (`user://library/`), every note that can use them does, and the Dex is where a
person finds them, and everything else the app has.

## Status

Proposed, not built beyond "What is there". The user judges: the names (Props, Dex), whether the set dresser may reach
the library, whether a note reads a kept voice by name or takes a copy, whether a voice's room goes with it, and the
order.

## What is there

- **Every prop is the same kind of data already.** A desk's mug and a set dresser's cauldron are both a `Props` spec:
  parts, each a shape with real sizes and a material, built by `Props.build`. The desk's 14 (`DeskLook.THINGS`) are
  recipes, code that writes a spec varied by the desk's number. A set dresser's are specs as written, about 500 bytes
  of JSON each, in an episode's `table.json`.
- **A library of things exists and is empty.** `ThingLibrary` (`src/table_show/`) keeps one thing per file in
  `user://library/things/`, with the materials it uses. Its "Keep in the library" and "+ From the library" sit in the
  Timeline dock's inspector, reached by opening ☰ and clicking a thing on the stage. It is for tables only, has no
  pictures, no list to browse and no delete, and the set dresser cannot see it. It keeps a thing whole, its episode's
  `why` and `group` included.
- **Agents' props are thrown away.** The author's 42 episodes hold 296 things a set dresser made, each built,
  photographed and fixed within a budget of 60 pictures. None is kept. Candles were made from scratch 31 times, mugs and
  cups 20.
- **The desk's props are a wall of ticks** on the Medium card (`DeskRows`, a CheckBox per `DeskLook.THINGS` row): fine
  at 14, not at 140.
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
  when its tile comes into view.
- **The Props card** is one card for every presentation that sets things down, as the Pictures card is for pictures.
  Whatever shows things hands it a `PropSection`, as a show hands the Pacing card a `TuneSection`; the card draws, the
  section does, and with no section there is no card. No card names another.
- Its rows are what stands: a small picture, a name and ×. "+ Add a prop" opens the Dex's Props shelf to pick from,
  offering only what fits (a 40 cm cauldron is not offered for a desk).
- **The desk**: `DeskRows`' ticks move here. Until a prop is added or taken off, the desk's number draws them, as now;
  the first change keeps them (`DeskRows._hold`). A kept prop is placed as a recipe's is: `DeskLook._pack` already
  works from a built size and `TALL_H`.
- **A table episode**: "Made for this episode" lists the set dresser's things, each with Keep. "Always on this table"
  is the note's own picks, which the set dresser starts with and cannot move: `FixedTable` does this today from a JSON
  block in the brief, and the card writes the same without JSON. The dock keeps its inspector; its Keep and "+ From the
  library" move to the card.
- **The set dresser** gets one tool, `library`: what it needs, in words, answered with the closest kept props (name,
  line, size; a picture when asked); `put` takes a kept one by name. The risk: handed a list, agents put the same
  favorites on every table, as a prompt's example gets copied. So it searches and is never handed the list, and its
  rule says a kept prop goes on a table only when it is what that table needs.

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

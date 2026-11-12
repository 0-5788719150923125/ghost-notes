# The dispatch desk: a lair, a terminal, a dozen phones

A Medium format for `rift/animations/targeted-individuality/targeted-individuality.md` (its handoff is `MEDIUM.md`
beside it): a desk with a terminal-style computer, cell phones and gadgets, with a camera that shifts between them
gently (left and right, in and out, a little tilt). Beyond the desk is a lair: large roots crawling down from the
ceiling as if underground, some past and below the desk, some reaching onto it and growing across it toward the camera,
simple and chaotic, a bit like neurons. The terminal is a deep beige CRT on a flat desktop case with a floppy slot and a
narrow keyboard.

## What it is

A format of the Medium card, `dispatch`, and its medium, `dispatch`: one desk late at night in a hollow under the ground,
seen from the chair. The man who works it is never seen: the viewer sits where he sits, and everything on the desk moves
on its own. The note's words are the script, word for word; the desk is described in the note's own top-level `desk:`
block (the author's, never ghost's `ghost:` block).

## Decisions

- **Every prop is built by code, not by agents.** Each has a job in the script - a phone opens and is held to the ear,
  the terminal types, the printer prints, the radar pings, the receiver's needle swings with the static, the switch is
  thrown - and a prop an agent designs cannot be worked by a mark, costs agent runs per note and lands unpredictable
  geometry. Static parts are [Props] specs written in code (as [DeskLook] writes the letter's desk things); moving parts
  are nodes of their own. The `desk:` block's words are kept for a later set dresser (phase two, as the letter's); today
  only `phones` (the labels, in order) is read.
- **The camera sits in the chair and turns to what is active** (a phone ringing, the terminal typing, the radar on a
  ping, a picture landing on a screen, the receiver while it plays static), leaning a little toward it on critically
  damped springs: nothing jumps or whips. With nothing new for a while it eases back to the whole desk, with a breath of
  slow wander under it.
- **A phone in hand is held to the ear**: it floats up beside the camera on the right, open and tilted, in the corner of
  the frame. A phone on hold lies open on the desk in front of the rows.
- **Voices through a phone are heard through one**, with a voice mark any script can use, `<!-- heard: phone -->` (also
  `desk`, `far`), on a speaker's turn: the earpiece's band (300-3400 Hz) and a little grit, quieter and further off for a
  phone lying on the desk, fainter still for a voice in the caller's room heard through their phone. The dispatch script
  writes it from which phone is in hand or held when each turn is said, so the author never writes it. A line's static:
  each row adds `hiss` and `crackle` before the band, riding the voice (open while it is heard and 0.35 s past it, so it
  hisses between words and never through the rests); a fourth row, `radio`, is a two-way radio: narrower, driven harder,
  crackling, its squelch bursting as the voice keys up and hissing off after it. A phone's line hiss is faint (about 30 dB
  under the voice).
- **Every sound is synthesized**, as the table's are ([WorkSounds], [Soundscape]): the flip and snap of a phone, dial
  tones and the ring in the earpiece, a phone buzzing against its neighbors, keys, the printer's screech, the sonar ping,
  the receiver's hiss and Jupiter's storms (Io-B's popcorn S-bursts, Io-A's surf-like L-bursts), the jet's Doppler fall
  (a moving source, pitch and level from where it is), the toggle's click, the mug set down. The medium plays them as it
  is drawn, so a render records them.
- **Marks the desk could not do on its own are made concrete**: `act:` (plain words, for a puppeteer that does not exist
  here) becomes `<!-- lift: mug -->` and `<!-- switch: BAD -->`; the last TV picture becomes `<!-- live: tv -->` - the TV
  shows this desk, live, seen from just behind the empty chair, with whatever lies on it. `<!-- static: 5, surf -->` names
  Io-A's sea; bare is Io-B's crackle. A text message gets a short rest so it can be read before the reply.
- **The roots are grown, seeded, and some grow**: a dozen-odd systems from the ceiling behind and beside the desk, random
  walks biased down that branch as they go; most hang into the dark past the desk to the floor, a few come over the desk's
  far edge and crawl across its top toward the chair between the things on it. The ones on the desk creep on through the
  night (a front moving along them with show time). Bark is from the props' wood shader, dark and fibrous; depth fog takes
  the far ones.

## The marks

As `MEDIUM.md` has them, with the changes above: `call:`, `/call`, `/call: X`, `ring:`, `text: X | words`, `ping:`,
`sound:`, `static:`, `print`, `sleep`, `off:`, `look:`, `lift:`, `switch:`, `live:`, `image (feed|satellite|tv|full)`,
`/image`, fenced ` ```type `, ` ```screen ` and ` ```terminal ` blocks, `strike` after a typed block, `<!-- redact: words -->`
inside a shown block or a session, `gain: N`, `bell` and `lamp: off|on` (below), and the voice's own (`speaker`,
`hesitation`, `delivery`). `act:` stays a note.

## Files (`src/dispatch/`, a folder after `letter`)

| File | What it is |
|---|---|
| `dispatch_script.gd` | `DispatchScript`: the note into the voice's text (rests, `heard` marks, typed words said), the spoken words, and the desk's actions anchored to them |
| `dispatch.gd` | `DispatchMedium`: the world, the schedule (a [ReadingFollower]), the state of every thing at a moment, the camera, the opening, the pictures, the captions |
| `dispatch_set.gd` | `DispatchSet`: the desk and everything on it, built - terminal, keyboard, phones, radar, receiver and scope, printer and its heap, the three screens, the switch, the chart, the handbook, the things, the chair, the room |
| `dispatch_roots.gd` | `DispatchRoots`: the roots grown and meshed |
| `dispatch_screens.gd` | the 2D faces drawn into the screens: the terminal (its redacted words as written, and where they lie), the radar and its clutter, the scope, a phone's two screens and keypad, the receiver's dial, the gain knob's scale |
| `dispatch_censor.gd` | `DispatchCensor`: redacted words hidden over the finished frame - a tracked box cracked into flat shards (`shaders/dispatch_redact.gdshader`) |
| `dispatch_sounds.gd` | `DispatchSounds`: every sound of the desk, a function of show time |
| `dispatch_format.gd`, `dispatch_walk.gd` | its own rows on the Medium card (the desk's number) and what they hand the reading; the pictures are the note's Pictures card's (next/pictures.md), `DispatchMedium.pictures_in` saying which marks they are |

And in the voice: `Manuscript.HEARD`, a passage's `heard` through [ReadingPlan], a mark in [ReadingJoin], applied by the
stream and the export, the band in [VoiceFX].

## Gates

`tests/dispatch/dispatch_script_check.gd` (the parser on a fixture with every mark: the phones' state, the voice's text,
the actions), `tests/dispatch/dispatch_check.gd` (the medium built headless and played through on rehearsed words: what is
in hand, on the terminal and on the radar at moments, the camera's target), `tests/dispatch/dispatch_sounds_check.gd` (the
jet's pitch falls, nothing is louder than the voice, the two storms differ, the same twice), `tests/voice/heard_check.gd`
(the band, the plan, the join's marks), `tests/dispatch/dispatch_redact_check.gd` (GPU: the terminal on a bulged quad
through a camera, the censor over it - no letter of the hidden words outside a box, every shard one color and the average
of the frame under it, the tracker never short of the words); probe `tests/dispatch/dispatch_look_probe.gd` (frames to
look at).

## Status

**Built.** The author has not yet watched or heard it.

Looked at (rendered with `tests/dispatch/dispatch_look_probe.gd` on a steady rehearsed voice, frames read by eye): the
home view from the chair, every camera spot settled, the record and the target's log on the terminal (legible close up),
the council's typed question, a text on its phone, a phone dialing and one on hold, a ring, the radar's ping with the place
beside the blip, the receiver in a storm, the printer, the TV showing this desk live from behind the chair, the roots from
the chair looking up and from outside the hollow.

Measured: the episode's 3,329 spoken words line up with the voice's plan word for word; every voice is routed through the
right phone; 90 actions, about three minutes of rests; the desk's build is about half a second (most of it the roots), so
it is made on a worker while the show waits, as the table's is; a frame's pose about 1.2 ms; a live plan made again about
20 ms a sentence.

Open:

- The author's eye: the camera's pace (springs of 0.95 s), the props' look, the roots, the lair's light, the censor's box
  size, waver and shard darkness, and the gain, bell and lamp marks.
- The intro's pace with the real voice, by ear and eye: the walks' length is the prose's.
- A real voice and an export; the seven pictures painted from the Pictures card.
- The paper heap on the floor reads only dimly; the printed lines on the paper are small.
- Agents dressing the desk from the note's `desk:` block (phase two).
- A live plan made again in about 20 ms a sentence could be made cheaper (the letter's indexing).
- Ten camera looks are still seen for under 2.5 s, each cut by the next thing the script does a few seconds later (a ping,
  then a picture landing; a print, then a call). They are the script's beats, which spacing them would give room.

How it is built:

- **The desk is crowded, and the roots go round it by a grid search** (`AStarGrid2D`, 2 cm cells, what stands there and a
  margin solid; a flood over it picks the spot each root can reach nearest the chair's middle, apart from the others).
  Free steering got stuck within centimeters. A root may lie across something flat (the chart); its growth runs along its
  crawl from the desk's edge.
- **The right side is laid out by what the chair must see past what**: the radar in front, the receiver at the desk's end
  so its view clears the radar, the TV up on a crate so it is seen over it.
- **Light**: the feed monitor's snow lights the desk's dark end (the printer, the phones); the lamp lights the keyboard and
  the blotter; a shaft of cold light falls through a crack among the roots behind the desk.
- **The terminal wraps at words inside what its curved glass and bezel leave seen** (70 columns, 22 rows).

### The author's first look (2026-11-06, later)

The opening, the radar, the terminal and the desk's props were reworked; what stands now:

- **The desk is seen first**: the voice opens on a breath of the desk at rest (`DispatchScript.OPENING`, 3 s), the camera
  home, the title cleared before it (`_opening`).
- **The target has a track**: a ping is where he arrives, a place laid out from the script alone (`DispatchMedium.track_of`:
  a step on from the last as long as the walk the script gives it, turning gently, a compass word setting the way; a place
  named again is the same spot, a name with a comma a little off its head; the whole track centered on the scope, made
  smaller only if it would run off). The sweep paints him where he is as it passes (every 2.5 s), the earlier paints
  fading behind - a step a round, never a jump - with a soft tick each pass on his way.
- **The walk is under the voice**: `<!-- moving -->` sets him off toward the next ping's place - the radar sounds its alarm
  (a low beep, two higher) and the camera turns to it - and what is written between it and the ping is said while he goes;
  the ping's sound turns the camera again as he arrives. Nothing makes the voice wait more than a beat for the radar, and
  the camera goes to the radar only at its sounds (dispatch_check holds it). A ping that still gives seconds is warned of.
- **The intro** (rift's script; NOTES.md there): Control opens the shift talking, the camera home; he pulls up the subject's
  record in short typed bursts between lines; the radar pings as it finds him in his room; the mug; then the alarm - he is
  moving - and Control talks over the walk to the stairwell and on to the parking lot.
- **The terminal is dark asleep** (no star), and **a session is typed** (` ```terminal `): `>` lines typed at the prompt a
  key at a time with a typist's give-or-take, entered, answered a line at a time, read before the next, the prompt back at
  the end; asleep, it wakes to a bare prompt first (`DispatchScript.session_plan`, `DispatchMedium.session_text`). A shown
  screen is drawn down the glass a line at a time. The episode logs into a menu, searches by keyword, gets three matches and
  opens the first, then the record; it mirrors his screen before the first HIS SCREEN.
- **The desk is its number's** (`DispatchSet._lay_out`, `_pack`): mirrored or not (the radio's things right or left, the
  phones and printer opposite), each end a little off as one, each thing turned; the small things packed into free room
  (the mug at arm's reach, 25-40 cm in, beside the keyboard; the switch by the keyboard; the handbook, its spine to the
  chair; the chart, the pencil cup, the stamp, the tracker). Everything the medium and the roots read follows it (`at_of`,
  `desk_at`, `held_rect`, the camera's spots). The glossy desk top (polish 0.22, an old desk) and the lamp's soft shadow
  (blur 6, never empty of its own light: `shadow_opacity` 0.62, the room's bounce) avoid a crisp pale-blue disc under the
  mug that the screens' cool glows (which cast no shadows) otherwise light. The coffee ring is a thin opaque, matte rim with
  an older arc beside it, a little off the mug's foot (a translucent disc read as glass, and a `Decal` drew its footprint
  pale).
- **The mug is drunk from**: upright all the way, lifted out of its ring and brought under the eye (`MUG_MOUTH`, in the
  camera's own frame, so it is out of the picture whichever way the camera looks), held for the sip, set back down; the
  camera stays on the whole desk, so the mug is seen to rise and leave past the lower edge.
- **The keyboard is a real one**: a standard compact layout, five rows of fifteen units (`DispatchSet.KEY_ROWS`), each key
  a sculpted cap (a skirt tapering to a dished top, the rows leaning toward the typist: `KEY_PROFILE`), letters beige, the
  rest gray, one mesh, on a case sized to it.
- **A text is read on its phone**: a chime and a buzz, the phone up out of its row and open, held before the eye (`READ`,
  in the camera's frame), the message on its screen as a thread - never captioned - and home after, unless it texts again
  within `TEXT_AGAIN`. A reply is typed back: `<!-- reply -->` types the room's next words into that phone as they are
  said, a key at a time, and sends them; the voice still says them.
- **A real keypad and speed dial**: each phone's keypad is drawn (`DispatchScreens._draw_keypad`: Send, End, a navigation
  key, 1-9, *, 0, # with their letters); a call comes up before the eye, 1 is held (its tone), Send pressed, then to the
  ear for the rings.
- **The mug and pencil cup are the letter desk's** (`DeskLook.made(kind, seed)` builds one of that desk's things), so the
  dispatch desk sets out the same mug and hollow pencil cup and nothing clips.
- **Roots all round** (`DispatchRoots`): eight systems beside the desk on each side, out past its ends, down to the floor
  and a long way along it, and one at each end clinging under the desk's edge, down its front corner and out across the
  floor.

### The drives, and typing said behind the keys (2026-11-06, later still)

- **A drive is one walk with stops along it**: a `<!-- moving -->` straight after a ping is the target passing a place - a
  point on his track he goes on through - and makes no alarm, takes no rest and turns no look (`DispatchScript`'s
  `passing`); the radar paints him on through it. A moving mark's look holds until the next ping, at most
  `MOVING_HOLD_MOST` (12 s), so a long drive does not leave the camera on the radar. The script's two drives are each
  "ping driving south/north" passed through, 2-3 minutes of the voice each, the rest is the prose's.
- **A typed block is said behind its keys** (`DispatchScript.AHEAD_WORDS`, the letter's two words): its first two words
  typed at a typist's pace in the rest before the voice, each word after typed while the voice says the one two before it,
  through to the next word's start, no quicker than `KEY_QUICK` a key and always done before the voice says it
  (`DispatchMedium._char_times`), so the voice reads what is on the screen and goes on unbroken. A mark inside a typed block
  does not reach the voice. A reply on a phone is still typed as it is said.
- **A block set all in capitals is said in sentence case** (`DispatchScript.said_of`): `TextNorm.INITIALISMS` reads `IT` as
  the letters, which is right for a field and wrong for a terminal's words. Only a block with no small letter is lowered, so
  an initialism in a log line keeps its capitals; a named letter, `[D]`, stays the letter. The screen still shows the
  capitals.
- **No root where a phone lies open**: an open lid reaches 14 cm past its base, so `DispatchSet.held_rect` is the whole of
  the first three phones laid open, lids and all, and the roots take it as one more thing standing on the desk
  (`DispatchRoots.build`). Across 20 desks, none has a root crossing it (dispatch_check `_roots_clear`, eight desks, with
  the old strip as its control).

### What the camera turns to is seen, and the mug is drunk from (2026-11-06, later still)

A probe sprang the camera through the whole episode on the rehearsal's voice, and again with the words arriving a sentence
at a time, 9 s ahead, as the live reading's do. The springs take about 3 s to settle, and a ping held the radar 3.1 s and
let go a second later where 4 s was wanted. `DispatchMedium._settled` now makes every look the camera takes:

- **Held long enough to be seen**: `LOOK_LEAST` (5 s) from its start, unless something else begins first, and the hold never
  runs past what begins next, so nothing is gone back to. A ping holds the radar `PING_HOLD` (5 s) at least, on to the end
  of the sentence said over it if that ends within `PING_HOLD_MOST` (9 s; `DispatchScript.sentence_ends`, since the spoken
  words have lost their punctuation), then lets go in a second.
- **Never left only to come straight back**: the camera stays on what it was on rather than ease home for less than
  `AWAY_LEAST` (7 s) before it turns again (a walk's look runs into the ping where he arrives, a ping's into the walk after
  it), unless what comes next is the whole desk.
- **No swerve**: a look cut before the camera could get there (`GLANCE_LEAST`, 2.5 s - a phone hung up as the radar pings)
  is not taken, nor a short turn away between two looks at the same thing - but words to be read are always looked at
  (`TO_READ`: a typed word is never captioned).
- **The mug, drunk from**: brought up over 2 s, held at the mouth 3 s for the sip, set down over 1.8 s; the voice waits
  through the sip and goes on as it comes down.

In the episode the ping at "And there's the rest of him" is held about 8 s and the walk at "No, no, no" is on the radar
throughout. A zoom-and-retract the author reported during that walk did not reproduce on the rehearsal's voice even with
the old rules, so the author's eye on that spot is the test.

### Redacted words, and places made generic

Real names, addresses and places are kept out of the episode so the viewer can imagine themselves in the target's shoes.
Sensitive text is hidden the way a video blurs a face, as a post-process on the finished frame, not as marks on the glass.

- **`<!-- redact: words -->` inside a ` ```screen ` or ` ```terminal ` block**: the words are put up as written, and hidden
  over the finished frame. A redacted character travels in the terminal's text as itself moved into Unicode's private plane
  (`DispatchScript.REDACT_BASE`), so typing, wrapping, scrolling and a strike count it as one character and nothing
  downstream changed. A typed block is said aloud, so a redact there is warned of and its words left out.
- **The episode**: the search (its three names and the first one's city), the record's name, address and plate are redacted;
  place names in what is said and on the radar are generic ("the grocery store", "the avenue", "the store").
- **`DispatchCensor` is drawn over the desk's frame after the 3D** (and under a picture over the whole screen): each run's
  rect on the terminal, padded (runs on lines next to each other make one box), is carried through the glass's bulge and the
  camera, and the box is the upright rect round it, eased a beat behind (`LAG` 0.09 s) and wavering outward a little, never
  short of the words. It is unstable and detached from the terminal on purpose: a big rectangle with large straight cracks
  in it. Its cracks are a tree of straight lines laid once per run (each across the shard it splits, shards about three
  letters long), and each shard is flat, the average of the frame under it, read off a jittered grid of taps over that shard
  alone (Godot's screen mipmaps are blurred: averaged off them, every shard came out near the box's mean). A name typed at
  the prompt is covered whole from its first key. The terminal draws its cursor as before; it is under the box while a name
  is typed.

Looked at: the censor in the gate's render (`tests/run_quiet.sh -- tests/dispatch/dispatch_redact_check.gd --png`).

### The revised night's marks: the gain, the bell, the lamp

Three marks from the revised script (rift's `MEDIUM.md`):

- **`<!-- gain: N -->`**: the radar's left knob is the gain (`DispatchSet.gain_knob`), its pointer at 3 when the night
  begins and its scale, one to ten, printed round it (`DispatchScreens` `gain` face). The mark turns it a step at a time, a
  click each, and the voice waits while it turns and a beat (`DispatchScript.GAIN_*`). Above 3 the scope paints clutter
  (`DispatchMedium.clutter_at`): up to 40 dim, unnamed blips round where the target was when it went up, laid as the rooms
  of one building turned its own way with him off its middle, nearest first, so each step paints the next nearest; 33 at
  nine. Each is painted only once the sweep passes it after the knob reached it, a little off each round; one in four
  drifts. Turned back down, they fade over a sweep or two and are not painted again. The camera stays on the radar after
  the turn, as a `look:` holds it.
- **`<!-- bell -->`**: one short near-square beep (880 Hz, 0.2 s) as the block after it goes up; the voice waits half a
  beat. It turns the camera to the terminal.
- **`<!-- lamp: off -->`** (or `on`): the lamp's click, its light dying over 0.18 s; the desk is left to its screens. It
  turns the camera to the whole desk, unless that would turn away from the terminal and straight back (`_looks_taken`),
  when the light goes out around the terminal instead.
- **The outro waits for the desk** (`DispatchMedium._after_last`): the end fade is timed from the end of the rests the voice
  holds after its last word, not the word itself, since the revised ending (lamp, a last line, sleep) runs eleven seconds
  past the last word.

Looked at (the look probe on a note cut from the episode's three passages, seed 57234): the scope at three and at nine,
the clutter fading and gone, the knob at three and at nine, an invalid option after its bell, the lamp's light gone from
beside the terminal, the last line printed in full light. On the episode itself (rehearsed): both bells sound as their
screens go up, nine paints 33 blips, the lamp clicks after the last word.

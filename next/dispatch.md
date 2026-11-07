# The dispatch desk: a lair, a terminal, a dozen phones

Opened 2026-11-06 for `rift/animations/targeted-individuality/targeted-individuality.md`, from its handoff
(`MEDIUM.md` beside it) and the user: "The main thing we're needing is the desk, with the terminal-style computer,
and the cell phones, and the gadgets on the table - with the ability to shift between the different things ... novel
camera requirements here, since we will likely need to either look left and right, or shift left and right - as well
as in/out, and possibly even tilting forward/back. But as before, we're looking for gentle transitions." And the lair:
"Just beyond the table ... large roots crawling downward from the ceiling, as if we are underground. Some of the roots
should extend past/below the table, while others should reach ON to the table, and grow across it toward us, the
camera/actor. Just simple roots, chaotically growing, a bit like neurons." The terminal is the beige computer on the
cover of "ERROR ME FOUND": a deep CRT on a flat desktop case with a floppy slot, a narrow keyboard, and asleep, one
small cyan star in the middle of the black.

## What it is

**A component, `dispatch`** ("+" Dispatch desk; it brings a Voice, as the Letter does) and **its medium, `dispatch`**:
one desk late at night in a hollow under the ground, seen from the chair. The man who works it is never seen: the
viewer sits where he sits, and everything on the desk moves on its own. The note's words are the script, word for
word; the desk is described in the note's own top-level `desk:` block (the author's, never ghost's `ghost:` block).

## Decisions

- **Every prop is built by code, not by agents.** Each one here has a job in the script - a phone opens and is held to
  the ear, the terminal types, the printer prints, the radar pings, the receiver's needle swings with the static, the
  switch is thrown - and a prop an agent designs can't be worked by a mark, costs agent runs per note, and lands
  unpredictable geometry. Static parts are [Props] specs written in code (as [DeskLook] writes the letter's desk
  things); moving parts are nodes of their own. The `desk:` block's words are kept for a later set dresser (phase two,
  as the letter's) and today only `phones` (the labels, in order) is read.
- **The camera sits in the chair and turns to what is active** (a phone ringing, the terminal typing, the radar on a
  ping, a picture landing on a screen, the receiver while it plays static), leaning a little toward it, on critically
  damped springs - gentle: nothing jumps, nothing whips. With nothing new for a while it eases back to the whole desk.
  A breath of slow wander under it, so it is never dead still.
- **A phone in hand is held to the ear**: it floats up beside the camera on the right, open and tilted, in the corner of
  the frame, while the camera looks where it looks. A phone on hold lies open on the desk in front of the rows.
- **The voices through a phone are heard through one** - a new voice mark any script can use, `<!-- heard: phone -->`
  (also `desk`, `far`), on a speaker's turn: the earpiece's band (300-3400 Hz) and a little grit, quieter and
  further off for a phone lying on the desk, fainter still for a voice in the caller's room heard through their phone
  (the cashier). The dispatch script writes it into what the voice reads, from which phone is in hand or held when
  each turn is said, so the author never writes it. **A line's static** (2026-11-06, the user: "if any of those voices
  are coming over radio transmissions or cell phones ... for radio: we might want to add a new voice feature, to
  overlay static over the voice"): each row adds `hiss` and `crackle` before the band, riding the voice - open while
  it is heard and 0.35 s past it, so it hisses between words and never through the rests - and a fourth row, `radio`,
  is a two-way radio: narrower, driven harder, crackling, its squelch bursting as the voice keys up and hissing off
  after it. No voice in this episode is a radio; a phone's line hiss is faint (about 30 dB under the voice).
- **Every sound is synthesized**, as the table's are ([WorkSounds], [Soundscape]): the flip and snap of a phone, its
  dial tones and the ring in the earpiece, a phone buzzing against its neighbors, keys, the printer's screech, the
  sonar ping, the receiver's hiss and Jupiter's storms (Io-B's popcorn S-bursts, Io-A's surf-like L-bursts), the jet's
  real Doppler fall (a moving source, its pitch and level from where it is), the toggle's click, the mug set down.
  Played by the medium as it is drawn, so a render records them.
- **The marks the script used that the desk could not do on its own are made concrete**: `act:` (plain words, for a
  puppeteer that does not exist here) becomes `<!-- lift: mug -->` and `<!-- switch: BAD -->`; the last TV picture,
  "may be better rendered than painted", becomes `<!-- live: tv -->` - the TV shows this desk, live, seen from just
  behind the empty chair, with whatever lies on it. `<!-- static: 5, surf -->` names Io-A's sea; bare is Io-B's crackle.
  A text message gets a short rest so it can be read before the reply (the handoff said the voice does not wait; the
  comedy needs it to).
- **The roots are grown, seeded, and some grow**: a dozen-odd systems from the ceiling behind and beside the desk,
  random walks biased down that branch as they go; most hang into the dark past the desk to the floor, a few come over
  the desk's far edge and crawl across its top toward the chair between the things on it. The ones on the desk creep
  on through the night (a front moving along them with show time). Bark from the props' wood shader, dark and fibrous;
  depth fog takes the far ones.

## The marks

As `MEDIUM.md` has them, with the changes above: `call:`, `/call`, `/call: X`, `ring:`, `text: X | words`, `ping:`,
`sound:`, `static:`, `print`, `sleep`, `off:`, `look:`, `lift:`, `switch:`, `live:`, `image (feed|satellite|tv|full)`,
`/image`, fenced ` ```type `, ` ```screen ` and ` ```terminal ` blocks, `strike` after a typed block, and the voice's own (`speaker`,
`hesitation`, `delivery`). `act:` stays a note.

## Files (`src/dispatch/`, a folder after `letter`)

| File | What it is |
|---|---|
| `dispatch_script.gd` | `DispatchScript`: the note into the voice's text (rests, `heard` marks, typed words said), the spoken words, and the desk's actions anchored to them |
| `dispatch.gd` | `DispatchMedium`: the world, the schedule (a [ReadingFollower]), the state of every thing at a moment, the camera, the opening, the pictures, the captions |
| `dispatch_set.gd` | `DispatchSet`: the desk and everything on it, built - terminal, keyboard, phones, radar, receiver and scope, printer and its heap, the three screens, the switch, the chart, the handbook, the things, the chair, the room |
| `dispatch_roots.gd` | `DispatchRoots`: the roots grown and meshed |
| `dispatch_screens.gd` | the 2D faces drawn into the screens: the terminal, the radar, the scope, a phone's two screens, the receiver's dial |
| `dispatch_sounds.gd` | `DispatchSounds`: every sound of the desk, a function of show time |
| `dispatch_card.gd`, `dispatch_walk.gd` | the component's card (pins the medium, the desk's number) and what it hands the reading; the pictures are the note's Pictures card's (next/pictures.md), `DispatchMedium.pictures_in` saying which marks they are |

And in the voice: `Manuscript.HEARD`, a passage's `heard` through [ReadingPlan], a mark in [ReadingJoin], applied by
the stream and the export, the band in [VoiceFX].

## Gates

`tests/dispatch/dispatch_script_check.gd` (the parser on a fixture with every mark: the phones' state, the voice's
text, the actions), `tests/dispatch/dispatch_check.gd` (the medium built headless and played through on rehearsed
words: what is in hand, on the terminal and on the radar at moments, the camera's target), `tests/dispatch/
dispatch_sounds_check.gd` (the jet's pitch falls, nothing is louder than the voice, the two storms differ, the same
twice), `tests/voice/heard_check.gd` (the band, the plan, the join's marks); probe `tests/dispatch/
dispatch_look_probe.gd` (frames to look at).

## Status

**Built 2026-11-06**; the author has not yet watched or heard it.

What was looked at (rendered with `tests/dispatch/dispatch_look_probe.gd` on a steady rehearsed voice, frames read by
eye): the home view from the chair, every camera spot settled, the record and the target's log on the terminal (legible
close up), the council's typed question, a text captioned and lit on its phone, a phone dialing and one on hold, a ring,
the radar's ping with the place beside the blip, the receiver in a storm, the printer, the TV showing this desk live
from behind the chair (it shows itself inside it, a tunnel), the roots from the chair looking up (the shaft of light
through the fog) and from outside the hollow.

Measured: the episode's 3,329 spoken words line up with the voice's plan word for word; every voice is routed through
the right phone; 90 actions, about three minutes of rests; the desk's build is about half a second (most of it the
roots), so it is made on a worker while the show waits, as the table's is; a frame's pose about 1.2 ms; a live plan made
again about 20 ms a sentence.

Decided in the build:

- **The desk is crowded, and the roots go round it by a grid search** (`AStarGrid2D`, 2 cm cells, what stands there and a
  margin solid; a flood over it picks the spot each root can reach nearest the chair's middle, apart from the others).
  Free steering got stuck within centimeters. A root may lie across something flat (the chart); its growth runs along
  its crawl from the desk's edge.
- **The right side was laid out by what the chair must see past what**: the radar in front, the receiver at the desk's
  end so its view clears the radar, the TV up on a crate so it is seen over it.
- **The feed monitor's snow lights the desk's dark end** (the printer, the phones); the lamp lights the keyboard and the
  blotter; a shaft of cold light falls through a crack among the roots behind the desk.
- **The terminal wraps at words inside what its curved glass and bezel leave seen** (70 columns, 22 rows).

### The author's first look (2026-11-06, later)

The author watched the opening and looked round the desk: "The initial pacing of this video feels all wrong. Right when it
starts, we've barely had a moment to look at the scene before we're zooming-in on the radar. Then, the radar itself: the
person jumps between 3 distant points (house, stairs, parking lot) for EACH spiral around the radar. They basically
teleported ... We might have to linger on the radar for 20 ticks or even more." Then: the terminal's star "was in the
source image, but we do not need it in this one"; "I don't like how the terminal just "jumps" directly to the redemption
simulation screen ... Start with a blank terminal prompt, type some commands, navigate a tree of options, find the record
we need (probably by keyword search, not a list)"; the seed "barely does anything" ("nobody puts a mug that close to them",
and "under the mug, there is a transparent circle"); and feedback 0033, roots only behind the desk ("As if the entire
office were under a tree, consumed from every direction by the roots"). The scene itself was "looking very nice". Built:

- **The desk is seen first**: the voice opens on a breath of the desk at rest (`DispatchScript.OPENING`, 3 s), the camera home,
  the title cleared before it (`_opening`).
- **The target has a track**: a ping is where he arrives, a place laid out from the script alone
  (`DispatchMedium.track_of`: a step on from the last as long as the walk the script gives it, turning gently, a compass word
  setting the way; a place named again is the same spot, a name with a comma a little off its head; the whole track centered
  on the scope, made smaller only if it would run off). The sweep paints him where he is as it passes (every 2.5 s), the
  paints before fading behind - a step a round, never a jump - with a soft tick each pass on his way.
- **The walk is under the voice** (the author, of a first try that had the voice wait while the radar was watched: "There
  are a solid 30 seconds of silence at the beginning of the video. Worse, the camera pans and focuses on the radar while it
  is doing NOTHING. The look should be in response to the sounds the radar makes, as the target starts moving"):
  `<!-- moving -->` sets him off toward the next ping's place - the radar sounds its alarm (a low beep, two higher) and
  the camera turns to it - and what is written between it and the ping is said while he goes; the ping's sound turns the
  camera again as he arrives. Nothing makes the voice wait more than a beat for the radar, and the camera goes to the
  radar only at its sounds (dispatch_check holds it). A ping that still gives seconds is warned of.
- **The intro, written again** (rift's script; NOTES.md there): Control opens the shift talking, the camera home; he pulls up
  the subject's record in short typed bursts between lines (`council`, `1`, `search ryan brooks`, `open 1`); the radar pings
  as it finds him in his room; the mug; then the alarm - he is moving - and Control talks over the walk to the stairwell
  ("Oh, no.") and on to the parking lot (the author's own "No, no, no. Ten to eleven?..." over the second walk).
- **The terminal is dark asleep** (no star), and **a session is typed** (` ```terminal `): `>` lines typed at the prompt a key
  at a time with a typist's give-or-take, entered, answered a line at a time, read before the next, the prompt back at the
  end; asleep, it wakes to a bare prompt first (`DispatchScript.session_plan`, `DispatchMedium.session_text`). A shown screen
  is drawn down the glass a line at a time. The episode logs into the council's menu, picks SUBJECTS, searches `ryan brooks`,
  gets three matches and opens the first - then the record; and mirrors his screen before the first HIS SCREEN.
- **The desk is its number's** (`DispatchSet._lay_out`, `_pack`): mirrored or not (the radio's things right or left, the
  phones and printer opposite), each end a little off as one, each thing turned; the small things packed into free room
  (the mug at arm's reach, 25-40 cm in, beside the keyboard; the switch by the keyboard; the handbook, its spine to the
  chair; the chart, the pencil cup, the stamp, the tracker). Everything the medium and the roots read follows it (`at_of`,
  `desk_at`, `held_rect`, the camera's spots). **The "transparent circle" under the mug was its shadow**: the gooseneck
  hangs almost straight over it, the glossy top (polish 0.45) wore the lamp's warm sheen everywhere else, and the shadow,
  emptied of it, was lit only by the screens' cool glows (which cast no shadows) - a crisp pale-blue disc, measured with the
  mug hidden and then the lamp. The top is duller now (polish 0.22, an old desk), the lamp's shadow soft (blur 6) and
  never empty of its own light (`shadow_opacity` 0.62, the room's bounce). The coffee ring itself is a thin opaque, matte
  rim with an older arc beside it, a little off the mug's foot (a translucent disc over the top had read as glass, and a
  `Decal` drew its footprint pale).
- **The mug is drunk from** (feedback 0036: "the cup is tilted in the wrong direction. It would be better to just bring
  the mug so close that it leave's the camera's viewport"): upright all the way, lifted out of its ring and brought under
  the eye (`MUG_MOUTH`, in the camera's own frame, so it is out of the picture whichever way the camera looks), held for the
  sip, set back down; the camera on the whole desk meanwhile, so the mug is seen to rise and leave past the lower edge. (It
  had been held in front of the camera in the camera's frame, and tipped with its every look down.)
- **The keyboard is a real one** (the author: "The keys are the wrong shape, they are layed-out in a nonstandard fashion
  ... Some of the keys at the top-right ... are just floating there"): a standard compact layout, five rows of fifteen
  units (`DispatchSet.KEY_ROWS`), each key a sculpted cap - a skirt tapering to a dished top, the rows leaning toward the
  typist (`KEY_PROFILE`), letters beige, the rest gray - one mesh, on a case sized to it. The four keys that had stood past
  its back edge are gone.
- **A text is read on its phone** (the author: "there are subtitles displayed in the middle of the screen. I don't like that.
  It would be better to ding with a notification sound, then pick up the cell phone, open it, and look at the message on the
  screen"): a chime and a buzz, the phone up out of its row and open, held before the eye (`READ`, in the camera's frame),
  the message on its screen as a thread - never captioned (the medium's caption is gone) - and home after, unless it
  texts again within `TEXT_AGAIN`. **A reply is typed back** ("we are SPEAKING to the person sending text messages, which
  doesn't work logically. We should probably be sending those messages back, through the phone"): `<!-- reply -->` types
  the room's next words into that phone as they are said, a key at a time, and sends them; the voice still says them.
- **A real keypad and speed dial** ("Ensure there are numbers, and probably a send/end button ... some kind of speed dial
  as well, where every person on the other end is bound to 1, then we click send, then we hear the ring"): each phone's
  keypad is drawn (`DispatchScreens._draw_keypad`: Send, End, a navigation key, 1-9, *, 0, # with their letters); a call
  comes up before the eye, 1 is held (its tone), Send pressed, then to the ear for the rings.
- **The mug and pencil cup are the letter desk's** (feedback 0037: "the pencils are clipping through it ... we should
  probably just reuse the pencils and mugs we already have ... we want to remain DRY"): `DeskLook.made(kind, seed)` builds
  one of that desk's things, and the dispatch desk sets out its mug and its hollow pencil cup.
- **Roots all round** (`DispatchRoots`): eight systems beside the desk on each side, out past its ends, down to the floor and
  a long way along it, and one at each end clinging under the desk's edge, down its front corner and out across the floor.

### The drives, and typing said behind the keys (2026-11-06, later still)

The author: "In the script, somehow "12 minutes in the car" turns into "he's walking up the stairs," within about 1 minute
... We should probably reduce that drive down to a more tolerable limit, like 4 minutes in the car, and then pad-out the
narrative however we need to do so." Then: "you could probably just call the grocery store "the Safeway" ... it is about 4
minutes away - just down the street." And of the council's message, around 15:00: "Every word is spoken individually, with
breaks, because we're waiting on the typing. Instead, you should just do what we do in the journal-writing mode: speak
slightly behind the writing. Also, in the B and C responses there, "IT" is pronounced like "I-T"."

- **A drive is one walk with stops along it**: a `<!-- moving -->` straight after a ping is the target PASSING a place - a
  point on his track he goes on through - and makes no alarm, takes no rest and turns no look (`DispatchScript`'s
  `passing`); the radar paints him on through it. A moving mark's look holds until the next ping, at most
  `MOVING_HOLD_MOST` (12 s), so a long drive does not leave the camera on the radar. The script's two drives (to the
  Safeway and home) are each "ping driving south/north" passed through, and long enough now (2-3 minutes of the voice each,
  the rest is the prose's).
- **A typed block is said behind its keys** (`DispatchScript.AHEAD_WORDS`, the letter's two words): its first two words
  typed at a typist's pace in the rest before the voice, each word after typed while the voice says the one two before it,
  through to the next word's start, no quicker than `KEY_QUICK` a key and always done before the voice says it
  (`DispatchMedium._char_times`) - so the voice reads what is on the screen and goes on unbroken. A mark inside a typed
  block no longer reaches the voice (the council's message had `<!-- hesitation -->` between its words; taken out of the
  script). A reply on a phone is still typed as it is said.
- **A block set all in capitals is said in sentence case** (`DispatchScript.said_of`): `TextNorm.INITIALISMS` reads `IT` as
  the letters, which is right for a field and wrong for a terminal's words ("CONTAIN IT." was "contain eye tee"). Only a
  block with no small letter is lowered, so an initialism in a log line keeps its capitals; a named letter, `[D]`, stays the
  letter. The screen still shows the capitals.
- **No root where a phone lies open** (feedback 0038, "This phone is clipping through the root here"): the held area had been
  a strip round the open phones' bases, and an open lid reaches 14 cm past its base; it was kept out of the roots' grid only,
  not their tendrils or their wander. `DispatchSet.held_rect` is now the whole of the first three phones laid open, lids and
  all, and the roots take it as one more thing standing on the desk (`DispatchRoots.build`). Of 20 desks, roots had crossed
  it on every one; on none now (dispatch_check `_roots_clear`, eight desks, with the old strip as its control).

### What the camera turns to is seen, and the mug is drunk from (2026-11-06, later still)

The author: ""And there's the rest of him" - this animation is weird, because it zooms to the radar then immediately
returns. If we're going to zoom there, we should at least hold it for a little bit." Then: "When the coffee mug was
pulled-in for a drink, it felt like it moved too fast. It also returned too quickly: it didn't hold long enough to take a
sip, either. Please correct that, as well as any other places where we aren't holding on the things we've focused on for
long enough." And feedback 0040, at "No, no, no.": "The camera here is zooming, then retracting, then zooming, then
retracting... it's not stable, and it feels bad. Please correct camera stability here, while the target is moving."

Measured first (a scratch probe springing the camera through the whole episode on the rehearsal's voice, and again with
the words arriving a sentence at a time, 9 s ahead, as the live reading's do): the springs take about 3 s to settle, and a
ping held the radar 3.1 s and let go a second later - wanted 4 s, settled on for under one. Two dozen looks were seen
for under 2.5 s. `DispatchMedium._settled` now makes every look the camera takes:

- **Held long enough to be seen**: `LOOK_LEAST` (5 s) from its start, unless something else begins first - and the hold
  never runs past what begins next, so nothing is gone back to. **A ping holds the radar** `PING_HOLD` (5 s) at least, on
  to the end of the sentence said over it if that ends within `PING_HOLD_MOST` (9 s; `DispatchScript.sentence_ends`,
  since the spoken words have lost their punctuation), then lets go in a second.
- **Never left only to come straight back**: the camera stays on what it was on rather than ease home for less than
  `AWAY_LEAST` (7 s) before it turns again - a walk's look runs into the ping where he arrives, a ping's into the walk
  after it (0040's zoom and retract) - unless what comes next is the whole desk, where it goes as before.
- **No swerve**: a look cut before the camera could get there (`GLANCE_LEAST`, 2.5 s - a phone hung up as the radar
  pings) is not taken, nor a short turn away between two looks at the same thing (the council's static between its two
  typed blocks) - but words to be read are always looked at (`TO_READ`: a typed word is never captioned).
- **The mug, drunk from**: brought up over 2 s, held at the mouth 3 s for the sip, set down over 1.8 s; the voice waits
  through the sip and goes on as it comes down ("Cold.").

On the episode, the ping at "And there's the rest of him" is now held about 8 s and the walk at "No, no, no" is on the
radar throughout. Ten looks are still seen for under 2.5 s, each cut by the next thing the script does a few seconds
later (a ping, then a picture landing; a print, then a call) - the script's beats, which spacing them would give room.
0040's zoom and retract did not reproduce on the rehearsal's voice even with the old rules (the walk was one look then
too), so the author's eye on that spot is the test.

Open:

- The author's eye: the camera's pace (springs of 0.95 s), the props' look, the roots, the lair's light.
- The intro's pace with the real voice, by ear and eye: the walks' length is the prose's.
- A real voice and an export; the seven pictures painted from the Pictures card.
- The paper heap on the floor reads only dimly; the printed lines on the paper are small.
- Agents dressing the desk from the note's `desk:` block (phase two).
- A live plan made again in about 20 ms a sentence could be made cheaper (the letter's indexing).

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

- **Every thing on the desk is a make of a role, not an agent's per note** (next/working_props.md). Each has a job in the
  script - a phone opens and is held to the ear, the terminal types, the printer prints, the radar pings, the receiver's
  needle swings with the static, the switch is thrown - so each is a [PropMakes] role whose own make is a [Props] spec
  shipped in `data/props/`, its working parts named: faces the desk shows its pictures on, lights, and parts that
  follow what the desk feeds them. Any make with the role's faces can play it - one kept, one refined - and is worked the same
  way. The `desk:` block's words are kept for a later set dresser (phase two, as the letter's); today only `phones` (the
  labels, in order) is read.
- **The camera sits in the chair and turns to what is active** (a phone ringing, the terminal typing, the radar on a
  ping, a picture landing on a screen, the receiver while it plays static), leaning a little toward it slowly and gently,
  as the night is: a lead that eases every move in, then critically damped springs (`LEAD_TAU`, `SPRING_TAU`; half a move
  in about 4 s, nearly all of it in 8): nothing jumps, whips or lurches. Two looks at the same thing are one, held between
  (`SAME_BRIDGE`); in a live reading the camera holds on for a next look that comes soon, before its words are heard
  (`_said_by`), rather than pull back to the whole desk for nothing. What happens in the black turns it to nothing, and so
  does a picture told `unwatched` (`image (feed, unwatched)`), which lands on its screen with the camera left on what it was
  on, and a static told so (`static: 3, surf, unwatched`), heard on the receiver with the camera kept where it is. With nothing new for a while it eases back to the whole desk, with a breath of
  slow wander under it.
- **A phone in hand is held to the ear**: it floats up beside the camera on the right, open and tilted, in the corner of
  the frame. A phone on hold lies open on the desk in front of the rows, its screen as a call's: the name and the clock.
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
  far edge or its ends and crawl across its top toward the chair through the open room between the things on it, a moderate
  reach, then over the near edge and down the desk's front. The ones on the desk creep on through the night (a front moving
  along them with show time). Bark is from the props' wood shader, dark and fibrous; depth fog takes
  the far ones.

## The marks

As `MEDIUM.md` has them, with the changes above: `call:`, `/call`, `/call: X`, `ring:`, `text: X | words`, `ping: place |
bearing, range`, `sound:`, `static:`, `print`, `sleep`, `off:`, `look:`, `lift:`, `switch:`, `live:` (a screen or the tablet),
`image (feed|satellite|tv|full)` (a picture over the whole screen comes in where it is written: after what the desk does
before it in that silence, a block's typing among them - `DispatchMedium._picture_in`), `/image`, `video
(feed|satellite|tv): file | words` (a screen's picture may be told `, unwatched`), ` ```terminal ` blocks (one program,
`DispatchTerminal`'s line kinds), `strike` after a typed line, `<!-- redact: words -->` on a line of a terminal block,
`gain: N`, `bell`, `lamp: off|on`, `power: off|on`, `environment: shafts off, beams on[, secs]`, `play
(terminal|feed|satellite|tv): NOTE TITLE | video path` (told `mono` or `unwatched`), `fade: to-black|from-black, HH:MM, secs`, `tablet` / `/tablet` with ` ```page ` fences,
`back`, `new tab` and `<!-- player -->`, `reply: tablet`, `replay: tablet | words`, and the voice's own (`speaker`, `heard:`, `hesitation`, `delivery`). `act:`
stays a note. The ScriptMarks registry has a row for each (docs/script.md).

## Files (`src/dispatch/`, a folder after `letter`)

| File | What it is |
|---|---|
| `dispatch_script.gd` | `DispatchScript`: the note into the voice's text (rests, `heard` marks, typed words said), the spoken words, and the desk's actions anchored to them |
| `dispatch_terminal.gd` | `DispatchTerminal`: the terminal's one program - the glass (a fixed 70 by 22 screen), panels kept by id, keys, every line kind of a block, timed; simulated through the whole note, played at a moment |
| `dispatch.gd` | `DispatchMedium`: the world, the schedule (a [ReadingFollower]), the state of every thing at a moment, the camera, the opening, the pictures, the captions |
| `dispatch_set.gd` | `DispatchSet`: the desk and everything on it, built - terminal, keyboard, phones, radar, receiver and scope, printer and its heap, the three screens, the switch, the chart, the handbook, the things, the chair, the room |
| `dispatch_desk.gd` | `DispatchDesk`: the desk itself - its wood, top, blotter and base - built from properties (`FIELDS`), each drawn by its number until set |
| `dispatch_roots.gd` | `DispatchRoots`: the roots grown and meshed, how many hang, lie on the desk and stand beside it, how thick and how they wander (`FIELDS`); a hanging root kept clear of the printer's paper and heap along the very line its tube is drawn on (`_drawn_clear`: filled in, each run moved round the side that moves it least, smoothed and cleared again), none comes down onto the desk where the paper falls, and the root clinging under the desk's end comes down in front of the paper hanging there (`_in_front`) |
| `dispatch_screens.gd` | the 2D faces drawn into the screens: the terminal (its redacted words as written, and where they lie), the radar and its clutter, the scope, the SDR's spectrum and waterfall, a phone's two screens and keypad, the receiver's dial, the gain knob's scale |
| `dispatch_scope.gd` | `DispatchScope`: what the receiver's oscilloscope draws - the receiver's own output (its static from `DispatchSounds.receiver_wave`, a voice on it from the heard waveform through its words), levelled by the receiver's AGC, triggered and swept; worked out on a worker |
| `dispatch_spectrum.gd` | `DispatchSpectrum`: what the SDR screen on the receiver shows - each row of its waterfall a pure function of its moment, the receiver's stretches and the heard audio's bands; the ring of rows it has made |
| `dispatch_censor.gd` | `DispatchCensor`: redacted words hidden over the finished frame - a tracked box cracked into flat shards (`shaders/dispatch_redact.gdshader`) |
| `dispatch_sounds.gd` | `DispatchSounds`: every sound of the desk, a function of show time |
| `dispatch_props.gd` | `DispatchProps`: the desk's things on the note's Props card and the Dex - the mug and the cup of pencils as roles any make can play (Choose…, kept in the Medium block's `things`; next/library.md, "Roles"), the desk and the roots as parts with properties and a Roll (kept in the Medium block's `desk` and `roots`; the desk's Choose… offers desks drawn by other numbers), and every thing the desk builds, pictured alone |
| `screen_plays.gd` | `ScreenPlays`: what a `play` mark plays, found by what it names - another note by its title (its made song, that song's bake taken once by the bake runner, its medium, its storyboard, how its Look shows its words), or a video file by its path (its size and rate probed and its sound taken out once, under `user://screen_films/`) |
| `dispatch_format.gd`, `dispatch_walk.gd` | its own rows on the Medium card (the desk's number) and what they hand the reading; the pictures are the note's Pictures card's (next/pictures.md), `DispatchMedium.pictures_in` saying which marks they are |

And in the voice: `Manuscript.HEARD`, a passage's `heard` through [ReadingPlan], a mark in [ReadingJoin], applied by the
stream and the export, the band in [VoiceFX].

## Gates

`tests/dispatch/dispatch_script_check.gd` (the parser on a fixture with every mark: the phones' state, the voice's text,
the actions, the glass panel by panel, pings, fades, the tablet's pages), `tests/dispatch/dispatch_check.gd` (the medium
built headless and played through on rehearsed words: what is in hand, on the terminal and on the radar at moments, the
camera's target and its hold on the glass, the black and the clock, the tablet, a clip's frames, the grid down, the
Environment switched and a video decoded onto the terminal), `tests/show/nested_show_check.gd` (a note played inside another:
its own Director, song and viewport, the session's untouched, its clock, its song silent once nobody asks, its words; the
credits' roll), `tests/dispatch/dispatch_sounds_check.gd` (the
jet's pitch falls, nothing is louder than the voice, the two storms differ, the same twice), `tests/voice/heard_check.gd`
(the band, the plan, the join's marks), `tests/dispatch/dispatch_redact_check.gd` (GPU: the terminal on a bulged quad
through a camera, the censor over it - no letter of the hidden words outside a box, every shard one color and the average
of the frame under it, the tracker never short of the words), `tests/dispatch/dispatch_spectrum_check.gd` (the SDR screen:
the filter's edges, a storm and its pops seen, a voice as a carrier and mirrored sidebands, the room's voice never on it, the
ring of rows; control: a screen that takes every voice heard), `tests/dispatch/dispatch_scope_check.gd` (the scope: a pop a
spike where it is heard, a voice its own waveform and the room's never, a held tone standing still, the AGC; controls: the
moment before the pop, running free), `tests/audio/heard_wave_check.gd` (the heard waveform read exactly off a WAV and off
what a bus caught); probe `tests/dispatch/dispatch_look_probe.gd` (frames to look
at; `--voice <wav> --sdr 1` for the SDR screen with a real voice's bands).

## Status

**The receiver's scope draws the receiver's own output** (built; not yet seen by the author): what a scope across its speaker
shows, never a drawn pattern (`DispatchScope`). Its static is the receiver's own synthesis, rendered for the moment on the glass
(`DispatchSounds.receiver_wave`: the same filters and levels, each pop in the slot and of the size the speaker plays it, a noise
of its own); a voice that comes in on the receiver is its real waveform, off the heard audio (`AudioFeatures.wave`, below), taken
only through that voice's words, so the room's voice never shows. The receiver's AGC levels it, as an old set's does: an idle
hiss brought up to a fine thread, a storm filling the glass, a voice bringing the gain down and the static under it, coming back
up over a moment after. It draws one of two ways, the receiver's `trace` property on the Props card (`DispatchSet.RECEIVER_FIELDS`):
a FIGURE (the default), the scope in XY - the output against a copy 0.3-3.5 ms behind and a copy 0.8-6 ms behind read at another
rate (its pitch and tempo morphed: held near one, where the figure precesses, or at 1.25, 1.5 or 0.75, where it ties Lissajous
knots, eased from one to the next every six seconds), three channels tracing the signal's phase portrait in three dimensions,
shown turning in depth as a slowly turning mix of two of them on the X input would; drawn through an 800 Hz tone so its loops are
the voice's lowest partials, smooth; the beam brightest where it moves slowest and on the near side, the two figures before it
fading. A held vowel is a knot of ribbons, a storm a fuzzy ball with each pop flaring out of it, an idle receiver a small blob. Or a
SWEEP, triggered on a rising edge, so a held vowel stands still and noise runs; 2.5 ms a division; the sweep before it fading on
the phosphor. The figure's drift (delays, rate, turn, tilt) is a function of show time and the desk's number. Worked out on a
worker a frame behind, in a render waited for. For the author: the figure's look with the real voice, how fast it turns, the
rates it ties, its tone, and whether the default is the figure or the sweep. The needle still swings with the
storm's level and each word. The dial and the SDR screen read one frequency (`DispatchSpectrum.FREQ`, 20.1 MHz).

**The heard waveform** (`AudioFeatures.wave`, `HeardWave` in `audio/`): every scene and medium is handed the last 93 ms of what
is heard, mono at 11,025 Hz, read only when asked and safe from a worker. A WAV playing (an export's take, a nested note's song)
is read exactly off the disk at its moment, never held whole; a stream (a reading said live, a song made as it plays) is caught
off the show's own bus (`Heard`, sent to the Master bus), so the desk's sounds are not in it. Not XY: the receiver is mono, and a
true scope in XY mode would draw only a diagonal line.

**The SDR screen on the receiver** (built; the author has not seen it): a hobbyist's addition to the old set, its own role
(`sdr`, `data/props/sdr.prop.json`: a 5" panel on a stand, a radio dongle in its side, a coax down the receiver's back) standing
on the receiver's oscilloscope (`DispatchSet._sdr`, on the highest part over the scope's glass), so the old green trace and the
modern waterfall are seen one over the other in the receiver's look, which aims a little higher for it. A spare thing: its × on
the Props card takes it off. It shows what a hobbyist's program shows (`DispatchSpectrum`, drawn by `DispatchScreens`): the
frequency (the dial's 20.100 MHz) and AM, the spectrum's line over a grid of decibels with the 6 kHz passband shaded and the
tuned frequency marked, and the waterfall under it, a row 24 times a second, the newest at the top, five seconds of it. Every row
is drawn from what the receiver sounds: the band's hiss inside the receiver's filter and dark past its edges, Io-B's pops as
pale streaks (the very pops `DispatchSounds` plays), Io-A's surf as swells, and a voice that comes in on the receiver as a
station - its carrier a line down the middle from a beat before its first word to after its last, and the voice's own spectrum
mirrored either side, read off the heard audio's bands (`AudioFeatures`, which the medium is handed every frame: the live
analyzer, or the export's bake) only through that voice's words, so the room's voice, the keys and the phones never show. The
screen is always full: where the show jumps (a scrub, a reading begun mid-way, its first frame) the rows before are made again
on a worker, with the bands kept for each row a voice was heard in, so a scrub back over the Council keeps it; the grid down,
its rows are dark. The levels were set from
a real take through the receiver's band (its bands 0.2-0.75 in speech) and looked at with the look probe and a recording's
bands standing in. Live reads the bands a few decibels hotter than an export's bake (the analyzer's peak against the bake's
mean), so the voice is a little brighter live. No constellation: an AM voice has none, and drawing one would say the signal is
digital. For the author: whether a modern screen belongs on this desk at all, where it stands, its size, how bright it is
against the scope, and the voice's colors with a real voice.

**The grid, notes inside notes, and videos** (built; the user has watched the first pass): `power: off` takes every thing that runs on the grid dark at once
(`PropRig.set_power`: each make's lights and glowing parts; the radar's, the oscilloscope's and every screen's glass collapsing to
its dot; the receiver's dial lamp, its needle and its hiss), with a breaker's thunk; the phones and the tablet run on batteries.
`environment:` switches the Environment's elements by kind or kept name (`DispatchMedium.env_levels`, eased over its seconds; an
element a mark names is the other way before it; `shafts` with none chosen is the hollow's own crack). `play (terminal): NOTE`
plays ANOTHER NOTE LIVE on a screen ([NestedShow] in `show/`, loaded by path: its own Director, [member Director.nested], walking
that note's seed's scenes or its storyboard in its medium, drawn into a 4:3 viewport with a world of its own as the comic's
panels are, hearing its own song through a [member Spectrum.nested] reading that song's bake on the desk's clock; its words
over the whole frame in its Look's reveal, the credits where it names none). Never rendered ahead. Only a note shown in scenes
(Auto, Full frame, Comic) with its song made. `play (terminal): /a/video.mp4` plays a video ([ScreenFilm] in `media/`: FFmpeg
piping raw frames to a thread of its own by the film's time, its sound a WAV taken out once). The glass wakes from its dot,
plays, holds its last frame and goes down; what is not ready is the screen's static; a screen something plays on is lit with
the grid down. The voice waits for the rest of what plays where its silence ends (`DispatchScript._hold_films`), so marks after
a `play` in the same silence happen while it plays. The session ending under it (Stop) lets every inner show go
(`DispatchMedium.release`), and an inner song falls silent once the desk stops asking for it. The Targeting Individuals ending
uses all of it: the crash held, the grid down, ERROR ME FOUND on the terminal, its lyrics rolling as credits, the shafts giving
way to colored beams. For the user: the beams' looks and timing, `mono` or color on the green glass, where the camera should be
while the song plays, the credits' legibility over the desk.

**Built.** The author has not yet watched or heard it.

The patch panel's cables are soft cords (`Rope` in `geometry/`: a chain of points held to their spacing, no stretch of it bent
tighter than its least radius over a few lengths at once - about CAT-5e's - falling under gravity, settled once at build). A point
that goes into a thing is put back where it went in, keeping half its slide along the face, so a cord at rest holds its place (and
never passes out through the far side of a thin thing); a point resting on something hardly feels the bending, so nothing pulls a
cord taut, while what drapes - over a root, off an edge - rests on its peak and comes down in a long curve. The way is laid with its
corners rounded and a gentle meander (`Rope.rounded`, `Rope.meandered`), 2 cm in from the desk's back and ends. Each is laid first as a hand lays it (`DispatchSet.lay_cables`: a path round
everything standing there on a 1 cm grid, the desk's back preferred, each beside the last, over a root where it is lowest; never
round the front of what it plugs into), a little slack, then let fall: it drapes over the roots on the desk and past its far edge
and rests on the desk, out of every part by the part's own outline. Each is plugged into the side of the part its thing stands
on that faces the panel (`ports_of`, three sides tried), or laid round the panel and over the far edge, beside the panel where no root climbs off it, held where it crosses the edge and where it hangs. Gate:
`dispatch_check` (ends in a part, through nothing on the desk; controls: laid blind of the roots, laid straight).

The printer's paper is fanfold (`Fanfold`, in `geometry/`): a strip stiff along each panel and soft at each perforation, where it
leans to fold one way and then the other. It comes up out of the slot, lies back on the make's paper rest, hangs past the desk's
end and folds panel over panel onto the heap, which stands under it. One fold out and back is baked once per desk (on the build's
worker, shared by desks alike) and read at the length fed, so the creases travel along it as it prints and a panel comes down
on the heap every 38 lines; a crease leaving the slot is held flat a few centimeters, as the printer's bail holds it. Where the
paper will not lay its folds leaving the slot one way it is tried others (`PAPER_LEANS`). Each panel is one smooth surface,
creased at its edges, printed on its front and plain on its back. Gate: `fanfold_check` (it folds, it bends at its creases, it
never runs on, it shades smoothly; controls: a sheet with no creases, a back with the front's normals); look with
`tests/dispatch/dispatch_paper_probe.gd` (side on) and `dispatch_look_probe.gd --eye --aim` (the fall is in no shot).

A cable plugs into the back of what it plugs into (its own back first, then its sides, never its front nor a side the chair sees:
`PORT_FRONT`), going round to it, under the printer's paper where it arches over the desk: each mesh's part is split at the desk's
edge (`_mesh_parts`), so what hangs past the edge closes nothing on the desk under it. A port inside a root pressed against that side
is passed over. Each cable comes straight out of its socket and its port for a plug's length (`CABLE_PLUG`), lies over the cables laid
before it where they cross (never through: they keep `CABLE_GAP`), and keeps clear of the other sockets' plugs; the patch panel stands
far enough behind the terminal for them to drop out of its sockets.

The desk and the roots are props on the Props card like the rest (`DispatchDesk`, `DispatchRoots`): each a list of properties
drawn by its own number until set (`Roll`), Roll for another, and the desk's Choose… for one picked from desks drawn by other
numbers. A desk with no number kept is the one the night was made with. The roots are pictured and turned in 3D grown round the
note's own desk, the desk with them for scale (`DispatchProps.roots_away`, grown once while nothing changes them). The phones'
entry carries their colors (`DispatchSet.PHONE_FIELDS`, kept in the block's `phones`): each a color of its own drawn from a palette
(office plastics, bright, metal, pastel), or all the make's own. The terminal's and the radar's entries carry the color their glass
glows in, any color picked (`TERMINAL_FIELDS`, `RADAR_FIELDS`, kept in the block's `terminal_screen` and `radar_screen`): the glass
shows it as drawn, so the hue picked is the hue seen; the terminal's power and case lights, the light each screen throws and the
title over the opening take its hue. The receiver's entry carries its oscilloscope's color and its dial lamp's (`RECEIVER_FIELDS`,
kept in the block's `receiver_glow`), the scope shown as drawn as the other two are. The Props card's heading is "In the scene".

Looked at (rendered with `tests/dispatch/dispatch_look_probe.gd` on a steady rehearsed voice, frames read by eye): the
home view from the chair, every camera spot settled, the record and the target's log on the terminal (legible close up),
the council's typed question, a text on its phone, a phone dialing and one on hold, a ring, the radar's ping, the receiver in a storm, the printer, the TV showing this desk live from behind the chair, the roots from
the chair looking up and from outside the hollow.

Measured: the episode's 3,329 spoken words line up with the voice's plan word for word; every voice is routed through the
right phone; 90 actions, about three minutes of rests; the desk's build is about half a second (most of it the roots), so
it is made on a worker while the show waits, as the table's is; a frame's pose about 1.2 ms; a live plan made again about
20 ms a sentence.

Open:

- The author's eye: the camera's pace (a lead of 1.1 s and springs of 1.7 s, every look held at least 10 s, a ping 12 to 16 s), the props' look, the roots, the lair's light, the censor's box
  size, waver and shard darkness, and the gain, bell and lamp marks.
- The intro's pace with the real voice, by ear and eye: the walks' length is the prose's.
- A real voice and an export; the seven pictures painted from the Pictures card.
- The paper heap on the floor reads only dimly; the printed lines on the paper are small. The paper's fold and the heap are in
  no shot the desk turns to.
- Agents dressing the desk from the note's `desk:` block (phase two).
- A live plan made again in about 20 ms a sentence could be made cheaper (the letter's indexing).
- Ten camera looks are still seen for under 2.5 s, each cut by the next thing the script does a few seconds later (a ping,
  then a picture landing; a print, then a call). They are the script's beats, which spacing them would give room.

How it is built:

- **The desk is crowded, and the roots go round it by a grid search** (`AStarGrid2D`, 2 cm cells, what stands there and a
  margin solid). Free steering got stuck within centimeters. Its growth runs along its crawl from the desk's edge.
- **A root on the desk goes as a root goes, not by the shortest way** (`DispatchRoots._desk_root`). The ground is dearer the
  nearer a thing it is, dearer where another root lies, and hard in patches of each root's own, so the cheapest way keeps to
  the open room and meanders (`_weigh`); the way is eased and sways within the room it has to spare (`_eased`). It comes on
  and goes only where there is room for a root (4 cm from its middle to a thing: never squeezed between the phones and where
  one is laid open). It wants a reach of 0.45 to 0.85 m across the top: of the ways to the near edge no longer than that
  allows it takes the one nearest it, goes over the edge and hangs 14 to 34 cm down the desk's front; shut in among the
  things, or with every way to the edge too long, it ends on the top at its reach (`_leaving`). It is as thick as its way lets
  it be - nowhere thicker than the room round it less 8 mm, thinning toward a narrow place over a length and never thicker
  again past it (`_fitted`) - so its skin never meets what stands there. Gate: `dispatch_check` `_roots_clear` (none nearer a
  thing than it is thick, the control grown knowing nothing of what stands there; a moderate reach; over the edge clear of
  the front, or an end on the top). The open room in front of the phones' rows is where a phone on hold is laid open
  (`held_rect`, three places): no root lies there.
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
  chair; the chart, the pencil cup, the stamp, the tracker). EVERYTHING IS WHERE ITS MESHES ARE: a thing is packed by its
  own meshes' outlines turned as it stands (`bounds`, `_parts_of`), never a typed footprint; nothing packed stands between
  the chair and a label, dial, screen or the clock's cards, nor in a face's own close-up (`_sights`, `hidden`: lines from the
  eye through each mesh's box); what the camera reads is packed first, and the stamp and pencil cup are left off a desk with
  no room. The satellite's monitor is on an arm low over the printer and the security monitor, clamped to the back edge
  where it is free, turned to the chair (`_satellite`). Everything the medium and the roots read follows it (`at_of`,
  `desk_at`, `held_rect`, the camera's spots). `dispatch_check` holds it on forty desks. The glossy desk top (polish 0.22, an old desk) and the lamp's soft shadow
  (blur 6, never empty of its own light: `shadow_opacity` 0.62, the room's bounce) avoid a crisp pale-blue disc under the
  mug that the screens' cool glows (which cast no shadows) otherwise light. The coffee ring is a thin opaque, matte rim with
  an older arc beside it, a little off the mug's foot (a translucent disc read as glass, and a `Decal` drew its footprint
  pale).
- **The mug is drunk from**: upright all the way, lifted gently out of its ring and carried on an arc to just under the eye
  (`DispatchMedium.mug_way`, `MUG_MOUTH` in the camera's own frame, so it is out of the picture whichever way the camera
  looks), coming up to the mouth from a little below and nearer the desk, lifted only as high as clears what stands under its
  way and never higher than the mouth; held for the sip, set back down as gently. The camera stays on the whole desk, so the
  mug is seen to rise and leave past the lower edge.
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
- **A voice with no phone comes in on the receiver** (`DispatchScript.on_receiver`): a typed block after its cue is said in
  that voice, `heard: receiver` (VoiceFX's shortwave row: a narrow band, a slow selective fade, a little hiss and crackle in
  the voice, no squelch), the room taking it down. The receiver opens under it on the storm it last opened on, carried
  straight on from a static that ends within `RECEIVER_JOIN` of it and open `RECEIVER_TAIL` past its last word
  (`DispatchMedium._build_receiver`, one stretch of the plan's sound); the storm is brought down to `DispatchSounds.UNDER`
  under the words, and the needle and the scope's trace swell with each word. A paragraph by such a voice is still heard as
  `_heard` says (a voice in a caller's room). Open: the author's ear on the balance of voice and static.
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

- **Held long enough to be seen**: `LOOK_LEAST` (10 s) from its start, unless something else begins first, and the hold never
  runs past what begins next, so nothing is gone back to. A ping holds the radar `PING_HOLD` (12 s) at least, on to the end
  of the sentence said over it if that ends within `PING_HOLD_MOST` (16 s; `DispatchScript.sentence_ends`, since the spoken
  words have lost their punctuation), then lets go in a second.
- **Never left only to come straight back**: the camera stays on what it was on rather than ease home for less than
  `AWAY_LEAST` (12 s) before it turns again (a walk's look runs into the ping where he arrives, a ping's into the walk after
  it), unless what comes next is the whole desk.
- **No swerve**: a look cut before the camera could get there (`GLANCE_LEAST`, 3 s - a phone hung up as the radar pings)
  is not taken, nor a short turn away between two looks at the same thing - but words to be read are always looked at
  (`TO_READ`: a typed word is never captioned).
- **The mug, drunk from**: brought up over 2.8 s, held at the mouth 3 s for the sip, set down over 2.4 s; the voice waits
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
- **The radar writes coordinates, not a place, beside the blip**: a real scope tags a track with data (who it is, where it is) and
  keeps place names on a map under the sweep. Beside the blip are his latitude and longitude, two lines that change as the sweep
  paints him (`DispatchScreens.coordinates`, from 0, 0 at the scope's middle, so never a real place), hidden by the censor like
  the terminal's words (`radar_redactions`; a run may name its own screen: `glass`, `curve`, `size`, `line`). The place they
  come to is held in a readout at the scope's lower right (`_readout`: parted at a comma, wrapped, on a dark plate, brighter
  for a moment after a ping), so the coordinates read as translated into a place.

Looked at: the censor in the gate's render (`tests/run_quiet.sh -- tests/dispatch/dispatch_redact_check.gd --png`). The radar's
readout and its covered coordinates are not yet seen by eye.

### The revised night's marks: the gain, the bell, the lamp

Three marks from the revised script (rift's `MEDIUM.md`):

- **`<!-- gain: N -->`**: the radar's left knob is the gain (`DispatchSet.gain_knob`), its pointer at 3 when the night
  begins and its scale, one to ten, printed round it (`DispatchScreens` `gain` face). The mark turns it a step at a time, a
  click each, and the voice waits while it turns and a beat (`DispatchScript.GAIN_*`). Above 3 the scope paints clutter
  (`DispatchMedium.clutter_at`): up to 40 dim, unnamed blips round where the target was when it went up, laid as the rooms
  of one building turned its own way with him off its middle, nearest first, so each step paints the next nearest; 33 at
  nine. From nine (`CHAIR_GAIN`) one more is painted on the desk itself, just off its mark on the chair's side
  (`CHAIR_AT`): whoever sits there. Each is painted only once the sweep passes it after the knob reached it, a little off
  each round; one in four round him drifts. Turned back down, they fade over a sweep or two and are not painted again. The camera stays on the radar after
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

### The night in pieces: one terminal, bearings, fades, the tablet, clips

The revised night (rift's `MEDIUM.md`, its design and what differs from it) is told in pieces and leans on seven marks:

- **The terminal is one program** (`DispatchTerminal`): a fixed screen - the title bar in inverse with the panel's name,
  its second line, sixteen rows of body that alone scroll, the keys spread across, the command line - never a scrolling
  shell. A ` ```terminal ` block is its lines in order: commands typed on the command line, panels kept by id (`panel: id =
  NAME | LEFT | RIGHT`) that a key or `> open id` brings back as they last stood, `type:` lines typed and said behind the
  keys (`type (Name):` in that voice), `read:` lines the other side types (the target on the mirror) read aloud the same
  way and never printed or struck, `key:` lines typed and never said, `show:`, `set:` (a row changed in place, what
  differs backspaced and typed - or, written straight after the panel is come back to, there as the panel is drawn: it
  comes back as it now stands), `wait:`, `alert:` (its beep), `crash:` (the program dies: the glass the screen's color edge to
  edge, its words in black at the middle, until a panel is drawn or the screen wakes; `crash (Name):` that voice says them
  over it, the receiver opened under them with the camera kept on the glass), `print`, `strike`, `clear`, `{N}` holding a line part-drawn,
  any desk mark at its point. The note's `terminal:` block holds the title, the width and the keys every panel shares. The
  parse simulates the glass through the whole note, so every action at the terminal carries the glass it starts from and
  the medium plays its own steps at a moment (`DispatchMedium.terminal_at`). A panel is read before the next step - a new
  one by its words, one come back to a glance - unless a `wait:` says how long; a typed line straight after it waits for the
  read too. Lines drawn onto a panel already up (`show:`, a body line) are read the same way before the next key or command,
  silently, at a reader's pace (`READ_DRAWN`, at most `READ_DRAWN_MOST`): an answer is taken in before it is answered. SAID LINES IN A ROW ARE ONE PASSAGE, AS A LETTER'S PEN WRITES ON: `type:` (or `read:`) lines one straight after
  another in one voice are typed on over each line's end, the keys one to three words ahead of the voice at the evenest
  pace that band allows (`PenPace.taut`, as the desk's pen), never rushing a short word or crawling through a pause, and
  struck unevenly within a word as a hand strikes them (`DispatchScript.hand_times`); the voice reads them through; a page the voice reads is written this way, never
  `key:` lines with the words said after the block - and where it is, the block's last `key:` lines that the paragraph
  straight after opens by saying are typed ahead of those words all the same (`DispatchScript.said_keys`: matched in order,
  a word left out or a clause put in allowed, what is typed past them carried on; a picture between leaves them where they
  are written). A typed line naming an option on the panel (`type: [D]` under `[D] ALL OF THE ABOVE`) chooses it: thought over
  past the read (`CHOICE_THINK`), typed at the prompt, that row shown in inverse (never a new line), and the camera held on it
  after (`CHOICE_HOLD`, a `look` at the terminal). `select: LABEL` moves a bar in the same inverse over the panel's cells
  with the arrow keys (a row's cells parted by three spaces, read down each column), a press an item, and Enter opens the
  panel written next: an item of a list is opened as a panel of its own (the agents on his screen, then agent 3's
  conversation, its tail on the glass).
- **The camera stays on the glass** after a block or a typed line while the voice talks of what is up
  (`DispatchMedium._glass_hold`: the panel's words read, `GLASS_LEAST` to `GLASS_MOST`, to the end of the sentence), and on
  however long the voice goes on, through to what comes next (`GLASS_LINGER` is unbounded): never pulled back to the whole
  desk for nothing. A script takes it home sooner with `<!-- look: home -->`.
- **A ping is where a radar reports it**: bearing clockwise from the scope's top, range in the desk's range rings
  (`rings:`, the scope's edge the last; `DispatchMedium.scope_at`). A place named again bare is the same spot; a place
  never given numbers is laid out from the words, as before, and warned of.
- **Fades and the clock**: the picture goes down to black and comes back up (`fade_at`, the environment's brightness and
  the pictures over the frame); what is marked in the black happens at once, unseen (no rest, no look); a fade up with a
  time comes up on the flip clock (`DispatchSet` builds it where the script uses one), its cards turned over to the time
  (`DispatchScreens` cuts each card's halves from one digit atlas), held a beat, then the camera eases to the desk; the clock
  runs a minute a minute. The camera is on the clock in the black. A note may open on a fade up: its title stands over the blurred desk as any show's does, the picture goes down to black as the title goes, and the night comes up on the clock. The first
  ping after it has no track across the black. A typed line opening on a time far off the clock (by a steady voice) is
  warned of. A call's timer counts the night's own time (`_night_at`): a call held across a black has been on the hours the
  clock jumped, past midnight too, and a phone shows its hours once it has run one (`DispatchScreens.call_time`).
- **A reading started mid-way** places what came before it far in the past: what counts time from one of those - the
  clock from a fade, a call's timer from its first move, the tablet's lock from when it was laid down - counts from where it
  fell on the reading (`_on_reading`), so a scrub shows what a whole reading would.
- **The tablet** (built where the script uses one) is the tablet medium's own at a real tablet's size - its rounded slab
  and glass (`TabletMedium.rounded_slab`, `SCREEN_SHADER`), portrait, its screen 1200 by 1600 - lying on the desk; it is
  lifted and held low over the desk's near edge, tipped toward the chair, the camera looking down into it
  (`DispatchSet.tablet_held_xf`), and laid back down unhurried, its screen left lit on the page it was left on until it
  locks itself half a minute on (dimmed for the last seconds; `TABLET_LOCK`). The camera leaves where it was held a second
  into the laying down (`TABLET_LEAVE`): for the whole desk, or straight on to what begins within another second. It is carried as a hand would, never over
  what it only passes beside (`DispatchMedium.tablet_route`: the straightest way that clears what stands under it, by each
  thing's own outline, no higher than the hand holds it; round by the desk's near side, or drawn out toward the chair
  first, before it is lifted any higher). Its screen is the tablet medium's: the pages `TabletScript` reads
  from the fences as one source, set by `TabletPage`, under the one browser every tablet draws (`TabletChrome`: the status
  bar with the desk's time, the tabs, back, the padlocked address bar, the load line, a blank tab's page, the keyboard).
  A page is held to be looked at once it loads; shown and never said, it scrolls to what the room reads off it (a phrase
  found there, never one stray word) - and where the room reads on from the page, word after word, those words are lit as
  the tablet medium lights what its voice reads (`_page_follow`, `_page_lit`) - else eases down at a skim's pace, never past
  where its writing ends. THE DESK'S PAGES DRAW NOTHING NOBODY WROTE (`TabletPage.placeholders` off): no squiggles, no
  padding stories; a site's menu row only where its first page names one (`nav:`), a footer of its name to the screen's foot. `<!-- player -->` is a picture slot that `live: tablet` fills with
  the desk seen from behind the chair; the tablet in that picture shows the same picture. `replay: tablet | words` says the
  room's earlier words again through the tablet's speaker (`heard: tablet`).
- **The tablet is browsed by the tablet medium's own walk** (`DispatchScript.browsing`): the page fences, and each `back`
  and `new tab` while it is up, are written out as a tablet chapter's marks and read by `TabletScript`, whose actions say
  which mark made each (`mark`, `tab`, `behind`, `again`) - one inference of how a page is reached, for both. So a page the
  one up links to is found and tapped; any other address is typed into the bar; a search is typed into the box of a search
  engine's page (a page that is little but its name) at the tablet medium's pace, else into the bar, its results the engine's
  last used; `back` taps the arrow and the page before in that tab comes back scrolled where it was left (the room may talk
  over it, and the next link is tapped from it); `new tab` taps the plus, a blank tab beside the others taking the next
  address; the address of the page up again is that page loaded again, where it was left. The keyboard is up while anything
  is typed. `reply: tablet` types the room's next words into the message box at the foot of the page up as they are said
  and sends them (an action `post`); a page at an address that takes a reply has the box each time it comes up. What does
  nothing is warned of: `back` or `new tab` with the tablet down, `back` with nothing behind it, a reply with no page up.
  Not built on it: a tab switched back to, `landscape`, `notify:`, `redirect`.
- **A forum on a page** (`<!-- post: name | rank · posts | when -->`, `> ` quotes, `TabletPage._post_begin`): each post a card,
  the author's column (an avatar drawn from the name, the name, what the forum says of them) beside its body, its pictures
  attachments; a board index or a thread list is a table (`<!-- pager: N -->` above and below it: Back, the pages to N, Next), a cell's detail after `<br>` set smaller, its columns of counts
  centered, its rows banded. `tests/dispatch/tablet_pages_probe.gd` draws every page of a note whole. Open: the author's eye.
- **A live chat on a page** (`<!-- chat: N -->` ... `<!-- /chat -->` in a page fence, `TabletScript.CHAT`): the page fits the
  screen and never scrolls (`TabletPage._live`): its picture (a LIVE badge, no taller than a third of the screen), what is
  written, the paid messages, a stream of the bank's messages under names drawn at random, about N a second (a pure function
  of show time and the address, `TabletPage.chat_at`), and the message box at the foot. A reply sent on it stands at the
  top of the paid messages under the chat's `me:` and `tip:`, lit. Open: the author's eye on it at the desk.
- **Clips on a screen**: `video (tv): file | words` is a picture whose slot on the Pictures card takes a clip: Generate
  paints it as a short loop (one sheet of six cells in the note's look, cut into frames at 8 fps: `Illustrations._keep_loop`),
  Import… decodes a video into frames (`Illustrations.import_clip`, FFmpeg), and the screen plays them by show time,
  looping under its snow - the screen's static until it has one.
- **The receiver**: a voice with no phone on the desk is heard on it, typed or said, unless a phone is at the ear (then it
  is somebody in the caller's room); `<!-- heard: band -->` after a cue says outright.
- **The note as written**: a synced note's words reach the card and the reading without their frontmatter, where the
  `desk:` and `terminal:` blocks are. The format reads the file's (`DocSource.head`), checks the whole note, and hands it in
  the document (`head`); the medium puts it back on the words (`DispatchMedium.whole`). The card lists four problems and
  logs them all.

Looked at (the look probe on the fixture, seed 3): a panel on the glass with its title bar and command line, the clock at
23:40 close up and from the chair, the forum page held up with the radar behind it, the player showing the desk live.
Run on the episode with a steady voice: no script error, every fade up on its clock, every page reached as written, the
night about 49 minutes.

Open: the author's eye and ear on the night in pieces - the glass's pace and the camera's hold on it, the clock shot, the
tablet's size, its pages' scroll and its browsing (the pace of a search typed into its box, the keyboard over the page,
the message box), the dog clip once imported (its sound is kept and not played yet).

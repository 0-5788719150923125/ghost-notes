# Studio

One of Table's formats: a table show's episode played as raw footage from a creator's chair. A camera stands in the middle of the
frame looking back at the viewer, its flip screen turned toward them; between them a giant fluffy microphone; and the things the
creator's hands work lie on the desk out of shot until the hands nobody sees bring them up into it. Table's agents make each episode from the note's brief, as they do
at the card table and the desk; the reader writes what the hands do among its words. First series: "ASMR for Influencers"
(`~/repos/rift/animations/asmr-for-influencers.md`, the brief; a hand-written pilot in its folder).

THE SOUND IS THE SHOW: every sound a thing makes is made by the motion that makes it - the same lanes move the prop and drive
the synthesizer - and is heard from where it happens around the microphone.

## Status

Built, each piece with its gate: the format (`studio` in `Medium.REGISTRY`, Table's like the desk, `own_set`, `own_work`), what its
reader is told (`rules/table/studio.yaml`, every word from `StudioActs`' and `HeadPlan`'s rows) and keeps in a passage
(`reader_marks`), a passage handed back told why (`reader_check`), the voice's rests for its acts (`voiced`), its things and its
sounds on the Pipeline card (`StudioFormat`), its things on the Props card (`StudioProps`), each designed by an agent (`RoleDesign`),
a part's `fur` drawn as strands (`FurStrands`, `prop_fur.gdshader`, `PropRig.touch`), the head performed from the show's own
phrases (next/head.md: `HeadPlan`, `HeadBank`, `HeadDesign`, `HeadMarks`; the voice placed by it and the eye moving with it), the chair on the Camera card (`Cameras` `creator`), `Gesture` in
`motion/`, and the sound host (`hosts/music/contact.py`).

Measured on the pilot's render (`tests/studio/studio_probe.gd --sound`): every act's sound runs its act's length where it was
placed; a rub on the left is 14.5 dB louder in the left ear and one on the right mirrors it; `around` swings the balance from
+14 to -14 and back to +13 dB; `faster` brightens (1.1 to 1.4 kHz) and `slower` darkens; a cup is deep (about 750 Hz) and in
both ears; brushing the lens is barely heard. All 24 of the pilot's sounds are made in about 30 s, two at a time.

Table's reader writes the hands' acts itself (`own_work` on the Medium row): no puppeteer blocks the work, and each passage's
reader is told its beat's planned work and about how many seconds of sound to write for it.

Known limits: no make ships with the app - a note's studio stands empty until Generate has its things designed (the probe stands the
fixtures in `tests/fixtures/studio/`); a close voice is not hushed yet (the near plan stands aside for the head, and the hush with it).

Open for the user: the first episode Table makes, by ear (the fur first) and by eye; the things its agents design; the head's moves
by eye and ear; the fur's color.

## The design

### The set (`StudioSet`)

- The viewer sits in the creator's chair (the stage camera at eye height, its Sway the Camera card's `creator`). The camera on its tripod, centered, its lens toward the viewer,
  inside a small (12-inch) ring light behind it; the microphone on a short stand in the lower middle, its fur windscreen the size of a head.
- The things lie on a side table beside the chair, below every view (the frame wherever the head goes, the flip screen's): the
  blocks stacked, the brush on its side. An act brings one up into the frame and lays it back (held, it is never still:
  `Gesture.idle`).
- Black round all of it; behind the chair a green screen on its stands, which only the flip screen sees - its background behind
  nobody.
- Every thing is a prop playing a `PropMakes` role, `designed`: no make ships with the app. An agent designs each for the note
  (`RoleDesign`, rules/table/prop_designer.yaml), told what the role is, the show, the things already designed and what the studio
  works on any make (the role's `needs`: the camera's `screen` face and `lens` point, the microphone's `windscreen` with `fur` and
  its `capsule`, the ring light's lit `ring`, the brush's `tip`...), checked on every make (`PropMakes.missing`) and asked once more
  told what it lacked. What it makes is held in the library as a draft (kept by a person's Keep in its 3D view), or added as a
  version to the prop of its name. The roles: `camera`, `tripod`, `ring_light`, `microphone`, `block` (two of it), `brush`,
  `backdrop`. A make is placed by its own points and measured (the brush's reach, the block's size), so any make is worked alike.
- Its things are the Pipeline's: a row each, Generate designing the ones not designed, ⟳ another kind (the one before stays in
  the library); and the Props card's (`StudioProps`: Choose… any kept make that has what the studio works, Refine… in 3D into
  versions the studio follows). The choice is the note's, in the Medium block's `makes`; the playing studio stands again with it.
- The studio sets itself: no set dresser, no table step and nothing painted for it (`own_work`).
- WHERE A THING STANDS IS THE SCENE'S, NEVER A VERSION OF ITS PROP: the set stands each by its relations (the camera by its lens, the
  tripod's head under the camera's foot - its meshes' lowest - as the studio stands it, the ring light by its middle, the microphone
  by its capsule), then moves each alone as the note places it (a camera floating off its tripod is brought down onto it)
  (`StudioSet.PLACE_FIELDS`: across, up, toward you, turn, tip, lean, size; the Medium block's `places`), every relation and the
  sound's capsule worked out from where the moved makes really are. A place is set by hand on the thing's Props card entry (Studio's
  place puts it back), or by Refine… in its 3D view, which is handed the studio it stands in (`StudioProps.scene_of`): a report in
  numbers and pictures (`StudioScene`: where the show is recorded from - the viewer's eye, the creator's head and how far the show
  moves it, and the camera's lens, the flip screen's picture - with each lens; every thing's box and what of it each camera sees,
  where it falls in each frame and how much of it it fills; the thing measured against the rest and its relations; from the
  viewer's eye, its side, above it and through the lens), answering a place (no version), a changed prop (a version) or both, and moving the
  studio's other things with it where the ask takes them (the tripod with the camera: `places`, by name) - looked at again once
  placed and put right once. A make an agent designs is looked at so before it is used (`StudioFormat._check_design`).
  `tests/studio/studio_probe.gd --scene ROLE` writes what such an agent sees. A place changed while the show is paused stands at once
  (`tests/studio/studio_live_check.gd`).
- A PAUSED SHOW IS LOOKED OVER (`StageLook` in `show/`, `FreeLook` in `motion/`, any medium answering `look_by`): a drag on the stage
  turns the eye about what it looks at, the wheel draws it in or out; once the show plays the eye eases back to the show's own,
  slowly, its own roll kept - never in a render.
- A role's needs are checked strictly of a make designed or refined for it (`PropMakes.missing(..., true)`): a part whose need names a
  `light` carries one, one that glows is lit (the ring light's face: a flat `ring` with a `width`, white and lit, a spot shining
  forward); a refine is told the role's needs and a version lacking one is put right once, told what. A make standing in the studio
  is held only to what places it (`fits`), so it can be opened and refined.
- A point is read in the thing's own space for a designed make (`PropRig.point_in_thing`), as the prop language writes it; the
  shipped makes and the table's work read a point in its part's node (`PropRig.point`) - one meaning for both is open.

### The flip screen

- A second camera at the camera prop's `lens` point renders the same world into a SubViewport shown on the flip screen's face,
  mirrored as a selfie screen is. The camera prop is off its layer (it never sees itself).
- Over the picture: REC, the running timecode of the take (raw footage: it never stops), and the two audio meters, fed by the
  act sounds' own levels left and right - the side of the microphone a sound is on, seen.

### Fur (props)

- A part may carry `fur` (`{length, density, curl, droop, color, tip}`): real strands over its own material, which is the
  undercoat (`FurStrands`, `prop_fur.gdshader`, gate `fur_strands_check`). Roots are strewn over its triangles by area in a seeded
  draw (the same prop, the same fur: an export plays what the live show did), at most `FurStrands.MOST` a part, kept in a float
  texture. One strip of placeholder vertices, a ribbon a strand, hangs in a one-instance MultiMesh; the vertex shader lays each strand
  out from VERTEX_ID: rising, parting at the part's crown (its top, middle of its width), falling away evenly on every side, drawn down
  by its weight, in loose waves, gathered by its tip into locks, each its own length and shade.
- Each strand faces the camera and tapers, never narrower than a pixel at its depth, and is opaque: a hair finer than a pixel stays
  one whole line the stage's MSAA smooths, never a run of dots, at any resolution. Lit along the strand (Kajiya-Kay highlights),
  darker toward the root, the tips glowing when lit from behind.
- A furred make is touched through its rig (`PropRig.touch`): a point, a push and a depth. Where it is touched the strands are laid
  flat along the push and pressed toward the skin, parted round the edge, with a sheen, springing back as it lets go - an invisible
  hand seen by what it moves.

### Human motion (`Gesture`, motion/)

Every move a pure function of time from a seeded plan, never a straight line or a constant speed:

- a reach is minimum-jerk (Flash and Hogan 1985) along a bowed path, a quick one ending short and corrected by a small second move
  (Meyer et al. 1988);
- a rub is strokes: each half-cycle minimum-jerk between its ends (a bell of speed, still at each turn), out and back on different
  arcs (a thin lens, never a line), the forward stroke pressed harder and taking a little longer; each cycle's period, length
  and arc drawn on from the last (an AR(1) drift, about 5% spread); a circle is an ellipse traced at a varying rate, which keeps
  the two-thirds power law (Lacquaniti et al. 1983);
- a pace that changes (`faster`, `slower`) moves the cycles' rate and with it the speed and the force;
- the assumptions break down now and then, seeded: a hesitation mid-stroke, a re-grip (lifted and set down a little elsewhere),
  a short stumbling cycle;
- taps come in groups (rolls of two to five, gaps between), each lifted slowly and struck accelerating, the first of a group
  hardest;
- a held thing drifts (slow incommensurate waves, a breath) and trembles (8-12 Hz, a fraction of a millimeter; signal-dependent:
  more while it moves).

### Acts (`StudioActs`, `StudioScript`)

A mark on a line of its own, `<!-- VERB: words -->`, its words in any order: a thing, a side, seconds, a pace, a pressure, a
pattern, `under`. Table's reader writes them among its words, told every word they may use (`rules/table/studio.yaml`, filled from
the rows), and its passages keep them (`reader_marks`). The voice waits out an act's seconds - a quiet rest where it is written
(`voiced`) - unless it says `under` (the words after it are said over it).

- verbs: `rub` (fingertips), `brush` (the powder brush), `scratch` (nails), `tap`, `scrape` (block on block), `knock` (blocks
  struck together), `cup` (both hands round the windscreen);
- things: `fur`, `lens`, `camera`, `mic`, `blocks`;
- sides, round the microphone: `left`, `right`, `front` (toward the camera), `back` (toward the viewer), `top`, the four
  between, `around` (circling it), `left to right`, `right to left`;
- pace `slow` `quick` `faster` `slower`; pressure `soft` `firm`; pattern `circles` `long` `short`.

An act is a pure function of its own time: where each thing is, and its CONTACT LANES - for each contact, where it is round the
microphone (meters, the listener's frame), how fast it slides (m/s) and how hard it presses (N), and each hit with its speed.
Placed in the rest the voice leaves for it (`ReadingFollower.place`).

### The sound (`hosts/music/contact.py`, `StudioSounds`)

Each act's lanes go to the music host, which makes the act's sound at 44.1 kHz stereo; kept by the hash of what it was asked and
of the host's own code. They are the Pipeline's: the Studio's rows on the Medium card list a row an act of the episode up now,
Generate makes those not made, and a row's ⟳ makes another take of its act (another performance, its motion and its sound; the
take before kept; `takes` in the Medium's block). The playing studio makes a sound still missing as it is wanted, and holds the show
for it.
Synthesized from the motion (no samples, no audio model):

- **fur**: a pressure rumble where the fur is pushed toward the capsule (20-150 Hz, from the change in force), a swish whose
  band rises with speed, and fiber crackle - micro-clicks at a rate set by speed, heavy-tailed in loudness, brighter faster;
- **brush**: bristle tips catching and slipping (a granular stream at bristles x speed), an airy swish;
- **scratch**: nails - dense, bright crackle and a hard-contact scrape;
- **scrape** (van den Doel, Kry and Pai 2001): a fractal surface read at the sliding speed, so its grain sounds higher as it goes
  faster; stick-slip creaks where it is slow and pressed hard; both blocks' modes ringing, damped by the hands;
- **hits**: a contact pulse as long as the materials are soft (a fingertip a few ms, a nail or wood on wood a fraction), its
  spectrum falling past one over that; the struck body's modes (a bar's, a shell's, a tube's) and a deep body thud;
- **where it is heard**: a spherical head at the capsule, turned as the viewer is (screen left is the left ear; front is toward
  the camera). Each ear's own distance (the near-field level difference close to one ear), the far ear's head shadow (Brown and
  Duda 1998, one pole and one zero), the delay round the head as a moving fractional delay (its Doppler free), darker from
  behind, a pinna notch that moves with height, and the cardioid's proximity bass growing as the sound comes close;
- the microphone's color (a little presence and air), a small dry room, a soft limiter. Levels are absolute (never normalized
  per act): a thing far from the microphone is quiet.

The footage ends on its last sound: a beat after the last word, or after an act the hands go on with past it, picture and sound
go down together over the outro.

`StudioSounds` plays the act sounds at their placed times, mixed with a low room tone (silence is never digital), begun again
where the show jumps: a pure function of show time, so a render hears what the live show heard. A WAV is read on a worker; the
host runs on its own process.

## Gates

- `hosts/music/test_contact.py` - faster is brighter and louder; harder is louder; the left side is louder and earlier in the
  left ear; behind is darker than in front; a pure function of its lanes; no clicks at an act's edges; nothing clips.
- `tests/motion/gesture_check.gd` - no stroke is a straight line or a constant speed; speed is still at a turn; periods spread
  but stay near their pace; a plan is a pure function of its seed; `faster` ends quicker than it began.
- `tests/studio/studio_script_check.gd` - marks read into acts, rests and words; `under` holds no rest; an unknown word is named;
  a reader's act marks kept in its passage and every word told to it; the studio's own table built; a take is that act's alone.
- `tests/studio/studio_probe.gd` - the set rendered (a look, never a gate).

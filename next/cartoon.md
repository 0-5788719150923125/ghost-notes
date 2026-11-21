# Cartoon: a show made from drawings

A cartoon is a note whose show is puppets made from their makers' own drawings, on painted sets, doing what a storyboard says - silent
for now, mouths moving as they talk. The component is **Cartoon** (`src/cartoon/`); the puppets, their verbs and the marks drawn over
them are the stage's (`src/stage/`: `PuppetRig`, `PuppetBody`, `CartoonFx`, the verbs in `Actions`); the drawing is made a puppet by
`hosts/puppet/rig.py`.

## Status

- **Built:** the MODEL SHEET (`PuppetSheet`: each character drawn again by an image model from its maker's drawing - facing us with
  its mouth closed, open and wide, in profile and talking in profile, from behind, scared, angry, laughing - each cut, set onto the
  drawing it was painted from, and rigged; the puppet swaps between them); the note's own Play (a silent track as long as its
  storyboard, `CartoonCard.playable`: Play, scrub, the bookends and Export run on it); ACTION drawings (a stride swapped with the
  profile at every step, a wind-up, a reeling a blow brings); a character nobody drew (`describe`: painted from words in the cast's
  style, a sheet of only the drawings it names, `drawings`); silhouettes (`shade`); a check that refuses puppets started on each
  other; a film told `loop` on the desk (`play (tv, loop): NOTE`: round and round under the narration until its screen is put to
  something else); scrubbing a written show (the Director re-walks a storyboard to wherever the playhead is moved,
  `Spectrum.sought`); cartoon shots framed still and no fade at either end (`CartoonProducer.settled`: `shot: centered`, `behavior:
  static`, `bookend: false`), no holds on a cartoon note; a puppet with a sheet bends a third as far, its poses shown as drawings
  (`PuppetBody.POSE_DRAWINGS`); a character in its own setting (`rigid`, `asks`, `align: width`: the sleeper in their bed, asleep,
  terrified and cartoon-dead); the puppet (a drawing cut off its paper, meshed
  along its outline, weighted to a skeleton through its own silhouette, drawn by the engine's 2D skinning), its life (springs on every bone, breath, sway, blinks, a gait read off its speed), the verbs
  `move`, `pose`, `talk`, `face`, `strike`, `hit`, `hop`, `shake`, `fx`, the backdrop, the marks (a star burst, dizzy stars, dust,
  sweat, an alarm, speed lines); the host's `cut` and `build` with their looks; the rigger's tools (`RiggerTools`); the producer
  (rig, paint, direct, each an agent job, a storyboard checked and sent back once); the Cartoon card and its Pipeline rows;
  `--cartoon <note>`; a silent note played on a screen (`ScreenPlays`, `NestedShow`, `Spectrum.hear_silence`).
- **In Targeting Individuals:** "Demons of Modern Life" loops on the desk's TV in the hypnosis section, in place of the empty stage
  picture (`play (tv, loop)`), until the section's `off: tv`.
- **Made with it:** the note "Demons of Modern Life" (three demons from their artist's drawings, each a model sheet of nine drawings
  painted by Codex and rigged by the rigger, a bedroom painted in their style, a 30-second storyboard written by the director agent
  with turns and moods). It goes into Targeting Individuals only once it is judged good
  enough on its own, and then on the desk's TV in place of the empty stage picture (`play (tv): Demons of Modern Life`).
- **Looked at:** each rig's look (the bones, what each moves, the puppet bent); the three sheets side by side (likeness held across
  all nine drawings); frames of each verb and of the whole storyboard through `tests/stage/cartoon_look_probe.gd` (the nested show, as
  the desk plays it); the note opened on main and played (`tests/cartoon/cartoon_app_probe.gd`).
- **The user's to judge:** the cartoon by eye; how the rigs move; the director's comedy; whether it is good enough for the desk's TV.

## The model sheet

A puppet bent from one drawing reads as a cardboard cutout: it turns by mirroring and talks by splitting its face. So a character is
drawn again, by the image model, as a cartoon's model sheet is drawn (`PuppetSheet.REGISTRY`, a row a drawing, its `ask` the painter's
words): the front first, from the maker's drawing; every other from the front (or the profile), the maker's drawing handed in beside
it for the style. Each is painted on plain paper (rules/cartoon/sheet.yaml), cut, and set onto the drawing it was painted from at its
height with its feet on theirs (`rig.py align`), so a talking mouth swapped in does not jump.

The rigger rigs the front and the profile; their other mouths are built on the same skeleton (no jaw: they talk by drawing); the back
and the moods are held whole on one bone (`rigid`). `sheet.json` lists what was made. As it plays the puppet SWAPS: its profile while
it goes across (mirrored going left; a drawing facing us is never mirrored), the view `face` latched otherwise, the mouth its syllables
call for held at least two frames at twelve a second, the mood `feel` set. Bending stays for the small life between drawings: breath,
a gait's bob, a blow's spin and squash.

## How a drawing becomes a puppet

1. **Cut.** The paper is the color round the drawing's edge; the largest thing on it is the figure. Paper the figure closes round is
   numbered: a gap (between a limb and the body) is cut, a drawn white thing (an eye, a page) kept - by size, and by whether anything
   is drawn inside it; the rigger says otherwise where it is wrong. Lettering and marks drawn round the figure are erased, or one
   color inside an outline (a flash round a hammer).
2. **Skeleton.** The rigger places bones on the cut over a pixel grid: one root, a `head`, chains of `arm`, `hand`, `leg`, and `loose`
   parts that trail and wiggle. Roles are what verbs read (a walk swings legs, a strike swings the arm nearer its victim).
3. **Jaw, eyes, behind, parts.** The jaw is cut out of the face onto a bone at its hinge; the hole it leaves is the mouth, painted
   dark into the body, so it moves with the face and shows only as the jaw drops. Each eye gets a bone (it swells when struck) and a
   lid of the skin round it. A part of one color behind the figure (an aura) is a layer of its own behind, filled flat where the
   figure hid it. A held thing, or a thin limb lying over the body, is a rigid part on its bone, the hole it leaves filled from the
   colors round it.
4. **Mesh and weights.** Points along the outline and sparse inside, triangulated, every triangle that crosses paper dropped (an ear
   and the finger beside it never share one). A vertex's bones are those nearest it through the silhouette (shortest paths inside it,
   not straight lines), blended where two are near; a bone lying inside a lifted part moves that part alone.

The rigger works by looking: `cut` and `rig` each answer with a picture, and `rig`'s shows the skeleton, what each bone moves in its
color, and the puppet bent (every bone turned, the jaw open), where a wrong weight shows as a smear.

## Traps

- A packed array read out of a Dictionary is a copy: weights filled through `per[bone][i] = w` stay zero, and every vertex skins to
  the origin (`PuppetBody.build` fills plain arrays and packs them once).
- A drawing's held thing touching another part (a hammer drawn against the head) joins them through the mesh: lift it as a part.
- A color tolerance too wide for a part behind takes in other parts of a near hue (a lime ear in a yellow aura).
- A painter told to draw nothing round a character drops what is its own (an aura): rules/cartoon/sheet.yaml keeps what belongs to it.
- A stage puppet is a node under the stage, drawn over everything the stage draws itself; a cut that carries it on moves the node in
  `begin_morph` (`Actor.moved_to`), before the old stage is freed.

## Open

- A three-quarter view between front and profile; more action drawings (a hop, a run, a fall); the sheet's drawings judged against each other for likeness before they are rigged; puppets in the Dex.
- Sound: voices for the lines the director only shows, and a score.

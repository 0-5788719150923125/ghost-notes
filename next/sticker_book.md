# The sticker book: a game's pictures as a cartoon is shot

A game played at the table (next/tabletop.md) tells most of its story in full-frame pictures over the voices, a new one every few
seconds. A whole page painted by an image model in one go is a dense illustration of its own - people posing, crowds, action - and a
run of them changes everything on screen every few seconds: each beautiful, together impossible to follow.

What the pictures should be is a comic book's or a manga's ACTION SHOTS: each one someone in the middle of doing something, caught at
its strongest moment, the camera close on whoever the moment belongs to, a face filling the frame for a reaction, speed lines and an
impact burst where a moment hits - and the place and the people the same from shot to shot, so the story can be followed. They are
MADE the way limited animation is: a background painted once and held, each character drawn once and then in its poses, cut out and
laid over the set as cels, the camera framing the cast on it. "Sticker book" names that making, never the look.

## Status

**Built 2026-11-24. The first real episode (796273) painted every drawing on flat magenta as asked; all 28 cut (close drawings once the
cut stopped asking for most of the edge to be ground). Not yet played whole or watched.** Seen: the layout and every transition rendered from
pictures cut out of an earlier episode's figure paintings (`tests/table/sticker_look_probe.gd`, at 9:16): characters stood at their
heights on the set, facing each other, a crowded row overlapping before it steps back, a close shot with a burst, a wipe between sets.
The cut was proved on a made painting (`hosts/puppet/test_sticker.py`) and the old figure paintings showed why it needs its own ground:
their skin and clothes are the paper's own brown. For the author to judge: the first episode painted this way ("A Day's Work at the
Tannery", Mistakes Were Made), whether the painter keeps a character alike from pose to pose, and whether the magenta ground cuts clean.

## How it works

- **The game master composes, the code lays out.** `picture` ([GameTools], [method GameLedger.page]) names a `set` (its `looks` the
  first time), its `cast` left to right - each `{who, pose}` or `{thing}`, with `looks` and `height` the first time someone or something
  is drawn tonight - `close` (who or what the camera is close on), `where` (left, middle, right of the set) and `fx`. A refusal says
  what is missing, and nothing happened. The poses and effects are rows ([StickerPoses]): generic as a body is, never a story's or a
  game's; a pose said in the game master's own words is painted from those words.
- **Painted once each** ([TableEpisode] `STICKER_PICTURES`, [method TableProducer._make_sticker]): `image:set:K` each set (3:2, empty,
  a stage seen from the front row: its floor across the lower third), `image:model:K` each character (whole, standing, turned a little
  right), `image:pose:K` each pose but standing (painted beside its model, made from it: a model painted again leaves its poses stale),
  `image:thing:K` each thing. All but a set are painted on flat magenta (rules/table/painter.yaml `game_model`, `game_pose`,
  `game_thing`) and cut off it by the puppet host (`rig.py sticker`: the ground the commonest color round the edge, vivid - a close
  drawing runs off the bottom and both sides, and a painting on paper is refused - keyed out, a soft edge matted against the drawing
  beside it, specks dropped, cropped) - the painting kept in `painted/`, what it was asked for beside it (`.key`): one never cut is cut
  on the next Generate rather than painted again, and one that will not cut is painted again, as a failed painting is. No whole page and no figure's own picture is painted for a session told
  this way. Each step is keyed by its own entry ([method TableEpisode.sticker_key]), so a word of the script changed repaints nothing.
- **Drawn the same next time** ([StickerLibrary]): before it paints, a step takes what the library keeps by that name and looks, else what
  this show's latest earlier night drew; a pose only from the very model this night has. The Props card lists a game's Characters and
  Sets, each with Keep ([EpisodeProps]), and the Dex shows what is kept ([StickerShelf]: Characters, Poses, Sets - the sets shelf is
  the cartoon's too).
- **Laid out by code** ([StickerBook]): the backdrop is a stage, one unit tall, eye level 0.42 down it; a figure's feet on the floor at its
  depth, a person of 175 cm 0.56 tall at the middle depth, nearer lower and bigger. The cast stands left to right round where the page
  is (`where`, else where the last page on the set was), facing each other; a row too wide for the frame overlaps (the shorter in
  front), then steps back. A pose's drawing is sized by the share of a standing figure it spans (`tall`), never by how big the painter
  drew it. A wide page frames everyone; a close one frames who it is on - a close pose is their head and shoulders over the frame's
  bottom, the set behind, nobody else on it; a creature wider than tall is framed whole, its head at whichever end. A frame never leaves
  its backdrop.
- **Between pages, a cut**: each page is a still action shot, as a comic's or a manga's panel is - nobody slides, bounces or breathes,
  and a pose is simply the next drawing. Only a page told `glide` has the camera move to it across the backdrop the page before stood on.
  A page is pushed in slowly (4%) while it is up. Effects: flash, shake, focus lines, a burst behind the subject, the set gone dark, a
  red, blue or gold tint, an explosion, a glide, a page held still.
- **Angles**: a set is painted from its front first (its `wide`), and from any other angle a page asks for (`reverse`, `side`, `close`;
  [constant StickerPoses.ANGLES], `image:angle:K`, painted beside the set's first painting, made from it). A page stands on its angle's
  backdrop; the game master covers a scene as a film does - the wide to open and when someone arrives or leaves, the reverse and the side
  as people talk, the close behind a close shot - and shows whoever is talking.
- **Played as a page is** ([TableGame]): the book is a viewport the size of the frame, its picture one sheet in front of the lens,
  faded in from the table and out again as a painted page was, a pure function of show time. A session of painted pages still plays
  as it did.

## The opening

Every table show's opening holds the table from its head ([method TableGame.opening_end]): pushed slowly in from the intro's start,
settled for its last 1.5 s, and seen 5 s past the show's first words before any page or other camera may take the view. Pages placed
before then are one page, the latest, coming up as it ends; every camera that wanted a moment by then takes the view from there.

## Open

- The first real episode: the painter's likeness from pose to pose, the cut on real paintings, the poses the game master reaches for, and whether they read as action shots.
- A pose's drawing where the painter changed its size on the page is sized by its `tall` row alone; a pose in words stands full height.
- A thing held in a hand; characters' mouths moving with their voices; a ground line traced on a set (the cartoon's surveyor).
- The sticker book outside a game: any note's pictures told this way (the cartoon's puppets and sets are its nearest kin).

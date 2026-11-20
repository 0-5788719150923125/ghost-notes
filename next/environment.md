# The Environment

What is round the scene a note is shown in, as one card: a list of elements - its light, shafts of light through its haze, fog,
what drifts in its air, what is heard round it - each with properties a person sets or a roll draws, and how strongly each thing in it
that throws light throws it. A component (`environment`, a family and hue of its own, needing `places`), its block `environment:`
([docs/surroundings.md](../docs/surroundings.md) lists every kind and property).

## Status

Built:

- **A list, as the Props card is** (`EnvironmentCard`, `EnvironmentSection` in `src/table/`, drawn by `PropsCard`): an entry an
  element (`EntryCard`) - its picture (drawn in boxes from its properties, `Surroundings.picture`), its name, a line, and its ×
  (pressed twice); opened, Used, Roll, Keep and its fields (`SchemaForm`). Below them, a row for each thing on the Props card that throws light
  or makes a sound of its own, its share tuned (`PropSection.lit`, `heard`). "+ Add to the environment" opens the Dex on the
  Environment's shelves. A change reaches a playing scene at once (the live document's `environment`).
- **Properties and Roll** (`Roll`, `src/data/`): a kind's fields are rows (SchemaForm's shape) with a `roll` - the bounds a draw
  stays in. A property set is pinned; one unset is drawn from the element's own number, shown dimmed. Roll is a new number: another
  variant of the same thing, what is set kept. The number also places what it lays out (where shafts land, where motes wander).
  `PropsCard` shows any section's row `fields` the same way (`PropSection.set_field`), so any prop can expose properties.
- **The registry** (`Surroundings`): `KINDS` (light, shafts, colored beams, eight things in the air, six sounds), each with its
  fields (`LIGHT_FIELDS`, `SHAFT_FIELDS`, `BEAM_FIELDS`, `HAZE_FIELDS`, `FOG_FIELDS`, `MOTE_FIELDS`, `SOUND_FIELDS`); six light presets (`LIGHTS`, the desk's moods drawn by
  its number as before; moonlight and no light weigh 0); three looks of shafts the Dex offers (`SHAFT_LOOKS`: through leaves,
  through a window, through a crack). A light and each sound are one to a scene: another added takes its place.
- **The Dex** (`DexWindow`): its shelves listed down its left side under their category (`ShelfSection.category`: Props, Voices,
  Environment). The Environment's shelves: Light (each preset, shafts and their looks), In the air, Heard, and Kept - elements a
  person kept (`EnvironmentLibrary`, `user://library/environment/`), renamed in place, removed to the trash, used as kept.
- **Light shafts** (`LightShafts`, `shaders/light_shaft.gdshader`): sunlight through a gap, never a spotlight. Up to 30 beams, their
  way the scene's own light turned by Direction and tipped by Steepness (never below `LOWEST`), each beam strayed from it by up to
  its Spread (0: all parallel, as through one window), a beam's shafts parallel; Variety from -1 to 1 strays their widths from the
  Width one way (0 all alike, above 0 some up to 8 times fatter, below 0 as many times skinnier, `LightShafts.beam_radius`) and
  their brightness as much; a column of one width its whole length, its edge blurring the further below the gap (the sun's 0.5°,
  `PENUMBRA`), running down to what it lands on (and on past a box's top, fading, where the ground is lower). Beams with narrower
  shafts inside, all added, so the light is about twice as bright where they cross. Worked out for each pixel from where the line of
  sight passes the axis: as deep as the haze crossed (longer looking along it), cut exactly where a floor or a mug stands inside it,
  faint streaks and drifting dust, the haze thick and thin along it, brighter looking toward the light (forward scattering), shimmering
  by Flicker. Its patch is drawn by the same shader - what the screen shows there made `LANDS` times brighter, as squarely as it faces
  the light, its edge the shaft's - because Godot's light grid drops a spot cone centimeters wide and a light's projector needs a
  shadow map: no glint, no bounce, no shadow behind what it lands on.
- **Colored beams** (`StageBeams`, `BEAM_FIELDS`, `BEAM_LOOKS`: disco, stage, lasers): a stage's or a club's moving heads, from
  fixtures on a truss over the scene, drawn by the shafts' shader as a cone opening by its Spread and faded in under its lens (no light:
  its patch drawn). How many, how wide, the palette (club, rainbow, warm, cool, ice, one color) or one Color, how many sweep and how far
  and fast (a pan and a tilt, each a swing of its own), how long each keeps a color (Hold) and how much the holds differ (Variety, a
  quarter to four times), how a color gives way (Blend), how many strobe in bursts and how fast, how strong, where the fixtures hang.
  A pure function of show time. A host that builds shafts builds beams with them (`Surroundings.rays`); each element's level is its own
  (`tick_rays`' levels), which a Dispatch script's `environment:` mark switches.
- **What is heard** (`SOUND_FIELDS`, `Soundscape`): each sound element's properties reach its part of the sound. A sound's own choice
  of what it is (the insects' crickets or cicadas, the sea's shore or dock) is the field `sort`, labeled Kind, handed to the sound as
  its `kind` (`Surroundings._heard_key`): an element's own keys (`OWN_KEYS`) are no property, and a change that would unmake an
  element is refused. The insects have How many (one cricket to a field of `CRICKETS_MOST`, a few cicadas to a chorus; many sing as
  a field does, not louder for each one more), Pitch (an octave and a half round their own) and Pace (a third to three times as
  quick); a table's sound that leaves them out draws its insects as it always did.
- **Test** (`SoundTest` in `src/audio/`): a sound element's entry has a Test, as a voice's has - it alone, at the level it has under
  the voice, made again whenever a property changes so the change is heard at once, until pressed again. Any card that hands a sound
  can use it (a key and a maker of a `SoundBed`).
- **Dust** is posed on the GPU (`Effects.drifts`, `MAX_ADRIFT`): 160 at Amount 1 (on the Dispatch desk, whose air reaches round the
  whole hollow, 2.2 times as many), each 2.2 mm, so a view holds more than a few and they read on screen.
- **Fog** (`FOG_FIELDS`, `FOG_LOOKS`: ground fog, thick fog, patchy mist, rolling bank): Godot's volumetric fog in a FogVolume over
  the room round the scene, lying on its floor (the Dispatch hollow's ground, a desk's top), drawn by the haze's shader told more
  (`Effects.FOG_MORE`; a fog that says none of it is a bank as it always was, line for line). How thick, how high (cm), how low
  it lies (Low lying: 0 as thick at its top as on the ground, 1 thinning fast above it, `Effects.fog_layer`), one sheet or
  patches with clear air between (and their size), its swirls' size, and its ACTIVATION - the curve its noise becomes fog through
  (`Effects.FOG_SHAPES`: smooth, billows, wisps, sharp-edged, folds). CHAOS runs randomness through the rest: the noise warped by
  noise, thick and thin from place to place, patch edges warped, the sway's swings and the gusts of every length. Its own wind
  (speed, direction, gusts from a lull to twice as strong, never blown back: `Effects.fog_run`, closed form), Streaks drawing its
  swirls out along the wind, a Sway in slow waves along the wind's way and its pace, a Breathe rising thinner and sinking
  thicker, a glow of its own, its color (unset, the light's fog). Its density is calibrated looked down through it (`sight`, its
  height and a half again), made up for its profile's thinning and its curve's gaps.
- **The desk** (Letter, Desk, a table show at the desk): its mood is the light element's preset; brightness its exposure; the lamp
  and each kind of candle at their share (`lamp`, `taper`, `pillar`, `tealights`); shafts from the window's side over the pad
  (`Desk.RAYS_REACH`); the air over the pad and the room.
- **The Dispatch desk**: no light element is the hollow's own; a preset sets its ambient, fill, the crack's color and strength, its
  lamp's share, and candles out of the shot where it burns candles and no lamp. Shafts stand in the crack's place, falling on the
  roots round the chair. Each role that throws light (the lamp, the terminal, the screens) has its row, by role
  (`PropRig.set_light_scale`).
- The old flat block (`light`, `brightness`, `rays`, `ray_strength`, `air`, `air_amount`, `sound`, `sound_level`) is no longer read;
  the two notes that had one in ~/repos/rift were moved to `elements`.

Gate: `tests/table/environment_check.gd` (Roll, the block, every kind's fields, air, sound, shafts' geometry, the card, Keep, the
Dex's list). Look: `dispatch_look_probe.gd` and `letter_look_probe.gd` take `--light`, `--bright`, `--shafts k=v,...`, `--air`,
`--heard` (`tests/table/environment_flags.gd`).

For the user to judge:

- The fog on the Dispatch desk and a desk: the Ground fog look first (low, a gentle wind, swaying); each activation; how
  strong Chaos should be at its default; whether Sway reads as waves or as the whole fog sliding; Glow at night, where no light
  falls on the floor. The froxel grid is coarse at the floor (`volumetric_fog_length`), so a layer under 15 cm is soft.

- The colored beams on the Dispatch desk's ending (Targeting Individuals): how many, how they move, how long they keep their colors,
  the strobe (bursts at 5 a second by default - mind photosensitive viewers), and the looks.

- The shafts on the Dispatch desk and a Letter desk: how thin, how many inside each beam, the patches, the streaks, how bright
  looking toward the light (`LightShafts.WIDTH`, `INNER`, `SHARE`, `GLOW`, `LANDS`; the shader's `streaks`, `clouds`, `forward`).
- The list: rows and the Properties toggle, Roll, the drawn pictures; the Dex's left-side list.
- Which properties each kind should show, and their roll bounds (a first, small set); the insects' How many, Pitch and Pace by ear,
  with Test; whether the other sounds want more dials (distance for the insects, gusts for the wind), and a Test for a prop's own
  sound (the receiver's hiss).

## Open

- **Props' own properties**: a prop on the Props card exposing a scale, a material's color, a recipe's number - each section's rows
  carrying `fields` as the Environment's do. The lit and heard shares belong there in the end, as a lamp's or a receiver's
  properties, once a prop's properties have a home in its note.
- **A roll constrained by the person**: a property set to a range (`0.3..0.6`, SchemaForm's `num`) drawn inside it by the number.
- **A table show's set** reads none of it yet: its light is the set dresser's (`Lights`), its air the episode's `effects`, its
  sound the table's. The table format would read the elements as a person's choice over the set dresser's.
- **The seeded show** (the storyboard's scenes) reads none of it: a scene's look is its own.
- An agent cannot choose an environment yet: a plan's `environment` the producer writes from the brief, the card's a person's
  change over it.
- Export and Import of a kept element (`.env.json`), as a prop and a voice are handed on.
- Sounds a scene makes on its own (the Dispatch desk's) play beside the Environment's, never instead of them.

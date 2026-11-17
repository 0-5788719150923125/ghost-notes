# The Environment

What is round the scene a note is shown in, as one card: its light, shafts of light through its haze, what drifts in its air,
what is heard round it, and how strongly each thing in it that throws light throws it. A component (`environment`, a family and
hue of its own, needing `places`), its block `environment:` ([docs/surroundings.md](../docs/surroundings.md) lists every row).

## Status

Built:

- **The card** (`EnvironmentCard`, `src/table/environment_card.gd`) on the reading's and the table's panels: a Light picker (the
  scene's own, or a preset) and Brightness; Light shafts (ticked: how many, how strong); In the air (ticks, any together, and an
  Amount); Heard (ticks, any together, and a Level); and a Lights section, a dial for each thing that throws light, from the
  Props card's sections (`PropSection.lit`). A change reaches a playing scene at once (the live document's `environment`).
- **The registry** (`Surroundings`, `src/table/surroundings.gd`): six lights - lamplight, candlelight, daylight, dusk (the
  desk's old moods, drawn by its number as before), moonlight and no light (weight 0: only chosen, so no desk already made
  changes) - each a row any host reads as it can; seven things in the air as `Effects` effects over `far`, `near` and `room`
  regions each host names; six sounds as parts of a `Soundscape`'s sound, the bed under the voice where no other card hands
  one (a table show's episode hands its own).
- **Shafts** are drawn cones (`shaders/light_shaft.gdshader`), each with a narrow spot that lights where it lands and does not
  fade along its length. The volumetric fog's grid blurs a shaft that narrow into a soft blob, so it is not used for them.
- **The desk** (Letter, Desk, a table show at the desk): its mood is the Environment's light (the Medium card's Light row is
  gone, and a `mood` in the Medium block is no longer read); brightness is its exposure; the lamp and each kind of candle at
  their share (`lamp`, `taper`, `pillar`, `tealights`); shafts from the window's side; the air over the pad and the room.
- **The Dispatch desk**: no light chosen is the hollow's own; a preset sets its ambient, fill, the shaft through the crack
  (its color and strength), its lamp's share, and candles out of the shot where it burns candles and no lamp. Shafts chosen
  stand in the crack's place, falling on the roots behind the desk. Each role that throws light (the lamp, the terminal, the
  screens) has its dial, by role (`PropRig.set_light_scale`).
- **The terminal's glow** follows how much of its screen is lit (`DispatchTerminal.lit_share`), never whether it is awake: a
  screen with one character on it throws next to nothing. The hollow is seen a little brighter from the start
  (`DispatchMedium.EXPOSURE`).
- The ⚙ panel at the row's left is called **Setup**, and the Episode card's sound dial **Place**, so "Environment" names one
  thing.

Looked at (renders, Targeting Individuals at seed 91981 and Secular Hazing): the terminal waking no longer lifts the room;
moonlight, candlelight, shafts with haze and pixies on the Dispatch desk; daylight with shafts and moonlight on a Letter desk.

For the user to judge:

- Every preset's look on the Dispatch desk and a Letter desk, and the default brightness of the hollow.
- The shafts: how many, how wide, how bright (`Surroundings.RAY_CONE`, `RAY_GLOW`, `RAY_THROUGH`).
- Which things in the air and which sounds are worth keeping, and their amounts.

## Open

- **A table show's set** reads none of it yet: its light is the set dresser's (`Lights`), its air the episode's `effects`, its
  sound the table's. The card is offered on a table note, where the desk format reads it; the table format would read it as a
  person's choice over the set dresser's (light preset over the plan's `light`, air added to the plan's `effects`).
- **The seeded show** (the storyboard's scenes) reads none of it: a scene's look is its own.
- An agent cannot choose an environment yet: a plan's `environment` the producer writes from the brief, the card's a person's
  change over it.
- Sounds a scene makes on its own (the Dispatch desk's) play beside the Environment's, never instead of them.

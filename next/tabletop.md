# A game played at the table: voices, real dice, a game master

The user, 2026-11-04:

> The idea would be a Dungeons & Dragons style of tabletop board game. Honestly, we might just follow the exact ruleset, without naming it outright. We would need a few different voices, and we would
> need to distribute them around the table. We might need a slightly different angle of the table (more top-down, so that we can't see that the person on the far side is invisible), or maybe just a
> bigger table. We would need a dedicated game master. We would need dice, which would come from different directions, depending upon the player. We would probably want different dice for different
> players. We would likely want banter, and here's an especially new thing: we might need the ability for voices to talk over each other ... lean into the ridiculous aspect of the game, akin to
> HarmonQuest ... a map and figurines ... elaborate storylines, and game states that could end in both success or failure... or maybe even in complete deviation into something that never resolves (i.e.
> the last remaining player bought a boat and became a fisherman at the end) ... Try to build a generic system, such that other games could be supported: Dungeons & Dragons, Pathfinder, Warhammer 40k, whatever.

**Status, 2026-11-04: built, and its opening really played by real agents ("The first real play", below). Nothing has been painted by a real painter or set by a real set dresser, no whole episode has played through to an export, and nobody has listened to it.** Trying it is below.

## Trying it

1. In the notes list, "Existing note..." and pick `rift/cards/nobody-brought-rope.md`.
2. On the Pipeline card, Generate. The producer plans the night, the game master prepares it, the table is set, the session is played stretch by stretch (each row says how many tool calls it has made), and then what it turned out to need is painted.
3. Play. The first time, the transport says "catching up" for the few seconds the dice take to be thrown.

To read a session with no pictures at all, in about a quarter of an hour: `env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT tests/run_boot_probe.sh tests/table_show/game_play_probe.gd 3000 --brief <brief> --out dist/game_play --scenes 2` (spends quota), then `dist/game_play/transcript.txt`.
To hear a stretch of it: `tests/run_boot_probe.sh tests/reading/game_take_probe.gd 1200 --script <say_K.txt> --note <brief> --out x.wav`.
To look with no agent: `GHOST_PROBE_GPU=1 tests/run_boot_probe.sh tests/table/game_look_probe.gd 400 [--times 30,50] [--clip 27,38]`.

**Verdict: possible, and most of the machine exists.** Three things are truly new: voices that overlap, a play step where what happens is not known until the dice say so, and dice as real bodies whose numbers are honest. Everything else is the table's existing pipeline with a new kind of episode on it.

## What a session of this game is

For someone who has never played. One person, the GAME MASTER (GM), is the referee and the whole world: they describe what you see, voice everyone you meet, play the monsters, and know the secrets, often behind a little cardboard screen. Three to five PLAYERS each run one character, written on a SHEET: six ability scores, hit points, what they carry, what they can do.

The whole game is one loop:

1. The GM says what is happening.
2. The players say what they do. **Anything.** That is the point, and nothing stops them.
3. If it might fail, the GM names a roll: a twenty-sided die plus a number from the sheet, against a number the GM picked.
4. The GM says what came of it, and back to 1.

A natural 20 on the die is a triumph and a natural 1 is a catastrophe, whatever the numbers say. "Advantage" means roll two and keep the better. Fights are the same loop with more bookkeeping: everyone rolls for their place in the order (INITIATIVE), and in turn each moves and acts; an attack is a roll against the target's armor number, then more dice for damage, taken off HIT POINTS. At zero you are down, dying over a few more rolls. Fights are played on a MAP with a one-inch grid, each square five feet, one FIGURE per character.

**On a real table:** a set of seven dice per person (d4, d6, d8, d10, d12, d20, and a percentile d10), a battle map, figures, a GM screen, sheets and pencils, snacks. Dice are personal and people get superstitious about them.

**What makes it a show, and what HarmonQuest knew:** nobody writes it. The comedy is not jokes but the gap between a plan and a die roll. The players are people as well as characters, and they talk over each other, argue rules, get attached to a goat, and ignore the plot. The GM stays dry and prepared while it all falls apart. Bad rolls are the gift. A fixed cast with a guest each episode gives you a newcomer who needs the rules explained, which explains them to the viewer. And a session can end anywhere: victory, everyone dead, or one survivor who buys a boat.

## What was found

**The rules are open, and the names are not.** SRD 5.2.1 is CC-BY-4.0 (checked in the PDF): classes, spells, monsters, the lot. Its one requirement is this statement, in any work using its material:

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

It asks for no other attribution to them, and allows "compatible with fifth edition" or "5E compatible". Goblin, owlbear, fireball and gelatinous cube are in it; beholder and mind flayer are not. The show therefore never says the brand name, invents its own world, and uses nothing outside the SRD. **The description carries that statement whenever the show uses SRD names or material.** Their page says the SRD license does not cover "D&D content" in streaming, which falls under a separate fan policy, so we make no claim to be that game. This is a reading of the documents, not legal advice.

- **Pathfinder 2e:** remaster material is under Paizo's ORC license; I did not read a full breakdown of what is covered. Its d20 and four degrees of success run on the same engine.
- **Warhammer 40k:** closed rules, and in 2021 Games Workshop's guidelines stated that fan films and animations need a license. **So a wargame show is an invented army and setting using d6 buckets, never theirs.** The engine does not care.

**Rigged dice are a solved problem, and honest.** Run the physics first, see which face lands up, then rotate the die's *numbering* by a rotation of the solid, so the number you need is on the face that landed. The shape does not change, so the tumble stays physically true, and every number still sits where a real die has it. I found this written up for cubes and the sources did not cover d4 or d20; every die we use is face-transitive, so a rotation exists for any pair of faces.

**The voice is one mono line with marks.** `ReadingJoin` appends chunks end to end; one `VoiceFX` chain is re-dialed at each voice's mark; `ReadingStream` pushes to a ring as soon as a chunk is ready. So overlap cannot be an edit of the join alone: a chunk must be held until those overlapping it have been synthesized, and voices at different seats must reach the ears separately, past the one chain's lean.

**Bricks already proved the dice.** Jolt in a second Godot (`AssemblyBake`), a record, a lookup at play, no hit no sound. A roll is far simpler than a dig: seconds long, and independent of the last roll if the last roll's dice go home first. So all of an episode's rolls can be baked once as a pipeline step, with no "catching up".

**The camera sees 69 by 39 cm** (`CardTable.sample_layout`: 0.5 m away, pitched 34-42 degrees). That is one person's place. A game needs a table about 1.2 m across, seen from higher up. A d20 is then about 35 px, too small to read, so the shot has to go to the dice (below).

## Generic, by owning no game

**NO CODE KNOWS ANY GAME.** `rules_check` already bans naming a kind of work in `rules/`; it will ban game words too. This is the same answer as "no alchemy mode". A game is the BRIEF's prose, played by an agent that knows or is told the rules. The code owns only what an honest table needs and an agent cannot be trusted with:

| the code holds | why | what stays free |
|---|---|---|
| **dice** (`DiceNotation`) | an agent cannot fake a number it did not roll | any shape 4/6/8/10/12/20, faces printed as anything, keep/drop, count successes, reroll, explode |
| **the ledger** (`GameLedger`) | an agent forgets it took 7 damage | fields are named by the agent, numbers and lists |
| **the board** | a figure's place is checked and drawn | squares, hexes as squares, or inches with no grid |
| **who is at the table** | throw direction, voice place | a referee or none; one side or two |

Checked against four games as gate fixtures, so a d20 assumption fails loudly:

| game | a roll | its board |
|---|---|---|
| this brief's | `1d20+5`, `2d20kh1+5`, `8d6` | 1-inch squares |
| four degrees of success | `1d20+9`, with the agent judging by 10s | squares |
| an invented wargame | `20d6>=3`, then `11d6>=4`, then saves | inches |
| percentile, sanity | `1d100` under a field that goes down | none |

## What a viewer sees

From the head of the table and a little above, looking down: a table with a painted map at its middle and paper figures standing on its squares. A GM's screen at the far side, a sheet and a set of dice at each place, things on the table as people leave them, nobody visible. Voices from where they sit. Someone calls a roll, and dice jump up at the right, rattle, and come in low across the table, bounce off a mug and rattle to a stop; the shot eases in to read them. Everyone reacts at once, from all sides. A figure hops four squares. A goblin falls flat. The GM slides a painting into view: here is what you see.

## The pipeline

Steps for an episode whose plan says `game` (other steps as before). New ones in bold:

| step | who | what |
|---|---|---|
| `plan` | producer | title, look, how many scenes at most, who is the guest |
| **`prep`** | game master (secret) | the adventure, its secrets, what happens if nobody does anything, several endings including failures, every person's sheet (real rolls), each player's private want |
| `image:surface`, `image:backdrop`, `table` | as ever | a bigger table, the map's place kept clear, each seat's place set |
| `say:intro`, **`say:K`**, `say:close` | game master, with tools, **asking the players** | the session, played. Made in order, each from what came before |
| **`image:map:K`, `image:figure:K`, `image:handout:K`** | painter | painted AFTER the play, whatever it turned out to need: a boat if there came to be a boat |
| `script` | code | as ever, plus every event gathered into `game.json` |
| **`dice`** | code | every throw baked, in a second process |

### Play is live

**The scene is written by tool calls in order, and the tools write the script.** This is the main design decision.

- `say` lines (who, words, `over`, `together`, delivery), in batches. Said is said: there is no going back.
- `roll` (who, dice, what for, hidden): the result comes back then, from the seed. Its mark goes into the script at this point on its own.
- `change` (a field on a sheet), `move`, `place`, `fall`, `map`, `show`, `state`.
- `ask` (one player) and `ask_table` (all): see below.
- `end_scene`, or `game_over`, which skips the scenes left. A scene budget is a ceiling, not a goal.

So no mark can be malformed, a roll cannot be hidden or re-rolled until it suits, speakers are always real, and nothing written can contradict the dice because the dice came first. This is how the table is honest, and it holds as THE WORK SHOWN IS THE WORK DONE does in Proof.

### The players are other agents

**The GM cannot decide what a player does.** `ask` starts a small job for that player, which sees only their sheet, their person, their private want and what has been said aloud. Its answer comes back to the GM's tool call, and the GM must honor it and rule on it. That is what makes the boat possible: an author writing one story will not abandon it, but a player with "secretly wants out of this life" will bid on a boat at the worst moment, and a GM told never to steer has to run the boat. A cheap fast model does this; about 100 questions an episode, a few seconds each.

The risk is worth saying plainly: **this may be funnier or it may be mush.** One writer writing everyone is more polished and less alive. It is built so the GM can do both, asking at decisions and writing the small talk itself, and only a real run will tell.

## Voices over each other

Marks, each usable in any script, not just a game's (a row in `ScriptMarks`):

```
<!-- speaker: Bea -->
<!-- over: 0.6 -->
Is it a bear?
```

- `<!-- over -->`: this line starts before the last one ends (by default a third of a second, or the seconds given). Stepping on someone's last words.
- `<!-- together -->`: this line starts just after the last one started. The table exclaiming as one.

How (as `ReadingJoin` is the one join for live and export, all of this is in one place):

1. `ReadingPlan` marks the chunk `over` or `with`, and gives it the sentence of the line it overlaps, so the caption shows one line, each word lit in its voice's color.
2. `ReadingJoin.add` places it on a **side track**, `{at, pcm, speaker}`, and pads the main track only for what runs past its end.
3. `ReadingStream._drain_ready` holds a chunk until everything overlapping it has arrived, so no sample of it reaches the ring early.
4. `VoiceFX` takes the stereo side voices beside the main line, sends a share to the shared room, and mixes them after the lean, so **the room hears everyone and each direct voice stays at its own seat**.

**A SEAT is a voice's new row**, in degrees round the table (0 the far side, 90 its right, 180 at the viewer's elbow), so pan = sin(seat). It also says where its dice come from. One value, two senses, one truth.

## Dice

Honest numbers on real bodies:

- **`Dice`** (pure): each shape's faces, standard numbering, and the rotation taking any face to any face. Gate: on every shape, for every face pair, that rotation is a true symmetry, by the mesh's own vertices.
- **`DiceBake`** (second Godot, Jolt, as `AssemblyBake`): each throw from its seat toward open table, hull shapes, the table's things as solids, figures standing where the ledger has them at that moment. What landed is read at rest; a die left cocked is thrown again. The result: every die's keys, how long, every hit.
- **`DiceTrack`**: a lookup, like `AssemblyTrack`.
- **Up to the moment of the throw it is a hand's**, shaken by the seat with a rattle (`Hands`); after it, recorded; then it lies until the next roll, and the last roll's dice go home first so no throw depends on the last.
- **Their voice rests for the throw** (`roll`'s rest in `TableActions`), and people speak over the rattle with `over`.
- **The shot goes to them** (`TableGame.shot_at`, a pure function of time): eases in as they land, holds until the reaction, eases back. The user's letter camera note applies: gentle, slow, and never a bounce. A viewer who sees the die read 1 before anyone says so laughs first.
- **Different dice per person**: a material row (plastic, metal, wood, stone, glass) gives its look, its bounce and what `WorkSounds` hits with; each person's color, ink and size are theirs. One person's absurd oversized d20 is one number.

## The board and figures

- **Map** (`image:map:K`, no grid or lettering in the painting; the code draws the grid, so a square is exact) laid flat in the table's middle. A new `map` event takes figures off, slides the old one aside, lays the new.
- **Figures are paper standees**: a painted card in a small base, standing, in the true tradition of a cheap table. They read from above, need no agent sculpting (the set dresser's "squid of balls and rods"), and **when one falls it lies flat with its painting up, which reads better than a fallen mini**. A move is a hop by `Hands`, over what is in the way. A set dresser's thing can stand in as a foe (the mug that is a dragon) later on.
- **Handouts**: a painting held up to the lens from the GM's side, as a card is. Then it lies aside.
- **Nothing is a mesh per piece unless it must be**: a few dozen quads a frame.

## The first real play

2026-11-04, this brief, seed 7, real agents (Opus for the game master at high effort, Sonnet at low for the players), its intro and two stretches, on a stand-in table. *The Extra Cow.* **I judge it good, and only the user's judgment counts:** it reads like people at a table. Nobody wrote a joke. Dell prepared 143 years of grazing rights; a cow nobody can afford to kill was drawn by lot and stood before a butcher; Milo, whose secret want is to own something outright, offered 19 gold for a cow worth two silver and crashed the market by accident, which nobody had planned; Bea, whose want is an animal of her own, spent her one spell asking if anyone had been nice to it; Teodora the vet, on Milo's worst dice, rolled 15 and 18, and Milo was outraged. Rosa, whose want is a brother Dell had never heard of, announced he was in town and Dell has to live with that.

| measured | |
|---|---|
| the plan; the preparation (28 real rolls) | about 2 min; 9 min |
| a stretch, once it is its turn | 1 to 2 min |
| what came of it | 2,064 words said, 5 rolls, 18 lines over another, 1 together |
| players asked | 16 answers through 4 calls to ask the table, plus 4 in the intro; 4 s each, used nearly word for word |
| its map, figures and picture, written by the game master | stood on the table as written: 7 figures, 26 events |
| stretch 1 in real voices | 303 s from 637 words; 7 voices over the line, 8.7 s of them; no frame clipped in five minutes; each in its own ear |
| the dice | every number shown checked by gate; by eye, Rosa says "eleven" and her die lies showing 11 |

What it found that no gate had: a plan with no beats was refused (fixed); a game master tightening a player's answer can leave a reply to a line it dropped (a rule added); and **it asks the table about twice a stretch**, where the rules say at every real choice. So far that has been enough to surprise it. Worth watching.

**Not yet done by anything real:** a painter's maps, figures and pictures; a set dresser's table (the frames here are on a table I wrote by hand and paper with no paintings); a fight (nothing has been fought yet, and fights are where the map earns its place); a game that ends; a whole episode through to an export; any of it live on the stream. And **I cannot hear**: the file is `dist/game_play/scene1.wav`, and the clip of dice with their sound is `dist/game_look/dice_clip.mp4`.

## Order of work

1. **Dice notation, ledger, board.** Done: `DiceNotation`, `GameLedger`, `GameBoard`. Gates: `dice_notation_check`, `game_ledger_check`.
2. **Tools and the play step.** Done: `GameTools`, `GamePrepTools`, steps `prep` and `say:K` as live play, `ask`, `rules/table/game_master.yaml`, `game_player.yaml`, the brief. Gate: `game_tools_check`. Played for real, above.
3. **Crosstalk and seats.** Done: `Manuscript.OVER`, `TOGETHER`, `ReadingPlan`, `ReadingJoin`'s side track, the stream's hold, the export, Test, `VoiceFX.side` and `seat`, the Seat row, one caption line. Gates: `crosstalk_check`, `script_marks_check`. Real voices, above; never heard live on a stream.
4. **The dice.** Done: `Dice`, `DiceBake`, numbers from `TextMesh`, sound through `WorkSounds`. Gates: `dice_check`, `dice_bake_check` (real bodies). **Changed from the plan:** thrown as the table first stands, not as a pipeline step, so a throw can meet the table's real things; it takes about a second a throw and waits as bricks do.
5. **The table.** Done: `TableGame`, its verbs in `TableActions`, `CardTable.game_camera`, the map's shader, paper figures, sets at each place, pictures held up, the shot, the set dresser's rule. Gate: `table_game_check`. Look: `game_look_probe`. **Changed from the plan:** a long lens (29 degrees from 1.25 m): the first look, on a short one, leaned every mug out of the picture.
6. **The rest of the pipeline.** Done: the painter's rows, the Pipeline card's rows and the Players row, the producer's `game`, the description's attribution (the brief's words).
7. **A real episode, end to end.** Next, and the user's call: it spends painter quota.

## Open

- **Laughter.** Table laughter is half of how a comedy reads, and a TTS "ha ha ha" is usually bad. The rule to start: reactions in words, and no written laughs. To be judged by ear; if it matters, a synthesized room laugh as `Soundscape` does its sounds.
- **A GM's voices.** A GM doing a silly voice for a barkeep is half the fun. Delivery marks move little. A voice of its own per person they play is easy to offer (a row of the cast), and is not in the first pass.
- **Knocked figures.** A die that hits a figure bounces off it; knocking it over is possible with bodies and has no first-pass path back to the ledger. It would be the best thing on the table, so it is next on the list once the first version is watched.
- **Sheets on the table** are props with scribble to begin with. Numbers that visibly change later.
- **Episodes that continue.** Each one is one session and one story for now. A campaign (same characters, dead stay dead, what carried over) is `TableEpisode.archive` plus the last ledger, and is plainly worth it, after one good episode exists.
- **The GM's drawn map.** A marker sketching rooms on a wet-erase mat as they are entered (`SheetWriting` could draw it). Later.
- **A phone** cannot bake; it plays what was baked elsewhere, as bricks.

## Sources

- [SRD 5.2.1](https://www.dndbeyond.com/srd) (legal page read from the PDF)
- [HarmonQuest](https://en.wikipedia.org/wiki/HarmonQuest) (format; nothing on how quests were planned or scenes cut)
- Games Workshop's 2021 guidelines, as reported by [PC Gamer](https://pcgamer.com/games-workshop-is-trying-to-shut-down-fan-animations) (the guidelines themselves not read; may have changed)
- Paizo's [note on Archives of Nethys and ORC](https://paizo.com/blog/archives-of-nethys) (not a full breakdown of what ORC covers)
- Rotating a die after simulation: a [Castle Engine write-up](https://castle-engine.io/wp/wp-json/wp/v2/posts/5547)

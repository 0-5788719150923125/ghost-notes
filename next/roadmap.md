# Ghost Notes Roadmap

Tracked work for Ghost Notes, from the notes refactor's next steps to the long arc. `python docs.py` keeps the open items above the closed ones.

---

- [ ] **Presets per song**
      Definition, behavior and lifecycle presets per song, config-driven.

- [ ] **One queue for every agent job**
      `Illustrations` still pumps its own jobs beside `AgentJobs`.

- [ ] **Photoreal stone**
      Texture, roughness and height relief for `rocks`, to pair with the wireframe reveal.

- [ ] **More procedural geometry**
      Extend `warp` and `facet` toward terrain, trees and crystals for the 3D world.

- [ ] **Better beat tracking**
      Stronger beat, onset and tempo tracking, and exits that snap to bars rather than beats.

- [ ] **More Swarm rules**
      Pheromone trails, reaction-diffusion, predator-prey, and abstract many-item scenes beyond the city.

- [ ] **Diff notes**
      A copy of a note that stores only its differences from its base. Decided with the notes refactor; not built.

- [ ] **Light crossing terrain**
      A moving light sweeping a landscape and casting traveling shadows - true occlusion under `Lens3D`.

- [ ] **A new playlist from the YouTube card**
      The card picks one of the channel's playlists; making one there (`playlists.insert`, 50 units of quota) is not built.

- [ ] **The tablet on ReadingFollower**
      The tablet carries its own copy of the reading follower the tarot table shares; port it, gated by tablet_check and tablet_camera_check.

- [ ] **One renderer**
      Move the remaining 2D scenes onto `Scene3D` and drive every scene through one modulation surface, so any scene renders under one set of camera and light controls.

- [ ] **A description and tags for every note's upload**
      Only Cards gives its uploads a description and tags (the show's, on the YouTube card); a reading or a song goes up with its title alone.

- [ ] **The tablet, continued**
      Switching between open tabs and a forward button, a visible finger instead of a touch dot, and the keyboard's number and shift layers. See [tablet.md](tablet.md).

- [ ] **Delete the episodes' one-time move**
      `main._adopt_old_episodes` moves `user://tarot/` to `user://cards/` at the first launch after the rename. Once it has run on the author's machine, it goes.

- [ ] **The comic book, later**
      Ink and halftone looks over the panels, speech balloons carrying the narration, and a page that bends as it turns. Deferred on purpose; see [media.md](media.md), "Deferred".

- [ ] **Windows and macOS, for real**
      Ghost Notes is developed on Linux. Nothing needs a Unix shell, and the Windows launcher was checked under PowerShell 7 on Linux, but neither Windows nor macOS has run it.

- [ ] **Spectral determinism, phase 2**
      A perceptual fingerprint that survives a re-encode, so like-sounding audio maps to the same imagery. The seed is the exact file's today; `Echo` already keeps a manual session aligned to its content.

- [ ] **Terrain and city specs**
      Texture as modulation everywhere (`Field` beyond terrain), erosion and rivers, vegetation by slope and mask, roads and districts along low-curvature contours, Gouraud shading under a moving sun, and weather composed onto terrain.

- [ ] **One transport for Masking too**
      Masking's panel is the framework's now (cards, "‹ Notes", the note's "⋯"); its playback is still its own - its timeline and its Space key. The shared transport could conduct it, its marker timeline staying the editor it is.

- [ ] **The APK on a phone**
      The phone shell runs on the desktop under `--handheld` and the APK builds; no device has run it yet. `scripts/build.sh --install android` puts it on a connected phone: the list, a note made, edited and kept across restarts, and nothing downloaded.

- [ ] **The synthesized voice: the room, landmarks, the actor**
      Voice.md's open rungs: room acoustics, a murmuring crowd and the air between voice and listener, all carried in the genome; landmark labels within a reading; and the voice as a Cast kind, so a storyboard speaks. See [voice.md](voice.md).

- [ ] **Portrait beyond full frame**
      Full frame shows and exports at 9:16 (step 10). Open: `cloth` and `two_eyes` tuned for the tall frame (cloth leaves most of it empty, two_eyes sits against its edges), the tablet's distances, the tarot's 16:9 values, and single-page comic, book and notebook layouts and a portrait tarot table - each design work of its own.

- [ ] **A desktop build that runs everything**
      An exported build cannot yet run the Python hosts, relaunch itself to render, or write into `res://`, and the Steam list is open: URL import left out of a store build, the export's excludes, a GPL FFmpeg on Linux, the Assistant stripped, third-party notices. See [binary_export_and_steam.md](binary_export_and_steam.md).

- [ ] **Cards, generalized**
      Built: the rename (Cards, 2026-10-06), the table's verbs as one registry, positions as data, a dealer's tools and the reader's guard (step 9). Open: card state over show time; decks and faces read from the show's guide (the rules are every show's since 2026-10-08 - a tarot show is its brief; the card's size and face are still the tarot's); a dealer run by a real agent (the tools exist, and no episode step calls them yet); pick-a-pile episodes.

- [ ] **The neural voice steered through its duration plan**
      Begun 2026-10-07: `dur_scale` patched in beside `rest_floor`, `*italic*` and `**bold**` spoken as stress, the clipped opening vowel floored, and both pitch moves band-limited and played back in the host. Open: rests rendered instead of spliced, final lengthening on the last words, `dur_cap`, a pitch accent on a stressed word, then a Kokoro-82M prototype whose decoder takes an F0 curve. See [voice_engines.md](voice_engines.md).

- [ ] **The storyboard's editor, continued**
      Built 2026-10-12: a note keeps its own storyboard and edits it in a dock under the show - a strip of entries, a stage entry's lanes, rows built from the fields' tables, undo, a YAML source view, and the seeded show written down as a first draft. Open: the author's own pass over it; a `layers` scene so a scene's look is data too; a storyboard that conducts itself with no sound; keyframed property lanes; a transition as a timeline item. See [storyboard.md](storyboard.md).

- [ ] **The scene-spec pipeline**
      The north star, "cattle, not pets": a declarative spec that samples a configuration of geometry families, modifiers, materials, motion and lighting and composes them, so lifelike scenes come from integrating many sampled domains rather than from code written per scene. `rocks` and `bloom` sample small specs already, and the storyboard `stage` spec is the same idea for choreography; next is pushing the spec down into the bodies' own geometry and material numbers, the `eye`'s hand-tuned constants first. Every tunable constant is a candidate for sampling.

- [ ] **The card table's light, in real episodes**
      Built 2026-10-07: the set dresser lights its table (`Lights`) - a sky, a sun or the moon and what it falls through (a window, blinds, a lattice, leaves, an awning, a parasol...), clouds passing over the sun, birds' shadows, lamps out of the shot - and watches what moves in it. Open: the first real set dresser run with it (how it reads the plan's light and the room's painting, and how many of its 40 pictures the light takes); a screen for a lamp at night (a street lamp through a window's bars); rain on a window; water's caustics. See [cards.md](cards.md), "THE LIGHT".

- [ ] **Let the note own the show**
      Built 2026-10-12: one kind of note, the panel that runs it derived from its components, slots for what a note has one of, a derived "+" and a detach on every panel, and one path that puts a song's show and a reading's up. Open: the Voice as a card on the note's own panel (the reading, Cards, the voice lab and Masking are still panels of their own), a song and a voice on one note, the note holding the clock, the feeds between its components, its moments, places and seed; one window - the note's text while writing, its stage while playing - and a card of the note's own. See [notes.md](notes.md), "Composition, not templates", and [storyboard.md](storyboard.md).

- [ ] **Tools for every agent**
      Only Claude takes Ghost Notes' tools (`AgentTools`), and only the set dresser uses them. Proposed: a painter checked by a vision pass and repainted with notes, a reader's `check_passage`, a producer that can read any earlier episode whole, and Bedrock as a tool-taking writer. Grok and Codex take them since 2026-10-09 (Codex with its token in its environment, sent as a bearer) (`TextGen.Grok`; a real set dresser run built, looked at and fixed a seven-thing table over 32 calls and 27 pictures, stopped by the machine's memory before `submit`): what is open is a whole run to `submit`, and its pace - at Grok's default high effort it thought ~11 minutes before its first call. See [cards.md](cards.md), "Not built yet".

- [ ] **Model the physical sciences**
      The long arc: grow the primitive kit until the catalog spans the natural world, alone or in combination. Open, by domain: weather (wind streaks, hail, heat shimmer, a lightning storm); light (a moving light casting real shadows, day and night, god rays, caustics, refraction); crystals (mineral lattices, accretion); geology (erosion, rivers, plate motion, volcanoes); structures (bridges, lattices, ruins, roads); botany (vines, flowers, undergrowth); fluids (smoke, whirlpools); the sky (n-body systems, rings, galaxies, comets); mechanics (springs and chains, harmonographs, explosions); biology (cells, reaction-diffusion, predator-prey, ant trails, slime molds); fields (EM and gravitational, interference); chemistry (molecules, crystallization, phase changes, combustion).

- [ ] **Folders that say what names what**
      Built 2026-10-13: `src/` is 22 folders, one level deep, stacked bottom to top, held by `python docs.py --check`; the 48 references that pointed up are turned; the tests mirror the folders and `scripts/check.sh --for` runs what a change can reach; a gate that passes over a runtime error fails; the scene roster is `scenes/roster.gd`; the table's shuffle and three of Masking's subsystems are scripts of their own. Built 2026-10-15 (the second round, for a live mode): the show's clock is handed to what it mounts (`ShowFeed.show_time()`...); nothing extends `ReadingPanel` - Cards is a card (`EpisodeCard`) that hands the reading its walk, its bed and its publish; the reading's pure rules are `Splice` and `Delivery`; `table.gd` has its plan, card poses, light and box as parts (2,841 lines, from 6,797); Masking's audio effect and undo are parts; every layer and force setting is a row in its class's `FIELDS`, held to the code both ways. Open: the reading's stateful half (the cast, the audition, the sliding window) as a voice card; placing the things on the table, and the plan as a function of the episode; Masking's banners sorted, then its lanes, markers and autosave, the shared transport and one timeline kit; field tables for the scenes. See [structure.md](structure.md).

- [x] **Notes, not modes (2026-10-06)**
      Ghost Notes opens on a notes list. A note is a markdown file with components attached; the six modes are templates over one registry; every panel section is a colored card; one transport plays every timed show; one bottom-right row; one frontmatter block per component; every mode is left and entered again through one teardown; and every component declares what it asks of the platform. Steps 0-8 of [notes.md](notes.md).

- [x] **One kind of note (2026-10-12)**
      New has no options: it makes a note with nothing attached, and "+" makes it what it becomes. The template table is gone; a component declares the room it takes and the workspace it needs, and the rest is derived. Every component detaches. A note keeps its own storyboard and edits it in the app. See [storyboard.md](storyboard.md).

- [x] **After the first review (2026-10-06)**
      A clean notes list (New only; delete with ×, or a note's "⋯"), every note starting from nothing, a song as a note's component with Auto as a medium, Manual's storyboards as a card, Tarot renamed Cards, Masking's panel in the framework, and "Edit". See [notes.md](notes.md), "After the first review".

- [x] **Tarot, now Cards (2026-10-04 to 10-06)**
      An automatic tarot reading: agents plan, paint and write each episode one card at a time, the table shuffles, deals and lights itself, a set dresser builds the reader's table through Ghost Notes' own tools, and an export can go straight to YouTube.

- [x] **YouTube uploads from every template**
      A YouTube component (2026-10-07): "+" on every note's panel attaches it, and its card holds the upload - after export or not, a title template, the visibility, a playlist - with the Google client and the sign-in. Masking's own export does not upload.

- [x] **Pronunciation as data**
      A `names:` block, homographs decided by part of speech and clause tense (eSpeak asked again, no word lists), `pronounce_audit.gd` before a render, and a probe that asks each voice checkpoint whether it says `read` right.

- [x] **Two frames (2026-10-06)**
      Landscape and portrait: the preview is the frame, subtitles keep the platforms' safe area, portrait presets and a frame-shaped thumbnail, and Movie Maker's crop in a mis-shaped window measured and avoided.

- [x] **The phone shell, on the desktop (2026-10-06)**
      On a phone (or under `--handheld`), a notes app: the list, a full-screen editor written as you type, Import and Export through the system picker, portrait, nothing downloaded.

- [x] **Ghost Notes installs its own dependencies (2026-10-05)**
      FFmpeg, uv, Python and one environment per feature, fetched, checked and kept current by the Provisioner, with progress on screen; Godot is the only install.

- [x] **The framework**
      A live analyzer feeding `AudioFeatures` to scenes, with behaviors, lifecycles, spectral exit triggers, render kinds and typed morphs; the force and layer registries; the nonlinear kit.

- [x] **The Generative voice**
      A small local neural voice: named speakers, hesitations, delivery marks, pictures, a script editor with a palette of marks, and the document as the source of truth.

- [x] **The gates**
      `scripts/check.sh` runs every gate, from a whole-catalog scene smoke to the pixel gates on a virtual display, two-sided wherever a pass could come from a broken instrument.

- [x] **Synthesis**
      `Phonemes`, `Voice` and a threaded `VoiceStream`, karaoke `Subtitles`, the fishing game that breeds voices, and the sampler that mints a seed from a living voice.

- [x] **Staying interactive**
      `TriBatch` batched drawing, `FrameForge` geometry built off the main thread, and `SimClock`, the fixed-rate tick every running system advances on.

- [x] **A repository of its own (2026-10-06)**
      Moved out of Praxis (`axis/ghost`): the GDScript in `src/`, build and check scripts in `scripts/`, the Python hosts in `hosts/`.

- [x] **Real 3D**
      `Mesh3D` bodies, `Geo` fracture and the `Lens3D` / `Scene3D` / `Plane3D` path; `Field`, `Palette` and `Terrain`, and a city that grows across real terrain.

- [x] **Masking**
      The marker and layer model, its effects keyed off the footage's own color, multi-track lanes, URL import, face and body tracking, and headless renders.

- [x] **Video export**
      An offline spectrum bake and a Movie Maker render on a virtual display, encoded while it renders, and the shared furniture every mode inherits.

- [x] **The media**
      A comic book, a novel, a notebook and a tablet beside full frame: the same Director cutting the same scenes, carried on something else.

- [x] **The bookend**
      Held silence before the first sound and after the last, on one session clock, with picture and sound fading together.

- [x] **Manual mode**
      The storyboard data spec, the Workspace, and `Echo` keeping an endless session aligned to its content.

- [x] **The Look**
      Combinable post-process filters over the whole picture, owned by the Director and inherited by a render.

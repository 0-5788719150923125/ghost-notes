# Ghost Notes Roadmap

Tracked work for Ghost Notes, from the notes refactor's next steps to the long arc. `python docs.py` keeps the open items above the closed ones.

---

- [ ] **Presets per song**
      Definition, behavior and lifecycle presets per song, config-driven.

- [ ] **One queue for every agent job**
      `Illustrations` still pumps its own jobs beside `AgentJobs`.

- [ ] **The manual editor**
      Per-entry params, reordering, a timeline and save, grown into the Workspace.

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

- [ ] **YouTube uploads from every template**
      Only Tarot describes its exports for an upload (`upload_meta`); a reading or a song could describe itself the same way.

- [ ] **The tablet on ReadingFollower**
      The tablet carries its own copy of the reading follower the tarot table shares; port it, gated by tablet_check and tablet_camera_check.

- [ ] **One renderer**
      Move the remaining 2D scenes onto `Scene3D` and drive every scene through one modulation surface, so any scene renders under one set of camera and light controls.

- [ ] **The tablet, continued**
      Switching between open tabs and a forward button, a visible finger instead of a touch dot, and the keyboard's number and shift layers. See [tablet.md](tablet.md).

- [ ] **The comic book, later**
      Ink and halftone looks over the panels, speech balloons carrying the narration, and a page that bends as it turns. Deferred on purpose; see [media.md](media.md), "Deferred".

- [ ] **Windows and macOS, for real**
      Ghost Notes is developed on Linux. Nothing needs a Unix shell, and the Windows launcher was checked under PowerShell 7 on Linux, but neither Windows nor macOS has run it.

- [ ] **Masking as cards**
      Masking is the one template whose panel is not cards: its options are one flat, sortable list on purpose (titled groups were rejected), and it keeps its own Space key. It moves last, once the note owns the show.

- [ ] **Spectral determinism, phase 2**
      A perceptual fingerprint that survives a re-encode, so like-sounding audio maps to the same imagery. The seed is the exact file's today; `Echo` already keeps a manual session aligned to its content.

- [ ] **Semi-automatic mode, continued**
      The Dial is the first lever on the autopilot. Next: more dials, each with a signature of its own; dials that reach into auto-mode scenes and layers; and the scene-spec's sampled parameters as addressable controls.

- [ ] **Terrain and city specs**
      Texture as modulation everywhere (`Field` beyond terrain), erosion and rivers, vegetation by slope and mask, roads and districts along low-curvature contours, Gouraud shading under a moving sun, and weather composed onto terrain.

- [ ] **The APK on a phone**
      The phone shell runs on the desktop under `--handheld` and the APK builds; no device has run it yet. `scripts/build.sh --install android` puts it on a connected phone: the list, a note made, edited and kept across restarts, and nothing downloaded.

- [ ] **The synthesized voice: the room, landmarks, the actor**
      Voice.md's open rungs: room acoustics, a murmuring crowd and the air between voice and listener, all carried in the genome; landmark labels within a reading; and the voice as a Cast kind, so a storyboard speaks. See [voice.md](voice.md).

- [ ] **Portrait beyond full frame**
      Full frame shows and exports at 9:16 (step 10). Open: `cloth` and `two_eyes` tuned for the tall frame (cloth leaves most of it empty, two_eyes sits against its edges), the tablet's distances, the tarot's 16:9 values, and single-page comic, book and notebook layouts and a portrait tarot table - each design work of its own.

- [ ] **Tools for every agent**
      Only Claude takes Ghost Notes' tools (`AgentTools`), and only the set dresser uses them. Proposed: a painter checked by a vision pass and repainted with notes, a reader's `check_passage`, a producer that can read any earlier episode whole, and Codex and Bedrock as tool-taking writers. See [tarot.md](tarot.md), "Not built yet".

- [ ] **A desktop build that runs everything**
      An exported build cannot yet run the Python hosts, relaunch itself to render, or write into `res://`, and the Steam list is open: URL import left out of a store build, the export's excludes, a GPL FFmpeg on Linux, the Assistant stripped, third-party notices. See [binary_export_and_steam.md](binary_export_and_steam.md).

- [ ] **Let the note own the show**
      The notes list and the templates are built (next/notes.md, step 8); the deeper half is not. The note, not the mode, should hold the clock, the feeds between its components, its moments, places and seed; there should be one window - the note's text while writing, its stage while playing - and the note should get a card of its own. See [notes.md](notes.md), step 8.

- [ ] **Generalize Tarot into a Cards component**
      Built: the table's verbs as one registry, positions as data, a dealer's tools and the reader's guard (step 9). Open: card state over show time; decks, faces and the recipe read from the show's guide; a dealer run by a real agent (the tools exist, and no episode step calls them yet); pick-a-pile episodes; and the rename - Cards or Deck is still to be chosen, since "card" already names a component's settings section.

- [ ] **The scene-spec pipeline**
      The north star, "cattle, not pets": a declarative spec that samples a configuration of geometry families, modifiers, materials, motion and lighting and composes them, so lifelike scenes come from integrating many sampled domains rather than from code written per scene. `rocks` and `bloom` sample small specs already, and the storyboard `stage` spec is the same idea for choreography; next is pushing the spec down into the bodies' own geometry and material numbers, the `eye`'s hand-tuned constants first. Every tunable constant is a candidate for sampling.

- [ ] **Model the physical sciences**
      The long arc: grow the primitive kit until the catalog spans the natural world, alone or in combination. Open, by domain: weather (wind streaks, hail, heat shimmer, a lightning storm); light (a moving light casting real shadows, day and night, god rays, caustics, refraction); crystals (mineral lattices, accretion); geology (erosion, rivers, plate motion, volcanoes); structures (bridges, lattices, ruins, roads); botany (vines, flowers, undergrowth); fluids (smoke, whirlpools); the sky (n-body systems, rings, galaxies, comets); mechanics (springs and chains, harmonographs, explosions); biology (cells, reaction-diffusion, predator-prey, ant trails, slime molds); fields (EM and gravitational, interference); chemistry (molecules, crystallization, phase changes, combustion).

- [x] **Notes, not modes (2026-10-06)**
      Ghost Notes opens on a notes list. A note is a markdown file with components attached; the six modes are templates over one registry; every panel section is a colored card; one transport plays every timed show; one bottom-right row; one frontmatter block per component; every mode is left and entered again through one teardown; and every component declares what it asks of the platform. Steps 0-8 of [notes.md](notes.md).

- [x] **Tarot (2026-10-04 to 10-06)**
      An automatic tarot reading: agents plan, paint and write each episode one card at a time, the table shuffles, deals and lights itself, a set dresser builds the reader's table through Ghost Notes' own tools, and an export can go straight to YouTube.

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
      The storyboard data spec, the Workspace, the Dial, and `Echo` keeping an endless session aligned to its content.

- [x] **The Look**
      Combinable post-process filters over the whole picture, owned by the Director and inherited by a render.

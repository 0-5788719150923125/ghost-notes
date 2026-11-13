# Media: what carries the show

Every note that runs the Director (a song's show, a reading) paints one scene, full-bleed, edge to edge, and cuts
to the next one.

A **medium** is that choice made addressable: the substrate the show is carried on. `full` is the default and paints one scene
full-bleed. `comic` renders the same scenes into the panels of a comic page and flies a real perspective camera over that page.

A medium is not a mode. Modes decide what *drives* the show (a song, a storyboard, a voice). A medium decides what the show is
*presented as*, and every mode gets both.

## Why it is possible at all

Four things in the codebase do almost all of the work:

- **Scenes are viewport-relative and aspect-agnostic.** `GhostScene.size` comes from `get_viewport_rect()`, geometry sizes off
  `unit() = min(size)`, and layers work in unit-fraction space. A scene rendered into a 512x384 panel is correct with no
  scene-side change.
- **The stage is a SubViewport, and the governor freezes it.** `main._stage_host()` hands the Director a SubViewport; the stage
  governor flips `render_target_update_mode` to `UPDATE_ONCE` and `process_mode` to `DISABLED` to spend less on the picture. The
  same two properties, per panel, let a filled panel hold its picture for free, with no readback (`get_image()` is the
  synchronous stall that cost Masking its frame rate).
- **`Lens3D` is a real perspective camera** projecting world points to centred unit-fraction screen space, and `Plane3D` is a
  real quad in that world. The page is a Plane3D; rotating it on X, Y and Z is the actual projection, not a skew trick.
- **`TriBatch` submits textured triangle arrays** (`uvs` + `tex_rid` -> `canvas_item_add_triangle_array`). A panel is a
  subdivided grid of those triangles with the panel's own SubViewport texture on it.

## The mechanism

```
_stage (SubViewport)                     the composited picture, as today
└── ComicMedium (Node2D)                draws the paper, the panels, the ink
     ├── slot 0 (SubViewport)  <- a GhostScene lives here, live or frozen
     ├── slot 1 (SubViewport)
     └── ...                              two pools of these (page A / page B)
```

Per frame the medium eases the page's basis and the lens, projects the page quad, then for each filled panel projects a
subdivided grid of its rect in page-local space and submits it as one textured draw call, UVs from the grid. Rounded corners are
paper-coloured wedges painted back over the square corners (exact under perspective, because they are computed in page space and
projected like everything else); the border is a rounded-rect polyline on top.

### One live panel, the rest held

The first build kept one scene live (the newest panel) and froze every panel behind it as a render target: viewport stopped,
scene freed, last frame in VRAM. A comic panel is a held moment, so this reads correctly, and it costs what the full medium
costs. The current build runs several panels live; see "The page owns its cast" and "What it costs now".

### A cut is a panel, a full page is a page turn

Every Director cut advances to the next panel slot. When the page fills, the next cut turns the page. `Scene hold` and
`Flourishes` keep their meaning, and a burst of quick cuts becomes a run of small panels filling in fast.

Transitions are panel-local: the outgoing alpha is held at 1 (the old panel is already drawn) and the incoming fades up inside
its own panel. Morphs are kept untouched: one eye in panel 3 splitting into two in panel 4 is continuity across a gutter. LAYER
falls back to a fade, since two scenes composited in one panel is just mud.

### Everything is sampled, nothing is drawn

Page layouts are rolled from `hash([session_seed, "comic", page_index])`: panel count (3-6), the row/column split, per-panel
aspect (clamped 0.5..2.2 so a subject is never cropped through), gutter width, corner radius, whether a panel is canted a couple
of degrees, whether the page has a splash panel. Page attitude (X/Y/Z rotation) is a sampled rest pose with slow ModBank
oscillators around it, so the page breathes.

### The camera over the page

The camera has a vocabulary of moves, not a target. A cut picks a move from a weighted bag and the camera travels it: a start
state, an end state, a duration, a curve. Travelling moves are about 70% of the bag and none of them settle: `drift`, `track`
(through the subject and out the far side), `sweep_h`, `sweep_v`, `push`, `pull`, `orbit`. Discontinuities and arrivals are the
other 30%: `swoop` (low off the far side of the page), `whip`, jump `cut`, `dip` through black. `hold`, which just looks at a
panel, is 3%. A spring easing toward a target has one behavior, which is why the camera is not one.

There is no wide shot. The camera is fitted by two constraints and takes the nearer: close enough that the panel spans the frame
vertically, and close enough that the page covers the frame's width. The panel is cropped by the screen and the sides are gutter
and neighbours. Behind the page is a vignetted desk wash with the sheet's own drop shadow.

- Attitude is sampled at real magnitude on all three axes and drifts continuously; the eye sits at a page-local azimuth and
  elevation rather than on the page normal (an eye on the normal sees a flat rectangle however the sheet is turned). Holding that
  station while the aim moves makes travel between panels a move parallel to the paper.
- The aim stays on the sheet (`AIM_MARGIN`): sweeps and tracks run to the edges, and an aim past the trim is an aim at the desk,
  which no framing distance can fix.
- Scale follows the panel the camera is over, not the one being read, since a travelling move spends most of its time between
  panels.
- `_fit`'s `fill` runs the other way round from how it reads: a smaller fill backs the camera off. The near limit `CROP_MAX`
  must not bind in the ordinary case, or it vetoes the push-in that fills the frame.

### Rake is typed by the scene, not by the page

Every scene is typed `subject` or `field`, and `Shots` gives fields the gentle moves only. The same rule applies to the page's
rake (`FIELD_FLATTEN`): a hard angle reads as foreshortening when there is an object to foreshorten and as damage when there is
not. The diagonal banding in `fractal_zoom` panels is that scene's own float32 precision, magnified by close framing; the
adaptive 6-40 texture grid does not change it.

### The page owns its cast

`Medium.owns_cast` / `take_over`, and `Director.mint_scene`: every panel is filled when the page turns (one per frame, so the
build does not hitch), and a Director cut means move the reading, not build a scene. Liveness follows the camera: panels in shot
run, panels out of shot are stopped targets, and the off-focus ones repaint every other frame at a matching multiple of the step,
so they run at the right speed with half the samples.

### The bookend

The whole-show fade from and to black rides `_current.modulate.a` in the full medium. In a comic that would fade one panel and
leave the paper lit, so the medium takes ownership of the bookend and modulates its own root; the Director stops applying it when
a medium claims it.

## What has to change in the Director

`_host.add_child(...)` at four sites is a router the medium answers, `_choose_style` and `_transition_alphas` get a medium veto,
and `_bookend_fade` gets an owner flag. `full` returns the stage from the router and vetoes nothing, so its behavior is
byte-identical to a build with no medium.

## Checklist

### Phase 0 - prove the two engine assumptions before building on them - DONE
- [x] `tests/media/medium_probe.gd`: a SubViewport set to `UPDATE_DISABLED` keeps its last frame after its child scene is freed.
      Measured: drift 0.0000 after 8 frames with the scene freed.
- [x] Same probe: a ViewportTexture RID draws through a projected, subdivided grid. Measured: the affine (1x1) seam lands 28.5 px
      from the perspective-correct (8x8) one on a 512 px frame, so subdivision is not optional.

### Phase 1 - the medium axis - DONE
- [x] `src/media/medium.gd` - the base + `MEDIUM_REGISTRY` (`full`, `comic`), labels, blurbs.
- [x] `src/media/full.gd` - the identity medium; every veto returns its argument.
- [x] Director: `_scene_host` router, `style_for` veto, `hold_outgoing`, `owns_bookend`, `begin_session`.
- [x] main: builds the medium, mounts it in the stage, passes it to every `Director.attach`, and rebuilds it when the setting
      changed (`_sync_medium`).
- [x] `Director.medium` + `set_medium()` + `resolved_medium()`, persisted to `[director] medium`, overridable with `--medium NAME`,
      forwarded by the exporter.
- [x] Regression: `scene_mix_check` replays one seed and reproduces all 140 cuts exactly, so `_choose_style` around the veto did
      not perturb the seeded stream. `sting_shape_check` also passes.

### Phase 2 - the comic page - DONE
- [x] `src/media/comic_page.gd` - the seeded page roll: 3-6 panels, rows then columns, uneven splits, gutters, margin, corner
      radius (weighted toward hard corners), the occasional cant. Rolls are rejected and retried when a panel aspect would crop a
      subject through.
- [x] `src/media/comic.gd` - the two slot pools, the page basis, the lens, the draw.
- [x] Panel rendering: subdivided textured grid, aspect-matched render targets at constant area, half-texel UV inset, rounded
      corners by paper wedges, ink border.
- [x] Freeze-on-advance, page turn hinged on the spine, two-pool alternation.
- [x] The camera's move vocabulary with an exactly-solved framing distance and eased attitude.

### Phase 3 - the surface - DONE
- [x] Medium picker in the Generative panel's "THE PICTURE" section, built off the registry.
- [x] `tests/media/comic_look_probe.gd` - drives a real comic session and writes PNGs; asserts only that the frame is not uniform.
- [x] `python docs.py` (`docs/media.md`, the CLI flag, the layout block) + README section.

## Second pass (the first one was framed wrong)

The first build left much of every page as dead zone: a wide `spread` shot could not fill a landscape frame with a portrait
sheet. The comic now has no wide shot and the camera is fitted by two constraints (see "The camera over the page"); the desk
wash replaces black. Several panels are available from the start and move at the same time ("The page owns its cast"), and the
page's attitude is sampled on all three axes and drifts.

### What it costs now

Three live scenes cost 73 ms of active frame against the full medium's 41, on one seed with the same scenes. The stage governor
absorbs the difference.

## Third pass: the camera is a vocabulary, not a target

The camera travels weighted moves instead of easing toward a target (see "The camera over the page"), so a constant shot of a
single panel is an event, not the rule.

### Rake is typed by the scene, not by the page

See above: field scenes take the gentle rake only (`FIELD_FLATTEN`).

### Coverage is measured now, not eyed

`ComicMedium.page_coverage()` reports how much of the frame's width the sheet spans, and the look probe prints it per frame and
flags anything under 0.995. It is the number to watch when touching the framing solve.

## Settings: one owner

Every remembered value used to be saved by whichever script owned the control (five writers, five debounces, each doing
`ConfigFile.load()`, set, `save()` on the same file). That is forgotten (a control is persistent only if someone writes save
code), clobbered (read-modify-write from separate owners, and an export renders in a second ghost against the same file) and lost
(a debounce flushes on quiet or at exit, so a kill drops everything since the last pause, and a drag can starve it).

`src/platform/settings.gd` is the one owner: one in-memory copy, one writer, `MAX_DIRTY_MS` so an unflushed change lands within a
couple of seconds, and `_read_only` so a render or a test probe never writes the author's file. `Settings.bind(control, section,
key, default, keys)` loads the stored value, connects the signal and writes on change, so a control cannot be added without being
saved. Two checks hold it: docs.py's rule "settings owner" (`RULES`) and `tests/platform/settings_check.gd`, which proves the kill
case.

- **Autoload order matters.** `Settings` must be first; listed after `Director` it loads the file after Director has read its
  values, so every setting comes back as its default, silently. `medium_pick_check` compares the picker against the file, which
  catches this.
- **A gate must not edit the config of whoever runs it.** Probes are read-only by default; `settings_check` opts in because
  persistence is what it tests.

## Known, and deliberately left

- **Panels out of shot are stills.** Everything visible moves; the budget (`LIVE_MAX`) keeps that affordable. If a rake puts more
  of the page in shot than the budget allows, the panels that keep moving are the ones nearest the reading.
- **Dark scenes read as empty boxes.** Roughly half the catalogue is near-black by design (`bed` tops out at a mid tone); a page
  of four dark panels is four dark rectangles. This is a scene-palette question, and the first thing to look at if the comic
  feels flat.
- **The desk is a screen-space wash, not a surface in the world.** A quad big enough never to run out under a close raked camera
  has corners behind the eye, and the projection drops those, so the world-quad version never drew.
- **`get_image()` is never called and must not be.** Everything here holds pictures by stopping render targets. A feature that
  wants a panel's pixels (a halftone filter, a thumbnail) must do it on the GPU or it reintroduces Masking's readback stall.
- **The GPU look probes core-dump at xvfb shutdown.** `city_look_probe.gd` aborts identically after its own clean exit.

## Deferred (phase 4, explicitly not now)

- Ink / halftone / screentone filters over the panels.
- Round-robin liveness for held panels.
- Speech balloons and captions carrying a reading's narration.
- A real page turn with a bent page and a printed back.
- A page turn seen from the reading distance: it is a gesture designed to be watched from further back than the camera sits.
- Adaptive `LIVE_MAX`, tied to what the stage governor is measuring.

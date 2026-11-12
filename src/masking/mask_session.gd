extends RefCounted
class_name MaskSession

## MaskSession - the data model for one mask-mode editing session: one imported clip (video + its extracted audio, see
## masks/README) with a timeline of markers, the points where the mask changes.
##
## A marker is a fixed-schema scalar vector (see VECTOR_FIELDS), so a session's marker list is a small matrix. Every
## marker is one layer, carrying one channel (one target color, effect, strength and pattern placement) plus its own
## transition envelope. Layers stack chronologically: a later marker adds to the earlier ones without disturbing them.
##
## The envelope's kind (see MARKER_KINDS) is which side of the anchor its transition occupies:
##   RAMP  - eases in over the `duration` seconds before the anchor, complete exactly at the marker's time.
##   DAMP  - begins at the anchor and accumulates over the `duration` seconds after it.
## A zero-length marker of either kind is an instant cut.
##
## Once in, a layer holds until one of three things ends it:
##   1. The raw checkpoint (the rebase). A full-raw marker (view_mode 2) is a canvas reset: once its transition to raw
##      has completed (at its anchor for a ramp, anchor+duration for a damp, never mid-fade), no earlier marker's layer
##      exists beyond it. The reset is pop-free because nothing is on screen, so history never crosses a raw boundary.
##   2. "restore" - draws nothing. It targets a color like a keying marker (own picker, own threshold for how wide
##      around the color it reaches, own envelope, intensity = how completely it restores) and fades out every earlier
##      layer on that color over its window.
##   3. "clear" - restore for all colors at once.
##
## Otherwise layering is additive: a later marker keying a second color stacks with the earlier work.
##
## The transition contract: every visual quantity leaving at_time() is transition-safe in one of three shapes, and
## nothing may drive a visual straight off a discrete snap:
##   1. CONTINUOUS - global keying scalars (threshold, feather, sat_floor), lerped across transition windows
##      (GLOBAL_CONTINUOUS).
##   2. PRESENCE   - which screen layers are up (view_mode): the discrete value is kept for storage and labeling, the
##      visuals consume the derived AMOUNT_FIELDS, which lerp.
##   3. LAYER      - everything a marker's channel carries (color, effect, strength, placement, coverage, contrast,
##      resonance), baked into the layer, whose envelope does the transitioning. An identity change is two layers with
##      complementary envelopes, a dissolve.

## The vector schema. Order is the contract (to_vector()/from_vector() index into it): append, never reorder or
## remove. The *_b fields are legacy from the two-channel era: stored, not consumed (a layer reads the *_a channel).
const VECTOR_FIELDS := [
	"time",             # seconds into the clip
	"kind",             # 0=ramp (eases in before the anchor) / 1=damp (accumulates after)
	"hue_a",            # THE layer's target hue, 0..1
	"hue_b",            # umbra's ACCENT hue - the color of the ghost's eyes
	"threshold",        # key distance threshold, 0..1 (global)
	"feather",          # edge softness, 0..1 (global)
	"sat_floor",        # minimum saturation to key at all, 0..1 (global)
	"swap",             # legacy, unused
	"effect_a",         # THE layer's effect id, see MASK_EFFECTS
	"effect_b",         # legacy, unused
	"intensity_a",      # THE layer's strength, 0..1
	"intensity_b",      # legacy, unused
	"duration",         # seconds the ramp (before) or damp (after) envelope takes
	"view_mode",        # which rendering is shown/exported at this point - see VIEW_MODES
	"pip_track",        # which video fills the PiP inset: 0 = the main clip (default),
	                    #   k = imported track (k-1). The V button cycles through these.
	"fx_x",             # THE layer's pattern pan X (unit UV)
	"fx_y",             # pattern pan Y
	"fx_scale",         # pattern zoom (1 = nominal)
	"fx_density",       # pattern coverage 0..1 (how much of the region the wisps consume)
	"resonance",        # 0..1 - how strongly the pattern breathes with the audio envelope
	"fx_contrast",      # 0..1 - wisp edge hardness; exponential response, 0.5 = neutral
	"fx_speed",         # drift velocity multiplier for the volumetric fields (1 = nominal)
	"fx_lag",           # echo: how far back the lagged frame reaches, seconds
	"fx_smooth",        # echo: 0 = discrete stutter, 1 = wide temporal blend (EMA-like)
	"fx_stick",         # fur: 0 = free coat everywhere (default look), 1 = strands cling
	                    #   to natural anchors (key-color concentration, tracked centroid, luminance) - see the shader's fur branch
	"fx_tint",          # Morph: rotates the EFFECT'S OWN palette hue (0 = natural colors).
	                    #   Decoupled from hue_a: the picker says what to mask, this says what color the effect becomes.
	# The region: where this layer acts at all, in the frame's own 0..1 UV (the same on any clip shape). Real fields, not
	# spare ones borrowed per effect: it multiplies into every layer's on-screen weight (see the shader's apply_layer),
	# so any effect can be confined. Default is the whole frame. Space separates what a color key cannot (a yellow wall
	# from a gold coin at the subject's neck).
	"reg_x0",           # region left edge, 0..1 UV
	"reg_y0",           # region top edge
	"reg_x1",           # region right edge (x1 <= x0 is normalized on read)
	"reg_y1",           # region bottom edge
	"reg_soft",         # 0..1 - how gradually the region fades out at its border,
	                    #   as a fraction of the box's smaller side; a hard cut reads as a rectangular cut.
	# The key swatch's other two components: the key itself is a hue (hue_a), and these carry the rest of the pick so a
	# reopened session shows the swatch that was set. Not in LAYER_FIELDS: no shader reads them, and a field there
	# promises that something does. Defaults are the constants the swatch was rebuilt with.
	"key_sat",          # the key swatch's saturation - display only
	"key_val",          # ...and its value
]

## Global keying environment - lerped across transition windows (contract shape 1).
const GLOBAL_CONTINUOUS := ["threshold", "feather", "sat_floor"]
## What each marker's layer carries (contract shape 3), baked at the marker's own values; only the envelope varies over
## time. A field a layer reads must be listed here, or `layer.get("threshold", 0.24)` returns the default forever
## (threshold/feather/sat_floor are also resolved as global scalars, see resolve()). intensity_b is the clown's Drip
## curve, `swap` its Smudge, hue_b umbra's accent hue (the ghost's eyes).
const LAYER_FIELDS := ["hue_a", "effect_a", "intensity_a", "intensity_b", "swap", "fx_x", "fx_y",
	"fx_scale", "fx_density", "resonance", "fx_contrast", "fx_speed", "fx_lag",
	"fx_smooth", "fx_stick", "fx_tint",
	"threshold", "feather", "sat_floor", "hue_b",
	# The region travels with the layer: a continuation marker blending into its predecessor lerps the box corners.
	"reg_x0", "reg_y0", "reg_x1", "reg_y1", "reg_soft"]

const MARKER_KINDS := ["ramp", "damp"]

## The most simultaneous layers the shader renders (its uniform arrays are sized to this); the oldest are dropped.
const MAX_LAYERS := 6

## The per-layer effect registry. Ids are the contract: append, never reorder.
##
## Most effects are volumetric consuming fields (see shaders/mask_split.gdshader): the keyed footage is eaten to void
## where the drifting noise field forms a lick, rimmed with a glow in the layer's hue. Placement and coverage ride the
## fx_* fields; coverage 0 = untouched, 1 = devoured.
##
##   erase     hides the keyed region outright.
##   fire      rising domain-warped licks.
##   freeze    near-static crystalline veins.
##   smoke     soft billowing gauze.
##   restore   subtractive: draws nothing; fades out every earlier layer whose target hue lies within its own
##             `threshold` of its picked color, over its envelope, scaled by intensity. layers_at resolves it into
##             the other layers' envelopes, so the shader never sees it.
##   whisp     content-aware volumetric: its field is advected along the picture's luminance edges and placement
##             locks to the target color's mass centroid, EMA-tracked by the editor.
##   crystal   faceted glass drawn in place of the target color (voronoi facets refracting the footage). Projection
##             based like erase: no gates, no rings.
##   echo      temporal lag: the target region shows a muted, delayed echo, optionally cloned with accumulating
##             offsets into staircase "time-shapes".
##   clear     restore for every color. The shader never sees it.
##   snow      keyless: foreground vs background is decided per pixel from motion (the echo ring's two newest
##             captures) and color intensity. Contrast is Sensitivity; Pan X/Y are Wind X/Y; Gust (fx_smooth) adds
##             irregular swings.
##   fur       hair anchored on the keyed surface. Strand roots are the key color's own pixels (read by crystal's
##             aligned-fraction projection, fur_root_mass() in mask_split.gdshader); a pixel carries hair only if
##             marching upstream against the local current reaches root mass. One shared breathing current field
##             drives the swarm; the emissive is tinted by the key hue. Undulation (fx_smooth) sends waves down each
##             strand; Coil (fx_lag) spins the flow into eddies.
##   oracle    echo inverted: the region stays live and the world lags through the same kernel, so the region leads
##             the motion. Coverage adds premonitions stamped ahead along the pan; Contrast mutes the delayed world;
##             Lag is how far ahead the region leads.
##   serpent   thousands of wriggling snakes as a sparse volumetric mask. Keyless like snow; contrast is
##             luminance-inverse (bites hardest where bright). Domain-warped torus lanes host one snake each, with
##             per-lane hashes for length, speed, heading, girth, wriggle, banding and glow; a slow fbm cluster field,
##             stirred by motion, decides where the swarm lives. Fixed viridian-to-jade palette.
##   chimera   the imported track's video grafted into the main frame through a soft window riding u_anchor (keyed by
##             this marker's color, else the motion centroid). Per pixel, the side with more feature energy owns the
##             pixel. Needs an imported track (T); draws nothing without one.
##   arealight cinematic area lighting, keyless and additive-only: a rig of sources across the azimuth behind the
##             camera, each waxing on its own clock, lit along the same gradient probe whisp/freeze/crystal read.
##             One dial (Contrast, relabeled Envelope) grows the rig: a wide soft warm practical at 0, more sources
##             through a gel palette as the falloff sharpens, then point flares.
##   clown     white-face paint on a detected face. The editor fits a face model each capture tick
##             (MaskEditor._update_face_model); the shader draws in the eye-line frame (origin mid-eyes, rotated to
##             the eye axis, unit = eye distance). Coverage is Wear, Contrast is Smear, Velocity paces the smear's
##             breathing; per-element numbers come from hashes salted by the key hue. Bleed (fx_smooth) widens each
##             feature's reach; Settle (fx_lag) sets the decay of orphaned paint and the rise of new paint; Hollow
##             (fx_stick) opens a radial hole gated on brightness.
##   umbra     the subject's own silhouette thrown as a larger cast shadow beside them, read ahead of the playhead so
##             it turns its head first; never drawn on the subject. Shape comes from hosts/face/pose_track.py (a
##             MediaPipe pose pre-pass cached in user://pose_tracks: a person mask and a skeleton). The throw is a
##             similarity pinned by two point pairs (shoulder line to the ghost's anchor, eye line to its head).
##             Separation is the two skulls' half-widths added (Stand scales it), on whichever side has room. A bust,
##             not a body: the mass is a radial falloff about the eye line in the subject's own units, dissolving into
##             smoke below. Lead is a real look-ahead in seconds. Knobs: Stand, Lead, Lean, Narrow, Gaze, Wisp, Cling,
##             Depth; Coverage is Loom, Contrast is Roil, Velocity is the essence's climb, Resonance swells the loom
##             with the audio. The mass darkens rather than paints black, keeping the surface's hue and texture.
const MASK_EFFECTS := ["erase", "fire", "freeze", "smoke", "restore", "whisp", "crystal", "echo", "clear", "snow", "fur", "oracle", "serpent", "chimera", "arealight", "meta", "clown", "umbra", "repaint", "rain", "audio"]
const EFFECT_RESTORE := 4
const EFFECT_CRYSTAL := 6
const EFFECT_CLEAR := 8
const EFFECT_SNOW := 9
const EFFECT_FUR := 10
const EFFECT_ORACLE := 11
const EFFECT_SERPENT := 12
const EFFECT_CHIMERA := 13
const EFFECT_AREALIGHT := 14
## META: mirrors the editor workspace into the frame (the recorded product demo). Keyless, no pattern. The editor
## captures its previous frame into u_workspace only while a meta layer is live (a per-frame viewport readback); the
## layer mixes it in by its envelope. See mask_editor.gd _capture_workspace / _meta_amount_of.
const EFFECT_META := 15
const EFFECT_CLOWN := 16
const EFFECT_UMBRA := 17
## REPAINT: replace one color with another. Projection-based like erase and crystal (no keying gates, no pattern),
## but it substitutes a chosen chroma where erase subtracts (subtracting leaves gray). Its selection is an angular cone
## around the key: a replacement is all-or-nothing, and skin 28 degrees off a yellow wall must not take a share (see
## tests/masking/repaint_check.gd).
const EFFECT_REPAINT := 18
## RAIN: keyless weather in front of and behind the subject. Every drop is independent (lane, phase, speed and length
## hashed per drop); Depth sets where near rain gives way to a far sheet that falls behind the subject.
const EFFECT_RAIN := 19
## AUDIO: draws nothing; its product is sound, an EQ, compressor, delay and reverb chain on the mask bus scaled by the
## marker's envelope. See MaskAudioFx.apply.
const EFFECT_AUDIO := 20

## The control hierarchy: which panel option groups each effect consumes (the editor hides a slider that does nothing
## for the selected effect). Color and intensity are universal. Groups:
##   "keying"  - threshold/feather/colorfulness steer the volumetric mask
##   "reach"   - threshold reinterpreted: how wide around the color a restore acts
##   "pattern" - field placement/coverage/contrast/resonance
## Erase consumes no groups: it is projection-subtraction, gate-free. The trailing comment of a row is its note in
## docs/masking.md, in the shape `name (note)`.
const EFFECT_CONTROLS := {
	0: [],                        # erase
	1: ["keying", "pattern"],     # fire
	2: ["keying", "pattern"],     # freeze
	3: ["keying", "pattern"],     # smoke
	4: ["reach"],                 # restore
	5: ["keying", "pattern"],     # whisp
	6: ["pattern"],               # crystal (projection-based: no keying gates)
	7: ["pattern", "echo"],       # echo (pan=clone step, scale=step size, coverage=clones, contrast=mute)
	9: ["pattern", "snow"],       # snow (no keying group: it has no key color at all)
	8: [],                        # clear (intensity = how completely; color is meaningless)
	10: ["keying", "pattern", "fur"],  # fur (a keyed volumetric + its own tendril-dynamics knobs)
	11: ["pattern", "echo"],      # oracle (echo inverted: pan=premonition step, coverage=copies, contrast=mute, lag=lead)
	12: ["pattern"],              # serpent (keyless, like snow: contrast-driven, no color to gate on)
	13: ["pattern"],              # chimera (scale=window, pan=graft offset, coverage=dominance, contrast=interleave sharpness)
	14: ["pattern"],              # arealight (keyless; one Envelope/contrast dial)
	15: [],                       # meta (mirrors the workspace; keyless, no pattern)
	16: ["pattern", "clown"],     # clown (pan=layout nudge, scale=feature size, coverage=Wear, contrast=Smear, + its own Bleed/Settle/Hollow)
	17: ["pattern", "umbra"],     # umbra (keyless; coverage=Loom, contrast=Roil, + its own Stand/Lead/Lean/Narrow/Gaze/Wisp/Cling/Depth)
	18: ["repaint"],              # repaint (projection-based, no keying gates, no pattern: the paint color + its reach and edge smoothing)
	19: ["pattern", "rain"],      # rain (keyless: coverage=Amount, velocity=fall speed, scale=streak length, pan=wind, contrast=Depth, + its own Squall)
	20: ["audio"],                # audio (draws nothing: lag=Echo time, smooth=Echo mix, density=Ambience, scale=Room, contrast=Resonance, stick=Bass)
}

## Second level of the same rule, inside the "pattern" group: which individual knobs an effect reads ("scale", "pan",
## "coverage", "contrast", "velocity", "resonance"). An effect not listed shows every knob; list one only to prune.
## Audit against shaders/mask_split.gdshader when an effect changes what it consumes.
const PATTERN_KNOBS_ALL := ["scale", "pan", "coverage", "contrast", "velocity", "resonance"]
const PATTERN_KNOBS := {
	# chimera reads scale (graft zoom), pan (graft nudge), coverage (dominance) and contrast (interleave sharpness).
	13: ["scale", "pan", "coverage", "contrast"],
	# arealight reads only contrast (relabeled Envelope): one dial, not a knob per light.
	14: ["contrast"],
	# clown draws no drifting pattern (Velocity and Resonance are hidden). "pan" is also absent: fx_x and fx_y carry
	# clown controls (Edge feather and Drip width), and a second slider on a field would fight the first.
	16: ["scale", "coverage", "contrast"],
	# rain reads all but resonance: scale = streak length, pan = wind, coverage = Amount, velocity = fall speed,
	# contrast = Depth. Its own Squall is in the "rain" group on fx_smooth.
	19: ["scale", "pan", "coverage", "contrast", "velocity"],
	# umbra is absent on purpose (it shows all six): Velocity is the essence's climb, Resonance swells the loom with the
	# audio.
}

## The view-mode registry (see mask_editor.gd): a 2-axis matrix (main screen raw/fx x inset hidden/raw/fx) flattened
## to one discrete field, since it is a per-marker exportable choice. Append-only (indices are stored in saved
## sessions); the display order is VIEW_CYCLE in mask_editor.gd:
##   pip        - main raw, inset fx (the compare view)
##   masked     - main fx, no inset
##   raw        - main raw, no inset (the default; no shader pass)
##   pip_raw    - main raw, inset raw
##   masked_pip - main fx and inset fx
const VIEW_MODES := ["pip", "masked", "raw", "pip_raw", "masked_pip", "masked_pip_raw"]

## The untouched (no markers) preview state: view_mode "raw" (index 2), the source video with no shader pass.
const DEFAULTS := {
	# hue_b 0.0 = red (umbra's eye color)
	"kind": 0.0, "hue_a": 0.02, "hue_b": 0.0, "threshold": 0.24, "feather": 0.12,
	"sat_floor": 0.18, "swap": 0.0, "effect_a": 0, "effect_b": 0,
	"intensity_a": 1.0, "intensity_b": 0.0, "duration": 1.0, "view_mode": 2.0,
	"pip_track": 0.0,
	"fx_x": 0.0, "fx_y": 0.0, "fx_scale": 1.0, "fx_density": 0.45, "resonance": 0.0,
	"fx_contrast": 0.5, "fx_speed": 1.0, "fx_lag": 0.35, "fx_smooth": 0.0,
	"fx_stick": 0.0, "fx_tint": 0.0,
	# The whole frame (no restriction). reg_soft defaults to a hard border, since a region is a selection and the
	# effect should look the same everywhere inside it.
	"reg_x0": 0.0, "reg_y0": 0.0, "reg_x1": 1.0, "reg_y1": 1.0, "reg_soft": 0.0,
	"key_sat": 0.85, "key_val": 0.9,
}


## Is this marker's region an actual restriction, or the default whole frame? One place, since the panel, the
## on-screen box and the shader push must agree.
static func has_region(m: Dictionary) -> bool:
	return float(m.get("reg_x0", 0.0)) > 0.001 or float(m.get("reg_y0", 0.0)) > 0.001 \
		or float(m.get("reg_x1", 1.0)) < 0.999 or float(m.get("reg_y1", 1.0)) < 0.999

var video_path := ""
var audio_path := ""
var source_path := ""     # the original file this session was prepared from
var duration := 0.0
var markers: Array = []   # Array[Dictionary], sorted by "time"; each has all VECTOR_FIELDS

## Primary-clip trim (in/out points, seconds into video_path/audio_path). clip_out of -1 means uncut (full duration).
## Never read by the timeline's own pixel mapping (see MaskTimeline._visible_span/timeline_extent): dragging a trim
## handle must not rescale the ruler it is dragged against.
var clip_in := 0.0
var clip_out := -1.0

## The main clip's audio level, 0 or 1 (the toggle on its lane). Tracks carry their own "volume"; all audio plays
## together, each gated by its own 0/1 (see MaskTracks.sync / _play).
var main_volume := 1.0

## The main clip's fade envelope (seconds): audio and video ramp in over the first `main_fade_in` and out over the
## last `main_fade_out`. Tracks carry their own "fade_in"/"fade_out". A lane edge has two handles, the trim point and
## the fade boundary (see TrackLane / _apply_clip_fade).
var main_fade_in := 0.0
var main_fade_out := 0.0

## Where the playhead was, in seconds, so reopening a session lands back there.
var playhead := 0.0

## Timeline zoom/pan (see TimelineView), persisted with the playhead.
var timeline_zoom := 1.0
var timeline_view_start := 0.0

## Secondary tracks (picture-in-picture overlays), see mask_editor.gd's "Import track" flow. Each: {video_path,
## duration, clip_in, clip_out, offset (seconds on the master timeline where clip_in lands), x, y, w, h (normalized
## 0..1 screen position/size), muted}. The primary clip (video_path/audio_path/duration/clip_in/clip_out above) is
## not in this array: it is track 0 implicitly.
var tracks: Array = []


## The clip end for playback clamping and the export stop: clip_out if trimmed, else the full duration.
func effective_clip_out() -> float:
	return clampf(clip_out if clip_out > 0.0 else duration, 0.0, duration)


## Where playback (live preview and export) stops: effective_clip_out(), extended to cover any track scheduled to run
## past it (e.g. MaskTracks._split_main's tail, appended as a track at the same offset). Clamped to `duration`: the
## master clock is the main clip's own decode position (see MaskTracks.sync), so it cannot pass its full length.
func content_end() -> float:
	var extent := effective_clip_out()
	for t in tracks:
		var span: float = maxf(0.0, float(t.get("clip_out", 0.0)) - float(t.get("clip_in", 0.0)))
		extent = maxf(extent, float(t.get("offset", 0.0)) + span)
	return minf(extent, duration)


## Index of the track that is a continuation of the main clip (same source video_path, produced by splitting the main
## clip, see MaskTracks._split_main/_split_track) whose [offset, offset+span) window covers master time `t`, or -1.
## A track on a different file is a PiP inset (see MaskTracks.sync), never a continuation. Each continuation has its
## own player (MaskTracks.runtime) that mask_editor.gd seeks and renders full-screen while it owns `t`, from its own
## `t - offset + clip_in`, so picture visibility does not depend on `offset == clip_in`.
func continuation_track_at(t: float) -> int:
	for i in tracks.size():
		var tr: Dictionary = tracks[i]
		if tr.get("video_path", "") != video_path:
			continue
		var offset := float(tr.get("offset", 0.0))
		var span: float = maxf(0.0, float(tr.get("clip_out", 0.0)) - float(tr.get("clip_in", 0.0)))
		if span > 0.0 and t >= offset and t < offset + span:
			return i
	return -1


## Whether some source (the main clip's kept range, or a continuation track right after it) has valid picture at `t`.
func main_visible_at(t: float) -> bool:
	return t < effective_clip_out() or continuation_track_at(t) != -1


## Whether a continuation track (same video_path as the main clip) claims audio ownership at `t`, so
## mask_editor.gd's _apply_main_fade mutes the main clip's audio in favor of that track's own player. Only true while
## the track is a genuine continuation: `offset` equal to its `clip_in`, so its source position (t - offset + clip_in)
## is `t` itself and it would duplicate main's audio. Once dragged apart it plays a different moment of the source,
## and main keeps playing so the two mix.
func track_owns_audio_at(t: float) -> bool:
	var i := continuation_track_at(t)
	if i == -1:
		return false
	var tr: Dictionary = tracks[i]
	return absf(float(tr.get("offset", 0.0)) - float(tr.get("clip_in", 0.0))) < 0.05


## The ruler's total extent in seconds: at least `duration` (the primary clip's untrimmed length), extended to cover
## any track that runs past it, plus a fixed overflow margin so a handle dragged near the boundary never forces a
## rescale mid-drag.
func timeline_extent() -> float:
	var extent := duration
	for t in tracks:
		var span: float = maxf(0.0, float(t.get("clip_out", 0.0)) - float(t.get("clip_in", 0.0)))
		extent = maxf(extent, float(t.get("offset", 0.0)) + span)
	return extent + maxf(5.0, extent * 0.12)


## A new marker at `t`, seeded from the previous marker's values (or DEFAULTS before the first), so it continues the
## same layer: the continuation rule in layers_at dissolves the predecessor through this marker's envelope. `kind_id`
## indexes MARKER_KINDS.
func add_marker(t: float, kind_id: int = 0) -> Dictionary:
	var prev = null
	for mm in markers:
		if mm.time <= t:
			prev = mm
	var src: Dictionary = prev if prev != null else DEFAULTS
	var m := {}
	for key in VECTOR_FIELDS:
		m[key] = src.get(key, DEFAULTS.get(key, 0.0))
	m.time = t
	m.kind = float(kind_id)
	markers.append(m)
	markers.sort_custom(func(a, b): return a.time < b.time)
	return m


func remove_marker(m: Dictionary) -> void:
	var i := markers.find(m)
	if i >= 0:
		markers.remove_at(i)


## Shortest distance between two hues on the wrapped 0..1 circle.
static func hue_dist(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 1.0 - d)


## The derived per-screen-layer presence amounts (0..1) a view mode implies. view_mode is stored discrete, but what
## transitions on screen is each surface's presence, blended through transition windows (contract shape 2).
const AMOUNT_FIELDS := ["main_fx", "inset_show", "inset_fx"]

static func mode_amounts(view_mode_val) -> Dictionary:
	var id := int(view_mode_val)
	return {
		"main_fx": 1.0 if (id == 1 or id == 4 or id == 5) else 0.0,          # masked, masked_pip, masked_pip_raw
		"inset_show": 1.0 if (id == 0 or id == 3 or id == 4 or id == 5) else 0.0,  # pip, pip_raw, masked_pip, masked_pip_raw
		"inset_fx": 1.0 if (id == 0 or id == 4) else 0.0,                   # pip, masked_pip (5 = fx main + RAW pip)
	}


# The amounts of a resolved at_time() state: carried in the dict if it came through at_time, else derived from view_mode.
static func _amounts_of(state: Dictionary) -> Dictionary:
	if state.has("main_fx"):
		return state
	return mode_amounts(state.get("view_mode", 2.0))


## Index of the latest full-raw marker whose transition to raw has completed by `t` (-1 if none): at its anchor for a
## ramp, anchor+duration for a damp. Cutting only after completion keeps the reset pop-free (presence is already zero).
## A later marker becomes at_time()'s governing `cur` from its arrival, so if one takes the screen back to masked/pip
## before the raw damp completes, main_fx never reaches 0 and a rebase from the raw marker's arithmetic alone would
## erase a stack still fully visible. A raw marker is only superseded, never doubled back to, so checking for one
## later marker starting before `done` suffices.
func _barrier_index(t: float) -> int:
	var idx := -1
	for i in markers.size():
		var m: Dictionary = markers[i]
		if int(m.get("view_mode", 2.0)) != 2:
			continue
		var done: float = float(m.time)
		if int(m.get("kind", 0.0)) == 1:
			done += maxf(0.001, float(m.get("duration", 1.0)))
		if t < done:
			continue
		var superseded := false
		for j in range(i + 1, markers.size()):
			if float(markers[j].time) < done:
				superseded = true
				break
		if not superseded:
			idx = i
	return idx


## A marker's own in-envelope at `t`: 0 before its window, easing to 1 across it, 1 after. Closed form, no recursion.
##   ramp: rises over [time - duration, time]     damp: rises over [time, time + duration]
static func _envelope(m: Dictionary, t: float) -> float:
	var d: float = maxf(0.001, float(m.get("duration", 1.0)))
	var anchor: float = float(m.time)
	if int(m.get("kind", 0.0)) == 0:
		return clampf((t - (anchor - d)) / d, 0.0, 1.0)
	return clampf((t - anchor) / d, 0.0, 1.0)


## Whether `b` is close enough to `a` in scale and placement to be the same instance keyframed again, not an unrelated
## burst sharing an effect and hue. Loose (50% scale tolerance, a real pan radius): it rejects only wholesale
## reconfigurations.
static func _same_instance(a: Dictionary, b: Dictionary) -> bool:
	var scale_a := maxf(0.05, float(a.get("fx_scale", 1.0)))
	var scale_b := maxf(0.05, float(b.get("fx_scale", 1.0)))
	var scale_ratio: float = maxf(scale_a, scale_b) / minf(scale_a, scale_b)
	var pos_a := Vector2(float(a.get("fx_x", 0.0)), float(a.get("fx_y", 0.0)))
	var pos_b := Vector2(float(b.get("fx_x", 0.0)), float(b.get("fx_y", 0.0)))
	return scale_ratio <= 1.5 and pos_a.distance_to(pos_b) <= 0.15


## The layer stack at time `t`, chronological (oldest first: the shader applies them in order). Each entry bakes its
## marker's LAYER_FIELDS plus "env", the layer's current envelope.
##
## Layering is additive: an applying marker never touches earlier layers. Only a RESTORE marker (effect ==
## EFFECT_RESTORE) closes earlier layers, every one whose target hue lies within its own `threshold` of its picked
## color, by (1 - restore_env * restore intensity) over its window. Restores compose multiplicatively and never appear
## as drawn layers. Fully-out layers are dropped; beyond MAX_LAYERS the oldest go.
func layers_at(t: float) -> Array:
	var out := []
	# The raw checkpoint: layers exist only back to the latest completed transition into full raw (the rebase).
	var start := _barrier_index(t) + 1
	# Continuation partners are merged into the chain that claimed them, so the outer loop must not emit them again.
	var consumed := {}
	for i in range(start, markers.size()):
		if consumed.has(i):
			continue
		var m: Dictionary = markers[i]
		var e := int(m.get("effect_a", 0))
		if e == EFFECT_RESTORE or e == EFFECT_CLEAR:
			continue   # they act on other layers; they draw nothing
		var env := _envelope(m, t)
		if env <= 0.0005:
			continue
		# `cur` is the field values actually drawn: m's own, until a continuation partner takes over.
		var cur: Dictionary = m
		for j in range(i + 1, markers.size()):
			var mj: Dictionary = markers[j]
			var ej := int(mj.get("effect_a", 0))
			if ej == EFFECT_CLEAR:
				env *= 1.0 - _envelope(mj, t) * clampf(float(mj.get("intensity_a", 1.0)), 0.0, 1.0)
				continue
			# Continuation: a later marker with the same effect on the same color is the same channel keyframed again and
			# takes over its predecessor through its own envelope, as one layer with interpolated field values drawn once.
			# Two layers with complementary envelopes would be wrong for fire/freeze/smoke/whisp: they add an emissive
			# body on top of an already-suppressed color, suppression compounds sub-additively (two 44%/56% consumes eat
			# less than one 100% consume) while the emissive sums to 100%, so the footage under the glow flares up
			# mid-crossfade. Hue alone is a weak signal (fire's natural hue is ~0.02, so two default fire bursts match),
			# so the pattern's placement must also agree: scale within 50% and pan within a small radius. Genuine
			# continuations (seeded by add_marker's copy-the-predecessor, then tweaked a little) satisfy this.
			if ej == e and hue_dist(float(cur.get("hue_a", 0.0)), float(mj.get("hue_a", 0.0))) <= 0.02 \
					and _same_instance(cur, mj):
				var f := _envelope(mj, t)
				if f <= 0.0005:
					continue   # mj hasn't started rising yet - cur stands as-is
				consumed[j] = true
				if f >= 0.9995:
					cur = mj   # fully handed off - mj IS the layer now
				else:
					var blended := {}
					for key in LAYER_FIELDS:
						blended[key] = lerpf(float(cur.get(key, DEFAULTS.get(key, 0.0))),
							float(mj.get(key, DEFAULTS.get(key, 0.0))), f)
					cur = blended
				continue
			if ej != EFFECT_RESTORE:
				continue
			var reach: float = maxf(0.02, float(mj.get("threshold", 0.24)))
			if hue_dist(float(cur.get("hue_a", 0.0)), float(mj.get("hue_a", 0.0))) <= reach:
				env *= 1.0 - _envelope(mj, t) * clampf(float(mj.get("intensity_a", 1.0)), 0.0, 1.0)
		if env <= 0.0005:
			continue
		var layer := {"env": env}
		for key in LAYER_FIELDS:
			layer[key] = cur.get(key, DEFAULTS.get(key, 0.0))
		out.append(layer)
	while out.size() > MAX_LAYERS:
		out.pop_front()
	return out


## The resolved state at time `t`: the global keying scalars (lerped through transition windows), the discrete
## view_mode and its derived presence AMOUNTS (lerped), and "layers" from layers_at(). Everything a consumer needs to
## draw the frame. want_layers=false skips the O(markers^2) layers_at(): the recursive calls that resolve the source
## state a transition window blends from read only the globals, amounts and pip_track.
func at_time(t: float, want_layers := true) -> Dictionary:
	if markers.is_empty():
		var d0 := DEFAULTS.duplicate()
		d0.merge(mode_amounts(d0.get("view_mode", 2.0)))
		d0["layers"] = []
		return d0
	var cur = null
	var cur_i := -1
	var nxt = null
	for i in markers.size():
		var m: Dictionary = markers[i]
		if m.time <= t:
			cur = m
			cur_i = i
		elif nxt == null:
			nxt = m

	# DEFAULTS (not markers[0]) before the first marker: its discrete values must not leak backward.
	var governing: Dictionary = cur if cur != null else DEFAULTS
	var out := {}
	out["view_mode"] = governing.get("view_mode", DEFAULTS.get("view_mode", 2.0))
	# pip_track is a discrete source selector: it does not blend (the inset's visibility does, via the amounts below).
	out["pip_track"] = float(governing.get("pip_track", 0.0))
	out.merge(mode_amounts(out["view_mode"]), true)
	for key in GLOBAL_CONTINUOUS:
		out[key] = float(governing.get(key, DEFAULTS.get(key, 0.0)))

	# Ramp window: the approaching marker's stage (view_mode) is up from the window's start while its presence amounts
	# and the global scalars ease in. The source is what was active as the window opened, recursed and nudged strictly
	# earlier (querying the exact boundary would resolve this same window again, forever).
	var approaching = nxt if nxt != null else (markers[0] if cur == null else null)
	if approaching != null and int(approaching.get("kind", 0.0)) == 0:
		var d: float = maxf(0.001, float(approaching.get("duration", 1.0)))
		var span_start: float = float(approaching.time) - d
		if t >= span_start and t <= float(approaching.time):
			var src := at_time(span_start - 0.001, false)
			var f := (t - span_start) / d
			for key in GLOBAL_CONTINUOUS:
				out[key] = lerpf(float(src.get(key, DEFAULTS.get(key, 0.0))),
					float(approaching.get(key, DEFAULTS.get(key, 0.0))), f)
			out["view_mode"] = approaching.get("view_mode", DEFAULTS.get("view_mode", 2.0))
			var src_amt := _amounts_of(src)
			var dst_amt := mode_amounts(out["view_mode"])
			# pip_track picks which video fills the inset: a hard content swap, not a blend. Swapping at window open would
			# show the wrong source at the old side's opacity. Whichever side has the greater inset presence owns the
			# content, so the swap lands only once the other side has faded past it.
			out["pip_track"] = float(approaching.get("pip_track", 0.0)) \
				if float(dst_amt.get("inset_show", 0.0)) >= float(src_amt.get("inset_show", 0.0)) \
				else float(src.get("pip_track", 0.0))
			for key in AMOUNT_FIELDS:
				out[key] = lerpf(float(src_amt.get(key, 0.0)), float(dst_amt.get(key, 0.0)), f)

	# Damp window: the just-passed marker's globals and presence accumulate from the prior state toward its own;
	# f clamps at 1.
	if cur != null and int(cur.get("kind", 0.0)) == 1 and t >= float(cur.time):
		var d: float = maxf(0.001, float(cur.get("duration", 1.0)))
		# If cur interrupted an earlier damp-to-raw marker's trail (its window still open when cur arrived), that fade
		# keeps counting down on its own clock and cur does not start accumulating until it is done. Otherwise a long
		# fade to raw would read as complete until the next anchor, then reverse and rebuild.
		var start_t := float(cur.time)
		var prev_raw_done = null   # prev's own resolved state at start_t, if gated - see below
		if cur_i > 0:
			var prev: Dictionary = markers[cur_i - 1]
			if int(prev.get("kind", 0.0)) == 1 and int(prev.get("view_mode", 2.0)) == 2:
				var prev_done: float = float(prev.time) + maxf(0.001, float(prev.get("duration", 1.0)))
				if prev_done > start_t:
					start_t = prev_done
					prev_raw_done = prev
		# While gated (t before start_t), prev's own damp-to-raw is mid-flight: ride that curve. cur is prev's immediate
		# successor arriving before prev's trail finishes, so prev never becomes the real barrier (see _barrier_index's
		# supersession check); treating it as already raw would pop presence to zero.
		if prev_raw_done != null and t < start_t:
			var pd: float = maxf(0.001, float(prev_raw_done.get("duration", 1.0)))
			var pf := clampf((t - float(prev_raw_done.time)) / pd, 0.0, 1.0)
			var psrc := at_time(float(prev_raw_done.time) - 0.001, false)
			for key in GLOBAL_CONTINUOUS:
				out[key] = lerpf(float(psrc.get(key, DEFAULTS.get(key, 0.0))),
					float(prev_raw_done.get(key, DEFAULTS.get(key, 0.0))), pf)
			var psrc_amt := _amounts_of(psrc)
			var pdst_amt := mode_amounts(prev_raw_done.get("view_mode", 2.0))
			out["pip_track"] = float(prev_raw_done.get("pip_track", 0.0)) \
				if float(pdst_amt.get("inset_show", 0.0)) >= float(psrc_amt.get("inset_show", 0.0)) \
				else float(psrc.get("pip_track", 0.0))
			for key in AMOUNT_FIELDS:
				out[key] = lerpf(float(psrc_amt.get(key, 0.0)), float(pdst_amt.get(key, 0.0)), pf)
			if want_layers:
				out["layers"] = layers_at(t)
			return out
		# `src` is the state at the moment cur may start accumulating. When gated, that is prev's own fully-arrived values
		# (at_time(start_t - 0.001) would re-enter this same window: infinite recursion).
		var src: Dictionary
		if prev_raw_done != null:
			src = prev_raw_done.duplicate()
			src.merge(mode_amounts(prev_raw_done.get("view_mode", 2.0)), true)
		else:
			src = at_time(start_t - 0.001, false)
		var f := clampf((t - start_t) / d, 0.0, 1.0)
		for key in GLOBAL_CONTINUOUS:
			out[key] = lerpf(float(src.get(key, DEFAULTS.get(key, 0.0))),
				float(cur.get(key, DEFAULTS.get(key, 0.0))), f)
		var src_amt := _amounts_of(src)
		var dst_amt := mode_amounts(cur.get("view_mode", 2.0))
		# The same pip_track pop-guard as the ramp window: the initial pass set out["pip_track"] to cur's value, wrong
		# while its inset presence has not accumulated past what was showing before.
		out["pip_track"] = float(cur.get("pip_track", 0.0)) \
			if float(dst_amt.get("inset_show", 0.0)) >= float(src_amt.get("inset_show", 0.0)) \
			else float(src.get("pip_track", 0.0))
		for key in AMOUNT_FIELDS:
			out[key] = lerpf(float(src_amt.get(key, 0.0)), float(dst_amt.get(key, 0.0)), f)

	if want_layers:
		out["layers"] = layers_at(t)
	return out


## This marker's active span: [time-duration, time] for a ramp, [time, time+duration] for a damp. Exposed so the
## timeline can draw the span without re-deriving the math.
func marker_span(m: Dictionary) -> Vector2:
	var d: float = maxf(0.001, float(m.get("duration", 1.0)))
	var anchor: float = float(m.time)
	var is_damp: bool = int(m.get("kind", 0.0)) == 1
	return Vector2(anchor, anchor + d) if is_damp else Vector2(anchor - d, anchor)


## Flatten a marker to its scalar vector, in VECTOR_FIELDS order.
static func to_vector(m: Dictionary) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for key in VECTOR_FIELDS:
		v.append(float(m.get(key, DEFAULTS.get(key, 0.0))))
	return v


## Rebuild a marker dictionary from a vector produced by to_vector().
static func from_vector(v: PackedFloat32Array) -> Dictionary:
	var m := {}
	for i in VECTOR_FIELDS.size():
		m[VECTOR_FIELDS[i]] = v[i] if i < v.size() else DEFAULTS.get(VECTOR_FIELDS[i], 0.0)
	return m


## The whole timeline as a matrix (one row per marker, columns = VECTOR_FIELDS).
func to_matrix() -> Array:
	var rows := []
	for m in markers:
		rows.append(to_vector(m))
	return rows


func to_dict() -> Dictionary:
	return {
		"source_path": source_path, "video_path": video_path, "audio_path": audio_path,
		"duration": duration, "clip_in": clip_in, "clip_out": clip_out, "tracks": tracks,
		"main_volume": main_volume, "main_fade_in": main_fade_in, "main_fade_out": main_fade_out,
		"playhead": playhead, "timeline_zoom": timeline_zoom, "timeline_view_start": timeline_view_start,
		"vector_fields": VECTOR_FIELDS, "markers": markers,
	}


func save(path: String) -> bool:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func load(path: String) -> MaskSession:
	if not FileAccess.file_exists(path):
		return null
	var fa := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(fa.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var s := MaskSession.new()
	s.source_path = String(parsed.get("source_path", ""))
	s.video_path = String(parsed.get("video_path", ""))
	s.audio_path = String(parsed.get("audio_path", ""))
	s.duration = float(parsed.get("duration", 0.0))
	s.clip_in = float(parsed.get("clip_in", 0.0))
	s.clip_out = float(parsed.get("clip_out", -1.0))
	s.main_volume = float(parsed.get("main_volume", 1.0))
	s.main_fade_in = float(parsed.get("main_fade_in", 0.0))
	s.main_fade_out = float(parsed.get("main_fade_out", 0.0))
	s.playhead = float(parsed.get("playhead", 0.0))
	s.timeline_zoom = float(parsed.get("timeline_zoom", 1.0))
	s.timeline_view_start = float(parsed.get("timeline_view_start", 0.0))
	for t in parsed.get("tracks", []):
		s.tracks.append(t)
	for m in parsed.get("markers", []):
		s.markers.append(m)
	s.markers.sort_custom(func(a, b): return a.time < b.time)
	return s

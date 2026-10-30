extends CanvasLayer
class_name MaskEditor

## MaskEditor - the mask-mode authoring surface.
##
## Load a clip, key two colors apart (per-pixel hue classification, see
## shaders/mask_split.gdshader), place MARKERS where the split/effect should
## change, scrub the timeline, export. See src/masking/mask_session.gd for the data
## model - a session's markers are fixed-schema scalar vectors, not free-form
## params, and every one is either a RAMP (eases in before its anchor) or a DAMP
## (accumulates after it) - there's no third, undifferentiated "marker" kind.
##
## Standalone by design: a mask session is tied to one specific external clip, not
## the audio-reactive show, so this does NOT route through the Director, and the clip
## plays through its own players - the video the master clock. Only the shared
## transport's verbs leave it, handed to the shell whose furniture the transport is
## ([method Shell.conduct_transport]): the editor CONDUCTS it ([method transport_hooks]),
## so ▶, ■, the rail, Space and the arrows are the same as in every mode, and its
## timeline stands above the rail ([method bottom_lift]). Two
## entry points (see main.gd):
##   --mask-edit [path]    interactive editor (this file's normal mode)
##   --mask-render <json>  the export relaunch's headless-ish render mode
##                         ([member render_mode] = true; no panel, autoplay, quits
##                         when the audio ends - mirrors --export/_export_mode).
##
## Widget choices mirror the rest of ghost: the timeline is a bespoke-drawn Control
## ([MaskTimeline]), the export button/status/FileDialog are
## the exact pattern from exporter.gd, color entry is Godot's native
## ColorPickerButton (precision input, not an "instrument" worth hand-drawing).
##
## The preview's view modes (see MaskSession.VIEW_MODES + _build_video_composition)
## are the main screen and the inset as independent axes - raw, inset-raw, inset-fx,
## both-fx, full-fx - cycled in that "evolution" order by one button (VIEW_CYCLE).
## Only one video ever decodes ([member _player], always raw); the fx layers just
## re-draw its decoded texture through [const SHADER], each only while visible - so
## "raw" costs no shader pass at all.
##
## view_mode is a per-MARKER field (see MaskSession.VECTOR_FIELDS), not an editing-
## only preference: the toggle button edits the marker at the playhead exactly like
## every other panel control (see _edit), the live preview always renders whatever
## session.at_time() resolves to, and the export relaunch (render_mode) runs the
## identical per-frame logic - so a marker set to "raw" plays raw in the rendered
## file too, not just live. What you see while editing is what you get.
##
## THE REGION is the one control here that is spatial rather than chromatic, and
## it is UNIVERSAL - not an entry in EFFECT_CONTROLS, because "where may this
## layer act" is meaningful for every effect. Each marker carries a box in frame
## UV (reg_x0/y0/x1/y1 + reg_soft) which multiplies into its layer's on-screen
## weight, so confining a layer is the same operation as fading it, resolved per
## pixel; the default is the whole frame. It exists because a color key cannot
## separate two things that ARE the same color - a yellow wall and a gold coin
## in front of it - and their positions separate them trivially. The box is
## dragged on the video itself, not typed (see _build_region_overlay).
##
## ANY FRAME SHAPE. The clip's own pixel dimensions are read once ([member
## _src_size]) and are the only thing that decides the picture's geometry: the
## editor fits the whole frame inside its video area (a portrait phone clip gets
## black bars left and right, a wide one keeps them above and below), the effects'
## patterns stay isotropic through the shader's `u_aspect`, and the export records
## at the SOURCE's resolution - a 1080x1920 clip renders a 1080x1920 movie. Nothing
## in here assumes 16:9; see _src_size and _write_render_override.

const SHADER := preload("res://shaders/mask_split.gdshader")
const PAINT_SIM_SHADER := preload("res://shaders/clown_paint.gdshader")
const UMBRA_SIM_SHADER := preload("res://shaders/umbra_field.gdshader")
const MASKS_DIR := "res://masks"

## The panel's width, as every note's panel has it ([SidePanel]); the video, the timeline and the
## lanes start past it and its margin on both sides.
const PANEL_W := 380.0
const VIDEO_LEFT := PANEL_W + 2.0 * SidePanel.MARGIN

# Picked via _sort_dropdown - see _apply_sort for what each one does.
const _SORT_MODES := ["A → Z", "Z → A", "Energy"]

## Set by main.gd before open_source() for the --mask-render relaunch: skip the
## editing panel, autoplay from t=0, quit when the audio finishes.
var render_mode := false

## The note this editor is (set by main), where a clip chosen here is written - "" from the
## command line.
var note_path := ""

## Set by main: (path: String) -> void - open the note again, once its clip has been detached.
var reopen: Callable
var session: MaskSession = null
var _session_path := ""       # res://-relative or absolute; wherever it was loaded from
var _player: VideoStreamPlayer     # always the RAW decode - never carries the shader
var _audio: AudioStreamPlayer
var _audio_thread: Thread = null   # loads the (large, uncompressed) main WAV off the main thread
var _render_t := 0.0               # accumulated MOVIE time in render mode - the deterministic
                                   #   export clock (sum of the fixed-fps _dt), authoritative over
                                   #   the video/audio stream clocks, which can drift or end early
var _autostart_pending := false    # live autostart is HELD (video paused on frame 1) until the
                                   #   threaded audio attaches, so the intro never plays audio-less
                                   #   and skips - _poll_audio_thread begins playback, synced (below)
var _pending_restore := -1.0       # playhead seconds to seek to once the player is ready (see _process)
var _pending_restore_tries := 0
var _reload_check_pid := -1        # headless compile check gating a reload (see _do_restart)
var _reload_check_log := ""

## Set when a reload was requested while an export was mid-flight (_render_state !=
## "idle") - see _reload_requested. _poll_render re-fires the request once the export
## finishes, same deference the assistant already gets in reload_when_idle: a restart
## quits this process, and Godot kills the child processes it created (see assistant.gd's
## _closing doc) - including the render/transcode subprocess an export is waiting on.
var _reload_after_export := false

## Set the instant _restart_now actually commits to quitting (after its own final
## _save_session capture) - see _save_session and _exit_tree for why this exists.
var _restarting := false

# One material PER LAYER: the main overlay and the inset can be mid-transition at
# different presences (e.g. fx-inset -> both: the inset holds full while the main
# overlay fades in), and a layer's presence multiplies into its own intensities -
# impossible with one shared material.
var _mat_main := ShaderMaterial.new()
var _mat_inset := ShaderMaterial.new()
var _playing := false
var _audio_holding := false   # main audio paused-in-place, waiting for video to catch up (see _process)
var _av_debug_ms := 0         # GHOST_AV_DEBUG throttle
var _av_reported := false     # the once-per-run audio path summary has been printed
var _audio_hold_ms := 0       # when that hold engaged - it is not allowed to last forever

## The longest the audio may be held waiting for the video. A readback stall is
## tens of milliseconds; anything past this is not a stall but a machine that is
## not keeping up, and continuing to wait is just silence.
const _AUDIO_HOLD_LIMIT_MS := 1200
var _cursor_idle_t := 0.0
const _CURSOR_HIDE_DELAY := 1.5   # seconds of stillness during playback before the mouse cursor hides
var _fx_overlay: TextureRect       # full-frame fx layer - shaded copy of whichever source is active
var _cont_view: TextureRect        # full-frame RAW layer for an active continuation track (see MaskTracks.sync) -
                                   # _player's own raw picture is only valid while session.main_visible_at's
                                   # own-clip half holds; once a continuation track owns time t, this shows
                                   # THAT track's own independently-decoded frame instead (never _player's -
                                   # see continuation_track_at's doc for why the two used to be conflated)
var _pip_view: TextureRect         # the inset's content - shaded or raw per view mode
var _mask_wrap: PanelContainer     # the inset's border/placement box (holds _pip_view)
var _view_label: Label     # passive view-mode readout (the old cycle button; V cycles now)
var _help_panel: PanelContainer
var _panel: SidePanel              # the editor's panel (see _build_panel)
var _src_panel: SidePanel          # the panel while no clip is open (see _build_source_panel)
var _src_link: LineEdit
var _peek_raw := false     # DISPLAY-ONLY raw override; never touches session data (hold P)
var _last_inset_show := 0.0   # this frame's resolved inset_show - MaskTracks.sync reads it too,
                               # so a track's own PiP box respects the same view-mode gate as _mask_wrap
var _pip_track := 0           # this frame's resolved pip_track: 0 = main clip in the PiP, k = track (k-1)
var _timeline: MaskTimeline
var _tview: TimelineView          # shared pixel<->time mapping - see timeline_view.gd
var _video_area: AspectRatioContainer  # letterboxed video slot - see MaskTracks.refresh_lanes
var _lanes_col: VBoxContainer     # primary clip's trim lane + one per imported track
var _composition_parent: Control  # holds _player/_fx_overlay/_mask_wrap - track PiP views land here too


# YouTube / URL import runtime (see [MaskUrlImport])
var _yt_state := "idle"    # idle | provisioning | downloading
var _yt_pid := -1
var _yt_step_started := 0.0   # unix time the CURRENT step began - the elapsed readout
var _yt_echoed := {}       # WARNING/ERROR lines already print()-echoed live (a set)

# The clown face model (see _update_face_model): eyes / mouth / oval /
# tint, fitted per capture tick, EMA-glided exactly like the anchor. Defaults
# describe a plausible centered face so the paint shows before the first fit.
var _clown_active := false
var _face_eye_l_prev := Vector2(0.42, 0.40)
var _face_eye_l_ema := Vector2(0.42, 0.40)
var _face_eye_r_prev := Vector2(0.58, 0.40)
var _face_eye_r_ema := Vector2(0.58, 0.40)
var _face_mouth_prev := Vector2(0.5, 0.62)
var _face_mouth_ema := Vector2(0.5, 0.62)
var _face_r_prev := Vector2(0.14, 0.20)
var _face_r_ema := Vector2(0.14, 0.20)
var _face_tint_ema := Vector3(0.55, 0.1, -0.5)
var _face_lum_ema := 0.5

# Per-feature sizes, measured from each cluster's own spread, in PLAIN
# SCREEN units (uv) - deliberately NOT eye-distance units: normalizing by
# the pair re-coupled every feature's size to the pair's jitter and the
# whole mask rescaled in lockstep. Each feature breathes on its own.
var _face_eye_lr_prev := 0.035
var _face_eye_lr_ema := 0.035
var _face_eye_rr_prev := 0.035
var _face_eye_rr_ema := 0.035
var _face_mouth_r_prev := Vector2(0.05, 0.028)
var _face_mouth_r_ema := Vector2(0.05, 0.028)

# The face centroid (the coat channel's home + the cracks' local pull) and
# the nose's OWN slow anchor - derived from eyes+mouth but smoothed on its
# own clock, so it does not inherit the pair's frame jitter.
var _face_c_prev := Vector2(0.5, 0.45)
var _face_c_ema := Vector2(0.5, 0.45)
var _face_nose_prev := Vector2(0.5, 0.52)
var _face_nose_ema := Vector2(0.5, 0.52)

# The face model's OWN capture cadence - faster than the echo ring's 0.35s,
# because the mask must chase the face in near-real-time (the half-second
# drift report), while the ring's semantics (8 slots x 0.35s of history)
# must not change. A tick that coincides with an echo capture reuses its
# image instead of paying a second readback.
const _FACE_INTERVAL := 0.15
var _face_slot := -1

## The aspect every hand-tuned bound in the face model was calibrated at. The
## fitted radii are stored in raw uv (the shaders' contract), but a BOUND on a
## width has to be applied in height units - "0.145 of the frame's width" is
## 0.258 frame-heights on a 16:9 clip and 0.082 on a 9:16 phone clip, i.e. the
## same rule crushing a face to a third of its width depending only on what the
## clip's shape happens to be. Converting through this constant keeps 16:9
## footage bit-identical to what those numbers were tuned against, and gives
## every other shape the same physical bound instead of a scaled one.
const FACE_ENV := "face_venv"
var _ft_state := "none"   # none | provisioning | tracking | ready | failed
var _ft_pid := -1
const _FACE_ASP_REF := 1.7778

## What counts as the face's CORE, as a fraction of the peak weight - the mass the
## size fit is allowed to see. See _update_face_model: the weight field is broad by
## design, and letting the broad part set the face's size is what pushed the eye
## pair off the face on real footage.
const _FACE_CORE := 0.35

## KNOWN LOOSE END, measured, deliberately left alone: this fit's own bound
## (0.30 x _FACE_ASP_REF) is nearly twice as wide as the cap the paint sim draws
## the coat with (clown_paint.gdshader's FACE_CAP_XHI). Since rx also sets how far
## out the eye search ranges, on a clip where the key hue is in the background too
## the fit runs wide and the band can reach past the face - far enough to take a
## dark headscarf hanging by a shoulder as an eye. Tightening this to agree with
## the coat's cap looks obviously right and was tried: on 16:9 footage it collapsed
## the detected eye pair (separation 0.164 -> 0.072) and dropped the mouth onto the
## nose, because every other constant here is tuned against a band this wide. It
## needs the whole vertical model re-tuned together, not a one-line tightening.
var _face_prev_lum := PackedFloat32Array()   # 96x54 luminance, for the mouth's motion cue
var _face_motion_mean := 0.0                 # EMA of the face's ambient per-pixel motion
var _face_red_ema := 0.02                    # mean (r-g) over the face - the lips' baseline
var _face_bg_lum := 0.2                      # this frame's whole-frame mean luminance (the
                                             #   brightness cue's floor - see _update_face_model)

# The liquid paint simulation (see shaders/clown_paint.gdshader and
# _step_paint_sim): a ping-pong SubViewport pair holding the persistent,
# advected paint field the mask shader samples as u_clown_paint. Built
# lazily on the first clown frame; stepped on playback-time deltas.
var _paint_vps: Array = []
var _paint_rects: Array = []
var _paint_ping := 0
var _paint_reset := true
var _paint_last_pos := 0.0
var _clown_fs := 1.0   # the live clown layer's Scale knob - the sim's target sizes ride it
var _rain_squall: HSlider
var _au_echo: HSlider
var _au_time: HSlider
var _au_amb: HSlider
var _au_room: HSlider
var _au_reso: HSlider
var _au_bass: HSlider
var _clown_feather_sl: HSlider
var _clown_eye_sl: HSlider
var _clown_steady_sl: HSlider
var _clown_drip_sl: HSlider
var _clown_drip_w_sl: HSlider
var _clown_smudge_sl: HSlider
var _clown_drip_curve_sl: HSlider
var _clown_smile_sl: HSlider
var _clown_curve_sl: HSlider
var _clown_evidence_sl: HSlider

## The clown's four tuning knobs, resolved per frame from the live layer (see
## _apply_frame_state). Each is a view onto a field the keying/pattern groups own
## for other effects and clown never uses - the same idiom umbra's six follow -
## and each DEFAULT REPRODUCES the constant it replaced, so no existing session
## changes look until its author moves a slider.
var _clown_evidence := 0.0   # resonance  - drawn-shape floor vs the picture's own evidence

## THE SHAPE KNOBS, on the three fields Steady/Firm/Lead used to hold.
##
## Those three existed to fight a detector that jittered and lagged. The landmark
## track does neither - it is fitted offline over the whole clip, so there is
## nothing to smooth and nothing to predict - which left three controls on screen
## doing nothing and three stored fields free. They now carry what the effect
## actually lacked, and what a fitted ellipse could never have expressed anyway:
## the SHAPE of the drawn features. (The fallback fitter keeps the old constants
## internally, so it behaves exactly as before when there is no track.)
var _clown_eye_size := 1.0     # threshold - how far the eye patch grows past the eye
var _clown_drip := 0.0         # sat_floor - how far the black runs down the cheek

## The run's WEIGHT and its BOW. Drip says how FAR the liner runs; these two say
## what it looks like on the way, which is the half the author was left with no
## say over at all ("no options to adjust this drop shape, or its position, or
## its curve, or anything"). Width scales the source width the shader measures
## off the eye patch itself, so it stays a fraction of THIS eye whatever size
## Eye size has grown it to; curve scales how far the run bows outboard across
## the cheekbone. Both defaults are the value their field defaults to.
## How far the eye paint is rubbed past its own contour. `swap` was "legacy,
## unused" for as long as the format has existed - see MaskSession's LAYER_FIELDS.
var _clown_smudge := 0.45      # swap        - the eye edge, rubbed rather than cut
var _clown_drip_w := 0.35      # fx_y        - the run's width, x the measured lash line
var _clown_drip_curve := 0.25  # intensity_b - how far it bows out across the cheek
var _clown_smile_w := 1.0      # feather   - the smile's width, past the real mouth
var _clown_smile_curve := 0.0  # fx_speed  - its corners swept up (-) or down (+)

## How far the coat's outer edge fades out, in frame UV. On fx_x - Pan is hidden
## for the clown (it could only slide a face-tracked mask OFF the face), so the
## field is free and this is the control that most wants a home.
var _clown_feather := 0.012

## How wide the CENTERED kernel is that smooths the landmark track, in samples
## (see _ft_point). Because it is centered it costs no lag at any width - the only
## thing a wider one loses is genuinely fast motion, which it rounds off. On
## hue_b, the last field clown had free.
var _ft_sigma := 2.5

## The clown layer's region box, mirrored CPU-side so the face SEARCH honors it
## too (see _face_region_at). Whole frame until the author draws one.
var _clown_region := Vector4(0.0, 0.0, 1.0, 1.0)

## The live audio layer (see _apply_audio_fx); empty when no audio marker governs.
var _audio_layer := {}
var _clown_bleed := 0.0    # its Bleed / Settle / Hollow knobs, fed to the paint sim
var _clown_settle := 0.35
var _clown_hollow := 0.0

## The landmark indices this effect uses, by name rather than by number at the call
## site - MediaPipe's pose order is not guessable and a transposed pair here is a
## ghost whose eyes are in its shoulders.
const PT_NOSE := 0
const PT_EYE_L := 2
const PT_EYE_R := 5
const PT_EAR_L := 7
const PT_EAR_R := 8
const PT_SH_L := 11
const PT_SH_R := 12

## The bootstrap's state, which is about the ENVIRONMENT AND ITS MODELS and not about
## any one window: none | provisioning | ready | failed. "ready" here means the
## tracker can be run, not that any particular window has been read. The pose model
## is `full` rather than `heavy`: on the reference footage `full` found a pose in
## 7451 of 7451 sampled frames, so the heavier model has nothing left to win and
## would cost the window's latency (see the face_venv row in deps.gd).
var _pt_state := "none"
var _pt_pid := -1          # unused by the bootstrap now; kept in the reap list

## THE CAST DIRECTION, accumulated over every window ever loaded this session and
## weighted by each one's own confidence. One window measures it poorly and a dozen
## measure it well, so this improves as the author works rather than being fixed by
## whichever window happened to load first - and a window that measured nothing
## contributes nothing rather than dragging the answer toward its noise.
var _pt_dir := Vector2(1.0, 0.0)

## The silhouette handed to the field sim, kept as one image + texture and rewritten
## in place per sample rather than reallocated - this runs every frame an umbra layer
## is live, and Image.create_from_data on every one of them is heap churn for nothing.
var _pt_slot := -1
var _pt_guard_slot := -1
var _pt_tex: ImageTexture = null
var _umbra_active := false

# THE CAST TRANSFORM, solved per frame from the pose sample at `t + Lead` and
# handed to the field sim as its inverse. It is a SIMILARITY pinned by two
# point pairs - her shoulder line to the ghost's, her eye line to the ghost's -
# so the ghost's head lands exactly where it was placed at any size. The
# effect this replaces magnified about a pivot and hoped, which meant growing
# it walked its head off the top of the frame and every fix traded the looming
# against the eyes.
var _umb_inv0 := Vector2(1.0, 0.0)   # inverse basis, column 0 (aspect-corrected space)
var _umb_inv1 := Vector2(0.0, 1.0)   # ...column 1
var _umb_anchor := Vector2(0.5, 0.5) # where her shoulder line lands, aspect-corrected
var _umb_src := Vector2(0.5, 0.5)    # her own shoulder line, aspect-corrected
var _umb_eye_src := Vector2(0.5, 0.3)# her own eye line, aspect-corrected (the bust's center)
var _umb_unit := 0.3                 # her eye-to-shoulder distance - the unit for everything
var _umb_bust0 := 1.2                # bust falloff, in her own units, from her eye line
var _umb_bust1 := 2.6

# The cast direction, measured over the WHOLE clip by the pose pre-pass (her
# shadow is the part of the background that moves when she does). Furniture,
# not a per-frame measurement.
var _umb_dir := Vector2(1.0, 0.0)
var _umb_pan := Vector2.ZERO
var _umb_stand := 1.05   # Stand  (threshold)   - how far to the side the ghost stands
var _umb_lead := 0.19    # Lead   (feather)     - seconds the ghost moves AHEAD of her
var _umb_lean := 0.45    # Lean   (swap)        - how far it leans along the throw, and rises
var _umb_narrow := 0.35  # Narrow (intensity_b) - how much taller-than-wide it is drawn

# THE GHOST'S EYES: her own eye landmarks pushed through the cast transform, so
# they are on the ghost's head by construction at every size.
var _umb_eye_l := Vector2(0.5, 0.4)
var _umb_eye_r := Vector2(0.6, 0.4)
var _umb_eye_rad := 0.05
var _umb_eyes_ok := false
var _umb_eye_amt := 0.0   # Gaze (sat_floor) - how strongly the eyes read
var _umb_have := false

# The umbra field simulation (ping-pong SubViewport pair, same discipline as
# the clown's paint sim: stepped on PLAYBACK deltas so pause freezes it and
# export traces the identical currents).
var _umb_vps: Array = []
var _umb_rects: Array = []
var _umb_ping := 0
var _umb_reset := true
var _umb_last_pos := 0.0
var _umb_loom := 0.45    # Coverage, with the audio swell already folded in
var _umb_rise := 1.0     # Velocity
var _umb_roil := 0.5     # Contrast
var _umb_wisp := 0.0     # Wisp   (fx_smooth)
var _umb_cling := 0.35   # Cling  (fx_lag)
var _umb_scale := 1.0    # Scale
var _selected: Variant = null   # the marker Dictionary currently shown in the panel
var _color_a: ColorPickerButton
var _hue_a: HSlider   # the Morph slider (fx_tint - palette rotation), decoupled from _color_a
var _threshold: HSlider
var _threshold_label: Label
var _grp_color: VBoxContainer   # "Key color" swatch, pinned above the sortable options below
var _key_color_label: Label     # retitled per effect (umbra's picker names the WALL, not a key)
var _grp_options: VBoxContainer   # every effect option (label+slider pairs), reordered by _apply_sort
var _options: Array = []          # [{label: Label, control: Control}], creation order - see _register_option
var _sort_mode := 2                # index into _SORT_MODES - defaults to Energy, see _apply_sort
var _sort_dropdown: OptionButton
var _feather: HSlider
var _sat_floor: HSlider
var _fx_x: HSlider
var _fx_y: HSlider
var _fx_x_label: Label   # "Pan X/Y" relabeled "Wind X/Y" for snow - direction, not placement
var _fx_y_label: Label
var _fx_scale: HSlider
var _fx_density: HSlider
var _fx_density_label: Label   # "Coverage" relabeled "Stickiness" for crystal (feature conformance)
var _fx_contrast: HSlider
var _fx_contrast_label: Label   # "Contrast" relabeled "Sensitivity" for snow (no keying group of its own)
var _fx_speed: HSlider
var _fx_lag: HSlider
var _fx_lag_label: Label            # "Lag (s)" relabeled "Lead (s)" for oracle - same field, opposite sense
var _fx_smooth: HSlider
var _gust: HSlider   # snow's own Gust slider - a second, independent view onto fx_smooth (see _fx_smooth)
var _undul: HSlider  # fur's Undulation - fur's view onto fx_smooth (same stored-field reuse as _gust)
var _coil: HSlider   # fur's Coil - fur's view onto fx_lag (pushed raw as u_l_lagf; echo bakes its lag into u_l_ew)
var _stick: HSlider  # fur's Stickiness - its OWN field (fx_stick, u_l_stick); 0 = today's free coat
var _bleed: HSlider   # clown's Bleed   - its view onto fx_smooth (see _gust/_undul for the idiom)
var _settle: HSlider  # clown's Settle  - its view onto fx_lag
var _hollow: HSlider  # clown's Hollow  - its view onto fx_stick
var _wisp: HSlider        # umbra's Wisp  - its view onto fx_smooth
var _cling: HSlider       # umbra's Cling - its view onto fx_lag
var _umbra_depth: HSlider # umbra's Depth - its view onto fx_stick
var _umbra_stand: HSlider # umbra's Stand  - its view onto threshold (umbra never keys)
var _umbra_lead: HSlider  # umbra's Lead   - its view onto feather
var _umbra_gaze: HSlider  # umbra's Gaze   - its view onto sat_floor
var _umbra_lean: HSlider  # umbra's Lean   - its view onto swap
var _umbra_narrow: HSlider# umbra's Narrow - its view onto intensity_b
var _color_eye: ColorPickerButton   # umbra's eye color - hue_b, pushed as u_l_accent

## repaint's replacement color. Unlike every other picker here this one is a
## WHOLE color, not a hue: it writes hue_b/fx_stick/fx_tint (h/s/v), so black
## and white are reachable and "replace the yellow wall with black" is one pick.
var _color_paint: ColorPickerButton
var _paint_reach: HSlider           # repaint's Reach - fx_contrast
var _paint_smooth: HSlider          # repaint's Smoothing - fx_smooth

## The region box: a CheckBox that turns it on for the selected marker, a slider
## for its border softness, and the draggable box itself over the video pane.
var _region_on: CheckBox
var _region_soft: HSlider
var _region_drag := ""              # "" | nw/ne/sw/se | n/s/e/w | move
var _resonance: HSlider
var _effect_a: OptionButton
var _intensity_a: HSlider
var _intensity_label: Label   # tooltip swaps meaning for restore/clear, see _update_effect_controls
var _kind: OptionButton     # ramp / damp - see MaskSession.MARKER_KINDS
var _marker_duration: HSlider
var _marker_label: Label
var _time_label: Label

## Whether playback drags the SELECTION along with the playhead (the "Follow"
## switch beside the marker list's header). On by default; off is what lets an
## author hold one marker selected and tune it while the clip runs.
var _follow_playhead: CheckBox
var _marker_list: VBoxContainer   # sequential ramp/damp list, pinned to the panel's bottom
var _history_label: Label   # "Undo: <last action>" preview above the +Ramp/+Damp row, see _refresh_history_label
var _feedback: Node = null    # the shell's backtick console (see _build_feedback); editor mode only
var _was_playing_before_feedback := false
var _status: Label            # shared bottom-right notification - prep AND export
var _export_btn: Button
var _open_dialog: FileDialog
var _prep_video_pid := -1
var _prep_audio_pid := -1
var _prep_state := "idle"        # idle / prepping_video / prepping_audio
var _pending := {}               # source/dir/video/audio paths mid-prep

# Temporal capture (echo ring + whisp anchor): quarter-res snapshots of past
# frames, taken every _ECHO_INTERVAL seconds of PLAYBACK time (slot = position /
# interval, so live preview and the export relaunch capture at the same clip
# positions - the deterministic-clock discipline, one level up from u_time).
# Only runs while a whisp/echo/snow/oracle/serpent/chimera layer is actually on
# screen THIS frame (_temporal_active, set alongside _chimera_active in
# _apply_frame_state) - a session-wide "does this ever use one" check made the
# synchronous GPU readback below run for the ENTIRE session once any one of
# those markers appeared anywhere in it, stuttering unrelated stretches of a
# long timeline (feedback/0016).
var _echo_ring: Array = [null, null, null, null, null, null, null, null]   # ImageTexture, slot-indexed
var _echo_slot := -1
var _prev_pos := -1.0         # last frame's playhead position - lets capture skip an ACTIVE
                              #   scrub drag (position moving) and fire once it settles
var _chimera_active := false  # is a chimera layer on screen THIS frame - gates the track readback
                              #   so it never runs while the (distant) chimera marker isn't rendering
var _temporal_active := false # is a whisp/echo/snow/oracle/serpent/chimera layer on screen THIS
                              #   frame - gates _maybe_capture_echo's readback entirely
var _meta_amount := 0.0       # strongest meta-layer weight on screen THIS frame (0 = none);
                              #   drives the workspace capture and the render-mode chrome reveal
var _workspace_tex: ImageTexture = null  # the editor's own previous frame, captured for the META
                              #   mirror (see _capture_workspace) - null until the first capture
var _meta_chrome: Control = null  # render-mode only: the editor-chrome overlay a META section
                              #   fades in over the clean video (the recorded product demo)
var _chrome_parent: Node = null   # where _build_chrome() parents (self, or _meta_chrome in export)

# The whisp anchor is double-buffered: _anchor_ema is the EMA at the LATEST
# capture, _anchor_prev the one before. The uniform pushed per frame lerps
# between them by position-within-slot (see _push_anchor) - pushing the EMA
# directly stepped the whole pattern once per capture, a visible jump amplified
# by pattern zoom ("jittery, it resets, it jumps"). Position-keyed, so live and
# export trace the identical glide.
var _anchor_prev := Vector2(0.5, 0.5)
var _anchor_ema := Vector2(0.5, 0.5)

# Chimera's landmark FRAME (position + size), double-buffered and glided exactly
# like the centroid above. The MAIN face's modeled size (RMS radius of its
# key/motion mass) and the imported TRACK face's own centroid + size, each an
# EMA over the same thresholds. The shader maps every main pixel through the two
# frames so the graft phase-locks to the main head instead of drifting (see the
# chimera branch in mask_split.gdshader). Defaults degrade to ~the old centered
# clone when a face can't be modeled.
var _anchor_scale_prev := 0.28
var _anchor_scale_ema := 0.28
var _track_anchor_prev := Vector2(0.5, 0.5)
var _track_anchor_ema := Vector2(0.5, 0.5)
var _track_scale_prev := 0.28
var _track_scale_ema := 0.28
var _track_prev_lum := PackedFloat32Array()   # track frame's previous-luminance grid (motion fallback)
const _ECHO_INTERVAL := 0.35

# Wave impulses (whisp only): a fast head turn shows up as a big frame-to-frame
# luminance jolt in the same 48x27 grid _update_whisp_anchor already samples -
# an ONSET detector (motion vs. an adaptive EMA baseline + deviation, not a
# fixed magic threshold) fires an impulse at the anchor's current position, and
# the shader drops a decaying blob of paint there that drifts off along
# whisp's own local current, confined to the volumetric field like the rest of
# whisp (see u_wave_* / wave_wash in mask_split.gdshader) - a drop carried by
# the water, not a ring detached from it. WAVE_SLOTS must match WAVEN in the
# shader.
const _WAVE_SLOTS := 3
const _WAVE_COOLDOWN := 1.1   # seconds; keeps a shaky run from piling up waves
var _wave_prev_lum := PackedFloat32Array()   # last capture's 48x27 luminance grid
var _wave_motion_ema := 0.0
var _wave_dev_ema := 0.02     # seeded so the first few ticks aren't hyper-sensitive
var _wave_last_time := -100.0
var _wave_pos := PackedVector2Array()
var _wave_time := PackedFloat32Array()
var _wave_amp := PackedFloat32Array()
var _wave_slot := 0
var _waveform_pid := -1
var _waveform_path := ""         # set once we know it; polled in _process until it exists
var _wavehi_pid := -1
var _render_state := "idle"      # idle / rendering / transcoding / done
var _render_pid := -1
var _transcode_pid := -1

# Auto-save: every edit marks the session dirty; it saves shortly after the last
# change in a burst (and unconditionally on close), so work persists across
# reloads without a save button and without writing once per slider-drag pixel.
var _dirty := false
var _syncing := false   # true while _refresh_panel repaints controls - _edit must ignore echoes
var _modal_depth := 0   # open popups (color pickers, dropdowns) - suspends the cursor auto-hide
var _autosave_cooldown := 0.0
const _AUTOSAVE_DELAY := 0.4

# Undo/redo: whole-array snapshots of session.markers (small, plain data - cheap
# enough to duplicate wholesale, no need for a diff/command log). A slider drag
# or a marker being dragged along the timeline fires the same mutation dozens of
# times a second, so a drag has to fold into ONE entry or a single Ctrl+Z would
# barely nudge the value back.
#
# THE BOUNDARY IS THE MOUSE BUTTON, not a clock - see _push_undo. A 0.9s coalescing
# window was tried and it fails in both directions at once: pause mid-drag for
# longer than the window and the drag fragments ("every single place where I stop
# will be added to the command history"), make two separate adjustments inside it
# and they merge ("Ctrl+Z often reverts several changes at once"). Both were
# reported. A press opens one entry, the release closes it, and anything that is
# not a drag is its own step.
# Parallel to _undo_stack/_redo_stack - a human-readable description of the
# action each entry captured, so the panel can preview what Ctrl+Z would
# revert (see _push_undo/_refresh_history_label).
## The undo key that the CURRENT mouse-held interaction opened, or "" when the
## button is up. See _push_undo - this is what makes a drag one history entry
## instead of one per place the pointer paused.
var _undo_press_key := ""
var _select_generation := 0   # bumped on every selection change; folded into the coalesce key
const YT_ENV := "ytdlp_venv"

## The bus the clip's sound runs through, with the timeline's effects on it ([MaskAudioFx]).
const MASK_BUS := "MaskFX"
const FT_NOSE_BRIDGE := 168
var _stencil_vp: SubViewport


# the editor's parts
# What used to be sections of this file and is a script of its own now: each holds its own state,
# reads the rest through `editor.`, and is asked a few things by name (next/structure.md, "One
# file, one job").

## THE POSE TRACK is a part of its own ([MaskPoseTrack]): bootstrapped, run a window at a time,
## and read by time. The umbra asks it where she is.
var _pose := MaskPoseTrack.new()

## A LINK WHERE A FILE IS EXPECTED is a part of its own ([MaskUrlImport]): downloaded, polled,
## and handed back to [method open_source].
var _url_import := MaskUrlImport.new()

## THE FACE TRACK is a part of its own ([MaskFaceTrack]): fitted once, read by time, and
## rasterized into the stencil the clown's shader keys on.
var _face := MaskFaceTrack.new()

## THE AUDIO EFFECT is a part of its own ([MaskAudioFx]): the bus, and the timeline applied to it.
var _audio_fx := MaskAudioFx.new()

## UNDO AND REDO are a part of their own ([MaskUndo]): the two stacks of snapshots.
var _undo := MaskUndo.new()

## THE CLIP'S PREPARATION is a part of its own ([MaskPrep]): transcoded once, guarded against a second
## writer, and measured - its length and its frame size.
var _source_prep := MaskPrep.new()

## THE WAVEFORM is a part of its own ([MaskWaveform]): the timeline's strip, crisp under zoom, and
## the sound's envelope read off it.
var _waveform := MaskWaveform.new()

## THE REGION BOX is a part of its own ([MaskRegion]): drawn on, and dragged over, the video itself.
var _region := MaskRegion.new()

## THE EXPORT is a part of its own ([MaskExport]): a Movie Maker relaunch at the clip's own size,
## then the mux.
var _export := MaskExport.new()


## THE TRACKS are a part of their own ([MaskTracks]): the trim lanes, a clip imported onto the
## timeline, and every track kept on the master's time.
var _tracks := MaskTracks.new()


func _init() -> void:
	_tracks.editor = self
	_source_prep.editor = self
	_export.editor = self
	_waveform.editor = self
	_region.editor = self
	_undo.editor = self
	_audio_fx.editor = self
	_pose.editor = self
	_url_import.editor = self
	_face.editor = self


func _ready() -> void:
	layer = 100
	_mat_main.shader = SHADER
	_mat_inset.shader = SHADER
	if not render_mode:
		add_to_group("mask_editor")   # so the Assistant can trigger a reload here (see _do_restart)
		# A render that was killed mid-flight leaves its override.cfg behind, and the
		# next launch would boot into the render's resolution. Harmless to remove even
		# while a render IS running: Godot reads it once, at that process's startup.
		_export.clear_override()
		_build_status_label()   # built up front - prep needs it before a session exists
		_warn_missing_tools()


func _exit_tree() -> void:
	var shell := Shell.of(self)
	if shell != null:
		shell.release_transport(self)
	# Hand the shared export button back on the way out, or leaving Masking would
	# leave every other mode without one - see _build_export_ui.
	var ch_out := _export.chrome()
	if ch_out != null:
		# KEYED, so this can only ever drop Masking's own claims. It used to write
		# `false` / 0.0 outright, which would have clobbered a claim made by whatever
		# came next - see the ordering note on Chrome._bottom_claims.
		ch_out.release_export(&"mask")
		ch_out.release_bottom(&"mask")
	# The ⤓ lives in Chrome's row, which outlives this editor: freed with it, not left behind.
	if _export_btn != null and is_instance_valid(_export_btn) and _export_btn.get_parent() != self:
		_export_btn.queue_free()
	_save_session()
	# Reap every subprocess THIS instance spawned. A detached child keeps running -
	# close the app mid-prep and the ffmpeg transcode carries on invisibly (no "godot"
	# in ps), still touching video.ogv, and the NEXT launch reads the fresh mtime as
	# "already in progress elsewhere" and waits on a writer the user can't see. Killing
	# our own pids is safe - the ECHILD hazard is polling pids we did NOT spawn (see
	# _prep_looks_live's doc). The half-written outputs are already handled: prep re-runs
	# when the lock goes stale and _finish_session rejects truncated video, yt-dlp resumes
	# its own .part.
	#
	# This list is now a BELT, not the braces: every spawn above goes through
	# [Subprocess], so `Boot` reaps anything missing from it when the app closes and the
	# kernel kills the lot if ghost is killed outright. Leaving the explicit list keeps
	# the timing right - these die when MASKING closes, not when the app does, which is
	# what frees video.ogv for the next session.
	for pid in [_prep_video_pid, _prep_audio_pid, _tracks.import_pid, _waveform_pid,
			_wavehi_pid, _yt_pid, _reload_check_pid, _render_pid, _transcode_pid,
			_ft_pid, _pt_pid]:
		Subprocess.stop(int(pid))
	Provision.release(FACE_ENV, "mask editor")
	Provision.release(YT_ENV, "clip download")
	for job in _tracks.audio_jobs:
		Subprocess.stop(int(job.get("pid", -1)))
	# Join the audio loader if it's still running, or Godot warns about an orphaned
	# thread on close.
	if _audio_thread != null and _audio_thread.is_started():
		_audio_thread.wait_to_finish()
		_audio_thread = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Whatever the debounce hasn't flushed yet lands on disk when the editor goes away -
## closing the window mid-burst never loses the last edit. Always save (not only when
## dirty) so the current playhead is captured even after a pure play/scrub with no edit.
## Why Masking cannot be left right now, "" when it can (see main.leave_blocker): its own export
## renders in programs this editor owns, and leaving reaps them. A clip still being prepared is not
## a reason - preparation picks up where it stopped the next time the clip is opened.
func leave_blocker() -> String:
	if _render_pid > 0 or _transcode_pid > 0:
		return "Masking is exporting - leaving now would stop the export. Wait for it to finish."
	return ""


## THE keyboard map (mirrored by the help overlay - keep the two in sync):
## Space play/pause and ←/→/Home seek (the shared transport's) · V cycle view · P hold-to-peek · T import track ·
## Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y undo/redo · F1 help · Esc close help.
## These aren't shortcuts FOR buttons any more - they're the only way; the
## toolbar collapsed to the single Help button. Only live once a clip is
## actually loaded (_player exists); main.gd defers Space entirely while this
## editor is open (see main.gd's KEY_SPACE handling), so this doesn't fight
## Director.next() for the key. echo excluded on undo/redo so a held key
## doesn't spam repeats; a real accident deserves a deliberate press each
## time it's undone.
## Plain _input (not _unhandled_input) so cursor motion resets the idle timer
## even while it's over a panel/button - GUI controls can eat mouse motion
## before it would ever reach _unhandled_input, and hovering the toolbar
## while playing should un-hide the cursor same as moving it over the video.
func _input(event: InputEvent) -> void:
	# THE DRAG BOUNDARY CLOSES HERE, on the release itself - see _push_undo. The
	# first cut closed it in _process, which is wrong for a reason worth writing
	# down: _process returns early in half a dozen states (clip still preparing,
	# audio still transcoding, render mode), so the boundary could stay open across
	# a release and swallow the NEXT adjustment into the previous undo step. _input
	# runs whatever _process is doing, and before any control consumes the event.
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_undo_press_key = ""
	if render_mode:
		return
	# SPACE, THE ARROWS AND HOME ARE THE SHARED TRANSPORT'S ([method transport_hooks]): it takes them
	# before the GUI, wherever the focus is, as this editor did
	# A region drag in flight is tracked HERE, not in the overlay's gui_input, so
	# it survives the cursor leaving the video pane - see _region_drag_motion.
	if _region_drag != "":
		_region.drag_motion(event)
	if not event is InputEventMouseMotion:
		return
	_cursor_idle_t = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if render_mode or _player == null:
		return
	if not event is InputEventKey or event.echo:
		return
	# Hold-to-peek wants the RELEASE too - everything below this wants presses
	# only. Hold beats the old toggle button for its actual job ("let me just
	# look at raw for a second"): letting go always puts the effects back.
	if event.keycode == KEY_P:
		_peek_raw = event.pressed
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if event.keycode == KEY_V:
		_cycle_view_mode()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T:
		_tracks.prompt_import()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F1:
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F5:
		_reload_requested()   # restart-and-restore, deferred until assistant runs finish
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _help_panel != null and _help_panel.visible:
		# Only claim Escape while help is open - otherwise it stays main.gd's
		# quit key. Consuming it here is what keeps closing the overlay from
		# ALSO quitting ghost.
		_help_panel.visible = false
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed:
			_undo.redo()
		else:
			_undo.undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_undo.redo()
		get_viewport().set_input_as_handled()


# --- the source: a clip opened, or asked for ------------------------------------------------------


static func _masks_dir() -> String:
	return MASKS_DIR if OS.has_feature("editor") else "user://masks"


## Masking is the mode that CANNOT work without ffmpeg: every clip is transcoded
## on import, every waveform and thumbnail is an ffmpeg pass, and ffprobe answers
## the frame count. ghost downloads FFmpeg itself, so on a first run it may still be
## on its way: say so at the door, and a clip opened meanwhile waits for it (see
## "waiting_tools" in _process) rather than failing with "prep did not finish".
func _warn_missing_tools() -> void:
	if _have_ffmpeg():
		return
	Provision.ensure("ffmpeg")
	_set_status("⏳  " + Deps.hint("ffmpeg"))


func _have_ffmpeg() -> bool:
	return Deps.has("ffmpeg") and Deps.has("ffprobe")


## `path` is either a prepared session .json, a raw source video (transcoded once
## and cached under masks/<slug>/), or empty (the panel asks for one - see _build_source_panel).
## A file opened here is the note's clip from then on ([method _note_clip]).
func open_source(path: String) -> void:
	if path.is_empty():
		if render_mode:
			return
		_build_source_panel()
		return
	if MaskUrlImport.is_url(path):
		_url_import.download(path)   # downloads, then re-enters here with the local file
		return
	_close_source_panel()
	_note_clip(path)
	if path.get_extension().to_lower() == "json":
		_session_path = path
		session = MaskSession.load(path if path.begins_with("res://") else path)
		if session != null:
			_ready_with_session()
		else:
			_set_status("⚠  Could not read session: " + path)
		return
	var slug := _slugify(path)
	var dir := _masks_dir() + "/" + slug
	var video := dir + "/video.ogv"
	var audio := dir + "/audio.wav"
	_session_path = dir + "/session.json"
	_pending = {"source": path, "dir": dir, "video": video, "audio": audio}
	# Check for a live prep BEFORE trusting anything cached on disk - a file that
	# merely EXISTS may just be mid-write (this is why the real clip's session ended
	# up with duration 0.0: it was opened while an external transcode was still
	# appending to video.ogv, and "exists" isn't "finished"). See _finish_session for
	# the matching duration>0 validation on the fast paths below.
	if _source_prep.looks_live(dir, video):
		_prep_state = "waiting_external"
		_set_status("⏳  Preparing clip (already in progress elsewhere)…")
		return
	var abs_session := ProjectSettings.globalize_path(_session_path)
	if FileAccess.file_exists(abs_session):
		var loaded := MaskSession.load(abs_session)
		if loaded != null and loaded.duration > 0.0:
			session = loaded
			_ready_with_session()
			return
	var abs_video := ProjectSettings.globalize_path(video)
	var abs_audio := ProjectSettings.globalize_path(audio)
	if FileAccess.file_exists(abs_video) and FileAccess.file_exists(abs_audio):
		_source_prep.finish_session(path, video, audio)   # validates duration itself; re-preps if bad
		return
	if not _have_ffmpeg():
		# A first run: FFmpeg is still downloading. The clip waits for it in _process.
		Provision.ensure("ffmpeg")
		_prep_state = "waiting_tools"
		_set_status("⏳  " + Deps.hint("ffmpeg"))
		return
	_source_prep.prep(path, dir, video, audio)


func _prompt_for_source() -> void:
	if _open_dialog != null and is_instance_valid(_open_dialog):
		return
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	# In-window, never native: the portal dialog shows nothing at all on a Linux box without
	# xdg-desktop-portal - and the notes list learned that first.
	_open_dialog.use_native_dialog = false
	_open_dialog.title = "Choose a video for this note"
	_open_dialog.filters = PackedStringArray(["*.mp4, *.mov, *.mkv, *.webm, *.avi ; Videos", "* ; Every file"])
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty():
		_open_dialog.current_dir = downloads
	_open_dialog.size = Vector2i(820, 560)
	_open_dialog.file_selected.connect(func(p: String) -> void:
		_open_dialog.queue_free()
		_open_dialog = null
		open_source(p))
	_open_dialog.canceled.connect(func() -> void:
		_open_dialog.queue_free()
		_open_dialog = null)
	add_child(_open_dialog)
	_open_dialog.popup_centered()


## A NOTE'S CLIP COMES OFF AGAIN: the Clip card's × on [param panel] takes the `clip:` block out of
## the note and opens it as what is left ([method NoteCards.detach]) - its words, as a plain note.
## The session Masking keeps for the clip is its own file and is left as it is. Not while an export
## is under way, and not from the command line, where there is no note.
func _note_detach(panel: SidePanel) -> void:
	if note_path.is_empty() or render_mode or not reopen.is_valid():
		return
	panel.detach_blocker = func(_key: String) -> String: return leave_blocker()
	panel.detach = func(key: String) -> void:
		var err := NoteCards.detach(note_path, key)
		if not err.is_empty():
			push_warning("ghost mask: could not detach the clip from %s - %s" % [note_path.get_file(), err])
			return
		reopen.call(note_path)


## The clip's own name, as the Clip card heads it.
func _clip_name() -> String:
	var src := String(session.source_path) if session != null else ""
	if src.is_empty() and session != null:
		src = String(session.video_path)
	return "▶  " + (src.get_file().get_basename() if not src.is_empty() else "the clip")


## A NOTE WITH NO CLIP YET (a Clip just attached): the panel, with a Clip card asking for one - a video
## file, or a link to download (2026-10-06: the link field left the notes list for the component it
## belongs to - "if we want to import an audio file or a video file - then we should add those
## relevant components/attachments to the note options themselves"). What is chosen is written into
## the note's `clip:` block once it is a file on disk, so the note opens on it from then on.
func _build_source_panel() -> void:
	if _src_panel != null and is_instance_valid(_src_panel):
		return
	_src_panel = SidePanel.new(PANEL_W)
	_src_panel.title = "Masking"
	_src_panel.card_prefix = "masking"
	_note_detach(_src_panel)
	add_child(_src_panel)
	_src_panel.body.add_theme_constant_override("separation", 8)
	_src_panel.pin_title_row(self, false)
	var chips := CardRow.new()
	_src_panel.body.add_child(chips)
	_src_panel.card_row = chips
	var clip: VBoxContainer = _src_panel.add_card("clip", "Clip", &"picture", "clip")
	var none := Label.new()
	none.text = "No clip yet."
	none.add_theme_font_size_override("font_size", 14)
	clip.add_child(none)
	var choose := Button.new()
	choose.text = "Choose a video…"
	choose.focus_mode = Control.FOCUS_NONE
	choose.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	choose.tooltip_text = "A video file: it is prepared once (a minute or two for a long clip) and kept."
	choose.pressed.connect(_prompt_for_source)
	clip.add_child(choose)
	_src_link = LineEdit.new()
	_src_link.placeholder_text = "…or paste a link and press Enter"
	_src_link.tooltip_text = "A YouTube (or any http) link: it is downloaded first, then prepared like a file."
	_src_link.text_submitted.connect(_on_link)
	_src_link.text_changed.connect(func(_t: String) -> void: _src_link.remove_theme_color_override("font_color"))
	clip.add_child(_src_link)


## A link pasted into the source panel: downloaded, then opened. Anything that is not URL-shaped turns
## the field red instead.
func _on_link(text: String) -> void:
	var s := text.strip_edges()
	if s.is_empty():
		return
	if not MaskUrlImport.is_url(s) and (s.begins_with("www.") or s.to_lower().contains("youtu.be") or s.to_lower().contains("youtube.com")):
		s = "https://" + s       # pasted without a scheme
	if not MaskUrlImport.is_url(s):
		_src_link.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	open_source(s)


func _close_source_panel() -> void:
	if _src_panel != null and is_instance_valid(_src_panel):
		_src_panel.queue_free()
	_src_panel = null


## The clip this note opens on: [param path], a file on disk, written into the note's `clip:` block
## when it is not what the block already says.
func _note_clip(path: String) -> void:
	if note_path.is_empty() or render_mode or not FileAccess.file_exists(note_path):
		return
	var ghost := NoteStore.blocks_of(note_path)
	var clip: Variant = ghost.get("clip", {})
	if clip is Dictionary and String((clip as Dictionary).get("path", "")) == path:
		return
	ghost["clip"] = {"path": path}
	var err := FrontMatter.write_block(note_path, ghost)
	if not err.is_empty():
		push_warning("ghost mask: could not write the clip into %s - %s" % [note_path.get_file(), err])


static func _slugify(path: String) -> String:
	var base := path.get_file().get_basename().to_lower()
	var out := ""
	for c in base:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_suffix("_").substr(0, 32)


# --- session ready: the preview, and (unless render_mode) the editing UI --------------------------


func _ready_with_session() -> void:
	if _status != null:
		_status.visible = false
	_player = VideoStreamPlayer.new()
	_player.stream = load(ProjectSettings.globalize_path(session.video_path))
	_player.expand = true
	# Before any layout is built: the editor's video slot is shaped by this, and so
	# is the export's recorded resolution (see _src_size).
	_source_prep.resolve_size()
	# No .material here, ever - the fx layers carry the shader (see
	# _build_video_composition). Which layer combination is shown is a per-marker
	# field, applied every frame in _process identically whether this is the live
	# editor or a render_mode export relaunch - export renders exactly what the
	# timeline says, not a hardcoded "always full masked" look.

	_audio = AudioStreamPlayer.new()
	# Through the effects bus from the start, not switched over later: the bus is
	# neutral until an audio marker says otherwise, and re-routing a playing stream
	# is an audible click.
	_audio_fx.ensure_bus()
	_audio.bus = MASK_BUS
	add_child(_audio)
	# The main audio is a big uncompressed WAV (~170MB / ~3s to read). Loading it on
	# the main thread froze startup for that whole time. Live: load it on a worker and
	# attach it the moment it's ready (_process polls the thread), so the video + UI
	# come up instantly and audio joins a beat later, synced to the current position.
	# Export (render_mode) still loads synchronously - it must have audio from frame 0,
	# deterministically. AudioStreamWAV's static loader is the runtime-safe path (plain
	# load() has no loader for a raw .wav outside the import pipeline).
	var abs_audio := ProjectSettings.globalize_path(session.audio_path)
	# THE COMPRESSED SIDECAR IS THE FAST PATH. audio.wav is raw PCM - about
	# 10 MB per minute, so a 40-minute clip is ~420 MB and takes SECONDS to
	# read however it is threaded. Vorbis decodes lazily, so the same audio
	# as a ~30 MB .ogg attaches effectively instantly. Prep writes both now
	# (see _start_prep_audio); sessions prepared before that derive theirs
	# once, in the background, and are instant from the next open on. The WAV
	# stays: ffmpeg reads it for the waveform strip and the resonance
	# envelope. Same sidecar idea the imported tracks already use.
	var abs_ogg := abs_audio.get_basename() + ".ogg"
	if FileAccess.file_exists(abs_ogg):
		_audio.stream = AudioStreamOggVorbis.load_from_file(abs_ogg)
		_apply_main_volume()
		print("ghost mask: audio ready from sidecar ", abs_ogg.get_file())
	elif render_mode:
		_audio.stream = AudioStreamWAV.load_from_file(abs_audio)
		_apply_main_volume()
	else:
		_audio_thread = Thread.new()
		_audio_thread.start(_load_wav_threaded.bind(abs_audio))
		print("ghost mask: no audio sidecar yet - loading raw WAV (playback holds until it lands)")
		_ensure_audio_ogg(abs_audio, abs_ogg)   # so the NEXT open skips all this

	if render_mode:
		_build_render_view()
		# The resonance envelope must exist BEFORE the first recorded frame, or the
		# export's early frames disagree with the live preview. Nearly always cached
		# already (editing generated it); if not, block briefly on ffmpeg - an export
		# is a batch job, a one-time pause is fine where it wouldn't be live.
		_waveform_path = session.audio_path.get_base_dir().path_join("waveform_sqrt.png")
		var abs_wave := ProjectSettings.globalize_path(_waveform_path)
		if not FileAccess.file_exists(abs_wave):
			Deps.execute("ffmpeg", _waveform.args_for(abs_wave))
		_waveform.load_strip(abs_wave)
	else:
		_build_editor_ui()
		_waveform.ensure()
	# Export loaded its audio synchronously (it must have sound from frame 0), so it
	# can start immediately. Live loads the WAV on a worker thread: starting now would
	# advance the video (the master clock) while the audio is still unattached, and the
	# audio would then join wherever the video already got to - the intro skip on every
	# first run. Hold the autostart instead - show frame 1 paused - and let
	# _poll_audio_thread begin playback the moment the audio is ready, synced from 0.
	if render_mode or _audio_thread == null or not _audio_thread.is_started():
		_play(true)
	else:
		_play(false)   # decode + show the first frame, but hold the clock at the start
		# ...AND ONLY THEN hold the start for the audio: an explicit pause cancels a held start
		# ([method _play]), and this one, made first, had cancelled it - a clip whose sound came
		# off the worker opened paused, its autostart never fired
		_autostart_pending = true
	# THE SHARED TRANSPORT DRIVES THE CLIP from here on ([method transport_hooks]), through the shell
	# whose furniture it is
	var shell := Shell.of(self)
	if not render_mode and shell != null:
		shell.conduct_transport(self, transport_hooks())
	# Land back where the playhead was last time (persisted per session) - only live;
	# an export always starts at clip_in. Deferred to the first _process tick: a
	# VideoStreamPlayer won't accept a seek the same frame it starts playing.
	if not render_mode and session.playhead > 0.05:
		_pending_restore = session.playhead
	# SELECT WHATEVER GOVERNS THE PLAYHEAD, so the panel opens showing the
	# session's real settings.
	# Nothing did this before: _selected stayed null until you clicked a marker
	# or playback happened to cross one, and _refresh_panel falls back to
	# MaskSession.DEFAULTS when nothing is selected. So every control - the wall
	# color swatch included - came up displaying a default while the marker sat
	# there holding the values you had set. Nothing was ever lost on disk; the
	# panel simply was not reading it. Re-picking the color from that state
	# then wrote a fresh near-identical hue, which is why the stored value
	# drifted a little on every restart instead of staying put.
	if not render_mode and not session.markers.is_empty():
		var gov: Variant = _governing_marker(
			session.playhead if session.playhead > 0.0 else 0.0)
		if gov == null:
			gov = session.markers[0]   # playhead sits before the first marker
		_select_marker(gov)


func _build_render_view() -> void:
	var full := Control.new()
	full.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(full)
	_build_video_composition(full)
	for i in session.tracks.size():
		_tracks.build_view(i)
	# Product-demo chrome: if this session uses META anywhere, build the REAL editor
	# chrome (timeline, lanes, control panel) on top of the clean composition, fully
	# transparent. _apply_meta_chrome fades it in per frame with the meta envelope, so
	# the export shows clean video normally and the working editor during a meta
	# section (the recorded demo). Purely additive - no meta markers, nothing built,
	# the clean-video export path is untouched. mouse_filter IGNORE: never interactive.
	if _session_uses_meta():
		_meta_chrome = Control.new()
		_meta_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
		_meta_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meta_chrome.modulate.a = 0.0
		add_child(_meta_chrome)
		_chrome_parent = _meta_chrome
		_build_chrome()
		_chrome_parent = null
		_refresh_panel()
	# The export starts at the TIMELINE start (0), exactly like the live editor: live
	# playback begins at 0 and main_visible_at() never gates on clip_in, so the main
	# clip is shown from source 0 and markers/scenes can (and here do) sit before
	# clip_in. Seeking the export to clip_in instead silently dropped everything before
	# it - the "main video starts ~30s too late, early scenes truncated" report, on a
	# session whose clip_in was 37s. clip_in still bounds the restore clamp and the
	# kept-range END via content_end(); it is simply not the export's start.
	_player.play()
	_player.stream_position = 0.0
	_apply_frame_state(session.at_time(0.0))
	# The export quits on the deterministic movie clock reaching content_end() (see
	# _process), NOT on the audio finishing - an audio track shorter than the session
	# would otherwise cut the movie (and its trailing raw video) short.


func _build_editor_ui() -> void:
	_video_area = AspectRatioContainer.new()
	_video_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_area.offset_left = VIDEO_LEFT
	# THE CLIP'S OWN SHAPE, not a 16:9 assumption: a portrait clip gets a tall
	# narrow slot with black bars left and right (pillarbox), a wide one keeps the
	# bars above and below. AspectRatioContainer centers its single child in
	# whatever is left after VIDEO_LEFT and the lane strip (see MaskTracks.reserve_lanes),
	# so the picture always fits the viewport whole and is never stretched.
	# _sync_source_size re-fits this once the decoder confirms the real size.
	_video_area.ratio = _source_prep.source_aspect()
	add_child(_video_area)

	# A plain Control fills the AspectRatioContainer's one centered/letterboxed slot.
	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_area.add_child(inner)
	_build_video_composition(inner)
	for i in session.tracks.size():
		_tracks.build_view(i)

	_build_chrome()
	_export.build_ui()
	_build_feedback()
	_refresh_panel()
	_apply_frame_state(session.at_time(_player.stream_position))


## Where the interactive chrome (timeline, lanes, control panel) parents. Normally
## `self` (the live editor); during a render-mode export that uses META, it's the
## fading _meta_chrome overlay so a meta section can reveal the real working editor
## over the clean video (the recorded product demo).
func _chrome_host() -> Node:
	return _chrome_parent if _chrome_parent != null else self


## The editor chrome - the marker timeline, the trim/track lane stack, and the
## control panel - built into _chrome_host(). Split out of _build_editor_ui so the
## export path can build the SAME real widgets into an overlay (see _build_render_view
## / _apply_meta_chrome). Prereqs: session and _player already exist.
func _build_chrome() -> void:
	_tview = TimelineView.new()
	_tview.zoom = session.timeline_zoom          # restore the last zoom/pan (see _save_session)
	_tview.view_start = session.timeline_view_start

	_timeline = MaskTimeline.new()
	_timeline.session = session
	_timeline.player = _player
	_timeline.tview = _tview
	_timeline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_timeline.offset_left = VIDEO_LEFT
	_timeline.offset_bottom = -90 - bottom_lift()
	_timeline.offset_top = -90 - bottom_lift()
	_timeline.scrubbed.connect(_on_scrub)
	_timeline.marker_picked.connect(_select_marker)
	_timeline.marker_drag_started.connect(func(_m): _undo.push("", "moved a marker"))
	_timeline.marker_moved.connect(func(_m):
		_refresh_marker_label()
		_mark_dirty())
	_chrome_host().add_child(_timeline)

	# The trim/track lane stack - the primary clip's own trim block, plus one
	# lane per imported track - sits directly above the marker strip, sharing
	# its ruler via the same _tview (see MaskTracks.refresh_lanes for why its height is
	# computed and set explicitly rather than left to container auto-sizing).
	_lanes_col = VBoxContainer.new()
	_lanes_col.add_theme_constant_override("separation", 2)
	_lanes_col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lanes_col.offset_left = VIDEO_LEFT
	_chrome_host().add_child(_lanes_col)
	_tracks.refresh_lanes()

	_build_panel()
	# Every popup in the editor joins the modal counter that suspends the
	# cursor auto-hide (see _guard_popups). Walked from the whole tree, not
	# just the panel, so the toolbar's dropdowns are covered too.
	_guard_popups(self)


## The same backtick feedback console every session has - the SHELL'S ([method
## Shell.attach_feedback]: one console and one Assistant in the app, wired to each other there),
## with mask-specific plumbing handed to it: the descriptor snapshots everything needed to debug a
## masking complaint (playhead, the fully-resolved layer stack at that instant, every marker,
## keying globals, audio envelope), freeze pauses playback while typing (restoring the prior play
## state after), and advance is a no-op - the playhead is the user's business, not the console's.
##
## Masking used to build a console and an Assistant of its own: it predates the shell, and
## launched from the notes that was a second 💬 and a second queue over the same feedback. With no
## shell in the tree (a gate building the editor by hand) there is no console, and nothing to wire.
func _build_feedback() -> void:
	var ch := Shell.of(self)
	_feedback = ch.attach_feedback() if ch != null else null
	if _feedback == null:
		return
	_feedback.describe = _feedback_descriptor
	_feedback.freeze = func(on: bool):
		if on:
			_was_playing_before_feedback = _playing
			_play(false)
		elif _was_playing_before_feedback:
			_play(true)
	_feedback.advance = func(): pass


## Everything I'd want to know about "this frame looks wrong": where we are, what
## the timeline resolved to (including each live layer's full parameter set and
## envelope), the raw marker list, and the session's file identity. The screenshot
## the console pairs with this carries the artifact itself.
func _feedback_descriptor() -> Dictionary:
	var t: float = _player.stream_position if _player != null else 0.0
	var p := session.at_time(t)
	return {
		"mode": "mask",
		"time": t,
		"time_str": Clock.text(t),
		"session_path": _session_path,
		"video_path": session.video_path,
		"source_path": session.source_path,
		"duration": session.duration,
		"resolved_state": p,             # globals + amounts + the live layer stack
		"layer_count": (p.get("layers", []) as Array).size(),
		"markers": session.markers,
		"marker_count": session.markers.size(),
		"audio_env": _waveform.env_at(t),
		"peek_raw": _peek_raw,
		"playing": _playing,
	}


## Wire every popup under `n` into the modal counter, once, at build time.
## Walks rather than naming them so a control added later is covered for free -
## the cursor bug this exists for was reported on the color picker, but every
## dropdown in the panel had exactly the same hole.
func _guard_popups(n: Node) -> void:
	var p: Popup = null
	if n is ColorPickerButton:
		p = (n as ColorPickerButton).get_popup()
	elif n is OptionButton:
		p = (n as OptionButton).get_popup()
	elif n is MenuButton:
		p = (n as MenuButton).get_popup()
	if p != null and not p.about_to_popup.is_connected(_on_modal_open):
		p.about_to_popup.connect(_on_modal_open)
		p.popup_hide.connect(_on_modal_close)
	for c in n.get_children():
		_guard_popups(c)


func _on_modal_open() -> void:
	_modal_depth += 1
	_cursor_idle_t = 0.0
	# Show it immediately rather than waiting for the next frame's elif: the
	# click that opens a picker is the same gesture that needs to keep aiming.
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_modal_close() -> void:
	_modal_depth = maxi(0, _modal_depth - 1)
	_cursor_idle_t = 0.0


## Kick off (or discover already-cached) the timeline's waveform image - fully
## decoupled from playback readiness. Generating it (an ffmpeg pass over the whole
## audio track) can take a couple seconds on a long clip; blocking session-ready on
# that would turn "instant" cache hits back into a wait, so this fires async and the


# --- the composition: the video's layers, and the meta mirror -------------------------------------


## Stacked layers in `parent`'s full rect, shared by both the live editor and
## the render_mode export so they composite identically:
##   _player      raw video, visible underneath everything while the main clip's
##                own kept range covers the current time
##   _cont_view   raw video, same full-rect slot as _player - visible instead of it
##                while a continuation track (see MaskSession.continuation_track_at)
##                owns the current time; never both at once
##   _fx_overlay  full-frame shaded copy of whichever of the above is active (its
##                own material) - the MAIN fx layer
##   _mask_wrap   the bordered inset holding _pip_view (its own material)
## Which layers show, and how strongly, comes from the per-frame AMOUNTS
## (MaskSession.mode_amounts, blended through ramp/damp windows by at_time) -
## applied every frame in _apply_frame_state. A layer's presence multiplies into
## its own material's intensities, which is why each has its own material: the
## inset can hold full fx while the main overlay is still fading in.
func _build_video_composition(parent: Control) -> void:
	_composition_parent = parent   # secondary tracks' PiP views land here too - see MaskTracks.build_view
	parent.add_child(_player)
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Sits at the same full-rect slot as _player, right underneath it in the same
	# z-position - only one of the two is ever visible at once (see _process), so
	# _fx_overlay's shaded copy always has exactly one raw picture beneath it to draw.
	_cont_view = TextureRect.new()
	_cont_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cont_view.stretch_mode = TextureRect.STRETCH_SCALE
	_cont_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cont_view.visible = false
	parent.add_child(_cont_view)

	_fx_overlay = TextureRect.new()
	_fx_overlay.material = _mat_main
	_fx_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fx_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_fx_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_fx_overlay)

	_mask_wrap = PanelContainer.new()
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.set_border_width_all(2)
	border.border_color = Color(1.0, 1.0, 1.0, 0.85)
	_mask_wrap.add_theme_stylebox_override("panel", border)
	# The inset's placement is fixed (bottom-right corner box); only its
	# visibility/presence animates.
	_mask_wrap.anchor_left = 0.66
	_mask_wrap.anchor_top = 0.64
	_mask_wrap.anchor_right = 0.98
	_mask_wrap.anchor_bottom = 0.96
	parent.add_child(_mask_wrap)

	_pip_view = TextureRect.new()
	_pip_view.material = _mat_inset
	_pip_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pip_view.stretch_mode = TextureRect.STRETCH_SCALE
	_mask_wrap.add_child(_pip_view)

	if not render_mode:
		_region.build(parent)   # never in an export - it is a tool, not a look


## The META mirror source: the editor's OWN previous frame, read back from the main
## viewport into u_workspace. A full-window GPU->CPU readback (expensive), so the
## caller (_process) only runs it while a meta layer is actually on screen. Feeding
## this window back into the video surface - which lives IN this window - is the
## infinite mirror; the one-frame delay is inherent and wanted (each frame nests one
## level deeper). Downscaled before upload since the mirror draws small anyway.
func _capture_workspace() -> void:
	# Headless has no real framebuffer to read back (the dummy renderer's viewport
	# texture is null - get_image would error every frame). It also never records a
	# movie, so there is nothing to mirror; the windowed Movie Maker export IS a real
	# GPU context, so this only ever skips genuine no-op cases.
	if DisplayServer.get_name() == "headless":
		return
	var vtex := get_viewport().get_texture()
	if vtex == null:
		return
	var img := vtex.get_image()
	if img == null or img.is_empty():
		return
	if img.get_width() > 960:
		var h := int(round(960.0 * float(img.get_height()) / float(maxi(1, img.get_width()))))
		img.resize(960, maxi(1, h), Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if render_mode:
		img = _shrink_into_video_pane(img)
	var sz := Vector2i(img.get_width(), img.get_height())
	if _workspace_tex == null or _workspace_tex.get_size() != Vector2(sz):
		_workspace_tex = ImageTexture.create_from_image(img)
	else:
		_workspace_tex.update(img)
	_mat_main.set_shader_parameter("u_workspace", _workspace_tex)
	_mat_inset.set_shader_parameter("u_workspace", _workspace_tex)


## In the live editor, the mirror's nesting comes for free: the video pane the shader
## draws onto is genuinely SMALLER than the captured window (see _video_area's
## VIDEO_LEFT inset + 16:9 letterbox in _build_editor_ui), so sampling the whole capture
## back onto that smaller surface shrinks it - and since the capture already contained
## the previous shrink, each frame nests one level deeper. _build_render_view's own
## surface is edge-to-edge (the export must stay a clean, full-bleed video outside a
## meta section - see its comment), so that free shrink doesn't exist there: verified
## by a standalone Movie-Maker readback test (feedback/0001) that a same-size feedback
## quad only ghosts/blurs, never nests. This reproduces the live editor's inset by hand
## - blit a downscaled copy of the capture into the same VIDEO_LEFT/letterbox sub-rect the
## live video pane occupies, over an unshrunk copy of the capture (so the chrome
## painted at its real position, e.g. by _apply_meta_chrome, still reads at full size
## around it) - so feeding this back through the SAME edge-to-edge quad reproduces the
## same receding "hall of mirrors" the live editor gets from its smaller surface.
func _shrink_into_video_pane(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	# VIDEO_LEFT is a fraction of the LIVE EDITOR's window (the base 1920-wide canvas
	# it lays out in), applied to whatever width the capture came back at. The pane
	# inside it fits the CLIP's aspect, same as _video_area does - so a portrait
	# session mirrors a tall narrow pane, not a 16:9 one.
	var asp := _source_prep.source_aspect()
	var px0 := int(round(w * VIDEO_LEFT / 1920.0))
	var avail_w := maxi(1, w - px0)
	var pw := avail_w
	var ph := int(round(float(avail_w) / asp))
	if ph > h:
		ph = h
		pw = int(round(float(h) * asp))
	var py0 := int(round((h - ph) / 2.0))
	var shrunk := img.duplicate()
	shrunk.resize(maxi(1, pw), maxi(1, ph), Image.INTERPOLATE_BILINEAR)
	var canvas: Image = img.duplicate()
	canvas.blit_rect(shrunk, Rect2i(Vector2i.ZERO, Vector2i(pw, ph)), Vector2i(px0, py0))
	return canvas


## Render-mode only: fade the editor-chrome overlay in with the meta envelope, so the
## export shows clean video normally and the real working editor during a meta section.
func _apply_meta_chrome(amount: float) -> void:
	if _meta_chrome == null:
		return
	_meta_chrome.modulate.a = smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))


func _session_uses_meta() -> bool:
	for m in session.markers:
		if int(m.get("effect_a", 0)) == MaskSession.EFFECT_META:
			return true
	return false


# --- the clown's paint and the umbra's field: ping-pong SubViewports ------------------------------


func _ensure_paint_sim() -> void:
	if not _paint_vps.is_empty():
		return
	for i in 2:
		var vp := SubViewport.new()
		# Finer than the echo ring: the deposits now carry per-pixel feature
		# shape, and an eye socket is only a few texels wide at 256x144.
		vp.size = Vector2i(384, 216)
		vp.disable_3d = true
		# Float buffers: the field decays multiplicatively, and 8-bit
		# quantization makes low paint values stick instead of thinning out.
		vp.use_hdr_2d = true
		# The COAT lives in the alpha channel, and a non-transparent viewport
		# FORCES alpha to 1 on its render target - the coat then read as
		# "everywhere" and the paint covered the whole frame, background
		# included. This is state, not a picture: keep every channel intact.
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		var rect := ColorRect.new()
		rect.size = Vector2(384, 216)
		var m := ShaderMaterial.new()
		m.shader = PAINT_SIM_SHADER
		rect.material = m
		vp.add_child(rect)
		add_child(vp)
		_paint_vps.append(vp)
		_paint_rects.append(rect)


## One simulation step per rendered frame while a clown layer is live (the
## META mirror's bounded-feedback discipline): the ping viewport re-renders
## sampling the pong's texture, then the mask materials sample the ping.
## Stepped on PLAYBACK deltas - pause freezes the liquid, and a seek (or the
## first frame) snaps the field to the targets instead of streaming paint
## across the jump.
func _step_paint_sim() -> void:
	if not _clown_active or _player == null:
		return
	_ensure_paint_sim()
	var pos := _player.stream_position
	var dtp := pos - _paint_last_pos
	_paint_last_pos = pos
	var reset := _paint_reset or dtp < -0.05 or dtp > 0.5
	dtp = clampf(dtp, 0.0, 0.1)
	if dtp <= 0.0 and not reset:
		return   # paused/held: the liquid holds; the mats keep last frame's field
	var cm := _face.clown_model_now()
	var mat: ShaderMaterial = _paint_rects[_paint_ping].material
	mat.set_shader_parameter("u_prev", _paint_vps[1 - _paint_ping].get_texture())
	mat.set_shader_parameter("u_dt", dtp)
	mat.set_shader_parameter("u_reset", 1 if reset else 0)
	mat.set_shader_parameter("u_time", pos)
	var vt := _player.get_video_texture()
	if vt != null and vt.get_height() > 0:
		mat.set_shader_parameter("u_aspect", float(vt.get_width()) / float(vt.get_height()))
		# The frame itself: the deposits read their evidence straight out of
		# it (dark socket, red lip line, lit nose ridge) instead of stamping
		# shapes - see clown_paint.gdshader.
		mat.set_shader_parameter("u_frame", vt)
	mat.set_shader_parameter("u_face_lum", _face_lum_ema)
	mat.set_shader_parameter("u_face_red", _face_red_ema)
	mat.set_shader_parameter("u_evidence", _clown_evidence)
	# The contour stencil, and whether there is one. Kept explicit rather than
	# inferred from the texture: a default-black sampler and a genuinely empty
	# face read identically, and one of those must fall back to the ellipses.
	if _stencil_vp != null and _ft_state == "ready":
		mat.set_shader_parameter("u_stencil", _stencil_vp.get_texture())
		mat.set_shader_parameter("u_has_stencil", 1.0)
	else:
		mat.set_shader_parameter("u_has_stencil", 0.0)
	mat.set_shader_parameter("u_drip", _clown_drip)
	mat.set_shader_parameter("u_drip_w", _clown_drip_w)
	mat.set_shader_parameter("u_eye_smudge", _clown_smudge)
	mat.set_shader_parameter("u_drip_curve", _clown_drip_curve)
	mat.set_shader_parameter("u_coat_feather", _clown_feather)
	mat.set_shader_parameter("u_eye_l", cm.eye_l)
	mat.set_shader_parameter("u_eye_r", cm.eye_r)
	mat.set_shader_parameter("u_mouth", cm.mouth)
	mat.set_shader_parameter("u_nose", cm.nose)
	mat.set_shader_parameter("u_face_c", cm.face_c)
	mat.set_shader_parameter("u_face_r", _face_r_ema)
	mat.set_shader_parameter("u_eye_lr", cm.eye_lr)
	mat.set_shader_parameter("u_eye_rr", cm.eye_rr)
	mat.set_shader_parameter("u_mouth_r", cm.mouth_r)
	mat.set_shader_parameter("u_scale", _clown_fs)
	mat.set_shader_parameter("u_bleed", _clown_bleed)
	mat.set_shader_parameter("u_settle", _clown_settle)
	mat.set_shader_parameter("u_hollow", _clown_hollow)
	_paint_vps[_paint_ping].render_target_update_mode = SubViewport.UPDATE_ONCE
	for m2 in [_mat_main, _mat_inset]:
		m2.set_shader_parameter("u_clown_paint", _paint_vps[_paint_ping].get_texture())
	_paint_ping = 1 - _paint_ping
	_paint_reset = false


## UMBRA's field simulation host - the same ping-pong pair the clown's paint
## uses, and for the same two hard-won reasons: transparent_bg because the
## GUARD lives in the alpha channel and a non-transparent viewport FORCES
## alpha to 1 (which would permit the mass everywhere, including on her), and
## CLEAR_MODE_NEVER because the field IS the state.
func _ensure_umbra_sim() -> void:
	if not _umb_vps.is_empty():
		return
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(384, 216)
		vp.disable_3d = true
		vp.use_hdr_2d = true
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		var rect := ColorRect.new()
		rect.size = Vector2(384, 216)
		var m := ShaderMaterial.new()
		m.shader = UMBRA_SIM_SHADER
		rect.material = m
		vp.add_child(rect)
		add_child(vp)
		_umb_vps.append(vp)
		_umb_rects.append(rect)


## One simulation step per rendered frame while an umbra layer is live.
## Stepped on PLAYBACK deltas, so pause freezes the mass mid-curl and the
## export relaunch traces the identical currents; a seek snaps the field to its
## targets rather than streaming smoke across the jump.
func _step_umbra_sim() -> void:
	if not _umbra_active or _player == null:
		return
	_ensure_umbra_sim()
	var pos := _player.stream_position
	var dtp := pos - _umb_last_pos
	_umb_last_pos = pos
	var reset := _umb_reset or dtp < -0.05 or dtp > 0.5
	dtp = clampf(dtp, 0.0, 0.1)
	if dtp <= 0.0 and not reset:
		return
	if not _umb_have or _pt_tex == null:
		return   # no pose there - leave the field alone rather than deposit noise
	var mat: ShaderMaterial = _umb_rects[_umb_ping].material
	mat.set_shader_parameter("u_prev", _umb_vps[1 - _umb_ping].get_texture())
	mat.set_shader_parameter("u_region", _pt_tex)
	mat.set_shader_parameter("u_dt", dtp)
	mat.set_shader_parameter("u_reset", 1 if reset else 0)
	mat.set_shader_parameter("u_time", pos)
	mat.set_shader_parameter("u_aspect", _source_prep.source_aspect())
	mat.set_shader_parameter("u_dir", _umb_dir)
	mat.set_shader_parameter("u_loom", _umb_loom)
	mat.set_shader_parameter("u_rise", _umb_rise)
	mat.set_shader_parameter("u_roil", _umb_roil)
	mat.set_shader_parameter("u_cling", _umb_cling)
	mat.set_shader_parameter("u_wisp", _umb_wisp)
	# The cast transform - see umbra_field.gdshader's to_source().
	mat.set_shader_parameter("u_inv0", _umb_inv0)
	mat.set_shader_parameter("u_inv1", _umb_inv1)
	mat.set_shader_parameter("u_anchor", _umb_anchor)
	mat.set_shader_parameter("u_src", _umb_src)
	mat.set_shader_parameter("u_eye_src", _umb_eye_src)
	mat.set_shader_parameter("u_unit", _umb_unit)
	mat.set_shader_parameter("u_bust0", _umb_bust0)
	mat.set_shader_parameter("u_bust1", _umb_bust1)
	mat.set_shader_parameter("u_eye_l", _umb_eye_l)
	mat.set_shader_parameter("u_eye_r", _umb_eye_r)
	mat.set_shader_parameter("u_eye_rad", _umb_eye_rad)
	mat.set_shader_parameter("u_eye_amt", _umb_eye_amt if _umb_eyes_ok else 0.0)
	_umb_vps[_umb_ping].render_target_update_mode = SubViewport.UPDATE_ONCE
	for m2 in [_mat_main, _mat_inset]:
		m2.set_shader_parameter("u_umbra_field", _umb_vps[_umb_ping].get_texture())
	_umb_ping = 1 - _umb_ping
	_umb_reset = false


## The umbra's per-frame tick. NO READBACK, which is the difference between this
## and _maybe_capture_face: the shape comes from the cached track, so there is no
## get_image() stall, no capture cadence to pick, and nothing that behaves
## differently while the author is scrubbing than it does during playback.
func _tick_umbra() -> void:
	if not _umbra_active or _player == null or session == null:
		return
	_pose.ensure()
	if _pt_state != "ready":
		_umb_have = false
		return
	_umb_solve_cast()


# --- umbra: throwing her shadow -------------------------------------------------------------------
# UMBRA: the ghost that moves her (see _umb_solve_cast and
# shaders/umbra_field.gdshader).
#
# WHAT IT IS. Her own silhouette, thrown as a cast shadow that is larger than
# she is, stands beside her, and reads the clip AHEAD of the playhead - so it
# turns its head before she turns hers, and the picture reads as the ghost
# moving her rather than the other way round.
#
# WHERE THE SHAPE COMES FROM. The pose track (_pt_*), which is MediaPipe's
# person segmentation plus 33 body landmarks, fitted offline over the whole
# clip. What it replaces was a chroma-direction detector that hunted the
# footage's own cast shadow: it needed the room to have one big soft shadow on
# a chromatically uniform wall, a color hypothesis scored per surface, two
# flood fills, and a confidence gate that drew nothing when they disagreed. A
# person mask is the same answer with none of the conditions - and it also
# gives the ghost a SKELETON, which is what lets its head and its eyes be
# placed rather than guessed at from the middle of a blob.


## ONE PLACE where the umbra's knobs are read off a layer, because there were two
## and they drifted: `tests/masking/umbra_look_probe.gd` carried its own copy of these
## mappings, and after Stand's low end was widened the probe went on rendering the
## old range - so the picture it produced to check a change was a picture of the
## code before it. A probe that reproduces the resolve is a probe that can lie.
func _umb_read_layer(l: Dictionary, env: float) -> void:
	# Scale is a real size relative to HER - at 1.0 the ghost is exactly her own
	# size and stands beside her; past that it looms. Its head cannot be pushed off
	# the frame at any setting (see _umb_solve_cast), so this is bounded only by
	# what still reads as a body.
	_umb_scale = clampf(float(l.get("fx_scale", 1.0)), 0.4, 3.2)
	_umb_pan = Vector2(float(l.get("fx_x", 0.0)), float(l.get("fx_y", 0.0))) * 0.25
	# Resonance folds in here exactly as it does for the shader's density array -
	# the loom breathes with the audio, so on a talking clip the ghost surges when
	# the subject speaks.
	var ures := float(l.get("resonance", 0.0))
	_umb_loom = clampf(float(l.get("fx_density", 0.45)) + 0.5 * ures * (env - 0.35), 0.0, 1.0)
	_umb_roil = clampf(float(l.get("fx_contrast", 0.5)), 0.0, 1.0)
	_umb_rise = maxf(0.05, float(l.get("fx_speed", 1.0)))
	_umb_wisp = clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0)
	_umb_cling = clampf(float(l.get("fx_lag", 0.35)), 0.0, 1.0)
	# Umbra-only views onto fields other effects own for their own purposes (umbra
	# never keys, and `swap`/`intensity_b` are the two fields the two-channel era
	# left behind - the clown reads the same pair under its own names).
	#
	# STAND'S LOW END REACHES BEHIND HER (0.55 -> 0.15). It was floored at a
	# clearance of half the two skulls because the guard used to gate the DEPOSIT,
	# so a ghost tucked in close was a ghost eaten by its own exclusion. The mass
	# grows under her now and is only masked at render, so overlapping her is free
	# - it hides behind her and emerges at her edges, which is what "hug the model
	# closer" asks for.
	_umb_stand = 0.15 + clampf(float(l.get("threshold", 0.24)), 0.0, 1.0) * 1.85
	_umb_lead = clampf(float(l.get("feather", 0.12)), 0.0, 0.5) * 1.6
	_umb_eye_amt = clampf(float(l.get("sat_floor", 0.18)), 0.0, 1.0)
	_umb_lean = clampf(float(l.get("swap", 0.45)), 0.0, 1.0)
	_umb_narrow = clampf(float(l.get("intensity_b", 0.35)), 0.0, 0.75)


## THE CAST TRANSFORM, solved for the current playhead.
##
## Everything here happens in ASPECT-CORRECTED space (x multiplied by the frame
## aspect), because every quantity is a distance between two points on a body and
## raw UV is not a unit - "0.145 of the frame's width" is 0.258 frame-heights on
## 16:9 and 0.082 on a phone clip, which is the trap that put the clown's lips
## under its nose.
##
## The construction, and why each part is what it is:
##
##  THE ANCHOR IS THE EYE LINE, not the head's centroid and not the mass's. The
##  eyes are the feature a viewer looks at, so they are the one that must land
##  where it was placed; anchoring anywhere else means the eyes arrive wherever
##  the rest of the geometry leaves them, which is how the effect this replaces
##  ended up with one socket out on bare wall.
##
##  THE GHOST'S HEAD MUST CLEAR HERS. The separation is the two skulls' own
##  half-widths added together, not a tuned constant - so it holds on a close-up
##  and on a wide shot without either being tuned for. Standing it on top of her
##  is what makes the guard eat the ghost: her silhouette is most of a close-up
##  frame, and a ghost behind her is then a thin rind around her outline.
##
##  IT STANDS ON THE SIDE THERE IS ROOM FOR. The measured throw picks the side;
##  if the ghost's head does not fit there, the other side is the honest answer.
##  A head jammed against the frame edge is half a head with one eye.
##
##  THE SIZE IS FREE, AND THE SHAPE IS A BUST. Her silhouette is ~45% of a
##  close-up frame; drawn whole at any magnification it is a wall of black with
##  nothing in it to read. The mass is her HEAD AND SHOULDERS - a radial falloff
##  about her eye line, applied in HER OWN units so it rides the transform with
##  everything else - and below that it dissolves into the field's own smoke.
##  Measured on the reference clip: drawn whole at Scale 2.8 the mass covered 63%
##  of the frame and read as a dimmed room; as a bust it reads as a figure.
func _umb_solve_cast() -> void:
	_umb_have = false
	_umb_eyes_ok = false
	if _player == null or _pt_state != "ready":
		return
	# THE LOOK-AHEAD, and the entire reason the track is offline. Reading the clip
	# at `t + Lead` means the ghost turns its head on the frame she has not reached
	# yet, which is what makes the picture read as the ghost moving HER. A velocity
	# extrapolation cannot do this - it can only continue what just happened, which
	# on real footage is mostly detection noise multiplied by the lead time.
	var t := _player.stream_position + clampf(_umb_lead, 0.0, 2.0)
	var i := _pose.slot_at(t)
	if i < 0:
		return
	if not _umb_cast_from(i, _source_prep.source_aspect()):
		return
	# The guard's own sample: HER, now, not the frame the ghost is drawn from.
	var gi := _pose.slot_at(_player.stream_position)
	if gi < 0:
		gi = i
	if _pt_slot != i or _pt_guard_slot != gi:
		_pt_slot = i
		_pt_guard_slot = gi
		_pose.upload_mask(i, gi)
	_umb_have = _pt_tex != null
	if OS.has_environment("GHOST_UMBRA_DEBUG"):
		print("UMBDBG t=%.2f (+%.2f) sample=%d unit=%.3f scale=%.2f throw=(%.2f,%.2f) "
			% [_player.stream_position, _umb_lead, i, _umb_unit, _umb_scale,
				_umb_dir.x, _umb_dir.y]
			+ "anchor=(%.3f,%.3f) eyeL=(%.3f,%.3f) eyeR=(%.3f,%.3f) rad=%.3f"
			% [_umb_anchor.x / maxf(_source_prep.source_aspect(), 1e-3), _umb_anchor.y,
				_umb_eye_l.x, _umb_eye_l.y, _umb_eye_r.x, _umb_eye_r.y, _umb_eye_rad])


## The geometry itself, split out from the playhead so it can be asserted without
## a clip, a player or a renderer (tests/masking/umbra_cast_check.gd). Reads the live knob
## state, writes every _umb_* transform field, and returns false when this sample
## cannot support a throw at all.
func _umb_cast_from(i: int, asp: float) -> bool:
	# THE FOUR LANDMARKS THE THROW IS BUILT FROM HAVE TO BE SEEN. A shoulder the
	# model placed by inference rather than by looking still returns a plausible
	# point, so without this the ghost's whole body axis can be built out of a
	# guess and nothing about the result looks wrong until it swings. The ears
	# are excluded on purpose - one of them is genuinely hidden whenever a head
	# turns, and half_w falls back on its own floor there.
	for k in [PT_SH_L, PT_SH_R, PT_EYE_L, PT_EYE_R]:
		if _pose.vis_at(i, k) < 0.30:
			return false
	var av := Vector2(asp, 1.0)
	var sh := (_pose.point(i, PT_SH_L) + _pose.point(i, PT_SH_R)) * 0.5 * av
	var eye_l := _pose.point(i, PT_EYE_L) * av
	var eye_r := _pose.point(i, PT_EYE_R) * av
	var eye := (eye_l + eye_r) * 0.5
	var half_w := maxf(absf(_pose.point(i, PT_EAR_L).x - _pose.point(i, PT_EAR_R).x) * asp * 0.5, 0.02)
	var axis := eye - sh
	var unit := axis.length()
	if unit < 1e-3:
		return false
	axis /= unit
	var scale := clampf(_umb_scale, 0.4, 3.2)
	var lean := clampf(_umb_lean, 0.0, 1.0)
	var narrow := clampf(_umb_narrow, 0.0, 0.75)
	# The throw, biased upward: a shadow thrown level reads as a stain on the wall,
	# and the thing being built is a presence that RISES. This is the only place the
	# measured direction is editorialized, and it is deliberate.
	var throw := (_pt_dir + Vector2(0.0, -0.35)).normalized()
	var ghost_hw := half_w * scale * (1.0 - narrow)
	var gap := (half_w + ghost_hw) * clampf(_umb_stand, 0.4, 2.4)
	var lim := ghost_hw + 0.04
	var side := 1.0 if throw.x >= 0.0 else -1.0
	var gx := eye.x + side * gap
	if minf(gx - lim, asp - lim - gx) < 0.0:
		var other := eye.x - side * gap
		if minf(other - lim, asp - lim - other) > minf(gx - lim, asp - lim - gx):
			gx = other
	gx = clampf(gx, lim, maxf(lim, asp - lim))
	# HOW FAR IT RISES IS A FRACTION OF THE HEADROOM THERE IS, not a multiple of
	# her own height. Written the obvious way - eye.y minus some number of her
	# units - it is pinned against the top clamp on any close-up, because her eyes
	# are already near the top of such a frame: measured, a whole sweep of Lean
	# produced eye heights of 0.1559, 0.1559, 0.1559 and 0.1559, i.e. a control
	# that did nothing. Against the ceiling it always moves, and on a wide shot
	# the same setting reads as a much bigger rise, which is right.
	#
	# THE CEILING IS WHERE ITS SOCKETS STILL FIT, not where its skull does. A
	# ghost this size has a crown taller than the headroom of a close-up, and
	# demanding the whole head stay in frame is the same pin one step further out:
	# it leaves nothing to rise into. A shadow whose crown leaves the top of the
	# picture is a shadow that is bigger than the picture, which is the point.
	var ceil_y := clampf(ghost_hw * 0.34 / asp * 2.5 + 0.03, 0.04, 0.6)
	var gy := lerpf(eye.y, minf(ceil_y, eye.y), 0.25 + 0.75 * lean)
	var head := Vector2(gx, gy) + Vector2(_umb_pan.x * asp, _umb_pan.y)
	# Its own body axis leans toward the throw too, but only half as far: a figure
	# whose head leans and whose spine does not reads as a head balanced on a post.
	var gaxis := (axis * (1.0 - lean * 0.5) + throw * (lean * 0.5)).normalized()
	var anchor := head - gaxis * (unit * scale)
	# The similarity, as a 2x2: her frame (axis, its perpendicular) into the ghost's,
	# with the across-axis component scaled down by Narrow. Built as basis-into-basis
	# rather than as an angle, because her axis is already a unit vector and the
	# inverse of an orthonormal 2x2 is its transpose - no trigonometry, no wrap.
	var h1 := axis
	var h2 := Vector2(-axis.y, axis.x)
	var e1 := gaxis * scale
	var e2 := Vector2(-gaxis.y, gaxis.x) * (scale * (1.0 - narrow))
	# fwd = [e1 e2] * [h1 h2]^-1, and [h1 h2] is orthonormal so its inverse is its
	# TRANSPOSE - which is exactly where a transposed pair of columns hides in
	# plain sight, because the wrong one is still a rotation and still draws
	# something plausible. Column k of fwd is e1*h1[k] + e2*h2[k]; the check that
	# catches it is that fwd*h1 must come back as e1 exactly, which is what
	# tests/masking/umbra_cast_check.gd asserts.
	var f0 := e1 * h1.x + e2 * h2.x     # column 0
	var f1 := e1 * h1.y + e2 * h2.y     # column 1
	var det := f0.x * f1.y - f1.x * f0.y
	if absf(det) < 1e-8:
		return false
	_umb_inv0 = Vector2(f1.y, -f0.y) / det
	_umb_inv1 = Vector2(-f1.x, f0.x) / det
	_umb_anchor = anchor
	_umb_src = sh
	_umb_eye_src = eye
	_umb_unit = unit
	# The bust's extent, in her own units from her eye line. Loom opens it from a
	# head and a collar out to a head, shoulders and chest.
	var loom := clampf(_umb_loom, 0.0, 1.0)
	_umb_bust0 = 0.70 + 2.00 * loom
	_umb_bust1 = 1.60 + 3.40 * loom
	_umb_dir = throw
	# THE EYES, through the same map - so they are on the ghost's head by
	# construction at every Scale, which is the property the previous version could
	# not have (it anchored them to the visible mass's centroid and amplified her
	# motion as a deviation, because carrying them geometrically put them off the
	# top of the frame).
	_umb_eye_l = anchor + Vector2(
		f0.x * (eye_l.x - sh.x) + f1.x * (eye_l.y - sh.y),
		f0.y * (eye_l.x - sh.x) + f1.y * (eye_l.y - sh.y))
	_umb_eye_r = anchor + Vector2(
		f0.x * (eye_r.x - sh.x) + f1.x * (eye_r.y - sh.y),
		f0.y * (eye_r.x - sh.x) + f1.y * (eye_r.y - sh.y))
	# Back to plain UV for the shader, which samples in screen space.
	_umb_eye_l.x /= asp
	_umb_eye_r.x /= asp
	# Sized from the ghost's own skull, not from the fitted separation: the pair's
	# spacing is the quantity that degrades when a head turns away, and a socket
	# that swells with it reads as two unrelated holes.
	_umb_eye_rad = clampf(ghost_hw * 0.34 / asp, 0.006, 0.09)
	_umb_eyes_ok = true
	return true


# --- the capture ticks: the echo, the face model, the anchors, the wave impulses ------------------


## Temporal capture: when the playhead crosses into a new _ECHO_INTERVAL slot,
## snapshot the current frame (quarter-res) into the ring and push the ring to
## both materials in AGE ORDER (u_echo0 = newest). GPU readback at ~3Hz is cheap
## enough for a demo; frames where no whisp/echo/snow/oracle/serpent/chimera
## layer is actually on screen (_temporal_active) skip all of it.
func _maybe_capture_echo() -> void:
	if _player == null or session == null:
		return
	var pos := _player.stream_position
	# The readback below (tex.get_image()) is a synchronous GPU->CPU stall. We only
	# ever want to pay it when it MATTERS and when it WON'T fight the user:
	#   - during playback (the effects need to advance), OR
	#   - once, when a scrub has SETTLED (playhead stationary since last frame) - so
	#     dragging the playhead stays responsive and the preview refreshes on release.
	# Never per-scrub-position mid-drag, which is what made clicking the timeline lag
	# and starved the audio. render_mode auto-plays, so export still captures every
	# slot deterministically.
	if not _playing:
		var settled := absf(pos - _prev_pos) < 0.0005
		_prev_pos = pos
		if not settled:
			return
	else:
		_prev_pos = pos
	if not _temporal_active:
		return
	var slot := int(pos / _ECHO_INTERVAL)
	if slot == _echo_slot:
		return
	var tex := _player.get_video_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	_echo_slot = slot
	img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	_echo_ring[slot % 8] = ImageTexture.create_from_image(img)
	for age in 8:
		var t: Variant = _echo_ring[((slot - age) % 8 + 8) % 8]
		if t == null:
			t = _echo_ring[slot % 8]
		for mat in [_mat_main, _mat_inset]:
			mat.set_shader_parameter("u_echo%d" % age, t)
	# The face model runs on its own higher-res copy BEFORE _update_whisp_anchor
	# destructively resizes img down to 48x27; claiming the face slot here means
	# _maybe_capture_face never pays a second readback on the same frame.
	if _clown_active:
		_face_slot = int(pos / _FACE_INTERVAL)
		# The blob fitter still runs for the face's COLOR statistics - mean tint,
		# luminance, redness - which the coat needs and which landmarks cannot
		# supply (they say where the face is, not what color it is). Its
		# GEOMETRY is then overwritten by the track, which is measured rather
		# than fitted. When there is no track the fitter's geometry stands, as
		# the fallback it now is.
		_update_face_model(img)
		if _ft_state == "ready" and _face.has_track(pos):
			_face.apply_model(pos)
	_update_whisp_anchor(img)
	# The track readback is chimera's alone - skip it entirely unless a chimera layer
	# is actually rendering this frame (it usually isn't: the marker sits at one point
	# in the timeline). This is what my earlier change was paying for everywhere.
	if _chimera_active:
		_update_track_frame()


## The face model's own capture ticks, BETWEEN echo captures (see
## _FACE_INTERVAL's doc). Same discipline as _maybe_capture_echo: only during
## playback (or once when a scrub settles), never mid-drag - the readback is a
## synchronous GPU stall and this one runs at ~7Hz while a clown layer is live.
func _maybe_capture_face() -> void:
	if not _clown_active or _player == null or session == null:
		return
	# THE TRACK WINS WHEN IT EXISTS. It is read every frame (not on the capture
	# tick) because reading it costs an array lookup, and the whole reason the
	# old path had a 6.7 Hz tick at all was that its detection was expensive.
	# Reading continuously is also what removes the last of the stepping.
	_face.ensure()
	if _ft_state == "ready":
		if _face.has_track(_player.stream_position):
			_face.apply_model(_player.stream_position)
			_face.update_stencil(_player.stream_position)
		# No detection at this instant (a turn away, a hand across the face):
		# HOLD the last model rather than snapping to a guess.
		return
	var pos := _player.stream_position
	if not _playing and absf(pos - _prev_pos) >= 0.0005:
		return
	var slot := int(pos / _FACE_INTERVAL)
	if slot == _face_slot:
		return
	var tex := _player.get_video_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	_face_slot = slot
	_update_face_model(img)


## The anchor uniform, glided per frame: lerp(prev EMA, latest EMA) by the
## playhead's fraction through the current capture slot. Deterministic (pure
## function of playback position + capture history) and continuous - the
## pattern drifts to each new lock instead of jumping there.
func _push_anchor() -> void:
	var f := clampf(fposmod(_player.stream_position, _ECHO_INTERVAL) / _ECHO_INTERVAL, 0.0, 1.0)
	var anchor := _anchor_prev.lerp(_anchor_ema, f)
	# Chimera's landmark frames, glided on the same fraction (position + size, both
	# faces). Pure function of playback position + capture history, so live and
	# export trace the identical lock.
	var anchor_scale := lerpf(_anchor_scale_prev, _anchor_scale_ema, f)
	var track_anchor := _track_anchor_prev.lerp(_track_anchor_ema, f)
	var track_scale := lerpf(_track_scale_prev, _track_scale_ema, f)
	for mat in [_mat_main, _mat_inset]:
		mat.set_shader_parameter("u_anchor", anchor)
		mat.set_shader_parameter("u_anchor_scale", anchor_scale)
		mat.set_shader_parameter("u_track_anchor", track_anchor)
		mat.set_shader_parameter("u_track_scale", track_scale)
		# Only push once impulses exist - a short array is silently dropped by
		# Godot (see the u_l_* comment above), so an empty/partial one is worse
		# than leaving the shader's own all-zero (inactive) uniform defaults.
		if _wave_amp.size() == _WAVE_SLOTS:
			mat.set_shader_parameter("u_wave_pos", _wave_pos)
			mat.set_shader_parameter("u_wave_time", _wave_time)
			mat.set_shader_parameter("u_wave_amp", _wave_amp)
		# The clown face model PREDICTS instead of gliding: displaying
		# lerp(prev, ema) put the mask a full tick behind the face - the
		# "always drifting just behind any movement" report. Extrapolating
		# along each feature's own velocity (ema + (ema - prev) * t) leads
		# the fit by up to one tick, which cancels the capture+EMA delay;
		# the cost is mild overshoot on direction reversals, which reads as
		# the mask swinging - far better than trailing.
		if _clown_active:
			var cm := _face.clown_model_now()
			mat.set_shader_parameter("u_clown_eye_l", cm.eye_l)
			mat.set_shader_parameter("u_clown_eye_r", cm.eye_r)
			mat.set_shader_parameter("u_clown_mouth", cm.mouth)
			mat.set_shader_parameter("u_clown_face_r", _face_r_ema)
			mat.set_shader_parameter("u_clown_eye_lr", cm.eye_lr)
			mat.set_shader_parameter("u_clown_eye_rr", cm.eye_rr)
			mat.set_shader_parameter("u_clown_mouth_r", cm.mouth_r)
			mat.set_shader_parameter("u_clown_face_c", cm.face_c)
			# The face's own axes, from the eye pair: direction along the eye line,
			# scaled by 1/separation. Everything drawn in this frame (the craquelure)
			# is then pinned to the skin rather than to the screen.
			var eye_v: Vector2 = (cm.eye_r - cm.eye_l) * Vector2(_source_prep.source_aspect(), 1.0)
			var eye_len: float = maxf(eye_v.length(), 1e-4)
			mat.set_shader_parameter("u_clown_frame", eye_v / (eye_len * eye_len))
			mat.set_shader_parameter("u_clown_tint", _face_tint_ema)
			mat.set_shader_parameter("u_clown_lum", _face_lum_ema)


## The landmark anchor (whisp's field origin, chimera's graft window): the
## first whisp-or-chimera marker's target-color mass centroid in the captured
## frame, EMA-smoothed so the lock glides to landmarks instead of jittering
## with noise. When the key color exists NOWHERE (flat lighting), the motion
## centroid anchors instead - see the fallback below. Fur no longer reads
## this - its strands root per-pixel on the keyed surface itself (see
## fur_root_mass / the fur branch of apply_layer in mask_split.gdshader).
func _update_whisp_anchor(img: Image) -> void:
	var hue := -1.0
	for m in session.markers:
		var e := int(m.get("effect_a", 0))
		# Fur joins whisp/chimera in driving the anchor: its Stickiness cue wants the
		# key color's centroid (with the motion-centroid fallback for flat footage) to
		# track the surface the strands root on. Fur ignores u_anchor at Stickiness 0,
		# so this has no effect on the existing look. Clown rides the same frame -
		# its whole makeup layout lives in the canonical space u_anchor defines.
		if e == 5 or e == MaskSession.EFFECT_CHIMERA or e == MaskSession.EFFECT_FUR \
				or e == MaskSession.EFFECT_CLOWN:
			hue = float(m.get("hue_a", 0.0))
			break
	if hue < 0.0:
		return
	var tc := Color.from_hsv(hue, 1.0, 1.0)
	var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
	var tdir := Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized()
	img.resize(48, 27, Image.INTERPOLATE_BILINEAR)
	# Read the frame as one flat RGBA8 buffer instead of 1296 Image.get_pixel()
	# calls. This runs every _ECHO_INTERVAL during playback (once a temporal effect
	# is live), right after the synchronous GPU readback - the per-pixel Color
	# construction get_pixel does was a measurable slice of that periodic hitch. The
	# math is unchanged; only the pixel access is. (_face_frame does the same.)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var acc := Vector2.ZERO
	var acc2 := 0.0          # weighted sum of |pos|^2 - second moment, for the RMS radius (size)
	var wsum := 0.0
	var macc := Vector2.ZERO
	var macc2 := 0.0
	var msum := 0.0
	var have_prev := _wave_prev_lum.size() == 48 * 27
	if not have_prev:
		_wave_prev_lum.resize(48 * 27)
	var motion := 0.0
	for y in 27:
		for x in 48:
			var idx := y * 48 + x
			var base := idx * 4
			var r := float(data[base]) / 255.0
			var g := float(data[base + 1]) / 255.0
			var b := float(data[base + 2]) / 255.0
			var l := 0.299 * r + 0.587 * g + 0.114 * b
			var pos := Vector2((float(x) + 0.5) / 48.0, (float(y) + 0.5) / 27.0)
			var pr := maxf(0.0, (r - l) * tdir.x + (g - l) * tdir.y + (b - l) * tdir.z)
			acc += pos * pr
			acc2 += pos.length_squared() * pr
			wsum += pr
			if have_prev:
				var dm := absf(l - _wave_prev_lum[idx])
				motion += dm
				macc += pos * dm
				macc2 += pos.length_squared() * dm
				msum += dm
			_wave_prev_lum[idx] = l
	if wsum > 0.01:
		_anchor_prev = _anchor_ema
		_anchor_ema = _anchor_ema.lerp(acc / wsum, 0.15)
		# Size = RMS radius of the mass about its own centroid (Var = E[|p|^2] -
		# |E[p]|^2), the second half of the main face's landmark frame.
		_anchor_scale_prev = _anchor_scale_ema
		_anchor_scale_ema = lerpf(_anchor_scale_ema,
			clampf(sqrt(maxf(1e-4, acc2 / wsum - (acc / wsum).length_squared())), 0.05, 0.9), 0.15)
	elif msum > 0.3:
		# FLAT-LIGHTING FALLBACK (chimera's first test case): standard, flat
		# footage may carry the key color NOWHERE - then the landmark is
		# wherever the pixels MOVE. The motion centroid of a talking head IS
		# the head; slower EMA than the color lock because motion is noisier
		# frame to frame.
		_anchor_prev = _anchor_ema
		_anchor_ema = _anchor_ema.lerp(macc / msum, 0.1)
		_anchor_scale_prev = _anchor_scale_ema
		_anchor_scale_ema = lerpf(_anchor_scale_ema,
			clampf(sqrt(maxf(1e-4, macc2 / msum - (macc / msum).length_squared())), 0.05, 0.9), 0.1)
	if have_prev:
		_update_wave_impulses(motion / (48.0 * 27.0))


## Model a face as a landmark FRAME - centroid + isotropic size (RMS radius) - from
## the key-color mass in an already-48x27 frame, with the motion centroid+spread
## as the flat-lighting fallback (the same thresholds _update_whisp_anchor uses).
## This is the "simple EMA over key thresholds" model chimera phase-locks to; it
## runs on the imported TRACK frame so the graft is normalized by the OTHER head's
## own frame before being re-fitted onto the main head. Returns
## {c, s, cur_lum, ok}; cur_lum is the caller's next previous-luminance grid.
func _face_frame(img: Image, tdir: Vector3, prev_lum: PackedFloat32Array) -> Dictionary:
	var acc := Vector2.ZERO
	var acc2 := 0.0
	var wsum := 0.0
	var macc := Vector2.ZERO
	var macc2 := 0.0
	var msum := 0.0
	var cur := PackedFloat32Array()
	cur.resize(48 * 27)
	var have_prev := prev_lum.size() == 48 * 27
	# Flat RGBA8 buffer read - see _update_whisp_anchor for why (same per-tick path).
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for y in 27:
		for x in 48:
			var idx := y * 48 + x
			var base := idx * 4
			var r := float(data[base]) / 255.0
			var g := float(data[base + 1]) / 255.0
			var b := float(data[base + 2]) / 255.0
			var l := 0.299 * r + 0.587 * g + 0.114 * b
			var pos := Vector2((float(x) + 0.5) / 48.0, (float(y) + 0.5) / 27.0)
			var pr := maxf(0.0, (r - l) * tdir.x + (g - l) * tdir.y + (b - l) * tdir.z)
			acc += pos * pr
			acc2 += pos.length_squared() * pr
			wsum += pr
			if have_prev:
				var dm := absf(l - prev_lum[idx])
				macc += pos * dm
				macc2 += pos.length_squared() * dm
				msum += dm
			cur[idx] = l
	if wsum > 0.01:
		var c0 := acc / wsum
		return {"c": c0, "s": clampf(sqrt(maxf(1e-4, acc2 / wsum - c0.length_squared())), 0.05, 0.9),
			"cur_lum": cur, "ok": true}
	elif msum > 0.3:
		var c1 := macc / msum
		return {"c": c1, "s": clampf(sqrt(maxf(1e-4, macc2 / msum - c1.length_squared())), 0.05, 0.9),
			"cur_lum": cur, "ok": true}
	return {"c": Vector2(0.5, 0.5), "s": 0.28, "cur_lum": cur, "ok": false}


## Model the imported track face (chimera's graft source) each capture tick, so its
## frame - centroid + size - can normalize the graft before it's re-fitted onto the
## main head. Keyed by the chimera marker's own color; nothing to do without one.
func _update_track_frame() -> void:
	if _tracks.runtime.is_empty():
		return
	var rt: Dictionary = _tracks.runtime[0]
	if not rt.has("player"):
		return
	var tp: VideoStreamPlayer = rt.player
	if tp == null:
		return
	var ttex := tp.get_video_texture()
	if ttex == null:
		return
	var timg := ttex.get_image()
	if timg == null or timg.is_empty():
		return
	var hue := -1.0
	for m in session.markers:
		if int(m.get("effect_a", 0)) == MaskSession.EFFECT_CHIMERA:
			hue = float(m.get("hue_a", 0.0))
			break
	if hue < 0.0:
		return
	var tc := Color.from_hsv(hue, 1.0, 1.0)
	var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
	var tdir := Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized()
	timg.resize(48, 27, Image.INTERPOLATE_BILINEAR)
	var fr := _face_frame(timg, tdir, _track_prev_lum)
	_track_prev_lum = fr.cur_lum
	if fr.ok:
		_track_anchor_prev = _track_anchor_ema
		_track_anchor_ema = _track_anchor_ema.lerp(fr.c, 0.15)
		_track_scale_prev = _track_scale_ema
		_track_scale_ema = lerpf(_track_scale_ema, float(fr.s), 0.15)


## Onset detection for the wave impulses: motion is this capture's average
## per-pixel luminance jolt (see caller). A steady baseline (_wave_motion_ema)
## and its own deviation (_wave_dev_ema) track each clip's ambient motion level
## adaptively - talking-head footage idles near-still, a real head turn spikes
## several deviations above it - so one fixed threshold doesn't have to guess
## right for every source video. Rate-limited (see _WAVE_COOLDOWN) so a shaky
## run of frames fires one wave, not a pile of overlapping ones.
func _update_wave_impulses(motion: float) -> void:
	var onset := motion - _wave_motion_ema
	var t: float = _player.stream_position
	if onset > _wave_dev_ema * 3.5 and t - _wave_last_time >= _WAVE_COOLDOWN:
		_wave_last_time = t
		if _wave_amp.size() != _WAVE_SLOTS:
			_wave_pos.resize(_WAVE_SLOTS)
			_wave_time.resize(_WAVE_SLOTS)
			_wave_amp.resize(_WAVE_SLOTS)
		_wave_pos[_wave_slot] = _anchor_ema
		_wave_time[_wave_slot] = t
		_wave_amp[_wave_slot] = clampf(onset / maxf(_wave_dev_ema * 6.0, 0.02), 0.35, 1.0)
		_wave_slot = (_wave_slot + 1) % _WAVE_SLOTS
	_wave_motion_ema = lerp(_wave_motion_ema, motion, 0.2)
	_wave_dev_ema = lerp(_wave_dev_ema, absf(onset), 0.2)


## Fit the clown face model from one capture: face mass -> centroid, spread
## and tint; then the EYES as the two darkest clusters in the upper face band
## (split left/right) and the MOUTH as the red/dark centroid below. Pure
## heuristics, the crystal school - no landmark model, no ML - built for the
## ASMR framing this effect targets: one person, near center, facing camera,
## small head movement. Face mass prefers the marker's KEY color (the picker
## says what the face's material is - on natural footage, pick the skin tone);
## a broad natural-skin rule backs it up, and a centered prior downweights
## background and hands at the frame's edges. Results are EMA'd with prev/ema
## pairs; _push_anchor glides the uniforms between ticks like the anchor.
## The live clown layer's region, in frame UV, as the face model sees it: 1 inside,
## 0 outside, soft at the border. Mirrors the shader's region_mask (see
## mask_split.gdshader) so the detector searches exactly the area the effect is
## allowed to paint - a box that bounded the drawing but not the SEARCH would let
## the model fit itself to something it can never paint, which is worse than no
## box at all. Default (whole frame) returns 1 everywhere.
func _face_region_at(uv: Vector2) -> float:
	var lo := Vector2(minf(_clown_region.x, _clown_region.z),
		minf(_clown_region.y, _clown_region.w))
	var hi := Vector2(maxf(_clown_region.x, _clown_region.z),
		maxf(_clown_region.y, _clown_region.w))
	var size := (hi - lo).max(Vector2(1e-4, 1e-4))
	# A softer shoulder than the shader's: the detector wants the box's EDGE to
	# fade its evidence out gradually so a face half in and half out still fits
	# rather than being sliced, where the drawn paint wants the edge the author
	# actually placed.
	var soft: float = maxf(0.06 * minf(size.x, size.y), 0.004)
	var m := 1.0
	if lo.x > 0.0005:
		m = minf(m, smoothstep(lo.x - soft, lo.x + soft, uv.x))
	if hi.x < 0.9995:
		m = minf(m, 1.0 - smoothstep(hi.x - soft, hi.x + soft, uv.x))
	if lo.y > 0.0005:
		m = minf(m, smoothstep(lo.y - soft, lo.y + soft, uv.y))
	if hi.y < 0.9995:
		m = minf(m, 1.0 - smoothstep(hi.y - soft, hi.y + soft, uv.y))
	return m


func _update_face_model(src: Image) -> void:
	var hue := -1.0
	for m in session.markers:
		if int(m.get("effect_a", 0)) == MaskSession.EFFECT_CLOWN:
			hue = float(m.get("hue_a", 0.0))
			break
	if hue < 0.0:
		return
	# prev catches up every tick, found or not - the push EXTRAPOLATES along
	# (ema - prev), so prev must always be exactly one tick behind.
	_face_eye_l_prev = _face_eye_l_ema
	_face_eye_r_prev = _face_eye_r_ema
	_face_mouth_prev = _face_mouth_ema
	_face_r_prev = _face_r_ema
	_face_eye_lr_prev = _face_eye_lr_ema
	_face_eye_rr_prev = _face_eye_rr_ema
	_face_mouth_r_prev = _face_mouth_r_ema
	_face_c_prev = _face_c_ema
	_face_nose_prev = _face_nose_ema
	var tc := Color.from_hsv(hue, 1.0, 1.0)
	var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
	var tdir := Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized()
	# EVERY anatomical ratio below is computed in ASPECT-CORRECTED space
	# (x scaled by the frame's aspect, so one unit means the same thing
	# horizontally and vertically). Mixing raw uv axes is a real bug, not a
	# rounding matter: on 16:9 it made the eye "distance" a width measure
	# while eye-to-mouth stayed a height measure, so the mouth's true offset
	# read ~1.75 instead of ~1.15 and the prior dragged the lips up under
	# the nose.
	var fasp := 1.7778
	if src.get_height() > 0:
		fasp = float(src.get_width()) / float(src.get_height())
	var img: Image = src.duplicate()
	# HALVE REPEATEDLY BEFORE THE FINAL RESIZE. Image.resize's bilinear filter
	# samples a 2x2 neighborhood whatever the reduction factor, so taking a
	# 1080x1920 frame straight to 96x54 - a 35x reduction vertically - is very
	# nearly point sampling: which source rows happen to land under the sample
	# points changes with sub-pixel movement of the subject, so the whole weight
	# field flickers tick to tick even on a still shot, and every fit derived from
	# it inherits that flicker. shrink_x2 is a true 2x2 box average, so halving
	# down to within ~2x of the target first makes the last resize a genuine
	# average of the whole frame instead of a sparse sample of it. Costs a few
	# cheap passes at this cadence and removes a whole class of jitter.
	while img.get_width() >= 192 and img.get_height() >= 108:
		img.shrink_x2()
	img.resize(96, 54, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	# Whole-frame mean luminance FIRST - the brightness cue below is relative
	# to it (a face is bright against ITS OWN room, not against an absolute).
	var bg_acc := 0.0
	for k in 96 * 54:
		var b4 := k * 4
		bg_acc += 0.299 * float(data[b4]) + 0.587 * float(data[b4 + 1]) + 0.114 * float(data[b4 + 2])
	_face_bg_lum = bg_acc / (255.0 * 96.0 * 54.0)
	var lums := PackedFloat32Array()
	lums.resize(96 * 54)
	var wts := PackedFloat32Array()
	wts.resize(96 * 54)
	var reds := PackedFloat32Array()
	reds.resize(96 * 54)
	var acc := Vector2.ZERO
	var accxx := 0.0
	var accyy := 0.0
	var wsum := 0.0
	var lum_acc := 0.0
	var red_acc := 0.0
	var tint_acc := Vector3.ZERO
	for y in 54:
		for x in 96:
			var idx := y * 96 + x
			var base := idx * 4
			var r := float(data[base]) / 255.0
			var g := float(data[base + 1]) / 255.0
			var b := float(data[base + 2]) / 255.0
			var l := 0.299 * r + 0.587 * g + 0.114 * b
			lums[idx] = l
			reds[idx] = r - g
			var pos := Vector2((float(x) + 0.5) / 96.0, (float(y) + 0.5) / 54.0)
			var cr := r - l
			var cg := g - l
			var cb := b - l
			# KEY-COLOR MASS, as a hue CONE rather than a raw projection - the
			# same correction repaint's selection needed, for the same reason and
			# with worse consequences here. A raw projection measures absolute
			# chroma along the key direction, so it rewards SATURATION as much as
			# similarity: measured against this effect's own default key (red), a
			# lit yellow wall projects 0.324 and the skin in front of it 0.206, so
			# the wall out-keyed the face by half again and the model fitted
			# itself to the wall - "pinned on half my face and half the wall, and
			# it never corrects itself". By the brightness-free aligned fraction
			# the same two are 45 degrees and 24 degrees off the key, and raising
			# that to a power turns a 1.6:1 loss into a 4.9:1 win for the face.
			var clen := sqrt(cr * cr + cg * cg + cb * cb)
			var align := maxf(0.0, cr * tdir.x + cg * tdir.y + cb * tdir.z) / maxf(clen, 1e-4)
			var pr := pow(align, 6.0) * smoothstep(0.02, 0.10, clen)
			# natural-skin fallback: warm chroma, red over blue, carried by
			# real light - broad on purpose, the prior does the rejecting
			var skin := 0.0
			if cr > 0.01 and l > 0.15 and cr > cb:
				skin = clampf(cr * 6.0, 0.0, 1.0) * clampf((cr - cb) * 4.0, 0.0, 1.0)
			# LUMINANCE fallback, for the many faces that carry no usable
			# chroma at all: near-monochrome grades, blue/gray night looks,
			# a lit face against a dark room. Both cues above read ~0 there
			# and the model simply stopped updating. Brightness relative to
			# THIS frame's own mean (computed on the fly below via
			# _face_bg_lum) is the one signal such footage always has.
			var bright := smoothstep(_face_bg_lum + 0.06, _face_bg_lum + 0.30, l)
			var prior := exp(-pos.distance_squared_to(Vector2(0.5, 0.45)) / 0.18)
			# THE REGION BOX IS A "LOOK FOR THE FACE HERE" HINT, not just a bound
			# on where paint may land. Color alone cannot always separate a face
			# from its background - a warm lit wall reads as skin to every cue
			# this has (warm chroma, bright against the frame's mean, and close
			# enough in hue to key on), and on the clip this was written for it
			# genuinely does. Position separates them trivially, and the author
			# has already drawn the box that says so. Applying it HERE as well is
			# what turns it from a crop into guidance: the detector stops seeing
			# the wall at all, so it locks onto the face instead of straddling
			# both - without anyone placing a single landmark by hand.
			var wt := maxf(maxf(pr * 2.2, skin * 0.9), bright * 0.85) * prior \
				* _face_region_at(pos)
			wts[idx] = wt
			acc += pos * wt
			accxx += pos.x * pos.x * wt
			accyy += pos.y * pos.y * wt
			wsum += wt
			lum_acc += l * wt
			red_acc += (r - g) * wt
			tint_acc += Vector3(cr, cg, cb) * wt
	if wsum <= 0.5:
		return   # nothing face-like this tick - keep the previous model
	# THE FACE'S SIZE COMES FROM ITS CORE, NOT FROM EVERY PIXEL THAT LEANS WARM.
	# The weight field is deliberately generous - key-hue projection OR skin
	# chroma OR brightness-over-the-frame's-mean - so on real footage a lit wall
	# the color of skin contributes a wide, low plateau of weight, and a plain
	# weighted variance over all of it reports the ROOM's spread as the face's.
	# Measured on a phone clip against a warm wall: rx climbed steadily to 0.42
	# where the head is really about 0.28, and because the eye separation is then
	# reined to that width (see `want` below), the pair was forced apart a little
	# further every tick until one eye sat out on the subject's headscarf. That is
	# the "only one eye is detected, the other is drawn across my forehead" report,
	# and it is a size bug, not a detection bug.
	#
	# So the spread is measured over the CONCENTRATED mass only - cells carrying a
	# real fraction of the peak weight - which is the face and not the plateau
	# around it. The centroid comes from the same cells for the same reason.
	var wpeak := 0.0
	for i in 96 * 54:
		wpeak = maxf(wpeak, wts[i])
	var core_floor := wpeak * _FACE_CORE
	var cacc := Vector2.ZERO
	var cxx := 0.0
	var cyy := 0.0
	var cw := 0.0
	for y in 54:
		for x in 96:
			var idx := y * 96 + x
			if wts[idx] < core_floor:
				continue
			var pos := Vector2((float(x) + 0.5) / 96.0, (float(y) + 0.5) / 54.0)
			var wv := wts[idx]
			cacc += pos * wv
			cxx += pos.x * pos.x * wv
			cyy += pos.y * pos.y * wv
			cw += wv
	# Fall back to the full field if the core is too thin to fit anything - a
	# nearly-flat weight field has no core, and a bad fit beats no fit here.
	if cw > wsum * 0.02:
		acc = cacc
		accxx = cxx
		accyy = cyy
		wsum = cw
	var c := acc / wsum
	# The half-width is FITTED in raw uv but BOUNDED in height units, then
	# converted back. A bound written in raw uv is a different physical size on
	# every frame shape - see _FACE_ASP_REF - and this one is what decides the
	# eye and mouth search bands below, so getting it wrong on a portrait clip
	# doesn't just mis-size the coat, it points the whole search at the wrong
	# part of the picture.
	var rx := clampf(sqrt(maxf(1e-5, accxx / wsum - c.x * c.x)) * 1.9 * fasp,
		0.06 * _FACE_ASP_REF, 0.30 * _FACE_ASP_REF) / fasp
	# The half-HEIGHT's bound scales with the frame's SHORTER side. "A face is at
	# most 0.36 of the frame's height" is a framing convention, and it is a
	# convention about the short axis: on a 16:9 clip that IS the height and this
	# is unchanged, but on a portrait clip the height covers most of a standing
	# body, so the same fraction admits an oval half again as tall as the head.
	# That matters well beyond the coat's looks - the eye and mouth search bands
	# below are struck as fractions of ry, so an ry that runs long aims them at
	# the forehead and the nose instead of the eyes and the mouth.
	var yshort: float = minf(1.0, fasp)
	var ry := clampf(sqrt(maxf(1e-5, accyy / wsum - c.y * c.y)) * 1.9,
		0.08 * yshort, 0.36 * yshort)
	var mean_lum := lum_acc / wsum
	var mean_red := red_acc / wsum
	# Blurred face mass (separable box, radius 3): an EYE is a dark spot in a
	# SKIN neighborhood. Weighting candidates by the pixel's own mass fails -
	# an eye pixel itself carries no skin chroma - and weighting by a flat
	# floor let the dark HAIR flanking the face win both clusters, which blew
	# the eye distance (and with it every feature size) up to face width.
	var wblur := PackedFloat32Array()
	wblur.resize(96 * 54)
	var wtmp := PackedFloat32Array()
	wtmp.resize(96 * 54)
	for y in 54:
		for x in 96:
			var s := 0.0
			for k in range(-3, 4):
				s += wts[y * 96 + clampi(x + k, 0, 95)]
			wtmp[y * 96 + x] = s / 7.0
	for y in 54:
		for x in 96:
			var s := 0.0
			for k in range(-3, 4):
				s += wtmp[clampi(y + k, 0, 53) * 96 + x]
			wblur[y * 96 + x] = s / 7.0
	# Second pass, inside the fitted oval only: eye clusters + mouth cluster,
	# each with its own second moment - the drawn features take their SIZES
	# from these spreads, so they breathe with the anatomy instead of holding
	# a flat mask's fixed proportions.
	var have_mo := _face_prev_lum.size() == 96 * 54
	# The eye frame from the LAST tick - stable, already smoothed, and the
	# mouth's search band rides it (see below).
	var eye_mid := (_face_eye_l_ema + _face_eye_r_ema) * 0.5
	# Eye separation in HEIGHT units (aspect-corrected) - the yardstick every
	# ratio below is expressed in.
	var eye_unit := maxf(((_face_eye_r_ema - _face_eye_l_ema)
		* Vector2(fasp, 1.0)).length(), 0.02)
	var el_acc := Vector2.ZERO
	var ela_acc := Vector2.ZERO
	var el2 := 0.0
	var el_w := 0.0
	var er_acc := Vector2.ZERO
	var era_acc := Vector2.ZERO
	var er2 := 0.0
	var er_w := 0.0
	var mo_acc := Vector2.ZERO
	var mo2x := 0.0
	var mo2y := 0.0
	var mo_w := 0.0
	var no_acc := Vector2.ZERO
	var no_w := 0.0
	var dm_sum := 0.0
	var dm_n := 0.0
	for y in 54:
		for x in 96:
			var idx := y * 96 + x
			var pos := Vector2((float(x) + 0.5) / 96.0, (float(y) + 0.5) / 54.0)
			var ex := (pos.x - c.x) / rx
			var ey := (pos.y - c.y) / ry
			if ex * ex + ey * ey > 1.3:
				continue
			var apos := Vector2(pos.x * fasp, pos.y)   # aspect-corrected twin of pos
			var dm := absf(lums[idx] - _face_prev_lum[idx]) if have_mo else 0.0
			dm_sum += dm
			dm_n += 1.0
			# EYES: darkness against the face's own mean, squared so real
			# sockets dominate faint shading, weighted by the BLURRED face
			# mass - dark-in-a-skin-neighborhood is an eye, dark-in-dark is
			# hair. Band kept off the oval's flanks for the same reason.
			if ey > -0.6 and ey < -0.05 and absf(ex) < 0.55:
				var dk := maxf(0.0, mean_lum - lums[idx])
				var we := dk * dk * wblur[idx]
				if ex < 0.0:
					el_acc += pos * we
					ela_acc += apos * we
					el2 += apos.length_squared() * we
					el_w += we
				else:
					er_acc += pos * we
					era_acc += apos * we
					er2 += apos.length_squared() * we
					er_w += we
			# This pixel in EYE-PAIR units (aspect-corrected), the frame both
			# the nose and the mouth search in.
			var mrel := ((pos - eye_mid) * Vector2(fasp, 1.0)) / eye_unit
			# NOSE: the NOSTRIL PAIR - two small dark spots between the eye
			# line and the mouth, close to the center. It is the only
			# dependable 2D signature a nose has: the tip's highlight walks
			# around with the lighting, and deriving the nose from
			# mid-eyes-to-mouth (what this did before) inherits the error of
			# BOTH estimates, which is why the ball kept sitting off-center
			# while the evidence-detected lips tracked fine.
			if mrel.y > 0.45 and mrel.y < 1.0 and absf(mrel.x) < 0.45:
				var nprior := exp(-pow((mrel.y - 0.85) / 0.28, 2.0))
				var wn := maxf(0.0, mean_lum - lums[idx]) * wblur[idx] * nprior
				wn *= wn   # concentrate on the actual nostril darkness (see the mouth)
				no_acc += pos * wn
				no_w += wn
			# MOUTH: MOTION first - on a talking face the mouth out-moves
			# everything else in the lower band, and unlike redness it can't
			# lock onto a warm-lit chin and sit there forever (the static
			# "swish" report). Ambient face motion (head sway, compression
			# shimmer) is subtracted; redness-over-face-mean and darkness stay
			# as tie-breakers for the quiet stretches.
			# The search band hangs off the EYE PAIR (the detection that
			# actually works), not the fitted oval: with the brightness cue
			# the oval swells over hair and shoulders, and an oval-relative
			# band put the mouth down on the chin.
			if mrel.y > 0.55 and mrel.y < 1.75 and absf(mrel.x) < 0.65:
				# Anatomical prior: the mouth sits ~1.2 eye-distances below
				# the eye line. Talking moves the whole lower face (jaw,
				# cheeks, nostrils), so raw motion alone pulled the centroid
				# up under the nose - the prior keeps it on the lips without
				# pinning it there (a wide gaussian, not a fixed offset).
				var mprior := exp(-pow((mrel.y - 1.15) / 0.38, 2.0))
				var wm := (maxf(0.0, dm - _face_motion_mean * 1.3) * 6.0
					+ maxf(0.0, reds[idx] - mean_red - 0.01) * 1.2
					+ maxf(0.0, mean_lum - lums[idx]) * 0.3) * wblur[idx] * mprior
				# SQUARED: the raw score is diffuse (compression shimmer and
				# residual head motion leak everywhere), and a diffuse weight
				# blew the cluster's variance to the clamps - the first cut
				# drew face-wide lips. Squaring concentrates centroid AND
				# spread on the actual peak: the moving mouth.
				wm *= wm
				mo_acc += pos * wm
				mo2x += pos.x * pos.x * wm
				mo2y += pos.y * pos.y * wm
				mo_w += wm
	_face_prev_lum = lums
	if dm_n > 0.0:
		_face_motion_mean = lerpf(_face_motion_mean, dm_sum / dm_n, 0.3)
	# THE TWO SMOOTHING RATES, both under the author's hand now (Steady and Firm
	# in the panel). They were constants tuned against one clip, and the right
	# value genuinely differs per clip: a locked-off shot wants heavy smoothing
	# and doesn't care about the lag, a moving one cannot afford it. Positions and
	# SIZES are separate because they fail differently - a position that lags
	# reads as the mask sliding behind the face, while a size that jitters reads
	# as the mask pulsing in and out several times a second, which is far more
	# distracting and worth a lot of lag to kill. Both mappings reproduce the old
	# constants exactly (0.35 positions, 0.30 sizes, 0.15 the coat) at the stored
	# field defaults, so nothing moves until the author moves it.
	# The fallback's own smoothing, back to the constants it was tuned with - the
	# fields that used to drive these now carry the shape knobs, and the track
	# (which needs no smoothing at all) is the path that matters.
	var a_pos := 0.35
	var a_size := 0.30
	_face_r_ema = _face_r_ema.lerp(Vector2(rx, ry), a_size * 0.5)
	_face_c_ema = _face_c_ema.lerp(c, a_pos * 0.86)
	# The EMA is a stabilizer for detection jitter, not the display's smoothing -
	# the push extrapolates (Lead), so residual EMA lag is what that covers.
	if el_w > 0.005 and er_w > 0.005:
		var el := el_acc / el_w
		var er := er_acc / er_w
		# Each eye's own spread -> its patch's own radius (eye-distance units,
		# so the shader's frame consumes it directly). Independent per side.
		var el_var := maxf(1e-6, el2 / el_w - (ela_acc / el_w).length_squared())
		var er_var := maxf(1e-6, er2 / er_w - (era_acc / er_w).length_squared())
		# Only a PLAUSIBLE pair updates the model: really apart, roughly level,
		# and the two clusters carrying COMPARABLE evidence. That last test is
		# new and it is the cheap guard against the failure the other two let
		# straight through - when one side finds a real socket and the other
		# finds a dark headscarf or a fall of hair, the two clusters' weights
		# differ by an order of magnitude even though the geometry still looks
		# fine. Holding the previous pair for a tick beats accepting half a face.
		var pair_bal: float = minf(el_w, er_w) / maxf(el_w, er_w)
		if er.x - el.x > rx * 0.3 and absf(er.y - el.y) < ry * 0.45 \
				and pair_bal > 0.12:
			# Anatomy rein: eye separation is a fraction of the face's half-width.
			# The clusters place the PAIR well but their spread leans outward
			# (sockets shade wider than pupils), so it is reined to the fitted
			# face rather than trusted raw - it's the unit every feature scales by.
			#
			# THE FLOOR IS THE DANGEROUS HALF, and it used to sit at 0.55, which
			# assumes a face looking straight down the lens. A head turned even
			# slightly has a smaller APPARENT separation - that is what turning
			# does - so the floor pushed the pair back apart to meet a frontal
			# assumption, a little further every tick as the fitted width crept up,
			# until one eye left the face altogether and landed on the forehead.
			# Dropped to a figure that still catches a COLLAPSED pair (two clusters
			# that found the same eye) without arguing with a real turned head.
			var mid := (el + er) * 0.5
			var sep := ((er - el) * Vector2(fasp, 1.0)).length()
			var facew := rx * fasp   # the face's half-width, same units as sep
			var want := clampf(sep, facew * 0.28, facew * 1.05)
			if sep > 1e-4:
				el = mid + (el - mid) * (want / sep)
				er = mid + (er - mid) * (want / sep)
			_face_eye_l_ema = _face_eye_l_ema.lerp(el, a_pos)
			_face_eye_r_ema = _face_eye_r_ema.lerp(er, a_pos)
			# Sizes in raw uv - each eye's spread stands alone, uncoupled
			# from how far apart the pair happens to read this tick.
			_face_eye_lr_ema = lerpf(_face_eye_lr_ema,
				clampf(sqrt(el_var) * 1.9, 0.015, 0.07), a_size)
			_face_eye_rr_ema = lerpf(_face_eye_rr_ema,
				clampf(sqrt(er_var) * 1.9, 0.015, 0.07), a_size)
	if mo_w > 0.0001:
		var mo := mo_acc / mo_w
		_face_mouth_ema = _face_mouth_ema.lerp(mo, a_pos)
		# The mouth's own width and height, separately - talking changes the
		# vertical spread far more than the horizontal, and the lips follow.
		var mvx := maxf(1e-6, mo2x / mo_w - mo.x * mo.x)
		var mvy := maxf(1e-6, mo2y / mo_w - mo.y * mo.y)
		# Caps ride the eye distance - a BOUND, not a normalization (the
		# stored value stays raw uv, so the lips never rescale in lockstep
		# with the eyes; this only stops a diffuse tick drawing a face-wide
		# blob).
		# Stored in raw uv (the shader's contract) but bounded in height units on
		# the x axis, same rule as rx above: the floor was a raw-uv constant, so
		# on a portrait clip it bounded a width to a third of what it means on
		# 16:9. The ceiling already rode eye_unit (height units) and only needed
		# the /fasp moved out of it.
		_face_mouth_r_ema = _face_mouth_r_ema.lerp(Vector2(
			clampf(sqrt(mvx) * 1.9 * fasp, 0.012 * _FACE_ASP_REF, eye_unit * 0.62) / fasp,
			clampf(sqrt(mvy) * 1.9, 0.008, eye_unit * 0.40)), a_size)
	if tint_acc.length() > 1e-4:
		_face_tint_ema = _face_tint_ema.lerp((tint_acc / wsum).normalized(), 0.1)
	_face_lum_ema = lerpf(_face_lum_ema, mean_lum, 0.1)
	_face_red_ema = lerpf(_face_red_ema, mean_red, 0.1)
	# The nose is DERIVED (mid-eyes toward mouth) but smoothed on its own,
	# slower clock - it must not inherit the eye pair's tick-to-tick jitter.
	# The nostril centroid is the BASE of the nose; the ball sits on the tip,
	# just above it. Falls back to the old mid-eyes-to-mouth interpolation
	# (~55% down) only when no nostril evidence turns up at all - flat
	# lighting, a raised chin, a profile.
	var nose_target := ((_face_eye_l_ema + _face_eye_r_ema) * 0.5).lerp(_face_mouth_ema, 0.55)
	var nose_alpha := a_pos * 0.43
	if no_w > 0.0001:
		nose_target = (no_acc / no_w) - Vector2(0.0, 0.14 * eye_unit)
		nose_alpha = a_pos * 0.86
	# A wide sanity box around the face's own center line - detection may be
	# imperfect, but a nose never lands out on a cheek.
	var nose_cx := (eye_mid.x + _face_mouth_ema.x) * 0.5
	nose_target.x = clampf(nose_target.x, nose_cx - eye_unit * 0.30 / fasp,
		nose_cx + eye_unit * 0.30 / fasp)
	_face_nose_ema = _face_nose_ema.lerp(nose_target, nose_alpha)
	if OS.has_environment("GHOST_FACE_DEBUG"):
		var em := (_face_eye_l_ema + _face_eye_r_ema) * 0.5
		var eu := maxf(((_face_eye_r_ema - _face_eye_l_ema) * Vector2(fasp, 1.0)).length(), 0.02)
		print("FACEDBG t=%.2f eyeL=%.3f,%.3f eyeR=%.3f,%.3f unit=%.3f mouth=%.3f,%.3f mouthU=%.2f moW=%.4f szL=%.3f szR=%.3f mr=%.3f,%.3f nose=%.3f,%.3f noW=%.4f" % [
			_player.stream_position if _player != null else 0.0,
			_face_eye_l_ema.x, _face_eye_l_ema.y, _face_eye_r_ema.x, _face_eye_r_ema.y, eu,
			_face_mouth_ema.x, _face_mouth_ema.y, (_face_mouth_ema.y - em.y) / eu, mo_w,
			_face_eye_lr_ema, _face_eye_rr_ema, _face_mouth_r_ema.x, _face_mouth_r_ema.y,
			_face_nose_ema.x, _face_nose_ema.y, no_w])


# --- the panel: its controls, kept to the selected marker -----------------------------------------


func _build_panel() -> void:
	# THE FRAMEWORK'S PANEL (2026-10-06, the user: Masking "doesn't inherit the panel UI or styling...
	# we need to work on bringing it into the framework, proper"): a [SidePanel] like every other
	# note's, with "‹ Notes", the note's title and its "⋯" on top, a chip per card, and three cards -
	# the Clip, the Effect (the marker's key color, effect and options: ONE flat, sortable list, never
	# titled groups - feedback 0011) and the Markers, PINNED under the rest as the ramp/damp list always was,
	# so the whole manage-markers workflow stays in view however far the options are scrolled.
	_panel = SidePanel.new(PANEL_W)
	_panel.title = "Masking"
	_panel.card_prefix = "masking"
	_note_detach(_panel)
	_chrome_host().add_child(_panel)
	_panel.body.add_theme_constant_override("separation", 8)
	_panel.pin_title_row(self, false)
	var chips := CardRow.new()
	_panel.body.add_child(chips)
	_panel.card_row = chips
	var clip: VBoxContainer = _panel.add_card("clip", "Clip", &"picture", "clip")
	var clip_name := Label.new()
	clip_name.text = _clip_name()
	clip_name.tooltip_text = String(session.source_path if not session.source_path.is_empty() else session.video_path)
	clip_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_name.add_theme_font_size_override("font_size", 14)
	clip.add_child(clip_name)

	# Two buttons here: Help and Import track. Everything ELSE that used to
	# be a button (play, view cycle, peek, undo, redo) was pure duplication of
	# a key and moved to the keyboard + the help overlay. Import stayed a
	# button on purpose: it's the ONE action with no on-screen equivalent and
	# no way to discover (a hidden T shortcut is exactly the "I don't see a
	# clear way to do this" complaint - a keyboard-only import that also
	# depends on nothing having eaten the keystroke is not good enough for the
	# single essential action). Both a visible button AND the T key now.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	clip.add_child(tools)
	var import_btn := Button.new()
	import_btn.text = "⬆ Track"
	import_btn.tooltip_text = "Import a second video as a picture-in-picture track (T)"
	import_btn.focus_mode = Control.FOCUS_NONE
	import_btn.pressed.connect(_tracks.prompt_import)
	tools.add_child(import_btn)
	var help_btn := Button.new()
	help_btn.text = "?  Help"
	help_btn.tooltip_text = "Keyboard map (F1)"
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.pressed.connect(_toggle_help)
	tools.add_child(help_btn)
	var col := clip

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	col.add_child(time_row)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 15)
	_time_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	time_row.add_child(_time_label)
	_view_label = Label.new()
	_view_label.add_theme_font_size_override("font_size", 13)
	_view_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	time_row.add_child(_view_label)
	_build_help_overlay()

	# One channel by default (a channel = one target color + one effect + one
	# strength); the second is opt-in behind a toggle. Channels are independent
	# layers in the shader, not competing "sides" - so there's no swap control any
	# more either (swapping meant something when every pixel was forced to one side
	# or the other; independent channels just re-pick their own colors).
	col = _panel.add_card("effect", "Effect", &"look")
	_grp_color = VBoxContainer.new()
	_grp_color.add_theme_constant_override("separation", 8)
	col.add_child(_grp_color)
	_key_color_label = _label("Key color", "The color this channel targets - what it keys or paints")
	_grp_color.add_child(_key_color_label)
	_color_a = ColorPickerButton.new()
	_color_a.focus_mode = Control.FOCUS_NONE
	_color_a.custom_minimum_size = Vector2(0, 40)
	_color_a.edit_alpha = false
	_color_a.tooltip_text = "The color this channel targets - what it keys or paints. " + \
		"The HUE is what gets matched; the swatch keeps the rest of your pick so you " + \
		"can see which color off the footage you chose"
	# Three fields, one pick - the same shape as the repaint picker below. Only the
	# HUE is keyed on; the other two exist so the swatch you get back is the swatch
	# you set (see MaskSession's key_sat/key_val).
	_color_a.color_changed.connect(func(c):
		_edit("hue_a", c.h)
		_edit("key_sat", c.s)
		_edit("key_val", c.v))
	_grp_color.add_child(_color_a)
	col.add_child(_label("Effect", "Which visual treatment this layer applies"))
	_effect_a = _effect_menu(col, func(id): _edit("effect_a", float(id)))

	# Every option below - this channel's grading through this effect's own
	# pattern/echo/weather/tendril knobs - lives in one flat, sortable list instead
	# of fixed titled groups (see feedback/0011: the group boundaries were drawn as
	# separator lines that "made no sense" and just ate space). Which rows are
	# actually visible still follows the selected effect exactly as before
	# (MaskSession.EFFECT_CONTROLS / PATTERN_KNOBS, see _update_effect_controls) -
	# only their ON-SCREEN ORDER is now driven by _sort_mode. _sort_dropdown picks
	# it directly - same shape as the Effect dropdown just above; see _apply_sort.
	var sort_tip := "How the options below are ordered - alphabetical (either " + \
		"direction), or energy: the fullest slider floats to the top, pick-type " + \
		"options with no slider sink to the bottom (A → Z among themselves)"
	col.add_child(_label("Sort", sort_tip))
	_sort_dropdown = OptionButton.new()
	_sort_dropdown.focus_mode = Control.FOCUS_NONE
	_sort_dropdown.tooltip_text = sort_tip
	for i in _SORT_MODES.size():
		_sort_dropdown.add_item(_SORT_MODES[i], i)
	_sort_dropdown.select(_sort_mode)
	_sort_dropdown.item_selected.connect(func(id):
		_sort_mode = id
		_apply_sort())
	col.add_child(_sort_dropdown)

	_grp_options = VBoxContainer.new()
	_grp_options.add_theme_constant_override("separation", 8)
	col.add_child(_grp_options)

	_intensity_a = _slider(_grp_options, "Strength", 0.0, 1.0, func(v): _edit("intensity_a", v),
		"How strongly this layer's effect applies")
	_intensity_label = _intensity_a.get_meta("field_label")
	_register_option(_intensity_a)
	# Morph: its OWN field (fx_tint), deliberately decoupled from the color
	# picker above. The old "Hue" slider was a second widget on hue_a and the
	# linkage read as a bug ("changing hue changes the picker too") - now the
	# picker says what to MASK and this says what color the drawn effect
	# becomes (a palette hue rotation; 0 = the effect's natural colors).
	_hue_a = _slider(_grp_options, "Morph", 0.0, 1.0, func(v):
		_edit("fx_tint", v),
		"Rotates this effect's own palette hue - 0 keeps its natural colors")
	_register_option(_hue_a)

	# Option rows, shown per the selected effect's needs (the control hierarchy,
	# MaskSession.EFFECT_CONTROLS): a slider that does nothing for the current
	# effect is not on screen for it. Erase shows none of these (projection is
	# gate-free); restore shows only the threshold, relabeled as its reach;
	# the volumetrics show everything. See _update_effect_controls.
	_threshold = _slider(_grp_options, "Threshold", 0.0, 1.0, func(v): _edit("threshold", v),
		"How far a pixel's hue may drift from the key color and still be masked")
	_threshold_label = _threshold.get_meta("field_label")
	_register_option(_threshold)

	_feather = _slider(_grp_options, "Feather", 0.0, 0.5, func(v): _edit("feather", v),
		"Softness of the mask's edge - 0 is a hard cutoff")
	_register_option(_feather)
	_sat_floor = _slider(_grp_options, "Min colorfulness", 0.0, 1.0, func(v): _edit("sat_floor", v),
		"Minimum saturation a pixel needs before it can be keyed at all")
	_register_option(_sat_floor)

	# The wisp field's placement - pan/zoom the pattern over the frame (keyframe a
	# tendril onto an eye), and dial its coverage from one wisp to an engulfing.
	# All continuous marker fields, so they blend through ramps/damps.
	_fx_x = _slider(_grp_options, "Pan X", -2.0, 2.0, func(v): _edit("fx_x", v),
		"Shifts the pattern horizontally over the frame")
	_fx_x.step = 0.01
	_fx_x_label = _fx_x.get_meta("field_label")
	_register_option(_fx_x)
	_fx_y = _slider(_grp_options, "Pan Y", -2.0, 2.0, func(v): _edit("fx_y", v),
		"Shifts the pattern vertically over the frame")
	_fx_y.step = 0.01
	_fx_y_label = _fx_y.get_meta("field_label")
	_register_option(_fx_y)
	_fx_scale = _slider(_grp_options, "Scale", 0.1, 8.0, func(v): _edit("fx_scale", v),
		"Zoom of the effect's pattern - 1 is nominal size")
	_fx_scale.exp_edit = true
	_register_option(_fx_scale)
	_fx_density = _slider(_grp_options, "Coverage", 0.0, 1.0, func(v): _edit("fx_density", v),
		"How much of the keyed region the pattern consumes - 0 untouched, 1 fully devoured")
	_fx_density_label = _fx_density.get_meta("field_label")
	_register_option(_fx_density)
	_fx_contrast = _slider(_grp_options, "Contrast", 0.0, 1.0, func(v): _edit("fx_contrast", v),
		"Edge hardness of the pattern - 0.5 is neutral")
	_fx_contrast_label = _fx_contrast.get_meta("field_label")
	_register_option(_fx_contrast)
	_fx_speed = _slider(_grp_options, "Velocity", 0.1, 4.0, func(v): _edit("fx_speed", v),
		"Speed multiplier for the pattern's motion")
	_fx_speed.exp_edit = true
	_register_option(_fx_speed)
	_resonance = _slider(_grp_options, "Resonance", 0.0, 1.0, func(v): _edit("resonance", v),
		"Audio drive - how strongly this layer reacts to the track's live energy")
	_register_option(_resonance)

	_fx_lag = _slider(_grp_options, "Lag (s)", 0.05, 2.4, func(v): _edit("fx_lag", v),
		"How far back the lagged frame reaches")
	_fx_lag.exp_edit = true
	_fx_lag_label = _fx_lag.get_meta("field_label")
	_register_option(_fx_lag)
	_fx_smooth = _slider(_grp_options, "Smoothing", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"Stutter → smear: 0 is a discrete stutter, 1 is a wide temporal blend")
	_register_option(_fx_smooth)

	# Snow's own view onto fx_smooth - a separate widget from Smoothing above (same
	# stored field, different meaning; the two rows never show together, see
	# _update_effect_controls, so there's no risk of them fighting over what the
	# slider looks like).
	_gust = _slider(_grp_options, "Gust", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"0 is a steady drift, 1 is chaotic gusts")
	_register_option(_gust)

	# Fur's tendril dynamics - fur-only views onto fx_smooth/fx_lag, the same
	# stored-field reuse as Gust above (the rows never show together, see
	# _update_effect_controls).
	_undul = _slider(_grp_options, "Undulation", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"Traveling waves along each strand")
	_register_option(_undul)
	_coil = _slider(_grp_options, "Coil", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"Eddies and spiral curl")
	_register_option(_coil)
	# Stickiness - 0 keeps today's free coat exactly; higher values thin the strands
	# away from natural anchors so the hair clings to the keyed surface, the tracked
	# landmark/motion centroid, and brighter regions (see the shader's fur branch).
	_bleed = _slider(_grp_options, "Bleed", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"How far each feature's paint may spread from the anatomy it found, and " +
		"how much it softens as it travels")
	_register_option(_bleed)
	_settle = _slider(_grp_options, "Settle", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"How sticky the paint is in time - higher holds its shape through " +
		"detection wobble (steadier, a touch slower to follow)")
	_register_option(_settle)
	# The clown's TRACKING knobs, as opposed to its look knobs above. The face
	# model is a blob fitter, not a landmark detector, and how well it holds is a
	# property of the footage as much as of the code - so the two smoothing rates,
	# the prediction, and how literally the picture is trusted are the author's to
	# set per clip. All four default to exactly what the constants they replaced
	# used to be.
	# THE CLOWN'S SHAPE KNOBS. What used to be Steady/Firm/Lead - three controls
	# for smoothing a detector that no longer needs smoothing. The landmark track
	# gives measured outlines, so what the effect was actually missing was a say
	# over how far those outlines get pushed past the face they came from.
	_clown_eye_sl = _slider(_grp_options, "Eye size", 0.0, 1.0,
		func(v): _edit("threshold", v),
		"How far the black grows past the eye it is painted on. It keeps the eye's " +
		"own shape whatever the size - it is that eye, bigger, not a bigger circle")
	_register_option(_clown_eye_sl)
	_clown_drip_sl = _slider(_grp_options, "Drip", 0.0, 1.0,
		func(v): _edit("sat_floor", v),
		"How far the eye black runs DOWN the cheek. It leaves the lash line's own " +
		"lower-outer corner - measured off the patch that is actually painted - so " +
		"it reads as liner running rather than a shape stuck underneath")
	_register_option(_clown_drip_sl)
	_clown_smudge_sl = _slider(_grp_options, "Smudge", 0.0, 1.0,
		func(v): _edit("swap", v),
		"How far the eye black is RUBBED past its own outline, and how softly it " +
		"ends - someone who has been crying and worrying at it, rather than a shape " +
		"with an edge. It thins away over a band instead of stopping, and reaches " +
		"further out in some places than others. 0 is already soft: a hard edge is " +
		"not a setting, it is the polygon showing")
	_register_option(_clown_smudge_sl)
	_clown_drip_w_sl = _slider(_grp_options, "Drip width", 0.0, 1.0,
		func(v): _edit("fx_y", v),
		"How heavy the run is where it leaves the eye. A fraction of THIS eye's " +
		"own width, so it stays in proportion however far Eye size has grown the " +
		"patch. 0 is a lean streak; wound up it is a smear")
	_register_option(_clown_drip_w_sl)
	_clown_drip_curve_sl = _slider(_grp_options, "Drip curve", 0.0, 1.0,
		func(v): _edit("intensity_b", v),
		"How far the run bows OUTWARD as it falls - down the outside of the cheek " +
		"rather than straight past the nose. The bow grows with distance, so the " +
		"run always leaves the lash line vertically whatever this is set to")
	_register_option(_clown_drip_curve_sl)
	_clown_smile_sl = _slider(_grp_options, "Smile width", 0.0, 0.5,
		func(v): _edit("feather", v),
		"How far the painted mouth runs past the real one. At the default it IS " +
		"the real mouth; wound up it goes Joker-wide, out toward the ears")
	_register_option(_clown_smile_sl)
	_clown_steady_sl = _slider(_grp_options, "Steadiness", 0.0, 1.0,
		func(v): _edit("hue_b", v),
		"How hard the landmark track is smoothed. The smoothing is CENTERED - it " +
		"weighs frames on both sides of now - so it costs no lag at any setting; " +
		"raising it only rounds off genuinely fast movement. 0 is already smoothed")
	_register_option(_clown_steady_sl)
	_clown_curve_sl = _slider(_grp_options, "Smile curve", 0.0, 2.0,
		func(v): _edit("fx_speed", v),
		"Sweeps the mouth's corners up into a grin or down into a sulk, leaving " +
		"its middle where the lips are. 1.0 is the mouth as measured")
	_register_option(_clown_curve_sl)
	_clown_feather_sl = _slider(_grp_options, "Edge feather", 0.0, 1.0,
		func(v): _edit("fx_x", v),
		"How far the coat's outer edge fades into the picture. The silhouette is " +
		"a hard-edged shape underneath; without this it reads as a sticker sitting " +
		"on the face rather than paint on it")
	_register_option(_clown_feather_sl)
	_clown_evidence_sl = _slider(_grp_options, "Evidence", 0.0, 1.0,
		func(v): _edit("resonance", v),
		"How much each feature is the PICTURE rather than the outline it is drawn " +
		"inside. At 0 a fixed share of every feature is the bare shape; raise it " +
		"and the outline only bounds where paint may go, while the frame's own " +
		"dark sockets and lip line decide what it actually lands on")
	_register_option(_clown_evidence_sl)

	_rain_squall = _slider(_grp_options, "Squall", 0.0, 1.0,
		func(v): _edit("fx_smooth", v),
		"How unsettled the weather is. Pan sets the direction the wind blows on " +
		"AVERAGE; this is how far the sheet wanders around it and how much the " +
		"drops scatter off each other. 0 is a still, straight downpour")
	_register_option(_rain_squall)

	# THE AUDIO GROUP. Six knobs, no color, no pattern - this effect resolves to
	# bus parameters instead of pixels (see _apply_audio_fx).
	_au_echo = _slider(_grp_options, "Echo", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"How much of the sound comes back as repeats. Two taps at unrelated " +
		"spacings, so they decay into each other instead of landing as one slap")
	_register_option(_au_echo)
	_au_time = _slider(_grp_options, "Echo time", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"How long between repeats - a slapback at the bottom, a room at the top")
	_register_option(_au_time)
	_au_amb = _slider(_grp_options, "Ambience", 0.0, 1.0, func(v): _edit("fx_density", v),
		"How wet the sound is - how much of what you hear arrived by reflection")
	_register_option(_au_amb)
	_au_room = _slider(_grp_options, "Room", 0.0, 2.0, func(v): _edit("fx_scale", v),
		"How BIG that space is, which is a different question from how wet it is - " +
		"a big dry room and a small wet one sound nothing alike")
	_register_option(_au_room)
	_au_reso = _slider(_grp_options, "Resonance", 0.0, 1.0, func(v): _edit("fx_contrast", v),
		"How much the repeats and the room ring rather than simply fading - it " +
		"darkens the tail so it reads as a space, not as a copy")
	_register_option(_au_reso)
	_au_bass = _slider(_grp_options, "Bass punch", 0.0, 1.0, func(v): _edit("fx_stick", v),
		"Weight AND attack together: it lifts the bottom two bands and compresses " +
		"underneath them, because punchy is not more bass - it is bass whose " +
		"transient survives. Lifting the bottom alone only makes a mix muddy")
	_register_option(_au_bass)
	_hollow = _slider(_grp_options, "Hollow", 0.0, 1.0, func(v): _edit("fx_stick", v),
		"Paint AROUND the eyes and mouth instead of over them - opens over a " +
		"visible eyeball or teeth, closes again on a blink or a shut mouth")
	_register_option(_hollow)
	_stick = _slider(_grp_options, "Stickiness", 0.0, 1.0, func(v): _edit("fx_stick", v),
		"0 is a free coat, 1 clings to the face/motion")
	_register_option(_stick)
	# Umbra's own three - the same stored fields fur/snow/clown reuse under
	# their own names (the groups never show together, so no schema growth).
	_wisp = _slider(_grp_options, "Wisp", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"How readily essence tears off the top of the mass and rises away, " +
		"like smoke leaving a fire")
	_register_option(_wisp)
	_cling = _slider(_grp_options, "Cling", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"How long the shadow-mass holds its shape - higher is heavier and " +
		"slower to follow her, lower is thinner and more restless")
	_register_option(_cling)
	_umbra_depth = _slider(_grp_options, "Depth", 0.0, 1.0, func(v): _edit("fx_stick", v),
		"How much light the mass swallows - some of the wall always survives " +
		"inside it, so it deepens the shadow rather than cutting a hole")
	_register_option(_umbra_depth)
	_umbra_stand = _slider(_grp_options, "Stand", 0.0, 1.0, func(v): _edit("threshold", v),
		"How far to the side of her the ghost stands. At the bottom it is " +
		"almost behind her (and mostly hidden by her); wound up it steps clear " +
		"onto the wall beside her")
	_register_option(_umbra_stand)
	_umbra_lead = _slider(_grp_options, "Lead", 0.0, 0.5, func(v): _edit("feather", v),
		"How far AHEAD of her the ghost moves, in seconds. It reads the clip " +
		"before the playhead does, so it turns its head before she turns hers " +
		"- which is what makes it look like the thing moving her")
	_register_option(_umbra_lead)
	_umbra_lean = _slider(_grp_options, "Lean", 0.0, 1.0, func(v): _edit("swap", v),
		"How far the ghost leans out along the light - upright over her at 0, " +
		"and rearing across her as it rises at 1")
	_register_option(_umbra_lean)
	_umbra_narrow = _slider(_grp_options, "Narrow", 0.0, 0.75, func(v): _edit("intensity_b", v),
		"How much taller-than-wide the ghost is drawn. Her outline squeezed " +
		"across its own spine - a long thin thing rather than a broad one")
	_register_option(_umbra_narrow)
	_umbra_gaze = _slider(_grp_options, "Gaze", 0.0, 1.0, func(v): _edit("sat_floor", v),
		"How hard the ghost's eyes burn. They sit on her own eyes, carried " +
		"through the same throw as the rest of it, so they are always on its " +
		"head - 0 is a faceless shadow")
	_register_option(_umbra_gaze)
	# The eye color needed a control of its own. hue_b was wired through to the
	# shader but nothing could edit it, so the eyes were stuck on whatever the
	# session happened to have stored - 0.58, cyan, for anything saved before
	# the default changed. "Cannot change their color" was literally true.
	var eye_lbl := _label("Eye color", "The color the ghost's eyes burn - red by default")
	_grp_options.add_child(eye_lbl)
	_color_eye = ColorPickerButton.new()
	_color_eye.focus_mode = Control.FOCUS_NONE
	_color_eye.custom_minimum_size = Vector2(0, 32)
	_color_eye.edit_alpha = false
	_color_eye.tooltip_text = eye_lbl.tooltip_text
	_color_eye.set_meta("field_label", eye_lbl)
	_color_eye.color_changed.connect(func(c): _edit("hue_b", c.h))
	_grp_options.add_child(_color_eye)
	_register_option(_color_eye)

	# Repaint's two. The paint color is stored as three fields because a hue
	# alone cannot say "black" - and black is the whole point of the effect's
	# first use (a yellow wall painted out). Same field-reuse idiom as umbra's
	# six above: fx_stick/fx_tint mean something else under other effects, and
	# the groups never show together.
	var paint_lbl := _label("Paint color",
		"The color the keyed color BECOMES - a whole color, so black and white " +
		"are both reachable. Black by default")
	_grp_options.add_child(paint_lbl)
	_color_paint = ColorPickerButton.new()
	_color_paint.focus_mode = Control.FOCUS_NONE
	_color_paint.custom_minimum_size = Vector2(0, 32)
	_color_paint.edit_alpha = false
	_color_paint.tooltip_text = paint_lbl.tooltip_text
	_color_paint.set_meta("field_label", paint_lbl)
	# Three fields, one pick. _edit creates the marker on the first call and
	# edits it on the other two, so this is one marker, not three.
	_color_paint.color_changed.connect(func(c):
		_edit("hue_b", c.h)
		_edit("fx_stick", c.s)
		_edit("fx_tint", c.v))
	_grp_options.add_child(_color_paint)
	_register_option(_color_paint)
	_paint_reach = _slider(_grp_options, "Reach", 0.0, 1.0, func(v): _edit("fx_contrast", v),
		"How far into weakly colored pixels the paint carries - low keeps it to " +
		"the vivid core of the color, high takes the washed-out and shadowed parts " +
		"of the same wall with it")
	_register_option(_paint_reach)
	_paint_smooth = _slider(_grp_options, "Smoothing", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"How wide the edge of the paint is averaged. Compressed video stores color " +
		"at quarter resolution in blocks, so a boundary keyed pixel-by-pixel comes out " +
		"blocky and crawls frame to frame - raise this until it stops. Some averaging " +
		"always happens; this is how much")
	_register_option(_paint_smooth)

	# THE REGION - universal, not one effect's group: any layer can be confined
	# to a box. Two panel controls (the box itself is dragged on the video, see
	# _build_region_overlay), because a color key cannot separate two things
	# that are the same color and position can.
	# A label of its own even though the checkbox carries text: every row here is
	# a (label, control) pair and _apply_sort re-orders them two children at a
	# time, so a control without one desynchronizes the whole list.
	var region_lbl := _label("Region",
		"Confine this layer to a box you drag on the video - for when the color " +
		"you want gone and the color you want kept are the SAME color, and only " +
		"their position tells them apart. For the clown it also tells the face " +
		"detector WHERE TO LOOK, which is the fastest cure for a mask that has " +
		"latched onto a wall the color of skin")
	_grp_options.add_child(region_lbl)
	_region_on = CheckBox.new()
	_region_on.text = "Limit to a box"
	_region_on.focus_mode = Control.FOCUS_NONE
	_region_on.tooltip_text = region_lbl.tooltip_text
	_region_on.set_meta("field_label", region_lbl)
	_region_on.toggled.connect(_region.on_toggled)
	_grp_options.add_child(_region_on)
	_register_option(_region_on)
	_region_soft = _slider(_grp_options, "Region edge", 0.0, 1.0,
		func(v): _edit("reg_soft", v),
		"How gradually the layer fades out at the region's border - 0 is a hard " +
		"rectangular cut, which reads as a rectangular cut")
	_register_option(_region_soft)

	# Every marker is a ramp or a damp - there is no plain/neutral marker (see
	# MaskSession class doc). Both transition TO this marker's values; the kind is
	# which side of the anchor the transition occupies: a ramp eases in BEFORE,
	# complete at the anchor; a damp begins AT the anchor and accumulates after.
	# Lives in _grp_options (not a fixed spot below it) so it's part of the same
	# sortable list as the effect knobs - see _apply_sort/_register_option; a
	# pick-type control with no slider, it sorts to the bottom under Energy mode.
	var _kind_label := _label("Kind",
		"Which way this marker's change runs - ramp eases in before it, damp accumulates after")
	_grp_options.add_child(_kind_label)
	_kind = OptionButton.new()
	_kind.focus_mode = Control.FOCUS_NONE
	_kind.tooltip_text = "Ramp eases in before this marker; damp accumulates after it"
	_kind.set_meta("field_label", _kind_label)
	for i in MaskSession.MARKER_KINDS.size():
		_kind.add_item(MaskSession.MARKER_KINDS[i].capitalize(), i)
	_kind.item_selected.connect(func(id): _edit("kind", float(id)))
	_grp_options.add_child(_kind)
	_register_option(_kind)
	# Exponential response: fine-grained fractions of a second on the left, whole
	# minutes on the right - one slider covers a subtle 0.2s blend and a transition
	# spanning the entire clip. (exp_edit needs a strictly positive min.)
	_marker_duration = _slider(_grp_options, "Ramp/damp span (s)", 0.05, maxf(8.0, session.duration),
		func(v): _edit("duration", v),
		"How long the ramp (before) or damp (after) transition takes, in seconds")
	_marker_duration.exp_edit = true
	_marker_duration.step = 0.01
	_register_option(_marker_duration)

	# --- create/delete + the sequential list, pinned to the panel's bottom with its
	# --- own scroll - the whole "manage markers" workflow stays visible together,
	# --- rather than the create buttons living up in the scrolling edit area where
	# --- reaching them means scrolling past everything else first.
	var list_col: VBoxContainer = _panel.add_footer_card("markers", "Markers", &"look")
	list_col.add_theme_constant_override("separation", 4)

	_marker_label = Label.new()
	_marker_label.add_theme_font_size_override("font_size", 12)
	_marker_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_marker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_col.add_child(_marker_label)

	# See feedback/0019: a preview of what Ctrl+Z would revert, so undo isn't a
	# blind guess - kept right above the buttons that create the history it
	# describes. Populated by _refresh_history_label, driven off _undo_descs.
	_history_label = Label.new()
	_history_label.add_theme_font_size_override("font_size", 12)
	_history_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_label.tooltip_text = "What Ctrl+Z would revert right now"
	list_col.add_child(_history_label)
	_undo.refresh_label()

	var mrow := HBoxContainer.new()
	list_col.add_child(mrow)
	var ramp_btn := Button.new()
	ramp_btn.text = "+ Ramp"
	ramp_btn.tooltip_text = "Eases IN before the playhead, arriving here complete"
	ramp_btn.focus_mode = Control.FOCUS_NONE
	ramp_btn.pressed.connect(func(): _add_marker_at_playhead(0))
	mrow.add_child(ramp_btn)
	var damp_btn := Button.new()
	damp_btn.text = "+ Damp"
	damp_btn.tooltip_text = "Begins here and accumulates over the span that follows"
	damp_btn.focus_mode = Control.FOCUS_NONE
	damp_btn.pressed.connect(func(): _add_marker_at_playhead(1))
	mrow.add_child(damp_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.pressed.connect(_delete_selected)
	mrow.add_child(del_btn)

	# The marker list's header, and beside it the switch for whether playback drags
	# the SELECTION along with it (see _process). It lives here rather than in the
	# options panel because it is about the list, not about a marker - nothing it
	# does is stored on one.
	var order_row := HBoxContainer.new()
	# THE LABEL TAKES THE SLACK, not a spacer beside it. Every label here
	# word-wraps (see _label - it is what stops a long one widening the whole
	# panel), and a wrapping label's minimum width is tiny. Put an expanding
	# spacer next to one in an HBox and the label is squeezed to that minimum,
	# which renders "In order" as a column of single letters and makes the row as
	# tall as the text is long. Letting the label expand instead leaves the
	# checkbox at its natural size on the right and the text on one line.
	var order_lbl := _label("In order")
	order_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_row.add_child(order_lbl)
	_follow_playhead = CheckBox.new()
	_follow_playhead.text = "Follow"
	# REMEMBERED ACROSS SESSIONS, in user://ghost.cfg rather than in the session
	# JSON. It is a preference about how the EDITOR behaves - the same reason it
	# sits by the list header and not in the options panel - so it belongs beside
	# the other per-user settings; storing it on the session would mean opening
	# somebody else's work silently switched it back.
	_follow_playhead.set_pressed_no_signal(_face.load_follow())
	_follow_playhead.toggled.connect(_face.save_follow)
	_follow_playhead.focus_mode = Control.FOCUS_NONE
	_follow_playhead.tooltip_text = "Select each marker as the playhead reaches it. " + \
		"On, scrubbing a session walks you through it without clicking every flag; " + \
		"OFF, the selection stays where you put it - which is what you want while " + \
		"tuning one marker's knobs during playback, since otherwise the next marker " + \
		"steals the panel mid-adjustment"
	order_row.add_child(_follow_playhead)
	list_col.add_child(order_row)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 150)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_col.add_child(list_scroll)

	_marker_list = VBoxContainer.new()
	_marker_list.add_theme_constant_override("separation", 2)
	_marker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_marker_list)


## `tip` is the full explanation shown on mouse-over (Godot's native tooltip) -
## labels themselves stay short so the panel reads clean; see the feedback that
## drove this (0005): inline "Label - long explanation" text was the ambiguity
## complaint, not just missing descriptions.
func _label(text: String, tip: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	# A long, unwrapped label's natural width becomes the whole column's minimum
	# width - that's exactly what pushed the panel wider than PANEL_W and over the
	# timeline (a real bug: "no marker selected..." is longer than most other panel
	# text, so it only showed up after deleting one). Word-wrap caps the minimum to
	# the longest WORD instead of the longest sentence.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_PASS   # let the tooltip trigger over the label itself
	l.tooltip_text = tip
	return l


func _slider(col: VBoxContainer, text: String, lo: float, hi: float, cb: Callable, tip: String = "") -> HSlider:
	var lbl := _label(text, tip)
	col.add_child(lbl)
	var s := HSlider.new()
	# Remember the label so a single knob (label + slider) can be hidden together
	# when the effect doesn't consume it - see _show_field / _update_effect_controls.
	s.set_meta("field_label", lbl)
	s.focus_mode = Control.FOCUS_NONE
	# The wheel belongs to the panel's ScrollContainer, never to a slider you
	# happen to pass over on the way down - the panel is long enough now that
	# scrolling it drags random knobs (and silently edits the marker under
	# them). Drag-only.
	s.scrollable = false
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.tooltip_text = tip   # hovering the slider itself explains it too, not just the label above
	s.value_changed.connect(cb)
	col.add_child(s)
	return s


## Show/hide one knob - the slider AND the label above it (stored on the slider
## by _slider, or passed for the hand-built pattern rows). Used to prune pattern
## knobs an effect doesn't read (MaskSession.PATTERN_KNOBS).
func _show_field(slider: Control, vis: bool, label: Control = null) -> void:
	if slider != null:
		slider.visible = vis
	var lbl: Variant = label
	if lbl == null and slider != null and slider.has_meta("field_label"):
		lbl = slider.get_meta("field_label")
	if lbl != null:
		(lbl as Control).visible = vis


## Registers a slider or pick-type control (label stashed via set_meta, either by
## _slider or by hand for non-Range controls like an OptionButton) into the flat
## sortable list - see _apply_sort.
func _register_option(ctrl: Control) -> void:
	_options.append({"label": ctrl.get_meta("field_label"), "control": ctrl})


## Re-orders _options within _grp_options per the active sort mode: alphabetical by
## each row's CURRENT label text (which itself changes per effect - e.g. Contrast ->
## Sensitivity for snow), or "energy" - how wide each slider's fill currently reads,
## fullest first (see _option_energy). Pick-type controls with no slider (e.g. Kind)
## have no fill to compare, so they sink below every slider and break ties alphabetically
## among themselves. Hidden rows (this effect doesn't use them) are left trailing after
## the visible ones - their order doesn't matter, they're off screen. Re-run whenever
## the effect/visibility changes (_update_effect_controls) or a mode is picked in
## _sort_dropdown - never on a live drag, so a slider never jumps out from under the
## mouse mid-edit.
func _apply_sort() -> void:
	if _grp_options == null:
		return
	var shown: Array = _options.filter(func(o): return o.control.visible)
	var hidden: Array = _options.filter(func(o): return not o.control.visible)
	match _sort_mode:
		1:
			shown.sort_custom(func(a, b): return a.label.text.nocasecmp_to(b.label.text) > 0)
		2:
			shown.sort_custom(func(a, b):
				var ea: float = _option_energy(a.control)
				var eb: float = _option_energy(b.control)
				if ea == eb:
					return a.label.text.nocasecmp_to(b.label.text) < 0
				return ea > eb)
		_:
			shown.sort_custom(func(a, b): return a.label.text.nocasecmp_to(b.label.text) < 0)
	var idx := 0
	for o in shown + hidden:
		_grp_options.move_child(o.label, idx)
		idx += 1
		_grp_options.move_child(o.control, idx)
		idx += 1


## How "present" a control's current value is, for the "Energy" sort mode. For a
## slider this is its actual fill fraction - the handle's position between the
## track's left and right ends, min at 0 and max at 1 - matching the bar you
## actually see, so a slider barely nudged off its floor reads as low energy even
## if that floor sits far from the range's midpoint. Range.get_as_ratio() (rather
## than a hand-rolled linear (value-min)/span) is what makes this match what's on
## screen for the exp_edit sliders (Scale/Velocity/Lag/Ramp-damp span): those are
## drawn on a logarithmic track, so a linear fraction would read a handle sitting
## visibly right-of-center as barely-there. Pick-type controls with no slider (not
## a Range, e.g. Kind's OptionButton) have nothing to compare, so they return a
## sentinel below any real slider value - see _apply_sort, where that sinks them to
## the bottom and falls back to alphabetical among themselves.
func _option_energy(ctrl: Control) -> float:
	if not (ctrl is Range):
		return -1.0
	return (ctrl as Range).get_as_ratio()


func _effect_menu(col: VBoxContainer, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.tooltip_text = "Which visual treatment this layer applies"
	for i in MaskSession.MASK_EFFECTS.size():
		ob.add_item(MaskSession.MASK_EFFECTS[i], i)
	ob.item_selected.connect(cb)
	col.add_child(ob)
	return ob


func _refresh_panel() -> void:
	# Every slider below is written with set_value_no_signal, but a
	# ColorPickerButton has no such door - assigning `color` can emit
	# color_changed, which lands in _edit. With nothing selected _edit CREATES a
	# marker, so merely repainting the panel could mint one stamped with the
	# DEFAULT hue. Guard the whole sync rather than the two pickers, so any
	# control added here later is safe by default.
	# The flag is only ever meant to be true INSIDE this call. If
	# _refresh_panel_inner ever aborts partway - a null control, a bad index -
	# GDScript unwinds the function and the reset below never runs, and from
	# that moment every _edit() in the session returns early and silently
	# discards the user's work. That failure is indistinguishable from "nothing
	# saves". _process clears it defensively every frame for exactly that
	# reason; this reset is the normal path, that one is the seatbelt.
	_syncing = true
	_refresh_panel_inner()
	_syncing = false


func _refresh_panel_inner() -> void:
	var m: Dictionary = _selected if _selected != null else MaskSession.DEFAULTS
	if OS.has_environment("GHOST_PANEL_DEBUG"):
		print("PANELDBG selected=%s hue_a=%.4f hue_b=%.4f thr=%.3f feather=%.3f sat=%.3f scale=%.3f"
			% [str(_selected != null), float(m.get("hue_a", -1)), float(m.get("hue_b", -1)),
			float(m.get("threshold", -1)), float(m.get("feather", -1)),
			float(m.get("sat_floor", -1)), float(m.get("fx_scale", -1))])
	_kind.select(int(m.get("kind", 0.0)))
	# The stored pick, all three components. It used to rebuild the swatch as
	# from_hsv(hue_a, 0.85, 0.9), which round-trips a color into a different one.
	_color_a.color = Color.from_hsv(float(m.get("hue_a", 0.02)),
		float(m.get("key_sat", 0.85)), float(m.get("key_val", 0.9)))
	if _color_eye != null:
		_color_eye.color = Color.from_hsv(float(m.get("hue_b", 0.0)), 0.88, 1.0)
	if _color_paint != null:
		# The stored color itself, all three components - this picker IS the
		# value, not a hue preview of it.
		_color_paint.color = Color.from_hsv(float(m.get("hue_b", 0.0)),
			float(m.get("fx_stick", 0.0)), float(m.get("fx_tint", 0.0)))
	_hue_a.set_value_no_signal(float(m.get("fx_tint", 0.0)))
	_threshold.set_value_no_signal(float(m.get("threshold", 0.24)))
	_feather.set_value_no_signal(float(m.get("feather", 0.12)))
	_sat_floor.set_value_no_signal(float(m.get("sat_floor", 0.18)))
	_effect_a.select(int(m.get("effect_a", 0)))
	_intensity_a.set_value_no_signal(float(m.get("intensity_a", 1.0)))
	_marker_duration.set_value_no_signal(float(m.get("duration", 1.0)))
	_fx_x.set_value_no_signal(float(m.get("fx_x", 0.0)))
	_fx_y.set_value_no_signal(float(m.get("fx_y", 0.0)))
	_fx_scale.set_value_no_signal(float(m.get("fx_scale", 1.0)))
	_fx_density.set_value_no_signal(float(m.get("fx_density", 0.45)))
	_fx_contrast.set_value_no_signal(float(m.get("fx_contrast", 0.5)))
	_fx_speed.set_value_no_signal(float(m.get("fx_speed", 1.0)))
	_fx_lag.set_value_no_signal(float(m.get("fx_lag", 0.35)))
	_fx_smooth.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_gust.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_undul.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_coil.set_value_no_signal(float(m.get("fx_lag", 0.35)))
	_stick.set_value_no_signal(float(m.get("fx_stick", 0.0)))
	_bleed.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_settle.set_value_no_signal(float(m.get("fx_lag", 0.35)))
	_hollow.set_value_no_signal(float(m.get("fx_stick", 0.0)))
	_clown_eye_sl.set_value_no_signal(float(m.get("threshold", 0.24)))
	_clown_drip_sl.set_value_no_signal(float(m.get("sat_floor", 0.18)))
	_clown_smudge_sl.set_value_no_signal(float(m.get("swap", 0.0)))
	_clown_drip_w_sl.set_value_no_signal(float(m.get("fx_y", 0.0)))
	_clown_drip_curve_sl.set_value_no_signal(float(m.get("intensity_b", 0.0)))
	_clown_smile_sl.set_value_no_signal(float(m.get("feather", 0.12)))
	_clown_curve_sl.set_value_no_signal(float(m.get("fx_speed", 1.0)))
	_clown_steady_sl.set_value_no_signal(float(m.get("hue_b", 0.0)))
	_rain_squall.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_au_echo.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_au_time.set_value_no_signal(float(m.get("fx_lag", 0.35)))
	_au_amb.set_value_no_signal(float(m.get("fx_density", 0.45)))
	_au_room.set_value_no_signal(float(m.get("fx_scale", 1.0)))
	_au_reso.set_value_no_signal(float(m.get("fx_contrast", 0.5)))
	_au_bass.set_value_no_signal(float(m.get("fx_stick", 0.0)))
	_clown_feather_sl.set_value_no_signal(float(m.get("fx_x", 0.0)))
	_clown_evidence_sl.set_value_no_signal(float(m.get("resonance", 0.0)))
	# Umbra's six. Every control in this panel is a VIEW onto a stored field and
	# has to be re-read here, or it shows its construction value (0) while the
	# marker holds something else - and the next drag then writes from that
	# wrong starting point. These were added without their sync lines, which is
	# why umbra's settings appeared to reset on every restart.
	_wisp.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_cling.set_value_no_signal(float(m.get("fx_lag", 0.35)))
	_umbra_depth.set_value_no_signal(float(m.get("fx_stick", 0.0)))
	_umbra_stand.set_value_no_signal(float(m.get("threshold", 0.24)))
	_umbra_lead.set_value_no_signal(float(m.get("feather", 0.12)))
	_umbra_gaze.set_value_no_signal(float(m.get("sat_floor", 0.18)))
	_umbra_lean.set_value_no_signal(float(m.get("swap", 0.45)))
	_umbra_narrow.set_value_no_signal(float(m.get("intensity_b", 0.35)))
	_paint_reach.set_value_no_signal(float(m.get("fx_contrast", 0.5)))
	_paint_smooth.set_value_no_signal(float(m.get("fx_smooth", 0.0)))
	_region_on.set_pressed_no_signal(MaskSession.has_region(m))
	_region_soft.set_value_no_signal(float(m.get("reg_soft", 0.0)))
	_resonance.set_value_no_signal(float(m.get("resonance", 0.0)))
	_update_effect_controls(int(m.get("effect_a", 0)))
	_region.sync()   # selection changed - the box follows the marker
	_refresh_marker_label()


## The control hierarchy in action (MaskSession.EFFECT_CONTROLS): show only the
## option groups the selected effect consumes. Threshold doubles as restore's
## reach - same stored field, relabeled so it says what it does here.
func _update_effect_controls(effect_id: int) -> void:
	var groups: Array = MaskSession.EFFECT_CONTROLS.get(effect_id, [])
	# clear fades out EVERYTHING earlier - it has no target color at all. snow
	# picks its foreground/background split automatically - it has no target
	# color either. arealight lights the whole frame, not a keyed color.
	# meta mirrors the whole workspace - it keys on nothing, so no color picker.
	# umbra joins them: it used to name the WALL its detector matched against, and
	# there is no wall hypothesis any more - the ghost is her own silhouette, so
	# the picker had nothing left to say. Its own Eye color picker stays.
	var has_color := effect_id != MaskSession.EFFECT_CLEAR and effect_id != MaskSession.EFFECT_SNOW \
		and effect_id != MaskSession.EFFECT_SERPENT and effect_id != MaskSession.EFFECT_AREALIGHT \
		and effect_id != MaskSession.EFFECT_META and effect_id != MaskSession.EFFECT_RAIN \
		and effect_id != MaskSession.EFFECT_AUDIO and effect_id != MaskSession.EFFECT_UMBRA
	_grp_color.visible = has_color
	# Morph shows only where there's a palette to rotate (the fixed-palette
	# emissives + crystal's glass + fur's key-tinted coat + clown's paint).
	var has_morph: bool = effect_id in [1, 2, 5, MaskSession.EFFECT_RAIN, MaskSession.EFFECT_CRYSTAL,
		MaskSession.EFFECT_SNOW, MaskSession.EFFECT_FUR, MaskSession.EFFECT_SERPENT,
		MaskSession.EFFECT_CLOWN, MaskSession.EFFECT_UMBRA]
	if _key_color_label != null:
		if effect_id == MaskSession.EFFECT_REPAINT:
			# Repaint has two color pickers and they are easy to confuse - name
			# both ends of the swap rather than leaving one called "Key color".
			_key_color_label.text = "Color to replace"
			_key_color_label.tooltip_text = "The color being painted over - " + \
				"pick it off the thing you want gone (the wall, a shirt)"
		else:
			_key_color_label.text = "Key color"
			_key_color_label.tooltip_text = "The color this channel targets - what it keys or paints"
	_show_field(_hue_a, has_morph)
	_show_field(_threshold, groups.has("keying") or groups.has("reach"), _threshold_label)
	if groups.has("reach"):
		_threshold_label.text = "Reach"
		_threshold_label.tooltip_text = "How wide around the picked color this restore reaches"
	else:
		_threshold_label.text = "Threshold"
		_threshold_label.tooltip_text = "How far a pixel's hue may drift from the key color and still be masked"
	_threshold.tooltip_text = _threshold_label.tooltip_text
	_show_field(_feather, groups.has("keying"))
	_show_field(_sat_floor, groups.has("keying"))
	# Prune the individual pattern knobs this effect never reads ("only show
	# properties that can be used"). Effects absent from PATTERN_KNOBS show them
	# all (the default); listed ones show only their subset.
	var has_pattern := groups.has("pattern")
	var knobs: Array = MaskSession.PATTERN_KNOBS.get(effect_id, MaskSession.PATTERN_KNOBS_ALL) \
		if has_pattern else []
	_show_field(_fx_scale, has_pattern and knobs.has("scale"))
	_show_field(_fx_x, has_pattern and knobs.has("pan"), _fx_x_label)
	_show_field(_fx_y, has_pattern and knobs.has("pan"), _fx_y_label)
	_show_field(_fx_density, has_pattern and knobs.has("coverage"), _fx_density_label)
	_show_field(_fx_contrast, has_pattern and knobs.has("contrast"), _fx_contrast_label)
	_show_field(_fx_speed, has_pattern and knobs.has("velocity"))
	_show_field(_resonance, has_pattern and knobs.has("resonance"))
	_show_field(_fx_lag, groups.has("echo"), _fx_lag_label)
	_show_field(_fx_smooth, groups.has("echo"))
	_show_field(_gust, groups.has("snow"))
	_show_field(_undul, groups.has("fur"))
	_show_field(_coil, groups.has("fur"))
	_show_field(_stick, groups.has("fur"))
	_show_field(_bleed, groups.has("clown"))
	_show_field(_settle, groups.has("clown"))
	_show_field(_hollow, groups.has("clown"))
	_show_field(_clown_eye_sl, groups.has("clown"))
	_show_field(_clown_drip_sl, groups.has("clown"))
	_show_field(_clown_smudge_sl, groups.has("clown"))
	_show_field(_clown_drip_w_sl, groups.has("clown"))
	_show_field(_clown_drip_curve_sl, groups.has("clown"))
	_show_field(_clown_smile_sl, groups.has("clown"))
	_show_field(_clown_curve_sl, groups.has("clown"))
	_show_field(_clown_steady_sl, groups.has("clown"))
	_show_field(_rain_squall, groups.has("rain"))
	for au in [_au_echo, _au_time, _au_amb, _au_room, _au_reso, _au_bass]:
		_show_field(au, groups.has("audio"))
	_show_field(_clown_feather_sl, groups.has("clown"))
	_show_field(_clown_evidence_sl, groups.has("clown"))
	_show_field(_wisp, groups.has("umbra"))
	_show_field(_cling, groups.has("umbra"))
	_show_field(_umbra_depth, groups.has("umbra"))
	_show_field(_umbra_stand, groups.has("umbra"))
	_show_field(_umbra_lead, groups.has("umbra"))
	_show_field(_umbra_lean, groups.has("umbra"))
	_show_field(_umbra_narrow, groups.has("umbra"))
	_show_field(_umbra_gaze, groups.has("umbra"))
	_show_field(_color_eye, groups.has("umbra"))
	_show_field(_color_paint, groups.has("repaint"))
	_show_field(_paint_reach, groups.has("repaint"))
	_show_field(_paint_smooth, groups.has("repaint"))
	# The region is UNIVERSAL - not in EFFECT_CONTROLS, because it restricts WHERE
	# a layer acts rather than what it draws, and that question is meaningful for
	# every effect. Hidden only where the effect draws nothing of its own to
	# confine (restore and clear act on other layers, not on pixels).
	var can_region: bool = effect_id != MaskSession.EFFECT_RESTORE \
		and effect_id != MaskSession.EFFECT_CLEAR
	_show_field(_region_on, can_region)
	_show_field(_region_soft, can_region and _region_on.button_pressed)
	var is_oracle := effect_id == MaskSession.EFFECT_ORACLE
	_fx_lag_label.text = "Lead (s)" if is_oracle else "Lag (s)"
	_fx_lag_label.tooltip_text = "How far ahead it leads" if is_oracle else "How the past is worn"
	_fx_lag.tooltip_text = _fx_lag_label.tooltip_text
	var is_snow := effect_id == MaskSession.EFFECT_SNOW
	var is_arealight := effect_id == MaskSession.EFFECT_AREALIGHT
	var is_clown := effect_id == MaskSession.EFFECT_CLOWN
	var is_umbra := effect_id == MaskSession.EFFECT_UMBRA
	if is_snow:
		_fx_contrast_label.text = "Sensitivity"
		_fx_contrast_label.tooltip_text = "How far snow's fall reaches toward the subject"
	elif is_umbra:
		_fx_contrast_label.text = "Roil"
		_fx_contrast_label.tooltip_text = "Turbulence in the mass - how hard the currents " + \
			"churn inside it and how much its silhouette fluctuates"
	elif is_clown:
		_fx_contrast_label.text = "Smear"
		_fx_contrast_label.tooltip_text = "How ragged and smeared the paint is - drooping eye " + \
			"patches, chewed edges, the mouth dragged into a grin"
	elif effect_id == MaskSession.EFFECT_RAIN:
		_fx_contrast_label.text = "Depth"
		_fx_contrast_label.tooltip_text = "Where the near sheet gives way to the far one - " + \
			"0 puts all the weather BEHIND the subject (confined to the dark background), " + \
			"1 brings it all in front, across the lens"
	elif is_arealight:
		_fx_contrast_label.text = "Envelope"
		_fx_contrast_label.tooltip_text = "Where along the rig's mood this sits - warm, soft, " + \
			"single-source practical at 0, toward cold, hard, full-spectrum multi-source at 1"
	else:
		_fx_contrast_label.text = "Contrast"
		_fx_contrast_label.tooltip_text = "Edge hardness of the pattern - 0.5 is neutral"
	_fx_contrast.tooltip_text = _fx_contrast_label.tooltip_text
	_fx_x_label.text = "Wind X" if (is_snow or effect_id == MaskSession.EFFECT_RAIN) else "Pan X"
	_fx_x_label.tooltip_text = "Fall direction - horizontal component" \
		if is_snow else "Shifts the pattern horizontally over the frame"
	_fx_x.tooltip_text = _fx_x_label.tooltip_text
	_fx_y_label.text = "Wind Y" if (is_snow or effect_id == MaskSession.EFFECT_RAIN) else "Pan Y"
	_fx_y_label.tooltip_text = "Fall direction - vertical component" \
		if is_snow else "Shifts the pattern vertically over the frame"
	_fx_y.tooltip_text = _fx_y_label.tooltip_text
	var is_crystal := effect_id == MaskSession.EFFECT_CRYSTAL
	var is_rain := effect_id == MaskSession.EFFECT_RAIN
	if is_crystal:
		_fx_density_label.text = "Stickiness"
	elif is_clown:
		_fx_density_label.text = "Wear"
	elif is_umbra:
		_fx_density_label.text = "Loom"
	elif is_rain:
		_fx_density_label.text = "Amount"
	else:
		_fx_density_label.text = "Coverage"
	if is_crystal:
		_fx_density_label.tooltip_text = "Pull toward the tracked face's edges"
	elif is_rain:
		_fx_density_label.tooltip_text = "How much rain falls at all. Most columns are " + \
			"EMPTY at the bottom of the slider - that is what makes a drizzle a drizzle " + \
			"rather than a finer downpour"
	elif is_clown:
		_fx_density_label.tooltip_text = "Cracks and chips in the white paint - 0 fresh " + \
			"coat, 1 ruined. Inside the face it MARKS the paint rather than opening it: " + \
			"the coat covers the outline it was given, and wear that perforates a mask " + \
			"just reads as the mask being broken"
	elif is_umbra:
		_fx_density_label.tooltip_text = "How much of the ghost is drawn - a head and a " + \
			"collar at 0, a head, shoulders and chest at 1. Below that it dissolves into " + \
			"the dark, because her whole outline magnified is a wall of black with " + \
			"nothing in it to read"
	else:
		_fx_density_label.tooltip_text = "How much of the keyed region the pattern consumes - 0 untouched, 1 fully devoured"
	_fx_density.tooltip_text = _fx_density_label.tooltip_text
	# "Strength" means something different for the two subtractive effects - the
	# ambiguity the feedback flagged (an unlabeled, unexplained "Intensity").
	if effect_id == MaskSession.EFFECT_RESTORE:
		_intensity_label.tooltip_text = "How completely this restore fades out earlier layers on this color"
	elif effect_id == MaskSession.EFFECT_CLEAR:
		_intensity_label.tooltip_text = "How completely this clears every earlier layer"
	else:
		_intensity_label.tooltip_text = "How strongly this layer's effect applies"
	_intensity_a.tooltip_text = _intensity_label.tooltip_text
	_apply_sort()   # visibility/labels just changed - re-rank the now-current set (see _apply_sort)


func _toggle_help() -> void:
	if _help_panel != null:
		_help_panel.visible = not _help_panel.visible


## The keyboard map, centered over the video (F1 / the panel's one Help
## button). This is where the buttons went: everything the old toolbar did is
## a key now, and this overlay is how anyone who never learned the shortcuts
## finds them. Keep in sync with _unhandled_input.
func _build_help_overlay() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.visible = false
	_help_panel.z_index = 40
	var hm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + side, 20)
	_help_panel.add_child(hm)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 7)
	hm.add_child(hv)
	var ht := Label.new()
	ht.text = "Keyboard"
	ht.add_theme_font_size_override("font_size", 18)
	hv.add_child(ht)
	for pair in [
		["Space", "play / pause"],
		["←  →", "back / ahead 10 s (Shift: a minute) · Home: the start"],
		["V", "cycle view - raw → PiP (raw) → PiP (fx) → both → full fx"],
		["P (hold)", "peek raw footage - display only, edits nothing"],
		["T", "import a second video track (picture-in-picture)"],
		["Ctrl+Z", "undo"],
		["Ctrl+Shift+Z", "redo (also Ctrl+Y)"],
		["`", "feedback console"],
		["F11", "fullscreen"],
		["F1", "this help (Esc closes it)"],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var kl := Label.new()
		kl.text = pair[0]
		kl.custom_minimum_size = Vector2(130, 0)
		kl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		row.add_child(kl)
		var dl := Label.new()
		dl.text = pair[1]
		dl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94))
		row.add_child(dl)
		hv.add_child(row)
	hv.add_child(HSeparator.new())
	for note in [
		"Timeline - click/drag scrubs · drag markers to move them · Ctrl+scroll zooms at the cursor, plain scroll pans when zoomed · drag clip/track edges to trim",
		"Editing - touching any knob plants a ramp at the playhead if nothing is selected · sliders are drag-only, the wheel always scrolls the panel",
	]:
		var nl := Label.new()
		nl.text = note
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(560, 0)
		nl.add_theme_font_size_override("font_size", 12)
		nl.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
		hv.add_child(nl)
	# Centered over the VIDEO side, not the whole window (the wrapper starts
	# at PANEL_W so the box doesn't sit half-under the left panel). The
	# wrapper ignores the mouse; the box itself still catches its own clicks.
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = VIDEO_LEFT
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	wrap.add_child(_help_panel)


# --- the status line ------------------------------------------------------------------------------
# Shared bottom-right notification: prep progress AND export progress use the
# same label, same position - one status line, whatever phase produced it.


func _build_status_label() -> void:
	_status = Label.new()
	_status.name = "MaskStatus"
	_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Right edge clears the console's >_ slot (-156..-116, see console.gd).
	_status.offset_left = -592
	_status.offset_top = -64
	_status.offset_right = -160
	_status.offset_bottom = -28
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.visible = false
	# Built before the chrome/timeline exist (see the doc comment on the _status
	# var) so prep messages show pre-session; once the chrome IS built, MaskTimeline's
	# near-opaque background (mask_timeline.gd's _draw) is added afterward and, being
	# a later sibling, painted over this label - silently swallowing every status this
	# label ever shows for the rest of the session (export progress included; feedback
	# 0026). z_index keeps it on top regardless of what gets added later.
	_status.z_index = 5
	add_child(_status)


func _set_status(text: String) -> void:
	if _status == null:     # render_mode never builds it - status there is stdout only
		print("ghost mask: ", text)
		return
	_status.text = text
	_status.visible = true


# --- markers: planted, edited, selected -----------------------------------------------------------


## Every panel edit targets the selected marker; if none is selected yet, planting
## one at the current playhead is the edit's first move (a knob you touch becomes a
## marker - no separate "create" step needed for the common case). Defaults to a
## ramp when auto-created this way; press +Damp explicitly for the other kind.
func _edit(field: String, value: float) -> void:
	if _syncing:
		return   # a programmatic panel repaint, not the user - see _refresh_panel
	var m: Variant = _selected
	var created := false
	if m == null:
		_undo.push("", "created a marker")   # about to create one - always its own boundary
		m = session.add_marker(_player.stream_position if _player != null else 0.0)
		_selected = m
		_select_generation += 1
		created = true
	else:
		_undo.push("marker:%d:%s" % [_select_generation, field], "adjusted %s" % field.capitalize())
	m[field] = value
	# Assigning a drawing effect to a marker whose OWN view shows no fx surface is
	# a silent foot-gun: the layer holds forever but this marker's view hides it -
	# "I configured fire and nothing shows" (a real session lost its fire exactly
	# this way: the view button had been cycled to Raw on the same marker). Bump
	# the view to the nearest fx-showing mode, preserving the surface choice:
	# raw -> masked, pip_raw -> pip. Never behind the user's back on an unrelated
	# knob, and never for restore/clear (they draw nothing of their own).
	#
	# THE HOLE THIS USED TO HAVE, and it swallowed a whole session: the bump fired
	# only on effect_a/intensity_a, but a marker's DEFAULT effect is already erase
	# and its default strength is already 1.0 - so anyone whose first move is the
	# color picker (the natural first move: "erase THIS color") never touches
	# either field, and the marker they just minted was born at view_mode raw,
	# which renders no shader pass at all. The effect was configured, saved and
	# completely invisible, and looked exactly like the effect being broken.
	# So a marker MINTED by a panel touch bumps too, whichever knob minted it -
	# it cannot have a deliberate view choice yet, it only has the inherited one.
	# Deliberately NOT widened to hue_a on an EXISTING marker: view_mode 2 on one
	# of those may be a raw checkpoint (the rebase - see MaskSession's class doc),
	# and quietly un-raw-ing a checkpoint because its color was adjusted would
	# break the layer window it exists to close.
	if created or field == "effect_a" or field == "intensity_a":
		var vm := int(m.get("view_mode", 2.0))
		var eid := int(m.get("effect_a", 0))
		var drawing: bool = eid != MaskSession.EFFECT_RESTORE \
			and eid != MaskSession.EFFECT_CLEAR \
			and float(m.get("intensity_a", 0.0)) > 0.0
		if drawing and (vm == 2 or vm == 3):
			m["view_mode"] = 1.0 if vm == 2 else 0.0
	if field == "effect_a":
		_update_effect_controls(int(value))
	_timeline.selected = _selected
	_refresh_marker_label()
	_mark_dirty()


func _add_marker_at_playhead(kind_id: int) -> void:
	_undo.push("", "added a %s marker" % MaskSession.MARKER_KINDS[kind_id].capitalize())
	_selected = session.add_marker(_player.stream_position if _player != null else 0.0, kind_id)
	_select_generation += 1
	_timeline.selected = _selected
	_refresh_panel()
	_mark_dirty()


func _delete_selected() -> void:
	if _selected != null:
		_undo.push("", "deleted a marker")
		session.remove_marker(_selected)
		_selected = null
		_timeline.selected = null
		_refresh_panel()
		_mark_dirty()


func _select_marker(m: Dictionary) -> void:
	_selected = m
	_select_generation += 1   # a new marker's edits must never coalesce with the last one's
	_timeline.selected = m
	_refresh_panel()


func _refresh_marker_label() -> void:
	if _selected == null:
		_marker_label.text = "nothing selected - editing plants a ramp here"
	else:
		var t := float(_selected.time)
		var kind_name: String = MaskSession.MARKER_KINDS[int(_selected.get("kind", 0.0))]
		_marker_label.text = "%s @ %s  (%d total)" % \
			[kind_name.capitalize(), Clock.text(t), session.markers.size()]
	_refresh_marker_list()


## The sequential ramp/damp list, pinned to the panel's bottom. Rebuilt wholesale -
## cheap at the marker counts a session actually has, and simpler than diffing.
## Piggybacks on _refresh_marker_label's call sites (add/delete/select/drag all
## already call it) rather than needing its own scattered call sites.
func _refresh_marker_list() -> void:
	if _marker_list == null:
		return
	for c in _marker_list.get_children():
		c.queue_free()
	for m in session.markers:
		var kind_name: String = MaskSession.MARKER_KINDS[int(m.get("kind", 0.0))]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var eff_name: String = MaskSession.MASK_EFFECTS[int(m.get("effect_a", 0))]
		var view_tag := "  · raw ⟲" if int(m.get("view_mode", 2.0)) == 2 else ""
		b.text = "%s   %s · %s%s" % [Clock.text(float(m.time)),
			kind_name.capitalize(), eff_name, view_tag]
		if _selected != null and _selected == m:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		b.pressed.connect(func(): _select_marker(m))
		_marker_list.add_child(b)


# --- auto-save, and the reload --------------------------------------------------------------------


func _mark_dirty() -> void:
	_dirty = true
	_autosave_cooldown = _AUTOSAVE_DELAY


func _save_session() -> void:
	if session == null or _session_path.is_empty():
		return
	# Once a restart has committed to quitting, _player's playback is no longer a
	# trustworthy live read - the engine's own shutdown sequence stops it before
	# _exit_tree runs, which reports stream_position back as 0. _restart_now already
	# took the definitive capture right before quitting; exit's own catch-all save
	# (below) must not re-derive playhead from a player that may already be torn
	# down, or it silently overwrites the correct saved value with 0 (this was why
	# a restart always landed back at the start of the timeline).
	if _player != null and not _restarting:
		session.playhead = _player.stream_position   # persist where the playhead is
	if _tview != null:
		session.timeline_zoom = _tview.zoom
		session.timeline_view_start = _tview.view_start
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_session_path.get_base_dir()))
	session.save(ProjectSettings.globalize_path(_session_path))
	_dirty = false


## Reload the app to pick up code the assistant just edited, landing back on THIS
## session at the current playhead (both persisted, see _save_session). Standalone
## Godot can't hot-reload GDScript, so this is a clean restart-and-restore.
##
## But a restart mid-flight would corrupt any OTHER assistant run still writing files,
## so it never fires while runs are in progress: it hands the restart to the Assistant,
## which holds it until every agent has returned, THEN restarts (see Assistant.reload_when_idle).
##
## Same deference applies to an export in progress (_render_state != "idle", see
## _poll_render): quitting to restart kills the render/transcode subprocess it's waiting
## on, losing the render (feedback/0027). Checked first, and re-checked by _poll_render
## once the export finishes, since one can start after this was first requested.
func _reload_requested() -> void:
	if _render_state != "idle":
		_reload_after_export = true
		_set_status("⟳  Reload queued - restarting once the export in progress finishes")
		return
	var a := get_tree().get_first_node_in_group("assistant")
	if a != null and a.has_method("reload_when_idle") and bool(a.call("is_busy")):
		a.call("reload_when_idle", Callable(self, "_do_restart"))
		_set_status("⟳  Reload queued - restarting once assistant runs finish")
	else:
		_do_restart()


## The actual restart: relaunch this same executable straight back into --mask-edit on
## the current session (so it reopens here, at the saved playhead), preserving whatever
## engine args (--path etc.) it was launched with.
func _do_restart() -> void:
	_save_session()   # captures the playhead
	if _reload_check_pid > 0:
		return   # a check is already running - don't stack another
	# NEVER restart into code that doesn't compile: the assistant's edit might have a
	# syntax error, and relaunching into it would leave the app unable to open. Validate
	# headless first (same check as src/scratchpad.py compile); _process reads the
	# result and only then restarts, or reports the errors and stays put.
	if not OS.has_feature("editor"):
		_restart_now()
		return
	var exe := OS.get_executable_path()
	_reload_check_log = ProjectSettings.globalize_path("user://reload_compile_check.log")
	_reload_check_pid = Subprocess.start_logged(exe,
		PackedStringArray(["--headless"]) + Boot.project_args() + PackedStringArray(["--editor", "--quit"]),
		_reload_check_log, "reload check")
	if _reload_check_pid <= 0:
		_set_status("⚠  Couldn't run the pre-reload compile check - NOT reloading (edits left as-is)")
		_reload_check_pid = -1
		return
	_set_status("⟳  Checking the edits compile before reloading…")


## The actual restart, run only once _do_restart's compile check comes back clean:
## relaunch this same executable straight back into --mask-edit on the current session
## (so it reopens here, at the saved playhead), preserving the engine args it had.
func _restart_now() -> void:
	# One last accurate capture right before quitting - the compile check the app just
	# ran can take a while, and the app stays fully interactive while it does, so the
	# playhead _do_restart captured when the check STARTED may already be stale. This
	# is also the last point _player is guaranteed to still report a live position -
	# see _save_session/_exit_tree for why nothing may re-derive it after this.
	_save_session()
	_restarting = true
	var engine_args := PackedStringArray()
	for a in OS.get_cmdline_args():
		if a == "--":
			break                     # everything before the user-args separator
		engine_args.append(a)
	engine_args.append("--")
	engine_args.append("--mask-edit")
	engine_args.append(_session_path)
	OS.set_restart_on_exit(true, engine_args)
	get_tree().quit()


## Poll the pre-reload compile check (see _do_restart). Clean -> restart; errors ->
## block the reload and surface them, so a broken assistant edit never bricks the app.
func _poll_reload_check() -> void:
	if _reload_check_pid <= 0 or Subprocess.alive(_reload_check_pid):
		return
	_reload_check_pid = -1
	var log := FileAccess.get_file_as_string(_reload_check_log) if FileAccess.file_exists(_reload_check_log) else ""
	if not _reload_check_log.is_empty():
		DirAccess.remove_absolute(_reload_check_log)
	var errs := []
	for line in log.split("\n"):
		for marker in ["SCRIPT ERROR", "Parse Error", "Compile Error", "Identifier not found", "Failed to load"]:
			if line.contains(marker):
				errs.append(line.strip_edges())
				break
	if errs.is_empty():
		_restart_now()
	else:
		_set_status("⚠  Reload blocked - the edits don't compile (%d error%s); app left running" % [
			errs.size(), "" if errs.size() == 1 else "s"])
		push_warning("ghost: reload blocked, compile errors:\n" + "\n".join(errs))


# --- playback: the clock, and the main clip's sound and fade --------------------------------------


## WHAT THE SHARED TRANSPORT DRIVES (see Spectrum's `_conductor`, handed over through the shell,
## [method Shell.conduct_transport]; next/roadmap.md, "One transport for
## Masking too"): its ▶ and ■, its rail, Space and the arrows play, pause and seek the clip as they do
## a reading, and the marker strip stays the editor it is, scrubbing the same clock. THE VIDEO IS THE
## MASTER: the position is the player's ([method playhead]), the length the clip's. Stop goes back to
## the in point and waits there, as a file does.
func transport_hooks() -> Dictionary:
	return {
		"play": func() -> void: _play(true),
		"pause": func() -> void: _play(false),
		"stop": func() -> void:
			_play(false)
			_on_scrub(session.clip_in if session != null else 0.0),
		"playing": func() -> bool: return _playing or _autostart_pending,
		"can_play": func() -> bool: return _player != null and session != null and session.duration > 0.0,
		"can_stop": func() -> bool: return _player != null,
		"position": playhead,
		"length": func() -> float: return session.duration if session != null else 0.0,
		"seek": func(t: float) -> void:
			if _player != null and session != null:
				_on_scrub(clampf(t, 0.0, session.duration)),
	}


## Where the master clock is: the main clip's own decode position, seconds.
func playhead() -> float:
	return _player.stream_position if _player != null else 0.0


## THE ROOM UNDER THE TIMELINE: the shared transport's rail runs along the bottom of the window
## ([method Shell.transport_room]), so the marker strip, the lanes and the video stand above it. None
## in a render, which has no transport, nor with no shell.
func bottom_lift() -> float:
	var shell := Shell.of(self)
	return shell.transport_room() if shell != null and not render_mode else 0.0


func _on_scrub(t: float) -> void:
	_player.stream_position = t
	_audio.seek(t)


func _play(on: bool) -> void:
	# HOLD A START THE AUDIO ISN'T READY FOR. _ready_with_session already
	# holds the AUTOstart until the threaded load attaches, but pressing play
	# yourself walked straight past that guard: the video (the master clock)
	# ran on while the stream was still loading, so the opening seconds
	# played silent and the audio joined wherever the video had got to. Same
	# hold, same recovery path - _poll_audio_thread starts playback the frame
	# the stream lands, synced.
	if on and _audio_thread != null and _audio_thread.is_started():
		_autostart_pending = true
		_playing = false
		if _player != null:
			_player.paused = true
		_set_status("⏳  Loading audio…")
		return
	if not on:
		_autostart_pending = false   # an explicit pause cancels a pending hold
	_playing = on
	if not _player.is_playing():
		_player.play()
	if not _audio.playing:
		_audio.play(_player.stream_position)
	_player.paused = not on
	_audio.stream_paused = not on
	_audio_holding = false   # any pending catch-up hold is moot once playback state changes
	# THE VIDEO IS THE MASTER CLOCK. The two players don't pause at the same
	# instant (video stops on a decoded-frame boundary, audio on a mix chunk),
	# so every pause/resume cycle - spacebar, the feedback console's freeze -
	# banked a little offset, and nothing ever corrected it. Snap audio to the
	# video on every resume; _process keeps them corrected from there.
	if on:
		_audio.seek(_player.stream_position)
	# Track audios are driven entirely by MaskTracks.sync (windowed play/seek/pause), so
	# nothing to do for them here.


## Derive the compressed playback sidecar for a session whose prep predates it
## (see _ready_with_session). Fire-and-forget: this run still pays the slow WAV
## load it already started, and every later open of this clip is instant. No
## .part dance - the name is only ever read when it exists AND a session is
## being opened, and a half-written .ogg simply fails to load and falls back.
func _ensure_audio_ogg(abs_wav: String, abs_ogg: String) -> void:
	if FileAccess.file_exists(abs_ogg) or not FileAccess.file_exists(abs_wav):
		return
	Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-loglevel", "error", "-i", abs_wav,
		"-c:a", "libvorbis", "-q:a", "5", abs_ogg]))


## Worker-thread body: the blocking WAV read (see _ready_with_session). Returns the
## stream; the main thread attaches it in _process the frame the thread finishes.
func _load_wav_threaded(path: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(path)


## Attach the threaded main-audio load the frame it's ready, started at the live
## position so it's in sync from its first sample. No-op until the thread finishes.
func _poll_audio_thread() -> void:
	if _audio_thread == null or _audio_thread.is_alive():
		return
	var stream = _audio_thread.wait_to_finish()
	_audio_thread = null
	if stream != null and _audio != null:
		_audio.stream = stream
		_apply_main_volume()
	# The autostart was waiting for exactly this: begin playback now, synced at the
	# current (start) position, so the intro plays with its audio from the first
	# sample instead of skipping. _play(true) seeks the audio to the video's position,
	# so it stays in sync. If the load FAILED (stream null) start anyway - a silent
	# editor beats one frozen forever waiting on audio that will never arrive.
	if _autostart_pending:
		_autostart_pending = false
		if _status != null and not render_mode:
			_status.visible = false
		_play(true)
		return
	if stream != null and _audio != null and _playing:
		_audio.play(_player.stream_position if _player != null else 0.0)
		_audio.stream_paused = false


## The main clip's 0/1 audio toggle -> the AudioStreamPlayer's level. -80 dB reads as
## silence; 0 dB is unity. Per-frame the fade overrides this (see _apply_main_fade);
## this covers the moment the toggle is flipped and the initial attach.
func _apply_main_volume() -> void:
	if _audio != null:
		_audio.volume_db = _track_level_db(session.main_volume, 1.0)


## The clip-fade fraction (0 at a faded edge, 1 across the flat middle) for a position
## `local` seconds into a clip of length `span`, given fade_in / fade_out durations.
func _clip_fade_gain(local: float, span: float, fi: float, fo: float) -> float:
	var g := 1.0
	if fi > 0.001 and local < fi:
		g = clampf(local / fi, 0.0, 1.0)
	if fo > 0.001 and local > span - fo:
		g = minf(g, clampf((span - local) / fo, 0.0, 1.0))
	return clampf(g, 0.0, 1.0)

## Exponential audio taper for the pull-rope knob's raw 0..1 reading: pushes the quiet
## end down hard (a real dead zone near the anchor, not just a shallower version of
## "audible") while leaving the top of the pull comparatively spacious, so fine-tuning
## a loud level doesn't blow past it - feedback/0025: "1% volume should be nearly
## inaudible, but isn't"; "the middle volume growth seems very fast". _TAPER_K controls
## how hard the low end is suppressed; the curve is 0 at v=0 and 1 at v=1 regardless.
const _TAPER_K := 5.0


func _volume_taper(v: float) -> float:
	return (exp(_TAPER_K * v) - 1.0) / (exp(_TAPER_K) - 1.0)


## Audio gain in dB for a clip: the pull-rope volume `v` (0..1), exponentially tapered
## (see _volume_taper), times the fade envelope `g` (0..1) gives the linear gain
## fraction. This used to run through lerpf(-40, 0, l) - a shallow floor that left a
## fade idling around a still-audible -40dB for nearly the whole marker-to-marker span,
## then jumped a discontinuous 40dB to silence in the last fraction of a percent
## (feedback/0024: "barely reduces until the very tail end"). An equal-power curve (the
## standard cinematic/DAW fade shape) into a real dB conversion spreads the perceived
## loudness change smoothly across the whole span instead, with no cliff at the end -
## and its own natural flattening near l=1 gives the fine control near the top of the
## pull that feedback/0025 asked for, on top of the taper above.
func _track_level_db(v: float, g: float) -> float:
	var l := _volume_taper(clampf(v, 0.0, 1.0)) * clampf(g, 0.0, 1.0)
	if l < 0.0005:
		return -80.0
	return clampf(linear_to_db(sin(l * PI * 0.5)), -80.0, 0.0)


## The main clip's own fade, applied every frame: the whole composite (video) dims via
## _composition_parent.modulate and the main audio ramps in dB - the same envelope,
## coupled. _composition_parent.modulate alone only reaches the RAW (unshaded) view
## though - mask_split.gdshader's fragment() samples TEXTURE directly rather than
## starting from the built-in COLOR, so the CanvasItem's modulate never reached the
## shaded fx overlay, and with any fx layer active the picture stayed full-opacity no
## matter what the envelope said (feedback/0022). u_fade is the shader's own copy of
## the same `g`, so the fade holds whether or not fx is on screen. Deterministic off
## the playhead, so live and export match.
func _apply_main_fade() -> void:
	if _player == null:
		return
	var cin := session.clip_in
	var cout := session.effective_clip_out()
	var t := _player.stream_position
	# Past the main clip's own kept range, the composite's alpha follows whichever
	# continuation track (see MaskSession.continuation_track_at) actually owns `t` now -
	# its OWN fade_in/fade_out, not main's - since the picture showing there is that
	# track's own independent frame (see _apply_frame_state/_cont_view). No owning
	# track (a gap, or past all content) holds at full opacity, same as before
	# continuation tracks respected their own fade at all.
	var g := 1.0
	if t < cout:
		g = _clip_fade_gain(t - cin, cout - cin, session.main_fade_in, session.main_fade_out)
	else:
		var cont_idx := session.continuation_track_at(t)
		if cont_idx != -1:
			var tr: Dictionary = session.tracks[cont_idx]
			var offset := float(tr.get("offset", 0.0))
			var span := float(tr.get("clip_out", 0.0)) - float(tr.get("clip_in", 0.0))
			g = _clip_fade_gain(t - offset, span, float(tr.get("fade_in", 0.0)), float(tr.get("fade_out", 0.0)))
	if _composition_parent != null:
		_composition_parent.modulate.a = g
	_mat_main.set_shader_parameter("u_fade", g)
	if _audio != null:
		# Audio cuts off exactly at cout, full stop - unlike the picture (see
		# _apply_frame_state), this is NOT extended by a continuation track's window.
		# A continuation track (MaskTracks._split_main's tail, same video_path) already plays its
		# OWN independent audio via MaskTracks.sync' taudio the moment it's active - gating
		# this on main_visible_at too meant the main clip's audio kept playing right
		# alongside it, doubled with the track's own copy of the same source audio
		# (feedback/0013). Audio ownership passes to the track the moment one exists
		# there - which, after the track's own in-point is re-trimmed independently of
		# cout, can be BEFORE cout (session.track_owns_audio_at) rather than exactly at
		# it. Without this check that brief overlap played main's audio and the track's
		# own copy of the same source at once, right at the handoff (feedback/0014).
		var audible := 0.0 if (t >= cout or session.track_owns_audio_at(t)) else g
		_audio.volume_db = _track_level_db(session.main_volume, audible)


# --- view mode: main (raw/fx) x inset (hidden/raw/fx) ---------------------------------------------
# A per-marker field (MaskSession.VIEW_MODES), not just an editing preference - see
# class doc. There is deliberately no standalone "current mode" variable: the single
# source of truth is always session.at_time(playhead), read fresh every frame in
# _process (live AND render_mode alike) and applied via _apply_frame_state - which
# consumes the CONTINUOUS per-layer amounts, so mode changes fade across their
# marker's window instead of popping.

## The DISPLAY/cycle order - the "evolution": raw, then the inset appears (still
## raw), then the inset gets the effect, then the main screen joins it, then
## full-frame fx alone. VIEW_MODES' own order is append-only storage layout (see
## MaskSession), so the narrative order lives here.
const VIEW_CYCLE := [2, 3, 0, 5, 4, 1]   # raw -> pip_raw -> pip -> fx+raw-pip -> masked_pip -> masked


## The marker GOVERNING time `t` - the same last-wins search at_time() uses
## internally to resolve its `cur`, exposed here so callers that need the
## actual marker OBJECT (not at_time()'s resolved copy) can find it without
## re-deriving the search. Null before the first marker.
func _governing_marker(t: float) -> Variant:
	if session == null:
		return null
	var cur = null
	for m in session.markers:
		if m.time <= t:
			cur = m
	return cur


## The toggle button edits the marker at the playhead exactly like every other panel
## control (see _edit) - cycling is relative to whatever's ACTIVE right now, not to
## some separately-tracked button state, so it can never drift from the timeline.
## That means retargeting _selected to the playhead's own governing marker FIRST:
## _selected may still be pointing at whatever the marker list was last clicked on,
## which never moves the playhead - editing through the stale selection silently
## changes an unrelated marker elsewhere on the timeline and nothing visibly happens.
func _cycle_view_mode() -> void:
	# The cycle is the base looks, then per imported track a pair of stops showing
	# THAT track raw in the PiP: once with a RAW main (pip_raw, 3), once with an FX
	# main (masked_pip_raw, 5) - so you can see the fx composite beside the raw source.
	# Each stop is [view_mode, pip_track]; the list grows/shrinks with the track count.
	var stops := []
	for vm in VIEW_CYCLE:
		stops.append([vm, 0])
	for k in range(1, session.tracks.size() + 1):
		stops.append([3, k])
		stops.append([5, k])
	var cur_vm := 2
	var cur_pt := 0
	if session != null and _player != null:
		var resolved: Dictionary = session.at_time(_player.stream_position)
		cur_vm = int(resolved.get("view_mode", 2.0))
		cur_pt = int(resolved.get("pip_track", 0.0))
	var idx := -1
	for j in stops.size():
		if int(stops[j][0]) == cur_vm and int(stops[j][1]) == cur_pt:
			idx = j
			break
	var nxt: Array = stops[(idx + 1) % stops.size()] if idx >= 0 else stops[0]
	if session != null and _player != null:
		var t: float = _player.stream_position
		_selected = _governing_marker(t)
	_edit("view_mode", float(int(nxt[0])))   # plants/selects a marker if needed; applied next frame
	if _selected != null:
		_selected["pip_track"] = float(int(nxt[1]))
		_mark_dirty()


# --- per-frame: push the timeline's blended params into the shader --------------------------------


func _process(_dt: float) -> void:
	# SEATBELT. _syncing is only valid inside a single synchronous
	# _refresh_panel() call, so finding it still set at the top of a frame means
	# that call aborted midway. Left latched it silently swallows every
	# subsequent edit - the user's settings appear to save and are simply
	# dropped. Clearing it here bounds the damage to one repaint instead of the
	# rest of the session.
	_syncing = false
	match _prep_state:
		"waiting_tools":
			if _have_ffmpeg():
				_prep_state = "idle"
				_source_prep.prep(_pending.source, _pending.dir, _pending.video, _pending.audio)
				return
			Provision.ensure("ffmpeg")   # retries by itself once a failed attempt has cooled off
			var hint := Deps.hint("ffmpeg")
			_set_status(("⏳  " + hint) if not Provision.state("ffmpeg").has("error")
				else "⚠  " + hint)
			return
		"prepping_video":
			if Subprocess.alive(_prep_video_pid):
				_set_status("⏳  Preparing clip (video)…  %d%%" % _source_prep.read_pct())
				return
			_source_prep.promote_part(String(_pending.video))
			_source_prep.start_audio()
			return
		"prepping_audio":
			if Subprocess.alive(_prep_audio_pid):
				return
			_source_prep.promote_part(String(_pending.audio))
			_source_prep.promote_part(String(_pending.audio).get_basename() + ".ogg")
			_source_prep.clear_lock(_pending.dir)
			_prep_state = "idle"
			_source_prep.finish_session(_pending.source, _pending.video, _pending.audio)
			return
		"waiting_external":
			var abs_video := ProjectSettings.globalize_path(_pending.video)
			var abs_audio := ProjectSettings.globalize_path(_pending.audio)
			if FileAccess.file_exists(abs_video) and FileAccess.file_exists(abs_audio):
				_prep_state = "idle"
				_source_prep.finish_session(_pending.source, _pending.video, _pending.audio)
				return
			if _source_prep.looks_live(_pending.dir, _pending.video):
				return   # still going elsewhere - keep waiting
			# Nothing's touched it in a while and it never produced both files - the
			# other writer died mid-prep. Run it ourselves rather than waiting forever.
			_prep_state = "idle"
			_source_prep.prep(_pending.source, _pending.dir, _pending.video, _pending.audio)
			return
		_:
			pass
	if _yt_state == "provisioning":
		_url_import.wait_for_env()
	elif _yt_state != "idle":
		if _yt_pid > 0 and not Subprocess.alive(_yt_pid):
			_yt_pid = -1
			_url_import.step_done()
		else:
			# Live readout every frame, exporter-style: a step with no percent
			# of its own at least ticks its elapsed seconds, so a slow venv
			# bootstrap or pip install never reads as a hang.
			var el := int(Time.get_unix_time_from_system() - _yt_step_started)
			match _yt_state:
				"downloading":
					var pct := _url_import.pct()
					_set_status("⏳  Downloading…  " + (pct if not pct.is_empty()
						else "connecting  %ds" % el))
					# yt-dlp's WARNING/ERROR lines echo into godot's log the
					# moment they appear (deduped) - a throttle warning is only
					# useful WHILE the download crawls, not after it finishes.
					for line in _url_import.tail_window().split("\n"):
						var s := line.strip_edges()
						if (s.begins_with("WARNING") or s.begins_with("ERROR")) \
								and not _yt_echoed.has(s):
							_yt_echoed[s] = true
							print("ghost yt: ", s)
	if _waveform_pid > 0 and not Subprocess.alive(_waveform_pid):
		_waveform_pid = -1
		var abs_wave := ProjectSettings.globalize_path(_waveform_path)
		if FileAccess.file_exists(abs_wave):
			_waveform.load_strip(abs_wave)
	_waveform.poll_hi(_dt)
	if _tracks.import_pid > 0 and not Subprocess.alive(_tracks.import_pid):
		_tracks.import_pid = -1
		_tracks.finish_import()
	_poll_audio_thread()   # cheap bool check; attaches the main audio once its load finishes
	if not _tracks.audio_jobs.is_empty():
		_tracks.poll_audio()
	if _lanes_col != null:
		var visible_lanes := 0
		for c in _lanes_col.get_children():
			if c is Control and (c as Control).visible:
				visible_lanes += 1
		_tracks.reserve_lanes(visible_lanes)
	if _reload_check_pid > 0:
		_poll_reload_check()   # gates the reload on a clean headless compile
	if session == null or _player == null:
		return
	_source_prep.sync_size()   # one-shot; adopts the decoder's own frame size
	# THE EXPORT CLOCK. In render mode the movie is driven by accumulated fixed-fps time
	# (_render_t), NOT the video/audio stream positions - those can drift a little, stall,
	# or (when a source is shorter than the session) end early, and binding the export to
	# them truncated the movie to the shorter stream and let effects/video slide out of
	# alignment. render_pos is where the timeline is at this recorded frame; the decoded
	# video normally free-runs within ~2 frames of it (measured), so it's only re-synced
	# on real divergence, never seeked every frame (which would thrash the OGV decoder).
	var render_pos := _player.stream_position
	if render_mode:
		_render_t += _dt
		render_pos = _render_t   # export runs the whole timeline from 0 (see _build_render_view)
		if _player.is_playing() and absf(_player.stream_position - render_pos) > 0.2:
			_player.stream_position = render_pos
	# Restore the persisted playhead once, now that the player has had a frame to start
	# (a same-frame seek in _ready_with_session is ignored). Retried until it takes or a
	# short budget lapses, then the seek + audio sync catch up from there.
	if _pending_restore >= 0.0:
		var target := clampf(_pending_restore, session.clip_in, session.effective_clip_out())
		_player.stream_position = target
		if _audio != null:
			_audio.seek(target)
		if absf(_player.stream_position - target) < 1.0 or _pending_restore_tries > 20:
			_pending_restore = -1.0
		_pending_restore_tries += 1
	# Same resolve, live or exported: whatever the timeline says at this instant is
	# what's shown - render_mode doesn't special-case a fixed "always masked" look. Live
	# reads the (just-restored) video position; export reads the deterministic movie clock.
	_apply_frame_state(session.at_time(render_pos if render_mode else _player.stream_position))
	_apply_main_fade()   # dim the whole composite + main audio at the clip's fade edges
	# The fx overlay re-draws whichever raw source is actually active this frame -
	# _player while the main clip's own kept range covers it, else _cont_view's
	# texture (a continuation track's own independent decode, see _apply_frame_state) -
	# each only while actually on screen; "raw" mode skips both (and the shader
	# passes they'd otherwise cost) entirely.
	if _fx_overlay != null and _fx_overlay.visible:
		_fx_overlay.texture = _player.get_video_texture() if _player.visible else _cont_view.texture
	if _pip_view != null and _mask_wrap.visible:
		_pip_view.texture = _player.get_video_texture()
	_maybe_capture_echo()
	_maybe_capture_face()
	_tick_umbra()
	# META: while a meta layer is live, capture the editor's own frame for the mirror
	# and (in export) lerp the editor chrome into view. Both are gated on _meta_amount
	# so the expensive readback only ever runs during an actual meta section.
	if _meta_amount > 0.001:
		_capture_workspace()
	if render_mode:
		_apply_meta_chrome(_meta_amount)
	_push_anchor()
	_step_paint_sim()
	_step_umbra_sim()
	# Standing A/V drift correction (see _play: video is the master clock).
	# 0.15s tolerance sits above audio mix-chunk granularity so this never chatters.
	#
	# Video ahead of audio: seek audio forward - a silent skip, no artifact.
	#
	# Audio ahead of video: HOLD audio in place (pause, no seek) until video's decode
	# catches back up. A backward seek would replay audio just heard, audible as an echo.
	# This direction is the common one: _maybe_capture_echo's synchronous GPU readback
	# (whisp/echo/chimera/snow/oracle/serpent) stalls this thread every _ECHO_INTERVAL and
	# freezes _player.stream_position for the stall's duration while _audio keeps flowing on
	# its own thread, so audio runs ahead after every capture and the drift only grows.
	#
	# The hold's exit check runs OUTSIDE the "_audio.playing" gate: setting
	# stream_paused = true immediately flips .playing to false, so gating the exit on
	# .playing would let a hold engage and never release.
	#
	# THE HOLD IS BOUNDED. It assumes the video catches up in a moment, which is true of a
	# readback stall and false of anything that starves the decode for as long as it runs -
	# a heavy background job, a busy machine. Past the limit the audio is seeked back to the
	# video instead: that replays a fraction of a second of sound, which is the artifact
	# this design refuses, and it is still better than indefinite silence.
	#
	# GHOST_AV_DEBUG=1 prints both clocks once a second. One line, every run, once playback
	# has started - four numbers saying immediately whether audio is being held, has run
	# out, or was never started.
	if not _av_reported and _playing and _audio != null and _audio.playing 			and _audio.get_playback_position() > 1.0:
		_av_reported = true
		var mb := AudioServer.get_bus_index(MASK_BUS)
		var ms := AudioServer.get_bus_index("Master")
		print("ghost mask: audio path - stream=%s len=%.1fs vol=%.1fdB bus=%s(%.1fdB mute=%s) "
			% [_audio.stream.get_class() if _audio.stream != null else "<null>",
				_audio.stream.get_length() if _audio.stream != null else 0.0,
				_audio.volume_db, _audio.bus,
				AudioServer.get_bus_volume_db(mb) if mb >= 0 else 99.0,
				str(AudioServer.is_bus_mute(mb)) if mb >= 0 else "?"]
			+ "master=%.1fdB mute=%s peak=%.1fdB device=%s"
			% [AudioServer.get_bus_volume_db(ms) if ms >= 0 else 99.0,
				str(AudioServer.is_bus_mute(ms)) if ms >= 0 else "?",
				AudioServer.get_bus_peak_volume_left_db(ms, 0) if ms >= 0 else 99.0,
				AudioServer.get_output_device()])
	if OS.has_environment("GHOST_AV_DEBUG") and _player != null and _audio != null:
		var now_ms := Time.get_ticks_msec()
		if now_ms - _av_debug_ms > 1000:
			_av_debug_ms = now_ms
			# EVERY GAIN STAGE BETWEEN THE FILE AND THE SPEAKER, in one line. The
			# transport half of this (positions, drift, hold) proved healthy while
			# the author heard nothing, which means the interesting question is not
			# "is it playing" but "at what level, through what" - and that is four
			# separate places any one of which silences the lot.
			var mbus := AudioServer.get_bus_index(MASK_BUS)
			var mst := AudioServer.get_bus_index("Master")
			var slen := 0.0
			var sname := "<null>"
			if _audio.stream != null:
				sname = _audio.stream.get_class()
				slen = _audio.stream.get_length()
			print("AVDBG video=%.2f audio=%.2f drift=%+.3f playing=%s apl=%s paused=%s hold=%s"
				% [_player.stream_position, _audio.get_playback_position(),
					_player.stream_position - _audio.get_playback_position(),
					str(_playing), str(_audio.playing), str(_audio.stream_paused),
					str(_audio_holding)]
				+ "  vol=%.1fdB stream=%s len=%.1f bus=%s(%.1fdB mute=%s) master=%.1fdB mute=%s"
				% [_audio.volume_db, sname, slen, _audio.bus,
					AudioServer.get_bus_volume_db(mbus) if mbus >= 0 else 99.0,
					str(AudioServer.is_bus_mute(mbus)) if mbus >= 0 else "?",
					AudioServer.get_bus_volume_db(mst) if mst >= 0 else 99.0,
					str(AudioServer.is_bus_mute(mst)) if mst >= 0 else "?"]
				+ "  peak=%.1fdB out=%s"
				% [AudioServer.get_bus_peak_volume_left_db(mst, 0) if mst >= 0 else 99.0,
					AudioServer.get_output_device()])
	if _playing and _audio_holding:
		var hold_drift := _player.stream_position - _audio.get_playback_position()
		if hold_drift >= -0.02:
			_audio.stream_paused = false
			_audio_holding = false
		elif Time.get_ticks_msec() - _audio_hold_ms > _AUDIO_HOLD_LIMIT_MS:
			_audio.stream_paused = false
			_audio_holding = false
			_audio.seek(_player.stream_position)
	elif _playing and _audio.playing and not _audio.stream_paused:
		var av_drift := _player.stream_position - _audio.get_playback_position()
		if av_drift > 0.15:
			_audio.seek(_player.stream_position)
		elif av_drift < -0.15:
			_audio.stream_paused = true
			_audio_holding = true
			_audio_hold_ms = Time.get_ticks_msec()
	_tracks.sync()
	# A trimmed clip's OUT point is a hard wall for playback (both live preview
	# and the export relaunch - export additionally needs a QUIT, not just a
	# pause, since Movie Maker keeps recording for as long as the process runs).
	# clip_in is not enforced here on purpose: scrubbing earlier to look at
	# trimmed-away footage while editing is fine, only PLAYBACK (and export) are
	# bounded to the kept range. Bounded by content_end(), not clip_out directly -
	# MaskTracks._split_main trims clip_out but appends the trimmed tail as a track at that
	# same offset, so the show must keep running (the master clock IS the main
	# clip's own decode position) until that track's own span is done too.
	var content_stop := session.content_end()
	if render_mode:
		# The export ends on the MOVIE clock reaching the session's own content length -
		# never on a source stream ending. Binding it to the streams truncated the movie
		# to whichever of the audio/video was shorter than the session (the 13:37 -> 13:00
		# report) and, since a stalled/ended source froze the position the effects keyed
		# off, slid the whole show out of alignment. Past a source's own end the timeline
		# simply shows raw for that region, but the movie still runs its full length with
		# the full audio. content_end() already folds in clip_out + any continuation track;
		# the export runs [0, content_end()] - the whole timeline, matching the editor.
		if _render_t >= content_stop - 0.001:
			get_tree().quit()
			return
	elif content_stop < session.duration and _player.stream_position >= content_stop and _playing:
		_play(false)
	if render_mode:
		return
	# Cross a marker during playback and it selects itself - the panel and timeline
	# follow the playhead, so scrubbing through a whole session no longer means
	# clicking every tiny flag by hand. Only while actually playing; a paused scrub
	# or a deliberate click in the marker list is left alone.
	# ...unless the author has switched Follow off, which is what makes tuning a
	# marker's knobs DURING playback possible at all: with it on, crossing the next
	# marker takes the panel away mid-adjustment.
	if _playing and _follow_playhead != null and _follow_playhead.button_pressed:
		var governing: Variant = _governing_marker(_player.stream_position)
		if governing != null and governing != _selected:
			_select_marker(governing)
	# Auto-hide the cursor once it's been still for a beat during playback -
	# _input() above resets the timer and un-hides on any motion, and pausing
	# (or a mouse click, which also fires motion-adjacent hover) restores it
	# immediately rather than leaving an editor with a phantom-hidden pointer.
	# ... and NEVER while a popup is up. A color picker or a dropdown is an
	# embedded SUBWINDOW: mouse motion inside it never reaches this node's
	# _input(), so the idle timer keeps running, the auto-hide fires, and the
	# pointer vanishes inside the one place it most needs to be visible - with
	# no way to un-hide it, because moving the mouse is exactly what stopped
	# being heard. Suspending the timer here also un-hides on the way in, via
	# the elif.
	if _playing and _modal_depth <= 0:
		_cursor_idle_t += _dt
		if _cursor_idle_t >= _CURSOR_HIDE_DELAY and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _time_label != null:
		_time_label.text = "%s / %s" % [
			Clock.text(_player.stream_position), Clock.text(session.duration)]
	# Auto-save: any edit marks the session dirty (see _mark_dirty); it lands on
	# disk shortly after the LAST change in a burst - a slider drag saves once,
	# not once per pixel of mouse travel.
	if _dirty:
		_autosave_cooldown -= _dt
		if _autosave_cooldown <= 0.0:
			_save_session()
	_export.poll()


## Pushes one resolved timeline state (see MaskSession.at_time) into the layers:
## channel params to both materials, each layer's intensities scaled by its own
## PRESENCE amount - so "how present is this layer" is a continuous, blendable
## quantity and a mode transition is a fade, not a toggle. The inset's border
## fades with it (modulate), and fully-absent layers are hidden entirely so they
## cost nothing.
func _apply_frame_state(p: Dictionary) -> void:
	var main_amt := clampf(float(p.get("main_fx", 0.0)), 0.0, 1.0)
	var inset_show := clampf(float(p.get("inset_show", 0.0)), 0.0, 1.0)
	var inset_fx := clampf(float(p.get("inset_fx", 0.0)), 0.0, 1.0)
	if _peek_raw:
		main_amt = 0.0
		inset_show = 0.0
		inset_fx = 0.0
	_last_inset_show = inset_show
	# Which source fills the PiP this frame. Fall back to the main clip if the stored
	# index points past the current track count (e.g. a track was deleted).
	var pt := int(p.get("pip_track", 0.0))
	_pip_track = 0 if (_peek_raw or pt < 0 or pt > session.tracks.size()) else pt
	var t: float = _player.stream_position if _player != null else 0.0
	var env := _waveform.env_at(t)
	var layers: Array = p.get("layers", [])
	# Does a chimera layer actually render this frame? _maybe_capture_echo reads this
	# to decide whether the (expensive) track readback is worth doing right now.
	# _temporal_active is the same idea one level up: gates the echo/whisp capture
	# itself on whatever's actually on screen, not on the session's marker list.
	_chimera_active = false
	_audio_layer = {}
	_temporal_active = false
	_clown_active = false
	_umbra_active = false
	_meta_amount = 0.0
	for l in layers:
		var le := int(l.get("effect_a", 0))
		if le == MaskSession.EFFECT_CHIMERA:
			_chimera_active = true
		if le == MaskSession.EFFECT_UMBRA:
			_umbra_active = true
			_umb_read_layer(l, env)
		if le == MaskSession.EFFECT_CLOWN:
			_clown_active = true
			_clown_fs = clampf(float(l.get("fx_scale", 1.0)), 0.3, 2.5)
			_clown_bleed = clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0)
			_clown_settle = clampf(float(l.get("fx_lag", 0.35)), 0.0, 1.0)
			_clown_hollow = clampf(float(l.get("fx_stick", 0.0)), 0.0, 1.0)
			# Four keying/pattern fields clown never keys or patterns with, read
			# here under their clown names. See the vars' own doc for the mappings.
			_clown_evidence = clampf(float(l.get("resonance", 0.0)), 0.0, 1.0)
			# Ranges chosen so the STORED DEFAULTS land on "exactly the measured
			# face": eye 1.0x, no drip, smile at the real mouth's width, no sweep.
			# 1.2x the eye at the bottom of the slider, 2.2x at the stored default,
			# 5.2x wound up. It used to be 1.0 + t*6 - 1.44, which is NEGATIVE below
			# threshold 0.24 - a negative scale turns the hull inside out - and only
			# 1.0x at the default, i.e. a patch exactly the size of the eye opening.
			_clown_eye_size = 1.2 + clampf(float(l.get("threshold", 0.24)), 0.0, 1.0) * 4.0
			_clown_drip = clampf(float(l.get("sat_floor", 0.18)), 0.0, 1.0) - 0.18
			# Both of these sit on fields that default to 0, so 0 has to be a GOOD
			# value rather than "off" - a lean streak with a gentle bow is what a
			# tear of liner looks like, and the sliders take it heavier and wider
			# from there.
			# Its floor is a SOFT edge, not the polygon: a hard-edged oval is the
			# fault this control exists for, so 0 must not be it. The floor is also
			# what rounds the outline off - the patch is a 16-vertex hull pushed
			# outward along its own normals, and at any real Eye size its facets are
			# plainly visible until something averages over them.
			_clown_smudge = 0.45 + clampf(float(l.get("swap", 0.0)), 0.0, 1.0) * 0.55
			_clown_drip_w = 0.35 + clampf(float(l.get("fx_y", 0.0)), 0.0, 1.0) * 0.80
			_clown_drip_curve = 0.45 + clampf(float(l.get("intensity_b", 0.0)),
				0.0, 1.0) * 1.55
			_clown_smile_w = 1.0 + (clampf(float(l.get("feather", 0.12)), 0.0, 0.5) - 0.12) * 8.0
			_clown_smile_curve = (clampf(float(l.get("fx_speed", 1.0)), 0.0, 2.0) - 1.0) * 0.12
			# fx_x defaults to 0, and 0 must be a GOOD value: some feather is
			# always wanted, so the range runs from soft to softer.
			_clown_feather = 0.012 + clampf(float(l.get("fx_x", 0.0)), 0.0, 1.0) * 0.055
			_ft_sigma = MaskFaceTrack.sigma_for(float(l.get("hue_b", 0.0)))
			_clown_region = Vector4(
				float(l.get("reg_x0", 0.0)), float(l.get("reg_y0", 0.0)),
				float(l.get("reg_x1", 1.0)), float(l.get("reg_y1", 1.0)))
		if le == 5 or le == 7 or le == MaskSession.EFFECT_SNOW or le == MaskSession.EFFECT_ORACLE \
				or le == MaskSession.EFFECT_SERPENT or le == MaskSession.EFFECT_CHIMERA \
				or le == MaskSession.EFFECT_CLOWN:
			_temporal_active = true
		# The META mirror's strength - the same env x intensity the shader gets as
		# this layer's weight. Drives whether the (expensive) workspace readback runs
		# at all this frame, and how far the render-mode editor chrome has revealed.
		if le == MaskSession.EFFECT_AUDIO:
			_audio_layer = l
		if le == MaskSession.EFFECT_META:
			_meta_amount = maxf(_meta_amount,
				clampf(float(l.get("env", 0.0)) * float(l.get("intensity_a", 0.0)), 0.0, 1.0))
	# The audio layer resolves to bus parameters rather than pixels. Applied every
	# frame like everything else, so its envelope ramps the sound in exactly as a
	# visual layer's ramps its paint - and so an export, which walks the same
	# per-frame path, mixes the same sound the editor previewed.
	_audio_fx.ensure_bus()
	_audio_fx.apply(_audio_layer)
	# Build the layer arrays ONCE; only the weights differ per surface (each
	# material multiplies its own presence in). Arrays are pushed at FULL declared
	# length - a short uniform array is silently dropped (flame.gdshader lesson).
	var n: int = mini(layers.size(), MaskSession.MAX_LAYERS)
	var hues := PackedFloat32Array()
	var effects := PackedInt32Array()
	var base_w := PackedFloat32Array()
	var offs := PackedVector2Array()
	var scales := PackedFloat32Array()
	var densities := PackedFloat32Array()
	var contrasts := PackedFloat32Array()
	var glows := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var smooths := PackedFloat32Array()   # raw fx_smooth - snow's Gust; echo bakes its own use into echo_w below
	var tdirs := PackedVector3Array()
	var echo_w := PackedFloat32Array()
	var echo_lag := PackedInt32Array()
	var lagf := PackedFloat32Array()   # raw fx_lag - fur's Coil knob (echo's use is baked into echo_w/echo_lag)
	var sticks := PackedFloat32Array()   # raw fx_stick - fur's Stickiness (0 = today's free coat)
	var tints := PackedFloat32Array()    # fx_tint - Morph, palette hue rotation (0 = natural)
	var accents := PackedFloat32Array()  # hue_b - umbra's ghost-eye color (0 = red)
	var regions := PackedVector4Array()  # the layer's box in frame UV (x0,y0,x1,y1)
	var regsofts := PackedFloat32Array() # how gradually it fades out at that border
	var slot_frac := fposmod((_player.stream_position if _player != null else 0.0) / _ECHO_INTERVAL, 1.0)
	for i in MaskSession.MAX_LAYERS:
		if i < n:
			var l: Dictionary = layers[i]
			var res := float(l.get("resonance", 0.0))
			hues.append(float(l.get("hue_a", 0.0)))
			effects.append(int(l.get("effect_a", 0)))
			base_w.append(float(l.get("env", 0.0)) * float(l.get("intensity_a", 0.0)))
			offs.append(Vector2(float(l.get("fx_x", 0.0)), float(l.get("fx_y", 0.0))))
			scales.append(float(l.get("fx_scale", 1.0)))
			# Resonance folds in CPU-side: the audio envelope swings coverage around
			# its nominal (loud opens the field, quiet closes it) and pulses the rim.
			densities.append(clampf(float(l.get("fx_density", 0.45)) + 0.5 * res * (env - 0.35), 0.0, 1.0))
			contrasts.append(float(l.get("fx_contrast", 0.5)))
			glows.append(1.0 + res * env * 1.3)
			speeds.append(maxf(0.05, float(l.get("fx_speed", 1.0))))
			smooths.append(clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0))
			# The echo's temporal kernel: weights over the 8 ring ages, centered
			# on the layer's lag. Age of ring index k is (k + slot_frac) slots -
			# continuous in playback time, so a spread kernel (Smoothing > 0)
			# glides through the ring with no steps; Smoothing ~ 0 collapses to
			# the nearest single frame - the held-frame stutter, now at an
			# adjustable distance. Pure function of position + fields: live and
			# export blend identically.
			var lag_slots := clampf(float(l.get("fx_lag", 0.35)) / _ECHO_INTERVAL, 0.0, 7.0)
			var smooth_amt := clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0)
			echo_lag.append(clampi(int(round(lag_slots)), 0, 7))
			lagf.append(float(l.get("fx_lag", 0.35)))
			sticks.append(clampf(float(l.get("fx_stick", 0.0)), 0.0, 1.0))
			tints.append(clampf(float(l.get("fx_tint", 0.0)), 0.0, 1.0))
			accents.append(clampf(float(l.get("hue_b", 0.0)), 0.0, 1.0))
			var w := PackedFloat32Array()
			var wsum := 0.0
			for k in 8:
				var wv: float
				if smooth_amt < 0.02:
					wv = 1.0 if k == clampi(int(round(lag_slots - slot_frac)), 0, 7) else 0.0
				else:
					wv = exp(-absf(float(k) + slot_frac - lag_slots) / (smooth_amt * 2.5))
				w.append(wv)
				wsum += wv
			for k in 8:
				echo_w.append(w[k] / maxf(wsum, 0.0001))
			# The target hue's normalized chroma direction, for erase's
			# projection-subtraction (see the shader: erase is subtraction,
			# not classification - no gates, no boundary rings).
			var tc := Color.from_hsv(float(l.get("hue_a", 0.0)), 1.0, 1.0)
			var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
			tdirs.append(Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized())
			# The layer's region box, normalized here so the shader never has to
			# wonder which corner is which (a box dragged past itself is still a
			# box). Sessions saved before regions existed have none of these
			# fields; the DEFAULTS fall back to the whole frame, which is exactly
			# what they rendered before.
			# SNAPPED HERE, not only when dragged. A drag snaps an edge that lands
			# near the frame's border onto it (see _snap_edge), but a value stored
			# before that existed - or set any other way - keeps whatever it has,
			# and an edge sitting 0.002 off the top is a four-pixel band of exactly
			# the color the layer was added to remove, hugging the top of the
			# picture. Snapping at the point of USE means every session gets the
			# same treatment, and the shader can then skip that side's falloff
			# entirely because the edge is genuinely flush.
			regions.append(Vector4(
				MaskRegion.snap_edge(minf(float(l.get("reg_x0", 0.0)), float(l.get("reg_x1", 1.0)))),
				MaskRegion.snap_edge(minf(float(l.get("reg_y0", 0.0)), float(l.get("reg_y1", 1.0)))),
				MaskRegion.snap_edge(maxf(float(l.get("reg_x0", 0.0)), float(l.get("reg_x1", 1.0)))),
				MaskRegion.snap_edge(maxf(float(l.get("reg_y0", 0.0)), float(l.get("reg_y1", 1.0))))))
			regsofts.append(clampf(float(l.get("reg_soft", 0.0)), 0.0, 1.0))
		else:
			hues.append(0.0)
			effects.append(0)
			base_w.append(0.0)
			offs.append(Vector2.ZERO)
			scales.append(1.0)
			densities.append(0.0)
			contrasts.append(0.5)
			speeds.append(1.0)
			smooths.append(0.0)
			echo_lag.append(0)
			lagf.append(0.0)
			sticks.append(0.0)
			tints.append(0.0)
			accents.append(0.0)
			for k in 8:
				echo_w.append(1.0 if k == 0 else 0.0)
			glows.append(1.0)
			tdirs.append(Vector3(1, 0, 0))
			regions.append(Vector4(0.0, 0.0, 1.0, 1.0))   # unused slot: whole frame
			regsofts.append(0.0)
	# Which source actually has valid picture at `t`: the main clip's own kept range,
	# or - once that's ended - whichever continuation track (see
	# MaskSession.continuation_track_at) has picked it up. Each continuation track
	# renders through its OWN player (see MaskTracks.sync), never by borrowing _player's -
	# see continuation_track_at's doc for why that used to be a fragile invariant.
	var main_active := t < session.effective_clip_out()
	var cont_idx := -1 if main_active else session.continuation_track_at(t)
	var cont_tex: Texture2D = null
	if cont_idx != -1 and cont_idx < _tracks.runtime.size() and _tracks.runtime[cont_idx].has("player"):
		var cp: VideoStreamPlayer = _tracks.runtime[cont_idx].player
		if cp != null and cp.get_video_texture() != null and cp.get_video_texture().get_height() > 0:
			cont_tex = cp.get_video_texture()
	_cont_view.visible = cont_tex != null
	if cont_tex != null:
		_cont_view.texture = cont_tex
	for pair in [[_mat_main, main_amt], [_mat_inset, inset_fx]]:
		var mat: ShaderMaterial = pair[0]
		var amt: float = pair[1]
		mat.set_shader_parameter("u_threshold", p.threshold)
		mat.set_shader_parameter("u_feather", p.feather)
		mat.set_shader_parameter("u_sat_floor", p.sat_floor)
		# The wisp field's clock is the CLIP's own playback position, never
		# wall-time - live and export step the same clock, so a session
		# reproduces its exact wisps frame-for-frame (flame.gdshader discipline).
		mat.set_shader_parameter("u_time", t)
		var tex := (_player.get_video_texture() if _player != null else null) if main_active else cont_tex
		if tex != null and tex.get_height() > 0:
			mat.set_shader_parameter("u_aspect", float(tex.get_width()) / float(tex.get_height()))
			# The ACTIVE source's own pixel grid - a continuation track may be a
			# different size from the main clip, so this tracks `tex`, not _src_size.
			mat.set_shader_parameter("u_texel",
				Vector2(1.0 / float(tex.get_width()), 1.0 / float(tex.get_height())))
		var ws := PackedFloat32Array()
		for i in MaskSession.MAX_LAYERS:
			ws.append(base_w[i] * amt)
		mat.set_shader_parameter("u_l_count", n)
		mat.set_shader_parameter("u_l_hue", hues)
		mat.set_shader_parameter("u_l_effect", effects)
		mat.set_shader_parameter("u_l_w", ws)
		mat.set_shader_parameter("u_l_off", offs)
		mat.set_shader_parameter("u_l_scale", scales)
		mat.set_shader_parameter("u_l_dens", densities)
		mat.set_shader_parameter("u_l_con", contrasts)
		mat.set_shader_parameter("u_l_glow", glows)
		mat.set_shader_parameter("u_l_speed", speeds)
		mat.set_shader_parameter("u_l_smooth", smooths)
		mat.set_shader_parameter("u_l_ew", echo_w)
		mat.set_shader_parameter("u_l_elag", echo_lag)
		mat.set_shader_parameter("u_l_lagf", lagf)
		mat.set_shader_parameter("u_l_stick", sticks)
		mat.set_shader_parameter("u_l_tint", tints)
		mat.set_shader_parameter("u_l_accent", accents)
		mat.set_shader_parameter("u_l_tdir", tdirs)
		mat.set_shader_parameter("u_l_region", regions)
		mat.set_shader_parameter("u_l_regsoft", regsofts)
		# Chimera's graft source: the first track's live frame. The explicit
		# flag matters - the sampler's default-black fallback must never read
		# as footage.
		var track_tex: Texture2D = null
		if _tracks.runtime.size() > 0 and _tracks.runtime[0].has("player"):
			var tp: VideoStreamPlayer = _tracks.runtime[0].player
			if tp != null and tp.get_video_texture() != null \
					and tp.get_video_texture().get_height() > 0:
				track_tex = tp.get_video_texture()
		mat.set_shader_parameter("u_track_on", 1 if track_tex != null else 0)
		if track_tex != null:
			mat.set_shader_parameter("u_track", track_tex)
	# The active source's own raw frame - and everything sourced from it (the fx
	# overlay, its own PiP inset) - only while the timeline actually claims this
	# instant (feedback/0009: past the main track's own trim, with no track
	# continuing it here, video.ogv kept rendering anyway).
	_player.visible = main_active
	_fx_overlay.visible = main_amt > 0.001 and (main_active or cont_tex != null)
	# Main clip's PiP only when it's the selected source; MaskTracks.sync re-confirms.
	_mask_wrap.visible = inset_show > 0.001 and _pip_track == 0 and main_active
	_mask_wrap.modulate.a = inset_show
	if _view_label != null:
		if _pip_track > 0:
			var main_lbl := "fx" if main_amt > 0.5 else "raw"
			_view_label.text = "🎞  main %s · Track %d (raw)" % [main_lbl, _pip_track]
		else:
			match MaskSession.VIEW_MODES[clampi(int(p.get("view_mode", 2.0)), 0, MaskSession.VIEW_MODES.size() - 1)]:
				"raw":            _view_label.text = "🎬  Raw"
				"pip_raw":        _view_label.text = "🖼  PiP (raw)"
				"pip":            _view_label.text = "🖼  PiP (fx)"
				"masked_pip_raw": _view_label.text = "🎭  Full (fx) · PiP (raw)"
				"masked_pip":     _view_label.text = "🎭  Both (fx)"
				"masked":         _view_label.text = "🎭  Full (fx)"

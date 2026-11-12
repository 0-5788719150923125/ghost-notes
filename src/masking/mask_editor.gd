extends CanvasLayer
class_name MaskEditor

## MaskEditor - the mask-mode authoring surface: load a clip, key colors apart (per-pixel hue classification, see
## shaders/mask_split.gdshader), place markers where the split or effect changes, scrub the timeline, export. See
## src/masking/mask_session.gd for the data model: markers are fixed-schema scalar vectors, each a RAMP (eases in
## before its anchor) or a DAMP (accumulates after it).
##
## Standalone: a mask session is tied to one external clip, so it does not route through the Director, and the clip
## plays through its own players (the video is the master clock). Only the shared transport's verbs leave it, handed to
## the shell ([method Shell.conduct_transport]): the editor conducts it ([method transport_hooks]), so play, stop, the
## rail, Space and the arrows are the same as in every mode, and its timeline stands above the rail
## ([method bottom_lift]). Two entry points (see main.gd):
##   --mask-edit [path]    interactive editor
##   --mask-render <json>  the export relaunch's render mode ([member render_mode] = true; no panel, autoplay, quits
##                         when the audio ends - mirrors --export/_export_mode).
##
## The timeline is a bespoke Control ([MaskTimeline]); the export button, status and FileDialog follow exporter.gd; color
## entry is Godot's ColorPickerButton.
##
## View modes (MaskSession.VIEW_MODES + _build_video_composition) are the main screen and the inset as independent axes,
## cycled by one button (VIEW_CYCLE). Only one video decodes ([member _player], always raw); the fx layers re-draw its
## texture through [const SHADER], each only while visible, so "raw" costs no shader pass.
##
## view_mode is a per-marker field, not an editing preference: the toggle edits the marker at the playhead like every
## panel control (see _edit), the preview renders what session.at_time() resolves to, and the export relaunch
## (render_mode) runs the same per-frame logic, so the rendered file matches what is seen.
##
## The region is universal, not an entry in EFFECT_CONTROLS: each marker carries a box in frame UV (reg_x0/y0/x1/y1 +
## reg_soft) that multiplies into its layer's on-screen weight, resolved per pixel; the default is the whole frame. It
## separates what a color key cannot (a yellow wall from a gold coin). The box is dragged on the video (see
## _build_region_overlay).
##
## Any frame shape: the clip's pixel size is read once ([member _src_size]) and decides the picture's geometry. The
## editor fits the frame inside its video area (bars left and right for portrait), patterns stay isotropic through the
## shader's `u_aspect`, and the export records at the source's resolution. Nothing assumes 16:9; see _src_size and
## _write_render_override.

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

## Set when a reload was requested while an export was mid-flight (_render_state != "idle"), see _reload_requested.
## _poll_render re-fires the request once the export finishes: a restart quits this process, and Godot kills the child
## processes it created (see assistant.gd's _closing doc), including the render/transcode subprocess.
var _reload_after_export := false

## Set when _restart_now commits to quitting (after its final _save_session capture); see _save_session and _exit_tree.
var _restarting := false

# One material per layer: the main overlay and the inset can be mid-transition at different presences, and a layer's
# presence multiplies into its own intensities, which one shared material cannot do.
var _mat_main := ShaderMaterial.new()
var _mat_inset := ShaderMaterial.new()
var _playing := false
var _audio_holding := false   # main audio paused-in-place, waiting for video to catch up (see _process)
var _av_debug_ms := 0         # GHOST_AV_DEBUG throttle
var _av_reported := false     # the once-per-run audio path summary has been printed
var _audio_hold_ms := 0       # when that hold engaged - it is not allowed to last forever

## The longest the audio may be held waiting for the video: a readback stall is tens of milliseconds, anything past
## this is a machine not keeping up.
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

# The clown face model (see _update_face_model): eyes / mouth / oval / tint, fitted per capture tick and EMA-glided like
# the anchor. Defaults describe a plausible centered face so the paint shows before the first fit.
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

# Per-feature sizes, measured from each cluster's own spread in plain screen units (uv), not eye-distance units:
# normalizing by the pair would couple every feature's size to the pair's jitter. Each feature breathes on its own.
var _face_eye_lr_prev := 0.035
var _face_eye_lr_ema := 0.035
var _face_eye_rr_prev := 0.035
var _face_eye_rr_ema := 0.035
var _face_mouth_r_prev := Vector2(0.05, 0.028)
var _face_mouth_r_ema := Vector2(0.05, 0.028)

# The face centroid (the coat channel's home and the cracks' local pull) and the nose's own slow anchor, smoothed on its
# own clock so it does not inherit the pair's frame jitter.
var _face_c_prev := Vector2(0.5, 0.45)
var _face_c_ema := Vector2(0.5, 0.45)
var _face_nose_prev := Vector2(0.5, 0.52)
var _face_nose_ema := Vector2(0.5, 0.52)

# The face model's own capture cadence: faster than the echo ring's 0.35s (8 slots x 0.35s of history, unchanged) so the
# mask chases the face in near real time. A tick coinciding with an echo capture reuses its image.
const _FACE_INTERVAL := 0.15
var _face_slot := -1

## The face tracker's environment key (see [Provision]).
const FACE_ENV := "face_venv"
var _ft_state := "none"   # none | provisioning | tracking | ready | failed
var _ft_pid := -1
## The aspect the face model's hand-tuned bounds were calibrated at. Radii are stored in raw uv (the shaders' contract),
## but a bound on a width is applied in height units through this constant, so 16:9 footage is unchanged and other
## shapes get the same physical bound.
const _FACE_ASP_REF := 1.7778

## What counts as the face's core, as a fraction of the peak weight: the mass the size fit may see (the weight field is
## broad, and letting the broad part set the size pushed the eye pair off the face).
const _FACE_CORE := 0.35

## Known loose end: this fit's bound (0.30 x _FACE_ASP_REF) is nearly twice as wide as the cap the paint sim draws the
## coat with (clown_paint.gdshader's FACE_CAP_XHI), and rx also sets how far the eye search ranges, so where the key
## hue is in the background too the band can reach past the face. Tightening it to the coat's cap collapsed the
## detected eye pair on 16:9 footage (separation 0.164 -> 0.072): the vertical model needs retuning as a whole.
var _face_prev_lum := PackedFloat32Array()   # 96x54 luminance, for the mouth's motion cue
var _face_motion_mean := 0.0                 # EMA of the face's ambient per-pixel motion
var _face_red_ema := 0.02                    # mean (r-g) over the face - the lips' baseline
var _face_bg_lum := 0.2                      # this frame's whole-frame mean luminance (the
                                             #   brightness cue's floor - see _update_face_model)

# The liquid paint simulation (see shaders/clown_paint.gdshader and _step_paint_sim): a ping-pong SubViewport pair
# holding the persistent, advected paint field the mask shader samples as u_clown_paint. Built lazily on the first
# clown frame; stepped on playback-time deltas.
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

## The clown's four tuning knobs, resolved per frame from the live layer (see _apply_frame_state). Each is a view onto a
## field the keying/pattern groups own for other effects (the idiom umbra's six follow), and each default reproduces
## the constant it replaced.
var _clown_evidence := 0.0   # resonance  - drawn-shape floor vs the picture's own evidence

## The shape knobs, on the three fields Steady/Firm/Lead used to hold. The landmark track is fitted offline, so there is
## nothing to smooth or predict; the fields now carry the shape of the drawn features. (The fallback fitter keeps the
## old constants internally.)
var _clown_eye_size := 1.0     # threshold - how far the eye patch grows past the eye
var _clown_drip := 0.0         # sat_floor - how far the black runs down the cheek

## The run's weight and bow (Drip says how far the liner runs). Width scales the source width the shader measures off
## the eye patch, so it stays a fraction of this eye at any Eye size; curve scales how far the run bows outboard across
## the cheekbone. Both defaults are their field's default.
## How far the eye paint is rubbed past its own contour (`swap`, see MaskSession's LAYER_FIELDS).
var _clown_smudge := 0.45      # swap        - the eye edge, rubbed rather than cut
var _clown_drip_w := 0.35      # fx_y        - the run's width, x the measured lash line
var _clown_drip_curve := 0.25  # intensity_b - how far it bows out across the cheek
var _clown_smile_w := 1.0      # feather   - the smile's width, past the real mouth
var _clown_smile_curve := 0.0  # fx_speed  - its corners swept up (-) or down (+)

## How far the coat's outer edge fades out, in frame UV. On fx_x: Pan is hidden for the clown (it could only slide a
## face-tracked mask off the face), so the field is free.
var _clown_feather := 0.012

## How wide the centered kernel that smooths the landmark track is, in samples (see _ft_point). Centered, so it costs
## no lag at any width; a wider one only rounds off genuinely fast motion. On hue_b.
var _ft_sigma := 2.5

## The clown layer's region box, mirrored CPU-side so the face search honors it too (see _face_region_at).
var _clown_region := Vector4(0.0, 0.0, 1.0, 1.0)

## The live audio layer (see _apply_audio_fx); empty when no audio marker governs.
var _audio_layer := {}
var _clown_bleed := 0.0    # its Bleed / Settle / Hollow knobs, fed to the paint sim
var _clown_settle := 0.35
var _clown_hollow := 0.0

## The landmark indices this effect uses, by name: MediaPipe's pose order is not guessable.
const PT_NOSE := 0
const PT_EYE_L := 2
const PT_EYE_R := 5
const PT_EAR_L := 7
const PT_EAR_R := 8
const PT_SH_L := 11
const PT_SH_R := 12

## The bootstrap's state, about the environment and its models, not any one window: none | provisioning | ready |
## failed. "ready" means the tracker can be run. The pose model is `full` rather than `heavy`: on the reference footage
## `full` found a pose in 7451 of 7451 sampled frames (see the face_venv row in deps.gd).
var _pt_state := "none"
var _pt_pid := -1          # unused by the bootstrap now; kept in the reap list

## The cast direction, accumulated over every window loaded this session, weighted by each one's own confidence: one
## window measures it poorly and a dozen well, and a window that measured nothing contributes nothing.
var _pt_dir := Vector2(1.0, 0.0)

## The silhouette handed to the field sim: one image + texture rewritten in place per sample (this runs every frame an
## umbra layer is live).
var _pt_slot := -1
var _pt_guard_slot := -1
var _pt_tex: ImageTexture = null
var _umbra_active := false

# The cast transform, solved per frame from the pose sample at `t + Lead` and handed to the field sim as its inverse: a
# similarity pinned by two point pairs (the subject's shoulder line to the ghost's, eye line to eye line), so the
# ghost's head lands where it was placed at any size.
var _umb_inv0 := Vector2(1.0, 0.0)   # inverse basis, column 0 (aspect-corrected space)
var _umb_inv1 := Vector2(0.0, 1.0)   # ...column 1
var _umb_anchor := Vector2(0.5, 0.5) # where her shoulder line lands, aspect-corrected
var _umb_src := Vector2(0.5, 0.5)    # her own shoulder line, aspect-corrected
var _umb_eye_src := Vector2(0.5, 0.3)# her own eye line, aspect-corrected (the bust's center)
var _umb_unit := 0.3                 # her eye-to-shoulder distance - the unit for everything
var _umb_bust0 := 1.2                # bust falloff, in her own units, from her eye line
var _umb_bust1 := 2.6

# The cast direction, measured over the whole clip by the pose pre-pass (the part of the background that moves with the
# subject). Furniture, not a per-frame measurement.
var _umb_dir := Vector2(1.0, 0.0)
var _umb_pan := Vector2.ZERO
var _umb_stand := 1.05   # Stand  (threshold)   - how far to the side the ghost stands
var _umb_lead := 0.19    # Lead   (feather)     - seconds the ghost moves AHEAD of her
var _umb_lean := 0.45    # Lean   (swap)        - how far it leans along the throw, and rises
var _umb_narrow := 0.35  # Narrow (intensity_b) - how much taller-than-wide it is drawn

# The ghost's eyes: the subject's eye landmarks pushed through the cast transform.
var _umb_eye_l := Vector2(0.5, 0.4)
var _umb_eye_r := Vector2(0.6, 0.4)
var _umb_eye_rad := 0.05
var _umb_eyes_ok := false
var _umb_eye_amt := 0.0   # Gaze (sat_floor) - how strongly the eyes read
var _umb_have := false

# The umbra field simulation (ping-pong SubViewport pair, as the clown's paint sim): stepped on playback deltas so pause
# freezes it and export traces the same currents.
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

## repaint's replacement color: a whole color, not a hue (it writes hue_b/fx_stick/fx_tint as h/s/v), so black and
## white are reachable.
var _color_paint: ColorPickerButton
var _paint_reach: HSlider           # repaint's Reach - fx_contrast
var _paint_smooth: HSlider          # repaint's Smoothing - fx_smooth

## The region box: a CheckBox that turns it on for the selected marker, a slider for its border softness, and the
## draggable box over the video pane.
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

## Whether playback drags the selection along with the playhead (the "Follow" switch beside the marker list's header);
## on by default.
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

# Temporal capture (echo ring + whisp anchor): quarter-res snapshots of past frames, taken every _ECHO_INTERVAL seconds
# of playback time (slot = position / interval, so live preview and export capture at the same clip positions). Runs
# only while a whisp/echo/snow/oracle/serpent/chimera layer is on screen this frame (_temporal_active, set with
# _chimera_active in _apply_frame_state): the synchronous GPU readback would otherwise stutter unrelated stretches.
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

# The whisp anchor is double-buffered: _anchor_ema is the EMA at the latest capture, _anchor_prev the one before. The
# uniform pushed per frame lerps between them by position within the slot (see _push_anchor); pushing the EMA directly
# stepped the pattern once per capture. Position-keyed, so live and export trace the same glide.
var _anchor_prev := Vector2(0.5, 0.5)
var _anchor_ema := Vector2(0.5, 0.5)

# Chimera's landmark frame (position + size), double-buffered and glided like the centroid above: the main face's
# modeled size (RMS radius of its key/motion mass) and the imported track face's centroid + size, each an EMA. The
# shader maps every main pixel through the two frames so the graft phase-locks to the main head (see the chimera
# branch in mask_split.gdshader). Defaults degrade to a centered clone when a face can't be modeled.
var _anchor_scale_prev := 0.28
var _anchor_scale_ema := 0.28
var _track_anchor_prev := Vector2(0.5, 0.5)
var _track_anchor_ema := Vector2(0.5, 0.5)
var _track_scale_prev := 0.28
var _track_scale_ema := 0.28
var _track_prev_lum := PackedFloat32Array()   # track frame's previous-luminance grid (motion fallback)
const _ECHO_INTERVAL := 0.35

# Wave impulses (whisp only): a fast head turn shows as a luminance jolt in the 48x27 grid _update_whisp_anchor
# samples; an onset detector (motion vs an adaptive EMA baseline + deviation) fires an impulse at the anchor's position,
# and the shader drops a decaying blob of paint there that drifts along whisp's local current (see u_wave_* / wave_wash
# in mask_split.gdshader). WAVE_SLOTS must match WAVEN in the shader.
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

# Auto-save: every edit marks the session dirty; it saves shortly after the last change in a burst (and on close).
var _dirty := false
var _syncing := false   # true while _refresh_panel repaints controls - _edit must ignore echoes
var _modal_depth := 0   # open popups (color pickers, dropdowns) - suspends the cursor auto-hide
var _autosave_cooldown := 0.0
const _AUTOSAVE_DELAY := 0.4

# Undo/redo (see [MaskUndo]): whole-array snapshots of session.markers, with a human-readable description per entry so
# the panel can preview what Ctrl+Z would revert (see _push_undo/_refresh_history_label). A drag folds into one entry:
# the boundary is the mouse button, not a clock (a timed window fragments a paused drag and merges separate edits).
## The undo key the current mouse-held interaction opened, or "" when the button is up (see _push_undo).
var _undo_press_key := ""
var _select_generation := 0   # bumped on every selection change; folded into the coalesce key
const YT_ENV := "ytdlp_venv"

## The bus the clip's sound runs through, with the timeline's effects on it ([MaskAudioFx]).
const MASK_BUS := "MaskFX"
const FT_NOSE_BRIDGE := 168
var _stencil_vp: SubViewport


# The editor's parts: each is a script of its own that holds its own state, reads the rest through `editor.`, and is
# asked a few things by name (next/structure.md, "One file, one job").

## The pose track is a part of its own ([MaskPoseTrack]): bootstrapped, run a window at a time, read by time.
var _pose := MaskPoseTrack.new()

## A link where a file is expected is a part of its own ([MaskUrlImport]): downloaded, polled, handed back to
## [method open_source].
var _url_import := MaskUrlImport.new()

## The face track is a part of its own ([MaskFaceTrack]): fitted once, read by time, rasterized into the stencil the
## clown's shader keys on.
var _face := MaskFaceTrack.new()

## The audio effect is a part of its own ([MaskAudioFx]): the bus, and the timeline applied to it.
var _audio_fx := MaskAudioFx.new()

## Undo and redo are a part of their own ([MaskUndo]): the two stacks of snapshots.
var _undo := MaskUndo.new()

## The clip's preparation is a part of its own ([MaskPrep]): transcoded once, guarded against a second writer, measured.
var _source_prep := MaskPrep.new()

## The waveform is a part of its own ([MaskWaveform]): the timeline's strip, crisp under zoom, and the sound's envelope.
var _waveform := MaskWaveform.new()

## The region box is a part of its own ([MaskRegion]): drawn on, and dragged over, the video.
var _region := MaskRegion.new()

## The export is a part of its own ([MaskExport]): a Movie Maker relaunch at the clip's own size, then the mux.
var _export := MaskExport.new()


## The tracks are a part of their own ([MaskTracks]): the trim lanes, a clip imported onto the timeline, and every
## track kept on the master's time.
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
		# A killed render leaves its override.cfg, and the next launch would boot into the render's resolution. Safe to
		# remove while a render runs: Godot reads it once, at that process's startup.
		_export.clear_override()
		_build_status_label()   # built up front - prep needs it before a session exists
		_warn_missing_tools()


func _exit_tree() -> void:
	var shell := Shell.of(self)
	if shell != null:
		shell.release_transport(self)
	# Hand the shared export button back on the way out (see _build_export_ui).
	var ch_out := _export.chrome()
	if ch_out != null:
		# Keyed, so this drops only Masking's own claims (see the ordering note on Chrome._bottom_claims).
		ch_out.release_export(&"mask")
		ch_out.release_bottom(&"mask")
	# The ⤓ lives in Chrome's row, which outlives this editor: freed with it, not left behind.
	if _export_btn != null and is_instance_valid(_export_btn) and _export_btn.get_parent() != self:
		_export_btn.queue_free()
	_save_session()
	# Reap every subprocess this instance spawned: a detached child keeps running (a prep ffmpeg still touching
	# video.ogv), and the next launch reads the fresh mtime as "already in progress elsewhere". Killing our own pids is
	# safe (the ECHILD hazard is polling pids we did not spawn, see _prep_looks_live's doc). Half-written outputs are
	# handled: prep re-runs when the lock goes stale, _finish_session rejects truncated video, yt-dlp resumes its .part.
	# Every spawn goes through [Subprocess], so `Boot` reaps anything missing here and the kernel kills the lot if
	# ghost is killed; this list makes them die when Masking closes, which frees video.ogv for the next session.
	for pid in [_prep_video_pid, _prep_audio_pid, _tracks.import_pid, _waveform_pid,
			_wavehi_pid, _yt_pid, _reload_check_pid, _render_pid, _transcode_pid,
			_ft_pid, _pt_pid]:
		Subprocess.stop(int(pid))
	Provision.release(FACE_ENV, "mask editor")
	Provision.release(YT_ENV, "clip download")
	for job in _tracks.audio_jobs:
		Subprocess.stop(int(job.get("pid", -1)))
	# Join the audio loader if it is still running, or Godot warns about an orphaned thread on close.
	if _audio_thread != null and _audio_thread.is_started():
		_audio_thread.wait_to_finish()
		_audio_thread = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Whatever the debounce hasn't flushed lands on disk when the editor goes away. Always saved (not only when dirty) so
## the playhead is captured after a pure play/scrub.
## Why Masking cannot be left right now, "" when it can (see main.leave_blocker): its export renders in programs this
## editor owns, and leaving reaps them. A clip still being prepared is no reason: preparation resumes on the next open.
func leave_blocker() -> String:
	if _render_pid > 0 or _transcode_pid > 0:
		return "Masking is exporting - leaving now would stop the export. Wait for it to finish."
	return ""


## The keyboard map (mirrored by the help overlay - keep the two in sync): Space play/pause and ←/→/Home seek (the
## shared transport's) · V cycle view · P hold-to-peek · T import track · Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y undo/redo ·
## F1 help · Esc close help. Live only once a clip is loaded (_player exists); main.gd defers Space entirely while this
## editor is open (see its KEY_SPACE handling). Echo is excluded on undo/redo so a held key does not repeat. Plain
## _input, not _unhandled_input: GUI controls can eat mouse motion before it reaches _unhandled_input, and hovering a
## panel while playing should still un-hide the cursor.
func _input(event: InputEvent) -> void:
	# The drag boundary closes here, on the release itself (see _push_undo): _process returns early in several states
	# (clip preparing, audio transcoding, render mode), so closing it there could leave it open across a release and
	# fold the next adjustment into the previous step. _input runs whatever _process is doing, before any control.
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_undo_press_key = ""
	if render_mode:
		return
	# Space, the arrows and Home are the shared transport's ([method transport_hooks]): it takes them before the GUI,
	# wherever the focus is. A region drag in flight is tracked here, not in the overlay's gui_input, so it survives
	# the cursor leaving the video pane - see _region_drag_motion.
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
	# Hold-to-peek wants the release too (everything below wants presses only): letting go puts the effects back.
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
		# Only claim Escape while help is open: otherwise it stays main.gd's quit key.
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


## Masking cannot work without ffmpeg: every clip is transcoded on import, every waveform and thumbnail is an ffmpeg
## pass, and ffprobe answers the frame count. ghost downloads FFmpeg itself, so on a first run it may still be on its
## way: say so at the door, and a clip opened meanwhile waits for it (see "waiting_tools" in _process).
func _warn_missing_tools() -> void:
	if _have_ffmpeg():
		return
	Provision.ensure("ffmpeg")
	_set_status("⏳  " + Deps.hint("ffmpeg"))


func _have_ffmpeg() -> bool:
	return Deps.has("ffmpeg") and Deps.has("ffprobe")


## `path` is a prepared session .json, a raw source video (transcoded once and cached under masks/<slug>/), or empty
## (the panel asks for one, see _build_source_panel). A file opened here is the note's clip from then on
## ([method _note_clip]).
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
	# Check for a live prep before trusting anything cached: a file that exists may be mid-write (see _finish_session
	# for the matching duration>0 validation on the fast paths below).
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
	# In-window, never native: the portal dialog shows nothing on a Linux box without xdg-desktop-portal.
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


## A note's clip comes off again: the Clip card's × on [param panel] takes the `clip:` block out of the note and opens
## it as what is left ([method NoteCards.detach]), its words as a plain note. The session Masking keeps for the clip is
## left as it is. Not while an export is under way, and not from the command line (no note).
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


## A note with no clip yet (a Clip just attached): the panel, with a Clip card asking for one - a video file or a link
## to download. What is chosen is written into the note's `clip:` block once it is a file on disk, so the note opens
## on it from then on.
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


## A link pasted into the source panel: downloaded, then opened. A non-URL turns the field red.
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
	# Before any layout is built: the video slot and the export's recorded resolution are shaped by this (see _src_size).
	_source_prep.resolve_size()
	# No .material here: the fx layers carry the shader (see _build_video_composition). The layer combination is a
	# per-marker field applied every frame in _process, identically in the live editor and the render_mode relaunch.

	_audio = AudioStreamPlayer.new()
	# Through the effects bus from the start: it is neutral until an audio marker says otherwise, and re-routing a
	# playing stream clicks.
	_audio_fx.ensure_bus()
	_audio.bus = MASK_BUS
	add_child(_audio)
	# The main audio is a big uncompressed WAV (~170MB, ~3s to read). Live: load it on a worker and attach it when
	# ready (_process polls the thread), so the video and UI come up at once and audio joins synced. Export
	# (render_mode) loads synchronously: it needs audio from frame 0, deterministically. AudioStreamWAV's static loader
	# is the runtime-safe path (plain load() has no loader for a raw .wav outside the import pipeline).
	var abs_audio := ProjectSettings.globalize_path(session.audio_path)
	# The compressed sidecar is the fast path: audio.wav is raw PCM (~10 MB/minute, seconds to read however threaded),
	# while Vorbis decodes lazily, so a ~30 MB .ogg attaches at once. Prep writes both (see _start_prep_audio);
	# older sessions derive theirs once in the background. The WAV stays: ffmpeg reads it for the waveform strip and
	# the resonance envelope.
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
		# The resonance envelope must exist before the first recorded frame or the export disagrees with the live preview.
		# Nearly always cached; if not, block briefly on ffmpeg (an export is a batch job).
		_waveform_path = session.audio_path.get_base_dir().path_join("waveform_sqrt.png")
		var abs_wave := ProjectSettings.globalize_path(_waveform_path)
		if not FileAccess.file_exists(abs_wave):
			Deps.execute("ffmpeg", _waveform.args_for(abs_wave))
		_waveform.load_strip(abs_wave)
	else:
		_build_editor_ui()
		_waveform.ensure()
	# Export loaded its audio synchronously, so it starts immediately. Live loads on a worker: starting now would advance
	# the video (the master clock) while the audio is unattached, and the audio would join late. So hold the autostart,
	# showing frame 1 paused, and let _poll_audio_thread begin playback when the audio is ready, synced from 0.
	if render_mode or _audio_thread == null or not _audio_thread.is_started():
		_play(true)
	else:
		_play(false)   # decode + show the first frame, but hold the clock at the start
		# Only then hold the start for the audio: an explicit pause cancels a held start ([method _play]), and one made
		# first would cancel it.
		_autostart_pending = true
	# The shared transport drives the clip from here on ([method transport_hooks]), through the shell.
	var shell := Shell.of(self)
	if not render_mode and shell != null:
		shell.conduct_transport(self, transport_hooks())
	# Land back where the playhead was (persisted per session), live only; an export starts at 0. Deferred to the first
	# _process tick: a VideoStreamPlayer won't accept a seek the frame it starts playing.
	if not render_mode and session.playhead > 0.05:
		_pending_restore = session.playhead
	# Select whatever governs the playhead so the panel opens showing the session's real settings (with nothing
	# selected, _refresh_panel falls back to MaskSession.DEFAULTS, and re-picking a color would write a near-identical
	# new hue).
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
	# Product-demo chrome: if this session uses META anywhere, build the real editor chrome (timeline, lanes, panel) on
	# the clean composition, transparent; _apply_meta_chrome fades it in per frame with the meta envelope. Additive:
	# with no meta markers nothing is built. mouse_filter IGNORE: never interactive.
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
	# The export starts at the timeline start (0), like the live editor: main_visible_at() never gates on clip_in, so
	# markers can sit before clip_in. clip_in still bounds the restore clamp and the kept-range end via content_end().
	_player.play()
	_player.stream_position = 0.0
	_apply_frame_state(session.at_time(0.0))
	# The export quits on the deterministic movie clock reaching content_end() (see _process), not on the audio
	# finishing: an audio track shorter than the session would cut the movie short.


func _build_editor_ui() -> void:
	_video_area = AspectRatioContainer.new()
	_video_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_area.offset_left = VIDEO_LEFT
	# The clip's own shape, not 16:9: a portrait clip gets a tall slot with bars left and right. AspectRatioContainer
	# centers its child in what is left after VIDEO_LEFT and the lane strip (see MaskTracks.reserve_lanes), so the
	# picture fits whole, unstretched. _sync_source_size re-fits this once the decoder confirms the size.
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


## Where the interactive chrome (timeline, lanes, panel) parents: `self` live; in a render-mode export that uses META,
## the fading _meta_chrome overlay, so a meta section reveals the real editor over the clean video.
func _chrome_host() -> Node:
	return _chrome_parent if _chrome_parent != null else self


## The editor chrome (marker timeline, trim/track lane stack, control panel) built into _chrome_host(), split out of
## _build_editor_ui so the export path builds the same widgets into an overlay (see _build_render_view /
## _apply_meta_chrome). Prereqs: session and _player exist.
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

	# The trim/track lane stack sits above the marker strip, sharing its ruler via the same _tview (see
	# MaskTracks.refresh_lanes for why its height is set explicitly).
	_lanes_col = VBoxContainer.new()
	_lanes_col.add_theme_constant_override("separation", 2)
	_lanes_col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lanes_col.offset_left = VIDEO_LEFT
	_chrome_host().add_child(_lanes_col)
	_tracks.refresh_lanes()

	_build_panel()
	# Every popup joins the modal counter that suspends the cursor auto-hide (see _guard_popups), walked from the whole
	# tree so the toolbar's dropdowns are covered.
	_guard_popups(self)


## The shell's backtick feedback console ([method Shell.attach_feedback]: one console and one Assistant in the app),
## with mask-specific plumbing: the descriptor snapshots what is needed to debug a masking complaint (playhead, the
## resolved layer stack, every marker, keying globals, audio envelope), freeze pauses playback while typing, and
## advance is a no-op. With no shell in the tree (a gate building the editor by hand) there is no console.
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


## Everything about "this frame looks wrong": where we are, what the timeline resolved to (each live layer's parameters
## and envelope), the raw marker list, and the session's file identity. The console's screenshot carries the frame.
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


## Wire every popup under `n` into the modal counter, once, at build time. Walks rather than naming them, so a control
## added later is covered.
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
	# Show it at once: the click that opens a picker is the gesture that needs to keep aiming.
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_modal_close() -> void:
	_modal_depth = maxi(0, _modal_depth - 1)
	_cursor_idle_t = 0.0




# --- the composition: the video's layers, and the meta mirror -------------------------------------


## Stacked layers in `parent`'s full rect, shared by the live editor and the render_mode export so they composite
## identically:
##   _player      raw video, underneath everything while the main clip's kept range covers the current time
##   _cont_view   raw video in the same slot, visible instead of _player while a continuation track (see
##                MaskSession.continuation_track_at) owns the time; never both
##   _fx_overlay  full-frame shaded copy of whichever is active (own material) - the main fx layer
##   _mask_wrap   the bordered inset holding _pip_view (own material)
## Which layers show, and how strongly, comes from the per-frame AMOUNTS (MaskSession.mode_amounts, blended through
## ramp/damp windows by at_time), applied in _apply_frame_state. Each layer has its own material because a layer's
## presence multiplies into its intensities: the inset can hold full fx while the main overlay is still fading in.
func _build_video_composition(parent: Control) -> void:
	_composition_parent = parent   # secondary tracks' PiP views land here too - see MaskTracks.build_view
	parent.add_child(_player)
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Same slot and z-position as _player: only one of the two is visible at once (see _process), so _fx_overlay's
	# shaded copy has exactly one raw picture beneath it.
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
	# The inset's placement is fixed (bottom-right box); only its presence animates.
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


## The META mirror source: the editor's own previous frame, read back from the main viewport into u_workspace. A
## full-window GPU->CPU readback, so _process runs it only while a meta layer is on screen. Feeding the window back
## into the video surface inside it is the infinite mirror; the one-frame delay nests each frame one level deeper.
## Downscaled before upload since the mirror draws small.
func _capture_workspace() -> void:
	# Headless has no framebuffer to read back (the dummy renderer's viewport texture is null) and never records a movie;
	# the windowed Movie Maker export is a real GPU context.
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


## In the live editor the mirror's nesting comes free: the video pane is smaller than the captured window (see
## _video_area's VIDEO_LEFT inset + letterbox in _build_editor_ui), so sampling the capture back onto it shrinks it,
## and the capture already contained the previous shrink. _build_render_view's surface is edge to edge (the export is
## clean full-bleed outside a meta section), where a same-size feedback quad only ghosts and blurs. This reproduces the
## live inset by hand: blit a downscaled copy of the capture into the VIDEO_LEFT/letterbox sub-rect over an unshrunk
## copy (so chrome painted at its real position, e.g. by _apply_meta_chrome, still reads at full size).
func _shrink_into_video_pane(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	# VIDEO_LEFT is a fraction of the live editor's window (the base 1920-wide canvas), applied to the capture's width.
	# The pane fits the clip's aspect, as _video_area does.
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


## Render-mode only: fade the editor-chrome overlay in with the meta envelope.
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
		# Finer than the echo ring: an eye socket is a few texels wide at 256x144.
		vp.size = Vector2i(384, 216)
		vp.disable_3d = true
		# Float buffers: the field decays multiplicatively, and 8-bit quantization makes low values stick.
		vp.use_hdr_2d = true
		# The coat lives in the alpha channel, and a non-transparent viewport forces alpha to 1 on its target, so the coat
		# would read as everywhere. This is state, not a picture: keep every channel intact.
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


## One simulation step per rendered frame while a clown layer is live: the ping viewport re-renders sampling the
## pong's texture, then the mask materials sample the ping. Stepped on playback deltas (pause freezes the liquid); a
## seek or the first frame snaps the field to the targets.
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
		# The frame itself: the deposits read their evidence from it (dark socket, red lip line, lit nose ridge).
		mat.set_shader_parameter("u_frame", vt)
	mat.set_shader_parameter("u_face_lum", _face_lum_ema)
	mat.set_shader_parameter("u_face_red", _face_red_ema)
	mat.set_shader_parameter("u_evidence", _clown_evidence)
	# The contour stencil, and whether there is one, kept explicit: a default-black sampler and an empty face read
	# identically, and the empty one must fall back to the ellipses.
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


## Umbra's field simulation host: the clown's ping-pong pair, with transparent_bg because the guard lives in the alpha
## channel (a non-transparent viewport forces alpha to 1) and CLEAR_MODE_NEVER because the field is the state.
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


## One simulation step per rendered frame while an umbra layer is live. Stepped on playback deltas (pause freezes the
## mass; the export traces the same currents); a seek snaps the field to its targets.
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


## The umbra's per-frame tick. No readback (unlike _maybe_capture_face): the shape comes from the cached track, so
## nothing behaves differently while scrubbing than during playback.
func _tick_umbra() -> void:
	if not _umbra_active or _player == null or session == null:
		return
	_pose.ensure()
	if _pt_state != "ready":
		_umb_have = false
		return
	_umb_solve_cast()


# --- umbra: throwing her shadow -------------------------------------------------------------------
# UMBRA: the ghost that moves the subject (see _umb_solve_cast and shaders/umbra_field.gdshader).
#
# The subject's silhouette thrown as a cast shadow larger than they are, standing beside them, reading the clip ahead
# of the playhead so it turns its head first. The shape comes from the pose track (_pt_*): MediaPipe's person
# segmentation plus 33 body landmarks, fitted offline over the whole clip. A person mask needs no conditions on the
# room, and gives the ghost a skeleton, so its head and eyes are placed rather than guessed.


## The one place the umbra's knobs are read off a layer (`tests/masking/umbra_look_probe.gd` calls it rather than
## keeping a copy, so a probe renders the real mappings).
func _umb_read_layer(l: Dictionary, env: float) -> void:
	# Scale is a real size relative to the subject: at 1.0 the ghost is their own size and stands beside them; past
	# that it looms. Its head cannot leave the frame at any setting (see _umb_solve_cast).
	_umb_scale = clampf(float(l.get("fx_scale", 1.0)), 0.4, 3.2)
	_umb_pan = Vector2(float(l.get("fx_x", 0.0)), float(l.get("fx_y", 0.0))) * 0.25
	# Resonance folds in as it does for the shader's density array: the loom breathes with the audio.
	var ures := float(l.get("resonance", 0.0))
	_umb_loom = clampf(float(l.get("fx_density", 0.45)) + 0.5 * ures * (env - 0.35), 0.0, 1.0)
	_umb_roil = clampf(float(l.get("fx_contrast", 0.5)), 0.0, 1.0)
	_umb_rise = maxf(0.05, float(l.get("fx_speed", 1.0)))
	_umb_wisp = clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0)
	_umb_cling = clampf(float(l.get("fx_lag", 0.35)), 0.0, 1.0)
	# Umbra-only views onto fields other effects own (umbra never keys; `swap`/`intensity_b` are the two fields the
	# two-channel era left, which the clown reads under its own names). Stand's low end reaches behind the subject
	# (0.15): the mass is only masked at render, so overlapping is free and it emerges at their edges.
	_umb_stand = 0.15 + clampf(float(l.get("threshold", 0.24)), 0.0, 1.0) * 1.85
	_umb_lead = clampf(float(l.get("feather", 0.12)), 0.0, 0.5) * 1.6
	_umb_eye_amt = clampf(float(l.get("sat_floor", 0.18)), 0.0, 1.0)
	_umb_lean = clampf(float(l.get("swap", 0.45)), 0.0, 1.0)
	_umb_narrow = clampf(float(l.get("intensity_b", 0.35)), 0.0, 0.75)


## The cast transform, solved for the current playhead. Everything is in aspect-corrected space (x times the frame
## aspect), since every quantity is a distance between two points on a body and raw UV is not a unit.
##
##  The anchor is the eye line, not the head's centroid: the eyes are what a viewer looks at, so they must land where
##  placed.
##
##  The ghost's head clears the subject's. The separation is the two skulls' half-widths added, not a tuned constant,
##  so it holds on a close-up and a wide shot. Standing the ghost on top of the subject would make the guard eat it
##  (the silhouette is most of a close-up frame).
##
##  It stands on the side there is room for: the measured throw picks the side, and if the head does not fit there the
##  other side is used (a head against the frame edge is half a head).
##
##  The size is free and the shape is a bust: the silhouette is ~45% of a close-up frame, and drawn whole at Scale 2.8
##  it covered 63% of the frame and read as a dimmed room. The mass is the head and shoulders, a radial falloff about
##  the eye line in the subject's own units (so it rides the transform), dissolving below into the field's smoke.
func _umb_solve_cast() -> void:
	_umb_have = false
	_umb_eyes_ok = false
	if _player == null or _pt_state != "ready":
		return
	# The look-ahead, the reason the track is offline: reading the clip at `t + Lead` turns the ghost's head on a frame
	# the subject has not reached. A velocity extrapolation can only continue what just happened (mostly detection noise).
	var t := _player.stream_position + clampf(_umb_lead, 0.0, 2.0)
	var i := _pose.slot_at(t)
	if i < 0:
		return
	if not _umb_cast_from(i, _source_prep.source_aspect()):
		return
	# The guard's own sample: the subject now, not the frame the ghost is drawn from.
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


## The geometry, split from the playhead so it can be asserted without a clip, player or renderer
## (tests/masking/umbra_cast_check.gd). Reads the live knob state, writes every _umb_* transform field, and returns
## false when this sample cannot support a throw.
func _umb_cast_from(i: int, asp: float) -> bool:
	# The four landmarks the throw is built from must be seen: a shoulder placed by inference still returns a plausible
	# point. The ears are excluded: one is hidden whenever a head turns, and half_w falls back on its own floor.
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
	# The throw is biased upward: a shadow thrown level reads as a stain on the wall, and the effect is a presence that
	# rises. This is the only place the measured direction is editorialized.
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
	# How far it rises is a fraction of the headroom there is, not a multiple of the subject's height (which pins against
	# the top clamp on any close-up, so a whole sweep of Lean gave identical eye heights). The ceiling is where the
	# ghost's sockets still fit, not its skull: a crown taller than a close-up's headroom is allowed to leave the top.
	var ceil_y := clampf(ghost_hw * 0.34 / asp * 2.5 + 0.03, 0.04, 0.6)
	var gy := lerpf(eye.y, minf(ceil_y, eye.y), 0.25 + 0.75 * lean)
	var head := Vector2(gx, gy) + Vector2(_umb_pan.x * asp, _umb_pan.y)
	# Its body axis leans toward the throw half as far: a head that leans on a spine that does not reads as a head on a post.
	var gaxis := (axis * (1.0 - lean * 0.5) + throw * (lean * 0.5)).normalized()
	var anchor := head - gaxis * (unit * scale)
	# The similarity as a 2x2: the subject's frame (axis, its perpendicular) into the ghost's, with the across-axis
	# component scaled by Narrow. Basis into basis, not an angle: the inverse of an orthonormal 2x2 is its transpose.
	var h1 := axis
	var h2 := Vector2(-axis.y, axis.x)
	var e1 := gaxis * scale
	var e2 := Vector2(-gaxis.y, gaxis.x) * (scale * (1.0 - narrow))
	# fwd = [e1 e2] * [h1 h2]^-1, and [h1 h2] is orthonormal, so its inverse is its transpose, where a transposed pair of
	# columns hides (the wrong one is still a rotation). Column k of fwd is e1*h1[k] + e2*h2[k]; fwd*h1 must equal e1
	# exactly, which tests/masking/umbra_cast_check.gd asserts.
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
	# The bust's extent, in the subject's units from the eye line. Loom opens it from a head and collar to head, shoulders
	# and chest.
	var loom := clampf(_umb_loom, 0.0, 1.0)
	_umb_bust0 = 0.70 + 2.00 * loom
	_umb_bust1 = 1.60 + 3.40 * loom
	_umb_dir = throw
	# The eyes go through the same map, so they are on the ghost's head at every Scale.
	_umb_eye_l = anchor + Vector2(
		f0.x * (eye_l.x - sh.x) + f1.x * (eye_l.y - sh.y),
		f0.y * (eye_l.x - sh.x) + f1.y * (eye_l.y - sh.y))
	_umb_eye_r = anchor + Vector2(
		f0.x * (eye_r.x - sh.x) + f1.x * (eye_r.y - sh.y),
		f0.y * (eye_r.x - sh.x) + f1.y * (eye_r.y - sh.y))
	# Back to plain UV for the shader, which samples in screen space.
	_umb_eye_l.x /= asp
	_umb_eye_r.x /= asp
	# Sized from the ghost's own skull, not the fitted separation (which degrades when a head turns away).
	_umb_eye_rad = clampf(ghost_hw * 0.34 / asp, 0.006, 0.09)
	_umb_eyes_ok = true
	return true


# --- the capture ticks: the echo, the face model, the anchors, the wave impulses ------------------


## Temporal capture: when the playhead crosses into a new _ECHO_INTERVAL slot, snapshot the current frame (quarter-res)
## into the ring and push the ring to both materials in age order (u_echo0 = newest). Frames where no
## whisp/echo/snow/oracle/serpent/chimera layer is on screen (_temporal_active) skip all of it.
func _maybe_capture_echo() -> void:
	if _player == null or session == null:
		return
	var pos := _player.stream_position
	# The readback below (tex.get_image()) is a synchronous GPU->CPU stall, paid only during playback, or once when a
	# scrub has settled (playhead stationary since last frame), so dragging stays responsive. render_mode auto-plays, so
	# export captures every slot deterministically.
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
	# The face model runs on its own higher-res copy before _update_whisp_anchor resizes img down to 48x27; claiming the
	# face slot here means _maybe_capture_face never pays a second readback on the same frame.
	if _clown_active:
		_face_slot = int(pos / _FACE_INTERVAL)
		# The blob fitter still runs for the face's color statistics (mean tint, luminance, redness), which landmarks
		# cannot supply. Its geometry is then overwritten by the track; with no track it stands as the fallback.
		_update_face_model(img)
		if _ft_state == "ready" and _face.has_track(pos):
			_face.apply_model(pos)
	_update_whisp_anchor(img)
	# The track readback is chimera's alone: skipped unless a chimera layer renders this frame.
	if _chimera_active:
		_update_track_frame()


## The face model's own capture ticks, between echo captures (see _FACE_INTERVAL's doc). Only during playback (or once
## when a scrub settles): the readback is a synchronous GPU stall, at ~7Hz while a clown layer is live.
func _maybe_capture_face() -> void:
	if not _clown_active or _player == null or session == null:
		return
	# The track wins when it exists. It is read every frame (an array lookup), which also removes the last of the
	# stepping.
	_face.ensure()
	if _ft_state == "ready":
		if _face.has_track(_player.stream_position):
			_face.apply_model(_player.stream_position)
			_face.update_stencil(_player.stream_position)
		# No detection at this instant (a turn away, a hand across the face): hold the last model.
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


## The anchor uniform, glided per frame: lerp(prev EMA, latest EMA) by the playhead's fraction through the current
## capture slot. A pure function of playback position and capture history, so live and export agree.
func _push_anchor() -> void:
	var f := clampf(fposmod(_player.stream_position, _ECHO_INTERVAL) / _ECHO_INTERVAL, 0.0, 1.0)
	var anchor := _anchor_prev.lerp(_anchor_ema, f)
	# Chimera's landmark frames (position + size, both faces), glided on the same fraction.
	var anchor_scale := lerpf(_anchor_scale_prev, _anchor_scale_ema, f)
	var track_anchor := _track_anchor_prev.lerp(_track_anchor_ema, f)
	var track_scale := lerpf(_track_scale_prev, _track_scale_ema, f)
	for mat in [_mat_main, _mat_inset]:
		mat.set_shader_parameter("u_anchor", anchor)
		mat.set_shader_parameter("u_anchor_scale", anchor_scale)
		mat.set_shader_parameter("u_track_anchor", track_anchor)
		mat.set_shader_parameter("u_track_scale", track_scale)
		# Only push once impulses exist: Godot silently drops a short array (see the u_l_* comment above).
		if _wave_amp.size() == _WAVE_SLOTS:
			mat.set_shader_parameter("u_wave_pos", _wave_pos)
			mat.set_shader_parameter("u_wave_time", _wave_time)
			mat.set_shader_parameter("u_wave_amp", _wave_amp)
		# The clown face model predicts instead of gliding: lerp(prev, ema) put the mask a tick behind the face.
		# Extrapolating along each feature's velocity (ema + (ema - prev) * t) leads the fit by up to one tick, cancelling
		# the capture+EMA delay, at the cost of mild overshoot on direction reversals.
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
			# The face's own axes from the eye pair (direction along the eye line, scaled by 1/separation): everything
			# drawn in this frame (the craquelure) is pinned to the skin, not the screen.
			var eye_v: Vector2 = (cm.eye_r - cm.eye_l) * Vector2(_source_prep.source_aspect(), 1.0)
			var eye_len: float = maxf(eye_v.length(), 1e-4)
			mat.set_shader_parameter("u_clown_frame", eye_v / (eye_len * eye_len))
			mat.set_shader_parameter("u_clown_tint", _face_tint_ema)
			mat.set_shader_parameter("u_clown_lum", _face_lum_ema)


## The landmark anchor (whisp's field origin, chimera's graft window): the first whisp-or-chimera marker's
## target-color mass centroid in the captured frame, EMA-smoothed. When the key color exists nowhere (flat lighting),
## the motion centroid anchors instead. Fur does not read this: its strands root per pixel on the keyed surface (see
## fur_root_mass / the fur branch of apply_layer in mask_split.gdshader).
func _update_whisp_anchor(img: Image) -> void:
	var hue := -1.0
	for m in session.markers:
		var e := int(m.get("effect_a", 0))
		# Fur joins whisp/chimera in driving the anchor: its Stickiness cue wants the key color's centroid (motion
		# fallback for flat footage). Fur ignores u_anchor at Stickiness 0. Clown rides the same frame: its makeup layout
		# lives in the canonical space u_anchor defines.
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
	# Read the frame as one flat RGBA8 buffer instead of 1296 Image.get_pixel() calls: per-pixel Color construction was
	# a measurable slice of the periodic hitch after the synchronous readback (_face_frame does the same).
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
		# Size = RMS radius of the mass about its centroid (Var = E[|p|^2] - |E[p]|^2), the second half of the main face's
		# landmark frame.
		_anchor_scale_prev = _anchor_scale_ema
		_anchor_scale_ema = lerpf(_anchor_scale_ema,
			clampf(sqrt(maxf(1e-4, acc2 / wsum - (acc / wsum).length_squared())), 0.05, 0.9), 0.15)
	elif msum > 0.3:
		# Flat-lighting fallback: footage may carry the key color nowhere, so the landmark is wherever the pixels move (a
		# talking head's motion centroid is the head). A slower EMA than the color lock, since motion is noisier.
		_anchor_prev = _anchor_ema
		_anchor_ema = _anchor_ema.lerp(macc / msum, 0.1)
		_anchor_scale_prev = _anchor_scale_ema
		_anchor_scale_ema = lerpf(_anchor_scale_ema,
			clampf(sqrt(maxf(1e-4, macc2 / msum - (macc / msum).length_squared())), 0.05, 0.9), 0.1)
	if have_prev:
		_update_wave_impulses(motion / (48.0 * 27.0))


## Model a face as a landmark frame (centroid + isotropic size, RMS radius) from the key-color mass in an already-48x27
## frame, with the motion centroid+spread as the flat-lighting fallback (the thresholds _update_whisp_anchor uses). It
## runs on the imported track frame so the graft is normalized by the other head's frame before being re-fitted onto
## the main head. Returns {c, s, cur_lum, ok}; cur_lum is the caller's next previous-luminance grid.
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
	# Flat RGBA8 buffer read, see _update_whisp_anchor.
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


## Model the imported track face (chimera's graft source) each capture tick, so its frame (centroid + size) can
## normalize the graft. Keyed by the chimera marker's own color; nothing to do without one.
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


## Onset detection for the wave impulses: motion is this capture's average per-pixel luminance jolt. A baseline
## (_wave_motion_ema) and its deviation (_wave_dev_ema) track each clip's ambient motion, so one threshold fits every
## source. Rate-limited (see _WAVE_COOLDOWN): a shaky run of frames fires one wave.
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


## Fit the clown face model from one capture (the fallback when there is no landmark track): face mass -> centroid,
## spread and tint; the eyes as the two darkest clusters in the upper face band (split left/right); the mouth as the
## red/dark centroid below. Heuristics for one person near center facing the camera with small head movement. Face
## mass prefers the marker's key color (on natural footage, pick the skin tone), backed by a broad natural-skin rule
## and a centered prior that downweights the frame's edges. Results are EMA'd with prev/ema pairs; _push_anchor glides
## the uniforms between ticks like the anchor.
## The live clown layer's region, in frame UV, as the face model sees it: 1 inside, 0 outside, soft at the border.
## Mirrors the shader's region_mask (see mask_split.gdshader), so the detector searches the area the effect may paint.
## The default (whole frame) returns 1 everywhere.
func _face_region_at(uv: Vector2) -> float:
	var lo := Vector2(minf(_clown_region.x, _clown_region.z),
		minf(_clown_region.y, _clown_region.w))
	var hi := Vector2(maxf(_clown_region.x, _clown_region.z),
		maxf(_clown_region.y, _clown_region.w))
	var size := (hi - lo).max(Vector2(1e-4, 1e-4))
	# A softer shoulder than the shader's: the detector fades evidence out gradually at the edge so a face half in the
	# box still fits, where the drawn paint wants the edge as placed.
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
	# prev catches up every tick, found or not: the push extrapolates along (ema - prev), so prev is exactly one tick behind.
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
	# Every anatomical ratio below is in aspect-corrected space (x scaled by the frame's aspect): mixing raw uv axes made
	# the eye "distance" a width measure while eye-to-mouth stayed a height measure (the mouth offset read ~1.75 instead
	# of ~1.15 on 16:9).
	var fasp := 1.7778
	if src.get_height() > 0:
		fasp = float(src.get_width()) / float(src.get_height())
	var img: Image = src.duplicate()
	# Halve repeatedly before the final resize: Image.resize's bilinear filter samples a 2x2 neighborhood at any
	# reduction, so taking 1080x1920 straight to 96x54 is nearly point sampling and the weight field flickers with
	# sub-pixel movement. shrink_x2 is a true 2x2 box average, so halving to within ~2x of the target first makes the
	# last resize an average of the whole frame.
	while img.get_width() >= 192 and img.get_height() >= 108:
		img.shrink_x2()
	img.resize(96, 54, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	# Whole-frame mean luminance first: the brightness cue is relative to it (a face is bright against its own room).
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
			# Key-color mass as a hue cone, not a raw projection (the correction repaint's selection needed): a raw projection
			# rewards saturation as much as similarity (against the default red key, a lit yellow wall projects 0.324 and
			# the skin in front of it 0.206, so the model fitted the wall). By the brightness-free aligned fraction the two
			# are 45 and 24 degrees off the key, and a power turns a 1.6:1 loss into a 4.9:1 win for the face.
			var clen := sqrt(cr * cr + cg * cg + cb * cb)
			var align := maxf(0.0, cr * tdir.x + cg * tdir.y + cb * tdir.z) / maxf(clen, 1e-4)
			var pr := pow(align, 6.0) * smoothstep(0.02, 0.10, clen)
			# natural-skin fallback: warm chroma, red over blue, carried by real light; broad on purpose, the prior rejects
			var skin := 0.0
			if cr > 0.01 and l > 0.15 and cr > cb:
				skin = clampf(cr * 6.0, 0.0, 1.0) * clampf((cr - cb) * 4.0, 0.0, 1.0)
			# Luminance fallback, for faces with no usable chroma (near-monochrome grades, night looks): brightness relative
			# to this frame's own mean (_face_bg_lum) is the one signal such footage always has.
			var bright := smoothstep(_face_bg_lum + 0.06, _face_bg_lum + 0.30, l)
			var prior := exp(-pos.distance_squared_to(Vector2(0.5, 0.45)) / 0.18)
			# The region box is a "look for the face here" hint, not just a bound on where paint may land: color cannot
			# always separate a face from a warm lit wall that reads as skin to every cue, but position can. Applying the
			# box here turns it from a crop into guidance, so the detector locks onto the face instead of straddling both.
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
	# The face's size comes from its core, not every pixel that leans warm. The weight field is generous (key-hue
	# projection or skin chroma or brightness over the mean), so a lit wall the color of skin adds a wide low plateau
	# and a plain weighted variance reports the room's spread (rx climbed to 0.42 where the head is ~0.28, and the eye
	# pair was forced apart each tick until one sat on a headscarf). So the spread and centroid are measured over the
	# concentrated mass only: cells carrying a real fraction of the peak weight.
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
	# Fall back to the full field if the core is too thin to fit anything (a nearly flat field has no core).
	if cw > wsum * 0.02:
		acc = cacc
		accxx = cxx
		accyy = cyy
		wsum = cw
	var c := acc / wsum
	# The half-width is fitted in raw uv but bounded in height units, then converted back (see _FACE_ASP_REF): this
	# decides the eye and mouth search bands, so a wrong bound on a portrait clip aims the whole search wrong.
	var rx := clampf(sqrt(maxf(1e-5, accxx / wsum - c.x * c.x)) * 1.9 * fasp,
		0.06 * _FACE_ASP_REF, 0.30 * _FACE_ASP_REF) / fasp
	# The half-height's bound scales with the frame's shorter side: "a face is at most 0.36 of the frame's height" is a
	# convention about the short axis (on a portrait clip the height covers most of a standing body). The eye and mouth
	# search bands are fractions of ry, so a long ry aims them at the forehead and nose.
	var yshort: float = minf(1.0, fasp)
	var ry := clampf(sqrt(maxf(1e-5, accyy / wsum - c.y * c.y)) * 1.9,
		0.08 * yshort, 0.36 * yshort)
	var mean_lum := lum_acc / wsum
	var mean_red := red_acc / wsum
	# Blurred face mass (separable box, radius 3): an eye is a dark spot in a skin neighborhood. Weighting candidates by
	# the pixel's own mass fails (an eye carries no skin chroma), and a flat floor let dark hair flanking the face win
	# both clusters.
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
	# Second pass, inside the fitted oval only: eye clusters and mouth cluster, each with its own second moment; the
	# drawn features take their sizes from these spreads.
	var have_mo := _face_prev_lum.size() == 96 * 54
	# The eye frame from the last tick (stable, smoothed): the mouth's search band rides it.
	var eye_mid := (_face_eye_l_ema + _face_eye_r_ema) * 0.5
	# Eye separation in height units (aspect-corrected): the yardstick every ratio below is expressed in.
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
			# EYES: darkness against the face's mean, squared so real sockets dominate faint shading, weighted by the blurred
			# face mass (dark in a skin neighborhood is an eye, dark in dark is hair). Band kept off the oval's flanks.
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
			# This pixel in eye-pair units (aspect-corrected), the frame the nose and mouth search in.
			var mrel := ((pos - eye_mid) * Vector2(fasp, 1.0)) / eye_unit
			# NOSE: the nostril pair, two small dark spots between the eye line and the mouth near the center, the one
			# dependable 2D signature (the tip's highlight follows the lighting, and deriving the nose from mid-eyes to
			# mouth inherits both estimates' error).
			if mrel.y > 0.45 and mrel.y < 1.0 and absf(mrel.x) < 0.45:
				var nprior := exp(-pow((mrel.y - 0.85) / 0.28, 2.0))
				var wn := maxf(0.0, mean_lum - lums[idx]) * wblur[idx] * nprior
				wn *= wn   # concentrate on the actual nostril darkness (see the mouth)
				no_acc += pos * wn
				no_w += wn
			# MOUTH: motion first (on a talking face it out-moves the rest of the lower band, and unlike redness cannot lock
			# onto a warm-lit chin). Ambient face motion is subtracted; redness-over-face-mean and darkness are
			# tie-breakers. The search band hangs off the eye pair (the detection that works), not the fitted oval, which
			# swells over hair and shoulders and put the mouth on the chin.
			if mrel.y > 0.55 and mrel.y < 1.75 and absf(mrel.x) < 0.65:
				# Anatomical prior: the mouth sits ~1.2 eye-distances below the eye line. Talking moves the whole lower face, so
				# raw motion alone pulled the centroid under the nose; a wide gaussian keeps it on the lips without pinning.
				var mprior := exp(-pow((mrel.y - 1.15) / 0.38, 2.0))
				var wm := (maxf(0.0, dm - _face_motion_mean * 1.3) * 6.0
					+ maxf(0.0, reds[idx] - mean_red - 0.01) * 1.2
					+ maxf(0.0, mean_lum - lums[idx]) * 0.3) * wblur[idx] * mprior
				# Squared: the raw score is diffuse (shimmer and head motion leak everywhere) and blew the cluster's variance to
				# the clamps; squaring concentrates centroid and spread on the moving mouth.
				wm *= wm
				mo_acc += pos * wm
				mo2x += pos.x * pos.x * wm
				mo2y += pos.y * pos.y * wm
				mo_w += wm
	_face_prev_lum = lums
	if dm_n > 0.0:
		_face_motion_mean = lerpf(_face_motion_mean, dm_sum / dm_n, 0.3)
	# The two smoothing rates, under the author's hand (Steady and Firm in the panel): the right value differs per clip
	# (a locked-off shot wants heavy smoothing, a moving one cannot afford the lag). Positions and sizes are separate:
	# a lagging position reads as the mask sliding behind the face, a jittering size as pulsing, which is worth more lag
	# to kill. The mappings reproduce the old constants (0.35 positions, 0.30 sizes, 0.15 the coat) at the field defaults.
	# The fallback's own smoothing is back at the constants it was tuned with: the fields that drove these now carry the
	# shape knobs, and the track (which needs no smoothing) is the path that matters.
	var a_pos := 0.35
	var a_size := 0.30
	_face_r_ema = _face_r_ema.lerp(Vector2(rx, ry), a_size * 0.5)
	_face_c_ema = _face_c_ema.lerp(c, a_pos * 0.86)
	# The EMA stabilizes detection jitter; the push extrapolates (Lead), so residual EMA lag is what that covers.
	if el_w > 0.005 and er_w > 0.005:
		var el := el_acc / el_w
		var er := er_acc / er_w
		# Each eye's own spread -> its patch's own radius (eye-distance units, as the shader's frame consumes it).
		var el_var := maxf(1e-6, el2 / el_w - (ela_acc / el_w).length_squared())
		var er_var := maxf(1e-6, er2 / er_w - (era_acc / er_w).length_squared())
		# Only a plausible pair updates the model: really apart, roughly level, and the two clusters carrying comparable
		# evidence (when one side finds a socket and the other a headscarf or hair, the weights differ by an order of
		# magnitude though the geometry looks fine). Holding the previous pair for a tick beats accepting half a face.
		var pair_bal: float = minf(el_w, er_w) / maxf(el_w, er_w)
		if er.x - el.x > rx * 0.3 and absf(er.y - el.y) < ry * 0.45 \
				and pair_bal > 0.12:
			# Anatomy rein: eye separation is a fraction of the face's half-width. The clusters place the pair well but their
			# spread leans outward (sockets shade wider than pupils), so it is reined to the fitted face. The floor must
			# still catch a collapsed pair (two clusters on the same eye) without forcing a turned head, whose apparent
			# separation is smaller, back to a frontal assumption (a 0.55 floor pushed one eye onto the forehead).
			var mid := (el + er) * 0.5
			var sep := ((er - el) * Vector2(fasp, 1.0)).length()
			var facew := rx * fasp   # the face's half-width, same units as sep
			var want := clampf(sep, facew * 0.28, facew * 1.05)
			if sep > 1e-4:
				el = mid + (el - mid) * (want / sep)
				er = mid + (er - mid) * (want / sep)
			_face_eye_l_ema = _face_eye_l_ema.lerp(el, a_pos)
			_face_eye_r_ema = _face_eye_r_ema.lerp(er, a_pos)
			# Sizes in raw uv: each eye's spread stands alone, uncoupled from the pair's separation this tick.
			_face_eye_lr_ema = lerpf(_face_eye_lr_ema,
				clampf(sqrt(el_var) * 1.9, 0.015, 0.07), a_size)
			_face_eye_rr_ema = lerpf(_face_eye_rr_ema,
				clampf(sqrt(er_var) * 1.9, 0.015, 0.07), a_size)
	if mo_w > 0.0001:
		var mo := mo_acc / mo_w
		_face_mouth_ema = _face_mouth_ema.lerp(mo, a_pos)
		# The mouth's width and height separately: talking changes the vertical spread far more than the horizontal.
		var mvx := maxf(1e-6, mo2x / mo_w - mo.x * mo.x)
		var mvy := maxf(1e-6, mo2y / mo_w - mo.y * mo.y)
		# Caps ride the eye distance as a bound, not a normalization (the stored value stays raw uv, so the lips never
		# rescale in lockstep with the eyes; this only stops a diffuse tick drawing a face-wide blob). Bounded in height
		# units on the x axis, as rx above, so a portrait clip is not held to a third of the 16:9 width; the ceiling
		# already rode eye_unit.
		_face_mouth_r_ema = _face_mouth_r_ema.lerp(Vector2(
			clampf(sqrt(mvx) * 1.9 * fasp, 0.012 * _FACE_ASP_REF, eye_unit * 0.62) / fasp,
			clampf(sqrt(mvy) * 1.9, 0.008, eye_unit * 0.40)), a_size)
	if tint_acc.length() > 1e-4:
		_face_tint_ema = _face_tint_ema.lerp((tint_acc / wsum).normalized(), 0.1)
	_face_lum_ema = lerpf(_face_lum_ema, mean_lum, 0.1)
	_face_red_ema = lerpf(_face_red_ema, mean_red, 0.1)
	# The nose is derived (mid-eyes toward mouth) but smoothed on its own slower clock, so it does not inherit the eye
	# pair's jitter. The nostril centroid is the base of the nose; the ball sits on the tip, just above. Falls back to
	# mid-eyes-to-mouth (~55% down) only when no nostril evidence turns up (flat lighting, a raised chin, a profile).
	var nose_target := ((_face_eye_l_ema + _face_eye_r_ema) * 0.5).lerp(_face_mouth_ema, 0.55)
	var nose_alpha := a_pos * 0.43
	if no_w > 0.0001:
		nose_target = (no_acc / no_w) - Vector2(0.0, 0.14 * eye_unit)
		nose_alpha = a_pos * 0.86
	# A wide sanity box around the face's center line: a nose never lands out on a cheek.
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
	# The framework's panel: a [SidePanel] like every other note's, with "‹", the note's title and its "⋯" on top, a chip
	# per card, and three cards - the Clip, the Effect (the marker's key color, effect and options as one flat sortable
	# list, never titled groups) and the Markers, pinned under the rest so the manage-markers workflow stays in view.
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

	# Two buttons: Help and Import track. The rest (play, view cycle, peek, undo, redo) duplicate a key and live on the
	# keyboard and the help overlay. Import stays a button because it has no on-screen equivalent to discover; the T key
	# works too.
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

	# One channel (a target color, an effect, a strength). Channels are independent shader layers, not competing sides, so
	# there is no swap control.
	col = _panel.add_card("effect", "Effect", &"look", "",
		"The chroma-key effect at the marker picked: the color each channel keys, and what it does there.")
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
	# Three fields, one pick (as the repaint picker below). Only the hue is keyed on; the other two exist so the swatch
	# you get back is the swatch you set (see MaskSession's key_sat/key_val).
	_color_a.color_changed.connect(func(c):
		_edit("hue_a", c.h)
		_edit("key_sat", c.s)
		_edit("key_val", c.v))
	_grp_color.add_child(_color_a)
	col.add_child(_label("Effect", "Which visual treatment this layer applies"))
	_effect_a = _effect_menu(col, func(id): _edit("effect_a", float(id)))

	# Every option below (this channel's grading through this effect's pattern/echo/weather/tendril knobs) lives in one
	# flat, sortable list. Which rows are visible follows the selected effect (MaskSession.EFFECT_CONTROLS /
	# PATTERN_KNOBS, see _update_effect_controls); their order is _sort_mode, picked by _sort_dropdown (see _apply_sort).
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
	# Morph: its own field (fx_tint), decoupled from the color picker above: the picker says what to mask, this says what
	# color the drawn effect becomes (a palette hue rotation; 0 = the effect's natural colors).
	_hue_a = _slider(_grp_options, "Morph", 0.0, 1.0, func(v):
		_edit("fx_tint", v),
		"Rotates this effect's own palette hue - 0 keeps its natural colors")
	_register_option(_hue_a)

	# Option rows, shown per the selected effect's needs (MaskSession.EFFECT_CONTROLS): erase shows none (projection is
	# gate-free), restore only the threshold relabeled as its reach, the volumetrics everything. See
	# _update_effect_controls.
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

	# The wisp field's placement (pan/zoom over the frame) and coverage, from one wisp to an engulfing. All continuous
	# marker fields, so they blend through ramps/damps.
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

	# Snow's view onto fx_smooth: a separate widget from Smoothing above (same stored field, different meaning; the two
	# rows never show together, see _update_effect_controls).
	_gust = _slider(_grp_options, "Gust", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"0 is a steady drift, 1 is chaotic gusts")
	_register_option(_gust)

	# Fur's tendril dynamics: fur-only views onto fx_smooth/fx_lag, as Gust above.
	_undul = _slider(_grp_options, "Undulation", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"Traveling waves along each strand")
	_register_option(_undul)
	_coil = _slider(_grp_options, "Coil", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"Eddies and spiral curl")
	_register_option(_coil)
	# Stickiness: 0 is the free coat; higher thins the strands away from natural anchors so the hair clings to the keyed
	# surface, the tracked landmark/motion centroid and brighter regions (see the shader's fur branch).
	_bleed = _slider(_grp_options, "Bleed", 0.0, 1.0, func(v): _edit("fx_smooth", v),
		"How far each feature's paint may spread from the anatomy it found, and " +
		"how much it softens as it travels")
	_register_option(_bleed)
	_settle = _slider(_grp_options, "Settle", 0.0, 1.0, func(v): _edit("fx_lag", v),
		"How sticky the paint is in time - higher holds its shape through " +
		"detection wobble (steadier, a touch slower to follow)")
	_register_option(_settle)
	# The clown's shape knobs: how far the landmark track's measured outlines are pushed past the face they came from
	# (the successors of Steady/Firm/Lead, which smoothed a detector that no longer needs it). All four defaults equal
	# the constants they replaced.
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

	# The audio group: six knobs, no color, no pattern; this effect resolves to bus parameters (see _apply_audio_fx).
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
	# Umbra's own three: the stored fields fur/snow/clown reuse under their own names (the groups never show together).
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
	# The eye color has a control of its own (hue_b, wired to the shader).
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

	# Repaint's two. The paint color is three fields because a hue alone cannot say "black" (a yellow wall painted out).
	# Same field reuse as umbra's six above: fx_stick/fx_tint mean something else under other effects.
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
	# Three fields, one pick. _edit creates the marker on the first call and edits it on the other two.
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

	# The region: universal, not one effect's group (see _build_region_overlay for the box dragged on the video). A label
	# of its own though the checkbox carries text: every row is a (label, control) pair and _apply_sort re-orders them
	# two children at a time.
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

	# Every marker is a ramp or a damp (see MaskSession class doc): both transition to this marker's values; the kind is
	# the side of the anchor the transition occupies. Lives in _grp_options so it is part of the sortable list (see
	# _apply_sort/_register_option); a pick-type control with no slider, it sorts to the bottom under Energy mode.
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
	# Exponential response: fractions of a second on the left, whole minutes on the right (exp_edit needs a strictly
	# positive min).
	_marker_duration = _slider(_grp_options, "Ramp/damp span (s)", 0.05, maxf(8.0, session.duration),
		func(v): _edit("duration", v),
		"How long the ramp (before) or damp (after) transition takes, in seconds")
	_marker_duration.exp_edit = true
	_marker_duration.step = 0.01
	_register_option(_marker_duration)

	# --- create/delete + the sequential list, pinned to the panel's bottom with its own scroll, so the manage-markers
	# --- workflow stays visible together.
	var list_col: VBoxContainer = _panel.add_footer_card("markers", "Markers", &"look",
		"The clip's markers in order, each where the effect changes - a ramp eases in before it, a damp builds after - with add, delete and undo.")
	list_col.add_theme_constant_override("separation", 4)

	_marker_label = Label.new()
	_marker_label.add_theme_font_size_override("font_size", 12)
	_marker_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_marker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_col.add_child(_marker_label)

	# A preview of what Ctrl+Z would revert, above the buttons that create the history. Populated by
	# _refresh_history_label from _undo_descs.
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

	# The marker list's header, and beside it the switch for whether playback drags the selection along with it (see
	# _process). It is about the list, not a marker, so it is not stored on one.
	var order_row := HBoxContainer.new()
	# The label takes the slack, not a spacer beside it: every label here word-wraps (see _label), and a wrapping label's
	# minimum width is tiny, so an expanding spacer next to one squeezes it to a column of single letters.
	var order_lbl := _label("In order")
	order_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_row.add_child(order_lbl)
	_follow_playhead = CheckBox.new()
	_follow_playhead.text = "Follow"
	# Remembered across sessions in user://ghost.cfg, not the session JSON: it is a preference about how the editor
	# behaves, and storing it on the session would have opening someone else's work switch it back.
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


## `tip` is the full explanation shown on mouse-over (Godot's native tooltip); labels stay short so the panel reads clean.
func _label(text: String, tip: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	# Word-wrap caps a label's minimum width to its longest word: an unwrapped long label's width becomes the whole
	# column's minimum and pushes the panel wider than PANEL_W over the timeline.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_PASS   # let the tooltip trigger over the label itself
	l.tooltip_text = tip
	return l


func _slider(col: VBoxContainer, text: String, lo: float, hi: float, cb: Callable, tip: String = "") -> HSlider:
	var lbl := _label(text, tip)
	col.add_child(lbl)
	var s := HSlider.new()
	# Remember the label so a knob (label + slider) hides together (see _show_field / _update_effect_controls).
	s.set_meta("field_label", lbl)
	s.focus_mode = Control.FOCUS_NONE
	# The wheel belongs to the panel's ScrollContainer, never to a slider passed on the way down. Drag-only.
	s.scrollable = false
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.tooltip_text = tip   # hovering the slider itself explains it too, not just the label above
	s.value_changed.connect(cb)
	col.add_child(s)
	return s


## Show/hide one knob: the slider and its label (stored on the slider by _slider, or passed for the hand-built pattern
## rows). Prunes pattern knobs an effect doesn't read (MaskSession.PATTERN_KNOBS).
func _show_field(slider: Control, vis: bool, label: Control = null) -> void:
	if slider != null:
		slider.visible = vis
	var lbl: Variant = label
	if lbl == null and slider != null and slider.has_meta("field_label"):
		lbl = slider.get_meta("field_label")
	if lbl != null:
		(lbl as Control).visible = vis


## Registers a slider or pick-type control (label stashed via set_meta, by _slider or by hand for non-Range controls
## like an OptionButton) into the flat sortable list, see _apply_sort.
func _register_option(ctrl: Control) -> void:
	_options.append({"label": ctrl.get_meta("field_label"), "control": ctrl})


## Re-orders _options within _grp_options per the sort mode: alphabetical by each row's current label text (which
## changes per effect, e.g. Contrast -> Sensitivity for snow), or "energy": how wide each slider's fill reads, fullest
## first (see _option_energy). Pick-type controls with no slider (e.g. Kind) sink below every slider, alphabetical among
## themselves; hidden rows trail the visible ones. Re-run when the effect or visibility changes or a mode is picked,
## never on a live drag, so a slider never jumps out from under the mouse.
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


## How "present" a control's value is, for the "Energy" sort: a slider's fill fraction. Range.get_as_ratio() (not a
## linear (value-min)/span) matches the bar on screen for the exp_edit sliders (Scale/Velocity/Lag/Ramp-damp span),
## which are drawn on a logarithmic track. Pick-type controls (not a Range, e.g. Kind's OptionButton) return a
## sentinel below any real slider value, so _apply_sort sinks them.
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
	# Sliders are written with set_value_no_signal, but a ColorPickerButton has no such door: assigning `color` can emit
	# color_changed into _edit, which with nothing selected creates a marker stamped with the default hue. So the whole
	# sync is guarded. The flag must be true only inside this call: if _refresh_panel_inner aborts partway the reset
	# never runs and every _edit() returns early, discarding work. _process clears it every frame as a seatbelt.
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
	# The stored pick, all three components (rebuilding from hue_a alone round-trips a color into a different one).
	_color_a.color = Color.from_hsv(float(m.get("hue_a", 0.02)),
		float(m.get("key_sat", 0.85)), float(m.get("key_val", 0.9)))
	if _color_eye != null:
		_color_eye.color = Color.from_hsv(float(m.get("hue_b", 0.0)), 0.88, 1.0)
	if _color_paint != null:
		# The stored color itself, all three components: this picker is the value, not a hue preview.
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
	# Umbra's six. Every control is a view onto a stored field and must be re-read here, or it shows its construction
	# value while the marker holds something else, and the next drag writes from the wrong start.
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


## The control hierarchy in action (MaskSession.EFFECT_CONTROLS): show only the option groups the selected effect
## consumes. Threshold doubles as restore's reach (same stored field, relabeled).
func _update_effect_controls(effect_id: int) -> void:
	var groups: Array = MaskSession.EFFECT_CONTROLS.get(effect_id, [])
	# No target color for: clear (fades out everything earlier), snow (automatic foreground/background split), arealight
	# (lights the whole frame), meta (mirrors the workspace) and umbra (the ghost is the subject's own silhouette; its own
	# Eye color picker stays).
	var has_color := effect_id != MaskSession.EFFECT_CLEAR and effect_id != MaskSession.EFFECT_SNOW \
		and effect_id != MaskSession.EFFECT_SERPENT and effect_id != MaskSession.EFFECT_AREALIGHT \
		and effect_id != MaskSession.EFFECT_META and effect_id != MaskSession.EFFECT_RAIN \
		and effect_id != MaskSession.EFFECT_AUDIO and effect_id != MaskSession.EFFECT_UMBRA
	_grp_color.visible = has_color
	# Morph shows only where there is a palette to rotate (fixed-palette emissives, crystal's glass, fur's key-tinted coat,
	# clown's paint).
	var has_morph: bool = effect_id in [1, 2, 5, MaskSession.EFFECT_RAIN, MaskSession.EFFECT_CRYSTAL,
		MaskSession.EFFECT_SNOW, MaskSession.EFFECT_FUR, MaskSession.EFFECT_SERPENT,
		MaskSession.EFFECT_CLOWN, MaskSession.EFFECT_UMBRA]
	if _key_color_label != null:
		if effect_id == MaskSession.EFFECT_REPAINT:
			# Repaint has two color pickers that are easy to confuse: name both ends of the swap.
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
	# Prune the individual pattern knobs this effect never reads; effects absent from PATTERN_KNOBS show them all.
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
	# The region is universal, not in EFFECT_CONTROLS: it restricts where a layer acts, meaningful for every effect.
	# Hidden only where the effect draws nothing to confine (restore and clear act on other layers).
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
	# "Strength" means something different for the two subtractive effects.
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


## The keyboard map, centered over the video (F1 / the panel's Help button): everything the old toolbar did is a key
## now, and this overlay is where the shortcuts are found. Keep in sync with _unhandled_input.
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
	# Centered over the video side (the wrapper starts at PANEL_W). The wrapper ignores the mouse; the box catches its own clicks.
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = VIDEO_LEFT
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	wrap.add_child(_help_panel)


# --- the status line ------------------------------------------------------------------------------
# Shared bottom-right notification: prep and export progress use the same label and position.


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
	# Built before the chrome/timeline exist (see the _status var's doc): MaskTimeline's near-opaque background is added
	# later as a sibling and would paint over this label, so z_index keeps it on top.
	_status.z_index = 5
	add_child(_status)


func _set_status(text: String) -> void:
	if _status == null:     # render_mode never builds it - status there is stdout only
		print("ghost mask: ", text)
		return
	_status.text = text
	_status.visible = true


# --- markers: planted, edited, selected -----------------------------------------------------------


## Every panel edit targets the selected marker; if none is selected, planting one at the playhead is the edit's first
## move (a knob you touch becomes a marker). Auto-created as a ramp; press +Damp for the other kind.
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
	# Assigning a drawing effect to a marker whose own view shows no fx surface would leave a layer that holds but is
	# hidden by this marker's view. Bump the view to the nearest fx-showing mode, preserving the surface choice (raw ->
	# masked, pip_raw -> pip), never for restore/clear (they draw nothing). A marker minted by a panel touch bumps too,
	# whichever knob minted it: its default effect is already erase and strength 1.0, so a first move on the color picker
	# touches neither, and the marker would be born at view_mode raw, which renders no shader pass. Not widened to
	# hue_a on an existing marker: view_mode 2 there may be a raw checkpoint (the rebase, see MaskSession's class doc).
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


## The sequential ramp/damp list, pinned to the panel's bottom. Rebuilt wholesale (cheap at real marker counts);
## piggybacks on _refresh_marker_label's call sites (add/delete/select/drag).
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
	# Once a restart has committed to quitting, _player's playback is not a live read: the engine's shutdown stops it
	# before _exit_tree runs, reporting stream_position 0. _restart_now already took the definitive capture, so this
	# catch-all save must not re-derive playhead from a torn-down player.
	if _player != null and not _restarting:
		session.playhead = _player.stream_position   # persist where the playhead is
	if _tview != null:
		session.timeline_zoom = _tview.zoom
		session.timeline_view_start = _tview.view_start
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_session_path.get_base_dir()))
	session.save(ProjectSettings.globalize_path(_session_path))
	_dirty = false


## Reload the app to pick up code the assistant just edited, landing back on this session at the current playhead (both
## persisted, see _save_session). Godot can't hot-reload GDScript, so this is a restart-and-restore. It never fires
## while assistant runs are in progress (a restart would corrupt any still writing files): it hands the restart to the
## Assistant, which holds it until every agent has returned (see Assistant.reload_when_idle). The same deference
## applies to an export in progress (_render_state != "idle", see _poll_render), since quitting kills the
## render/transcode subprocess; checked first, and re-checked by _poll_render once the export finishes.
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


## The restart: relaunch this executable into --mask-edit on the current session (reopening at the saved playhead),
## preserving the engine args (--path etc.) it was launched with.
func _do_restart() -> void:
	_save_session()   # captures the playhead
	if _reload_check_pid > 0:
		return   # a check is already running - don't stack another
	# Never restart into code that doesn't compile: validate headless first (same check as src/scratchpad.py compile);
	# _process reads the result and only then restarts, or reports the errors and stays put.
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


## The restart, run once _do_restart's compile check comes back clean: relaunch into --mask-edit on the current session,
## preserving the engine args.
func _restart_now() -> void:
	# One last capture right before quitting: the compile check can take a while with the app interactive, so the
	# playhead captured when it started may be stale. This is the last point _player reports a live position (see
	# _save_session/_exit_tree).
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


## Poll the pre-reload compile check (see _do_restart): clean -> restart; errors -> block the reload and surface them.
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


## What the shared transport drives (see Spectrum's `_conductor`, handed over through [method Shell.conduct_transport];
## next/roadmap.md, "One transport for Masking too"): its play and stop, rail, Space and the arrows play, pause and seek
## the clip as they do a reading, and the marker strip scrubs the same clock. The video is the master: the position is
## the player's ([method playhead]), the length the clip's. Stop goes back to the in point and waits there.
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


## The room under the timeline: the shared transport's rail runs along the bottom of the window
## ([method Shell.transport_room]), so the marker strip, lanes and video stand above it. None in a render or with no shell.
func bottom_lift() -> float:
	var shell := Shell.of(self)
	return shell.transport_room() if shell != null and not render_mode else 0.0


func _on_scrub(t: float) -> void:
	_player.stream_position = t
	_audio.seek(t)


func _play(on: bool) -> void:
	# Hold a start the audio isn't ready for: _ready_with_session holds the autostart until the threaded load attaches,
	# and pressing play must too, or the video (the master clock) runs on and the audio joins late. _poll_audio_thread
	# starts playback the frame the stream lands, synced.
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
	# The video is the master clock. The two players pause at different instants (video on a decoded-frame boundary,
	# audio on a mix chunk), so each pause/resume banks a little offset: snap audio to the video on every resume;
	# _process keeps them corrected from there.
	if on:
		_audio.seek(_player.stream_position)
	# Track audios are driven entirely by MaskTracks.sync (windowed play/seek/pause).


## Derive the compressed playback sidecar for a session whose prep predates it (see _ready_with_session).
## Fire-and-forget: this run pays the slow WAV load it already started, later opens are instant. No .part dance: the
## name is read only when it exists, and a half-written .ogg fails to load and falls back.
func _ensure_audio_ogg(abs_wav: String, abs_ogg: String) -> void:
	if FileAccess.file_exists(abs_ogg) or not FileAccess.file_exists(abs_wav):
		return
	Subprocess.start("ffmpeg", PackedStringArray([
		"-y", "-loglevel", "error", "-i", abs_wav,
		"-c:a", "libvorbis", "-q:a", "5", abs_ogg]))


## Worker-thread body: the blocking WAV read (see _ready_with_session). The main thread attaches the result in _process.
func _load_wav_threaded(path: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(path)


## Attach the threaded main-audio load the frame it is ready, started at the live position so it is synced from its
## first sample. No-op until the thread finishes.
func _poll_audio_thread() -> void:
	if _audio_thread == null or _audio_thread.is_alive():
		return
	var stream = _audio_thread.wait_to_finish()
	_audio_thread = null
	if stream != null and _audio != null:
		_audio.stream = stream
		_apply_main_volume()
	# The autostart was waiting for this: begin playback now, synced (_play(true) seeks the audio to the video). If the
	# load failed (stream null) start anyway: a silent editor beats one frozen waiting on audio that never arrives.
	if _autostart_pending:
		_autostart_pending = false
		if _status != null and not render_mode:
			_status.visible = false
		_play(true)
		return
	if stream != null and _audio != null and _playing:
		_audio.play(_player.stream_position if _player != null else 0.0)
		_audio.stream_paused = false


## The main clip's 0/1 audio toggle -> the AudioStreamPlayer's level (-80 dB reads as silence). Per frame the fade
## overrides it (see _apply_main_fade); this covers the toggle flip and the initial attach.
func _apply_main_volume() -> void:
	if _audio != null:
		_audio.volume_db = _track_level_db(session.main_volume, 1.0)


## The clip-fade fraction (0 at a faded edge, 1 across the middle) for a position `local` seconds into a clip of length
## `span`, given fade_in / fade_out durations.
func _clip_fade_gain(local: float, span: float, fi: float, fo: float) -> float:
	var g := 1.0
	if fi > 0.001 and local < fi:
		g = clampf(local / fi, 0.0, 1.0)
	if fo > 0.001 and local > span - fo:
		g = minf(g, clampf((span - local) / fo, 0.0, 1.0))
	return clampf(g, 0.0, 1.0)

## Exponential audio taper for the pull-rope knob's raw 0..1 reading: a dead zone near the anchor, a spacious top for
## fine-tuning a loud level. _TAPER_K sets how hard the low end is suppressed; the curve is 0 at v=0 and 1 at v=1.
const _TAPER_K := 5.0


func _volume_taper(v: float) -> float:
	return (exp(_TAPER_K * v) - 1.0) / (exp(_TAPER_K) - 1.0)


## Audio gain in dB for a clip: the pull-rope volume `v` (0..1), exponentially tapered (see _volume_taper), times the
## fade envelope `g` (0..1), as a linear gain fraction. An equal-power curve into a real dB conversion spreads the
## perceived loudness change across the whole span with no cliff at the end (a linear dB floor of -40 left fades near
## -40 dB for most of the span, then jumped to silence), and flattens near l=1 for fine control at the top.
func _track_level_db(v: float, g: float) -> float:
	var l := _volume_taper(clampf(v, 0.0, 1.0)) * clampf(g, 0.0, 1.0)
	if l < 0.0005:
		return -80.0
	return clampf(linear_to_db(sin(l * PI * 0.5)), -80.0, 0.0)


## The main clip's fade, applied every frame: the composite dims via _composition_parent.modulate and the main audio
## ramps in dB, one coupled envelope. modulate reaches only the raw view (mask_split.gdshader's fragment() samples
## TEXTURE, not COLOR), so u_fade carries the same `g` into the shader. Deterministic off the playhead, so live and
## export match.
func _apply_main_fade() -> void:
	if _player == null:
		return
	var cin := session.clip_in
	var cout := session.effective_clip_out()
	var t := _player.stream_position
	# Past the main clip's kept range, the composite's alpha follows the continuation track (see
	# MaskSession.continuation_track_at) that owns `t`, with its own fade_in/fade_out, since that track's own frame is
	# the picture there. With no owner (a gap, or past all content) it holds at full opacity.
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
		# Audio cuts off exactly at cout, not extended by a continuation track's window: the track (MaskTracks._split_main's
		# tail, same video_path) plays its own audio via MaskTracks.sync once active, and gating on main_visible_at would
		# double it. Audio ownership passes to the track the moment one exists there, which can be before cout
		# (session.track_owns_audio_at), so that is checked too.
		var audible := 0.0 if (t >= cout or session.track_owns_audio_at(t)) else g
		_audio.volume_db = _track_level_db(session.main_volume, audible)


# --- view mode: main (raw/fx) x inset (hidden/raw/fx) ---------------------------------------------
# A per-marker field (MaskSession.VIEW_MODES), see class doc. There is no standalone "current mode" variable: the
# source of truth is session.at_time(playhead), read fresh every frame in _process (live and render_mode alike) and
# applied via _apply_frame_state, which consumes the continuous per-layer amounts, so mode changes fade across their
# marker's window.

## The display/cycle order: raw, then the inset appears (still raw), then the inset gets the effect, then the main
## screen joins it, then full-frame fx alone. VIEW_MODES' own order is append-only storage layout (see MaskSession).
const VIEW_CYCLE := [2, 3, 0, 5, 4, 1]   # raw -> pip_raw -> pip -> fx+raw-pip -> masked_pip -> masked


## The marker governing time `t`: the last-wins search at_time() uses for its `cur`, exposed for callers that need the
## marker object, not the resolved copy. Null before the first marker.
func _governing_marker(t: float) -> Variant:
	if session == null:
		return null
	var cur = null
	for m in session.markers:
		if m.time <= t:
			cur = m
	return cur


## The toggle edits the marker at the playhead like every panel control (see _edit): cycling is relative to what is
## active now, so it cannot drift from the timeline. _selected is retargeted to the playhead's governing marker first:
## it may still point at whatever the list was last clicked on, and editing through it would change an unrelated marker.
func _cycle_view_mode() -> void:
	# The cycle is the base looks, then per imported track a pair of stops showing that track raw in the PiP, once with
	# a raw main (pip_raw, 3) and once with an fx main (masked_pip_raw, 5). Each stop is [view_mode, pip_track].
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
	# Seatbelt: _syncing is valid only inside one synchronous _refresh_panel() call, so finding it set at the top of a
	# frame means that call aborted, and latched it would drop every later edit.
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
			# Nothing has touched it in a while and it never produced both files: the other writer died mid-prep. Run it ourselves.
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
			# Live readout every frame, exporter-style: a step with no percent ticks its elapsed seconds, so a slow venv
			# bootstrap never reads as a hang.
			var el := int(Time.get_unix_time_from_system() - _yt_step_started)
			match _yt_state:
				"downloading":
					var pct := _url_import.pct()
					_set_status("⏳  Downloading…  " + (pct if not pct.is_empty()
						else "connecting  %ds" % el))
					# yt-dlp's WARNING/ERROR lines echo into godot's log as they appear (deduped): a throttle warning is only
					# useful while the download crawls.
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
	# The export clock: in render mode the movie is driven by accumulated fixed-fps time (_render_t), not the video/audio
	# stream positions, which drift, stall, or end early when a source is shorter than the session. render_pos is where
	# the timeline is at this recorded frame; the decoded video free-runs within ~2 frames of it and is re-synced only on
	# real divergence (seeking every frame would thrash the OGV decoder).
	var render_pos := _player.stream_position
	if render_mode:
		_render_t += _dt
		render_pos = _render_t   # export runs the whole timeline from 0 (see _build_render_view)
		if _player.is_playing() and absf(_player.stream_position - render_pos) > 0.2:
			_player.stream_position = render_pos
	# Restore the persisted playhead once the player has had a frame to start (a same-frame seek in _ready_with_session
	# is ignored). Retried until it takes or a short budget lapses.
	if _pending_restore >= 0.0:
		var target := clampf(_pending_restore, session.clip_in, session.effective_clip_out())
		_player.stream_position = target
		if _audio != null:
			_audio.seek(target)
		if absf(_player.stream_position - target) < 1.0 or _pending_restore_tries > 20:
			_pending_restore = -1.0
		_pending_restore_tries += 1
	# Same resolve live or exported: whatever the timeline says now is what is shown. Live reads the (just-restored)
	# video position; export reads the deterministic movie clock.
	_apply_frame_state(session.at_time(render_pos if render_mode else _player.stream_position))
	_apply_main_fade()   # dim the whole composite + main audio at the clip's fade edges
	# The fx overlay re-draws whichever raw source is active: _player while the main clip's kept range covers it, else
	# _cont_view's texture (a continuation track's own decode, see _apply_frame_state), each only while on screen; "raw"
	# mode skips both and their shader passes.
	if _fx_overlay != null and _fx_overlay.visible:
		_fx_overlay.texture = _player.get_video_texture() if _player.visible else _cont_view.texture
	if _pip_view != null and _mask_wrap.visible:
		_pip_view.texture = _player.get_video_texture()
	_maybe_capture_echo()
	_maybe_capture_face()
	_tick_umbra()
	# META: while a meta layer is live, capture the editor's frame for the mirror and (in export) lerp the chrome into
	# view, gated on _meta_amount so the readback runs only during a meta section.
	if _meta_amount > 0.001:
		_capture_workspace()
	if render_mode:
		_apply_meta_chrome(_meta_amount)
	_push_anchor()
	_step_paint_sim()
	_step_umbra_sim()
	# Standing A/V drift correction (see _play: video is the master clock). The 0.15s tolerance sits above the audio mix
	# chunk so it never chatters. Video ahead of audio: seek audio forward (a silent skip). Audio ahead of video: hold
	# the audio (pause, no seek) until the video's decode catches up, since a backward seek replays sound as an echo.
	# This is the common case: _maybe_capture_echo's synchronous GPU readback stalls this thread every _ECHO_INTERVAL and
	# freezes _player.stream_position while _audio flows on its own thread.
	#
	# The hold's exit check runs outside the "_audio.playing" gate: stream_paused = true flips .playing to false at once,
	# so gating the exit on it would never release. The hold is bounded (_AUDIO_HOLD_LIMIT_MS): it assumes the video
	# catches up in a moment, true of a readback stall and false of a starved decode (a heavy background job), so past
	# the limit the audio is seeked back instead, replaying a fraction of a second rather than going silent.
	#
	# GHOST_AV_DEBUG=1 prints both clocks once a second once playback has started.
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
			# Every gain stage between the file and the speaker, in one line (the bus, its effects and the player's level).
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
	# A trimmed clip's out point is a hard wall for playback (live and the export relaunch; export needs a quit, since
	# Movie Maker records as long as the process runs). clip_in is not enforced: scrubbing earlier to look at
	# trimmed-away footage is fine. Bounded by content_end(), not clip_out: MaskTracks._split_main appends the trimmed
	# tail as a track at the same offset, so the show runs (the master clock is the main clip's decode position) until
	# that track's span is done too.
	var content_stop := session.content_end()
	if render_mode:
		# The export ends on the movie clock reaching the session's content length, never on a source stream ending (an
		# audio or video shorter than the session would truncate the movie and freeze the position the effects key off).
		# Past a source's end the timeline shows raw for that region, and the movie runs its full length with the full
		# audio. content_end() folds in clip_out and any continuation track: the export runs [0, content_end()].
		if _render_t >= content_stop - 0.001:
			get_tree().quit()
			return
	elif content_stop < session.duration and _player.stream_position >= content_stop and _playing:
		_play(false)
	if render_mode:
		return
	# Cross a marker during playback and it selects itself, so the panel and timeline follow the playhead. Only while
	# playing; a paused scrub or a click in the marker list is left alone. With Follow off, knobs can be tuned during
	# playback (crossing the next marker would take the panel away mid-adjustment).
	if _playing and _follow_playhead != null and _follow_playhead.button_pressed:
		var governing: Variant = _governing_marker(_player.stream_position)
		if governing != null and governing != _selected:
			_select_marker(governing)
	# Auto-hide the cursor once still for a beat during playback (_input() above resets the timer and un-hides on
	# motion; pausing restores it). Never while a popup is up: a color picker or dropdown is an embedded subwindow whose
	# mouse motion never reaches this node's _input(), so the pointer would vanish and not come back. Suspending the
	# timer here also un-hides on the way in, via the elif.
	if _playing and _modal_depth <= 0:
		_cursor_idle_t += _dt
		if _cursor_idle_t >= _CURSOR_HIDE_DELAY and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _time_label != null:
		_time_label.text = "%s / %s" % [
			Clock.text(_player.stream_position), Clock.text(session.duration)]
	# Auto-save: any edit marks the session dirty (see _mark_dirty); it lands shortly after the last change in a burst.
	if _dirty:
		_autosave_cooldown -= _dt
		if _autosave_cooldown <= 0.0:
			_save_session()
	_export.poll()


## Pushes one resolved timeline state (see MaskSession.at_time) into the layers: channel params to both materials, each
## layer's intensities scaled by its own presence amount, so a mode transition is a fade, not a toggle. The inset's
## border fades with it (modulate), and fully-absent layers are hidden so they cost nothing.
func _apply_frame_state(p: Dictionary) -> void:
	var main_amt := clampf(float(p.get("main_fx", 0.0)), 0.0, 1.0)
	var inset_show := clampf(float(p.get("inset_show", 0.0)), 0.0, 1.0)
	var inset_fx := clampf(float(p.get("inset_fx", 0.0)), 0.0, 1.0)
	if _peek_raw:
		main_amt = 0.0
		inset_show = 0.0
		inset_fx = 0.0
	_last_inset_show = inset_show
	# Which source fills the PiP this frame; falls back to the main clip if the stored index is past the track count.
	var pt := int(p.get("pip_track", 0.0))
	_pip_track = 0 if (_peek_raw or pt < 0 or pt > session.tracks.size()) else pt
	var t: float = _player.stream_position if _player != null else 0.0
	var env := _waveform.env_at(t)
	var layers: Array = p.get("layers", [])
	# Does a chimera layer render this frame? _maybe_capture_echo reads this to decide whether the track readback is
	# worth doing; _temporal_active gates the echo/whisp capture on what is on screen, not the session's marker list.
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
			# Four keying/pattern fields clown never keys or patterns with, read under their clown names (see the vars' doc).
			_clown_evidence = clampf(float(l.get("resonance", 0.0)), 0.0, 1.0)
			# Ranges chosen so the stored defaults land on "exactly the measured face": eye 1.0x, no drip, smile at the real
			# mouth's width, no sweep. Eye size is 1.2x at the bottom of the slider, 2.2x at the default, 5.2x wound up (a
			# negative scale would turn the hull inside out).
			_clown_eye_size = 1.2 + clampf(float(l.get("threshold", 0.24)), 0.0, 1.0) * 4.0
			_clown_drip = clampf(float(l.get("sat_floor", 0.18)), 0.0, 1.0) - 0.18
			# These sit on fields that default to 0, so 0 is a good value: a lean streak with a gentle bow is a tear of
			# liner. The smudge floor is a soft edge, not the polygon: a hard-edged oval is the fault this control exists
			# for, and the floor rounds off the 16-vertex hull's facets, visible at any real Eye size.
			_clown_smudge = 0.45 + clampf(float(l.get("swap", 0.0)), 0.0, 1.0) * 0.55
			_clown_drip_w = 0.35 + clampf(float(l.get("fx_y", 0.0)), 0.0, 1.0) * 0.80
			_clown_drip_curve = 0.45 + clampf(float(l.get("intensity_b", 0.0)),
				0.0, 1.0) * 1.55
			_clown_smile_w = 1.0 + (clampf(float(l.get("feather", 0.12)), 0.0, 0.5) - 0.12) * 8.0
			_clown_smile_curve = (clampf(float(l.get("fx_speed", 1.0)), 0.0, 2.0) - 1.0) * 0.12
			# fx_x defaults to 0, and 0 is a good value: some feather is always wanted, so the range is soft to softer.
			_clown_feather = 0.012 + clampf(float(l.get("fx_x", 0.0)), 0.0, 1.0) * 0.055
			_ft_sigma = MaskFaceTrack.sigma_for(float(l.get("hue_b", 0.0)))
			_clown_region = Vector4(
				float(l.get("reg_x0", 0.0)), float(l.get("reg_y0", 0.0)),
				float(l.get("reg_x1", 1.0)), float(l.get("reg_y1", 1.0)))
		if le == 5 or le == 7 or le == MaskSession.EFFECT_SNOW or le == MaskSession.EFFECT_ORACLE \
				or le == MaskSession.EFFECT_SERPENT or le == MaskSession.EFFECT_CHIMERA \
				or le == MaskSession.EFFECT_CLOWN:
			_temporal_active = true
		# The META mirror's strength: the same env x intensity the shader gets as this layer's weight. Drives whether the
		# workspace readback runs this frame and how far the render-mode chrome has revealed.
		if le == MaskSession.EFFECT_AUDIO:
			_audio_layer = l
		if le == MaskSession.EFFECT_META:
			_meta_amount = maxf(_meta_amount,
				clampf(float(l.get("env", 0.0)) * float(l.get("intensity_a", 0.0)), 0.0, 1.0))
	# The audio layer resolves to bus parameters rather than pixels, applied every frame, so its envelope ramps the sound
	# in as a visual layer's ramps its paint, and an export mixes the sound the editor previewed.
	_audio_fx.ensure_bus()
	_audio_fx.apply(_audio_layer)
	# Build the layer arrays once; only the weights differ per surface (each material multiplies its own presence in).
	# Arrays are pushed at full declared length: a short uniform array is silently dropped.
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
			# Resonance folds in CPU-side: the audio envelope swings coverage around its nominal and pulses the rim.
			densities.append(clampf(float(l.get("fx_density", 0.45)) + 0.5 * res * (env - 0.35), 0.0, 1.0))
			contrasts.append(float(l.get("fx_contrast", 0.5)))
			glows.append(1.0 + res * env * 1.3)
			speeds.append(maxf(0.05, float(l.get("fx_speed", 1.0))))
			smooths.append(clampf(float(l.get("fx_smooth", 0.0)), 0.0, 1.0))
			# The echo's temporal kernel: weights over the 8 ring ages, centered on the layer's lag. The age of ring index k
			# is (k + slot_frac) slots, continuous in playback time, so a spread kernel (Smoothing > 0) glides through the
			# ring and Smoothing ~ 0 collapses to the nearest single frame (the held-frame stutter). A pure function of
			# position and fields, so live and export blend identically.
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
			# The target hue's normalized chroma direction, for erase's projection-subtraction (no gates, no boundary rings).
			var tc := Color.from_hsv(float(l.get("hue_a", 0.0)), 1.0, 1.0)
			var tl := 0.299 * tc.r + 0.587 * tc.g + 0.114 * tc.b
			tdirs.append(Vector3(tc.r - tl, tc.g - tl, tc.b - tl).normalized())
			# The layer's region box, normalized so the shader never wonders which corner is which; sessions saved before
			# regions have none of these fields and fall back to the whole frame. Snapped here, not only when dragged (see
			# _snap_edge): a stored edge 0.002 off the top is a four-pixel band of the color the layer should remove, and
			# snapping at use treats every session alike and lets the shader skip that side's falloff on a flush edge.
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
	# Which source has valid picture at `t`: the main clip's kept range, or once that has ended the continuation track
	# (see MaskSession.continuation_track_at) that picked it up. Each renders through its own player (see
	# MaskTracks.sync), never by borrowing _player's.
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
		# The wisp field's clock is the clip's own playback position, never wall time, so live and export reproduce the
		# wisps frame for frame.
		mat.set_shader_parameter("u_time", t)
		var tex := (_player.get_video_texture() if _player != null else null) if main_active else cont_tex
		if tex != null and tex.get_height() > 0:
			mat.set_shader_parameter("u_aspect", float(tex.get_width()) / float(tex.get_height()))
			# The active source's own pixel grid (a continuation track may differ in size from the main clip).
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
		# Chimera's graft source: the first track's live frame. The explicit flag matters: the sampler's default-black
		# fallback must not read as footage.
		var track_tex: Texture2D = null
		if _tracks.runtime.size() > 0 and _tracks.runtime[0].has("player"):
			var tp: VideoStreamPlayer = _tracks.runtime[0].player
			if tp != null and tp.get_video_texture() != null \
					and tp.get_video_texture().get_height() > 0:
				track_tex = tp.get_video_texture()
		mat.set_shader_parameter("u_track_on", 1 if track_tex != null else 0)
		if track_tex != null:
			mat.set_shader_parameter("u_track", track_tex)
	# The active source's raw frame, and everything sourced from it (the fx overlay, its PiP inset), shows only while the
	# timeline claims this instant (past the main track's trim with no continuing track, video.ogv would still render).
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

extends RefCounted
class_name FrameForge

## FrameForge - scene geometry built off the main thread, so a heavy scene frame never blocks the UI.
##
## The engine runs one main loop (input, every node's _process/_draw, present), so GDScript spent in a frame blocks
## clicks for as long. Scene work lives on a worker thread and the main thread only submits.
##
## The contract a scene opts into:
##   - a static, pure builder function: takes one snapshot Dictionary of plain data (packed arrays, scalars, a
##     fresh-per-frame AudioFeatures), touches no nodes and no drawing API, and returns packet chunks
##     [{pts, cols, idx[, uvs, tex]}], typically built with a TriBatch.
##   - update() calls kick(builder, snapshot, self); if the worker is free the snapshot ships to a
##     WorkerThreadPool thread, and when the packet lands the scene is queue_redraw()n.
##   - _draw() calls submit(self): a few RenderingServer calls.
##
## Consequences:
##   - A slow worker only makes the backdrop update less often; input never waits.
##   - Snapshots must be safe: duplicate anything main mutates per frame; immutable-after-build arrays may pass by
##     reference.
##   - A scene freed mid-job (a Director cut) is harmless: the weakref completion just drops.
##   - Exports stay deterministic: in --export mode kick() runs the builder synchronously.

var _packet: Array = []
var _busy := false
var _pending_builder := Callable()
var _pending_snapshot := {}
var _has_pending := false            # a job-pattern snapshot is {}, so emptiness never means "no work"
var _pending_retain: RefCounted = null   # a Callable holds only an object ID and does not keep a RefCounted job alive, so the forge retains it until its build has run
## The job that built the packet now in `_packet`, swapped with it in one assignment (see [method packet_source]).
var _packet_src: RefCounted = null
var _fails := 0                          # consecutive builds that returned no packet

# resolved lazily on first kick; exports must build synchronously or the movie records stale packets
static var _sync_known := false
static var _sync := false


## Register the newest frame inputs. Cheap and idempotent: the Director calls a scene's update() several times
## per frame (music-clock debt substeps, the cut pre-warm), so kick() only stores the snapshot (newest wins). The
## build runs at most once per drawn frame: in submit() when synchronous, on the worker (pipelined, newest snapshot) live.
func kick(builder: Callable, snapshot: Dictionary, scene: CanvasItem,
		retain: RefCounted = null) -> void:
	if not _sync_known:
		_sync_known = true
		_sync = OS.get_cmdline_user_args().has("--export")
	_pending_builder = builder
	_pending_snapshot = snapshot
	_pending_retain = retain
	_has_pending = true
	if _sync:
		scene.queue_redraw()
		return
	if not _busy:
		_launch(scene)


func _launch(scene: CanvasItem) -> void:
	_busy = true
	var builder := _pending_builder
	var snapshot := _pending_snapshot
	var retain := _pending_retain    # a closure capture is a real reference: the job
	_pending_snapshot = {}           # lives exactly as long as its build
	_pending_retain = null
	_has_pending = false
	var wr: WeakRef = weakref(scene)
	WorkerThreadPool.add_task(func() -> void:
		# Untyped, then checked: a builder that aborts returns null, and `var out: Array = <null>` raises a second
		# error that kills this lambda before it can schedule `fin`, leaving `_busy` true forever. A failure must
		# degrade to a stale frame and a warning, never to a permanently black stage.
		var built: Variant = builder.call(snapshot)
		if retain != null:
			pass                     # (referenced so the capture is retained)
		var ok: bool = built is Array
		var out: Array = built if ok else []
		var fin := func() -> void:
			_busy = false
			if ok:
				_packet = out
				_packet_src = retain     # in the SAME assignment as the packet, on
				                         # the MAIN thread - see packet_source()
				_fails = 0
			else:
				_note_failure()      # keep the last good packet rather than blanking the stage
			var sc: Object = wr.get_ref()
			if sc != null:
				(sc as CanvasItem).queue_redraw()
				if _has_pending:
					_launch(sc as CanvasItem)   # pipeline: newest inputs next
		fin.call_deferred())


## A build produced no packet (the builder aborted on a runtime error): say so, on the first failure and every
## hundredth after, since a scene that draws only what the forge gives it goes black for its hold.
func _note_failure() -> void:
	_fails += 1
	if _fails == 1 or _fails % 100 == 0:
		push_warning("ghost: FrameForge build returned no packet (%d in a row) - " % _fails
			+ "the scene is showing its last good frame; look above for the builder's own error")


## The job object whose build produced the packet that is on screen now. A scene that draws anything alongside
## the packet places it against the inputs the packet was built from, not the inputs it has now, and cannot ask
## the job it last kicked (kick() keeps only the newest snapshot, and a build lands a frame or more later). The
## source and the packet are swapped in one assignment on one thread, so they cannot disagree.
##
## Null until the first packet lands. Cast it to your own job class.
func packet_source() -> RefCounted:
	return _packet_src


## Finish any build that has to happen on the main thread, so the packet AND
## [method packet_source] are final for this frame. [method submit] calls this itself; call
## it directly only when you must READ the source before drawing (contour_map sets its
## transform from it, and in export mode the build happens right here).
func flush() -> void:
	# `not _busy` keeps the inline first build (so a fresh cut never shows an empty backdrop) from firing while a
	# worker build of the same job is in flight: for a job object that carries state, two concurrent builds are a data
	# race. Skipping it costs at most one frame of empty backdrop.
	if _has_pending and (_sync or (_packet.is_empty() and not _busy)):
		var t0 := Time.get_ticks_usec()
		var built: Variant = _pending_builder.call(_pending_snapshot)
		var src := _pending_retain
		# Cleared before the check, so a builder that fails every frame does not also re-run off a pending flag that never clears.
		_pending_snapshot = {}
		_pending_retain = null
		_has_pending = false
		if built is Array:
			_packet = built
			_packet_src = src
			_fails = 0
		else:
			_note_failure()
		if not OS.get_environment("GHOST_PROFILE").is_empty():
			print("forge sync build: %d us" % (Time.get_ticks_usec() - t0))


## Emit the latest packet onto `ci`'s canvas. Call from _draw(). In sync
## (export) mode this is where the once-per-frame build happens; live, a
## scene with no packet yet builds its FIRST one inline so a fresh cut
## never shows an empty backdrop.
func submit(ci: CanvasItem) -> void:
	flush()
	var item := ci.get_canvas_item()
	for chunk in _packet:
		var c: Dictionary = chunk
		if (c.idx as PackedInt32Array).is_empty():
			continue
		if c.has("tex"):
			RenderingServer.canvas_item_add_triangle_array(
				item, c.idx, c.pts, c.cols, c.uvs,
				PackedInt32Array(), PackedFloat32Array(), c.tex)
		else:
			RenderingServer.canvas_item_add_triangle_array(
				item, c.idx, c.pts, c.cols)

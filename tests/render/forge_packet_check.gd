extends SceneTree

## forge_packet_check - [method FrameForge.packet_source] names the job whose geometry is actually on screen, not the
## newest build to have finished.
##   godot --headless --path . --script res://tests/render/forge_packet_check.gd
##   godot --headless --path . --script res://tests/render/forge_packet_check.gd -- --race
##
## A scene that draws anything alongside its packet places it against the inputs the packet was built from
## (contour_map translates a sheet built at one warp offset to show at another). That is exact only if the offset it
## subtracts is the offset the packet on screen carries: a job that publishes its offset at the end of run() (on the
## worker) while its packet reaches the main thread later makes every frame in between compensate the old sheet by
## the new offset.
##
## Asserted here is the synchronous path (the export's), which is deterministic and carries the same defect without
## needing luck: the build happens inside the draw, so a scene that reads the source before flushing gets the
## previous sheet's offset against this sheet's lines.
##
## `-- --race` runs the threaded path instead, kicking real worker builds and comparing what the packet says against
## both schemes each frame. It is a probe, not an assertion, since the disagreement is a race: packet_source()
## disagreed on 0 of ~237 frames, the old shared-slot mimic on 19-23. It exits dirty (any [WorkerThreadPool] task in a
## `--script` process faults during Godot's teardown), so the verdict is printed before quitting and the exit code
## means nothing.

## Frames to run in --race mode, and how often a fresh job is kicked: every few frames, since in the scenes' regime
## most builds finish between kicks.
const FRAMES := 240
const KICK_EVERY := 6
## Roughly how long a build should take: long enough to straddle a frame, since a build that returns instantly never opens the window.
const WORK := 60000

var _node: Node2D
var _forge: FrameForge
var _slot := OldSlot.new()
var _serial := 0
var _frame := 0
var _checked := 0
var _src_bad := 0
var _slot_bad := 0
var _race := false
var _fails: Array = []


func _initialize() -> void:
	_node = Node2D.new()
	root.add_child(_node)
	_race = OS.get_cmdline_user_args().has("--race")
	if _race:
		_forge = FrameForge.new()
		return
	_check_sync()
	_finish()


func _process(_dt: float) -> bool:
	if not _race:
		return false
	_frame += 1
	# Stop kicking before the end so the last build lands and is observed.
	if _frame % KICK_EVERY == 1 and _frame < FRAMES - KICK_EVERY * 3:
		_serial += 1
		var job := StampJob.new()
		job.serial = _serial
		job.slot = _slot
		_forge.kick(job.run, {}, _node, job)
	_observe()
	if _frame < FRAMES:
		return false
	_report_race()
	_finish()
	return false


## The export path, the deterministic half of the defect: the build happens inside the draw, so the source a scene
## reads before drawing is the previous packet's unless flush() has run first (the ordering contour_map depends on).
func _check_sync() -> void:
	FrameForge._sync_known = true
	FrameForge._sync = true
	var forge := FrameForge.new()
	for k in 3:
		var job := StampJob.new()
		job.serial = 100 + k
		forge.kick(job.run, {}, _node, job)
		forge.flush()
		var shown := _serial_of(forge)
		var src := forge.packet_source() as StampJob
		var got := -1 if src == null else src.serial
		print("forge_packet_check: sync build %d -> packet says %d, source says %d"
			% [job.serial, shown, got])
		if shown != job.serial:
			_fails.append("flush() left the packet at %d for a build of %d"
				% [shown, job.serial])
		if got != job.serial:
			_fails.append("flush() left the source at %d while the packet on screen is %d - "
				% [got, shown] + "a scene reading it before drawing places itself against the "
				+ "sheet BEFORE the one it is about to draw")
	FrameForge._sync = false


## Compare what the packet says against what each bookkeeping scheme claims.
func _observe() -> void:
	var shown := _serial_of(_forge)
	if shown <= 0:
		return
	_checked += 1
	var src := _forge.packet_source() as StampJob
	if src == null or src.serial != shown:
		_src_bad += 1
	if _slot.serial != shown:
		_slot_bad += 1


## The serial the geometry carries, encoded in its vertex count so this reads the packet itself.
func _serial_of(forge: FrameForge) -> int:
	var pk: Array = forge._packet
	if pk.is_empty():
		return 0
	var pts: PackedVector2Array = (pk[0] as Dictionary)["pts"]
	return pts.size() / 3 - 1


func _report_race() -> void:
	print("forge_packet_check: %d frames, %d kicks, %d frames with a packet"
		% [FRAMES, _serial, _checked])
	print("forge_packet_check: packet_source disagreed on %d, the old shared-slot mimic on %d"
		% [_src_bad, _slot_bad])
	if _checked < 20:
		_fails.append("only %d frames ever carried a packet - the probe measured nothing"
			% _checked)
	if _src_bad > 0:
		_fails.append("packet_source() named a job other than the one whose geometry is in "
			+ "the packet, on %d of %d frames" % [_src_bad, _checked])
	if _slot_bad == 0:
		print("forge_packet_check: (the old pattern did not lose the race this run - it is a "
			+ "race, not a certainty; the point is that the new one cannot lose it)")


func _finish() -> void:
	_node.free()
	if _fails.is_empty():
		print("forge_packet_check: ALL OK")
		quit()
		return
	print("forge_packet_check: %d FAILURE(S)" % _fails.size())
	for f in _fails:
		print("   ", f)
	quit(1)


## The old shared-slot scheme, kept as the thing being measured against.
class OldSlot:
	extends RefCounted
	var serial := 0


## A build that says who it is: the serial goes into the vertex count, so it travels inside the packet.
class StampJob:
	extends RefCounted

	var serial := 0
	var slot: OldSlot

	func run(_s: Dictionary) -> Array:
		# Real work, so the build straddles a frame the way a scene's does.
		var acc := 0.0
		for i in WORK:
			acc += sqrt(float(i))
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for k in serial + 1:
			var b := k * 3
			pts.append(Vector2(acc * 0.0, 0.0))
			pts.append(Vector2(1.0, 0.0))
			pts.append(Vector2(0.0, 1.0))
			cols.append(Color.WHITE)
			cols.append(Color.WHITE)
			cols.append(Color.WHITE)
			idx.append(b)
			idx.append(b + 1)
			idx.append(b + 2)
		# ...and the old pattern, from the worker, one instruction before the packet starts its journey to the main thread.
		if slot != null:
			slot.serial = serial
		return [{"pts": pts, "cols": cols, "idx": idx}]

extends SceneTree

## Does a background program ghost started die with ghost? Two mechanisms answer that (see [Subprocess]) and
## each is measured on its own:
##   The registry - `reap_all()` kills whatever is still registered when the app closes.
##   The death pact - `setpriv --pdeathsig KILL` binds the child to this process in the kernel, the only thing
##   that helps when no shutdown code runs. Ghost's own quit ends in `OS.kill(OS.get_process_id())`
##   (main._shutdown), so the SIGKILL this gate stages is what closing the window does.
##
## The pact half is two-sided: the child process starts two sleepers, one bound and one deliberately detached,
## and the check is that the parent's death took the first and not the second. Only the difference is evidence
## of a pact.
##
##   godot --headless --path . --script tests/platform/subprocess_pact_check.gd
##
## Linux only (PR_SET_PDEATHSIG); elsewhere it reports the registry half and says the pact was unavailable.
##
## The echo half holds that what a `start()` child prints reaches the app's loggers (the file the console tails).
## Its control is a child started with inherited stdio (`start_detached`): its line reaches the terminal and
## must not reach the loggers.
##
## The mark half holds that a child's tree goes with it, down to an orphan whose parent has already exited (an
## agent's gate after its shell returned), which neither the registry nor the pact can reach: `stop` takes one
## child's (control: another child's orphan still runs), `reap_all` the rest, and the pact half's SIGKILL takes
## a bound child's orphan through the guardian. The control in both is a detached child's orphan, unmarked,
## which survives.

const PID_FILE := "user://subprocess_pact_probe.txt"
const SLEEP_S := "120"
## A shell that leaves a sleeper orphaned (the subshell that started it has exited) and becomes a sleeper itself.
## The orphan's pid goes to the file $1.
const ORPHAN := "(sleep \"$2\" </dev/null >/dev/null 2>&1 & echo $! > \"$1\"); exec sleep \"$2\""

var _fails: Array = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--child"):
		_child_role()
		return
	_registry_half()
	_logged_half()
	_echo_half()
	_mark_half()
	_pact_half()
	if _fails.is_empty():
		print("subprocess_pact_check: ALL OK")
		quit(0)
	else:
		print("subprocess_pact_check: %d FAILURE(S)" % _fails.size())
		for f in _fails:
			print("   ", f)
		quit(1)


func _check(ok: bool, msg: String) -> void:
	print(("   ok   " if ok else "   FAIL ") + msg)
	if not ok:
		_fails.append(msg)


# The child: start one bound sleeper and one detached one, and one orphan-leaving shell of each kind, publish the
# pids, then sit until the parent kills us. Nothing here may quit on its own; this process must die by SIGKILL.
func _child_role() -> void:
	var bound := Subprocess.start("sleep", [SLEEP_S], "pact probe")
	var loose := Subprocess.start_detached("sleep", [SLEEP_S])
	var files := _orphan_files(["child_bound", "child_loose"])
	Subprocess.start("sh", ["-c", ORPHAN, "sh", files[0], SLEEP_S], "pact orphan")
	var loose_shell := Subprocess.start_detached("sh", ["-c", ORPHAN, "sh", files[1], SLEEP_S])
	var f := FileAccess.open(PID_FILE, FileAccess.WRITE)
	if f != null:
		f.store_line("%d %d %d %d %d %d" % [OS.get_process_id(), bound, loose,
			_orphan_pid(files[0]), _orphan_pid(files[1]), loose_shell])
		f.close()
	# no quit(): the parent SIGKILLs this process


# --- the registry, in this process ------------------------------------------------------
func _registry_half() -> void:
	print("REGISTRY (the clean-quit half: reap_all kills what is still registered)")
	var before := Subprocess.tracked()
	_check(not Subprocess.closing(), "nothing is closing before the reap")
	var pid := Subprocess.start("sleep", [SLEEP_S], "registry probe")
	_check(pid > 0, "a tracked child started (pid %d)" % pid)
	_check(Subprocess.tracked() == before + 1, "it is registered (%d tracked)" % Subprocess.tracked())
	_check(_running(pid), "and it is actually running")
	# The readers are done when the reap returns: a killed child's log reader calls back into Subprocess after a
	# few empty reads, and a closing engine has cleared its functions. The control is a stop (kill, let go), which
	# leaves its reader running.
	var log_path := OS.get_user_data_dir().path_join("subprocess_reap_probe.log")
	var stopped := Subprocess.start_logged("sleep", [SLEEP_S], log_path, "reap control")
	Subprocess.start_logged("sleep", [SLEEP_S], log_path, "reap probe")
	Subprocess.stop(stopped)
	_check(Subprocess._stray.any(func(t: Thread) -> bool: return t.is_alive()),
		"control: a child stopped and let go leaves its log reader running")
	var n := Subprocess.reap_all()
	_check(Subprocess._stray.is_empty() and Subprocess._pumps.is_empty(),
		"every log reader has finished and been joined when reap_all() returns (%d left)"
		% (Subprocess._stray.size() + Subprocess._pumps.size()))
	DirAccess.remove_absolute(log_path)
	OS.delay_msec(400)
	_check(n >= 1, "reap_all() reported killing %d" % n)
	_check(Subprocess.closing(), "...and says ghost is closing, for whoever was watching a child")
	_check(not _running(pid), "the child is gone after reap_all()")
	_check(Subprocess.tracked() == 0, "the registry is empty (%d tracked)" % Subprocess.tracked())
	# ...and the registry forgets a child that exited on its own, or a shutdown reap could signal a recycled pid.
	var quick := Subprocess.start("true", [], "exit probe")
	OS.delay_msec(300)
	_check(not Subprocess.alive(quick), "a child that exited is reported not alive")
	_check(Subprocess.tracked() == 0, "...and is forgotten (%d tracked)" % Subprocess.tracked())

	# The second stop: after a reap, `stop` must answer from the registry and never reach the kernel (the old
	# `OS.is_process_running` call printed "The process N does not exist or is not a child of the calling process").
	_check(not Subprocess.stop(pid), "a second stop, after the reap, is a no-op")
	_check(not Subprocess.stop(-1), "stopping a pid that was never started is a no-op")
	# The sharp version: hand `stop` a running pid that is not ours - this very process. Without the registry
	# check it would SIGKILL the gate, so surviving to the next assertion is the assertion.
	var me := OS.get_process_id()
	_check(not Subprocess.alive(me), "alive() answers from the registry, not from the OS")
	_check(not Subprocess.stop(me), "stop() refuses a pid it did not start...")
	OS.delay_msec(150)
	_check(_running(me), "...and the gate is still running to say so")


# --- start_logged: output pumped into a log, no shell ------------------------------------
# start_logged must hold what the shell redirect held: more than a pipe's worth (64 KiB) on both streams,
# interleaved (a single reader blocked on one stream deadlocks while the child fills the other), and `alive()`
# must not report the child gone before its last line is in the log.
func _logged_half() -> void:
	print("LOGGED (start_logged: both streams into one file, drained before alive() lets go)")
	var log_path := OS.get_user_data_dir().path_join("subprocess_logged_probe.log")
	var n := 3000
	var script := "i=0; while [ $i -lt %d ]; do " % n \
		+ "echo \"out $i ................................................\"; " \
		+ "echo \"err $i ................................................\" >&2; " \
		+ "i=$((i+1)); done; echo LAST-OUT; echo LAST-ERR >&2"
	var pid := Subprocess.start_logged("sh", ["-c", script], log_path, "logged probe")
	_check(pid > 0, "a logged child started (pid %d)" % pid)
	var waited := 0
	while Subprocess.alive(pid) and waited < 15000:
		OS.delay_msec(20)
		waited += 20
	_check(waited < 15000, "it finished (%d ms) - no deadlock on two full pipes" % waited)
	var text := FileAccess.get_file_as_string(log_path)
	var outs := 0
	var errs := 0
	for line in text.split("\n"):
		if line.begins_with("out "):
			outs += 1
		elif line.begins_with("err "):
			errs += 1
	_check(outs == n and errs == n, "every line of both streams is in the log (%d/%d, %d/%d)"
		% [outs, n, errs, n])
	_check(text.contains("LAST-OUT") and text.contains("LAST-ERR"),
		"including the last ones, read the moment alive() said it was gone")
	var sleeper := Subprocess.start_logged("sleep", [SLEEP_S], log_path, "logged sleeper")
	_check(Subprocess.stop(sleeper), "a logged child can be stopped")
	OS.delay_msec(300)
	_check(not _running(sleeper), "and it is gone")
	DirAccess.remove_absolute(log_path)


# --- start: what a child prints reaches the app's log -------------------------------------
class _Catch extends Logger:
	var lock := Mutex.new()
	var said: Array[String] = []

	func _log_message(message: String, error: bool) -> void:
		lock.lock()
		said.append(("ERR " if error else "OUT ") + message.strip_edges(false, true))
		lock.unlock()


func _echo_half() -> void:
	print("ECHO (start: a child's output lands in the app's log, as the console reads it)")
	var catch := _Catch.new()
	OS.add_logger(catch)
	# stdout, stderr, a progress line rewritten in place with \r, and a last line with no end
	var script := "echo 'parity out'; echo 'parity err' >&2; " \
		+ "printf 'parity tick 1\\rparity tick 2\\r'; printf 'parity last'"
	var pid := Subprocess.start("sh", ["-c", script], "parity")
	_check(pid > 0, "a child started (pid %d)" % pid)
	var loose := Subprocess.start_detached("sh", ["-c", "echo 'parity loose'"])
	var waited := 0
	while Subprocess.alive(pid) and waited < 5000:
		OS.delay_msec(20)
		waited += 20
	OS.delay_msec(300)                   # the detached child's line has long been written
	OS.remove_logger(catch)
	catch.lock.lock()
	var said := catch.said.duplicate()
	catch.lock.unlock()
	for want in ["OUT [parity] parity out", "ERR [parity] parity err", "OUT [parity] parity tick 1",
			"OUT [parity] parity tick 2", "OUT [parity] parity last"]:
		_check(said.has(want), "the log has `%s`" % want)
	_check(loose > 0 and not said.any(func(l: String) -> bool: return l.contains("parity loose")),
		"CONTROL: a child on the terminal (start_detached) does not reach the log")
	# A Godot child of this project gets a log file of its own, never the app's
	var own := Subprocess.own_log("probe")
	var live := ProjectSettings.globalize_path(String(ProjectSettings.get_setting(
		"debug/file_logging/log_path", "user://logs/godot.log")))
	_check(own.size() == 2 and own[0] == "--log-file" and own[1] != live,
		"own_log() names a file other than the app's log (%s)" % own[1])
	# Release builds: the raw settings, since a debug run reads the `.debug` override instead
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	_check(cfg.get_value("application", "run/flush_stdout_on_print", false) == true,
		"release builds flush the log on every line (ghost quits by SIGKILL)")
	_check(cfg.get_value("debug", "file_logging/enable_file_logging", false) == true,
		"every platform keeps a log file, Android too")


# --- the mark: what a child starts goes with it -------------------------------------------
func _mark_half() -> void:
	print("THE MARK (a child's tree goes with it, even what a parent that already exited left running)")
	if OS.get_name() != "Linux":
		print("   SKIP - the mark is swept through /proc")
		return
	var files := _orphan_files(["a", "b", "loose"])
	var a := Subprocess.start("sh", ["-c", ORPHAN, "sh", files[0], SLEEP_S], "orphan a")
	var b := Subprocess.start("sh", ["-c", ORPHAN, "sh", files[1], SLEEP_S], "orphan b")
	# Detached on purpose: unmarked, the orphan every sweep must leave alone.
	var loose := Subprocess.start_detached("sh", ["-c", ORPHAN, "sh", files[2], SLEEP_S])
	var oa := _orphan_pid(files[0])
	var ob := _orphan_pid(files[1])
	var ol := _orphan_pid(files[2])
	_check(oa > 0 and ob > 0 and ol > 0, "three children each left an orphan (%d %d %d)" % [oa, ob, ol])
	_check(_running(oa) and _ppid(oa) != a,
		"a's orphan runs and a is not its parent: neither the registry nor the pact can reach it")
	Subprocess.stop(a)
	_check(_gone_within(oa), "stop(a) took a's orphan with it")
	_check(_running(ob), "CONTROL: b's orphan, another child's tree, still runs")
	Subprocess.reap_all()
	_check(not _running(ob), "reap_all() took b's orphan, though only b was registered")
	_check(_running(ol), "CONTROL: a detached child's orphan carries no mark and survives the reap")
	for p in [ol, loose, oa, ob]:
		if _running(p):
			OS.kill(p)
	for p in files:
		DirAccess.remove_absolute(p)


# --- the pact, across a hard kill -------------------------------------------------------
func _pact_half() -> void:
	print("DEATH PACT (the killed-outright half: the kernel kills the child with us)")
	if Subprocess._pact_bin() == "-":
		print("   SKIP - no setpriv --pdeathsig on this system; the registry half stands alone")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PID_FILE))
	var exe := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	# Detached on purpose: this probe must die by SIGKILL and nothing else, so it must not be bound to the gate.
	var child := Subprocess.start_detached(exe, PackedStringArray([
		"--headless", "--path", project, "--script",
		"res://tests/platform/subprocess_pact_check.gd", "--", "--child"]))
	_check(child > 0, "child ghost started (pid %d)" % child)
	var line := ""
	for _i in 100:                       # up to ~10 s for the child to boot and publish
		OS.delay_msec(100)
		var f := FileAccess.open(PID_FILE, FileAccess.READ)
		if f != null:
			line = f.get_line().strip_edges()
			f.close()
			if line.split(" ").size() == 6:
				break
	var parts := line.split(" ")
	if parts.size() != 6:
		_check(false, "the child never published its pids (got %r)" % line)
		if child > 0:
			OS.kill(child)
		return
	var kid := int(parts[0])
	var bound := int(parts[1])
	var loose := int(parts[2])
	var bound_orphan := int(parts[3])
	var loose_orphan := int(parts[4])
	var loose_shell := int(parts[5])
	print("   child ghost %d started bound=%d loose=%d orphans bound=%d loose=%d"
		% [kid, bound, loose, bound_orphan, loose_orphan])
	_check(_running(bound) and _running(loose), "both sleepers are running before the kill")
	_check(_running(bound_orphan) and _ppid(bound_orphan) != kid and _running(loose_orphan),
		"both orphans are running, out of the pact's reach")
	OS.kill(kid)                         # Godot's OS.kill is SIGKILL: no shutdown code runs
	_check(_gone_within(bound), "the BOUND child died with the parent (no shutdown code ran)")
	_check(_running(loose), "the DETACHED child survived - so the pact is what killed the other")
	_check(_gone_within(bound_orphan), "the bound child's ORPHAN died too: the guardian swept the mark")
	_check(_running(loose_orphan), "the detached child's orphan survived - so the mark is what found the other")
	# Leave nothing behind, whichever way the checks went.
	for p in [loose, bound, loose_orphan, bound_orphan, loose_shell, kid]:
		if p > 0 and _running(p):
			OS.kill(p)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PID_FILE))
	for p in _orphan_files(["child_bound", "child_loose"]):
		DirAccess.remove_absolute(p)


# Liveness without OS.is_process_running: these are grandchildren, and polling a pid this process did not spawn
# is the ECHILD hazard mask_editor documents. /proc is the plain fact; a zombie is not running.
func _running(pid: int) -> bool:
	var stat := _stat(pid)
	return stat.size() > 1 and stat[0] != "Z"


# The fields of /proc/<pid>/stat after the command, from the state on; empty once it is gone.
func _stat(pid: int) -> PackedStringArray:
	var f := FileAccess.open("/proc/%d/stat" % pid, FileAccess.READ) if pid > 0 else null
	if f == null:
		return PackedStringArray()
	var line := f.get_line()
	return line.substr(line.rfind(")") + 1).strip_edges().split(" ", false)


func _ppid(pid: int) -> int:
	var stat := _stat(pid)
	return int(stat[1]) if stat.size() > 1 else -1


# Waits, measured, up to ~5 s for `pid` to stop running.
func _gone_within(pid: int) -> bool:
	for _i in 100:
		if not _running(pid):
			return true
		OS.delay_msec(50)
	return not _running(pid)


func _orphan_files(names: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n in names:
		var p := OS.get_user_data_dir().path_join("subprocess_orphan_%s.txt" % n)
		DirAccess.remove_absolute(p)
		out.append(p)
	return out


# The orphan's pid once its shell has written it, -1 if it never does.
func _orphan_pid(path: String) -> int:
	for _i in 100:
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var line := f.get_line().strip_edges()
			f.close()
			if line.is_valid_int():
				return int(line)
		OS.delay_msec(20)
	return -1

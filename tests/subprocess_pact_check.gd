extends SceneTree

## Does a background program ghost started die with ghost? Reported as: both windows shut,
## and `ffmpeg` still transcoding to disk with no "godot" left in `ps` to explain it.
##
## Two mechanisms answer that (see [Subprocess]) and they fail differently, so each is
## measured on its own:
##   THE REGISTRY - `reap_all()` kills whatever is still registered when the app closes.
##   THE DEATH PACT - `setpriv --pdeathsig KILL` binds the child to this process in the
##   KERNEL, which is the only thing that can help when no shutdown code runs at all. That
##   is the ordinary case here, not the exotic one: ghost's own quit ends in
##   `OS.kill(OS.get_process_id())` (main._shutdown, an audio-teardown workaround), so the
##   SIGKILL this gate stages is exactly what closing the window does.
##
## The pact half is TWO-SIDED and has to be: a test that only checks "the child is gone
## after the parent is killed" passes just as well if the child never started, if it exited
## on its own, or if something else swept it up. So the child process starts TWO sleepers -
## one bound, one deliberately detached - and the check is that the parent's death took the
## first and NOT the second. Only the difference between them is evidence of a pact.
##
##   godot --headless --path . --script tests/subprocess_pact_check.gd
##
## Linux only, because PR_SET_PDEATHSIG is; elsewhere it reports the registry half and says
## the pact was unavailable rather than failing.
##
## THE ECHO HALF holds the log's parity with the terminal: what a `start()` child prints must
## reach the app's loggers (the file the console tails), because it used to inherit the terminal
## and nobody without one ever saw it. Its control is a child started the old way
## (`start_detached`, inherited stdio): its line reaches the terminal and must NOT reach the
## loggers, or catching the other proves nothing.

const PID_FILE := "user://subprocess_pact_probe.txt"
const SLEEP_S := "120"

var _fails: Array = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--child"):
		_child_role()
		return
	_registry_half()
	_logged_half()
	_echo_half()
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


# THE CHILD: start one bound sleeper and one detached one, publish both pids, then sit
# there until the parent kills us. Nothing here may quit on its own - the whole point is
# that this process dies by SIGKILL, with no chance to clean up after itself.
func _child_role() -> void:
	var bound := Subprocess.start("sleep", [SLEEP_S], "pact probe")
	var loose := Subprocess.start_detached("sleep", [SLEEP_S])
	var f := FileAccess.open(PID_FILE, FileAccess.WRITE)
	if f != null:
		f.store_line("%d %d %d" % [OS.get_process_id(), bound, loose])
		f.close()
	# no quit(): the parent SIGKILLs this process


# --- the registry, in this process ------------------------------------------------------
func _registry_half() -> void:
	print("REGISTRY (the clean-quit half: reap_all kills what is still registered)")
	var before := Subprocess.tracked()
	var pid := Subprocess.start("sleep", [SLEEP_S], "registry probe")
	_check(pid > 0, "a tracked child started (pid %d)" % pid)
	_check(Subprocess.tracked() == before + 1, "it is registered (%d tracked)" % Subprocess.tracked())
	_check(_running(pid), "and it is actually running")
	var n := Subprocess.reap_all()
	OS.delay_msec(400)
	_check(n >= 1, "reap_all() reported killing %d" % n)
	_check(not _running(pid), "the child is gone after reap_all()")
	_check(Subprocess.tracked() == 0, "the registry is empty (%d tracked)" % Subprocess.tracked())
	# ...and the registry FORGETS a child that exited on its own, or a shutdown reap could
	# signal a pid the OS has since handed to somebody else.
	var quick := Subprocess.start("true", [], "exit probe")
	OS.delay_msec(300)
	_check(not Subprocess.alive(quick), "a child that exited is reported not alive")
	_check(Subprocess.tracked() == 0, "...and is forgotten (%d tracked)" % Subprocess.tracked())

	# THE SECOND STOP. Reported as an error on every close: `Boot` reaps the registry, then the
	# tree tears down and the owning autoload's `_exit_tree` stops its own pid again - and the
	# old `stop()` asked `OS.is_process_running` first, which waitpid()s a child Godot has
	# already reaped and prints "The process N does not exist or is not a child of the calling
	# process". So a stop after a reap must answer from the REGISTRY and never reach the kernel.
	_check(not Subprocess.stop(pid), "a second stop, after the reap, is a no-op")
	_check(not Subprocess.stop(-1), "stopping a pid that was never started is a no-op")
	# And the sharp version of the same claim, which cannot pass by accident: hand `stop` a pid
	# that IS running but is not ours - this very process. Without the registry check it would
	# SIGKILL the gate, so surviving to make the next assertion IS the assertion.
	var me := OS.get_process_id()
	_check(not Subprocess.alive(me), "alive() answers from the registry, not from the OS")
	_check(not Subprocess.stop(me), "stop() refuses a pid it did not start...")
	OS.delay_msec(150)
	_check(_running(me), "...and the gate is still running to say so")


# --- start_logged: output pumped into a log, no shell ------------------------------------
# The seven `/bin/bash -c '... > log 2>&1'` call sites are this now, so it has to hold what
# the shell held. More than a pipe's worth (64 KiB) on BOTH streams, interleaved: a single
# reader blocked on one stream while the child fills the other deadlocks, and that is the
# case that would hang a pip install forever. And `alive()` must not report the child gone
# before its last line is in the log - callers read the log the frame it exits.
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
	# RELEASE BUILDS: the raw settings, since a debug run reads the `.debug` override instead
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	_check(cfg.get_value("application", "run/flush_stdout_on_print", false) == true,
		"release builds flush the log on every line (ghost quits by SIGKILL)")
	_check(cfg.get_value("debug", "file_logging/enable_file_logging", false) == true,
		"every platform keeps a log file, Android too")


# --- the pact, across a hard kill -------------------------------------------------------
func _pact_half() -> void:
	print("DEATH PACT (the killed-outright half: the kernel kills the child with us)")
	if Subprocess._pact_bin() == "-":
		print("   SKIP - no setpriv --pdeathsig on this system; the registry half stands alone")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PID_FILE))
	var exe := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	# Detached ON PURPOSE: this probe must die by SIGKILL and by nothing else, so it must
	# not be bound to the process running the gate.
	var child := Subprocess.start_detached(exe, PackedStringArray([
		"--headless", "--path", project, "--script",
		"res://tests/subprocess_pact_check.gd", "--", "--child"]))
	_check(child > 0, "child ghost started (pid %d)" % child)
	var line := ""
	for _i in 100:                       # up to ~10 s for the child to boot and publish
		OS.delay_msec(100)
		var f := FileAccess.open(PID_FILE, FileAccess.READ)
		if f != null:
			line = f.get_line().strip_edges()
			f.close()
			if line.split(" ").size() == 3:
				break
	var parts := line.split(" ")
	if parts.size() != 3:
		_check(false, "the child never published its pids (got %r)" % line)
		if child > 0:
			OS.kill(child)
		return
	var kid := int(parts[0])
	var bound := int(parts[1])
	var loose := int(parts[2])
	print("   child ghost %d started bound=%d loose=%d" % [kid, bound, loose])
	_check(_running(bound) and _running(loose), "both sleepers are running before the kill")
	OS.kill(kid)                         # Godot's OS.kill is SIGKILL: no shutdown code runs
	var gone := false
	for _i in 50:                        # the kernel signals PDEATHSIG promptly; allow ~5 s
		OS.delay_msec(100)
		if not _running(bound):
			gone = true
			break
	_check(gone, "the BOUND child died with the parent (no shutdown code ran)")
	_check(_running(loose), "the DETACHED child survived - so the pact is what killed the other")
	# Leave nothing behind, whichever way the checks went.
	for p in [loose, bound, kid]:
		if p > 0 and _running(p):
			OS.kill(p)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PID_FILE))


# Liveness WITHOUT OS.is_process_running: these are grandchildren, and polling a pid this
# process did not spawn is the ECHILD hazard mask_editor documents. /proc is the plain fact.
func _running(pid: int) -> bool:
	return pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid)

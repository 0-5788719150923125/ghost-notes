extends RefCounted
class_name Subprocess

## Subprocess - every external program ghost starts, in one place, with one promise: a child never outlives
## the app that started it. `OS.create_process` on Unix is fully detached, so closing or killing ghost would
## leave an `ffmpeg` transcoding to disk. Going through [method start] covers every call site by default.
##
## Two independent mechanisms:
##
## 1. The registry (everywhere). Every pid started here is remembered until it exits or is stopped, and
##    [method reap_all] kills whatever is left. `Boot` calls it when the app closes. Portable.
## 2. The death pact (Linux, when available). A registry cannot help if the app is SIGKILLed, and ghost's own
##    quit ends in `OS.kill(OS.get_process_id())` (see main._shutdown, a workaround for an audio-driver
##    teardown crash), so no `_exit_tree` runs. `setpriv --pdeathsig KILL` sets the child's PR_SET_PDEATHSIG
##    before exec'ing the real program, so the kernel kills it when the parent dies; the pid returned is the
##    real program's.
##
## The pact is per-thread: PR_SET_PDEATHSIG fires when the parent thread exits, so a child must be started from
## a thread that lives as long as the app (the main thread). Do not call `start()` from a WorkerThreadPool task;
## use [method start_detached] there.
##
## The one deliberate exception uses [method start_detached] and says why at the call site: `assistant.gd`
## dispatches `claude -p` runs that write to the working tree and are meant to finish after the editor closes.
##
## No shell is assumed (`/bin/bash` does not exist on Windows). Two portable forms:
##   [method start_logged] - stdout+stderr into one log file, pumped by this process. Pure Godot.
##   [method start_redirected] - a working directory, stdin from a file, stdout and stderr to separate files,
##     for runs that must not hold a pipe to this process or must see stdin closed (`codex exec` waits on an
##     open one). `/bin/sh` on Linux and macOS, PowerShell on Windows.
## Free text never goes in argv: Godot's Windows command-line quoting does not escape quotes inside an
## argument, so a prompt containing `"` arrives split. Prompts travel through [method start_redirected]'s
## stdin file.

## pid -> a short label, kept only so the shutdown reap can say what it killed.
static var _tracked := {}
## Ghost is closing: [method reap_all] has run, so every child still registered was killed by us.
static var _closing := false
## Resolved once: "" not looked up yet, "-" no pact available, otherwise the setpriv path.
static var _pact := ""
## Programs already reported missing, so a per-frame caller complains once, not 60x/s.
static var _warned := {}
## pid -> {threads, exited_ms}: the reader threads behind a [method start_logged] child. [method alive] stays
## true until they have drained the pipes, so a caller reading the log once the child is gone reads all of it.
static var _pumps := {}
## Reader threads no longer tied to a live pid, joined once they finish.
static var _stray: Array[Thread] = []
## How long a finished child's readers may keep draining before [method alive] stops waiting (a grandchild
## that inherited the pipe can hold it open indefinitely).
const _DRAIN_MS := 2000
## The longest run without a line end a log pump holds back (see [method _pump]).
const _LINE_MAX := 65536

## The Windows half of [method start_redirected]. Fixed text written once per run into user://; everything
## variable arrives in a JSON spec file, so nothing the caller passes is parsed as PowerShell. Arguments are
## re-quoted with the CommandLineToArgvW rules, which Godot's own quoting skips. Output files are opened
## unbuffered and share-readable, so a caller tailing them sees each event as written.
const _PS_LAUNCHER := """param([string]$SpecPath)
$ErrorActionPreference = 'Stop'
$s = [IO.File]::ReadAllText($SpecPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
Remove-Item -LiteralPath $SpecPath -ErrorAction SilentlyContinue
function Format-Arg([string]$a) {
	if ($a.Length -gt 0 -and $a -notmatch '[\\s"]') { return $a }
	$sb = New-Object System.Text.StringBuilder
	[void]$sb.Append([char]'"')
	$bs = 0
	foreach ($c in $a.ToCharArray()) {
		if ($c -eq [char]'\\') { $bs++; continue }
		if ($c -eq [char]'"') { [void]$sb.Append([char]'\\', 2 * $bs + 1) }
		elseif ($bs -gt 0) { [void]$sb.Append([char]'\\', $bs) }
		[void]$sb.Append($c)
		$bs = 0
	}
	[void]$sb.Append([char]'\\', 2 * $bs)
	[void]$sb.Append([char]'"')
	return $sb.ToString()
}
function Open-Sink([string]$p) {
	return New-Object System.IO.FileStream($p, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite, 1)
}
$out = Open-Sink $s.out
$err = Open-Sink $s.err
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $s.program
$psi.Arguments = (@($s.args) | ForEach-Object { Format-Arg ([string]$_) }) -join ' '
if ($s.cwd) { $psi.WorkingDirectory = $s.cwd }
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
if ($s.env) { foreach ($v in $s.env.PSObject.Properties) { $psi.EnvironmentVariables[$v.Name] = [string]$v.Value } }
try { $p = [System.Diagnostics.Process]::Start($psi) } catch {
	$b = [Text.Encoding]::UTF8.GetBytes("ghost launcher: " + $_.Exception.Message + "`n")
	$err.Write($b, 0, $b.Length); $out.Close(); $err.Close(); exit 127
}
$to = $p.StandardOutput.BaseStream.CopyToAsync($out)
$te = $p.StandardError.BaseStream.CopyToAsync($err)
if ($s.stdin) {
	$in = [IO.File]::OpenRead($s.stdin)
	try { $in.CopyTo($p.StandardInput.BaseStream) } catch {}
	$in.Close()
}
try { $p.StandardInput.Close() } catch {}
$p.WaitForExit()
try { [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($to, $te)) } catch {}
$out.Close(); $err.Close()
exit $p.ExitCode
"""

## The Unix half: `cd`, export the `env` entries (their count, then each `NAME=value`), then exec with the
## redirects, so the pid the caller holds is the program's (and a `setpriv` pact on the shell carries over).
## Every value is a positional parameter; nothing is interpolated into the script.
const _SH_LAUNCHER := "cd \"$1\" || exit 1; in=\"$2\"; out=\"$3\"; err=\"$4\"; n=\"$5\"; shift 5; " \
	+ "while [ \"$n\" -gt 0 ]; do export \"$1\"; shift; n=$((n - 1)); done; " \
	+ "exec \"$@\" < \"$in\" > \"$out\" 2> \"$err\""


## Start `path` with `args`, bound to this process, and return its pid (<= 0 on failure).
## `tag` is a human label for the shutdown log and the echo; it defaults to the program's name.
##
## What the child says lands in the app's log, line by line, as `[tag] line` (stderr through printerr), so it
## reaches the console (`>_`) and the feedback record even where no terminal exists. The child's stdin is a
## pipe nobody writes, as in [method start_logged].
static func start(path: String, args: PackedStringArray, tag := "") -> int:
	_sweep_pumps()
	var info := start_with_pipe(path, args, tag)
	if info.is_empty():
		return -1
	return _attach_pumps(info, null, "[%s] " % (tag if tag != "" else path.get_file()))


## The words that give a Godot child of this project a log file of its own - `--log-file user://logs/<name>.log`
## - to go before its `--`. Without them it opens user://logs/godot.log, and Godot opens its log truncated, so a
## running session's lines survive only in the rotated copy. What the child prints still reaches the app's log
## through [method start].
static func own_log(name: String) -> PackedStringArray:
	return PackedStringArray(["--log-file", ProjectSettings.globalize_path("user://logs/%s.log" % name)])


## Start `path` with `args` and keep a pipe to its stdio - the `OS.execute_with_pipe` form, bound and registered
## like [method start]. Returns that call's Dictionary, empty on failure. The returned pid and pipe are the real
## program's (`setpriv` execs).
static func start_with_pipe(path: String, args: PackedStringArray, tag := "") -> Dictionary:
	var prog := _program(path)
	if prog.is_empty():
		return {}
	var bin := _pact_bin()
	var info := {}
	if bin == "-":
		info = OS.execute_with_pipe(prog, args)
	else:
		var full := PackedStringArray(["--pdeathsig", "KILL", "--", prog])
		full.append_array(args)
		info = OS.execute_with_pipe(bin, full)
	var pid := int(info.get("pid", -1))
	if pid > 0:
		_tracked[pid] = tag if tag != "" else path.get_file()
	return info


## The words that bind a program a wrapper starts (xvfb-run, say) to that wrapper: run `pact_prefix() +
## [program, args...]` where the wrapper would run `[program, args...]`. A pact does not pass to a child's own
## children, so stopping the wrapper would otherwise leave what it started running. Empty where no pact exists.
static func pact_prefix() -> PackedStringArray:
	var bin := _pact_bin()
	return PackedStringArray() if bin == "-" else PackedStringArray([bin, "--pdeathsig", "KILL", "--"])


## Start a program that is supposed to outlive the app. Not tracked, not bound; the call site must say why in a
## comment.
static func start_detached(path: String, args: PackedStringArray) -> int:
	var prog := _program(path)
	return OS.create_process(prog, args) if not prog.is_empty() else -1


## Start `path` with `args`, stdout and stderr both written to `log_path` (truncated first),
## bound and registered like [method start]. Returns the pid, <= 0 on failure.
##
## One reader thread per stream, since a single blocking reader deadlocks when the child fills the pipe it is
## not reading. Both append to the log under one lock and flush per chunk, so a caller tailing the file each
## frame sees it live. The child's stdin is a pipe this process never writes: fine for uv, yt-dlp, python and a
## headless Godot, wrong for anything that reads stdin (use [method start_redirected]).
static func start_logged(path: String, args: PackedStringArray, log_path: String, tag := "") -> int:
	_sweep_pumps()
	var info := start_with_pipe(path, args, tag)
	if info.is_empty():
		return -1
	# A log that cannot be opened is still drained: an unread pipe stalls the child.
	return _attach_pumps(info, FileAccess.open(log_path, FileAccess.WRITE), "")


# One reader thread per stream of a [method start_with_pipe] child: into `sink` when there is
# one, otherwise echoed into the app's log behind `echo`. Returns the child's pid.
static func _attach_pumps(info: Dictionary, sink: FileAccess, echo: String) -> int:
	var lock := Mutex.new()
	var threads: Array[Thread] = []
	for key in ["stdio", "stderr"]:
		var pipe: FileAccess = info.get(key)
		if pipe == null:
			continue
		var t := Thread.new()
		t.start(_pump.bind(pipe, sink, lock, echo, key == "stderr"))
		threads.append(t)
	var pid := int(info.get("pid", -1))
	_pumps[pid] = {"threads": threads, "exited_ms": 0}
	return pid


## Start `path` with `args` with its stdio wired to files. `io` keys, all optional:
##   cwd   - working directory ("" keeps this process's)
##   stdin - a file whose bytes are the child's whole stdin ("" = empty, closed at once)
##   out, err - where stdout and stderr go; must be two different files
##   env   - `{NAME: value}` set for this child alone, over what it inherits from this process
## Registered and bound like [method start]; with `detached` true it is neither, exactly as
## [method start_detached]. Returns the pid, <= 0 on failure.
##
## On Linux and macOS the pid is the program's own (`sh` execs it). On Windows it is the
## PowerShell launcher's, which lives exactly as long as the program and is stopped with
## its whole tree by [method terminate].
static func start_redirected(path: String, args: PackedStringArray, io: Dictionary,
		tag := "", detached := false) -> int:
	var prog := _program(path)
	if prog.is_empty():
		return -1
	var out := String(io.get("out", ""))
	var err := String(io.get("err", ""))
	if out.is_empty() or err.is_empty() or out == err:
		push_error("Subprocess.start_redirected: `out` and `err` must be two different files")
		return -1
	var env: Dictionary = io.get("env", {})
	var shell := ""
	var full := PackedStringArray()
	if _is_windows():
		shell = _powershell()
		var spec := _write_ps_spec({"program": prog, "args": Array(args),
			"cwd": String(io.get("cwd", "")), "stdin": String(io.get("stdin", "")),
			"out": out, "err": err, "env": env})
		if shell.is_empty() or spec.is_empty():
			return -1
		full = PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
			"-File", _ps_launcher_path(), spec])
	else:
		shell = "/bin/sh"
		var cwd := String(io.get("cwd", ""))
		var stdin := String(io.get("stdin", ""))
		full = PackedStringArray(["-c", _SH_LAUNCHER, "sh",
			cwd if not cwd.is_empty() else ".",
			stdin if not stdin.is_empty() else "/dev/null", out, err, str(env.size())])
		for k in env:
			full.append("%s=%s" % [String(k), String(env[k])])
		full.append(prog)
		full.append_array(args)
	if detached:
		return start_detached(shell, full)
	return start(shell, full, tag if tag != "" else path.get_file())


## Kill `pid`, and on Windows its whole process tree (a [method start_redirected] child sits under a PowerShell
## launcher). Not registry-checked: [method stop] is the guarded form, this is for pids the caller owns outright
## (a detached assistant run).
static func terminate(pid: int) -> void:
	if pid <= 0:
		return
	if _is_windows():
		var tk := OS.get_environment("SystemRoot").path_join("System32/taskkill.exe")
		if FileAccess.file_exists(tk) and OS.execute(tk, ["/PID", str(pid), "/T", "/F"]) == 0:
			return
	OS.kill(pid)


## Every child goes through [Deps] first, so a bare "ffmpeg" becomes an absolute path (a GUI-launched app does
## not inherit a shell's PATH). Returns "" and says why, once, when the program is not there at all. A program
## ghost downloads itself is asked for on the way out, so the next attempt finds it.
static func _program(path: String) -> String:
	# Nothing starts where nothing can (next/notes.md, "Platforms"): a phone executes no program ghost could fetch,
	# so a component that forgot to declare `subprocess` still launches nothing.
	var impossible := Capabilities.impossible("subprocess")
	if not impossible.is_empty():
		if not _warned.has(path):
			_warned[path] = true
			push_warning("ghost: cannot start '%s' - %s" % [path, impossible])
		return ""
	var bin := Deps.resolve(path)
	if not bin.is_empty():
		return bin
	var key := Deps.fetched_key(path)
	if not key.is_empty():
		Provision.ensure(key)
	if not _warned.has(path):
		_warned[path] = true
		var why := Deps.hint(key) if not key.is_empty() else \
			"not installed (or not on PATH) - see the Environment panel (the ⚙ in the bottom-right row)"
		push_warning("ghost: cannot start '%s' - %s" % [path, why])
		printerr("ghost: cannot start '%s' - %s" % [path, why])
	return bin


## The registry is the authority on whether a pid is ours to ask about: [method alive] and [method stop] check
## it before they touch the OS. `Boot` reaps the registry, then the tree tears down and an owning autoload's
## `_exit_tree` stops its pid a second time, and `OS.is_process_running` on a child Godot already reaped
## is a `waitpid` that fails with ECHILD, reported as an engine error. A pid in `_tracked` is one we started and
## have not stopped, reaped or seen exit; anything else answers from the registry alone. `kill()` on a tracked
## child that has exited is harmless (a signal, not a wait), so `stop` needs no liveness question.

## Is this child of ours still running? Forgets it once it is not, so the registry stays tight and a shutdown
## reap never signals a recycled pid. A pid we did not start or already forgot, including a `start_detached`
## child, is not alive as far as this registry is concerned.
static func alive(pid: int) -> bool:
	if pid <= 0 or not _tracked.has(pid):
		return false
	if OS.is_process_running(pid) or _draining(pid):
		return true
	_tracked.erase(pid)
	return false


## True once ghost is closing and [method reap_all] has killed its children. Whoever watches a child asks this
## before concluding anything from the child being gone: the tree lives one more frame after the reap
## (main._shutdown waits for it so the `_exit_tree` saves run), and a child ghost stopped has not failed.
static func closing() -> bool:
	return _closing


## Kill one child now and forget it. Returns whether it signaled anything, so a second stop is a visible
## no-op rather than an error in the log.
static func stop(pid: int) -> bool:
	if pid <= 0 or not _tracked.has(pid):
		return false
	terminate(pid)
	_tracked.erase(pid)
	_release_pumps(pid)
	return true


## Forget a pid without killing it, for a child deliberately handed off. Rare.
static func forget(pid: int) -> void:
	_tracked.erase(pid)


## Kill every child still registered. Called from `Boot` when the app closes; safe to call more than once.
## It does not call `OS.is_process_running` first: at shutdown Godot reaps its own children on another path, and
## a same-frame call races that reap into ECHILD (the crash-on-close `assistant.gd` documents). `kill()` on an
## already-dead child is harmless. It returns once the killed children's log readers have finished
## ([method _await_pumps]).
static func reap_all() -> int:
	_closing = true
	var n := 0
	for pid in _tracked.keys():
		if int(pid) > 0:
			terminate(int(pid))
			n += 1
	if n > 0:
		print("ghost: stopped %d background process(es) on exit: %s"
			% [n, ", ".join(PackedStringArray(_tracked.values()))])
	_tracked.clear()
	for pid in _pumps.keys():
		_release_pumps(int(pid))
	_await_pumps()
	return n


## How many children are currently registered - for status lines and gates.
static func tracked() -> int:
	return _tracked.size()


# One stream of a child, copied into its log (or echoed into the app's) until EOF. A blocking read returns
# whatever is available, and nothing only at EOF or when a signal interrupts it, so one empty read is not
# believed until it repeats.
##
## Whole lines only. Both streams share one log and a read takes whatever is in the pipe, so a chunk ending
## mid-line could be spliced with the other stream's chunk. The part after the last line end is held back until
## the line is finished. A carriage return ends a line too (yt-dlp rewrites its progress line with `\r`), and a
## "line" grown past [constant _LINE_MAX] goes out as it is.
static func _pump(pipe: FileAccess, sink: FileAccess, lock: Mutex, echo: String, err: bool) -> void:
	var empty := 0
	var held := PackedByteArray()          # the unfinished line, waiting for its end
	while empty < 3:
		var chunk := pipe.get_buffer(4096)
		if chunk.is_empty():
			empty += 1
			OS.delay_msec(20)
			continue
		empty = 0
		held.append_array(chunk)
		var cut := maxi(held.rfind(10), held.rfind(13))      # the last \n or \r
		if cut < 0 and held.size() < _LINE_MAX:
			continue
		var whole := held if cut < 0 else held.slice(0, cut + 1)
		held = PackedByteArray() if cut < 0 else held.slice(cut + 1)
		_store(sink, lock, whole, echo, err)
	_store(sink, lock, held, echo, err)     # what was left when the stream ended


static func _store(sink: FileAccess, lock: Mutex, bytes: PackedByteArray, echo: String, err: bool) -> void:
	if bytes.is_empty():
		return
	if sink == null:
		if not echo.is_empty():
			_echo(bytes, echo, err)
		return
	lock.lock()
	sink.store_buffer(bytes)
	sink.flush()
	lock.unlock()


# Whole lines into the app's log, one print each (one write each, so the two streams cannot splice). A line
# rewritten in place with `\r` is a line of its own here.
static func _echo(bytes: PackedByteArray, echo: String, err: bool) -> void:
	var lines := bytes.get_string_from_utf8().replace("\r\n", "\n").replace("\r", "\n").split("\n")
	if lines.size() > 1 and lines[-1].is_empty():
		lines.resize(lines.size() - 1)     # the end of the last line, not a line
	for line in lines:
		if err:
			printerr(echo + line)
		else:
			print(echo + line)


# Is an exited child's output still on its way into the log? Gives up after _DRAIN_MS.
static func _draining(pid: int) -> bool:
	if not _pumps.has(pid):
		return false
	var rec: Dictionary = _pumps[pid]
	var busy := false
	for t in rec.threads:
		busy = busy or (t as Thread).is_alive()
	if busy:
		var now := Time.get_ticks_msec()
		if int(rec.exited_ms) == 0:
			rec.exited_ms = now
		if now - int(rec.exited_ms) < _DRAIN_MS:
			return true
	_release_pumps(pid)
	return false


# Let go of the readers of children nobody asks after any more (a caller may start one and never
# call [method alive] again); a finished reader has drained its pipe, so nothing is lost.
static func _sweep_pumps() -> void:
	for pid in _pumps.keys():
		var done := true
		for t in _pumps[pid].threads:
			done = done and not (t as Thread).is_alive()
		if done:
			_release_pumps(int(pid))
	_join_finished_pumps()


static func _release_pumps(pid: int) -> void:
	if _pumps.has(pid):
		_stray.append_array(_pumps[pid].threads)
		_pumps.erase(pid)
	_join_finished_pumps()


static func _join_finished_pumps() -> void:
	for t in _stray.duplicate():
		if not t.is_alive():
			t.wait_to_finish()
			_stray.erase(t)


# The readers finish before the script does. A killed child's pipe ends at once, but its reader notices only
# after a few empty reads (about 60 ms) and then calls back into this script; a closing engine clears every
# script's functions under a thread still running. So the close waits for them, up to [constant _DRAIN_MS]; a
# grandchild holding a pipe open is left reading.
static func _await_pumps() -> void:
	var until := Time.get_ticks_msec() + _DRAIN_MS
	while Time.get_ticks_msec() < until and _stray.any(func(t: Thread) -> bool: return t.is_alive()):
		OS.delay_msec(10)
	_join_finished_pumps()


static func _is_windows() -> bool:
	return OS.get_name() == "Windows"


# By absolute path under SystemRoot first: it ships with every Windows since 7, and a stripped PATH should not
# decide whether the assistant can start.
static func _powershell() -> String:
	var p := OS.get_environment("SystemRoot").path_join(
		"System32/WindowsPowerShell/v1.0/powershell.exe")
	if FileAccess.file_exists(p):
		return p
	var bin := Deps.resolve("powershell")
	if bin.is_empty():
		push_warning("ghost: PowerShell not found - programs that need their output "
			+ "redirected (the assistant, illustrations) cannot start")
	return bin


static func _ps_launcher_path() -> String:
	var path := OS.get_user_data_dir().path_join("launch/redirect.ps1")
	if FileAccess.get_file_as_string(path) != _PS_LAUNCHER:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(_PS_LAUNCHER)
			f.close()
	return path


# One spec per launch; the launcher deletes it once read.
static func _write_ps_spec(spec: Dictionary) -> String:
	var dir := OS.get_user_data_dir().path_join("launch")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("%d_%d.json" % [Time.get_ticks_usec(), randi()])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(spec))
	f.close()
	return path


# The `setpriv` binary if it can bind a child to us, "-" if it cannot; resolved once per run. `--pdeathsig` needs
# util-linux 2.33 and an older setpriv rejects it, which would stop every child starting, so the flag is
# exercised on `true` first.
static func _pact_bin() -> String:
	if _pact != "":
		return _pact
	_pact = "-"
	if OS.get_name() != "Linux":
		return _pact          # PR_SET_PDEATHSIG is a Linux facility; elsewhere the registry stands alone
	var bin := Deps.resolve("setpriv")
	if bin.is_empty():
		push_warning("ghost: setpriv not found - background programs will only be stopped on a "
			+ "clean quit, not if ghost is killed outright")
		return _pact
	if OS.execute(bin, ["--pdeathsig", "KILL", "--", "true"]) == 0:
		_pact = bin
	return _pact

# Running only the gates whose inputs changed

`scripts/check.sh` skips a gate while nothing it read has changed since it passed. "What it read" is what the gate's
processes actually opened, stat'ed, listed and looked for, never what its source seems to name.

## Status

- Built: every gate runs under strace; a pass keeps a record in `dist/gate_cache/` (`scripts/gate_cache.py`), and a run
  leaves out each gate whose record still holds. `--full` runs them anyway. ghost.cfg is kept by the keys each gate's
  Settings read (`GHOST_SETTINGS_READS`). `gate_cache` is the cache's control (`gate_cache.py --selftest`).
- Measured: tracing costs about a second of engine boot per gate (a 1.8 s gate takes 2.9 s). A traced full run (233
  headless gates, two at a time) is 87 min of gates in 46 min. Not yet measured: what a run after an edit takes (the
  records' inputs and `.times` give it per changed file). The GPU gates have not run traced yet.
- For the user: whether a gate is ever cached wrongly. A `--full` run now and then is the check; CI is always one.
- Open: `settings_check` writes the author's ghost.cfg (persistence is what it holds) and puts it back at the end; a
  gate beside it under `--jobs` reads its values in between. The cache refuses such a pass ("changed during the run"),
  but the gate itself ran on them.

## What a gate depends on (measured)

- **Every gate compiles the autoloads and everything they name.** An empty `--script` read 126 of the 431 scripts in
  `src/` - exactly the static closure of Settings, Boot, Spectrum, Director and Provisioner. GDScript compiles every class
  a loaded script names, whether or not that code runs. This is the floor: an edit to any of those 126 reruns every gate,
  and 23% of git's edits to `src/` land there.
- **docs.py's graph (`_references`) is right where code names a class, and blind elsewhere.** With the autoloads, it
  matched the trace exactly for `voice_readers_check` (127 scripts) and `tables_check` (230), and missed 303 of 430 for
  `timeline_kit_check`, which walks `res://src` itself. It never sees the other inputs: `tables_check` read two rules files
  and ten shaders, `voice_readers_check` a data JSON. So the key is a trace, never a static graph.
- **Godot's verbose log is no trace:** it names 9 resources for `timeline_kit_check`, which read 438 files.
- **Every gate reads the author's ghost.cfg** (read-only), and the app rewrites it with nearly any use. Kept whole, it
  would rerun every gate after the app was touched; `voice_readers_check` reads 14 of its keys.

## How it works

1. **Trace.** `strace -ff -y --seccomp-bpf` with only the file calls (`gate_cache.CALLS`) wraps each gate's command,
   OUTSIDE its timeout: with `-o` strace holds fatal signals, so a timeout signalling strace would never end the gate.
2. **Inputs.** In the repo and user:// (the fetched environments live there): each file opened to read, stat'ed or run;
   each folder listed; each path looked for and not found. What the gate wrote is its own, and so is everything under a
   folder it made, moved or removed, and the listing of a folder it wrote into. Left out: `dist/`, `.git/`, the engine's
   and Python's caches, user:// logs, the recovery lock, and the boot probe runner's `tests/_probe_<pid>.tscn`.
3. **Record.** A content hash per file, the names the gate saw per listing (strace prints them, so parallel probes
   writing into `tests/` change nothing), what was absent, each ghost.cfg key read with its value, and the meta: Godot's
   version and binary, the gate's run line (with the driver for a GPU gate), the locale, and the hash of check.sh and
   gate_cache.py. A pass is kept only if no file it read changed after it started; a failure deletes it.
4. **Check.** One pass over every record at the start of a run (hashes remembered by device, inode, size, mtime and ctime).
   When `parse` runs, the gates found cached are checked again after it: it rewrites the `.godot/` caches they read
   (byte for byte the same when nothing changed, which is measured).

A gate that connects off this machine is never kept. A flaky gate stays cached after one pass until something it reads
changes.

## What to expect

- **Run again after a fix: only the gates that read the fixed file.** `--for` compares with the last commit, so on long
  work it repeats every gate that already passed since; the cache does not.
- **A one-file edit to `src/`,** weighted by where git's edits land: about 38% of the suite's time reruns, against 61% for
  `--for`'s folder rule (estimated from the static graph).
- **The floor drops as the autoloads name less:** every script they pull in is read by every gate.
- **An edit to check.sh or gate_cache.py reruns everything** (they are in every record's meta).

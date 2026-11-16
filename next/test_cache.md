# Running only the gates whose inputs changed

The question: can a gate be skipped when nothing it depends on has changed since it last passed? Yes, safely, if "depends
on" means what the gate actually read, not what its source seems to name.

## Status

- Built: nothing. `check.sh --for` already narrows by folder (against the last commit), and `.times` orders the run.
- Looked at: docs.py's static reference graph, Godot's own load log, and a file-read trace of four runs (a throwaway
  LD_PRELOAD shim, kept out of the repo).
- For the user: whether to take strace as a test-only system tool, and whether CI stays uncached.

259 gates; their last passing times add up to 104 minutes. The 11 over 100 s are 55% of that (`table_place_check` alone 15).

## What a gate depends on (measured)

- **Every gate compiles the autoloads and everything they name.** An empty `--script` read 126 of the 431 scripts in
  `src/` - exactly the static closure of Settings, Boot, Spectrum, Director and Provisioner. GDScript compiles every class
  a loaded script names, whether or not that code runs. This is the floor: an edit to any of those 126 reruns every gate,
  and 23% of git's edits to `src/` land there.
- **docs.py's graph (`_references`) is right where code names a class, and blind elsewhere.** With the autoloads, it
  matched the trace exactly for `voice_readers_check` (127 scripts) and `tables_check` (230), and missed 303 of 430 for
  `timeline_kit_check`, which walks `res://src` itself. It never sees the other inputs: `tables_check` read two rules files
  and ten shaders, `voice_readers_check` a data JSON. A scene picked by key, a script named by path in a registry row, a
  `.tscn`, a Python host - the same.
- **Godot's verbose log is no trace:** it names 9 resources for `timeline_kit_check`, which read 438 files.

So an AST pass is not enough. A key that misses an input skips a gate that should run, which is worse than no cache. The
inputs are what the process read, and a process can be watched.

## The design

1. **Trace each gate's run:** every file its process tree opened (failed opens too - a file that appears later counts),
   every directory it listed, every program it spawned. What it wrote is not an input.
2. **On a pass, keep a record** in `$OUT/.passed/<gate>`: a content hash per file read and per directory listing, Godot's
   `--version`, the gate's run line and the env check.sh sets, and for a GPU gate the driver version. A failure is never kept.
3. **Next run, rehash the record.** All equal: print `cached` and skip. Anything differs: run it traced, replace the record.
4. **`--fresh`** ignores the records. `--for` composes with it unchanged.

This is how tracing build tools cache (fabricate, tup): a deterministic program given the same bytes does the same thing.
The gates are already held to that - pinned seeds, no timing the machine (`tests/work_clock.gd`).

## The problems

- **The tracer.** strace (`-f`, opens, execs, directory reads, `--seccomp-bpf` so only those stop) is not installed: one
  Arch package, 1.7 MB. An LD_PRELOAD shim also works, but can miss a statically linked child. Without a tracer, check.sh
  runs every gate as it does now. The overhead is unmeasured: time one long gate both ways first.
- **Inputs outside the repo.** Hash what a gate reads in the repo, `user://` and the `Deps` folder (the venvs); skip
  `/usr`, `/sys`, `/proc`, `/dev` and the gate's own scratch.
- **`.godot/`.** Every gate reads the class and UID caches, which `parse` rewrites. Verify a rescan with nothing changed
  writes them byte for byte; if not, hash a sorted form. `.godot/imported/` is hashed like any file: it is what a gate sees.
- **A file edited mid-run** (dispatched runs share this tree): keep a pass only if nothing it read changed after it started.
- **Flaky gates** stay cached after one pass until something they read changes. `--fresh` and CI find them.
- **The network:** a gate that opens a socket is never cached (the trace sees `connect`).
- **The cache is two-sided like any gate:** edit a file a gate read and it runs; edit one it didn't and it is cached; add
  a file to a directory it listed and it runs.

## What to expect

- **Run again after a fix: only the gates that read the fixed file.** The largest win, since `--for` compares with the
  last commit and so repeats, on long work, every gate that already passed since.
- **A one-file edit to `src/`,** weighted by where git's edits land: about 38% of the suite's time reruns, against 61% for
  `--for`'s folder rule (from the static graph, which agrees with the trace except for gates that walk the source).
- **The floor drops as the autoloads name less:** every script they pull in is read by all 259 gates, and compiled by each.
- CI stays fresh, since proving a clean checkout is its job; it could carry `.passed` the way it carries `.times`.

## The build

A tracer around `run_gate`'s command and a record written in `settle` (check.sh), a small `scripts/gate_cache.py` that
turns a trace into a record and checks one, and the two-sided gate above. No gate changes.

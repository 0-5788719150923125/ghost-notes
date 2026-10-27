# Supply chain: what reaches users, and what a helper may touch

Researched and decided 2026-10-26. Nothing is built: "We're going to wait a bit before execution."
The user's fear, which started it: "my biggest fear is accidentally hitting hundreds or thousands of
users with a bad dependency update, and compromising them all."

## Decided

- **The bleeding edge stays.** No pins and no lockfiles: "Pinning to versions is a nightmare, because
  it forces me to be current with the project, which I do not have capacity for. We run on the
  bleeding edge intentionally. Praxis and other projects are exactly the same way ... it ensures we
  fail fast, fail early, and fail often."
- **An update delay.** "A lot of compromised packages will be found within the first few days, maybe
  a week, maybe two. We very likely don't need updates on the exact day they're released. Just soon
  after." (Step 1.)
- **A sandbox, on by default.** "Try it by default, and prompt the user if it fails. Allow the user to
  bypass the sandbox, but only explicitly. Only prompt them once, but provide a checkbox to toggle in
  the environment panel." (Steps 2 to 4.)
- **Not everything can be sandboxed**: "certain components cannot be sandboxed reliably. The AI
  agents, for example, are external programs." (What stays outside.)
- **No signing for now**: "We're going to just trust that the CI builds are safe. We're not at a scale
  for signing yet." `AppUpdate` is unchanged.
- **Not Docker** (Not taken, below).

## A delay is not a pin

The first draft tied the cooldown to lockfiles; it does not need them. uv's `--exclude-newer "7 days"`
on the same floating install takes the newest release that is at least a week old (checked on ghost's
own uv 0.13.5, 2026-10-26). There is no lock and nothing to keep current: every environment still
moves every day, a week behind the edge, and fail fast still holds, a week later. uv never picks a
yanked release either, so a bad one pulled within the week is never taken.

## What ghost does today (read from the code, 2026-10-26)

- Requirements files list floors only. The daily pass (`Provisioner._update_all`, `[deps] auto_update`,
  on by default) runs `uv pip install --upgrade` on every installed environment: about 130 packages on
  the dev machine move to whatever PyPI holds that day.
- Every fetched program (`Deps.FETCHED`) is upstream's newest, checked against a SHA-256 from the same
  upstream: that catches a broken download, not a compromised release. uv installs Python and every
  environment, so it sits under all of them.
- `--no-build` already stops a source package's `setup.py` from running at install. A wheel's `.pth`
  file still runs at every interpreter start - the LiteLLM 1.82.8 payload (March 2026) and the June
  2026 Shai-Hulud packages on PyPI both worked that way - and the environment job's own check
  (`python -c "import ..."`, `_env_job`) starts the interpreter right after the install.
- Every helper runs as the user, with the whole home folder: SSH keys, browser profiles, the `claude`
  and `codex` logins, and ghost's own YouTube tokens (`user://youtube/token.json`, `channels/`). Only
  Proof's computed code is sandboxed (`hosts/compute/run.py`, bwrap).

## Step 1 - The update delay

- **One number**, `SETTLE_DAYS` (7), in `Provision`: anything ghost takes from upstream must be at least
  that old, on a first install and on an update alike.
- **Python packages**: every `uv pip install` takes `--exclude-newer "<SETTLE_DAYS> days"`. The floors
  stay floors.
- **Fetched programs**: `Provisioner._release` picks the newest release at least that old - PyPI's upload
  times (uv), GitHub's `published_at` (TinyTeX, FFmpeg on Windows, Lean), Mathlib's releases
  (`pick_mathlib`). GitHub's `/releases/latest` gives only the newest, so read `/releases` instead.
  Riedl's FFmpeg is a "latest" redirect: find out whether Riedl lists older builds with dates. If it does
  not, an update waits until the newest is old enough (its `Last-Modified`), and a first install takes
  it as it is.
- **Python follows uv**: uv carries the list of Python builds it installs, so a delayed uv means a
  delayed Python.
- **A floor never names a release younger than the delay**, or the install fails until it is old enough.
  Each requirements file's header says so.
- **The environments already built** - measured, uv 0.13.5: `uv pip install --upgrade --exclude-newer`
  KEEPS an installed version newer than the cutoff ("Checked 1 package"), and only `--reinstall` moves
  it back. So the delay goes into `Provision.env_digest`, and a changed stamp rebuilds the environment
  (`uv venv --clear`, mostly from uv's cache) instead of upgrading it: each environment is rebuilt once,
  when the delay lands.
- **The dev machine takes the same delay.** It holds the GitHub login that publishes to every user, so
  it is the last machine that should take a release on its first day.
- **Not delayed**: data fetched at run time (Piper's voices from `resolve/main`, nltk's data,
  kaikki.org). Data is the sandbox's concern (Step 5).

Status: not started.

## Step 2 - A sandbox for every helper (Linux)

- **A helper** is any program ghost starts for its own work: the Python hosts, FFmpeg, TeX, Lean and
  Lake, yt-dlp with Deno, and Playwright's Chromium.
- **A row per helper** says what it may touch: network, graphics card, what it reads and where it
  writes - a `sandbox` field on the `Deps` rows, or a registry of its own. The paths a caller hands a run
  (the clip, an actor's folder read in place) join the row's.
- **Started through `Subprocess`**, as the death pact is: covered by default, not only if someone
  remembers.
- **What it keeps out**: the home folder, and ghost's own secrets in user:// (`youtube/`, the agent
  tools' token, other notes). Both mechanisms below allow only what is listed, so user:// is closed
  except for the helper's own environment, models and output folder.
- **bwrap first**: `run.py`'s `sandbox_argv`, made general - no home folder, `--unshare-net` for a
  helper that works offline, `/dev/nvidia*` and `/dev/dri` bound for one on the graphics card, its
  environment and models read-only, and its own folders writable.
- **Landlock where bwrap fails**: Ubuntu 23.10 and later restrict unprivileged user namespaces through
  AppArmor - test a stock Ubuntu 24.04. Landlock needs no namespaces and no setuid (kernel 5.13 and later;
  TCP rules from 6.7; this machine lists it in `/sys/kernel/security/lsm`). A process restricts itself
  and everything it starts, so the launcher restricts BEFORE `site.py` reads any `.pth`: `python -I -S
  enter.py <policy> <host>` turns Landlock on, then calls `site.main()`, then runs the host. For a
  program that is not Python, the launcher restricts itself and then `os.execv`s the program; Landlock
  holds across exec. About a hundred lines of ctypes, and no new package.
- **Pipes still work**: the voice host talks over stdin and stdout (`Subprocess.start_with_pipe`), which
  a sandbox keeps; no helper listens on a port.
- **The install's import check** runs inside the sandbox too.

Status: not started.

## The switch

- **`[deps] sandbox`**, on by default. A checkbox in the Environment panel, "Run helper programs in a
  sandbox" (`Settings.bind`). Its row says what the sandbox is on this machine (bubblewrap, Landlock,
  Seatbelt), or why there is none and how to get one (bwrap's `TOOLS` row already has the install
  line).
- **A self-test at an interactive launch**, on a worker: a sandboxed program that must fail to read a
  file planted outside its folders.
- **One prompt.** If the self-test fails and `[deps] sandbox_asked` is unset, one dialog over the notes
  list at launch, saying what failed, why, and how to fix it, with two choices: "Keep the sandbox on"
  (the default, and what closing the dialog means) or "Run without the sandbox". Either way
  `sandbox_asked` is set and the dialog never shows again; from then on the panel's checkbox is the
  switch.
- **Off only by the user's hand.** No code path clears the setting, and a read-only process (an export
  render, a gate) never prompts.
- **On but not working**: a helper does not start, and the feature says why and points at the panel,
  as an `unsupported` row does.
- **A sandbox that worked and then broke** (an OS update) prompts at that point if the user was never
  asked.
- **Proof's computed code keeps its own sandbox whatever the switch says**: it runs code an agent wrote.

Status: not started.

## Step 3 - macOS

The same rows, written as a Seatbelt profile (`sandbox-exec -p`), as Chrome, Claude Code and Codex
do. Apple has called it deprecated for a decade, and everyone still uses it. Untested here: there is no
Mac.

Status: not started.

## Step 4 - Windows

Until Windows has a sandbox, its self-test fails, so every Windows user sees the prompt once. Later: a
restricted token, a job object and folders opened by ACL (Codex's "unelevated" mode) keep a helper out
of the user's files; blocking the network that way needs admin rights. AppContainer is stronger, but
whether CUDA works inside one is not known. WSL2 is never a requirement. Windows has never run ghost.

Status: not started.

## Step 5 - Helpers stop fetching for themselves

The voice host fetches Piper's voices, nltk's data and kaikki.org lookups at run time. The first two
move to the Provisioner, and the lookups go through the app or get a narrow allowance, so the voice host
can run with no network at all.

Status: not started.

## Step 6 - Gates

- `sandbox_check`: a helper under the sandbox tries to read a file planted outside its folders, write
  outside them, and connect out, and each must fail. The control is the same three with the sandbox
  off, which must succeed. It is read-only: a fake home in the gate's own scratch, and the setting never
  written.
- Whether bwrap works on CI's `ubuntu-24.04` runner (AppArmor again); Landlock should.

Status: not started.

## What each helper needs

| Helper | Environment | Network | Graphics card | Writes |
|---|---|---|---|---|
| Voice (`hosts/voice`) | voice_venv | today voices, nltk, kaikki; none after Step 5 | no | its cache, the take |
| URL import (yt-dlp, Deno) | ytdlp_venv | yes | no | the clip's folder |
| Page capture (Playwright) | capture_venv | yes | no | the capture |
| Face, pose, actor survey (`hosts/face`) | face_venv | no | no | its tracks, the actor's folder |
| Speech (`hosts/speech`) | speech_venv | no | no | the transcript |
| Ink and figures (`hosts/math`) | math_venv, TeX | no | no | its output |
| Computed code (`hosts/compute`) | compute_venv | no (already) | no | its work folder (already) |
| Head, bake, fit, voice training (`hosts/avatar`, `hosts/voice_train`) | voice_train_venv | no | yes | the actor's folder |
| Mathlib workbench build (Lake, git, curl) | Lean | yes, while it builds | no | the workbench |
| Lean check | Lean | no | no | scratch |
| FFmpeg | fetched | no | no | the output |

## What stays outside

- **The AI agents** (`claude`, `codex`, `grok`): external programs with their own logins and their own
  sandboxes. What they reach of ghost is its MCP server.
- **The Assistant's `claude -p` runs**, already flagged in next/binary_export_and_steam.md.
- **Ghost itself**, and the second ghost an export renders in.
- **The machine's own tools**: `xvfb-run`, `setpriv`.
- **Maybe Chromium**: its own sandbox wants user namespaces, so it may not run inside bwrap. Landlock
  may be the fit for it; test it.

## Not taken

- **Pins and lockfiles**: the user's call (Decided).
- **Signing ghost's releases**: not at this scale.
- **Docker**, weighed first:
  - **It does not stop the mass event.** An image built from floating requirements carries the same
    bad release, and a registry is one more thing to trust.
  - **Linux**: the daemon runs as root, and the `docker` group is root on that machine. Rootless Docker
    and Podman need `newuidmap` and `/etc/subuid`, and a container on the graphics card needs the NVIDIA
    Container Toolkit: system installs, the thing ghost does not do.
  - **Windows**: it needs WSL2 - admin rights, virtualization turned on in the firmware, often a reboot.
    Docker Desktop cannot ship inside an app: each user installs it, and an organization of 250 or more
    people or $10M in revenue needs a paid seat. WSL2 also mounts `C:\` by default.
  - **macOS**: containers run in a Linux VM that gets no graphics card.
  - **Precedent**: Claude Code and Codex use bwrap and Seatbelt, not Docker.

## Open

- **Seven days or fourteen** ("maybe a week, maybe two")? Seven, as a constant rather than a setting:
  most of the attacks Woodruff reviewed were caught within a week.
- **Should `AppUpdate` wait the same delay?** Leave it as it is: CI is trusted, and ghost's own builds
  are where failing fast is the point.
- **Should Proof's computed code keep its sandbox when the switch is off?** Yes, as written above.

## Sources

- LiteLLM's `.pth` stealer, March 2026: [Simon Willison](https://simonwillison.net/2026/Mar/24/malicious-litellm/)
- The June 2026 PyPI `.pth` packages: [OSV MAL-2026-5324](https://osv.dev/vulnerability/MAL-2026-5324)
- Cooldowns: [Willison on Woodruff](https://simonwillison.net/2025/Nov/21/dependency-cooldowns), [LWN](https://lwn.net/Articles/1068692/), [Dependabot's cooldown](https://infoq.com/news/2026/07/github-dependabot-cooldown)
- Docker Desktop's terms: [docs.docker.com](https://docs.docker.com/subscription/desktop-license/)
- Codex on Windows: [OpenAI's write-up](https://openai.com/index/building-codex-windows-sandbox/), [its Windows docs](https://developers.openai.com/codex/windows)

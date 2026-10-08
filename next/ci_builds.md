# CI builds and releases

Researched 2026-10-07. Scaffolded the same day (below); the first real Actions run has not happened yet.

## Status: scaffolded 2026-10-07

- `.github/workflows/build.yml`: jobs `gatekeeping` (`scripts/check.sh`, headless), `export` (`scripts/build.sh --release --no-check linux windows`, which includes the Linux launch check; then `scripts/package_release.py`), `windows-launch` (a `windows-2022` runner unpacks the zip and runs `scripts/smoke-export.sh` on the `.exe`), `publish` (push to `main` or a manual run on `main`; `contents: write` only here; needs all three). Pull requests build and test, never publish. A manual run has a `skip_gatekeeping` input to publish past a red gatekeeping job.
- Release: tag `build-<full sha>`, title `Build <short sha>`, one-line notes, assets `ghost-notes-linux-x86_64.tar.gz`, `ghost-notes-windows-x86_64.zip`, `SHA256SUMS`, `manifest.json`. An existing tag is left alone on a rerun.
- `scripts/package_release.py` (`archive <target>`, `finalize`; honors `OUT`). `scripts/smoke-export.sh` also takes a Windows `.exe` from Git Bash (reads the engine's `--log-file`; `APPDATA` isolates the profile).
- Android (2026-10-08): `scripts/setup_android.py` fetches a minimal SDK into `build/tools/android` (command-line tools pinned by checksum, then platform-tools, build-tools 35.0.0, platform android-35; about 680 MB unpacked, no NDK/CMake/emulator), makes a debug keystore and a private Godot config; `build.sh` evals its environment for an Android target and verifies the APK's signature. Needs a JDK 17+ on the machine (not fetched). The release APK is signed with the DEBUG key until a real release key exists (`GODOT_ANDROID_KEYSTORE_RELEASE_*` override it). CI caches the SDK and, on a fixed key, the keystore so builds install over one another. Package id `eco.src.ghost`; `version/code` is not incremented (manual installs only). From scratch it took 252 s locally. NOT verified on a runner; CI cannot launch an APK (no emulator), it only checks the signature.
- Verified locally: both exports from a clean clone of HEAD (fresh import included), the Linux launch check, archive contents, checksums.
- NOT verified: anything on a GitHub runner (the gatekeeping job on a clean Ubuntu image, the Windows launch check, the publish job); the full gate suite is not known green (`cards_choose_check` was failing); the Windows `.exe` has never been run.

## Original request and agreed order

The user asked for:

- **GitHub Actions builds for Linux and Windows only for now.** macOS and mobile support will be needed later, but are outside this first CI phase.
- **A fully autonomous build:** fetch the pinned Godot editor and matching export templates as needed, with no manual template installation or other preparatory clicks on a runner.
- **Immediate GitHub Releases publication after successful builds**, using a version/tag derived from the source commit hash and attaching the binaries. Detailed release notes are not wanted now. The user may later prefer at most one release per day; defer that decision rather than designing the first pipeline around it.
- **Reusable local scripts under `scripts/`.** The same commands should work on a developer machine and in CI; workflows should invoke them with arguments instead of duplicating build logic in YAML.
- **A future in-app update path.** Determine whether the app can discover a GitHub Release, download its platform asset and replace the installed binary. The user prefers a simple app-driven flow over a persistent sidecar. On exported Godot builds, use `OS.get_executable_path().get_base_dir()` for the real installation directory and `user://` for writable downloads; `res://` is packed and cannot serve as a native executable directory.

The user then authorized implementation **in stages**: make a functional local Linux export first, and do not start GitHub Actions until that is working. The local Linux export now works. The user has since asked to stop before the remaining CI/release implementation and leave this document as a handoff for another agent.

## Current base

- `scripts/build.sh --release linux` runs project checks, obtains the pinned Godot 4.7.2 editor and templates through `scripts/setup_godot.py`, packages the Python hosts, exports Linux, then runs `scripts/smoke-export.sh` against the standalone binary. `scripts/build.sh --release --no-check linux` produces a working local export, but is not a release gate.
- `scripts/setup_godot.py` can install **Linux and Windows export templates on Linux**. Native Windows editor setup and a Windows smoke runner still need work. Godot supports command-line exports from named presets with installed templates. [Godot export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- `export_presets.cfg` has Linux, Windows and Android presets. The current release scope is Linux and Windows. Export smoke already checks bundled Python hosts, a Cards note's frontmatter and imported card fonts. More real workflows should be added only where they catch export-specific failures.
- The full `scripts/check.sh` gate currently fails at `cards_choose_check`; fix that before allowing automatic publication. A green export with `--no-check` alone must not publish.
- The official 4.7.2 Linux release template emits `focus_entered` / `tree_exited` disconnect errors when UI controls are used. Godot's [confirmed issue](https://github.com/godotengine/godot/issues/89657) and [open engine fix](https://github.com/godotengine/godot/pull/123998) trace this to callable hashing in optimized engine builds. Recheck with a fixed official template before treating it as a project signal-wiring failure or publishing a release.

## Recommended next steps

1. **Finish local validation.** Resolve the failing gate. Run a checked Linux release build and its smoke test from a clean checkout. Cross-export Windows locally with `scripts/build.sh --release windows`; then run the resulting `.exe` on a Windows machine or runner, including a clean-profile smoke check. Check that no runtime resources are missing from either PCK.
2. **Add reusable packaging scripts.** Put release staging in `scripts/`: make a Linux `tar.gz` that retains executable permissions, a Windows ZIP, a SHA-256 checksum file, and a small JSON manifest with the full source commit, Godot version, platform and asset names. Keep the existing build scripts as the source of truth; CI should pass target and mode arguments to them. Add a Windows smoke script or cross-platform smoke helper rather than embedding application checks in workflow YAML.
3. **Add Actions jobs.** On pull requests, run the checks and builds without publishing. On pushes to the chosen release branch, run the same gates, export both targets from pinned Godot/templates, upload temporary workflow artifacts, and run a Windows job that downloads and launches the `.exe` headlessly. Make release publication depend on all required jobs. Godot can cross-export Windows from Linux; a Windows runner is still useful for native validation. Keep GPU-only gates as a separately declared policy until a reliable CI renderer is available. [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax), [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
4. **Publish one immutable result per commit.** Use a tag such as `build-<full-commit-sha>` and a short title such as `Build <short-sha>`. Create the release against that exact SHA and attach both archives, checksums and manifest. A one-line body is enough; generated release notes are unnecessary. Grant `contents: write` only to the publication job; build jobs need read access. Publish only for trusted branch pushes, not pull requests. Make reruns recognize an existing tag/release without replacing published assets. `gh release create` supports an exact target commit, asset files and explicit notes. [GitHub CLI release create](https://cli.github.com/manual/gh_release_create), [token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)

The possible **one release per day** limit can be added later by changing the release trigger or selection rule. Keep the commit hash in the tag and manifest even if a daily selector is introduced. Decide then whether the chosen commit is the first or last green commit of the day; a mutable daily tag would undermine reproducibility.

## Later platforms and updates

- macOS needs its own export validation and distribution/signing decisions. Android needs signing credentials and a mobile distribution path. Add each as a new target of the same local scripts and a new validation job, rather than branching build logic inside one workflow.
- In-app update checks are feasible: query GitHub's latest published release, inspect its assets, download the appropriate archive into `user://`, verify its digest, then stage it beside the installed app. GitHub exposes release assets and `browser_download_url`; Godot has `HTTPRequest.download_file`. [GitHub release API](https://docs.github.com/en/rest/releases/releases), [release assets API](https://docs.github.com/en/rest/releases/assets), [Godot HTTPRequest](https://docs.godotengine.org/en/4.5/classes/class_httprequest.html)
- Use `OS.get_executable_path().get_base_dir()` for the installation location and keep user data in `user://`. An update may download while the app runs, but replacing a running Windows executable requires the app to exit and a small one-shot updater/launcher or installer to complete the swap. Linux can also use a staged, atomic switch after exit. Keep rollback to the prior version. This is a later feature; release archives and a manifest make it possible without committing to an updater now.

## Scope boundary

No workflow, automatic GitHub Release, updater, macOS build or mobile build is part of the current local-export work.

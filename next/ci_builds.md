# CI builds and releases

GitHub Actions builds and releases for Linux, Windows and macOS from reusable local scripts. The workflow is scaffolded;
its first real Actions run has not happened yet.

## Status: scaffolded 2026-10-07

- `.github/workflows/build.yml`: jobs `gatekeeping` (`scripts/check.sh`, headless), `export` (`scripts/build.sh --release --no-check linux windows`, which includes the Linux launch check; then `scripts/package_release.py`), `windows-launch` (a `windows-2022` runner unpacks the zip and runs `scripts/smoke-export.sh` on the `.exe`), `publish` (push to `main` or a manual run on `main`; `contents: write` only here; needs all the launch jobs). Pull requests build and test, never publish. A manual run has a `skip_gatekeeping` input to publish past a red gatekeeping job.
- Release: tag `build-<short sha>`, title `Build <short sha>`, one-line notes, assets `ghost-notes-linux-x86_64.tar.gz`, `ghost-notes-windows-x86_64.zip`, `SHA256SUMS`, `manifest.json`. An existing tag is left alone on a rerun. Only the three newest build releases and tags are retained.
- `scripts/package_release.py` (`archive <target>`, `finalize`; honors `OUT`). `scripts/smoke-export.sh` also takes a Windows `.exe` from Git Bash (reads the engine's `--log-file`; `APPDATA` isolates the profile).
- Android: `scripts/setup_android.py` fetches a minimal SDK into `build/tools/android` (command-line tools pinned by checksum, then platform-tools, build-tools 35.0.0, platform android-35; about 680 MB unpacked, no NDK/CMake/emulator), makes a debug keystore and a private Godot config; `build.sh` evals its environment for an Android target and verifies the APK's signature. It needs a JDK 17+ on the machine (not fetched). The release APK is signed with the debug key until a real release key exists (`GODOT_ANDROID_KEYSTORE_RELEASE_*` override it). CI caches the SDK and, on a fixed key, the keystore so builds install over one another. Package id `eco.src.ghost`; `version/code` is not incremented (manual installs only). From scratch it takes about 250 s locally. CI cannot launch an APK (no emulator); it only checks the signature.
- Verified locally: both desktop exports from a clean clone of HEAD (fresh import included), the Linux launch check, archive contents, checksums.
- Not verified: anything on a GitHub runner (the gatekeeping job on a clean Ubuntu image, the Windows launch check, the publish job, the Android build); the Windows `.exe` has never been run.

## macOS, and why not iOS

The goal is macOS support for drive-by users, without being able to test it on a Mac.

- **macOS: built.** Preset `macOS` (universal arm64 + x86_64, bundle id `eco.src.ghost`, category Productivity, the build's ghost as its icon from `AppIcon.PACKAGED["macos"]`, a microphone line for the voice sampler), exported on Linux like the rest: `scripts/build.sh --release macos` -> `dist/ghost-notes-macos.zip` (`Ghost Notes.app`, 67 MB zipped; the pinned template archive carries `macos.zip`). It is signed ad hoc by Godot's built-in signer (an Apple Silicon Mac runs no unsigned code) and not notarized, which takes a paid Apple Developer account and the author's credentials (Godot can notarize from Linux through rcodesign if that changes). A copy a browser downloads is refused once: System Settings > Privacy & Security > Open Anyway (the release notes and README say so).
- **CI**: the export job builds it, `package_release.py archive macos` copies the zip as-is (asset `ghost-notes-macos-universal.zip`, no raw executable), and `macos-launch` on a `macos-15` (Apple Silicon) runner verifies the signature (`codesign --verify --deep --strict`) and runs `smoke-export.sh` on the .app from an empty profile (HOME and XDG pointed at it; Perl's alarm where there is no GNU `timeout`). Publish needs it. It is free because the repository is public.
- **No in-app update on a Mac** (`AppUpdate`): the program is sealed in a signed bundle, and a quarantined download runs translocated from a read-only folder. The Environment panel says new builds are on GitHub Releases.
- **What the app already had**: `Deps` rows and PATH extras for macOS (FFmpeg, uv, TeX, Lean, Homebrew's folders), `Capabilities` counts it as a desktop, `Subprocess` runs there without the Linux death pact, the exporter warns that there is no virtual display.
- **Verified locally**: the cross-export from Linux with no warnings; the zip holds the .app with its executable bit, `_CodeSignature`, `icon.icns` and an Info.plist with the bundle id, category and microphone line.
- **Not verified**: anything on a Mac. The launch check is headless: it proves the app starts, reads a note and unpacks its hosts, never that the picture draws (Forward+ on Metal, MoltenVK on an Intel Mac), the Intel half, Gatekeeper's prompt, the Python hosts or any fetched program. If `codesign --verify --strict` rejects Godot's ad hoc seal while the launch passes, drop `--strict` before blaming the build.

**iOS: not built, and not easy.** Godot can only write an Xcode project on Linux; the `.ipa` needs Xcode on a Mac runner, and Godot's iOS export wants an App Store team id even for an unsigned build. No drive-by user can install an unsigned `.ipa`: it takes a paid developer account (TestFlight or the App Store, certificates and provisioning profiles as CI secrets) or a sideloading tool that re-signs it with the visitor's own Apple ID every seven days. What it would install is the phone build, a notes app and nothing more (iOS runs no child programs, so no agents, voices, FFmpeg or export). The icons are ready (`ios_1024*.png`, next/app_icon.md). Revisit only with a developer account.

## Gatekeeping on four cores

CI's gatekeeping run four gates at a time, but two long gates (`soundscape_check`, 122 s; `table_place_check`, 202 s) were missing from `check.sh`'s hand-kept list of slow gates, so they started last and ran alone for the final 2m50s of a 372 s run. The gates add up to about 1040 s, which is 260 s at best over four cores.

- **The longest start first, by measurement.** `check.sh` writes how long each gate took when it passed (`dist/check/.times`) and the next run starts them in that order; a gate with no time yet goes before the timed ones, longest timeout first. There is no hand list. The workflow carries `.times` between runs in a cache (a new key per run, the newest restored), so only the first run orders by timeouts alone.
- **A run says what the cores were given**: the gates added up, what that is at best over the jobs, and the longest gate alone. `scripts/check.sh --list --jobs 4` shows the order with each gate's last time.
- **What bounds it now** is the work, not the order: about 17 minutes of gates over four cores. Three gates are 41% of that (`table_place_check`, `soundscape_check`, `sand_settle_check`); making gatekeeping much shorter means making those cheaper. Not done.
- **Not verified on a runner**: the cache step and the new order have run only locally.

## Original request and agreed order

The requirements:

- **GitHub Actions builds for Linux and Windows first.** macOS and mobile come later, outside this first phase.
- **A fully autonomous build:** fetch the pinned Godot editor and matching export templates as needed, with no manual template installation or other preparatory clicks on a runner.
- **Immediate GitHub Releases publication after successful builds**, with a version/tag derived from the source commit hash and the binaries attached. Detailed release notes are not wanted. At most one release per day may be preferred later; the first pipeline is not designed around it.
- **Reusable local scripts under `scripts/`.** The same commands work on a developer machine and in CI; workflows invoke them with arguments instead of duplicating build logic in YAML.
- **A future in-app update path:** the app discovers a GitHub Release, downloads its platform asset and replaces the installed binary, in a simple app-driven flow rather than a persistent sidecar. On exported Godot builds, `OS.get_executable_path().get_base_dir()` is the real installation directory and `user://` holds writable downloads; `res://` is packed and cannot serve as a native executable directory.

The order was staged: a working local Linux export first (done), then the Actions workflow.

## Current base

- `scripts/build.sh --release linux` runs project checks, obtains the pinned Godot 4.7.2 editor and templates through `scripts/setup_godot.py`, packages the Python hosts, exports Linux, then runs `scripts/smoke-export.sh` against the standalone binary. `scripts/build.sh --release --no-check linux` produces a working local export, but is not a release gate.
- `scripts/setup_godot.py` installs Linux and Windows export templates on Linux. Native Windows editor setup is still open. Godot supports command-line exports from named presets with installed templates. [Godot export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- `export_presets.cfg` has Linux, Windows, macOS and Android presets. Export smoke checks bundled Python hosts, a table note's frontmatter and imported fonts. More real workflows are worth adding only where they catch export-specific failures.
- The full `scripts/check.sh` gate must be green before automatic publication (`tests/table_show/cards_choose_check.gd` was failing at the last check). A green export with `--no-check` alone must not publish.
- The official 4.7.2 Linux release template emits `focus_entered` / `tree_exited` disconnect errors when UI controls are used. Godot's [confirmed issue](https://github.com/godotengine/godot/issues/89657) and [open engine fix](https://github.com/godotengine/godot/pull/123998) trace this to callable hashing in optimized engine builds. Recheck with a fixed official template before treating it as a project signal-wiring failure or publishing a release.

## Recommended next steps

1. **Finish local validation.** Resolve the failing gate. Run a checked Linux release build and its smoke test from a clean checkout. Cross-export Windows locally with `scripts/build.sh --release windows`, then run the resulting `.exe` on a Windows machine or runner, including a clean-profile smoke check. Check that no runtime resources are missing from either PCK.
2. **Add reusable packaging scripts** (built: `scripts/package_release.py`). Release staging lives in `scripts/`: a Linux `tar.gz` that retains executable permissions, a Windows ZIP, a SHA-256 checksum file, and a small JSON manifest with the full source commit, Godot version, platform and asset names. The build scripts are the source of truth; CI passes target and mode arguments to them.
3. **Add Actions jobs** (scaffolded). On pull requests, run the checks and builds without publishing. On pushes to the release branch, run the same gates, export the targets from pinned Godot/templates, upload temporary workflow artifacts, and run a Windows job that downloads and launches the `.exe` headlessly. Release publication depends on all required jobs. A Windows runner is useful for native validation even though Godot can cross-export Windows from Linux. GPU-only gates stay a separately declared policy until a reliable CI renderer exists. [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax), [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
4. **Publish one immutable result per retained commit.** Tag `build-<short-commit-sha>`, title `Build <short-sha>`, created against the full SHA with the archives, checksums and manifest attached and a one-line body. `contents: write` goes only to the publication job; build jobs need read access. Only trusted branch pushes publish, never pull requests. Reruns recognize an existing tag/release without replacing published assets. The three newest build releases are retained and older tags are deleted with them. [GitHub CLI release create](https://cli.github.com/manual/gh_release_create), [token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)

A one-release-per-day limit can be added later by changing the release trigger or selection rule. The commit hash stays in the tag and manifest either way, and a mutable daily tag is avoided because it would undermine reproducibility; the open choice is whether the day's commit is the first or last green one.

## Later platforms and updates

- macOS is built (above); notarization waits on an Apple Developer account. Android needs signing credentials and a mobile distribution path. Each is a new target of the same local scripts and a new validation job, never build logic branched inside one workflow.
- Desktop updater: release exports embed `data/build_info.json` with their full commit hash. `AppUpdate` (`src/platform/app_update.gd`) in the Environment panel checks published build releases at launch and every six hours when **keep up to date** is enabled, then confirms that the release commit is ahead of the current build. It downloads a raw Linux or Windows executable into `user://updates`, verifies the manifest checksum, and stages a copy beside the running executable. On any normal exit, the downloaded executable starts headlessly as a one-shot helper, waits for the old process to close, swaps the files, and keeps the previous executable as a rollback copy. The panel shows the running build and a restart action when an update is ready. Editor, debug, dirty and mobile builds do not auto-update. [GitHub release API](https://docs.github.com/en/rest/releases/releases), [release assets API](https://docs.github.com/en/rest/releases/assets), [Godot HTTPRequest](https://docs.godotengine.org/en/4.5/classes/class_httprequest.html)

## Scope boundary

The local export, the scaffolded workflow, the updater and the macOS build exist; a mobile distribution path and any notarized or signed release do not.

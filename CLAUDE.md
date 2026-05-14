# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Core Keeper mod that disables item durability loss by Harmony-patching `PlayerEquipment.ChangeDurabilitySystem.OnUpdate` to skip the original. Built against Pugstorm's official `CoreKeeperModSDK`. Single-target, personal-use, non-commercial (Pugstorm EULA).

The lived design spec is `docs/superpowers/specs/2026-05-13-disable-durability-design.md` and the implementation history is `docs/superpowers/plans/2026-05-13-disable-durability-implementation.md`. Read those before changing scope, mod target, or build pipeline.

## Build and deploy

```bash
source .envrc           # exports UNITY_BIN, SDK_PATH, MOD_INSTALL_PATH
./scripts/build.sh      # Unity batchmode build; on Darwin auto-runs install-macos.sh
```

Unity Editor must be closed (it locks the project). The build takes ~90 s on a warm machine. `scripts/install-macos.sh` is the macOS-specific deploy step; opt out with `SKIP_MACOS_INSTALL=1`.

`scripts/link.sh` is a one-time setup step that symlinks `src/`, `src/Editor/`, and `config/` into `$SDK_PATH/Assets/DisableDurability/`. Re-run any time the repo path changes — that includes **after entering or exiting a git worktree**: the existing symlinks point at whichever path was current when link.sh last ran, so a worktree switch leaves them dangling and the next build fails with `Compilation Pipeline: Could not read file …asmdef`.

There are no automated tests. Verification is manual per spec §11; the gameplay smoke test is "load a world, mine 30 blocks with a pickaxe, durability bar stays put."

## Required external setup

- **Unity Editor `6000.0.59f2`** (exact patch version — pinned in the SDK's `ProjectVersion.txt`, not the SDK's `README.md` which is one patch behind). Add the **Linux Build Support (Mono)** and, on macOS, **Windows Build Support (Mono)** modules via Unity Hub.
- **`Pugstorm/CoreKeeperModSDK`** cloned as a sibling at `$SDK_PATH`. The wizard's "Create New Mod" + "Update Game Files" + manifest settings (`requiredOn=ClientAndServer`) must have been done once. See spec §10 for the procedure.
- **`jq`** and standard macOS userland for `scripts/install-macos.sh`. **GNU `sed`** for plan-wide edits (Homebrew on macOS).

## Architecture

Three runtime classes plus one editor helper, all in the `DisableDurability` namespace:

- **`DisableDurabilityMod` (`IMod`)** — bootstrap. The single line that matters is `BurstDisabler.DisableBurstForSystem<ChangeDurabilitySystem>()` in `Init()`. Burst-compiled `OnUpdate` methods are not patchable by Harmony; this call moves the system out of Burst so the Prefix can intercept.
- **`NoDurabilityLossPatch` (`[HarmonyPatch]`)** — `Prefix` returning `false` skips `ChangeDurabilitySystem.OnUpdate`, which also prevents its two scheduled jobs (`ChangeDurabilityOfHeldEquipmentJob`, `ReduceDurabilityOfAllEquipmentJob`) from running. `[HarmonyPriority(Priority.Last)]` is a defensive default for coexistence with other durability mods.
- **`ModConfig`** — hardcoded `enabled = true`. Looks like a config-loader but doesn't read a file: Pugstorm's RoslynCSharp sandbox blocks `System.IO` at runtime. The singleton API shape is preserved so a future loader can drop in without touching `NoDurabilityLossPatch`. See `docs/research/macos-crossover-wine-workaround.md` for the sandbox details.
- **`Editor/CLIBuildHelper`** — wraps `PugMod.ModBuilder.BuildMod(...)` for `unity -batchmode -executeMethod`. Lives in its own asmdef (`src/Editor/DisableDurability.Editor.asmdef`) because runtime+editor combined asmdefs cannot reference editor-only ones; `ModBuilder` and `ModBuilderSettings` are editor-only.

`src/` is canonical source. The SDK clone's `Assets/DisableDurability/` contains **symlinks** back to `src/` (created by `scripts/link.sh`). Edit in `src/`; the SDK picks up the change on the next refresh.

Patch target was identified by inspecting PermaBreak's source under `mod.io/.../5289/mods/3407304_4384035/Scripts/` (a production mod that does the inverse). PermaBreak's published source references a method (`PlayerController.ReduceDurabilityOfEquipment`) that no longer exists in the current game build; the working target is `PlayerEquipment.ChangeDurabilitySystem.OnUpdate` from `Pug.Other.dll`. The full reasoning is in `docs/research/permabreak-patch-target.md`.

## macOS / CrossOver — critical operational rules

Pugstorm's loader extracts `Scripts/` from locally built mods into `~/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/users/crossover/AppData/Local/Temp/Pugstorm/Core Keeper/ModLoader/<ModName>/`, and Wine's `RemoveDirectoryRecursive` on the `\\?\C:\` long-path prefix fails with an unspecified IOException. The loader then reports "compilation failed" even though no compile has run.

The workaround — implemented by `scripts/install-macos.sh` — routes the mod through mod.io's load path instead (which doesn't go through `ModLoader/`). It populates three locations:

1. `mod.io/5289/mods/9999999_1/` — extracted files (mod ID `9999999` is a fake; mod.io's real catalog never has it)
2. `<bottle>/users/crossover/AppData/Local/Temp/Pugstorm/Core Keeper/5289/9999999_1.zip` — ZIP cache the loader expects
3. `mod.io/5289/state.json` — `subscribedMods += "9999999"` plus a minimal `mods["9999999"]` stub

**Do not open the in-game Mods menu while a fake-ID mod is installed.** Opening it triggers a mod.io API sync that resolves `9999999` against the real mod.io catalog, finds it doesn't exist, and **deletes the local files and the cached ZIP**. The fix is to re-run `./scripts/build.sh` (which re-populates the three locations idempotently). Game start, world load, and gameplay do not trigger the sync; only the mod browser does.

CoreLib triggers the same Wine bug when its cache is fresh — its cache structure is deep enough to hit the failure mode reliably. If iterating with CoreLib installed and disabled, leave it in `disabledMods`; if you actually need CoreLib at runtime, beware that any cache-cleaning event can put you back in the same compilation-failed state.

The full background, including what was ruled out and upstream fix candidates, is in `docs/research/macos-crossover-wine-workaround.md`. The other research notes (`macos-sdk-steamworks-fix.md`, `permabreak-patch-target.md`) cover one-time fixes already applied; they are mostly relevant if a fresh SDK clone is set up.

## Conventions

- Commit messages: short subject, imperative, no emoji. Wrap body at ~75 chars.
- Documentation files under `docs/` are English (per the user's global instructions); chat answers are German.
- The user prefers `git commit --amend` and `git reset --soft` over fix-up commits while a change is in progress on a personal branch. For shared/pushed branches, ask first.
- The user prefers `git rebase` over `git merge` for integrating branches when there are real divergent commits. The worktree branch produced by `superpowers:using-git-worktrees` is normally fast-forwardable into `main`.
- macOS-specific: GNU `sed`/`find`/`xargs` are on `PATH` (Homebrew). `pgrep -P` and `pgrep -x` are unreliable under proctools — prefer `pgrep -f`. `eza` may shadow `ls`; use `/bin/ls` if column flags misbehave.

## When picking up work later

1. `source .envrc` — confirm UNITY_BIN, SDK_PATH, MOD_INSTALL_PATH still resolve.
2. Check `git log --oneline | head -5` and `git status` — the project is on `main` with the worktree removed; new work should create a new worktree via `superpowers:using-git-worktrees`.
3. If anything in `mod.io/5289/mods/9999999_1/` or the cached ZIP is missing (e.g. after the user opened the Mods menu), `./scripts/build.sh` restores all three locations.

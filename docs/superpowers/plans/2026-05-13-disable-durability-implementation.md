# Disable Durability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a deployable Core Keeper mod folder that prevents item durability from decrementing on use, gated by a JSON `enabled` toggle, built via the official Pugstorm `CoreKeeperModSDK` toolchain and loaded by the game's bundled mod loader.

**Architecture:** A single Harmony `Prefix` patch (target method resolved in Task 3) suppresses the durability-decrement code path. A lazy-loaded `ModConfig` singleton reads a JSON config sitting next to the mod DLL and exposes a `bool Enabled` flag. An Editor-only `CLIBuildHelper` wraps `PugMod.ModBuilder.BuildMod(...)` so the build runs from a shell via `unity -batchmode -executeMethod`.

**Tech Stack:** C# 9, Unity 6 (Editor `6000.0.58f2`), Linux Mono target, HarmonyLib (game-bundled), Pugstorm `dev.pugstorm.mod` 0.1.0, bash for build scripts. No automated test framework — verification is manual per the design spec `§11`.

**Reference spec:** `docs/superpowers/specs/2026-05-13-disable-durability-design.md` — cite by section number throughout this plan.

---

## File Structure

In `disable-durability/` (this repo):

| Path | Responsibility | Status after this plan |
|---|---|---|
| `README.md` | Mod overview, install instructions for end-users, "freeze not repair" caveat | new |
| `.envrc.example` | Committed template; users copy to `.envrc` (gitignored) and fill paths | new |
| `src/ModConfig.cs` | Lazy singleton, reads `config.json` next to DLL, defaults to `Enabled=true` | new |
| `src/NoDurabilityLossPatch.cs` | Harmony patch class with `[HarmonyPriority(Priority.Last)]` and target method resolved in Task 3 | new |
| `src/Editor/CLIBuildHelper.cs` | Editor-only static class, callable via `-executeMethod`, wraps `ModBuilder.BuildMod` | new |
| `config/config.json` | Default config bundled with built mod | new |
| `scripts/build.sh` | Validates env vars, invokes Unity batchmode, surfaces exit codes | new, executable |
| `scripts/link.sh` | Idempotently creates symlinks from SDK clone back to this repo's `src/` and `config/` | new, executable |
| `docs/research/permabreak-patch-target.md` | Findings from Task 3 — the patch target class + method, with reasoning | new |

In `CoreKeeperModSDK/Assets/Mods/DisableDurability/` (SDK clone, **not** this repo):
- `ModBuilderSettings.asset` + `.meta` — created by the PugMod SDK Window in Task 10; Unity-managed.
- `DisableDurability.asmdef` + `.meta` — created by the same workflow.
- Symlinks pointing back to our `src/` and `config/` — created by `scripts/link.sh` in Task 11.
- Unity-generated `.meta` sidecars for the symlinked files.

The SDK clone itself lives at `/Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK/`, sibling to this repo, established in Task 10. It is **its own git repo** and is never nested inside `disable-durability/`.

---

## Branch and worktree setup

Per the user's global preference (CLAUDE.md), implementation work happens in a worktree. Before starting Task 1, the executing skill creates a worktree off `main` named after the feature, e.g.:

```bash
git worktree add ../.worktrees/disable-durability-v1 -b disable-durability-v1
```

If `superpowers:using-git-worktrees` is invoked at execution time it handles this. All file paths in this plan are relative to the worktree root.

---

## Task 1: Scaffold directory structure and `.envrc.example`

**Files:**
- Create: `src/Editor/.gitkeep` (placeholder so empty dir is tracked)
- Create: `config/.gitkeep`
- Create: `scripts/.gitkeep`
- Create: `docs/research/.gitkeep`
- Create: `.envrc.example`

- [ ] **Step 1: Create the empty directories**

Run:
```bash
mkdir -p src/Editor config scripts docs/research
touch src/Editor/.gitkeep config/.gitkeep scripts/.gitkeep docs/research/.gitkeep
```

Verify: `find . -type d -name 'Editor' -o -name 'config' -o -name 'scripts' -o -name 'research' | sort` lists all four.

- [ ] **Step 2: Create `.envrc.example`**

Write `.envrc.example` with this exact content:

```bash
# Disable Durability — environment variables
#
# Copy this file to `.envrc` and fill in your machine-specific paths.
# `.envrc` is gitignored.
#
# Optional: install direnv (`brew install direnv`) so the file auto-loads
# on `cd` into this directory.

# Path to the Unity Editor binary (must be Unity 6000.0.58f2 per the SDK)
export UNITY_BIN="/Applications/Unity/Hub/Editor/6000.0.58f2/Unity.app/Contents/MacOS/Unity"

# Path to the cloned Pugstorm CoreKeeperModSDK (sibling to this repo recommended)
export SDK_PATH="/Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK"

# Mod install path inside the CrossOver Core Keeper bottle.
# StreamingAssets/Mods/ is the SDK-default destination; the builder
# creates a DisableDurability/ subfolder inside it automatically.
export MOD_INSTALL_PATH="$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/Program Files (x86)/Steam/steamapps/common/Core Keeper/CoreKeeper_Data/StreamingAssets/Mods/"
```

Verify: `head -3 .envrc.example` shows the comment header.

- [ ] **Step 3: Commit**

```bash
git add src/Editor/.gitkeep config/.gitkeep scripts/.gitkeep docs/research/.gitkeep .envrc.example
git commit -m "Scaffold source/build/config directories and envrc template"
```

---

## Task 2: Write `README.md`

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Write `README.md` (English per global CLAUDE.md rule) with this content:

```markdown
# Disable Durability — Core Keeper Mod

A small Core Keeper mod that prevents item durability from decreasing when items are used. Built on the official Pugstorm `CoreKeeperModSDK`.

## What it does

While the mod is enabled, the game skips the durability-decrement code path for items in use. The durability bar stays at whatever value the item had when the mod loaded — items at 100/100 stay full; items at 30/100 stay at 30/100.

**This is not a repair mod.** Items keep their current durability — they do not regenerate to maximum.

## Requirements

- Core Keeper (Steam, PC build)
- Pugstorm `CoreKeeperModSDK` toolchain to build (developer-side only)
- For multiplayer: the mod must be installed on both client and server.

## Install (end-user)

1. Download the latest `DisableDurability/` folder from the releases page.
2. Copy it into your Core Keeper `Mods/` directory:
   - Windows: `<Steam>/steamapps/common/Core Keeper/CoreKeeper_Data/StreamingAssets/Mods/`
   - macOS (CrossOver): same path inside the CrossOver bottle.
3. Launch Core Keeper. The mod loads automatically.

## Configuration

Edit `config.json` next to the mod DLL:

```json
{
  "enabled": true
}
```

Set `enabled` to `false` and restart the game to disable durability protection without removing the mod.

## Build (developer)

See `docs/superpowers/specs/2026-05-13-disable-durability-design.md` §10.

## License

Source code: see `LICENSE`. Distribution of compiled mod must comply with the Pugstorm Mod Tool EULA (non-commercial only).
```

Verify: `wc -l README.md` reports >30 lines.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Add README with mod overview and end-user install instructions"
```

---

## Task 3: Research — locate the durability-decrement patch target

This is the most important task. Without a correct target, the rest of the code cannot work.

**Files:**
- Create: `docs/research/permabreak-patch-target.md`

Two routes available; **try Route A first**; fall back to Route B if A is blocked.

### Route A: Inspect the PermaBreak mod (preferred)

PermaBreak is a production mod on mod.io that does the inverse of what we want (forces items to break permanently). Its Harmony patch targets the exact same method we want to neutralize, just with opposite intent.

- [ ] **Step A.1: USER ACTION — install PermaBreak via the in-game mod browser**

User opens Core Keeper, goes to the in-game Mods screen, searches "PermaBreak", installs it. The installation lands somewhere under `~/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/users/Public/mod.io/` (per the empirical observation in the design spec §10.4).

Wait for user to confirm install succeeded.

- [ ] **Step A.2: Locate the installed PermaBreak DLL**

Run:

```bash
find ~/Library/Application\ Support/CrossOver/Bottles/Core\ Keeper/drive_c/users/Public/mod.io/ \
     -iname 'PermaBreak*.dll' 2>/dev/null
```

Expected: one or more paths to a `PermaBreak.dll` (or similar). Note the full path. If multiple, prefer the one in a folder named like `<numeric-id>/install/...`.

- [ ] **Step A.3: Install ilspycmd if not present**

Run:

```bash
which ilspycmd || dotnet tool install -g ilspycmd
```

Expected: either a path to `ilspycmd` already, or installation output ending in success. If `dotnet` itself is missing, install .NET SDK via `brew install --cask dotnet-sdk` first.

- [ ] **Step A.4: Decompile PermaBreak.dll**

Run (substitute `<PERMABREAK_DLL>` with the path from Step A.2):

```bash
ilspycmd <PERMABREAK_DLL> > /tmp/permabreak-decompiled.cs
```

Expected: `/tmp/permabreak-decompiled.cs` exists, size > 1 KB.

- [ ] **Step A.5: Find the Harmony patch annotation**

Run:

```bash
grep -B1 -A3 '\[HarmonyPatch' /tmp/permabreak-decompiled.cs | head -40
```

Expected output shape:

```csharp
[HarmonyPatch(typeof(<SomeGameClass>), "<methodName>")]
internal class <PatchClassName>
{
    static void Prefix(...) // or Postfix, or Transpiler
```

Capture: the full type name in `typeof(...)` (including namespace if shown), the method name, and the patch type (Prefix/Postfix/Transpiler).

- [ ] **Step A.6: Confirm this is the durability path (not some other patch)**

If PermaBreak ships multiple patches, identify which one targets durability. Search the surrounding code for `durability`, `charges`, `Durability`, `CD` references:

```bash
grep -i 'durability\|charges' /tmp/permabreak-decompiled.cs | head -20
```

The patch class with these references is our target.

- [ ] **Step A.7: Write the research note**

Create `docs/research/permabreak-patch-target.md` with this template (fill in `<…>`):

```markdown
# Patch target — research findings (2026-05-13)

## Source
PermaBreak mod (mod.io). DLL path on this machine: `<PATH>`. Decompiled with ilspycmd.

## Target

- **Class:** `<full.namespace.ClassName>`
- **Method:** `<methodName>`
- **Patch type used by PermaBreak:** `<Prefix | Postfix | Transpiler>`

## Method signature (as decompiled)

```csharp
<paste the method signature here>
```

## Our adapted patch

We use a `Prefix` returning `false` to skip the original. This is correct iff the original method's job is to reduce durability and has no other essential side-effects. From inspection:

<short paragraph: what the original method does, what we lose by skipping it,
why that's acceptable>

## Alternatives considered
- Strategy 2 (system OnUpdate): <ruled out / kept as fallback because …>
- Strategy 3 (multiple call sites): <…>
```

- [ ] **Step A.8: Commit**

```bash
git add docs/research/permabreak-patch-target.md
git commit -m "Document Harmony patch target derived from PermaBreak inspection"
```

### Route B: AssetRipper fallback (if Route A blocked)

Only execute if Route A is not viable (PermaBreak not available, mod.io download blocked, etc.).

- [ ] **Step B.1: Install AssetRipper**

Download AssetRipper from `https://assetripper.github.io/` (the macOS build). Extract somewhere stable.

- [ ] **Step B.2: Point AssetRipper at the Core Keeper install**

Open AssetRipper, File → Open → select `<bottle>/drive_c/Program Files (x86)/Steam/steamapps/common/Core Keeper/`. Let it analyze. Export scripts to a folder.

- [ ] **Step B.3: Grep the decompiled source for durability methods**

```bash
grep -rEl 'class.*Durability|Durability.*System|ReduceDurability|DecreaseDurability' \
     <ASSETRIPPER_EXPORT>/
```

- [ ] **Step B.4: Inspect candidates and pick the lowest-level mutating method**

Look for a method that writes to a `Durability` component (DOTS pattern) or modifies a numeric field. Prefer a helper method over a system `OnUpdate` (per spec §6.2 Strategy 1).

- [ ] **Step B.5: Write the research note**

Same template as Route A, Step A.7, with the source line saying "AssetRipper export of Core Keeper <version>".

- [ ] **Step B.6: Commit**

Same as A.8.

---

## Task 4: Write `src/ModConfig.cs`

**Files:**
- Create: `src/ModConfig.cs`

- [ ] **Step 1: Write the config-loader source**

Create `src/ModConfig.cs` with this exact content:

```csharp
using System;
using System.IO;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Lazy-loaded mod configuration. Reads <c>config.json</c> from the
    /// directory containing this assembly. Falls back to defaults if the
    /// file is missing or malformed.
    /// </summary>
    [Serializable]
    internal sealed class ModConfig
    {
        // Public field (not property) because Unity's JsonUtility populates
        // fields, not properties. Default value matches the "missing file"
        // fallback — a user who installed the mod presumably wants it active.
        public bool enabled = true;

        private static ModConfig _instance;
        public static ModConfig Instance => _instance ??= Load();

        private static ModConfig Load()
        {
            var cfg = new ModConfig();
            var dllPath = typeof(ModConfig).Assembly.Location;
            var dllDir = Path.GetDirectoryName(dllPath);
            if (string.IsNullOrEmpty(dllDir)) return cfg;

            var cfgPath = Path.Combine(dllDir, "config.json");
            if (!File.Exists(cfgPath)) return cfg;

            try
            {
                var json = File.ReadAllText(cfgPath);
                var parsed = JsonUtility.FromJson<ModConfig>(json);
                if (parsed != null) cfg = parsed;
            }
            catch (Exception e)
            {
                Debug.LogWarning(
                    $"[DisableDurability] Config parse failed: {e.Message} — using defaults.");
            }
            return cfg;
        }
    }
}
```

Note: the JSON key is lowercase `enabled` to match `config/config.json` exactly. Unity's `JsonUtility` is case-sensitive.

- [ ] **Step 2: Verify file syntax**

Run:
```bash
grep -c "namespace DisableDurability" src/ModConfig.cs
```
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add src/ModConfig.cs
git commit -m "Add ModConfig — JSON config loader with defaults"
```

---

## Task 5: Write `src/NoDurabilityLossPatch.cs`

**Depends on:** Task 3 (patch target findings).

**Files:**
- Create: `src/NoDurabilityLossPatch.cs`

- [ ] **Step 1: Read the research note**

Run:
```bash
cat docs/research/permabreak-patch-target.md
```

Extract:
- **Target class** (full namespace) → put in `typeof(...)`
- **Method name** → put in second `HarmonyPatch` argument
- Verify the patch type was Prefix; if Transpiler, this task needs revision before continuing.

- [ ] **Step 2: Write the patch class**

Create `src/NoDurabilityLossPatch.cs`. Replace `<TARGET_TYPE>` and `<TARGET_METHOD>` with the values from the research note:

```csharp
using HarmonyLib;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Harmony patch that suppresses the durability-decrement code path.
    /// Target derived from PermaBreak inspection — see
    /// <c>docs/research/permabreak-patch-target.md</c>.
    /// </summary>
    [HarmonyPatch(typeof(<TARGET_TYPE>), nameof(<TARGET_TYPE>.<TARGET_METHOD>))]
    [HarmonyPriority(Priority.Last)]
    internal static class NoDurabilityLossPatch
    {
        static NoDurabilityLossPatch()
        {
            Debug.Log(
                $"[DisableDurability] Patch loaded. " +
                $"Enabled={ModConfig.Instance.enabled}");
        }

        [HarmonyPrefix]
        private static bool Prefix()
        {
            if (!ModConfig.Instance.enabled) return true;  // run original
            return false;                                   // skip original
        }
    }
}
```

If the target class name has special characters or is in a nested namespace that's not importable with a `using`, use the fully-qualified form in `typeof(...)` and adjust `nameof(...)` accordingly. If `nameof` doesn't resolve, fall back to a string literal: `[HarmonyPatch(typeof(X), "MethodName")]`.

- [ ] **Step 3: Verify file syntax**

Run:
```bash
grep -c '\[HarmonyPatch' src/NoDurabilityLossPatch.cs
grep -c '\[HarmonyPrefix' src/NoDurabilityLossPatch.cs
```
Expected: both return `1`.

- [ ] **Step 4: Commit**

```bash
git add src/NoDurabilityLossPatch.cs
git commit -m "Add Harmony Prefix patch on durability-decrement target"
```

---

## Task 6: Write `src/Editor/CLIBuildHelper.cs`

**Files:**
- Create: `src/Editor/CLIBuildHelper.cs`

- [ ] **Step 1: Write the CLI build wrapper**

Create `src/Editor/CLIBuildHelper.cs`:

```csharp
using System;
using System.IO;
using PugMod;
using UnityEditor;
using UnityEngine;

namespace DisableDurability.Editor
{
    /// <summary>
    /// Editor-only helper invoked via
    /// <c>unity -batchmode -executeMethod DisableDurability.Editor.CLIBuildHelper.Build</c>.
    /// Wraps <see cref="ModBuilder.BuildMod"/> and surfaces success/failure
    /// as the Unity process exit code (0 on success, 1 on failure).
    /// </summary>
    public static class CLIBuildHelper
    {
        private const string ModName = "DisableDurability";
        private const string SettingsPath = "Assets/Mods/" + ModName + ".asset";

        public static void Build()
        {
            try
            {
                var settings = AssetDatabase.LoadAssetAtPath<ModBuilderSettings>(SettingsPath);
                if (settings == null)
                {
                    Debug.LogError(
                        $"[CLIBuildHelper] Could not load ModBuilderSettings at {SettingsPath}");
                    EditorApplication.Exit(1);
                    return;
                }

                var exportPath = Environment.GetEnvironmentVariable("MOD_INSTALL_PATH");
                if (string.IsNullOrEmpty(exportPath))
                {
                    Debug.LogError("[CLIBuildHelper] MOD_INSTALL_PATH not set");
                    EditorApplication.Exit(1);
                    return;
                }

                Directory.CreateDirectory(exportPath);

                Debug.Log($"[CLIBuildHelper] Building {ModName} → {exportPath}");
                ModBuilder.BuildMod(settings, exportPath, ok =>
                {
                    Debug.Log($"[CLIBuildHelper] Build {(ok ? "succeeded" : "FAILED")}");
                    EditorApplication.Exit(ok ? 0 : 1);
                });
            }
            catch (Exception e)
            {
                Debug.LogError($"[CLIBuildHelper] Exception: {e}");
                EditorApplication.Exit(2);
            }
        }
    }
}
```

- [ ] **Step 2: Verify file syntax**

Run:
```bash
grep -c 'class CLIBuildHelper' src/Editor/CLIBuildHelper.cs
grep -c 'EditorApplication.Exit' src/Editor/CLIBuildHelper.cs
```
Expected: `1` and `3` respectively (success, failure, exception paths).

- [ ] **Step 3: Commit**

```bash
git add src/Editor/CLIBuildHelper.cs
git commit -m "Add CLIBuildHelper for unity batchmode invocations"
```

---

## Task 7: Write `config/config.json`

**Files:**
- Create: `config/config.json`

- [ ] **Step 1: Write the default config**

Create `config/config.json`:

```json
{
  "enabled": true
}
```

- [ ] **Step 2: Verify JSON is valid**

Run:
```bash
jq . config/config.json
```
Expected: prints the same JSON (jq exits 0).

- [ ] **Step 3: Commit**

```bash
git add config/config.json
git commit -m "Add default config (enabled=true)"
```

---

## Task 8: Write `scripts/build.sh`

**Files:**
- Create: `scripts/build.sh`

- [ ] **Step 1: Write the build script**

Create `scripts/build.sh`:

```bash
#!/usr/bin/env bash
# scripts/build.sh — Build the Disable Durability mod via Unity batchmode.
#
# Required env vars (set in .envrc):
#   UNITY_BIN          Path to the Unity Editor binary (Unity 6000.0.58f2)
#   SDK_PATH           Path to the cloned Pugstorm CoreKeeperModSDK
#   MOD_INSTALL_PATH   Destination Mods/ folder inside the game install
#
# Exit codes:
#   0   Build succeeded
#   1   Env var missing or invalid path
#   2   Unity binary returned non-zero (build failure or Unity crash)

set -euo pipefail

# 1. Validate env vars.
: "${UNITY_BIN:?must be set in .envrc — see .envrc.example}"
: "${SDK_PATH:?must be set in .envrc}"
: "${MOD_INSTALL_PATH:?must be set in .envrc}"

if [ ! -x "$UNITY_BIN" ]; then
    echo "ERROR: \$UNITY_BIN is not executable: $UNITY_BIN" >&2
    exit 1
fi

if [ ! -d "$SDK_PATH/Assets" ]; then
    echo "ERROR: \$SDK_PATH does not look like a Unity project: $SDK_PATH" >&2
    exit 1
fi

# 2. Ensure install path exists.
mkdir -p "$MOD_INSTALL_PATH"

# 3. Invoke Unity.
echo "Building DisableDurability mod..."
echo "  SDK:     $SDK_PATH"
echo "  Install: $MOD_INSTALL_PATH"

if "$UNITY_BIN" \
        -batchmode \
        -nographics \
        -projectPath "$SDK_PATH" \
        -executeMethod DisableDurability.Editor.CLIBuildHelper.Build \
        -logFile - \
        -quit; then
    echo "✓ Build complete. Restart Core Keeper to load."
else
    echo "✗ Build failed. Check Unity log output above for errors." >&2
    exit 2
fi
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x scripts/build.sh
```

- [ ] **Step 3: Verify shellcheck cleanliness (if available)**

Run:
```bash
command -v shellcheck >/dev/null && shellcheck scripts/build.sh || echo "shellcheck not installed; skipping"
```
Expected: no warnings, or skip notice.

- [ ] **Step 4: Commit**

```bash
git add scripts/build.sh
git commit -m "Add build.sh — Unity batchmode build entrypoint"
```

---

## Task 9: Write `scripts/link.sh`

**Files:**
- Create: `scripts/link.sh`

- [ ] **Step 1: Write the symlink script**

Create `scripts/link.sh`:

```bash
#!/usr/bin/env bash
# scripts/link.sh — Idempotently create symlinks from the SDK clone's
# Assets/Mods/DisableDurability/ folder back to this repo's src/ and config/.
#
# Required env vars (set in .envrc):
#   SDK_PATH   Path to the cloned Pugstorm CoreKeeperModSDK
#
# Preconditions:
#   - SDK_PATH/Assets/Mods/DisableDurability/ must already exist (created by
#     PugMod → Open Mod SDK Window → "Create Mod" in Task 10, step 10.1.6).
#
# This script uses absolute paths in the symlinks so the SDK clone can sit
# anywhere on disk. Re-run after moving either repo.

set -euo pipefail

: "${SDK_PATH:?must be set in .envrc}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_MOD_DIR="$SDK_PATH/Assets/Mods/DisableDurability"

if [ ! -d "$SDK_MOD_DIR" ]; then
    echo "ERROR: SDK mod dir not found: $SDK_MOD_DIR" >&2
    echo "Create it first via PugMod → Open Mod SDK Window → Create Mod." >&2
    exit 1
fi

cd "$SDK_MOD_DIR"
mkdir -p Editor

# -s symbolic, -f force overwrite existing link, -n don't dereference existing dir-link
ln -sfn "$REPO_ROOT/src/NoDurabilityLossPatch.cs" NoDurabilityLossPatch.cs
ln -sfn "$REPO_ROOT/src/ModConfig.cs"             ModConfig.cs
ln -sfn "$REPO_ROOT/src/Editor/CLIBuildHelper.cs" Editor/CLIBuildHelper.cs
ln -sfn "$REPO_ROOT/config/config.json"           config.json

echo "✓ Symlinks created in $SDK_MOD_DIR:"
ls -la NoDurabilityLossPatch.cs ModConfig.cs Editor/CLIBuildHelper.cs config.json
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/link.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/link.sh
git commit -m "Add link.sh — symlink mod sources into SDK clone"
```

---

## Task 10: USER ACTION — Unity environment setup (spec §10.1.1–10.1.9)

**Files:** None modified in this repo. User installs Unity Hub + Editor + SDK clone per the spec.

This task cannot be automated. Walk the user through it.

- [ ] **Step 1: Verify prerequisites**

User confirms:
- macOS Big Sur or newer
- ~10 GB free disk space
- CrossOver installed with a working `Core Keeper` bottle
- Core Keeper installed in Steam within that bottle
- `git` and `uuidgen` work in their terminal

- [ ] **Step 2: Install Unity Hub**

User downloads Unity Hub from `https://unity.com/unity-hub` and installs to `/Applications/`. Signs in / creates a Unity account; accepts free Personal license.

- [ ] **Step 3: Install Unity Editor 6000.0.58f2 with Linux Mono Build Support**

User: Unity Hub → Installs → Install Editor → version `6000.0.58f2` (may be in Archive). **Critical:** in the modules dialog, check `Linux Build Support (Mono)`.

Verify (run in terminal after install):
```bash
ls /Applications/Unity/Hub/Editor/6000.0.58f2/Unity.app/Contents/MacOS/Unity
```
Expected: file exists.

- [ ] **Step 4: Clone the Pugstorm SDK**

```bash
cd /Users/valgard/Projects/private/core_keeper
git clone https://github.com/Pugstorm/CoreKeeperModSDK.git
```

Verify:
```bash
ls /Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK/Assets/
```
Expected: a populated Unity `Assets/` directory.

- [ ] **Step 5: Open SDK as a Unity project**

User: Unity Hub → Projects → Add → Add project from disk → select `CoreKeeperModSDK/`. Right-click the project → Add command line arguments → `-disable-assembly-updater` → Save. Open the project. **Wait 5–10 min** for Unity to import packages and extract bundled assemblies. Console will fill with chatter — wait until activity settles.

Verify: user reports the Unity Editor main window is open with the SDK project visible in Project panel.

- [ ] **Step 6: Create the DisableDurability mod scaffold**

User: top menu → PugMod → Open Mod SDK Window. In the panel, find the "Create New Mod" workflow. Enter mod name `DisableDurability`. Confirm. Inspect `Assets/Mods/DisableDurability.asset` and set fields per spec §10.1.6:

- `guid` — generate with `uuidgen | tr A-Z a-z` and paste
- `name` — `DisableDurability`
- `displayName` — `Disable Durability`
- `requiredOn` — `ClientAndServer`
- `disableHarmonyPatching` — **false** (default)
- All other flags — leave default

Save (Cmd+S).

Verify:
```bash
ls "$SDK_PATH/Assets/Mods/"
```
Expected: `DisableDurability.asset` and `DisableDurability/` folder both present.

- [ ] **Step 7: Discover CrossOver bottle paths**

```bash
ls ~/Library/Application\ Support/CrossOver/Bottles/
find ~/Library/Application\ Support/CrossOver/Bottles/Core\ Keeper/drive_c/ \
     -name "CoreKeeper.exe" 2>/dev/null
```

User notes the exact `MOD_INSTALL_PATH` (Spec §10.4: ends with `CoreKeeper_Data/StreamingAssets/Mods/`).

- [ ] **Step 8: Create `.envrc` from `.envrc.example`**

```bash
cp .envrc.example .envrc
# Edit .envrc and set UNITY_BIN, SDK_PATH, MOD_INSTALL_PATH for this machine.
```

User edits `.envrc` to match their actual paths.

- [ ] **Step 9: Source `.envrc` and sanity-check**

```bash
source .envrc
[ -x "$UNITY_BIN" ] && echo "✓ UNITY_BIN ok"
[ -d "$SDK_PATH/Assets" ] && echo "✓ SDK_PATH ok"
mkdir -p "$MOD_INSTALL_PATH" && echo "✓ MOD_INSTALL_PATH writable"
```

Expected: three `✓` lines.

- [ ] **Step 10: No commit**

This task does not modify the repo. No commit.

---

## Task 11: USER ACTION — Link source files into the SDK

**Depends on:** Tasks 4–9 (source files committed) and Task 10 (SDK mod scaffold exists).

**Files:** Symlinks created in `$SDK_PATH/Assets/Mods/DisableDurability/` (outside this repo).

- [ ] **Step 1: Source `.envrc` if not active**

```bash
source .envrc
```

- [ ] **Step 2: Run the link script**

```bash
./scripts/link.sh
```

Expected output: `✓ Symlinks created in …` plus a `ls -la` showing four symlinks (three `.cs`, one `.json`), each line containing `->`.

- [ ] **Step 3: Verify Unity sees the new files**

User switches to Unity Editor (it should be open from Task 10). Wait ~5 seconds. Unity auto-detects new files and runs an import. The Project panel should show, under `Assets/Mods/DisableDurability/`: `NoDurabilityLossPatch`, `ModConfig`, `config` (json), and an `Editor/` folder containing `CLIBuildHelper`.

If Unity shows compile errors in the Console panel, leave them — they will be addressed in Task 12.

- [ ] **Step 4: No commit**

Symlinks live in the SDK clone, not this repo.

---

## Task 12: First manual build + iterate on compile errors

**Depends on:** Tasks 4–11.

**Files:** Possibly small edits to `src/*.cs` based on compile errors surfaced by Unity.

The plan optimistically assumes the code compiles on first try. In practice, the most common issues are:

- `HarmonyLib` not referenced in the asmdef (most likely).
- `PugMod` not referenced (less likely; should be by default).
- Patch target name doesn't resolve (revisit Task 3).
- `JsonUtility` field-vs-property mismatch.

- [ ] **Step 1: USER ACTION — first GUI build for sanity**

User: in Unity, PugMod → Open Mod SDK Window → select `DisableDurability` → Build. Provide `$MOD_INSTALL_PATH` as the export path when prompted.

- [ ] **Step 2: USER ACTION — collect error output**

If build succeeds, skip to Step 6.

If build fails: user copies the error text from the Unity Console and pastes it into the chat for diagnosis.

- [ ] **Step 3: Likely fix A — Add HarmonyLib reference to asmdef**

If the error contains `The type or namespace 'HarmonyLib' could not be found`:

User edits `$SDK_PATH/Assets/Mods/DisableDurability/DisableDurability.asmdef` (a JSON file). Locate `references` array, append `"HarmonyLib"`:

```json
{
  "name": "DisableDurability",
  "references": [
    "Unity.Burst",
    "Unity.Collections",
    "Unity.Entities",
    "Unity.Entities.Hybrid",
    "HarmonyLib"
  ],
  ...
}
```

Save. Unity auto-recompiles. Re-run build (Step 1).

- [ ] **Step 4: Likely fix B — Fix patch target name**

If the error references the patch target type/method (`'XYZ' could not be found`):

Re-read `docs/research/permabreak-patch-target.md`. Verify the namespace + class + method spelling. Edit `src/NoDurabilityLossPatch.cs`. The Unity-side symlink will reflect the edit immediately.

- [ ] **Step 5: Iterate**

For other errors: diagnose case-by-case. Common cases:
- `JsonUtility` warnings about non-serializable type → ensure `ModConfig` has `[Serializable]` (already done in Task 4).
- Editor-only code referenced outside Editor → make sure `CLIBuildHelper` lives in `Editor/` subfolder (it does via symlink target path).
- `PugMod.ModBuilderSettings` not found → ensure `dev.pugstorm.mod` package is in the SDK clone's `Packages/` (it is by default).

After each fix, re-run Step 1.

- [ ] **Step 6: Verify build output**

When the build reports success, run:

```bash
ls -la "$MOD_INSTALL_PATH/DisableDurability/"
```

Expected: `ModManifest.json`, `DisableDurability.dll`, `config.json` all present, with non-zero sizes.

- [ ] **Step 7: Commit any code fixes from this task**

If `src/` was modified during this task:

```bash
git add src/
git commit -m "Fix compile errors surfaced during first build"
```

(Multiple commits acceptable if fixes were independent.)

---

## Task 13: USER ACTION — First in-game load verification

**Depends on:** Task 12 (build succeeded).

**Files:** None. Pure runtime verification.

- [ ] **Step 1: Launch Core Keeper via CrossOver**

User: open Steam in CrossOver, launch Core Keeper normally. Wait for the title screen.

- [ ] **Step 2: Tail the Unity Player log**

In a separate terminal:

```bash
find ~/Library/Application\ Support/CrossOver/Bottles/Core\ Keeper/drive_c/users/ \
     -name "Player.log" -path "*/Pugstorm/*" 2>/dev/null
```

Note the path. Then:

```bash
tail -n 200 "<path>" | grep -i 'DisableDurability\|HarmonyPatch\|ModLoader'
```

- [ ] **Step 3: Look for the loaded-marker**

Expected line in the log:

```
[DisableDurability] Patch loaded. Enabled=True
```

- [ ] **Step 4a: If the line is present — pass**

Setup verified end-to-end. Proceed to Task 14.

- [ ] **Step 4b: If the line is absent — diagnose**

Possible causes (try in order):

1. **Wrong install path.** Switch `$MOD_INSTALL_PATH` to the mod.io cache path per spec §10.4:
   ```
   ~/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/users/Public/mod.io/<game-id>/mods/<mod-id>/
   ```
   (Discover the path by inspecting where PermaBreak landed from Task 3 Step A.2.) Re-run Task 12 (build) and Task 13.

2. **Build silently produced an empty/missing DLL.** Run:
   ```bash
   file "$MOD_INSTALL_PATH/DisableDurability/DisableDurability.dll"
   ```
   Expected: `PE32 executable` or `Mono/.Net assembly`. If the file is missing or 0 bytes, the build broke. Re-run Task 12 with verbose Unity logging.

3. **Manifest `requiredOn` mismatch.** Some loader paths may filter by required-on flag. Try toggling to `Client` only in the SDK, rebuild, retest. (Revert before shipping.)

4. **Game version mismatch with SDK.** Note the game version and SDK commit; consult mod.io / Pugstorm Discord if the API shifted between versions.

---

## Task 14: USER ACTION — Run the V1 manual test suite

**Depends on:** Task 13 passed.

**Files:** None modified in this task. Optionally update README if observed multiplayer enforcement behavior should be documented.

Run the 8 manual tests from spec §11 in order. Each test should report **PASS** or **FAIL** with a note.

- [ ] **Test 1: Install path verification**

Confirmed in Task 13 — PASS automatically here.

- [ ] **Test 2: Basic behavior**

User: equip a pickaxe, mine ~50 blocks. Check durability bar.

Expected: durability unchanged from start.

- [ ] **Test 3: Config disable**

Edit `$MOD_INSTALL_PATH/DisableDurability/config.json` → `{"enabled": false}`. Restart Core Keeper. Mine 50 blocks.

Expected: durability decreases normally.

Restore `enabled: true` after this test.

- [ ] **Test 4: Item-type coverage**

Repeat Test 2 with a sword (combat), a bow (ranged), and armor (taking damage).

Expected: all retain full durability.

- [ ] **Test 5: Damaged item freeze**

Find or craft an item that is already partially used (e.g., 30/100). With mod active, use it heavily.

Expected: durability stays at the starting value — does not recover to 100, does not decrease.

- [ ] **Test 6: Save persistence**

Use modded items, save the world, exit to title, reload. Use items again.

Expected: behavior consistent across reload.

- [ ] **Test 7: Multiplayer smoke (optional, skip if multiplayer is not in scope for the user)**

Run a dedicated server with the mod installed. Connect a client also running the mod. Both players use durability-consuming items.

Expected: both sides see consistent (non-decrementing) durability.

- [ ] **Test 8: Multiplayer mismatch (optional)**

Server has the mod, client does not (or vice versa). Try to connect.

Document the observed behavior:
- Did the connection succeed?
- If yes: does durability decrement?
- If the connection was refused: what was the error message?

If `requiredOn` enforcement was strict (connection refused on mismatch), update README to mention "both server and client must have the mod" with a clear note. If enforcement was lax, document that too.

- [ ] **Step 9: Update README if needed**

If multiplayer testing surfaced behavior worth documenting, append to `README.md`. Commit:

```bash
git add README.md
git commit -m "Document multiplayer enforcement behavior observed during V1 testing"
```

- [ ] **Step 10: Final commit / merge worktree**

If everything passes:

```bash
# From the worktree:
git checkout main
git merge --ff-only disable-durability-v1   # or rebase per global CLAUDE.md
git worktree remove ../.worktrees/disable-durability-v1
git branch -d disable-durability-v1
```

V1 is complete. The mod is installed and verified.

---

## What V1 ships with

- `disable-durability/` repo with all source, config, scripts, docs, research notes, spec, plan.
- A working `DisableDurability/` mod folder in `$MOD_INSTALL_PATH`, verified loaded.
- Documented multiplayer enforcement behavior (per Task 14 Test 8).
- Clean git history on `main`: spec commit + scaffolding/code commits + any compile-error fixes.

## Open follow-ups deferred to V2

Per spec §15:
- Hot-reload config without restart.
- In-game UI toggle.
- Item-type whitelist/blacklist.
- mod.io upload (icon, README in mod.io format, changelog).
- Automated test harness for Harmony patches.
- CI pipeline.

# Disable Durability — Design Spec (V1)

| Field | Value |
|---|---|
| Date | 2026-05-13 |
| Status | Approved, ready for implementation planning |
| Target game | Core Keeper (Windows build, running under CrossOver on macOS) |
| Modding pipeline | Pugstorm `CoreKeeperModSDK` (official) + Harmony |
| Distribution | Personal use; mod.io upload deferred to V2 |

## 1. Problem statement

Items in Core Keeper lose durability when used and eventually break. For a QoL-focused playstyle (creative, casual, exploration-heavy) this introduces friction without compensating value. The user wants a mod that disables durability loss so that tools, weapons, and armor never wear out.

## 2. Goals (V1)

1. Items never lose durability when used.
2. Behavior is toggleable via a JSON config file.
3. Works in singleplayer; works in multiplayer when installed on both sides.
4. Minimal, isolated patch — easy to remove or to revise when the game updates.
5. Built on the officially supported Pugstorm modding pipeline.

## 3. Non-goals (V1)

- Hot-reload of config at runtime (game restart required to apply changes).
- In-game UI or hotkey toggle.
- Item-specific whitelist or blacklist.
- Repair functionality (items keep their *current* durability; they do not reset to max).
- Automated tests (Harmony patches without a test harness are tested manually).
- mod.io upload (deferred to V2; code is structured so the upgrade is trivial).
- Multi-language UI (the mod has no UI strings).

## 4. Constraints

- **Pugstorm EULA**: mods may only be distributed non-commercially.
- **Test environment**: macOS host, Core Keeper Windows build running under CrossOver.
- **Build toolchain**: Unity Editor 6000.0.59f2 with Linux Build Support (Mono) is required by the SDK.
- **Architecture**: Core Keeper uses Unity DOTS / ECS; durability lives as component data, not as a field on a `MonoBehaviour`.

## 5. Architecture

### 5.1 High-level summary

A single Harmony `Prefix` patch suppresses the code path that decrements durability. A lazy-loaded `ModConfig` singleton reads `config.json` from the mod's install directory and exposes an `Enabled` flag. Pugstorm's bundled mod loader auto-discovers `[HarmonyPatch]`-annotated classes, so no explicit entry-point interface is needed.

### 5.2 Components

| Component | Responsibility | Visibility |
|---|---|---|
| `NoDurabilityLossPatch` | Harmony patch class with `Prefix` that skips original when `Enabled` is true. | internal static |
| `ModConfig` | Lazy singleton; reads `config.json` next to the mod DLL; exposes `bool Enabled`. | internal sealed |
| `CLIBuildHelper` | Editor-only wrapper around `PugMod.ModBuilder.BuildMod(...)` for `unity -executeMethod` invocations. | public static (Editor-only) |

Each component has one responsibility. The patch class does not know how config is loaded. The config class does not know about Harmony. The connection point is a single read of `ModConfig.Instance.Enabled` inside the patch.

### 5.3 Deliverable layout

The Pugstorm builder produces this folder, which is installed in the game's mod directory:

```
DisableDurability/
├── ModManifest.json        # Pugstorm mod metadata
├── DisableDurability.dll   # patch + config code (Linux Mono assembly)
└── config.json             # default config bundled with the mod
```

### 5.4 Source repository layout

```
disable-durability/                            # this git repo
├── .gitignore
├── README.md                                  # to be written during implementation
├── docs/superpowers/specs/
│   └── 2026-05-13-disable-durability-design.md
├── src/                                       # canonical source of truth
│   ├── NoDurabilityLossPatch.cs
│   ├── ModConfig.cs
│   └── Editor/
│       └── CLIBuildHelper.cs
├── config/
│   └── config.json                            # default config shipped with builds
└── scripts/
    └── build.sh                               # wraps unity batchmode invocation
```

The Pugstorm SDK is cloned separately (not vendored in this repo). `build.sh` syncs `src/` contents into the SDK's `Assets/DisableDurability/` folder and then invokes Unity. Decision on whether the SDK is a sibling clone, a submodule, or a worktree is deferred to the implementation planning phase.

## 6. Patch strategy

### 6.1 Target method — to be determined during implementation

Core Keeper's DOTS/ECS architecture means durability is mutated by an ECS system, not by a method on an item object. The exact target class/method name is unknown without binary inspection. Implementation begins with a 15–30-minute investigation:

1. Download the **PermaBreak** mod from mod.io (production mod that does the inverse: forces items to break permanently). Inspect its DLL with `ilspycmd` to see which method it patches.
2. If PermaBreak is not available as plain DLL, use AssetRipper on the local Core Keeper installation and grep for `Durability` in the decompiled output.

### 6.2 Candidate patch strategies

| Strategy | When to use | Pros | Cons |
|---|---|---|---|
| 1. Central helper method | A single `ItemUtility.ReduceDurability(...)`-style method exists | one patch site, covers all callers | depends on game architecture having such a helper |
| 2. ECS System `OnUpdate` | Durability decrement is a dedicated system | clear scope boundary | may also skip wanted side effects (visual feedback, achievements) |
| 3. Multiple specific call sites | Decrement happens inline at each use site | maximum precision | many patches, more maintenance, fragile across updates |

Strategy 1 is preferred and likely to be available given a similar mod (PermaBreak) exists. Strategy 2 is the next fallback. Strategy 3 is a last resort.

### 6.3 Patch shape

```csharp
[HarmonyPatch(/* target resolved during implementation */)]
[HarmonyPriority(Priority.Last)]
internal static class NoDurabilityLossPatch
{
    static NoDurabilityLossPatch()
    {
        Debug.Log($"[DisableDurability] Patch loaded. Enabled={ModConfig.Instance.Enabled}");
    }

    [HarmonyPrefix]
    static bool Prefix()
    {
        if (!ModConfig.Instance.Enabled) return true;  // run original
        return false;                                   // skip original
    }
}
```

### 6.4 Effect on item state

Skipping the decrement freezes durability at its *current* value, not at max. A pickaxe at 30/100 stays at 30/100 indefinitely while the mod is active. This is the correct semantics for "freeze"; it is not a repair mod. The README must call this out so users do not expect repair behavior.

## 7. Configuration

### 7.1 File

`config.json`, written by the build into the mod's install folder next to `DisableDurability.dll`.

### 7.2 Schema

```json
{
  "enabled": true
}
```

### 7.3 Loading

```csharp
internal sealed class ModConfig
{
    public bool Enabled { get; private set; } = true;

    private static ModConfig _instance;
    public static ModConfig Instance => _instance ??= Load();

    private static ModConfig Load()
    {
        var cfg = new ModConfig();
        var dllPath = typeof(ModConfig).Assembly.Location;
        var cfgPath = Path.Combine(Path.GetDirectoryName(dllPath)!, "config.json");
        if (!File.Exists(cfgPath)) return cfg;
        try
        {
            var json = File.ReadAllText(cfgPath);
            cfg = JsonUtility.FromJson<ModConfig>(json) ?? cfg;
        }
        catch (Exception e)
        {
            Debug.LogWarning($"[DisableDurability] Config parse failed: {e.Message} — using defaults.");
        }
        return cfg;
    }
}
```

### 7.4 Defaults

- Missing file → `enabled = true`.
- Malformed file → log warning, `enabled = true`.
- Rationale: a user who installs the mod presumably wants it on; fall back to "active" rather than "silent no-op".

### 7.5 Lifecycle

Read once on first access. No hot-reload in V1. Changing `config.json` requires a game restart.

## 8. Multiplayer

### 8.1 Manifest setting

`requiredOn = ClientAndServer` in the Pugstorm `ModMetadata`.

### 8.2 Rationale

| Mod installed on | Durability changes | Outcome |
|---|---|---|
| Client only | Yes (server is authoritative) | mod has no effect |
| Server only (dedicated) | No | mod works; client may briefly see stale UI |
| Both sides | No | consistent, intended behavior |

In singleplayer the player is both client and server, so this is automatically satisfied. In multiplayer the mod must be on both sides; `requiredOn = ClientAndServer` is the Pugstorm-supported way to express this.

### 8.3 Open question

Whether Pugstorm enforces the `requiredOn` flag (e.g., by refusing client connections to a server with a mismatched mod loadout) is not documented in the SDK code and is not clear from inspection. This is verified during multiplayer testing and documented in the README based on observed behavior.

### 8.4 No custom netcode

Each side reads its own `config.json` independently. We do not synchronize config across the network. This is a deliberate V1 simplification.

## 9. Error handling

### 9.1 Failure modes and responses

| Failure | Response | User-visible signal |
|---|---|---|
| Harmony cannot locate target method (e.g., game update broke the patch) | Pugstorm loader logs; patch class is silently skipped; rest of mod loader continues | log entry |
| `config.json` malformed | Catch parse exception, log warning, use defaults | log warning |
| Patch throws at runtime | Harmony default: catch, log, fall back to original | log entry |
| Mod present on client only in multiplayer | Server authority dominates; mod has no effect | player observes "mod not working" |

### 9.2 Proactive visibility

A static constructor in the patch class logs `[DisableDurability] Patch loaded. Enabled=…` on first access. Users grep the game log to verify the patch was applied.

### 9.3 Deliberately not implemented

- `try`/`catch` around the patch body — Harmony's own catch is sufficient.
- Validation classes for config values — `bool enabled` is trivial.
- Self-healing or retry — if the patch breaks, a code update is the right response, not a runtime retry.
- Telemetry or crash reporting — personal-use mod, no need.

## 10. Build & install workflow

### 10.1 Initial setup (one-time)

Walks from "empty disk" to "first successful mod build". Wall-time **30–60 min** depending on download speeds; **~15 min hands-on**. Most of the wall-time is Unity Editor download (~5–8 GB) and Unity's first-open package compilation.

**Step ordering note:** §10.1.1–10.1.9 are pure environment setup and can be completed before any code is written. §10.1.10 (first manual build) and §10.1.11 (first load verification) require the source files in `disable-durability/src/` to exist, and so happen **after the first implementation pass** — they belong logically to the implement-build-verify loop, not to environment setup. They are kept in this section because the workflow is unified, but expect to return to them once the implementation plan has written initial source files.

#### 10.1.1 Prerequisites

- macOS Big Sur or newer (required by Unity 6).
- ~10 GB free disk space (Unity Editor + SDK + build artifacts).
- CrossOver installed with a working **Core Keeper** bottle; the game launches and runs.
- Steam account with Core Keeper purchased.
- `git` and `uuidgen` available in `PATH` (both shipped with macOS).
- (Optional, free) A Unity account — created during Hub install if you don't have one.

#### 10.1.2 Install Unity Hub

Unity Hub is the launcher / version-manager for Unity Editor installs.

1. Download from `https://unity.com/unity-hub` (macOS installer, ~150 MB).
2. Drag `Unity Hub.app` into `/Applications/`.
3. Launch Unity Hub. On first launch:
   - Sign in with a Unity account (create one if needed — free, no payment required).
   - Accept the free **Personal** license when prompted (sufficient for non-commercial modding).

#### 10.1.3 Install Unity Editor 6000.0.59f2 with Linux Mono build support

The SDK is **pinned to this exact version**. Mismatched versions may not import the project correctly.

> **Note on version source:** The SDK's `README.md` mentions `6000.0.58f2`, but `ProjectSettings/ProjectVersion.txt` (the file Unity actually reads when opening a project) pins to `6000.0.59f2`. The project file is authoritative — install `6000.0.59f2`. If you already have a newer Unity 6 release installed (e.g., `6000.4.6f1`), keep it; Unity Hub supports parallel Editor versions, and using the newer one to open this SDK would trigger an irreversible project upgrade that may break the DOTS-heavy mod toolchain.

1. In Unity Hub: **Installs** tab → **Install Editor**.
2. Find `6000.0.59f2` in the version list. If absent from "Official Releases", scroll to **Archive** → click "download archive" — the linked page lets you launch Unity Hub directly into the install flow for that specific version.
3. When the **Add modules** dialog appears, **check `Linux Build Support (Mono)`**. This is mandatory for Core Keeper mods (per SDK README).
   - Other modules (WebGL, iOS, Android) are optional and add 1–2 GB each — skip them.
4. Continue and accept the Unity EULA.
5. Download + install: 5–15 minutes (~5–8 GB).
6. Verify the editor binary path (you'll need it as `$UNITY_BIN` below):

   ```bash
   ls /Applications/Unity/Hub/Editor/6000.0.59f2/Unity.app/Contents/MacOS/Unity
   ```

#### 10.1.4 Clone the Pugstorm Mod SDK

Cloned **sibling to this mod repo**, keeping the `core_keeper/` hub organized. The SDK is its own repo — **do not** nest it under `disable-durability/`.

```bash
cd /Users/valgard/Projects/private/core_keeper
git clone https://github.com/Pugstorm/CoreKeeperModSDK.git
```

Resulting layout:

```
core_keeper/                  # hub (not a git repo)
├── disable-durability/       # our mod (git repo)
└── CoreKeeperModSDK/         # Pugstorm SDK (separate git repo)
```

Optional but recommended — pin a known-working SDK commit so future SDK updates don't surprise you mid-development:

```bash
cd CoreKeeperModSDK
git rev-parse HEAD            # note this SHA
# Later, in scripts/build.sh:
#   git -C "$SDK_PATH" rev-parse HEAD | grep -qx "$PINNED_SHA" || echo "WARN: SDK SHA drift"
```

#### 10.1.5 Open the SDK as a Unity project

1. In Unity Hub: **Projects** tab → **Add** dropdown → **Add project from disk**.
2. Select `/Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK/`.
3. The project appears in the list. **Right-click (or three-dot menu)** on it → **Add command line arguments** → enter `-disable-assembly-updater` → Save. (Per the SDK README; removes spurious upgrade-warnings on first open.)
4. Click the project name to open it.
5. **First open takes 5–10 minutes.** Unity downloads and imports all Unity packages, extracts any bundled assembly archives (the SDK ships `Assets/ModSDK/EditorAssemblies.zip` and similar), and compiles scripts. Lots of progress bars and console warnings — most are benign Unity 6 / DOTS chatter. **Wait until the activity indicator settles before doing anything.**
6. When the Editor main window stabilizes with the SDK's project layout visible (you'll see Assets/, Packages/ in the Project panel), you're ready.

#### 10.1.6 Create a new mod via the PugMod SDK Window

1. Top menu: **PugMod → Open Mod SDK Window**. A dockable panel opens.
2. Find the "Create New Mod" workflow in the panel (Pugstorm's SDK exposes this via `ModSDKWindow/CreateMod.cs`; UI label may be a tab or button).
3. Mod name: `DisableDurability` (no spaces — internal identifier).
4. Confirm. The SDK creates:
   - `Assets/DisableDurability/` folder with template files.
   - `Assets/DisableDurability.asset` — a `ModBuilderSettings` ScriptableObject holding the manifest.
5. Click `Assets/DisableDurability.asset` in the Project panel. The Inspector shows the manifest fields. Set:
   - `guid` — generate a fresh GUID: open a macOS terminal, run `uuidgen | tr A-Z a-z`, paste the result. Example: `a1b2c3d4-e5f6-7890-abcd-ef0123456789`.
   - `name` — `DisableDurability` (must match the folder name).
   - `displayName` — `Disable Durability` (user-facing label; spaces OK).
   - `requiredOn` — `ClientAndServer` (critical for multiplayer correctness, see §8).
   - `disableHarmonyPatching` — **false** (critical: leave Harmony enabled, that's how our patch runs).
   - `skipSafetyChecks`, `disableScripts`, `accessesExtraAssemblies` — all leave at defaults (`false`).
6. Save (Cmd+S).

#### 10.1.7 Link our source code into the SDK's mod folder

Our `.cs` files are canonical in **`disable-durability/src/`** (this git repo). Instead of copying them into the SDK clone (which would duplicate state and lose history), we **symlink** them in. Unity treats symlinked C# files like normal source files; edits in `src/` are picked up on save.

```bash
# Working directory: the SDK mod folder that PugMod just created
cd /Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK/Assets/DisableDurability/

# Create the Editor/ subfolder (Unity magic-folder for editor-only code)
mkdir -p Editor

# Symlink each source file. Relative paths so the links survive moves.
ln -s ../../../../disable-durability/src/NoDurabilityLossPatch.cs .
ln -s ../../../../disable-durability/src/ModConfig.cs .
ln -s ../../../../disable-durability/src/Editor/CLIBuildHelper.cs Editor/
ln -s ../../../../disable-durability/config/config.json .

# Verify symlinks resolve (each line should show '->'):
ls -la *.cs config.json Editor/*.cs
```

What lives where after this:

| In our git repo (`disable-durability/`) | In the SDK clone (`CoreKeeperModSDK/.../DisableDurability/`) |
|---|---|
| `src/*.cs` — canonical source | symlinks pointing back to `src/*.cs` |
| `config/config.json` — default config | symlink pointing back |
| (none) | `ModBuilderSettings.asset` + `.meta` (Unity-managed; do not commit into our repo) |
| (none) | `DisableDurability.asmdef` + `.meta` (Unity-managed) |
| (none) | Per-file `.meta` sidecars Unity generates for the symlinks |

Notes:
- If Unity briefly shows "missing meta file" warnings: click into the Project panel; Unity reconciles automatically.
- The symlinks themselves are inside the SDK clone, so they are not version-controlled in our repo — they're a setup-time artifact.
- Alternative: drop the symlinks and have `build.sh` `rsync` `src/` → SDK on each build. Slower, requires never editing inside the SDK clone, but avoids symlink edge-cases on case-insensitive HFS+ filesystems. Default is symlinks.

#### 10.1.8 Discover your CrossOver bottle paths

Three values needed for `$MOD_INSTALL_PATH`. Run these to verify the empirically observed bottle name `Core Keeper`:

```bash
# 1. Confirm bottle name:
ls ~/Library/Application\ Support/CrossOver/Bottles/

# 2. Locate CoreKeeper.exe inside the bottle:
find ~/Library/Application\ Support/CrossOver/Bottles/Core\ Keeper/drive_c/ \
     -name "CoreKeeper.exe" 2>/dev/null

# 3. The mods directory is sibling to CoreKeeper.exe under CoreKeeper_Data/StreamingAssets/Mods/.
#    Typical full path:
echo "$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/Program Files (x86)/Steam/steamapps/common/Core Keeper/CoreKeeper_Data/StreamingAssets/Mods/"
```

If your Steam library is in a non-standard location inside the bottle (e.g., custom library folder), adjust accordingly.

#### 10.1.9 Set environment variables

Create `disable-durability/.envrc`:

```bash
# .envrc — source from your shell before working on this mod.
export UNITY_BIN="/Applications/Unity/Hub/Editor/6000.0.59f2/Unity.app/Contents/MacOS/Unity"
export SDK_PATH="/Users/valgard/Projects/private/core_keeper/CoreKeeperModSDK"
export MOD_INSTALL_PATH="$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/Program Files (x86)/Steam/steamapps/common/Core Keeper/CoreKeeper_Data/StreamingAssets/Mods/"
```

Use it:

```bash
cd /Users/valgard/Projects/private/core_keeper/disable-durability
source .envrc
```

Optional: install `direnv` (`brew install direnv`) so `.envrc` auto-loads on `cd` into the directory. The file is `.gitignore`-listed if you keep machine-specific paths (use `.envrc.local` for that, also gitignored).

#### 10.1.10 First manual build (GUI sanity check)

Before scripting CLI builds, do **one build from the Unity GUI** to confirm the pipeline works end-to-end:

1. In Unity, with the SDK project open: **PugMod → Open Mod SDK Window**.
2. Select `DisableDurability` from the mod list.
3. Click the **Build** action in the window (label may be "Build Mod" or "Build & Install").
4. When prompted for export path, paste the value of `$MOD_INSTALL_PATH`.
5. Build takes ~30–60 s first time (cold compile of dependencies), faster on subsequent runs.
6. Verify output from a terminal:
   ```bash
   ls -la "$MOD_INSTALL_PATH/DisableDurability/"
   # expect: ModManifest.json, DisableDurability.dll, config.json
   ```

Common failures:
- "Missing Linux Build Support" → revisit §10.1.3.
- "GUID conflict" → regenerate `guid` in the manifest.
- "Symlink target not found" → re-check §10.1.7 (`ls -la` should show `->`).
- "Compile errors" → console will pinpoint the file/line.

#### 10.1.11 First load verification in Core Keeper

1. Launch Core Keeper through CrossOver (normal Steam launch).
2. In a terminal, find and tail the Unity Player log (path uses Unity's standard `LocalLow` convention; exact `<wine-user>` directory depends on your bottle setup):
   ```bash
   find ~/Library/Application\ Support/CrossOver/Bottles/Core\ Keeper/drive_c/users/ \
        -name "Player.log" -path "*/Pugstorm/*" 2>/dev/null
   tail -f "<path-from-above>"
   ```
3. Grep for our marker:
   ```bash
   grep -i "DisableDurability" "<path-from-above>"
   ```
   Expected: `[DisableDurability] Patch loaded. Enabled=True`.
4. **If the line is present**: setup complete. From here on, iterate via `scripts/build.sh` (§10.2) — Unity GUI never needs to open again.
5. **If the line is absent**: the loader didn't pick the mod up. Either:
   - Install path is wrong → fall back to mod.io cache path (§10.4), retry.
   - Build silently failed → check the export folder; if `DisableDurability.dll` is missing or 0 bytes, the build broke despite returning success — re-run from Unity GUI and watch the console.
   - Game isn't reading from `StreamingAssets/Mods/` in this version → switch to the mod.io fallback path.

### 10.2 Iteration (CLI-driven, no Unity GUI needed)

`CLIBuildHelper.cs` wraps `PugMod.ModBuilder.BuildMod(...)` so it can be invoked with `unity -batchmode -executeMethod`:

```bash
"$UNITY_BIN" -batchmode -nographics \
  -projectPath "$SDK_PATH" \
  -executeMethod CLIBuildHelper.Build \
  -logFile - -quit
```

A `scripts/build.sh` wrapper sets defaults, syncs `src/` into the SDK, and forwards exit codes.

### 10.3 Environment variables

Configured once in `.envrc` (or shell rc):

```bash
export UNITY_BIN="/Applications/Unity/Hub/Editor/6000.0.59f2/Unity.app/Contents/MacOS/Unity"
export SDK_PATH="$HOME/.../CoreKeeperModSDK"
export MOD_INSTALL_PATH="$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper/drive_c/Program Files (x86)/Steam/steamapps/common/Core Keeper/CoreKeeper_Data/StreamingAssets/Mods/"
```

The exact `MOD_INSTALL_PATH` depends on whether Steam is in the bottle's standard location; verified at first setup.

### 10.4 Install path

Two candidate paths exist for Pugstorm mods:

| Path | Source | Use |
|---|---|---|
| `<GameDir>/CoreKeeper_Data/StreamingAssets/Mods/` | SDK `CreateMod.cs` default | primary target for SDK-built mods |
| `~/Library/.../Bottles/Core Keeper/drive_c/users/Public/mod.io/...` | mod.io client cache (observed empirically) | where mod.io-downloaded mods land |

V1 installs to the `StreamingAssets/Mods/` path. If the load test (10.5) fails there, fall back to the mod.io cache path; the exact namespaced subpath in the mod.io directory is determined at that point.

The Pugstorm builder appends a subfolder named after the mod, so `MOD_INSTALL_PATH` ends with `Mods/`, not `Mods/DisableDurability/`.

### 10.5 Install path verification (first test after every install change)

After the first build, launch Core Keeper and search the game log for `[DisableDurability] Patch loaded`. If the line is present, the install path is correct. If not, the loader did not pick the mod up — try the fallback path.

## 11. Test plan

All tests are manual in V1. No automated test harness is built.

| # | Test | Steps | Pass condition |
|---|---|---|---|
| 1 | Install path verification | Build, install, launch game, grep log | `[DisableDurability] Patch loaded` line present |
| 2 | Basic behavior | Equip a pickaxe, mine ~50 blocks | Durability bar unchanged |
| 3 | Config disable | Set `config.json` `enabled: false`, restart game, mine 50 blocks | Durability decreases normally |
| 4 | Item-type coverage | Repeat (2) for sword, bow, armor (taking damage) | All retain durability |
| 5 | Damaged item freeze | Take an item at e.g., 30/100, use it heavily | Stays at 30/100 — does not repair to 100 |
| 6 | Save persistence | Use modded items, save, reload, use again | Consistent behavior across reload |
| 7 (optional) | Multiplayer smoke | Dedicated server + client both with mod | Both sides show consistent durability |
| 8 (optional) | Multiplayer mismatch | Server with mod, client without (or vice versa) | Document observed enforcement behavior |

## 12. Open questions carried into implementation

1. **Exact target method** for the Harmony patch — resolved via PermaBreak inspection or AssetRipper analysis as the first implementation step.
2. **Primary vs fallback install path** — resolved by test 1 ("Install path verification") on the first build.
3. **Multiplayer enforcement behavior** of `requiredOn` — resolved by tests 7 and 8 if multiplayer is in scope for the user.
4. **SDK integration layout** (sibling clone vs submodule vs worktree) — resolved during implementation planning.

## 13. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Future Core Keeper update renames the patch target method | Harmony supports signature-based matching; minor version bump fixes most cases. Document the failure mode in README. |
| Another mod patches the same target with conflicting intent | `[HarmonyPriority(Priority.Last)]` makes us a defensive default; conflicts log clearly. |
| Pugstorm SDK API changes | Pin the SDK clone to a specific commit/tag in `scripts/build.sh`; bump deliberately. |
| Player expects "repair" behavior | README explicitly states "freeze, not repair". |
| Pugstorm EULA disallows commercial distribution | V1 is personal-use only; spec acknowledges the restriction. |

## 14. License and distribution

The mod source code in this repository is the author's work and may be licensed as the author chooses, subject to the constraint that resulting mods must be distributed non-commercially per the Pugstorm EULA. Future mod.io upload is out of V1 scope.

## 15. Out-of-scope (V2+ candidates)

- Hot-reload config without restart.
- In-game UI toggle (settings menu or hotkey).
- Item-type whitelist / blacklist.
- Repair-on-use as a separate mode (item rises back to max instead of freezing).
- Mod.io publication with icon, README, changelog.
- Automated tests using a Harmony-aware test harness.
- CI pipeline to build artifacts on push.

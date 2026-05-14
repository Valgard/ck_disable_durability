#!/usr/bin/env bash
# scripts/build.sh — Build the Disable Durability mod via Unity batchmode.
#
# Required env vars (set in .envrc):
#   UNITY_BIN          Path to the Unity Editor binary (Unity 6000.0.59f2)
#   SDK_PATH           Path to the cloned Pugstorm CoreKeeperModSDK
#   MOD_INSTALL_PATH   Destination Mods/ folder inside the game install
#
# On macOS, this script also runs `scripts/install-macos.sh` after the build
# to apply the CrossOver/Wine workaround (route the mod through mod.io's
# load path so Pugstorm's source-extract code doesn't hit the Wine bug).
# See docs/research/macos-crossover-wine-workaround.md for the full story.
# Set SKIP_MACOS_INSTALL=1 to opt out of the workaround step.
#
# Exit codes:
#   0   Build succeeded (and on macOS, install step also succeeded)
#   1   Env var missing or invalid path
#   2   Unity binary returned non-zero (build failure or Unity crash)
#   3   macOS install step failed

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

# 3. Refresh symlinks into the SDK clone. Idempotent; cheap; self-heals
# after worktree switches or repo moves where existing symlinks would dangle.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/link.sh" >/dev/null

# 4. Invoke Unity.
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
    echo "✓ Build complete."
else
    echo "✗ Build failed. Check Unity log output above for errors." >&2
    exit 2
fi

# 5. On macOS, apply the CrossOver/Wine workaround.
if [ "$(uname -s)" = "Darwin" ] && [ -z "${SKIP_MACOS_INSTALL:-}" ]; then
    echo
    if "$SCRIPT_DIR/install-macos.sh"; then
        echo "✓ macOS install complete. Launch Core Keeper to load."
        echo "  Reminder: do NOT open the in-game Mod menu."
    else
        echo "✗ macOS install step failed." >&2
        exit 3
    fi
else
    echo "  Restart Core Keeper to load."
fi

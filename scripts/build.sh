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

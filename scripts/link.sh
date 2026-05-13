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
ln -sfn "$REPO_ROOT/src/DisableDurabilityMod.cs"  DisableDurabilityMod.cs
ln -sfn "$REPO_ROOT/src/NoDurabilityLossPatch.cs" NoDurabilityLossPatch.cs
ln -sfn "$REPO_ROOT/src/ModConfig.cs"             ModConfig.cs
ln -sfn "$REPO_ROOT/src/Editor/CLIBuildHelper.cs" Editor/CLIBuildHelper.cs
ln -sfn "$REPO_ROOT/config/config.json"           config.json

echo "✓ Symlinks created in $SDK_MOD_DIR:"
ls -la DisableDurabilityMod.cs NoDurabilityLossPatch.cs ModConfig.cs Editor/CLIBuildHelper.cs config.json

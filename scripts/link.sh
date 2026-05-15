#!/usr/bin/env bash
# scripts/link.sh — Idempotently symlink the mod into the shared SDK clone.
#
# The mod's canonical files live in this repo under `unity/`, laid out as a
# 1:1 mirror of the SDK's `Assets/` tree. This script links that mirror into
# the SDK clone so Unity builds against it:
#
#   $SDK_PATH/Assets/DisableDurability            -> unity/DisableDurability/   (dir symlink)
#   $SDK_PATH/Assets/DisableDurability.asset      -> unity/DisableDurability.asset
#   $SDK_PATH/Assets/DisableDurability.asset.meta -> unity/DisableDurability.asset.meta
#   $SDK_PATH/Assets/DisableDurability.meta       -> unity/DisableDurability.meta
#
# The single directory symlink captures every file inside the mod folder —
# including ones the Unity Editor adds later — so nothing has to be wired up
# here by hand. The three Assets-level files sit beside the mod folder (the
# ModBuilderSettings asset + the folder's own .meta) and need their own links.
#
# Required env vars (set in .envrc):
#   SDK_PATH   Path to the cloned Pugstorm CoreKeeperModSDK
#
# The symlinks encode an absolute path, so they dangle after a worktree
# switch or repo move. `build.sh` re-runs this on every build; run it
# standalone only when iterating on the SDK side outside of `build.sh`.

set -euo pipefail

: "${SDK_PATH:?must be set in .envrc}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$SDK_PATH/Assets"
MIRROR="$REPO_ROOT/unity"

if [ ! -d "$ASSETS" ]; then
    echo "ERROR: SDK Assets dir not found: $ASSETS" >&2
    echo "Is SDK_PATH correct, and has the SDK been set up?" >&2
    exit 1
fi

if [ ! -d "$MIRROR/DisableDurability" ]; then
    echo "ERROR: mod mirror not found: $MIRROR/DisableDurability" >&2
    exit 1
fi

# -s symbolic, -f overwrite existing link, -n don't dereference an existing
# symlink-to-dir (so re-runs replace the link instead of nesting inside it).
ln -sfn "$MIRROR/DisableDurability"            "$ASSETS/DisableDurability"
ln -sfn "$MIRROR/DisableDurability.asset"      "$ASSETS/DisableDurability.asset"
ln -sfn "$MIRROR/DisableDurability.asset.meta" "$ASSETS/DisableDurability.asset.meta"
ln -sfn "$MIRROR/DisableDurability.meta"       "$ASSETS/DisableDurability.meta"

echo "✓ Symlinks created in $ASSETS:"
ls -la "$ASSETS/DisableDurability" "$ASSETS/DisableDurability.asset" \
       "$ASSETS/DisableDurability.asset.meta" "$ASSETS/DisableDurability.meta"

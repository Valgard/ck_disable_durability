#!/usr/bin/env bash
# scripts/install-macos.sh — Workaround installer for macOS / CrossOver.
#
# Pugstorm's mod loader fails to extract Scripts/ from locally built mods
# under Wine due to a `\\?\C:\…` path bug in RemoveDirectoryRecursive.
# Mods downloaded via mod.io are loaded from a different codepath that
# avoids the bug. This script makes a locally built mod look like a
# mod.io-installed mod by populating the three places the loader checks:
#
#   1. mod.io/<game_id>/mods/<mod_id>_<modfile_id>/   (extracted)
#   2. <Temp>/Pugstorm/Core Keeper/<game_id>/<mod_id>_<modfile_id>.zip (cache)
#   3. mod.io/<game_id>/state.json — subscribedMods + mods.<mod_id> entry
#
# Full background: docs/research/macos-crossover-wine-workaround.md.
#
# Required env vars (set in .envrc):
#   MOD_INSTALL_PATH   The directory that contains the built `DisableDurability/`
#                      mod folder (the destination `scripts/build.sh` writes to).
#
# Optional env vars:
#   CK_BOTTLE_PATH     Path to the CrossOver bottle containing Core Keeper.
#                      Defaults to "$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper".
#                      Override only if your bottle has a non-default name.
#
# Idempotent — safe to re-run after each `./scripts/build.sh`.
#
# IMPORTANT: after running this, launch Core Keeper but DO NOT open the
# in-game Mod menu. Opening it triggers a mod.io API sync that discovers
# the fake mod ID does not exist server-side and deletes the cache.

set -euo pipefail

: "${MOD_INSTALL_PATH:?must be set in .envrc — see .envrc.example}"

# --- Project-specific constants ----------------------------------------------

GAME_ID="5289"             # Core Keeper's mod.io game ID.
FAKE_MOD_ID="9999999"      # Any numeric ID not present in mod.io's catalog.
FAKE_MODFILE_ID="1"        # Pugstorm uses this as the cached modfile version.
MOD_NAME="DisableDurability"
MOD_NAME_ID="disable-durability"
MOD_DISPLAY_NAME="Disable Durability"
MOD_SUMMARY="Items never lose durability when used."

# --- Resolve bottle path and derive loader paths -----------------------------

# CrossOver bottle root. Override CK_BOTTLE_PATH in .envrc if your bottle name differs.
CK_BOTTLE_PATH="${CK_BOTTLE_PATH:-$HOME/Library/Application Support/CrossOver/Bottles/Core Keeper}"

if [ ! -d "$CK_BOTTLE_PATH" ]; then
    echo "ERROR: CrossOver bottle not found at:" >&2
    echo "       $CK_BOTTLE_PATH" >&2
    echo "       Set CK_BOTTLE_PATH in .envrc if your bottle has a different name." >&2
    exit 1
fi

WINE_USER="crossover"   # CrossOver's default Wine username; adjust if your bottle differs.

SRC="$MOD_INSTALL_PATH/$MOD_NAME"
MODIO_BASE="$CK_BOTTLE_PATH/drive_c/users/Public/mod.io/$GAME_ID"
MODIO_DST="$MODIO_BASE/mods/${FAKE_MOD_ID}_${FAKE_MODFILE_ID}"
ZIP_DIR="$CK_BOTTLE_PATH/drive_c/users/$WINE_USER/AppData/Local/Temp/Pugstorm/Core Keeper/$GAME_ID"
ZIP_DST="$ZIP_DIR/${FAKE_MOD_ID}_${FAKE_MODFILE_ID}.zip"
STATE_JSON="$MODIO_BASE/state.json"
MODLOADER_CACHE="$CK_BOTTLE_PATH/drive_c/users/$WINE_USER/AppData/Local/Temp/Pugstorm/Core Keeper/ModLoader/$MOD_NAME"

# --- Sanity check on the built mod -------------------------------------------

if [ ! -f "$SRC/ModManifest.json" ]; then
    echo "ERROR: no built mod at $SRC/ModManifest.json" >&2
    echo "       Run ./scripts/build.sh first." >&2
    exit 1
fi

echo "Installing $MOD_NAME for macOS / CrossOver…"
echo "  Source:    $SRC"
echo "  mod.io:    $MODIO_DST"
echo "  Cache zip: $ZIP_DST"

# --- 1. Copy extracted mod into mod.io path ----------------------------------

rm -rf "$MODIO_DST"
mkdir -p "$MODIO_DST"
cp -R "$SRC/ModManifest.json" "$MODIO_DST/"
[ -d "$SRC/Scripts" ] && cp -R "$SRC/Scripts" "$MODIO_DST/"
[ -d "$SRC/Bundles" ] && cp -R "$SRC/Bundles" "$MODIO_DST/"

# macOS extended attributes can trip Wine in some operations; strip defensively.
xattr -rc "$MODIO_DST/" 2>/dev/null || true

# --- 2. Build the ZIP at the loader's expected cache path --------------------

mkdir -p "$ZIP_DIR"
rm -f "$ZIP_DST"

# zip must produce a flat archive: Bundles/, Scripts/, ModManifest.json at root,
# matching how mods downloaded by Pugstorm's client are packaged.
( cd "$SRC" && zip -qr "$ZIP_DST" Bundles Scripts ModManifest.json )

# --- 3. Patch state.json to register our fake mod ----------------------------

if [ ! -f "$STATE_JSON" ]; then
    echo "ERROR: $STATE_JSON not found. Has the game ever launched with mod.io enabled?" >&2
    exit 1
fi

# Backup once; do not overwrite an existing backup.
[ -f "$STATE_JSON.macos-backup" ] || cp "$STATE_JSON" "$STATE_JSON.macos-backup"

# Find the first user ID under existingUsers (typically the only one).
USER_ID="$(jq -r '.existingUsers | keys[0]' "$STATE_JSON")"
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "ERROR: could not find a user under existingUsers in $STATE_JSON." >&2
    exit 1
fi

# Add the fake mod to subscribedMods if not already, and write/refresh the
# stub mod entry. jq handles both cases idempotently.
jq --arg user "$USER_ID" \
   --arg modid "$FAKE_MOD_ID" \
   --argjson modidNum "$FAKE_MOD_ID" \
   --argjson modfileNum "$FAKE_MODFILE_ID" \
   --arg name "$MOD_NAME" \
   --arg nameId "$MOD_NAME_ID" \
   --arg displayName "$MOD_DISPLAY_NAME" \
   --arg summary "$MOD_SUMMARY" \
   '
   (.existingUsers[$user].subscribedMods) |=
       (if index($modid) then . else . + [$modid] end)
   |
   .mods[$modid] = {
       currentModfile: {
           id: $modfileNum,
           mod_id: $modidNum,
           version: "1.0.0",
           filename: ($name + ".zip")
       },
       modObject: {
           id: $modidNum,
           game_id: 5289,
           status: 1,
           visible: 1,
           name: $name,
           name_id: $nameId,
           summary: $summary,
           modfile: { id: $modfileNum, mod_id: $modidNum }
       }
   }
   ' "$STATE_JSON" > "$STATE_JSON.tmp"
mv "$STATE_JSON.tmp" "$STATE_JSON"

# --- 4. Clean the ModLoader cache for this mod -------------------------------
# The loader will not touch this path for mod.io-routed mods, but a stale entry
# from an earlier StreamingAssets-style install can still trip future runs.

rm -rf "$MODLOADER_CACHE"

echo "✓ Install complete."
echo
echo "  Next: launch Core Keeper. Do NOT open the in-game Mod menu — that"
echo "  triggers a mod.io API sync that will delete this fake entry."

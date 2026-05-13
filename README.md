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

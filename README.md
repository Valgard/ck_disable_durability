# Disable Durability

A small Core Keeper mod that prevents item durability from decreasing when items are used. Built on the official Pugstorm `CoreKeeperModSDK`.

## What it does

While the mod is enabled, the game skips the durability-decrement code path for items in use. The durability bar stays at whatever value the item had when the mod loaded — items at 100/100 stay full; items at 30/100 stay at 30/100.

**This is not a repair mod.** Items keep their current durability — they do not regenerate to maximum.

## Requirements

- Core Keeper (Steam, PC build)
- Pugstorm `CoreKeeperModSDK` toolchain to build (developer-side only)
- For multiplayer: install on both client and server.

## Configuration

There is no runtime `config.json` — Pugstorm's RoslynCSharp sandbox blocks file
I/O. Configuration lives in a source constant in
`unity/DisableDurability/ModConfig.cs`; edit it and rebuild to change behavior:

| Constant | Default | Vanilla | Effect |
|----------|---------|---------|--------|
| `enabled` | `true` | — | Master switch. When `false`, the patch early-returns and item durability decreases exactly as vanilla. |

## Build (developer)

See `CLAUDE.md` for the build and deploy procedure.

## Publishing

Publish a new version to mod.io:

1. Bump the topmost `## [x.y.z]` entry in `CHANGELOG.md`.
2. One-time only: open the Pugstorm Mod SDK window in Unity and log in via
   the "Log in" tab.
3. Close the Unity Editor, then run:

   ```bash
   source .envrc
   ../utils/upload.sh            # or: ../utils/upload.sh --dry-run
   ```

A newly created mod.io profile is hidden — open its profile page and set it
visible once you have reviewed it.

## License

Personal-use, non-commercial — Pugstorm Core Keeper EULA. Built against the
official `CoreKeeperModSDK`. Source on GitHub; contributions welcome.

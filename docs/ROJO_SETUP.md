# Hatch an Anime: Rojo Setup

## Tools

- Rojo **7.7.0**, pinned in `rokit.toml`. Install with [Rokit](https://github.com/rojo-rbx/rokit): `rokit install`.
- Rojo Studio plugin of the same version.
- Recommended for VS Code: **Luau Language Server** (`JohnnyMorganz.luau-lsp`). It reads `default.project.json` to resolve `require`s.

## How the project file works

- The root `DataModel` and every service/folder node use `"$ignoreUnknownInstances": true`. Rojo only manages the scripts listed in the project. Models, GUIs, parts, sounds and Studio-made remotes stay owned by the place.
- Each script is an explicit node:
  ```json
  "PlayerDataService": { "$path": "src/server/PlayerData/PlayerDataService.server.luau" }
  ```
  The **key** is the instance name, and the node's **position** is its runtime location.
- Folders that hold scripts inside place-owned models carry a `$className` (`Model`, `ScreenGui`, `Tool`, …) so Rojo can build them standalone. During a live sync they match the existing instances by name.
- Originally-disabled scripts:
  ```json
  "EggStealServer": { "$path": "…", "$properties": { "Disabled": true } }
  ```
- A single file may back several nodes. `HatchGoo.server.luau` is used by four templates, so editing it updates all four.

## Commands

```sh
# Check the project resolves (catches bad $path entries)
rojo build default.project.json -o build-check.rbxlx

# Live sync into Studio
rojo serve default.project.json

# Sourcemap for luau-lsp / other tooling (optional, git-ignored)
rojo sourcemap default.project.json -o sourcemap.json
```

## Safe first sync

1. Open a **copy** of the place (`result.rbxl` is the reference backup; never overwrite it).
2. `rojo serve`, then connect from the plugin. Review the plugin's change list before accepting. Expect **no** script source changes, because sources match the export.
3. Check that the scripts listed as "Disabled = yes" in [SCRIPT_MIGRATION.md](SCRIPT_MIGRATION.md) are still disabled in Explorer (most importantly `ServerScriptService.EggSteal.EggStealServer`).
4. Play-test in the copy before publishing.

## Known mapping caveats

- **59 archived sources are not mapped.** Their Explorer ancestry was ambiguous at export. The files are kept in `archive/_ARCHIVE/` for reference only.
- **ScreenGui/Model properties** such as `ResetOnSpawn` are not represented in the project. They keep their place values during a live sync, but a standalone `rojo build` uses Roblox defaults. Do not ship a place produced only by `rojo build`.
- **Same-named siblings.** If two sibling instances in the place share a name, Rojo matches the first one. The export already marked such cases as unmapped.

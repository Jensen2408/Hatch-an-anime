# Hatch an Anime: Rojo project

Script sources for the Roblox game **Hatch an Anime**, exported from `result.rbxl` and organised by feature.
(The folder name `StealAGhost_Rojo` is historical; this is not the Steal a Ghost game.)

```
src/client/   LocalScripts, grouped by feature (Bootstrap, UI, Egg, Hatching, …)
src/server/   Scripts and server modules (PlayerData, Economy, Eggs, Plots, Admin, …)
src/shared/   ReplicatedStorage modules: client-visible (Catalogs, Config, UI, …)
archive/      historical backups, still mapped to ServerStorage._ARCHIVE and backup folders
docs/         audit, architecture, dependencies, migration map, Rojo setup, refactor report
```

The filesystem layout is **independent of the Roblox hierarchy**. Every script's runtime location is set by its node in `default.project.json`. Start with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quick start

```sh
rokit install                               # Rojo 7.7.0 (rokit.toml)
rojo build default.project.json -o check.rbxlx   # sanity check
rojo serve default.project.json             # live sync; connect from a COPY of the place first
```

See [docs/ROJO_SETUP.md](docs/ROJO_SETUP.md) before the first sync.

## Safety

- `result.rbxl` is the original place backup. Do not overwrite it.
- Models, GUIs, maps and Studio-created remotes are **not** in this repo. They stay managed in Studio (`$ignoreUnknownInstances`).
- Do not rename DataStores (`PlayerData_v1`, `ShopData_v2`, …), remotes, or instances without updating every reference. See [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).
- Scripts disabled in the original place are kept disabled via `$properties.Disabled`.
- Known bugs and security issues (not yet fixed) are listed in [docs/PROJECT_AUDIT.md](docs/PROJECT_AUDIT.md).

## Metadata

`script-manifest.json` has one entry per exported script:

- `fullpath`: the runtime path.
- `path`: the current file.
- `exportPath` / `originalPath`: earlier locations.
- `class`, `disabled`, `runContext`.

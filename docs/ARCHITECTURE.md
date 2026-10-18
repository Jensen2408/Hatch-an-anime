# Hatch an Anime: Architecture

## Two hierarchies, deliberately separate

There are two separate trees:

- **Filesystem tree** (`src/…`): grouped by *feature*, for humans and AI tools.
- **Roblox runtime tree** (`ServerScriptService/…`, `StarterPlayerScripts/…`): what scripts actually see through `script.Parent`, `WaitForChild` and `require`.

`default.project.json` connects the two. **Every script has an explicit node** (`"$path": "src/…"`), so a file's location on disk has no effect on where it lands in the place. The runtime tree is byte-for-byte the same as the original export (see [REFACTOR_REPORT.md](REFACTOR_REPORT.md)).

Consequences:

- Moving a file on disk only requires updating its `$path`. Requires keep working.
- Changing where a script *runs* means editing the node's position in `default.project.json` **and** every `script.Parent…`/`WaitForChild` path that reaches it. Treat that as a code change, not a move.
- Non-script instances (models, GUIs, parts, remotes created in Studio) are not in the repo. Every service/folder node uses `$ignoreUnknownInstances: true`, so Rojo leaves them alone.

## Filesystem layout

```text
src/
├── client/            LocalScripts (and two client-side modules)
│   ├── Bootstrap/       ReplicatedFirst: loading screen, startup preload, backpack bootstrap
│   ├── UI/
│   │   ├── Screens/     scripts living inside StarterGui ScreenGuis (GameMenus, MoneyDisplay)
│   │   └── Controllers/ HUD / skin / overlay controllers from StarterPlayerScripts
│   ├── Admin/           owner panel, admin terminal, staff announcements, VIP tag
│   ├── Audio/           background music, music settings, UI audio
│   ├── Characters/      character animation, info cards, floating/hatched displays
│   ├── Cinematics/      owner-only trailer and camera tools
│   ├── Effects/         aura, gold FX, mutation board, night sky, showcase FX
│   ├── Egg/             egg labels, pickup feedback, carry/steal client
│   ├── Hatching/        hatch cinematic, hatch FX starter, liquid visuals
│   ├── Inventory/       character inventory starter
│   ├── Plot/            construction, money stand, portal, plot prompts
│   ├── Temple/          temple effects, wind, upgrade camera shake
│   ├── Tutorial/        first-hatch tutorial, join arrival
│   ├── Weapons/         bat motion, weapon preload
│   └── World/           river, waterfall, water FX, conveyor motion
├── server/            Scripts and server-only ModuleScripts
│   ├── PlayerData/      saves, restore, respawn item keeping, tutorial flags
│   ├── Economy/         money stands, upgrade effects, no-earn accounts
│   ├── Shops/           purchases, gamepasses, daily rewards
│   ├── Eggs/            conveyors, river eggs, selling, EggSteal/
│   ├── Hatching/        camera gate, hatch video, HatchFX/, Templates/HatchGoo
│   ├── Characters/      rewards, sizing, placement, CharacterInventory/
│   ├── Mutations/       mutation rules, drop timer, gold FX attributes
│   ├── Plots/           plot assignment, chambers, home teleport
│   ├── Temple/          occupancy, slot unlocks, Construction/
│   ├── Carry/           two-hand carry
│   ├── Admin/           roles, owner panel and controls, punish, staff servers
│   ├── Services/        cross-server, feedback, night time, tool icons, Leaderboard/, GameMenu/
│   ├── World/           Portal/, PumpkinGentleman/
│   ├── Cinematics/      CineCam server
│   ├── Weapons/         weapon giver, WoodenBat/
│   ├── Storage/         ServerStorage modules and stored (inactive) scripts
│   └── DevTools/        ServerStorage/DevWorkshop (editable originals, rigs)
└── shared/            ModuleScripts in ReplicatedStorage (client-visible!)
    ├── Catalogs/        CharacterCatalog, CharacterEconomy, EggCatalog
    ├── Config/          tuning tables and per-feature config folders
    ├── UI/              shared UI modules, Leaderboard/
    ├── Admin/           OwnerPanel/ UI kit
    ├── Characters/      CharacterInfo/
    ├── Effects/         gold FX modules
    ├── Egg/             EggSteal/
    ├── Hatching/        IncubatorController, HatchFX/
    ├── Inventory/       CharacterInventory/
    ├── Temple/          Construction/
    └── World/           Portal/, WaterfallRiver/, PirateEggConveyor/

archive/               historical sources, still mapped to their original ServerStorage paths
├── _ARCHIVE/            ServerStorage._ARCHIVE (593 sources, 59 of them unmapped)
└── ServerStorage_Backups/  ServerStorage/Before*, Backup_*, *_v1_* folders
```

A sub-folder named after a Roblox folder (for example `Eggs/EggSteal/`, `Services/Leaderboard/`) means those files share that **runtime** folder. Keep them together, because they reach each other through `script.Parent`.

The side folder means *where the code runs*, not which Roblox service it sits in:

- `server/World/PumpkinGentleman/PumpkinIdle.server.luau` runs on the server but lives in **Workspace**.
- `shared/World/PirateEggConveyor/RollingMotion.luau` is a Workspace module required by client scripts.
- `server/DevTools/.../Animate.client.luau` is a LocalScript stored inside a ServerStorage rig, so it never runs.

The authoritative runtime path for any file is its node in `default.project.json` (also `fullpath` in `script-manifest.json`).

## File naming

| Extension | Roblox class | RunContext |
|---|---|---|
| `Name.server.luau` | Script | Legacy (0) |
| `Name.client.luau` | LocalScript | n/a |
| `Name.luau` | ModuleScript | n/a |

The instance name comes from the **project key**, not the file name. Keep both identical.

## Disabled scripts

Originally-disabled scripts carry `"$properties": { "Disabled": true }` on their node. Remove that line to enable a script; never delete the node.

## Adding a new feature

1. Put the file in the feature folder of the side where it runs (`src/server/<Feature>/…`).
2. Add a node to `default.project.json` at the runtime location it needs, for example:
   ```json
   "MyService": { "$path": "src/server/Economy/MyService.server.luau" }
   ```
   under `ServerScriptService`.
3. Server-only data (DataStore names, secrets, prices that must not be trusted) never goes in `src/shared`.
4. Validate every remote argument on the server (type, `x == x` for NaN, range, ownership, distance, rate limit), following `EggSellService` and `TempleSlotUnlocks.Purchase`.
5. Run `rojo build default.project.json -o test.rbxlx` and fix any `$path` error before syncing.

## Conventions observed in the code

- Services are fetched with `game:GetService` at the top of a file.
- Remotes are created server-side with the `X:FindFirstChild(name) or Instance.new(...)` pattern. Clients use `WaitForChild`.
- Feature "packages" (Leaderboard, CharacterInventory, GameMenu) follow *Config / Service (server) / Client / View* modules plus a tiny starter Script/LocalScript. Prefer this pattern for new systems.
- Player state is exposed through attributes on `Player`, plots (`OwnerUserId`), and `workspace`.

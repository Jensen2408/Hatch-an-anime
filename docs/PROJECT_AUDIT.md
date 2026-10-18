# Hatch an Anime: Project Audit

Audit date: 2026-10-19. Source of truth: `result.rbxl`, `script-manifest.json`, and the exported sources.
The folder is still named `StealAGhost_Rojo`, but the game is **Hatch an Anime**.

## 1. Inventory

| | Count |
|---|---|
| Script sources exported from `result.rbxl` | 798 |
| Mapped in `default.project.json` (unique runtime paths) | 739 |
| Not mapped: Explorer ancestry was ambiguous at export time (all inside `_ARCHIVE`) | 59 |
| Live and dev sources under `src/` (after refactor) | 189 files / 192 script instances |
| Historical sources under `archive/` | 606 files |
| Lines of code under `src/` | ~28,600 |
| Scripts that were `Disabled` in the original place | 159 (153 of them mapped) |

Live script instances by side:

| Area | LocalScript | Script | ModuleScript |
|---|---|---|---|
| `src/client` | 60 | 0 | 2 |
| `src/server` | 1 (dev rig) | 48 | 30 |
| `src/shared` | 0 | 0 | 51 |

### Static checks

- luau-lsp in VS Code reported **0 errors and 0 warnings** across all 800 analysed files.
- Every `$path` exists, and `rojo build` succeeds.
- No class/extension mismatches (`.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript).
- All `require` calls use runtime paths (`script.Parent`, `game:GetService(...)`, `ReplicatedStorage.X`), never file paths.

## 2. Major systems

| System | Server | Shared | Client |
|---|---|---|---|
| Player data / saves | `PlayerDataService`, `SaveRestore`, `KeepItemsOnRespawn`, `TutorialProgress` | | |
| Economy | `MoneyStandServer`, `MoneyStandOwnership`, `UpgradeEffects`, `NoEarnAccounts` | `UpgradePrices`, `CharacterEconomy` | `MoneyStandClient`, `MoneyLogic` |
| Shop / monetisation | `ShopService` | `ShopSystem/ShopConfig` | `MenuLogic` (shop tab) |
| Eggs | `ConveyorEggs`, `EggSellService`, `PirateEggFreeConveyor`, `RiverEgg*` | `EggCatalog`, `EggLabel`, `EggUIStyle` | `EggLabelsClient`, `EggPickupFeedback`, `RiverEggCarryClient` |
| Egg steal (currently **off**) | `EggSteal/EggStealServer` (Disabled), `EggStealService` | `EggSteal/*` | `EggStealClientStart`, `StolenEggCarryPose` |
| Hatching | `HatchCameraGate`, `HatchVideoService`, `HatchFX/HatchFXServer`, template `HatchGoo` | `IncubatorController`, `EggHatchTiming`, `HatchFX/*` | `CinematicHatch`, `HatchFXClientStart`, `HatchLiquidVisuals` |
| Characters | `EggCharacterRewards`, `CharacterSize`, `BrainrotPlacement`, `CharacterInventory/*` | `CharacterCatalog`, `CharacterInfo/*`, `CharacterInventory/*` | `CharacterAnimator`, `CharacterInfoClient`, `FloatingCharacters` |
| Plots and temple | `PlotManager`, `PlotChambers`, `PlotReadyFlag`, `HomeAndBubbles`, `TempleOccupancy`, `TempleSlotUnlocks`, `Construction/*` | `TempleAppearanceThemes`, `Construction/*` | `ConstructionClientStart`, `PromptCards`, `GoldTempleEffects` |
| Mutations / gold FX | `Mutations`, `MutationDropService`, `GoldFXServer` | `GoldCharacterFX`, `RichGoldFinish` | `GoldFXClient`, `AuraFlipbookPump`, `MutationDropBoardClient` |
| Carry | `TwoHandItemCarry*`, `CarryGripLayout` | | `StolenEggCarryPose` |
| Admin / staff | `AdminRoles`, `Owner*`, `PlayerPunish`, `StaffServerService`, `RoleTagServer` | `OwnerPanel/*` | `OwnerPanelClient`, `AdminTerminal`, `StaffAnnouncements` |
| Cross-server | `CrossServerService` (MessagingService) | | `StaffAnnouncements` |
| Leaderboards / menus / quests | `Leaderboard/*`, `GameMenu/*` | `Leaderboard/*`, `GameMenu/Config` | `LeaderboardClientStart`, `MenuLogic`, `GameHUD` |
| World / map | `Portal/*`, `PumpkinIdle` | `Portal/*`, `WaterfallRiver/*`, `RollingMotion` | `RiverFlow`, `Waterfall*`, `WaterFX`, `PortalClient` |
| Night time | `NighttimeClock`, `NighttimeService` | | `NighttimeSky`, `NighttimeHUD` |
| Cinematics (owner-only dev tools) | `CineCamServer` | `TrailerConfig` | `TrailerCinematic`, `TrailerDuoV2/V3`, `CineCamClient`, `HatchVideoClient` |
| Weapons | `WeaponGiver`, `WoodenBat/BatServer` | | `BatMotionClient`, `WeaponPreloadClient` |

See [DEPENDENCIES.md](DEPENDENCIES.md) for the require graph, DataStores, and remotes.

## 3. Issues found

### 3.1 Structural (fixed by this refactor)

1. **Rojo dropped every `Disabled` flag.** The export had no `.meta.json` files and no `$properties`, so `rojo build`/`rojo serve` produced 153 originally-disabled scripts as **enabled**. These include `EggStealServer` (it would switch on the steal system), `OwnerShowcase`, `UpgradeCameraShake`, and `OwnerShowcaseFX`. Fixed: `"$properties": { "Disabled": true }` is now set on each of those nodes.
2. **Filesystem layout mirrored Roblox services.** Everything sat in `ServerScriptService/`, `StarterPlayerScripts/` and similar folders, about 50 files per folder. Live code, dev tools and backups were mixed together in `ServerStorage`. Now grouped by feature (see [ARCHITECTURE.md](ARCHITECTURE.md)).
3. **Four byte-identical `HatchGoo` copies** (chamber template plus three incubator level templates). They now share one file.
4. **Backups inside the live tree.** `_ARCHIVE` (593 files) and seven `ServerStorage/Before*`/`Backup_*` folders are now under `archive/`. They still map to the same `ServerStorage` paths, so nothing disappears from the place.

### 3.2 Code issues (documented, NOT fixed: each fix changes runtime behaviour)

Ranked by severity. Line numbers refer to the files at their new locations.

| Sev | Location | Issue |
|---|---|---|
| High | `src/server/Admin/StaffServerService.luau:17-24` | `IsStaffServer` is set from client-controlled `TeleportData`. Anyone can mark a public server as staff-only, and then every non-staff player who joins is kicked. Use `game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0` instead. |
| High | `src/server/PlayerData/PlayerDataService.server.luau:224-229` | Saved tools are given before the plot wait. If no plot is assigned (full server) or `apply` errors, the snapshot keeps the old `tools`/`placed` while cash is saved. Result: sell, rejoin, sell again (duplication). |
| High (latent) | `src/server/Eggs/EggSteal/EggStealService.luau:643` + `EggStealConfig.VictimLeaves="Continue"` | Victim leaving mid-steal: the victim's save keeps the egg and the thief also gets it. Latent while steal stays disabled. |
| High | `src/server/Plots/HomeAndBubbles.server.luau:8-13` | `GoHome` has `COOLDOWN=0` and ignores `RiverEggCarryId`/ragdoll, so a carried river egg is secured instantly. |
| High | `src/server/Plots/PlotManager.server.luau:58-64` | An incremental temple upgrade leaves the model named `Temple_Retiring`. Later builds stack on top of it. |
| High (conditional) | `src/client/UI/Controllers/FigmaSkin.client.luau:276-313` | Reparents HUD buttons into `GameMenus`. If that ScreenGui has `ResetOnSpawn=true`, the buttons are lost after respawn. Not verifiable from scripts. |
| Medium | `src/server/Shops/ShopService.server.luau:245, 183, 120` | StarterPack/Daily cash granted before `PlayerDataService.apply` assigns `cash.Value = d.cash`, which overwrites it. |
| Medium | `src/server/Shops/ShopService.server.luau:226-259` | Player leaving during load gets re-added to `data`. Autosave then keeps writing stale shop data with no version check. |
| Medium | `src/server/Shops/ShopService.server.luau:205-219` | `ProcessReceipt` grants before saving. A failed save then leads to a double grant on retry. |
| Medium | `src/server/PlayerData/KeepItemsOnRespawn.server.luau:44` / `src/server/Admin/OwnerGameActions.luau:47` | Admin "Respawn" (`LoadCharacterAsync`) does not fire `Died`, so the backpack is lost. |
| Medium | `src/server/Admin/AdminRoles.luau:13-15` | Admin list is read once at server start, so a revoked admin keeps access on other servers. |
| Medium | `src/server/Services/FeedbackService.server.luau:20-25` | Cooldown is set after a yield. Parallel invokes bypass it and can spam the webhook. |
| Medium | `src/server/Weapons/WoodenBat/BatServer.server.luau:179-206` | Hit range is measured from the client-owned attacker position. |
| Medium | `src/server/Characters/BrainrotPlacement.server.luau:37-56` | Slot is marked `Occupied` before validation, so a failed assert locks the slot. |
| Medium | `src/shared/Config/GameMenu/Config.luau:51` | Weekly quest key includes the year, so it resets mid-week on 1 January (double claim). |
| Medium | `src/shared/Hatching/IncubatorController.luau:94-97`, `src/server/World/PumpkinGentleman/PumpkinIdle.server.luau` | Per-frame property writes on the server are replicated to all clients. |
| Medium | `src/client/Bootstrap/StartupLoader.luau:128` | Loading screen waits on the whole map's assets (up to 45 s). |
| Low | various | About 30 smaller items: connection leaks, missing `pcall` in loops, number formatting for NaN/inf/negative/≥1e15, F7 keybind clash between owner trailer tools, `_G` coupling between trailer scripts, unused `PlotReadyFlag`, a hard reference to `ServerStorage._ARCHIVE` in `HalloweenSwitch.luau:140`. |

Verified safe: sell/pick-up/collect remotes validate price, ownership and distance; PlayerData uses session locking, retries and `BindToClose`; leaderboard values come from server state; owner/admin remotes check roles server-side; nothing secret is in ReplicatedStorage.

### 3.3 Code-quality observations (not changed)

- **Oversized scripts:** `MenuLogic` (1246 lines), `InventoryView` (982), `TrailerCinematic` (962), `EggStealClient` (849), `LeaderboardView` (769), `GameHUD` (741), `EggStealService` (687), `InventoryService` (650).
- **Duplicated helpers:** about 8 different number formatters (`InventoryFormat`, `LeaderboardFormat`, `CharacterInfo/Style`, `EggLabel`, `HatchFXConfig.LegacyShort`, `CharacterEconomy.Format`, `CharacterCatalog.FormatPrice`, `GameMenu/Config.Full`). They produce **different output** (some truncate, some round, and the suffix sets differ), so merging them would change the UI.
- **Owner UserIds hard-coded** in several scripts (`TrailerConfig`, `HatchVideoService`, `CineCamClient`, `OwnerShowcase`, `OwnerControlServer`, `OwnerOverheadBanner`).
- **Globals:** `_G.__shopPrices` (MenuLogic), `_G.TrailerStartV1`, `_G.TrailerDuoStartV2/V3`, `_G.TrailerPicker`.
- **Place-owned instances** referenced by name but not created by any script (they exist only in `result.rbxl`): `RiverEggCarryState`, `RiverEggPurchaseFeedback`, `CollectRiverEgg`, `EggCollected`, `DropHeldItem`, `HatchCameraReady`, `GoldTempleSurfaces`, `ServerStorage.MoneyStandPlotTemplates`, `ServerStorage.AuxEggTemplates`, and others.
- **Dead code:** `InventoryClient.Open` returns immediately, `HatchReveal:Push` is never called, and several helpers in `EggStealClient` are unused. `EggLabelsClient` is a 0-byte script.

## 4. Proposed follow-up (requires play-testing in a copy of the place)

1. Fix the StaffServer TeleportData trust (small, isolated, high value).
2. Fix the PlayerData restore ordering and the ShopService cash overwrite. Test with a full server and a website purchase.
3. Add a `GoHome` cooldown and carry check, and rename `Temple_Retiring` back to `Temple` after an upgrade.
4. Move owner-only trailer/cinematic tools out of `StarterPlayerScripts` into a dev place, or behind one `DevTools` module with one owner list.
5. Only after the above: consolidate number formatting behind `InventoryFormat`, one call site at a time with visual checks.

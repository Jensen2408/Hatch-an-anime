# Hatch an Anime: Script Migration

Every source file was **moved without modification**: each one was checked by MD5 against the pre-refactor backup. Only `$path` values in `default.project.json` changed. Runtime paths, classes and RunContext are unchanged.

- **Machine-readable map** of all 798 moves: [`docs/script-moves.json`](script-moves.json) (`old export path → new path`).
- `script-manifest.json`: `path` is now the new file, `exportPath` is the path from the original Rojo export, `originalPath` is the path from the very first export, and `fullpath` is the runtime path.

## Rules

| Old location | New location |
|---|---|
| `src/server/ServerStorage/_ARCHIVE/**` | `archive/_ARCHIVE/**` (same sub-structure, includes the 59 unmapped sources) |
| `src/server/ServerStorage/{Before*,Backup_*,CharacterInfoUI_v1_*,LeaderboardBeforePodiumFix_*}/**` | `archive/ServerStorage_Backups/**` |
| `ServerStorage/HatchChamberTemplate/HatchGoo` and `ServerStorage/IncubatorUpgradeTemplates/Level{1,2,3}/HatchGoo` (4 identical files) | one file: `src/server/Hatching/Templates/HatchGoo.server.luau`, referenced by all four nodes |
| everything else under `src/` | feature folder (table below) |

## Live and dev scripts

"Disabled = yes" means the script was disabled in the original place. It is now built disabled again via `$properties`.

| Runtime path (unchanged) | Class | Old file (export) | New file | Disabled |
|---|---|---|---|---|
| `StarterPlayer/StarterPlayerScripts/AdminTerminal` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/AdminTerminal.client.luau` | `src/client/Admin/AdminTerminal.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/OwnerPanelClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/OwnerPanelClient.client.luau` | `src/client/Admin/OwnerPanelClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/StaffAnnouncements` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/StaffAnnouncements.client.luau` | `src/client/Admin/StaffAnnouncements.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/VIPChatTag` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/VIPChatTag.client.luau` | `src/client/Admin/VIPChatTag.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/BackgroundMusic` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.luau` | `src/client/Audio/BackgroundMusic.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/MusicSettings` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/MusicSettings.client.luau` | `src/client/Audio/MusicSettings.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/UIAudioClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/UIAudioClient.client.luau` | `src/client/Audio/UIAudioClient.client.luau` |  |
| `ReplicatedFirst/CustomInventoryBootstrap` | LocalScript | `src/client/ReplicatedFirst/CustomInventoryBootstrap.client.luau` | `src/client/Bootstrap/CustomInventoryBootstrap.client.luau` |  |
| `ReplicatedFirst/LoadingScreen` | LocalScript | `src/client/ReplicatedFirst/LoadingScreen.client.luau` | `src/client/Bootstrap/LoadingScreen.client.luau` |  |
| `ReplicatedFirst/LoadingScreen/Config` | ModuleScript | `src/client/ReplicatedFirst/LoadingScreen/Config.luau` | `src/client/Bootstrap/LoadingScreen/Config.luau` |  |
| `ReplicatedFirst/StartupLoader` | ModuleScript | `src/client/ReplicatedFirst/StartupLoader.luau` | `src/client/Bootstrap/StartupLoader.luau` |  |
| `StarterPlayer/StarterPlayerScripts/CharacterAnimator` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/CharacterAnimator.client.luau` | `src/client/Characters/CharacterAnimator.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/CharacterInfoClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/CharacterInfoClient.client.luau` | `src/client/Characters/CharacterInfoClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/FloatingCharacters` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/FloatingCharacters.client.luau` | `src/client/Characters/FloatingCharacters.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/GoldenLuffyIdle` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/GoldenLuffyIdle.client.luau` | `src/client/Characters/GoldenLuffyIdle.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/HatchedCharacterDisplay` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/HatchedCharacterDisplay.client.luau` | `src/client/Characters/HatchedCharacterDisplay.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/CineCamClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/CineCamClient.client.luau` | `src/client/Cinematics/CineCamClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/HatchVideoClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/HatchVideoClient.client.luau` | `src/client/Cinematics/HatchVideoClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/TrailerCinematic` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/TrailerCinematic.client.luau` | `src/client/Cinematics/TrailerCinematic.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/TrailerDuoV2` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/TrailerDuoV2.client.luau` | `src/client/Cinematics/TrailerDuoV2.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/TrailerDuoV3` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/TrailerDuoV3.client.luau` | `src/client/Cinematics/TrailerDuoV3.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/AuraFlipbookPump` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/AuraFlipbookPump.client.luau` | `src/client/Effects/AuraFlipbookPump.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/GoldFXClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/GoldFXClient.client.luau` | `src/client/Effects/GoldFXClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/MutationDropBoardClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/MutationDropBoardClient.client.luau` | `src/client/Effects/MutationDropBoardClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/NighttimeSky` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/NighttimeSky.client.luau` | `src/client/Effects/NighttimeSky.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/OwnerShowcaseFX` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/OwnerShowcaseFX.client.luau` | `src/client/Effects/OwnerShowcaseFX.client.luau` | yes |
| `StarterPlayer/StarterPlayerScripts/EggLabelsClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/EggLabelsClient.client.luau` | `src/client/Egg/EggLabelsClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/EggPickupFeedback` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/EggPickupFeedback.client.luau` | `src/client/Egg/EggPickupFeedback.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/EggStealClientStart` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/EggStealClientStart.client.luau` | `src/client/Egg/EggStealClientStart.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/RiverEggCarryClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/RiverEggCarryClient.client.luau` | `src/client/Egg/RiverEggCarryClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/StolenEggCarryPose` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/StolenEggCarryPose.client.luau` | `src/client/Egg/StolenEggCarryPose.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/CinematicHatch` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/CinematicHatch.client.luau` | `src/client/Hatching/CinematicHatch.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/HatchFXClientStart` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/HatchFXClientStart.client.luau` | `src/client/Hatching/HatchFXClientStart.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/HatchLiquidVisuals` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/HatchLiquidVisuals.client.luau` | `src/client/Hatching/HatchLiquidVisuals.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/CharacterInventoryStart` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/CharacterInventoryStart.client.luau` | `src/client/Inventory/CharacterInventoryStart.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/ConstructionClientStart` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/ConstructionClientStart.client.luau` | `src/client/Plot/ConstructionClientStart.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/MoneyStandClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/MoneyStandClient.client.luau` | `src/client/Plot/MoneyStandClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/PortalClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/PortalClient.client.luau` | `src/client/Plot/PortalClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/PromptCards` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/PromptCards.client.luau` | `src/client/Plot/PromptCards.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/GoldTempleEffects` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/GoldTempleEffects.client.luau` | `src/client/Temple/GoldTempleEffects.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/TempleWindAnimator` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/TempleWindAnimator.client.luau` | `src/client/Temple/TempleWindAnimator.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/UpgradeCameraShake` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/UpgradeCameraShake.client.luau` | `src/client/Temple/UpgradeCameraShake.client.luau` | yes |
| `StarterPlayer/StarterPlayerScripts/FirstHatchTutorial` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/FirstHatchTutorial.client.luau` | `src/client/Tutorial/FirstHatchTutorial.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/JoinArrival` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/JoinArrival.client.luau` | `src/client/Tutorial/JoinArrival.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/FeedbackClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/FeedbackClient.client.luau` | `src/client/UI/Controllers/FeedbackClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/FigmaSkin` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/FigmaSkin.client.luau` | `src/client/UI/Controllers/FigmaSkin.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/GameHUD` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/GameHUD.client.luau` | `src/client/UI/Controllers/GameHUD.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/LeaderboardClientStart` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/LeaderboardClientStart.client.luau` | `src/client/UI/Controllers/LeaderboardClientStart.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/LeaveEarningsOverlay` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/LeaveEarningsOverlay.client.luau` | `src/client/UI/Controllers/LeaveEarningsOverlay.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/NighttimeHUD` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/NighttimeHUD.client.luau` | `src/client/UI/Controllers/NighttimeHUD.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/OfflineEarningsUI` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/OfflineEarningsUI.client.luau` | `src/client/UI/Controllers/OfflineEarningsUI.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/PixelIconSharpener` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/PixelIconSharpener.client.luau` | `src/client/UI/Controllers/PixelIconSharpener.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/SharpUI` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/SharpUI.client.luau` | `src/client/UI/Controllers/SharpUI.client.luau` |  |
| `StarterGui/GameMenus/MenuLogic` | LocalScript | `src/client/StarterGui/GameMenus/MenuLogic.client.luau` | `src/client/UI/Screens/GameMenus/MenuLogic.client.luau` |  |
| `StarterGui/MoneyDisplay/MoneyLogic` | LocalScript | `src/client/StarterGui/MoneyDisplay/MoneyLogic.client.luau` | `src/client/UI/Screens/MoneyDisplay/MoneyLogic.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/BatMotionClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/BatMotionClient.client.luau` | `src/client/Weapons/BatMotionClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/WeaponPreloadClient` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/WeaponPreloadClient.client.luau` | `src/client/Weapons/WeaponPreloadClient.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/PirateEggConveyorMotion` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/PirateEggConveyorMotion.client.luau` | `src/client/World/PirateEggConveyorMotion.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/RiverFlow` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/RiverFlow.client.luau` | `src/client/World/RiverFlow.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/WaterFX` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/WaterFX.client.luau` | `src/client/World/WaterFX.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/WaterfallFallMotion` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/WaterfallFallMotion.client.luau` | `src/client/World/WaterfallFallMotion.client.luau` |  |
| `StarterPlayer/StarterPlayerScripts/WaterfallRiverMotion` | LocalScript | `src/client/StarterPlayer/StarterPlayerScripts/WaterfallRiverMotion.client.luau` | `src/client/World/WaterfallRiverMotion.client.luau` |  |
| `ServerScriptService/AdminRoles` | ModuleScript | `src/server/ServerScriptService/AdminRoles.luau` | `src/server/Admin/AdminRoles.luau` |  |
| `ServerScriptService/OwnerControlServer` | Script | `src/server/ServerScriptService/OwnerControlServer.server.luau` | `src/server/Admin/OwnerControlServer.server.luau` |  |
| `ServerScriptService/OwnerGameActions` | ModuleScript | `src/server/ServerScriptService/OwnerGameActions.luau` | `src/server/Admin/OwnerGameActions.luau` |  |
| `ServerScriptService/OwnerOverheadBanner` | Script | `src/server/ServerScriptService/OwnerOverheadBanner.server.luau` | `src/server/Admin/OwnerOverheadBanner.server.luau` |  |
| `ServerScriptService/OwnerPanelServer` | Script | `src/server/ServerScriptService/OwnerPanelServer.server.luau` | `src/server/Admin/OwnerPanelServer.server.luau` |  |
| `ServerScriptService/OwnerShowcase` | Script | `src/server/ServerScriptService/OwnerShowcase.server.luau` | `src/server/Admin/OwnerShowcase.server.luau` | yes |
| `ServerScriptService/PlayerPunish` | ModuleScript | `src/server/ServerScriptService/PlayerPunish.luau` | `src/server/Admin/PlayerPunish.luau` |  |
| `ServerScriptService/RoleTagServer` | Script | `src/server/ServerScriptService/RoleTagServer.server.luau` | `src/server/Admin/RoleTagServer.server.luau` |  |
| `ServerScriptService/StaffServerService` | ModuleScript | `src/server/ServerScriptService/StaffServerService.luau` | `src/server/Admin/StaffServerService.luau` |  |
| `ServerScriptService/CarryGripLayout` | ModuleScript | `src/server/ServerScriptService/CarryGripLayout.luau` | `src/server/Carry/CarryGripLayout.luau` |  |
| `ServerScriptService/TwoHandItemCarryServer` | Script | `src/server/ServerScriptService/TwoHandItemCarryServer.server.luau` | `src/server/Carry/TwoHandItemCarryServer.server.luau` |  |
| `ServerScriptService/TwoHandItemCarryService` | ModuleScript | `src/server/ServerScriptService/TwoHandItemCarryService.luau` | `src/server/Carry/TwoHandItemCarryService.luau` |  |
| `ServerScriptService/BrainrotPlacement` | Script | `src/server/ServerScriptService/BrainrotPlacement.server.luau` | `src/server/Characters/BrainrotPlacement.server.luau` |  |
| `ServerScriptService/CharacterInventory/InventoryServer` | Script | `src/server/ServerScriptService/CharacterInventory/InventoryServer.server.luau` | `src/server/Characters/CharacterInventory/InventoryServer.server.luau` |  |
| `ServerScriptService/CharacterInventory/InventoryService` | ModuleScript | `src/server/ServerScriptService/CharacterInventory/InventoryService.luau` | `src/server/Characters/CharacterInventory/InventoryService.luau` |  |
| `ServerScriptService/CharacterSize` | Script | `src/server/ServerScriptService/CharacterSize.server.luau` | `src/server/Characters/CharacterSize.server.luau` |  |
| `ServerScriptService/EggCharacterRewards` | ModuleScript | `src/server/ServerScriptService/EggCharacterRewards.luau` | `src/server/Characters/EggCharacterRewards.luau` |  |
| `ServerScriptService/CineCamServer` | Script | `src/server/ServerScriptService/CineCamServer.server.luau` | `src/server/Cinematics/CineCamServer.server.luau` |  |
| `ServerStorage/DevWorkshop/AnimRig_MovedFromWorkspace/Animate` | LocalScript | `src/server/ServerStorage/DevWorkshop/AnimRig_MovedFromWorkspace/Animate.client.luau` | `src/server/DevTools/DevWorkshop/AnimRig_MovedFromWorkspace/Animate.client.luau` |  |
| `ServerStorage/DevWorkshop/BUILD WORKSHOP/HATCH - EDITABLE ORIGINAL/HatchGoo` | Script | `src/server/ServerStorage/DevWorkshop/BUILD WORKSHOP/HATCH - EDITABLE ORIGINAL/HatchGoo.server.luau` | `src/server/DevTools/DevWorkshop/BUILD WORKSHOP/HATCH - EDITABLE ORIGINAL/HatchGoo.server.luau` | yes |
| `ServerStorage/DevWorkshop/HalloweenTemple_Deluxe/SpookyMotion` | Script | `src/server/ServerStorage/DevWorkshop/HalloweenTemple_Deluxe/SpookyMotion.server.luau` | `src/server/DevTools/DevWorkshop/HalloweenTemple_Deluxe/SpookyMotion.server.luau` |  |
| `ServerScriptService/MoneyStandOwnership` | Script | `src/server/ServerScriptService/MoneyStandOwnership.server.luau` | `src/server/Economy/MoneyStandOwnership.server.luau` |  |
| `ServerScriptService/MoneyStandServer` | Script | `src/server/ServerScriptService/MoneyStandServer.server.luau` | `src/server/Economy/MoneyStandServer.server.luau` |  |
| `ServerScriptService/NoEarnAccounts` | Script | `src/server/ServerScriptService/NoEarnAccounts.server.luau` | `src/server/Economy/NoEarnAccounts.server.luau` |  |
| `ServerScriptService/UpgradeEffects` | ModuleScript | `src/server/ServerScriptService/UpgradeEffects.luau` | `src/server/Economy/UpgradeEffects.luau` |  |
| `ServerScriptService/ConveyorEggs` | Script | `src/server/ServerScriptService/ConveyorEggs.server.luau` | `src/server/Eggs/ConveyorEggs.server.luau` |  |
| `ServerScriptService/EggSellService` | Script | `src/server/ServerScriptService/EggSellService.server.luau` | `src/server/Eggs/EggSellService.server.luau` |  |
| `ServerScriptService/EggSteal/EggStealServer` | Script | `src/server/ServerScriptService/EggSteal/EggStealServer.server.luau` | `src/server/Eggs/EggSteal/EggStealServer.server.luau` | yes |
| `ServerScriptService/EggSteal/EggStealService` | ModuleScript | `src/server/ServerScriptService/EggSteal/EggStealService.luau` | `src/server/Eggs/EggSteal/EggStealService.luau` |  |
| `ServerScriptService/PirateEggFreeConveyor` | Script | `src/server/ServerScriptService/PirateEggFreeConveyor.server.luau` | `src/server/Eggs/PirateEggFreeConveyor.server.luau` |  |
| `ServerScriptService/RiverEggCarryService` | ModuleScript | `src/server/ServerScriptService/RiverEggCarryService.luau` | `src/server/Eggs/RiverEggCarryService.luau` |  |
| `ServerScriptService/RiverEggPayment` | ModuleScript | `src/server/ServerScriptService/RiverEggPayment.luau` | `src/server/Eggs/RiverEggPayment.luau` |  |
| `ServerScriptService/RiverEggSpawnScheduler` | ModuleScript | `src/server/ServerScriptService/RiverEggSpawnScheduler.luau` | `src/server/Eggs/RiverEggSpawnScheduler.luau` |  |
| `ServerScriptService/HatchCameraGate` | ModuleScript | `src/server/ServerScriptService/HatchCameraGate.luau` | `src/server/Hatching/HatchCameraGate.luau` |  |
| `ServerScriptService/HatchFX/HatchFXServer` | ModuleScript | `src/server/ServerScriptService/HatchFX/HatchFXServer.luau` | `src/server/Hatching/HatchFX/HatchFXServer.luau` |  |
| `ServerScriptService/HatchVideoService` | Script | `src/server/ServerScriptService/HatchVideoService.server.luau` | `src/server/Hatching/HatchVideoService.server.luau` |  |
| `ServerStorage/HatchChamberTemplate/HatchGoo` | Script | `src/server/ServerStorage/HatchChamberTemplate/HatchGoo.server.luau` | `src/server/Hatching/Templates/HatchGoo.server.luau` |  |
| `ServerStorage/IncubatorUpgradeTemplates/Level1/HatchGoo` | Script | `src/server/ServerStorage/IncubatorUpgradeTemplates/Level1/HatchGoo.server.luau` | `src/server/Hatching/Templates/HatchGoo.server.luau` |  |
| `ServerStorage/IncubatorUpgradeTemplates/Level2/HatchGoo` | Script | `src/server/ServerStorage/IncubatorUpgradeTemplates/Level2/HatchGoo.server.luau` | `src/server/Hatching/Templates/HatchGoo.server.luau` |  |
| `ServerStorage/IncubatorUpgradeTemplates/Level3/HatchGoo` | Script | `src/server/ServerStorage/IncubatorUpgradeTemplates/Level3/HatchGoo.server.luau` | `src/server/Hatching/Templates/HatchGoo.server.luau` |  |
| `ServerScriptService/GoldFXServer` | Script | `src/server/ServerScriptService/GoldFXServer.server.luau` | `src/server/Mutations/GoldFXServer.server.luau` |  |
| `ServerScriptService/MutationDropService` | Script | `src/server/ServerScriptService/MutationDropService.server.luau` | `src/server/Mutations/MutationDropService.server.luau` |  |
| `ServerScriptService/Mutations` | ModuleScript | `src/server/ServerScriptService/Mutations.luau` | `src/server/Mutations/Mutations.luau` |  |
| `ServerScriptService/KeepItemsOnRespawn` | Script | `src/server/ServerScriptService/KeepItemsOnRespawn.server.luau` | `src/server/PlayerData/KeepItemsOnRespawn.server.luau` |  |
| `ServerScriptService/PlayerDataService` | Script | `src/server/ServerScriptService/PlayerDataService.server.luau` | `src/server/PlayerData/PlayerDataService.server.luau` |  |
| `ServerScriptService/SaveRestore` | ModuleScript | `src/server/ServerScriptService/SaveRestore.luau` | `src/server/PlayerData/SaveRestore.luau` |  |
| `ServerScriptService/TutorialProgress` | Script | `src/server/ServerScriptService/TutorialProgress.server.luau` | `src/server/PlayerData/TutorialProgress.server.luau` |  |
| `ServerScriptService/HomeAndBubbles` | Script | `src/server/ServerScriptService/HomeAndBubbles.server.luau` | `src/server/Plots/HomeAndBubbles.server.luau` |  |
| `ServerScriptService/PlotChambers` | Script | `src/server/ServerScriptService/PlotChambers.server.luau` | `src/server/Plots/PlotChambers.server.luau` |  |
| `ServerScriptService/PlotManager` | Script | `src/server/ServerScriptService/PlotManager.server.luau` | `src/server/Plots/PlotManager.server.luau` |  |
| `ServerScriptService/PlotReadyFlag` | Script | `src/server/ServerScriptService/PlotReadyFlag.server.luau` | `src/server/Plots/PlotReadyFlag.server.luau` |  |
| `ServerScriptService/CrossServerService` | ModuleScript | `src/server/ServerScriptService/CrossServerService.luau` | `src/server/Services/CrossServerService.luau` |  |
| `ServerScriptService/FeedbackService` | Script | `src/server/ServerScriptService/FeedbackService.server.luau` | `src/server/Services/FeedbackService.server.luau` |  |
| `ServerScriptService/GameMenu/GameAdapter` | ModuleScript | `src/server/ServerScriptService/GameMenu/GameAdapter.luau` | `src/server/Services/GameMenu/GameAdapter.luau` |  |
| `ServerScriptService/GameMenu/GameMenuServer` | Script | `src/server/ServerScriptService/GameMenu/GameMenuServer.server.luau` | `src/server/Services/GameMenu/GameMenuServer.server.luau` |  |
| `ServerScriptService/GameMenu/QuestService` | ModuleScript | `src/server/ServerScriptService/GameMenu/QuestService.luau` | `src/server/Services/GameMenu/QuestService.luau` |  |
| `ServerScriptService/Leaderboard/LeaderboardChampions` | Script | `src/server/ServerScriptService/Leaderboard/LeaderboardChampions.server.luau` | `src/server/Services/Leaderboard/LeaderboardChampions.server.luau` |  |
| `ServerScriptService/Leaderboard/LeaderboardServer` | Script | `src/server/ServerScriptService/Leaderboard/LeaderboardServer.server.luau` | `src/server/Services/Leaderboard/LeaderboardServer.server.luau` |  |
| `ServerScriptService/Leaderboard/LeaderboardService` | ModuleScript | `src/server/ServerScriptService/Leaderboard/LeaderboardService.luau` | `src/server/Services/Leaderboard/LeaderboardService.luau` |  |
| `ServerScriptService/NighttimeClock` | Script | `src/server/ServerScriptService/NighttimeClock.server.luau` | `src/server/Services/NighttimeClock.server.luau` |  |
| `ServerScriptService/NighttimeService` | ModuleScript | `src/server/ServerScriptService/NighttimeService.luau` | `src/server/Services/NighttimeService.luau` |  |
| `ServerScriptService/NoDropping` | Script | `src/server/ServerScriptService/NoDropping.server.luau` | `src/server/Services/NoDropping.server.luau` |  |
| `ServerScriptService/StartupAssetManifest` | Script | `src/server/ServerScriptService/StartupAssetManifest.server.luau` | `src/server/Services/StartupAssetManifest.server.luau` |  |
| `ServerScriptService/ToolIcons` | Script | `src/server/ServerScriptService/ToolIcons.server.luau` | `src/server/Services/ToolIcons.server.luau` |  |
| `ServerScriptService/ShopService` | Script | `src/server/ServerScriptService/ShopService.server.luau` | `src/server/Shops/ShopService.server.luau` |  |
| `ServerStorage/FutureUpdateContent/RiverBeforeGoldContentReservation` | Script | `src/server/ServerStorage/FutureUpdateContent/RiverBeforeGoldContentReservation.server.luau` | `src/server/Storage/FutureUpdateContent/RiverBeforeGoldContentReservation.server.luau` |  |
| `ServerStorage/HalloweenSwitch` | ModuleScript | `src/server/ServerStorage/HalloweenSwitch.luau` | `src/server/Storage/HalloweenSwitch.luau` |  |
| `ServerStorage/MoneyStandBuilder` | ModuleScript | `src/server/ServerStorage/MoneyStandBuilder.luau` | `src/server/Storage/MoneyStandBuilder.luau` |  |
| `ServerStorage/RestoreSurfaceAppearances` | ModuleScript | `src/server/ServerStorage/RestoreSurfaceAppearances.luau` | `src/server/Storage/RestoreSurfaceAppearances.luau` |  |
| `ServerStorage/StoredCollectAllZones/CollectAllZoneServer` | Script | `src/server/ServerStorage/StoredCollectAllZones/CollectAllZoneServer.server.luau` | `src/server/Storage/StoredCollectAllZones/CollectAllZoneServer.server.luau` | yes |
| `ServerScriptService/Construction/ConstructionService` | ModuleScript | `src/server/ServerScriptService/Construction/ConstructionService.luau` | `src/server/Temple/Construction/ConstructionService.luau` |  |
| `ServerScriptService/TempleOccupancy` | ModuleScript | `src/server/ServerScriptService/TempleOccupancy.luau` | `src/server/Temple/TempleOccupancy.luau` |  |
| `ServerScriptService/TempleSlotUnlocks` | ModuleScript | `src/server/ServerScriptService/TempleSlotUnlocks.luau` | `src/server/Temple/TempleSlotUnlocks.luau` |  |
| `ServerScriptService/WeaponGiver` | Script | `src/server/ServerScriptService/WeaponGiver.server.luau` | `src/server/Weapons/WeaponGiver.server.luau` |  |
| `ServerStorage/Weapons/WoodenBat/BatServer` | Script | `src/server/ServerStorage/Weapons/WoodenBat/BatServer.server.luau` | `src/server/Weapons/WoodenBat/BatServer.server.luau` |  |
| `ServerScriptService/Portal/PortalBuilder` | ModuleScript | `src/server/ServerScriptService/Portal/PortalBuilder.luau` | `src/server/World/Portal/PortalBuilder.luau` |  |
| `ServerScriptService/Portal/PortalServer` | Script | `src/server/ServerScriptService/Portal/PortalServer.server.luau` | `src/server/World/Portal/PortalServer.server.luau` |  |
| `ServerScriptService/Portal/PortalService` | ModuleScript | `src/server/ServerScriptService/Portal/PortalService.luau` | `src/server/World/Portal/PortalService.luau` |  |
| `Workspace/PumpkinGentleman/PumpkinIdle` | Script | `src/client/Workspace/PumpkinGentleman/PumpkinIdle.server.luau` | `src/server/World/PumpkinGentleman/PumpkinIdle.server.luau` |  |
| `ReplicatedStorage/OwnerPanel/ActivityLog` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/ActivityLog.luau` | `src/shared/Admin/OwnerPanel/ActivityLog.luau` |  |
| `ReplicatedStorage/OwnerPanel/Components` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/Components.luau` | `src/shared/Admin/OwnerPanel/Components.luau` |  |
| `ReplicatedStorage/OwnerPanel/ConfirmDialog` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/ConfirmDialog.luau` | `src/shared/Admin/OwnerPanel/ConfirmDialog.luau` |  |
| `ReplicatedStorage/OwnerPanel/PlayerRow` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/PlayerRow.luau` | `src/shared/Admin/OwnerPanel/PlayerRow.luau` |  |
| `ReplicatedStorage/OwnerPanel/StudPanel` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/StudPanel.luau` | `src/shared/Admin/OwnerPanel/StudPanel.luau` |  |
| `ReplicatedStorage/OwnerPanel/Theme` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/Theme.luau` | `src/shared/Admin/OwnerPanel/Theme.luau` |  |
| `ReplicatedStorage/OwnerPanel/Toast` | ModuleScript | `src/shared/ReplicatedStorage/OwnerPanel/Toast.luau` | `src/shared/Admin/OwnerPanel/Toast.luau` |  |
| `ReplicatedStorage/CharacterCatalog` | ModuleScript | `src/shared/ReplicatedStorage/CharacterCatalog.luau` | `src/shared/Catalogs/CharacterCatalog.luau` |  |
| `ReplicatedStorage/CharacterEconomy` | ModuleScript | `src/shared/ReplicatedStorage/CharacterEconomy.luau` | `src/shared/Catalogs/CharacterEconomy.luau` |  |
| `ReplicatedStorage/EggCatalog` | ModuleScript | `src/shared/ReplicatedStorage/EggCatalog.luau` | `src/shared/Catalogs/EggCatalog.luau` |  |
| `ReplicatedStorage/CharacterInfo/Adapter` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInfo/Adapter.luau` | `src/shared/Characters/CharacterInfo/Adapter.luau` |  |
| `ReplicatedStorage/CharacterInfo/Style` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInfo/Style.luau` | `src/shared/Characters/CharacterInfo/Style.luau` |  |
| `ReplicatedStorage/EggHatchTiming` | ModuleScript | `src/shared/ReplicatedStorage/EggHatchTiming.luau` | `src/shared/Config/EggHatchTiming.luau` |  |
| `ReplicatedStorage/GameMenu/Config` | ModuleScript | `src/shared/ReplicatedStorage/GameMenu/Config.luau` | `src/shared/Config/GameMenu/Config.luau` |  |
| `ReplicatedStorage/JoinArrival/Config` | ModuleScript | `src/shared/ReplicatedStorage/JoinArrival/Config.luau` | `src/shared/Config/JoinArrival/Config.luau` |  |
| `ReplicatedStorage/ShopSystem/ShopConfig` | ModuleScript | `src/shared/ReplicatedStorage/ShopSystem/ShopConfig.luau` | `src/shared/Config/ShopSystem/ShopConfig.luau` |  |
| `ReplicatedStorage/TempleAppearanceThemes` | ModuleScript | `src/shared/ReplicatedStorage/TempleAppearanceThemes.luau` | `src/shared/Config/TempleAppearanceThemes.luau` |  |
| `ReplicatedStorage/TrailerConfig` | ModuleScript | `src/shared/ReplicatedStorage/TrailerConfig.luau` | `src/shared/Config/TrailerConfig.luau` |  |
| `ReplicatedStorage/UpdateConfig` | ModuleScript | `src/shared/ReplicatedStorage/UpdateConfig.luau` | `src/shared/Config/UpdateConfig.luau` |  |
| `ReplicatedStorage/UpgradePrices` | ModuleScript | `src/shared/ReplicatedStorage/UpgradePrices.luau` | `src/shared/Config/UpgradePrices.luau` |  |
| `ReplicatedStorage/GoldCharacterFX` | ModuleScript | `src/shared/ReplicatedStorage/GoldCharacterFX.luau` | `src/shared/Effects/GoldCharacterFX.luau` |  |
| `ReplicatedStorage/RichGoldFinish` | ModuleScript | `src/shared/ReplicatedStorage/RichGoldFinish.luau` | `src/shared/Effects/RichGoldFinish.luau` |  |
| `ReplicatedStorage/EggSteal/EggStealClient` | ModuleScript | `src/shared/ReplicatedStorage/EggSteal/EggStealClient.luau` | `src/shared/Egg/EggSteal/EggStealClient.luau` |  |
| `ReplicatedStorage/EggSteal/EggStealConfig` | ModuleScript | `src/shared/ReplicatedStorage/EggSteal/EggStealConfig.luau` | `src/shared/Egg/EggSteal/EggStealConfig.luau` |  |
| `ReplicatedStorage/HatchFX/HatchFXClient` | ModuleScript | `src/shared/ReplicatedStorage/HatchFX/HatchFXClient.luau` | `src/shared/Hatching/HatchFX/HatchFXClient.luau` |  |
| `ReplicatedStorage/HatchFX/HatchFXConfig` | ModuleScript | `src/shared/ReplicatedStorage/HatchFX/HatchFXConfig.luau` | `src/shared/Hatching/HatchFX/HatchFXConfig.luau` |  |
| `ReplicatedStorage/IncubatorController` | ModuleScript | `src/shared/ReplicatedStorage/IncubatorController.luau` | `src/shared/Hatching/IncubatorController.luau` |  |
| `ReplicatedStorage/CharacterInventory/HatchReveal` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/HatchReveal.luau` | `src/shared/Inventory/CharacterInventory/HatchReveal.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryClient` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryClient.luau` | `src/shared/Inventory/CharacterInventory/InventoryClient.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryConfig` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryConfig.luau` | `src/shared/Inventory/CharacterInventory/InventoryConfig.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryFormat` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryFormat.luau` | `src/shared/Inventory/CharacterInventory/InventoryFormat.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryModel` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryModel.luau` | `src/shared/Inventory/CharacterInventory/InventoryModel.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryStyle` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryStyle.luau` | `src/shared/Inventory/CharacterInventory/InventoryStyle.luau` |  |
| `ReplicatedStorage/CharacterInventory/InventoryView` | ModuleScript | `src/shared/ReplicatedStorage/CharacterInventory/InventoryView.luau` | `src/shared/Inventory/CharacterInventory/InventoryView.luau` |  |
| `ReplicatedStorage/Construction/ConstructionClient` | ModuleScript | `src/shared/ReplicatedStorage/Construction/ConstructionClient.luau` | `src/shared/Temple/Construction/ConstructionClient.luau` |  |
| `ReplicatedStorage/Construction/ConstructionConfig` | ModuleScript | `src/shared/ReplicatedStorage/Construction/ConstructionConfig.luau` | `src/shared/Temple/Construction/ConstructionConfig.luau` |  |
| `ReplicatedStorage/EggLabel` | ModuleScript | `src/shared/ReplicatedStorage/EggLabel.luau` | `src/shared/UI/EggLabel.luau` |  |
| `ReplicatedStorage/EggUIStyle` | ModuleScript | `src/shared/ReplicatedStorage/EggUIStyle.luau` | `src/shared/UI/EggUIStyle.luau` |  |
| `ReplicatedStorage/FirstHatchGuide` | ModuleScript | `src/shared/ReplicatedStorage/FirstHatchGuide.luau` | `src/shared/UI/FirstHatchGuide.luau` |  |
| `ReplicatedStorage/Leaderboard/LeaderboardClient` | ModuleScript | `src/shared/ReplicatedStorage/Leaderboard/LeaderboardClient.luau` | `src/shared/UI/Leaderboard/LeaderboardClient.luau` |  |
| `ReplicatedStorage/Leaderboard/LeaderboardConfig` | ModuleScript | `src/shared/ReplicatedStorage/Leaderboard/LeaderboardConfig.luau` | `src/shared/UI/Leaderboard/LeaderboardConfig.luau` |  |
| `ReplicatedStorage/Leaderboard/LeaderboardFormat` | ModuleScript | `src/shared/ReplicatedStorage/Leaderboard/LeaderboardFormat.luau` | `src/shared/UI/Leaderboard/LeaderboardFormat.luau` |  |
| `ReplicatedStorage/Leaderboard/LeaderboardView` | ModuleScript | `src/shared/ReplicatedStorage/Leaderboard/LeaderboardView.luau` | `src/shared/UI/Leaderboard/LeaderboardView.luau` |  |
| `ReplicatedStorage/PixelIcon` | ModuleScript | `src/shared/ReplicatedStorage/PixelIcon.luau` | `src/shared/UI/PixelIcon.luau` |  |
| `ReplicatedStorage/StolenEggBanner` | ModuleScript | `src/shared/ReplicatedStorage/StolenEggBanner.luau` | `src/shared/UI/StolenEggBanner.luau` |  |
| `ReplicatedStorage/UISound` | ModuleScript | `src/shared/ReplicatedStorage/UISound.luau` | `src/shared/UI/UISound.luau` |  |
| `Workspace/PirateEggConveyor/RollingMotion` | ModuleScript | `src/client/Workspace/PirateEggConveyor/RollingMotion.luau` | `src/shared/World/PirateEggConveyor/RollingMotion.luau` |  |
| `ReplicatedStorage/Portal/PortalBuilder` | ModuleScript | `src/shared/ReplicatedStorage/Portal/PortalBuilder.luau` | `src/shared/World/Portal/PortalBuilder.luau` |  |
| `ReplicatedStorage/Portal/PortalConfig` | ModuleScript | `src/shared/ReplicatedStorage/Portal/PortalConfig.luau` | `src/shared/World/Portal/PortalConfig.luau` |  |
| `ReplicatedStorage/WaterfallRiver/RiverConfig` | ModuleScript | `src/shared/ReplicatedStorage/WaterfallRiver/RiverConfig.luau` | `src/shared/World/WaterfallRiver/RiverConfig.luau` |  |
| `ReplicatedStorage/WaterfallRiver/RiverPath` | ModuleScript | `src/shared/ReplicatedStorage/WaterfallRiver/RiverPath.luau` | `src/shared/World/WaterfallRiver/RiverPath.luau` |  |

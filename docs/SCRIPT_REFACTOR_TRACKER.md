# Script Refactor Tracker

Every active Luau script in `src/` (all are mapped in `default.project.json`).
Original Lines = commit `8aa46a3` (before any refactor). Final Lines = current working tree.
Bytecode: `SAME` = `luau-compile --text -g0` output identical to the pre-refactor source (renames/comments/formatting only, proven behaviour-identical); `CHANGED` = structural edit, reviewed by diff.

## Summary

| Status | Scripts |
|---|---:|
| Pending | 67 |
| Reviewed — No Changes Needed | 5 |
| Refactored | 117 |
| Blocked — Requires Manual Review | 0 |
| **Total** | **189** |

## Batch 01 — Shared — config, catalogs, utilities

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `shared/Catalogs/CharacterCatalog.luau` | ModuleScript | 96 | 253 | Refactored | SAME | Header documents entry shape; renamed CHARACTER_IDS/ASSET_NAMES/PRICES/RARITY_NAMES/RARITY_COLORS/MENU_IMAGES, unknownEntry, addLine/label; comments on spawn roll and parallel arrays. |
| `shared/Catalogs/CharacterEconomy.luau` | ModuleScript | 104 | 256 | Refactored | SAME | Header lists attributes; renamed defaultRandom, mutationMultiplier, power, anchorPart, boxCFrame, skew, addLine, unit/text; documented RollWeights, Roll, legacy PowerVersion conversion, Format. |
| `shared/Catalogs/EggCatalog.luau` | ModuleScript | 1 | 52 | Refactored | SAME | Comment-only header: consumers, field meanings, array order is a contract. |
| `shared/Characters/CharacterInfo/Adapter.luau` | ModuleScript | 74 | 88 | Refactored | SAME | Renamed instance, attr, attributeNames/attributeName; comments on Read, Watched, BrainrotId precedence, client-only ReducedMotion. |
| `shared/Config/EggHatchTiming.luau` | ModuleScript | 15 | 43 | Refactored | SAME | Header; M->Timing, hours/minutes/secs; unused locals prefixed with _ (require kept). Selene 2->0. |
| `shared/Config/GameMenu/Config.luau` | ModuleScript | 62 | 149 | Refactored | SAME | C->Config, U->_LEGACY_UNITS (still created), timestamp/date/year/month/weekIndex/digits; documented Monday week offset, PeriodKey/PeriodEnds. |
| `shared/Config/JoinArrival/Config.luau` | ModuleScript | 42 | 42 | Reviewed — No Changes Needed | SAME | Untouched. |
| `shared/Config/ShopSystem/ShopConfig.luau` | ModuleScript | 62 | 81 | Refactored | SAME | C->Config; data untouched. |
| `shared/Config/TempleAppearanceThemes.luau` | ModuleScript | 39 | 82 | Refactored | SAME | Header per theme; T->Themes, candidate, part, surfaceAppearance, baseColor/tint; notes on fallback and Neon/Glass skip. |
| `shared/Config/TrailerConfig.luau` | ModuleScript | 52 | 81 | Refactored | SAME | C->Config. |
| `shared/Config/UpdateConfig.luau` | ModuleScript | 16 | 16 | Reviewed — No Changes Needed | SAME | Untouched. |
| `shared/Config/UpgradePrices.luau` | ModuleScript | 17 | 27 | Refactored | SAME | P->Prices, ls->leaderstats; header gives runtime path, table keying and Charge contract. |
| `shared/Effects/GoldCharacterFX.luau` | ModuleScript | 73 | 234 | Refactored | SAME | Header; CollectionService, boxCFrame/boxSize, originalParts, part/limb, weld names, addSparkleEmitter; Selene 1->0. |
| `shared/Effects/RichGoldFinish.luau` | ModuleScript | 14 | 20 | Refactored | SAME | Header; part, surfaceAppearance. |
| `shared/Egg/EggSteal/EggStealConfig.luau` | ModuleScript | 111 | 111 | Refactored | SAME | C->Config. |
| `shared/Hatching/HatchFX/HatchFXConfig.luau` | ModuleScript | 85 | 107 | Refactored | SAME | C->Config, U->LEGACY_UNITS, at->scaled, unit/value/text; documented Timeline scaling and that Config.T is not used by Timeline. |
| `shared/Inventory/CharacterInventory/InventoryConfig.luau` | ModuleScript | 144 | 144 | Reviewed — No Changes Needed | SAME | Untouched; pre-existing selene deprecated (Enum.KeyCode.Unknown) kept — config value. |
| `shared/Inventory/CharacterInventory/InventoryFormat.luau` | ModuleScript | 78 | 114 | Refactored | SAME | truncated/text/digits/difference/multiplier/percent; exports and output strings unchanged; comments on truncation, rounding, Ago. |
| `shared/Temple/Construction/ConstructionConfig.luau` | ModuleScript | 104 | 111 | Refactored | SAME | C->Config; timing/count/buildStart in Timeline; replaced stale comment with accurate timeline description. |
| `shared/UI/EggUIStyle.luau` | ModuleScript | 19 | 61 | Refactored | SAME | Header; label, position; comment on staggered dot grid. |
| `shared/UI/Leaderboard/LeaderboardConfig.luau` | ModuleScript | 115 | 144 | Reviewed — No Changes Needed | SAME | Untouched. |
| `shared/UI/Leaderboard/LeaderboardFormat.luau` | ModuleScript | 33 | 54 | Refactored | SAME | UNITS->_UNITS (still created), digits/grouped; comments on Commas, Compact, Value kinds; Selene 1->0. |
| `shared/UI/PixelIcon.luau` | ModuleScript | 72 | 113 | Refactored | SAME | P->PixelIcon, icon/height/width/char/pixel/property/value; documented run-length merge, +1px seam trick, deprecated Instance.new parent arg. |
| `shared/World/PirateEggConveyor/RollingMotion.luau` | ModuleScript | 113 | 197 | Refactored | SAME | Header lists phases and attributes; RS->ReplicatedStorage, conveyor, riverOrigin, phase durations, progress vars, eggCFrame, segment. |
| `shared/World/Portal/PortalBuilder.luau` | ModuleScript | 107 | 258 | Refactored | SAME | C->Config, P->PALETTE, makePart, buildLantern, gate, groundY, pillarHeight, surfaceGui, plaqueText; header notes server near-copy. |
| `shared/World/Portal/PortalConfig.luau` | ModuleScript | 52 | 67 | Refactored | SAME | C->Config. |
| `shared/World/WaterfallRiver/RiverConfig.luau` | ModuleScript | 70 | 76 | Refactored | SAME | C->Config. |
| `shared/World/WaterfallRiver/RiverPath.luau` | ModuleScript | 72 | 92 | Refactored | SAME | ORIGIN, SAMPLE_COUNT, cumulativeDistance, segmentStart/End, fraction, tangent, dashHeads, keypoints, addKeypoint; documented sampling, meander fade, WidthAt, Dash. |

## Batch 02 — Shared — UI modules

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Egg/EggLabelsClient.client.luau` | LocalScript | 1 | 3 | Refactored | SAME | Added 2-line header comment only. |
| `shared/Characters/CharacterInfo/Style.luau` | ModuleScript | 126 | 420 | Refactored | SAME | S->Style (fields unchanged), descriptive params/locals (dims, stripGradient, powerGradient, mutationBadge, sparkBar...), TS->TweenService; documented Card/Apply contracts; _outlined. |
| `shared/UI/EggLabel.luau` | ModuleScript | 425 | 865 | Refactored | SAME | Renamed locals (textRow/makeLabel, plateColorsByRarity, rarityColor, hookPrompt, refreshCollectible...); documented fade cache, smoothstep scale, touch tap; unused -> _ prefix. |
| `shared/UI/FirstHatchGuide.luau` | ModuleScript | 88 | 223 | Refactored | SAME | Header documents Resolve() return tuple; tool->findTool, richestStand/firstEmptySlot, bestChamber/readyChamber, nearestAnchor etc.; step comments. |
| `shared/UI/StolenEggBanner.luau` | ModuleScript | 309 | 750 | Refactored | SAME | Header explains token generations; full-name locals (BANNER_WIDTH/HEIGHT, socketFrame, eggInfo, currentState, trackConnection...); unused -> _ prefix; section comments. |
| `shared/UI/UISound.luau` | ModuleScript | 523 | 581 | Refactored | SAME | Header lists API, pooling, debounce and mute sources; cfg->config, s->preloadSound; _cashSuppressedUntil; comments on cash alias debounce and preload. |

## Batch 03 — Player data

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `server/Economy/NoEarnAccounts.server.luau` | Script | 30 | 47 | Refactored | SAME | Renames (guardCash, lastValue, isReverting...), header runtime note, comment on re-entrancy flag. |
| `server/PlayerData/KeepItemsOnRespawn.server.luau` | Script | 51 | 80 | Refactored | SAME | Renames (shouldKeep, parkItems, restoreItems, watchPlayer, deadBackpacks...); header notes the admin-respawn known issue. |
| `server/PlayerData/PlayerDataService.server.luau` | Script | 402 | 922 | Refactored | SAME | Full saved-schema + load/save/failure-flow header; descriptive renames (sessionData, restoreState, saveData/loadData...); invariant comments. Save/load logic untouched (SAME). |
| `server/PlayerData/SaveRestore.luau` | ModuleScript | 54 | 104 | Refactored | SAME | Header documents store/key/lock coupling; renames (resolvePlayer, summarize, oldSave, versionInfo); function comments. |
| `server/PlayerData/TutorialProgress.server.luau` | Script | 13 | 31 | Refactored | SAME | RS->ReplicatedStorage, expected->EXPECTED_ACTION, header with remote + attribute contract. |

## Batch 04 — Egg — server and carry

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `server/Carry/CarryGripLayout.luau` | ModuleScript | 58 | 87 | Refactored | SAME | Header (API + 3 strategies), descriptive renames (gripY, upperLength, handX/handY, *Att), section comments per fallback. |
| `server/Carry/TwoHandItemCarryServer.server.luau` | Script | 5 | 8 | Refactored | SAME | Header, Carry -> TwoHandItemCarryService, comment on why the empty DropHeldItem handler stays. |
| `server/Carry/TwoHandItemCarryService.luau` | ModuleScript | 227 | 629 | Refactored | SAME | Header with API + pickup authority; renames (carryRecords, stopCarry, presentationOf, stripNonVisuals, addLabel, fxColor...); selene 4->1 (deprecated Instance.new parent kept). |
| `server/Eggs/ConveyorEggs.server.luau` | Script | 76 | 172 | Refactored | SAME | Header (spawn cadence, collect checks, remote payload); renames (EGG_CATALOG, eggCollectedEvent, chooseEntry, priceBadge...); _Players; selene 1->0. |
| `server/Eggs/EggSellService.server.luau` | Script | 35 | 99 | Refactored | SAME | Header documents SellEgg actions/returns + authority; renames (sellPriceOf, lastSellAt, candidates, soldCount...); note on header/code mismatch. |
| `server/Eggs/EggSteal/EggStealServer.server.luau` | Script | 8 | 8 | Refactored | SAME | Service -> EggStealService, header notes the script is Disabled (steal system off). |
| `server/Eggs/EggSteal/EggStealService.luau` | ModuleScript | 687 | 949 | Refactored | SAME | R->Rules, Event->stealEvent, StealFolder, catalogById, descriptive locals; header lists all Event payloads, attributes, OFF status, audit known issue; function comments. |
| `server/Eggs/PirateEggFreeConveyor.server.luau` | Script | 148 | 306 | Refactored | SAME | Header (cadence, collect authority, remote/bindable contracts, test attributes); renames (conveyor, collectByEgg, MUTATION_TIERS, collectPrompt...); selene 4->0. |
| `server/Eggs/RiverEggCarryService.luau` | ModuleScript | 70 | 147 | Refactored | SAME | Header (API, end states, attributes, RiverEggCarryState payloads, lazy require cycle); renames (activeCarries, carryStateEvent, homePlot...); box + iteration comments. |
| `server/Eggs/RiverEggPayment.luau` | ModuleScript | 12 | 30 | Refactored | SAME | Header (contract, no-yield guarantee), stats -> leaderstats, NaN comment. |
| `server/Eggs/RiverEggSpawnScheduler.luau` | ModuleScript | 44 | 73 | Refactored | SAME | Header (rules), RARITY_ORDER/RARITY_MIN_AGE/RARITY_COOLDOWN, self -> scheduler (selene 1->0), totalWeight/cumulative/candidate. |

## Batch 05 — Egg — client

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Egg/EggPickupFeedback.client.luau` | LocalScript | 54 | 149 | Refactored | SAME | Header documents EggCollected (eggId, eggCFrame, eggSize); RS->ReplicatedStorage, VOICE_ASSET_IDS, catalogById, pickupCard, cardSerial, progress/eased; section comments. |
| `client/Egg/EggStealClientStart.client.luau` | LocalScript | 2 | 4 | Refactored | SAME | Header expanded (bootstraps EggStealClient.Start()). |
| `client/Egg/RiverEggCarryClient.client.luau` | LocalScript | 22 | 36 | Refactored | SAME | Header with RiverEggCarryState payloads + attribute mirror; RS->ReplicatedStorage, currentCarryId, recoverFromAttributes, carryId/basePosition. |
| `client/Egg/StolenEggCarryPose.client.luau` | LocalScript | 105 | 152 | Refactored | SAME | Header (pose for all characters, joints, reset); watchedCharacters, scanCharacter, setupPlayer, findJoint, record/arm/joint, *World, *BoneDir; unused -> _upperArm etc; selene 3->0. |
| `shared/Egg/EggSteal/EggStealClient.luau` | ModuleScript | 849 | 1245 | Refactored | SAME | Header with remote contract + thief/banner split; COLORS/ALARM/SOUND_IDS, create/tween/playSound, activeSteals, fxLayer; descriptive locals; dead helpers prefixed _; selene 7->0. |

## Batch 06 — Hatching — server and incubators

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Cinematics/HatchVideoClient.client.luau` | LocalScript | 61 | 140 | Refactored | SAME | UserInputService, _TweenService, _arg2/_arg3; descriptive locals (hiddenGuis, connections, orbitAngle...); comments on camera orbit and owner check; selene 3->0. |
| `server/DevTools/DevWorkshop/BUILD WORKSHOP/HATCH - EDITABLE ORIGINAL/HatchGoo.server.luau` | Script | 215 | 443 | Refactored | SAME | Header explains Disabled reference copy + how it differs + the (-22.75,-26,-92) pivot offset; same renames as the template (not merged); _bottom; selene 1->0. |
| `server/Hatching/HatchCameraGate.luau` | ModuleScript | 18 | 47 | Refactored | SAME | Header with Focus API + CinematicHatchCue/HatchCameraReady payloads; ReplicatedStorage, pendingByPlayer, request; why the stale-request check exists. |
| `server/Hatching/HatchFX/HatchFXServer.luau` | ModuleScript | 112 | 256 | Refactored | SAME | Header (API, options, replicated attrs/ObjectValues); activeJobs, options, timeline, eggRef/characterRef, getController; fixed playerJobs comment; job.o field kept. |
| `server/Hatching/HatchVideoService.server.luau` | Script | 79 | 188 | Refactored | CHANGED | Remote payload + HatchGoo interface documented; full service names, DEFAULT_CHAIN, descriptive locals; the 2 identical reward-removal closures merged into destroyHatchedReward. |
| `server/Hatching/Templates/HatchGoo.server.luau` | Script | 292 | 663 | Refactored | SAME | Header (mappings, flow, remotes/bindables/attributes); chamber/liquidSystem/cinematicCue/glassController/runCycle/canUseChamber; phase section comments; _doorRest/_bottom; selene 2->0. |
| `shared/Hatching/IncubatorController.luau` | ModuleScript | 185 | 315 | Refactored | SAME | Public method contract in header; SLIDE_DISTANCE/JADE_COLOR/WARM_COLOR; nameHasAny/findDescendant; descriptive locals; self.* fields and method names unchanged. |

## Batch 07 — Hatching — client

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Hatching/CinematicHatch.client.luau` | LocalScript | 612 | 967 | Refactored | CHANGED | Renames (record/activeSession/timelineTime…), services full names, UPPER constants, contract header; extracted createCoreEffects, showRecord, animateHatching, animateRelease, updateOwnerCamera |
| `client/Hatching/HatchFXClientStart.client.luau` | LocalScript | 2 | 4 | Refactored | SAME | Header comment explaining what it starts |
| `client/Hatching/HatchLiquidVisuals.client.luau` | LocalScript | 113 | 213 | Refactored | SAME | Header with attribute contract, descriptive renames, unused locals prefixed _, comments; heartbeatConnection kept as-is and documented as known issue |
| `shared/Hatching/HatchFX/HatchFXClient.luau` | ModuleScript | 446 | 980 | Refactored | CHANGED | Renames, replicated-contract header, section/why comments; extracted rockEgg, updateCracks, updateShards, updateCharacter (from step) and createEggEffects, collectMachineGlow (from begin) |

## Batch 08 — Characters

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Characters/CharacterAnimator.client.luau` | LocalScript | 152 | 317 | Refactored | SAME | JOINT_POSITIONS/MAX_DISTANCE, computePose with documented pose fields, descriptive renames, cycle comments; all poses/speeds unchanged |
| `client/Characters/CharacterInfoClient.client.luau` | LocalScript | 178 | 334 | Refactored | SAME | Style/characterInfoFolder names, kindConfig/billboard/uiScale/labelState renames, header on label instances, KINDS legend, why-comments |
| `client/Characters/FloatingCharacters.client.luau` | LocalScript | 116 | 183 | Refactored | SAME | Header rewritten to match actual motion + attribute contract, unused helper prefixed _, descriptive renames, shadow/ring comments |
| `client/Characters/GoldenLuffyIdle.client.luau` | LocalScript | 30 | 73 | Refactored | SAME | Header, IDLE_DISTANCE constant, descriptive renames (descendant, motor, restC0, now), state shape comment |
| `client/Characters/HatchedCharacterDisplay.client.luau` | LocalScript | 35 | 111 | Refactored | SAME | Header with attribute contract, full service names, TAG/REVEAL_DISTANCE/ENTRANCE_SECONDS constants, descriptive renames, section comments |
| `server/Characters/BrainrotPlacement.server.luau` | Script | 110 | 239 | Refactored | SAME | Header with entry points + attribute contract, named folded constants, descriptive renames (no shadowing), unused locals prefixed _, why-comments; deprecated Instance.new(parent) kept + documented |
| `server/Characters/CharacterInventory/InventoryServer.server.luau` | Script | 2 | 3 | Refactored | SAME | One-line purpose comment added |
| `server/Characters/CharacterInventory/InventoryService.luau` | ModuleScript | 650 | 973 | Refactored | SAME | Network-authority + remote contract header, ServerConfig alias, folded limit constants, descriptive renames; validation logic byte-identical (SAME) |
| `server/Characters/CharacterSize.server.luau` | Script | 13 | 29 | Refactored | SAME | Header, DEFAULT_SIZE_MULTIPLIER constant (folded), scaleCharacter/setupPlayer renames |
| `server/Characters/EggCharacterRewards.luau` | ModuleScript | 50 | 136 | Refactored | SAME | Header documenting Resolve/Tool API and mutation semantics, DISPLAY_HEIGHT constant, descriptive renames, section comments |

## Batch 09 — Characters — inventory client

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Bootstrap/CustomInventoryBootstrap.client.luau` | LocalScript | 13 | 16 | Refactored | SAME | Header (ReplicatedFirst LocalScript, purpose, pcall reason); clearer render-step comment |
| `client/Inventory/CharacterInventoryStart.client.luau` | LocalScript | 2 | 2 | Reviewed — No Changes Needed | SAME | No changes |
| `shared/Inventory/CharacterInventory/HatchReveal.luau` | ModuleScript | 243 | 372 | Refactored | SAME | Header: API + payload + note that Push is no longer called; Theme/Fonts/RevealConfig; reducedMotion; descriptive renames; comments on queue, burst, log-scale count |
| `shared/Inventory/CharacterInventory/InventoryClient.luau` | ModuleScript | 377 | 604 | Refactored | SAME | Header: network use + retired-UI status; Theme/Fonts, DONE_MESSAGES; descriptive renames; unused buildHud/reveal -> _buildHud/_reveal (selene 3->1); why-comments |
| `shared/Inventory/CharacterInventory/InventoryModel.luau` | ModuleScript | 162 | 246 | Refactored | SAME | Descriptive renames (cap -> capacity param, query, compare, slotsToFill, freeSlots...); doc comments for Filter/Sort/Strongest/BestPlan fields/CompareTarget priority/Actions |
| `shared/Inventory/CharacterInventory/InventoryStyle.luau` | ModuleScript | 257 | 370 | Refactored | SAME | Theme/Fonts, QUICK_TWEEN; descriptive renames (params of Pad/StudBand too); comments for Make, Pad, Text, Chip, Button attributes, FrameModel distance |
| `shared/Inventory/CharacterInventory/InventoryView.luau` | ModuleScript | 982 | 1588 | Refactored | CHANGED | Header with View API + callbacks contract; Theme/Fonts, SHEET_TWEEN, SHORT_RARITY_LABELS; descriptive renames; extracted buildNote, buildSkeletonCards, clearPips; doc comments per method |

## Batch 10 — Plots, temples and portals

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Plot/ConstructionClientStart.client.luau` | LocalScript | 2 | 4 | Refactored | SAME | Header extended (what it boots, tag, server counterpart) |
| `client/Plot/PortalClient.client.luau` | LocalScript | 350 | 655 | Refactored | SAME | Renames (portalState, create, roundCorners, makeSound, playSound, addPortal, emerge, elapsed...), comments on emerge phases/startEmerge |
| `client/Temple/GoldTempleEffects.client.luau` | LocalScript | 98 | 228 | Refactored | SAME | Header (effect list, distance, timings), renames (activeTemples, addGoldEffects, queueGoldEffects, emitter, attachment, ribbon), comments |
| `client/Temple/TempleWindAnimator.client.luau` | LocalScript | 48 | 68 | Refactored | SAME | Header extended (TempleWindStreams anchor attributes, 30 Hz), windFolder, rippleTime, comments |
| `client/Temple/UpgradeCameraShake.client.luau` | LocalScript | 98 | 231 | Refactored | SAME | Header (disabled legacy effect, UpgradeAssembly tag, timing), CollectionService, renames, _radius, trauma/schedule comments |
| `server/Plots/HomeAndBubbles.server.luau` | Script | 66 | 181 | Refactored | CHANGED | Header with GoHome protocol, renames, refresh now calls clearBubble (identical body), comments incl. known GoHome cooldown issue and double MaxDistance |
| `server/Plots/PlotChambers.server.luau` | Script | 122 | 257 | Refactored | SAME | Header (remotes, attributes, SavedChambers), constants MAX_CHAMBERS/MAX_CHAMBER_LEVEL/UPGRADE_MAX_DISTANCE/ADMIN_USER_ID, descriptive renames, comments on generation/busy, _target |
| `server/Plots/PlotManager.server.luau` | Script | 171 | 388 | Refactored | SAME | Header (plot lifecycle + dependent systems/attribute contracts), sections, UPPER_SNAKE constants, renames (assignedPlots, waitingQueue, upgradeCooldowns, swapInstantly...), _player/_level |
| `server/Plots/PlotReadyFlag.server.luau` | Script | 7 | 25 | Refactored | SAME | Header (polling window, attribute unused per audit), renames markIfPlotAssigned/player/plot |
| `server/Temple/Construction/ConstructionService.luau` | ModuleScript | 347 | 492 | Refactored | SAME | Renames throughout (options, indexParts, roundTo, bucketKey, timeline, partKey, constructionId...), ConstructionService table name, bucket-key comment |
| `server/Temple/TempleOccupancy.luau` | ModuleScript | 42 | 88 | Refactored | SAME | Header (API, cached Claim* attributes), module renamed TempleOccupancy, setClaimVisible/claimed/item/child, comments |
| `server/Temple/TempleSlotUnlocks.luau` | ModuleScript | 111 | 247 | Refactored | SAME | Header with full API + slot attributes, constants SLOTS_PER_LEVEL/MAX_TEMPLE_LEVEL/FALLBACK_PRICE/MAX_PURCHASE_DISTANCE, renames, InventoryFormat |
| `server/World/Portal/PortalBuilder.luau` | ModuleScript | 107 | 258 | Refactored | SAME | Synced with refactored shared copy; now identical except header line 1 and the near-copy cross-reference on line 7 (points to the shared file) |
| `server/World/Portal/PortalServer.server.luau` | Script | 47 | 69 | Refactored | SAME | Config/PortalService names, runDemo/buildGate, descriptive locals, comments |
| `server/World/Portal/PortalService.luau` | ModuleScript | 71 | 110 | Refactored | SAME | Config/PortalService names, emergeJob/targetValue/gatePivot, header lists IsBusy and the client cue attributes |
| `shared/Temple/Construction/ConstructionClient.luau` | ModuleScript | 404 | 619 | Refactored | SAME | Renames (elapsed, timeline, kindConfig, batchInfo, partState, playSound...), job structure comment, helper comments, _ReplicatedStorage, ConstructionClient table |

## Batch 11 — Economy, shops and game menu server

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Plot/MoneyStandClient.client.luau` | LocalScript | 157 | 236 | Refactored | SAME | _player/_shine (documented as unused), stand/targetCFrame/chip/angle/elapsed etc., GOLD_COLOR, formatMoney, header remote note, stands shape comment |
| `client/UI/Controllers/LeaveEarningsOverlay.client.luau` | LocalScript | 85 | 213 | Refactored | SAME | TweenService, FONT/BLACK/WHITE/*_IMAGE, titleLabel/rateLabel/capLabel + strokes, fadeOverlay/spawnFallingCoin/show/hideOverlay, header note on hard-coded rate |
| `client/UI/Controllers/OfflineEarningsUI.client.luau` | LocalScript | 160 | 495 | Refactored | SAME | Service names, ShopConfig/shopRemote, BLACK/WHITE/*_IMAGE, create/makeLabel/makeButton/rgb, window/header/amountLabel..., header on Offline2x flow |
| `client/UI/Screens/MoneyDisplay/MoneyLogic.client.luau` | LocalScript | 162 | 221 | Refactored | SAME | baseScale, playTween params, formatCash/Full/Short, screenGui/moneyFrame/amountLabel, label/stroke, shownCash/targetCash, header + comments |
| `server/Economy/MoneyStandOwnership.server.luau` | Script | 55 | 135 | Refactored | SAME | Header (attribute inputs/outputs, templates path, if_same_then_else note), CollectionService, GHOST_COLOR, buildLockedGhost/setupPlot, descriptive locals, comments |
| `server/Economy/MoneyStandServer.server.luau` | Script | 111 | 145 | Refactored | SAME | Header: server-only collection authority, MoneyCollected payload, side effects. Renames (awardCurrency, isInPlateZone, addStand, standState, isOnPlate...), edge-trigger comment |
| `server/Economy/UpgradeEffects.luau` | ModuleScript | 121 | 239 | Refactored | SAME | Header with opts contract + replicated attributes, CollectionService, UpgradeEffects table name, partSignature, record/part/instance renames, _riseDistance, comments |
| `server/Services/GameMenu/GameAdapter.luau` | ModuleScript | 187 | 443 | Refactored | SAME | Header with full public API, service names, GameAdapter/QuestService/InventoryService names, _EggCharacterRewards/_err/_tool, descriptive renames, comments |
| `server/Services/GameMenu/GameMenuServer.server.luau` | Script | 182 | 414 | Refactored | SAME | Header (authority, GetState sections, Action names, Changed), gameMenuFolder/rootPart fix shadowing, ACTIONS, descriptive renames, comments on upgrade request flow |
| `server/Services/GameMenu/QuestService.luau` | ModuleScript | 76 | 146 | Refactored | SAME | QuestService/questData/getQuestRow renames, _player/_questData, header with API + persistence override note |
| `server/Shops/ShopService.server.luau` | Script | 262 | 545 | Refactored | SAME | Renames only (player, playerData, savePlayer, refreshMultipliers, receiptInfo...), DAY_SECONDS, CROWN_IMAGE, header with authority + remote contract + receipt flow, state shape comments |
| `server/Storage/MoneyStandBuilder.luau` | ModuleScript | 81 | 146 | Refactored | SAME | COLORS, STUD_TEXTURE, makePart/options/newPart, screenGui/background/amountStroke, header notes (contract names, no active requirer) |

## Batch 12 — Mutations, effects and nighttime

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Effects/AuraFlipbookPump.client.luau` | LocalScript | 12 | 18 | Refactored | SAME | Header location/tag; CollectionService, camera, emitter, part |
| `client/Effects/GoldFXClient.client.luau` | LocalScript | 81 | 200 | Refactored | SAME | Header (rig contract, config attrs, sync, distance/budget); full service names; trackModel/activeModels; descriptive sweep vars + comments |
| `client/Effects/MutationDropBoardClient.client.luau` | LocalScript | 17 | 31 | Refactored | SAME | Header (board path, attributes); TIER_COLORS, screen/timerLabel/tiersLabel, lastTier/lastDropAt/secondsLeft |
| `client/Effects/NighttimeSky.client.luau` | LocalScript | 135 | 347 | Refactored | SAME | Header (what is tweened, legacy disabled banner); section banners; NIGHT_LIGHTING, nightBlend, clockValue, onNighttimeChanged, playTween, descriptive locals |
| `client/Effects/OwnerShowcaseFX.client.luau` | LocalScript | 89 | 281 | Refactored | SAME | Header notes Disabled in project; TweenService; WHITE/PURPLE/... + *_TEXTURE; colorSequence/numberSequence/makeEmitter/makeRing/rerouteBolt; comments |
| `client/UI/Controllers/NighttimeHUD.client.luau` | LocalScript | 150 | 316 | Refactored | SAME | Header (sync, no remotes, mirrored constants); create/playTween/makePanel/makeLabel/formatClock/resizePill; CYCLE_SECONDS; _GuiService/_barGradient; comments |
| `server/Mutations/GoldFXServer.server.luau` | Script | 20 | 48 | Refactored | SAME | Header (gold criteria, GoldFX contract); GoldCharacterFX, isGoldCharacter/applyIfGold/watchModel, watchedModels; defer comment |
| `server/Mutations/MutationDropService.server.luau` | Script | 19 | 44 | Refactored | SAME | Header lists written workspace attributes + consumer; pickTier/nextDropAt, totalWeight/roll/tier locals |
| `server/Mutations/Mutations.luau` | ModuleScript | 67 | 149 | Refactored | SAME | Header documents mutation model (Roll/Model/AddAura, odds, assets, consumers, Theme). Mutations/ServerStorage names, findPackModel, descriptive locals, why-comments |
| `server/Services/NighttimeClock.server.luau` | Script | 2 | 8 | Refactored | SAME | Header; NighttimeService name |
| `server/Services/NighttimeService.luau` | ModuleScript | 17 | 36 | Refactored | SAME | Header documents cycle + published attributes/multipliers; CYCLE_SECONDS/NIGHT_SECONDS (constant-folded), cycleStart/forcedUntil |

## Batch 13 — Client UI — MenuLogic

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/UI/Screens/GameMenus/MenuLogic.client.luau` | LocalScript | 1246 | 3477 | Pending | — | — |

## Batch 14 — Client UI — GameHUD

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/UI/Controllers/GameHUD.client.luau` | LocalScript | 741 | 2372 | Pending | — | — |

## Batch 15 — Client UI — controllers and prompts

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Plot/PromptCards.client.luau` | LocalScript | 399 | 822 | Pending | — | — |
| `client/UI/Controllers/FeedbackClient.client.luau` | LocalScript | 101 | 316 | Pending | — | — |
| `client/UI/Controllers/FigmaSkin.client.luau` | LocalScript | 396 | 884 | Pending | — | — |
| `client/UI/Controllers/PixelIconSharpener.client.luau` | LocalScript | 10 | 40 | Pending | — | — |
| `client/UI/Controllers/SharpUI.client.luau` | LocalScript | 84 | 164 | Pending | — | — |
| `server/Services/FeedbackService.server.luau` | Script | 36 | 81 | Pending | — | — |

## Batch 16 — Client UI — leaderboards

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/UI/Controllers/LeaderboardClientStart.client.luau` | LocalScript | 3 | 3 | Pending | — | — |
| `server/Services/Leaderboard/LeaderboardChampions.server.luau` | Script | 349 | 420 | Pending | — | — |
| `server/Services/Leaderboard/LeaderboardServer.server.luau` | Script | 2 | 2 | Pending | — | — |
| `server/Services/Leaderboard/LeaderboardService.luau` | ModuleScript | 486 | 608 | Pending | — | — |
| `shared/UI/Leaderboard/LeaderboardClient.luau` | ModuleScript | 431 | 568 | Pending | — | — |
| `shared/UI/Leaderboard/LeaderboardView.luau` | ModuleScript | 769 | 1230 | Pending | — | — |

## Batch 17 — Client UI — tutorial and bootstrap

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Bootstrap/LoadingScreen.client.luau` | LocalScript | 209 | 578 | Pending | — | — |
| `client/Bootstrap/LoadingScreen/Config.luau` | ModuleScript | 34 | 50 | Pending | — | — |
| `client/Bootstrap/StartupLoader.luau` | ModuleScript | 131 | 259 | Pending | — | — |
| `client/Tutorial/FirstHatchTutorial.client.luau` | LocalScript | 321 | 738 | Pending | — | — |
| `client/Tutorial/JoinArrival.client.luau` | LocalScript | 523 | 894 | Pending | — | — |
| `server/Services/StartupAssetManifest.server.luau` | Script | 20 | 40 | Pending | — | — |

## Batch 18 — Cinematics — TrailerCinematic

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Cinematics/TrailerCinematic.client.luau` | LocalScript | 962 | 2355 | Pending | — | — |

## Batch 19 — Cinematics — duo trailers and cine cam

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Cinematics/CineCamClient.client.luau` | LocalScript | 405 | 541 | Pending | — | — |
| `client/Cinematics/TrailerDuoV2.client.luau` | LocalScript | 140 | 549 | Pending | — | — |
| `client/Cinematics/TrailerDuoV3.client.luau` | LocalScript | 178 | 737 | Pending | — | — |
| `server/Cinematics/CineCamServer.server.luau` | Script | 78 | 121 | Pending | — | — |

## Batch 20 — Admin and cross-server

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Admin/AdminTerminal.client.luau` | LocalScript | 244 | 601 | Pending | — | — |
| `client/Admin/OwnerPanelClient.client.luau` | LocalScript | 38 | 79 | Pending | — | — |
| `client/Admin/StaffAnnouncements.client.luau` | LocalScript | 110 | 360 | Pending | — | — |
| `client/Admin/VIPChatTag.client.luau` | LocalScript | 12 | 14 | Pending | — | — |
| `server/Admin/AdminRoles.luau` | ModuleScript | 49 | 114 | Pending | — | — |
| `server/Admin/OwnerControlServer.server.luau` | Script | 129 | 324 | Pending | — | — |
| `server/Admin/OwnerGameActions.luau` | ModuleScript | 97 | 220 | Pending | — | — |
| `server/Admin/OwnerOverheadBanner.server.luau` | Script | 88 | 102 | Pending | — | — |
| `server/Admin/OwnerPanelServer.server.luau` | Script | 145 | 412 | Pending | — | — |
| `server/Admin/OwnerShowcase.server.luau` | Script | 66 | 109 | Pending | — | — |
| `server/Admin/PlayerPunish.luau` | ModuleScript | 84 | 125 | Pending | — | — |
| `server/Admin/RoleTagServer.server.luau` | Script | 13 | 20 | Pending | — | — |
| `server/Admin/StaffServerService.luau` | ModuleScript | 185 | 185 | Pending | — | — |
| `server/Services/CrossServerService.luau` | ModuleScript | 295 | 305 | Pending | — | — |
| `shared/Admin/OwnerPanel/ActivityLog.luau` | ModuleScript | 1 | 17 | Pending | — | — |
| `shared/Admin/OwnerPanel/Components.luau` | ModuleScript | 26 | 134 | Pending | — | — |
| `shared/Admin/OwnerPanel/ConfirmDialog.luau` | ModuleScript | 10 | 36 | Pending | — | — |
| `shared/Admin/OwnerPanel/PlayerRow.luau` | ModuleScript | 8 | 42 | Pending | — | — |
| `shared/Admin/OwnerPanel/Theme.luau` | ModuleScript | 1 | 16 | Pending | — | — |
| `shared/Admin/OwnerPanel/Toast.luau` | ModuleScript | 6 | 37 | Pending | — | — |

## Batch 21 — Admin — StudPanel

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `shared/Admin/OwnerPanel/StudPanel.luau` | ModuleScript | 488 | 1599 | Pending | — | — |

## Batch 22 — Remaining — audio, weapons, world, services, storage, dev tools

| File | Type | Original Lines | Final Lines | Status | Bytecode | Notes |
|---|---|---:|---:|---|---|---|
| `client/Audio/BackgroundMusic.client.luau` | LocalScript | 85 | 114 | Pending | — | — |
| `client/Audio/MusicSettings.client.luau` | LocalScript | 221 | 493 | Pending | — | — |
| `client/Audio/UIAudioClient.client.luau` | LocalScript | 9 | 8 | Pending | — | — |
| `client/Weapons/BatMotionClient.client.luau` | LocalScript | 68 | 82 | Pending | — | — |
| `client/Weapons/WeaponPreloadClient.client.luau` | LocalScript | 64 | 76 | Pending | — | — |
| `client/World/PirateEggConveyorMotion.client.luau` | LocalScript | 76 | 174 | Pending | — | — |
| `client/World/RiverFlow.client.luau` | LocalScript | 24 | 51 | Pending | — | — |
| `client/World/WaterFX.client.luau` | LocalScript | 65 | 85 | Pending | — | — |
| `client/World/WaterfallFallMotion.client.luau` | LocalScript | 140 | 158 | Pending | — | — |
| `client/World/WaterfallRiverMotion.client.luau` | LocalScript | 47 | 95 | Pending | — | — |
| `server/DevTools/DevWorkshop/AnimRig_MovedFromWorkspace/Animate.client.luau` | LocalScript | 971 | 1020 | Pending | — | — |
| `server/DevTools/DevWorkshop/HalloweenTemple_Deluxe/SpookyMotion.server.luau` | Script | 11 | 21 | Pending | — | — |
| `server/Services/NoDropping.server.luau` | Script | 18 | 34 | Pending | — | — |
| `server/Services/ToolIcons.server.luau` | Script | 56 | 92 | Pending | — | — |
| `server/Storage/FutureUpdateContent/RiverBeforeGoldContentReservation.server.luau` | Script | 58 | 130 | Pending | — | — |
| `server/Storage/HalloweenSwitch.luau` | ModuleScript | 112 | 195 | Pending | — | — |
| `server/Storage/RestoreSurfaceAppearances.luau` | ModuleScript | 12 | 31 | Pending | — | — |
| `server/Storage/StoredCollectAllZones/CollectAllZoneServer.server.luau` | Script | 74 | 94 | Pending | — | — |
| `server/Weapons/WeaponGiver.server.luau` | Script | 41 | 41 | Pending | — | — |
| `server/Weapons/WoodenBat/BatServer.server.luau` | Script | 220 | 246 | Pending | — | — |
| `server/World/PumpkinGentleman/PumpkinIdle.server.luau` | Script | 33 | 65 | Pending | — | — |

## Inventory

Responsibility, dependencies (`require` targets), public functions, event usage, readability problems found at scan time, and priority.

### `shared/Catalogs/CharacterCatalog.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** Display text only; model IDs and artwork keys retain their existing names. Player-facing names (Adam, Oct 16): hint at the anime each one references.
- **Dependencies:** —
- **Public functions:** Catalog.BuildSpawnPool, Catalog.DisplayName, Catalog.FormatPrice, Catalog.Label, Catalog.Stamp
- **Events:** —
- **Readability problems:** no header; cryptic locals (ids/names/prices/colors/e/s/cf/l/line); parallel arrays undocumented

### `shared/Catalogs/CharacterEconomy.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** High · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** Economy.Apply, Economy.BasePower, Economy.Color, Economy.Format, Economy.Income, Economy.Label, Economy.Quality, Economy.Read, Economy.Roll, Economy.RollWeights
- **Events:** —
- **Readability problems:** no header; p/l/u/t/mutMult names; band/luck semantics undocumented

### `shared/Catalogs/EggCatalog.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** no header

### `shared/Characters/CharacterInfo/Adapter.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInfo.Adapter  (ModuleScript)
- **Dependencies:** CharacterCatalog
- **Public functions:** Adapter.IsCharacterTool, Adapter.Read, Adapter.Watched
- **Events:** —
- **Readability problems:** A/t/v/inst names

### `shared/Config/EggHatchTiming.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CharacterEconomy
- **Public functions:** M.Format, M.Seconds
- **Events:** —
- **Readability problems:** no header; M/h/m/s names; 2 unused_variable warnings

### `shared/Config/GameMenu/Config.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.GameMenu.Config  (ModuleScript, shared)
- **Dependencies:** InventoryFormat
- **Public functions:** C.Full, C.PeriodEnds, C.PeriodKey, C.Short
- **Events:** —
- **Readability problems:** C/U/d/y/m/w/t/s names; unused U table

### `shared/Config/JoinArrival/Config.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Reviewed — No Changes Needed
- **Responsibility:** JoinArrival.Config
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** none; already fully commented

### `shared/Config/ShopSystem/ShopConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.ShopSystem.ShopConfig — everything you tune for the Shop + Daily Rewards.
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** local named C

### `shared/Config/TempleAppearanceThemes.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** T.Apply
- **Events:** —
- **Readability problems:** no header; T/t/p/sa/c names

### `shared/Config/TrailerConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.TrailerConfig: settings for the recording-only trailer (/trailer or F7)
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** local named C

### `shared/Config/UpdateConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Reviewed — No Changes Needed
- **Responsibility:** UpdateConfig: edit this for each update. Players see a countdown before LaunchTime and a "What's new" window after it (once per update).
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** none

### `shared/Config/UpgradePrices.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Cash prices for plot upgrades. Server charges these; the Plot menu shows them.
- **Dependencies:** —
- **Public functions:** P.CanAfford, P.Charge
- **Events:** —
- **Readability problems:** P/ls names

### `shared/Effects/GoldCharacterFX.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** RichGoldFinish
- **Public functions:** FX.apply, FX.remove
- **Events:** —
- **Readability problems:** no header; Collection/cf/v/p/sa/w/e/rw/particle names; unused sa

### `shared/Effects/RichGoldFinish.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** Finish.Apply
- **Events:** —
- **Readability problems:** no header; p/sa names

### `shared/Egg/EggSteal/EggStealConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.EggSteal.EggStealConfig  (ModuleScript, shared by server + client)
- **Dependencies:** —
- **Public functions:** C.RarityColor
- **Events:** —
- **Readability problems:** local named C

### `shared/Hatching/HatchFX/HatchFXConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.HatchFX.HatchFXConfig  (ModuleScript, shared)
- **Dependencies:** InventoryFormat
- **Public functions:** C.LegacyShort, C.Level, C.Short, C.Timeline
- **Events:** —
- **Readability problems:** C/U/u/v/s/at names; Timeline vs T unclear

### `shared/Inventory/CharacterInventory/InventoryConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Reviewed — No Changes Needed
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryConfig  (ModuleScript)
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** none; well commented

### `shared/Inventory/CharacterInventory/InventoryFormat.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryFormat  (ModuleScript)
- **Dependencies:** —
- **Public functions:** Format.Ago, Format.Delta, Format.Exact, Format.Money, Format.Multiplier, Format.Rate, Format.Relative, Format.Short
- **Events:** —
- **Readability problems:** t/s/d/m/pct names

### `shared/Temple/Construction/ConstructionConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.Construction.ConstructionConfig  (ModuleScript, shared by server + client)
- **Dependencies:** —
- **Public functions:** C.Timeline
- **Events:** —
- **Readability problems:** C/k/n/t0 names; stale phaseOffset comment

### `shared/UI/EggUIStyle.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** Style.Panel, Style.Text
- **Events:** —
- **Readability problems:** no header; t/pos names

### `shared/UI/Leaderboard/LeaderboardConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Reviewed — No Changes Needed
- **Responsibility:** ReplicatedStorage.Leaderboard.LeaderboardConfig  (ModuleScript)
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** none; well commented

### `shared/UI/Leaderboard/LeaderboardFormat.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.Leaderboard.LeaderboardFormat  (ModuleScript)
- **Dependencies:** InventoryFormat
- **Public functions:** Format.Age, Format.Commas, Format.Compact, Format.Value
- **Events:** —
- **Readability problems:** unused UNITS; s/out names

### `shared/UI/PixelIcon.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Builds crisp pixel-art icons out of Frames. rows = strings, palette = {char=Color3}; "." = empty
- **Dependencies:** —
- **Public functions:** P.build
- **Events:** —
- **Readability problems:** P/def/h/w/c/px/k/v names

### `shared/World/PirateEggConveyor/RollingMotion.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Moves a river egg along the new winding WaterfallRiver (ReplicatedStorage.WaterfallRiver.RiverPath). Same API as before: returns update(), pose(elapsed) -> cframe, phase ("fall"\|"land"\|"travel"\|"exit"
- **Dependencies:** RiverConfig, RiverPath
- **Public functions:** —
- **Events:** —
- **Readability problems:** RS/m/O/k/u/wt/d/p/a/cf names; phases/attributes undocumented

### `shared/World/Portal/PortalBuilder.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.Portal.PortalBuilder  (ModuleScript, shared: server builds live gates, the trailer builds local ones)
- **Dependencies:** PortalConfig
- **Public functions:** Builder.Build
- **Events:** —
- **Readability problems:** C/P/m/g/H/l/t/sg/s names

### `shared/World/Portal/PortalConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.Portal.PortalConfig  (ModuleScript, shared)
- **Dependencies:** —
- **Public functions:** C.Color, C.Total, C.WalkTime
- **Events:** —
- **Readability problems:** local named C

### `shared/World/WaterfallRiver/RiverConfig.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.WaterfallRiver.RiverConfig Edit values here, then rebuild with:  require(game.ServerStorage.WaterfallRiverBuilder:Clone())() NOTE: fitted to the Hatch A Anime arena (cliff backs onto
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** local named C

### `shared/World/WaterfallRiver/RiverPath.luau`

- **Type:** ModuleScript · **Batch:** 01 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.WaterfallRiver.RiverPath Shared, deterministic river + egg maths. Server (validation) and client (visuals) compute identical positions from server time.
- **Dependencies:** RiverConfig
- **Public functions:** Path.At, Path.Dash, Path.WidthAt
- **Events:** —
- **Readability problems:** O/N/cum/a/b/f/tan/ps/kps/add names

### `client/Egg/EggLabelsClient.client.luau`

- **Type:** LocalScript · **Batch:** 02 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** EggLabel
- **Public functions:** —
- **Events:** —
- **Readability problems:** no header

### `shared/Characters/CharacterInfo/Style.luau`

- **Type:** ModuleScript · **Batch:** 02 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInfo.Style  (ModuleScript)  shared look + number formatting ]]
- **Dependencies:** —
- **Public functions:** S.Apply, S.Card, S.Celebrate, S.Full, S.Short, S.corner, S.label, S.make, S.stroke
- **Events:** —
- **Readability problems:** module local `S`; one-letter params (o/r/t/d/c/p/l/u/v/s); unused outlined(); Card dims/return contract undocumented

### `shared/UI/EggLabel.luau`

- **Type:** ModuleScript · **Batch:** 02 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.EggLabel  (ModuleScript, client-only)
- **Dependencies:** EggLabel
- **Public functions:** EggLabel.Attach, EggLabel.Detach, EggLabel.FormatPrice, EggLabel.Start, EggLabel:Destroy, EggLabel:Remove, EggLabel:SetNear, EggLabel:_appear, EggLabel:_setActive, EggLabel:_tick, EggLabel:_updatePrice
- **Events:** Connect×11, RunService×1
- **Readability problems:** cryptic locals (PL/sh/pl/rc/st/gs/lbl/str/t0/l/acc); _bt/_tt/_st cache and tick scaling math undocumented; 3 unused locals

### `shared/UI/FirstHatchGuide.luau`

- **Type:** ModuleScript · **Batch:** 02 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** Shared objective selection. The server remains responsible for rewards and completion.
- **Dependencies:** —
- **Public functions:** Guide.Plot, Guide.Resolve
- **Events:** —
- **Readability problems:** no header; return tuple/step numbers undocumented; cryptic locals (tool/t/ch/e/d/a/b/ends/best/ready/occupied/empty)

### `shared/UI/StolenEggBanner.luau`

- **Type:** ModuleScript · **Batch:** 02 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.StolenEggBanner  (ModuleScript, client)
- **Dependencies:** —
- **Public functions:** Banner.Hide, Banner.Resolve, Banner.Show, Banner.Start
- **Events:** Connect×4, RunService×2
- **Readability problems:** single-letter locals throughout (c/p/o/t/s/d/W/H/src/mdl/x/cf/r); token protocol undocumented; 5 unused locals

### `shared/UI/UISound.luau`

- **Type:** ModuleScript · **Batch:** 02 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** !strict Central UI feedback. UI and plate samples come from Creator Store; existing coin, purchase, and hatch cues retain their previous assets.
- **Dependencies:** —
- **Public functions:** UISound.AttachButton, UISound.AttachDescendants, UISound.IsCashFeedbackSuppressed, UISound.Play, UISound.PlayAt, UISound.PlayCoinPickup, UISound.SuppressCashFeedback
- **Events:** Connect×6
- **Readability problems:** cfg/s abbreviations; unused cashSuppressedUntil; header lacked API/mute summary; hard-coded Kaching id undocumented

### `server/Economy/NoEarnAccounts.server.luau`

- **Type:** Script · **Batch:** 03 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** NoEarnAccounts: these accounts can never gain cash (stands, offline earnings, sales, gifts...). Spending still works. The saved balance is restored normally on join; guarding starts once the save is f
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, PlayerAdded×1
- **Readability problems:** Cryptic names (guard, p, t, ls, last, fixing, v)

### `server/PlayerData/KeepItemsOnRespawn.server.luau`

- **Type:** Script · **Batch:** 03 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** KeepItemsOnRespawn: eggs and characters (Tools with EggType / CharacterId / BrainrotId) survive dying and respawning. Roblox clears the Backpack and destroys the held Tool on respawn, so a player who 
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, PlayerAdded×1
- **Readability problems:** Cryptic names (keep, t, c, p, hum, t0, deadBag)

### `server/PlayerData/PlayerDataService.server.luau`

- **Type:** Script · **Batch:** 03 · **Priority:** High · **Status:** Refactored
- **Responsibility:** PlayerDataService — saves and restores each player's progress (DataStore "PlayerData_v1", key "u<UserId>").
- **Dependencies:** CharacterCatalog, CharacterEconomy, EggCharacterRewards, Mutations, TempleSlotUnlocks
- **Public functions:** —
- **Events:** Connect×4, OnServerEvent×1, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** Cryptic locals (d, r, p, t, m, inc, nv, jd/td), aliases DSS/SSS/RS, shadowed `r` in snapshot (3 selene warnings), header said autosave 90 s but AUTOSAVE=30, no schema doc

### `server/PlayerData/SaveRestore.luau`

- **Type:** ModuleScript · **Batch:** 03 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** SaveRestore (owner only, used by the owner panel): list a player's older saves (Roblox keeps ~30 days) and put one back.
- **Dependencies:** —
- **Public functions:** M.List, M.Restore
- **Events:** —
- **Readability problems:** Alias DSS, module `M`, cryptic locals (r, n, s, v, cur, here), undocumented coupling to PlayerDataService schema/lock timeout

### `server/PlayerData/TutorialProgress.server.luau`

- **Type:** Script · **Batch:** 03 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Only acknowledges the UI tour after server-validated first income collection. These acknowledgements cannot buy upgrades, grant cash, or award items.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, OnServerEvent×1
- **Readability problems:** Alias RS, constant table `expected` lower-case, header lacked runtime/remote info

### `server/Carry/CarryGripLayout.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Place the item just below shoulder height, where straight arms can support it.
- **Dependencies:** —
- **Public functions:** Layout.Frame
- **Events:** —
- **Readability problems:** No header; cryptic locals (sum, y, l1, l2, x, wy, z, sa, ea, eb, wa, wb, half); three fallback strategies undocumented

### `server/Carry/TwoHandItemCarryServer.server.luau`

- **Type:** Script · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Player dropping (F key / Drop button) is turned off on purpose. Old handler + DropHeldItemClient are in ServerStorage._ARCHIVE.BeforeNoDrop_1792078437-- (Deaths/steals still drop items through their o
- **Dependencies:** TwoHandItemCarryService
- **Public functions:** —
- **Events:** Connect×1, OnServerEvent×1
- **Readability problems:** No header; generic `Carry` alias; empty DropHeldItem handler unexplained

### `server/Carry/TwoHandItemCarryService.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CarryGripLayout, RiverEggCarryService
- **Public functions:** Service.Attach, Service.DropTool, Service.Init
- **Events:** Connect×6, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** No header; RS alias; cryptic names (rec, h, m, p, d, k, pts, bb, lbl, st, g/gs, r/rs, TS, top1, dir, col, mut); 3 selene warnings (shadowed size, unused r/rs)

### `server/Eggs/ConveyorEggs.server.luau`

- **Type:** Script · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** EggCatalog, EggUIStyle
- **Public functions:** —
- **Events:** Connect×1
- **Readability problems:** No header; unused Players; cryptic names (config, event, folder, choose, c, hum, bag, gear, start/finish, y, custom, round)

### `server/Eggs/EggSellService.server.luau`

- **Type:** Script · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** EggSellService: sells an egg Tool from the player's own backpack/hand for cash. Server decides the price. Price = 40% of the egg's shop price; free eggs sell for $0. Limited, golden and owner-test egg
- **Dependencies:** CharacterCatalog
- **Public functions:** —
- **Events:** Connect×1, OnServerInvoke×1, PlayerRemoving×1
- **Readability problems:** RS alias; cryptic names (last, p, t, e, c, v, n, list); header claim 'can't be sold' contradicts code ($0 sell); remote contract undocumented

### `server/Eggs/EggSteal/EggStealServer.server.luau`

- **Type:** Script · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.EggSteal.EggStealServer  (Script)
- **Dependencies:** EggStealService
- **Public functions:** —
- **Events:** —
- **Readability problems:** Generic `Service` alias; header did not say the script is Disabled

### `server/Eggs/EggSteal/EggStealService.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ServerScriptService.EggSteal.EggStealService  (ModuleScript, SERVER ONLY)
- **Dependencies:** EggCatalog, EggStealConfig
- **Public functions:** Service.Cancel, Service.Init, Service.IsCarrying
- **Events:** Connect×10, OnServerEvent×1, PlayerRemoving×1
- **Readability problems:** Already well structured; cryptic names (R, Folder, Event, entries, e, m, b, p, o, c, d, w, hl, bg, att, src, s, pos, flat); unused `char` (selene); remote payloads not listed

### `server/Eggs/PirateEggFreeConveyor.server.luau`

- **Type:** Script · **Batch:** 04 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** AdminRoles, CharacterCatalog, CharacterEconomy, EggHatchTiming, Mutations, QuestService, RiverEggCarryService, RiverEggPayment, RiverEggSpawnScheduler, RollingMotion
- **Public functions:** —
- **Events:** Connect×3, OnServerEvent×1
- **Readability problems:** No header; `m` for the conveyor shadowed by `m` in mutatedTemplate; second `prompt` shadows first; unused RunService/update; cryptic (MUT, active, q, mt, base, drop, a/b, tcf/mcf, p)

### `server/Eggs/RiverEggCarryService.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** TwoHandItemCarryService
- **Public functions:** Service.Begin, Service.Drop
- **Events:** Connect×2, RunService×1, PlayerRemoving×1
- **Readability problems:** No header; RS alias; cryptic names (active, event, rec, hum, char, home, base); secure box magic numbers; dead `visual` field undocumented

### `server/Eggs/RiverEggPayment.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** Payment.TryCharge
- **Events:** —
- **Readability problems:** No header; `stats` local; NaN check unexplained

### `server/Eggs/RiverEggSpawnScheduler.luau`

- **Type:** ModuleScript · **Batch:** 04 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CharacterCatalog
- **Public functions:** Scheduler.new
- **Events:** —
- **Readability problems:** No header; lower-case constant tables; `self` local shadowed by method self (selene); total/sum/bucket names reused

### `client/Egg/EggPickupFeedback.client.luau`

- **Type:** LocalScript · **Batch:** 05 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** EggCatalog, EggUIStyle
- **Public functions:** —
- **Events:** Connect×2, OnClientEvent×1, RunService×1
- **Readability problems:** No header; RS alias; cryptic names (e, t, u, entries, holder, serial, from, size); EggCollected payload undocumented

### `client/Egg/EggStealClientStart.client.luau`

- **Type:** LocalScript · **Batch:** 05 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** StarterPlayer.StarterPlayerScripts.EggStealClientStart  (LocalScript) ]]
- **Dependencies:** EggStealClient
- **Public functions:** —
- **Events:** —
- **Readability problems:** Header did not say what the script does

### `client/Egg/RiverEggCarryClient.client.luau`

- **Type:** LocalScript · **Batch:** 05 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** StolenEggBanner
- **Public functions:** —
- **Events:** Connect×3, OnClientEvent×1
- **Readability problems:** No header; RS alias; vague names (current, recover, id, base); RiverEggCarryState contract undocumented

### `client/Egg/StolenEggCarryPose.client.luau`

- **Type:** LocalScript · **Batch:** 05 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×4, PlayerAdded×1
- **Readability problems:** No header; cryptic names (c, p, a, j, rec, sWorld, eWorld, wWorld, uBone, lBone, half, vFrom/vTo); 3 unused locals (upper/lower/hand)

### `shared/Egg/EggSteal/EggStealClient.luau`

- **Type:** ModuleScript · **Batch:** 05 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.EggSteal.EggStealClient  (ModuleScript, CLIENT ONLY)
- **Dependencies:** EggStealConfig, StolenEggBanner
- **Public functions:** Client.Start
- **Events:** Connect×11, OnClientEvent×1, RunService×3
- **Readability problems:** Header stale (described thief card; thief UI now lives in StolenEggBanner); cryptic aliases K/A/S, new/tw/play helpers; many 1-letter locals (g, d, c, m, p, u, l/r/t/b, v3, rc, hw, hh, k); 5 dead local functions + 2 unused params (selene 7)

### `client/Cinematics/HatchVideoClient.client.luau`

- **Type:** LocalScript · **Batch:** 06 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Owners only. Press J (or /hatchvid) = RECORDING MODE + "hatching until GOD" run. Hides ALL UI, name labels and your own character; smooth camera on your incubator between hatches, the game's own hatch
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×5, OnClientEvent×1, RunService×2
- **Readability problems:** UIS/TS aliases (TS unused); g/b/c/p/o/h/a/i/gp/m names; 2 unused handler params; owner list duplicated from server without note

### `server/DevTools/DevWorkshop/BUILD WORKSHOP/HATCH - EDITABLE ORIGINAL/HatchGoo.server.luau`

- **Type:** Script · **Batch:** 06 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** EggCharacterRewards
- **Public functions:** —
- **Events:** Connect×5
- **Readability problems:** No header saying it is an older, disabled, out-of-sync copy; same cryptic names as the template; magic pivot offset undocumented; unused local

### `server/Hatching/HatchCameraGate.luau`

- **Type:** ModuleScript · **Batch:** 06 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** Gate.Focus
- **Events:** Connect×1, OnServerEvent×1
- **Readability problems:** No header; RS alias; p for the pending request; remote contract (token handshake, 8 s timeout) undocumented

### `server/Hatching/HatchFX/HatchFXServer.luau`

- **Type:** ModuleScript · **Batch:** 06 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** HatchFXConfig
- **Public functions:** Service.Cancel, Service.IsBusy, Service.IsPlayerBusy, Service.Play
- **Events:** Connect×1
- **Readability problems:** No header; wrong comment (playerJobs keyed by incubator, it is by player); cryptic inc, o, T, ev/cv, ch, th, n, c, ctl; replicated attribute contract undocumented

### `server/Hatching/HatchVideoService.server.luau`

- **Type:** Script · **Batch:** 06 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** HatchVideoService (owners only): "hatching until I get a GOD" recording run. Client sends "Start" -> server hatches a chain of eggs in incubator 1 instantly (no waiting), each with the real hatch reve
- **Dependencies:** CharacterCatalog
- **Public functions:** —
- **Events:** Connect×4, OnServerEvent×1, PlayerRemoving×1
- **Readability problems:** RS/SS aliases; p/pl/ch/t/s/h/w/reward/cReward names; two identical ChildAdded handlers; remote payloads undocumented

### `server/Hatching/Templates/HatchGoo.server.luau`

- **Type:** Script · **Batch:** 06 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CharacterCatalog, CharacterEconomy, EggCharacterRewards, EggHatchTiming, HatchCameraGate, HatchFXConfig, HatchFXServer, IncubatorController, Mutations
- **Public functions:** —
- **Events:** Connect×6
- **Readability problems:** No header (4 Rojo mappings, inputs/outputs undocumented); cryptic locals h, m, v, p, r, mut, held, rest/doorRest, camera (actually a RemoteEvent); 300-line cycle with no sections; Collection alias; 2 unused locals

### `shared/Hatching/IncubatorController.luau`

- **Type:** ModuleScript · **Batch:** 06 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.IncubatorController (ModuleScript)
- **Dependencies:** IncubatorController
- **Public functions:** Incubator.new, Incubator:Close, Incubator:Destroy, Incubator:Hatch, Incubator:Open, Incubator:PlaceEgg, Incubator:Shake, Incubator:_slide
- **Events:** Connect×2, RunService×1
- **Readability problems:** Cryptic helper/local names (has, find, x, t, d, n, plat, cf, att, e, l, v, con, tw, snd, jobs, rz/rx, amp); constants not UPPER_SNAKE_COLOR-clear; public contract not listed

### `client/Hatching/CinematicHatch.client.luau`

- **Type:** LocalScript · **Batch:** 07 · **Priority:** High · **Status:** Refactored
- **Responsibility:** CinematicHatch (LocalScript, StarterPlayerScripts) Local hatch cinematic for the incubators. The server owns timing, rewards and machine state; this script only draws. Everyone nearby sees the egg bre
- **Dependencies:** PlayerModule, UISound
- **Public functions:** —
- **Events:** Connect×7, OnClientEvent×1, RunService×1
- **Readability problems:** 897-line script; ~230-line render-step callback mixing egg animation, release physics and owner camera; cryptic locals (r, s, u, t, b, d, g, e, em, mn/mx); service aliases Collection/Actions; unused Debris; stale sound comment

### `client/Hatching/HatchFXClientStart.client.luau`

- **Type:** LocalScript · **Batch:** 07 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.HatchFXClientStart  (LocalScript)
- **Dependencies:** HatchFXClient
- **Public functions:** —
- **Events:** —
- **Readability problems:** One-line bootstrap with minimal header

### `client/Hatching/HatchLiquidVisuals.client.luau`

- **Type:** LocalScript · **Batch:** 07 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×5
- **Readability problems:** No header; cryptic names (h, m, e, a, s, c, fade, collection); unused RunService/layers; undefined global heartbeatConnection read

### `shared/Hatching/HatchFX/HatchFXClient.luau`

- **Type:** ModuleScript · **Batch:** 07 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.HatchFX.HatchFXClient  (ModuleScript, client)
- **Dependencies:** HatchFXConfig
- **Public functions:** Client.Start, Shake.add
- **Events:** Connect×9, RunService×3
- **Readability problems:** 898 lines; step() ~170 lines and begin() ~190 lines mixing phases; one-letter locals (s, g, l, r, d, n, p, q, cf, R, T); contract undocumented

### `client/Characters/CharacterAnimator.client.luau`

- **Type:** LocalScript · **Batch:** 08 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.CharacterAnimator  (LocalScript)
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** One-letter locals throughout pose math and rig setup (P, S, J, c, a, e, m, b, j, w, sw, u, n, d, g, lp, s, W, sc, cf); pose field meaning undocumented

### `client/Characters/CharacterInfoClient.client.luau`

- **Type:** LocalScript · **Batch:** 08 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.CharacterInfoClient  (LocalScript)
- **Dependencies:** Adapter, Style
- **Public functions:** —
- **Events:** Connect×13, RunService×1, PlayerAdded×1
- **Readability problems:** S alias for Style; cryptic locals (k, bb, sc, st, upd, d, was, a, c, m, t0, cp, cf); KINDS fields undocumented

### `client/Characters/FloatingCharacters.client.luau`

- **Type:** LocalScript · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.FloatingCharacters  (LocalScript)
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** Header described a bob/6.6 s spin the code no longer does; unused easeIO and Config fields; cryptic locals (p, d, s, h, k, r, w, sel, cam)

### `client/Characters/GoldenLuffyIdle.client.luau`

- **Type:** LocalScript · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, RunService×1
- **Readability problems:** No header; v/t/joint/base names; magic distance 100

### `client/Characters/HatchedCharacterDisplay.client.luau`

- **Type:** LocalScript · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, RunService×1
- **Readability problems:** No header; service aliases Collection/Tween; cryptic locals (r, t, e, m, root); repeated tag string; magic 130/0.75

### `server/Characters/BrainrotPlacement.server.luau`

- **Type:** Script · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CharacterCatalog, CharacterEconomy, Mutations, TempleSlotUnlocks
- **Public functions:** —
- **Events:** Connect×3, PlayerAdded×1
- **Readability problems:** No header; placement/income contract undocumented; magic numbers (12, 6, 0.65, 1.5); cryptic/shadowed locals (p, old, stats, stand, cash, base, root, rate); unused Catalog/old/cash

### `server/Characters/CharacterInventory/InventoryServer.server.luau`

- **Type:** Script · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.CharacterInventory.InventoryServer  (Script)
- **Dependencies:** InventoryService
- **Public functions:** —
- **Events:** —
- **Readability problems:** Header did not say what the script does

### `server/Characters/CharacterInventory/InventoryService.luau`

- **Type:** ModuleScript · **Batch:** 08 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ServerScriptService.CharacterInventory.InventoryService  (ModuleScript)
- **Dependencies:** CharacterCatalog, CharacterEconomy, EggCharacterRewards, InventoryConfig, TempleSlotUnlocks
- **Public functions:** Actions.Hold, Actions.PickUp, Actions.Place, Actions.PlaceBest, Actions.PutAway, Actions.Sell, Actions.SellBackpack, Actions.SellBackpackAll, Actions.Store, Service.Init
- **Events:** Connect×15, OnServerInvoke×1, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** Remote contract (actions, payload fields, replies, events) undocumented; S alias; cryptic locals (obj, alt, v, b, s, cap, hum, char, ls, d, c, conns, p, who, inst); magic limits 64/32/300/16

### `server/Characters/CharacterSize.server.luau`

- **Type:** Script · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, PlayerAdded×1
- **Readability problems:** No header; generic function names (scale, setup); magic default 1.2

### `server/Characters/EggCharacterRewards.luau`

- **Type:** ModuleScript · **Batch:** 08 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** CharacterCatalog, CharacterEconomy, Mutations
- **Public functions:** Rewards.Resolve, Rewards.Tool
- **Events:** —
- **Readability problems:** No header/API doc; mutation nil/false/string semantics implicit; cryptic locals (p, w, library, mutated, bounds, box)

### `client/Bootstrap/CustomInventoryBootstrap.client.luau`

- **Type:** LocalScript · **Batch:** 09 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Disable Roblox's tool slots: the game uses its own hotbar + Inventory (GameHUD).
- **Dependencies:** —
- **Public functions:** —
- **Events:** RunService×1
- **Readability problems:** No location header; why the RenderStep re-check exists was terse

### `client/Inventory/CharacterInventoryStart.client.luau`

- **Type:** LocalScript · **Batch:** 09 · **Priority:** Low · **Status:** Reviewed — No Changes Needed
- **Responsibility:** StarterPlayer.StarterPlayerScripts.CharacterInventoryStart  (LocalScript)
- **Dependencies:** InventoryClient
- **Public functions:** —
- **Events:** —
- **Readability problems:** None (one-line entry point with location header)

### `shared/Inventory/CharacterInventory/HatchReveal.luau`

- **Type:** ModuleScript · **Batch:** 09 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.HatchReveal  (ModuleScript)
- **Dependencies:** InventoryConfig, InventoryFormat, InventoryStyle, UISound
- **Public functions:** Reveal.new, Reveal:Push, Reveal:_build, Reveal:_play
- **Events:** Connect×2, RunService×1
- **Readability problems:** T/F/R aliases; cryptic locals (W/H, p, tw, u, e, abs, held, out, cam, v); API and current (unused) status not documented

### `shared/Inventory/CharacterInventory/InventoryClient.luau`

- **Type:** ModuleScript · **Batch:** 09 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryClient  (ModuleScript)
- **Dependencies:** HatchReveal, InventoryConfig, InventoryFormat, InventoryModel, InventoryStyle, InventoryView
- **Public functions:** Client.Close, Client.Open, Client.Show, Client.Start, Client.Toggle, callbacks.onAction, callbacks.onClearFilters, callbacks.onClose, callbacks.onPin, callbacks.onRarity, callbacks.onSearch, callbacks.onSelect, callbacks.onSort
- **Events:** Connect×10, OnClientEvent×1, RunService×1
- **Readability problems:** T/F aliases; cryptic locals (t, v, L, snap, res, b, s, r, k, fn, dir, hum, char, cam); retired UI (Open early-return, buildHud unused, reveal unused) undocumented; network use not in header

### `shared/Inventory/CharacterInventory/InventoryModel.luau`

- **Type:** ModuleScript · **Batch:** 09 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryModel  (ModuleScript)
- **Dependencies:** InventoryConfig
- **Public functions:** Model.Actions, Model.BestPlan, Model.CompareTarget, Model.Filter, Model.Sort, Model.Strongest
- **Events:** —
- **Readability problems:** Cryptic locals (q, out, ra/rb, ta/tb, cmp, n, free, cap); BestPlan / CompareTarget rules only partly documented

### `shared/Inventory/CharacterInventory/InventoryStyle.luau`

- **Type:** ModuleScript · **Batch:** 09 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryStyle  (ModuleScript)
- **Dependencies:** InventoryConfig
- **Public functions:** Style.Button, Style.Chip, Style.Corner, Style.Deep, Style.Enabled, Style.FrameModel, Style.GoldText, Style.Inset, Style.Make, Style.Pad, Style.Page, Style.Roof, Style.SetOn, Style.Shell, Style.Stroke, Style.Stud, Style.StudBand, Style.Text
- **Events:** Connect×10
- **Readability problems:** T/F aliases; cryptic locals (inst, k/v, f, l/t/r/b, z, s, w, c, b, cam, cf, dist); Button attribute contract (Fill/BaseText) undocumented

### `shared/Inventory/CharacterInventory/InventoryView.luau`

- **Type:** ModuleScript · **Batch:** 09 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.CharacterInventory.InventoryView  (ModuleScript)
- **Dependencies:** InventoryConfig, InventoryFormat, InventoryModel, InventoryStyle, UISound
- **Public functions:** View.new, View:Destroy, View:FirstSelectable, View:Render, View:SetLoadingPulse, View:SetSize, View:Step, View:Toast, View:_assignCard, View:_build, View:_buildDetails, View:_connect, View:_layoutGrid, View:_newCard, View:_paintCard, View:_renderDetails, View:_showNote
- **Events:** Connect×7, RunService×1
- **Readability problems:** 1529-line builder; T/F aliases; cryptic locals (vp, c, f, b, s, p, sw, d, M, n, x0, dp, di, tw, a, mult, cap, toolH, searchW); 490-line _build; duplicated pip-clearing loop; API/callback contract undocumented

### `client/Plot/ConstructionClientStart.client.luau`

- **Type:** LocalScript · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.ConstructionClientStart  (LocalScript)
- **Dependencies:** ConstructionClient
- **Public functions:** —
- **Events:** —
- **Readability problems:** Minimal header

### `client/Plot/PortalClient.client.luau`

- **Type:** LocalScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** StarterPlayer.StarterPlayerScripts.PortalClient  (LocalScript)
- **Dependencies:** PortalConfig
- **Public functions:** —
- **Events:** Connect×4, RunService×1
- **Readability problems:** RS/C aliases; pervasive one-letter names (st, e, s, t, u, n, o, R, L, w, h, sc, rm, cg, im, f, k); generic helper names new/round/sound/play/add

### `client/Temple/GoldTempleEffects.client.luau`

- **Type:** LocalScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, RunService×1
- **Readability problems:** No header; names active/pending/add/queue/e/a/cf/x/z/r/v

### `client/Temple/TempleWindAnimator.client.luau`

- **Type:** LocalScript · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Airborne visual wind across the central temple courtyard. Authored beams provide an edit-mode preview; animation runs locally.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** Header lacked runtime location and authored attribute contract; t/folder names

### `client/Temple/UpgradeCameraShake.client.luau`

- **Type:** LocalScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, RunService×2
- **Readability problems:** No header (and Disabled in Rojo); Collection alias; names a/dir/eq/fn/at/m/final/finish/owner; unused radius

### `server/Plots/HomeAndBubbles.server.luau`

- **Type:** Script · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** HomeAndBubbles: Home button teleport (RemoteEvent RS.GoHome) + owner avatar bubble above every claimed temple.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×5, OnServerEvent×1, PlayerRemoving×1
- **Readability problems:** RS alias; one-letter names (p, att, bb, st, ns, img, ref); local `spawn` shadowed global; refresh() duplicated clearBubble() body

### `server/Plots/PlotChambers.server.luau`

- **Type:** Script · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** ConstructionService, UpgradePrices
- **Public functions:** —
- **Events:** Connect×4
- **Readability problems:** No header; vague names (sign, owned, anchor, make, place, wire, add, ownership, token, lv); magic numbers 3/80/admin id; unused param

### `server/Plots/PlotManager.server.luau`

- **Type:** Script · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** ConstructionService, TempleAppearanceThemes, TempleOccupancy, TempleSlotUnlocks, UpgradePrices
- **Public functions:** —
- **Events:** Connect×7, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** No header; cryptic locals (t, c, r, old, hum, snap, i, p); magic numbers (admin id, cooldown, distance, footprint); no sections in a 300-line lifecycle script

### `server/Plots/PlotReadyFlag.server.luau`

- **Type:** Script · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, PlayerAdded×1
- **Readability problems:** No header; names p/pl/check

### `server/Temple/Construction/ConstructionService.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ServerScriptService.Construction.ConstructionService  (ModuleScript, server)
- **Dependencies:** ConstructionConfig, ConstructionService
- **Public functions:** Service.Cancel, Service.IsBusy, Service.Upgrade
- **Events:** Connect×1, RunService×1
- **Readability problems:** Good header but many one-letter locals (o, d, n, tl, op, cf, sa/sb, ba/bb, k, g, p, m); module table named Service

### `server/Temple/TempleOccupancy.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** M.Apply, M.ApplyPaths
- **Events:** —
- **Readability problems:** No header; M / visible / v / on names

### `server/Temple/TempleSlotUnlocks.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** InventoryFormat
- **Public functions:** Slots.CanUpgrade, Slots.Capacity, Slots.Format, Slots.Purchase, Slots.Refresh, Slots.Reset, Slots.Setup
- **Events:** Connect×2
- **Readability problems:** No header; magic numbers (12, 3, 250000, 12 studs); short names (cap, st, tst, pc, pg, ps, amt, apad, gui, char, hum); Format alias

### `server/World/Portal/PortalBuilder.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.Portal.PortalBuilder  (ModuleScript, server)
- **Dependencies:** PortalConfig
- **Public functions:** Builder.Build
- **Events:** —
- **Readability problems:** Unrefactored near-copy of the shared PortalBuilder (C/P/part/p names)

### `server/World/Portal/PortalServer.server.luau`

- **Type:** Script · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.Portal.PortalServer  (Script)
- **Dependencies:** PortalConfig, PortalService
- **Public functions:** —
- **Events:** Connect×1
- **Readability problems:** C / Portal aliases; names i, list, src, ch, c, n, s, base

### `server/World/Portal/PortalService.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.Portal.PortalService  (ModuleScript, server)
- **Dependencies:** PortalBuilder, PortalConfig
- **Public functions:** S.Build, S.Cancel, S.Emerge, S.IsBusy
- **Events:** —
- **Readability problems:** C/S aliases; b/v/ref/d names; IsBusy missing from header

### `shared/Temple/Construction/ConstructionClient.luau`

- **Type:** ModuleScript · **Batch:** 10 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ReplicatedStorage.Construction.ConstructionClient  (ModuleScript, client)
- **Dependencies:** ConstructionClient, ConstructionConfig
- **Public functions:** Client.Start, Shake.add, Shake.step
- **Events:** Connect×5, RunService×3
- **Readability problems:** Dense one-letter locals in step/animation code (t, tl, k, e, a, b, s, p, st, hl, sp, str, c); unused ReplicatedStorage; Client table name

### `client/Plot/MoneyStandClient.client.luau`

- **Type:** LocalScript · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.MoneyStandClient  (LocalScript)
- **Dependencies:** InventoryFormat, UISound
- **Public functions:** —
- **Events:** Connect×7, OnClientEvent×1, RunService×1
- **Readability problems:** Unused player and shine; st/cf/g/tw/a/bb/t/p/k/v/c/x/m names; GOLD

### `client/UI/Controllers/LeaveEarningsOverlay.client.luau`

- **Type:** LocalScript · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** LeaveEarningsOverlay (LocalScript): when the Roblox menu (Esc) opens, show behind it that the temple keeps earning offline. Offline rate matches PlayerDataService: half of live income, for up to 8 hou
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** TS alias; F/K/W; t1-t3/s1-s3/g1/bg/top/txt/conn/acc/sz/img/dur names

### `client/UI/Controllers/OfflineEarningsUI.client.luau`

- **Type:** LocalScript · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** OfflineEarningsUI (LocalScript): "while you were away" window from Figma "Offline Earnings v3". Reads player attributes set by PlayerDataService: OfflineEarnings (cash put on the stands), OfflineSecon
- **Dependencies:** ShopConfig, UISound
- **Public functions:** —
- **Events:** Connect×7
- **Readability problems:** TS/RS/SC aliases; K/W/c3/new/lbl/amt/win/hd/dbl/fl/b/h/g/sc names; remote flow undocumented

### `client/UI/Screens/MoneyDisplay/MoneyLogic.client.luau`

- **Type:** LocalScript · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** Cash display: panel + coin art from ReplicatedStorage.GameMenuImages (CashPanel / CashCoin), smooth count, +$ popups, coin bounce, shine sweep, income per second.
- **Dependencies:** InventoryFormat, UISound
- **Public functions:** —
- **Events:** Connect×7, RunService×2
- **Readability problems:** RS alias; BASE_SCALE is reassigned (not a constant); tw(o,t,p,s,d), fmt/full/short, l/st/v/c/m/t0 names

### `server/Economy/MoneyStandOwnership.server.luau`

- **Type:** Script · **Batch:** 11 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** locked (but buyable-floor) slots show a grey, see-through ghost of the podium
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×4
- **Readability problems:** No header; CS alias; one-letter names (g, d); vague names (templates, ghostOf, setup, folder, owner)

### `server/Economy/MoneyStandServer.server.luau`

- **Type:** Script · **Batch:** 11 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.MoneyStandServer  (Script)
- **Dependencies:** QuestService
- **Public functions:** —
- **Events:** Connect×2
- **Readability problems:** Header lacked network authority / remote contract; cryptic locals (ls, rel, hx, hz, s, hrp, hum, on, m); generic names add/remove/remote

### `server/Economy/UpgradeEffects.luau`

- **Type:** ModuleScript · **Batch:** 11 · **Priority:** High · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** FX.Play
- **Events:** —
- **Readability problems:** No header/API doc; FX/Collection aliases; one-letter names (p, k, r, v, t, a, b); unused riseDistance; dead `if false` retention path undocumented

### `server/Services/GameMenu/GameAdapter.luau`

- **Type:** ModuleScript · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** Game Menu adapters: use existing server inventory/economy, never client stats.
- **Dependencies:** CharacterCatalog, EggCharacterRewards, InventoryService, QuestService, TempleSlotUnlocks
- **Public functions:** Adapter.BuyCash, Adapter.EquipBest, Adapter.ExportDiscovered, Adapter.GetCash, Adapter.GetCatalog, Adapter.GetDiscovered, Adapter.GetOwnedEggs, Adapter.GetPlot, Adapter.GrantReward, Adapter.GrantShopItem, Adapter.ImportDiscovered, Adapter.Init, Adapter.PlaceCharacters, Adapter.SpendCash, Adapter.StoreCharacters
- **Events:** Connect×13, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** RS/SS/SSS/Http/Catalog aliases; p/e/it/s/n/r/c/d names; unused Rewards/err/tool; no API doc

### `server/Services/GameMenu/GameMenuServer.server.luau`

- **Type:** Script · **Batch:** 11 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** ServerScriptService.GameMenu.GameMenuServer  (Script, server)
- **Dependencies:** Config, GameAdapter, QuestService, TempleSlotUnlocks, UpgradePrices
- **Public functions:** —
- **Events:** Connect×2, OnServerInvoke×2, PlayerRemoving×1
- **Readability problems:** RS alias; shadowed `root`; p/a/e/n/q/c/i/lv/req/UP/x names; ACT constant name; remote payloads undocumented

### `server/Services/GameMenu/QuestService.luau`

- **Type:** ModuleScript · **Batch:** 11 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerScriptService.GameMenu.QuestService  (ModuleScript, server)
- **Dependencies:** Config, QuestService
- **Public functions:** Q.Claim, Q.Increment, Q.Snapshot
- **Events:** Connect×2, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** Q/data/row/r/d/q/x names; unused params in Persistence stubs; header did not mention PlayerDataService override

### `server/Shops/ShopService.server.luau`

- **Type:** Script · **Batch:** 11 · **Priority:** High · **Status:** Refactored
- **Responsibility:** ServerScriptService.ShopService
- **Dependencies:** CharacterCatalog, ShopConfig
- **Public functions:** —
- **Events:** Connect×4, OnServerInvoke×1, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** MPS/DSS/RS aliases; p/d/r/t/lv/st/bb/img/sn/n names everywhere in purchase code; remote contract and receipt flow undocumented; unused `id`

### `server/Storage/MoneyStandBuilder.luau`

- **Type:** ModuleScript · **Batch:** 11 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** ServerStorage.MoneyStandBuilder  (ModuleScript)
- **Dependencies:** MoneyStandBuilder
- **Public functions:** —
- **Events:** —
- **Readability problems:** `C` palette; StudTexture constant casing; p/o/t/f/sg/bg/as names

### `client/Effects/AuraFlipbookPump.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Keeps flipbook auras alive: emits one crossfading particle every half lifetime (Rate is scaled to 0 on low graphics).
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** CS/cam aliases; e/p locals

### `client/Effects/GoldFXClient.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** No header; Collection/Run aliases; cryptic sweep math names (R, U, N, s, k, b, r, dot)

### `client/Effects/MutationDropBoardClient.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** No header; COL constant; last/left/board/timer names

### `client/Effects/NighttimeSky.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** No header; Tween/Run aliases; vague names (day, night, strength, clock, fx, part, text, change, k, r, l)

### `client/Effects/OwnerShowcaseFX.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** Client VFX around the owner's showcase statue: spinning ground sigil, lightning, pulsing light, and a power burst (shockwave + sky pillar + flash) every 7 s. Only runs while you're within 160 studs.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** TS alias; W/P/D/C color + cs/ns/em/part/ring cryptic helpers; one-letter locals throughout

### `client/UI/Controllers/NighttimeHUD.client.luau`

- **Type:** LocalScript · **Batch:** 12 · **Priority:** Medium · **Status:** Refactored
- **Responsibility:** StarterPlayerScripts.NighttimeHUD
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, RunService×1
- **Readability problems:** Cryptic helpers (make, tw, fmt, setPill) and locals (f, st, l, v, s, m, prev, acc); unused GuiService/barGrad; magic 300

### `server/Mutations/GoldFXServer.server.luau`

- **Type:** Script · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** GoldCharacterFX
- **Public functions:** —
- **Events:** Connect×5
- **Readability problems:** No header; FX alias; one-letter m/v; generic names (eligible, apply, watch, watched)

### `server/Mutations/MutationDropService.server.luau`

- **Type:** Script · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Guaranteed mutation egg in the river every INTERVAL seconds. The board by the river counts down to it. Change the timer: set this script's attribute "IntervalSeconds" (default 600 = 10 min).
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** Header lacked attribute contract; vague names (pick, nextAt, r, t, w)

### `server/Mutations/Mutations.luau`

- **Type:** ModuleScript · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Mutations: rolled on every hatch. Model swap + rarity aura + income multiplier (multiplier lives in RS.CharacterEconomy). Models: ServerStorage.UpdatePack_Mutations (pack names via BrainrotModels.<id>
- **Dependencies:** —
- **Public functions:** M.AddAura, M.Model, M.Roll
- **Events:** —
- **Readability problems:** Module table named M; SS alias; one-letter locals (m, c, d, p, k, v, a, w, cf); mutation model undocumented

### `server/Services/NighttimeClock.server.luau`

- **Type:** Script · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** —
- **Dependencies:** NighttimeService
- **Public functions:** —
- **Events:** —
- **Readability problems:** No header; Night alias

### `server/Services/NighttimeService.luau`

- **Type:** ModuleScript · **Batch:** 12 · **Priority:** Low · **Status:** Refactored
- **Responsibility:** Staff panel trigger: NightForcedUntil (server time) forces night on until then
- **Dependencies:** —
- **Public functions:** Service.Update
- **Events:** —
- **Readability problems:** No header; magic 300/20; vague boundary/forced

### `client/UI/Screens/GameMenus/MenuLogic.client.luau`

- **Type:** LocalScript · **Batch:** 13 · **Priority:** High · **Status:** Pending
- **Responsibility:** StarterGui.GameMenus.MenuLogic (LocalScript) Opens/closes the four ForgeGUI panels and fills them with live data from ServerScriptService.GameMenu (GetState / Action / Changed remotes). All positions 
- **Dependencies:** Config, ShopConfig, UISound, UpgradePrices
- **Public functions:** —
- **Events:** Connect×50, OnClientEvent×1, RunService×1
- **Readability problems:** 106 dense one-line statements; 180 lines >160 chars; 21 one-letter locals

### `client/UI/Controllers/GameHUD.client.luau`

- **Type:** LocalScript · **Batch:** 14 · **Priority:** High · **Status:** Pending
- **Responsibility:** GameHUD: custom hotbar (replaces Roblox's), backpack with egg and character selling, and the top-centre night timer.
- **Dependencies:** CharacterCatalog, PixelIcon, UISound
- **Public functions:** —
- **Events:** Connect×52, OnClientEvent×2, RunService×2
- **Readability problems:** 127 dense one-line statements; 94 lines >160 chars; 21 one-letter locals

### `client/Plot/PromptCards.client.luau`

- **Type:** LocalScript · **Batch:** 15 · **Priority:** High · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.PromptCards
- **Dependencies:** UISound
- **Public functions:** —
- **Events:** Connect×20, OnClientEvent×1
- **Readability problems:** 47 dense one-line statements; 21 lines >160 chars; 13 one-letter locals

### `client/UI/Controllers/FeedbackClient.client.luau`

- **Type:** LocalScript · **Batch:** 15 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Feedback button (right side) + window. Sends to ReplicatedStorage.SendFeedback.
- **Dependencies:** UISound
- **Public functions:** —
- **Events:** Connect×12
- **Readability problems:** 13 dense one-line statements; 14 lines >160 chars; 6 one-letter locals

### `client/UI/Controllers/FigmaSkin.client.luau`

- **Type:** LocalScript · **Batch:** 15 · **Priority:** High · **Status:** Pending
- **Responsibility:** FigmaSkin: restyles the code-built menu content to the Figma "Hatch an Anime – Game UI" design. Only colours/decoration change (no layout, no click logic): dark teal rows -> night purple studded block
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×22, OnClientEvent×1
- **Readability problems:** 107 dense one-line statements; 12 lines >160 chars; 14 one-letter locals

### `client/UI/Controllers/PixelIconSharpener.client.luau`

- **Type:** LocalScript · **Batch:** 15 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Pixel-art icons (CC0 packs: OwlishMedia "RPG UI icons", Bonsaiheldin "Gold treasure icons") are drawn with nearest-neighbour scaling so they stay crisp instead of blurry.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1
- **Readability problems:** 1 dense one-line statements; 1 lines >160 chars

### `client/UI/Controllers/SharpUI.client.luau`

- **Type:** LocalScript · **Batch:** 15 · **Priority:** Low · **Status:** Pending
- **Responsibility:** SharpUI: house style = sharp corners + solid black outlines on all game menus. Strips UICorner, forces UIStroke black/mitred, removes thin white highlight lines. Image art (torii, side buttons) is lef
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×5, RunService×1
- **Readability problems:** 14 dense one-line statements; 1 lines >160 chars; 4 one-letter locals

### `server/Services/FeedbackService.server.luau`

- **Type:** Script · **Batch:** 15 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Player feedback -> private Discord #feedback (via webhook relay, because Discord blocks Roblox servers). Paste the Discord webhook link into ServerStorage.FeedbackConfig attribute "WebhookUrl" (never 
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, OnServerInvoke×1, PlayerRemoving×1
- **Readability problems:** 6 dense one-line statements; 1 lines >160 chars

### `client/UI/Controllers/LeaderboardClientStart.client.luau`

- **Type:** LocalScript · **Batch:** 16 · **Priority:** Low · **Status:** Pending
- **Responsibility:** StarterPlayer.StarterPlayerScripts.LeaderboardClientStart  (LocalScript)
- **Dependencies:** LeaderboardClient
- **Public functions:** —
- **Events:** —
- **Readability problems:** —

### `server/Services/Leaderboard/LeaderboardChampions.server.luau`

- **Type:** Script · **Batch:** 16 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Global Cash and Eggs Hatched podiums. Avatar failures never remove a winner's identity.
- **Dependencies:** LeaderboardConfig, LeaderboardFormat, LeaderboardService
- **Public functions:** —
- **Events:** Connect×6
- **Readability problems:** 21 dense one-line statements; 1 one-letter locals

### `server/Services/Leaderboard/LeaderboardServer.server.luau`

- **Type:** Script · **Batch:** 16 · **Priority:** Low · **Status:** Pending
- **Responsibility:** ServerScriptService.Leaderboard.LeaderboardServer  (Script)
- **Dependencies:** LeaderboardService
- **Public functions:** —
- **Events:** —
- **Readability problems:** —

### `server/Services/Leaderboard/LeaderboardService.luau`

- **Type:** ModuleScript · **Batch:** 16 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** ServerScriptService.Leaderboard.LeaderboardService  (ModuleScript)
- **Dependencies:** LeaderboardConfig
- **Public functions:** Service.Forget, Service.GetGlobalTop, Service.GetValue, Service.RecordHatch, Service.SetGlobalCash, Service.Start
- **Events:** Connect×4, OnServerInvoke×1, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** 39 dense one-line statements; 1 lines >160 chars; 5 one-letter locals

### `shared/UI/Leaderboard/LeaderboardClient.luau`

- **Type:** ModuleScript · **Batch:** 16 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** true if the click landed on any visible part of a panel (anything in this ScreenGui that isn't the dim)
- **Dependencies:** LeaderboardConfig, LeaderboardView, UISound
- **Public functions:** Client.Close, Client.IsOpen, Client.Open, Client.Start
- **Events:** Connect×5
- **Readability problems:** 39 dense one-line statements; 1 lines >160 chars; 6 one-letter locals

### `shared/UI/Leaderboard/LeaderboardView.luau`

- **Type:** ModuleScript · **Batch:** 16 · **Priority:** High · **Status:** Pending
- **Responsibility:** ReplicatedStorage.Leaderboard.LeaderboardView  (ModuleScript)
- **Dependencies:** LeaderboardConfig, LeaderboardFormat
- **Public functions:** View.new, View:DefaultSelection, View:Destroy, View:Render, View:Tick, View:_build, View:_countUp, View:_meta, View:_row, View:_selectScope, View:_selectTab, View:_setStatus
- **Events:** Connect×10, RunService×1
- **Readability problems:** 30 dense one-line statements; 5 lines >160 chars; 14 one-letter locals

### `client/Bootstrap/LoadingScreen.client.luau`

- **Type:** LocalScript · **Batch:** 17 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** ReplicatedFirst.LoadingScreen  (LocalScript) — Hatch An Anime × Velm Studios
- **Dependencies:** Config
- **Public functions:** —
- **Events:** Connect×2, RunService×2
- **Readability problems:** 19 dense one-line statements; 22 lines >160 chars; 9 one-letter locals

### `client/Bootstrap/LoadingScreen/Config.luau`

- **Type:** ModuleScript · **Batch:** 17 · **Priority:** Low · **Status:** Pending
- **Responsibility:** ReplicatedFirst.LoadingScreen.Config  (ModuleScript, child of the LoadingScreen LocalScript)
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** —

### `client/Bootstrap/StartupLoader.luau`

- **Type:** ModuleScript · **Batch:** 17 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Startup readiness and bounded content loading. No gameplay data is created here.
- **Dependencies:** —
- **Public functions:** M.Collect, M.Preload, M.Ready, M.Run
- **Events:** —
- **Readability problems:** 18 dense one-line statements; 2 lines >160 chars; 2 one-letter locals

### `client/Tutorial/FirstHatchTutorial.client.luau`

- **Type:** LocalScript · **Batch:** 17 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** A local first-hatch guide. No client requests can grant progress or rewards.
- **Dependencies:** InventoryConfig
- **Public functions:** —
- **Events:** Connect×6, RunService×1
- **Readability problems:** 50 dense one-line statements; 22 lines >160 chars; 6 one-letter locals

### `client/Tutorial/JoinArrival.client.luau`

- **Type:** LocalScript · **Batch:** 17 · **Priority:** High · **Status:** Pending
- **Responsibility:** JoinArrival (LocalScript, StarterPlayerScripts)
- **Dependencies:** Config
- **Public functions:** —
- **Events:** Connect×11, RunService×1
- **Readability problems:** 66 dense one-line statements; 18 lines >160 chars; 11 one-letter locals

### `server/Services/StartupAssetManifest.server.luau`

- **Type:** Script · **Batch:** 17 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Build a content-ID manifest, including gameplay templates not yet replicated.
- **Dependencies:** StartupLoader
- **Public functions:** —
- **Events:** —
- **Readability problems:** 2 dense one-line statements; 1 lines >160 chars; 1 one-letter locals

### `client/Cinematics/TrailerCinematic.client.luau`

- **Type:** LocalScript · **Batch:** 18 · **Priority:** High · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.TrailerCinematic  (LocalScript)
- **Dependencies:** TrailerConfig
- **Public functions:** —
- **Events:** Connect×11, RunService×1, PlayerAdded×1
- **Readability problems:** 229 dense one-line statements; 56 lines >160 chars; 24 one-letter locals

### `client/Cinematics/CineCamClient.client.luau`

- **Type:** LocalScript · **Batch:** 19 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Hatch An Anime CineCam: place in StarterPlayerScripts as CineCamClient.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×7, OnClientEvent×1, RunService×2
- **Readability problems:** 44 dense one-line statements; 8 one-letter locals

### `client/Cinematics/TrailerDuoV2.client.luau`

- **Type:** LocalScript · **Batch:** 19 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** TrailerDuo (v2): two players drop from a portal, look around, see their temples, fight over a river egg. /trailer opens a picker with every trailer version. Recording only, local only.
- **Dependencies:** TrailerConfig
- **Public functions:** _G.TrailerDuoStartV2
- **Events:** Connect×3, RunService×1
- **Readability problems:** 22 dense one-line statements; 23 lines >160 chars; 16 one-letter locals

### `client/Cinematics/TrailerDuoV3.client.luau`

- **Type:** LocalScript · **Batch:** 19 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** TrailerDuoV3: Jen1sen + Jacobo6I9 step out of two Summon Gates by the temple, look around, peek at the temple, an egg drops from the sky into the river, both sprint and fight over it. /trailer opens t
- **Dependencies:** PortalBuilder, PortalConfig, TrailerConfig
- **Public functions:** _G.TrailerDuoStartV3
- **Events:** Connect×3, RunService×1
- **Readability problems:** 30 dense one-line statements; 33 lines >160 chars; 16 one-letter locals

### `server/Cinematics/CineCamServer.server.luau`

- **Type:** Script · **Batch:** 19 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Hatch An Anime CineCam: place in ServerScriptService as CineCamServer.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, OnServerInvoke×1
- **Readability problems:** 17 dense one-line statements

### `client/Admin/AdminTerminal.client.luau`

- **Type:** LocalScript · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** AdminTerminal (LocalScript): command line for staff (owner + admins from AdminRoles). Open with F2 or the ` key, or type /terminal in chat. Every command goes through ReplicatedStorage.OwnerPanel.Acti
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×4
- **Readability problems:** 46 dense one-line statements; 24 lines >160 chars; 8 one-letter locals

### `client/Admin/OwnerPanelClient.client.luau`

- **Type:** LocalScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.OwnerPanelClient (LocalScript)
- **Dependencies:** StudPanel
- **Public functions:** —
- **Events:** Connect×6, OnClientEvent×1, PlayerAdded×1, PlayerRemoving×1
- **Readability problems:** 9 dense one-line statements; 1 lines >160 chars; 1 one-letter locals

### `client/Admin/StaffAnnouncements.client.luau`

- **Type:** LocalScript · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Announcement banner (staff announcements, events, /update). Rounded 3D card in the game's clean style: no pill studs. /update countdown ticks update ONE banner in place instead of stacking five.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, OnClientEvent×1
- **Readability problems:** 5 dense one-line statements; 24 lines >160 chars; 4 one-letter locals

### `client/Admin/VIPChatTag.client.luau`

- **Type:** LocalScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Gold [VIP] prefix in chat for players with the VIP attribute (set by ShopService)
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** 1 one-letter locals

### `server/Admin/AdminRoles.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Who can open the panel. Owner = everything. Admin = events, river spawns, announcements, teleports, respawn, kick. Add permanent admins here by User ID, or use the Admins page in the owner panel (save
- **Dependencies:** —
- **Public functions:** M.Can, M.List, M.Role, M.SetAdmin
- **Events:** Connect×1, PlayerAdded×1
- **Readability problems:** 7 dense one-line statements; 1 lines >160 chars; 4 one-letter locals

### `server/Admin/OwnerControlServer.server.luau`

- **Type:** Script · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** AdminRoles, CharacterCatalog, EggCharacterRewards, OwnerGameActions
- **Public functions:** —
- **Events:** Connect×2, OnServerInvoke×1, PlayerRemoving×1
- **Readability problems:** 19 dense one-line statements; 13 lines >160 chars; 2 one-letter locals

### `server/Admin/OwnerGameActions.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** AdminRoles, TempleSlotUnlocks
- **Public functions:** Actions.Run
- **Events:** —
- **Readability problems:** 14 dense one-line statements; 8 lines >160 chars; 5 one-letter locals

### `server/Admin/OwnerOverheadBanner.server.luau`

- **Type:** Script · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** ServerScriptService.OwnerOverheadBanner Verified account usernames are used, never DisplayName.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, PlayerAdded×1
- **Readability problems:** 5 dense one-line statements

### `server/Admin/OwnerPanelServer.server.luau`

- **Type:** Script · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** Owner / Admin panel server. Every request is checked here against AdminRoles. Owner: everything. Admin: events, river spawns, announcements, teleports, respawn, kick (not staff).
- **Dependencies:** AdminRoles, CharacterCatalog, CrossServerService, PlayerPunish, SaveRestore, StaffServerService
- **Public functions:** —
- **Events:** Connect×2, OnServerInvoke×1, PlayerRemoving×1
- **Readability problems:** 37 dense one-line statements; 17 lines >160 chars; 3 one-letter locals

### `server/Admin/OwnerShowcase.server.luau`

- **Type:** Script · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** OwnerShowcase: a statue of the owner (real avatar) with the KitsBlox aura, ONLY on the owner's own temple.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3
- **Readability problems:** 8 dense one-line statements; 3 one-letter locals

### `server/Admin/PlayerPunish.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** PlayerPunish (owner only, used by the owner panel "Punish" page): take money from a player or wipe their save + leaderboard. Works for online (this server) and offline players. A player playing in ANO
- **Dependencies:** LeaderboardService
- **Public functions:** M.TakeCash, M.Wipe
- **Events:** —
- **Readability problems:** 10 dense one-line statements; 3 one-letter locals

### `server/Admin/RoleTagServer.server.luau`

- **Type:** Script · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** AdminRoles
- **Public functions:** —
- **Events:** Connect×2, PlayerAdded×1
- **Readability problems:** —

### `server/Admin/StaffServerService.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** !strict StaffServerService: Manages reserved server access for Admins and Owner. Cross-server sync via MemoryStoreService ensures all staff join the same reserved instance.
- **Dependencies:** AdminRoles
- **Public functions:** StaffServerService.GetOrCreateStaffServerCode, StaffServerService.ReturnToPublic, StaffServerService.TeleportToStaffServer
- **Events:** Connect×3, PlayerAdded×2
- **Readability problems:** —

### `server/Services/CrossServerService.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** !strict CrossServerService: Handles universe-wide announcements and update notifications using MessagingService.
- **Dependencies:** AdminRoles
- **Public functions:** CrossServerService.AnnounceUpdate, CrossServerService.Broadcast, CrossServerService.GlobalAnnounce, CrossServerService.PerformRejoin
- **Events:** Connect×3, PlayerAdded×4
- **Readability problems:** 2 dense one-line statements

### `shared/Admin/OwnerPanel/ActivityLog.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** M.Add, M.Clear
- **Events:** —
- **Readability problems:** 1 lines >160 chars; 1 one-letter locals

### `shared/Admin/OwnerPanel/Components.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** Theme
- **Public functions:** C.Border, C.Button, C.Card, C.Disable, C.Format, C.Grid, C.Input, C.Label, C.Make, C.Round, C.Stack
- **Events:** Connect×3
- **Readability problems:** 5 dense one-line statements; 9 lines >160 chars; 6 one-letter locals

### `shared/Admin/OwnerPanel/ConfirmDialog.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** Components, Theme
- **Public functions:** M.Show
- **Events:** —
- **Readability problems:** 2 dense one-line statements; 1 lines >160 chars; 3 one-letter locals

### `shared/Admin/OwnerPanel/PlayerRow.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** Components, Theme
- **Public functions:** M.New
- **Events:** —
- **Readability problems:** 1 dense one-line statements; 1 lines >160 chars; 4 one-letter locals

### `shared/Admin/OwnerPanel/Theme.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** 1 lines >160 chars

### `shared/Admin/OwnerPanel/Toast.luau`

- **Type:** ModuleScript · **Batch:** 20 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** Components, Theme
- **Public functions:** M.Show
- **Events:** —
- **Readability problems:** 2 dense one-line statements; 3 lines >160 chars; 5 one-letter locals

### `shared/Admin/OwnerPanel/StudPanel.luau`

- **Type:** ModuleScript · **Batch:** 21 · **Priority:** High · **Status:** Pending
- **Responsibility:** StudPanel: the brick/stud style Owner + Admin panel UI. Built by OwnerPanelClient. Purely visual: every button calls the server (OwnerPanelServer), which checks the role again.
- **Dependencies:** —
- **Public functions:** M.Build
- **Events:** Connect×12
- **Readability problems:** 54 dense one-line statements; 71 lines >160 chars; 21 one-letter locals

### `client/Audio/BackgroundMusic.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.BackgroundMusic
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3
- **Readability problems:** 11 dense one-line statements

### `client/Audio/MusicSettings.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.MusicSettings  — Settings button + panel
- **Dependencies:** PixelIcon, UISound
- **Public functions:** —
- **Events:** Connect×15
- **Readability problems:** 22 dense one-line statements; 16 lines >160 chars; 7 one-letter locals

### `client/Audio/UIAudioClient.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** PlayerGui buttons, including menus built after join, share the same audio palette. Activated supports mouse, touch, and gamepad. UISound guards duplicate bindings.
- **Dependencies:** UISound
- **Public functions:** —
- **Events:** —
- **Readability problems:** —

### `client/Weapons/BatMotionClient.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** BatMotionClient: play the uploaded bat swing through the character Animator.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×6
- **Readability problems:** 7 dense one-line statements

### `client/Weapons/WeaponPreloadClient.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×3
- **Readability problems:** 4 dense one-line statements

### `client/World/PirateEggConveyorMotion.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** RollingMotion
- **Public functions:** —
- **Events:** Connect×8, RunService×2
- **Readability problems:** 17 dense one-line statements; 6 lines >160 chars; 1 one-letter locals

### `client/World/RiverFlow.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** RiverFlow: scrolling current streaks laid along the river so the water visibly flows downstream (client only).
- **Dependencies:** RiverPath
- **Public functions:** —
- **Events:** —
- **Readability problems:** 1 lines >160 chars; 4 one-letter locals

### `client/World/WaterFX.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** StarterPlayerScripts.WaterFX  (client only: animates flow streaks, foam and ripples — nothing replicates)
- **Dependencies:** RiverPath
- **Public functions:** —
- **Events:** Connect×2, RunService×1
- **Readability problems:** 5 dense one-line statements; 6 one-letter locals

### `client/World/WaterfallFallMotion.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Falling streaks, foam boil and ripple rings for the waterfall. Everything is local (client-only) so it is smooth and costs the server nothing.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, RunService×1
- **Readability problems:** 5 dense one-line statements; 6 one-letter locals

### `client/World/WaterfallRiverMotion.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Soft wake ring around river eggs, following the new winding WaterfallRiver.
- **Dependencies:** RiverPath
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** 7 dense one-line statements; 1 lines >160 chars; 4 one-letter locals

### `server/DevTools/DevWorkshop/AnimRig_MovedFromWorkspace/Animate.client.luau`

- **Type:** LocalScript · **Batch:** 22 · **Priority:** High · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×9
- **Readability problems:** —

### `server/DevTools/DevWorkshop/HalloweenTemple_Deluxe/SpookyMotion.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** candle-style flicker: old pumpkin "Rib" lights plus any light inside a voxel *_Glow part (jack-o'-lanterns, candles)
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, RunService×1
- **Readability problems:** 2 dense one-line statements; 1 lines >160 chars; 1 one-letter locals

### `server/Services/NoDropping.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Players can't drop anything (owner's rule). Safety net: any Tool that ends up in a player's Backpack or character gets CanBeDropped = false, even if a future script forgets. (The F key / Drop button a
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×4, PlayerAdded×1
- **Readability problems:** 4 dense one-line statements

### `server/Services/ToolIcons.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** ToolIcons: every egg / character Tool gets a picture (TextureId) so Roblox's default backpack + hotbar show what you hold. Characters use their Index art (CharacterCatalog .image); eggs use rendered i
- **Dependencies:** CharacterCatalog
- **Public functions:** —
- **Events:** Connect×4, PlayerAdded×1
- **Readability problems:** 10 dense one-line statements; 1 one-letter locals

### `server/Storage/FutureUpdateContent/RiverBeforeGoldContentReservation.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** RollingMotion
- **Public functions:** —
- **Events:** Connect×2, OnServerEvent×1
- **Readability problems:** 19 dense one-line statements; 3 lines >160 chars; 2 one-letter locals

### `server/Storage/HalloweenSwitch.luau`

- **Type:** ModuleScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** HALLOWEEN SWITCH Turn Halloween OFF:  require(game.ServerStorage.HalloweenSwitch).Set(false) Turn Halloween ON:   require(game.ServerStorage.HalloweenSwitch).Set(true) Run it in the Studio command bar
- **Dependencies:** HalloweenSwitch, TempleAppearanceThemes
- **Public functions:** S.Set
- **Events:** —
- **Readability problems:** 8 dense one-line statements; 1 lines >160 chars; 7 one-letter locals

### `server/Storage/RestoreSurfaceAppearances.luau`

- **Type:** ModuleScript · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** require(game.ServerStorage.RestoreSurfaceAppearances)() puts back the SurfaceAppearances + RenderFidelity removed by the Oct 15 memory cleanup
- **Dependencies:** —
- **Public functions:** —
- **Events:** —
- **Readability problems:** 1 dense one-line statements; 2 lines >160 chars; 2 one-letter locals

### `server/Storage/StoredCollectAllZones/CollectAllZoneServer.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Collect-all pad in front of each temple (Adam, Oct 16). Stand on your own plot's pad to collect every MoneyStand you own at once. The label shows the total waiting.
- **Dependencies:** QuestService
- **Public functions:** —
- **Events:** —
- **Readability problems:** 6 dense one-line statements; 1 one-letter locals

### `server/Weapons/WeaponGiver.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×2, PlayerAdded×4
- **Readability problems:** —

### `server/Weapons/WoodenBat/BatServer.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Medium · **Status:** Pending
- **Responsibility:** —
- **Dependencies:** RiverEggCarryService, TwoHandItemCarryService
- **Public functions:** —
- **Events:** Connect×3, RunService×1
- **Readability problems:** 13 dense one-line statements

### `server/World/PumpkinGentleman/PumpkinIdle.server.luau`

- **Type:** Script · **Batch:** 22 · **Priority:** Low · **Status:** Pending
- **Responsibility:** Idle loop for the Pumpkin Gentleman: breathing, look around, cane tap, hat tip, flickering face.
- **Dependencies:** —
- **Public functions:** —
- **Events:** Connect×1, RunService×1
- **Readability problems:** 4 dense one-line statements; 3 one-letter locals


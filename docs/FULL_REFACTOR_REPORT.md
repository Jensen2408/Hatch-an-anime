# Full Luau Refactor Report — Hatch an Anime

Branch `refactor/luau-cleanup`, 24 commits on top of `8aa46a3` (2026-10-19).
Per-script results are in [SCRIPT_REFACTOR_TRACKER.md](SCRIPT_REFACTOR_TRACKER.md).

**Nothing in this refactor was play-tested in Roblox Studio.** Behaviour preservation rests entirely on the static
checks described in section 11. Sections 1–11 record completed work; section 12 records issues that were found
and **not** fixed, and recommendations.

---

## 1–6. Numbers

| # | Item | Value |
|---|---|---:|
| 1 | Active scripts discovered (all `.luau` under `src/`, every one mapped in `default.project.json`) | **189** |
| 2 | Scripts reviewed | **189** |
| 3 | Scripts modified (status *Refactored*) | **184** |
| 4 | Scripts left unchanged beyond formatting (*Reviewed — No Changes Needed*) | **5** |
| 5 | Blocked scripts (*Blocked — Requires Manual Review*) | **0** |
| 6a | Lines at `8aa46a3` (original, many statements packed per line) | 28,666 |
| 6b | Lines after the StyLua formatting pass only | 53,404 |
| 6c | Lines now | 58,169 |

The line growth is almost entirely formatting (6a → 6b, one statement per line, 4-space indentation) plus new
header and section comments (6b → 6c). As the brief notes, fewer lines would not have meant better code.

Of the 189 scripts:
- **177 compile to bytecode identical to the original.** These are proven behaviour-identical (see section 11).
- **12 have structural changes:** helper extraction or merging identical blocks. Each one was reviewed individually.

The 5 unchanged scripts are `JoinArrival/Config`, `UpdateConfig`, `InventoryConfig`, `LeaderboardConfig` and
`CharacterInventoryStart`. They were already clean; the formatting pass still applies to them.

## 7. Major readability improvements

- **Consistent formatting:** StyLua was applied to every file (4 spaces, 120 columns, double quotes). Before this,
  selene reported 9,038 `multiple_statements` warnings: many lines held several statements joined with `;` or
  `then … end`.
- **Header comment on every script:** each one states:
  - what the script does and where it lives at runtime;
  - the remotes, bindables, attributes and `_G` keys it uses, with their payload shapes;
  - for server scripts, a **network-authority** section: what the server validates and what it trusts from the
    client.
- **Persistence and economy contracts documented in place:**
  - **PlayerDataService:** the saved schema `v, savedAt, lock, cash, tools{k,n,a,inc}, placed, …`, the load/save
    flow, the lock and the failure handling.
  - **LeaderboardService:** the OrderedDataStore model.
  - **ShopService:** the ProcessReceipt flow.
  - **InventoryService and GameMenuServer:** the remote contracts.
  - **CineCamServer:** every validation bound.
  - **Admin scripts:** who is authorized, how that is checked, and which remote input is trusted.
- **Naming:**
  - Short service aliases now use the full service name, e.g. `RS`/`TS`/`UIS` → `ReplicatedStorage`/`TweenService`/`UserInputService`. None remain.
  - Single-letter module locals are gone: `C` → `Config`, `M` → `Mutations`, `S` → `ServerConfig`.
  - Several thousand cryptic locals got descriptive names.
  - Constants are `UPPER_SNAKE_CASE`.
  - Unused locals are prefixed with `_` and kept, because removing them could remove a side effect.
  - Table keys, attribute names, instance names, remote names and public module APIs were **never** renamed.
- **Navigation:** large scripts have a table of contents and numbered `-- ===== N. Title =====` section banners.
- **Stale comments corrected.** For example:
  - PlayerDataService said "autosave every 90 s"; the code uses 30 s.
  - FloatingCharacters' header described motion the code no longer does.
  - EggStealClient's header described a thief card that no longer exists.
  - HatchFXServer's `playerJobs` comment named the wrong key.
- **selene: 9,446 warnings + 11 errors → 161 warnings + 11 errors.**
  - `shadowing` went from 30 to 0, `unused_variable` from 176 to 2, and `multiple_statements` from 9,038 to 0.
  - The 11 errors are the same as at baseline. Each one is either a selene false positive or pre-existing code that
    is documented in place (details in section 11).

## 8. Functions extracted

Only 12 files have structural changes. Every other file kept its original structure.

| File | Extracted helpers |
|---|---|
| `client/UI/Screens/GameMenus/MenuLogic.client.luau` | `extendDimPastInsets`, `fitPanelToScreen`, `buildIndexSeasonTabs`, `buildIndexProgressStrip`, `buildIndexRarityFilters`, `buildIndexCell`, `buildIndexDetail`, `buildQuestTabs`, `buildQuestTimer`, `buildQuestRow`, `applyFigmaWindow`, `addSlotCell`, `addUpgradeRow`, `addDealEggShowcase`, `addDealCountdown` (15) |
| `client/UI/Controllers/GameHUD.client.luau` | `addMutationAura`, `buildPreviewModel`, `restyleHeldSlots`, `buildSlot`, `buildBagCard`, `refreshControls`, `buildCell`, `playNightTransition`, `playDayTransition`, `updateBigCountdown` (10) |
| `client/Cinematics/TrailerCinematic.client.luau` | `loadMarkers`, `findIncubator`, `addDerivedMarkers`, `assertSetupComplete`, `buildActor`, `findEggSocket`, `computeShots`, `planRoutes`, `preloadAssets`, `startPlayback`, `hideCoreUi`, `hideGuisAndPrompts`, `hideCharacters`, `disablePlayerControls`, `applyColorGrade`, `takeOverCamera`, `createRiftParts`, `createFallTrail`, `animateRift`, `applyEggWobble`, `revealReward`, `updateRewardPop`, `updateRewardLift`, `spawnSlotGlow`, `sumShakes`, `pullCameraClear` (26) |
| `client/Hatching/CinematicHatch.client.luau` | `createCoreEffects`, `showRecord`, `animateHatching`, `animateRelease`, `updateOwnerCamera` (5) |
| `shared/Hatching/HatchFX/HatchFXClient.luau` | `rockEgg`, `updateCracks`, `updateShards`, `updateCharacter`, `createEggEffects`, `collectMachineGlow` (6) |
| `shared/UI/Leaderboard/LeaderboardView.luau` | `buildHeader`, `buildTabs`, `buildScopeToggle`, `buildColumnLabels`, `buildWell`, `buildStatusStates`, `buildYourRank`, `buildMetaLine`, `yourRankNote` (9) |
| `shared/Inventory/CharacterInventory/InventoryView.luau` | `buildNote`, `buildSkeletonCards`, `clearPips` (3) |
| `shared/Admin/OwnerPanel/StudPanel.luau` | `addAmountPresets`, `addPlayerRow`, `addHalloweenDropCard` (3) |
| `client/Tutorial/JoinArrival.client.luau` | `showWelcomeCard` (1) |
| `client/UI/Controllers/FeedbackClient.client.luau` | `setZIndexDeep` (1) |
| `server/Hatching/HatchVideoService.server.luau` | `destroyHatchedReward` (1) |
| `server/Plots/HomeAndBubbles.server.luau` | none new; it reuses the existing `clearBubble` |

Every extraction follows the same pattern:
- The block was moved verbatim (only re-indented) and is called exactly where it used to be.
- No helper assigns to a local of its caller. Shared state is written through table fields or through upvalues
  that both sides already shared.
- A `return` inside a helper exists only where the block was the tail of the original function.

The one documented exception is in TrailerCinematic: `findEggSocket` turns each of its five `run.socket = X`
branches into `return X`, and the caller assigns `run.socket`. All five branches are covered, so the result is the
same.

## 9. Duplicated logic consolidated

Only blocks that were byte-for-byte identical were merged:
- **HatchVideoService:** two identical reward-cleanup closures (they capture nothing) became `destroyHatchedReward`.
- **HomeAndBubbles:** `refresh` contained an inline copy of `clearBubble`'s body; it now calls `clearBubble`.
- **InventoryView:** two identical pip-destroy loops became `clearPips`.
- **FeedbackClient:** three identical deep-ZIndex loops became `setZIndexDeep`.
- **StudPanel:** the 1K–1T amount-preset grid on the Money and Punish pages became `addAmountPresets`.
- **server `World/Portal/PortalBuilder.luau`:** this is a near-copy of the shared PortalBuilder. It was synced with
  the refactored shared copy so the two files again differ only in their header lines. They were not merged.

**Cross-file consolidation was deliberately not done.** Merging code across files changes bytecode in many
consumers at once, and several "duplicates" turned out to differ in rounding, defaults or easing. The candidates
are listed under section 12.3.

## 10. Large scripts refactored

| Script | Lines at `8aa46a3` | After format | Now | Bytecode |
|---|---:|---:|---:|---|
| `client/UI/Screens/GameMenus/MenuLogic.client.luau` | 1246 | 3477 | 3874 | CHANGED (15 helpers) |
| `client/UI/Controllers/GameHUD.client.luau` | 741 | 2372 | 2538 | CHANGED (10 helpers) |
| `client/Cinematics/TrailerCinematic.client.luau` | 962 | 2355 | 2688 | CHANGED (26 helpers) |
| `shared/Admin/OwnerPanel/StudPanel.luau` | 488 | 1599 | 1813 | CHANGED (3 helpers) |
| `shared/Inventory/CharacterInventory/InventoryView.luau` | 982 | 1529 | 1588 | CHANGED (3 helpers) |
| `shared/UI/Leaderboard/LeaderboardView.luau` | 769 | 1230 | 1289 | CHANGED (9 helpers) |
| `shared/Egg/EggSteal/EggStealClient.luau` | 849 | 1184 | 1245 | SAME |
| `server/DevTools/.../Animate.client.luau` (Roblox stock script) | 971 | 1020 | 1029 | SAME |
| `server/Characters/CharacterInventory/InventoryService.luau` | 650 | 929 | 973 | SAME |
| `server/Eggs/EggSteal/EggStealService.luau` | 687 | 926 | 949 | SAME |
| `shared/Hatching/HatchFX/HatchFXClient.luau` | 446 | 898 | 980 | CHANGED (6 helpers) |
| `client/Hatching/CinematicHatch.client.luau` | 612 | 897 | 967 | CHANGED (5 helpers) |
| `client/Tutorial/JoinArrival.client.luau` | 523 | 894 | 924 | CHANGED (1 helper) |
| `server/PlayerData/PlayerDataService.server.luau` | 402 | 826 | 922 | SAME |
| `server/Plots/PlotManager.server.luau` | 171 | 300 | 388 | SAME |
| `shared/Hatching/IncubatorController.luau` | 185 | 296 | 315 | SAME |

**No script was split into child modules.** Requiring a module runs its body at require time. Splitting these
scripts would also have moved `WaitForChild` calls and top-level side effects relative to each other, so it was not
safe to verify without play-testing. Large scripts got a table of contents, section banners and in-file helpers
instead.

Server persistence and economy code was renamed and commented only, and stays bytecode SAME. This covers
PlayerDataService, ShopService, LeaderboardService, InventoryService and the admin permission paths.

## 11. Static verification

**Tools added:** in `rokit.toml`, `StyLua 2.6.0` and `selene 0.32.0`. Supporting files: `selene.toml` and
`roblox.yml` (the selene Roblox std, generated by `selene generate-roblox-std`). The official Luau compiler,
`luau-compile` from luau-lang/luau, was used from a scratch directory and is **not** part of the repo.

**Checks run after every batch, plus once over the whole tree at the end:**

1. **Formatting:** `stylua --verify` (it refuses any output whose AST differs from the input), then
   `stylua --check src`.
2. **Compile check:** `luau-compile` on every file, which also enforces the 200-local and 255-upvalue limits.
   All 189 files compile.
3. **Bytecode fingerprint:** `luau-compile --text -g0` (no debug info) was compared against the formatted original.
   - Local names and comments do not reach `-g0` bytecode. So when the output is identical (`SAME`), the
     behaviour is proven identical.
   - **177 files are SAME.**
4. **Constant check** for the 12 CHANGED files: the set of bytecode constants (strings, numbers, global and field
   names) must be unchanged. All 12 pass.
   - This check caught one real mistake during the work: a rename had turned the string `"/s"` into `"/sort"`.
     It was fixed before commit.
5. **Extraction checks** for CHANGED files:
   - no helper assigns to its own parameters (writes that a caller would lose);
   - `SETUPVAL`/`SETGLOBAL` counts are unchanged;
   - for MenuLogic, GameHUD, CinematicHatch, HatchFXClient and TrailerCinematic, every function that was not
     touched is op-for-op identical to the renames-only version;
   - for InventoryView, inlining the helpers back reproduces the original bytecode exactly.
   - The coordinator also reviewed each CHANGED diff by hand.
6. **selene per file:** no file may gain warnings compared with its baseline. There are no regressions anywhere.
7. **Rojo mapping:**
   - `rojo build` must succeed;
   - the instance tree must equal the pre-refactor build, compared on path, class and every property except
     `Source`;
   - result: 1004 instances, **0 differences** after every batch.
   - `default.project.json` was not modified.

**Remaining selene findings** (161 warnings and 11 errors, all pre-existing, none suppressed by configuration):

| Finding | Count | Why it stays |
|---|---:|---|
| `roblox_manual_fromscale_or_fromoffset` | 83 | Style only. Fixing it changes bytecode and constants. |
| `deprecated` | 44 | Mostly the `Instance.new(class, parent)` parent argument and `:connect`. Changing them would reorder parenting or Name assignment. |
| `global_usage` | 29 | Intentional `_G` contracts between the trailer and menu scripts. |
| `if_same_then_else` (error) | 6 | Pre-existing identical branches, documented in place. Merging them changes bytecode. |
| `incorrect_standard_library_use` (error) | 4 | selene false positives: `Vector3.yAxis:Cross`, `CFrame.identity:Lerp`, `game.JobId:sub`. |
| `undefined_variable` (error) | 1 | `heartbeatConnection` in HatchLiquidVisuals: a pre-existing read of a nil global. Harmless, annotated. |
| `unused_variable`, `empty_if`, `empty_loop`, `manual_table_clone` | 5 | Upstream Animate globals, a retired branch, and a side-effect loop. |

## 12. Remaining issues and risks (found, **not** fixed)

Fixing any of these changes behaviour, so each needs a deliberate decision. Code comments mark most of them at the
relevant line. The full list, per batch, is in the appendix.

### 12.1 Highest priority (security, data, money)

| Area | Issue | Where |
|---|---|---|
| **Security** | `IsStaffServer` is taken from client-controlled TeleportData. Anyone can turn a public server staff-only, so every non-staff player gets kicked. | `server/Admin/StaffServerService.luau` (also in PROJECT_AUDIT) |
| **Security (new)** | `guardPlayer` skips any player whose TeleportData has `SoftShutdown == true`, which is also client-controlled. A non-staff player can use it to get into a real staff server. | `server/Admin/StaffServerService.luau` |
| **Security** | Cross-server table messages from any server in the universe are trusted, and can trigger an update rejoin. Open Cloud text goes into RichText banners without escaping. | `server/Services/CrossServerService.luau`, `client/Admin/StaffAnnouncements.client.luau` |
| **Item duplication** | Saved tools are given before the plot wait. A failed restore then saves cash but keeps the old tools and placements, so sell + rejoin duplicates items. | `server/PlayerData/PlayerDataService.server.luau` (PROJECT_AUDIT) |
| **Item duplication (latent)** | With `VictimLeaves = "Continue"`, both the victim and the thief keep the egg. The steal system is currently disabled. | `server/Eggs/EggSteal/EggStealService.luau` |
| **Robux** | GameMenu `Buy` prompts products and passes from `GameMenu Config.Shop`. The only ProcessReceipt (ShopService) grants only `ShopConfig.Products`, so a GameMenu-only product is charged and never granted. | `server/Services/GameMenu/GameMenuServer.server.luau` and `server/Shops/ShopService.server.luau` |
| **Robux** | `ownsPass` caches `false` when `UserOwnsGamePassAsync` errors, so a paying VIP or StarterPack owner loses the perk for the whole session. | `server/Shops/ShopService.server.luau` |
| **Exploit** | `GoHome` has cooldown 0 and doesn't check a carried river egg, so a carried egg is secured instantly. | `server/Plots/HomeAndBubbles.server.luau`, `server/Eggs/RiverEggCarryService.luau` (PROJECT_AUDIT) |
| **Spam** | `CollectRiverEgg` has no per-player rate limit, and every failed attempt builds and destroys a full Tool. FeedbackService's cooldown is stamped only after a yield, so a burst of invokes can post to Discord several times. | `server/Eggs/PirateEggFreeConveyor.server.luau`, `server/Services/FeedbackService.server.luau` |
| **Session lock** | If a player leaves right after load, the DataStore lock is never released. The 8th load attempt overrides even a fresh foreign lock. | `server/PlayerData/PlayerDataService.server.luau` |
| **Stuck state** | In GameHUD, any error after `selling = true` blocks selling for the rest of the session, and `SellEgg` can be nil (it is waited for with a 10 s timeout). `BrainrotPlacement`'s assert runs after the slot is claimed, so a missing podium surface leaves the slot Occupied forever. | `client/UI/Controllers/GameHUD.client.luau`, `server/Characters/BrainrotPlacement.server.luau` |
| **Temple upgrade** | The old temple is renamed `Temple_Retiring` and is only renamed back when the upgrade fails. | `server/Plots/PlotManager.server.luau` (PROJECT_AUDIT) |

### 12.2 Other known issues (selection)

- **Connection leaks:**
  - StudPanel: the `ViewportSize` connection is never disconnected, and the panel is rebuilt on every role change.
  - TrailerCinematic: a CharacterAdded connection inside PlayerAdded survives cleanup.
  - StolenEggBanner: a RenderStepped connection is overwritten when Show is called again.
  - GoldFXServer: `watchedModels` is strong-keyed.
- **Loops that can die:**
  - MutationDropService errors for good if `NextMutationDropAt` is cleared.
  - GoldFXClient indexes `ShineShells` without waiting for it.
  - TrailerDuoV3 errors every frame if an avatar fails to load.
- **Values copied by hand between scripts**, which can drift apart:
  - night-cycle constants in NighttimeService, NighttimeHUD and NighttimeSky;
  - the offline rate and cap in LeaveEarningsOverlay;
  - the bat cooldown in BatMotionClient;
  - the owner UserIds, hard-coded in about 15 scripts even though `AdminRoles` exists.
- **Dead code**, kept and marked with a `_` prefix:
  - the retired inventory panel in InventoryClient;
  - the legacy OwnerPanel modules (ActivityLog, Components, ConfirmDialog, PlayerRow, Theme, Toast);
  - the old GameHUD bag;
  - unused Config keys in LoadingScreen and FloatingCharacters;
  - UpgradeEffects and MoneyStandBuilder, which no active script requires.
- **Parked content:** `Storage/FutureUpdateContent/RiverBeforeGoldContentReservation` is **not** Disabled in
  `default.project.json`. Moving it into ServerScriptService would run it alongside the live PirateEggFreeConveyor,
  using the same remote.

### 12.3 Recommendations (not done)

1. Fix the items in 12.1, starting with StaffServerService and the GameMenu/ShopService receipt gap. Each fix needs
   play-testing.
2. Add shared modules for logic that is copied today:
   - a UI-primitives module: `create`/`make`, `tween`, corner/stroke/gradient, the studded plate (about 10 UI
     scripts);
   - one money/number formatter (several near-identical variants exist);
   - one place for rarity and mutation colours;
   - a `NightConfig`;
   - `PlayerDataConfig` (store name, key and lock timeout are copied in PlayerDataService and SaveRestore);
   - a `findPlotByOwner` / `getCashStat` server util;
   - a Cinematics util shared by TrailerCinematic and TrailerDuoV2/V3.
3. Replace the hard-coded owner UserIds with `AdminRoles` lookups.
4. After play-testing, delete the dead code that is now marked with `_` prefixes.
5. Optionally switch `UDim2.new(x, 0, y, 0)` to `UDim2.fromScale` and drop the deprecated `Instance.new` parent
   argument. Both are low risk, but they change bytecode, so each should be verified in Studio.

## How to reproduce the verification

1. `rokit install`.
2. `stylua --check src` and `selene src`.
3. `rojo build -o check.rbxlx`.
4. For the bytecode-identity check, download `luau-compile` (luau-lang/luau releases). Then compare
   `luau-compile --text -g0 <file>` output between `git show 9b0615e:<file>` and the working tree. Identical output
   means the change touched only names, comments or formatting.

---

## Appendix — per-batch findings

These notes were written by each batch's reviewer. They give the full detail behind section 12. Line references
may have shifted since.

References to `scratch/...` files point to temporary working copies used during the refactor; they are not part of the repository.

### Batch 01 — Shared config, catalogs, utilities
Known issues (not fixed):
- TempleAppearanceThemes.Apply: tinted themes multiply the current colour (re-applying compounds); "Original" returns early and doesn't restore colours; HalloweenDecor destroy is permanent.
- HatchFXConfig: Config.T appears unused (Timeline hard-codes its numbers); LegacyShort has no callers in src.
- Dead data kept for bytecode identity: GameMenu Config `_LEGACY_UNITS`, LeaderboardFormat `_UNITS`, GoldCharacterFX unused SurfaceAppearance lookup, EggHatchTiming unused CharacterEconomy require.
- GoldCharacterFX.remove applies RichGoldFinish first (likely intentional refresh; name misleading).
Cross-file duplication candidates:
- 3-digit comma grouping in CharacterCatalog.FormatPrice, GameMenu Config.Full, InventoryFormat.Exact, LeaderboardFormat.Commas (differ in rounding/format/prefix → not identical).
- Number shortening: CharacterEconomy.Format and HatchFXConfig.LegacyShort have own logic (others delegate to InventoryFormat.Short).
- Rarity colour tables: CharacterCatalog == InventoryConfig.Theme.Rarity; HatchFXConfig.RarityColor == PortalConfig.RarityColor; EggStealConfig.RarityColors differs.
- CharacterCatalog.Label / CharacterEconomy.Label similar billboard builders.
- server/World/Portal/PortalBuilder.luau byte-identical to shared copy apart from header line.
Selene left: InventoryConfig deprecated Enum.KeyCode.Unknown (config value).

### Batch 02 — Shared: UI modules
All 6 files bytecode SAME (renames, comments, formatting only). No functions extracted, no duplicates consolidated, no splits.
Public names, signatures and returned table keys unchanged (Style.Card still returns root/card/name/badge/strip/mut/power/pgrad/income/spark/sparkScale; StolenEggBanner `ui` keys vp/sub/dist kept).

Known issues (not fixed):
- StolenEggBanner.build: `workspace.CurrentCamera:GetPropertyChangedSignal(...)` is unguarded (fit() guards a nil camera, the connect does not) and bound to the build-time camera only.
- StolenEggBanner.Show while already "Stolen" with new egg data: clearPreview() + showPreview(token) reuses the same token, so an earlier preview task still polling can also finish -> duplicate model in the viewport and the previous spinConnection is overwritten without Disconnect (RenderStepped leak).
- StolenEggBanner: subtitle (`ui.sub`) is created Visible=false and never shown, so the egg name/rarity/price line is never visible (maybe intentional). Preview-name match has no break (last match wins). COPY text and PLATE are dead data.
- EggLabel: Config.PlaytestFree, PriceTooMuch, CurrencyStats, `_playerMoney`, `_stroke`, `EggLabel:_setActive` unused. Attach returns nil (not the label) for eggs without RiverEggVisual.
- UISound: `_cashSuppressedUntil` dead; SuppressCashFeedback is a no-op, IsCashFeedbackSuppressed always false.
- FirstHatchGuide.Resolve returns 13 when completed while Steps has 12 entries (callers must treat 13 as "done").
- Style: `_outlined` dead helper; the "d: { w, ..., powLabel, gap }" comment describes an older layout.

Cross-file duplication candidates:
- make(class, props, parent) + tween(...) re-implemented in StolenEggBanner, EggLabel and Style.make (Style.make parents only when parent is truthy; tween default easing Quart vs Quad).
- Number shortening: Style.Short, EggLabel.FormatPrice ($/FREE, max B), StolenEggBanner.short (1 decimal, max T) - similar, not identical.
- Plate gradient colours: Style.Plate == EggLabel plateColorsByRarity (minus Secret); stud image 132561191216691 in both.
- Phone heuristic duplicated inside StolenEggBanner (fit() vs isPhone()); not merged (bytecode would change).

Selene left: Style.luau 3x roblox_manual_fromscale_or_fromoffset (pre-existing; fixing changes bytecode). All unused_variable warnings fixed via `_` prefix.

### Batch 03 — Player data
All 5 files bytecode SAME (renames, comments, formatting only). No functions extracted, no duplicates consolidated, no splits. Save/load paths, DataStore name/key, schema field names, retries (save 3, load 8), waits, lock logic, BindToClose/PlayerRemoving untouched.

Main deliverable: PlayerDataService header now documents the saved schema (v, savedAt, lock, restoredAt, cash, tools, placed, unlocked, chambers, templeLevel, tutorial*, settings, discovered, quests; tool record {k,n,a,inc{c,left}}), the load/save flow, triggers and failure handling. Header comment "autosave every 90 s" corrected to the real value (AUTOSAVE_INTERVAL = 30).

Known issues (not fixed):
- PlayerDataService.applySavedState: saved tools go into the backpack before the plot wait; with no plot / restore error restoreState.all stays false, so snapshot saves cash but keeps old tools/placed -> sell + rejoin duplication (= PROJECT_AUDIT High "PlayerData restore dup"; comment added at the spot).
- PlayerDataService.onJoin: if the player leaves after loadData succeeded (lock taken) but before `if not player.Parent`, the lock is never released; a quick rejoin elsewhere waits until attempt 8 steals it (~30+ s).
- loadData: on attempt 8 a fresh foreign lock is overridden (by design, but two live servers could then both write).
- saveData returns nil (not false) after 3 failed attempts; PlayerDataSaveNow only treats `== true` as success, so harmless.
- snapshot: `chambers` is compacted (nil indices skipped), so a missing chamber 2 shifts chamber 3's level into slot 2.
- standCash is only banked on final snapshots; autosaves ignore uncollected stand cash (intentional?).
- Shutdown: BindToClose and PlayerRemoving(onLeave) can both save the same player concurrently (both release the lock; benign double write).
- Non-Studio with GetDataStore failing -> "nostore" path shows "Session only (Studio)" and plays without saving.
- Saved `settings` are re-applied as attributes on join without re-validation (trusted, server-written).
- SaveRestore.Restore: UpdateAsync is not pcall'd (error bubbles to OwnerPanelServer as message - fine); summarize() omits `slots` for unreadable saves.
- KeepItemsOnRespawn: LoadCharacterAsync respawn without Died loses the backpack (= PROJECT_AUDIT Medium).
- NoEarnAccounts: SoftShutdown join path never sets TutorialDataReady, so the guard waits the full 90 s before starting (harmless). Owner UserId hard-coded.
- Leaks: none found (per-player tables cleared in onLeave; Died/CharacterRemoving connections die with character/player; deadBackpacks is weak-keyed).

Cross-file duplication candidates:
- "PlayerData_v1", key "u"..UserId and lock timeout 150 duplicated in PlayerDataService and SaveRestore (could share a PlayerDataConfig).
- plotOf / cashOf helpers (owner plot by OwnerUserId, leaderstats.Cash) likely re-implemented across server scripts.
- "wait for TutorialDataReady/DataLoaded" polling loops in NoEarnAccounts, QuestService.Persistence.Load and others.

Selene: PlayerDataService 3 -> 0 (shadowing fixed by renames); others 0. KeepItemsOnRespawn.shouldKeep is formatted a bit awkwardly by StyLua (kept; restructuring would change bytecode).

### Batch 04 — Egg: server and carry
All 11 files bytecode SAME. Every server file now has a network-authority header (what is validated vs trusted, remotes/payloads).
Known issues (not fixed):
- EggStealService (PROJECT_AUDIT High, latent): VictimLeaves="Continue" duplicates the egg (victim keeps it + thief secures clone). System currently disabled.
- EggStealService: chamberUntil never cleared for destroyed chambers; cooldownUntil only on PlayerRemoving (small leak).
- RiverEggCarryService (PROJECT_AUDIT High): GoHome ignores RiverEggCarryId → carried river egg secured instantly. Record field `visual` never set (dead branch). Secure box hard-coded, separate from EggStealConfig BaseMin/BaseMax.
- PirateEggFreeConveyor: CollectRiverEgg has no per-player rate limit; failed charges still build+destroy a full Tool (spam/CPU vector). Redundant `if entry` check, duplicate prompt lookup, unparented preview clone.
- EggSellService: header says limited/golden/owner eggs can't be sold, code sells them for $0; sold eggs not removed from StarterGear by EggId (suspected).
- ConveyorEggs: unused StarterGear dependency; legacy EggCatalog roll; inactive without workspace.EggConveyor.
- TwoHandItemCarryService: every GoldVariant shows "Golden Pirate" model; mutated presentation cloned twice (wasted work); deprecated Instance.new(class, parent).
Cross-file duplication candidates: OwnerUserId plot lookup; leaderstats.Cash lookup; strip-non-visual descendants filter; egg Tool construction (ConveyorEggs vs PirateEggFreeConveyor); mutation tiers/colours in 3 places; CharacterCatalog rarity pcall block twice in TwoHandItemCarryService.
Selene: batch 11 -> 1 (deprecated Instance.new parent arg kept — changing it alters parenting order).

### Batch 05 — Egg: client

- Functions extracted: none. Every file is SAME, so no CHANGED justifications are needed. EggStealClient's long functions (buildCard is declarative UI; updateGuide; step) read fine with section comments, and extracting them would have made the bytecode CHANGED for little gain.
- Duplicates consolidated: none.
- Dead code renamed with a `_` prefix and kept, not deleted (EggStealClient): `_shake`, `_goldBurst`, `_startThiefAlarm`, `_toCarryState`, `_flyToBackpack`, and the unused parameters `_steal` (flyToBackpack) and `_info` (securedThief). They are leftovers from the old thief card UI, which StolenEggBanner replaced. Safe to delete in a later cleanup.
- Known issue (not fixed), EggStealClient: since the thief has no card, `buildCard`'s thief branches are unreachable: "EGG STOLEN!" / "RETURN TO YOUR BASE" texts, the value label (`UI.ShowValue`), and the `isThief` colours. `formatWithCommas` is only reached through that thief branch, so it is effectively dead too. The thief steal record's `card = { destroyed = true }` dummy works only because `step` checks `card.destroyed` first.
- Known issue (not fixed), EggStealClient: `entrance()` defaults its flash colour to `COLORS.Alert` and titles it "EGG STOLEN!", but it is only ever called for the victim, with `COLORS.Victim`. `danger.target` is never set above 0 anywhere, so the vignette pulse code never shows.
- Known issue (not fixed), EggStealClient: `cancelledReasons` is a table literal rebuilt on every thief "End" message. This is harmless; hoisting it would change the bytecode.
- Leak (minor, not fixed), EggStealClient: `watchPrompt` connects 3 signals per prompt and never disconnects them. They are released only when the prompt is destroyed. `GetInstanceAddedSignal` can also fire again for a re-tagged prompt, which would double the connections. The behaviour is idempotent, so the only cost is the extra connections.
- Known issue (not fixed), EggPickupFeedback: `ReplicatedStorage.EggVisuals` is indexed directly, so the handler throws if the folder is missing; other scripts use FindFirstChild. The RenderStepped flight connection is disconnected only when the flight completes or the root is gone. If `root` stays parented but the character is replaced, the connection still finishes after 0.65 s, so there is no leak.
- Known issue (not fixed), RiverEggCarryClient: a "Stolen" event with a nil `data` would error (`data.id`). The server always sends a table.
- Known issue (not fixed), StolenEggCarryPose: `scanCharacter` calls FindFirstChild for UpperArm/LowerArm/Hand and never uses the results (now `_upperArm` etc., kept so the bytecode stays SAME). It runs for every character, every frame, whenever the carry is active. The rescan of incomplete rigs (`#arms < 2`) also runs every 0.5 s for R6 rigs forever.
- Cross-file duplication candidates: the `create`/`tween`/`isReducedMotion` helpers in EggStealClient and StolenEggBanner; the attribute-based "recover carry" pattern in EggStealClient.recoverCarry and RiverEggCarryClient; quadratic Bezier flights in EggPickupFeedback and EggStealClient._flyToBackpack; and `makePanel` in EggStealClient, which duplicates the look of `EggUIStyle.Panel`.
- Selene: 10 warnings to 0 across the batch, with no regressions.

### Batch 06 — Hatching: server and incubators

- Functions extracted: HatchVideoService: `destroyHatchedReward` (merges the two identical closures). No others; HatchGoo's long `runCycle` got phase section comments instead (extracting from inside its xpcall body would change upvalues/early returns).
- Duplicates consolidated: HatchVideoService backpack/character ChildAdded handlers -> `destroyHatchedReward`.
- CHANGED justification, HatchVideoService: the bytecode diff shows only the two `DUPCLOSURE` handlers (both capture nothing) replaced by one module-level closure passed via an upvalue; same checks, same `task.defer` destroy, same connection order and lazy `bag and ...` / `player.Character and ...` guards. Everything else is SAME (only register/constant renumbering).
- Template vs DevWorkshop HatchGoo (not merged): the DevWorkshop copy is a Disabled, older version. It lacks the UnderConstruction wait, IncubatorController glass (it tweens `LoadingDoor` instead), CharacterEconomy roll/apply/label, EggHatchTiming durations (uses the tool's HatchSeconds or 10, clamp 1..3600 vs 1..86400), night/player hatch-speed multiplier loop, the countdown billboard, mutations and gold variant, EggSteal (StealLock/EggStolen/IncubatorChamber), HatchFXServer busy check and HatchFX.Play reveal, HatchCameraGate, resume (`ResumeEgg` bindable and resumeTool/resumeLeft), auto-equip on collect, and the power/income texts. It has its own scripted 6 s reveal (CrackStage, CinematicEggHatch tag, "Start"/"Reveal" cue). Its chamber pivot is shifted by (-22.75, -26, -92), with matching offsets elsewhere, and it uses different character scaling (fit box vs 6 studs tall).
- Known issue (not fixed), HatchGoo template: `collect` sets `collected = true` / `pickup.Enabled = false` twice. The `loadingDoor` part is only read for `_doorRest`, which is unused. `_bottom` is unused. The "  •  2×" suffix shows for any speed > 1, not the real multiplier. `player.Character.Humanoid:UnequipTools()` throws without a Humanoid; xpcall recovers, and the cycle then returns the egg.
- Known issue (not fixed), HatchGoo template: after the reveal, `glassController:Open(0.65)` is spawned and `Open(0.45)` is called later. `self.open` only flips after a slide finishes, so if the first slide is still running, both tween the same doors at once. The end position is the same, so the effect is cosmetic at most.
- Known issue (not fixed), HatchFXServer: `getController` calls `IncubatorController.new(incubator)` on a model that HatchGoo already wrapped. That would add a second IncubatorFX part, light and Heartbeat pulse. It is never reached from HatchGoo, which passes no-op `closeGlass`/`openGlass`, but any other caller without those hooks triggers it.
- Known issue (not fixed), IncubatorController: the door closed-pivots are captured in `new()`. If the model is moved afterwards, the doors snap back to the old place, which is why HatchGoo waits out `UnderConstruction`. `Destroy()` only disconnects the pulse; the IncubatorFX part and lights stay. `Hatch()`/`Shake()`/`PlaceEgg()` are not used by the live game.
- Known issue (not fixed), HatchVideoService: an early return in `run` (no Chamber1, no HumanoidRootPart) leaves `running[player] = true` and sends nothing to the client. A new "Start" is ignored until the client sends "Stop", for example by pressing J again. `ServerStorage.AuxEggTemplates` is indexed directly.
- Leaks: none found beyond the above. HatchFX jobs disconnect `ancestry`, and HatchGoo's pickup connections die with `pickupAnchor`. In HatchVideoClient, the Heartbeat connection is tracked in `connections` and cleared on stop.
- Cross-file duplication candidates: the owner id list `{168774222, 353101613}` in HatchVideoService.OWNERS and HatchVideoClient. The template and DevWorkshop HatchGoo are near-duplicates by design. The "anchor + no collide/touch/query" part loops repeat across HatchGoo, HatchFXServer.lock and IncubatorController.
- Selene: 6 warnings to 0 across the batch (unused locals prefixed `_`), with no regressions.

### Batch 07 — Hatching: client

- Functions extracted:
  - CinematicHatch: `createCoreEffects` (from `prepare`'s build thread), plus `showRecord`, `animateHatching`, `animateRelease` and `updateOwnerCamera` (from the `BindToRenderStep` callback).
  - HatchFXClient: `rockEgg`, `updateCracks`, `updateShards` and `updateCharacter` (from `step`), plus `createEggEffects` and `collectMachineGlow` (from `begin`).
- Duplicates consolidated: none.
- Why CinematicHatch (CHANGED) behaves the same:
  - Each helper is a block moved verbatim, and the call sits exactly where the block was. Each call keeps its original guard: `if not record.shown`, the released/not-released if/else, and the owner-camera tail.
  - The blocks contain no `break` or `continue`. The only `return`s are in `updateOwnerCamera`, which was the tail of the callback, so returning from the helper is the same as returning from the callback.
  - Values that were upvalues or locals are now passed as parameters, all read-only: record, folder, home, timelineTime, sinceEpoch, half, dt, cam. `session` stays a shared upvalue.
  - The normalized bytecode diff of each helper against its old window shows only call-feedback slot numbers, GETUPVAL→register for the new parameters, and JUMP→RETURN at function ends. All other functions are identical.
- Why HatchFXClient (CHANGED) behaves the same:
  - The same approach applies. `step` keeps its order: early cleanup/return → `reduced()` read → rock (same guard) → inward-off → glow/light → cracks → doBreak → shards (`if job.shards`, checked after doBreak as before) → character (`job.char` read at the same point).
  - In `begin`, `createEggEffects` covers holder → light → burst → stars → inward → `holder.Size`, in the same instance creation and parenting order. `collectMachineGlow` follows immediately after it.
  - The normalized bytecode diff is clean as above. Functions 0–27 and all closures after `begin` are identical.
- Known issue (not fixed), HatchLiquidVisuals: `heartbeatConnection` (Destroying handler, formerly line ~107, now ~199) is never declared. It is a read of an undefined global, which is always nil because a script's environment does not share globals. It looks left over from a removed Heartbeat loop. Effect: the table literal is `{nil, pulse, status, venting}`. Generic iteration skips the nil slot, and the `if connection` guard covers it too, so the other three still disconnect. Harmless; kept as-is and annotated in code.
- Known issue (not fixed), HatchLiquidVisuals:
  - The 16 `ChamberMist*` emitters and the `GasInlet` emitter are created with `Rate = 0`. Nothing in the repo ever Emits them or raises their Rate, so they never show (only `TeleportPuff` emits).
  - `_chamberMistLayers` is never read.
  - The `else` branch check `state ~= "Incubating"` is redundant.
  - `RunService` is unused (now `_RunService`).
- Known issue (not fixed), CinematicHatch:
  - `record.hum` is never assigned, so the destroy in `cleanup` is dead code.
  - `buildFracture`'s returned `size` is unused.
  - `Debris` is unused (now `_Debris`).
  - The owner-camera shake takes the shake of the last record whose `home` matches, which depends on iteration order.
  - `workspace.CurrentCamera` is assumed non-nil in `begin` and the render step.
  - `hideAvatars` walks every descendant of nearby characters every frame (performance).
  - The header comment "Sounds are not set yet" was stale. The crack and release hooks already call UISound, so a clarifying line was added.
- Known issue (not fixed), HatchFXClient:
  - On cleanup, prepared crack stages reset only Decals. Prepared BasePart stages keep the LocalTransparencyModifier they had (0 if revealed) when a hatch is cancelled before the break.
  - The header comment of `preparedCracks` mentions SurfaceGuis, but only Decal and BasePart stages are handled.
  - `job.inc` is never read.
  - `job.far` is nil, not false, when there is no camera (it is treated the same way).
- Leaks (suspected, not changed):
  - CinematicHatch `meshSources` caches the source EditableMesh per MeshId for the whole session and never destroys it. It is bounded by the number of unique egg meshes.
  - HatchFXClient `seenTokens` grows by one entry per hatch, forever.
  - HatchFXClient `Client.Start`'s per-incubator `HatchToken` connection is never disconnected. It dies with the instance, and `watchedIncubators` is weak.
- Cross-file duplication candidates:
  - The `smooth` smoothstep helper (CinematicHatch, HatchFXClient).
  - The "anchored, no collide/touch/query part" setup (CinematicHatch `newPart`, HatchFXClient `fxPart`, HatchLiquidVisuals holder/flash).
  - The smoke/sparkle texture asset strings.
- Selene: CinematicHatch went from 1 to 0 warnings (`_Debris`) and HatchLiquidVisuals from 3 to 1 (`_RunService`, `_chamberMistLayers`). The remaining `undefined_variable heartbeatConnection` is pre-existing and intentionally untouched. No regressions.

### Batch 08 — Characters

- Functions extracted: none. All 10 files are bytecode SAME at -g0. Only renames, comments, and new number/string constants, which Luau folds (checked to compile identically).
- Duplicates consolidated: none. `KINDS.*.d` in CharacterInfoClient has three identical layout tables. I kept them separate because Style.Card receives each one, and sharing a single table could change aliasing.
- CHANGED files: none.
- Known issue (not fixed), BrainrotPlacement:
  - `assert(support, "Missing podium surface…")` runs after the slot is already claimed (`Occupied = true`, `PlacementToken` set). If the podium surface is missing, the slot stays Occupied forever, the cloned display is leaked unparented and the Tool is kept. Re-placing on that slot is then impossible until the server restarts.
  - `_previousActionText` is read but never used to restore the prompt. `SlotUnlocks.Refresh` restores it after 1.5 s.
  - `_cash` (the leaderstats Cash lookup in the income loop) is unused.
  - `_Catalog` is required but unused. The require is kept in case it has side effects.
  - The script mixes `game.ServerStorage` / `game.CollectionService` direct indexing with GetService.
  - `game.ServerStorage.FutureUpdateContent.Characters` is indexed directly for golden tools. It errors if that content is missing. EggCharacterRewards.Resolve does the same.
- Known issue (not fixed), InventoryService:
  - `Actions.PickUp` compares `item.data.itemId`, which never exists (the field is `id`). The branch is dead and the `data.id` comparison covers it.
  - In PickUp, `payload.slot` / `payload.id` are not type- or length-checked. They are only used in equality comparisons, so this is harmless.
  - `watchPlot` hooks AttributeChanged only on slots that exist when it runs. Slots added later never mark the owner dirty.
  - `snapshot.multiplier` uses `tonumber()` on OwnerIncomeMultiplier but not on NightCashMultiplier. BrainrotPlacement uses neither.
- Known issue (not fixed), EggCharacterRewards: when an explicit mutation string is passed for a Golden template, the mutation is still applied (only the auto-roll is skipped). The first ToolTip assignments are always overwritten when a catalog entry exists.
- Known issue (not fixed), FloatingCharacters:
  - The old header described a bob, a breathe and a 6.6 s eased showcase spin with a lift. The code only holds the character at FloatHeight and turns it continuously (one turn per 10 s). I rewrote the header to match the code.
  - Config fields Bob / Cycle / SpinStart / SpinTime / SpinLift / SwayYaw / SwayTilt are unused, as is `_easeInOutCubic` (formerly `easeIO`).
  - `seed` is always 0, and `state.ground` is never read.
- Known issue (not fixed), HatchedCharacterDisplay: on tag removal, the RewardAura Highlight and the Torso PointLight stay on the model, and the model is not reset to RewardHome. Harmless if the model is destroyed.
- Known issue (not fixed), GoldenLuffyIdle: it listens to `workspace.DescendantAdded` and defers `add` for every Model in the game (performance).
- Leaks (suspected, not changed):
  - CharacterInfoClient: `watchCharacter`'s ChildAdded/ChildRemoved connections and `watchPlayer`'s CharacterAdded connection are never disconnected. They die with the instances.
  - InventoryService: `watchPlot` connections live for the plot's lifetime. `hookedEvents` is weak-keyed.
  - CharacterAnimator / FloatingCharacters: the RenderStepped connections are never disconnected (script lifetime).
- Cross-file duplication candidates:
  - Golden-template lookup (`ServerStorage.FutureUpdateContent.Characters["Golden Pirate"]`) in BrainrotPlacement, EggCharacterRewards and InventoryService.goldenTemplate.
  - Scale-to-6-studs (`ScaleTo(GetScale() * 6 / math.max(size.Y, 0.01))`) in BrainrotPlacement and EggCharacterRewards.
  - BasePart-count loop in BrainrotPlacement (DisplayPartCount), FloatingCharacters.add and CharacterInfoClient.geometryReady.
  - Free-slot sequence (Occupied=false, PlacementToken=nil, stand IncomePerSecond=0, SlotUnlocks.Refresh) in InventoryService storeDisplay, InventoryService Actions.Sell and the end of BrainrotPlacement's income loop.
  - Income multiplier product (OwnerIncomeMultiplier × NightCashMultiplier) in BrainrotPlacement and InventoryService.snapshot.
- Selene warnings left:
  - BrainrotPlacement: 2× `deprecated` for `Instance.new(class, parent)`. Changing it would alter the parent-before-Name order, so it is kept and documented.
  - CharacterInfoClient: 1× `roblox_manual_fromscale_or_fromoffset` (`UDim2.new` → fromScale). Changing it would change the bytecode, so it is kept.
  - The other selene counts went down: BrainrotPlacement 7→2, FloatingCharacters 1→0.

### Batch 09 — Characters: inventory client

**Functions extracted**
- InventoryView.luau: `buildNote(self, gridWell, compact)` (placeholder note + first-visit steps, from `View:_build`), `buildSkeletonCards(skeleton, metrics)` (from `View:_showNote`), `clearPips(pips)` (from `View:Render`). All are file-local functions, so the View table shape is unchanged.

**Duplicates consolidated**
- InventoryView.luau: the two identical "destroy every Frame child of self.pips" loops in `Render` now call `clearPips`.

**Why the CHANGED file behaves the same**
- InventoryView.luau: I inlined the three helpers back into the new source mechanically (helper body at the call site, `skeleton` -> `self.skeleton`, `pips` -> `self.pips`, `local metrics = self.M`), compiled it with `-g0` and compared it to HEAD: byte-identical. So the only differences are the three call boundaries. Each helper writes only `self.*` fields and instances (no enclosing locals), has no early return, and is called at the exact spot of the original block, so instance creation, parenting and `_connect` order are unchanged. The rename pass briefly turned the string `"/s"` into `"/sort"`; the inline check caught it and it is fixed.

**Known issues (not fixed)**
- InventoryClient: the whole panel UI is retired. `Client.Open` starts with `if true then return end`, so the rest of its body is unreachable. `_buildHud` is never called, the toggle key is not bound, the "Reveal" event branch is empty, and `HatchReveal.new` builds an object that never gets `:Push`. `Start` still creates the CharacterInventory and CharacterReveal ScreenGuis, fetches the snapshot forever with backoff, and runs a `while true do task.wait(30)` loop. All of this is dead weight but harmless.
- InventoryView: `SHORT_RARITY_LABELS` (was `SHORT`) has no entry for "Limited". In the Wide/Dense layout that button gets a nil label, `Style.Button` then skips `Text`, and the button would show Roblox's default "Button". It is only visible if the panel is revived.
- InventoryView `Render`: the sort label lookup assumes every `sortButtons` id exists in `Config.Sorts`. This holds today; otherwise `label .. …` would error.
- Leaks: none found that matter. Card, button and stud-band connections sit on instances that are destroyed with `root`. Humanoid `Died` connections die with the humanoid. `View.connections` is disconnected in `Destroy`.

**Cross-file duplication candidates**
- `reducedMotion()` (the `LocalPlayer` "ReducedMotion" attribute check) appears in both InventoryClient and HatchReveal.
- The compact-screen test against `Config.Layout.CompactBelowWidth/Height` is in HatchReveal `compactScreen` and InventoryClient `chooseLayout`, and they read different viewport sources.
- The `for key, value in props or {} do inst[key] = value end` overlay appears in Style (Shell/Inset/Chip/Button) and View `newViewport`. It could become a `Style.Apply` helper, but that would change the bytecode.

**Selene warnings left**
- InventoryView: 12 x `roblox_manual_fromscale_or_fromoffset`, all pre-existing. Switching to `UDim2.fromScale` changes the bytecode, so I left them.
- InventoryClient: 1 x `empty_if` (the "Reveal" branch was emptied when the reveal was retired). I kept it so the conditions are still evaluated exactly as before. I fixed the pre-existing `unused_variable` for `buildHud` and `reveal` by renaming them `_buildHud` and `_reveal`.

### Batch 10 — Plots, temples and portals

**Functions extracted**
- None. All but one file are bytecode-SAME: renames, comments, constants, formatting only.

**Duplicates consolidated**
- HomeAndBubbles: `refresh(plot)` had an inline copy of `clearBubble(plot)`. It now calls `clearBubble`.

**CHANGED files (why behaviour is identical)**
- `src/server/Plots/HomeAndBubbles.server.luau`: the inline block in `refresh` was the same code as `clearBubble`: same FindFirstChild "OwnerBubble", ObjectValue check, Value:Destroy and ref:Destroy, no yields, no return values. It is replaced by one call to `clearBubble`, which is declared above it. The bytecode diff only shows that block becoming a GETUPVAL+CALL. strcheck OK.

**PortalBuilder sync**
- `src/server/World/Portal/PortalBuilder.luau` now matches `src/shared/World/Portal/PortalBuilder.luau` except for two lines: line 1 (header) and line 7, where the "Near-copy of ..." note now points to the shared file instead of to itself. Bytecode SAME. The two files were not merged.

**Known issues (not fixed)**
- HomeAndBubbles `GoHome`: `COOLDOWN = 0`, and only `CarryingStolenEggId` blocks the teleport. A carried river egg or a ragdolled player can still go home (audit: High). A comment now points to this.
- PlotManager `build` (animated path): the old temple is renamed `Temple_Retiring` and only renamed back if the build fails (audit: High). A comment now points to this.
- PlotManager reads `AppearanceBuilding`, but no script in `src` sets it (the appearance system is archived), so that check is dead.
- PlotManager: `save` does nothing (PlayerDataService does the saving). `refresh` computes `TempleLevel` and never uses it (now `_level`). The `swapInstantly(prepare)` parameter is never passed.
- PlotChambers: any non-nil `adminActor` skips the price charge. Only the distance check compares against the admin UserId. This relies on the BindableEvents being server-only.
- PlotReadyFlag: nothing reads `PlotReady` (LoadingScreen.Config only names it). The script has no `GetPlayers()` loop for players who joined before it ran. It stops polling after 10 s, so a player still queued for a plot never gets the flag.
- HomeAndBubbles: `billboard.MaxDistance` is set to 400 and then to 260. 260 is the value that applies.
- TempleOccupancy: on the root part, `CanQuery` is not cached. It just follows `visible`, unlike descendants, which restore `ClaimQuery`.
- TempleSlotUnlocks: `Setup` connects the OwnerUserId and TempleLevel signals on every call. Calling it twice on one plot would give duplicate handlers (possible leak). Slots above 36 fall back to a price of 250000.
- ConstructionClient: `job.retireModel` is never assigned, so it is always nil in the raycast ignore list. The selene `CFrame.identity:Lerp` error is a pre-existing false positive.
- ConstructionService: the header documents `onComplete(model)`, but it is called with `(model, reason)`. The Heartbeat safety loop runs for the whole server lifetime (cheap).
- UpgradeCameraShake (Disabled): its two BindToRenderStep callbacks would run forever. It uses `game.Players`. `BuildRadius` is read and never used (`_radius`).
- PortalClient: the RenderStepped connection and the per-portal connections are never disconnected (they are freed when the portal is destroyed). There are debug `print`s on every portal build.
- GoldTempleEffects: listens to `workspace.DescendantAdded` for every instance in the game (performance cost, not a bug).

**Cross-file duplication candidates**
- PortalBuilder server/shared copies (kept separate on purpose).
- `feetOrigin(model)` is identical in PortalService and PortalClient.
- The Claim* attribute caching (ClaimTransparency/Collide/Query) appears in both TempleOccupancy.setClaimVisible and TempleSlotUnlocks.Refresh.
- The admin UserId 168774222 is hard-coded in PlotManager, PlotChambers and about 15 other files. AdminRoles exists.
- The `UpgradePrices.Charge(player, UpgradePrices.X[level])` pattern appears in PlotManager and PlotChambers. TempleSlotUnlocks charges `leaderstats.Cash` directly (a second payment path).
- Camera shake exists twice: ConstructionClient `Shake` and the legacy UpgradeCameraShake.
- Clone + TempleAppearanceThemes.Apply appears twice inside PlotManager.build. It was not merged because `clearFootprint` runs at a different point in each path.

**Selene warnings left**
- TempleSlotUnlocks: 3 × `roblox_manual_fromscale_or_fromoffset` (pre-existing). Fixing them would change the bytecode.
- ConstructionClient: 1 `incorrect_standard_library_use` on `CFrame.identity:Lerp` (pre-existing false positive).
- Pre-existing `unused_variable` warnings were fixed with `_` prefixes in PlotManager, PlotChambers, ConstructionClient and UpgradeCameraShake.

### Batch 11 — Economy, shops and game menu server

**Functions extracted**
- None. All 12 files are bytecode-SAME (renames, comments, constant casing, formatting only). Purchase / receipt / cash code was not restructured.

**Duplicates consolidated**
- None (would make economy files CHANGED). In-file candidates left as-is:
  - GameMenuServer: the "find the player's plot" loop is copied in UpgradeTemple / UpgradeIncubator / AddIncubator / UnlockSlot (GameAdapter.getOwnedPlot returns the first match, these loops the last match).
  - GameAdapter: leaderstats.Cash lookup repeated in GetCash / SpendCash / GrantReward; GetOwnedEggs and GetDiscovered share the Backpack+Character tool scan.

**CHANGED files**
- None.

**Known issues / suspected bugs (not fixed)**
- GameMenuServer ACTIONS.Buy prompts Robux products / passes from GameMenu Config.Shop, but the only ProcessReceipt (ShopService) grants only ShopConfig.Products / MoneyLevels ids. A GameMenu productId not also in ShopConfig.Products is charged by Roblox and never granted (receipt stays NotProcessedYet). Same for gamePassId: PromptGamePassPurchaseFinished only grants ShopConfig.GamePasses keys.
- ShopService ProcessReceipt: "if n > 50 then receiptOrder = receiptOrder or {} end" is redundant with the next line (harmless). Receipts saved before receiptOrder existed are never trimmed.
- ShopService ownsPass caches false when UserOwnsGamePassAsync errors, so VIP / StarterPack stay off for the session after one failed call.
- ShopService giveUnknownEgg: the odds roll / pool are dead work whenever CharacterCatalog.ById.Unknown exists (that entry always wins).
- MoneyStandServer: cooldown is only checked on step-on; stepping on during the 0.8 s cooldown sets Pressed=true without collecting, so the player must step off and on again.
- MoneyStandOwnership: only slots that exist at setup are watched for Unlocked/Available; later slots rely on the owner-change refresh.
- QuestService: Increment calls while PlayerDataService's Persistence.Load is still yielding (up to 30 s) are dropped.
- GameMenuServer: GetState rate limit is 5 ms (0.005), effectively only same-frame spam. Upgrade actions infer success by waiting 0.4 s; a slow server can answer "Go to your plot to upgrade" although the upgrade started.
- UpgradeEffects and MoneyStandBuilder are not required by any active script in src/ (only archived copies / template clones).
- LeaveEarningsOverlay: OFFLINE_RATE 0.5 / 8 h cap are hard-coded copies of PlayerDataService values.
- MoneyStandClient: _shine is never called (plate Shine sweep is dead code).

**Leaks (not fixed)**
- None significant: GameAdapter/ShopService/MoneyStandClient/MoneyStandOwnership connections are bound to Player, Backpack, Character, plot or stand instances and die with them; watchedHatchEvents is weak-keyed.

**Cross-file duplication candidates**
- formatShortCash (UNITS table) identical in OfflineEarningsUI and LeaveEarningsOverlay (MoneyLogic uses InventoryFormat.Short).
- getIncomePerSecond (PlacedItems IncomePerSecond sum x OwnerIncomeMultiplier) in MoneyLogic and LeaveEarningsOverlay.
- create(class, props, parent) helper in OfflineEarningsUI and LeaveEarningsOverlay (and other UI scripts).
- Egg Tool building (Handle + welded visual) in ShopService.giveUnknownEgg and GameAdapter.createEgg.
- leaderstats.Cash lookup in ShopService.getCashStat, GameAdapter, GameMenuServer.UnlockSlot, MoneyStandServer.awardCurrency.

**Selene warnings left**
- MoneyStandOwnership: 2x if_same_then_else (pre-existing; three branches all :Destroy(); documented in header, not merged to stay bytecode-SAME).
- OfflineEarningsUI 3x, LeaveEarningsOverlay 1x roblox_manual_fromscale_or_fromoffset (pre-existing; switching to fromScale changes bytecode).
- Fixed via _ prefix: unused_variable in UpgradeEffects, ShopService, GameAdapter (3), QuestService (3), MoneyStandClient (2); shadowing root in GameMenuServer (now rootPart).

### Batch 12 — Mutations, effects and nighttime

**Functions extracted**
- None. All 11 files are bytecode-SAME (renames, headers/comments, UPPER_SNAKE constants that Luau constant-folds, formatting).

**Duplicates consolidated**
- None. In-file candidate left as-is: NighttimeHUD setMode delayed fade-out sequences ("countdown" vs "active") differ only in timings.

**CHANGED files**
- None.

**Known issues / suspected bugs (not fixed)**
- NighttimeSky legacy "NighttimeStatus" banner says "2x CASH / 2x RIVER LUCK" and "DOUBLE CASH ...", but NighttimeService gives 3x cash / 2x hatch / 3x luck. The ScreenGui is Enabled = false (NighttimeHUD replaced it), so nobody sees it, but its labels and tweens are still updated every frame (wasted work).
- NighttimeService: inside the forced-night branch, `active and endsAt or 0` is always endsAt (active was just set to true). This is redundant but harmless.
- NighttimeHUD / NighttimeSky hard-code DURATION 20, the 300 s cycle and the bonus text, so they must be kept in sync with NighttimeService by hand. During a forced (staff) night longer than 20 s, the HUD bar stays clamped full.
- NighttimeHUD: `create("UIScale", {}, gui):Destroy()` is a no-op, and _barGradient / _GuiService are unused.
- MutationDropService: if the workspace attribute NextMutationDropAt is ever cleared, `GetServerTimeNow() >= nil` errors and the drop loop dies for the rest of the server's life.
- MutationDropBoardClient: Timer / Tiers are looked up with FindFirstChild (no wait). If either is missing, the loop errors and the board stops.
- Mutations.Roll checks each tier separately, rarest first. So the real chance of a lower tier is slightly below 1/N, and luck >= 5000 always gives Rainbow. This is by design and is now documented in the header.
- Mutations.Model:
  - A non-Gold tier with no pack model returns nil, so the character gets no Mutation and the caller keeps the base model.
  - Base attributes are copied over the pack model's own attributes.
  - The Gold tint fallback does not strip RarityFX / Aura children.
- GoldFXClient: the RenderStepped loop indexes data.fx.GoldFX_Emitter / data.fx.ShineShells directly, but trackModel never waits for ShineShells. If it is missing, every frame errors for every model. Box-corner bounds are also recomputed every frame for each sweeping model (performance only).
- GoldFXServer: any model whose name contains "gold" (for example "Marigold") counts as gold if it has a Torso and a Head.
- AuraFlipbookPump: workspace.CurrentCamera is captured once. If the camera instance is replaced, the distance checks use the old camera.
- OwnerShowcaseFX is shipped Disabled (default.project.json $properties.Disabled = true), so all of its code is currently inactive.

**Leaks (not fixed)**
- GoldFXServer: watchedModels is strong-keyed and only cleared on Destroying. A model that is unparented but never destroyed keeps its entry and its 4 connections alive.
- OwnerShowcaseFX: plot.ChildAdded connections are never disconnected (minor, since plots live as long as the server). The pillar fade task can outlive a destroyed fxFolder (harmless).

**Cross-file duplication candidates**
- Night cycle constants (300 s cycle, 20 s night, the (floor(now/300)+1)*300 fallback) appear in NighttimeService, NighttimeHUD and NighttimeSky. A shared NightConfig module would remove the risk of them drifting apart.
- The mutation tier list / order appears in several places: Mutations.Order, the literal list in MutationDropService.pickTier, and the board's TIER_COLORS / "SILVER · GOLD · DIAMOND · RAINBOW" text.
- Invisible anchored holder-part helpers: NighttimeSky.makeHolderPart and OwnerShowcaseFX.makeHolderPart. The create(className, props, parent) builder also appears in many UI scripts.
- The colorSequence / numberSequence varargs helpers (OwnerShowcaseFX) are likely duplicated in other FX scripts.

**Selene warnings left**
- NighttimeSky (1) and NighttimeHUD (2): pre-existing roblox_manual_fromscale_or_fromoffset warnings on UDim2.new offset-only calls. They are left as-is because fixing them would change bytecode and constants.
- NighttimeHUD: the pre-existing unused_variable warnings (GuiService, barGrad) are fixed by the `_` prefix (selene 4 -> 2).

### Batch 13 — Client UI: MenuLogic

**Functions extracted (MenuLogic.client.luau)**
- Top level: extendDimPastInsets, fitPanelToScreen (out of layoutMenus); buildIndexSeasonTabs, buildIndexProgressStrip, buildIndexRarityFilters, buildIndexCell, buildIndexDetail (out of RENDER.Index); buildQuestTabs, buildQuestTimer, buildQuestRow (out of RENDER.Quests); applyFigmaWindow (out of RENDER.Plot).
- Local to a render: addDealEggShowcase, addDealCountdown (RENDER.VipShop limited deal); addSlotCell, addUpgradeRow (RENDER.Plot loop bodies).
- Index's per-render `local ORANGE = Color3.fromRGB(255, 140, 30)` became the top-level constant HALLOWEEN_ORANGE (a pure value, now built once).

**Duplicates consolidated**
- None. In-file candidates were left alone because they are not identical:
  - livePrice (shop) vs warmPrice (start-up warm-up): the same _G.__shopPrices fill logic, but one returns price/fallback and the other returns nothing.
  - formatCountdown ("[Nd ]HH:MM:SS") vs the shop's formatHms ("H:MM:SS").

**Why the CHANGED file is behaviour-identical**
- Pass 1 was renames, comments and banners only. It verified SAME, and that copy is saved at scratch/ml_pass1.luau.
- Pass 2 only moves contiguous blocks into helpers:
  - Each helper is called at the block's original position, with that block's locals passed in as parameters.
  - No block assigns to a caller local. The only state they write is top-level state (indexSeason, indexFilter, indexSelectedId, questTab) and table fields.
  - No block contains return, break or continue at its own level (loop bodies included).
- Bytecode check (scratch/b13_bc.py, -g1, operands stripped):
  - All 126 nested closures that existed before are op-for-op identical.
  - Each extracted body matches its old parent window. The only differences are MOVE↔GETUPVAL (param/upvalue vs register) and JUMP→RETURN at branch ends.
- strcheck OK, so the constant set is unchanged. Tree diffs 0.

**Known issues / suspected bugs (not fixed)**
- VipShop: `shopRemote:InvokeServer("State")` and shopAction's InvokeServer are not pcall'd. The render error is caught by refresh's pcall, but an error inside a buy click just dies in the event handler, and the shop does not re-render.
- VipShop only checks the remote. If ShopSystem has ShopRemote but no ShopConfig, `ShopConfig.Icons` errors.
- fetchState retries only when the server's text is exactly "Please wait a moment.". This is a string contract with GameMenuServer.
- SKINS.VipShop (Halloween vs normal) and the initial indexSeason read workspace.HalloweenMode once at script start. Toggling the event at runtime does not update them.
- Quest progress bar: `quest.progress / quest.target` gives NaN/inf if target is 0.
- RENDER.Plot upgrade rows always send `{ index = 1 }`. "Incubator Speed" only ever upgrades chamber 1, and its level shown is chamber 1's.
- slotCap defaults differ: RENDER.Plot uses `availableSlots or 12`, while the legacy pages used `availableSlots or level*12`.
- layoutMenus listens to ViewportSize only on the camera that exists at start-up. A replaced CurrentCamera is not tracked.
- isClickOnPanel assumes PlayerGui exists (it would error otherwise; practically always present).
- Every refresh rebuilds the whole panel: all instances, infinite tweens and new `while label.Parent and panel.Visible` timer threads. The old ones die when their labels are destroyed, so this is not a leak, but it is heavy churn on each Changed event.
- Dead code kept (renamed with a `_` prefix where it was unused):
  - _addStuds (returns immediately)
  - _plotTabs, _legacyOverview, _legacyUpgrades, plus plotPage / SLOT_PRICES, which only they use
  - _innerOf, _EDGE_COLOR, _BANGERS_FONT, _figmaArt
  - Quest `_emoji`: a chain of string.find calls that runs on every row, but its result is unused
  - v3tab's `tabFrame = tabFrame` no-op

**Leaks (not fixed)**
- None found. The egg RenderStepped connection disconnects itself once its viewport is unparented. All other connections live on instances that are destroyed on re-render, or on permanent side buttons.

**Cross-file duplication candidates**
- The create(className, props, parent) builder, the UIScale hover/press tween pattern and the studded-card builders are repeated across many UI scripts (GameHUD, NighttimeHUD, FigmaSkin...).
- The `Slot%02d` lookup and the UpgradePrices.Temple/IncubatorLevel/AddIncubator price display logic are duplicated with the server's GameAdapter / PlotManager.
- `_G.__shopPrices` is only read and written in this file (by both the shop and the warm-up). It is effectively script-local, but it was kept as-is per the rules.

**Selene warnings left (17, baseline 38)**
- 11 global_usage on `_G.__shopPrices`: an intentional cross-script contract, kept.
- 6 roblox_manual_fromscale_or_fromoffset: fixing them would change bytecode and constants.

### Batch 14 — Client UI: GameHUD

**What changed (GameHUD.client.luau)**
- Pass 1 (renames + comments + banners) verified SAME. That copy is saved at scratch/gh_pass1.luau (rename script: b14_ren.py, comments: b14_cmt.py).
  - New header: runtime location, the two ScreenGuis, table of contents, every remote with its payloads, modules, attributes read and written, instance names other scripts look up (FigmaSkin, SharpUI, FirstHatchTutorial), key bindings and init order.
  - 11 "-- ===== N. ... =====" section banners, in MenuLogic style.
  - Locals renamed: services get their full names; make->create, tw->tween, money->formatMoney, RARITY->RARITY_COLORS, MUTC->MUTATION_COLORS, bar->hotbar, panel->bagPanel, Inv->inventoryPanel, tab/small/big/sub/cnt->nightBanner/nightCountdownLabel/..., plus all single-letter locals. Unused locals got a _ prefix (_StarterGui, _name/_rarity in buildSlot, _minutesAway).
  - selene warnings went from 16 to 8 (removed: 4 unused_variable and 4 shadowing).
- Pass 2: 10 helpers extracted (b14_ext.py). The file is now CHANGED.

**Functions extracted (GameHUD.client.luau)**
- From buildPreview: addMutationAura (the mutation aura and shine block), buildPreviewModel (the PREVIEW_CACHE miss branch, which now returns the model).
- From renderBar: restyleHeldSlots (the reuse path), buildSlot (the per-slot loop body).
- From renderBag: buildBagCard (the per-card body, after the totals are added up in the caller).
- From the Inventory render (inside its do block): refreshControls (tab and chip restyle), buildCell (the per-cell body).
- From the night RenderStepped handler: playNightTransition, playDayTransition, updateBigCountdown.
- Not extracted on purpose: the drag ghost creation in startDrag. Moving it would delay the "ghost = ..." upvalue write until after buildPreview runs, which changes the error path.

**Duplicates consolidated**
- None. INVENTORY_MUTATION_COLORS (Inventory panel) has the same values as MUTATION_COLORS (hotbar), and the hotbar slot's rainbow ColorSequence equals RAINBOW_GRADIENT. They are separate tables built at different points, so merging them would change bytecode. They are left as candidates.

**Why the CHANGED file is behaviour-identical**
- Each block was moved unchanged into a helper and called at its original position. The block's locals became parameters: groups[i] and signatures are read at the same point, and a loop's i became slotIndex or index (the occurrence counts were asserted).
- No moved block assigns to a caller local:
  - buildPreviewModel creates its own model and returns it as its last statement. The caller's model is not read until after the call.
  - Totals in renderBag stay in the caller.
  - Writes to nightState, lastCountdownSecond, countdownTween, armedTool, armedItem, selling and bulkIds are top-level or do-block upvalues in both versions.
- No moved block contains return, break or continue at its own level.
- Bytecode (-g1, operands stripped, scratch/b13_bc.py on a14.txt / b14.txt):
  - All 111 closures that are not parents are op-for-op identical.
  - 8 of the 10 helper bodies match their old parent window with 0 diff hunks.
  - buildPreviewModel and buildBagCard differ by one dropped MOVE each (a register/upvalue difference).
- strcheck OK (the constant set is unchanged). Tree diffs 0. verify PASS.

**Known issues / suspected bugs (not fixed)**
- SellEgg is fetched with WaitForChild(..., 10) and can be nil. Then sellEggRemote.InvokeServer is indexed before pcall, so every quote or sell errors.
- CharacterInventory.InventoryRequest/InventoryEvent are waited for with no timeout. If they are missing, the whole HUD below the hotbar never builds.
- Any error after "selling = true" in a sell handler leaves selling true for good, which blocks all selling. Examples: SellAll returns ok without a count, so ".. n .." errors on nil; formatMoney(nil).
- Egg quotes (sellQuotes) are cached per tool forever:
  - A failed quote (false) stays "CAN'T SELL".
  - A changed server price is never re-quoted.
- The legacy bag is retired but still built. setBagOpen always forwards to the Inventory panel, so EggBag never becomes visible.
  - Its debounced onQuote is overwritten by the Inventory panel's version.
  - FirstHatchTutorial checks shown_("GameHUD", "EggBag"), which therefore can never be true.
- If InputEnded never arrives (for example, focus is lost mid-drag), activeDrag stays set and the move connection stays alive. No new drag can start after that.
- rescale only tracks the ViewportSize of the camera that existed at start-up.
- The hotbar tooltip rebuilds its RichText and calls describeTool every frame while hovering, which is minor per-frame work.
- The Inventory render rebuilds every cell, including the spawned edge-rotation loops, on each change. The loops end when the cells are destroyed, so this is churn, not a leak.
- Dead code kept:
  - the "if false then" rainbow tint in buildPreview
  - the away-earnings popup (earnings is hard-wired to nil, _minutesAway is unused)
  - USE_DEFAULT_BACKPACK branches (the flag is always false)

**Leaks (not fixed)**
- None confirmed. Watchers hook each new Backpack and Character, and those connections die with the instances. Every spawned animation loop exits once its instance is unparented. The only risk is the stuck drag described above.

**Cross-file duplication candidates**
- The create / addCorner / addStroke / tween primitives, the studs ImageLabel (rbxassetid://132561191216691) and the studded-plate pattern are shared with MenuLogic, NighttimeHUD and FigmaSkin.
- formatMoney vs other money formatters.
- The phoneScale / compact (<600 px) checks.
- The night timer duplicates NighttimeHUD/NighttimeStatus, which this script disables.
- The mutation and rarity colour tables vs the shared mutation and rarity configs.

**Selene warnings left (8, baseline 16)**
- 8 roblox_manual_fromscale_or_fromoffset. Fixing them would change bytecode and constants.

### Batch 15 — Client UI: controllers and prompts

**Functions extracted / duplicates consolidated**
- FeedbackClient: `setZIndexDeep(root, zIndex)` replaces 3 identical "set ZIndex on button + every GuiObject descendant (ipairs)" blocks (close X, kind buttons, SEND).

**Why the CHANGED file is behaviour-identical**
- FeedbackClient: the helper body is the original block verbatim (same ZIndex write first, then the same ipairs loop over GetDescendants, same IsA check); it only writes instance fields, never caller locals (extcheck: no PARAM_WRITES); strcheck OK; bytecode diff = one new closure + register shifts.

**Known issues (not fixed)**
- FeedbackService: the cooldown stamp is written only after `FilterStringAsync` (yields), so several invokes fired at once by one player all pass the cooldown check and can each post to Discord. A failed HTTP post clears the stamp, so while the webhook is failing each invoke triggers another post attempt. There is no per-server cap (`_perServer` was never implemented).
- FeedbackClient: `windowScale.Scale * 0.9` in setWindowOpen is overwritten by refitWindow straight away (no visible effect; commented).
- FigmaSkin: skinMoney (section 3) builds FigmaPill/FigmaShadow that section 5 hides 0.5 s later (wasted work, and it depends on timing). Quest tracker: Changed events that arrive while a fetch is in flight are dropped (it catches up on the next 8 s poll); the poll loop runs for the whole session (one GetState invoke every 8 s per player).
- FigmaSkin: skinNight connects to workspace `NighttimeActive` and the gui; if NightBar is ever re-created, the old connections stay (suspected small leak; NightBar is ResetOnSpawn=false in practice).
- FigmaSkin: `_skinBag`, `_skinGear`, `_thumb`, `_face` are dead code (kept, prefixed `_`).
- PromptCards: watchPlot hooks `OwnerUserId` only on plots that exist when the script starts (plots added later are never watched); any plot's owner change rebuilds all owner prompts.
- PromptCards: the batch brief says it uses GameMenus.OpenMenu — it only fires `LocalRefresh` (OpenMenu is used by FigmaSkin's daily button).
- PixelIconSharpener: only checks images when they are added; an image whose Image is later set to a pixel-art id is not sharpened.
- SharpUI: `Gloss`/`Stripes` frames and thin white frames are hidden for good (no restore); by design, noted for anyone reusing those names.

**Cross-file duplication candidates**
- `__clickOnPanel` (FeedbackClient) = same function as in src/shared/UI/Leaderboard/LeaderboardClient.luau (name kept for grep-ability).
- `create`/`make` instance helpers + `formatShort`/`short` number formatters exist in FeedbackClient, PromptCards, FigmaSkin and GameHUD/MenuLogic.
- The "Studs" tiled ImageLabel is built 3x in FigmaSkin (decorateFrame, studButton, addStudsImage) with slightly different properties (Active / ZIndex), so it was not merged; FeedbackClient builds the same studs texture.
- FredokaOne `Font.new(...)` and `STUDS` asset id repeated across UI scripts.

**Selene warnings left (all pre-existing)**
- FigmaSkin: `roblox_manual_fromscale_or_fromoffset` (1), `deprecated` Instance.new parent argument (1) — left so the bytecode stays the same.
- FeedbackClient: `roblox_manual_fromscale_or_fromoffset` (2). (The pre-existing `shadowing` of pg is gone.)
- FeedbackService: `incorrect_standard_library_use` on `game.JobId:sub` (known false positive).

### Batch 16 — Client UI: leaderboards (client + server)

**Functions extracted**
- LeaderboardView: `buildHeader`, `buildTabs`, `buildScopeToggle`, `buildColumnLabels`, `buildWell`, `buildStatusStates`, `buildYourRank`, `buildMetaLine` (sections of `View:_build`, as local functions taking `self` so no new method-name constants), `yourRankNote` (from `View:Render`).

**Duplicates consolidated**
- None.

**CHANGED files — why behaviour-identical**
- LeaderboardView.luau: each `_build` section moved verbatim into a local function called in the original order; the running `y` offset stays in `_build` (`y += ...` lines kept in the caller, the `Column > 0` and `Meta == 0` guards kept in the caller); helpers only create instances / set `self.*` fields, no param writes (extcheck clean). `yourRankNote` turns the if/elseif assignment chain into returns of the same expressions; `state.scope` / `stat.Kind` are plain-table reads passed in up front. strcheck OK (no constant changes).

**Known issues (not fixed)**
- LeaderboardService `incomeOf`: `workspace:GetAttribute("NightCashMultiplier")` is not `tonumber`ed; a non-number attribute would error (the loop is pcalled, but the first `refreshServer()` in `Start` is not).
- LeaderboardService `Service.Forget` resets the online player's `record.written`, so the next flush rewrites their Cash/Income and they reappear on the global board while online (non-hidden users).
- LeaderboardService `onInvoke` can recreate `buckets[player]` after `PlayerRemoving` if a late invoke arrives (tiny leak).
- LeaderboardService `Forget` calls `RemoveAsync` without a request-budget check.
- LeaderboardChampions: a podium removed without being destroyed (reparented out of the board) keeps its `spots` entry until the board is untagged; its `Destroying` connection is only released on Destroy.
- LeaderboardChampions: `_RANK_WORD` is unused; `createChampionTag`'s `_entry` param is unused (texts filled by `updateIdentity`).
- LeaderboardClient: `isClickOnPanel` is declared before the services block (kept in place for bytecode identity).
- Leaks: none found beyond the above; View button connections die with their instances; client CollectionService connections live for the session by design.

**Cross-file duplication candidates**
- `create` / `addCorner` / `addStroke` / `addGradient` / `createLabel` UI builders (LeaderboardView) vs. the same helpers in FeedbackClient, FigmaSkin and other UI scripts; `createPlainFrame` in LeaderboardClient.
- "User <id>" / "@username" fallback formatting in LeaderboardChampions vs. `fillRow` in LeaderboardView (could live in LeaderboardFormat).
- Tab/scope key `tab .. "|" .. scope` built in both LeaderboardClient and LeaderboardView.

**Selene warnings left**
- LeaderboardView: 13 × `roblox_manual_fromscale_or_fromoffset` (pre-existing; fixing changes bytecode).
- LeaderboardChampions: 1 × `deprecated` (`Instance.new("Animator", humanoid)`, kept and documented). Pre-existing `unused_variable` warnings fixed by `_` prefix.

### Batch 17 — Client UI: tutorial and bootstrap

- **Functions extracted**: JoinArrival: `showWelcomeCard(travelTime)` (the 140-line welcome-card `do` block from `begin`).
- **Duplicates consolidated**: none.
- **CHANGED files**:
  - JoinArrival.client.luau: the welcome-card block moved verbatim (dedented) into a top-level local function, called at the same spot in `begin`. Its only outer local, `travelTime`, is read-only and is now passed as a parameter. It writes no enclosing locals and has no return/break, and instance creation, task.spawn and task.delay run in the same order. extcheck: PARAM_WRITES=[]; strcheck OK.
- **Load sequence**: LoadingScreen, StartupLoader and StartupAssetManifest are bytecode SAME (renames and comments only). The manifest contract (`StartupAssetManifest` / `StartupAssetManifestEssential`, JSON `{id, kind}` from `StartupLoader.Collect`) is documented in both headers.
- **Known issues (not fixed)**:
  - JoinArrival: `begin` sets `setCharacterAlpha(char, 1)` and then the render step sets it back to 0 every frame. The character is therefore never hidden or faded in, even though the comment says "character fades in during the reveal beat". `_revealStart` is computed but unused.
  - JoinArrival: the Sky* Config keys (SkyHeightScale, SkyBackScale, SkyLookBias, SkySideAngle) are unused since the Hero path replaced the sky shot. `_mapBounds` / `_bezier` are dead code, and so are the colours `_WOOD` / `_CREAM_*` and `_restoreCoreGui`.
  - JoinArrival entry loop checks `ReplicatedFirst.LaunchLoadingScreen` / PlayerGui `LaunchLoadingScreen` (old name). The current gui is `HatchLoading` (also checked), so this works, but the old name is stale.
  - JoinArrival: the connections made at top level (`skip.MouseButton1Down/Up/Leave`, `AbsoluteSize`, Studio replay) are never disconnected. That is harmless because the gui has ResetOnSpawn=false and the script lives for the whole session.
  - LoadingScreen: `_rays`, `_fillShine` (an empty Frame + gradient), `_artZoom`, `_anime`, `_loopTween` and `_COLORS` are dead code. Config Images/PreloadFolders/PlotReadyAttribute/PlotWait/Colors are unused.
  - LoadingScreen: while Studio `HoldLoading` holds `close(true)`, a Skip or timeout `close(false)` can run alongside it, because `closing` is only set after the hold loop. Both then run the fade/destroy path (Studio-only).
  - StartupLoader.Run: `StartupAssetCount` counts only the essentials, but the essentials and the rest go through a single 45 s Preload pass. The background pass (180 s) retries only the failed or timed-out assets (`deferredAssets` is emptied).
  - FirstHatchTutorial: `applyLayout` is a no-op, so the phone "squeezed" state is tracked but has no effect. `useCompactScale` is a redundant copy of `isPhone`. `gui.Destroying` connection not tracked (fine, fires once).
- **Cross-file duplication candidates**: `restoreCoreGui` is identical in LoadingScreen and JoinArrival. `make/create(class, props, parent)` instance helpers appear in LoadingScreen and FirstHatchTutorial (and other UI files). The loading-gui name checks `HatchLoading` / `LaunchLoadingScreen` are repeated in JoinArrival and FirstHatchTutorial.
- **Selene warnings left**: LoadingScreen has 5 `roblox_manual_fromscale_or_fromoffset` warnings (pre-existing; fixing them would change bytecode). Every other file in the batch has 0.

### Batch 18 — Cinematics: TrailerCinematic

Worked in passes. Pass 1 (renames + header + banners + comments) was bytecode SAME and is saved as the fallback
scratch/tc_pass1.luau (scripts b18_ren.py, b18_cmt.py). Pass 2 (extractions: b18_ext_prepare.py, b18_ext_hide.py,
b18_ext_scenes.py) makes the file CHANGED. Original copy: scratch/tc_orig.luau. No module split.

**Functions extracted** (TrailerCinematic.client.luau; all top-level local functions, one call site each)
- prepare: loadMarkers, findIncubator, addDerivedMarkers, assertSetupComplete, buildActor, findEggSocket,
  computeShots, planRoutes, preloadAssets, startPlayback
- hideForRecording: hideCoreUi, hideGuisAndPrompts, hideCharacters, disablePlayerControls, applyColorGrade,
  takeOverCamera
- scenes: createRiftParts, createFallTrail, animateRift (RiftArrival); applyEggWobble, revealReward,
  updateRewardPop, updateRewardLift (Hatch); spawnSlotGlow (Place)
- updateFrame: sumShakes, pullCameraClear

**Duplicates consolidated:** none.

**Why the CHANGED file is behaviour-identical**
- Every extracted body was moved verbatim (scripted cut/paste by anchors, only re-indented) and is called exactly
  where the block was, so evaluation order, yields (WaitForChild, ComputeAsync, PreloadAsync wait loop, task.wait)
  and instance creation / parenting order are unchanged. No helper writes an enclosing local; values used later come
  back as return values (findIncubator, buildActor -> actor, model, findEggSocket, createRiftParts, createFallTrail,
  sumShakes, pullCameraClear).
- findEggSocket: the five "run.socket = X" branch tails became "return X"; the caller does
  run.socket = findEggSocket(incubator). Nothing reads run.socket in between.
- pullCameraClear(run, camCF) reassigns its own parameter and returns it (extcheck flags it; intended).
- The countdown loop with its returns stays in prepare; startPlayback is the former tail of prepare.
- strcheck OK (constant set unchanged). SETUPVAL/SETGLOBAL: 6 before, 6 after, same owners (showStatus, cleanup,
  start, the pcall closure setting model - now in buildActor - and the preload closure setting preloadDone - now in
  preloadAssets). Per-function -g1 comparison against pass 1: only prepare, hideForRecording, updateFrame and the
  anonymous RiftArrival / Hatch / Place callbacks changed.
- _G.TrailerStartV1 = start and the _G.TrailerPicker read are unchanged; shot order, cue times, CFrames, easing,
  durations, sound slots, attribute and instance names are untouched.

**Renames (selection):** R -> run, top-level run -> activeRun, A -> actor, E -> egg, W -> reward, T -> title,
M -> markerPos, V -> euler, seg -> segment, status -> showStatus, part -> makePart, sound -> playSound,
base -> actorBaseCF, update -> updateFrame, ROCKS -> EGG_ROCK_KEYS, JOINT -> JOINT_NAMES, REQUIRED -> REQUIRED_MARKERS,
plus the locals in prepare / hideForRecording / the scenes. Unused: the pose functions' t params -> _t,
runTo -> _runTo, route's R -> _run, Intro start T -> _title (the titleGui call stays).

**Known issues (not fixed)**
- hideGuisAndPrompts: the ProximityPrompt and Highlight branches have identical bodies (selene if_same_then_else,
  pre-existing). Harmless; documented inline.
- Prompts added during a take (DescendantAdded handler) are disabled with no restore callback, so they stay off
  after the trailer ends.
- Leak: in hideCharacters, the CharacterAdded connection made inside Players.PlayerAdded is never stored in
  run.conns, so it survives cleanup (every take adds another; guarded by activeRun == run).
- preloadAssets' wait loop (up to 8 s) ignores cancellation; after a cancel the "Loading trailer assets…" toast
  keeps overriding "Trailer cancelled" until the loop ends.
- _runTo is dead code. Instance.new("Animator", hum) uses the deprecated parent argument (selene deprecated).

**Cross-file duplication candidates:** TrailerDuoV2 / TrailerDuoV3 duplicate the picker GUI and likely many of this
file's helpers (easing, status toast, recording-mode hiding, cleanup) - candidates for a shared Cinematics util
module (not done).

**Selene warnings left:** 1x if_same_then_else (pre-existing, documented), 1x deprecated (Instance.new parent arg),
3x global_usage (_G contracts, must stay). 16 -> 5 (all 11 unused_variable fixed with _ prefixes).

**Verification:** stylua --check OK; "CHANGED lines 2355->2688 selene 16->5 ... RESULT: PASS"; strcheck OK;
treecheck "instances 1004 1004 diffs 0".

### Batch 19 — Cinematics: duo trailers and cine cam

All four files bytecode SAME (renames, comments, banners, one pure declaration split). No extraction, no split.
Scripts: scratch/b19_ren.py (scoped renames), scratch/b19_ins.py + b19_spec_{v2,v3,cc,cs}.py (headers / banners / comments).
Originals: scratch/b19_*.orig.luau.

**Functions extracted:** none. The two RenderStepped drivers are long, but their branches share many per-frame locals
(eggHeight, shake, poseOffsets, target / shotId) that are written in one block and read in later ones, so extracting
would mean returning several values per block for little gain. Left as one function with clear sub-comments plus a
timeline in each header.

**Duplicates consolidated:** none. (TrailerDuoV2's `local angles, lerp, clamp = ...` split into three
declarations, bytecode identical.)

**CHANGED files:** none.

**Known issues (not fixed)**
- TrailerDuoV2: the picker (`_togglePicker`, was `picker`) is dead code, never called or exported (TrailerDuoV3 owns
  _G.TrailerPicker).
- TrailerDuoV2: `local lastShot = -1` was declared twice (first renamed `_lastShot`, unused).
- TrailerDuoV2: TUG_POSE keys UpperTorso / LeftUpperArm / RightUpperArm / LeftLowerArm / RightLowerArm are part
  names, not Motor6D names, so applyPose ignores them (only hips / knees + Waist / Neck apply). V3 uses the right names.
- TrailerDuoV3: `actors[1].head, actors[2].head` has no nil fallback: if an avatar fails to load, the RenderStepped
  callback errors every frame, never reaches cleanup, and `running` stays true (V2 has fallbacks).
- TrailerDuoV3: egg PivotTo if-chain has two identical branches (selene if_same_then_else, pre-existing; documented).
- TrailerDuoV3: cleanup re-enables every BillboardGui under WaterfallEggs / LocalRiverEggs, even ones that were
  disabled before the take. `_eggFocus` (was `e`) is computed but unused.
- TrailerDuoV3: `_G.PortalRipple` is not defined anywhere in src, and no script reads the gates' "SurgeLevel"
  attribute (stale contracts; calls are guarded so harmless).
- Both duo trailers: no cancel / death handling; once started a take always runs 18 s. The countdown yields the caller
  (picker button / attribute handler). Instance.new(class, parent) deprecated parent arg used throughout.
- Both duo trailers: the owner gate uses only Config.OwnerIds (no AllowInStudio like v1).
- CineCamClient: exitCamera never restores the saved CFrame (`originalCamera.cf` recorded, unused). Owner id
  168774222 hard-coded in both CineCam files, separate from TrailerConfig.OwnerIds. The Studio bypass checks
  UserId == 0, which Studio test players normally don't have (Play Solo uses the real id, test-server players are
  negative), so it likely never triggers.
- CineCamClient: hideVisualUI's DescendantAdded connections are disconnected only via restoreVisualUI (fine); the
  "Preview saved path" button reports "Set or load at least two points." also when the refusal is because a preview is
  already playing.
- CineCamServer: save validates only the array part (`#payload`, ipairs); extra hash keys in the payload or in shot
  / point tables are stored to the DataStore unvalidated (owner-only, low risk). Name length is in bytes.

**Cross-file duplication candidates (not merged)**
- TrailerDuoV2 / TrailerDuoV3: the picker GUI (VERSIONS + toggle), buildActor (avatar clone + Motor6D swap),
  playAnim, applyPose, lerp / segment / ease, the status-label countdown, the end-card makeCardText + flash frame,
  the recording-mode hiding (ScreenGuis, CoreGui, BillboardGuis, characters) and the cleanup tail are near-identical.
  TrailerCinematic has its own versions of the easing helpers, status toast, actor build and hiding.
  Candidate: a shared ReplicatedStorage Cinematics util module.
- CineCamClient / CineCamServer: the owner-id + Studio check is duplicated (and differs from TrailerConfig.OwnerIds).

**Selene warnings left:** V2 18 (was 23): deprecated Instance.new parent arg, global_usage (_G contracts),
manual_table_clone in tugPose (pre-existing). V3 29 (was 32): deprecated, global_usage, 1 if_same_then_else
(pre-existing, documented). CineCamClient 2 deprecated (unchanged). CineCamServer 0.

**Verification:** stylua --check OK; all 4 files SAME, RESULT: PASS; treecheck "instances 1004 1004 diffs 0".

### Batch 20 — Admin and cross-server

All 20 files bytecode SAME (renames, headers, section banners, comments). No extraction, no split, no CHANGED file.
Scripts: scratch/b20_ren.py (scoped renames from originals in scratch/b20/), scratch/b20_specs.py + scratch/b20_ins.py (headers / banners).
Every server header now states who is authorized, how it is checked and which remote input is trusted.
Server permission paths got renames + comments only.

**Functions extracted:** none. Tried makeHolder(width, height) in StaffAnnouncements (the holder Frame + UIScale block
is identical in buildChatBanner and buildBanner). Reverted: the call stops constant folding (/ 700, / 640), so
strcheck reports DIFF (numbers 640 / 700 leave the constant table) even though the values are the same.
Listed as a candidate for later.

**Duplicates consolidated:** none.

**CHANGED files:** none.

**Known issues (not fixed)**
- StaffServerService (audit: "StaffServer TeleportData trust"): IsStaffServer is set from client-controlled
  TeleportData.isStaffServer, so anyone can make a public server kick all non-staff. Also, guardPlayer skips any player
  whose TeleportData has SoftShutdown == true (also client-controlled), so a non-staff player can get into a real staff
  server that way.
- AdminRoles (audit): the panel-added admin list is read once at start-up. SetAdmin only updates this server, so a
  revoked admin keeps access on other running servers.
- OwnerGameActions (audit): Respawn uses LoadCharacterAsync, which does not fire Died, so the backpack is lost.
- OwnerControlServer: the GiveCash branch inside dispatch can't be reached (OwnerGameActions.Handles.GiveCash is
  checked first), and it has different limits (1e12 cap vs finite).
- OwnerPanelServer: args.color is passed to clients and to CrossServerService.GlobalAnnounce without checking it
  (clients fall back to red). Global announcements are filtered twice (Announce cuts to 120 characters, then
  GlobalAnnounce filters again).
- CrossServerService: table messages from other servers are trusted as-is (any server in the universe can trigger
  isUpdate rejoin); outside JSON messages are forwarded to clients without checks (title / by go into the chat-style
  banner's RichText, so markup injection is possible from Open Cloud). After a live soft shutdown, ServerUpdating
  stays true (by design).
- StaffAnnouncements: chat-style banners put by / title into RichText without escaping. When a banner is hiding
  (0.32 s yield, currentBanner == nil) a new event starts at once while the queue also spawns the next one, so two
  banners can overlap.
- AdminTerminal: the start-up staff probe (Announce with empty text) counts against the server's 0.2 s rate limit.
  /ban only works on online players (the panel needs an online target). The TextChatCommand "OpenTerminal" is created
  on the client without checking for an existing one.
- OwnerPanelClient: the legacy player.Chatted fallback has two identical branches (selene if_same_then_else). With
  TextChatService it may never fire.
- OwnerShowcase: plots added after start are connected but refreshStatue is not called for them. Plots is waited for
  twice. Instance.new("Animator", humanoid) uses the deprecated parent argument (documented, kept).
- OwnerPanel legacy modules (ActivityLog, Components, ConfirmDialog, PlayerRow, Theme, Toast) are only required by
  each other; StudPanel and nothing else in src uses them (dead code, kept). Toast's bullet ternary has two identical
  branches.
- VIPChatTag assigns TextChatService.OnIncomingMessage; any other script that assigns it replaces this one.
- The owner UserId 168774222 / co-owner 353101613 / YOUTUBE 10192461618 are hard-coded in AdminRoles,
  OwnerControlServer, OwnerShowcase, OwnerOverheadBanner and RoleTagServer (audit item).
- Leaks: OwnerOverheadBanner's CharacterAdded connections and RoleTagServer's PanelRole connections are never
  disconnected (they end with the player, so harmless). Each Components.Button adds 2 to 3 connections that live as
  long as the button.

**Cross-file duplication candidates**
- The same make(className, props, parent) instance builder is in AdminTerminal, StaffAnnouncements and
  Components.Make.
- The username / UserId resolvers are separate in OwnerControlServer.resolveTarget, OwnerGameActions.getPlayer,
  PlayerPunish.resolvePlayer and AdminTerminal.findPlayer.
- The same TextService FilterStringAsync + GetNonChatStringForBroadcastAsync pcall is in OwnerPanelServer.Announce
  and twice in CrossServerService.
- The plot lookup by OwnerUserId is in OwnerGameActions.findPlot, OwnerPanelServer.plotSummary and PlayerPunish.
- The role / tag tables are in RoleTagServer.TAG_BY_USER_ID and OwnerOverheadBanner.ROLE_BY_USER_ID.
- The holder + UIScale block is in both StaffAnnouncements builders (in-file candidate, see above).

**Selene warnings left (all pre-existing)**
- OwnerPanelClient and OwnerPanelServer: if_same_then_else. Documented in comments; changing it would change the
  bytecode.
- Components, ConfirmDialog, Toast, AdminTerminal: roblox_manual_fromscale_or_fromoffset. These are style warnings and
  were left so the bytecode stays SAME.
- OwnerShowcase: deprecated (Instance.new parent argument). Documented.
- CrossServerService: unused_variable fixed (pubErr renamed to _pubErr). OwnerPanelServer went from 12 warnings to 1
  (unused handler parameters given a _ prefix).

### Batch 21 — Admin: StudPanel

One file, src/shared/Admin/OwnerPanel/StudPanel.luau. Bytecode CHANGED (helper extraction only). Pass 1 (renames + comments)
is SAME and saved as scratch/sp_pass1.luau. Scripts: scratch/b21_ren.py (scoped renames from scratch/b21_StudPanel.orig.luau),
scratch/b21_cmt.py (header/banners/comments), scratch/b21_ext.py (pass 2 extraction).

- Header documents: public API (StudPanel.Colors, StudPanel.Button -> buttonApi {face, holder, label, stroke, set, select},
  StudPanel.Build(gui, context) -> {open, close, toggle, refresh, show}), Owner and Admin tabs, scopes, every action
  name + payload per page, which are behind a confirm dialog, the direct invokes (Snapshot, SaveList), and the
  confirm / busy flow. Banners 1-5 at top level, 5.1-5.8 sub-banners inside Build.
- Renames: M->StudPanel, C->PALETTE (StudPanel.Colors field kept), RC->RARITY_COLORS, F/FB->FONT/FONT_BODY, STUDS->STUD_TEXTURE,
  ask->sendAction, toast->showToast, confirm->showConfirm, refresh->refreshSnapshot, selected->getSelectedPlayer,
  nx->nextLayoutOrder, fmt->formatNumber, helpers to addX/makeX, all page locals. Unused locals prefixed _
  (_addHardShadow, _titleLabel, _sideBackground, _closeButton, _faceGradient, _holder/_row): selene 28 -> 16.

**Functions extracted**
- StudPanel: addAmountPresets(parent, amountBox) (module level), addPlayerRow(pickCard, playerInfo) and
  addHalloweenDropCard() (local to Build).

**Duplicates consolidated**
- The 1K..1T amount preset grid on the Money and Punish pages was the same code (only the parent card differed) -> addAmountPresets.

**Why CHANGED is behaviour-identical**
- Each extracted block is moved verbatim (only dedented) and called at the same spot, with the same instance creation order and
  the same nextLayoutOrder() calls. No extracted block assigns to its parameters (extcheck: no PARAM_WRITES) or to locals of the
  calling page; the writes in addPlayerRow's click handler (selectedId, scope) and in the Halloween card (pickedEgg / pickedButton,
  own locals) go to the same variables as before. SETUPVAL/SETGLOBAL count 29 = pass 1, SETGLOBAL 0. strcheck OK, selene no
  regression, treecheck diffs 0. The Halloween block had no return/break; the player-row block was a whole loop body.

**Known issues (not fixed)**
- Leak: Build connects workspace.CurrentCamera ViewportSize -> refitToViewport and never disconnects it. OwnerPanelClient rebuilds
  the panel (destroying the old ScreenGui) on every PanelRole change, so each rebuild leaves a connection that keeps
  rescaling a destroyed UIScale. A camera swap (new CurrentCamera) is also not followed.
- sendAction silently drops clicks while another action is pending (busy); no feedback to the user.
- sendAction fills args.scope / args.userId on every call, so even scope-free actions (StopEvent, Announce...) send them; the
  "Give $1M to me" quick action forces scope "me" but still sends args.userId = selectedId.
- Events page: picking a duration calls render(), which rebuilds the page and clears the typed announcement text and river speed.
- Admins page "ONLINE — can use the panel now" only checks Players in this server; an admin online elsewhere shows as offline.
- panelApi.show(pageId) with a page id not in pages errors (pages[pageId] is nil); it also lets callers open Owner pages
  for an Admin (cosmetic only, the server re-checks).
- Hard-coded "Golden Pirate" exclusion in the Halloween drop list.
- Dead code kept: addStudRow returns nil immediately (makeStud unreachable), _addHardShadow unused, PALETTE.Plate2 unused,
  FONT and FONT_BODY are the same font.

**Cross-file duplication candidates**
- makeButton / brick / stud visuals mirror the StudHUD buttons (comment says "same look as the StudHUD buttons").
- formatNumber (K/M/B/T formatting) likely duplicates other cash formatters in the client HUD.
- Avatar headshot row (rbxthumb AvatarHeadShot) built twice here (Players, Admins pages) with different sizes; left as is.

**Selene warnings left**
- 16 x roblox_manual_fromscale_or_fromoffset (UDim2.new with only scale). Pre-existing style; switching to UDim2.fromScale
  would change bytecode/constants for no behaviour benefit.

**Tried and not done**
- Did not extract the near-identical Give egg / Give character buttons (different action, confirm text) or the repeated
  refreshSnapshot(); render() pairs: low value for a CHANGED diff.

### Batch 22 — Remaining: audio, weapons, world, services, storage, dev tools

- All 21 files SAME bytecode (renames + comments only). No helpers extracted, no duplicates consolidated, no module splits. Tree check: diffs 0.
- Parked / inert content (documented in headers): everything under ServerStorage never runs — DevWorkshop (Animate, SpookyMotion), FutureUpdateContent/RiverBeforeGoldContentReservation (NOT Disabled in default.project.json, so it would start immediately if moved to ServerScriptService), StoredCollectAllZones/CollectAllZoneServer (also Disabled), HalloweenSwitch / RestoreSurfaceAppearances (Studio command-bar modules). WoodenBat/BatServer lives in ServerStorage as a template but runs once WeaponGiver clones the Tool into a Backpack.

#### Known issues (not fixed)
- BatServer: hit test uses `part:FindFirstAncestorOfClass("Model")` — a part inside a nested model (accessory model, carried item model) resolves to that inner model and the hit is missed for that part. `canSwing` is per Tool instance, not per player (fine today: one bat per Backpack). Hits any Model with Humanoid + HumanoidRootPart (NPCs too).
- BatServer: attributes `SwingTick`, `LastHitTime` (Tool) and `BatEggKnocks` (Player) have no readers in src/ — maybe read by Studio-only or future code; kept.
- BatServer: `playHitFX` ignores its hit position (now `_hitPosition`); `Debris` service fetched but unused (now `_Debris`).
- BatMotionClient: client cooldown (1.1 s) mirrors the server value by hand — if BatServer.SWING_COOLDOWN changes, the animation can desync.
- HalloweenSwitch: `swapTrees` runs after the ITEMS loop, so if `ServerStorage._ARCHIVE.BeforeHalloweenMap_1791902647.MapTrees` is missing the empty loop errors and leaves the switch half-applied. `Instance.new("Folder", parent)` deprecated parent arg kept.
- HalloweenSwitch: SWAP_FOLDERS still lists the legacy `BrainrotModels` folder.
- RiverBeforeGoldContentReservation: Collect remote handler has no rate limit (server validation is phase + 17-stud distance only); `_RunService`/`_update` unused.
- CollectAllZoneServer: `require(...QuestService)` inside the payout path on every payout (cached by require, fine) — wrapped in pcall so a missing QuestService is silent.
- MusicSettings: `onMenuOverlay` always sets the gear holder Visible = true (`menuOpen` only used to close the panel) — the comment says the hide behaviour was retired; `_musicSlider` return value unused. The Activated `switch` callbacks run `onChange(initial)` at build time, re-writing the attributes (triggers one SaveSettings send after 1.5 s if remote present).
- WaterfallRiverMotion: `visible and (...) or 1` in the segment loop is always the first branch (visible already checked) — dead branch.
- WaterfallFallMotion: FALL_TIME assumes v0 = 2 but streak v0 is 2..5, so faster streaks sit clamped at BASE_Y until the cycle wraps (visual only).
- PumpkinIdle: runs on the server and writes 5 Motor6D C0s every Heartbeat (replication cost); `_glowParts` collected but unused.
- PirateEggConveyorMotion: `prompt.Triggered` on the local clone has no client debounce (server validates); the `RenderStepped` gold-glow connection and render step are never unbound (script lifetime = session, fine).
- Leaks: none beyond the above; WaterFX/RiverFlow/WaterfallFall connections live for the session by design.

#### Cross-file duplication candidates
- `watch(container)` + `onPlayer` Backpack/Character watcher pattern: NoDropping, ToolIcons, WeaponPreloadClient, BatMotionClient (watchCharacter).
- RiverPath consumers (RiverFlow, WaterFX, WaterfallRiverMotion) each throttle to 30 Hz with their own accumulator.
- RiverBeforeGoldContentReservation duplicates the live PirateEggFreeConveyor spawner/collect logic (intentional snapshot).
- Animate.client.luau: `configureAnimationSet` vs upstream's dead `configureAnimationSetOld` (kept to mirror upstream).
- Short-number formatter `formatShort` (CollectAllZoneServer) vs other number formatters in UI modules.

#### Selene warnings left
- WaterFX: 2x incorrect_standard_library_use on `Vector3.yAxis:Cross` — false positive (comment added).
- MusicSettings: 1x roblox_manual_fromscale_or_fromoffset (UDim2.new) — style only, would change bytecode.
- HalloweenSwitch: 2x deprecated (Instance.new parent arg) + 1x empty_loop (side-effect loop kept).
- Animate: 2x deprecated `:connect` on script.ChildAdded/Removed, 1x unused `findExistingAnimationInSet`, 1x unused `configureAnimationSetOld` — global functions of the upstream script; renaming globals would change bytecode.


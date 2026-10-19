# Hatch an Anime: Refactor Report

Date: 2026-10-19

A full copy of the pre-refactor repository is at `../StealAGhost_Rojo_BACKUP_2026-10-19/`. `result.rbxl` is unchanged (MD5 verified).

## What changed

| Change | Files | Runtime effect |
|---|---|---|
| Sources regrouped by feature (`src/client|server|shared/<Feature>/`) | 189 live/dev files | none: only `$path` values changed |
| `_ARCHIVE` and `ServerStorage` backup folders moved to `archive/` | 606 files | none: still mapped to the same `ServerStorage` paths |
| 4 identical `HatchGoo` copies merged into `src/server/Hatching/Templates/HatchGoo.server.luau` | -3 files | none: all four nodes point at the one file, so the same Source is built |
| `"$properties": { "Disabled": true }` restored on 153 nodes | `default.project.json` | **restores the original place behaviour**. Before this, Rojo built these scripts *enabled*. |
| Project name `StealAGhostScripts` → `HatchAnAnime` | `default.project.json` | display name only |
| `script-manifest.json`: `path` updated, `exportPath` added | | none |
| New docs: `docs/*.md` and `docs/script-moves.json`; new `.gitignore` and `.stylua.toml`; README rewritten | | none |

**No `.luau` source was edited.** Every moved file is byte-identical to its pre-refactor original.

## How equivalence was verified (static only)

1. `rojo build` of the **original** project into `baseline.rbxlx`, then of the **refactored** project into `after.rbxlx`.
2. Both XML files were parsed and every instance was listed as `runtime path | class | properties`, with `Source` reduced to an MD5 hash.
3. Result:
   - 1004 instances in each build.
   - 0 runtime paths added or removed.
   - 0 differences in class, `Source` or `RunContext`.
   - Exactly 153 instances differ, and **only** by `Disabled=true`. All 153 are marked `disabled: true` in `script-manifest.json`.
4. MD5 of each of the 798 sources in the backup equals the MD5 of its new file.
5. All 798 manifest `path` entries exist.

This proves the Rojo output is the same as before, apart from the restored Disabled flags. It does **not** prove gameplay equivalence of a live place: no play-test was run, by instruction. See *Remaining risks*.

## What was deliberately NOT done

The brief forbids changing behaviour that static analysis cannot prove safe, so the following were documented instead of changed:

- **Bug and security fixes** found in the audit ([PROJECT_AUDIT.md §3.2](PROJECT_AUDIT.md)). All of them alter runtime behaviour: the StaffServer TeleportData trust, the item duplication on restore, the GoHome cooldown, `Temple_Retiring`, and the shop cash overwrite.
- **Splitting oversized scripts** (MenuLogic, GameHUD, InventoryView, …). These are large closures over shared local state, and splitting them without play-testing is not provably safe.
- **Merging number formatters.** The implementations produce different strings (truncate vs round, different suffix sets), so merging them would visibly change the UI.
- **Moving scripts to other runtime locations**, renaming instances, remotes or DataStores.
- **Running StyLua.** Reformatting all sources would hide real diffs and cannot be checked without tooling. `.stylua.toml` is provided for new code. *(Superseded 2026-10-19: all sources are now formatted with StyLua, AST-verified — see [FULL_REFACTOR_REPORT.md](FULL_REFACTOR_REPORT.md).)*
- **Deleting archives, dead code, or the 0-byte `EggLabelsClient`.** Kept, because a 0-byte LocalScript is harmless and removing it changes the place tree.

## Remaining risks

| Risk | Mitigation |
|---|---|
| A live `rojo serve` into a place that was edited after `result.rbxl` was exported could overwrite newer Studio-side script edits. | Sync into a copy first. Review the plugin's change list. |
| `rojo build` output lacks place-owned instances and properties (`ResetOnSpawn`, models, remotes). | Only use live sync into the real place. Never publish a build-only place. |
| Restoring `Disabled` changes the Rojo result compared with the previous project. If someone had relied on Rojo enabling, for example, `EggStealServer`, it is now off again (as in the original place). | Intended. To enable a script, remove its `$properties` entry. |
| One file backs four `HatchGoo` nodes. An edit meant for a single template now affects all four. | Documented in ROJO_SETUP.md. Split it back into separate files if the templates need to diverge. |
| The truncated brief: sections after "5. Rojo Mapping Refactor" were not provided. | Sections 1–5 and the listed docs are covered. |

## Next steps (recommended order, each needs a play-test in a copy)

1. StaffServer: replace the TeleportData check with a reserved-server check.
2. PlayerData restore ordering, and the ShopService cash overwrite plus stale autosave.
3. GoHome cooldown and carry check, and renaming `Temple_Retiring` back to `Temple` after an upgrade.
4. Move owner-only trailer tools out of `StarterPlayerScripts`.
5. Initialise git (`git init`) and commit this state, so future refactors are reviewable as diffs.

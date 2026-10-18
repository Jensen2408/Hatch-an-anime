# StealAGhost — Rojo (client/server/shared)

Script-only export from `result.rbxl` with 798 original script files.

## Structure

```
src/
  client/  # ReplicatedFirst, StarterPlayer, StarterGui, Workspace
  server/  # ServerScriptService, ServerStorage
  shared/  # ReplicatedStorage
```

**Important:** Service directory names are preserved inside `client`, `server` and `shared` so that the `default.project.json` mapping points at the **original Roblox Explorer positions**, including descendants. This is a *filesystem reorganization*, not a relocation of script instances into new Roblox services.

Current counts: client 64; server 684; shared 50.

## Safety

- Exactly 798 exported sources; 739 mapped uniquely, 59 with ambiguous Explorer ancestry remain **not mapped** (but their source files are included).
- Never connect this project to a live place without reviewing changes in a copy. Existing models, map, UI and non-script objects are intended to remain managed by Studio, but Rojo mapping mistakes can cause replacements.
- All script source bytes are unchanged. Metadata such as `Disabled` and `RunContext` may need manual checking.
- The original place is included as `result.rbxl`.
- Check `script-manifest.json` for `originalPath`, `path`, `class`, and other original metadata.

## Run

Open this folder in VS Code, install Rojo CLI + Studio plugin, then run:

```sh
rojo serve
```

Connect only to a *duplicate* of the Roblox place while verifying the mapping.

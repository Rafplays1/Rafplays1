# Trap a Legend

Co-op creature hunt for Roblox. The code lives in this folder and is synced into
Roblox Studio with **Rojo**. You edit files in VS Code, and they appear in Studio.

## One-time setup

1. **Check what you have.** Open a terminal (in VS Code: `Terminal > New Terminal`) and run:
   ```
   git --version
   code --version
   rojo --version
   ```
   Any line that says "not found" means that tool is missing.
   - Roblox Studio: https://create.roblox.com
   - VS Code: https://code.visualstudio.com
   - Git: https://git-scm.com/downloads
2. **Install Rojo** with Rokit (a tool installer): follow the install line at
   https://github.com/rojo-rbx/rokit, restart the terminal, then in this folder run:
   ```
   rokit install
   rojo plugin install
   ```
   The second command adds the Rojo plugin to Roblox Studio.
3. **VS Code extension (recommended):** install "Luau Language Server" (by JohnnyMorganz)
   for autocomplete and error underlines.

## Every time you work

1. In the terminal, in this folder: `rojo serve`  (leave it running)
2. Open Roblox Studio, open a **Baseplate** place.
3. In Studio: `Plugins` tab > `Rojo` > `Connect`.
4. Press **Play** (F5).

Save your place to Roblox once (`File > Publish to Roblox`) so you can reopen the same place.

## Where each file ends up in Studio

Rojo does this for you. You never copy files by hand.

| File on disk                           | In Studio's Explorer                                       | Kind         |
| -------------------------------------- | ---------------------------------------------------------- | ------------ |
| `src/shared/Config.luau`               | ReplicatedStorage > Shared > Config                        | ModuleScript |
| `src/shared/Remotes.luau`              | ReplicatedStorage > Shared > Remotes                       | ModuleScript |
| `src/server/Main.server.luau`          | ServerScriptService > Server > Main                        | Script       |
| `src/server/Ragdoll.luau`              | ServerScriptService > Server > Ragdoll                     | ModuleScript |
| `src/server/LegendRegistry.luau`       | ServerScriptService > Server > LegendRegistry              | ModuleScript |
| `src/server/Legends/Mossback.luau`     | ServerScriptService > Server > Legends > Mossback          | ModuleScript |
| `src/server/Legends/MossbackModel.luau`| ServerScriptService > Server > Legends > MossbackModel     | ModuleScript |
| `src/server/Traps/LogSwing.luau`       | ServerScriptService > Server > Traps > LogSwing            | ModuleScript |
| `src/server/World/TestArena.luau`      | ServerScriptService > Server > World > TestArena           | ModuleScript |
| `src/client/Main.client.luau`          | StarterPlayer > StarterPlayerScripts > Client > Main       | LocalScript  |

File name rules: `.server.luau` = Script (runs on the server), `.client.luau` =
LocalScript (runs on each player's device), plain `.luau` = ModuleScript (code
other scripts load with `require`).

## Tuning

Every number worth tweaking (speeds, timings, knockback) is in `src/shared/Config.luau`.

## Status

Phase 1, step 1: Mossback chase + Antler Charge, Log Swing trap, ragdoll.
The Mossback and the arena are placeholder blocks built by script.

-- Server entry point. This is the only Script on the server; everything else
-- is a ModuleScript that this file (or another module) loads with require().
--
-- Phase 1, step 1: a test arena, one Log Swing trap and one Mossback.

local LogSwing = require(script.Parent.Traps.LogSwing)
local Mossback = require(script.Parent.Legends.Mossback)
local TestArena = require(script.Parent.World.TestArena)

local arena = TestArena.build()

LogSwing.new(arena.trapCFrame)
Mossback.new(arena.legendSpawn, arena.legendFacing)

print("[Trap a Legend] Test arena ready. Mossback is hunting!")

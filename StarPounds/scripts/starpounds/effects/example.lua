-- Sets up the effect object, a data table, and placeholder functions for those below.
-- Adding blank functions is unnecessary unless you need the functionality.
-- Data table contains a reference to the effect's duration/level, and can be used for persistent storage.
local example = starPounds.effect:new()
example.data.something = "example"
-- Runs when the entity with the effect loads, or enables the mod.
function example:init()
  sb.logInfo("Example: init")
  example.data.somethingElse = "example"
end
-- Runs every effect update tick. (Delta is the effectTimer value in /scripts/starpounds/starpounds.config)
function example:update(dt)
  sb.logInfo("Example: update ("..sb.print(dt)..")")
end
-- Runs when the entity with the effect unloads, or disables the mod.
function example:uninit()
  sb.logInfo("Example: uninit")
end
-- Runs when the effect is applied, or increases in level.
function example:apply()
  sb.logInfo("Example: apply")
end
-- Runs when the effect expires, or otherwise gets removed.
function example:expire()
  sb.logInfo("Example: expire")
end
-- Add the effect.
starPounds.scriptedEffects.example = example

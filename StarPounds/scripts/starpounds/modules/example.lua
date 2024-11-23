-- Sets up the module object, a data table, and placeholder functions for those below.
-- Adding blank functions is unnecessary unless you need the functionality.
-- example.module holds data for the dynamic update stuff, don't (or do?) mess with it.
local example = starPounds.module:new("example")
-- Runs when the entity loads, or enables the mod.
function example:init()
  sb.logInfo("Example: init")
  -- Data table is just the contents of the module's config file. (/starpounds/effects/modules/example.lua)
  sb.logInfo(example.data.randomConfigLink)
  sb.logInfo(example.data.randomConfigPassword)
end
-- Update loop. Change the delta with self:setUpdateDelta(frames)
function example:update(dt)
  sb.logInfo("Example: update ("..sb.print(dt)..")")
end
-- Runs when the entity unloads, or disables the mod.
function example:uninit()
  sb.logInfo("Example: uninit")
end
-- Add the module.
starPounds.modules.example = example

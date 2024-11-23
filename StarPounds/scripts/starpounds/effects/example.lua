-- Effects are almost identical to modules (/scripts/starpounds/modules/example.lua), with a few exceptions:
--  Effects don't have config files, instead use starPounds.effects.example to get the effect's config.
--  Data table is persistent across loads, and gets baked into the save until the effect expires.
--  Data table contains direct references to effect's duration and level. Editing these to change it.
--  Additional functions for when the effect is applied (or reapplied), and expires (or gets removed).
local example = starPounds.effect:new()
example.data.something = "I'm persistent across reloads!"
-- Runs when the effect is applied, or increases in level.
function example:apply()
  sb.logInfo("Example: apply")
end
-- Runs when the effect expires, or otherwise gets removed.
function example:expire()
  sb.logInfo("Example: expire")
  -- Doesn't trigger when effects expire by default. Just call it here if you want it to.
  self:uninit()
end
-- Add the effect.
starPounds.scriptedEffects.example = example

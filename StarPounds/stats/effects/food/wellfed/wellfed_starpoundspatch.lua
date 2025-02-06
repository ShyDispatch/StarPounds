local init_old = init or function() end
local update_old = update or function() end

function init()
  init_old()
  -- Cross script stuff.
  starPounds = getmetatable ''.starPounds
  starPoundsEnabled = starPounds and starPounds.isEnabled()
  -- Turn off the particles if the mod is running.
  animator.setParticleEmitterActive("healing", config.getParameter("particles", not starPoundsEnabled))
end


function update(dt)
  -- Remove the effect if we toggle.
  if starPoundsEnabled ~= (starPounds and starPounds.isEnabled()) then
    effect.expire()
    return
  end
  -- Remove the effect if the player falls under the wellfed threshold.
  if starPoundsEnabled then
    local threshold = starPounds.hasSkill("wellfedProtection") and starPounds.settings.thresholds.strain.starpoundsstomach3 or starPounds.settings.thresholds.strain.starpoundsstomach
    if starPounds.stomach.fullness < threshold then
      effect.expire()
      return
    end
  end
  -- Run old stuff if the mod isn't enabled.
  if not starPoundsEnabled then
    update_old(dt)
  end
end

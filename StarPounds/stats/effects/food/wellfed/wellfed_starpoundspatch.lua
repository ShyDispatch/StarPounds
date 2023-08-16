local init_old = init or function() end
local update_old = update or function() end

function init()
  starPounds = getmetatable ''.starPounds
  starPoundsEnabled = starPounds and starPounds.isEnabled()
  doHealing = not starPoundsEnabled
  init_old()
end


function update(dt)
  starPounds = getmetatable ''.starPounds
  starPoundsEnabled = starPounds and starPounds.isEnabled()

  local threshold = starPounds.hasSkill("wellfedProtection") and starPounds.settings.threshholds.strain.starpoundsstomach3 or starPounds.settings.threshholds.strain.starpoundsstomach
  if starPoundsEnabled and starPounds.stomach.interpolatedFullness < threshold then
    if doHealing then
      status.addEphemeralEffect("starpoundswellfed", effect.duration())
    end
    effect.expire()
    return
  end

  if not doHealing and not starPoundsEnabled then
    effect.expire()
    return
  end

  if not starPoundsEnabled or status.uniqueStatusEffectActive("starpoundswellfed") then
    doHealing = true
    status.removeEphemeralEffect("starpoundswellfed")
  end

  if doHealing then
    update_old(dt)
  end
  animator.setParticleEmitterActive("healing", config.getParameter("particles", doHealing))

  doHealing = not starPoundsEnabled or doHealing or ((starPoundsEnabled and starPounds.stomach.food > 0) and status.resource("food") >= (status.resourceMax("food") + status.stat("foodDelta")))
end

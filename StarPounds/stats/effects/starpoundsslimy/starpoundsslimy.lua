function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = config.getParameter("powerModifier", 1)}})
  local color = config.getParameter("color")
  if color then
    effect.setParentDirectives("fade="..config.getParameter("color").."=0.5")
  end
end

function update(dt)
  mcontroller.controlModifiers(config.getParameter("controlModifiers", {}))
end

function uninit()

end

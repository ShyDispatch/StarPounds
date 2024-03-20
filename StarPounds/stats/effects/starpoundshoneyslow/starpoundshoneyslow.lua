function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  local color = config.getParameter("color")
  if color then
    effect.setParentDirectives("fade="..config.getParameter("color").."=0.25")
  end
end

function update(dt)
  mcontroller.controlModifiers({
    groundMovementModifier = 0.45,
    airJumpModifier = 0.4,
    speedModifier = 0.40
  })
end

function uninit()

end

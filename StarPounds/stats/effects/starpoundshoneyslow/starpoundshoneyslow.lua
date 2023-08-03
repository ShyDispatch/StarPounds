function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
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

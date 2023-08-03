function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
end

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.75,
	  airJumpModifier = 0.7,	  
      speedModifier = 0.70
    })
end

function uninit()
  
end

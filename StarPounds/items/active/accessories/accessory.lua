require "/scripts/vec2.lua"

function init()
  self.accessoryType = config.getParameter("accessoryType")
  updateAim()
end

function update(dt, fireMode, shiftHeld)
  updateAim()
end

function activate(fireMode, shiftHeld)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    local currentAccessory = starPounds.getAccessory(self.accessoryType)
    if currentAccessory then
      player.giveItem(currentAccessory)
    end
    starPounds.setAccessory(player[activeItem.hand().."HandItem"](), self.accessoryType)
    if starPounds.accessoryChanged then
      starPounds.accessoryChanged(self.accessoryType)
    end
    item.consume(1)
    animator.playSound("activate")
    animator.burstParticleEmitter("activate")
    animator.translateTransformationGroup("emitter", vec2.mul(activeItem.handPosition(), {self.aimDirection * -1, -1}))
    animator.rotateTransformationGroup("emitter", -self.aimAngle)
    animator.setParticleEmitterOffsetRegion("activate", mcontroller.boundBox())
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

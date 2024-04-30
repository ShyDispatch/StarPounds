require "/scripts/vec2.lua"

function init()
  animator.resetTransformationGroup("pda")
  animator.scaleTransformationGroup("pda", config.getParameter("scale", 1))
  armAngle = config.getParameter("armAngle", 0) * math.pi/180
  animator.rotateTransformationGroup("pda", -armAngle)
  activeItem.setArmAngle(armAngle)
  message.setHandler("starPounds.holdingPizzaPda", function() return true end)
end

function activate(fireMode, shiftHeld)
  player.interact("ScriptPane", { gui = { }, scripts = {"/metagui.lua"}, ui = "starpounds:pizzamenu" })
  animator.playSound("use")
end

function update(dt, fireMode, shiftHeld)
  updateAim()
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  self.aimAngle = self.aimAngle + armAngle
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function holdingItem()
  return true
end

function recoil()
  return false
end

function outsideOfHand()
  return false
end

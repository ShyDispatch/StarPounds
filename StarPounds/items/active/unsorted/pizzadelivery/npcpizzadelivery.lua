require "/scripts/vec2.lua"

function init()
  animator.resetTransformationGroup("box")
  animator.scaleTransformationGroup("box", config.getParameter("scale", 1))
  local armAngle = config.getParameter("armAngle", 0) * math.pi/180
  animator.rotateTransformationGroup("box", -armAngle)
  activeItem.setArmAngle(armAngle)
end

function activate(fireMode, shiftHeld)
  animator.playSound("eat")
  activeItem.emote("eat")
  item.consume(1)
  if world.entityType(activeItem.ownerEntityId()) == "npc" then
    world.callScriptedEntity(activeItem.ownerEntityId(), "npc.endPrimaryFire")
    world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.deletePizzaItem")
  end
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

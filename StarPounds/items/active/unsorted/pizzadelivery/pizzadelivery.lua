require "/scripts/vec2.lua"

function init()
  animator.resetTransformationGroup("box")
  animator.scaleTransformationGroup("box", config.getParameter("scale", 1))
  local armAngle = config.getParameter("armAngle", 0) * math.pi/180
  animator.rotateTransformationGroup("box", -armAngle)
  activeItem.setArmAngle(armAngle)

end

function activate(fireMode, shiftHeld)
  item.consume(1)
  if player then
      for itemName, itemQuantity in pairs(config.getParameter("order", {})) do
        local maxStack = root.createItem({name = itemName, count = itemQuantity, parameters = {}}).count
        local remainingQuantity = itemQuantity
        while remainingQuantity > 0 do
          local count = math.min(itemQuantity, maxStack)
          player.giveItem({name = itemName, count = count, parameters = {}})
          remainingQuantity = remainingQuantity - count
        end
      end
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

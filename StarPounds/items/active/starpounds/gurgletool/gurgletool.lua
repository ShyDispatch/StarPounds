function init()
	activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
	world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.playSound", "digest", 0.60, 3)
end

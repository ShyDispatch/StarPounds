function init()
	activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
	world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.playSound", "digest", shiftHeld and 0.75 or 0.60, shiftHeld and 1 or 3)
end

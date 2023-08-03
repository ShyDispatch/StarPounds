require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

function init()
	range = config.getParameter("range", 3)
	querySize = config.getParameter("querySize", 0.5)
	activeItem.setHoldingItem(false)
	activeItem.setCursor("/cursors/starpoundsvore.cursor")
	script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 5)
end

function activate(fireMode, shiftHeld)
	if shiftHeld then
		world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.releaseEntity")
	else
		local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
		local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
		local aimPosition = activeItem.ownerAimPosition()
		local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
		local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
		world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.eatNearbyEntity", targetPosition, range, querySize)
	end
end

function update(dt)
	promises:update()
	local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
	local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
	local aimPosition = activeItem.ownerAimPosition()
	local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
	local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
	promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.eatNearbyEntity", targetPosition, range, querySize, nil, true), function(valid)
		activeItem.setCursor((valid and valid[1]) and (valid[2] and "/cursors/starpoundsvorevalid.cursor" or "/cursors/starpoundsvorenearby.cursor") or "/cursors/starpoundsvore.cursor")
	end)
end

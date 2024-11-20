require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

function init()
	range = config.getParameter("range", 3)
	querySize = config.getParameter("querySize", 0.5)
	activeItem.setHoldingItem(false)
	script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 1)
	tickDelta = 5
	cooldownTime = root.assetJson("/scripts/starpounds/starpounds.config:settings.voreCooldown")
	cooldown = cooldownTime
	cooldownStat = 1
	cooldownFrames = 8
	canRelease = false
	cursorType = "pred"
	updateCursor()

	crouching = mcontroller.crouching()
	facing = mcontroller.facingDirection()
end

function activate(fireMode, shiftHeld)
	if shiftHeld then
		world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.releaseEntity")
	elseif cooldown == 0 then
		local mouthOffset = {0.375 * facing * (crouching and 1.5 or 1), crouching and -1 or 0}
		local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
		local aimPosition = activeItem.ownerAimPosition()
		local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
		local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
		promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.eatNearbyEntity", targetPosition, range, querySize), function(valid)
			if (valid and valid[1]) then
				cooldown = cooldownTime
			end
		end)
	end
end

function update(dt, _, shiftHeld)
	promises:update()
	tickCounter = math.max((tickCounter or 0) - 1, 0)
	cooldown = math.max((cooldown or cooldownTime) - (dt/cooldownStat), 0)
	if tickCounter == 0 then
		crouching = mcontroller.crouching()
		facing = mcontroller.facingDirection()
		local mouthOffset = {0.375 * facing * (crouching and 1.5 or 1), crouching and -1 or 0}
		local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
		local aimPosition = activeItem.ownerAimPosition()
		local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
		local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
		-- Vore icon updater.
		promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.eatNearbyEntity", targetPosition, range, querySize, nil, true), function(valid)
			cursorType = (valid and valid[1]) and (valid[2] and "pred_valid" or "pred_nearby") or "pred"
		end)
		-- Stomach icon updater.
		promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.getData", "stomachEntities"), function(entities)
			canRelease = false
			for preyIndex = #entities, 1, -1 do
				local prey = entities[preyIndex]
				if not prey.noRelease then canRelease = true end
			end
		end)
		-- Vore cooldown stat checker.
		promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.getStat", "voreCooldown"), function(amount)
			cooldownStat = amount
		end)
		tickCounter = tickDelta
	end
	updateCursor(shiftHeld)
end

function updateCursor(shiftHeld)
	if shiftHeld then
		activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:release%s", canRelease and "_valid" or ""))
	else
		local readyPercent = 1 - (cooldown/cooldownTime)
		local frame = "_"..math.min(math.floor(readyPercent * (cooldownFrames)), cooldownFrames - 1)
		activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", cursorType, cooldown > 0 and frame or ""))
	end
end

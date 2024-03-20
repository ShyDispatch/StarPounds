require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
	range = config.getParameter("range", 3)
	querySize = config.getParameter("querySize", 1)
	activeItem.setHoldingItem(false)
	activeItem.setCursor("/cursors/starpoundsvoreprey.cursor")
	script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 5)
	settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")
end

function update(dt)
	local starPounds = getmetatable ''.starPounds
	local validTarget = false
	if starPounds and starPounds.isEnabled() and not starPounds.hasOption("disablePrey") then
		position = activeItem.ownerAimPosition()
		local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
		local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
		local aimPosition = activeItem.ownerAimPosition()
		local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
		local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
		local entities = world.entityQuery(targetPosition, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or jarray()
		for _, target in ipairs(entities) do
			if isTargetValid(target) then
				validTarget = true
				break
			end
		end
	end
	activeItem.setCursor(validTarget and "/cursors/starpoundsvorepreyvalid.cursor" or "/cursors/starpoundsvoreprey.cursor")
end

function activate(fireMode, shiftHeld)
	local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
	local mouthPosition = vec2.add(world.entityMouthPosition(activeItem.ownerEntityId()), mouthOffset)
	local aimPosition = activeItem.ownerAimPosition()
	local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize)
	local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
	local entities = world.entityQuery(targetPosition, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or jarray()
	for _, target in ipairs(entities) do
		if isTargetValid(target) then
			world.sendEntityMessage(target, "starPounds.eatEntity", activeItem.ownerEntityId(), true)
			return
		end
	end
end

function isTargetValid(target)
	local targetType = world.entityTypeName(target)
	if world.entityType(target) == "monster" then
		local scriptCheck = contains(root.monsterParameters(targetType).scripts or jarray(), "/scripts/starpounds/starpounds_monster.lua")
		local parameters = root.monsterParameters(targetType)
		local behaviorCheck = parameters.behavior and contains(settings.monsterBehaviors, parameters.behavior) or false
		if parameters.starPounds_options and parameters.starPounds_options.disablePred then return false end
		if not (scriptCheck or behaviorCheck) then
			return false
		end
	end
	if world.entityType(target) == "npc" then
		if not contains(root.npcConfig(targetType).scripts or jarray(), "/scripts/starpounds/starpounds_npc.lua") then return false end
		if world.getNpcScriptParameter(target, "starPounds_options", jarray()).disablePred then return false end
	end
	return not world.lineTileCollision(world.entityMouthPosition(target), world.entityPosition(activeItem.ownerEntityId()), {"Null", "Block", "Dynamic", "Slippery"})
end

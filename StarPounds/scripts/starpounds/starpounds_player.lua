require "/scripts/rect.lua"
-- Dummy empty function so we save memory.
local function nullFunction()
end
-- Run on load.
function init()
	-- Load StarPounds.
	require "/scripts/starpounds/starpounds.lua"
	-- Radio message if we have QuickbarMini instead (or with) StardustLite.
	local mmconfig = root.assetJson("/interface/scripted/mmupgrade/mmupgradegui.config")
	if mmconfig.replaced and not pcall(root.assetJson, "/metagui/registry.json") then
		player.radioMessage("starpounds_quickbar")
	elseif not mmconfig.replaced then
		player.radioMessage("starpounds_stardust")
	end
	-- Grab or create the data.
	local loadBackup = not storage.starPounds
	storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
	getmetatable ''.starPounds = starPounds
	starPounds.type = "player"

	if loadBackup then
		 storage.starPounds = sb.jsonMerge(storage.starPounds, player.getProperty("starPoundsBackup", {}))
	end
	-- Override functions for script compatibility on different entities.
	makeOverrideFunction()
	starPounds.overrides()
	-- Setup message handlers
	starPounds.messageHandlers()
	-- Reload whenever the entity loads in/beams/etc.
	starPounds.statCache = {}
	starPounds.parseSkills()
	starPounds.accessoryModifiers = starPounds.getAccessoryModfiers()
	starPounds.parseEffectStats(1)
	starPounds.stomach = starPounds.getStomach()
	starPounds.breasts = starPounds.getBreasts()
	starPounds.setWeight(storage.starPounds.weight)
	starPounds.damageHitboxTiles = damageHitboxTiles
	-- Damage listener for fall/fire damage.
	starPounds.damageListener = damageListener("damageTaken", function(notifications)
		for _, notification in pairs(notifications) do
			if notification.sourceEntityId == entity.id() and notification.targetEntityId == entity.id() then
				if notification.damageSourceKind == "falling" and starPounds.currentSizeIndex > 1 then
					-- "explosive" damage (ignores tilemods) to blocks is reduced by 80%, for a total of 5% damage applied to blocks. (Isn't reduced by the fall damage skill)
					local baseDamage = (notification.damageDealt)/(1 + starPounds.currentSize.healthBonus * (1 - starPounds.getStat("fallDamageReduction")))
					local	tileDamage = baseDamage * (1 + starPounds.currentSize.healthBonus) * 0.25
					starPounds.damageHitboxTiles(tileDamage)
					break
				end
				if starPounds.currentSizeIndex > 1 and string.find(notification.damageSourceKind, "fire") and starPounds.getStat("firePenalty") > 0 then
					local percentLost = math.round(notification.healthLost/status.resourceMax("health"), 2)
					percentLost = 2 * percentLost * starPounds.getStat("firePenalty") * (starPounds.currentSizeIndex - 1)/(#starPounds.sizes - 1)

					if percentLost > 0.01 then
						status.overConsumeResource("energy", status.resourceMax("energy") * percentLost)
						status.addEphemeralEffect("sweat")
					end
				end
			end
		end
	end)
end

function update(dt)
-- Holy shit why can we not detect what gamemode the player is using.
	if starPounds.hasOption("disableHunger") then
		status.setResourcePercentage("food", 1)
	end
	-- Check promises.
	promises:update()
	-- Reset stat cache.
	starPounds.statCache = {}
	-- Update fall damage listener.
	starPounds.damageListener:update()
	-- Check if the entity has gone up a size.
	starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
	starPounds.stomach = starPounds.getStomach()
	starPounds.breasts = starPounds.getBreasts()
	starPounds.currentVariant = starPounds.getChestVariant(modifierSize or starPounds.currentSize)
	starPounds.weight = storage.starPounds.weight
	starPounds.level = storage.starPounds.level
	starPounds.experience = storage.starPounds.experience
	starPounds.weightMultiplier = storage.starPounds.enabled and math.round(1 + (storage.starPounds.weight/(entity.weight + entity.bloat)), 1) or 1

	local doBlobProjectile = false
	local blobProjectileActive = starPounds.blobProjectile and world.entityExists(starPounds.blobProjectile)
	if storage.starPounds.enabled then
		starPounds.damageListener:update()
		if starPounds.currentSize.isBlob then
			-- Automatically open doors in front/close doors behind since blob's cant reach to interact.
			if not starPounds.hasOption("disableBlobDoors") then
				useDoors()
			end
			-- Spawn blob projectile.
			doBlobProjectile = status.stat("activeMovementAbilities") < 1 and not starPounds.hasOption("disableBlobCollision")
			if doBlobProjectile and not blobProjectileActive then
				starPounds.blobProjectile = world.spawnProjectile("starpoundsblobhitbox", mcontroller.position(), entity.id(), {0, 0}, true)
			end
		end
	end
	-- Kill the blob projectile if we don't need it.
	if blobProjectileActive and not doBlobProjectile then
		world.callScriptedEntity(starPounds.blobProjectile, "projectile.die")
		starPounds.blobProjectile = nil
	end

	local currentSizeWeight = starPounds.currentSize.weight
	local nextSizeWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
	if nextSizeWeight ~= starPounds.settings.maxWeight and starPounds.sizes[starPounds.currentSizeIndex + 1].isBlob and starPounds.hasOption("disableBlob") then
		nextSizeWeight = starPounds.settings.maxWeight
	end

	-- Cross script voodoo witch magic.
	getmetatable ''.starPounds.progress = math.round((storage.starPounds.weight - currentSizeWeight)/(nextSizeWeight - currentSizeWeight) * 100)
	getmetatable ''.starPounds.weight = storage.starPounds.weight
	getmetatable ''.starPounds.enabled = storage.starPounds.enabled
	starPounds.swapSlotItem = player.swapSlotItem()
	if starPounds.swapSlotItem and root.itemType(starPounds.swapSlotItem.name) == "consumable" then
		local replaceItem = starPounds.updateFoodItem(starPounds.swapSlotItem)
		if replaceItem then
			player.setSwapSlotItem(replaceItem)
		end
	end

	if starPounds.currentSize.size ~= (oldSize and oldSize.size or nil) then
		-- Force stat update.
		starPounds.updateStats(true)
		-- Update status effect trackers.
		starPounds.createStatuses("starpoundsstomach")
		-- Don't play the sound on the first load.
		if oldSize then
			-- Play sound to indicate size change.
			world.sendEntityMessage(entity.id(), "starPounds.playSound", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
		end
	end
	-- Checks
	starPounds.voreCheck()
	starPounds.equipCheck(starPounds.currentSize, {
		chestVariant = starPounds.currentVariant,
		chestSize = storage.starPounds.enabled and (starPounds.hasOption("extraTopHeavy") and 2 or (starPounds.hasOption("topHeavy") and 1 or nil) or nil),
		legsSize = storage.starPounds.enabled and (starPounds.hasOption("extraBottomHeavy") and 2 or (starPounds.hasOption("bottomHeavy") and 1 or nil) or nil)
	})
	-- Actions.
	starPounds.eaten(dt)
	starPounds.digest(dt)
	starPounds.exercise(dt)
	starPounds.drink(dt)
	starPounds.lactating(dt)
	-- Stat/status updating stuff.
	starPounds.hunger(dt)
	starPounds.parseEffectStats(dt)
	starPounds.updateStatuses()
	starPounds.updateStats(starPounds.optionChanged)
	-- Save for comparison later.
	oldSize = starPounds.currentSize
	oldVariant = starPounds.currentVariant
	oldWeightMultiplier = starPounds.weightMultiplier

	if storage.starPounds.enabled then
		if starPounds.stomach.contents > storage.starPounds.stomachLerp and (starPounds.stomach.contents - storage.starPounds.stomachLerp) > 1 then
			storage.starPounds.stomachLerp = math.round(util.lerp(5 * dt, storage.starPounds.stomachLerp, starPounds.stomach.contents), 4)
		else
			storage.starPounds.stomachLerp = math.round(util.lerp(10 * dt, storage.starPounds.stomachLerp, starPounds.stomach.contents), 4)
		end
		if math.abs(starPounds.stomach.contents - storage.starPounds.stomachLerp) < 1 then
			storage.starPounds.stomachLerp = starPounds.stomach.contents
		end
	end

	starPounds.optionChanged = false
	if starPounds.hasOption("showDebug") then
		starPounds.debug("experience", storage.starPounds.enabled and string.format("^#665599;Level:^gray; %s ^#665599;Experience:^gray; %.0f/%.0f ^#665599;Multiplier:^gray; %s", storage.starPounds.level, storage.starPounds.experience, starPounds.settings.experienceAmount * (1 + storage.starPounds.level * starPounds.settings.experienceIncrement), starPounds.getStat("experienceMultiplier")) or "^gray;Mod disabled")
		starPounds.debug("stomach", storage.starPounds.enabled and string.format("^#665599;Capacity:^gray; %.1f/%.1f ^#665599;Food:^gray; %.1f ^#665599;Bloat:^gray; %.1f ^#665599;Entity:^gray; %.1f", starPounds.stomach.contents, starPounds.stomach.capacity, starPounds.stomach.food, starPounds.stomach.bloat, starPounds.stomach.contents - (starPounds.stomach.food + starPounds.stomach.bloat)) or "^gray;Mod disabled")
		starPounds.debug("breasts", storage.starPounds.enabled and string.format("^#665599;Type:^gray; %s ^#665599;Capacity:^gray; %.1f/%.1f ^#665599;Contents:^gray; %.1f", starPounds.breasts.type, starPounds.breasts.contents, starPounds.breasts.capacity, storage.starPounds.breasts) or "^gray;Mod disabled")
		starPounds.debug("size", storage.starPounds.enabled and string.format("^#665599;Size:^gray; %s ^#665599;Weight:^gray; %.2flb ^#665599;Multiplier:^gray; %.1fx", (starPounds.currentSize.size == "" and "none" or starPounds.currentSize.size)..(starPounds.currentVariant and " + "..starPounds.currentVariant or ""), storage.starPounds.weight, starPounds.weightMultiplier) or "^gray;Mod disabled")
		starPounds.debug("timers", storage.starPounds.enabled and string.format("^#665599;Gurgle:^gray; %.1f ^#665599;Rumble:^gray; %.1f ^#665599;Effect Update:^gray; %.1f", starPounds.gurgleTimer or 0, starPounds.rumbleTimer or 0, starPounds.statusEffectModifierTimer or 0) or "^gray;Mod disabled")
	end
end

function uninit()
	starPounds.releaseEntity(nil, true)
	starPounds.backup()
end

function damageHitboxTiles(tileDamage)
	if starPounds.hasOption("disableTileDamage") then return end
	local lowDamageTiles = {}
	local highDamageTiles = {}
	local groundLevel = 0
	local height = 0
	local width = {0, 0}
	local position = mcontroller.position()
	-- Calculate height, groundLevel, and width.
	for _, v in ipairs(mcontroller.collisionPoly()) do
		height = math.max(height, v[2])
		groundLevel = math.min(groundLevel, v[2])
		width[1] = math.min(width[1], v[1])
		width[2] = math.max(width[2], v[1])
	end
	-- Create tile damage polys.
	local lowPoly = {
		vec2.add({width[1] - 1, groundLevel - 0.5}, position),
		vec2.add({width[2] + 1, groundLevel - 0.5}, position),
		vec2.add({math.max(0, width[2] - 1.5), groundLevel - 2.5}, position),
		vec2.add({math.min(0, width[1] + 1.5), groundLevel - 2.5}, position)
	}
	local highPoly = {
		vec2.add({math.min(-0.5, width[1] + 0.5), groundLevel - 0.5}, position),
		vec2.add({math.max(0.5, width[2] - 0.5), groundLevel - 0.5}, position),
		vec2.add({math.max(0, width[2] - 1.5), groundLevel - 1.5}, position),
		vec2.add({math.min(0, width[1] + 1.5), groundLevel - 1.5}, position)
	}
	-- Check if nearby tiles fall in the damage poly.
	local tileQueryRadius = (0.5 * (math.abs(width[1]) + width[2])) - groundLevel + 1
	local foregroundTiles = world.radialTileQuery(position, tileQueryRadius, "foreground")
	for _, tile in pairs(foregroundTiles) do
		if world.polyContains(lowPoly, tile) then
			lowDamageTiles[#lowDamageTiles + 1] = tile
		end
		if world.polyContains(highPoly, tile) then
			highDamageTiles[#highDamageTiles + 1] = tile
		end
	end
	-- Damage valid tiles based on fall damage.
	world.damageTiles(lowDamageTiles, "foreground", position, "explosive", tileDamage * 0.25, 1, entity.id())
	world.damageTiles(highDamageTiles, "foreground", position, "explosive", tileDamage * 0.75, 1, entity.id())
end

function makeOverrideFunction()
  function starPounds.overrides()
    if not starPounds.didOverrides then
			local speciesData = starPounds.getSpeciesData(player.species())
      entity = {
        id = player.id,
        setDropPool = nullFunction,
        setDeathParticleBurst = nullFunction,
        setDeathSound = nullFunction,
        setDamageOnTouch = nullFunction,
        setDamageTeam = nullFunction,
	      weight = math.round(speciesData.weight * speciesData.nutritionRatio),
	      bloat = math.round(speciesData.weight * (1 - speciesData.nutritionRatio)),
	      experience = speciesData.experience
      }
    	if not speciesData.weightGain then
    		message.setHandler("starPounds.feed", simpleHandler(function(amount) status.giveResource("food", amount) end))
    		starPounds.getChestVariant = function() return "" end
    		starPounds.getDirectives = function() return "" end
    		starPounds.getBreasts = function() return {capacity = 10 * starPounds.getStat("breastCapacity"), contents = 0, fullness = 0, type = "milk"} end
    		starPounds.equipSize = nullFunction
    		starPounds.equipCheck = nullFunction
    		starPounds.gainBloat = nullFunction
    		starPounds.gainWeight = nullFunction
    		starPounds.loseWeight = nullFunction
    		starPounds.setWeight = nullFunction
    		starPounds.getSize = function() return starPounds.sizes[1], 1 end
    	end
      -- Only ever run this once per load.
      starPounds.didOverrides = true
    end
  end
end

function useDoors()
  if not (mcontroller.running() or mcontroller.walking()) then
    return
  end

	local playerBounds = rect.pad(mcontroller.boundBox(), {0, -1})
	local playerWidth = math.abs(playerBounds[3] - playerBounds[1]) * 0.5
  local openBounds = rect.translate(playerBounds, mcontroller.position())
  local closeBounds = {table.unpack(openBounds)}

  if mcontroller.movingDirection() > 0 then
		openBounds[1], openBounds[3] = openBounds[3], openBounds[3] + 0.5
    closeBounds[3], closeBounds[1] = closeBounds[1] - 3, closeBounds[1] - 3.5
  else
    openBounds[3], openBounds[1] = openBounds[1], openBounds[1] - 0.5
    closeBounds[1], closeBounds[3] = closeBounds[3] + 3, closeBounds[3] + 3.5
  end

	local function sendDoorMessage(doorId, minimumDistance, message)
    local canInteract = world.isEntityInteractive(doorId)
    local isDoor = contains(world.getObjectParameter(doorId, "scripts", jarray()), "/objects/wired/door/door.lua")
    if canInteract and isDoor then
      local distance = math.floor(math.abs(world.distance(mcontroller.position(), world.entityPosition(doorId))[1]) - playerWidth)
      if not minimumDistance or distance <= minimumDistance then
        world.sendEntityMessage(doorId, message)
      end
    end
  end

  local function queryDoors(bounds, minimumDistance, message)
    local doorIds = world.objectQuery(rect.ll(bounds), rect.ur(bounds))
    for _, doorId in ipairs(doorIds) do
      sendDoorMessage(doorId, minimumDistance, message)
    end
  end

  queryDoors(openBounds, nil, "openDoor")
  queryDoors(closeBounds, 1, "closeDoor")
end

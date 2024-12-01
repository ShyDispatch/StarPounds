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
	-- This is stupid, but prevents 'null' data being saved.
	getmetatable(storage.starPounds).__nils = {}
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
	-- Setup species traits.
	local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
	for _, skill in ipairs(speciesTrait.skills or jarray()) do
		starPounds.forceUnlockSkill(skill[1], skill[2])
	end
	-- Reload whenever the entity loads in/beams/etc.
	starPounds.statCache = {}
	starPounds.statCacheTimer = starPounds.settings.statCacheTimer
	starPounds.parseSkills()
	starPounds.parseStats()
	starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
	starPounds.stomach = starPounds.getStomach()
	starPounds.setWeight(storage.starPounds.weight)
	starPounds.moduleInit(starPounds.type)
	starPounds.effectInit()
	starPounds.damageHitboxTiles = damageHitboxTiles
	-- Damage listener for fall/fire damage.
	starPounds.damageListener = damageListener("damageTaken", function(notifications)
		for _, notification in pairs(notifications) do
			if notification.sourceEntityId == entity.id() and notification.targetEntityId == entity.id() then
				if notification.damageSourceKind == "falling" and starPounds.currentSizeIndex > 1 then
					-- "explosive" damage (ignores tilemods) to blocks is reduced by 80%, for a total of 5% damage applied to blocks. (Isn't reduced by the fall damage skill)
					local baseDamage = (notification.damageDealt)/(1 + starPounds.currentSize.healthBonus * (1 - starPounds.getStat("fallDamageResistance")))
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
	-- Check promises.
	promises:update()
	-- Reset stat cache.
	starPounds.statCacheTimer = math.max(starPounds.statCacheTimer - dt, 0)
	if starPounds.statCacheTimer == 0 then
		starPounds.statCache = {}
		starPounds.statCacheTimer = starPounds.settings.statCacheTimer
	end
	-- Update fall damage listener.
	starPounds.damageListener:update()
	-- Check if the entity has gone up a size.
	starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
	starPounds.stomach = starPounds.getStomach()
	starPounds.currentVariant = starPounds.getChestVariant(modifierSize or starPounds.currentSize)
	starPounds.weight = storage.starPounds.weight
	starPounds.level = storage.starPounds.level
	starPounds.experience = storage.starPounds.experience
	starPounds.weightMultiplier = storage.starPounds.enabled and math.round(1 + (storage.starPounds.weight/entity.weight), 1) or 1

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
		-- Don't play the sound on the first load.
		if oldSize then
			-- Play sound to indicate size change.
		starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
		end
		-- Update status effect tracker.
		starPounds.moduleFunc("tracking", "clearStatuses")
		starPounds.moduleFunc("tracking", "createStatuses")
	end
	-- Checks
	starPounds.voreCheck()
	starPounds.equipCheck(starPounds.currentSize)
	-- Actions.
	starPounds.eaten(dt)
	starPounds.digest(dt)
	-- Stat/status updating stuff.
	starPounds.updateEffects(dt)
	starPounds.updateStats(starPounds.optionChanged, dt)
	-- Modules.
	starPounds.moduleUpdate(dt)
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
end

function uninit()
	starPounds.releaseEntity(nil, true)
	starPounds.moduleUninit()
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
	      weight = speciesData.weight,
	      foodType = speciesData.foodType
      }
			local mt = {__index = function () return nullFunction end}
			setmetatable(entity, mt)
    	if not speciesData.weightGain then
    		message.setHandler("starPounds.feed", simpleHandler(function(amount) status.giveResource("food", amount) end))
    		starPounds.getChestVariant = function() return "" end
    		starPounds.getDirectives = function() return "" end
    		starPounds.equipSize = nullFunction
    		starPounds.equipCheck = nullFunction
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

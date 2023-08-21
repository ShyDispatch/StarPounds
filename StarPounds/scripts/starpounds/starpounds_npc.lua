-- Dummy empty function so we save memory.
local function nullFunction()
end
-- Old functions. (we call these in functons we replace)
local init_old = init or nullFunction
local update_old = update or nullFunction
local uninit_old = uninit or nullFunction
-- Run on load.
function init()
	-- Run old NPC/Monster stuff.
	init_old()
	require "/scripts/starpounds/starpounds.lua"
  storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
  -- Used in functions for detection.
  starPounds.type = "npc"
  -- Replace some functions.
  makeOverrideFunction()
  starPounds.overrides()
	-- Setup message handlers
	starPounds.messageHandlers()
	-- Reload whenever the entity loads in/beams/etc.
	starPounds.statCache = {}
	storage.starPounds.options = sb.jsonMerge(storage.starPounds.options, config.getParameter("starPounds_options", {}))

	if not storage.starPounds.parsedInitialSkills then
		local skills = config.getParameter("starPounds_skills", {})
		for k, v in pairs(skills) do
			local level = 0
			if type(v) == "table" then
				level = math.random(v[1], v[2])
			elseif type(v) == "number" then
				level = v
			end
			if level > 0 then
				skills[k] = jarray()
				skills[k][1] = level
				skills[k][2] = level
			else
				skills[k] = nil
			end
		end
		storage.starPounds.skills = sb.jsonMerge(storage.starPounds.skills, skills)
		storage.starPounds.parsedInitialSkills = true
	end

	starPounds.parseSkills()
	storage.starPounds.stats = sb.jsonMerge(storage.starPounds.stats, config.getParameter("starPounds_stats", {}))
	starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
	starPounds.parseEffectStats(1)
	starPounds.stomach = starPounds.getStomach()
	starPounds.breasts = starPounds.getBreasts()
	starPounds.setWeight(storage.starPounds.weight)
end

function update(dt)
	-- Run old NPC/Monster stuff.
	update_old(dt)
	-- Check promises.
	promises:update()
	-- Reset stat cache.
	starPounds.statCache = {}
	-- Check if the entity has gone up a size.
	starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
	starPounds.stomach = starPounds.getStomach()
	starPounds.breasts = starPounds.getBreasts()
	starPounds.currentVariant = starPounds.getChestVariant(modifierSize or starPounds.currentSize)
	starPounds.level = storage.starPounds.level
	starPounds.experience = storage.starPounds.experience
	starPounds.weightMultiplier = math.round(1 + (storage.starPounds.weight/(entity.weight + entity.bloat)), 1)
	if storage.starPounds.enabled then
		if starPounds.currentSize.movementPenalty == 1 then
			mcontroller.controlModifiers({
				movementSuppressed = true
			})
		end
	end
	if starPounds.currentSize.size ~= (oldSize and oldSize.size or nil) then
		-- Force stat update.
		starPounds.updateStats(true)
		-- Update status effect trackers.
		starPounds.createStatuses()
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
	starPounds.lactating(dt)
	-- Stat/status updating stuff.
	starPounds.parseEffectStats(dt)
	starPounds.updateStatuses()
	starPounds.updateStats()
	-- Save for comparison later.
	oldSize = starPounds.currentSize
	oldVariant = starPounds.currentVariant
	oldWeightMultiplier = starPounds.weightMultiplier

	if storage.starPounds.enabled then
		storage.starPounds.stomachLerp = starPounds.stomach.contents
	end
end

function makeOverrideFunction()
  function starPounds.overrides()
    if not starPounds.didOverrides then
			local speciesData = starPounds.getSpeciesData(npc.species())
      -- NPCs start with the mod enabled (and stuff for stats/options)
      storage.starPounds.enabled = true
      starPounds.parseSkillStats()
      -- No debug stuffs for NPCs
      starPounds.debug = nullFunction
      -- Shortcuts to make functions work for NPCs.
      player = {
        equippedItem = npc.getItemSlot,
        setEquippedItem = npc.setItemSlot,
        isLounging = npc.isLounging,
        loungingIn = npc.loungingIn,
        consumeItemWithParameter = function(parameter, value)
          for _, v in pairs({"chest", "legs", "chestCosmetic", "legsCosmetic"}) do
            local item = npc.getItemSlot(v)
            if item and item.parameters and item.parameters[parameter] == value then
              npc.setItemSlot(v, nil)
            end
          end
        end
      }
			local mt = {__index = function () return nullFunction end}
			setmetatable(player, mt)
      entity.setDropPool = function(...) return npc.setDropPools({...}) end
      entity.setDeathParticleBurst = npc.setDeathParticleBurst
      entity.setDeathSound = nullFunction
      entity.setDamageOnTouch = npc.setDamageOnTouch
			entity.setDamageSources = nullFunction
      entity.setDamageTeam = npc.setDamageTeam
      entity.weight = math.round(speciesData.weight * speciesData.nutritionRatio)
      entity.bloat = math.round(speciesData.weight * (1 - speciesData.nutritionRatio))
      entity.experience = speciesData.experience
      -- NPCs don't have a food stat, and trying to adjust it crashes the script.
      starPounds.feed = starPounds.eat
      -- Disable stuff NPCs don't use.
      starPounds.hunger = nullFunction
      starPounds.drink = nullFunction
      -- Save default functions.
      npc.say_old = npc.say_old or npc.say
			notify_old = notify_old or notify
      openDoors_old = openDoors_old or openDoors
      closeDoors_old = closeDoors_old or closeDoors
      closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
      preservedStorage_old = preservedStorage_old or preservedStorage
      -- Override default functions.
      npc.say = function(...) if not storage.starPounds.pred then npc.say_old(...) end end
			notify = function(...) if not storage.starPounds.pred then notify_old(...) end end
      closeDoorsBehind = function() if storage.starPounds.pred then closeDoorsBehind_old() end end
      openDoors = function(...) return storage.starPounds.pred and false or openDoors_old(...) end
      closeDoors = function(...) return storage.starPounds.pred and false or closeDoors_old(...) end
      preservedStorage = function()
        -- Grab old NPC stuff
        local preserved = preservedStorage_old()
        -- Add to preserved storage so it persists in crewmembers/bounties/etc.
        preserved.starPounds = storage.starPounds
        return preserved
      end
      -- Disable anything that uses visuals if the species doesn't have a patch.
      if not speciesData.weightGain then
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

-- Default override functions
----------------------------------------------------------------------------------
die_old = die or nullFunction
setDying = setDying or nullFunction
function die()
	if storage.starPounds.pred then
		storage.starPounds.pred = nil
		setDying({shouldDie = true})
		entity.setDropPool()
		entity.setDeathSound()
		entity.setDeathParticleBurst()
		status.setResource("health", 0)
	end
	die_old()
end

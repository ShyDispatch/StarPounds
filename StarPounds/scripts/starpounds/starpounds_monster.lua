-- Dummy empty function so we save memory.
local function nullFunction()
end
-- Old functions. (we call these in functons we replace)
local init_old = init or nullFunction
local update_old = update or nullFunction
local uninit_old = uninit or nullFunction
-- Run on load.
function starPoundsInit()
	require "/scripts/starpounds/starpounds.lua"
	storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
	-- Used in functions for detection.
	starPounds.type = "monster"
	-- Replace some functions.
	makeOverrideFunction()
	starPounds.overrides()
	-- Setup message handlers
	starPounds.messageHandlers()
	-- Reload whenever the entity loads in/beams/etc.
	starPounds.statCache = {}
	starPounds.statCacheTimer = starPounds.settings.statCacheTimer
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
	starPounds.currentVariant = starPounds.getChestVariant()
end

function init()
	-- Run old NPC/Monster stuff.
	init_old()
	starPoundsInit()
end

function update(dt)
	if not starPounds then
		require "/scripts/starpounds/starpounds.lua"
		starPoundsInit()
	end
	-- Run old NPC/Monster stuff.
	update_old(dt)
	-- Check promises.
	promises:update()
	-- Reset stat cache.
	starPounds.statCacheTimer = math.max(starPounds.statCacheTimer - dt, 0)
	if starPounds.statCacheTimer == 0 then
		starPounds.statCache = {}
		starPounds.statCacheTimer = starPounds.settings.statCacheTimer
	end
	starPounds.level = storage.starPounds.level
	starPounds.experience = storage.starPounds.experience
	starPounds.weightMultiplier = math.round(1 + (storage.starPounds.weight/(entity.weight + entity.bloat)), 1)
	-- Checks
	starPounds.voreCheck()
	-- Actions.
	starPounds.eaten(dt)
	starPounds.digest(dt)
	-- Stat/status updating stuff.
	starPounds.parseEffectStats(dt)
	starPounds.updateStatuses()
end

function makeOverrideFunction()
  function starPounds.overrides()
    if not starPounds.didOverrides then
			-- Monsters start with the mod enabled.
			storage.starPounds.enabled = true
			-- No debug stuffs for monsters
			starPounds.debug = nullFunction
			-- Shortcuts to make functions work for monsters.
			player = {}
			local mt = {__index = function () return nullFunction end}
			setmetatable(player, mt)
			entity.setDropPool = monster.setDropPool
			entity.setDeathParticleBurst = monster.setDeathParticleBurst
			entity.setDeathSound = monster.setDeathSound
			entity.setDamageOnTouch = monster.setDamageOnTouch
			entity.setDamageSources = monster.setDamageSources
			entity.setDamageTeam = monster.setDamageTeam
			-- Monsters cause a lot of bloat to make the stomach look full, but not be too overpowered for food.
			-- ~ 15 bloat and 15 food per block the entity's bounding box occupies.
			local boundBox = mcontroller.boundBox()
			local monsterArea = math.abs(boundBox[1]) + math.abs(boundBox[3]) * math.abs(boundBox[2]) + math.abs(boundBox[4])
			entity.bloat = math.round(monsterArea * 20)
			entity.weight = math.min(math.round(monsterArea * 10), 50)
			local deathActions = config.getParameter("behaviorConfig.deathActions", {})
			-- Remove base weight if the monster is 'replaced'.
			for _, action in ipairs(deathActions) do
				if action.name == "action-spawnmonster" and action.parameters.replacement then
						entity.bloat = 0
						entity.weight = 0
				end
			end
			for _, action in ipairs(deathActions) do
				if action.name == "action-spawnmonster" then
					local monsterPoly = root.monsterParameters(action.parameters.monsterType).movementSettings.collisionPoly
					local boundBox = util.boundBox(monsterPoly)
					local monsterArea = math.abs(boundBox[1]) + math.abs(boundBox[3]) * math.abs(boundBox[2]) + math.abs(boundBox[4])
					entity.bloat = entity.bloat + math.round(monsterArea * 20)
					entity.weight = entity.weight + math.min(math.round(monsterArea * 10), 50)
				end
			end
			entity.experience = entity.weight * starPounds.settings.monsterExperienceMultiplier
			-- No XP if the monster is a pet (prevents infinite XP).
			if (capturable and (capturable.tetherUniqueId() or capturable.ownerUuid())) then
				entity.experience = 0
			end
			-- Robotic monsters only give bloat, but still give XP.
			if status.statusProperty("targetMaterialKind") == "robotic" then
				entity.bloat = entity.bloat + entity.weight
				entity.weight = 0
			end
			-- Monsters don't have a food stat, and trying to adjust it crashes the script.
			starPounds.feed = starPounds.eat
			starPounds.hunger = nullFunction
			-- Disable stuff monsters don't use
			starPounds.gainExperience = nullFunction
			starPounds.exercise = nullFunction
			starPounds.drink = nullFunction
			starPounds.getChestVariant = function() return "" end
			starPounds.getDirectives = function() return "" end
			starPounds.getSpecies = function() return "" end
			starPounds.getBreasts = function() return {capacity = 10 * starPounds.getStat("breastCapacity"), contents = 0, fullness = 0, type = "milk"} end
			starPounds.equipSize = nullFunction
			starPounds.equipCheck = nullFunction
			starPounds.updateStats = nullFunction
			starPounds.gainBloat = nullFunction
			starPounds.gainWeight = nullFunction
			starPounds.loseWeight = nullFunction
			starPounds.setWeight = nullFunction
			starPounds.gainMilk = nullFunction
			starPounds.lactate = nullFunction
			starPounds.lactating = nullFunction
			-- Save default functions.
			openDoors_old = openDoors_old or openDoors
			closeDoors_old = closeDoors_old or closeDoors
			closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
			-- Override default functions.
			closeDoorsBehind = function() if storage.starPounds.pred then closeDoorsBehind_old() end end
			openDoors = function(...) return storage.starPounds.pred and false or openDoors_old(...) end
			closeDoors = function(...) return storage.starPounds.pred and false or closeDoors_old(...) end
			-- Ignore things that have been eaten.
			entity.isValidTarget_old = entity.isValidTarget_old or entity.isValidTarget
			entity.isValidTarget = function(entityId)
				local eatenEntity = nil
				if not world.entityExists(entityId) then return false end
				for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
					if prey.id == entityId then
						eatenEntity = prey
					end
				end
				if #world.monsterQuery(world.entityPosition(entityId), 1, {withoutEntityId = entity.id(), callScript = "hasEatenEntity", callScriptArgs = {{entity = entityId}}}) > 0 then
					return false
				end
				if #world.npcQuery(world.entityPosition(entityId), 1, {withoutEntityId = entity.id(), callScript = "hasEatenEntity", callScriptArgs = {{entity = entityId}}}) > 0 then
					return false
				end
				if eatenEntity then return false end
				return entity.isValidTarget_old(entityId)
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
		self.deathBehavior = nil
	end
	die_old()
end

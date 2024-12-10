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
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds).__nils = {}
  -- Used in functions for detection.
  starPounds.type = "npc"
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Setup species traits.
  storage.starPounds.overrideSpecies = config.getParameter("starPounds_overrideSpecies")
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
  starPounds.setWeight(storage.starPounds.weight)
  starPounds.moduleInit({"humanoid", "npc"})
  starPounds.effectInit()
end

function update(dt)
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
  -- Check if the entity has gone up a size.
  starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
  starPounds.currentVariant = starPounds.getChestVariant(modifierSize or starPounds.currentSize)
  starPounds.weight = storage.starPounds.weight
  starPounds.level = storage.starPounds.level
  starPounds.experience = storage.starPounds.experience
  starPounds.weightMultiplier = storage.starPounds.enabled and math.round(1 + (storage.starPounds.weight/entity.weight), 1) or 1

  if starPounds.currentSize.size ~= (oldSize and oldSize.size or nil) then
    -- Force stat update.
    starPounds.updateStats(true)
    -- Update status effect trackers.
    starPounds.createStatuses()
    -- Don't play the sound on the first load.
    if oldSize then
      -- Play sound to indicate size change.
      starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
    end
  end
  -- Checks
  starPounds.voreCheck()
  starPounds.equipCheck(starPounds.currentSize)
  -- Actions.
  starPounds.eaten(dt)
  -- Stat/status updating stuff.
  starPounds.updateEffects(dt)
  starPounds.updateStats(starPounds.optionChanged, dt)
  -- Modules.
  starPounds.moduleUpdate(dt)
  -- Save for comparison later.
  oldSize = starPounds.currentSize
  oldVariant = starPounds.currentVariant
  oldWeightMultiplier = starPounds.weightMultiplier

  starPounds.optionChanged = false
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end

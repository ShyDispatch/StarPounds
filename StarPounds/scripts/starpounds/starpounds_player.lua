require "/scripts/rect.lua"
-- Run on load.
function init()
  -- Load StarPounds.
  require "/scripts/starpounds/starpounds.lua"
  -- Grab or create the data.
  local loadBackup = not storage.starPounds
  storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds).__nils = {}
  getmetatable ''.starPounds = starPounds
  -- Used in functions for detection.
  starPounds.type = "player"
  -- Backup storage.
  if loadBackup then
    storage.starPounds = sb.jsonMerge(storage.starPounds, player.getProperty("starPoundsBackup", {}))
  end
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
  starPounds.setWeight(storage.starPounds.weight)
  starPounds.moduleInit({"humanoid", "player", "vore"})
  starPounds.effectInit()
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
    -- Don't play the sound on the first load.
    if oldSize then
      -- Play sound to indicate size change.
      starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
    end
    -- Update status effect tracker.
    starPounds.moduleFunc("trackers", "clearStatuses")
    starPounds.moduleFunc("trackers", "createStatuses")
  end
  -- Checks
  starPounds.voreCheck()
  starPounds.equipCheck(starPounds.currentSize)
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
  starPounds.releaseEntity(nil, true)
  starPounds.moduleUninit()
  starPounds.backup()
end

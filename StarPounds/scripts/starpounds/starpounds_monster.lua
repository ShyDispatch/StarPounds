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
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds).__nils = {}
  -- Used in functions for detection.
  starPounds.type = "monster"
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.statCache = {}
  starPounds.statCacheTimer = starPounds.settings.statCacheTimer
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
  starPounds.level = storage.starPounds.level
  starPounds.experience = storage.starPounds.experience
  starPounds.moduleInit({"monster", "vore"})
  starPounds.effectInit()
  if not starPounds.getTrait() then
    starPounds.setTrait(config.getParameter("starPounds_trait"))
  end
  starPounds.weightMultiplier = math.round(1 + (storage.starPounds.weight/entity.weight), 1)
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
  -- Stat/status updating stuff.
  starPounds.updateEffects(dt)
  -- Modules.
  starPounds.moduleUpdate(dt)
  starPounds.optionChanged = false
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end

-- Underscore here since the NPC table exists.
local _npc = starPounds.module:new("npc")

function _npc:init()
  -- Set NPC specific trait.
  if not starPounds.getTrait() then
    starPounds.setTrait(config.getParameter("starPounds_trait"))
  end
  -- Initial skills and options.
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
  self:setup()
  starPounds.parseSkills()
  starPounds.parseStats()
  -- Triggers aggro.
  message.setHandler("starPounds.notifyDamage", simpleHandler(damage))
  message.setHandler("starPounds.notifyDamage", simpleHandler(function(args)
    _ENV.self.damaged = true
    _ENV.self.board:setEntity("damageSource", args.sourceId)
  end))
  -- I hate it.
  self.setNpcItemSlot_old = setNpcItemSlot
  self.setNpcItemSlotCC_old = setNpcItemSlotCC or nullFunction
  setNpcItemSlot = function(...)
    self.setNpcItemSlot_old(...)
    starPounds.optionChanged = true
  end
  setNpcItemSlotCC = function(...)
    self.setNpcItemSlotCC_old(...)
    starPounds.optionChanged = true
  end
end

function _npc:update(dt)
  if storage.starPounds.enabled then
    if starPounds.currentSize.movementPenalty == 1 then
      mcontroller.controlModifiers({
        movementSuppressed = true
      })
    end
  end
end

function _npc:setup()
  -- Dummy empty function so we save memory.
  local function nullFunction() end
  local speciesData = starPounds.getSpeciesData(npc.species())
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
  entity.weight = speciesData.weight
  entity.foodType = speciesData.foodType
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
    starPounds.equipSize = nullFunction
    starPounds.equipCheck = nullFunction
    starPounds.gainWeight = nullFunction
    starPounds.loseWeight = nullFunction
    starPounds.setWeight = nullFunction
    starPounds.getSize = function() return starPounds.sizes[1], 1 end
  end
end

local die_old = die or nullFunction
local setDying = setDying or nullFunction
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

starPounds.modules.npc = _npc

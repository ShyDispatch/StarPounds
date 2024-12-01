local init_old = init
local update_old = update

function init()
  init_old()
  -- Count starpoundsapplevisitor as a valid target, even if the damage team is different.
  local isValidTarget_old = entity.isValidTarget
  function entity.isValidTarget(entityId)
    return world.entityTypeName(entityId) == "starpoundsapplevisitor" or isValidTarget_old(entityId)
  end

  -- Ignore world protection.
  local eatEntity_old = starPounds.eatEntity
  starPounds.eatEntity = function(preyId, options, check)
    options = type(options) == "table" and options or {}
    options.ignoreProtection = true
    options.ignoreCapacity = true
    return eatEntity_old(preyId, options, check)
  end
end

function update(dt)
  update_old(dt)
  if starPounds.currentVariant and not storage.removedChest and #storage.starPounds.stomachEntities > 0 then
    storage.removedChest = true

    npc.setItemSlot("chestCosmetic")
    -- Fast way to force a size reequip.
    starPounds.optionChanged = true
    starPounds.equipCheck(starPounds.currentSize)
    starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
  end

  teleportVoreDelay = math.max((teleportVoreDelay or 1) - dt, 0)
  if not starPounds_didQuery and status.uniqueStatusEffectActive("beamin") and teleportVoreDelay == 0 then
    local entities = world.entityQuery(mcontroller.position(), 1, {order = "nearest", includedTypes = {"player", "npc"}, withoutEntityId = entity.id()}) or jarray()
    local eatOptions = {ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirment = true, energyMultiplier = 0, noSwallowSound = true}
    for _, target in ipairs(entities) do
      if starPounds.eatEntity(target, eatOptions, true) then
        starPounds.eatEntity(target, eatOptions)
        break
      end
    end
    starPounds_didQuery = true
  end
end

local init_old = init
local update_old = update

function init()
  init_old()
  -- Count starpoundsapplevisitor as a valid target, even if the damage team is different.
  local isValidTarget_old = entity.isValidTarget
  function entity.isValidTarget(entityId)
    return world.entityTypeName(entityId) == "starpoundsapplevisitor" or isValidTarget_old(entityId)
  end

  -- Ignore world protection for specific npc type.
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
    world.sendEntityMessage(entity.id(), "starPounds.playSound", "clothingrip", 0.75)
  end
end

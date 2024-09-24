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

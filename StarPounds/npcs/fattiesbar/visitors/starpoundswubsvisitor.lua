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
  starPounds.modules.pred.eat_old = starPounds.modules.pred.eat
  function starPounds.modules.pred:eat(preyId, options, check)
    options = type(options) == "table" and options or {}
    options.ignoreProtection = true
    options.ignoreCapacity = true
    return self:eat_old(preyId, options, check)
  end
end

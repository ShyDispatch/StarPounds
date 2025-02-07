local init_old = init
function init()
  init_old()
  -- Count Apple/Grace as a valid target, even if the damage team is different.
  local isApple = function(entityId)
    if world.entityDamageTeam(entityId) and world.entityDamageTeam(entityId).type == "ghostly" then return false end
    if string.find(sb.print(world.entityTypeName(entityId)), "starpoundsapple") then return true end
    if string.find(sb.print(world.entityName(entityId)), "%^#2862e9;Grace%^reset;") then return true end
    return false
  end

  local isValidTarget_old = entity.isValidTarget
  function entity.isValidTarget(entityId)
    return isApple(entityId) or isValidTarget_old(entityId)
  end

  -- Ignore world protection.
  starPounds.modules.pred.eat_old = starPounds.modules.pred.eat
  function starPounds.modules.pred:eat(preyId, options, check)
    options = type(options) == "table" and options or {}
    -- The eaty is inevitable.
    options.ignoreProtection = true
    options.ignoreCapacity = true
    options.noEscape = true
    return self:eat_old(preyId, options, check)
  end
end

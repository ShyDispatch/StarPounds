function init()
  if effect.sourceEntity() == entity.id() then
    local effects = effect.getParameter("sourceStatusEffects", jarray())
    status.addEphemeralEffects(effects, effect.sourceEntity())
  else
    local effects = effect.getParameter("statusEffects", jarray())
    status.addEphemeralEffects(effects, effect.sourceEntity())
  end
  effect.expire()
end

function init()
  source = effect.sourceEntity()
  if source ~= entity.id() then
    world.sendEntityMessage(source, "starPounds.eatEntity", entity.id(), effect.getParameter("options", {}))
  end
  effect.expire()
end

function update()
  effect.expire()
end

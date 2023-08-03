function init()
  source = effect.sourceEntity()
  if source ~= entity.id() then
    world.sendEntityMessage(entity.id(), "starPounds.eatEntity", source, true)
  end
  effect.expire()
end

function update()
  effect.expire()
end

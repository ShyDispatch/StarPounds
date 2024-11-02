function init()
  entityId = entity.id()
  incrementType = string.format("starPounds.%s", effect.getParameter("type", "feed"))
  rate = effect.getParameter("rate", 5)
  data = effect.getParameter("data")
end

function update(dt)
  world.sendEntityMessage(entityId, incrementType, dt * rate, data)
end

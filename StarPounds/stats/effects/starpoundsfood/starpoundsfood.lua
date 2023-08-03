function init()
  local duration = effect.duration() or 0
  if duration > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.feed", duration)
  end
end

function update()
  effect.expire()
end

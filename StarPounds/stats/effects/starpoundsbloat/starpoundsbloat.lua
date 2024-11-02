function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.feed", effect.duration(), "bloat")
  end
end

function update()
  effect.expire()
end

function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "starPounds.gainBloat", effect.duration(), effect.getParameter("full", false))
  end
end

function update()
  effect.expire()
end

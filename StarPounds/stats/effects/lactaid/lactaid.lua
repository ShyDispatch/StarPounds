function init()
  local skill = effect.getParameter("skill")
  if skill then
    world.sendEntityMessage(entity.id(), "starPounds.upgradeSkill", skill)
  end
end

function update()
  effect.expire()
end

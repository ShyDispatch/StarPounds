local update_old = update or function() end
function update(dt)
  starPounds = getmetatable ''.starPounds
  if starPounds and starPounds.isEnabled() then
    if not starPounds.modules.hunger.isStarving then
      mcontroller.controlModifiers(self.movementModifiers)
    else
      update_old(dt)
    end
  end
end

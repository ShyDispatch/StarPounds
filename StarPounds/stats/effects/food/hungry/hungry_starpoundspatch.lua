local update_old = update or function() end
function update(dt)
  starPounds = getmetatable ''.starPounds
  if starPounds and starPounds.isEnabled() then
    if starPounds.hasSkill("preventStarving") and not starPounds.hasOption("disableLoss") then
      self.soundTimer = self.soundInterval
    end
  end
  update_old(dt)
end

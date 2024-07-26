require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  self.fillRange = effect.getParameter("fillRange", {1, 16})
  self.scale = ( self.fillRange[2] - (self.fillRange[1] - 1) ) / 16
  self.buffer = 100 * (self.fillRange[1] - 1) / 16
end

function update(dt)
  -- Cross script voodoo witch magic.
  if world.entityType(entity.id()) == "player" then
    local progress = getmetatable ''.starPounds and getmetatable ''.starPounds.progress or 0
    if effect.duration() and (effect.duration() > 0) then
      -- "Center" the animation.
      effect.modifyDuration((progress * self.scale) + self.buffer + dt - effect.duration())
    end
    if getmetatable ''.starPounds and getmetatable ''.starPounds.hasOption("disableSizeMeter") then
      effect.expire()
    end
  end
end

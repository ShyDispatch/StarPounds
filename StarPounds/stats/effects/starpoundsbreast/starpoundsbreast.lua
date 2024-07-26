require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  self.fillRange = effect.getParameter("fillRange", {1, 16})
  self.scale = ( self.fillRange[2] - (self.fillRange[1] - 1) ) / 16
  self.buffer = 100 * (self.fillRange[1] - 1) / 16
end

function update(dt)
  -- Cross script voodoo witch magic.
  local starPounds = getmetatable ''.starPounds
  local progress = math.min(starPounds.breasts.fullness, 1) * 100
  if effect.duration() and (effect.duration() > 0) then
    -- "Center" the animation.
    effect.modifyDuration((progress * self.scale) + self.buffer + dt - effect.duration())
  end

  if starPounds and (not starPounds.hasOption("breastMeter")) then
    effect.expire()
  end
end

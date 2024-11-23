local fizzy = starPounds.effect:new()

function fizzy:init()
  self.airAmount = 5
  self.fizzVolume = 0.25
  self.firstUpdate = false
  self.expiring = false
  self.baseDuration = starPounds.effects.fizzy.duration
  world.sendEntityMessage(entity.id(), "starPounds.stopSound", "fizz")
end

function fizzy:apply()
  self.expiring = false
end

function fizzy:update(dt)
  -- Decrease fizz amount and sound volume as it runs out.
  local multiplier = math.max(math.min(self.data.duration/self.baseDuration, 1), 0.25)
  local volume = (multiplier + 1) * 0.5
  -- Update the sound volume after the first update.
  if self.firstUpdate then
    world.sendEntityMessage(entity.id(), "starPounds.setSoundVolume", "fizz", self.fizzVolume * volume, dt)
  end
  -- Gurgle sound that plays when enabling the mod overrides if we trigger it on init.
  if not self.firstUpdate then
    world.sendEntityMessage(entity.id(), "starPounds.playSound", "fizz", self.fizzVolume * volume, 0.75, -1)
    self.firstUpdate = true
  end
  -- Ramp down sound as it expires.
  if not self.expiring and (self.data.duration + dt) <= 1 then
    self.expiring = true
    world.sendEntityMessage(entity.id(), "starPounds.setSoundVolume", "fizz", 0, 1)
  end
  -- Add air bloat.
  local airAmount = self.airAmount * multiplier
  if not (mcontroller.zeroG() or mcontroller.liquidMovement()) and not mcontroller.onGround() then
    if not self.jumped then
      starPounds.rumble(volume)
      world.sendEntityMessage(entity.id(), "starPounds.playSound", "slosh", 0.5 * volume)
      -- Remove one second of duration at the cost of 2 seconds of air.
      starPounds.feed(airAmount * 2, "air")
      self.data.duration = math.max(self.data.duration - 1, 0)
      self.jumped = true
    end
  elseif mcontroller.onGround() then
    self.jumped = false
  end
  starPounds.feed(airAmount * dt, "air")
end

function fizzy:expire()
  self:uninit()
end

function fizzy:uninit()
  world.sendEntityMessage(entity.id(), "starPounds.stopSound", "fizz")
end
-- Add the effect.
starPounds.scriptedEffects.fizzy = fizzy

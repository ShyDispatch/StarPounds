local fizzy = starPounds.effect:new()

function fizzy:init()
  self.airAmount = 5
  self.fizzVolume = 0.25
  self.fizzMultiplier = 1
  self.volumeMultiplier = 1
  self.firstUpdate = false
  self.expiring = false
  self.baseDuration = starPounds.effects.fizzy.duration
  starPounds.moduleFunc("sound", "stop", "fizz")
end

function fizzy:apply()
  self.expiring = false
end

function fizzy:update(dt)
  -- Decrease fizz amount and sound volume as it runs out.
  self.fizzMultiplier = math.max(math.min(self.data.duration/self.baseDuration, 1), 0.25)
  self.volumeMultiplier = (self.fizzMultiplier + 1) * 0.5
  -- Update the sound volume after the first update.
  if self.firstUpdate then
    starPounds.moduleFunc("sound", "setVolume", "fizz", self.fizzVolume * self.volumeMultiplier, dt)
  end
  -- Gurgle sound that plays when enabling the mod overrides if we trigger it on init.
  if not self.firstUpdate then
    starPounds.moduleFunc("sound", "play", "fizz", self.fizzVolume * self.volumeMultiplier, 0.75, -1)
    self.firstUpdate = true
  end
  -- Ramp down sound as it expires.
  if not self.expiring and (self.data.duration + dt) <= 1 then
    self.expiring = true
    starPounds.moduleFunc("sound", "setVolume", "fizz", 0, 1)
  end
  -- Add air bloat.
  if not (mcontroller.zeroG() or mcontroller.liquidMovement()) and not mcontroller.onGround() then
    if not self.jumped then
      starPounds.moduleFunc("sound", "play", "slosh", 0.5 * self.volumeMultiplier)
      self:shake(1)
      self.jumped = true
    end
  elseif mcontroller.onGround() then
    self.jumped = false
  end
  starPounds.feed(self.airAmount * self.fizzMultiplier * dt, "air")
end

function fizzy:expire()
  self:uninit()
end

function fizzy:uninit()
  starPounds.moduleFunc("sound", "stop", "fizz")
end

function fizzy:shake(duration)
  -- Remove duration for double the air.
  starPounds.feed(duration * self.airAmount * self.fizzMultiplier * 2, "air")
  self.data.duration = math.max(self.data.duration - duration, 0)
  starPounds.rumble(self.volumeMultiplier)
end
-- Add the effect.
starPounds.scriptedEffects.fizzy = fizzy

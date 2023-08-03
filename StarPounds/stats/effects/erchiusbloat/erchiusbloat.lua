function init()
  script.setUpdateDelta(5)
  self.bloatAmount = effect.getParameter("bloatAmount", 10)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimer = 0

  self.desaturateAmount = config.getParameter("desaturateAmount")
  self.multiply = config.getParameter("multiplyColor")

  self.saturation = 0

  animator.playSound("geiger", -1)
end

function update(dt)
  if world.entityType(entity.id()) == "npc" or (getmetatable ''.starPounds and getmetatable ''.starPounds.enabled) then
    -- Gain 10 + (Seconds since bloating began) bloat per second. (Max: 100 per second)
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      self.tickTimer = self.tickTime
      self.bloatAmount = math.min(self.bloatAmount + 1 * self.tickTime, 100)
      self.saturation = math.floor(-self.desaturateAmount * self.bloatAmount * 0.01)

      local multiply = {255 + self.multiply[1] * self.bloatAmount * 0.01, 255 + self.multiply[2] * self.bloatAmount * 0.01, 255 + self.multiply[3] * self.bloatAmount * 0.01}
      local multiplyHex = string.format("%s%s%s", toHex(multiply[1]), toHex(multiply[2]), toHex(multiply[3]))

      world.sendEntityMessage(entity.id(), "starPounds.gainBloat", self.bloatAmount)
      effect.setParentDirectives(string.format("?saturation=%d?multiply=%s", self.saturation, multiplyHex))
      animator.setSoundVolume("geiger", self.bloatAmount * 0.01)
    end
  else
    effect.expire()
  end
end

function toHex(num)
  local hex = string.format("%X", math.floor(num + 0.5))
  if num < 16 then hex = "0"..hex end
  return hex
end

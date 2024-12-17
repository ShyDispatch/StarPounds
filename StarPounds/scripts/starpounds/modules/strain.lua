local strain = starPounds.module:new("strain")

function strain:init()
  self.thresholds = starPounds.settings.thresholds.strain
  self.energyRegenBlockDelta = root.assetJson("/player.config:statusControllerSettings.resources.energyRegenBlock.deltaValue")
  self.speedModifier = 1
  self.effort = 0
end

function strain:update(dt)
  self.speedModifier = 1
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.effort = starPounds.moduleFunc("movement", "getEffort")
  -- Skip the rest if we're not moving.
  if self.effort == 0 then return end
  -- Skip this if we're in a sphere.
  if status.stat("activeMovementAbilities") > 1 then return end
  -- Skip this for monsters.
  if starPounds.type == "monster" then return end
  if self:strained() then
    local strainedPenalty = starPounds.getStat("strainedPenalty")
    local energyPercent = status.resourcePercentage("energy")
    local energyLocked = status.resourceLocked("energy")
    -- Slow movement when out of energy and strained, based on energy left.
    self.speedModifier = (1 - self.data.penalty - (self.data.scalingPenalty * (energyLocked and 1 or (1 - energyPercent)))) ^ strainedPenalty
    -- Consume and lock energy when running.
    if self:straining() then
      local energy = status.resource("energy")
      local energyMax = status.resourceMax("energy")
      local energyCost = energyMax * self.data.energyCost * self.effort
      local fullnessMultiplier = math.min(math.max(1, starPounds.stomach.fullness - 1), self.thresholds.starpoundsstomach3 - 1)
      -- Stomach makes more rumble sounds while straining.
      starPounds.moduleFunc("stomach", "stepTimer", "rumble", self.data.rumbleBonus * fullnessMultiplier * dt)
      -- Don't run this if we're at zero energy.
      if energy > 0 then
        local deltaAmount = dt
        if energyLocked then
          deltaAmount = deltaAmount * energyMax * status.stat("energyRegenPercentageRate") * 1.25
        else
          deltaAmount = deltaAmount * energyCost * strainedPenalty * fullnessMultiplier
          status.modifyResource("energyRegenBlock", ((1 + self.effort) - self.energyRegenBlockDelta) * dt)
        end
        -- Subtract the delta amount (the regen rate + a little extra if we're locked), but leave a tiny bit of energy to prevent lockout.
        status.modifyResource("energy", -math.min(deltaAmount, math.max(0, energy - deltaAmount)))
      end
      -- Sweat we're out of energy.
      if energyLocked or energyPercent < 0.05 then
        status.addEphemeralEffect("sweat")
      end
    end
  end
  -- Move speed stuffs.
  mcontroller.controlModifiers({
    airJumpModifier = self.speedModifier,
    speedModifier = self.speedModifier
  })
end

function strain:strained()
  return starPounds.stomach.fullness > self.thresholds.starpoundsstomach
end

function strain:straining()
  return self:strained() and (self.effort >= self.data.effortThreshold)
end

starPounds.modules.strain = strain

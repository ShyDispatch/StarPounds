local hunger = starPounds.module:new("hunger")

function hunger:init()
  self.isStarving = false
  self.baseThreshold = starPounds.settings.thresholds.strain.starpoundsstomach
  self.skillThreshold = starPounds.settings.thresholds.strain.starpoundsstomach3
end

function hunger:update(dt)
  -- Holy shit why can we not detect what gamemode the player is using.
  if starPounds.hasOption("disableHunger") then
    status.setResourcePercentage("food", 1)
  end
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Check if the player is starving.
  self.isStarving = status.uniqueStatusEffectActive("starving")
  -- Check upgrade for preventing starving and they have weight loss enabled.
  if starPounds.hasSkill("preventStarving") and not starPounds.hasOption("disableLoss") then
    -- 1% more than the food delta.
    if self.isStarving then
      local foodDelta = math.max(status.stat("foodDelta") * -1, 0) * dt
      local availableWeight = storage.starPounds.weight - starPounds.sizes[starPounds.getSkillLevel("minimumSize") + 1].weight
      if availableWeight > 0 then
        self.isStarving = false
        local lossMultiplier = math.max(1, 1/math.max(0.01, (starPounds.getStat("foodValue") * starPounds.getStat("absorption"))))
        -- Converting fat, so ignore weight loss modifiers.
        starPounds.loseWeight(foodDelta * lossMultiplier, true)
      end
    end
  end
  -- Set the statuses.
  if starPounds.stomach.interpolatedFullness >= self.baseThreshold and not starPounds.hasSkill("wellfedProtection") then
    status.addEphemeralEffect("wellfed")
  elseif starPounds.stomach.interpolatedFullness >= self.skillThreshold then
    status.addEphemeralEffect("wellfed")
  else
    if status.resource("food") >= (status.resourceMax("food") + status.stat("foodDelta")) and starPounds.stomach.food > 0 then
      status.addEphemeralEffect("starpoundswellfed")
    end
  end
end

starPounds.modules.hunger = hunger

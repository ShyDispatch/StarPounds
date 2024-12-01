local exercise = starPounds.module:new("exercise")

function exercise:init()
  self.hasFood = status.isResource("food")
  self.energyRegenBlockDelta = root.assetJson("/player.config:statusControllerSettings.resources.energyRegenBlock.deltaValue")
  self.thresholds = starPounds.settings.thresholds.strain
  self.didJump = false
end

function exercise:update(dt)
  -- Don't do anything if the mod is disabled.
	if not storage.starPounds.enabled then return end
	-- Assume we're not strained.
	starPounds.strained = false
	-- Skip this if we're in a sphere.
	if status.stat("activeMovementAbilities") > 1 then return end
	-- Jumping > Running > Walking
	local effort = 0
	local consumeEnergy = false
	if mcontroller.groundMovement() then
		if mcontroller.walking() then effort = self.data.multipliers.walking end
		if mcontroller.running() then effort = self.data.multipliers.running consumeEnergy = true end
		-- Reset jump checker while on ground.
		self.didJump = false
		-- Moving through liquid takes up to 50% more effort.
		effort = effort * (1 + math.min(math.round(mcontroller.liquidPercentage(), 1), 0.5))
	elseif not mcontroller.liquidMovement() and mcontroller.jumping() and not self.didJump then
		effort = self.data.multipliers.jumping
		consumeEnergy = true
	else
		self.didJump = true
	end

	-- Skip the rest if we're not moving.
	if effort == 0 then return end
	local speedModifier = 1
	local runningSuppressed = false
	-- Consume energy based on how far over capacity they are.
	local strainedPenalty = starPounds.getStat("strainedPenalty")
	if starPounds.stomach.fullness > self.thresholds.starpoundsstomach then
		starPounds.strained = true
		speedModifier = math.max(0.5, (1 - math.max(0, math.min(starPounds.stomach.fullness - self.thresholds.starpoundsstomach, 2)/4) * strainedPenalty * (1 - (status.resourcePercentage("energy")))))
		runningSuppressed = status.resourceLocked("energy") or not status.resourcePositive("energy")
		-- Consume and lock energy when running.
		if not status.resourceLocked("energy") and consumeEnergy then
			local energyCost = status.resourceMax("energy") * strainedPenalty * status.resourcePercentage("energyRegenBlock") * effort * 0.25 * dt
			-- Double energy cost from super tummy-too-big-itus
			if starPounds.stomach.fullness >= self.thresholds.starpoundsstomach2 then
				energyCost = energyCost * 2
			end
			status.modifyResource("energy", -energyCost)
			status.modifyResource("energyRegenBlock", ((1 + effort) * strainedPenalty - self.energyRegenBlockDelta) * dt)
		end
	end
	-- Sweat if we can't run and moving.
	if runningSuppressed and effort > 0 then
		status.addEphemeralEffect("sweat")
	end
	-- Move speed stuffs.
	mcontroller.controlModifiers({
		runningSuppressed = runningSuppressed,
		airJumpModifier = runningSuppressed and (1 - (0.5 * strainedPenalty)) or nil,
		speedModifier = speedModifier
	})
	-- Lose weight based on weight, effort, and the multiplier.
	local amount = effort * (starPounds.weightMultiplier ^ 0.5) * dt * self.data.multipliers.base * starPounds.getStat("metabolism")
	-- Weight loss reduced by 75% if you're full, and have food in your stomach.
	if self.hasFood and status.resource("food") >= (status.resourceMax("food") + status.stat("foodDelta")) and starPounds.stomach.food > 0 then
		amount = amount * 0.25
	end
	starPounds.loseWeight(amount)
end

starPounds.modules.exercise = exercise

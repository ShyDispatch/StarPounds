local sloshing = starPounds.module:new("sloshing")

function sloshing:init()
  self.sloshTimer = 0
  self.sloshDeactivateTimer = 0
  self.sloshActivations = 0
end

function sloshing:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Skip if nothing in stomach.
  if starPounds.stomach.amount == 0 then return end
  -- Check for skill.
  if not starPounds.hasSkill("sloshing") then return end
  -- Only works with energy.
  if status.isResource("energy") and status.resourceLocked("energy") then return end
  local crouching = mcontroller.crouching()
  self.sloshTimer = math.max(self.sloshTimer - dt, 0)
  self.sloshDeactivateTimer = math.max(self.sloshDeactivateTimer - dt, 0)
  if crouching and not self.wasCrouching and self.sloshTimer < (self.data.sloshTimer - self.data.minimumSloshTimer) then
  	local activationMultiplier = self.sloshActivations/self.data.sloshActivationCount
  	local sloshEffectiveness = (1 - (self.sloshTimer/self.data.sloshTimer)) * activationMultiplier
  	-- Sloshy sound, with volume increasing until activated.
  	local soundMultiplier = 0.65 * (0.5 + 0.5 * math.min(starPounds.stomach.contents/starPounds.settings.stomachCapacity, 1)) * activationMultiplier
  	local pitchMultiplier = 1.25 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2)
  	world.sendEntityMessage(entity.id(), "starPounds.playSound", "slosh", soundMultiplier, pitchMultiplier)
  	if activationMultiplier > 0 then
  		starPounds.digest(self.data.sloshDigestion * sloshEffectiveness, true)
  		local energyMultiplier = sloshEffectiveness * starPounds.getStat("sloshingEnergy")
  		status.modifyResource("energyRegenBlock", status.stat("energyRegenBlockTime") * self.data.sloshEnergyLock * sloshEffectiveness)
  		status.modifyResource("energy", -self.data.sloshEnergy * energyMultiplier)
  		starPounds.gurgleTimer = math.max((starPounds.gurgleTimer or 0) - (self.data.sloshPercent * starPounds.settings.gurgleTime), 0)
  		starPounds.rumbleTimer = math.max((starPounds.rumbleTimer or 0) - (self.data.sloshPercent * starPounds.settings.rumbleTime), 0)
      if starPounds.modules.effect_fizzy then
        starPounds.modules.effect_fizzy:shake(sloshEffectiveness)
      end
  	end
  	self.sloshActivations = math.min(self.sloshActivations + 1, self.data.sloshActivationCount)
  	self.sloshTimer = self.data.sloshTimer
  	self.sloshDeactivateTimer = self.data.sloshDeactivateTimer
  end
  if self.sloshDeactivateTimer == 0 or (mcontroller.walking() or mcontroller.running()) then
  	self.sloshActivations = 0
  end
  self.wasCrouching = crouching
end

starPounds.modules.sloshing = sloshing

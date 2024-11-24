local statuses = starPounds.module:new("statuses")

function statuses:init()
  self.bonuses = {}
  self.multipliers = {}
end

function statuses:update(dt)
	-- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.bonuses = {}
  self.multipliers = {}
  -- Don't create if we can't add statuses anyway.
	if status.statPositive("statusImmunity") then return end
	for effectName, stats in pairs(self.data.bonuses) do
		if status.uniqueStatusEffectActive(effectName) then
			for stat, bonus in pairs(stats) do
				local currentBonus = self.bonuses[stat] or 0
				self.bonuses[stat] = currentBonus + bonus
			end
		end
	end
	for effectName, stats in pairs(self.data.multipliers) do
		if status.uniqueStatusEffectActive(effectName) then
			for stat, multiplier in pairs(stats) do
				local currentMultiplier = self.multipliers[stat] or 1
				self.multipliers[stat] = currentMultiplier * multiplier
			end
		end
	end
end

starPounds.modules.statuses = statuses

-- Overwrite stub functions.
starPounds.getStatusEffectMultiplier = function(stat)
	-- Argument sanitisation.
	stat = tostring(stat)
	return starPounds.modules.statuses.multipliers[stat] or 1
end

starPounds.getStatusEffectBonus = function(stat)
	-- Argument sanitisation.
	stat = tostring(stat)
	return starPounds.modules.statuses.bonuses[stat] or 0
end

local respawn = starPounds.module:new("respawn")

function respawn:uninit()
  if not status.resourcePositive("health") then
    local experienceProgress = storage.starPounds.experience/(starPounds.settings.experienceAmount * (1 + storage.starPounds.level * starPounds.settings.experienceIncrement))
    local experienceCost = math.ceil(self.data.experiencePercentile * storage.starPounds.level * starPounds.getStat("deathPenalty"))
    local weightCost = math.ceil(storage.starPounds.weight * self.data.weightPercentile * starPounds.getStat("deathPenalty"))
    -- Reduce levels and progress to next experience level.
    storage.starPounds.level = math.max(storage.starPounds.level - experienceCost, 0)
    storage.starPounds.experience = math.max(experienceProgress - (self.data.experiencePercentile * starPounds.getStat("deathPenalty")), 0) * starPounds.settings.experienceAmount * (1 + storage.starPounds.level * starPounds.settings.experienceIncrement)
    -- Lose weight.
    starPounds.loseWeight(weightCost)
    -- Reset stomach.
    starPounds.resetStomach()
    starPounds.resetBreasts()
  end
end

starPounds.modules.respawn = respawn

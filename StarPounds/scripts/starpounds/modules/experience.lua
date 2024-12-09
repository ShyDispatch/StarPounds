local experience = starPounds.module:new("experience")

function experience:init()
  message.setHandler("starPounds.addExperience", function(_, _, ...) return self:add(...) end)
end

function experience:add(amount, multiplier, isLevel)
  if not storage.starPounds.enabled then return end
  -- Legacy mode gains no experience.
  if starPounds.hasOption("legacyMode") then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  local hungerPenalty = starPounds.hasOption("disableHunger") and math.max((starPounds.getStat("hunger") - starPounds.stats.hunger.base) * 0.2, 0) or 0
  multiplier = tonumber(multiplier) or math.max(starPounds.getStat("experienceMultiplier") - hungerPenalty, 0)
  -- Skip everything else if we're just adding straight levels.
  if isLevel then
    storage.starPounds.level = storage.starPounds.level + math.max(math.round(amount))
    return
  end

  local levelModifier = 1 + storage.starPounds.level * self.data.experienceIncrement
  local amount = math.round((amount or 0) * multiplier)
  local amountRequired = math.round(self.data.experienceAmount * levelModifier - storage.starPounds.experience)
  if amount < amountRequired then
    storage.starPounds.experience = math.round(storage.starPounds.experience + amount)
  else
    amount = amount - amountRequired
    storage.starPounds.level = storage.starPounds.level + 1
    storage.starPounds.experience = 0
    self:add(amount, 1)
  end
end

function experience:config()
  return {
    experienceAmount = self.data.experienceAmount,
    experienceIncrement = self.data.experienceIncrement
  }
end

starPounds.modules.experience = experience

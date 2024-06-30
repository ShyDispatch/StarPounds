function init()
  script.setUpdateDelta(5)

  self.healingRate = 1.0 / config.getParameter("healTime", 60)
  self.statGroup = effect.addStatModifierGroup({
    {stat = "protection", amount = 0},
    {stat = "fallDamageMultiplier", effectiveMultiplier = 0}
  })
end

function update(dt)
  status.modifyResourcePercentage("health", self.healingRate * dt)
  effect.setStatModifierGroup(self.statGroup, {
    {stat = "protection", amount = math.ceil(math.min(100 - 100 * math.log(10 * status.resourcePercentage("health"), 10), 100))},
    {stat = "fallDamageMultiplier", effectiveMultiplier = 0}
  })
end

function uninit()
  effect.removeStatModifierGroup(self.statGroup)
end

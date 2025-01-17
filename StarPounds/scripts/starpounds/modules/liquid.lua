local liquid = starPounds.module:new("liquid")

function liquid:get(liq)
  return self.data.liquids[liq] or self.data.liquids.default
end

function liquid:getFood(liq)
  local food = 0
  local liq = self:get(liq)
  -- Iterate to get total food value.
  for foodType, foodAmount in pairs(liq) do
    local foodType = starPounds.foods[foodType]
    if foodType then
      food = food + (foodAmount * foodType.multipliers.food)
    end
  end

  return food
end

-- Add the module.
starPounds.modules.liquid = liquid

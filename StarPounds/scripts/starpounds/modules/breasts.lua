local breasts = starPounds.module:new("breasts")

function breasts:init()
  self.lactationTimer = 0
  self.breasts = self:get()

  message.setHandler("starPounds.getBreasts", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.setMilkType", function(_, _, ...) return self:setMilkType(...) end)
  message.setHandler("starPounds.setMilk", function(_, _, ...) return self:setMilk(...) end)
  message.setHandler("starPounds.gainMilk", function(_, _, ...) return self:gainMilk(...) end)
  message.setHandler("starPounds.loseMilk", function(_, _, ...) return self:loseMilk(...) end)
  message.setHandler("starPounds.lactate", function(_, _, ...) return self:lactate(...) end)
end

function breasts:update(dt)
  self.breasts = self:get()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return end
  --
  self.lactationTimer = math.max(self.lactationTimer - dt, 0)
  -- Check if breast capacity is exceeded.
  if self.breasts.contents > self.breasts.capacity then
    if starPounds.hasOption("disableLeaking") then
      if not starPounds.hasOption("disableMilkGain") then
        storage.starPounds.breasts = self.breasts.capacity
      end
      return
    end
    self.lactationTimer = math.max(self.lactationTimer - dt, 0)
    if self.lactationTimer == 0 then
      local amount = math.min(math.round(self.breasts.fullness * 0.5, 1), 1, self.breasts.contents - self.breasts.capacity)
      -- Lactate away excess
      self:lactate(amount)
      self.lactationTimer = math.round(util.randomInRange({self.data.minimumLactationTime, (self.data.lactationTime * 2) - self.data.minimumLactationTime}))
    end
  end
end

function breasts:get()
  local breastCapacity = self.data.breastCapacity * starPounds.getStat("breastCapacity")
  if starPounds.hasOption("disableLeaking") then
    storage.starPounds.breasts = math.min(storage.starPounds.breasts, breastCapacity)
  end
  local breastContents = storage.starPounds.breasts

  return {
    capacity = breastCapacity,
    type = storage.starPounds.breastType or "milk",
    contents = math.round(breastContents, 4),
    fullness = math.round(breastContents/breastCapacity, 4)
  }
end

function breasts:lactate(amount, noConsume)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Skip if no milk.
  if amount == 0 then return end
  if self.breasts.contents == 0 then return end
  -- Don't spawn milk automatically if leaking is disabled, gain it instead.
  if starPounds.hasOption("disableLeaking") and noConsume then self:gainMilk(amount) return end
  amount = math.min(math.round(amount, 4), self.breasts.contents)
  -- Slightly below and in front the head.
  local spawnPosition = vec2.add(world.entityMouthPosition(entity.id()), {mcontroller.facingDirection(), -1})
  local existingLiquid = world.liquidAt(spawnPosition) and world.liquidAt(spawnPosition)[1] or nil
  local lactationLiquid = root.liquidId(self.breasts.type)
  local doLactation = not existingLiquid or (lactationLiquid == existingLiquid)
  -- Only remove the milk if it actually spawns.
  if doLactation and world.spawnLiquid(spawnPosition, lactationLiquid, amount) and not noConsume then
    self:loseMilk(amount)
  end
end

function breasts:setMilkType(liquidType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  liquidType = tostring(liquidType)
  -- Skip if it's the same type of milk.
  if liquidType == storage.starPounds.breastType then return end
  -- Only allow liquids we have values for.
  local liquids = starPounds.moduleFunc("drinking", "config")
  if not liquids.drinkables[liquidType] then return end
  local currentMilkRatio = liquids.drinkables[self.breasts.type]
  local newMilkRatio = liquids.drinkables[liquidType]
  local convertRatio = currentMilkRatio/newMilkRatio
  storage.starPounds.breastType = liquidType
  self:setMilk(self.breasts.contents * convertRatio, 4)
end

function breasts:milkProduction(food)
  local milkCost = 0
  local milkProduced = 0
  local liquids = starPounds.moduleFunc("drinking", "config")
  if (starPounds.getStat("breastProduction") > 0) and (starPounds.getStat("breastEfficiency") > 0) and not starPounds.hasOption("disableMilkGain") then
    local milkValue = liquids.drinkableVolume * liquids.drinkables[self.breasts.type]
    local maxCapacity = self.breasts.capacity * (starPounds.hasOption("disableLeaking") and 1 or 1.1)
    if self.breasts.contents < maxCapacity then
      milkCost = food * starPounds.getStat("breastProduction")
      milkProduced = math.round((milkCost/milkValue) * math.min(1, starPounds.getStat("breastEfficiency")), 4)
      if (self.breasts.capacity - self.breasts.contents) < milkProduced then
        -- Free after you've maxed out capacity, but you only gain a third as much.
        milkProduced = math.min(math.max((self.breasts.capacity - self.breasts.contents), milkProduced/3), maxCapacity - self.breasts.contents)
        milkCost = math.max(0, self.breasts.capacity - self.breasts.contents) * milkValue
      end
    end
  end
  return milkProduced, milkCost
end

function breasts:setMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Set milk, rounded to 4 decimals.
  amount = math.round(amount, 4)
  storage.starPounds.breasts = amount
end

function breasts:gainMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Set milk, rounded to 4 decimals.
  if starPounds.hasOption("disableMilkGain") then return end
  amount = math.max(math.round(math.min(amount, (self.breasts.capacity * (starPounds.hasOption("disableLeaking") and 1 or 1.1)) - self.breasts.contents), 4), 0)
  storage.starPounds.breasts = math.round(storage.starPounds.breasts + amount, 4)
end

function breasts:loseMilk(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Decrease milk by amount (min: 0)
  amount = math.min(amount, storage.starPounds.breasts)
  storage.starPounds.breasts = math.max(0, math.round(storage.starPounds.breasts - amount, 4))
  return amount
end

starPounds.modules.breasts = breasts

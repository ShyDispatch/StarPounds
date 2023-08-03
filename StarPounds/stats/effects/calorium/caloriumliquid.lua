require "/scripts/messageutil.lua"

function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.02)
  self.tickTime = effect.getParameter("tickTime", 1)
  self.tickTimeStep = effect.getParameter("tickTimeStep", 0)
  self.tickTimeMinimum = effect.getParameter("tickTimeMinimum", self.tickTime)
  self.tickTimer = self.tickTime
  self.minimumLiquid = root.assetJson("/player.config:statusControllerSettings.minimumLiquidStatusEffectPercentage")
  self.sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config")
	self.settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")

  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 2/(1 + self.tickTime))
end

function update(dt)
  if mcontroller.liquidPercentage() < self.minimumLiquid then return end
  if world.entityType(entity.id()) == "npc" or (getmetatable ''.starPounds and getmetatable ''.starPounds.enabled) then
  	-- Check promises.
    wasActive = true
  	promises:update()
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      local bounds = translateRect(mcontroller.boundBox(), mcontroller.position())
      local consumedLiquid = 0
      local liquids = world.liquidAlongLine({bounds[1], bounds[2]}, {bounds[3], bounds[2]})
      local filteredLiquids = jarray()
      for _, liquid in ipairs(liquids) do
        if root.liquidName(liquid[2][1]) == "starpoundscaloriumliquid" then
          filteredLiquids[#filteredLiquids + 1] = liquid
        end
      end

      table.sort(filteredLiquids, function (left, right)
        return right[2][2] < left[2][2]
      end)
      shuffle(filteredLiquids)

      for _, liquid in ipairs(filteredLiquids) do
        consumedLiquid = math.min(consumedLiquid + world.destroyLiquid(liquid[1])[2], 1)
        if consumedLiquid == 1 then break end
      end

      if consumedLiquid > 0 then
        self.tickTime = math.max(self.tickTime - self.tickTimeStep, self.tickTimeMinimum)
        self.tickTimer = self.tickTime

        local foodAmount = self.settings.drinkableVolume * (self.settings.drinkables.starpoundscaloriumliquid or 0)
        local bloatAmount = math.max(0, self.settings.drinkableVolume - foodAmount)
        world.sendEntityMessage(entity.id(), "starPounds.feed", foodAmount * consumedLiquid)
        world.sendEntityMessage(entity.id(), "starPounds.gainBloat", bloatAmount * consumedLiquid)

        promises:add(world.sendEntityMessage(entity.id(), "starPounds.getData"), function(starPounds)
          increaseWeightProgress(starPounds.weight, self.progressStep * consumedLiquid, disableBlob)
        end)

        animator.setSoundPitch("digest", 2/(1 + self.tickTime))
        animator.playSound("digest")
      else
        self.tickTime = effect.getParameter("tickTime", 1)
      end
    end
  else
    effect.expire()
  end
end

function translateRect(rectangle, offset)
  return {
    rectangle[1] + offset[1], rectangle[2] + offset[2],
    rectangle[3] + offset[1], rectangle[4] + offset[2]
  }
end

function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function increaseWeightProgress(weight, step)
  if weight == self.settings.maxWeight then return end
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = self.sizes[currentSizeIndex + 1] and self.sizes[currentSizeIndex + 1].weight or self.settings.maxWeight
  local currentProgress = (weight - currentSize.weight)/(nextWeight - currentSize.weight)
  local targetProgress = math.ceil(currentProgress/step) * step
  local targetWeight = currentSize.weight + (nextWeight - currentSize.weight) * targetProgress
  world.sendEntityMessage(entity.id(), "starPounds.gainWeight", targetWeight - weight)
end

function getSize(weight)
	local sizeIndex = 0
	-- Go through all sizes (smallest to largest) to find which size.
	for i in ipairs(self.sizes) do
		if weight >= self.sizes[i].weight then
			sizeIndex = i
		end
	end

	return self.sizes[sizeIndex], sizeIndex
end

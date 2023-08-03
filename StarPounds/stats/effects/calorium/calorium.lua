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
  if status.uniqueStatusEffectActive("caloriumliquid") then return end
  if world.entityType(entity.id()) == "npc" or (getmetatable ''.starPounds and getmetatable ''.starPounds.enabled) then
  	-- Check promises.
  	promises:update()
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      self.tickTime = math.max(self.tickTime - self.tickTimeStep, self.tickTimeMinimum)
      self.tickTimer = self.tickTime

      promises:add(world.sendEntityMessage(entity.id(), "starPounds.getData"), function(starPounds)
        increaseWeightProgress(starPounds.weight, self.progressStep, disableBlob)
      end)

      animator.setSoundPitch("digest", 2/(1 + self.tickTime))
      animator.playSound("digest")
    end
  else
    effect.expire()
  end
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

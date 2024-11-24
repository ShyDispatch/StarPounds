local lactating = starPounds.module:new("lactating")

function lactating:init()
  self.lactationTimer = 0
end

function lactating:update(dt)
  -- Don't do anything if the mod is disabled.
	if not storage.starPounds.enabled then return end
	-- Don't do anything if eaten.
	if storage.starPounds.pred then return end
  --
  self.lactationTimer = math.max(self.lactationTimer - dt, 0)
	-- Check if breast capacity is exceeded.
	if starPounds.breasts.contents > starPounds.breasts.capacity then
		if starPounds.hasOption("disableLeaking") then
			if not starPounds.hasOption("disableMilkGain") then
				storage.starPounds.breasts = starPounds.breasts.capacity
			end
			return
		end
    self.lactationTimer = math.max(self.lactationTimer - dt, 0)
    if self.lactationTimer == 0 then
      local amount = math.min(math.round(starPounds.breasts.fullness * 0.5, 1), 1, starPounds.breasts.contents - starPounds.breasts.capacity)
			-- Lactate away excess
			starPounds.lactate(amount)
      self.lactationTimer = math.round(util.randomInRange({self.data.minimumLactationTime, (self.data.lactationTime * 2) - self.data.minimumLactationTime}))
    end
	end
end

starPounds.modules.lactating = lactating

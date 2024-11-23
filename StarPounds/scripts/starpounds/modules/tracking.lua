local tracking = starPounds.module:new("tracking")

function tracking:init()
  self.thresholds = starPounds.settings.thresholds.strain
end

function tracking:update(dt)
	-- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Check if statuses don't exist.
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
		local stomachTracker = "starpoundsstomach"
		if starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach2 then
			stomachTracker = "starpoundsstomach3"
		elseif starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach then
			stomachTracker = "starpoundsstomach2"
		end
		if not status.uniqueStatusEffectActive(stomachTracker) then
			starPounds.createStatuses()
			return
		end
	end
	-- Size status.
	if not starPounds.hasOption("disableSizeMeter") then
		if not status.uniqueStatusEffectActive("starpounds"..starPounds.currentSize.size) then
			starPounds.createStatuses()
			return
		end
	end
	-- Tiddy status.
	if starPounds.hasOption("breastMeter") then
		if not status.uniqueStatusEffectActive("starpoundsbreast") then
			starPounds.createStatuses()
			return
		end
	end
end

starPounds.modules.tracking = tracking

local tracking = starPounds.module:new("tracking")

function tracking:init()
  local currentSize, currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
  self.thresholds = starPounds.settings.thresholds.strain
end

function tracking:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't create if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  -- Check if statuses don't exist.
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    local stomachTracker = self:getStomachTracker()
    if not status.uniqueStatusEffectActive(stomachTracker) then
      self:createStatuses()
      return
    end
  end
  -- Size status.
  if not starPounds.hasOption("disableSizeMeter") then
    if not status.uniqueStatusEffectActive("starpounds"..starPounds.currentSize.size) then
      self:createStatuses()
      return
    end
  end
  -- Tiddy status.
  if starPounds.hasOption("breastMeter") then
    if not status.uniqueStatusEffectActive("starpoundsbreast") then
      self:createStatuses()
      return
    end
  end
end

function tracking:uninit()
  self:clearStatuses()
end

function tracking:createStatuses()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  local stomachTracker = self:getStomachTracker()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  -- Removing them just puts them back in order (Size tracker before stomach tracker)
  self:clearStatuses()
  if not starPounds.hasOption("disableSizeMeter") then
    status.addEphemeralEffect(sizeTracker)
  end
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    status.addEphemeralEffect(stomachTracker)
  end
  if starPounds.hasOption("breastMeter") then
    status.addEphemeralEffect("starpoundsbreast")
  end
end

function tracking:clearStatuses()
  local stomachTracker = self:getStomachTracker()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  status.removeEphemeralEffect(stomachTracker)
  status.removeEphemeralEffect(sizeTracker)
  status.removeEphemeralEffect("starpoundsbreast")
  world.sendEntityMessage(entity.id(), "starPounds.expireSizeTracker")
end

function tracking:getStomachTracker()
  local stomachTracker = "starpoundsstomach"
  if starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach2 then
    stomachTracker = "starpoundsstomach3"
  elseif starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach then
    stomachTracker = "starpoundsstomach2"
  end
  return stomachTracker
end

starPounds.modules.tracking = tracking

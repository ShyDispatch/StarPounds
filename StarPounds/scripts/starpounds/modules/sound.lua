local sound = starPounds.module:new("sound")

function sound:update(dt)
	-- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Check if status doesn't exist.
  if not status.uniqueStatusEffectActive("starpoundssound") then
    starPounds.createStatuses()
  end
end

starPounds.modules.sound = sound

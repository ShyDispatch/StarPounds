local sound = starPounds.module:new("sound")

function sound:init()
  if storage.starPounds.enabled then
    status.addEphemeralEffect("starpoundssoundhandler")
  end
end

function sound:update(dt)
	-- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't create if we can't add statuses anyway.
	if status.statPositive("statusImmunity") then return end
  -- Check if status doesn't exist.
  if not status.uniqueStatusEffectActive("starpoundssoundhandler") then
    status.addEphemeralEffect("starpoundssoundhandler")
  end
end
starPounds.modules.sound = sound

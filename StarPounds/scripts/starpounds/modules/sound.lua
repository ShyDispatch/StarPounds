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

function sound:play(soundPool, volume, pitch, loops)
  world.sendEntityMessage(entity.id(), "starPounds.playSound", soundPool, volume, pitch, loops)
end

function sound:stop(soundPool)
  world.sendEntityMessage(entity.id(), "starPounds.stopSound", soundPool)
end

function sound:setVolume(soundPool, volume, rampTime)
  world.sendEntityMessage(entity.id(), "starPounds.setSoundVolume", soundPool, volume, rampTime)
end

function sound:setPitch(soundPool, pitch, rampTime)
  world.sendEntityMessage(entity.id(), "starPounds.setSoundPitch", soundPool, pitch, rampTime)
end

starPounds.modules.sound = sound

require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
end

function update(dt)
  -- Cross script voodoo witch magic.
  if world.entityType(entity.id()) == "player" then
    local progress = getmetatable ''.starPounds and getmetatable ''.starPounds.progress or 0
    if effect.duration() and (effect.duration() > 0) then
      -- Weird numbers just kinda "center" the animation.
       effect.modifyDuration((progress*0.875) - effect.duration() + 6.25)
    end
    if getmetatable ''.starPounds and getmetatable ''.starPounds.hasOption("disableSizeMeter") then
      effect.expire()
    end
  end
end

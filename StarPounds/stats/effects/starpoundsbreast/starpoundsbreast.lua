require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
end

function update(dt)
  -- Cross script voodoo witch magic.
  local starPounds = getmetatable ''.starPounds
  local fullness = math.min(starPounds.breasts.fullness, 1)
  if effect.duration() > 0 then
    -- Weird numbers just kinda "center" the animation.
     effect.modifyDuration(fullness * 87.5 - effect.duration() + 6.25)
  end

  if starPounds and (not starPounds.hasOption("breastMeter")) then
    effect.expire()
  end
end

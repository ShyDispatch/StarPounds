require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  range = effect.getParameter("range", {0, 1})
  maxRangeExpire = effect.getParameter("maxRangeExpire", true)
end

function update(dt)
  -- Cross script voodoo witch magic.
  local starPounds = getmetatable ''.starPounds
  local minimum = range[1] * starPounds.getStat("strainedThreshhold")
  local maximum = range[2] * starPounds.getStat("strainedThreshhold")
  local fullness = math.min(math.max(starPounds.stomach.interpolatedFullness - minimum, 0) / (range[2] - range[1]), 1)
  if effect.duration() > 0 then
    -- Weird numbers just kinda "center" the animation.
     effect.modifyDuration(fullness * 87.5 - effect.duration() + 6.25)
  end

  if starPounds and (starPounds.hasOption("disableStomachMeter") or starPounds.stomach.interpolatedFullness < range[1] or (maxRangeExpire and starPounds.stomach.interpolatedFullness > range[2])) then
    effect.expire()
  end
end

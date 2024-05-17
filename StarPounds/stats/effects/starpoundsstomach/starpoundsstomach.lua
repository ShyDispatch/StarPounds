require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  range = effect.getParameter("range", {0, 1})
  maxRangeExpire = effect.getParameter("maxRangeExpire", true)
end

function update(dt)
  -- Cross script voodoo witch magic.
  local starPounds = getmetatable ''.starPounds
  local minimum = range[1]
  local maximum = range[2]
  local fullness = math.min(math.max(starPounds.stomach.interpolatedFullness - minimum, 0) / (maximum - minimum), 1)
  if effect.duration() > 0 then
    -- Weird numbers just kinda "center" the animation.
     effect.modifyDuration(fullness * 87.5 - effect.duration() + 6.25)
  end

  if starPounds and (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode") or starPounds.stomach.interpolatedFullness < minimum or (maxRangeExpire and starPounds.stomach.interpolatedFullness > maximum)) then
    effect.expire()
  end
end

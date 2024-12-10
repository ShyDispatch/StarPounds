require "/scripts/vec2.lua"
function init()
  range = config.getParameter("range", 2.5)
  querySize = config.getParameter("querySize", 0.5)
  activeItem.setHoldingItem(false)
  script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 5)
  cooldownTime = root.assetJson("/scripts/starpounds/starpounds.config:settings.voreCooldown")
  cooldown = cooldownTime
  cooldownStat = 1
  cooldownFrames = 8
  cursorType = "pred"
  updateCursor()
end

function activate(fireMode, shiftHeld)
  local starPounds = getmetatable ''.starPounds
  if shiftHeld then
    starPounds.moduleFunc("pred", "release")
  elseif cooldown == 0 then
    local mouthPosition = vec2.add(starPounds.mouthPosition(), {0, (starPounds.currentSize.yOffset or 0)})
    local aimPosition = activeItem.ownerAimPosition()
    local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
    local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
    local valid = starPounds.moduleFunc("pred", "eatNearby", targetPosition, range - (starPounds.currentSize.yOffset or 0), querySize)
    if (valid and valid[1]) then
      cooldown = cooldownTime
    end
  end
end

function update(dt, _, shiftHeld)
  local starPounds = getmetatable ''.starPounds
  cooldown = math.max((cooldown or cooldownTime) - (dt/starPounds.getStat("voreCooldown")), 0)
  local mouthPosition = starPounds.mouthPosition()
  if starPounds.currentSize.yOffset then
    mouthPosition[2] = mouthPosition[2] + starPounds.currentSize.yOffset
  end
  local aimPosition = activeItem.ownerAimPosition()
  local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
  local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
  -- Vore icon updater.
  local valid = starPounds.moduleFunc("pred", "eatNearby", targetPosition, range - (starPounds.currentSize.yOffset or 0), querySize, nil, true)
  cursorType = (valid and valid[1]) and (valid[2] and "pred_valid" or "pred_nearby") or "pred"
  -- Stomach icon updater.
  updateCursor(shiftHeld)
end

function canRelease()
  local canRelease = false
  local stomachEntities = getmetatable ''.starPounds.getData("stomachEntities")
  for preyIndex = #stomachEntities, 1, -1 do
    local prey = stomachEntities[preyIndex]
    if not prey.noRelease then
      canRelease = true
      break
    end
  end
  return canRelease
end

function updateCursor(shiftHeld)
  if shiftHeld then
    activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:release%s", canRelease() and "_valid" or ""))
  else
    local readyPercent = 1 - (cooldown/cooldownTime)
    local frame = "_"..math.min(math.floor(readyPercent * (cooldownFrames)), cooldownFrames - 1)
    activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", cursorType, cooldown > 0 and frame or ""))
  end
end

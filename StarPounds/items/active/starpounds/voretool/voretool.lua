require "/scripts/vec2.lua"
function init()
  starPounds = getmetatable ''.starPounds
  range = config.getParameter("range", 2.5)
  querySize = config.getParameter("querySize", 0.5)
  activeItem.setHoldingItem(false)
  script.setUpdateDelta(world.getProperty("nonCombat") and 0 or 5)
  cooldownFrames = 8
  cursorType = "pred"
  updateCursor()
end

function activate(fireMode, shiftHeld)
  if shiftHeld then
    starPounds.moduleFunc("pred", "release")
  elseif starPounds.moduleFunc("pred", "cooldown") == 0 then
    local mouthPosition = vec2.add(starPounds.mcontroller.mouthPosition, {0, (starPounds.currentSize.yOffset or 0)})
    local aimPosition = activeItem.ownerAimPosition()
    local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), range - querySize - (starPounds.currentSize.yOffset or 0))
    local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
    local valid = starPounds.moduleFunc("pred", "eatNearby", targetPosition, range - (starPounds.currentSize.yOffset or 0), querySize)
    if (valid and valid[1]) then
      starPounds.moduleFunc("pred", "cooldownStart")
    end
  end
end

function update(dt, _, shiftHeld)
  starPounds = getmetatable ''.starPounds
  local mouthPosition = starPounds.mcontroller.mouthPosition
  if starPounds.currentSize.yOffset then
    mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
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
  local stomachEntities = starPounds.getData("stomachEntities")
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
    local cooldown = starPounds.moduleFunc("pred", "cooldown")
    local readyPercent = 1 - (cooldown/starPounds.moduleFunc("pred", "cooldownTime"))
    local frame = "_"..math.min(math.floor(readyPercent * (cooldownFrames)), cooldownFrames - 1)
    activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", cursorType, cooldown > 0 and frame or ""))
  end
end

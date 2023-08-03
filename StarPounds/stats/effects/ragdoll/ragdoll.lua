require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  entityType = world.entityType(entity.id())
  baseDuration = effect.duration()
  bounds = mcontroller.boundBox()
  -- No ragdoll for monsters, or if the model is wider than it is tall (since we rotate to be facing down/on the side).
  doRagdoll = entityType ~= "monster"
  if (math.abs(bounds[2]) + math.abs(bounds[4])) < (math.abs(bounds[1]) + math.abs(bounds[3])) then
    doRagdoll = false
  end
end

function update(dt)
  -- Set again if a longer status gets applied.
  if effect.duration() > baseDuration then init() end
  -- Only do this for Players/NPCs.
  if doRagdoll then
    local currentRotation = mcontroller.rotation()
    if mcontroller.onGround() or minimumSpringDistance({
      {0, bounds[4]},
      {0, (bounds[2] + bounds[4])/2},
      {0, bounds[2]}
    }) < 1 then
      if onGround then
        -- If they're laying on the ground, slowly move to a laying down position.
        local leftSpringDistance = minimumSpringDistance({{-0.75, (bounds[2] + bounds[4])/2}})
        local rightSpringDistance = minimumSpringDistance({{0.75, (bounds[2] + bounds[4])/2}})
        local frontSpringDistance = minimumSpringDistance({{0, bounds[4] - 0.5}, {0, bounds[4] - 1.5}})
        local backSpringDistance = minimumSpringDistance({{0, bounds[2] + 0.5}, {0, bounds[2] + 1.5}})
        local direction = leftSpringDistance >= rightSpringDistance and 1 or -1
        mcontroller.setRotation(currentRotation + math.atan(backSpringDistance - frontSpringDistance) * direction * 10 * dt)
      else
        onGround = true
      end
    else
      -- Flippidy spin if they're in the air, based on their velocity. Kind of arbitrary value for velocity -> spins but it looks nice.
      mcontroller.setRotation(currentRotation + dt * -math.pi * mcontroller.xVelocity()/8)
      -- If they get knocked in the air again, restart. Skip if they have no gravity.
      if not mcontroller.zeroG() and not mcontroller.liquidMovement() then
        effect.modifyDuration(baseDuration - effect.duration())
      end
      onGround = false
    end
  elseif not mcontroller.zeroG() and not mcontroller.liquidMovement() and not mcontroller.onGround() then
    -- Just functions as a stun for monsters, extended while in the air.
    effect.modifyDuration(dt)
  end

  -- Stun ooga booga.
  if status.isResource("stunned") then
    if status.resource("health") > 0 then
      status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
    else
      status.setResource("stunned", 0)
    end
  end

  -- Mostly for the player since NPCs/monsters are stunned already.
  mcontroller.controlModifiers({
    facingSuppressed = true,
    movementSuppressed = true
  })

end

function uninit()
  if doRagdoll then
    if entityType == "npc" then
      if world.entityExists(entity.id()) then
        world.callScriptedEntity(entity.id(), "npc.endPrimaryFire")
        world.callScriptedEntity(entity.id(), "npc.endAltFire")
      end
    end
    mcontroller.translate({0, math.abs(vec2.rotate({1, 0}, mcontroller.rotation())[2])})
    mcontroller.setRotation(0)
  end
end

function minimumSpringDistance(points)
  local min = nil
  for _, point in ipairs(points) do
    point = vec2.rotate(point, mcontroller.rotation())
    point = vec2.add(point, mcontroller.position())
    local d = distanceToGround(point)
    if min == nil or d < min then
      min = d
    end
  end
  return min
end

function distanceToGround(point)
  local distance = 1 + (math.abs(bounds[1]) + math.abs(bounds[3]))/2
  local endPoint = vec2.add(point, {0, -distance})
  local intPoint = world.lineCollision(point, endPoint, {"Null", "Block", "Dynamic", "Platform", "Slippery"})
  if intPoint then
    return point[2] - intPoint[2]
  else
    return distance
  end
end

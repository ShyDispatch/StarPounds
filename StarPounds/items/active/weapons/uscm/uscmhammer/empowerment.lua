require "/scripts/util.lua"
require "/scripts/rect.lua"

Empowerment = WeaponAbility:new()

function Empowerment:init()
  self.cooldownTimer = self.cooldownTime

  self.active = false
end

function Empowerment:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.active and not status.overConsumeResource("energy", self.energyPerSecond * self.dt) then
    self.active = false
  end

  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy") then

    if self.active then
      self:setState(self.windup)
    else
      self:setState(self.empower)
    end
  end
end

function Empowerment:empower()
  self.weapon:setStance(self.stances.empower)

  util.wait(self.stances.empower.durationBefore)

  animator.playSound("empower")
  self.active = true

  util.wait(self.stances.empower.durationAfter)
end

function Empowerment:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("charge", true)
  animator.playSound("charge")

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (status.resourcePositive("energy")) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds("charge")
      animator.playSound("full", -1)
    end

    local chargeRatio = math.sin(chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))

    mcontroller.controlModifiers({
      jumpingSuppressed = true,
      runningSuppressed = true
    })

    coroutine.yield()
  end

  animator.stopAllSounds("charge")
  animator.stopAllSounds("full")

  if chargeTimer > self.minChargeTime then
    self:setState(self.fire, chargeTimer / self.chargeTime)
  end
end

function Empowerment:fire(charge)
  self.weapon:setStance(self.stances.fire)
  animator.playSound("activefire")

  local impact, impactHeight = self:impactPosition()

  if impact then
    self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}
    local charge = math.floor(charge * self.maxDistance)
    local directions = {1}
    if self.bothDirections then directions[2] = -1 end
    local positions = self:shockwaveProjectilePositions(impact, charge, directions)
    if #positions > 0 then
      animator.playSound("impact")
      local params = copy(self.projectileParameters)
      params.powerMultiplier = activeItem.ownerPowerMultiplier()
      params.power = params.power * config.getParameter("damageLevelMultiplier")
      params.actionOnReap = {
        {
          action = "projectile",
          inheritDamageFactor = 1,
          type = self.projectileType
        }
      }
      for i,position in pairs(positions) do
        local xDistance = world.distance(position, impact)[1]
        local dir = util.toDirection(xDistance)
        params.timeToLive = (math.floor(math.abs(xDistance))) * 0.025
        world.spawnProjectile("shockwavespawner", position, activeItem.ownerEntityId(), {dir,0}, false, params)
      end
    end
  end

  status.overConsumeResource("energy", status.resourceMax("energy"))
  self.active = false

  util.wait(self.stances.fire.duration)

  self.cooldownTimer = self.cooldownTime
end

function Empowerment:impactPosition()
  local dir = mcontroller.facingDirection()
  local startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  local endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))

  local blocks = world.collisionBlocksAlongLine(startLine, endLine, {"Null", "Block"})
  if #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), endLine[2] - blocks[1][2] + 1
  end
end

function Empowerment:shockwaveProjectilePositions(impactPosition, distance, directions)
  local positions = {}

  for _,direction in pairs(directions) do
    direction = direction * mcontroller.facingDirection()
    local position = copy(impactPosition)
    for i = 0, distance do
      local continue = false
      for _,yDir in ipairs({0, -1, 1}) do
        local wavePosition = {position[1] + direction * i, position[2] + 0.5 + yDir + self.shockwaveHeight}
        local groundPosition = {position[1] + direction * i, position[2] + yDir}
        local bounds = rect.translate(self.shockWaveBounds, wavePosition)

        if world.pointTileCollision(groundPosition, {"Null", "Block", "Dynamic", "Slippery"}) and not world.rectTileCollision(bounds, {"Null", "Block", "Dynamic", "Slippery"}) then
          table.insert(positions, wavePosition)
          position[2] = position[2] + yDir
          continue = true
          break
        end
      end
      if not continue then break end
    end
  end

  return positions
end

function Empowerment:reset()
  animator.setGlobalTag("directives", "")
  animator.setParticleEmitterActive("charge", false)
  animator.stopAllSounds("charge")
end

function Empowerment:uninit()
  self:reset()
end

function Empowerment:aimVector()
  return {mcontroller.facingDirection(), 0}
end

function Empowerment:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end

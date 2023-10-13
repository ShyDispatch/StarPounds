require "/tech/distortionsphere/distortionsphere.lua"

function init()
  initCommonParameters()
  self.ballLiquidSpeed = config.getParameter("ballLiquidSpeed")
  self.baseParameters = sb.jsonMerge(mcontroller.baseParameters(), config.getParameter("transformedMovementParameters"))
  self.baseCollisionPoly = self.baseParameters.collisionPoly
  self.baseBallRadius = self.ballRadius
  self.scale = 1
  self.sizeCap = world.type() == "unknown" and 2.5 or 4
  self.projectiles = jarray()
  self.projectilePositions = jarray()
  local radius = 0.85 * self.scale
  for height = -math.floor(radius), math.floor(radius), 2 do
    for width = -math.floor(radius), math.floor(radius), 2 do
      local height = math.min(math.max(-radius + 0.5, height), radius - 0.5)
      local width = math.min(math.max(-radius + 0.5, width), radius - 0.5)
      self.projectilePositions[#self.projectilePositions + 1] = {width, height}
    end
  end
end

function update(args)
  starPounds = getmetatable ''.starPounds
  local weightMultiplier = self.shrunk and 1 or 1 + math.floor(0.5 + (starPounds.currentSize or {weight = 0}).weight/1.2)/100
  self.scale = self.shrunk and 1 or math.min(math.floor(0.5 + 10 * weightMultiplier ^ (1/3)) * 0.1, self.sizeCap)

  if not self.active and not args.moves["run"] and starPounds.hasSkill("throgSphereShrink") then
    self.shrunk = true
  elseif not self.active then
    self.shrunk = false
  end

  animator.setGlobalTag("shrunkDirectives", self.shrunk and "?hueshift=100" or "")

  local skipScaling = animator.animationState("ballState") == "activate" or animator.animationState("ballState") == "deactivate"
  if self.scale ~= self.lastScale and not skipScaling then
    self.basePoly = starPounds.currentSize and (starPounds.currentSize.controlParameters[starPounds.getVisualSpecies()] or starPounds.currentSize.controlParameters.default).standingPoly or self.baseParameters.standingPoly
    self.transformedMovementParameters.collisionPoly = jarray()
    for i, v in ipairs(self.baseCollisionPoly) do
      self.transformedMovementParameters.collisionPoly[i] = vec2.mul(v, self.scale)
    end
    self.transformedMovementParameters.mass = self.baseParameters.mass * weightMultiplier
    self.transformedMovementParameters.groundForce = self.baseParameters.groundForce * (self.shrunk and weightMultiplier or (1 + (weightMultiplier - 1) * starPounds.getStat("throgSphereForce") * 0.06))
    self.transformedMovementParameters.slopeSlidingFactor = self.baseParameters.slopeSlidingFactor/self.scale
    self.transformedMovementParameters.normalGroundFriction = self.baseParameters.normalGroundFriction * weightMultiplier
    self.transformedMovementParameters.airJumpProfile.jumpControlForce = self.baseParameters.airJumpProfile.jumpControlForce * weightMultiplier
    self.transformedMovementParameters.liquidJumpProfile.jumpControlForce = self.baseParameters.liquidJumpProfile.jumpControlForce * weightMultiplier
    self.ballRadius = self.baseBallRadius * self.scale
    self.lastScale = self.scale
    animator.resetTransformationGroup("ballScale")
    animator.scaleTransformationGroup("ballScale", self.scale)

    if self.active then
  		local targetSize = starPounds.settings.targetSize - 1
      local sizeIndex = starPounds.currentSizeIndex - 1
      local protection = self.shrunk and 0 or math.min(starPounds.getStat("throgSphereArmor") * (sizeIndex/targetSize), starPounds.getStat("throgSphereArmor"))
      status.setPersistentEffects("starpoundsthrogsphere", {{stat = "grit", amount = 1}, {stat = "physicalResistance", amount = protection}})
    end

    self.projectilePositions = jarray()
    if not self.shrunk then
      local radius = 0.85 * self.scale
      for height = -math.floor(radius), math.floor(radius), 2 do
        for width = -math.floor(radius), math.floor(radius), 2 do
          local height = math.min(math.max(-radius + 0.5, height), radius - 0.5)
          local width = math.min(math.max(-radius + 0.5, width), radius - 0.5)
          self.projectilePositions[#self.projectilePositions + 1] = {width, height}
        end
      end
    end
  end

  if starPounds.optionChanged and self.active then
    self.lastScale = nil
    self.force = (starPounds and starPounds.getStat("throgSphereForce") or 0)
  	local targetSize = starPounds.settings.targetSize - 1
    local sizeIndex = starPounds.currentSizeIndex - 1
    local protection = self.shrunk and 0 or math.min(starPounds.getStat("throgSphereArmor") * (sizeIndex/targetSize), starPounds.getStat("throgSphereArmor"))
    status.setPersistentEffects("starpoundsthrogsphere", {{stat = "grit", amount = 1}, {stat = "physicalResistance", amount = protection}})
  end

  if self.active and (not self.shrunk) and mcontroller.groundMovement() then
    self.movementMagnitude = math.min(vec2.mag(mcontroller.velocity())/10, 1) * (0.5 + ((self.scale - 1)/6))
    animator.setSoundVolume("loop", self.movementMagnitude, 0.25)
    animator.setParticleEmitterActive("movementParticles", (#self.projectiles > 0) and not (mcontroller.liquidPercentage() > 0))
    animator.setParticleEmitterEmissionRate("movementParticles", 20 * self.movementMagnitude^2)
  elseif self.active then
    self.movementMagnitude = 0
    animator.setSoundVolume("loop", 0, 1)
    animator.setParticleEmitterActive("movementParticles", false)
  else
    self.movementMagnitude = 0
    animator.setSoundVolume("loop", 0)
    animator.setParticleEmitterActive("movementParticles", false)
  end

  if self.active then
    local position = mcontroller.position()
    local positionCheck = string.format("%s.%s", math.floor(position[1]), math.floor(position[2]))

    local pos1 = vec2.add(position, vec2.mul({-0.45, -0.85}, self.scale))
    local pos2 = vec2.add(position, vec2.mul({0.45, -0.85}, self.scale))
    local rect = {
      pos1[1] - 0.2 * self.scale,
      pos1[2] + 0.05,
      pos2[1] + 0.2 * self.scale,
      pos2[2] - 0.05
    }

    if not starPounds.hasOption("disableTileDamage") and self.scale > 1 and world.type() ~= "unknown" and positionCheck ~= self.lastPositionCheck and vec2.mag(mcontroller.velocity()) > 3 then
      local tiles = world.radialTileQuery(vec2.add(position, {0, -1 - 0.2 * self.scale}), 0.5  + 0.65 * self.scale, "foreground")
      local damage = self.movementMagnitude^2 * ((self.scale > 1.5) and 0.1 or 0.5)
      local damageTiles = jarray()
      for _, tile in ipairs(tiles) do
        if not world.isTileProtected(tile) then
          table.insert(damageTiles, tile)
        end
      end
      world.damageTiles(damageTiles, "foreground", position, (self.scale > 1.5) and "blockish" or "explosive", damage)
    end

    for i, projectile in ipairs(self.projectiles) do
      if not world.entityExists(projectile) then
        table.remove(self.projectiles, i)
      end
    end

    self.lastPositionCheck = positionCheck
  end

  if self.active and #self.projectiles ~= #self.projectilePositions and vec2.mag(mcontroller.velocity()) > 10 then
    for _, projectile in pairs(self.projectiles) do
      if world.entityExists(projectile) then
        world.callScriptedEntity(projectile, "projectile.die")
      end
    end
    self.projectiles = jarray()

    params = {
      power = math.floor(5 + 5 * (self.scale - 1)^2 + 0.5) * status.stat("powerMultiplier"),
      knockback = 10 * self.scale
    }

    local position = mcontroller.position()
    for _, projectilePosition in ipairs(self.projectilePositions) do
      self.projectiles[#self.projectiles + 1] = world.spawnProjectile("starpoundsthrogsphere", vec2.add(position, projectilePosition), entity.id(), {0, 0}, true, params)
    end

  elseif #self.projectiles > 0 and vec2.mag(mcontroller.velocity()) < 10 then
    for _, projectile in pairs(self.projectiles) do
      if world.entityExists(projectile) then
        world.callScriptedEntity(projectile, "projectile.die")
      end
    end
    self.projectiles = jarray()
  end

  restoreStoredPosition()
  if not self.specialLast and args.moves["special1"] then
    attemptActivation()
  end
  self.specialLast = args.moves["special1"]

  if not args.moves["special1"] then
    self.forceTimer = nil
  end

  if self.active then
    mcontroller.controlParameters(self.transformedMovementParameters)
    status.setResourcePercentage("energyRegenBlock", 1.0)

    local controlDirection = 0
    if args.moves["right"] then controlDirection = controlDirection - 1 end
    if args.moves["left"] then controlDirection = controlDirection + 1 end

    updateAngularVelocity(args.dt, inLiquid, controlDirection)
    updateRotationFrame(args.dt)

    checkForceDeactivate(args.dt)
  end

  updateTransformFade(args.dt)

  self.lastPosition = mcontroller.position()
end

function updateAngularVelocity(dt, inLiquid, controlDirection)
  if mcontroller.isColliding() then
    -- If we are on the ground, assume we are rolling without slipping to
    -- determine the angular velocity
    local positionDiff = world.distance(self.lastPosition or mcontroller.position(), mcontroller.position())
    self.angularVelocity = -vec2.mag(positionDiff) / dt / self.ballRadius

    if positionDiff[1] > 0 then
      self.angularVelocity = -self.angularVelocity
    end
  elseif inLiquid then
    if controlDirection ~= 0 then
      self.angularVelocity = 1.5 * self.ballLiquidSpeed * controlDirection
    else
      self.angularVelocity = self.angularVelocity - (self.angularVelocity * 0.8 * dt)
      if math.abs(self.angularVelocity) < 0.1 then
        self.angularVelocity = 0
      end
    end
  end
end

local activate_old = activate
function activate()
  self.scale = 1
  self.lastScale = nil
  animator.resetTransformationGroup("ballScale")
  animator.playSound("loop", -1)
  animator.setSoundVolume("loop", 0)
  activate_old()
  starPounds.updateStats(true)
  status.setPersistentEffects("starpoundsthrogsphere", {{stat = "grit", amount = 1}, {stat = "physicalResistance", amount = math.min(starPounds.getStat("throgSphereArmor") * (starPounds.currentSizeIndex - 1)/3, starPounds.getStat("throgSphereArmor"))}})
end

local deactivate_old = deactivate
function deactivate()
  local wasActive = self.active
  self.scale = 1
  self.lastScale = nil
  animator.resetTransformationGroup("ballScale")
  animator.stopAllSounds("loop")
  deactivate_old()
  starPounds.updateStats(true)
  for _, projectile in pairs(self.projectiles) do
    if world.entityExists(projectile) then
      world.callScriptedEntity(projectile, "projectile.die")
    end
  end
  self.projectiles = jarray()
  status.clearPersistentEffects("starpoundsthrogsphere")
end

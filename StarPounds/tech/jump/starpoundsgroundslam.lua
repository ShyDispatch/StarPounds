require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.multiJumpCount = 1
  self.slamCooldown = 0
  self.slamTimer = 0
  self.rechargeEffectTimer = 0
  refreshJumps()
end

function update(args)
  starPounds = getmetatable ''.starPounds
  self.slamTimer = math.max(self.slamTimer - args.dt, 0)

  if self.slamCooldown > 0 then
    self.slamCooldown = math.max(0, self.slamCooldown - args.dt)
    if self.slamCooldown == 0 then
      self.rechargeEffectTimer = 0.1
      animator.playSound("recharge")
      tech.setParentDirectives("?fade=ccbbff=0.25")
    end
  end

  if self.rechargeEffectTimer > 0 then
    self.rechargeEffectTimer = math.max(0, self.rechargeEffectTimer - args.dt)
    if self.rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  if mcontroller.liquidMovement() or mcontroller.zeroG() then
    self.slamTimer = 0
  end

  if self.slamTimer > 0 then
    mcontroller.setYVelocity(-75)
    if mcontroller.onGround() then
      local slammed = shockwave.fireShockwave()
      self.slamTimer = 0
      self.slamCooldown = 0.5
      if slammed then
        mcontroller.setYVelocity(30)
        self.slamCooldown = math.max(self.slamCooldown, 3 * starPounds.getStat("groundSlamCooldown"))
      end
    end
  else
    if self.slammed then
      self.slamCooldown = math.max(args.dt * 2, self.slamCooldown)
    end
    status.clearPersistentEffects("starpoundsslam")
  end

  animator.setFlipped(mcontroller.facingDirection() == -1)

  local jumpActivated = args.moves["jump"] and not self.lastJump
  self.lastJump = args.moves["jump"]

  updateJumpModifier()

  if jumpActivated and canMultiJump() then
      doMultiJump()
  elseif jumpActivated and canSlam() then
      doSlam()
  else
    if mcontroller.groundMovement() or mcontroller.liquidMovement() then
      refreshJumps()
    end
  end
end

function uninit()
  status.clearPersistentEffects("starpoundsslam")
end

-- after the original ground jump has finished, start applying the new jump modifier
function updateJumpModifier()
  if not self.applyJumpModifier
      and not mcontroller.jumping()
      and not mcontroller.groundMovement() then

    self.applyJumpModifier = true
  end

  if self.applyJumpModifier then
    local maxMod = (1/(starPounds.movementModifier or 1)) - 1
    local modifier = 1 + maxMod * starPounds.getStat("groundSlamHeight")
    mcontroller.controlModifiers({airJumpModifier = modifier})
  end
end

function canMultiJump()
  return self.multiJumps > 0
      and not mcontroller.jumping()
      and not mcontroller.canJump()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function canSlam()
  return not self.slammed
      and self.slamCooldown == 0
      and not mcontroller.jumping()
      and not mcontroller.canJump()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function doMultiJump()
  mcontroller.controlJump(true)
  mcontroller.setYVelocity(math.max(0, mcontroller.yVelocity()))
  self.multiJumps = self.multiJumps - 1
  animator.burstParticleEmitter("multiJumpParticles")
  animator.playSound("multiJumpSound")
end

function doSlam()
  mcontroller.setYVelocity(-75)
  self.weightMultiplier = 1 + math.floor(0.5 + (starPounds.currentSize or {weight = 0}).weight/1.2)/100
  self.scale = math.min(math.floor(0.5 + 10 * self.weightMultiplier ^ (1/3))/10, 4)
  self.slammed = true
  self.slamTimer = 1
  animator.playSound("startSlam")
  status.setPersistentEffects("starpoundsslam", {
    {stat = "fallDamageMultiplier", effectiveMultiplier = 0},
    {stat = "invulnerable", amount = 1},
    {stat = "activeMovementAbilities", amount = 1}
  })
end

function refreshJumps()
  self.multiJumps = self.multiJumpCount
  self.slammed = false
  self.applyJumpModifier = false
end

-- Hammer ability, but ground slams.
shockwave = {
	projectileType = "physicalshockwave",
	projectileParameters = {
		knockback = 40,
		knockbackMode = "facing"
	},
	shockWaveBounds = {-0.4, -1.375, 0.4, 0.0},
	shockwaveHeight = 1.375,
	impactLine = {{0, -1.5}, {0, -4.5}},

	fireShockwave = function()
		local impact
		local position = vec2.add(mcontroller.position(), (starPounds.currentSize.isBlob and {0, -2} or {0, 0}))
		local blocks = world.collisionBlocksAlongLine(vec2.add(position, shockwave.impactLine[1]), vec2.add(position, shockwave.impactLine[2]), {"Null", "Block"})
		if #blocks > 0 then
			impact = vec2.add(blocks[1], {0.5, 0.5})
		end

    local width = {0, 0}
    for _,v in ipairs(mcontroller.collisionPoly()) do
      width[1] = (v[1] < width[1]) and v[1] or width[1]
      width[2] = (v[1] > width[2]) and v[1] or width[2]
    end
    local baseWidth = math.round((math.abs(width[1]) + math.abs(width[2])) * 0.5)

	  if impact then
      local actions = root.assetJson("/projectiles/explosions/regularexplosion2/regularexplosionknockback.config").list
      actions[5] = {action = "sound", options = {"/sfx/melee/shockwave_physical_slam.ogg"}}
      actions[7].harvestLevel = 1
      if starPounds.hasOption("disableTileDamage") or world.type() == "unknown" then
        table.remove(actions, 7)
      end
      table.remove(actions, 4)
      table.remove(actions, 3)
      table.remove(actions, 1)
      local params = {
        actionOnReap = {{action = "actions", list = actions}},
	      powerMultiplier = 0,
	      power = 0,
        onlyHitTerrain = true
      }
      world.spawnProjectile("physicalexplosionknockback", vec2.add(position, {0, -2.5}), entity.id(), {0, 0}, false, params)
      local maxDistance = 1 + 2 * (self.weightMultiplier - 1)^(1/3)
	    local positions = shockwave.shockwaveProjectilePositions(impact, maxDistance + baseWidth)
	    if #positions > 0 then
        local damageUuid = sb.makeUuid()
	      local params = copy(shockwave.projectileParameters)
	      params.powerMultiplier = status.stat("powerMultiplier")
				params.onlyHitTerrain = true
	      params.actionOnReap = {
	        {
	          action = "projectile",
	          inheritDamageFactor = 1,
	          type = shockwave.projectileType,
						config = {
							damageRepeatGroup = "starpoundsgroundslam_"..damageUuid,
							damageRepeatTimeout = 1
						}
	        }
	      }
	      for i, position in pairs(positions) do
	        local xDistance = world.distance(position, impact)[1]
	        local dir = util.toDirection(xDistance)
          local distance = (math.floor(math.max(math.abs(xDistance) - baseWidth, 0)))
          local multiplier = (maxDistance - distance * 0.75) / maxDistance
	        params.timeToLive = distance * 0.025
  	      params.power = math.floor(10 + 30 * (self.scale - 1) + 0.5) * multiplier
          if not starPounds.hasOption("disableTileDamage") and world.type() ~= "unknown" then
            params.actionOnReap[2] = {
              action = "explosion",
              foregroundRadius = 2.5,
              backgroundRadius = 0,
              harvestLevel = 1,
              explosiveDamageAmount = math.floor(0.25 + 0.25 * (self.scale - 1) + 0.5) * multiplier^2
            }
          end
	        world.spawnProjectile("shockwavespawner", position, entity.id(), {dir, 0}, false, params)
	      end
	    end
	  end
    return impact ~= nil
	end,

	shockwaveProjectilePositions = function(impactPosition, maxDistance)
	  local positions = {}

	  for _,direction in pairs({1, -1}) do
	    local position = copy(impactPosition)
	    for i = 0, maxDistance do
	      local continue = false
	      for _,yDir in ipairs({-2, -1, 0, 1}) do
	        local wavePosition = {position[1] + direction * i, position[2] + 0.5 + yDir + shockwave.shockwaveHeight}
	        local groundPosition = {position[1] + direction * i, position[2] + yDir}
	        local bounds = {
						shockwave.shockWaveBounds[1] + wavePosition[1],
						shockwave.shockWaveBounds[2] + wavePosition[2],
						shockwave.shockWaveBounds[3] + wavePosition[1],
						shockwave.shockWaveBounds[4] + wavePosition[2]
					}

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
}

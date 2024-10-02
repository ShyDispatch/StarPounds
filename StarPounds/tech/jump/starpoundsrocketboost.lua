require "/scripts/vec2.lua"

function init()
  self.energyCost = config.getParameter("energyCost")
  self.energyCostPerSecond = config.getParameter("energyCostPerSecond")
  self.boostSpeed = config.getParameter("boostSpeed")
  self.boostForce = config.getParameter("boostForce")

  idle()

  self.activated = false
end

function uninit()
  idle()
end

function update(args)
  starPounds = getmetatable ''.starPounds
  local jumpActivated = args.moves["jump"] and not self.lastJump
  self.lastJump = args.moves["jump"]

  if mcontroller.groundMovement() or mcontroller.liquidMovement() then
    if self.state ~= "idle" then
      idle()
    end

    self.activated = false
  end

  if self.state == "idle" then
    if jumpActivated and canRocketJump() then
      boost()
    end
  elseif self.state == "boost" then
    local velocity = mcontroller.yVelocity()
    if args.moves["jump"]
      and not status.statPositive("activeMovementAbilities")
      and status.overConsumeResource("energy", self.energyCostPerSecond * args.dt * (0.5 + math.min(0.5 * math.max(velocity, 0)/self.boostSpeed, 0.5)))
    then
      if starPounds.movementModifier == 0 then
        starPounds.controlModifiers.speedModifier = 0.1
      end
      -- -40 is the velocity at which the player can take damage from falling.
      local minimumVel = -5
      local forceBoost = 1 + math.max(0, velocity/minimumVel) * 3
      local movementModifier = math.max(starPounds.movementModifier or 1, 0.25)
      local weightBonusSpeed = 1/movementModifier
      local weightBonusForce = 1 + ((starPounds.weightMultiplier or 1) - 1) * 0.25
      mcontroller.controlParameters({gravityMultiplier = 1/world.gravity(mcontroller.position())})
      mcontroller.controlApproachYVelocity(self.boostSpeed * weightBonusSpeed, self.boostForce * weightBonusForce * forceBoost)
    else
      idle()
    end
  end

  animator.setFlipped(mcontroller.facingDirection() < 0)
end

function canRocketJump()
  return not status.resourceLocked("energy")
    and not mcontroller.jumping()
    and not mcontroller.canJump()
    and not mcontroller.liquidMovement()
    and not status.statPositive("activeMovementAbilities")
end

function boost()
  self.state = "boost"
  if self.activated then
    status.overConsumeResource("energy", self.energyCost)
  end
  self.activated = true
  animator.setParticleEmitterActive("boost", true)
  animator.setParticleEmitterActive("ember", true)
  tech.setParentState()
  animator.playSound("boostStart")
  animator.playSound("boost", -1)
end

function idle()
  self.state = "idle"
  status.clearPersistentEffects("movementAbility")
  tech.setParentState()
  animator.setParticleEmitterActive("boost", false)
  animator.setParticleEmitterActive("ember", false)
  animator.stopAllSounds("boost")
end

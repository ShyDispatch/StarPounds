local movement = starPounds.module:new("movement")

function movement:init()
  self.mcontroller = self:getController()
  self.effort = 0
end

function movement:update(dt)
  self.mcontroller = self:getController()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self.effort = 0
  -- Skip this if we're in a sphere.
  if status.stat("activeMovementAbilities") > 1 then return end
  -- Jumping > Running > Walking
  if self.mcontroller.groundMovement then
    if self.mcontroller.walking then self.effort = self.data.effort.walking end
    if self.mcontroller.running then self.effort = self.data.effort.running end
    -- Reset jump checker while on ground.
    self.didJump = false
    -- Moving through liquid takes up to 50% more effort.
    self.effort = self.effort * (1 + math.min(math.round(self.mcontroller.liquidPercentage, 1), 0.5))
  elseif not self.mcontroller.liquidMovement and self.mcontroller.jumping and not self.didJump then
    self.effort = self.data.effort.jumping
  else
    self.didJump = true
  end
end

function movement:getController()
  self.mcontroller = {
    onGround = mcontroller.onGround(),
    groundMovement = mcontroller.groundMovement(),
    liquidMovement = mcontroller.liquidMovement(),
    liquidPercentage = mcontroller.liquidPercentage(),
    zeroG = mcontroller.zeroG(),

    facingDirection = mcontroller.facingDirection(),
    movingDirection = mcontroller.movingDirection(),
    rotation = mcontroller.rotation(),

    crouching = mcontroller.crouching(),
    walking = mcontroller.walking(),
    running = mcontroller.running(),
    canJump = mcontroller.canJump(),
    jumping = mcontroller.jumping(),
    falling = mcontroller.falling(),
    flying = mcontroller.flying(),

    position = mcontroller.position(),
    velocity = mcontroller.velocity(),
    xVelocity = mcontroller.xVelocity(),
    yVelocity = mcontroller.yVelocity(),
  }
  -- Needs some of the above values to calculate properly.
  self.mcontroller.mouthPosition = self:mouthPosition()

  starPounds.mcontroller = self.mcontroller

  return self.mcontroller
end

function movement:controller()
  return self.mcontroller or self:getController()
end

function movement:mouthPosition()
  -- Player module will not have run the function fill for the entity table on the first tick.
  local id = (entity or player).id()
  -- Silly, but when the uninitialising this returns nil.
  if world.entityMouthPosition(id) == nil then return self.mcontroller.position end
  local mouthOffset = {0.375 * self.mcontroller.facingDirection * (self.mcontroller.crouching and 1.5 or 1), (self.mcontroller.crouching and -1 or 0)}
  return vec2.add(world.entityMouthPosition(id), mouthOffset)
end


function movement:getEffort()
  return self.effort
end


starPounds.modules.movement = movement

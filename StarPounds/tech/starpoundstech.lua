local init_old = init or function() end
local update_old = update or function() end
local uninit_old = uninit or function() end

function init()
  init_old()
  -- HEAD TECHS
  ----------------------------------------------------------------------------------
  -- Using ballRadius to detect since it's a common parameter between all distortionsphere techs.
  if config.getParameter("ballRadius") then
    starPounds = getmetatable ''.starPounds
    local activate_old = activate or function() end
    local deactivate_old = deactivate or function() end

    function activate()
      activate_old()
      status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 2}})
      if starPounds then starPounds.updateStats(true) end
    end

    function deactivate()
      deactivate_old()
      if starPounds then starPounds.updateStats(true) end
    end
    -- Already in the throg sphere.
    if config.getParameter("name") ~= "starpoundsthrogsphere" then
      function update(args)
        starPounds = getmetatable ''.starPounds
        self.currentSize = starPounds.currentSize and starPounds.currentSize.size or ""
        if self.currentSize ~= self.oldSize then
          self.basePoly = starPounds.currentSize and (starPounds.currentSize.controlParameters[starPounds.getVisualSpecies()] or starPounds.currentSize.controlParameters.default).standingPoly or mcontroller.baseParameters().standingPoly
        end
        self.oldSize = self.currentSize
        update_old(args)
      end
    end

  -- BODY TECHS
  ----------------------------------------------------------------------------------
  -- Dashes
  -- Using dashControlForce to detect since it's a common parameter that we're going to change.
  elseif config.getParameter("dashControlForce") then
    -- Save this so we can revert to it
    self.baseDashControlForce = self.dashControlForce
    self.baseDashSpeed = self.dashSpeed
    local startDash_old = startDash or function() end
    function startDash(direction)
      starPounds = getmetatable ''.starPounds
      self.dashControlForce = self.baseDashControlForce * starPounds.weightMultiplier
      self.dashSpeed = self.baseDashSpeed * (starPounds.movementModifier or 1)
      startDash_old(direction)
    end

  -- LEG TECHS
  ----------------------------------------------------------------------------------
  -- Wall Jump tech
  elseif config.getParameter("name") == "walljump" then
    -- Allow bigger sizes to hang onto walls.
    function buildSensors()
      local bounds = poly.boundBox(mcontroller.collisionPoly())
      self.wallSensors = {
        right = {},
        left = {}
      }
      for _, offset in pairs(config.getParameter("wallSensors")) do
        table.insert(self.wallSensors.left, {bounds[1] - 0.1, bounds[2] + offset})
        table.insert(self.wallSensors.right, {bounds[3] + 0.1, bounds[2] + offset})
      end
    end

    -- Refresh the size hitbox when checking for walls.
    function checkWall(wall)
      local pos = mcontroller.position()
      local wallCheck = 0
      buildSensors()
      for _, offset in pairs(self.wallSensors[wall]) do
        -- world.debugPoint(vec2.add(pos, offset), world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) and "yellow" or "blue")
        if world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) then
          wallCheck = wallCheck + 1
        end
      end
      return wallCheck >= self.wallDetectThreshold
    end

  -- Rocket Jump Tech.
  elseif config.getParameter("name") == "rocketjump" then
    -- Save this so we can revert to it
    self.baseBoostForce = self.boostForce

    function update(args)
      -- Increase the boost force based on weight multiplier.
      if self.state == "charge" or self.state == "boost" then
        local multiplier = (getmetatable ''.starPounds and getmetatable ''.starPounds.weightMultiplier or 1) - 1
        if self.state == "boost" then
          multiplier = multiplier * 0.2
          mcontroller.controlParameters({gravityMultiplier = 0.1})
        end
        self.boostForce = self.baseBoostForce * (1 + multiplier)
      end
      update_old(args)
    end
  end
end

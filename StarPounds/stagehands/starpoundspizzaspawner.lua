require "/scripts/stagehandutil.lua"
require "/scripts/util.lua"
require "/scripts/companions/util.lua"
require "/scripts/pathutil.lua"

function init()
  self.target = config.getParameter("target", "")
  self.order = config.getParameter("order", {})
  self.npcType = config.getParameter("npcType", "starpoundspizzaemployee")
  self.overrideItems = config.getParameter("overrideItems", {})
  self.beaconColours = config.getParameter("beaconColours", {})
  self.delay = config.getParameter("delay", 10)
  self.poly = root.assetJson("/humanoid.config:movementParameters.standingPoly")

  local bounds = util.boundBox(self.poly)
  local height = bounds[4] - bounds[2] + 5
  local collisionSet = {"Null", "Block", "Platform"}
  self.position = findGroundPosition(stagehand.position(), -height, height, false, collisionSet, bounds)
  local particles = {
    pizza = {
      type = "textured",
      image = "/interface/scripted/starpounds/pizzamenu/pizzas.png",
      fullbright = true,
      size = 0.75,
      destructionAction = "fade",
      destructionTime = 0.75,
      position = {0, 0.125},
      collidesLiquid = false,
      layer = "middle",
      timeToLive = 0.5
    },
    pizzaFloat = {
      type = "textured",
      image = "/interface/scripted/starpounds/pizzamenu/pizzas.png?multiply=ffffff80",
      position = {0, 0.125},
      initialVelocity = {0, 2},
      finalVelocity = {0, 12},
      approach = {0, 6},
      fullbright = true,
      size = 0.5,
      destructionAction = "fade",
      destructionTime = 0.75,
      collidesLiquid = false,
      layer = "back",
      timeToLive = 0.5
    },
    beacon = {{action = "particle", specification = {
      type = "ember",
      position = {0, 0.25},
      initialVelocity = {0, 2},
      finalVelocity = {0, 12},
      approach = {0, 6},
      fullbright = true,
      size = 2.0,
      color = {255, 140, 70, 196},
      destructionAction = "fade",
      destructionTime = 1,
      collidesLiquid = false,
      layer = "back",
      timeToLive = 0.25
    }}},
    splash = {{action = "particle", specification = {
      type = "ember",
      position = {0, 0.25},
      initialVelocity = {0, 2},
      finalVelocity = {0, 12},
      approach = {2, 6},
      fullbright = true,
      size = 2.0,
      color = {255, 70, 35, 196},
      destructionAction = "shrink",
      destructionTime = 1,
      collidesLiquid = false,
      layer = "back",
      timeToLive = 0,
      variance = {
        initialVelocity = {3, 1},
        finalVelocity = {0, 1.0}
      }
    }}}
  }

  for _, colourType in ipairs({"beacon", "splash"}) do
    for i, colour in ipairs(self.beaconColours[colourType] or {}) do
      particles[colourType][i + 1] = sb.jsonMerge(particles[colourType][1], {})
      particles[colourType][i + 1].specification.color = colour
    end
  end

  world.spawnProjectile("invisibleprojectile", {self.position[1], self.position[2] + bounds[2] + 0.25}, entity.id(), {0,0}, true, {
    damageKind = "hidden",
    universalDamage = false,
    onlyHitTerrain = true,
    collisionEnabled = false,
    timeToLive = self.delay,
    periodicActions = {
      {time = 0.05, action = "option", options = particles.splash},
      {time = 0.1, action = "option", options = particles.beacon},
      {time = 0, ["repeat"] = false, action = "particle", specification = particles.pizza},
      {time = 0, ["repeat"] = false, action = "particle", specification = particles.pizzaFloat},
      {time = 0, ["repeat"] = false, action = "sound", options = {"/sfx/interface/sniper_mark_pitch5.ogg"}},
      {time = 1, action = "particle", specification = particles.pizza},
      {time = 1, action = "particle", specification = particles.pizzaFloat},
      {time = 1, action = "sound", options = {"/sfx/interface/sniper_mark_pitch5.ogg"}},
    }
  })
end

function update(dt)
  self.delay = math.max(self.delay - dt, 0)
  if self.delay == 0 then
    local npcId = world.spawnNpc(self.position, "human", self.npcType, world.threatLevel(), nil, {scriptConfig = {order = self.order, target = self.target, overrideItems = self.overrideItems}})
    world.callScriptedEntity(npcId, "status.addEphemeralEffect", "beamin")
    stagehand.die()
  end
end

function findGroundPosition(position, minHeight, maxHeight, avoidLiquid, collisionSet, bounds)
  -- Align the vertical position of the bottom of our feet with the top
  -- of the row of tiles below:
  position = {position[1], math.ceil(position[2]) - (bounds[2] % 1)}

  local groundPosition
  for y = 0, math.max(math.abs(minHeight), math.abs(maxHeight)) do
    -- -- Look up
    if y <= maxHeight and validStandingPosition({position[1], position[2] + y}, avoidLiquid, collisionSet, bounds) then
      groundPosition = {position[1], position[2] + y}
      break
    end
    -- Look down
    if -y >= minHeight and validStandingPosition({position[1], position[2] - y}, avoidLiquid, collisionSet, bounds) then
      groundPosition = {position[1], position[2] - y}
      break
    end
  end

  if groundPosition and avoidLiquid then
    local liquidLevel = world.liquidAt(rect.translate(bounds, groundPosition))
    if liquidLevel and liquidLevel[2] >= 0.1 then
      return position
    end
  end

  return groundPosition or position
end

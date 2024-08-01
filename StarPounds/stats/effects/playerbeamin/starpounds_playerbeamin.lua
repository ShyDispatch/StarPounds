require "/scripts/messageutil.lua"

starPounds = getmetatable ''.starPounds

local init_old = init
local update_old = update
init = function() end

local didQuery = false
local didOldInit = false
local oldInitDelay = 0.1
local foundTarget = false

if not starPounds or
  not starPounds.isEnabled() or
  not starPounds.hasOption("teleportationVore") or
  starPounds.hasOption("disablePrey")
then
  didQuery = true
  oldInitDelay = 0
end

function update(dt)
  -- Check promises.
  promises:update()
  if not didQuery then
    local entities = world.entityQuery(mcontroller.position(), 1, {order = "nearest", includedTypes = {"player", "npc"}, withoutEntityId = entity.id()}) or jarray()
    for _, target in ipairs(entities) do
      promises:add(world.sendEntityMessage(target, "starPounds.eatEntity", entity.id(), {ignoreSkills = true, ignoreCapacity = true, noEnergyCost = true, noSwallowSound = true}), function(success)
        if success then foundTarget = true end
      end)
    end
  end
  didQuery = true

  -- Remove the beam status if we found a pred.
  if foundTarget then
    effect.setParentDirectives("")
    effect.expire()
    return
  end

  -- Wait 0.1 seconds before doing the old init (since it spawns a knockback projectile).
  oldInitDelay = math.max(oldInitDelay - dt, 0)
  if oldInitDelay == 0 and not didOldInit then
    didOldInit = true
    init_old()
  end
  -- Continue with normal beam stuff.
  update_old(dt)
end

require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.spawnInterval = config.getParameter("spawnInterval")
  self.spawnPosition = vec2.add(entity.position(), config.getParameter("spawnOffset"))

  self.types = config.getParameter("npctypes")
end

function update(dt)
  if not self.spawnTimer then
    self.spawnTimer = util.randomInRange(self.spawnInterval)
  end

  self.spawnTimer = math.max(0, self.spawnTimer - dt)
  if self.spawnTimer == 0 then
    local spawn = util.randomFromList(self.types)
    local species = util.randomFromList(spawn.species)
    local npcId = world.spawnNpc(self.spawnPosition, species, spawn.type, 1)
    world.callScriptedEntity(npcId, "status.addEphemeralEffect", "beamin")
    if spawn.displayNametag then
      world.callScriptedEntity(npcId, "npc.setDisplayNametag", true)
    end

    self.spawnTimer = nil
  end
end

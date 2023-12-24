require "/scripts/messageutil.lua"

function init()
  script.setUpdateDelta(5)
  self.progressStep = effect.getParameter("progressStep", 0.01) * effect.duration()
  self.sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes")
	self.settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")
  animator.setSoundVolume("digest", 0.75)
  animator.setSoundPitch("digest", 1)
  if world.entityType(entity.id()) == "npc" or (getmetatable ''.starPounds and getmetatable ''.starPounds.enabled) then
    promises:add(world.sendEntityMessage(entity.id(), "starPounds.getData"), function(starPounds)
      increaseWeightProgress(starPounds.weight, self.progressStep)
      effect.expire()
    end)
  end
end

function update(dt)
  promises:update()
end

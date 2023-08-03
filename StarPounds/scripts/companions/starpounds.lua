require "/scripts/messageutil.lua"

local init_old = init or function() end
local respawnRecruit_old = recruitSpawner.respawnRecruit

-- Run on load.
function init()
  init_old()
  message.setHandler("recruits.digestingRecruit", simpleHandler(function() player.radioMessage("starpounds_digestcrew") end))
  message.setHandler("recruits.digestedRecruit", simpleHandler(
    function(recruitUuid)
      local recruit = recruitSpawner.followers[recruitUuid] or recruitSpawner.shipCrew[recruitUuid]
      if not recruit then
        sb.logInfo("Cannot dismiss unknown recruit %s", recruitUuid)
        return
      end
      if recruit.spawning then return end
      recruitSpawner.followers[recruitUuid] = nil
      recruitSpawner.shipCrew[recruitUuid] = nil

      recruitSpawner:markDirty()
    end)
  )
end

function recruitSpawner:respawnRecruit(uuid, recruit)
  if recruit.storage then
    if recruit.storage.starPounds then
      recruit.storage.starPounds.pred = nil
    end
  end
  respawnRecruit_old(self, uuid, recruit)
end

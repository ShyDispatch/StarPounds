function init()
  dungeonId = world.dungeonId(object.position())
  object.setInteractive(true)
end

function onInteraction(args)
  object.smash()
end

function die(smash)
  world.setTileProtection(dungeonId, false)
end

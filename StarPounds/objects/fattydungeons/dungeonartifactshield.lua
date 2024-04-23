function init()
  dungeonId = world.dungeonId(object.position())
  radioMessage = config.getParameter("radioMessage")
  object.setInteractive(true)
end

function onInteraction(args)
  if radioMessage then
    world.sendEntityMessage(args.sourceId, "queueRadioMessage", radioMessage)
  end
  object.smash()
end

function die(smash)
  world.setTileProtection(dungeonId, false)
end

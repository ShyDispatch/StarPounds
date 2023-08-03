function init()
  animator.setAnimationState("beamaxe", "active")
  object.setInteractive(true)
end

function showBeamaxe()
  animator.setAnimationState("beamaxe", "active")
  object.setInteractive(true)
end

function onInteraction(args)
  animator.setAnimationState("beamaxe", "inactive")
  object.setInteractive(false)
  world.sendEntityMessage(args.sourceId, "giveBeamaxe")

  for parameter,value in pairs(config.getParameter("pickedUpParameters")) do
    object.setConfigParameter(parameter, value)
  end
end

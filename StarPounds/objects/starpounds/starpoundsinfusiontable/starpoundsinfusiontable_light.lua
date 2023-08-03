function init()
  if storage.state == nil then storage.state = config.getParameter("defaultLightState", true) end

  if config.getParameter("inputNodes") then
    processWireInput()
  end

  setLightState(storage.state)
end

function onNodeConnectionChange(args)
  processWireInput()
end

function onInputNodeChange(args)
  processWireInput()
end

function processWireInput()
  if object.isInputNodeConnected(0) then
    storage.state = object.getInputNodeLevel(0)
    setLightState(storage.state)
  end
end

function setLightState(newState)
  if newState then
    animator.setAnimationState("light", "on")
    object.setSoundEffectEnabled(true)
    if animator.hasSound("on") then
      animator.playSound("on");
    end
    --TODO: support lightColors configuration
    object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
  else
    animator.setAnimationState("light", "off")
    object.setSoundEffectEnabled(false)
    if animator.hasSound("off") then
      animator.playSound("off");
    end
    object.setLightColor(config.getParameter("lightColorOff", {0, 0, 0}))
  end
end

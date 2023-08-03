require "/scripts/vec2.lua"

function init()
  storage.timer = storage.timer or 0
  
  if storage.active == nil then
    updateActive()
  end
  object.setSoundEffectEnabled(storage.active)
  if storage.state == nil then storage.state = config.getParameter("defaultLightState", true) end

  self.interactive = config.getParameter("interactive", true)
  object.setInteractive(self.interactive)  

  self.fireTime = config.getParameter("fireTime", 1)
  self.fireTimeVariance = config.getParameter("fireTimeVariance", 0)
  self.projectile = config.getParameter("projectile")
  self.projectileConfig = config.getParameter("projectileConfig", {})
  self.projectilePosition = config.getParameter("projectilePosition", {0, 0})
  self.projectileDirection = config.getParameter("projectileDirection", {1, 0})
  self.inaccuracy = config.getParameter("inaccuracy", 0)
  if config.getParameter("inputNodes") then
    processWireInput()
  end  

  self.projectilePosition = object.toAbsolutePosition(self.projectilePosition)
  setLightState(storage.state)  
end

function update(dt)
  if storage.active then
    storage.timer = storage.timer - dt
    if storage.timer <= 0 then
      storage.timer = self.fireTime + (self.fireTimeVariance * math.random() - self.fireTimeVariance / 2)
      shoot()
    end
  end
end

function onNodeConnectionChange(args)
  updateActive()
  processWireInput()  
end

function onInputNodeChange(args)
  updateActive()
  processWireInput()  
end

function onInteraction(args)
  if not config.getParameter("inputNodes") or not object.isInputNodeConnected(0) then
    storage.state = not storage.state
    setLightState(storage.state)
  end
end

function processWireInput()
  if object.isInputNodeConnected(0) then
    object.setInteractive(false)
    storage.state = object.getInputNodeLevel(0)
    setLightState(storage.state)
  elseif self.interactive then
    object.setInteractive(true)
  end
end


function shoot()
  --animator.playSound("shoot")
  local projectileDirection = vec2.rotate(self.projectileDirection, sb.nrand(self.inaccuracy, 0))
  world.spawnProjectile(self.projectile, self.projectilePosition, entity.id(), projectileDirection, false, self.projectileConfig)
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

function updateActive()
  local active = (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0)
  if active ~= storage.active then
    storage.active = active
    if active then
      storage.timer = 0
      --animator.setAnimationState("trapState", "on")
      --object.setLightColor(config.getParameter("activeLightColor", {0, 0, 0, 0}))
      --object.setSoundEffectEnabled(true)
      --animator.playSound("on");
    else
      --animator.setAnimationState("trapState", "off")
      --object.setLightColor(config.getParameter("inactiveLightColor", {0, 0, 0, 0}))
      --object.setSoundEffectEnabled(false)
      --animator.playSound("off");
    end
  end
end

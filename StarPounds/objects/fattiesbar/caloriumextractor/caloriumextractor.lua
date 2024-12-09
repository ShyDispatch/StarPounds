require "/scripts/messageutil.lua"
function init()
  local liquid = config.getParameter("liquid", "starpoundscaloriumliquid")
  setLiquidType(liquid)
  heartbeatTimer = 0
  message.setHandler("heartbeat", simpleHandler(heartbeat))
end

function update(dt)
  heartbeatTimer = math.max(heartbeatTimer - script.updateDt(), 0)
  animator.setAnimationState("pump", heartbeatTimer == 0 and "off" or "on")
  animator.setAnimationState("liquid", heartbeatTimer == 0 and "off" or "on")
  -- Check promises.
  promises:update()
end

function setLiquidType(liquidName)
  local liquidConfig = root.liquidConfig(liquidName).config
  local rgb = liquidConfig.color
  animator.setGlobalTag("liquidImage", string.format("%s?multiply=%s", liquidConfig.texture, string.format("%02X%02X%02X%02X", rgb[1], rgb[2], rgb[3], rgb[4])))
  object.setLightColor(liquidConfig.radiantLight or {0, 0, 0})
end

function heartbeat()
  -- Makes the animation stop a little more in sync, but still finish the whole loop.
  if heartbeatTimer < 0.25 then
    heartbeatTimer = heartbeatTimer + 0.5
  end
end

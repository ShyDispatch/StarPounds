require "/scripts/messageutil.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("treadmill.init", simpleHandler(
  	function(pos, direction, id)
      position = pos
      facing = direction
      target = id

      world.sendEntityMessage(entity.id(), "queueRadioMessage", "starpounds_treadmill")
  	end
  ))
  message.setHandler("treadmill.uninit", simpleHandler(effect.expire))
end

function update(dt)
  if target and world.entityExists(target) then
    -- Keep status alive and hold player in position.
    effect.modifyDuration(dt)
    mcontroller.setPosition(vec2.add(position, world.entityPosition(target)))
    -- Kick the player off the treadmill if they jump or run the other way.
    if mcontroller.jumping() or (mcontroller.movingDirection() ~= facing and (mcontroller.walking() or mcontroller.running())) then
      effect.expire()
      world.sendEntityMessage(target, "treadmill.uninit")
    -- Disable movement when out of energy.
    elseif not status.resourcePositive("energy") or status.resourceLocked("energy") then
      mcontroller.controlModifiers({movementSuppressed = true})
    -- Sweat and consume energy when running.
    elseif mcontroller.running() then
      status.addEphemeralEffect("sweat")
      status.overConsumeResource("energy", status.resourceMax("energy") * 0.05 * dt)
    end
  end
end

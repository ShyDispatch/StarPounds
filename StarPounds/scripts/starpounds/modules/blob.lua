local blob = starPounds.module:new("blob")

function blob:init()
  self.firstUpdate = false
  self.isBlob = false
  self.blobProjectileActive = false
  self.size = ""
  self.bounds = rect.pad(mcontroller.boundBox(), {0, -1})
  self.playerWidth = math.abs(self.bounds[3] - self.bounds[1]) * 0.5
  self.doorDeltaTime = self.data.doorDelta * self.data.scriptDelta
  self.doorTimer = 0
end

function blob:update(dt)
  self.isBlob = starPounds.currentSize.isBlob
  -- Projectile spawner for the hitbox/magnet.
  self.blobProjectileActive = self.blobProjectile and world.entityExists(self.blobProjectile)
  if not self.blobProjectileActive and self:doProjectile() then
    self.blobProjectile = world.spawnProjectile("starpoundsblobhitbox", mcontroller.position(), entity.id(), {0, 0}, true)
  elseif self.blobProjectileActive and not self:doProjectile() then
    world.callScriptedEntity(self.blobProjectile, "projectile.die")
  end
  -- Delay first update loop by 1 tick.
  if not self.firstUpdate then self.firstUpdate = true return end
  -- Don't run anything after this if we're not blob size.
  if not self.isBlob then return end
  -- Bounds updater for blob door interaction.
  if self.size ~= starPounds.currentSize.size then
    self.size = starPounds.currentSize.size
    if self.isBlob then
      self.bounds = rect.translate(rect.pad(mcontroller.boundBox(), {0, self.data.boundsPadding}), self.data.boundsOffset)
      self.width = math.abs(self.bounds[3] - self.bounds[1]) * 0.5
    end
  end
  -- Automatically open doors in front/close doors behind since blob's cant reach to interact.
  if not starPounds.hasOption("disableBlobDoors") then
    self:automaticDoors(dt)
  end
end

function blob:doProjectile()
  if not self.isBlob then return false end
  if starPounds.hasOption("disableBlobCollision") then return false end
  if status.stat("activeMovementAbilities") >= 1 then return false end
  return true
end

function blob:automaticDoors(dt)
  -- Run this less often.
  self.doorTimer = math.max(self.doorTimer - dt, 0)
  if self.doorTimer > 0 then return end
  self.doorTimer = self.doorDeltaTime * dt

  if not (mcontroller.running() or mcontroller.walking()) then
    return
  end

  local openBounds = rect.translate(self.bounds, mcontroller.position())
  local closeBounds = {table.unpack(openBounds)}

  if mcontroller.movingDirection() > 0 then
    openBounds[1], openBounds[3] = openBounds[3] + self.data.openRange[1], openBounds[3] + self.data.openRange[2]
    closeBounds[3], closeBounds[1] = closeBounds[1] - self.data.closeRange[1], closeBounds[1] - self.data.closeRange[2]
  else
    openBounds[3], openBounds[1] = openBounds[1] + self.data.openRange[1], openBounds[1] - self.data.openRange[2]
    closeBounds[1], closeBounds[3] = closeBounds[3] + self.data.closeRange[1], closeBounds[3] + self.data.closeRange[2]
  end

  if world.rectTileCollision(openBounds, {"dynamic"}) then
    self:queryDoors(openBounds, nil, "openDoor")
  end
  self:queryDoors(closeBounds, 1, "closeDoor")
end

function blob:queryDoors(bounds, minimumDistance, message)
  local doorIds = world.objectQuery(rect.ll(bounds), rect.ur(bounds))
  for _, doorId in ipairs(doorIds) do
    local valid = false
    if world.isEntityInteractive(doorId) and contains(world.getObjectParameter(doorId, "scripts", jarray()), "/objects/wired/door/door.lua") then
      local position = world.entityPosition(doorId)
      local spaces = world.getObjectParameter(doorId, "closedMaterialSpaces", world.objectSpaces(doorId))
      -- Check if the object is actually in the rect because queries suck.
      for i = 1, #spaces do
        local space = vec2.add(spaces[i], world.entityPosition(doorId))
        if rect.contains(bounds, space) then
          valid = true
          break
        end
      end
    end
    -- Message valid doors.
    if valid then
      world.sendEntityMessage(doorId, message)
    end
  end
end

starPounds.modules.blob = blob

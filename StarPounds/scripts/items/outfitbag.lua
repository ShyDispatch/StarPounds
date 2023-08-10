require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

function init()
  self.recoil = 0
  self.recoilRate = 0

  self.fireOffset = config.getParameter("fireOffset")
  self.outfitKey = config.getParameter("outfitKey", "fatty")
  self.outfitTypes = config.getParameter("outfitTypes", jarray())
  updateAim()

  self.active = false
  storage.fireTimer = storage.fireTimer or 0
end

function update(dt, fireMode, shiftHeld)
  promises:update()
	updateAim()

	storage.fireTimer = math.max(storage.fireTimer - dt, 0)

	self.recoilRate = self.active and 0 or math.max(1, self.recoilRate + (10 * dt))
	self.recoil = math.max(self.recoil - dt * self.recoilRate, 0)

	if self.active and not storage.firing and storage.fireTimer <= 0 then
		if self.fireMode == "alt" then
			local entityIds = world.entityQuery(activeItem.ownerAimPosition(), 2, {["order"] = "nearest", includedTypes = {"npc", "player"}, withoutEntityId = player.id()})
			for _, id in ipairs(entityIds) do
				if world.entityHealth(id)[1] > 0 then self.entityId = id break end
			end
		else
			self.entityId = player.id()
		end

		if not self.entityId then
			self.active = false
			return nil
		end

		self.recoil = math.pi/2 - self.aimAngle
		activeItem.setArmAngle(math.pi/2)
		if animator.animationState("firing") == "off" then
			animator.setAnimationState("firing", "fire")
		end
		storage.fireTimer = config.getParameter("fireTime", 1.0)
		storage.firing = true
	end

	self.active = false

	if storage.firing and animator.animationState("firing") == "off" and self.entityId then
    promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.getDirectives", self.entityId), function(directives)
    promises:add(world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.getVisualSpecies", world.entitySpecies(self.entityId)), function(species)
      for _, outfitType in ipairs(self.outfitTypes) do
        local itemConfig = {
          name = self.outfitKey..species:lower()..outfitType,
          parameters = {directives = "?"..directives},
          count = 1
        }
        if pcall(root.itemType, itemConfig.name) then
      		player.giveItem(itemConfig)
        else
          sb.logError("%s","Outfit bag could not find item: "..itemConfig.name)
        end
      end
      item.consume(1)
    end) end)
		storage.firing = false
	end
end

function activate(fireMode, shiftHeld)
	if not storage.firing then
		self.active = true
		self.fireMode = fireMode
	end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  self.aimAngle = self.aimAngle + self.recoil
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end

function holdingItem()
  return true
end

function recoil()
  return false
end

function outsideOfHand()
  return false
end

-- code edits by Joliair
-- updated by LittleVulpine/Apple

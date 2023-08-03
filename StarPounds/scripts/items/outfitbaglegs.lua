require "/scripts/vec2.lua"

function init()
  self.recoil = 0
  self.recoilRate = 0

  self.fireOffset = config.getParameter("fireOffset")
  self.outfitKey = config.getParameter("outfitKey", "fatty")
  updateAim()

  self.active = false
  storage.fireTimer = storage.fireTimer or 0
  
end

function update(dt, fireMode, shiftHeld)
	updateAim()

	storage.fireTimer = math.max(storage.fireTimer - dt, 0)

	if self.active then
		self.recoilRate = 0
	else
		self.recoilRate = math.max(1, self.recoilRate + (10 * dt))
	end
	self.recoil = math.max(self.recoil - dt * self.recoilRate, 0)

	if self.active and not storage.firing and storage.fireTimer <= 0 then
		if self.FMode == "alt" then
			local entityIds = world.entityQuery(activeItem.ownerAimPosition(), 2, {["order"] = "nearest", includedTypes = {"npc", "player"}, withoutEntityId = player.id()})
			 
			for i = 1, #entityIds+1 do
				if entityIds[i] ~= nil then
					if world.entityHealth(entityIds[i])[1] > 0 then
						self.EntityId = entityIds[i]
						break
					end
				end
			end
		else
			self.EntityId = player.id()
		end
		
		if self.EntityId == nil then
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

	if storage.firing and animator.animationState("firing") == "off" and self.EntityId ~= nil then
		local item1 = {name=self.outfitKey..world.entitySpecies(self.EntityId):lower().."legs", count=1}
		
		if not (pcall(root.itemType, item1.name) or pcall(root.itemType, item2.name)) then
			storage.firing = false
			sb.logError("%s","No species item found")
			return
		end
	  
		item.consume(1)
		if player then
			local portrait = world.entityPortrait(self.EntityId, "full")
			local bodyDirectives = ""
			for key, value in pairs(portrait) do
				if string.find(portrait[key].image, "body.png") then
					local body_image =  portrait[key].image
					local directive_location = string.find(body_image, "replace")
					bodyDirectives = string.sub(body_image,directive_location)
					break
				end
			end
			item1.parameters = {directives = "?"..bodyDirectives}
			if pcall(root.itemType, item1.name) then
				player.giveItem(item1)
			end
			if pcall(root.itemType, item2.name) then
				player.giveItem(item2)
			end
		end
		storage.firing = false
		return nil
	end
end

function activate(fireMode, shiftHeld)
	if not storage.firing then
		self.active = true
		self.FMode = fireMode
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
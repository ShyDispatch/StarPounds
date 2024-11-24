local oSB = starPounds.module:new("oSB")

function oSB:init()
  self.voreCooldown = 0
  self.lactateBindTimer = self.data.lactateBindTime
end

function oSB:update(dt)
  -- Skip this module if we don't have input access.
  if not input then return end
  -- Menu time.
	for _, menu in ipairs({"menu", "skills", "accessories", "options"}) do
		if input.bindDown("starpounds", menu.."Menu") then
			player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:"..menu})
		end
	end
	-- Toggle the mod.
	if input.bindDown("starpounds", "toggle") then
		starPounds.toggleEnable()
	end
	-- Burpy.
	if input.bindDown("starpounds", "belch") then
		starPounds.belch(0.75, starPounds.belchPitch(), nil, false)
	end
	-- Eat entity.
	self.voreCooldown = math.max((self.voreCooldown or 0) - (dt/starPounds.getStat("voreCooldown")), 0)
	if input.bindDown("starpounds", "voreEat") then
		if player.isAdmin() or self.voreCooldown == 0 then
			local mouthPosition = starPounds.mouthPosition()
			local aimPosition = player.aimPosition()
			local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), 2)
			local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
			local success = starPounds.eatNearbyEntity(targetPosition, 3, 1)
			if success then self.voreCooldown = starPounds.settings.voreCooldown end
		end
	end
	-- Regurgitate last entity.
	if input.bindDown("starpounds", "voreRegurgitate") then
		starPounds.releaseEntity()
	end
	-- Lactate.
	if input.bind("starpounds", "lactate") then
		if input.bindDown("starpounds", "lactate") then
			starPounds.lactate(math.random(5, 10)/10)
		end
		-- Lactate constantly after holding for 1 second.
		self.lactateBindTimer = math.max(self.lactateBindTimer - dt, 0)
		if self.lactateBindTimer == 0 then
			starPounds.lactate(math.random(5, 10)/10)
			self.lactateBindTimer = self.data.lactateInterval
		end
	else
		self.lactateBindTimer = self.data.lactateBindTime
	end
end

starPounds.modules.oSB = oSB

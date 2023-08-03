require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	starPounds.init()
	starPounds.messageHandlers()
	storage.starPounds = storage.starPounds or starPounds.baseData
	object.setInteractive(true)

	dialog = {
		swallow = {
			"Not every day food comes to me~",
			"You went down easy, <player>~",
			"Didn't think you'd want to be bug butt so bad~",
			"Aaaah~ You tasted nice, <player>~",
			"Mrrrrrrr~ Feeling that bulge go down is always the best~",
			"Mmmm~ Delicious~",
			"Aaaah~ Guess you're gonna be my assfat, <player>~",
			"Hope you don't mind the belly rubs I'm giving myself~",
			"Nothing like a live, squirmy meal to treat myself~"
		},
		struggle = {
			"Yanno, I've eaten muuuuuch bigger~",
			"Mmmm~ Keep up the massage in there~",
			"You're a good belly pet, <player>~",
			"Mrrrrr~ Your squirming feels sooooo good~",
			"Hey you wanted in, now settle down and let the belly churn ya~.",
			"We both know where this is going, <player>~",
			"Shush, <player>- you'll on be my butt soon enough~",
			"Bwuh, feisty lil snack!~"
		},
		stop = {
			"Oh... Bored of me already?",
			"You have other things to do? Okay...",
			"Don't want to be bug butt?",
			"Bweh, fiiiiiine.",
			"I thought you wanted to be food?"
		},
		digested = {
			"You make good assfat, <player>~",
			"Gonna have to write your name on my butt... <player>, was it?~",
			"You were good food, <player>~",
			"Think you'll keep me full for... an hour or so~",
			"That was fun while it lasted... At least I'm a little thicker from it~",
			"Thanks for volunteering, snack~",
			"I think you look cuter wobbling around back there~",
			"Mmm~ I feel so much softer~",
			"Aaah~ That hit the spot",
			"My pants are feeling tighter~"
		}
	}

	regurgitateTimer = 0
end

function onInteraction(args)
	starPounds.eatEntity(args.sourceId)
end

function onNpcPlay(npcId)
	onInteraction({sourceId = npcId})
end

function update(dt)
	-- Check promises.
	promises:update()

	starPounds.voreCheck()
	starPounds.digest(dt)

	if storage.starPounds.entityStomach[1] then
		lastEntity = storage.starPounds.entityStomach[1]
	end

	if regurgitateTimer > 0 and (regurgitateTimer - dt) <= 0 then
		playSound("talk", 1, 1.25)
		animator.burstParticleEmitter("emotesad")
		object.say(tostring(dialog.stop[math.random(1, #dialog.stop)]:gsub("<player>", world.entityName(lastEntity.id).."^reset;")))
		world.sendEntityMessage(lastEntity.id, "starPounds.getReleased", entity.id())
	end

	regurgitateTimer = math.max(0, regurgitateTimer - dt)
end

function playSound(soundPool, volume, pitch, loops)
	if not ((soundPool == "digest" or soundPool == "struggle") and regurgitateTimer > 0) then
		animator.setSoundVolume(soundPool, volume or 1, 0)
		animator.setSoundPitch(soundPool, pitch or 1, 0)
		animator.playSound(soundPool, loops)
		if soundPool == "struggle" then
			if math.random(1, 600) == 1 then
				playSound("talk", 1, 1.25)
				animator.burstParticleEmitter("emotehappy")
				object.say(tostring(dialog.struggle[math.random(1, #dialog.struggle)]:gsub("<player>", world.entityName(storage.starPounds.entityStomach[1].id).."^reset;")))
			end
		end
	end
end

starPounds = {
	init = function()
		starPounds.settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")
		starPounds.baseData = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
	end,
	-- Mod functions
	----------------------------------------------------------------------------------
	digest = function(dt, isGurgle)
		-- Don't do anything if stomach is empty.
		if not (#storage.starPounds.entityStomach > 0) then
			starPounds.gurgleTimer = nil
			starPounds.voreDigestTimer = 0
			return
		end

		if not isGurgle then
			-- Vore stuff
			starPounds.voreDigestTimer = math.max((starPounds.voreDigestTimer or 0) - dt, 0)
			if starPounds.voreDigestTimer == 0 then
				starPounds.voreDigestTimer = starPounds.settings.voreDigestTimer
				starPounds.voreDigest(starPounds.settings.voreDigestTimer)
			end
			-- Gurgle stuff.
			if starPounds.gurgleTimer and starPounds.gurgleTimer > 0 then
				starPounds.gurgleTimer = math.max(starPounds.gurgleTimer - dt, 0)
			else
				-- gurgleTime (default 30) is the average, minimumGurgleTime (default 5) is the minimum, so (5 + (60 - 5))/2 = 30
				if starPounds.gurgleTimer then starPounds.gurgle() end
				starPounds.gurgleTimer = math.round(util.randomInRange({starPounds.settings.minimumGurgleTime, (starPounds.settings.gurgleTime * 2) - starPounds.settings.minimumGurgleTime}))
			end
		else
			-- 25% strength for vore digestion on gurgles.
			starPounds.voreDigest(dt * 0.25)
		end
	end,

	gurgle = function(noDigest)
		local seconds = math.random(100, 300)/100
		starPounds.digest(seconds, true)
		playSound("digest", 0.75, (2 - seconds/5))
	end,

	-- Vore functions
	----------------------------------------------------------------------------------
	voreCheck = function()
		-- Don't do anything if there's no eaten entities.
		if not (#storage.starPounds.entityStomach > 0) then return end
		-- table.remove is very inefficient in loops, so we'll make a new table instead and just slap in the stuff we're keeping.
		local newStomach = jarray()
		for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
			if world.entityExists(prey.id) then
				table.insert(newStomach, prey)
			end
		end
		storage.starPounds.entityStomach = newStomach
	end,

	voreDigest = function(digestionRate)
		-- Don't do anything if there's no eaten entities.
		if not (#storage.starPounds.entityStomach > 0) then return end
		-- Reduce health of all entities.
		for _, prey in pairs(storage.starPounds.entityStomach) do
			world.sendEntityMessage(prey.id, "starPounds.getDigested", digestionRate)
		end
	end,

	eatEntity = function(preyId)
		-- Max 1 entity for this object.
		if #storage.starPounds.entityStomach > 0 then return end
		-- Don't do anything if they're already eaten.
		local eatenEntity = nil
		for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
			if prey.id == preyId then
				eatenEntity = prey
			end
		end
		if eatenEntity then return false end
		-- Ask the entity to be eaten, add to stomach if the promise is successful.
		promises:add(world.sendEntityMessage(preyId, "starPounds.getEaten", entity.id()), function(prey)
			table.insert(storage.starPounds.entityStomach, {
				id = preyId,
				weight = prey.weight or 0,
				bloat = prey.bloat or 0,
				experience = prey.experience or 0,
				type = world.entityType(preyId):gsub(".+", {player = "humanoid", npc = "humanoid", monster = "creature"})
			})
			-- Swallow/stomach rumble
			playSound("swallow", 1 + math.random(0, 10)/100, 1)
			playSound("digest", 1, 0.75)
			playSound("talk", 1, 1.25)
			animator.burstParticleEmitter("emotehappy")
			object.say(tostring(dialog.swallow[math.random(1, #dialog.swallow)]:gsub("<player>", world.entityName(preyId).."^reset;")))
			animator.setAnimationState("interactState", "swallow", true)
		end)
		return true
	end,

	ateEntity = function(preyId)
		if regurgitateTimer > 0 then return true end
		for _, prey in ipairs(storage.starPounds.entityStomach) do
			if prey.id == preyId then return true end
		end
		return false
	end,

	digestEntity = function(preyId, items, preyStomach)
		-- Find the entity's entry in the stomach.
		local digestedEntity = nil
		for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
			if prey.id == preyId then
				digestedEntity = table.remove(storage.starPounds.entityStomach, preyIndex)
				break
			end
		end
		-- Don't do anything if we didn't digest an entity.
		if not digestedEntity then return end
		playSound("digest", 0.75, 0.75)
		playSound("talk", 1, 1.25)
		animator.burstParticleEmitter("emotehappy")
		animator.setAnimationState("interactState", "digest", true)
		object.say(tostring(dialog.digested[math.random(1, #dialog.digested)]:gsub("<player>", world.entityName(digestedEntity.id).."^reset;")))
		return true
	end,

	preyStruggle = function(preyId)
		-- Only continue if they're actually eaten.
		for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
			if prey.id == preyId then
				local preyHealth = world.entityHealth(prey.id)
				local preyHealthPercent = preyHealth[1]/preyHealth[2]

				playSound("struggle", math.min(1, (0.25 + math.max(0.5 * prey.weight/120, 0.35)) * (0.75 + preyHealthPercent/4)))
				if world.entityType(preyId) == "player" and math.random() < 0.1 then
					starPounds.releaseEntity(preyId)
				end
				-- 1 second worth of digestion per struggle.
				world.sendEntityMessage(preyId, "starPounds.getDigested", 1)
				break
			end
		end
	end,

	releaseEntity = function(preyId)
		-- Delete the entity's entry in the stomach.
		local releasedEntity = nil
		for preyIndex, prey in ipairs(storage.starPounds.entityStomach) do
			if prey.id == preyId then
				releasedEntity = table.remove(storage.starPounds.entityStomach, preyIndex)
				break
			end
			if not preyId then
				releasedEntity = table.remove(storage.starPounds.entityStomach)
				break
			end
		end
		if releasedEntity and world.entityExists(releasedEntity.id) then
			if regurgitateTimer == 0 then
				regurgitateTimer = 2
				animator.setAnimationState("interactState", "regurgitate", true)
				playSound("swallow", 1.25, math.random(8, 12)/10, 2)
			end
		end
	end,

	messageHandlers = function()
		message.setHandler("starPounds.digest", simpleHandler(starPounds.digest))
		-- Ditto but vore.
		message.setHandler("starPounds.eatEntity", simpleHandler(starPounds.eatEntity))
		message.setHandler("starPounds.ateEntity", simpleHandler(starPounds.ateEntity))
		message.setHandler("starPounds.digestEntity", simpleHandler(starPounds.digestEntity))
		message.setHandler("starPounds.preyStruggle", simpleHandler(starPounds.preyStruggle))
		message.setHandler("starPounds.releaseEntity", simpleHandler(starPounds.releaseEntity))
		-- sounds
		message.setHandler("starPounds.playSound", simpleHandler(playSound))
	end
}

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
	local format = string.format("%%.%df", numDecimalPlaces or 0)
	return tonumber(string.format(format, num))
end

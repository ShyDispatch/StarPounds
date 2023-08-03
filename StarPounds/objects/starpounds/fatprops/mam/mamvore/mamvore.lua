require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	starPounds.messageHandlers()
	storage.starPounds = storage.starPounds or root.assetJson("/scripts/starpounds/starpounds.config:baseData")
	object.setInteractive(true)

	dialog = {
		swallow = {
			"Mmhph! ...UURP! Thanks for the meal you cutie~",
			"Ulp! Fwah~ RIGHT where you belong, burbling away for me~",
			"Gulp! Mhmmm... mph, pwah!~ Oogh... So nice and filling...~ Now stay put in there~",
			"Ulp! Bwah~ I was feeling a little peckish too~ Just what I need for my growing ass!",
			"Gllp!~ Fwaah~ Y'know, all you had to do was ask, not that I mind at all~",
			"Gulp! Phew!~ Just kick REALLY hard if ya need me to swallow down some food for you~",
			"Ulp! Fufufu~ Should've been more careful, slimes like myself prefer our meals fresh... and wriggling~",
			"Gullp! Ahhn~ You superfans will stop at nothing to get closer to me... Not that I mind~",
			"Sllurp!~ Hhahh~ Could have at least fed me a little first, a gal's gotta eat~"
		},
		struggle = {
			"Unnf... Keep struggling~ It feels so... so...~",
			"Y'know you're just a thick, juicy hunk of meat one way or another, just give in already~",
			"Caaareful~ You're making my stomach work really hard! You might drown in all those juices~",
			"M-mmmph... mmwuuAAAGH~ ...Y-you didn't hear that...",
			"Gosh... y-you're wobbling all of me with all those pointless struggles~ My boobs... and belly...~",
			"Ahahh... Second thoughts already? A shame...~",
			"Mmn~ Getting adjusted? Good, stay as long as you like...~",
			"Oohh... I wonder just where you'll end up, my pudgy belly?~ My sloshing tits?~ or maybe you'll add to my titanic tush like the last 20...~",
			"Hah... hooOUUUURP!~ Keep shaking those belches out cutie, makes more room for what little of you is gonna be left~"
		},
		stop = {
			"H-hey! Who said you could wriggle out like that!",
			"Ooogh but I wasn't done demolishing every fiber of your being into thick, soupy calories...",
			"Dooh... I'm still soo hungry, are you really gonna neglect my empty tummy like that?",
			"Come baack...~ you know you belong right here on this bulging dough belly~",
			"I hope you're only leaving so you can come back with more food~",
			"Leaving so you can plump yourself up for me? Dooh how sweet~",
			"Unf... get back in here! I'm wasting away! Just listen to this poor starving belly...",
			"Come back soon morsel~ I can't wait to finally churn you up into a fine slurry~",
			"Oh come on, make up your mind silly, do you wanna be butt fat or not?~",
			"How disappointing~ I thought you WANTED me fatter, I guess not.",
			"D'aww, come back sweetie~ I promise I'll just give you a kiss next time, no funny business... maybe~",
			"Didja forget something?~ Or did you just wanna look at my cute face one last time~",
			"Mmf, fine~ I'll save that spot just for you when you change your mind~"
		},
		digested = {
			"BuuuUUUUOOOOOORRRRP!!!~ Oogh~ Thanks for the meal you cutie~",
			"Nothing but a mushy, sloshy soup pumping through my guts now~",
			"Be a good little snack and fill out the rest of my churning guts~",
			"Ooh? My belly's all sloshy and soft again? Guess they didn't last very long...~",
			"So what do you prefer? Being my boobs, butt, or belly fat?~",
			"Uugh I thought you'd last a little longer in there...~",
			"Look at you destroying what's left of my shrinking wardrobe!~",
			"Mhmmm I'm already getting so bloated~ Guess you were nothing but hot air~",
			"UUURP!~ Oh! Already gave up? Shoulda kept your head above that sea of stomach soup~",
			"What's this now? Another cup size? I'll need to order some cute new lingerie soon...~",
			"OoouUUUUUUURP!~ Mnnf~ Right to my ass, just how I like it~",
			"Urp!~ Teehee, how unladylike of me~",
			"Was this how you imagined your night would end?~ as more pudgy slime for my glorious frame?~",
			"Ahh~ How deliciously fun, now be sure to rub my belly when you... oh right, my bad~",
			"Fatter and fatter, everyday I'm getting so fat off of cute fans like you, and you'll be here for the rest of that journey~",
			"Oh my, I must've gotten carried away~ Sorry cutie, but you'll be much better as butt fat I assure you~",
			"BuuOUUURP!~ That's it, now who's next?~"
		}
	}


	regurgitateTimer = 0
	boostTimer = 0

	digestionBoost = false
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
	starPounds.gurgle(dt)

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
	-- Mod functions
	----------------------------------------------------------------------------------
	digest = function(dt)
		starPounds.voreDigest(dt)
	end,

	gurgle = function(dt)
		if #storage.starPounds.entityStomach == 0 then return end
		-- Roughly every 30 seconds, gurgle (i.e. instantly digest 2.5 - 5 seconds worth of food).
		if math.random(1, math.round(30/dt)) == 1 then
			local seconds = math.random(25, 50)/10
			starPounds.digest(seconds)
			playSound("digest", 0.75, (0.8 - seconds/10))
		end
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
		-- Don't do anything if they not a compatible entity.
		if not contains({"player", "npc", "monster"}, world.entityType(preyId)) then return false end
		-- Ask the entity to be eaten, add to stomach if the promise is successful.
		promises:add(world.sendEntityMessage(preyId, "starPounds.getEaten", entity.id()), function(prey)
			if not (prey and (prey.weight or prey.bloat)) then return end
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
		playSound("belch", 1, 1.0)
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

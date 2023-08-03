function init()
	object.setInteractive(true)
	animations = {
		"smack1",
		"smack2",
		"bounce"
	}
	dialog = {
		interact = {
			"^#aa99dd;Fayane^reset; likess when <player> does that.",
			"<player> can do that to ^#aa99dd;Fayane^reset; again, yesss?",
			"Careful <player> doess not stand too close, ^#aa99dd;Fayane^reset; could ssslip...\n\nBy mistake of course~.",
			"Floran hopess <player> not getting tired yet.",
			"<player> hasss plenty of time, ^#aa99dd;Fayane^reset; hopess.",
			"Fassster!",
			"^#aa99dd;Fayane^reset; likesss <player>, has nice handss.",
			"^#aa99dd;Fayane^reset; hass nice soft belly, yes?",
			"If <player> keeps thisss up, ^#aa99dd;Fayane^reset; may have to ssteal them.",
			"<player> can be rougher than that~.",
			"<player> should do thiss more often, is fun!"
		},
		stop = {
			"Floran wantsss more!",
			"^#aa99dd;Fayane^reset; not sssay sstop!",
			"If ^#aa99dd;Fayane^reset; askss nicely, will <player> keep going?",
			"<player> ssstopping so soon?",
			"Can <player> give floran goodbye sslap? Please?",
			"Where doess <player> think <player> is going?",
			"Finish what <player> started!",
			"<player> knowsss they want to keep going."
		}
	}
	animator.setSoundPitch("talk", 1.25)
	
	animator.setSoundVolume("smack", 0.75)
	animator.setSoundPitch("smack", 1.25)
	
	animator.setSoundVolume("bounce", 1.75)
	animator.setSoundPitch("bounce", 1.25)
	animator.setSoundVolume("gurgle", 0.5)
	animator.setSoundPitch("gurgle", 2)
	
	cooldown = 0
end

function onInteraction(args)
	if cooldown < 4.3 then
		lastPlayer = args.sourceId
		
		animator.setAnimationState("interactState", "default")
		animation = animations[math.random(1, #animations)]
		
		if animation:find("smack") then
			animator.playSound("smack")
		end
		if animation:find("bounce") then
			animator.playSound("bounce")
			animator.playSound("gurgle")
		end
		
		if math.random(1, 5) == 1 then
			animator.playSound("talk")
			animator.burstParticleEmitter("emotehappy")
			object.say(tostring(dialog.interact[math.random(1, #dialog.interact)]:gsub("<player>", world.entityName(args.sourceId).."^reset;")))
		end
		
		animator.setAnimationState("interactState", animation)
		cooldown = 5
	end
end

function update(dt)
	cooldown = math.max(cooldown - dt, 0)
	if cooldown == 0 and lastPlayer then
		if math.random(1, 2) == 1 then
			animator.playSound("talk")
			animator.burstParticleEmitter("emotesad")
			object.say(tostring(dialog.stop[math.random(1, #dialog.stop)]:gsub("<player>", world.entityName(lastPlayer).."^reset;")))
		end
		lastPlayer = nil
	end
end
function init()
	object.setInteractive(true)
	animations = {
		"smack1",
		"smack2",
		"bounce"
	}
	dialog = {
		interact = {
			"What are you doing <player>!?",
			"If you keep doing this <player> I might just fall over.",
			"Do you ever get tired doing this?",
			"Do you have anything better to do <player>?",
			"Eek!",
			"You're lucky it's so padded I can hardly feel that.",
			"Yes, I know. It's very big...",
			"I'd walk away, but these don't allow me to get very far...",
			"*sigh*",
			"T-that one felt nice."
		},
		stop = {
			"Phew...",
			"Thank goodness.",
			"That was, interesting.",
			"Why did that feel so... nice?",
			"Can you apologize as well?",
			"At least it's over now.",
			"<player>... Maybe just one more?",
			"Why am I sad now?"
		}
	}
	animator.setSoundPitch("talk", 1.25)

	animator.setSoundVolume("smack", 0.75)
	animator.setSoundPitch("smack", 1.25)

	animator.setSoundVolume("bounce", 1.75)
	animator.setSoundPitch("bounce", 1.25)

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

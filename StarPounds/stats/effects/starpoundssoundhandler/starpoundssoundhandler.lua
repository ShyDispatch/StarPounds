require "/scripts/messageutil.lua"

function init()
	message.setHandler("starPounds.playSound", simpleHandler(playSound))
	message.setHandler("starPounds.stopSound", simpleHandler(animator.stopAllSounds))
	message.setHandler("starPounds.setSoundVolume", simpleHandler(animator.setSoundVolume))
	message.setHandler("starPounds.setSoundPitch", simpleHandler(animator.setSoundPitch))
	message.setHandler("starPounds.expire", localHandler(effect.expire))
end

function update(dt)
	effect.modifyDuration(dt)
end

function playSound(soundPool, volume, pitch, loops)
	local volume = volume or 1
	local pitch = pitch or 1
	local starPounds = getmetatable ''.starPounds

	if starPounds then
		-- Don't do anything if disabled.
		if starPounds.hasOption("disableSound") then return end
			-- UUUEEGGHH
		if starPounds.hasSkill("secret") then
			soundPool = "secret"
			volume = (volume + 0.5) * 0.5
			pitch = (pitch + 1) * 0.5
		end
		if starPounds.hasOption("quietSounds") then
			volume = volume * 0.5
		end
		-- Burp stuff.
		if soundPool == "belch" then
			if starPounds.hasOption("disableBelches") then return end
			if starPounds.hasOption("higherBelches") then pitch = pitch * 1.25 end
			if starPounds.hasOption("deeperBelches") then pitch = pitch * 0.75 end
		end
	end

	animator.setSoundVolume(soundPool, volume or 1, 0)
	animator.setSoundPitch(soundPool, pitch or 1, 0)
	animator.playSound(soundPool, loops)
end

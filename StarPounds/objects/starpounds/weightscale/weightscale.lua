require "/scripts/messageutil.lua"

function update(dt)
	promises:update()
end

function onInteraction(args)
	promises:add(world.sendEntityMessage(args.sourceId, "starPounds.getData"), function(data)
		object.say(string.format(config.getParameter("interactMessage"), math.floor(data.weight + 0.5)))
	end)
end

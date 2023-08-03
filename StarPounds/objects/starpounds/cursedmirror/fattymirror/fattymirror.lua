require "/scripts/messageutil.lua"

function init()
  self.chatOptions = config.getParameter("chatOptions", {})
  self.chatTimer = 0
  self.sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config")
	self.settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")
  self.activationTime = config.getParameter("activationTime") or 60

  if storage.active == nil then activate() end

  animator.setAnimationState("state", storage.active and "active" or "expire")
end

function onInteraction(args)
  if storage.active then
      use(args)
  end
end

function update(dt)
  promises:update()

  if isTimeToActivate() and not world.isVisibleToPlayer(object.boundBox()) then
    activate()
  end
  self.chatTimer = math.max(0, self.chatTimer - dt)
  if self.chatTimer == 0 and storage.active then
    local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })

    if #players > 0 and #self.chatOptions > 0 then
      object.say(self.chatOptions[math.random(1, #self.chatOptions)])
      self.chatTimer = config.getParameter("chatCooldown")
    end
  end
end

function isTimeToActivate()
  return storage.lastActive and world.time() - storage.lastActive > self.activationTime
end

function use(args)
  if storage.active then
    targetId = args.sourceId
    promises:add(world.sendEntityMessage(targetId, "starPounds.getData", "weight"), function(weight)
      currentSize, currentSizeIndex = getSize(weight)
      if currentSizeIndex == #self.sizes then return end
      local currentProgress = (weight - currentSize.weight)/(self.sizes[currentSizeIndex + 1].weight - currentSize.weight)
      local amount = math.floor(0.5 + self.sizes[currentSizeIndex + 1].weight - weight + currentProgress * ((self.sizes[currentSizeIndex + 2] and self.sizes[currentSizeIndex + 2].weight or self.settings.maxWeight) - self.sizes[currentSizeIndex + 1].weight))
      world.sendEntityMessage(targetId, "starPounds.gainWeight", amount)
      deactivate()
      animator.playSound("use")
    end)
  end
end

function activate()
  animator.setAnimationState("state", "active")
  storage.active = true
  storage.lastActive = false
  object.setInteractive(true)
end

function deactivate()
  animator.setAnimationState("state", "expire")
  storage.active = false
  storage.lastActive = world.time()
  object.setInteractive(false)
end

function getSize(weight)
	local sizeIndex = 0
	-- Go through all sizes (smallest to largest) to find which size.
	for i in ipairs(self.sizes) do
		if weight >= self.sizes[i].weight then
			sizeIndex = i
		end
	end

	return self.sizes[sizeIndex], sizeIndex
end

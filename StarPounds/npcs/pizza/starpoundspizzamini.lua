local starPounds_didQuery = false
local init_old = init
local update_old = update
local handleInteract_old = handleInteract
function init()
  init_old()
  message.setHandler("starPounds.deletePizzaItem", localHandler(function() self.deleteItem = true end))
  self.waitEatTimer = config.getParameter("waitEatTime", 30)
  self.eatTime = config.getParameter("eatTime", 2)
  self.voreWaitTime = config.getParameter("voreWaitTime", 2)
  self.voreBelchTime = config.getParameter("voreBelchTime", 1)
  self.voreEatTalkDelay = config.getParameter("voreEatTalkDelay", 2)
  self.voreEscapeTalkDelay = config.getParameter("voreEscapeTalkDelay", 2)

  local orderList = jarray()
  local totalItemCount = 0
  for itemName, itemCount in pairs(self.order) do
    totalItemCount = totalItemCount + itemCount
    orderList[#orderList + 1] = itemName
  end
  -- She eats 25% -> 50% of your order, max 5 items.
  local eatPercent = math.random(25, 50)/100
  local eatCount = math.floor(totalItemCount * eatPercent)
  local eatFoodCost = 0
  self.totalFood = 0
  for i = 1, eatCount do
    -- Pick a random item.
    local itemIndex = math.random(1, #orderList)
    local itemName = orderList[itemIndex]
    local itemConfig = root.itemConfig(itemName).config
    self.totalFood = self.totalFood + (itemConfig.foodValue or 0)
    eatFoodCost = eatFoodCost + (itemConfig.price or 0)
    self.order[itemName] = self.order[itemName] - 1
    -- Remove the item if it has no count.
    if self.order[itemName] == 0 then
       self.order[itemName] = nil
       table.remove(orderList, itemIndex)
    end
  end
  starPounds.feed(totalFood)
  self.order.money = (self.order.money or 0) + eatFoodCost
  self.ateItems = self.totalFood > 0
  if self.totalFood >= 500 then
    self.removeChest = true
  end
end

function update(dt)
  update_old(dt)
  beamOut()
  self.ateEntity = #storage.starPounds.stomachEntities > 0
  self.removeChest = self.removeChest or self.ateEntity
  if starPounds.currentVariant and not storage.removedChest and self.removeChest then
    storage.removedChest = true

    npc.setItemSlot("chestCosmetic")
    -- Fast way to force a size reequip.
    starPounds.optionChanged = true
    starPounds.equipCheck(starPounds.currentSize)
    if self.ateEntity or self.ateOrder then
      starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
    end
  end

  for _, prey in ipairs(storage.starPounds.stomachEntities) do
    if self.deliveryTarget and (world.entityUniqueId(prey.id) == self.deliveryTarget) then
      targetEntityId = prey.id
      self.ateCustomer = true
    end
  end

  if targetEntityId and starPounds.ateEntity(targetEntityId) then
    self.voreWaitTime = math.max(self.voreWaitTime - dt, 0)
    if not self.eatOrder and self.voreWaitTime == 0 then
      storage.collectedTime = os.time()
      sayToEntity({dialogType = "dialog.voreCustomer", entity = targetEntityId})
      self.eatOrder = true
    end
    -- Linger for a few seconds after they've digested.
    storage.voreTime = os.time()
  end

  if self.eatOrder then
    self.eatTime = math.max(self.eatTime - dt, 0)
    if not self.ateOrder and self.eatTime == 0 then
      for itemName, itemCount in pairs(self.order) do
        self.totalFood = self.totalFood + (root.itemConfig(itemName).config.foodValue or 0) * itemCount
      end
      if self.totalFood >= 250 then
        self.removeChest = true
      end
      npc.beginPrimaryFire()
      starPounds.feed(itemFood)
      self.ateOrder = true
    end
    if self.ateCustomer and not starPounds.ateEntity(targetEntityId) then
      self.voreEscapeTalkDelay = math.max(self.voreEscapeTalkDelay - dt, 0)
      if not self.voreEscaped and self.voreEscapeTalkDelay == 0 then
        self.voreEscaped = true
        sayToEntity({dialogType = "dialog.voreCustomerEscaped", entity = targetEntityId})
        faceEntity({entity = targetEntityId, headingDirection = {0, 0}})
      end
    elseif not self.ateOrder and self.waitedTooLong and not storage.collectedTime then
      storage.collectedTime = os.time()
      sayToEntity({dialogType = "dialog.eatOrder", entity = targetEntityId})
    end
  end

  if self.ateOrder then
    self.voreBelchTime = math.max(self.voreBelchTime - dt, 0)
    if not self.belched and self.voreBelchTime == 0 then
      starPounds.belch(0.75, starPounds.belchPitch(0.8))
      npc.emote("oh")
      self.belched = true
    end
    if not self.voreAte and self.voreBelchTime == 0 and self.ateCustomer and starPounds.ateEntity(targetEntityId) then
      self.voreEatTalkDelay = math.max(self.voreEatTalkDelay - dt, 0)
      if self.voreEatTalkDelay == 0 then
        self.voreAte = true
        sayToEntity({dialogType = "dialog.eatOrderVore", entity = targetEntityId})
      end
    end
  end

  if self.deleteItem then
    npc.setItemSlot("primary")
  end

  teleportVoreDelay = math.max((teleportVoreDelay or 1) - dt, 0)
  if config.getParameter("data", {}).teleportVore and not (starPounds_didQuery) and teleportVoreDelay == 0 then
    local entities = world.entityQuery(mcontroller.position(), 1, {order = "nearest", includedTypes = {"player", "npc"}, withoutEntityId = entity.id()}) or jarray()
    local eatOptions = {ignoreProtection = true, ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirment = true, energyMultiplier = 0, noSwallowSound = true}
    for _, target in ipairs(entities) do
      if starPounds.moduleFunc("pred", "eat", target, eatOptions, true) then
        starPounds.moduleFunc("pred", "eat", target, eatOptions)
        break
      end
    end
    starPounds_didQuery = true
  end
end

function handleInteract(args)
  if not (args.sourceId and starPounds.ateEntity(args.sourceId)) then
    handleInteract_old(args)
    if world.entityUniqueId(args.sourceId) == self.deliveryTarget then
      if self.ateItems and dialogKey == "dialog.collect" then
        dialogKey = "dialog.collectMissing"
      end
      if self.eatOrder then
        dialogKey = "dialog.ateOrder"..(self.ateCustomer and "Vore" or "")
      end
    end
  end
end


function beamOut()
  local currentTime = os.time()
  local waitTime = os.time() - (storage.spawnTime or os.time())
  local lingerTime = currentTime - (storage.voreTime or (storage.collectedTime or currentTime))

  if self.waitEatTimer and (waitTime > self.waitEatTimer and not storage.collectedTime) then
    self.eatOrder = true
    self.waitedTooLong = true
  end

  if (self.waitTimer and (waitTime > self.waitTimer) and not storage.collectedTime) or self.lingerTimer and (lingerTime > self.lingerTimer) then
    status.addEphemeralEffect("beamoutanddie")
    npc.setDeathParticleBurst()
  end
end

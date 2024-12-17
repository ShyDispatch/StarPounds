function extraInit()
  self.waitTimer = config.getParameter("waitTime")
  self.lingerTimer = config.getParameter("lingerTime")
  self.deliveryTarget = config.getParameter("target")
  self.order = config.getParameter("order", {})
  self.overrideItems = config.getParameter("overrideItems", {})

  storage.spawnTime = storage.spawnTime or os.time()

  for slot, item in pairs(self.overrideItems) do
    npc.setItemSlot(slot, item)
  end
end

local sayToEntity_old = sayToEntity
function sayToEntity(args, board)
  if dialogKey then
    args.dialogType = dialogKey
  end
  return sayToEntity_old(args, board)
end

function handleInteract(args)
  if world.entityUniqueId(args.sourceId) == self.deliveryTarget then
    if not storage.collectedTime then
      storage.collectedTime = os.time()
      dialogKey = "dialog.collect"
      npc.setItemSlot("primary")
      local itemPrice = 0
      for itemName, itemCount in pairs(self.order) do
        itemPrice = itemPrice + (root.itemConfig(itemName).config.price or 0) * itemCount
      end
      world.spawnItem({name = "starpoundspizzadelivery", count = 1, parameters = {order = self.order, price = itemPrice, shortdescription = "Order for: "..world.entityName(args.sourceId)}}, world.entityPosition(args.sourceId))
    else
      dialogKey = "dialog.collected"
    end
  end
end

local update_old = update
function update(dt)
  update_old(dt)
  beamOut()

  if starPounds.mcontroller.liquidMovement then
    mcontroller.controlParameters({liquidBuoyancy = 1})
  end
end

function beamOut()
  local currentTime = os.time()
  local waitTime = os.time() - (storage.spawnTime or os.time())
  local lingerTime = currentTime - (storage.collectedTime or currentTime)

  if not status.uniqueStatusEffectActive("starpoundseaten") then
    if (self.waitTimer and (waitTime > self.waitTimer) and not storage.collectedTime) or self.lingerTimer and (lingerTime > self.lingerTimer) then
      status.addEphemeralEffect("beamoutanddie")
      npc.setDeathParticleBurst()
    end
  end
end

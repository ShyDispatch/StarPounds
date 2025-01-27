require "/scripts/messageutil.lua"
require "/scripts/util.lua"

function init()
  self.gulpDelay = config.getParameter("gulpDelay", 0.8)
  self.stateTimer = self.gulpDelay
  self.queryTimer = 0
  self.animationRate = 1
  self.capacity = config.getParameter("capacity", 1000)
  self.maxWeight = root.assetJson("/scripts/starpounds/starpounds.config:settings.maxWeight")
  self.liquids = root.assetJson("/scripts/starpounds/modules/liquid.config:liquids")
  self.boundBox = object.boundBox()
  self.statusBlacklist = {
    "wet",
    "swimming",
    "slimeslow",
    "tarslow",
    "starpoundschocolateslow",
    "starpoundshoneyslow",
    "caloriumliquid"
  }

  local liquidName, liquidAmount = table.unpack(config.getParameter("defaultLiquid", jarray()))
  if liquidName then
    defaultLiquid = {
      name = liquidName,
      statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
      item = root.liquidConfig(liquidName).config.itemDrop
    }
  end

  object.setConfigParameter("defaultLiquid", nil)

  storage = sb.jsonMerge({
    liquid = defaultLiquid,
    amount = liquidAmount or 0,
  }, storage)

  if storage.liquid then
    setLiquidType(storage.liquid.name)
  end

  self.liquidLevel = storage.amount
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))
end

function update(dt)
  promises:update()
  self.stateTimer = math.max(0, self.stateTimer - dt)
  self.queryTimer = math.max(0, self.queryTimer - dt)
  if world.loungeableOccupied(entity.id()) then
    if feedTarget and world.entityExists(feedTarget) then
      if storage.amount > 0 then
        promises:add(world.sendEntityMessage(feedTarget, "starPounds.getData"), function(data)
          self.animationRate = 1 + math.floor((data.weight/self.maxWeight) * 100 + 0.5) * 0.01
          animator.setAnimationRate(self.animationRate)
        end)
        if self.stateTimer == 0 then
          animator.setAnimationState("feedState", "feeding", true)
          self.stateTimer = self.gulpDelay/self.animationRate
        elseif self.stateTimer > self.gulpDelay/5 and math.max(0, self.stateTimer - dt) < self.gulpDelay/5 then
          animator.playSound("drink")
          storage.amount = math.max(0, storage.amount - 1)
          for foodType, foodAmount in pairs(self.liquids[storage.liquid.name] or self.liquids.default) do
            world.sendEntityMessage(feedTarget, "starPounds.feed", foodAmount, foodType)
          end
          for _, statusEffect in pairs(storage.liquid.statusEffects) do
            if not contains(self.statusBlacklist, statusEffect) then
              world.sendEntityMessage(feedTarget, "applyStatusEffect", statusEffect)
            end
          end
          world.sendEntityMessage(feedTarget, "applyStatusEffect", "starpoundsdrinking")
        end
      else
        setLiquidType()
        animator.setAnimationState("feedState", "default", true)
      end
    else
      feedTarget = nil
    end
  else
    reset()
  end

  if storage.amount <= 0 then
    setLiquidType()
  end

  self.liquidLevel = math.round(util.lerp(dt * 2, self.liquidLevel, storage.amount), 4)
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))

  if self.queryTimer == 0 then
    findLiquidDrops()
    self.queryTimer = 1
  end
end

function onInteraction(args)
  if not world.loungeableOccupied(entity.id()) then
    feedTarget = args.sourceId
    self.animationRate = 1
  end
end

function onNpcPlay(npcId)
  if not world.loungeableOccupied(entity.id()) then
    onInteraction({sourceId = npcId})
    world.callScriptedEntity(npcId, "lounge", {entity = entity.id()})
    world.callScriptedEntity(npcId, "mcontroller.clearControls")
    world.callScriptedEntity(feedTarget, "status.setResource", "stunned", math.random(5, 30))
  end
end

function reset()
  animator.setAnimationState("feedState", "idle", true)
  animator.setAnimationRate(1)
  if feedTarget and world.entityExists(feedTarget) and world.entityType(feedTarget) == "npc" then
    world.callScriptedEntity(feedTarget, "status.setResource", "stunned", 0)
  end
end

function die()
  if storage.liquid then
    world.spawnItem(storage.liquid.item, entity.position(), storage.amount)
  end
end

function findLiquidDrops()
  if storage.amount < self.capacity then
    local items = world.itemDropQuery(entity.position(), 4)
    for _, itemId in pairs(items) do
      local item = world.itemDropItem(itemId)
      if root.itemType(item.name) == "liquid" then
        local liquidName = root.itemConfig(item.name).config.liquid
        if not storage.liquid or liquidName == storage.liquid.name then
          local itemDrop = world.takeItemDrop(itemId, entity.id())
          if itemDrop then
            storage.liquid = {
              name = liquidName,
              statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
              item = item.name
            }
            storage.amount = storage.amount + itemDrop.count
            setLiquidType(liquidName)
            if storage.amount > self.capacity then
              local excess = storage.amount - self.capacity
              world.spawnItem(storage.liquid.item, entity.position(), excess)
              storage.amount = self.capacity
            end
          end
        end
      end
    end
  end
end

function setLiquidType(liquidName)
  if liquidName then
    local liquidConfig = root.liquidConfig(liquidName).config
    local rgb = liquidConfig.color
    animator.setGlobalTag("liquidImage", string.format("%s?multiply=%s", liquidConfig.texture, string.format("%02X%02X%02X%02X", rgb[1], rgb[2], rgb[3], rgb[4])))
    object.setLightColor(liquidConfig.radiantLight or {0, 0, 0})
  else
    storage.liquid = nil
    animator.setGlobalTag("liquidImage", "")
    object.setLightColor({0, 0, 0})
  end
end

function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end

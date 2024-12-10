-- Underscore here since the player table exists.
local _player = starPounds.module:new("player")

function _player:init()
  self:setup()
  -- Radio message if we have QuickbarMini instead (or with) StardustLite.
  local mmconfig = root.assetJson("/interface/scripted/mmupgrade/mmupgradegui.config")
  if mmconfig.replaced and not pcall(root.assetJson, "/metagui/registry.json") then
    player.radioMessage("starpounds_quickbar")
  elseif not mmconfig.replaced then
    player.radioMessage("starpounds_stardust")
  end
  -- Damage listener for fall/fire damage.
  self.damageListener = damageListener("damageTaken", function(notifications)
    for _, notification in pairs(notifications) do
      if notification.sourceEntityId == entity.id() and notification.targetEntityId == entity.id() then
        if notification.damageSourceKind == "falling" and starPounds.currentSizeIndex > 1 then
          -- "explosive" damage (ignores tilemods) to blocks is reduced by 80%, for a total of 5% damage applied to blocks. (Isn't reduced by the fall damage skill)
          local baseDamage = (notification.damageDealt)/(1 + starPounds.currentSize.healthBonus * (1 - starPounds.getStat("fallDamageResistance")))
          local tileDamage = baseDamage * (1 + starPounds.currentSize.healthBonus) * 0.25
          _player.damageHitboxTiles(_player, tileDamage)
          break
        end
        if starPounds.currentSizeIndex > 1 and string.find(notification.damageSourceKind, "fire") and starPounds.getStat("firePenalty") > 0 then
          local percentLost = math.round(notification.healthLost/status.resourceMax("health"), 2)
          percentLost = 2 * percentLost * starPounds.getStat("firePenalty") * (starPounds.currentSizeIndex - 1)/(#starPounds.sizes - 1)

          if percentLost > 0.01 then
            status.overConsumeResource("energy", status.resourceMax("energy") * percentLost)
            status.addEphemeralEffect("sweat")
          end
        end
      end
    end
  end)
end

function _player:update(dt)
  -- Update fall damage listener.
  self.damageListener:update()

  local currentSizeWeight = starPounds.currentSize.weight
  local nextSizeWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
  if nextSizeWeight ~= starPounds.settings.maxWeight and starPounds.sizes[starPounds.currentSizeIndex + 1].isBlob and starPounds.hasOption("disableBlob") then
    nextSizeWeight = starPounds.settings.maxWeight
  end
  -- Cross script voodoo witch magic.
  getmetatable ''.starPounds.progress = math.round((storage.starPounds.weight - currentSizeWeight)/(nextSizeWeight - currentSizeWeight) * 100)
  getmetatable ''.starPounds.weight = storage.starPounds.weight
  getmetatable ''.starPounds.enabled = storage.starPounds.enabled

  starPounds.swapSlotItem = player.swapSlotItem()
  if starPounds.swapSlotItem and root.itemType(starPounds.swapSlotItem.name) == "consumable" then
    local replaceItem = self:updateFoodItem(starPounds.swapSlotItem)
    if replaceItem then
      player.setSwapSlotItem(replaceItem)
    end
  end
end

function _player:setup()
  -- Dummy empty function so we save memory.
  local function nullFunction() end
  local speciesData = starPounds.getSpeciesData(player.species())
  entity = {
    id = player.id,
    weight = speciesData.weight,
    foodType = speciesData.foodType
  }
  local mt = {__index = function () return nullFunction end}
  setmetatable(entity, mt)
  if not speciesData.weightGain then
    message.setHandler("starPounds.feed", simpleHandler(function(amount) status.giveResource("food", amount) end))
    starPounds.getChestVariant = function() return "" end
    starPounds.getDirectives = function() return "" end
    starPounds.equipSize = nullFunction
    starPounds.equipCheck = nullFunction
    starPounds.gainWeight = nullFunction
    starPounds.loseWeight = nullFunction
    starPounds.setWeight = nullFunction
    starPounds.getSize = function() return starPounds.sizes[1], 1 end
  end
end

function _player:damageHitboxTiles(tileDamage)
  if starPounds.hasOption("disableTileDamage") then return end
  local lowDamageTiles = {}
  local highDamageTiles = {}
  local groundLevel = 0
  local height = 0
  local width = {0, 0}
  local position = mcontroller.position()
  -- Calculate height, groundLevel, and width.
  for _, v in ipairs(mcontroller.collisionPoly()) do
    height = math.max(height, v[2])
    groundLevel = math.min(groundLevel, v[2])
    width[1] = math.min(width[1], v[1])
    width[2] = math.max(width[2], v[1])
  end
  -- Create tile damage polys.
  local lowPoly = {
    vec2.add({width[1] - 1, groundLevel - 0.5}, position),
    vec2.add({width[2] + 1, groundLevel - 0.5}, position),
    vec2.add({math.max(0, width[2] - 1.5), groundLevel - 2.5}, position),
    vec2.add({math.min(0, width[1] + 1.5), groundLevel - 2.5}, position)
  }
  local highPoly = {
    vec2.add({math.min(-0.5, width[1] + 0.5), groundLevel - 0.5}, position),
    vec2.add({math.max(0.5, width[2] - 0.5), groundLevel - 0.5}, position),
    vec2.add({math.max(0, width[2] - 1.5), groundLevel - 1.5}, position),
    vec2.add({math.min(0, width[1] + 1.5), groundLevel - 1.5}, position)
  }
  -- Check if nearby tiles fall in the damage poly.
  local tileQueryRadius = (0.5 * (math.abs(width[1]) + width[2])) - groundLevel + 1
  local foregroundTiles = world.radialTileQuery(position, tileQueryRadius, "foreground")
  for _, tile in pairs(foregroundTiles) do
    if world.polyContains(lowPoly, tile) then
      lowDamageTiles[#lowDamageTiles + 1] = tile
    end
    if world.polyContains(highPoly, tile) then
      highDamageTiles[#highDamageTiles + 1] = tile
    end
  end
  -- Damage valid tiles based on fall damage.
  world.damageTiles(lowDamageTiles, "foreground", position, "explosive", tileDamage * 0.25, 1, entity.id())
  world.damageTiles(highDamageTiles, "foreground", position, "explosive", tileDamage * 0.75, 1, entity.id())
end

function _player:updateFoodItem(item)
  if configParameter(item, "foodValue") and not configParameter(item, "starpounds_effectApplied", false) then
    local experienceBonus = starPounds.settings.foodExperienceBonus
    local effects = configParameter(item, "effects", jarray())

    if not effects[1] then
      table.insert(effects, jarray())
    end

    -- Set the food type.
    local category = configParameter(item, "category", ""):lower()
    local foodType = (category == "drink") and "drink" or "food"
    local foodValue = configParameter(item, "foodValue", 0)
    local disableExperience = configParameter(item, "starpounds_disableExperience", false)

    local rarity = configParameter(item, "rarity", "common"):lower()
    local bonusExperience = foodValue * (experienceBonus[rarity] or 0)
    table.insert(effects[1], {
      effect = string.format("starpoundsfood_%sitem%s", foodType, disableExperience and "_noexperience" or ""),
      duration = foodValue
    })
    if not disableExperience and bonusExperience > 0 then
      table.insert(effects[1], {effect = "starpoundsfood_bonusexperience", duration = bonusExperience})
    end

    item.parameters.starpounds_effectApplied = true
    item.parameters.effects = effects
    item.parameters.starpounds_foodValue = foodValue
    item.parameters.foodValue = 0

    return item
  end
  return false
end

starPounds.modules.player = _player

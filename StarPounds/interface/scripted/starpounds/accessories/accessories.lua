require "/scripts/messageutil.lua"
starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.enabled and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  stats = root.assetJson("/scripts/starpounds/starpounds_stats.config")
  if starPounds then
    -- Pop out bad items.
    for _,v in ipairs({"pendant", "ring", "trinket"}) do
      local item = starPounds.getAccessory(v) and root.createItem(starPounds.getAccessory(v)) or nil
      if item and not _ENV[v]:acceptsItem(item) then
        starPounds.setAccessory(nil, v)
        player.giveItem(item)
      end
    end

    pendant:setItem(starPounds.getAccessory("pendant"))
    ring:setItem(starPounds.getAccessory("ring"))
    trinket:setItem(starPounds.getAccessory("trinket"))
    accessoryChanged("pendant")
    accessoryChanged("ring")
    accessoryChanged("trinket")
  end
end

function update()
  if isAdmin ~= player.isAdmin() then
    isAdmin = player.isAdmin()
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
  end

  if starPounds.optionChanged then
    for _,v in ipairs({"pendant", "ring", "trinket"}) do
      _ENV[v]:setItem(starPounds.getAccessory(v))
      accessoryChanged(v)
    end
  end

  -- Check promises.
  promises:update()
end

function pendant:acceptsItem(item)
  return configParameter(item, "accessoryType") == "pendant"
end

function pendant:onItemModified()
  starPounds.setAccessory(pendant:item(), "pendant")
  accessoryChanged("pendant")
end

function ring:acceptsItem(item)
  return configParameter(item, "accessoryType") == "ring"
end

function ring:onItemModified()
  starPounds.setAccessory(ring:item(), "ring")
  accessoryChanged("ring")
end

function trinket:acceptsItem(item)
  return configParameter(item, "accessoryType") == "trinket"
end

function trinket:onItemModified()
  starPounds.setAccessory(trinket:item(), "trinket")
  accessoryChanged("trinket")
end

function accessoryChanged(slot)
  local item = _ENV[slot]:item()

  local statModifierString = ""
  if item then
    for _, stat in ipairs(configParameter(item, "stats", jarray())) do
      local modifierColour = (stats[stat.name].negative and stat.modifier < 0 or stat.modifier > 0) and "^green;" or "^red;"
      local amount = (stats[stat.name].invertDescriptor and (stat.modifier * -1) or stat.modifier) * 100
      local statColour = stats[stat.name].colour and ("^#"..stats[stat.name].colour..";") or ""
      statModifierString = statModifierString..string.format("%s%s^reset; %s by %s%d%%\n", statColour, stats[stat.name].pretty, amount > 0 and "increased" or "reduced", modifierColour, math.floor(math.abs(amount) + 0.5))
    end
  end

  _ENV[slot.."Description"]:setText(statModifierString)
end

configParameter = function(item, keyName, defaultValue)
  if item.parameters[keyName] ~= nil then
    return item.parameters[keyName]
  elseif root.itemConfig(item).config[keyName] ~= nil then
    return root.itemConfig(item).config[keyName]
  else
    return defaultValue
  end
end

function weightDecrease:onClick()
  local progress = (starPounds.weight - starPounds.currentSize.weight)/((starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight) - starPounds.currentSize.weight)
  local targetWeight = starPounds.sizes[math.max(starPounds.currentSizeIndex - 1, 1)].weight
  local targetWeight2 = starPounds.sizes[starPounds.currentSizeIndex].weight
  starPounds.setWeight(metagui.checkShift() and 0 or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function weightIncrease:onClick()
  local progress = math.max(0.01, (starPounds.weight - starPounds.currentSize.weight)/((starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight) - starPounds.currentSize.weight))
  local targetWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
  local targetWeight2 = starPounds.sizes[starPounds.currentSizeIndex + 2] and starPounds.sizes[starPounds.currentSizeIndex + 2].weight or starPounds.settings.maxWeight
  starPounds.setWeight(metagui.checkShift() and starPounds.settings.maxWeight or (targetWeight + (targetWeight2 - targetWeight) * progress))
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = "Accessories",
    icon = "/interface/scripted/starpounds/accessories/icon.png",
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "starPounds.reset"), function()
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
end

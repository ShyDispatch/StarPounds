require "/scripts/messageutil.lua"
require "/scripts/util.lua"
starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.enabled and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  options = root.assetJson("/scripts/starpounds/starpounds_options.config:options")
  stats = root.assetJson("/scripts/starpounds/starpounds_stats.config")
  tabs = root.assetJson("/scripts/starpounds/starpounds_options.config:tabs")
  tabs[#tabs + 1] = {
    id = "miscellaneous",
    description = "Miscellaneous Options",
    icon = "miscellaneous.png"
  }
  if starPounds then
    populateOptions()
  end
end

function update()
  if isAdmin ~= admin() then
    isAdmin = admin()
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
  end

  -- Check promises.
  promises:update()
end

function populateOptions()
  local firstTab = nil
  for _, tab in ipairs(tabs) do
    tab.title = " "
    tab.icon = tab.id..".png"
    tab.contents = copy(tabField.data)
    replaceInData(tab.contents, "id", "<panel>", "panel_"..tab.id)
    replaceInData(tab.contents, "text", "<title>", tab.description)
    local newTab = tabField:newTab(tab)

    if not firstTab then
      firstTab = newTab
    end
  end
  firstTab:select()

  for optionIndex, option in ipairs(options) do
    local statModifierString = ""
    if not option.hideStats then
      for _, statModifier in ipairs(option.statModifiers or jarray()) do
        local modifierColour = (stats[statModifier[1]].negative and statModifier[2] < 0 or statModifier[2] > 0) and "^green;" or "^red;"
        local amount = (stats[statModifier[1]].invertDescriptor and (statModifier[2] * -1) or statModifier[2]) * 100
        local statColour = stats[statModifier[1]].colour and ("^#"..stats[statModifier[1]].colour.."aa;") or "^gray;"
        statModifierString = statModifierString..string.format("\n%s%s^gray; %s by %s%s", statColour, stats[statModifier[1]].pretty, amount > 0 and "increased" or "reduced", modifierColour, math.floor(math.abs(amount) + 0.5)).."%"
      end

      for _, statOverride in ipairs(option.statOverrides or jarray()) do
        local overrideColour = (stats[statOverride[1]].negative and statOverride[2] < stats[statOverride[1]].base or statOverride[2] > stats[statOverride[1]].base) and "^green;" or "^red;"
        local amount = (stats[statOverride[1]].invertDescriptor and (statOverride[2] * -1) or statOverride[2]) * (stats[statOverride[1]].flat and 1 or 100)
        local statColour = stats[statOverride[1]].colour and ("^#"..stats[statOverride[1]].colour.."aa;") or "^gray;"
        statModifierString = statModifierString..string.format("\n%s%s^gray; set to %s%s", statColour, stats[statOverride[1]].pretty, overrideColour, math.floor(math.abs(amount) + 0.5))..(stats[statOverride[1]].flat and "" or "%")
      end
    end
    local optionWidget = {
      type = "panel", style = "concave", expandMode = {1, 0}, children = {
        {type = "layout", mode = "manual", size = {131, 20}, children = {
          {id = string.format("%sOption", option.name), type = "checkBox", position = {4, 5}, size = {9, 9}, toolTip = option.description..statModifierString..(option.footer and "\n"..option.footer or ""), radioGroup = option.group and option.name or nil},
          {type = "label", position = {15, 6}, size = {120, 9}, align = "left", text = option.pretty},
        }}
      }
    }
    if _ENV[(string.format("panel_%s", option.tab))] then
      _ENV[(string.format("panel_%s", option.tab))]:addChild(optionWidget)
      _ENV[string.format("%sOption", option.name)].onClick = function() toggleOption(option) end
      _ENV[string.format("%sOption", option.name)]:setChecked(starPounds.hasOption(option.name))
    end
  end
end

function toggleOption(option)
  local enabled = starPounds.setOption(option.name, not starPounds.hasOption(option.name))
  if option.group then
    for _, disableOption in ipairs(options) do
      if (disableOption.name ~= option.name) and (disableOption.group == option.group) then
        _ENV[string.format("%sOption", disableOption.name)]:setChecked(starPounds.setOption(disableOption.name, false))
      end
    end
  end
  _ENV[string.format("%sOption", option.name)]:setChecked(enabled)
  starPounds.setOptionsMultipliers(options)
  starPounds.setOptionsOverrides(options)
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
    title = "Options",
    icon = "/interface/scripted/starpounds/options/icon.png",
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

function admin()
  return (player.isAdmin() or starPounds.hasOption("admin")) or false
end

function replaceInData(data, keyname, value, replacevalue)
  if type(data) == "table" then
    for k, v in pairs(data) do
      if (k == keyname or keyname == nil) and (v == value or value == nil) then
        -- sb.logInfo("Replacing value %s of key %s with value %s", v, k, replacevalue)
        data[k] = replacevalue
      else
        replaceInData(v, keyname, value, replacevalue)
      end
    end
  end
end

require "/scripts/messageutil.lua"
require "/scripts/util.lua"

starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.enabled and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
	skills = root.assetJson("/scripts/starpounds/starpounds_skills.config:skills")
	traits = root.assetJson("/scripts/starpounds/starpounds_traits.config:traits")
  tabs = root.assetJson("/scripts/starpounds/starpounds_skills.config:tabs")
  tabNames = {}

  if metagui.inputData.tabs then
    local filteredTabs = jarray()
    local filteredSkills = {}

    for _, tab in ipairs(tabs) do
      if contains(metagui.inputData.tabs, tab.id) then
        filteredTabs[#filteredTabs + 1] = tab
      end
    end

    for skillName, skill in pairs(skills) do
      if contains(metagui.inputData.tabs, skill.tab) then
        filteredSkills[skillName] = skill
      end
    end

    tabs = filteredTabs
    skills = filteredSkills
  end

  descriptionFunctions = {}

  isAdmin = admin()

  weightDecrease:setVisible(isAdmin)
  weightIncrease:setVisible(isAdmin)
  barPadding:setVisible(not isAdmin)
  enableUpgrades = metagui.inputData.isObject or isAdmin
  selectedSkill = nil
  setProgress(starPounds.experience, starPounds.level)
  -- Make the trait tab show first if we don't have one.
  if not (starPounds.getTrait() or starPounds.hasOption("lowerTraitTab")) then
    populateTraitTab()
    populateSkillTree()
  else
    populateSkillTree()
    populateTraitTab()
  end
  resetInfoPanel()
  checkSkills()
end

function update()
  -- Pane title and icon don't update properly in init() >:(
  if not titleFix then
    titleFix = true

    if metagui.inputData.title then
      metagui.setTitle(metagui.inputData.title)
      metagui.queueFrameRedraw()
    end
    if metagui.inputData.iconSuffix then
      metagui.setIcon(string.format("icon%s.png", metagui.inputData.iconSuffix or ""))
      metagui.queueFrameRedraw()
    end
    if currentTab.id ~= "selectTrait" then
      _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
    end
    -- Can't do this in init for some reason.
    traitBuffers(starPounds.getTrait() ~= nil)
  end

  if isAdmin ~= admin() then
    isAdmin = admin()
    enableUpgrades = metagui.inputData.isObject or isAdmin
    checkSkills()
    if selectedSkill then
      _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
    end
    weightDecrease:setVisible(isAdmin)
    weightIncrease:setVisible(isAdmin)
    barPadding:setVisible(not isAdmin)
  end

  if experience ~= starPounds.experience or level ~= starPounds.level then
    setProgress(starPounds.experience, starPounds.level)
    checkSkills()
  end

  if level ~= starPounds.level then
    if selectedSkill then
      _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
    end
    experienceText:setText(string.format("%s XP", starPounds.level))
    checkSkills()
  end

  -- Check promises.
  promises:update()
  level = starPounds.level
  experience = starPounds.experience
end

function uninit()
end

function enable:onClick()
  local buttonIcon = string.format("%s.png", starPounds.toggleEnable() and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
end

function reset:onClick()
  local confirmLayout = sb.jsonMerge(root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config"), {
    title = metagui.inputData.title or "Skills",
    icon = string.format("/interface/scripted/starpounds/skills/icon%s.png", metagui.inputData.iconSuffix or ""),
    images = {
      portrait = world.entityPortrait(player.id(), "full")
    }
  })
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "starPounds.reset"), function()
        checkSkills()
        resetInfoPanel()
        traitButtons(true)
        traitBuffers(false)
        speciesTraitPanel:setVisible(true)
        selectableTraitPanel:setVisible(true)
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
end

function populateSkillTree()
  for _, tab in ipairs(tabs) do
    tab.title = " "
    tab.icon = string.format("icons/tabs/%s.png", tab.id)
    tab.contents = copy(tabField.data.tabTemplate)
    tab.contents[1].children[1].id = tab.id.."_skillTree"
    tab.contents[1].children[1].children[3].id = tab.id.."_skillCanvas"
    tab.contents[1].children[1].children[4].id = tab.id.."_skillWidgets"

    local newTab = tabField:newTab(tab)
    newTab.pretty = tab.pretty
    newTab.description = tab.description
    newTab.offset = tab.offset

    if not currentTab then
      currentTab = newTab
    end
  end

  for _, tab in ipairs(tabs) do
    _ENV[tab.id.."_skillCanvasBind"] = widget.bindCanvas(_ENV[tab.id.."_skillCanvas"].backingWidget)
    tabNames[tab.id] = tab.pretty
  end

  currentTab:select()

  local offset = {240, 160}
  local iconOffset = {-24, -24}

  local function adjustLinePosition(pos)
    return vec2.add(vec2.add({0, 320}, {24, -20}), vec2.mul(pos, {1, -1}))
  end

  -- First loop just edits all the positions values beforehand, and adds default data
  for skillName, skill in pairs(skills) do
      if not skill.internal then
      skill.position = vec2.add(vec2.add(vec2.mul(skill.position, 24), offset), iconOffset)
      skill.name = skillName
      skill.levels = skill.levels or 1
      skill.cost.increase = skill.cost.increase or 0
      skill.cost.max = skill.cost.max or math.huge
    end
  end

  for skillName, skill in pairs(skills) do
    if not skill.internal then
      local lineColour1 = {152, 133, 99, 255}
      local lineColour2 = {165, 147, 122, 255}

      if skill.connect then
        if skill.connect[2] then
          lineColour1 = skill.connect[2][1]
          lineColour2 = skill.connect[2][2]
        end
        for _, skillName in pairs(skill.connect[1]) do
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour1, 5)
          _ENV[skill.tab.."_skillCanvasBind"]:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour2, 3)
        end
      end
      _ENV[skill.tab.."_skillWidgets"]:addChild(makeSkillWidget(skill))
      -- Make the button callback
      _ENV[string.format("%sSkill", skill.name)].onClick = function() selectSkill(skill) end
      _ENV[string.format("%sSkill_locked", skill.name)].onClick = function() widget.playSound("/sfx/interface/clickon_error.ogg") end
    end
  end
end

function buildTraitTab()
  selectTrait = tabField:newTab(tabField.data.traitTab)
  selectTrait.pretty = "Traits"
  selectTrait.description = "This menu allows you to select a starting trait!\n\nTraits grant you skills, weight, and ^#b8eb00;XP^reset;! \n\nOnce selected, traits cannot be changed unless you reset. Choose wisely!"

  if not currentTab then
    currentTab = selectTrait
  end

  speciesTraitSelect.onClick = (function() setTrait(speciesTrait.id, true) end)
  selectableTraitSelect.onClick = (function() setTrait(selectedTrait.id, false) end)
  traitCycleLeft.onClick = traitCycleDecrease
  traitCycleRight.onClick = traitCycleIncrease
end

function buildTraitPreview(traitType, trait)
  _ENV[traitType.."TraitLabel"]:setText(trait.description)
  if traitType == "species" then
    _ENV[traitType.."TraitIcon"]:setFile(string.format("icons/traits/species/%s.png", trait.id))
  else
    _ENV[traitType.."TraitIcon"]:setFile(string.format("icons/traits/%s.png", trait.id))
  end
  -- Skill display stuff.
  local slotCount = 0
  local slotPosition = 1
  for _, skill in ipairs(trait.skills or jarray()) do
    slotCount = slotCount + 1
  end
  slotCount = math.min(slotCount, 5)
  _ENV[traitType.."TraitSkills"].columns = slotCount
  _ENV[traitType.."TraitSkills"]:setNumSlots(slotCount)
  for _, skill in ipairs(trait.skills or jarray()) do
    _ENV[traitType.."TraitSkills"]:setItem(slotPosition, {name = "starpoundsskill", count = 1, parameters = {skill = skill[1], level = skill[2]}})
    _ENV[traitType.."TraitSkills"].children[slotPosition].hideRarity = true
    slotPosition = slotPosition + 1
  end
  _ENV[traitType.."TraitSkills"]:setVisible(slotCount > 0)
  _ENV[traitType.."TraitSkillsLabel"]:setVisible(slotCount == 0)
  -- Default values for attributes. (Starting weight/milk/XP)
  local attributes = jarray()
  local attributeString = ""
  if trait.weight then
    attributes[#attributes + 1] = string.format("^#%s;Starting Weight:^reset; %slb", starPounds.stats.absorption.colour, trait.weight)
  end
  if trait.breasts then
    attributes[#attributes + 1] = string.format("^#%s;Starting Milk:^reset; %s", starPounds.stats.breastProduction.colour, trait.breasts)
  end
  if trait.experience then
    attributes[#attributes + 1] = string.format("^#%s;Starting XP:^reset; %s", starPounds.stats.experienceMultiplier.colour, trait.experience)
  end
  for i, attribute in ipairs(attributes) do
    if i > 1 then attributeString = attributeString.."\n" end
    attributeString = attributeString..attribute
  end
  if attributeString == "" then attributeString = "^red;None" end
  _ENV[traitType.."TraitAttributes"]:setText(attributeString)
end

function populateTraitTab()
  buildTraitTab()
  local species = player.species()
  speciesTrait = traits[species] or traits.none
  speciesTrait.id = traits[species] and species or "none"
  selectableTraits = jarray()
  -- Add the 'No trait' option if it's not being used to replace the species.
  -- Uses default as the id so that default and the bonus XP show up as the same trait with fetching functions.
  for i, trait in ipairs(root.assetJson("/scripts/starpounds/starpounds_traits.config:selectableTraits")) do
    if starPounds.getTrait() == trait then selectedTraitIndex = i end
    table.insert(selectableTraits, sb.jsonMerge(traits[trait], {id = trait}))
  end
  if speciesTrait.id ~= "none" then
    selectableTraits[#selectableTraits + 1] = sb.jsonMerge(traits.none, {id = "none"})
    if starPounds.getTrait() == "default" then selectedTraitIndex = #selectableTraits + 1 end
  end
  selectedTraitIndex = selectedTraitIndex or math.random(1, #selectableTraits)
  selectedTrait = selectableTraits[selectedTraitIndex]

  local hasTrait = starPounds.getTrait()
  traitButtons(not hasTrait)
  if (hasTrait == species) or (hasTrait == "default" and speciesTrait.id == "none") then
    speciesTraitPanel:setVisible(true)
    selectableTraitPanel:setVisible(false)
  elseif hasTrait then
    selectableTraitPanel:setVisible(true)
    speciesTraitPanel:setVisible(false)
  end

  buildTraitPreview("selectable", selectedTrait)
  buildTraitPreview("species", speciesTrait)
end

function makeSkillWidget(skill)
  local toolTip = string.format("%s%s", skill.pretty:gsub("%^.-;", ""), skill.shortDescription and "\n^gray;"..skill.shortDescription or "")
  local skillWidget = {
    type = "layout", position = skill.position, size = {48, 48}, mode = "manual", children = {
      {id = string.format("%sSkill_back", skill.name), type = "image", noAutoCrop = true, position = {12, 8}, file = string.format("back.png?multiply=%s", skill.colour)},
      {id = string.format("%sSkill", skill.name), toolTip = toolTip, position = {16, 12}, type = "iconButton", image = string.format("icons/skills/%s.png", skill.icon or skill.name), hoverImage = string.format("icons/skills/%s.png", skill.icon or skill.name), pressImage = string.format("icons/skills/%s.png", skill.icon or skill.name).."?border=1;00000000;00000000?crop=1;2;17;18"},
      {id = string.format("%sSkill_locked", skill.name), toolTip = toolTip, visible = false, type = "iconButton", position = {12, 8}, image = "locked.png", hoverImage = "locked.png", pressImage = "locked.png"},
      {id = string.format("%sSkill_check", skill.name), visible = false, type = "image", noAutoCrop = true, position = {28, 20}, file = "check.png"}
    }
  }
  -- Under skill level for multilevel skills.
  if skill.levels > 1 then
    local level = starPounds.getSkillUnlockedLevel(skill.name)
    local currentLevel = starPounds.getSkillLevel(skill.name)
    if currentLevel < level then
      level = string.format("^#ffaaaa;%s^reset;", currentLevel)
    end
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevel", skill.name), type = "image", position = {14, 29}, file = "backLevel.png"})
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevelText", skill.name), type = "label", position = {14, 32}, size = {20, 10}, fontSize = 5, align = "center", text = string.format("%s/%s", level, skill.levels)})
  end

  if skill.hidden then
    skillWidget.children[2] = {id = string.format("%sSkill", skill.name), position = {16, 12}, type = "iconButton", image = string.format("icons/skills/%s.png", skill.hiddenIcon), hoverImage = string.format("icons/skills/%s.png", skill.hiddenIcon), pressImage = string.format("icons/skills/%s.png", skill.hiddenIcon).."?border=1;00000000;00000000?crop=1;2;17;18"}
    skillWidget.children[4].file = "check.png?multiply=00000000"
  elseif isAdmin and starPounds.hasOption("showDebug") then
    local totalSkillCost = 0
    for skillLevel = 1, skill.levels do
      totalSkillCost = totalSkillCost + math.min((skill.cost.base + skill.cost.increase * (skillLevel - 1)), skill.cost.max)
    end
    skillWidget.children[2].toolTip = skillWidget.children[2].toolTip..string.format("\n\n^#665599;Skill Id: ^gray;%s\n^#665599;Base Cost: ^gray;%s XP\n^#665599;Increase: ^gray;%s XP\n^#665599;Total Cost: ^gray;%s XP", skill.name, skill.cost.base, skill.cost.increase, totalSkillCost)
    skillWidget.children[4].toolTip = skillWidget.children[2].toolTip
  end

  return skillWidget
end

function selectSkill(skill)
  unlockPanel:setVisible(true)
  infoPanel:setVisible(false)
  local canIncrease = false
  local canDecrease = false
  local canUpgrade = false
  local useToggle = false
  local skillMaxed = false
  local experienceCost = 0
  descriptionWidget:clearChildren()
  if selectedSkill and (not skill or selectedSkill.name ~= skill.name) then
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:setFile(string.format("back.png?multiply=%s", selectedSkill.colour))
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", selectedSkill.name)]:setImage(
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name),
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name),
      string.format("icons/skills/%s.png", selectedSkill.icon or selectedSkill.name)
    )
    if selectedSkill.hidden then
      _ENV[string.format("%sSkill", selectedSkill.name)]:setImage(
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon),
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon),
        string.format("icons/skills/%s.png", selectedSkill.hiddenIcon)
      )
    end
  end
  if skill then
    _ENV[string.format("%sSkill_back", skill.name)]:setFile(string.format("back.png?multiply=%s?brightness=50?saturation=-15", skill.colour))
    _ENV[string.format("%sSkill_back", skill.name)]:queueRedraw()
    _ENV[string.format("%sSkill", skill.name)]:setImage(
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name),
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name),
      string.format("icons/skills/%s.png?border=1;ffffffaa;00000000", skill.icon or skill.name)
    )

    descriptionTitle:setText("^shadow;"..skill.pretty)
    descriptionIcon:setFile(string.format("icons/skills/%s.png", skill.icon or skill.name))
    descriptionIcon:queueRedraw()
    descriptionText:setText(skill.description)

    local currentLevel = starPounds.getSkillLevel(skill.name)
    local unlockedLevel = starPounds.getSkillUnlockedLevel(skill.name)
    local nextLevel = math.min(unlockedLevel + 1, skill.levels)
    local skillItems = getSkillItems(skill)
    local hasItems = hasSkillItems(skill)
    -- Clear the slots.
    local slotCount = math.min(#skillItems, 5)
    unlockItems.columns = slotCount
    unlockItems:setNumSlots(slotCount)
    -- Set the slots, and check player items.
    for i, item in ipairs(skillItems) do
      unlockItems.children[i].hideRarity = true
      if i <= slotCount then
        unlockItems:setItem(i, {name = item[1], count = item[2], parameters = {}})
      end
    end

    itemPanel:setVisible(slotCount > 0)

    if skill.type == "addStat" or skill.type == "subtractStat" then
      infoPanel:setVisible(true)
      local baseAmount = starPounds.stats[skill.stat].base
      local textColour = starPounds.stats[skill.stat].colour or skill.colour

      local nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
      local nextIncrease = math.floor(0.5 + (100 * (nextAmount - baseAmount)) * 10)/10
      local nextAmount = (starPounds.stats[skill.stat].invertDescriptor and (nextIncrease * -1) or nextIncrease)
      local nextString = currentLevel == skill.levels and "" or string.format("%s%.1f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "").."%"

      local totalAmount = starPounds.getSkillBonus(skill.stat) + starPounds.stats[skill.stat].base
      local totalIncrease = math.floor(0.5 + (100 * totalAmount) * 10)/10
      local amount = totalIncrease ~= 0 and (starPounds.stats[skill.stat].invertDescriptor and (totalIncrease * -1) or totalIncrease) or 0
      local amountString = string.format("%.1f", amount):gsub("%.?0+$", "").."%"

      if starPounds.stats[skill.stat].normalizeBase then
        nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
        nextIncrease = math.floor(0.5 + (100 * (nextAmount - baseAmount)/(baseAmount > 0 and baseAmount or 1)) * 10)/10
        nextAmount = (starPounds.stats[skill.stat].invertDescriptor and (nextIncrease * -1) or nextIncrease)
        nextString = currentLevel == skill.levels and "" or string.format("%s%.1f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "").."%"


        totalIncrease = math.floor(0.5 + (100 * totalAmount/(baseAmount > 0 and baseAmount or 1)) * 10)/10
        amount = totalIncrease ~= 0 and (starPounds.stats[skill.stat].invertDescriptor and (totalIncrease * -1) or totalIncrease) or 0
        amountString = string.format("%.1f", amount):gsub("%.?0+$", "").."%"
      end

      local function tchelper(first, rest)
         return first:upper()..rest:lower()
      end

      infoCurrent:setText(
        string.format("^#%s;%s^reset; \n^clear;%s^reset; %s ^gray;%s", textColour, starPounds.stats[skill.stat].pretty:gsub("(%a)([%w_']*)", tchelper), nextString, amountString, nextString)
      )
      statInfo.toolTip = starPounds.stats[skill.stat].description

    end

    experienceCost = isAdmin and 0 or math.min(skill.cost.base + skill.cost.increase * (nextLevel - 1), skill.cost.max)
    canDecrease = currentLevel > 0
    canIncrease = currentLevel < unlockedLevel
    useToggle = skill.levels == 1
    skillMaxed = unlockedLevel == skill.levels
    canUpgrade = (isAdmin or ((starPounds.level >= experienceCost) and hasItems)) and not skillMaxed
    unlockText:setText(useToggle and (currentLevel > 0 and "On" or "Off") or string.format("%s/%s", currentLevel, unlockedLevel))

    unlockExperience:setText(string.format("^%s;%s XP", skillMaxed and "darkgray" or ((enableUpgrades and canUpgrade) and "green" or "red"), (skillMaxed or not enableUpgrades) and "-" or experienceCost))

    unlockToggle:setVisible(useToggle)
    unlockIncrease:setVisible(not useToggle)
    unlockDecrease:setVisible(not useToggle)

    unlockButton.toolTip = nil
    if not (enableUpgrades and canUpgrade) then
      unlockButton.toolTip = "^red;Upgrading Disabled"
    end

    if skillMaxed then
      unlockButton.toolTip = string.format(unlockButton.toolTip.."\n^gray;Skill fully upgraded!"):gsub("red", "green")
    elseif skill.tab and not enableUpgrades then
      local tab
      local objectConfig
      for _, tab in ipairs(tabs) do
        if skill.tab == tab.id then
          objectConfig = root.itemConfig(tab.defaultObject)
          break
        end
      end

      if objectConfig then
        local objectName = objectConfig.config.shortdescription
        local useAn = string.find(objectName:gsub("%^.-;", ""):sub(1, 1), "[AEIOUaeiou]")
        unlockButton.toolTip = string.format(unlockButton.toolTip.."\n^gray;Requires %s %s^reset;", useAn and "an" or "a", objectName)
      end
    elseif not canUpgrade then
      unlockButton.toolTip = unlockButton.toolTip.."\n^gray;Requires"
      if starPounds.level < experienceCost then
        unlockButton.toolTip = string.format(unlockButton.toolTip.." ^#b8eb00;%s XP^reset;", experienceCost)
      end
      if not hasItems then
        for _, item in ipairs(skillItems) do
          local itemCount = player.hasCountOfItem(item[1])
          local itemName = root.itemConfig(item[1]).config.shortdescription
          local hasItem = itemCount >= item[2]
          unlockButton.toolTip = unlockButton.toolTip..string.format("\n^gray;%s ^%s;%s/%s", itemName, hasItem and "green" or "red", itemCount, item[2])
        end
      end
    end

    unlockToggle:setImage(
      string.format("unlockToggle.png:%s.%s", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled"),
      string.format("unlockToggle.png:%s.%s", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled"),
      string.format("unlockToggle.png:%s.%s?border=1;00000000;00000000?crop=1;2;13;27", (canIncrease or not skillMaxed) and "off" or "on", skillMaxed and "enabled" or "disabled")
    )
    unlockButton:setImage(
      string.format("unlock%s.png", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked"),
      string.format("unlock%s.png", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked"),
      string.format("unlock%s.png?border=1;00000000;00000000?crop=1;2;25;27", enableUpgrades and (canUpgrade and "" or "Disabled") or "Locked")
    )
    unlockIncrease:setImage(
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canIncrease and "" or "Disabled")
    )
    unlockDecrease:setImage(
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canDecrease and "" or "Disabled")
    )
    if skill.widget and (skill.forceWidget or unlockedLevel > 0) then
      require(string.format("/interface/scripted/starpounds/skills/descriptionWidgets/%s.lua", skill.widget.id))
      descriptionWidget:addChild(skill.widget).onClick = descriptionFunctions[skill.widget.id]
    end
  end

  selectedSkill = skill
end

function checkSkills()
  for skillName, skill in pairs(skills) do
    if not skill.internal then
      _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(false)
      -- Under skill level for multilevel skills.
      if skill.levels > 1 then
        local level = starPounds.getSkillUnlockedLevel(skill.name)
        local currentLevel = starPounds.getSkillLevel(skill.name)
        if currentLevel < level then
          level = string.format("^#ffaaaa;%s^reset;", currentLevel)
        end
        _ENV[string.format("%sSkill_backLevelText", skill.name)]:setText(string.format("%s/%s", level, skill.levels))
      end
      if skill.requirements then
        local requirements = "Requires"
        local hasRequirements = true

        if not enableUpgrades then
          local tab
          local objectConfig
          for _, tab in ipairs(tabs) do
            if skill.tab == tab.id then
              objectConfig = root.itemConfig(tab.defaultObject)
              break
            end
          end

          if objectConfig then
            local objectName = objectConfig.config.shortdescription
            requirements = string.format(requirements.."\n^gray;Object: %s^reset;", objectName)
          end
        end

        for requirement, requirementLevel in pairs(skill.requirements) do
          local hasRequirement = starPounds.getSkillUnlockedLevel(requirement) >= requirementLevel
          local name = skills[requirement].pretty:gsub("%^.-;", "")
          local requirementTab = ""

          if skills[requirement].tab ~= skill.tab and not hasRequirement then
            requirementTab = " ^darkgray;- "..tabNames[skills[requirement].tab].."^reset;"
          end

          if starPounds.getSkillUnlockedLevel(requirement) == 0 then
            for requirement, requirementLevel in pairs(skills[requirement].requirements or {}) do
              if not (starPounds.getSkillUnlockedLevel(requirement) >= requirementLevel) then
                name = name:lower():gsub("[a-z]",
                  {a="", b="", c="", d="", e="", f="", g="", h="", i="", j="", k="", l="", m="", n="", o="", p="", q="", r="", s="", t="", u="", v="", w="", x="", y="", z=""}
                )
              end
            end
          end
          hasRequirements = hasRequirements and hasRequirement
          requirements = string.format("%s\n^%s;%s%s",
            requirements,
            hasRequirement and "green" or "red",
            name..((skills[requirement].levels or 1) > 1 and ": "..requirementLevel or ""),
            requirementTab
          )
        end

        if selectedSkill and selectedSkill.name == skill.name then
          if not (hasRequirements or isAdmin or starPounds.hasSkill(skill.name)) then
            resetInfoPanel()
          end
        end
        _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(not ((enableUpgrades and hasRequirements) or isAdmin or starPounds.getSkillUnlockedLevel(skill.name) > 0))
        _ENV[string.format("%sSkill_locked", skill.name)].toolTip = requirements
      end
      _ENV[string.format("%sSkill_check", skill.name)]:setVisible(starPounds.getSkillUnlockedLevel(skill.name) == skill.levels)
    end
  end
end

function tabField:onTabChanged(tab, previous)
  if currentTab then
    currentTab = tab
    resetInfoPanel()
    if currentTab.id ~= "selectTrait" then
      _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
    end
  end
end

function resetInfoPanel()
  selectSkill()
  local icon = string.format("icons/tabs/%s.png", currentTab.id)
  infoPanel:setVisible(false)
  unlockPanel:setVisible(false)
  descriptionTitle:setText(currentTab.pretty)
  descriptionText:setText(currentTab.description)
  descriptionIcon:setFile(icon)
  descriptionIcon:queueRedraw()
end

function unlockButton:onClick()
  local experienceLevel = math.min((starPounds.getSkillUnlockedLevel(selectedSkill.name)) + 1, selectedSkill.levels) - 1
  local experienceCost = math.min(selectedSkill.cost.base + selectedSkill.cost.increase * experienceLevel, selectedSkill.cost.max)
  local canUpgrade = isAdmin or (hasSkillItems(selectedSkill) and starPounds.level >= experienceCost)
  selectSkill(selectedSkill)
  if starPounds.getSkillUnlockedLevel(selectedSkill.name) == selectedSkill.levels or not canUpgrade or not enableUpgrades then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
  end
  if not isAdmin then
    for _, item in ipairs(getSkillItems(selectedSkill)) do
      player.consumeItem({name = item[1], count = item[2]})
    end
  end
  starPounds.upgradeSkill(selectedSkill.name, isAdmin and 0 or experienceCost)
  local level = starPounds.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = starPounds.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
  end
  checkSkills()
  selectSkill(selectedSkill)
  widget.playSound("/sfx/interface/crafting_medical.ogg")
end

function getSkillItems(skill)
  local unlockedLevel = starPounds.getSkillUnlockedLevel(skill.name)
  local nextLevel = math.min(unlockedLevel + 1, skill.levels)
  local skillItems = jarray()

  for _, requiredItems in ipairs(skill.upgradeItems or jarray()) do
    if nextLevel >= requiredItems[1] then
      skillItems = requiredItems[2]
    else
      break
    end
  end
  return skillItems
end

function hasSkillItems(skill)
  local skillItems = getSkillItems(skill)
  local hasItems = true
  -- Clear the slots.
  for i, item in ipairs(skillItems) do
    if player.hasCountOfItem(item[1]) < item[2] then
      hasItems = false
    end
  end
  return hasItems
end

function unlockIncrease:onClick()
  starPounds.setSkill(selectedSkill.name, metagui.checkShift() and starPounds.getSkillUnlockedLevel(selectedSkill.name) or (starPounds.getSkillLevel(selectedSkill.name) + 1))
  local level = starPounds.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = starPounds.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end

  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
end

function unlockDecrease:onClick()
  starPounds.setSkill(selectedSkill.name, metagui.checkShift() and 0 or (starPounds.getSkillLevel(selectedSkill.name) - 1))
  local level = starPounds.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = starPounds.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  selectSkill(selectedSkill)
  _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
end

function unlockToggle:onClick()
  if starPounds.getSkillUnlockedLevel(selectedSkill.name) > 0 then
    starPounds.setSkill(selectedSkill.name, (starPounds.getSkillLevel(selectedSkill.name) == 0) and 1 or 0)
    selectSkill(selectedSkill)
  end
end

function setTrait(trait, isSpecies)
  if starPounds.setTrait(trait) then
    traitButtons(false)
    traitBuffers(true)
    if isSpecies then
      speciesTraitPanel:setVisible(true)
      selectableTraitPanel:setVisible(false)
    else
      selectableTraitPanel:setVisible(true)
      speciesTraitPanel:setVisible(false)
    end
    checkSkills()
    widget.playSound("/sfx/interface/crafting_medical.ogg")
  end
end

function traitCycleDecrease()
  local hasTrait = starPounds.getTrait()
  if not hasTrait then
    selectedTraitIndex = (selectedTraitIndex - 2 + #selectableTraits) % #selectableTraits + 1
    selectedTrait = selectableTraits[selectedTraitIndex]
    buildTraitPreview("selectable", selectedTrait)
  end
end

function traitCycleIncrease()
  local hasTrait = starPounds.getTrait()
  if not hasTrait then
    selectedTraitIndex = (selectedTraitIndex % #selectableTraits) + 1
    selectedTrait = selectableTraits[selectedTraitIndex]
    buildTraitPreview("selectable", selectedTrait)
  end
end

function traitButtons(enable)
  speciesTraitSelect:setImage(
    string.format("traitSelect%s.png", enable and "" or "Disabled"),
    string.format("traitSelect%s.png", enable and "" or "Disabled"),
    string.format("traitSelect%s.png?border=1;00000000;00000000?crop=1;2;33;18", enable and "" or "Disabled")
  )
  selectableTraitSelect:setImage(
    string.format("traitSelect%s.png", enable and "" or "Disabled"),
    string.format("traitSelect%s.png", enable and "" or "Disabled"),
    string.format("traitSelect%s.png?border=1;00000000;00000000?crop=1;2;33;18", enable and "" or "Disabled")
  )
  traitCycleLeft:setImage(
    string.format("traitCycleLeft%s.png", enable and "" or "Disabled"),
    string.format("traitCycleLeft%s.png", enable and "" or "Disabled"),
    string.format("traitCycleLeft%s.png?border=1;00000000;00000000?crop=1;2;12;15", enable and "" or "Disabled")
  )
  traitCycleRight:setImage(
    string.format("traitCycleRight%s.png", enable and "" or "Disabled"),
    string.format("traitCycleRight%s.png", enable and "" or "Disabled"),
    string.format("traitCycleRight%s.png?border=1;00000000;00000000?crop=1;2;12;15", enable and "" or "Disabled")
  )
end


function traitBuffers(enable)
  startBuffer:setVisible(enable)
  endBuffer:setVisible(enable)
end

function statInfo:onClick()
  statInfoCount = (statInfoCount or 0) + 1
  if statInfoCount == 50 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "You know this isn't an actual button right? It doesn't do anything. It will never do anything. It's just the only easy way to get tooltips to work here."})
  elseif statInfoCount == 100 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Since you decided you would click this 100 times you're probably expecting a reward, so have a single pixel. You're welcome."})
    player.giveItem("money")
  elseif statInfoCount == 250 then
    player.radioMessage({important = true, unique = false, messageId = "BUT_WHY", text = "Whatever." })
    player.giveItem("gracecupcake")
    widget.playSound("/sfx/objects/colonydeed_partyhorn.ogg", nil, 0.75)
  end
end

function setProgress(experience, level)
  local progress = experience/(starPounds.settings.experienceAmount * (1 + level * starPounds.settings.experienceIncrement))
  experienceBar:setFile(string.format("bar.png?crop;0;0;%s;14", math.floor(70 * (progress or 0) + 0.5)))
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

function admin()
  return (player.isAdmin() or starPounds.hasOption("admin")) or false
end

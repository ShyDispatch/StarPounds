require "/scripts/messageutil.lua"
require "/scripts/util.lua"

starPounds = getmetatable ''.starPounds

function init()
  local buttonIcon = string.format("%s.png", starPounds.enabled and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
	skills = root.assetJson("/scripts/starpounds/starpounds_skills.config:skills")
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

  isAdmin = player.isAdmin()

  weightDecrease:setVisible(isAdmin)
  weightIncrease:setVisible(isAdmin)
  barPadding:setVisible(not isAdmin)
  enableUpgrades = metagui.inputData.isObject or isAdmin
  selectedSkill = nil
  setProgress(starPounds.experience, starPounds.level)
  populateSkillTree()
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
    _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
  end

  if player.isAdmin() ~= isAdmin then
    isAdmin = player.isAdmin()
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
    tab.contents = copy(tabField.data)
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
    _ENV[string.format("%sSkill_back", skill.name)]:setFile(string.format("back.png?multiply=%s?brightness=30?saturation=-30", skill.colour))
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

    if skill.type == "addStat" or skill.type == "subtractStat" then
      infoPanel:setVisible(true)
      local baseAmount = starPounds.stats[skill.stat].base
      local textColour = starPounds.stats[skill.stat].colour or skill.colour

      local nextAmount = baseAmount + skill.amount * (skill.type == "addStat" and 1 or -1)
      local nextIncrease = math.floor(0.5 + (100 * (nextAmount - baseAmount)/(baseAmount > 0 and baseAmount or 1)) * 10)/10
      local nextAmount = (starPounds.stats[skill.stat].invertDescriptor and (nextIncrease * -1) or nextIncrease)
      local nextString = starPounds.getSkillLevel(skill.name) == skill.levels and "" or string.format("%s%.1f", nextAmount > 0 and "+" or "", nextAmount):gsub("%.?0+$", "").."%"

      local totalAmount = starPounds.getSkillBonus(skill.stat)
      local totalIncrease = math.floor(0.5 + (100 * totalAmount/(baseAmount > 0 and baseAmount or 1)) * 10)/10
      local amount = totalIncrease ~= 0 and (starPounds.stats[skill.stat].invertDescriptor and (totalIncrease * -1) or totalIncrease) or 0
      local amountString = string.format("%s%.1f", amount > 0 and "+" or "", amount):gsub("%.?0+$", "").."%"

      local function tchelper(first, rest)
         return first:upper()..rest:lower()
      end

      infoCurrent:setText(
        string.format("^#%s;%s^reset; \n^clear;%s^reset; %s ^gray;%s", textColour, starPounds.stats[skill.stat].pretty:gsub("(%a)([%w_']*)", tchelper), nextString, amountString, nextString)
      )
      statInfo.toolTip = starPounds.stats[skill.stat].description

    end

    local experienceLevel = math.min(starPounds.getSkillUnlockedLevel(skill.name) + 1, skill.levels) - 1
    experienceCost = isAdmin and 0 or (skill.cost.base + skill.cost.increase * experienceLevel)
    canDecrease = starPounds.getSkillLevel(skill.name) > 0
    canIncrease = starPounds.getSkillLevel(skill.name) < starPounds.getSkillUnlockedLevel(skill.name)
    useToggle = skill.levels == 1
    skillMaxed = starPounds.getSkillUnlockedLevel(skill.name) == skill.levels
    canUpgrade = (starPounds.level >= experienceCost) and not skillMaxed
    unlockText:setText(useToggle and (starPounds.getSkillLevel(skill.name) > 0 and "On" or "Off") or string.format("%s/%s", starPounds.getSkillLevel(skill.name), starPounds.getSkillUnlockedLevel(skill.name)))

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
      unlockButton.toolTip = string.format(unlockButton.toolTip.."\n^gray;Requires ^#b8eb00;%s XP^reset;", experienceCost)
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
    if skill.widget and (skill.forceWidget or starPounds.getSkillUnlockedLevel(skill.name) > 0) then
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
    _ENV[currentTab.id.."_skillTree"]:scrollTo(currentTab.offset)
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
  local experienceCost = selectedSkill.cost.base + selectedSkill.cost.increase * experienceLevel
  local canUpgrade = isAdmin or starPounds.level >= experienceCost
  if starPounds.getSkillUnlockedLevel(selectedSkill.name) == selectedSkill.levels or not canUpgrade or not enableUpgrades then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
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

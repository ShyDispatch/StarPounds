starPounds = getmetatable ''.starPounds
function init()
  maxStack = root.assetJson("/items/defaultParameters.config:defaultMaxStack")
  extracting = false
  extractTimer = 0.5
  updateButtonIcon()
end

function update()
  updateButtonIcon()
  updateStatusImage()
  if starPounds.enabled and extracting then
    extractTimer = math.max(extractTimer - script.updateDt(), 0)
    local weight = starPounds.getData("weight")
    if canExtract() then
      if extractTimer == 0 then
        local caloriumCost = 10 + math.min(50, math.floor(0.02 * weight))
        local converted = math.floor(starPounds.loseWeight((caloriumCost)/starPounds.getStat("weightLoss"))/caloriumCost)
        addCalorium(converted)
        world.sendEntityMessage(pane.sourceEntity(), "heartbeat")
        extractTimer = 0.1
      end
    else
      extracting = false
      widget.playSound("/sfx/objects/apexcoolcomputer_switchoff.ogg")
    end
  end
end

function extract:onClick()
  if not extracting and not canExtract() then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
  end
  extracting = not extracting
  if extracting then
    widget.playSound("/sfx/objects/apexcoolcomputer_switchon.ogg")
    world.sendEntityMessage(pane.sourceEntity(), "heartbeat")
  else
    widget.playSound("/sfx/objects/apexcoolcomputer_switchoff.ogg")
  end
end

function caloriumOutput:acceptsItem(item)
  return item.name == "starpoundsliquidcalorium"
end

function addCalorium(amount)
  local item = caloriumOutput:item() or {name = "starpoundsliquidcalorium", count = 0}
  item.count = math.min(maxStack, item.count + amount)
  caloriumOutput:setItem(item)
end

function canExtract()
  local weight = starPounds.getData("weight")
  local itemCount = (caloriumOutput:item() or {name = "starpoundsliquidcalorium", count = 0}).count
  local canExtract = starPounds.enabled and not starPounds.hasOption("disableLoss") and weight >= 10 and itemCount < maxStack
  return canExtract
end

function updateButtonIcon()
  local buttonIcon = string.format("button.png:%s", canExtract() and (extracting and "on" or "off") or "disabled")
  extract:setImage(buttonIcon, buttonIcon, buttonIcon)
end

function updateStatusImage()
  statusImage:setFile("status.png:"..(extracting and "on" or "off"))
end

function uninit()
  player.giveItem(caloriumOutput:item())
end

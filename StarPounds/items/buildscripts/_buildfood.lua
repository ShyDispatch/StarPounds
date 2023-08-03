function build(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  if not parameters.timeToRot then
    local rottingMultiplier = parameters.rottingMultiplier or config.rottingMultiplier or 1.0
    parameters.timeToRot = root.assetJson("/items/rotting.config:baseTimeToRot") * rottingMultiplier
  end

  config.tooltipFields = config.tooltipFields or {}
  config.tooltipFields.rotTimeLabel = getRotTimeDescription(parameters.timeToRot)

  if not configParameter("effectApplied", false) then
    local experienceRatio = {
      common = 1,
      uncommon = 1.1,
      rare = 1.25,
      legendary = 1.5,
      essential = 1.5
    }
    parameters.effectApplied = true
    local effects = configParameter("effects", jarray())
    if not effects[1] then
      table.insert(effects, jarray())
    end
    table.insert(effects[1], {effect = "starpoundsfood", duration = configParameter("foodValue", 0)})
    table.insert(effects[1], {effect = "starpoundsexperience", duration = configParameter("foodValue", 0) * experienceRatio[string.lower(configParameter("rarity", "common"))]})
    parameters.effects = effects
    parameters.bf_foodValue = configParameter("foodValue", 0)
    parameters.foodValue = 0
  end

  return config, parameters
end

function getRotTimeDescription(rotTime)
  local descList = root.assetJson("/items/rotting.config:rotTimeDescriptions")
  for i, desc in ipairs(descList) do
    if rotTime <= desc[1] then return desc[2] end
  end
  return descList[#descList]
end

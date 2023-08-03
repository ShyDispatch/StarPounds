require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"

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

  -- initialize randomization
  if seed then
    parameters.seed = seed
  elseif config.statConfig then
    seed = configParameter("seed")
    if not seed then
      math.randomseed(util.seedTime())
      seed = math.random(1, 4294967295)
      parameters.seed = seed
    end
  end

  -- name
  if config.builderConfig.nameGenerator then
    config.shortdescription = root.generateName(util.absolutePath(directory, config.builderConfig.nameGenerator), seed)
  end
  -- build palette swap directives
  config.paletteSwaps = ""
  if config.builderConfig.trimPalette and sb.staticRandomDouble(seed, "config.builderConfig") > 0.25 then
    local palette = root.assetJson(util.absolutePath(directory, config.builderConfig.trimPalette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwapsTrim")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  else
      config.paletteSwaps = string.format("%s?replace;951500=735e3a;be1b00=a38d59;dc1f00=d9c189;f32200=f7e7b2;", config.paletteSwaps)
  end
  if config.builderConfig.metalPalette then
    local palette = root.assetJson(util.absolutePath(directory, config.builderConfig.metalPalette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwapsMetal")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end
  if config.builderConfig.crystalPalette then
    local palette = root.assetJson(util.absolutePath(directory, config.builderConfig.crystalPalette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwapsCrystal")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end

  -- build icon
  local tier = math.min(config.builderConfig.tier or 1, 3)
  local icon = string.format("%s.png:%s%s", configParameter("accessoryType", "ring"), tier, config.paletteSwaps)
  config.inventoryIcon = config.inventoryIcon or icon

  config.scripts = {"/items/active/accessories/accessory.lua"}
  config.animation = "/items/active/accessories/accessory.animation"
  config.animationParts = config.animationParts or {accessory = config.inventoryIcon, accessoryFullbright = ""}
  if config.builderConfig.fullbright then
    config.animationParts.accessoryFullbright = config.animationParts.accessory:gsub(".png", "_fullbright.png")
  end

  -- build stats
  parameters.stats = parameters.stats or config.stats
  if not parameters.stats then
    local experienceMultiplier = 0
    parameters.stats = jarray()
    local statCount = math.min(config.statConfig.count, 3)
    local statList = {table.unpack(config.statConfig.list)}
    for i=1, statCount do
      local switch = (i > (statCount - (config.statConfig.negativeCount or 0))) and -1 or 1
      local stat = table.remove(statList, randomIntInRange({1, #statList}, seed, "stat"..i))
      local modifier = math.floor(randomInRange(config.statConfig.amplitude, seed, "stat"..i) * switch * (100/stat.weight) + 0.5)/100
      table.insert(parameters.stats, {
        name = stat.name,
        modifier = modifier
      })
      experienceMultiplier = experienceMultiplier + (modifier * -0.5 * stat.weight)
    end

    table.sort(parameters.stats, function(a, b) return a.name < b.name end)

    if config.statConfig.experienceMultiplier then
      parameters.stats[#parameters.stats + 1] = {name = "experienceMultiplier", modifier = math.floor(experienceMultiplier*100)/100}
    end
  end

  -- tooltip fields
  config.tooltipFields = {}
  config.tooltipFields.statusList = jarray()
  for i, stat in ipairs(parameters.stats) do
    config.tooltipFields["stat"..i.."_Label"] = string.format("%s%s%%", stat.modifier > 0 and "+" or "", math.floor(100 * stat.modifier + 0.5))
    config.tooltipFields["stat"..i.."_Image"] = string.format("/interface/tooltips/accessoryicons/%s.png", stat.name)
    -- setting this here so the background shows without the skill
    config.tooltipFields["stat"..i.."_BackgroundImage"] = "/interface/tooltips/statlistback.png"
  end

  return config, parameters
end

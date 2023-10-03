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

  local starPoundsConfig = configParameter("starPounds", {})
  local sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes")
  local sizeKeys = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizeKeys")
  local species = starPoundsConfig.species
  local size = starPoundsConfig.size
  local variant = starPoundsConfig.variant

  local sizeConfig
  for index, sizeName in ipairs(sizeKeys) do
    if sizeName == size then
      sizeConfig = sizes[index]
      if size == "" then size = "default" end
    end
  end

  species = species and species.."/" or ""
  size = size and size.."/" or ""
  variant = variant and variant.."/" or ""

  local imagePath = string.format("%s%s", species, size)
  local variantImagePath = string.format("%s%s", imagePath, variant)

  config.inventoryIcon = string.format("%s%sicons.png:%s", directory, imagePath, config.starPounds.type:gsub("legs", "pants"))
  config.statusEffects = jarray()
  if starPoundsConfig.size then
    table.insert(config.statusEffects, "starpounds"..starPoundsConfig.size)
  end
  if starPoundsConfig.variant then
    table.insert(config.statusEffects, "starpounds"..starPoundsConfig.variant)
  end


  if config.starPounds.type == "chest" then
    local maleChest = sizeConfig.armorFlags.maleChest
    local maleBSleeve = sizeConfig.armorFlags.maleBSleeve
    local maleFSleeve = sizeConfig.armorFlags.maleFSleeve
    config.maleFrames = {
      body = string.format("%s%s", variantImagePath, maleChest and "chestm.png" or "chest.png"),
      backSleeve = string.format("%s%s", imagePath, maleBSleeve and "bsleevem.png" or "bsleeve.png"),
      frontSleeve = string.format("%s%s", imagePath, maleFSleeve and "fsleevem.png" or "fsleeve.png")
    }

    local femaleChest = sizeConfig.armorFlags.femaleChest
    local femaleBSleeve = sizeConfig.armorFlags.femaleBSleeve
    local femaleFSleeve = sizeConfig.armorFlags.femaleFSleeve
    config.femaleFrames = {
      body = string.format("%s%s", variantImagePath, femaleChest and "chestf.png" or "chest.png"),
      backSleeve = string.format("%s%s", imagePath, femaleBSleeve and "bsleevef.png" or "bsleeve.png"),
      frontSleeve = string.format("%s%s", imagePath, femaleFSleeve and "fsleevef.png" or "fsleeve.png")
    }
  elseif config.starPounds.type == "legs" then
    local maleLegs = sizeConfig.armorFlags.maleLegs
    config.maleFrames = string.format("%s%s", imagePath, maleLegs and "pantsm.png" or "pants.png")

    local femaleLegs = sizeConfig.armorFlags.femaleLegs
    config.femaleFrames = string.format("%s%s", imagePath, femaleLegs and "pantsf.png" or "pants.png")
  end
  parameters.maleFrames = config.maleFrames
  parameters.femaleFrames = config.femaleFrames

  return config, parameters
end

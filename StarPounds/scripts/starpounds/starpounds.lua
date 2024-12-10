require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"

local function nullFunction()
end

starPounds = {
  settings = root.assetJson("/scripts/starpounds/starpounds.config:settings"),
  sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes"),
  stats = root.assetJson("/scripts/starpounds/starpounds_stats.config"),
  foods = root.assetJson("/scripts/starpounds/starpounds_foods.config"),
  skills = root.assetJson("/scripts/starpounds/starpounds_skills.config:skills"),
  traits = root.assetJson("/scripts/starpounds/starpounds_traits.config:traits"),
  effects = root.assetJson("/scripts/starpounds/starpounds_effects.config:effects"),
  selectableTraits = root.assetJson("/scripts/starpounds/starpounds_traits.config:selectableTraits"),
  species = root.assetJson("/scripts/starpounds/starpounds_species.config"),
  baseData = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
}
-- Mod functions
----------------------------------------------------------------------------------
starPounds.isEnabled = function()
  return storage.starPounds.enabled
end

starPounds.getData = function(key)
  if key then return storage.starPounds[key] end
  return storage.starPounds
end

-- Runs a function in a module. Same as calling directly, but makes sure it exists.
starPounds.moduleFunc = function(name, func, ...)
  local module = starPounds.modules[name]
  if module then
    return module[func](module, ...)
  end
end

starPounds.moduleInit = function(moduleGroups)
  starPounds.modules = starPounds.modules or {}
  local modulePath = "/scripts/starpounds/modules/%s.lua"
  if moduleGroups then
    if type(moduleGroups) == "string" then moduleGroups = {moduleGroups} end
    for _, moduleGroup in ipairs(moduleGroups) do
      for i = 1, #starPounds.settings.modules[moduleGroup] do
        require(string.format(modulePath, starPounds.settings.modules[moduleGroup][i]))
        local module = starPounds.modules[starPounds.settings.modules[moduleGroup][i]]
        module:moduleInit()
      end
    end
  end
end

starPounds.moduleUpdate = function(dt)
  for _, module in pairs(starPounds.modules) do
    module:moduleUpdate(dt)
  end
end

starPounds.moduleUninit = function()
  for _, module in pairs(starPounds.modules) do
    module:uninit()
  end
end

starPounds.module = {}
function starPounds.module:new(name)
  local module = {}
  local modulePath = "/scripts/starpounds/modules/%s.config"
  module.data = root.assetJson(string.format(modulePath, name))
  setmetatable(module, extend(self))
  return module
end

-- Specific module initialising.
function starPounds.module:moduleInit()
  -- Sticking all the management stuff under a module table just in case.
  self.module = {
    parentDelta = math.round(60 * script.updateDt()),
    tickCounter = 0,
    updateTicks = 1
  }
  self:setUpdateDelta(self.data.scriptDelta)
  self:init()
end
-- Instead of a timer, just count update ticks of the main script.
-- E.g. If the module delta is 10, and the main script is 5, update every 2 main script ticks.
function starPounds.module:moduleUpdate(dt) -- Updates the module's update loop based on it's delta.
  if self.module.updateTicks == 0 then return end
  self.module.tickCounter = (self.module.tickCounter + 1) % self.module.updateTicks
  if self.module.tickCounter == 0 then
    -- Run the actual update loop.
    self:update(dt * self.module.updateTicks)
  end
end

function starPounds.module:setUpdateDelta(dt)
  -- Argument sanitisation.
  dt = math.max(tonumber(dt) or 1, 0)
  -- 0 = No update.
  if dt == 0 then
    self.module.updateTicks = 0
    return
  end
  self.module.updateTicks = math.max(math.round(dt / self.module.parentDelta), 1)
end
-- Standard functions.
function starPounds.module:init() end -- Runs whenever the target loads in, or the mod gets enabled.
function starPounds.module:update(dt) end -- Update loop.
function starPounds.module:uninit() end -- Runs whenever the target unloads, or the mod gets disabled.

starPounds.belch = function(volume, pitch, loops, addMomentum)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  volume = tonumber(volume) or 1
  pitch = tonumber(pitch) or 1
  loops = tonumber(loops)
  if addMomentum == nil then addMomentum = true end
  -- Skip if belches are disabled.
  if starPounds.hasOption("disableBelches") then return end
  starPounds.moduleFunc("sound", "play", "belch", volume, pitch, loops)
  -- 7.5 (Rounded to 8) to 10 particles, decreased or increased by up to 2x, -5
  -- Ends up yielding around 10 - 15 particles if the belch is very loud and deep, 3 - 5 at normal volume and pitch, and none if it's half volume or twice as high pitch.
  local volumeMultiplier = math.max(math.min(volume, 1.5), 0)
  local pitchMultiplier = 1/math.max(pitch, 2/3)
  local particleCount = starPounds.hasOption("disableBelchParticles") and 0 or math.round(math.max(math.random(75, 100) * 0.1 * pitchMultiplier * volumeMultiplier - 5, 0))
  -- Belches give momentum in zero g based on the particle count, because why not.
  local facingDirection = mcontroller.facingDirection()
  if addMomentum and mcontroller.zeroG() then
    mcontroller.addMomentum({-0.5 * facingDirection * (0.5 + starPounds.weightMultiplier * 0.5) * particleCount, 0})
  end
  -- Alert nearby enemies.
  local targets = world.entityQuery(mcontroller.position(), starPounds.settings.belchAlertRadius * volume, { includedTypes = {"npc", "monster"} })
  for _, target in pairs(targets) do
    if world.entityAggressive(target) and world.entityCanDamage(target, entity.id()) then
      world.sendEntityMessage(target, "starPounds.notifyDamage", {sourceId = entity.id()})
    end
  end
  -- Skip if we're not doing particles.
  if particleCount == 0 then return end
  local mouthPosition = starPounds.mouthPosition()
  local gravity = world.gravity(mouthPosition)
  local friction = world.breathable(mouthPosition) or world.liquidAt(mouthPosition)
  local particle = sb.jsonMerge(starPounds.settings.particleTemplates.belch, {})
  particle.initialVelocity = vec2.add({7 * facingDirection, 0}, vec2.add(mcontroller.velocity(), {0, gravity/62.5})) -- Weird math but it works I guess.
  particle.finalVelocity = {0, -gravity}
  particle.approach = {friction and 5 or 0, gravity}
  starPounds.spawnMouthProjectile({{action = "particle", specification = particle}}, particleCount)
end

starPounds.belchPitch = function(multiplier)
  multiplier = tonumber(multiplier) or 1
  local pitch = util.randomInRange(starPounds.settings.belchPitch)
  if not starPounds.hasOption("genderlessBelches") then
    local gender = world.entityGender(entity.id())
    if gender then
      pitch = pitch + (starPounds.settings.belchGenderModifiers[gender] or 0)
    end
  end
  pitch = math.round(pitch * multiplier, 2)
  return pitch
end

starPounds.mouthPosition = function()
  -- Silly, but when the uninitialising this returns nil.
  if world.entityMouthPosition(entity.id()) == nil then return mcontroller.position() end
  local facingDirection = mcontroller.facingDirection()
  local crouching = mcontroller.crouching()
  local mouthOffset = {0.375 * mcontroller.facingDirection() * (crouching and 1.5 or 1), (crouching and -1 or 0)}
  return vec2.add(world.entityMouthPosition(entity.id()), mouthOffset)
end

starPounds.spawnMouthProjectile = function(actions, count)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  if not actions then return end
  count = tonumber(count) or 1
  local mouthPosition = starPounds.mouthPosition()
  world.spawnProjectile("invisibleprojectile", vec2.add(mouthPosition, mcontroller.isNullColliding() and 0 or vec2.div(mcontroller.velocity(), 60)), entity.id(), {0,0}, true, {
    damageKind = "hidden",
    universalDamage = false,
    onlyHitTerrain = true,
    timeToLive = 5/60,
    periodicActions = {{action = "loop", time = 0, ["repeat"] = false, count = count, body = actions}}
  })
end

starPounds.updateStats = function(force, dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Give the entity hitbox, bonus stats, and effects based on fatness.
  local size = starPounds.currentSize
  starPounds.statRefreshTimer = math.max((starPounds.statRefreshTimer or 0) - (dt or 0), 0)
  local timer = starPounds.statRefreshTimer
  if timer == 0 or oldWeightMultiplier ~= starPounds.weightMultiplier or force then
    -- Shouldn't activate at base size, so both indexes are reduced by one.
    local sizeIndex = starPounds.currentSizeIndex - 1
    local scalingSize = starPounds.settings.scalingSize - 1
    local applyImmunity = starPounds.currentSizeIndex >= starPounds.settings.activationSize
    local bonusEffectiveness = math.min(1, sizeIndex/scalingSize)
    local gritReduction = status.stat("activeMovementAbilities") <= 1 and -((starPounds.weightMultiplier - 1) * math.max(0, 1 - starPounds.getStat("knockbackResistance"))) or 0
    local persistentEffects = {
      {stat = "maxHealth", baseMultiplier = math.round(1 + size.healthBonus * starPounds.getStat("health"), 2)},
      {stat = "foodDelta", effectiveMultiplier = ((starPounds.stomach.food > 0) or starPounds.hasOption("disableHunger")) and 0 or math.round(starPounds.getStat("hunger"), 2)},
      {stat = "grit", amount = gritReduction},
      {stat = "shieldHealth", effectiveMultiplier = 1 + starPounds.getStat("shieldHealth") * bonusEffectiveness},
      {stat = "knockbackThreshold", effectiveMultiplier = 1 - gritReduction},
      {stat = "fallDamageMultiplier", effectiveMultiplier = 1 + size.healthBonus * (1 - starPounds.getStat("fallDamageResistance"))},
      {stat = "iceStatusImmunity", amount = applyImmunity and starPounds.getSkillLevel("iceImmunity") or 0},
      {stat = "poisonStatusImmunity", amount = applyImmunity and starPounds.getSkillLevel("poisonImmunity") or 0},
      {stat = "iceResistance", amount = starPounds.getStat("iceResistance") * bonusEffectiveness},
      {stat = "poisonResistance", amount = starPounds.getStat("poisonResistance") * bonusEffectiveness}
    }
    -- Probably not optimal, but don't apply effects if they do nothing.
    local filteredPersistentEffects = jarray()
    for i, effect in ipairs(persistentEffects) do
      local skip = (
        effect.baseMultiplier and effect.baseMultiplier == 1) or (
        effect.effectiveMultiplier and effect.effectiveMultiplier == 1) or (
        effect.amount and effect.amount == 0
      )
      if not skip then filteredPersistentEffects[#filteredPersistentEffects + 1] = effect end
    end
    status.setPersistentEffects("starpounds", filteredPersistentEffects)
    -- Only the timer resets itself.
    if (timer == 0) and dt then
      starPounds.statRefreshTimer = starPounds.settings.statRefreshTimer
    end
  end

  -- Check if the entity is using a morphball (Tech patch bumps this number for the morphball).
  if status.stat("activeMovementAbilities") > 1 then return end

  -- Disable blob on the tech missions so you can actually complete them.
  starPounds.blobDisabled = status.uniqueStatusEffectActive("starpoundstechmissionmobility") or starPounds.hasOption("disableBlob")

  if not baseParameters then baseParameters = mcontroller.baseParameters() end
  local parameters = baseParameters

  if timer == 0 or not (starPounds.controlModifiers and starPounds.controlParameters) or oldWeightMultiplier ~= starPounds.weightMultiplier or force then
    -- Movement stat starts at 0.
    -- Every +1 halves the penalty, every -1 doubles it (muliplicatively).
    local movement = starPounds.getStat("movement")
    if movement <= 0 then
      starPounds.movementModifier = (1 - size.movementPenalty) ^ (1 - starPounds.getStat("movement"))
    else
      starPounds.movementModifier = 1 - (size.movementPenalty / (2 ^ starPounds.getStat("movement")))
    end

    if size.movementPenalty >= 1 then
      starPounds.movementModifier = 0
      starPounds.jumpModifier = starPounds.settings.minimumJumpMultiplier
      starPounds.swimModifier = starPounds.settings.minimumSwimMultiplier
    else
      starPounds.jumpModifier = math.max(starPounds.settings.minimumJumpMultiplier, 1 - ((1 - starPounds.movementModifier) * starPounds.getStat("jumpPenalty")))
      starPounds.swimModifier = math.max(starPounds.settings.minimumSwimMultiplier, 1 - ((1 - starPounds.movementModifier) * starPounds.getStat("swimPenalty")))
    end

    local movementModifier = starPounds.movementModifier
    local weightMultiplier = starPounds.weightMultiplier

    starPounds.controlModifiers = weightMultiplier == 1 and {} or {
      groundMovementModifier = movementModifier,
      liquidMovementModifier = starPounds.swimModifier,
      speedModifier = movementModifier,
      airJumpModifier = starPounds.jumpModifier,
      liquidJumpModifier = starPounds.swimModifier
    }
    -- Silly, but better than updating modifiers every tick.
    starPounds.controlModifiersAlt = (movementModifier < starPounds.settings.minimumAltSpeedMultiplier) and sb.jsonMerge(starPounds.controlModifiers, {
      speedModifier = starPounds.settings.minimumAltSpeedMultiplier
    }) or nil
    starPounds.controlParameters = weightMultiplier == 1 and {} or {
      mass = parameters.mass * weightMultiplier,
      airForce = parameters.airForce * weightMultiplier,
      groundForce = parameters.groundForce * weightMultiplier,
      airFriction = parameters.airFriction * weightMultiplier,
      liquidBuoyancy = parameters.liquidBuoyancy + math.min((weightMultiplier - 1) * 0.01, 0.95),
      liquidForce = parameters.liquidForce * weightMultiplier,
      liquidFriction = parameters.liquidFriction * weightMultiplier,
      normalGroundFriction = parameters.normalGroundFriction * weightMultiplier,
      ambulatingGroundFriction = parameters.ambulatingGroundFriction * weightMultiplier,
      airJumpProfile = {jumpControlForce = parameters.airJumpProfile.jumpControlForce * weightMultiplier},
      liquidJumpProfile = {jumpControlForce = parameters.liquidJumpProfile.jumpControlForce * weightMultiplier}
    }
    -- Apply hitbox if we don't have the disable option checked, or we're a blob.
    if size.isBlob or not starPounds.hasOption("disableHitbox") then
      starPounds.controlParameters = sb.jsonMerge(starPounds.controlParameters, (size.controlParameters[starPounds.getVisualSpecies()] or size.controlParameters.default))
    end
  end
  mcontroller.controlModifiers((not starPounds.controlModifiersAlt or mcontroller.groundMovement()) and starPounds.controlModifiers or starPounds.controlModifiersAlt)
  mcontroller.controlParameters(starPounds.controlParameters)
end

starPounds.createStatuses = function()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't recreate if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  status[((storage.starPounds.pred or not status.resourcePositive("health")) and "set" or "clear").."PersistentEffects"]("starpoundseaten", {
    {stat = "statusImmunity", effectiveMultiplier = 0}
  })
  status[((storage.starPounds.pred or not status.resourcePositive("health")) and "add" or "remove").."EphemeralEffect"]("starpoundseaten")
end

starPounds.setOptionsMultipliers = function(options)
  storage.starPounds.optionMultipliers = {}
  for _, option in ipairs(options) do
    if option.statModifiers and starPounds.hasOption(option.name) then
      for _, statModifier in ipairs(option.statModifiers) do
        storage.starPounds.optionMultipliers[statModifier[1]] = (storage.starPounds.optionMultipliers[statModifier[1]] or 1) + statModifier[2]
      end
    end
  end
end

starPounds.getOptionsMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return storage.starPounds.optionMultipliers[stat] or 1
end

starPounds.setOptionsOverrides = function(options)
  storage.starPounds.optionOverrides = {}
  for _, option in ipairs(options) do
    if option.statOverrides and starPounds.hasOption(option.name) then
      for _, statOverride in ipairs(option.statOverrides) do
        storage.starPounds.optionOverrides[statOverride[1]] = statOverride[2]
      end
    end
  end
end

starPounds.getOptionsOverride = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return storage.starPounds.optionOverrides[stat] or nil
end

starPounds.hasOption = function(option)
  -- Argument sanitisation.
  option = tostring(option)
  return storage.starPounds.options[option]
end

starPounds.setOption = function(option, enable)
  -- Argument sanitisation.
  option = tostring(option)
  storage.starPounds.options[option] = enable and true or nil
  starPounds.optionChanged = true
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.options).__nils = {}
  starPounds.backup()
  return storage.starPounds.options[option]
end

starPounds.getStat = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  if not starPounds.stats[stat] then return 0 end
  -- Only recalculate per tick, otherwise use the cached value. (starPounds.statCache gets reset every tick)
  if not starPounds.statCache[stat] then
    -- Default amount (or 1, so we can boost stats that start at 0), modified by accessory values.
    local accessoryBonus = (starPounds.stats[stat].base ~= 0 and starPounds.stats[stat].base or 1) * starPounds.getAccessoryModifiers(stat)
    -- Base stat + Skill bonuses + Accessory bonuses.
    local statAmount = starPounds.stats[stat].base + starPounds.getSkillBonus(stat) + accessoryBonus
    -- Trait multiplier and effect multiplier.
    statAmount = statAmount * starPounds.getTraitMultiplier(stat) * starPounds.getEffectMultiplier(stat)
    -- Trait bonus and effect bonus
    statAmount = statAmount + starPounds.getTraitBonus(stat) + starPounds.getEffectBonus(stat)
    -- Override stat. (Used for legacy BF option)
    statAmount = starPounds.getOptionsOverride(stat) or statAmount
    -- Status effect multipliers and bonuses.
    statAmount = statAmount * starPounds.getStatusEffectMultiplier(stat) + starPounds.getStatusEffectBonus(stat)
    -- Option multipliers.
    statAmount = statAmount * starPounds.getOptionsMultiplier(stat)
    -- Cap the stat between 0 and it's maxValue.
    starPounds.statCache[stat] = math.max(math.min(statAmount, starPounds.stats[stat].maxValue or math.huge), starPounds.stats[stat].minValue or 0)
  end

  return starPounds.statCache[stat]
end

starPounds.getSkillUnlockedLevel = function(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][2] or 0, starPounds.skills[skill] and (starPounds.skills[skill].levels or 1) or 0)
end

starPounds.hasUnlockedSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  return (starPounds.getSkillUnlockedLevel(skill) >= level)
end

starPounds.getSkillLevel = function(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][1] or 0, starPounds.skills[skill] and (starPounds.skills[skill].levels or 1) or 0)
end

starPounds.hasSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  -- Legacy mode disables skills.
  return (starPounds.getSkillLevel(skill) >= level) and not starPounds.hasOption("legacyMode")
end

starPounds.upgradeSkill = function(skill, cost)
  -- Argument sanitisation.
  skill = tostring(skill)
  cost = tonumber(cost) or 0
  storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
  if starPounds.getSkillUnlockedLevel(skill) == starPounds.getSkillLevel(skill) then
    storage.starPounds.skills[skill][1] = math.min(starPounds.getSkillUnlockedLevel(skill) + 1, starPounds.skills[skill].levels or 1)
  end
  storage.starPounds.skills[skill][2] = math.min(starPounds.getSkillUnlockedLevel(skill) + 1, starPounds.skills[skill].levels or 1)

  local experienceConfig = starPounds.moduleFunc("experience", "config")
  local experienceProgress = storage.starPounds.experience/(experienceConfig.experienceAmount * (1 + storage.starPounds.level * experienceConfig.experienceIncrement))
  storage.starPounds.level = math.max(storage.starPounds.level - math.round(cost), 0)
  storage.starPounds.experience = math.round(experienceProgress * experienceConfig.experienceAmount * (1 + storage.starPounds.level * experienceConfig.experienceIncrement))
  starPounds.moduleFunc("experience", "add")
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.updateStats(true)
  starPounds.optionChanged = true
end

starPounds.forceUnlockSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- If we're forcing the skill, also increase the unlocked level (and initialise it).
  if starPounds.skills[skill] then
    storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
    storage.starPounds.skills[skill][1] = math.max(level, starPounds.getSkillLevel(skill))
    storage.starPounds.skills[skill][2] = math.max(level, starPounds.getSkillUnlockedLevel(skill))
  end
  starPounds.parseSkills()
  starPounds.parseStats()
  -- Update stats if we're already up and running.
  if starPounds.currentSize then
     starPounds.updateStats(true)
    starPounds.optionChanged = true
  end
end

starPounds.setSkill = function(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- Skip if there's no such skill.
  if not storage.starPounds.skills[skill] then return end
  if starPounds.getSkillUnlockedLevel(skill) > 0 then
    storage.starPounds.skills[skill][1] = math.max(math.min(level, starPounds.getSkillUnlockedLevel(skill)), 0)
  end
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.updateStats(true)
  starPounds.optionChanged = true
end

starPounds.parseStats = function()
  -- Skill stats
  storage.starPounds.stats = {}
  for skillName in pairs(storage.starPounds.skills) do
    local skill = starPounds.skills[skillName]
    if skill.type == "addStat" then
      storage.starPounds.stats[skill.stat] = (storage.starPounds.stats[skill.stat] or 0) + (skill.amount * starPounds.getSkillLevel(skillName))
    elseif skill.type == "subtractStat" then
      storage.starPounds.stats[skill.stat] = (storage.starPounds.stats[skill.stat] or 0) - (skill.amount * starPounds.getSkillLevel(skillName))
    end
    if storage.starPounds.stats[skill.stat] == 0 then
      storage.starPounds.stats[skill.stat] = nil
    end
  end

  -- Trait Stats
  storage.starPounds.traitStats = {}
  local selectedTrait = starPounds.traits[starPounds.getTrait() or "default"]
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, trait in ipairs({speciesTrait, selectedTrait}) do
    for _, stat in ipairs(trait.stats or jarray()) do
      storage.starPounds.traitStats[stat[1]] = storage.starPounds.traitStats[stat[1]] or {0, 1}
      if stat[2] == "add" then
        storage.starPounds.traitStats[stat[1]][1] = storage.starPounds.traitStats[stat[1]][1] + stat[3]
      elseif stat[2] == "sub" then
        storage.starPounds.traitStats[stat[1]][1] = storage.starPounds.traitStats[stat[1]][1] - stat[3]
      elseif stat[2] == "mult" then
        storage.starPounds.traitStats[stat[1]][2] = storage.starPounds.traitStats[stat[1]][2] * stat[3]
      end
    end
  end

  -- Effect stats
  starPounds.effectStats = {}
  for effectName, effectData in pairs(storage.starPounds.effects) do
    local effectConfig = starPounds.effects[effectName]
    if effectConfig then
      for _, stat in ipairs(effectConfig.stats or jarray()) do
        starPounds.effectStats[stat[1]] = starPounds.effectStats[stat[1]] or {0, 1}
        if stat[2] == "add" then
          starPounds.effectStats[stat[1]][1] = starPounds.effectStats[stat[1]][1] + stat[3] + (effectData.level - 1) * (stat[4] or 0)
        elseif stat[2] == "sub" then
          starPounds.effectStats[stat[1]][1] = starPounds.effectStats[stat[1]][1] - (stat[3] + (effectData.level - 1) * (stat[4] or 0))
        elseif stat[2] == "mult" then
          starPounds.effectStats[stat[1]][2] = starPounds.effectStats[stat[1]][2] * stat[3] + (effectData.level - 1) * (stat[4] or 0)
        end
      end
    end
  end

  starPounds.optionChanged = true
  starPounds.backup()
end

starPounds.parseSkills = function()
  for skill in pairs(storage.starPounds.skills) do
    -- Remove the skill if it doesn't exist.
    if not starPounds.skills[skill] then
      storage.starPounds.skills[skill] = nil
    else
      -- Cap skills at their maximum possible level.
      storage.starPounds.skills[skill][2] = math.min(starPounds.skills[skill].levels or 1, storage.starPounds.skills[skill][2])
      storage.starPounds.skills[skill][1] = math.min(storage.starPounds.skills[skill][1], storage.starPounds.skills[skill][2])
    end
  end
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.skills).__nils = {}
end

starPounds.getTrait = function()
  -- Reset the trait if it doesn't exist.
  local trait = storage.starPounds.trait
  -- Reset non-existent traits
  if trait and not starPounds.traits[trait] then
    starPounds.resetTrait()
    return
  end
  -- Remove a player's trait if they shouldn't be able to select it.
  if trait and starPounds.type == "player" then
    if not contains(starPounds.selectableTraits, trait) then
      starPounds.resetTrait()
      return
    end
  end
  return storage.starPounds.trait
end

starPounds.setTrait = function(trait)
  -- Argument sanitisation.
  trait = tostring(trait)
  -- Don't do anything if we already have a trait, or the trait doesn't exist.
  if storage.starPounds.trait or not starPounds.traits[trait] then return false end
  -- Set the trait.
  storage.starPounds.trait = starPounds.traits[trait].idOverride or trait
  local selectedTrait = starPounds.traits[trait]
  local mt = {__index = function (table, key) return starPounds.traits.default[key] end}
  setmetatable(selectedTrait, mt)
  -- Unlock trait skills.
  for _, skill in ipairs(selectedTrait.skills or jarray()) do
    starPounds.forceUnlockSkill(skill[1], skill[2])
  end
  -- Set trait starting values. Done a bit weirdly so it still applies when the mod is off.
  storage.starPounds.weight = math.max(storage.starPounds.weight, selectedTrait.weight)
  starPounds.setWeight(storage.starPounds.weight)
  -- Give trait milk
  storage.starPounds.breasts = math.max(storage.starPounds.breasts, selectedTrait.breasts)
  starPounds.moduleFunc("breasts", "setMilk", storage.starPounds.breasts)
  -- Give trait experience.
  storage.starPounds.level = storage.starPounds.level + selectedTrait.experience
  -- Give trait items to players.
  if starPounds.type == "player" then
    for _, item in ipairs(selectedTrait.items) do
      player.giveItem(item)
    end
  end
  -- Refresh stats.
  starPounds.parseStats()
  -- Set the trait successfully.
  return true
end

starPounds.resetTrait = function()
  storage.starPounds.trait = nil
  -- Refresh stats.
  starPounds.parseStats()
end

starPounds.effect = setmetatable({}, { __index = starPounds.module })
function starPounds.effect:new()
  -- Effects are effectively just timed modules.
  local newEffect = starPounds.module:new("effect")
  setmetatable(newEffect, { __index = self })
  return newEffect
end

function starPounds.effect:apply() end -- Runs whenever the effect gets applied, or reapplied.
function starPounds.effect:expire() end -- Runs whenever the effect times out, or gets removed.

starPounds.updateEffects = function(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  starPounds.effectTimer = math.max((starPounds.effectTimer or 0) - dt, 0)
  -- Update effect durations.
  if starPounds.effectTimer == 0 then
    for effectName, effect in pairs(storage.starPounds.effects) do
      local effectData = storage.starPounds.effects[effectName]
      if effectData.duration then
        effectData.duration = math.max(effectData.duration - starPounds.settings.effectTimer, 0)
        if effectData.duration == 0 then
          local effectConfig = starPounds.effects[effectName]
          if effectConfig.expirePerLevel and (effectData.level > 1) then
            effectData.level = effectData.level - 1
            effectData.duration = effectConfig.duration
            starPounds.parseStats()
          else
            starPounds.removeEffect(effectName)
          end
        end
      end
    end
    starPounds.effectTimer = starPounds.settings.effectTimer
  end
end

starPounds.loadScriptedEffect = function(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  local effectConfig = starPounds.effects[effect]
  if effectConfig then
    if effectConfig.script and not starPounds.scriptedEffects[effect] then
      require(effectConfig.script)
      _SBLOADED[effectConfig.script] = nil
      util.mergeTable(storage.starPounds.effects[effect], starPounds.scriptedEffects[effect].data)
      starPounds.scriptedEffects[effect].data = storage.starPounds.effects[effect]
      starPounds.scriptedEffects[effect]:moduleInit()
      starPounds.modules[string.format("effect_%s", effect)] = starPounds.scriptedEffects[effect]
      starPounds.modules[string.format("effect_%s", effect)]:setUpdateDelta(effectConfig.scriptDelta or 1)
    end
  end
end

starPounds.effectInit = function()
  starPounds.scriptedEffects = {}
  for effect in pairs(storage.starPounds.effects) do
    starPounds.loadScriptedEffect(effect)
  end
end

starPounds.addEffect = function(effect, duration)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  local effectConfig = starPounds.effects[effect]
  local effectData = storage.starPounds.effects[effect] or {}
  if effectConfig then
    duration = tonumber(duration) or effectConfig.duration
    -- Negative durations become infinite.
    if duration < 0 then duration = nil end
    if effectConfig.particle then
      local spec = starPounds.settings.particleTemplates.effect
      world.spawnProjectile("invisibleprojectile", vec2.add(mcontroller.position(), mcontroller.isNullColliding() and 0 or vec2.div(mcontroller.velocity(), 60)), entity.id(), {0,0}, true, {
        damageKind = "hidden",
        universalDamage = false,
        onlyHitTerrain = true,
        timeToLive = 5/60,
        periodicActions = {
          { action = "loop", time = 0, ["repeat"] = false, count = 5, body = {
            { action = "particle", specification = spec },
            { action = "particle", specification = sb.jsonMerge(spec, {layer = "front"}) }
          }}
        }
      })
      starPounds.moduleFunc("sound", "play", "digest", 0.5, (math.random(120,150)/100))
    end
    effectData.duration = duration and math.max(effectData.duration or 0, duration) or nil
    effectData.level = math.min((effectData.level or 0) + 1, effectConfig.levels or 1)
    storage.starPounds.effects[effect] = effectData
    if not effectConfig.hidden then
      storage.starPounds.discoveredEffects[effect] = true
    end
    -- Scripted effects.
    if effectConfig.script then
      starPounds.loadScriptedEffect(effect)
      starPounds.scriptedEffects[effect]:apply()
    end

    starPounds.parseStats()
    return true
  end
  return false
end

starPounds.removeEffect = function(effect)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  if storage.starPounds.effects[effect] then
    storage.starPounds.effects[effect] = nil
    starPounds.parseStats()
    if starPounds.scriptedEffects[effect] then
      starPounds.scriptedEffects[effect]:expire()
      starPounds.scriptedEffects[effect] = nil
      starPounds.modules[string.format("effect_%s", effect)] = nil
    end
    return true
  end
  return false
end

starPounds.getEffect = function(effect)
  -- Return empty if the mod is disabled.
  --if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.effects[effect]
end

starPounds.hasDiscoveredEffect = function(effect)
  -- Argument sanitisation.
  effect = tostring(effect)
  return storage.starPounds.discoveredEffects[effect] ~= nil
end

starPounds.resetEffects = function()
  storage.starPounds.effects = {}
  storage.starPounds.discoveredEffects = {}
  starPounds.parseStats()
end

starPounds.getSkillBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (storage.starPounds.stats[stat] or 0)
end

starPounds.getTraitMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (storage.starPounds.traitStats[stat] or {0, 1})[2]
end

starPounds.getTraitBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (storage.starPounds.traitStats[stat] or {0, 1})[1]
end

starPounds.getEffectMultiplier = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.effectStats[stat] or {0, 1})[2]
end

starPounds.getEffectBonus = function(stat)
  -- Argument sanitisation.
  stat = tostring(stat)
  return (starPounds.effectStats[stat] or {0, 1})[1]
end

starPounds.getStatusEffectMultiplier = function(stat)
  return 1
end

starPounds.getStatusEffectBonus = function(stat)
  return 0
end

starPounds.getAccessory = function()
  if storage.starPounds.accessory then
    return root.createItem(storage.starPounds.accessory)
  end
end

starPounds.getAccessoryModifiers = function(stat)
  -- Argument sanitisation.
  stat = stat and tostring(stat) or nil
  if not stat then
    local accessoryModifiers = {}
    local accessory = starPounds.getAccessory()
    if accessory then
      for _, stat in pairs(configParameter(accessory, "stats", {})) do
        if starPounds.stats[stat.name] then
          accessoryModifiers[stat.name] = math.round((accessoryModifiers[stat.name] or 0) + stat.modifier, 3)
        end
      end
    end
    return accessoryModifiers
  else
    return starPounds.accessoryModifiers[stat] or 0
  end
end

starPounds.setAccessory = function(item)
  -- Argument sanitisation.
  if item and type(item) ~= "table" then
    item = tostring(item)
  end
  storage.starPounds.accessory = item and root.createItem(item) or nil
  starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
  starPounds.statCacheTimer = 0 -- Force a cache update to immediately apply the bonuses.
  starPounds.optionChanged = true
  starPounds.backup()
end

starPounds.getSize = function(weight)
  -- Default to base size if the mod is off.
  if not storage.starPounds.enabled then
    return starPounds.sizes[1], 1
  end
  -- Argument sanitisation.
  weight = math.max(tonumber(weight) or 0, 0)

  local sizeIndex = 0
  -- Go through all starPounds.sizes (smallest to largest) to find which size.
  for i in ipairs(starPounds.sizes) do
    local isBlob = starPounds.sizes[i].isBlob
    local blobDisabled = starPounds.hasOption("disableBlob") or starPounds.blobDisabled
    local skipSize = isBlob and blobDisabled
    if weight >= starPounds.sizes[i].weight and not skipSize then
      sizeIndex = i
    end
  end

  -- If we have the anti-immobile skill, use the regular blob clothing and an increased movement penalty.
  local isImmobile = starPounds.sizes[sizeIndex].movementPenalty == 1
  local immobileDisabled = blobDisabled or starPounds.hasSkill("preventImmobile")
  if isImmobile and immobileDisabled then
    local oldMovementPenalty = starPounds.sizes[sizeIndex - 1].movementPenalty
    local newMovementPenalty = oldMovementPenalty + 0.5 * (1 - oldMovementPenalty)
    local newSize = sb.jsonMerge(starPounds.sizes[sizeIndex], {
      movementPenalty = newMovementPenalty
    })
    return newSize, sizeIndex
  end

  return starPounds.sizes[sizeIndex], sizeIndex
end

starPounds.getChestVariant = function(size)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  local size = type(size) == "table" and size or {}
  local variants = size.variants or jarray()
  local variant = nil
  local thresholdMultiplier = starPounds.currentSize.thresholdMultiplier
  local breastThresholds = starPounds.settings.thresholds.breasts
  local stomachThresholds = starPounds.settings.thresholds.stomach

  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0)) + (
    starPounds.hasOption("busty") and breastThresholds[1].amount * thresholdMultiplier or (
    starPounds.hasOption("milky") and breastThresholds[2].amount * thresholdMultiplier or 0)
  )

  local stomachSize = (starPounds.hasOption("disableStomachGrowth") and 0 or (starPounds.moduleFunc("stomach", "get").interpolatedContents or 0)) + (
    starPounds.hasOption("stuffed") and stomachThresholds[2].amount * thresholdMultiplier or (
    starPounds.hasOption("filled") and stomachThresholds[4].amount * thresholdMultiplier or (
    starPounds.hasOption("gorged") and stomachThresholds[6].amount * thresholdMultiplier or 0))
  )

  for _, v in ipairs(breastThresholds) do
    if contains(variants, v.name) then
      if breastSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  for _, v in ipairs(stomachThresholds) do
    if contains(variants, v.name) then
      if stomachSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  if starPounds.hasOption("hyper") then
    variant = "hyper"
  end

  return variant
end

-- world.entitySpecies can be unreliable on the first tick.
starPounds.getSpecies = function()
  if storage.starPounds.overrideSpecies then return storage.starPounds.overrideSpecies end
  if starPounds.type == "player" then return player.species() end
  if starPounds.type == "npc" then return npc.species() end
  return world.entitySpecies(entity.id())
end

starPounds.getVisualSpecies = function(species)
  -- Get entity species.
  local species = species and tostring(species) or starPounds.getSpecies()
  return starPounds.species[species] and (starPounds.species[species].override or species) or species
end

starPounds.getSpeciesData = function(species)
  -- Get merged species data.
  local species = species and tostring(species) or starPounds.getSpecies()
  return sb.jsonMerge(starPounds.species.default, starPounds.species[species] or {})
end

starPounds.getDirectives = function(target)
  -- Argument sanitisation.
  local target = tonumber(target) or entity.id()
  local directives = ""
  -- Get entity species.
  local species = (target ~= entity.id()) and world.entitySpecies(target) or starPounds.getSpecies()
  local speciesData = starPounds.getSpeciesData(species)
  -- Generate a nude portrait.
  for _,v in ipairs(world.entityPortrait(target, "fullnude")) do
    -- Find the player's body sprite.
    if string.find(v.image, "body.png") then
      -- Seperate the body sprite's image directives.
      directives = string.sub(v.image,(string.find(v.image, "?")))
      break
    end
  end
  -- Add append directives, if any. (i.e. novakids have this white patch that doesn't change with default species colours, adding ffffff=ffffff means it gets picked up by the fullbright block)
  if speciesData.appendDirectives then
    directives = string.format("%s;%s", directives, speciesData.appendDirectives):gsub(";;", ";")
  end
  -- If the species is fullbright (i.e. novakids), append 'fe' to hexcodes to make them fullbright. (99%+ opacity)
  if speciesData.fullbright then
    directives = (directives..";"):gsub("(%x)(%?)", function(a) return a..";?" end):gsub(";;", ";"):gsub("(%x+=%x%x%x%x%x%x);", function(colour)
      return string.format("%sfe;", colour)
    end)
  end
  -- Slip in override directives, if any. This is after the fullbright block since this is usually used for mimicking species palettes.
  if speciesData.prependDirectives then
    directives = string.format("%s;%s", speciesData.prependDirectives, directives):gsub(";;", ";")
  end
  return directives
end

starPounds.equipSize = function(size, modifiers)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Get entity species.
  local species = starPounds.getVisualSpecies()
  -- Get entity directives
  local directives = starPounds.getDirectives()
  -- Setup base parameters for item.
  local visualSize = size.size
  if starPounds.hasSkill("preventImmobile") and visualSize == "immobile" then
    visualSize = "blob"
  end
  local items = {
    legs = {name = (modifiers.legsSize or visualSize)..species:lower().."legs", count=1},
    chest = {name = (modifiers.chestSize or visualSize)..(modifiers.chestVariant or "")..species:lower().."chest", count=1}
  }

  -- Give the items parameters to track/prevent dupes.
  items.legs.parameters = {directives = directives, price = 0, size = (modifiers.legsSize or size.size), rarity = "essential"}
  items.chest.parameters = {directives = directives, price = 0, size = (modifiers.chestSize or size.size), variant = modifiers.chestVariant, rarity = "essential"}
  -- Base size doesn't have any items.
  if (modifiers.legsSize or size.size) == "" then items.legs = nil end
  if (modifiers.chestSize or size.size) == "" and (modifiers.chestVariant or "") == "" then items.chest = nil end
  -- Grab current worn clothing.
  local currentItems = {
    legs = player.equippedItem("legsCosmetic"),
    chest = player.equippedItem("chestCosmetic")
  }
  -- Shorthand instead of 2 blocks.
  for _, itemType in ipairs({"legs", "chest"}) do
    currentItem = currentItems[itemType]
    -- If the item isn't a generated item, give it back.
    if currentItems[itemType] and not currentItems[itemType].parameters.size and not currentItems[itemType].parameters.tempSize == size.size then
      player.giveItem(currentItems[itemType])
    end
    -- Replace the item if it isn't generated.
    if not (currentItem and currentItems[itemType].parameters.tempSize) then
      player.setEquippedItem(itemType.."Cosmetic", items[itemType])
    end
  end
end

starPounds.equipCheck = function(size)
  -- Cap size in certain vehicles to prevent clipping.
  local leftCappedVehicle = false
  local modifiers = {}
  if mcontroller.anchorState() then
    local anchorEntity = world.entityName(mcontroller.anchorState())
    if anchorEntity and starPounds.settings.vehicleSizeCap[anchorEntity] then
      if starPounds.currentSizeIndex > starPounds.settings.vehicleSizeCap[anchorEntity] then
        modifiers.chestVariant = "busty"
        modifiers.legsSize = nil
        modifiers.chestSize = nil
        modifiers.override = true
        size = starPounds.sizes[starPounds.settings.vehicleSizeCap[anchorEntity]]
        inCappedVehicle = true
      end
    end
  else
    if inCappedVehicle then
      leftCappedVehicle = true
      inCappedVehicle = false
    end
  end
  -- Skip if no changes.
  if
    size.size == (oldSize and oldSize.size or nil) and
    starPounds.currentVariant == oldVariant and
    not leftCappedVehicle and
    not (starPounds.swapSlotItem ~= nil and starPounds.swapSlotItem.parameters ~= nil and (starPounds.swapSlotItem.parameters.size ~= nil or starPounds.swapSlotItem.parameters.tempSize ~= nil)) and
    not starPounds.optionChanged
  then return end
  -- Setup modifiers.
  if not modifiers.override then
    modifiers = {
      chestVariant = starPounds.currentVariant,
      chestSize = storage.starPounds.enabled and (starPounds.hasOption("extraTopHeavy") and 2 or (starPounds.hasOption("topHeavy") and 1 or nil) or nil),
      legsSize = storage.starPounds.enabled and (starPounds.hasOption("extraBottomHeavy") and 2 or (starPounds.hasOption("bottomHeavy") and 1 or nil) or nil)
    }
  end
  -- Check the item the player is holding.
  if starPounds.swapSlotItem and starPounds.swapSlotItem.parameters then
    local item = starPounds.swapSlotItem
    -- If it's a base one then bye bye item.
    if starPounds.swapSlotItem.parameters.size then
      player.setSwapSlotItem(nil)
    -- If it's a clothing one then reset it to the normal item in their cursor.
    elseif item.parameters.tempSize and item.parameters.baseName then
      -- Restore the original item
      item = {
        name = item.parameters.baseName,
        parameters = item.parameters,
        count = item.count
      }
      item.parameters.tempSize = nil
      item.parameters.baseName = nil
      player.setSwapSlotItem(item)
    end
  end

  modifierSize = nil
  -- Get the entity size, and what index it is in the config.
  sizeIndex = starPounds.currentSizeIndex
  -- Check if there's a leg size modifier, and if it exists.
  if modifiers.legsSize then
    for i = 1, modifiers.legsSize do
      if starPounds.sizes[sizeIndex + i] and not starPounds.sizes[sizeIndex + i].isBlob then
         modifiers.legsSize = starPounds.sizes[sizeIndex + i].size
      end
    end
    if type(modifiers.legsSize) == "number" then modifiers.legsSize = nil end
  end
  -- Check if there's a chest size modifier, and if it exists.
  if modifiers.chestSize then
    for i = 1, modifiers.chestSize do
      if starPounds.sizes[sizeIndex + i] and not starPounds.sizes[sizeIndex + i].isBlob then
         modifiers.chestSize = starPounds.sizes[sizeIndex + i].size
         modifierSize = starPounds.sizes[sizeIndex + i]
      end
    end
    if type(modifiers.chestSize) == "number" then modifiers.chestSize = nil end
  end
  -- Check if there's a chest variant, and if it exists.
  if modifiers.chestVariant then
    modifiers.chestVariant = contains(starPounds.sizes[sizeIndex].variants, modifiers.chestVariant) and modifiers.chestVariant or nil
  end

  -- Iterate over worn clothing.
  local doEquip = false
  local returnedItems = false
  for _, itemType in ipairs({"legs", "chest"}) do
    local currentItem = player.equippedItem(itemType.."Cosmetic")
    local currentSize = modifiers[itemType.."Size"] or size.size
    -- Check if the entity is wearing something, if it's not a base item, and if it's generated but the size is wrong.
    if currentItem and not currentItem.parameters.size and currentItem.parameters.tempSize ~= currentSize then
      -- Attempt to find the item for the current size.
      if pcall(root.itemType, currentSize..(currentItem.parameters.baseName or currentItem.name)) then
        -- If found, give the new item some parameters for easier checking.
        currentItem.parameters.baseName = (currentItem.parameters.baseName or currentItem.name)
        currentItem.parameters.tempSize = currentSize
        currentItem.name = currentSize..(currentItem.parameters.baseName or currentItem.name)
        player.setEquippedItem(itemType.."Cosmetic", currentItem)
      else
        -- Reset and give the item back/remove it from the slot if an updated one couldn't be found.
        currentItem.name = currentItem.parameters.baseName or currentItem.name
        currentItem.parameters.tempSize = nil
        currentItem.parameters.baseName = nil
        player.giveItem(currentItem)
        player.setEquippedItem(itemType.."Cosmetic", nil)
        currentItem = nil

        if not returnedItems then
          starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
          returnedItems = true
        end
      end
    end
    -- If the entity isn't wearing an item, or the item they are wearing has the wrong size/variant.
    if currentSize ~= "" or (
      not currentItem or
      currentItem.parameters.size == currentSize and currentItem.parameters.variant == modifiers[itemType.."Variant"] or
      currentItem.parameters.tempSize == currentSize or
      starPounds.currentSizeIndex == 1 and not currentItem.parameters.size
    )
    then
      player.consumeItemWithParameter("size", currentSize, 2)
      doEquip = true
    end
    for _, removedSize in ipairs(starPounds.sizes) do
      if removedSize ~= size then
        -- Delete all base items.
        player.consumeItemWithParameter("size", removedSize.size, 2)
      end
    end
  end
  if doEquip then
    starPounds.equipSize(size, modifiers)
  end
end

starPounds.feed = function(amount, foodType)
  -- Runs eat, but adapts for player food.
  -- Use this rather than eat() unless we don't care about the hunger bar for some reason.

  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  if not storage.starPounds.enabled then
    if status.isResource("food") then
      status.giveResource("food", amount)
    end
  else
    starPounds.eat(amount, foodType)
  end
end

starPounds.eat = function(amount, foodType)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  foodType = foodType and tostring(foodType) or "default"
  if not starPounds.foods[foodType] then foodType = "default" end
  -- Don't do anything if there's no food.
  if amount == 0 then return end
  -- Food type capacity cap.
  local maxCapacity = math.huge
  if starPounds.foods[foodType].maxCapacity then
    maxCapacity = starPounds.stomach.capacity * (starPounds.foods[foodType].maxCapacity / starPounds.foods[foodType].multipliers.capacity)
  end
  -- Stats that affect the amount gained.
  if starPounds.foods[foodType].amountStats then
    for _, stat in pairs(starPounds.foods[foodType].amountStats) do
      amount = math.max(amount * starPounds.getStat(stat), 0)
    end
  end
  -- Insert food into stomach.
  amount = math.round(amount, 3)
  storage.starPounds.stomachContents[foodType] = math.min((storage.starPounds.stomachContents[foodType] or 0) + amount, maxCapacity)
end

starPounds.gainWeight = function(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if weight gain is disabled.
  if starPounds.hasOption("disableGain") then return end
  -- Increase weight by amount.
  amount = math.min(amount * (fullAmount and 1 or starPounds.getStat("weightGain")), starPounds.settings.maxWeight - storage.starPounds.weight)
  starPounds.setWeight(storage.starPounds.weight + amount)
  return amount
end

starPounds.loseWeight = function(amount, fullAmount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return 0 end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Don't do anything if weight loss is disabled.
  if starPounds.hasOption("disableLoss") then return end
  -- Decrease weight by amount (min: 0)
  amount = math.min(amount * (fullAmount and 1 or starPounds.getStat("weightLoss")), storage.starPounds.weight)
  starPounds.setWeight(storage.starPounds.weight - amount)
  return amount
end

starPounds.setWeight = function(amount)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  amount = math.max(tonumber(amount) or 0, 0)
  -- Set weight, rounded to 4 decimals.
  amount = math.round(amount, 4)
  storage.starPounds.weight = math.max(math.min(amount, starPounds.settings.maxWeight), starPounds.sizes[(starPounds.getSkillLevel("minimumSize") + 1)].weight)
end

starPounds.voreCheck = function()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if there's no eaten entities.
  if storage.starPounds.stomachEntities == 0 then return end
  -- table.remove is doodoo poop water.
  local newStomach = jarray()
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if world.entityExists(prey.id) then
      table.insert(newStomach, prey)
    elseif (starPounds.type == "player") and (prey.world == player.worldId()) then
      starPounds.digestEntity(prey.id)
    end
  end
  storage.starPounds.stomachEntities = newStomach
end

starPounds.eatNearbyEntity = function(position, range, querySize, options, check)
  -- Argument sanitisation.
  position = (type(position) == "table" and type(position[1]) == "number" and type(position[2]) == "number") and position or mcontroller.position()
  range = math.max(tonumber(range) or 0, 0)
  querySize = math.max(tonumber(querySize) or 0, 0)
  options = type(options) == "table" and options or {}

  local mouthPosition = starPounds.mouthPosition()
  if starPounds.currentSize.yOffset then
    mouthPosition[2] = mouthPosition[2] + starPounds.currentSize.yOffset
  end

  local preferredEntities = position and world.entityQuery(position, querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()}) or jarray()
  local nearbyEntities = world.entityQuery(mouthPosition, range, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()})
  local eatenTargets = jarray()

  for _, prey in ipairs(storage.starPounds.stomachEntities) do
    eatenTargets[prey.id] = true
  end

  local function isTargetValid(target)
    return not eatenTargets[target] and not world.lineTileCollision(mouthPosition, world.entityPosition(target), {"Null", "Block", "Dynamic", "Slippery"})
  end

  for _, target in ipairs(preferredEntities) do
    if isTargetValid(target) then
      return {starPounds.eatEntity(target, options, check), true}
    end
  end

  for _, target in ipairs(nearbyEntities) do
    if isTargetValid(target) then
      return {starPounds.eatEntity(target, options, check), false}
    end
  end
end

starPounds.eatEntity = function(preyId, options, check)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return false end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return false end
  options = type(options) == "table" and options or {}
  -- Legacy mode doesn't require the skill.
  options.ignoreSkills = options.ignoreSkills or starPounds.hasOption("legacyMode")
  -- Check if they exist.
  if not world.entityExists(preyId) then return false end
  -- Counting this as 'combat', so no eating stuff on protected worlds. (e.g. the outpost)
  if world.getProperty("nonCombat") and not options.ignoreProtection then return false end
  -- Don't do anything if pred is disabled.
  if starPounds.hasOption("disablePred") then return false end
  -- Need the upgrades for parts of the skill to work.
  local canVoreCritter = starPounds.hasSkill("voreCritter")
  local canVoreMonster = starPounds.hasSkill("voreMonster")
  local canVoreHumanoid = starPounds.hasSkill("voreHumanoid")
  local canVoreFriendly = options.ignoreSkills or starPounds.hasSkill("voreFriendly")
  -- Skip if we can't eat anything at all.
  if not (
    canVoreCritter or
    canVoreMonster or
    canVoreHumanoid or
    options.ignoreSkills
  ) then return false end
  -- Store so we don't have to grab multiple times.
  local preyType = world.entityTypeName(preyId)
  -- Can't eat friendlies without the skill.
  if not canVoreFriendly and not world.entityCanDamage(entity.id(), preyId) then return false end
  -- Don't do anything if eaten.
  if storage.starPounds.pred then return false end
  -- Can only eat if you're below capacity.
  if starPounds.stomach.fullness >= starPounds.settings.thresholds.strain.starpoundsstomach and not starPounds.hasSkill("wellfedProtection") and not options.ignoreCapacity then
    return false
  elseif starPounds.stomach.fullness >= starPounds.settings.thresholds.strain.starpoundsstomach3 and not options.ignoreCapacity then
    return false
  end
  -- Don't do anything if they're already eaten.
  if starPounds.ateEntity(preyId) then return false end
  -- Don't do anything if they're not a compatible entity.
  local compatibleEntities = jarray()
  if canVoreCritter or canVoreMonster then
    table.insert(compatibleEntities, "monster")
  end
  if canVoreHumanoid then
    table.insert(compatibleEntities, "npc")
    table.insert(compatibleEntities, "player")
  end
  local preyType = world.entityTypeName(preyId)
  if not options.ignoreEnergyRequirement and status.isResource("energy") and status.resourceLocked("energy") then return false end
  if not options.ignoreSkills then
    if not contains(compatibleEntities, world.entityType(preyId)) then return false end
    -- Need the upgrades for the specific entity type
    if world.entityType(preyId) == "monster" then
      local scriptCheck = contains(root.monsterParameters(preyType).scripts or jarray(), "/scripts/starpounds/starpounds_monster.lua")
      if scriptCheck then
        if (not canVoreMonster) and (not preyType:find("critter")) then return false end
        if (not canVoreCritter) and preyType:find("critter") then return false end
      else
        local behavior = root.monsterParameters(preyType).behavior
        if contains(starPounds.settings.critterBehaviors, behavior) and not canVoreCritter then return false end
        if contains(starPounds.settings.monsterBehaviors, behavior) and not canVoreMonster then return false end
      end
    end
  end

  -- Skip the rest if the monster/npc can't be eaten to begin with.
  local isCritter = false
  if world.entityType(preyId) == "monster" then
    local scriptCheck = contains(root.monsterParameters(preyType).scripts or jarray(), "/scripts/starpounds/starpounds_monster.lua")
    local parameters = root.monsterParameters(preyType)
    isCritter = contains(starPounds.settings.critterBehaviors, parameters.behavior)
    local isMonster = contains(starPounds.settings.monsterBehaviors, parameters.behavior)
    local behaviorCheck = parameters.behavior and (isCritter or isMonster) or false
    if parameters.starPounds_options and parameters.starPounds_options.disablePrey then return false end
    if not (scriptCheck or behaviorCheck) then
      return false
    end
  end

  if world.entityType(preyId) == "npc" then
    if not contains(root.npcConfig(preyType).scripts or jarray(), "/scripts/starpounds/starpounds_npc.lua") then return false end
    if world.getNpcScriptParameter(preyId, "starPounds_options", jarray()).disablePrey then return false end
    if starPounds.type == "player" and starPounds.hasOption("disableCrewVore") and world.getNpcScriptParameter(preyId, "ownerUuid") ~= entity.uniqueId() then return false end
  end

  if world.entityDamageTeam(preyId).type == "ghostly" then return false end
  -- Skip eating if we're only checking for a valid target.
  if check then return true end
  -- Ask the entity to be eaten, add to stomach if the promise is successful.
  promises:add(world.sendEntityMessage(preyId, "starPounds.getEaten", entity.id()), function(prey)
    if not (prey and (prey.base or prey.weight)) then return end
    table.insert(storage.starPounds.stomachEntities, {
      id = preyId,
      base = prey.base or 0,
      weight = prey.weight or 0,
      foodType = prey.foodType or "prey",
      experience = prey.experience or 0,
      world = (starPounds.type == "player") and player.worldId() or nil,
      noRelease = prey.noRelease or options.noRelease,
      noBelch = prey.noBelch or options.noBelch,
      type = world.entityType(preyId):gsub(".+", {player = "humanoid", npc = "humanoid", monster = "creature"}),
      typeName = world.entityTypeName(preyId)
    })
    local energyMult = options.energyMultiplier or 1
    if energyMult > 0 then
      local preyHealth = world.entityHealth(preyId)
      local preyHealthPercent = preyHealth[1]/preyHealth[2]
      local preySizeMult = (1 + (((prey.base or 0) + (prey.weight or 0))/starPounds.species.default.weight)) * 0.5
      if isCritter then
        preySizeMult = preySizeMult * starPounds.settings.voreCritterEnergyMultiplier
      end
      local energyCost = (options.energyMultiplier or 1) * (starPounds.settings.voreEnergyBase + starPounds.settings.voreEnergy * preyHealthPercent * preySizeMult)
      status.overConsumeResource("energy", energyCost)
    end
    -- Swallow sound
    if not (options.noSound or options.noSwallowSound) then
      starPounds.moduleFunc("sound", "play", "swallow", 1 + math.random(0, 10)/100, 1)
    end
    -- Stomach sound
    if not (options.noSound or options.noDigestSound) then
      starPounds.moduleFunc("sound", "play", "digest", 1, 0.75)
    end
  end)
  return true
end

starPounds.ateEntity = function(preyId)
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return false end
  for _, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then return true end
  end
  return false
end

starPounds.digestClothing = function(item)
  -- Argument sanitisation.
  if not (item and type(item) == "table") then return end
  item = root.createItem(item)
  -- Make sure this exists to start with.
  item.parameters = item.parameters or {}
  -- First time digesting the item.
  if not item.parameters.baseParameters then
    local baseParameters = {}
    for k, v in pairs(item.parameters) do
      baseParameters[k] = v
    end
    item.parameters.baseParameters = baseParameters
  end
  item.parameters.digestCount = item.parameters.digestCount and math.min(item.parameters.digestCount + 1, 3) or 1
  -- Reset values before editing.
  item.parameters.category = item.parameters.baseParameters.category
  item.parameters.price = item.parameters.baseParameters.price
  item.parameters.level = item.parameters.baseParameters.level
  item.parameters.directives = item.parameters.baseParameters.directives
  item.parameters.colorIndex = item.parameters.baseParameters.colorIndex
  item.parameters.colorOptions = item.parameters.baseParameters.colorOptions
  -- Add visual flair and reduce rarity down to common.
  local label = root.assetJson("/items/categories.config:labels")[configParameter(item, "category", ""):gsub("enviroProtectionPack", "backwear")]
  item.parameters.category = string.format("%sDigested %s%s", starPounds.hasOption("disableRegurgitatedClothingTint") and "" or "^#a6ba5d;", label, ((item.parameters.digestCount > 1) and string.format(" (x%s)", item.parameters.digestCount) or ""))
  item.parameters.rarity = configParameter(item, "rarity", "common"):lower():gsub(".+", { uncommon = "common", rare = "uncommon", legendary = "rare" })
  -- Reduce price to 10% (15% - 5% per digestion) of the original value.
  item.parameters.price = math.round(configParameter(item, "price", 0) * (0.15 - 0.05 * item.parameters.digestCount))
  -- Reduce armor level by 1 per digestion. (Or planet threat level, whatever is lower)
  item.parameters.level = math.max(math.min(configParameter(item, "level", 0) - item.parameters.digestCount, world.threatLevel()), configParameter(item, "level", 0) > 0 and 1 or 0)
  -- Disable status effects.
  item.parameters.statusEffects = root.itemConfig(item).statusEffects and jarray() or nil
  -- Disable effects.
  item.parameters.effectSources = root.itemConfig(item).effectSources and jarray() or nil
  -- Disable augments.
  if configParameter(item, "acceptsAugmentType") then
    item.parameters.acceptsAugmentType = ""
  end
  if configParameter(item, "tooltipKind") == "baseaugment" then
    item.parameters.tooltipKind = "back"
  end
  if starPounds.hasOption("disableRegurgitatedClothingTint") then return item end
  -- Give the armor some colour changes to make it look digested.
  item.parameters.colorOptions = configParameter(item, "colorOptions", {})
  item.parameters.colorIndex = configParameter(item, "colorIndex", 0) % (#item.parameters.colorOptions > 0 and #item.parameters.colorOptions or math.huge)
  -- Convert colorOptions and colorIndex to directives.
  if not configParameter(item, "directives") and item.parameters.colorOptions and #item.parameters.colorOptions > 0 then
    item.parameters.directives = "?replace;"
    for fromColour, toColour in pairs(item.parameters.colorOptions[item.parameters.colorIndex + 1]) do
      item.parameters.directives = string.format("%s%s=%s;", item.parameters.directives, fromColour, toColour)
    end
  end
  item.parameters.directives = configParameter(item, "directives", "")..string.rep("?brightness=-20?multiply=e9ffa6?saturation=-20", item.parameters.digestCount)
  item.parameters.colorIndex = nil
  item.parameters.colorOptions = jarray()
  return item
end

starPounds.digestEntity = function(preyId, items, preyStomach)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  if not preyId then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePredDigestion") then return end
  -- Find the entity's entry in the stomach.
  local digestedEntity = nil
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then
      digestedEntity = table.remove(storage.starPounds.stomachEntities, preyIndex)
      break
    end
  end
  -- Don't do anything if we didn't digest an entity.
  if not digestedEntity then return end
  -- Transfer eaten entities.
  storage.starPounds.stomachEntities = util.mergeLists(storage.starPounds.stomachEntities, preyStomach or jarray())
  for _, prey in ipairs(preyStomach or jarray()) do
    world.sendEntityMessage(prey.id, "starPounds.predEaten", entity.id())
  end
  local mouthPosition = starPounds.mouthPosition()
  -- Iterate over and edit the items.
  local regurgitatedItems = jarray()
  -- We get purple particles if we digest something that gives ancient essence.
  local hasEssence = false
  for _, item in pairs(items or jarray()) do
    local itemType = root.itemType(item.name)
    if string.find(root.itemType(item.name), "armor") then itemType = "clothing" end

    if itemType == "clothing" then
      if math.random() < starPounds.getStat("regurgitateClothingChance") then
        -- Give them item digested effects
        item = starPounds.digestClothing(item)
        -- Spawn the item, but double check if it's still clothing (in case of pgis)
        if (root.itemType(item.name) == "clothing") or string.find(root.itemType(item.name), "armor") then
          table.insert(regurgitatedItems, item)
        end
      -- Second chance to regurgitate 'scrap' items instead.
      elseif math.random() < starPounds.getStat("regurgitateChance") then
        -- Default to clothing drops.
        local armorType = "Clothing"
        -- Check if it's a tier 5/6 armor, since the classes have different components.
        if configParameter(item, "level", 0) >= 5 then
          for _, recipe in ipairs(root.recipesForItem(item.name)) do
            if contains(recipe.groups, "craftingaccelerator") then armorType = "Accelerator" break
            elseif contains(recipe.groups, "craftingmanipulator") then armorType = "Manipulator" break
            elseif contains(recipe.groups, "craftingseparator") then armorType = "Separator" break
            end
          end
        end
        -- Add drops to the pool.
        for _, item in ipairs(root.createTreasure("regurgitated"..armorType, configParameter(item, "level", 0))) do
          table.insert(regurgitatedItems, item)
        end
      end
    elseif item.name == "essence" then
      if starPounds.type == "player" then player.giveItem(item) end
      hasEssence = true
    end
  end
  local doBelch = not (starPounds.hasOption("disableBelches") or starPounds.hasOption("disablePredBelches") or digestedEntity.noBelch)
  -- No belching up items if belching (or their particles) is disabled on the pred or prey side.
  local doBelchParticles = doBelch and not starPounds.hasOption("disableBelchParticles")
  -- Burp/Stomach rumble.
  if doBelch then
    local belchMultiplier = 1 - math.round(((digestedEntity.base + digestedEntity.weight) - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
    starPounds.belch(0.75, starPounds.belchPitch(belchMultiplier))
  end

  if not starPounds.hasOption("disableGurgleSounds") then
    starPounds.moduleFunc("sound", "play", "digest", 0.75, 0.75)
  end
  -- Fancy little particles similar to the normal death animation.
  if doBelchParticles then
    local friction = world.breathable(mouthPosition) or world.liquidAt(mouthPosition)
    local particle = sb.jsonMerge(starPounds.settings.particleTemplates.vore, {})
    particle.color = {188, 235, 96}
    particle.initialVelocity = vec2.add({(friction and 2 or 3) * mcontroller.facingDirection(), 0}, vec2.add(mcontroller.velocity(), {0, world.gravity(mouthPosition)/62.5})) -- Weird math but it works I guess.
    particle.finalVelocity = {mcontroller.facingDirection(), 10}
    particle.approach = friction and {5, 10} or {0, 0}
    particle.timeToLive = friction and 0.2 or 0.075
    local particles = {{
      action = "particle",
      specification = particle
    }}
    particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {144, 217, 0}}})
    -- Humanoids get glowy death particles.
    if digestedEntity.type == "humanoid" then
      particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {96, 184, 235}, fullbright = true, collidesLiquid = false, timeToLive = 0.5}})
      particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {0, 140, 217}, fullbright = true, collidesLiquid = false, timeToLive = 0.5}})
    end
    -- Add monster to collection if we have the skill.
    if starPounds.hasSkill("voreCollection") and (digestedEntity.type == "creature") and digestedEntity.typeName then
      local collectables = root.monsterParameters(digestedEntity.typeName).captureCollectables or {}
      for collection, collectable in pairs(collectables) do
        world.sendEntityMessage(entity.id(), "addCollectable", collection, collectable)
      end
    end
    -- Vault monsters get glowy purple particles.
    if hasEssence then
      particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {160, 70, 235}, fullbright = true, collidesLiquid = false, timeToLive = 0.5, light = {134, 71, 179, 255}}})
      particles[#particles + 1] = sb.jsonMerge(particles[1], {specification = {color = {102, 0, 216}, fullbright = true, collidesLiquid = false, timeToLive = 0.5, light = {134, 71, 179, 255}}})
    end

    starPounds.spawnMouthProjectile(particles, 5)
  end

  if not starPounds.hasOption("disableItemRegurgitation") and (#regurgitatedItems > 0) then
    if doBelchParticles then
      world.spawnProjectile("regurgitateditems", mouthPosition, entity.id(), vec2.rotate({math.random(1,2) * mcontroller.facingDirection(), math.random(0, 2)/2}, mcontroller.rotation()), false, {
        items = regurgitatedItems
      })
    elseif starPounds.type == "player" then
      for _, regurgitatedItem in pairs(regurgitatedItems) do
        player.giveItem(regurgitatedItem)
      end
    end
  end
  starPounds.feed(digestedEntity.base, digestedEntity.foodType)
  starPounds.feed(digestedEntity.weight, "preyWeight")
  return true
end

starPounds.preyStruggle = function(preyId, struggleStrength, escape)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  struggleStrength = math.max(tonumber(struggleStrength) or 0, 0)
  if not preyId then return end
  -- Only continue if they're actually eaten.
  for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
    if prey.id == preyId then
      local preyHealth = world.entityHealth(prey.id)
      local preyHealthPercent = preyHealth[1]/preyHealth[2]
      local struggleStrength = root.evalFunction2("protection", struggleStrength, status.stat("protection"))
      local escapeChance = math.max(world.entityType(preyId) == "player" and starPounds.settings.vorePlayerEscape or 0, 0.5 * struggleStrength)
      if escape and (math.random() < escapeChance) then
        if world.entityType(preyId) == "player" or (status.resourceLocked("energy") and preyHealthPercent > starPounds.settings.voreInescapableHealth) then
          starPounds.releaseEntity(preyId)
        end
      end

      if status.isResource("energy") then
        local struggleMultiplier = math.max(0, 1 - starPounds.getStat("struggleResistance"))
        local energyAmount = struggleMultiplier * (starPounds.settings.voreStruggleEnergyBase + starPounds.settings.voreStruggleEnergy * struggleStrength)
        if status.isResource("energyRegenBlock") and status.resourceLocked("energy") then
          status.modifyResource("energyRegenBlock", status.stat("energyRegenBlockTime") * starPounds.settings.voreStruggleEnergyLock * struggleMultiplier * struggleStrength)
        elseif status.resource("energy") > energyAmount then
          status.modifyResource("energy", -energyAmount)
        else
          status.overConsumeResource("energy", energyAmount)
        end
      end

      if not starPounds.hasOption("disablePredDigestion") then
        -- 1 second worth of digestion per struggle.
        local damageMultiplier = math.max(1, status.stat("powerMultiplier")) * starPounds.getStat("voreDamage")
        local protectionMultiplier = math.max(0, 1 - starPounds.getStat("voreArmorPiercing"))
        world.sendEntityMessage(preyId, "starPounds.getDigested", damageMultiplier, protectionMultiplier)
      end

      if not starPounds.hasOption("disableStruggleSounds") then
        local totalPreyWeight = (prey.base or 0) + (prey.weight or 0)
        local soundVolume = math.min(1, 0.25 + preyHealthPercent * (totalPreyWeight/(starPounds.species.default.weight * 2)))
        starPounds.moduleFunc("sound", "play", "struggle", soundVolume)
      end
      break
    end
  end
end

starPounds.releaseEntity = function(preyId, releaseAll)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  preyId = tonumber(preyId)
  -- Delete the entity's entry in the stomach.
  local releasedEntity = nil
  local statusEffect = starPounds.hasSkill("regurgitateSlimeStatus") and "starpoundsslimyupgrade" or nil
  if releaseAll then
    releasedEntity = storage.starPounds.stomachEntities[1]
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if world.entityExists(prey.id) then
        world.sendEntityMessage(prey.id, "starPounds.getReleased", entity.id(), statusEffect)
      end
    end
    if releasedEntity and world.entityExists(releasedEntity.id) then
      local belchMultiplier = 1 - math.round((releasedEntity.weight + storage.starPounds.weight - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
      starPounds.belch(0.75, starPounds.belchPitch(belchMultiplier))
    end
    storage.starPounds.stomachEntities = jarray()
  else
    -- Reverse order, lastest prey gets removed first (if not specified).
    for preyIndex = #storage.starPounds.stomachEntities, 1, -1 do
      local prey = storage.starPounds.stomachEntities[preyIndex]
      if not prey.noRelease or (starPounds.type == "player" and player.isAdmin()) then
        -- Release the first (allowed) prey, or a specific ID if given.
        if (not preyId) or (prey.id == preyId) then
          releasedEntity = table.remove(storage.starPounds.stomachEntities, preyIndex)
          break
        end
      end
    end
    -- Call back to release the entity incase the pred is releasing them.
    if releasedEntity and world.entityExists(releasedEntity.id) then
      local belchMultiplier = 1 - math.round((releasedEntity.weight - starPounds.species.default.weight)/(starPounds.settings.maxWeight * 4), 2)
      starPounds.belch(0.75, starPounds.belchPitch(belchMultiplier))
      world.sendEntityMessage(releasedEntity.id, "starPounds.getReleased", entity.id(), statusEffect)
    end
  end
end

starPounds.messageHandlers = function()
  -- Handler for enabling the mod.
  message.setHandler("starPounds.toggleEnable", localHandler(starPounds.toggleEnable))
  -- Handler for grabbing data.
  message.setHandler("starPounds.getData", simpleHandler(starPounds.getData))
  message.setHandler("starPounds.isEnabled", simpleHandler(starPounds.isEnabled))
  message.setHandler("starPounds.getSize", simpleHandler(starPounds.getSize))
  message.setHandler("starPounds.getChestVariant", simpleHandler(starPounds.getChestVariant))
  message.setHandler("starPounds.getDirectives", simpleHandler(starPounds.getDirectives))
  message.setHandler("starPounds.getVisualSpecies", simpleHandler(starPounds.getVisualSpecies))
  -- Handlers for skills/stats/options
  message.setHandler("starPounds.hasOption", simpleHandler(starPounds.hasOption))
  message.setHandler("starPounds.setOption", localHandler(starPounds.setOption))
  message.setHandler("starPounds.upgradeSkill", simpleHandler(starPounds.upgradeSkill))
  message.setHandler("starPounds.getStat", simpleHandler(starPounds.getStat))
  message.setHandler("starPounds.parseStats", simpleHandler(starPounds.parseStats))
  message.setHandler("starPounds.parseStatusEffectStats", simpleHandler(starPounds.parseStatusEffectStats))
  message.setHandler("starPounds.getSkillLevel", simpleHandler(starPounds.getSkillLevel))
  message.setHandler("starPounds.hasSkill", simpleHandler(starPounds.hasSkill))
  message.setHandler("starPounds.getAccessory", simpleHandler(starPounds.getAccessory))
  message.setHandler("starPounds.getAccessoryModifiers", simpleHandler(starPounds.getAccessoryModifiers))
  message.setHandler("starPounds.getTrait", simpleHandler(starPounds.getTrait))
  message.setHandler("starPounds.setTrait", localHandler(starPounds.setTrait))
  message.setHandler("starPounds.addEffect", simpleHandler(starPounds.addEffect))
  message.setHandler("starPounds.removeEffect", simpleHandler(starPounds.removeEffect))
  message.setHandler("starPounds.getEffect", localHandler(starPounds.getEffect))
  message.setHandler("starPounds.hasDiscoveredEffect", localHandler(starPounds.hasDiscoveredEffect))
  -- Handlers for affecting the entity.
  message.setHandler("starPounds.belch", simpleHandler(starPounds.belch))
  message.setHandler("starPounds.belchPitch", simpleHandler(starPounds.belchPitch))
  message.setHandler("starPounds.feed", simpleHandler(starPounds.feed))
  message.setHandler("starPounds.eat", simpleHandler(starPounds.eat))
  message.setHandler("starPounds.gainWeight", simpleHandler(starPounds.gainWeight))
  message.setHandler("starPounds.loseWeight", simpleHandler(starPounds.loseWeight))
  message.setHandler("starPounds.setWeight", simpleHandler(starPounds.setWeight))
  -- Ditto but vore.
  message.setHandler("starPounds.voreDigest", simpleHandler(starPounds.voreDigest))
  message.setHandler("starPounds.eatNearbyEntity", simpleHandler(starPounds.eatNearbyEntity))
  message.setHandler("starPounds.eatEntity", simpleHandler(starPounds.eatEntity))
  message.setHandler("starPounds.ateEntity", simpleHandler(starPounds.ateEntity))
  message.setHandler("starPounds.digestEntity", simpleHandler(starPounds.digestEntity))
  message.setHandler("starPounds.preyStruggle", simpleHandler(starPounds.preyStruggle))
  message.setHandler("starPounds.releaseEntity", simpleHandler(starPounds.releaseEntity))
  -- Interface/debug stuff.
  message.setHandler("starPounds.reset", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetConfirm", localHandler(starPounds.reset))
  message.setHandler("starPounds.resetWeight", localHandler(starPounds.resetWeight))
  message.setHandler("starPounds.resetStomach", localHandler(starPounds.resetStomach))
  message.setHandler("starPounds.resetBreasts", localHandler(starPounds.resetBreasts))
  message.setHandler("starPounds.resetTrait", localHandler(starPounds.resetTrait))
  message.setHandler("starPounds.resetEffects", localHandler(starPounds.resetEffects))
  message.setHandler("starPounds.setResource", localHandler(status.setResource))
end

-- Other functions
----------------------------------------------------------------------------------
starPounds.toggleEnable = function()
  starPounds.moduleFunc("prey", "released")
  starPounds.releaseEntity(nil, true)
  -- Do a barrel roll (just flip the boolean).
  storage.starPounds.enabled = not storage.starPounds.enabled
  -- Make sure the movement penalty stuff gets reset as well.
  starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
  starPounds.parseSkills()
  starPounds.updateStats(true)
  starPounds.optionChanged = true
  if not storage.starPounds.enabled then
    starPounds.moduleUninit()
    starPounds.movementModifier = 1
    starPounds.jumpModifier = 1
    starPounds.equipCheck(starPounds.getSize(0))
    world.sendEntityMessage(entity.id(), "starPounds.expire")
    status.clearPersistentEffects("starpounds")
    status.clearPersistentEffects("starpoundseaten")
  else
    for _, module in pairs(starPounds.modules or {}) do
      module:moduleInit()
    end
  end
  return storage.starPounds.enabled
end

starPounds.reset = function()
  -- Save accessories.
  local accessories = storage.starPounds.accessories
  -- Reset to base data.
  storage.starPounds = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
  -- Restore accessories.
  storage.starPounds.accessories = accessories
  -- If we set this to true, the enable function sets it back to false.
  -- Means we can keep all the 'get rid of stuff' code in one place.
  storage.starPounds.enabled = true
  starPounds.toggleEnable()
  -- Bye bye fat techs.
  if starPounds.type == "player" then
    for _, v in ipairs(player.availableTechs()) do
      if v:find("starpounds") then
        player.makeTechUnavailable(v)
      end
    end
  end
  -- Re-unlock default trait skills.
  if starPounds.type == "monster" then
    if not starPounds.getTrait() then
      starPounds.setTrait(config.getParameter("starPounds_trait"))
    end
  else
    local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
    for _, skill in ipairs(speciesTrait.skills or jarray()) do
      starPounds.forceUnlockSkill(skill[1], skill[2])
    end
  end
  return true
end

starPounds.resetConfirm = function()
  local confirmLayout = root.assetJson("/interface/confirmation/resetstarpoundsconfirmation.config")
  confirmLayout.images.portrait = world.entityPortrait(player.id(), "full")
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      starPounds.reset()
    end
  end)
  return true
end

starPounds.resetWeight = function()
  -- Set weight.
  storage.starPounds.weight = starPounds.sizes[(starPounds.getSkillLevel("minimumSize") + 1)].weight
  starPounds.currentSize, starPounds.currentSizeIndex = starPounds.getSize(storage.starPounds.weight)
  -- Reset the fat items.
  starPounds.equipCheck(starPounds.getSize(storage.starPounds.weight))

  return true
end

starPounds.resetStomach = function()
  storage.starPounds.stomachContents = {}
  storage.starPounds.stomachEntities = jarray()
  return true
end

starPounds.resetBreasts = function()
  storage.starPounds.breasts = 0
  return true
end

starPounds.backup = function()
  if starPounds.type == "player" then
    player.setProperty("starPoundsBackup", storage.starPounds)
  end
end

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end

-- Grabs a parameter, or a config, or defaultValue
configParameter = function(item, keyName, defaultValue)
  if item.parameters[keyName] ~= nil then
    return item.parameters[keyName]
  elseif root.itemConfig(item).config[keyName] ~= nil then
    return root.itemConfig(item).config[keyName]
  else
    return defaultValue
  end
end

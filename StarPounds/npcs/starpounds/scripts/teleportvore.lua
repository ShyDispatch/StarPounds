local update_old = update

function update(dt)
  update_old(dt)
  teleportVoreDelay = math.max((teleportVoreDelay or 1) - dt, 0)
  if not starPounds_didQuery and status.uniqueStatusEffectActive("beamin") and teleportVoreDelay == 0 then
    local entities = world.entityQuery(starPounds.mcontroller.position, 1, {order = "nearest", includedTypes = {"player", "npc"}, withoutEntityId = entity.id()}) or jarray()
    local eatOptions = {ignoreProtection = true, ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirment = true, energyMultiplier = 0, noSwallowSound = true}
    for _, target in ipairs(entities) do
      if starPounds.moduleFunc("pred", "eat", target, eatOptions, true) then
        starPounds.moduleFunc("pred", "eat", target, eatOptions)
        break
      end
    end
    starPounds_didQuery = true
  end
end

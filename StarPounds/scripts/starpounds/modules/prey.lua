local prey = starPounds.module:new("prey")

function prey:init()
  message.setHandler("starPounds.getEaten", function(_, _, ...) return self:swallowed(...) end)
  message.setHandler("starPounds.getReleased", function(_, _, ...) return self:released(...) end)
  message.setHandler("starPounds.getDigested", function(_, _, ...) return self:digesting(...) end)
  message.setHandler("starPounds.newPred", function(_, _, ...) return self:newPred(...) end)
end

function prey:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  self:eaten(dt)
end

function prey:eaten(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then self.heartbeat = nil return end
  -- Spectating pred stuff.
  if storage.starPounds.spectatingPred then
    if not (starPounds.hasOption("spectatePred") and world.entityExists(storage.starPounds.pred)) then
      self:released()
      status.setResource("health", 0)
      return
    else
      status.setResource("health", 0.1)
    end
  end
  -- Check that the entity actually exists.
  if not world.entityExists(storage.starPounds.pred) or starPounds.hasOption("disablePrey") then
    self:released()
    return
  end

  self.heartbeat = math.max((self.heartbeat or self.data.heartbeat) - dt, 0)
  if not storage.starPounds.spectatingPred and self.heartbeat == 0 then
    self.heartbeat = self.data.heartbeat
    promises:add(world.sendEntityMessage(storage.starPounds.pred, "starPounds.ateEntity", entity.id()), function(isEaten)
      if not isEaten then self:released() end
    end)
  end
  -- Disable knockback while eaten.
  entity.setDamageOnTouch(false)
  -- Stop entities trying to move.
  mcontroller.clearControls()
  -- Stun the entity.
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), dt))
  end
  -- Stop lounging.
  mcontroller.resetAnchorState()
  if starPounds.type == "npc" then
    -- Stop NPCs attacking.
    npc.endPrimaryFire()
    npc.endAltFire()
  end
  if starPounds.type == "monster" then
    pcall(animator.setAnimationState, "body", "idle")
    pcall(animator.setAnimationState, "damage", "none")
    pcall(animator.setGlobalTag, "hurt", "hurt")
  end
  -- Struggle mechanics.
  self[starPounds.type.."Struggle"](self, dt)
  -- Set velocity to zero.
  mcontroller.setVelocity({0, 0})
  -- Stop the prey from colliding/moving normally.
  mcontroller.controlParameters({ airFriction = 0, groundFriction = 0, liquidFriction = 0, collisionEnabled = false, gravityEnabled = false })
end

function prey:swallowed(pred)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return false end
  -- Argument sanitisation.
  pred = tonumber(pred)
  if not pred then return false end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePrey") then return false end
  -- Don't do anything if already eaten.
  if storage.starPounds.pred then return false end
  -- Check that the entity actually exists.
  if not world.entityExists(pred) then return false end
  -- Don't get eaten if already dead.
  if not status.resourcePositive("health") then return false end
  -- Eaten entities can't be interacted with. This looks very silly atm since I need to figure out a way to dynamically detect it.
  self.wasInteractable = false
  if starPounds.type == "npc" then
    self.wasInteractable = true
  end
  if self.wasInteractable then
    if starPounds.type == "npc" then
      npc.setInteractive(false)
    end
  end
  storage.starPounds.damageTeam = world.entityDamageTeam(entity.id())
  -- Player specific.
  if starPounds.type == "player" then
    self.oldTech = {}
    for _,v in pairs({"head", "body", "legs"}) do
      local equippedTech = player.equippedTech(v)
      if equippedTech then
        self.oldTech[v] = equippedTech
      end
      player.makeTechAvailable("starpoundseaten_"..v)
      player.enableTech("starpoundseaten_"..v)
      player.equipTech("starpoundseaten_"..v)
    end
  end
  -- NPC specific.
  if starPounds.type == "npc" then
    -- Are they a crewmate?
    if recruitable then
      -- Did their owner eat them?
      if recruitable.ownerUuid() and world.entityUniqueId(pred) == recruitable.ownerUuid() then
        recruitable.messageOwner("recruits.digestingRecruit")
      end
    end

    local nearbyNpcs = world.npcQuery(mcontroller.position(), 50, {withoutEntityId = entity.id(), callScript = "entity.entityInSight", callScriptArgs = {entity.id()}, callScriptResult = true})
    for _, nearbyNpc in ipairs(nearbyNpcs) do
      world.callScriptedEntity(nearbyNpc, "notify", {type = "attack", sourceId = entity.id(), targetId = storage.starPounds.pred})
    end
  end
  -- Non-player.
  if not (starPounds.type == "player") then
    -- Save the old damage team.
    -- Make other entities ignore it.
    entity.setDamageTeam({type = "ghostly", team = storage.starPounds.damageTeam.team})
    entity.setDamageOnTouch(false)
    entity.setDamageSources()
  end
  -- Save the entityId of the pred.
  storage.starPounds.pred = pred
  -- Make the entity immune to outside damage/invisible, and disable regeneration.
  status.setPersistentEffects("starpoundseaten", {
    {stat = "statusImmunity", effectiveMultiplier = 0}
  })
  status.addEphemeralEffect("starpoundseaten")
  return {
    base = entity.weight,
    foodType = entity.foodType,
    weight = storage.starPounds.weight,
    noBelch = starPounds.hasOption("disablePreyBelches")
  }
end

function prey:playerStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier
  -- Player struggles are directional.
  self.startedStruggling = self.startedStruggling or os.clock()
  -- Follow the pred's position, struggle if the player is using movement keys.
  local horizontalDirection = (mcontroller.xVelocity() > 0) and 1 or ((mcontroller.xVelocity() < 0) and -1 or 0)
  local verticalDirection = (mcontroller.yVelocity() > 0) and 1 or ((mcontroller.yVelocity() < 0) and -1 or 0)
  self.cycle = vec2.lerp(5 * dt, (self.cycle or {0, 0}), vec2.mul({horizontalDirection, verticalDirection}, self.struggled and 0.25 or 1))
  local struggleMagnitude = vec2.mag(self.cycle)
  if not (horizontalDirection == 0 and verticalDirection == 0) then
    -- Kills the player if they're spectating, but move.
    if storage.starPounds.spectatingPred and verticalDirection > 0 then
      status.setResource("health", 0)
      self:released()
      return
    end
    if struggleMagnitude > 0.6 and not self.struggled then
      self.struggled = true
      world.sendEntityMessage(storage.starPounds.pred, "starPounds.preyStruggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
    elseif math.round(struggleMagnitude, 1) < 0.2 then
      self.struggled = false
    end
  elseif math.round(struggleMagnitude, 1) < 0.2 then
    self.struggled = false
    self.startedStruggling = os.clock()
  end
  local predPosition = world.entityPosition(storage.starPounds.pred)
  if storage.starPounds.spectatingPred then
    mcontroller.setPosition(vec2.add(world.entityPosition(storage.starPounds.pred), {0, -1}))
    local distance = world.distance(predPosition, mcontroller.position())
    mcontroller.translate(vec2.lerp(10 * dt, {0, 0}, distance))
  else
    local predPosition = vec2.add(predPosition, vec2.mul(self.cycle, 2 + (math.sin((os.clock() - self.startedStruggling) * 2) + 1)/4))
    -- Slowly drift up/down.
    predPosition = vec2.add(predPosition, {0, math.sin(os.clock() * 0.5) * 0.25 - 0.25})
    local distance = world.distance(predPosition, mcontroller.position())
    mcontroller.translate(vec2.lerp(10 * dt, {0, 0}, distance))
  end
  -- No air.
  if not (starPounds.hasOption("disablePreyDigestion") or starPounds.hasOption("disablePreyBreathLoss")) and (not status.statPositive("breathProtection")) and world.breathable(world.entityMouthPosition(entity.id())) then
    status.modifyResource("breath", -(status.stat("breathDepletionRate") * self.data.playerBreathMultiplier + status.stat("breathRegenerationRate")) * dt)
  end
end

function prey:npcStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier
  -- Monsters/NPCs just cause energy loss occassionally, and are locked to the pred's position.
  mcontroller.setPosition(vec2.add(world.entityPosition(storage.starPounds.pred), {0, -1}))
  self.cycle = self.cycle and self.cycle - (dt * healthMultiplier) or (math.random(10, 15) / 10)
  if self.cycle <= 0 then
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.preyStruggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
    self.cycle = math.random(10, 15) / 10
  end
end

function prey:monsterStruggle(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Loose calculation for how "powerful" the prey is.
  local healthMultiplier = 0.5 + status.resourcePercentage("health") * 0.5
  -- Using the NPC power function because the monster one gets stupid high.
  local weightRatio = math.max((entity.weight + storage.starPounds.weight) / starPounds.species.default.weight, 0.1)
  local monsterMultiplier = root.evalFunction("npcLevelPowerMultiplierModifier", monster.level()) * self.data.monsterStruggleMultiplier + 1
  if starPounds.isCritter then
    monsterMultiplier = root.evalFunction("npcLevelPowerMultiplierModifier", monster.level()) * self.data.critterStruggleMultiplier
  end
  local struggleStrength = math.max(1, status.stat("powerMultiplier")) * healthMultiplier * weightRatio * monsterMultiplier
  -- Monsters/NPCs just cause energy loss occassionally, and are locked to the pred's position.
  mcontroller.setPosition(vec2.add(world.entityPosition(storage.starPounds.pred), {0, -1}))
  self.cycle = self.cycle and self.cycle - (dt * healthMultiplier) or (math.random(10, 15) / 10)
  if self.cycle <= 0 then
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.preyStruggle", entity.id(), struggleStrength, not starPounds.hasOption("disableEscape"))
    self.cycle = math.random(10, 15) / 10
  end
end

function prey:released(source, overrideStatus)
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- Argument sanitisation.
  source = tonumber(source)
  overrideStatus = overrideStatus and tostring(overrideStatus) or nil
  -- Reset damage team.
  entity.setDamageTeam(storage.starPounds.damageTeam)
  storage.starPounds.damageTeam = nil
  local pred = storage.starPounds.pred
  -- Remove the pred id from storage.
  storage.starPounds.pred = nil
  storage.starPounds.spectatingPred = nil
  -- Reset struggle cycle.
  self.cycle = nil
  status.clearPersistentEffects("starpoundseaten")
  status.removeEphemeralEffect("starpoundseaten")
  entity.setDamageOnTouch(true)
  if self.wasInteractable then
    if starPounds.type == "npc" then
      npc.setInteractive(true)
    end
  end
  -- Restore techs.
  if starPounds.type == "player" then
    for _,v in pairs({"head", "body", "legs"}) do
      player.unequipTech("starpoundseaten_"..v)
      player.makeTechUnavailable("starpoundseaten_"..v)
    end
    for _,v in pairs(self.oldTech or {}) do
      player.equipTech(v)
    end
  end
  -- Tell the pred we're out.
  if world.entityExists(pred) then
    -- Callback incase the entity calls this.
    world.sendEntityMessage(pred, "starPounds.releaseEntity", entity.id())
    -- Don't get stuck in the ground.
    mcontroller.setPosition(world.entityPosition(pred))
    -- Make them wet.
    status.addEphemeralEffect(overrideStatus or "starpoundsslimy")
    -- Behaviour damage trigger.
    self.notifyDamage(pred)
  end
end

function prey:newPred(pred)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  pred = tonumber(pred)
  if not pred then return false end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePrey") then return false end
  -- Don't do anything if not already eaten.
  if not storage.starPounds.pred then return false end
  -- New pred.
  storage.starPounds.pred = pred
  return true
end

function prey:digesting(digestionRate, protectionMultiplier)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Argument sanitisation.
  digestionRate = math.max(tonumber(digestionRate) or 0, 0)
  protectionMultiplier = math.max(tonumber(protectionMultiplier) or 1, 0)
  if digestionRate == 0 then return end
  -- Don't do anything if disabled.
  if starPounds.hasOption("disablePreyDigestion") then return end
  -- Don't do anything if we're not eaten.
  if not storage.starPounds.pred then return end
  -- 0.5% of current health + 0.5 or 0.5% max health, whichever is smaller. (Stops low hp entities dying instantly)
  local amount = (status.resource("health") * 0.005 + math.min(0.005 * status.resourceMax("health"), 1)) * digestionRate
  amount = root.evalFunction2("protection", amount, status.stat("protection") * protectionMultiplier)
  -- Remove the health.
  status.overConsumeResource("health", amount)
  if not status.resourcePositive("health") then
    world.sendEntityMessage(storage.starPounds.pred, "starPounds.preyDigested", entity.id(), self:createDrops(), storage.starPounds.stomachEntities)
    -- Player stuff.
    if starPounds.type == "player" then
      if starPounds.hasOption("spectatePred") then
        player.playCinematic("/cinematics/starpounds/starpoundsvore.cinematic")
        storage.starPounds.spectatingPred = true
      else
        for _,v in pairs({"head", "body", "legs"}) do
          player.unequipTech("starpoundseaten_"..v)
          player.makeTechUnavailable("starpoundseaten_"..v)
        end
        for _,v in pairs(starPounds.oldTech or {}) do
          player.equipTech(v)
        end
      end
    end
    -- NPC stuff.
    if starPounds.type == "npc" then
      if world.entityUniqueId(storage.starPounds.pred) and world.entityUniqueId(storage.starPounds.pred) == self.deliveryTarget then
        world.sendEntityMessage(storage.starPounds.pred, "starPounds.digestedPizzaEmployee")
      end
      -- Are they a crewmate?
      if recruitable then
        -- Did their owner eat them?
        local predId = storage.starPounds.pred
        storage.starPounds.pred = nil
        if recruitable.ownerUuid() and world.entityUniqueId(predId) == recruitable.ownerUuid() then
          recruitable.messageOwner("recruits.digestedRecruit", recruitable.recruitUuid())
        end
        recruitable.despawn()
        return
      end
    end
    -- Getting digested by a player removes all your fat.
    local predType = world.entityType(storage.starPounds.pred)
    if (predType == "player") or (predType == "npc") then
      starPounds.setWeight(0)
    end
    -- Run standard monster/NPC death stuff.
    if die then die() end
  end
end

function prey:createDrops()
  local items = {}
  for _, slot in ipairs({"head", "chest", "legs", "back"}) do
    local item = player.equippedItem(slot.."Cosmetic") or player.equippedItem(slot)
    if item then
      if (item.parameters and item.parameters.tempSize) then
        item.name = item.parameters.baseName
        item.parameters.tempSize = nil
        item.parameters.baseName = nil
      end
      item.name = configParameter(item, "regurgitateItem", item.name)
      if not (item.parameters and item.parameters.size) and not configParameter(item, "hideBody") and not configParameter(item, "disableRegurgitation") then
        table.insert(items, item)
      end
    end
  end
  -- Give essence if applicable.
  if starPounds.type == "monster" then
    local dropPools = sb.jsonQuery(monster.uniqueParameters(), "dropPools", jarray())
    if dropPools[1] and dropPools[1].default then
      local dropItems = root.createTreasure(dropPools[1].default, monster.level())
      for _, item in ipairs(dropItems) do
        if item.name == "essence" then table.insert(items, item) end
      end
    end
  end
  return items
end

function prey.notifyDamage(predId)
  -- NPCs/monsters become hostile when released (as if damaged normally).
  if starPounds.type == "npc" then
    notify({type = "attack", sourceId = entity.id(), targetId = predId})
  elseif starPounds.type == "monster" then
    self.damaged = true
    if self.board then self.board:setEntity("damageSource", predId) end
  end
end

starPounds.modules.prey = prey

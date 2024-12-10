require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  starPounds.init()
  starPounds.messageHandlers()
  storage.starPounds = storage.starPounds or starPounds.baseData
  object.setInteractive(true)

  dialog = {
    swallow = {
      "Mmhph! ...UURP! Thanks for the meal you cutie~",
      "Ulp! Fwah~ RIGHT where you belong, burbling away for me~",
      "Gulp! Mhmmm... mph, pwah!~ Oogh... So nice and filling...~ Now stay put in there~",
      "Ulp! Bwah~ I was feeling a little peckish too~ Just what I need for my growing ass!",
      "Gllp!~ Fwaah~ Y'know, all you had to do was ask, not that I mind at all~",
      "Gulp! Phew!~ Just kick REALLY hard if ya need me to swallow down some food for you~"
    },
    struggle = {
      "Unnf... Keep struggling~ It feels so... so...~",
      "Y'know you're just a thick, juicy hunk of meat one way or another, just give in already~",
      "Caaareful~ You're making my stomach work really hard! You might drown in all those juices~",
      "M-mmmph... mmwuuAAAGH~ ...Y-you didn't hear that...",
      "Gosh... y-you're wobbling all of me with all those pointless struggles~ My boobs... and belly...~"
    },
    stop = {
      "H-hey! Who said you could wriggle out like that!",
      "Ooogh but I wasn't done demolishing every fiber of your being into thick, soupy calories...",
      "Dooh... I'm still soo hungry, are you really gonna neglect my empty tummy like that?",
      "Come baack...~ you know you belong right here on this bulging dough belly~",
      "I hope you're only leaving so you can come back with more food~",
      "Leaving so you can plump yourself up for me? Dooh how sweet~",
      "Unf... get back in here! I'm wasting away! Just listen to this poor starving belly...",
      "Come back soon morsel~ I can't wait to finally churn you up into a fine slurry~"
    },
    digested = {
      "BuuuUUUUOOOOOORRRRP!!!~ Oogh~ Thanks for the meal you cutie~",
      "Nothing but a mushy, sloshy soup pumping through my guts now~",
      "Be a good little snack and fill out the rest of my churning guts~",
      "Ooh? My belly's all sloshy and soft again? Guess they didn't last very long...~",
      "So what do you prefer? Being my boobs, butt, or belly fat?~",
      "Uugh I thought you'd last a little longer in there...~",
      "Look at you destroying what's left of my shrinking wardrobe!~",
      "Mhmmm I'm already getting so bloated~ Guess you were nothing but hot air~",
      "UUURP!~ Oh! Already gave up? Shoulda kept your head above that sea of stomach soup~",
      "What's this now? Another cup size? I'll need to order some cute new lingerie soon...~"
    }
  }


  regurgitateTimer = 0
end

function onInteraction(args)
  starPounds.eatEntity(args.sourceId)
end

function onNpcPlay(npcId)
  onInteraction({sourceId = npcId})
end

function update(dt)
  -- Check promises.
  promises:update()

  starPounds.voreCheck()
  starPounds.digest(dt)

  if storage.starPounds.stomachEntities[1] then
    lastEntity = storage.starPounds.stomachEntities[1]
  end

  if regurgitateTimer > 0 and (regurgitateTimer - dt) <= 0 then
    playSound("talk", 1, 1.25)
    animator.burstParticleEmitter("emotesad")
    object.say(tostring(dialog.stop[math.random(1, #dialog.stop)]:gsub("<player>", world.entityName(lastEntity.id).."^reset;")))
    world.sendEntityMessage(lastEntity.id, "starPounds.getReleased", entity.id())
  end

  regurgitateTimer = math.max(0, regurgitateTimer - dt)
end

function playSound(soundPool, volume, pitch, loops)
  if not ((soundPool == "digest" or soundPool == "struggle") and regurgitateTimer > 0) then
    animator.setSoundVolume(soundPool, volume or 1, 0)
    animator.setSoundPitch(soundPool, pitch or 1, 0)
    animator.playSound(soundPool, loops)
    if soundPool == "struggle" then
      if math.random(1, 600) == 1 then
        playSound("talk", 1, 1.25)
        animator.burstParticleEmitter("emotehappy")
        object.say(tostring(dialog.struggle[math.random(1, #dialog.struggle)]:gsub("<player>", world.entityName(storage.starPounds.stomachEntities[1].id).."^reset;")))
      end
    end
  end
end

starPounds = {
  init = function()
    starPounds.settings = root.assetJson("/scripts/starpounds/starpounds.config:settings")
    starPounds.baseData = root.assetJson("/scripts/starpounds/starpounds.config:baseData")
    -- Need to update this whole script to use modules at some point.
    starPounds.settings.minimumGurgleTime = 5
    starPounds.settings.gurgleTime = 30
    starPounds.settings.voreDigestTimer = 0.25
  end,
  -- Mod functions
  ----------------------------------------------------------------------------------
  digest = function(dt, isGurgle)
    -- Don't do anything if stomach is empty.
    if not (#storage.starPounds.stomachEntities > 0) then
      starPounds.gurgleTimer = nil
      starPounds.voreDigestTimer = 0
      return
    end

    if not isGurgle then
      -- Vore stuff
      starPounds.voreDigestTimer = math.max((starPounds.voreDigestTimer or 0) - dt, 0)
      if starPounds.voreDigestTimer == 0 then
        starPounds.voreDigestTimer = starPounds.settings.voreDigestTimer
        starPounds.voreDigest(starPounds.settings.voreDigestTimer)
      end
      -- Gurgle stuff.
      if starPounds.gurgleTimer and starPounds.gurgleTimer > 0 then
        starPounds.gurgleTimer = math.max(starPounds.gurgleTimer - dt, 0)
      else
        -- gurgleTime (default 30) is the average, minimumGurgleTime (default 5) is the minimum, so (5 + (60 - 5))/2 = 30
        if starPounds.gurgleTimer then starPounds.gurgle() end
        starPounds.gurgleTimer = math.round(util.randomInRange({starPounds.settings.minimumGurgleTime, (starPounds.settings.gurgleTime * 2) - starPounds.settings.minimumGurgleTime}))
      end
    else
      -- 25% strength for vore digestion on gurgles.
      starPounds.voreDigest(dt * 0.25)
    end
  end,

  gurgle = function(noDigest)
    local seconds = math.random(100, 300)/100
    starPounds.digest(seconds, true)
    playSound("digest", 0.75, (2 - seconds/5))
  end,

  -- Vore functions
  ----------------------------------------------------------------------------------
  voreCheck = function()
    -- Don't do anything if there's no eaten entities.
    if not (#storage.starPounds.stomachEntities > 0) then return end
    -- table.remove is very inefficient in loops, so we'll make a new table instead and just slap in the stuff we're keeping.
    local newStomach = jarray()
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if world.entityExists(prey.id) then
        table.insert(newStomach, prey)
      end
    end
    storage.starPounds.stomachEntities = newStomach
  end,

  voreDigest = function(digestionRate)
    -- Don't do anything if there's no eaten entities.
    if not (#storage.starPounds.stomachEntities > 0) then return end
    -- Reduce health of all entities.
    for _, prey in pairs(storage.starPounds.stomachEntities) do
      world.sendEntityMessage(prey.id, "starPounds.getDigested", digestionRate)
    end
  end,

  eatEntity = function(preyId)
    -- Max 1 entity for this object.
    if #storage.starPounds.stomachEntities > 0 then return end
    -- Don't do anything if they're already eaten.
    local eatenEntity = nil
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == preyId then
        eatenEntity = prey
      end
    end
    if eatenEntity then return false end
    -- Ask the entity to be eaten, add to stomach if the promise is successful.
    promises:add(world.sendEntityMessage(preyId, "starPounds.getEaten", entity.id()), function(prey)
      table.insert(storage.starPounds.stomachEntities, {
        id = preyId,
        weight = prey.weight or 0,
        bloat = prey.bloat or 0,
        experience = prey.experience or 0,
        type = world.entityType(preyId):gsub(".+", {player = "humanoid", npc = "humanoid", monster = "creature"})
      })
      -- Swallow/stomach rumble
      playSound("swallow", 1 + math.random(0, 10)/100, 1)
      playSound("digest", 1, 0.75)
      playSound("talk", 1, 1.25)
      animator.burstParticleEmitter("emotehappy")
      object.say(tostring(dialog.swallow[math.random(1, #dialog.swallow)]:gsub("<player>", world.entityName(preyId).."^reset;")))
      animator.setAnimationState("interactState", "swallow", true)
    end)
    return true
  end,

  ateEntity = function(preyId)
    if regurgitateTimer > 0 then return true end
    for _, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == preyId then return true end
    end
    return false
  end,

  digestEntity = function(preyId, items, preyStomach)
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
    playSound("digest", 0.75, 0.75)
    playSound("talk", 1, 1.25)
    animator.burstParticleEmitter("emotehappy")
    animator.setAnimationState("interactState", "digest", true)
    object.say(tostring(dialog.digested[math.random(1, #dialog.digested)]:gsub("<player>", world.entityName(digestedEntity.id).."^reset;")))
    return true
  end,

  preyStruggle = function(preyId)
    -- Only continue if they're actually eaten.
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == preyId then
        local preyHealth = world.entityHealth(prey.id)
        local preyHealthPercent = preyHealth[1]/preyHealth[2]

        playSound("struggle", math.min(1, (0.25 + math.max(0.5 * prey.weight/120, 0.35)) * (0.75 + preyHealthPercent/4)))
        if world.entityType(preyId) == "player" and math.random() < 0.1 then
          starPounds.releaseEntity(preyId)
        end
        -- 1 second worth of digestion per struggle.
        world.sendEntityMessage(preyId, "starPounds.getDigested", 1)
        break
      end
    end
  end,

  releaseEntity = function(preyId)
    -- Delete the entity's entry in the stomach.
    local releasedEntity = nil
    for preyIndex, prey in ipairs(storage.starPounds.stomachEntities) do
      if prey.id == preyId then
        releasedEntity = table.remove(storage.starPounds.stomachEntities, preyIndex)
        break
      end
      if not preyId then
        releasedEntity = table.remove(storage.starPounds.stomachEntities)
        break
      end
    end
    if releasedEntity and world.entityExists(releasedEntity.id) then
      if regurgitateTimer == 0 then
        regurgitateTimer = 2
        animator.setAnimationState("interactState", "regurgitate", true)
        playSound("swallow", 1.25, math.random(8, 12)/10, 2)
      end
    end
  end,

  messageHandlers = function()
    message.setHandler("starPounds.digest", simpleHandler(starPounds.digest))
    -- Ditto but vore.
    message.setHandler("starPounds.eatEntity", simpleHandler(starPounds.eatEntity))
    message.setHandler("starPounds.ateEntity", simpleHandler(starPounds.ateEntity))
    message.setHandler("starPounds.digestEntity", simpleHandler(starPounds.digestEntity))
    message.setHandler("starPounds.preyStruggle", simpleHandler(starPounds.preyStruggle))
    message.setHandler("starPounds.releaseEntity", simpleHandler(starPounds.releaseEntity))
    -- sounds
    message.setHandler("starPounds.playSound", simpleHandler(playSound))
  end
}

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end

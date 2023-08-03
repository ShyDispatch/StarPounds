function init()
  self.chatOptions = config.getParameter("chatOptions", {})
  self.chatTimer = 0
    self.minimumDistance = config.getParameter("minimumDistance", 10)
    self.objectPosition = entity.position()
end

function update(dt)
  self.chatTimer = math.max(0, self.chatTimer - dt)
  if self.chatTimer == 0 then
    local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })
        
        local filteredPlayers = jarray()
        for _, player in ipairs(players) do

            local playerPosition = world.entityMouthPosition(player)
            if world.magnitude(self.objectPosition, playerPosition) > self.minimumDistance then
                if world.lineTileCollision(self.objectPosition, playerPosition) then
                    table.insert(filteredPlayers, player)
                end
            end
        end

    if #filteredPlayers > 0 and #self.chatOptions > 0 then
      object.say(self.chatOptions[math.random(1, #self.chatOptions)])
      self.chatTimer = config.getParameter("chatCooldown")
    end
  end
end
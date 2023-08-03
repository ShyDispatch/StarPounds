function init()
  if not cakes then cakes = {} end
end

function update(dt)
  if effect.duration() == 60 then
    -- Add a new cake.
    table.insert(cakes, math.random(60, 600)/60)
  end
  sb.setLogMap("^#ccbbff;Starpounds_Cakes", sb.print(cakes))
  -- Decrement the timer on each cake.
  for i in pairs(cakes) do
    cakes[i] = math.max(cakes[i] - dt, 0)
    if cakes[i] == 0 then
      -- Spawn the cake.
      world.spawnItem("anomalouscake", entity.position())
      cakes[i] = nil
    end
  end
  -- Needs to be 2 * dt so it doesn't immediately end the next tick.
  effect.modifyDuration(60 - dt - effect.duration())
  -- Yeet status if no cakes are left.
  if #cakes == 0 then
    status.setStatusProperty("cakes", nil)
    effect.expire()
  end
end

function uninit()
  local items = projectile.getParameter("items", jarray())
  for _, item in ipairs(items) do
    world.spawnItem(item, entity.position())
  end
end

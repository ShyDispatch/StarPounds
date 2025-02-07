local update_old = update
function update(dt)
  update_old(dt)
  if starPounds.currentVariant and not storage.removedChest and #storage.starPounds.stomachEntities > 0 then
    storage.removedChest = true

    npc.setItemSlot("chestCosmetic")
    -- Fast way to force a size reequip.
    starPounds.optionChanged = true
    starPounds.equipCheck(starPounds.currentSize)
    starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
  end
end

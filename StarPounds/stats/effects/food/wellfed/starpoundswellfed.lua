function init()
  for _, statusScript in ipairs(root.assetJson("/stats/effects/food/wellfed/wellfed.statuseffect:scripts")) do
    if statusScript ~= "wellfed_starpoundspatch.lua" then
      require(string.format("/stats/effects/food/wellfed/%s", statusScript))
    end
    local update_old = update or function() end
    function update(dt)
      starPounds = getmetatable ''.starPounds
      starPoundsEnabled = starPounds and starPounds.isEnabled()
      if not starPoundsEnabled then
        status.addEphemeralEffect("wellfed", effect.duration())
      end
      update_old(dt)
    end
  end

  init()
end

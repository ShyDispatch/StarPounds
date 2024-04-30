function randomStatusText(personality)
  local statuses = root.assetJson("/npcs/statuses.config:statuses")
  local customStatuses = config.getParameter("statuses")
  if customStatuses then
    options = customStatuses
  elseif not personality or math.random() < 0.5 then
    options = statuses.generic
  else
    options = statuses[personality]
    if not options then
      options = statuses.generic
    end
  end
  return options[math.random(#options)]
end

require "/scripts/messageutil.lua"
starPounds = getmetatable ''.starPounds

function init()
end

function update()
  if isAdmin ~= player.isAdmin() then
    isAdmin = player.isAdmin()
  end

  -- Check promises.
  promises:update()
end

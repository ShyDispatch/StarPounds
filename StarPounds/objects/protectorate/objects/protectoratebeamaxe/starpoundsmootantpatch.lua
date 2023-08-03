local init_old = init or function() end

function init()
  init_old()

  if world.type() == "mootantintro" then
    object.setInteractive(true)
  end
end

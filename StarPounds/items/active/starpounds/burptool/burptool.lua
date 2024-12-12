function init()
  activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    starPounds.belch(0.75, starPounds.belchPitch(), nil, false)
  end
end

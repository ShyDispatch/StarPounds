--Silver Sokolova#3576
function init()
  swingTime = config.getParameter("swingTime",1)
  activeItem.setArmAngle(-math.pi / 2)
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  if not swingTimer and fireMode == "primary" and player then
    swingTimer = swingTime
  end

  if swingTimer then
    swingTimer = math.max(0, swingTimer - dt)

    activeItem.setArmAngle((-math.pi / 2) * (swingTimer / swingTime))

    if swingTimer == 0 then
      learnBlueprint(shiftHeld)
      activeItem.setArmAngle(-math.pi / 2)
    end
  end
end

function learnBlueprint()
  local recipes = config.getParameter("recipes","perfectlygenericitem")
  recipes = type(recipes) == "string" and {recipes} or recipes
  local consume = false

  for i = 1, #recipes do
    if not player.blueprintKnown(recipes[i]) then
      player.giveBlueprint(recipes[i])
      consume = true
    end
  end
  if consume then item.consume(1) end
  script.setUpdateDelta(0)
  animator.playSound("learnBlueprint")
end

function updateAim()
  aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  activeItem.setFacingDirection(aimDirection)
end
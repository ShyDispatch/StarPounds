require "/scripts/util.lua"

function init()
  object.setInteractive(true)
end

function onInteraction(args)
  local interactData = config.getParameter("interactData")

  local inventoryPool = config.getParameter("inventoryPool")
  local shuffleSeed = math.floor(os.time() / config.getParameter("rotationTime"))
  math.randomseed(shuffleSeed)
  shuffle(inventoryPool)
  math.randomseed(util.seedTime())

  interactData.recipes = jarray()
  for i = 1, config.getParameter("selectCount", 1) do
    if not inventoryPool[i] then break end
    table.insert(interactData.recipes, inventoryPool[i])
  end

  return { "OpenCraftingInterface", interactData }
end

function shuffle(list)
  for i = 1, #list do
    local swapIndex = math.random(1, #list)
    list[i], list[swapIndex] = list[swapIndex], list[i]
  end
end

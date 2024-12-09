local init_old = init
function init()
  sizes = root.assetJson("/scripts/starpounds/starpounds_sizes.config:sizes")
  init_old()
end

function increaseWeightProgress(weight, step)
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = sizes[currentSizeIndex + 1] and sizes[currentSizeIndex + 1].weight or self.settings.maxWeight
  local weightGain = math.floor(step * (nextWeight - sizes[currentSizeIndex].weight) + 0.5)
  world.sendEntityMessage(entity.id(), "starPounds.gainWeight", weightGain, true)
end

function decreaseWeightProgress(weight, step)
  local step = math.max(0, math.min((step or 1), 1))
  local currentSize, currentSizeIndex = getSize(weight)
  local nextWeight = sizes[currentSizeIndex + 1] and sizes[currentSizeIndex + 1].weight or self.settings.maxWeight
  local weightLoss = math.floor(step * (nextWeight - sizes[currentSizeIndex].weight) + 0.5)
  world.sendEntityMessage(entity.id(), "starPounds.loseWeight", weightLoss, true)
end

function getSize(weight)
  local sizeIndex = 0
  -- Go through all sizes (smallest to largest) to find which size.
  for i in ipairs(sizes) do
    if weight >= sizes[i].weight then
      sizeIndex = i
    end
  end

  return sizes[sizeIndex], sizeIndex
end

-- param entity
function tryEatEntity(args, board)
  if args.entity == nil then return false end
  return starPounds.eatEntity(args.entity)
end

-- param entity
function hasEatenEntity(args, board)
  if args.entity == nil then return false end
  local eatenEntity = false
  if storage.starPounds then
  	for _, prey in ipairs(storage.starPounds.stomachEntities) do
  		if prey.id == args.entity then
  			eatenEntity = true
  			break
  		end
  	end
  end
  return eatenEntity
end

function movementPenalty(args, board)
  return true, {number = (starPounds.currentSize and (1 - starPounds.currentSize.movementPenalty) or 1)}
end

function fullStomach(args, board)
  return starPounds.stomach.contents > starPounds.stomach.capacity
end

function isEaten(args, board)
  return (storage.starPounds.pred ~= nil) or status.uniqueStatusEffectActive("starpoundsvore")
end

function blobOffset(args, board)
  return offsetPosition({position = args.position, offset = ((starPounds.currentSize and starPounds.currentSize.isBlob) and {0, 2} or {0, 0})}, board)
end

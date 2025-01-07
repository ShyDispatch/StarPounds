local interact_old = interact

function interact(args, ...)
  --world.sendEntityMessage(args.sourceId, "starPounds.addEffect", "fizzy")
  return interact_old(args, ...)
end

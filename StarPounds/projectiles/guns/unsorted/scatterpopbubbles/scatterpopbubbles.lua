require "/scripts/vec2.lua"
function init()
  local speedVariance = 1 + (math.random() - 0.5) * projectile.getParameter("speedVariance", 0)
  mcontroller.setVelocity(vec2.mul(mcontroller.velocity(), speedVariance))
end

local updat = update or function() end

function update(...)
  updat(...)
  animator.setAnimationState("starpounds_hook", self.projectileId and "off" or "on")
end

--Script provided by Silver Sokolova
require "/items/active/weapons/ranged/beamfire.lua"

function BeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self.transitionTimer = 0
    self:setState(self.fire)
  end

  if self.weapon.currentAbility == self then
    if self.weapon.currentState == self.fire then
      self.transitionTimer = math.min(self.transitionTimer + self.dt, self.beamTransitionTime)
    end
  end
end

function BeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)

  util.wait(self.stances.cooldown.duration, function()
    if self.transitionTimer > 0 then
      self.transitionTimer = math.max(0, self.transitionTimer - self.dt)

      if self.transitionTimer == 0 then
        activeItem.setScriptedAnimationParameter("chains", {})
      else
        local beamStart = self:firePosition()
        local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
        local collidePoint = world.lineCollision(beamStart, beamEnd)
        if collidePoint then
          beamEnd = collidePoint
        end

        self:drawBeam(beamEnd, collidePoint)
      end
    end
  end)
end

function BeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  local currentFrame = self:beamFrame()
  if newChain.startSegmentImage then
    newChain.startSegmentImage = newChain.startSegmentImage:gsub("<beamFrame>", currentFrame)
  end
  newChain.segmentImage = newChain.segmentImage:gsub("<beamFrame>", currentFrame)
  if newChain.endSegmentImage then
    newChain.endSegmentImage = newChain.endSegmentImage:gsub("<beamFrame>", currentFrame)
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function BeamFire:beamFrame()
  return math.max(1, math.min(self.beamTransitionFrames, math.floor(self.transitionTimer * self.beamTransitionFrames / self.beamTransitionTime + 1.25)))
end

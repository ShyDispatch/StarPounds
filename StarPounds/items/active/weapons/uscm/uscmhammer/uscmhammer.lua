require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  self.weapon:addAbility(self.altAbility)

  self.weapon:init()

  self.inactiveBaseDps = config.getParameter("inactiveBaseDps")
  self.activeBaseDps = config.getParameter("activeBaseDps")

  self.active = false
  animator.setAnimationState("hammer", "inactive")
  self.primaryAbility.animKeyPrefix = "inactive"
  self.primaryAbility.baseDps = self.inactiveBaseDps
  self.animKeyPrefix = self.animKeyPrefix or ""
  updateSmashAbility()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)

  setActive(self.altAbility.active)
end

function uninit()
  self.weapon:uninit()
end

function setActive(active)
  if self.active ~= active then
    self.active = active
    if self.active then
      animator.setAnimationState("hammer", "extend")
      self.primaryAbility.animKeyPrefix = "active"
      self.primaryAbility.baseDps = self.activeBaseDps
    else
      animator.setAnimationState("hammer", "retract")
      self.primaryAbility.animKeyPrefix = "inactive"
      self.primaryAbility.baseDps = self.inactiveBaseDps
    end
    self.primaryAbility.damageConfig.baseDamage = self.primaryAbility.baseDps * self.primaryAbility.fireTime
  end
end

function updateSmashAbility()
  if HammerSmash then
    HammerSmash.fire = function(self)
      self.weapon:setStance(self.stances.fire)
      self.weapon:updateAim()

      animator.setAnimationState("swoosh", self.animKeyPrefix .. "fire")
      animator.playSound(self.animKeyPrefix .. "fire")
      animator.burstParticleEmitter(self.animKeyPrefix .. self.weapon.elementalType .. "swoosh")

      local smashMomentum = self.smashMomentum
      smashMomentum[1] = smashMomentum[1] * mcontroller.facingDirection()
      mcontroller.addMomentum(smashMomentum)

      local smashTimer = self.stances.fire.smashTimer
      local duration = self.stances.fire.duration
      while smashTimer > 0 or duration > 0 do
        smashTimer = math.max(0, smashTimer - self.dt)
        duration = math.max(0, duration - self.dt)

        local damageArea = partDamageArea("swoosh")
        if not damageArea and smashTimer > 0 then
          damageArea = partDamageArea("hammer")
        end
        self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)

        if smashTimer > 0 then
          local groundImpact = world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("hammer", "groundImpactPoly")), mcontroller.position()))
          if mcontroller.onGround() or groundImpact then
            smashTimer = 0
            if groundImpact then
              animator.burstParticleEmitter("groundImpact")
              animator.playSound("groundImpact")
            end
          end
        end
        coroutine.yield()
      end

      self.cooldownTimer = self:cooldownTime()
    end

    HammerSmash.spin = function(self)
      self.weapon:setStance(self.stances.fire)
      self.weapon:updateAim()

      animator.setAnimationState("swoosh", self.animKeyPrefix .. "fire")
      animator.playSound(self.animKeyPrefix .. "fire")
      animator.burstParticleEmitter(self.animKeyPrefix .. self.weapon.elementalType .. "swoosh")

      local direction = -mcontroller.facingDirection()

      local spinTimer = self.stances.spin.spinTimer
      while spinTimer > 0 do
        spinTimer = spinTimer - self.dt

        local ratio = 1 - ((spinTimer / self.stances.spin.spinTimer) ^ 2)
        local angle = ratio * self.stances.spin.spinAngle * direction
        mcontroller.setRotation(angle)

        local damageArea = partDamageArea("swoosh")
        if damageArea then
          self.weapon:setDamage(self.damageConfig, poly.rotate(damageArea, angle), self.fireTime)
        end

        coroutine.yield()
      end

      mcontroller.setRotation(0)
      self.cooldownTimer = self:cooldownTime()
    end
  end
end

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
  animator.setAnimationState("blade", "inactive")
  self.animKeyPrefix = self.primaryAbility.animKeyPrefix
  self.primaryAbility.baseDps = self.inactiveBaseDps
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
      animator.setAnimationState("blade", "extend")
      self.primaryAbility.animKeyPrefix = "active"
      self.primaryAbility.baseDps = self.activeBaseDps
    else
      animator.setAnimationState("blade", "retract")
      self.primaryAbility.animKeyPrefix = "inactive"
      self.primaryAbility.baseDps = self.inactiveBaseDps
    end
    self.animKeyPrefix = self.primaryAbility.animKeyPrefix
    self.primaryAbility.damageConfig.baseDamage = self.primaryAbility.baseDps * self.primaryAbility.fireTime
  end
end

-- Unlike the normal melee ability, hammers don't support animKeyPrefix for whatever reason, so enjoy this mess.
function updateSmashAbility()
  if HammerSmash then
    local hammerSmashFire_old = HammerSmash.fire
    local hammerSmashSpin_old = HammerSmash.spin
    local setAnimationState_old = animator.setAnimationState

    function animator.setAnimationState(partName, partState, startNew)
      if (partName == "swoosh") and (partState == "fire") then partState = self.animKeyPrefix .. "fire" end
      setAnimationState_old(partName, partState, startNew)
    end

    function HammerSmash:fire(...)
      animator.playSound(self.animKeyPrefix .. "fire")
      animator.burstParticleEmitter(self.animKeyPrefix .. self.weapon.elementalType .. "swoosh")
      hammerSmashFire_old(self, ...)
    end

    function HammerSmash:spin(...)
      animator.playSound(self.animKeyPrefix .. "fire")
      animator.burstParticleEmitter(self.animKeyPrefix .. self.weapon.elementalType .. "swoosh")
      hammerSmashSpin_old(self, ...)
    end
  end
end

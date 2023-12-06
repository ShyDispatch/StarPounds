local HammerSmashFire_old = HammerSmash.fire
function HammerSmash:fire(...)
  local defaultDamage = self.damageConfig.baseDamage

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    -- Shouldn't activate at base size, so both indexes are reduced by one.
    local sizeIndex = starPounds.currentSizeIndex - 1
    local scalingSize = starPounds.settings.scalingSize - 1
    local bonusEffectiveness = math.min(1, sizeIndex/scalingSize)
    self.damageConfig.baseDamage = defaultDamage * (1 + starPounds.getStat("smashDamage") * bonusEffectiveness)
  end

  HammerSmashFire_old(self, ...)
  self.damageConfig.baseDamage = defaultDamage
end

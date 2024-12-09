require"/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.expire", localHandler(effect.expire))
  statModifier = effect.addStatModifierGroup({
    {stat = "invisible", amount = 1},
    {stat = "invulnerable", amount = 1},
    {stat = "healingStatusImmunity", amount = 1},
    {stat = "fireStatusImmunity", amount = 1},
    {stat = "iceStatusImmunity", amount = 1},
    {stat = "electricStatusImmunity", amount = 1},
    {stat = "poisonStatusImmunity", amount = 1},
    {stat = "specialStatusImmunity", amount = 1},
    {stat = "waterImmunity", amount = 1},
    {stat = "lavaImmunity", amount = 1},
    {stat = "tarStatusImmunity", amount = 1},
    {stat = "wetImmunity", amount = 1},
    {stat = "slimeImmunity", amount = 1},
    {stat = "energyRegenPercentageRate", effectiveMultiplier = 0},
    {stat = "healthRegen", effectiveMultiplier = 0}
  })
  effect.setParentDirectives("?multiply=00000000;")
end

function update(dt)
  effect.modifyDuration(dt)
end

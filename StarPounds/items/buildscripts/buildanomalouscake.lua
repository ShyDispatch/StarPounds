require "/items/buildscripts/buildfood.lua"

build_old = build

function build(directory, config, parameters, level, seed)
  config, parameters = build_old(directory, config, parameters, level, seed)
  if not parameters.shortdescription then
    local colourOptions = {
      -- Yellow
      { ffca8a = "fff8b5", e0975c = "fde03f", a85636 = "f6b919", ["6f2919"] = "352b12" },
      -- Orange
      { ffca8a = "ffedc4", e0975c = "feb05c", a85636 = "fa8131", ["6f2919"] = "40110a" },
      -- Red
      { ffca8a = "ffe2c9", e0975c = "fe9875", a85636 = "ef5443", ["6f2919"] = "4f160d" },
      -- Pinky
      { ffca8a = "fee5ff", e0975c = "f6bbf9", a85636 = "f57afc", ["6f2919"] = "4c2153" },
      -- Purple
      { ffca8a = "fedbff", e0975c = "da89f7", a85636 = "ae38f1", ["6f2919"] = "340e52" },
      -- Blue
      { ffca8a = "c7feff", e0975c = "56ebf8", a85636 = "12c2e8", ["6f2919"] = "0c2b4b" },
      -- Sea Green
      { ffca8a = "c3fffc", e0975c = "4df4df", a85636 = "0cd6b8", ["6f2919"] = "0c482d" },
      -- Green
      { ffca8a = "c7ffdc", e0975c = "63f574", a85636 = "17dc0d", ["6f2919"] = "0d500f" },
      -- Yellow Green
      { ffca8a = "fffdae", e0975c = "c9f236", a85636 = "8ae100", ["6f2919"] = "2d510d" }
    }
    local directives = "?replace;"
    local icingColour = math.random(1, #colourOptions)
    local decorationColour = math.max(1, math.fmod(icingColour + math.random(2, 4) * (math.random(0, 1) * 2 - 1), #colourOptions))

    for k,v in pairs(colourOptions[icingColour]) do
      directives = directives..k.."="..v..";"
    end
    directives = string.format(directives..
      "?replace;a4230e=%s;cb2f00=%s;?border=2;%s;%s;",
      colourOptions[decorationColour].e0975c,
      colourOptions[decorationColour].a85636,
      colourOptions[decorationColour].ffca8a.."88",
      colourOptions[decorationColour].ffca8a.."00"
    )

    parameters.shortdescription = string.format("^#%s;Anomalous Cake", colourOptions[icingColour].e0975c)
    parameters.inventoryIcon = "anomalouscake.png"..directives
  end

  return config, parameters
end

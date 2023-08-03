--Definition stuff by Silver Sokolova#3576, from Betabound. Used with permission!
require "/scripts/util.lua"

function build(directory, config, parameters)
  local configParameter = function(keyName, defaultValue) return parameters[keyName] or config[keyName] or defaultValue end
  local definition = configParameter("definition",configParameter("bf_definition"))
  if definition then
    util.mergeTable(config,root.assetJson("/bf_definitions/"..definition..".config"))
    if configOverrides then util.mergeTable(config,configOverrides) end
  end
  return config, parameters
end
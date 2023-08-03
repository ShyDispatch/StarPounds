function init()
  self.buyFactor = config.getParameter("buyFactor", root.assetJson("/merchant.config").defaultBuyFactor)

  object.setInteractive(true)
end

function onInteraction(args)
  local interactData = config.getParameter("interactData")
  interactData.recipes = {}

  local storeInventory = config.getParameter("storeInventory")  
  local tabs = interactData["modTab"]
  local posY = 277
  local categories = {
      type = "radioGroup",
      toggleMode = false,
      buttons = {}
	}
  
  if #tabs > 0 then
	  for i,modtab in ipairs(tabs) do
		local tabIcon = modtab["file"]
		local tabName = modtab["label"]
		local tabFilter = modtab["filter"]
		
		local tabIconLabel = {
		  type = "image",
		  file = tabIcon,
		  position = {
			6,
			posY
		  },
		  zlevel = 3
		}
		
		local tabNameLabel = {
		  type = "label",
		  value = tabName,
		  position = {
			20,
			posY+2
		  },
		  zlevel = 3
		}
		
		local tabButton = {
			  selected = true,
			  position = {
				3,
				posY-2
			  },
			  baseImage = "/interface/fattyshops/body/unselectedTab.png",
			  baseImageChecked = "/interface/fattyshops/body/selectedTab.png",
			  data = {
				filter = tabFilter
			  }
			}
		
		interactData.paneLayoutOverride["icon" .. tabName] = tabIconLabel
		interactData.paneLayoutOverride["lbl" .. tabName] = tabNameLabel
		table.insert(categories["buttons"], 1, tabButton)
		posY = posY - 18
	  end  
	  interactData.paneLayoutOverride["categories"] = categories
  end
  
  for genre,objects in pairs(storeInventory) do addRecipes(interactData, objects, genre) end

  return { "OpenCraftingInterface", interactData }
end

function addRecipes(interactData, items, category)
  for i, item in ipairs(items) do
    interactData.recipes[#interactData.recipes + 1] = generateRecipe(item, category)
  end
end

function generateRecipe(itemName, category)
  return {
    input = { {"money", math.floor(self.buyFactor * (root.itemConfig(itemName).config.price or root.assetJson("/merchant.config").defaultItemPrice))} },
    output = itemName,
	duration = 0,
    groups = { category }
  }
end

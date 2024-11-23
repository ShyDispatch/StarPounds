local pizza = starPounds.module:new("pizza")

function pizza:init()
  message.setHandler("starPounds.digestedPizzaEmployee", simpleHandler(self.digestedPizzaEmployee))
end

-- Pizza stuff.
function pizza:digestedPizzaEmployee()
  storage.starPounds.pizzaEmployeesEaten = (storage.starPounds.pizzaEmployeesEaten or 0) + 1
end

function pizza:boughtPizza()
  storage.starPounds.pizzaEmployeesEaten = nil
end

function pizza:employeeFee()
  return (starPounds.getData("pizzaEmployeesEaten") or 0) * self.data.employeeFee
end

-- Add the module.
starPounds.modules.pizza = pizza

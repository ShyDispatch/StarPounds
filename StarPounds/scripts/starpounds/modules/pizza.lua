local pizza = starPounds.module:new("pizza")

function pizza:init()
  message.setHandler("starPounds.digestedPizzaEmployee", simpleHandler(self.digestedPizzaEmployee))
end

function pizza:digestedPizzaEmployee()
  storage.starPounds.pizzaEmployeesEaten = (storage.starPounds.pizzaEmployeesEaten or 0) + 1
end

function pizza:boughtPizza()
  storage.starPounds.pizzaEmployeesEaten = nil
end

function pizza:employeeFee()
  return (starPounds.getData("pizzaEmployeesEaten") or 0) * self.data.employeeFee
end

starPounds.modules.pizza = pizza

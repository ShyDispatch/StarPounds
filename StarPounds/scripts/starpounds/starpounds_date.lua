function isLeapYear(year)
  return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

function daysPerMonth(month, year)
  local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if month == 2 and isLeapYear(year) then
    return 29
  else
    return days[month]
  end
end

function getDate(timestamp)
  timestamp = timestamp or os.time()
  local year = 1970
  local daysPerYear = 365.25
  local secondsPerDay = 86400
  local days = math.floor(timestamp / secondsPerDay)
  local seconds = timestamp % secondsPerDay

  while days >= math.floor(daysPerYear) do
    days = days - math.floor(isLeapYear(year) and 366 or 365)
    year = year + 1
  end

  local month = 1
  while days >= daysPerMonth(month, year) do
    days = days - daysPerMonth(month, year)
    month = month + 1
  end

  local day = days + 1
  local hour = math.floor(seconds / 3600)
  seconds = seconds % 3600
  local minute = math.floor(seconds / 60)
  local second = seconds % 60

  return {year = year, month = month, day = day, hour = hour, minute = minute, second = second}
end

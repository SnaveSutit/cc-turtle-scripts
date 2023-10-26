-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/count_chests.lua startup.lua

local count = 0
local goal = 153996
-- {time: number, count: number}
local itemHistory = {}

local getAverageItemsPerSecond = function()
	if #itemHistory < 2 then
		return 0
	end
	if #itemHistory > 20 then
		table.remove(itemHistory, 1)
	end

	local totalItems = 0
	local totalTime = 0
	for i = 1, #itemHistory - 1 do
		totalItems = totalItems + (itemHistory[i + 1].count - itemHistory[i].count)
		totalTime = totalTime + (itemHistory[i + 1].time - itemHistory[i].time)
	end
	return totalItems / totalTime
end

local getExpectedTimeRemaining = function(itemsPerSecond)
	if itemsPerSecond == 0 then
		return "Unknown"
	end
	local timeRemaining = (goal - count) / itemsPerSecond
	return ("%d:%d:%d"):format(
		math.floor(timeRemaining / 60 / 60),
		math.floor(timeRemaining / 60) % 60,
		math.floor(timeRemaining) % 60
	)
end

local function returnHomeAndUpdateDisplay()
	while true do
		if not turtle.back() then
			if turtle.getFuelLevel() == 0 then
				turtle.refuel()
			else
				break
			end
		end
	end

	table.insert(itemHistory, { time = os.clock(), count = count })

	local createSource = peripheral.find("create_source")
	if createSource then
		createSource.clear()
		createSource.setCursorPos(1, 1)
		createSource.write("Vanta Black: " .. count .. "/" .. goal .. " (" .. ("%.2f"):format(count / goal * 100) .. "%)")
		createSource.setCursorPos(1, 2)
		local avgItemsPerSecond = getAverageItemsPerSecond()
		createSource.write(
			"ETA: " .. getExpectedTimeRemaining(avgItemsPerSecond) ..
			" Items/s: " .. ("%.2f"):format(avgItemsPerSecond))
	end

	sleep(5)
end

while true do
	local chest = peripheral.find("inventory")
	if chest then
		for slot, item in pairs(chest.list()) do
			if item.name == "dbe:vanta_black" then
				count = count + item.count
			end
		end
	end

	if not turtle.forward() then
		if turtle.getFuelLevel() == 0 then
			turtle.refuel()
		else
			returnHomeAndUpdateDisplay()
			count = 0
		end
	end
end

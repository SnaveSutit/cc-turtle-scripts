-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/count_chests.lua startup.lua

local count = 0
local goal = 153996
-- {time: number, count: number}
local itemHistory = {}

local getAverageItemsPerSecond = function()
	if #itemHistory < 2 then
		return 0
	end

	local totalItems = 0
	local totalTime = 0
	for i = 1, #itemHistory - 1 do
		totalItems = totalItems + (itemHistory[i + 1].count - itemHistory[i].count)
		totalTime = totalTime + (itemHistory[i + 1].time - itemHistory[i].time)
	end
	return totalItems / (totalTime / 1000)
end

local function returnHomeAndUpdateDisplay()
	while turtle.back() do end

	table.insert(itemHistory, { time = os.clock(), count = count })

	local createSource = peripheral.find("create_source")
	if createSource then
		createSource.clear()
		createSource.setCursorPos(1, 1)
		createSource.write("Vanta Black: " .. count .. "/" .. goal .. " (" .. ("%.2f"):format(count / goal * 100) .. "%)")
		createSource.setCursorPos(1, 2)
		createSource.write("Items per second: " .. ("%.2f"):format(getAverageItemsPerSecond()))
	end

	sleep(10)
end

while true do
	count = 0

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
			print("Failed to move forward. Returning to base.")
			returnHomeAndUpdateDisplay()
		end
	end
end

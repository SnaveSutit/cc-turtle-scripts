-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/count_chests.lua startup.lua

local count = 0
local goal = 153996
local lastCheckTime = os.epoch()
local timeHistory = { lastCheckTime }

local getAverageItemsPerSecond = function()
	local total = 0
	for _, time in pairs(timeHistory) do
		total = total + time
	end
	return count / (total / #timeHistory)
end

local function returnHomeAndUpdateDisplay()
	while turtle.back() do end

	table.insert(timeHistory, os.epoch() - lastCheckTime)

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

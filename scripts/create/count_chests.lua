-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/count_chests.lua startup.lua

local count = 0
local goal = 153996

local function returnHomeAndUpdateDisplay()
	while turtle.back() do end

	local createSource = peripheral.find("create_source")
	if createSource then
		createSource.clear()
		createSource.setCursorPos(1, 1)
		createSource.write("Vanta Black: " .. count .. "/" .. goal .. " (" .. math.floor(count / goal * 100) .. "%)")
	end
	sleep(10)
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
			print("Failed to move forward. Returning to base.")
			returnHomeAndUpdateDisplay()
		end
	end
end
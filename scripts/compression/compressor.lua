-- Compressor
-- wget http://localhost:3000/scripts/compression/compressor.lua startup.lua
-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/compression/compressor.lua startup.lua

local chest = peripheral.wrap("top")
local modem = peripheral.find("modem")
local protocol = "compression"
local chestModemName

local function compress(inputSlots)
	local totalCount = 0
	local slot = 1
	while slot <= 11 do
		if turtle.getItemCount(slot) < 64 then
			turtle.select(slot)
			modem.callRemote(chestModemName, "pushItems", modem.getNameLocal(), table.remove(inputSlots, 1), nil, slot)
		end
		totalCount = totalCount + turtle.getItemCount(slot)

		slot = slot + 1
		if slot % 4 == 0 then
			slot = slot + 1
		end
	end

	if totalCount == (9 * 64) then
		turtle.craft()
		turtle.dropUp()
	else
		error("Not enough items to compress")
	end
end

local function getChestModemName()
	print("Getting chest modem name...")
	local inputComputerID
	repeat
		inputComputerID = rednet.lookup(protocol, "input")
	until inputComputerID
	local message
	local computerID = os.getComputerID()
	repeat
		rednet.send(inputComputerID, {
			title = "getItemChest",
			computerID = computerID,
			itemName = os.getComputerLabel(),
		}, protocol)
		_, message = rednet.receive(protocol, 10)
	until type(message) == "table"
		and message.receiverID == computerID
		and message.title == "getItemChestResponse"
		and message.chest
	local itemChest = message.chest
	chestModemName = itemChest
	print("Got chest modem name: " .. chestModemName)
end

local function main()
	rednet.open(peripheral.getName(modem))
	sleep(1)
	getChestModemName()

	while true do
		local groups = {}
		local groupsAbove9x64 = {}
		local storage = chest.list()
		for slot, item in pairs(storage) do
			if groups[item.name] then
				groups[item.name].count = groups[item.name].count + item.count
				table.insert(groups[item.name].slots, slot)
			else
				groups[item.name] = {
					count = item.count,
					slots = { slot },
				}
			end
			if groups[item.name].count >= (9 * 64) then
				groupsAbove9x64[item.name] = groups[item.name]
			end
		end
		for itemName, item in pairs(groupsAbove9x64) do
			print("Compressing " .. itemName)
			compress(item.slots)
		end
		sleep(5)
	end
end

main()

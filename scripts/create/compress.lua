-- wget run http://localhost:3000/scripts/create/compress.lua

local modem = peripheral.find("modem")
local chestName = modem.getNamesRemote()[1]
local modemName = modem.getNameLocal()
local craftingSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }

if not chestName then
	error("No chest found")
end

local function pullItems(fromSlot, limit, toSlot)
	return modem.callRemote(chestName, "pushItems", modemName, fromSlot, limit, toSlot)
end

local function getItems()
	return modem.callRemote(chestName, "list")
end

local function clearAllSlots()
	for i = 1, 16 do
		turtle.select(i)
		turtle.dropUp()
	end
end

local function compressItems(itemName, item, maxCompressed)
	for _, slot in ipairs(craftingSlots) do
		turtle.select(slot)
		local slotItemCount = turtle.getItemCount(slot)
		if slotItemCount > maxCompressed then
			print("Unexpected item count in slot " .. slot .. ": " .. slotItemCount)
			clearAllSlots()
			return
		elseif slotItemCount < maxCompressed then
			local thisSlot = item.slots[1]
			while slotItemCount < maxCompressed do
				local pulledCount = pullItems(thisSlot.slot, maxCompressed - slotItemCount, slot)
				if pulledCount == 0 then
					slotItemCount = turtle.getItemCount(slot)
					if slotItemCount < maxCompressed then
						print("Unexpected item count in slot " .. slot .. ": " .. slotItemCount)
						clearAllSlots()
						return
					end
				else
					slotItemCount = slotItemCount + pulledCount
				end
				thisSlot.count = thisSlot.count - pulledCount
				if thisSlot.count == 0 then
					table.remove(item.slots, 1)
					thisSlot = item.slots[1]
				end
			end
		end
	end

	turtle.craft()
	turtle.dropUp()
end

local function getItemData()
	local list = getItems()
	local items = {}
	for slot, item in pairs(list) do
		if items[item.name] then
			table.insert(items[item.name].slots, { slot = slot, count = item.count })
			items[item.name].totalCount = items[item.name].totalCount + item.count
		else
			items[item.name] = {
				name = item.name,
				slots = { { slot = slot, count = item.count } },
				totalCount = item.count
			}
		end
	end
	return items
end

local function main()
	clearAllSlots()

	while true do
		local items = getItemData()
		table.sort(items, function(a, b) return a.totalCount > b.totalCount end)

		local didCompression = false
		for itemName, item in pairs(items) do
			if item.totalCount >= 9 then
				local maxCompressed = math.floor(item.totalCount / 9)

				while maxCompressed > 64 do
					compressItems(itemName, item, 64)
					maxCompressed = maxCompressed - 64
				end
				compressItems(itemName, item, maxCompressed)
				didCompression = true
			end
		end

		if not didCompression then
			sleep(1)
		end
	end
end

main()

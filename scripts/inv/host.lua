-- wget run http://localhost:3000/scripts/inv/host.lua host.lua
-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/inv/host.lua host.lua

local modem = peripheral.find('modem')
local source = peripheral.find('create_source')
local input_chest = ''
local output_chests = {}


local function initializePaths()
	local names = modem.getNamesRemote()
	for _, name in ipairs(names) do
		if name:find('copper_chest') then
			input_chest = name
		else
			local label = modem.callRemote(name, 'getLabel')
			output_chests[label] = name
		end
	end
end


local function send_to_turtle(turtle, slot)
	modem.callRemote(input_chest, 'pushItems', turtle, slot)
end


local function checkIfTurtleFull(turtle)
	local items = modem.callRemote(turtle, 'list')
	local size = modem.callRemote(turtle, 'size')
	if #items >= size then
		return true
	end
end


local function scanForItems()
	local items = modem.callRemote(input_chest, 'list')

	for slot, item in pairs(items) do
		local my_turtle = output_chests[item.name]
		if my_turtle then
			print('Sending item: ' .. item.name .. ' to turtle: ' .. my_turtle)
			send_to_turtle(my_turtle, slot)
		else
			print('No turtle for item: ' .. item.name .. ' sending to misc output')
			local misc = output_chests['MISC']
			if not misc then
				print('No misc output turtle found')
				return false
			end
			send_to_turtle(misc, slot)
		end
	end

	return false
end


local function main()
	initializePaths()
	while true do
		if not scanForItems() then
			sleep(1)
		end
	end
end

main()

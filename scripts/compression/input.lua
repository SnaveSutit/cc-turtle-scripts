-- Extractor
-- wget http://localhost:3000/scripts/compression/input.lua startup.lua

local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end
local state = requireExternal(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua"
)
local modem = peripheral.find("modem")
local protocol = "compression"
local defaultState = {
	input = false,
	miscOutput = false,
	outputs = {},
}

local function rebootTurtles()
	for _, name in ipairs(modem.getNamesRemote()) do
		if name:match("^turtle") then
			print("Rebooting " .. name)
			modem.callRemote(name, "reboot")
		end
	end
end

local function updateOutputChests()
	local outputs = state.get("outputs")
	for _, name in ipairs(modem.getNamesRemote()) do
		local _, t = modem.getTypeRemote(name)
		if t == "inventory" and not outputs[name] then
			outputs[name] = false
		end
	end
	for chest, item in pairs(outputs) do
		if not item then
			print("WARNING! No output item specified for " .. chest)
		end
	end
	state.save()
end

local function getItemOutputChest(itemName)
	local outputs = state.get("outputs")
	for chest, item in pairs(outputs) do
		if item == itemName then
			return chest
		end
	end
end

local function isOutputFull(output)
	local items = modem.callRemote(output, "list")
	local size = modem.callRemote(output, "size")
	if #items >= size - 2 then
		return true
	end
	return false
end

local function takeInput()
	local inputChest = state.get("input")
	local lastItemName, outputChest
	local miscOutputChest = state.get("miscOutput")
	while true do
		local items = modem.callRemote(inputChest, "list")
		print("Got " .. #items .. " items")
		for slot, item in pairs(items) do
			if not (item.name == lastItemName) then
				outputChest = getItemOutputChest(item.name)
				lastItemName = item.name
			end
			if not outputChest then
				print("Pushing " .. item.name .. " to misc output")
				if isOutputFull(miscOutputChest) then
					error("Misc output full!")
				end
				modem.callRemote(inputChest, "pushItems", miscOutputChest, slot)
			else
				print("Pushing " .. item.name .. " to " .. outputChest)
				if isOutputFull(outputChest) then
					print("Output for " .. item.name .. " full!")
					os.reboot()
				else
					modem.callRemote(inputChest, "pushItems", outputChest, slot)
				end
			end
		end
		sleep(1)
	end
end

local function main()
	state.load(".extractor_state", defaultState)
	rednet.open(peripheral.getName(modem))
	rebootTurtles()

	if not state.get("input") then
		print("No input chest specified. Available chests:")
		print("  " .. table.concat(modem.getNamesRemote(), "\n  "))
		error("No input chest specified.")
	end

	if not state.get("miscOutput") then
		print("No misc output chest specified. Available chests:")
		print("  " .. table.concat(modem.getNamesRemote(), "\n  "))
		error("No misc output chest specified.")
	end

	updateOutputChests()

	while true do
		parallel.waitForAny(takeInput, function()
			local senderID, message
			while true do
				senderID, message = rednet.receive(protocol)
				if type(message) == "table" and message.title == "getItemChest" then
					local result = getItemOutputChest(message.itemName)
					print("Sending " .. result .. " to " .. message.computerID)
					rednet.send(message.computerID, {
						title = "getItemChestResponse",
						receiverID = message.computerID,
						chest = result,
					}, protocol)
				end
			end
		end)
	end
end

main()
